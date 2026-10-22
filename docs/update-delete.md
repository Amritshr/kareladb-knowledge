# UPDATE and DELETE

> Change rows with UPDATE, remove rows with DELETE, empty tables with TRUNCATE, get the changed rows back with RETURNING, and fix wrong data safely.

- Category: Writing data
- Keywords: update, change rows, modify, SET, delete, remove rows, delete rows, WHERE, all rows, RETURNING, fix bad data, wrong data, correct data, undo, rollback, TRUNCATE, TRUNCATE TABLE, RESTART IDENTITY, CONTINUE IDENTITY, empty a table, delete all rows, the update would create a second row, row(s) updated, row(s) deleted, safe workflow, UPDATE FROM, FROM other table, update from another table, DELETE USING
- See also: [INSERT](insert.md), [Transactions](transactions.md), [ALTER, RENAME and DROP TABLE](alter-table.md), [Constraints](constraints.md), [Backup, check, repair and restore](backup-and-safety.md), [WHERE](where.md)

`UPDATE` changes values in rows that are already there. `DELETE` removes rows. Both take a `WHERE` condition that says **which** rows. Like `INSERT`, one statement is all or nothing, and it is saved as soon as KDB says `updated` or `deleted`.

**Warning:** without `WHERE`, `UPDATE` changes **every row** and `DELETE` removes **every row**. Before a big change, run `SELECT count(*)` with the same `WHERE` and check the number.

**Example: Make every VOLT daily volume of 2026-09 ten percent bigger: count first, then change** (sample data: sample)

```sql
SELECT count(*) AS rows FROM ochl_day WHERE symbol = 'VOLT' AND time IN '2026-09';
UPDATE ochl_day SET volume = round(volume * 1.1) WHERE symbol = 'VOLT' AND time IN '2026-09';
```

Result:

`SELECT count(*) AS rows FROM ochl_day WHERE symbol = 'VOLT' AND time IN '2026-09'`

| rows (LONG) |
|---|
| 8 |

(1 row)

`UPDATE ochl_day SET volume = round(volume * 1.1) WHERE symbol = 'VOLT' AND time IN '2026-09'`

```text
8 row(s) updated
```

<a id="update"></a>

## UPDATE

Syntax:

```sql
UPDATE table SET column = expression [, column = expression ...] [WHERE condition] [RETURNING ...]
```

Sets new values in every row where `condition` is true. The expression can use the **old** values of the same row: `balance = balance - 250.50`.

| Part | Meaning |
|---|---|
| `SET column = expression` | the new value; each column at most once |
| `WHERE condition` | which rows; without it: **all** rows. See [WHERE](where.md) |
| `RETURNING` | give the changed rows back; see [RETURNING](#returning) |

- **Returns:** `N row(s) updated` (also `0 row(s) updated`: no row matched, not an error).
- New values are converted to the column type and every [constraint](constraints.md) is checked.
- An `UPDATE` may change a key or the time column; KDB moves the row (also to another partition). It refuses to make a duplicate: `the update would create a second row with ...`.
- **Notes:** a computed column cannot be set. A **subquery works** in `SET` and in `WHERE`. A `DECIMAL` result with too many decimal places is refused; use `round(x, 2)`.

<a id="update-from"></a>

### UPDATE ... FROM

Syntax:

```sql
UPDATE table SET column = expression FROM other_table [alias] [, ...] WHERE join_condition
UPDATE table SET column = expression FROM (SELECT ...) alias WHERE join_condition
```

Takes the new values from **another table** or from a subquery (PostgreSQL style). `FROM` can list more than one table, or a `JOIN`.

- **Notes:**
  - The `WHERE` must join the rows: `WHERE trade_log.id = fix.id`. Without it, **every** row of the table is updated.
  - When a column name is in both tables, write `table.column` (or `alias.column`), also on the right side of `SET`. Otherwise: `column 'price' is in more than one table`.
  - The table being updated can have an alias too: `UPDATE trade_log t SET ... WHERE t.id = f.id`.
  - `RETURNING` works. For `DELETE` the same idea is written `DELETE FROM table USING other_table WHERE ...`.

**Example: Copy corrected prices from another table**

Setup:

```sql
CREATE TABLE trade_log (id LONG PRIMARY KEY, symbol SYMBOL, price DOUBLE);
CREATE TABLE price_fix (id LONG PRIMARY KEY, price DOUBLE);
INSERT INTO trade_log VALUES (1, 'ACME', 10.5), (2, 'CITY', 20.0), (3, 'VOLT', 30.0);
INSERT INTO price_fix VALUES (1, 11.0), (3, 33.0);
```

```sql
UPDATE trade_log SET price = f.price FROM price_fix f WHERE trade_log.id = f.id RETURNING id, symbol, price;
SELECT * FROM trade_log ORDER BY id;
```

Result:

`UPDATE trade_log SET price = f.price FROM price_fix AS f WHERE trade_log.id = f.id RETURNING id, sym`

| id (LONG) | symbol (SYMBOL) | price (DOUBLE) |
|---|---|---|
| 1 | ACME | 11 |
| 3 | VOLT | 33 |

(2 rows)

```text
2 row(s) updated
```

`SELECT * FROM trade_log ORDER BY id`

| id (LONG) | symbol (SYMBOL) | price (DOUBLE) |
|---|---|---|
| 1 | ACME | 11 |
| 2 | CITY | 20 |
| 3 | VOLT | 33 |

(3 rows)

**Example: UPDATE ... FROM a subquery**

Setup:

```sql
CREATE TABLE trade_log (id LONG PRIMARY KEY, symbol SYMBOL, price DOUBLE);
CREATE TABLE price_fix (id LONG, price DOUBLE);
INSERT INTO trade_log VALUES (1, 'ACME', 10.5), (2, 'CITY', 20.0), (3, 'VOLT', 30.0);
INSERT INTO price_fix VALUES (1, 11.0), (1, 12.0), (3, 33.0);
```

```sql
UPDATE trade_log SET price = s.last_price
FROM (SELECT id, max(price) AS last_price FROM price_fix GROUP BY id) s
WHERE trade_log.id = s.id;
SELECT * FROM trade_log ORDER BY id;
```

Result:

`UPDATE trade_log SET price = s.last_price FROM (SELECT id, max(price) AS last_price FROM price_fix G`

```text
2 row(s) updated
```

`SELECT * FROM trade_log ORDER BY id`

| id (LONG) | symbol (SYMBOL) | price (DOUBLE) |
|---|---|---|
| 1 | ACME | 12 |
| 2 | CITY | 20 |
| 3 | VOLT | 33 |

(3 rows)

**Example: Take 250.50 from an account and give it to another**

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000.00), (2, 'Sita', 0.00);
```

```sql
UPDATE accounts SET balance = balance - 250.50 WHERE id = 1;
UPDATE accounts SET balance = balance + 250.50 WHERE id = 2;
SELECT id, owner, balance FROM accounts ORDER BY id;
```

Result:

`UPDATE accounts SET balance = balance - 250.50 WHERE id = 1`

```text
1 row(s) updated
```

`UPDATE accounts SET balance = balance + 250.50 WHERE id = 2`

```text
1 row(s) updated
```

`SELECT id, owner, balance FROM accounts ORDER BY id`

| id (INT) | owner (STRING) | balance (DECIMAL(2)) |
|---|---|---|
| 1 | Ram | 749.50 |
| 2 | Sita | 250.50 |

(2 rows)

**Example: Edit a forum post and mark it edited**

Setup:

```sql
CREATE TABLE posts (id LONG PRIMARY KEY AUTO, author STRING NOT NULL, body STRING NOT NULL, edited BOOL NOT NULL DEFAULT FALSE);
INSERT INTO posts (author, body) VALUES ('ram', 'CITY dividend looks god.'), ('sita', 'I agree.');
```

```sql
UPDATE posts SET body = 'CITY dividend looks good.', edited = TRUE WHERE id = 1;
SELECT id, author, body, edited FROM posts ORDER BY id;
```

Result:

`UPDATE posts SET body = 'CITY dividend looks good.', edited = TRUE WHERE id = 1`

```text
1 row(s) updated
```

`SELECT id, author, body, edited FROM posts ORDER BY id`

| id (LONG) | author (STRING) | body (STRING) | edited (BOOL) |
|---|---|---|---|
| 1 | ram | CITY dividend looks good. | true |
| 2 | sita | I agree. | false |

(2 rows)

**Example: Round the TELCO live prices (many columns at once)** (sample data: sample)

```sql
UPDATE live_data SET ltp = round(ltp, 0), point_change = round(point_change, 0) WHERE symbol = 'TELCO';
SELECT timestamp, symbol, ltp, point_change FROM live_data WHERE symbol = 'TELCO';
```

Result:

`UPDATE live_data SET ltp = round(ltp, 0), point_change = round(point_change, 0) WHERE symbol = 'TELC`

```text
3 row(s) updated
```

`SELECT timestamp, symbol, ltp, point_change FROM live_data WHERE symbol = 'TELCO'`

| timestamp (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) | point_change (DOUBLE) |
|---|---|---|---|
| 2026-09-10T05:20:00.000Z | TELCO | 861 | -21 |
| 2026-09-10T07:15:00.000Z | TELCO | 869 | -12 |
| 2026-09-10T09:14:00.000Z | TELCO | 898 | 17 |

(3 rows)

**Example: Moving a candle onto a day that already has one** (shows an error)

Setup:

```sql
CREATE TABLE ochl_day (time TIMESTAMP ROUND 1d, symbol SYMBOL, close DOUBLE) TIMESERIES(time) DEDUP KEY (symbol, time);
INSERT INTO ochl_day VALUES ('2026-09-13', 'CITY', 507.6), ('2026-09-14', 'CITY', 511.0);
```

```sql
UPDATE ochl_day SET time = '2026-09-13' WHERE symbol = 'CITY' AND time IN '2026-09-14';
```

Result:

Error: `the update would create a second row with symbol='CITY', time='2026-09-13T00:00:00.000Z' in 'ochl_day'`

**Example: A subquery in UPDATE**

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, balance DECIMAL(2));
INSERT INTO accounts VALUES (1, 10.00), (2, 20.00);
```

```sql
UPDATE accounts SET balance = (SELECT max(balance) FROM accounts) WHERE id = 1;
SELECT * FROM accounts ORDER BY id;
```

Result:

`UPDATE accounts SET balance = (SELECT max(balance) FROM accounts) WHERE id = 1`

```text
1 row(s) updated
```

`SELECT * FROM accounts ORDER BY id`

| id (INT) | balance (DECIMAL(2)) |
|---|---|
| 1 | 20.00 |
| 2 | 20.00 |

(2 rows)

<a id="delete"></a>

## DELETE

Syntax:

```sql
DELETE FROM table [WHERE condition] [RETURNING ...]
```

Removes every row where `condition` is true. Without `WHERE`, it removes **all** rows, but the table stays.

- **Returns:** `N row(s) deleted`.
- **Notes:** a row that another table still [REFERENCES](constraints.md#references) cannot be deleted, unless that `REFERENCES` says `ON DELETE CASCADE` (the pointing rows go too) or `ON DELETE SET NULL`. There is no `DELETE ... LIMIT`; a subquery in the `WHERE` works. To remove whole days, months or years of a time-series table, [DROP PARTITION](alter-table.md#drop-partition) is much faster. To empty a whole table, [TRUNCATE](#truncate) is much faster. Unlike QuestDB, KDB can delete single rows of a time-series table.
- **Whole partitions:** when the `WHERE` matches **every** row of each partition the `DELETE` reads - all rows of a table that holds one symbol, or whole months of a `PARTITION BY MONTH` table - KDB drops those partitions instead of deleting row by row, as `DROP PARTITION` does: the same rows go, but one log entry is written instead of one per row (239,326 minute bars: 3 ms instead of 300 ms). Inside `BEGIN ... COMMIT` a `ROLLBACK` puts them back. KDB checks this by counting: if a single row of those partitions does not match, the `DELETE` goes row by row as before. In the [change stream](change-stream.md) such a `DELETE` is one `ddl` row (`ALTER TABLE ... DROP PARTITION ...`), not a `delete` row per row. `KDB_NO_DELETE_DROP=1` turns it off.

**Example: Delete the trades of broker 34 on 2026-09-09** (sample data: sample)

```sql
SELECT count(*) AS trades FROM trade_log WHERE date IN '2026-09-09' AND (buyer = 34 OR seller = 34);
DELETE FROM trade_log WHERE date IN '2026-09-09' AND (buyer = 34 OR seller = 34);
SELECT count(*) AS trades FROM trade_log WHERE date IN '2026-09-09' AND (buyer = 34 OR seller = 34);
```

Result:

`SELECT count(*) AS trades FROM trade_log WHERE date IN '2026-09-09' AND (buyer = 34 OR seller = 34)`

| trades (LONG) |
|---|
| 4 |

(1 row)

`DELETE FROM trade_log WHERE date IN '2026-09-09' AND (buyer = 34 OR seller = 34)`

```text
4 row(s) deleted
```

`SELECT count(*) AS trades FROM trade_log WHERE date IN '2026-09-09' AND (buyer = 34 OR seller = 34)`

| trades (LONG) |
|---|
| 0 |

(1 row)

**Example: Remove app sessions that have ended**

Setup:

```sql
CREATE TABLE sessions (token STRING PRIMARY KEY, user_id LONG NOT NULL, expires TIMESTAMP NOT NULL);
INSERT INTO sessions VALUES ('a1', 1, '2026-09-01T00:00:00Z'), ('b2', 2, '2026-09-30T00:00:00Z'), ('c3', 1, '2026-08-15T00:00:00Z');
```

```sql
DELETE FROM sessions WHERE expires < '2026-09-11T00:00:00Z';
SELECT token, user_id, expires FROM sessions;
```

Result:

`DELETE FROM sessions WHERE expires < '2026-09-11T00:00:00Z'`

```text
2 row(s) deleted
```

`SELECT token, user_id, expires FROM sessions`

| token (STRING) | user_id (LONG) | expires (TIMESTAMP) |
|---|---|---|
| b2 | 2 | 2026-09-30T00:00:00.000Z |

(1 row)

**Example: Delete bars by a list of (symbol, day) keys**

Setup:

```sql
CREATE TABLE bars (time TIMESTAMP ROUND 1d TIME ZONE 'Asia/Kathmandu', symbol SYMBOL, close DOUBLE)
  TIMESERIES(time) PARTITION BY MONTH DEDUP KEY (symbol, time);
INSERT INTO bars VALUES ('2026-07-01T00:00:00+05:45', 'CITY', 500), ('2026-08-02T00:00:00+05:45', 'CITY', 505),
  ('2026-09-10T00:00:00+05:45', 'CITY', 512), ('2026-09-10T00:00:00+05:45', 'COAST', 376);
```

```sql
-- Only the July and September partitions are read, and only these keys in them.
DELETE FROM bars WHERE (symbol, time) IN (('CITY', '2026-07-01T00:00:00+05:45'), ('COAST', '2026-09-10T00:00:00+05:45'));
SELECT symbol, to_char(time, 'YYYY-MM-DD', 'Asia/Kathmandu') AS nepal_day, close FROM bars ORDER BY time, symbol;
```

Result:

`DELETE FROM bars WHERE (symbol, time) IN (('CITY', '2026-07-01T00:00:00+05:45'), ('COAST', '2026-09-`

```text
2 row(s) deleted
```

`SELECT symbol, to_char(time, 'YYYY-MM-DD', 'Asia/Kathmandu') AS nepal_day, close FROM bars ORDER BY `

| symbol (SYMBOL) | nepal_day (STRING) | close (DOUBLE) |
|---|---|---|
| CITY | 2026-08-02 | 505 |
| CITY | 2026-09-10 | 512 |

(2 rows)

**Example: Remove all rows, keep the table**

Setup:

```sql
CREATE TABLE import_staging (symbol SYMBOL, close DOUBLE);
INSERT INTO import_staging VALUES ('CITY', 504.9), ('COAST', 376.1);
```

```sql
DELETE FROM import_staging;
SELECT count(*) AS rows FROM import_staging;
```

Result:

`DELETE FROM import_staging`

```text
2 row(s) deleted
```

`SELECT count(*) AS rows FROM import_staging`

| rows (LONG) |
|---|
| 0 |

(1 row)

**Example: A broker with trades cannot be deleted** (sample data: sample; shows an error)

```sql
DELETE FROM brokers WHERE id = 58;
```

Result:

Error: `cannot remove brokers(id) = '58': table 'trade_log' column 'buyer' still refers to it (foreign key 'trade_log_buyer_fkey')`

<a id="truncate"></a>

## TRUNCATE

Syntax:

```sql
TRUNCATE [TABLE] table [, table ...] [RESTART IDENTITY | CONTINUE IDENTITY] [CASCADE | RESTRICT]
```

Empties tables and keeps them: their columns, indexes, triggers and rights stay. It drops the table's files, as [DROP PARTITION](alter-table.md#drop-partition) does, instead of deleting row by row. So it takes the same short time for ten rows or a hundred million.

| Part | Meaning |
|---|---|
| `table, ...` | one or more tables (not views) |
| `RESTART IDENTITY` | [AUTO](constraints.md#auto) ids start again at 1 |
| `CONTINUE IDENTITY` | AUTO ids go on from where they were (the default) |
| `CASCADE` | also empty the tables whose `REFERENCES` point at these tables |
| `RESTRICT` | the default: refuse when another table points at one of them |

- **Returns:** `N table(s) truncated (M row(s) removed)`, with `, AUTO ids start again at 1` for `RESTART IDENTITY`.
- **Rights:** the same as `DELETE` on each table, also on the tables `CASCADE` reaches.
- **Notes:**
  - A table that another table `REFERENCES` is emptied only together with it: name both, or add `CASCADE`.
  - No row triggers run, as in PostgreSQL. A [materialized view](views.md#materialized-view) of the table is emptied too.
  - Not inside `BEGIN ... COMMIT` or a procedure: it cannot be undone. Use `DELETE FROM t` there; `ROLLBACK` undoes that.
  - The old files go to the database's `_trash` folder and are removed after an hour, or at once with [PURGE TRASH](databases.md#purge-trash). To empty every table of a test database, see [TRUNCATE ALL TABLES](databases.md#truncate-all-tables).
  - `ONLY` and `*` after a name (PostgreSQL table inheritance) are read and change nothing.
  - The two options can come in either order: `CASCADE RESTART IDENTITY` works the same as `RESTART IDENTITY CASCADE`.
  - `_audit_log` cannot be emptied, and a dropped table in the [trash](trash.md) cannot be truncated.

**Example: Empty a staging table before the next import**

Setup:

```sql
CREATE TABLE import_staging (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO import_staging VALUES ('2026-09-10', 'CITY', 504.9), ('2026-09-11', 'COAST', 376.1);
```

```sql
TRUNCATE import_staging;
SELECT count(*) AS rows FROM import_staging;
```

Result:

`TRUNCATE TABLE import_staging`

```text
1 table(s) truncated (2 row(s) removed)
```

`SELECT count(*) AS rows FROM import_staging`

| rows (LONG) |
|---|
| 0 |

(1 row)

**Example: Brokers and the trades that point at them, ids from 1 again**

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
CREATE TABLE trades (id LONG PRIMARY KEY AUTO, buyer INT REFERENCES brokers(id), qty LONG);
INSERT INTO brokers VALUES (1, 'Keystone Securities'), (45, 'Imperial Securities');
INSERT INTO trades (buyer, qty) VALUES (1, 10), (45, 20);
```

```sql
TRUNCATE TABLE brokers CASCADE RESTART IDENTITY;
INSERT INTO brokers VALUES (58, 'Northgate Securities');
INSERT INTO trades (buyer, qty) VALUES (58, 5);
SELECT id, buyer, qty FROM trades;
```

Result:

`TRUNCATE TABLE brokers RESTART IDENTITY CASCADE`

```text
2 table(s) truncated (4 row(s) removed, AUTO ids start again at 1)
```

`INSERT INTO brokers VALUES (58, 'Northgate Securities')`

```text
1 row(s) inserted
```

`INSERT INTO trades (buyer, qty) VALUES (58, 5)`

```text
1 row(s) inserted
```

`SELECT id, buyer, qty FROM trades`

| id (LONG) | buyer (INT) | qty (LONG) |
|---|---|---|
| 1 | 58 | 5 |

(1 row)

**Example: Another table points at it** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
CREATE TABLE trades (id LONG PRIMARY KEY AUTO, buyer INT REFERENCES brokers(id));
```

```sql
TRUNCATE brokers;
```

Result:

Error: `cannot truncate 'brokers': table 'trades' has a foreign key to it (trades_buyer_fkey); truncate both in one statement, or add CASCADE`

**Example: Not inside a transaction** (shows an error)

Setup:

```sql
CREATE TABLE notes (id INT PRIMARY KEY, body STRING);
```

```sql
BEGIN;
TRUNCATE notes;
```

Result:

```text
transaction started
```

Error: `TRUNCATE cannot be used inside a transaction or a procedure: KDB cannot undo it. COMMIT or ROLLBACK first, or use DELETE FROM table, which ROLLBACK undoes (the transaction was rolled back)`

<a id="returning"></a>

## RETURNING

Syntax:

```sql
UPDATE ... [WHERE ...] RETURNING expression [[AS] alias], ... | *
DELETE FROM ... [WHERE ...] RETURNING expression [[AS] alias], ... | *
```

Gives rows back like a `SELECT`: for `UPDATE` the rows **after** the change, for `DELETE` the rows as they **were** before they were removed.

- **Returns:** the rows, then `N row(s) updated` or `N row(s) deleted`.
- **Notes:** use it to show the new balance to the user, or to keep a copy of deleted rows in your app log. If the `RETURNING` list has an error, nothing is changed. See also [INSERT ... RETURNING](insert.md#returning).

**Example: Withdraw money and get the new balance in one statement**

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000.00);
```

```sql
UPDATE accounts SET balance = balance - 250.50 WHERE id = 1 RETURNING id, owner, balance;
```

Result:

| id (INT) | owner (STRING) | balance (DECIMAL(2)) |
|---|---|---|
| 1 | Ram | 749.50 |

(1 row)

```text
1 row(s) updated
```

**Example: Delete old news and see what was removed**

Setup:

```sql
CREATE TABLE news (id LONG PRIMARY KEY AUTO, title STRING NOT NULL, published_at TIMESTAMP NOT NULL);
INSERT INTO news (title, published_at) VALUES
  ('Old IPO notice', '2025-01-10T10:00:00+05:45'),
  ('City Bank profit rises 18%', '2026-08-01T11:00:00+05:45');
```

```sql
DELETE FROM news WHERE published_at < '2026-01-01' RETURNING id, title;
```

Result:

| id (LONG) | title (STRING) |
|---|---|
| 1 | Old IPO notice |

(1 row)

```text
1 row(s) deleted
```

<a id="fix-safely"></a>

## Fix wrong rows safely

Syntax:

```sql
1. SELECT count(*) ... WHERE condition        -- look, count
2. BACKUP DATABASE  (or kdb backup)           -- a way back
3. DELETE FROM ... WHERE condition            -- the same WHERE
4. INSERT OR REPLACE INTO ... VALUES (...)    -- the correct rows
5. SELECT ... WHERE condition                 -- check
```

Bad data happens: a wrong file is imported, a price is ten times too big, a day is loaded twice. Use these steps.

- Use the **same `WHERE`** in every step. The number of deleted rows must be the number you counted.
- To try a change first, wrap it in `BEGIN` ... `ROLLBACK`: you see the result, and nothing is saved. When it looks right, run it again with `COMMIT` ([transactions](transactions.md)).
- **Notes:** if something went badly wrong (an `UPDATE` without `WHERE`), do not fix it row by row: restore the backup to the time before the mistake with `kdb restore --until` ([backup and safety](backup-and-safety.md)). Times that are 5:45 hours wrong (a local time written without its offset, here `+05:45`) can be fixed with `UPDATE t SET time = time - 20700000 WHERE ...` (20700000 ms = 5 h 45 min); check the `DEDUP KEY` first.

**Example: A bad import made COAST minute prices ten times too big: find, delete, load again, check** (sample data: sample)

Setup:

```sql
UPDATE ochl_minutes SET open = open * 10, high = high * 10, low = low * 10, close = close * 10
WHERE symbol = 'COAST' AND time IN '2026-09-10';
```

```sql
SELECT count(*) AS rows, min(low) AS min_low, max(high) AS max_high FROM ochl_minutes WHERE symbol = 'COAST' AND time IN '2026-09-10';
DELETE FROM ochl_minutes WHERE symbol = 'COAST' AND time IN '2026-09-10';
INSERT OR REPLACE INTO ochl_minutes VALUES
  ('2026-09-10T11:00:00+05:45', 'COAST', 380.1, 380.4, 379.8, 380.2, 900),
  ('2026-09-10T11:01:00+05:45', 'COAST', 380.2, 380.5, 380.0, 380.3, 650);
SELECT time, symbol, open, high, low, close, volume FROM ochl_minutes WHERE symbol = 'COAST' AND time IN '2026-09-10';
```

Result:

`SELECT count(*) AS rows, min(low) AS min_low, max(high) AS max_high FROM ochl_minutes WHERE symbol =`

| rows (LONG) | min_low (DOUBLE) | max_high (DOUBLE) |
|---|---|---|
| 236 | 3732 | 3820 |

(1 row)

`DELETE FROM ochl_minutes WHERE symbol = 'COAST' AND time IN '2026-09-10'`

```text
236 row(s) deleted
```

`INSERT OR REPLACE INTO ochl_minutes VALUES ('2026-09-10T11:00:00+05:45', 'COAST', 380.1, 380.4, 379.`

```text
2 row(s) inserted
```

`SELECT time, symbol, open, high, low, close, volume FROM ochl_minutes WHERE symbol = 'COAST' AND tim`

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|---|
| 2026-09-10T05:15:00.000Z | COAST | 380.1 | 380.4 | 379.8 | 380.2 | 900 |
| 2026-09-10T05:16:00.000Z | COAST | 380.2 | 380.5 | 380 | 380.3 | 650 |

(2 rows)

To replace **all** rows of one symbol (prices adjusted for a bonus share, say), load the new rows into a table with the same columns first, then swap them in one transaction. Readers see the old rows or the new ones, never an empty chart. When the symbol fills its partitions, the `DELETE` drops them and the `INSERT` copies the new table's partitions whole: 239,326 minute bars take about 0.1 s.

**Example: Re-adjust one symbol's whole history in one transaction**

Setup:

```sql
CREATE TABLE city_min (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY YEAR SORT BY (symbol, time) DEDUP KEY (symbol, time);
CREATE TABLE city_adj (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY YEAR SORT BY (symbol, time) DEDUP KEY (symbol, time);
INSERT INTO city_min VALUES ('2025-12-31T09:00:00Z', 'CITY', 500), ('2026-09-10T09:00:00Z', 'CITY', 520);
INSERT INTO city_adj SELECT time, symbol, round(close * 0.95, 2) FROM city_min;
```

```sql
BEGIN;
DELETE FROM city_min WHERE symbol = 'CITY';
INSERT INTO city_min SELECT time, symbol, close FROM city_adj;
COMMIT;
SELECT time, symbol, close FROM city_min ORDER BY time;
```

Result:

`BEGIN`

```text
transaction started
```

`DELETE FROM city_min WHERE symbol = 'CITY'`

```text
2 row(s) deleted
```

`INSERT INTO city_min SELECT time, symbol, close FROM city_adj`

```text
2 row(s) inserted
```

`COMMIT`

```text
transaction committed: 3 change(s) saved
```

`SELECT time, symbol, close FROM city_min ORDER BY time`

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2025-12-31T09:00:00.000Z | CITY | 475 |
| 2026-09-10T09:00:00.000Z | CITY | 494 |

(2 rows)

**Example: Try an UPDATE, look, and roll it back**

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000.00), (2, 'Sita', 500.00);
```

```sql
BEGIN;
UPDATE accounts SET balance = balance * 2;
SELECT id, owner, balance FROM accounts ORDER BY id;
ROLLBACK;
SELECT id, owner, balance FROM accounts ORDER BY id;
```

Result:

`BEGIN`

```text
transaction started
```

`UPDATE accounts SET balance = balance * 2`

```text
2 row(s) updated
```

`SELECT id, owner, balance FROM accounts ORDER BY id`

| id (INT) | owner (STRING) | balance (DECIMAL(2)) |
|---|---|---|
| 1 | Ram | 2000.00 |
| 2 | Sita | 1000.00 |

(2 rows)

`ROLLBACK`

```text
transaction rolled back: 1 change(s) undone
```

`SELECT id, owner, balance FROM accounts ORDER BY id`

| id (INT) | owner (STRING) | balance (DECIMAL(2)) |
|---|---|---|
| 1 | Ram | 1000.00 |
| 2 | Sita | 500.00 |

(2 rows)

**Example: Nepal times stored without +05:45: move them back 5 h 45 min**

Setup:

```sql
CREATE TABLE live_data (timestamp TIMESTAMP, symbol SYMBOL, ltp DOUBLE) TIMESERIES(timestamp) DEDUP KEY (timestamp, symbol);
INSERT INTO live_data VALUES ('2026-09-10 11:05:00', 'CITY', 513.0), ('2026-09-10 14:59:00', 'CITY', 527.1);
```

```sql
UPDATE live_data SET timestamp = timestamp - 20700000 WHERE symbol = 'CITY' AND timestamp IN '2026-09-10';
SELECT timestamp, symbol, ltp FROM live_data;
```

Result:

`UPDATE live_data SET timestamp = timestamp - 20700000 WHERE symbol = 'CITY' AND timestamp IN '2026-0`

```text
2 row(s) updated
```

`SELECT timestamp, symbol, ltp FROM live_data`

| timestamp (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) |
|---|---|---|
| 2026-09-10T05:20:00.000Z | CITY | 513 |
| 2026-09-10T09:14:00.000Z | CITY | 527.1 |

(2 rows)
