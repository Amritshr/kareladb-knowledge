# INSERT

> Add rows with INSERT, decide what happens with duplicate keys, get new ids back with RETURNING, and write times correctly.

- Category: Writing data
- Keywords: insert, add rows, new row, VALUES, INTO, column list, multi-row insert, upsert, INSERT OR REPLACE, REPLACE, INSERT OR IGNORE, IGNORE, ON CONFLICT, duplicate key, already exists, dedup, RETURNING, returning id, new id, last insert id, time zone, +05:45, Nepal time, UTC, INSERT SELECT, copy rows
- See also: [UPDATE and DELETE](update-delete.md), [Loading many rows](loading-data.md), [Constraints](constraints.md), [Column types](column-types.md), [CREATE TABLE](create-table.md), [Transactions](transactions.md), [Time and time zones](time-and-time-zones.md)

`INSERT` adds rows to a table. One `INSERT` can add many rows, and it is **all or nothing**: when one row is bad, no row of that statement is saved. When KDB says `inserted`, the rows are already on the disk.

| Statement | The key is new | The key is already there |
|---|---|---|
| [`INSERT`](#insert) | row added | **error**, nothing saved |
| [`INSERT OR REPLACE`](#insert-or-replace) | row added | the old row is replaced by the new one |
| [`INSERT OR IGNORE`](#insert-or-ignore) | row added | the new row is skipped |

A real example: today's market candles arrive; one of them was already loaded.

**Example: Load daily candles; a repeated row is replaced, not doubled**

Setup:

```sql
CREATE TABLE ochl_day (time TIMESTAMP ROUND 1d, symbol SYMBOL, open DOUBLE, high DOUBLE, low DOUBLE, close DOUBLE, volume DOUBLE)
  TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (symbol, time);
INSERT INTO ochl_day VALUES ('2026-09-13', 'CITY', 505.0, 509.0, 503.1, 508.2, 91000);
```

```sql
INSERT OR REPLACE INTO ochl_day (time, symbol, open, high, low, close, volume) VALUES
  ('2026-09-13', 'CITY', 505.0, 509.0, 503.1, 507.6, 91000),
  ('2026-09-13', 'COAST',  376.0, 379.9, 374.0, 378.5, 120500),
  ('2026-09-13', 'VOLT', 191.0, 194.2, 190.1, 193.7, 64000);
SELECT time, symbol, close FROM ochl_day ORDER BY symbol;
```

Result:

`INSERT OR REPLACE INTO ochl_day (time, symbol, open, high, low, close, volume) VALUES ('2026-09-13',`

```text
2 row(s) inserted, 1 replaced
```

`SELECT time, symbol, close FROM ochl_day ORDER BY symbol`

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-13T00:00:00.000Z | CITY | 507.6 |
| 2026-09-13T00:00:00.000Z | COAST | 378.5 |
| 2026-09-13T00:00:00.000Z | VOLT | 193.7 |

(3 rows)

<a id="insert"></a>

## INSERT INTO ... VALUES

Syntax:

```sql
INSERT INTO table [(column, ...)] VALUES (value, ...) [, (value, ...) ...] [RETURNING ...]
```

Adds one row for each `(...)` after `VALUES`.

| Part | Meaning |
|---|---|
| `table` | a table (not a view) |
| `(column, ...)` | optional. The columns the values are for, in any order. Columns you leave out get their `DEFAULT`, or `NULL`, or the next [AUTO](constraints.md#auto) id |
| without a column list | give a value for **every** stored column, in table order; computed columns are skipped |
| `value` | a constant (`'CITY'`, `504.9`, `NULL`, `TRUE`) or an expression without columns (`1 + 1`, `now()`, `CAST('7' AS INT)`) |

- **Returns:** `N row(s) inserted`.
- Each value is converted to the column type; see [column types](column-types.md). Text goes in single quotes; a `'` inside is written `''`.
- **Notes:** many rows in one `INSERT` are **much** faster than one `INSERT` per row. A value cannot be a subquery or use a column. Every row needs the same number of values. The rules of the table ([constraints](constraints.md)) are checked for every row.

**Example: Register two app users; the id and the time come by themselves**

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE, name STRING, created TIMESTAMP DEFAULT now());
```

```sql
INSERT INTO users (email, name) VALUES ('ram@example.com', 'Ram Sharma'), ('sita@example.com', 'Sita Rai');
SELECT id, email, name, created IS NOT NULL AS has_created FROM users;
```

Result:

`INSERT INTO users (email, name) VALUES ('ram@example.com', 'Ram Sharma'), ('sita@example.com', 'Sita`

```text
2 row(s) inserted
```

`SELECT id, email, name, created IS NOT NULL AS has_created FROM users`

| id (LONG) | email (STRING) | name (STRING) | has_created (BOOL) |
|---|---|---|---|
| 1 | ram@example.com | Ram Sharma | true |
| 2 | sita@example.com | Sita Rai | true |

(2 rows)

**Example: A forum post with text in another language (Nepali) and a quote inside**

Setup:

```sql
CREATE TABLE posts (id LONG PRIMARY KEY AUTO, author STRING NOT NULL, body STRING NOT NULL);
```

```sql
INSERT INTO posts (author, body) VALUES
  ('ram', 'City''s dividend looks good.'),
  ('sita', 'नमस्ते, यो राम्रो छ।');
SELECT id, author, body FROM posts;
```

Result:

`INSERT INTO posts (author, body) VALUES ('ram', 'City''s dividend looks good.'), ('sita', 'नमस्ते, य`

```text
2 row(s) inserted
```

`SELECT id, author, body FROM posts`

| id (LONG) | author (STRING) | body (STRING) |
|---|---|---|
| 1 | ram | City's dividend looks good. |
| 2 | sita | नमस्ते, यो राम्रो छ। |

(2 rows)

**Example: Values can be expressions without columns**

Setup:

```sql
CREATE TABLE ledger (id LONG PRIMARY KEY AUTO, amount DECIMAL(2) NOT NULL, fee DECIMAL(2), created TIMESTAMP);
```

```sql
INSERT INTO ledger (amount, fee, created) VALUES (1000.00, round(1000.00 * 0.004, 2), now());
SELECT id, amount, fee, created > '2026-01-01' AS recent FROM ledger;
```

Result:

`INSERT INTO ledger (amount, fee, created) VALUES (1000.00, round(1000.00 * 0.004, 2), now())`

```text
1 row(s) inserted
```

`SELECT id, amount, fee, created > '2026-01-01' AS recent FROM ledger`

| id (LONG) | amount (DECIMAL(2)) | fee (DECIMAL(2)) | recent (BOOL) |
|---|---|---|---|
| 1 | 1000.00 | 4.00 | true |

(1 row)

**Example: One bad row: no row of the statement is saved** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
```

```sql
INSERT INTO brokers VALUES (1, 'Keystone Securities'), (2, NULL), (3, 'Vision Securities');
```

Result:

Error: `row 2: column 'name' (STRING): cannot be NULL`

**Example: The wrong number of values** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
```

```sql
INSERT INTO brokers VALUES (1, 'Keystone Securities'), (2);
```

Result:

Error: `line 1, column 56: row 2 has 1 value; expected 2 like the first row`

<a id="duplicates"></a>

## Duplicate keys

Syntax:

```sql
PRIMARY KEY (column)            relational table
DEDUP KEY (column, ..., time)   time-series table
UNIQUE (column)                 any table
```

How KDB decides that a new row is "already there":

| Table | Two rows are the same when |
|---|---|
| relational with a `PRIMARY KEY` | they have the same key value |
| time-series with a `DEDUP KEY` | all `DEDUP KEY` columns are the same (after `ROUND` of the time) |
| without a key | never: every `INSERT` adds rows, also exact copies |

- Duplicates **inside one statement** count too: with `INSERT` it is an error, with `INSERT OR REPLACE` the **last** one wins, with `INSERT OR IGNORE` the first one stays.
- **Returns:** `a row with symbol='CITY', time='...' already exists in 'ochl_day'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it`.
- **Notes:** a `UNIQUE` column is always an error on a clash, also with `OR REPLACE` and `OR IGNORE`: they only look at the primary key or dedup key. If you did not expect a duplicate, check the time zone (`+05:45` missing?) and `ROUND` on the time column.

**Example: A candle for the same symbol and day** (shows an error)

Setup:

```sql
CREATE TABLE ochl_day (time TIMESTAMP ROUND 1d, symbol SYMBOL, close DOUBLE) TIMESERIES(time) DEDUP KEY (symbol, time);
INSERT INTO ochl_day VALUES ('2026-09-10', 'CITY', 504.9);
```

```sql
INSERT INTO ochl_day VALUES ('2026-09-10T14:00:00+05:45', 'CITY', 505.0);
```

Result:

Error: `a row with symbol='CITY', time='2026-09-10T00:00:00.000Z' already exists in 'ochl_day'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it`

**Example: The same key twice in one INSERT OR REPLACE: the last row wins**

Setup:

```sql
CREATE TABLE live_data (timestamp TIMESTAMP, symbol SYMBOL, ltp DOUBLE) TIMESERIES(timestamp) DEDUP KEY (timestamp, symbol);
```

```sql
INSERT OR REPLACE INTO live_data VALUES
  ('2026-09-10T11:05:00+05:45', 'CITY', 513.0),
  ('2026-09-10T11:05:00+05:45', 'CITY', 513.4);
SELECT timestamp, symbol, ltp FROM live_data;
```

Result:

`INSERT OR REPLACE INTO live_data VALUES ('2026-09-10T11:05:00+05:45', 'CITY', 513.0), ('2026-09-10T1`

```text
1 row(s) inserted, 1 replaced
```

`SELECT timestamp, symbol, ltp FROM live_data`

| timestamp (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) |
|---|---|---|
| 2026-09-10T05:20:00.000Z | CITY | 513.4 |

(1 row)

<a id="insert-or-replace"></a>

## INSERT OR REPLACE

Syntax:

```sql
INSERT OR REPLACE INTO table [(column, ...)] VALUES (...), ... [RETURNING ...]
```

Adds rows with new keys, and **replaces** rows whose key is already there. This is an **upsert**. It is the best statement for imports: the same file can be loaded again and again without double rows.

- The **whole old row** is replaced. Columns you do not give get their `DEFAULT` or `NULL`, **not** the old values. To change only some columns, use [UPDATE](update-delete.md#update).
- **Returns:** `N row(s) inserted, M replaced`.
- **Notes:** on a table without a key it works like `INSERT`. PostgreSQL writes `INSERT ... ON CONFLICT (key) DO UPDATE`; MySQL writes `REPLACE INTO`. QuestDB replaces rows by itself with `DEDUP UPSERT KEYS`; KDB does too on a table made with those words, and otherwise only when you write `OR REPLACE` ([dedup_insert](partitions-and-dedup.md#dedup-insert)).

**Example: The CITY close price was wrong: send the full row again**

Setup:

```sql
CREATE TABLE ochl_day (time TIMESTAMP ROUND 1d, symbol SYMBOL, open DOUBLE, high DOUBLE, low DOUBLE, close DOUBLE, volume DOUBLE) TIMESERIES(time) DEDUP KEY (symbol, time);
INSERT INTO ochl_day VALUES ('2026-09-13', 'CITY', 505.0, 509.0, 503.1, 508.2, 91000);
```

```sql
INSERT OR REPLACE INTO ochl_day VALUES ('2026-09-13', 'CITY', 505.0, 509.0, 503.1, 507.6, 91000);
SELECT time, symbol, close, volume FROM ochl_day;
```

Result:

`INSERT OR REPLACE INTO ochl_day VALUES ('2026-09-13', 'CITY', 505.0, 509.0, 503.1, 507.6, 91000)`

```text
0 row(s) inserted, 1 replaced
```

`SELECT time, symbol, close, volume FROM ochl_day`

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|
| 2026-09-13T00:00:00.000Z | CITY | 507.6 | 91000 |

(1 row)

**Example: Careful: columns you leave out lose their old values**

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY, email STRING, phone STRING, verified BOOL DEFAULT FALSE);
INSERT INTO users VALUES (1, 'ram@example.com', '9800000000', TRUE);
```

```sql
INSERT OR REPLACE INTO users (id, email) VALUES (1, 'ram.sharma@example.com');
SELECT id, email, phone, verified FROM users;
```

Result:

`INSERT OR REPLACE INTO users (id, email) VALUES (1, 'ram.sharma@example.com')`

```text
0 row(s) inserted, 1 replaced
```

`SELECT id, email, phone, verified FROM users`

| id (LONG) | email (STRING) | phone (STRING) | verified (BOOL) |
|---|---|---|---|
| 1 | ram.sharma@example.com | NULL | false |

(1 row)

<a id="insert-or-ignore"></a>

## INSERT OR IGNORE

Syntax:

```sql
INSERT OR IGNORE INTO table [(column, ...)] VALUES (...), ... [RETURNING ...]
```

Adds rows with new keys, and **skips** rows whose key is already there. The old row stays as it is.

- **Returns:** `N row(s) inserted, M skipped (already there)`.
- **Notes:** use it when the first value must win: an imported trade list where rows never change, or "create the settings row if it is missing". `RETURNING` does not return skipped rows. PostgreSQL writes `ON CONFLICT DO NOTHING`.

**Example: Load a trade log file again: old trades stay, new ones are added**

Setup:

```sql
CREATE TABLE trade_log (date TIMESTAMP ROUND 1d, transaction_id LONG, symbol SYMBOL, quantity LONG, rate DOUBLE) TIMESERIES(date) PARTITION BY DAY DEDUP KEY (date, transaction_id);
INSERT INTO trade_log VALUES ('2026-09-10', 100009, 'COAST', 50, 400.0);
```

```sql
INSERT OR IGNORE INTO trade_log VALUES
  ('2026-09-10', 100009, 'COAST', 1, 1.0),
  ('2026-09-10', 100010, 'CITY', 50, 517.0);
SELECT transaction_id, symbol, quantity, rate FROM trade_log ORDER BY transaction_id;
```

Result:

`INSERT OR IGNORE INTO trade_log VALUES ('2026-09-10', 100009, 'COAST', 1, 1.0), ('2026-09-10', 10001`

```text
1 row(s) inserted, 1 skipped (already there)
```

`SELECT transaction_id, symbol, quantity, rate FROM trade_log ORDER BY transaction_id`

| transaction_id (LONG) | symbol (SYMBOL) | quantity (LONG) | rate (DOUBLE) |
|---|---|---|---|
| 100009 | COAST | 50 | 400 |
| 100010 | CITY | 50 | 517 |

(2 rows)

<a id="returning"></a>

## RETURNING

Syntax:

```sql
INSERT ... VALUES (...) RETURNING expression [[AS] alias], ... | *
```

Gives the inserted rows back, like a `SELECT`, with `AUTO` ids and `DEFAULT` values filled in. Your app gets the new id in the same statement.

| Part | Meaning |
|---|---|
| `*` | all columns, computed columns included |
| `expression [AS alias]` | columns of the new row, or expressions over them (`upper(email)`) |

- **Returns:** the rows, and the message `N row(s) inserted`.
- **Notes:** also works with `UPDATE` and `DELETE` ([update and delete](update-delete.md#returning)). With `INSERT OR IGNORE`, skipped rows are not returned. With `INSERT OR REPLACE`, every written row is returned, also one that a later row of the same statement replaced. If the `RETURNING` list has an error (an unknown column), nothing is written.

**Example: Register a user and get the new id**

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE, created TIMESTAMP DEFAULT now());
INSERT INTO users (email) VALUES ('ram@example.com');
```

```sql
INSERT INTO users (email) VALUES ('sita@example.com') RETURNING id, email;
```

Result:

| id (LONG) | email (STRING) |
|---|---|
| 2 | sita@example.com |

(1 row)

```text
1 row(s) inserted
```

**Example: Open accounts and see the defaults**

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY AUTO, user_id LONG NOT NULL, balance DECIMAL(2) NOT NULL DEFAULT 0, status STRING DEFAULT 'active');
```

```sql
INSERT INTO accounts (user_id, balance) VALUES (1, 1000);
INSERT INTO accounts (user_id) VALUES (2) RETURNING *;
```

Result:

`INSERT INTO accounts (user_id, balance) VALUES (1, 1000)`

```text
1 row(s) inserted
```

`INSERT INTO accounts (user_id) VALUES (2) RETURNING *`

| id (INT) | user_id (LONG) | balance (DECIMAL(2)) | status (STRING) |
|---|---|---|---|
| 2 | 2 | 0.00 | active |

(1 row)

```text
1 row(s) inserted
```

**Example: A mistake in RETURNING: nothing is written** (shows an error)

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE);
```

```sql
INSERT INTO users (email) VALUES ('ram@example.com') RETURNING user_id;
SELECT count(*) FROM users;
```

Result:

Error: `RETURNING: line 1, column 8: unknown column 'user_id' (table 'users' has: id email)`

<a id="time-zones"></a>

## Times and time zones in values

Syntax:

```sql
'YYYY-MM-DD[T| ]HH:MM[:SS[.fff]][Z | +HH:MM | +HHMM | -HH:MM]'
```

KDB keeps every `TIMESTAMP` in **UTC**. The text you write is read like this:

| You write | KDB reads it as |
|---|---|
| `'2026-09-10T11:00:00+05:45'` | 11:00 Nepal time = 05:15 UTC |
| `'2026-09-10 11:00:00'` (no zone) | 11:00 **UTC** |
| `'2026-09-10T05:15:00Z'` | 05:15 UTC |
| `'2026-09-10'` | 00:00 UTC |
| `1789017300000` | milliseconds since 1970-01-01 UTC |

- A local time needs its zone offset, for example Nepal **+05:45** or New York `-04:00`. In the sample data the market opens at 11:00 local time (+05:45) = 05:15 UTC.
- **Notes:** the most common mistake is a local time **without** its zone offset (for example `+05:45`): the row is then 5 hours 45 minutes wrong. The date must be `YYYY-MM-DD` with two digits for month and day. More in [time and time zones](time-and-time-zones.md) and [TIMESTAMP](column-types.md#timestamp).

**Example: Live prices written in Nepal time**

Setup:

```sql
CREATE TABLE live_data (timestamp TIMESTAMP, symbol SYMBOL, ltp DOUBLE) TIMESERIES(timestamp) DEDUP KEY (timestamp, symbol);
```

```sql
INSERT INTO live_data VALUES
  ('2026-09-10T11:05:00+05:45', 'CITY', 513.0),
  ('2026-09-10T14:59:00+05:45', 'CITY', 527.1);
SELECT timestamp, symbol, ltp FROM live_data;
```

Result:

`INSERT INTO live_data VALUES ('2026-09-10T11:05:00+05:45', 'CITY', 513.0), ('2026-09-10T14:59:00+05:`

```text
2 row(s) inserted
```

`SELECT timestamp, symbol, ltp FROM live_data`

| timestamp (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) |
|---|---|---|
| 2026-09-10T05:20:00.000Z | CITY | 513 |
| 2026-09-10T09:14:00.000Z | CITY | 527.1 |

(2 rows)

**Example: Nepal time without +05:45 is stored 5:45 hours too late**

Setup:

```sql
CREATE TABLE live_data (timestamp TIMESTAMP, symbol SYMBOL, ltp DOUBLE) TIMESERIES(timestamp);
```

```sql
INSERT INTO live_data VALUES ('2026-09-10 11:05:00', 'CITY', 513.0);
SELECT timestamp, symbol, ltp FROM live_data;
```

Result:

`INSERT INTO live_data VALUES ('2026-09-10 11:05:00', 'CITY', 513.0)`

```text
1 row(s) inserted
```

`SELECT timestamp, symbol, ltp FROM live_data`

| timestamp (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) |
|---|---|---|
| 2026-09-10T11:05:00.000Z | CITY | 513 |

(1 row)

**Example: A date in the wrong format** (shows an error)

Setup:

```sql
CREATE TABLE live_data (timestamp TIMESTAMP, symbol SYMBOL, ltp DOUBLE) TIMESERIES(timestamp);
```

```sql
INSERT INTO live_data VALUES ('10/09/2026 11:05', 'CITY', 513.0);
```

Result:

Error: `column 'timestamp' (TIMESTAMP): '10/09/2026 11:05' is not a time like '2026-09-11 11:00:00' (UTC) or '2026-09-11T11:00:00+05:45'`

<a id="insert-select"></a>

## INSERT ... SELECT, DEFAULT VALUES

Syntax:

```sql
INSERT INTO table [(columns)] SELECT ...
INSERT INTO table DEFAULT VALUES
```

Copies the rows of a query into a table in one statement.

- **Returns:** the number of rows written. `RETURNING` works too.
- **Notes:**
  - The query must give one value for each target column, in order.
  - `ON CONFLICT`, `OR REPLACE` and `OR IGNORE` work with it (see [ON CONFLICT](#on-conflict)).
  - `DEFAULT VALUES` writes one row with every column at its `DEFAULT` (or NULL).
  - **Big copies:** when the query is a plain read of tables (a `WHERE` and expressions are fine, `UNION ALL` too; no `GROUP BY`, `DISTINCT`, window or `LIMIT`), the rows go into the table while they are read. An `ORDER BY` of one table is fine too: the rows are sorted in batches of a few MB that go to temporary files in `_tmp/` of the database folder (`max_spill_bytes`), then written in that order - the same rows as a sort in memory, so the `ORDER BY` still decides which of two rows with one key is kept. They are not held first as a query result, so `--max-result-memory` does not stop the copy; the rows count toward the [transaction limits](limits.md) instead. It is still one statement: a bad row writes nothing, and the error names the row (`row 17000: ...`). This needs no `RETURNING`, no trigger on the table, and an `ON CONFLICT` only as `DO NOTHING` or a `DO UPDATE` that sets every other column from `EXCLUDED`. Any other query keeps its rows first, as before.
  - **Into a table without a key** (no `DEDUP KEY`, no `PRIMARY KEY`, not split by `SYMBOL(...)`), such a copy is written as columns, the way [/imp](http-import.md) writes: about 50 bytes a row in memory until the next checkpoint, not about 600. A loop copying 660k rows at a time stays near 80 MB of unsaved rows, not 750 MB.
  - **Into empty partitions of a table with a key** (a `DEDUP KEY` or `PRIMARY KEY` that is the whole `SORT BY`): when no partition the rows go to held a row before (a new month, or partitions a `DELETE` of the same transaction emptied) and the rows come in key order - as a copy from a table with the same `SORT BY` gives them - such a copy is written as columns too, and no key is looked up. A plain copy of every column, `INSERT INTO t SELECT a, b, c FROM s`, where `s` has the same columns and types, the same `SORT BY` and `PARTITION BY`, copies the partitions of `s` whole. The rows and the messages are the same as row by row: a key that repeats, or one already stored, sends the copy the row way, which reports it as before. `KDB_NO_INSERT_KEY_RUNS=1` and `KDB_NO_INSERT_COPY=1` turn these off.
  - A subquery can also be a value: `VALUES ((SELECT max(id) FROM t) + 1, 'x')`.

**Example: Copy the closes of one symbol into another table**

Setup:

```sql
CREATE TABLE ochl_day (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time);
CREATE TABLE city_close (time TIMESTAMP, close DOUBLE) TIMESERIES(time);
INSERT INTO ochl_day VALUES ('2026-09-09T09:00:00Z', 'CITY', 510), ('2026-09-10T09:00:00Z', 'CITY', 513), ('2026-09-10T09:00:00Z', 'COAST', 900);
```

```sql
INSERT INTO city_close SELECT time, close FROM ochl_day WHERE symbol = 'CITY';
SELECT * FROM city_close ORDER BY time;
```

Result:

`INSERT INTO city_close SELECT time, close FROM ochl_day WHERE symbol = 'CITY'`

```text
2 row(s) inserted
```

`SELECT * FROM city_close ORDER BY time`

| time (TIMESTAMP) | close (DOUBLE) |
|---|---|
| 2026-09-09T09:00:00.000Z | 510 |
| 2026-09-10T09:00:00.000Z | 513 |

(2 rows)

<a id="on-conflict"></a>

## ON CONFLICT (PostgreSQL upsert)

Syntax:

```sql
INSERT INTO table (columns) VALUES (...) | SELECT ...
  ON CONFLICT [(key columns) [WHERE condition] | ON CONSTRAINT name]
  DO NOTHING
  | DO UPDATE SET column = EXCLUDED.column, ... [WHERE condition]
  [RETURNING ..., (xmax = 0) AS inserted]
```

What to do when a new row has the same key as a row that is there.

- **DO NOTHING:** skip that row.
- **DO UPDATE:** change the row that is there. `EXCLUDED.column` is the value of the new row; `table.column` is the value that is there now.
- **Key columns:** the primary key, a `DEDUP KEY`, a `UNIQUE` column or constraint, or a `UNIQUE INDEX` with exactly these columns. `DO UPDATE` needs them; `DO NOTHING` without them means any unique key.
- **Partial unique index** (`CREATE UNIQUE INDEX ... WHERE ...`): `DO NOTHING` without key columns skips a clash in it too. To name it, write its columns and a `WHERE` that holds every `AND`-ed part of the index's own `WHERE` (in any order; more parts are fine). A `WHERE` that does not is an error, as in PostgreSQL.
- **RETURNING:** the rows that were inserted or updated. `xmax` is 0 for an inserted row and 1 for an updated one.
- **NULL:** a key with a NULL never clashes.
- **Notes:**
  - Two new rows with the same key in one `DO UPDATE` statement are an error (as in PostgreSQL).
  - `DO UPDATE SET` of every other column from `EXCLUDED` is as fast as `INSERT OR REPLACE`.
  - Write the table name before a column (`t.hits + 1`); a plain name is ambiguous in PostgreSQL.

**Example: Count visits per page: insert the first, update the rest**

Setup:

```sql
CREATE TABLE page_hits (page STRING PRIMARY KEY, hits LONG NOT NULL);
INSERT INTO page_hits VALUES ('/chart', 1);
```

```sql
INSERT INTO page_hits (page, hits) VALUES ('/chart', 1), ('/news', 1)
ON CONFLICT (page) DO UPDATE SET hits = page_hits.hits + EXCLUDED.hits
RETURNING page, hits, (xmax = 0) AS inserted;
```

Result:

| page (STRING) | hits (LONG) | inserted (BOOL) |
|---|---|---|
| /chart | 2 | false |
| /news | 1 | true |

(2 rows)

```text
1 row(s) inserted, 1 updated
```

**Example: One open job per key: a partial unique index**

Setup:

```sql
CREATE TABLE jobs (id INT, dedup_key STRING, status STRING);
CREATE UNIQUE INDEX jobs_open ON jobs (dedup_key) WHERE status <> 'done';
INSERT INTO jobs VALUES (1, 'report', 'queued');
```

```sql
INSERT INTO jobs VALUES (2, 'report', 'queued') ON CONFLICT DO NOTHING;
INSERT INTO jobs VALUES (3, 'report', 'queued') ON CONFLICT (dedup_key) WHERE status <> 'done' DO NOTHING;
SELECT id, status FROM jobs;
```

Result:

`INSERT INTO jobs VALUES (2, 'report', 'queued') ON CONFLICT DO NOTHING`

```text
0 row(s) inserted, 1 skipped (already there)
```

`INSERT INTO jobs VALUES (3, 'report', 'queued') ON CONFLICT (dedup_key) WHERE status != 'done' DO NO`

```text
0 row(s) inserted, 1 skipped (already there)
```

`SELECT id, status FROM jobs`

| id (INT) | status (STRING) |
|---|---|
| 1 | queued |

(1 row)
