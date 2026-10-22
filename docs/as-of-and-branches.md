# Time travel and branches: SELECT ... AS OF, CREATE DATABASE ... BRANCH OF

> Read a table as it was at an earlier time or commit, undo a bad change with one query, and make a full writable copy of a database in a moment, without copying its files.

- Category: Databases & folders
- Keywords: AS OF, AS OF TIMESTAMP, AS OF LSN, AS OF SYSTEM TIME, FOR SYSTEM\_TIME AS OF, time travel, flashback, read the past, table as it was, undo, undo a bad import, point in time, BRANCH OF, branch, clone, copy database, zero-copy, test copy, hard link, keep\_versions, KDB\_KEEP\_VERSIONS, no longer kept
- See also: [Databases and the data folder](databases.md), [Change stream and live subscriptions: changes('t'), GET /api/changes, GET /api/subscribe](change-stream.md), [Backup, check, repair and restore](backup-and-safety.md), [kdb serve](cli-serve.md), [The trash - UNDROP TABLE](trash.md)

KDB never changes a data file once it is written. Each checkpoint writes the changed files anew and keeps the older versions for a while. With those and the log, KDB can show a table **as it was**, and make a new database from another one **without copying** its files.

| You want | Write |
|---|---|
| a table as it was at a time | `SELECT ... FROM t AS OF TIMESTAMP '2026-09-25 14:30'` (or `AS OF '2026-09-25 14:30'`) |
| a table as it was after a commit | `SELECT ... FROM t AS OF LSN 12345` |
| undo a bad change | `INSERT OR REPLACE INTO t SELECT * FROM t AS OF TIMESTAMP '...'` |
| a copy of a database to try things on | `CREATE DATABASE test BRANCH OF live` |
| a copy of a database as it was | `CREATE DATABASE before BRANCH OF live AS OF TIMESTAMP '...'` |

<a id="as-of"></a>

## SELECT ... AS OF

Syntax:

```sql
SELECT ... FROM <table> AS OF TIMESTAMP <time> [[AS] alias] ...
SELECT ... FROM <table> AS OF LSN <commit lsn> [[AS] alias] ...
SELECT ... FROM <table> AS OF SYSTEM TIME <time>        -- CockroachDB's spelling
SELECT ... FROM <table> FOR SYSTEM_TIME AS OF <time>    -- SQL:2011's spelling
```

- `AS OF TIMESTAMP <time>`: the table with every change committed **at or before** that time (to the millisecond). The time is any expression: `'2026-09-25 14:30'`, `now() - INTERVAL '10 minutes'`. A time without a zone is read like any other time of the session.
- `AS OF LSN <n>`: the table with every transaction committed at or before log position `n`. `changes('t')` shows the commit LSN of each change ([change stream](change-stream.md)).
- Each table in a query has its own `AS OF`. The others are read as they are now, so a query can compare then and now:

```sql
-- Which prices did the 14:30 import change?
SELECT now.sym, before.price AS was, now.price AS is_now
FROM prices now
JOIN prices AS OF TIMESTAMP '2026-09-25 14:29' before ON before.sym = now.sym
WHERE before.price <> now.price;
```

Undo a bad change with one statement:

```sql
INSERT OR REPLACE INTO prices SELECT * FROM prices AS OF TIMESTAMP '2026-09-25 14:29';
CREATE TABLE prices_before AS SELECT * FROM prices AS OF LSN 1200345;
```

Good to know:

| | |
|---|---|
| columns | the table's columns **as they were**: a column added since is not there |
| a renamed table | found by its name now |
| a table made after the point | `table 't' did not exist yet AS OF ...` |
| a view | refused: read the tables it reads AS OF instead |
| rights | the user's rights on the table **now** (a user who may not read it now may not read it AS OF either) |
| writes | none: the past is read only, from the files where they are |
| speed | the first read of a point opens the table's files of that time and replays the log from the checkpoint before it. That copy is kept a minute, so asking the same point again (a chart) is fast |

<a id="how-far-back"></a>

## How far back

A read AS OF needs, for each file of the table, a version older than the point, and the log after it. Both are kept only for a while:

| What limits it | Kept | Set with |
|---|---|---|
| older versions of each table file | 2 per file | `keep_versions` in `kdb.conf`, `KDB_KEEP_VERSIONS` (0 to 10) |
| older versions of the catalog (the tables' definitions), views, routines, sequences | at least 16 | always (they are a few KB) |
| the old log | 1 GB | `ALTER DATABASE ... SET WAL_ARCHIVE`, `KDB_WAL_ARCHIVE_MB` |

So a table that changes often can be read back over its last few checkpoints, a table that rarely changes much further. A point that can no longer be rebuilt is **refused**, never answered with rows that were not there together. The error says why and the oldest point that still works:

```text
the data as of LSN 4 is no longer kept: an older version of its files was removed (keep_versions) ...
The oldest point it can be read at is LSN 14.
```

These also end a table's history, because their rows are in no file any more:

- a partition that became empty (all its rows deleted), `DROP PARTITION`, a TTL drop
- `TRUNCATE`, and `PURGE VERSIONS`
- a database last written by a KDB from before AS OF, or restored from a backup: its history starts at its next open for writing

<a id="branch"></a>

## CREATE DATABASE ... BRANCH OF

Syntax:

```sql
CREATE DATABASE [IF NOT EXISTS] <new> BRANCH OF <database>
CREATE DATABASE <new> BRANCH OF <database> AS OF TIMESTAMP <time>
CREATE DATABASE <new> BRANCH OF <database> AS OF LSN <commit lsn>
```

A branch is a **full, writable database** with every table, view, routine, sequence and row of `<database>`, as it is now or as it was at the point. Try a repair, a migration or a new release on real data, compare, then drop the branch (or swap it in: `POST /api/databases/swap`).

```sql
CREATE DATABASE market_test BRANCH OF market;
-- database 'market_test' created as a branch of 'market' at LSN 1204551 in 120 ms (401 data files shared, 0 copied)
USE market_test;
UPDATE ochl_day SET close = close * 1.1 WHERE symbol = 'ACME';   -- market is not touched
DROP DATABASE market_test;
```

| | |
|---|---|
| speed | the data files are **hard links**: made in a moment whatever their size, and no extra disk until either side changes a file |
| no hard links | a file system without them (some network or Docker folders) gets copies: same result, slower |
| independent | each database writes its own new files; writes, checkpoints and `DROP DATABASE` of one never change the other |
| what goes with it | the tables, views, routines, sequences, triggers and waiting trigger jobs; its SQL dialect and `pg_compat` |
| what does not | users' rights, `READ ONLY`, timers and pinned queries: they belong to names. Grant them on the branch if needed |
| who | a server admin (as `CREATE DATABASE`) |
| safety | the branch is made in a hidden folder and gets its name last, so a crash never leaves half a database. The source keeps running meanwhile |
