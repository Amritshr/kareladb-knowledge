# Audit log

> KarelaDB writes security events (logins, users, DDL, backups, refused rights) and, for chosen tables, every changed row with who, when, old and new values.

- Category: Users & security
- Keywords: audit, audit log, audit trail, hash chain, tamper, tamper-evident, SHOW AUDIT VERIFY, verify, user agent, User-Agent, application\_name, agent, --token-name, KARELADB\_TOKEN\_NAME, who changed, history of changes, login history, failed logins, lockout, \_audit\_log, AUDIT, SET AUDIT ON, SET AUDIT OFF, old values, new values, accounting, compliance, --audit, --audit-keep-days, retention, erase user, delete user data, right to be forgotten, GDPR, privacy, personal data, erasure
- See also: [Protection - timeouts, limits, safe updates, read-only](protection.md), [Users and roles](users-and-roles.md), [Keeping kareladb serve safe](server-security.md), [Table rights - GRANT ON TABLE](table-rights.md), [Two-factor login (TOTP)](two-factor-login.md), [Logins, tokens and roles over HTTP](http-login.md)

The audit log is a table named `_audit_log`. KarelaDB writes it; nobody can change, delete or drop its rows (it is **append-only**). It goes through the log like any change, so it survives crashes, and backups hold it.

| What | Where | Turn it on |
|---|---|---|
| logins (good, failed, lockouts), user and grant changes, `CREATE`/`DROP`/`ALTER` of tables, indexes, views, functions, procedures, triggers and databases, backups, timers, pinned statements, partitions a TTL dropped, refused rights | `_audit_log` of the hidden `_system` database | `kareladb serve --data-dir ...` (default `--audit on`) |
| every row a statement adds, changes or deletes in one table | `_audit_log` of that database | `ALTER TABLE t SET AUDIT ON` |

Columns of `_audit_log`: `time`, `event`, `user`, `client`, `db`, `object`, `detail`, `row_key`, `old_values` (JSON), `new_values` (JSON), `session`, `ok`, `seq`, `hash`, `agent`.

`client` is the address and protocol (`10.0.0.5 (http)`). `agent` is the program that sent the request: the HTTP `User-Agent` header (`curl/8.4.0`, the browser of the web console), or the PostgreSQL `application_name` (`psql`, `DBeaver`). It is at most 200 characters, and `NULL` when the client sent none. A client can write anything there, so it helps to tell programs apart but proves nothing.

An action done with the server's `--token` is written with `user` = `token`, or the name given with `--token-name` (or `KARELADB_TOKEN_NAME`), never with an empty user.

| event | Meaning |
|---|---|
| `login`, `login_failed`, `lockout` | a login, a wrong password or code, an address that must wait |
| `user`, `ddl`, `protection`, `backup`, `server` | user statements, schema changes, protection settings, backups, server start, stop and restart |
| `timer` | a [timer](timers.md) saved, run now, turned on or off, or deleted |
| `pin` | a [pinned statement](pinned-queries.md) pinned or unpinned |
| `ttl_drop` | partitions a table's [TTL](alter-table.md#set-ttl) dropped by itself |
| `denied` | a statement the user's rights did not allow |
| `insert`, `update`, `delete` | a row of a table with `SET AUDIT ON` |

<a id="show-audit"></a>

## SHOW AUDIT

Syntax:

```sql
SHOW AUDIT [LIMIT n] [WHERE <condition>] [LIMIT n]
```

The newest security events first (100 when there is no `LIMIT`). The condition uses the columns above.

- **Returns:** rows of `_audit_log` of `_system` (on a server that opened one folder by its path: of that database).
- **Notes:** needs a server admin. The condition may only use the audit rows: no subqueries of other tables.

**Example: Failed logins of the last day**

```sql
SHOW AUDIT WHERE event = 'login_failed' AND time > dateadd('d', -1, now()) LIMIT 20;
```

Result:

| time (TIMESTAMP) | event (STRING) | user (STRING) | client (STRING) | db (STRING) | object (STRING) | detail (STRING) | row_key (STRING) | old_values (JSON) | new_values (JSON) | session (LONG) | ok (BOOL) | seq (LONG) | hash (STRING) | agent (STRING) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|

(0 rows)

```text
no audit events yet
```

<a id="set-audit"></a>

## ALTER TABLE ... SET AUDIT ON

Syntax:

```sql
ALTER TABLE <name> SET AUDIT ON
ALTER TABLE <name> SET AUDIT OFF
```

From now on, every row a statement adds, changes or deletes in the table is also written to `_audit_log` of the database, **in the same transaction** as the change: there is never a change without its audit row, or an audit row without its change.

| Column | Holds |
|---|---|
| `event` | `insert`, `update` or `delete` |
| `user`, `client`, `agent`, `session` | who: the logged-in user, the address and protocol, the client program, the session |
| `detail` | the statement (a big INSERT is shortened) |
| `row_key` | the key of the row: `id='5'`, or `rowid=7` for a table without a key |
| `old_values`, `new_values` | the row before and after, as JSON. Columns whose name holds `password`, `secret`, `token`, `scram` or `totp` show `"***"`. |

- **Returns:** `audit is on for table 'accounts': every changed row is written to _audit_log`.
- **Notes:**
  - Tables without `SET AUDIT ON` cost nothing extra. An audited table's writes cost one row lookup and one audit row per changed row.
  - An `UPDATE` that changes nothing in a row writes no audit row. Rolled back transactions write none.
  - Read the rows with `SELECT ... FROM _audit_log` (needs role admin on the database).
  - Older KarelaDB programs refuse a database with an audited table (the setting would be lost).

**Example: Audit an accounts table**

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING, balance DECIMAL(2));
ALTER TABLE accounts SET AUDIT ON;
INSERT INTO accounts VALUES (1, 'Sita', 100.00);
UPDATE accounts SET balance = balance - 25 WHERE id = 1;
SELECT event, row_key, old_values, new_values FROM _audit_log ORDER BY time;
```

Result:

`CREATE TABLE accounts (`

```text
table 'accounts' created
```

`ALTER TABLE accounts SET AUDIT ON`

```text
audit is on for table 'accounts': every changed row is written to _audit_log
```

`INSERT INTO accounts VALUES (1, 'Sita', 100.00)`

```text
1 row(s) inserted
```

`UPDATE accounts SET balance = balance - 25 WHERE id = 1`

```text
1 row(s) updated
```

`SELECT event, row_key, old_values, new_values FROM _audit_log ORDER BY time`

| event (STRING) | row_key (STRING) | old_values (JSON) | new_values (JSON) |
|---|---|---|---|
| insert | id='1' | NULL | {"id":1,"owner":"Sita","balance":100.00} |
| update | id='1' | {"id":1,"owner":"Sita","balance":100.00} | {"id":1,"owner":"Sita","balance":75.00} |

(2 rows)

**Example: Nobody can change the audit rows** (shows an error)

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, balance DECIMAL(2));
ALTER TABLE accounts SET AUDIT ON;
DELETE FROM _audit_log;
```

Result:

`CREATE TABLE accounts (`

```text
table 'accounts' created
```

`ALTER TABLE accounts SET AUDIT ON`

```text
audit is on for table 'accounts': every changed row is written to _audit_log
```

Error: `the audit table _audit_log is append-only: KarelaDB writes it, nobody can change or drop it (old rows are removed by the audit retention setting)`

<a id="hash-chain"></a>

## The hash chain

Every row gets a number and a hash, so a row changed or removed outside KarelaDB (by editing the files) is found.

| Column | Holds |
|---|---|
| `seq` | 1, 2, 3 ... in the order the rows were written |
| `hash` | SHA-256 (hex) of the previous row's hash and this row's values |

A changed row no longer matches its hash. A removed row leaves a gap in `seq`. `SHOW AUDIT VERIFY`, `kareladb check <database>` and `POST /api/check` check the whole chain and name the rows that do not fit.

- **Returns:** `kareladb check` prints `audit chain: N row(s) checked, seq 1 to N, newest hash ...`, or a `TAMPERED:` line per problem (exit code 2).
- **Notes:**
  - Note the newest hash somewhere else now and then (a ticket, an email). Then even the newest rows cannot be cut off unseen.
  - Rows written before KarelaDB had the chain keep `seq` and `hash` empty; the check counts them apart.
  - When `--audit-keep-days` removes old months, the check starts at the oldest row left.
  - The `agent` column came after the chain. It is in the hashed values only when it has a value: older rows (no agent) keep the hash they were written with, and a row's agent can not be changed or cleared unseen.

**Example: The chain of an audited table**

```sql
CREATE TABLE ledger (id INT PRIMARY KEY, amount DECIMAL(2));
ALTER TABLE ledger SET AUDIT ON;
INSERT INTO ledger VALUES (1, 10.00), (2, 20.00);
SELECT seq, event, row_key, length(hash) AS hash_length FROM _audit_log ORDER BY seq;
```

Result:

`CREATE TABLE ledger (`

```text
table 'ledger' created
```

`ALTER TABLE ledger SET AUDIT ON`

```text
audit is on for table 'ledger': every changed row is written to _audit_log
```

`INSERT INTO ledger VALUES (1, 10.00), (2, 20.00)`

```text
2 row(s) inserted
```

`SELECT seq, event, row_key, length(hash) AS hash_length FROM _audit_log ORDER BY seq`

| seq (LONG) | event (STRING) | row_key (STRING) | hash_length (LONG) |
|---|---|---|---|
| 1 | insert | id='1' | 64 |
| 2 | insert | id='2' | 64 |

(2 rows)

<a id="show-audit-verify"></a>

## SHOW AUDIT VERIFY

Syntax:

```sql
SHOW AUDIT VERIFY
```

Checks the hash chain from SQL, the same check as `kareladb check`, without stopping the server.

| Column | Holds |
|---|---|
| `log` | which `_audit_log`: `_system` (the security events), or the database of the session (its `SET AUDIT ON` rows) |
| `ok` | `true` when every row matches its hash and no `seq` is missing |
| `rows_checked` | the rows with a `seq` |
| `unchained` | older rows written before the chain existed |
| `first_seq`, `last_seq` | the range of `seq` checked |
| `first_broken` | the `seq` of the first row that does not fit; `NULL` when all fit |
| `problems` | what is wrong, row by row |
| `last_hash` | the newest hash: note it somewhere else to also catch a cut at the end |

- **Returns:** one row per audit log, and the message `the audit hash chain is intact (N rows checked)` or `the audit hash chain is broken: ...`.
- **Notes:**
  - Needs a server admin, like `SHOW AUDIT`.
  - It reads the whole chain: on a log of millions of rows it takes a few seconds.

**Example: Check the chain of an audited table**

```sql
CREATE TABLE ledger (id INT PRIMARY KEY, amount DECIMAL(2));
ALTER TABLE ledger SET AUDIT ON;
INSERT INTO ledger VALUES (1, 10.00), (2, 20.00);
UPDATE ledger SET amount = 15.00 WHERE id = 1;
SHOW AUDIT VERIFY;
```

Result:

`CREATE TABLE ledger (`

```text
table 'ledger' created
```

`ALTER TABLE ledger SET AUDIT ON`

```text
audit is on for table 'ledger': every changed row is written to _audit_log
```

`INSERT INTO ledger VALUES (1, 10.00), (2, 20.00)`

```text
2 row(s) inserted
```

`UPDATE ledger SET amount = 15.00 WHERE id = 1`

```text
1 row(s) updated
```

`SHOW AUDIT VERIFY`

| log (STRING) | ok (BOOL) | rows_checked (LONG) | unchained (LONG) | first_seq (LONG) | last_seq (LONG) | first_broken (LONG) | problems (STRING) | last_hash (STRING) |
|---|---|---|---|---|---|---|---|---|
| demo | true | 3 | 0 | 1 | 3 | NULL | NULL | 586b7f6bc8a60adc19241c04b6556b4076d49e57567d5b7b613c74bb6657009b |

(1 row)

```text
the audit hash chain is intact (3 rows checked)
```

<a id="api-audit"></a>

## GET /api/audit

Syntax:

```sql
GET /api/audit?limit=100&where=<condition>
GET /api/audit?db=<name>&kind=data&limit=100&where=<condition>
```

The same as `SHOW AUDIT` over HTTP. With `kind=data`: the data-change rows of the database `db`.

- **Returns:** `{"query", "columns", "dataset", "count"}`.
- **Notes:** needs a server admin (for `kind=data`: admin on that database). HTTP 404 when no table of the database has `SET AUDIT ON` yet.

**HTTP: The newest security events**

```http
GET /api/audit?limit=5
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "SHOW AUDIT LIMIT 5",
  "columns": [
    {"name": "time", "type": "TIMESTAMP"},
    {"name": "event", "type": "STRING"},
    {"name": "user", "type": "STRING"},
    {"name": "client", "type": "STRING"},
    {"name": "db", "type": "STRING"},
    {"name": "object", "type": "STRING"},
    {"name": "detail", "type": "STRING"},
    {"name": "row_key", "type": "STRING"},
    {"name": "old_values", "type": "JSON"},
    {"name": "new_values", "type": "JSON"},
    {"name": "session", "type": "LONG"},
    {"name": "ok", "type": "BOOL"},
    {"name": "seq", "type": "LONG"},
    {"name": "hash", "type": "STRING"},
    {"name": "agent", "type": "STRING"}
  ],
  "dataset": [],
  "count": 0
}
```

<a id="audit-keep-days"></a>

## --audit-keep-days

Syntax:

```sql
kareladb serve [--audit on|off] [--audit-keep-days N]
```

`--audit off` writes no security events. `--audit-keep-days N` removes security events older than N days, a whole month at a time, once a day (0 = keep forever, the default).

- **Notes:**
  - Security events (`login_failed`, `lockout`, `denied`, `user`, `protection`) are written to disk before the request that caused them gets its answer. A successful `login` and the other events (`ddl`, `timer`, `backup` ...) are written in groups every 200 ms, so a crash can lose the events of that moment. A new connection does not wait for a disk write.
  - Keep the audit log of accounting for as long as the law asks (often several years).
  - `--audit-keep-days` only removes **security events** (the `_audit_log` of `_system`). The data-change rows of `SET AUDIT ON` tables, in each database's own `_audit_log`, are kept as long as the database lives (see [erase one user's data](#erase-user)).

<a id="erase-user"></a>

## Erase one user's data

A person asks you to delete everything you hold about them. Three steps: find the tables, delete the rows, and know what the audit log keeps.

**1. Find every table with a user column.** `information_schema.columns` lists the columns of every table.

**Example: Which tables hold a user id or an email?**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY, email STRING NOT NULL);
CREATE TABLE orders (id INT PRIMARY KEY, user_id INT REFERENCES app_users(id) ON DELETE CASCADE, amount DECIMAL(2));
CREATE TABLE page_views (time TIMESTAMP, user_id INT, page STRING) TIMESERIES(time) PARTITION BY DAY;
```

```sql
SELECT table_name, column_name FROM information_schema.columns
WHERE column_name IN ('user_id', 'email') ORDER BY table_name;
```

Result:

| table_name (STRING) | column_name (STRING) |
|---|---|
| app_users | email |
| orders | user_id |
| page_views | user_id |

(3 rows)

**2. Delete the rows in one transaction.** Tables that point to the user with `REFERENCES ... ON DELETE CASCADE` lose their rows together with the user's row ([REFERENCES](constraints.md#references)). Tables without such a key (a time-series table of page views, for example) need their own `DELETE`. One `BEGIN ... COMMIT` makes it all or nothing.

**Example: Delete user 1 everywhere, then check**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY, email STRING NOT NULL);
CREATE TABLE orders (id INT PRIMARY KEY, user_id INT REFERENCES app_users(id) ON DELETE CASCADE, amount DECIMAL(2));
CREATE TABLE page_views (time TIMESTAMP, user_id INT, page STRING) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO app_users VALUES (1, 'ram@example.com'), (2, 'sita@example.com');
INSERT INTO orders VALUES (10, 1, 250.00), (11, 2, 99.50), (12, 1, 10.00);
INSERT INTO page_views VALUES ('2026-09-24T10:00:00Z', 1, '/home'), ('2026-09-24T10:01:00Z', 2, '/home');
```

```sql
BEGIN;
DELETE FROM page_views WHERE user_id = 1;
DELETE FROM app_users WHERE id = 1;
COMMIT;
SELECT 'orders' AS table_name, count(*) AS rows_left FROM orders WHERE user_id = 1
UNION ALL SELECT 'page_views', count(*) FROM page_views WHERE user_id = 1
UNION ALL SELECT 'app_users', count(*) FROM app_users WHERE id = 1;
```

Result:

`BEGIN`

```text
transaction started
```

`DELETE FROM page_views WHERE user_id = 1`

```text
1 row(s) deleted
```

`DELETE FROM app_users WHERE id = 1`

```text
1 row(s) deleted
```

`COMMIT`

```text
transaction committed: 4 change(s) saved
```

`SELECT 'orders' AS table_name, count(*) AS rows_left FROM orders WHERE user_id = 1 UNION ALL SELECT `

| table_name (STRING) | rows_left (LONG) |
|---|---|
| orders | 0 |
| page_views | 0 |
| app_users | 0 |

(3 rows)

**3. What the audit log keeps.** If a table has `SET AUDIT ON`, its `_audit_log` row for the `DELETE` holds the deleted row in `old_values`, and the older `insert` and `update` rows hold it too. **These rows cannot be erased with SQL.** The log is append-only on purpose: `DELETE`, `UPDATE`, `TRUNCATE` and `DROP` of `_audit_log` are refused, and every row is linked to the one before by the [hash chain](#hash-chain), so a row removed by editing the files is reported by `kareladb check`. `--audit-keep-days` does not reach these rows either: it only removes security events.

**Example: The deleted row is still in old_values**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY, email STRING NOT NULL);
ALTER TABLE app_users SET AUDIT ON;
INSERT INTO app_users VALUES (1, 'ram@example.com');
```

```sql
DELETE FROM app_users WHERE id = 1;
SELECT event, row_key, old_values FROM _audit_log WHERE event = 'delete';
```

Result:

`DELETE FROM app_users WHERE id = 1`

```text
1 row(s) deleted
```

`SELECT event, row_key, old_values FROM _audit_log WHERE event = 'delete'`

| event (STRING) | row_key (STRING) | old_values (JSON) |
|---|---|---|
| delete | id='1' | {"id":1,"email":"ram@example.com"} |

(1 row)

| What you can do | How |
|---|---|
| Keep personal data out of audited tables | Put names, emails and phone numbers in a table **without** `SET AUDIT ON`, and audit the table of money or orders that holds only the user's id. The audit rows then hold an id that means nothing once the user row is gone. |
| Hide secrets | Columns whose name holds `password`, `secret`, `token`, `scram` or `totp` are always written as `"***"`. |
| Stop recording | `ALTER TABLE t SET AUDIT OFF` writes no new rows. The rows already there stay. |
| Remove everything | `DROP DATABASE`, then `PURGE TRASH ALL`, removes the database and its `_audit_log`. There is no way to remove only some rows. |

- **Notes:** backups hold the deleted rows too, until the [backup schedule](backup-schedule.md) removes the old backups (`backup_keep_daily`, `backup_keep_weekly`).
- **Notes:** in many places the law lets you keep records you must keep for accounting or security, even after an erasure request. Say in your privacy policy that the audit log keeps the changes of audited tables, and for how long.
