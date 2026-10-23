# Quick start

> Get kareladb, make a database, create a table, add rows, query them and open the web console.

- Category: Getting started
- Keywords: install, build, first steps, getting started, hello world, kareladb version, kareladb sql, kareladb shell, kareladb serve, console, sample data, tutorial
- See also: [Install packages and the Claude skill](install-packages.md), [SQL basics](sql-basics.md), [Sample data](sample-data.md), [Databases and the data folder](databases.md), [CREATE TABLE](create-table.md), [INSERT](insert.md), [Web console](web-console.md), [kareladb serve](cli-serve.md), [What's new](whats-new.md)

KarelaDB is one program: `kareladb` (`kareladb.exe` on Windows), with three folders of plain files next to it: `web/` (the web console), `help/` (these pages) and `skill/` (the Claude skill). It keeps each **database** in a folder. You talk to it with **SQL** (the language of databases). This page takes about 10 minutes.

KarelaDB is a general-purpose database: market and time-series data, sensor readings, logs and metrics, accounting, users and logins, app backends. A small example: a table of daily stock prices, three rows, and a query.

**Example: Your first table, rows and query**

```sql
CREATE TABLE ochl_day (
  time TIMESTAMP, symbol SYMBOL,
  open DOUBLE, high DOUBLE, low DOUBLE, close DOUBLE, volume DOUBLE
) TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (symbol, time);

INSERT INTO ochl_day VALUES
  ('2026-09-09', 'CITY', 512, 512.4, 504, 504.6, 182390),
  ('2026-09-10', 'CITY', 504.6, 507, 500.7, 504.9, 183040),
  ('2026-09-10', 'COAST', 380.5, 382, 375.2, 376.1, 186200);

SELECT time, symbol, close FROM ochl_day WHERE symbol = 'CITY';
```

Result:

`CREATE TABLE ochl_day (`

```text
table 'ochl_day' created
```

`INSERT INTO ochl_day VALUES ('2026-09-09', 'CITY', 512, 512.4, 504, 504.6, 182390), ('2026-09-10', '`

```text
3 row(s) inserted
```

`SELECT time, symbol, close FROM ochl_day WHERE symbol = 'CITY'`

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 504.6 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 |

(2 rows)

<a id="get-kdb"></a>

## Get KarelaDB

There are three ways. Pick one.

| Way | You run | Then |
|---|---|---|
| An install package | unpack `kareladb-<version>-windows-x64.zip` (or the Linux `.tar.gz`) and run `install.ps1` (or `install.sh`) | `kareladb` is on your PATH, with its `web`, `help` and `skill` folders |
| Docker | `docker run` with the image `kareladb` (below) | the server runs on port 9900, the PostgreSQL port on 8832 |
| Build from the source | `cmake` (below) | the program is in `build\bin\kareladb.exe` |

[Install packages](install-packages.md) explains the packages and the Docker image in full.

<a id="docker"></a>

### Docker

Syntax:

```sql
docker run -d --name kareladb -p 9900:9900 -p 8832:8832 -e KARELADB_TOKEN=<secret> -v <data>:/data kareladb
```

The image holds the program and its three folders. Make it once from the source folder with `docker build -t kareladb -f docker/Dockerfile .`. The data stays in the volume, so a new container keeps it.

- **Notes:** the server does not start without `KARELADB_TOKEN`. Paste the token into the console's token box, or send it as `Authorization: Bearer <token>`. Add `--restart unless-stopped --stop-timeout 60` so it comes back after a restart and stops cleanly. See [Docker](install-packages.md#docker).

```bash
docker run -d --name kareladb --restart unless-stopped --stop-timeout 60 \
  -p 9900:9900 -p 8832:8832 -e KARELADB_TOKEN=my-secret -v kdb-data:/data kareladb
curl http://127.0.0.1:9900/health
```

Then open <http://127.0.0.1:9900> and go on at [Open the web console](#console): the console and the HTTP API do everything the `kareladb sql` steps below do.

<a id="build"></a>

### Build from the source

Syntax:

```sql
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build --target kareladb
```

Build the program from the KarelaDB source folder. You need CMake, Ninja and a C++17 compiler (on Windows: MSYS2 UCRT64). KarelaDB needs no other libraries.

- **Returns:** the program `build\bin\kareladb.exe` (Linux and macOS: `build/bin/kareladb`).
- **Notes:** a `kareladb` run from `build\bin` finds the console, the help and the skill in the source folder by itself (`web/console`, `docs/help/site`, `.claude/skills/kareladb`). To copy it to another PC, copy `kareladb.exe` together with the folders `web`, `help` and `skill`, or make a package. Without `web/` the HTTP API still works, but `http://127.0.0.1:9900/` says the console is not installed. See [where kareladb finds them](install-packages.md#folders). [Chapter 1](../tutorial/01-install.md) explains every step.

```powershell
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build --target kareladb
$env:Path = "$PWD\build\bin;" + $env:Path
```

Check that it works:

**Command line: Show the version**

```bash
kareladb version
```

Output:

```text
KarelaDB 0.2.0-dev (crc32c hardware: yes)
tls: OpenSSL 3.6.3 9 Jun 2026

Stored-format features this build reads (52):
  views                0.2.0-dev (2026-09-10)   CREATE VIEW: the "views" file
  partition_format_2   0.2.0-dev (2026-09-11)   table partition files in format 2 (one raw block per column)
  block_stats          0.2.0-dev (2026-09-11)   column stats section in partition files (count, min, max, sum per column)
  runs                 0.2.0-dev (2026-09-11)   log record 'C': rows of a bulk upsert kept as columns
  auto_meta            0.2.0-dev (2026-09-11)   AUTO id counters in the manifest (auto.<table id>)
  json                 0.2.0-dev (2026-09-11)   JSON columns (type code 12)
  bytes                0.2.0-dev (2026-09-11)   BYTES columns (type code 13)
  check                0.2.0-dev (2026-09-11)   CHECK constraints (catalog format 2, part 'C')
  indexes              0.2.0-dev (2026-09-11)   CREATE INDEX, UNIQUE and FULLTEXT indexes (catalog part 'I')
  routines             0.2.0-dev (2026-09-11)   functions, procedures and triggers: the "routines" file
  users                0.2.0-dev (2026-09-11)   server users and roles (_system.users)
  audit                0.2.0-dev (2026-09-12)   SET AUDIT ON: catalog part 'A', log record 'P', the _audit_log table
  table_grants         0.2.0-dev (2026-09-12)   GRANT ... ON TABLE (_system.users.table_grants)
  totp                 0.2.0-dev (2026-09-12)   two-factor logins (_system.users.totp)
  trash                0.2.0-dev (2026-09-12)   dropped tables kept as _dropped_<ms>_<name> for UNDROP TABLE
  database_settings    0.2.0-dev (2026-09-12)   ALTER DATABASE ... SET READ ONLY (_system.database_settings)
  dialects             0.2.0-dev (2026-09-12)   ALTER DATABASE ... SET dialect (_system.database_dialects)
  pg_catalog_parts     0.2.0-dev (2026-09-12)   PostgreSQL column types, multi-column keys, foreign keys, expression and partial indexes (catalog parts 'T', 'K', 'F', 'X')
  sequences            0.2.0-dev (2026-09-12)   CREATE SEQUENCE: the "sequences" file and its log records
  batched_log_sync     0.2.0-dev (2026-09-11)   log segments in the batched format (header flag 1, 16-byte commit records): group commit and --sync-commits batch
  dedup_change         0.2.0-dev (2026-09-12)   ALTER TABLE ... DEDUP ENABLE / DISABLE: the DEDUP KEY of a table that already holds rows
  plpgsql_triggers     0.2.0-dev (2026-09-12)   PostgreSQL plpgsql trigger functions and FOR EACH ROW triggers in the "routines" file
  cached_views         0.2.0-dev (2026-09-13)   CREATE CACHED VIEW: which views are cached, and REFRESH ON COMMIT, in the "views" file
  deferred_triggers    0.2.0-dev (2026-09-13)   CREATE TRIGGER ... DEFERRED: job records in the log, and the "trigger_queue" and "q/<job>" files of queued jobs
  materialized_views   0.2.0-dev (2026-09-13)   CREATE MATERIALIZED VIEW: catalog part 'M', REFRESH MATERIALIZED VIEW log records, mv_dirty.<id> in the manifest
  table_ttl            0.2.0-dev (2026-09-13)   TTL n DAYS on a table: catalog part 'L'
  read_only_procedures 0.2.0-dev (2026-09-24)   CREATE PROCEDURE ... READ ONLY in the "routines" file
  dedup_insert         0.2.0-dev (2026-09-24)   WITH (dedup_insert = 'upsert') on a table: catalog part 'U'
  decimal128           0.2.0-dev (2026-09-25)   NUMERIC(p, s) columns with more than 18 digits: 128-bit DECIMAL (type code 14) in the catalog, partition files and log
  dedup_generated_key  0.2.0-dev (2026-09-25)   a stored generated column in a DEDUP KEY, like the minute of the time (an older build refuses such a catalog)
  symbol_partitions    0.2.0-dev (2026-09-25)   PARTITION BY <time>, SYMBOL(col): catalog part 'P' (one partition file per time bucket and symbol, t/<id>/<time>/s-...)
  round_time_zone      0.2.0-dev (2026-09-25)   TIMESTAMP ROUND ... TIME ZONE 'zone' columns: catalog part 'R'
  enum_types           0.2.0-dev (2026-09-25)   CREATE TYPE ... AS ENUM: the ENUM types after the tables of the catalog (catalog format 3)
  row_ttl              0.2.0-dev (2026-09-25)   CREATE TABLE ... WITH (ttl_column = c): rows expire one by one, catalog part 'E'
  column_compression   0.2.0-dev (2026-09-25)   ALTER TABLE ... SET (compression = on): catalog part 'Z' and packed partition files (header flag 2)
  calendars            0.2.0-dev (2026-09-25)   CREATE CALENDAR: trading calendars (eras, holidays, extra trading days) after the ENUM types of the catalog (catalog format 4)
  materialized_view_sample_by 0.2.0-dev (2026-09-26)   CREATE MATERIALIZED VIEW ... AS (SELECT ... SAMPLE BY ...): a SAMPLE BY query in catalog part 'M', refreshed bucket by bucket
  comments             0.2.0-dev (2026-09-26)   COMMENT ON TABLE / COLUMN: the comments of a table and its columns, catalog part 'N'
  cache_tables         0.2.0-dev (2026-10-02)   WITH (max_bytes, evict, durability): cache tables with a memory cap and eviction, catalog part 'Y'
  resident_tables      0.2.0-dev (2026-10-02)   WITH / SET (resident = on): a table never unloaded to make room, catalog part 'H'
  partition_tails      0.2.0-dev (2026-10-02)   tail files: rows appended to a partition saved in extra files t/<id>/<partition>.tail<k>.b<version> (tail_files)
  uuid                 0.2.0-dev (2026-10-02)   UUID columns: 16 bytes per value (type code 15) in the catalog, partition files and log
  search_analyzer      0.2.0-dev (2026-10-02)   CREATE FULLTEXT INDEX ... WITH (language = 'english'): the word analyzer of a full-text index, catalog part 'S'
  column_grants        0.2.0-dev (2026-10-02)   GRANT / REVOKE on single columns (_system.users.column_grants)
  row_policies         0.2.0-dev (2026-10-02)   row-level security: CREATE POLICY and ALTER TABLE ... ENABLE ROW LEVEL SECURITY (_system.row_policies)
  partition_deltas     0.2.0-dev (2026-10-02)   delta files: a few rows of a partition replaced or deleted, saved in t/<id>/<partition>.delta.b<version>
  fulltext_segments    0.2.0-dev (2026-10-02)   full-text and JSON index segments in fts/*.kfs (the words of each partition's rows; never recorded: an older build ignores them)
  compressed_log       0.2.0-dev (2026-10-02)   packed log records (type 3): the data records of a big commit written compressed (KARELADB_WAL_COMPRESS)
  endpoints            0.2.0-dev (2026-10-03)   CREATE ENDPOINT: saved queries served at GET /v/<name>, kind 'E' in the routines file
  rules                0.2.0-dev (2026-10-03)   CREATE RULE: named checks, session hours and settings of a table (catalog part 'Q')
  sync_commit_tables   0.2.0-dev (2026-10-03)   WITH (synchronous_commit = on | off) of a table: catalog part 'G'
  cold_storage         0.2.0-dev (2026-10-22)   cold storage: WITH / SET (cold_storage, cold_after), catalog part 'O', and partitions moved to an object store, kept as stub files (t/<id>/<partition>.cold.v<N>.kdb, header flag 1)

A database that uses a feature not in this list needs a newer KarelaDB (kareladb check exits with 3).
```

<a id="first-database"></a>

## Your first database

Syntax:

```sql
kareladb sql database "SQL"
```

`kareladb sql` opens a database, runs the SQL, prints the result and closes the database. When the database does not exist yet, KarelaDB makes a new empty one.

| Argument | Type | Meaning |
|---|---|---|
| `database` | name or folder | a database name like `shop`, or a folder path like `D:\kdb\shop` |
| `"SQL"` | text | one or more statements, separated by `;` |

- **Returns:** the result of each statement. Exit code `0` means OK, `1` means an error.
- **Notes:** a name without `\`, `/`, `:` or `.` means a database in the data folder, if one with that name is there; else a folder with that name in the current folder. See [databases](databases.md).

**Command line: Make a table in a new database, add a row, read it**

```bash
kareladb sql shop "CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL)"
kareladb sql shop "INSERT INTO brokers VALUES (58, 'Northgate Securities'), (45, 'Imperial Securities')"
kareladb sql shop "SELECT id, name FROM brokers ORDER BY id"
```

Output:

`> kareladb sql shop "CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL)"`

```text
table 'brokers' created
```

`> kareladb sql shop "INSERT INTO brokers VALUES (58, 'Northgate Securities'), (45, 'Imperial Securities')"`

```text
2 row(s) inserted
```

`> kareladb sql shop "SELECT id, name FROM brokers ORDER BY id"`

```text
id | name                
---+---------------------
45 | Imperial Securities 
58 | Northgate Securities
(2 rows, 0.2 ms)
```

A mistake gives a clear message and exit code 1:

**Command line: A typing mistake in a table name** (shows an error)

```bash
kareladb sql shop "CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL)"
kareladb sql shop "SELECT * FROM brokerz"
```

Output:

`> kareladb sql shop "CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL)"`

```text
table 'brokers' created
```

`> kareladb sql shop "SELECT * FROM brokerz"`

```text
error: line 1, column 15: table or view 'brokerz' does not exist
```

exit code 1

<a id="first-sql"></a>

## CREATE TABLE, INSERT and SELECT

Syntax:

```sql
CREATE TABLE name (column TYPE [rules], ...) [TIMESERIES(time_column) ...]
INSERT INTO name VALUES (value, ...), (value, ...)
SELECT columns FROM name [WHERE condition]
```

The three statements you use most. `CREATE TABLE` makes a table. `INSERT` adds rows. `SELECT` reads rows.

- There are two kinds of tables: **relational** (lists of things, like users) and **time-series** (rows with a time, like prices). See [CREATE TABLE](create-table.md).
- Text and times go in single quotes: `'CITY'`, `'2026-09-10'`.
- KarelaDB shows times in UTC (the `Z` at the end). Write a local time with its zone offset, for example `+05:45` (Nepal) or `-04:00` (New York).

**Example: App users: a relational table**

```sql
CREATE TABLE users (
  id    LONG PRIMARY KEY AUTO,
  email STRING NOT NULL UNIQUE,
  name  STRING
);
INSERT INTO users (email, name) VALUES ('ram@example.com', 'Ram'), ('sita@example.com', 'Sita');
SELECT id, email, name FROM users;
```

Result:

`CREATE TABLE users (`

```text
table 'users' created
```

`INSERT INTO users (email, name) VALUES ('ram@example.com', 'Ram'), ('sita@example.com', 'Sita')`

```text
2 row(s) inserted
```

`SELECT id, email, name FROM users`

| id (LONG) | email (STRING) | name (STRING) |
|---|---|---|
| 1 | ram@example.com | Ram |
| 2 | sita@example.com | Sita |

(2 rows)

**Example: A local time goes in with its offset (+05:45) and comes out in UTC**

```sql
CREATE TABLE live_prices (time TIMESTAMP, symbol SYMBOL, ltp DOUBLE) TIMESERIES(time);
INSERT INTO live_prices VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 513.0);
SELECT time, symbol, ltp FROM live_prices;
```

Result:

`CREATE TABLE live_prices (`

```text
table 'live_prices' created
```

`INSERT INTO live_prices VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 513.0)`

```text
1 row(s) inserted
```

`SELECT time, symbol, ltp FROM live_prices`

| time (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | CITY | 513 |

(1 row)

<a id="shell"></a>

## kareladb shell

Syntax:

```sql
kareladb shell [database]
```

A prompt where you type SQL. End each statement with `;`. A statement can use many lines. Commands that start with a dot (`.tables`, `.help`, `.exit`) need no `;`.

- **Notes:** without a database name, the shell opens the database `default` in the data folder. There you can also use `CREATE DATABASE` and `USE`.

**Command line: Type SQL in the shell**

```bash
kareladb shell shop
> CREATE TABLE posts (id LONG PRIMARY KEY AUTO, author STRING, body STRING);
> INSERT INTO posts (author, body) VALUES ('ram', 'CITY dividend looks good.');
> .tables
> SELECT id, author, body FROM posts;
> .exit
```

Output:

```text
KarelaDB 0.2.0-dev shell on shop
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> table 'posts' created
kareladb> 1 row(s) inserted
kareladb> name  | kind       | partition | columns | rows
------+------------+-----------+---------+-----
posts | relational | NONE      |       3 |    1
(1 row, 0.0 ms)
kareladb> id | author | body                     
---+--------+--------------------------
 1 | ram    | CITY dividend looks good.
(1 row, 0.1 ms)
kareladb>
```

<a id="sample-data"></a>

## Load the sample data

Syntax:

```sql
Get-Content file.sql -Raw | kareladb sql database -
```

The tutorial has a small made-up stock market dataset: securities, brokers, daily and minute candles, a trade log and live prices. It is just one example of what KarelaDB stores. The `-` means "read the SQL from the pipe". Run the two files once, in this order.

- **Notes:** the help examples with `fixture=sample` use this data. [Sample data](sample-data.md) shows every table.

```powershell
# from the KarelaDB source folder
$examples = "docs\tutorial\examples"
Get-Content "$examples\setup\schema.sql" -Raw | kareladb sql market -
Get-Content "$examples\setup\sample-data.sql" -Raw | kareladb sql market -
```

**Command line: The tables of the sample data** (sample data: sample)

```bash
kareladb sql market "SHOW TABLES"
```

Output:

```text
name         | kind       | partition | columns | rows
-------------+------------+-----------+---------+-----
brokers      | relational | NONE      |       2 |    5
live_data    | timeseries | DAY       |      12 |   12
ochl_day     | timeseries | YEAR      |       7 |   57
ochl_minutes | timeseries | MONTH     |       7 |  956
securities   | relational | NONE      |       3 |    5
trade_log    | timeseries | DAY       |       8 |   32
(6 rows, 0.0 ms)
```

**Example: The last 3 daily closes of CITY** (sample data: sample)

```sql
SELECT time, symbol, close FROM ochl_day WHERE symbol = 'CITY' ORDER BY time DESC LIMIT 3;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.9 |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 |
| 2026-09-08T00:00:00.000Z | CITY | 497.5 |

(3 rows)

<a id="console"></a>

## Open the web console (kareladb serve)

Syntax:

```sql
kareladb serve [database] [--port 9900]
```

Starts the server. Open <http://127.0.0.1:9900> in a browser. Type SQL, press **Ctrl+Enter**, and see a grid or a chart. Press **Ctrl+C** to stop the server.

- **Notes:** while the server runs, other `kareladb` commands cannot open the same database. Use the console or the HTTP API then. Without a database name, the server serves every database in the data folder. The same server answers PostgreSQL tools on port 8832 and serves these help pages at <http://127.0.0.1:9900/help/>. See [kareladb serve](cli-serve.md) and [web console](web-console.md).
- **In Docker** the server is already running: open <http://127.0.0.1:9900> and paste your `KARELADB_TOKEN` into the token box.

**Command line: Start the server on the sample data** (sample data: sample)

```bash
kareladb serve market
```

Output:

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      market
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
  logs      slow queries >= 1000 ms to market/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 2 ms: manifest 1 ms, 1 files read 0 ms (8 table files left for their first use), log check 1 ms, replay 0 ms (0 transactions), clean-up 0 ms

Press Ctrl+C to stop.
```

<a id="next"></a>

## Next steps

Syntax:

```sql
SQL basics  ->  tables  ->  writing data  ->  queries
```

Read the topics in this order:

1. [SQL basics](sql-basics.md): names, text, numbers, NULL and comments.
2. [Databases](databases.md) and [CREATE TABLE](create-table.md).
3. [INSERT](insert.md), [UPDATE and DELETE](update-delete.md).
4. [SELECT](select.md) and [SAMPLE BY](sample-by.md) for candles.

Or follow the [tutorial](../tutorial/02-first-database.md) chapter by chapter. [What's new](whats-new.md) lists what was added lately.

**Example: A taste of time-series SQL: hourly candles of CITY** (sample data: sample)

```sql
SELECT time, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
SAMPLE BY 1h;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-10T05:00:00.000Z | 504.6 | 507 | 503.8 | 506.4 | 36170 |
| 2026-09-10T06:00:00.000Z | 506.4 | 506.6 | 500.7 | 501.2 | 41280 |
| 2026-09-10T07:00:00.000Z | 501.2 | 504.1 | 500.7 | 502.6 | 46160 |
| 2026-09-10T08:00:00.000Z | 502.6 | 507 | 501.9 | 505 | 47560 |
| 2026-09-10T09:00:00.000Z | 505 | 506.1 | 504.3 | 504.9 | 11870 |

(5 rows)
