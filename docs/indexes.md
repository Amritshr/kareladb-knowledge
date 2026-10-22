# Indexes

> Make WHERE and ORDER BY ... LIMIT fast with an index, and keep values unique with a UNIQUE index.

- Category: Indexes & search
- Keywords: index, secondary index, bitmap, USING BITMAP, bitmap index, roaring, low cardinality, IF NOT EXISTS, IF EXISTS, SHOW INDEX, SHOW INDEXES FROM, SHOW INDEXES ON, UNIQUE, duplicate value, keyset pagination, OFFSET pages, slow query, use index, built, memory_bytes, index_memory_bytes, warm, built at open, warm-indexes, KDB_WARM_INDEXES, building
- See also: [Full-text search](full-text-search.md), [EXPLAIN](explain.md), [Constraints](constraints.md), [Performance tips](performance-tips.md), [Limits](limits.md), [ALTER, RENAME and DROP TABLE](alter-table.md)

An **index** is a second, sorted list of some columns of a table. Each entry points to its row. It works like the index at the back of a book: KDB finds the rows at once and does not read the whole table.

- Every table is already sorted by its **storage key** (the `PRIMARY KEY`, or `SORT BY` / `DEDUP KEY` of a time-series table). A condition on another column reads every row. An index fixes that.
- An index lives **in memory**. Only its definition is saved with the table. After the database opens, `kdb serve` builds it from the rows on a background thread ([built at open](#warm)); a query that needs it before that builds it itself.
- Every `INSERT`, `UPDATE` and `DELETE` also changes the index. So writes are a little slower, and each index costs memory. Create indexes only for the columns your app really uses in `WHERE` and `ORDER BY`.
- The result of a query is the same with or without an index. Only the speed changes.

The examples use a small forum: tables `threads` and `posts` (`id`, `thread_id`, `parent_id`, `author`, `body`, `created_at`).

**Example: A forum shows the 3 newest posts of thread 1** (sample data: content-forum)

```sql
CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id);
SELECT id, author, created_at FROM posts
WHERE thread_id = 1
ORDER BY created_at DESC, id DESC
LIMIT 3;
```

Result:

`CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id)`

```text
index 'posts_thread_time' created on table 'posts' (8 rows)
```

`SELECT id, author, created_at FROM posts WHERE thread_id = 1 ORDER BY created_at DESC, id DESC LIMIT`

| id (LONG) | author (STRING) | created_at (TIMESTAMP) |
|---|---|---|
| 6 | sita | 2026-09-01T06:15:00.000Z |
| 5 | ram | 2026-09-01T05:45:00.000Z |
| 4 | gita | 2026-09-01T05:15:00.000Z |

(3 rows)

<a id="create-index"></a>

## CREATE INDEX

Syntax:

```sql
CREATE INDEX [IF NOT EXISTS] name ON table (column [, column ...])
```

Makes an index on one or more columns of a table. When the table already has rows, KDB builds the index at once and says how many rows it has.

| Argument | Type | Meaning |
|---|---|---|
| `name` | name | the index name; it must be unique in the whole database (a good habit: `table_columns`) |
| `table` | name | a relational or time-series table |
| `column` | names | 1 to 16 stored columns. The order matters (see [When an index is used](indexes.md#when-used)) |

- **Returns:** a message: `index 'name' created on table 'table' (N rows)`.
- **NULL:** rows with `NULL` values are in the index too, so `WHERE parent_id IS NULL` can use it.
- **IF NOT EXISTS:** when an index with this name already exists, nothing happens and there is no error. KDB does not compare the columns.
- **Notes:**
  - An index on `(a, b)` also helps queries on `a` alone. You do not need a second index on `(a)`.
  - Errors: the name is used already; the table or a column does not exist; a column is listed twice; another index of the table has the same columns; a computed column (`amount DOUBLE AS (...)`).
  - `CREATE INDEX` cannot run inside `BEGIN ... COMMIT`.
  - No index on an expression (`lower(email)`), no partial index (`WHERE ...`), no `INCLUDE`, no `CONCURRENTLY` (PostgreSQL has these).
  - `USING GIN (json_column)` on one `JSON` column makes an index of the keys and values inside the documents, for `@>`, `?` and `->> = 'text'` (see [GIN index](functions-json.md#gin)). Other `USING` methods make an ordinary index.
  - An index bigger than the setting `index_memory_bytes` (default 2 GB) is not built. Queries then read the table, and `SHOW INDEXES` shows `built` = `false`.
  - A column that an index uses cannot be dropped. `RENAME COLUMN` and `RENAME TABLE` keep the index. `DROP TABLE` drops the table's indexes.

**Example: Indexes for a forum: pages of a thread, replies, and posts of one author** (sample data: content-forum)

```sql
CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id);
CREATE INDEX posts_parent ON posts (parent_id);
CREATE INDEX posts_author ON posts (author);
SELECT id, author, body FROM posts WHERE parent_id = 1 ORDER BY created_at;
```

Result:

`CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id)`

```text
index 'posts_thread_time' created on table 'posts' (8 rows)
```

`CREATE INDEX posts_parent ON posts (parent_id)`

```text
index 'posts_parent' created on table 'posts' (8 rows)
```

`CREATE INDEX posts_author ON posts (author)`

```text
index 'posts_author' created on table 'posts' (8 rows)
```

`SELECT id, author, body FROM posts WHERE parent_id = 1 ORDER BY created_at`

| id (LONG) | author (STRING) | body (STRING) |
|---|---|---|
| 2 | sita | I agree, the profit grew 18%. |
| 3 | hari | Price is high now. Wait for a dip. |

(2 rows)

**Example: Trades of one broker in the trade_log table (a time-series table)** (sample data: sample)

```sql
CREATE INDEX trade_log_buyer ON trade_log (buyer);
SELECT date, transaction_id, symbol, quantity, rate
FROM trade_log
WHERE buyer = 45
ORDER BY transaction_id
LIMIT 3;
```

Result:

`CREATE INDEX trade_log_buyer ON trade_log (buyer)`

```text
index 'trade_log_buyer' created on table 'trade_log' (32 rows)
```

`SELECT date, transaction_id, symbol, quantity, rate FROM trade_log WHERE buyer = 45 ORDER BY transac`

| date (TIMESTAMP) | transaction_id (LONG) | symbol (SYMBOL) | quantity (LONG) | rate (DOUBLE) |
|---|---|---|---|---|
| 2026-09-09T00:00:00.000Z | 100002 | CITY | 10 | 515 |
| 2026-09-10T00:00:00.000Z | 100014 | COAST | 20 | 399.5 |
| 2026-09-10T00:00:00.000Z | 100018 | CITY | 500 | 516 |

(3 rows)

**Example: IF NOT EXISTS: a setup script can run again** (sample data: content-forum)

```sql
CREATE INDEX IF NOT EXISTS posts_author ON posts (author);
CREATE INDEX IF NOT EXISTS posts_author ON posts (author);
```

Result:

`CREATE INDEX IF NOT EXISTS posts_author ON posts (author)`

```text
index 'posts_author' created on table 'posts' (8 rows)
```

`CREATE INDEX IF NOT EXISTS posts_author ON posts (author)`

```text
index 'posts_author' already exists
```

**Example: The name is used already** (sample data: content-forum; shows an error)

Setup:

```sql
CREATE INDEX posts_author ON posts (author);
```

```sql
CREATE INDEX posts_author ON posts (author, created_at);
```

Result:

Error: `index 'posts_author' already exists (on table 'posts'); expected a new index name, or CREATE INDEX IF NOT EXISTS`

**Example: Not inside a transaction** (sample data: content-forum; shows an error)

```sql
BEGIN;
CREATE INDEX posts_author ON posts (author);
```

Result:

```text
transaction started
```

Error: `CREATE INDEX cannot be used inside a transaction; COMMIT or ROLLBACK first (the transaction was rolled back)`

<a id="create-unique-index"></a>

## CREATE UNIQUE INDEX

Syntax:

```sql
CREATE UNIQUE INDEX [IF NOT EXISTS] name ON table (column [, column ...])
```

An index that also makes sure no two rows have the same values in its columns. Use it for email addresses, user names, or "one vote per user per post".

| Argument | Type | Meaning |
|---|---|---|
| `name` | name | the index name, unique in the whole database |
| `table` | name | the table |
| `column` | names | 1 to 16 stored columns; with several columns, the **combination** must be unique |

- **Returns:** a message: `index 'name' created on table 'table' (N rows)`.
- **NULL:** `NULL` values never clash. Many rows may have a `NULL` email.
- **Notes:**
  - A write that breaks the rule fails with `duplicate value violates unique index '...'`, and the message names the value. Nothing is written. Your app can look for the word `unique` in the message and show "this email is already used".
  - The check covers `INSERT`, `INSERT OR REPLACE`, `UPDATE`, bulk loading and transactions. In a transaction the error rolls back the whole transaction.
  - Text must be exactly the same: `RAM@example.com` and `ram@example.com` are **different**. Save emails with `lower(...)` in your app.
  - `CREATE UNIQUE INDEX` on a table that already has two equal values fails, and names the value. Fix the rows first.
  - Bulk loading (`InsertRows`, line protocol) into a table with a `UNIQUE` index is slower: each row must be checked.

**Example: App users: one account per email address** (sample data: content-forum; shows an error)

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY, email STRING NOT NULL, name STRING);
CREATE UNIQUE INDEX users_email ON users (email);
INSERT INTO users VALUES (1, 'ram@example.com', 'Ram'), (2, 'sita@example.com', 'Sita');
```

```sql
INSERT INTO users VALUES (3, 'ram@example.com', 'Another Ram');
```

Result:

Error: `duplicate value violates unique index 'users_email' on table 'users': a row with email='ram@example.com' already exists`

**Example: NULL values never clash, and upper case letters make a different value** (sample data: content-forum)

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY, email STRING, name STRING);
CREATE UNIQUE INDEX users_email ON users (email);
INSERT INTO users VALUES (1, 'ram@example.com', 'Ram');
```

```sql
INSERT INTO users VALUES (2, NULL, 'Hari'), (3, NULL, 'Gita'), (4, 'RAM@example.com', 'Big Ram');
SELECT * FROM users ORDER BY id;
```

Result:

`INSERT INTO users VALUES (2, NULL, 'Hari'), (3, NULL, 'Gita'), (4, 'RAM@example.com', 'Big Ram')`

```text
3 row(s) inserted
```

`SELECT * FROM users ORDER BY id`

| id (LONG) | email (STRING) | name (STRING) |
|---|---|---|
| 1 | ram@example.com | Ram |
| 2 | NULL | Hari |
| 3 | NULL | Gita |
| 4 | RAM@example.com | Big Ram |

(4 rows)

**Example: Forum votes: one vote per user per post (two columns)** (sample data: content-forum; shows an error)

Setup:

```sql
CREATE TABLE votes (id LONG PRIMARY KEY, user_id LONG NOT NULL, post_id LONG NOT NULL, value INT NOT NULL);
CREATE UNIQUE INDEX votes_one_per_user ON votes (user_id, post_id);
INSERT INTO votes VALUES (1, 10, 1, 1), (2, 10, 2, 1), (3, 11, 1, -1);
```

```sql
INSERT INTO votes VALUES (4, 10, 1, -1);
```

Result:

Error: `duplicate value violates unique index 'votes_one_per_user' on table 'votes': a row with user_id='10', post_id='1' already exists`

**Example: The table already has two equal values** (sample data: content-forum; shows an error)

```sql
CREATE UNIQUE INDEX posts_one_per_author ON posts (author);
```

Result:

Error: `cannot create unique index 'posts_one_per_author': two rows of table 'posts' have author='gita'; each value may be used by one row only`

<a id="bitmap"></a>

## Bitmap index

Syntax:

```sql
CREATE INDEX name ON table USING BITMAP (column)
CREATE INDEX name ON table (column) WITH (kind = 'bitmap')
```

For a column with **few different values**: a symbol, a side (`B` / `S`), a status, a region. For each value the index keeps the set of rows that have it, as a compact bitmap. Two or more such conditions are answered together: `region = 5 AND status = 'open'` takes the rows in both sets at once (an AND of two bitmaps), not the rows of one index checked one by one.

| Argument | Type | Meaning |
|---|---|---|
| `name` | name | the index name |
| `column` | any stored column | one column only |

| Your query | Uses the bitmap indexes |
|---|---|
| `a = 5`, `a IN (1, 2)`, `a IS NULL` | yes |
| `a = 5 AND b = 'x'` (a bitmap index on each) | yes: the rows in both sets |
| `a = 5 AND b <> 'x'`, `a = 5 AND b NOT IN (...)` | yes: the rows of `a = 5`, without those of `b` |
| `(a = 5 OR b = 'x') AND c = 1` | yes: the rows in either set, then those of `c` too |
| `a = 5 AND MATCH(body, 'word')` (a [full-text index](full-text-search.md)) | yes: the sets and the matches combined |
| `a = 5 AND d BETWEEN 1 AND 99` (an ordinary index on `d`) | yes, when the range finds few rows: combined too |
| `a = 5 AND ts >= '2026-03-01' AND ts < '2026-04-01'` | yes: only the partitions of that month |
| `b <> 'x'` alone | no |
| `a > 5`, `a LIKE ...` | no: use an ordinary index |

- **Returns:** a message, like `CREATE INDEX`.
- **Notes:**
  - `EXPLAIN` says `use bitmap index: a_ix (1 value) AND b_ix (2 values), N row(s)`. An OR shows as `(a_ix (1 value) OR b_ix (1 value))`; a text search or an ordinary index combined with the sets adds `AND full-text name` or `AND index name (...)`. N is the rows all of them agree on: only those are read.
  - A text search with a filter: `MATCH(body, 'oil') AND symbol = 'X'` in one month used to read every row with the word and check the symbol on each. Now the matches and the symbol's set are combined first: on 1,000,000 rows, 5 ms instead of 99 ms. A word that is far more common than the filter (more than 32 matches per row of the sets) is still checked row by row.
  - On a table stored by the column (`symbol = 'X'` on a time-series table whose first `SYMBOL` column is its sort key), the storage key already finds the rows: the bitmap index is then used only together with a text search.
  - Like every index, it lives in memory and is built from the rows when first needed. Every `INSERT`, `UPDATE` and `DELETE` changes it. Rows that come in storage order (a time-series table) cost very little: their sets are long runs of rows.
  - The same cost rules as above: on a big table it is used when the sets together find few rows.
  - It cannot be `UNIQUE`, have an expression or a `WHERE`, or have two columns (make one bitmap index per column: they combine).
  - `SHOW INDEXES` shows its kind as `BITMAP`.

**Example: Open orders of one region: two bitmap indexes together** (sample data: content-forum)

Setup:

```sql
CREATE TABLE orders (id LONG PRIMARY KEY, region INT, status SYMBOL, amount DOUBLE);
INSERT INTO orders SELECT x, x % 7, CASE x % 3 WHEN 0 THEN 'open' WHEN 1 THEN 'paid' ELSE 'sent' END, x * 1.5
FROM generate_series(1, 300) g(x);
CREATE INDEX orders_region ON orders USING BITMAP (region);
CREATE INDEX orders_status ON orders (status) WITH (kind = 'bitmap');
```

```sql
SELECT count(*), sum(amount) FROM orders WHERE region = 5 AND status = 'open';
EXPLAIN SELECT id FROM orders WHERE region = 5 AND status = 'open';
EXPLAIN SELECT id FROM orders WHERE region IN (1, 2) AND status <> 'paid';
```

Result:

`SELECT count(*), sum(amount) FROM orders WHERE region = 5 AND status = 'open'`

| count(*) (LONG) | sum(amount) (DOUBLE) |
|---|---|
| 14 | 3118.5 |

(1 row)

`EXPLAIN SELECT id FROM orders WHERE region = 5 AND status = 'open'`

| plan (STRING) |
|---|
| scan table orders (1 of 1 partitions, about 300 rows) |
| use bitmap index: orders_region (1 value) AND orders_status (1 value), 14 row(s) |
| build 3 of 4 stored column(s) per row: id, region, status |
| filter while scanning: 2 condition(s) |
| engine: column |

(5 rows)

`EXPLAIN SELECT id FROM orders WHERE region IN (1, 2) AND status != 'paid'`

| plan (STRING) |
|---|
| scan table orders (1 of 1 partitions, about 300 rows) |
| use bitmap index: orders_region (2 values) AND NOT orders_status (1 value), 57 row(s) |
| build 3 of 4 stored column(s) per row: id, region, status |
| filter while scanning: 2 condition(s) |
| engine: column |

(5 rows)

**Example: An OR of two bitmap indexes, and a text search combined with them** (sample data: content-forum)

Setup:

```sql
CREATE TABLE notes (id LONG PRIMARY KEY, region INT, status SYMBOL, body STRING);
INSERT INTO notes SELECT x, x % 7, CASE x % 3 WHEN 0 THEN 'open' WHEN 1 THEN 'paid' ELSE 'sent' END,
  CASE WHEN x % 5 = 0 THEN 'oil price up' ELSE 'quiet day' END
FROM generate_series(1, 300) g(x);
CREATE INDEX notes_region ON notes USING BITMAP (region);
CREATE INDEX notes_status ON notes USING BITMAP (status);
CREATE FULLTEXT INDEX notes_body ON notes (body);
```

```sql
SELECT count(*) FROM notes WHERE (region = 5 OR status = 'open') AND MATCH(body, 'oil');
EXPLAIN SELECT id FROM notes WHERE (region = 5 OR status = 'open') AND MATCH(body, 'oil');
```

Result:

`SELECT count(*) FROM notes WHERE (region = 5 OR status = 'open') AND match(body, 'oil')`

| count(*) (LONG) |
|---|
| 26 |

(1 row)

`EXPLAIN SELECT id FROM notes WHERE (region = 5 OR status = 'open') AND match(body, 'oil')`

| plan (STRING) |
|---|
| scan table notes (1 of 1 partitions, about 300 rows) |
| use bitmap index: (notes_region (1 value) OR notes_status (1 value)) AND full-text notes_body, 26 row(s) |
| filter while scanning: 2 condition(s) |
| engine: row (a condition the column engine does not do) |

(4 rows)

<a id="drop-index"></a>

## DROP INDEX

Syntax:

```sql
DROP INDEX [IF EXISTS] name
```

Removes an index. The rows of the table do not change.

| Argument | Type | Meaning |
|---|---|---|
| `name` | name | the index name (you do not name the table: index names are unique in the database) |

- **Returns:** a message: `index 'name' dropped`.
- **IF EXISTS:** when there is no such index, the message is `index 'name' does not exist` and there is no error.
- **Notes:** `DROP INDEX` cannot run inside `BEGIN ... COMMIT`. To drop a column that an index uses, drop the index first.

**Example: Drop an index, then run the same script again** (sample data: content-forum)

Setup:

```sql
CREATE INDEX posts_author ON posts (author);
```

```sql
DROP INDEX posts_author;
DROP INDEX IF EXISTS posts_author;
```

Result:

`DROP INDEX posts_author`

```text
index 'posts_author' dropped
```

`DROP INDEX IF EXISTS posts_author`

```text
index 'posts_author' does not exist
```

**Example: There is no such index** (sample data: content-forum; shows an error)

```sql
DROP INDEX posts_author;
```

Result:

Error: `cannot drop index 'posts_author': it does not exist`

**Example: A column that an index uses cannot be dropped** (sample data: content-forum; shows an error)

Setup:

```sql
CREATE INDEX posts_parent ON posts (parent_id);
```

```sql
ALTER TABLE posts DROP COLUMN parent_id;
```

Result:

Error: `cannot drop column 'parent_id' from table 'posts': index 'posts_parent' uses it; DROP INDEX posts_parent first`

<a id="show-indexes"></a>

## SHOW INDEXES

Syntax:

```sql
SHOW INDEXES
SHOW INDEXES FROM table
SHOW INDEXES ON table
```

Lists the indexes of the database, or of one table. `SHOW INDEX` is the same.

| Column | Type | Meaning |
|---|---|---|
| `name` | STRING | index name |
| `table` | STRING | table name |
| `kind` | STRING | `INDEX`, `UNIQUE`, `FULLTEXT`, or `GIN` (a [JSON index](functions-json.md#gin)) |
| `columns` | STRING | the columns, in index order |
| `built` | BOOL | `true` when the index is in memory now |
| `rows` | LONG | entries in the index; `NULL` when not built |
| `memory_bytes` | LONG | memory the index uses; `NULL` when not built |
| `create_sql` | STRING | the `CREATE ... INDEX` statement that makes the index again |
| `building` | BOOL | `true` while the server's warm-up thread is building it right now (see [Built at open](#warm)) |

- **Notes:** a table that does not exist gives an error. `SHOW CREATE TABLE` also lists the table's `CREATE INDEX` statements (see [show-tables](show-tables.md)).

**Example: The index is built by the first query that needs it** (sample data: content-forum)

Setup:

```sql
CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id);
CREATE INDEX posts_author ON posts (author);
```

```sql
SHOW INDEXES FROM posts;
SELECT count(*) AS posts FROM posts WHERE thread_id = 1;
SHOW INDEXES FROM posts;
```

Result:

`SHOW INDEXES FROM posts`

| name (STRING) | table (STRING) | kind (STRING) | columns (STRING) | built (BOOL) | rows (LONG) | memory_bytes (LONG) | create_sql (STRING) | building (BOOL) |
|---|---|---|---|---|---|---|---|---|
| posts_thread_time | posts | INDEX | thread_id, created_at, id | false | NULL | NULL | CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id) | false |
| posts_author | posts | INDEX | author | false | NULL | NULL | CREATE INDEX posts_author ON posts (author) | false |

(2 rows)

`SELECT count(*) AS posts FROM posts WHERE thread_id = 1`

| posts (LONG) |
|---|
| 6 |

(1 row)

`SHOW INDEXES FROM posts`

| name (STRING) | table (STRING) | kind (STRING) | columns (STRING) | built (BOOL) | rows (LONG) | memory_bytes (LONG) | create_sql (STRING) | building (BOOL) |
|---|---|---|---|---|---|---|---|---|
| posts_thread_time | posts | INDEX | thread_id, created_at, id | true | 8 | 400 | CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id) | false |
| posts_author | posts | INDEX | author | false | NULL | NULL | CREATE INDEX posts_author ON posts (author) | false |

(2 rows)

Here the database was opened again after `CREATE INDEX` with `kdb sql`, so no index was in memory at first. The `SELECT` built `posts_thread_time`; `posts_author` is still not built.

<a id="warm"></a>

## Built at open

`kdb serve` builds every index of a database **right after it opens**, on a background thread, so the first query finds them ready instead of paying for the build (about 0.2 s per million rows for a plain index, a few seconds for a full-text index over 200,000 articles). Nothing else waits for it:

- The open itself takes the same time, and `/health`, `/api/stats` and every query answer while it runs. A query that needs an index the thread has not reached yet builds it itself, as before.
- The order is `UNIQUE` indexes first, then the smallest tables, `FULLTEXT` indexes last.
- Writes are never blocked for long: between two waves of partitions the thread lets writers go first, and an index whose table changed meanwhile is dropped and built again (once more by the thread, then by the first query that needs it).
- An index bigger than `index_memory_bytes` is not built, exactly as by a query. When the indexes built so far fill `index_memory_bytes`, the thread stops, and the rest are built on first use. `SHOW INDEXES` shows `building` = `true` for the index the thread is on.
- After the indexes, the same thread computes the [pinned queries](pinned-queries.md), so a pinned search finds its text index ready.
- `kdb serve --warm-indexes off` (or `KDB_WARM_INDEXES=off`) goes back to building on first use. `kdb sql` never warms: it runs its statements and closes.

**Example: Every index of the database** (sample data: content-forum)

Setup:

```sql
CREATE INDEX posts_author ON posts (author);
CREATE TABLE users (id LONG PRIMARY KEY, email STRING NOT NULL);
CREATE UNIQUE INDEX users_email ON users (email);
CREATE FULLTEXT INDEX posts_body ON posts (body);
```

```sql
SHOW INDEXES;
```

Result:

| name (STRING) | table (STRING) | kind (STRING) | columns (STRING) | built (BOOL) | rows (LONG) | memory_bytes (LONG) | create_sql (STRING) | building (BOOL) |
|---|---|---|---|---|---|---|---|---|
| posts_author | posts | INDEX | author | false | NULL | NULL | CREATE INDEX posts_author ON posts (author) | false |
| posts_body | posts | FULLTEXT | body | false | NULL | NULL | CREATE FULLTEXT INDEX posts_body ON posts (body) | false |
| users_email | users | UNIQUE | email | false | NULL | NULL | CREATE UNIQUE INDEX users_email ON users (email) | false |

(3 rows)

<a id="when-used"></a>

## When an index is used

Syntax:

```sql
EXPLAIN SELECT ...
```

KDB picks an index by itself. There is no hint to force one. Put [EXPLAIN](explain.md) before a query: the line `use index <name>` says which index is used. No such line: every row is read.

For an index on the columns `(a, b, c)`:

| Your query | Uses the index |
|---|---|
| `a = 5`, `a IN (1, 2, 3)`, `a IS NULL` | yes |
| `a = 5 AND b = 7` | yes, both columns |
| `a > 5`, `a BETWEEN ...`, `a LIKE 'abc%'` | yes: a range of `a` |
| `a = 5 AND b > 100` | yes: `a` exactly, then a range of `b` |
| `a = 5 ORDER BY b DESC LIMIT 20` | yes, and it stops after 20 rows |
| `a = 5 AND (b, c) < (x, y) ORDER BY b DESC, c DESC LIMIT 20` | yes: keyset pagination (below) |
| `b = 7` alone | no: `b` is not the first column |
| `a = 5 OR a = 7` | yes: the rows of each side, once (or write `a IN (5, 7)`) |
| `a = 5 OR x = 7`, with another index that starts with `x` | yes: each side uses its own index |
| `a = 5 OR b = 7` | no: `b = 7` has no index of its own, so every row is read |
| `lower(a) = 'x'`, `a + 1 = 6` | no: a function or math around the column |
| `a != 5`, `a NOT IN (...)`, `a LIKE '%abc'`, `NOT LIKE` | no |

- **Notes:**
  - Put the column you compare with `=` first, and the column you sort by or compare with `<` / `>` next. For "the newest N rows of X" use `(x, time)`, for example `(thread_id, created_at, id)`.
  - When the condition already uses the table's storage key (like `id = 3` on a `PRIMARY KEY` table), KDB does not need an index.
  - KDB compares the cost first. An index reads its rows one by one; a scan reads rows in big pieces on all threads, about 1,000 times cheaper per row. So an index is used only when it finds **few** rows. When a scan is cheaper, `EXPLAIN` says `no index: <name> would read N row(s), a scan is cheaper` (see the [example in EXPLAIN](explain.md#plan-lines)).
  - On a big table an index that finds a quarter of the rows, or a symbol that is in every partition, is not used. Tables of up to 10,000 rows cost nothing either way: they keep the index, so the small examples here show it.
  - **`OR`:** when every side of an `OR` has an index, like `email = $1 OR phone = $1` with one index on `email` and one on `phone`, each index finds its rows and a row found by both is read once. `EXPLAIN` says `use index users_email (...) OR index users_phone (...)`. On 100,000 users the login by email or phone went from a read of every row (22 to 75 ms) to 0.1 ms.
  - With `ORDER BY ... LIMIT`, KDB reads the index in order but gives up soon when most rows fail the other conditions, then finds the rows another way. A keyset page is never much slower than a scan.
  - In a `JOIN`, only the first table (after `FROM`) uses an index.
  - `UPDATE ... WHERE` and `DELETE ... WHERE` use indexes too, whenever one fits: they do not compare the cost with a scan.
  - A text column compared with a number (`author = 5`) does not use the index.
  - **Keyset pagination:** for the next page, remember `created_at` and `id` of the last row shown, and ask for rows before it with a row comparison `(created_at, id) < (..., ...)`. Page 1000 is as fast as page 1. `LIMIT 20 OFFSET 20000` must still count 20,000 rows, so it gets slower on every page.

**Example: A forum page: the index gives the rows in order and stops after 3** (sample data: content-forum)

Setup:

```sql
CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id);
```

```sql
EXPLAIN SELECT id FROM posts WHERE thread_id = 1 ORDER BY created_at DESC, id DESC LIMIT 3;
```

Result:

| plan (STRING) |
|---|
| scan table posts (1 of 1 partitions, about 8 rows) |
| use index posts_thread_time (thread_id = value, rows in ORDER BY order, stops after 3 row(s)) |
| build 3 of 6 stored column(s) per row: id, thread_id, created_at |
| filter while scanning: 1 condition(s) |
| sort by 2 key(s) |
| limit 3 |
| engine: column |

(7 rows)

**Example: Next page (keyset pagination): posts older than post 4** (sample data: content-forum)

Setup:

```sql
CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id);
```

```sql
SELECT id, author, created_at FROM posts
WHERE thread_id = 1 AND (created_at, id) < ('2026-09-01T11:00:00+05:45', 4)
ORDER BY created_at DESC, id DESC
LIMIT 3;
```

Result:

| id (LONG) | author (STRING) | created_at (TIMESTAMP) |
|---|---|---|
| 3 | hari | 2026-09-01T04:35:00.000Z |
| 2 | sita | 2026-09-01T04:20:00.000Z |
| 1 | ram | 2026-09-01T04:15:00.000Z |

(3 rows)

**Example: IN and LIKE 'text%' use the index; a function around the column does not** (sample data: content-forum)

Setup:

```sql
CREATE INDEX posts_author ON posts (author);
```

```sql
EXPLAIN SELECT id FROM posts WHERE author IN ('ram', 'sita');
EXPLAIN SELECT id FROM posts WHERE author LIKE 'ra%';
EXPLAIN SELECT id FROM posts WHERE lower(author) = 'ram';
```

Result:

`EXPLAIN SELECT id FROM posts WHERE author IN ('ram', 'sita')`

| plan (STRING) |
|---|
| scan table posts (1 of 1 partitions, about 8 rows) |
| use index posts_author (author in 2 values) |
| build 2 of 6 stored column(s) per row: id, author |
| filter while scanning: 1 condition(s) |
| engine: column |

(5 rows)

`EXPLAIN SELECT id FROM posts WHERE author LIKE 'ra%'`

| plan (STRING) |
|---|
| scan table posts (1 of 1 partitions, about 8 rows) |
| use index posts_author (author in a range) |
| build 2 of 6 stored column(s) per row: id, author |
| filter while scanning: 1 condition(s) |
| engine: column |

(5 rows)

`EXPLAIN SELECT id FROM posts WHERE lower(author) = 'ram'`

| plan (STRING) |
|---|
| scan table posts (1 of 1 partitions, about 8 rows) |
| build 2 of 6 stored column(s) per row: id, author |
| filter while scanning: 1 condition(s) |
| engine: row (a condition the column engine does not do) |

(4 rows)

**Example: Not the first column of the index: the table is read** (sample data: content-forum)

Setup:

```sql
CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id);
```

```sql
EXPLAIN SELECT id FROM posts WHERE created_at > '2026-09-01';
```

Result:

| plan (STRING) |
|---|
| scan table posts (1 of 1 partitions, about 8 rows) |
| build 2 of 6 stored column(s) per row: id, created_at |
| filter while scanning: 1 condition(s) |
| engine: column |

(4 rows)
