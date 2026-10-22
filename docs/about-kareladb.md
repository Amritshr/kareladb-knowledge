# About KarelaDB

> What KarelaDB is, who made it, what you can use it for, how it keeps your data safe, how fast it is and how it is tested.

- Category: Getting started
- Keywords: about, KarelaDB, KDB, kdb, old name, renamed, name change, why the name changed, kdb+, KX Systems, KARELA, KARELA DataBase, what is KarelaDB, creator, author, Amrit Shrestha, created by, use cases, what can I use KarelaDB for, time-series database, relational database, IoT, sensors, logs, metrics, accounting, ledger, app backend, full-text search, PostgreSQL compatible, data safety, comments, suggestions, feedback
- See also: [Quick start](quick-start.md), [What's new](whats-new.md), [Install packages and the Claude skill](install-packages.md), [Database models: relational, hierarchical, network, NoSQL, object](data-models.md), [Test report](test-report.md), [Benchmark report](benchmark-report.md), [Limits](limits.md), [Backup, check, repair and restore](backup-and-safety.md)

KarelaDB (KARELA DataBase) is a small, general-purpose SQL database written in C++17. It runs as **one program** with no other software needed, and it keeps your data safe from crashes, power cuts and disk damage.

| | |
|---|---|
| Name | KarelaDB: KARELA DataBase (called KDB until 2026-10-22, see [why the name changed](#name)) |
| Created by | **Amrit Shrestha** |
| Version | 0.2.0-dev |
| Written in | C++17, with no third-party libraries in the core |
| Tested on | Windows 11, and Linux (Debian 12 and Alpine) in Docker |
| What changed lately | [What's new](whats-new.md) |

Send comments and suggestions from the web console: Help menu > Comments and suggestions.

Source: README.md, CMakeLists.txt, reports/linux-build.md, reports/docker-image.md.

<a id="name"></a>

## Why the name changed

KarelaDB was called **KDB** until 2026-10-22. There is an older, well-known time-series database called **kdb+** (with its language q) by KX Systems, and the two names were easy to mix up. KarelaDB has nothing to do with kdb+: its language is ordinary SQL. So the product took its full name, KARELA DataBase, written as KarelaDB.

Nothing changes for your data, and the old names keep working:

| What | New name | The old name still works? |
|---|---|---|
| The program | `kareladb` (`kareladb.exe` on Windows) | yes: `kdb` (`kdb.exe`) is the same program |
| Settings in the environment | `KARELADB_TOKEN`, `KARELADB_DATA_DIR`, ... | yes: every `KDB_*` name is still read |
| The settings file | `kareladb.conf` | yes: `kdb.conf` is read when there is no `kareladb.conf` |
| The Docker image and container | `kareladb` | a new image is named `kareladb`; start it on the same data folder and `kdb_wal` volume and it opens the same databases |
| The Claude skill | `kareladb` (and `kareladb-geometry`) | it still answers to "kdb", `KDB_TOKEN` and "port 9900" |

If you installed the skill before the rename: after `kareladb skill install`, delete the old folder `~/.claude/skills/kdb` (and its `token` file), so the assistant does not keep an old copy next to the new one. See [the Claude skill](install-packages.md#skill).

What does **not** change at all: your data folders and files (`kdb_data`, the `.kdb` files, the log), the Docker volume `kdb_wal`, the ports 9900 and 8832, the HTTP routes and headers (`X-KDB-...`), the JSON fields, the metric names (`kdb_...`) and the SQL settings (`kdb.pg_compat`, ...). A database written before the rename opens as it is; nothing needs to be copied or converted.

<a id="one-program"></a>

## One program, three doors

`kareladb serve` starts one server. You reach the same databases three ways:

| Door | Port | For |
|---|---|---|
| [Web console](web-console.md) | 9900 | a browser: run SQL, see tables and charts, dashboards, settings |
| [HTTP API](http-overview.md) | 9900 | any language or script: send SQL, get JSON back |
| [PostgreSQL protocol](postgres-protocol.md) | 8832 | `psql`, PostgreSQL drivers and apps written for PostgreSQL |

> **Diagram:** Three kinds of client, a web browser, apps and scripts, and PostgreSQL tools, reach the one kareladb program on ports 9900, 9900 and 8832. Inside the program the SQL engine sits on top of the storage engine.
>
> Every door reaches the same SQL engine and the same data. The web console, the help and the Claude skill are plain folders next to the program.

- A database is a folder. One server can hold many databases.
- KarelaDB is one server on one machine. It is not a cluster that spreads data over many machines.
- Nothing else is built into the program. The web console, the help and the Claude skill are the folders `web/`, `help/` and `skill/` next to `kareladb`, so a new console or help needs no new program. See [where kareladb finds them](install-packages.md#folders).
- You can also run it in Docker: the image (about 44 MB) holds the program and those three folders. See [install-packages](install-packages.md#docker).

Ask the running server which version it is:

**Example: Which KarelaDB is this?** (sample data: sample)

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
| features this KDB reads | 52: views, partition_format_2, block_stats, runs, auto_meta, json, bytes, check, indexes, routines, users, audit, table_grants, totp, trash, database_settings, dialects, pg_catalog_parts, sequences... |

(5 rows)

Source: README.md, reports/docker-image.md, src/server/support_files.h, docker/Dockerfile.

<a id="use-cases"></a>

## What you can use KarelaDB for

KarelaDB is not tied to one market or one kind of data. It holds **time-series tables** (rows that arrive in time order) and ordinary **relational tables** (rows linked by keys), and one query may use both.

| Use | What KarelaDB gives you | Help |
|---|---|---|
| Market and price data | OHLC candles from raw rows, the latest row per symbol, technical indicators, trade lists loaded faster than QuestDB | [sample-by](sample-by.md), [latest-on](latest-on.md), [functions-indicators](functions-indicators.md), [candles-cookbook](candles-cookbook.md) |
| IoT and sensor readings | many small rows per second over the line protocol, grouped by device and time, duplicates dropped | [line-protocol](line-protocol.md), [partitions-and-dedup](partitions-and-dedup.md), [sample-by](sample-by.md) |
| Logs, metrics and monitoring | append-only events kept in time partitions, filtered and summed by time, old days dropped on a schedule | [create-table](create-table.md), [time-and-time-zones](time-and-time-zones.md), [group-by](group-by.md), [console-keep-data](console-keep-data.md) |
| Accounting and ledgers | exact `DECIMAL` money, `CHECK` rules, `BEGIN` / `COMMIT` / `ROLLBACK`, writers of different tables at the same time | [column-types](column-types.md), [constraints](constraints.md), [transactions](transactions.md) |
| Users, logins and app backends | password hashes, random tokens, UUIDs, unique keys, indexes, database users and roles | [functions-security](functions-security.md), [indexes](indexes.md), [users-and-roles](users-and-roles.md) |
| News, documents and forums | full-text search with ranking, phrases and prefixes answered from the index, `JSON` columns for loose data | [full-text-search](full-text-search.md), [functions-json](functions-json.md) |
| Apps already written for PostgreSQL | connect normal PostgreSQL tools and drivers to port 8832 | [postgres-protocol](postgres-protocol.md), [functions-postgres](functions-postgres.md) |
| Trees, networks and documents | parent-child tables, links between items, `WITH RECURSIVE` | [data-models](data-models.md) |
| Charts, dashboards and scheduled jobs | 22 chart types from any query, dashboards saved in the database, timers that run a procedure every minute, day or month | [web-console](web-console.md), [timers](timers.md) |

What does not work yet is listed on [limits](limits.md).

Source: README.md "What you can use KarelaDB for", docs/help/topics/data-models.md.

<a id="safety"></a>

## How your data is kept safe

| Protection | What it does for you |
|---|---|
| Checksum on every block | Every file is split into blocks, and each block has a CRC32C checksum. If one bit changes on the disk, KarelaDB finds it and knows which block is bad. |
| Write-ahead log | Every change is written to the log and saved to disk before KarelaDB says "committed". After a crash the log is played again, so no committed change is lost. |
| Copy-on-write files | A data file is never changed after it is written. KarelaDB writes a new version and then switches to it, so a crash never leaves a half-changed file. |
| Two manifest copies | The list of current files is kept twice. KarelaDB always writes over the older copy, so one good copy is always left. |
| Repair ladder | A damaged file is repaired from an older version first, then from a backup. If both fail, only that file is marked damaged and the rest still works. |
| Verified backups | After a backup, KarelaDB reads every file of it again. A backup that is not finished or not correct is never used. |
| Point-in-time restore | Restore a backup and replay the log up to an exact time, for example just before a bad import. |

With `--sync-commits batch` (a disk flush every 10 ms, the faster setting) a power cut can lose writes from the last moments that were already confirmed. `--sync-commits always` flushes on every commit and loses nothing. See [backup-and-safety](backup-and-safety.md) and [protection](protection.md).

Source: README.md "What protects your data", reports/qa-tests.md.

<a id="speed"></a>

## How fast it is

KarelaDB is measured against QuestDB (time-series) and PostgreSQL (relational and search) on the same PC, in the same minutes. A few lines from the reports:

| Work | KarelaDB | The other database | Report |
|---|---|---|---|
| Bulk load of candles, 20,000 rows a request | 1.04M to 1.36M rows/s | QuestDB 865k rows/s | vs QuestDB |
| Load of a trade list (814,535 real trades, no DEDUP KEY) | 918k rows/s | QuestDB 678k rows/s | keyless runs |
| SQL `INSERT`, 100 rows a statement | 144k to 166k rows/s | QuestDB 6.8k to 8.9k rows/s | vs QuestDB |
| Search 200,000 news articles: count of a common word | 3.6 ms | PostgreSQL 18: 250 ms | news search |
| Search: a two-word phrase | 9.7 ms | PostgreSQL 18: 295 ms | news search |
| 8 clients doing bank transfers | 1,981 a second | PostgreSQL 18: 890 a second | table locks |

Where KarelaDB is still slower:

| Work | KarelaDB | The other database |
|---|---|---|
| A report joining three tables with `GROUP BY` and `LEFT JOIN` | 19 a second | PostgreSQL 68 a second |
| `ORDER BY` over many groups, and big JSON answers | slower | QuestDB |

The full tables, how each number was measured and every place KarelaDB still loses are on [benchmark-report](benchmark-report.md). New speed-ups and their before and after numbers are on [what's new](whats-new.md).

Source: reports/benchmark-vs-questdb.md, reports/keyless-runs.md, reports/news-search.md, reports/table-locks-merge.md, reports/benchmark-postgres.md, reports/floorsheet-filter-speed.md.

<a id="quality"></a>

## How it is tested

| Test | What it does | Result |
|---|---|---|
| Crash test | kills the program at a random moment while it writes, 1,000 times | every confirmed change there, no money lost |
| Power-cut test | throws away every write the disk had not flushed, 1,000 times, also during recovery | pass, 0 repairs needed |
| Damage test | flips bytes, cuts and deletes files, 1,000 rounds | damage always found, 0 wrong answers |
| Full disk | a full disk at 24 moments in 3 log modes | committed rows intact, HTTP 507, writes go on when space returns |
| Junk text | 12,132 statements of broken UTF-8, NUL bytes, huge texts | no crash, no hang |
| Soak | 30 minutes of mixed load: 19.9M line-protocol rows, 64,637 queries | 0 errors, every row accounted for |
| C++ test programs | 52 programs, also run with ASan and UBSan (tools that find memory mistakes) | pass |
| Console and HTTP API | Node tests that drive the console in Chrome and call every route | pass |
| Help examples | every example on these help pages is run on each help build | about 1,900, 0 failed |

Details: [test-report](test-report.md). Tests that are not done yet (a 48-hour soak, a real full disk) are listed there too.

Source: reports/qa-tests.md, reports/disk-full.md, reports/text-fuzz.md, reports/soak.md, reports/help-coverage.md.
