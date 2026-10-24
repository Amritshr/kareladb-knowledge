# Table rights - GRANT ON TABLE

> Give a user rights on one table (GRANT SELECT ON TABLE prices), on some of its columns (GRANT SELECT (id, name) ON staff) or on some of its rows (CREATE POLICY), or take some rights of the role away (REVOKE UPDATE, DELETE ON TABLE ledger).

- Category: Users & security
- Keywords: table rights, table privileges, per-table grant, column rights, column privileges, GRANT SELECT (, column\_privileges, has\_column\_privilege, hide a column, permissions, GRANT SELECT, GRANT INSERT, REVOKE DELETE, REVOKE UPDATE, PRIVILEGES, DEFAULT, append-only table, ledger rights, read one table, row rights, row-level security, RLS, CREATE POLICY, DROP POLICY, ENABLE ROW LEVEL SECURITY, pg\_policies, row\_security, multi-tenant, own rows only
- See also: [Users and roles](users-and-roles.md), [Audit log](audit-log.md), [Protection - timeouts, limits, safe updates, read-only](protection.md), [Keeping kareladb serve safe](server-security.md)

A user's [role](users-and-roles.md#roles) gives rights on a whole database. Table rights change that for one table of the current database:

```text
allowed = (the role allows it AND it was not revoked on the table) OR it was granted on the table
```

| Right | Needed for |
|---|---|
| `SELECT` | reading the table in `SELECT`, subqueries, `JOIN`, `EXPLAIN`, cursors, and `RETURNING` |
| `INSERT` | `INSERT`, and the line protocol (`POST /write`) |
| `UPDATE` | `UPDATE` |
| `DELETE` | `DELETE` |

They are checked once per statement, before it runs (and before the result cache), never per row.

<a id="grant-on-table"></a>

## GRANT ... ON TABLE

Syntax:

```sql
GRANT SELECT | INSERT | UPDATE | DELETE | ALL [PRIVILEGES] [, ...] ON TABLE <table> TO <user>
GRANT DEFAULT ON TABLE <table> TO <user>
```

Adds rights on one table of the current database (`USE`). `DEFAULT` removes every table right of the user on that table: the role decides again.

- **Returns:** `granted SELECT on table 'prices' of database 'shop' to user 'viewer'`.
- **Notes:** needs a server admin. Works for views too (a view gives what it shows).

**Example: A user who may only read one table** (sample data: sample)

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER viewer WITH PASSWORD 'Viewer-password-42';
GRANT SELECT ON TABLE securities TO viewer;
SHOW USERS;
```

Result:

`CREATE USER admin WITH PASSWORD '***' ROLE admin`

```text
user 'admin' created with role admin
```

`CREATE USER viewer WITH PASSWORD '***'`

```text
user 'viewer' created with role none
```

`GRANT SELECT ON TABLE securities TO viewer`

```text
granted SELECT on table 'securities' of database 'demo' to user 'viewer'
```

`SHOW USERS`

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-24T06:40:30.648Z | 2026-10-24T06:40:30.648Z | NULL | false | NULL | NULL |
| viewer | none | NULL | 2026-10-24T06:40:30.707Z | 2026-10-24T06:40:30.753Z | demo.securities: +SELECT | false | NULL | NULL |

(2 rows)

<a id="revoke-on-table"></a>

## REVOKE ... ON TABLE

Syntax:

```sql
REVOKE SELECT | INSERT | UPDATE | DELETE | ALL [, ...] ON TABLE <table> FROM <user>
```

Takes rights away on one table, even when the role allows them. For an accounting ledger that must only grow: the app's user has role `write`, and `REVOKE UPDATE, DELETE ON TABLE ledger FROM app`.

- **Returns:** `revoked UPDATE, DELETE on table 'ledger' of database 'shop' from user 'app'`. A refused statement gets `DELETE on table 'ledger' was revoked for user 'app'` (HTTP 403, SQLSTATE `42501`).
- **Notes:**
  - `DROP TABLE` removes the table rights of that table; `RENAME TABLE` keeps them under the new name. A new table with an old name does not get old rights.
  - Views, procedures (`CALL`) and triggers run without the rights of whoever uses them, like PostgreSQL's `SECURITY DEFINER`. So when a `ddl` user saves one, KarelaDB checks what it reads and changes against that user's rights: a view of a revoked table, or a procedure that deletes from it, is refused. The same holds for `CREATE TABLE ... AS SELECT`.
  - A statement that reads a second table needs `SELECT` on it too: `INSERT ... SELECT`, `UPDATE ... FROM`, `DELETE ... USING` and `WITH`.
  - Older KarelaDB programs refuse a data folder with table rights (they would ignore them).

**Example: The ledger only grows** (sample data: query-app)

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER app WITH PASSWORD 'App-password-12345';
GRANT write ON DATABASE demo TO app;
REVOKE UPDATE, DELETE ON TABLE ledger FROM app;
SHOW USERS;
```

Result:

`CREATE USER admin WITH PASSWORD '***' ROLE admin`

```text
user 'admin' created with role admin
```

`CREATE USER app WITH PASSWORD '***'`

```text
user 'app' created with role none
```

`GRANT write ON DATABASE demo TO app`

```text
user 'app' has role write on database 'demo'
```

`REVOKE UPDATE, DELETE ON TABLE ledger FROM app`

```text
revoked UPDATE, DELETE on table 'ledger' of database 'demo' from user 'app'
```

`SHOW USERS`

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-24T06:40:30.663Z | 2026-10-24T06:40:30.663Z | NULL | false | NULL | NULL |
| app | none | demo=write | 2026-10-24T06:40:30.725Z | 2026-10-24T06:40:30.770Z | demo.ledger: -UPDATE -DELETE | false | NULL | NULL |

(2 rows)

**Example: A revoked table can not be wrapped in a view** (sample data: query-app; shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER migrate WITH PASSWORD 'Migrations-only-secret-9' ROLE ddl;
REVOKE SELECT ON TABLE ledger FROM migrate;
```

```sql
SET ROLE migrate;
CREATE VIEW all_ledger AS SELECT * FROM ledger;
```

Result:

```text
statements now use the rights of user 'migrate' (RESET ROLE goes back)
```

Error: `SELECT on table 'ledger' was revoked for user 'migrate' (REVOKE SELECT ON TABLE ledger)`

<a id="column-rights"></a>

## Column rights

Syntax:

```sql
GRANT SELECT | INSERT | UPDATE | ALL (<column> [, ...]) [, ...] ON [TABLE] <table> TO <user>
REVOKE SELECT | INSERT | UPDATE | ALL (<column> [, ...]) [, ...] ON [TABLE] <table> FROM <user>
```

A right can name columns. Then it is about those columns only. Each right has its own list: `GRANT SELECT (id, name), UPDATE (name) ON staff TO clerk`.

```text
column allowed = not revoked on the column AND (the table allows it OR it was granted on the column)
```

| You want | Write |
|---|---|
| A user who reads only some columns | `GRANT SELECT (id, name) ON staff TO temp` (no role on the database) |
| Hide one column from a role | `REVOKE SELECT (salary) ON staff FROM clerk` |
| Let a user change only one column | `REVOKE UPDATE ON staff FROM clerk; GRANT UPDATE (name) ON staff TO clerk` |
| Back to the role | `GRANT DEFAULT ON TABLE staff TO clerk` (removes the table's column rights too) |

Every column a statement names is checked: the `SELECT` list, `WHERE`, `JOIN ... ON`, `GROUP BY`, `HAVING`, `ORDER BY`, subqueries, `WITH`, `RETURNING`, the columns an `INSERT` fills and the columns an `UPDATE` sets. A refused statement gets `permission denied for column "salary" of table "staff"` (HTTP 403, SQLSTATE `42501`).

- **Returns:** `revoked SELECT on column 'salary' of table 'staff' of database 'hr' from user 'clerk'`.
- **Notes:**
  - `SELECT *` (and `RETURNING *`) reads every column, so it is refused when one of them is not allowed, as in PostgreSQL. Name the columns instead. `count(*)` reads no column and is fine.
  - An `INSERT` without a column list fills every column: it needs `INSERT` on all of them.
  - `DELETE` takes whole rows, so it cannot name columns.
  - A user whose role on the database is `admin` is never held back by column rights.
  - The rights are checked each time a statement runs, also for a prepared statement or a plan kept in the cache.
  - `RENAME COLUMN` keeps the rights under the new name; `DROP COLUMN` removes them.
  - A table of another database (`otherdb.t`) with a column you may not read is refused as a whole; `USE` that database to read the other columns.
  - `has_column_privilege()` and `information_schema.column_privileges` show the same rights.
  - The rights are kept in `_system`. Older KarelaDB programs refuse a data folder once a column right was granted there (they would ignore it).

**Example: An auditor who reads some columns of the ledger** (sample data: query-app)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER auditor WITH PASSWORD 'Auditor-password-77';
GRANT SELECT (line_id, entry_date, account) ON ledger TO auditor;
```

```sql
SET ROLE auditor;
SELECT line_id, account FROM ledger ORDER BY line_id LIMIT 3;
```

Result:

`SET role = 'auditor'`

```text
statements now use the rights of user 'auditor' (RESET ROLE goes back)
```

`SELECT line_id, account FROM ledger ORDER BY line_id LIMIT 3`

| line_id (INT) | account (INT) |
|---|---|
| 1 | 1100 |
| 2 | 3000 |
| 3 | 1200 |

(3 rows)

**Example: SELECT * needs every column** (sample data: query-app; shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER auditor WITH PASSWORD 'Auditor-password-77';
GRANT SELECT (line_id, entry_date, account) ON ledger TO auditor;
```

```sql
SET ROLE auditor;
SELECT * FROM ledger;
```

Result:

```text
statements now use the rights of user 'auditor' (RESET ROLE goes back)
```

Error: `permission denied for column "entry_id" of table "ledger": SELECT * (or RETURNING *) reads every column, and user 'auditor' may not SELECT this one; name the columns instead`

**Example: What the current user may do with each column** (sample data: query-app)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER app WITH PASSWORD 'App-password-12345';
GRANT write ON DATABASE demo TO app;
REVOKE SELECT (credit) ON ledger FROM app;
```

```sql
SET ROLE app;
SELECT column_name, privilege_type FROM information_schema.column_privileges
WHERE table_name = 'ledger' AND column_name IN ('debit', 'credit') ORDER BY 1, 2;
```

Result:

`SET role = 'app'`

```text
statements now use the rights of user 'app' (RESET ROLE goes back)
```

`SELECT column_name, privilege_type FROM "information_schema.column_privileges" WHERE table_name = 'l`

| column_name (STRING) | privilege_type (STRING) |
|---|---|
| credit | INSERT |
| credit | UPDATE |
| debit | INSERT |
| debit | SELECT |
| debit | UPDATE |

(5 rows)

<a id="row-rights"></a>

## Row rights (row-level security)

Syntax:

```sql
CREATE POLICY <name> ON <table> [AS PERMISSIVE] [FOR ALL | SELECT | INSERT | UPDATE | DELETE]
    [TO <user> | PUBLIC [, ...]] [USING (<condition>)] [WITH CHECK (<condition>)]
DROP POLICY [IF EXISTS] <name> ON <table>
ALTER TABLE <table> ENABLE | DISABLE ROW LEVEL SECURITY
```

A policy decides which rows of a table a user sees and may change. It acts once the table's row-level security is on (`ENABLE ROW LEVEL SECURITY`). Then, for every user who is not an admin of the database:

| Statement | What the policies do |
|---|---|
| `SELECT` (also joins, subqueries, `WITH`, views, `EXPLAIN`, `CREATE TABLE ... AS`) | only rows where a `USING` condition is true are read |
| `UPDATE`, `DELETE` | only those rows are changed; others are left alone, without an error |
| `INSERT`, and the new version of an updated row | must pass a `WITH CHECK` condition (or the `USING` of a policy without one), else `new row violates row-level security policy for table "t"` (HTTP 403, SQLSTATE `42501`) |

The policies of a table are joined with `OR`: one that lets a row in is enough. A table with row-level security on and no policy for the user shows them no rows at all.

- **Returns:** `policy 'own' created on table 'orders'`; `row-level security of table 'orders' is on`.
- **Notes:**
  - Needs role `admin` on the database. An admin is never held back by the policies (`FORCE ROW LEVEL SECURITY` is accepted and changes nothing).
  - `current_user` in a condition is the user running the statement, so one policy serves every user.
  - A view shows each reader the rows their own policies allow (like PostgreSQL's `security_invoker` views).
  - `SET row_security = off`: a statement a policy would change fails instead (`query would be affected by row-level security policy`), as in PostgreSQL. Use it to be sure a dump gets every row.
  - Bulk paths that do not run SQL refuse such a table for these users: `/cursor`, `POST /write`, `/imp` and `COPY FROM`. A `DO` block is refused too. Use `SELECT` and `INSERT`.
  - A `WITH CHECK` condition looks at the one row only (no subqueries).
  - Results of these users never come from the result cache, so a cached answer is never shared between users.
  - `RENAME TABLE` keeps the policies; `DROP TABLE` removes them. `pg_policies`, `pg_policy` and `pg_tables.rowsecurity` show them.
  - Only `PERMISSIVE` policies (`AS RESTRICTIVE` is refused). Statements inside procedures and triggers are not filtered; their `WITH CHECK` still applies.
  - The policies are kept in `_system`. Older KarelaDB programs refuse a data folder once a policy was made there (they would ignore it).

**Example: Each user sees only their own rows** (sample data: query-app)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER ann WITH PASSWORD 'Ann-password-12345';
GRANT write ON DATABASE demo TO ann;
CREATE TABLE orders (id INT PRIMARY KEY, owner STRING, amount DOUBLE);
INSERT INTO orders VALUES (1, 'ann', 10), (2, 'bo', 20), (3, 'ann', 30);
CREATE POLICY own ON orders TO ann USING (owner = current_user);
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
```

```sql
SET ROLE ann;
SELECT * FROM orders ORDER BY id;
```

Result:

`SET role = 'ann'`

```text
statements now use the rights of user 'ann' (RESET ROLE goes back)
```

`SELECT * FROM (SELECT * FROM orders WHERE owner = current_user) AS orders ORDER BY id`

| id (INT) | owner (STRING) | amount (DOUBLE) |
|---|---|---|
| 1 | ann | 10 |
| 3 | ann | 30 |

(2 rows)

**Example: A row for someone else is refused** (sample data: query-app; shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER ann WITH PASSWORD 'Ann-password-12345';
GRANT write ON DATABASE demo TO ann;
CREATE TABLE orders (id INT PRIMARY KEY, owner STRING, amount DOUBLE);
CREATE POLICY own ON orders TO ann USING (owner = current_user);
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
```

```sql
SET ROLE ann;
INSERT INTO orders VALUES (4, 'bo', 5);
```

Result:

```text
statements now use the rights of user 'ann' (RESET ROLE goes back)
```

Error: `new row violates row-level security policy for table "orders"`

**Example: The policies of a database** (sample data: query-app)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER ann WITH PASSWORD 'Ann-password-12345';
CREATE TABLE orders (id INT PRIMARY KEY, owner STRING, amount DOUBLE);
CREATE POLICY own ON orders TO ann USING (owner = current_user);
CREATE POLICY big ON orders FOR SELECT TO PUBLIC USING (amount > 100);
```

```sql
SELECT policyname, cmd, roles, qual FROM pg_policies ORDER BY policyname;
```

Result:

| policyname (STRING) | cmd (STRING) | roles (STRING) | qual (STRING) |
|---|---|---|---|
| big | SELECT | {public} | amount > 100 |
| own | ALL | {ann} | owner = current_user |

(2 rows)

<a id="revoke-role"></a>

## REVOKE role ON DATABASE

Syntax:

```sql
REVOKE read | write | admin ON DATABASE <db> FROM <user>
REVOKE ALL ON DATABASE <db> FROM <user>
```

`REVOKE <role>` takes away exactly a grant of that role. A stronger grant stays: `REVOKE read` does not remove a `write` grant (the message says so). `REVOKE ALL` removes any grant on the database.

- **Returns:** `user 'u' has no grant on database 'shop' now`, or `user 'u' keeps role write on database 'shop': REVOKE read takes away only a read grant; use REVOKE write or REVOKE ALL. Nothing was revoked`.
