# Standby server: a live read-only copy (--standby-of, kareladb promote)

> A second KarelaDB server that copies every database of a primary from its log, a moment behind, and serves reads.

- Category: Backup, check, repair, restore
- Keywords: standby, hot standby, replica, read replica, replication, failover, streaming, long poll, KARELADB\_STANDBY\_WAIT\_MS, --standby-of, --standby-token, KARELADB\_STANDBY\_OF, KARELADB\_STANDBY\_TOKEN, GET /api/wal, api/wal, GET /api/standby, api/standby, in\_hot\_standby, wal, log shipping, lsn, kareladb promote, POST /api/promote, api/promote, promote, failover, lag, replication lag, kdb\_standby\_lag\_seconds, 25006, read\_only\_sql\_transaction
- See also: [Cluster: automatic failover (--cluster-peers, kareladb witness)](cluster.md), [Backup, check, repair and restore](backup-and-safety.md), [Change stream and live subscriptions: changes('t'), GET /api/changes, GET /api/subscribe](change-stream.md), [kareladb serve](cli-serve.md), [Databases and the data folder](databases.md)

A **standby** is a second `kareladb serve` that keeps a copy of every database of another server, the **primary**. It reads the primary's log (the WAL) over HTTP and applies each transaction in order. The primary sends each commit as soon as it is on its disk, so the copy is usually a few milliseconds behind. Users of the standby can read; every change is made on the primary.

Use it to keep reports and dashboards off the primary, and to have a second copy on another computer.

A standby does not take over by itself when the primary dies: a person runs `kareladb promote`. For automatic failover, run a [cluster](cluster.md) instead: two data nodes and a small witness, where the leader is elected and a new one takes writes within about 6 seconds (3.6 to 6 s measured) ([what was tested](cluster.md#failures)).

<a id="start"></a>

## Start a standby

```bash
# the primary: any kareladb serve with a token
kareladb serve --data-dir D:/kdb-data --token <secret>

# the standby: another folder (another computer), pointing at the primary
kareladb serve --data-dir E:/kdb-copy --standby-of http://primary:9900 --standby-token <secret>
```

| Setting | Meaning |
|---|---|
| `--standby-of URL` (`KARELADB_STANDBY_OF`) | the primary's address, `http://host:port` or `https://host:port` |
| `--standby-token T` (`KARELADB_STANDBY_TOKEN`) | what the standby sends to the primary: the primary's `--token`, or an API token of an admin |
| `KARELADB_STANDBY_WAIT_MS` | how long one request waits at the primary for the next commit (default 25000 ms, at least 1000, at most 55000). `0` turns streaming off: the standby then asks every `KARELADB_STANDBY_POLL_MS` |
| `KARELADB_STANDBY_POLL_MS` | how often an up-to-date standby asks again when it cannot wait at the primary (default 100 ms) |

<a id="streaming"></a>

## Streaming: how fast the copy follows

Each database is copied by a thread of its own. The thread asks the primary for the log after its last LSN and says it will wait (`wait=`). When nothing is new, the request waits on the primary. The primary's commit wakes it the moment the commit is on disk, and the answer goes out at once.

| | Before 2026-10-22 | Now |
|---|---|---|
| how the standby asks | every 100 ms, database after database | one waiting request per database |
| a big load in one database | the others waited for it | the others go on |
| requests while nothing changes | 10 a second per database | one every 25 s per database |

Measured on one PC (primary and standby on 2 CPUs each, in WSL), from the moment the primary confirmed a one-row commit until the standby showed the row:

| Load on the primary | Before (median / p99) | Now (median / p99) |
|---|---|---|
| none | 69 / 110 ms | 3.2 / 5.0 ms |
| a bulk load (500-row inserts) in another database | 1,435 / 1,945 ms | 1.1 / 7.6 ms |
| a bulk load in the same database | 855 / 1,405 ms | 150 / 278 ms |

With a bulk load in the same database, the standby has to apply all of that load first, one transaction after another, so the lag is the time to apply it. The primary's write speed was the same with and without the change.

A waiting request costs the primary a sleeping thread, not a worker: while it waits, another HTTP thread serves in its place (one kept from an earlier wait, so a commit does not start and end a thread), so `/exec` has all its `--http-threads` workers however many databases the standbys copy. At most 64 requests wait at once. A request that finds all 64 places taken is answered at once (`X-KDB-Waited: 0`), and that thread asks again after `KARELADB_STANDBY_POLL_MS`, as before.

A waiting request does not keep its database open: `DROP DATABASE` on the primary works while a standby waits on it.

The standby only asks the primary to wait when the primary's list of databases says it can (the header `X-KDB-Wal-Wait: 1`). A primary on a version before 2026-10-22 does not say so: the standby then asks it every `KARELADB_STANDBY_POLL_MS`, as before, and its waiting places stay free for `GET /api/changes`. Upgrade the primary too to get streaming.

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
| `promoted` | `kareladb promote` ran: this server is a primary now |
| `connected`, `error` | the last request to the primary worked, or why not |
| `fetch_threads` | the threads copying a database each (streaming) |
| `databases[].applied_lsn` | the last LSN of the primary this copy holds |
| `databases[].primary_lsn`, `behind_lsn` | the end of the primary's log when last asked, and the difference |
| `databases[].last_commit_ms` | when the last applied transaction committed on the primary |
| `databases[].received_bytes` | log bytes copied since the standby started |
| `databases[].error` | why this database stopped copying |

<a id="promote"></a>

## Promote: the standby becomes the primary

When the primary is lost, make the standby the primary:

```bash
kareladb promote --url http://standby:9900 --token <secret>
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

To have this done by itself, with no person at 3 a.m., run a [cluster](cluster.md): two data nodes and a witness elect a new leader when the old one dies, and fence it so the two never both write.

Before you promote:

- Make sure the old primary is really gone, or stop it. Two primaries take different writes, and the copies cannot be joined again.
- Look at `lag_lsn`: what the primary committed and the standby had not copied is lost.

After the promote, start the server again **without** `--standby-of` (and drop `KARELADB_STANDBY_OF`); with it, it would be a standby again. To get a new standby, start one against the new primary. The old primary's folder cannot follow the new one: copy it again from a backup of the new primary.

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

With `wait=ms` and nothing new yet, the answer waits up to that long and goes out as soon as the next commit is on disk. These headers come with each answer:

| Header | Meaning |
|---|---|
| `X-KDB-Durable-Lsn` | where the primary's log on disk ended when it was read |
| `X-KDB-More` | `1`: there is more right now, ask again at once |
| `X-KDB-Waited` | with `wait=`: `1` it waited, `0` every waiting place was taken and it answered at once |

The list (`GET /api/wal`) carries `X-KDB-Wal-Wait: 1`: this primary honours `wait=`.

Use HTTPS (`--tls-cert`) between computers: the log is sent as it is.
