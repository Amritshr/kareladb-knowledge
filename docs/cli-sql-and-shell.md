# kareladb sql and kareladb shell

> Run SQL from the command line once (kareladb sql) or type it at a prompt (kareladb shell).

- Category: Command line
- Keywords: run SQL, script, stdin, pipe, .sql file, output format, CSV, JSON, prompt, REPL, dot command, .help, .tables, .schema, .format, .maxrows, .check, .backup, .exit, .quit, exit, quit, ...\>
- See also: [The kareladb program](cli-overview.md), [kareladb serve](cli-serve.md), [Transactions](transactions.md), [Backup, check, repair and restore (backup-database)](backup-and-safety.md#backup-database), [Loading many rows](loading-data.md)

`kareladb sql` opens a database, runs SQL, prints the results and closes the database. It is good for scripts.
`kareladb shell` opens a prompt. You type SQL, and it stays open until you quit.

Both open the database **files directly**. So only one program may use the database: while `kareladb serve` runs on it, use the server's console or HTTP API instead. Neither asks for a login (see [users and roles](users-and-roles.md)).

## kareladb sql

Syntax:

```sql
kareladb sql <db> "SQL" [--format table|csv|json] [--max-rows N] [--backups <dir>] [--memory <MB>] [--trash-days N] [--data-dir <folder>]
kareladb sql <db> - [options]        -- read the SQL from stdin (a pipe or a file)
```

Runs one or more SQL statements and prints one result per statement. Separate statements with `;`.
`<db>` is a database name in the data folder or a folder path (see [<db>](cli-overview.md#db-argument)).

| Option | Meaning | Default |
|---|---|---|
| `"SQL"` | The SQL text. Use `-` to read it from stdin (a pipe). | required |
| `--format table` | A text table for people. Numbers are right-aligned. Text longer than 48 characters is cut (`...`). | `table` |
| `--format csv` | CSV for Excel and scripts. The first line has the column names. | |
| `--format json` | One JSON array, one object per statement, for programs. | |
| `--max-rows N` | At most `N` rows per statement. `0` = no limit. | `1000` for `table`, no limit for `csv` and `json` |
| `--backups <dir>` | Backup folder. Needed for `BACKUP DATABASE`. Also used to repair damaged files when the database opens. | not set |
| `--memory <MB>` | Memory for table data kept loaded. | `512` |
| `--trash-days N` | `DROP TABLE` keeps the table this many days for `UNDROP TABLE` ([trash](trash.md)). `0` = remove at once. | `7` |
| `--data-dir <folder>` | The data folder (see [the data folder](cli-overview.md#data-folder)). | `KARELADB_DATA_DIR`, else `data` next to kareladb |

- **Exit code:** `0` when every statement worked. `1` when a statement failed (wrong SQL, duplicate key, ...) or the database is open in another program. `2` when a data file is damaged.
- **Stops at the first error.** The statements before it are done and saved. The statements after it do not run. The error goes to stderr.
- **Opens a new database:** a name or path that does not exist becomes a new, empty database. A typing mistake gives `table ... does not exist`.
- Every run opens and closes the database. For many small queries in a loop, one `kareladb serve` and HTTP is faster.
- The `(3 rows, 0.4 ms)` line in table format is the time KarelaDB needed (parse and run).

**Command line: One query** (sample data: sample)

```bash
kareladb sql market "SELECT symbol, close FROM ochl_day WHERE time IN '2026-09-10' ORDER BY close DESC"
```

Output:

```text
symbol | close
-------+------
CITY   | 504.9
COAST  | 376.1
VOLT   | 191.2
(3 rows, 0.3 ms)
```

**Command line: Many statements: one result each** (sample data: sample)

```bash
kareladb sql market "SELECT count(*) AS securities FROM securities; SELECT count(*) AS brokers FROM brokers"
```

Output:

```text
securities
----------
         5
(1 row, 0.2 ms)

brokers
-------
      5
(1 row, 0.0 ms)
```

**Command line: A script stops at the first error** (sample data: sample)

```bash
kareladb sql market "SELECT count(*) AS before FROM brokers; SELECT nope FROM brokers; SELECT 1 AS never_runs"
```

Output:

```text
before
------
     5
(1 row, 0.2 ms)
error: line 1, column 48: unknown column 'nope' (table 'brokers' has: id name)
```

exit code 1

<a id="formats"></a>

## Output formats: table, CSV, JSON

Syntax:

```sql
--format table | csv | json
```

| | table | csv | json |
|---|---|---|---|
| For | people | Excel, PowerShell `ConvertFrom-Csv` | programs, `ConvertFrom-Json` |
| NULL | `NULL` | an empty field | `null` |
| Times | UTC: `2026-09-10T05:15:00.000Z` | the same | the same, as text |
| DECIMAL | `10.50` | `10.50` | text `"10.50"` (to stay exact) |
| Messages like `1 row(s) inserted` | printed | **not** printed | in `"message"` |
| Rows | at most 1000 | all | all |

- **CSV:** text with a comma, a quote or a line break is put in double quotes. Many SELECTs give many CSV blocks, each with its own header line; use one SELECT per command when you save a file.
- **JSON fields:** `statement` (the SQL as KarelaDB understood it), `columns` (name and type), `rows` (a list of values per row), `rows_affected`, `message`, `truncated` (`true` when `--max-rows` cut rows).
- **Saving a file in Windows PowerShell 5.1:** `>` writes UTF-16. Use `| Set-Content prices.csv -Encoding UTF8` when another program must read the file.

**Command line: CSV for Excel and scripts** (sample data: sample)

```bash
kareladb sql market "SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol" --format csv
```

Output:

```text
symbol,ltp,pct_change
CITY,527.1,2.71
COAST,401.9,0.7
TELCO,897.7,1.9
VOLT,184,-0.86
```

**Command line: JSON for programs** (sample data: sample)

```bash
kareladb sql market "SELECT symbol, ltp FROM live_data LATEST ON timestamp PARTITION BY symbol LIMIT 2" --format json
```

Output:

```text
[{"statement":"SELECT symbol, ltp FROM live_data LATEST ON timestamp PARTITION BY symbol LIMIT 2","columns":[{"name":"symbol","type":"SYMBOL"},{"name":"ltp","type":"DOUBLE"}],"rows":[["CITY",527.1],["COAST",401.9]],"rows_affected":0,"message":"","truncated":false}
]
```

**Command line: --max-rows: only the first rows** (sample data: sample)

```bash
kareladb sql market "SELECT time, symbol, close FROM ochl_minutes" --max-rows 3
```

Output:

```text
time                     | symbol | close
-------------------------+--------+------
2026-09-09T05:15:00.000Z | CITY   | 512.1
2026-09-09T05:16:00.000Z | CITY   | 511.9
2026-09-09T05:17:00.000Z | CITY   | 511.9
(3 rows, more not shown, 0.3 ms)
```

`--max-rows` is a safety net for big results. When you want fewer rows, write `LIMIT` in the SQL: it says clearly what you want, and it works the same in the console and over HTTP.

```powershell
# PowerShell (not run here): CSV to objects. Every CSV value is text, so use [double] for numbers.
$rows = kareladb sql market "SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol" --format csv | ConvertFrom-Csv
$rows | Where-Object { [double]$_.pct_change -gt 1 }

# JSON to objects (Windows PowerShell 5.1 needs Out-String first).
$result = kareladb sql market "SELECT symbol, ltp FROM live_data LATEST ON timestamp PARTITION BY symbol" --format json | Out-String | ConvertFrom-Json
$result[0].rows
```

<a id="stdin"></a>

## SQL from a file or a pipe

Syntax:

```sql
Get-Content load.sql -Raw | kareladb sql <db> -       -- PowerShell
kareladb sql <db> - < load.sql                         -- cmd.exe, bash, zsh
kareladb sql <db> - <<'SQL' ... SQL                    -- bash here-document
```

With `-` instead of the SQL text, `kareladb sql` reads the whole input first and then runs it, like one long SQL text.

- Save `.sql` files as **UTF-8**. PowerShell's byte order mark at the start is skipped.
- **Windows PowerShell 5.1** sends pipe text as ASCII, so letters outside English (Nepali, Chinese, emoji) become `?`. Run `$OutputEncoding = New-Object System.Text.UTF8Encoding $false` first. PowerShell 7 already uses UTF-8.
- A big file is read into memory first. For millions of rows, split it into files of a few thousand rows per `INSERT`.

**Command line: SQL typed into kareladb sql - (the lines after > are the input)** (sample data: sample)

```bash
kareladb sql market -
> -- report.sql: closing prices on the last day
> SELECT symbol, close
> FROM ochl_day
> WHERE time IN '2026-09-10'
> ORDER BY close DESC;
```

Output:

```text
symbol | close
-------+------
CITY   | 504.9
COAST  | 376.1
VOLT   | 191.2
(3 rows, 0.3 ms)
```

```powershell
# The same from a real file (not run here)
Get-Content report.sql -Raw -Encoding UTF8 | kareladb sql market -
```

```bash
# bash (not run here)
kareladb sql market - < report.sql
kareladb sql market - <<'SQL'
SELECT count(*) AS trades FROM trade_log;
SQL
```

<a id="backup"></a>

## BACKUP DATABASE from kareladb sql

Syntax:

```sql
kareladb sql <db> "BACKUP DATABASE" --backups <dir>
```

`BACKUP DATABASE` needs a backup folder. Without `--backups` it fails with `no backup folder is set`.
For a database **name** in the data folder, the backup goes to `<dir>/<name>`; for a folder path, to `<dir>`.
See [BACKUP DATABASE](backup-and-safety.md#backup-database) and [kareladb backup](backup-and-safety.md#kareladb-backup).

**Command line: A verified backup from a script** (sample data: sample)

```bash
kareladb sql market "BACKUP DATABASE" --backups backups
```

Output:

```text
backup                      | files | bytes  | log_lsn
----------------------------+-------+--------+--------
backups/20261024-035553-188 |     9 | 194519 |      30
(1 row, 97.9 ms)
backup created and verified
```

**Command line: Without --backups** (sample data: sample)

```bash
kareladb sql market "BACKUP DATABASE"
```

Output:

```text
error: no backup folder is set; start KarelaDB with a backup folder (for example --backups D:/kdb_backups)
```

exit code 1

## kareladb shell

Syntax:

```sql
kareladb shell [<db>] [--backups <dir>] [--memory <MB>] [--trash-days N] [--data-dir <folder>]

kareladb> .help | .tables | .schema <table> | .format table|csv|json | .maxrows <n> | .check | .backup | .exit | .quit
```

Opens a prompt. Type SQL and end each statement with `;`. Lines that start with a dot are [shell commands](#dot-commands).

| Option | Meaning | Default |
|---|---|---|
| `<db>` | A database name in the data folder or a folder path. Without it: the database `default` in the data folder. | `default` |
| `--backups <dir>` | Backup folder for `.backup` and `BACKUP DATABASE` | not set |
| `--memory <MB>` | Memory for table data kept loaded | `512` |
| `--trash-days N` | Days a dropped table is kept for `UNDROP TABLE` | `7` |
| `--data-dir <folder>` | The data folder | `KARELADB_DATA_DIR`, else `data` next to kareladb |

- **Prompts:** `kareladb>` waits for a new statement. `...>` means the statement is not finished yet (no `;` so far).
- **Exit code:** the exit code of the last statement or dot command (`0`, `1` or `2`).
- **One session:** everything you type runs in one SQL session. `BEGIN` on one line and `COMMIT` on a later line work; cursors stay open. See [transactions in the shell](#transactions).
- **Data folder:** without `<db>` (or with a name from the data folder) `CREATE DATABASE`, `SHOW DATABASES` and `USE` work. With a folder path they are refused, because only that folder is open.
- **Piped input:** `"..." | kareladb shell market` runs the lines like typed lines. A last statement without `;` still runs at the end. The prompts are printed too.
- **Quit** with `.exit`, `.quit`, `exit` or `quit`, or end the input (Ctrl+Z then Enter on Windows, Ctrl+D on Linux). These close the database cleanly. Ctrl+C also ends the shell, but without a clean close (it is safe: the log is replayed at the next open).
- Keywords and names do not care about case. Comments are `-- to the end of the line` and `/* inside */`.

**Command line: A shell session (the lines after > are what you type)** (sample data: sample)

```bash
kareladb shell market
> .tables
> SELECT symbol, close
> FROM ochl_day
> WHERE time IN '2026-09-10';
> .format csv
> SELECT id, name FROM brokers LIMIT 3;
> .exit
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> name         | kind       | partition | columns | rows
-------------+------------+-----------+---------+-----
brokers      | relational | NONE      |       2 |    5
live_data    | timeseries | DAY       |      12 |   12
ochl_day     | timeseries | YEAR      |       7 |   57
ochl_minutes | timeseries | MONTH     |       7 |  956
securities   | relational | NONE      |       3 |    5
trade_log    | timeseries | DAY       |       8 |   32
(6 rows, 0.0 ms)
kareladb> ...> ...> symbol | close
-------+------
CITY   | 504.9
COAST  | 376.1
VOLT   | 191.2
(3 rows, 0.3 ms)
kareladb> kareladb> id,name
1,Keystone Securities
34,Vision Securities
45,Imperial Securities
kareladb>
```

**Command line: Without a database: the data folder**

```bash
kareladb shell
> CREATE DATABASE reports;
> USE reports;
> CREATE TABLE notes (id INT PRIMARY KEY, text STRING);
> SHOW DATABASES;
```

Output:

```text
KarelaDB 0.2.0-dev shell on default (data folder ./kdb-data)
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> database 'reports' created
kareladb> using database 'reports'
kareladb> table 'notes' created
kareladb> name    | tables | bytes | current
--------+--------+-------+--------
default |      0 |     0 | false  
reports |      1 |   229 | true   
(2 rows, 2.4 ms)
kareladb>
```

```powershell
# Run a few lines through the shell from PowerShell (not run here)
".tables`nSELECT count(*) FROM ochl_day;" | kareladb shell market
```

<a id="multi-line"></a>

## Statements over many lines

Syntax:

```sql
kareladb> SELECT symbol, close
...> FROM ochl_day
...> WHERE time IN '2026-09-10';
```

A statement ends at a `;` that is outside quotes and comments. Until then the shell shows `...>` and waits.

- A `;` inside `'text'`, `"name"`, `-- comment` or `/* comment */` does not end the statement.
- `CREATE PROCEDURE ... AS BEGIN ... END;`, `CREATE TRIGGER ... EXECUTE BEGIN ... END;` and `CASE ... END` may have many `;` inside. The shell waits for the `END;` that closes them.
- A dot command only works at the start of a new statement (at `kareladb>`, not at `...>`).
- Many statements on one line run one after the other.

**Command line: Two lines, one statement; then two statements on one line** (sample data: sample)

```bash
kareladb shell market
> SELECT count(*) AS days
> FROM ochl_day;
> SELECT 1 AS a; SELECT 2 AS b;
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> ...> days
----
  57
(1 row, 0.2 ms)
kareladb> a
-
1
(1 row, 0.0 ms)

b
-
2
(1 row, 0.0 ms)
kareladb>
```

**Command line: A procedure body with ; inside**

```bash
kareladb shell ./demo
> CREATE PROCEDURE hello(name STRING) AS BEGIN
>   PRINT name;
>   SELECT upper(name) AS shout;
> END;
> CALL hello('market');
```

Output:

```text
KarelaDB 0.2.0-dev shell on ./demo
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> ...> ...> ...> procedure 'hello' created
kareladb> procedure 'hello' done: 0 row(s) changed

shout 
------
MARKET
(1 row, 0.1 ms)

output
------
market
(1 row, 0.0 ms)
kareladb>
```

<a id="transactions"></a>

## Transactions in the shell

Syntax:

```sql
kareladb> BEGIN;
kareladb> ... statements ...
kareladb> COMMIT;     -- or ROLLBACK;
```

The shell keeps one SQL session, so a transaction stays open over many lines until `COMMIT` or `ROLLBACK`.

- Other statements in the same shell see your changes before `COMMIT`.
- **Quitting with an open transaction rolls it back.** The shell says `the open transaction was rolled back (it had no COMMIT)`.
- `kareladb sql` is one command: a `BEGIN` there must have its `COMMIT` in the same SQL text. Without it, the changes are rolled back and the exit code is `1`.
- A transaction with no statement for 30 seconds is rolled back. See [transactions](transactions.md).

**Command line: COMMIT keeps the change** (sample data: sample)

```bash
kareladb shell market
> BEGIN;
> INSERT INTO brokers VALUES (77, 'Northgate Securities');
> COMMIT;
kareladb sql market "SELECT count(*) AS brokers FROM brokers"
```

Output:

`> kareladb shell market`

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> transaction started
kareladb> 1 row(s) inserted
kareladb> transaction committed: 1 change(s) saved
kareladb>
```

`> kareladb sql market "SELECT count(*) AS brokers FROM brokers"`

```text
brokers
-------
      6
(1 row, 0.2 ms)
```

**Command line: No COMMIT: the change is rolled back when the shell ends** (sample data: sample)

```bash
kareladb shell market
> BEGIN;
> INSERT INTO brokers VALUES (59, 'Test Broker');
> SELECT count(*) AS inside_the_transaction FROM brokers;
kareladb sql market "SELECT count(*) AS after_the_shell FROM brokers"
```

Output:

`> kareladb shell market`

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> transaction started
kareladb> 1 row(s) inserted
kareladb> inside_the_transaction
----------------------
                     6
(1 row, 0.2 ms)
kareladb> 
the open transaction was rolled back (it had no COMMIT)
```

`> kareladb sql market "SELECT count(*) AS after_the_shell FROM brokers"`

```text
after_the_shell
---------------
              5
(1 row, 0.2 ms)
```

**Command line: kareladb sql: BEGIN and COMMIT must be in the same command** (sample data: sample)

```bash
kareladb sql market "BEGIN; INSERT INTO brokers VALUES (60, 'Test Broker'); COMMIT"
kareladb sql market "BEGIN; INSERT INTO brokers VALUES (61, 'No Commit Broker')"
```

Output:

`> kareladb sql market "BEGIN; INSERT INTO brokers VALUES (60, 'Test Broker'); COMMIT"`

```text
transaction started

1 row(s) inserted

transaction committed: 1 change(s) saved
```

`> kareladb sql market "BEGIN; INSERT INTO brokers VALUES (61, 'No Commit Broker')"`

```text
transaction started

1 row(s) inserted
error: BEGIN without COMMIT: the transaction was rolled back (end it with COMMIT to save the changes)
```

exit code 1

<a id="dot-commands"></a>

## Shell commands

Syntax:

```sql
.help
.tables
.schema <table>
.format table|csv|json
.maxrows <n>
.check
.backup
.exit
.quit
```

Shell commands start with a dot and need no `;`. They must be at the start of a line, at the `kareladb>` prompt.

| Command | What it does | Same as |
|---|---|---|
| `.help` | Lists the shell commands | |
| `.tables` | Lists the tables with kind, partitions, columns and rows | `SHOW TABLES` |
| `.schema <table>` | Shows the `CREATE TABLE` statement | `SHOW CREATE TABLE <table>` |
| `.format table\|csv\|json` | How results are printed from now on | `--format` of `kareladb sql` |
| `.maxrows <n>` | At most `n` rows per result. `0` = all. | `--max-rows` (default 1000) |
| `.check` | Reads every file and log record and reports damage | `CHECK TABLE` |
| `.backup` | Makes a verified backup (start the shell with `--backups <dir>`) | `BACKUP DATABASE` |
| `.exit`, `.quit` | Quits the shell | `exit`, `quit` |

An unknown dot command prints `unknown command .xyz (try .help)`.

## .help

Syntax:

```sql
.help
```

Lists the shell commands.

**Command line** (sample data: sample)

```bash
kareladb shell market
> .help
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb>   .tables              list tables
  .schema <table>      show CREATE TABLE
  .format table|csv|json
  .maxrows <n>         rows shown per query (0 = all)
  .check               read every file and report damage
  .backup              make a verified backup (needs --backups)
  .exit                quit
kareladb>
```

## .tables

Syntax:

```sql
.tables
```

Lists the tables of the database: name, kind (`timeseries` or `relational`), partitioning, number of columns and rows. The same as `SHOW TABLES` (see [SHOW TABLES](show-tables.md)).

**Command line** (sample data: sample)

```bash
kareladb shell market
> .tables
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> name         | kind       | partition | columns | rows
-------------+------------+-----------+---------+-----
brokers      | relational | NONE      |       2 |    5
live_data    | timeseries | DAY       |      12 |   12
ochl_day     | timeseries | YEAR      |       7 |   57
ochl_minutes | timeseries | MONTH     |       7 |  956
securities   | relational | NONE      |       3 |    5
trade_log    | timeseries | DAY       |       8 |   32
(6 rows, 0.0 ms)
kareladb>
```

## .schema

Syntax:

```sql
.schema <table>
```

Shows the `CREATE TABLE` statement of a table. The same as `SHOW CREATE TABLE <table>`.

- **Notes:** in `table` format the text is cut after 48 characters. Use `.format csv` first to see all of it.

**Command line: Use .format csv to see the whole statement** (sample data: sample)

```bash
kareladb shell market
> .format csv
> .schema ochl_day
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> kareladb> create_sql
"CREATE TABLE ochl_day (
  time TIMESTAMP ROUND 1d,
  symbol SYMBOL,
  open DOUBLE,
  high DOUBLE,
  low DOUBLE,
  close DOUBLE,
  volume DOUBLE
) TIMESERIES(time) PARTITION BY YEAR SORT BY (symbol, time) DEDUP KEY (symbol, time)"
kareladb>
```

## .format

Syntax:

```sql
.format table
.format csv
.format json
```

Sets how results are printed, for the rest of the session. The formats are the same as `--format` of [kareladb sql](#formats).

- **Notes:** a wrong value prints `format must be table, csv or json` and keeps the old format.

**Command line** (sample data: sample)

```bash
kareladb shell market
> .format json
> SELECT id, name FROM brokers LIMIT 2;
> .format table
> SELECT id, name FROM brokers LIMIT 2;
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> kareladb> [{"statement":"SELECT id, name FROM brokers LIMIT 2","columns":[{"name":"id","type":"INT"},{"name":"name","type":"STRING"}],"rows":[[1,"Keystone Securities"],[34,"Vision Securities"]],"rows_affected":0,"message":"","truncated":false}
]
kareladb> kareladb> id | name               
---+--------------------
 1 | Keystone Securities
34 | Vision Securities  
(2 rows, 0.0 ms)
kareladb>
```

## .maxrows

Syntax:

```sql
.maxrows <n>
```

Shows at most `n` rows per result. `0` means all rows. The default is `1000`.

- **Notes:** `.maxrows` without a number (or with text) also means `0` (all rows). `LIMIT` in the SQL is faster.

**Command line** (sample data: sample)

```bash
kareladb shell market
> .maxrows 2
> SELECT time, symbol, close FROM ochl_minutes;
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> kareladb> time                     | symbol | close
-------------------------+--------+------
2026-09-09T05:15:00.000Z | CITY   | 512.1
2026-09-09T05:16:00.000Z | CITY   | 511.9
(2 rows, more not shown, 0.5 ms)
kareladb>
```

## .check

Syntax:

```sql
.check
```

Reads every block of every data file and every log record, and reports damage. The same as `CHECK TABLE` (it always checks the whole database).
It shows a table of problems (empty when all is well) and `OK: no damage found in N files`.
For a closed database, [kareladb check](cli-maintenance.md#kareladb-check) does the same from the command line.

**Command line** (sample data: sample)

```bash
kareladb shell market
> .check
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> problem
-------
(0 rows, 0.9 ms)
OK: no damage found in 14 files
kareladb>
```

## .backup

Syntax:

```sql
.backup
```

Makes a backup and checks it, like `BACKUP DATABASE`. Start the shell with `--backups <dir>`; otherwise it says `no backup folder is set`.
It also deletes old backups: it keeps the newest backup of each of the last 7 days and 4 weeks.

**Command line: Start the shell with a backup folder** (sample data: sample)

```bash
kareladb shell market --backups backups
> .backup
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> backup                      | files | bytes  | log_lsn
----------------------------+-------+--------+--------
backups/20261024-035553-707 |     9 | 194519 |      30
(1 row, 110.4 ms)
backup created and verified
kareladb>
```

**Command line: Without --backups** (sample data: sample)

```bash
kareladb shell market
> .backup
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> kareladb> 
error: no backup folder is set; start KarelaDB with a backup folder (for example --backups D:/kdb_backups)
```

exit code 1

<a id="exit"></a>

## .exit, .quit

Syntax:

```sql
.exit
.quit
exit
quit
```

Quits the shell and closes the database cleanly. An open transaction is rolled back.
The words `exit` and `quit` (without a dot) also work, at the `kareladb>` prompt.

**Command line** (sample data: sample)

```bash
kareladb shell market
> SELECT 1 AS one;
> .quit
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> one
---
  1
(1 row, 0.1 ms)
kareladb>
```
