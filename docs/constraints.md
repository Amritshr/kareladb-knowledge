# Constraints

> Rules that keep table data correct: PRIMARY KEY, AUTO, NOT NULL, UNIQUE, DEFAULT, REFERENCES and CHECK.

- Category: Constraints
- Keywords: constraint, rule, column rule, primary key, key, auto increment, autoincrement, serial, identity, sequence, AUTO, not null, required, unique, duplicate, default value, DEFAULT, foreign key, references, REFERENCES, parent row, ON DELETE CASCADE, check, CHECK, CONSTRAINT, validation, data integrity, cannot be NULL, must be unique, has no matching row, still refers to it, CHECK constraint failed, NaN, bad price, price check
- See also: [CREATE TABLE](create-table.md), [ALTER, RENAME and DROP TABLE](alter-table.md), [INSERT](insert.md), [UPDATE and DELETE](update-delete.md), [Indexes](indexes.md), [Transactions](transactions.md)

A **constraint** is a rule for the rows of a table. KarelaDB checks the rules every time a row is written (`INSERT`, `INSERT OR REPLACE`, `UPDATE`, the C++ `InsertRows`, the line protocol). A row that breaks a rule is **not** written, and the whole statement fails. So your app can never store a user without an email, a negative balance, or a trade for a broker that does not exist.

| Rule | Meaning | Error when broken |
|---|---|---|
| [`PRIMARY KEY`](#primary-key) | one row per value; never NULL | `a row with id='1' already exists` |
| [`AUTO`](#auto) | KarelaDB gives the next id | |
| [`NOT NULL`](#not-null) | the column must have a value | `cannot be NULL` |
| [`UNIQUE`](#unique) | no two rows with the same value | `must be unique: ... is already used` |
| [`DEFAULT`](#default) | the value when an INSERT gives none | |
| [`REFERENCES`](#references) | the value must exist in another table | `has no matching row in` / `still refers to it` |
| [`CHECK`](#check) | a condition every row must meet | `CHECK constraint '...' failed` |

A real example: the accounting tables of an app.

**Example: Users, accounts and a ledger with every kind of rule**

```sql
CREATE TABLE users (
  id            INT PRIMARY KEY AUTO,
  email         STRING NOT NULL UNIQUE,
  password_hash STRING NOT NULL,
  created       TIMESTAMP DEFAULT now()
);
CREATE TABLE accounts (
  id      INT PRIMARY KEY AUTO,
  user_id INT NOT NULL REFERENCES users(id),
  balance DECIMAL(2) NOT NULL DEFAULT 0 CHECK (balance >= 0)
);
CREATE TABLE ledger (
  id           LONG PRIMARY KEY AUTO,
  from_account INT NOT NULL REFERENCES accounts(id),
  to_account   INT NOT NULL REFERENCES accounts(id),
  amount       DECIMAL(2) NOT NULL,
  created      TIMESTAMP DEFAULT now(),
  CONSTRAINT positive_amount CHECK (amount > 0),
  CONSTRAINT two_accounts CHECK (from_account != to_account)
);
SHOW CREATE TABLE ledger;
```

Result:

`CREATE TABLE users (`

```text
table 'users' created
```

`CREATE TABLE accounts (`

```text
table 'accounts' created
```

`CREATE TABLE ledger (`

```text
table 'ledger' created
```

`SHOW CREATE TABLE ledger`

| create_sql (STRING) |
|---|
| CREATE TABLE ledger (   id LONG PRIMARY KEY AUTO,   from_account INT NOT NULL REFERENCES accounts(id),   to_account INT NOT NULL REFERENCES accounts(id),   amount DECIMAL(2) NOT NULL,   created TIM... |

(1 row)

<a id="primary-key"></a>

## PRIMARY KEY

Syntax:

```sql
column TYPE PRIMARY KEY [AUTO]
```

The column that identifies a row. There is **one row per value**. Rows are kept in key order, so finding a row by its key is fast.

- At most one `PRIMARY KEY` per table, on one column. For a key over many columns, use `CREATE UNIQUE INDEX` ([indexes](indexes.md)).
- A key can never be `NULL` (you do not need to write `NOT NULL`).
- `UPDATE` may change a key; it is refused when the new value is already used.
- **Returns:** a duplicate key gives `a row with id='...' already exists in 't'`; nothing of that statement is saved. Use `INSERT OR REPLACE` or `INSERT OR IGNORE` to decide what happens ([INSERT](insert.md#duplicates)).
- **Notes:** only for relational tables. A time-series table uses [DEDUP KEY](create-table.md#dedup-key) instead. You cannot add a primary key with `ALTER TABLE` later.

**Example: One row per broker**

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
INSERT INTO brokers VALUES (58, 'Northgate Securities'), (1, 'Keystone Securities');
SELECT id, name FROM brokers;
```

Result:

`CREATE TABLE brokers (`

```text
table 'brokers' created
```

`INSERT INTO brokers VALUES (58, 'Northgate Securities'), (1, 'Keystone Securities')`

```text
2 row(s) inserted
```

`SELECT id, name FROM brokers`

| id (INT) | name (STRING) |
|---|---|
| 1 | Keystone Securities |
| 58 | Northgate Securities |

(2 rows)

**Example: The same broker number twice** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
INSERT INTO brokers VALUES (58, 'Northgate Securities');
```

```sql
INSERT INTO brokers VALUES (58, 'Another Broker');
```

Result:

Error: `a row with id='58' already exists in 'brokers'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it`

**Example: A key cannot be NULL** (shows an error)

Setup:

```sql
CREATE TABLE securities (symbol SYMBOL PRIMARY KEY, name STRING);
```

```sql
INSERT INTO securities (name) VALUES ('No symbol');
```

Result:

Error: `column 'symbol' (SYMBOL): cannot be NULL`

<a id="auto"></a>

## PRIMARY KEY AUTO

Syntax:

```sql
column BYTE | SHORT | INT | LONG PRIMARY KEY AUTO
```

When an `INSERT` gives no value (or `NULL`) for the key, KarelaDB uses the **next number** of the table's counter: 1, 2, 3, ... This is like `SERIAL` or `IDENTITY` in PostgreSQL.

- You may still give an id yourself. A bigger id moves the counter up: after id 10, the next automatic id is 11.
- The counter **only goes up**. The id of a deleted row, of a failed insert, or of a rolled-back transaction is never used again, so there can be gaps (1, 2, 4, ...).
- **Returns:** use `RETURNING id` to get the new id back ([RETURNING](insert.md#returning)).
- **Notes:** only on an integer `PRIMARY KEY`. Do not use AUTO ids to count rows. When the counter passes the type's range (127 for `BYTE`), the insert fails; use `LONG` for big tables.

**Example: New forum posts get ids 1, 2, 3**

```sql
CREATE TABLE posts (id LONG PRIMARY KEY AUTO, author STRING NOT NULL, body STRING NOT NULL);
INSERT INTO posts (author, body) VALUES ('ram', 'Is CITY a good buy?'), ('sita', 'I agree, the profit grew 18%.');
INSERT INTO posts (author, body) VALUES ('hari', 'Price is high now.');
SELECT id, author, body FROM posts;
```

Result:

`CREATE TABLE posts (`

```text
table 'posts' created
```

`INSERT INTO posts (author, body) VALUES ('ram', 'Is CITY a good buy?'), ('sita', 'I agree, the profi`

```text
2 row(s) inserted
```

`INSERT INTO posts (author, body) VALUES ('hari', 'Price is high now.')`

```text
1 row(s) inserted
```

`SELECT id, author, body FROM posts`

| id (LONG) | author (STRING) | body (STRING) |
|---|---|---|
| 1 | ram | Is CITY a good buy? |
| 2 | sita | I agree, the profit grew 18%. |
| 3 | hari | Price is high now. |

(3 rows)

**Example: Ids of deleted rows are not used again**

Setup:

```sql
CREATE TABLE posts (id LONG PRIMARY KEY AUTO, body STRING NOT NULL);
INSERT INTO posts (body) VALUES ('first'), ('second'), ('third');
```

```sql
DELETE FROM posts WHERE id = 3;
INSERT INTO posts (id, body) VALUES (10, 'imported with its old id');
INSERT INTO posts (body) VALUES ('new post');
SELECT id, body FROM posts;
```

Result:

`DELETE FROM posts WHERE id = 3`

```text
1 row(s) deleted
```

`INSERT INTO posts (id, body) VALUES (10, 'imported with its old id')`

```text
1 row(s) inserted
```

`INSERT INTO posts (body) VALUES ('new post')`

```text
1 row(s) inserted
```

`SELECT id, body FROM posts`

| id (LONG) | body (STRING) |
|---|---|
| 1 | first |
| 2 | second |
| 10 | imported with its old id |
| 11 | new post |

(4 rows)

**Example: AUTO needs a whole-number column** (shows an error)

```sql
CREATE TABLE users (id STRING PRIMARY KEY AUTO, email STRING);
```

Result:

Error: `line 1, column 43: PRIMARY KEY AUTO needs an integer column; expected BYTE, SHORT, INT or LONG but column 'id' is STRING`

<a id="not-null"></a>

## NOT NULL

Syntax:

```sql
column TYPE NOT NULL
```

The column must always have a value. An `INSERT` that gives no value (and there is no `DEFAULT`), or gives `NULL`, fails. An `UPDATE ... SET column = NULL` fails too.

- **Returns:** `column 'name' (STRING): cannot be NULL`.
- **Notes:** a `DEFAULT` fills the column only when the `INSERT` does not name it. An explicit `NULL` is still refused. To add a `NOT NULL` column to a table with rows, give it a `DEFAULT` ([ADD COLUMN](alter-table.md#add-column)). The time column of a time-series table always needs a value: `the time column 'time' needs a value`.

**Example: Every user needs an email**

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL, phone STRING);
INSERT INTO users (email) VALUES ('ram@example.com');
SELECT id, email, phone FROM users;
```

Result:

`CREATE TABLE users (`

```text
table 'users' created
```

`INSERT INTO users (email) VALUES ('ram@example.com')`

```text
1 row(s) inserted
```

`SELECT id, email, phone FROM users`

| id (LONG) | email (STRING) | phone (STRING) |
|---|---|---|
| 1 | ram@example.com | NULL |

(1 row)

**Example: A user without an email** (shows an error)

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL, phone STRING);
```

```sql
INSERT INTO users (phone) VALUES ('9800000000');
```

Result:

Error: `column 'email' (STRING): cannot be NULL`

**Example: NOT NULL with a DEFAULT: leaving it out is fine, NULL is not** (shows an error)

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY AUTO, status STRING NOT NULL DEFAULT 'active');
```

```sql
INSERT INTO accounts (id) VALUES (1);
SELECT id, status FROM accounts;
INSERT INTO accounts (id, status) VALUES (2, NULL);
```

Result:

`INSERT INTO accounts (id) VALUES (1)`

```text
1 row(s) inserted
```

`SELECT id, status FROM accounts`

| id (INT) | status (STRING) |
|---|---|
| 1 | active |

(1 row)

Error: `column 'status' (STRING): cannot be NULL`

<a id="unique"></a>

## UNIQUE

Syntax:

```sql
column TYPE UNIQUE
```

No two rows may have the same value in this column. `NULL` does not count: many rows may have `NULL`.

- A table may have many `UNIQUE` columns (email, phone, username).
- Checked on `INSERT`, `INSERT OR REPLACE` and `UPDATE`, and also between the rows of one statement.
- **Returns:** `column 'email' must be unique: 'ram@example.com' is already used`.
- **Notes:** `INSERT OR REPLACE` replaces a row with the same **key**, not a row with the same unique value: a clash on a `UNIQUE` column is still an error. For a rule over many columns (one row per symbol, year and quarter), use `CREATE UNIQUE INDEX` ([indexes](indexes.md)). Text compares exactly: `'Ram@Example.com'` and `'ram@example.com'` are different; store emails in lower case.

**Example: One account per email; many users without a phone**

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE, phone STRING UNIQUE);
INSERT INTO users (email, phone) VALUES ('ram@example.com', NULL), ('sita@example.com', NULL), ('hari@example.com', '9800000000');
SELECT id, email, phone FROM users;
```

Result:

`CREATE TABLE users (`

```text
table 'users' created
```

`INSERT INTO users (email, phone) VALUES ('ram@example.com', NULL), ('sita@example.com', NULL), ('har`

```text
3 row(s) inserted
```

`SELECT id, email, phone FROM users`

| id (LONG) | email (STRING) | phone (STRING) |
|---|---|---|
| 1 | ram@example.com | NULL |
| 2 | sita@example.com | NULL |
| 3 | hari@example.com | 9800000000 |

(3 rows)

**Example: Register the same email twice** (shows an error)

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE);
INSERT INTO users (email) VALUES ('ram@example.com');
```

```sql
INSERT INTO users (email) VALUES ('ram@example.com');
```

Result:

Error: `column 'email' must be unique: 'ram@example.com' is already used`

**Example: Change an email to one that is taken** (shows an error)

Setup:

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL UNIQUE);
INSERT INTO users (email) VALUES ('ram@example.com'), ('sita@example.com');
```

```sql
UPDATE users SET email = 'ram@example.com' WHERE id = 2;
```

Result:

Error: `column 'email' must be unique: 'ram@example.com' is already used`

<a id="default"></a>

## DEFAULT

Syntax:

```sql
column TYPE DEFAULT expression
```

The value a column gets when an `INSERT` does not name it. Also used by `INSERT OR REPLACE` for columns you do not give, and for old rows by `ALTER TABLE ... ADD COLUMN`.

| Default | Example |
|---|---|
| a constant | `DEFAULT 0`, `DEFAULT 'active'`, `DEFAULT FALSE`, `DEFAULT '{}'` for JSON |
| an expression without columns | `DEFAULT -1`, `DEFAULT 60 * 24` |
| a function | `DEFAULT now()`, `DEFAULT gen_random_uuid()`, `DEFAULT random_token()` |

- `now()` and random functions are worked out for **each** inserted row.
- **Notes:** a default cannot use columns (write a computed column `AS (...)` for that) or subqueries. A constant must fit the column type: `INT DEFAULT 'x'` is refused when the table is created. `NOT NULL DEFAULT NULL` is refused. An explicit `NULL` in an `INSERT` does not use the default. There is no `DEFAULT` keyword inside `VALUES (...)`: leave the column out of the column list instead.

**Example: New accounts start active, with 0.00 and a creation time**

```sql
CREATE TABLE accounts (
  id      INT PRIMARY KEY AUTO,
  owner   STRING NOT NULL,
  balance DECIMAL(2) NOT NULL DEFAULT 0,
  status  STRING NOT NULL DEFAULT 'active',
  opened  TIMESTAMP DEFAULT now()
);
INSERT INTO accounts (owner) VALUES ('Ram Sharma');
INSERT INTO accounts (owner, balance, status) VALUES ('Sita Rai', 99.50, 'frozen');
SELECT id, owner, balance, status, opened IS NOT NULL AS has_open_time FROM accounts;
```

Result:

`CREATE TABLE accounts (`

```text
table 'accounts' created
```

`INSERT INTO accounts (owner) VALUES ('Ram Sharma')`

```text
1 row(s) inserted
```

`INSERT INTO accounts (owner, balance, status) VALUES ('Sita Rai', 99.50, 'frozen')`

```text
1 row(s) inserted
```

`SELECT id, owner, balance, status, opened IS NOT NULL AS has_open_time FROM accounts`

| id (INT) | owner (STRING) | balance (DECIMAL(2)) | status (STRING) | has_open_time (BOOL) |
|---|---|---|---|---|
| 1 | Ram Sharma | 0.00 | active | true |
| 2 | Sita Rai | 99.50 | frozen | true |

(2 rows)

**Example: A default of the wrong type** (shows an error)

```sql
CREATE TABLE posts (id LONG PRIMARY KEY AUTO, likes INT DEFAULT 'none');
```

Result:

Error: `column 'likes' of table 'posts' is INT but its DEFAULT 'none' is text; expected a whole number`

**Example: A default cannot use another column** (shows an error)

```sql
CREATE TABLE posts (id LONG PRIMARY KEY AUTO, created TIMESTAMP, edited TIMESTAMP DEFAULT created);
```

Result:

Error: `column 'edited' of table 'posts' has DEFAULT using column 'created'; expected a constant such as 0 or 'n/a', or AS (...) for a computed column`

<a id="references"></a>

## REFERENCES

Syntax:

```sql
column TYPE REFERENCES table(column)
```

The value must exist in the other table (the **parent**). This is a **foreign key**. Use it so a trade cannot point to a broker that does not exist, and a ledger row cannot point to a missing account.

| Argument | Meaning |
|---|---|
| `table` | the parent table; it must exist already (or be the same table) |
| `column` | the parent column; it must be the `PRIMARY KEY` or `UNIQUE`, with the same kind of type (any integer type fits any integer type; a `SYMBOL` may point to a `STRING`) |

What KarelaDB checks:

| Action | Result |
|---|---|
| `INSERT` or `UPDATE` of a child row with a value the parent does not have | error: `column 'buyer' = '99' has no matching row in brokers(id)` |
| `NULL` in the child column | allowed, not checked (add `NOT NULL` to forbid it) |
| `DELETE` of a parent row that children still use, or `UPDATE` of its key | error: `cannot remove brokers(id) = '58': ... still refers to it` |
| `INSERT OR REPLACE` of a parent row with the same key | allowed |
| `DROP TABLE` of the parent | error while a child column references it |

- **Notes:** `ON DELETE` / `ON UPDATE` take `NO ACTION` (the default: refuse while children point to the row), `RESTRICT`, `CASCADE` (delete the children too; ON UPDATE CASCADE follows the new key), `SET NULL` and `SET DEFAULT`. All children are changed in the same statement, or none. Children that `SET NULL`, `SET DEFAULT` or `ON UPDATE CASCADE` change are an update of the child table: its `BEFORE UPDATE` row triggers and `UPDATE` triggers run for them (as in PostgreSQL), and a trigger that refuses stops the whole statement. What such a trigger changes is checked like a plain UPDATE (references, CHECK, the time column); it may not change a UNIQUE or key column there - do that with a separate `UPDATE`. Children `ON DELETE CASCADE` removes fire its `DELETE` triggers. Load the parent table before the child table. A new row cannot point to a row inserted **in the same statement** (a reply and its parent post in one `INSERT`): insert the parent first. REFERENCES checks every new row, so very big imports are faster without it.

**Example: Trades must use real brokers**

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
CREATE TABLE trades (id LONG PRIMARY KEY AUTO, symbol SYMBOL, buyer INT NOT NULL REFERENCES brokers(id), seller INT REFERENCES brokers(id));
INSERT INTO brokers VALUES (58, 'Northgate Securities'), (45, 'Imperial Securities');
```

```sql
INSERT INTO trades (symbol, buyer, seller) VALUES ('CITY', 58, 45), ('COAST', 45, NULL);
SELECT id, symbol, buyer, seller FROM trades;
```

Result:

`INSERT INTO trades (symbol, buyer, seller) VALUES ('CITY', 58, 45), ('COAST', 45, NULL)`

```text
2 row(s) inserted
```

`SELECT id, symbol, buyer, seller FROM trades`

| id (LONG) | symbol (SYMBOL) | buyer (INT) | seller (INT) |
|---|---|---|---|
| 1 | CITY | 58 | 45 |
| 2 | COAST | 45 | NULL |

(2 rows)

**Example: A broker that does not exist** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
CREATE TABLE trades (id LONG PRIMARY KEY AUTO, buyer INT NOT NULL REFERENCES brokers(id));
INSERT INTO brokers VALUES (58, 'Northgate Securities');
```

```sql
INSERT INTO trades (buyer) VALUES (99);
```

Result:

Error: `column 'buyer' = '99' has no matching row in brokers(id)`

**Example: A broker with trades cannot be deleted** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
CREATE TABLE trades (id LONG PRIMARY KEY AUTO, buyer INT NOT NULL REFERENCES brokers(id));
INSERT INTO brokers VALUES (58, 'Northgate Securities');
INSERT INTO trades (buyer) VALUES (58);
```

```sql
DELETE FROM brokers WHERE id = 58;
```

Result:

Error: `cannot remove brokers(id) = '58': table 'trades' column 'buyer' still refers to it (foreign key 'trades_buyer_fkey')`

**Example: Forum replies point to their parent post (same table)**

Setup:

```sql
CREATE TABLE posts (id LONG PRIMARY KEY AUTO, parent_id LONG REFERENCES posts(id), author STRING NOT NULL, body STRING NOT NULL);
```

```sql
INSERT INTO posts (parent_id, author, body) VALUES (NULL, 'ram', 'Is CITY a good buy?');
INSERT INTO posts (parent_id, author, body) VALUES (1, 'sita', 'Yes, the dividend looks good.');
SELECT id, parent_id, author, body FROM posts;
```

Result:

`INSERT INTO posts (parent_id, author, body) VALUES (NULL, 'ram', 'Is CITY a good buy?')`

```text
1 row(s) inserted
```

`INSERT INTO posts (parent_id, author, body) VALUES (1, 'sita', 'Yes, the dividend looks good.')`

```text
1 row(s) inserted
```

`SELECT id, parent_id, author, body FROM posts`

| id (LONG) | parent_id (LONG) | author (STRING) | body (STRING) |
|---|---|---|---|
| 1 | NULL | ram | Is CITY a good buy? |
| 2 | 1 | sita | Yes, the dividend looks good. |

(2 rows)

**Example: The parent column must be a key** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
```

```sql
CREATE TABLE trades (id LONG PRIMARY KEY AUTO, buyer_name STRING REFERENCES brokers(name));
```

Result:

Error: `column 'buyer_name' of table 'trades' REFERENCES brokers(name), which is neither PRIMARY KEY nor UNIQUE; expected a key column so each value points at exactly one row`

<a id="check"></a>

## CHECK

Syntax:

```sql
column TYPE [CONSTRAINT name] CHECK (condition)            -- after a column
[CONSTRAINT name] CHECK (condition)                        -- after the columns, for the table
ALTER TABLE table ADD [CONSTRAINT name] CHECK (condition)
ALTER TABLE table DROP CONSTRAINT name
```

A condition that every row must meet. A row where the condition is **false** is not written, and the statement fails. Use it for business rules: a balance is never negative, an amount is positive, a quarter is 1 to 4.

| Part | Rule |
|---|---|
| `condition` | uses the stored columns of the **same row**, operators, `CASE`, `IN`, `BETWEEN`, `LIKE` and built-in functions (`length(email) > 3`) |
| not allowed | other rows, subqueries, aggregates (`sum`), window functions, saved functions, computed columns |
| `CONSTRAINT name` | the name of the rule; without it KarelaDB makes `table_column_check` (after a column) or `table_check` (for the table) |
| `NULL` | a condition that is `NULL` **passes**: add `NOT NULL` when the value must be there |
| NaN | every comparison with a NaN (`=`, `<`, `>=`, `BETWEEN`, `IN`) is **false** here, and `<>` is true: `CHECK (price > 0)` refuses a NaN price, `CHECK (price <> 0)` does not. Write what a good value is, not what a bad one is. (A query compares a NaN as PostgreSQL does, bigger than every number: see [DOUBLE](column-types.md#double).) |

- **Returns:** `CHECK constraint 'name' of table 't' failed: condition is false for the row id='1', balance='-4000.00'`. The message names the rule, the table, the row key and the columns the rule uses.
- **Notes:** table rules come **after** all columns. A column used by a `CHECK` cannot be dropped; `RENAME COLUMN` renames it inside the rule. `SHOW CREATE TABLE` shows every rule with its name. [ADD and DROP CONSTRAINT](alter-table.md#add-check) change the rules later. A rule cannot compare with other rows (like "the sum of all balances is 0"); check that with a query or in a [procedure](procedures.md).

**Example: A withdrawal bigger than the balance is refused** (shows an error)

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY AUTO, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL DEFAULT 0 CHECK (balance >= 0));
INSERT INTO accounts (owner, balance) VALUES ('Ram', 1000.00);
```

```sql
UPDATE accounts SET balance = balance - 5000 WHERE id = 1;
```

Result:

Error: `CHECK constraint 'accounts_balance_check' of table 'accounts' failed: balance >= 0 is false for the row id='1', balance='-4000.00'`

**Example: Named rules for a ledger** (shows an error)

Setup:

```sql
CREATE TABLE ledger (
  id           LONG PRIMARY KEY AUTO,
  from_account INT NOT NULL,
  to_account   INT NOT NULL,
  amount       DECIMAL(2) NOT NULL,
  CONSTRAINT positive_amount CHECK (amount > 0),
  CONSTRAINT two_accounts CHECK (from_account != to_account)
);
```

```sql
INSERT INTO ledger (from_account, to_account, amount) VALUES (1, 2, 250.50);
INSERT INTO ledger (from_account, to_account, amount) VALUES (1, 1, 100.00);
```

Result:

```text
1 row(s) inserted
```

Error: `CHECK constraint 'two_accounts' of table 'ledger' failed: from_account != to_account is false for the row id='2', from_account='1', to_account='1'`

**Example: Quarter 1 to 4, and a CHECK lets NULL pass**

Setup:

```sql
CREATE TABLE fundamentals (
  symbol STRING NOT NULL,
  quarter INT CHECK (quarter BETWEEN 1 AND 4),
  eps DECIMAL(2)
);
```

```sql
INSERT INTO fundamentals VALUES ('CITY', 4, 12.10), ('COAST', NULL, 6.35);
SELECT symbol, quarter, eps FROM fundamentals;
SHOW CREATE TABLE fundamentals;
```

Result:

`INSERT INTO fundamentals VALUES ('CITY', 4, 12.10), ('COAST', NULL, 6.35)`

```text
2 row(s) inserted
```

`SELECT symbol, quarter, eps FROM fundamentals`

| symbol (STRING) | quarter (INT) | eps (DECIMAL(2)) |
|---|---|---|
| CITY | 4 | 12.10 |
| COAST | NULL | 6.35 |

(2 rows)

`SHOW CREATE TABLE fundamentals`

| create_sql (STRING) |
|---|
| CREATE TABLE fundamentals (   symbol STRING NOT NULL,   quarter INT,   eps DECIMAL(2),   CONSTRAINT fundamentals_quarter_check CHECK (quarter BETWEEN 1 AND 4) ) |

(1 row)

**Example: A price rule: which values pass price > 0**

Setup:

```sql
CREATE TABLE prices (symbol SYMBOL NOT NULL, price DOUBLE NOT NULL CHECK (price > 0));
```

```sql
INSERT INTO prices VALUES ('CITY', 527.1);
SELECT symbol, price FROM prices;
SELECT 527.1 > 0 AS good_price, 0 > 0 AS zero, -1 > 0 AS negative;
```

Result:

`INSERT INTO prices VALUES ('CITY', 527.1)`

```text
1 row(s) inserted
```

`SELECT symbol, price FROM prices`

| symbol (SYMBOL) | price (DOUBLE) |
|---|---|
| CITY | 527.1 |

(1 row)

`SELECT 527.1 > 0 AS good_price, 0 > 0 AS zero, -1 > 0 AS negative`

| good_price (BOOL) | zero (BOOL) | negative (BOOL) |
|---|---|---|
| true | false | false |

(1 row)

**Example: A NaN price is refused** (shows an error)

Setup:

```sql
CREATE TABLE prices (symbol SYMBOL NOT NULL, price DOUBLE NOT NULL CHECK (price > 0));
```

```sql
INSERT INTO prices VALUES ('CITY', 'NaN');
```

Result:

Error: `CHECK constraint 'prices_price_check' of table 'prices' failed: price > 0 is false for the row price='NaN'`

**Example: A zero price is refused (and -1 the same way)** (shows an error)

Setup:

```sql
CREATE TABLE prices (symbol SYMBOL NOT NULL, price DOUBLE NOT NULL CHECK (price > 0));
```

```sql
INSERT INTO prices VALUES ('CITY', 0);
```

Result:

Error: `CHECK constraint 'prices_price_check' of table 'prices' failed: price > 0 is false for the row price='0'`

**Example: A missing price is refused by NOT NULL** (shows an error)

Setup:

```sql
CREATE TABLE prices (symbol SYMBOL NOT NULL, price DOUBLE NOT NULL CHECK (price > 0));
```

```sql
INSERT INTO prices VALUES ('CITY', NULL);
```

Result:

Error: `column 'price' (DOUBLE): cannot be NULL`

**Example: A CHECK cannot look at other rows** (shows an error)

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, balance DECIMAL(2) CHECK (balance <= (SELECT max(balance) FROM accounts)));
```

Result:

Error: `line 1, column 81: CHECK cannot use a subquery; expected a condition on the values of one row`
