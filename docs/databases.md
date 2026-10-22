# Databases and the data folder

> Where KarelaDB keeps databases, how to name them, and CREATE DATABASE, DROP DATABASE, SHOW DATABASES and USE.

- Category: Databases & folders
- Keywords: database, data folder, PURGE TRASH, PURGE TRASH ALL, data directory, --data-dir, KARELADB\_DATA\_DIR, default database, \_trash, trash, database name, folder path, CREATE DATABASE, IF NOT EXISTS, DROP DATABASE, IF EXISTS, SHOW DATABASES, USE, switch database, many databases, kdb.lock, wal\_archive, WAL\_ARCHIVE, old log, log archive, KARELADB\_WAL\_ARCHIVE\_MB, RESULT\_CACHE, result cache per database, MEMORY\_LIMIT, MEMORY\_RESERVED, memory per database, database\_memory, per-column loads, partial\_loads, BRANCH OF, branch, clone database
- See also: [Quick start](quick-start.md), [CREATE TABLE](create-table.md), [SHOW TABLES, COLUMNS, CREATE TABLE](show-tables.md), [Users and roles](users-and-roles.md), [Backup, check, repair and restore](backup-and-safety.md), [kareladb serve](cli-serve.md), [Queries across databases](cross-database-queries.md), [Time travel and branches: SELECT ... AS OF, CREATE DATABASE ... BRANCH OF](as-of-and-branches.md)

A **database** is one folder with its own tables, views, triggers and procedures. KarelaDB keeps many databases in one **data folder**: one sub-folder per database. `kareladb serve` without a database name serves all of them.

A real setup: one database for market prices, one for the accounting app, one for the forum.

**Example: Three databases for three apps**

```sql
CREATE DATABASE market;
CREATE DATABASE accounts;
CREATE DATABASE forum;
SHOW DATABASES;
```

Result:

`CREATE DATABASE market`

```text
database 'market' created
```

`CREATE DATABASE accounts`

```text
database 'accounts' created
```

`CREATE DATABASE forum`

```text
database 'forum' created
```

`SHOW DATABASES`

| name (STRING) | tables (LONG) | bytes (LONG) | current (BOOL) |
|---|---|---|---|
| accounts | 0 | 0 | false |
| demo | 0 | 0 | true |
| forum | 0 | 0 | false |
| market | 0 | 0 | false |

(4 rows)

<a id="data-folder"></a>

## The data folder

Syntax:

```sql
kareladb <command> --data-dir <folder> ...
KARELADB_DATA_DIR=<folder>
<folder of kareladb.exe>\data
```

KarelaDB looks for the data folder in this order. The first one that is set wins:

| # | Where | Example |
|---|---|---|
| 1 | the option `--data-dir <folder>` | `kareladb serve --data-dir E:\kdb-data` |
| 2 | the environment variable `KARELADB_DATA_DIR` | `$env:KARELADB_DATA_DIR = "E:\kdb-data"` |
| 3 | the folder `data` next to the `kareladb` program | `D:\KarelaDB\build\bin\data` |

KarelaDB creates the folder when it is missing.

```text
E:\kdb-data\              <- the data folder
E:\kdb-data\default\      <- the database "default" (kareladb shell without a name uses it)
E:\kdb-data\market\        <- the database "market"
E:\kdb-data\_trash\       <- dropped databases (kept until PURGE TRASH ALL)
```

- **Notes:** use `KARELADB_DATA_DIR` when the data must be on another disk, or when `kareladb.exe` is in a folder where you cannot write (like `C:\Program Files`). To set it for good on Windows: `[Environment]::SetEnvironmentVariable("KARELADB_DATA_DIR", "E:\kdb-data", "User")`, then open a new PowerShell window.
- **Notes:** never change files inside a database folder by hand. Only one program can open a database at a time (the file `kdb.lock` shows this).

**Command line: A shell on a data folder: make a database and list them**

```bash
kareladb shell --data-dir my-data
> CREATE DATABASE market;
> SHOW DATABASES;
```

Output:

```text
KarelaDB 0.2.0-dev shell on default (data folder my-data)
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> database 'market' created
kareladb> name    | tables | bytes | current
--------+--------+-------+--------
default |      0 |     0 | true   
market  |      0 |     0 | false  
(2 rows, 0.2 ms)
kareladb>
```

<a id="names"></a>

## Database names and folder paths

Syntax:

```sql
name        letters, digits, _ and -   (1 to 64 characters)
.\folder    a path: always that folder
```

A database name has only letters `a-z A-Z`, digits, `_` and `-`, and is 1 to 64 characters long. Upper and lower case do not matter: `Market` and `market` are the same database. The folder keeps the spelling you used first.

| Not allowed | Why |
|---|---|
| `my shop`, `my.shop`, `नेपाल` | only letters a-z, digits, `_` and `-` |
| `_trash` | the folder for dropped databases |
| `_system` | the folder where KarelaDB keeps its users |
| `CON`, `PRN`, `AUX`, `NUL`, `COM0`-`COM9`, `LPT0`-`LPT9` | device names on Windows |

Commands like `kareladb sql` and `kareladb shell` take a **name** or a **path**:

| You write | KarelaDB uses |
|---|---|
| a name, and the data folder has that database | that database |
| a name, and the data folder does not have it | the folder with that name in the **current** folder (made when missing) |
| a path with `\`, `/`, `:` or `.` (`.\market`, `D:\kdb\market`) | always that folder |

- **Notes:** a command that opened a database by its **path** cannot create or drop databases. SQL names in quotes do not help: `CREATE DATABASE "my shop"` is still refused.

**Example: A name with a dot** (shows an error)

```sql
CREATE DATABASE my.shop;
```

Result:

Error: `line 1, column 19: unexpected '.' after CREATE DATABASE`

**Example: A reserved folder name** (shows an error)

```sql
CREATE DATABASE _trash;
```

Result:

Error: `line 1, column 17: bad database name '_trash': '_trash' is where dropped databases are kept`

**Command line: A name that is not in the data folder means a folder here**

```bash
kareladb sql shop "CREATE TABLE products (id INT PRIMARY KEY, name STRING)"
kareladb sql .\shop "SHOW TABLES"
```

Output:

`> kareladb sql shop "CREATE TABLE products (id INT PRIMARY KEY, name STRING)"`

```text
table 'products' created
```

`> kareladb sql .\shop "SHOW TABLES"`

```text
name     | kind       | partition | columns | rows
---------+------------+-----------+---------+-----
products | relational | NONE      |       2 |    0
(1 row, 0.0 ms)
```

<a id="create-database"></a>

## CREATE DATABASE

Syntax:

```sql
CREATE DATABASE [IF NOT EXISTS] name [WITH (pg_compat = on | off, encryption = on | off)]
```

Makes a new, empty database folder in the data folder. With `IF NOT EXISTS`, a database that is already there is not an error.

| Argument | Type | Meaning |
|---|---|---|
| `name` | database name | see [names](#names) |
| `pg_compat` | on / off | PostgreSQL 14's answers in this database ([PostgreSQL protocol](postgres-protocol.md)) |
| `encryption` | on / off | every file of the database is encrypted; needs the server's master key ([encryption at rest](encryption.md)). Default `off` |

- **Returns:** the message `database 'name' created` (`... created encrypted` with `encryption = on`), or `database 'name' already exists` with `IF NOT EXISTS`.
- **Notes:** `IF NOT EXISTS` never changes a database that is there: a plain one stays plain. Encryption is chosen only here; `ALTER DATABASE` cannot switch it.
- **Notes:** needs a data folder: it works in `kareladb shell`, in `kareladb sql` with a database name, and in `kareladb serve` started without a folder path. With users, only a user with `ROLE admin` may run it ([users and roles](users-and-roles.md)).
- **Notes:** an empty folder with that name becomes the database. A folder with other files in it is refused.
- **Notes:** `CREATE DATABASE test BRANCH OF live [AS OF ...]` makes a full, writable copy of another database in a moment, sharing its files ([branches](as-of-and-branches.md#branch)).

**Example: Safe to run again with IF NOT EXISTS**

```sql
CREATE DATABASE IF NOT EXISTS accounts;
CREATE DATABASE IF NOT EXISTS accounts;
SHOW DATABASES;
```

Result:

`CREATE DATABASE IF NOT EXISTS accounts`

```text
database 'accounts' created
```

`CREATE DATABASE IF NOT EXISTS accounts`

```text
database 'accounts' already exists
```

`SHOW DATABASES`

| name (STRING) | tables (LONG) | bytes (LONG) | current (BOOL) |
|---|---|---|---|
| accounts | 0 | 0 | false |
| demo | 0 | 0 | true |

(2 rows)

**Example: Upper and lower case are the same database** (shows an error)

```sql
CREATE DATABASE Forum;
CREATE DATABASE forum;
```

Result:

```text
database 'Forum' created
```

Error: `database 'Forum' already exists`

<a id="drop-database"></a>

## DROP DATABASE

Syntax:

```sql
DROP DATABASE [IF EXISTS] name
```

Closes the database and **moves** its folder to `<data folder>/_trash/<time in ms>-<name>`. KarelaDB never deletes the files. With `IF EXISTS`, a database that is not there is not an error.

- **Returns:** `database 'name' dropped; its folder was moved to ...`.
- **Notes:** refused while another request or shell uses the database, or while another program has it open. To get it back: stop the server and move the folder back from `_trash`. When you are sure you do not need it, [PURGE TRASH ALL](#purge-trash) frees the space.
- **Notes:** dropping the database you are using leaves you with **no** database: the next statement needs `USE` first.
- **Notes:** with users, the grants on that database are removed too, so a new database with the same name does not give old rights back.
- **Notes:** the database's [timers](timers.md) are deleted too, so they never run in a new database of the same name.

**Example: Drop an old test database; the second DROP is not an error**

Setup:

```sql
CREATE DATABASE test_2025;
```

```sql
DROP DATABASE test_2025;
DROP DATABASE IF EXISTS test_2025;
SHOW DATABASES;
```

Result:

`DROP DATABASE test_2025`

```text
database 'test_2025' dropped; its folder was moved to kdb-data/_trash/1792666934850-test_2025
```

`DROP DATABASE IF EXISTS test_2025`

```text
database 'test_2025' does not exist
```

`SHOW DATABASES`

| name (STRING) | tables (LONG) | bytes (LONG) | current (BOOL) |
|---|---|---|---|
| demo | 0 | 0 | true |

(1 row)

**Example: Drop the database you are using** (shows an error)

Setup:

```sql
CREATE TABLE notes (id INT);
```

```sql
DROP DATABASE demo;
SHOW TABLES;
```

Result:

```text
database 'demo' dropped; its folder was moved to kdb-data/_trash/1792666934901-demo; no database is selected now (USE <name>)
```

Error: `no database is selected; choose one with USE <name>`

**Example: A database that is not there** (shows an error)

```sql
DROP DATABASE nothing;
```

Result:

Error: `database 'nothing' does not exist`

<a id="purge-trash"></a>

## PURGE TRASH

Syntax:

```sql
PURGE TRASH
PURGE TRASH ALL
```

Frees disk space. KarelaDB never deletes data on its own at once: it moves it to a `_trash` folder first. `PURGE TRASH` removes, for good, what is in the `_trash` folder of the **current database**. `PURGE TRASH ALL` does it for every `_trash` folder of the data folder, dropped databases too:

| Folder | What is in it | Emptied by | Without a purge |
|---|---|---|---|
| `<database>/_trash` | old copies of files after `TRUNCATE`, `DROP PARTITION`, `UPDATE`, checkpoints | `PURGE TRASH` in that database, or `PURGE TRASH ALL` | removed by itself after `trash_keep_hours` (1 hour): while the server runs, and when the database opens |
| `<data folder>/_trash` | dropped databases | `PURGE TRASH ALL` only | kept forever |

- **Returns:** `removed N folder(s) from the trash, freed 27.0 GB`.
- **Notes:** `PURGE TRASH` needs `ROLE admin` on the database. `PURGE TRASH ALL` needs the user's own `ROLE admin` (it acts on the whole server). Before 2026-09-25 plain `PURGE TRASH` emptied the whole server's trash.
- **Notes:** with no database selected (after dropping the one you used), `PURGE TRASH` is an error that points to `PURGE TRASH ALL`.
- **Notes:** tables and rows in use are not touched. Dropped **tables** stay: `UNDROP TABLE` still brings them back ([the trash](trash.md)). `PURGE TRASH ALL` does not open databases that are not open. A folder that is still in use is skipped and named in the message.
- **Notes:** a dropped database cannot be moved back from `_trash` after `PURGE TRASH ALL`.
- **Notes:** removing many gigabytes takes a while: minutes for a large trash, longer when the data folder is a Docker folder share on Windows. Only one `PURGE TRASH ALL` runs at a time; a second one meanwhile is refused with `PURGE TRASH is already running`.
- **Notes:** in the console: the **Tools** panel on the right, **Purge trash**, runs `PURGE TRASH ALL`. The dialog shows how long the purge has been running; it can be closed, and the result appears in the panel. **Save disk** on the Keep data page runs `PURGE TRASH` for one database.
- **Notes:** a database's own `_trash` (replaced files) also empties **by itself** while the server runs: every minute the database removes every folder older than `trash_keep_hours` (1 hour unless `kareladb.conf` or `KARELADB_TRASH_KEEP_HOURS` says otherwise), also while writes never stop. Beyond `trash_max_mb` (a quarter of the database's data, at least 256 MB, unless set; 0 = no limit) the oldest folders also go, whatever their age, until the trash fits. `PURGE TRASH` is for having the space back now.

**Example: Free this database's trash now**

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO ticks VALUES ('2026-09-24T10:00:00Z', 1.5);
```

```sql
TRUNCATE TABLE ticks;
PURGE TRASH;
```

Result:

`TRUNCATE TABLE ticks`

```text
1 table(s) truncated (1 row(s) removed)
```

`PURGE TRASH`

```text
removed 1 folder(s) from the trash, freed 388 bytes
```

**Example: Drop a test database, then free its space**

Setup:

```sql
CREATE DATABASE old_test;
```

```sql
DROP DATABASE old_test;
PURGE TRASH ALL;
```

Result:

`DROP DATABASE old_test`

```text
database 'old_test' dropped; its folder was moved to kdb-data/_trash/1792666935086-old_test
```

`PURGE TRASH ALL`

```text
removed 1 folder(s) from the trash, freed 604 bytes
```

<a id="purge-versions"></a>

## PURGE VERSIONS

Syntax:

```sql
PURGE VERSIONS [KEEP n]
```

Frees disk space in the current database by removing the **older versions** of its data files. Every checkpoint writes a data file anew and keeps the older versions (2 per file unless `keep_versions` in `kareladb.conf` or `KARELADB_KEEP_VERSIONS` says otherwise), so that a file found damaged can be repaired from one of them plus the log. On a table that is rewritten often they add up to more than the data itself. `PURGE VERSIONS` keeps `n` older versions per file (1 without `KEEP`, 0 to 10), moves the rest to the trash, and empties that trash at once.

- **Returns:** `N older file version(s) removed (3.9 GB), 1 kept per file; freed 3.9 GB from the trash`.
- **Notes:** needs `ROLE admin` on the database. The rows are untouched and the database stays consistent: the list of files is saved before anything moves. With `KEEP 0` a damaged file can only be repaired from a backup, so keep 1 unless space is short.
- **Notes:** in the console: the **Keep data** page, **Save disk** (runs `PURGE VERSIONS KEEP 1` and `PURGE TRASH`).

**Example: Keep one older copy of each file, free the rest**

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO ticks VALUES ('2026-09-10T10:00:00Z', 1.5);
```

```sql
PURGE VERSIONS KEEP 1;
```

Result:

```text
0 older file version(s) removed (0 bytes), 1 kept per file; freed 0 bytes from the trash
```

<a id="truncate-all-tables"></a>

## TRUNCATE ALL TABLES

Syntax:

```sql
TRUNCATE ALL TABLES
```

Empties every table of the current database in one `TRUNCATE ... CASCADE`, then removes what that took out of use from the database's `_trash` at once, so the space is free right away. Meant for test databases.

- **Returns:** `N table(s) truncated (M row(s) removed); freed 1.2 GB from the trash`.
- **Notes:** needs `ROLE admin` on the database. The tables, columns, indexes, views, triggers and procedures stay. Materialized views are emptied with their tables. Dropped tables and `_audit_log` keep their rows. No row triggers run, as with `TRUNCATE`.
- **Notes:** it cannot be undone: the old rows are not kept in the trash. Make a backup first if you may need them.
- **Notes:** on a big database it takes as long as `TRUNCATE` of every table, and other writers wait meanwhile. In the console: **Tools**, **Delete all data**.

**Example: Empty a test database but keep its tables**

Setup:

```sql
CREATE TABLE customers (id INT PRIMARY KEY, name STRING);
CREATE TABLE orders (id INT, customer INT REFERENCES customers(id), total DOUBLE);
INSERT INTO customers VALUES (1, 'Asha'), (2, 'Bikash');
INSERT INTO orders VALUES (10, 1, 99.5), (11, 2, 12.0);
```

```sql
TRUNCATE ALL TABLES;
SELECT count(*) FROM orders;
```

Result:

`TRUNCATE ALL TABLES`

```text
2 table(s) truncated (4 row(s) removed); freed 962 bytes from the trash
```

`SELECT count(*) FROM orders`

| count(*) (LONG) |
|---|
| 0 |

(1 row)

<a id="show-databases"></a>

## SHOW DATABASES

Syntax:

```sql
SHOW DATABASES
```

Lists the databases of the data folder.

| Column | Type | Meaning |
|---|---|---|
| `name` | `STRING` | database name |
| `tables` | `LONG` | number of tables |
| `bytes` | `LONG` | size of the data files |
| `current` | `BOOL` | `true` for the database your statements use now |

- **Notes:** with users, a user who is not an admin sees only the databases they may read. The web console has a **Database** list with the same data.

**Example: The size of each database**

Setup:

```sql
USE demo;
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
INSERT INTO brokers VALUES (58, 'Northgate Securities'), (45, 'Imperial Securities');
CREATE DATABASE forum;
```

```sql
SHOW DATABASES;
```

Result:

| name (STRING) | tables (LONG) | bytes (LONG) | current (BOOL) |
|---|---|---|---|
| demo | 1 | 674 | true |
| forum | NULL | 0 | false |

(2 rows)

<a id="use"></a>

## USE

Syntax:

```sql
USE name
```

The statements after `USE` run in that database.

| Where | How long `USE` lasts |
|---|---|
| `kareladb shell` | until the next `USE` |
| `kareladb sql` | until the end of the text you sent |
| HTTP `/exec` | until the end of that request; choose the database of a request with `db=<name>` |

- **Returns:** `using database 'name'`.
- **Notes:** `USE` of a database that does not exist is an error; `USE` does not create it. PostgreSQL has no `USE` (you connect to the other database); MySQL has the same statement.
- **Notes:** `USE` does not end an open `BEGIN ... COMMIT`. The transaction stays open in the first database until you go back there and `COMMIT` or `ROLLBACK`.

**Example: Make a table in another database**

Setup:

```sql
CREATE DATABASE forum;
```

```sql
USE forum;
CREATE TABLE posts (id LONG PRIMARY KEY AUTO, author STRING NOT NULL, body STRING NOT NULL);
SHOW DATABASES;
USE demo;
SHOW TABLES;
```

Result:

`USE forum`

```text
using database 'forum'
```

`CREATE TABLE posts (`

```text
table 'posts' created
```

`SHOW DATABASES`

| name (STRING) | tables (LONG) | bytes (LONG) | current (BOOL) |
|---|---|---|---|
| demo | 0 | 0 | false |
| forum | 1 | 270 | true |

(2 rows)

`USE demo`

```text
using database 'demo'
```

`SHOW TABLES`

| name (STRING) | kind (STRING) | partition (STRING) | columns (INT) | rows (LONG) |
|---|---|---|---|---|

(0 rows)

**Example: USE does not create a database** (shows an error)

```sql
USE shop;
```

Result:

Error: `database 'shop' does not exist; create it with CREATE DATABASE shop`

<a id="dialect"></a>

## ALTER DATABASE ... SET DIALECT

Syntax:

```sql
ALTER DATABASE <name> SET DIALECT = 'questdb'
ALTER DATABASE <name> SET DIALECT = 'postgres'
```

Says which SQL family this database should behave like when the two differ. The default is `'postgres'`. `'postgresql'`, `'kdb'` and `'default'` mean `'postgres'` too.

| Value | What changes |
|---|---|
| `'postgres'` (default) | `CAST(time AS LONG)` gives **milliseconds**; a plain `INSERT` of a row that is already there (by `DEDUP KEY`) is an error |
| `'questdb'` | `CAST(time AS LONG)` gives **microseconds**, as QuestDB does; a plain `INSERT` into a table with a `DEDUP KEY` **replaces** the old row, as QuestDB does |

- **Returns:** `database 'x' now reads SQL as ...`.
- **Notes:**
  - Needs a server admin. The setting is kept in the data folder (`_system`) and holds after a restart, so an app does not have to send it again.
  - It is **per database**, so a QuestDB app and a PostgreSQL app can share one server.
  - Set it before you move a QuestDB app over, so its `INSERT`s and its time maths keep the meaning they had.
  - A database that has this setting needs a KarelaDB that knows the `dialects` feature; an older KarelaDB refuses to open it (see [versions](versions.md)).

**Example: A QuestDB app: INSERT replaces a row with the same key**

Setup:

```sql
CREATE DATABASE questdb_app;
USE questdb_app;
CREATE TABLE live_ticks (time TIMESTAMP, symbol SYMBOL, ltp DOUBLE)
  TIMESERIES(time) PARTITION BY DAY DEDUP KEY (time, symbol);
```

```sql
ALTER DATABASE questdb_app SET DIALECT = 'questdb';
USE questdb_app;
INSERT INTO live_ticks VALUES ('2026-09-10T11:00:00Z', 'CITY', 512.5);
INSERT INTO live_ticks VALUES ('2026-09-10T11:00:00Z', 'CITY', 514.0);
SELECT * FROM live_ticks;
```

Result:

`ALTER DATABASE questdb_app SET dialect = 'questdb'`

```text
database 'questdb_app' now reads SQL as QuestDB does (plain INSERT replaces rows of a DEDUP KEY; CAST(time AS LONG) is microseconds)
```

`USE questdb_app`

```text
using database 'questdb_app'
```

`INSERT INTO live_ticks VALUES ('2026-09-10T11:00:00Z', 'CITY', 512.5)`

```text
1 row(s) inserted
```

`INSERT INTO live_ticks VALUES ('2026-09-10T11:00:00Z', 'CITY', 514.0)`

```text
0 row(s) inserted, 1 replaced
```

`SELECT * FROM live_ticks`

| time (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) |
|---|---|---|
| 2026-09-10T11:00:00.000Z | CITY | 514 |

(1 row)

**Example: Back to the PostgreSQL way**

Setup:

```sql
CREATE DATABASE questdb_app;
```

```sql
ALTER DATABASE questdb_app SET DIALECT = 'questdb';
ALTER DATABASE questdb_app SET DIALECT = 'postgres';
```

Result:

`ALTER DATABASE questdb_app SET dialect = 'questdb'`

```text
database 'questdb_app' now reads SQL as QuestDB does (plain INSERT replaces rows of a DEDUP KEY; CAST(time AS LONG) is microseconds)
```

`ALTER DATABASE questdb_app SET dialect = 'postgres'`

```text
database 'questdb_app' now reads SQL as PostgreSQL does
```

**Example: Only those two names** (shows an error)

```sql
ALTER DATABASE demo SET DIALECT = 'mysql';
```

Result:

Error: `line 1, column 35: SET dialect needs 'questdb' or 'postgres'`

<a id="wal-archive"></a>

## ALTER DATABASE ... SET WAL_ARCHIVE

Syntax:

```sql
ALTER DATABASE <name> SET WAL_ARCHIVE = '<size>'
ALTER DATABASE <name> SET WAL_ARCHIVE = OFF
ALTER DATABASE <name> SET WAL_ARCHIVE = DEFAULT
```

Says how much **old log** a database keeps in its `wal_archive` folder. Old log is only used to repair a damaged file and by backups. Your tables do not need it: the data is in the data files and the current log.

| Value | Meaning |
|---|---|
| `'100MB'`, `'1GB'`, `'512 MB'`, `'1.5 GB'` | keep up to this much; the oldest files are removed beyond it |
| `250` (a number without a unit) | megabytes |
| `OFF` | keep no old log |
| `DEFAULT` | follow the server default again |

The server default is 1 GB. Change it on the console's [Settings page](console-settings.md#wal-archive), or with `wal_archive_mb` in `kareladb.conf` or `KARELADB_WAL_ARCHIVE_MB`.

- **Returns:** `database 'x' keeps at most 100 MB of old log in wal_archive`.
- **Notes:**
  - Needs a server admin. The setting is kept in the data folder (`_system`) and holds after a restart.
  - It works at once. A smaller size removes the oldest files now, not at the next checkpoint. Log that the current data files still need is never removed.
  - With `OFF`, a damaged data file can only be repaired from a **backup**. Keep it on if you have no backups.
  - A log file is 64 MB, so a size under 64 MB keeps few or no files.
  - In the console: the **Databases** panel, **Old log**. `/api/databases` shows each database's limit (`wal_archive_max_bytes`), where it comes from (`wal_archive_source`: `database` or `server`) and the size on disk now (`wal_archive_bytes`).

**Example: Keep only 100 MB of old log**

Setup:

```sql
CREATE DATABASE prices;
```

```sql
ALTER DATABASE prices SET WAL_ARCHIVE = '100MB';
```

Result:

```text
database 'prices' keeps at most 100 MB of old log in wal_archive
```

**Example: No old log, then back to the server default**

Setup:

```sql
CREATE DATABASE scratch;
```

```sql
ALTER DATABASE scratch SET WAL_ARCHIVE = OFF;
ALTER DATABASE scratch SET WAL_ARCHIVE = DEFAULT;
```

Result:

`ALTER DATABASE scratch SET WAL_ARCHIVE = OFF`

```text
database 'scratch' keeps no old log in wal_archive; a damaged file can now only be repaired from a backup
```

`ALTER DATABASE scratch SET WAL_ARCHIVE = DEFAULT`

```text
database 'scratch' keeps at most 1 GB of old log in wal_archive (the server default)
```

**Example: A size needs a unit KarelaDB knows** (shows an error)

```sql
ALTER DATABASE demo SET WAL_ARCHIVE = '100 XB';
```

Result:

Error: `line 1, column 39: SET WAL_ARCHIVE: unknown unit 'XB'; use KB, MB, GB or TB`

<a id="result-cache"></a>

## ALTER DATABASE ... SET RESULT_CACHE

Syntax:

```sql
ALTER DATABASE <name> SET RESULT_CACHE = '<size>'
ALTER DATABASE <name> SET RESULT_CACHE = OFF
ALTER DATABASE <name> SET RESULT_CACHE = DEFAULT
```

Gives a database a [result cache](performance-tips.md#result-cache) space of its **own**. Without it, all databases share the server's cache (`--cache-mb`, `cache_mb` in kareladb.conf, 256 MB by default), and a busy database's results can push out another's. Use it for the database behind a dashboard that must stay fast while other apps load data.

| Value | Meaning |
|---|---|
| `'512MB'`, `'1GB'`, `'1.5 GB'` | keep up to this much of this database's results, apart from the others |
| `128` (a number without a unit) | megabytes |
| `OFF` | keep no results of this database: every `SELECT` runs |
| `DEFAULT` | share the server's cache again |

- **Returns:** `database 'x' keeps up to 512 MB of query results in a space of its own; one result may use a quarter of it, a pinned one three quarters`.
- **Notes:**
  - Needs a server admin. The setting is kept in the data folder (`_system`) and holds after a restart.
  - It works at once. A smaller size drops the oldest results now.
  - `/api/databases` shows each database's size (`result_cache_bytes`) and where it comes from (`result_cache_source`: `database` or `server`). `/api/stats` shows `cache_own`.

**Example: A dashboard database with 512 MB of its own**

Setup:

```sql
CREATE DATABASE board;
```

```sql
ALTER DATABASE board SET RESULT_CACHE = '512MB';
```

Result:

```text
database 'board' keeps up to 512 MB of query results in a space of its own; one result may use a quarter of it, a pinned one three quarters
```

**Example: No cached results, then back to the shared cache**

Setup:

```sql
CREATE DATABASE loader;
```

```sql
ALTER DATABASE loader SET RESULT_CACHE = OFF;
ALTER DATABASE loader SET RESULT_CACHE = DEFAULT;
```

Result:

`ALTER DATABASE loader SET RESULT_CACHE = OFF`

```text
database 'loader' keeps no query results: every SELECT runs
```

`ALTER DATABASE loader SET RESULT_CACHE = DEFAULT`

```text
database 'loader' shares the server's result cache again (64 MB for all databases together)
```

<a id="memory"></a>

## ALTER DATABASE ... SET MEMORY_LIMIT and MEMORY_RESERVED

Syntax:

```sql
ALTER DATABASE <name> SET MEMORY_LIMIT = '<size>' | OFF | DEFAULT
ALTER DATABASE <name> SET MEMORY_RESERVED = '<size>' | OFF | DEFAULT
```

Gives a database its own part of the server's memory for table data ([`--memory`](performance-tips.md#memory)). Without them, all databases share it, and a big scan in one database can unload the tables another one reads all the time.

| Setting | Meaning |
|---|---|
| `MEMORY_LIMIT` | the most loaded data this database holds. Over it, its **own** partitions are unloaded first, even when `--memory` has room. |
| `MEMORY_RESERVED` | loaded data of this database that nothing else can unload: not another database, not the [process memory limit](cli-serve.md#memory-limit). Its own trims still keep to its `MEMORY_LIMIT`. |
| `OFF` | none for this database, whatever kareladb.conf says |
| `DEFAULT` | the value in kareladb.conf `database_memory`, or none |

- **Returns:** `database 'x' holds at most 512 MB of loaded partitions; over it, its own partitions are unloaded first`.
- **Notes:**
  - Needs a server admin. The settings are kept in the data folder (`_system`) and hold after a restart. They work at once.
  - A reservation cannot be more than the database's limit, and all reservations together at most three quarters of `--memory`.
  - kareladb.conf can set start values per database: `"database_memory": {"sales": {"limit_mb": 512, "reserved_mb": 128}}`.
  - `GET /api/stats` shows `used_bytes`, `limit_bytes`, `reserved_bytes` and `resident_bytes` in each database's `memory`.
  - To keep one table loaded whatever happens, use [`ALTER TABLE t SET (resident = on)`](alter-table.md#resident).

**Example: A dashboard database keeps its data loaded while a loader scans**

Setup:

```sql
CREATE DATABASE dash;
CREATE DATABASE loader;
```

```sql
ALTER DATABASE dash SET MEMORY_RESERVED = '32MB';
ALTER DATABASE loader SET MEMORY_LIMIT = '256MB';
```

Result:

`ALTER DATABASE dash SET MEMORY_RESERVED = '32 MB'`

```text
database 'dash' keeps 32 MB of its loaded partitions whatever other databases need
```

`ALTER DATABASE loader SET MEMORY_LIMIT = '256 MB'`

```text
database 'loader' holds at most 256 MB of loaded partitions; over it, its own partitions are unloaded first
```

**Example: Back to the shared budget**

Setup:

```sql
CREATE DATABASE scratch;
ALTER DATABASE scratch SET MEMORY_LIMIT = '64MB';
```

```sql
ALTER DATABASE scratch SET MEMORY_LIMIT = DEFAULT;
```

Result:

```text
database 'scratch' has no memory limit of its own (kareladb.conf): it shares the server's budget
```

<a id="per-column-loads"></a>

### Per-column loads

A column-engine query (sums, counts, `GROUP BY` and the like) on a partition that is not in memory reads **only the columns it names** from the file, plus the time column and the key columns. A sum of one column of a 20-column table reads and keeps about a tenth of the bytes, so the same memory holds many more partitions and a repeated query does not read its files again.

| What | What happens |
|---|---|
| a later query names more columns | those columns are read and added |
| a write, a checkpoint or a row read (`SELECT *`) | the whole partition is read first, and replaces the columns read apart |
| a partition with changes not yet in its file | read whole, as before |
| memory runs short | the columns read apart are unloaded like any loaded partition |

`GET /api/stats` counts these reads in `partial_loads` (part of `partition_loads`). Nothing to set: it is always on.
