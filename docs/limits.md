# Limits

> The sizes and counts KDB allows, what happens at each limit, and the features that are not there yet.

- Category: Limits
- Keywords: limit, limits, maximum, max, how big, how many, too big, too many, nested too deeply, 16 MB, 64 MB, 10 million, DECIMAL scale, name length, too many open cursors, lock timeout, database is busy, table is busy, deadlock, idle transaction, request body, 10,000 rows, truncated, disk full, 507, 53100, statement timeout, max-queries-per-user, max-groups, max-result-memory, max_spill_bytes, KDB_NO_ZONE_MAPS, KDB_NO_COLUMN_MASK, KDB_NO_UNION_PUSHDOWN, switches, reader yield, not supported, missing features, known limitations, not available
- See also: [Performance tips](performance-tips.md), [Cursors (limits)](cursors.md#limits), [Transactions](transactions.md), [Run SQL over HTTP (/exec, /exp)](http-exec.md), [How KDB stores data](data-formats.md), [Protection - timeouts, limits, safe updates, read-only](protection.md)

These are the limits of KDB `0.2.0-dev` (September 2026). Most of them are there to protect memory and to give a clear error instead of a crash.
When a limit is reached, the statement fails with an error that names the limit, and **nothing** of that statement is saved.

The full list of missing features is in [known limitations](../tutorial/known-limitations.md). Please check again after you update KDB.

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
kdb sql / kdb shell     1,000 rows per result in table format (--max-rows, .maxrows)
HTTP /exec              10,000 rows by default, at most 1,000,000 (limit=)
HTTP /exp               1,000,000 rows by default, any number with limit= (streamed)
one transaction         10 million changed rows
one query (kdb serve)   1 GB of rows in memory, 5,000,000 groups
```

| What | Limit |
|---|---|
| Rows, tables, partitions, databases | **no fixed limit** (the disk is the limit) |
| Rows shown by `kdb sql` and `kdb shell` in table format | 1,000 (change with `--max-rows N` / `.maxrows N`; `0` = all). CSV and JSON: no limit. |
| Rows returned by HTTP `/exec` | 10,000 unless you pass `limit=`, at most 1,000,000. A cut answer has `"truncated": true`: check it, or you read (and time) a short answer. |
| Rows exported by HTTP `/exp` | 1,000,000 unless you pass `limit=`, then any number: a plain read of one table is streamed, never held whole. `X-KDB-Truncated: true` says rows were cut ([GET /exp](http-exec.md#get-exp)). |
| Rows changed in one transaction (`BEGIN`...`COMMIT`, `CALL`, a statement with triggers) | 10 million (the old rows are kept in memory until the end) |
| Rows one query keeps in memory under `kdb serve` | 1 GB (`--max-result-memory`, `0` = no limit). A plain `INSERT ... SELECT` writes its rows while it reads them and is not stopped by it ([INSERT ... SELECT](insert.md#insert-select)), and neither is a plain read over the Postgres port, which sends its rows while it reads them ([big answers stream](postgres-protocol.md#streaming)). A sort (`ORDER BY` without `LIMIT`) cannot use disk: its rows must fit. |
| Groups of one `GROUP BY` or `SAMPLE BY` under `kdb serve` | 5,000,000 (`--max-groups`, `0` = no limit). Counted as the groups are made, also those kept on disk when memory is short, so the query stops as soon as it passes the limit. |
| Rows made by `FILL` in `SAMPLE BY`, and by `generate_series` | 10 million |
| Text shown per cell in `kdb sql` table format | 48 characters (then `...`); use `--format csv` |

**Command line: kdb sql shows at most --max-rows rows** (sample data: sample)

```bash
kdb sql market "SELECT time, symbol, close FROM ochl_minutes" --max-rows 2
```

Output:

```text
time                     | symbol | close
-------------------------+--------+------
2026-09-09T05:15:00.000Z | CITY   | 512.1
2026-09-09T05:16:00.000Z | CITY   | 511.9
(2 rows, more not shown, 0.3 ms)
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
      "timings": {"parse_us": 30, "execute_us": 287}
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
  "timings": {"parse_us": 30, "execute_us": 287}
}
```

<a id="cursors-transactions"></a>

## Writers, readers and transactions

Syntax:

```sql
writers                 one per table; writers of different tables run at the same time
waiting for a table     5 seconds unless set (--lock-timeout, SET lock_timeout), then "table 'x' is busy"
idle transaction        rolled back after 30 seconds without a statement (--idle-in-transaction-timeout, SET idle_in_transaction_session_timeout)
open cursors            16 per database, 10 million rows each, closed after 10 unused minutes
```

| What | Limit |
|---|---|
| Writers at the same time | **one per table**. Writers of different tables run at the same time. A writer of a table that another writer or an open `BEGIN` ... `COMMIT` holds waits at most 5 seconds, then gets `table 'x' is busy: ...`. Change the wait for the server (`kdb serve --lock-timeout 20s`, `KDB_LOCK_TIMEOUT`, `lock_timeout_ms` in `kdb.conf`) or for one session (`SET lock_timeout = '20s'`); `0` = no limit ([lock timeout](transactions.md#lock-timeout)). |
| Two transactions that would wait for each other | one of them gets `deadlock: ...` at once |
| Schema changes (`CREATE`, `ALTER`, `DROP`) | `CREATE`, `ALTER` and `DROP TABLE`, `CREATE` and `DROP INDEX` and `CREATE`, `ALTER` and `DROP TRIGGER` wait only for writers of their table (`table 'x' is busy: ...`), and for writers of other tables only until those pause between two statements. So do `TRUNCATE`, `CREATE TABLE ... AS` (the tables its query reads) and materialized views (the view and its table). Views, procedures and functions lock no table, but a procedure or function change waits for a running writer that runs a procedure, function or plpgsql trigger (a long `CALL`), and a view change for a running writer that reads views. Sequences, `BACKUP` and a schema change sent in one request with statements it affects (`CREATE OR REPLACE PROCEDURE p ...; CALL p()`) wait for every table of the database (`database is busy: ...`). A load into a table waits while a schema change is queued for it, unless the schema change itself still waits for a writer that was there first. A statement with nothing to do (`CREATE TABLE IF NOT EXISTS` of a table that is there, `ADD COLUMN IF NOT EXISTS` of a column that is there, `DROP ... IF EXISTS` of something that is not there) waits for nothing. |
| Readers | any number, and a read never waits for another read. A read does not wait for an open `BEGIN` ... `COMMIT`: it sees the committed rows. |
| Readers during a long `CALL`, trigger, write request or checkpoint | a read of other tables never waits. A read of a table the writer holds waits until the running statement ends: the writer lets it in between its statements ([reader yield](transactions.md#reader-yield), on by default). With `--reader-yield off` it waits for the whole request. See [readers during a long writer](transactions.md#per-table-reads). |
| An open transaction with no statement | rolled back after 30 seconds. Change it for the server (`--idle-in-transaction-timeout`, `KDB_IDLE_IN_TRANSACTION_TIMEOUT`, `idle_in_transaction_timeout_ms` in `kdb.conf`) or one session (`SET idle_in_transaction_session_timeout = '5min'`); `0` = never ([idle transactions](transactions.md#idle-timeout)). |
| Statement timeout of `kdb serve` | 60 s (`--statement-timeout`, `0` = none). A trigger's time counts toward the statement that fired it, also for `POST /write` and `POST /imp`. |
| How soon a timeout stops a statement | the row path checks every 1,024 rows; the column engine once per batch. One row is never stopped in the middle (a 16 MB value with a slow regular expression runs to its end). |
| Statements of one user at the same time under `kdb serve` | 32 (`--max-queries-per-user`, `0` = no limit) |
| Open cursors | 16 per database. Each keeps at most 10 million rows in memory. An unused cursor is closed after 10 minutes. |
| Queued `DEFERRED` trigger jobs | no cap yet |
| Advisory locks (`pg_advisory_lock`) | wait at most 30 seconds |
| Programs with the database folder open | one (`the database is open in another program`) |
| Isolation levels | `SERIALIZABLE` (the default) and `READ COMMITTED` ([isolation](transactions.md#isolation)); `REPEATABLE READ` runs as `SERIALIZABLE` |
| `READ ONLY` transactions | accepted, not enforced |

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
| HTTP replies | not compressed |
| HTTP request headers | 64 KB |
| Requests handled at the same time | one worker thread per CPU thread, at least 8 and at most 64 by default. Set it with `kdb serve --http-threads N` (1 to 1024), `KDB_HTTP_THREADS` or `http_threads` in `kdb.conf`. Fast and slow requests share the workers: more slow statements than workers make other requests wait for a free one (in a test with 8 workers, 12 slow scans made a `SELECT 1` wait 18.6 s). |
| PostgreSQL connections | 500 logged-in connections for the whole server, all databases together. Set it with `kdb serve --max-connections N` (`0` = no limit), `KDB_MAX_CONNECTIONS` or `max_connections` in `kdb.conf`. A closed connection's place is free again at once. One more gets `53300`. |
| A keep-alive connection with no new request | closed after 35 seconds (answers advertise `Keep-Alive: timeout=30`; the 5 extra seconds keep a request sent right at 30 seconds from meeting the close) |
| A started request must arrive within | 30 seconds |
| Failed logins | after 5 failures for one user from one address (or 20 from one address), waits of 1 s, 2 s, 4 s ... up to 15 minutes |
| Web console login | 12 hours |
| HTTPS | `--tls-cert` ([TLS](tls.md)), or a reverse proxy |

See [server security](server-security.md) and [HTTP exec](http-exec.md).

**Command line: The server's defaults are in its banner** (sample data: sample)

```bash
kdb serve ./market
```

Output:

```text
KDB 0.2.0-dev
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
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log off
  logs      slow queries >= 1000 ms to ./market/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 2 ms: manifest 1 ms, 1 files read 0 ms (8 table files left for their first use), log check 1 ms, replay 0 ms (0 transactions), clean-up 0 ms

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
| A full disk with the default log mode | `kdb serve` commits with a group flush (`--sync-commits always`). If that flush hits a full disk, the writes in it get 507 with `The rows of this write are applied in memory and reach the log once disk space is freed`. Reads go on, later writes get 507 until there is room, and then everything works again with no restart. Those refused rows are lost only if the server stops before space is freed. Rarely (the disk refuses the flush after it took the data), the log stops instead: reads go on, writes say `reopen the database to recover`. |
| A full disk with `--sync-commits batch` | reads go on, and writes work again when there is space. But if the disk fills at the moment the log is flushed, the writes confirmed since the last flush (every 10 ms) are lost, and the database must be reopened. |
| An `INSERT` that got 507 | can still be committed: the checkpoint that runs after a commit can fail on its own and report the full disk. Count the rows before you send them again. |
| Previous versions of each data file | 2 (for the repair ladder; `keep_versions` in `kdb.conf` or `KDB_KEEP_VERSIONS`, 0 to 10); fewer once the old log they need is gone |
| Replaced files in `_trash` | removed after 1 hour (`trash_keep_hours` in `kdb.conf` or `KDB_TRASH_KEEP_HOURS`), or sooner beyond `trash_max_mb` (a quarter of the data, at least 256 MB, unless set) |
| A dropped table | kept 7 days for `UNDROP TABLE` (`--trash-days`) |
| Old log files (`wal_archive`) | 1 GB per database by default; the oldest are deleted. Change it per database with [ALTER DATABASE ... SET WAL_ARCHIVE](databases.md#wal-archive), or for all with `wal_archive_mb` on the [Settings page](console-settings.md#wal-archive). `OFF` keeps none. |
| One log file (`wal/*.log`) | 64 MB, then a new file starts |
| One log record | 256 MB (big changes are split into several records) |
| Memory for loaded table data | `--memory`, default 512 MB for all open databases of `kdb serve` together |
| Memory for one plain or full-text index | 2 GB (`index_memory_bytes`); a bigger index is not built and queries read the table |
| Memory for repeated query results | `--cache-mb`, default 64 MB for all open databases together. One result may use an eighth of it, a [pinned query](pinned-queries.md) half. |
| Temporary files of one big `GROUP BY` or `SAMPLE BY` | 16 GB (`max_spill_bytes`), in `_tmp/` of the database folder; used when the groups need more than half of `--max-result-memory`, removed when the query ends |
| Temporary files of one `INSERT ... SELECT ... ORDER BY` | the same 16 GB (`max_spill_bytes`), in `_tmp/`; the rows are sorted in batches of up to 64 MB, removed when the statement ends |
| Full-text search: one word | 256 bytes (a longer word is cut) |
| [Zone maps](performance-tips.md#zone-maps) | skip only partitions that are in memory. A partition not loaded since the open is read, unless a whole-table `count`, `sum`, `min` or `max` is answered from [saved stats](performance-tips.md#saved-stats). |

**Command line: Sizes and log positions of the files** (sample data: sample)

```bash
kdb info market
```

Output:

```text
database        market
manifest        copy a, sequence 9
last shutdown   clean
log position    30 (saved in files up to 30)
newest change   2026-10-22 11:28:27
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
(STATUS is what the manifest records. To read every block and find new damage, run: kdb check)
```

<a id="switches"></a>

## Switches for measuring

These environment variables turn one speed-up off, so you can time a query with and without it. The answers are the same either way. Set them for `kdb serve` only while you measure.

| Variable | Turns off |
|---|---|
| `KDB_NO_ZONE_MAPS=1` | skipping partitions by their min and max, and answers from [saved stats](performance-tips.md#saved-stats) |
| `KDB_NO_COLUMN_MASK=1` | building only the columns a query reads ([column mask](performance-tips.md#column-mask)) |
| `KDB_NO_UNION_PUSHDOWN=1` | grouping a `GROUP BY` over a `UNION ALL` part by part |

For one query, `/exec?cache=0` skips the result cache (see [performance tips](performance-tips.md#measure)).

<a id="not-supported"></a>

## Not supported yet

Syntax:

```sql
NATURAL JOIN   DDL in a transaction
```

Short list. The details, and the ways around each one, are in [known limitations](../tutorial/known-limitations.md).

| Area | Not there yet |
|---|---|
| Statements | `CREATE`/`DROP`/`ALTER` inside a transaction or procedure; `SELECT ... INTO` |
| Changing a table | `PARTITION BY` and `SORT BY` of an existing table; the type of the time column or of a `SORT BY` / `DEDUP KEY` column; dropping the `PRIMARY KEY` |
| Queries | `NATURAL JOIN` (write `JOIN ... USING (columns)`); `ASOF JOIN ... TOLERANCE`; a series function inside another (`lag(sma(x, 3))`); `GROUPS` frames, named windows, `IGNORE NULLS` |
| Procedures and triggers | exception handlers, `LOOP`, `OUT` parameters, functions that return tables, `INSTEAD OF` triggers; row triggers (`FOR EACH ROW`) only as a PostgreSQL `BEFORE UPDATE` trigger |
| Transactions | Only `SELECT ... FOR UPDATE` on one table with a primary key locks rows; a change (`UPDATE`, `DELETE`, `INSERT`) still locks its whole table until `COMMIT`, so `SKIP LOCKED` inside `BEGIN` returns no rows (and `NOWAIT` fails) while another transaction has changed that table, unless `kdb serve --skip-locked-beside on`. `FOR SHARE`, `FOR NO KEY UPDATE` and `FOR KEY SHARE` take the same lock as `FOR UPDATE`: two sessions cannot share a row lock, the second one waits (stricter than PostgreSQL, never looser; see [FOR UPDATE](transactions.md#for-update)). |
| Text and JSON | regular expression back references and look-around, JSON path wildcards (`$.items[*]`), `json_each`, the `jsonb` operator `?` |
| Time | summer time in `ROUND ... TIME ZONE`, `time IN ... TIME ZONE` and the zone argument of `date_trunc` / `to_char` (fixed offsets only there) |
| Server | CORS, compressed replies, a Windows service mode; TLS certificates are read at start (restart after renewing one) |
| PostgreSQL port | pgAdmin's own catalog queries (psql `\d` and DBeaver work); API tokens as passwords |
| Users | rights per column or row (rights are per database, and per table with `GRANT ... ON TABLE`); `kdb sql` and `kdb shell` never ask for a login |
| Other databases | writing into another database (`INSERT INTO otherdb.t` is refused; reading it works, see [queries across databases](cross-database-queries.md)) |

**Example: NATURAL JOIN is not there yet** (sample data: sample; shows an error)

```sql
SELECT * FROM brokers b NATURAL JOIN brokers c;
```

Result:

Error: `line 1, column 25: expected JOIN, LEFT JOIN, RIGHT JOIN, FULL JOIN, ASOF JOIN, LT JOIN, SPLICE JOIN, CROSS JOIN, WHERE, LATEST ON, SAMPLE BY, GROUP BY, UNION ALL, ORDER BY, LIMIT, ';' or the end of the input but found 'NATURAL'`
