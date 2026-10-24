# Loading many rows

> Load thousands or millions of rows: multi-row INSERT, SQL files, CSV files (POST /imp, COPY), the line protocol and the C++ InsertRows API, with speed tips.

- Category: Writing data
- Keywords: bulk load, bulk insert, import, batch insert, load data, load file, SQL file, pipe, stdin, kareladb sql -, CSV, CSV import, export CSV, --format csv, migrate, migration, QuestDB export, csv-to-sql.ps1, line protocol, ILP, POST /write, POST /imp, COPY, COPY FROM STDIN, pgx CopyFrom, InsertRows, C++ API, InsertMode, InsertRequest, fast insert, speed, sync-commits, disk full, 507, trigger slows load, going back, back to QuestDB, back to PostgreSQL, export-since.mjs, roll back migration, export new rows, shadow period, dual-write, compare QuestDB, compare.mjs, \_shadow\_diffs, nightly compare
- See also: [INSERT](insert.md), [Performance tips](performance-tips.md), [Line protocol (POST /write)](line-protocol.md), [kareladb sql and kareladb shell](cli-sql-and-shell.md), [Run SQL over HTTP (/exec, /exp)](http-exec.md), [Partitions, SORT BY and DEDUP KEY](partitions-and-dedup.md)

A daily import can be tens of thousands of rows: trades, minute candles, sensor readings or log lines. There are several ways to load them. All of them check the same rules as `INSERT` (types, keys, `NOT NULL`, `REFERENCES`, `CHECK`).

| Way | Good for | Speed |
|---|---|---|
| [Multi-row INSERT](#multi-row-insert) | scripts and apps | good: one commit per statement |
| [SQL file with `kareladb sql <db> -`](#sql-files) | a file on the same PC, server stopped | good |
| [CSV file](#csv) with `POST /imp` | data from Excel, QuestDB or another database | fast: one request |
| [`COPY ... FROM STDIN`](#csv) on the PostgreSQL port | Go, Python or psql programs | fast |
| [HTTP `POST /exec`](#http) | while `kareladb serve` runs | good |
| [Line protocol `POST /write`](#line-protocol) | live feeds, many rows from programs | fastest over HTTP |
| [C++ `InsertRows`](#insert-rows) | a program that has KarelaDB inside | fastest |

The golden rule: **use `INSERT OR REPLACE` with a `DEDUP KEY` or `PRIMARY KEY`**. Then a file can be loaded again after an error, and you never get double rows.

**Example: The same batch loaded twice: still 3 rows**

Setup:

```sql
CREATE TABLE ochl_day (time TIMESTAMP ROUND 1d, symbol SYMBOL, open DOUBLE, high DOUBLE, low DOUBLE, close DOUBLE, volume DOUBLE)
  TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (symbol, time);
```

```sql
INSERT OR REPLACE INTO ochl_day VALUES
  ('2026-09-10', 'CITY', 504.6, 507.0, 500.7, 504.9, 183040),
  ('2026-09-10', 'COAST',  380.1, 382.0, 373.2, 376.1, 186200),
  ('2026-09-10', 'VOLT', 185.6, 192.1, 184.2, 191.2, 41470);
INSERT OR REPLACE INTO ochl_day VALUES
  ('2026-09-10', 'CITY', 504.6, 507.0, 500.7, 504.9, 183040),
  ('2026-09-10', 'COAST',  380.1, 382.0, 373.2, 376.1, 186200),
  ('2026-09-10', 'VOLT', 185.6, 192.1, 184.2, 191.2, 41470);
SELECT count(*) AS rows FROM ochl_day;
```

Result:

`INSERT OR REPLACE INTO ochl_day VALUES ('2026-09-10', 'CITY', 504.6, 507.0, 500.7, 504.9, 183040), (`

```text
3 row(s) inserted
```

`INSERT OR REPLACE INTO ochl_day VALUES ('2026-09-10', 'CITY', 504.6, 507.0, 500.7, 504.9, 183040), (`

```text
0 row(s) inserted, 3 replaced
```

`SELECT count(*) AS rows FROM ochl_day`

| rows (LONG) |
|---|
| 3 |

(1 row)

<a id="multi-row-insert"></a>

## Multi-row INSERT

Syntax:

```sql
INSERT [OR REPLACE | OR IGNORE] INTO table (column, ...) VALUES
  (...), (...), (...), ...;
```

Put many rows in one statement. Every statement is **one commit** (one write to the log and one wait for the disk), so 5,000 rows in one `INSERT` are far faster than 5,000 `INSERT`s.

- Use about **1,000 to 5,000 rows** per statement. Much bigger statements only use more memory.
- One statement is all or nothing. When a row is bad, the message says `row N:` and nothing of that statement is saved; statements before it stay saved.
- **Notes:** write a column list: then the load still works after `ALTER TABLE ... ADD COLUMN`. See [performance tips](performance-tips.md#bulk-insert) for measured speeds.

**Example: Trades for the trade log in one statement**

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
INSERT INTO brokers VALUES (1, 'Keystone Securities'), (34, 'Vision Securities'), (45, 'Imperial Securities'), (58, 'Northgate Securities');
CREATE TABLE trade_log (date TIMESTAMP ROUND 1d, transaction_id LONG, symbol SYMBOL, buyer INT REFERENCES brokers(id), seller INT REFERENCES brokers(id), quantity LONG, rate DOUBLE, amount DOUBLE AS (quantity * rate))
  TIMESERIES(date) PARTITION BY DAY DEDUP KEY (date, transaction_id);
```

```sql
INSERT OR REPLACE INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate) VALUES
  ('2026-09-10', 100009, 'COAST',  34, 45, 50,  400.0),
  ('2026-09-10', 100010, 'CITY', 1,  45, 50,  517.0),
  ('2026-09-10', 100011, 'VOLT', 1,  58, 50,  184.0),
  ('2026-09-10', 100012, 'VOLT', 58, 45, 200, 184.0);
SELECT count(*) AS trades, sum(amount) AS turnover FROM trade_log;
```

Result:

`INSERT OR REPLACE INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate) VALUE`

```text
4 row(s) inserted
```

`SELECT count(*) AS trades, sum(amount) AS turnover FROM trade_log`

| trades (LONG) | turnover (DOUBLE) |
|---|---|
| 4 | 91850 |

(1 row)

**Example: One bad row in a batch: the message names the row** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
INSERT INTO brokers VALUES (1, 'Keystone Securities'), (45, 'Imperial Securities');
CREATE TABLE trades (id LONG PRIMARY KEY, buyer INT REFERENCES brokers(id), quantity LONG);
```

```sql
INSERT INTO trades VALUES (1, 1, 100), (2, 45, 50), (3, 77, 10), (4, 1, 20);
```

Result:

Error: `row 3: column 'buyer' = '77' has no matching row in brokers(id)`

<a id="sql-files"></a>

## SQL files: kareladb sql <db> -

Syntax:

```sql
Get-Content load.sql -Raw -Encoding UTF8 | kareladb sql database -      (PowerShell)
kareladb sql database - < load.sql                                     (cmd.exe, bash)
```

Write the statements into a `.sql` file, then send the file into `kareladb sql`. The `-` means "read the SQL from the pipe". KarelaDB runs the statements one by one and stops at the first error.

- `kareladb sql` opens the database files directly, so `kareladb serve` must **not** run on the same database. While the server runs, send the file over [HTTP](#http).
- Save the file as UTF-8. In Windows PowerShell 5.1, run `$OutputEncoding = New-Object System.Text.UTF8Encoding $false` first, or text in other languages becomes `?`.
- Check the exit code: `0` all statements ran, `1` an error (the output shows which statement).
- **Notes:** a big file is read into memory first. For millions of rows, split it: one file per day or month. More in [kareladb sql](cli-sql-and-shell.md#stdin).

**Command line: A small SQL file piped into kareladb sql** (sample data: sample)

```bash
kareladb sql market -
> INSERT OR REPLACE INTO ochl_day VALUES
>   ('2026-09-13', 'CITY', 505.0, 509.0, 503.1, 508.2, 91000),
>   ('2026-09-13', 'COAST',  376.0, 379.9, 374.0, 378.5, 120500);
> SELECT time, symbol, close FROM ochl_day WHERE time IN '2026-09-13';
```

Output:

```text
2 row(s) inserted

time                     | symbol | close
-------------------------+--------+------
2026-09-13T00:00:00.000Z | CITY   | 508.2
2026-09-13T00:00:00.000Z | COAST  | 378.5
(2 rows, 0.2 ms)
```

```powershell
# A real file (not run here). Load the tables in order: parents (brokers) before children (trade_log).
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
Get-Content brokers.sql -Raw -Encoding UTF8 | kareladb sql market -
Get-Content trade_log_2026-09-10.sql -Raw -Encoding UTF8 | kareladb sql market -
"exit code: $LASTEXITCODE"
```

<a id="csv"></a>

## CSV files

Syntax:

```sql
POST /imp?name=<table>&db=<database>        body: the CSV file       (kareladb serve running)
COPY table FROM STDIN (FORMAT csv)                                    (the PostgreSQL port)
CSV file  ->  INSERT OR REPLACE statements  ->  kareladb sql database -    (server stopped)
kareladb sql database "SELECT ..." --format csv > file.csv                 (export)
```

There are three ways to load a CSV file:

| Way | How |
|---|---|
| [POST /imp](http-import.md) | send the file to the running server. It is QuestDB's import route: it can make the table from the file, and it upserts like the line protocol. One request is one transaction |
| `COPY table FROM STDIN` | on the [PostgreSQL port](postgres-protocol.md): psql `\copy`, pgx `CopyFrom`, psycopg `copy`. Text, CSV and binary format. One `COPY` is one transaction |
| SQL statements | convert the CSV into `INSERT OR REPLACE` statements and pipe them into `kareladb sql`. The tutorial has a script: `docs/tutorial/examples/10-migrating-from-questdb/csv-to-sql.ps1` ([chapter 10](../tutorial/10-migrating-from-questdb.md)) |

Rules for converting a CSV row into SQL values:

| CSV value | SQL value |
|---|---|
| looks like a number: `512.4`, `182390` | the number, without quotes |
| empty | `NULL` |
| anything else: symbols, names, times | text in single quotes, with every `'` written twice: `'City''s'` |
| a local time without a zone | add its offset (for example `+05:45`) before loading |

- Write one `INSERT OR REPLACE` per 1,000 to 5,000 CSV rows.
- To **export** a table as CSV, use `--format csv`; the first line is the header.
- **Notes:** QuestDB times with 6 digits after the second (`.000000Z`) are fine: KarelaDB keeps milliseconds.

```powershell
# Convert (not run here): one INSERT OR REPLACE per 5000 rows, then load.
.\csv-to-sql.ps1 -Csv trade_log.csv -Table trade_log -Out trade_log.sql -BatchSize 5000
Get-Content trade_log.sql -Raw -Encoding UTF8 | kareladb sql market -
```

**Command line: Export daily candles as CSV** (sample data: sample)

```bash
kareladb sql market "SELECT time, symbol, open, high, low, close, volume FROM ochl_day WHERE time IN '2026-09-10' ORDER BY symbol" --format csv
```

Output:

```text
time,symbol,open,high,low,close,volume
2026-09-10T00:00:00.000Z,CITY,504.6,507,500.7,504.9,183040
2026-09-10T00:00:00.000Z,COAST,380.1,382,373.2,376.1,186200
2026-09-10T00:00:00.000Z,VOLT,185.6,192.1,184.2,191.2,41470
```

<a id="http"></a>

## Over HTTP: POST /exec

Syntax:

```sql
POST /exec?db=<database>
body: the SQL text (many statements allowed)
```

While `kareladb serve` runs, send the same SQL text in the body of `POST /exec`. It works like `kareladb sql`: the statements run one by one, and the answer says which statement failed.

- The body may be up to **64 MB**; split bigger files.
- **Notes:** for many small writes from many clients, start the server with `--sync-commits batch` ([performance tips](performance-tips.md#sync-commits)). Details in [POST /exec](http-exec.md).

**HTTP: Load two candles over HTTP**

```http
POST /exec?db=demo

CREATE TABLE ochl_day (time TIMESTAMP ROUND 1d, symbol SYMBOL, close DOUBLE, volume DOUBLE) TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (symbol, time);
INSERT OR REPLACE INTO ochl_day VALUES ('2026-09-10', 'CITY', 504.9, 183040), ('2026-09-10', 'COAST', 376.1, 186200);
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "CREATE TABLE ochl_day (time TIMESTAMP ROUND 1d, symbol SYMBOL, close DOUBLE, volume DOUBLE) TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (symbol, time);\nINSERT OR REPLACE INTO ochl_day VALUES ('2026-09-10', 'CITY', 504.9, 183040), ('2026-09-10', 'COAST', 376.1, 186200);",
  "results": [
    {
      "statement": "CREATE TABLE ochl_day (\n  time TIMESTAMP ROUND 1d,\n  symbol SYMBOL,\n  close DOUBLE,\n  volume DOUBLE\n) TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (symbol, time)",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "table 'ochl_day' created",
      "timings": {"parse_us": 29, "execute_us": 11873}
    },
    {
      "statement": "INSERT OR REPLACE INTO ochl_day VALUES ('2026-09-10', 'CITY', 504.9, 183040), ('2026-09-10', 'COAST', 376.1, 186200)",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 2,
      "message": "2 row(s) inserted",
      "timings": {"parse_us": 29, "execute_us": 1888}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 58, "execute_us": 13761}
}
```

<a id="line-protocol"></a>

## Line protocol: POST /write

Syntax:

```sql
POST /write?db=<database>&precision=ms
table,tag=value field=value,field=value timestamp
```

The InfluxDB line protocol, as QuestDB accepts it: one row per line. It is the fastest way to send many rows to a running server. Rows are always **upserted** (like `INSERT OR REPLACE`), and the whole request is one transaction.

- A table that is not there is made from the lines, as QuestDB does (role `ddl`; [new tables](line-protocol.md#new-tables)). Tags fill `SYMBOL` and `STRING` columns; the timestamp fills the time column.
- **Notes:** everything about the format, the precision and the errors is in [line protocol](line-protocol.md).

**HTTP: Two minute candles with the line protocol, then a check**

Setup:

```text
CREATE TABLE ochl_minutes (time TIMESTAMP ROUND 1m, symbol SYMBOL, open DOUBLE, high DOUBLE, low DOUBLE, close DOUBLE, volume DOUBLE) TIMESERIES(time) PARTITION BY MONTH DEDUP KEY (symbol, time);
```

```http
POST /write?db=demo&precision=ms

ochl_minutes,symbol=CITY open=504.6,high=504.9,low=504.5,close=504.8,volume=1200 1789017600000
ochl_minutes,symbol=COAST open=380.1,high=380.4,low=379.8,close=380.2,volume=900 1789017600000
###
GET /exec?db=demo&query=SELECT%20time,%20symbol,%20close,%20volume%20FROM%20ochl_minutes
```

Response:

`POST /write?db=demo&precision=ms`

HTTP 204

`GET /exec?db=demo&query=SELECT%20time,%20symbol,%20close,%20volume%20FROM%20ochl_minutes`

HTTP 200 (application/json)

```text
{
  "query": "SELECT time, symbol, close, volume FROM ochl_minutes",
  "results": [
    {
      "statement": "SELECT time, symbol, close, volume FROM ochl_minutes",
      "columns": [
        {"name": "time", "type": "TIMESTAMP"},
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "close", "type": "DOUBLE"},
        {"name": "volume", "type": "DOUBLE"}
      ],
      "dataset": [
        ["2026-09-10T05:20:00.000Z", "CITY", 504.8, 1200],
        ["2026-09-10T05:20:00.000Z", "COAST", 380.2, 900]
      ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 15, "execute_us": 79}
    }
  ],
  "columns": [
    {"name": "time", "type": "TIMESTAMP"},
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "close", "type": "DOUBLE"},
    {"name": "volume", "type": "DOUBLE"}
  ],
  "dataset": [
    ["2026-09-10T05:20:00.000Z", "CITY", 504.8, 1200],
    ["2026-09-10T05:20:00.000Z", "COAST", 380.2, 900]
  ],
  "count": 2,
  "timings": {"parse_us": 15, "execute_us": 79}
}
```

<a id="insert-rows"></a>

## C++ API: InsertRows

Syntax:

```sql
Status Database::InsertRows(const std::string& table,
                            const std::vector<std::string>& columns,
                            const std::vector<Value>& values,
                            InsertMode mode = InsertMode::kError,
                            InsertSummary* summary = nullptr);
Status Database::InsertRows(const std::vector<InsertRequest>& requests, InsertSummary* summary = nullptr);
```

A program that has KarelaDB inside (see `src/db/database.h`) can insert rows **without SQL**: no text to build or parse.

| Argument | Meaning |
|---|---|
| `table` | the table name |
| `columns` | the column names; empty = every stored column in table order |
| `values` | row after row: `columns.size()` values per row (`Value::Int`, `Value::Double`, `Value::String`, `Value::Bool`, `Value::Null`) |
| `mode` | `kError` (like `INSERT`), `kReplace` (like `INSERT OR REPLACE`), `kIgnore` (like `INSERT OR IGNORE`), `kUpsert` (same result as `kReplace`, faster, does not count replaced rows apart) |
| `summary` | gets `inserted`, `replaced`, `skipped`, `upserted`, and the request and row of an error |

- Values are converted like `INSERT` values: an integer for a `TIMESTAMP` column is Unix milliseconds, text is parsed (`'2026-09-10T11:00:00+05:45'`), a `DECIMAL` can be given as text.
- All rules apply: `NOT NULL`, `DEFAULT`, `AUTO`, `REFERENCES`, keys, `CHECK`, triggers.
- The version with many `InsertRequest`s writes **all requests as one transaction**: every row, or none. Rows of earlier requests count for keys and `REFERENCES` of later requests.
- **Returns:** `Status`; `ok()` when all rows were written, else `message()` starts with `row N:` for an error about one row.

```cpp
#include "db/database.h"

std::unique_ptr<kdb::Database> db;
kdb::Status s = kdb::Database::Open("D:/kdb-data/market", kdb::DatabaseOptions(), &db);

// Two minute candles: time, symbol, close, volume.
std::vector<kdb::Value> values = {
    kdb::Value::String("2026-09-10T11:05:00+05:45"), kdb::Value::String("CITY"), kdb::Value::Double(504.8), kdb::Value::Int(1200),
    kdb::Value::Int(1789017660000),                  kdb::Value::String("COAST"),  kdb::Value::Double(380.2), kdb::Value::Int(900),
};
kdb::InsertSummary summary;
s = db->InsertRows("ochl_minutes", {"time", "symbol", "close", "volume"}, values,
                   kdb::InsertMode::kReplace, &summary);
if (!s.ok()) std::printf("error: %s\n", s.message().c_str());
else std::printf("%llu inserted, %llu replaced\n", (unsigned long long)summary.inserted, (unsigned long long)summary.replaced);
```

<a id="speed"></a>

## Speed tips

Syntax:

```sql
many rows per statement  +  INSERT OR REPLACE  +  load in time order  +  keys before, indexes after
```

What makes loading fast:

| Tip | Why |
|---|---|
| 1,000 to 5,000 rows per `INSERT` | one commit per statement instead of one per row |
| one `kareladb sql <db> -` run or one HTTP request for many statements | no new process or connection per statement |
| load in **time order**, one day or month at a time | rows go to the end of few partitions |
| a good `PARTITION BY` (see [partitions](partitions-and-dedup.md)) | small partitions for big daily data, big ones for small data |
| create indexes **after** a big first import | every index is updated for every row |
| `REFERENCES` and `UNIQUE` only where needed | they look up every new row |
| `--sync-commits batch` for live feeds | commits are put on disk together every 10 ms ([kareladb serve](cli-serve.md)) |
| the line protocol or `InsertRows` for programs | no SQL text to build and parse |

- **Notes:** do not wrap a load of millions of rows in `BEGIN ... COMMIT`: a transaction keeps the old version of every changed row in memory (at most 10 million). Plain statements are saved one by one. Load the parent tables (brokers) before the child tables (trade_log).
- **Notes:** an immediate `INSERT` [trigger](triggers.md) on a table makes the loads into **that** table go row by row, several times slower. A trigger on another table does not slow it. For a table loaded in bulk, make the trigger [DEFERRED](triggers.md#deferred): it then runs after the load, once per request.
- **Notes:** a line protocol or `/imp` load is fastest into a day with no rows yet, or into a table whose `DEDUP KEY` holds every `SORT BY` column. A table with no `DEDUP KEY` loads just as fast. Details: [how loads find duplicates](partitions-and-dedup.md#load-dedup).
- **Notes:** loads into different tables run at the same time; loads into one table take turns. A load that waits more than 5 s for a table gets `table 'x' is busy: ...` (HTTP 503) and writes nothing: send it again.
- **Notes:** KarelaDB keeps 64 MB of the disk free. Below that a write is refused with HTTP 507 (`disk full`; SQLSTATE `53100` on the PostgreSQL port) and nothing is written; free some space ([PURGE TRASH](databases.md#purge-trash)) and send it again. If the disk fills up in the middle of writing the log anyway, the write gets 507 too and reads go on; writes work again once space is freed. Rows already confirmed are safe in both cases.

**Example: Check a load: rows, first and last time, total volume**

Setup:

```sql
CREATE TABLE ochl_minutes (time TIMESTAMP ROUND 1m, symbol SYMBOL, close DOUBLE, volume DOUBLE) TIMESERIES(time) PARTITION BY MONTH DEDUP KEY (symbol, time);
INSERT OR REPLACE INTO ochl_minutes VALUES
  ('2026-09-10T11:00:00+05:45', 'CITY', 504.4, 960), ('2026-09-10T11:01:00+05:45', 'CITY', 504.6, 700),
  ('2026-09-10T11:02:00+05:45', 'CITY', 504.2, 150), ('2026-09-10T11:00:00+05:45', 'COAST', 380.2, 900);
```

```sql
SELECT symbol, count(*) AS rows, min(time) AS first, max(time) AS last, sum(volume) AS volume
FROM ochl_minutes WHERE time IN '2026-09-10'
GROUP BY symbol ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | rows (LONG) | first (TIMESTAMP) | last (TIMESTAMP) | volume (DOUBLE) |
|---|---|---|---|---|
| CITY | 3 | 2026-09-10T05:15:00.000Z | 2026-09-10T05:17:00.000Z | 1810 |
| COAST | 1 | 2026-09-10T05:15:00.000Z | 2026-09-10T05:15:00.000Z | 900 |

(2 rows)

<a id="go-back"></a>

## Going back to QuestDB or PostgreSQL

Syntax:

```sql
node tools/go-back/export-since.mjs --url <kareladb url> --token <token> --db <database> --since <switch time>
     [--tables a,b] [--out <folder>] [--questdb <url>] [--with-relational]
```

Your app moved from QuestDB or PostgreSQL to KarelaDB, and you want to go back. The old database still has everything up to the switch. This script exports only what KarelaDB got **after** it, so the old database can catch up. It needs Node 18 or newer and nothing else. It is in the KarelaDB source, in `tools/go-back/`.

| Option | Meaning | Default |
|---|---|---|
| `--url` | the KarelaDB server | `KARELADB_URL` |
| `--token` | the token or an [API key](api-tokens.md) with `read` | `KARELADB_TOKEN` |
| `--db` | the database | required |
| `--since` | the switch time. Rows with a time **after** it are exported. `2026-09-20T00:00:00Z`, or with an offset: `2026-09-20T05:45:00+05:45` | required |
| `--tables` | only these tables, comma separated | every time-series table |
| `--out` | the folder for the files | `go-back-<db>` |
| `--questdb` | the QuestDB address written into `load-questdb.sh` | `http://localhost:9000` |
| `--with-relational` | also export tables without a time column, whole | skipped |

| File | What it is |
|---|---|
| `<table>.csv` | the new rows of one table, ordered by time, with a header line ([GET /exp](http-exec.md#get-exp) CSV: times in UTC) |
| `load-postgres.sql` | one psql `\copy` per table, in one transaction: `psql "<connection>" -v ON_ERROR_STOP=1 -f load-postgres.sql` |
| `load-questdb.sh` | one `curl ... /imp` per table: `sh load-questdb.sh` |

- **How it finds the new rows:** every table with a designated time column (`TIMESERIES(time)`) gives the rows with a time after `--since`. A table without one cannot say which rows are new: it is skipped and named, or exported whole with `--with-relational`.
- **Big tables:** the script asks `/exp` for at most 1,000,000 rows per request (its default), so it splits the time range until each part fits, and writes all parts into one file. A table without a time column is read in pages of 1,000,000 rows, ordered by its primary key (or by every column when it has none). If its row count changes during the export, the script stops with an error instead of writing a file that does not match the table.
- **Run it from the folder** it wrote: the load scripts name the CSV files without a path.
- **Notes:**
  - Rows **changed** or **deleted** in KarelaDB after the switch are not in the export: only rows whose time is after the switch are. If the app updates old rows, export those tables whole with `--tables` and `--with-relational`, or compare them.
  - Computed columns (`amount DOUBLE AS (quantity * rate)`) are exported as values. If the PostgreSQL table makes that column itself (`GENERATED ALWAYS AS ... STORED`), remove it from the `\copy` column list and from the CSV.
  - PostgreSQL: the tables must exist. A row whose key is already there makes the whole load fail; load into a copy of the table and `INSERT ... ON CONFLICT DO NOTHING` from it instead.
  - QuestDB: `/imp` adds the rows, and makes a missing table with the same time column and partitioning. A QuestDB table with `DEDUP UPSERT KEYS` can take the same file twice without doubles.
  - Stop the writes to KarelaDB first (or [set it read-only](protection.md#read-only)), so no row arrives after the export.

```bash
node tools/go-back/export-since.mjs --url http://127.0.0.1:9900 --token "$KARELADB_TOKEN" --db market --since 2026-09-09T12:00:00Z
cd go-back-market
sh load-questdb.sh                                               # back to QuestDB
psql "postgres://app@localhost/app" -v ON_ERROR_STOP=1 -f load-postgres.sql   # or back to PostgreSQL
```

On the [sample data](sample-data.md) it prints:

```text
live_data: 12 row(s) after 2026-09-09T12:00:00Z -> go-back-market/live_data.csv
ochl_day: 3 row(s) after 2026-09-09T12:00:00Z -> go-back-market/ochl_day.csv
ochl_minutes: 476 row(s) after 2026-09-09T12:00:00Z -> go-back-market/ochl_minutes.csv
trade_log: 24 row(s) after 2026-09-09T12:00:00Z -> go-back-market/trade_log.csv
4 table(s), 515 row(s) in go-back-market; load with load-postgres.sql or load-questdb.sh
skipped (no time column, so no "since"; add --with-relational to export them whole): brokers, securities
```

and `load-questdb.sh` holds lines like:

```bash
curl -sS -F data=@ochl_day.csv "http://localhost:9000/imp?name=ochl_day&overwrite=false&fmt=json&timestamp=time&partitionBy=YEAR"
```

<a id="shadow-compare"></a>

## Shadow period: compare QuestDB and KarelaDB

Syntax:

```sql
node tools/shadow/compare.mjs --db <database> [--kdb <kareladb url>] [--questdb <questdb url>]
     [--since <time>] [--until <time>] [--tables a,b] [--sum a,b] [--symbol <column>]
     [--nightly [--at HH:MM] [--days N]] [--listen <port>]
```

Before the switch, run the app against both databases for a few weeks: it writes every row to QuestDB **and** to KarelaDB (dual-write). This script checks that the two hold the same data. It needs Node 18 or newer and nothing else. It is in the KarelaDB source, in `tools/shadow/`.

For every table and every UTC day it compares, on both sides:

| Check | Meaning |
|---|---|
| day | the row count, the first and last time, and the sums of the price and volume columns |
| symbol | the row count and sums per symbol, every day (two symbols can be off in opposite ways and still give the same day total) |
| minute | only where a day or a symbol differs: the row count and sums per minute, so you see **which minute** lost or changed a row |

| Option | Meaning | Default |
|---|---|---|
| `--kdb` | the KarelaDB server. The token is read from the `KARELADB_TOKEN` environment variable only (never a flag, so it is not seen in a process list). It needs `read`, and `write` to log the differences | `KARELADB_URL`, then `http://127.0.0.1:9900` |
| `--db` | the KarelaDB database | required |
| `--questdb` | QuestDB's HTTP address (its `/exec`) | `http://localhost:9000` |
| `--since`, `--until` | the time compared: from `--since` up to, not including, `--until`. A date alone is 00:00 UTC; `--until now` takes in today | yesterday (UTC) |
| `--tables` | only these tables | every KarelaDB time-series table |
| `--sum` | the columns to sum | `price`, `open`, `high`, `low`, `close`, `volume`, `qty`, `quantity`, `amount`, `turnover` (those the table has) |
| `--symbol` | the column to split by; `none` for no split | the table's first `SYMBOL` column |
| `--report-dir` | the folder for the report | `reports` |
| `--diff-table` | the KarelaDB table for the differences; `--no-log` writes none | `_shadow_diffs` |
| `--max-minutes` | at most this many differing minutes per symbol and day | `100` |
| `--tolerance` | how far two sums may be apart, relative: the two servers add numbers in another order | `1e-9` |

- **What you get:** one line per table, a dated report `reports/<date>_<time>_shadow-compare_<db>.md`, and one row per difference in `_shadow_diffs` (`run`, `tbl`, `day`, `level` = `day`/`symbol`/`minute`/`table`, `symbol`, `minute`, `what`, `questdb`, `kareladb`). The exit code is `0` when all is the same, `3` when something differs, `1` on an error.
- **Times:** QuestDB keeps microseconds and KarelaDB milliseconds, so times are compared to the millisecond.
- **A table missing on one side** is one `table` / `error` row; the other tables are still compared.
- **Rows still arriving:** compare whole days that are over (the default), or the newest rows may be on one side and not yet on the other.

```bash
export KARELADB_TOKEN=...                      # the token, in the environment
node tools/shadow/compare.mjs --kdb http://127.0.0.1:9900 --db market --questdb http://localhost:9000 --since 2026-09-20
```

```text
ticks: 2 day(s), 8 row(s) in QuestDB, 7 in KarelaDB, 5 difference(s)
5 difference(s); report reports/2026-10-02_0200_shadow-compare_market.md; 5 row(s) in _shadow_diffs
```

```sql
-- Which minutes differ, newest run first
SELECT run, tbl, day, symbol, minute, what, questdb, kareladb
FROM _shadow_diffs WHERE level = 'minute' ORDER BY run DESC, tbl, minute;
```

<a id="shadow-nightly"></a>

### Every night

| Way | How |
|---|---|
| keep it running | `--nightly` compares once now, then every day at `--at` (UTC, default `02:00`) the last `--days` full days (default 1) |
| cron (Linux) | `15 2 * * * cd /opt/kdb-src && KARELADB_TOKEN=... node tools/shadow/compare.mjs --db market >> shadow.log 2>&1` |
| Windows Task Scheduler | a daily task that runs `node tools\shadow\compare.mjs --db market`, with `KARELADB_TOKEN` set for that user |
| a KarelaDB [timer](timers.md) | start the script with `--listen 9890`. Then `GET /run` starts a compare of yesterday (or `?since=...&until=...`) and answers at once; `GET /last` shows the last result. A timer calls it with [http_get](http-functions.md), once that host is allowed |

```text
POST /api/timers
Content-Type: application/json

{"name": "shadow_compare", "schedule": "daily 02:15",
 "sql": "SELECT http_get('http://host.docker.internal:9890/run')"}
```

Start the script first with `--listen 9890 --listen-host 0.0.0.0` (KarelaDB in Docker reaches the PC as `host.docker.internal`; allow that host in `http_functions`). `--listen` has no login of its own: keep it on `127.0.0.1` (the default) unless KarelaDB runs in Docker, and then only on a private network.
