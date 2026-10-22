# pg_stat_activity and pg_stat_statements

> See who is connected and what runs now (pg_stat_activity, query_activity(), GET /api/sessions), stop a statement or close a connection (pg_cancel_backend, pg_terminate_backend, CANCEL QUERY, DELETE /api/sessions/<pid>), close idle and vanished clients (idle_session_timeout, tcp_keepalives_*), and see the totals of every statement shape (pg_stat_statements).

- Category: Postgres protocol
- Keywords: query\_activity, CANCEL QUERY, cancel\_query, pg\_sleep, idle\_session\_timeout, client\_connection\_check\_interval, tcp\_keepalives\_idle, tcp\_keepalives\_interval, tcp\_keepalives\_count, keepalive, 57P01, 57P05, 57014, /api/sessions, CLIENT LIST, CLIENT KILL, kill session, pg\_stat\_activity, pg\_stat\_statements, pg\_stat\_statements\_reset, pg\_cancel\_backend, pg\_terminate\_backend, pg\_backend\_pid, running queries, running statements, idle in transaction, wait\_event, wait\_event\_type, kill query, kill connection, terminate connection, statement statistics, query statistics, slow statements, query totals, --stat-statements, KARELADB\_STAT\_STATEMENTS, queryid, mean\_exec\_time, total\_exec\_time, 42501
- See also: [Protection - timeouts, limits, safe updates, read-only (cancel)](protection.md#cancel), [EXPLAIN (explain-analyze)](explain.md#explain-analyze), [Health, info, check and backup over HTTP (slow-queries)](http-server-info.md#slow-queries), [Monitor panel (memory, processor, caches)](console-monitor.md), [PostgreSQL protocol (port 8832)](postgres-protocol.md), [Sessions and cursors over HTTP](http-sessions-and-cursors.md)

These are the views and functions PostgreSQL tools use to watch a server. They work the same over the [Postgres port](postgres-protocol.md) and over HTTP (`POST /exec`), and they show both kinds of client.

| View or function | What it gives |
|---|---|
| `pg_stat_activity` | one row per connection and HTTP session, and per HTTP request while it runs |
| `pg_cancel_backend(pid)` | stops the statement that backend runs |
| `pg_terminate_backend(pid)` | also closes its connection or HTTP session |
| `pg_backend_pid()` | the pid of your own connection (or HTTP request) |
| `query_activity()`, `CANCEL QUERY id`, `cancel_query(id)` | QuestDB's names: the running statements, and stopping one of them |
| `pg_sleep(seconds)` | waits; a cancel or a timeout stops it at once |
| `GET /api/sessions`, `DELETE /api/sessions/<pid>` | the same list as JSON, and closing one (Redis' `CLIENT LIST` and `CLIENT KILL`) |
| `pg_stat_statements` | calls, times and rows of every statement shape since the server started |
| `pg_stat_statements_reset()` | starts the totals again |
| `pg_locks`, `pg_blocking_pids(pid)` | the table locks held and waited for, with the same pids; who a waiting pid waits for ([LOCK TABLE and pg_locks](transactions.md#lock-table)) |

`kareladb sql` and `kareladb shell` have no server around them: there the views are empty and the functions answer `false`.

<a id="pg-stat-activity"></a>

## pg_stat_activity

Syntax:

```sql
SELECT pid, usename, application_name, client_addr, state, wait_event_type, wait_event, query_start, query
FROM pg_stat_activity
[WHERE pid <> pg_backend_pid()]
```

The columns are PostgreSQL 14's, in its order.

| Column | Meaning |
|---|---|
| `pid` | the backend's number. A Postgres connection's is its `pg_backend_pid()` (the key of its cancel requests). An HTTP request without a session gets one of its own, from 1073741824 up |
| `datname`, `usename` | the database and the user (for a login without KarelaDB users: the login name) |
| `application_name` | the Postgres `application_name`, or the HTTP `User-Agent` |
| `client_addr` | the client's address (`client_port` and `client_hostname` are NULL) |
| `backend_start`, `xact_start`, `query_start`, `state_change` | when the connection opened, its transaction began, its statement began, its state last changed |
| `state` | `active` (a statement runs), `idle`, `idle in transaction`, `idle in transaction (aborted)` |
| `wait_event_type`, `wait_event` | what an active statement waits for: `Lock` / `relation` (another statement's tables), `Lock` / `tuple` (a row another transaction locked), `Lock` / `advisory`; an idle Postgres connection shows `Client` / `ClientRead`. NULL when not waiting |
| `query` | the running statement, or the last one when idle (up to 1024 characters) |
| `backend_type` | `client backend` |

- **Rights:** an admin (and the `--token`) sees every row in full. Other users see every row, but only their own rows' details: for another user's backend `query` is `<insufficient privilege>` and the times, state, address and wait columns are NULL, as in PostgreSQL.
- **Notes:**
  - An HTTP session ([POST /session](http-sessions-and-cursors.md)) is one backend from its start to its close. An HTTP request without a session is listed only while it runs.
  - `datid` and `usesysid` are the oids `pg_database` and `pg_roles` show; use `datname` and `usename`.
  - The same list, as JSON, is in [`GET /api/stats`](http-server-info.md) (`running`), which the console's Monitor panel shows.

**Example: Without a server (kareladb sql) nobody else is connected**

```sql
SELECT count(*) AS others FROM pg_stat_activity WHERE pid <> pg_backend_pid();
```

Result:

| others (LONG) |
|---|
| 0 |

(1 row)

<a id="pg-cancel-backend"></a>

## pg_cancel_backend and pg_terminate_backend

Syntax:

```sql
pg_cancel_backend(pid)
pg_terminate_backend(pid [, timeout])
```

`pg_cancel_backend` stops the statement the backend runs now; the connection stays. `pg_terminate_backend` also closes it: a Postgres connection gets `FATAL: terminating connection due to administrator command` (SQLSTATE `57P01`) and is closed at once (an open transaction is rolled back), an HTTP session is closed as [DELETE /session](http-sessions-and-cursors.md) closes it.

- **Returns:** `true` when a backend has that pid (also when it is idle and there was nothing to stop), `false` when none has, NULL for a NULL pid.
- **Rights:** an admin may stop every backend; other users only their own. Otherwise: `must be a member of the role whose query is being canceled or member of pg_signal_backend` (SQLSTATE `42501`, HTTP 403).
- **Notes:**
  - The stopped statement gets `canceling statement due to user request` (SQLSTATE `57014`, HTTP 408), as with a [cancel request](protection.md#cancel). It stops within milliseconds: the scans look at the stop flag once per batch of rows.
  - `timeout` is accepted and not waited for.
  - Over TLS a terminated idle connection is closed without the `57P01` message (two threads must not write one TLS session).

**Example: No backend has this pid**

```sql
SELECT pg_cancel_backend(12345) AS cancelled, pg_terminate_backend(12345) AS terminated;
```

Result:

| cancelled (BOOL) | terminated (BOOL) |
|---|---|
| false | false |

(1 row)

Syntax:

```sql
-- Stop everything user etl has run for more than 5 minutes
SELECT pid, pg_cancel_backend(pid) FROM pg_stat_activity
WHERE usename = 'etl' AND state = 'active' AND query_start < now() - INTERVAL '5 minutes';

-- Close the connections left idle in a transaction
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle in transaction';
```

<a id="query-activity"></a>

## query_activity, CANCEL QUERY and cancel_query

Syntax:

```sql
SELECT query_id, worker_id, worker_pool, username, query_start, state_change, state, is_wal, query
FROM query_activity()
CANCEL QUERY query_id
cancel_query(query_id)
```

QuestDB's way to see and stop running statements. `query_activity()` has one row per statement running now, over HTTP and the Postgres port, itself included.

| Column | Meaning |
|---|---|
| `query_id` | the statement's number: new for every statement, never used twice while the server runs |
| `worker_id` | the `pid` of its connection or request, as `pg_stat_activity` shows it |
| `worker_pool` | `pgwire` (the Postgres port) or `http` |
| `username`, `query` | who runs it, and its text (up to 1024 characters) |
| `query_start`, `state_change` | when it started |
| `state` | `active`, or `cancelled` while a stopped statement winds down |
| `is_wal` | always `false`: KarelaDB applies a commit before it returns, so it has no WAL apply jobs |

- **Returns:** `CANCEL QUERY` answers `true` or fails with `query to cancel not found in registry [id=...]` (SQLSTATE `42704`) when no statement runs with that id. `cancel_query(id)` answers `true` when it stopped one, `false` when none runs with that id, NULL for NULL.
- **Rights:** an admin sees and stops every statement; other users see only their own and may stop only their own (otherwise SQLSTATE `42501`, HTTP 403).
- **Notes:** the stopped statement ends with `canceling statement due to user request` (`57014`); its connection stays. `pg_stat_activity`'s own `query_id` column is PostgreSQL's (a number for the statement's shape) and stays NULL.

**Example: Without a server (kareladb sql) nothing else runs**

```sql
SELECT count(*) AS running FROM query_activity();
```

Result:

| running (LONG) |
|---|
| 0 |

(1 row)

**Example: No statement runs with this id**

```sql
SELECT cancel_query(123456) AS cancelled;
```

Result:

| cancelled (BOOL) |
|---|
| false |

(1 row)

Syntax:

```sql
-- Stop every statement that has run for more than a minute
SELECT query_id, cancel_query(query_id) FROM query_activity()
WHERE query_start < now() - INTERVAL '1 minute' AND query NOT LIKE '%query_activity%';
```

<a id="pg-sleep"></a>

## pg_sleep

Syntax:

```sql
pg_sleep(seconds)
```

Waits that many seconds (a fraction is fine), then returns an empty value, as PostgreSQL's `void`. A cancel, `pg_terminate_backend`, `CANCEL QUERY` or the [statement timeout](protection.md) stops it within about 10 ms. NULL or 0 returns at once.

**Example: A short wait**

```sql
SELECT pg_sleep(0.01) IS NOT NULL AS waited;
```

Result:

| waited (BOOL) |
|---|
| true |

(1 row)

<a id="idle-clients"></a>

## Idle and vanished clients

Syntax:

```sql
SET idle_session_timeout = '10min'             -- 0 = off (the default)
SET client_connection_check_interval = '5s'    -- 0 = off (the default)
SET tcp_keepalives_idle = 60                   -- seconds; 0 = the server's
SET tcp_keepalives_interval = 10
SET tcp_keepalives_count = 5
kareladb serve --tcp-keepalives-idle 60 --tcp-keepalives-interval 10 --tcp-keepalives-count 5
```

PostgreSQL 14's settings, for one Postgres connection.

| Setting | What it does |
|---|---|
| `idle_session_timeout` | A connection that waits longer than this for its next query, **outside** a transaction, is closed with `FATAL: terminating connection due to idle-session timeout` (SQLSTATE `57P05`). An open `BEGIN` counts under `idle_in_transaction_session_timeout` instead ([idle transactions](transactions.md#idle-timeout)). Milliseconds as a number, or `'2s'`, `'5min'`. |
| `client_connection_check_interval` | While a statement runs, the server looks this often whether the client is still there, and stops the statement when it went away, so a long query does not run on for nobody. At most about 5 times a second. |
| `tcp_keepalives_idle`, `_interval`, `_count` | TCP keepalive of this connection: seconds without traffic before the first probe, seconds between probes, probes before the connection is given up. `SHOW` reads the value back from the socket. `0` = the server's (the `--tcp-keepalives-*` flags, `KARELADB_TCP_KEEPALIVES_*`, `tcp_keepalives_*` in `kareladb.conf`), else the system's. |

- **Notes:**
  - Keepalive is on for every HTTP and Postgres connection, as in PostgreSQL, so a client that vanished without closing (a laptop shut, a NAT that forgot it) is noticed and its locks are given back. The server flags set the timings for both ports.
  - A wrong value is refused with SQLSTATE `22023` and changes nothing. Idle and interval go up to 32767 s, the count up to 127.
  - The connections the server closed are in the [activity log](http-server-info.md) (`GET /api/activity`, kind `session`).
  - These are settings of the Postgres port. `SHOW idle_session_timeout` there answers `0` until it is set, then as PostgreSQL writes it (`2s`, `1min`).

<a id="api-sessions"></a>

## GET /api/sessions and DELETE /api/sessions/<pid>

Syntax:

```sql
GET /api/sessions
GET /api/activity?sessions=1
DELETE /api/sessions/<pid>
```

`GET /api/sessions` is `pg_stat_activity` as JSON: every Postgres connection, HTTP session and running HTTP request, with `pid`, `protocol` (`pg` or `http`), `user`, `database`, `application_name`, `client_addr`, `state`, `wait_event_type`, `wait_event`, `query`, the times in Unix milliseconds (`backend_start_ms`, `xact_start_ms`, `query_start_ms`, `state_change_ms`) and `query_id` (the running statement's, for `CANCEL QUERY`; null when idle). `GET /api/activity?sessions=1` adds the same list to the activity log's answer, so one poll shows what happened and what runs now.

`DELETE /api/sessions/<pid>` is `pg_terminate_backend(<pid>)`: the statement stops, an open transaction rolls back, a Postgres client gets `57P01`. It answers `{"pid":..,"terminated":true}`, `404` when no session has that pid, `403` when it is another user's and you are not an admin, `400` for a pid that is not a number.

Syntax:

```sql
curl -H "Authorization: Bearer $KARELADB_TOKEN" http://localhost:9900/api/sessions
curl -X DELETE -H "Authorization: Bearer $KARELADB_TOKEN" http://localhost:9900/api/sessions/42
```

<a id="pg-stat-statements"></a>

## pg_stat_statements

Syntax:

```sql
SELECT query, calls, total_exec_time, mean_exec_time, max_exec_time, rows
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10
pg_stat_statements_reset([userid, dbid, queryid])
kareladb serve --stat-statements on|off          (env KARELADB_STAT_STATEMENTS; default on)
```

The totals of every statement **shape** the server ran: the statement with each literal replaced by `$1`, `$2`, ..., so `WHERE id = 5` and `WHERE id = 7` count together. Spacing, comments and the case of words do not make a new shape. No extension needs to be created.

| Column | Meaning |
|---|---|
| `queryid` | the shape's number: the same for every user |
| `query` | the shape, as its user first sent it (up to 1024 characters) |
| `calls`, `rows` | how often it ran, and the rows it returned or changed in all |
| `total_exec_time`, `min_exec_time`, `max_exec_time`, `mean_exec_time`, `stddev_exec_time` | milliseconds |
| `usename`, `datname` | KarelaDB's own columns: the user and the database (`userid` and `dbid` are the same oid for everyone) |
| `plans`, `*_plan_time`, `shared_blks_*`, `local_blks_*`, `temp_blks_*`, `blk_*_time`, `wal_*` | PostgreSQL's columns KarelaDB does not count: 0 |

- **Returns:** one row per user, database and shape.
- **Notes:**
  - Only statements that ended without an error count, as in PostgreSQL. The console's own polling does not count.
  - One HTTP request is one statement, even when it holds several.
  - At most 5000 shapes are kept (PostgreSQL's `pg_stat_statements.max`). When a new one comes, the 5% least-called make room. The totals are kept in memory: a restart starts them again. Statements a procedure or trigger runs count in the `CALL` or write that ran them (`pg_stat_statements.track` is `top`).
  - It costs a few hundred nanoseconds per statement: the first 16 KB of the text are read once for the shape. `--stat-statements off` switches it off; the view is then empty.
  - Other users' shapes show `<insufficient privilege>` instead of the text to a user who is not an admin.
  - `pg_stat_statements_reset()` needs an admin. With a `queryid` (the third argument, `0` = all) only that shape starts again.

**Example: Without a server (kareladb sql) nothing is counted**

```sql
SELECT count(*) AS shapes FROM pg_stat_statements;
```

Result:

| shapes (LONG) |
|---|
| 0 |

(1 row)
