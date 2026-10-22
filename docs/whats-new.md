# What's new

> Everything added to KDB since 2026-09-12, grouped by what it does for you, with the measured number and the topic that explains it.

- Category: Getting started
- Keywords: whats new, whats new, new features, changes, changelog, release notes, recent changes, since 2026-09-12, zone maps, saved stats, warm at open, table locks, group commit, keyless runs, phrase search, word positions, disk full, format
- See also: [About KDB](about-kdb.md), [Benchmark report](benchmark-report.md), [Test report](test-report.md), [Performance tips](performance-tips.md), [Limits](limits.md)

This page lists what was added to KDB from 2026-09-12 to 2026-09-24. Each line says what changed, the number measured before and after (where there is one), and where to read more.

- Numbers are medians on one PC (Intel i9-14900HX, 32 GB). The reports say how each was measured.
- "A -> B" means before -> after, on the same machine in the same minutes.
- A switch like `KDB_NO_ZONE_MAPS=1` turns a new speed-up off. It is there so an answer can be checked against the old path, not for normal use.

<a id="2026-10-18-pg-stream"></a>

## 2026-10-18: streamed reads over the Postgres port run three to four times faster; a view's one-day read in half the time

| What changed | Measured (10M trades in 145 day partitions, the server on 2 CPUs, Windows, a Go pgx client reading every row, 006's way) | Read more |
|---|---|---|
| A driver that describes a query before it runs it (pgx, psycopg, JDBC, npgsql all send `Describe`, `Execute` and `Sync` at once) no longer has every row written to a temporary file and read back: a plain `SELECT` of a table's columns is described from the table, and any other query runs as its `Execute` would, the rows streamed. | `SELECT * FROM fs` (10M rows, 8 columns): 6.6-7.4 s -> 1.5-1.8 s (1.4M -> 5.7-6.6M rows/s, the two builds side by side); the 34M-row floor sheet in Docker took 46 s | [big answers stream](postgres-protocol.md#streaming) |
| The rows of a streamed answer are written straight from the stored columns, no value object per cell, and sent from a thread of their own while the next run is written. | server CPU per 10M rows 1.9 s -> 1.3 s | [big answers stream](postgres-protocol.md#streaming) |
| A view that is rewritten before it runs (a day's conditions pushed in, aggregates pushed into `UNION ALL` parts) is copied as a tree instead of printed and parsed again on every run. | one day of a view over two materialized views (91 rows): 0.33-0.35 ms -> 0.17 ms per request over the Postgres port, the two builds side by side; the server's own time (`pg_stat_statements`) 0.21 -> 0.13 ms | [views](views.md#where-pushdown) |
<a id="2026-10-18-key-map"></a>

## 2026-10-18: a join to a small table runs as a key lookup; a day's grouping in fewer steps

| What changed | Measured (10M floorsheet trades, 2 CPUs, 1.5 GB memory budget, WSL with an emulated 2-CPU quota) | Read more |
|---|---|---|
| A grouped view joined to a total of itself over some of its keys (`df d JOIN (SELECT time, symbol, sum(buy_qty) AS tot FROM df GROUP BY time, symbol) t ON d.time = t.time AND d.symbol = t.symbol`, each broker beside the symbol-day's total) makes the totals inside the view's own grouping: no row of the view is joined. An `INNER JOIN` on all of t's keys, t's aggregates `sum` / `min` / `max` of the view's `sum` / `count` / `min` / `max` outputs, a `WHERE` that narrows by those keys and by aggregates only. `EXPLAIN` says "to its own totals"; `KDB_NO_SELF_JOIN_TOTALS=1` turns it off. | OTM filter, one day: 7.6 -> 6.3 ms (side by side on a busy host) | [views](views.md#where-pushdown) |
| A `HAVING` that reads only aggregates (a `CASE` flag, comparisons, `AND` / `OR` / `NOT`, `IN`, `BETWEEN`) is worked out column-wise over all the groups at once, with the same `NULL` rules, instead of one group at a time. An average, a first/last, a DECIMAL sum or whole-number arithmetic in the test still goes group by group; `KDB_NO_VECTOR_HAVING=1` turns it off. | OTM flag test over a day's 10,000 groups: 3.9 -> 1.4 ms (the step alone) | [HAVING](group-by.md#having) |
| A `GROUP BY` over a view joined to a small table whose columns are only group keys (`df d JOIN sector s ON d.symbol = s.symbol GROUP BY d.time, d.broker, s.sector`) runs the join as a lookup of the key inside the view's own grouping: no row of the view is made. Only an `INNER JOIN` on one column, a table of up to 65,536 rows that holds each key once, and columns of texts or whole numbers without NULLs. `EXPLAIN` says "run as a lookup of". | broker-sector, one day: 4.9 -> 1.1 ms; over a year: 31 -> 16 ms | [views](views.md#where-pushdown) |
| A `GROUP BY` of two to four keys (`time, symbol, broker`) keeps them in one 64-bit number, each key in the bits its saved stats call for, so the merge compares numbers and not 48-byte keys. | daily filter, one day: 3.6 -> 2.6 ms; OTM filter, one day: 6.0 -> 5.4 ms | [GROUP BY](group-by.md) |
| The small steps around a day's grouping cost less: the zero and one columns of a `UNION ALL` part are kept across queries instead of being made as long as the partition each time, the merge tables are sized once from the pieces, and with few groups the steps after the scan run on one thread instead of a pass over the pool each. `KDB_FLAT_TRACE=1` prints where a grouping's time goes. | (in the numbers above) | [GROUP BY](group-by.md) |

<a id="2026-10-17-window-sums"></a>

## 2026-10-17: sums over a year of windows and of buy/sell views on the column engine

| What changed | Measured (36M floorsheet trades over 2 years, 2 CPUs, 1.5 GB memory budget, WSL) | Read more |
|---|---|---|
| A `GROUP BY` over a subquery of `row_number()`, `rank()`, `dense_rank()`, `lead()` or `lag()` over one table runs on the column engine: the window values are worked out partition by partition, then grouped. The `PARTITION BY` must be the first columns the table is sorted by, with its time column among them. | pump-and-dump summed over 1 / 2 years: 4.7 / 9.0 s -> 0.61 / 1.2 s | [window functions](functions-window.md) |
| A sum over a view that joins the buy side and the sell side of one table with `UNION ALL` reads only the columns it uses, and each side finds its groups as runs of the symbol the table is sorted by. | daily filter summed over 1 year: 0.88 -> 0.35 s; sector turnover over 2 years: 1.47 -> 0.46 s; broker invest over 2 years: 1.71 -> 0.54 s | [UNION ALL](union-subqueries.md) |
| A `GROUP BY` of a SYMBOL and a LONG column keeps both keys in one 64-bit number when the saved stats of every partition read keep the LONG in 32 bits; over the parts of a `UNION ALL` too. | broker holding (symbol x broker) over 2 years: 3.77 -> 1.75 s | [GROUP BY](group-by.md) |
| `CAST(0 AS LONG)` and other casts of a number that cannot change it count as that number in a sum of a `CASE` on the column engine. | (the pump-and-dump view writes its zeros that way) | [window functions](functions-window.md) |

<a id="2026-10-17-view-memory"></a>

## 2026-10-17: year-long reads of joined and lag views fit in memory

| What changed | Measured (34M floorsheet trades over 2 years, 2 CPUs, 1.5 GB memory budget, WSL) | Read more |
|---|---|---|
| A view that joins is read a few days at a time too, when its time comes from one source and reaches the others through `ON d.time = t.time`, or the other side is a small table. Its parts are sized by what the first part held. | OTM filter over 1 / 2 years: memory full -> 4.4 / 9.1 s, about 25 MB held | [views](views.md#where-pushdown) |
| A `GROUP BY` over a view joined to a table groups the view first, then joins the groups. | broker-sector over 1 year: 9.3 s and 2.6 GB -> 0.37 s | [views](views.md#where-pushdown) |
| A `lag()` view read for one day reads only that day and each partition's last row before it, a few days per read. | broker spark, one day: 1.7 s and 2.6 GB -> 0.3-0.45 s, 22 MB held | [views](views.md#where-pushdown) |
| The row engine's `GROUP BY` keeps small states for `count`, `sum`, `avg`, `min`, `max`, and hashes its keys with the CPU's crc32 instruction. | Mkt hit over 1 year: 57 s -> 28-45 s | [views](views.md#where-pushdown) |
| A view read a few days at a time runs two parts at once on 2 or more CPUs; the rows still go on in time order. | OTM filter over 1 / 2 years (materialized views): 4.3 / 8.7 s -> 2.0 / 4.5 s; Mkt hit over 2 years: 63 s (past the 60 s statement timeout) -> 32-39 s | [views](views.md#where-pushdown) |
| Conditions and sums of numbers (comparisons, + - * /, AND, OR, CASE WHEN) are worked out without building a value object per step, and a join finds its rows in one flat table. | OTM filter's CPU over 1 year: about 5.0 s -> 4.2 s | [views](views.md#where-pushdown) |

<a id="2026-10-16-streaming"></a>

## 2026-10-16: big answers stream over the Postgres port; long view ranges run in parts

| What changed | Measured (10M trades in 148 day partitions, `--threads 2`, `--max-result-memory 600MB`, Windows, a Go client reading every row) | Read more |
|---|---|---|
| A big plain `SELECT` over the Postgres port sends its rows while it reads them (simple query, `Execute` with or without a row limit, `Describe` first). Small answers are made and cached as before. | `SELECT * FROM fs` (10M rows): refused at `max_result_memory` -> 3.0-3.4 s, about 110 MB above the loaded table; the 34M-row floor sheet was refused at 6,609 MB | [big answers stream](postgres-protocol.md#streaming) |
| A `GROUP BY` over a window or grouping view for many days runs the view a few days at a time when the time column passes through every step. | pump-and-dump summed over 31 / 148 days: refused -> 4.1 / 18 s; Mkt hit over 10 days: memory full -> 5.9 s | [views](views.md#where-pushdown) |
| A `GROUP BY` over a view no longer runs the view's inner query whole first only to find it cannot stream it. | Accumulation/Distribution over 10 days: 60 s statement timeout -> 1.2 s | [views](views.md#where-pushdown) |

<a id="2026-10-10-read-ahead"></a>

## 2026-10-10: a cold scan keeps the disk busy

| What changed | Measured (a cached daily view built over 6.2M trades in 80 day files on a Windows folder mounted into WSL, `--memory 1536`, 2 cores, files not in memory) | Read more |
|---|---|---|
| While a batch of partitions is grouped, two helper threads read the files of the next partitions into the room the memory budget has, so the disk never waits for the grouping or for the last files of a round; a budget that is full stops them and the batches make room as before. | first build of the view: 868 -> 683 ms (the second, from memory, 47 ms either way) | [memory](performance-tips.md#memory) |
| A partition file is read in as few requests as a slow mount allows: neighbouring sections in one whole-block read, the checksum table and trailer together. | read calls for the 80 files: 1,612 -> 646 | [memory](performance-tips.md#memory) |
| `CREATE VIEW`, `CREATE CACHED VIEW` and `DROP VIEW` leave the views file to the next checkpoint, as `DROP TABLE` does; the statement is in the log before it answers. | a plain `CREATE VIEW` on that folder: 93 -> 2.7 ms; the cached view's second build: 90-117 -> 47 ms | [views](views.md) |

<a id="2026-10-09-slim-scan"></a>

## 2026-10-09: big scans in a full memory budget stop reading the same files again

| What changed | Measured (34M trades in 447 day partitions, `--memory 1536`, 2 cores, data on a Windows disk, after a line-protocol load) | Read more |
|---|---|---|
| A query that reads a few columns of a table bigger than the room left first cuts the partitions held whole (just written, or read for every column) down in memory to its columns, then unloads only if it must. Only when that lets all its columns fit: a bigger query, or one over a small table, leaves them whole. `KDB_NO_SLIM_SCAN=1` goes back. | `REFRESH VIEW` of a daily GROUP BY: 3.0-3.3 s -> 0.34-0.38 s (median of 15); its second build 2.6-2.8 s -> 0.39-0.47 s; files read again per run: 189-254 -> 0 | [memory](performance-tips.md#memory) |
| A number column whose saved stats say one value in the whole file (the day of a day partition) is filled from the stats instead of read. | bytes read for a cold pass of that view: 1,417 -> 1,146 MB | [memory](performance-tips.md#memory) |

<a id="2026-10-06-statement-cost"></a>

## 2026-10-06: less work around each statement on the PostgreSQL port

| What changed | Measured (server CPU per statement, 2 cores, pgx sending a new text each time, result cache off; best of 3) | Read more |
|---|---|---|
| A plain statement is recognized by its first word; a connection reuses its statement record, its unnamed portal and, for a parameterized statement sent again with the same text, its parse and description (until a table, view or setting it depends on changes). | `SELECT 1`: 54 -> 36 us; a primary-key lookup: 82 -> 54 us; a one-row INSERT with parameters: 270 -> 170 us | [performance tips](performance-tips.md) |
| Rows go out as text without a string per value: times and decimals are written digit by digit. | the last 500 bars of a symbol: 413 -> 200 us; 16 clients: 4,300 -> 7,400 per second | [performance tips](performance-tips.md) |
| A query without a time range keeps each partition's time range instead of reading it from the partition's name again. | a lookup by a number over 43 day partitions: 112 -> 67 us | [zone maps](performance-tips.md#zone-maps) |

<a id="2026-10-02-sorted-copy"></a>

## 2026-10-02: big sorted copies fit a 3 GB memory limit

| What changed | Measured (15.3M minute bars, `--memory 1536 --memory-limit 3GB`) | Read more |
|---|---|---|
| `INSERT ... SELECT ... ORDER BY` sorts its rows in batches on disk and writes them in that order; a `DEDUP KEY` on a minute bucket (`DEDUP KEY (symbol, minute)`) keeps the copied rows as compact runs. `KDB_NO_SORTED_INSERT_STREAM=1` goes back. | 1.8M bars of 5 symbols `ORDER BY time` into `DEDUP KEY (symbol, minute)`: peak 4.9 GB and stopped -> 1.9 GB, 10 s; the same rows kept | [INSERT](insert.md) |
| A quick statement let in at the limit that needs more than its small reserve waits up to 2 s for memory to come back, then runs on. | the three `GROUP BY` checks right after that copy: `memory full` -> answered | [kdb serve](cli-serve.md#memory-limit) |

<a id="2026-10-02-read-slots"></a>

## 2026-10-02: reads take turns on a small CPU limit

| What changed | Measured (2 CPUs by quota as `docker --cpus 2`, 32 HTTP threads, 006's day-candle mix, result cache off) | Read more |
|---|---|---|
| Reads run at most as many at once as the server has CPUs (at least 2); the rest wait in line, and a read holds its turn for at most 10 ms. `--read-slots off` goes back. | 50 clients: 464 -> 2,685 requests/s; 200 clients: 500 -> 2,526; PostgreSQL prepared at 50 clients: 514 -> 2,253 | [read slots](cli-serve.md#read-slots) |

<a id="2026-10-02-cache"></a>

## 2026-10-02: cache tables with a memory cap

| What changed | Measured | Read more |
|---|---|---|
| `CREATE TABLE ... WITH (max_bytes = '64MB', evict = 'lru')`: once the rows take more than the cap, the rows used longest ago are deleted (also `volatile_ttl`, `random`, `volatile_lru`, `volatile_random`). `durability = 'none'` starts empty after a restart. | 100,000 rows of 100 bytes into a 1 MB table: about 1 MB left within a second; a key read every few ms is kept | [cache tables](create-table.md#cache-table) |
| The key-value store takes `CONFIG SET maxmemory`, `maxmemory-policy` (`allkeys-lru`, `volatile-ttl`, `noeviction`, ...) and `appendonly no`, and answers `MEMORY USAGE`. Keys are evicted at once, so the cap holds after every command. | | [kv memory cap](kv.md#kv-memory) |

<a id="2026-10-02-kv"></a>

## 2026-10-02: a Redis-like key-value store

| What changed | Measured (200 clients, one counter step per request) | Read more |
|---|---|---|
| `POST /kv` answers `GET`, `SET ... EX`, `INCR`, `EXPIRE`, `TTL`, `DEL`, `KEYS`, `MGET` and the other Redis string commands, one at a time or as a pipeline; SQL has `kv_get()`, `kv_set()`, `kv_incr()`. Keys are in memory and in the table `_kv`. | `UPDATE ... SET n = n + 1` over `/exec`: 2,100/s -> `INCR` over `/kv`: 23,000/s, every answer on disk (`--http-threads 200`); 47,000/s with `?sync=off` | [key-value store](kv.md) |

<a id="2026-09-25-throughput"></a>

## 2026-09-25: more requests per second on 2 CPUs

| What changed | Measured (2 cores, 16 clients, result cache off) | Read more |
|---|---|---|
| A chart read (`ORDER BY time DESC LIMIT n` of plain columns) takes its rows straight from the columns as the answer. | day candles: 2,200 -> 5,000 requests/s | [performance tips](performance-tips.md) |
| `WHERE symbol = 'x'` on a `PARTITION BY ..., SYMBOL(symbol)` table finds its partitions without walking all of them. | minute candles: 4,400 -> 5,800 requests/s | [partitions](partitions-and-dedup.md) |
| `GROUP BY ... ORDER BY ... LIMIT n` picks the first groups instead of sorting all of them. | 1.2 million groups: 970 -> 920 ms | [performance tips](performance-tips.md) |
| Answers of 2 KB or more come gzip-compressed to clients on other computers that send `Accept-Encoding: gzip`. | a 500-bar chart: 31 KB -> 7 KB | [compressed answers](http-overview.md#gzip-answers) |

<a id="2026-09-24"></a>

## 2026-09-24: fixes from the 006 test report

The NChartPro team (session 006) tested KDB as a replacement for PostgreSQL, QuestDB and Redis and listed what was missing. Most of the list went in on 2026-09-24, in five waves. The day-by-day list is in the console (Help > What's new).

**Wave 1: waits, sessions and a busy server.**

| What changed | Read more |
|---|---|
| `--http-threads`, `--max-connections`, `--lock-timeout`, and `SET lock_timeout` for one session. | [kdb serve](cli-serve.md), [transactions](transactions.md) |
| Session settings (`SET` / `current_setting`), advisory locks, `INTERVAL` columns. | [PostgreSQL functions](functions-postgres.md) |
| Exact statement timeouts, admin queue commands, a TTL that runs on a busy database. | [protection](protection.md) |
| A schema change with nothing to do locks nothing; small writers no longer wait for another table's checkpoint. | [transactions](transactions.md) |

**Wave 2: readers never wait for the wrong writer.**

| What changed | Measured | Read more |
|---|---|---|
| A `SELECT` waits only for writers of the tables it reads; a checkpoint lets readers in while it writes its files. `NOWAIT` / `SKIP LOCKED` answer at once. | a login lookup during a long CALL: 3.4 s -> 1.5 ms | [transactions](transactions.md#per-table-reads) |
| A `CALL` that only reads runs like a `SELECT`. Reader yield is on by default. | | [procedures](procedures.md#read-only-call) |
| The result cache is kept per symbol: a write of one symbol keeps the other symbols' results. `GET /api/rev` and `kdb_rev()`. | | [revisions](revisions.md) |
| One memory limit for the whole process (`--memory-limit`); small tables are unloaded last. | | [kdb serve](cli-serve.md) |
| Timers fire on time; failed deferred trigger jobs run again and raise an alert; `DROP TABLE` / `DROP PARTITION` answer at once. | DROP of 230 partitions: 1,000 -> 23 ms | [timers](timers.md), [triggers](triggers.md) |

**Wave 3: speed.**

| What changed | Measured | Read more |
|---|---|---|
| `ORDER BY time DESC LIMIT n` and the newest n buckets of a `SAMPLE BY` read the newest rows first and stop. `SAMPLE BY` itself is 2-4x faster. | 5-minute chart, 5,000 bars: 560 -> 29 ms | [ORDER BY and LIMIT](order-by-limit.md), [SAMPLE BY](sample-by.md) |
| `NOT`, `OR`, `AND` of simple conditions run in the column engine; an `OR` whose branches all have an index reads those indexes; `CASE` of sums and `ORDER BY` on the result stay on the fast path. | ghost-bar filter 189 -> 5 ms; `email = x OR phone = x` 38 -> 0.08 ms; filter page 34 -> 9 ms | [WHERE](where.md), [indexes](indexes.md) |
| `LATEST ON` over a table split by symbol reads only each symbol's newest rows; outer filters of a window query run right after the windows. | day change with `lag()`: 41 -> 3 ms | [LATEST ON](latest-on.md) |
| A join on a key or an indexed column looks up only the matching rows. | session check: 144 -> 0.13 ms | [joins](joins.md#join-speed) |
| Scans of tables bigger than the memory budget load partitions in parallel batches and keep other tables in memory. | 20M minute bars `GROUP BY`, 1.5 GB: 24 s -> 1.8 s | [performance tips](performance-tips.md) |
| Log tables: time ranges on relational tables, `EXTRACT(...) = x` as a time range, `json->>'key'` filters and text `GROUP BY` keys in the column engine. | count by level, 24 h of 2M rows: 835 -> 4 ms | [WHERE](where.md), [EXPLAIN](explain.md) |
| The result cache is 256 MB and settable per server and database; one-off quick results are kept only when asked twice; `now()` results may be cached briefly on request; a repeated `SELECT` is not parsed again; big databases open lazily. | floor-sheet day with the cache: 231 -> 19 ms | [performance tips](performance-tips.md#result-cache), [databases](databases.md#result-cache) |
| PostgreSQL-port point lookups scale with the clients; bulk loads into indexed tables are 1.6-2.8x faster. | login by email, 32 clients: 14.5k -> 115k/s; 300k logins COPY: 7.9 -> 2.8 s | [PostgreSQL port](postgres-protocol.md) |
| `SET synchronous_commit = off` for fast small commits of one session. | 5 -> 0.36 ms a commit | [performance tips](performance-tips.md#synchronous-commit) |
| The newest bars of every symbol are read newest first; a one-day `GROUP BY` with many groups uses every thread; group commit lets 2-8 writers share one disk flush. | newest 5,000 1-hour bars: ~1,000 -> 8 ms; symbol x buyer, one day: 9.5 -> 4.5 ms | [SAMPLE BY](sample-by.md), [performance tips](performance-tips.md) |

**Wave 4: PostgreSQL features.**

| What changed | Read more |
|---|---|
| `SET TIME ZONE` and `kdb serve --timezone`: `CURRENT_DATE`, `::date`, `date_trunc` and `EXTRACT` on your clock; times stay stored in UTC. | [time zones](time-and-time-zones.md) |
| `SET int_division = integer` (7 / 2 = 3); `GROUP BY ROLLUP`, `CUBE`, `GROUPING SETS` and `GROUPING()`. | [operators](operators.md), [GROUP BY](group-by.md) |
| `SAVEPOINT`, `READ COMMITTED` on request, 40001 for a busy table inside a transaction, `SET ROLE`. | [transactions](transactions.md), [users and roles](users-and-roles.md) |
| `WITH (dedup_insert = 'upsert')`: a plain `INSERT` replaces a row with the same DEDUP KEY. | [partitions and DEDUP](partitions-and-dedup.md) |
| psql `\d` and DBeaver; Unicode `lower` / `upper`, `COLLATE`; `SIMILAR TO`. | [PostgreSQL port](postgres-protocol.md), [text functions](functions-text.md) |
| JSON `?`, `?\|`, `?&`, `@>` on objects and a GIN index; `GENERATED ALWAYS AS (...) STORED`. | [JSON functions](functions-json.md), [CREATE TABLE](create-table.md) |

**Wave 5: running it safely.**

| What changed | Read more |
|---|---|
| Backups on by default; restore into a new database while the server runs, then swap; `--backup-command` copies each backup off the server. | [backups](backup-and-safety.md), [backup schedule](backup-schedule.md) |
| TLS on both ports, named API tokens that can be revoked, logins that survive a restart. | [TLS](tls.md), [API tokens](api-tokens.md) |
| Rate limits per address and per user, a time limit per user, an audit log chained by hashes. | [protection](protection.md), [audit log](audit-log.md) |
| `GET /metrics` for Prometheus, a slow-query log, trash emptied by size, disk use by kind. | [server info](http-server-info.md), [trash](trash.md) |
| `INSERT ... SELECT` copies in batches; at the memory limit the biggest statement is stopped, not the server. | [INSERT](insert.md), [kdb serve](cli-serve.md) |

<a id="queries"></a>

## Faster queries

Queries now read less: partitions are skipped by their saved minimum and maximum, filters run as tight loops, and some totals come from saved numbers without reading any row.

| What changed | Measured | Read more |
|---|---|---|
| **Zone maps.** `WHERE qty > x`, `BETWEEN`, `IN` and `time IN` on number, date, time and `DECIMAL` columns skip every partition and block whose minimum and maximum rule it out. `EXPLAIN` says "K skipped by column stats". Off: `KDB_NO_ZONE_MAPS=1`. | an id-like column, 814,535 rows in 15 day files: 0.93 -> 0.56 ms (14 of 15 files skipped); a value no file holds: 1.66 -> 0.59 ms | [EXPLAIN](explain.md), report |
| **One symbol of a partition not in memory.** With `--memory` full, `WHERE symbol = 'X'` on a table sorted by symbol first reads only that symbol's rows of a partition file, not the whole file, and pushes nothing out. No partition file is read under the readers' shared lock any more. Off: `KDB_NO_SLICE_READS=1`. | 14.6M minute bars, 500 symbols, 2 cores, `--memory 300`, 006's chart mix: 9 -> 237 requests/s (1 client), 12 -> 378 (10 clients), 18 -> 363 (50 clients) | [performance tips](performance-tips.md#slice-reads) |
| **Totals from saved stats.** `count(*)`, `count(col)`, `sum`, `min`, `max` and `avg` with no `WHERE` (or only a time `WHERE`) are answered from the numbers saved with each file, for partitions not in memory. `EXPLAIN` says "answer from saved stats". | 4M rows in 200 day files, right after a restart: 99.7 -> 0.28 ms, 0 partitions loaded | [EXPLAIN](explain.md) |
| **LIKE, ILIKE and OR in the column engine.** `LIKE`, `ILIKE` and `NOT LIKE` on `SYMBOL` and `STRING` columns, and `col = a OR col = b`, no longer fall back to the slow row path. A `SYMBOL` pattern is checked once per name, not once per row. | 1M rows: `sym LIKE 'S6%'` 242 -> 1.2 ms; `ILIKE` 230 -> 2.2 ms; `sum(qty) WHERE sym = 'S1' OR sym = 'S2'` 151 -> 0.30 ms | [WHERE](where.md), [performance tips](performance-tips.md) |
| **Branch-free filters.** Every compare on `LONG` and `DOUBLE`, and `BETWEEN`, runs as a tight loop over 8 rows at a time. | 1M random rows: `x > L` 4.68 -> 0.67 ms; `y > L` (DOUBLE) 7.03 -> 0.62 ms; `b BETWEEN` 8.77 -> 0.84 ms | [performance tips](performance-tips.md) |
| **The row path reads only the columns a query uses.** Queries the column engine cannot run no longer build all columns of every row. Off: `KDB_NO_COLUMN_MASK=1`. | a 21-column table, 1M rows: `count(*) WHERE a * 1 > X` 460 -> 210 ms; `GROUP BY` 549 -> 242 ms; `SELECT *` not slower (465 -> 436 ms) | [EXPLAIN](explain.md) ("build 2 of 3 stored columns") |
| **Warm at open.** Indexes are built on a background thread right after a database opens, so the first query after a restart finds them ready. `--warm-indexes on\|off`, on by default. | first request after a restart, 200k posts: author lookup 89.7 -> 1.5 ms; common-word search count 774 -> 3.1 ms | [kdb serve](cli-serve.md), [indexes](indexes.md), report |
| **Pinned queries.** An admin pins a query with `POST /api/pins`; its answer stays in the result cache, is never pushed out, and is made again after writes. | a pinned dashboard query answers from memory after every restart | [pinned queries](pinned-queries.md) |
| **GROUP BY with many groups.** Tens of thousands of groups, `buyer = seller`, `date_trunc` keys, `count(DISTINCT)` and `CASE` inside `sum` run in the column engine. | 30 days of trades by symbol and broker: 84 -> 14 ms | [GROUP BY](group-by.md), [performance tips](performance-tips.md#many-groups), report |
| **GROUP BY over UNION ALL** groups each part by itself first. | buy side + sell side in one query: 1,750 -> 29 ms | [UNION](union-subqueries.md), [performance tips](performance-tips.md#big-group-by) |
| **Integer hash join.** A join on one equality of numbers no longer makes a text key for every row. | | [joins](joins.md) |
| **Procedure parameters prune partitions.** `WHERE date = d` inside a procedure reads only that day. | 1 of 1,060 partitions read; 16 ms cold, 0.2 ms warm | [procedures](procedures.md), report |

**Example: See it in EXPLAIN: a day skipped by its column stats**

```sql
CREATE TABLE trades (time TIMESTAMP, symbol SYMBOL, qty LONG) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO trades VALUES
  ('2026-09-21T10:00:00Z', 'CITY', 100), ('2026-09-21T11:00:00Z', 'COAST', 250),
  ('2026-09-22T10:00:00Z', 'CITY', 4000), ('2026-09-22T11:00:00Z', 'COAST', 5200);
-- No row of 2026-09-21 has qty over 1000, so that day is never read.
EXPLAIN SELECT count(*) FROM trades WHERE qty > 1000;
```

Result:

`CREATE TABLE trades (`

```text
table 'trades' created
```

`INSERT INTO trades VALUES ('2026-09-21T10:00:00Z', 'CITY', 100), ('2026-09-21T11:00:00Z', 'COAST', 2`

```text
4 row(s) inserted
```

`EXPLAIN SELECT count(*) FROM trades WHERE qty > 1000`

| plan (STRING) |
|---|
| scan table trades (2 of 2 partitions, about 4 rows) |
| build 2 of 3 stored column(s) per row: time, qty |
| filter while scanning: 1 condition(s) |
| group by 0 key(s), 1 aggregate(s) |
| engine: column |

(5 rows)

<a id="loads"></a>

## Faster loads

Big loads go through the fast columnar path in more cases, and a trigger on one table no longer slows the others.

| What changed | Measured | Read more |
|---|---|---|
| **Line protocol in one pass (2026-10-06).** A line shaped like the one before it is read in one pass, and its values go straight into the table columns; a line that is different in any way is read as before, with the same errors. | 1 million trades lines in 100,000-line batches, 2 cores: 1.55M -> 2.2M rows/s, half the server CPU; 2 million candles 1.7M -> 2.4M rows/s | [line protocol](line-protocol.md) |
| **Tables without a DEDUP KEY are written as runs.** A trade list, where two trades in one second are both real, now takes the same fast path as a candle table. | 814,535 real trades, 20,000 rows a request: 438k -> 918k rows/s; QuestDB 678k rows/s on the same PC (KDB 35% faster, was 36% slower) | [line protocol](line-protocol.md), report |
| **Per-table trigger gate.** An immediate trigger on one table no longer sends every write of the database down the row-by-row path. | a 20,000-row write into a table with no trigger, while another table has one: 34 -> 8 ms (the same as no trigger at all) | [triggers](triggers.md) |
| **Deferred triggers.** `CREATE TRIGGER ... AFTER INSERT ON t DEFERRED` runs the trigger body after the load returns, as a background job. | a 20,000-row write into a table with a heavy trigger: 103 -> 9 ms once the trigger is deferred | [triggers](triggers.md#deferred) |
| **Batch duplicate check.** A `/write` batch into a table whose `SORT BY` differs from its `DEDUP KEY` is checked as one batch and stays on the fast path. | | [partitions and DEDUP KEY](partitions-and-dedup.md) |
| **`dedup=skip`** on `POST /write` and `POST /imp` loads rows you know are new without the duplicate check; `DEDUP TABLE` repairs duplicates afterwards. | | [dedup=skip](partitions-and-dedup.md#dedup-skip), [DEDUP TABLE](partitions-and-dedup.md#dedup-table) |
| **`PARTITION BY MONTH, SYMBOL(col)`** (also `YEAR` or `NONE`) puts each symbol of a new time-series table in its own partitions, so `col = 'X'` and `col IN (...)` read only those. | | [partitions and DEDUP KEY](partitions-and-dedup.md#partition-by) |
| **Packed partitions (2026-09-25).** `ALTER TABLE t SET (compression = on)` stores the sealed partitions of a table packed; `COMPRESS TABLE t` shows how far the background pass is. Off by default. | a floorsheet-shaped table of 3 million rows: 76.1 -> 15.5 bytes a row on disk; the first GROUP BY after a start 433 -> 368 ms | [compression](partitions-and-dedup.md#compression) |

<a id="search"></a>

## Search

Searches of 200,000 news articles now beat PostgreSQL 18 with a GIN index on every measured query but one, where the two tie.

The one tie is a word plus a symbol and a month (0.54 vs 0.48 ms). The articles hold 378 MB of text.

| What changed | Measured (KDB vs PostgreSQL 18) | Read more |
|---|---|---|
| **Counts come from the index.** `count(*)` of a search no longer fetches every found row, and a search never falls back to reading every text. | common word: 3.6 ms vs 250 ms (69x); mid word: 0.66 ms vs 82 ms (124x) | [full-text search](full-text-search.md), report |
| **Word positions in the index.** A phrase like `"hydro power"` is answered from the index. | 2,347 -> 9.7 ms (PostgreSQL 295 ms) | [search text](full-text-search.md#search-syntax) |
| **LIMIT goes into the index.** `ORDER BY id LIMIT 20` on a search stops after 20 rows. | forum search: 7.16 -> 0.265 ms (PostgreSQL 0.843 ms) | [full-text search](full-text-search.md) |
| **The cheaper index goes first.** A search plus a plain filter (a symbol, a month) starts with whichever index finds fewer rows, and checks the other condition on those rows only. | | [EXPLAIN](explain.md) |
| **Ranked search** (`ORDER BY search_rank(...) LIMIT 20`) on the same 200,000 articles. | top 20: 5.5 to 16.9 ms vs 364 to 408 ms (23x to 66x); 8 clients: 348/s vs 23/s | [search_rank](full-text-search.md#search-rank) |
| **Readers locked against writers.** A search no longer reads the index while a write changes it, a likely cause of a silent exit under many searches. | | [full-text search](full-text-search.md) |

<a id="writes"></a>

## Writes, locks and transactions

Writers of different tables now run at the same time.

| What changed | Measured | Read more |
|---|---|---|
| **Table-level write locks.** A write locks only the tables it changes, not the whole database. Deadlocks between two writers are found and one is told to retry. | 8 clients doing bank transfers: 604 -> 1,981 transfers/s; PostgreSQL 890/s in the same minutes | [transactions](transactions.md#one-writer), report |
| **Group commit.** Several transactions that finish together share one disk flush. | (part of the number above) | [transactions](transactions.md) |
| **LOCK TABLE, pg_locks, pg_blocking_pids.** `LOCK TABLE ... IN <mode> MODE [NOWAIT]` with PostgreSQL's eight modes; `pg_locks` shows holders and waiters with `pg_stat_activity`'s pids; a deadlock names both pids (`40P01`); `log_lock_waits` logs a wait over `deadlock_timeout`. | the same speed while no `LOCK TABLE` is held (before and after, side by side): taking and freeing one table lock 81-84 ns and 83-84 ns; a one-row `UPDATE` 16.8-17.0 us and 16.5-17.3 us; a primary-key `SELECT` 6.3-6.8 us and 6.2-6.4 us | [LOCK TABLE](transactions.md#lock-table) |
| **One disk wait per pipeline.** On the PostgreSQL port, several `Execute`s before one `Sync` wait for the disk once, at the `Sync`. | counter updates, batches of 32, 1 connection: 211 -> 4,277 a second | [performance tips](performance-tips.md#one-wait) |
| **Reader yield.** With `--reader-yield on` (or `KDB_READER_YIELD=on`) reads do not wait for a long trigger or `CALL`; they read the last committed rows. | | [kdb serve](cli-serve.md) |
| **Index lookups on a snapshot** (2026-10-02). With snapshot reads on, a lookup by a plain or expression index on a table a long `CALL` writes uses the index on the snapshot, at any table size, instead of waiting (over 1,000,000 rows) or reading every row. | 1.1 million rows, lookups during a long `CALL`: p50 0.12 ms, p99 3.3 ms | [snapshot reads](transactions.md#snapshot-reads) |
| **Opening a big database** no longer blocks the database list, `/api/stats` or other databases. | a 9.5 GB database, 124 s open: `/api/stats` answered in 100 to 110 ms all the way through | [many databases](cli-serve.md#many-databases) |
| **Shared memory budget.** Idle databases give memory back first; writers keep a floor. | | [performance tips](performance-tips.md#memory) |

<a id="protection"></a>

## Protection

New checks for a full disk, junk input and slow patterns, all with tests.

| What changed | Measured | Read more |
|---|---|---|
| **A full disk.** Committed rows stay intact, the client gets HTTP **507** `{"code":"disk full"}` (SQLSTATE **53100** on the PostgreSQL port), and writes go on when space comes back, with no restart. Five faults fixed on the way. | 24 rounds x 3 log modes x 2 places for the fault, all pass | [limits](limits.md#disk-memory), report |
| **Junk text.** NUL bytes, broken UTF-8, emoji, 1 MB texts and broken search syntax through every text function and the search. | 12,132 junk statements: no crash, no hang; every junk row still found by its clean word after a restart | report |
| **The statement timeout stops scans sooner.** It is now checked every 1,024 rows, also for rows not yet saved to files. | a 300 ms timeout ended a 187 s regexp scan of 200,000 rows in 0.9 s | [statement timeout](protection.md#statement-timeout) |
| **Encryption at rest** (2026-09-26). `CREATE DATABASE x WITH (encryption = on)` encrypts every file, log record and backup of that database with AES-256-GCM (ChaCha20-Poly1305 without AES instructions). Off by default; the master key comes from `KDB_MASTER_KEY` or a key file, never the data folder. | scans of loaded data +3%; the first scan after opening +18%, short of the 10% goal; files +2.3% | [encryption at rest](encryption.md) |
| **Timers need admin and are audited.** | | [timers](timers.md) |
| **The memory limit holds.** It counts what the process holds (resident), not only the heap; quick statements run in a small reserve at the limit; the result cache is dropped before the limit refuses work; a big `INSERT ... SELECT` into a keyed table puts its rows in as it goes; `SELECT` of another database runs there. | 400,000 rows into a DEDUP `YEAR, SYMBOL` table: ~1,100 -> ~150-280 bytes a row, 1.7 s -> 0.9 s; `count(*)` of 400,000 rows in another database: 486 ms and 363 MB -> 0.2 ms | [kdb serve](cli-serve.md#memory-limit) |
| **All 52 test programs under ASan and UBSan** (tools that catch memory mistakes). | one finding, fixed (an empty text passed to `memcpy` in the password hash code) | [test report](test-report.md) |

<a id="operations"></a>

## Running the server

Less disk, faster checkpoints, backups under load, and the help in the terminal.

| What changed | Measured | Read more |
|---|---|---|
| **Old files leave the trash while the server runs.** The idle thread empties trash older than an hour, every minute (it used to wait for a restart). `PURGE TRASH` and `PURGE VERSIONS [KEEP n]` free space now; `GET /api/disk` shows what each part takes. | `PURGE TRASH` freed 39.6 GB in 49 s on a real data folder | [PURGE TRASH](databases.md#purge-trash), [PURGE VERSIONS](databases.md#purge-versions), report |
| **Keep data for a time.** `DROP PARTITION ... OLDER THAN`, a table TTL, and monthly timers drop old rows on a schedule. | | [Keep data page](console-keep-data.md), [timers](timers.md), [DROP PARTITION](partitions-and-dedup.md#drop-partition) |
| **Old log kept per database.** `ALTER DATABASE ... SET WAL_ARCHIVE` keeps the old write-ahead log for point-in-time restore. | | [WAL_ARCHIVE](databases.md#wal-archive) |
| **Leftover keys of dropped tables are swept** at open and at every checkpoint. `kdb info` shows the count. | 300 partitions, one table dropped: manifest 1,128 -> 573 KB; checkpoint 24.6 -> 14.7 ms | [kdb info](cli-maintenance.md) |
| **Backup under load.** | a 2.1 GB backup made and verified in 7 s while 16 query lanes and 2 writers ran: 0 errors, 0 timeouts | [backup](backup-and-safety.md) |
| **30-minute soak** on the table-locks build. | 19.9M line-protocol rows + 1.36M SQL rows, 64,637 queries, 14 checkpoints, 0 errors, every row accounted for | [test report](test-report.md), report |
| **Memory given back** to the system on Linux (glibc) builds after big queries. | | [performance tips](performance-tips.md#memory) |
| **`kdb help [<topic> \| tutorial]`** prints the help topics and the tutorial in the terminal. | | [the kdb program](cli-overview.md) |

<a id="sql"></a>

## SQL and the HTTP API

New SQL for queries across databases and procedures, and two HTTP options that make answers smaller.

| What changed | Read more |
|---|---|
| `/exec?format=columns` answers one array per column, the shape a chart wants. | [format=columns](http-exec.md#format) |
| `/exec` sends an `ETag`; a client that sends it back in `If-None-Match` gets **304** and no body when nothing changed. | [ETag](http-exec.md#etag) |
| Queries across databases: `otherdb.table` in any `SELECT`. | [queries across databases](cross-database-queries.md) |
| `EXECUTE` runs SQL made at run time inside a procedure. | [procedure language](procedure-language.md) |
| `CREATE MATERIALIZED VIEW`, refreshed partition by partition. Since 2026-09-26 also QuestDB's `SAMPLE BY` form, refreshed bucket by bucket (1,000,000 ticks: a one-tick refresh about 4 ms, was a day's partition), `REFRESH ... CONCURRENTLY / FULL / INCREMENTAL / RANGE`, `materialized_views()` and `views()`. | [materialized views](views.md#materialized-view) |
| `(symbol, time) IN (('CITY', '2026-09-10'), ...)` on keys, and time zones for data stored at local midnight. | [WHERE](where.md), [time zones](time-and-time-zones.md) |
| `SELECT DISTINCT date` and `min`/`max`/`count(DISTINCT)` of it answered from the partition list, without reading rows. | [EXPLAIN](explain.md) |
| `TRUNCATE ALL TABLES`. | [TRUNCATE ALL TABLES](databases.md#truncate-all-tables) |
| `RIGHT JOIN`, `FULL JOIN`, `JOIN ... USING (columns)` (PostgreSQL), `LT JOIN` and `SPLICE JOIN` (QuestDB), `ON (symbol)` keys for time joins (2026-09-25). 1M rows: `RIGHT` / `FULL JOIN` about as fast as `LEFT JOIN` (0.41 s), `LT JOIN` as `ASOF JOIN` (0.5 s). | [joins](joins.md#right-join) |
| 2026-09-26: QuestDB time filters: `time IN '2026-09-24;1d'`, repeated windows `'...T05:15;1h;1d;5'`, `IN today()` / `interval(a, b)`, `LIMIT -n` (the newest n rows), `LATEST BY`, `DECLARE @x := ...`, and `timestamp_ceil`, `days_in_month`, `timestamp_sequence` and more. Only the partitions of the windows are read. | [interval lists](where.md#interval-lists), [LIMIT -n](order-by-limit.md#limit), [timestamp_ceil](functions-date-time.md#timestamp_ceil) |
| 2026-09-25: `first()` / `last()` keep a NULL first / last row, as in QuestDB; `first_not_null()` / `last_not_null()` skip it. | [first](functions-aggregate.md#first) |
| 2026-09-25: `encode(sha256(x), 'hex')` gives the 64-character hash as in PostgreSQL; `sha224/384/512`, `digest`, `convert_to`, `convert_from`, `round_half_even`. | [sha256](functions-security.md#sha256), [convert_to](functions-bytes.md#convert_to) |
| 2026-09-26: PostgreSQL's pgcrypto: `pgp_sym_encrypt` / `pgp_sym_decrypt` (OpenPGP, opens in PostgreSQL and GnuPG), `encrypt` / `decrypt`, `crypt` / `gen_salt` (bcrypt, MD5, DES), `gen_random_bytes`, `armor` / `dearmor`; QuestDB's `base64`. 1M rows: `digest(x, 'sha1')` 0.76 -> 0.44 s, `md5(x)` 0.52 -> 0.33 s. | [pgcrypto](functions-security.md#pgcrypto) |
| 2026-09-25: `jsonb - 'key'`, `#-`, and JSON to rows: `jsonb_each`, `jsonb_array_elements`, `json_to_recordset`, `jsonb_populate_recordset`, ... | [JSON to rows](functions-json.md#json-rows) |
| 2026-09-25: a NaN from a calculation is stored as NaN, not NULL; `/exec?nan=string` sends NaN and Infinity as text. | [DOUBLE](column-types.md#double), [nan=string](http-exec.md#nan) |
| 2026-10-02: in a time-series table a NaN is stored as NULL, as in QuestDB, so `open IS NULL OR open <= 0` finds it (a CHECK still refuses it); QuestDB's `ksum` / `nsum` are `sum`, whose DOUBLE total is compensated (exactly 55128735 where QuestDB's plain `sum` gives 55128734.99999999). | [DOUBLE](column-types.md#double), [sum](functions-aggregate.md#sum) |
| 2026-09-26: PostgreSQL's JSON path language: `jsonb_path_query`, `jsonb_path_match`, `@?`, `@@`, filters, sums and methods; `jsonb_pretty`, `jsonb_strip_nulls`, `jsonb_set_lax`, `jsonb_insert`, `jsonb_object`, `jsonb_agg`, `json(b)_object_agg`, `array_to_json`. 1M rows: `jsonb_path_exists` 0.82 -> 0.34 s, `doc @? '$.n ? (@ > 50)'` 0.13 s. | [JSON path](functions-json.md#jsonpath) |
| 2026-09-26: QuestDB's `query_activity()`, `CANCEL QUERY <id>` and `cancel_query(id)`; `GET /api/sessions` and `DELETE /api/sessions/<pid>`; `pg_terminate_backend` sends `57P01`; `pg_sleep`, `idle_session_timeout` (`57P05`), `client_connection_check_interval` and TCP keepalive on every connection. | [query_activity and CANCEL QUERY](server-activity.md#query-activity), [idle and vanished clients](server-activity.md#idle-clients) |
| `pg_stat_activity` lists every connection, HTTP session and running request (it was empty); `pg_cancel_backend` and `pg_terminate_backend` stop them; `pg_stat_statements` keeps calls, times and rows per statement shape, for a few hundred nanoseconds per statement. | [pg_stat_activity and pg_stat_statements](server-activity.md) |
| `EXPLAIN ANALYZE` runs a `SELECT` and shows its real rows, the time of each part, the engine, the partitions read and the memory held; `EXPLAIN (FORMAT JSON)` gives the plan as JSON. | [EXPLAIN ANALYZE](explain.md#explain-analyze) |
| `LISTEN`, `NOTIFY` and `pg_notify()` as in PostgreSQL, and `GET /listen` (server-sent events) for web pages; triggers can send them. | [LISTEN and NOTIFY](listen-notify.md) |
| Rows that expire one by one: `CREATE TABLE ... WITH (ttl_column = expires_at)`. | [rows that expire](create-table.md#row-ttl) |
| 2026-09-26: a table as it was, `SELECT ... FROM t AS OF TIMESTAMP '...'` or `AS OF LSN n` (undo a bad import with one `INSERT OR REPLACE ... SELECT`), and `CREATE DATABASE test BRANCH OF live [AS OF ...]`: a writable copy that shares the data files (no copying, no extra disk). | [time travel and branches](as-of-and-branches.md) |

<a id="console"></a>

## Console, help and packages

A new console layout, install packages, and the console, help and skill as plain folders next to the program.

| What changed | Read more |
|---|---|
| A redesigned console: timers page, activity log (inserts and trigger time), a Tools panel (`PURGE TRASH`, `TRUNCATE ALL TABLES`), a Delete button for databases, a Keep data page and a Save disk view. | [web console](web-console.md), [Keep data page](console-keep-data.md), [Monitor page](console-monitor.md) |
| Comments and suggestions from the Help menu. | [feedback](feedback.md) |
| Install packages for Windows and Linux, and a Docker image. | [install packages](install-packages.md) |
| Nothing is built into the program: the console, the help and the Claude skill are the folders `web/`, `help/` and `skill/` next to `kdb`. A console or help change needs no new program. | [where kdb finds them](install-packages.md#folders) |
| A skill file that teaches an AI assistant in another project how to use KDB (`kdb skill install`, `GET /skill.md`). | [the Claude skill](install-packages.md#skill) |
