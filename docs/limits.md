# Limits

> The sizes and counts KarelaDB allows, what happens at each limit, and the features that are not there yet.

- Category: Limits
- Keywords: limit, limits, maximum, max, how big, how many, too big, too many, nested too deeply, 16 MB, 64 MB, 10 million, DECIMAL scale, name length, too many open cursors, lock timeout, database is busy, table is busy, deadlock, idle transaction, request body, 10,000 rows, truncated, disk full, 507, 53100, statement timeout, max-queries-per-user, max-groups, max-result-memory, max\_spill\_bytes, KARELADB\_NO\_ZONE\_MAPS, KARELADB\_NO\_COLUMN\_MASK, KARELADB\_NO\_UNION\_PUSHDOWN, switches, reader yield, not supported, missing features, known limitations, not available
- See also: [Performance tips](performance-tips.md), [Cursors (limits)](cursors.md#limits), [Transactions](transactions.md), [Run SQL over HTTP (/exec, /exp)](http-exec.md), [How KarelaDB stores data](data-formats.md), [Protection - timeouts, limits, safe updates, read-only](protection.md)

These are the limits of KarelaDB `0.2.0-dev` (checked against the program on 2026-10-25). Most of them are there to protect memory and to give a clear error instead of a crash.
When a limit is reached, the statement fails with an error that names the limit, and **nothing** of that statement is saved.

The full list of missing features is in [known limitations](../tutorial/known-limitations.md). Please check again after you update KarelaDB.

<a id="names"></a>

## Names

Syntax:

```sql
database names   1 to 64 characters: letters, digits, _ and -
user names       1 to 63 characters: letters, digits, _ and -
passwords        12 characters to 1024 bytes
```

| Name | Limit |
|---|---|
| Database | 1 to 64 characters, letters, digits, `_` and `-`. Upper and lower case are the same. Not `_trash`, `_system`, or Windows device names (`CON`, `NUL`, `COM1`, ...). |
| Server user | 1 to 63 characters, letters, digits, `_` and `-` |
| Password of a server user | at least 12 characters (not the user name), at most 1024 bytes |
| Tables, columns, views, functions | no fixed length. Reserved words (like `order`, `select`) need double quotes. |
| Columns in one index | 16 |

**Example: A database name that is too long** (shows an error)

```sql
CREATE DATABASE stock_market_data_from_2015_to_2026_all_symbols_minute_candles_copy;
```

Result:

Error: `line 1, column 17: bad database name 'stock_market_data_from_2015_to_2026_all_symbols_minute_candles_copy': the name is longer than 64 characters`

<a id="values"></a>

## Values

Syntax:

```sql
DECIMAL(scale)       scale 0 to 18, 18 digits
NUMERIC(p, scale)    up to 38 digits
STRING, JSON, BYTES  at most 16 MB per value
TIMESTAMP            milliseconds, UTC
```

| Value | Limit |
|---|---|
| `INT` | -2,147,483,647 to 2,147,483,647 |
| `LONG` | about ±9.2 × 10^18 |
| `DECIMAL(scale)` | scale 0 to 18; 18 digits in all (8 bytes). Exact. |
| `NUMERIC(p, s)`, `DECIMAL(p, s)` | up to 38 digits (16 bytes when `p` is over 18), scale 0 to 38. Exact; a result past 38 digits is an error (`22003`). |
| `STRING`, `JSON`, `BYTES` | 16 MB per value. Keep PDF files and images outside the database; store a path and a hash. |
| JSON nesting | 256 levels |
| `TIMESTAMP` | milliseconds. Microseconds and nanoseconds are cut. |
| `repeat` result | 16 MB |
| `lpad`, `rpad` length | 10,000,000 characters |
| `greatest`, `least` | 64 values |
| Regular expression | 4,096 bytes; `{n,m}` up to 1,000; 32 groups; 200 million steps of work per match, then `needs too much work for this text` (a 4 MB value can take 2 to 3 seconds before that) |
| Password hash rounds (`password_hash(text, n)`) | 1,000 to 10,000,000 |

**Example: DECIMAL scale** (shows an error)

```sql
SELECT CAST(12.5 AS DECIMAL(19));
```

Result:

Error: `line 1, column 29: expected a scale from 0 to 18 in DECIMAL(scale) but found '19'`

**Example: A value too big for INT** (sample data: sample; shows an error)

```sql
INSERT INTO brokers VALUES (3000000000, 'Too Big Securities');
```

Result:

Error: `column 'id' (INT): 3000000000 is out of range (-2147483647 to 2147483647)`

**Example: A text result over 16 MB** (shows an error)

```sql
SELECT length(repeat('x', 20000000));
```

Result:

Error: `line 1, column 15: repeat: the result would be larger than 16 MB`

<a id="nesting"></a>

## Nesting

Syntax:

```sql
expressions                  about 100 levels of ( ... )
subqueries and views         16 levels
saved functions, CALL, triggers   16 levels each
tables in one query          63
```

| What | Limit |
|---|---|
| Nesting of expressions (brackets, `CASE` in `CASE`, ...) | about 100 levels |
| Nesting of subqueries and views | 16 levels |
| Saved functions calling saved functions | 16 levels |
| `CALL` inside procedures, triggers that fire triggers | 16 levels each |
| Tables in one query (`FROM` and `JOIN`s) | 63 |
| Rounds of one `WHILE` loop | 10 million |
| A recursive `WITH` query | 100,000 rounds or 10 million rows |

**Example: Too many brackets** (shows an error)

```sql
SELECT (((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((1)))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))));
```

Result:

Error: `line 1, column 107: expression is nested too deeply; expected at most 100 levels of nesting`

<a id="rows"></a>

## Rows

Syntax:

```sql
kareladb sql / kareladb shell     1,000 rows per result in table format (--max-rows, .maxrows)
HTTP /exec              10,000 rows by default, at most 1,000,000 (limit=)
HTTP /exp               1,000,000 rows by default, any number with limit= (streamed)
one transaction         10 million changed rows
one query (kareladb serve)   1 GB of rows in memory, 5,000,000 groups
```

| What | Limit |
|---|---|
| Rows, tables, partitions, databases | **no fixed limit** (the disk is the limit) |
| Rows shown by `kareladb sql` and `kareladb shell` in table format | 1,000 (change with `--max-rows N` / `.maxrows N`; `0` = all). CSV and JSON: no limit. |
| Rows returned by HTTP `/exec` | 10,000 unless you pass `limit=`, at most 1,000,000. A cut answer has `"truncated": true`: check it, or you read (and time) a short answer. |
| Rows exported by HTTP `/exp` | 1,000,000 unless you pass `limit=`, then any number: a plain read of one table is streamed, never held whole. `X-KDB-Truncated: true` says rows were cut ([GET /exp](http-exec.md#get-exp)). |
| Rows changed in one transaction (`BEGIN`...`COMMIT`, `CALL`, a statement with triggers) | 10 million (the old rows are kept in memory until the end) |
| Rows one query keeps in memory under `kareladb serve` | 1 GB (`--max-result-memory`, `0` = no limit). A plain `INSERT ... SELECT` writes its rows while it reads them and is not stopped by it ([INSERT ... SELECT](insert.md#insert-select)), and neither is a plain read over the Postgres port, which sends its rows while it reads them ([big answers stream](postgres-protocol.md#streaming)). A sort (`ORDER BY` without `LIMIT`) cannot use disk: its rows must fit. |
| Groups of one `GROUP BY` or `SAMPLE BY` under `kareladb serve` | 5,000,000 (`--max-groups`, `0` = no limit). Counted as the groups are made, also those kept on disk when memory is short, so the query stops as soon as it passes the limit. |
| Rows made by `FILL` in `SAMPLE BY`, and by `generate_series` | 10 million |
| Rows one call of a [plpgsql function](procedure-language.md#plpgsql-functions) gives (`RETURN NEXT`, `RETURN QUERY`) | 10 million. They are kept until the query has read them and count against the 1 GB above and the statement's share of `--memory-limit`, which usually stop a big call first |
| `read_csv('file.csv')` ([read_csv](loading-data.md#read-csv)) | admins only, files in `<data folder>/<database>/import/` only; one row (with its quoted line breaks) at most 256 MB; every row the same number of values. A file up to 256 MB is held as columns while the statement runs when its arrays fit in 256 MB and in half of the statement's memory cap: up to about 4 times the file's size for files of short numbers (8 bytes a value), about its size for text; a bigger one streams under `GROUP BY` / aggregates and into `INSERT ... SELECT` / `CREATE TABLE ... AS`. A plain `SELECT *` keeps its rows (about 8 times the file's size, under the 1 GB above) |
| Text shown per cell in `kareladb sql` table format | 48 characters (then `...`); use `--format csv` |

**Command line: kareladb sql shows at most --max-rows rows** (sample data: sample)

```bash
kareladb sql market "SELECT time, symbol, close FROM ochl_minutes" --max-rows 2
```

Output:

```text
time                     | symbol | close
-------------------------+--------+------
2026-09-09T05:15:00.000Z | CITY   | 512.1
2026-09-09T05:16:00.000Z | CITY   | 511.9
(2 rows, more not shown, 0.5 ms)
```

**HTTP: HTTP: limit=2, and truncated is true** (sample data: sample)

```http
GET /exec?query=SELECT%20time,%20symbol,%20close%20FROM%20ochl_minutes&limit=2
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "SELECT time, symbol, close FROM ochl_minutes",
  "results": [
    {
      "statement": "SELECT time, symbol, close FROM ochl_minutes",
      "columns": [
        {"name": "time", "type": "TIMESTAMP"},
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "close", "type": "DOUBLE"}
      ],
      "dataset": [
        ["2026-09-09T05:15:00.000Z", "CITY", 512.1],
        ["2026-09-09T05:16:00.000Z", "CITY", 511.9]
      ],
      "count": 2,
      "truncated": true,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 46, "execute_us": 397}
    }
  ],
  "columns": [
    {"name": "time", "type": "TIMESTAMP"},
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "close", "type": "DOUBLE"}
  ],
  "dataset": [
    ["2026-09-09T05:15:00.000Z", "CITY", 512.1],
    ["2026-09-09T05:16:00.000Z", "CITY", 511.9]
  ],
  "count": 2,
  "timings": {"parse_us": 46, "execute_us": 397}
}
```

<a id="cursors-transactions"></a>

## Writers, readers and transactions

Syntax:

```sql
writers                 one per table; writers of different tables run at the same time
waiting for a table     5 seconds unless set (--lock-timeout, SET lock_timeout), then "table 'x' is busy"
idle transaction        rolled back after 30 seconds without a statement (--idle-in-transaction-timeout, SET idle_in_transaction_session_timeout)
open cursors            16 per database, no row limit (big ones wait on disk), closed after 10 unused minutes
```

| What | Limit |
|---|---|
| Writers at the same time | **one per table**. Writers of different tables run at the same time. A writer of a table that another writer or an open `BEGIN` ... `COMMIT` holds waits at most 5 seconds, then gets `table 'x' is busy: ...`. Change the wait for the server (`kareladb serve --lock-timeout 20s`, `KARELADB_LOCK_TIMEOUT`, `lock_timeout_ms` in `kareladb.conf`) or for one session (`SET lock_timeout = '20s'`); `0` = no limit ([lock timeout](transactions.md#lock-timeout)). |
| Two transactions that would wait for each other | one of them gets `deadlock: ...` at once |
| Schema changes (`CREATE`, `ALTER`, `DROP`) | `CREATE`, `ALTER` and `DROP TABLE`, `CREATE` and `DROP INDEX` and `CREATE`, `ALTER` and `DROP TRIGGER` wait only for writers of their table (`table 'x' is busy: ...`), and for writers of other tables only until those pause between two statements. So do `TRUNCATE`, `CREATE TABLE ... AS` (the tables its query reads) and materialized views (the view and its table). Views, procedures and functions lock no table, but a procedure or function change waits for a running writer that runs a procedure, function or plpgsql trigger (a long `CALL`), and a view change for a running writer that reads views. Sequences, `BACKUP` and a schema change sent in one request with statements it affects (`CREATE OR REPLACE PROCEDURE p ...; CALL p()`) wait for every table of the database (`database is busy: ...`). A load into a table waits while a schema change is queued for it, unless the schema change itself still waits for a writer that was there first. A statement with nothing to do (`CREATE TABLE IF NOT EXISTS` of a table that is there, `ADD COLUMN IF NOT EXISTS` of a column that is there, `DROP ... IF EXISTS` of something that is not there) waits for nothing. |
| Readers | any number, and a read never waits for another read. A read does not wait for an open `BEGIN` ... `COMMIT`: it sees the committed rows. |
| Readers during a long `CALL`, trigger, write request or checkpoint | a read of other tables never waits. A read of a table the writer holds waits until the running statement ends: the writer lets it in between its statements ([reader yield](transactions.md#reader-yield), on by default). With `--reader-yield off` it waits for the whole request. See [readers during a long writer](transactions.md#per-table-reads). |
| Background work (idle checkpoints, compression, TTL, row TTL and cache sweeps, cold pass, trash; scheduled backup copies apart) | at most `--background-threads` jobs at once in the whole server (default a quarter of the CPUs, at least 1); the others run at their next tick. Scheduled backup copies have one slot of their own: one copy at a time, and the other jobs go on during it. Between two tables or partitions a job lets waiting writes of its own database go first, at most 50 ms a piece. A checkpoint holds at most `--background-memory` of partitions at once (default a quarter of the memory limit), a quarter of that at red memory ([background share](cli-serve.md#background-share)). |
| An open transaction with no statement | rolled back after 30 seconds. Change it for the server (`--idle-in-transaction-timeout`, `KARELADB_IDLE_IN_TRANSACTION_TIMEOUT`, `idle_in_transaction_timeout_ms` in `kareladb.conf`) or one session (`SET idle_in_transaction_session_timeout = '5min'`); `0` = never ([idle transactions](transactions.md#idle-timeout)). |
| Statement timeout of `kareladb serve` | 60 s (`--statement-timeout`, `0` = none). A trigger's time counts toward the statement that fired it, also for `POST /write` and `POST /imp`. |
| How soon a timeout stops a statement | the row path checks every 1,024 rows; the column engine once per batch. One row is never stopped in the middle (a 16 MB value with a slow regular expression runs to its end). |
| Statements of one user at the same time under `kareladb serve` | 32 (`--max-queries-per-user`, `0` = no limit); a user's own with `ALTER USER u SET max_statements = n` ([users](users-and-roles.md#max-statements)) |
| Statements on one database at the same time | none unless set: `ALTER DATABASE d SET MAX_STATEMENTS = n` (1 to 100,000; admins are not held back) ([databases](databases.md#max-statements)). Over a max_statements a statement waits up to 2 s, then HTTP 429 / SQLSTATE 53300 |
| Unsaved changes before loads are held back | half of `--memory-limit`: new writes wait up to 2 s, then HTTP 503 / SQLSTATE 53200 ([back-pressure on loads](cli-serve.md#memory-limit)); none without a memory limit |
| Open cursors | 16 per database, with no row limit: each keeps its first rows in memory (1 MB to 64 MB) and the rest in a temporary file of at most `max_spill_bytes` (16 GB). An unused cursor is closed after 10 minutes. See [limits of cursors](cursors.md#limits). |
| Queued `DEFERRED` trigger jobs | 10,000 waiting in one database (`--max-trigger-jobs`, `0` = no limit). A write past it is refused with `503` and the reason ([triggers](triggers.md)) |
| Advisory locks (`pg_advisory_lock`) | wait at most 30 seconds |
| Programs with the database folder open | one (`the database is open in another program`) |
| Isolation levels | `SERIALIZABLE` (the default, by locks) and `READ COMMITTED`; `REPEATABLE READ` runs as `SERIALIZABLE` (there is no snapshot), `READ UNCOMMITTED` as `READ COMMITTED`. The rules of each level: [isolation](transactions.md#isolation-rules) |
| `READ ONLY` transactions | enforced: a change gets `25006` ([read-only transactions](transactions.md#read-only)) |

See [cursors](cursors.md) and [transactions](transactions.md).

**Example: The 17th open cursor** (shows an error)

```sql
DECLARE c1 CURSOR FOR SELECT 1 AS x;
DECLARE c2 CURSOR FOR SELECT 2 AS x;
DECLARE c3 CURSOR FOR SELECT 3 AS x;
DECLARE c4 CURSOR FOR SELECT 4 AS x;
DECLARE c5 CURSOR FOR SELECT 5 AS x;
DECLARE c6 CURSOR FOR SELECT 6 AS x;
DECLARE c7 CURSOR FOR SELECT 7 AS x;
DECLARE c8 CURSOR FOR SELECT 8 AS x;
DECLARE c9 CURSOR FOR SELECT 9 AS x;
DECLARE c10 CURSOR FOR SELECT 10 AS x;
DECLARE c11 CURSOR FOR SELECT 11 AS x;
DECLARE c12 CURSOR FOR SELECT 12 AS x;
DECLARE c13 CURSOR FOR SELECT 13 AS x;
DECLARE c14 CURSOR FOR SELECT 14 AS x;
DECLARE c15 CURSOR FOR SELECT 15 AS x;
DECLARE c16 CURSOR FOR SELECT 16 AS x;
DECLARE c17 CURSOR FOR SELECT 17 AS x;
```

Result:

`DECLARE c1 CURSOR FOR SELECT 1 AS x`

```text
cursor 'c1' declared: 1 row(s)
```

`DECLARE c2 CURSOR FOR SELECT 2 AS x`

```text
cursor 'c2' declared: 1 row(s)
```

`DECLARE c3 CURSOR FOR SELECT 3 AS x`

```text
cursor 'c3' declared: 1 row(s)
```

`DECLARE c4 CURSOR FOR SELECT 4 AS x`

```text
cursor 'c4' declared: 1 row(s)
```

`DECLARE c5 CURSOR FOR SELECT 5 AS x`

```text
cursor 'c5' declared: 1 row(s)
```

`DECLARE c6 CURSOR FOR SELECT 6 AS x`

```text
cursor 'c6' declared: 1 row(s)
```

`DECLARE c7 CURSOR FOR SELECT 7 AS x`

```text
cursor 'c7' declared: 1 row(s)
```

`DECLARE c8 CURSOR FOR SELECT 8 AS x`

```text
cursor 'c8' declared: 1 row(s)
```

`DECLARE c9 CURSOR FOR SELECT 9 AS x`

```text
cursor 'c9' declared: 1 row(s)
```

`DECLARE c10 CURSOR FOR SELECT 10 AS x`

```text
cursor 'c10' declared: 1 row(s)
```

`DECLARE c11 CURSOR FOR SELECT 11 AS x`

```text
cursor 'c11' declared: 1 row(s)
```

`DECLARE c12 CURSOR FOR SELECT 12 AS x`

```text
cursor 'c12' declared: 1 row(s)
```

`DECLARE c13 CURSOR FOR SELECT 13 AS x`

```text
cursor 'c13' declared: 1 row(s)
```

`DECLARE c14 CURSOR FOR SELECT 14 AS x`

```text
cursor 'c14' declared: 1 row(s)
```

`DECLARE c15 CURSOR FOR SELECT 15 AS x`

```text
cursor 'c15' declared: 1 row(s)
```

`DECLARE c16 CURSOR FOR SELECT 16 AS x`

```text
cursor 'c16' declared: 1 row(s)
```

Error: `too many open cursors (16); CLOSE the ones you do not need (an unused cursor also closes after 10 minutes)`

**Example: DDL inside a transaction is refused** (shows an error)

```sql
BEGIN;
CREATE TABLE notes (id LONG PRIMARY KEY, body STRING);
```

Result:

```text
transaction started
```

Error: `CREATE TABLE cannot be used inside a transaction; COMMIT or ROLLBACK first (the transaction was rolled back)`

<a id="http"></a>

## Server and HTTP

Syntax:

```sql
request body     64 MB (also after gzip or deflate is unpacked)
request headers  64 KB
idle connection  closed after 30 seconds
worker threads   one per CPU thread, at least 8 (--http-threads)
pg connections   500 (--max-connections)
```

| What | Limit |
|---|---|
| HTTP request body (SQL text, line protocol, CSV) | 64 MB. A body sent with `Content-Encoding: gzip` or `deflate` is unpacked first, and the unpacked body is also at most 64 MB. Send big loads in several requests. |
| HTTP replies | answers of 2 KB or more are compressed (gzip) for a client that asks for it and is beyond this computer and its private networks; `--http-gzip on` for every client, `off` for none ([compressed answers](http-overview.md#gzip-answers)) |
| HTTP request headers | 64 KB |
| Requests handled at the same time | one worker thread per CPU thread, at least 8 and at most 64 by default. Set it with `kareladb serve --http-threads N` (1 to 1024), `KARELADB_HTTP_THREADS` or `http_threads` in `kareladb.conf`. Fast and slow requests share the workers: more slow statements than workers make other requests wait for a free one (in a test with 8 workers, 12 slow scans made a `SELECT 1` wait 18.6 s). |
| PostgreSQL connections | 500 logged-in connections for the whole server, all databases together. Set it with `kareladb serve --max-connections N` (`0` = no limit), `KARELADB_MAX_CONNECTIONS` or `max_connections` in `kareladb.conf`. A closed connection's place is free again at once. One more gets `53300`. |
| A keep-alive connection with no new request | closed after 35 seconds (answers advertise `Keep-Alive: timeout=30`; the 5 extra seconds keep a request sent right at 30 seconds from meeting the close) |
| A started request must arrive within | 30 seconds |
| Failed logins | after 5 failures for one user from one address (or 20 from one address), waits of 1 s, 2 s, 4 s ... up to 15 minutes |
| Web console login | 12 hours |
| HTTPS | `--tls-cert` ([TLS](tls.md)), or a reverse proxy |

See [server security](server-security.md) and [HTTP exec](http-exec.md).

**Command line: The server's defaults are in its banner** (sample data: sample)

```bash
kareladb serve ./market
```

Output:

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      ./market
  backups   ./_backups/market (from default)
  access    no token
  capacity  32 HTTP threads (default), 500 PostgreSQL connections (default), lock wait 5 s (default)
  lanes     reads using 100 ms of CPU (three times in a row) wait for one of 16 heavy slots, at most 16 HTTP in line (--lanes on)
  reads     32 reads run at once (the CPUs, at least 2; follows the CPU limit), the rest wait in line (--read-slots)
  commits   synced to disk before they are confirmed (--sync-commits always)
  time zone Asia/Katmandu (the computer's); also timers and backup schedules
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    26.95 GB for the whole process (85% of the machine's memory); table data 512.0 MB of it (--memory)
  background 8 jobs at once (default); share 6.74 GB (default), checkpoint waves up to 128.0 MB
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log off
  logs      slow queries >= 1000 ms to ./market/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 2 ms: manifest 0 ms, 1 files read 1 ms (8 table files left for their first use), log check 0 ms, replay 1 ms (0 transactions), clean-up 0 ms

Press Ctrl+C to stop.
```

<a id="disk-memory"></a>

## Disk and memory

Syntax:

```sql
free disk space     writes stop below 64 MB free
disk full           HTTP 507 {"code":"disk full"}, PostgreSQL SQLSTATE 53100
old file versions   2 per file, then _trash for 1 hour
log archive         1 GB per database by default; SET WAL_ARCHIVE changes it
memory for data     --memory, default 512 MB for all open databases together
```

| What | Limit |
|---|---|
| Free disk space | writes (and checkpoints) are refused when less than 64 MB is free; they work again when there is space |
| A full disk | the write fails with HTTP 507 `{"code":"disk full", ...}` (PostgreSQL port: SQLSTATE `53100`). Rows already committed stay, and nothing is half written. |
| A full disk with the default log mode | `kareladb serve` commits with a group flush (`--sync-commits always`). If that flush hits a full disk, the writes in it get 507 with `The rows of this write are applied in memory and reach the log once disk space is freed`. Reads go on, later writes get 507 until there is room, and then everything works again with no restart. Those refused rows are lost only if the server stops before space is freed. Rarely (the disk refuses the flush after it took the data), the log stops instead: reads go on, writes say `reopen the database to recover`. |
| A full disk with `--sync-commits batch` | reads go on, and writes work again when there is space. But if the disk fills at the moment the log is flushed, the writes confirmed since the last flush (every 10 ms) are lost, and the database must be reopened. |
| An `INSERT` that got 507 | can still be committed: the checkpoint that runs after a commit can fail on its own and report the full disk. Count the rows before you send them again. |
| Previous versions of each data file | 2 (for the repair ladder; `keep_versions` in `kareladb.conf` or `KARELADB_KEEP_VERSIONS`, 0 to 10); fewer once the old log they need is gone |
| Replaced files in `_trash` | removed after 1 hour (`trash_keep_hours` in `kareladb.conf` or `KARELADB_TRASH_KEEP_HOURS`), or sooner beyond `trash_max_mb` (a quarter of the data, at least 256 MB, unless set) |
| A dropped table | kept 7 days for `UNDROP TABLE` (`--trash-days`) |
| Old log files (`wal_archive`) | 1 GB per database by default; the oldest are deleted. Change it per database with [ALTER DATABASE ... SET WAL_ARCHIVE](databases.md#wal-archive), or for all with `wal_archive_mb` on the [Settings page](console-settings.md#wal-archive). `OFF` keeps none. |
| One log file (`wal/*.log`) | 64 MB, then a new file starts |
| One log record | 256 MB (big changes are split into several records) |
| Memory for loaded table data | `--memory`, default 512 MB for all open databases of `kareladb serve` together |
| Memory for one plain or full-text index | 2 GB (`index_memory_bytes`); a bigger index is not built and queries read the table |
| Memory for repeated query results | `--cache-mb`, default 256 MB (at most a tenth of the memory limit) for all open databases together. One result may use a quarter of it, a [pinned query](pinned-queries.md) three quarters. |
| Temporary files of one big `GROUP BY` or `SAMPLE BY` | 16 GB (`max_spill_bytes`), in `_tmp/` of the database folder; used when the groups need more than half of `--max-result-memory`, removed when the query ends |
| Temporary files of one big hash join | the same 16 GB (`max_spill_bytes`), in `_tmp/`; used when the joined table needs more than three quarters of the statement's working memory (half for `RIGHT` / `FULL JOIN`; or `SET work_mem`) and both tables fit in the 16 GB, 4 to 256 parts per table, removed when the query ends ([a join bigger than memory](joins.md#join-spill)) |
| Temporary files of one `INSERT ... SELECT ... ORDER BY` | the same 16 GB (`max_spill_bytes`), in `_tmp/`; the rows are sorted in batches of up to 64 MB, removed when the statement ends |
| Full-text search: one word | 256 bytes (a longer word is cut) |
| Full-text search text | 1,024 words, phrases and synonyms after the synonyms are added; parentheses 32 deep; a fuzzy word `~1` or `~2` edits ([search text](full-text-search.md#search-syntax)) |
| Full-text synonym list | 1 MB; 64 terms in a group; a word in one group only ([synonyms](full-text-search.md#synonyms)) |
| [Zone maps](performance-tips.md#zone-maps) | skip only partitions that are in memory. A partition not loaded since the open is read, unless a whole-table `count`, `sum`, `min` or `max` is answered from [saved stats](performance-tips.md#saved-stats). |

**Command line: Sizes and log positions of the files** (sample data: sample)

```bash
kareladb info market
```

Output:

```text
database        market
manifest        copy a, sequence 9
last shutdown   clean
log position    30 (saved in files up to 30)
newest change   2026-11-18 13:46:57
features        batched_log_sync, block_stats, compressed_log, partition_format_2
manifest keys   26

FILE                                      VERSION       SIZE          LSN  STATUS
catalog                                         6     2.1 KB           30  ok
t/1/all                                         7      777 B           30  ok
t/2/all                                         8      556 B           30  ok
t/3/2025                                        9     1.7 KB           30  ok
t/3/2026                                       10     3.6 KB           30  ok
t/4/2026-09                                    11    57.0 KB           30  ok
t/5/2026-09-09                                 12     1.4 KB           30  ok
t/5/2026-09-10                                 13     2.4 KB           30  ok
t/6/2026-09-10                                 14     2.7 KB           30  ok

9 files, 72.1 KB, 0 marked damaged
(STATUS is what the manifest records. To read every block and find new damage, run: kareladb check)
```

<a id="switches"></a>

## Switches for measuring

These environment variables turn one speed-up off, so you can time a query with and without it. The answers are the same either way. Set them for `kareladb serve` only while you measure.

| Variable | Turns off |
|---|---|
| `KARELADB_NO_ZONE_MAPS=1` | skipping partitions by their min and max, and answers from [saved stats](performance-tips.md#saved-stats) |
| `KARELADB_NO_COLUMN_MASK=1` | building only the columns a query reads ([column mask](performance-tips.md#column-mask)) |
| `KARELADB_NO_UNION_PUSHDOWN=1` | grouping a `GROUP BY` over a `UNION ALL` part by part |

For one query, `/exec?cache=0` skips the result cache (see [performance tips](performance-tips.md#measure)).

<a id="not-supported"></a>

## Not supported yet

Syntax:

```sql
DDL in a transaction   SELECT ... INTO   microsecond times
```

Short list. The details, and the ways around each one, are in [known limitations](../tutorial/known-limitations.md).

| Area | Not there yet |
|---|---|
| Statements | `CREATE`/`DROP`/`ALTER` inside a transaction or procedure; `SELECT ... INTO`; `MERGE` into a table with row-level security policies for the user |
| Changing a table | `PARTITION BY` and `SORT BY` of an existing table; the type of the time column or of a `SORT BY` / `DEDUP KEY` column; dropping the `PRIMARY KEY` |
| Queries | A window function inside an aggregate (`sum(lag(x))`: use a subquery); `IGNORE NULLS` only for first_value, last_value, and lag / lead with an offset of 1; `WITHIN GROUP (ORDER BY x DESC)` (use `1 - fraction`); `LIKE ... ESCAPE`, `BETWEEN SYMMETRIC`, `WITH ORDINALITY` |
| Procedures and triggers | `OUT` parameters of procedures; a plpgsql function that returns one plain value (`RETURNS INT ... RETURN n`) is only recorded, and a plpgsql function a query calls cannot change data ([plpgsql functions](procedure-language.md#plpgsql-functions) with `OUT` parameters, `RETURNS TABLE` and `RETURNS SETOF` work); `INSTEAD OF` triggers; a `BEFORE ... FOR EACH ROW` trigger's statements may not change its own table (refused, see [triggers](triggers.md#for-each-row)) |
| Transactions | `REPEATABLE READ` is a table lock, not a snapshot ([isolation rules](transactions.md#isolation-rules)). Row-level locks cover `UPDATE` / `DELETE` by primary key and `SELECT ... FOR UPDATE` on one table; an `INSERT`, or a change of a table without a primary key or with a secondary `UNIQUE` or a `FOREIGN KEY`, still locks its whole table until `COMMIT`, so `SKIP LOCKED` inside `BEGIN` returns no rows (and `NOWAIT` fails) while another transaction holds that table that way, unless `kareladb serve --skip-locked-beside on`. `FOR SHARE`, `FOR NO KEY UPDATE` and `FOR KEY SHARE` take the same lock as `FOR UPDATE`: two sessions cannot share a row lock, the second one waits (stricter than PostgreSQL, never looser; see [FOR UPDATE](transactions.md#for-update)). |
| Text and JSON | regular expression back references and look-around; wildcards in the simple paths of `json_extract` and `->` (`$.items[*]`: use `jsonb_path_query`, which has the whole PostgreSQL JSON path language) |
| Server | CORS, a Windows service mode; turning TLS on or off, or other certificate file names, need a restart (a renewed certificate in the same files is taken in without one: [renew](tls.md#reload)) |
| PostgreSQL port | pgAdmin's own catalog queries (psql `\d` and DBeaver work); API tokens as passwords; the error Detail line (`D`) of a duplicate in an expression `UNIQUE` index (`lower(email)`), and the readable columns of a `Failing row` that has a hidden one ([error fields](postgres-protocol.md#errors)) |
| Users | A view, a `CALL` and a trigger run with the rights of the user who saved them (like `SECURITY DEFINER`): table rights are checked when a `ddl` user saves one, not each time someone uses it ([table rights](table-rights.md)); `kareladb sql` and `kareladb shell` never ask for a login; no two-factor login over HTTP Basic or the PostgreSQL port |
| Files | `read_csv` options beyond `header`, `delim` / `sep`, `columns` and `auto_detect` (no `quote`, `escape`, `skip`, `nullstr`, `dateformat`, globs, compressed files); no `read_parquet` / `read_json`; `COPY ... FROM 'file'` (use `read_csv`) |
| Key-value store ([kv](kv.md)) | streams (`XADD` ...), bitmaps (`SETBIT`), HyperLogLog (`PFADD`), geo (`GEOADD`), Lua scripts (`EVAL`), `SELECT n` (use `?db=`), `CLIENT TRACKING`, `DUMP` / `RESTORE`, a RESP port for `redis-cli` (use `POST /kv`). Eviction policies are Redis's six: `noeviction`, `allkeys-lru`, `volatile-lru`, `allkeys-random`, `volatile-random`, `volatile-ttl` |
| Other databases | writing into another database (`INSERT INTO otherdb.t` is refused; reading it works, see [queries across databases](cross-database-queries.md)) |
