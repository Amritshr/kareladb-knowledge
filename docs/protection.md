# Protection - timeouts, limits, safe updates, read-only

> Stop slow statements (timeout and cancel), limit the memory of one query and the statements of one user, refuse UPDATE or DELETE without WHERE, and make a database read-only.

- Category: Users & security
- Keywords: protection, statement timeout, statement\_timeout, timeout, cancel, cancel query, stop query, kill query, CancelRequest, 57014, query\_canceled, X-KDB-Request-Id, X-KDB-Statement-Timeout, X-KDB-Safe-Updates, memory limit, too many rows, too many groups, 54000, max\_result\_memory, max\_groups, safe updates, safe\_updates, read-only, READ, ONLY, WRITE, --statement-timeout, --max-result-memory, --max-groups, --max-queries-per-user, --rate-limit-ip, --rate-limit-user, rate limit, 53400, --safe-updates, --read-only, 408, 413, 429, 503, Retry-After, drain, --drain-timeout, graceful shutdown
- See also: [Keeping kdb serve safe](server-security.md), [Audit log](audit-log.md), [The trash - UNDROP TABLE](trash.md), [Table rights - GRANT ON TABLE](table-rights.md), [Two-factor login (TOTP)](two-factor-login.md), [Backups on a schedule](backup-schedule.md), [kdb serve](cli-serve.md), [PostgreSQL protocol (port 8832)](postgres-protocol.md), [Run SQL over HTTP (/exec, /exp)](http-exec.md)

These settings keep one bad query, one busy user or one typing mistake from hurting the server. They cost almost nothing: a running query looks at one flag every 16,384 rows, never at every row.

| Protection | Turn it on | Default of `kdb serve` |
|---|---|---|
| statement timeout | `--statement-timeout 30s`, `SET statement_timeout = '5s'`, `ALTER USER u SET statement_timeout = '2s'` | 60 s |
| cancel a running statement | Postgres cancel (pgx context, psql Ctrl+C), `DELETE /exec/<id>`, closing the HTTP connection | on |
| memory of one query | `--max-result-memory 1GB`, `--max-groups 5000000` | 1 GB, 5,000,000 groups |
| memory of the whole server | `--memory-limit 3GB` ([memory limit](cli-serve.md#memory-limit)) | 85% of a container's limit, else of the machine's memory |
| statements per user | `--max-queries-per-user 32` | 32 |
| requests per second | `--rate-limit-ip 50`, `--rate-limit-user 20` ([rate limits](#rate-limits)) | no limit |
| safe updates | `--safe-updates`, `SET safe_updates = on` | off |
| read-only | `--read-only`, `ALTER DATABASE x SET READ ONLY` | off |

`kdb sql`, `kdb shell` and programs that use the KDB library have no limits unless they set `DatabaseOptions`.

<a id="statement-timeout"></a>

## SET statement_timeout

Syntax:

```sql
kdb serve --statement-timeout 60s          (0 = no limit)
SET statement_timeout = '5s' | 5000 | 0 | DEFAULT
HTTP header:  X-KDB-Statement-Timeout: 5s
```

A statement (one request, or one Postgres query message) that runs longer is stopped. Nothing of a stopped change is written: an `UPDATE` stopped halfway changes no row.

| Value | Meaning |
|---|---|
| `'5s'`, `'500ms'`, `'2min'`, `5000` | the time; a plain number is milliseconds (like PostgreSQL) |
| `0` | no limit (only admins; others keep the server's limit) |
| `DEFAULT` | the server's `--statement-timeout` again |

- **Returns:** the error `canceling statement due to statement timeout (5 s); ...`. HTTP 408, PostgreSQL SQLSTATE `57014`.
- **Notes:**
  - A user who is not an admin can only make the limit shorter.
  - An admin can give one user their own limit, shorter or longer than the server's: `ALTER USER charts SET statement_timeout = '2s'` (see [Users and roles](users-and-roles.md#statement-timeout)). That limit then stands in for `--statement-timeout` for that user.
  - Over HTTP, `SET statement_timeout` lasts for the rest of the request (a shorter time counts at once, a longer one from the next request), or for the whole [HTTP session](http-sessions-and-cursors.md) when one is used. The header works for one request.
  - Waiting for another session's transaction (at most 5 s) counts too. A statement that waits for another writer (a long `CALL`, a trigger job, a load) stops at its time limit or when cancelled, within a few milliseconds, not when that writer is done.
  - The limit is checked inside every long loop: table scans, rows made by `generate_series`, joins, `GROUP BY`, window functions, `WHILE` loops and each statement of a `CALL`. A statement stops within a fraction of a second after its time is up. Sorting millions of rows, or freeing the memory they took, can add a little.
  - A `CALL` stopped inside its body says where first (`procedure 'p', line 4: canceling statement due to statement timeout ...`). It is still HTTP 408 and SQLSTATE `57014`.
  - [Triggers](triggers.md#time-limit) count toward the timeout of the statement that fired them. This is also true for `POST /write` and `POST /imp`: the header `X-KDB-Statement-Timeout` works there too, with the same rules. A trigger that runs too long gives `trigger <name>: statement timeout (<N> s)` (HTTP 408), and nothing of the request is written.

**Example: A time for the rest of this session** (sample data: sample)

```sql
SET statement_timeout = '5s';
SELECT count(*) FROM ochl_day;
```

Result:

`SET statement_timeout = '5s'`

```text
statement_timeout is 5 s for this session
```

`SELECT count(*) FROM ochl_day`

| count(*) (LONG) |
|---|
| 57 |

(1 row)

<a id="cancel"></a>

## Cancel a running statement

Syntax:

```sql
PostgreSQL:  CancelRequest (pgx: cancel the context; psql: Ctrl+C)
HTTP:        POST /exec with X-KDB-Request-Id: <id>, then DELETE /exec/<id>
HTTP:        close the connection (the browser or program gave up)
SQL:         SELECT pg_cancel_backend(pid)   (pid from pg_stat_activity; pg_terminate_backend also closes it)
```

Stops a statement that is running now.

- **Returns:** the stopped statement gets `canceling statement due to user request` (HTTP 408, SQLSTATE `57014`).
- **Notes:**
  - The Postgres port answers the CancelRequest of the connection's key only, like PostgreSQL.
  - When an HTTP client closes the connection, KDB notices it within a fifth of a second and stops the statement.
  - From SQL, over either port: find the statement in [pg_stat_activity](server-activity.md#pg-stat-activity) and stop it with [pg_cancel_backend](server-activity.md#pg-cancel-backend). Users may stop only their own; admins every one.

<a id="delete-exec"></a>

## DELETE /exec/<id>

Syntax:

```sql
DELETE /exec/<id>
```

Stops the `/exec` request that was sent with the header `X-KDB-Request-Id: <id>`. The id is chosen by the program (for example a random text).

- **Returns:** `{"request_id":"<id>","cancelled":true}`, or HTTP 404 when no request with that id is running (it finished).
- **Notes:** users may stop only their own requests; admins may stop every request. A second request with the same id while the first runs gets HTTP 409.

**HTTP: Nothing with this id is running**

```http
DELETE /exec/report-17
```

Response:

HTTP 404 (application/json)

```text
{"error": "no running request has the id 'report-17' (it may have finished)"}
```

<a id="memory-limits"></a>

## Memory limits

Syntax:

```sql
kdb serve --max-result-memory 1GB --max-groups 5000000        (0 = no limit)
```

Stops a query that would keep too much in memory: the rows of the result, rows waiting for `ORDER BY`, `DISTINCT` or window functions, and the groups of `GROUP BY`, `SAMPLE BY` and `LATEST ON`.

- **Returns:** `the query keeps too many rows in memory (about N MB; the limit is M MB, max_result_memory)` or `the query makes more than N groups (max_groups)`. HTTP 413, SQLSTATE `54000`.
- **Notes:** add a `WHERE` or a `LIMIT`, group by fewer columns, or read a big result in parts with a [cursor](cursors.md).
- **Big answers over the Postgres port** stream: a plain read (no `ORDER BY`, `GROUP BY`, `DISTINCT` or `OFFSET`) sends its rows while it reads them, so this limit does not stop it ([big answers stream](postgres-protocol.md#streaming)).
- **INSERT ... SELECT:** a plain copy (no `GROUP BY`, `DISTINCT`, window, `ORDER BY` or `LIMIT`) writes the rows while it reads them, so this limit does not stop it ([INSERT ... SELECT](insert.md#insert-select)).
- **GROUP BY and SAMPLE BY bigger than memory:** when the groups of a query need more than half of `--max-result-memory`, the rows of the groups that are not in memory yet go to sorted temporary files in the database folder (`_tmp/`) and are added up after the scan, one group at a time. The result is exactly the same, only slower. The files are removed when the query ends, fails or is cancelled, and when the database opens after a crash. One query may write at most 16 GB of them (`DatabaseOptions::max_spill_bytes`); past that it stops with `the GROUP BY needs more than N MB of temporary files (max_spill_bytes)`. A read-only database never writes them.

<a id="max-queries-per-user"></a>

## --max-queries-per-user

Syntax:

```sql
kdb serve --max-queries-per-user 32        (0 = no limit)
```

How many statements one user may run at the same time, over HTTP and the Postgres port together.

- **Returns:** HTTP 429 `user 'x' already runs 32 statements at the same time`; on the Postgres port SQLSTATE `55P03`.
- **Notes:** the `--token` and a server without users are not counted. A connection pool of your app normally stays below the limit.

<a id="rate-limits"></a>

## --rate-limit-ip and --rate-limit-user

Syntax:

```sql
kdb serve --rate-limit-ip 50 --rate-limit-user 20       (requests per second, 0 = no limit)
kdb.conf:  "rate_limit_ip": 50, "rate_limit_user": 20
env:       KDB_RATE_LIMIT_IP=50  KDB_RATE_LIMIT_USER=20
```

How many requests one client address, and one user, may send per second. Both are off unless set.

| Counts as one request | Where |
|---|---|
| one HTTP request to `/exec`, `/exp`, `/write`, `/imp`, `/cursor`, `/api/...` and `POST /api/login` | HTTP port |
| one Query message, or one Execute of a prepared statement | PostgreSQL port |

- **Returns:** HTTP `429` with a `Retry-After` header (whole seconds) and `rate limit: user 'charts' sends more than 20 requests per second (--rate-limit-user); try again in 1 s`. On the PostgreSQL port SQLSTATE `53400`. Nothing of the request runs. Inside `BEGIN ... COMMIT` on the PostgreSQL port the refusal is an error like any other: the transaction is aborted, and `COMMIT` rolls it back.
- **Notes:**
  - Each address and each user has a "bucket" of N requests that refills at N per second. A client may send N at once, then N per second on average.
  - The address limit is checked **before** the login, so a flood of wrong passwords is slowed too. The user limit is checked after it.
  - Requests from this computer (`127.x`) are never limited by address, so the console and health checks always get through. The `--token` (no user) is limited only by address.
  - The web console's files, `/health` and `/help` are not counted.
  - **Behind Docker's port mapping or a proxy**, every client may reach KDB from the same address. Then use `--rate-limit-user`, or set `--rate-limit-ip` high.
  - Read when the server starts. The Settings page shows the values in use.

<a id="safe-updates"></a>

## SET safe_updates

Syntax:

```sql
kdb serve --safe-updates
SET safe_updates = on | off
HTTP header:  X-KDB-Safe-Updates: on | off
```

Refuses `UPDATE` and `DELETE` without `WHERE`, the classic mistake that changes every row.

- **Returns:** `safe updates are on: an UPDATE without WHERE would change every row of 't'. Add a WHERE ...`
- **Notes:** `WHERE true` changes every row on purpose. `--safe-updates` makes it the start value of every session; a session can turn it off.

**Example: UPDATE without WHERE is refused** (sample data: sample; shows an error)

```sql
SET safe_updates = on;
UPDATE securities SET name = 'oops';
```

Result:

```text
safe updates are on for this session
```

Error: `safe updates are on: an UPDATE without WHERE would change every row of 'securities'. Add a WHERE (WHERE true changes every row on purpose), or turn safe updates off for this session: SET safe_updates = off`

<a id="read-only"></a>

## ALTER DATABASE ... SET READ ONLY

Syntax:

```sql
ALTER DATABASE <name> SET READ ONLY
ALTER DATABASE <name> SET READ WRITE
kdb serve --read-only
```

A read-only database takes no changes: `INSERT`, `UPDATE`, `DELETE`, DDL, `CALL`, the line protocol. `SELECT`, backups and checks work.

- **Returns:** `database 'x' is read-only now: only reads are allowed`. A refused change gets `the database is read-only (...)`, HTTP 403, SQLSTATE `25006`.
- **Notes:**
  - Needs a server admin. The setting is kept in the data folder (`_system`) and holds after a restart. A read-only database cannot be dropped.
  - `kdb serve --read-only` makes **every** database read-only, and refuses new databases and user changes. Good for a report server on a copy of the data.

**Example: Read-only, then writable again** (shows an error)

```sql
ALTER DATABASE demo SET READ ONLY;
SELECT count(*) FROM securities;
INSERT INTO brokers VALUES (99, 'New broker');
```

Result:

```text
database 'demo' is read-only now: only reads are allowed
```

Error: `the database is read-only (ALTER DATABASE demo SET READ ONLY; undo with SET READ WRITE): only reads are allowed`

<a id="drain"></a>

## Stopping the server without cutting requests off

Syntax:

```sql
kdb serve --drain-timeout 30s          (0 = do not wait; env KDB_DRAIN_TIMEOUT; 5s in the Docker image)
```

When the server is asked to stop (Ctrl+C, SIGTERM, `docker stop`), it does not drop what is running:

| Request | What happens |
|---|---|
| already running | finishes and gets its real answer, for up to `--drain-timeout`; then its connection closes |
| arrives during the stop | HTTP **503** with `Retry-After: 2`; nothing of it is run |
| still running after `--drain-timeout` | cancelled like a [statement timeout](#statement-timeout); nothing half-done is written |

- `GET /health` also answers 503 while the server stops, so a load balancer or Docker's health check stops sending traffic.
- The 503 body is `{"error": "the server is shutting down; send the request again in a moment"}`, and the server log shows the request with `503 0 ms (stopping)`.
- There is no drain when the server restarts itself ([POST /api/restart](http-server-info.md#api-restart)) or when its Windows console window is closed (Windows gives it only about 4 seconds). Running statements are cancelled at once then.
- The log says `stopping: running requests finished in N ms`, or `stopping: requests still running after 30s (--drain-timeout); they are cancelled`.
- Clients should send a request again after a 503, a refused connection or a connection closed before the reply. A cut-off `/write` or `/exec` is rolled back as a whole, so repeating it is safe.
- Keep the drain time below how long your service manager waits before it kills the process. See [Docker](install-packages.md#docker-stop).
