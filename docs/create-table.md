# CREATE TABLE

> Make a relational or a time-series table, with partitions, sort order, a dedup key, rounded times and computed columns, or make one from a query with CREATE TABLE ... AS.

- Category: Tables
- Keywords: create table, new table, IF NOT EXISTS, TEMP TABLE, TEMPORARY, UNLOGGED, table options, relational table, time-series table, timeseries table, RECORDS, TIMESERIES, PARTITION BY, DAY, MONTH, YEAR, NONE, SYMBOL(col), SORT BY, DEDUP KEY, DEDUP UPSERT KEYS, TIMESTAMP(col), WAL, CREATE TABLE AS, CREATE TABLE ... AS SELECT, AS SELECT, WITH NO DATA, copy a table, deduplication, ROUND, round time, computed column, generated column, GENERATED ALWAYS, STORED, stored generated column, virtual column, AS, schema, design, ttl\_column, row TTL, expire, EXPIRE, expires\_at, per-row TTL, key expiry, redis, session table, rate limit, max\_bytes, evict, durability, cache table, LRU, eviction, maxmemory, kv\_memory, volatile\_ttl
- See also: [Column types](column-types.md), [Constraints](constraints.md), [ALTER, RENAME and DROP TABLE](alter-table.md), [SHOW TABLES, COLUMNS, CREATE TABLE](show-tables.md), [INSERT](insert.md), [Partitions, SORT BY and DEDUP KEY](partitions-and-dedup.md), [Indexes](indexes.md)

`CREATE TABLE` makes a new table. KDB has **two kinds** of tables:

| | Relational table | Time-series table |
|---|---|---|
| Holds | lists of things: users, accounts, brokers, posts | rows with a time: candles, trades, live prices |
| Written as | `CREATE TABLE t (...)` | `CREATE TABLE t (...) TIMESERIES(time_column)` |
| Duplicate check | `PRIMARY KEY`, `UNIQUE` | `DEDUP KEY (..., time)` |
| Split into files | no | `PARTITION BY DAY`, `MONTH`, `YEAR` or `NONE` |

Simple rule: **if every row has a time and many new rows come every day, use a time-series table.** You cannot change the kind, the partitions or the sort order later, so choose carefully before you load big data. The dedup key can be changed later, but that rewrites every row ([DEDUP ENABLE](alter-table.md#dedup-enable)).

**Example: Daily stock candles: a time-series table**

```sql
CREATE TABLE ochl_day (
  time   TIMESTAMP ROUND 1d,
  symbol SYMBOL,
  open   DOUBLE,
  high   DOUBLE,
  low    DOUBLE,
  close  DOUBLE,
  volume DOUBLE
) TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (symbol, time);
```

Result:

```text
table 'ochl_day' created
```

<a id="create-table"></a>

## CREATE TABLE

Syntax:

```sql
CREATE TABLE [IF NOT EXISTS] name (
  column TYPE [PRIMARY KEY [AUTO]] [NOT NULL] [UNIQUE] [DEFAULT expr]
              [REFERENCES table(column)] [ROUND interval] [AS (expr) | GENERATED ALWAYS AS (expr) STORED]
              [[CONSTRAINT name] CHECK (condition)],
  ...
  [, [CONSTRAINT name] CHECK (condition) ...]
)
[TIMESERIES(time_column)]
[PARTITION BY DAY | MONTH | YEAR | NONE [, SYMBOL(column)]]
[SORT BY (column, ...)]
[DEDUP KEY (column, ...)]
[TTL n HOURS | DAYS | WEEKS | MONTHS | YEARS]
[RECORDS]
[WITH (ttl_column = column)]
```

Makes a table with at least one column. The table options after `)` can come in any order, each at most once.

| Part | Meaning |
|---|---|
| `IF NOT EXISTS` | a table with this name is already there: do nothing, no error (the old table is **not** changed) |
| `name` | the table name; see [names](sql-basics.md#names) |
| `column TYPE` | a column and its [type](column-types.md) |
| column rules | `PRIMARY KEY`, `AUTO`, `NOT NULL`, `UNIQUE`, `DEFAULT`, `REFERENCES`, `CHECK`: see [constraints](constraints.md) |
| `TTL` | drop partitions older than this, by itself; see [SET TTL](alter-table.md#set-ttl) |
| `WITH (ttl_column = c)` | each row expires at the time in column `c`: see [rows that expire](#row-ttl) |
| `WITH (max_bytes = '64MB', evict = 'lru')` | a cache table: rows used longest ago go when it is full; see [cache tables](#cache-table) |
| `ROUND`, `AS (...)`, `GENERATED ... STORED` | see [ROUND](#round), [computed columns](#computed) and [stored generated columns](#generated) |
| table options | see the entries below |

- **Returns:** `table 'name' created`, or `table 'name' already exists` with `IF NOT EXISTS`.
- **Notes:** a view and a table cannot have the same name. `CREATE TABLE` cannot be used inside `BEGIN ... COMMIT`. To make a table from a query, see [CREATE TABLE ... AS](#create-table-as).
- **PostgreSQL:** `CREATE TEMP TABLE` makes a [temporary table](#temp-table). `CREATE UNLOGGED TABLE` is refused: every KDB table is written to the log.
- **QuestDB:** `TIMESTAMP(col)` means `TIMESERIES(col)`, `DEDUP UPSERT KEYS (...)` means `DEDUP KEY (...)` with `dedup_insert = 'upsert'` (a plain `INSERT` replaces the row, as in QuestDB), and `WAL` / `BYPASS WAL` are read and ignored. `col SYMBOL INDEX [CAPACITY n]`, and `INDEX(col [CAPACITY n])` after the column list, make an [index](indexes.md) on the column. A SYMBOL's `CAPACITY n`, `CACHE` and `NOCACHE` are read and ignored: KDB sizes its dictionaries itself.

**Example: App users: a relational table with keys and defaults**

```sql
CREATE TABLE users (
  id            LONG PRIMARY KEY AUTO,
  email         STRING NOT NULL UNIQUE,
  password_hash STRING NOT NULL,
  name          STRING,
  created       TIMESTAMP NOT NULL DEFAULT now()
);
SHOW COLUMNS FROM users;
```

Result:

`CREATE TABLE users (`

```text
table 'users' created
```

`SHOW COLUMNS FROM users`

| name (STRING) | type (STRING) | primary_key (BOOL) | not_null (BOOL) | computed (BOOL) | references (STRING) |
|---|---|---|---|---|---|
| id | LONG | true | false | false | NULL |
| email | STRING | false | true | false | NULL |
| password_hash | STRING | false | true | false | NULL |
| name | STRING | false | false | false | NULL |
| created | TIMESTAMP | false | true | false | NULL |

(5 rows)

**Example: An install script that can run many times**

```sql
CREATE TABLE IF NOT EXISTS brokers (id INT PRIMARY KEY, name STRING NOT NULL);
CREATE TABLE IF NOT EXISTS brokers (id INT PRIMARY KEY, name STRING NOT NULL);
```

Result:

`CREATE TABLE IF NOT EXISTS brokers (`

```text
table 'brokers' created
```

`CREATE TABLE IF NOT EXISTS brokers (`

```text
table 'brokers' already exists
```

**Example: The same name twice without IF NOT EXISTS** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
```

```sql
CREATE TABLE brokers (id INT PRIMARY KEY);
```

Result:

Error: `table 'brokers' already exists; expected a new table name, or CREATE TABLE IF NOT EXISTS`

<a id="temp-table"></a>

## Temporary tables: CREATE TEMP TABLE

Syntax:

```sql
CREATE [GLOBAL | LOCAL] TEMP | TEMPORARY TABLE name (...) [table options]
CREATE TEMP TABLE name AS query
```

A **temporary table** belongs to one session, as in PostgreSQL:

| | |
|---|---|
| Who sees it | only the session that made it. For every other session the name does not exist |
| A table of the same name | is hidden in that session while the temporary one exists; `DROP TABLE` of the temporary one shows it again |
| When it goes | when the session ends (the PostgreSQL connection closes, or the HTTP [session](http-sessions-and-cursors.md) ends). Without a session, at the end of the request. A server that stopped with sessions open drops their tables when it starts |
| What it is | an ordinary table under the name `pg_temp_<session>_<name>`: indexes, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE` and `ALTER TABLE` work as on any table |

- **Role:** `ddl`, like `CREATE TABLE`.
- **Notes:** `ON COMMIT DROP` and `ON COMMIT DELETE ROWS` are not supported; the table lives until the session ends.

**Example: A scratch table for one request: made, used, gone**

```sql
CREATE TEMP TABLE scratch (id INT, score DOUBLE);
INSERT INTO scratch VALUES (1, 0.5), (2, 0.9);
SELECT count(*) AS rows_now, max(score) AS best FROM scratch;
```

Result:

`CREATE TABLE pg_temp_4611686018427387904_scratch (`

```text
table 'pg_temp_4611686018427387904_scratch' created
```

`INSERT INTO pg_temp_4611686018427387904_scratch VALUES (1, 0.5), (2, 0.9)`

```text
2 row(s) inserted
```

`SELECT count(*) AS rows_now, max(score) AS best FROM pg_temp_4611686018427387904_scratch`

| rows_now (LONG) | best (DOUBLE) |
|---|---|
| 2 | 0.9 |

(1 row)

**Example: After the request, the name is gone** (shows an error)

Setup:

```sql
CREATE TEMP TABLE scratch2 (id INT);
```

```sql
SELECT * FROM scratch2;
```

Result:

Error: `line 1, column 15: table or view 'scratch2' does not exist`

**Example: UNLOGGED is refused** (shows an error)

```sql
CREATE UNLOGGED TABLE fast_scratch (id INT);
```

Result:

Error: `line 1, column 8: CREATE UNLOGGED TABLE is not supported: every KDB table is written to the log and kept. Use CREATE TABLE`

<a id="create-table-as"></a>

## CREATE TABLE ... AS

Syntax:

```sql
CREATE TABLE [IF NOT EXISTS] name [(column, ...)] AS query
    [TIMESERIES(time_column)] [PARTITION BY DAY | MONTH | YEAR | NONE]
    [SORT BY (column, ...)] [DEDUP KEY (column, ...)] [RECORDS]
CREATE TABLE name AS query WITH NO DATA
```

Makes a new table from the result of a query, and copies the rows in. The columns get the names and types of the query's columns. The query may be in brackets: `AS (SELECT ...)`.

| Part | Meaning |
|---|---|
| `(column, ...)` | new names for the first columns, in order |
| table options | as for `CREATE TABLE`; without `TIMESERIES` the new table is a relational table |
| `WITH NO DATA` | make the empty table only |

- **Returns:** `table 'name' created with N row(s)`.
- **Notes:**
  - A `SYMBOL` column of the query becomes `STRING`. Keys, `NOT NULL`, defaults, `CHECK` rules and indexes are **not** copied. Add them with [ALTER TABLE](alter-table.md) afterwards, or make the table first and `INSERT INTO t SELECT ...` (see [INSERT ... SELECT](insert.md#insert-select)).
  - `PARTITION BY ..., SYMBOL(col)` is not accepted here.
  - Two query columns with the same name are refused: name them with `AS`.

**Example: Copy one symbol's daily candles into a time-series table** (sample data: sample)

```sql
CREATE TABLE city_day AS
  SELECT time, close, volume FROM ochl_day WHERE symbol = 'CITY'
  TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (time);
SHOW CREATE TABLE city_day;
SELECT count(*) AS rows FROM city_day;
```

Result:

`CREATE TABLE city_day AS SELECT time, close, volume FROM ochl_day WHERE symbol = 'CITY'`

```text
table 'city_day' created with 19 row(s)
```

`SHOW CREATE TABLE city_day`

| create_sql (STRING) |
|---|
| CREATE TABLE city_day (   time TIMESTAMP,   close DOUBLE,   volume DOUBLE ) TIMESERIES(time) PARTITION BY YEAR SORT BY (time) DEDUP KEY (time) |

(1 row)

`SELECT count(*) AS rows FROM city_day`

| rows (LONG) |
|---|
| 19 |

(1 row)

**Example: A summary table with new column names**

Setup:

```sql
CREATE TABLE trades (symbol SYMBOL, qty LONG, rate DOUBLE);
INSERT INTO trades VALUES ('CITY', 10, 515.0), ('CITY', 20, 516.0), ('COAST', 5, 376.0);
```

```sql
CREATE TABLE turnover (symbol, amount) AS SELECT symbol, sum(qty * rate) FROM trades GROUP BY symbol;
SELECT * FROM turnover ORDER BY symbol;
```

Result:

`CREATE TABLE turnover (symbol, amount) AS SELECT symbol, sum(qty * rate) FROM trades GROUP BY symbol`

```text
table 'turnover' created with 2 row(s)
```

`SELECT * FROM turnover ORDER BY symbol`

| symbol (STRING) | amount (DOUBLE) |
|---|---|
| CITY | 15470 |
| COAST | 1880 |

(2 rows)

**Example: The same column name twice** (shows an error)

Setup:

```sql
CREATE TABLE trades (symbol SYMBOL, qty LONG);
```

```sql
CREATE TABLE bad AS SELECT symbol, qty, qty FROM trades;
```

Result:

Error: `the query of CREATE TABLE bad gives two columns named 'qty'; name them with AS`

<a id="relational"></a>

## Relational tables (RECORDS)

Syntax:

```sql
CREATE TABLE name (column TYPE [rules], ...) [RECORDS]
```

A table without `TIMESERIES` is a **relational** table. The word `RECORDS` says it explicitly; it changes nothing. Use relational tables for lists of things that you look up by a key and change often: users, accounts, the ledger, brokers, forum posts, news articles.

- Give it a `PRIMARY KEY`. Rows are kept in key order, so a lookup by key is fast.
- Without a key, every `INSERT` adds rows, also exact copies.
- For money, add rules like `CHECK (balance >= 0)`; see [CHECK](constraints.md#check).
- **Notes:** `PARTITION BY`, `SORT BY` and `DEDUP KEY` are only for time-series tables. `RECORDS` together with `TIMESERIES` is an error.

**Example: Accounting: accounts and a ledger with exact money**

```sql
CREATE TABLE accounts (
  id      INT PRIMARY KEY AUTO,
  owner   STRING NOT NULL,
  balance DECIMAL(2) NOT NULL DEFAULT 0
) RECORDS;

CREATE TABLE ledger (
  id           LONG PRIMARY KEY AUTO,
  from_account INT NOT NULL REFERENCES accounts(id),
  to_account   INT NOT NULL REFERENCES accounts(id),
  amount       DECIMAL(2) NOT NULL,
  created      TIMESTAMP DEFAULT now()
);
SHOW TABLES;
```

Result:

`CREATE TABLE accounts (`

```text
table 'accounts' created
```

`CREATE TABLE ledger (`

```text
table 'ledger' created
```

`SHOW TABLES`

| name (STRING) | kind (STRING) | partition (STRING) | columns (INT) | rows (LONG) |
|---|---|---|---|---|
| accounts | relational | NONE | 3 | 0 |
| ledger | relational | NONE | 5 | 0 |

(2 rows)

**Example: Forum posts and news articles**

```sql
CREATE TABLE posts (
  id         LONG PRIMARY KEY AUTO,
  thread_id  LONG NOT NULL,
  parent_id  LONG REFERENCES posts(id),
  author     STRING NOT NULL,
  body       STRING NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE news (
  id           LONG PRIMARY KEY AUTO,
  symbol       STRING,
  published_at TIMESTAMP NOT NULL,
  lang         STRING NOT NULL DEFAULT 'en',
  title        STRING NOT NULL,
  body         STRING NOT NULL,
  source_url   STRING
);
SHOW TABLES;
```

Result:

`CREATE TABLE posts (`

```text
table 'posts' created
```

`CREATE TABLE news (`

```text
table 'news' created
```

`SHOW TABLES`

| name (STRING) | kind (STRING) | partition (STRING) | columns (INT) | rows (LONG) |
|---|---|---|---|---|
| news | relational | NONE | 7 | 0 |
| posts | relational | NONE | 6 | 0 |

(2 rows)

**Example: PARTITION BY on a relational table** (shows an error)

```sql
CREATE TABLE users (id LONG PRIMARY KEY, email STRING) PARTITION BY MONTH;
```

Result:

Error: `line 1, column 56: PARTITION BY is only for time-series tables; expected TIMESERIES(<TIMESTAMP or DATE column>) on table 'users'`

<a id="timeseries"></a>

## TIMESERIES

Syntax:

```sql
CREATE TABLE name (...) TIMESERIES(time_column) [PARTITION BY ...] [SORT BY (...)] [DEDUP KEY (...)]
```

Makes a **time-series** table. `time_column` is its time column: a stored `TIMESTAMP` or `DATE` column. Time-series tables are made for many rows with a time: they are split into files by time ([PARTITION BY](#partition-by)), and they work with [SAMPLE BY](sample-by.md), [LATEST ON](latest-on.md), [ASOF JOIN](joins.md) and `WHERE time IN '2026-09'`.

- Every row needs a value in the time column.
- A time-series table cannot have a `PRIMARY KEY`. Use [DEDUP KEY](#dedup-key).
- **Notes:** partitions use the **UTC** date of the time column.

**Example: Minute candles and live prices**

```sql
CREATE TABLE ochl_minutes (
  time TIMESTAMP ROUND 1m, symbol SYMBOL,
  open DOUBLE, high DOUBLE, low DOUBLE, close DOUBLE, volume DOUBLE
) TIMESERIES(time) PARTITION BY MONTH DEDUP KEY (symbol, time);

CREATE TABLE live_data (
  timestamp TIMESTAMP, symbol SYMBOL, ltp DOUBLE, pct_change DOUBLE, volume LONG
) TIMESERIES(timestamp) PARTITION BY DAY DEDUP KEY (timestamp, symbol);
SHOW TABLES;
```

Result:

`CREATE TABLE ochl_minutes (`

```text
table 'ochl_minutes' created
```

`CREATE TABLE live_data (`

```text
table 'live_data' created
```

`SHOW TABLES`

| name (STRING) | kind (STRING) | partition (STRING) | columns (INT) | rows (LONG) |
|---|---|---|---|---|
| live_data | timeseries | DAY | 5 | 0 |
| ochl_minutes | timeseries | MONTH | 7 | 0 |

(2 rows)

**Example: A DATE time column: one row per company per trading day**

```sql
CREATE TABLE market_cap (day DATE, symbol SYMBOL, cap DECIMAL(2)) TIMESERIES(day) PARTITION BY YEAR DEDUP KEY (symbol, day);
INSERT INTO market_cap VALUES ('2026-09-10', 'CITY', 136637213200.00);
SELECT day, symbol, cap FROM market_cap;
```

Result:

`CREATE TABLE market_cap (`

```text
table 'market_cap' created
```

`INSERT INTO market_cap VALUES ('2026-09-10', 'CITY', 136637213200.00)`

```text
1 row(s) inserted
```

`SELECT day, symbol, cap FROM market_cap`

| day (DATE) | symbol (SYMBOL) | cap (DECIMAL(2)) |
|---|---|---|
| 2026-09-10 | CITY | 136637213200.00 |

(1 row)

**Example: The time column must be a TIMESTAMP or DATE** (shows an error)

```sql
CREATE TABLE trades (id LONG, price DOUBLE) TIMESERIES(id);
```

Result:

Error: `line 1, column 56: TIMESERIES column 'id' is LONG; expected a TIMESTAMP or DATE column`

**Example: A time-series table with a PRIMARY KEY** (shows an error)

```sql
CREATE TABLE trades (time TIMESTAMP, id LONG PRIMARY KEY, price DOUBLE) TIMESERIES(time);
```

Result:

Error: `time-series tables cannot have a PRIMARY KEY ('id'); use DEDUP KEY (..., time) instead, or make it a relational table`

<a id="partition-by"></a>

## PARTITION BY

Syntax:

```sql
PARTITION BY DAY | MONTH | YEAR | NONE
```

A time-series table keeps its rows in one file (a **partition**) per day, month or year of the time column. The default is `DAY`.

| Value | Partition names | Good for |
|---|---|---|
| `DAY` | `'2026-09-10'` | trade log trades, live prices: many rows per day |
| `MONTH` | `'2026-09'` | minute candles |
| `YEAR` | `'2026'` | daily candles |
| `NONE` | one partition | very small time-series tables |

Add `, SYMBOL(column)` after `YEAR`, `MONTH` or `NONE` to split each partition again, one file per symbol: `PARTITION BY YEAR, SYMBOL(symbol)`. The rules are in [PARTITION BY ..., SYMBOL(col)](partitions-and-dedup.md#partition-by-symbol).

Why partitions help:

- `WHERE time IN '2026-09'` reads only the files of September 2026.
- `ALTER TABLE t DROP PARTITION '2025'` deletes a whole year at once ([DROP PARTITION](alter-table.md#drop-partition)).

- **Notes:** the choices are `DAY`, `MONTH`, `YEAR` and `NONE`; there are no weekly partitions, and `PARTITION BY WEEK` is an error. The partition is the **UTC** date. `2026-09-10T02:00:00+05:45` is 2026-09-09 20:15 UTC, so it goes into the partition `2026-09-09`. Too small partitions (DAY for a table with 50 rows a day) make many tiny files; too big ones (NONE for millions of rows) make writes slower. See [partitions and dedup](partitions-and-dedup.md).

**Example: Rows go to monthly partitions; drop one month**

Setup:

```sql
CREATE TABLE ochl_minutes (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY MONTH;
INSERT INTO ochl_minutes VALUES
  ('2026-08-30T11:00:00+05:45', 'CITY', 508.1),
  ('2026-09-10T11:00:00+05:45', 'CITY', 504.6);
```

```sql
ALTER TABLE ochl_minutes DROP PARTITION '2026-08';
SELECT time, symbol, close FROM ochl_minutes;
```

Result:

`ALTER TABLE ochl_minutes DROP PARTITION '2026-08'`

```text
1 partition(s) of 'ochl_minutes' dropped
```

`SELECT time, symbol, close FROM ochl_minutes`

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | CITY | 504.6 |

(1 row)

<a id="sort-by"></a>

## SORT BY

Syntax:

```sql
SORT BY (column, ...)
```

The order of the rows **inside** each partition file. Rows with the same first columns are stored close together, so a query for one symbol reads less.

- **Default:** the first `SYMBOL` column, then the time column: `SORT BY (symbol, time)`. Without a `SYMBOL` column: the time column only.
- Only stored columns (not computed ones), each once.
- **Notes:** you cannot change `SORT BY` later. Columns in `SORT BY` cannot be dropped. `SHOW CREATE TABLE` shows the sort order KDB uses.

**Example: The default sort order is shown by SHOW CREATE TABLE**

```sql
CREATE TABLE trade_log (date TIMESTAMP, transaction_id LONG, symbol SYMBOL, quantity LONG, rate DOUBLE) TIMESERIES(date);
SHOW CREATE TABLE trade_log;
```

Result:

`CREATE TABLE trade_log (`

```text
table 'trade_log' created
```

`SHOW CREATE TABLE trade_log`

| create_sql (STRING) |
|---|
| CREATE TABLE trade_log (   date TIMESTAMP,   transaction_id LONG,   symbol SYMBOL,   quantity LONG,   rate DOUBLE ) TIMESERIES(date) PARTITION BY DAY SORT BY (symbol, date) |

(1 row)

**Example: Sort the trades of a day by transaction number**

```sql
CREATE TABLE trade_log (date TIMESTAMP ROUND 1d, transaction_id LONG, symbol SYMBOL, quantity LONG, rate DOUBLE)
  TIMESERIES(date) PARTITION BY DAY SORT BY (date, transaction_id) DEDUP KEY (date, transaction_id);
SHOW CREATE TABLE trade_log;
```

Result:

`CREATE TABLE trade_log (`

```text
table 'trade_log' created
```

`SHOW CREATE TABLE trade_log`

| create_sql (STRING) |
|---|
| CREATE TABLE trade_log (   date TIMESTAMP ROUND 1d,   transaction_id LONG,   symbol SYMBOL,   quantity LONG,   rate DOUBLE ) TIMESERIES(date) PARTITION BY DAY SORT BY (date, transaction_id) DEDUP K... |

(1 row)

<a id="dedup-key"></a>

## DEDUP KEY

Syntax:

```sql
DEDUP KEY (column, ..., time_column)
```

The columns that make two rows "the same row". It is the key of a time-series table, and it **must include the time column**.

| Statement | The key is new | The key is already there |
|---|---|---|
| `INSERT` | row added | **error**, nothing saved |
| `INSERT OR REPLACE` | row added | the old row is replaced |
| `INSERT OR IGNORE` | row added | the new row is skipped |

- Without a `DEDUP KEY`, KDB keeps every row, also exact copies.
- `NULL` counts as a value here: two rows with the same time and `symbol` `NULL` are the same row.
- **Tip:** give every time-series table a `DEDUP KEY`. Then an import file can be loaded twice without double rows.
- **Notes:** QuestDB's `DEDUP UPSERT KEYS(...)` is read as `DEDUP KEY (...)` and, as in QuestDB, a plain `INSERT` of a key that is there then **replaces** the row ([dedup_insert](partitions-and-dedup.md#dedup-insert)). With KDB's own `DEDUP KEY`, duplicates give an error unless you write `INSERT OR REPLACE`, the table has `dedup_insert = 'upsert'`, or the database uses the [QuestDB dialect](databases.md#dialect). See [INSERT](insert.md#duplicates).
- **Notes:** a load over the line protocol does less work when every `SORT BY` column is in the `DEDUP KEY` ([how loads find duplicates](partitions-and-dedup.md#load-dedup)).

**Example: One candle per symbol per day**

Setup:

```sql
CREATE TABLE ochl_day (time TIMESTAMP ROUND 1d, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (symbol, time);
INSERT INTO ochl_day VALUES ('2026-09-10', 'CITY', 504.9);
```

```sql
INSERT OR REPLACE INTO ochl_day VALUES ('2026-09-10', 'CITY', 505.2);
SELECT time, symbol, close FROM ochl_day;
```

Result:

`INSERT OR REPLACE INTO ochl_day VALUES ('2026-09-10', 'CITY', 505.2)`

```text
0 row(s) inserted, 1 replaced
```

`SELECT time, symbol, close FROM ochl_day`

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 505.2 |

(1 row)

**Example: Without a DEDUP KEY, the same tick is stored twice**

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO ticks VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 510);
INSERT INTO ticks VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 510);
SELECT time, symbol, price FROM ticks;
```

Result:

`CREATE TABLE ticks (`

```text
table 'ticks' created
```

`INSERT INTO ticks VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 510)`

```text
1 row(s) inserted
```

`INSERT INTO ticks VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 510)`

```text
1 row(s) inserted
```

`SELECT time, symbol, price FROM ticks`

| time (TIMESTAMP) | symbol (SYMBOL) | price (DOUBLE) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | CITY | 510 |
| 2026-09-10T05:15:00.000Z | CITY | 510 |

(2 rows)

**Example: A DEDUP KEY without the time column** (shows an error)

```sql
CREATE TABLE live_data (timestamp TIMESTAMP, symbol SYMBOL, ltp DOUBLE) TIMESERIES(timestamp) DEDUP KEY (symbol);
```

Result:

Error: `DEDUP KEY must include the time column 'timestamp', e.g. DEDUP KEY (symbol, timestamp), or a column GENERATED ALWAYS AS (date_trunc('minute', timestamp)) STORED`

<a id="round"></a>

## ROUND

Syntax:

```sql
column TIMESTAMP ROUND interval
interval: number + ms | s | m | h | d | w      (1m, 5m, 15m, 1h, 1d)
```

Cuts every time **down** to the interval when a row is written. `ROUND 1m` turns `11:05:42` into `11:05:00`. Use it for candles, so that times are clean and the `DEDUP KEY` finds the same minute or day.

| Unit | Meaning |
|---|---|
| `ms` | milliseconds |
| `s` | seconds |
| `m` | minutes (also `M`: `ROUND` has no months) |
| `h` | hours |
| `d` | days (UTC) |
| `w` | weeks of 7 days, counted from 1970-01-01 (a **Thursday**) |

- **NULL:** a `NULL` time stays `NULL`.
- **Notes:** only for `TIMESTAMP` columns. `ROUND 1d` rounds to the **UTC** day: `2026-09-10T02:00:00+05:45` becomes `2026-09-09T00:00:00Z`. For weeks that start on Sunday, use `ROUND 1d` and [SAMPLE BY 1w](sample-by.md) in queries instead of `ROUND 1w`.

**Example: Minute candles: 11:05:42 Nepal time is stored as 05:20:00 UTC**

```sql
CREATE TABLE ochl_minutes (time TIMESTAMP ROUND 1m, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY MONTH DEDUP KEY (symbol, time);
INSERT INTO ochl_minutes VALUES ('2026-09-10T11:05:42+05:45', 'CITY', 504.8);
SELECT time, symbol, close FROM ochl_minutes;
```

Result:

`CREATE TABLE ochl_minutes (`

```text
table 'ochl_minutes' created
```

`INSERT INTO ochl_minutes VALUES ('2026-09-10T11:05:42+05:45', 'CITY', 504.8)`

```text
1 row(s) inserted
```

`SELECT time, symbol, close FROM ochl_minutes`

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T05:20:00.000Z | CITY | 504.8 |

(1 row)

**Example: With ROUND 1d a second row of the same day is a duplicate** (shows an error)

Setup:

```sql
CREATE TABLE ochl_day (time TIMESTAMP ROUND 1d, symbol SYMBOL, close DOUBLE) TIMESERIES(time) DEDUP KEY (symbol, time);
INSERT INTO ochl_day VALUES ('2026-09-10 14:37:12', 'CITY', 504.9);
```

```sql
INSERT INTO ochl_day VALUES ('2026-09-10 09:00', 'CITY', 1);
```

Result:

Error: `a row with symbol='CITY', time='2026-09-10T00:00:00.000Z' already exists in 'ochl_day'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it`

**Example: 15-minute buckets**

```sql
CREATE TABLE index_15m (time TIMESTAMP ROUND 15m, index_name SYMBOL, value DOUBLE) TIMESERIES(time) DEDUP KEY (index_name, time);
INSERT OR REPLACE INTO index_15m VALUES
  ('2026-09-10T11:14:59+05:45', 'INDEX', 2710.5),
  ('2026-09-10T11:15:00+05:45', 'INDEX', 2712.0);
SELECT time, index_name, value FROM index_15m;
```

Result:

`CREATE TABLE index_15m (`

```text
table 'index_15m' created
```

`INSERT OR REPLACE INTO index_15m VALUES ('2026-09-10T11:14:59+05:45', 'INDEX', 2710.5), ('2026-09-10`

```text
2 row(s) inserted
```

`SELECT time, index_name, value FROM index_15m`

| time (TIMESTAMP) | index_name (SYMBOL) | value (DOUBLE) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | INDEX | 2710.5 |
| 2026-09-10T05:30:00.000Z | INDEX | 2712 |

(2 rows)

**Example: ROUND on a column that is not a TIMESTAMP** (shows an error)

```sql
CREATE TABLE t (day DATE ROUND 1d, v DOUBLE);
```

Result:

Error: `line 1, column 26: ROUND needs a TIMESTAMP column; expected TIMESTAMP but column 'day' is DATE`

<a id="computed"></a>

## Computed columns: AS (expr)

Syntax:

```sql
column TYPE AS (expression)
```

A **computed** column is not stored. KDB works it out from the other columns of the same row each time you read it.

- The expression uses **stored** columns of the same row, operators and built-in functions.
- You cannot give it a value in `INSERT`, and `UPDATE` cannot set it. Change the columns it is made from.
- `INSERT INTO t VALUES (...)` without a column list skips computed columns.
- To keep the value on disk (for an index, `UNIQUE` or `NOT NULL`), use a [stored generated column](#generated).
- **Notes:** a computed column cannot also have `PRIMARY KEY`, `NOT NULL`, `UNIQUE`, `DEFAULT`, `REFERENCES` or `ROUND`, and cannot be in `SORT BY`, `DEDUP KEY`, a `CHECK` or an index. No subqueries, window functions or other computed columns inside. Do not use random functions (`gen_random_uuid()`) or `now()` in it: the value changes on every read.

**Example: Trade log amount and broker commission**

```sql
CREATE TABLE trade_log (
  date TIMESTAMP ROUND 1d, transaction_id LONG, symbol SYMBOL,
  quantity LONG, rate DOUBLE,
  amount DOUBLE AS (quantity * rate),
  commission DOUBLE AS (round(quantity * rate * 0.004, 2))
) TIMESERIES(date) PARTITION BY DAY DEDUP KEY (date, transaction_id);
INSERT INTO trade_log VALUES ('2026-09-10', 100010, 'CITY', 50, 517.0);
SELECT transaction_id, quantity, rate, amount, commission FROM trade_log;
```

Result:

`CREATE TABLE trade_log (`

```text
table 'trade_log' created
```

`INSERT INTO trade_log VALUES ('2026-09-10', 100010, 'CITY', 50, 517.0)`

```text
1 row(s) inserted
```

`SELECT transaction_id, quantity, rate, amount, commission FROM trade_log`

| transaction_id (LONG) | quantity (LONG) | rate (DOUBLE) | amount (DOUBLE) | commission (DOUBLE) |
|---|---|---|---|---|
| 100010 | 50 | 517 | 25850 | 103.4 |

(1 row)

**Example: A computed column cannot be given a value** (shows an error)

Setup:

```sql
CREATE TABLE trade_log (quantity LONG, rate DOUBLE, amount DOUBLE AS (quantity * rate));
```

```sql
INSERT INTO trade_log (quantity, rate, amount) VALUES (100, 515.5, 51550);
```

Result:

Error: `column 'amount' is computed (AS ...) and cannot be given a value`

**Example: A computed column that uses a missing column** (shows an error)

```sql
CREATE TABLE trade_log (quantity LONG, amount DOUBLE AS (quantity * price));
```

Result:

Error: `column 'amount' of table 'trade_log' uses column 'price' in AS (...), which does not exist in table 'trade_log'`

<a id="generated"></a>

## Stored generated columns: GENERATED ALWAYS AS (expr) STORED

Syntax:

```sql
column TYPE GENERATED ALWAYS AS (expression) STORED
column TYPE GENERATED ALWAYS AS (expression) [VIRTUAL]
```

The PostgreSQL form. With `STORED`, KDB works the value out **when the row is written** and keeps it like any other column. Without `STORED` (or with `VIRTUAL`) it is a [computed column](#computed), worked out when read.

| | `AS (expr)`, `VIRTUAL` | `STORED` |
|---|---|---|
| worked out | on every read | on every write |
| takes disk space | no | yes |
| an index, `UNIQUE`, `NOT NULL`, `CHECK`, `REFERENCES` | no | yes |

- Every write works it out again: `INSERT`, `UPDATE` of a column it reads, `ON CONFLICT DO UPDATE`, a foreign key `ON UPDATE CASCADE`, and API and line-protocol inserts.
- You cannot give it a value in `INSERT` or `UPDATE`, as in PostgreSQL. `INSERT INTO t VALUES (...)` without a column list skips it; `COPY` without a column list too.
- `ALTER TABLE ... ADD COLUMN ... GENERATED ALWAYS AS (...) STORED` fills it in for the rows already in the table (the rows are written again).
- **Notes:** it cannot be the `PRIMARY KEY`, a time-series table's time column, or in `SORT BY`, and cannot have `DEFAULT`, `AUTO` or `ROUND`. It **can** be in a `DEDUP KEY`: `date_trunc('minute', time)` there makes seconds of one minute the same row ([a key on the minute](partitions-and-dedup.md#minute-key)). The expression uses stored columns that are not generated themselves, and built-in functions only. A column it uses cannot be dropped first.
- Tables made before 2026-09-24 with `STORED` keep a computed column (worked out when read). To store it, drop the column and add it again.

**Example: An order total you can index and search**

```sql
CREATE TABLE order_lines (
  id INT PRIMARY KEY, qty INT, price DECIMAL(2),
  total DECIMAL(2) GENERATED ALWAYS AS (qty * price) STORED
);
CREATE INDEX order_lines_total ON order_lines (total);
INSERT INTO order_lines (id, qty, price) VALUES (1, 2, 1.50), (2, 4, 2.00);
UPDATE order_lines SET qty = 3 WHERE id = 1;
SELECT id, qty, price, total FROM order_lines WHERE total > 4 ORDER BY id;
```

Result:

`CREATE TABLE order_lines (`

```text
table 'order_lines' created
```

`CREATE INDEX order_lines_total ON order_lines (total)`

```text
index 'order_lines_total' created on table 'order_lines' (0 rows)
```

`INSERT INTO order_lines (id, qty, price) VALUES (1, 2, 1.50), (2, 4, 2.00)`

```text
2 row(s) inserted
```

`UPDATE order_lines SET qty = 3 WHERE id = 1`

```text
1 row(s) updated
```

`SELECT id, qty, price, total FROM order_lines WHERE total > 4 ORDER BY id`

| id (INT) | qty (INT) | price (DECIMAL(2)) | total (DECIMAL(2)) |
|---|---|---|---|
| 1 | 3 | 1.50 | 4.50 |
| 2 | 4 | 2.00 | 8.00 |

(2 rows)

**Example: A stored generated column cannot be given a value** (shows an error)

Setup:

```sql
CREATE TABLE order_lines (id INT PRIMARY KEY, qty INT, price DECIMAL(2), total DECIMAL(2) GENERATED ALWAYS AS (qty * price) STORED);
```

```sql
UPDATE order_lines SET total = 10;
```

Result:

Error: `column 'total' is GENERATED ALWAYS AS (...) STORED and cannot be set; KDB works it out from the row`

<a id="row-ttl"></a>

## Rows that expire: WITH (ttl_column = ...)

Syntax:

```sql
CREATE TABLE name (..., expires_at TIMESTAMP, ...) WITH (ttl_column = expires_at)
```

Each row can have its own end of life, like a Redis key with `EXPIRE`. When the time in `expires_at` has come, the row is **gone at once** for every statement, and a background thread deletes it within about a second. Use it for login sessions, rate-limit counters, caches and short-lived tokens.

| `expires_at` is | the row is |
|---|---|
| later than now | there |
| now or earlier | gone: no `SELECT`, join, `UPDATE` or `DELETE` sees it |
| `NULL` | there for ever |

- An `INSERT` of an expired row's key is a new row, not an "already exists" error. `INSERT ... ON CONFLICT DO UPDATE` starts a fresh row, so a counter that expires counts from 1 again.
- To keep a row alive longer, `UPDATE` its `expires_at`.
- The deletes are ordinary deletes: they are in the log, and `DELETE` [triggers](triggers.md) see the rows.
- **Notes:** the column must be a stored `TIMESTAMP`. It cannot be dropped while the table has the option, and the option is set by `CREATE TABLE` only (`ALTER TABLE ... SET (ttl_column = ...)` is refused for now). A database with such a table needs KDB 2026-09-25 or later ([versions](versions.md)).
- **Speed:** a read of such a table checks the time on each row and never comes from the [result cache](performance-tips.md#result-cache). The table's `TTL n DAYS` (whole partitions) is a different, older option: [SET TTL](alter-table.md#set-ttl).

**Example: Sessions that expire, and a counter that starts again**

```sql
CREATE TABLE sessions (
  token      STRING PRIMARY KEY,
  user_id    LONG,
  hits       LONG,
  expires_at TIMESTAMP
) WITH (ttl_column = expires_at);
INSERT INTO sessions VALUES ('old', 1, 5, '2020-01-01T00:00:00Z'), ('new', 2, 1, '2099-01-01T00:00:00Z'), ('api', 3, 0, NULL);
SELECT token, user_id FROM sessions ORDER BY token;
INSERT INTO sessions VALUES ('old', 1, 1, '2099-01-01T00:00:00Z')
  ON CONFLICT (token) DO UPDATE SET hits = sessions.hits + 1 RETURNING hits;
```

Result:

`CREATE TABLE sessions (`

```text
table 'sessions' created
```

`INSERT INTO sessions VALUES ('old', 1, 5, '2020-01-01T00:00:00Z'), ('new', 2, 1, '2099-01-01T00:00:0`

```text
3 row(s) inserted
```

`SELECT token, user_id FROM sessions ORDER BY token`

| token (STRING) | user_id (LONG) |
|---|---|
| api | 3 |
| new | 2 |

(2 rows)

`INSERT INTO sessions VALUES ('old', 1, 1, '2099-01-01T00:00:00Z') ON CONFLICT (token) DO UPDATE SET `

| hits (LONG) |
|---|
| 1 |

(1 row)

```text
1 row(s) inserted
```

<a id="cache-table"></a>

## Cache tables: WITH (max_bytes, evict, durability)

Syntax:

```sql
CREATE TABLE name (key ... PRIMARY KEY, ...)
  WITH (max_bytes = '64MB' [, evict = 'lru'] [, durability = 'none'])
ALTER TABLE name SET (max_bytes = '128MB')
ALTER TABLE name RESET (max_bytes)
```

A **cache table** has a memory cap, like Redis with `maxmemory`. When its rows take more than `max_bytes`, a background thread deletes rows until it fits again (within about a second), in the order `evict` says:

| `evict` | Rows that go first | Redis name |
|---|---|---|
| `'lru'` (the default with a cap) | the rows read or written longest ago | `allkeys-lru` |
| `'volatile_lru'` | the same, but only rows that expire | `volatile-lru` |
| `'random'` | any rows | `allkeys-random` |
| `'volatile_random'` | any rows that expire | `volatile-random` |
| `'volatile_ttl'` | the rows that [expire](#row-ttl) soonest | `volatile-ttl` |
| `'none'` | nothing (no cap) | `noeviction` |

| Option | Means |
|---|---|
| `max_bytes` | the cap: `'64MB'`, `'512KB'`, `'1GB'` or a number of bytes; `0` = no cap |
| `durability = 'none'` | the table is **emptied every time the database opens** (Redis `appendonly no`), for data you can rebuild |
| `durability = 'log'` | rows survive a restart (the default) |

- `SELECT kv_memory('name')` answers the bytes the table holds, as last measured. A row counts the bytes of its values (text by its length, numbers and times 8 bytes) plus 48 bytes.
- A row is "used" when a statement reads it row by row (a look-up by key, `SELECT ... WHERE`) or writes it. Aggregates over many rows (`count(*)`, `sum`) do not count as a use.
- **Needs:** a `PRIMARY KEY` for any `evict`; a [ttl_column](#row-ttl) for the `volatile_` ones. The evicting deletes are ordinary deletes: they are in the log and `DELETE` triggers see them.
- The key-value store has the same cap: `CONFIG SET maxmemory 64mb` ([kv](kv.md#kv-memory)).
- A database with a cache table needs KDB 2026-10-02 or later ([versions](versions.md)).

**Example: A cache of 1 MB that keeps the rows in use**

```sql
CREATE TABLE page_cache (url STRING PRIMARY KEY, html STRING)
  WITH (max_bytes = '1MB', evict = 'lru');
INSERT INTO page_cache VALUES ('/', '<h1>home</h1>'), ('/about', '<h1>about</h1>');
SELECT html FROM page_cache WHERE url = '/';
ALTER TABLE page_cache SET (max_bytes = '4MB', durability = 'none');
```

Result:

`CREATE TABLE page_cache (`

```text
table 'page_cache' created
```

`INSERT INTO page_cache VALUES ('/', '<h1>home</h1>'), ('/about', '<h1>about</h1>')`

```text
2 row(s) inserted
```

`SELECT html FROM page_cache WHERE url = '/'`

| html (STRING) |
|---|
| <h1>home</h1> |

(1 row)

`ALTER TABLE page_cache SET (max_bytes = 4194304, durability = 'none')`

```text
table 'page_cache': max_bytes = 4194304, evict = 'lru', durability = 'none' (emptied every time the database opens)
```
