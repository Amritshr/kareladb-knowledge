# Keep data page (how long tables keep their rows)

> See every table of a database with how long it keeps its rows, and set "keep only the last N months or years": the older days, months or years are dropped, the newest stay.

- Category: Web console
- Keywords: keep data, retention, Save disk, /api/disk, disk usage, older copies, trash, keep the last, keep only, old data, drop old data, TTL, months, years, drop partition older than, disk space, save disk, free space, purge
- See also: [Web console](web-console.md), [ALTER, RENAME and DROP TABLE](alter-table.md), [Timers](timers.md), [Partitions, SORT BY and DEDUP KEY](partitions-and-dedup.md), [Databases and the data folder](databases.md), [View data page (browse and edit rows)](console-data-page.md)

The **Keep data** page of the [web console](web-console.md) (Home menu) lists every table of the chosen database and lets you say how long each keeps its rows. Nothing is dropped from the start of the table: it keeps the **newest** data and lets the oldest go.

<a id="screen"></a>

## The screen

```text
+------------------------------------------------------------------------------------------+
| Keep data   database nchart006                                                [Refresh]  |
| [x] all   For the 3 ticked: keep the last [6] [months v]  [Keep] [Keep everything] [Drop older now] |
|                                                                                          |
|   | table         | kind              | rows   | on disk | data from / to           | keeps           |                              |
| [x]| Daily_Filter  | time-series, DAY  | 11.5M  | 890 MB  | 2022-01-25 to 2026-09-11 | the last 6 months | [6][months v] [Keep] [Drop older now] [Everything] |
| [ ]| floorsheet_v1 | time-series, DAY  | 69.3M  | 5.3 GB  | 2022-01-25 to 2026-09-11 | everything        | [6][months v] [Keep] [Drop older now]              |
| [ ]| bg_config     | relational        | 2      | 4 KB    | no partitions            | everything (no partitions to drop)                                    |
+------------------------------------------------------------------------------------------+
```

| Part | What it is |
|---|---|
| rows, on disk | the table's row count and the bytes its files take |
| data from / to | the oldest and newest time in the table (read from the block statistics, so it costs nothing) |
| keeps | `everything`, or `the last 6 months`: the table's [TTL](alter-table.md#set-ttl) |
| **Keep** | sets the TTL: `ALTER TABLE t SET TTL 6 MONTHS`. From then on KarelaDB drops, every minute and by itself, every partition whose last moment is older than that |
| **Everything** | takes the TTL off: `ALTER TABLE t SET TTL NONE` |
| **Drop older now** | one drop, now: `ALTER TABLE t DROP PARTITION OLDER THAN 6 MONTHS`. It shows the statement and asks first |
| the top bar | the same three for every ticked table at once (**Keep everything** takes the TTL off them) |
| **Refresh** | reads the tables and the disk box again |

The period is a number and a unit: `days`, `weeks`, `months` or `years`.

- Only time-series tables with `PARTITION BY DAY`, `MONTH` or `YEAR` can keep "the last N": everything else has no partitions to drop, is listed greyed, and keeps everything. Use [DELETE](update-delete.md#delete) there.
- A partition goes when its **last** moment is older than the period, so "the last 6 months" always holds at least 6 full months. Months and years follow the calendar.
- Whole partitions go, never single rows, and a dropped partition cannot be brought back. Every drop is written to the audit log.
- A `read` user sees the page; the buttons need `write`.

<a id="disk"></a>

## Disk space

The box at the top says what the database takes on disk, part by part. It reads [GET /api/disk](http-server-info.md#api-disk), which walks the trash folder, so it is asked for on this page only. Hover a part to see how many files it holds.

| Part | What it is | Field of `/api/disk` |
|---|---|---|
| On disk | everything below together | `total_bytes` |
| data | the current version of every data file: the rows. Of those, [tail files](partitions-and-dedup.md#tail-files) are rows appended after a partition's file, folded back into it later, and [delta files](partitions-and-dedup.md#delta-files) the rows of a partition replaced or deleted | `data_bytes`, `data_files`; tails `tail_bytes`, `tail_files`; deltas `delta_bytes`, `delta_files` |
| older copies | older versions of the data files, kept so a damaged file can be repaired from one of them (2 per file unless `keep_versions` says otherwise; a version whose old log is gone can repair nothing and goes by itself) | `previous_bytes`, `previous_files` |
| trash | replaced files nothing needs any more; the server removes them by itself once they are older than `trash_keep_hours` (1 hour unless set), or when the trash is over `trash_max_mb` (a quarter of the data, at least 256 MB, unless set) | `trash_bytes`, `trash_folders` |
| log | the current log, and old log kept for repairs and backups ([wal_archive](console-settings.md#wal-archive)) | `wal_bytes` + `wal_archive_bytes` |

**Save disk** (admin) runs [PURGE VERSIONS KEEP 1](databases.md#purge-versions), which leaves one older copy per file, then [PURGE TRASH](databases.md#purge-trash), and shows the space that came back. Dropping partitions frees their files the same way: they go to the trash first, and the trash goes on its own.

**Example: What the Keep button runs**

Setup:

```sql
CREATE TABLE trades (time TIMESTAMP, symbol SYMBOL, qty LONG) TIMESERIES(time) PARTITION BY MONTH;
```

```sql
ALTER TABLE trades SET TTL 6 MONTHS;
SHOW CREATE TABLE trades;
```

Result:

`ALTER TABLE trades SET TTL 6 MONTHS`

```text
table 'trades' drops partitions older than 6 MONTHS
```

`SHOW CREATE TABLE trades`

| create_sql (STRING) |
|---|
| CREATE TABLE trades (   time TIMESTAMP,   symbol SYMBOL,   qty LONG ) TIMESERIES(time) PARTITION BY MONTH SORT BY (symbol, time) TTL 6 MONTHS |

(1 row)
