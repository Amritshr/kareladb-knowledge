# The trash - UNDROP TABLE

> DROP TABLE keeps the table hidden for some days; UNDROP TABLE brings it back with its rows and indexes.

- Category: Tables
- Keywords: trash, undo drop, undrop, UNDROP, restore table, dropped table, recover table, DROPPED, \_dropped\_, --trash-days, PurgeDroppedTables
- See also: [CREATE TABLE](create-table.md), [ALTER, RENAME and DROP TABLE](alter-table.md), [Protection - timeouts, limits, safe updates, read-only](protection.md), [Backup, check, repair and restore](backup-and-safety.md), [Databases and the data folder](databases.md)

`DROP TABLE` is easy to type by mistake. With the trash, the table is only hidden: its rows stay where they are, and `UNDROP TABLE` brings it back. After the keep time (7 days by default) KarelaDB removes it for good.

`kareladb serve`, `kareladb sql` and `kareladb shell` keep dropped tables for `--trash-days 7`. Programs that use the KarelaDB library set `DatabaseOptions::dropped_table_keep_ms` (0 = off, the default there).

<a id="drop"></a>

## DROP TABLE and the trash

Syntax:

```sql
DROP TABLE [IF EXISTS] <name>                 -- kept in the trash
kareladb serve --trash-days 7                      (0 = DROP TABLE removes at once)
DROP TABLE _dropped_<time>_<name>             -- remove one from the trash for good
```

- **Returns:** `table 't' dropped; UNDROP TABLE t brings it back within 7 days`.
- **Notes:**
  - A new table with the same name, and indexes with the same names, can be made at once.
  - Dropping takes no time and no space: nothing is copied. The rows use disk space until the table is removed for good.
  - When it is removed for good, its files go and so do its entries in the database's list of files; any left by an older build are swept at the next checkpoint or open (`kareladb info` counts them under `manifest keys`).
  - This trash is for tables. [PURGE TRASH](databases.md#purge-trash) empties the database's `_trash` folder of replaced files, and `PURGE TRASH ALL` also the dropped databases; it leaves dropped tables alone.
  - A dropped table is hidden from `SHOW TABLES`, `SHOW INDEXES` and `/api/info`, and nobody can read or change it.
  - A dropped table that REFERENCES another table is removed for good when that other table is dropped.
  - A table with named `UNIQUE` or `PRIMARY KEY` constraints (PostgreSQL style) is dropped for good at once for now.
  - Table grants ([GRANT ... ON TABLE](table-rights.md)) do not come back with `UNDROP TABLE`.

<a id="undrop-table"></a>

## UNDROP TABLE

Syntax:

```sql
UNDROP TABLE <name>
```

Brings back the newest dropped table with this name: its columns, rows and indexes.

- **Returns:** `table 't' is back, with N row(s)`.
- **Notes:** refused while a table or view with that name exists (rename or drop it first), or when an index name is used again meanwhile. Needs role admin on the database.

**Example: Drop by mistake, then bring it back** (sample data: sample)

```sql
DROP TABLE live_data;
SHOW DROPPED TABLES;
UNDROP TABLE live_data;
SELECT count(*) FROM live_data;
```

Result:

`DROP TABLE live_data`

```text
table 'live_data' dropped; UNDROP TABLE live_data brings it back within 7 days
```

`SHOW DROPPED TABLES`

| name (STRING) | dropped (TIMESTAMP) | removed_after (TIMESTAMP) | rows (LONG) | stored_as (STRING) |
|---|---|---|---|---|
| live_data | 2026-10-24T03:43:27.347Z | 2026-10-31T03:43:27.347Z | 12 | _dropped_1792813407347_live_data |

(1 row)

`UNDROP TABLE live_data`

```text
table 'live_data' is back, with 12 row(s)
```

`SELECT count(*) FROM live_data`

| count(*) (LONG) |
|---|
| 12 |

(1 row)

<a id="show-dropped-tables"></a>

## SHOW DROPPED TABLES

Syntax:

```sql
SHOW DROPPED TABLES
```

The tables in the trash of the current database, newest first.

| Column | Meaning |
|---|---|
| `name` | the name the table had |
| `dropped` | when it was dropped |
| `removed_after` | when KarelaDB removes it for good |
| `rows` | rows in it |
| `stored_as` | its hidden name, for `DROP TABLE` to remove it at once |
