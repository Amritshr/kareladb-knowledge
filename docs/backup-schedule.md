# Backups on a schedule

> kareladb serve makes a verified backup of every database at set times, checks a second copy on another disk, runs your command to copy each backup off the server, and warns when the last good backup is old.

- Category: Backup, check, repair, restore
- Keywords: backup schedule, scheduled backup, nightly backup, daily backup, automatic backup, second copy, copy to another disk, offsite, off-site, S3, rclone, scp, remote storage, backup command, backup status, backup warning, default backup folder, \_backups, KARELADB\_BACKUP\_DIR, KARELADB\_BACKUP\_SCHEDULE, KARELADB\_BACKUP\_COMMAND, KARELADB\_BACKUP\_KEEP\_DAILY, KARELADB\_BACKUP\_KEEP\_WEEKLY, backup\_dir, backup\_schedule, backup\_command, --backups, --backup-schedule, --backup-copy, --backup-command, --backup-warn-hours, --keep-daily, --keep-weekly, daily, hourly, every
- See also: [Backup, check, repair and restore](backup-and-safety.md), [kareladb serve](cli-serve.md), [kareladb info, check, repair, dump-file](cli-maintenance.md), [Health, info, check and backup over HTTP](http-server-info.md), [Protection - timeouts, limits, safe updates, read-only](protection.md), [Audit log](audit-log.md)

You do not need a scheduled task outside KarelaDB: `kareladb serve` makes the backups itself.

A backup does not stop the database. KarelaDB waits for an open transaction to end, writes a checkpoint, and then copies the files while reads and writes go on.

<a id="backup-settings"></a>

## Where the settings come from

Each backup setting is read when the server starts. The first of these wins: a flag, `kareladb.conf` (the [Settings page](console-settings.md#backups) saves it there), the environment, the default.

| Setting | Flag | `kareladb.conf` | Environment | Default |
|---|---|---|---|---|
| backup folder | `--backups <dir>` | `backup_dir` | `KARELADB_BACKUP_DIR` | `_backups` in the data folder (one folder served by its path: `_backups/<folder name>` next to it) |
| schedule | `--backup-schedule` | `backup_schedule` | `KARELADB_BACKUP_SCHEDULE` | `off` |
| daily backups kept | `--keep-daily` | `backup_keep_daily` | `KARELADB_BACKUP_KEEP_DAILY` | 7 |
| weekly backups kept | `--keep-weekly` | `backup_keep_weekly` | `KARELADB_BACKUP_KEEP_WEEKLY` | 4 |
| copy command | `--backup-command` | `backup_command` | `KARELADB_BACKUP_COMMAND` | none |

- A server with a data folder always has a backup folder: `<data folder>/_backups`, one sub-folder per database. In Docker that is `/data/_backups`, inside the volume, so a rebuild keeps it. `BACKUP DATABASE` and **Backup now** work without any setting.
- `off` as the folder turns backups off. `_backups` cannot be a database name.
- The default folder is on the **same disk** as the data. Copy the backups off the server too: [--backup-command](#backup-command) or [--backup-copy](#backup-copy).
- A folder served by its path (`kareladb serve D:\kdb\market`) backs up into `D:\kdb\_backups\market`: the folder a data-folder server in `D:\kdb` would use for the database `market`, so both keep one set of backups. It is next to the database folder, never inside it.
- The Settings page can save the schedule and what is kept, not the copy command: a command runs programs on the server, so only whoever can edit `kareladb.conf` (or the server's start command) sets it.

**Command line: The default backup folder in the start-up lines**

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

<a id="daily-recipe"></a>

## Set a daily backup

Backups are on by default, but nothing makes one by itself until there is a schedule. Three steps:

1. Open **Settings > Backups** in the console, type `daily 16:30` as the schedule and press **Save**. Or send it with the token:

Syntax:

```sql
POST /api/settings   {"backup_schedule": "daily 16:30"}   ->  {"saved": true, "restart_required": true, ...}
```

2. The schedule is saved in `kareladb.conf` and used **from the next start**. Restart the server (the **Restart** button on the Settings page, or restart the service or container).
3. Check it: `GET /api/info` shows `"backup_schedule": {"schedule": "daily 16:30", "next_run_ms": ...}`, and the Settings page shows the schedule from `kareladb.conf`.

- In a container the time is UTC unless `kareladb serve --timezone` is set: `daily 16:30` is 22:15 in Nepal.
- Pick a time after the day's data is in. A backup does not stop reads or writes.
- Then set a [copy command](#backup-command), so a lost disk does not take the backups with it.

<a id="backup-schedule"></a>

## --backup-schedule

Syntax:

```sql
kareladb serve [--backups <dir>] --backup-schedule "daily 16:00" [--keep-daily 7] [--keep-weekly 4]
```

| Schedule | Meaning |
|---|---|
| `daily 16:00` | every day at 16:00 |
| `daily 02:00,14:00` | several times a day |
| `hourly`, `hourly :30` | every hour, at minute 0 (or 30) |
| `every 6h`, `every 30m` | counted from midnight, 5 minutes to 24 hours |
| `off` | no scheduled backups (the default) |

Times are the **local time of the computer**, or the zone of `kareladb serve --timezone` when it is set (in a zone without daylight saving, such as Nepal `+05:45`, `daily 16:00` is always the same hour; pick a time after your data for the day is in).

- **Returns:** the start-up lines show `schedule  backups daily 16:00, next 2026-09-12 16:00:00`. Each backup writes a line: `backup of 'market' OK: 12 files, 3.4 MB, 850 ms, ...` or `backup of 'market' FAILED: ...`.
- **Notes:**
  - Every database of the data folder and `_system` (users, audit log) are backed up into `<dir>/<name>`. Each backup is read back and checked before it counts.
  - Old backups are removed by `--keep-daily` and `--keep-weekly` (7 and 4).
  - Each backup is in the [audit log](audit-log.md) (`event = 'backup'`).

| Start error | Why |
|---|---|
| `a backup schedule needs a backup folder: add --backups <dir> (or KARELADB_BACKUP_DIR)` | a schedule with the folder `off` |
| `--backup-copy needs a backup schedule (the copy is made after each scheduled backup)` | a copy without a schedule |
| `the backup schedule (--backup-schedule): the backup interval must be from 5 minutes to 24 hours` | `every 1m` and the like |

These stop the start only when the flags themselves clash. When the folder
`off` comes from `kareladb.conf` or `KARELADB_BACKUP_DIR`, the server starts anyway with
`warning: backups are off ... starting without scheduled backups`, so the
console stays reachable to fix it. The Settings page refuses to save such a
clash: send `{"backup_dir": "off", "backup_schedule": "off"}` to turn both off.

**Command line: Backups every day at 16:00 local time**

```bash
kareladb serve --backups backups --backup-schedule "daily 16:00"
```

Output:

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      ./kdb-data (from KDB_DATA_DIR; one folder per database)
  default   default (used when a request names no database)
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
  schedule  backups daily 16:00, next 2026-10-23 16:00:00
  recovery  the default database is created when it is first used

Press Ctrl+C to stop.
```

**Command line: A schedule with backups turned off is refused**

```bash
kareladb serve --backups off --backup-schedule "daily 16:00"
```

Output:

```text
cold store 'archive': folder ./cold-archive
error: a backup schedule needs a backup folder: add --backups <dir> (or KARELADB_BACKUP_DIR)
```

exit code 1

<a id="backup-copy"></a>

## --backup-copy

Syntax:

```sql
kareladb serve --backups <dir> --backup-schedule "..." --backup-copy <dir on another disk>
```

After each scheduled backup, KarelaDB copies it to a second folder (another disk, a USB disk, a mounted network drive) and checks the copy there: every block checksum and every log checksum is read back from the copy. A backup on the same disk is lost with the disk.

- **Returns:** the log line says `copy checked: E:/kdb_copy/market/...` or `COPY FAILED: ...`.
- **Notes:** the copy keeps old backups by the same `--keep-daily` / `--keep-weekly`. For a cloud or another computer, use [--backup-command](#backup-command).

<a id="backup-command"></a>

## --backup-command

Syntax:

```sql
kareladb serve --backup-command "<command with {dir}, {database}, {name}>"
```

After **every** backup the server makes (the schedule, `BACKUP DATABASE`, **Backup now**, `POST /api/backup`), it runs this command to copy the backup off the server. KarelaDB has no cloud code of its own: the command is any tool you have installed and logged in (rclone, the AWS CLI, scp, robocopy).

| In the command | Becomes |
|---|---|
| `{dir}` | the new backup folder, full path |
| `{database}` | the database's name |
| `{name}` | the backup folder's own name, like `20260924-160000-123` |

- Each value is put in quotes for the shell. Without any placeholder the folder is added at the end.
- The command runs through `/bin/sh` (Linux, Docker) or `cmd.exe` (Windows). Exit code `0` is success.
- It never holds up the database: the backup is finished when the command starts. Commands run one at a time, in order; at most 100 wait.
- **Returns:** a line in the server log (`backup copy command for 'market' OK in 5200 ms: ...` or `FAILED (exit code 1) ... - <its last line>`), an event in the activity log, and `backup_command` in `/api/info` (below). The console shows `(copy failed)` next to **Last backup**.
- The tool must be inside the Docker image or on the host's `PATH`. Test the command by hand once.

Syntax:

```sql
rclone:   --backup-command "rclone copy {dir} remote:kdb/{database}/{name}"
AWS S3:   --backup-command "aws s3 cp --recursive {dir} s3://my-bucket/kdb/{database}/{name}"
scp:      --backup-command "scp -r {dir} backup@10.0.0.9:/srv/kareladb/{database}/"
Windows:  --backup-command "robocopy {dir} \\nas\kdb\{name} /E"
```

A copy made with `--backup-command` is a plain folder: to use it, copy it back and restore it ([kareladb restore](backup-and-safety.md#kareladb-restore), or put it in the backup folder and use [POST /api/restore](http-server-info.md#api-restore)).

**Command line: A command after each backup: here it only prints the folder**

```bash
kareladb serve --backup-command "echo copy {database} {name}"
```

Output:

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      ./kdb-data (from KDB_DATA_DIR; one folder per database)
  default   default (used when a request names no database)
  backups   ./kdb-data/_backups/<database name> (from default)
  copy      after each backup: echo copy {database} {name} (from --backup-command)
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

<a id="backup-warn-hours"></a>

## --backup-warn-hours

Syntax:

```sql
kareladb serve ... --backup-schedule "..." --backup-warn-hours 26        (0 = no warning)
```

Each database is checked on its own. When a database's newest good backup is older than this, the log says so once an hour, naming the database: `WARNING: the last good backup of 'sales' is 30 hours old ...`. `/api/info` and the console show the same warning.

- A database with no backup at all counts from when the server first saw it: `WARNING: database 'test_01' has no good backup yet (known for 27 hours) ...`. A database made after today's round is backed up by the next one, so it is not overdue before that.
- When several databases are overdue, the one waiting longest is named and the rest are counted: `... (and 12 more databases)`.
- The server reads the backup folders at start and every hour after, so a backup made by hand (`BACKUP DATABASE`) counts too. It never opens a database to do so.

<a id="backup-status"></a>

## Backup status in /api/info

Syntax:

```sql
GET /api/info  ->  "backup_schedule": {"schedule", "copy_to", "next_run_ms", "last_run_ms", "last_run_ok",
                                       "last_ok_ms", "running", "warning", "databases": [...]}
```

- **Returns:** `null` when there is no schedule. `databases` lists the last round: `database`, `ok`, `error`, `dir`, `files`, `bytes`, `started_ms`, `took_ms`, `copy_dir`, `copy_ok`, `copy_error`.
- `warning` is `""`, `the last good backup of 'x' is N hours old` or `database 'x' has no good backup yet (known for N hours)`, with `(and N more databases)` when several are overdue. `databases_overdue` is how many are.
- `last_ok_ms` is the newest good backup of the database whose newest backup is oldest (0 when a database has none).

Syntax:

```sql
GET /api/info  ->  "backup_command": {"set", "runs", "failed", "dropped", "queued", "running",
                                      "last": {"database", "dir", "ok", "exit_code", "output", "started_ms", "took_ms"}}
```

- `null` without a copy command. `output` is the end of what the command printed, shown to admins only (`""` for other users).
