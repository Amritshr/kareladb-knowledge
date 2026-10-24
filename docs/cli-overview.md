# The kareladb program

> What the kareladb program is, how it finds your databases, and what its exit codes mean.

- Category: Command line
- Keywords: command line, CLI, kareladb.exe, usage, exit code, $LASTEXITCODE, data folder, KARELADB\_DATA\_DIR, --data-dir, --config, kareladb.conf, database name, folder path, --help, -h, --version, kareladb help, kareladb help tutorial
- See also: [kareladb sql and kareladb shell](cli-sql-and-shell.md), [kareladb serve](cli-serve.md), [kareladb info, check, repair, dump-file](cli-maintenance.md), [kareladb user](cli-users.md), [Backup, check, repair and restore](backup-and-safety.md), [Databases and the data folder](databases.md)

`kareladb` is the one program you need. It runs SQL, the interactive shell, the server, backups and repairs.
It works in PowerShell, CMD, bash and zsh, on Windows, Linux and macOS.

A **database** is a folder on the disk. Many databases can live in one **data folder** (one sub-folder per database).
Most commands take a `<db>` argument: the **name** of a database in the data folder, or the **path** of a database folder.

| Command | What it does | Help |
|---|---|---|
| `kareladb sql` | Runs SQL once and prints the result | [kareladb sql](cli-sql-and-shell.md#kareladb-sql) |
| `kareladb shell` | A prompt where you type SQL | [kareladb shell](cli-sql-and-shell.md#kareladb-shell) |
| `kareladb serve` | The server: web console, HTTP API, PostgreSQL port | [kareladb serve](cli-serve.md#kareladb-serve) |
| `kareladb info`, `kareladb check`, `kareladb repair`, `kareladb dump-file` | Look at a database, find and fix damage | [maintenance](cli-maintenance.md) |
| `kareladb backup`, `kareladb backups`, `kareladb verify-backup`, `kareladb restore` | Backups | [backup and safety](backup-and-safety.md) |
| `kareladb user ...` | Users of the server | [kareladb user](cli-users.md) |
| `kareladb version`, `kareladb help [<topic>]` | Version; the list of commands and of every help topic, one topic, or a tutorial chapter, in the terminal | below |
| `kareladb upgrade` | Make an older database ready for this KarelaDB (backup, feature list, check) | [versions and upgrades](versions.md) |
| `kareladb features` | The stored-format features a database uses now, and what uses them | [going back](versions.md#downgrade) |
| `kareladb downgrade` | Let an older KarelaDB open the data again, when it uses nothing newer (backup, feature list, check) | [going back](versions.md#downgrade) |
| `kareladb skill`, `kareladb skill install` | Print, or install for Claude Code, the file that teaches an AI assistant how to use KarelaDB | [the Claude skill](install-packages.md#skill) |

<a id="help"></a>

## kareladb help

Syntax:

```sql
kareladb
kareladb help
kareladb --help
kareladb -h
kareladb help <topic>
kareladb help tutorial [<chapter>]
```

Prints the version and a short list of every command and option, then the list of help topics - the same pages a running server shows at `/help` - with their titles. `kareladb help <topic>` prints one topic in the terminal (the Markdown source in a source checkout, the built page as text in a package); a word that is not a topic lists the topics whose name contains it. `kareladb help tutorial` lists the tutorial chapters and `kareladb help tutorial 17` prints one (the tutorial is part of the source checkout only).

- **Exit code:** `0` for `kareladb help`, `--help` and `-h`. `1` for `kareladb` with no command, for an unknown command, and for a topic that does not exist.
- **Notes:** an unknown command (for example a typing mistake like `kareladb bakup`) also prints this list, with exit code `1`. The topics come from the help folder the program finds (`help_dir` in kareladb.conf, `KARELADB_HELP_DIR`, next to the program, or the checkout's `docs/help/site`); without one, only the command list is printed.

**Command line: The list of commands**

```bash
kareladb help
```

Output:

```text
KarelaDB 0.2.0-dev (KARELA DataBase)

Usage:
  kareladb info    <db>                          show files, versions and log position
  kareladb check   <db> [--no-audit-chain]       read every block and log record, report damage;
                                                 then check the hash chain of _audit_log
  kareladb repair  <db> [--backups <dir>] [--accept-log-loss]
                                                 fix damaged files from old versions or backups
  kareladb backup  <db> <backups-dir> [--hard-links] [--keep-daily N] [--keep-weekly N]
  kareladb backups <backups-dir>                 list backups, newest first
  kareladb verify-backup <backup-dir>
  kareladb restore <backup-dir> <new-data-dir> [--logs-from <old-data-dir>] [--until "YYYY-MM-DD HH:MM[:SS]"]
  kareladb dump-file <file.kdb>                  header and block checksums of one file
  kareladb serve   [<db>] [--db <name>] [--port 9900] [--bind 127.0.0.1] [--backups <dir>] [--token <t>] [--memory <MB>]
              [--sync-commits always|batch] [--threads N]  HTTP API, line protocol (POST /write) and web console
              [--pg-port 8832] [--pg-timestamptz] PostgreSQL protocol for Postgres drivers and tools (0 = off)
                                                 (Ctrl+C stops). Without <db>: every database in the data folder
  kareladb exec [--url http://localhost:9900] [--token <t>] [--db <name>] "SQL"
              run SQL on a running server and print its JSON answer; a cluster follower's 421 is followed
              once to the leader it names
  kareladb promote [--url http://localhost:9900] [--token <t>]  make the standby at --url a primary: it stops
                                                 copying and takes changes (when the primary is lost)
  kareladb witness --data-dir <dir> --node-id <id> --cluster-peers <list> [--port 9900] [--bind 127.0.0.1]
              [--token <t>]                      a cluster voter that holds no data: it only votes (docs: cluster)
  kareladb cluster diverged list|drop <folder> [--data-dir <dir>]
              the copies a cluster node kept in _diverged when it took the leader's history; drop deletes one
  kareladb shell   [<db>] [--backups <dir>] [--memory <MB>]  interactive SQL prompt (end statements with ;)
  kareladb sql     <db> "SQL" [--format table|csv|json] [--max-rows N]
                                                 run SQL and print results (use - to read SQL from stdin)
  kareladb user add <name> [--role admin|ddl|write|read]  add a server user; the password is asked for (or read
                                                 from a pipe), never given on the command line
  kareladb user passwd <name>                    set a new password
  kareladb user role <name> admin|ddl|write|read|none change the role
  kareladb user list                             users and roles (never passwords)
  kareladb user remove <name>
  kareladb user reset-2fa <name>                 turn two-factor login off (a lost phone)
                                                 (kareladb user works on the data folder while kareladb serve is stopped;
                                                 while it runs, use CREATE USER ... in its console)
  kareladb version [<db>]                        this build and the stored-format features it reads;
                                                 with <db>: the features that database uses
  kareladb upgrade <db> [--backups <dir>]        verified backup, then save the database's feature list, then check
  kareladb features <db> | --data-dir <folder>   the stored-format features each database uses now, and what uses them
  kareladb downgrade <db> | --data-dir <folder> --to <version> [--backups <dir>] [--no-backup]
                                                 let an older KarelaDB open the data (--to 2026-09-13, or --known
                                                 <names> from the older kareladb version); refused, naming what uses
                                                 each newer feature, when the data needs one
  kareladb key new                               print a new random master key (64 hex characters) for
                                                 encrypted databases: keep it in KARELADB_MASTER_KEY or a key file
                                                 (KARELADB_MASTER_KEY_FILE) outside the data folder
  kareladb key rotate <folder>                   re-wrap the data key of an encrypted database folder, or of
                                                 every backup in a folder of backups, with KARELADB_MASTER_KEY
                                                 (the old key in KARELADB_MASTER_KEY_PREVIOUS); no data file changes
  kareladb help [<topic> | tutorial [<chapter>]]     the help topics (and, in a source checkout, the tutorial)
                                                 in the terminal; without a topic: the list of topics
  kareladb skill [install] [--dir <d>] [--url <u>] [--token <t>] [--home <checkout>]
                                                 print, or install into ~/.claude/skills/kareladb, the file that
                                                 teaches an AI assistant in another project how to use KarelaDB

<db>: a database name in the data folder (market), or the path of a database folder (D:\kdb\market, ./market).
Data folder: --data-dir <folder>, else kareladb.conf, else the KARELADB_DATA_DIR environment variable,
  else "data" next to kareladb.
--config <file>: kareladb.conf, the JSON file the console's Settings page and ALTER SYSTEM write
  (default: kareladb.conf next to kareladb). A flag on the command line always wins over it, and it wins over
  the environment. It may hold: data_dir, wal_dir, wal_archive_mb, cache_mb, keep_versions, trash_keep_hours,
  trash_max_mb, slow_query_ms, http_threads, max_connections, lock_timeout_ms,
  idle_in_transaction_timeout_ms, rate_limit_ip, rate_limit_user, timer_workers, timezone,
  http_functions, http_timeout_ms, ilp_auto_create, step_up_actions, step_up_minutes, alert_webhook,
  tls_cert, tls_key, the backup_*
  settings, and "system" (what ALTER SYSTEM SET saved; SELECT pg_reload_conf() puts it in use).
  A database folder served by its path (kareladb serve D:\kdb\market) reads only the three folders below.
  web_dir, help_dir and skill_dir name the folders of the console, the help and the Claude skill
  (else KARELADB_WEB_DIR, KARELADB_HELP_DIR, KARELADB_SKILL_DIR, else web/, help/ and skill/ next to kareladb).
--memory <MB>: memory for table data kept loaded (default 512). More is faster on big tables.
--memory-limit <size>: one limit for everything the server holds (table data, unsaved changes,
  indexes, results, caches, what the allocator keeps), like 3GB or 3072 (MB). Near it, memory is
  given back (the result cache too); at it, quick statements still run in a small reserve and
  others get 'memory full' (HTTP 503, PostgreSQL 53200); over it, the running statement that
  holds the most is stopped with 'memory full'. Default: 85% of a container's
  memory limit, else of the machine's memory (env KARELADB_MEMORY_LIMIT; 0 or off = no limit).
--threads <N>: threads for big queries and writes (default and most: half of the CPU threads).
--cache-mb <MB>: memory for results of repeated queries, all databases together (default 256,
  0 = off; else kareladb.conf cache_mb, else env KARELADB_CACHE_MB). A result is used again only while no
  table it read has changed; a quick one (under 1 ms) is kept when asked twice. Queries with
  random() are never kept; with now() only for a caller that takes an older answer
  (/exec?cache_now_ms=500, SET result_cache_now_ms = 500). One result may use a quarter of it,
  a pinned one three quarters. ALTER DATABASE db SET RESULT_CACHE = '256MB' gives a database
  a space of its own.
--pg-compat on|off: PostgreSQL 14's answers for every database without its own ALTER DATABASE ...
  SET pg_compat (default off; env KARELADB_PG_COMPAT): 7 / 2 = 3, 1.005 is an exact NUMERIC, a window
  with ORDER BY counts ties together, text sorts like en_US. A session can choose with
  SET kdb.pg_compat = on | off.
--pg-int-division on|off: on the Postgres port, whole number / whole number gives a whole
  number (7 / 2 = 3) as in PostgreSQL (default off; env KARELADB_PG_INT_DIVISION). A session can
  still choose with SET int_division = integer | float.
--reader-yield on|off: readers do not wait for a long trigger or CALL; they read the last
  committed rows (default on; env KARELADB_READER_YIELD). Off: readers wait for the writer's statement.
--per-table-reads on|off: a reader waits only for writers of the tables it reads, and not while
  a checkpoint writes its files (default on; env KARELADB_PER_TABLE_READS). Off: it waits for every writer.
--pin-threads auto|on|off: auto (default): on Linux, inside a CPU quota (docker --cpus, cgroup cpu.max)
  smaller than the CPUs the process may run on, every thread is pinned to the quota's worth of CPUs,
  one per core, and moved back when the quota goes (docker update --cpus); 32 connections on a 2-CPU
  quota of a 32-CPU host no longer run on all 32 and stall when the time is spent. on: each HTTP
  worker, PostgreSQL connection and query thread runs on one CPU of its own, taken in turn from as
  many CPUs as KarelaDB may use, out of the cpuset; background threads stay on those CPUs. off: nothing is
  pinned (env KARELADB_PIN_THREADS). Ignored on Windows.
--read-only-calls on|off: a CALL of a procedure that changes nothing runs like a SELECT: no table
  locks, no transaction (default on; env KARELADB_READ_ONLY_CALLS).
--scoped-ddl on|off: CREATE/ALTER/DROP TABLE, INDEX and TRIGGER, TRUNCATE, CREATE TABLE AS and
  materialized views lock only the tables they touch; views, procedures and functions lock none
  (default on; env KARELADB_SCOPED_DDL). Off: every schema change locks every table.
--ddl-beside-writers on|off: with --scoped-ddl, CREATE TABLE, ALTER TABLE, RENAME TABLE and CREATE/DROP
  INDEX run beside a writer of other tables that is inside one long statement (default on; env
  KARELADB_DDL_BESIDE_WRITERS). Off: they wait until that writer pauses between two statements.
--log-lock-waits on|off: a statement that waits for a table lock longer than --deadlock-timeout
  writes one line to the log naming itself, the lock and who holds it (default off; env
  KARELADB_LOG_LOCK_WAITS; a session: SET log_lock_waits = on).
--deadlock-timeout 1s: when --log-lock-waits writes its line (default 1s; env KARELADB_DEADLOCK_TIMEOUT;
  a session: SET deadlock_timeout). Deadlocks are found at once whatever it is.
--skip-locked-beside on|off: SELECT ... FOR UPDATE SKIP LOCKED inside BEGIN reads beside other open
  transactions that hold the table and returns the rows they did not touch (default off; env
  KARELADB_SKIP_LOCKED_BESIDE). Its UPDATE of such a row waits for their COMMIT. Off: no rows there.
--table-writers one|many: many: several users change one table at the same time when each of their
  statements on it touches single rows by the primary key (one-row INSERT, UPDATE or DELETE ... WHERE
  id = x, a CALL or trigger of such statements); the same row is waited for, as in PostgreSQL. Anything
  else on the table waits for the whole table, as before (default one; env KARELADB_TABLE_WRITERS).
--snapshot-reads on|off: a reader of a table that a long CALL, trigger job or bulk write is changing
  does not wait: it reads a snapshot of the committed rows (default off; env KARELADB_SNAPSHOT_READS).
  Tables with an index too, while a writer is busy on them, at any size: the read uses the index
  on the snapshot (an idle BEGIN is taken out and the index used, as before).
--tail-files on|off: a checkpoint saves rows appended after the end of a partition in a small tail file
  instead of writing the whole partition again (default off; env KARELADB_TAIL_FILES). A database with tail
  files needs a KarelaDB from 2026-10-02 or later (kareladb downgrade merges them back).
--snapshot-index-rows 1000000: a table with a full-text/JSON index, or an index not built yet, is
  scanned on a snapshot: only up to this many rows, a bigger one waits for its writer as before
  (default 1000000; 0 = indexed tables never get snapshots; env KARELADB_SNAPSHOT_INDEX_ROWS).
--txn-spill-mb 64: a transaction's log records past this many MB (or 1/16 of --memory-limit) go to a
  temporary file in the database's _tmp folder until COMMIT (default 64; 0 = never; env KARELADB_TXN_SPILL_MB).
--lanes on|off: priority lanes (default on; env KARELADB_LANES). A read whose shape used --heavy-ms of
  CPU or more the last three times it ran is heavy: only --heavy-slots of those run at once, at a
  lower CPU priority, and the rest wait in line. Charts and other short statements never wait. SET kdb.priority = high|normal|low, the X-KDB-Priority header
  and ALTER USER ... SET kdb.priority choose a lane by hand. Off: every statement runs at once.
--heavy-ms 100: the CPU time a read shape must use to count as heavy (env KARELADB_HEAVY_MS).
--heavy-slots N: heavy statements that run at once (default half the CPUs, at least 1; env
  KARELADB_HEAVY_SLOTS).
--heavy-queue N: heavy HTTP requests that may wait at once (default half the HTTP threads, at
  least 4; env KARELADB_HEAVY_QUEUE). Past it a request sent with priority low gets 503; a read heavy by
  its history runs at once. PostgreSQL statements are not counted: they wait up to their timeout.
--read-slots auto|off|N: reads (outside BEGIN) that run at once; the rest wait in line. A read holds
  its slot for at most 10 ms, so a long one never holds the line up (default auto = the CPUs the
  process may use, at least 2, following docker update --cpus; env KARELADB_READ_SLOTS). Off: every read
  starts at once, as before.
--timezone Asia/Kathmandu: the clock of CURRENT_DATE, ::date, date_trunc, EXTRACT and to_char, and of
  timer and backup schedules (default: the computer's own zone; env
  KARELADB_TIMEZONE; kareladb.conf "timezone"). Times are still stored as UTC. A session: SET TIME ZONE.
  Default: the computer's own zone. Zones with summer time (America/New_York) need the system's
  zone files (tzdata); per user: ALTER USER name SET timezone = 'zone'.
--warm-indexes on|off: build every index right after a database opens, on a background thread,
  so the first query finds them ready (default on; env KARELADB_WARM_INDEXES). Off: on first use.
--sync-commits always: every write is on disk before it is confirmed (default).
--sync-commits batch: writes are confirmed at once and put on disk every 10 ms. Much faster for
  many small writes; a power cut can lose the last confirmed writes, but never damages the data.
Protection of kareladb serve (docs/tutorial/21-protection.md):
  --statement-timeout 60s      stop statements that run longer (default 60s, 0 = no limit)
  --max-result-memory 1GB      rows one query may keep in memory (default 1GB, 0 = no limit)
  --max-groups N               GROUP BY groups of one query (default 5000000, 0 = no limit)
  --max-queries-per-user N     statements one user runs at the same time (default 32, 0 = no limit)
  --safe-updates               refuse UPDATE and DELETE without WHERE (SET safe_updates = off per session)
  --read-only                  the whole server only reads
  --standby-of URL             this server is a standby: it copies every database of the primary at URL
                               (http://host:9900) from its log, and only reads (env KARELADB_STANDBY_OF)
  --standby-token T            the token the standby sends to the primary: its --token or an admin's API
                               token (env KARELADB_STANDBY_TOKEN)
  --cluster-peers LIST         this server is a cluster node: id=http://host:port of every voter, this one too
                               (a=http://a:9900,b=http://b:9900,w=http://w:9900); the leader is elected and
                               takes over by itself when it dies (env KARELADB_CLUSTER_PEERS)
  --node-id ID                 this node's id in --cluster-peers (env KARELADB_NODE_ID)
  --cluster-token T            the token the nodes send each other (default --token; every node must accept
                               it as an admin's) (env KARELADB_CLUSTER_TOKEN)
                               a cluster node also reads KARELADB_SYNC_STANDBYS=0|1|required (1: a commit is
                               confirmed once a standby holds it, or alone when none copies; default 1;
                               required: never alone, refused when no standby copies, failed after
                               KARELADB_SYNC_WAIT_MS, 10000) and KARELADB_ON_LEADER / KARELADB_ON_FOLLOWER
                               (a command run on each role change: <cmd> leader|follower <term> <leader-id>)
  --cluster-learner            a cluster follower that does not vote: one more copy to read from; its
                               --node-id is not in --cluster-peers (env KARELADB_CLUSTER_LEARNER=on, or list
                               it in KARELADB_CLUSTER_FOLLOWERS=f1=http://h4:9900,...). Reads on any follower:
                               KARELADB_MAX_READ_LAG_MS (answer 503 when further behind), KARELADB_READ_WAIT_MS
                               (how long X-KarelaDB-Min-Lsn waits; default 2000)
  --trash-days N               DROP TABLE keeps the table N days for UNDROP TABLE (default 7; also sql, shell)
  --audit on|off               audit log of logins, users, DDL, backups in _system (default on)
  --audit-keep-days N          remove audit rows older than N days (default 0 = keep forever)
  --activity-log-size N        recent events for the console's activity panel, in memory (default 5000, 0 = off)
  --slow-query-ms N            statements taking N ms or more go to <data>/_logs/slow_queries.jsonl
                               (GET /api/slow-queries; default 1000, 0 = off; env KARELADB_SLOW_QUERY_MS)
  --stat-statements on|off     pg_stat_statements: totals per statement shape, in memory
                               (default on; env KARELADB_STAT_STATEMENTS)
  --token-name NAME            what the audit log calls whoever uses the --token (default token; env KARELADB_TOKEN_NAME)
  --trash-max-mb N             a database's _trash may hold N MB; beyond it the oldest go at once
                               (default: a quarter of the data, at least 256 MB; 0 = no limit;
                               env KARELADB_TRASH_MAX_MB, kareladb.conf trash_max_mb)
  --drain-timeout 30s          on stop, running requests may finish this long; new ones get 503 (default 30s)
  --tls-cert FILE --tls-key FILE  TLS on both ports: https:// and PostgreSQL sslmode=require (PEM files;
                               --tls-cert auto: a self-signed pair made in <data>/_tls; env KARELADB_TLS_CERT,
                               KARELADB_TLS_KEY; kareladb.conf tls_cert, tls_key)
  --tls-required on|off        with TLS, refuse plain connections except from 127.x (default on;
                               env KARELADB_TLS_REQUIRED)
  --rate-limit-ip N            requests per second one client address may send, HTTP and PostgreSQL
                               (default 0 = no limit; 127.x is never limited; env KARELADB_RATE_LIMIT_IP)
  --rate-limit-user N          requests per second one user may send (default 0 = no limit;
                               env KARELADB_RATE_LIMIT_USER). Over a limit: HTTP 429 with Retry-After
  --http-threads N             HTTP requests handled at once (default: the CPU threads, at least 8; env KARELADB_HTTP_THREADS)
  --http-gzip remote|on|off    gzip answers of 2 KB or more for clients that send Accept-Encoding: gzip:
                               clients on other computers (remote, the default), all, or none (env KARELADB_HTTP_GZIP)
  --timer-workers N            timers that may run at the same time (1 to 64, default 3; env KARELADB_TIMER_WORKERS)
  --tcp-keepalives-idle S      TCP keepalive of every connection: seconds idle before the first probe,
  --tcp-keepalives-interval S  seconds between probes, and probes before a vanished client is dropped
  --tcp-keepalives-count N     (0 = the system's, the default; env KARELADB_TCP_KEEPALIVES_IDLE, ...)
  --ilp-auto-create on|off     POST /write creates a table it does not find, as QuestDB does (default on;
                               kareladb.conf "ilp_auto_create"; env KARELADB_ILP_AUTO_CREATE)
  --max-connections N          PostgreSQL logins at once, all databases (default 100, 0 = no limit; env KARELADB_MAX_CONNECTIONS)
  --lock-timeout 5s            a writer waits this long for a busy table (default 5s, 0 = no limit; env KARELADB_LOCK_TIMEOUT;
                               a session: SET lock_timeout = '20s')
  --idle-in-transaction-timeout 30s  an open BEGIN ... COMMIT that sends nothing this long is rolled
                               back (default 30s, 0 = never; env KARELADB_IDLE_IN_TRANSACTION_TIMEOUT;
                               a session: SET idle_in_transaction_session_timeout = '5min')
  --trigger-retries N          a failed deferred trigger job runs again N times (1 s, 2 s, 4 s ... apart) before
                               its queue stops (default 3, 0 = never; env KARELADB_TRIGGER_RETRIES)
  --max-trigger-jobs N         deferred trigger jobs waiting per database; a write past it is refused with the
                               reason (default 10000, 0 = no limit; env KARELADB_MAX_TRIGGER_JOBS)
  --alert-webhook URL          POST failed trigger jobs as JSON to http://<IPv4>:<port>/<path>
                               (env KARELADB_ALERT_WEBHOOK, kareladb.conf alert_webhook)
  --backups <dir>              backup folder (default <data folder>/_backups; "off" = none; or KARELADB_BACKUP_DIR)
  --backup-schedule "daily 16:00"  verified backups of every database (local time; or KARELADB_BACKUP_SCHEDULE)
  --backup-command "<cmd>"     run after each backup to copy it off the server: {dir} {database} {name}
                               (or KARELADB_BACKUP_COMMAND), e.g. "rclone copy {dir} remote:kdb/{database}/{name}"
  --backup-copy <dir>          a second, checked copy of each scheduled backup (another disk)
  --backup-warn-hours N        warn in the log when the last good backup is older (default 26)
  --keep-daily N --keep-weekly N   backups kept (default 7 and 4; or KARELADB_BACKUP_KEEP_DAILY / _WEEKLY)
Exit codes: 0 OK, 1 error, 2 damage found, 3 the database needs a newer KarelaDB (nothing was changed).

Help topics (0), from ./help-placeholder. "kareladb help <topic>" prints one; a running server has them at /help:
```
## kareladb version

Syntax:

```sql
kareladb version
kareladb --version
kareladb version <db>
```

Prints the version of KarelaDB and the stored-format features it can read. `crc32c hardware: yes` means the CPU computes checksums (CRC32C) with special fast instructions. `no` also works, only slower.
With `<db>` it shows the features that database uses ([versions and upgrades](versions.md)).

- **Exit code:** `0`. With `<db>`: `3` when the database needs a newer KarelaDB.

**Command line**

```bash
kareladb version
```

Output:

```text
KarelaDB 0.2.0-dev (crc32c hardware: yes)
tls: OpenSSL 3.6.3 9 Jun 2026

Stored-format features this build reads (52):
  views                0.2.0-dev (2026-09-10)   CREATE VIEW: the "views" file
  partition_format_2   0.2.0-dev (2026-09-11)   table partition files in format 2 (one raw block per column)
  block_stats          0.2.0-dev (2026-09-11)   column stats section in partition files (count, min, max, sum per column)
  runs                 0.2.0-dev (2026-09-11)   log record 'C': rows of a bulk upsert kept as columns
  auto_meta            0.2.0-dev (2026-09-11)   AUTO id counters in the manifest (auto.<table id>)
  json                 0.2.0-dev (2026-09-11)   JSON columns (type code 12)
  bytes                0.2.0-dev (2026-09-11)   BYTES columns (type code 13)
  check                0.2.0-dev (2026-09-11)   CHECK constraints (catalog format 2, part 'C')
  indexes              0.2.0-dev (2026-09-11)   CREATE INDEX, UNIQUE and FULLTEXT indexes (catalog part 'I')
  routines             0.2.0-dev (2026-09-11)   functions, procedures and triggers: the "routines" file
  users                0.2.0-dev (2026-09-11)   server users and roles (_system.users)
  audit                0.2.0-dev (2026-09-12)   SET AUDIT ON: catalog part 'A', log record 'P', the _audit_log table
  table_grants         0.2.0-dev (2026-09-12)   GRANT ... ON TABLE (_system.users.table_grants)
  totp                 0.2.0-dev (2026-09-12)   two-factor logins (_system.users.totp)
  trash                0.2.0-dev (2026-09-12)   dropped tables kept as _dropped_<ms>_<name> for UNDROP TABLE
  database_settings    0.2.0-dev (2026-09-12)   ALTER DATABASE ... SET READ ONLY (_system.database_settings)
  dialects             0.2.0-dev (2026-09-12)   ALTER DATABASE ... SET dialect (_system.database_dialects)
  pg_catalog_parts     0.2.0-dev (2026-09-12)   PostgreSQL column types, multi-column keys, foreign keys, expression and partial indexes (catalog parts 'T', 'K', 'F', 'X')
  sequences            0.2.0-dev (2026-09-12)   CREATE SEQUENCE: the "sequences" file and its log records
  batched_log_sync     0.2.0-dev (2026-09-11)   log segments in the batched format (header flag 1, 16-byte commit records): group commit and --sync-commits batch
  dedup_change         0.2.0-dev (2026-09-12)   ALTER TABLE ... DEDUP ENABLE / DISABLE: the DEDUP KEY of a table that already holds rows
  plpgsql_triggers     0.2.0-dev (2026-09-12)   PostgreSQL plpgsql trigger functions and FOR EACH ROW triggers in the "routines" file
  cached_views         0.2.0-dev (2026-09-13)   CREATE CACHED VIEW: which views are cached, and REFRESH ON COMMIT, in the "views" file
  deferred_triggers    0.2.0-dev (2026-09-13)   CREATE TRIGGER ... DEFERRED: job records in the log, and the "trigger_queue" and "q/<job>" files of queued jobs
  materialized_views   0.2.0-dev (2026-09-13)   CREATE MATERIALIZED VIEW: catalog part 'M', REFRESH MATERIALIZED VIEW log records, mv_dirty.<id> in the manifest
  table_ttl            0.2.0-dev (2026-09-13)   TTL n DAYS on a table: catalog part 'L'
  read_only_procedures 0.2.0-dev (2026-09-24)   CREATE PROCEDURE ... READ ONLY in the "routines" file
  dedup_insert         0.2.0-dev (2026-09-24)   WITH (dedup_insert = 'upsert') on a table: catalog part 'U'
  decimal128           0.2.0-dev (2026-09-25)   NUMERIC(p, s) columns with more than 18 digits: 128-bit DECIMAL (type code 14) in the catalog, partition files and log
  dedup_generated_key  0.2.0-dev (2026-09-25)   a stored generated column in a DEDUP KEY, like the minute of the time (an older build refuses such a catalog)
  symbol_partitions    0.2.0-dev (2026-09-25)   PARTITION BY <time>, SYMBOL(col): catalog part 'P' (one partition file per time bucket and symbol, t/<id>/<time>/s-...)
  round_time_zone      0.2.0-dev (2026-09-25)   TIMESTAMP ROUND ... TIME ZONE 'zone' columns: catalog part 'R'
  enum_types           0.2.0-dev (2026-09-25)   CREATE TYPE ... AS ENUM: the ENUM types after the tables of the catalog (catalog format 3)
  row_ttl              0.2.0-dev (2026-09-25)   CREATE TABLE ... WITH (ttl_column = c): rows expire one by one, catalog part 'E'
  column_compression   0.2.0-dev (2026-09-25)   ALTER TABLE ... SET (compression = on): catalog part 'Z' and packed partition files (header flag 2)
  calendars            0.2.0-dev (2026-09-25)   CREATE CALENDAR: trading calendars (eras, holidays, extra trading days) after the ENUM types of the catalog (catalog format 4)
  materialized_view_sample_by 0.2.0-dev (2026-09-26)   CREATE MATERIALIZED VIEW ... AS (SELECT ... SAMPLE BY ...): a SAMPLE BY query in catalog part 'M', refreshed bucket by bucket
  comments             0.2.0-dev (2026-09-26)   COMMENT ON TABLE / COLUMN: the comments of a table and its columns, catalog part 'N'
  cache_tables         0.2.0-dev (2026-10-02)   WITH (max_bytes, evict, durability): cache tables with a memory cap and eviction, catalog part 'Y'
  resident_tables      0.2.0-dev (2026-10-02)   WITH / SET (resident = on): a table never unloaded to make room, catalog part 'H'
  partition_tails      0.2.0-dev (2026-10-02)   tail files: rows appended to a partition saved in extra files t/<id>/<partition>.tail<k>.b<version> (tail_files)
  uuid                 0.2.0-dev (2026-10-02)   UUID columns: 16 bytes per value (type code 15) in the catalog, partition files and log
  search_analyzer      0.2.0-dev (2026-10-02)   CREATE FULLTEXT INDEX ... WITH (language = 'english'): the word analyzer of a full-text index, catalog part 'S'
  column_grants        0.2.0-dev (2026-10-02)   GRANT / REVOKE on single columns (_system.users.column_grants)
  row_policies         0.2.0-dev (2026-10-02)   row-level security: CREATE POLICY and ALTER TABLE ... ENABLE ROW LEVEL SECURITY (_system.row_policies)
  partition_deltas     0.2.0-dev (2026-10-02)   delta files: a few rows of a partition replaced or deleted, saved in t/<id>/<partition>.delta.b<version>
  fulltext_segments    0.2.0-dev (2026-10-02)   full-text and JSON index segments in fts/*.kfs (the words of each partition's rows; never recorded: an older build ignores them)
  compressed_log       0.2.0-dev (2026-10-02)   packed log records (type 3): the data records of a big commit written compressed (KARELADB_WAL_COMPRESS)
  endpoints            0.2.0-dev (2026-10-03)   CREATE ENDPOINT: saved queries served at GET /v/<name>, kind 'E' in the routines file
  rules                0.2.0-dev (2026-10-03)   CREATE RULE: named checks, session hours and settings of a table (catalog part 'Q')
  sync_commit_tables   0.2.0-dev (2026-10-03)   WITH (synchronous_commit = on | off) of a table: catalog part 'G'
  cold_storage         0.2.0-dev (2026-10-22)   cold storage: WITH / SET (cold_storage, cold_after), catalog part 'O', and partitions moved to an object store, kept as stub files (t/<id>/<partition>.cold.v<N>.kdb, header flag 1)

A database that uses a feature not in this list needs a newer KarelaDB (kareladb check exits with 3).
```

<a id="db-argument"></a>

## <db>: a name or a folder path

Syntax:

```sql
kareladb sql market "..."          -- a name: the database 'market' in the data folder
kareladb sql ./market "..."        -- a path: the folder 'market' in the current folder
kareladb sql D:\kdb\market "..."   -- a path: always that folder
```

The commands `sql`, `shell`, `serve`, `info`, `check`, `repair` and `backup` take `<db>`. KarelaDB decides like this:

| You write | KarelaDB uses |
|---|---|
| A name (only letters, digits, `_` and `-`), and the data folder has a database with that name | That database in the data folder. Upper or lower case does not matter. |
| A name, and the data folder has **no** database with that name | The folder with that name in the **current** folder. It is created when it does not exist. |
| A path (it has `\`, `/`, `:` or `.`) | Always that folder. It is created when it does not exist (not by `kareladb info` and `kareladb check`). |
| Nothing (only `kareladb shell` and `kareladb serve`) | The data folder: `kareladb shell` opens the database `default`; `kareladb serve` serves all databases. |

- **Notes:** a wrong name does **not** give an error. `kareladb sql markett "..."` makes a new, empty database `markett`, and then says `table ... does not exist`. Write `./market` when you want to be sure you mean a folder.
- With a **name**, `kareladb backup` and `kareladb repair --backups` use the sub-folder `<backups-dir>/<name>`, the same place `kareladb serve` uses.
- Database names are 1 to 64 characters. `Market` and `market` are the same database.

**Command line: A name in the data folder, and a path in the current folder**

```bash
kareladb shell
> CREATE DATABASE reports;
kareladb sql reports "CREATE TABLE daily (day DATE PRIMARY KEY, trades LONG); INSERT INTO daily VALUES ('2026-09-10', 32)"
kareladb info reports
kareladb sql ./reports "SHOW TABLES"
```

Output:

`> kareladb shell`

```text
KarelaDB 0.2.0-dev shell on default (data folder ./kdb-data)
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> database 'reports' created
kareladb>
```

`> kareladb sql reports "CREATE TABLE daily (day DATE PRIMARY KEY, trades LONG); INSERT INTO daily VALUES ('2026-09-10', 32)"`

```text
table 'daily' created

1 row(s) inserted
```

`> kareladb info reports`

```text
database        ./kdb-data/reports
manifest        copy a, sequence 7
last shutdown   clean
log position    4 (saved in files up to 4)
newest change   2026-10-24 11:29:57
features        batched_log_sync, block_stats, compressed_log, partition_format_2
manifest keys   8

FILE                                      VERSION       SIZE          LSN  STATUS
catalog                                         1      232 B            4  ok
t/1/all                                         2      388 B            4  ok

2 files, 620 B, 0 marked damaged
(STATUS is what the manifest records. To read every block and find new damage, run: kareladb check)
```

`> kareladb sql ./reports "SHOW TABLES"`

```text
name | kind | partition | columns | rows
-----+------+-----------+---------+-----
(0 rows, 0.0 ms)
```

In this example the data folder is `./kdb-data`. `kareladb info reports` opens `./kdb-data/reports`. `./reports` is a new, empty database in the current folder, so it has no tables.

<a id="data-folder"></a>

## The data folder

Syntax:

```sql
--data-dir <folder>
KARELADB_DATA_DIR=<folder>
```

The data folder holds many databases, one sub-folder per database. KarelaDB looks for it in this order; the first one that is set wins:

| # | Where | Example |
|---|---|---|
| 1 | The option `--data-dir <folder>` | `kareladb serve --data-dir E:\kdb-data` |
| 2 | Only `kareladb serve`: `data_dir` in `kareladb.conf`, what the console's [Settings page](console-settings.md) saved ([kareladb.conf](cli-serve.md#kareladb-conf)) | `"data_dir": "E:/kdb-data"` |
| 3 | The environment variable `KARELADB_DATA_DIR` | `$env:KARELADB_DATA_DIR = "E:\kdb-data"` |
| 4 | The folder `data` next to the `kareladb` program | `D:\KarelaDB\build\bin\data` |

- `--data-dir` works with `kareladb sql`, `kareladb shell`, `kareladb serve`, `kareladb info`, `kareladb check`, `kareladb repair`, `kareladb backup` and `kareladb user`.
- KarelaDB creates the data folder when it is missing.
- `kareladb sql`, `kareladb shell` and the other commands do not read `kareladb.conf`. When the Settings page moved the server to another folder, give that folder to them with `--data-dir`.
- The data folder also holds `_trash` (dropped databases) and `_system` (the server's users). They are not databases you can use.
- Use `KARELADB_DATA_DIR` when the data must be on another disk, or when `kareladb.exe` is in a folder where you cannot write (like `C:\Program Files`).

<a id="wal-dir"></a>

### The log on another disk

Syntax:

```sql
KARELADB_WAL_DIR=<folder>
"wal_dir": "<folder>"        in kareladb.conf (kareladb serve only)
```

Every commit writes the database's log and waits for the disk to confirm it. When the data folder is on a slow-to-sync disk (a Windows folder bind-mounted into Docker Desktop confirms a small write in about 1 ms; a Docker volume inside the VM in 0.4 ms), `wal_dir` puts the log on the faster disk while the data files stay where they are. Each database gets a sub-folder of it, named like the database. KarelaDB leaves a note in the database's own `wal` folder saying where its log went, so `kareladb backup`, a repair and a server started without the setting still find it. A database that already has a log keeps writing its current segment where it is; the next segment goes to the new folder. The old log kept for repairs (`wal_archive`) stays in the data folder.

**Command line: --data-dir wins over KARELADB_DATA_DIR**

```bash
kareladb shell --data-dir my-data
> CREATE DATABASE shop;
> SHOW DATABASES;
kareladb serve --data-dir my-data
```

Output:

`> kareladb shell --data-dir my-data`

```text
KarelaDB 0.2.0-dev shell on default (data folder my-data)
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> database 'shop' created
kareladb> name    | tables | bytes | current
--------+--------+-------+--------
default |      0 |     0 | true   
shop    |      0 |     0 | false  
(2 rows, 0.2 ms)
kareladb>
```

`> kareladb serve --data-dir my-data`

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      my-data (from --data-dir; one folder per database)
  default   default (used when a request names no database)
  backups   my-data/_backups/<database name> (from default)
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
  logs      slow queries >= 1000 ms to my-data/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  manifest copy: a, last shutdown: clean
  open      opened in 1 ms: manifest 1 ms, 0 files read 0 ms, log check 0 ms, replay 0 ms (0 transactions), clean-up 0 ms

Press Ctrl+C to stop.
```

The banner of `kareladb serve` says where the data folder came from: `from --data-dir`, `from kareladb.conf`, `from KARELADB_DATA_DIR` or `from program folder`.

To set `KARELADB_DATA_DIR` for good (these lines are not run here):

```powershell
# Windows, for your user. Open a new PowerShell window afterwards.
[Environment]::SetEnvironmentVariable("KARELADB_DATA_DIR", "E:\kdb-data", "User")
```

```bash
# Linux and macOS: add this line to ~/.bashrc or ~/.zshrc
export KARELADB_DATA_DIR=/srv/kareladb/data
```

<a id="exit-codes"></a>

## Exit codes

Syntax:

```sql
0   OK
1   error
2   damage found, or damage that could not be repaired
3   the database needs a newer KarelaDB (nothing was changed)
```

Every `kareladb` command ends with an exit code. Scripts use it to know if the command worked.

| Code | Meaning | Examples |
|---|---|---|
| `0` | OK | The query ran. The backup was made. No damage found. |
| `1` | Error | Wrong SQL. A duplicate key. The database is open in another program. Wrong arguments. |
| `2` | Damage | `kareladb check` found damage. A data file failed its checksum. A repair could not fix everything. |
| `3` | Needs a newer KarelaDB | A newer KarelaDB wrote the database. It is not damaged: open it with that KarelaDB ([versions](versions.md#needs-newer)). |

- In PowerShell the exit code is in `$LASTEXITCODE`. In bash and zsh it is in `$?`. Read it **right after** the `kareladb` command.
- `$ErrorActionPreference = "Stop"` does not stop a PowerShell script when `kareladb` fails. Check `$LASTEXITCODE` yourself.
- Error messages go to the error output (stderr) and start with `error:`.
- `kareladb shell` ends with the exit code of the last statement or dot command.

**Command line: 0 for a good query, 1 for a wrong table name** (sample data: sample)

```bash
kareladb sql market "SELECT count(*) AS n FROM brokers"
kareladb sql market "SELECT count(*) FROM brokerz"
```

Output:

`> kareladb sql market "SELECT count(*) AS n FROM brokers"`

```text
n
-
5
(1 row, 0.5 ms)
```

`> kareladb sql market "SELECT count(*) FROM brokerz"`

```text
error: line 1, column 22: table or view 'brokerz' does not exist
```

exit code 1

```powershell
# In a script (not run here)
kareladb check D:\kdb\market | Out-Null
switch ($LASTEXITCODE) {
  0 { "check: OK" }
  2 { "check: DAMAGE FOUND - run kareladb repair" }
  3 { "check: this database needs a newer KarelaDB - do not repair it" }
  default { "check: could not run (exit code $LASTEXITCODE)" }
}
```

<a id="options"></a>

## How options are read

Syntax:

```sql
kareladb <command> <arguments> [--option value] [--flag]
```

Options can come before or after the other arguments. Some options take a value (`--format csv`), some do not (`--hard-links`).

| Option | Value | Used by |
|---|---|---|
| `--data-dir` | folder | [sql, shell](cli-sql-and-shell.md), [serve](cli-serve.md), info, check, repair, backup, [user](cli-users.md) |
| `--backups` | folder | [sql, shell](cli-sql-and-shell.md), [serve](cli-serve.md), [repair](cli-maintenance.md#kareladb-repair) |
| `--memory` | megabytes | sql, shell, serve |
| `--format`, `--max-rows` | `table`/`csv`/`json`, a number | [kareladb sql](cli-sql-and-shell.md#kareladb-sql) |
| `--port`, `--bind`, `--token`, `--db`, `--threads`, `--cache-mb`, `--sync-commits`, `--pg-port`, `--pg-timestamptz`, `--config`, `--warm-indexes`, `--reader-yield`, `--drain-timeout` | see [kareladb serve](cli-serve.md#kareladb-serve) | serve |
| `--statement-timeout`, `--max-result-memory`, `--max-groups`, `--max-queries-per-user`, `--safe-updates`, `--read-only`, `--trash-days`, `--audit`, `--audit-keep-days`, `--activity-log-size` | see [protection](protection.md) | serve (`--trash-days` also sql, shell) |
| `--backup-schedule`, `--backup-copy`, `--backup-warn-hours` | see [backup schedule](backup-schedule.md) | serve |
| `--dir`, `--url`, `--token`, `--home` | folder, address, secret, folder | [kareladb skill install](install-packages.md#skill) |
| `--hard-links`, `--keep-daily`, `--keep-weekly` | -, a number, a number | [kareladb backup](backup-and-safety.md#kareladb-backup) |
| `--logs-from`, `--until` | folder, time | [kareladb restore](backup-and-safety.md#kareladb-restore) |
| `--accept-log-loss` | - | [kareladb repair](cli-maintenance.md#kareladb-repair) |
| `--role` | `admin`/`write`/`read`/`none` | [kareladb user add](cli-users.md#kareladb-user-add) |

- **Notes:** an option a command does not know is **ignored without a message**. Check the spelling: `--hard-link` (without `s`) makes a normal backup.
- An option that takes a value always takes the **next word**, even when that word starts with `--`. So `--token --port 9901` sets the token to `--port`.
- A word that is not an option counts as an argument. `kareladb sql market "SELECT 1" --formt csv` has one argument too many (`csv`), so it prints the usage line.
- Text in arguments may use any language: `kareladb sql market "INSERT ... 'नेपाल'"` works on Windows too.

**Command line: A misspelled option with a value** (sample data: sample)

```bash
kareladb sql market "SELECT 1" --formt csv
```

Output:

```text
usage: kareladb sql <db> "SQL" [--format table|csv|json] [--max-rows N] [--backups <dir>]
```

exit code 1
