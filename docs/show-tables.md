# SHOW TABLES, COLUMNS, CREATE TABLE

> List the tables of a database, the columns of a table, its partitions, and the full CREATE TABLE statement - also with QuestDB's tables() and table_columns().

- Category: Tables
- Keywords: show tables, list tables, show columns, describe, describe table, table columns, schema, show create table, table definition, DDL, .tables, .schema, information\_schema, show partitions, partitions, QuestDB, tables(), table\_columns, table\_partitions, wal\_tables, upsertKey, designatedTimestamp
- See also: [CREATE TABLE](create-table.md), [ALTER, RENAME and DROP TABLE](alter-table.md), [Databases and the data folder](databases.md), [Views](views.md), [Indexes](indexes.md), [Saved functions](saved-functions.md), [Stored procedures](procedures.md), [Triggers](triggers.md), [Users and roles](users-and-roles.md)

These statements show what is **in** a database: which tables there are, which columns a table has, and how a table was made. They only read; they never change anything.

| Statement | Shows |
|---|---|
| `SHOW TABLES` | every table, its kind, partitions, columns and rows |
| `SHOW COLUMNS FROM t` | the columns of one table |
| `SHOW CREATE TABLE t` | the `CREATE TABLE` statement of one table |
| `SHOW PARTITIONS FROM t` | the partitions of one table: rows, time range, size |
| `tables()`, `table_columns('t')`, `wal_tables()` | the same facts with QuestDB's column names ([below](#questdb-meta)) |

Other `SHOW` statements: `SHOW DATABASES` ([databases](databases.md#show-databases)), `SHOW VIEWS` ([views](views.md)), `SHOW INDEXES` ([indexes](indexes.md)), `SHOW FUNCTIONS` ([saved functions](saved-functions.md)), `SHOW PROCEDURES` ([procedures](procedures.md)), `SHOW TRIGGERS` ([triggers](triggers.md)), `SHOW USERS` ([users and roles](users-and-roles.md)).

- **Notes:** KarelaDB has no `DESCRIBE`. `information_schema` and `pg_catalog` can be read like tables, and psql's `\d` works on the [PostgreSQL port](postgres-protocol.md#catalog). In `kareladb shell`, `.tables` is the same as `SHOW TABLES`, and `.schema t` shows `SHOW CREATE TABLE t`.

**Example: What is in the sample database** (sample data: sample)

```sql
SHOW TABLES;
SHOW COLUMNS FROM trade_log;
```

Result:

`SHOW TABLES`

| name (STRING) | kind (STRING) | partition (STRING) | columns (INT) | rows (LONG) |
|---|---|---|---|---|
| brokers | relational | NONE | 2 | 5 |
| live_data | timeseries | DAY | 12 | 12 |
| ochl_day | timeseries | YEAR | 7 | 57 |
| ochl_minutes | timeseries | MONTH | 7 | 956 |
| securities | relational | NONE | 3 | 5 |
| trade_log | timeseries | DAY | 8 | 32 |

(6 rows)

`SHOW COLUMNS FROM trade_log`

| name (STRING) | type (STRING) | primary_key (BOOL) | not_null (BOOL) | computed (BOOL) | references (STRING) |
|---|---|---|---|---|---|
| date | TIMESTAMP | false | false | false | NULL |
| transaction_id | LONG | false | false | false | NULL |
| symbol | SYMBOL | false | false | false | NULL |
| buyer | INT | false | false | false | brokers(id) |
| seller | INT | false | false | false | brokers(id) |
| quantity | LONG | false | false | false | NULL |
| rate | DOUBLE | false | false | false | NULL |
| amount | DOUBLE | false | false | true | NULL |

(8 rows)

<a id="show-tables"></a>

## SHOW TABLES

Syntax:

```sql
SHOW TABLES
```

Lists the tables of the current database, sorted by name. Views are not in this list (use `SHOW VIEWS`).

| Column | Type | Meaning |
|---|---|---|
| `name` | `STRING` | table name, spelled as in `CREATE TABLE` |
| `kind` | `STRING` | `relational` or `timeseries` |
| `partition` | `STRING` | `DAY`, `MONTH`, `YEAR`, or `NONE` (always `NONE` for relational tables) |
| `columns` | `LONG` | number of columns, computed columns included |
| `rows` | `LONG` | number of rows now |

- **Returns:** one row per table; `(0 rows)` for an empty database.
- **Notes:** the result can be used like any query result in scripts: `kareladb sql market "SHOW TABLES" --format csv`.

**Example: An app database with users, accounts and a ledger**

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE);
CREATE TABLE accounts (id INT PRIMARY KEY AUTO, user_id LONG NOT NULL REFERENCES users(id), balance DECIMAL(2) NOT NULL DEFAULT 0);
CREATE TABLE ledger (time TIMESTAMP, account INT, amount DECIMAL(2)) TIMESERIES(time) PARTITION BY MONTH;
INSERT INTO users (email) VALUES ('ram@example.com'), ('sita@example.com');
INSERT INTO accounts (user_id, balance) VALUES (1, 1000.00);
```

```sql
SHOW TABLES;
```

Result:

| name (STRING) | kind (STRING) | partition (STRING) | columns (INT) | rows (LONG) |
|---|---|---|---|---|
| accounts | relational | NONE | 3 | 1 |
| ledger | timeseries | MONTH | 3 | 0 |
| users | relational | NONE | 2 | 2 |

(3 rows)

**Command line: The same list from the shell** (sample data: sample)

```bash
kareladb shell market
> .tables
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> name         | kind       | partition | columns | rows
-------------+------------+-----------+---------+-----
brokers      | relational | NONE      |       2 |    5
live_data    | timeseries | DAY       |      12 |   12
ochl_day     | timeseries | YEAR      |       7 |   57
ochl_minutes | timeseries | MONTH     |       7 |  956
securities   | relational | NONE      |       3 |    5
trade_log    | timeseries | DAY       |       8 |   32
(6 rows, 0.0 ms)
kareladb>
```

<a id="show-columns"></a>

## SHOW COLUMNS FROM

Syntax:

```sql
SHOW COLUMNS FROM table
```

Lists the columns of one table, in table order.

| Column | Type | Meaning |
|---|---|---|
| `name` | `STRING` | column name |
| `type` | `STRING` | column type, like `LONG`, `DECIMAL(2)`, `TIMESTAMP` |
| `primary_key` | `BOOL` | `true` for the `PRIMARY KEY` column |
| `not_null` | `BOOL` | `true` when the column has `NOT NULL` |
| `computed` | `BOOL` | `true` for a computed column (`AS (...)`) |
| `references` | `STRING` | `table(column)` when the column has `REFERENCES`, else `NULL` |

- **Notes:** `not_null` is `false` for a `PRIMARY KEY` column without the words `NOT NULL`, even though a key can never be `NULL`. `UNIQUE`, `DEFAULT`, `ROUND`, `CHECK`, `SORT BY` and `DEDUP KEY` are not shown here: use `SHOW CREATE TABLE`. Works for tables only, not for views.

**Example: The trade_log table: references and a computed column** (sample data: sample)

```sql
SHOW COLUMNS FROM trade_log;
```

Result:

| name (STRING) | type (STRING) | primary_key (BOOL) | not_null (BOOL) | computed (BOOL) | references (STRING) |
|---|---|---|---|---|---|
| date | TIMESTAMP | false | false | false | NULL |
| transaction_id | LONG | false | false | false | NULL |
| symbol | SYMBOL | false | false | false | NULL |
| buyer | INT | false | false | false | brokers(id) |
| seller | INT | false | false | false | brokers(id) |
| quantity | LONG | false | false | false | NULL |
| rate | DOUBLE | false | false | false | NULL |
| amount | DOUBLE | false | false | true | NULL |

(8 rows)

**Example: Forum posts that point to their parent post**

Setup:

```sql
CREATE TABLE posts (id LONG PRIMARY KEY AUTO, parent_id LONG REFERENCES posts(id), author STRING NOT NULL, body STRING NOT NULL, words LONG AS (length(body)));
```

```sql
SHOW COLUMNS FROM posts;
```

Result:

| name (STRING) | type (STRING) | primary_key (BOOL) | not_null (BOOL) | computed (BOOL) | references (STRING) |
|---|---|---|---|---|---|
| id | LONG | true | false | false | NULL |
| parent_id | LONG | false | false | false | posts(id) |
| author | STRING | false | true | false | NULL |
| body | STRING | false | true | false | NULL |
| words | LONG | false | false | true | NULL |

(5 rows)

**Example: A table that does not exist** (shows an error)

```sql
SHOW COLUMNS FROM userz;
```

Result:

Error: `table 'userz' does not exist`

**Example: FROM is needed** (shows an error)

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY);
```

```sql
SHOW COLUMNS users;
```

Result:

Error: `line 1, column 14: expected FROM after SHOW COLUMNS but found 'users'`

<a id="show-create-table"></a>

## SHOW CREATE TABLE

Syntax:

```sql
SHOW CREATE TABLE table
```

Gives the full `CREATE TABLE` statement of a table, with every rule KarelaDB keeps: types, keys, defaults, `ROUND`, computed columns, `REFERENCES`, `CHECK` rules with their names, and the table options with their **default values filled in** (like `PARTITION BY DAY` and `SORT BY (symbol, time)`).

| Column | Type | Meaning |
|---|---|---|
| `create_sql` | `STRING` | the statement; newer KarelaDB versions add one more row for each index: `CREATE INDEX ...` |

- **Returns:** the text you can run in another database to make the same (empty) table.
- **Notes:** in `kareladb sql` and `kareladb shell` table format, long text is cut after 48 characters. Use `--format csv` (or `.format csv` in the shell) to see all of it.

**Example: The daily candles table of the sample data** (sample data: sample)

```sql
SHOW CREATE TABLE ochl_day;
```

Result:

| create_sql (STRING) |
|---|
| CREATE TABLE ochl_day (   time TIMESTAMP ROUND 1d,   symbol SYMBOL,   open DOUBLE,   high DOUBLE,   low DOUBLE,   close DOUBLE,   volume DOUBLE ) TIMESERIES(time) PARTITION BY YEAR SORT BY (symbol,... |

(1 row)

**Example: Defaults filled in: PARTITION BY and SORT BY**

Setup:

```sql
CREATE TABLE live_data (timestamp TIMESTAMP, symbol SYMBOL, ltp DOUBLE) TIMESERIES(timestamp);
```

```sql
SHOW CREATE TABLE live_data;
```

Result:

| create_sql (STRING) |
|---|
| CREATE TABLE live_data (   timestamp TIMESTAMP,   symbol SYMBOL,   ltp DOUBLE ) TIMESERIES(timestamp) PARTITION BY DAY SORT BY (symbol, timestamp) |

(1 row)

**Example: An accounts table with a CHECK rule and an index**

Setup:

```sql
CREATE TABLE accounts (
  id INT PRIMARY KEY AUTO,
  email STRING NOT NULL UNIQUE,
  balance DECIMAL(2) NOT NULL DEFAULT 0 CHECK (balance >= 0)
);
CREATE INDEX accounts_balance ON accounts (balance);
```

```sql
SHOW CREATE TABLE accounts;
```

Result:

| create_sql (STRING) |
|---|
| CREATE TABLE accounts (   id INT PRIMARY KEY AUTO,   email STRING NOT NULL UNIQUE,   balance DECIMAL(2) NOT NULL DEFAULT 0,   CONSTRAINT accounts_balance_check CHECK (balance >= 0) ) |
| CREATE INDEX accounts_balance ON accounts (balance) |

(2 rows)

**Command line: See the whole text in CSV format** (sample data: sample)

```bash
kareladb sql market "SHOW CREATE TABLE trade_log" --format csv
```

Output:

```text
create_sql
"CREATE TABLE trade_log (
  date TIMESTAMP ROUND 1d,
  transaction_id LONG,
  symbol SYMBOL,
  buyer INT REFERENCES brokers(id),
  seller INT REFERENCES brokers(id),
  quantity LONG,
  rate DOUBLE,
  amount DOUBLE AS (quantity * rate)
) TIMESERIES(date) PARTITION BY DAY SORT BY (symbol, date) DEDUP KEY (date, transaction_id)"
```

<a id="show-partitions"></a>

## SHOW PARTITIONS FROM

Syntax:

```sql
SHOW PARTITIONS FROM table
SELECT * FROM table_partitions('table')
```

Lists the partitions of one table, oldest first, with QuestDB's columns. Both forms give the same rows.

| Column | Type | Meaning |
|---|---|---|
| `index` | `INT` | 0 for the first partition, then 1, 2, ... |
| `partitionBy` | `STRING` | `DAY`, `MONTH`, `YEAR` or `NONE` |
| `name` | `STRING` | `2026-09-24`, `2026-09`, `2026`; `default` for a table without time partitions |
| `minTimestamp`, `maxTimestamp` | `TIMESTAMP` | the first and last time in it; `NULL` for a table without a time column |
| `numRows` | `LONG` | rows now |
| `diskSize` | `LONG` | bytes: its file, plus its new rows still in the log |
| `diskSizeHuman` | `STRING` | the same, like `12.4 KiB` |
| `readOnly`, `active`, `attached`, `detached`, `attachable` | `BOOL` | `active` is `true` for the newest partition; KarelaDB has no read-only or detached partitions |

- **Notes:** it needs the right to read the table (the row counts and times tell about the rows).

**Example: Trades split by day**

Setup:

```sql
CREATE TABLE trades (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO trades VALUES ('2026-09-24T05:00:00Z', 'CITY', 10), ('2026-09-24T05:03:00Z', 'CITY', 11), ('2026-09-25T05:00:00Z', 'VOLT', 50);
```

```sql
SHOW PARTITIONS FROM trades;
```

Result:

| index (INT) | partitionBy (STRING) | name (STRING) | minTimestamp (TIMESTAMP) | maxTimestamp (TIMESTAMP) | numRows (LONG) | diskSize (LONG) | diskSizeHuman (STRING) | readOnly (BOOL) | active (BOOL) | attached (BOOL) | detached (BOOL) | attachable (BOOL) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | DAY | 2026-09-24 | 2026-09-24T05:00:00.000Z | 2026-09-24T05:03:00.000Z | 2 | 548 | 548 B | false | false | true | false | false |
| 1 | DAY | 2026-09-25 | 2026-09-25T05:00:00.000Z | 2026-09-25T05:00:00.000Z | 1 | 520 | 520 B | false | true | true | false | false |

(2 rows)

<a id="questdb-meta"></a>

## QuestDB's meta functions

Apps written for QuestDB read the schema with functions in `FROM`. KarelaDB has them with QuestDB 9.4.3's column names and types, so that code runs unchanged.

| Function | One row per | Columns |
|---|---|---|
| `tables()` | table | `id`, `table_name`, `designatedTimestamp`, `partitionBy`, `maxUncommittedRows`, `o3MaxLag`, `walEnabled`, `directoryName`, `dedup`, `ttlValue`, `ttlUnit`, `matView` |
| `table_columns('t')` | column of `t` | `column`, `type`, `indexed`, `indexBlockCapacity`, `symbolCached`, `symbolCapacity`, `designated`, `upsertKey` |
| `wal_tables()` | table | `name`, `suspended`, `writerTxn`, `bufferedTxnSize`, `sequencerTxn`, `errorTag`, `errorMessage`, `memoryPressure` |
| `table_partitions('t')` | partition of `t` | as [SHOW PARTITIONS](#show-partitions) |
| `information_schema.tables()` | table or view | the same as `information_schema.tables` |

- `designatedTimestamp` is the time column of a `TIMESERIES` table, `NULL` for other tables. `dedup` is `true` when the table has a `DEDUP KEY`, and `upsertKey` marks its columns.
- `indexed` is `true` for a column with an index of its own (`ALTER TABLE t ALTER COLUMN c ADD INDEX`, or `CREATE INDEX` on that one column).
- `ttlValue`/`ttlUnit` show a TTL as QuestDB does: `SET TTL 14 DAYS` shows `2` `WEEK`; no TTL shows `0` `HOUR`.
- `maxUncommittedRows` (500000), `o3MaxLag` (600000000) and the symbol sizes (256) are QuestDB's defaults: KarelaDB has no such setting per table.
- `wal_tables()`: a KarelaDB commit is applied before it returns, so `writerTxn` always equals `sequencerTxn` and `suspended` is `false`. Code that waits for the two to match goes on at once.

**Example: What a rebuild reads first: time column, partitions, dedup keys**

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY DEDUP KEY (symbol, time);
```

```sql
SELECT table_name, designatedTimestamp, partitionBy, dedup FROM tables() WHERE table_name = 'ticks';
SELECT "column", type, indexed, designated, upsertKey FROM table_columns('ticks');
SELECT name, suspended, writerTxn = sequencerTxn AS caught_up FROM wal_tables() WHERE name = 'ticks';
```

Result:

`SELECT table_name, designatedTimestamp, partitionBy, dedup FROM tables() WHERE table_name = 'ticks'`

| table_name (STRING) | designatedTimestamp (STRING) | partitionBy (STRING) | dedup (BOOL) |
|---|---|---|---|
| ticks | time | DAY | true |

(1 row)

`SELECT column, type, indexed, designated, upsertKey FROM table_columns('ticks')`

| column (STRING) | type (STRING) | indexed (BOOL) | designated (BOOL) | upsertKey (BOOL) |
|---|---|---|---|---|
| time | TIMESTAMP | false | true | true |
| symbol | SYMBOL | false | false | true |
| price | DOUBLE | false | false | false |

(3 rows)

`SELECT name, suspended, writerTxn = sequencerTxn AS caught_up FROM wal_tables() WHERE name = 'ticks'`

| name (STRING) | suspended (BOOL) | caught_up (BOOL) |
|---|---|---|
| ticks | false | true |

(1 row)

**Example: A table that does not exist** (shows an error)

```sql
SELECT * FROM table_columns('tickz');
```

Result:

Error: `table 'tickz' does not exist`
