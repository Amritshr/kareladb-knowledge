# SQL command groups: DDL, DML, DCL, TCL, DQL

> The five groups of SQL statements, every KarelaDB statement in its group, and the role each group needs.

- Category: Getting started
- Keywords: DDL, DML, DCL, TCL, DQL, data definition language, data manipulation language, data control language, transaction control language, data query language, command groups, statement types, kinds of statements, sublanguage, which role do I need, TRUNCATE, SAVEPOINT
- See also: [SQL basics](sql-basics.md), [CREATE TABLE](create-table.md), [ALTER, RENAME and DROP TABLE](alter-table.md), [Views](views.md), [Indexes](indexes.md), [INSERT](insert.md), [UPDATE and DELETE](update-delete.md), [Users and roles](users-and-roles.md), [Transactions](transactions.md), [SELECT](select.md), [SHOW TABLES, COLUMNS, CREATE TABLE](show-tables.md)

SQL statements are sorted into five **groups** by what they do. The group tells you three things at once: what the statement changes, which [role](users-and-roles.md#roles) a user needs for it, and whether it can go inside [BEGIN ... COMMIT](transactions.md).

| Group | Name | What it does | Main statements | Role needed |
|---|---|---|---|---|
| **DDL** | Data Definition Language | makes, changes and removes **objects**: tables, views, indexes, functions, procedures, triggers | `CREATE`, `ALTER`, `DROP`, `RENAME` | `admin` |
| **DML** | Data Manipulation Language | changes the **rows** inside tables | `INSERT`, `UPDATE`, `DELETE`, `CALL` | `write` |
| **DCL** | Data Control Language | says **who** may do what | `CREATE USER`, `GRANT`, `REVOKE` | `admin` as the user's own `ROLE` |
| **TCL** | Transaction Control Language | groups changes so they are saved **together or not at all** | `BEGIN`, `COMMIT`, `ROLLBACK` | `read` |
| **DQL** | Data Query Language | **reads** rows and never changes anything | `SELECT`, `EXPLAIN`, `SHOW` | `read` |

- Roles are checked only by `kareladb serve` (HTTP, web console and the PostgreSQL port). `kareladb sql` and `kareladb shell` open the files directly and may run everything.
- Some books put `SELECT` into DML. KarelaDB's help keeps it apart as DQL, because a read needs only the `read` role.
- The web console lists what DDL made: open the **Objects** list on the left (see [web console](web-console.md#tables)).

<a id="ddl"></a>

## DDL: Data Definition Language

DDL statements build the **shape** of a database. They change objects, not rows (except `DROP`, which removes the rows with the table).

| Object | Make | Change | Remove | Help |
|---|---|---|---|---|
| table | `CREATE TABLE` | `ALTER TABLE`, `RENAME TABLE` | `DROP TABLE`, then `UNDROP TABLE` to bring it back | [create-table](create-table.md), [alter-table](alter-table.md), [trash](trash.md) |
| view | `CREATE VIEW`, `CREATE CACHED VIEW` | drop and create again | `DROP VIEW` | [views](views.md) |
| materialized view | `CREATE MATERIALIZED VIEW` | `ALTER TABLE ... SET TTL`; otherwise drop and create again | `DROP MATERIALIZED VIEW` | [views](views.md#materialized-view) |
| index | `CREATE INDEX`, `CREATE UNIQUE INDEX`, `CREATE FULLTEXT INDEX` | - | `DROP INDEX` | [indexes](indexes.md) |
| saved function | `CREATE FUNCTION` | `CREATE OR REPLACE FUNCTION` | `DROP FUNCTION` | [saved-functions](saved-functions.md) |
| stored procedure | `CREATE PROCEDURE` | `CREATE OR REPLACE PROCEDURE` | `DROP PROCEDURE` | [procedures](procedures.md) |
| trigger | `CREATE TRIGGER` | `ALTER TRIGGER ... ENABLE / DISABLE` | `DROP TRIGGER` | [triggers](triggers.md) |
| sequence | `CREATE SEQUENCE` | `ALTER SEQUENCE` | `DROP SEQUENCE` | [functions-postgres](functions-postgres.md) |
| ENUM type | `CREATE TYPE ... AS ENUM` | `ALTER TYPE ... ADD VALUE` | `DROP TYPE` | [column-types](column-types.md#enum) |
| trading calendar | `CREATE CALENDAR` | `ALTER CALENDAR ... ADD HOLIDAY` / `ADD ERA` / ... | `DROP CALENDAR` | [calendars](calendars.md) |
| database | `CREATE DATABASE` | `ALTER DATABASE` | `DROP DATABASE` | [databases](databases.md) |

- **Role:** `admin`. Databases need `admin` as the user's own `ROLE`.
- **Notes:**
  - Each DDL statement is saved on its own, at once. Most of them can not go inside `BEGIN` ... `COMMIT` (see [what is not allowed inside a transaction](transactions.md#not-inside)).
  - Look at what DDL made with `SHOW TABLES`, `SHOW COLUMNS FROM t`, `SHOW CREATE TABLE t`, `SHOW VIEWS`, `SHOW INDEXES`, `SHOW FUNCTIONS`, `SHOW PROCEDURES` and `SHOW TRIGGERS` (see [show-tables](show-tables.md)).
  - `TRUNCATE TABLE t` empties a table and keeps it (see [UPDATE and DELETE](update-delete.md#truncate)). PostgreSQL counts it as DDL.

**Example: DDL: a table, a column added later, a view and an index** (sample data: sample)

```sql
CREATE TABLE watchlist (symbol STRING PRIMARY KEY, note STRING);
ALTER TABLE watchlist ADD COLUMN target DOUBLE;
CREATE VIEW watchlist_names AS
SELECT w.symbol, s.name, w.target FROM watchlist w JOIN securities s ON s.symbol = w.symbol;
CREATE INDEX watchlist_note ON watchlist (note);
SHOW COLUMNS FROM watchlist;
SHOW VIEWS;
```

Result:

`CREATE TABLE watchlist (`

```text
table 'watchlist' created
```

`ALTER TABLE watchlist ADD COLUMN target DOUBLE`

```text
table 'watchlist' altered
```

`CREATE VIEW watchlist_names AS SELECT w.symbol, s.name, w.target FROM watchlist AS w JOIN securities`

```text
view 'watchlist_names' created
```

`CREATE INDEX watchlist_note ON watchlist (note)`

```text
index 'watchlist_note' created on table 'watchlist' (0 rows)
```

`SHOW COLUMNS FROM watchlist`

| name (STRING) | type (STRING) | primary_key (BOOL) | not_null (BOOL) | computed (BOOL) | references (STRING) |
|---|---|---|---|---|---|
| symbol | STRING | true | false | false | NULL |
| note | STRING | false | false | false | NULL |
| target | DOUBLE | false | false | false | NULL |

(3 rows)

`SHOW VIEWS`

| name (STRING) | query (STRING) | kind (STRING) | refresh (STRING) |
|---|---|---|---|
| watchlist_names | SELECT w.symbol, s.name, w.target FROM watchlist AS w JOIN securities AS s ON s.symbol = w.symbol | complex | NULL |

(1 row)

<a id="dml"></a>

## DML: Data Manipulation Language

DML statements change the **rows** of tables. The table itself stays as it is.

| Statement | What it does | Help |
|---|---|---|
| `INSERT INTO ... VALUES` | adds rows | [insert](insert.md) |
| `INSERT OR REPLACE`, `INSERT OR IGNORE`, `ON CONFLICT` | adds rows, or replaces / keeps the row with the same key | [insert](insert.md#insert-or-replace) |
| `INSERT INTO ... SELECT` | adds the rows a query gives | [insert](insert.md#insert-select) |
| `UPDATE ... SET ... WHERE` | changes rows | [update-delete](update-delete.md#update) |
| `DELETE FROM ... WHERE` | removes rows | [update-delete](update-delete.md#delete) |
| `... RETURNING` | shows the rows that were added, changed or removed | [update-delete](update-delete.md#returning) |
| `CALL name(...)` | runs a stored procedure, which changes rows | [procedures](procedures.md) |

- **Role:** `write`.
- **Notes:**
  - Each statement is all or nothing: an `INSERT` of 5000 rows with one bad row saves no row.
  - To make **many** DML statements succeed or fail together, put them inside `BEGIN` ... `COMMIT` (TCL).
  - Triggers run by themselves after (or before) DML on their table.
  - A view has no rows of its own: DML on a view is refused. Change the table the view reads.

**Example: DML: add, change and remove rows** (sample data: sample)

Setup:

```sql
CREATE TABLE watchlist (symbol STRING PRIMARY KEY, note STRING, target DOUBLE);
```

```sql
INSERT INTO watchlist VALUES ('CITY', 'bank', 520), ('VOLT', 'hydro', 250);
UPDATE watchlist SET target = 540 WHERE symbol = 'CITY';
DELETE FROM watchlist WHERE symbol = 'VOLT' RETURNING symbol, note;
SELECT * FROM watchlist;
```

Result:

`INSERT INTO watchlist VALUES ('CITY', 'bank', 520), ('VOLT', 'hydro', 250)`

```text
2 row(s) inserted
```

`UPDATE watchlist SET target = 540 WHERE symbol = 'CITY'`

```text
1 row(s) updated
```

`DELETE FROM watchlist WHERE symbol = 'VOLT' RETURNING symbol, note`

| symbol (STRING) | note (STRING) |
|---|---|
| VOLT | hydro |

(1 row)

```text
1 row(s) deleted
```

`SELECT * FROM watchlist`

| symbol (STRING) | note (STRING) | target (DOUBLE) |
|---|---|---|
| CITY | bank | 540 |

(1 row)

<a id="dcl"></a>

## DCL: Data Control Language

DCL statements decide **who** may connect and what each user may do.

| Statement | What it does | Help |
|---|---|---|
| `CREATE USER name PASSWORD '...' ROLE ...` | adds a user with a role for every database | [users-and-roles](users-and-roles.md#create-user) |
| `ALTER USER` | changes a password or a role | [users-and-roles](users-and-roles.md#alter-user) |
| `DROP USER` | removes a user | [users-and-roles](users-and-roles.md#drop-user) |
| `GRANT role ON DATABASE db TO name` | gives a role on one database | [users-and-roles](users-and-roles.md#grant) |
| `GRANT ... ON TABLE` | gives rights on one table | [table-rights](table-rights.md) |
| `REVOKE ... FROM name` | takes a grant away | [users-and-roles](users-and-roles.md#revoke) |
| `SHOW USERS` | lists users, roles and grants | [users-and-roles](users-and-roles.md#show-users) |

The roles, from least to most: `none` < `read` < `write` < `admin`. Each role may do everything of the roles before it.

- **Role:** `admin` as the user's **own** `ROLE` (a `GRANT` of admin on one database is not enough), because users belong to the whole server. Changing your own password needs no role.
- **Notes:**
  - The **first** user must have `ROLE admin`. From then on, `kareladb serve` asks everyone to log in.
  - Users are kept in the `_system` database, not in the database you are using.
  - Give each program only what it needs: an app's backend `write` on its own database, a report script `read`.

**Example: DCL: an admin, a read-only report user, and an app that may write one database** (sample data: sample)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
```

```sql
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
CREATE USER shop_app WITH PASSWORD 'Another-long-secret-42' ROLE none;
GRANT write ON DATABASE demo TO shop_app;
SHOW USERS;
```

Result:

`CREATE USER report WITH PASSWORD '***' ROLE read`

```text
user 'report' created with role read
```

`CREATE USER shop_app WITH PASSWORD '***' ROLE none`

```text
user 'shop_app' created with role none
```

`GRANT write ON DATABASE demo TO shop_app`

```text
user 'shop_app' has role write on database 'demo'
```

`SHOW USERS`

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-24T04:51:05.403Z | 2026-10-24T04:51:05.403Z | NULL | false | NULL | NULL |
| report | read | NULL | 2026-10-24T04:51:05.653Z | 2026-10-24T04:51:05.653Z | NULL | false | NULL | NULL |
| shop_app | none | demo=write | 2026-10-24T04:51:05.706Z | 2026-10-24T04:51:05.708Z | NULL | false | NULL | NULL |

(3 rows)

<a id="tcl"></a>

## TCL: Transaction Control Language

TCL statements group DML into one **transaction**: KarelaDB saves all of its changes together, or none of them.

| Statement | What it does | Help |
|---|---|---|
| `BEGIN` (also `BEGIN TRANSACTION`, `BEGIN WORK`) | starts a transaction | [transactions](transactions.md#begin) |
| `COMMIT` | saves every change since `BEGIN`, in one write | [transactions](transactions.md#commit) |
| `ROLLBACK` | throws away every change since `BEGIN` | [transactions](transactions.md#rollback) |
| `SELECT ... FOR UPDATE` | reads rows that no other session may change before you `COMMIT` | [transactions](transactions.md#for-update) |

- **Role:** `read` to start and end one. The statements inside still need their own role (`write` for DML).
- **Notes:**
  - Without `BEGIN`, every statement is its own small transaction and is saved at once.
  - When a statement inside the transaction fails, KarelaDB undoes the whole transaction.
  - `SAVEPOINT`, `ROLLBACK TO SAVEPOINT` and `RELEASE SAVEPOINT` undo part of a transaction ([savepoints](transactions.md#savepoint)).
  - One writer at a time: while a transaction changes rows, other writers wait (see [one writer at a time](transactions.md#one-writer)).

**Example: TCL: a transfer that is saved, and a mistake that is undone** (sample data: sample)

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```sql
BEGIN;
UPDATE accounts SET balance = balance - 300 WHERE id = 1;
UPDATE accounts SET balance = balance + 300 WHERE id = 2;
COMMIT;

BEGIN;
DELETE FROM accounts;
ROLLBACK;

SELECT * FROM accounts ORDER BY id;
```

Result:

`BEGIN`

```text
transaction started
```

`UPDATE accounts SET balance = balance - 300 WHERE id = 1`

```text
1 row(s) updated
```

`UPDATE accounts SET balance = balance + 300 WHERE id = 2`

```text
1 row(s) updated
```

`COMMIT`

```text
transaction committed: 2 change(s) saved
```

`BEGIN`

```text
transaction started
```

`DELETE FROM accounts`

```text
2 row(s) deleted
```

`ROLLBACK`

```text
transaction rolled back: 1 change(s) undone
```

`SELECT * FROM accounts ORDER BY id`

| id (INT) | owner (STRING) | balance (DECIMAL(2)) |
|---|---|---|
| 1 | Ram | 700.00 |
| 2 | Sita | 300.00 |

(2 rows)

<a id="dql"></a>

## DQL: Data Query Language

DQL statements **read**. They never change a row or an object, so they are safe to run at any time.

| Statement | What it does | Help |
|---|---|---|
| `SELECT` | reads rows: `WHERE`, `JOIN`, `GROUP BY`, `ORDER BY`, `LIMIT` | [select](select.md) |
| `SELECT ... SAMPLE BY`, `LATEST ON` | time-series candles and the newest row per key | [sample-by](sample-by.md), [latest-on](latest-on.md) |
| `WITH ... SELECT` | a query with named parts | [union-subqueries](union-subqueries.md) |
| `EXPLAIN SELECT ...` | shows how KarelaDB will run a query, without running it | [explain](explain.md) |
| `SHOW TABLES`, `SHOW VIEWS`, `SHOW INDEXES`, ... | lists the objects of a database | [show-tables](show-tables.md) |
| `DECLARE`, `FETCH`, `CLOSE` | reads a big result a part at a time | [cursors](cursors.md) |

- **Role:** `read`.
- **Notes:**
  - Selecting from a view is DQL too: the view's query runs, and nothing is changed.
  - `SELECT ... FOR UPDATE` is the one read that waits for writers; it belongs with TCL.

**Example: DQL: a report, a query plan and a list of objects** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades, sum(quantity) AS shares
FROM trade_log GROUP BY symbol ORDER BY trades DESC, symbol LIMIT 3;
EXPLAIN SELECT * FROM ochl_day WHERE symbol = 'CITY';
SHOW TABLES;
```

Result:

`SELECT symbol, count(*) AS trades, sum(quantity) AS shares FROM trade_log GROUP BY symbol ORDER BY t`

| symbol (SYMBOL) | trades (LONG) | shares (LONG) |
|---|---|---|
| CITY | 11 | 2420 |
| COAST | 11 | 3070 |
| TELCO | 6 | 2770 |

(3 rows)

`EXPLAIN SELECT * FROM ochl_day WHERE symbol = 'CITY'`

| plan (STRING) |
|---|
| scan table ochl_day (2 of 2 partitions, about 57 rows) |
| read only 1 key range(s) of each partition |
| filter while scanning: 1 condition(s) |
| engine: column |

(4 rows)

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

<a id="which-group"></a>

## Which group is my statement?

| Starts with | Group |
|---|---|
| `CREATE`, `ALTER`, `DROP`, `RENAME`, `UNDROP` (tables, views, indexes, functions, procedures, triggers, sequences, databases) | DDL |
| `INSERT`, `UPDATE`, `DELETE`, `CALL` | DML |
| `CREATE USER`, `ALTER USER`, `DROP USER`, `GRANT`, `REVOKE` | DCL |
| `BEGIN`, `COMMIT`, `ROLLBACK` | TCL |
| `SELECT`, `WITH`, `EXPLAIN`, `SHOW`, `DECLARE`, `FETCH`, `CLOSE` | DQL |

Other statements belong to looking after the database, not to one of the five groups: `BACKUP DATABASE`, `CHECK TABLE`, `CHECKPOINT` (see [backup and safety](backup-and-safety.md)) and `USE` (see [databases](databases.md#use)).
