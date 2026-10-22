# Versions and upgrades

> A new KDB opens the data of an older KDB. An older KDB refuses the data of a newer KDB with "needs a newer KDB" and changes nothing.

- Category: Backup, check, repair, restore
- Keywords: version, versions, upgrade, kdb upgrade, kdb version, SHOW VERSION, VERSION, feature list, stored-format feature, needs a newer KDB, newer KDB, older KDB, old data, compatibility, exit code 3, Newer format, 0A000, KDB_TEST_HIDE_FEATURES, partition_format_2, block_stats, auto_meta, table_grants, pg_catalog_parts, batched_log_sync, database_settings, dedup_change, plpgsql_triggers, symbol_partitions, round_time_zone, no feature name, catalog part, downgrade, kdb downgrade, kdb features, going back, older version, go back to an older KDB, rollback
- See also: [Backup, check, repair and restore](backup-and-safety.md), [kdb info, check, repair, dump-file](cli-maintenance.md), [The kdb program (exit-codes)](cli-overview.md#exit-codes), [How KDB stores data](data-formats.md), [Versions and upgrades (downgrade)](versions.md#downgrade)

The rule:

- A **newer** KDB opens the data of an **older** KDB, as it is. Nothing to convert.
- An **older** KDB refuses the data of a **newer** KDB with the message `this database needs a newer KDB: it uses <feature>`. It does not call the data damaged, it repairs nothing and it changes nothing.

How it works: every database keeps a **feature list** in its manifest. A feature is one change to what KDB writes on disk, for example `json` (a JSON column) or `sequences` (`CREATE SEQUENCE`). KDB adds a feature to the list **before** it writes the first data that needs it. When a database opens, KDB reads the list first. A name it does not know means: a newer KDB wrote this. Only schema statements (`CREATE`, `ALTER`, ...), first uses and checkpoints look at the list, so rows cost nothing extra.

A database made by a KDB **before** feature lists (before 2026-09-12) has no list. It opens as always. KDB works out its list from the tables, files and log, and saves it at the next checkpoint (or now, with [kdb upgrade](#kdb-upgrade)).

<a id="kdb-version"></a>

## kdb version <db>

Syntax:

```sql
kdb version
kdb version <db> [--data-dir <folder>]
```

Without `<db>`: this KDB and every feature it can read. With `<db>`: the feature list of that database (read from its manifest, so it also works while a server has the database open).

- **Exit code:** `0`. `3` when the database uses a feature this KDB does not know. `1` when the folder is not a database.
- A database without a list yet says `feature list: not saved yet`.

**Command line: This KDB and the features it reads**

```bash
kdb version
```

Output:

```text
kdb 0.2.0-dev (crc32c hardware: yes)
tls: OpenSSL 3.6.3 9 Jun 2026

Stored-format features this build reads (51):
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
  compressed_log       0.2.0-dev (2026-10-02)   packed log records (type 3): the data records of a big commit written compressed (KDB_WAL_COMPRESS)
  endpoints            0.2.0-dev (2026-10-03)   CREATE ENDPOINT: saved queries served at GET /v/<name>, kind 'E' in the routines file
  rules                0.2.0-dev (2026-10-03)   CREATE RULE: named checks, session hours and settings of a table (catalog part 'Q')
  sync_commit_tables   0.2.0-dev (2026-10-03)   WITH (synchronous_commit = on | off) of a table: catalog part 'G'

A database that uses a feature not in this list needs a newer KDB (kdb check exits with 3).
```

**Command line: The features of one database** (sample data: sample)

```bash
kdb version market
```

Output:

```text
kdb 0.2.0-dev (crc32c hardware: yes)
database market
feature list (4):
  batched_log_sync     log segments in the batched format (header flag 1, 16-byte commit records): group commit and --sync-commits batch
  block_stats          column stats section in partition files (count, min, max, sum per column)
  compressed_log       packed log records (type 3): the data records of a big commit written compressed (KDB_WAL_COMPRESS)
  partition_format_2   table partition files in format 2 (one raw block per column)
```

## SHOW VERSION

Syntax:

```sql
SHOW VERSION
```

This KDB's version, and for the current database: the features it uses now and the list saved in its manifest. Every user may run it (it shows no data).

| item | value |
|---|---|
| `kdb version` | the version of this KDB |
| `database` | the current database |
| `features used` | what the database uses now |
| `feature list` | `saved: ...`, or `not saved yet (written by an older KDB)` |
| `features this KDB reads` | how many, and their names |

**Example: SHOW VERSION** (sample data: sample)

```sql
SHOW VERSION;
```

Result:

| item (STRING) | value (STRING) |
|---|---|
| kdb version | 0.2.0-dev |
| database | demo |
| features used | batched_log_sync, block_stats, compressed_log, partition_format_2 |
| feature list | saved: batched_log_sync, block_stats, compressed_log, partition_format_2 |
| features this KDB reads | 51: views, partition_format_2, block_stats, runs, auto_meta, json, bytes, check, indexes, routines, users, audit, table_grants, totp, trash, database_settings, dialects, pg_catalog_parts, sequences... |

(5 rows)

## kdb upgrade

Syntax:

```sql
kdb upgrade <db> [--backups <dir>] [--data-dir <folder>]
```

Makes a database ready for this KDB, in three steps:

1. A **verified backup** into `--backups <dir>` (default: a folder `<db folder>-backups` next to the database; for a name in the data folder `<data folder>-backups/<name>`). Older backups there are kept.
2. Saves the database's **feature list** (and writes anything a newer format needs; this version needs nothing more).
3. Runs [kdb check](cli-maintenance.md#kdb-check).

- **Exit code:** `0` = done. `3` = the database needs a newer KDB (nothing was done, no backup). `2` = the check found damage (the backup from step 1 is named). `1` = it could not run (for example the database is open in a server: stop it first).
- You do not have to run it: KDB saves the list by itself at the next checkpoint. Run it when you want the backup, or before you give the folder to another KDB.
- After an upgrade, an older KDB that does not know one of the listed features refuses the database. Keep the backup if you may need to go back to that older KDB.

**Command line: Upgrade a database** (sample data: sample)

```bash
kdb upgrade market --backups backups
```

Output:

```text
KDB 0.2.0-dev, database market
saved feature list: batched_log_sync, block_stats, compressed_log, partition_format_2
1/3 verified backup into backups ...
    backups/20261022-054442-544 (9 files, 190.0 KB)
2/3 saving the feature list ...
    features used: batched_log_sync, block_stats, compressed_log, partition_format_2
    (no files need to be written again for this KDB version)
3/3 check ...
checked 14 files (76.1 KB) and 1 log segments
OK: no damage found

Upgrade done. An older KDB build that does not know one of these features now refuses this database with "needs a newer KDB".
```

<a id="downgrade"></a>

## Going back to an older version

Syntax:

```sql
kdb features <db> | --data-dir <folder>
kdb downgrade <db> | --data-dir <folder> --to <version> [--backups <dir>] [--no-backup]
kdb downgrade <db> | --data-dir <folder> --known <feature,feature,...>
```

An older KDB opens a database again when the data uses nothing newer than that KDB reads. The feature list only grows, so it may still name a feature you stopped using: a dropped column, a dropped procedure. `kdb downgrade` takes those names off.

`kdb features` shows what each database uses **now**, and what uses it. It changes nothing.

`kdb downgrade` works in three steps:

1. A **verified backup** (as [kdb upgrade](#kdb-upgrade) makes it). `--no-backup` skips it.
2. A checkpoint, so nothing waits in the log. Then the feature list becomes exactly what the data uses.
3. [kdb check](cli-maintenance.md#kdb-check).

| Option | What it means |
|---|---|
| `--to 2026-09-24` | a KDB built on that day: it reads every feature written since that day or before |
| `--to 0.2.0-dev` | the last KDB of that version |
| `--known views,indexes,...` | exactly these features: the names `kdb version` of the older KDB prints |
| `--data-dir <folder>` without `<db>` | every database of the data folder, `_system` too. All are checked before any is changed. |

- **Refused** when the data uses a feature the older KDB does not read. It names the table, column, index, view or routine that uses it, and how to remove it. Nothing is changed, and no backup is made.
- A dropped table stays in the [trash](trash.md) and still counts. Remove it for good with `DROP TABLE _dropped_<time>_<name>`.
- It never rewrites data into an older form. To go back, first stop using the newer feature, for example `ALTER TABLE prices DROP COLUMN amount` for a `NUMERIC(30, 4)` column.
- A dropped column stays in the table's files written before the drop, and an older KDB refuses such a file. `kdb features` names these files ("a dropped or changed ... column still in N partition file(s)"). You do nothing: in step 2, `kdb downgrade` writes those partitions again without the column, and says how many.
- Stop the server first. Then start the older KDB on the data.
- **Exit code:** `0` = done. `1` = refused, or it could not run. `2` = the check found damage (the backup is named).

**Command line: What a database uses now** (sample data: sample)

```bash
kdb features market
```

Output:

```text
database market
in use now (4):
  partition_format_2     0.2.0-dev (2026-09-11)
      used by: the table files
  block_stats            0.2.0-dev (2026-09-11)
      used by: the table files
  batched_log_sync       0.2.0-dev (2026-09-11)
      used by: the log (group commit writes every log segment this way)
  compressed_log         0.2.0-dev (2026-10-02)
      used by: the log (big commits are written as packed records)
```

**Command line: Let a KDB of 24 Sep 2026 open the data** (sample data: sample)

```bash
kdb downgrade market --to 2026-09-24 --backups backups
```

Output:

```text
KDB 0.2.0-dev: downgrade to 2026-09-24

database market
1/3 verified backup into backups ...
    backups/20261022-054442-754 (9 files, 190.0 KB)
2/3 checkpoint, then the feature list ...
    list before: batched_log_sync, block_stats, compressed_log, partition_format_2
    list now:    batched_log_sync, block_stats, partition_format_2
    taken off (no longer used): compressed_log
3/3 check ...
checked 14 files (76.1 KB) and 1 log segments
OK: no damage found

Downgrade done. Stop this KDB and start the older one on the data. Opening the data with this KDB again is fine: it adds features to the list as they are used.
```

**Command line: Refused: a 128-bit NUMERIC column is in use**

Setup:

```text
CREATE TABLE prices (id LONG, amount NUMERIC(30, 4));
```

```bash
kdb downgrade market --to 2026-09-24 --no-backup
```

Output:

```text
KDB 0.2.0-dev: downgrade to 2026-09-24

database market uses features the older KDB does not read:
  decimal128             0.2.0-dev (2026-09-25)
      used by: column 'amount' of table 'prices' (NUMERIC with more than 18 digits)
      to remove: ALTER TABLE prices DROP COLUMN amount

Nothing was changed. Remove what is listed (a dropped table stays in the trash until DROP TABLE _dropped_<time>_<name>), or keep this KDB. The command only goes back when the data uses nothing newer.
```

exit code 1

<a id="needs-newer"></a>

## "needs a newer KDB"

Syntax:

```sql
error: this database needs a newer KDB: it uses <feature> (a stored-format feature this KDB build does not know). Nothing was changed
```

The database was written by a newer KDB. **It is not damaged.**

- Open it with that KDB or a newer one. `kdb version` on both programs shows what each can read.
- Do **not** run `kdb repair` or `kdb restore`: they would refuse too (exit code `3`).
- The same message comes for other things only a newer KDB writes: a newer manifest or file format version, a log record type or a catalog part this KDB does not know, a file name it does not know, or a backup of such a database.
- `kdb check`, `kdb repair`, `kdb sql`, `kdb version <db>` and `kdb upgrade` end with **exit code 3**. Over HTTP it is status 500; on the PostgreSQL port SQLSTATE `0A000`.

<a id="features"></a>

## The features

| Feature | What a database with it has | Written since |
|---|---|---|
| `views` | `CREATE VIEW` (the "views" file) | 0.2.0-dev (2026-09-10) |
| `partition_format_2` | table partition files in format 2 | 2026-09-11 |
| `block_stats` | count, min, max and sum per column in partition files | 2026-09-11 |
| `runs` | log records of bulk upserts kept as columns (line protocol) | 2026-09-11 |
| `auto_meta` | AUTO id counters in the manifest | 2026-09-11 |
| `json`, `bytes` | `JSON` and `BYTES` columns | 2026-09-11 |
| `check` | `CHECK` constraints | 2026-09-11 |
| `indexes` | `CREATE INDEX`, `UNIQUE`, `FULLTEXT` | 2026-09-11 |
| `routines` | saved functions, procedures, triggers | 2026-09-11 |
| `users` | server users (in `_system`) | 2026-09-11 |
| `batched_log_sync` | log files in the batched form: group commit (the default) and `--sync-commits batch` write them, so every database has it | 2026-09-11 |
| `audit` | `ALTER TABLE ... SET AUDIT ON`, `_audit_log` | 2026-09-12 |
| `table_grants`, `totp` | `GRANT ... ON TABLE`, two-factor logins (in `_system`) | 2026-09-12 |
| `trash` | dropped tables kept for `UNDROP TABLE` | 2026-09-12 |
| `database_settings`, `dialects` | `ALTER DATABASE ... SET READ ONLY` / `SET dialect` (in `_system`) | 2026-09-12 |
| `pg_catalog_parts` | PostgreSQL types, multi-column keys, foreign keys, expression and partial indexes | 2026-09-12 |
| `sequences` | `CREATE SEQUENCE` | 2026-09-12 |
| `dedup_change` | `ALTER TABLE ... DEDUP ENABLE` / `DISABLE` on a table that already holds rows | 2026-09-12 |
| `plpgsql_triggers` | PostgreSQL `plpgsql` trigger functions and `FOR EACH ROW` triggers | 2026-09-12 |
| `cached_views` | `CREATE CACHED VIEW`: which views are cached and `REFRESH ON COMMIT`, kept in the "views" file | 2026-09-13 |
| `deferred_triggers` | `CREATE TRIGGER ... DEFERRED`: job records in the log, and the "trigger_queue" and "q/..." files of waiting jobs | 2026-09-13 |
| `materialized_views` | `CREATE MATERIALIZED VIEW`: the view's query in the catalog, refresh records in the log, waiting partitions in the manifest | 2026-09-13 |
| `table_ttl` | `TTL n DAYS` on a table, kept in the catalog | 2026-09-13 |
| `read_only_procedures` | `CREATE PROCEDURE ... READ ONLY`, kept with the procedure | 2026-09-24 |
| `dedup_insert` | `WITH (dedup_insert = 'upsert')` on a table, kept in the catalog | 2026-09-24 |
| `decimal128` | `NUMERIC(p, s)` columns with more than 18 digits (128 bits each) | 2026-09-25 |
| `uuid` | `UUID` columns, 16 bytes per value ([UUID](column-types.md#uuid)) | 2026-10-02 |
| `column_grants` | `GRANT SELECT (a, b) ON TABLE t` ([column rights](table-rights.md#column-rights); in `_system`, only once one is granted) | 2026-10-02 |
| `row_policies` | `CREATE POLICY`, `ALTER TABLE t ENABLE ROW LEVEL SECURITY` ([row rights](table-rights.md#row-rights); in `_system`, only once one is made) | 2026-10-02 |
| `dedup_generated_key` | a stored generated column in a `DEDUP KEY`, like [the minute of the time](partitions-and-dedup.md#minute-key) | 2026-09-25 |
| `symbol_partitions` | `PARTITION BY ..., SYMBOL(col)` ([split by symbol](partitions-and-dedup.md#partition-by-symbol)) | 2026-09-25 |
| `round_time_zone` | a column `TIMESTAMP ROUND 1d TIME ZONE 'Asia/Kathmandu'` ([TIME ZONE](sample-by.md#time-zone)) | 2026-09-25 |
| `enum_types` | `CREATE TYPE ... AS ENUM`: the types and their labels, kept in the catalog | 2026-09-25 |
| `row_ttl` | `WITH (ttl_column = c)`: [rows that expire](create-table.md#row-ttl), kept in the catalog | 2026-09-25 |
| `column_compression` | `SET (compression = on)` on a table and its packed partition files ([compression](partitions-and-dedup.md#compression)); `kdb downgrade` writes the files plain again once the table is set to `off` | 2026-09-25 |
| `calendars` | `CREATE CALENDAR`: [trading calendars](calendars.md) (eras, holidays, extra trading days), kept in the catalog | 2026-09-25 |
| `materialized_view_sample_by` | a [materialized view](views.md#materialized-view) over a `SAMPLE BY` query (QuestDB's form) | 2026-09-26 |
| `comments` | `COMMENT ON TABLE / COLUMN`: [the comments](functions-postgres.md#comments) of tables and columns, kept in the catalog; `COMMENT ON ... IS NULL` removes one | 2026-09-26 |
| `partition_tails` | [tail files](partitions-and-dedup.md#tail-files) (`kdb serve --tail-files on`): rows appended to a partition saved in extra files next to it; `kdb downgrade` writes those partitions whole again | 2026-10-02 |
| `partition_deltas` | [delta files](partitions-and-dedup.md#delta-files) (on unless `KDB_NO_PARTITION_DELTA=1`): a few rows of a partition replaced, updated or deleted, saved in one extra file next to it; `kdb downgrade` writes those partitions whole again | 2026-10-02 |
| `compressed_log` | [compressed log](backup-and-safety.md#compressed-log): a big commit's log records written packed (on unless `KDB_WAL_COMPRESS=off`), so every database this KDB opens has it; `kdb downgrade` to an older KDB turns packing off by itself while it works | 2026-10-02 |
| `search_analyzer` | `CREATE FULLTEXT INDEX ... WITH (language = 'english')`: the [word analyzer](full-text-search.md#language) of a full-text index, kept in the catalog | 2026-10-02 |
| `fulltext_segments` | the words of full-text and JSON indexes saved in the folder `fts/` ([segments on disk](full-text-search.md#segments)). **Never put in a database's list:** an older KDB ignores the folder, so it still opens the database; `kdb downgrade` to a KDB without it moves the folder's files to `_trash` | 2026-10-02 |
| `endpoints` | `CREATE ENDPOINT`: [saved queries served at GET /v/name](http-endpoints.md), kept with the functions and procedures | 2026-10-03 |

- A feature stays in the list once it is there, even when you drop the table that used it. [kdb downgrade](#downgrade) takes such names off.
- Programs made **before** feature lists do not read the list. They still refuse most new data (catalog parts, file formats) but not all of it: do not open new data with them.
- For tests only: the environment variable `KDB_TEST_HIDE_FEATURES=name,name` makes kdb act like an older build that does not know those features.

<a id="no-feature-name"></a>

## Two options named late

Two table options were saved for a while as a new **part** of a table in the catalog, without a feature name. Since 2026-09-25 they have one: `symbol_partitions` and `round_time_zone`. KDB adds the name to the list at the next checkpoint.

| Table option | Saved as | Written since | Named since |
|---|---|---|---|
| a column `TIMESTAMP ROUND 1d TIME ZONE 'Asia/Kathmandu'` | catalog part `R` | 2026-09-13 | 2026-09-25 (`round_time_zone`) |
| `PARTITION BY ..., SYMBOL(col)` | catalog part `P` | 2026-09-18 | 2026-09-25 (`symbol_partitions`) |

- Only a database with such a table gets the name. Every other database opens in an older KDB as before.
- A KDB from before the name still refuses such a database safely: it finds a catalog part it does not know and stops with `needs a newer KDB`.

<a id="no-format-change"></a>

## Changes that need no format change

These newer changes write nothing an older KDB cannot read. An older KDB that knows the features in the database's list still opens it.

| Change | Since | Why the files stay the same |
|---|---|---|
| tables without a `DEDUP KEY` loaded as sorted runs | 2026-09-23 | the same run log record (`runs`) as tables with a key |
| skipping partitions and blocks by column stats, `count`/`min`/`max`/`sum` from saved stats | 2026-09-23 | partition files already had the stats (`block_stats`) |
| table write locks, group commit, reader yield | 2026-09-23 | only how writers take turns in memory |
| keys of dropped tables removed from the manifest | 2026-09-23 | fewer keys of a kind the manifest already had. See [manifest keys](data-formats.md#manifest-keys). |
| indexes built at open | 2026-09-23 | indexes are never stored |
| [pinned queries](pinned-queries.md) | 2026-09-23 | kept as rows of an ordinary table, `_pinned_queries` (in `_system`, or in the database of a server without a data folder) |
