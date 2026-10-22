# 2. Your first database

- Category: Tutorial

## What you will learn

- What is inside a KarelaDB database folder.
- How to use `kareladb shell` (type SQL) and `kareladb sql` (run SQL once).
- What the exit codes mean.

The examples use the database `market` with the sample data (see the quick start).

## A database is a folder

A KarelaDB database is **one folder**. You choose the name. When you open a folder that does not exist, KarelaDB creates a new empty database there.

```powershell
Get-ChildItem market -Name
```

```text
files
wal
wal_archive
_trash
kdb.lock
_manifest.a
_manifest.b
```

| Name | What it is |
|---|---|
| `files\` | The data files. One file for each table part (partition), plus the table list (catalog). |
| `wal\` | The write-ahead log. Every change goes here first. |
| `wal_archive\` | Old log files. Only backups and repairs use them. The oldest are deleted after 1 GB (changeable: `ALTER DATABASE ... SET WAL_ARCHIVE`, or `wal_archive_mb` in `kareladb.conf` for all databases). |
| `_trash\` | Old file versions. KarelaDB deletes them after 1 hour (`trash_keep_hours` in `kareladb.conf`, or `KARELADB_TRASH_KEEP_HOURS`). |
| `kdb.lock` | Only one program may open the database. This file is locked while it is open. |
| `_manifest.a`, `_manifest.b` | The list of current files. It is saved twice, for safety. |

Rules:

- **Do not change or delete files in the folder by hand.** Use `kareladb` commands.
- To copy a database, stop every program that uses it first. Better: use `kareladb backup` (chapter 9).
- Only **one program** can open a database at a time. While `kareladb serve` runs, `kareladb sql` on the same folder fails with "the database is open in another program". Use the server's HTTP API then (chapter 8).

## kareladb shell: type SQL

`kareladb shell <folder>` opens a prompt. Type SQL and end it with `;`. A statement can use many lines. The prompt `...>` means "the statement is not finished yet".

```text
PS D:\kdb-work> kareladb shell market
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> .help
  .tables              list tables
  .schema <table>      show CREATE TABLE
  .format table|csv|json
  .maxrows <n>         rows shown per query (0 = all)
  .check               read every file and report damage
  .backup              make a verified backup (needs --backups)
  .exit                quit
kareladb> .tables
name         | kind       | partition | columns | rows
-------------+------------+-----------+---------+-----
brokers      | relational | NONE      |       2 |    5
trade_log    | timeseries | DAY       |       8 |   32
live_data    | timeseries | DAY       |      12 |   12
ochl_day     | timeseries | YEAR      |       7 |   57
ochl_minutes | timeseries | MONTH     |       7 |  956
securities   | relational | NONE      |       3 |    5
(6 rows, 0.0 ms)
kareladb> SELECT symbol, close
...> FROM ochl_day
...> WHERE time IN '2026-09-10';
symbol | close
-------+------
CITY   | 504.9
COAST  | 376.1
VOLT   | 191.2
(3 rows, 0.4 ms)
kareladb> .format csv
kareladb> .schema brokers
create_sql
"CREATE TABLE brokers (
  id INT PRIMARY KEY,
  name STRING NOT NULL
)"
kareladb> SELECT id, name FROM brokers LIMIT 3;
id,name
1,Keystone Securities
34,Vision Securities
45,Imperial Securities
kareladb> .exit
```

### Shell commands

Shell commands start with a dot. They do **not** need `;`.

| Command | What it does |
|---|---|
| `.help` | Shows the commands |
| `.tables` | Lists the tables (same as `SHOW TABLES`) |
| `.schema <table>` | Shows the `CREATE TABLE` statement of a table |
| `.format table` / `csv` / `json` | How results are printed. `table` is the default. |
| `.maxrows <n>` | Shows at most `n` rows per query (default 1000). `0` = all rows. |
| `.check` | Reads every file and reports damage |
| `.backup` | Makes a backup. Start the shell with `--backups <folder>` first. |
| `.exit` or `exit` | Quits the shell. `Ctrl+C` also works. |

Tips:

- In `table` format, long text is cut after 48 characters (`...`). Use `.format csv` to see all of it, for example for `.schema`.
- Keywords and names do not care about case: `select` = `SELECT`, `OCHL_DAY` = `ochl_day`.
- Comments: `-- to the end of the line` and `/* inside */`.

## kareladb sql: run SQL once

`kareladb sql <folder> "SQL"` opens the database, runs the SQL, prints the result and closes the database. This is good for scripts.

```powershell
kareladb sql market "SELECT count(*) AS minute_rows FROM ochl_minutes"
```

```text
minute_rows
-----------
        956
(1 row, 0.5 ms)
```

### Many statements

Separate statements with `;`. KarelaDB prints one result for each statement, with an empty line between them.

```powershell
kareladb sql market "SELECT count(*) AS securities FROM securities; SELECT count(*) AS brokers FROM brokers"
```

```text
securities
----------
         5
(1 row, 0.2 ms)

brokers
-------
      5
(1 row, 0.1 ms)
```

If one statement fails, KarelaDB **stops** there. The statements before it are already saved. The statements after it do not run. See [chapter 4](04-writing-data.md#a-script-stops-at-the-first-error).

### SQL from a file

Write the SQL in a file. Then send the file into `kareladb sql` with a pipe. The `-` means "read the SQL from the pipe".

```powershell
@"
-- report.sql: closing prices on the last day
SELECT symbol, close
FROM ochl_day
WHERE time IN '2026-09-10'
ORDER BY close DESC;
"@ | Set-Content report.sql -Encoding UTF8

Get-Content report.sql -Raw | kareladb sql market -
```

```text
symbol | close
-------+------
CITY   | 504.9
COAST  | 376.1
VOLT   | 191.2
(3 rows, 0.2 ms)
```

- Use `-Raw`. It sends the file as one piece of text.
- If the file has text in another language (not English), see [chapter 7](07-command-line-and-scripts.md#non-english-text-utf-8).
- In `cmd.exe` and bash you can write `kareladb sql market - < report.sql`.

### Options of kareladb sql

| Option | Meaning |
|---|---|
| `--format table` | Text table (default) |
| `--format csv` | CSV, good for Excel and scripts |
| `--format json` | JSON, good for programs |
| `--max-rows N` | At most N rows per statement. Default: 1000 for `table`, no limit for `csv` and `json`. |
| `--backups <folder>` | Backup folder, needed for `BACKUP DATABASE` |

Chapter 7 shows the formats in detail.

## Exit codes

Every `kareladb` command ends with an exit code. Scripts use it to know if the command worked.

| Code | Meaning | Examples |
|---|---|---|
| `0` | OK | The query ran. The backup was made. No damage found. |
| `1` | Error | Wrong SQL. Duplicate key. The database is open in another program. Wrong arguments. |
| `2` | Damage | `kareladb check` found damage. A file could not be read. A repair could not fix everything. |
| `3` | Needs a newer KarelaDB | The database uses a stored-format feature this `kareladb` does not know. Nothing was changed. See chapter 24. |

In PowerShell the exit code is in `$LASTEXITCODE`:

```powershell
kareladb sql market "SELECT count(*) AS n FROM brokers"
"exit code: $LASTEXITCODE"
kareladb sql market "SELECT count(*) FROM brokerz"
"exit code: $LASTEXITCODE"
```

```text
n
-
5
(1 row, 0.2 ms)
exit code: 0
error: line 1, column 22: table or view 'brokerz' does not exist
exit code: 1
```

Error messages say **where** the problem is: `line 1, column 22` is the place of `brokerz` in the SQL. In bash the exit code is in `$?`.

`kareladb shell` ends with the exit code of the last statement or command you ran.

## Try it yourself

1. Open the shell on `market` and list the columns of `live_data`.
2. With one `kareladb sql` command, count the rows of `trade_log` and `live_data`.
3. Run `kareladb sql market "SELECT * FROM nothing"`. What is the exit code?

<details>
<summary>Answers</summary>

1. ```text
   kareladb> SHOW COLUMNS FROM live_data;
   ```
   (or `.schema live_data` after `.format csv`)
2. ```powershell
   kareladb sql market "SELECT count(*) AS trades FROM trade_log; SELECT count(*) AS snapshots FROM live_data"
   ```
   The answers are 32 and 12.
3. The exit code is `1`, because the table does not exist.

</details>

---

Next: [3. Tables](03-tables.md)
