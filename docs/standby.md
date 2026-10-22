# Standby server: a live read-only copy (--standby-of, kdb promote)

> A second KDB server that copies every database of a primary from its log, a moment behind, and serves reads.

- Category: Backup, check, repair, restore
- Keywords: standby, hot standby, replica, read replica, replication, failover, --standby-of, --standby-token, KDB_STANDBY_OF, KDB_STANDBY_TOKEN, GET /api/wal, api/wal, GET /api/standby, api/standby, in_hot_standby, wal, log shipping, lsn, kdb promote, POST /api/promote, api/promote, promote, failover, lag, replication lag, kdb_standby_lag_seconds, 25006, read_only_sql_transaction
- See also: [Backup, check, repair and restore](backup-and-safety.md), [Change stream and live subscriptions: changes('t'), GET /api/changes, GET /api/subscribe](change-stream.md), [kdb serve](cli-serve.md), [Databases and the data folder](databases.md)

A **standby** is a second `kdb serve` that keeps a copy of every database of another server, the **primary**. It reads the primary's log (the WAL) over HTTP and applies each transaction in order, so the copy is a moment behind the primary. Users of the standby can read; every change is made on the primary.

Use it to keep reports and dashboards off the primary, and to have a second copy on another computer.

<a id="start"></a>

## Start a standby

```bash
# the primary: any kdb serve with a token
kdb serve --data-dir D:/kdb-data --token <secret>

# the standby: another folder (another computer), pointing at the primary
kdb serve --data-dir E:/kdb-copy --standby-of http://primary:9900 --standby-token <secret>
```

| Setting | Meaning |
|---|---|
| `--standby-of URL` (`KDB_STANDBY_OF`) | the primary's address, `http://host:port` or `https://host:port` |
| `--standby-token T` (`KDB_STANDBY_TOKEN`) | what the standby sends to the primary: the primary's `--token`, or an API token of an admin |
| `KDB_STANDBY_POLL_MS` | how often an up-to-date standby asks again (default 100 ms) |

The standby copies:

| What | How |
|---|---|
| rows: INSERT, UPDATE, DELETE, loads | as logged, in commit order, one whole transaction at a time |
| schema changes: CREATE, ALTER, DROP TABLE, indexes, views | as logged |
| partitions dropped by a TTL or `DROP PARTITION` | as logged by the primary |
| new and dropped databases | a new one is copied; a dropped one goes to `_trash` |
| users, rights and API tokens (`_system`) | as logged; logins on the standby use them |

<a id="read-only"></a>

## Read-only

On a standby every change is refused with `this server is a standby of http://...: it only reads; make changes on the primary`. That covers INSERT, DDL, `CREATE DATABASE` and user statements.

| Where | Answer |
|---|---|
| `POST /exec` | HTTP 403, `"sqlstate": "25006"` |
| `POST /write`, `POST /imp` | HTTP 403, `"sqlstate": "25006"` (before the body is read) |
| PostgreSQL port | error `25006` (read_only_sql_transaction), as on a PostgreSQL hot standby |

Timers, TTL checks, trigger jobs, materialized view refreshes and the audit log do not run there: the primary runs them, and their results come in its log.

PostgreSQL drivers see `in_hot_standby = on` and `default_transaction_read_only = on`, so `target_session_attrs=read-only` picks the standby.

<a id="status"></a>

## How far is it?

The lag, over every database:

| Where | Fields |
|---|---|
| `GET /api/stats` (any login) | `standby.lag_lsn`, `standby.lag_bytes`, `standby.lag_seconds`, `standby.connected` |
| `GET /metrics` | `kdb_standby`, `kdb_standby_connected`, `kdb_standby_lag_lsn`, `kdb_standby_lag_bytes`, `kdb_standby_lag_seconds`, `kdb_standby_applied_transactions_total` |
| the console | the status bar: `Standby (read-only) - lag 0.1 s` |

`lag_lsn` counts the log entries the primary has and the copy has not applied. `lag_bytes` is those entries in bytes, estimated from the bytes per entry copied so far. `lag_seconds` is how long the oldest of them has waited; when the primary cannot be reached, at least the time since it last answered. All three are 0 when the copy is up to date.

`GET /api/standby` (server admins) on the standby gives the detail:

| Field | Meaning |
|---|---|
| `lag_lsn`, `lag_bytes`, `lag_seconds` | as above |
| `promoted` | `kdb promote` ran: this server is a primary now |
| `connected`, `error` | the last request to the primary worked, or why not |
| `databases[].applied_lsn` | the last LSN of the primary this copy holds |
| `databases[].primary_lsn`, `behind_lsn` | the end of the primary's log when last asked, and the difference |
| `databases[].last_commit_ms` | when the last applied transaction committed on the primary |
| `databases[].received_bytes` | log bytes copied since the standby started |
| `databases[].error` | why this database stopped copying |

<a id="promote"></a>

## Promote: the standby becomes the primary

When the primary is lost, make the standby the primary:

```bash
kdb promote --url http://standby:9900 --token <secret>
```

That sends `POST /api/promote` (server admins). The standby stops copying (a transaction being applied ends first), and from that moment:

| What | After the promote |
|---|---|
| writes (HTTP, `/write`, `/imp`, PostgreSQL) | taken; the log goes on from the last LSN copied |
| PostgreSQL | new connections see `in_hot_standby = off` |
| TTL checks, sweeps, refreshes, trigger jobs, timers | run here (the Timers page shows up after the next restart) |
| `CREATE DATABASE`, users | allowed |
| `GET /api/standby` | `"promoted": true` |

A second promote answers 409. A server that is no standby answers 409 too.

Before you promote:

- Make sure the old primary is really gone, or stop it. Two primaries take different writes, and the copies cannot be joined again.
- Look at `lag_lsn`: what the primary committed and the standby had not copied is lost.

After the promote, start the server again **without** `--standby-of` (and drop `KDB_STANDBY_OF`); with it, it would be a standby again. To get a new standby, start one against the new primary. The old primary's folder cannot follow the new one: copy it again from a backup of the new primary.

<a id="seed"></a>

## Starting from a backup

From an empty data folder the standby copies each database from the start of its log. That works only while the primary still keeps its whole log (`ALTER DATABASE ... SET WAL_ARCHIVE`). Otherwise start the standby on a copy of the primary's data: a restored backup, or the data folder copied while the primary was stopped. The standby asks for the log from where that copy ends.

When the primary no longer keeps the log a database needs, or the two no longer fit (the primary's database was dropped and made again, or restored), that database stops copying and `databases[].error` says so: copy it again from a backup of the primary. The other databases go on. Equal LSNs are not trusted alone: with each request the standby sends the commit time of the last transaction it holds, and the primary checks that its own log has that same transaction there. A database the primary cannot open for a moment is left as it is on the standby, never dropped.

<a id="api-wal"></a>

## GET /api/wal

What the standby reads. Server admins only: it holds every row, and the users' password hashes.

| Request | Answer |
|---|---|
| `GET /api/wal` | the databases and where each one's log ends (`format=tsv`: one line each; `-` or `null` when the primary cannot open it right now) |
| `GET /api/wal?db=x&from=<lsn>[&max_bytes=n][&wait=ms][&prev_ms=t]` | the committed transactions of `x` from LSN `from` on, binary; `410` when that part of the log is gone; `409` when the transaction at LSN `from - 1` did not commit at `prev_ms` (another log) |

Use HTTPS (`--tls-cert`) between computers: the log is sent as it is.
