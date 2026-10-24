# Backup, check, repair and restore

> How KarelaDB keeps your data safe, how to make and test backups, and how to get the data back after damage or a mistake.

- Category: Backup, check, repair, restore
- Keywords: backup, backups, CHECKPOINT, checkpoint now, settle after a load, restore, point-in-time restore, PITR, point-in-time window, restore drill, monthly restore, test restore, restore while running, online restore, /api/restore, swap database, /api/databases/swap, wal\_archive\_mb, undo, bad import, UPDATE without WHERE, verify, verified backup, hard links, retention, keep daily, keep weekly, prune, daily backup, Task Scheduler, cron, damage, disk failure, safety, --hard-links, --keep-daily, --keep-weekly, --logs-from, --until, backup.kdb, /api/backup, /api/check, Backup now, Check now, disk full, 507, 53100, no space, out of memory, ENOMEM, Cannot allocate memory, 53200, try again, compressed log, compressed\_log, log compression, WAL compression, KARELADB\_WAL\_COMPRESS, packed log records, kdb\_wal\_packed\_input\_bytes\_total
- See also: [kareladb info, check, repair, dump-file](cli-maintenance.md), [How KarelaDB stores data](data-formats.md), [kareladb serve](cli-serve.md), [Transactions](transactions.md), [Health, info, check and backup over HTTP](http-server-info.md)

KarelaDB is built so that a crash, a power cut or a bad disk block never gives you wrong data without telling you.
But only **backups on another disk** protect you from a dead disk or a big mistake (a wrong `UPDATE`, a bad import).
This page shows how to make backups, check them, and restore from them.

Most commands here need the database **closed** (no `kareladb serve`, no `kareladb shell` on it). With a running server, use `BACKUP DATABASE`, the console's **Backup now**, `POST /api/backup` and `POST /api/check`, and [restore while the server runs](#restore-online).

<a id="protection"></a>

## How KarelaDB protects your data

| Danger | What KarelaDB does |
|---|---|
| Power cut or crash while writing | Every change goes into the **log** (WAL, write-ahead log) first. The log is on the disk before KarelaDB says "done". At the next start KarelaDB replays the log. |
| A file only half written | Data files are **never changed**. KarelaDB writes a new version, checks it, and then switches to it. |
| A bad bit on the disk | Every block of every file has a **checksum** (CRC32C, a short number made from the bytes). KarelaDB notices one wrong bit and names the file and block. |
| A damaged data file | The **repair ladder**: the previous version of the file plus the log, then a copy from a backup plus the log. See [kareladb repair](cli-maintenance.md#kareladb-repair). |
| A damaged list of files | The list (the **manifest**) is saved **twice**. One good copy is always left. |
| A mistake (wrong UPDATE, bad import) | **Point-in-time restore**: a backup plus the log, up to the second before the mistake. See [restore while running](#restore-online) and [kareladb restore](#kareladb-restore). |
| The whole disk dies | Only backups on another disk help. |
| The disk is full | KarelaDB stops accepting writes when less than 64 MB is free, so nothing is left half written. See [when the disk is full](#disk-full). |

More details: [data formats](data-formats.md) and [chapter 9](../tutorial/09-backup-and-safety.md).

<a id="compressed-log"></a>

## The log is compressed

A commit has to wait until its log records are on the disk. For a big commit (a whole-history rewrite of one symbol: `DELETE` 240,000 rows and `INSERT ... SELECT` them again) that is tens of MB, and the wait for the disk was most of the commit's time. Since 2026-10-02 KarelaDB packs such records before it writes them.

| What | How |
|---|---|
| which commits | those whose log records hold **64 KB or more**; smaller commits are written exactly as before, so they cost nothing extra |
| how much smaller | about **a third** of the bytes for candle rows and deletes (measured: 44 MB of log became 14 MB) |
| how fast | packing runs on up to 8 threads (at most half the CPUs); measured on that rewrite, its `COMMIT` took 41 ms instead of 89 ms |
| never bigger | a group of records that does not get smaller (random bytes) is written as before |
| safe | every record inside is checked again (its checksum) when it is read; a torn end after a power cut is found as before |
| encrypted databases | the records are packed first, then [encrypted](encryption.md) |
| everything that reads the log | recovery, `kareladb check`, backups and restore, [standby copies](standby.md), [change streams](change-stream.md) and `AS OF` read packed records like any others |
| watch it | `/metrics`: `kdb_wal_packed_input_bytes_total` (what the records would have taken) and `kdb_wal_packed_output_bytes_total` (what was written) |
| turn it off | `KARELADB_WAL_COMPRESS=off` in the environment of `kareladb serve` (or any `kareladb` command) |

Packed records are a stored-format feature (`compressed_log`, see [versions](versions.md)): a build from before 2026-10-02 refuses them as "needs a newer KDB" (its name then), never as damage. [kareladb downgrade](versions.md#downgrade) to such a KarelaDB turns packing off by itself while it works, so it leaves no packed record that the older KarelaDB would have to read.

<a id="disk-full"></a>

## When the disk is full

Syntax:

```sql
HTTP:        507 Insufficient Storage   (/exec: {"error": ...}; POST /write: {"code": "disk full", "message": ..., ...})
PostgreSQL:  SQLSTATE 53100 (disk_full)
```

KarelaDB looks at the free space of the data disk before it writes, at most once a second. Below **64 MB** free it refuses the write with `only N MB free on disk; KarelaDB pauses writes below 64 MB so nothing is half-written`. A write the disk itself refuses (it filled up in between) gets the same HTTP code and SQLSTATE, with the system's message.

| What | What happens |
|---|---|
| the refused write | nothing of it is saved; the whole request or transaction is rolled back |
| reads | go on as usual |
| the database | is not damaged and needs no repair |
| later writes | work again as soon as there is room; no restart is needed |

- Free room: delete old backups on that disk, empty the [trash](trash.md), drop old partitions, or move the data folder to a bigger disk (the [Settings page](console-settings.md)).
- A loader should treat 507 like 503: wait, then send the same request again. It was not applied.
- One exception: when the disk fills while the log is being flushed, the 507 message says `The rows of this write are applied in memory and reach the log once disk space is freed`. Those rows are already there (reads show them) and are saved once space is back. For a table with a key, sending them again is harmless; for a table without one, do not send them again.

<a id="out-of-memory"></a>

## When the system is short of memory

Syntax:

```sql
HTTP:        503 Service Unavailable, Retry-After: 1   (not applied: send it again)
HTTP:        500, no Retry-After   ("... The rows of this write are applied in memory ...": do not send it again)
PostgreSQL:  SQLSTATE 53200 (out_of_memory)
```

Sometimes the operating system refuses a write to a file for a moment: `Cannot allocate memory` (ENOMEM). A Docker VM whose memory is full of file cache does this. It is not a broken disk, and since 2026-10-02 KarelaDB treats it so:

| What | What happens |
|---|---|
| a read, write or truncate of a file | tried again after a short pause, for about 2 s, before it counts as failed |
| a write to the log | undone and tried again, for about 3 s more |
| a write that still fails | gets 503 with `Retry-After` (it was not applied: send it again in a moment); the database does **not** stop and needs no reopen |
| reads, `/health` | go on as usual |
| later writes | work again by themselves when memory is back |

- One exception, as with a full disk: when the shortage hits the shared flush of the log, the rows are already in the table. That answer is **500 without `Retry-After`**, and its message says `The rows of this write are applied in memory`. Reads show those rows, and KarelaDB writes them to the log as soon as it can. Do not send them again to a table without a key: it would hold them twice.
- `kdb_io_retries_total` in [/metrics](http-server-info.md#metrics) counts the calls that were tried again.

## BACKUP DATABASE

Syntax:

```sql
BACKUP DATABASE
```

Makes a backup of the current database **while it stays open**, then reads the whole backup again to check it.
It works in `kareladb serve` (console, `POST /exec`), in `kareladb shell` and in `kareladb sql`, when there is a backup folder. `kareladb serve` always has one unless it is started with `--backups off` (`_backups` in the data folder, `_backups/<folder name>` next to a folder served by its path, or `--backups <dir>`; see [where the settings come from](backup-schedule.md#backup-settings)). `kareladb shell` and `kareladb sql` need `--backups <dir>`.

| Result column | Meaning |
|---|---|
| `backup` | The new backup folder. Its name is the **UTC** time: `20260911-081906-660`. |
| `files` | Data files in the backup |
| `bytes` | Size of the backup |
| `log_lsn` | The backup holds every change up to this log position |

- **Deletes old backups:** after a good backup it keeps the newest backup of each of the last 7 days and of the last 4 weeks, and deletes the rest of that folder.
- In a server with a data folder, a database backs up into `<dir>/<database name>`.
- Needs the `admin` role when the server has users.
- Without a backup folder (`kareladb sql` without `--backups`, or a server started with `--backups off`): `no backup folder is set`.
- A server with a [copy command](backup-schedule.md#backup-command) copies each new backup off the server.

**Command line: In kareladb shell, started with a backup folder** (sample data: sample)

```bash
kareladb shell market --backups backups
> BACKUP DATABASE;
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> backup                      | files | bytes  | log_lsn
----------------------------+-------+--------+--------
backups/20261024-063935-086 |     9 | 194519 |      30
(1 row, 20.8 ms)
backup created and verified
kareladb>
```

**Example: No backup folder was given** (sample data: sample; shows an error)

```sql
BACKUP DATABASE;
```

Result:

Error: `no backup folder is set; start KarelaDB with a backup folder (for example --backups D:/kdb_backups)`

## CHECK TABLE

Syntax:

```sql
CHECK TABLE <table>
```

Reads every block of every data file and every log record, and checks the checksums. It changes nothing.

- **Result:** a column `problem` with one row per problem (no rows when all is well), and the message `OK: no damage found in N files` or `N problem(s) found`.
- **It always checks the whole database**, whatever table you name. The name is not even checked.
- The same as `.check` in `kareladb shell`, **Check now** in the console, `POST /api/check`, and [kareladb check](cli-maintenance.md#kareladb-check) for a closed database.
- Needs the `admin` role when the server has users.

**Example: Check the database** (sample data: sample)

```sql
CHECK TABLE ochl_day;
```

Result:

| problem (STRING) |
|---|

(0 rows)

```text
OK: no damage found in 14 files
```

<a id="checkpoint"></a>

## CHECKPOINT

Syntax:

```sql
CHECKPOINT
```

Writes every change of the current database that waits in memory (and in the log) to its data files, and answers only when that is done. It is PostgreSQL's `CHECKPOINT`. A benchmark or a loader sends it after a bulk load, so that what comes next does not run beside the background writing of that load.

| What | How |
|---|---|
| a checkpoint already running | it waits for that one to end first, then writes what is still waiting |
| nothing waiting | answers at once: `nothing to write: every change is in the files already` (no file is written) |
| readers | go on while the files are written; writers wait until it is done |
| the answer | no rows; the message `checkpoint done: every change is in the files`. Over the PostgreSQL port the command tag is `CHECKPOINT` |
| where | HTTP `POST /exec`, the PostgreSQL port, the console, `kareladb shell` |
| rights | the `ddl` role (or `admin`) when the server has users, as for `COMPRESS TABLE` |

- Send it **alone**: `CHECKPOINT; SELECT 1` is refused with `CHECKPOINT runs alone`.
- Not inside a transaction block: after `BEGIN` it is refused (SQLSTATE `25001`); `COMMIT` or `ROLLBACK` first.
- Your changes are safe without it: every commit is in the log on the disk before KarelaDB answers. `CHECKPOINT` only moves the work of writing the data files to a moment you choose. See [data formats](data-formats.md) for when KarelaDB checkpoints by itself.
- On a read-only database there is nothing to write, and it answers at once.

**Example: Write out what a load left waiting** (sample data: sample)

```sql
CHECKPOINT;
```

Result:

```text
checkpoint done: every change is in the files
```

## kareladb backup

Syntax:

```sql
kareladb backup <db> <backups-dir> [--hard-links] [--keep-daily N] [--keep-weekly N] [--data-dir <folder>]
```

Makes a backup of a **closed** database into a new folder inside `<backups-dir>`, then reads the whole backup again. Only then it prints `backup created and verified`.

| Option | Meaning | Default |
|---|---|---|
| `<db>` | A database name in the data folder, or a folder path | required |
| `<backups-dir>` | The folder for backups. It is created when missing. For a database **name**, the backup goes to `<backups-dir>/<name>`. | required |
| `--hard-links` | Hard links instead of copies for the data files: very fast, no extra space, but **no protection** from disk damage (see below). The log files are always copied. | copies |
| `--keep-daily N` | After the backup, keep the newest backup of each of the last `N` days | 7 (when only `--keep-weekly` is given) |
| `--keep-weekly N` | After the backup, keep the newest backup of each of the last `N` weeks (weeks start on Sunday, UTC) | 4 (when only `--keep-daily` is given) |

- **Exit code:** `0` = the backup is made and verified. `1` = error (for example `the database is open in another program`). `2` = damage (the backup failed its check).
- **Without `--keep-daily` and `--keep-weekly` nothing is deleted.** With one of them, backups that no rule keeps are deleted, and each one prints `removed old backup ...`. The newest backup is always kept. Days count only days that have a backup.
- **Backup folder names are UTC time**: `20260911-081906-660` = 2026-09-11 08:19:06.660 UTC = 14:04 in Nepal (+05:45).
- Inside: `backup.kdb` (the list, written last), `files/` (the data files) and `wal/` (the log needed). A folder whose name ends in `.partial` is an unfinished backup; it is never used.
- **Put the backups on another disk** (`E:\kdb_backups`). One broken disk must not destroy both.
- **Hard links** share the same disk sectors as the database. If the disk goes bad, both are lost. Use them only as an extra undo point before a big import, never as the only backup.
- A running server has the database open, so `kareladb backup` fails with `the database is open in another program. Stop it first, or run BACKUP DATABASE in that server's console or API.`
- **Watch the path:** `kareladb backup` on a folder that does not exist makes a new empty database there and backs it up (`0 files`) with exit code `0`. Check the output of a scheduled backup.

**Command line: A daily backup that keeps 7 daily and 4 weekly backups** (sample data: sample)

```bash
kareladb backup market backups --keep-daily 7 --keep-weekly 4
kareladb backups backups
```

Output:

`> kareladb backup market backups --keep-daily 7 --keep-weekly 4`

```text
backup created and verified: backups/20261024-063935-214
  9 files, 190.0 KB, log up to 30
```

`> kareladb backups backups`

```text
BACKUP                 CREATED               FILES       SIZE      LOG LSN
20261024-063935-214    2026-10-24 12:24:35       9   190.0 KB           30
1 backups
```

**Command line: Three backups, but keep only the newest of today** (sample data: sample)

```bash
kareladb backup market backups
kareladb backup market backups
kareladb backup market backups --keep-daily 1 --keep-weekly 1
kareladb backups backups
```

Output:

`> kareladb backup market backups`

```text
backup created and verified: backups/20261024-063935-230
  9 files, 190.0 KB, log up to 30
```

`> kareladb backup market backups`

```text
backup created and verified: backups/20261024-063935-280
  9 files, 190.0 KB, log up to 30
```

`> kareladb backup market backups --keep-daily 1 --keep-weekly 1`

```text
backup created and verified: backups/20261024-063935-327
  9 files, 190.0 KB, log up to 30
removed old backup backups/20261024-063935-280
removed old backup backups/20261024-063935-230
```

`> kareladb backups backups`

```text
BACKUP                 CREATED               FILES       SIZE      LOG LSN
20261024-063935-327    2026-10-24 12:24:35       9   190.0 KB           30
1 backups
```

**Command line: Hard links: a fast undo point before a big import** (sample data: sample)

```bash
kareladb backup market before-import --hard-links
```

Output:

```text
backup created and verified: before-import/20261024-063935-243
  9 files, 190.0 KB, log up to 30
```

**Command line: A database name in the data folder backs up into a sub-folder**

```bash
kareladb shell
> CREATE DATABASE reports;
> USE reports;
> CREATE TABLE daily (day DATE PRIMARY KEY, trades LONG);
kareladb backup reports backups
kareladb backups backups/reports
```

Output:

`> kareladb shell`

```text
KarelaDB 0.2.0-dev shell on default (data folder ./kdb-data)
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> database 'reports' created
kareladb> using database 'reports'
kareladb> table 'daily' created
kareladb>
```

`> kareladb backup reports backups`

```text
backup created and verified: backups/reports/20261024-063935-302
  1 files, 427 B, log up to 2
```

`> kareladb backups backups/reports`

```text
BACKUP                 CREATED               FILES       SIZE      LOG LSN
20261024-063935-302    2026-10-24 12:24:35       1      427 B            2
1 backups
```

## kareladb backups

Syntax:

```sql
kareladb backups <backups-dir>
```

Lists the finished backups in a folder, **newest first**.

| Column | Meaning |
|---|---|
| `BACKUP` | Folder name (UTC time) |
| `CREATED` | When it was made, in the **local time** of this computer |
| `FILES`, `SIZE` | Data files and total size (data and log) |
| `LOG LSN` | The backup holds every change up to this log position |

- **Exit code:** `0`; `1` when the folder does not exist.
- Unfinished (`.partial`) and unreadable folders are not listed. It does **not** check the backups: use [kareladb verify-backup](#kareladb-verify-backup).
- For a database name in the data folder, list `<backups-dir>/<name>`.

**Command line** (sample data: sample)

```bash
kareladb backup market backups
kareladb backups backups
```

Output:

`> kareladb backup market backups`

```text
backup created and verified: backups/20261024-063935-301
  9 files, 190.0 KB, log up to 30
```

`> kareladb backups backups`

```text
BACKUP                 CREATED               FILES       SIZE      LOG LSN
20261024-063935-301    2026-10-24 12:24:35       9   190.0 KB           30
1 backups
```

**Command line: A folder that does not exist** (sample data: sample)

```bash
kareladb backups no-such-folder
```

Output:

```text
error: Not found: list 'no-such-folder': Windows error 3
```

exit code 1

## kareladb verify-backup

Syntax:

```sql
kareladb verify-backup <backup-dir>
```

Reads **one** whole backup again: every data file and block against its checksum, every log file, and that the log reaches the end the backup promises.

- **Exit code:** `0` = `OK: backup is intact`. `2` = problems, one `PROBLEM:` line each. A folder that is not a backup also gives `2`.
- `<backup-dir>` is one backup folder, like `E:\kdb_backups\20260911-081906-660`, not the folder of all backups.
- A backup you never tested is not a backup. Verify old backups now and then, and do a test restore once a month.

The help build cannot know the name of a new backup folder, so this is real output from [chapter 9](../tutorial/09-backup-and-safety.md):

```powershell
$newest = Get-ChildItem backups -Directory | Sort-Object Name | Select-Object -Last 1
kareladb verify-backup "backups\$($newest.Name)"
"exit code: $LASTEXITCODE"
```

```text
OK: backup is intact
exit code: 0
```

**Command line: The folder of all backups is not one backup** (sample data: sample)

```bash
kareladb backup market backups
kareladb verify-backup backups
```

Output:

`> kareladb backup market backups`

```text
backup created and verified: backups/20261024-063935-354
  9 files, 190.0 KB, log up to 30
```

`> kareladb verify-backup backups`

```text
PROBLEM: backup.kdb: open 'backups/backup.kdb': Windows error 2
error: Corruption: backup.kdb: open 'backups/backup.kdb': Windows error 2
```

exit code 2

## kareladb restore

Syntax:

```sql
kareladb restore <backup-dir> <new-folder> [--logs-from <old-db-folder>] [--until "YYYY-MM-DD HH:MM[:SS]"]
```

Makes a **new** database folder from a backup. The old database is not touched.

| Option | Meaning | Default |
|---|---|---|
| `<backup-dir>` | One backup folder (`backups\20260911-081906-660`) | required |
| `<new-folder>` | The new database folder. It must not exist, or be empty. | required |
| `--logs-from <old-db-folder>` | Also take the **newer log** from the old database, so changes made **after** the backup come back too | only the backup |
| `--until "YYYY-MM-DD HH:MM[:SS]"` | Replay the log only up to this time, in the **local time** of this computer. Changes made in that second are included. | the end of the log |

- **Exit code:** `0` = restored. `1` = error (the target is not empty, a wrong `--until`). `2` = the backup is damaged (`pick another one`). A wrong backup path gives the same message and `2`.
- **First it verifies the backup.** Every copied file is checked again.
- `--until` earlier than the backup itself is refused: `this backup already contains changes made after the requested time; pick an older backup`.
- `--logs-from` only uses a log of the **same** database and history; another database's log is ignored with a note.
- The log is replayed the first time the new database is opened. Run `kareladb check <new-folder>` before you use it.
- A restored database has no older file versions yet; they appear again as data changes.
- `<new-folder>` is a folder path. To use it as a database in the data folder, restore into `<data folder>\<name>`.

**A story: an UPDATE without WHERE.** At about 14:05 someone ran `UPDATE ochl_day SET close = 0`. The newest backup was from 14:04. Restore the backup, add the newer log from the old database, and stop one second before the mistake. Real commands and output from [chapter 9](../tutorial/09-backup-and-safety.md) (the help build cannot run this, because it cannot know the backup's folder name):

```powershell
$backup = Get-ChildItem backups -Directory | Sort-Object Name | Select-Object -Last 1
kareladb restore "backups\$($backup.Name)" market-restored --logs-from market --until "2026-09-11 14:05:10"
kareladb sql market-restored "SELECT time, symbol, close FROM ochl_day WHERE time >= '2026-09-10' ORDER BY symbol, time"
```

```text
stopped at the requested time: changes after LSN 36 are not restored
restored 9 data files from backups\20260911-142715-556 plus 1 newer log segments; the log (up to LSN 36) is replayed on first open
restored into market-restored
time                     | symbol | close
-------------------------+--------+------
2026-09-10T00:00:00.000Z | CITY  | 504.9
2026-09-13T00:00:00.000Z | CITY  | 508.2
2026-09-14T00:00:00.000Z | CITY  |   511
2026-09-10T00:00:00.000Z | COAST   | 376.1
2026-09-10T00:00:00.000Z | VOLT  | 191.2
(5 rows, 0.2 ms)
```

The prices are back. The row of 2026-09-14 was added **after** the backup but **before** the mistake, and it is there too.

Then switch over: stop the server, rename `market` to `market-broken` and `market-restored` to `market`, start the server. Keep `market-broken` until you are sure. With a running server, [restore while running](#restore-online) does all of this without a stop.

A target folder that is not empty (real output from chapter 9):

```text
error: Already exists: restore target is not empty: market-restored
```

**Command line: --until must be a local time like 2026-09-11 14:30** (sample data: sample)

```bash
kareladb restore backups/20260911-081906-660 market-restored --until "11.09.2026 14:30"
```

Output:

```text
error: --until must look like "2026-09-11 14:30" or "2026-09-11 14:30:15"
```

exit code 1

**Command line: Not a backup folder** (sample data: sample)

```bash
kareladb restore no-such-backup market-restored
```

Output:

```text
error: Corruption: the backup is damaged; pick another one
  backup.kdb: open 'no-such-backup/backup.kdb': Windows error 3
```

exit code 2

<a id="restore-online"></a>

## Restore while the server runs

Syntax:

```sql
POST /api/restore            {"database": "market", "as": "market_check", "until": "2026-09-24 14:05:09"}
POST /api/databases/swap     {"database": "market", "with": "market_check"}
```

The same as `kareladb restore`, without stopping anything:

1. **Restore** a backup of `market` into a **new** database `market_check`. `market` keeps running and is not touched.
2. **Check** `market_check`: run a few queries, `CHECK TABLE`.
3. **Swap**: `market` gets the restored data, `market_check` the data `market` had. Users, rights and settings (read-only, dialect, old log, timers, pins) stay with the name `market`.
4. Drop `market_check` when you are sure.

| `until` | What comes back |
|---|---|
| not given | the backup as it was |
| a time (`2026-09-24 14:05:09`, UTC unless it ends in `Z` or `+05:45`), or `until_ms` | the backup, then `market`'s own log up to that time: **point in time** |
| `latest` | the backup, then all of `market`'s log: a copy as of now |

- The newest backup made before `until` is used, or name one with `"backup": "20260924-120000-000"`.
- In the console: **Health** > **Restore a backup**, then **Swap in**.
- The swap needs both databases unused: an open PostgreSQL connection or session on either gives `in use`; close it and try again.
- Details: [POST /api/restore](http-server-info.md#api-restore) and [POST /api/databases/swap](http-server-info.md#api-swap).

<a id="pitr-window"></a>

### How far back a point in time can go

A restore to a time starts from a backup made **before** it and replays the database's log from there. The log older than the data files is kept in `wal_archive`, up to its size limit (`wal_archive_mb`, 1 GB per database by default; [Settings](console-settings.md#wal-archive)). When the oldest kept log starts after a backup ended, that backup can only be restored as it was.

`GET /api/backups` says how far back you can go now:

Syntax:

```sql
"point_in_time": {"possible": true, "from": "2026-09-23T10:00:00.000Z", "from_backup": "20260923-100000-000", ...}
```

- `from` is the earliest time you can restore to; anything from there to now works.
- `possible: false` with `why`: the kept log does not reach the newest backup. Make a backup now, and raise `wal_archive_mb` or back up more often.
- Rule of thumb: `wal_archive_mb` must hold the log written between **two** backups. A database that writes 300 MB of log a day and backs up daily needs at least 300 MB; 100 MB gives a point in time only for the last few hours.

<a id="restore-drill"></a>

## A monthly restore drill

A backup you never restored is a hope, not a backup. Once a month, with the server running:

| Step | How | Pass when |
|---|---|---|
| 1. restore the newest backup into a new name | `POST /api/restore {"database":"market","as":"drill_2026_09"}` (or **Health** > **Restore a backup**) | `"opened": true` |
| 2. check it | `POST /api/check?db=drill_2026_09` | `"ok": true` |
| 3. compare | `SELECT count(*)` of the main tables in both, and the newest row time | the counts match the backup's time |
| 4. a point in time | the same with `"until"` an hour ago | it opens, rows up to that hour |
| 5. the copy off the server | copy one backup back from the remote (rclone, S3) into the backup folder and restore it | it restores |
| 6. clean up | `DROP DATABASE drill_2026_09` | |
| 7. write it down | date, backup used, time taken | |

Time step 1: that is how long a real restore takes. If `point_in_time` says `possible: false`, raise `wal_archive_mb`.

**HTTP: Step 1 and 6 of a drill: restore the newest backup, then drop the copy** (sample data: sample)

```http
POST /api/backup
###
POST /api/restore
Content-Type: application/json

{"as": "drill_check"}
###
POST /exec?db=drill_check
Content-Type: text/plain

SELECT count(*) FROM ochl_day
###
DELETE /api/databases/drill_check
```

Response:

`POST /api/backup`

HTTP 200 (application/json)

```text
{
  "name": "20261024-063935-580",
  "dir": "./backups/demo/20261024-063935-580",
  "created_ms": 1792823975580,
  "created": "2026-10-24T06:39:35.580Z",
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
  "database": "drill_check",
  "source": "demo",
  "backup": {
    "name": "20261024-063935-580",
    "dir": "./backups/demo/20261024-063935-580",
    "created_ms": 1792823975580,
    "created": "2026-10-24T06:39:35.580Z",
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
    "restored 9 data files from ./backups/demo/20261024-063935-580; the log (up to LSN 30) is replayed on first open"
  ],
  "took_ms": 24,
  "next": "check 'drill_check', then POST /api/databases/swap {\"database\":\"demo\",\"with\":\"drill_check\"} to put it in place, or DROP DATABASE drill_check"
}
```

`POST /exec?db=drill_check`

HTTP 200 (application/json)

```text
{
  "query": "SELECT count(*) FROM ochl_day",
  "results": [
    {
      "statement": "SELECT count(*) FROM ochl_day",
      "columns": [
        {"name": "count(*)", "type": "LONG"}
      ],
      "dataset": [
        [57]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 29, "execute_us": 135}
    }
  ],
  "columns": [
    {"name": "count(*)", "type": "LONG"}
  ],
  "dataset": [
    [57]
  ],
  "count": 1,
  "timings": {"parse_us": 29, "execute_us": 135}
}
```

`DELETE /api/databases/drill_check`

HTTP 200 (application/json)

```text
{
  "name": "drill_check",
  "dropped": true,
  "moved_to": "kdb-data/_trash/1792823975643-drill_check"
}
```

<a id="daily-plan"></a>

## A daily backup plan

Syntax:

```sql
after the market closes:  kareladb backup <db> <other disk> --keep-daily 7 --keep-weekly 4
right after:               kareladb check <db>
once a week:               copy the newest backup to a third place
once a month:              a restore drill (below), then a few queries
```

The plan below is for market data that stops arriving at 15:00 local time (the examples use Nepal time and a Sunday-to-Thursday trading week, as on some exchanges). For logs, sensor readings or an app, pick the quietest hour of your own day. Do this every working day:

| When (local time) | What | How |
|---|---|---|
| after 15:00, when imports are done | Backup to **another disk** | `kareladb backup` (server stopped) or `POST /api/backup` (server running). Keep 7 daily + 4 weekly. |
| right after the backup | Check the database | `kareladb check` or `POST /api/check`. Exit code `2` or `"ok":false`: act now. |
| every day | Read the log of the backup script | |
| after each backup | Copy it to a third place (another PC, NAS, cloud) | [--backup-command](backup-schedule.md#backup-command), or `robocopy`, `rsync` or your backup tool |
| once a month | **Test restore** and run a few queries | the [restore drill](#restore-drill), or `kareladb restore <backup> D:\restore-test`, then `kareladb sql D:\restore-test "SELECT count(*) FROM ochl_day"` |
| before a big import or a schema change | An extra backup | `kareladb backup ... --hard-links` is fine here |

**The script** (Windows PowerShell; save as `D:\kdb-work\daily-backup.ps1`; not run here):

```powershell
# daily-backup.ps1 - backup and check after the market closes. Use full paths in a scheduled task.
$Kdb     = "D:\KarelaDB\build\bin\kareladb.exe"
$Data    = "D:\kdb\market"
$Backups = "E:\kdb_backups"
$Log     = "D:\kdb-work\backup-log.txt"

Add-Content $Log "---- $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

$out = & $Kdb backup $Data $Backups --keep-daily 7 --keep-weekly 4 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
Add-Content $Log $out
if ($code -ne 0) { Add-Content $Log "BACKUP FAILED (exit code $code)"; exit $code }

$out = & $Kdb check $Data 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
Add-Content $Log $out
if ($code -ne 0) { Add-Content $Log "CHECK FOUND A PROBLEM (exit code $code)"; exit $code }
```

**Windows Task Scheduler**, Sunday to Thursday at 15:30 (run PowerShell as Administrator; not run here):

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
             -Argument "-NoProfile -ExecutionPolicy Bypass -File D:\kdb-work\daily-backup.ps1" `
             -WorkingDirectory "D:\kdb-work"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday,Monday,Tuesday,Wednesday,Thursday -At 15:30
Register-ScheduledTask -TaskName "KarelaDB daily backup" -Action $action -Trigger $trigger
Start-ScheduledTask -TaskName "KarelaDB daily backup"     # test it once, then read the log
```

**Linux cron** (`crontab -e`; Sunday=0 to Thursday=4, computer time; not run here):

```bash
30 15 * * 0-4  /usr/local/bin/kareladb backup /srv/kareladb/data/market /mnt/backup/kdb --keep-daily 7 --keep-weekly 4 >> /var/log/kdb-backup.log 2>&1 && /usr/local/bin/kareladb check /srv/kareladb/data/market >> /var/log/kdb-backup.log 2>&1
```

**If `kareladb serve` runs all day**, let the server do it: `--backups E:\kdb_backups --backup-schedule "daily 15:30" --backup-copy F:\kdb_copy` makes, checks and copies a backup of every database each day, with no script (see [backups on a schedule](backup-schedule.md)). To do it from a script instead, ask the server. It keeps 7 daily and 4 weekly backups by itself (not run here):

```powershell
$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/api/backup?db=market"
$c = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/api/check?db=market"
if (-not $c.ok) { "CHECK FOUND A PROBLEM: $($c.problems -join '; ')"; exit 2 }
```

With `--token` or users, add `-Headers @{ Authorization = "Bearer <token>" }` (see [HTTP login](http-login.md)).

<a id="after-damage"></a>

## After damage: what to do

Syntax:

```sql
1. stop       2. copy the folder       3. kareladb check <db>
4. kareladb repair <db> --backups <dir>     5. kareladb check <db>
6. if still damaged: kareladb restore <newest backup> <new folder> --logs-from <db>
```

Messages like `failed its checksum`, `DAMAGED`, `the end of the log is damaged`, or exit code `2`:

1. **Stop** the server and every program that uses the database.
2. **Copy** the whole database folder to a safe place (`Copy-Item D:\kdb\market E:\damaged-copy -Recurse`). Then nothing you try can make it worse.
3. `kareladb check <db>` to see what is damaged.
4. `kareladb repair <db> --backups <backups-dir>`. It uses the previous file version, then the backups, and replays the log. See [kareladb repair](cli-maintenance.md#kareladb-repair).
5. `kareladb check <db>` again. When it says `OK: no damage found`, start the server again.
6. If the repair says `Some damage could not be repaired`: `kareladb restore <newest backup> <new folder> --logs-from <db>`, check the new folder, and switch folders.
7. If needed log records are damaged and no backup has them: `kareladb restore ... --logs-from` keeps everything up to the damage. `kareladb repair <db> --accept-log-loss` is the **last** choice: it opens the database and the changes in the damaged part are lost.
8. Find out **why**: disk errors in the Windows Event Viewer, a failing SSD (`smartctl`). Replace bad hardware.

- After a crash or a killed server, `last shutdown: not clean` is normal: KarelaDB replays the log, and confirmed changes are not lost. That is not damage.
- A write that the crash cut in half at the very end of the log is dropped by itself, as if the power had gone a moment earlier.

**Command line: Steps 3 to 5 on a healthy database** (sample data: sample)

```bash
kareladb check market
kareladb repair market --backups backups
kareladb check market
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

`> kareladb check market`

```text
checked 14 files (76.1 KB) and 1 log segments
OK: no damage found
```
