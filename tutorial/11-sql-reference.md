# 11. SQL reference

- Category: Tutorial

## What you will learn

- The exact form of every KarelaDB statement.
- Every type, function and operator, with a short example.
- The time rules, reserved words and limits.

This is a short reference. Chapters 3 to 5 explain everything with longer examples. In the syntax, `[x]` means "x is optional", `a | b` means "a or b", and `...` means "more of the same".

The example results in this chapter are real. They come from `examples/11-sql-reference/`.

## General rules

| Rule | Detail |
|---|---|
| Statements | End with `;`. Many statements can be sent at once. Each one is saved on its own (statements between `BEGIN` and `COMMIT`, and a whole `CALL`, are saved together); KarelaDB stops at the first error. |
| Case | Keywords, table names, column names and function names do not care about case. Text values do (`'CITY'` is not `'city'`). |
| Names | Letters, digits, `_`, and non-English letters. A reserved word or a special name must be in double quotes: `"order"`. |
| Text | In single quotes: `'CITY'`. A quote inside is doubled: `'City''s'`. |
| Numbers | `42`, `-7`, `512.45`, `1.5e3`. Integers from -9223372036854775808 to 9223372036854775807. |
| Other constants | `TRUE`, `FALSE`, `NULL` |
| Comments | `-- to the end of the line` and `/* ... */` |
| Errors | Say where: `line 1, column 22: ...` |

## Statements

### Tables

```sql
CREATE TABLE [IF NOT EXISTS] name (
  column TYPE [PRIMARY KEY [AUTO]] [NOT NULL] [[CONSTRAINT name] UNIQUE] [DEFAULT expr]
              [[CONSTRAINT name] REFERENCES table[(column)] [ON DELETE action] [ON UPDATE action]]
              [ROUND interval] [AS (expr)] [[CONSTRAINT name] CHECK (condition)],
  ...
  [, [CONSTRAINT name] CHECK (condition) ...]
  [, [CONSTRAINT name] PRIMARY KEY (column, ...)]
  [, [CONSTRAINT name] UNIQUE (column, ...)]
  [, [CONSTRAINT name] FOREIGN KEY (column, ...) REFERENCES table (column, ...) [ON DELETE action] [ON UPDATE action]]
)
[TIMESERIES(time_column)]
[PARTITION BY DAY | MONTH | YEAR | NONE]
[SORT BY (column, ...)]
[DEDUP KEY (column, ...)]
[TTL n HOURS | DAYS | WEEKS | MONTHS | YEARS]
[RECORDS];

DROP TABLE [IF EXISTS] name;
TRUNCATE [TABLE] name [, name ...];      -- removes every row at once; not inside BEGIN ... COMMIT
RENAME TABLE old TO new;
ALTER TABLE name ADD [COLUMN] column TYPE [rules];
ALTER TABLE name DROP [COLUMN] column;
ALTER TABLE name RENAME [COLUMN] old TO new;
ALTER TABLE name DROP PARTITION 'key' [, 'key' ...];
ALTER TABLE name DROP PARTITION OLDER THAN n DAYS | MONTHS | YEARS | ...;
ALTER TABLE name SET TTL n DAYS | ... | NONE;
ALTER TABLE name DEDUP ENABLE UPSERT KEYS (column, ...);   -- or DEDUP DISABLE; rewrites the rows
ALTER TABLE name ADD [CONSTRAINT cname] CHECK (condition);
ALTER TABLE name DROP CONSTRAINT cname;
-- PostgreSQL forms (chapter 22):
CREATE TABLE name AS SELECT ...;
ALTER TABLE [IF EXISTS] name action [, action ...];
  -- ADD [COLUMN] [IF NOT EXISTS] ..., DROP [COLUMN] [IF EXISTS] c [CASCADE],
  -- ALTER [COLUMN] c {SET DEFAULT expr | DROP DEFAULT | SET NOT NULL | DROP NOT NULL | TYPE type [USING expr]},
  -- ADD [CONSTRAINT n] {UNIQUE (...) | PRIMARY KEY (...) | FOREIGN KEY (...) REFERENCES ... | CHECK (...)} [NOT VALID],
  -- DROP CONSTRAINT [IF EXISTS] n, RENAME [COLUMN] a TO b, RENAME TO new

SHOW TABLES;
SHOW COLUMNS FROM name;
SHOW CREATE TABLE name;
SHOW VIEWS;
```

| Part | Rules |
|---|---|
| `TIMESERIES(col)` | Makes a time-series table. `col` is TIMESTAMP or DATE. |
| `PARTITION BY` | Time-series only. Default `DAY`. Partition keys: `'2026'`, `'2026-09'`, `'2026-09-10'` (UTC). |
| `SORT BY` | Time-series only. Default: first SYMBOL column, then the time column. |
| `DEDUP KEY` | Time-series only. Must include the time column. |
| `TTL n DAYS` | Time-series only. Partitions whose last moment is older than that are dropped by themselves. `SET TTL NONE` stops it. `DROP PARTITION OLDER THAN` does the same once, now. |
| `TRUNCATE` | Removes every row, and keeps the table, its columns and indexes. Much faster than `DELETE FROM t`. Returns `1 table(s) truncated (57 row(s) removed)`. `ROLLBACK` cannot undo it, so it is refused inside `BEGIN` ... `COMMIT`. Needs the `write` role (`TRUNCATE ALL TABLES`: `admin`). |
| `RECORDS` | Says "relational table" explicitly. Cannot be used with TIMESERIES. |
| `PRIMARY KEY` | At most one per table. Implies NOT NULL. |
| `AUTO` | Integer PRIMARY KEY only. Next value from the table's counter, which only goes up (never reuses ids of deleted or rolled-back rows). |
| `DEFAULT` | A constant or `now()`. No column names. |
| `AS (expr)` | Computed column, not stored. Uses stored columns of the same row only. No DEFAULT, keys or REFERENCES. Cannot be set by INSERT/UPDATE. |
| `REFERENCES t(c)` | `t.c` must be PRIMARY KEY or UNIQUE and of the same kind of type. Checked on INSERT and UPDATE. Without `ON DELETE`, a referenced row cannot be deleted; a referenced table cannot be dropped. `REFERENCES t` means t's PRIMARY KEY. |
| `ON DELETE` / `ON UPDATE` | `NO ACTION` (default), `RESTRICT`, `CASCADE`, `SET NULL`, `SET DEFAULT`. All changes of a statement are one transaction. Chapter 22. |
| `PRIMARY KEY (a, b)` | Rows are stored by the key. |
| PostgreSQL type names | `SERIAL`, `VARCHAR(n)`, `NUMERIC(p,s)`, `UUID`, `TEXT[]`, ... See [Types](#types) and chapter 22. |
| `ROUND interval` | TIMESTAMP only. Cuts values down: `ROUND 1m`, `ROUND 1d`. |
| `CHECK (condition)` | Checked for every written row (INSERT, UPDATE, upserts, `InsertRows`, line protocol). A row where it is false is refused; NULL passes. Only stored columns of the same row and built-in functions. Name when not given: `table_column_check` / `table_check`. `ADD CHECK` refuses when a row already breaks it. Chapter 15. |
| `ADD COLUMN ... NOT NULL` | Needs a DEFAULT. |
| `DROP COLUMN` | Not for: the TIMESERIES column, SORT BY / DEDUP KEY columns, the PRIMARY KEY, referenced columns, columns used by computed columns or indexes, the only column. |

### Writing

```sql
[WITH name AS (query), ...]
INSERT [OR REPLACE | OR IGNORE] INTO table [AS alias] [(column, ...)]
VALUES (value, ...) [, (value, ...) ...] | SELECT ... | DEFAULT VALUES
[ON CONFLICT [(column, ...) [WHERE ...] | ON CONSTRAINT name]
   DO NOTHING | DO UPDATE SET column = expr, ... [WHERE condition]]      -- chapter 23
[RETURNING expr [[AS] alias], ... | *];

UPDATE table [[AS] alias] SET column = expr [, column = expr ...] [FROM source, ...] [WHERE condition] [RETURNING ...];

DELETE FROM table [[AS] alias] [USING source, ...] [WHERE condition] [RETURNING ...];
```

- `RETURNING` gives rows like a SELECT: the inserted rows (with AUTO ids and defaults), the rows after an UPDATE, the deleted rows.

- Values are constants or expressions without columns (`now()`, `1 + 1`, `CAST(...)`), and subqueries.
- `ON CONFLICT`, `UPDATE ... FROM`, `DELETE ... USING`, `WITH x AS (UPDATE ... RETURNING ...)` and subqueries (also correlated ones) in `SET` and `WHERE`: chapter 23.
- There is no `MERGE`. To empty a table, use `TRUNCATE` (see [Tables](#tables)).

### Queries

```sql
[WITH [RECURSIVE] name [(column, ...)] AS (query), ...]
SELECT [DISTINCT | DISTINCT ON (expr, ...)] expr [[AS] alias], ... | * | table.*
[FROM table | view | (SELECT ...) [[AS] alias [(column, ...)]] | (VALUES (...), ...) AS alias (column, ...)
   | unnest(array) [AS alias (column)] | [LEFT JOIN] LATERAL (SELECT ...) alias
   [[INNER] JOIN | LEFT [OUTER] JOIN  source ON condition]
   [ASOF JOIN source [ON condition]]
   [CROSS JOIN source | , source] ...]
[WHERE condition]
[LATEST ON time_column PARTITION BY column, ...]
[SAMPLE BY interval [FILL(NONE | NULL | PREV | LINEAR | constant)]
                    [ALIGN TO CALENDAR | ALIGN TO FIRST OBSERVATION]
                    [TIME ZONE 'zone'] [WITH OFFSET '+HH:MM']
                    [WEEK START SUNDAY | MONDAY]]
[GROUP BY expr, ...]
[HAVING condition]
[UNION [ALL] | INTERSECT [ALL] | EXCEPT [ALL]  SELECT ... ...]
[ORDER BY expr [ASC | DESC] [NULLS FIRST | NULLS LAST], ...]
[LIMIT n | ALL] [OFFSET m [ROWS]] [FETCH FIRST n ROWS ONLY]
[FOR UPDATE];                            -- locks the tables it reads until the transaction ends (chapter 15)

EXPLAIN SELECT ...;
```

| Rule | Detail |
|---|---|
| Implicit GROUP BY | With aggregates or SAMPLE BY and no GROUP BY, every select item without an aggregate is a group key. |
| SAMPLE BY | Time-series tables (or subqueries with a TIMESTAMP column). The output time is the bucket start. |
| SAMPLE BY intervals | `ms`, `s`, `m`, `h`, `d`, `w`, `M` (month), `y` (year). `m` = minute, `M` = month. |
| WEEK START | Only with a week interval. Default Monday. |
| ALIGN TO FIRST OBSERVATION | Not with TIME ZONE, WITH OFFSET, months or years. |
| FILL | Applies to all aggregate columns. Fills only between the first and last bucket with data. At most 10 million rows. |
| LATEST ON | One table, no joins. Runs after WHERE. |
| ASOF JOIN | Both sides need a time column. Takes the last right row at or before the left row's time. |
| ORDER BY | Output column name, alias, position (`ORDER BY 2`), or an expression. Default NULL position: NULLS LAST for ASC, NULLS FIRST for DESC. |
| UNION, INTERSECT, EXCEPT | Same number of columns. Without `ALL` the rows are distinct. `INTERSECT` goes before `UNION` and `EXCEPT`. ORDER BY / LIMIT at the end apply to all rows and must use output names or positions. |
| Subqueries | `(SELECT ...)` as a value (must return 0 or 1 row), `IN (SELECT ...)`, `EXISTS (SELECT ...)`, `FROM (SELECT ...)`, `LATERAL`. They may use outer columns (correlated); `inner.col = outer.col` becomes a hash lookup (chapter 23). |
| Aggregates | `agg(x) FILTER (WHERE cond)`, `array_agg(x ORDER BY y)`, `GROUP BY 1` (a select column), aggregates in ORDER BY and HAVING. |
| Window functions | With GROUP BY or SAMPLE BY they run over the groups, one row per group. Their arguments must be aggregates or group keys: `sma(last(close), 2)`, `rank() OVER (ORDER BY sum(volume) DESC)`. `sma(close, 2)` there is an error (`column 'close' is used by a window function in a query with aggregates, so it must be a key of the groups`). Not inside each other (`lag(sma(close, 3))`): use a subquery. |
| Big GROUP BY | When the groups need more than half of `--max-result-memory`, KarelaDB writes them to temporary files (`_tmp/` in the database folder) and adds them up after the scan. The result is the same, only slower. At most 16 GB of such files per query. |
| `SELECT` without `FROM` | Allowed: `SELECT 1 + 1`. |

### Views

```sql
CREATE [OR REPLACE] [CACHED] VIEW [IF NOT EXISTS] name AS [(] SELECT ... [)] [REFRESH ON COMMIT];
ALTER VIEW name AS SELECT ...;
REFRESH VIEW name;
DROP VIEW [IF EXISTS] name;
CREATE MATERIALIZED VIEW [IF NOT EXISTS] name [PARTITION BY DAY | MONTH | YEAR] [TTL n DAYS]
  AS SELECT time_bucket, ..., aggregates FROM table GROUP BY time_bucket, ...;
REFRESH MATERIALIZED VIEW name [FOR 'time' [TO 'time']];
DROP MATERIALIZED VIEW [IF EXISTS] name;
SHOW VIEWS;
```

| Kind | What it keeps |
|---|---|
| View | Nothing. Its query runs every time you use it. |
| `CACHED` view | Its rows, in memory. Made at `CREATE` and at `REFRESH VIEW`; with `REFRESH ON COMMIT` again at the first read after a commit changed one of its tables. `CREATE` says `view 'name' created (4 row(s) cached)`. |
| `MATERIALIZED` view | A real table with the result of a `GROUP BY` over one time-series table. After each commit, a background thread rebuilds only the partitions that changed. The `GROUP BY` must have a time bucket: the time column, `to_date(time)` or `date_trunc('day', time)`. |

`REFRESH ON COMMIT` needs `CACHED`. A view and a table cannot have the same name.

### Indexes and full-text search

Chapter 17 explains them with a forum and a news example.

```sql
CREATE [UNIQUE | FULLTEXT] INDEX [IF NOT EXISTS] name ON table (column, ...);
CREATE [UNIQUE] INDEX [CONCURRENTLY] [IF NOT EXISTS] [name] ON [ONLY] table [USING method]
  ({column | (expression)} [DESC] [NULLS LAST], ...) [WHERE condition];   -- PostgreSQL form, chapter 22
DROP INDEX [IF EXISTS] name;
SHOW INDEXES [FROM table];   -- columns: name, table, kind, columns, built, rows, memory_bytes, create_sql
```

| Rule | Detail |
|---|---|
| Name | Unique in the database. |
| Columns | 1 to 16 stored columns (not computed). Relational and time-series tables. |
| `UNIQUE` | Two rows cannot have the same values. NULL values never clash. Error: `duplicate value violates unique index 'name' on table 't': a row with col='value' already exists`. Creating it fails when rows already clash. |
| `FULLTEXT` | STRING, SYMBOL or JSON columns. Used by `MATCH(...)`, `search_rank(...)`. |
| Where the data lives | In memory only. `kareladb serve` builds it from the rows right after the database opens, on a background thread. In `kareladb sql`, `kareladb shell` and with `--warm-indexes off`, the first query that needs it builds it. `CREATE INDEX` builds it at once. Nothing on disk: crashes, `kareladb check`, `kareladb repair`, backups need nothing extra. |
| When a query uses an index | `col = value`, `col IN (...)`, `col IS NULL` on the first columns, then a range (`<`, `<=`, `>`, `>=`, `BETWEEN`, `LIKE 'abc%'`, `time IN '...'`, a row comparison) on the next column. `ORDER BY` the next columns (all ASC or all DESC) with `LIMIT` reads only the rows needed. `MATCH` uses a FULLTEXT index on the same columns. `EXPLAIN` shows `use index name (...)`. Also used by `UPDATE` and `DELETE`. |
| When it does not | A condition with `OR`, a function around the column, `!=`, `NOT LIKE`, a FLOAT column, text compared with a number, or when the index would read more than a quarter of the table. |
| `DROP COLUMN` | Refused while an index uses the column. `RENAME COLUMN` / `RENAME TABLE` keep the index. `DROP TABLE` drops its indexes. |
| Expression and partial | `(lower(email))`, `WHERE is_default`. A UNIQUE one is checked on every write. A non-unique one is used by a query that asks for the same thing: `lower(email) = 'a@x.np'`, or a `WHERE` that has every part of the index's own `WHERE`. |
| Not in a transaction | `CREATE INDEX` and `DROP INDEX` cannot be used between `BEGIN` and `COMMIT`. |

### Sequences

Chapter 22 explains them.

```sql
CREATE SEQUENCE [IF NOT EXISTS] name [INCREMENT [BY] n] [MINVALUE n] [MAXVALUE n] [START [WITH] n] [[NO] CYCLE];
ALTER SEQUENCE name [RESTART [WITH n]] [INCREMENT [BY] n] ...;
DROP SEQUENCE [IF EXISTS] name [, ...];
SELECT nextval('name'), currval('name'), setval('name', n [, is_called]), lastval();
```

A number is never given twice, also after a crash. `currval` and `lastval` are per session.

### PostgreSQL schema statements

`CREATE SCHEMA`, `CREATE EXTENSION` (pgcrypto, uuid-ossp, citext, plpgsql, pg_trgm, btree_gin, btree_gist, unaccent) and `COMMENT ON` are accepted and change nothing. `DO $$ BEGIN ... END $$` runs `IF`, `RAISE` and SQL statements. The views `information_schema.tables`, `.columns`, `.table_constraints`, `.key_column_usage`, ... and `pg_class`, `pg_attribute`, `pg_indexes`, `pg_constraint`, ... describe the database. Chapter 22.

### Functions, procedures and triggers

Chapter 13 explains them with examples.

```sql
CREATE [OR REPLACE] FUNCTION name(param TYPE, ...) [RETURNS TYPE] AS (expression);
DROP FUNCTION [IF EXISTS] name;
SHOW FUNCTIONS;                         -- columns: name, arguments, returns, definition

CREATE [OR REPLACE] PROCEDURE name(param TYPE, ...) AS BEGIN
  statement; ...
END;
CALL name(argument, ...) [WITH DEBUG];
DROP PROCEDURE [IF EXISTS] name;
SHOW PROCEDURES;                        -- columns: name, arguments, definition

CREATE [OR REPLACE] TRIGGER name {BEFORE | AFTER} {INSERT | UPDATE | DELETE} ON table
  EXECUTE {CALL procedure(argument, ...) | INSERT ... | UPDATE ... | DELETE ... | BEGIN statement; ... END};
ALTER TABLE table {ENABLE | DISABLE} TRIGGER name;
DROP TRIGGER [IF EXISTS] name;
CREATE [OR REPLACE] TRIGGER name AFTER INSERT ON table DEFERRED [TIMEOUT 10min] EXECUTE ...;
RETRY TRIGGER QUEUE name;               -- a DEFERRED trigger: run the failed job again
SKIP TRIGGER JOB name job_id;           -- a DEFERRED trigger: leave one job out
SHOW TRIGGERS;                          -- columns: name, table, timing, event, enabled, definition
```

Statements inside a procedure or trigger body (each ends with `;`):

```sql
SELECT ... | INSERT ... | UPDATE ... | DELETE ... | CALL name(...) | SHOW ... | EXPLAIN ...
DECLARE variable TYPE [DEFAULT expr]
SET variable = expr                     -- also: SET variable = (SELECT ...)
IF condition THEN ... [ELSIF condition THEN ...] [ELSE ...] END IF
WHILE condition DO ... END WHILE
FOR row IN (SELECT ...) DO ... END FOR  -- row.column is a value of the current row
DECLARE cursor CURSOR FOR SELECT ...
OPEN cursor
FETCH cursor INTO variable, ...        -- sets the variable FOUND
CLOSE cursor
RETURN
RAISE expr                              -- error: the whole CALL (or statement) is undone
PRINT expr                              -- a line in the "print" (or "debug") result
```

| Rule | Detail |
|---|---|
| Function body | One expression using only its parameters. No subqueries, aggregates or window functions. Not in computed columns. The name cannot be a built-in function. |
| Names in a body | A column name wins over a variable or parameter with the same name. |
| `CALL` | One transaction. Its SELECTs return extra results; `PRINT` adds a `print` result; `WITH DEBUG` adds a `debug` result (step, routine, statement, rows, time_us, changes). |
| Triggers | Once per statement (also once per `InsertRows` call and `POST /write` request), in the same transaction. The body reads the tables `NEW` and `OLD`. |
| `DEFERRED` | Only `AFTER INSERT`. Runs after the commit, as a background job of the server; the insert does not wait. Chapter 13. |
| `DROP TABLE`, `RENAME TABLE` | Refused while the table has triggers. |

### Transactions and cursors

```sql
BEGIN [TRANSACTION | WORK];
COMMIT [TRANSACTION | WORK];
ROLLBACK [TRANSACTION | WORK];

DECLARE name CURSOR FOR SELECT ...;     -- runs the query and keeps the rows
FETCH [NEXT [n] | ALL] FROM name;       -- NEXT without n = 1 row
CLOSE name;
```

| Rule | Detail |
|---|---|
| Scope | A transaction and a cursor end with the text they were sent in (`kareladb sql`, `/exec`, the web console). In a session (`kareladb shell`, `POST /session` + `X-KDB-Session`, a PostgreSQL connection) they stay open over many requests. A text without a session that ends without `COMMIT` is rolled back with an error. |
| Errors | A failing statement rolls back the whole open transaction. In a session, only `ROLLBACK` (or `COMMIT`, which then fails) is accepted after that. |
| Many writers | Writers of different tables run at the same time; writers of the same table take turns: they wait up to 5 s (`table 'x' is busy`), and two transactions that would wait for each other get `deadlock` at once. Readers see the committed rows. An idle transaction is rolled back after 30 s. Chapter 15. |
| Not in a transaction | `CREATE`, `DROP`, `ALTER`, `RENAME`, `TRUNCATE`, `BACKUP DATABASE`. |
| HTTP | `POST /cursor`, `GET /cursor/<id>?fetch=N`, `DELETE /cursor/<id>` (chapter 8). |

### Database

```sql
BACKUP DATABASE;          -- needs --backups <folder> on kareladb serve / shell / sql
CHECK TABLE any_name;     -- reads every file of the whole database
```

`CHECK TABLE` checks **all** files; the table name is not used.

### Databases

A **database** is a folder in the **data folder** (chapter 1). Each database has its own tables, views, triggers and procedures.

```sql
CREATE DATABASE [IF NOT EXISTS] name;
DROP DATABASE [IF EXISTS] name;     -- closes it and moves its folder to <data folder>/_trash
SHOW DATABASES;                     -- columns: name, tables, bytes, current
USE name;                           -- the statements after it use this database
SELECT ... FROM other_db.table ...; -- read a table of another database on the same server
```

| Rule | Detail |
|---|---|
| Names | Letters, digits, `_` and `-`, 1 to 64 characters. `Market` and `market` are the same database. The folder keeps the name as you first wrote it. Not allowed: `_trash` and the Windows device names `CON`, `PRN`, `AUX`, `NUL`, `COM0`-`COM9`, `LPT0`-`LPT9`. |
| `DROP DATABASE` | Refused while another request or shell uses the database. Nothing is deleted: the folder moves to `_trash/<time in ms>-<name>`. To get it back, stop the server and move the folder back. |
| `database.table` | Reads a table of another database: `SELECT`, joins, subqueries, `INSERT INTO t SELECT ...`, `CREATE TABLE t AS SELECT ...`. A statement only changes the database it runs in. Works over HTTP, the PostgreSQL port, `kareladb shell` and the console. |
| `USE` | In `kareladb shell`: stays until the next `USE`. Over HTTP: only for the rest of that request; choose the database of a request with `db=<name>` (chapter 8). |
| Where they work | `kareladb shell` and `kareladb sql` with a database name (or no name), and `kareladb serve` with a data folder. A command that opened one folder by its **path** (`kareladb serve D:\kdb\market`) cannot create or drop databases. |

```powershell
@"
CREATE DATABASE IF NOT EXISTS market;
CREATE DATABASE demo;
USE demo;
CREATE TABLE notes (id INT PRIMARY KEY, text STRING);
SHOW DATABASES;
USE market;
DROP DATABASE demo;
DROP DATABASE IF EXISTS demo;
SHOW DATABASES;
"@ | kareladb shell --data-dir kdb-data
```

```text
KarelaDB 0.2.0-dev shell on default (data folder kdb-data)
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> database 'market' created
kareladb> database 'demo' created
kareladb> using database 'demo'
kareladb> table 'notes' created
kareladb> name    | tables | bytes | current
--------+--------+-------+--------
default |      0 |     0 | false
demo    |      1 |   229 | true
market  |      0 |     0 | false
(3 rows, 0.1 ms)
kareladb> using database 'market'
kareladb> database 'demo' dropped; its folder was moved to kdb-data/_trash/1789135960212-demo
kareladb> database 'demo' does not exist
kareladb> name    | tables | bytes | current
--------+--------+-------+--------
default |      0 |     0 | false
market  |      0 |     0 | true
(2 rows, 0.0 ms)
kareladb>
```

### Users and roles

Users of the KarelaDB server (chapter 16). They belong to the data folder, not to one database.

```sql
CREATE USER [IF NOT EXISTS] name [WITH] PASSWORD 'secret' [ROLE admin|write|read|none];
ALTER USER name [WITH] PASSWORD 'new secret';
ALTER USER name ROLE read;
DROP USER [IF EXISTS] name;
SHOW USERS;                                              -- columns: name, role, grants, created, changed
GRANT read|write|admin|ALL ON DATABASE db TO name;       -- ALL = admin
REVOKE [read|write|admin|ALL] ON DATABASE db FROM name;
```

| Role | Statements |
|---|---|
| `read` | `SELECT`, `SHOW`, `EXPLAIN`, `BEGIN`/`COMMIT`/`ROLLBACK`, `DECLARE`/`FETCH`/`CLOSE` |
| `write` | + `INSERT`, `UPDATE`, `DELETE` (also with `RETURNING`), `TRUNCATE`, `CALL`, `SELECT ... FOR UPDATE` |
| `admin` | + `CREATE`/`ALTER`/`DROP`/`RENAME` of tables, views, indexes, functions, procedures, triggers; `BACKUP DATABASE`; `CHECK TABLE` |
| ROLE `admin` (own role) | + `CREATE`/`DROP DATABASE`, all user statements |

| Rule | Detail |
|---|---|
| Names | letters, digits, `_` and `-`, 1 to 63 characters; not case sensitive |
| Passwords | 8 to 1024 bytes. Shown as `'***'` in every statement KarelaDB shows back. |
| First user | must have `ROLE admin`. From then on the server asks for a login. |
| Last admin | cannot be dropped or lose ROLE admin while other users exist |
| Own password | every user may run `ALTER USER <own name> WITH PASSWORD '...'` |
| `SHOW USERS` | never shows passwords or hashes; a user who is not an admin sees only their own row |
| `kareladb shell`, `kareladb sql` | open the files directly and do not check users |

## Types

| Type | Also written | Size | Range | NULL stored as |
|---|---|---|---|---|
| `BOOL` | `BOOLEAN` | 1 byte | `TRUE`, `FALSE` | special value |
| `BYTE` | | 1 byte | -127 to 127 | -128 |
| `SHORT` | | 2 bytes | -32767 to 32767 | -32768 |
| `INT` | `INTEGER` | 4 bytes | -2147483647 to 2147483647 | smallest value |
| `LONG` | `BIGINT` | 8 bytes | -9223372036854775807 to 9223372036854775807 | smallest value |
| `FLOAT` | | 4 bytes | about ±3.4e38, 7 digits | NaN |
| `DOUBLE` | | 8 bytes | about ±1.8e308, 15 digits | NaN |
| `DECIMAL(s)` | | 8 bytes | exact; value × 10^s must fit in LONG; s = 0..18 | smallest value |
| `DATE` | | 4 bytes | days since 1970-01-01 | smallest value |
| `TIMESTAMP` | | 8 bytes | milliseconds since 1970-01-01 UTC | smallest value |
| `SYMBOL` | | 4 bytes | repeated text | special value |
| `STRING` | `VARCHAR`, `TEXT` | length + text | UTF-8 text, at most 16 MB | special length |
| `JSON` | `JSONB` | length + text | checked JSON, stored without extra spaces, at most 16 MB | special length |
| `BYTES` | `BYTEA`, `BLOB` | length + bytes | any bytes (also zero bytes), at most 16 MB; written `X'0A0B'` or `'\x0a0b'`, shown as `\x0a0b` | special length |

Chapter 18 explains JSON and BYTES with examples.

PostgreSQL type names are accepted too, with their rules: `SMALLINT`, `SERIAL`/`BIGSERIAL` (the PRIMARY KEY with AUTO), `REAL`, `DOUBLE PRECISION`, `NUMERIC(p,s)` (DECIMAL(s), p digits checked), `NUMERIC` (DOUBLE), `MONEY`, `VARCHAR(n)`/`CHAR(n)` (STRING, at most n characters), `TIMESTAMPTZ` (TIMESTAMP), `TIME` (STRING `HH:MM:SS`), `INTERVAL` (LONG milliseconds), `UUID` (STRING, checked), `INET`, `CITEXT`, `type[]` (JSON array). The full table is in chapter 22.

### Conversions (when a value goes into a column, or with CAST)

| Into | Accepts |
|---|---|
| integers | whole numbers, whole DOUBLE values (`5.0`), text like `'42'`, `TRUE`/`FALSE`. Out of range → error. |
| DOUBLE, FLOAT | numbers, text like `'512.5'` |
| DECIMAL(s) | numbers and text with at most `s` digits after the point. More digits → error (use `round(x, s)`). |
| TIMESTAMP | time text (see time rules), DATE, a number (milliseconds) |
| DATE | `'2026-09-10'`, time text (the UTC date is kept), TIMESTAMP |
| BOOL | `TRUE`/`FALSE`, `1`/`0`, `'true'`/`'false'` |
| STRING, SYMBOL | anything (written as text) |
| JSON | JSON text (checked; bad JSON → error with the position), numbers, `TRUE`/`FALSE` |
| BYTES | `X'0A0B'`, text `'\x0a0b'` (hex), other text (its UTF-8 bytes) |

`CAST(x AS TYPE)` and `x::TYPE` are the same. `CAST(x AS DECIMAL(2))` needs the scale.

## Operators

From loose (evaluated last) to tight (evaluated first):

| Level | Operators |
|---|---|
| 1 | `OR` |
| 2 | `AND` |
| 3 | `NOT` |
| 4 | `=` `==` `!=` `<>` `<` `<=` `>` `>=`, `IS [NOT] NULL`, `[NOT] IN`, `[NOT] BETWEEN`, `[NOT] LIKE`, `[NOT] ILIKE` |
| 5 | `+` `-` `\|\|` |
| 6 | `*` `/` `%` |
| 7 | unary `-` |
| 8 | `::` cast, `->` `->>` (JSON), `( )`, values, columns, function calls, `CASE`, `CAST` |

```sql
SELECT 2 + 3 * 4 AS a, (2 + 3) * 4 AS b, -2 * 3 AS c, 1 = 1 OR 1 = 2 AND 1 = 3 AS d, NOT 1 = 2 AND 2 = 2 AS e;
```

```text
a,b,c,d,e
14,20,-6,true,true
```

| Operator rule | Example | Result |
|---|---|---|
| `/` always gives a decimal number | `7 / 2` | `3.5` |
| Division or `%` by zero gives NULL | `5 / 0` | NULL |
| Integer overflow switches to DOUBLE | | |
| TIMESTAMP ± number = milliseconds added | `CAST('2026-09-10T11:00:00+05:45' AS TIMESTAMP) + 60000` | `2026-09-10T05:16:00.000Z` |
| TIMESTAMP - TIMESTAMP = milliseconds | `'2026-09-10T11:05:00Z'::TIMESTAMP - '2026-09-10T11:00:00Z'::TIMESTAMP` | `300000` |
| DATE ± number = days added | | |
| Text compared with TIMESTAMP/DATE is read as a time | `time >= '2026-09-01'` | |
| Text is joined with `\|\|` (not `+`); NULL on either side gives NULL | `'CITY' \|\| '-' \|\| 1` | `CITY-1` |
| `LIKE`: `%` any text, `_` one character (also one letter of any language), `\` before `%` or `_` means the letter itself, case matters | `'COAST' LIKE 'C_AST'` | `true` |
| `ILIKE`: like `LIKE`, but English letters match in any case | `'City' ILIKE 'CIT%'` | `true` |
| `json -> 'key'`, `json -> 0`: a part of a JSON value (as JSON); `->>` gives it as text | `'{"a": [5]}' -> 'a' ->> 0` | `5` |
| Row comparison: `(a, b) < (x, y)` means `a < x OR (a = x AND b < y)`; also `<=` `>` `>=` `=` `!=`, any number of values | `(2, 5) < (2, 7)` | `true` |

### NULL and logic

```sql
SELECT coalesce(NULL, 'n/a') AS coalesce, nullif(5, 5) AS nullif, NULL + 1 AS null_plus, NULL = NULL AS null_eq,
       NULL IS NULL AS is_null, TRUE AND NULL AS and_null, TRUE OR NULL AS or_null, NOT FALSE AS not_false,
       3 BETWEEN 1 AND 5 AS between_1_5, 'COAST' IN ('CITY', 'COAST') AS in_list, 1 <> 2 AS not_equal;
```

```text
coalesce,nullif,null_plus,null_eq,is_null,and_null,or_null,not_false,between_1_5,in_list,not_equal
n/a,,,,true,,true,true,true,true,true
```

(Empty CSV fields are NULL.) NULL in arithmetic or comparison gives NULL. WHERE and HAVING treat NULL as false. Use `IS NULL`.

## Functions

### Math

| Function | Meaning | Example | Result |
|---|---|---|---|
| `abs(x)` | absolute value | `abs(-3.5)` | `3.5` |
| `round(x)`, `round(x, d)` | round (half away from zero) to d decimals | `round(512.456, 2)`, `round(512.5)` | `512.46`, `513` |
| `floor(x)` | round down | `floor(5.7)` | `5` |
| `ceil(x)`, `ceiling(x)` | round up | `ceil(5.2)` | `6` |
| `sqrt(x)` | square root (NULL for negative) | `sqrt(16)` | `4` |
| `pow(x, y)`, `power(x, y)` | x to the power y | `pow(2, 10)` | `1024` |
| `exp(x)` | e to the power x | `exp(0)` | `1` |
| `ln(x)`, `log(x)` | natural log (NULL for ≤ 0) | `ln(1)` | `0` |
| `log(base, x)` | log with a base | `log(2, 8)` | `3` |
| `log10(x)` | log base 10 | `log10(1000)` | `3` |
| `sign(x)` | -1, 0 or 1 | `sign(-7)` | `-1` |
| `mod(x, y)` | remainder (same as `%`) | `mod(10, 3)` | `1` |
| `greatest(a, b, ...)` | biggest (NULLs ignored) | `greatest(3, 9, 4)` | `9` |
| `least(a, b, ...)` | smallest (NULLs ignored) | `least(3, 9, 4)` | `3` |

More math, finance and price functions (`trunc`, `cbrt`, `log2`, `gcd`, `lcm`, `factorial`, `pi`, trigonometry, `width_bucket`, `clamp`, `safe_divide`, `div0`, `percent`, `random`, `setseed`, `normal_cdf`, `normal_inv`, `round_tick`, `pivot_point`, `pivot_level`, `cagr`, `fv`, `pv`, `pmt`, `nper`, `npv`, `irr`) are in [chapter 19](19-analysis-functions.md#part-5-scalar-functions).

### Text

| Function | Meaning | Example | Result |
|---|---|---|---|
Text functions count **characters**, so text in any language works (`length('नेपाल')` is `5`). A NULL argument gives NULL (except `concat`, `concat_ws`, `coalesce`).

| Function | Meaning | Example | Result |
|---|---|---|---|
| `upper(s)` | upper case (English letters; other letters stay) | `upper('city')` | `CITY` |
| `lower(s)` | lower case | `lower('CITY')` | `city` |
| `length(s)`, `char_length(s)` | number of characters (BYTES: number of bytes) | `length('नेपाल')` | `5` |
| `octet_length(s)` | number of bytes | `octet_length('नेपाल')` | `15` |
| `substr(s, start [, len])`, `substring(...)` | part of the text; start counts from 1 | `substr('CITY-1', 1, 4)` | `CITY` |
| `left(s, n)`, `right(s, n)` | first / last n characters (negative n: all but n) | `left('CITY', 2)` | `CI` |
| `trim(s [, chars])`, `ltrim`, `rtrim`, `btrim` | remove spaces (or the given characters) at the ends | `trim('xxNICAxx', 'x')` | `COAST` |
| `replace(s, from, to)` | replace all | `replace('CITY-1', '-1', '')` | `CITY` |
| `split_part(s, sep, n)` | field n (1 = first, -1 = last) | `split_part('2082/83', '/', 2)` | `83` |
| `strpos(s, part)`, `position(part IN s)` | where part starts (1 = first character), 0 = not found | `strpos('CITY', 'TY')` | `3` |
| `starts_with(s, p)`, `ends_with(s, p)` | true if s starts / ends with p | `starts_with('CITY-1', 'CIT')` | `true` |
| `lpad(s, n [, fill])`, `rpad(...)` | fill to n characters (cut if longer) | `lpad('7', 3, '0')` | `007` |
| `repeat(s, n)`, `reverse(s)` | repeat n times; characters backwards | `repeat('ab', 2)` | `abab` |
| `concat(a, b, ...)` | join as text (NULLs skipped) | `concat('CITY', '-', 1)` | `CITY-1` |
| `concat_ws(sep, a, b, ...)` | join with a separator (NULLs skipped) | `concat_ws(', ', 'a', NULL, 'b')` | `a, b` |
| `regexp_like(s, pattern [, 'i'])` | true when the regular expression matches (`'i'`: any case) | `regexp_like('CITY', '^C[A-Z]+$')` | `true` |
| `regexp_substr(s, pattern [, 'i'])` | the first match, or NULL | `regexp_substr('EPS 12.50', '\d+\.\d+')` | `12.50` |
| `regexp_count(s, pattern [, 'i'])` | number of matches | `regexp_count('a1b22', '\d+')` | `2` |
| `regexp_replace(s, pattern, new [, flags])` | replace the first match; flag `g` = every match; `\1` in new = group 1 | `regexp_replace('a1b2', '\d', '#', 'g')` | `a#b#` |
| `coalesce(a, b, ...)` | first value that is not NULL | `coalesce(NULL, 'n/a')` | `n/a` |
| `nullif(a, b)` | NULL if a = b, else a | `nullif(5, 5)` | NULL |

Regular expressions: `.` `[abc]` `[^abc]` `[a-z]` `\d` `\w` `\s` `\b` `^` `$` `(...)` `(?:...)` `a|b` `*` `+` `?` `{n,m}` (and lazy `*?`). `\w` also matches letters of other languages. Back references and look-ahead are not supported. KarelaDB never backtracks, so no pattern can hang the server.

### JSON and BYTES

Chapter 18 has examples. A path looks like `'$.a.b[0]'`, `'$.items[-1]'` (last) or `'$."key with spaces"'`.

| Function | Meaning |
|---|---|
| `json(text)`, `CAST(text AS JSON)` | check text and make it JSON |
| `json_valid(text)` | true when the text is valid JSON |
| `json_extract(j, path)` | the part at path, as JSON (NULL if missing) |
| `json_value(j, path)` | the part as a value: text, LONG, DOUBLE or BOOL (NULL for objects, arrays, null) |
| `json_value_text` / `json_value_double` / `json_value_long` / `json_value_bool(j, path)` | the part as that type (NULL if it does not fit) |
| `json_type(j [, path])` | `object`, `array`, `string`, `number`, `boolean`, `null` |
| `json_array_length(j [, path])`, `json_keys(j [, path])` | number of elements; the keys as a JSON array |
| `json_object(k, v, ...)`, `json_array(v, ...)`, `to_json(v)` | build JSON from values |
| `json_set(j, path, v, ...)`, `json_insert`, `json_replace`, `json_remove(j, path, ...)`, `json_array_append(j, path, v)` | change JSON (for UPDATE) |
| `hex(x)`, `unhex(text)` | bytes to hex text and back |
| `to_base64(x)`, `from_base64(text)`, `encode(bytes, 'hex'\|'base64')`, `decode(text, 'hex'\|'base64')` | base64 and hex |

### Full-text search

Chapter 17 has examples. They work with or without a FULLTEXT index (without one, every row is read).

| Function | Meaning |
|---|---|
| `MATCH(col, ..., 'words')` | true when the text of the columns has every word. `'"exact phrase"'` = words next to each other; `'hydro*'` = a word that starts with hydro; `'-loan'` = rows with this word are left out |
| `search_rank(col, ..., 'words')` | how well the row matches (BM25; higher is better, 0 when it does not match) |
| `highlight(col, ..., 'words')` | the text with the found words in `<b>` and `</b>` |

Words: letters and digits of any language (English, Nepali). English letters are made lower case, Devanagari digits become 0-9, punctuation (also `।` and `॥`) separates words, and a number like `12.5` stays one word.

### Time

All of these work in **UTC**. Arguments can be TIMESTAMP, DATE or time text.

| Function | Meaning | Example | Result |
|---|---|---|---|
| `now()`, `systimestamp()` | current time (the same for the whole statement) | `now()` | `2026-09-11T08:45:59.939Z` |
| `year(t)` `month(t)` `day(t)` | parts of the UTC date | `year('2026-09-10T08:30:15Z')` | `2026` |
| `hour(t)` `minute(t)` `second(t)` | parts of the UTC time | `hour('2026-09-10T08:30:15Z')` | `8` |
| `day_of_week(t)` | 0 = Sunday ... 6 = Saturday | `day_of_week('2026-09-11')` | `5` |
| `is_trading_day(t)` | true for Sunday to Thursday (UTC date; holidays are not known) | `is_trading_day('2026-09-11')` | `false` |
| `date_trunc(unit, t)` | cut down to `year`, `quarter`, `month`, `week` (Sunday), `day`, `hour`, `minute`, `second`, `ms` | `date_trunc('week', '2026-09-10T08:30:00Z')` | `2026-09-06T00:00:00.000Z` |
| `extract(field FROM t)`, `date_part('field', t)` | `year`, `quarter`, `month`, `week`, `day`, `dow`, `isodow`, `doy`, `hour`, `minute`, `second`, `epoch`, ... | `extract(dow FROM '2026-09-11')` | `5` |
| `dateadd(unit, n, t)` | add n units: `y`, `month`, `w`, `d`, `h`, `m`, `s`, `ms` (day clamped at month end) | `dateadd('month', 1, '2026-01-31')` | `2026-02-28T00:00:00.000Z` |
| `datediff(unit, a, b)` | whole units from a to b: `y`, `month`, `w`, `d`, `h`, `m`, `s`, `ms` (months and years by the calendar) | `datediff('m', '2026-09-10T11:00:00+05:45', '2026-09-10T15:00:00+05:45')` | `240` |
| `to_timestamp(x)` | text or number (ms) to TIMESTAMP | `to_timestamp('2026-09-10T11:00:00+05:45')` | `2026-09-10T05:15:00.000Z` |
| `to_date(x)` | to DATE (UTC date) | `to_date('2026-09-10T20:00:00Z')` | `2026-09-10` |
| `to_char(t, format [, zone])` | time as text: `YYYY` `YY` `MM` `Mon` `Month` `DD` `DDD` `Dy` `Day` `D` `HH24` `HH12` `MI` `SS` `MS` `AM` `Q` (quarter), `"text"`; zone like `'+05:45'` or `'Asia/Kathmandu'` | `to_char('2026-09-10T08:30:00Z', 'YYYY-MM-DD HH24:MI', '+05:45')` | `2026-09-10 14:15` |

Nepal clock: `hour(time + 20700000)` (20700000 ms = 5 h 45 min).

Also in [chapter 19](19-analysis-functions.md#dates-for-reports): `age`, `quarter`, `day_of_year`, `week_of_year`, `last_day`, `make_date`, `make_timestamp`, `fiscal_year`, `fiscal_quarter`, `nepal_fiscal_year`.

### Aggregates

Used in SELECT with GROUP BY, SAMPLE BY or alone; also with `OVER (...)`.

| Function | Meaning |
|---|---|
| `count(*)` | number of rows |
| `count(x)` | rows where x is not NULL |
| `count(DISTINCT x)`, `count_distinct(x)` | number of different values |
| `sum(x)` | total (stays integer or DECIMAL when the inputs are) |
| `avg(x)` | average |
| `min(x)`, `max(x)` | smallest, biggest (numbers, text, times) |
| `first(x)`, `last(x)` | value of the earliest / latest row by time |
| `median(x)` | middle value |
| `percentile(x, p)` | p = 0.9 or 90 |
| `stddev(x)`, `stddev_samp(x)` | sample standard deviation |
| `stddev_pop(x)` | population standard deviation |
| `variance(x)`, `var_samp(x)`, `var_pop(x)` | variance |
| `vwap(price, volume)` | sum(price × volume) / sum(volume) |

```sql
SELECT count(*) AS count_all, count(close) AS count_close, count(DISTINCT symbol) AS count_distinct,
       count_distinct(symbol) AS count_distinct2, sum(volume) AS sum, round(avg(close), 3) AS avg,
       min(close) AS min, max(close) AS max, first(close) AS first, last(close) AS last
FROM ochl_day WHERE time IN '2026-09-10';
SELECT round(stddev(close), 3) AS stddev, round(stddev_pop(close), 3) AS stddev_pop, round(variance(close), 3) AS variance,
       round(var_pop(close), 3) AS var_pop, median(close) AS median, percentile(close, 0.9) AS p90,
       round(vwap(close, volume), 3) AS vwap
FROM ochl_day WHERE time IN '2026-09-10';
```

```text
count_all,count_close,count_distinct,count_distinct2,sum,avg,min,max,first,last
3,3,3,3,410710,357.4,191.2,504.9,504.9,191.2
stddev,stddev_pop,variance,var_pop,median,p90,vwap
157.684,128.748,24864.19,16576.127,376.1,479.14,414.832
```

Aggregates ignore NULL values. `count()` without `*` is the same as `count(*)`.

More aggregates are in [chapter 19](19-analysis-functions.md#part-1-aggregates) (row engine only):

| Group | Functions |
|---|---|
| Correlation, regression | `corr`, `covar_pop`, `covar_samp`, `regr_slope`, `regr_intercept`, `regr_r2`, `regr_count`, `regr_avgx`, `regr_avgy`, `regr_sxx`, `regr_syy`, `regr_sxy`, `beta`, `alpha` |
| Shape | `skewness` (`skew`), `skewness_pop`, `kurtosis` (`kurt`), `kurtosis_pop`, `geomean`, `harmonic_mean`, `mode`, `percentile_cont`, `percentile_disc` (also `... WITHIN GROUP (ORDER BY x)`), `median_abs_deviation` (`mad`), `iqr`, `range`, `entropy` |
| Conditions, picking rows | `count_if`, `sum_if`, `avg_if`, `bool_and` (`every`), `bool_or`, `arg_min` (`min_by`), `arg_max` (`max_by`), `approx_count_distinct`, `sum_of_squares`, `product`, `weighted_avg`, `twap` |
| Lists | `string_agg`, `listagg`, `array_agg` (`json_agg`) |
| Risk, money | `sharpe_ratio`, `sortino_ratio`, `calmar_ratio`, `information_ratio`, `max_drawdown`, `value_at_risk`, `expected_shortfall`, `xnpv`, `xirr` |

### Series and window functions

Used in SELECT only. Without `OVER`, series functions run over all result rows in time order.

| Function | Meaning |
|---|---|
| `sma(x, n)` | simple moving average of n rows |
| `ema(x, n)` | exponential moving average (starts with SMA of the first n rows) |
| `rsi(x, n)` | Wilder's RSI (0-100) |
| `atr(high, low, close, n)` | Wilder's average true range |
| `lag(x [, k [, default]])` | value k rows before (default 1); `default` instead of NULL when there is no such row |
| `lead(x [, k [, default]])` | value k rows after |
| `pct_change(x)` | (x - previous) / previous × 100 |
| `cumsum(x)` | running total |
| `row_number()` | 1, 2, 3, ... |
| `rank()` | rank with gaps (1, 1, 3) |
| `dense_rank()` | rank without gaps (1, 1, 2) |
| any aggregate `OVER (...)` | aggregate over a window |

```sql
fn(...) OVER ([PARTITION BY expr, ...] [ORDER BY expr [ASC|DESC], ...] [frame])

frame:  ROWS n PRECEDING | ROWS UNBOUNDED PRECEDING
      | {ROWS | RANGE} BETWEEN start AND end
start, end:  UNBOUNDED PRECEDING | n PRECEDING | CURRENT ROW | n FOLLOWING | UNBOUNDED FOLLOWING
             (RANGE: n is a number, or text like '5 days' for a time ORDER BY)
```

The period `n` must be a whole number, 1 or more.

More window and series functions are in [chapter 19](19-analysis-functions.md): `percent_rank`, `cume_dist`, `ntile`, `first_value`, `last_value`, `nth_value`, `cumprod`, `cummax`, `cummin`, returns and risk (`pct_return`, `log_return`, `cum_return`, `drawdown`, `volatility`, `zscore`, `minmax_scale`) and technical indicators (`wma`, `dema`, `tema`, `trima`, `kama`, `hma`, `vwma`, `macd`, `macd_signal`, `macd_hist`, `stoch_k`, `stoch_d`, `stochf_k`, `stochrsi_k`, `stochrsi_d`, `willr`, `cci`, `roc`, `rocp`, `rocr`, `mom`, `trix`, `natr`, `trange`, `bb_upper`, `bb_middle`, `bb_lower`, `bb_percent_b`, `bb_width`, `kc_upper`, `kc_middle`, `kc_lower`, `dc_upper`, `dc_middle`, `dc_lower`, `plus_di`, `minus_di`, `dx`, `adx`, `adxr`, `aroon_up`, `aroon_down`, `aroon_osc`, `sar`, `ichimoku_tenkan`, `ichimoku_kijun`, `ichimoku_senkou_a`, `ichimoku_senkou_b`, `ichimoku_chikou`, `obv`, `ad`, `cmf`, `adosc`, `mfi`, `efi`, `eom`, `supertrend`, `supertrend_direction`, `ha_open`, `ha_high`, `ha_low`, `ha_close`, `linearreg`, `linearreg_slope`, `linearreg_intercept`, `linearreg_angle`, `tsf`).

### Table functions and PIVOT

```sql
SELECT ... FROM generate_series(start, stop [, step]) [[AS] alias [(column)]]   -- numbers or times
SELECT ... FROM long_sequence(n)                                              -- column x = 1 .. n
SELECT ... FROM source PIVOT (agg(x) [AS name], ... FOR column IN (value [AS name], ...)) [[AS] alias]
```

Chapter 19 explains them ([Part 6](19-analysis-functions.md#part-6-tables-of-numbers-and-pivots)).

### Passwords, hashes and random values

| Function | Meaning | Example | Result |
|---|---|---|---|
| `password_hash(s)` | slow, salted hash for storing a password (PBKDF2-HMAC-SHA-256, 600,000 rounds) | `password_hash('secret')` | `$pbkdf2-sha256$i=600000$...` |
| `password_hash(s, n)` | the same with n rounds (1,000 to 10,000,000) | `password_hash('secret', 1000)` | `$pbkdf2-sha256$i=1000$...` |
| `password_verify(s, hash)` | does the password match the hash? (`false` for a damaged hash) | `password_verify('secret', password_hash)` | `true` |
| `sha256(s)` | SHA-256 as 64 hex characters | `sha256('abc')` | `ba7816bf...f20015ad` |
| `hmac_sha256(key, s)` | HMAC-SHA-256 as hex | `hmac_sha256('key', 'message')` | `6e9ef29b...` |
| `random_bytes(n)` | n random bytes (1 to 1024) as hex | `random_bytes(8)` | `6614740117d2ce39` |
| `random_token([n])` | n random bytes (default 32) as URL-safe base64 | `random_token()` | 43 characters |
| `gen_random_uuid()` | random UUID (version 4) | `gen_random_uuid()` | `0465d47f-8194-4c94-a372-eda3b70504a0` |

A NULL argument gives NULL. The random functions give a new value for every row and every call. `password_hash` and `password_verify` take about 0.05 to 0.4 seconds each: call `password_verify` once per login. `password_hash('...')` with a literal password in `INSERT ... VALUES` and `UPDATE ... SET` is hashed before the statement waits for the database, and the statement shown back contains the hash, not the password. Chapter 16 shows the register and login pattern.

### Other expressions

| Expression | Example |
|---|---|
| `CASE WHEN cond THEN a [WHEN ...] [ELSE b] END` | `CASE WHEN pct_change > 0 THEN 'up' ELSE 'down' END` |
| `CASE x WHEN v THEN a ... END` | `CASE symbol WHEN 'CITY' THEN 1 ELSE 0 END` |
| `CAST(x AS TYPE)`, `x::TYPE` | `CAST('512.5' AS DOUBLE)`, `'42'::INT` |
| `x [NOT] IN (a, b, ...)` | `symbol IN ('CITY', 'COAST')` |
| `t [NOT] IN 'interval'` | `time IN '2026-09'` |
| `x [NOT] BETWEEN a AND b` | `close BETWEEN 500 AND 510` |
| `EXISTS (SELECT ...)` | |
| `(SELECT ...)` | a single value |

## Time rules

| Rule | Detail |
|---|---|
| Storage | TIMESTAMP = milliseconds since 1970-01-01 **UTC**. DATE = days. |
| Output | Always UTC: `2026-09-10T05:15:00.000Z`, DATE as `2026-09-10`. |
| Time text | `YYYY-MM-DD`, then optional `T` or space and `HH`, `:MM`, `:SS`, `.fff`, then optional `Z` or `+HH:MM` / `+HHMM` / `-HH:MM`. |
| No zone | **UTC**. Nepal time must have `+05:45`. |
| More than 3 fraction digits | cut to milliseconds |
| Numbers | milliseconds since 1970 (UTC) |
| `time IN 'text'` | The whole year / month / day / hour / minute / second of the text, in UTC. |
| Partitions | by UTC date |
| `SAMPLE BY ... TIME ZONE` | the only place where KarelaDB computes in another time zone |
| `--until` of `kareladb restore` | local time of the computer |
| Backup folder names | UTC |

Time zones for `TIME ZONE` (fixed offsets only, no daylight saving): `UTC`, `GMT`, `Z`, `Etc/UTC`, `Asia/Kathmandu`, `Asia/Katmandu`, `NPT`, `Asia/Kolkata`, `Asia/Calcutta`, `IST`, `Asia/Colombo`, `Asia/Dhaka`, `Asia/Thimphu`, `Asia/Karachi`, `Asia/Dubai`, `Asia/Bangkok`, `Asia/Jakarta`, `Asia/Shanghai`, `Asia/Hong_Kong`, `Asia/Singapore`, `Asia/Taipei`, `Asia/Tokyo`, `Asia/Seoul`, or an offset like `'+05:45'`. Others are refused:

```sql
SELECT time, count(*) FROM ochl_minutes SAMPLE BY 1h TIME ZONE 'Europe/London';
```

```text
error: time zone 'Europe/London' is not supported (it may change for daylight saving); use a fixed offset like '+05:45'
```

## Reserved words

These words cannot be table, column or alias names without double quotes:

`ALTER` `AND` `AS` `BETWEEN` `CASE` `CREATE` `DEFAULT` `DELETE` `DISTINCT` `DROP` `ELSE` `END` `FALSE` `FROM` `GROUP` `IN` `INSERT` `INTO` `IS` `JOIN` `LIKE` `LIMIT` `NOT` `NULL` `ON` `OR` `ORDER` `PRIMARY` `REFERENCES` `SELECT` `SET` `TABLE` `THEN` `TO` `TRUE` `UNIQUE` `UPDATE` `VALUES` `WHEN` `WHERE`

```sql
CREATE TABLE orders (id INT, order STRING);
```

```text
error: line 1, column 30: expected a column name but found the reserved word 'order' (write it in double quotes, "order", to use it as a name)
```

```sql
CREATE TABLE orders (id INT, "order" STRING);
INSERT INTO orders VALUES (1, 'buy');
SELECT id, "order" FROM orders;
```

```text
table 'orders' created

1 row(s) inserted

id | order
---+------
 1 | buy  
(1 row, 0.1 ms)
```

These words **can** be names, but not a short alias without `AS` (write `AS left` then): `ASOF` `CROSS` `FULL` `HAVING` `INNER` `LATEST` `LEFT` `LT` `OVER` `REFRESH` `RIGHT` `SAMPLE` `SPLICE` `UNION` `USING`.

All other words (`time`, `date`, `timestamp`, `symbol`, `partition`, `open`, `close`, `volume`, `value`, `key`, ...) are normal names.

## Limits

| Limit | Value |
|---|---|
| DECIMAL scale | 0 to 18 |
| Nesting of expressions | 100 levels |
| Nesting of subqueries and views | 16 levels |
| Nesting of saved functions, of `CALL`, of triggers | 16 levels each |
| Rows changed in one transaction (`BEGIN`/`COMMIT`, `CALL`, statement with triggers) | 10 million |
| Rounds of one `WHILE` loop | 10 million |
| Open cursors | 16 per database; unused ones close after 10 minutes; 10 million rows each |
| Tables in one query | 63 |
| Rows made by FILL | 10 million |
| Rows returned by `kareladb sql` | 1000 in table format (`--max-rows`), no limit in csv/json |
| Rows returned by HTTP `/exec` | 10,000 by default, 1,000,000 at most |
| HTTP request body | 64 MB |
| One STRING, JSON or BYTES value | 16 MB (keep bigger files outside the database) |
| JSON nesting | 256 levels |
| Regular expression | 4096 bytes; `{n,m}` up to 1000 |
| Writers at the same time | one per table; writers of different tables run together |
| Readers at the same time | any number; a read never waits for an open transaction |
| Temporary files of one big GROUP BY | 16 GB |
| Programs with the database open | one |
| Number of partitions, rows, tables | no fixed limit |

## Correlated subqueries

```sql
SELECT s.symbol, (SELECT max(close) FROM ochl_day d WHERE d.symbol = s.symbol) AS best FROM securities s;
```

The subquery uses `s.symbol` of the outer row. KarelaDB does not run it once per row: it reads `ochl_day` once, groups it by `symbol`, and looks every security up in that result. Chapter 23 has the rules.

## Try it yourself

1. What is the result of `SELECT 10 / 4, 10 % 4, round(10 / 4)`?
2. Write the number of whole days between 2026-01-01 and 2026-09-10.
3. Which of these names need double quotes: `time`, `order`, `left`, `select`, `symbol`?

<details>
<summary>Answers</summary>

1. `2.5`, `2`, `3`.
2. `SELECT datediff('d', '2026-01-01', '2026-09-10')` gives `252`.
3. `order` and `select` always. `left` only as a short alias without `AS`. `time` and `symbol` never.

</details>

---

Next: [12. Troubleshooting](12-troubleshooting.md)
