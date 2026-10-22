# 21. Protection

- Category: Tutorial

## What you will learn

KDB already protects your data from crashes and disk damage (chapter 9) and from strangers (chapter 16). This chapter is about the other dangers of a real app:

- **Part A.** A slow or huge query that blocks the server: timeouts, cancel, memory limits, statements per user, and a stop that lets running requests finish.
- **Part B.** "Who changed this?": the audit log.
- **Part C.** Backups that happen by themselves, with a checked copy on another disk.
- **Part D.** Rights on single tables: an app user who may add ledger rows but never change them.
- **Part E.** Stronger logins: a password rule and two-factor codes.
- **Part F.** Mistakes: `UPDATE` without `WHERE`, a read-only database, `DROP TABLE` by mistake.
- **Part G.** What is not there yet: encryption of the files.
- A **VPS checklist** and **what it costs** in speed.

Everything here is fast. A running query looks at one flag every 16,384 rows (never at every row). Tables without audit pay nothing. The numbers are at the end.

## The short version

For the NChartPro server on a VPS, start KDB like this:

```sh
kdb serve --data-dir /srv/kdb/data --backups /srv/kdb/backups \
  --backup-schedule "daily 16:00" --backup-copy /mnt/backup-disk/kdb \
  --statement-timeout 30s --max-queries-per-user 32 --safe-updates
```

Then, in the console as an admin:

```sql
ALTER TABLE ledger SET AUDIT ON;
ALTER TABLE accounts SET AUDIT ON;
REVOKE UPDATE, DELETE ON TABLE ledger FROM app;
ALTER USER admin ENABLE TOTP;
```

The rest of the chapter explains each line.

| Protection | Default in `kdb serve` | How to change |
|---|---|---|
| statement timeout | 60 s | `--statement-timeout 30s`, `SET statement_timeout = '5s'` |
| memory of one query | 1 GB of rows, 5,000,000 groups | `--max-result-memory`, `--max-groups` |
| statements per user | 32 at the same time | `--max-queries-per-user` |
| requests at a stop | may finish for 30 s; new ones get 503 | `--drain-timeout 5s` |
| audit log of logins, users, DDL, backups | on (with a data folder) | `--audit off`, `--audit-keep-days N` |
| audit of changed rows | off | `ALTER TABLE t SET AUDIT ON` |
| scheduled backups | off | `--backup-schedule "daily 16:00"`, `--backup-copy <dir>` |
| table rights | none | `GRANT/REVOKE ... ON TABLE` |
| password rule | at least 12 characters, not the user name | always on |
| two-factor login | off | `ALTER USER x ENABLE TOTP` |
| safe updates | off | `--safe-updates`, `SET safe_updates = on` |
| read-only | off | `--read-only`, `ALTER DATABASE x SET READ ONLY` |
| DROP TABLE trash | 7 days (also `kdb sql` and `kdb shell`) | `--trash-days N` |

`kdb sql`, `kdb shell` and apps that use the KDB library directly have no timeouts or limits (they are your own programs). Their `DROP TABLE` keeps the trash.

---

## Part A: slow and huge queries

### Statement timeout

A statement that runs longer than the limit is stopped. In the web console of `kdb serve market` (with the sample data of chapter 2):

```sql
SET statement_timeout = '2s';
SELECT count(*) FROM ochl_minutes a CROSS JOIN ochl_minutes b CROSS JOIN ochl_minutes c WHERE a.close + b.close > c.close;
```

```text
statement_timeout is 2 s for this session
error: canceling statement due to statement timeout (2 s); make the query faster (WHERE, an index, LIMIT) or raise statement_timeout
```

- The limit counts from the start of the request (over HTTP) or of the query message (PostgreSQL).
- **Nothing of a stopped change is written.** An `UPDATE` stopped halfway changes no row; inside `BEGIN ... COMMIT` the transaction is rolled back, like any failed statement.
- The server's limit is `--statement-timeout` (60 s by default; `0` = no limit). A user who is not an admin can only make it shorter.
- HTTP: send `X-KDB-Statement-Timeout: 5s` with a request, or `SET statement_timeout = '5s'` in an [HTTP session](08-http-api.md).
- PostgreSQL: `SET statement_timeout = 5000` (milliseconds) or `'5s'`, like PostgreSQL itself. The error has SQLSTATE `57014`.
- HTTP answers a stopped statement with status **408**.

### Cancel a running statement

| From | How |
|---|---|
| Go `pgx`, Python, psql | cancel the context / press Ctrl+C: the driver sends a PostgreSQL CancelRequest, KDB stops the statement (`57014`, "due to user request") |
| HTTP | send `X-KDB-Request-Id: <your id>` with `POST /exec`; `DELETE /exec/<your id>` stops it |
| HTTP | close the connection: KDB notices it within 0.2 s and stops the statement |

```sh
# terminal 1: a long report
curl -s -H "X-KDB-Request-Id: report-17" --data "SELECT ... big report ..." http://127.0.0.1:9900/exec
# terminal 2: stop it
curl -s -X DELETE http://127.0.0.1:9900/exec/report-17
```

```text
{"request_id":"report-17","cancelled":true}
```

Users may stop only their own requests; admins may stop all.

### Memory of one query

A query that keeps too many rows in memory (the result, rows waiting for `ORDER BY`, `DISTINCT`, window functions) or makes too many groups is stopped before it uses all the memory of the VPS:

```text
error: the query keeps too many rows in memory (about 1030 MB; the limit is 1024 MB, max_result_memory). Add a WHERE or a LIMIT, or fetch the rows in parts with a cursor
error: the query makes more than 5000000 groups (max_groups). Group by fewer columns, add a WHERE, or use a longer SAMPLE BY interval
```

Set them with `--max-result-memory 512MB` and `--max-groups 1000000`. HTTP status 413, SQLSTATE `54000`. For a small VPS (1-2 GB), use `--max-result-memory 256MB`.

A big `GROUP BY` is not stopped just because its groups need a lot of memory. When they need more than half of `--max-result-memory`, KDB writes the groups that do not fit to temporary files in the database folder (`_tmp/`) and adds them up after the scan. The result is the same, only slower. The files are removed when the query ends. One query may write at most 16 GB of them; past that it stops with `the GROUP BY needs more than N MB of temporary files (max_spill_bytes)`.

### Statements per user

`--max-queries-per-user 32`: one user runs at most 32 statements at the same time (HTTP and PostgreSQL together). More get HTTP 429 (`user 'app' already runs 32 statements at the same time`). This stops one broken client or one script in a loop from taking every thread. Your app's connection pool should be smaller than the limit (pgx: `pool_max_conns=16`).

### Stopping the server

Ctrl+C, SIGTERM and `docker stop` do not cut running requests off:

| Request | What happens |
|---|---|
| already running | finishes and gets its real answer, for up to `--drain-timeout` (30 s; 5 s in the Docker image) |
| arrives during the stop | HTTP **503** with `Retry-After: 2`; nothing of it is run. `/health` answers 503 too. |
| still running after `--drain-timeout` | cancelled like a statement timeout; nothing half-done is written |

Keep the drain time below how long your service manager waits before it kills the process (`docker run --stop-timeout 60`, `TimeoutStopSec=` in systemd). Clients should send a request again after a 503: a cut-off `/write` or `/exec` was rolled back as a whole.

---

## Part B: the audit log

### Security events

`kdb serve --data-dir ...` writes these events to a table `_audit_log` in the hidden `_system` database:

| event | When |
|---|---|
| `login`, `login_failed`, `lockout` | a login (HTTP, Basic, PostgreSQL), a wrong password or code, an address that must wait |
| `user` | `CREATE/ALTER/DROP USER`, `GRANT`, `REVOKE`, also `kdb user ...` while the server is stopped |
| `ddl` | `CREATE`, `DROP`, `ALTER`, `RENAME` of tables, indexes, views, functions, procedures, triggers; `CREATE/DROP DATABASE` |
| `protection` | `SET AUDIT`, `UNDROP TABLE`, `ALTER DATABASE ... SET READ ONLY` |
| `backup` | every scheduled or manual backup, OK or failed |
| `denied` | a statement the user's rights did not allow |
| `server` | the server started or stopped |

Read them as a server admin:

```sql
SHOW AUDIT WHERE event = 'login_failed' LIMIT 20;
SHOW AUDIT WHERE user = 'app' AND time > dateadd('d', -1, now());
```

```text
time                     | event        | user  | client             | db | object | detail                                   | ...
-------------------------+--------------+-------+--------------------+----+--------+------------------------------------------+
2026-09-12T10:31:07.412Z | login_failed | admin | 203.0.113.7 (http) |    | admin  | wrong password; 3 failure(s) in a row    |
```

Over HTTP: `GET /api/audit?limit=50&where=event%20%3D%20'lockout'`. The `where` can use every column, but no subqueries of other tables.

Nobody can change the audit rows: `DELETE FROM _audit_log` answers `the audit table _audit_log is append-only`. The rows are written in groups every 200 ms, through the log like any change: a crash can lose only the events of that last moment.

Old rows: `--audit-keep-days 400` removes whole months older than 400 days, once a day. The default keeps everything. For accounting data, keep the log as long as the law asks.

A server started on one folder by its path (`kdb serve D:\kdb\market`) has no `_system` and writes no security events. Use `--data-dir`.

### Who changed this row?

For money tables, turn on the data-change audit:

```sql
ALTER TABLE accounts SET AUDIT ON;
UPDATE accounts SET balance = balance - 25 WHERE id = 1;
SELECT time, event, user, row_key, old_values, new_values, detail FROM _audit_log ORDER BY time DESC LIMIT 5;
```

```text
audit is on for table 'accounts': every changed row is written to _audit_log
1 row(s) updated
time                     | event  | user | row_key | old_values                               | new_values                              | detail
-------------------------+--------+------+---------+------------------------------------------+-----------------------------------------+------------------------------------------------
2026-09-12T10:40:02.118Z | update | app  | id='1'  | {"id":1,"owner":"Sita","balance":100.00} | {"id":1,"owner":"Sita","balance":75.00} | UPDATE accounts SET balance = balance - 25 ...
```

- Every row that an `INSERT`, `UPDATE`, `DELETE`, `INSERT OR REPLACE`, `CALL`, trigger or line-protocol request adds, changes or deletes gets one audit row: `event` (insert, update, delete), `user`, `client`, `session`, the statement, the row key, and the row before and after as JSON.
- The audit row is written **in the same transaction** as the change. There is never a change without its audit row, not even after a power cut. A rolled back transaction leaves neither.
- Columns whose name holds `password`, `secret`, `token`, `scram` or `totp` show `"***"`.
- An `UPDATE` that changes nothing in a row writes no audit row.
- Only admins of the database can read `_audit_log`; nobody can change it.
- Tables without `SET AUDIT ON` cost nothing extra. An audited table's writes cost about one row lookup and one extra row per changed row.
- `ALTER TABLE accounts SET AUDIT OFF` stops it; the rows already written stay.

---

## Part C: backups on a schedule

Chapter 9 made backups by hand. `kdb serve` can do it by itself:

```sh
kdb serve --data-dir D:\kdb\data --backups D:\kdb_backups --backup-schedule "daily 16:00" --backup-copy E:\kdb_copy
```

```text
  schedule  backups daily 16:00, next 2026-09-12 16:00:00, checked copy in E:\kdb_copy
...
2026-09-12 16:00:03  backup of 'market' OK: 41 files, 312.4 MB, 2850 ms, D:/kdb_backups/market/20260912-101500-004; copy checked: E:/kdb_copy/market/20260912-101500-004
2026-09-12 16:00:03  backup of '_system' OK: 6 files, 1.2 MB, 90 ms, ...
```

| Schedule | Meaning |
|---|---|
| `daily 16:00` | every day at 16:00 local time (for example after a market closes at 15:00) |
| `daily 02:00,16:00` | twice a day |
| `hourly`, `hourly :30` | every hour |
| `every 6h`, `every 30m` | from midnight on |

- Times are the **local time** of the computer. In a zone without daylight saving (such as Nepal, +05:45), `16:00` stays 16:00 all year. On a VPS set to UTC, write the UTC time: `daily 10:15` for 16:00 in Nepal.
- Every database of the data folder and `_system` (users and audit log) are backed up. Each backup is read back and checked, as in chapter 9.
- **The backup does not stop the server.** It waits for an open transaction to end (at most a few seconds), writes a checkpoint, then copies the files while reads and writes go on. The test `test_protection` writes rows during a scheduled backup to check this.
- `--backup-copy <dir>`: after each backup, a second copy in another folder, best on another disk. KDB checks every block and log checksum of the copy by reading it back from that disk. A failed copy is reported (`COPY FAILED`) and the backup itself still counts.
- Old backups go by `--keep-daily 7 --keep-weekly 4`, in both folders.
- `--backup-warn-hours 26`: when a database's newest good backup is older, the log says `WARNING: the last good backup of 'x' is 30 hours old ...` once an hour. Watch for it (`journalctl -u kdb | grep WARNING`).
- The console's health panel shows the schedule, the next backup and a `(!)` when the last one failed. `/api/info` has the full status in `backup_schedule`.

---

## Part D: rights on tables

The roles of chapter 16 give rights on a whole database. Table rights change that for one table:

```sql
CREATE USER app WITH PASSWORD 'App-password-long-42';
GRANT write ON DATABASE shop TO app;
REVOKE UPDATE, DELETE ON TABLE ledger FROM app;      -- the ledger only grows

CREATE USER auditor WITH PASSWORD 'Auditor-password-17';
GRANT SELECT ON TABLE ledger TO auditor;             -- reads one table, nothing else
SHOW USERS;
```

```text
name    | role  | grants     | created | changed | table_grants                     | two_factor
--------+-------+------------+---------+---------+----------------------------------+-----------
app     | none  | shop=write | ...     | ...     | shop.ledger: -UPDATE -DELETE     | false
auditor | none  | NULL       | ...     | ...     | shop.ledger: +SELECT             | false
```

Now `app` gets `DELETE on table 'ledger' was revoked for user 'app' (REVOKE DELETE ON TABLE ledger)` (HTTP 403, SQLSTATE `42501`), and `auditor` can read `ledger` but gets 403 for every other table, also inside subqueries and joins.

| Statement | Does |
|---|---|
| `GRANT SELECT, INSERT, UPDATE, DELETE, ALL ON TABLE t TO u` | adds rights on one table of the current database |
| `REVOKE ... ON TABLE t FROM u` | takes rights away on that table, even when the role has them |
| `GRANT DEFAULT ON TABLE t TO u` | the role decides again for that table |

- Rights are checked **once per statement**, before it runs (and before the result cache). There is no cost per row.
- They count for `/exec`, `/exp`, `/cursor`, the line protocol (`INSERT`) and the PostgreSQL port.
- `DROP TABLE` removes the table rights of that table; `RENAME TABLE` moves them. A new table with an old name does not get old rights.
- `CALL` and triggers run their statements without table rights (only admins create procedures and triggers).
- A view is a table for rights: `GRANT SELECT ON TABLE cheap_prices TO u` lets `u` read what the view shows.
- **`REVOKE <role> ON DATABASE`** takes away exactly that grant. `REVOKE read ON DATABASE shop FROM app` does **not** remove a `write` grant; it says `user 'app' keeps role write ... Nothing was revoked`. Use `REVOKE write` or `REVOKE ALL`.

---

## Part E: stronger logins

### The password rule

A new password of a database user must have **at least 12 characters** (letters of any language count as one each) and must not be the user name. Old passwords keep working. For programs, use 20 or more random characters.

### Two-factor login

For people who use the console (especially admins):

```sql
ALTER USER admin ENABLE TOTP;
```

```text
user  | otpauth_uri                                                                                 | secret
------+---------------------------------------------------------------------------------------------+---------------------------------
admin | otpauth://totp/KDB:admin?secret=JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP&issuer=KDB&algorithm=SHA1&... | JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP
two-factor login is on for user 'admin': add the otpauth URI (or the secret) to an authenticator app now; it is shown only once
```

Put the secret into Google Authenticator, Microsoft Authenticator, Aegis or 1Password **now** (it is shown only once). From then on:

- The console's login box asks for the **6-digit code** after a right password.
- Programs send it to `POST /api/login` as `{"user": "admin", "password": "...", "code": "492039"}`.
- A code works once. Wrong codes count as failed logins (after 5, the address must wait).
- HTTP Basic and the PostgreSQL port cannot ask for a code, so they refuse this user. Programs use their own users without two-factor login.
- `ALTER USER admin DISABLE TOTP` turns it off. A lost phone: stop the server and run `kdb user reset-2fa admin`.

### Other login protection

- **Lockouts** (5 failures for a user from one address) are in the audit log as `lockout`.
- **A new token for every login.** When a login request still carries an old login (cookie or Bearer token), the old one ends. A token somebody planted in a browser before the login is worthless afterwards.

---

## Part F: mistakes

### UPDATE or DELETE without WHERE

```sh
kdb serve ... --safe-updates
```

```sql
UPDATE accounts SET balance = 0;
```

```text
error: safe updates are on: an UPDATE without WHERE would change every row of 'accounts'. Add a WHERE (WHERE true changes every row on purpose), or turn safe updates off for this session: SET safe_updates = off
```

Each session can switch: `SET safe_updates = off` (or on) in SQL, `X-KDB-Safe-Updates: off` over HTTP, `SET safe_updates = off` on the PostgreSQL port.

### A read-only database

```sql
ALTER DATABASE market_2025 SET READ ONLY;
```

Now every change of `market_2025` is refused (`the database is read-only (...)`, HTTP 403, SQLSTATE `25006`); reads, backups and checks work. The setting is kept in the data folder and holds after a restart. `ALTER DATABASE market_2025 SET READ WRITE` undoes it. A read-only database cannot be dropped.

`kdb serve --read-only` makes the whole server read-only: all databases, no new databases, no user changes. Use it for a report server that works on a copy of the data.

### DROP TABLE by mistake

`DROP TABLE` does not remove the rows at once. The table goes into the **trash** for 7 days:

```sql
DROP TABLE ledger;
SHOW DROPPED TABLES;
UNDROP TABLE ledger;
```

```text
table 'ledger' dropped; UNDROP TABLE ledger brings it back within 7 days
name   | dropped                  | removed_after            | rows  | stored_as
-------+--------------------------+--------------------------+-------+------------------------------
ledger | 2026-09-12T10:50:12.004Z | 2026-09-19T10:50:12.004Z | 48210 | _dropped_1789217412004_ledger
table 'ledger' is back, with 48210 row(s)
```

- Dropping takes no time: nothing is copied. A new table and indexes with the same names can be made at once (app migrations keep working).
- `UNDROP TABLE` brings back the newest table of that name with its rows and indexes (not its table rights).
- After `--trash-days` (7) the server removes it for good. `DROP TABLE _dropped_..._ledger` removes one at once.
- A table with named `UNIQUE` or `PRIMARY KEY` constraints (PostgreSQL style) is dropped for good at once for now.
- `DROP DATABASE` already moved whole databases to `data/_trash` (chapter 1); that stays.

---

## Part G: encryption of the files

Not built yet. Today whoever can read the data folder or a backup can read the data: protect them with file permissions (chapter 16) and keep backups private. The plan (AES-256-GCM per block with AES-NI, a key file or the OS key store, the log and backups encrypted too, key rotation, about 3-8% slower cold reads and no change for queries on loaded data) is in docs/design/encryption-at-rest.md. It comes after the versioning work, because it changes the bytes on disk.

---

## VPS checklist

Add this to the checklist of chapter 16:

| Check | Why |
|---|---|
| `--backup-schedule "daily 10:15"` (16:00 in Nepal, +05:45, on a UTC VPS) and `--backup-copy` on a second disk or mounted storage | backups happen even when you forget |
| `journalctl -u kdb | grep -E "WARNING|FAILED"` in a daily mail or monitor | a broken backup is noticed |
| `--statement-timeout 30s`, `--max-result-memory 256MB` on a 1-2 GB VPS | one report cannot freeze the app |
| `--max-queries-per-user` above your app's pool size | a loop in a script cannot take every thread |
| `ALTER TABLE ... SET AUDIT ON` for accounts, ledger, orders, portfolio | every money change has who and when |
| `REVOKE UPDATE, DELETE ON TABLE ledger FROM app` | even a bug in the app cannot rewrite history |
| `ALTER USER <admin> ENABLE TOTP` for every person | a stolen password is not enough |
| `--safe-updates` | no `UPDATE` without `WHERE` by accident |
| `SHOW AUDIT WHERE event IN ('lockout', 'denied')` now and then | see who tries |
| old years: `ALTER DATABASE ... SET READ ONLY` | closed books stay closed |

Example `systemd` line:

```ini
ExecStart=/usr/local/bin/kdb serve --data-dir /srv/kdb/data --backups /srv/kdb/backups --backup-schedule "daily 10:15" --backup-copy /mnt/backup/kdb --statement-timeout 30s --max-result-memory 256MB --safe-updates --audit-keep-days 2000
```

---

## What it costs

Measured on the development PC (Intel i9-14900HX, Windows 11), same data, runs mixed so that other work on the PC hits both sides. "On" is `kdb serve` with its defaults (60 s timeout, memory and group limits, 32 statements per user); "off" is the same program with `--statement-timeout 0 --max-result-memory 0 --max-groups 0 --max-queries-per-user 0`.

| Test | Off (or before) | On (after) |
|---|---|---|
| line protocol, 8 clients x 200,000 rows | before: 2.21, 2.13, 1.96 million rows/s | 2.21, 2.26, 2.16 million rows/s |
| `SELECT count(*), sum(volume)` over 1.1 million rows, no result cache (server time, 3 runs) | 153 µs | 154 µs |
| `GROUP BY symbol`, no cache | 1,384 µs | 1,306 µs |
| `LATEST ON`, no cache | 394 µs | 385 µs |
| 5,000 rows to JSON, no cache | 1,605 µs | 1,593 µs |
| `SELECT count(*)+sum`, with the result cache (round trip, 1,000 runs, 3 times) | 0.12, 0.11, 0.12 ms | 0.12, 0.11, 0.11 ms |
| `kdb_bench` weekly candles of all 527 symbols (first run) | before: 354, 380 ms | 335, 348 ms |
| 100 INSERTs of 1,000 rows into an accounts table | audit off: 1.40, 1.46 s | `SET AUDIT ON`: 1.61, 1.92 s |

The differences are smaller than the noise between two runs. Only `SET AUDIT ON` costs something: about 15-30% on the writes of that table.

- **No per-row cost** in scans: the timeout flag is read once per 16,384 rows in the row engine and once per batch in the column engine; a watchdog thread sets it, so the check never reads the clock.
- Tables without `SET AUDIT ON`: one `if` per commit.
- Table rights: nothing for users without table rights; one short walk over the statement for users with them.
- `SHOW AUDIT` and the audit writer run on their own thread, never in the request.

---

## Limits

- Security events are written every 200 ms: a crash can lose the events of that moment (data-change audit rows are never lost: same transaction).
- A server on one folder path (`kdb serve D:\kdb\market`) has no security audit log (it has no `_system`). Data-change audit works there.
- The audit log is not signed: a person who can change the data files can change it too. Keep the data folder private and copy backups off the server.
- Table rights: no column rights (masking of columns in results is not built), no row rights. `CALL` and triggers ignore table rights.
- Two-factor login is only for HTTP logins (console, `/api/login`). HTTP Basic and the PostgreSQL port refuse two-factor users.
- The statement timeout does not stop a single very long step that has no rows in between (for example sorting one huge result); memory limits usually stop such a query first.
- `kdb sql`, `kdb shell` and library apps have no timeouts or limits.
- The trash keeps tables with named `UNIQUE`/`PRIMARY KEY` constraints only after the constraint work supports renaming them; such tables are dropped for good now.
- Older KDB programs refuse a database with audited tables, and a data folder with table rights, two-factor users or read-only settings (they would ignore them). Update every `kdb` program first.
- No encryption of the files yet (Part G).

---

Next: [Known limitations](known-limitations.md)
