# 9. Backup and safety

- Category: Tutorial

## What you will learn

- What protects your data, in simple words.
- How to check a database, make and test backups, and restore to an exact time.
- What to do when a disk is damaged: a real example with real output.

The examples use the database `market` with the sample data. **No server may be running** on it (these commands need the database closed). Chapter 8 shows the server versions (`/api/check`, `/api/backup`).

## What protects your data

| Danger | What KarelaDB does |
|---|---|
| Power cut or crash while writing | Every change goes into the **log** first, and the log is saved to disk before KarelaDB says "done". At the next start KarelaDB plays the log again. Nothing that was confirmed is lost. |
| A file only half written | Data files are **never changed**. KarelaDB writes a new version, checks it, and then switches to it. A crash leaves the old version complete. |
| A bit on the disk goes bad | Every block of every file has a **checksum**. KarelaDB notices one wrong bit and knows which file and block is bad. It never returns wrong data without telling you. |
| A damaged file | **Repair ladder:** KarelaDB tries the previous version of the file (+ the log), then a copy from a backup (+ the log). |
| The list of files is damaged | The list (manifest) is saved **twice**. One good copy is always left. |
| A mistake (wrong UPDATE, bad import) | **Point-in-time restore:** a backup + the log, up to the second before the mistake. |
| The whole disk dies | Only **backups on another disk** help. `kareladb serve --backup-schedule "daily 16:00" --backup-copy <other disk>` makes them by itself (chapter 21). |
| `DROP TABLE` by mistake | The table goes to the **trash** for 7 days: `UNDROP TABLE t` (chapter 21). |
| A slow query or a script in a loop | Statement timeout, memory limits and a limit per user in `kareladb serve` (chapter 21). |

The details are in docs/FORMAT.md (for developers).

## The commands

| Command | What it does | Changes the database? |
|---|---|---|
| `kareladb info <db>` | Lists the files, versions and log position | no |
| `kareladb check <db>` | Reads every block and every log record; reports damage | no |
| `kareladb backup <db> <backups>` | Makes a backup and checks it | no (it adds a backup) |
| `kareladb backups <backups>` | Lists backups, newest first | no |
| `kareladb verify-backup <backup>` | Reads the whole backup again | no |
| `kareladb repair <db> [--backups <folder>] [--accept-log-loss]` | Fixes damaged files | yes |
| `kareladb restore <backup> <new-db> [--logs-from <old-db>] [--until "YYYY-MM-DD HH:MM[:SS]"]` | Makes a **new** database from a backup | no (makes a new folder) |
| `kareladb dump-file <file.kdb>` | Header and block checksums of one file | no |

Exit codes: `0` OK, `1` error (for example: the database is open in another program), `2` damage, `3` the database needs a newer KarelaDB (chapter 24).

## kareladb info

```powershell
kareladb info market
```

```text
database        market
manifest        copy b, sequence 12
last shutdown   clean
log position    30 (saved in files up to 30)
newest change   2026-09-23 17:57:58
features        batched_log_sync, block_stats, partition_format_2
manifest keys   23

FILE                                      VERSION       SIZE          LSN  STATUS
catalog                                         6     2.1 KB           30  ok
t/1/all                                         7      777 B           30  ok
t/2/all                                         8      556 B           30  ok
t/3/2025                                        9     1.7 KB           30  ok
t/3/2026                                       10     3.6 KB           30  ok
t/4/2026-09                                    11    57.0 KB           30  ok
t/5/2026-09-09                                 12     1.4 KB           30  ok
t/5/2026-09-10                                 13     2.4 KB           30  ok
t/6/2026-09-10                                 14     2.7 KB           30  ok

9 files, 72.1 KB, 0 marked damaged
(STATUS is what the manifest records. To read every block and find new damage, run: kareladb check)
```

| Line | Meaning |
|---|---|
| `manifest copy b` | Which of the two manifest copies is newest |
| `last shutdown` | `clean`, or `not clean` after a crash or kill (then the log was replayed) |
| `log position 30` | Number (LSN) of the last change |
| `newest change` | Time of the last change, **local time** of this computer |
| `features` | The stored-format features this database uses. An older KarelaDB that does not know one of them refuses to open it (chapter 24). `batched_log_sync` is in every database this KarelaDB writes: commits that come at the same moment share one write to the disk (group commit), and that needs this log format. |
| `manifest keys` | How many extra entries the manifest keeps besides the files (counters, settings). When some belong to files that are gone, the line says so; KarelaDB removes them the next time it opens the database for writing. |
| `t/4/2026-09` | Table number 4 (tables are numbered in the order they were made), partition `2026-09` |
| `catalog` | The list of tables and columns |
| `LSN` | The file holds every change up to this log position. A checkpoint also raises it for files that had no changes, so an old table does not make KarelaDB read old log. |
| `STATUS` | `ok`, or `DAMAGED: ...` if KarelaDB marked the file as damaged |

`kareladb info` only reads the list of files. It does **not** read the files. To find damage, use `kareladb check`.

## kareladb check

```powershell
kareladb check market
"exit code: $LASTEXITCODE"
```

```text
checked 11 files (74.7 KB) and 1 log segments
OK: no damage found
exit code: 0
```

`kareladb check` changes nothing. Run it every day (see the routine at the end). For a running server, use the console's **Check now** or `POST /api/check`.

## kareladb backup

```powershell
kareladb backup market backups --keep-daily 7 --keep-weekly 4
```

```text
backup created and verified: backups/20260923-121259-430
  9 files, 190.0 KB, log up to 30
```

- A backup is a new folder inside `backups`. Its name is the **UTC** time: `20260923-121259-430` = 2026-09-23 12:12:59.430 UTC (17:57 Nepal time).
- It holds a copy of the data files, the needed log files, and `backup.kdb` (the list, written last). A folder without `backup.kdb` is not finished and is never used.
- After copying, KarelaDB **reads the whole backup again**. Only then it prints "verified".
- `--keep-daily 7 --keep-weekly 4` deletes old backups: it keeps the newest backup of each of the last 7 days and each of the last 4 weeks (weeks start on Sunday, UTC). Without these options, nothing is deleted.
- `kareladb backup` needs the database closed. With a running server, use `BACKUP DATABASE`, **Backup now**, or `POST /api/backup`. They work while the server keeps running.

### --hard-links

```powershell
kareladb backup market backups-fast --hard-links
```

```text
backup created and verified: backups-fast/20260923-121309-580
  9 files, 197.0 KB, log up to 38
```

Hard links are very fast and use no extra space. But the backup and the database then share the **same disk sectors**. If the disk goes bad, both are lost. Use hard links only as an extra "undo point" (for example before a big import), never as your only backup. The log files are always copied.

## kareladb backups and verify-backup

```powershell
kareladb backups backups
```

```text
BACKUP                 CREATED               FILES       SIZE      LOG LSN
20260923-121259-430    2026-09-23 17:57:59       9   190.0 KB           30
1 backups
```

`CREATED` is shown in **local time**. The folder name is UTC.

```powershell
$newest = Get-ChildItem backups -Directory | Sort-Object Name | Select-Object -Last 1
kareladb verify-backup "backups\$($newest.Name)"
"exit code: $LASTEXITCODE"
```

```text
OK: backup is intact
exit code: 0
```

A backup that you never tested is not a backup. Verify old backups from time to time, and do a test restore once a month (see below).

## A story: the disk is damaged

This is a real run. We made a **copy** of the database and wrote zeros into the middle of one data file, like a bad disk sector would.

> **Never do this on real data.** It is only for learning.

### Before: a backup, then more work

The backup above was made at 17:57. After it, work went on:

```sql
-- Work goes on after the backup.
INSERT INTO ochl_day VALUES ('2026-09-13', 'CITY', 505.0, 509.0, 503.1, 508.2, 91000);
UPDATE ochl_day SET volume = 41500 WHERE symbol = 'VOLT' AND time IN '2026-09-10';
```

```text
1 row(s) inserted

1 row(s) updated
```

### The damage

```powershell
# FOR LEARNING ONLY. Never do this to a real database.
# Make a copy, then write 64 zero bytes into the middle of one data file of the copy.
Copy-Item market market-test -Recurse

$file = Get-ChildItem market-test\files\t\4 -Filter *.kdb | Sort-Object Name | Select-Object -Last 1
"damaging files\t\4\$($file.Name) (table ochl_minutes)"
$fs = [System.IO.File]::OpenWrite($file.FullName)
$null = $fs.Seek(20000, [System.IO.SeekOrigin]::Begin)
$fs.Write((New-Object byte[] 64), 0, 64)
$fs.Close()
```

```text
damaging files\t\4\2026-09.v11.kdb (table ochl_minutes)
```

### Step 1: notice the problem

Queries on other tables still work. A query that needs the damaged rows refuses to answer. **It never gives wrong numbers:**

```powershell
kareladb sql market-test "SELECT count(*) FROM ochl_day"
kareladb sql market-test "SELECT count(*) FROM ochl_minutes"
kareladb sql market-test "SELECT time, close FROM ochl_minutes WHERE symbol = 'CITY' ORDER BY time DESC LIMIT 1"
"exit code: $LASTEXITCODE"
```

```text
count(*)
--------
      58
(1 row, 0.3 ms)
count(*)
--------
     956
(1 row, 0.3 ms)
error: table 'ochl_minutes' partition 2026-09: market-test/files/t/4/2026-09.v11.kdb: block 0 (bytes 0-58257) failed its checksum. Run: kareladb repair <data-dir> --backups <dir>
exit code: 2
```

- `count(*)` of `ochl_minutes` still answers, and the number is right. KarelaDB saves the row count and the min, max and sum of each column with every file. `count`, `sum`, `min` and `max` of a whole partition come from these saved numbers, so the damaged block is not read.
- The third query needs the rows themselves. They are in the damaged block, so KarelaDB refuses, names the file and the block, and exits with code `2`.

### Step 2: stop everything and check

Stop the server and all programs that use the database. Then:

```powershell
kareladb check market-test
"exit code: $LASTEXITCODE"
```

```text
checked 12 files (78.4 KB) and 1 log segments
DAMAGED: t/4/2026-09: market-test/files/t/4/2026-09.v11.kdb: block 0 (bytes 0-58257) failed its checksum (no good previous version or backup copy)
PROBLEM: t/4/2026-09: marked DAMAGED: market-test/files/t/4/2026-09.v11.kdb: block 0 (bytes 0-58257) failed its checksum
PROBLEM: t/4/2026-09 v11 (current): 1 damaged block(s): 0

Damage found. Fix it with: kareladb repair market-test --backups <backups-dir>
exit code: 2
```

**Before a repair, copy the whole damaged folder somewhere safe** (for example `Copy-Item D:\kdb\market E:\damaged-copy -Recurse`). Then nothing you try can make things worse.

### Step 3: repair without a backup

The minute table's file has no older version (it was written only once), so the first rung of the ladder does not help:

```powershell
kareladb repair market-test
"exit code: $LASTEXITCODE"
```

```text
manifest copy: b, last shutdown: clean
replayed 0 transactions after LSN 34, last LSN 34
DAMAGED: t/4/2026-09: market-test/files/t/4/2026-09.v11.kdb: block 0 (bytes 0-58257) failed its checksum (no good previous version or backup copy)
still damaged: t/4/2026-09: marked DAMAGED: market-test/files/t/4/2026-09.v11.kdb: block 0 (bytes 0-58257) failed its checksum
still damaged: t/4/2026-09 v11 (current): 1 damaged block(s): 0

Some damage could not be repaired. Restore a backup with: kareladb restore
exit code: 2
```

### Step 4: repair with the backups

```powershell
kareladb repair market-test --backups backups
"exit code: $LASTEXITCODE"
```

```text
manifest copy: b, last shutdown: clean
replayed 2 transactions after LSN 30, last LSN 34
REPAIRED: t/4/2026-09: market-test/files/t/4/2026-09.v11.kdb: block 0 (bytes 0-58257) failed its checksum -> restored from backup backups/20260923-121259-430 (v11) and replaying the log from LSN 30

Repaired.
exit code: 0
```

KarelaDB took the file from the backup and then **replayed the log** from the backup's position (30) to the end. So also the changes made **after** the backup are back.

### Step 5: check again

```powershell
kareladb check market-test
"exit code: $LASTEXITCODE"
kareladb sql market-test "SELECT count(*) AS minute_rows FROM ochl_minutes; SELECT time, symbol, close, volume FROM ochl_day WHERE time >= '2026-09-10' ORDER BY symbol, time"
```

```text
checked 12 files (78.4 KB) and 1 log segments
OK: no damage found
exit code: 0
minute_rows
-----------
        956
(1 row, 0.7 ms)

time                     | symbol | close | volume
-------------------------+--------+-------+-------
2026-09-10T00:00:00.000Z | CITY   | 504.9 | 183040
2026-09-13T00:00:00.000Z | CITY   | 508.2 |  91000
2026-09-10T00:00:00.000Z | COAST  | 376.1 | 186200
2026-09-10T00:00:00.000Z | VOLT   | 191.2 |  41500
(4 rows, 0.2 ms)
```

All 956 minute rows are back, and so are the two changes made after the backup (the 2026-09-13 row and the volume 41500).

Also try: the damaged file was replaced from the **previous version** when one exists. Then `kareladb repair` works even without `--backups`, and the message says `using previous version v10 and replaying the log`.

## When the log is damaged

The log is only needed for changes that are **not yet saved** in the data files. `kareladb sql`, `kareladb shell` and a server stopped with Ctrl+C save everything when they close. So damage at the end of the log then costs nothing:

```powershell
# FOR LEARNING ONLY. Damage the end of the log in another copy.
Copy-Item market market-log -Recurse

$log = Get-ChildItem market-log\wal -Filter *.log | Sort-Object Name | Select-Object -Last 1
$fs = [System.IO.File]::OpenWrite($log.FullName)
$null = $fs.Seek(-40, [System.IO.SeekOrigin]::End)
$fs.Write([byte[]](1..32), 0, 32)
$fs.Close()

kareladb check market-log
"exit code: $LASTEXITCODE"
```

```text
checked 12 files (78.4 KB) and 1 log segments
OK: no damage found
exit code: 0
```

`kareladb repair` cuts the damaged end away and continues the log in a new file. Nothing is lost:

```powershell
kareladb repair market-log --backups backups
"exit code: $LASTEXITCODE"
```

```text
manifest copy: a, last shutdown: clean
replayed 0 transactions after LSN 34, last LSN 34
dropped an unfinished write at the end of the log (185 bytes)

Nothing to repair.
exit code: 0
```

**After a crash** (power cut, killed server) the newest changes may be only in the log. If exactly that end is damaged, KarelaDB cannot tell it from a write the crash cut in half, so it drops those last changes, as if the power had gone a moment earlier. After a crash, check the newest data and load it again if needed.

If log records that KarelaDB still **needs** are damaged (not only the very end), KarelaDB refuses to open the database and names the damaged log file. The choices, in this order:

1. `kareladb repair <db> --backups <folder>`: when a backup has those log records, KarelaDB copies the good bytes from it.
2. `kareladb restore` from the newest backup with `--logs-from <db>`: keeps everything up to the damage.
3. `kareladb repair <db> --accept-log-loss`: opens the database and accepts that the changes in the damaged part are lost.
## A story: an UPDATE without WHERE

At about 14:05 someone runs an UPDATE and forgets the WHERE. Every close price becomes 0.

(`kareladb serve --safe-updates` refuses such an UPDATE, see chapter 21. `kareladb sql`, used here, does not.)

```powershell
kareladb sql market "INSERT INTO ochl_day VALUES ('2026-09-14', 'CITY', 508, 512, 507, 511, 64000)"

Start-Sleep -Seconds 2
# Remember a time when the data was still good (local time of this computer).
Get-Date -Format "yyyy-MM-dd HH:mm:ss" | Set-Content good-time.txt
Start-Sleep -Seconds 2

# The mistake: an UPDATE without WHERE.
kareladb sql market "UPDATE ochl_day SET close = 0"
kareladb sql market "SELECT time, symbol, close FROM ochl_day WHERE time >= '2026-09-10' ORDER BY symbol, time"
```

```text
1 row(s) inserted
59 row(s) updated
time                     | symbol | close
-------------------------+--------+------
2026-09-10T00:00:00.000Z | CITY   |     0
2026-09-13T00:00:00.000Z | CITY   |     0
2026-09-14T00:00:00.000Z | CITY   |     0
2026-09-10T00:00:00.000Z | COAST  |     0
2026-09-10T00:00:00.000Z | VOLT   |     0
(5 rows, 0.2 ms)
```

(In real life you do not have `good-time.txt`. You know roughly when the mistake happened, for example "a few minutes after 14:05". Use a time **before** the mistake.)

### Restore to the moment before the mistake

```powershell
$goodTime = Get-Content good-time.txt
$backup = Get-ChildItem backups -Directory | Sort-Object Name | Select-Object -Last 1

kareladb restore "backups\$($backup.Name)" market-restored --logs-from market --until $goodTime
"exit code: $LASTEXITCODE"
kareladb sql market-restored "SELECT time, symbol, close FROM ochl_day WHERE time >= '2026-09-10' ORDER BY symbol, time"
```

```text
stopped at the requested time: changes after LSN 36 are not restored
restored 9 data files from backups\20260923-121259-430 plus 1 newer log segments; the log (up to LSN 36) is replayed on first open
restored into market-restored
exit code: 0
time                     | symbol | close
-------------------------+--------+------
2026-09-10T00:00:00.000Z | CITY   | 504.9
2026-09-13T00:00:00.000Z | CITY   | 508.2
2026-09-14T00:00:00.000Z | CITY   |   511
2026-09-10T00:00:00.000Z | COAST  | 376.1
2026-09-10T00:00:00.000Z | VOLT   | 191.2
(5 rows, 0.3 ms)
```

- The prices are back. The row for 2026-09-14, made **after** the backup but **before** the mistake, is also there.
- `--logs-from market` takes the newer log from the old database. Without it, you get the backup as it was.
- `--until "2026-09-11 14:05"` or `"2026-09-11 14:05:30"` is **local time** of this computer. Changes in that second are included.
- The target folder must be **new or empty**:

```powershell
$backup = Get-ChildItem backups -Directory | Sort-Object Name | Select-Object -Last 1
kareladb restore "backups\$($backup.Name)" market-restored
"exit code: $LASTEXITCODE"
```

```text
error: Already exists: restore target is not empty: market-restored
exit code: 1
```

Then switch over:

1. Stop the server.
2. Rename the folders: `market` → `market-broken`, `market-restored` → `market`.
3. Start the server again. Keep `market-broken` until you are sure.

Check the restored database before you switch:

```powershell
kareladb check market-restored
"exit code: $LASTEXITCODE"
```

```text
checked 10 files (75.9 KB) and 2 log segments
OK: no damage found
exit code: 0
```

A backup holds only the current version of each file, so a restored database has no older versions yet. They appear again as data changes.

## Daily routine for a trading database

The sample market closes at 15:00 Nepal time and trades Sunday to Thursday. Use your own market hours and days. Do this every trading day:

| When (NPT) | What | How |
|---|---|---|
| after 15:00, when the day's imports are done | Backup to **another disk** | `kareladb serve --backup-schedule "daily 16:00" --backup-copy <other disk>` does it by itself; or `kareladb backup` (server stopped) or `POST /api/backup` (server running). Keep 7 daily + 4 weekly. |
| right after the backup | Check the database | `kareladb check` or `POST /api/check`. Exit code 2 or `"ok":false` → act now. |
| every day | Look at the log of the backup script, or for `WARNING` and `FAILED` in the server's output | chapter 7, chapter 21 |
| once a week | Copy the newest backup to a third place (another PC, NAS, cloud) | `robocopy` or your normal backup tool |
| once a month | **Test restore** into a test folder, run a few queries | `kareladb restore <backup> D:\restore-test`, then `kareladb sql D:\restore-test "SELECT count(*) FROM ochl_day"` |
| before a big import or a schema change | An extra backup | `kareladb backup ...` (hard links are OK here) |

When a check finds damage:

1. Stop the server.
2. Copy the damaged database folder to a safe place.
3. `kareladb repair <db> --backups <backups>`.
4. `kareladb check <db>`. If it is OK, start the server again.
5. If repair fails: `kareladb restore <newest backup> <new folder> --logs-from <db>`, check it, and switch folders.
6. Find out **why** (disk errors in Windows Event Viewer, a failing SSD). Replace bad hardware.

## Other safety facts

- **Backups while the server runs:** `POST /api/backup` and scheduled backups do not stop the server. KarelaDB waits for an open transaction (at most a few seconds), writes a checkpoint, and copies the files while reads and writes go on.
- **Disk full:** KarelaDB stops accepting writes when less than 64 MB is free, so a full disk never leaves something half written. A program gets HTTP 507 (`disk full`). Writes work again when there is space, without a restart.
- **Old versions:** KarelaDB keeps the 2 previous versions of each file (for the repair ladder) and moves older ones to `_trash`. Files older than 1 hour leave the trash while the server runs. `PURGE TRASH` frees that space at once.
- **Log archive:** old log files go to `wal_archive` (up to 1 GB by default; `ALTER DATABASE ... SET WAL_ARCHIVE` or the Settings page changes it), for backups and repairs. With it `OFF`, a damaged file can only be repaired from a backup.
- **Killing the server** (closing the window, `Stop-Process`) is safe: it is like a power cut. The next start shows `last shutdown: not clean` and replays the log. But **Ctrl+C is better**: it closes the database cleanly.

## dump-file (for experts)

Shows the header and checks the blocks of one file:

```powershell
kareladb dump-file market-test\files\t\4\2026-09.v11.kdb
```

For a damaged file it ends with `DAMAGED block 0` and exit code 2. Example from a damaged test file:

```text
file         story/files/t/3/2026.v15.kdb
type         data file
version      1
data         3.1 KB
block size   65536
LSN          34
id           3
created      2026-09-11 13:45:11
blocks       1
digest       bb8fefdd
DAMAGED block 0
```

## Try it yourself

1. Make a backup of `market`, then list the backups.
2. Delete all rows of `live_data` by mistake. Restore a new database from the backup with `--logs-from` and an `--until` time from before the delete.
3. What exit code does `kareladb check` give on a healthy database, and what on a damaged one?

<details>
<summary>Answers</summary>

1. ```powershell
   kareladb backup market backups
   kareladb backups backups
   ```
2. ```powershell
   Get-Date -Format "yyyy-MM-dd HH:mm:ss"      # note the time, e.g. 2026-09-11 15:40:10
   kareladb sql market "DELETE FROM live_data"
   $b = Get-ChildItem backups -Directory | Sort-Object Name | Select-Object -Last 1
   kareladb restore "backups\$($b.Name)" market-undo --logs-from market --until "2026-09-11 15:40:10"
   kareladb sql market-undo "SELECT count(*) FROM live_data"
   ```
3. `0` when healthy, `2` when damage is found (`1` when it cannot run at all, for example the database is open in another program).

</details>

---

Next: [10. Moving from QuestDB](10-migrating-from-questdb.md)
