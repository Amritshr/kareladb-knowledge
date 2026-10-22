# 1. Install KarelaDB

- Category: Tutorial

## What you will learn

- Three ways to get KarelaDB: an install package, the Docker image, or a build from the source.
- How to build KarelaDB on Windows, Linux and macOS.
- Where KarelaDB keeps your databases: the data folder and `KARELADB_DATA_DIR`.
- Where the web console, the help and the Claude skill come from: the folders `web/`, `help/` and `skill/`.
- What each program in `build/bin` does.
- How to run the tests.

## Three ways to get KarelaDB

| Way | Good for | Section |
|---|---|---|
| An install package (`.zip` for Windows, `.tar.gz` for Linux) | a PC or a server that only runs KarelaDB | [Install a package](#install-a-package) |
| The Docker image | a server that already runs Docker | [Run KarelaDB in Docker](#run-kareladb-in-docker) |
| Build from the source | working on KarelaDB itself, and this tutorial | [Build on Windows](#build-on-windows-msys2) |

## The program and its folders

KarelaDB is one program, `kareladb` (`kareladb.exe` on Windows). Nothing else is put inside it. The web console, the help pages and the Claude skill are plain files in folders **next to the program**:

```text
kareladb.exe          the program
kareladb.conf         settings (optional); the console's Settings page writes it
web\             the web console
help\            the help pages
skill\skill.md   the Claude skill: teaches an AI assistant in another project how to use KarelaDB
```

So a new console or a new help needs only the files copied, not a new program. `kareladb` looks for each folder in this order. The first one that has the folder's files wins:

| # | Where | Example |
|---|---|---|
| 1 | `web_dir`, `help_dir`, `skill_dir` in `kareladb.conf` | `"help_dir": "D:/kdb/help"` |
| 2 | The environment variables `KARELADB_WEB_DIR`, `KARELADB_HELP_DIR`, `KARELADB_SKILL_DIR` | `$env:KARELADB_HELP_DIR = "D:\kdb\help"` |
| 3 | `web`, `help`, `skill` next to the program | `C:\kdb\web` |
| 4 | `../share/kareladb/web`, `help`, `skill` (Linux: `/usr/local/bin` and `/usr/local/share/kareladb`) | `/usr/local/share/kareladb/web` |
| 5 | The source folders, when you run `build\bin\kareladb.exe` in a source checkout: `web\console`, `docs\help\site`, `.claude\skills\kareladb` | `D:\KarelaDB\web\console` |

A missing folder is not an error. The server still runs; the page says the console (or the help) is not installed, and where KarelaDB looked. The console's **Settings** page shows the folders in use.

## Install a package

A package holds the program, the `web`, `help` and `skill` folders, an installer and `kareladb.conf.example`. No source and no tests.

**Windows** (`kareladb-<version>-windows-x64.zip`): unpack it, open PowerShell in the folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

It copies `kareladb.exe` with its folders to `%LOCALAPPDATA%\Programs\kdb`, puts it on your `PATH` and writes the Claude skill. To remove KarelaDB, delete that folder.

**Linux** (`kareladb-<version>-linux-x64.tar.gz`, a static program that runs on any distribution):

```sh
./install.sh                   # just for you: ~/.local/bin and ~/.local/share/kareladb
sudo ./install.sh --system     # for everyone: /usr/local/bin and /usr/local/share/kareladb
sudo ./install.sh --system --service --token <your-token>   # and start it at boot (systemd)
```

To make the packages yourself from the source, see `packaging/README.md`.

## Run KarelaDB in Docker

The image is built from the source folder. It puts the program in `/usr/local/bin` and copies the `web`, `help` and `skill` folders into `/usr/local/share/kareladb/`. The help pages are copied only when they were built first (`node tools/help/build_help.mjs`, see the README of this tutorial); without them `/help` says the help is not installed.

```sh
docker build -t kareladb -f docker/Dockerfile .
docker run -d --name kareladb --restart unless-stopped --stop-timeout 60 \
  -p 9900:9900 -p 8832:8832 \
  -e KARELADB_TOKEN=<your-token> -e KARELADB_MEMORY=1536 \
  -v kdb-data:/data kareladb
```

| Setting | Meaning |
|---|---|
| `-p 9900:9900` | the HTTP API and the web console |
| `-p 8832:8832` | the PostgreSQL protocol (chapter 14) |
| `KARELADB_TOKEN` | the access token; send it as `Authorization: Bearer <token>`. **Required**: the container listens on all addresses, and KarelaDB never does that without a secret, so it stops at once when `KARELADB_TOKEN` is not set. |
| `KARELADB_MEMORY` | memory in MB for table data (`--memory`; 256 when not set) |
| `-v kdb-data:/data` | the data folder. It lives outside the container, so a new image does not lose it. `kareladb.conf` is kept there too. |
| `--stop-timeout 60` | lets KarelaDB stop cleanly. Without it, Docker may kill KarelaDB after a few seconds, and the next start replays the log. |
| `--restart unless-stopped` | starts KarelaDB again after a restart of Docker or the computer |

To update: build the image again, then `docker stop kareladb`, `docker rm kareladb` and the same `docker run`. The data stays in the volume. Stop the container before you remove it: `docker rm -f` kills KarelaDB at once.

`docker exec kareladb kareladb skill > SKILL.md` saves the Claude skill from the running container.

## Build from the source

### What you need

| Tool | Version | Why |
|---|---|---|
| CMake | 3.16 or newer | Makes the build files |
| Ninja | any | Runs the build fast |
| C++ compiler | C++17 (GCC, Clang or MSVC) | Compiles KarelaDB |

KarelaDB needs **no other libraries**. The build makes only the program. The console, the help and the skill stay as files in the source folder, and `build\bin\kareladb.exe` finds them there (row 5 of the table above).

## Build on Windows (MSYS2)

1. Install MSYS2 from <https://www.msys2.org/>.
2. Open the **MSYS2 UCRT64** terminal. Install the tools:

   ```sh
   pacman -S mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-ninja
   ```

3. Add `C:\msys64\ucrt64\bin` to your Windows `PATH`. Then the tools work in PowerShell too.
4. Open PowerShell in the KarelaDB folder and build:

   ```powershell
   cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
   cmake --build build
   ```

The programs are in `build\bin\`. They are linked statically. You can copy `kareladb.exe` to another Windows PC. It needs no DLL files. For the web console and the help on that PC, copy the folders too (`web\console` as `web`, `docs\help\site` as `help`, `.claude\skills\kareladb` as `skill`), or make a package (`packaging/README.md`), which does this for you.

To build only the `kareladb` program (faster):

```powershell
cmake --build build --target kareladb
```

## Build on Linux

Ubuntu or Debian:

```sh
sudo apt install cmake ninja-build g++
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

The programs are in `build/bin/` (no `.exe` at the end).

## Build on macOS

```sh
xcode-select --install
brew install cmake ninja
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

## Check the build

```powershell
.\build\bin\kareladb.exe version
```

```text
kareladb 0.2.0-dev (crc32c hardware: yes)

Stored-format features this build reads (26):
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
  batched_log_sync     0.2.0-dev (2026-09-11)   --sync-commits batch: log segments with 16-byte commit records
  dedup_change         0.2.0-dev (2026-09-12)   ALTER TABLE ... DEDUP ENABLE / DISABLE: the DEDUP KEY of a table that already holds rows
  plpgsql_triggers     0.2.0-dev (2026-09-12)   PostgreSQL plpgsql trigger functions and FOR EACH ROW triggers in the "routines" file
  cached_views         0.2.0-dev (2026-09-13)   CREATE CACHED VIEW: which views are cached, and REFRESH ON COMMIT, in the "views" file
  deferred_triggers    0.2.0-dev (2026-09-13)   CREATE TRIGGER ... DEFERRED: job records in the log, and the "trigger_queue" and "q/<job>" files of queued jobs
  materialized_views   0.2.0-dev (2026-09-13)   CREATE MATERIALIZED VIEW: catalog part 'M', REFRESH MATERIALIZED VIEW log records, mv_dirty.<id> in the manifest
  table_ttl            0.2.0-dev (2026-09-13)   TTL n DAYS on a table: catalog part 'L'

A database that uses a feature not in this list needs a newer KarelaDB (kareladb check exits with 3).
```

`crc32c hardware: yes` means your CPU can compute checksums fast. `no` also works, only slower.
The list under it is the **stored-format feature list**: everything this build can read from disk. Chapter 24 explains it.

Run `kareladb` with no command to see all commands:

```powershell
kareladb
"exit code: $LASTEXITCODE"
```

```text
kareladb 0.2.0-dev

Usage:
  kareladb info    <db>                               show files, versions and log position
  kareladb check   <db>                               read every block and log record, report damage
  kareladb repair  <db> [--backups <dir>] [--accept-log-loss]
                                                 fix damaged files from old versions or backups
  kareladb backup  <db> <backups-dir> [--hard-links] [--keep-daily N] [--keep-weekly N]
  kareladb backups <backups-dir>                      list backups, newest first
  kareladb verify-backup <backup-dir>
  kareladb restore <backup-dir> <new-data-dir> [--logs-from <old-data-dir>] [--until "YYYY-MM-DD HH:MM[:SS]"]
  kareladb dump-file <file.kdb>                       header and block checksums of one file
  kareladb serve   [<db>] [--db <name>] [--port 9900] [--bind 127.0.0.1] [--backups <dir>] [--token <t>] [--memory <MB>]
              [--sync-commits always|batch] [--threads N]  HTTP API, line protocol (POST /write) and web console
              [--pg-port 8832] [--pg-timestamptz] PostgreSQL protocol for Postgres drivers and tools (0 = off)
                                                 (Ctrl+C stops). Without <db>: every database in the data folder
  kareladb shell   [<db>] [--backups <dir>] [--memory <MB>]  interactive SQL prompt (end statements with ;)
  kareladb sql     <db> "SQL" [--format table|csv|json] [--max-rows N]
                                                 run SQL and print results (use - to read SQL from stdin)
  kareladb user add <name> [--role admin|write|read]  add a server user; the password is asked for (or read
                                                 from a pipe), never given on the command line
  kareladb user passwd <name>                         set a new password
  kareladb user role <name> admin|write|read|none     change the role
  kareladb user list                                  users and roles (never passwords)
  kareladb user remove <name>
  kareladb user reset-2fa <name>                      turn two-factor login off (a lost phone)
                                                 (kareladb user works on the data folder while kareladb serve is stopped;
                                                 while it runs, use CREATE USER ... in its console)
  kareladb version [<db>]                             this build and the stored-format features it reads;
                                                 with <db>: the features that database uses
  kareladb upgrade <db> [--backups <dir>]             verified backup, then save the database's feature list, then check
  kareladb help [<topic> | tutorial [<chapter>]]     the help topics (and, in a source checkout, the tutorial)
                                                 in the terminal; without a topic: the list of topics
  kareladb skill [install] [--dir <d>] [--url <u>] [--token <t>] [--home <checkout>]
                                                 print, or install into ~/.claude/skills/kareladb, the file that
                                                 teaches an AI assistant in another project how to use KarelaDB

<db>: a database name in the data folder (market), or the path of a database folder (D:\kdb\market, ./market).
Data folder: --data-dir <folder>, else kareladb.conf, else the KARELADB_DATA_DIR environment variable,
  else "data" next to kareladb.
--config <file>: settings the console's Settings page may change (default: kareladb.conf next to kareladb).
  It holds data_dir and wal_archive_mb; a --data-dir on the command line always wins over it. It may also
  name web_dir, help_dir and skill_dir: the folders of the console, the help and the Claude skill
  (else KARELADB_WEB_DIR, KARELADB_HELP_DIR, KARELADB_SKILL_DIR, else web/, help/ and skill/ next to kareladb).
--memory <MB>: memory for table data kept loaded (default 512). More is faster on big tables.
--threads <N>: threads for big queries and writes (default and most: half of the CPU threads).
--cache-mb <MB>: memory for results of repeated queries (default 64, 0 = off). A result is used
  again only while no table it read has changed; queries with now() or random() are never kept.
--reader-yield on|off: readers do not wait for a long trigger or CALL; they read the last
  committed rows (default off; env KARELADB_READER_YIELD).
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
  --trash-days N               DROP TABLE keeps the table N days for UNDROP TABLE (default 7; also sql, shell)
  --audit on|off               audit log of logins, users, DDL, backups in _system (default on)
  --audit-keep-days N          remove audit rows older than N days (default 0 = keep forever)
  --activity-log-size N        recent events for the console's activity panel, in memory (default 5000, 0 = off)
  --drain-timeout 30s          on stop, running requests may finish this long; new ones get 503 (default 30s)
  --backup-schedule "daily 16:00"  verified backups of every database (local time; needs --backups)
  --backup-copy <dir>          a second, checked copy of each scheduled backup (another disk)
  --backup-warn-hours N        warn in the log when the last good backup is older (default 26)
  --keep-daily N --keep-weekly N   backups kept (default 7 and 4)
Exit codes: 0 OK, 1 error, 2 damage found, 3 the database needs a newer KarelaDB (nothing was changed).
exit code: 1
```

## Where your data lives

A **database** is a folder. KarelaDB keeps many databases in one **data folder**, one sub-folder for each database:

```text
D:\KarelaDB\build\bin\kareladb.exe
D:\KarelaDB\build\bin\data\              <- the data folder
D:\KarelaDB\build\bin\data\market\        <- the database "market"
D:\KarelaDB\build\bin\data\demo\         <- the database "demo"
D:\KarelaDB\build\bin\data\_trash\       <- dropped databases (KarelaDB never deletes them)
```

Each database has its own tables, views, triggers and procedures.

KarelaDB looks for the data folder in this order. The first one that is set wins:

| # | Where | Example |
|---|---|---|
| 1 | The option `--data-dir <folder>` | `kareladb serve --data-dir E:\kdb-data` |
| 2 | `data_dir` in `kareladb.conf` (next to the program, or the file named by `--config`). The console's **Settings** page writes it. | `"data_dir": "E:/kdb-data"` |
| 3 | The environment variable `KARELADB_DATA_DIR` | `$env:KARELADB_DATA_DIR = "E:\kdb-data"` |
| 4 | The folder `data` next to the `kareladb` program | `D:\KarelaDB\build\bin\data` |

KarelaDB creates the folder when it is missing. Use `KARELADB_DATA_DIR` when the data must be on another disk, or when `kareladb.exe` is in a folder where you cannot write (like `C:\Program Files`).

To set `KARELADB_DATA_DIR` for good on Windows (then open a new PowerShell window):

```powershell
[Environment]::SetEnvironmentVariable("KARELADB_DATA_DIR", "E:\kdb-data", "User")
```

On Linux and macOS, add `export KARELADB_DATA_DIR=/srv/kdb-data` to `~/.bashrc` (or `~/.zshrc`).

Database names: letters, digits, `_` and `-`, 1 to 64 characters. `Market` and `market` are the same database.

An example. Here the data folder is `kdb-data` in the current folder. `kareladb shell` without a database name opens the database `default`:

```powershell
$env:KARELADB_DATA_DIR = "kdb-data"
"CREATE DATABASE market; CREATE DATABASE demo; SHOW DATABASES;" | kareladb shell
Get-ChildItem kdb-data -Name
```

```text
KarelaDB 0.2.0-dev shell on default (data folder kdb-data)
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> database 'market' created

database 'demo' created

name    | tables | bytes | current
--------+--------+-------+--------
default |      0 |     0 | true
demo    |      0 |     0 | false
market  |      0 |     0 | false
(3 rows, 0.1 ms)
kareladb>
default
demo
market
```

Every command also still takes a **folder path**, like in the rest of this tutorial: `kareladb sql market "..."` uses the folder `market` in the current folder, as long as the data folder has no database called `market`. [Chapter 7](07-command-line-and-scripts.md#database-names-and-folder-paths) explains names and paths.
## What the programs are

| Program | What it is |
|---|---|
| `kareladb` | The main program. It runs SQL, the shell, the server, backups and repairs. You need only this one. |
| `test_env`, `test_crc32c`, `test_block_file`, `test_wal`, `test_manifest`, `test_store`, `test_backup`, `test_disk_full` | Tests for the storage layer. Each tests one part. |
| `test_sql_parser`, `test_catalog`, `test_database`, `test_tables`, `test_select`, `test_indexes`, `test_procedures`, `test_mviews`, ... | Tests for SQL, tables, queries, indexes, procedures and views. |
| `test_table_locks`, `test_txn_readers`, `test_accounting` | Tests for many writers and readers at the same time, and for transactions. |
| `test_manager`, `test_cross_database` | Tests for many databases: names, the data folder, CREATE/DROP DATABASE, the trash folder, queries over two databases. |
| `test_server`, `test_pg`, `test_pg_dml`, `test_users`, `test_protection` | Tests for the HTTP server, the PostgreSQL protocol, users and the protection limits. |
| `powercut_test [n]` | Cuts the "power" at a random moment, `n` times (default 300). Every committed change must still be there. |
| `corrupt_test [n]` | Damages a random file, `n` times (default 1000). KarelaDB must repair it or refuse clearly. It must never return wrong data. |
| `crash_test [n]` | Kills a real writer process at a random moment, `n` times (default 200). |
| `fuzz_test`, `stress_test`, `test_text_fuzz` | Random SQL and random load, to find crashes. |
| `kdb_bench` | Speed tests. See `bench/README.md`. |

## Run the tests

Each test is a separate program. Exit code `0` means it passed. Tests write temporary files into the folder in `KDB_TEST_TMP` (default: `.\kdb_test_tmp`).

```powershell
$env:KDB_TEST_TMP = "D:\kdb_test_tmp"
.\build\bin\test_crc32c.exe
.\build\bin\test_sql_parser.exe
.\build\bin\test_tables.exe
.\build\bin\test_select.exe
"exit code: $LASTEXITCODE"
```

```text
crc32c hardware: yes
PASS test_crc32c
PASS test_sql_parser
bulk: 12272 rows after 20,000 upserts and range deletes
checkpoints on threads: same files as on one thread
idle checkpoint: written after writes stopped
runs: 16094 rows after 160 random steps, both engines equal to the model
row builders: same rows and messages as InsertRows
PASS test_tables
warning: D:\kdb_test_tmp/select/db: the table data of this database is 0 MB, 154869 times the memory budget of 0 MB (--memory). Expect queries over much of it, and writes into old partitions, to read files again and again and to take seconds. Give KarelaDB more memory: --memory 0 or more (KARELADB_MEMORY in Docker)
warning: D:\kdb_test_tmp/select/db: the table data of this database is 0 MB, 153700 times the memory budget of 0 MB (--memory). Expect queries over much of it, and writes into old partitions, to read files again and again and to take seconds. Give KarelaDB more memory: --memory 0 or more (KARELADB_MEMORY in Docker)
PASS test_select
exit code: 0
```

The two warnings of `test_select` are on purpose. The test opens a database with a memory budget of 1 byte, to check that queries give the same rows when KarelaDB must read the files again and again. A real server prints the same warning once, when it opens a database whose data is more than 8 times its memory budget (`--memory`).

To run all tests:

```powershell
ctest --test-dir build --output-on-failure
```

There are 56 tests. This takes a long time, because `powercut_test`, `corrupt_test`, `crash_test`, `fuzz_test` and `stress_test` repeat many times (`corrupt_test` alone takes about half an hour). Most others take a few seconds. Run the tests for the part you changed first; run them all before a release. When all pass, the last lines are:

```text
100% tests passed, 0 tests failed out of 56
```

Use a smaller `n` for a quick check:

```powershell
.\build\bin\corrupt_test.exe 50
```

On Linux and macOS:

```sh
export KDB_TEST_TMP=/tmp/kdb_test
./build/bin/test_select
ctest --test-dir build --output-on-failure
```

## Phones (iOS and Android)

For iOS and Android, CMake turns off the `kareladb` program and the tests. Only the library is built. This tutorial is about the `kareladb` program, so it does not cover phones.

## Try it yourself

1. Build only the `kareladb` program again, and check the version it prints.
2. Run `test_catalog` and check the exit code.
3. Run `crash_test` with only 5 rounds.

<details>
<summary>Answers</summary>

1. ```powershell
   cmake --build build --target kareladb
   .\build\bin\kareladb.exe version
   ```
2. ```powershell
   .\build\bin\test_catalog.exe
   $LASTEXITCODE    # 0 = passed
   ```
3. ```powershell
   .\build\bin\crash_test.exe 5
   ```

</details>

---

Next: [2. Your first database](02-first-database.md)
