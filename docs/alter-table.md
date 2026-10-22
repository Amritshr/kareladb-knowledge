# ALTER, RENAME and DROP TABLE

> Add, drop, rename and change columns, drop partitions, set a TTL, add and drop rules and keys, turn DEDUP on or off, rename and drop tables.

- Category: Tables
- Keywords: alter table, change table, add column, new column, drop column, remove column, rename column, COLUMN, TO, drop partition, delete old data, OLDER THAN, DROP PARTITION LIST, DROP PARTITION WHERE, add constraint, add check, drop constraint, rename table, drop table, delete table, remove table, IF EXISTS, IF NOT EXISTS, ALTER COLUMN, SET DATA TYPE, TYPE ... USING, USING, change column type, SET DEFAULT, DROP DEFAULT, SET NOT NULL, DROP NOT NULL, ADD UNIQUE, ADD FOREIGN KEY, FOREIGN KEY, NOT VALID, DEDUP ENABLE, DEDUP DISABLE, DEDUP ENABLE UPSERT KEYS, SET (dedup\_insert, RESET (dedup\_insert, SET (compression, RESET (compression, compression, SET (resident, RESET (resident, resident, keep in memory, ALTER TABLE RENAME TO, schema change, migration
- See also: [CREATE TABLE](create-table.md), [Constraints](constraints.md), [SHOW TABLES, COLUMNS, CREATE TABLE](show-tables.md), [UPDATE and DELETE](update-delete.md), [Triggers](triggers.md), [Indexes](indexes.md), [Partitions, SORT BY and DEDUP KEY](partitions-and-dedup.md), [Cold storage (S3, MinIO, R2, B2)](cold-storage.md)

Tables change when your app grows: a new column for the phone number, a better column name, old data to remove. Most of these statements change a table **without** copying its rows; changing a column's type and turning DEDUP on or off rewrite the rows.

| Statement | What it does |
|---|---|
| `ALTER TABLE t ADD [COLUMN] c TYPE [rules]` | adds a column at the end |
| `ALTER TABLE t DROP [COLUMN] c` | removes a column and its data |
| `ALTER TABLE t RENAME [COLUMN] a TO b` | renames a column |
| `ALTER TABLE t ALTER [COLUMN] c TYPE LONG` | changes a column's type; also `SET`/`DROP DEFAULT`, `SET`/`DROP NOT NULL` |
| `ALTER TABLE t DROP PARTITION 'key', ...` | deletes whole days, months or years of a time-series table |
| `ALTER TABLE t DROP PARTITION OLDER THAN 6 MONTHS` | deletes the partitions that ended more than 6 months ago, once, now |
| `ALTER TABLE t DROP PARTITION WHERE time < '2026-09-01'` | deletes the partitions whose whole time range matches (QuestDB's form) |
| `ALTER TABLE t SET TTL 90 DAYS` | drops partitions older than 90 days, by itself, from now on |
| `ALTER TABLE t ADD [CONSTRAINT name] CHECK (...)` | adds a rule for every row |
| `ALTER TABLE t ADD [CONSTRAINT name] UNIQUE (...)` or `FOREIGN KEY (...) REFERENCES ...` | adds a key |
| `ALTER TABLE t DROP CONSTRAINT name` | removes a rule or a key |
| `ALTER TABLE t DEDUP ENABLE UPSERT KEYS (...)` / `DEDUP DISABLE` | sets or removes the `DEDUP KEY` of a time-series table |
| `ALTER TABLE t SET (dedup_insert = 'upsert')` / `RESET (dedup_insert)` | a plain `INSERT` of a key that is there replaces the row, or fails again ([dedup_insert](partitions-and-dedup.md#dedup-insert)) |
| `ALTER TABLE t SET (compression = on)` / `SET (compression = off)` / `RESET (compression)` | stores the sealed partitions packed, about 5 times smaller on disk, or plain again ([compression](partitions-and-dedup.md#compression)) |
| `ALTER TABLE t SET (cold_storage = 'archive', cold_after = '90 days')` / `RESET (cold_storage)` | moves partitions older than 90 days to an S3-compatible object store, where queries still read them ([cold storage](cold-storage.md)) |
| `ALTER TABLE t MOVE PARTITION '2025-01' TO COLD` / `FROM COLD` | moves a partition to the table's cold store now, or brings it back as a local file ([cold storage](cold-storage.md#move-partition)) |
| `ALTER TABLE t SET (resident = on)` / `SET (resident = off)` / `RESET (resident)` | keeps the table's partitions in memory once read, whoever needs memory ([resident](#resident)) |
| `RENAME TABLE a TO b`, `ALTER TABLE a RENAME TO b` | renames a table |
| `DROP TABLE [IF EXISTS] t` | deletes a table and all its rows |

What you **cannot** change: `PARTITION BY`, `SORT BY`, the kind of table, and the type of the time column, of a `SORT BY` or `DEDUP KEY` column and of the `PRIMARY KEY`. To change those, make a new table with [CREATE TABLE ... AS](create-table.md#create-table-as) or `INSERT INTO new SELECT ... FROM old`, and drop the old table. `ALTER TABLE ... ENABLE TRIGGER` and `DISABLE TRIGGER` are explained in [triggers](triggers.md).

Several actions can go in one statement, with commas: `ALTER TABLE t ADD COLUMN a INT, DROP COLUMN b`. `DROP PARTITION` must be on its own. These statements cannot be used inside `BEGIN ... COMMIT`.

**Example: The users table of an app grows**

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE);
INSERT INTO users (email) VALUES ('ram@example.com'), ('sita@example.com');
```

```sql
ALTER TABLE users ADD COLUMN phone STRING;
ALTER TABLE users ADD COLUMN verified BOOL NOT NULL DEFAULT FALSE;
ALTER TABLE users RENAME COLUMN email TO login_email;
SELECT id, login_email, phone, verified FROM users;
```

Result:

`ALTER TABLE users ADD COLUMN phone STRING`

```text
table 'users' altered
```

`ALTER TABLE users ADD COLUMN verified BOOL NOT NULL DEFAULT FALSE`

```text
table 'users' altered
```

`ALTER TABLE users RENAME COLUMN email TO login_email`

```text
table 'users' altered
```

`SELECT id, login_email, phone, verified FROM users`

| id (LONG) | login_email (STRING) | phone (STRING) | verified (BOOL) |
|---|---|---|---|
| 1 | ram@example.com | NULL | false |
| 2 | sita@example.com | NULL | false |

(2 rows)

<a id="add-column"></a>

## ADD COLUMN

Syntax:

```sql
ALTER TABLE table ADD [COLUMN] [IF NOT EXISTS] column TYPE [NOT NULL] [UNIQUE] [DEFAULT expr]
                                          [REFERENCES table(column)] [ROUND interval]
                                          [AS (expr) | GENERATED ALWAYS AS (expr) STORED]
                                          [[CONSTRAINT name] CHECK (condition)]
```

Adds a new column **at the end** of the table. The word `COLUMN` is optional.

- Rows already in the table get the `DEFAULT` value, or `NULL` when there is no default.
- A [stored generated column](create-table.md#generated) (`GENERATED ALWAYS AS (...) STORED`) is worked out for every row already in the table: the rows are written again, so this takes longer on a big table.
- **Returns:** `table 'name' altered`.
- **Notes:** a `NOT NULL` column needs a `DEFAULT` (old rows need a value). You cannot add a `PRIMARY KEY` column. With `IF NOT EXISTS`, a column that is already there is not an error. A default like `now()` or `gen_random_uuid()` is worked out **once** for all old rows, so they all get the same value; new rows get their own.
- **Notes:** `INSERT INTO t VALUES (...)` without a column list now needs a value for the new column too.

**Example: Add a phone number and a verified flag**

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL);
INSERT INTO users (email) VALUES ('ram@example.com');
```

```sql
ALTER TABLE users ADD COLUMN phone STRING;
ALTER TABLE users ADD verified BOOL NOT NULL DEFAULT FALSE;
INSERT INTO users (email, phone, verified) VALUES ('sita@example.com', '9800000000', TRUE);
SELECT id, email, phone, verified FROM users;
```

Result:

`ALTER TABLE users ADD COLUMN phone STRING`

```text
table 'users' altered
```

`ALTER TABLE users ADD COLUMN verified BOOL NOT NULL DEFAULT FALSE`

```text
table 'users' altered
```

`INSERT INTO users (email, phone, verified) VALUES ('sita@example.com', '9800000000', TRUE)`

```text
1 row(s) inserted
```

`SELECT id, email, phone, verified FROM users`

| id (LONG) | email (STRING) | phone (STRING) | verified (BOOL) |
|---|---|---|---|
| 1 | ram@example.com | NULL | false |
| 2 | sita@example.com | 9800000000 | true |

(2 rows)

**Example: Add a sector link to securities (REFERENCES)**

Setup:

```sql
CREATE TABLE sectors (name STRING PRIMARY KEY);
CREATE TABLE securities (symbol SYMBOL PRIMARY KEY, name STRING NOT NULL);
INSERT INTO sectors VALUES ('Banking'), ('Energy');
INSERT INTO securities VALUES ('CITY', 'City Bank Limited');
```

```sql
ALTER TABLE securities ADD COLUMN sector STRING REFERENCES sectors(name);
UPDATE securities SET sector = 'Banking' WHERE symbol = 'CITY';
SELECT symbol, name, sector FROM securities;
```

Result:

`ALTER TABLE securities ADD COLUMN sector STRING REFERENCES sectors(name)`

```text
table 'securities' altered
```

`UPDATE securities SET sector = 'Banking' WHERE symbol = 'CITY'`

```text
1 row(s) updated
```

`SELECT symbol, name, sector FROM securities`

| symbol (SYMBOL) | name (STRING) | sector (STRING) |
|---|---|---|
| CITY | City Bank Limited | Banking |

(1 row)

**Example: Add a computed column to the trade log**

Setup:

```sql
CREATE TABLE trade_log (date TIMESTAMP, transaction_id LONG, quantity LONG, rate DOUBLE) TIMESERIES(date) DEDUP KEY (date, transaction_id);
INSERT INTO trade_log VALUES ('2026-09-10', 100010, 50, 517.0);
```

```sql
ALTER TABLE trade_log ADD COLUMN amount DOUBLE AS (quantity * rate);
SELECT transaction_id, quantity, rate, amount FROM trade_log;
```

Result:

`ALTER TABLE trade_log ADD COLUMN amount DOUBLE AS (quantity * rate)`

```text
table 'trade_log' altered
```

`SELECT transaction_id, quantity, rate, amount FROM trade_log`

| transaction_id (LONG) | quantity (LONG) | rate (DOUBLE) | amount (DOUBLE) |
|---|---|---|---|
| 100010 | 50 | 517 | 25850 |

(1 row)

**Example: NOT NULL without a DEFAULT** (shows an error)

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL);
```

```sql
ALTER TABLE users ADD COLUMN verified BOOL NOT NULL;
```

Result:

Error: `cannot add column 'verified' to table 'users': rows already in the table need a value for a NOT NULL column; expected NOT NULL DEFAULT <value>`

<a id="drop-column"></a>

## DROP COLUMN

Syntax:

```sql
ALTER TABLE table DROP [COLUMN] [IF EXISTS] column
```

Removes a column and all its values. The word `COLUMN` is optional.

These columns **cannot** be dropped:

| Column | Message says |
|---|---|
| the `TIMESERIES` column | `it is the TIMESERIES column` |
| a `SORT BY` or `DEDUP KEY` column | `it is part of SORT BY` / `DEDUP KEY` |
| the `PRIMARY KEY` | `it is the PRIMARY KEY` |
| a column that another table `REFERENCES` | `... REFERENCES it; drop that column first` |
| a column used by a computed column, a `CHECK` or an index | `... uses it` |
| the only column of the table | `drop the table instead` |

- **Returns:** `table 'name' altered`.
- **Notes:** there is no undo. Make a backup first when the data matters ([backup](backup-and-safety.md)). With `IF EXISTS`, a column that is not there is not an error.

**Example: Remove a column nobody uses**

Setup:

```sql
CREATE TABLE news (id LONG PRIMARY KEY AUTO, title STRING NOT NULL, old_category STRING);
INSERT INTO news (title, old_category) VALUES ('City Bank profit rises 18%', 'banking');
```

```sql
ALTER TABLE news DROP COLUMN old_category;
SELECT * FROM news;
```

Result:

`ALTER TABLE news DROP COLUMN old_category`

```text
table 'news' altered
```

`SELECT * FROM news`

| id (LONG) | title (STRING) |
|---|---|
| 1 | City Bank profit rises 18% |

(1 row)

**Example: The symbol is part of the sort order** (shows an error)

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time);
```

```sql
ALTER TABLE ticks DROP COLUMN symbol;
```

Result:

Error: `cannot drop column 'symbol' from table 'ticks': it is part of SORT BY`

**Example: A computed column still uses it** (shows an error)

Setup:

```sql
CREATE TABLE trade_log (quantity LONG, rate DOUBLE, amount DOUBLE AS (quantity * rate));
```

```sql
ALTER TABLE trade_log DROP COLUMN rate;
```

Result:

Error: `cannot drop column 'rate' from table 'trade_log': computed column 'amount' uses it in AS (quantity * rate); drop 'amount' first`

<a id="rename-column"></a>

## RENAME COLUMN

Syntax:

```sql
ALTER TABLE table RENAME [COLUMN] old_name TO new_name
```

Gives a column a new name. The rows do not change. The word `COLUMN` is optional.

- KarelaDB also renames the column inside computed columns, `CHECK` rules, and `REFERENCES` of other tables.
- **Returns:** `table 'name' altered`.
- **Notes:** views, saved functions, procedures and triggers that use the old name are **not** changed; fix them yourself. Your app's SQL must use the new name too.

**Example: Rename price to ltp in a live prices table**

Setup:

```sql
CREATE TABLE live_prices (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time);
INSERT INTO live_prices VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 513.0);
```

```sql
ALTER TABLE live_prices RENAME COLUMN price TO ltp;
SELECT time, symbol, ltp FROM live_prices;
```

Result:

`ALTER TABLE live_prices RENAME COLUMN price TO ltp`

```text
table 'live_prices' altered
```

`SELECT time, symbol, ltp FROM live_prices`

| time (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | CITY | 513 |

(1 row)

**Example: A REFERENCES of another table follows the new name**

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING);
CREATE TABLE trades (id LONG PRIMARY KEY, buyer INT REFERENCES brokers(id));
```

```sql
ALTER TABLE brokers RENAME id TO broker_no;
SHOW COLUMNS FROM trades;
```

Result:

`ALTER TABLE brokers RENAME COLUMN id TO broker_no`

```text
table 'brokers' altered
```

`SHOW COLUMNS FROM trades`

| name (STRING) | type (STRING) | primary_key (BOOL) | not_null (BOOL) | computed (BOOL) | references (STRING) |
|---|---|---|---|---|---|
| id | LONG | true | false | false | NULL |
| buyer | INT | false | false | false | brokers(broker_no) |

(2 rows)

**Example: The new name is already used** (shows an error)

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY, email STRING, mail STRING);
```

```sql
ALTER TABLE users RENAME COLUMN mail TO email;
```

Result:

Error: `cannot rename column 'mail' of table 'users' to 'email': the table already has a column named 'email'`

<a id="alter-column"></a>

## ALTER COLUMN

Syntax:

```sql
ALTER TABLE table ALTER [COLUMN] column [SET DATA] TYPE type [USING expression]
ALTER TABLE table ALTER [COLUMN] column SET DEFAULT expression
ALTER TABLE table ALTER [COLUMN] column DROP DEFAULT
ALTER TABLE table ALTER [COLUMN] column SET NOT NULL
ALTER TABLE table ALTER [COLUMN] column DROP NOT NULL
```

Changes one column. These are the PostgreSQL forms, so a PostgreSQL migration script runs.

| Form | What it does |
|---|---|
| `TYPE type` | converts every stored value to the new type, like `CAST`. It rewrites the rows |
| `TYPE type USING expression` | the new value of each row is `expression`, over the columns of that row |
| `SET DEFAULT` / `DROP DEFAULT` | the value new rows get when they do not give one; old rows keep theirs |
| `SET NOT NULL` | from now on the column needs a value. Refused while a row has `NULL` there |
| `DROP NOT NULL` | the column may be `NULL` again |

- **Returns:** `table 'name' altered`, with `(N row change(s) written)` when rows were rewritten, or `table 'name' not changed (already as asked)`.
- **Notes:**
  - When one stored value does not fit the new type, nothing changes and the message names the value: `12.7 is not a whole number`. Write a `USING` that fits, or fix the rows first.
  - The time column, a `SORT BY` column and a `DEDUP KEY` column cannot change type: the rows are stored by them, and KarelaDB refuses. A `PRIMARY KEY` column can: KarelaDB writes the whole table again in the new key order, in one commit (it takes as long as a copy of the table). A change that makes two keys equal, such as `TYPE INT USING round(id)`, is refused with "(duplicate)".
  - An index on the column is built again for the new type.
  - `COLLATE` after the type is read and ignored. Write `COLLATE` in the query instead ([ORDER BY](order-by-limit.md#collate)).

**Example: Ages were saved as text: make them numbers**

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING, age STRING);
INSERT INTO users (email, age) VALUES ('ram@example.com', '31'), ('sita@example.com', 'unknown');
```

```sql
ALTER TABLE users ALTER COLUMN age TYPE INT USING CASE WHEN age = 'unknown' THEN NULL ELSE CAST(age AS INT) END;
SELECT id, email, age FROM users ORDER BY id;
```

Result:

`ALTER TABLE users ALTER COLUMN age TYPE INT USING CASE WHEN age = 'unknown' THEN NULL ELSE CAST(age `

```text
table 'users' altered (2 row change(s) written)
```

`SELECT id, email, age FROM users ORDER BY id`

| id (LONG) | email (STRING) | age (INT) |
|---|---|---|
| 1 | ram@example.com | 31 |
| 2 | sita@example.com | NULL |

(2 rows)

**Example: A default for new rows, then a NOT NULL rule**

Setup:

```sql
CREATE TABLE posts (id LONG PRIMARY KEY AUTO, author STRING, lang STRING);
INSERT INTO posts (author, lang) VALUES ('ram', 'en');
```

```sql
ALTER TABLE posts ALTER COLUMN lang SET DEFAULT 'ne';
ALTER TABLE posts ALTER COLUMN author SET NOT NULL;
INSERT INTO posts (author) VALUES ('sita');
SELECT id, author, lang FROM posts ORDER BY id;
```

Result:

`ALTER TABLE posts ALTER COLUMN lang SET DEFAULT 'ne'`

```text
table 'posts' altered
```

`ALTER TABLE posts ALTER COLUMN author SET NOT NULL`

```text
table 'posts' altered
```

`INSERT INTO posts (author) VALUES ('sita')`

```text
1 row(s) inserted
```

`SELECT id, author, lang FROM posts ORDER BY id`

| id (LONG) | author (STRING) | lang (STRING) |
|---|---|---|
| 1 | ram | en |
| 2 | sita | ne |

(2 rows)

**Example: A value that does not fit the new type** (shows an error)

Setup:

```sql
CREATE TABLE prices (id INT PRIMARY KEY, price DOUBLE);
INSERT INTO prices VALUES (1, 12.7);
```

```sql
ALTER TABLE prices ALTER COLUMN price TYPE INT;
```

Result:

Error: `cannot change column 'price' of table 'prices': a row already there does not fit (column 'price' (INT): 12.7 is not a whole number)`

**Example: SET NOT NULL while a row has NULL** (shows an error)

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING);
INSERT INTO users (email) VALUES ('ram@example.com'), (NULL);
```

```sql
ALTER TABLE users ALTER COLUMN email SET NOT NULL;
```

Result:

Error: `column 'email' of table 'users' contains NULL values; set them first (UPDATE ... SET email = ... WHERE email IS NULL)`

**Example: A SORT BY column keeps its type** (shows an error)

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, qty INT) TIMESERIES(time);
```

```sql
ALTER TABLE ticks ALTER COLUMN symbol TYPE STRING;
```

Result:

Error: `cannot alter column 'symbol' of table 'ticks': it is the TIMESERIES column or part of SORT BY / DEDUP KEY`

<a id="drop-partition"></a>

## DROP PARTITION

Syntax:

```sql
ALTER TABLE table DROP PARTITION [LIST] 'key' [, 'key' ...]
ALTER TABLE table DROP PARTITION OLDER THAN n HOURS | DAYS | WEEKS | MONTHS | YEARS
ALTER TABLE table DROP PARTITION WHERE time_column < '2026-09-01'
```

Deletes whole partitions of a time-series table: all rows of that day, month or year. It is much faster than `DELETE` for old data. `OLDER THAN` works out the keys itself, by the same rule as a [TTL](#set-ttl): a partition goes when its **last** moment is more than that long ago. It is the form for a [timer](timers.md) that cleans up on a set day, where a TTL cleans up by itself all the time.

`LIST` and `WHERE` are QuestDB's forms. `LIST 'a', 'b'` is the same as `'a', 'b'`. `WHERE` drops each partition whose **whole** time range matches the condition:

| `WHERE` | Partitions dropped |
|---|---|
| `time < '2026-09-22'` (a day boundary, DAY partitions) | every day before 2026-09-22 |
| `time < '2026-09-22T12:00'` (inside a day) | every day before 2026-09-22; the day 2026-09-22 is **kept** and named in the answer |
| `time IN '2026-08' OR time >= '2026-09-20'` | August, and every day from 2026-09-20 on |

- The condition may only compare the time column with fixed times: `=`, `<>`, `<`, `<=`, `>`, `>=`, `BETWEEN`, `IN (...)`, `IN '2026-09'`, joined by `AND`, `OR` and `NOT`. `now()` and `dateadd('d', -30, now())` count as fixed. Anything else (another column, a function of the time column) is an error, and nothing is dropped.
- A partition the condition cuts through is kept whole, because dropping it would delete rows the condition does not name. Delete those rows with [DELETE](update-delete.md#delete). QuestDB only tests a partition's first moment, so it would drop that partition too.
- **Returns (WHERE):** `N partition(s) of 'table' dropped`, then `; kept partition(s) only part of which matches: ...` when there are some; `no partition of 'table' matches as a whole` when nothing goes.
- The partitions it finds are written to the database log by name, so a restart or power cut repeats exactly the same drop.

| Table has | Partition keys look like |
|---|---|
| `PARTITION BY YEAR` | `'2025'` |
| `PARTITION BY MONTH` | `'2026-08'` |
| `PARTITION BY DAY` | `'2026-09-09'` |

- The keys are **UTC** dates, in single quotes.
- **Returns:** `N partition(s) of 'table' dropped`, or for `OLDER THAN` with nothing that old, `no partition of 'table' is older than 6 MONTHS`.
- **Notes:** a key that does not exist is an error, and the message lists the keys that do. A relational table and a table with `PARTITION BY NONE` have no partitions to drop; use [DELETE](update-delete.md#delete) or [TRUNCATE](update-delete.md#truncate).
- **Notes:** with [PARTITION BY YEAR, SYMBOL(col)](partitions-and-dedup.md#partition-by-symbol) the key is the time part: `'2025'` drops every symbol of 2025.
- **Notes:** it answers at once, even for hundreds of partitions on a busy database. The rows are gone for every query straight away; their files move to the database's `_trash` a moment later, in the background.

**Example: Remove the 2025 daily candles**

Setup:

```sql
CREATE TABLE ochl_day (time TIMESTAMP ROUND 1d, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (symbol, time);
INSERT INTO ochl_day VALUES ('2025-12-31', 'CITY', 542.4), ('2026-09-10', 'CITY', 504.9);
```

```sql
SELECT count(*) AS rows_2025 FROM ochl_day WHERE time IN '2025';
ALTER TABLE ochl_day DROP PARTITION '2025';
SELECT time, symbol, close FROM ochl_day;
```

Result:

`SELECT count(*) AS rows_2025 FROM ochl_day WHERE time IN '2025'`

| rows_2025 (LONG) |
|---|
| 1 |

(1 row)

`ALTER TABLE ochl_day DROP PARTITION '2025'`

```text
1 partition(s) of 'ochl_day' dropped
```

`SELECT time, symbol, close FROM ochl_day`

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.9 |

(1 row)

**Example: Drop what ended more than a year ago (by hand, or from a monthly timer)**

Setup:

```sql
CREATE TABLE trades_log (time TIMESTAMP, symbol SYMBOL, qty LONG) TIMESERIES(time) PARTITION BY MONTH;
INSERT INTO trades_log VALUES ('2024-01-15', 'CITY', 100), ('2024-02-15', 'CITY', 200), ('2099-01-15', 'CITY', 300);
```

```sql
ALTER TABLE trades_log DROP PARTITION OLDER THAN 1 YEAR;
SELECT time, symbol, qty FROM trades_log;
```

Result:

`ALTER TABLE trades_log DROP PARTITION OLDER THAN 1 YEAR`

```text
2 partition(s) of 'trades_log' dropped
```

`SELECT time, symbol, qty FROM trades_log`

| time (TIMESTAMP) | symbol (SYMBOL) | qty (LONG) |
|---|---|---|
| 2099-01-15T00:00:00.000Z | CITY | 300 |

(1 row)

**Example: Drop two days of trade log at once**

Setup:

```sql
CREATE TABLE trade_log (date TIMESTAMP ROUND 1d, transaction_id LONG, symbol SYMBOL) TIMESERIES(date) PARTITION BY DAY DEDUP KEY (date, transaction_id);
INSERT INTO trade_log VALUES ('2026-09-08', 1, 'CITY'), ('2026-09-09', 2, 'COAST'), ('2026-09-10', 3, 'TELCO');
```

```sql
ALTER TABLE trade_log DROP PARTITION '2026-09-08', '2026-09-09';
SELECT date, transaction_id, symbol FROM trade_log;
```

Result:

`ALTER TABLE trade_log DROP PARTITION '2026-09-08', '2026-09-09'`

```text
2 partition(s) of 'trade_log' dropped
```

`SELECT date, transaction_id, symbol FROM trade_log`

| date (TIMESTAMP) | transaction_id (LONG) | symbol (SYMBOL) |
|---|---|---|
| 2026-09-10T00:00:00.000Z | 3 | TELCO |

(1 row)

**Example: QuestDB's forms: LIST, and WHERE on the time column**

Setup:

```sql
CREATE TABLE floorsheet (date TIMESTAMP, symbol SYMBOL, qty LONG) TIMESTAMP(date) PARTITION BY DAY;
INSERT INTO floorsheet VALUES ('2026-09-20T10:00', 'CITY', 1), ('2026-09-21T10:00', 'CITY', 2), ('2026-09-22T10:00', 'CITY', 3), ('2026-09-23T10:00', 'CITY', 4);
```

```sql
ALTER TABLE floorsheet DROP PARTITION LIST '2026-09-20';
ALTER TABLE floorsheet DROP PARTITION WHERE date < '2026-09-22T12:00';
SELECT date, qty FROM floorsheet;
```

Result:

`ALTER TABLE floorsheet DROP PARTITION '2026-09-20'`

```text
1 partition(s) of 'floorsheet' dropped
```

`ALTER TABLE floorsheet DROP PARTITION WHERE date < '2026-09-22T12:00'`

```text
1 partition(s) of 'floorsheet' dropped; kept partition(s) only part of which matches: 2026-09-22 (use DELETE for those rows)
```

`SELECT date, qty FROM floorsheet`

| date (TIMESTAMP) | qty (LONG) |
|---|---|
| 2026-09-22T10:00:00.000Z | 3 |
| 2026-09-23T10:00:00.000Z | 4 |

(2 rows)

With `LIST`, as in QuestDB, a partition that is not there is skipped and the others are still dropped. Without `LIST`, a partition that is not there is an error and nothing is dropped.

**Example: LIST skips a day that has no partition**

Setup:

```sql
CREATE TABLE floorsheet (date TIMESTAMP, symbol SYMBOL, qty LONG) TIMESTAMP(date) PARTITION BY DAY;
INSERT INTO floorsheet VALUES ('2026-09-20T10:00', 'CITY', 1), ('2026-09-21T10:00', 'CITY', 2);
```

```sql
ALTER TABLE floorsheet DROP PARTITION LIST '2026-09-20', '2000-01-01';
SELECT date, qty FROM floorsheet;
```

Result:

`ALTER TABLE floorsheet DROP PARTITION '2026-09-20', '2000-01-01'`

```text
1 partition(s) of 'floorsheet' dropped
```

`SELECT date, qty FROM floorsheet`

| date (TIMESTAMP) | qty (LONG) |
|---|---|
| 2026-09-21T10:00:00.000Z | 2 |

(1 row)

**Example: WHERE takes only the time column** (shows an error)

Setup:

```sql
CREATE TABLE floorsheet (date TIMESTAMP, symbol SYMBOL, qty LONG) TIMESTAMP(date) PARTITION BY DAY;
INSERT INTO floorsheet VALUES ('2026-09-20T10:00', 'CITY', 1);
```

```sql
ALTER TABLE floorsheet DROP PARTITION WHERE qty > 0;
```

Result:

Error: `DROP PARTITION WHERE compares the time column 'date' with fixed times only (=, <>, <, <=, >, >=, BETWEEN, IN, joined by AND, OR, NOT), as in WHERE date < '2026-09-01'`

**Example: A month key for a table partitioned by day** (shows an error)

Setup:

```sql
CREATE TABLE trade_log (date TIMESTAMP, transaction_id LONG) TIMESERIES(date) PARTITION BY DAY;
INSERT INTO trade_log VALUES ('2026-09-10', 1);
```

```sql
ALTER TABLE trade_log DROP PARTITION '2026-09';
```

Result:

Error: `table 'trade_log' has no partition '2026-09'; partitions: 2026-09-10`

<a id="set-ttl"></a>

## SET TTL

Syntax:

```sql
ALTER TABLE table SET TTL n HOURS | DAYS | WEEKS | MONTHS | YEARS
ALTER TABLE table SET TTL NONE
CREATE TABLE ... TIMESERIES(time) PARTITION BY DAY TTL 90 DAYS
```

A TTL (time to live) keeps a time-series table small. KarelaDB drops **whole partitions** whose time ended more than the TTL ago. It never deletes single rows.

- A background thread checks once a minute. It only runs when no statement is writing.
- A partition goes when its **last** moment is older than the TTL. With `TTL 3 DAYS` on 2026-09-10 12:00, the day `2026-09-06` goes and `2026-09-07` stays.
- `MONTHS` and `YEARS` are calendar months and years.
- **Returns:** `table 'name' drops partitions older than 90 DAYS`, or `table 'name' keeps its partitions (no TTL)` for `NONE`.
- **Notes:**
  - Only for time-series tables with `PARTITION BY DAY`, `MONTH` or `YEAR`.
  - `SHOW CREATE TABLE` shows the TTL.
  - Every drop is written to the audit log (event `ttl_drop`) and to the database log, like `DROP PARTITION`.
  - A [materialized view](views.md#materialized-view) keeps its rows when the TTL drops partitions of its table.
  - The TTL is checked every minute. It also runs on a busy database. It locks only a table that has a partition past its TTL, one table at a time, and waits only briefly for it. A table held by a long load or an open transaction is left for the next check, and writers of other tables never wait for it. Writers of the table being trimmed wait while the old partitions go, which is quick.

**Example: Keep 90 days of live prices**

Setup:

```sql
CREATE TABLE live_prices (time TIMESTAMP, symbol SYMBOL, ltp DOUBLE) TIMESERIES(time) PARTITION BY DAY;
```

```sql
ALTER TABLE live_prices SET TTL 90 DAYS;
SHOW CREATE TABLE live_prices;
```

Result:

`ALTER TABLE live_prices SET TTL 90 DAYS`

```text
table 'live_prices' drops partitions older than 90 DAYS
```

`SHOW CREATE TABLE live_prices`

| create_sql (STRING) |
|---|
| CREATE TABLE live_prices (   time TIMESTAMP,   symbol SYMBOL,   ltp DOUBLE ) TIMESERIES(time) PARTITION BY DAY SORT BY (symbol, time) TTL 90 DAYS |

(1 row)

**Example: TTL when the table is made, and taken off again**

Setup:

```sql
CREATE TABLE candles_1m (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY MONTH TTL 2 YEARS;
```

```sql
ALTER TABLE candles_1m SET TTL NONE;
SHOW CREATE TABLE candles_1m;
```

Result:

`ALTER TABLE candles_1m SET TTL NONE`

```text
table 'candles_1m' keeps its partitions (no TTL)
```

`SHOW CREATE TABLE candles_1m`

| create_sql (STRING) |
|---|
| CREATE TABLE candles_1m (   time TIMESTAMP,   symbol SYMBOL,   close DOUBLE ) TIMESERIES(time) PARTITION BY MONTH SORT BY (symbol, time) |

(1 row)

**Example: A relational table has no partitions to drop** (shows an error)

Setup:

```sql
CREATE TABLE notes (id LONG PRIMARY KEY, body STRING);
```

```sql
ALTER TABLE notes SET TTL 30 DAYS;
```

Result:

Error: `TTL drops whole time partitions, so it needs a time-series table with PARTITION BY DAY, MONTH or YEAR; table 'notes' has none`

<a id="dedup-enable"></a>

## DEDUP ENABLE and DEDUP DISABLE

Syntax:

```sql
ALTER TABLE table DEDUP ENABLE UPSERT KEYS (column, ..., time_column)
ALTER TABLE table DEDUP DISABLE
```

Sets or removes the [DEDUP KEY](partitions-and-dedup.md#dedup-key) of a time-series table. It is QuestDB's statement; `UPSERT` may be left out.

- `DEDUP ENABLE` rewrites the rows by the new key. Rows that already share a key are **folded**: the newest of each key stays.
- `DEDUP DISABLE` takes the key off. From then on every row is kept, also exact copies.
- **Returns:** `table 't' now dedups on (time, symbol) (N row(s) rewritten, M duplicate row(s) folded: the newest row of each key was kept)`, or `table 't' no longer dedups (N row(s) rewritten)`.
- **Notes:**
  - The key must include the time column, as in `CREATE TABLE`. With [SYMBOL(col) partitions](partitions-and-dedup.md#partition-by-symbol) it must include that column too.
  - It reads and rewrites every row, so on a big table it takes a while. Folded rows cannot be brought back: make a backup first when they matter.
  - Only for time-series tables. A relational table uses a `PRIMARY KEY`.
  - This statement leaves the table's [dedup_insert](partitions-and-dedup.md#dedup-insert) as it was: on a table that did not have it, a plain `INSERT` of a key that is there still fails. To make it replace the row, as QuestDB does, add `ALTER TABLE t SET (dedup_insert = 'upsert')`. (A table made with `CREATE TABLE ... DEDUP UPSERT KEYS (...)` has it from the start.)

**Example: A tick table loaded twice: turn DEDUP on and the copies fold**

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO ticks VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 510), ('2026-09-10T11:01:00+05:45', 'CITY', 511);
INSERT INTO ticks VALUES ('2026-09-10T11:00:00+05:45', 'CITY', 510.5);
```

```sql
ALTER TABLE ticks DEDUP ENABLE UPSERT KEYS (time, symbol);
SELECT time, symbol, price FROM ticks;
```

Result:

`ALTER TABLE ticks DEDUP ENABLE UPSERT KEYS (time, symbol)`

```text
table 'ticks' now dedups on (time, symbol) (2 row(s) rewritten, 1 duplicate row(s) folded: the newest row of each key was kept)
```

`SELECT time, symbol, price FROM ticks`

| time (TIMESTAMP) | symbol (SYMBOL) | price (DOUBLE) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | CITY | 510.5 |
| 2026-09-10T05:16:00.000Z | CITY | 511 |

(2 rows)

**Example: The key needs the time column** (shows an error)

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time);
```

```sql
ALTER TABLE ticks DEDUP ENABLE UPSERT KEYS (symbol);
```

Result:

Error: `DEDUP UPSERT KEYS must include the time column 'time' of table 'ticks', or a stored column GENERATED ALWAYS AS (date_trunc('minute', time)) STORED`

<a id="add-check"></a>

## ADD CONSTRAINT ... CHECK

Syntax:

```sql
ALTER TABLE table ADD [CONSTRAINT name] CHECK (condition)
```

Adds a rule that every row must follow. KarelaDB first reads **every** row: if one row already breaks the rule, the rule is refused and the message names that row.

- Without `CONSTRAINT name`, KarelaDB makes the name `table_check` (or `table_check1`, ...).
- **Returns:** `table 'name' altered`.
- **Notes:** on a very big time-series table this reads all rows once, so it can take a while. The rules for the condition are in [CHECK](constraints.md#check).

**Example: No negative balances from now on: the rule stops a bad UPDATE** (shows an error)

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY AUTO, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL DEFAULT 0);
INSERT INTO accounts (owner, balance) VALUES ('Ram', 1000.00), ('Sita', 0);
```

```sql
ALTER TABLE accounts ADD CONSTRAINT balance_not_negative CHECK (balance >= 0);
UPDATE accounts SET balance = balance - 50 WHERE owner = 'Sita';
```

Result:

```text
table 'accounts' altered
```

Error: `CHECK constraint 'balance_not_negative' of table 'accounts' failed: balance >= 0 is false for the row id='2', balance='-50.00'`

**Example: A row already breaks the rule** (shows an error)

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY AUTO, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL DEFAULT 0);
INSERT INTO accounts (owner, balance) VALUES ('Ram', -20.00);
```

```sql
ALTER TABLE accounts ADD CONSTRAINT balance_not_negative CHECK (balance >= 0);
```

Result:

Error: `cannot add the constraint: a row already in table 'accounts' breaks it (CHECK constraint 'balance_not_negative' of table 'accounts' failed: balance >= 0 is false for the row id='1', balance='-20.00'); fix or delete such rows first`

<a id="add-key"></a>

## ADD UNIQUE, ADD FOREIGN KEY

Syntax:

```sql
ALTER TABLE table ADD [CONSTRAINT name] UNIQUE (column [, column ...])
ALTER TABLE table ADD [CONSTRAINT name] FOREIGN KEY (column [, ...]) REFERENCES other (column [, ...])
                      [ON DELETE action] [ON UPDATE action] [NOT VALID]
```

Adds a key to a table that already has rows, the PostgreSQL way. KarelaDB first reads every row.

| Form | KarelaDB checks first | After it |
|---|---|---|
| `UNIQUE (...)` | no two rows have the same values | a new duplicate is refused |
| `FOREIGN KEY (...) REFERENCES other (...)` | every row has a matching row in `other` | a new row must point at a row that is there |
| `... NOT VALID` | nothing: rows already there are not checked | new rows are checked |

- **Returns:** `table 'name' altered`.
- **Notes:**
  - Without `CONSTRAINT name`, KarelaDB makes the name: `trades_ref_key`, `trades_buyer_fkey`. `SHOW CREATE TABLE` shows it, and [DROP CONSTRAINT](#drop-constraint) removes it.
  - A `FOREIGN KEY` must point at the `PRIMARY KEY` or a `UNIQUE` column of the other table, of the same kind of type. The `ON DELETE` actions are in [REFERENCES](constraints.md#references).
  - When a row breaks the rule, nothing changes and the message names the row.

**Example: Trades point at brokers from now on**

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
CREATE TABLE trades (id LONG PRIMARY KEY, buyer INT, qty LONG);
INSERT INTO brokers VALUES (1, 'Keystone Securities'), (45, 'Imperial Securities');
INSERT INTO trades VALUES (1, 1, 10), (2, 45, 20);
```

```sql
ALTER TABLE trades ADD CONSTRAINT trades_buyer_fk FOREIGN KEY (buyer) REFERENCES brokers(id);
ALTER TABLE brokers ADD CONSTRAINT brokers_name_key UNIQUE (name);
SHOW CREATE TABLE trades;
```

Result:

`ALTER TABLE trades ADD CONSTRAINT trades_buyer_fk FOREIGN KEY (buyer) REFERENCES brokers (id)`

```text
table 'trades' altered
```

`ALTER TABLE brokers ADD CONSTRAINT brokers_name_key UNIQUE (name)`

```text
table 'brokers' altered
```

`SHOW CREATE TABLE trades`

| create_sql (STRING) |
|---|
| CREATE TABLE trades (   id LONG PRIMARY KEY,   buyer INT CONSTRAINT trades_buyer_fk REFERENCES brokers(id),   qty LONG ) |

(1 row)

**Example: Old rows break the rule: NOT VALID checks only new rows** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
CREATE TABLE trades (id LONG PRIMARY KEY, buyer INT);
INSERT INTO brokers VALUES (1, 'Keystone Securities');
INSERT INTO trades VALUES (1, 1), (2, 77);
```

```sql
ALTER TABLE trades ADD CONSTRAINT trades_buyer_fk FOREIGN KEY (buyer) REFERENCES brokers(id) NOT VALID;
INSERT INTO trades VALUES (3, 99);
```

Result:

```text
table 'trades' altered
```

Error: `column 'buyer' = '99' has no matching row in brokers(id)`

**Example: Two rows already have the same value** (shows an error)

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY, email STRING);
INSERT INTO users VALUES (1, 'ram@example.com'), (2, 'ram@example.com');
```

```sql
ALTER TABLE users ADD UNIQUE (email);
```

Result:

Error: `cannot add constraint 'users_email_key': two rows of table 'users' have email='ram@example.com' (duplicate)`

<a id="drop-constraint"></a>

## DROP CONSTRAINT

Syntax:

```sql
ALTER TABLE table DROP CONSTRAINT name
```

Removes a `CHECK` rule, a `UNIQUE` key or a `FOREIGN KEY` by its name. `SHOW CREATE TABLE` shows the names, also the names KarelaDB made for you (like `accounts_balance_check`). The `PRIMARY KEY` cannot be dropped: the rows are stored by it.

- **Returns:** `table 'name' altered`.
- **Notes:** a name that does not exist is an error; the message lists the names the table has. A column called `constraint` is dropped with `ALTER TABLE t DROP constraint` (no name after it).

**Example: Remove a limit that is too strict**

Setup:

```sql
CREATE TABLE ledger (id LONG PRIMARY KEY AUTO, amount DECIMAL(2) NOT NULL, CONSTRAINT max_amount CHECK (amount <= 100000));
```

```sql
ALTER TABLE ledger DROP CONSTRAINT max_amount;
INSERT INTO ledger (amount) VALUES (250000.00);
SELECT id, amount FROM ledger;
```

Result:

`ALTER TABLE ledger DROP CONSTRAINT max_amount`

```text
table 'ledger' altered
```

`INSERT INTO ledger (amount) VALUES (250000.00)`

```text
1 row(s) inserted
```

`SELECT id, amount FROM ledger`

| id (LONG) | amount (DECIMAL(2)) |
|---|---|
| 1 | 250000.00 |

(1 row)

**Example: A wrong constraint name** (shows an error)

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, balance DECIMAL(2) CHECK (balance >= 0));
```

```sql
ALTER TABLE accounts DROP CONSTRAINT balance_check;
```

Result:

Error: `table 'accounts' has no constraint 'balance_check' (it has: accounts_pkey, accounts_balance_check)`

<a id="rename-table"></a>

## RENAME TABLE

Syntax:

```sql
RENAME TABLE old_name TO new_name
```

Gives a table a new name. `REFERENCES` in other tables follow the new name.

- **Returns:** `table 'old' renamed to 'new'`.
- **Notes:** refused when a table with the new name exists, and while the table has triggers (drop them first). Views, procedures and triggers that use the old name are not changed. The PostgreSQL form `ALTER TABLE a RENAME TO b` works the same.

**Example: Rename a table; the REFERENCES follows**

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING);
CREATE TABLE trades (id LONG PRIMARY KEY, buyer INT REFERENCES brokers(id));
```

```sql
RENAME TABLE brokers TO members;
SHOW COLUMNS FROM trades;
```

Result:

`RENAME TABLE brokers TO members`

```text
table 'brokers' renamed to 'members'
```

`SHOW COLUMNS FROM trades`

| name (STRING) | type (STRING) | primary_key (BOOL) | not_null (BOOL) | computed (BOOL) | references (STRING) |
|---|---|---|---|---|---|
| id | LONG | true | false | false | NULL |
| buyer | INT | false | false | false | members(id) |

(2 rows)

**Example: The new name is taken** (shows an error)

Setup:

```sql
CREATE TABLE posts (id LONG PRIMARY KEY);
CREATE TABLE posts_old (id LONG PRIMARY KEY);
```

```sql
RENAME TABLE posts TO posts_old;
```

Result:

Error: `cannot rename table 'posts' to 'posts_old': a table named 'posts_old' already exists`

<a id="drop-table"></a>

## DROP TABLE

Syntax:

```sql
DROP TABLE [IF EXISTS] table [CASCADE | RESTRICT]
```

Deletes a table with all its rows and its indexes. With `IF EXISTS`, a table that is not there is not an error.

- **Returns:** `table 'name' dropped`, or `table 'name' does not exist` with `IF EXISTS`.
- **Notes:** the table goes to the [trash](trash.md) for some days, and `UNDROP TABLE` brings it back. It answers at once: it waits only for the statements running in the database at that moment, not for its files to be written or moved. Refused while another table `REFERENCES` it, and while it has triggers. To remove all rows and keep the table, use [TRUNCATE](update-delete.md#truncate).
- **CASCADE and RESTRICT:** PostgreSQL writes `DROP TABLE t CASCADE` (drop what depends on it too) or `DROP TABLE t RESTRICT` (refuse while something depends on it). KarelaDB always works like `RESTRICT`: it never drops anything but the table.
  - `RESTRICT` is read and changes nothing.
  - `CASCADE` works when nothing uses the table, so a PostgreSQL script with `DROP TABLE IF EXISTS t CASCADE` runs.
  - `CASCADE` is **refused** while a view, a materialized view or another table's foreign key uses the table: `DROP TABLE ... CASCADE is not supported` (PostgreSQL `0A000`). The message names what uses it. Drop those first, then the table.
  - Without `CASCADE`, a plain view that reads the table does not stop the drop: the view stays and fails when it is read (see [views](views.md)).
  - `DROP FUNCTION`, `DROP PROCEDURE` and `DROP TRIGGER` read both words and ignore them.

**Example: Remove a test table; safe to run twice**

Setup:

```sql
CREATE TABLE test_ticks (time TIMESTAMP, price DOUBLE) TIMESERIES(time);
```

```sql
DROP TABLE test_ticks;
DROP TABLE IF EXISTS test_ticks;
SHOW TABLES;
```

Result:

`DROP TABLE test_ticks`

```text
table 'test_ticks' dropped; UNDROP TABLE test_ticks brings it back within 7 days
```

`DROP TABLE IF EXISTS test_ticks`

```text
table 'test_ticks' does not exist
```

`SHOW TABLES`

| name (STRING) | kind (STRING) | partition (STRING) | columns (INT) | rows (LONG) |
|---|---|---|---|---|

(0 rows)

**Example: Brokers are still used by the trades** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING);
CREATE TABLE trades (id LONG PRIMARY KEY, buyer INT REFERENCES brokers(id));
```

```sql
DROP TABLE brokers;
```

Result:

Error: `cannot drop table 'brokers': column 'buyer' of table 'trades' REFERENCES it; drop that column or table first`

**Example: A table that is not there** (shows an error)

```sql
DROP TABLE nothing;
```

Result:

Error: `cannot drop table 'nothing': it does not exist`

**Example: CASCADE and RESTRICT on tables nothing uses**

Setup:

```sql
CREATE TABLE test_a (id INT PRIMARY KEY);
CREATE TABLE test_b (id INT PRIMARY KEY);
```

```sql
DROP TABLE test_a CASCADE;
DROP TABLE test_b RESTRICT;
SHOW TABLES;
```

Result:

`DROP TABLE test_a`

```text
table 'test_a' dropped; UNDROP TABLE test_a brings it back within 7 days
```

`DROP TABLE test_b`

```text
table 'test_b' dropped; UNDROP TABLE test_b brings it back within 7 days
```

`SHOW TABLES`

| name (STRING) | kind (STRING) | partition (STRING) | columns (INT) | rows (LONG) |
|---|---|---|---|---|

(0 rows)

**Example: CASCADE would have to drop a view: refused** (shows an error)

Setup:

```sql
CREATE TABLE test_prices (symbol SYMBOL, price DOUBLE);
CREATE VIEW test_expensive AS SELECT symbol FROM test_prices WHERE price > 1000;
```

```sql
DROP TABLE test_prices CASCADE;
```

Result:

Error: `DROP TABLE ... CASCADE is not supported: it would not drop view 'test_expensive', which uses table 'test_prices'. Drop the dependent views first (DROP VIEW test_expensive), then DROP TABLE test_prices`

<a id="resident"></a>

## SET (resident = on): keep a table in memory

Syntax:

```sql
ALTER TABLE <t> SET (resident = on | off)
ALTER TABLE <t> RESET (resident)
CREATE TABLE <t> (...) WITH (resident = on)
```

A table an app reads on every request (sessions, users, symbols) should not be read from disk again because another query needed memory. With `resident = on`, its partitions are **never unloaded** once a read has loaded them: not for a big scan of the same database, not for another database, not for the [process memory limit](cli-serve.md#memory-limit).

- **Returns:** `table 't' stays in memory once loaded (resident = on); it counts against the database's MEMORY_LIMIT`.
- **Notes:**
  - It loads nothing by itself: the first read that needs the rows loads them.
  - What it holds still counts in `--memory` and in the database's [`MEMORY_LIMIT`](databases.md#memory), so keep it for small and medium tables.
  - `GET /api/stats` shows what resident tables hold as `resident_bytes` in each database's `memory`.
  - A database with a resident table needs KarelaDB 2026-10-02 or newer; `RESET (resident)` lets an older KarelaDB open it again.

**Example: The sessions table of an app stays loaded**

Setup:

```sql
CREATE TABLE sessions (token STRING PRIMARY KEY, user_id LONG);
```

```sql
ALTER TABLE sessions SET (resident = on);
```

Result:

```text
table 'sessions' stays in memory once loaded (resident = on); it counts against the database's MEMORY_LIMIT
```
