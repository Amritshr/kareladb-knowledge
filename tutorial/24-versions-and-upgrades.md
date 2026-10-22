# 24. Versions and upgrades

- Category: Tutorial

## What you will learn

KarelaDB gets new features all the time. Some of them change what KarelaDB writes on disk. This chapter explains what happens to your data when you update KarelaDB, and when you go back to an older KarelaDB:

- **Part A.** The rule: a new KarelaDB opens old data; an old KarelaDB refuses new data.
- **Part B.** `kareladb version` and `SHOW VERSION`: which features a database uses.
- **Part C.** A database from an older KarelaDB, and `kareladb upgrade`.
- **Part D.** What an older KarelaDB says, and what to do.
- **Part E.** How to update the KarelaDB programs on a server.

All examples are in examples/24-versions-and-upgrades/. The output under each example is real. The examples use the database `market` with the sample data.

## The short version

- Update **every** `kareladb` program (server, scripts, tools) at the same time, to the same build.
- A newer KarelaDB opens your old databases as they are. There is nothing to convert.
- Before you update a server, make a backup (you do that every day anyway, chapter 9). `kareladb upgrade <db>` does backup + feature list + check in one command, when you want it.
- If a `kareladb` command says `this database needs a newer KarelaDB` (exit code `3`): the data is **not damaged**. Use the newer KarelaDB. Do **not** run `kareladb repair` or `kareladb restore`.

---

## Part A: the rule

Each database keeps a **feature list** in its manifest (the file that lists the database's files, chapter 9). A feature is one change to what KarelaDB writes on disk. For example:

| Feature | The database has |
|---|---|
| `json` | a `JSON` column |
| `indexes` | a `CREATE INDEX` |
| `sequences` | a `CREATE SEQUENCE` |
| `audit` | a table with `SET AUDIT ON` |
| `runs` | rows written by the line protocol in the fast column form |
| `deferred_triggers` | a trigger made with `DEFERRED` (chapter 13) |
| `table_ttl` | a table with `TTL n DAYS` |

KarelaDB puts a feature into the list **before** it writes the first data that needs it. When a database opens, KarelaDB reads the list **first**, before it reads or changes anything else:

- Every name is known: the database opens.
- A name is not known: a newer KarelaDB wrote this database. KarelaDB stops with `this database needs a newer KarelaDB: it uses <name>` and changes nothing.

The same message comes for the other things only a newer KarelaDB writes: a newer file format number, a log record or catalog part KarelaDB does not know. KarelaDB never calls such data "damaged", and it never starts a repair.

Only schema statements (`CREATE`, `ALTER`, `DROP`), the first use of a feature and checkpoints look at the list. Writing rows costs nothing extra: the write benchmark gave the same numbers before and after (see the report `reports/versioning.md`).

## Part B: which features does a database use?

### kareladb version

Without a database, `kareladb version` shows this KarelaDB and every feature it can read:

```powershell
kareladb version
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

With a database, it shows the database's list. It reads only the manifest, so it also works while a server has the database open:

```powershell
kareladb version market
```

```text
kareladb 0.2.0-dev (crc32c hardware: yes)
database market
feature list (3):
  batched_log_sync     --sync-commits batch: log segments with 16-byte commit records
  block_stats          column stats section in partition files (count, min, max, sum per column)
  partition_format_2   table partition files in format 2 (one raw block per column)
```

The sample data has plain tables only, so its list is short. `batched_log_sync` is in every list today: writers that commit at the same moment share one wait for the disk (group commit, chapter 15), and the log keeps them in the same form as `--sync-commits batch`. Each commit is still on the disk before it is confirmed. So every database this build writes uses `batched_log_sync`, and a KarelaDB built before 2026-09-11 cannot open it.

### SHOW VERSION

In SQL (`kareladb sql`, `kareladb shell`, the web console, the PostgreSQL port), `SHOW VERSION` shows the same for the current database:

```sql
SHOW VERSION;
```

```text
item                    | value                                           
------------------------+-------------------------------------------------
kareladb version             | 0.2.0-dev                                       
database                | market                                          
features used           | batched_log_sync, block_stats, partition_form...
feature list            | saved: batched_log_sync, block_stats, partiti...
features this KarelaDB reads | 26: views, partition_format_2, block_stats, r...
(5 rows, 0.1 ms)
```

- `features used`: what the database uses right now.
- `feature list`: what is saved in the manifest. Normally the same.

## Part C: a database from an older KarelaDB

Databases made by KarelaDB programs **before 2026-09-12** have no feature list. KarelaDB opens them exactly as before. It works out their list from the tables, files and log, and saves it at the next checkpoint (for example when the database is closed).

The KarelaDB source has small databases made by the older programs, for the tests (`tests/fixtures`). This one was made by the `kareladb.exe` of 2026-09-11:

```powershell
# A database written by an older KarelaDB (2026-09-11, before feature lists)
Copy-Item "$env:KDB_EXAMPLES\..\..\..\tests\fixtures\sep11_clean" old-db -Recurse
kareladb version old-db
```

```text
kareladb 0.2.0-dev (crc32c hardware: yes)
database old-db
feature list: not saved yet (the database was written by a KarelaDB before feature lists).
It is saved at the next checkpoint of this KarelaDB, or now with: kareladb upgrade old-db
SHOW VERSION in kareladb sql or kareladb shell shows the features it uses.
```

### kareladb upgrade

`kareladb upgrade` does three things: a verified backup, then it saves the feature list, then `kareladb check`. The database must be closed (stop the server first).

```powershell
kareladb upgrade old-db --backups upgrade-backups
"exit code: $LASTEXITCODE"
kareladb version old-db
kareladb sql old-db "SELECT count(*) AS candles FROM ochl; SHOW VERSION"
```

```text
KarelaDB 0.2.0-dev, database old-db
saved feature list: none (written by a KarelaDB before feature lists)
1/3 verified backup into upgrade-backups ...
    upgrade-backups/20260923-121111-373 (7 files, 10.5 KB)
2/3 saving the feature list ...
    features used: batched_log_sync, block_stats, partition_format_2, views
    (no files need to be written again for this KarelaDB version)
3/3 check ...
checked 9 files (12.3 KB) and 2 log segments
OK: no damage found

Upgrade done. An older KarelaDB build that does not know one of these features now refuses this database with "needs a newer KarelaDB".
exit code: 0
kareladb 0.2.0-dev (crc32c hardware: yes)
database old-db
feature list (4):
  batched_log_sync     --sync-commits batch: log segments with 16-byte commit records
  block_stats          column stats section in partition files (count, min, max, sum per column)
  partition_format_2   table partition files in format 2 (one raw block per column)
  views                CREATE VIEW: the "views" file
candles
-------
    176
(1 row, 0.7 ms)

item                    | value                                           
------------------------+-------------------------------------------------
kareladb version             | 0.2.0-dev                                       
database                | old-db                                          
features used           | batched_log_sync, block_stats, partition_form...
feature list            | saved: batched_log_sync, block_stats, partiti...
features this KarelaDB reads | 26: views, partition_format_2, block_stats, r...
(5 rows, 0.1 ms)
```

- Without `--backups`, the backup goes into a folder next to the database: `old-db-backups` (for a database name in the data folder: `<data folder>-backups/<name>`). Older backups there are kept.
- You do not **have** to run `kareladb upgrade`. It is the safe way when you want a backup from just before, or before you move the folder to another computer.
- Exit codes: `0` done, `3` the database needs a newer KarelaDB (nothing done, no backup), `2` the check found damage (the backup is named), `1` could not run.

## Part D: when an older KarelaDB opens newer data

To show it here, the environment variable `KDB_TEST_HIDE_FEATURES` makes `kareladb` act like an older program that does not know `views`. It is **only for tests**; do not set it on a server.

```powershell
# Play an older KarelaDB that does not know "views" (KDB_TEST_HIDE_FEATURES is only for tests)
$env:KDB_TEST_HIDE_FEATURES = "views"
kareladb check old-db
"exit code: $LASTEXITCODE"
kareladb sql old-db "SELECT count(*) FROM ochl"
"exit code: $LASTEXITCODE"
$env:KDB_TEST_HIDE_FEATURES = ""
kareladb check old-db
"exit code: $LASTEXITCODE"
```

```text
error: this database needs a newer KarelaDB: it uses views (a stored-format feature this KarelaDB build does not know). Nothing was changed
This database was written by a newer KarelaDB. Open it with that KarelaDB or a newer one (kareladb version lists what this build can read). Do not run kareladb repair.
exit code: 3
error: this database needs a newer KarelaDB: it uses views (a stored-format feature this KarelaDB build does not know). Nothing was changed
This database was written by a newer KarelaDB. Open it with that KarelaDB or a newer one (kareladb version lists what this build can read). Do not run kareladb repair.
exit code: 3
checked 9 files (12.3 KB) and 2 log segments
OK: no damage found
exit code: 0
```

What to do when you see this message:

1. Do **not** repair or restore: the data is fine. `kareladb repair` would refuse too (exit code `3`).
2. Find the newer `kareladb` program that wrote the database, or build the newest one.
3. `kareladb version` on both programs shows which features each one reads.

Where you see it:

| Where | What you get |
|---|---|
| `kareladb check`, `kareladb repair`, `kareladb sql`, `kareladb shell`, `kareladb version <db>`, `kareladb upgrade` | the message and exit code `3` |
| `kareladb serve` | the database does not open; requests to it get HTTP status `500` with the message |
| PostgreSQL port | SQLSTATE `0A000` with the message |
| `kareladb restore` of a backup made by a newer KarelaDB | the message; nothing is copied |

In a nightly script:

```powershell
# In a script (not run here)
kareladb check D:\kdb\data\market | Out-Null
switch ($LASTEXITCODE) {
  0 { "check: OK" }
  2 { "check: DAMAGE FOUND - run kareladb repair" }
  3 { "check: this database needs a newer KarelaDB - update this kareladb, do not repair" }
  default { "check: could not run (exit code $LASTEXITCODE)" }
}
```

## Part E: updating KarelaDB on a server

1. Make a backup of every database (`BACKUP DATABASE`, or the scheduled backup of chapter 21), or run `kareladb upgrade` on each database while the server is stopped.
2. Stop the server. Replace **every** `kareladb` program on the machine (server, scheduled scripts) with the new build.
3. Start the server. Old databases open as they are; each gets its feature list at its next checkpoint.
4. `kareladb version <db>` or `SHOW VERSION` shows the lists.

Going back to an older KarelaDB:

- A database whose list has only features the older KarelaDB knows opens there.
- A database that uses a newer feature does not. Restore the backup from before the update with the **older** `kareladb restore` (changes made after that backup are then not in it).
- KarelaDB programs built **before 2026-09-12** do not read the feature list at all. They refuse most new data anyway, but not all of it. Never start such an old program on data of a newer KarelaDB.

## What you learned

- Every database has a feature list; KarelaDB records a feature before it writes data that needs it.
- A new KarelaDB opens old data; an old KarelaDB refuses new data with `needs a newer KarelaDB` and exit code `3`, never "damaged".
- `kareladb version`, `kareladb version <db>` and `SHOW VERSION` show the features; `kareladb upgrade` makes a backup, saves the list and checks the database.

More: the help topic **Versions and upgrades**, [known limitations](known-limitations.md#versions-and-upgrades-chapter-24), and `reports/versioning.md`.
