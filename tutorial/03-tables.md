# 3. Tables

- Category: Tutorial

## What you will learn

- The two kinds of tables, and when to use each.
- Column types and column rules (keys, NOT NULL, DEFAULT, REFERENCES, computed columns).
- How to change and remove tables.

The examples start with an **empty** database `market`. Run them in order.

## Two kinds of tables

| | Time-series table | Relational table |
|---|---|---|
| What it holds | Rows with a time: prices, candles, trades | Lists of things: securities, brokers, accounts |
| How you make it | `CREATE TABLE ... TIMESERIES(time_column)` | `CREATE TABLE ...` (nothing extra) |
| Must have | A `TIMESTAMP` or `DATE` column | nothing |
| Split into parts | Yes: `PARTITION BY DAY`, `MONTH`, `YEAR` or `NONE` | No, one part |
| Duplicate check | `DEDUP KEY (...)`, must include the time column | `PRIMARY KEY` |
| Special queries | `SAMPLE BY`, `LATEST ON`, `ASOF JOIN`, `time IN '2026-09'` | normal SQL |
| Stock market examples | `ochl_day`, `ochl_minutes`, `trade_log`, `live_data` | `securities`, `brokers`, `accounts` |

Simple rule: **if the row has a time and you get many new rows every day, use a time-series table.**

## Relational tables

```sql
CREATE TABLE securities (
  symbol SYMBOL PRIMARY KEY,
  name   STRING NOT NULL,
  sector STRING
);

CREATE TABLE brokers (
  id   INT PRIMARY KEY,
  name STRING NOT NULL
);

INSERT INTO securities VALUES
  ('CITY', 'City Bank Limited', 'Banking'),
  ('COAST',  'Coastal Bank Limited', 'Banking'),
  ('VOLT', 'Volt River Hydropower Limited', 'Energy');

INSERT INTO brokers VALUES (1, 'Keystone Securities'), (45, 'Imperial Securities'), (58, 'Northgate Securities');
```

```text
table 'securities' created

table 'brokers' created

3 row(s) inserted

3 row(s) inserted
```

(To run a file like this: `Get-Content tables.sql -Raw | kareladb sql market -`.)

## Time-series tables

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

CREATE TABLE ochl_minutes (
  time   TIMESTAMP ROUND 1m,
  symbol SYMBOL,
  open   DOUBLE,
  high   DOUBLE,
  low    DOUBLE,
  close  DOUBLE,
  volume DOUBLE
) TIMESERIES(time) PARTITION BY MONTH DEDUP KEY (symbol, time);
```

```text
table 'ochl_day' created

table 'ochl_minutes' created
```

### The table options

| Option | Meaning | Default |
|---|---|---|
| `TIMESERIES(col)` | This is a time-series table. `col` is its time column (`TIMESTAMP` or `DATE`). | - (without it: relational table) |
| `PARTITION BY DAY` / `MONTH` / `YEAR` / `NONE` | Rows are saved in one file per day, month or year. | `DAY` |
| `PARTITION BY MONTH, SYMBOL(symbol)` | Also one file per symbol (the time part is `YEAR`, `MONTH` or `NONE`). A query for one symbol reads only its files. | - |
| `TTL 90 DAYS` | KarelaDB drops partitions older than this by itself (see [Keep only recent data](#keep-only-recent-data)). | no TTL |
| `SORT BY (a, b)` | Order of rows inside each file. | the first `SYMBOL` column, then the time column |
| `DEDUP KEY (a, b)` | Two rows with the same values here are "the same row". | none: duplicates are allowed |

### A picture of a time-series table

`ochl_minutes` with `PARTITION BY MONTH` and the default `SORT BY (symbol, time)`:

| Partition (one file) | Rows inside the file, in order |
|---|---|
| `2026-08` | CITY 08-30 11:00, CITY 08-30 11:01, ... COAST 08-30 11:00, COAST 08-30 11:01, ... |
| `2026-09` | CITY 09-09 11:00, CITY 09-09 11:01, ... CITY 09-10 14:59, COAST 09-09 11:00, ... |
| `2026-10` | (made when the first October row arrives) |

Why this is good:

- A query with `WHERE time IN '2026-09'` reads only the `2026-09` file.
- A query for one symbol finds its rows close together.
- You can delete a whole month fast: `ALTER TABLE ochl_minutes DROP PARTITION '2026-08'`, or everything older than a year: `ALTER TABLE ochl_minutes DROP PARTITION OLDER THAN 1 YEAR`.

### Which PARTITION BY to use

| Data | Rows per day (all symbols) | Good choice |
|---|---|---|
| Daily candles (`ochl_day`) | a few hundred | `YEAR` |
| Minute candles (`ochl_minutes`) | tens of thousands | `MONTH` |
| TradeLog trades | tens of thousands | `DAY` |
| Live price snapshots | many | `DAY` |
| Very small tables | few | `NONE` |

Partitions are based on the **UTC** date of the time column.

### DEDUP KEY: how duplicates are found

`DEDUP KEY (symbol, time)` means: one row per symbol per time. A second row with the same symbol and time is a duplicate.

- `INSERT` stops with an error on a duplicate.
- `INSERT OR REPLACE` overwrites the old row.
- `INSERT OR IGNORE` keeps the old row and skips the new one.

The DEDUP KEY **must include the time column**:

```sql
CREATE TABLE bad (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) DEDUP KEY (symbol);
```

```text
error: DEDUP KEY must include the time column 'time', e.g. DEDUP KEY (symbol, time)
```

Without a DEDUP KEY, KarelaDB keeps every row, also exact copies:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;

INSERT INTO ticks VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 510);
INSERT INTO ticks VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 510);

SELECT time, symbol, price FROM ticks;
```

```text
table 'ticks' created

1 row(s) inserted

1 row(s) inserted

time                     | symbol | price
-------------------------+--------+------
2026-09-10T05:15:00.000Z | CITY   |   510
2026-09-10T05:15:00.000Z | CITY   |   510
(2 rows, 0.1 ms)
```

**Tip:** give every market-data time-series table a DEDUP KEY. Then you can load the same file twice without making double rows.

### ROUND: clean times

`ROUND 1d` (or `1m`, `5m`, `1h`, ...) on a `TIMESTAMP` column cuts the time down when a row is written. Units: `ms`, `s`, `m` (minute), `h`, `d`, `w`.

```sql
INSERT INTO ochl_day VALUES ('2026-09-10 14:37:12', 'CITY', 504.6, 507, 500.7, 504.9, 183040);
INSERT INTO ochl_minutes VALUES ('2026-09-10T11:05:42+05:45', 'CITY', 504.6, 504.9, 504.5, 504.8, 1200);
SELECT time, symbol, close FROM ochl_day;
SELECT time, symbol, close FROM ochl_minutes;
```

```text
1 row(s) inserted

1 row(s) inserted

time                     | symbol | close
-------------------------+--------+------
2026-09-10T00:00:00.000Z | CITY   | 504.9
(1 row, 0.1 ms)

time                     | symbol | close
-------------------------+--------+------
2026-09-10T05:20:00.000Z | CITY   | 504.8
(1 row, 0.0 ms)
```

- `14:37:12` became `00:00:00` (the day, in UTC).
- `11:05:42` Nepal time is `05:20:42` UTC. It became `05:20:00`.

Because of ROUND, a second row for the same day is a duplicate, even with another time of day:

```sql
INSERT INTO ochl_day VALUES ('2026-09-10 09:00', 'CITY', 1, 1, 1, 1, 1);
```

```text
error: a row with symbol='CITY', time='2026-09-10T00:00:00.000Z' already exists in 'ochl_day'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it
```

**Careful:** `ROUND 1d` rounds to the **UTC** day. For daily candles stored at 00:00 UTC of the trading date, this is right. A time like `2026-09-10T02:00:00+05:45` (still 9 September in UTC) would go to 9 September.

## SHOW: look at tables

```sql
SHOW TABLES;
```

```text
name         | kind       | partition | columns | rows
-------------+------------+-----------+---------+-----
brokers      | relational | NONE      |       2 |    3
trade_log    | timeseries | DAY       |       8 |    0
live_data    | timeseries | DAY       |       5 |    0
ochl_day     | timeseries | YEAR      |       7 |    0
ochl_minutes | timeseries | MONTH     |       7 |    0
securities   | relational | NONE      |       3 |    3
(6 rows, 0.0 ms)
```

(`trade_log` and `live_data` are created in the next section. The output above was taken after that.)

```sql
SHOW COLUMNS FROM trade_log;
```

```text
name           | type      | primary_key | not_null | computed | references 
---------------+-----------+-------------+----------+----------+------------
date           | TIMESTAMP | false       | false    | false    | NULL       
transaction_id | LONG      | false       | false    | false    | NULL       
symbol         | SYMBOL    | false       | false    | false    | NULL       
buyer          | INT       | false       | false    | false    | brokers(id)
seller         | INT       | false       | false    | false    | brokers(id)
quantity       | LONG      | false       | false    | false    | NULL       
rate           | DOUBLE    | false       | false    | false    | NULL       
amount         | DOUBLE    | false       | false    | true     | NULL       
(8 rows, 0.0 ms)
```

`SHOW CREATE TABLE` gives the full statement. Use CSV format, so the long text is not cut:

```powershell
kareladb sql market "SHOW CREATE TABLE ochl_day" --format csv
```

```text
create_sql
"CREATE TABLE ochl_day (
  time TIMESTAMP ROUND 1d,
  symbol SYMBOL,
  open DOUBLE,
  high DOUBLE,
  low DOUBLE,
  close DOUBLE,
  volume DOUBLE
) TIMESERIES(time) PARTITION BY YEAR SORT BY (symbol, time) DEDUP KEY (symbol, time)"
```

You can see the default `SORT BY (symbol, time)` here.

`SHOW VIEWS` lists views (chapter 5).

## Column types

| Type | Size | Values | Use it for |
|---|---|---|---|
| `BOOL` | 1 byte | `TRUE`, `FALSE` | yes/no flags |
| `BYTE` | 1 byte | -127 to 127 | very small numbers |
| `SHORT` | 2 bytes | -32767 to 32767 | small numbers |
| `INT` | 4 bytes | -2147483647 to 2147483647 | broker ids |
| `LONG` | 8 bytes | about ±9.2 × 10^18 | transaction ids, share quantities |
| `FLOAT` | 4 bytes | about 7 digits | rarely needed |
| `DOUBLE` | 8 bytes | about 15 digits | prices, volumes, percentages |
| `DECIMAL(s)` | 8 bytes | exact, `s` digits after the point (0 to 18) | money: `DECIMAL(2)` for dollars and cents |
| `DATE` | 4 bytes | a day, like `2026-09-10` | dates without time |
| `TIMESTAMP` | 8 bytes | a moment in UTC, in milliseconds | candle and trade times |
| `SYMBOL` | 4 bytes | text that repeats a lot | stock symbols, sectors |
| `STRING` | as long as the text | any text (UTF-8) | names, notes |

Other names that also work: `BOOLEAN` = `BOOL`, `INTEGER` = `INT`, `BIGINT` = `LONG`, `VARCHAR` and `TEXT` = `STRING`.

There are more types for other kinds of data: `JSON` and `BYTES` (chapter 18), and the PostgreSQL types like `SERIAL`, `VARCHAR(n)`, `NUMERIC(p,s)`, `UUID` and arrays (chapter 22).

Every type can be `NULL` (no value). For the number types, the smallest value is used to store NULL. That is why `BYTE` goes to -127, not -128.

All types in one table:

```sql
CREATE TABLE type_demo (
  b   BOOL,
  i8  BYTE,
  i16 SHORT,
  i32 INT,
  i64 LONG,
  f   FLOAT,
  d   DOUBLE,
  m   DECIMAL(2),
  day DATE,
  ts  TIMESTAMP,
  sym SYMBOL,
  txt STRING
);

INSERT INTO type_demo VALUES
  (TRUE, 127, 32767, 2147483647, 9223372036854775807, 1.5, 512.45, 1500.25,
   '2026-09-10', '2026-09-10T11:00:00+05:45', 'CITY', 'City Bank Limited'),
  (NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

SELECT * FROM type_demo;
```

```text
table 'type_demo' created

2 row(s) inserted

b    | i8   | i16   | i32        | i64                 | f    | d      | m       | day        | ts                       | sym   | txt               
-----+------+-------+------------+---------------------+------+--------+---------+------------+--------------------------+-------+-------------------
true |  127 | 32767 | 2147483647 | 9223372036854775807 |  1.5 | 512.45 | 1500.25 | 2026-09-10 | 2026-09-10T05:15:00.000Z | CITY  | City Bank Limited
NULL | NULL |  NULL |       NULL |                NULL | NULL |   NULL |    NULL | NULL       | NULL                     | NULL  | NULL              
(2 rows, 0.1 ms)
```

**DOUBLE or DECIMAL?** `DOUBLE` is fast and good for prices and indicators. It is not exact: `0.1 + 0.2` is not exactly `0.3`. For money that must add up exactly (accounts, fees), use `DECIMAL(2)`.

## Column rules

| Rule | Meaning |
|---|---|
| `PRIMARY KEY` | One row per value. At most one per table. Cannot be NULL. |
| `PRIMARY KEY AUTO` | Like PRIMARY KEY. If you give no value, KarelaDB uses the next number of the table's counter. The counter only goes up: ids of deleted rows are never used again. Integer columns only. |
| `NOT NULL` | The column must have a value. |
| `UNIQUE` | No two rows may have the same value (NULL is allowed many times). |
| `DEFAULT value` | Used when the INSERT gives no value. A constant, or `now()`. |
| `REFERENCES table(column)` | The value must exist in the other table. The other column must be PRIMARY KEY or UNIQUE. |
| `AS (expression)` | A computed column. It is not stored; KarelaDB computes it when you read. |
| `ROUND interval` | Cuts TIMESTAMP values down (see above). |

Use PRIMARY KEY on **relational** tables. On time-series tables use DEDUP KEY (a PRIMARY KEY there is refused).

### Accounts: AUTO key, NOT NULL, UNIQUE, DEFAULT, DECIMAL

```sql
CREATE TABLE accounts (
  id      LONG PRIMARY KEY AUTO,
  owner   STRING NOT NULL,
  email   STRING UNIQUE,
  balance DECIMAL(2) DEFAULT 0,
  status  STRING DEFAULT 'active',
  opened  TIMESTAMP DEFAULT now()
);

INSERT INTO accounts (owner, email, balance) VALUES
  ('Ram Sharma', 'ram@example.com', 1500.25),
  ('Sita Rai', 'sita@example.com', '99.5');
INSERT INTO accounts (owner) VALUES ('Hari Thapa');

SELECT id, owner, email, balance, status FROM accounts;
```

```text
table 'accounts' created

2 row(s) inserted

1 row(s) inserted

id | owner      | email            | balance | status
---+------------+------------------+---------+-------
 1 | Ram Sharma | ram@example.com  | 1500.25 | active
 2 | Sita Rai   | sita@example.com |   99.50 | active
 3 | Hari Thapa | NULL             |    0.00 | active
(3 rows, 0.1 ms)
```

- `id` was filled with 1, 2, 3.
- `'99.5'` (text) was turned into the decimal `99.50`.
- Hari got the DEFAULT values `0.00` and `active`.

The rules stop bad rows:

```sql
INSERT INTO accounts (owner, balance) VALUES ('Gita', 10.555);
```

```text
error: column 'balance' (DECIMAL(2)): 10.555 has more than 2 decimal places
```

```sql
INSERT INTO accounts (email) VALUES ('nobody@example.com');
```

```text
error: column 'owner' (STRING): cannot be NULL
```

```sql
INSERT INTO accounts (owner, email) VALUES ('Ram Again', 'ram@example.com');
```

```text
error: column 'email' must be unique: 'ram@example.com' is already used
```

### TradeLog: REFERENCES and a computed column

```sql
CREATE TABLE trade_log (
  date           TIMESTAMP ROUND 1d,
  transaction_id LONG,
  symbol         SYMBOL,
  buyer          INT REFERENCES brokers(id),
  seller         INT REFERENCES brokers(id),
  quantity       LONG,
  rate           DOUBLE,
  amount         DOUBLE AS (quantity * rate)
) TIMESERIES(date) PARTITION BY DAY DEDUP KEY (date, transaction_id);

CREATE TABLE live_data (
  timestamp  TIMESTAMP,
  symbol     SYMBOL,
  ltp        DOUBLE,
  pct_change DOUBLE,
  volume     LONG
) TIMESERIES(timestamp) PARTITION BY DAY DEDUP KEY (timestamp, symbol);
```

```text
table 'trade_log' created

table 'live_data' created
```

Insert a trade. Do not give `amount`; KarelaDB computes it:

```sql
INSERT INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate)
VALUES ('2026-09-10', 100001, 'CITY', 58, 45, 100, 515.5);

SELECT transaction_id, symbol, buyer, seller, quantity, rate, amount FROM trade_log;
```

```text
1 row(s) inserted

transaction_id | symbol | buyer | seller | quantity | rate  | amount
---------------+--------+-------+--------+----------+-------+-------
        100001 | CITY   |    58 |     45 |      100 | 515.5 |  51550
(1 row, 0.2 ms)
```

A broker that does not exist is refused:

```sql
INSERT INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate)
VALUES ('2026-09-10', 100002, 'COAST', 99, 45, 10, 399);
```

```text
error: column 'buyer' = '99' has no matching row in brokers(id)
```

A broker that trades are pointing at cannot be deleted:

```sql
DELETE FROM brokers WHERE id = 58;
```

```text
error: cannot remove brokers(id) = '58': table 'trade_log' column 'buyer' still refers to it (foreign key 'trade_log_buyer_fkey')
```

**Speed note:** REFERENCES checks every new row. For very big imports (millions of trade_log rows) you may want to leave REFERENCES out, and check the data with a query instead.

## Change a table

| Statement | What it does |
|---|---|
| `ALTER TABLE t ADD COLUMN c TYPE [rules]` | Adds a column at the end. Old rows get NULL. |
| `ALTER TABLE t RENAME COLUMN a TO b` | Renames a column. |
| `ALTER TABLE t DROP COLUMN c` | Removes a column and its data. |
| `ALTER TABLE t ALTER COLUMN c TYPE LONG` | Changes the type of a column. Every row is checked first: when one value does not fit, nothing changes. |
| `ALTER TABLE t DEDUP ENABLE UPSERT KEYS (time, symbol)` | Gives a table a DEDUP KEY later. Rows with the same key are folded into one: the newest row is kept. `DEDUP DISABLE` takes the key away. |
| `ALTER TABLE t DROP PARTITION '2025', '2026-01'` | Deletes whole partitions (chapter 4). |
| `ALTER TABLE t DROP PARTITION OLDER THAN 6 MONTHS` | Deletes the partitions that ended more than 6 months ago. |
| `ALTER TABLE t SET TTL 90 DAYS` / `SET TTL NONE` | Drops old partitions by itself from now on (see below). |
| `TRUNCATE TABLE t` | Removes all rows. The table, its columns and indexes stay. |
| `RENAME TABLE a TO b` | Renames a table. |
| `DROP TABLE t` / `DROP TABLE IF EXISTS t` | Deletes a table and all its data. It is kept in the trash for 7 days, so `UNDROP TABLE t` can bring it back (chapter 21). |
| `CREATE TABLE IF NOT EXISTS t (...)` | Creates the table only if it is not there yet. |

The word `COLUMN` is optional: `ALTER TABLE t ADD c LONG` also works.

```sql
ALTER TABLE ticks ADD COLUMN volume LONG;
ALTER TABLE ticks RENAME COLUMN price TO ltp;
INSERT INTO ticks VALUES ('2026-09-10T11:01:00+05:45', 'CITY', 511, 300);
SELECT time, symbol, ltp, volume FROM ticks;
```

```text
table 'ticks' altered

table 'ticks' altered

1 row(s) inserted

time                     | symbol | ltp | volume
-------------------------+--------+-----+-------
2026-09-10T05:15:00.000Z | CITY   | 510 |   NULL
2026-09-10T05:15:00.000Z | CITY   | 510 |   NULL
2026-09-10T05:16:00.000Z | CITY   | 511 |    300
(3 rows, 0.2 ms)
```

Some columns cannot be dropped: the TIMESERIES column, SORT BY and DEDUP KEY columns, the PRIMARY KEY, columns that other tables REFERENCE, and columns used by a computed column.

```sql
ALTER TABLE ticks DROP COLUMN symbol;
```

```text
error: cannot drop column 'symbol' from table 'ticks': it is part of SORT BY
```

```sql
ALTER TABLE ticks DROP COLUMN volume;
RENAME TABLE ticks TO test_ticks;
DROP TABLE test_ticks;
DROP TABLE IF EXISTS test_ticks;
SHOW TABLES;
```

```text
table 'ticks' altered

table 'ticks' renamed to 'test_ticks'

table 'test_ticks' dropped; UNDROP TABLE test_ticks brings it back within 7 days

table 'test_ticks' does not exist

name         | kind       | partition | columns | rows
-------------+------------+-----------+---------+-----
accounts     | relational | NONE      |       6 |    3
brokers      | relational | NONE      |       2 |    3
trade_log    | timeseries | DAY       |       8 |    1
live_data    | timeseries | DAY       |       5 |    0
ochl_day     | timeseries | YEAR      |       7 |    1
ochl_minutes | timeseries | MONTH     |       7 |    1
securities   | relational | NONE      |       3 |    3
type_demo    | relational | NONE      |      12 |    2
(8 rows, 0.0 ms)
```

A table that another table REFERENCES cannot be dropped:

```sql
DROP TABLE brokers;
```

```text
error: cannot drop table 'brokers': column 'buyer' of table 'trade_log' REFERENCES it; drop that column or table first
```

### Keep only recent data

Live prices and ticks grow every day. Often you need only the last months. A **TTL** (time to live) drops old partitions by itself:

```sql
ALTER TABLE live_data SET TTL 90 DAYS;
```

```text
table 'live_data' drops partitions older than 90 DAYS
```

- KarelaDB checks once a minute. A partition goes when its **last** moment is older than the TTL. It never deletes single rows.
- `SHOW CREATE TABLE` shows the TTL. `ALTER TABLE live_data SET TTL NONE` turns it off.
- You can also give it when you create the table: `... TIMESERIES(timestamp) PARTITION BY DAY TTL 90 DAYS`.
- To drop old data once, by hand or from a timer, use `ALTER TABLE live_data DROP PARTITION OLDER THAN 90 DAYS`.

### What you cannot change

You cannot change the **PARTITION BY** or the **SORT BY** of a table, and you cannot change the type of a column that is the time column or part of SORT BY or DEDUP KEY. To change them, create a new table, copy the rows with `INSERT ... SELECT`, then drop the old table:

```sql
CREATE TABLE ochl_day_by_symbol (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY YEAR SORT BY (symbol, time);
INSERT INTO ochl_day_by_symbol SELECT time, symbol, close FROM ochl_day;
```

Copying a big table this way takes time and space. **Choose the table design carefully before you load big data.**

## Names

- Table and column names: letters, digits and `_`. They do not care about upper or lower case.
- A name that is a reserved word (like `order`, `from`, `select`) must be written in double quotes: `"order"`. Chapter 11 lists the reserved words.
- `time`, `date`, `timestamp`, `symbol` and `partition` are **not** reserved. You can use them as column names.

## Try it yourself

1. Create a time-series table `index_minutes` for stock index values: time, index name, value. One row per index per minute. Partition by month.
2. Create a relational table `sectors` with `name` as the primary key. Add a new column `sector_name` to `securities` that must point to `sectors(name)`.
3. Insert a stock index value at `2026-09-10T11:00:00+05:45` and again at `11:00:30` into your table from task 1, with plain `INSERT`. What happens?

<details>
<summary>Answers</summary>

1. ```sql
   CREATE TABLE index_minutes (
     time       TIMESTAMP ROUND 1m,
     index_name SYMBOL,
     value      DOUBLE
   ) TIMESERIES(time) PARTITION BY MONTH DEDUP KEY (index_name, time);
   ```
2. ```sql
   CREATE TABLE sectors (name STRING PRIMARY KEY);
   ALTER TABLE securities ADD COLUMN sector_name STRING REFERENCES sectors(name);
   ```
   Old rows get NULL, which is allowed. A value that is not in `sectors` is refused.
3. `ROUND 1m` makes both times `05:15:00` UTC. The second INSERT fails:
   `a row with index_name='MARKET', time='2026-09-10T05:15:00.000Z' already exists`. Use `INSERT OR REPLACE` to keep the newest value.

</details>

---

Next: [4. Writing data](04-writing-data.md)
