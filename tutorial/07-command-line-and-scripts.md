# 7. Command line and scripts

- Category: Tutorial

## What you will learn

- When a command means a database in the data folder, and when a folder path.
- The three output formats of `kdb sql`: table, CSV and JSON.
- How to use KDB in PowerShell and bash scripts (loops, exit codes, UTF-8 text).
- How to make a daily backup task with Windows Task Scheduler.

The examples use the database `market` with the sample data.

## Database names and folder paths

Every command that needs a database (`sql`, `shell`, `serve`, `info`, `check`, `repair`, `backup`) takes a **name** or a **path**:

| You write | KDB uses |
|---|---|
| A name (only letters, digits, `_`, `-`), and the data folder has a database with that name | That database in the data folder (chapter 1). Upper or lower case does not matter. |
| A name, and the data folder has no database with that name | The folder with that name in the current folder, like before. It is created if it does not exist. |
| A path (it has `\`, `/`, `:` or `.`): `.\market`, `D:\kdb\market` | Always that folder |
| Nothing (`kdb shell`, `kdb serve`) | The data folder: the database `default` for the shell; all databases for the server |

- To be sure you mean the folder in the current folder, write `.\market` (Linux: `./market`).
- To make a database in the data folder, use `CREATE DATABASE` in `kdb shell` (or in the console, or over HTTP).
- With a **name**, `kdb backup` and `kdb repair --backups` use the sub-folder `<backups-dir>\<name>`, the same place `kdb serve` uses. With a path, they use `<backups-dir>` as before.

```powershell
$env:KDB_DATA_DIR = "kdb-data"

# Make a database in the data folder (kdb shell runs CREATE DATABASE).
"CREATE DATABASE reports;" | kdb shell | Out-Null

# A name that is in the data folder means that database, from any folder.
kdb sql reports "CREATE TABLE daily (day DATE PRIMARY KEY, trades LONG); INSERT INTO daily VALUES ('2026-09-10', 32)"
kdb sql reports "SELECT * FROM daily"
kdb info reports | Select-Object -First 1
"reports in the data folder: $(Test-Path kdb-data\reports)   in the current folder: $(Test-Path reports)"

# A name that is not in the data folder is a folder in the current folder, as before.
kdb sql market "SELECT count(*) AS brokers FROM brokers"

# A path always means that folder: .\reports is a new, empty database here.
kdb sql .\reports "SHOW TABLES"
"reports in the current folder now: $(Test-Path reports)"
```

```text
table 'daily' created

1 row(s) inserted
day        | trades
-----------+-------
2026-09-10 |     32
(1 row, 0.4 ms)
database        kdb-data/reports
reports in the data folder: True   in the current folder: False
brokers
-------
      5
(1 row, 0.2 ms)
name | kind | partition | columns | rows
-----+------+-----------+---------+-----
(0 rows, 0.0 ms)
reports in the current folder now: True
```

## Output formats

### table (default)

For people. Numbers are right-aligned. At most 1000 rows are shown (change with `--max-rows`).

```powershell
kdb sql market "SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol"
```

```text
symbol | ltp   | pct_change
-------+-------+-----------
CITY   | 527.1 |       2.71
COAST  | 401.9 |        0.7
TELCO  | 897.7 |        1.9
VOLT   |   184 |      -0.86
(4 rows, 0.4 ms)
```

### csv

For Excel and scripts. The first line has the column names. There is no row limit.

```powershell
kdb sql market "SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol" --format csv
```

```text
symbol,ltp,pct_change
CITY,527.1,2.71
COAST,401.9,0.7
TELCO,897.7,1.9
VOLT,184,-0.86
```

- Text with a comma, quote or line break is put in `"double quotes"`.
- NULL is an empty field.
- Times are UTC, like `2026-09-10T05:15:00.000Z`.
- Messages like `3 row(s) inserted` are not printed in CSV.
- With many SELECT statements, the CSV blocks come one after another, each with its own header line. Use one SELECT per command when you save CSV.

To save a file: `kdb sql market "SELECT ..." --format csv > prices.csv`. (In Windows PowerShell 5.1, `>` writes UTF-16. Use `| Set-Content prices.csv -Encoding UTF8` if another program must read the file.)

### json

For programs. One JSON array with one object per statement.

```powershell
kdb sql market "SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol" --format json
```

```text
[{"statement":"SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol","columns":[{"name":"symbol","type":"SYMBOL"},{"name":"ltp","type":"DOUBLE"},{"name":"pct_change","type":"DOUBLE"}],"rows":[["CITY",527.1,2.71],["COAST",401.9,0.7],["TELCO",897.7,1.9],["VOLT",184,-0.86]],"rows_affected":0,"message":"","truncated":false}
]
```

| Field | Meaning |
|---|---|
| `statement` | The statement, as KDB understood it |
| `columns` | Name and type of each column |
| `rows` | The rows. Each row is a list of values in column order. |
| `rows_affected` | Rows changed by INSERT, UPDATE or DELETE |
| `message` | For example `3 row(s) inserted` |
| `truncated` | `true` if there were more rows than `--max-rows` |

Values in JSON: numbers are numbers; TIMESTAMP and DATE are text (UTC); DECIMAL is text (to stay exact); NULL is `null`.

If a statement fails, the JSON of the statements before it is printed, and the error goes to the error output (stderr) with exit code 1.

### --max-rows

```powershell
kdb sql market "SELECT time, symbol, close FROM ochl_minutes" --max-rows 3
```

```text
time                     | symbol | close
-------------------------+--------+------
2026-09-09T05:15:00.000Z | CITY   | 512.1
2026-09-09T05:16:00.000Z | CITY   | 511.9
2026-09-09T05:17:00.000Z | CITY   | 511.9
(3 rows, more not shown, 0.6 ms)
```

`--max-rows 0` means no limit. For a fixed number of rows in your result, `LIMIT` in the SQL is better: it also makes the query faster.

## PowerShell

### CSV to objects: ConvertFrom-Csv

```powershell
$rows = kdb sql market "SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol" --format csv | ConvertFrom-Csv

# Every value is text. Use [double] to compare numbers.
$rows | Where-Object { [double]$_.pct_change -gt 1 } | Format-Table -AutoSize
```

```text
symbol ltp   pct_change
------ ---   ----------
CITY   527.1 2.71      
TELCO  897.7 1.9
```

Without `[double]`, PowerShell compares text: `"10" -gt "9"` is false.

### JSON to objects: ConvertFrom-Json

In Windows PowerShell 5.1, join the lines with `Out-String` first:

```powershell
$json = kdb sql market "SELECT symbol, sum(quantity) AS shares FROM trade_log WHERE date IN '2026-09-10' GROUP BY symbol ORDER BY shares DESC" --format json | Out-String
$result = ConvertFrom-Json $json

# One result per statement. rows is a list of rows; each row is a list of values.
foreach ($row in $result[0].rows) {
  "{0,-6} {1,6} shares" -f $row[0], $row[1]
}
```

```text
COAST    2850 shares
CITY      910 shares
TELCO     770 shares
VOLT      400 shares
```

JSON keeps numbers as numbers, so you do not need `[double]`.

### A loop: one CSV file per symbol

```powershell
foreach ($symbol in @("CITY", "COAST", "VOLT")) {
  $csv = kdb sql market "SELECT symbol, time, close FROM ochl_day WHERE symbol = '$symbol' AND time IN '2026-09' ORDER BY time" --format csv
  $csv | Set-Content "close-$symbol.csv" -Encoding UTF8
  "$symbol : $(($csv | Measure-Object).Count - 1) rows saved to close-$symbol.csv"
}
```

```text
CITY : 8 rows saved to close-CITY.csv
COAST : 8 rows saved to close-COAST.csv
VOLT : 8 rows saved to close-VOLT.csv
```

Inside `"double quotes"`, PowerShell puts in the value of `$symbol`. The SQL text uses `'single quotes'`, so both work together.

**Never put text from users directly into SQL.** A symbol like `x' OR '1'='1` would change the query. Check such values first, for example with `if ($symbol -notmatch '^[A-Z0-9-]+$') { throw "bad symbol" }`.

### Exit codes in scripts

```powershell
kdb sql market "INSERT INTO brokers VALUES (58, 'Northgate Securities')" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Output "The insert failed (exit code $LASTEXITCODE). Stop here."
}

kdb check market | Out-Null
switch ($LASTEXITCODE) {
  0 { Write-Output "check: OK" }
  2 { Write-Output "check: DAMAGE FOUND - run kdb repair" }
  default { Write-Output "check: could not run (exit code $LASTEXITCODE)" }
}
```

```text
The insert failed (exit code 1). Stop here.
check: OK
```

- `0` = OK, `1` = error, `2` = damage, `3` = the database needs a newer KDB (chapter 2).
- `$LASTEXITCODE` changes after **every** program. Read it right after the `kdb` command.
- `$ErrorActionPreference = "Stop"` does **not** stop a script when `kdb` fails. Check `$LASTEXITCODE` yourself.

### Non-English text (UTF-8)

Windows PowerShell 5.1 sends text into a pipe as ASCII by default. Letters outside English (Nepali, Chinese, accented letters, ...) then become `?`. Set UTF-8 first:

```powershell
# Windows PowerShell 5.1 sends pipe text as ASCII unless you say UTF-8.
$OutputEncoding = New-Object System.Text.UTF8Encoding $false

@"
CREATE TABLE IF NOT EXISTS names_np (symbol SYMBOL PRIMARY KEY, name_np STRING);
INSERT OR REPLACE INTO names_np VALUES ('TELCO', 'नेपाल दूरसञ्चार');
"@ | Set-Content names.sql -Encoding UTF8

Get-Content names.sql -Raw -Encoding UTF8 | kdb sql market -
kdb sql market "SELECT symbol, name_np FROM names_np"
```

```text
table 'names_np' created

1 row(s) inserted
symbol | name_np        
-------+----------------
TELCO  | नेपाल दूरसञ्चार
(1 row, 0.2 ms)
```

- Save `.sql` files as **UTF-8**.
- Text in any language also works directly in the command line (`kdb sql market "INSERT ... 'नेपाल'"`). If you see `????` after a pipe, see [chapter 12](12-troubleshooting.md#text-in-other-languages-looks-broken).
- PowerShell 7 already uses UTF-8.

## Daily backup script

This script makes a backup, deletes old backups, checks the database and writes a log. Run it every trading day **after 15:00 Nepal time**, when the market is closed.

It works when **no server is running** on the database (`kdb backup` needs the database closed). If `kdb serve` runs all the time, see [the server version](#if-kdb-serve-runs-all-day) below.

Save as `daily-backup.ps1`:

```powershell
# daily-backup.ps1 - run after the market closes (15:00 Nepal time).
# Use full paths in a scheduled task, for example:
#   $Kdb = "D:\KDB\build\bin\kdb.exe"; $Data = "D:\kdb\market"; $Backups = "E:\kdb_backups"
$Kdb     = "kdb"
$Data    = "market"
$Backups = "backups"
$Log     = "backup-log.txt"

Add-Content $Log "---- $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# 2>&1 keeps error lines too; "$_" turns each line into plain text.
$out = & $Kdb backup $Data $Backups --keep-daily 7 --keep-weekly 4 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
Add-Content $Log $out
Add-Content $Log "backup exit code: $code"
if ($code -ne 0) { Write-Output "BACKUP FAILED, see $Log"; exit $code }

$out = & $Kdb check $Data 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
Add-Content $Log $out
Add-Content $Log "check exit code: $code"
if ($code -ne 0) { Write-Output "CHECK FOUND A PROBLEM, see $Log"; exit $code }

Write-Output "backup and check OK"
```

Run it:

```powershell
powershell -ExecutionPolicy Bypass -File .\daily-backup.ps1
```

```text
backup and check OK
```

The log file:

```text
---- 2026-09-23 17:54:29
backup created and verified: backups/20260923-120929-906
  10 files, 190.8 KB, log up to 34
backup exit code: 0
checked 12 files (76.2 KB) and 1 log segments
OK: no damage found
check exit code: 0
```

Notes:

- **Put the backups on another disk** than the database (for example `E:\kdb_backups`). One broken disk must not destroy both.
- `--keep-daily 7 --keep-weekly 4` keeps the newest backup of each of the last 7 days and of the last 4 weeks. Older backups are deleted, and the script prints `removed old backup ...`.
- Backup folder names use **UTC** time: `20260923-120929-906` = 12:09:29 UTC = 17:54 Nepal time.

### If kdb serve runs all day

A running server keeps the database open, so `kdb backup` fails. Ask the server to make the backup instead. Start the server with `--backups E:\kdb_backups`, then:

```powershell
# daily-backup-server.ps1
$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/api/backup"
"backup $($r.name): $($r.files) files, $($r.bytes) bytes"
$c = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/api/check"
if (-not $c.ok) { Write-Output "CHECK FOUND A PROBLEM: $($c.problems -join '; ')"; exit 2 }
```

(If the server uses `--token`, add `-Headers @{ Authorization = "Bearer <token>" }`.) The server keeps 7 daily and 4 weekly backups by itself. Chapter 8 shows the JSON of these two calls.

Simpler: no script at all. `kdb serve ... --backups E:\kdb_backups --backup-schedule "daily 16:00" --backup-copy F:\kdb_copy` makes and checks the backups by itself, while the server keeps working ([chapter 21](21-protection.md#part-c-backups-on-a-schedule)).

### Windows Task Scheduler

Register the script to run Sunday to Thursday at 15:30. Run PowerShell **as Administrator**. Change the paths.

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
             -Argument "-NoProfile -ExecutionPolicy Bypass -File D:\kdb-work\daily-backup.ps1" `
             -WorkingDirectory "D:\kdb-work"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday,Monday,Tuesday,Wednesday,Thursday -At 15:30
Register-ScheduledTask -TaskName "KDB daily backup" -Action $action -Trigger $trigger `
  -Description "Backup and check the market KDB database after market close"
```

(These Task Scheduler commands were **not run** while writing this tutorial, so they would not change the test PC. The script itself was run.)

- The time `15:30` is the **computer's** clock. Set the PC to Nepal time, or change the time.
- Test it once: `Start-ScheduledTask -TaskName "KDB daily backup"`, then read the log file.
- In a task, use **full paths** in the script, because the task does not have your `PATH`.

## bash (Linux, macOS, Git Bash)

The same ideas in bash. Save as `report.sh`:

```bash
#!/usr/bin/env bash
set -u
DB=market

kdb sql "$DB" "SELECT symbol, close FROM ochl_day WHERE time IN '2026-09-10'" --format csv > closes.csv
echo "saved $(( $(wc -l < closes.csv) - 1 )) rows"

kdb sql "$DB" "SELECT nope FROM ochl_day" > /dev/null 2>&1
code=$?
if [ "$code" -ne 0 ]; then
  echo "query failed with exit code $code"
fi

kdb sql "$DB" - <<'SQL'
SELECT count(*) AS trades FROM trade_log;
SQL
```

```bash
bash ./report.sh
```

```text
saved 3 rows
query failed with exit code 1
trades
------
    32
(1 row, 0.3 ms)
```

- `<<'SQL' ... SQL` sends many lines of SQL into `kdb sql ... -`. The quotes around `'SQL'` stop bash from changing `$` signs in the SQL.
- `kdb sql "$DB" - < file.sql` sends a file.
- On Linux you can use `cron` for the daily backup: `30 15 * * 0-4 /home/kdb/daily-backup.sh` (Sunday=0 to Thursday=4, computer time).

(Tested with Git Bash on Windows.)

## Speed options for `kdb serve`

| Option | Default | What it does |
|---|---|---|
| `--memory <MB>` | 512 | Table data kept in memory. More is faster for big tables. Data stays on disk; only what queries need is loaded. |
| `--threads <N>` | half of the CPU threads | Threads for big queries and bulk writes. KDB never uses more than half of the CPU threads. |
| `--cache-mb <MB>` | 64 | Memory for results of repeated queries. `0` turns the cache off. |
| `--sync-commits always\|batch` | always | `batch` is much faster for many small writes; a power cut can lose the last few confirmed writes, but never damages data. With `always`, writers that commit at the same moment still share one wait for the disk (group commit). |
| `--warm-indexes on\|off` | on | Build every index on a background thread right after a database opens, so the first query after a restart finds it ready. `off`: an index is built when a query first needs it. |
| `--reader-yield on\|off` | off | `on`: reads do not wait for a long trigger or `CALL`; they read the last committed rows. Also `KDB_READER_YIELD`. |

**The result cache.** When the same `SELECT` comes again (a dashboard that refreshes, a live page) and no table it reads has changed, KDB answers from memory in a few microseconds.

- Any change to a table it read (INSERT, UPDATE, DELETE, line protocol, rollback) makes KDB compute the result again.
- Changes of views, functions, procedures and tables clear the whole cache.
- Queries with `now()`, `random()`, `gen_random_uuid()`, password functions and similar are never kept.
- A `SELECT` inside your own open transaction is never taken from the cache.

```powershell
.\kdb serve market --memory 2048 --cache-mb 128
```

## Protection options for `kdb serve`

[Chapter 21](21-protection.md) explains them. They cost almost no speed.

| Option | Default | What it does |
|---|---|---|
| `--statement-timeout 30s` | 60s | Stop a statement that runs longer (`0` = no limit) |
| `--max-result-memory 512MB` | 1GB | Stop a query that keeps more rows in memory |
| `--max-groups N` | 5000000 | Stop a `GROUP BY` with more groups. (A `GROUP BY` that needs more than half of `--max-result-memory` does not stop: it puts groups in temporary files on disk and gives the same result, only slower.) |
| `--max-queries-per-user N` | 32 | Statements of one user at the same time |
| `--safe-updates` | off | Refuse `UPDATE`/`DELETE` without `WHERE` |
| `--read-only` | off | No changes at all (a report server) |
| `--trash-days N` | 7 | `DROP TABLE` keeps the table for `UNDROP TABLE` (also `kdb sql` and `kdb shell`) |
| `--audit on\|off`, `--audit-keep-days N` | on, forever | The audit log of logins, user changes, DDL and backups |
| `--backup-schedule "daily 16:00"` | off | Backups by themselves (needs `--backups`) |
| `--backup-copy <dir>` | none | A checked second copy of each scheduled backup |
| `--backup-warn-hours N` | 26 | Warn when the last good backup is older |
| `--drain-timeout 30s` | 30s | On stop (Ctrl+C or a service stop), running requests may finish this long; new ones get HTTP 503 |
| `--activity-log-size N` | 5000 | Recent events kept in memory for the console's Terminal (`0` = off) |

`kdb sql` and `kdb shell` have no timeouts or limits. `kdb user reset-2fa <name>` turns two-factor login off while the server is stopped.

## Try it yourself

1. Save all CITY minute candles of 2026-09-10 to `city-minutes.csv`.
2. Write a PowerShell line that prints only the number of trade_log trades on 2026-09-10 (just the number).
3. Change the daily backup script so it also writes the size of the newest backup into the log (hint: `kdb backups`).

<details>
<summary>Answers</summary>

1. ```powershell
   kdb sql market "SELECT * FROM ochl_minutes WHERE symbol = 'CITY' AND time IN '2026-09-10' ORDER BY time" --format csv | Set-Content city-minutes.csv -Encoding UTF8
   ```
2. ```powershell
   (kdb sql market "SELECT count(*) AS n FROM trade_log WHERE date IN '2026-09-10'" --format csv | ConvertFrom-Csv).n
   ```
   The answer is `24`.
3. After the backup lines, add:
   ```powershell
   $list = & $Kdb backups $Backups 2>&1 | ForEach-Object { "$_" }
   Add-Content $Log $list[1]    # line 2 = the newest backup
   ```

</details>

---

Next: [8. HTTP API](08-http-api.md)
