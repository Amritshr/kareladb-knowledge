# Troubleshooting a running server

> What to look at, and what to change, when the server is slow, readers wait, memory or disk grows, the start is slow, a timer or a backup does not run, or data must come back.

- Category: Backup, check, repair, restore
- Keywords: troubleshooting, runbook, production problem, incident, server slow, slow server, slow queries, readers wait, reads wait, busy, table is busy, 55P03, 40001, lock timeout, memory high, out of memory, memory full, disk full, disk growing, disk space, trash, keep\_versions, last shutdown: not clean, slow start, start-up slow, log replay, timer not running, timer did not run, backup failed, restore, what to do, symptom
- See also: [Monitor panel (memory, processor, caches)](console-monitor.md), [Health, info, check and backup over HTTP (metrics)](http-server-info.md#metrics), [Health, info, check and backup over HTTP (slow-queries)](http-server-info.md#slow-queries), [Transactions (lock-timeout)](transactions.md#lock-timeout), [kareladb serve (memory-limit)](cli-serve.md#memory-limit), [Databases and the data folder (purge-trash)](databases.md#purge-trash), [Timers](timers.md), [Backups on a schedule](backup-schedule.md), [Backup, check, repair and restore (after-damage)](backup-and-safety.md#after-damage)

Each part below is one **symptom**: what you see, where to **check**, and the **fix**. Start with the console's [Monitor](console-monitor.md): it shows memory, the statements running now and the slow statements on one page.

The checks use three routes. Send the token as for any route: `Authorization: Bearer <token>`.

| Route | Shows |
|---|---|
| [`GET /api/stats`](http-server-info.md#api-stats) | memory, running statements, waits, snapshot reads, databases that are still opening |
| [`GET /metrics`](http-server-info.md#metrics) | the same counters for Prometheus or Grafana |
| [`GET /api/slow-queries`](http-server-info.md#slow-queries) | the statements that took longer than `--slow-query-ms` (1 second unless set) |

<a id="slow"></a>

## The server is slow

| Check | What it tells you |
|---|---|
| Monitor, **Statements running now** | one long statement that holds everything up. **Cancel** stops it. |
| `GET /api/slow-queries?limit=20` | which statements are slow, who sent them, how many rows they gave |
| `kdb_slow_statements_total` in `/metrics` | whether slow statements are new or have always been there |
| `kdb_gate_waits_total{mode}`, `kdb_gate_wait_seconds_total{mode}` | time spent **waiting for a lock**, not working: see [readers wait](#readers-wait) |
| `kdb_partition_loads_total` rising fast | data is read from disk again and again: `--memory` is too small for what is queried |
| `EXPLAIN <the slow query>` | whether the query reads every partition (`scan table t (120 of 120 partitions ...)`) |

- **Fix:** give a time range to queries of big time-series tables, add an [index](indexes.md) for lookups by one column, and see [performance tips](performance-tips.md). Stop a runaway statement with **Cancel**, and limit them with `--statement-timeout` ([protection](protection.md)).

**HTTP: The newest slow statements**

```http
GET /api/slow-queries?limit=5
```

Response:

HTTP 200 (application/json)

```text
{
  "threshold_ms": 1000,
  "recorded": 0,
  "queries": []
}
```

**Example: How much of the table a query reads**

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO ticks VALUES ('2026-09-23T10:00:00Z', 'CITY', 510), ('2026-09-24T10:00:00Z', 'CITY', 512);
```

```sql
EXPLAIN SELECT max(price) FROM ticks WHERE time IN '2026-09-24';
```

Result:

| plan (STRING) |
|---|
| scan table ticks (1 of 2 partitions, about 2 rows) |
| answer from saved stats of table ticks: 1 of 1 partitions from the partition list and their files' stats (0 in memory, 0 partitions loaded, 1 file headers read); 0 partitions scanned |
| build 2 of 3 stored column(s) per row: time, price |
| filter while scanning: 1 condition(s) |
| group by 0 key(s), 1 aggregate(s) |
| engine: column |

(6 rows)

<a id="readers-wait"></a>

## Readers wait for a writer

A `SELECT` that is quick at night takes seconds by day, while a load, a trigger or a long `CALL` writes the same table.

| Check | What it tells you |
|---|---|
| The start-up lines, `readers ...` | whether [reader yield](transactions.md#reader-yield) is on |
| `kdb_gate_wait_seconds_total{mode="read"}` | how long readers waited in total |
| `snapshot_reads` in `/api/stats` | whether [snapshot reads](transactions.md#snapshot-reads) are on and used |

- **Fix:**
  - Keep reader yield on (`--reader-yield on`, `KARELADB_READER_YIELD=on`; on unless set). Readers then get in between the writer's statements.
  - Turn on snapshot reads (`--snapshot-reads on`, `KARELADB_SNAPSHOT_READS=on`) so readers do not wait even for one long statement, also on tables with an index of up to 1,000,000 rows (`--snapshot-index-rows`).
  - Split one huge statement (`INSERT ... SELECT` of millions of rows) into smaller ones: readers can only get in between statements.

<a id="busy"></a>

## Errors 55P03 and 40001: the table is busy

`table 'x' is busy: another transaction has held it for N ms` means a writer waited the [lock timeout](transactions.md#lock-timeout) (5 seconds unless set) for another writer of the same table. Nothing of the statement was done.

| Code | When | Fix |
|---|---|---|
| `55P03` (HTTP 503) | a statement outside `BEGIN ... COMMIT` | send it again |
| `40001` (HTTP 503) | inside `BEGIN ... COMMIT` | `ROLLBACK` and run the whole transaction again; drivers retry this code by themselves |
| `40P01` | two transactions that would wait for each other | run it again |

| Check | What it tells you |
|---|---|
| Monitor, **Statements running now** | the transaction that holds the table, and for how long |
| `idle_in_transaction_session_timeout` | a client that sent `BEGIN` and then nothing keeps the table until it is rolled back (30 s unless set, see [idle transactions](transactions.md#idle-timeout)) |

- **Fix:** keep transactions short. For many small writers of one table that should queue instead of failing, raise the wait for them: `SET lock_timeout = '20s'` in the session, `X-KDB-Lock-Timeout: 20s` on one request, or `--lock-timeout` for the server.

**Example: Let this session wait longer for a busy table, then go back to the server's wait**

```sql
SET lock_timeout = '20s';
SET lock_timeout = DEFAULT;
```

Result:

`SET lock_timeout = '20s'`

```text
lock_timeout is 20 s for this session
```

`SET lock_timeout = 'DEFAULT'`

```text
lock_timeout is the server's default again
```

<a id="memory"></a>

## Memory is high

| Check | What it tells you |
|---|---|
| Monitor, **Memory in RAM** and **Most it ever held** | what the process holds now, and at its peak |
| `kdb_memory_bytes{kind}` in `/metrics` | which part is big: `table_data`, `key_maps`, `indexes`, `pending`, `result_cache`, `allocator` ... |
| `kdb_memory_level` | 0 green, 1 yellow, 2 red: near the [memory limit](cli-serve.md#memory-limit) |
| errors `memory full: ...` (HTTP 503) | the limit stopped new work instead of the process being killed |

| Setting | What it limits |
|---|---|
| `--memory <MB>` (`KARELADB_MEMORY`) | table data kept loaded. Data over it is read from disk again. |
| `--memory-limit <size>` (`KARELADB_MEMORY_LIMIT`) | everything together. Keep `--memory` at about half of it. |
| `--max-result-memory` | one query's result ([protection](protection.md#memory-limits)) |
| `GLIBC_TUNABLES=glibc.malloc.arena_max=8:glibc.malloc.trim_threshold=67108864` | Linux and Docker: how much freed memory the C library keeps; without it the process can hold far more than it uses |

- **Fix:** `allocator` big: set `GLIBC_TUNABLES` as above (see [Docker](install-packages.md#docker)). `table_data` big: lower `--memory`. A query that needs much memory: add a time range or a `LIMIT`. A transaction that fails with `transaction too big for memory`: split it.

<a id="disk"></a>

## The disk keeps growing

| Check | What it tells you |
|---|---|
| [`GET /api/disk`](http-server-info.md#api-disk), or the console's [Keep data](console-keep-data.md) page | the size of the data, of older file versions, of the trash, and of the log |
| `kdb_database_disk_bytes{database,kind}` in `/metrics` | the same, over time |

| Big part | Why | Fix |
|---|---|---|
| `previous_bytes` | every checkpoint keeps older versions of each file for repairs (`keep_versions`, 2 unless set) | `PURGE VERSIONS KEEP 1`, or a lower `keep_versions` in `kareladb.conf` ([versions](databases.md#purge-versions)) |
| `trash_bytes` | replaced files wait `trash_keep_hours` (1 hour), dropped databases wait for ever | `PURGE TRASH`, or `PURGE TRASH ALL` for dropped databases ([trash](databases.md#purge-trash)) |
| dropped tables | `DROP TABLE` keeps a table for `--trash-days` (7) so `UNDROP TABLE` works | `SHOW DROPPED TABLES`, then `DROP TABLE _dropped_...` ([the trash](trash.md)) |
| `wal_archive_bytes` | the old log is kept for point-in-time restores | a shorter `WAL_ARCHIVE` ([databases](databases.md#wal-archive)) |
| `data_bytes` | the rows themselves | a [TTL](alter-table.md#set-ttl) or `DROP PARTITION` for old days |

**HTTP: What a database takes on disk**

Setup:

```text
CREATE TABLE ticks (time TIMESTAMP, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO ticks VALUES ('2026-09-24T10:00:00Z', 1.5);
```

```http
GET /api/disk
```

Response:

HTTP 200 (application/json)

```text
{
  "database": "demo",
  "data_files": 1,
  "data_bytes": 236,
  "tail_files": 0,
  "tail_bytes": 0,
  "delta_files": 0,
  "delta_bytes": 0,
  "previous_files": 0,
  "previous_bytes": 0,
  "trash_folders": 0,
  "trash_bytes": 0,
  "wal_bytes": 1048640,
  "wal_archive_bytes": 0,
  "total_bytes": 1048876,
  "trash_purged_bytes": 0
}
```

**Example: Free older file versions and the trash**

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO ticks VALUES ('2026-09-24T10:00:00Z', 1.5);
```

```sql
PURGE VERSIONS KEEP 1;
PURGE TRASH;
```

Result:

`PURGE VERSIONS KEEP 1`

```text
0 older file version(s) removed (0 bytes), 1 kept per file; freed 0 bytes from the trash
```

`PURGE TRASH`

```text
removed 0 folder(s) from the trash, freed 0 bytes
```

<a id="slow-start"></a>

## The start is slow, or says "last shutdown: not clean"

`last shutdown: not clean (crash or kill)` in the start-up lines means the server was killed, not stopped. That is not damage: KarelaDB replays the log, and every confirmed change comes back. Replaying a long log takes time.

| Check | What it tells you |
|---|---|
| the `recovery` start-up line | clean or not, and how many log records were replayed |
| `opening_databases` in `/api/stats` | databases still opening, and for how long |

- **Fix:** stop the server so it can finish: Ctrl+C, `docker stop`, or a service stop. A Docker container needs `--stop-timeout 60` when it is **created**; without it, Docker Desktop kills it about 1 second after asking it to stop, and every start replays the log ([Docker](install-packages.md#docker), [stopping](cli-serve.md#stop)). Do not use `docker rm -f` or `docker kill` on a running server.

<a id="timer"></a>

## A timer does not run

| Check | What it tells you |
|---|---|
| [`GET /api/timers`](timers.md#get-api-timers) | `enabled`, `next_run_ms` (0 = off), `last_run_ms`, `last_ok`, `last_error` |
| `kdb_timer_failures_total`, `kdb_timer_late_seconds_max` | failed runs, and how late runs started |

| Cause | Fix |
|---|---|
| the timer is off | turn it on (**Timers** page, or `POST /api/timers/<name>/enable`) |
| it runs at the wrong hour | times are the server's clock; a container runs on UTC. Set `--timezone Asia/Kathmandu` |
| `last_error` says why | fix the SQL, or the rights of the user who saved it last (it runs with them) |
| the run before is still going | a run is skipped when the one before has not finished. Make the SQL faster; a run stops after 10 minutes |
| its database was dropped | delete the timer |

**HTTP: Every timer, with its last run and error**

```http
GET /api/timers
```

Response:

HTTP 200 (application/json)

```text
{
  "now_ms": 1792821180685,
  "timers": []
}
```

<a id="backup"></a>

## A backup failed

| Check | What it tells you |
|---|---|
| `backup_schedule` in [`GET /api/info`](backup-schedule.md#backup-status) | `last_run_ok`, `warning` (`the last good backup of 'x' is N hours old`), and per database `error` |
| `backup_command` in `/api/info` | the copy command's exit code and the end of what it printed |
| `kareladb backups <dir>` | the backups there, and whether each is whole |

| Cause | Fix |
|---|---|
| disk full | free space, or keep fewer backups (`backup_keep_daily`, `backup_keep_weekly`) ([when the disk is full](backup-and-safety.md#disk-full)) |
| the folder is not there, or not writable | inside Docker it must be under a mounted volume |
| the copy command failed | run the command by hand with the same folder |

Then run one backup now to see that it works: `POST /api/backup`, or **Back up now** in the console.

<a id="restore"></a>

## Getting data back

| What happened | Steps |
|---|---|
| a table was dropped | `UNDROP TABLE t` within `--trash-days` ([the trash](trash.md)) |
| a bad `UPDATE` or `DELETE` | [restore while the server runs](backup-and-safety.md#restore-online): `POST /api/restore` with `"until"` one second before the mistake into a new name, check it, then `POST /api/databases/swap` |
| damaged files (`failed its checksum`, `DAMAGED`) | stop, copy the folder, `kareladb check`, `kareladb repair --backups <dir>` ([after damage](backup-and-safety.md#after-damage)) |
| the whole folder is lost | `kareladb restore <newest backup> <new folder>`, `kareladb check <new folder>`, then start the server on it ([kareladb restore](backup-and-safety.md#kareladb-restore)) |

**Command line: Check a database, then repair it from the backups** (sample data: sample)

```bash
kareladb check market
kareladb repair market --backups backups
```

Output:

`> kareladb check market`

```text
checked 14 files (76.1 KB) and 1 log segments
OK: no damage found
```

`> kareladb repair market --backups backups`

```text
manifest copy: a, last shutdown: clean
replayed 0 transactions after LSN 30, last LSN 30

Nothing to repair.
```
