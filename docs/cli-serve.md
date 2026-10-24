# kareladb serve

> Start the KarelaDB server - web console, HTTP API, line protocol and PostgreSQL port - on one database or on the whole data folder.

- Category: Command line
- Keywords: server, start server, port 9900, web console, HTTP API, banner, Ctrl+C, stop server, SIGTERM, systemd, service, many databases, default database, --port, --bind, --token, --db, --threads, --cache-mb, --warm-indexes, KARELADB\_WARM\_INDEXES, --reader-yield, KARELADB\_READER\_YIELD, reader yield, --per-table-reads, KARELADB\_PER\_TABLE\_READS, --read-only-calls, KARELADB\_READ\_ONLY\_CALLS, --scoped-ddl, KARELADB\_SCOPED\_DDL, --snapshot-reads, KARELADB\_SNAPSHOT\_READS, snapshot reads, --tail-files, KARELADB\_TAIL\_FILES, tail files, --sync-commits, --pg-port, --pg-timestamptz, --pg-int-division, KARELADB\_PG\_INT\_DIVISION, 0.0.0.0, result cache, --drain-timeout, KARELADB\_DRAIN\_TIMEOUT, drain, graceful shutdown, 503, Retry-After, kareladb.conf, KARELADB\_WAL\_ARCHIVE\_MB, KARELADB\_KEEP\_VERSIONS, KARELADB\_TRASH\_KEEP\_HOURS, worker threads, --http-threads, KARELADB\_HTTP\_THREADS, http\_threads, --http-gzip, KARELADB\_HTTP\_GZIP, gzip answers, --max-connections, KARELADB\_MAX\_CONNECTIONS, max\_connections, --lock-timeout, KARELADB\_LOCK\_TIMEOUT, lock\_timeout\_ms, --idle-in-transaction-timeout, KARELADB\_IDLE\_IN\_TRANSACTION\_TIMEOUT, idle\_in\_transaction\_timeout\_ms, --memory-limit, KARELADB\_MEMORY\_LIMIT, KARELADB\_LEVEL\_FROM\_HEAP, memory limit, memory full, out of memory, 53200, OOM, container memory, --slow-query-ms, KARELADB\_SLOW\_QUERY\_MS, slow\_query\_ms, --token-name, KARELADB\_TOKEN\_NAME, --trash-max-mb, KARELADB\_TRASH\_MAX\_MB, trash\_max\_mb, metrics, self-tuning, cgroup, cpu.max, --cpus, docker update, CPU limit, KARELADB\_SELF\_TUNING\_SECONDS, --pin-threads, KARELADB\_PIN\_THREADS, pin threads, CPU pinning, sched\_setaffinity, cpuset, pinned\_cpus, --snapshot-index-rows, KARELADB\_SNAPSHOT\_INDEX\_ROWS, --txn-spill-mb, KARELADB\_TXN\_SPILL\_MB, txn\_spill\_mb, --ddl-beside-writers, KARELADB\_DDL\_BESIDE\_WRITERS, --skip-locked-beside, KARELADB\_SKIP\_LOCKED\_BESIDE, SKIP LOCKED, options, all options, every option, settings, environment variables, --timer-workers, KARELADB\_TIMER\_WORKERS, timer\_workers, KARELADB\_TTL\_CHECK\_MS, KARELADB\_LAZY\_OPEN, KARELADB\_CACHE\_MB, KARELADB\_TOKEN, KARELADB\_MEMORY, --timezone, KARELADB\_TIMEZONE, --trigger-retries, KARELADB\_TRIGGER\_RETRIES, --max-trigger-jobs, KARELADB\_MAX\_TRIGGER\_JOBS, --alert-webhook, KARELADB\_ALERT\_WEBHOOK, alert\_webhook, rate\_limit\_ip, rate\_limit\_user, KARELADB\_RATE\_LIMIT\_IP, KARELADB\_RATE\_LIMIT\_USER, tls\_cert, tls\_key, KARELADB\_TLS\_CERT, KARELADB\_TLS\_KEY, KARELADB\_TLS\_REQUIRED, http\_functions, http\_timeout\_ms, KARELADB\_HTTP\_FUNCTIONS, KARELADB\_HTTP\_TIMEOUT\_MS, KARELADB\_BACKUP\_DIR, KARELADB\_BACKUP\_SCHEDULE, KARELADB\_BACKUP\_KEEP\_DAILY, KARELADB\_BACKUP\_KEEP\_WEEKLY, KARELADB\_BACKUP\_COMMAND, test switches, KARELADB\_CHECKPOINT\_BESIDE\_WRITERS, checkpoint beside writers, KARELADB\_NO\_ZONE\_MAPS, KARELADB\_NO\_COLUMN\_MASK, KARELADB\_NO\_SYMBOL\_PRUNING, KARELADB\_NO\_TIME\_SPANS, KARELADB\_NO\_PARTITION\_ANSWERS, KARELADB\_NO\_LATEST\_PARTITIONS, KARELADB\_NO\_NEWEST\_FIRST, KARELADB\_NO\_TEXT\_KEYS, KARELADB\_NO\_VECTOR\_EXPR, KARELADB\_NO\_VECTOR\_CASE, KARELADB\_NO\_VECTOR\_DISTINCT, KARELADB\_NO\_UNION\_PUSHDOWN, KARELADB\_NO\_DISTINCT\_GROUP, KARELADB\_NO\_VIEW\_PUSHDOWN, KARELADB\_NO\_SUBQUERY\_STREAM, KARELADB\_NO\_JOIN\_LOOKUP, KARELADB\_NO\_JOIN\_PLACES, KARELADB\_NO\_KEY\_STRETCH, KARELADB\_NO\_POST\_WINDOW\_FILTER, KARELADB\_NO\_WINDOW\_TOP\_PER\_KEY, KARELADB\_WINDOW\_NO\_FAST, KARELADB\_WINDOW\_NO\_VECTOR\_SCAN, KARELADB\_NO\_INSERT\_STREAM, KARELADB\_NO\_INSERT\_RUNS, KARELADB\_NO\_INSERT\_APPLY, KARELADB\_NO\_BATCH\_DEDUP, KARELADB\_NO\_FOREIGN\_PUSH, KARELADB\_NO\_VECTOR\_PRESELECT, KARELADB\_NO\_PREFETCH, KARELADB\_MV\_NO\_DEFER, KARELADB\_WRITE\_TRACE, KARELADB\_CACHE\_VERIFY, KARELADB\_INDEX\_MAX\_VISITS, --stat-statements, KARELADB\_STAT\_STATEMENTS, lanes, priority lanes, admission control, --lanes, KARELADB\_LANES, --heavy-ms, KARELADB\_HEAVY\_MS, --heavy-slots, KARELADB\_HEAVY\_SLOTS, --heavy-queue, KARELADB\_HEAVY\_QUEUE, --read-slots, KARELADB\_READ\_SLOTS, read slots, docker --cpus throughput, kdb.priority, X-KDB-Priority, heavy query, report, chart latency, 53000, server is busy, --log-lock-waits, KARELADB\_LOG\_LOCK\_WAITS, --deadlock-timeout, KARELADB\_DEADLOCK\_TIMEOUT, log\_lock\_waits, deadlock\_timeout, --tcp-keepalives-idle, --tcp-keepalives-interval, --tcp-keepalives-count, KARELADB\_TCP\_KEEPALIVES\_IDLE, tcp\_keepalives\_idle, TCP keepalive, --standby-of, --standby-token, KARELADB\_STANDBY\_OF, standby, kareladb promote
- See also: [The kareladb program](cli-overview.md), [Web console](web-console.md), [Run SQL over HTTP (/exec, /exp)](http-exec.md), [Databases over HTTP (/api/databases)](http-databases.md), [Keeping kareladb serve safe](server-security.md), [Users and roles](users-and-roles.md), [PostgreSQL protocol (port 8832)](postgres-protocol.md), [Line protocol (POST /write)](line-protocol.md), [Performance tips](performance-tips.md)

`kareladb serve` starts the server. It keeps running until you press Ctrl+C.
While it runs, programs use the databases through it: the [web console](web-console.md) in a browser, the [HTTP API](http-exec.md), the [line protocol](line-protocol.md) (`POST /write`) and PostgreSQL tools on the [PostgreSQL port](postgres-protocol.md).

The server has the database files open. So `kareladb sql`, `kareladb shell`, `kareladb backup` and `kareladb check` on the same database fail while it runs. Use the server instead: the console, `POST /exec`, `BACKUP DATABASE`, `POST /api/check`.

## kareladb serve

Syntax:

```sql
kareladb serve [<db>] [--data-dir <folder>] [--config <file>] [--db <name>] [--port 9900] [--bind 127.0.0.1]
          [--backups <dir>] [--token <secret>] [--memory <MB>] [--memory-limit <size>] [--threads N] [--cache-mb <MB>]
          [--sync-commits always|batch] [--pg-port 8832] [--pg-timestamptz] [--pg-int-division on|off]
          [--warm-indexes on|off] [--reader-yield on|off] [--per-table-reads on|off] [--read-only-calls on|off]
          [--scoped-ddl on|off] [--ddl-beside-writers on|off] [--skip-locked-beside on|off]
          [--log-lock-waits on|off] [--deadlock-timeout 1s]
          [--snapshot-reads on|off] [--snapshot-index-rows N] [--txn-spill-mb 64] [--tail-files on|off]
          [--table-writers one|many]
          [--timezone <zone>] [--drain-timeout 30s] [--pin-threads auto|on|off]
          [--http-threads N] [--max-connections N] [--timer-workers N] [--lock-timeout 5s] [--idle-in-transaction-timeout 30s]
          [--trigger-retries N] [--max-trigger-jobs N] [--alert-webhook <url>] [--slow-query-ms N] [--token-name <name>]
          [--trash-max-mb N] [--tls-cert <file> --tls-key <file>] [--tls-required on|off]
          [--lanes on|off] [--heavy-ms 100] [--heavy-slots N] [--heavy-queue N] [--read-slots auto|off|N]
          [protection and backup options: see protection and backup-schedule]
```

| Option | Meaning | Default |
|---|---|---|
| `<db>` | Without it: **every** database in the data folder. A name from the data folder: every database, and this one is the default. A folder path: **only** that folder. | all databases in the data folder |
| `--data-dir <folder>` | The data folder (see [the data folder](cli-overview.md#data-folder)). Always wins over `kareladb.conf`. | `kareladb.conf`, else `KARELADB_DATA_DIR`, else `data` next to kareladb |
| `--config <file>` | Settings the console's [Settings page](console-settings.md) may change: the data folder, and `wal_archive_mb` (old log kept per database; it wins over the `KARELADB_WAL_ARCHIVE_MB` environment variable, default 1024). | `kareladb.conf` next to kareladb |
| `--db <name>` | The **default** database: the one a request uses when it names no database. With a folder path: the name the folder is served under. | `default` (with a path: the folder's name) |
| `--port N` | The HTTP port for the console and the API (1 to 65535) | `9900` |
| `--bind <address>` | The network address to listen on. `127.0.0.1` = only this computer. `0.0.0.0` = every network. | `127.0.0.1` |
| `--backups <dir>` | Backup folder for `BACKUP DATABASE`, the console's **Backup now**, `POST /api/backup` and the [schedule](backup-schedule.md). A database of the data folder backs up into `<dir>/<name>`. Damaged files are also repaired from here when a database opens. `off` = no backups. Also `KARELADB_BACKUP_DIR` or `backup_dir` in `kareladb.conf`. | `_backups` in the data folder; for one folder served by its path, `_backups/<folder name>` next to that folder |
| `--token <secret>` | A secret every request must send (`Authorization: Bearer <secret>`). It works like an admin user. `kareladb serve` reads no environment variable for it; the Docker image passes its `KARELADB_TOKEN` as `--token`. | no token |
| `--memory <MB>` | Memory for table data kept loaded, for all open databases together. Data over it is read from disk again when needed. No environment variable in the program; the Docker image passes its `KARELADB_MEMORY` as `--memory`. | `512`, but without the flag at most 40% of the [memory limit](#memory-limit) |
| `--memory-limit <size>` | One limit for **everything** the server holds: table data, unsaved changes, indexes, results and caches (see [memory limit](#memory-limit)). `3GB`, `512MB`, or a plain number of megabytes. `0` or `off` = no limit. Also `KARELADB_MEMORY_LIMIT`. | 85% of a container's memory limit, else of the machine's memory |
| `--threads N` | Threads for big queries and writes, shared by all databases. From 1 to half of the machine's CPU threads. A number set here stays; without it the count follows the CPU limit ([self-tuning](#self-tuning)). | half of the CPUs the process may use |
| `--cache-mb <MB>` | Memory for results of repeated queries, for all open databases together. `0` = no result cache. Else `cache_mb` in kareladb.conf, else `KARELADB_CACHE_MB`. One result may use a quarter of it, a [pinned](pinned-queries.md) one three quarters. | `256`, but at most a tenth of the [memory limit](#memory-limit) |
| `--warm-indexes on\|off` | Build every index of a database on a background thread right after it opens, so the first query finds it ready (see [indexes](indexes.md#warm)). `off` = build on first use. Also `KARELADB_WARM_INDEXES`. | `on` |
| `--read-only-calls on\|off` | `on`: a `CALL` of a procedure that changes nothing runs like a `SELECT`: no table locks, no transaction ([a CALL that only reads](procedures.md#read-only-call)). `off`: every `CALL` is a transaction. Also `KARELADB_READ_ONLY_CALLS`. | `on` |
| `--scoped-ddl on\|off` | `on`: `CREATE`, `ALTER` and `DROP TABLE`, `CREATE` and `DROP INDEX` and `CREATE`, `ALTER` and `DROP TRIGGER`, `TRUNCATE`, `CREATE TABLE ... AS` and materialized views lock only their tables, and views, procedures and functions lock none, so they do not wait for a long writer of other tables ([schema changes](transactions.md#one-writer)). `off`: every schema change locks every table. Also `KARELADB_SCOPED_DDL`. | `on` |
| `--ddl-beside-writers on\|off` | With `--scoped-ddl on`: `CREATE TABLE`, `ALTER TABLE`, `RENAME TABLE` and `CREATE` / `DROP INDEX` run beside writers of other tables, also beside one long statement that never pauses (a big `INSERT ... SELECT` or `COPY`), instead of failing with `55P03` after the lock timeout ([schema changes](transactions.md#one-writer)). `off`: they wait until such a writer pauses between two statements, as before 2026-09-25. Also `KARELADB_DDL_BESIDE_WRITERS`. | `on` |
| `--skip-locked-beside on\|off` | `on`: `SELECT ... FOR UPDATE SKIP LOCKED` inside `BEGIN` returns the rows another open transaction did not lock or change, although that transaction holds the table. Your `UPDATE` of such a row then waits for its `COMMIT` and fails with `40001` after the lock timeout ([FOR UPDATE](transactions.md#for-update)). `off`: no rows there, as before; without `BEGIN` the free rows are returned either way. Also `KARELADB_SKIP_LOCKED_BESIDE`. | `off` |
| `--reader-yield on\|off` | `on`: a reader of a table a long trigger, `CALL` or transaction is writing does not wait for it. The writer steps aside between its statements and the reader sees the last committed rows. `off`: such readers wait for the writer's whole request. Also `KARELADB_READER_YIELD`. The start-up line `readers` says which is in use. | `on` |
| `--pin-threads auto\|on\|off` | Linux. `auto`: inside a CPU quota (`docker --cpus`, cgroup `cpu.max`) smaller than the CPUs the process may run on, every thread is pinned to the quota's worth of CPUs, one per core, and moved back when the quota goes ([pinning threads](#pin-threads)). `on`: each HTTP worker, PostgreSQL connection and query thread runs on one CPU of its own, so its CPU cache stays warm. `off`: nothing is pinned. Windows: ignored (`on` with a warning). Also `KARELADB_PIN_THREADS`. | `auto` |
| `--per-table-reads on\|off` | `on`: a reader waits only for writers of the tables it reads, and not while a checkpoint writes its files (see [transactions](transactions.md#per-table-reads)). `off`: every reader waits for every writer. Also `KARELADB_PER_TABLE_READS`. | `on` |
| `--snapshot-reads on\|off` | `on`: a reader of a table a long `CALL`, trigger job or big statement is writing does not wait at all: it reads a snapshot of the committed rows (see [transactions](transactions.md#snapshot-reads)). Tables with an index too, while a writer is busy on them: such a read still uses a plain or expression index, on the snapshot. Also `KARELADB_SNAPSHOT_READS`. The start-up line `readers` says so. | `off` |
| `--table-writers one\|many` | `many`: several users change **one table** at the same time when each of their statements on it touches single rows by the primary key - a one-row `INSERT`, `UPDATE ... WHERE id = x`, `DELETE ... WHERE id = x`, a `CALL` or trigger made of such statements. The same row is waited for, as in PostgreSQL; two writers that wait for each other's rows get `deadlock` (`40P01`). Anything else on the table (a range `UPDATE`, `INSERT ... SELECT`, a `SELECT` statement, `BEGIN ... COMMIT` across requests, a table with foreign keys or other `UNIQUE` columns) takes the whole table, as before ([several writers of one table](transactions.md#shared-writers)). `one`: one writer per table at a time. Also `KARELADB_TABLE_WRITERS`. | `one` |
| `--snapshot-index-rows N` | With snapshot reads on: a plain or expression index is used on a snapshot at any table size. A table with a full-text or JSON index, or an index not built in memory yet, has its snapshot scanned instead, and only while it has at most this many rows; a bigger one is waited for, as before, so a lookup does not turn into a scan of millions of rows. `0`: indexed tables are always waited for. Also `KARELADB_SNAPSHOT_INDEX_ROWS`. | `1000000` |
| `--tail-files on\|off` | `on`: a save (checkpoint) puts rows appended after the end of a partition in a small [tail file](partitions-and-dedup.md#tail-files) next to it, instead of writing the whole partition again. A database with tail files needs KarelaDB 2026-10-02 or newer. Also `KARELADB_TAIL_FILES`. | `off` |
| `--txn-spill-mb N` | A transaction's log records past this many MB (or 1/16 of `--memory-limit`, if less) go to a temporary file in the database's `_tmp` folder until `COMMIT`, so a long `CALL` or trigger job does not hold them all in memory (see [transactions](transactions.md#txn-spill)). `0`: they all stay in memory. Also `KARELADB_TXN_SPILL_MB`. | `64` |
| `--sync-commits always` | Every write is on disk before KarelaDB confirms it. | `always` |
| `--sync-commits batch` | Writes are confirmed at once and put on disk every 10 ms. | |
| `--pg-port N` | Port for the PostgreSQL protocol. `0` = off. | `8832` |
| `--pg-timestamptz` | Send `TIMESTAMP` columns to PostgreSQL clients as `timestamptz` (with time zone). | off |
| `--timezone <zone>` | The server's time zone, like `Asia/Kathmandu`: the clock of `CURRENT_DATE`, `::date`, `date_trunc` and `EXTRACT` for sessions that set none, and of timer and backup schedules. Times are still stored in UTC. Env `KARELADB_TIMEZONE`, kareladb.conf `"timezone"`. See [time zones](time-and-time-zones.md#session-time-zone). | UTC (schedules: the machine's clock) |
| `--pg-int-division on\|off` | `on`: on the Postgres port, whole number / whole number gives a whole number (`7 / 2` is `3`), as in PostgreSQL. A connection can still choose with `SET int_division = integer \| float`. Also `KARELADB_PG_INT_DIVISION`. See [integer division](postgres-protocol.md#int-division). | `off` |
| `--pg-compat on\|off` | `on`: PostgreSQL 14's answers (exact decimal literals, `RANGE` window frames, locale text order, ...) for every database without its own `ALTER DATABASE ... SET pg_compat`. A session can still choose with `SET kdb.pg_compat`. Also `KARELADB_PG_COMPAT`. Waiting for the owner's decision: keep it off. See [PostgreSQL-compatible results](postgres-protocol.md#pg-compat). | `off` |
| `--drain-timeout <time>` | On a stop, how long running requests may still finish while new ones get 503 (see [stopping](#stop)). `0` = do not wait. | `30s`, or `KARELADB_DRAIN_TIMEOUT` |
| `--http-threads N` | HTTP requests handled at the same time (1 to 1024). A slow query holds its thread until it ends, so more threads keep fast lookups from waiting behind slow ones. Also `KARELADB_HTTP_THREADS` or `http_threads` in `kareladb.conf`. | the CPUs the process may use, at least 8, at most 64; without a number set it follows the CPU limit while the server runs (`docker update --cpus`) |
| `--http-gzip remote\|on\|off` | Answers of 2 KB or more (JSON, CSV, the console's files) go out compressed (`Content-Encoding: gzip`, about a fifth of the bytes) to a client that sends `Accept-Encoding: gzip`, as browsers, Go and Python do by themselves. `remote`: only clients beyond this computer and its private networks; one on this computer (`127.x`), on the same LAN (`10.x`, `172.16-31.x`, `192.168.x`) or in another container on this computer (Docker's bridge, `172.17.x`) gets plain answers, as there the bytes arrive faster than they can be compressed. Also `KARELADB_HTTP_GZIP`. See [compressed answers](http-overview.md#gzip-answers). | `remote` |
| `--lanes on\|off` | [Priority lanes](#lanes): a read that used `--heavy-ms` of CPU or more the last three times runs only when a heavy slot is free, so charts stay fast while reports run. `off`: every statement starts at once. Also `KARELADB_LANES`. | `on` |
| `--heavy-ms N` | How much CPU time (in ms) a read must use, three times in a row, to count as heavy. Also `KARELADB_HEAVY_MS`. | `100` |
| `--heavy-slots N` | Heavy statements that run at the same time. Also `KARELADB_HEAVY_SLOTS`. | half of the CPUs the process may use, at least 1 |
| `--heavy-queue N` | Heavy HTTP requests that may wait for a slot at the same time. Past it a request sent with priority `low` is refused with `503`; a read heavy by its history runs at once. PostgreSQL statements are not counted. Also `KARELADB_HEAVY_QUEUE`. | half of `--http-threads`, at least 4 |
| `--read-slots auto\|off\|N` | [Read slots](#read-slots): reads that run at the same time; the rest wait in line, and a read holds its slot for at most 10 ms. `off`: every read starts at once. Also `KARELADB_READ_SLOTS`. | `auto`: the CPUs the process may use, at least 2 |
| `--max-connections N` | PostgreSQL logins at the same time, for all databases together. `0` = no limit. Also `KARELADB_MAX_CONNECTIONS` or `max_connections` in `kareladb.conf`. | `500` |
| `--timer-workers N` | [Timers](timers.md) that may run at the same time (1 to 64). Each running timer is one more writer at the database. Also `KARELADB_TIMER_WORKERS` or `timer_workers` in `kareladb.conf`. | 3 |
| `--tcp-keepalives-idle S`, `--tcp-keepalives-interval S`, `--tcp-keepalives-count N` | TCP keepalive of every HTTP and PostgreSQL connection: seconds without traffic before the first probe (0 to 32767), seconds between probes, probes before a vanished client is dropped (0 to 127). Keepalive is always on; `0` = the system's timings. A Postgres connection can set its own with `SET tcp_keepalives_idle` ([idle and vanished clients](server-activity.md#idle-clients)). Also `KARELADB_TCP_KEEPALIVES_IDLE`, `KARELADB_TCP_KEEPALIVES_INTERVAL`, `KARELADB_TCP_KEEPALIVES_COUNT` or `tcp_keepalives_idle`, `tcp_keepalives_interval`, `tcp_keepalives_count` in `kareladb.conf`. | 0 (the system's) |
| `--trigger-retries <N>` | A failed [deferred trigger](triggers.md#deferred) job runs again this many times, 1 s, 2 s, 4 s ... apart, before its queue stops. `0` = never. Also `KARELADB_TRIGGER_RETRIES`. | `3` |
| `--max-trigger-jobs <N>` | Deferred trigger jobs that may wait in one database. A write past it is refused with `503` and the reason. `0` = no limit. Also `KARELADB_MAX_TRIGGER_JOBS`. | `10000` |
| `--alert-webhook <url>` | Failed deferred trigger jobs are sent as JSON to this `http://<IPv4>:<port>/<path>` ([alerts](triggers.md#deferred-alerts)). Also `KARELADB_ALERT_WEBHOOK` or `alert_webhook` in `kareladb.conf`. | none |
| `--lock-timeout <time>` | How long a writer waits for a table another writer holds, then `table 'x' is busy`. `0` = no limit. A session can set its own with `SET lock_timeout` ([lock timeout](transactions.md#lock-timeout)). Also `KARELADB_LOCK_TIMEOUT` or `lock_timeout_ms` in `kareladb.conf`. | `5s` |
| `--idle-in-transaction-timeout <time>` | An open `BEGIN` ... `COMMIT` that sends nothing this long is rolled back, so a client that died cannot keep its tables locked. `0` = never. A session can set its own with `SET idle_in_transaction_session_timeout` ([idle transactions](transactions.md#idle-timeout)). Also `KARELADB_IDLE_IN_TRANSACTION_TIMEOUT` or `idle_in_transaction_timeout_ms` in `kareladb.conf`. | `30s` |

- **Exit code:** `1` when it cannot start (a bad option, the port is in use, the database is open in another program). `0` after a clean stop with Ctrl+C. `2` when a database is damaged and cannot be opened.
- **Security:** `--bind` with an address that is not `127.x` or `localhost` is **refused** when there is no `--token` and no user. `--tls-cert`, `--tls-key` and `--tls-required` turn on encryption for both ports: see [TLS](tls.md) and [server security](server-security.md).
- **Users:** when the data folder has users (made with [kareladb user add](cli-users.md) or `CREATE USER`), every request needs a login. A server on one folder path has no users.
- **Result cache (`--cache-mb`):** a result is given again only while no table it read has changed. A quick result (under 1 ms) is kept when the same query comes a second time. Queries with random functions are never kept, and queries with `now()` only for a caller that takes an older answer (`cache_now_ms`, see [result cache](performance-tips.md#result-cache)).
- **Start-up:** a database's table files are opened when a query first needs them, not all at open, so a big database answers in seconds. The start-up lines show where the open went (`open  opened in 193 ms: manifest 33 ms, 1 files read 6 ms (6000 table files left for their first use), log check 75 ms, ...`). A background check then reads every table file's header and checksums and reports a damaged one (`recovery_summary` in `GET /api/info`, and the server log). `KARELADB_LAZY_OPEN=off` reads (and repairs) every file at open, as before.
- **Batch commits:** a power cut can lose the writes of the last few milliseconds that were already confirmed. It never damages the data. See [performance tips](performance-tips.md#sync-commits).
- **Standby:** `--standby-of http://primary:9900 --standby-token <t>` makes the server a read-only copy of another one; `kareladb promote --url <standby>` makes it a primary when the primary is lost. Restart it without `--standby-of` after that. See [standby](standby.md).
- **Protection and backups:** `--statement-timeout`, `--max-result-memory`, `--max-groups`, `--max-queries-per-user`, `--rate-limit-ip`, `--rate-limit-user`, `--safe-updates`, `--read-only`, `--trash-days`, `--audit`, `--audit-keep-days` and `--activity-log-size` are in [protection](protection.md). `--backup-schedule`, `--backup-copy`, `--backup-command`, `--backup-warn-hours`, `--keep-daily` and `--keep-weekly` are in [backup schedule](backup-schedule.md).
- **A flag or an environment variable:** `--warm-indexes`, `--reader-yield`, `--per-table-reads`, `--read-only-calls`, `--scoped-ddl`, `--ddl-beside-writers`, `--skip-locked-beside`, `--log-lock-waits`, `--deadlock-timeout`, `--snapshot-reads`, `--snapshot-index-rows`, `--tail-files`, `--table-writers`, `--pg-int-division`, `--drain-timeout`, `--token-name`, `--trigger-retries`, `--max-trigger-jobs`, `--memory-limit` and `--tls-required` can come from the environment instead (`KARELADB_WARM_INDEXES`, `KARELADB_READER_YIELD`, `KARELADB_PER_TABLE_READS`, `KARELADB_READ_ONLY_CALLS`, `KARELADB_SCOPED_DDL`, `KARELADB_DDL_BESIDE_WRITERS`, `KARELADB_SKIP_LOCKED_BESIDE`, `KARELADB_LOG_LOCK_WAITS`, `KARELADB_DEADLOCK_TIMEOUT`, `KARELADB_SNAPSHOT_READS`, `KARELADB_SNAPSHOT_INDEX_ROWS`, `KARELADB_TAIL_FILES`, `KARELADB_TABLE_WRITERS`, `KARELADB_PG_INT_DIVISION`, `KARELADB_DRAIN_TIMEOUT`, `KARELADB_TOKEN_NAME`, `KARELADB_TRIGGER_RETRIES`, `KARELADB_MAX_TRIGGER_JOBS`, `KARELADB_MEMORY_LIMIT`, `KARELADB_TLS_REQUIRED`). A flag always wins. That is how the Docker image sets them ([Docker](install-packages.md#docker)). They have no `kareladb.conf` key. The whole list is in [every option](#all-options).
- **A flag, kareladb.conf or the environment:** `--http-threads`, `--max-connections`, `--lock-timeout`, `--idle-in-transaction-timeout`, `--rate-limit-ip`, `--rate-limit-user`, `--timer-workers` and the `--tcp-keepalives-*` flags are read in this order: the flag, then `kareladb.conf`, then `KARELADB_HTTP_THREADS`, `KARELADB_MAX_CONNECTIONS`, `KARELADB_LOCK_TIMEOUT`, `KARELADB_IDLE_IN_TRANSACTION_TIMEOUT`, `KARELADB_RATE_LIMIT_IP`, `KARELADB_RATE_LIMIT_USER`, `KARELADB_TIMER_WORKERS`, `KARELADB_TCP_KEEPALIVES_*`, then the default. The start-up lines show them (`capacity  16 HTTP threads (default), 500 PostgreSQL connections (default), lock wait 5 s (default)`), and the console's Settings page shows them with where each came from.
- **Logs and metrics:** `--slow-query-ms N` sets the [slow-query log](http-server-info.md#slow-queries) threshold, `--token-name NAME` (or `KARELADB_TOKEN_NAME`) is what the [audit log](audit-log.md) calls whoever uses the token (default `token`), and [`GET /metrics`](http-server-info.md#metrics) serves Prometheus metrics. `--stat-statements off` (or `KARELADB_STAT_STATEMENTS=off`) switches off [pg_stat_statements](server-activity.md#pg-stat-statements), which is on by default. The start-up line `logs` says where the slow statements go, and whether pg_stat_statements is on.
- **Threads:** the HTTP side has one poller thread and a pool of workers (`--http-threads`); `--threads` is for the work inside queries and writes ([limits](http-overview.md#limits)).

<a id="kareladb-conf"></a>

### kareladb.conf

`kareladb.conf` is a small JSON file of settings, next to kareladb (or `--config <file>`). A `kdb.conf` from before the rename is read when there is no `kareladb.conf`. The console's [Settings page](console-settings.md) writes it. A server on one folder path (`kareladb serve ./market`) reads only the three folder keys from it.

| Key | Meaning | Else |
|---|---|---|
| `data_dir` | the data folder | `KARELADB_DATA_DIR`, then `data` next to kareladb. `--data-dir` always wins over it. |
| `wal_archive_mb` | old log each database keeps for repairs (0 = none) | `KARELADB_WAL_ARCHIVE_MB`, then 1024 |
| `cache_mb` | the [result cache](performance-tips.md#result-cache) of all databases together, in MB (0 = off) | `KARELADB_CACHE_MB`, then 256. `--cache-mb` wins. |
| `keep_versions` | older file versions kept for repairs (0 to 10) | `KARELADB_KEEP_VERSIONS`, then 2 |
| `trash_keep_hours` | how long replaced files stay in the trash | `KARELADB_TRASH_KEEP_HOURS`, then 1 |
| `trash_max_mb` | the most a database's trash may hold; beyond it the oldest folders go at once, whatever their age (0 = no limit) | `KARELADB_TRASH_MAX_MB`, then a quarter of the database's data (at least 256 MB). `--trash-max-mb` wins. |
| `slow_query_ms` | statements taking this many milliseconds or more go to the [slow-query log](http-server-info.md#slow-queries) (0 = off) | `KARELADB_SLOW_QUERY_MS`, then 1000. `--slow-query-ms` wins. |
| `http_threads` | HTTP requests handled at once (1 to 1024) | `KARELADB_HTTP_THREADS`, then the CPU threads (at least 8, at most 64). `--http-threads` wins. |
| `max_connections` | PostgreSQL logins at once (0 = no limit) | `KARELADB_MAX_CONNECTIONS`, then 500. `--max-connections` wins. |
| `lock_timeout_ms` | milliseconds a writer waits for a busy table (0 = no limit) | `KARELADB_LOCK_TIMEOUT`, then 5000. `--lock-timeout` wins. |
| `idle_in_transaction_timeout_ms` | milliseconds an open transaction may send nothing before it is rolled back (0 = never) | `KARELADB_IDLE_IN_TRANSACTION_TIMEOUT`, then 30000. `--idle-in-transaction-timeout` wins. |
| `timer_workers` | [timers](timers.md) that may run at the same time (1 to 64) | `KARELADB_TIMER_WORKERS`, then 3. `--timer-workers` wins. |
| `tcp_keepalives_idle`, `tcp_keepalives_interval`, `tcp_keepalives_count` | TCP keepalive timings of every connection: seconds, seconds, probes (0 = the system's) | `KARELADB_TCP_KEEPALIVES_IDLE`, `KARELADB_TCP_KEEPALIVES_INTERVAL`, `KARELADB_TCP_KEEPALIVES_COUNT`, then 0. The `--tcp-keepalives-*` flags win. |
| `rate_limit_ip`, `rate_limit_user` | requests per second per client address / per user (0 = no limit; [rate limits](protection.md#rate-limits)) | `KARELADB_RATE_LIMIT_IP`, `KARELADB_RATE_LIMIT_USER`, then 0. `--rate-limit-ip`, `--rate-limit-user` win. |
| `timezone` | the server's time zone, like `"Asia/Kathmandu"` or `"America/New_York"` ([summer time](time-and-time-zones.md#summer-time)) | `KARELADB_TIMEZONE`, then the computer's own zone (UTC in a container without one). `--timezone` wins. |
| `alert_webhook` | where failed deferred trigger jobs are POSTed ([alerts](triggers.md#deferred-alerts)) | `KARELADB_ALERT_WEBHOOK`, then none. `--alert-webhook` wins. |
| `tls_cert`, `tls_key` | PEM files for [TLS](tls.md) on both ports; `tls_cert` `"auto"` = a self-signed pair | `KARELADB_TLS_CERT`, `KARELADB_TLS_KEY`, then off. `--tls-cert`, `--tls-key` win. |
| `http_functions`, `http_timeout_ms` | the hosts [`http_get` / `http_post`](http-functions.md) may call (`"off"` or a list), and the milliseconds one call may take | `KARELADB_HTTP_FUNCTIONS`, `KARELADB_HTTP_TIMEOUT_MS`, then off and 10000. No flag. |
| `web_dir`, `help_dir`, `skill_dir` | the folders of the console, the help and the Claude skill | `KARELADB_WEB_DIR` ..., then the folders next to kareladb ([folders](install-packages.md#folders)) |
| `backup_dir`, `backup_schedule`, `backup_keep_daily`, `backup_keep_weekly`, `backup_command` | the [backup settings](backup-schedule.md#backup-settings) (`backup_dir` `"off"` = none) | `KARELADB_BACKUP_DIR`, `KARELADB_BACKUP_SCHEDULE`, ..., then `_backups` in the data folder, `off`, 7, 4, none. The flags win. |

```json
{
  "data_dir": "E:/kdb-data",
  "wal_archive_mb": 512
}
```

- A lower `keep_versions` also trims files that are never written again: each database does it once, when it opens.
- An older version is only useful while the old log after it is still on disk (`wal_archive_mb`). Once that log is gone, the version goes to the trash by itself within a minute.
- For these keys `kareladb.conf` wins over the environment, so what the Settings page saved stays in force in a Docker container that sets the same variable.
- **When a change takes effect:** `cache_mb`, `wal_archive_mb`, `http_functions` and `http_timeout_ms` saved on the Settings page apply at once. Every other key is read when the server starts: edit the file, then **Restart** on the Settings page or `POST /api/restart`. A restart re-reads `kareladb.conf` but not the flags or the environment: those change only when the process (in Docker, the container) is started again.
- Unknown keys are left alone, so a file written by a newer KarelaDB still loads. A key with a wrong kind of value (text for a number, `"5s"` for `lock_timeout_ms`) stops the start with the key's name.
- A saved `data_dir` that cannot be used at start (an unplugged disk) does not stop the server: it prints a warning and starts on the usual folder, so the Settings page is there to fix it.

**Command line: Every database of the data folder**

```bash
kareladb serve
```

Output:

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      ./kdb-data (from KDB_DATA_DIR; one folder per database)
  default   default (used when a request names no database)
  backups   ./kdb-data/_backups/<database name> (from default)
  access    no token
  capacity  32 HTTP threads (default), 500 PostgreSQL connections (default), lock wait 5 s (default)
  lanes     reads using 100 ms of CPU (three times in a row) wait for one of 16 heavy slots, at most 16 HTTP in line (--lanes on)
  reads     32 reads run at once (the CPUs, at least 2; follows the CPU limit), the rest wait in line (--read-slots)
  commits   synced to disk before they are confirmed (--sync-commits always)
  time zone Asia/Katmandu (the computer's); also timers and backup schedules
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    26.95 GB for the whole process (85% of the machine's memory); table data 512.0 MB of it (--memory)
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log on (SHOW AUDIT)
  logs      slow queries >= 1000 ms to ./kdb-data/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  the default database is created when it is first used

Press Ctrl+C to stop.
```

**Command line: Only one database folder, given by its path** (sample data: sample)

```bash
kareladb serve ./market
```

Output:

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      ./market
  backups   ./_backups/market (from default)
  access    no token
  capacity  32 HTTP threads (default), 500 PostgreSQL connections (default), lock wait 5 s (default)
  lanes     reads using 100 ms of CPU (three times in a row) wait for one of 16 heavy slots, at most 16 HTTP in line (--lanes on)
  reads     32 reads run at once (the CPUs, at least 2; follows the CPU limit), the rest wait in line (--read-slots)
  commits   synced to disk before they are confirmed (--sync-commits always)
  time zone Asia/Katmandu (the computer's); also timers and backup schedules
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    26.95 GB for the whole process (85% of the machine's memory); table data 512.0 MB of it (--memory)
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log off
  logs      slow queries >= 1000 ms to ./market/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 1 ms: manifest 0 ms, 1 files read 0 ms (8 table files left for their first use), log check 1 ms, replay 0 ms (0 transactions), clean-up 0 ms

Press Ctrl+C to stop.
```

**Command line: More memory, batch commits, backups and a token** (sample data: sample)

```bash
kareladb serve ./market --backups backups --memory 2048 --threads 1 --sync-commits batch --token a-long-random-secret
```

Output:

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      ./market
  backups   backups (from --backups)
  access    token required
  capacity  32 HTTP threads (default), 500 PostgreSQL connections (default), lock wait 5 s (default)
  lanes     reads using 100 ms of CPU (three times in a row) wait for one of 16 heavy slots, at most 16 HTTP in line (--lanes on)
  reads     32 reads run at once (the CPUs, at least 2; follows the CPU limit), the rest wait in line (--read-slots)
  commits   synced every 10 ms (--sync-commits batch)
  time zone Asia/Katmandu (the computer's); also timers and backup schedules
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    26.95 GB for the whole process (85% of the machine's memory); table data 2.00 GB of it (--memory)
  cpu       32 CPUs (the machine's); 1 query thread (--threads), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log off
  logs      slow queries >= 1000 ms to ./market/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 1 ms: manifest 0 ms, 1 files read 1 ms (8 table files left for their first use), log check 0 ms, replay 0 ms (0 transactions), clean-up 0 ms

Press Ctrl+C to stop.
```

**Command line: PostgreSQL port and result cache** (sample data: sample)

```bash
kareladb serve ./market --pg-port 18832 --pg-timestamptz --cache-mb 256
```

Output:

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  postgres  127.0.0.1:18832 (PostgreSQL protocol, no TLS; no password on this computer only)
  data      ./market
  backups   ./_backups/market (from default)
  access    no token
  capacity  32 HTTP threads (default), 500 PostgreSQL connections (default), lock wait 5 s (default)
  lanes     reads using 100 ms of CPU (three times in a row) wait for one of 16 heavy slots, at most 16 HTTP in line (--lanes on)
  reads     32 reads run at once (the CPUs, at least 2; follows the CPU limit), the rest wait in line (--read-slots)
  commits   synced to disk before they are confirmed (--sync-commits always)
  time zone Asia/Katmandu (the computer's); also timers and backup schedules
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    26.95 GB for the whole process (85% of the machine's memory); table data 512.0 MB of it (--memory)
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log off
  logs      slow queries >= 1000 ms to ./market/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 1 ms: manifest 0 ms, 1 files read 0 ms (8 table files left for their first use), log check 0 ms, replay 1 ms (0 transactions), clean-up 0 ms

Press Ctrl+C to stop.
```

The help build runs every example on a free port, so the banner always shows port `9900`. `--pg-port 18832` is used here only so the example does not meet a real server on `8832`.

**Command line: --bind 0.0.0.0 without a token or users is refused**

```bash
kareladb serve --bind 0.0.0.0
```

Output:

```text
cold store 'archive': folder ./cold-archive
error: --bind 0.0.0.0 without --token and without users would let anyone who can reach this computer
read, change and delete every database. Do one of these first:
  1. create an admin user:   kareladb user add <name> --role admin
  2. or start with a secret:  --token <long random text>
  3. or keep --bind 127.0.0.1 and put a web server with HTTPS in front of KarelaDB
See docs/tutorial/16-users-passwords-security.md
```

exit code 1

**Command line: A wrong value stops the start**

```bash
kareladb serve --sync-commits fast
```

Output:

```text
error: --sync-commits must be 'always' or 'batch'
```

exit code 1

<a id="all-options"></a>

## Every option at a glance

Every setting of `kareladb serve` in one table: the flag, the environment variable, the `kareladb.conf` key and the default. `-` means there is none. When one setting has more than one of them, the flag wins, then `kareladb.conf`, then the environment, then the default.

Old names still work: KarelaDB was called KDB until 2026-10-22 ([why](about-kareladb.md#name)). Every `KARELADB_*` variable below may also be given by its old name `KDB_*` (`KDB_DATA_DIR`, `KDB_MEMORY`, ...), the program also answers to `kdb`, and `kdb.conf` is read when there is no `kareladb.conf`.

| Flag | Environment | kareladb.conf | Default | More |
|---|---|---|---|---|
| `--data-dir` | `KARELADB_DATA_DIR` | `data_dir` | `data` next to kareladb | [data folder](cli-overview.md#data-folder) |
| `--config` | - (Docker: `KARELADB_CONFIG`) | - | `kareladb.conf` next to kareladb | [kareladb.conf](#kareladb-conf) |
| `--db` | - | - | `default` | [many databases](#many-databases) |
| `--port`, `--bind` | - | - | `9900`, `127.0.0.1` | [kareladb serve](#kareladb-serve) |
| `--pg-port` | - | - | `8832` (`0` = off) | [PostgreSQL port](postgres-protocol.md) |
| `--token` | - (Docker: `KARELADB_TOKEN`) | - | none | [server security](server-security.md) |
| `--token-name` | `KARELADB_TOKEN_NAME` | - | `token` | [audit log](audit-log.md) |
| `--memory` | - (Docker: `KARELADB_MEMORY`) | - | `512`, at most 40% of the memory limit | [kareladb serve](#kareladb-serve) |
| `--memory-limit` | `KARELADB_MEMORY_LIMIT` | - | 85% of the container's or machine's memory | [memory limit](#memory-limit) |
| `--threads` | - | - | half of the CPUs, follows the CPU limit | [self-tuning](#self-tuning) |
| `--cache-mb` | `KARELADB_CACHE_MB` | `cache_mb` | `256`, at most a tenth of the memory limit | [result cache](performance-tips.md#result-cache) |
| `--sync-commits` | - | - | `always` | [performance tips](performance-tips.md#sync-commits) |
| `--http-threads` | `KARELADB_HTTP_THREADS` | `http_threads` | the CPUs, 8 to 64 | [kareladb serve](#kareladb-serve) |
| `--http-gzip` | `KARELADB_HTTP_GZIP` | - | `remote` | [compressed answers](http-overview.md#gzip-answers) |
| `--max-connections` | `KARELADB_MAX_CONNECTIONS` | `max_connections` | `500` | [kareladb serve](#kareladb-serve) |
| `--lanes` | `KARELADB_LANES` | - | `on` | [priority lanes](#lanes) |
| `--heavy-ms`, `--heavy-slots`, `--heavy-queue` | `KARELADB_HEAVY_MS`, `KARELADB_HEAVY_SLOTS`, `KARELADB_HEAVY_QUEUE` | - | `100`, half of the CPUs, half of the HTTP threads (at least 4) | [priority lanes](#lanes) |
| `--read-slots` | `KARELADB_READ_SLOTS` | - | `auto` (the CPUs, at least 2) | [read slots](#read-slots) |
| `--timer-workers` | `KARELADB_TIMER_WORKERS` | `timer_workers` | `3` | [timers](timers.md) |
| `--tcp-keepalives-idle`, `--tcp-keepalives-interval`, `--tcp-keepalives-count` | `KARELADB_TCP_KEEPALIVES_IDLE`, `KARELADB_TCP_KEEPALIVES_INTERVAL`, `KARELADB_TCP_KEEPALIVES_COUNT` | `tcp_keepalives_idle`, `tcp_keepalives_interval`, `tcp_keepalives_count` | `0` (the system's) | [idle and vanished clients](server-activity.md#idle-clients) |
| `--lock-timeout` | `KARELADB_LOCK_TIMEOUT` | `lock_timeout_ms` | `5s` | [lock timeout](transactions.md#lock-timeout) |
| `--idle-in-transaction-timeout` | `KARELADB_IDLE_IN_TRANSACTION_TIMEOUT` | `idle_in_transaction_timeout_ms` | `30s` | [idle transactions](transactions.md#idle-timeout) |
| `--reader-yield` | `KARELADB_READER_YIELD` | - | `on` | [reader yield](transactions.md#reader-yield) |
| `--pin-threads` | `KARELADB_PIN_THREADS` | - | `auto` | [pinning threads](#pin-threads) |
| `--per-table-reads` | `KARELADB_PER_TABLE_READS` | - | `on` | [per-table reads](transactions.md#per-table-reads) |
| `--snapshot-reads` | `KARELADB_SNAPSHOT_READS` | - | `off` | [snapshot reads](transactions.md#snapshot-reads) |
| `--snapshot-index-rows` | `KARELADB_SNAPSHOT_INDEX_ROWS` | - | `1000000` | [kareladb serve](#kareladb-serve) |
| `--table-writers` | `KARELADB_TABLE_WRITERS` | - | `one` | [several writers of one table](transactions.md#shared-writers) |
| `--tail-files` | `KARELADB_TAIL_FILES` | - | `off` | [tail files](partitions-and-dedup.md#tail-files) |
| `--read-only-calls` | `KARELADB_READ_ONLY_CALLS` | - | `on` | [procedures](procedures.md#read-only-call) |
| `--scoped-ddl` | `KARELADB_SCOPED_DDL` | - | `on` | [schema changes](transactions.md#one-writer) |
| `--ddl-beside-writers` | `KARELADB_DDL_BESIDE_WRITERS` | - | `on` | [schema changes](transactions.md#one-writer) |
| `--skip-locked-beside` | `KARELADB_SKIP_LOCKED_BESIDE` | - | `off` | [FOR UPDATE](transactions.md#for-update) |
| `--log-lock-waits` | `KARELADB_LOG_LOCK_WAITS` | - | `off` | [lock waits](transactions.md#lock-table) |
| `--deadlock-timeout` | `KARELADB_DEADLOCK_TIMEOUT` | - | `1s` | [lock waits](transactions.md#lock-table) |
| `--warm-indexes` | `KARELADB_WARM_INDEXES` | - | `on` | [indexes](indexes.md#warm) |
| `--timezone` | `KARELADB_TIMEZONE` | `timezone` | UTC | [time zones](time-and-time-zones.md#session-time-zone) |
| `--pg-timestamptz` | - | - | off | [PostgreSQL port](postgres-protocol.md) |
| `--pg-int-division` | `KARELADB_PG_INT_DIVISION` | - | `off` | [integer division](postgres-protocol.md#int-division) |
| `--pg-compat` | `KARELADB_PG_COMPAT` | - | `off` | [PostgreSQL-compatible results](postgres-protocol.md#pg-compat) |
| `--trigger-retries` | `KARELADB_TRIGGER_RETRIES` | - | `3` | [deferred triggers](triggers.md#deferred) |
| `--max-trigger-jobs` | `KARELADB_MAX_TRIGGER_JOBS` | - | `10000` | [deferred triggers](triggers.md#deferred) |
| `--alert-webhook` | `KARELADB_ALERT_WEBHOOK` | `alert_webhook` | none | [alerts](triggers.md#deferred-alerts) |
| `--statement-timeout` | - | - | `60s` | [protection](protection.md#statement-timeout) |
| `--max-result-memory`, `--max-groups` | - | - | `1GB`, `5000000` | [protection](protection.md#memory-limits) |
| `--max-queries-per-user` | - | - | `32` | [protection](protection.md#max-queries-per-user) |
| `--rate-limit-ip`, `--rate-limit-user` | `KARELADB_RATE_LIMIT_IP`, `KARELADB_RATE_LIMIT_USER` | `rate_limit_ip`, `rate_limit_user` | `0` (no limit) | [rate limits](protection.md#rate-limits) |
| `--safe-updates` | - | - | off | [protection](protection.md#safe-updates) |
| `--read-only` | - | - | off | [protection](protection.md#read-only) |
| `--standby-of`, `--standby-token` | `KARELADB_STANDBY_OF`, `KARELADB_STANDBY_TOKEN` | - | off | [standby](standby.md) (`kareladb promote` makes it a primary) |
| `--drain-timeout` | `KARELADB_DRAIN_TIMEOUT` | - | `30s` (Docker image: `5s`) | [stopping](#stop) |
| `--tls-cert`, `--tls-key` | `KARELADB_TLS_CERT`, `KARELADB_TLS_KEY` | `tls_cert`, `tls_key` | off | [TLS](tls.md) |
| `--tls-required` | `KARELADB_TLS_REQUIRED` | - | `on` | [TLS](tls.md) |
| `--audit`, `--audit-keep-days` | - | - | `on`, `0` (keep for ever) | [audit log](audit-log.md) |
| `--activity-log-size` | - | - | `5000` | [monitor](console-monitor.md) |
| `--slow-query-ms` | `KARELADB_SLOW_QUERY_MS` | `slow_query_ms` | `1000` | [slow queries](http-server-info.md#slow-queries) |
| `--trash-days` | - | - | `7` | [trash](trash.md) |
| `--trash-max-mb` | `KARELADB_TRASH_MAX_MB` | `trash_max_mb` | a quarter of the data, at least 256 MB | [kareladb.conf](#kareladb-conf) |
| - | `KARELADB_TRASH_KEEP_HOURS` | `trash_keep_hours` | `1` | [kareladb.conf](#kareladb-conf) |
| - | `KARELADB_KEEP_VERSIONS` | `keep_versions` | `2` | [kareladb.conf](#kareladb-conf) |
| - | `KARELADB_WAL_ARCHIVE_MB` | `wal_archive_mb` | `1024` | [Settings page](console-settings.md#wal-archive) |
| - | `KARELADB_HTTP_FUNCTIONS`, `KARELADB_HTTP_TIMEOUT_MS` | `http_functions`, `http_timeout_ms` | off, `10000` | [calls from SQL](http-functions.md) |
| - | `KARELADB_WEB_DIR`, `KARELADB_HELP_DIR`, `KARELADB_SKILL_DIR` | `web_dir`, `help_dir`, `skill_dir` | next to kareladb | [folders](install-packages.md#folders) |
| `--backups` | `KARELADB_BACKUP_DIR` | `backup_dir` | `_backups` in the data folder | [backup schedule](backup-schedule.md#backup-settings) |
| `--backup-schedule` | `KARELADB_BACKUP_SCHEDULE` | `backup_schedule` | `off` | [backup schedule](backup-schedule.md) |
| `--keep-daily`, `--keep-weekly` | `KARELADB_BACKUP_KEEP_DAILY`, `KARELADB_BACKUP_KEEP_WEEKLY` | `backup_keep_daily`, `backup_keep_weekly` | `7`, `4` | [backup schedule](backup-schedule.md) |
| `--backup-command` | `KARELADB_BACKUP_COMMAND` | `backup_command` | none | [backup command](backup-schedule.md#backup-command) |
| `--backup-copy` | - | - | none | [backup schedule](backup-schedule.md) |
| `--backup-warn-hours` | - | - | `26` | [backup schedule](backup-schedule.md) |
| - | `KARELADB_LAZY_OPEN` | - | `on` | [kareladb serve](#kareladb-serve) (start-up) |
| - | `KARELADB_SELF_TUNING_SECONDS` | - | `10` (`0` = only at start) | [self-tuning](#self-tuning) |
| - | `KARELADB_TTL_CHECK_MS` | - | `60000` | how often partitions past their `TTL` are dropped (100 to 86400000 ms) |
| - | `KARELADB_LEVEL_FROM_HEAP` | - | off | [memory limit](#memory-limit) |

- **What needs a restart:** everything, except `cache_mb`, `wal_archive_mb`, `http_functions` and `http_timeout_ms` saved on the [Settings page](console-settings.md), which apply at once. **Restart** on that page (`POST /api/restart`) re-reads `kareladb.conf`; a flag or an environment variable changes only when the process is started again (in Docker: the container is made again).
- **Docker:** the image's start script also reads `KARELADB_TOKEN`, `KARELADB_MEMORY`, `KARELADB_CONFIG`, `KARELADB_CORE_DUMPS` and `KARELADB_CORE_KEEP` ([Docker](install-packages.md#docker)). Every environment variable above works there too, with `-e`.
- **Which values** are in use now: the start-up lines, and `GET /api/settings` (admin), which says where each came from.

<a id="test-switches"></a>

### Switches for tests and comparisons

These environment variables turn one engine feature **off**, so its gain can be measured and a wrong answer can be traced to it. The answers stay the same, only slower. Do not set them on a server people use.

| Variable | Turns off |
|---|---|
| `KARELADB_CHECKPOINT_BESIDE_WRITERS=off` | loads (`POST /write`) going on while a save (checkpoint) writes its files: with it off, every writer waits for the files again |
| `KARELADB_NO_ZONE_MAPS` | skipping partitions and blocks by their saved min and max ([EXPLAIN](explain.md)) |
| `KARELADB_NO_COLUMN_MASK` | building only the columns a query names |
| `KARELADB_NO_SYMBOL_PRUNING` | skipping partitions that do not hold the symbol asked for |
| `KARELADB_NO_TIME_SPANS` | cutting a scan to the time range asked for |
| `KARELADB_NO_PARTITION_ANSWERS` | answering `count`, `min`, `max`, `sum` from saved partition stats |
| `KARELADB_NO_LATEST_PARTITIONS` | `LATEST ON` read from the newest partition of each symbol |
| `KARELADB_NO_NEWEST_FIRST` | `ORDER BY time DESC LIMIT n` reading the newest partitions first |
| `KARELADB_NO_TEXT_KEYS` | `GROUP BY` a `STRING` column in the column engine |
| `KARELADB_NO_VECTOR_EXPR`, `KARELADB_NO_VECTOR_CASE`, `KARELADB_NO_VECTOR_DISTINCT` | `a + b` between columns, `sum(CASE WHEN ...)` and `count(DISTINCT col)` in the column engine |
| `KARELADB_NO_UNION_PUSHDOWN` | grouping each part of a `UNION ALL` on its own ([limits](limits.md)) |
| `KARELADB_NO_DISTINCT_GROUP` | `SELECT DISTINCT` and `UNION` run as a `GROUP BY` of every column ([DISTINCT](select.md#distinct)) |
| `KARELADB_NO_VIEW_PUSHDOWN` | moving a `WHERE` into a view |
| `KARELADB_NO_SUBQUERY_STREAM` | streaming the rows of a subquery into the grouping |
| `KARELADB_NO_JOIN_LOOKUP` | a join done by key lookups |
| `KARELADB_NO_JOIN_PLACES` | a hash join that points at the joined table's rows instead of copying them |
| `KARELADB_NO_KEY_STRETCH` | narrowing a scan to the keys an index found |
| `KARELADB_NO_POST_WINDOW_FILTER`, `KARELADB_NO_WINDOW_TOP_PER_KEY`, `KARELADB_WINDOW_NO_FAST`, `KARELADB_WINDOW_NO_VECTOR_SCAN` | the fast paths of window functions |
| `KARELADB_NO_INSERT_STREAM`, `KARELADB_NO_INSERT_RUNS`, `KARELADB_NO_INSERT_APPLY` | `INSERT ... SELECT` writing while it reads, keeping rows as columns, and applying batches before the commit ([memory limit](#memory-limit)) |
| `KARELADB_NO_BATCH_DEDUP` | the batch key check of loads into a `DEDUP KEY` table ([dedup](partitions-and-dedup.md)) |
| `KARELADB_NO_FOREIGN_PUSH` | running a `SELECT` of another database's tables in that database ([cross-database queries](cross-database-queries.md)) |
| `KARELADB_NO_VECTOR_PRESELECT` | the column engine finding the rows of a row-engine read of a small table (a `SELECT` or `INSERT ... SELECT` that works out values per row) |
| `KARELADB_NO_PREFETCH` | reading a partition file's columns several at once from a slow disk (a Windows folder mounted into Docker) |
| `KARELADB_MV_NO_DEFER` | waiting with the refresh of a materialized view while its table takes a bulk load ([views](views.md#materialized-view)) |

- Set them to `1`. Some also read `0` as "off" (the feature stays on), others do not: to turn a feature back on, leave the variable out.
- Two more for tests: `KARELADB_CACHE_VERIFY=1` computes every result cache hit again and counts the ones that differ ([server info](http-server-info.md)), and `KARELADB_INDEX_MAX_VISITS=N` gives up index order after N index rows that fail the other conditions.
- `KARELADB_UP_DEBUG`, `KDB_TEST_HIDE_FEATURES` and `KDB_TEST_DEFAULT_OPEN_DELAY_MS` are for KarelaDB's own tests.
- `KARELADB_WRITE_TRACE=1` prints one line per `POST /write` and `/imp` request, and per materialized view refresh, to the server's error output with the time each step took (parse, sort, queue, lock, log, apply, sync): for finding where a load spends its time.

<a id="banner"></a>

## What kareladb serve prints

Syntax:

```sql
KarelaDB <version>
  console   http://127.0.0.1:9900
  help      not installed (...)          (only when the help pages are missing)
  postgres  127.0.0.1:8832 (...)
  data      <folder> (from --data-dir | kareladb.conf | KARELADB_DATA_DIR | program folder; one folder per database)
  default   <name> (used when a request names no database)
  backups   <dir>/<database name> (from --backups | kareladb.conf | KARELADB_BACKUP_DIR | default) | off (...)
  copy      after each backup: <command> (from ...)   (only with a backup command)
  access    no token | token required | login required (N users)
  commits   synced to disk before they are confirmed | synced every 10 ms
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    3.00 GB for the whole process (--memory-limit); table data 1.00 GB of it (--memory)
  cpu       2 CPUs of the machine's 16 (cgroup v2 cpu.max 2.00); 1 query thread (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 60s, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log on (SHOW AUDIT)
  schedule  backups daily 16:00, next ...        (only with --backup-schedule)
  recovery  manifest copy: a, last shutdown: clean
Press Ctrl+C to stop.
```

| Line | Meaning |
|---|---|
| `console` | Open this address in a browser for the [web console](web-console.md). The help is at `/help`. When the console files are missing, a second line says so; the page at this address lists the folders KarelaDB looked in ([folders](install-packages.md#folders)). |
| `help` | Only when the help pages are not installed: build them with `node tools/help/build_help.mjs` and put them next to the program as `help/` |
| `postgres` | The PostgreSQL port and how to log in there. Not shown with `--pg-port 0`. |
| `data` | The data folder and where its name came from, or the one folder served |
| `default` | The database used when a request names no database |
| `backups` | Where `BACKUP DATABASE` writes and where that came from, or `off` |
| `copy` | Only with a [backup command](backup-schedule.md#backup-command): what runs after each backup |
| `access` | `no token`, `token required`, or `login required (N users)` |
| `commits` | `--sync-commits always` or `batch` |
| `readers` | Whether a `SELECT` waits for a long trigger or `CALL` ([reader yield](transactions.md#reader-yield)), and after how long an idle open transaction is rolled back ([idle transactions](transactions.md#idle-timeout)) |
| `memory` | The [memory limit](#memory-limit) and where it came from, and the table data share (`--memory`). Without a limit: `no limit for the whole process`. A `warning` line follows when `--memory` is more than 60% of the limit. |
| `cpu` | The CPUs the process may use and what decided it (`the machine's`, a container's `cgroup v2 cpu.max`, `cgroup v1 cpu.cfs_quota_us`, `affinity`, or a Windows `job object CPU rate`), and the query threads chosen from it ([self-tuning](#self-tuning)) |
| `pinning` | With `--pin-threads on`, or with `auto` inside a CPU quota: the CPUs the threads are pinned to, out of the CPUs the process may run on, or why nothing was pinned ([pinning threads](#pin-threads)) |
| `limits`, `safety` | The [protection](protection.md) settings in force |
| `schedule` | Only with `--backup-schedule`: the schedule and the next run ([backup schedule](backup-schedule.md)) |
| `recovery` | What happened when the default database opened: `last shutdown: clean`, or `not clean (crash or kill)` and how many log records were replayed. Repaired or damaged files are listed here too. |

- With `--bind 0.0.0.0` the banner adds `(listening on all network interfaces)` and a **NOTE** that passwords and tokens travel unencrypted.
- While it runs, the server prints **one line per HTTP request**: the local time, the method, the path, the status and the milliseconds, like `2026-09-11 14:05:10  GET /exec 200 3 ms`. The query text is not printed.
- Failed logins are printed too, with the time, the user name and the address (never the password).
- To keep this output, send it to a file: `kareladb serve --data-dir E:\kdb-data > E:\kdb-logs\serve.txt`.
- The default database of the data folder is opened at start (so a locked or damaged one is reported at once). When it does not exist yet, the banner says `the default database is created when it is first used`.

**Command line: A data folder with users**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
kareladb serve
```

Output:

`> kareladb user add admin --role admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb serve`

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      ./kdb-data (from KDB_DATA_DIR; one folder per database)
  default   default (used when a request names no database)
  backups   ./kdb-data/_backups/<database name> (from default)
  access    login required (1 user)
  capacity  32 HTTP threads (default), 500 PostgreSQL connections (default), lock wait 5 s (default)
  lanes     reads using 100 ms of CPU (three times in a row) wait for one of 16 heavy slots, at most 16 HTTP in line (--lanes on)
  reads     32 reads run at once (the CPUs, at least 2; follows the CPU limit), the rest wait in line (--read-slots)
  commits   synced to disk before they are confirmed (--sync-commits always)
  time zone Asia/Katmandu (the computer's); also timers and backup schedules
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    26.95 GB for the whole process (85% of the machine's memory); table data 512.0 MB of it (--memory)
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log on (SHOW AUDIT)
  logs      slow queries >= 1000 ms to ./kdb-data/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  the default database is created when it is first used

Press Ctrl+C to stop.
```

<a id="self-tuning"></a>

## Self-tuning to the CPU and memory limits

Inside `docker run --cpus=1` a program still sees every core of the host. KarelaDB reads the real limits instead, and sizes itself from them:

| Limit | Where KarelaDB reads it | What follows it |
|---|---|---|
| CPUs | Linux: cgroup v2 `cpu.max` (also a parent cgroup's), else cgroup v1 `cpu.cfs_quota_us`; the CPUs the process may run on (`--cpuset-cpus`). Windows: the affinity mask and a job's CPU rate cap. `--cpus=1.5` counts as 2. | query threads (half of the CPUs, at least 1), and so every parallel scan, sort, load and index build; HTTP threads at start |
| Memory | cgroup v2 `memory.max`, cgroup v1 `memory.limit_in_bytes`, a Windows job's memory limit | the [memory limit](#memory-limit) (85%), and with it the unsaved-changes share that forces a checkpoint (a quarter). At start also the result cache (at most a tenth of the limit) and, without `--memory`, the table data (at most 40%). |

- **While it runs:** KarelaDB reads the limits again every 10 seconds. After `docker update --cpus=4 kareladb` the query threads grow at once; after `--cpus=1` the extra threads stop when their current piece of work ends, so no query is cut short. No restart.
- **Set by hand stays:** `--threads`, `--memory-limit` and `KARELADB_MEMORY_LIMIT` are never changed.
- **The log:** each change is one line, like `self-tuning: CPU limit 1 CPU (cgroup v2 cpu.max 1.00, machine 16) -> 4 CPUs (cgroup v2 cpu.max 4.00, machine 16); query threads 1 -> 2`. It shows in the console's activity panel too.
- **See it:** `limits` in [`GET /api/stats`](http-server-info.md#api-stats), and the `cpu` line at start.
- **How often:** `KARELADB_SELF_TUNING_SECONDS` (default 10; `0` = read only at start).

<a id="pin-threads"></a>

## Pinning threads to CPUs

**`auto` (the default, Linux):** a container started with `docker run --cpus=2` on a 32-core host gets two cores' worth of time in every period, but its threads may run on all 32 cores. KarelaDB has a thread per PostgreSQL connection, 8 HTTP workers and the query threads, so 32 clients ran 32 threads at once on 32 cores: they spent the two cores' time in a fraction of the period, then every thread stood still for the rest of it, and while they ran they met on every shared lock. Measured (2026-10-04, a 0.1 ms key lookup over the PostgreSQL port from 32 connections): 5,965 requests a second that way, 39,000 when the same server was kept on two cores with `taskset`. So inside a CPU quota smaller than the CPUs the process may run on, KarelaDB pins **all** its threads to the quota's worth of CPUs:

- **Which CPUs:** `--cpus 2` gives two; one per physical core when the host has hyper-threads (the two threads of one core share its units: 32,000 a second on two siblings, 39,000 on two cores), from the highest numbers of the CPUs the process may run on (the cgroup cpuset, `--cpuset-cpus`, `taskset`). The same CPUs come out at every restart.
- **Follows `docker update --cpus`:** the [self-tuning](#self-tuning) looks at the limit every 10 s. A smaller or bigger quota moves the threads; a quota that goes away, or one that covers every CPU, gives them all their CPUs back. Each change is one log line, like `threads pinned to CPUs 29,31 of 0-31 (41 threads; CPU quota 2.00 of 32 CPUs; --pin-threads auto)`.
- **Nothing to do:** on a machine without a quota, or when the quota is as big as the cpuset (`--cpus=2 --cpuset-cpus=4-5`), `auto` pins nothing and the server runs as before.

**`on`:** the kernel moves a busy thread from core to core, and each move leaves the CPU cache it had warmed behind. `--pin-threads on` (or `KARELADB_PIN_THREADS=on`) keeps KarelaDB's threads in place:

| Threads | Where they run |
|---|---|
| HTTP workers, PostgreSQL connections, query threads | one CPU each, taken in turn |
| the checkpoint thread, timer jobs, the backup schedule | any of the pinned CPUs |

- **Which CPUs:** as many as KarelaDB may use ([self-tuning](#self-tuning): `--cpus`, cgroup `cpu.max`), taken from the lowest numbers of the CPUs the process may run on. In `docker run --cpus=2 --cpuset-cpus=4-7` that is CPUs 4 and 5.
- **Read at start:** the CPUs are chosen once. After `docker update --cpus` restart the server to pin to the new count.
- **When it pays:** on a host or container given to KarelaDB alone. A pinned thread cannot move to an idle core, so when two busy workers share one CPU the second waits.

**Both:**

- **See it:** the start-up line `pinning   workers pinned one CPU each to CPUs 0-3 of 0-15 (--pin-threads on)` or `pinning   threads pinned to CPUs 29,31 of 0-31 (...; --pin-threads auto)`, and `pinned_cpus` (`""` = not pinned) and `pinned_threads` in `limits` of [`GET /api/stats`](http-server-info.md#api-stats). On Linux, `grep Cpus_allowed_list /proc/<pid>/task/*/status` shows each thread's CPUs.
- **Windows:** ignored. With `on` the server says `warning: --pin-threads: off: --pin-threads works on Linux only; ignored here` and runs as without it; `auto` says nothing.
- **Check it in Docker:** `docker build --target pin-test --output type=local,dest=build/pin -f docker/Dockerfile .` starts KarelaDB inside `taskset -c 0-1` and writes every thread's `Cpus_allowed_list` to `build/pin/threads.txt` and the verdict to `build/pin/status`. It makes no image.

<a id="lanes"></a>

## Priority lanes

On a server with one or two CPUs, a few heavy reports (a big `GROUP BY` over all rows) take the whole processor, and a chart that answers in 2 ms alone takes 30 to 60 ms. Priority lanes stop that. Every statement goes into one lane before it runs:

| Lane | Which statements | What happens |
|---|---|---|
| `fast` | a statement whose shape ran in under 20 ms last time; anything with priority `high` | runs at once |
| `normal` | a shape not seen yet, writes, `BEGIN`, `SET`, `SHOW`, and everything between | runs at once |
| `heavy` | a read (`SELECT`, `WITH`, `VALUES`, `EXPLAIN`) whose shape used `--heavy-ms` of CPU or more **the last three times** it ran; anything but `BEGIN`, `COMMIT`, `SET` and `SHOW` with priority `low` | waits for a heavy slot, first come first served, then runs at a lower CPU priority |

- **The shape** is the statement with its values taken out, as in `pg_stat_statements`: `WHERE sym = 'A'` and `WHERE sym = 'B'` are one shape, and so are a candle query over one day and over five years. The server remembers what each shape cost; nothing is saved to disk.
- **CPU time, not the clock:** a chart that took 600 ms only because the server was busy used a few ms of CPU. It is not a report. The work of the query's helper threads counts too.
- **Three heavy runs in a row, not one or two:** the first chart after a restart may be slow once while it reads its data from disk, and one user zooming a chart out twice must not put everybody's charts of that shape in line. Once heavy, a shape leaves the heavy lane after one clearly light run (under half of `--heavy-ms`, as any chart is), so a report close to the line does not flap.
- **A report never seen before** starts in the `normal` lane. Once it has run 250 ms by the clock, it holds a heavy slot until it ends, so a known report waits for it.
- **Slots:** `--heavy-slots` heavy statements run at the same time (half of the CPUs, at least 1). The rest wait, first come first served.
- **The HTTP line is short:** a waiting HTTP request holds one of the server's request threads, so at most `--heavy-queue` HTTP requests wait. Past that, a read that is heavy only by its history runs at once in the `normal` lane (as before the lanes; `overflowed` in `/api/stats` counts them), and a request sent with priority `low` gets `503` with `Retry-After: 1` and the message `server is busy: ...`. Nothing of it ran.
- **PostgreSQL clients wait:** a connection has its own thread, so its statements are not counted against `--heavy-queue` and are never refused. They wait up to their statement timeout.
- **The wait is limited by the [statement timeout](protection.md#statement-timeout),** but it does not eat into the time to run: once let in, the timeout starts again, so a report that finished in time before still does. A statement that waits longer than its timeout ends with the usual timeout error (HTTP `408`, PostgreSQL `57014`). `DELETE /exec/<id>`, `pg_cancel_backend` and a client that goes away end the wait at once.
- **Many reports at once now take turns.** A batch of parallel reports finishes one slot at a time instead of all sharing the CPU; each may take longer from send to answer, but none is refused unless it asked for priority `low` over HTTP.
- **Never inside a transaction:** a statement of an open `BEGIN` ... `COMMIT` never waits (it may hold tables a heavy statement needs). It runs in the `normal` lane.
- **Answers do not change.** The lanes only decide when a statement starts, and at what CPU priority it runs.
- **CPU priority:** on Windows, heavy statements run below normal priority. On Linux only when the process may raise a thread's priority again (`CAP_SYS_NICE`); a plain `docker run` may not, so there the slots do the work alone. `cpu_priority` in `/api/stats` says which.

Choose a lane by hand:

| How | Where |
|---|---|
| `SET kdb.priority = high \| normal \| low` | a PostgreSQL connection or an [HTTP session](http-sessions-and-cursors.md); `RESET kdb.priority` goes back; `SHOW kdb.priority` shows the one in use |
| `X-KDB-Priority: high \| normal \| low` | one HTTP request |
| `ALTER USER reports SET kdb.priority = low` | every statement of that user (admin only; `RESET kdb.priority` takes it away) |

- `high` never waits and never counts as heavy. Only an admin, or a user an admin set to `high`, may ask for it: otherwise every report could mark itself `high`. A session may always go **lower** than its user's setting.
- `normal` is the default: the server decides by what the shape cost before.
- `low`: a report, an audit or a rebuild that may wait for the charts.

**Measured** (2026-09-25, Windows, the process pinned to 2 CPUs and then 1, `bench/lanes.mjs`): a candle page of 300 bars every 10 ms while 4 clients ran a `GROUP BY` over 4 million rows back to back (about 0.5 s each alone). Times of the candle page:

| CPUs | | p50 | p95 | p99 | reports finished in 20 s |
|---|---|---|---|---|---|
| 2 | alone | 1 ms | 2 ms | 4.3 ms | - |
| 2 | with the reports, before lanes | 1.5 ms | 34.7 ms | 64 ms | 100 |
| 2 | with the reports, lanes on | 0.9 ms | 2.1 ms | 5.8 ms | 57 |
| 1 | alone | 3.6 ms | 13.6 ms | 18.6 ms | - |
| 1 | with the reports, before lanes | 24 ms | 109 ms | 170 ms | 44 |
| 1 | with the reports, lanes on | 3.9 ms | 13.1 ms | 14.5 ms | 43 |

Judged by CPU time over three runs (the default since 2026-09-25, `--heavy-ms 100`), the same test gave a candle p95 of 2.0 to 2.4 ms on 2 CPUs (63 to 65 reports) and 1.8 ms on 1 CPU (53 reports), with 1.7 to 2.1 ms alone. The charts stay as fast as alone. On 2 CPUs the reports take turns on one of them, so fewer finish while charts are served; `--heavy-slots 2` let 69 through, but the chart p99 went to 10 ms. The 1-CPU run was on a busier machine, so its "alone" numbers are higher.

**See it:** `lanes` in [`GET /api/stats`](http-server-info.md#api-stats) (slots in use, how many wait, the waits since start per lane), the **Lanes** card of the [Monitor](console-monitor.md), and `lane` / `waiting` on each running statement. A waiting statement shows `Lane` / `heavy queue` in `pg_stat_activity.wait_event_type` / `wait_event`.

<a id="read-slots"></a>

### Read slots

Since 2026-10-02, reads run at most `--read-slots` at a time (by default as many as the CPUs the process may use, at least 2). The rest wait in line, first come first served, and each read that ends lets the next one in.

Why: a container limited with `docker update --cpus 2` still sees every core of the machine. With 30 clients, 30 reads ran at once on 30 cores until the 2-CPU budget was spent, and they spent most of that budget waking each other up on shared locks instead of reading. Taking turns does the same work with a quarter of the CPU.

| Statement | Takes a read slot? |
|---|---|
| a read (`SELECT`, `WITH`, `VALUES`, `EXPLAIN`) in the `fast` or `normal` lane | yes |
| a read inside `BEGIN` ... `COMMIT` | no: it may hold tables a running read needs |
| a write, `CALL`, DDL, `BEGIN`, `SET`, `SHOW` | no |
| a read sent with priority `high` | no |
| a heavy read | no: it has its own [heavy slots](#lanes) |

- **A long read never holds the line up:** a read counts against the slots only for its first 10 ms. A report, or a read that waits for a writer or the disk, stops counting then and the next read goes in.
- **The slots follow the CPU limit:** after `docker update --cpus 4` there are 4 (checked every 10 s, as the [self-tuning](#self-tuning) does).
- **The wait is limited by the statement timeout,** and a cancel ends it at once. `pg_stat_activity` shows `Lane` / `read slot` while a read waits.
- **Answers do not change.** The slots only decide when a read starts.
- **See it:** `lanes.read_slots` in [`GET /api/stats`](http-server-info.md#api-stats): `slots`, `used`, `waiting`, and since start `waited`, `wait_ms_total`, `wait_ms_max`. The `reads` line at start says how many.

**Measured** (2026-10-02, Linux build in WSL, the process limited to 2 CPUs with a CPU quota as `docker --cpus 2` does, 32 HTTP threads as the container has; 523,233 day candles of 544 symbols; 006's day-candle mix: last 500 bars, `SAMPLE BY 7d` last 300, `SAMPLE BY 1M` last 200, the whole history; result cache off). Requests a second:

| Clients | 1 | 10 | 25 | 50 | 100 | 200 |
|---|---|---|---|---|---|---|
| before | 1,085 | 1,303 | 592 | 464 | 469 | 500 |
| read slots | 1,734 | 3,035 | 2,630 | 2,685 | 2,285 | 2,526 |

The CPU per request fell from 4.4 ms to 0.75 ms at 50 clients. Over the PostgreSQL port at 50 clients: simple queries 1,042 -> 2,682 a second, prepared statements 514 -> 2,253.

<a id="memory-limit"></a>

## Memory limit for the whole process

Syntax:

```sql
kareladb serve --memory-limit 3GB        (or 3072 = megabytes; 0 or off = no limit)
KARELADB_MEMORY_LIMIT=3GB                (the environment; the flag wins)
```

`--memory` limits only the table data kept loaded. Unsaved changes, indexes, the rows of running queries and what the allocator keeps come on top. `--memory-limit` is one limit for all of it, so the server slows down or refuses work instead of being killed.

KarelaDB looks ten times a second at two numbers: the bytes its objects hold (the heap) and what the system says the process holds (resident). The larger one is **in use**, so memory the allocator keeps after a free counts too:

| Level | When | What happens |
|---|---|---|
| green | under 80% of the limit | nothing |
| yellow | 80% to 95% | memory is given back: on Linux freed memory goes back to the system first, then loaded partitions are unloaded (idle databases first), then kept query results (the result cache) when that was not enough |
| red | 95% and over | also: a **quick** statement runs at once in a small reserve; any other **new** statement waits up to 2 s for memory, then fails with `memory full: ...` |

- **Over by the resident size alone:** when the heap is under 80% and only the resident size is high, the excess is free memory the allocator kept and could not give back. New statements reuse it first, so the level stops at **yellow** there: nothing is refused and nothing is stopped for it. Partitions and kept results are given back once; while that does not bring the level down it is not done again for 30 s, then 1, 2, 4 and up to 10 minutes (`resident_holds` in `/api/stats` counts the looks that held back), so queries do not read their partitions from disk again and again. `KARELADB_LEVEL_FROM_HEAP=1` goes back to working the level out from the heap alone (`level_from` says `heap`).

- **The reserve for quick statements:** at red, 8 statements at a time run at once, each allowed about 1/256 of the limit (4 to 64 MB; 12 MB under 3 GB). Only reads and name changes use it: `SELECT`, `VALUES`, `EXPLAIN`, `WITH` (without a write in it), `CREATE TABLE` / `VIEW` / `DATABASE` / `USER` without data, `DROP`, `TRUNCATE`, `GRANT`, `BEGIN`. Writes and loads - `INSERT`, `UPDATE`, `DELETE`, `COPY`, `/write`, `/imp`, `CREATE INDEX`, `ALTER`, `CALL`, and text with a second statement after `;` - wait as before, so a loader backs off at red and cannot take the places `SELECT 1` needs. One that needs more first waits, like any statement at the door, up to 2 s for the server to come below red (right after a big statement its memory often takes a second to come back), and then runs on without the cap. Only when memory stays full is it stopped with `memory full: the server is at its memory limit ..., so this statement ran in the small reserve kept for quick statements, and it needed more than the 12 MB ...` (same codes as below). `reserve_in_use`, `reserve_admitted` and `reserve_lifted` in `/api/stats` show it.

- **The error:** `memory full: 2.9 of 3.0 GB in use (table data 1.0, key maps 0.4, indexes 0.3, pending 0.2, result cache 0.1, queries and other 0.9, allocator 0.2); try again or raise --memory-limit`. HTTP **503** with `Retry-After: 2`; on the PostgreSQL port SQLSTATE **53200** (`out_of_memory`). Nothing of the statement ran, so it is safe to send again.
- **Over the limit itself:** a statement that is already running keeps going at red. If the heap stays at red, or memory still passes the limit after it is given back, the running statement that holds the most memory is stopped: `memory full: the server went over its memory limit while this statement ran, and it held the most memory (about N MB of rows and working memory), so it was stopped ...`, with the same numbers. Same codes: HTTP **503**, PostgreSQL **53200**. At most one statement is stopped every 0.3 s this way, and only one that holds at least 2% of the limit. A statement that grows while the heap is over the limit and holds at least an eighth of it stops itself at once, without waiting for the next look. The others go on, and the server keeps running; `stopped` in `/api/stats` counts them. Without this, the system could kill the whole server.
- **Working memory of one statement:** what a query keeps while it works counts too: the values `string_agg`, `array_agg`, `median`, `percentile_*` and `agg(x ORDER BY y)` keep, the sets of `count(DISTINCT ...)` and `SELECT DISTINCT`, and the groups of `GROUP BY` (a join's table and its hash count toward what the statement holds as well). One statement may keep a quarter of the limit in such working memory (and no more than `--max-result-memory`); past that it is stopped: `memory full: this statement needed more than N MB of working memory ...` (HTTP **503**, PostgreSQL **53200**). A `GROUP BY` with many groups writes the groups that do not fit to temporary files first ([protection](protection.md#memory-limits)), and does so earlier when the server is at red. Four `string_agg` over a join took a server with a 3 GB limit to 7.1 GB before this was counted.
- **Held back at red:** SQL over HTTP (`/exec`, `/exp`) and the PostgreSQL port (quick statements through the reserve first), and loads (`/write`, `/imp`, `COPY`), which never use the reserve. **Never held back:** `/health`, `/api/stats` and the other pages that run no SQL, and `ROLLBACK`, `COMMIT`, `SET`, `SHOW` (ending a transaction frees memory).
- **Unsaved changes:** when the changes not yet written to partition files pass a quarter of the limit, the database holding the most writes them out. A long `CALL`, trigger or `BEGIN ... COMMIT` no longer holds that off: between two of its statements KarelaDB writes the **committed** changes of other writers and keeps the transaction's own.
- **A transaction too big for memory:** its own changes stay in memory until `COMMIT`. When they pass a quarter of the limit it is stopped and rolled back: `transaction too big for memory: ...; split the work into smaller transactions` (HTTP 413, SQLSTATE `53200`). What counts is what the transaction keeps: about 600 bytes for a row written one by one, next to nothing for `DELETE FROM t` without `WHERE` (it drops the table's partitions and keeps them whole for a `ROLLBACK`), and about 50 bytes a row for a big `INSERT ... SELECT` into partitions the transaction emptied or that had no unsaved changes (the rows are kept as columns). So a procedure that rebuilds a table - `DELETE FROM t`, then `INSERT INTO t SELECT ...` of a million rows or two - runs again and again under `--memory-limit 3GB`.
- **A big `INSERT ... SELECT` into a table with a key** (`DEDUP KEY`, `PRIMARY KEY`), outside `BEGIN ... COMMIT`: past 65,536 rows it runs as a transaction of its own and puts each batch of rows into the table as soon as it is checked, instead of holding every row to the end. Into partitions with no unsaved changes of earlier statements a row then takes about 150 bytes until the commit, not about 1,100: a copy of millions of rows into a `PARTITION BY YEAR, SYMBOL(symbol)` candle table fits. It is still one statement: a bad row anywhere, or a repeated key, writes nothing, and readers see all of it or none. Its limit is half of `--memory-limit`: `memory full: this INSERT ... SELECT's N rows take about M MB until it commits, more than half of the memory limit ...; it was stopped and nothing was written. Copy in parts ...`. `KARELADB_NO_INSERT_APPLY=1` goes back to holding every row to the end.
- **`SELECT ... FROM otherdb.t`:** a `SELECT` that reads only tables of one other database runs in that database, so `SELECT count(*) FROM otherdb.t` is answered from its row counts and copies nothing ([cross-database queries](cross-database-queries.md)).
- **Small tables stay loaded:** a table wholly in memory and small (up to 1/32 of `--memory`, all of them together up to 1/8) is unloaded last, and never for another database or the memory limit. A sessions table read by every login is not dropped because another database scanned something big.
- **Default:** 85% of the container's memory limit (`docker run --memory 4g`). Without one (a plain `docker run`, or no container), 85% of the machine's memory; in Docker Desktop that is Docker's VM. Set a smaller one when the machine runs other programs too, and `off` for no limit.
- **Room:** keep `--memory` well under the limit (at most about half), and `--max-result-memory` too ([protection](protection.md#memory-limits)): the table data, the changes and the queries share it.
- `GET /api/stats` shows the level and the numbers per kind in `memory_limit` ([server info](http-server-info.md)).

**Command line: A 3 GB limit for everything, 1 GB of it for table data** (sample data: sample)

```bash
kareladb serve ./market --memory 1024 --memory-limit 3GB
```

Output:

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      ./market
  backups   ./_backups/market (from default)
  access    no token
  capacity  32 HTTP threads (default), 500 PostgreSQL connections (default), lock wait 5 s (default)
  lanes     reads using 100 ms of CPU (three times in a row) wait for one of 16 heavy slots, at most 16 HTTP in line (--lanes on)
  reads     32 reads run at once (the CPUs, at least 2; follows the CPU limit), the rest wait in line (--read-slots)
  commits   synced to disk before they are confirmed (--sync-commits always)
  time zone Asia/Katmandu (the computer's); also timers and backup schedules
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    3.00 GB for the whole process (--memory-limit); table data 1.00 GB of it (--memory)
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log off
  logs      slow queries >= 1000 ms to ./market/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 1 ms: manifest 0 ms, 1 files read 0 ms (8 table files left for their first use), log check 1 ms, replay 0 ms (0 transactions), clean-up 0 ms

Press Ctrl+C to stop.
```

**Command line: Too small a limit stops the start**

```bash
kareladb serve --memory-limit 10MB
```

Output:

```text
error: --memory-limit (or KARELADB_MEMORY_LIMIT) needs a size of at least 64MB, like 3GB or 3072 (megabytes), or off; not '10MB'
```

exit code 1

<a id="memory-warning"></a>

### A database far bigger than --memory

A database whose table files are more than 8 times `--memory` still works, but slowly in ways that look like a fault: a query over much of it, or a write into old partitions, reads the same files again and again. So when such a database opens, KarelaDB says so once:

```text
warning: /data/market: database market is 12.0 GB on disk and --memory is 1.5 GB (8x, shared by all open databases):
expect loads and evictions - queries over much of it, and writes into old partitions, read files again and again
and take seconds. Give KarelaDB more memory: --memory 6144 or more (KARELADB_MEMORY in Docker); ...
```

- It is printed when the database opens (at the start for the default database, else at its first use).
- `GET /api/stats` lists it in `warnings` and in that database's `memory_warning`; the console's Monitor shows it at the top.
- `GET /api/info` has it in `warning`.
- The fix: a bigger `--memory`, about half the data or more. Keep it under about half of `--memory-limit`.

<a id="many-databases"></a>

## Many databases

Syntax:

```sql
kareladb serve                         -- every database in the data folder, default 'default'
kareladb serve market                   -- every database, default 'market' (a name in the data folder)
kareladb serve --db market              -- the same
kareladb serve ./market                 -- only this folder
```

Without a folder path, one server serves **every** database in the data folder.

- A request chooses the database with `db=<name>` in the URL or the header `X-KDB-Database: <name>`. Without one it uses the default database (see [HTTP databases](http-databases.md)).
- `CREATE DATABASE`, `DROP DATABASE`, `SHOW DATABASES` and `USE` work in the console and over HTTP.
- A new database is a new sub-folder. A database made with `CREATE DATABASE` can be used at once.
- All databases share the `--threads`, the `--memory` and the `--cache-mb`: three databases with `--memory 256` keep 256 MB of table data together, not 768 MB.
- A server on a **folder path** serves only that folder. It cannot create or drop databases, and it has no users.

**Command line: The default database is 'reports'**

```bash
kareladb shell
> CREATE DATABASE reports;
kareladb serve --db reports --backups backups
```

Output:

`> kareladb shell`

```text
KarelaDB 0.2.0-dev shell on default (data folder ./kdb-data)
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> database 'reports' created
kareladb>
```

`> kareladb serve --db reports --backups backups`

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      ./kdb-data (from KDB_DATA_DIR; one folder per database)
  default   reports (used when a request names no database)
  backups   backups/<database name> (from --backups)
  access    no token
  capacity  32 HTTP threads (default), 500 PostgreSQL connections (default), lock wait 5 s (default)
  lanes     reads using 100 ms of CPU (three times in a row) wait for one of 16 heavy slots, at most 16 HTTP in line (--lanes on)
  reads     32 reads run at once (the CPUs, at least 2; follows the CPU limit), the rest wait in line (--read-slots)
  commits   synced to disk before they are confirmed (--sync-commits always)
  time zone Asia/Katmandu (the computer's); also timers and backup schedules
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    26.95 GB for the whole process (85% of the machine's memory); table data 512.0 MB of it (--memory)
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log on (SHOW AUDIT)
  logs      slow queries >= 1000 ms to ./kdb-data/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 1 ms: manifest 0 ms, 0 files read 0 ms, log check 1 ms, replay 0 ms (0 transactions), clean-up 0 ms

Press Ctrl+C to stop.
```

<a id="stop"></a>

## Stopping the server

Syntax:

```sql
Ctrl+C                 -- in the server's window (Windows, Linux, macOS)
kill -TERM <pid>       -- Linux, macOS (systemd: KillSignal=SIGINT or SIGTERM)
```

Press **Ctrl+C** in the server's window. The server prints `stopping...`, finishes its work, closes every database cleanly and prints `databases closed cleanly (N ms)` (or `database closed cleanly` for one folder). Then it ends with exit code `0`.

- SIGTERM (Linux, macOS) and closing the console window (Windows) also stop it cleanly. Closing the window gives it about 4 seconds, so it skips the drain below.
- **Drain.** Before it closes, the server lets requests that are already running finish, for up to `--drain-timeout` (default `30s`, or the `KARELADB_DRAIN_TIMEOUT` environment variable; the Docker image sets `5s`). Meanwhile the port stays open and new requests get HTTP **503** with `Retry-After: 2`. What still runs after that is cancelled and rolled back, and the log says `stopping: requests still running after ... (--drain-timeout); they are cancelled`.
- `POST /api/restart` does not drain: it stops running statements at once and starts again.
- A writer that waits for a busy table stops waiting as soon as the stop cancels it, so a long `--lock-timeout` never holds up a stop. That goes for SQL and for queued loads (line protocol, `/imp`, PostgreSQL `COPY`); nothing of a cancelled write is kept. The databases close side by side, each writing its clean-shutdown mark.
- Keep `--drain-timeout` below the time your service manager waits before it kills (`TimeoutStopSec`, `docker stop -t`). See [Docker](install-packages.md#docker-stop).
- A **second** Ctrl+C ends the process at once.
- **Killing** the process (Task Manager, `Stop-Process`, `kill -9`, a power cut) is safe: it is like a crash. Confirmed writes are in the log. The next start shows `last shutdown: not clean (crash or kill)` and replays the log, which can take longer for a big log.
- There is no Windows service mode yet. Run it in a window, or with Task Scheduler "At startup".

```ini
# /etc/systemd/system/kdb.service on Linux (not run here)
[Service]
User=kdb
ExecStart=/usr/local/bin/kareladb serve --data-dir /srv/kareladb/data --backups /srv/kareladb/backups
Restart=on-failure
KillSignal=SIGINT
TimeoutStopSec=60
```

<a id="start-errors"></a>

## Port in use, database in use

Syntax:

```sql
error: Already exists: port 9900 on 127.0.0.1 is already in use
error: the database is open in another program. Stop it first.
```

`kareladb serve` stops at once when it cannot use the port or the database.

| Message | Why | Fix |
|---|---|---|
| `port 9900 on 127.0.0.1 is already in use` | Another program (often another `kareladb serve`) listens on that port | `--port 9901`, or stop the other program |
| `Postgres protocol port: ...` | Port 8832 is in use | `--pg-port 8833`, or `--pg-port 0` to turn it off |
| `the database is open in another program` | A `kareladb shell`, `kareladb sql` or another server has the database open | Close it (look for `kareladb` in Task Manager) |
| `--threads needs a number from 1 to N` | More threads than half of the CPU threads | A smaller number |
| `--memory needs a number of megabytes` | Not a number | `--memory 2048` |
| `--memory-limit (or KARELADB_MEMORY_LIMIT) needs a size of at least 64MB` | Not a size, or under 64 MB | `--memory-limit 3GB`, or `off` |

**Command line: Too many threads**

```bash
kareladb serve --threads 100000
```

Output:

```text
error: --threads needs a number from 1 to 32 (this computer's CPU threads)
```

exit code 1
