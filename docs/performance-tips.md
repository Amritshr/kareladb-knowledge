# Performance tips

> Make loading and queries fast - memory, threads, batch commits, bulk INSERTs, good table design, time filters, what the column engine takes, zone maps, saved stats, and how to measure.

- Category: Performance tips
- Keywords: performance, speed, slow query, fast, tuning, column engine, row path, zone maps, skipped by column stats, KARELADB\_NO\_ZONE\_MAPS, slice reads, one symbol not in memory, KARELADB\_NO\_SLICE\_READS, slice\_reads, saved stats, answer from saved stats, column mask, KARELADB\_NO\_COLUMN\_MASK, keyless table, DEFERRED trigger, cache, EXPLAIN lines, memory, --memory, threads, --threads, --sync-commits, batch commits, synchronous\_commit, SET synchronous\_commit, X-KDB-Synchronous-Commit, group commit, bulk insert, batch size, rows per INSERT, result cache, --cache-mb, KARELADB\_CACHE\_VERIFY, cache per symbol, benchmark, kdb\_bench, timings, EXPLAIN, partition pruning, time filter, SYMBOL, LATEST ON, LIMIT, index, line protocol, checkpoint
- See also: [EXPLAIN](explain.md), [Indexes](indexes.md), [Line protocol (POST /write)](line-protocol.md), [Partitions, SORT BY and DEDUP KEY](partitions-and-dedup.md), [LATEST ON](latest-on.md), [Column types](column-types.md), [kareladb serve](cli-serve.md), [Limits](limits.md)

KarelaDB is fast for the work it was made for: chart queries on one symbol or one sensor, live commits, bulk loads.
Some queries that read **every row** of a big table are still slow. This page tells you how to avoid them, and how to measure.

The first rule: **measure first.** Look at the time KarelaDB prints (`(3 rows, 0.4 ms)`) and at [EXPLAIN](explain.md), then change one thing at a time.

<a id="measure"></a>

## Measure: timings and EXPLAIN

Syntax:

```sql
kareladb sql <db> "SELECT ..."        -- table format ends with (N rows, X ms)
EXPLAIN SELECT ...                -- how KarelaDB will read the data
```

- `kareladb sql` and `kareladb shell` print `(N rows, X ms)` after each result: the time to parse and run the statement, without opening the database.
- The HTTP API gives `timings` (`parse_us`, `execute_us`, in microseconds) with each result (see [HTTP exec](http-exec.md)).
- `EXPLAIN` shows how many **partitions** are read (`1 of 12 partitions`), whether only a **key range** is read, whether an **index** is used, and on its last line which **engine** reads the table (`engine: column` is the fast one; `engine: row (...)` says why not).
- Run a query twice. The first run may read files from disk; the second is warm.
- With `kareladb serve`, a repeated query comes from the [result cache](#result-cache). To time the engine, add `cache=0`: `GET /exec?query=...&cache=0`. A benchmark without it times the cache, not the query.
- `/exec` answers at most 10,000 rows unless you pass `limit`, and then says `"truncated": true`. Check that flag before you compare times: a cut answer is faster.
- For bigger tests there is `kdb_bench` (see `bench/README.md`).

**Command line: The time is on the last line** (sample data: sample)

```bash
kareladb sql market "SELECT symbol, round(avg(close), 2) AS avg_close FROM ochl_minutes WHERE time IN '2026-09-10' GROUP BY symbol"
```

Output:

```text
symbol | avg_close
-------+----------
CITY   |    504.24
COAST  |    378.36
(2 rows, 0.5 ms)
```

**Example: EXPLAIN: a time filter and a symbol read only one key range** (sample data: sample)

```sql
EXPLAIN SELECT time, close FROM ochl_minutes WHERE symbol = 'CITY' AND time IN '2026-09-10';
```

Result:

| plan (STRING) |
|---|
| scan table ochl_minutes (1 of 1 partitions, about 956 rows) |
| read only 1 key range(s) of each partition |
| build 3 of 7 stored column(s) per row: time, symbol, close |
| filter while scanning: 2 condition(s) |
| engine: column |

(5 rows)

**Example: EXPLAIN without filters: every row is read** (sample data: sample)

```sql
EXPLAIN SELECT count(*) FROM ochl_minutes WHERE close > 500;
```

Result:

| plan (STRING) |
|---|
| scan table ochl_minutes (1 of 1 partitions, about 956 rows) |
| build 2 of 7 stored column(s) per row: time, close |
| filter while scanning: 1 condition(s) |
| group by 0 key(s), 1 aggregate(s) |
| engine: column |

(5 rows)

<a id="explain-lines"></a>

## EXPLAIN lines to look for

| Line in EXPLAIN | What it tells you |
|---|---|
| `scan table t (k of n partitions, ...)` | Only `k` files are read. A small `k` means the time filter works. |
| `..., m skipped by column stats)` | [Zone maps](#zone-maps) left out `m` more files by their min and max. |
| `answer from saved stats of table t: ...` | `count`, `sum`, `min`, `max` come from [saved stats](#saved-stats). No row is read. |
| `read only k key range(s) of each partition` | `symbol = ...` on the first sort column reads only those rows. |
| `use index name (...)` | An [index](#indexes) finds the rows. |
| `build k of n stored column(s) per row: ...` | The row path builds only these columns ([column mask](#column-mask)). |
| `aggregates pushed into the N UNION ALL parts` | A `GROUP BY` over a `UNION ALL` is grouped part by part ([many groups](#many-groups)). |
| `join (nested loop) ...` | The join has no `a = b` condition: every row meets every row. Slow on big tables. |

All lines are explained in [EXPLAIN](explain.md#plan-lines).

<a id="time-filter"></a>

## Filter on time and symbol first

Syntax:

```sql
WHERE symbol = 'CITY' AND time IN '2026-09'
WHERE symbol IN ('CITY', 'COAST') AND time >= '2026-09-01' AND time < '2026-10-01'
```

On a time-series table, a condition on the **time column** skips whole partitions (files), and `symbol = ...` or `symbol IN (...)` on the first key column jumps straight to those rows.

- Always add a time range to queries on big tables: `time IN '2026-09'`, `time >= '2026-09-01'`.
- `symbol = 'X'`, `symbol IN ('X', 'Y')` and `symbol = 'X' OR symbol = 'Y'` on a `SYMBOL` column also skip the partitions that have **no row** of those symbols. KarelaDB knows which symbols each partition holds without reading it. A symbol that traded for 3 months of 10 years reads 3 partitions.
- A symbol that is in every partition still reads every partition. Add a time range for those.
- A function around the column (`date_trunc('d', time) = ...`, `lower(symbol) = ...`) cannot skip anything. Compare the column itself.
- Select only the columns you need. `SELECT *` on 20 million rows moves much more data.
- `OR` between different columns reads everything; `IN (...)` on one column does not.

**Example: One symbol, one day: fast even on 20 million rows** (sample data: sample)

```sql
SELECT time, open, high, low, close FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
LIMIT 5;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T05:15:00.000Z | 504.6 | 504.6 | 504.4 | 504.4 |
| 2026-09-10T05:16:00.000Z | 504.4 | 504.7 | 504.3 | 504.6 |
| 2026-09-10T05:17:00.000Z | 504.6 | 504.9 | 504 | 504.2 |
| 2026-09-10T05:18:00.000Z | 504.2 | 504.6 | 504.1 | 504.4 |
| 2026-09-10T05:19:00.000Z | 504.4 | 504.8 | 504.1 | 504.5 |

(5 rows)

<a id="parameters"></a>

## Parameters, variables and computed dates

Syntax:

```sql
WHERE time >= d AND time < dateadd('d', 1, d)     -- d: a procedure parameter or variable
WHERE time >= dateadd('d', -30, '2026-09-11')
```

A procedure parameter, a variable, a `$1` value and an expression without columns skip partitions just like a written date.

- KarelaDB works out `dateadd(...)`, `CAST(...)`, `+ INTERVAL '1 day'`, sums of numbers and `now()` **once** per statement, before it picks the partitions.
- `=`, `<`, `<=`, `>`, `>=`, `BETWEEN` and `IN (...)` on the time column all skip partitions.
- A variable is read again every time a statement runs. A loop that changes it reads the right days.
- A `NULL` parameter matches no row and reads nothing.
- `random()` and `nextval()` still run for every row, so they cannot skip anything.
- `time::date = CURRENT_DATE` (or `>=`, `>`, `<=`, `<` a date) is read as `time >= the day's start AND time < the next day's start` on the session's clock, so an index on the column, partition skipping and the column engine take it as they take a written range. `<>` stays a check of every row.
- `CALL ... WITH DEBUG` shows `partitions read: N` for each statement (see [procedures](procedures.md#with-debug)).

**Example: A computed start date still reads only the days it needs** (sample data: sample)

```sql
EXPLAIN SELECT count(*) FROM ochl_minutes
WHERE time >= dateadd('d', -1, '2026-09-11') AND time < '2026-09-11';
```

Result:

| plan (STRING) |
|---|
| scan table ochl_minutes (1 of 1 partitions, about 956 rows) |
| build 1 of 7 stored column(s) per row: time |
| filter while scanning: 2 condition(s) |
| group by 0 key(s), 1 aggregate(s) |
| engine: column |

(5 rows)

**Example: A date cast compared with a date is a range of the time column** (sample data: sample)

```sql
EXPLAIN SELECT count(*) FROM ochl_minutes WHERE time::date = DATE '2026-09-10';
```

Result:

| plan (STRING) |
|---|
| scan table ochl_minutes (1 of 1 partitions, about 956 rows) |
| build 1 of 7 stored column(s) per row: time |
| filter while scanning: 1 condition(s) |
| group by 0 key(s), 1 aggregate(s) |
| engine: column |

(5 rows)

**Example: A procedure parameter reads one day, like a written date** (sample data: sample)

```sql
CREATE PROCEDURE minutes_of(day TIMESTAMP) AS BEGIN
  SELECT count(*) AS minutes FROM ochl_minutes WHERE time >= day AND time < dateadd('d', 1, day);
END;
CALL minutes_of('2026-09-10') WITH DEBUG;
```

Result:

`CREATE PROCEDURE minutes_of(day TIMESTAMP) AS BEGIN`

```text
procedure 'minutes_of' created
```

`CALL minutes_of('2026-09-10') WITH DEBUG`

```text
procedure 'minutes_of' done: 0 row(s) changed
```

`SELECT count(*) AS minutes FROM ochl_minutes WHERE time >= day AND time < dateadd('d', 1, day)`

| minutes (LONG) |
|---|
| 476 |

(1 row)

`debug`

| step (LONG) | routine (STRING) | statement (STRING) | rows (LONG) | time_us (LONG) | changes (STRING) |
|---|---|---|---|---|---|
| 1 |  | CALL minutes_of('2026-09-10') WITH DEBUG | 0 | 549 | partitions read: 1 |
| 2 | minutes_of | SELECT count(*) AS minutes FROM ochl_minutes WHERE time >= day AND time < dateadd('d', 1, day) | 1 | 511 | partitions read: 1 |

(2 rows)

<a id="limit"></a>

## LIMIT

Syntax:

```sql
SELECT ... LIMIT n
SELECT ... ORDER BY col DESC LIMIT n
```

- `LIMIT` without `ORDER BY` stops reading as soon as it has `n` rows.
- `ORDER BY time DESC LIMIT n` on a time-series table reads **newest first**: it reads a short stretch of the newest rows, then older stretches only while it has fewer than `n` rows. The same goes for the newest `n` buckets of a chart, `SAMPLE BY 5m ORDER BY time DESC LIMIT n`, also with a key such as the symbol (`SELECT time, symbol, last(close) ... SAMPLE BY 1h ORDER BY time DESC LIMIT n`: the newest bars of every symbol). So the last 300 bars cost about the same with or without a time lower bound. [EXPLAIN](explain.md) shows `newest first: ...`. `ORDER BY time LIMIT n` (the oldest rows or buckets) reads the oldest stretch first the same way (`oldest first: ...`). It applies to one table (no join), with `ORDER BY` the time column alone, and for `SAMPLE BY` without `HAVING`. Since 2026-10-02 it also covers keys of any type (`SELECT time, symbol, volume > 0 AS traded, count(*) ...`) and `GROUP BY` next to `SAMPLE BY`, `ALIGN TO FIRST OBSERVATION` (the oldest row is found first, then the buckets are counted from it) and `FILL` without keys (`SAMPLE BY 5m FILL(PREV) ORDER BY time DESC LIMIT 5000`: when the first stretch ends in a gap and holds too few buckets, a longer stretch is read again, so the filled bars after the gap still take their `PREV` or `LINEAR` value from the real bar before it). `FILL` with a key (every symbol gets every bucket, also a symbol whose rows are all older), `FILL` with `FROM ... TO`, and a `LIMIT` per key (`ORDER BY symbol, time DESC`) still read every row: no short stretch can show which rows those need. A view or a subquery in `FROM` counts as its table when it only keeps some rows of it (`SELECT *` or plain columns `FROM t WHERE ...`): its `WHERE` is added to the query's. A `DATE` time column reads whole days. A table with `PARTITION BY NONE` is read this way when its rows are kept in time order (`SORT BY (time)`, or `PARTITION BY NONE, SYMBOL(sym) SORT BY (sym, time)`): each stretch is found by binary search on the time column. The rows it reads count against `max_result_memory` like any kept rows; a `LIMIT` too big for that limit is read the usual way (and refused when its rows do not fit).
- Any other `ORDER BY ... LIMIT n` must look at every matching row, but keeps only the best `n` in memory.
- `ORDER BY` one whole-number, `DATE` or `TIMESTAMP` column with no `LIMIT` (one symbol's trades of a day, newest first) reads the rows straight from the columns and sorts only them: about 3 ms became 1 ms for 5,000 of 64,000 rows (2026-09-25).
- Top `n` per group, `SELECT ... FROM (SELECT ..., row_number() OVER (PARTITION BY symbol ORDER BY qty DESC) AS rn FROM t WHERE ...) WHERE rn <= 5`: when every window of the inner query is `row_number()` or `rank()` with such a limit, over one `SYMBOL` column and ordered by one number or time column, KarelaDB first finds the `n`-th best value of each symbol and then collects only the rows at least that good. 30 days of 686,000 rows: 57 ms became 4 ms (2026-09-25). A `NULL` or `NaN` in either column makes it read every row, as before.
- `--max-rows` of `kareladb sql` and `limit=` of HTTP are a safety net that cuts the result. When you want fewer rows, write `LIMIT` in the SQL.
- For pages of a big result, use keyset pages (`WHERE time < <last time> ORDER BY time DESC LIMIT 20`), not a big `OFFSET`: `OFFSET 20000` still reads the 20,000 rows before.

**Example: The 3 biggest minute volumes of one day** (sample data: sample)

```sql
SELECT time, symbol, volume FROM ochl_minutes
WHERE time IN '2026-09-10'
ORDER BY volume DESC
LIMIT 3;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | volume (DOUBLE) |
|---|---|---|
| 2026-09-10T06:02:00.000Z | COAST | 1490 |
| 2026-09-10T07:22:00.000Z | COAST | 1490 |
| 2026-09-10T07:21:00.000Z | CITY | 1480 |

(3 rows)

<a id="latest-on"></a>

## LATEST ON with a time filter

Syntax:

```sql
SELECT ... FROM live_data WHERE timestamp >= '<today>' LATEST ON timestamp PARTITION BY symbol
```

[LATEST ON](latest-on.md) gives the newest row per symbol. It reads **every row in the time range** (column by column, on several threads), so it gets slower as the table grows.

- Add a time filter: `WHERE timestamp >= '2026-09-10'` reads only today's partition.
- For a live page of the last price per symbol, a small relational table updated with `INSERT OR REPLACE` (one row per symbol) is fastest.

**Example: The newest price per symbol, reading only one day** (sample data: sample)

```sql
SELECT symbol, timestamp, ltp FROM live_data
WHERE timestamp >= '2026-09-10'
LATEST ON timestamp PARTITION BY symbol;
```

Result:

| symbol (SYMBOL) | timestamp (TIMESTAMP) | ltp (DOUBLE) |
|---|---|---|
| CITY | 2026-09-10T09:14:00.000Z | 527.1 |
| COAST | 2026-09-10T09:14:00.000Z | 401.9 |
| TELCO | 2026-09-10T09:14:00.000Z | 897.7 |
| VOLT | 2026-09-10T09:14:00.000Z | 184 |

(4 rows)

<a id="bulk-insert"></a>

## Bulk INSERT: many rows per statement

Syntax:

```sql
INSERT [OR REPLACE | OR IGNORE] INTO table VALUES (...), (...), (...), ...
```

Every statement is one **commit**: one write to the log and one wait for the disk. So many rows in one statement are much faster than one statement per row.

| Way | Rows per second on the test PC (about) |
|---|---|
| One `INSERT` per row, one HTTP request each | about 1,300 |
| `INSERT` with 100 rows per request | about 35,000 |
| `INSERT` with 2,000 to 20,000 rows per statement | about 110,000 to 160,000 |
| [Line protocol](line-protocol.md) (`POST /write`), many lines per request | the fastest way |

- Use **1,000 to 5,000 rows per `INSERT`** for loads. Much bigger statements only use more memory.
- Load in **time order** when you can.
- Send many statements in one `kareladb sql <db> -` run or one HTTP request, not one process per statement.
- `REFERENCES`, `UNIQUE` indexes and triggers check every row: a big first import is faster without them. Create indexes **after** a big first import.
- A `BEGIN` ... `COMMIT` with millions of changed rows keeps the old rows in memory (at most 10 million). For loads, use plain statements.
- (Numbers from `bench/README.md` and `bench/questdb/README.md`, measured on 2026-09-11 on an Intel i9-14900HX. Your PC will differ.)

**Example: Three rows in one statement: one commit** (sample data: sample)

```sql
INSERT OR REPLACE INTO ochl_day VALUES
  ('2026-09-13', 'CITY', 505.0, 509.0, 503.1, 508.2, 91000),
  ('2026-09-13', 'COAST', 376.0, 380.0, 375.2, 379.5, 120500),
  ('2026-09-13', 'VOLT', 191.0, 193.4, 190.1, 192.8, 40200);
```

Result:

```text
3 row(s) inserted
```

<a id="sync-commits"></a>

## Many small writes: --sync-commits batch

Syntax:

```sql
kareladb serve [<db>] --sync-commits always|batch
```

By default (`always`) KarelaDB waits until each commit is **on the disk** before it answers. That is safe, but a disk can do only a few hundred to a few thousand such waits per second. Writers that commit at the same moment share one wait, so many clients together get many more commits per second than one client.

One wait is the disk's own flush: about 2-5 ms on a laptop SSD, on Docker Desktop and on many cloud disks. PostgreSQL waits for the same flush. When a few clients commit in a loop, KarelaDB waits a moment (at most half a flush) for the ones that are about to commit, so one flush carries all of them instead of two flushes carrying half each. Measured, `UPDATE ... SET n = n + 1` over HTTP: 2 to 8 clients get 1.2 to 1.7 times more commits a second than before; one client and 16 or more are unchanged.

With `--sync-commits batch` KarelaDB answers at once and writes all waiting commits to the disk together, every 10 ms.

- **Much faster** for many small writers (live ticks, one row per request, many clients).
- A power cut or a crash of the computer can **lose the commits of the last few milliseconds** that were already confirmed. The data is **never damaged**: after the restart the database is consistent, only those last commits are missing.
- Use `always` for money and accounting. `batch` is fine for market data you can load again.

**Command line: A server for a live feed** (sample data: sample)

```bash
kareladb serve ./market --sync-commits batch
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
  commits   synced every 10 ms (--sync-commits batch)
  time zone Asia/Katmandu (the computer's); also timers and backup schedules
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    26.95 GB for the whole process (85% of the machine's memory); table data 512.0 MB of it (--memory)
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log off
  logs      slow queries >= 1000 ms to ./market/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 1 ms: manifest 0 ms, 1 files read 0 ms (8 table files left for their first use), log check 0 ms, replay 0 ms (0 transactions), clean-up 1 ms

Press Ctrl+C to stop.
```

<a id="synchronous-commit"></a>

### One session only: SET synchronous_commit = off

Syntax:

```sql
SET synchronous_commit = off | on          one session (HTTP session or PostgreSQL connection)
SET LOCAL synchronous_commit = off         this transaction only (PostgreSQL connection)
X-KDB-Synchronous-Commit: off              one HTTP request
```

The same trade as `batch`, but only for the writes that can take it - a rate-limit counter, a cache row - while every other session keeps `always`. No restart is needed. It works as in PostgreSQL:

- The commit is confirmed without waiting for the disk. A background thread puts it on the disk within about 10 ms.
- A power cut can lose the commits of about the last 10 ms that were already confirmed. A crash or kill of the KarelaDB program (`docker rm -f`, an out-of-memory kill) can lose those of the last few ms: the log is handed to the operating system at most a millisecond later, except while a disk sync is running. The data is never damaged, and no other session's commit is ever lost. PostgreSQL makes the same trade.
- Measured on a laptop SSD, one client doing `UPDATE ctr SET n = n + 1 WHERE k = $1`: **5.1 ms** per update with `on`, **0.36 ms** with `off` (16 clients: 1,740 and 5,490 updates a second).

<a id="table-sync-commit"></a>

### One table: WITH (synchronous_commit = off)

Syntax:

```sql
CREATE TABLE t (...) WITH (synchronous_commit = on | off)
ALTER TABLE t SET (synchronous_commit = on | off)
ALTER TABLE t RESET (synchronous_commit)
```

The same trade, chosen once for a table instead of per session. A commit that changes **only** such tables is confirmed without waiting for the disk; the disk follows within about 10 ms, with the same risk as above. A commit that also changes a table that waits - an account, a user, an order - waits for the disk as before, so money and users are never confirmed early.

| Table | Without the option |
|---|---|
| a cache table (`WITH (max_bytes = ...)`, `evict`, `durability`) | answers before the flush |
| the key-value store's `_kv` and `_kv_items` | answers before the flush (Redis's `appendfsync everysec`); `CONFIG SET appendfsync always` sets `on` ([key-value](kv.md#kv-sync)) |
| every other table | waits for the flush |

- `SHOW CREATE TABLE` shows the option when it is set; `RESET` goes back to what the table's kind gives.
- `SET synchronous_commit = off` of a session still makes every commit of that session answer early.

**Example: Counters that need not wait for the disk, beside a ledger that must** (sample data: sample)

Setup:

```sql
CREATE TABLE page_hits (page STRING PRIMARY KEY, n LONG) WITH (synchronous_commit = off);
CREATE TABLE ledger (id LONG PRIMARY KEY, amount DECIMAL(2));
INSERT INTO page_hits VALUES ('/home', 1);
```

```sql
SHOW CREATE TABLE page_hits;
```

Result:

| create_sql (STRING) |
|---|
| CREATE TABLE page_hits (   page STRING PRIMARY KEY,   n LONG ) WITH (synchronous_commit = off) |

(1 row)

<a id="one-wait"></a>

### Many writes in one go: one disk wait for all

Each commit that waits for the disk costs one flush, so a client that sends one counter update per request is held to a few hundred a second. Send several writes together and they share **one** flush, with no loss of safety:

| Client | Send | One disk wait for |
|---|---|---|
| HTTP | several statements in one `POST /exec` (each commits on its own), or with `atomic=1` (one transaction) | the whole request |
| PostgreSQL port | a pipeline: several `Execute`s, then one `Sync` (pgx `SendBatch`, JDBC `executeBatch`, psycopg pipeline mode) | the whole pipeline, before `ReadyForQuery` |

Each statement of a pipeline still commits on its own, as before; what changed is that they wait for the disk together, at the `Sync` (since 2026-09-25). Measured on a busy laptop, counter updates (`UPDATE ... SET n = n + 1 ... RETURNING n`), one connection, 32 per batch (`node bench/counter.mjs`):

| Pipeline of 32, PostgreSQL port | before | now |
|---|---|---|
| 1 connection | 211 a second | 4,277 a second |
| 16 connections | 2,253 | 10,443 |

A `Sync` after every `Execute` still waits for each one, as PostgreSQL does. For single writes that may lose the last 10 ms in a power cut, use `synchronous_commit = off` (above).

<a id="memory"></a>

## Memory: --memory

Syntax:

```sql
kareladb serve [<db>] --memory <MB>
kareladb sql <db> "..." --memory <MB>
kareladb shell [<db>] --memory <MB>
```

`--memory` is the memory for table data that KarelaDB keeps loaded, for **all open databases together**. The default is **512 MB**. Data over the budget is unloaded and read from disk again when needed.

- When the tables are bigger than the budget, queries over much data read files again and again. On the test PC, a count over 20 million minute rows took 4.4 s with 512 MB and 1.4 s with `--memory 4096`.
- A good start: about the size of the data folder on disk, plus some room, if the computer has the RAM. `kareladb info` shows the file sizes.
- When a database opens with more than **8 times** `--memory` of table data, the server log says so, and `GET /api/info` has the same text in `warning`.
- Do not give KarelaDB more than the computer has: the operating system would swap, which is much slower.

What the budget counts, and what it does not:

| Memory | Limited by | Freed |
|---|---|---|
| Saved rows of loaded partitions | `--memory` | oldest use first, when over the budget |
| Lookup maps of `DEDUP KEY` / `PRIMARY KEY` for those partitions | `--memory` | with the partition |
| Column copies of changed rows (for fast scans) | `--memory` | at the checkpoint, or when over the budget |
| Changes not yet written to partition files | a checkpoint starts at a quarter of `--memory` per database | at the checkpoint |
| Kept query results | `--cache-mb` (all databases together) | oldest first |
| `CREATE INDEX` indexes | not limited (see [indexes](indexes.md)) | `DROP INDEX` |
| The rows of a statement while it runs (a big `INSERT`, a `/write` with triggers, a big result) | the size of the request | when it ends |

So the memory of the process is about `--memory` + `--cache-mb` + a quarter of `--memory` for each database being written + indexes + the requests running now + about 30 MB for the program itself. `GET /api/stats` shows every part (`memory` of each database) next to `resident_bytes`.

- Partitions a running write statement uses (the partition it inserts into, the rows it looks up) are not unloaded until the statement ends, and partitions with unsaved changes go after those without. So a small budget makes big queries slower, but a load does not read the same partition again for every statement.
- A query that reads a few columns of a table bigger than the room left, when partitions of that table are held whole (just written, or read for every column), first cuts those partitions down in memory to the columns it reads, and only then unloads anything. It does so only when the cut lets all the columns it reads fit the budget next to what other tables hold; a query bigger than the budget even at its own columns, or one over a small table, unloads as before (its own reads first), so the partitions other queries keep whole stay whole. The next run of the same query finds all its columns in memory instead of reading the same files again. `GET /api/stats` counts these as `partitions_slimmed`; `KARELADB_NO_SLIM_SCAN=1` turns it off.
- When the databases together are over `--memory`, memory is taken back in this order: databases with no statement in the last 2 seconds, then databases that only read, then the database that needs the room, then other databases that are writing.
- A database that is writing keeps at least `max(64 MB, --memory / (2 x open databases))` (never more than an equal share), whatever the others need. So one database kept in memory by earlier reads cannot slow down a load into another one. `GET /api/stats` shows each database's `share_bytes`, `floor_bytes` and `evicted_by_other_databases`.

**Command line: More memory for a big history** (sample data: sample)

```bash
kareladb serve ./market --memory 4096
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
  memory    26.95 GB for the whole process (85% of the machine's memory); table data 4.00 GB of it (--memory)
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log off
  logs      slow queries >= 1000 ms to ./market/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 1 ms: manifest 1 ms, 1 files read 0 ms (8 table files left for their first use), log check 0 ms, replay 0 ms (0 transactions), clean-up 0 ms

Press Ctrl+C to stop.
```

<a id="memory-per-database"></a>

### Memory per database and resident tables

When several apps share one server, a big scan in one database can unload the tables another database reads all the time. Three settings stop that:

| Setting | What it does |
|---|---|
| [`ALTER DATABASE d SET MEMORY_LIMIT = '512MB'`](databases.md#memory) | `d` holds at most this much loaded data. Over it, `d` unloads its **own** partitions first, even when `--memory` has room. |
| [`ALTER DATABASE d SET MEMORY_RESERVED = '128MB'`](databases.md#memory) | this much of `d`'s loaded data is never unloaded for another database or for the [process memory limit](cli-serve.md#memory-limit). |
| [`ALTER TABLE t SET (resident = on)`](alter-table.md#resident) | the table's partitions stay loaded once read, whoever needs memory. They still count against the database's `MEMORY_LIMIT`. |

- All reservations together may be at most three quarters of `--memory`, and a database's reservation at most its limit.
- `GET /api/stats` shows each database's `used_bytes`, `limit_bytes`, `reserved_bytes` and `resident_bytes` under `memory`.
- kareladb.conf can give the start values: `"database_memory": {"sales": {"limit_mb": 512, "reserved_mb": 128}}`. `ALTER DATABASE` wins over it; `DEFAULT` goes back to it.

<a id="big-group-by"></a>

## Big GROUP BY over a UNION

`INSERT INTO daily SELECT ... FROM (SELECT ... FROM a UNION ALL SELECT ... FROM b) u GROUP BY ...` does not keep the rows of the `UNION ALL` in memory: when every part is a plain read of one table (no `GROUP BY`, `DISTINCT`, `ORDER BY` or `LIMIT` inside), the rows go straight into the grouping, part after part. A view of that shape works the same way.

- Only the groups are kept. When they need more than half of `--max-result-memory`, the rows of further groups go to sorted temporary files in the database folder and are added up after the scan ([memory limits](protection.md#memory-limits)). The result is the same, only slower.
- Conditions of the outer `WHERE` are not moved into the parts then: write a time condition inside each part, so whole partitions are skipped.
- To keep a very big grouping fast, group one day (or one month) per statement.

<a id="threads"></a>

## Threads: --threads

Syntax:

```sql
kareladb serve [<db>] --threads N
```

Big queries and big writes use several threads. The default, and the most, is **half** of the CPU threads, so KarelaDB never takes the whole computer.

- Use fewer threads when the same computer runs your app and other programs that need the CPU: `--threads 2`.
- More threads help queries that read many rows (counts, sums, GROUP BY over months). A query on one symbol and one day does not need them.
- All databases of one server share these threads.
- `kareladb sql` and `kareladb shell` always use the default.

**Command line: Leave CPU for other programs** (sample data: sample)

```bash
kareladb serve ./market --threads 1
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
  cpu       32 CPUs (the machine's); 1 query thread (--threads), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log off
  logs      slow queries >= 1000 ms to ./market/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 1 ms: manifest 0 ms, 1 files read 0 ms (8 table files left for their first use), log check 0 ms, replay 1 ms (0 transactions), clean-up 0 ms

Press Ctrl+C to stop.
```

<a id="result-cache"></a>

## Result cache: --cache-mb

Syntax:

```sql
kareladb serve [<db>] --cache-mb <MB>
```

`kareladb serve` keeps the results of queries in memory (default **256 MB** for all open databases together). The same query again gets the kept result at once, as long as **no table it reads has changed**.

- Good for dashboards and live pages that ask the same question many times.
- A write makes old only the kept results that **read what it changed**. A result of `WHERE symbol = 'NABIL'` (or `symbol IN (...)`) stays valid while other symbols are written, on a table with a [rev column](revisions.md#rev-column): `PARTITION BY ..., SYMBOL(symbol)`, or `symbol` first in `SORT BY` / `DEDUP KEY`. A new NEPSE candle every minute no longer makes every NABIL chart run again.
- Every other kept result of the table - no symbol filter, a join of the table with itself, `symbol = 'x' OR <another column>` - is made old by any write to the table, as before.
- A page can ask cheaply whether its symbol changed at all: [GET /api/rev](revisions.md) and `kdb_rev()`.
- A result that took **1 ms or more** is kept the first time. A quicker one is kept the **second** time the same query comes. So one-off lookups (a session token, a user id) do not fill the cache and push out the pages that are asked for all day.
- Random functions and similar are never kept. Queries with `now()` (or `current_date`, `age(t)`) are not kept either, unless the caller says how old an answer it takes: `/exec?cache_now_ms=500`, or `SET result_cache_now_ms = 500` for a session. The answer is then the one computed up to that long ago, as if the query had run then.
- `--cache-mb 0` turns it off. A bigger value helps when many different queries repeat.
- The size can also come from `cache_mb` in [kareladb.conf](cli-serve.md#kareladb-conf) (the console's [Settings page](console-settings.md#result-cache) changes it while the server runs) or `KARELADB_CACHE_MB`. A database can get a space of its own that other databases' results cannot push out: [ALTER DATABASE ... SET RESULT_CACHE](databases.md#result-cache).
- One result is kept up to a quarter of the cache (64 MB with the default: a whole day of a floor sheet fits), and the oldest results go first when it is full. A result that took 1 ms or more to compute is passed over once before it goes. A query that must always be ready - the slow one a dashboard asks on every load - can be **pinned** ([pinned queries](pinned-queries.md)): computed when the database opens, never pushed out, allowed three quarters of the cache, and computed again by the server after a write.
- A plain `SELECT` sent again with the same text is not parsed again, and neither is an `INSERT ... VALUES`, `UPDATE` or `DELETE` sent a third time: the server keeps the parsed statement for each database ([the plan cache](server-settings.md#plan-cache), at most 2,048 texts of up to 2 KB). An `INSERT ... VALUES`, `UPDATE`, `DELETE` or `CALL` whose values are written into the text is also kept by its shape, per connection: the next one with other values (`CALL transfer(1018, 3, 9, 25)` after `CALL transfer(1017, 5, 2, 10)`) puts its values into the kept parse instead of being parsed. After `ALTER TABLE` or `DROP TABLE` the next run parses it again. A prepared statement with `$1` values (the PostgreSQL protocol's Parse, then Bind and Execute) is parsed once, when it is prepared: each Execute only puts its values in place. That holds for a `SELECT` (also with `FOR UPDATE`, or a `$1` in `LIMIT`, `OFFSET` or `FETCH FIRST`), `INSERT ... VALUES`, `UPDATE` and `DELETE`, with or without `RETURNING`. So prepare a query or a write your app sends often once per connection (most drivers, such as pgx and psycopg, do this for you) instead of sending new text each time. These still parse their text each time: `INSERT ... SELECT`, a statement that starts with `WITH`, one that names another database (`db.t`), `FOR UPDATE SKIP LOCKED`, `LIMIT $1, $2` and `LIMIT -$1`, and an `INSERT` or `UPDATE` that calls `password_hash()`.
- For a fair benchmark, skip the cache for one query or one session instead: `/exec?cache=0` (see [GET /exec](http-exec.md#get-exec)), or `SET result_cache = off` (back with `SET result_cache = on`). The answer is the same; only the time changes.
- To check the cache itself, start the server with `KARELADB_CACHE_VERIFY=1` in the environment: every cache hit is computed again and compared. A difference is logged, counted in `GET /api/stats` (`cache_verify_mismatches`, next to `cache_verify_checks`) and answered with the fresh result. It costs every hit a full query, so it is for tests and for chasing a suspected stale answer.

```sql
SET result_cache = off;
SELECT symbol, sum(volume) FROM ochl_day GROUP BY symbol;  -- computed every time
```

```sql
SET result_cache_now_ms = 1000;
SELECT count(*) AS n, max(now()) AS asked_at FROM ochl_day;  -- an answer up to 1 s old may come from the cache
```

**Command line: A bigger result cache for a dashboard** (sample data: sample)

```bash
kareladb serve ./market --cache-mb 256
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
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log off
  logs      slow queries >= 1000 ms to ./market/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 1 ms: manifest 0 ms, 1 files read 1 ms (8 table files left for their first use), log check 0 ms, replay 0 ms (0 transactions), clean-up 0 ms

Press Ctrl+C to stop.
```

<a id="column-engine"></a>

## What the column engine takes

Syntax:

```sql
WHERE part AND part AND ...     -- every part must be one of the shapes below
```

KarelaDB has two ways to run a query on one table: the **column engine** (whole columns at a time, on all threads) and the **row path** (row by row, one thread). The column engine takes a `WHERE` only when **every** part joined by `AND` is one of these:

| `WHERE` part | Example |
|---|---|
| a column against a value: `=`, `!=`, `<`, `<=`, `>`, `>=` | `volume > 1000`, `symbol = 'CITY'` |
| `BETWEEN` and `NOT BETWEEN` two values | `close BETWEEN 500 AND 510` |
| `IN` and `NOT IN` a list of values | `symbol IN ('CITY', 'COAST')` |
| `OR` of `=` (or `IN`) on the **same** column | `symbol = 'CITY' OR symbol = 'COAST'` |
| `LIKE`, `ILIKE`, `NOT LIKE` on a `SYMBOL` or `STRING` column | `symbol LIKE 'C%'` |
| `time IN '...'` on a `TIMESTAMP` or `DATE` column | `time IN '2026-09-10'` |
| `IS NULL`, `IS NOT NULL` | `close IS NOT NULL` |
| a column against a column: two whole-number columns, two `DATE`, two `TIMESTAMP`, two `FLOAT`/`DOUBLE`; two `SYMBOL` columns with `=` or `!=` | `close > open`, `buyer = seller` |
| `NOT`, `OR` and `AND` of the shapes above, nested any way | `NOT (volume <= 0 AND high = low AND open = close)`, `symbol = 'CITY' OR volume > 1000` |
| one member of a `JSON` column against text: `=`, `!=`, `<`, `<=`, `>`, `>=` | `extra_data->>'category' = 'auth'` |
| a `TIMESTAMP` column against `date_trunc` of a `TIMESTAMP` column: `=` and `!=`, also with a time zone | `time = date_trunc('day', time)` (daily bars only: 2.7 ms became 0.8 ms, 2026-09-25) |

These send the query to the row path:

- **Arithmetic in the `WHERE`**: `close * 1 > 500`, `high - low > 5`. Keep the column alone on one side.
- **A function around a column**: `lower(symbol) = 'city'`, `abs(close) > 1` (only `time = date_trunc(...)` above is taken).
- `JSON` and `BYTES` columns (other than `json->>'key'` against text), and `DECIMAL` or `STRING` compared with another column.
- **Two tables**: a `JOIN` runs on the row path.
- **One such part is enough.** `volume > 1000 AND close * 1 > 500` runs as slowly as the slow part alone: on 1,000,000 rows the row path took 107 to 151 ms where the column engine took 1.3 to 2.4 ms.

What the newer shapes gave, 1,000,000 rows, one thread, before and after they came into the column engine (TASKS.md, 2026-09-23):

| Query | Before | After |
|---|---|---|
| `sym LIKE 'S6%'` | 242 ms | 1.2 ms |
| `sym ILIKE ...` | 230 ms | 2.2 ms |
| `sum(qty) WHERE sym = 'S1' OR sym = 'S2'` | 151 ms | 0.30 ms |
| random whole numbers, `x > L` | 4.68 ms | 0.67 ms |
| `b BETWEEN ...` | 8.77 ms | 0.84 ms |

`NOT`, `OR` and `AND` trees (2026-09-24, 8.4 million minute bars of 20 symbols stored by symbol, all threads; `reports/speed-trees-or-index-agg-expr-2026-09-24.md`):

| Query | Before | After |
|---|---|---|
| a chart read: `symbol = 'NABIL-1' AND NOT (volume <= 0 AND high = low AND open = close) ORDER BY time DESC LIMIT 300` | 189 ms | 5.3 ms |
| the same, `LIMIT 5000` | 256 ms | 35 ms |
| `count(*) WHERE symbol = ... AND (volume IS NULL OR volume > 550 OR (open = close AND high = low))` | 129 ms | 1.7 ms |

**Example: LIKE, BETWEEN and an OR on one column: all in the column engine** (sample data: sample)

```sql
SELECT count(*) AS minutes, sum(volume) AS volume FROM ochl_minutes
WHERE (symbol = 'CITY' OR symbol = 'COAST') AND symbol LIKE 'C%' AND close BETWEEN 400 AND 600;
```

Result:

| minutes (LONG) | volume (DOUBLE) |
|---|---|
| 480 | 365430 |

(1 row)

<a id="column-mask"></a>

## Select only the columns you need

Syntax:

```sql
SELECT time, close FROM ...      -- builds 2 columns per row
SELECT * FROM ...                -- builds every column
```

When a query runs on the row path, KarelaDB builds only the columns the query reads. `EXPLAIN` shows them: `build 2 of 7 stored column(s) per row: time, close`.

- On a table with 21 columns, `count(*) WHERE a * 1 > X` went from 460 ms to 210 ms, `GROUP BY` from 549 to 242 ms. `SELECT *` still builds every column (465 to 436 ms).
- So name the columns, even when the `WHERE` must stay on the row path.
- `KARELADB_NO_COLUMN_MASK=1` in the environment of `kareladb serve` turns this off, to compare.

**Example: The row path builds only the columns the query reads** (sample data: sample)

```sql
EXPLAIN SELECT time, close FROM ochl_minutes WHERE close * 1 > 500;
```

Result:

| plan (STRING) |
|---|
| scan table ochl_minutes (1 of 1 partitions, about 956 rows) |
| build 2 of 7 stored column(s) per row: time, close |
| filter while scanning: 1 condition(s) |
| engine: row (a condition the column engine does not do) |

(4 rows)

<a id="saved-stats"></a>

## count, sum, min, max of a whole table

Syntax:

```sql
SELECT count(*), sum(x), min(x), max(x), avg(x) FROM t [WHERE <time range>]
```

Every partition file keeps its row count and, per column, its count, sum, min and max. When a query asks only for these, with no `WHERE` or only a time range, KarelaDB answers from those stats. It reads no rows, and loads no partition that is not loaded yet.

- 4,000,000 rows in 200 day files, right after a restart: 99.7 ms and 200 partition loads before, 0.28 ms and 0 loads after.
- A partition with unsaved changes is scanned as usual; the others still come from the stats.
- A condition on another column, a `GROUP BY` or `count(DISTINCT ...)` reads the rows.
- `EXPLAIN` says `answer from saved stats of table t: ...`.
- `KARELADB_NO_ZONE_MAPS=1` turns this off too, to compare.

**Example: A whole-table aggregate answered from the files' stats** (sample data: sample)

```sql
EXPLAIN SELECT count(*), sum(volume), min(low), max(high) FROM ochl_minutes;
```

Result:

| plan (STRING) |
|---|
| scan table ochl_minutes (1 of 1 partitions, about 956 rows) |
| answer from saved stats of table ochl_minutes: 1 of 1 partitions from the partition list and their files' stats (0 in memory, 0 partitions loaded, 1 file headers read); 0 partitions scanned |
| build 4 of 7 stored column(s) per row: time, high, low, volume |
| group by 0 key(s), 4 aggregate(s) |
| engine: column |

(5 rows)

<a id="zone-maps"></a>

## Zone maps: files skipped by min and max

Syntax:

```sql
WHERE col > value | col BETWEEN a AND b | col IN (...) | time IN '...'
```

For a number, `DATE`, `TIMESTAMP` or `DECIMAL` column, KarelaDB knows the smallest and the biggest value in each partition file. A partition whose range cannot hold a match is skipped before any row is read.

- It pays for columns that **grow with time**: ids, sequence numbers, times. On 814,535 floor-sheet trades in 15 day files, `contract > <99th percentile>` skipped 14 of 15 files: 0.93 ms went to 0.56 ms. A value above every file skipped all 15: 1.66 ms to 0.59 ms.
- A price or an amount that has high and low values on every day skips **nothing**: `rate > <99th percentile>` read all 15 files.
- `!=`, `NOT ...`, arithmetic on the column (`rate + 0 > x`), text and `BOOL` columns never skip.
- A partition that is not in memory (never read since the start, or pushed out by `--memory`) is skipped too: KarelaDB reads only the small stats part of its file once, never its rows.
- `EXPLAIN` says `m skipped by column stats`. `GET /api/stats` counts `zone_partition_skips` and `zone_block_skips`. `KARELADB_NO_ZONE_MAPS=1` turns zone maps off.

**Example: Trade ids grow with time: the first day cannot hold ids above 100008** (sample data: sample)

```sql
SELECT count(*) AS trades FROM trade_log;
EXPLAIN SELECT count(*) FROM trade_log WHERE transaction_id > 100008;
```

Result:

`SELECT count(*) AS trades FROM trade_log`

| trades (LONG) |
|---|
| 32 |

(1 row)

`EXPLAIN SELECT count(*) FROM trade_log WHERE transaction_id > 100008`

| plan (STRING) |
|---|
| scan table trade_log (1 of 2 partitions, about 32 rows, 1 skipped by column stats) |
| build 2 of 7 stored column(s) per row: date, transaction_id |
| filter while scanning: 1 condition(s) |
| group by 0 key(s), 1 aggregate(s) |
| engine: row (a condition, group key or aggregate the column engine does not do) |

(5 rows)

<a id="slice-reads"></a>

## One symbol of a partition not in memory

Syntax:

```sql
WHERE symbol = 'X'   -- on a table with SORT BY (symbol, time) (or symbol first in its key)
```

A month of minute candles for 500 symbols is one partition file of about 20 MB, and one symbol's rows are a few KB of it. When `--memory` is full and such a partition is not loaded, a query for one symbol now reads **only that symbol's rows** from the file. It does not load the whole file, and it pushes nothing else out of memory.

- It is used when the table is sorted by the `SYMBOL` column first (`SORT BY (symbol, time)`, or the symbol first in its key), the query names one symbol (or a few), and the budget has no room left. While there is room, the whole partition is loaded and kept, as before.
- The first such read of a file notes where each symbol's rows are (4 bytes a row are read once). Later reads of any symbol read only its rows.
- A partition with rows not saved yet, a packed file (`compression = on`), or a file with a `NULL` symbol is read whole, as before. So is a file where the symbols asked for cover more than half of it (`IN ('A...', 'Z...')`, the first and the last symbol); such files still count against `--memory` and are read a few at a time.
- On 14.6 million minute bars (500 symbols, 40 months) with 2 cores and `--memory 300`, 006's chart mix of random symbols went from 9 to 237 requests a second with one client, 12 to 378 with 10 clients and 18 to 363 with 50 (the slowest 5% at 10 clients: 2.6 s to 68 ms). With the whole table in memory (`--memory 1536`) nothing changes: about 1,100 a second either way.
- Chart reads (`ORDER BY time DESC LIMIT n`, the newest `n` buckets of a `SAMPLE BY`) also size their first time window by that symbol's own rows once they are known, not by every symbol's rows: fewer windows, fewer files.
- Slices read lately are kept in a slice cache, so the next chart of the same symbol does not read the file again. It holds at most `KARELADB_SLICE_CACHE_MB` (128 by default; 0 turns it off), counted as table data.
- `GET /api/stats` counts `slice_reads`, and of those `slice_cache_hits` (with `slice_cache_bytes` held now); `/metrics` has `kdb_slice_reads_total`. `KARELADB_NO_SLICE_READS=1` in the environment of `kareladb serve` turns slice reads off, to compare.

A scan now reads a single partition file outside the lock all readers share, as it already did for several at once, so readers of other partitions and tables do not wait for one reader's disk. Two readers that need the same file read it once.

<a id="aggregate-math"></a>

## Math inside sum(), avg(), min(), max()

Syntax:

```sql
sum(a + b)   sum(a - b)   sum(a * 2)   avg(close - open)   max(volume / 1000)
```

One `+`, `-`, `*` or `/` between two number columns, or a column and a number, runs as fast as a plain column.

- The answer is exactly the row-by-row answer. A row where `a` or `b` is `NULL` adds nothing; `x / 0` or a whole number that overflows is an error, as row by row.
- `sum(a + b)` on whole numbers without NULLs, and `sum(a * 2)`, `min(a + 5)` on whole numbers, come straight from each partition's saved totals.
- Longer math (`sum(a * b + c)`) or a function (`sum(abs(a))`) reads row by row, which is about 20 times slower.

**Example: Math inside an aggregate** (sample data: sample)

```sql
SELECT sum(volume * 2), avg(close - open), max(high - low) FROM ochl_minutes WHERE symbol = 'CITY';
```

Result:

| sum(volume * 2) (DOUBLE) | avg(close - open) (DOUBLE) | max(high - low) (DOUBLE) |
|---|---|---|
| 730860 | -0.0147916666666667 | 1.20000000000005 |

(1 row)

<a id="many-groups"></a>

## GROUP BY with many groups

Syntax:

```sql
SELECT key, key2, sum(a), sum(a) - sum(b) FROM t WHERE time_range GROUP BY key, key2
```

KarelaDB has two ways to run a query: the **column engine** (whole columns at a time, on all threads) and the **row engine** (row by row). The column engine is 5 to 50 times faster. A `GROUP BY` stays in it, even with hundreds of thousands of groups, when it is written like this:

| Part of the query | The column engine takes |
|---|---|
| Group keys | `SYMBOL`, `STRING` (`VARCHAR`, `TEXT`), whole-number, `DATE` and `TIMESTAMP` columns, up to 4 of them; `date_trunc('day', time)` and `to_char(time, 'YYYY-MM-DD')` of a time column, also with a time zone |
| Aggregates | `count`, `sum`, `avg`, `min`, `max`, `first`, `last`; `count(DISTINCT col)`; `sum(CASE WHEN a > b THEN x ELSE y END)`; [math inside an aggregate](#aggregate-math) |
| Result columns | the keys, the aggregates, and expressions of aggregates only: `sum(a) - sum(b)`, `round(sum(a) / sum(b), 2)`, `coalesce(sum(a), 0)`, `CASE WHEN sum(q) > 0 THEN sum(a) / sum(q) ELSE 0 END` |
| `ORDER BY` | result columns, by name, alias or position, and an aggregate that is also a result column (`ORDER BY sum(q) DESC`) |
| `WHERE` | the [column engine shapes](#column-engine): a column against a value, `IN`, `BETWEEN`, `LIKE`, `IS NULL`, a column against a column of the same kind (`buyer = seller`, `close > open`), a `JSON` member against text (`extra->>'category' = 'auth'`), and `NOT` / `OR` / `AND` of them |
| `SELECT DISTINCT`, `UNION` | run as a `GROUP BY` of every column, so the same keys apply ([DISTINCT](select.md#distinct)) |

These send the query, or its last step, back to the row engine:

- A `WHERE` part the column engine does not take (arithmetic, a function), more than 4 group keys, a `DOUBLE` group key, a function other than `date_trunc` / `to_char` as a key.
- `HAVING`, an `ORDER BY` of something that is not a result column (`ORDER BY sum(x)` with no `sum(x)` in the list), or of a `DECIMAL` result, still run, but every group becomes a row first. With 300,000 groups that step takes longer than the grouping. Add a time range so fewer groups are made.
- The same aggregate written twice (`sum(q)` in the list and again in a `CASE`) is added up once.
- A result column that mixes a plain column into the arithmetic (`sum(a) - broker`).

A `GROUP BY` over a `UNION ALL` in `FROM` is grouped **part by part**: each part groups its own table in the column engine, and the outer query only adds up one row per group and part. This is the buy-and-sell shape of a floor sheet, and it costs the two legs instead of a row-by-row pass over every trade twice:

Syntax:

```sql
SELECT symbol, broker, sum(bq) AS buy_qty, sum(sq) AS sell_qty
FROM (SELECT symbol, buyer AS broker, quantity AS bq, 0 AS sq FROM trades WHERE time_range
      UNION ALL
      SELECT symbol, seller AS broker, 0 AS bq, quantity AS sq FROM trades WHERE time_range)
GROUP BY symbol, broker
```

A view whose query is such a `UNION ALL` is grouped the same way, also when its parts say `SELECT *` (see [views](views.md#where-pushdown)). `EXPLAIN` starts with `aggregates pushed into the 2 UNION ALL parts` when it applies. It applies to `sum`, `count`, `min` and `max` (with `sum(a) - sum(b)`, `HAVING`, `ORDER BY` and `LIMIT` on the outer query, and an outer `WHERE`, which moves into every part) over parts that are plain `SELECT ... FROM one_table [WHERE ...]`. With `avg`, `first`, `last`, `DISTINCT`, a window function, or a part that joins, groups or limits by itself, the query runs as written.

Both engines give the same rows. Two small differences exist, and neither changes a stored value:

- Sums of `DOUBLE` values are added up in a different order. When one group holds huge values that cancel (`+1e300` and `-1e300`) next to small ones, the last digits of the sum can differ.
- A page with no rows (`OFFSET` past the last group) may name a different column type, because the type of a `sum` comes from the values found.

**Example: Two keys, a CASE sum and arithmetic on aggregates: all in the column engine** (sample data: sample)

```sql
SELECT symbol, date_trunc('day', time) AS day, sum(volume) AS volume,
       sum(CASE WHEN close > open THEN volume ELSE 0 END) AS up_volume,
       round(sum(volume * close) / sum(volume), 2) AS vwap
FROM ochl_minutes WHERE close > low GROUP BY symbol, day LIMIT 5;
```

Result:

| symbol (SYMBOL) | day (TIMESTAMP) | volume (DOUBLE) | up_volume (DOUBLE) | vwap (DOUBLE) |
|---|---|---|---|---|
| CITY | 2026-09-09T00:00:00.000Z | 152030 | 80580 | 507.77 |
| CITY | 2026-09-10T00:00:00.000Z | 156040 | 90920 | 504.28 |
| COAST | 2026-09-09T00:00:00.000Z | 155100 | 70190 | 387.25 |
| COAST | 2026-09-10T00:00:00.000Z | 168560 | 89090 | 378.39 |

(4 rows)

<a id="table-design"></a>

## Table design: partitions, DEDUP KEY, SORT BY

Syntax:

```sql
CREATE TABLE ... TIMESERIES(time) PARTITION BY DAY|MONTH|YEAR SORT BY (symbol, time) DEDUP KEY (symbol, time)
```

How a table is made decides how fast it is. You cannot change these later without making a new table.

| Choice | Advice |
|---|---|
| `PARTITION BY` | One partition should hold from about 100,000 to a few million rows. Minute candles of 500 symbols: `MONTH`. Daily candles: `YEAR`. Trades: `DAY`. Too small partitions (millions of tiny files) and too big ones (one file for 10 years) are both slow. |
| `SORT BY` / `DEDUP KEY` | Put the column you filter on most **first**: `(symbol, time)`. Then `WHERE symbol = 'CITY'` reads only CITY's rows in each partition. |
| `DEDUP KEY` | Makes `INSERT OR REPLACE` and duplicate checks cheap. It must include the time column, so a duplicate is looked for only in the row's own partition. A write into a new day looks up nothing. |
| Deletes of old data | `ALTER TABLE ... DROP PARTITION` removes a whole partition at once. `DELETE` of many rows is slower: the next checkpoint rewrites every partition it touched. |

See [partitions and dedup](partitions-and-dedup.md) and [CREATE TABLE](create-table.md).

<a id="symbol"></a>

## SYMBOL columns

Syntax:

```sql
symbol SYMBOL
```

Use `SYMBOL` for short text that repeats a lot: stock symbols, sectors, broker codes, statuses.

- KarelaDB keeps each different value once per partition and stores a small number per row. Files are smaller, and comparisons and `GROUP BY` are faster.
- Use `STRING` for text that is mostly different: names, news titles, comments.
- A `STRING`, `JSON` or `BYTES` column keeps all its text in one block of memory per partition, plus 8 bytes per row
  for where each value ends. Writing, saving and reading such rows makes no small allocation per value.
- See [column types](column-types.md).

<a id="indexes"></a>

## Indexes

Syntax:

```sql
CREATE INDEX name ON table (column, ...)
```

A condition on a column that is **not** the first key column (`WHERE thread_id = 7`, `WHERE email = '...'`) reads every row. An **index** makes it fast.

- Indexes live in memory. `kareladb serve` builds them on a background thread right after the database opens (about 0.2 seconds per million rows); a query that comes before that builds the index itself (see [indexes](indexes.md#warm)).
- This matters after a restart. With 200,000 posts and 4 indexes, the first word count after a restart took 774 ms when it had to build the text index, and 3.1 ms when the index was built at open. All 4 indexes were ready 0.7 s after the open.
- Every index makes writes a little slower and uses memory.
- `EXPLAIN` shows `use index ...` when an index is used.
- See [indexes](indexes.md) and [full-text search](full-text-search.md).

<a id="line-protocol"></a>

## The line protocol for fast writes

Syntax:

```sql
POST /write?db=<name>&precision=s
<table>,<tag>=<value> <field>=<value>,... <time>
```

For live feeds and big loads, send rows in the InfluxDB **line protocol** to `kareladb serve` instead of SQL. There is no SQL to parse, and big bodies are read on several threads.

- Send many lines per request (1,000 to 100,000), not one request per row.
- **One new day per request is the fastest load.** A day that is not in the table yet needs no duplicate lookups: its rows are sorted and written in one piece. 250,000 rows take about 0.2 s (1.3 million rows per second).
- A day sent **again** is slower (about 1.5 s for 250,000 rows): every key is looked up in that day. The result is the same: the new rows replace the old ones.
- A write returns before the checkpoint that saves it to partition files. The checkpoint runs right after, in the background. The rows are already safe in the log.
- Tables with indexes are slower to fill this way (every row is checked).
- **A slow trigger makes every load slow**: a normal trigger runs inside the write. Make it [DEFERRED](triggers.md#deferred): the write returns at once, and the trigger runs after it. See [what keeps the fast path](#load-fast-path).
- The activity log splits each write's time: `275,207 rows into floorsheet (line protocol; insert 1.9 s, trigger 25.9 s)`. The event has `insert_ms` and `trigger_ms`.
- See [line protocol](line-protocol.md).

<a id="load-fast-path"></a>

## Loads: what keeps the fast path

Syntax:

```sql
CREATE TABLE trades (...) TIMESERIES(time) PARTITION BY DAY SORT BY (symbol, time)     -- no DEDUP KEY
CREATE TRIGGER t AFTER INSERT ON trades DEFERRED EXECUTE BEGIN ... END
```

A big `POST /write` or a many-row `INSERT` is fastest when KarelaDB can write the rows as sorted column **runs**, built before the table is locked. Some table features need every row on its own.

| The table has | Load path |
|---|---|
| a `DEDUP KEY` (or `PRIMARY KEY`) | runs |
| **no** unique key at all (keyless) | runs, appended: nothing is looked up or replaced |
| only `DEFERRED` triggers | runs; the trigger runs after the commit |
| an `INSERT` trigger that is not deferred | row by row, with the trigger inside the write |
| `REFERENCES`, `UNIQUE` (other than the key), `AUTO` columns, a `UNIQUE` index, or other tables that `REFERENCE` it | row by row: each row is checked against other rows |

Measured on 2026-09-23:

| Change | Before | After |
|---|---|---|
| floor sheet without a `DEDUP KEY` written as runs (814,535 real trades) | 438,373 rows/s | 918,067 rows/s (QuestDB 677,540) |
| 20,000-row load into a table **without** a trigger, while another table has one | 34 ms | 8 ms |
| 20,000-row load into a table whose trigger is made `DEFERRED` | 103 ms | 9 ms |

- A **keyless** table never replaces a row: two equal rows both stay. That is right for trades, where two trades of one symbol in one second are both real. For candles, where a row sent again must replace the old one, keep the `DEDUP KEY`.
- Only `AFTER INSERT` triggers can be `DEFERRED`.

<a id="slow-parts"></a>

## Slow parts KarelaDB still has

Syntax:

```sql
reads of every row  |  one writer per table  |  big DELETEs  |  CHECK and BACKUP of everything
```

Being honest helps you plan. These are known (from `bench/README.md`, September 2026):

| Slow part | What to do |
|---|---|
| Queries that read **every row** of a big table (`GROUP BY symbol` over years, `ORDER BY volume LIMIT 10` over months, `count(*)` with a filter on another column) take from tenths of a second to seconds. A plain `count(*)` or `sum` of the whole table is answered from [saved stats](#saved-stats). | Add a time range. Keep summary tables (for example daily candles) and query those. |
| `LATEST ON` reads every row in the time range. | Add a time filter, or keep a one-row-per-symbol table. |
| **One writer per table.** A long `UPDATE` or `DELETE` makes other writers of the same table wait; writers of other tables go on. While a `BEGIN` ... `COMMIT` is open, writers of its tables wait up to 5 seconds, then get `table 'x' is busy`. | Keep transactions short. Split huge changes into parts. Put a live feed and a big load in different tables. |
| `DELETE` of many rows: the next checkpoint rewrites every partition that had deleted rows. | Use `DROP PARTITION` for old data. |
| `CHECK TABLE` and backups read or copy the **whole** database. | Run them after market hours. |
| With less `--memory` than the data, big queries read files again. | Give `--memory` about the size of the data. |
| The first query after a start loads files (and builds an index the warm-up thread has not reached yet). | Expect a slower first query; later ones are warm. |
| Opening a data folder with many thousands of partition files: a 9.5 GB folder with 11,104 partitions took 124 to 233 s, one file open per partition (TASKS.md). | Keep partitions big enough (see [table design](#table-design)); drop old ones with `DROP PARTITION`. |
| Every HTTP request prints a line in the server's window. | With thousands of requests per second, send the server's output to a file. |

What the test PC measured (medium = 2 million minute rows, large = 20 million):

| Benchmark | Medium | Large, `--memory 4096` |
|---|---|---|
| bulk load, one INSERT of 2,000 rows | 12.6 ms | 12.7 ms |
| live commit of 527 rows (one row per symbol) | 6.4 ms | 7.7 ms |
| one symbol, one year of minutes as 1-hour candles | 1.9 ms | 3.8 ms |
| LATEST ON for 527 symbols | 13 ms | 25 ms |
| count + sum over all minute rows | 186 ms | 1.4 s |
| open the database after a clean close | 95 ms | 74 ms |
| backup (copy and check) | 0.86 s | 4.3 s |
