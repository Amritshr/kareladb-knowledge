# Users and roles

> Database users with passwords, and the roles read, write, ddl and admin for every database or for one.

- Category: Users & security
- Keywords: ALTER USER SET timezone, user time zone, user, users, database user, role, roles, rights, permissions, privileges, GRANT, REVOKE, PASSWORD, ROLE, USER, USERS, IF NOT EXISTS, IF EXISTS, WITH, ALL, admin, ddl, write, read, none, DDL right, schema changes, migrations, \_system, last admin, REVOKE ALL ON DATABASE, 403, permission denied, SET ROLE, RESET ROLE, SET ROLE NONE, current\_user, session\_user
- See also: [Keeping kareladb serve safe](server-security.md), [Security functions](functions-security.md), [kareladb user](cli-users.md), [Logins, tokens and roles over HTTP](http-login.md), [Databases and the data folder](databases.md), [PostgreSQL protocol (port 8832)](postgres-protocol.md)

**Database users** are the people and programs that connect to a running `kareladb serve`: you in the web console, your app's backend, a report script. Each user has a password and a **role** (what it may do).

- As soon as the first user exists, `kareladb serve` asks for a login on every request (see [Keeping kareladb serve safe](server-security.md)).
- The users of **your app** (customers who register on your web site) are something else. Keep them in your own table with [password_hash](functions-security.md#password-hash).
- `kareladb sql` and `kareladb shell` open the files directly. They never ask for a login and can run every statement here. Protect the data folder with the file rights of the operating system.

A small shop with three users: you (admin), the shop's backend (write on one database) and a report script (read everywhere).

**Example: Three users for a small shop**

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER shop_app WITH PASSWORD 'Another-long-secret-42';
GRANT write ON DATABASE demo TO shop_app;
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
SHOW USERS;
```

Result:

`CREATE USER admin WITH PASSWORD '***' ROLE admin`

```text
user 'admin' created with role admin
```

`CREATE USER shop_app WITH PASSWORD '***'`

```text
user 'shop_app' created with role none
```

`GRANT write ON DATABASE demo TO shop_app`

```text
user 'shop_app' has role write on database 'demo'
```

`CREATE USER report WITH PASSWORD '***' ROLE read`

```text
user 'report' created with role read
```

`SHOW USERS`

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-22T09:56:41.412Z | 2026-10-22T09:56:41.412Z | NULL | false | NULL | NULL |
| report | read | NULL | 2026-10-22T09:56:41.521Z | 2026-10-22T09:56:41.521Z | NULL | false | NULL | NULL |
| shop_app | none | demo=write | 2026-10-22T09:56:41.467Z | 2026-10-22T09:56:41.468Z | NULL | false | NULL | NULL |

(3 rows)

## CREATE USER

Syntax:

```sql
CREATE USER [IF NOT EXISTS] name [WITH] PASSWORD 'secret' [ROLE admin | ddl | write | read | none]
```

Adds a database user with a password. `PASSWORD` and `ROLE` may come in any order.

| Part | Meaning |
|---|---|
| `IF NOT EXISTS` | no error when the user is already there (nothing is changed then) |
| `name` | letters, digits, `_` and `-`, 1 to 63 characters. `Bob` and `bob` are the same user. |
| `PASSWORD 'secret'` | at least 12 characters, not the user name, at most 1024 bytes. Write `''` for a `'` inside. Required. |
| `ROLE` | the role on **every** database. Default `none` (nothing until a `GRANT`). |

- **Returns:** a message like `user 'report' created with role read`.
- **Notes:**
  - The **first** user must have `ROLE admin`. Once a user exists, the server asks for a login, and only an admin can manage users.
  - Only a user whose own `ROLE` is `admin` may run it (on a server with users).
  - KarelaDB keeps a PBKDF2 hash of the password (600,000 rounds) and a SCRAM-SHA-256 secret for the PostgreSQL port. The password itself is never stored. The statement KarelaDB shows back reads `PASSWORD '***'`.
  - Hashing takes about 0.1 second, so creating many users is not instant.
  - A name with other characters (a dot, a space, Nepali letters) is refused, also inside double quotes. The name is kept as you wrote it (`Sita-K`), but compared without case.
  - Different from PostgreSQL: there is no `CREATE ROLE`, no `LOGIN`/`NOLOGIN` and no `VALID UNTIL`. MySQL writes `'name'@'host' IDENTIFIED BY '...'`; KarelaDB has no host part.

**Example**

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER IF NOT EXISTS admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER report ROLE read PASSWORD 'Reports-only-secret-7';
```

Result:

`CREATE USER admin WITH PASSWORD '***' ROLE admin`

```text
user 'admin' created with role admin
```

`CREATE USER IF NOT EXISTS admin WITH PASSWORD '***' ROLE admin`

```text
user 'admin' already exists
```

`CREATE USER report WITH PASSWORD '***' ROLE read`

```text
user 'report' created with role read
```

**Example: The first user must be an admin** (shows an error)

```sql
CREATE USER shop_app WITH PASSWORD 'Another-long-secret-42';
```

Result:

Error: `the first user must have ROLE admin (CREATE USER name WITH PASSWORD '...' ROLE admin): once a user exists the server asks for a login, and only an admin can manage users`

**Example: Too short a password** (shows an error)

```sql
CREATE USER admin WITH PASSWORD 'nepal' ROLE admin;
```

Result:

Error: `the password is too short: use at least 12 characters (a password manager can make a long random one)`

**Example: The same name in other letters is the same user** (shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
```

```sql
CREATE USER Admin WITH PASSWORD 'Another-long-secret-42' ROLE read;
```

Result:

Error: `user 'admin' already exists`

**Example: A password is required** (shows an error)

```sql
CREATE USER report ROLE read;
```

Result:

Error: `line 1, column 29: CREATE USER needs a password, like CREATE USER report WITH PASSWORD '...' ROLE read`

## ALTER USER

Syntax:

```sql
ALTER USER name [WITH] PASSWORD 'new secret'
ALTER USER name ROLE admin | ddl | write | read | none
ALTER USER name [WITH] PASSWORD 'new secret' ROLE read
```

Changes the password, the role, or both.

| Part | Meaning |
|---|---|
| `name` | an existing user |
| `PASSWORD 'new secret'` | the new password (at least 12 characters, at most 1024 bytes) |
| `ROLE` | the new role on every database. Grants on single databases stay. |

- **Returns:** a message like `user 'report' changed: new password, role read`.
- **Notes:**
  - **Every user may change their own password.** Changing a role, or another user's password, needs `ROLE admin`.
  - A new password ends every login (session) of that user at once: the web console and `POST /api/login` tokens must log in again.
  - The last user with `ROLE admin` can not lose that role while other users exist. Make another user admin first.

**Example: A new password and a new role**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
```

```sql
ALTER USER report WITH PASSWORD 'New-report-secret-8';
ALTER USER report ROLE write;
SHOW USERS;
```

Result:

`ALTER USER report WITH PASSWORD '***'`

```text
user 'report' changed: new password
```

`ALTER USER report ROLE write`

```text
user 'report' changed: role write
```

`SHOW USERS`

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-22T09:56:41.880Z | 2026-10-22T09:56:41.880Z | NULL | false | NULL | NULL |
| report | write | NULL | 2026-10-22T09:56:41.935Z | 2026-10-22T09:56:42.184Z | NULL | false | NULL | NULL |

(2 rows)

**Example: The last admin must stay an admin** (shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
```

```sql
ALTER USER admin ROLE read;
```

Result:

Error: `'admin' is the last user with ROLE admin; make another user admin first (ALTER USER <name> ROLE admin), or nobody could manage users any more`

**Example: Nothing to change** (shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
```

```sql
ALTER USER admin;
```

Result:

Error: `line 1, column 17: ALTER USER needs PASSWORD '...' or ROLE read|write|ddl|admin`

<a id="statement-timeout"></a>

## ALTER USER ... SET statement_timeout

Syntax:

```sql
ALTER USER name SET statement_timeout = '5s' | 5000 | 0 | DEFAULT
ALTER USER name RESET statement_timeout
```

Gives one user their own time limit for a statement. It takes the place of the server's `--statement-timeout` (60 s unless set) for that user only.

| Value | Meaning |
|---|---|
| `'2s'`, `'500ms'`, `'10min'`, `5000` | the time; a plain number is milliseconds |
| `0` | no limit for this user |
| `DEFAULT`, or `RESET` | the server's limit again |

- **Returns:** a message like `statement_timeout of user 'charts' is 2 s (from their next statement)`. `SHOW USERS` shows it in the column `statement_timeout`.
- **Notes:**
  - Needs `ROLE admin`. A user can not change their own limit.
  - It may be longer than the server's limit: a report user may get 10 minutes while every other user keeps 60 s.
  - In a session, the user may still make it **shorter** with `SET statement_timeout`, never longer (an admin user may do both).
  - It counts on the HTTP API and on the PostgreSQL port, from the user's next statement. It is kept in the data folder, so it survives a restart.
  - A per-role limit (all `read` users at once) does not exist; set it on each user.

**Example: Short queries for the chart app, long ones for reports**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER charts WITH PASSWORD 'Chart-app-secret-11' ROLE read;
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
```

```sql
ALTER USER charts SET statement_timeout = '2s';
ALTER USER report SET statement_timeout = '10min';
SHOW USERS;
```

Result:

`ALTER USER charts SET statement_timeout = '2000ms'`

```text
statement_timeout of user 'charts' is 2 s (from their next statement)
```

`ALTER USER report SET statement_timeout = '600000ms'`

```text
statement_timeout of user 'report' is 10 min (from their next statement)
```

`SHOW USERS`

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-22T09:56:42.338Z | 2026-10-22T09:56:42.338Z | NULL | false | NULL | NULL |
| charts | read | NULL | 2026-10-22T09:56:42.393Z | 2026-10-22T09:56:42.623Z | NULL | false | 2 s | NULL |
| report | read | NULL | 2026-10-22T09:56:42.447Z | 2026-10-22T09:56:42.625Z | NULL | false | 10 min | NULL |

(3 rows)

**Example: Back to the server's limit**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
ALTER USER report SET statement_timeout = '10min';
```

```sql
ALTER USER report RESET statement_timeout;
```

Result:

```text
user 'report' has the server's statement_timeout again
```

**Example: Only a time is accepted** (shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
```

```sql
ALTER USER admin SET statement_timeout = 'soon';
```

Result:

Error: `line 1, column 42: statement_timeout needs a time like '30s', '500ms', '2min', 0 (no limit) or DEFAULT, not 'soon'`

<a id="user-timezone"></a>

## ALTER USER ... SET timezone

Syntax:

```sql
ALTER USER name SET timezone = 'Asia/Kathmandu' | 'America/New_York' | '+05:45' | DEFAULT
ALTER USER name SET TIME ZONE 'Asia/Kathmandu'
ALTER USER name RESET timezone
```

The clock one user's sessions start on: `CURRENT_DATE`, `::date`, `date_trunc`, `EXTRACT`, `to_char` and a `DATE` met by a `TIMESTAMP` use it ([time zones](time-and-time-zones.md#session-time-zone)). The user's own `SET TIME ZONE` still changes it for a session. Users without one have the server's zone, which is the computer's own unless `kareladb serve --timezone` names another.

- **Role:** an admin sets it, for any user.
- **Kept:** with the user, across restarts and backups.

**Example: Asha sees days on the Nepal clock, the others on the server's**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER asha WITH PASSWORD 'Asha-Long-Passw0rd' ROLE read;
```

```sql
ALTER USER asha SET timezone = 'Asia/Kathmandu';
```

Result:

```text
time zone of user 'asha' is Asia/Kathmandu (from their next session)
```

## DROP USER

Syntax:

```sql
DROP USER [IF EXISTS] name
```

Removes a user and its grants. Its logins stop working at once.

| Part | Meaning |
|---|---|
| `IF EXISTS` | no error when there is no such user |
| `name` | the user to remove |

- **Returns:** `user 'name' dropped`, or `user 'name' does not exist` with `IF EXISTS`.
- **Notes:**
  - Needs `ROLE admin`.
  - The last user with `ROLE admin` can not be dropped while other users exist.
  - When the **last** user is dropped, the server has no users again and stops asking for a login (on `127.0.0.1`).
  - Tables and data are never touched: KarelaDB has no "owner" of a table.

**Example**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
```

```sql
DROP USER report;
DROP USER IF EXISTS report;
SHOW USERS;
```

Result:

`DROP USER report`

```text
user 'report' dropped
```

`DROP USER IF EXISTS report`

```text
user 'report' does not exist
```

`SHOW USERS`

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-22T09:56:42.936Z | 2026-10-22T09:56:42.936Z | NULL | false | NULL | NULL |

(1 row)

**Example: The last admin can not be dropped while others exist** (shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
```

```sql
DROP USER admin;
```

Result:

Error: `'admin' is the last user with ROLE admin; make another user admin first (ALTER USER <name> ROLE admin), or nobody could manage users any more`

## SHOW USERS

Syntax:

```sql
SHOW USERS
```

Lists the users with their roles and grants. It never shows passwords or hashes.

| Column | Meaning |
|---|---|
| `name` | the user name as it was created |
| `role` | the role on every database |
| `grants` | the roles on single databases, like `shop=write, demo=read`; `NULL` when there are none |
| `created` | when the user was made (UTC) |
| `changed` | the last change of password, role or grants (UTC) |
| `table_grants` | [table rights](table-rights.md), like `shop.ledger: -DELETE`; `NULL` when there are none |
| `two_factor` | `true` when the user logs in with a [two-factor code](two-factor-login.md) |
| `statement_timeout` | the user's own [time limit](#statement-timeout), like `2 s` or `off`; `NULL` = the server's |

- **Returns:** one row per user, sorted by name (small and capital letters count the same).
- **Notes:**
  - Every user may run it. A user who is not an admin sees **only their own row**.
  - With no users yet it gives 0 rows.
  - A server or command that opened one database folder by its path (not a data folder) gives an error: users need a data folder.

**Example**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER shop_app WITH PASSWORD 'Another-long-secret-42' ROLE none;
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
CREATE DATABASE shop;
GRANT write ON DATABASE shop TO shop_app;
GRANT read ON DATABASE demo TO shop_app;
```

```sql
SHOW USERS;
```

Result:

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-22T09:56:42.950Z | 2026-10-22T09:56:42.950Z | NULL | false | NULL | NULL |
| report | read | NULL | 2026-10-22T09:56:43.060Z | 2026-10-22T09:56:43.060Z | NULL | false | NULL | NULL |
| shop_app | none | demo=read, shop=write | 2026-10-22T09:56:43.005Z | 2026-10-22T09:56:43.076Z | NULL | false | NULL | NULL |

(3 rows)

## GRANT

Syntax:

```sql
GRANT read | write | ddl | admin | ALL ON DATABASE db TO name
```

Gives a user a role on **one** database. `ALL` is the same as `admin`.

| Part | Meaning |
|---|---|
| role | `read`, `write`, `ddl`, `admin` or `ALL` |
| `db` | an existing database |
| `name` | an existing user |

- **Returns:** a message like `user 'shop_app' has role write on database 'shop'`.
- **Notes:**
  - A user has **one** grant per database. A new `GRANT` on the same database replaces the old one (also a weaker one: `GRANT read` after `GRANT admin` leaves `read`).
  - The user may use the **stronger** of its own `ROLE` and the grant. A grant can never take away what `ROLE` gives.
  - `GRANT admin ON DATABASE shop` gives all rights **inside** `shop`, but not creating or dropping databases, and not managing users. Those need `ROLE admin`.
  - Needs `ROLE admin`.
  - `DROP DATABASE` also removes every grant on that database.
  - A `GRANT` of a role is per database. For single tables use [table rights](table-rights.md): `GRANT SELECT ON TABLE prices TO u`, `REVOKE DELETE ON TABLE ledger FROM app`. There are no column or row rights.

**Example: The app may write in its own database only**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER shop_app WITH PASSWORD 'Another-long-secret-42';
CREATE DATABASE shop;
```

```sql
GRANT write ON DATABASE shop TO shop_app;
GRANT ALL ON DATABASE demo TO shop_app;
SHOW USERS;
```

Result:

`GRANT write ON DATABASE shop TO shop_app`

```text
user 'shop_app' has role write on database 'shop'
```

`GRANT admin ON DATABASE demo TO shop_app`

```text
user 'shop_app' has role admin on database 'demo'
```

`SHOW USERS`

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-22T09:56:43.118Z | 2026-10-22T09:56:43.118Z | NULL | false | NULL | NULL |
| shop_app | none | demo=admin, shop=write | 2026-10-22T09:56:43.173Z | 2026-10-22T09:56:43.316Z | NULL | false | NULL | NULL |

(2 rows)

**Example: DROP DATABASE removes the grants on it**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER shop_app WITH PASSWORD 'Another-long-secret-42';
CREATE DATABASE shop;
GRANT write ON DATABASE shop TO shop_app;
```

```sql
DROP DATABASE shop;
SHOW USERS;
```

Result:

`DROP DATABASE shop`

```text
database 'shop' dropped; its folder was moved to kdb-data/_trash/1792663003586-shop
```

`SHOW USERS`

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-22T09:56:43.339Z | 2026-10-22T09:56:43.339Z | NULL | false | NULL | NULL |
| shop_app | none | NULL | 2026-10-22T09:56:43.399Z | 2026-10-22T09:56:43.592Z | NULL | false | NULL | NULL |

(2 rows)

**Example: The database must exist** (shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER shop_app WITH PASSWORD 'Another-long-secret-42';
```

```sql
GRANT write ON DATABASE accounts TO shop_app;
```

Result:

Error: `database 'accounts' does not exist`

**Example: none is not a role to grant: use REVOKE** (shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
```

```sql
GRANT none ON DATABASE demo TO admin;
```

Result:

Error: `line 1, column 7: expected a role (read, write, ddl or admin, or ALL) in GRANT, found 'none'`

## REVOKE

Syntax:

```sql
REVOKE [read | write | ddl | admin | ALL] ON DATABASE db FROM name
```

Removes the user's grant on one database.

| Part | Meaning |
|---|---|
| role | optional, and only for reading comfort: the whole grant on `db` goes, whatever role you write |
| `db` | the database. It may already be gone. |
| `name` | an existing user |

- **Returns:** `user 'name' has no grant on database 'db' now` (also when there was no grant).
- **Notes:**
  - It does **not** change the user's own `ROLE`. A user with `ROLE read` can still read `db` after `REVOKE`. Use `ALTER USER name ROLE none` for that.
  - `REVOKE read ...` on a user with a `write` grant removes the `write` grant too; there is no "step down". To give less, `GRANT` the smaller role instead.
  - KarelaDB also accepts `TO name` instead of `FROM name`.
  - Needs `ROLE admin`.

**Example**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER shop_app WITH PASSWORD 'Another-long-secret-42';
GRANT write ON DATABASE demo TO shop_app;
```

```sql
REVOKE ALL ON DATABASE demo FROM shop_app;
SHOW USERS;
```

Result:

`REVOKE ALL ON DATABASE demo FROM shop_app`

```text
user 'shop_app' has no grant on database 'demo' now
```

`SHOW USERS`

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-22T09:56:43.618Z | 2026-10-22T09:56:43.618Z | NULL | false | NULL | NULL |
| shop_app | none | NULL | 2026-10-22T09:56:43.672Z | 2026-10-22T09:56:43.798Z | NULL | false | NULL | NULL |

(2 rows)

**Example: REVOKE does not touch the user's own ROLE**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
GRANT write ON DATABASE demo TO report;
```

```sql
REVOKE read ON DATABASE demo FROM report;
SHOW USERS;
```

Result:

`REVOKE read ON DATABASE demo FROM report`

```text
user 'report' keeps role write on database 'demo': REVOKE read takes away only a read grant; use REVOKE write or REVOKE ALL. Nothing was revoked
```

`SHOW USERS`

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-22T09:56:43.815Z | 2026-10-22T09:56:43.815Z | NULL | false | NULL | NULL |
| report | read | demo=write | 2026-10-22T09:56:43.872Z | 2026-10-22T09:56:43.874Z | NULL | false | NULL | NULL |

(2 rows)

<a id="set-role"></a>

## SET ROLE

Syntax:

```sql
SET ROLE name          -- from now on, statements use the rights of user `name`
SET ROLE NONE          -- back to the login user's rights
RESET ROLE             -- the same
```

An app that logs in as an admin (for its start-up migrations) can drop to the rights of its own user for everything else. The session keeps the role until `RESET ROLE`, as in PostgreSQL.

| Who logged in | May take |
|---|---|
| the token, or a server without users | any user |
| a user whose own `ROLE` is `admin` | any user |
| any other user | only itself |

- **Returns:** `statements now use the rights of user 'name' (RESET ROLE goes back)`.
- **Errors:** a name that is no user: `role "name" does not exist` (`22023`). Someone else, without `ROLE admin`: `permission denied to set role "name"` (`42501`).
- **Notes:**
  - Every statement is checked against the rights of the role: its `ROLE`, its database `GRANT`s and its [table rights](table-rights.md).
  - Over the PostgreSQL protocol `current_user` gives the role and `session_user` the login user. The audit log names both (`admin (as report)`).
  - It changes the rights of SQL. HTTP routes that are not SQL (`/api/...`) still use the login.
  - It lasts for the HTTP session or the PostgreSQL connection. Without a session it lasts for the one request.

**Example: An admin session takes the rights of a report user** (shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
```

```sql
SET ROLE report;
SELECT 1 AS reading_is_fine;
CREATE TABLE made_by_report (id INT);
```

Result:

```text
statements now use the rights of user 'report' (RESET ROLE goes back)
```

Error: `CREATE TABLE needs role ddl on database 'demo'; user 'report' has read`

**Example: RESET ROLE goes back to the login user's rights**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
```

```sql
SET ROLE report;
RESET ROLE;
CREATE TABLE made_after_reset (id INT);
```

Result:

`SET role = 'report'`

```text
statements now use the rights of user 'report' (RESET ROLE goes back)
```

`SET role = ''`

```text
back to the rights of the login user
```

`CREATE TABLE made_after_reset (`

```text
table 'made_after_reset' created
```

<a id="roles"></a>

## Roles: what each one may do

Syntax:

```sql
none  <  read  <  write  <  ddl  <  admin
```

Each role may do everything of the roles before it.

| Role | May do |
|---|---|
| `none` | nothing (until a `GRANT`). It may still log in, change its own password and see its own row in `SHOW USERS`. |
| `read` | `SELECT`, `SHOW ...`, `EXPLAIN`, `USE`, CSV export, cursors (`DECLARE`, `FETCH`, `CLOSE`), `BEGIN` / `COMMIT` / `ROLLBACK` / `SAVEPOINT`, `/api/info`, list backups |
| `write` | also `INSERT`, `UPDATE`, `DELETE` (with `RETURNING`), `TRUNCATE`, `CALL` of procedures, `SELECT ... FOR UPDATE`, line protocol (`POST /write`) |
| `ddl` | also the schema: `CREATE` / `ALTER` / `DROP` / `RENAME` of tables, views, indexes, sequences, functions, procedures and triggers, `REFRESH VIEW`, a new table with `POST /imp`. No users, no server settings, no backups, no audit log. |
| `admin` | also `BACKUP`, `CHECK TABLE`, `SHOW AUDIT`, `ALTER TABLE ... SET AUDIT`, `ALTER DATABASE`, `TRUNCATE ALL TABLES`, the trigger queue (`RETRY` / `SKIP`) |

The HTTP routes that are not SQL need these roles:

| Needs | Routes |
|---|---|
| a login only | `GET /api/me`, `POST /api/feedback` (send a comment) |
| `read` on the database | `GET /api/info`, `GET /api/disk`, `GET /api/backups`, `GET /api/stats`, `GET /api/trigger-queue`, `GET /api/timers`, `GET /api/pins`, cursors |
| `write` on the database | `POST /write`, `POST /api/v2/write`, `POST /imp` (`ddl` when it creates the table) |
| `admin` on the database | `POST /api/check`, `POST /api/backup`, save, run, turn off or delete a [timer](timers.md), pin or unpin a [statement](pinned-queries.md) |
| the user's own `ROLE admin` | `GET` and `POST /api/settings`, `POST /api/restart`, `POST` and `DELETE /api/databases`, `GET /api/feedback`, `POST /api/feedback/<id>`, `GET /api/audit` (with `kind=data`: `admin` on that database is enough) |

Two places give a role:

| Where | For | Written |
|---|---|---|
| the user's own `ROLE` | **every** database | `CREATE USER ... ROLE read`, `ALTER USER ... ROLE read` |
| a grant | **one** database | `GRANT write ON DATABASE shop TO shop_app` |

- **Returns:** a statement without the needed role is refused before any of it runs, with HTTP status 403 and a message like `INSERT needs role write on database 'shop'; user 'report' has read`.
- **Notes:**
  - Only a user whose own `ROLE` is `admin` may create and drop databases and manage users (`CREATE USER`, `ALTER USER ... ROLE`, `DROP USER`, `GRANT`, `REVOKE`). The message then says `needs role admin as its own ROLE (it acts on the whole server)`.
  - `SHOW DATABASES` lists only the databases the user may read.
  - A `--token` of the server works like a full admin.
  - Give each program only what it needs: your app's backend `write` on its own database, a report script `read`, a migration tool `ddl`. Keep `admin` for yourself.
  - `ddl` is for a developer or a migration tool (Flyway, Alembic, Prisma) that changes tables but must not manage users or settings. It is kept by its name, like the other roles. An older KarelaDB reads a `ddl` user as `none`: that user loses rights there, it never gains them.
  - `CALL` needs `write`: a procedure can only change rows (it can not hold `CREATE` or `DROP`).
  - A view, procedure or trigger saved by a `ddl` user may only read and change what that user may. `CREATE VIEW v AS SELECT * FROM _audit_log` needs `admin`, like reading `_audit_log` itself. See [table rights](table-rights.md#revoke-on-table).
  - Only `kareladb serve` (HTTP, web console and PostgreSQL port) checks roles. `kareladb sql` and `kareladb shell` do not.

**Example: A report user that may read every database, and an app that may write one**

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
| admin | admin | NULL | 2026-10-22T09:56:44.043Z | 2026-10-22T09:56:44.043Z | NULL | false | NULL | NULL |
| report | read | NULL | 2026-10-22T09:56:44.223Z | 2026-10-22T09:56:44.223Z | NULL | false | NULL | NULL |
| shop_app | none | demo=write | 2026-10-22T09:56:44.281Z | 2026-10-22T09:56:44.283Z | NULL | false | NULL | NULL |

(3 rows)

**Example: A migration user may change tables, not users** (shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER migrate WITH PASSWORD 'Migrations-only-secret-9' ROLE ddl;
```

```sql
SET ROLE migrate;
CREATE TABLE orders (id INT PRIMARY KEY, total DOUBLE);
ALTER TABLE orders ADD COLUMN placed TIMESTAMP;
CREATE INDEX orders_placed ON orders (placed);
INSERT INTO orders VALUES (1, 12.5, '2026-09-25T10:00:00Z');
CREATE USER intern WITH PASSWORD 'Intern-long-secret-3';
```

Result:

`SET role = 'migrate'`

```text
statements now use the rights of user 'migrate' (RESET ROLE goes back)
```

`CREATE TABLE orders (`

```text
table 'orders' created
```

`ALTER TABLE orders ADD COLUMN placed TIMESTAMP`

```text
table 'orders' altered
```

`CREATE INDEX orders_placed ON orders (placed)`

```text
index 'orders_placed' created on table 'orders' (0 rows)
```

`INSERT INTO orders VALUES (1, 12.5, '2026-09-25T10:00:00Z')`

```text
1 row(s) inserted
```

Error: `CREATE USER needs role admin as its own ROLE (it acts on the whole server); user 'migrate' has ddl`

**Example: A writer may change rows but not the schema** (shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER shop_app WITH PASSWORD 'Another-long-secret-42' ROLE write;
```

```sql
SET ROLE shop_app;
CREATE TABLE app_made (id INT);
```

Result:

```text
statements now use the rights of user 'shop_app' (RESET ROLE goes back)
```

Error: `CREATE TABLE needs role ddl on database 'demo'; user 'shop_app' has write`

<a id="system-database"></a>

## Where users are kept

Syntax:

```sql
<data folder>/_system/        the hidden database with the table users
```

Users belong to the **data folder**, not to one database. KarelaDB keeps them in a hidden database named `_system` inside the data folder. All databases of that folder share the users.

| Column of `users` | Holds |
|---|---|
| `name`, `role`, `grants` | what `SHOW USERS` shows |
| `password_hash` | `$pbkdf2-sha256$i=600000$...` (the same form as `password_hash()`) |
| `scram` | `SCRAM-SHA-256$4096:...` for PostgreSQL clients |
| `created_at`, `changed_at` | times |

- **Returns:** not a statement: `USE _system` and `CREATE DATABASE _system` are refused.
- **Notes:**
  - A server that opened **one database folder by its path** (`kareladb serve D:\kdb\market`) has no users. Use `--data-dir <folder>`.
  - Anyone who can read the data folder or a backup can read the password hashes. Keep the folder and backups private (`chmod 700` on Linux).
  - `kareladb user add | passwd | role | list | remove` work on the same users while the server is stopped (see [kareladb user](cli-users.md)). While `kareladb serve` runs, use SQL in its console.
  - Logins (sessions) and [API tokens](api-tokens.md) are kept here too, as hashes only, so a restart logs nobody out.
  - An old `kareladb` program made before users existed does not know `_system` and would serve the data **without** a login. Update every `kareladb` program first.

**Example: _system is not a normal database** (shows an error)

```sql
USE _system;
```

Result:

Error: `line 1, column 5: bad database name '_system': '_system' is where KarelaDB keeps its users`

**Command line: kareladb user and SQL see the same users**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
> Long-Admin-Passw0rd
kareladb user list
kareladb sql kdb-data/shop "CREATE TABLE orders (id INT PRIMARY KEY)"
kareladb sql shop "CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read; SHOW USERS"
```

Output:

`> kareladb user add admin --role admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb user list`

```text
USER                     ROLE   GRANTS                         CHANGED
admin                    admin  -                              2026-10-22 15:41:44
1 user in ./kdb-data
```

`> kareladb sql kdb-data/shop "CREATE TABLE orders (id INT PRIMARY KEY)"`

```text
table 'orders' created
```

`> kareladb sql shop "CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read; SHOW USERS"`

```text
user 'report' created with role read

name   | role  | grants | created                  | changed                  | table_grants | two_factor | statement_timeout | priority
-------+-------+--------+--------------------------+--------------------------+--------------+------------+-------------------+---------
admin  | admin | NULL   | 2026-10-22T09:56:44.318Z | 2026-10-22T09:56:44.318Z | NULL         | false      | NULL              | NULL    
report | read  | NULL   | 2026-10-22T09:56:44.908Z | 2026-10-22T09:56:44.908Z | NULL         | false      | NULL              | NULL    
(2 rows, 0.0 ms)
```

Here the data folder is `kdb-data`. The first `kareladb sql` makes the database `shop` in it by its path. After that, the plain name `shop` means the database in the data folder, so the user statements work. A plain name that is **not** in the data folder is taken as a new folder in the current folder, and then user statements say `users need a data folder`.
