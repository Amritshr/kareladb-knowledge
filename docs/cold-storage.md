# Cold storage (S3, MinIO, R2, B2)

> Move old partitions of a time-series table to S3-compatible object storage (AWS S3, MinIO, Cloudflare R2, Backblaze B2) and keep reading them as if they were local.

- Category: Time-series
- Keywords: cold storage, cold, tiering, tiered storage, archive, object storage, S3, AWS S3, MinIO, Cloudflare R2, R2, Backblaze B2, B2, bucket, cold\_storage, cold\_after, WITH (cold\_storage, SET (cold\_storage, RESET (cold\_storage, MOVE PARTITION, TO COLD, FROM COLD, cold\_partitions(), KARELADB\_COLD, KARELADB\_COLD\_CACHE\_MB, KARELADB\_COLD\_DELETE, old partitions, move old data, cheap storage, disk full, kdb\_cold, multipart, SigV4
- See also: [Partitions, SORT BY and DEDUP KEY](partitions-and-dedup.md), [ALTER, RENAME and DROP TABLE](alter-table.md), [CREATE TABLE](create-table.md), [Backup, check, repair and restore](backup-and-safety.md), [Health, info, check and backup over HTTP](http-server-info.md)

A time-series table keeps every partition on the server's disk. Old partitions are read rarely but take the same space. **Cold storage** moves them to an object store (a bucket in AWS S3, MinIO, Cloudflare R2 or Backblaze B2) and keeps a small note in their place. Queries do not change: a query that reads an old day fetches what it needs and answers as before.

| | Local partition | Cold partition |
|---|---|---|
| Where the rows are | a file in the data folder | an object in the bucket, plus a stub of at most about 70 KB on disk |
| A query that does not touch it | nothing | nothing (no request is sent) |
| A query that reads it | reads the file | fetches only the columns it reads, in 1 MiB pieces, into a local cache |
| Writes (late rows, UPDATE, DELETE) | as usual | accepted; the next checkpoint writes the partition back as a local file |
| Backup | copies the file | copies the stub: the bucket is part of the backup |

Setup used by the examples below:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE, volume LONG)
  TIMESERIES(time) PARTITION BY MONTH;
INSERT INTO ticks VALUES
  ('2025-01-15T10:00:00Z', 'CITY', 500.0, 120), ('2025-01-16T10:00:00Z', 'BANK', 211.5, 900),
  ('2025-02-12T10:00:00Z', 'CITY', 507.5, 300), ('2025-02-13T10:00:00Z', 'BANK', 209.0, 450),
  ('2025-03-11T10:00:00Z', 'CITY', 512.0, 210), ('2025-03-12T10:00:00Z', 'BANK', 214.0, 380),
  ('2026-10-01T10:00:00Z', 'CITY', 530.0, 150);
```

<a id="define-a-store"></a>

## Define a store

A store is defined by settings where the server starts, never by SQL. Its keys never appear in a statement, the log, a system table, `/api/info` or `/api/stats`. `<NAME>` is the store's name in capitals; tables use it in lower case.

| Setting | Meaning | Default |
|---|---|---|
| `KARELADB_COLD_<NAME>_URL` | the endpoint, without the bucket: `https://s3.eu-west-1.amazonaws.com`, `http://minio:9000`, or a folder `file:///mnt/cold` | required |
| `KARELADB_COLD_<NAME>_BUCKET` | the bucket (not used by `file://`) | required for S3 |
| `KARELADB_COLD_<NAME>_PREFIX` | a folder inside the bucket, put before every object | none |
| `KARELADB_COLD_<NAME>_REGION` | the region the request is signed for; R2 takes `auto` | `us-east-1` |
| `KARELADB_COLD_<NAME>_ACCESS_KEY` | the access key id | none |
| `KARELADB_COLD_<NAME>_SECRET_KEY` | the secret key | none |
| `KARELADB_COLD_<NAME>_PATH_STYLE` | `on`: `http://host/bucket/key` (MinIO); `off`: `http://bucket.host/key` | `on`, except for `*.amazonaws.com` |
| `KARELADB_COLD_<NAME>_TIMEOUT_MS` | the most one request may take | `300000` |
| `KARELADB_COLD_CACHE_MB` | the local cache of fetched pieces, all databases together; `0` = no cache | `1024` |

- Every `KARELADB_COLD_*` setting may also be written `KDB_COLD_*`; the `KARELADB_` one wins.
- `kareladb serve` prints each store it found at start (where it is, never its keys). `GET /api/stats` lists them under `cold.stores`.
- The server talks to the store over HTTPS (it checks the certificate like any HTTPS client) or plain HTTP. Every request is signed with AWS Signature Version 4, and every upload carries the SHA-256 of its body, so the store refuses a body damaged on the way.
- The folder store (`file://`) needs no keys: a network drive, or a disk of its own.

```text
# AWS S3
KARELADB_COLD_ARCHIVE_URL=https://s3.eu-west-1.amazonaws.com
KARELADB_COLD_ARCHIVE_BUCKET=my-company-cold
KARELADB_COLD_ARCHIVE_REGION=eu-west-1
KARELADB_COLD_ARCHIVE_ACCESS_KEY=AKIA...
KARELADB_COLD_ARCHIVE_SECRET_KEY=...

# MinIO
KARELADB_COLD_ARCHIVE_URL=http://minio:9000
KARELADB_COLD_ARCHIVE_BUCKET=cold

# Cloudflare R2
KARELADB_COLD_ARCHIVE_URL=https://<account id>.r2.cloudflarestorage.com
KARELADB_COLD_ARCHIVE_REGION=auto

# Backblaze B2
KARELADB_COLD_ARCHIVE_URL=https://s3.us-west-004.backblazeb2.com
KARELADB_COLD_ARCHIVE_REGION=us-west-004
```

In Docker, pass them with `-e`, as `KARELADB_TOKEN` is. The bucket must exist; KarelaDB does not make it.

The examples on this page use a store named `archive`, a folder the help build made.

<a id="turn-on"></a>

## Turn it on for a table

Syntax:

```sql
CREATE TABLE name (...) TIMESERIES(time) PARTITION BY DAY | MONTH | YEAR
  WITH (cold_storage = 'store' [, cold_after = 'span'])
ALTER TABLE name SET (cold_storage = 'store' [, cold_after = 'span'])
ALTER TABLE name RESET (cold_storage) | RESET (cold_after)
```

| Option | Meaning |
|---|---|
| `cold_storage` | the store's name (letters, digits and `_`). The store must be defined where the statement runs |
| `cold_after` | how long after a partition's time **ended** it moves: `'90 days'`, `'6 months'`, `'1 year'`. Units: seconds, minutes, hours, days, weeks, months (30 days) and years (365 days). `'0'` or not set: nothing moves by itself, only [MOVE PARTITION](cold-storage.md#move-partition) moves |

- The server checks every minute for **sealed** partitions (every one but the newest) whose time range ended more than `cold_after` ago, and moves them one at a time, in the background. The newest partition, where rows still arrive, never moves.
- Only tables with time partitions (`PARTITION BY DAY`, `MONTH` or `YEAR`) can have a cold store.
- `RESET (cold_storage)` stops further moves. Partitions already cold stay there until [FROM COLD](cold-storage.md#move-partition) brings them back.
- `SHOW CREATE TABLE` shows the options.

**Example: Old partitions of ticks go to the store 'archive' half a year after they end**

```sql
ALTER TABLE ticks SET (cold_storage = 'archive', cold_after = '6 months');
SHOW CREATE TABLE ticks;
```

Result:

`ALTER TABLE ticks SET (cold_storage = 'archive', cold_after = '180 days')`

```text
table 'ticks': cold store 'archive' (folder ./cold-archive); sealed partitions whose time ended more than 180 days ago move there in the background
```

`SHOW CREATE TABLE ticks`

| create_sql (STRING) |
|---|
| CREATE TABLE ticks (   time TIMESTAMP,   symbol SYMBOL,   price DOUBLE,   volume LONG ) TIMESERIES(time) PARTITION BY MONTH SORT BY (symbol, time) WITH (cold_storage = 'archive', cold_after = '180 ... |

(1 row)

**Example: A store that is not defined is refused** (shows an error)

```sql
ALTER TABLE ticks SET (cold_storage = 'nowhere');
```

Result:

Error: `cold store 'nowhere' is not defined: set KARELADB_COLD_NOWHERE_URL (and _BUCKET, _ACCESS_KEY, _SECRET_KEY) where the server starts`

<a id="move-partition"></a>

## MOVE PARTITION ... TO COLD and FROM COLD

Syntax:

```sql
ALTER TABLE name MOVE PARTITION [LIST] 'partition' [, ...] TO COLD
ALTER TABLE name MOVE PARTITION [LIST] 'partition' [, ...] FROM COLD
```

`TO COLD` moves the partitions now, whatever `cold_after` says. `FROM COLD` writes cold partitions back as local files. The answer has one row per partition: what happened, and the bytes moved.

- Send it **alone**, outside a transaction, like `CHECKPOINT`. It uploads or fetches for as long as that takes; it holds the database alone only for the moment it switches each partition over.
- A partition with unsaved changes is first written by a checkpoint, so what moves is one whole file.
- The newest partition cannot move. When none of the partitions named can move, the statement fails and says why for each.
- After `FROM COLD`, a table whose `cold_after` still says the partition is old moves it again at the next check. `RESET (cold_storage)` or a longer `cold_after` keeps it local.
- Rights: the `ddl` role (or `admin`), as for `COMPRESS TABLE`.

**Example: Move two old months now**

Setup:

```sql
ALTER TABLE ticks SET (cold_storage = 'archive');
```

```sql
ALTER TABLE ticks MOVE PARTITION '2025-01', '2025-02' TO COLD;
```

Result:

| partition (STRING) | result (STRING) | bytes (LONG) |
|---|---|---|
| 2025-01 | moved to cold store 'archive' | 692 |
| 2025-02 | moved to cold store 'archive' | 692 |

(2 rows)

```text
2 partition(s) of table 'ticks' moved to cold store 'archive' (they stay there: cold_after is not set)
```

Each statement on its own, as `kareladb shell` and the console send them:

**Command line: Queries read cold partitions as before**

Setup:

```text
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE, volume LONG)
  TIMESERIES(time) PARTITION BY MONTH WITH (cold_storage = 'archive');
INSERT INTO ticks VALUES
  ('2025-01-15T10:00:00Z', 'CITY', 500.0, 120), ('2025-01-16T10:00:00Z', 'BANK', 211.5, 900),
  ('2025-02-12T10:00:00Z', 'CITY', 507.5, 300), ('2025-02-13T10:00:00Z', 'BANK', 209.0, 450),
  ('2025-03-11T10:00:00Z', 'CITY', 512.0, 210), ('2025-03-12T10:00:00Z', 'BANK', 214.0, 380),
  ('2026-10-01T10:00:00Z', 'CITY', 530.0, 150);
```

```bash
kdb shell market
> ALTER TABLE ticks MOVE PARTITION '2025-01', '2025-02' TO COLD;
> SELECT symbol, count(*) AS days, avg(price) AS avg_price, sum(volume) AS volume FROM ticks WHERE time < '2026-01-01' GROUP BY symbol ORDER BY symbol;
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> partition | result                        | bytes
----------+-------------------------------+------
2025-01   | moved to cold store 'archive' |   692
2025-02   | moved to cold store 'archive' |   692
(2 rows, 80.1 ms)
2 partition(s) of table 'ticks' moved to cold store 'archive' (they stay there: cold_after is not set)
kareladb> symbol | days | avg_price | volume
-------+------+-----------+-------
BANK   |    3 |     211.5 |   1730
CITY   |    3 |     506.5 |    630
(2 rows, 0.6 ms)
kareladb>
```

**Example: The newest partition stays** (shows an error)

Setup:

```sql
ALTER TABLE ticks SET (cold_storage = 'archive');
```

```sql
ALTER TABLE ticks MOVE PARTITION '2026-10' TO COLD;
```

Result:

Error: `nothing of table 'ticks' can move to cold storage: 2026-10: it is the newest partition, where rows still arrive`

**Command line: Bring a month back as a local file**

Setup:

```text
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE, volume LONG)
  TIMESERIES(time) PARTITION BY MONTH WITH (cold_storage = 'archive');
INSERT INTO ticks VALUES
  ('2025-01-15T10:00:00Z', 'CITY', 500.0, 120), ('2025-01-16T10:00:00Z', 'BANK', 211.5, 900),
  ('2025-02-12T10:00:00Z', 'CITY', 507.5, 300), ('2025-02-13T10:00:00Z', 'BANK', 209.0, 450),
  ('2025-03-11T10:00:00Z', 'CITY', 512.0, 210), ('2025-03-12T10:00:00Z', 'BANK', 214.0, 380),
  ('2026-10-01T10:00:00Z', 'CITY', 530.0, 150);
```

```bash
kdb shell market
> ALTER TABLE ticks MOVE PARTITION '2025-01', '2025-02' TO COLD;
> ALTER TABLE ticks MOVE PARTITION '2025-02' FROM COLD;
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> partition | result                        | bytes
----------+-------------------------------+------
2025-01   | moved to cold store 'archive' |   692
2025-02   | moved to cold store 'archive' |   692
(2 rows, 73.9 ms)
2 partition(s) of table 'ticks' moved to cold store 'archive' (they stay there: cold_after is not set)
kareladb> partition | result                       | bytes
----------+------------------------------+------
2025-02   | written back as a local file |     0
(1 row, 19.2 ms)
1 partition(s) of table 'ticks' are local files again
kareladb>
```

<a id="cost"></a>

## What a query costs

| Query | What it reads |
|---|---|
| a time range with no cold partition in it | the local files, exactly as before: a partition the time range rules out is never opened, local or cold |
| a cold partition, its count, min, max, or the plan | nothing from the store: the file's header, first block and checksums are in the stub |
| columns of a cold partition | only those columns' parts of the file, fetched in 1 MiB pieces by ranged GETs (pieces next to each other in one request of up to 16 MiB) |
| the same piece again | the local cache (`KARELADB_COLD_CACHE_MB`), least recently used first out |

- Every piece is checked twice: against a CRC32C kept with it in the cache, and, like every local file, against the partition file's own checksum of each 64 KiB block. A damaged cache file is fetched again.
- The cache is only a copy: it is emptied when the database opens and closes.
- Once read, a cold partition stays in memory like any other until memory is needed.

<a id="watch"></a>

## Watch it: cold_partitions(), /api/stats, /metrics

`cold_partitions()` lists the cold partitions of the current database.

| Column | Type | Meaning |
|---|---|---|
| `table_name` | STRING | the table |
| `partition` | STRING | the partition name |
| `store` | STRING | the cold store |
| `object_key` | STRING | the object in the bucket: `kareladb/<database id>/<table id>/<partition>/v<version>-<digest>.kdb` |
| `bytes` | LONG | the size of the object (the whole partition file) |
| `moved_at` | TIMESTAMP | when it moved |
| `stub_bytes` | LONG | the size of the stub on disk |
| `sha256` | STRING | the SHA-256 of the object, as uploaded |

**Command line: The cold partitions of this database**

Setup:

```text
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE, volume LONG)
  TIMESERIES(time) PARTITION BY MONTH WITH (cold_storage = 'archive');
INSERT INTO ticks VALUES
  ('2025-01-15T10:00:00Z', 'CITY', 500.0, 120), ('2025-01-16T10:00:00Z', 'BANK', 211.5, 900),
  ('2025-02-12T10:00:00Z', 'CITY', 507.5, 300), ('2025-02-13T10:00:00Z', 'BANK', 209.0, 450),
  ('2025-03-11T10:00:00Z', 'CITY', 512.0, 210), ('2025-03-12T10:00:00Z', 'BANK', 214.0, 380),
  ('2026-10-01T10:00:00Z', 'CITY', 530.0, 150);
```

```bash
kdb shell market
> ALTER TABLE ticks MOVE PARTITION '2025-01', '2025-02', '2025-03' TO COLD;
> SELECT table_name, partition, store, bytes FROM cold_partitions() ORDER BY partition;
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> partition | result                        | bytes
----------+-------------------------------+------
2025-01   | moved to cold store 'archive' |   692
2025-02   | moved to cold store 'archive' |   692
2025-03   | moved to cold store 'archive' |   692
(3 rows, 128.2 ms)
3 partition(s) of table 'ticks' moved to cold store 'archive' (they stay there: cold_after is not set)
kareladb> table_name | partition | store   | bytes
-----------+-----------+---------+------
ticks      | 2025-01   | archive |   692
ticks      | 2025-02   | archive |   692
ticks      | 2025-03   | archive |   692
(3 rows, 0.2 ms)
kareladb>
```

`GET /api/stats` has an object `cold`, and `GET /metrics` has the same counts as `kdb_cold_*` (since the server started):

| /api/stats `cold.` | /metrics | Meaning |
|---|---|---|
| `partitions` | `kdb_cold_partitions` | cold partitions of the open databases now |
| `remote_bytes` | `kdb_cold_remote_bytes` | their bytes in object storage |
| `moved`, `moved_bytes` | `kdb_cold_moved_total`, `kdb_cold_moved_bytes_total` | partitions moved, and bytes uploaded |
| `returned` | `kdb_cold_returned_total` | partitions written back with `FROM COLD` |
| `fetches`, `fetched_bytes` | `kdb_cold_fetches_total`, `kdb_cold_fetched_bytes_total` | ranged reads from the store, and their bytes |
| `cache_hits`, `cache_misses` | `kdb_cold_cache_hits_total`, `kdb_cold_cache_misses_total` | 1 MiB pieces read from the cache, and fetched |
| `cache_bytes`, `cache_cap_bytes` | `kdb_cold_cache_bytes` | the cache now, and its size limit |
| `cache_evictions` | `kdb_cold_cache_evictions_total` | pieces the cache let go |
| `deleted_objects` | `kdb_cold_deleted_objects_total` | objects deleted once no partition named them |
| `errors` | `kdb_cold_errors_total` | moves, reads and deletes that failed (the server log says which) |
| `stores` | | each store defined here: its name and where it is |

<a id="safety"></a>

## How a move stays safe

A partition moves in five steps. The data is readable at every moment, from the local file or from the store, never from neither.

| Step | What happens | After a crash here |
|---|---|---|
| 1. intent | the server notes in the manifest that the object is being made | the next check deletes the object and the note; the partition stays local |
| 2. upload | the file is checked block by block, then sent whole: one PUT up to 16 MiB, else a multipart upload of 16 MiB parts | as step 1 |
| 3. verify | the store's size and the SHA-256 of the object must match the file, and its ETag too where the bucket does not encrypt with KMS or a customer key (SSE-KMS and SSE-C ETags are not MD5s) | as step 1 |
| 4. switch | with the database held alone, the stub is published in the manifest, in the same save that ends the intent | the partition is cold and reads from the store |
| 5. let go | only now the local file moves to `_trash` (removed with the trash, within the hour) | the next check lets the local file go |

- Network trouble and "slow down" answers (5xx, 429) are tried again, with pauses growing from 0.25 to 4 seconds. A refusal (403, wrong keys) is reported at once, without the keys. A read a query waits for gives up after 30 seconds a try and 2 minutes in all, or as soon as the statement is cancelled or reaches its `statement_timeout`.
- Every request carries the SHA-256 of its body, signed, so the store refuses one damaged on the way. Buckets encrypted by default with SSE-KMS work like any other.
- Objects are never deleted where the data changes. The server deletes an object it made once no partition file of the database names it any more: after `DROP PARTITION`, a TTL, `DROP TABLE` (once it leaves the trash), `TRUNCATE`, or a partition written back. It waits an hour after it first finds the object unnamed, and deletes nothing while a backup or an `AS OF` read is running, so a backup taken a moment before still finds every object it names. An older version of a partition (kept for repairs) still names its object; `PURGE VERSIONS` lets it go sooner.
- A database deletes only objects under its own id (`kareladb/<database id>/`). A [branch](as-of-and-branches.md) gets an id of its own: it reads the objects of the database it came from but never deletes them, even when it drops those partitions.
- `DROP DATABASE` deletes nothing in the bucket. Once the dropped database leaves the trash, remove its objects under `kareladb/<database id>/` by hand (the id is in the `object_key` column of `cold_partitions()`; note it before you drop).
- **Backups** copy the stubs, not the objects: the bucket is part of every backup. Keep the bucket while you keep the backups, and turn on the bucket's versioning (or object lock) if a backup must bring back a partition that was dropped later.
- A backup restored into a **second** folder next to the original shares the original's objects and id. Before you drop partitions in such a copy, start it with `KARELADB_COLD_DELETE=off` (it then deletes no object at all), or give it its own bucket. A restore never finishes or cleans up an upload the original had under way when the backup was taken: at worst that object is left in the bucket.
- `kareladb check` checks the stubs; it does not read the objects.

<a id="limits"></a>

## Limits

- A database encrypted at rest ([encryption](encryption.md)) cannot use cold storage yet: its partitions would leave the computer without its key's protection.
- A standby copy keeps its own local files; moves happen on the primary.
- Writes into a cold partition are accepted. The write itself fetches the partition when it needs its rows (an UPDATE, a DELETE, a key already there), before it takes any lock other tables wait for; a store that cannot be reached then fails that statement. The checkpoint that saves the changes writes the partition locally.
- When the store cannot be reached at a checkpoint (down, or its `KARELADB_COLD_*` settings missing after a restart), that checkpoint saves every other partition and leaves this one's changes in memory and the log, as safe as any commit: the log is kept from that partition's last save and replayed at the next open. `errors` in `/api/stats` counts it and the server log names the partition. Checkpoints try it again after a minute; until then the log and memory hold its changes, so bring the store back (or define it again) soon.
- An older KarelaDB build refuses a database with cold partitions (feature `cold_storage`), rather than taking the stubs for damaged files. `ALTER TABLE ... MOVE PARTITION ... FROM COLD` and `RESET (cold_storage)` take a database back.
