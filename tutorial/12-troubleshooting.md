# 12. Troubleshooting

- Category: Tutorial

## What you will learn

- The common error messages, exactly as KarelaDB prints them.
- What each one means and how to fix it.
- Answers to frequent questions.

All messages below are real output (`examples/12-troubleshooting/`). Use `Ctrl+F` and search for words from your error.

## Quick table

| Message starts with | Section |
|---|---|
| `the database is open in another program` | [Database is locked](#database-is-locked) |
| `a row with ... already exists` | [Duplicate key](#duplicate-key) |
| `unknown column` | [Unknown column](#unknown-column) |
| `table or view ... does not exist` | [Unknown table](#unknown-table) |
| `expected ... but found ...` | [Syntax error](#syntax-error) |
| `is not a time like` / `cannot compare TIMESTAMP` | [Time format](#time-format) |
| `has more than 2 decimal places` | [Decimal places](#decimal-places) |
| `has no matching row in` | [REFERENCES failure](#references-failure) |
| `cannot remove ... still refers to it` | [Cannot delete a referenced row](#cannot-delete-a-referenced-row) |
| `cannot be NULL` / `needs a value` | [Missing value](#missing-value) |
| `is out of range` | [Number out of range](#number-out-of-range) |
| `cannot compare STRING ... with LONG` | [Type mismatch](#type-mismatch) |
| `port ... is already in use` | [Port in use](#port-in-use) |
| `access token required` / `wrong access token` (HTTP 401) | [Token 401](#token-401) |
| `cross-site requests are not allowed` (HTTP 403) | [403 cross-site](#403-cross-site-cross-origin-host-name) |
| `this SQL changes data, so it must be sent with POST` (HTTP 405) | [405 GET changes data](#405-get-changes-data) |
| `????` or broken letters instead of non-English text | [Text in other languages looks broken](#text-in-other-languages-looks-broken) |
| `failed its checksum`, `DAMAGED` | [Damage](#damage) |

## Database is locked

```text
error: Locked: the database is open in another program (for example kareladb serve). Stop it, or query it through that server's console or HTTP API (kareladb serve)
exit code: 1
error: the database is open in another program. Stop it first, or run BACKUP DATABASE in that server's console or API.
exit code: 1
```

(The first line is from `kareladb sql`, the second from `kareladb backup`, while `kareladb serve` had the database open.)

**Why:** only one program can open a database folder. `kareladb serve`, `kareladb shell` or another `kareladb sql` has it open.

**Fix:**

- Use the running server: the console, `POST /exec`, `POST /api/backup`, `POST /api/check` (chapter 8).
- Or stop the other program (Ctrl+C in its window), then run your command.
- Look for a forgotten `kareladb shell` in another window. In PowerShell: `Get-Process kareladb`.
- Do not delete `kdb.lock`. The lock is held by the running program, not by the file. When no program runs, the lock is free.

## Duplicate key

```sql
INSERT INTO ochl_day VALUES ('2026-09-10', 'CITY', 504.6, 507, 500.7, 504.9, 183040);
```

```text
error: a row with symbol='CITY', time='2026-09-10T00:00:00.000Z' already exists in 'ochl_day'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it
```

**Why:** the table has a DEDUP KEY or PRIMARY KEY, and a row with these values is already there (or twice in your statement). **Nothing** from this INSERT was saved.

**Fix:** `INSERT OR REPLACE` (new data wins) or `INSERT OR IGNORE` (old data wins). If you did not expect a duplicate: check the time zone (`+05:45` missing?) and `ROUND` on the time column (chapter 3).

## Unknown column

```sql
SELECT time, symbol, clsoe
FROM ochl_day
WHERE symbol = 'CITY';
```

```text
error: line 1, column 22: unknown column 'clsoe' (table 'ochl_day' has: time symbol open high low close volume)
```

**Why:** a typing mistake, or the column is in another table.

**Fix:** look at the list in the message. With joins, write `table.column`. In the console, click the arrow next to a table to see its columns.

`line 1, column 22` is the place in the SQL you sent. In a file, it is the line of the file.

## Unknown table

```sql
SELECT * FROM ochl_days;
```

```text
error: line 1, column 15: table or view 'ochl_days' does not exist
```

**Fix:** `SHOW TABLES` or `.tables` in the shell. Check that you opened the right database **folder**: `kareladb sql` creates a new empty database when the folder does not exist, so a wrong folder name gives "does not exist" for every table.

## Syntax error

```sql
SELECT symbol close FROM ochl_day WHERE;
```

```text
error: line 1, column 40: expected an expression (a value, column name, function call or '(') but found ';'
```

**Why:** the SQL does not follow the grammar. The message says what KarelaDB expected at that place.

Watch out: `SELECT symbol close` is **not** an error. It means "column symbol, named close". A missing comma changes your column names quietly.

An unclosed text:

```sql
SELECT * FROM brokers WHERE name = 'Northgate;
```

```text
error: line 1, column 36: expected a closing ' to end the string that starts here but found the end of the input
```

A reserved word as a name: see chapter 11 (`"order"`).

## Time format

```sql
INSERT INTO ochl_day VALUES ('10/09/2026', 'CITY', 1, 1, 1, 1, 1);
```

```text
error: column 'time' (TIMESTAMP): '10/09/2026' is not a time like '2026-09-11 11:00:00' (UTC) or '2026-09-11T11:00:00+05:45'
```

```sql
SELECT time, close FROM ochl_day WHERE time >= '2026-9-1';
```

```text
error: line 1, column 45: cannot compare TIMESTAMP '2025-12-28T00:00:00.000Z' with STRING '2026-9-1'
```

**Fix:** always `YYYY-MM-DD` with two digits for month and day: `'2026-09-01'`. Add `+05:45` for Nepal times. Convert other formats in your script before sending (for example in PowerShell: `([datetime]::ParseExact('10/09/2026', 'dd/MM/yyyy', $null)).ToString('yyyy-MM-dd')`).

**Times are 5:45 hours wrong?** You wrote Nepal time without `+05:45`. KarelaDB read it as UTC. Fix the data with an UPDATE: `UPDATE t SET time = time - 20700000 WHERE ...` (this subtracts 5 h 45 min), but check the DEDUP KEY first.

## Decimal places

```sql
CREATE TABLE wallet (id INT PRIMARY KEY, balance DECIMAL(2));
INSERT INTO wallet VALUES (1, 100.50);
UPDATE wallet SET balance = balance * 1.015 WHERE id = 1;
```

```text
table 'wallet' created

1 row(s) inserted
error: column 'balance' (DECIMAL(2)): 102.0075 has more than 2 decimal places
```

**Why:** KarelaDB never rounds money by itself.

**Fix:** round it yourself, the way your business rule says:

```sql
UPDATE wallet SET balance = round(balance * 1.015, 2) WHERE id = 1;
SELECT id, balance FROM wallet;
```

```text
1 row(s) updated

id | balance
---+--------
 1 |  102.01
(1 row, 0.1 ms)
```

For amounts with more than about 15 digits, send the value as **text** (`'123456789012345.67'`). A number that big cannot be stored exactly as a DOUBLE, so KarelaDB refuses it and tells you to write it as text.

## REFERENCES failure

```sql
INSERT INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate)
VALUES ('2026-09-10', 200001, 'CITY', 77, 58, 10, 515);
```

```text
error: column 'buyer' = '77' has no matching row in brokers(id)
```

**Fix:** insert the missing row first (`INSERT INTO brokers VALUES (77, '...')`), or correct the value. For a big import, load the parent table (brokers) before the child table (trade_log).

## Cannot delete a referenced row

```sql
DELETE FROM brokers WHERE id = 45;
```

```text
error: cannot remove brokers(id) = '45': table 'trade_log' column 'buyer' still refers to it (foreign key 'trade_log_buyer_fkey')
```

**Why:** trades still point to this broker. A plain `REFERENCES` never deletes them for you. (A foreign key written with `ON DELETE CASCADE` or `ON DELETE SET NULL` would; chapter 22.)

**Fix:** delete or change the trades first, or keep the broker. Changing the broker's `id` with UPDATE is refused for the same reason. Dropping the whole table gives: `cannot drop table 'brokers': column 'buyer' of table 'trade_log' REFERENCES it; drop that column or table first`.

## Missing value

```sql
INSERT INTO brokers (id) VALUES (99);
```

```text
error: column 'name' (STRING): cannot be NULL
```

```sql
INSERT INTO ochl_day (symbol, close) VALUES ('CITY', 505);
```

```text
error: the time column 'time' needs a value
```

**Fix:** give a value for `NOT NULL` and PRIMARY KEY columns and for the time column of a time-series table.

## Number out of range

```sql
INSERT INTO brokers VALUES (3000000000, 'Too Big');
```

```text
error: column 'id' (INT): 3000000000 is out of range (-2147483647 to 2147483647)
```

**Fix:** use a bigger type (LONG). For an existing table: `ALTER TABLE t ALTER COLUMN c TYPE LONG` (chapter 3). A column that is the time column or part of SORT BY or DEDUP KEY cannot change its type.

## Type mismatch

```sql
SELECT * FROM brokers WHERE name = 58;
```

```text
error: line 1, column 34: cannot compare STRING 'Keystone Securities' with LONG '58'
```

```sql
SELECT sum(symbol) FROM ochl_day;
```

```text
error: line 1, column 8: sum needs numbers, got 'CITY'
```

**Fix:** compare text with `'text'` and numbers with numbers. Use `CAST` when needed.

## Other query errors

| Message | Fix |
|---|---|
| `SAMPLE BY needs a table with a time column (a TIMESERIES table)` | SAMPLE BY only works on time-series tables. Use GROUP BY. |
| `column 'close' is used by a window function in a query with aggregates, so it must be a key of the groups: add it to the SELECT list or to GROUP BY` | With `GROUP BY` or `SAMPLE BY`, a window function reads the groups, not the rows. Give it an aggregate (`sma(last(close), 2)`) or a group key, or aggregate in a subquery and put the indicator outside (chapter 5). |
| `'sma' works over a series of rows and can only be used in a SELECT list` | Not in WHERE and not inside another series function. Use a subquery. |
| `column 'amount' is computed and cannot be set` | Computed columns (`AS (...)`) are not stored. Change the columns it is computed from. |
| `in subquery: ... unknown column 's.symbol'` | The name is wrong, or `s` is not a table of the outer query. Correlated subqueries work (chapter 23). |
| `subquery returned 3 rows; a value needs exactly one (add LIMIT 1?)` | A `(SELECT ...)` used as a value must return one row. |
| `time zone '...' is not supported` | Use `'Asia/Kathmandu'` or `'+05:45'`. |
| `offset '00:15' must look like '+05:45' or '-03:00'` | Write `WITH OFFSET '+00:15'`. |
| `DEDUP KEY must include the time column` | Add the time column to the DEDUP KEY. |
| `there is no unique key on (a, b) of table 't' for ON CONFLICT` | Add `PRIMARY KEY`, `UNIQUE (a, b)` or a `UNIQUE INDEX` on exactly these columns (chapter 23). |
| `ON CONFLICT DO UPDATE cannot change the same row twice in one statement` | Two new rows have the same key. Remove the copy, or use `DO NOTHING`. |
| `the query makes more than N groups (max_groups)` | The `GROUP BY` makes more groups than `--max-groups` allows. Add a time filter or group by fewer columns. (A `GROUP BY` that only needs much memory does not fail: it uses temporary files and is slower.) |
| `table 'x' is busy: ...`, `database is busy: ...`, `deadlock: ...` | Another transaction holds the table. Nothing of your statement was done. Wait a little and run the whole transaction again (chapter 15). |

The outputs of these are in `examples/05-queries/`, `examples/10-migrating-from-questdb/`, `examples/11-sql-reference/` and `examples/03-tables/`.

## Port in use

```text
error: Already exists: port 9945 on 127.0.0.1 is already in use
exit code: 1
```

**Why:** another program (often another `kareladb serve`) listens on that port.

**Fix:** use another port (`--port 9901`), or find the program:

```powershell
Get-NetTCPConnection -LocalPort 9900 -State Listen | Select-Object OwningProcess
Get-Process -Id <OwningProcess>
```

## Token 401

```text
{"error":"access token required"}   (HTTP 401)
{"error":"wrong access token"}   (HTTP 401)
```

**Why:** the server was started with `--token`.

**Fix:** send `Authorization: Bearer <token>`. In the console, enter the token in the dialog. If the console keeps asking, the saved token is wrong: clear the site data of `127.0.0.1:9900` in the browser, or open a private window. Check with `curl.exe -s http://127.0.0.1:9900/health`: `"auth_required":true` means a token is needed.

## 403 cross-site, cross-origin, host name

```text
{"error":"cross-site requests are not allowed"}   (HTTP 403)
{"error":"cross-origin requests are not allowed"}   (HTTP 403)
{"error":"host name 'market.example.com' is not allowed without an access token; use localhost or start the server with --token"}   (HTTP 403)
```

**Why:** protection against web pages that try to use your local KarelaDB (chapter 8).

**Fix:**

- Call KarelaDB from a program or your backend, not from JavaScript on another web site.
- Open the console with `http://127.0.0.1:9900` or `http://localhost:9900`.
- Behind a reverse proxy or with a host name: start the server with `--token`.

## 405 GET changes data

```text
{"error":"this SQL changes data, so it must be sent with POST /exec (GET /exec only reads)"}   (HTTP 405)
{"error":"CSV export needs a SELECT, SHOW or EXPLAIN statement"}   (HTTP 400)
```

**Why:** `GET /exec` only runs reading statements, and `/exp` only exports reading statements. A web page could otherwise change your data with a simple link.

**Fix:** send INSERT, UPDATE, DELETE, CREATE, DROP, ALTER and BACKUP DATABASE with **POST**: `curl.exe http://127.0.0.1:9900/exec --data-binary "INSERT ..."`.

## Text in other languages looks broken

```powershell
kareladb sql market "CREATE TABLE IF NOT EXISTS names_np (symbol SYMBOL PRIMARY KEY, name_np STRING)"

# Text in any language (here Nepali) works directly on the command line:
kareladb sql market "INSERT OR REPLACE INTO names_np VALUES ('VOLT', 'भोल्ट रिभर')"
kareladb sql market "SELECT symbol, name_np FROM names_np"

# It also works from a UTF-8 file (or over HTTP):
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
"INSERT OR REPLACE INTO names_np VALUES ('VOLT', 'भोल्ट रिभर');" | Set-Content np.sql -Encoding UTF8
Get-Content np.sql -Raw -Encoding UTF8 | kareladb sql market -
kareladb sql market "SELECT symbol, name_np FROM names_np"
```

```text
table 'names_np' created
1 row(s) inserted
symbol | name_np   
-------+-----------
VOLT   | भोल्ट रिभर
(1 row, 0.2 ms)
0 row(s) inserted, 1 replaced
symbol | name_np   
-------+-----------
VOLT   | भोल्ट रिभर
(1 row, 0.2 ms)
```

**If you see `????`:** Windows PowerShell 5.1 sends pipe text as ASCII unless `$OutputEncoding` is UTF-8. Set it (as above) before you pipe SQL into `kareladb sql -` or `kareladb shell`. Text in command-line arguments and over HTTP is fine.

If the letters look broken only in the **console window**, the window font may not have Devanagari. Use Windows Terminal, or save the output as CSV and open it in an editor.

## Damage

Messages like `failed its checksum`, `DAMAGED`, `the end of the log is damaged`, exit code 2:

1. Stop the server and all programs that use the database.
2. Copy the whole database folder to a safe place.
3. `kareladb check <db>` to see the damage.
4. `kareladb repair <db> --backups <backups>`.
5. If it still fails: `kareladb restore <newest backup> <new folder> --logs-from <db>`.

Chapter 9 shows a full real example.

## The server stopped

If the server process ends without Ctrl+C (crash, closed window, killed), start it again. The banner then shows `last shutdown: not clean (crash or kill)` and KarelaDB replays the log. Committed data is not lost.

## FAQ

**Where are my times? They look 5:45 hours early.**
KarelaDB shows UTC. `05:15Z` is 11:00 in Nepal. The chart in the console shows your local time.

**Can two programs write at the same time?**
Not to the same folder directly. Run one `kareladb serve` and let all programs use its HTTP API or its PostgreSQL port. In the server, writers of **different** tables run at the same time. Writers of the **same** table take turns. A read waits for a long write of the same database unless the server runs with `--reader-yield on` (the Docker image does), then it runs between the writer's statements (chapter 15).

**Is a statement saved when KarelaDB says "inserted"?**
Yes, it is on the disk. A power cut after that does not lose it.

**How do I undo a change?**
Inside `BEGIN` ... `COMMIT`, `ROLLBACK` undoes everything since `BEGIN` (chapter 13). A dropped table comes back with `UNDROP TABLE` for 7 days (chapter 21). After a committed change, restore a backup to the time before it (`kareladb restore --until`, chapter 9). Make a backup before big changes.

**How big can a table be?**
There is no fixed limit. Very old data can be removed quickly with `ALTER TABLE ... DROP PARTITION OLDER THAN 1 YEAR`, or by itself with a TTL (`ALTER TABLE ... SET TTL 90 DAYS`, chapter 3).

**Why is my query slow?**
Add a time filter on the time-series table (`time IN '2026-09'`), select fewer columns, and check with `EXPLAIN` how many partitions are read (chapter 5).

**Can I use DBeaver, psql or Excel to connect?**
DBeaver and `psql`: yes, through the PostgreSQL port 8832 (chapter 14). For Excel, export CSV (`kareladb sql ... --format csv`, or the console's **Export CSV**).

**Does KarelaDB know stock exchange holidays?**
No. `is_trading_day()` only checks for a Sunday-to-Thursday week (as on some exchanges). Keep a holiday table if you need it.

**Can I copy the database folder to another PC?**
Yes, when no program has it open. Better: `kareladb backup`, copy the backup folder, `kareladb restore` on the other PC. The restore checks every file.

**Do Linux and Windows use the same files?**
The file format is the same on all systems (chapter 1, FORMAT.md).

**Where is `kareladb.conf`?**
Next to the `kareladb` program (or the file named with `--config <file>`). It is a small JSON file that the console's **Settings** page writes. It holds `data_dir`, `wal_archive_mb`, `trash_keep_hours`, `keep_versions`, and the folders of the console, the help and the Claude skill (`web_dir`, `help_dir`, `skill_dir`). An option on the command line always wins over it. Everything else is a command-line option (`kareladb` with no command lists them).

## Try it yourself

1. You get `error: line 3, column 5: unknown column 'volum'`. What do you do?
2. A script prints `the database is open in another program`, but no server is running. What else can hold the database?
3. An INSERT of 5000 rows fails with a duplicate key. How many rows were saved?

<details>
<summary>Answers</summary>

1. Look at line 3, column 5 of your SQL, and fix the name to `volume` (the message lists the real columns).
2. A `kareladb shell` or `kareladb sql` in another window, or a scheduled task (backup script) that is running. Check with `Get-Process kareladb`.
3. None. One statement is all or nothing. Use `INSERT OR REPLACE` or `INSERT OR IGNORE`, or remove the duplicates.

</details>

---

Next: [13. Functions, procedures and triggers](13-functions-procedures-triggers.md). Back to the index. Also read the [known limitations](known-limitations.md).
