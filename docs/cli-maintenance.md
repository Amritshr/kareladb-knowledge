# kareladb info, check, repair, dump-file

> Look inside a database, find damage, repair it, and check one file.

- Category: Command line
- Keywords: damage, damaged, corruption, checksum, failed its checksum, repair ladder, scrub, manifest, manifest keys, stale keys, LSN, log position, last shutdown, not clean, --accept-log-loss, log loss, torn tail, DAMAGED, PROBLEM, NEEDS REPAIR, maintenance
- See also: [Backup, check, repair and restore](backup-and-safety.md), [Backup, check, repair and restore (after-damage)](backup-and-safety.md#after-damage), [How KarelaDB stores data](data-formats.md), [The kareladb program (exit-codes)](cli-overview.md#exit-codes)

These commands look after a database folder. `kareladb info`, `kareladb check` and `kareladb dump-file` only read. `kareladb repair` changes the database.

All of them need the database **closed**: stop `kareladb serve`, `kareladb shell` and other programs that use it first. While a server runs, use its console (**Check now**) or `POST /api/check` instead.

What to do after damage, step by step: [after damage](backup-and-safety.md#after-damage). How the files look: [data formats](data-formats.md).

## kareladb info

Syntax:

```sql
kareladb info <db> [--data-dir <folder>]
```

Shows what the **manifest** (the list of current files) says: the files, their versions, sizes and log positions.
It does **not** read the files themselves. To find new damage, use [kareladb check](#kareladb-check).

| Line or column | Meaning |
|---|---|
| `database` | The folder that was opened |
| `manifest` | `copy a` or `copy b`: which of the two manifest copies is newest, and its `sequence` (how often it was saved). A `note:` line under it says when one copy could not be used. |
| `last shutdown` | `clean`, or `not clean (running now, crashed or killed)` |
| `log position N (saved in files up to M)` | N = number (LSN) of the last change in the log. M = every change up to M is in the data files. |
| `newest change` | Time of the last change, in the **local time** of this computer |
| `features` | The stored-format features the database uses, or `no list yet` for a database of an older KarelaDB ([versions](versions.md)) |
| `manifest keys` | How many extra entries the manifest holds (partition summaries and row counts of files). `(N of files that are gone: ...)` counts stale ones, left by a `DROP TABLE` of an older build; they are removed the next time the database is opened for writing. Harmless. |
| `FILE` | `catalog` = the list of tables. `t/4/2026-09` = table number 4, partition `2026-09`. `all` = a table without partitions. |
| `VERSION` | Version of the file. A change writes a new version. |
| `LSN` | The file holds every change up to this log position |
| `STATUS` | `ok`, or `DAMAGED: <reason>` when KarelaDB marked the file as damaged |
| last line | `N files, <size>, M marked damaged` |

- **Exit code:** `0`; `2` when a file is marked damaged; `1` when the folder has no manifest (not a database).
- **LSN** = log sequence number: every change in the log gets the next number.
- `last shutdown: not clean (running now, ...)` is normal while a program has the database open.

**Command line** (sample data: sample)

```bash
kareladb info market
```

Output:

```text
database        market
manifest        copy a, sequence 9
last shutdown   clean
log position    30 (saved in files up to 30)
newest change   2026-10-24 09:40:44
features        batched_log_sync, block_stats, compressed_log, partition_format_2
manifest keys   26

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

**Command line: A folder that is not a database** (sample data: sample)

```bash
kareladb info not-a-database
```

Output:

```text
error: Not found: no manifest
```

exit code 1

## kareladb check

Syntax:

```sql
kareladb check <db> [--data-dir <folder>] [--no-audit-chain]
```

Reads **every block** of every data file and **every record** of the log, and checks each checksum. It reports damage and **changes nothing** (it opens the database read-only).

- **Exit code:** `0` = no damage. `2` = damage found. `3` = the database was written by a newer KarelaDB: not damage, do not repair it ([versions](versions.md#needs-newer)). `1` = it could not run (the folder does not exist, or the database is open in another program).
- **Output lines:** `OK: no damage found`, or one line per problem: `DAMAGED:` (a file that could not be loaded), `NEEDS REPAIR:` (a problem `kareladb repair` can fix), `PROBLEM:` (a bad block, a bad log record).
- **Audit chain:** when the files are sound and the database has an [audit log](audit-log.md#hash-chain), it then checks the hash chain of `_audit_log`: `audit chain: N row(s) checked ...`, or `TAMPERED:` for a row that was changed or removed outside KarelaDB (exit code `2`). This opens the database read-only and replays its log in memory; `--no-audit-chain` skips it.
- Run it every day, right after the backup. It is also the SQL [CHECK TABLE](backup-and-safety.md#check-table) and the shell's `.check`.
- Time: it reads everything, so a big database takes a while (about as long as copying it).

**Command line: A healthy database** (sample data: sample)

```bash
kareladb check market
```

Output:

```text
checked 14 files (76.1 KB) and 1 log segments
OK: no damage found
```

**Command line: A folder that does not exist** (sample data: sample)

```bash
kareladb check markett
```

Output:

```text
error: 'markett' is not a KarelaDB database (it has no _manifest.a or _manifest.b). Check the name or path.
```

exit code 1

A damaged database (real output from [chapter 9](../tutorial/09-backup-and-safety.md), where 64 zero bytes were written into a data file of a copy):

```text
checked 12 files (73.8 KB) and 1 log segments
DAMAGED: t/4/2026-09: market-test/files/t/4/2026-09.v11.kdb: block 0 (bytes 0-57697) failed its checksum (no good previous version or backup copy)
PROBLEM: t/4/2026-09: marked DAMAGED: market-test/files/t/4/2026-09.v11.kdb: block 0 (bytes 0-57697) failed its checksum
PROBLEM: t/4/2026-09 v11 (current): 1 damaged block(s): 0

Damage found. Fix it with: kareladb repair market-test --backups <backups-dir>
```

The exit code was `2`. Queries on other tables still worked. A query on the damaged part gave an error, never wrong numbers:

```text
error: table 'ochl_minutes' partition 2026-09: market-test/files/t/4/2026-09.v11.kdb: block 0 (bytes 0-57697) failed its checksum. Run: kareladb repair <data-dir> --backups <dir>
```

```powershell
# A script that checks every night (not run here)
kareladb check D:\kdb\market | Out-File -Append check-log.txt
if ($LASTEXITCODE -eq 2) { Write-Output "DAMAGE FOUND: stop the server and run kareladb repair" }
```

## kareladb repair

Syntax:

```sql
kareladb repair <db> [--backups <dir>] [--accept-log-loss] [--data-dir <folder>]
```

Opens the database and fixes damaged files with the **repair ladder**. Then it reads everything again and says what is still damaged.

| Option | Meaning | Default |
|---|---|---|
| `--backups <dir>` | Backups to take good copies of files and log records from. For a database **name** in the data folder, KarelaDB looks in `<dir>/<name>`. | only old versions on disk |
| `--accept-log-loss` | Last choice: when needed log records are damaged, cut the log there and open anyway. The changes in the damaged part are **lost**. | refuse to open |
| `--data-dir <folder>` | The data folder | `KARELADB_DATA_DIR` |

**The repair ladder** for one damaged data file. KarelaDB tries each rung, top to bottom:

| Rung | KarelaDB tries | Then |
|---|---|---|
| 1 | The **previous version** of the file (KarelaDB keeps 2) | Replays the log from that version, so no change is lost |
| 2 | The same file from a **backup** (`--backups`), newest backup first | Copies it back and replays the log from the backup's position, so changes made after the backup come back too |
| 3 | Nothing worked | Marks only this file as `DAMAGED`. The rest of the database still works. |

- **Exit code:** `0` = `Repaired.` or `Nothing to repair.` `2` = `Some damage could not be repaired.` `3` = the database needs a newer KarelaDB; nothing was repaired or changed. `1` = it could not run (for example the database is open in another program).
- **Before a repair, copy the whole damaged folder to a safe place.** Then nothing you try can make it worse.
- Only backups of the **same** database are used. A backup of another database, or of a history that a restore left behind, is never used.
- A log that is only damaged at the very end (a write that a crash cut in half) needs no repair: it is cut away when the database opens, and the output says `dropped an unfinished write at the end of the log`.
- **Damaged log records that are still needed:** KarelaDB refuses to open and names the log file. Try, in this order: `kareladb repair <db> --backups <dir>` (copies the good bytes from a backup), then [kareladb restore](backup-and-safety.md#kareladb-restore) with `--logs-from`, and only then `--accept-log-loss`.
- **Notes:** `kareladb repair` on a folder that does not exist makes a new, empty database there and says `Nothing to repair.` Check the path.

**Command line: A healthy database: nothing to repair** (sample data: sample)

```bash
kareladb repair market --backups backups
```

Output:

```text
manifest copy: a, last shutdown: clean
replayed 0 transactions after LSN 30, last LSN 30

Nothing to repair.
```

Repairing the damaged copy from `kareladb check` above (real output from [chapter 9](../tutorial/09-backup-and-safety.md)). First without backups: the file had no previous version, so rung 1 cannot help:

```text
manifest copy: a, last shutdown: clean
replayed 0 transactions after LSN 34, last LSN 34
DAMAGED: t/4/2026-09: market-test/files/t/4/2026-09.v11.kdb: block 0 (bytes 0-57697) failed its checksum (no good previous version or backup copy)
still damaged: t/4/2026-09: marked DAMAGED: market-test/files/t/4/2026-09.v11.kdb: block 0 (bytes 0-57697) failed its checksum
still damaged: t/4/2026-09 v11 (current): 1 damaged block(s): 0

Some damage could not be repaired. Restore a backup with: kareladb restore
```

(exit code `2`). Then with `kareladb repair market-test --backups backups`:

```text
manifest copy: a, last shutdown: clean
replayed 2 transactions after LSN 30, last LSN 34
REPAIRED: t/4/2026-09: market-test/files/t/4/2026-09.v11.kdb: block 0 (bytes 0-57697) failed its checksum -> restored from backup backups/20260911-142715-556 (v11) and replaying the log from LSN 30

Repaired.
```

(exit code `0`). The 2 transactions after the backup were replayed, so nothing was lost. When a previous version exists, the line says `using previous version v10 and replaying the log from LSN ...` instead.

A damaged end of the log (real output from chapter 9):

```text
manifest copy: a, last shutdown: clean
replayed 0 transactions after LSN 34, last LSN 34
dropped an unfinished write at the end of the log (178 bytes)

Nothing to repair.
```

**Command line: --accept-log-loss on a healthy database changes nothing** (sample data: sample)

```bash
kareladb repair market --accept-log-loss
```

Output:

```text
manifest copy: a, last shutdown: clean
replayed 0 transactions after LSN 30, last LSN 30

Nothing to repair.
```

## kareladb dump-file

Syntax:

```sql
kareladb dump-file <file.kdb>
```

Shows the 64-byte **header** of one KarelaDB file and checks the **checksum** of every block. For experts: use it to look at one file that `kareladb check` named.

| Line | Meaning |
|---|---|
| `type` | `data file`, `manifest`, `backup manifest` or `WAL segment` (a log file) |
| `version` | File format version (`1`) |
| `data` | Size of the data in the file |
| `block size` | The data is cut into blocks of this size (65536 bytes); each block has a CRC32C checksum |
| `LSN` | The file holds every change up to this log position |
| `id` | For a data file: the table number. For a manifest: its sequence number. |
| `created` | When the file was written (local time) |
| `blocks`, `digest` | Number of blocks, and one checksum over the header and all block checksums |
| last line | `OK: all blocks match their checksums`, or `DAMAGED block N` for each bad block |

- **Exit code:** `0` = all blocks are good. `2` = a damaged block, or a header that is not a KarelaDB header. `1` = the file cannot be opened.
- For a log file (`wal/*.log`) it shows only the header.
- Data files are in `files/t/<table number>/<partition>.v<version>.kdb`. [kareladb info](#kareladb-info) lists them.

**Command line: The manifest of the sample database** (sample data: sample)

```bash
kareladb dump-file market/_manifest.a
```

Output:

```text
file         market/_manifest.a
type         manifest
version      1
data         2.3 KB
block size   65536
LSN          30
id           9
created      2026-10-24 09:40:44
blocks       1
digest       0e660cec
OK: all blocks match their checksums
```

**Command line: A data file: table 1 (securities), version 7** (sample data: sample)

```bash
kareladb info market
kareladb dump-file market/files/t/1/all.v7.kdb
```

Output:

`> kareladb info market`

```text
database        market
manifest        copy a, sequence 9
last shutdown   clean
log position    30 (saved in files up to 30)
newest change   2026-10-24 09:40:44
features        batched_log_sync, block_stats, compressed_log, partition_format_2
manifest keys   26

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

`> kareladb dump-file market/files/t/1/all.v7.kdb`

```text
file         market/files/t/1/all.v7.kdb
type         data file
version      1
data         693 B
block size   65536
LSN          30
id           1
created      2026-10-24 09:40:44
blocks       1
digest       1d198644
OK: all blocks match their checksums
```

**Command line: A file that is not a KarelaDB file** (sample data: sample)

```bash
kareladb dump-file market/kdb.lock
```

Output:

```text
error: Corruption: market/kdb.lock: file is 0 bytes, too short for a header
```

exit code 2

A damaged data file (real output from chapter 9):

```text
file         story/files/t/3/2026.v15.kdb
type         data file
version      1
data         3.1 KB
block size   65536
LSN          1092
id           3
created      2026-09-11 13:45:11
blocks       1
digest       bb8fefdd
DAMAGED block 0
```
