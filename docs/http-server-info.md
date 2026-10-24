# Health, info, check and backup over HTTP

> Check that the server is alive, read the tables, disk use and health of a database, look for damage, make and list backups, watch deferred trigger queues, and read the server's memory, processor and settings.

- Category: HTTP API
- Keywords: health, /health, monitoring, uptime, api/info, table list, recovery\_summary, damaged, last\_lsn, api/check, scrub, damage, api/backup, api/backups, api/restore, restore while running, point\_in\_time, api/databases/swap, swap databases, backup\_command, backup folder, --backups, last\_backup, server\_time\_ms, auth\_required, api/disk, disk usage, trash\_bytes, wal\_archive\_bytes, api/trigger-queue, trigger queue, deferred trigger, oldest\_pending\_age\_ms, zone\_partition\_skips, zone\_block\_skips, slice\_reads, slice\_cache\_hits, slice\_cache\_bytes, KARELADB\_SLICE\_CACHE\_MB, kdb\_slice\_reads\_total, cache\_pinned, cache\_verify\_checks, cache\_verify\_mismatches, rev\_values, wal\_archive\_mb, web\_dir, help\_dir, skill\_dir, metrics, /metrics, Prometheus, Grafana, slow queries, slow-query log, api/slow-queries, --slow-query-ms, KARELADB\_SLOW\_QUERY\_MS, trash\_purged\_bytes
- See also: [HTTP API overview](http-overview.md), [Backup, check, repair and restore](backup-and-safety.md), [kareladb info, check, repair, dump-file](cli-maintenance.md), [Web console (health-box)](web-console.md#health-box), [Grafana and Prometheus](grafana.md)

These routes tell you how the server and a database are doing. The [web console](web-console.md#health-box) uses them for its table list and health box.

- `GET /health` is for monitoring: it needs no login and never touches data.
- The other routes work on one database: `db=<name>` or the header `X-KDB-Database` ([choosing the database](http-overview.md#database)).
- Backups go to the backup folder: `_backups` in the data folder unless `--backups <folder>` (or `KARELADB_BACKUP_DIR`, `backup_dir` in `kareladb.conf`) names another ([where the settings come from](backup-schedule.md#backup-settings)).

## GET /health

Syntax:

```sql
GET /health
```

Answers when the server is running. Use it to check that KarelaDB is up (a monitoring script, a load balancer, a start script that waits for the server).

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| (none) | - | No database, no login | - |

| Answer field | Meaning |
|---|---|
| `status` | always `"ok"`: the server is running |
| `ready` | `false` while the server still opens the default database after a start (a long log replay after a crash, a slow disk); `true` after that. Requests for that database wait until it is open; other databases answer at once |
| `starting` | only while `ready` is `false`: what it is doing, like `opening the default database 'default': replaying the log, 12 s so far` |
| `version` | the KarelaDB version |
| `server_time_ms` | the server clock: milliseconds since 1970-01-01 UTC |
| `auth_required` | `true` when other requests need a token or a login |
| `login` | `true` when the data folder has users (the console then shows a login form instead of a token box) |

- **Status codes:** 200; 503 while the server is stopping ([drain](cli-serve.md#stop)). When the server does not run, there is no answer at all (the connection is refused).
- **Notes:** `/health` never needs a token or login, even on a server that has them. It does not open a database, so it stays fast when a database is busy. When every HTTP worker is busy with queries, `/health` does not wait in line behind them: a thread of its own answers it (plain HTTP; over https it waits for a worker as before).
- **At start:** the port answers within about a second, however many databases the data folder holds. Only the default database is opened at start; every other one opens when it is first used. A start script that must wait for the default database waits for `"ready": true`.

**HTTP: Is the server alive?**

```http
GET /health
```

Response:

HTTP 200 (application/json)

```text
{
  "status": "ok",
  "version": "0.2.0-dev",
  "product": "KarelaDB",
  "server_time_ms": 1792824013407,
  "auth_required": false,
  "login": false,
  "tls": false,
  "ready": true,
  "standby": false,
  "role": "leader"
}
```

```bash
curl -s http://127.0.0.1:9900/health
```

```powershell
# Wait until a server that is starting answers (at most 10 seconds).
foreach ($i in 1..50) {
  try { $h = Invoke-RestMethod http://127.0.0.1:9900/health; "KarelaDB $($h.version) is up"; break }
  catch { Start-Sleep -Milliseconds 200 }
}
```

```python
import requests

try:
    h = requests.get("http://127.0.0.1:9900/health", timeout=3).json()
    print("up, version", h["version"])
except requests.RequestException:
    print("KarelaDB is down")
```

## GET /api/info

Syntax:

```sql
GET /api/info[?db=<name>]
```

Everything about one database: its tables and columns, sizes, damage, what happened when it was opened, and the last backup.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `db` | URL | The database (or the header `X-KDB-Database`) | the default database |

| Answer field | Meaning |
|---|---|
| `database` | The database name |
| `dir` | Its folder |
| `version` | The KarelaDB version |
| `opened_ms` | When the server opened the database (ms since 1970, UTC) |
| `server_time_ms` | The server clock |
| `last_lsn` | The number of the last change in the log (the **LSN**, log sequence number). It grows with every change. |
| `data_files`, `data_bytes` | Count and size of the data files |
| `tables[]` | One object per table: `name`, `kind` (`timeseries` or `relational`), `partition` (`NONE`, `DAY`, `MONTH`, `YEAR`), `timestamp_column`, `rows`, `bytes`, `columns[]`, `create_sql` |
| `tables[].columns[]` | `name`, `type`, `primary_key`, `not_null`, `computed` (a column made from others), `references` (the table and column it points to, or empty) |
| `damaged[]` | Damaged files KarelaDB knows about; empty when all is well |
| `recovery_summary` | What KarelaDB did when it opened the database (for example after a crash) |
| `warning` | A warning when the data is far bigger than `--memory`; `""` when all is well |
| `backup_dir` | The backup folder of this database (empty when backups are off) |
| `last_backup` | The newest backup (same fields as [POST /api/backup](http-server-info.md#post-api-backup)), or `null` |
| `auth_required` | `true` when requests need a token or login |
| `read_only` | `true` when this database only reads |
| `protection` | The server's [protection](protection.md) settings: `statement_timeout_ms`, `max_result_bytes`, `max_groups`, `max_queries_per_user`, `safe_updates`, `running` (statements running now), `server_read_only`, `audit` |
| `backup_schedule` | The [backup schedule](backup-schedule.md) and its last run, or `null` without a schedule |
| `backup_command` | The [copy command](backup-schedule.md#backup-command) run after each backup and its last run, or `null` without one |
| `timers` | How many [timers](timers.md) of this database are on |

- **Status codes:** 200; 401/403 login or role (needs `read`); 404 unknown database; 500 the database cannot be read.
- **Notes:** views, functions and procedures are not in `tables[]`; use `SHOW VIEWS`, `SHOW FUNCTIONS` and `SHOW PROCEDURES` with [/exec](http-exec.md#get-exec).

**HTTP: A small database: one table**

Setup:

```text
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
INSERT INTO brokers VALUES (1, 'Keystone Securities'), (34, 'Vision Securities');
```

```http
GET /api/info
```

Response:

HTTP 200 (application/json)

```text
{
  "database": "demo",
  "dir": "kdb-data/demo",
  "version": "0.2.0-dev",
  "product": "KarelaDB",
  "opened_ms": 1792824013416,
  "server_time_ms": 1792824013461,
  "last_lsn": 4,
  "data_files": 1,
  "data_bytes": 231,
  "tables": [
    {
      "name": "brokers",
      "kind": "relational",
      "partition": "NONE",
      "timestamp_column": "",
      "rows": 2,
      "bytes": 0,
      "columns": [
        {
          "name": "id",
          "type": "INT",
          "primary_key": true,
          "not_null": false,
          "computed": false,
          "references": ""
        },
        {
          "name": "name",
          "type": "STRING",
          "primary_key": false,
          "not_null": true,
          "computed": false,
          "references": ""
        }
      ],
      "create_sql": "CREATE TABLE brokers (\n  id INT PRIMARY KEY,\n  name STRING NOT NULL\n)"
    }
  ],
  "damaged": [],
  "recovery_summary": "manifest copy: -, last shutdown: clean\nreplayed 0 transactions after LSN 0, last LSN 0\nopened in 0 ms: manifest 0 ms, 0 files read 0 ms, log check 0 ms, replay 0 ms (0 transactions), clean-up 0 ms",
  "warning": "",
  "backup_dir": "./backups/demo",
  "last_backup": null,
  "auth_required": false,
  "read_only": false,
  "protection": {
    "statement_timeout_ms": 60000,
    "max_result_bytes": 1073741824,
    "max_groups": 5000000,
    "max_queries_per_user": 32,
    "safe_updates": false,
    "running": 1,
    "server_read_only": false,
    "audit": true
  },
  "backup_schedule": null,
  "backup_command": null,
  "timers": 0
}
```

```powershell
$info = Invoke-RestMethod "http://127.0.0.1:9900/api/info?db=market"
"log LSN: $($info.last_lsn)   damaged files: $($info.damaged.Count)"
$info.tables | Select-Object name, kind, partition, timestamp_column, rows | Format-Table -AutoSize
```

```js
const info = await (await fetch("http://127.0.0.1:9900/api/info?db=market")).json();
for (const t of info.tables) console.log(t.name, t.kind, t.rows, t.columns.map((c) => `${c.name} ${c.type}`).join(", "));
```

<a id="api-disk"></a>

## GET /api/disk

Syntax:

```sql
GET /api/disk[?db=<name>]
```

What one database takes on disk, part by part. The console's [Keep data page](console-keep-data.md) shows it. It walks the trash folder, so it is a separate route and not part of `/api/info`. It never waits for running statements and never holds them up: while the database is busy writing, the answer is its last measure (each open database measures about once a minute; `measured_ms` says when).

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `db` | URL | The database (or the header `X-KDB-Database`) | the default database |

| Answer field | Meaning |
|---|---|
| `database` | The database name |
| `data_files`, `data_bytes` | The current version of every file |
| `tail_files`, `tail_bytes` | Of those: [tail files](partitions-and-dedup.md#tail-files), rows appended after a partition's file and not yet folded back into it |
| `delta_files`, `delta_bytes` | Of those: [delta files](partitions-and-dedup.md#delta-files), rows of a partition replaced or deleted and not yet compacted into it |
| `previous_files`, `previous_bytes` | Older versions kept for repairs (`PURGE VERSIONS` removes them) |
| `trash_folders`, `trash_bytes` | Replaced files waiting in `_trash` to be removed (`PURGE TRASH`) |
| `wal_bytes` | The log (the **WAL**) |
| `wal_archive_bytes` | Old log kept for repairs and restores (`WAL_ARCHIVE`) |
| `total_bytes` | All of the above together |
| `trash_purged_bytes` | What the database removed from its trash by itself since it opened |

- **Status codes:** 200; 401/403 login or role (needs `read`); 404 unknown database.
- **Notes:** see [trash](trash.md) and [versions](versions.md) for how to free the space.

**HTTP: Disk use of a small database**

Setup:

```text
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
INSERT INTO brokers VALUES (1, 'Keystone Securities'), (34, 'Vision Securities');
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
  "data_bytes": 231,
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
  "total_bytes": 1048871,
  "trash_purged_bytes": 0
}
```

<a id="api-trigger-queue"></a>

## GET /api/trigger-queue

Syntax:

```sql
GET /api/trigger-queue[?db=<name>][&trigger=<name>][&wait=<time>]
```

The queues of the database's [deferred triggers](triggers.md#deferred), and every job that has not finished yet. Use it to see the lag after a load, or to wait until the work of a load is done.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `db` | URL | The database (or the header `X-KDB-Database`) | the default database |
| `trigger` | URL | Only this trigger | every deferred trigger |
| `wait` | URL | Hold the answer until the jobs finished, or stand still behind a failed job, for at most this long (`500ms`, `30s`, `10min`) | no wait |

| Answer field | Meaning |
|---|---|
| `queues[]` | One object per deferred trigger (below) |
| `jobs[]` | Every job not finished yet: `id`, `trigger`, `table`, `status`, `rows`, `commit_lsn`, `made_ms`, `took_ms`, `error` |

Each `queues` object:

| Field | Meaning |
|---|---|
| `trigger`, `table`, `enabled` | The trigger, its table, and whether it is enabled |
| `timeout_ms` | Its `DEFERRED TIMEOUT`; `0` = the statement timeout |
| `pending` | Jobs not finished: waiting, running and failed |
| `oldest_pending_age_ms` | How long the oldest of those has waited: the lag. `0` = none. |
| `running_job`, `running_since_ms` | The job running now (same fields as `jobs[]`), or `null` |
| `failed_job`, `failed_ms` | The job that failed and stopped the queue, or `null` ([recovery](triggers.md#deferred-recovery)) |
| `last_done_job` | The newest job that finished (done or skipped) |

A job's `status` is `waiting`, `running`, `done`, `skipped`, `failed`, or `blocked` (waiting behind a failed job).

- **Status codes:** 200; 400 a `wait` that is not a time; 401/403 login or role (needs `read`); 404 unknown database, or `trigger` names no deferred trigger.
- **Notes:** `GET /api/stats` shows the same queues for every open database, under `trigger_queues`. A load can also wait for its own jobs: `POST /write?...&wait=trigger` ([line protocol](line-protocol.md)).

**HTTP: One deferred trigger, after a load**

Setup:

```text
CREATE TABLE trades (id INT, qty INT);
CREATE TABLE seen (id INT);
CREATE TRIGGER copy_ids AFTER INSERT ON trades DEFERRED EXECUTE INSERT INTO seen SELECT id FROM NEW;
INSERT INTO trades VALUES (1, 10), (2, 20);
```

```http
GET /api/trigger-queue?wait=10s
```

Response:

HTTP 200 (application/json)

```text
{
  "queues": [
    {
      "trigger": "copy_ids",
      "table": "trades",
      "enabled": true,
      "timeout_ms": 0,
      "pending": 0,
      "oldest_pending_age_ms": 0,
      "running_job": null,
      "running_since_ms": 0,
      "failed_job": null,
      "failed_ms": 0,
      "last_done_job": 1,
      "failures": 0,
      "retries": 0,
      "refused_writes": 0
    }
  ],
  "jobs": []
}
```

**HTTP: An unknown trigger**

```http
GET /api/trigger-queue?trigger=nope
```

Response:

HTTP 404 (application/json)

```text
{"error": "deferred trigger 'nope' does not exist"}
```

## POST /api/check

Syntax:

```sql
POST /api/check[?db=<name>]
```

Reads every block of every data file and of the log, and checks each against its checksum (a small number that changes when the data is damaged). Use it to find damage early.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `db` | URL | The database (or the header `X-KDB-Database`) | the default database |

| Answer field | Meaning |
|---|---|
| `ok` | `true` when nothing is damaged |
| `files_checked` | Data files read |
| `bytes_checked` | Bytes read |
| `wal_segments_checked` | Log files read (the **WAL**, write-ahead log, where every change is written first) |
| `problems[]` | One text for each problem found; empty when `ok` |
| `elapsed_us` | Time it took, in microseconds |

- **Status codes:** 200 (also when damage is found: then `ok` is `false`); 401/403 login or role (needs `admin` on the database); 404 unknown database; 405 for `GET`.
- **Notes:** a big database takes time, because every file is read. When `ok` is `false`: stop the server and run `kareladb repair` ([check, repair, restore](cli-maintenance.md)). `CHECK TABLE name` in SQL checks one table.

**HTTP: Check the sample database** (sample data: sample)

```http
POST /api/check
```

Response:

HTTP 200 (application/json)

```text
{
  "ok": true,
  "files_checked": 14,
  "bytes_checked": 77929,
  "wal_segments_checked": 1,
  "problems": [],
  "elapsed_us": 764
}
```

**HTTP: GET is not allowed: checking is work for the server**

```http
GET /api/check
```

Response:

HTTP 405 (application/json)

```text
{"error": "method GET is not allowed here"}
```

## POST /api/backup

Syntax:

```sql
POST /api/backup[?db=<name>]
```

Makes a **verified backup** of the database while the server keeps running: it copies the files into a new folder and reads the copy back to check it.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `db` | URL | The database (or the header `X-KDB-Database`) | the default database |

| Answer field | Meaning |
|---|---|
| `name` | The backup's folder name: the time, like `20260911-081748-398` |
| `dir` | The backup folder: `<backup folder>/<database>/<name>` |
| `created_ms`, `created` | When it was made: ms since 1970, and as UTC text |
| `end_lsn` | The last change in the backup |
| `checkpoint_lsn` | The last change already in the data files when it was made |
| `files`, `bytes` | Count and size of the copied files |

- **Status codes:** 200; 400 backups are off (`no backup folder is set; ...`); 401/403 login or role (needs `admin` on the database); 404 unknown database; 500 disk trouble; 503 busy.
- **Notes:** other requests can go on while the backup runs. After each backup, old backups are removed: the newest of each of the last 7 days and of the last 4 weeks are kept (`--keep-daily`, `--keep-weekly`). `BACKUP DATABASE` in SQL (with `POST /exec`) does the same. A backup on the same disk is lost with that disk: a [copy command](backup-schedule.md#backup-command) copies each one off the server.

**HTTP: Make a backup, then list the backups** (sample data: sample)

```http
POST /api/backup
###
GET /api/backups
```

Response:

`POST /api/backup`

HTTP 200 (application/json)

```text
{
  "name": "20261024-064013-540",
  "dir": "./backups/demo/20261024-064013-540",
  "created_ms": 1792824013540,
  "created": "2026-10-24T06:40:13.540Z",
  "end_lsn": 30,
  "checkpoint_lsn": 30,
  "files": 9,
  "bytes": 194519
}
```

`GET /api/backups`

HTTP 200 (application/json)

```text
{
  "backups": [
    {
      "name": "20261024-064013-540",
      "dir": "./backups/demo/20261024-064013-540",
      "created_ms": 1792824013540,
      "created": "2026-10-24T06:40:13.540Z",
      "end_lsn": 30,
      "checkpoint_lsn": 30,
      "files": 9,
      "bytes": 194519
    }
  ],
  "backup_dir": "./backups/demo",
  "point_in_time": {
    "possible": true,
    "from_ms": 1792824013540,
    "from": "2026-10-24T06:40:13.540Z",
    "from_backup": "20261024-064013-540",
    "log_first_lsn": 1,
    "why": "",
    "wal_archive_max_bytes": 1073741824
  }
}
```

```powershell
# daily-backup.ps1: a backup and a check of a running server (run it with Task Scheduler).
$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/api/backup?db=market"
"backup $($r.name): $($r.files) files, $($r.bytes) bytes"
$c = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/api/check?db=market"
if (-not $c.ok) { Write-Output "CHECK FOUND A PROBLEM: $($c.problems -join '; ')"; exit 2 }
"check ok: $($c.files_checked) files"
```

```bash
# Linux cron, on a server with users: an admin user for that database.
curl -s -u admin:"$(cat /root/kdb-admin-password)" -X POST "http://127.0.0.1:9900/api/backup?db=shop"
```

## GET /api/backups

Syntax:

```sql
GET /api/backups[?db=<name>]
```

Lists the backups of the database, **newest first**.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `db` | URL | The database (or the header `X-KDB-Database`) | the default database |

| Answer field | Meaning |
|---|---|
| `backups[]` | One object per backup, with the fields of [POST /api/backup](http-server-info.md#post-api-backup): `name`, `dir`, `created_ms`, `created`, `end_lsn`, `checkpoint_lsn`, `files`, `bytes` |
| `backup_dir` | The folder they are in (`""` when backups are off) |
| `point_in_time.possible` | `true` when a [restore up to a time](backup-and-safety.md#pitr-window) works now |
| `point_in_time.from_ms`, `from` | The earliest time it can go back to (the time of `from_backup`) |
| `point_in_time.from_backup` | The oldest backup the kept log still reaches |
| `point_in_time.log_first_lsn` | The oldest log record the database still keeps |
| `point_in_time.why` | When `possible` is `false`: what to change |
| `point_in_time.wal_archive_max_bytes` | The old log this database may keep (`wal_archive`) |

- **Status codes:** 200; 401/403 login or role (needs `read`); 404 unknown database.
- **Notes:** without a backup folder the list is empty. To restore one while the server runs, use [POST /api/restore](#api-restore).

**HTTP: No backups yet**

```http
GET /api/backups
```

Response:

HTTP 200 (application/json)

```text
{
  "backups": [],
  "backup_dir": "./backups/demo",
  "point_in_time": {
    "possible": false,
    "from_ms": 0,
    "from": "",
    "from_backup": "",
    "log_first_lsn": 0,
    "why": "there is no backup yet: a point-in-time restore starts from one",
    "wal_archive_max_bytes": 1073741824
  }
}
```

```python
import requests

for b in requests.get("http://127.0.0.1:9900/api/backups", params={"db": "market"}).json()["backups"]:
    print(b["created"], b["files"], "files", b["bytes"], "bytes")
```

<a id="api-restore"></a>

## POST /api/restore

Syntax:

```sql
POST /api/restore[?db=<name>]
body: {"as": "<new database>", "database": "<name>", "backup": "<backup name>", "until": "<time>" | "latest", "until_ms": <ms>}
```

Restores a backup of a database into a **new** database while the server runs. The database itself is not touched. See [restore while the server runs](backup-and-safety.md#restore-online).

| Field | Meaning | Default |
|---|---|---|
| `as` | The name of the new database. It must not exist. | required |
| `database` | Whose backup (or `db=` / `X-KDB-Database`) | the default database |
| `backup` | One backup's name, from [GET /api/backups](#get-api-backups) | the newest one made before `until`, else the newest |
| `until` | Replay the database's own log up to this time: `2026-09-24 14:05:09` (UTC unless it ends in `Z` or an offset like `+05:45`). `latest` = all of the log. | the backup as it was |
| `until_ms` | The same time in ms since 1970 | |

| Answer field | Meaning |
|---|---|
| `database`, `source` | The new database and the one whose backup it is |
| `backup` | The backup used (fields of [POST /api/backup](#post-api-backup)) |
| `until_ms`, `used_log` | The time asked for (`null` = none), and whether the log was replayed |
| `opened`, `open_error` | The new database was opened and its log replayed; `false` with the reason if not |
| `notes` | What the restore did, like `stopped at the requested time: changes after LSN 36 are not restored` |
| `took_ms` | How long it took |
| `next` | What to do next |

- **Needs:** the user's own `ROLE` `admin`.
- **Status codes:** 200; 400 a missing or bad name, a bad `until`, or no backup older than `until`; 401; 403; 404 no such database, no backups, or no such backup; 409 the name is taken, or another restore is running; 500 the backup is damaged (`pick another one`) or a disk problem.
- **Notes:** one restore runs at a time. The source keeps taking reads and writes meanwhile; while its log is read, old log files stay in place. It is copied into a hidden folder first and only gets its name when complete, so nobody sees half a database. Each restore is in the [audit log](audit-log.md) (`event = 'restore'`).

**HTTP: A backup, then a restore of it into a new database** (sample data: sample)

```http
POST /api/backup
###
POST /api/restore
Content-Type: application/json

{"as": "demo_restored"}
###
DELETE /api/databases/demo_restored
```

Response:

`POST /api/backup`

HTTP 200 (application/json)

```text
{
  "name": "20261024-064013-715",
  "dir": "./backups/demo/20261024-064013-715",
  "created_ms": 1792824013715,
  "created": "2026-10-24T06:40:13.715Z",
  "end_lsn": 30,
  "checkpoint_lsn": 30,
  "files": 9,
  "bytes": 194519
}
```

`POST /api/restore`

HTTP 200 (application/json)

```text
{
  "database": "demo_restored",
  "source": "demo",
  "backup": {
    "name": "20261024-064013-715",
    "dir": "./backups/demo/20261024-064013-715",
    "created_ms": 1792824013715,
    "created": "2026-10-24T06:40:13.715Z",
    "end_lsn": 30,
    "checkpoint_lsn": 30,
    "files": 9,
    "bytes": 194519
  },
  "until_ms": null,
  "used_log": false,
  "opened": true,
  "open_error": "",
  "notes": [
    "restored 9 data files from ./backups/demo/20261024-064013-715; the log (up to LSN 30) is replayed on first open"
  ],
  "took_ms": 86,
  "next": "check 'demo_restored', then POST /api/databases/swap {\"database\":\"demo\",\"with\":\"demo_restored\"} to put it in place, or DROP DATABASE demo_restored"
}
```

`DELETE /api/databases/demo_restored`

HTTP 200 (application/json)

```text
{
  "name": "demo_restored",
  "dropped": true,
  "moved_to": "kdb-data/_trash/1792824013927-demo_restored"
}
```

**HTTP: The name is taken**

```http
POST /api/backup
###
POST /api/restore
Content-Type: application/json

{"as": "demo_twice"}
###
POST /api/restore
Content-Type: application/json

{"as": "demo_twice"}
```

Response:

`POST /api/backup`

HTTP 200 (application/json)

```text
{
  "name": "20261024-064013-741",
  "dir": "./backups/demo/20261024-064013-741",
  "created_ms": 1792824013741,
  "created": "2026-10-24T06:40:13.741Z",
  "end_lsn": 0,
  "checkpoint_lsn": 0,
  "files": 0,
  "bytes": 64
}
```

`POST /api/restore`

HTTP 200 (application/json)

```text
{
  "database": "demo_twice",
  "source": "demo",
  "backup": {
    "name": "20261024-064013-741",
    "dir": "./backups/demo/20261024-064013-741",
    "created_ms": 1792824013741,
    "created": "2026-10-24T06:40:13.741Z",
    "end_lsn": 0,
    "checkpoint_lsn": 0,
    "files": 0,
    "bytes": 64
  },
  "until_ms": null,
  "used_log": false,
  "opened": true,
  "open_error": "",
  "notes": [
    "restored 0 data files from ./backups/demo/20261024-064013-741; the log (up to LSN 0) is replayed on first open"
  ],
  "took_ms": 37,
  "next": "check 'demo_twice', then POST /api/databases/swap {\"database\":\"demo\",\"with\":\"demo_twice\"} to put it in place, or DROP DATABASE demo_twice"
}
```

`POST /api/restore`

HTTP 409 (application/json)

```text
{"error": "database 'demo_twice' already exists; restore into a new name, then swap or drop"}
```

<a id="api-swap"></a>

## POST /api/databases/swap

Syntax:

```sql
POST /api/databases/swap[?db=<name>]
body: {"database": "<name>", "with": "<other name>"}
```

The two databases trade their data, by renaming their folders. Everything KarelaDB keeps by **name** stays with the name: users' rights, `READ ONLY`, the dialect, `WAL_ARCHIVE`, timers and pins. So after a restore into `market_check`, a swap of `market` with `market_check` puts the restored data under `market` for everyone who uses it, and the old data is in `market_check`.

- **Needs:** the user's own `ROLE` `admin`.
- **Status codes:** 200 `{"swapped": true, "database", "with"}`; 400 `with` missing, the same database twice, or a database served by its path; 401; 403; 404 no such database; 409 one of them is in use (an open PostgreSQL connection, a session, a running request), being opened, or dropped.
- **Notes:** both databases are closed for the swap and open again at their next use. The swap is in the [audit log](audit-log.md) (`event = 'swap database'`). Swap again to undo it.

**HTTP: Swap a database with a restored copy, then swap back**

```http
POST /exec
Content-Type: text/plain

CREATE TABLE t (a INT); INSERT INTO t VALUES (1)
###
POST /api/backup
###
POST /exec
Content-Type: text/plain

INSERT INTO t VALUES (2)
###
POST /api/restore
Content-Type: application/json

{"as": "demo_old"}
###
POST /api/databases/swap
Content-Type: application/json

{"with": "demo_old"}
###
POST /exec
Content-Type: text/plain

SELECT count(*) FROM t
###
POST /api/databases/swap
Content-Type: application/json

{"with": "demo_old"}
###
DELETE /api/databases/demo_old
```

Response:

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "CREATE TABLE t (a INT); INSERT INTO t VALUES (1)",
  "results": [
    {
      "statement": "CREATE TABLE t (\n  a INT\n)",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "table 't' created",
      "timings": {"parse_us": 17, "execute_us": 18047}
    },
    {
      "statement": "INSERT INTO t VALUES (1)",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 17, "execute_us": 3068}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 34, "execute_us": 21115}
}
```

`POST /api/backup`

HTTP 200 (application/json)

```text
{
  "name": "20261024-064013-834",
  "dir": "./backups/demo/20261024-064013-834",
  "created_ms": 1792824013834,
  "created": "2026-10-24T06:40:13.834Z",
  "end_lsn": 4,
  "checkpoint_lsn": 4,
  "files": 2,
  "bytes": 707
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "INSERT INTO t VALUES (2)",
  "results": [
    {
      "statement": "INSERT INTO t VALUES (2)",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 17, "execute_us": 27}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 17, "execute_us": 27}
}
```

`POST /api/restore`

HTTP 200 (application/json)

```text
{
  "database": "demo_old",
  "source": "demo",
  "backup": {
    "name": "20261024-064013-834",
    "dir": "./backups/demo/20261024-064013-834",
    "created_ms": 1792824013834,
    "created": "2026-10-24T06:40:13.834Z",
    "end_lsn": 4,
    "checkpoint_lsn": 4,
    "files": 2,
    "bytes": 707
  },
  "until_ms": null,
  "used_log": false,
  "opened": true,
  "open_error": "",
  "notes": [
    "restored 2 data files from ./backups/demo/20261024-064013-834; the log (up to LSN 4) is replayed on first open"
  ],
  "took_ms": 51,
  "next": "check 'demo_old', then POST /api/databases/swap {\"database\":\"demo\",\"with\":\"demo_old\"} to put it in place, or DROP DATABASE demo_old"
}
```

`POST /api/databases/swap`

HTTP 200 (application/json)

```text
{"swapped": true, "database": "demo", "with": "demo_old"}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "SELECT count(*) FROM t",
  "results": [
    {
      "statement": "SELECT count(*) FROM t",
      "columns": [
        {"name": "count(*)", "type": "LONG"}
      ],
      "dataset": [
        [1]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 30, "execute_us": 148}
    }
  ],
  "columns": [
    {"name": "count(*)", "type": "LONG"}
  ],
  "dataset": [
    [1]
  ],
  "count": 1,
  "timings": {"parse_us": 30, "execute_us": 148}
}
```

`POST /api/databases/swap`

HTTP 200 (application/json)

```text
{"swapped": true, "database": "demo", "with": "demo_old"}
```

`DELETE /api/databases/demo_old`

HTTP 200 (application/json)

```text
{
  "name": "demo_old",
  "dropped": true,
  "moved_to": "kdb-data/_trash/1792824014157-demo_old"
}
```

<a id="api-stats"></a>

## GET /api/stats

Syntax:

```sql
GET /api/stats
```

What the server is doing right now: the memory and processor of the process, the statements running this second, and the memory and cache counters of every **open** database. Everything here is a counter already in memory, so it is cheap enough to ask for every couple of seconds - no file is read and no database is opened to answer it. The [Monitor page](console-monitor.md) of the console shows it.

| Answer field | Meaning |
|---|---|
| `version` | the KarelaDB version |
| `server_time_ms` | the server's clock (ms since 1970, UTC) |
| `process` | see the table below |
| `running` | one object per statement running now (HTTP and the PostgreSQL port together) |
| `can_cancel` | `true` when the server was started with query protection, so `DELETE /exec/<id>` works |
| `lanes` | [priority lanes](cli-serve.md#lanes): `enabled`, `heavy_slots`, `max_waiting` (HTTP places in line), `http_waiting`, `occupied` (heavy slots in use), `long_normal`, `heavy_ms`, `fast_ms`, `long_ms`, `shapes`, `heavy_shapes`, `cpu_priority`, `read_slots` ([read slots](cli-serve.md#read-slots): `slots`, `slot_ms`, `used`, `waiting`, `waited`, `wait_ms_total`, `wait_ms_max`), and per lane (`fast`, `normal`, `heavy`) `running`, `waiting`, `entered`, `waited`, `wait_ms_total`, `wait_ms_max`, `last_wait_ms`, `refused`, `overflowed` (heavy by history, HTTP line full: ran at once), `stopped_waiting`. Each object of `running` has `lane` and `waiting` too. |
| `zone_partition_skips`, `zone_block_skips` | since the process started: partitions not read and blocks not scanned because their saved column statistics (min and max) ruled the `WHERE` out |
| `slice_reads` | since the process started: partitions not in memory of which a one-symbol query read only that symbol's rows from the file (see [slice reads](performance-tips.md#slice-reads)) |
| `slice_cache_hits` | of those, slices found in the slice cache instead of the file |
| `slice_cache_bytes` | what the slice cache holds now (at most `KARELADB_SLICE_CACHE_MB`) |
| `search` | since the process started, all databases: `bm25_evaluations` (full-text ranks worked out), `top_k_searches` (`ORDER BY search_rank(...) DESC LIMIT n` answered from the index), `skipped_blocks` and `skipped_docs` (rows those searches skipped because they could not make the top n; see [search_rank](full-text-search.md#search-rank)); `segments_written`, `segment_extensions`, `segments_merged`, `segments_loaded`, `segment_rows_loaded`, `segments_damaged`, `segments_stale` and `rows_indexed` ([segments on disk](full-text-search.md#segments)) |
| `opening_databases` | one object per database a request is opening right now |
| `databases` | one object per **open** database; a database opens the first time it is used |
| `warnings` | sentences an operator should read now, one per problem. Today: a database far bigger than `--memory` (see [memory](cli-serve.md#memory-warning)). `[]` when all is well |

`process`:

| Field | Meaning |
|---|---|
| `resident_bytes` | memory the process holds in RAM now (Windows: working set; Linux: `VmRSS`) |
| `peak_resident_bytes` | the highest that has been since the process started |
| `virtual_bytes` | memory it asked for that is its own (Windows: private bytes, which can be **smaller** than resident; Linux: `VmSize`, which is larger) |
| `cpu_ms` | processor time used since the process started, user and kernel together |
| `uptime_ms` | how long the process has been up |
| `threads`, `open_files` | threads and open handles now |
| `cpu_count` | processors the process may use: inside `docker --cpus=2` this is 2, not the host's count ([self-tuning](cli-serve.md#self-tuning)) |
| `heap_bytes`, `heap_objects` | what KarelaDB's own objects hold now |
| `allocator` | the C library's allocator: `glibc` (the Docker image), `windows` or `other` |
| `allocator_retained_bytes` | `resident_bytes - heap_bytes`: memory that was freed but is still kept by the allocator, plus the program and its thread stacks (tens of MB). On glibc KarelaDB gives freed memory back in the background, so after work this falls back near that. |
| `allocator_arena_max` | how many glibc malloc arenas KarelaDB allows (`0` = the C library decides; `GLIBC_TUNABLES=glibc.malloc.arena_max=N` overrides) |
| `allocator_mmap_threshold` | blocks of this many bytes or more get memory of their own from the system. `0` = the C library moves the line itself. A `GLIBC_TUNABLES` with `trim_threshold` (as in the Docker example) stops glibc from moving it, so KarelaDB sets it to 32 MB; `glibc.malloc.mmap_threshold=N` overrides |
| `allocator_trims`, `allocator_trim_released_bytes`, `allocator_last_trim_ms_ago` | how often freed memory was given back, how much in total, and how long ago the last time was (`0` = never) |
| `allocator_purge_delay_ms` | the program built with mimalloc (the Docker image): how long memory a thread freed stays with it before it goes back to the system, 1000 unless `MIMALLOC_PURGE_DELAY` says otherwise. A query that comes within that time on the same thread reuses the pages instead of faulting them in again. `0` with another allocator |
| `allocator_longest_trim_ms` | the longest one give-back took, in milliseconds. Threads that need memory wait for it, so a long one is a pause of the whole server (HTTP and PostgreSQL port at once). One of 1 s or more is also written to the server log |
| `system_memory_bytes`, `system_memory_free_bytes` | RAM in the computer, and what is still free. Inside a container these are the container's limit and use, not the host's. |

`limits` - the CPU and memory the process may really use, and what KarelaDB sized from them ([self-tuning](cli-serve.md#self-tuning)):

| Field | Meaning |
|---|---|
| `cpus` | CPUs KarelaDB sizes its threads by: the smaller of the CPUs it may run on and the CPU quota, rounded up |
| `host_cpus`, `affinity_cpus` | the machine's processors, and those the process may run on (`0` = not known) |
| `cpu_quota` | the container's or job's CPU quota in CPUs (`1.5` for `--cpus=1.5`); `0` = none |
| `cpu_source` | what decided `cpus`: `machine`, `affinity`, `cgroup v2 cpu.max`, `cgroup v1 cpu.cfs_quota_us` or `job object CPU rate` |
| `pinned_cpus` | the CPUs KarelaDB's threads are pinned to, like `"0-3"` ([`--pin-threads`](cli-serve.md#pin-threads): `on`, or `auto` inside a CPU quota); `""` when not pinned |
| `pinned_threads` | `on`: threads that pinned themselves since the start; `auto`: the threads pinned now (`0` when not pinned) |
| `memory_limit_bytes`, `memory_source` | the container's or job's memory limit (`0` = none) and where it was read |
| `machine_memory_bytes` | RAM in the machine |
| `query_threads`, `query_threads_follow` | the query pool's size now, and whether it follows the CPU limit (`false` with `--threads`) |
| `process_memory_limit_bytes`, `process_memory_limit_follows` | the memory limit for the whole process now, and whether it follows the container's (`false` with `--memory-limit`) |
| `check_interval_ms`, `checks`, `changes`, `last_check_ms`, `last_change` | how often the limits are read (`0` = only at start), readings and changes since start, when the last reading was, and the log line of the last change |

`memory_limit` - the [memory limit for the whole process](cli-serve.md#memory-limit) (`--memory-limit`):

| Field | Meaning |
|---|---|
| `limit_bytes` | the limit; `0` = none |
| `level` | `green` (under 80%), `yellow` (80-95%: memory is being given back), `red` (95% and over: quick statements run in the reserve, others wait, then get `memory full`) |
| `in_use_bytes` | the number the limit is checked against: `heap_bytes`, or the resident size when that is more. Over by the resident size alone (heap under 80%) the level stops at `yellow` |
| `level_from` | `in_use`, or `heap` with `KARELADB_LEVEL_FROM_HEAP=1` (the level from the heap alone) |
| `heap_bytes` | what KarelaDB's objects hold now |
| `table_data_bytes`, `key_map_bytes`, `view_bytes` | loaded table data of all databases, split as in `memory` below |
| `pending_bytes` | changes not yet written to partition files, all databases |
| `index_bytes` | `CREATE INDEX` indexes, all databases |
| `result_cache_bytes` | the result caches |
| `other_bytes` | the rest of the heap: rows of running queries, results being sent, sessions |
| `allocator_bytes` | `resident_bytes - heap_bytes` |
| `refused` | statements told `memory full` since the start |
| `reserve_in_use`, `reserve_admitted` | quick statements (reads, no writes or loads) running now in the reserve kept for them at red (at most 8), and how many were let in that way since the start |
| `reserve_lifted` | of those, how many needed more than their place, waited for memory to come back and then ran on without the cap |
| `stopped` | running statements stopped with `memory full` since the start (the process went over the limit, and each held the most memory) |
| `relieved`, `trims` | looks that gave memory back, and times freed memory went back to the system (Linux) |
| `resident_holds` | looks at `yellow` by the resident size alone that did not unload partitions or drop kept results, because the last time that did not bring the level down |

Work out the processor share yourself from two readings: `(cpu_ms2 - cpu_ms1) * 100 / (uptime_ms2 - uptime_ms1)` is the percentage of one processor.

Each `running` object: `id` (the `X-KDB-Request-Id` the client sent, or `""`), `user` (`""` for the token), `client`, `database`, `sql` (the first 200 characters), `started_ms`, `elapsed_ms`, `stopping`. Cancel one with `DELETE /exec/<id>`; a statement with no id can only stop on its own timeout.

`timers`: every [timer](timers.md) of the databases the caller may read, each as in [GET /api/timers](timers.md#get-api-timers), with `failures_24h` (failed runs in about the last 24 hours).

Each `opening_databases` object says how far the open got. Opening a big database replays the log written after its last checkpoint, which over a slow disk takes minutes; the first request for it waits that long, and this list shows why and whether it is moving. Meanwhile other databases, `/api/stats` and `GET /api/databases` answer as usual.

| Field | Meaning |
|---|---|
| `name`, `elapsed_ms` | the database, and how long it has been opening |
| `phase` | what it does now: `reading manifest`, `opening table files`, `checking log`, `replaying log`, `cleaning up`, `loading tables`, `finishing` |
| `partitions_done`, `partitions_total` | partition files gone through, of those the manifest names. Most are only read when a query first needs them, so this part is quick |
| `log_bytes_replayed`, `log_bytes_total` | how much of the log has been applied again. The log is read once to check it (`checking log`), then applied (`replaying log`) |
| `transactions_replayed` | transactions applied so far |

Each `databases` object: `name`, `busy` and `memory_warning` (only when set, see below), `checkpoint` (below), `opened_ms`, `last_lsn`, `loaded_bytes` and `memory_budget_bytes` (table data in memory, against `--memory`), `pending_bytes` (changes not yet written to partition files), `cache_bytes`, `cache_budget_bytes`, `cache_entries`, `cache_hits`, `cache_misses` (`--cache-mb`), `cache_verify_checks` and `cache_verify_mismatches` (hits computed again and compared, with `KARELADB_CACHE_VERIFY=1`; see [result cache](performance-tips.md#result-cache)), `rev_values` (values of rev columns that keep their own [revision](revisions.md#rev-column), all tables), `cache_pinned` (pinned statements whose result is in the cache now, see [pinned queries](pinned-queries.md)), `memory` (below), `open_cursors`, `read_only`, `tables` - one object per table with `name`, `rows`, `partitions`, `loaded_partitions`, `loaded_bytes` and `pending_rows` - and `materialized_views`.

`/api/stats` never waits for a database. When a write or a checkpoint holds one, its object says `"busy": true`: the memory and cache numbers are live, and `tables`, the trigger queues, `last_lsn` and `pending_bytes` are from the last reading that got in. With [snapshot reads](transactions.md#snapshot-reads) on (since 2026-10-02), a long `CALL` or an open transaction no longer makes a database busy here: the `rows` of the tables it changes are counted on a snapshot, so they are the committed rows, fresh, and the open transaction is left alone. Only a checkpoint or a schema change still gives `"busy": true`. `memory_warning` is the [memory warning](cli-serve.md#memory-warning) of a database far bigger than `--memory`.

`checkpoint` - a checkpoint writing changes to partition files right now, or `null`. Over a slow disk one can take minutes; readers go on meanwhile.

| Field | Meaning |
|---|---|
| `stage` | `writing files` (one new file per changed partition), then `publishing` (switching to them all at once) |
| `table` | the table of the partition written last |
| `partitions_done`, `partitions_total` | changed partitions written, of those this checkpoint writes |
| `elapsed_ms` | how long it has been running |

Each `materialized_views` object says how far a [materialized view](views.md#materialized-view) is behind its table:

| Field | Meaning |
|---|---|
| `name`, `base` | the view and the table it reads |
| `lag_ms` | how long ago the oldest change not yet in the view was committed; `0` = up to date |
| `pending_partitions` | view partitions waiting to be rebuilt |
| `full_refresh_pending` | `true` when the whole view waits (just created, or its table was truncated or altered) |
| `refreshes`, `last_refresh_ms`, `last_refresh_took_ms` | refreshes since the database opened, when the last one ended, and how long it took |
| `last_error` | why the last refresh failed, or `""`. It is tried again after a short wait. |

`disk` - what the database takes on disk, by kind, as it last measured it. Each open database measures once a minute, when it empties its old trash, so this costs the reply nothing: `measured_ms` (when; `0` = not yet), `data_bytes`, `tail_files`, `tail_bytes`, `delta_files`, `delta_bytes` (both part of `data_bytes`), `previous_bytes`, `trash_bytes`, `trash_folders`, `wal_bytes`, `wal_archive_bytes`, `total_bytes`, `trash_purged_bytes` (the fields of [GET /api/disk](#api-disk)).

`memory` - what this database holds, by kind. The sizes are estimates of the bytes KarelaDB asked for.

| Field | Meaning |
|---|---|
| `data_bytes` | saved rows read from partition files |
| `key_map_bytes` | the lookup maps of `DEDUP KEY` and `PRIMARY KEY` for loaded partitions |
| `view_bytes` | column copies of changed rows that fast scans read; freed at the checkpoint |
| `pending_bytes` | changes not yet written to partition files (at most a quarter of `--memory`, and of `--memory-limit`, before a checkpoint writes them) |
| `cache_bytes` | results in the result cache |
| `index_bytes` | `CREATE INDEX` indexes; **not** limited by `--memory` (`--memory-limit` counts them) |
| `budget_used_bytes` | data + key maps + views of **all** open databases: this is what `--memory` limits |
| `cache_used_bytes` | the result caches of all open databases: what `--cache-mb` limits |
| `partition_loads`, `key_map_builds` | since the database opened: partition files read into memory, and key maps built. When they go up with every request, the budget is too small for the work. |
| `partial_loads` | of `partition_loads`: reads of only the columns a query names ([per-column loads](databases.md#per-column-loads)) |
| `trigger_queues` | one object per deferred trigger, as in [GET /api/trigger-queue](#api-trigger-queue) |
| `trigger_job_file_bytes` | the size of the file that holds the deferred trigger jobs not finished yet |
| `share_bytes` | this database's part of `budget_used_bytes` |
| `floor_bytes` | while the database is writing, the part of the budget other databases cannot take from it; `0` when it is not writing or is the only open database |
| `writing` | `true` when it changed rows in the last 30 seconds |
| `evicted_by_other_databases`, `evicted_by_other_databases_bytes` | since it opened: partitions it unloaded to make room for another database, and their size |

- `resident_bytes` of the process is about `budget_used_bytes` + `cache_used_bytes` + the `pending_bytes` and `index_bytes` of every database + the memory of the statements running now + about 30 MB for the program. See [memory](performance-tips.md#memory).

- **Needs:** `read`. A user sees only the databases they may read, and only **their own** statements in `running`, because statement text can hold values; an admin sees everyone's.
- **Status codes:** 200; 401 without a login.

```bash
curl -s -H "Authorization: Bearer $KARELADB_TOKEN" http://127.0.0.1:9900/api/stats
```

<a id="metrics"></a>

## GET /metrics

Syntax:

```sql
GET /metrics
```

The server's counters in the Prometheus text format, for Prometheus, Grafana Agent or any scraper. Every number is a counter the server keeps as it works, so a scrape never waits for a database lock and never slows a query.

| Metric | Kind | Meaning |
|---|---|---|
| `kdb_http_requests_total{code}` | counter | HTTP requests answered, by status class (`2xx`, `4xx`, `5xx` ...) |
| `kdb_http_unsent_total` | counter | answers that could not be sent: the client stopped reading for the whole send timeout (30 s), or left |
| `kdb_http_read_timeouts_total` | counter | requests that started to arrive but did not finish within 30 s (answered 408) |
| `kdb_http_request_duration_seconds` | histogram | time of each HTTP request, 1 ms to 10 s buckets |
| `kdb_statement_duration_seconds{protocol}` | histogram | time of each statement, `http` or `pg` |
| `kdb_statement_errors_total{protocol}` | counter | statements that failed or were stopped |
| `kdb_statements_running` | gauge | statements running now |
| `kdb_slow_statements_total`, `kdb_slow_query_threshold_seconds` | counter, gauge | statements over the slow-query threshold, and the threshold |
| `kdb_gate_waits_total{mode}`, `kdb_gate_wait_seconds_total{mode}` | counter | requests that had to wait for a database lock, and for how long, by `read`, `write`, `alone`, `checkpoint` |
| `kdb_result_cache_hits_total`, `kdb_result_cache_misses_total` | counter | the result cache |
| `kdb_column_engine_queries_total` | counter | queries the column engine ran |
| `kdb_partition_loads_total` | counter | partitions read from disk into memory |
| `kdb_checkpoints_total`, `kdb_checkpoint_written_bytes_total` | counter | checkpoints that wrote data files, and the bytes they wrote |
| `kdb_wal_written_bytes_total` | counter | bytes written to the log |
| `kdb_io_retries_total` | counter | file reads, writes and syncs tried again because the system was short of memory for a moment ([out of memory](backup-and-safety.md#out-of-memory)) |
| `kdb_memory_bytes{kind}` | gauge | memory by kind: `table_data`, `key_maps`, `views`, `pending`, `indexes`, `result_cache`, `other`, `allocator` |
| `kdb_memory_limit_bytes`, `kdb_memory_level` | gauge | `--memory-limit`, and its level (0 green, 1 yellow, 2 red) |
| `kdb_up`, `kdb_ready` | | health for alerts: `kdb_up` is `1` whenever the server answers (alert on its absence, as on PostgreSQL's `pg_up`); `kdb_ready` is `0` while start-up (the default database's log replay) still runs |
| `kdb_process_resident_bytes`, `kdb_process_cpu_seconds_total`, `kdb_process_threads`, `kdb_process_open_files`, `kdb_uptime_seconds` | | the process |
| `kdb_database_disk_bytes{database,kind}` | gauge | disk use by kind: `data`, `previous_versions`, `trash`, `wal`, `wal_archive` (measured once a minute) |
| `kdb_database_tail_bytes{database}` | gauge | [tail files](partitions-and-dedup.md#tail-files), part of the `data` kind above |
| `kdb_database_delta_bytes{database}` | gauge | [delta files](partitions-and-dedup.md#delta-files), part of the `data` kind above |
| `kdb_database_trash_purged_bytes_total{database}` | counter | trash the database removed by itself |
| `kdb_trigger_jobs_waiting{database}`, `kdb_trigger_job_failures_total{database}` | gauge, counter | deferred trigger jobs waiting, and failed runs |
| `kdb_timer_runs_total`, `kdb_timer_failures_total`, `kdb_timer_late_seconds_total`, `kdb_timer_late_seconds_max` | counter, gauge | timer runs, failed runs, and how late they started |

- **Needs:** `read`. A user sees the per-database lines of the databases they may read. Send the token as for any route: `Authorization: Bearer <token>`.
- **Notes:** counters start at 0 when the server starts. Only **open** databases have per-database lines.
- **Grafana:** a ready server dashboard, the scrape setup and `kdb_snapshot_reads_total{database}` (snapshot reads per open database): [Grafana and Prometheus](grafana.md#prometheus).

```bash
curl -s -H "Authorization: Bearer $KARELADB_TOKEN" http://127.0.0.1:9900/metrics
```

A Prometheus scrape job:

```yaml
scrape_configs:
  - job_name: kareladb
    authorization: { credentials: "<the token>" }
    static_configs: [{ targets: ["127.0.0.1:9900"] }]
```

<a id="slow-queries"></a>

## GET /api/slow-queries

Syntax:

```sql
GET /api/slow-queries[?limit=100][&db=<name>]
```

Statements that took at least the slow-query threshold, newest first. They are kept on disk in `<data folder>/_logs/slow_queries.jsonl` (one JSON object per line), so they survive a restart. At 16 MB the file becomes `slow_queries.1.jsonl` and a new one starts; the one before that is removed. The [Monitor](console-monitor.md) shows the newest 20.

| Setting | Where | Default |
|---|---|---|
| the threshold in milliseconds, `0` = off | `kareladb serve --slow-query-ms N`, then `slow_query_ms` in `kareladb.conf`, then `KARELADB_SLOW_QUERY_MS` | 1000 |

| Answer field | Meaning |
|---|---|
| `threshold_ms` | the threshold in use |
| `recorded` | slow statements written since the server started |
| `queries` | one object each: `ms` (when it ended), `took_ms`, `user`, `client`, `database`, `rows`, `ok`, `error`, `sql` |

- **Needs:** `read`. A user who is not an admin sees only their own statements.
- **Notes:** the statement text is masked like the activity log's (a password or token literal becomes `'***'`) and cut to 4,000 characters. Statements over HTTP and the PostgreSQL port both count.

```bash
curl -s -H "Authorization: Bearer $KARELADB_TOKEN" "http://127.0.0.1:9900/api/slow-queries?limit=10"
```

<a id="api-settings"></a>

## GET /api/settings

Syntax:

```sql
GET /api/settings
```

Where the server keeps its data, and whether that can be changed from here. The [Settings page](console-settings.md) of the console shows it.

| Answer field | Meaning |
|---|---|
| `data_dir` | the data folder in use |
| `data_dir_source` | where that came from: `--data-dir`, `kareladb.conf`, `KARELADB_DATA_DIR` or `program folder` |
| `saved_data_dir` | what `kareladb.conf` holds, which may differ from `data_dir` |
| `config_path` | the settings file (`--config`, else `kareladb.conf` next to the program); `""` = settings cannot be saved |
| `config_error` | why the settings file could not be read, if it could not |
| `command_line` | the command line the server was started with |
| `wal_archive_mb`, `wal_archive_mb_source` | old log each database keeps for repairs, in MB, and where that came from: `kareladb.conf`, `KARELADB_WAL_ARCHIVE_MB` or `default` |
| `backups` | the [backup settings](backup-schedule.md#backup-settings) in use since the start: `dir`, `schedule`, `keep_daily`, `keep_weekly`, `command`, each with a `..._source` (`--backups`, `kareladb.conf`, `KARELADB_BACKUP_DIR`, `default`, ...), and what `kareladb.conf` holds now: `saved_dir`, `saved_schedule`, `saved_keep_daily`, `saved_keep_weekly` (`""` / `-1` = not set) |
| `web_dir`, `help_dir`, `skill_dir` | the folders the console, the help and the Claude skill are read from (`""` = not found) |
| `web_dir_source`, `help_dir_source`, `skill_dir_source` | what chose each folder: `kareladb.conf`, `KARELADB_WEB_DIR` (and so on), `program folder`, `share folder`, `source checkout` or `not found` ([folders](install-packages.md#folders)) |
| `can_save` | `true` when the settings file can be written |
| `cannot_save_reason` | why not, when `can_save` is `false` |
| `can_restart` | `true` when `POST /api/restart` works on this server |
| `flag_overrides_config` | `true` when `--data-dir` was given, so a saved folder will not be used |
| `default_database`, `has_root`, `read_only_server` | the default database's name, whether there is a data folder, whether the server is read-only |
| `free_bytes` | room left on that disk |
| `databases`, `data_bytes` | how many databases there are and how much they use |

- **Needs:** the user's own `ROLE` `admin`.
- **Status codes:** 200; 401 without a login; 403 for any weaker role.

<a id="post-api-settings"></a>

## POST /api/settings

Syntax:

```sql
POST /api/settings
body: {"data_dir": "E:/kdb-data"}   (or data_dir=<folder> as a query or form field)
body: {"wal_archive_mb": 100}       (or both in one body)
body: {"backup_schedule": "daily 02:00", "backup_keep_daily": 14, "backup_keep_weekly": 8, "backup_dir": "E:/kdb_backups"}
```

Checks a folder and writes it to the settings file. A new folder takes effect at the **next start**, not at once, and nothing is moved: the databases in the old folder stay where they are. `wal_archive_mb` (0 = keep no old log) takes effect at once, for every database without its own `ALTER DATABASE ... SET WAL_ARCHIVE`. The backup settings take effect at the next start (`backup_dir`: a folder, `off`, or `default` for `_backups` in the data folder). `backup_command` is refused with 403: it runs a program on the server, so it is set in `kareladb.conf` by hand, with `--backup-command` or `KARELADB_BACKUP_COMMAND`.

Before writing anything the server makes the folder if it is missing, writes and removes a probe file in it, and refuses a folder that is itself one database (it holds a `_manifest.a`) - the data folder is the one **above** those. A folder that fails any of these is a 400 with the reason, and the settings file is not touched.

| Answer field | Meaning |
|---|---|
| `saved` | always `true` |
| `data_dir` | the folder as KarelaDB spells it (`/` separators, no trailing separator) |
| `wal_archive_mb` | the old log kept per database now, in MB |
| `config_path` | the file it was written to |
| `restart_required` | `true` when this is not the folder in use now, or a backup setting changed |
| `flag_overrides_config` | `true` when `--data-dir` will keep winning, so the restart will change nothing |

- **Needs:** the user's own `ROLE` `admin`.
- **Status codes:** 200; 400 nothing to save, a folder that cannot be used, a `wal_archive_mb` that is not a whole number, or a bad backup schedule or count; 401; 403 (also for `backup_command`); 409 when the server has no settings file; 500 the file cannot be written.

<a id="api-restart"></a>

## POST /api/restart

Syntax:

```sql
POST /api/restart
```

Closes every database cleanly, then starts the server again **in the same process**, on the same port. No service manager, Docker restart policy or supervisor is needed.

The reply is sent before the server stops listening, so the caller always gets an answer. Statements that are running are stopped and open transactions rolled back, as at a normal shutdown. The server prints `restarting...`, then `databases closed cleanly`, then its usual banner; the restart is written to the [audit log](audit-log.md).

A folder saved in `kareladb.conf` that cannot be used when the server comes back does **not** stop it: the server prints a warning and starts on the usual folder instead.

| Answer field | Meaning |
|---|---|
| `restarting` | always `true` |
| `message` | what it is about to do |

- **Needs:** the user's own `ROLE` `admin`.
- **Status codes:** 200; 401; 403; 409 when this server cannot restart itself (one database served by its path).
