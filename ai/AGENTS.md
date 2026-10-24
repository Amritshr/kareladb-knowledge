<!-- Made from the KarelaDB skills (skills/kareladb, skills/kareladb-geometry). Copy this file into your project. -->

# KarelaDB

KarelaDB (KARELA DataBase) is a database written in C++. One program serves an HTTP API, a PostgreSQL wire
port and a web console. It is **not** kdb+/q - the query language is ordinary
SQL.

## Where it runs

| What | Default | Override |
|---|---|---|
| HTTP API and web console | `http://localhost:9900` | `$KARELADB_URL` (or the old `$KDB_URL`) |
| PostgreSQL wire protocol | `localhost:8832` | - |
| Token | - | `$KARELADB_TOKEN` (or the old `$KDB_TOKEN`) |

Auth goes on every request as `Authorization: Bearer $KARELADB_TOKEN`. That may be the
server's `--token` or a named API token (`kdbt_...`, made with `CREATE TOKEN name FOR USER u`)
with that user's rights; `DROP TOKEN name` revokes one. HTTP 429 with `Retry-After`
means a rate limit or too many statements at once: wait that many seconds.

A server started with TLS (`--tls-cert`, or `KARELADB_TLS_CERT=auto` in Docker) wants
`https://` and PostgreSQL `sslmode=require` from other computers (`curl -k` or
`--cacert <data>/_tls/kdb-cert.pem` for its self-signed certificate); plain
`http://` from the same computer still works.

Set the two names once per shell, so the commands below also work where only the
old `KDB_URL` / `KDB_TOKEN` are set, then check it is up first:

```bash
KARELADB_URL="${KARELADB_URL:-${KDB_URL:-http://localhost:9900}}"
KARELADB_TOKEN="${KARELADB_TOKEN:-$KDB_TOKEN}"
curl -s "$KARELADB_URL/health"
```

If that fails, KarelaDB is not running. Say so rather than guessing - do not start a
second server to work around it.

A "This installation" section at the end of this file holds the real address,
the paths and where the token file is when `kareladb skill install` wrote them there
(the token itself is in that file, never in this one: do not print or copy it).

## Running SQL

`GET /exec` runs **read-only** SQL (a SELECT calling `nextval()` or with a `DELETE ... RETURNING` WITH is refused, 405). `POST /exec` runs **anything**.

```bash
# read
curl -s -G "$KARELADB_URL/exec" \
  --data-urlencode "query=SELECT * FROM companies LIMIT 5" \
  -H "Authorization: Bearer $KARELADB_TOKEN"

# write - the body is the SQL; many statements allowed, separated by ;
curl -s -X POST "$KARELADB_URL/exec" \
  -H "Authorization: Bearer $KARELADB_TOKEN" \
  -H "Content-Type: text/plain; charset=utf-8" \
  --data-binary "INSERT INTO companies VALUES ('CITY','City Bank','Banking',100);"
```

The answer is JSON:

```json
{"columns":[{"name":"x","type":"LONG"}],"dataset":[[2]],"count":1,
 "results":[{"...":"one per statement"}],"timings":{}}
```

Rows are in `dataset` as arrays in `columns` order. On failure the JSON has
`error`, plus `line` and `column` when KarelaDB knows where in the SQL, and
`sqlstate` (the PostgreSQL code: `23505` duplicate key, `23503` foreign key, or
the code a trigger's `RAISE ... USING ERRCODE` chose). A `23505`/`23503` also
has `table` and `constraint` (like `users_email_key`), as the PostgreSQL port
sends in `ConstraintName`/`TableName`. Status
codes: 400 bad SQL, 401 or 403 auth, 404 unknown database, 408 statement
timeout, 413 body over 64 MB or a memory limit, 503 a table is busy (another
writer held it past the lock timeout, 5 s unless set), the server is stopping
or its memory is full (`memory full: ...` under `--memory-limit`; retry after
2 s; PostgreSQL `53200`; a running statement that held the most memory when the
server went over its limit gets it too - read less at once and retry), 507 the disk is full (nothing of the request was saved, unless the
message says `applied in memory`: those rows are in, so do not send them again). With several statements in one
body, each is saved on its own as it finishes, and the body stops at the first statement that fails: the answer is
an error, `results` holds only the statements before it, `saved` says how many of them are saved, and the statements
after it did not run. Add `atomic=1` to make the body all or nothing.

Parameters, given in the URL or as a form field: `db=<name>` picks the
database, `limit=N` caps rows per statement (default 10,000: check `truncated`
in the answer before trusting a count of rows), `compat=0` drops the duplicated
top-level copy of the last result, `format=columns` gives one array per column
instead of one per row (smaller, faster to chart), `cache=0` skips the result
cache. Every answer with rows carries an `ETag`; send it back as
`If-None-Match` and an unchanged result costs a `304` with no body.

A big copy needs no chunking: `INSERT INTO t SELECT ... FROM src WHERE ...`
(also `UNION ALL` of such reads) writes rows while it reads them, so the 1 GB
per-query memory limit does not stop it. With `GROUP BY`, `DISTINCT`, a window,
`ORDER BY` or `LIMIT` the rows are kept first and that limit applies.

One query may read a table of another database on the same server as
`otherdb.table` (joins, subqueries, `INSERT INTO t SELECT ... FROM otherdb.t2`).
Changes stay in the database the request runs in. Keep shared reference data
in one database and read it from the others instead of copying it.

A table as it was: `SELECT ... FROM t AS OF TIMESTAMP '2026-09-25 14:30'`
(or `AS OF LSN n`; the commit LSNs are in `changes('t')`). Undo a bad load with
`INSERT OR REPLACE INTO t SELECT * FROM t AS OF TIMESTAMP '...'`. How far back
depends on `KARELADB_KEEP_VERSIONS` (older file versions, 2) and the old log; a point
that is gone, or before a TRUNCATE / emptied partition, is refused ("no longer
kept"), never answered wrong. To try a risky change on real data first:
`CREATE DATABASE test BRANCH OF live [AS OF ...]` (a full writable copy that
shares the data files, made in about a second; admin only), then `DROP DATABASE test`.

## Other endpoints worth knowing

| Route | What it does |
|---|---|
| `GET /health` | is it alive |
| `GET /api/info` | every table, its columns, row counts, sizes |
| `GET /exp` | as `/exec`, but the answer is a CSV file |
| `POST /imp` | load a CSV file into a table |
| `POST /write` | load rows in the InfluxDB line format (fast bulk); a table that is not there is made from the lines, as in QuestDB (needs role ddl) |
| `POST /api/backup`, `GET /api/backups` | make and list backups (default folder `_backups` in the data folder; `point_in_time` says how far back a restore can go) |
| `POST /api/restore` `{"as":"new_db","until":"2026-09-24 14:05:09"}` | restore a backup into a NEW database while the server runs (admin); `until` = point in time, `"latest"` = up to now |
| `POST /api/databases/swap` `{"database":"a","with":"b"}` | the two databases trade data; rights and settings stay with the names (admin; both unused) |
| `POST /session`, `POST /cursor` | transactions and paged reads across requests |
| `GET /v/<name>?param=value` | a saved query: `CREATE ENDPOINT GET /v/last_close(symbol TEXT, n INT DEFAULT 1) AS SELECT ... WHERE symbol = :symbol LIMIT :n`; values are typed and bound, never SQL |
| `Idempotency-Key: <text>` header | on `POST /exec`, `/write`, `/imp`: a retry with the same key gets the first answer instead of writing twice (24 h, per user and database) |
| `GET/POST /api/timers` | timers: saved SQL (often `CALL proc()`) that the server runs on a schedule like `every 5m`, `daily 16:00`, `weekdays 11:00`, `sun-thu 11:00`, `monthly 1 02:00` or `trading nepse 15:05` (trading days of a `CREATE CALENDAR`: eras of weekdays plus holidays; SQL `is_trading_day('nepse', ts)`, `next_trading_day`, `prev_trading_day`, `trading_days_between`, `suggest_calendar_eras(ts)`); `POST /api/timers/<name>/run` runs one now. Old data: `ALTER TABLE t SET TTL 6 MONTHS` drops old partitions by itself; a monthly timer can run `ALTER TABLE t DROP PARTITION OLDER THAN 6 MONTHS` instead |
| `GET /api/trigger-queue` | the jobs of DEFERRED triggers: waiting, running, failed |
| `GET/POST/DELETE /api/pins` | pinned queries: kept in the cache for good and run again after writes (admin) |
| `GET /api/stats` | memory, cache, partitions loaded, zone-map skips, running statements, disk use by kind per database (`disk`); a database being opened with its `phase` and log bytes replayed (`opening_databases`), a running `checkpoint`, `warnings` (data far bigger than `--memory`). Never waits for a busy database (`busy: true`) |
| `GET /metrics` | Prometheus text: request and statement time histograms, lock waits, cache, checkpoints, WAL bytes, memory and disk by kind, trigger queues, timers. Cheap: counters only |
| `GET /api/slow-queries` | statements over the slow threshold (`--slow-query-ms`, default 1000 ms), newest first, kept on disk across restarts |
| `GET /api/rev?table=candles&symbol=NABIL` | committed revision per symbol (and `table_rev`): poll it and read the candles again only when it changed; never waits for writers. SQL: `kdb_rev('candles', 'NABIL')` |
| `GET /listen?channel=orders` | LISTEN as server-sent events (`EventSource`): one JSON event per `NOTIFY orders, '...'` or `pg_notify('orders', ...)`, sent when its transaction commits; `&pattern=price.*` = PSUBSCRIBE (events then carry `"pattern"`). On the pg port use `LISTEN orders` as in PostgreSQL; triggers can NOTIFY |
| `POST /kv` | Redis-like key-value store: body `["INCR","hits"]` or a pipeline `[["SET","otp:1","123456","EX",120],["GET","otp:1"]]` -> `["OK","123456"]` (one reply per command; errors as `{"error":"..."}`). GET/SET (NX XX EX PX GET KEEPTTL), INCR/INCRBY/INCRBYFLOAT, MGET/MSET, EXPIRE/TTL/PERSIST, DEL, EXISTS, KEYS, SCAN, RENAME, FLUSHDB ... Keys live in memory and in table `_kv` (SELECT only). `?sync=off` answers before the disk sync (fastest). SQL: `kv_get(k)`, `kv_set(k, v[, ttl_s])`, `kv_incr(k[, n])`, `kv('MGET','a','b')`. Pub/sub: `PUBLISH ch msg` (sent at once, answers listener count; reaches /listen and pg LISTEN), `PUBSUB CHANNELS|NUMSUB|NUMPAT`; keyspace events with `CONFIG SET notify-keyspace-events Ex` (server admin) on `__keyevent@0__:expired` / `__keyspace@0__:<key>` (evictions send `__keyevent@0__:evicted`, class `e`). Memory cap: `["CONFIG","SET","maxmemory","64mb","maxmemory-policy","allkeys-lru"]`, `MEMORY USAGE k`, `kv_memory()`. Cache tables: `CREATE TABLE c (k TEXT PRIMARY KEY, v TEXT) WITH (max_bytes='64MB', evict='lru' \| 'volatile_ttl' \| ..., durability='none')` |
| `CREATE TABLE ... WITH (ttl_column = expires_at)` | rows that expire one by one, like Redis keys: gone at once for every read and write, deleted within a second; `INSERT ... ON CONFLICT DO UPDATE` on an expired key starts over (an INCR with EXPIRE) |
| `GET /api/disk` | what a database takes on disk: data, older file copies, trash, log. Space back: `PURGE VERSIONS KEEP 1` (older copies) and `PURGE TRASH` (this database; `PURGE TRASH ALL` = the whole server, dropped databases too); old trash also goes by itself every minute (`KARELADB_TRASH_KEEP_HOURS`, `KARELADB_TRASH_MAX_MB` caps its size, `KARELADB_KEEP_VERSIONS`). Console: Keep data page, **Save disk** |
| `GET /` | the web console |
| `GET /help` | the full help: one page per topic under `/help/`, with a search |
| `GET /skill.md` | this file |

## From PostgreSQL clients

Port 8832 speaks the PostgreSQL wire protocol, so `psql`, DBeaver and the
normal drivers for Python, Node, C#, and Go connect straight to it. Use it when
a library expects a real SQL connection instead of HTTP. The server allows 100
logged-in connections for all databases together unless started with
`--max-connections N` (a closed connection frees its place at once); size
connection pools to fit.

- `SET app.flag = 'on'`, `SET LOCAL app.flag = 'on'` (ends at COMMIT/ROLLBACK),
  `set_config(name, value, is_local)` and `current_setting(name [, missing_ok])`
  are per connection, and triggers run by that connection's statements see them.
- `pg_try_advisory_*` and `pg_advisory_unlock*` come back typed `bool`; a lone
  `SELECT pg_advisory_xact_lock(...)` inside `BEGIN` waits without blocking others.
- A column declared `INTERVAL` is sent as a real `interval` (Go `time.Duration`);
  over HTTP it is a number of milliseconds. Parameters next to it (`d > $1`,
  `d + $1`) take an interval too; `sum(d)`/`avg(d)` come back as intervals. To pass
  milliseconds as a number, write `$1::bigint`.
- Times are stored and shown in UTC. `SET TIME ZONE 'Asia/Kathmandu'` (or the
  server's `--timezone`) makes `CURRENT_DATE`, `::date`, `date_trunc`, `EXTRACT`,
  `to_char` and `ts >= CURRENT_DATE` use that clock, and the driver gets
  `TimeZone` back. Zones with summer time (America/New_York) work from the
  system's zone files (tzdata); `SAMPLE BY`, time
  text without an offset and materialized view buckets stay UTC. Over HTTP: the same SQL, or the header
  `X-KDB-Time-Zone`.
- `/` gives a DOUBLE in KarelaDB (`7 / 2` = `3.5`). For PostgreSQL's whole-number
  division (`7 / 2` = `3`) send `SET int_division = integer`, put
  `int_division=integer` in the connection string, or start the server with
  `--pg-int-division on` (`KARELADB_PG_INT_DIVISION=on`). It works over HTTP too, for
  the rest of the request (`SET int_division = integer; SELECT ...`).
  CHECK, DEFAULT, computed columns, index expressions and materialized views
  always divide as DOUBLE, whatever the session's setting.
- `SET kdb.pg_compat = on` (or `ALTER DATABASE x SET pg_compat = on`, or the
  connection string `options=-c kdb.pg_compat=on`) gives PostgreSQL 14's
  answers: integer division, `1.5` and `x::numeric` as exact NUMERIC, a window
  with ORDER BY and no frame is `RANGE UNBOUNDED PRECEDING`, window NULLs as in
  PostgreSQL, text ORDER BY / `<` by an en_US-like order, and on the PG port a
  plain TIMESTAMP is the session's wall clock. Off by default (held for the
  owner); KarelaDB's own answers never change while it is off.
- `JSON`/`JSONB` columns take `?`, `?|`, `?&`, `@>` / `<@` (nested objects too)
  and `jsonb_path_exists`; `CREATE INDEX ... USING GIN (doc)` indexes the keys and
  values for `@>`, `?` and `doc ->> 'k' = 'v'`. `doc - 'key'`, `doc #- '{a,0}'`,
  and JSON to rows in FROM (`jsonb_each`, `jsonb_array_elements(_text)`,
  `json_to_recordset($1) AS r(id INT, ...)`, `jsonb_populate_recordset(NULL::t, $1)`)
  work as in PostgreSQL; the argument must be a value, not a column of another
  FROM table (no LATERAL call yet).
- `first(x)` / `last(x)` give the first / last row's value even when it is NULL
  (QuestDB); `first_not_null` / `last_not_null` skip NULLs (`any_value` and `arbitrary` are read as `first_not_null`).
- `sha256(text)` gives hex text; `sha256(bytes)` gives bytes, and
  `encode(sha256(convert_to(t, 'UTF8')), 'hex')` works as in PostgreSQL. A NaN is
  stored as NaN (not NULL) in a relational table, as NULL in a time-series table
  (QuestDB; a CHECK still refuses it); `/exec` writes NaN and Infinity as `null` unless
  `?nan=string`.
- `GENERATED ALWAYS AS (expr) STORED` is worked out on every write and stored
  (indexable, `UNIQUE`); without `STORED` it is worked out on read.

## The SQL

Ordinary SQL (PostgreSQL-like: `TRUNCATE`, `CREATE TABLE AS`, `ALTER COLUMN
TYPE`, `ON DELETE CASCADE`, `WITH RECURSIVE`, `INSERT ... ON CONFLICT`,
window functions also over `GROUP BY` results, `GROUP BY ROLLUP / CUBE /
GROUPING SETS` with `GROUPING()`, `CREATE TYPE ... AS ENUM` with `ALTER TYPE
... ADD VALUE` - an ENUM column takes only its labels and sorts in label
order), plus time-series extras: `SAMPLE BY` for candles and time
buckets, partitioned time-series tables with a designated timestamp column,
computed columns, views, triggers, saved functions, and a large function
library covering indicators, finance, statistics, regex, JSON, text and dates.
Split- and bonus-adjusted prices without changing the data: `SELECT ... FROM
day_bars ADJUSTED BY corp_actions` (a table of `symbol, ex_date, factor`;
prices before an ex-date are divided by the later factors, volumes multiplied).
`CREATE TEMP TABLE` is one session's (gone when it ends; without a session,
at the end of the request). Not PostgreSQL: `CREATE UNLOGGED TABLE` is
refused, and a `sum()` of `LONG` values
whose total passes 64 bits is an error (`22003`), not a NUMERIC - write
`sum(x::DOUBLE)` for an approximate total. DECIMAL is exact as in PostgreSQL:
DECIMAL arithmetic, `sum` and `avg` give DECIMAL (up to 38 digits; `avg` has
at least 16 significant digits), `NUMERIC(p, s)` holds `p` digits up to 38,
and a number literal of more than 15 digits is read exactly.

Text compares and sorts byte by byte, like PostgreSQL's `COLLATE "C"`
(`'Zebra' < 'apple'`). For dictionary order write `ORDER BY name COLLATE "en_US"`;
`COLLATE nocase` makes `=` ignore case, `COLLATE natural` sorts `file2` before
`file10`. `lower`, `upper` and `initcap` work for every script with capitals.

## Designing a time-series table

```sql
CREATE TABLE trades (
  time TIMESTAMP, symbol SYMBOL, contract_no LONG, buyer INT, seller INT,
  quantity LONG, rate DOUBLE, amount DOUBLE
) TIMESERIES(time) PARTITION BY DAY SORT BY (symbol, time) DEDUP KEY (contract_no, time);
```

| Choice | Rule of thumb |
|---|---|
| `PARTITION BY DAY / MONTH / YEAR / NONE` | one file per bucket. Pick the bucket most queries ask for: `DAY` for a trade list read a day at a time, `MONTH` or `YEAR` for candles |
| `SORT BY (symbol, time)` | rows of one symbol sit together inside the file, so `WHERE symbol = 'X'` reads one slice. KarelaDB also skips whole partitions that do not hold the symbol |
| `DEDUP KEY (...)` | a re-sent row replaces the old one with `INSERT OR REPLACE` (and in loads), so loads can be repeated safely. A plain `INSERT` of a key that is there fails unless the table has `WITH (dedup_insert = 'upsert')` (or `ALTER TABLE t SET (dedup_insert = 'upsert')`), which makes it replace, as QuestDB does. The key must hold the time column, or a stored minute of it: `minute TIMESTAMP GENERATED ALWAYS AS (date_trunc('minute', time)) STORED ... DEDUP KEY (symbol, minute)` makes 10:01:07 and 10:01:42 one row (the later wins) |
| dedup skip | a trusted bulk load that knows its rows are new can skip the key lookups: `POST /write?dedup=skip`, `INSERT ... WITH (dedup = skip)`, or `SET dedup = skip` for a session (also its PostgreSQL `COPY`). A key that was stored already may then be there twice; `DEDUP TABLE t [FOR 'day']` repairs it |
| `SYMBOL` vs `STRING` | `SYMBOL` for a repeated short text (ticker, broker, category): stored once, compared as a number |

### Partition by a text column as well as by time

For data that is nearly always read **one value at a time** (one ticker's
candles, one source's news, one company's fundamentals), a second partition level
keeps each value in its own file:

```sql
CREATE TABLE candles (...) TIMESERIES(time)
  PARTITION BY YEAR, SYMBOL(symbol)      -- MONTH or NONE also work; DAY is refused
  SORT BY (symbol, time) DEDUP KEY (symbol, time);

CREATE TABLE news (...) TIMESERIES(time)
  PARTITION BY MONTH, KEY(source) ...    -- KEY(col) is the same thing; any SYMBOL or STRING column
```

- The column must be the **first** `SORT BY` column and part of the `DEDUP KEY`.
- `WHERE symbol = 'X'` or `symbol IN (...)` then opens only those files
  (`EXPLAIN` shows `2 of 62 partitions`).
- `ALTER TABLE t DROP PARTITION '2024'` drops every value of that bucket.
- Values may hold any characters (`/`, spaces, unicode); at most 64 bytes.
- **Not for a column with very many values** (a user id): each value is a file.
  `NONE, SYMBOL(col)` refuses past 4,096 values. Keep such a column as the first
  `SORT BY` column instead - that already gives a one-slice read.
- **Reads get faster, writes do not**: a batch holding 300 symbols touches 300
  files. Do not use it for a table that is read a whole day at a time across
  all symbols (a trade list) - plain `PARTITION BY DAY` is right there.
- New tables only: an existing table cannot be converted yet, and relational
  tables (`PRIMARY KEY`, no `TIMESERIES`) cannot be partitioned.

## Old partitions in S3, MinIO, R2 or B2 (cold storage)

Sealed partitions of a time-series table can move to object storage and are still
read by every query (only the column files a query needs are fetched, into a local
cache). Help: `cold-storage`.

```sql
-- the store is defined by settings, never in SQL: KARELADB_COLD_<NAME>_URL, _BUCKET,
-- _REGION, _ACCESS_KEY, _SECRET_KEY (MinIO: _PATH_STYLE=on); cache KARELADB_COLD_CACHE_MB
ALTER TABLE ticks SET (cold_storage = 'archive', cold_after = '90 days');  -- moves by itself
ALTER TABLE ticks MOVE PARTITION '2025-01' TO COLD;                         -- or now
ALTER TABLE ticks MOVE PARTITION '2025-01' FROM COLD;                       -- back to local
SELECT * FROM cold_partitions();                                            -- what is where
```

- The newest partition never moves. A query whose time range has no cold partition costs nothing extra; one that reads a cold partition pays a fetch the first time.
- Writes into a cold partition work: the write fetches it first, so an unreachable store fails that statement.
- Not for a database encrypted at rest. `/metrics` counts it as `kdb_cold_*`.

## Grafana and Prometheus

- **Grafana**: add a built-in **PostgreSQL** data source at port 8832 (database = the KarelaDB database, a read-only user). `$__timeFilter`, `$__timeGroupAlias`, `$__timeGroup` and template variables work; `SAMPLE BY` gives fast candles.
- **Prometheus**: scrape `GET /metrics` (counter names `kdb_*`).
- Two ready dashboards (server health; candles, volume and trades), provisioning files and a `docker-compose.yml` are in `integrations/grafana` in the source. Help: `grafana`.
- Telegraf and other line-protocol senders write to `POST /write`.

## Writing fast queries

- **Always pass `db=`.** Tables live in a named database; without it you query
  `default` and get "table does not exist".
- **Give a time range** on the time column (`time >= '2026-09-01' AND time <
  '2026-10-01'`, or `time IN '2026-09'`): whole partitions are skipped. A filter
  on a `DATE` text column or on `to_char(time, ...)` skips nothing.
- **Bucket by time with `SAMPLE BY 1d`**, or group by `date_trunc('day', time)`.
  `timestamp_floor('15m', time)` (QuestDB), `time_bucket(INTERVAL '15 minutes', time)`
  (TimescaleDB), `date_bin('15 minutes', time, origin)` (PostgreSQL) and
  `extract(hour FROM time)` are just as fast as GROUP BY keys (column engine).
  Candles read often belong in a materialized view, kept up to date after
  every write, one bucket at a time: `CREATE MATERIALIZED VIEW mv1m AS (SELECT
  time, symbol, first(price) o, max(price) h, min(price) l, last(price) c,
  sum(qty) v FROM ticks SAMPLE BY 1m) PARTITION BY DAY` (QuestDB's form; no
  FILL). The refresh runs in the background just after the commit: poll
  `SELECT refresh_base_table_txn = base_table_txn FROM materialized_views()`
  or run `REFRESH MATERIALIZED VIEW mv1m INCREMENTAL` when a read must see the
  write. A bulk load (100k+ rows a second over several `/write` requests) is
  refreshed once in one go after it pauses for 0.3 s, not between its
  requests; a read of the view during the load waits for that refresh. `GROUP BY` with many groups, `col = other_col`, `sum(CASE WHEN ... END)`,
  `count(DISTINCT col)`, `sum(a) - sum(b)`, `LIKE` / `ILIKE` / `NOT LIKE`,
  `BETWEEN`, `IN (...)` and `col = a OR col = b` on one column all run in the
  fast column engine (1M rows in about 1 ms). What still drops to the slow
  row-by-row engine (100x slower): math or a function on a column in `WHERE`
  (`price * qty > X`, `abs(x) > 5`: store the value as a column instead), `OR`
  of anything but `col = a OR col = b` on one column, a `JOIN`, a subquery in `FROM` that is not a `UNION ALL` of plain
  SELECTs, window functions, and a table with computed columns. One such part
  of an `AND` sends the whole query there. `EXPLAIN <query>` says which
  partitions are read, and its last line names the engine: `engine: column`,
  or `engine: row (why)`.
- **Whole-table totals are free**: `count(*)`, `sum`, `min`, `max`, `avg` with
  no `WHERE` (or only a time range) are answered from the files' saved stats
  without reading rows: 69M rows in under 1 ms. `EXPLAIN` says "answer from
  saved stats".
- **Name the columns you need** instead of `SELECT *`: the slow path then builds
  only those columns (2x on a wide table).
- **Clustered columns skip files by themselves**: a `WHERE` on a column whose
  values grow with time (ids, contract numbers) skips partitions whose min/max
  cannot match ("skipped by column stats" in `EXPLAIN`).
- **Buy and sell legs in one query**: `SELECT symbol, broker, sum(bq), sum(sq)
  FROM (SELECT symbol, buyer broker, quantity bq, 0 sq FROM fs WHERE ... UNION
  ALL SELECT symbol, seller broker, 0 bq, quantity sq FROM fs WHERE ...) GROUP BY
  symbol, broker` is grouped part by part in the column engine (`sum`, `count`,
  `min`, `max`; `EXPLAIN` starts with "aggregates pushed into the 2 UNION ALL
  parts"). `avg`, `first`, `last`, `DISTINCT` or a part with its own `GROUP BY`
  keep the slow form: then ask for the two legs as two grouped queries.
- **Latest row per key**: `LATEST ON time PARTITION BY symbol`, not a self-join.
- **Results are cached** by query text until what they read changes. One
  result may use at most a quarter of the cache (64 MB of the default 256 MB;
  a pinned one three quarters); a bigger one is not kept. A result that took
  1 ms or more is kept the first time, a quicker one only when the same query
  comes a second time. Queries with `random()` are never kept, and with
  `now()` only for a caller that accepts an older answer (`cache_now_ms=500`,
  `SET result_cache_now_ms = 500`). On a table
  with `PARTITION BY ..., SYMBOL(symbol)` or `symbol` first in `SORT BY` /
  `DEDUP KEY`, a `WHERE symbol = 'X'` result survives writes of other symbols;
  other results of the table go on any write. To time the engine itself add
  `cache=0` to the request. The PostgreSQL port uses the cache too
  (on for every new connection): send `SET result_cache = off` on each
  connection of a benchmark. `EXPLAIN`'s "about N rows" is only an estimate
  of the whole table, not the rows a query reads.
- **Send `compat=0`** (halves the reply) and **reuse the connection** (HTTP
  keep-alive): for small queries the connection costs more than the query.
- **The first read after a restart is slow** (files are loaded whole); the
  second is what users see. Indexes are built in the background right after
  a database opens; pin the queries users need fast after a restart
  (`/api/pins`).
- **Loading**: `POST /write` with many rows per request (tens of thousands), not
  one request per row or per symbol. Re-sending a batch is safe with a
  `DEDUP KEY`. A table without a `DEDUP KEY` loads fastest (about 900k rows/s).
  Request bodies may be gzip.
- **Triggers on a bulk-loaded table**: an ordinary (immediate) `AFTER INSERT`
  trigger makes every load into **that** table go row by row (about 4x slower). Make
  it `DEFERRED`: the load returns at full speed and the trigger runs right
  after the commit, from a queue (`/api/trigger-queue`). A trigger on one table
  does not slow loads into the others. A failed job runs again by itself (3 tries,
  1 s / 2 s / 4 s apart), then stops its trigger's queue until `RETRY TRIGGER QUEUE`
  or `SKIP TRIGGER JOB`; failures show in `/api/stats` (`alerts`) and the activity
  log. At 10,000 waiting jobs a write is refused with 503 and the reason.
- **Calling a web service from SQL** (a procedure or timer telling another
  service something): `http_get(url [, headers])` and
  `http_post(url, body [, content_type [, headers]])` return JSON
  `{"status":200,"headers":{...},"body":"..."}`; read it with `r ->> 'body'` and
  `json_value_long(r, '$.status')`. `headers` is a JSON object like
  `'{"Authorization":"Bearer ..."}'`. Off until the server lists the hosts in
  `http_functions` (kareladb.conf, `KARELADB_HTTP_FUNCTIONS` or the Settings page, e.g.
  `"10.0.0.5:8080, api.example.com"`); a refusal is 403 / `42501`. Needs role
  write; never cached; `http_timeout_ms` (10 s) per call, 16 MB answer, 3
  redirects to allowed hosts only; https certificates are checked. Help topic
  `http-functions`.
- **Many writers**: writers of different tables run at the same time; writers of
  one table take turns (up to the lock timeout, then 503 / `55P03` "table is
  busy": retry). The wait is 5 s unless the server sets `--lock-timeout`; a
  session can set its own with `SET lock_timeout = '20s'`, and one HTTP request
  with the header `X-KDB-Lock-Timeout: 20s` (also on `/write` and `/imp`; a
  PostgreSQL `COPY` follows the connection's `SET lock_timeout`). A
  `CALL` locks every table it may touch; an `EXECUTE` whose text is built
  while it runs (`format()`, `||`) locks every table, so keep big procedures
  off the hot path. A `CALL` whose procedure changes nothing (no
  INSERT/UPDATE/DELETE, FOR UPDATE, nextval, dynamic EXECUTE) locks nothing
  and runs like a SELECT; declare it `CREATE PROCEDURE p() READ ONLY AS
  BEGIN ... END` to have KarelaDB refuse a body that writes. CREATE/ALTER/DROP TABLE,
  RENAME, CREATE/DROP INDEX, CREATE/ALTER/DROP TRIGGER, TRUNCATE, CREATE TABLE
  AS (the tables it reads) and materialized views (the view and its table)
  lock only their tables; views, procedures and functions lock no table. They
  wait for writers of other tables only until those pause between two
  statements - but a procedure/function change waits for a running writer
  that runs a procedure, function or plpgsql trigger (a long CALL), and a view
  change for a running writer that reads views. Sequences, BACKUP and
  DDL sent in one request with the statements it affects
  (`CREATE OR REPLACE PROCEDURE p ...; CALL p()`) lock the whole database, but
  `CREATE ... IF NOT EXISTS` of something already there (and other no-op
  `IF [NOT] EXISTS` forms) locks nothing, so start-up DDL never waits. A
  request that gets "busy" ran none of its statements: send all of it again.
  "Busy" (`55P03`) is never a duplicate key: retry, and the retry says
  `23505` if the key is really taken. Inside the session's own `BEGIN ...
  COMMIT` the same refusal is `40001` (serialization_failure): roll back and
  run the whole transaction again. An open transaction
  that sends nothing for 30 s is rolled back (`SET
  idle_in_transaction_session_timeout = '5min'`, `0` = never).
- **Isolation**: transactions are SERIALIZABLE by default - a `SELECT` inside
  `BEGIN` locks its tables until `COMMIT`, so "read v, write v+1" never loses
  an update (other writers wait). `BEGIN ISOLATION LEVEL READ COMMITTED`,
  `SET TRANSACTION ISOLATION LEVEL READ COMMITTED` or `SET
  default_transaction_isolation = 'read committed'` make a `SELECT` sent on its
  own read tables the transaction has not written without locking them (as in
  PostgreSQL; updates can then be lost - use `UPDATE ... SET v = v + 1`).
- **Savepoints**: `SAVEPOINT a`, `ROLLBACK TO SAVEPOINT a`, `RELEASE SAVEPOINT a`
  inside `BEGIN ... COMMIT`. In a session an error after a savepoint aborts
  the transaction (`25P02` for other statements) and `ROLLBACK TO SAVEPOINT`
  makes it usable again; without a savepoint an error rolls it all back.
- **SET ROLE name** / `RESET ROLE`: a session checks its SQL against another
  KarelaDB user's rights (an admin login dropping to the app user's rights).
  Roles: `read < write < ddl < admin`; `ddl` changes the schema (a migration
  tool) but cannot manage users, settings, backups or the audit log; a view
  or routine it saves is checked against its own table rights.
  `SHOW AUDIT VERIFY` (admin) checks the audit log's hash chain.
- **Readers**: a `SELECT` waits only while a writer is running on a table it
  reads; `SELECT 1`, logins and reads of other tables answer at once during a
  long `CALL`, bulk load or checkpoint. Readers of the writer's own tables wait
  only for the statement running now, not the whole trigger or `CALL`
  (`--reader-yield`, on by default). With `--snapshot-reads on`
  (`KARELADB_SNAPSHOT_READS=on`) they do not wait at all: they read a snapshot of
  the committed rows. An indexed table is read that way too while a writer is
  busy on it, at any size, and plain or expression indexes are still used
  (since 2026-10-02); only a table with a full-text or JSON index over
  `--snapshot-index-rows` rows (1,000,000) still waits. A read of `information_schema` /
  `pg_catalog` or `SHOW` still waits for every writer. For a job queue use
  `BEGIN; SELECT ... ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED` on a table
  with a primary key: it locks only the rows it returns (until COMMIT), so
  several workers take different jobs at the same time; `NOWAIT` fails at once
  (503 / `55P03`) only on a locked row. An UPDATE / DELETE by primary key
  inside BEGIN locks only its rows too; an INSERT, or a change of a table with
  a secondary UNIQUE or a FOREIGN KEY, keeps the whole table until COMMIT:
  send such a statement just before COMMIT. Without a primary key FOR UPDATE
  locks the whole table. A transaction that read a row another one was
  changing and then changes it gets `40001`: run it again.

## Cluster: automatic failover

Two data nodes and a witness (`kareladb witness`, no data) elect a leader;
when the leader's computer dies the other data node takes writes within
about 6 s (3.6-6 s measured). Each node: `--node-id a --cluster-peers a=http://h1:9900,b=http://h2:9900,w=http://h3:9900`
(the same list everywhere) and the same token. Help topic: `cluster`.

- Writes go to the leader. Give PostgreSQL clients both data nodes:
  `postgresql://u:p@h1:8832,h2:8832/default?target_session_attrs=read-write`.
  Over HTTP a follower answers a write with `421` and `X-KarelaDB-Leader: <url>`:
  send it again there. `GET /health?role=leader` is 200 only on the leader.
- `KARELADB_SYNC_STANDBYS=1` (default): a commit is confirmed once the other
  data node holds it too, so a dead leader loses nothing confirmed. While no
  standby copies (it is down, or only the witness is reachable), commits are
  confirmed without one (`kdb_cluster_sync_fallback_total` counts them).
  `KARELADB_SYNC_STANDBYS=required`: never confirmed without a standby. While
  none copies, a write is refused before it is written (`25006`, nothing to
  undo: send it again later); a write whose standby left while it waited fails
  after `KARELADB_SYNC_WAIT_MS` (10 s) or its statement_timeout (`25006`, "no
  standby holds this commit": it is on the leader, check before resending).
  `0`: faster, but a dead leader loses what the follower had not copied, and a
  leader that is only cut off keeps confirming for up to 3 s (its lease):
  those rows end up in its `_diverged` folder, not in the cluster.
- A commit that fails during a failover (`25006`, `421`, "may be lost", a
  closed connection) may or may not be there: check on the new leader before
  sending it again (or write rows with a key, so a repeat does no harm).
- Followers serve reads; to read your own write there, send the leader's
  `X-KarelaDB-Lsn` back as `X-KarelaDB-Min-Lsn`.
- `GET /api/cluster` (token) shows role, term, leader, lag; `/metrics` has `kdb_cluster_*`.

## Server options

`kareladb serve` reads its settings when it starts, from three places. The first
one that has a value wins:

| Place | Example | To change it |
|---|---|---|
| a flag | `--http-threads 32` | restart the program; in Docker, recreate the container |
| `kareladb.conf` (JSON next to kareladb; `/data/kareladb.conf` in Docker) | `{"http_threads": 32}` | edit the file, then `POST /api/restart` (admin) |
| a `KARELADB_*` environment variable (or its old name `KDB_*`) | `KARELADB_HTTP_THREADS=32` | restart the program; in Docker, recreate the container |

Four settings apply at once, with no restart, when saved on the console's
Settings page (`POST /api/settings`): `cache_mb`, `wal_archive_mb`,
`http_functions` and `http_timeout_ms`. `GET /api/settings` (admin) shows the
value in use and where it came from. Only the options below that have a
`kareladb.conf` key can be changed without touching the command line. Ask the
server's owner before changing any of them: they affect every user.

The most useful ones:

| Option (flag / env / kareladb.conf) | Default | What it does |
|---|---|---|
| `--memory` MB (Docker: `KARELADB_MEMORY`) | 512 (Docker image 256); without the flag at most 40% of the memory limit | table data kept loaded, for all databases together. Keep it near the data size and under half of `--memory-limit` |
| `--memory-limit` / `KARELADB_MEMORY_LIMIT` | 85% of the container's memory limit, else of the machine's | one cap for everything. At 80% memory is given back; at 95% new statements wait 2 s, then get 503 / `53200` "memory full" (safe to retry). A reserve of 8 places lets quick reads like `SELECT 1` through even then |
| `--cache-mb` / `KARELADB_CACHE_MB` / `cache_mb` | 256, at most a tenth of the memory limit | the result cache of all databases; one result may use a quarter of it |
| `--threads` | half the CPUs the process may use (follows `docker update --cpus`) | threads inside one big query or load |
| `--http-threads` / `KARELADB_HTTP_THREADS` / `http_threads` | the CPUs, at least 8, at most 64 | HTTP requests that run at once; a slow query holds one until it ends |
| `--max-connections` / `KARELADB_MAX_CONNECTIONS` / `max_connections` | 100 | PostgreSQL logins at once, all databases (0 = no limit) |
| `--statement-timeout` | 60s | longest statement: 408 / `57014` after it. A session: `SET statement_timeout = '5s'` |
| `--max-result-memory`, `--max-groups` | 1GB, 5000000 | what one query may hold: 413 / `54000` past it |
| `--max-queries-per-user` | 32 | statements one user runs at once (the token is not counted) |
| `--sync-commits always\|batch` | always | `batch`: a write is confirmed at once and on disk within 10 ms; a crash may lose the last few ms. A session: `SET synchronous_commit = off` |
| `--timezone` / `KARELADB_TIMEZONE` / `timezone` | UTC | clock of `CURRENT_DATE`, `::date`, `date_trunc`, `EXTRACT`, timers and backups. A session: `SET TIME ZONE` |
| `--slow-query-ms` / `KARELADB_SLOW_QUERY_MS` / `slow_query_ms` | 1000 | statements this slow go to `GET /api/slow-queries` (0 = off) |

Readers and writers:

| Option | Default | What it does |
|---|---|---|
| `--lock-timeout` / `KARELADB_LOCK_TIMEOUT` / `lock_timeout_ms` | 5s | a writer waits this long for a busy table, then 503 / `55P03` |
| `--idle-in-transaction-timeout` / `KARELADB_IDLE_IN_TRANSACTION_TIMEOUT` / `idle_in_transaction_timeout_ms` | 30s | an open `BEGIN` that sends nothing this long is rolled back |
| `--lanes` / `KARELADB_LANES` (+ `--heavy-ms`, `--heavy-slots`, `--heavy-queue`) | on, 100 ms of CPU, half the CPUs, half the HTTP threads (min 4) | priority lanes: a read whose shape used 100 ms+ of CPU three times in a row waits for a heavy slot, so charts stay fast. The wait is limited by the statement timeout, which then starts again for the run. Only an HTTP request sent with priority low is refused when the HTTP line is full: 503 + `Retry-After: 1` "server is busy" (safe to retry); PostgreSQL clients wait instead. Never inside BEGIN. Also `--read-slots` / `KARELADB_READ_SLOTS` (default auto = the CPUs, at least 2): short reads take turns, at most that many at once, each holding its slot at most 10 ms; keeps a `docker --cpus 2` container from losing throughput as clients grow (`off` = old behaviour). `X-KDB-Priority: low` (or `SET kdb.priority = low`, `ALTER USER x SET kdb.priority = low`) for reports; `high` (admin, or a user set high) never waits |
| `--reader-yield` / `KARELADB_READER_YIELD` | on | a reader waits only for the writer's current statement, not the whole `CALL` or trigger |
| `--snapshot-reads` / `KARELADB_SNAPSHOT_READS` | off | a reader of a table being written reads a snapshot and does not wait |
| `--snapshot-index-rows` / `KARELADB_SNAPSHOT_INDEX_ROWS` | 1000000 | the biggest table with a full-text/JSON index (or an index not built yet) a snapshot read may scan; a bigger one waits (0 = indexed tables never get snapshots) |
| `--per-table-reads` / `KARELADB_PER_TABLE_READS` | on | a reader waits only for writers of its own tables, not for checkpoints |
| `--read-only-calls` / `KARELADB_READ_ONLY_CALLS` | on | a `CALL` that changes nothing runs like a `SELECT` (no locks) |
| `--scoped-ddl` / `KARELADB_SCOPED_DDL` | on | `CREATE` / `ALTER` / `DROP` lock only their own tables |
| `--ddl-beside-writers` / `KARELADB_DDL_BESIDE_WRITERS` | on | `CREATE TABLE`, `ALTER TABLE`, `RENAME`, `CREATE` / `DROP INDEX` run beside a long writer of other tables |
| `--skip-locked-beside` / `KARELADB_SKIP_LOCKED_BESIDE` | off | `FOR UPDATE SKIP LOCKED` inside `BEGIN` also returns free rows of a table another open transaction holds |
| `--log-lock-waits` / `KARELADB_LOG_LOCK_WAITS` | off | a statement waiting for a table lock longer than `--deadlock-timeout` writes one log line naming who holds it (`SET log_lock_waits = on` per session) |
| `--deadlock-timeout` / `KARELADB_DEADLOCK_TIMEOUT` | 1s | when `--log-lock-waits` writes its line; deadlocks are found at once anyway |
| `--warm-indexes` / `KARELADB_WARM_INDEXES` | on | indexes are built in the background right after a database opens |
| `--trigger-retries` / `KARELADB_TRIGGER_RETRIES` | 3 | tries of a failed DEFERRED trigger job before its queue stops |
| `--max-trigger-jobs` / `KARELADB_MAX_TRIGGER_JOBS` | 10000 | waiting deferred jobs per database; past it writes get 503 |
| `--alert-webhook` / `KARELADB_ALERT_WEBHOOK` / `alert_webhook` | none | failed deferred jobs are POSTed as JSON to this `http://` address |
| `--timer-workers` / `KARELADB_TIMER_WORKERS` / `timer_workers` | 3 | timers that may run at the same time (1 to 64) |
| `--tcp-keepalives-idle`, `-interval`, `-count` / `KARELADB_TCP_KEEPALIVES_*` / `tcp_keepalives_*` | 0 (system) | TCP keepalive timings of every HTTP and pg connection (keepalive is always on) |

Security and the PostgreSQL port:

| Option | Default | What it does |
|---|---|---|
| `--bind`, `--port`, `--pg-port` | 127.0.0.1, 9900, 8832 | where it listens; `--pg-port 0` turns the PostgreSQL port off. Another address than 127.x needs a token or users |
| `--token`, `--token-name` / `KARELADB_TOKEN_NAME` | none, `token` | the shared admin secret, and the name the audit log gives it. `kareladb serve` reads no `KARELADB_TOKEN`: the Docker image passes it as `--token` |
| `--tls-cert`, `--tls-key` / `KARELADB_TLS_CERT`, `KARELADB_TLS_KEY` / `tls_cert`, `tls_key` | off | TLS on both ports; `auto` makes a self-signed pair |
| `--tls-required` / `KARELADB_TLS_REQUIRED` | on | with TLS, plain connections are refused except from 127.x |
| `--rate-limit-ip`, `--rate-limit-user` / `KARELADB_RATE_LIMIT_IP`, `KARELADB_RATE_LIMIT_USER` / `rate_limit_ip`, `rate_limit_user` | 0 (off) | requests per second per address / per user: 429 with `Retry-After` |
| `--safe-updates`, `--read-only` | off | refuse `UPDATE` / `DELETE` without `WHERE`; a whole server that only reads |
| `--audit on\|off`, `--audit-keep-days` | on, 0 (forever) | the security log in `_system` (`SHOW AUDIT`) |
| `http_functions`, `http_timeout_ms` / `KARELADB_HTTP_FUNCTIONS`, `KARELADB_HTTP_TIMEOUT_MS` | off, 10000 | the hosts `http_get()` / `http_post()` may call (no flag) |
| `--pg-timestamptz` | off | send `TIMESTAMP` as `timestamptz` on the PostgreSQL port |
| `--pg-int-division` / `KARELADB_PG_INT_DIVISION` | off | on the PostgreSQL port `7 / 2` is `3`, as in PostgreSQL. A session: `SET int_division = integer` |
| `--pg-compat` / `KARELADB_PG_COMPAT` | off | PostgreSQL 14's answers (exact decimal literals and `::numeric`, `RANGE` window frames, PG's window NULL order, en_US text order, plain `TIMESTAMP` as the session's wall clock on the PG port). Per database: `ALTER DATABASE x SET pg_compat = on`; a session: `SET kdb.pg_compat = on`. Held for the owner: off |

Data, disk and backups:

| Option | Default | What it does |
|---|---|---|
| `--data-dir` / `KARELADB_DATA_DIR` / `data_dir` | `data` next to kareladb | the folder with one folder per database. Here the flag wins, then kareladb.conf, then the variable |
| `--config`, `--db` | `kareladb.conf` next to kareladb, `default` | the settings file; the database a request without `db=` uses |
| `--backups` / `KARELADB_BACKUP_DIR` / `backup_dir` | `_backups` in the data folder | backup folder (`off` = none) |
| `--backup-schedule` / `KARELADB_BACKUP_SCHEDULE` / `backup_schedule` | off | backups by themselves, like `daily 02:00` |
| `--keep-daily`, `--keep-weekly` / `KARELADB_BACKUP_KEEP_DAILY`, `_WEEKLY` / `backup_keep_daily`, `_weekly` | 7, 4 | backups kept |
| `--backup-command` / `KARELADB_BACKUP_COMMAND` / `backup_command`; `--backup-copy`; `--backup-warn-hours` | none; none; 26 | copy each backup off the server; a checked second copy; warn when the last good backup is older |
| `KARELADB_WAL_ARCHIVE_MB` / `wal_archive_mb` | 1024 | old log kept per database for repairs and point-in-time restore |
| `KARELADB_KEEP_VERSIONS` / `keep_versions`; `KARELADB_TRASH_KEEP_HOURS` / `trash_keep_hours`; `--trash-max-mb` / `KARELADB_TRASH_MAX_MB` / `trash_max_mb` | 2; 1; a quarter of the data (at least 256) | older file versions, and how long / how much the trash keeps |
| `--trash-days` | 7 | days `UNDROP TABLE` can bring a dropped table back |
| `--drain-timeout` / `KARELADB_DRAIN_TIMEOUT` | 30s (Docker image 5s) | on a stop, running requests may finish this long; new ones get 503 |
| `--activity-log-size` | 5000 | events in the console's activity panel (0 = off) |
| `web_dir`, `help_dir`, `skill_dir` / `KARELADB_WEB_DIR`, `KARELADB_HELP_DIR`, `KARELADB_SKILL_DIR` | next to kareladb | the console, help and skill folders |

Docker image only (read by its start script): `KARELADB_TOKEN` (required, becomes
`--token`), `KARELADB_MEMORY` (256, becomes `--memory`), `KARELADB_CONFIG`
(`/data/kareladb.conf`), `KARELADB_DATA_DIR` (`/data`), `KARELADB_CORE_DUMPS` (`on`: a crash
leaves a core dump in `/data/_logs/cores`; `off` = none) and `KARELADB_CORE_KEEP`
(2 dumps kept). `GLIBC_TUNABLES=glibc.malloc.arena_max=2` keeps less memory
per thread. Every `KARELADB_*` variable above works with `-e` too, and words after
the image name are added to `kareladb serve`.

Rarely needed: `KARELADB_LAZY_OPEN=off` reads every table file at open;
`KARELADB_SELF_TUNING_SECONDS` (10) is how often CPU and memory limits are read
again (0 = only at start); `KARELADB_TTL_CHECK_MS` (60000) is how often `TTL` drops
old partitions; `KARELADB_LEVEL_FROM_HEAP=1` judges memory by the heap alone. The
`KARELADB_NO_*` / `KARELADB_WINDOW_NO_*` switches, `KARELADB_CACHE_VERIFY` and
`KARELADB_INDEX_MAX_VISITS` turn engine features off to compare timings: never set
them on a server people use. Help topic `cli-serve` lists every option.

## Reading the full docs

The help is a set of short topics. Two ways to read them:

- **In a KarelaDB checkout:** `docs/help/topics/*.md`, plain markdown. Start with
  `http-overview.md`, `sql-basics.md`, `select.md`, `create-table.md`,
  `column-types.md`, `sample-by.md`, `postgres-protocol.md`. The function
  reference is in the `functions-*.md` files. For a problem on a running
  server (slow, busy tables, memory, disk, timers, backups, restore) start
  with `troubleshooting.md` (`/help/troubleshooting.html`).
- **From any machine that can reach the server:** `GET /help`.
- **On the web, with no server:** https://raw.githubusercontent.com/Amritshr/kareladb-knowledge/main/llms.txt
  lists every topic with a link to its markdown (the same topics, with each
  example's real result). Pages for people: https://amritshr.github.io/kareladb-knowledge/
- **Survey, CAD and 3D data** (points, drawings, layers, blocks, meshes, a canvas that
  loads in parts): `geometry-and-cad.md` (`/help/geometry-and-cad.html`). The checkout also
  has a skill for it, `.claude/skills/kareladb-geometry/SKILL.md`.

Every example in those topics is executed for real when the help is built, so
the examples are known to work.

## Cautions

- Do not start a second KarelaDB server on another port to test something. The
  server already running is the one that matters.
- In Docker the data lives in whatever is mounted at `/data` - a named volume
  or a folder on the host (`docker inspect <container>` shows which). Never
  remove it without asking.
- Prefer `--data-binary` over `--data` with curl so line breaks survive.
- `DROP TABLE t` is refused (2BP01) while a view, materialized view or foreign key
  uses `t`; the error names each. `DROP TABLE t CASCADE` drops them too.
- A `DOUBLE` keeps full precision (`9609.0/17` is `565.2352941176471`). When a
  procedure replaces a program that stores rates rounded (often to 6 places),
  store `round(x, 6)` and round both sides of filter comparisons, or rows
  differ in the last digit. Money that must add up exactly belongs in `DECIMAL(s)`
  (18 digits) or `NUMERIC(p, s)` (up to 38).

---

# KarelaDB for survey, CAD and 3D data

KarelaDB has **no geometry type and no spatial index**. Do not look for `ST_*` functions or
`GEOMETRY` columns: they do not exist. Everything below uses plain columns, rows,
triggers and SQL maths, and it is fast enough up to a few hundred thousand entities per
drawing. The full topic with runnable examples is `/help/geometry-and-cad.html` on the server
(`GET $KARELADB_URL/help/geometry-and-cad.html`). Connecting and running SQL is in the `kareladb` skill.

## The layout to use

| Thing | Table | Key columns |
|---|---|---|
| project | `projects` | `id`, `crs` (the one coordinate system of every number in it), `units` |
| survey point / shot | `points` | `(project, id)`, `x` easting, `y` northing, `z`, `code` (CP, TP, SP...), `observed` |
| raw instrument reading | `observations` | `station`, `bearing`, `vertical`, `slope`, `hi`, `ht` - coordinates are computed from these |
| drawing (also a block) | `drawings` | `id`, `project`, `name`, `props JSON` |
| layer | `layers` | `(drawing, name)`, `color`, `visible`, `locked` |
| entity | `entities` | `id UUID`, `drawing`, `layer`, `kind`, typed columns, `props JSON`, `min_x min_y max_x max_y`, `updated` |
| vertex | `vertices` | `(entity, seq)`, `x`, `y`, `z`, `bulge`; `REFERENCES entities(id) ON DELETE CASCADE` |
| mesh | `mesh_vertices`, `mesh_faces` | `(mesh, id)`; a face is three vertex ids |
| camera | `saved_views` | `(drawing, owner, name)`, `cx`, `cy`, `scale`, `rotation` - written rarely |

Rules that keep it right:

1. **One `crs` per project.** Never mix a local grid and a national grid in one table.
2. **`kind` says which columns mean something.** `line`/`polyline`: vertices. `circle`/`arc`:
   `cx cy radius` (+ `start_angle end_angle` in degrees, counter-clockwise from +x).
   `text`: `cx cy rotation` and `props.text`, `props.height`. `insert`: `block`, `cx cy rotation scale`.
   Groups: children carry the group's id in `parent`. These are DXF's conventions; keep them.
3. **The bounding box is always filled.** Vertex tables get `AFTER INSERT` and `AFTER UPDATE`
   triggers that recompute `min_x..max_y` of the entity from `min()`/`max()` over its vertices.
   Circles, text and inserts write their box in the same INSERT.
4. **Index `(drawing, min_x, min_y)`** on `entities`. The viewport query is
   `drawing = ? AND max_x >= x0 AND min_x <= x1 AND max_y >= y0 AND min_y <= y1`,
   joined to `layers` for `visible`.
5. **Vertices as rows, not JSON.** A `DOUBLE[]` is fine only for a list that is never edited
   in place and always read whole (a simplified copy for far zooms, for example).
6. **`props JSON` for the long tail** (colour, line weight, text). A field you filter on often
   gets its own column: `json_value()` cannot use an index.

## What stays in the client

Pan, zoom, the view matrix, hover and window selection never touch the database. The client
keeps a working set in memory, redraws from it every frame, and asks KarelaDB again only when the
view leaves the loaded region (ask with a margin of about one screen). Save the camera as a
row in `saved_views` when the user stops moving or closes the drawing, not per frame.

## Maths that is already in SQL

| Need | Expression |
|---|---|
| distance | `sqrt((x2-x1)*(x2-x1) + (y2-y1)*(y2-y1))` |
| surveyor's bearing (clockwise from north) | `degrees(atan2(x2-x1, y2-y1))`, add 360 if negative |
| coordinate from a shot | `x = sx + slope*sin(radians(vertical))*sin(radians(bearing))`, `y = ... cos(radians(bearing))`, `z = sz + hi + slope*cos(radians(vertical)) - ht` |
| arc start point / length | `cx + r*cos(radians(a0))`, `cy + r*sin(radians(a0))`; `r*radians(a1-a0)` |
| polyline length | `lag(x)`, `lag(y)` over `(PARTITION BY entity ORDER BY seq)`, sum the segment lengths; add the closing segment with `first_value()` when `closed` |
| polygon area | shoelace: `abs(sum(px*y - x*py) + closing term) / 2` with the same windows |
| mesh volume | `abs(sum(signed tetrahedron))/6` over the faces of a closed mesh |
| nearest point | narrow by a box on `x`, `y`, then `ORDER BY distance LIMIT 1` |

Use `sum(CASE WHEN ... END)`, never `max()`, for the closing term: it can be negative.

## History and several users

`SELECT ... FROM entities AS OF TIMESTAMP <t>` reads the drawing as it was; `INSERT OR
REPLACE ... SELECT * FROM entities AS OF ...` undoes an edit for everyone. `changes('entities')`
and `GET /api/changes?table=entities` give every committed change in order, so a second
viewer redraws what others change without polling. `CREATE DATABASE plan_b BRANCH OF <db>`
is a writable copy for a design alternative.

## Do not

- Do not store the camera, selection or matrix per frame.
- Do not put a whole drawing in one JSON document: it cannot be loaded in part or edited row by row.
- Do not invent `GEOMETRY`, `POINT`, `ST_Intersects`, `<->` or GiST indexes; say they are not in KarelaDB and use the box columns.
- Do not convert between datums in SQL; that is not built in.

## Full documentation

The full documentation (every topic, with examples and their real results) is indexed at https://raw.githubusercontent.com/Amritshr/kareladb-knowledge/main/llms.txt - read that index, then fetch only the topics the task needs.
