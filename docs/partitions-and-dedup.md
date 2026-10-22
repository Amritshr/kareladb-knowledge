# Partitions, SORT BY and DEDUP KEY

> How PARTITION BY, SORT BY and DEDUP KEY of a time-series table change where rows go, their order, and what happens to duplicates; DROP PARTITION deletes old data fast.

- Category: Time-series
- Keywords: partition, partitions, PARTITION BY, DAY, MONTH, YEAR, NONE, SYMBOL(col), KEY(col), partition by symbol, symbol partitions, DROP PARTITION OLDER THAN, OLDER THAN, TRUNCATE, keyless table, batch dedup, KDB\_NO\_BATCH\_DEDUP, how loads find duplicates, SORT BY, SORT, sort order, row order, DEDUP KEY, DEDUP, KEY, dedup, deduplication, duplicates, duplicate rows, upsert, INSERT OR REPLACE, INSERT OR IGNORE, DROP PARTITION, delete old data, retention, purge, files, key range, TIMESERIES, time-series table, QuestDB, DROP PARTITION LIST, dedup, skip dedup, DEDUP TABLE, repair duplicates, dedup\_insert, WITH (dedup\_insert, plain INSERT upserts, DEDUP UPSERT, compression, WITH (compression, SET (compression, COMPRESS TABLE, packed, pack, compress, bytes a row, disk size, sealed partition, tail files, tail\_files, KDB\_TAIL\_FILES, --tail-files, append, appends, checkpoint, rewrite, delta files, KDB\_NO\_PARTITION\_DELTA, partition\_deltas, small update, small replace, trash growth
- See also: [CREATE TABLE](create-table.md), [ALTER, RENAME and DROP TABLE](alter-table.md), [INSERT](insert.md), [UPDATE and DELETE](update-delete.md), [Time and time zones (storage)](time-and-time-zones.md#storage), [EXPLAIN (explain)](explain.md#explain), [Performance tips](performance-tips.md)

A time-series table (`CREATE TABLE ... TIMESERIES(time)`) has three extra options. This page shows what they **do**. The full `CREATE TABLE` and `ALTER TABLE` grammar is in [create-table](create-table.md) and [alter-table](alter-table.md).

| Option | What it decides | Default |
|---|---|---|
| [PARTITION BY](partitions-and-dedup.md#partition-by) | which **file** a row goes into: one file per day, month or year, and with [SYMBOL(col)](partitions-and-dedup.md#partition-by-symbol) one per symbol too | `DAY` |
| [SORT BY](partitions-and-dedup.md#sort-by) | the **order** of rows inside each file | the first `SYMBOL` column, then the time column |
| [DEDUP KEY](partitions-and-dedup.md#dedup-key) | when two rows are **the same row** (a duplicate) | none: every row is kept |

`PARTITION BY` and `SORT BY` cannot be changed after the table is made. Choose them when you create the table. The `DEDUP KEY` can be set or taken off later with [ALTER TABLE ... DEDUP ENABLE](alter-table.md#dedup-enable), which rewrites the rows.

**Example: The sample market tables and their partitions** (sample data: sample)

```sql
SHOW TABLES;
```

Result:

| name (STRING) | kind (STRING) | partition (STRING) | columns (INT) | rows (LONG) |
|---|---|---|---|---|
| brokers | relational | NONE | 2 | 5 |
| live_data | timeseries | DAY | 12 | 12 |
| ochl_day | timeseries | YEAR | 7 | 57 |
| ochl_minutes | timeseries | MONTH | 7 | 956 |
| securities | relational | NONE | 3 | 5 |
| trade_log | timeseries | DAY | 8 | 32 |

(6 rows)

<a id="partition-by"></a>

## PARTITION BY

Syntax:

```sql
CREATE TABLE name (...) TIMESERIES(time_column)
    PARTITION BY DAY | MONTH | YEAR | NONE
```

A **partition** is one part of the table on disk. KDB puts each row into the partition of its time: with `PARTITION BY MONTH`, all rows of September 2026 go into the partition `2026-09`.

| PARTITION BY | Partition names | Good for |
|---|---|---|
| `DAY` (default) | `'2026-09-10'` | trades, live price snapshots (many rows per day) |
| `MONTH` | `'2026-09'` | one-minute candles |
| `YEAR` | `'2026'` | daily candles, yearly reports |
| `NONE` | (one part only) | small tables |

- **Notes:**
  - Partitions follow the **UTC** date. `'2026-09-10T02:00:00+05:45'` (2 AM in Nepal) is still 9 September in UTC, so it goes into partition `2026-09-09`.
  - A query with a time condition on the first table (`time IN '2026-09'`, `>=`, `<`, `BETWEEN`) reads **only** the partitions in that range. `EXPLAIN` shows it as `1 of 2 partitions`.
  - A condition without the time column (`close > 500`) reads every partition.
  - A partition is made when its first row arrives. Old partitions can be deleted fast with [DROP PARTITION](partitions-and-dedup.md#drop-partition).
  - Too small partitions (`DAY` for 50 rows a day) make many small files; too big ones make time filters less useful. See the table above.
  - Only time-series tables have partitions. `PARTITION BY` on a relational table is an error.
  - A table that is nearly always read one symbol at a time can be split by symbol too: [PARTITION BY ..., SYMBOL(col)](partitions-and-dedup.md#partition-by-symbol).

**Example: A condition on time skips whole partitions** (sample data: sample)

```sql
EXPLAIN SELECT symbol, close FROM ochl_day WHERE time IN '2025-12';
EXPLAIN SELECT symbol, close FROM ochl_day WHERE close > 500;
```

Result:

`EXPLAIN SELECT symbol, close FROM ochl_day WHERE time IN '2025-12'`

| plan (STRING) |
|---|
| scan table ochl_day (1 of 2 partitions, about 57 rows) |
| build 3 of 7 stored column(s) per row: time, symbol, close |
| filter while scanning: 1 condition(s) |
| engine: column |

(4 rows)

`EXPLAIN SELECT symbol, close FROM ochl_day WHERE close > 500`

| plan (STRING) |
|---|
| scan table ochl_day (2 of 2 partitions, about 57 rows) |
| build 3 of 7 stored column(s) per row: time, symbol, close |
| filter while scanning: 1 condition(s) |
| engine: column |

(4 rows)

**Example: Month partitions: rows of three months make three partitions** (sample data: sample)

```sql
CREATE TABLE prices (time TIMESTAMP, symbol SYMBOL, close DOUBLE)
  TIMESERIES(time) PARTITION BY MONTH;
INSERT INTO prices VALUES
  ('2026-07-31T11:00:00+05:45', 'CITY', 511.0),
  ('2026-08-30T11:00:00+05:45', 'CITY', 507.3),
  ('2026-09-10T11:00:00+05:45', 'CITY', 504.6);
EXPLAIN SELECT close FROM prices WHERE time IN '2026-09';
```

Result:

`CREATE TABLE prices (`

```text
table 'prices' created
```

`INSERT INTO prices VALUES ('2026-07-31T11:00:00+05:45', 'CITY', 511.0), ('2026-08-30T11:00:00+05:45'`

```text
3 row(s) inserted
```

`EXPLAIN SELECT close FROM prices WHERE time IN '2026-09'`

| plan (STRING) |
|---|
| scan table prices (1 of 3 partitions, about 3 rows) |
| build 2 of 3 stored column(s) per row: time, close |
| filter while scanning: 1 condition(s) |
| engine: column |

(4 rows)

**Example: Early morning in Nepal is the day before in UTC: the error lists partition 2026-09-09** (sample data: sample; shows an error)

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO ticks VALUES ('2026-09-10T02:00:00+05:45', 'CITY', 1), ('2026-09-10T11:00:00+05:45', 'CITY', 2);
```

```sql
ALTER TABLE ticks DROP PARTITION '2026-09-11';
```

Result:

Error: `table 'ticks' has no partition '2026-09-11'; partitions: 2026-09-09, 2026-09-10`

**Example: Partitions are only for time-series tables** (sample data: sample; shows an error)

```sql
CREATE TABLE app_notes (id INT PRIMARY KEY, text STRING) PARTITION BY DAY;
```

Result:

Error: `line 1, column 58: PARTITION BY is only for time-series tables; expected TIMESERIES(<TIMESTAMP or DATE column>) on table 'app_notes'`

<a id="partition-by-symbol"></a>

## PARTITION BY time, SYMBOL(col)

Syntax:

```sql
CREATE TABLE name (...) TIMESERIES(time_column)
    PARTITION BY YEAR | MONTH | NONE, SYMBOL(column)
    SORT BY (column, ...) [DEDUP KEY (column, ..., time_column)]
PARTITION BY ..., KEY(column)        -- the same, for a column that is not a market symbol
```

A second level of partitions: each time bucket is split again into **one file per value** of the column. A query for one symbol then opens only that symbol's files.

| Rule | Why |
|---|---|
| the time part is `YEAR`, `MONTH` or `NONE`; `DAY` is refused | one small file per symbol per day makes thousands of files a week |
| the column is a stored `SYMBOL` or `STRING` column | its value names the file |
| it is the **first** `SORT BY` column | then reading the files one after the other keeps the `SORT BY` order |
| a `DEDUP KEY` must include it | a duplicate is looked for in one partition only |
| a value is at most 64 bytes, with no 0 byte | the value is part of a file name |
| at most 4,096 values with `NONE`, 100,000 partitions with `YEAR` or `MONTH` | every value is a file of its own |

- **Returns:** `SHOW TABLES` shows the partition as `YEAR, SYMBOL(symbol)`. `KEY(col)` is shown as `SYMBOL(col)`.
- **Notes:**
  - `WHERE symbol = 'CITY'` or `symbol IN (...)` opens only those files. `EXPLAIN` shows it as `1 of 4 partitions`.
  - Good for data read **one value at a time**: one symbol's candles, one source's news. Not for a table read a whole day at a time across all symbols (a trade list): plain `PARTITION BY DAY` is right there.
  - Reads get faster, writes do not: a load that holds 300 symbols writes 300 files.
  - Not for a column with very many values (a user id). Keep such a column as the first `SORT BY` column instead: that already reads only its rows.
  - `DROP PARTITION '2025'` drops every symbol of that year. Single symbols cannot be dropped by name: use `DELETE ... WHERE symbol = ...`. With `NONE` there is no time part to drop: use `DELETE` or [TRUNCATE](update-delete.md#truncate).
  - Only for new tables: an existing table cannot be changed to it. Not with `CREATE TABLE ... AS`.
  - An older KDB build cannot open a database with such a table (see [versions](versions.md)).

**Example: Daily candles in one file per year and symbol** (sample data: sample)

Setup:

```sql
CREATE TABLE candles (time TIMESTAMP ROUND 1d, symbol SYMBOL, close DOUBLE)
  TIMESERIES(time) PARTITION BY YEAR, SYMBOL(symbol) SORT BY (symbol, time) DEDUP KEY (symbol, time);
INSERT INTO candles VALUES
  ('2025-09-10', 'CITY', 500.0), ('2026-09-10', 'CITY', 504.6),
  ('2026-09-10', 'COAST', 376.1), ('2026-09-10', 'VOLT', 191.2);
```

```sql
SHOW TABLES;
EXPLAIN SELECT time, close FROM candles WHERE symbol = 'COAST';
ALTER TABLE candles DROP PARTITION '2025';
SELECT time, symbol, close FROM candles ORDER BY symbol;
```

Result:

`SHOW TABLES`

| name (STRING) | kind (STRING) | partition (STRING) | columns (INT) | rows (LONG) |
|---|---|---|---|---|
| brokers | relational | NONE | 2 | 5 |
| candles | timeseries | YEAR, SYMBOL(symbol) | 3 | 4 |
| live_data | timeseries | DAY | 12 | 12 |
| ochl_day | timeseries | YEAR | 7 | 57 |
| ochl_minutes | timeseries | MONTH | 7 | 956 |
| securities | relational | NONE | 3 | 5 |
| trade_log | timeseries | DAY | 8 | 32 |

(7 rows)

`EXPLAIN SELECT time, close FROM candles WHERE symbol = 'COAST'`

| plan (STRING) |
|---|
| scan table candles (1 of 4 partitions, about 4 rows) |
| read only 1 key range(s) of each partition |
| filter while scanning: 1 condition(s) |
| engine: column |

(4 rows)

`ALTER TABLE candles DROP PARTITION '2025'`

```text
1 partition(s) of 'candles' dropped
```

`SELECT time, symbol, close FROM candles ORDER BY symbol`

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.6 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 |

(3 rows)

**Example: News split by source: KEY(col) and PARTITION BY NONE** (sample data: sample)

Setup:

```sql
CREATE TABLE news (time TIMESTAMP, source STRING, title STRING)
  TIMESERIES(time) PARTITION BY NONE, KEY(source) SORT BY (source, time);
INSERT INTO news VALUES
  ('2026-09-10T11:00:00+05:45', 'wire one', 'City Bank profit rises 18%'),
  ('2026-09-11T09:30:00+05:45', 'market desk', 'Index closes higher');
```

```sql
EXPLAIN SELECT title FROM news WHERE source = 'market desk';
SHOW CREATE TABLE news;
```

Result:

`EXPLAIN SELECT title FROM news WHERE source = 'market desk'`

| plan (STRING) |
|---|
| scan table news (1 of 2 partitions, about 2 rows) |
| read only 1 key range(s) of each partition |
| filter while scanning: 1 condition(s) |
| engine: column |

(4 rows)

`SHOW CREATE TABLE news`

| create_sql (STRING) |
|---|
| CREATE TABLE news (   time TIMESTAMP,   source STRING,   title STRING ) TIMESERIES(time) PARTITION BY NONE, SYMBOL(source) SORT BY (source, time) |

(1 row)

**Example: DAY is refused with SYMBOL(col)** (sample data: sample; shows an error)

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE)
  TIMESERIES(time) PARTITION BY DAY, SYMBOL(symbol);
```

Result:

Error: `PARTITION BY ..., SYMBOL(column) on table 'ticks': the time part must be YEAR, MONTH or NONE (as in PARTITION BY YEAR, SYMBOL(symbol))`

**Example: The column must be the first SORT BY column** (sample data: sample; shows an error)

```sql
CREATE TABLE candles (time TIMESTAMP, symbol SYMBOL, close DOUBLE)
  TIMESERIES(time) PARTITION BY MONTH, SYMBOL(symbol) SORT BY (time);
```

Result:

Error: `PARTITION BY ..., SYMBOL(column) on table 'candles': 'symbol' must be the first SORT BY column (as in SORT BY (symbol, time))`

**Example: The DEDUP KEY must hold the column** (sample data: sample; shows an error)

```sql
CREATE TABLE candles (time TIMESTAMP, symbol SYMBOL, close DOUBLE)
  TIMESERIES(time) PARTITION BY MONTH, SYMBOL(symbol) DEDUP KEY (time);
```

Result:

Error: `PARTITION BY ..., SYMBOL(column) on table 'candles': the DEDUP KEY must include 'symbol'`

<a id="sort-by"></a>

## SORT BY

Syntax:

```sql
CREATE TABLE name (...) TIMESERIES(time_column)
    [PARTITION BY ...]
    SORT BY (column [, column ...])
```

Sets the **order of rows inside each partition**. Rows are kept sorted by these columns, whatever order you insert them in.

- **Returns:** a `SELECT` without `ORDER BY` gives rows partition by partition, and inside a partition in `SORT BY` order.
- **Notes:**
  - The default is the first `SYMBOL` column, then the time column: `SORT BY (symbol, time)`. Without a `SYMBOL` column it is the time column.
  - With `SORT BY (symbol, time)`, `WHERE symbol = 'CITY'` or `symbol IN (...)` reads only CITY's rows (with a time range: only that part of them). `EXPLAIN` shows `read only 1 key range(s)`. This is why the default is good for market data: most queries ask for one symbol.
  - With `SORT BY (time)`, a filter on `symbol` alone must read every row of the partitions. A time range still reads only that part.
  - Do not depend on the order without `ORDER BY`: the partitions, `SORT BY` and the query plan decide it. Write `ORDER BY` when the order matters.
  - `SORT BY` only decides the order. Two rows with the same `SORT BY` values are **not** duplicates; that is the job of [DEDUP KEY](partitions-and-dedup.md#dedup-key).

**Example: Default SORT BY (symbol, time): rows come grouped by symbol** (sample data: sample)

Setup:

```sql
CREATE TABLE trades (time TIMESTAMP, symbol SYMBOL, broker INT, qty LONG) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO trades VALUES
  ('2026-09-10T11:02:00+05:45', 'COAST', 58, 10),
  ('2026-09-10T11:00:00+05:45', 'CITY', 45, 20),
  ('2026-09-10T11:01:00+05:45', 'COAST', 34, 30),
  ('2026-09-10T11:00:00+05:45', 'VOLT', 1, 40);
```

```sql
SELECT * FROM trades;
EXPLAIN SELECT * FROM trades WHERE symbol = 'COAST';
```

Result:

`SELECT * FROM trades`

| time (TIMESTAMP) | symbol (SYMBOL) | broker (INT) | qty (LONG) |
|---|---|---|---|
| 2026-09-10T05:15:00.000Z | CITY | 45 | 20 |
| 2026-09-10T05:16:00.000Z | COAST | 34 | 30 |
| 2026-09-10T05:17:00.000Z | COAST | 58 | 10 |
| 2026-09-10T05:15:00.000Z | VOLT | 1 | 40 |

(4 rows)

`EXPLAIN SELECT * FROM trades WHERE symbol = 'COAST'`

| plan (STRING) |
|---|
| scan table trades (1 of 1 partitions, about 4 rows) |
| read only 1 key range(s) of each partition |
| filter while scanning: 1 condition(s) |
| engine: column |

(4 rows)

**Example: SORT BY (time): rows come in time order, but a symbol filter reads everything** (sample data: sample)

Setup:

```sql
CREATE TABLE trades (time TIMESTAMP, symbol SYMBOL, broker INT, qty LONG)
  TIMESERIES(time) PARTITION BY DAY SORT BY (time);
INSERT INTO trades VALUES
  ('2026-09-10T11:02:00+05:45', 'COAST', 58, 10),
  ('2026-09-10T11:00:00+05:45', 'CITY', 45, 20),
  ('2026-09-10T11:01:00+05:45', 'COAST', 34, 30),
  ('2026-09-10T11:00:00+05:45', 'VOLT', 1, 40);
```

```sql
SELECT * FROM trades;
EXPLAIN SELECT * FROM trades WHERE symbol = 'COAST';
```

Result:

`SELECT * FROM trades`

| time (TIMESTAMP) | symbol (SYMBOL) | broker (INT) | qty (LONG) |
|---|---|---|---|
| 2026-09-10T05:15:00.000Z | CITY | 45 | 20 |
| 2026-09-10T05:15:00.000Z | VOLT | 1 | 40 |
| 2026-09-10T05:16:00.000Z | COAST | 34 | 30 |
| 2026-09-10T05:17:00.000Z | COAST | 58 | 10 |

(4 rows)

`EXPLAIN SELECT * FROM trades WHERE symbol = 'COAST'`

| plan (STRING) |
|---|
| scan table trades (1 of 1 partitions, about 4 rows) |
| filter while scanning: 1 condition(s) |
| engine: column |

(3 rows)

**Example: SORT BY needs real columns** (sample data: sample; shows an error)

```sql
CREATE TABLE bad (time TIMESTAMP, symbol SYMBOL) TIMESERIES(time) SORT BY (sym);
```

Result:

Error: `line 1, column 76: SORT BY column 'sym' does not exist; expected one of the columns of 'bad'`

<a id="dedup-key"></a>

## DEDUP KEY

Syntax:

```sql
CREATE TABLE name (...) TIMESERIES(time_column)
    [PARTITION BY ...] [SORT BY (...)]
    DEDUP KEY (column [, column ...], time_column)

INSERT INTO name VALUES (...)              -- a duplicate: error, nothing is saved (see dedup_insert)
INSERT OR REPLACE INTO name VALUES (...)   -- a duplicate: the old row is replaced
INSERT OR IGNORE INTO name VALUES (...)    -- a duplicate: the new row is skipped
```

Says which columns make a row **unique**. Two rows with the same values in all `DEDUP KEY` columns are the same row. `DEDUP KEY (symbol, time)` means "one row per symbol per time".

| Statement | Key is new | Key is already there |
|---|---|---|
| `INSERT` | row inserted | **error**, nothing from the statement is saved |
| `INSERT OR REPLACE` | row inserted | the whole old row is **replaced** by the new one |
| `INSERT OR IGNORE` | row inserted | the new row is **skipped** |
| `UPDATE` that would make two equal keys | - | error |

- **Returns:** messages like `1 row(s) inserted, 1 replaced` or `0 row(s) inserted, 1 skipped (already there)`.
- **NULL:** `NULL` values in key columns are compared like values: two rows with the same time and a `NULL` symbol are duplicates.
- **Notes:**
  - The DEDUP KEY **must include the time column**. KDB finds duplicates inside one partition, and the time decides the partition. A stored column holding the time's **minute** may take its place: see [a key on the minute](partitions-and-dedup.md#minute-key).
  - Without a DEDUP KEY, every INSERT adds rows, also exact copies. Load the same file twice and you have every row twice. Such a table loads fast: nothing is looked up (see [how loads find duplicates](partitions-and-dedup.md#load-dedup)).
  - Duplicates **inside one statement** count too: with `INSERT OR REPLACE`, the last one wins.
  - `INSERT OR REPLACE` replaces the **whole** row: columns you do not give become their DEFAULT or `NULL`. To change some columns only, use `UPDATE`.
  - With `ROUND 1d` or `ROUND 1m` on the time column, two times in the same day or minute become equal, so they are duplicates ([create-table](create-table.md)).
  - Time-series tables cannot have a `PRIMARY KEY`. Use `DEDUP KEY (..., time)`.
  - Tip: give every time-series table that you import into a DEDUP KEY and load with `INSERT OR REPLACE`. Then you can run the same import again and again ([insert](insert.md)).

**Example: Live snapshots: a snapshot sent again replaces the old one** (sample data: sample)

Setup:

```sql
CREATE TABLE snapshots (time TIMESTAMP, symbol SYMBOL, ltp DOUBLE, volume LONG)
  TIMESERIES(time) PARTITION BY DAY DEDUP KEY (symbol, time);
INSERT INTO snapshots VALUES ('2026-09-10T11:05:00+05:45', 'CITY', 513.0, 65850);
```

```sql
INSERT OR REPLACE INTO snapshots VALUES
  ('2026-09-10T11:05:00+05:45', 'CITY', 513.2, 66010),
  ('2026-09-10T11:06:00+05:45', 'CITY', 513.5, 67000);
INSERT OR IGNORE INTO snapshots VALUES ('2026-09-10T11:05:00+05:45', 'CITY', 999, 1);
SELECT * FROM snapshots;
```

Result:

`INSERT OR REPLACE INTO snapshots VALUES ('2026-09-10T11:05:00+05:45', 'CITY', 513.2, 66010), ('2026-`

```text
1 row(s) inserted, 1 replaced
```

`INSERT OR IGNORE INTO snapshots VALUES ('2026-09-10T11:05:00+05:45', 'CITY', 999, 1)`

```text
0 row(s) inserted, 1 skipped (already there)
```

`SELECT * FROM snapshots`

| time (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) | volume (LONG) |
|---|---|---|---|
| 2026-09-10T05:20:00.000Z | CITY | 513.2 | 66010 |
| 2026-09-10T05:21:00.000Z | CITY | 513.5 | 67000 |

(2 rows)

**Example: A plain INSERT of a duplicate is refused** (sample data: sample; shows an error)

```sql
INSERT INTO ochl_day VALUES ('2026-09-10', 'CITY', 504.6, 507.0, 500.7, 504.9, 183040);
```

Result:

Error: `a row with symbol='CITY', time='2026-09-10T00:00:00.000Z' already exists in 'ochl_day'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it`

**Example: Trade log: the same transaction twice in one import keeps one row (the last)** (sample data: sample)

```sql
INSERT OR REPLACE INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate) VALUES
  ('2026-09-11', 200001, 'CITY', 45, 1, 10, 515.0),
  ('2026-09-11', 200001, 'CITY', 45, 1, 10, 516.0);
SELECT date, transaction_id, symbol, quantity, rate, amount FROM trade_log WHERE date IN '2026-09-11';
```

Result:

`INSERT OR REPLACE INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate) VALUE`

```text
1 row(s) inserted, 1 replaced
```

`SELECT date, transaction_id, symbol, quantity, rate, amount FROM trade_log WHERE date IN '2026-09-11`

| date (TIMESTAMP) | transaction_id (LONG) | symbol (SYMBOL) | quantity (LONG) | rate (DOUBLE) | amount (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-11T00:00:00.000Z | 200001 | CITY | 10 | 516 | 5160 |

(1 row)

**Example: Without a DEDUP KEY every copy is kept** (sample data: sample)

Setup:

```sql
CREATE TABLE raw_ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
```

```sql
INSERT INTO raw_ticks VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 510);
INSERT INTO raw_ticks VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 510);
SELECT count(*) AS rows_kept FROM raw_ticks;
```

Result:

`INSERT INTO raw_ticks VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 510)`

```text
1 row(s) inserted
```

`INSERT INTO raw_ticks VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 510)`

```text
1 row(s) inserted
```

`SELECT count(*) AS rows_kept FROM raw_ticks`

| rows_kept (LONG) |
|---|
| 2 |

(1 row)

**Example: A market index: one value per minute, DEDUP KEY on the time alone** (sample data: sample)

Setup:

```sql
CREATE TABLE market_index (time TIMESTAMP ROUND 1m, value DOUBLE)
  TIMESERIES(time) PARTITION BY MONTH DEDUP KEY (time);
```

```sql
INSERT OR REPLACE INTO market_index VALUES
  ('2026-09-10T11:00:05+05:45', 2840.1),
  ('2026-09-10T11:00:40+05:45', 2841.5),
  ('2026-09-10T11:01:10+05:45', 2842.0);
SELECT * FROM market_index;
```

Result:

`INSERT OR REPLACE INTO market_index VALUES ('2026-09-10T11:00:05+05:45', 2840.1), ('2026-09-10T11:00`

```text
2 row(s) inserted, 1 replaced
```

`SELECT * FROM market_index`

| time (TIMESTAMP) | value (DOUBLE) |
|---|---|
| 2026-09-10T05:15:00.000Z | 2841.5 |
| 2026-09-10T05:16:00.000Z | 2842 |

(2 rows)

**Example: An UPDATE may not make a duplicate** (sample data: sample; shows an error)

```sql
UPDATE ochl_day SET time = '2026-09-09' WHERE symbol = 'CITY' AND time IN '2026-09-10';
```

Result:

Error: `the update would create a second row with symbol='CITY', time='2026-09-09T00:00:00.000Z' in 'ochl_day'`

**Example: The DEDUP KEY must include the time column** (sample data: sample; shows an error)

```sql
CREATE TABLE bad (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) DEDUP KEY (symbol);
```

Result:

Error: `DEDUP KEY must include the time column 'time', e.g. DEDUP KEY (symbol, time), or a column GENERATED ALWAYS AS (date_trunc('minute', time)) STORED`

<a id="minute-key"></a>

## Ragged seconds: a DEDUP KEY on the minute

Syntax:

```sql
minute TIMESTAMP GENERATED ALWAYS AS (date_trunc('minute', time)) STORED
... DEDUP KEY (symbol, minute)
```

A feed of minute candles often sends the same minute with different seconds: `11:01:07`, then `11:01:42`. With `DEDUP KEY (symbol, time)` those are two rows. Put the minute in a stored [generated column](create-table.md#generated) and make **that** the key: then both are the same row, and the later one replaces the earlier one.

| Column in the key | `11:01:07` then `11:01:42`, same symbol |
|---|---|
| `time` | two rows |
| `minute` (`date_trunc('minute', time)`) | one row: the later one (with `INSERT OR REPLACE`, `dedup_insert = 'upsert'`, `POST /write` or `/imp`) |

- **Notes:**
  - The time column keeps the real time of the row (`11:01:42`). Only the key uses the minute.
  - The column must be `date_trunc('<unit>', <time column>)`, `STORED`, with a unit of `minute`, `second` or `ms`. An hour is refused: in Nepal (+05:45) a local hour can start before midnight UTC and end after it, so it would reach into another day's partition.
  - A plain `INSERT` of the same minute fails like any repeated key. Use `INSERT OR REPLACE`, or give the table `WITH (dedup_insert = 'upsert')` ([above](partitions-and-dedup.md#dedup-insert)). `POST /write` and `/imp` always replace.
  - Such a table checks its keys row by row, so a bulk load into it is slower than into a table keyed on the time itself.
  - An existing table moves to the minute with `ALTER TABLE ... ADD COLUMN` and then `ALTER TABLE ... DEDUP ENABLE UPSERT KEYS (...)`. Rows of one minute are folded then: the newest stays.

**Example: Minute candles: 11:01:07 and 11:01:42 of one symbol keep one row, the later** (sample data: sample)

Setup:

```sql
CREATE TABLE candle_1m (time TIMESTAMP, symbol SYMBOL, close DOUBLE,
    minute TIMESTAMP GENERATED ALWAYS AS (date_trunc('minute', time)) STORED)
  TIMESERIES(time) PARTITION BY DAY DEDUP KEY (symbol, minute) WITH (dedup_insert = 'upsert');
```

```sql
INSERT INTO candle_1m (time, symbol, close) VALUES ('2026-09-25T11:01:07+05:45', 'CITY', 510.0);
INSERT INTO candle_1m (time, symbol, close) VALUES ('2026-09-25T11:01:42+05:45', 'CITY', 512.5),
                                                ('2026-09-25T11:02:03+05:45', 'CITY', 513.0);
SELECT time, symbol, close, minute FROM candle_1m ORDER BY time;
```

Result:

`INSERT INTO candle_1m (time, symbol, close) VALUES ('2026-09-25T11:01:07+05:45', 'CITY', 510.0)`

```text
1 row(s) inserted
```

`INSERT INTO candle_1m (time, symbol, close) VALUES ('2026-09-25T11:01:42+05:45', 'CITY', 512.5), ('2`

```text
1 row(s) inserted, 1 replaced
```

`SELECT time, symbol, close, minute FROM candle_1m ORDER BY time`

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | minute (TIMESTAMP) |
|---|---|---|---|
| 2026-09-25T05:16:42.000Z | CITY | 512.5 | 2026-09-25T05:16:00.000Z |
| 2026-09-25T05:17:03.000Z | CITY | 513 | 2026-09-25T05:17:00.000Z |

(2 rows)

**Example: Move a table that is there to the minute: seconds of one minute fold into the newest row** (sample data: sample)

Setup:

```sql
CREATE TABLE ticks_1m (time TIMESTAMP, symbol SYMBOL, close DOUBLE)
  TIMESERIES(time) PARTITION BY DAY DEDUP KEY (symbol, time);
INSERT INTO ticks_1m VALUES ('2026-09-25T11:01:07+05:45', 'CITY', 510.0), ('2026-09-25T11:01:42+05:45', 'CITY', 512.5);
```

```sql
ALTER TABLE ticks_1m ADD COLUMN minute TIMESTAMP GENERATED ALWAYS AS (date_trunc('minute', time)) STORED;
ALTER TABLE ticks_1m DEDUP ENABLE UPSERT KEYS (symbol, minute);
SELECT time, close FROM ticks_1m;
```

Result:

`ALTER TABLE ticks_1m ADD COLUMN minute TIMESTAMP GENERATED ALWAYS AS (date_trunc('minute', time)) ST`

```text
table 'ticks_1m' altered (2 row change(s) written)
```

`ALTER TABLE ticks_1m DEDUP ENABLE UPSERT KEYS (symbol, minute)`

```text
table 'ticks_1m' now dedups on (symbol, minute) (1 row(s) rewritten, 1 duplicate row(s) folded: the newest row of each key was kept)
```

`SELECT time, close FROM ticks_1m`

| time (TIMESTAMP) | close (DOUBLE) |
|---|---|
| 2026-09-25T05:16:42.000Z | 512.5 |

(1 row)

**Example: An hour is too coarse to stand in for the time** (sample data: sample; shows an error)

```sql
CREATE TABLE candle_1h (time TIMESTAMP, symbol SYMBOL, close DOUBLE,
    hour TIMESTAMP GENERATED ALWAYS AS (date_trunc('hour', time)) STORED)
  TIMESERIES(time) PARTITION BY DAY DEDUP KEY (symbol, hour);
```

Result:

Error: `DEDUP KEY must include the time column 'time', e.g. DEDUP KEY (symbol, time), or a column GENERATED ALWAYS AS (date_trunc('minute', time)) STORED`

<a id="dedup-insert"></a>

## A plain INSERT that replaces: dedup_insert

Syntax:

```sql
CREATE TABLE name (...) TIMESERIES(time) ... DEDUP KEY (...) WITH (dedup_insert = 'upsert')
ALTER TABLE name SET (dedup_insert = 'upsert')    -- a plain INSERT replaces the row with the same key
ALTER TABLE name SET (dedup_insert = 'error')     -- back to the default: it fails
ALTER TABLE name RESET (dedup_insert)             -- the same as 'error'
```

In QuestDB a plain `INSERT` into a `DEDUP UPSERT KEYS` table replaces the row with the same key. On a table made with KDB's own `DEDUP KEY (...)` it fails, so you do not overwrite a row by mistake. A table made with QuestDB's words, `DEDUP UPSERT KEYS (...)`, gets QuestDB's behaviour: `dedup_insert = 'upsert'` is set by itself (since 2026-09-25), so an app written for QuestDB keeps its plain `INSERT`s unchanged. Any table can switch with `ALTER TABLE ... SET (dedup_insert = ...)`.

| The table was made with | A plain `INSERT` of a key that is there |
|---|---|
| `DEDUP KEY (...)` | fails (`dedup_insert = 'error'`) |
| `DEDUP UPSERT KEYS (...)` (QuestDB) | replaces the row (`dedup_insert = 'upsert'`) |
| `DEDUP UPSERT KEYS (...) WITH (dedup_insert = 'error')` | fails |

| `dedup_insert` | A plain `INSERT` of a key that is there |
|---|---|
| `'error'` (default) | fails: `a row with ... already exists` (`23505`) |
| `'upsert'` | replaces the whole row, like `INSERT OR REPLACE` |

- **Returns:** `table 'name': a plain INSERT of a DEDUP KEY that is there replaces the row (dedup_insert = 'upsert')`.
- **Notes:**
  - Only a table with a `DEDUP KEY` can have it. A table with a `PRIMARY KEY` takes `INSERT OR REPLACE` or `INSERT ... ON CONFLICT`.
  - It works for every way rows come in: SQL `INSERT`, a PostgreSQL `COPY`, `POST /write` and `/imp`.
  - `INSERT OR IGNORE` still skips, and `INSERT ... ON CONFLICT` still does what it says.
  - `SHOW CREATE TABLE` shows it as `WITH (dedup_insert = 'upsert')`. `DEDUP DISABLE` turns it off with the key.
  - A table made with `DEDUP UPSERT KEYS` before 2026-09-25 keeps the rule it had (fails); `ALTER TABLE t SET (dedup_insert = 'upsert')` changes it. `ALTER TABLE t DEDUP ENABLE UPSERT KEYS (...)` does not change it.
  - New rows cost nothing extra: the setting is looked at only when a key is already there.
  - A database with such a table needs KDB 2026-09-24 or newer (feature `dedup_insert`, see [versions](versions.md)).

**Example: A price feed written for QuestDB: plain INSERTs replace the tick** (sample data: sample)

Setup:

```sql
CREATE TABLE ltp (time TIMESTAMP, symbol SYMBOL, price DOUBLE)
  TIMESERIES(time) PARTITION BY DAY DEDUP KEY (symbol, time) WITH (dedup_insert = 'upsert');
```

```sql
INSERT INTO ltp VALUES ('2026-09-24T11:00:00+05:45', 'CITY', 510.0);
INSERT INTO ltp VALUES ('2026-09-24T11:00:00+05:45', 'CITY', 512.5), ('2026-09-24T11:01:00+05:45', 'CITY', 513.0);
SELECT * FROM ltp;
```

Result:

`INSERT INTO ltp VALUES ('2026-09-24T11:00:00+05:45', 'CITY', 510.0)`

```text
1 row(s) inserted
```

`INSERT INTO ltp VALUES ('2026-09-24T11:00:00+05:45', 'CITY', 512.5), ('2026-09-24T11:01:00+05:45', '`

```text
1 row(s) inserted, 1 replaced
```

`SELECT * FROM ltp`

| time (TIMESTAMP) | symbol (SYMBOL) | price (DOUBLE) |
|---|---|---|
| 2026-09-24T05:15:00.000Z | CITY | 512.5 |
| 2026-09-24T05:16:00.000Z | CITY | 513 |

(2 rows)

**Example: Turn it on for a table that is there** (sample data: sample)

Setup:

```sql
CREATE TABLE ltp (time TIMESTAMP, symbol SYMBOL, price DOUBLE)
  TIMESERIES(time) PARTITION BY DAY DEDUP KEY (symbol, time);
INSERT INTO ltp VALUES ('2026-09-24T11:00:00+05:45', 'CITY', 510.0);
```

```sql
ALTER TABLE ltp SET (dedup_insert = 'upsert');
INSERT INTO ltp VALUES ('2026-09-24T11:00:00+05:45', 'CITY', 511.0);
SELECT * FROM ltp;
```

Result:

`ALTER TABLE ltp SET (dedup_insert = 'upsert')`

```text
table 'ltp': a plain INSERT of a DEDUP KEY that is there replaces the row (dedup_insert = 'upsert')
```

`INSERT INTO ltp VALUES ('2026-09-24T11:00:00+05:45', 'CITY', 511.0)`

```text
0 row(s) inserted, 1 replaced
```

`SELECT * FROM ltp`

| time (TIMESTAMP) | symbol (SYMBOL) | price (DOUBLE) |
|---|---|---|
| 2026-09-24T05:15:00.000Z | CITY | 511 |

(1 row)

**Example: A table without a DEDUP KEY cannot have it** (sample data: sample; shows an error)

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, balance DOUBLE);
```

```sql
ALTER TABLE accounts SET (dedup_insert = 'upsert');
```

Result:

Error: `dedup_insert = 'upsert' needs a DEDUP KEY, and table 'accounts' has none (a table with a PRIMARY KEY takes INSERT OR REPLACE or INSERT ... ON CONFLICT)`

<a id="compression"></a>

## Packed partitions: compression

Syntax:

```sql
CREATE TABLE name (...) TIMESERIES(time) PARTITION BY DAY ... WITH (compression = on)
ALTER TABLE name SET (compression = on)     -- sealed partitions are stored packed
ALTER TABLE name SET (compression = off)    -- back to the default: stored as plain arrays
ALTER TABLE name RESET (compression)        -- the same as off
COMPRESS TABLE name                         -- how far it is; packs what is left, in the background
COMPRESS TABLE name WAIT                    -- packs what is left now, then answers
```

A partition is **sealed** when a newer time bucket exists: yesterday's day, last month's month. Only sealed partitions are packed. The newest one is where rows still arrive, so it stays plain and quick to write again. A packed file keeps the same rows in far fewer bytes: times and ids that go up by small steps, broker numbers, sorted symbols and prices with a few decimals take 1 to 3 bytes instead of 8.

| Measured (a floorsheet-shaped table, 3,000,000 rows, 60 days) | plain | packed |
|---|---|---|
| bytes a row on disk | 76.1 | 15.5 |
| first `GROUP BY symbol, buyer` after a start (reads every file), 1 thread | 433 ms | 368 ms |
| the same with a small memory budget (files read again and again), 1 thread | 316 ms | 183 ms |
| the same with every partition in memory | 96 ms | 98 ms (the same work) |

- **Returns:** `ALTER TABLE` says what it does. `COMPRESS TABLE` answers with one row:

| Column | Meaning |
|---|---|
| `partitions`, `sealed`, `packed` | partitions with a file, how many are sealed, how many files are packed |
| `to_do` | partitions still to write again: sealed plain ones while `on`, packed ones while `off` |
| `rows`, `file_bytes`, `bytes_per_row` | the saved rows and the bytes of their files |

- **Notes:**
  - It is **off** by default. Nothing changes for a table until you turn it on.
  - Queries answer exactly the same: a packed file is unpacked into the same arrays when it is loaded. Loading reads fewer bytes, so it is often faster; with every partition in memory the speed is the same.
  - After `SET (compression = on)` the partitions already on disk are packed in the background, one partition at a time, with a pause after each one, while reads and writes go on. Run `COMPRESS TABLE name` again to see how far it is. `SET (compression = off)` unpacks them the same way.
  - When the first rows of a new day arrive, yesterday becomes sealed. The server packs it in the background after its next save, with no `COMPRESS TABLE` and no restart.
  - Rows added to a sealed day later (a late load, `UPDATE`, `DELETE`) are fine: the day is written packed again with them.
  - A crash in the middle loses nothing: a packed file replaces the old one only once it is complete, like every file KDB writes.
  - A table without time partitions has no sealed partition, so nothing is packed.
  - A database that has used it needs KDB 2026-09-25 or newer (feature `column_compression`, see [versions](versions.md)). An older KDB refuses it with "needs a newer KDB", never misreads it. [kdb downgrade](versions.md#downgrade) writes packed files plain again once the table is set to `off`.

**Example: Pack the old days of a trade table** (sample data: sample)

Setup:

```sql
CREATE TABLE trades (time TIMESTAMP, symbol SYMBOL, qty LONG, price DOUBLE)
  TIMESERIES(time) PARTITION BY DAY;
INSERT INTO trades VALUES ('2026-09-21T10:00:00Z', 'NABIL', 100, 512.5), ('2026-09-21T10:01:00Z', 'NABIL', 20, 513.0),
  ('2026-09-22T10:00:00Z', 'CITY', 50, 99.5), ('2026-09-23T10:00:00Z', 'NABIL', 10, 515.0);
```

```sql
ALTER TABLE trades SET (compression = on);
COMPRESS TABLE trades WAIT;
SELECT symbol, sum(qty), max(price) FROM trades GROUP BY symbol;
```

Result:

`ALTER TABLE trades SET (compression = on)`

```text
table 'trades': sealed partitions are stored packed (compression = on); the sealed partitions on disk are written again in the background (COMPRESS TABLE trades shows how far, COMPRESS TABLE trades WAIT does it now)
```

`COMPRESS TABLE trades WAIT`

| table (STRING) | compression (STRING) | partitions (LONG) | sealed (LONG) | packed (LONG) | to_do (LONG) | rows (LONG) | file_bytes (LONG) | bytes_per_row (DOUBLE) |
|---|---|---|---|---|---|---|---|---|
| trades | on | 3 | 2 | 2 | 0 | 4 | 2031 | 507.75 |

(1 row)

```text
table 'trades': 2 sealed partition(s) written packed
```

`SELECT symbol, sum(qty), max(price) FROM trades GROUP BY symbol`

| symbol (SYMBOL) | sum(qty) (LONG) | max(price) (DOUBLE) |
|---|---|---|
| NABIL | 130 | 515 |
| CITY | 50 | 99.5 |

(2 rows)

**Example: compression takes on or off** (sample data: sample; shows an error)

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
```

```sql
ALTER TABLE ticks SET (compression = small);
```

Result:

Error: `line 1, column 24: compression takes on (sealed partitions are stored packed) or off (the default)`

<a id="tail-files"></a>

## Appending without rewriting: tail files

Syntax:

```sql
kdb serve --tail-files on       -- or KDB_TAIL_FILES=on; off by default
```

Every save (checkpoint) used to write each changed partition whole. On `PARTITION BY YEAR, SYMBOL(symbol)` one more month of candles wrote each symbol's whole year again, and a live feed touching every symbol wrote every year file again at each save. Most of the bytes written, and kept in the trash, were rows already on disk.

With tail files on, a partition whose new rows all come **after** its last saved row gets them in a small extra file, a **tail**, next to its file. Its file is not read or written. Reads put the file and its tails together, so every query answers exactly the same.

| What changed in the partition since the last save | What the save writes |
|---|---|
| only new rows, all after the last saved key (next minute, next month) | one tail file with just those rows |
| an `UPDATE` or `DELETE` of a saved row, an upsert of an existing key, a late row before the end | a [delta file](#delta-files) when the changes are few, else the whole partition (and its tails go) |
| it has 8 tails already, or its tails reach a quarter of its file | the whole partition, once, and its tails go |

- **Notes:**
  - It is **off** by default while it is new. Nothing changes until you turn it on.
  - "After the last saved row" is in the table's key order (`SORT BY`, or time then row id): for `SORT BY (symbol, time)` in a `SYMBOL(symbol)` partition, a later time.
  - A crash in the middle loses nothing: a tail is listed only once it is complete, like every file KDB writes. A tail cut short by a power cut was never listed, and the next start removes it.
  - Folding the tails back into the file is an ordinary save too: a crash during it leaves the file and its tails as they were.
  - Backups, restores, branches, the trash and `kdb info` see tails as ordinary files. Encryption at rest and column compression cover them like any file (a packed, sealed partition is written whole, never given a tail).
  - `kdb check` also checks that every tail sits behind its partition file, numbered 1, 2, 3 ... with none missing, and is no older than what it extends.
  - [GET /api/disk](http-server-info.md#api-disk) and the console's [Keep data](console-keep-data.md#disk) page show how much of the data is in tails (`tail_bytes`, `tail_files`).
  - A read `AS OF` an earlier time reads the tails that existed then. When a partition is written whole and its tails go, reads `AS OF` a time before that are refused for the table, as after `TRUNCATE`.
  - Turned off again, existing tails are still read; the next change of such a partition writes it whole.
  - A database with tail files needs KDB 2026-10-02 or newer (feature `partition_tails`, see [versions](versions.md)). An older KDB refuses it with "needs a newer KDB". [kdb downgrade](versions.md#downgrade) writes those partitions whole again first and says how many it folded.

<a id="delta-files"></a>

## Small changes without rewriting: delta files

Syntax:

```sql
KDB_NO_PARTITION_DELTA=1        -- turns them off: every change writes the whole partition again
```

An `UPDATE`, a `DELETE` or an `INSERT OR REPLACE` of a few rows used to make the next save write the whole partition again. One replaced row in a day of a million rows wrote the whole day, and the old day went to the trash. Do that a hundred times and the trash holds a hundred days.

Now, when the changes of a partition are a **small share** of its rows, the save writes them to one small extra file next to it, its **delta**: the rows replaced, updated or added, and the keys deleted. The partition's file (and its [tails](#tail-files)) stay as they are. Reads apply the delta, so every query answers exactly the same.

| What changed in the partition since it was last written whole | What the save writes |
|---|---|
| replaced, updated, new and deleted rows, together at most 1/16 of its rows | its delta again, with all those rows (a few hundred bytes for one row) |
| more than that | the whole partition, and its delta goes |
| a delta file bigger than 1/8 of the partition's files, or delta bytes written since the last whole write more than the partition's files (one key replaced again and again) | the whole partition, and its delta goes: **compaction** |
| a sealed partition of a table with `compression = on` whose file is not packed yet | the whole partition, packed |

- **Notes:**
  - It is **on** by default. `KDB_NO_PARTITION_DELTA=1` in the server's environment turns it off.
  - Each save writes the partition's delta again with everything in it so far, so a partition has one delta, and the bytes written and trashed are those of the changed rows, not of the partition.
  - A partition that is not in memory is still read once for the save (its new row count and summary come from its rows); only the writing is saved.
  - Compaction keeps the cost bounded: the delta bytes a partition writes before it is written whole again are about the size of the partition, never many times it. The count survives a restart.
  - `/api/stats` counts `partition_whole_writes` / `partition_whole_bytes` and `partition_delta_writes` / `partition_delta_bytes` since the start. `GET /api/disk` and the `disk` part of `/api/stats` show `delta_files` / `delta_bytes`, the delta files on disk now (part of `data_bytes`).
  - A power cut during a save loses nothing confirmed: a new delta, or the whole file that replaces it, is used only once the manifest names it, and both change in one manifest save.
  - A partition with a delta is always read whole: a [per-column load](databases.md#per-column-loads) would miss the replaced rows. Its next whole write makes it per-column again.
  - Backups, the trash and `kdb info` see a delta as an ordinary file. `kdb check` also reads every partition with a delta and reports one that does not fit its file (made for other rows, keys out of order, a row count other than the saved one) or that has no partition file.
  - A read `AS OF` an earlier time reads the delta that existed then. When the partition is written whole and its delta goes, reads `AS OF` a time before that are refused for the table, as for tails.
  - A database with delta files needs KDB 2026-10-02 or newer (feature `partition_deltas`, see [versions](versions.md)). An older KDB refuses it with "needs a newer KDB". [kdb downgrade](versions.md#downgrade) writes those partitions whole again first.

<a id="load-dedup"></a>

## How a load finds duplicates

A load over [POST /write](line-protocol.md#post-write) or [POST /imp](http-import.md) builds its rows as columns and writes them in one piece per partition. How much work the duplicate check is depends on the keys:

| Table | A partition that has no rows yet | A partition that has rows |
|---|---|---|
| no `DEDUP KEY` | nothing to check | nothing to check: every row is added |
| every `SORT BY` column is in the `DEDUP KEY` (`SORT BY (symbol, time) DEDUP KEY (symbol, time)`) | nothing to check | nothing to look up: the key decides the place, so a row sent again lands on the old one |
| the `DEDUP KEY` has columns the `SORT BY` does not start with (`SORT BY (symbol, id) DEDUP KEY (date, id)`) | only repeats inside the load | the whole load is checked against the stored keys **at once**; a stored row with the same key is replaced |

- **Notes:**
  - Some tables still go row by row, which is several times slower: a table with an immediate `INSERT` [trigger](triggers.md), a `CHECK`, `REFERENCES`, a `UNIQUE` column or index, an `AUTO` column, or a `BEFORE UPDATE` row trigger. A trigger on **another** table does not slow the load. For a table you load in bulk, make its triggers [DEFERRED](triggers.md#deferred).
  - A table with no `DEDUP KEY` is as fast to load as one with a key.
  - `KDB_NO_BATCH_DEDUP=1` (read at start) turns the at-once check off: such partitions then go row by row. It is only for comparing the two ways.
  - SQL `INSERT` statements check key by key as described in [DEDUP KEY](partitions-and-dedup.md#dedup-key); the result is the same.

<a id="dedup-skip"></a>

## Loads without the duplicate check: dedup=skip

Syntax:

```sql
POST /write?...&dedup=skip
POST /imp?...&dedup=skip
```

A load normally looks up every key in its day, so a day sent again replaces its rows. With `dedup=skip` the load **does not look**. Use it only for trusted bulk loads where you know the rows are new.

It matters only for a table whose `DEDUP KEY` is not the start of its `SORT BY` (the last row of the [table above](partitions-and-dedup.md#load-dedup)). For the other tables a load never looks anything up.

| | `dedup=on` (default) | `dedup=skip` |
|---|---|---|
| a new day | no lookups, fast | the same |
| a day that has rows | the load's keys checked against that day's keys at once | no check: faster |
| the same key twice in one load | the last row stays | the same |
| a key that is already stored | replaced | **may be there twice** |

- **The risk:** if a key already exists, you get **two rows with the same key**. Queries then return both. A row with the same key **and** the same `SORT BY` values still replaces the old one; one with other `SORT BY` values (another symbol) is added next to it.
- Rights: the same as a normal write.
- The activity log says `dedup skipped`, and the event has `dedup_skipped`: the rows that went into days which already had rows.
- A table that goes row by row anyway (an immediate `INSERT` trigger, `CHECK`, `REFERENCES`, a `UNIQUE` column or index, an `AUTO` column) checks every key: `dedup=skip` does nothing there.
- `dedup=skip` cannot be used with `upsert=merge`.

<a id="dedup-skip-sql"></a>

### The same in SQL: WITH (dedup = skip) and SET dedup

Syntax:

```sql
INSERT INTO table ... WITH (dedup = skip | on)     -- this statement only
SET dedup = skip | on | DEFAULT                     -- every INSERT and COPY FROM of this session
SHOW dedup                                          -- skip or on
RESET dedup                                         -- back to on
```

The words are those of `?dedup=`. `skip` means: **do not look the key up among the stored rows**. A plain `INSERT` of a stored key then does not fail. Repeats inside the statement are still found.

Which value counts, first match wins:

| Where it is set | Notes |
|---|---|
| 1. the statement's `WITH (dedup = ...)` | `on` looks up even in a `skip` session |
| 2. the session's `SET dedup` | an HTTP session or a PostgreSQL connection; `SET LOCAL dedup` lasts until the transaction ends |
| 3. the table | `on`: every key is looked up |

- **Returns:** the usual message, then `; dedup = skip: N key(s) not looked up among the stored rows`.
- **Notes:**
  - A stored key written again with `skip`: when the key is the whole `SORT BY`, the new row lands on the old one and replaces it. Otherwise the key is **there twice**. Repair it with [DEDUP TABLE](partitions-and-dedup.md#dedup-table).
  - `INSERT OR IGNORE`, `INSERT OR REPLACE` and `ON CONFLICT` need the lookup: with `WITH (dedup = skip)` they are refused, and a session's `skip` does not count for them.
  - The same tables as `?dedup=skip` ignore it: an immediate `INSERT` trigger, `REFERENCES`, a `UNIQUE` column or index, an `AUTO` column, a `BEFORE UPDATE` row trigger. A `CHECK` is fine.
  - A PostgreSQL `COPY ... FROM STDIN` takes the connection's `SET dedup` too.
  - A statement run by a trigger or a function for the `INSERT` does not take the session's `skip`.

**Example: A day you know is new: write it without the lookups** (sample data: sample)

Setup:

```sql
CREATE TABLE fills (date TIMESTAMP, id LONG, symbol SYMBOL, qty LONG)
  TIMESERIES(date) PARTITION BY DAY SORT BY (symbol, id) DEDUP KEY (date, id);
INSERT INTO fills VALUES ('2026-09-11', 1, 'CITY', 10);
```

```sql
INSERT INTO fills VALUES ('2026-09-12', 1, 'CITY', 11), ('2026-09-12', 2, 'COAST', 20) WITH (dedup = skip);
SELECT date, id, symbol, qty FROM fills ORDER BY date, id;
```

Result:

`INSERT INTO fills VALUES ('2026-09-12', 1, 'CITY', 11), ('2026-09-12', 2, 'COAST', 20) WITH (dedup =`

```text
2 row(s) inserted; dedup = skip: 2 key(s) not looked up among the stored rows
```

`SELECT date, id, symbol, qty FROM fills ORDER BY date, id`

| date (TIMESTAMP) | id (LONG) | symbol (SYMBOL) | qty (LONG) |
|---|---|---|---|
| 2026-09-11T00:00:00.000Z | 1 | CITY | 10 |
| 2026-09-12T00:00:00.000Z | 1 | CITY | 11 |
| 2026-09-12T00:00:00.000Z | 2 | COAST | 20 |

(3 rows)

**Example: A session that skips, a key sent twice by mistake, and the repair** (sample data: sample)

Setup:

```sql
CREATE TABLE fills (date TIMESTAMP, id LONG, symbol SYMBOL, qty LONG)
  TIMESERIES(date) PARTITION BY DAY SORT BY (symbol, id) DEDUP KEY (date, id);
INSERT INTO fills VALUES ('2026-09-11', 1, 'CITY', 10);
```

```sql
SET dedup = skip;
SHOW dedup;
INSERT INTO fills VALUES ('2026-09-11', 1, 'COAST', 12);
SELECT count(*) AS rows_for_id_1 FROM fills WHERE id = 1;
DEDUP TABLE fills FOR '2026-09-11';
RESET dedup;
SELECT id, symbol, qty FROM fills;
```

Result:

`SET dedup = 'skip'`

```text
INSERTs and COPY FROM of this session do not look keys up among the stored rows (dedup = skip); a key that is stored already is then overwritten or there twice, DEDUP TABLE repairs it
```

`SHOW dedup`

| dedup (STRING) |
|---|
| skip |

(1 row)

`INSERT INTO fills VALUES ('2026-09-11', 1, 'COAST', 12)`

```text
1 row(s) inserted; dedup = skip: 1 key(s) not looked up among the stored rows
```

`SELECT count(*) AS rows_for_id_1 FROM fills WHERE id = 1`

| rows_for_id_1 (LONG) |
|---|
| 2 |

(1 row)

`DEDUP TABLE fills FOR '2026-09-11'`

```text
1 duplicate row(s) removed from 1 of 1 partition(s) of 'fills'
```

`SET dedup = 'default'`

```text
INSERTs of this session look every key up again (dedup = on)
```

`SELECT id, symbol, qty FROM fills`

| id (LONG) | symbol (SYMBOL) | qty (LONG) |
|---|---|---|
| 1 | COAST | 12 |

(1 row)

**Example: OR IGNORE needs the lookup** (sample data: sample; shows an error)

Setup:

```sql
CREATE TABLE fills (date TIMESTAMP, id LONG, symbol SYMBOL, qty LONG)
  TIMESERIES(date) PARTITION BY DAY SORT BY (symbol, id) DEDUP KEY (date, id);
```

```sql
INSERT OR IGNORE INTO fills VALUES ('2026-09-11', 1, 'CITY', 10) WITH (dedup = skip);
```

Result:

Error: `line 1, column 66: INSERT OR IGNORE cannot be used with WITH (dedup = skip): it looks every key up, and skip means no lookup`

<a id="dedup-table"></a>

## DEDUP TABLE

Syntax:

```sql
DEDUP TABLE table [FOR 'time']
```

Removes rows that repeat a `DEDUP KEY`. Of the rows with the same key, the one written **last** stays, as a normal load would have kept it. Use it to repair a load made with `dedup=skip`.

| Part | Meaning |
|---|---|
| `table` | a time-series table with a `DEDUP KEY` |
| `FOR 'time'` | only the partition that holds this time, like `'2026-09-11'`. Without it: every partition. |

- **Returns:** `N duplicate row(s) removed from X of Y partition(s) of 'table'`.
- **Notes:**
  - It is a `DELETE` of the extra rows: it needs the same rights, runs `DELETE` triggers, and is saved like any change.
  - Without `FOR` it reads the whole table. Give the day when you know it.

**Example: Repair a day: nothing to remove in a table loaded normally** (sample data: sample)

Setup:

```sql
CREATE TABLE fills (date TIMESTAMP, id LONG, symbol SYMBOL, qty LONG)
  TIMESERIES(date) PARTITION BY DAY SORT BY (symbol, id) DEDUP KEY (date, id);
INSERT OR REPLACE INTO fills VALUES ('2026-09-11', 1, 'CITY', 10), ('2026-09-11', 2, 'COAST', 20);
```

```sql
DEDUP TABLE fills FOR '2026-09-11';
SELECT id, symbol, qty FROM fills ORDER BY id;
```

Result:

`DEDUP TABLE fills FOR '2026-09-11'`

```text
0 duplicate row(s) removed from 0 of 1 partition(s) of 'fills'
```

`SELECT id, symbol, qty FROM fills ORDER BY id`

| id (LONG) | symbol (SYMBOL) | qty (LONG) |
|---|---|---|
| 1 | CITY | 10 |
| 2 | COAST | 20 |

(2 rows)

**Example: DEDUP TABLE needs a DEDUP KEY** (sample data: sample; shows an error)

```sql
CREATE TABLE raw (time TIMESTAMP, v LONG) TIMESERIES(time) PARTITION BY DAY;
DEDUP TABLE raw;
```

Result:

```text
table 'raw' created
```

Error: `DEDUP TABLE needs a time-series table with a DEDUP KEY; 'raw' has none`

<a id="drop-partition"></a>

## DROP PARTITION

Syntax:

```sql
ALTER TABLE table DROP PARTITION 'name' [, 'name' ...]
ALTER TABLE table DROP PARTITION OLDER THAN n HOURS | DAYS | WEEKS | MONTHS | YEARS
```

Deletes whole partitions: all rows of a day, month or year at once. It removes files, so it is much faster than `DELETE` for old data. `OLDER THAN` picks the partitions whose last moment is more than that long ago ([alter-table](alter-table.md#drop-partition)); a [TTL](alter-table.md#set-ttl) does the same by itself.

| Argument | Type | Meaning |
|---|---|---|
| `'name'` | text in single quotes | the partition: `'2026'` (YEAR), `'2026-09'` (MONTH), `'2026-09-10'` (DAY) |

- **Returns:** `N partition(s) of 'table' dropped`.
- **Notes:**
  - The name must be a partition that exists. If not, the error **lists the partitions** the table has. That is an easy way to see them.
  - The name is a UTC date (see [PARTITION BY](partitions-and-dedup.md#partition-by)).
  - All names are checked first. When one is wrong, nothing is dropped.
  - Not for relational tables and not for `PARTITION BY NONE` tables. There, use `DELETE FROM table WHERE ...`.
  - QuestDB's `DROP PARTITION LIST '2026-09'` works too (with `LIST` a partition that is not there is skipped, as in QuestDB), and so does `DROP PARTITION WHERE time < '2026-09-01'`, which drops each partition whose whole time range matches ([alter-table](alter-table.md#drop-partition)).
  - There is no undo. Make a backup first when the data matters.
  - `DELETE FROM t WHERE time IN '2025'` removes the same rows, one by one (slower, but works for any condition).
  - With [SYMBOL(col)](partitions-and-dedup.md#partition-by-symbol) partitions, the name is the time part: `'2025'` drops every symbol of 2025.
  - To empty the whole table fast, use [TRUNCATE](update-delete.md#truncate): it drops every partition the same way.

**Example: Delete the 2025 daily candles** (sample data: sample)

```sql
SELECT count(*) AS rows_2025 FROM ochl_day WHERE time IN '2025';
ALTER TABLE ochl_day DROP PARTITION '2025';
SELECT count(*) AS rows_2025 FROM ochl_day WHERE time IN '2025';
```

Result:

`SELECT count(*) AS rows_2025 FROM ochl_day WHERE time IN '2025'`

| rows_2025 (LONG) |
|---|
| 12 |

(1 row)

`ALTER TABLE ochl_day DROP PARTITION '2025'`

```text
1 partition(s) of 'ochl_day' dropped
```

`SELECT count(*) AS rows_2025 FROM ochl_day WHERE time IN '2025'`

| rows_2025 (LONG) |
|---|
| 0 |

(1 row)

**Example: Trade log: delete two days at once** (sample data: sample)

```sql
ALTER TABLE trade_log DROP PARTITION '2026-09-09', '2026-09-10';
SELECT count(*) AS trades_left FROM trade_log;
```

Result:

`ALTER TABLE trade_log DROP PARTITION '2026-09-09', '2026-09-10'`

```text
2 partition(s) of 'trade_log' dropped
```

`SELECT count(*) AS trades_left FROM trade_log`

| trades_left (LONG) |
|---|
| 0 |

(1 row)

**Example: A wrong name: the message lists the partitions** (sample data: sample; shows an error)

```sql
ALTER TABLE ochl_day DROP PARTITION '2026-09';
```

Result:

Error: `table 'ochl_day' has no partition '2026-09'; partitions: 2025, 2026`

**Example: The name needs quotes** (sample data: sample; shows an error)

```sql
ALTER TABLE ochl_day DROP PARTITION 2025;
```

Result:

Error: `line 1, column 37: expected a partition value in single quotes, e.g. '2026-09' but found '2025'`

**Example: Relational tables have no partitions** (sample data: sample; shows an error)

```sql
ALTER TABLE brokers DROP PARTITION '2026';
```

Result:

Error: `cannot drop partitions of table 'brokers': it is a relational table; only time-series tables have partitions`
