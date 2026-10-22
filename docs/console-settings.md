# Settings page (data folder, old log, capacity, program files and users)

> Where the server keeps its data, how to point it at another folder, and who may log in - all from the console.

- Category: Web console
- Keywords: settings, settings page, data folder, move data, change data folder, kareladb.conf, config file, --config, restart, restart server, add user, change password, remove user, grants, roles, free space, disk space, wal\_archive, wal\_archive\_mb, KARELADB\_WAL\_ARCHIVE\_MB, old log, cache\_mb, KARELADB\_CACHE\_MB, result cache size, program files, web\_dir, help\_dir, skill\_dir, KARELADB\_WEB\_DIR, KARELADB\_HELP\_DIR, KARELADB\_SKILL\_DIR, command line, Docker, KARELADB\_DATA\_DIR, capacity, http\_threads, max\_connections, lock\_timeout\_ms, idle\_in\_transaction\_timeout\_ms, rate\_limit\_ip, rate\_limit\_user, timer\_workers, http\_functions, KARELADB\_HTTP\_FUNCTIONS
- See also: [Web console](web-console.md), [Monitor panel (memory, processor, caches)](console-monitor.md), [View data page (browse and edit rows)](console-data-page.md), [Users and roles](users-and-roles.md), [kareladb user](cli-users.md), [kareladb serve](cli-serve.md), [Databases and the data folder](databases.md), [Keeping kareladb serve safe](server-security.md), [Install packages and the Claude skill](install-packages.md), [Health, info, check and backup over HTTP](http-server-info.md)

The **Settings** page of the [web console](web-console.md) has these parts: **Storage** (where the databases live), **Old log kept per database** (the `wal_archive` size), **Result cache** (`cache_mb`), **Backups**, **Calls from SQL** (`http_functions`), **Capacity and waits** (HTTP threads, PostgreSQL connections, the lock timeout, the drain time), **Program files** (the folders of the console, the help and the Claude skill) and **Users** (who may log in). Only a user whose own `ROLE` is `admin` may open it; everybody else sees a line saying so.

<a id="storage"></a>

## Storage

The top of the page shows the **data folder** in use, and a badge saying where that choice came from. Under it: how many databases are in it, how much they use, and how much room is left on that disk.

Where the data folder comes from, strongest first:

| Source | Badge | Set by |
|---|---|---|
| `--data-dir <folder>` | `--data-dir on the command line` | the command that started the server |
| `kareladb.conf` | `this Settings page (kareladb.conf)` | **Save** on this page |
| `KARELADB_DATA_DIR` | `the KARELADB_DATA_DIR environment variable` | the environment |
| the default | `program folder` | `data` next to `kareladb` |

**A flag always wins.** When the server was started with `--data-dir`, the page says so in a yellow banner: a folder saved here will only be used once the server is started without that flag. This is worth reading before pressing anything - it is the difference between a setting that works and one that quietly does nothing.

**How this server was started** folds open to show the settings file (`config_path`) and the whole command line (`command_line`), as [GET /api/settings](http-server-info.md#api-settings) gives them.

**In Docker** the image passes the data folder as the environment variable `KARELADB_DATA_DIR=/data`, not as `--data-dir`, on purpose: a flag would always win, and this page could then never change the folder. The image also keeps `kareladb.conf` in the volume (`--config /data/kareladb.conf`), so a setting saved here survives a new image and a new container. A folder you choose here must be under a mounted volume too; anywhere else is inside the container and is lost with it ([Docker](install-packages.md#docker)).

<a id="change"></a>

### Changing the folder

Type a folder and press **Save**. Before anything is written, the server:

1. makes the folder if it is not there,
2. writes a small file in it and removes it again, to be sure it can write there,
3. refuses a folder that is itself **one database** (it holds a `_manifest.a`) - the data folder is the one **above** those, the one with a folder per database.

Only then is the folder written to `kareladb.conf`. A folder that fails any of those checks is refused with the reason, and the file is not touched.

```json
{"data_dir":"E:/kdb-data"}
```

**Nothing is copied.** The databases in the old folder stay exactly where they are; the server simply looks somewhere else from the next start. To take them along:

1. Save the new folder here.
2. Stop the server.
3. Move the database folders yourself.
4. Start it again.

<a id="restart"></a>

### Restart

**Restart the server** closes every database cleanly and starts again **in the same process**. No service manager, Docker restart policy or supervisor is needed, and the server keeps the same port, so the console reconnects by itself after a few seconds.

- Statements that are running are stopped and open transactions are rolled back, exactly as at a normal shutdown.
- The server prints `restarting...`, then `databases closed cleanly (N ms)`, then its usual banner.
- Restarting is written to the [audit log](audit-log.md).

If the saved folder cannot be used when the server starts again - an unplugged disk, a renamed share - the server does **not** refuse to boot. It prints a warning and starts on the usual folder instead, so there is always a console to fix the setting in:

```text
warning: the data folder saved in 'C:/kdb/kareladb.conf' cannot be used: cannot make the folder 'Z:/gone'
         starting with the usual folder instead. Fix it on the Settings page.
```

<a id="read-only"></a>

### When it cannot be changed here

The page shows the folder without a **Save** button when the settings file cannot be written - a read-only program folder, for instance, as in some container images. It then says why, and the folder is set with `--data-dir` or `KARELADB_DATA_DIR` as before. `--config <file>` puts the settings file somewhere writable:

```bash
kareladb serve --config /var/lib/kdb/kareladb.conf
```

A server started on **one database folder** (`kareladb serve D:\kdb\market`) has no data folder to change, so Storage is read-only there too.

<a id="wal-archive"></a>

## Old log kept per database

Each database keeps old log files in its `wal_archive` folder. They are only used to repair a damaged file and by backups; the data does not need them. This part of the page sets how much each database keeps: a size in MB, or **Off**.

| Where the value comes from, strongest first | Shown as |
|---|---|
| `wal_archive_mb` in `kareladb.conf` (**Save** here) | `this page (kareladb.conf)` |
| the environment variable `KARELADB_WAL_ARCHIVE_MB` | `KARELADB_WAL_ARCHIVE_MB` |
| the default | `the default (1 GB)` |

- **Save** works at once, with no restart. A smaller size removes the oldest files of every open database now.
- **Off** keeps no old log. A damaged file can then only be repaired from a backup.
- A database with its own setting keeps it: [`ALTER DATABASE ... SET WAL_ARCHIVE`](databases.md#wal-archive), or **Old log** in the console's **Databases** panel. There you can also pick **Server default** again.

```json
{"data_dir":"E:/kdb-data","wal_archive_mb":100}
```

<a id="result-cache"></a>

## Result cache

The [result cache](performance-tips.md#result-cache) keeps the results of repeated `SELECT`s in memory. This part of the page sets its size for all databases together, in MB; `0` turns it off.

| Where the value comes from, strongest first | Shown as |
|---|---|
| `--cache-mb` on the command line (the page cannot change it then) | `--cache-mb` |
| `cache_mb` in `kareladb.conf` (**Save** here) | `this page (kareladb.conf)` |
| the environment variable `KARELADB_CACHE_MB` | `KARELADB_CACHE_MB` |
| the default | `the default (256 MB)` |

- **Save** works at once, with no restart. A smaller size drops the oldest results now.
- One result may use a quarter of the space, a [pinned](pinned-queries.md) one three quarters.
- A database with a space of its own keeps it: [`ALTER DATABASE ... SET RESULT_CACHE`](databases.md#result-cache).

<a id="backups"></a>

## Backups

The backup folder, the schedule, how many backups are kept, and the command that copies each backup off the server. Each line says where its value came from: a flag, this page (`kareladb.conf`), the environment or the default ([where the settings come from](backup-schedule.md#backup-settings)).

| Line | What it is |
|---|---|
| **Folder** | where backups go; `_backups` in the data folder by default |
| **Schedule** | when the server makes backups by itself (`daily 02:00`, `every 6h`, `off`) |
| **Kept** | the newest backup of each of the last N days and weeks |
| **Copy off the server** | the [backup command](backup-schedule.md#backup-command), or `none` with a warning: backups on the same disk are lost with it |

- **Save** writes the schedule and the two counts to `kareladb.conf`. They are used from the next start: use **Restart** under Storage.
- The folder and the copy command are shown, not edited. A command runs programs on the server, so it is set in `kareladb.conf` by hand, with `--backup-command` or `KARELADB_BACKUP_COMMAND`.
- Keep enough old log (above) to cover the time between two backups, or a restore to a moment in between is not possible ([the window](backup-and-safety.md#pitr-window)).

```json
{"data_dir":"/data","backup_schedule":"daily 02:00","backup_keep_daily":14,"backup_command":"aws s3 cp --recursive {dir} s3://my-bucket/kdb/{database}/{name}"}
```

<a id="http-functions"></a>

## Calls from SQL

Which hosts [`http_get` and `http_post`](http-functions.md) may call, and how long one call may take.

- Type the hosts separated by commas (`api.example.com, 10.0.0.5:8080`), or `off`.
- **Save** writes `http_functions` and `http_timeout_ms` to `kareladb.conf`. They apply at once, no restart.
- **Set by** says where the list came from: this page (`kareladb.conf`), `KARELADB_HTTP_FUNCTIONS`, or the default (off).

<a id="capacity"></a>

## Capacity and waits

What the server was started with, and where each value came from. It is read-only: the server reads these when it starts, so a change needs a restart.

| Line | Setting | Set with, strongest first |
|---|---|---|
| **HTTP requests at once** | `http_threads` | `--http-threads`, then `kareladb.conf`, then `KARELADB_HTTP_THREADS`, then the CPU threads (at least 8) |
| **PostgreSQL connections** | `max_connections` | `--max-connections`, then `kareladb.conf`, then `KARELADB_MAX_CONNECTIONS`, then 500 |
| **Wait for a busy table** | `lock_timeout_ms` | `--lock-timeout`, then `kareladb.conf`, then `KARELADB_LOCK_TIMEOUT`, then 5 s. A session changes its own with [`SET lock_timeout`](transactions.md#lock-timeout). |
| **Idle open transaction rolled back after** | `idle_in_transaction_timeout_ms` | `--idle-in-transaction-timeout`, then `kareladb.conf`, then `KARELADB_IDLE_IN_TRANSACTION_TIMEOUT`, then 30 s. A session: [`SET idle_in_transaction_session_timeout`](transactions.md#idle-timeout). |
| **Time to finish on stop** | `--drain-timeout` | `--drain-timeout`, then `KARELADB_DRAIN_TIMEOUT`, then 30 s ([stopping](cli-serve.md#stop)) |
| **Requests per second per address** | `rate_limit_ip` | `--rate-limit-ip`, then `kareladb.conf`, then `KARELADB_RATE_LIMIT_IP`, then no limit ([rate limits](protection.md#rate-limits)) |
| **Requests per second per user** | `rate_limit_user` | `--rate-limit-user`, then `kareladb.conf`, then `KARELADB_RATE_LIMIT_USER`, then no limit |
| **Timers running at once** | `timer_workers` | `--timer-workers`, then `kareladb.conf`, then `KARELADB_TIMER_WORKERS`, then 3 ([timers](timers.md)) |
| **TCP keepalive: idle before the first probe**, **between probes**, **probes before giving up** | `tcp_keepalives_idle`, `tcp_keepalives_interval`, `tcp_keepalives_count` | `--tcp-keepalives-*`, then `kareladb.conf`, then `KARELADB_TCP_KEEPALIVES_*`, then the system's. A Postgres session: [`SET tcp_keepalives_idle`](server-activity.md#idle-clients). |

To change one, write its key into `kareladb.conf` by hand and press **Restart** under Storage; a flag or an environment variable changes only when the server is started again. Every option of the server, with its flag, variable and key, is in [every option](cli-serve.md#all-options).

```json
{"data_dir":"E:/kdb-data","http_threads":32,"max_connections":300,"lock_timeout_ms":20000}
```

<a id="program-files"></a>

## Program files

The web console, the help pages and the Claude skill are folders of plain files next to the kareladb program, not part of it. This part shows which folder the server uses for each, and what chose it. It is read-only.

| Line | Folder | Chosen by, strongest first |
|---|---|---|
| **Web console** | `web_dir` | `kareladb.conf` `"web_dir"`, then `KARELADB_WEB_DIR`, then `web/` next to the program, then `share/kareladb/web` beside the program folder, then a source checkout |
| **Help pages** | `help_dir` | the same, with `"help_dir"`, `KARELADB_HELP_DIR` and `help/` |
| **Claude skill** | `skill_dir` | the same, with `"skill_dir"`, `KARELADB_SKILL_DIR` and `skill/` |

- After each folder the page says where it came from: `from kareladb.conf`, `from KARELADB_WEB_DIR`, `next to the program`, `in share/kareladb beside the program folder` or `from the source checkout`. `not found` means none of the places had the files.
- To use other folders, write them into `kareladb.conf` by hand, or set the environment variables, and restart the server. More: [where kareladb finds the console, the help and the skill](install-packages.md#folders).

```json
{"data_dir":"E:/kdb-data","web_dir":"E:/kdb/web","help_dir":"E:/kdb/help","skill_dir":"E:/kdb/skill"}
```

<a id="users"></a>

## Users

The same users as [`CREATE USER`](users-and-roles.md) and [`kareladb user`](cli-users.md) - this page just sends that SQL for you.

| Button | What it sends |
|---|---|
| **Add a user** | `CREATE USER name WITH PASSWORD '...' ROLE read` |
| **Change** | `ALTER USER name WITH PASSWORD '...' ROLE write` (only the parts you filled in) |
| **Grants** | `GRANT write ON DATABASE shop TO name`, or `REVOKE ALL ON DATABASE shop FROM name` |
| **Remove** | `DROP USER name` |

On a server with no users yet, the page says so and offers **Add the first user**. That first user must have `ROLE admin`, so the role box is fixed. **As soon as that user exists, every request needs a login** - the console notices at once and shows its login form, so have the password ready.

The rules the server enforces, which the page simply reports:

- A password must be at least 12 characters and must not be the user name.
- `Bob` and `bob` are the same user.
- The last user with `ROLE admin` cannot be removed or made weaker while other users exist.
- A new password ends that user's open logins at once.

Roles, and what each one may do, are in [users and roles](users-and-roles.md). Keeping a server reachable from outside safe is in [server security](server-security.md).
