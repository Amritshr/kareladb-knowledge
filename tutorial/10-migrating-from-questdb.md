# 10. Moving from QuestDB

- Category: Tutorial

## What you will learn

- The tables of the 006 app (NChartPro) as KarelaDB tables.
- What is different between QuestDB SQL and KarelaDB SQL.
- How to move the data (CSV export, then `/imp` or INSERT batches).

The examples start with an **empty** database `market`. The files are in `examples/10-migrating-from-questdb/`.

## First: what works today

| 006 uses | QuestDB | KarelaDB |
|---|---|---|
| Reads with Go `pgx` (Postgres protocol) | port 8812 | **yes**, port 8832 (chapter 14). Change the port in the connection string. |
| Bulk writes with HTTP `/imp` (CSV upload) | port 9000 | **yes**, the same parameters (chapter 8) |
| SAT3 writes with ILP (InfluxDB line protocol) | port 9009 (TCP) or HTTP `/write` | **yes, over HTTP**: `POST /write` (also `/api/v2/write`) on port 9900. There is no TCP port for ILP. The tables must exist first. |
| `/exec` JSON (`columns`, `dataset`, `count`) | yes | **yes**, same top-level fields (plus `results`) |
| `/exp` CSV export | yes | **yes**, for reading statements |
| Web console | yes | yes, with charts, dashboards and health (chapters 6 and 20) |

So the 006 Go code can keep `pgx`: point it at port 8832. The SQL itself mostly stays the same. `ALTER DATABASE name SET dialect = 'questdb'` makes KarelaDB read a few things the QuestDB way (chapter 23).

## The 006 tables in KarelaDB

The KarelaDB tables have the **same names and columns** as in QuestDB. Names do not care about case, with or without double quotes.

```sql
-- The tables of the 006 app, in KarelaDB. Names and columns are the same as in QuestDB.

CREATE TABLE IF NOT EXISTS "Ochl_Day" (
  time   TIMESTAMP,
  symbol SYMBOL,
  open   DOUBLE,
  high   DOUBLE,
  low    DOUBLE,
  close  DOUBLE,
  volume DOUBLE
) TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (time, symbol);

CREATE TABLE IF NOT EXISTS "Ochl_Day_Unadj" (
  time TIMESTAMP, symbol SYMBOL, open DOUBLE, high DOUBLE, low DOUBLE, close DOUBLE, volume DOUBLE
) TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (time, symbol);

CREATE TABLE IF NOT EXISTS "Ochl_Minutes" (
  time TIMESTAMP, symbol SYMBOL, open DOUBLE, high DOUBLE, low DOUBLE, close DOUBLE, volume DOUBLE
) TIMESERIES(time) PARTITION BY MONTH DEDUP KEY (time, symbol);

CREATE TABLE IF NOT EXISTS "Ochl_Minutes_Adj" (
  time TIMESTAMP, symbol SYMBOL, open DOUBLE, high DOUBLE, low DOUBLE, close DOUBLE, volume DOUBLE
) TIMESERIES(time) PARTITION BY MONTH DEDUP KEY (time, symbol);

CREATE TABLE IF NOT EXISTS "TradeLog" (
  date           TIMESTAMP,
  transaction_id LONG,
  symbol         SYMBOL,
  buyer          INT,
  seller         INT,
  quantity       LONG,
  rate           DOUBLE,
  amount         DOUBLE
) TIMESERIES(date) PARTITION BY DAY DEDUP KEY (date, transaction_id);

CREATE TABLE IF NOT EXISTS "LiveData" (
  symbol           SYMBOL,
  ltp              DOUBLE,
  ltv              LONG,
  point_change     DOUBLE,
  pct_change       DOUBLE,
  open             DOUBLE,
  high             DOUBLE,
  low              DOUBLE,
  avg_traded_price DOUBLE,
  prev_close       DOUBLE,
  volume           LONG,
  timestamp        TIMESTAMP
) TIMESERIES(timestamp) PARTITION BY DAY DEDUP KEY (timestamp, symbol);

SHOW TABLES;
```

```text
table 'Ochl_Day' created

table 'Ochl_Day_Unadj' created

table 'Ochl_Minutes' created

table 'Ochl_Minutes_Adj' created

table 'TradeLog' created

table 'LiveData' created

name             | kind       | partition | columns | rows
-----------------+------------+-----------+---------+-----
TradeLog         | timeseries | DAY       |       8 |    0
LiveData         | timeseries | DAY       |      12 |    0
Ochl_Day         | timeseries | YEAR      |       7 |    0
Ochl_Day_Unadj   | timeseries | YEAR      |       7 |    0
Ochl_Minutes     | timeseries | MONTH     |       7 |    0
Ochl_Minutes_Adj | timeseries | MONTH     |       7 |    0
(6 rows, 0.0 ms)
```

How the QuestDB DDL maps to KarelaDB:

| QuestDB | KarelaDB |
|---|---|
| `TIMESTAMP(time)` after the column list | `TIMESERIES(time)` |
| `PARTITION BY DAY/MONTH/YEAR` | same |
| `WAL` | remove it (KarelaDB always has a log) |
| `symbol SYMBOL INDEX` | `symbol SYMBOL` is enough: rows are sorted by symbol inside each partition. `SYMBOL INDEX` is accepted too and makes an index (`q_s_idx`). |
| `DEDUP UPSERT KEYS(time, symbol)` | `DEDUP KEY (time, symbol)`, and write with `INSERT OR REPLACE` (or run `ALTER DATABASE name SET dialect = 'questdb'` once: then a plain `INSERT` replaces too, and `CAST(time AS LONG)` gives microseconds; chapter 23). The QuestDB words are accepted as well. |
| `ALTER TABLE ... DEDUP ENABLE UPSERT KEYS(...)` / `DEDUP DISABLE` | same. `DEDUP ENABLE` on a table with rows folds rows with the same key into one (the newest is kept). |
| `CREATE TABLE ... AS (SELECT ...)` | same: `table 'x' created with 57 row(s)` |

The QuestDB `CREATE TABLE` text itself (`TIMESTAMP(time) PARTITION BY DAY WAL DEDUP UPSERT KEYS(...)`) is accepted as it is. The KarelaDB form above is easier to read.

Design notes for these tables:

- **DEDUP stays on.** In 006, dedup on `Ochl_*` was switched off during big backfills because QuestDB's merge was slow. In KarelaDB, the DEDUP KEY check is part of every insert and is fast, so you can leave it on. Test the speed of your backfill with a real file first. (`POST /write` and `POST /imp` also take `dedup=skip` for rows you know are new.)
- **Minute symbols** in `Ochl_Minutes` use the `-1` suffix (`CITY-1`) in 006. KarelaDB does not care; keep it the same so the Go code does not change. `replace(symbol, '-1', '')` removes it in a query.
- **ROUND is optional.** `time TIMESTAMP ROUND 1d` on `Ochl_Day` and `date TIMESTAMP ROUND 1d` on `TradeLog` would force times to 00:00 UTC. That would make a trade with a wrong sub-day time a duplicate of the right row, instead of a second row. But it would also merge an intraday junk row into the real day row (`INSERT OR REPLACE` keeps the last one). Decide after you clean the data.
- **amount** in `TradeLog` is a stored column here, because the imports send it. It could be a computed column `amount DOUBLE AS (quantity * rate)` (chapter 3), if the source value is always `quantity * rate`.
- **REFERENCES** to a brokers table would check every trade, but it slows down big imports. Leave it out for the migration.
- **Timestamps:** QuestDB stores microseconds; KarelaDB stores milliseconds. Daily market data like this has no sub-millisecond times, so nothing is lost. Digits after the milliseconds are dropped when you insert.

## Query differences

Most 006 queries run unchanged. These are the differences:

| Task | QuestDB | KarelaDB |
|---|---|---|
| 1-hour candles on the Nepal clock | `SAMPLE BY 1h ALIGN TO CALENDAR WITH OFFSET '00:15'` | same, or `SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu'` |
| Weekly candles starting Sunday | not possible in SQL (006 folds days in Go: `rollupWeeklySunday`) | `SAMPLE BY 1w WEEK START SUNDAY` |
| Monthly candles | `SAMPLE BY 1M` | same |
| Newest row per symbol | `LATEST ON timestamp PARTITION BY symbol` | same |
| Delete some rows | not possible (006 rebuilds tables with `CREATE TABLE AS`) | `DELETE FROM t WHERE ...` |
| Change some rows | `UPDATE` (slow on WAL tables) | `UPDATE t SET ... WHERE ...` |
| Drop a partition | `ALTER TABLE t DROP PARTITION LIST '2026-09'` | `ALTER TABLE t DROP PARTITION '2026-09'` (no `LIST`) |
| Count rows | `count()` or `count(*)` | same |
| Time interval | `time IN '2026-09-10'` | same. The QuestDB form with `;` (`'2026-09-10;1d'`) is not available. |
| Row range | `LIMIT 10,20` | same (rows 11 to 20), or `LIMIT 10 OFFSET 10` |
| Bucket a time | `timestamp_floor('1h', time)` | same, or `date_trunc('hour', time)` |
| Nepal clock | `to_timezone(time, 'Asia/Kathmandu')` | same |
| Implicit GROUP BY | yes | yes, same rule |
| Casts | `x::DOUBLE` | same |
| Remove all rows | `TRUNCATE TABLE t` | same |
| Joins | `JOIN`, `LEFT JOIN`, `ASOF JOIN`, `LT JOIN`, `SPLICE JOIN` | the same, and `RIGHT JOIN`, `FULL JOIN`, `CROSS JOIN`, `JOIN ... USING`. `SPLICE JOIN ... ON` with several keys keeps every row of both tables (QuestDB 9.4.3 drops some); no `TOLERANCE` yet |
| Indicators | few built in | `sma`, `ema`, `rsi`, `atr`, `lag`, `pct_change`, ... (chapter 5) |

### Hourly candles (candles_get.go)

```sql
INSERT INTO "Ochl_Minutes" VALUES
  ('2026-09-10T11:00:00+05:45', 'CITY-1', 504.6, 504.9, 504.3, 504.4, 280),
  ('2026-09-10T11:59:00+05:45', 'CITY-1', 505.1, 505.4, 505.0, 505.3, 900),
  ('2026-09-10T12:00:00+05:45', 'CITY-1', 505.3, 505.5, 505.2, 505.2, 400);

-- QuestDB (006): SAMPLE BY 1h ALIGN TO CALENDAR WITH OFFSET '00:15'
-- KarelaDB:
SELECT time, first(open) open, max(high) high, min(low) low, last(close) close, sum(volume) volume
FROM "Ochl_Minutes"
WHERE symbol = 'CITY-1' AND time IN '2026-09-10'
SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu'
ORDER BY time DESC
LIMIT 500;
```

```text
3 row(s) inserted

time                     | open  | high  | low   | close | volume
-------------------------+-------+-------+-------+-------+-------
2026-09-10T06:15:00.000Z | 505.3 | 505.5 | 505.2 | 505.2 |    400
2026-09-10T05:15:00.000Z | 504.6 | 505.4 | 504.3 | 505.3 |   1180
(2 rows, 0.2 ms)
```

The bucket times are the same as QuestDB's with the `00:15` offset (`05:15Z` = 11:00 NPT).

`WITH OFFSET` gives the same buckets:

```sql
-- The same with WITH OFFSET, written with a sign.
SELECT time, first(open) open, last(close) close
FROM "Ochl_Minutes"
WHERE symbol = 'CITY-1'
SAMPLE BY 1h ALIGN TO CALENDAR WITH OFFSET '+00:15';
```

```text
time                     | open  | close
-------------------------+-------+------
2026-09-10T05:15:00.000Z | 504.6 | 505.3
2026-09-10T06:15:00.000Z | 505.3 | 505.2
(2 rows, 0.3 ms)
```

```sql
-- The exact QuestDB text, without the sign, also works ('00:15' means '+00:15'):
SELECT time, first(open) open, last(close) close
FROM "Ochl_Minutes"
WHERE symbol = 'CITY-1'
SAMPLE BY 1h ALIGN TO CALENDAR WITH OFFSET '00:15';
```

```text
time                     | open  | close
-------------------------+-------+------
2026-09-10T05:15:00.000Z | 504.6 | 505.3
2026-09-10T06:15:00.000Z | 505.3 | 505.2
(2 rows, 0.2 ms)
```

### Weekly candles (candles_weekly.go)

```sql
-- 006 folds day rows into Sunday weeks in Go (rollupWeeklySunday). KarelaDB does it in SQL.
-- Day rows are at 00:00 UTC, so no TIME ZONE is needed here.
SELECT time, first(open) open, max(high) high, min(low) low, last(close) close, sum(volume) volume
FROM "Ochl_Day"
WHERE symbol = 'CITY'
SAMPLE BY 1w WEEK START SUNDAY
ORDER BY time DESC
LIMIT 500;
```

```text
time                     | open | high  | low   | close | volume
-------------------------+------+-------+-------+-------+-------
2026-09-06T00:00:00.000Z |  512 | 512.4 | 500.7 | 504.9 | 365430
(1 row, 0.3 ms)
```

The bucket time is Sunday 00:00 UTC, the same value `weekBucketStartSunday` makes in Go. (Do **not** add `TIME ZONE 'Asia/Kathmandu'` here: the bucket would then be stamped Saturday 18:15 UTC.)

### Deleting rows

```sql
-- QuestDB cannot delete rows (006 rebuilds tables with CREATE TABLE AS). KarelaDB can:
DELETE FROM "Ochl_Minutes" WHERE symbol = 'CITY-1' AND time < '1990-01-01';
DELETE FROM "TradeLog" WHERE date IN '2026-09-10' AND transaction_id = 100003;
SELECT count(*) AS trade_log_rows FROM "TradeLog";
```

```text
0 row(s) deleted

1 row(s) deleted

trade_log_rows
---------------
              2
(1 row, 0.1 ms)
```

Code like `holiday_sweep.go`, `minute_day_replace.go` and `trade_log_purge.go` (copy table, filter, swap) can become one `DELETE` plus `INSERT OR REPLACE`.

### LATEST ON (live_movers.go)

```sql
INSERT INTO "LiveData" (symbol, ltp, pct_change, volume, timestamp) VALUES
  ('CITY', 513.0, 0.4, 12000, '2026-09-10T11:05:00+05:45'),
  ('CITY', 527.1, 2.71, 90500, '2026-09-10T14:59:00+05:45'),
  ('COAST',  401.9, 0.7, 40100, '2026-09-10T14:59:00+05:45');

-- Same text as live_movers.go:
SELECT symbol, ltp, point_change, pct_change, volume FROM "LiveData"
WHERE symbol IN ('CITY', 'COAST') AND timestamp >= '2026-09-10T00:00:00.000000Z'
LATEST ON timestamp PARTITION BY symbol;
```

```text
3 row(s) inserted

symbol | ltp   | point_change | pct_change | volume
-------+-------+--------------+------------+-------
CITY   | 527.1 |         NULL |       2.71 |  90500
COAST  | 401.9 |         NULL |        0.7 |  40100
(2 rows, 0.2 ms)
```

### Names

```sql
-- Table and column names do not care about upper or lower case, with or without quotes.
SELECT count(*) AS a FROM "Ochl_Day";
SELECT count(*) AS b FROM ochl_day;
SELECT count(*) AS c FROM OCHL_DAY;
```

All three return the same count (5 after the import below).

## Moving the data

The plan:

1. **Export** each table (or each year or month) from QuestDB as CSV with `/exp`.
2. **Convert** the CSV into `INSERT OR REPLACE` statements with `csv-to-sql.ps1`.
3. **Load** the SQL into KarelaDB with `kareladb sql` (KarelaDB server stopped) or `POST /exec` (server running).
4. **Compare** row counts and a few sums between QuestDB and KarelaDB.

### 1. Export from QuestDB

Run this against your QuestDB (port 9000). **Not run while writing this tutorial** (there was no QuestDB on the test PC):

```powershell
$qdb = "http://127.0.0.1:9000"
curl.exe -s -G "$qdb/exp" --data-urlencode "query=SELECT * FROM 'Ochl_Day' WHERE time IN '2026'" -o Ochl_Day_2026.csv
curl.exe -s -G "$qdb/exp" --data-urlencode "query=SELECT * FROM 'Ochl_Minutes' WHERE time IN '2026-09'" -o Ochl_Minutes_2026-09.csv
curl.exe -s -G "$qdb/exp" --data-urlencode "query=SELECT * FROM 'TradeLog' WHERE date IN '2026-09-10'" -o TradeLog_2026-09-10.csv
```

- Export big tables **one partition at a time** (a year, a month or a day). Files stay small, and a failed step is easy to repeat.
- Use `SELECT *` so the columns come in table order. Or list the columns: the script uses the header line as the column list.

A QuestDB CSV looks like this. The sample file `Ochl_Day.csv` in the examples folder was **written by hand** in this style (times with 6 digits, quoted header and text). The script accepts the values with or without quotes.

```text
"time","symbol","open","high","low","close","volume"
2026-09-09T00:00:00.000000Z,"CITY",512.0,512.4,504.0,504.6,182390.0
2026-09-09T00:00:00.000000Z,"COAST",398.0,398.8,379.2,380.1,186330.0
2026-09-10T00:00:00.000000Z,"CITY",504.6,507.0,500.7,504.9,183040.0
2026-09-10T00:00:00.000000Z,"COAST",380.1,382.0,373.2,376.1,186200.0
2026-09-10T00:00:00.000000Z,"VOLT",187.3,192.1,184.2,191.2,41470.0
```

The simplest way to load such a file into a running KarelaDB server is `POST /imp`, the same call QuestDB takes (chapter 8):

```powershell
curl.exe -s -F "data=@Ochl_Day_2026.csv" "http://127.0.0.1:9900/imp?name=Ochl_Day"
```

The steps below do the same without a server: they turn the CSV into SQL and load it with `kareladb sql`.

### 2. Convert: csv-to-sql.ps1

The script examples/10-migrating-from-questdb/csv-to-sql.ps1 reads the CSV line by line and writes INSERT statements:

- Values that look like numbers stay numbers. Everything else becomes `'text'` (times, symbols). Empty values become NULL.
- One `INSERT OR REPLACE` per `-BatchSize` rows (default 5000). `-OnDuplicate IGNORE` or `NONE` change the verb.
- It works in Windows PowerShell 5.1 and PowerShell 7.

Here with a batch size of 3, so you can see two statements:

```powershell
.\csv-to-sql.ps1 -Csv Ochl_Day.csv -Table Ochl_Day -Out Ochl_Day.sql -BatchSize 3
Get-Content Ochl_Day.sql
```

```text
5 rows from Ochl_Day.csv written to Ochl_Day.sql
INSERT OR REPLACE INTO "Ochl_Day" ("time", "symbol", "open", "high", "low", "close", "volume") VALUES
  ('2026-09-09T00:00:00.000000Z', 'CITY', 512.0, 512.4, 504.0, 504.6, 182390.0),
  ('2026-09-09T00:00:00.000000Z', 'COAST', 398.0, 398.8, 379.2, 380.1, 186330.0),
  ('2026-09-10T00:00:00.000000Z', 'CITY', 504.6, 507.0, 500.7, 504.9, 183040.0);
INSERT OR REPLACE INTO "Ochl_Day" ("time", "symbol", "open", "high", "low", "close", "volume") VALUES
  ('2026-09-10T00:00:00.000000Z', 'COAST', 380.1, 382.0, 373.2, 376.1, 186200.0),
  ('2026-09-10T00:00:00.000000Z', 'VOLT', 187.3, 192.1, 184.2, 191.2, 41470.0);
```

### 3. Load

```powershell
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
Get-Content Ochl_Day.sql -Raw -Encoding UTF8 | kareladb sql market -
"exit code: $LASTEXITCODE"
kareladb sql market "SELECT * FROM Ochl_Day"
```

```text
3 row(s) inserted

2 row(s) inserted
exit code: 0
time                     | symbol | open  | high  | low   | close | volume
-------------------------+--------+-------+-------+-------+-------+-------
2026-09-09T00:00:00.000Z | CITY   |   512 | 512.4 |   504 | 504.6 | 182390
2026-09-10T00:00:00.000Z | CITY   | 504.6 |   507 | 500.7 | 504.9 | 183040
2026-09-09T00:00:00.000Z | COAST  |   398 | 398.8 | 379.2 | 380.1 | 186330
2026-09-10T00:00:00.000Z | COAST  | 380.1 |   382 | 373.2 | 376.1 | 186200
2026-09-10T00:00:00.000Z | VOLT   | 187.3 | 192.1 | 184.2 | 191.2 |  41470
(5 rows, 0.3 ms)
```

Loading the same file again is safe:

```powershell
# Running the same import again is safe: INSERT OR REPLACE finds the rows by (time, symbol).
Get-Content Ochl_Day.sql -Raw -Encoding UTF8 | kareladb sql market -
kareladb sql market "SELECT count(*) AS rows FROM Ochl_Day"
```

```text
0 row(s) inserted, 3 replaced

0 row(s) inserted, 2 replaced
rows
----
   5
(1 row, 0.2 ms)
```

Duplicates inside the file are handled too. `TradeLog.csv` has transaction 100002 twice:

```powershell
# TradeLog.csv has transaction 100002 twice. DEDUP KEY (date, transaction_id) keeps one row.
.\csv-to-sql.ps1 -Csv TradeLog.csv -Table TradeLog -Out TradeLog.sql
Get-Content TradeLog.sql -Raw -Encoding UTF8 | kareladb sql market -
kareladb sql market "SELECT date, transaction_id, symbol, buyer, seller, quantity, rate, amount FROM TradeLog"
```

```text
4 rows from TradeLog.csv written to TradeLog.sql
3 row(s) inserted, 1 replaced
date                     | transaction_id | symbol | buyer | seller | quantity | rate  | amount
-------------------------+----------------+--------+-------+--------+----------+-------+-------
2026-09-10T00:00:00.000Z |         100001 | CITY   |    58 |     45 |      100 | 515.5 |  51550
2026-09-10T00:00:00.000Z |         100002 | COAST  |    45 |      1 |     1000 |   398 | 398000
2026-09-10T00:00:00.000Z |         100003 | VOLT   |    34 |     58 |      200 |   184 |  36800
(3 rows, 0.2 ms)
```

**While the KarelaDB server runs**, send the file with POST (chapter 8). The body may be up to 64 MB, so split very big SQL files (for example one file per month):

```powershell
$body = [System.IO.File]::ReadAllBytes((Resolve-Path Ochl_Day.sql))
$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/exec?compat=0" -Body $body -ContentType "text/plain; charset=utf-8"
$r.results | ForEach-Object { $_.message }
```

Speed: on the test PC, loading 24,000 minute rows in 5 statements of 5000 rows took about 0.6 seconds with `kareladb sql`. The PowerShell conversion script is slower than the load; for many millions of rows you may want to convert in Go or Python (same rules: numbers stay numbers, other values in single quotes with `'` doubled).

### 4. Compare

Run the same checks on both databases:

```sql
SELECT count(*) AS rows, min(time) AS first, max(time) AS last, sum(volume) AS volume
FROM Ochl_Day WHERE time IN '2026';

SELECT date, count(*) AS trades, sum(quantity) AS shares, sum(amount) AS amount
FROM TradeLog WHERE date IN '2026-09' SAMPLE BY 1d;
```

The numbers must be the same. Also open a few charts in both consoles.

## A migration checklist

1. Build KarelaDB, run the tests (chapter 1).
2. Create the tables (above). Keep the SQL in a file in the 006 repo.
3. Export and load one small table (`LiveData` of one day). Compare.
4. Load `Ochl_Day`, one year at a time. Compare counts per year.
5. Load `Ochl_Minutes` and `Ochl_Minutes_Adj`, one month at a time.
6. Load `TradeLog`, one day or month at a time.
7. Change the queries that use the differences above (`DROP PARTITION LIST`, `'2026-09-10;1d'`).
8. Point the Go `pgx` connection at port 8832 (chapter 14), and the ILP writers at `POST /write` on port 9900.
9. Run 006 against KarelaDB on a test PC for some days, next to QuestDB.
10. Set up the daily backup and check (chapters 7 and 9), and test a restore.

## Try it yourself

1. Write the KarelaDB `CREATE TABLE` for a QuestDB table `Index_Minutes (time TIMESTAMP, index_name SYMBOL INDEX, value DOUBLE) TIMESTAMP(time) PARTITION BY MONTH WAL DEDUP UPSERT KEYS(time, index_name)`.
2. Rewrite for KarelaDB: `SELECT * FROM Ochl_Day WHERE symbol = 'CITY' ORDER BY time DESC LIMIT 20,40`.
3. Rewrite for KarelaDB: `SELECT timestamp_floor('1d', time) AS day, count() FROM LiveData GROUP BY day`.

<details>
<summary>Answers</summary>

1. ```sql
   CREATE TABLE IF NOT EXISTS "Index_Minutes" (
     time TIMESTAMP, index_name SYMBOL, value DOUBLE
   ) TIMESERIES(time) PARTITION BY MONTH DEDUP KEY (time, index_name);
   ```
2. ```sql
   SELECT * FROM Ochl_Day WHERE symbol = 'CITY' ORDER BY time DESC LIMIT 20 OFFSET 20;
   ```
   (QuestDB `LIMIT 20,40` means rows 21 to 40. KarelaDB also takes `LIMIT 20,40` as it is.)
3. ```sql
   SELECT timestamp, count(*) AS n FROM LiveData SAMPLE BY 1d;
   ```
   or `SELECT date_trunc('day', timestamp) AS day, count(*) AS n FROM LiveData GROUP BY date_trunc('day', timestamp);`. The QuestDB text with `timestamp_floor` and `count()` also runs as it is.

</details>

---

Next: [11. SQL reference](11-sql-reference.md)
