# 8. HTTP API

- Category: Tutorial

## What you will learn

- Every HTTP route of `kdb serve`, with `curl` examples and the real JSON answers.
- How one server serves many databases: `db=<name>` and `/api/databases`.
- How to call KDB from PowerShell, Python, Node, Go and C#.
- The rules: GET only reads, row limits, errors, access token, users and logins.
- Fast loads with the line protocol (`POST /write`), all-or-nothing requests (`atomic=1`), results by column (`format=columns`) and the `ETag`.

Start the server first (with a backup folder, for the backup routes). `kdb serve market` serves the one database folder `market`; [Many databases](#many-databases) shows a server for a whole data folder.

```powershell
kdb serve market --backups backups
```

All examples use `http://127.0.0.1:9900`. On Windows, write `curl.exe` (in PowerShell, `curl` alone is another command).

## Routes

| Method | Path | What it does | Login needed |
|---|---|---|---|
| GET | `/health` | Is the server alive? Version, clock. | no |
| POST | `/api/login` | Log in with a user name and password: a cookie and a token (chapter 16) | no |
| POST | `/api/logout` | End the login | no |
| GET | `/api/me` | The logged-in user and role | yes |
| GET | `/exec?query=SQL` | Run SQL that **reads**. JSON result. | yes |
| POST | `/exec` | Run **any** SQL (the body is the SQL). JSON result. | yes |
| DELETE | `/exec/<id>` | Stop the running request sent with `X-KDB-Request-Id: <id>` ([Stop a slow request](#stop-a-slow-request)) | yes |
| GET or POST | `/exp?query=SQL` | Run a SELECT and download CSV | yes |
| POST | `/imp?name=table` | Load a CSV file into a table, as QuestDB does ([/imp](#imp-load-csv)) | yes |
| GET | `/api/info` | Tables, columns, sizes, damage, last backup | yes |
| POST | `/api/check` | Read every file and the log; report damage | yes |
| POST | `/api/backup` | Make a verified backup (needs `--backups`) | yes |
| GET | `/api/backups` | List backups, newest first | yes |
| GET | `/api/audit?limit=N&where=...` | The audit log: logins, user changes, DDL, backups (server admins; chapter 21). `kind=data` reads the data-change rows of the database | yes |
| GET | `/api/databases` | List the databases: name, folder, tables, bytes | yes |
| POST | `/api/databases` | Create a database (`name=<name>` or `{"name":"<name>"}`) | yes |
| DELETE | `/api/databases/<name>` | Drop a database (its folder moves to `_trash`) | yes |
| POST | `/cursor` | Run one SELECT and keep its rows (see [Cursors](#cursors-read-a-big-result-bit-by-bit)) | yes |
| GET | `/cursor/<id>?fetch=N` | The next N kept rows | yes |
| DELETE | `/cursor/<id>` | Close the cursor | yes |
| POST | `/session`, DELETE `/session/<id>` | A transaction over many requests: send `X-KDB-Session: <id>` with each `/exec` (chapter 15) | yes |
| POST | `/write` (also `/api/v2/write`) | Load rows in the InfluxDB line format, the fast way for feeds and sensors ([Line protocol](#post-write-line-protocol)) | yes |
| GET | `/api/stats` | Memory, processor, running statements, open databases (the console's **Monitor**) | yes |
| GET | `/api/disk` | What a database takes on disk, part by part | yes |
| GET | `/api/activity` | Recent server events (the console's **Terminal**) | yes |
| GET | `/api/trigger-queue` | The queues of deferred triggers (chapter 13) | yes |
| GET, POST | `/api/timers` | SQL that runs on a schedule (admins) | yes |
| GET, POST, DELETE | `/api/pins` | Statements whose results are kept ready (admins; chapter 17) | yes |
| GET, POST | `/api/settings`, POST `/api/restart` | Saved settings in `kdb.conf` (the console's **Settings** page); restart in place (admins) | yes |
| GET | `/` | The web console (chapter 6), from the folder `web/` next to `kdb` | no |
| GET | `/help/` | The help pages, from the folder `help/` next to `kdb` | no |
| GET | `/skill.md` | The Claude skill file, from the folder `skill/` next to `kdb` | no |

"Login needed" applies when the server was started with `--token`, or when its data folder has users (chapter 16). Then each user may only do what their role allows; other requests get HTTP 403.

Every route that reads or changes data (all except `/health` and `/api/databases`) works on **one database**: the one named by the parameter `db=<name>` or the header `X-KDB-Database: <name>`. Without them, the server's default database is used. With `kdb serve market` the server has only that database, so you can leave `db` out. See [Many databases](#many-databases).

Parameters for `/exec` and `/exp`:

| Parameter | Meaning | Default |
|---|---|---|
| `db` | The database (also for `/api/info`, `/api/check`, `/api/backup`, `/api/backups`, `/write`) | the default database |
| `query` | The SQL (for GET, or as a form field in POST) | - |
| `limit` | Most rows per statement. At most 1,000,000. `limit=0` means 1,000,000. QuestDB style `limit=10,500` uses the second number. | `/exec`: 10,000; `/exp`: 1,000,000 |
| `compat` | `compat=0` leaves out the QuestDB-style copy of the last result (see below) | `1` |
| `format` | (`/exec` only) `columns`: each `dataset` as one list per column ([format=columns](#format-columns-and-etag)) | `rows` |
| `atomic` | (`/exec` only) `atomic=1` (or the header `X-KDB-Atomic: 1`): all statements of the body are one transaction, all or nothing ([atomic=1](#atomic-1-all-or-nothing)) | `0` |
| `cache` | `cache=0`: do not use the result cache for this request (for timing tests) | `1` |
| `filename` | (`/exp` only) name of the downloaded file | `kdb-export.csv` |

## GET /health

```powershell
curl.exe -s http://127.0.0.1:9900/health
```

```json
{"status":"ok","version":"0.2.0-dev","server_time_ms":1789114666217,"auth_required":false,"login":false}
```

`server_time_ms` is the server clock in milliseconds since 1970 (UTC). `auth_required` is `true` when requests need a token or a login. `login` is `true` when the data folder has users (the console then shows a login form). Use `/health` for monitoring: it never needs a token and never touches the data.

## /exec: run SQL

### GET only reads

Use `--data-urlencode` so curl makes the URL safe (spaces, quotes, `%`):

```powershell
curl.exe -s -G http://127.0.0.1:9900/exec --data-urlencode "query=SELECT id, name FROM brokers WHERE id < 40"
```

The answer (formatted for reading; the server sends it on one line):

```json
{
  "query": "SELECT id, name FROM brokers WHERE id < 40",
  "results": [
    {
      "statement": "SELECT id, name FROM brokers WHERE id < 40",
      "columns": [ { "name": "id", "type": "INT" }, { "name": "name", "type": "STRING" } ],
      "dataset": [ [1, "Keystone Securities"], [34, "Vision Securities"] ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": { "parse_us": 7, "execute_us": 167 }
    }
  ],
  "columns": [ { "name": "id", "type": "INT" }, { "name": "name", "type": "STRING" } ],
  "dataset": [ [1, "Keystone Securities"], [34, "Vision Securities"] ],
  "count": 2,
  "timings": { "parse_us": 7, "execute_us": 167 }
}
```

| Field | Meaning |
|---|---|
| `query` | The SQL you sent |
| `results` | One object per statement |
| `results[].statement` | The statement, as KDB understood it |
| `results[].columns` | Name and type of each column |
| `results[].dataset` | The rows. Each row is a list of values in column order. |
| `results[].count` | Number of rows in `dataset` |
| `results[].truncated` | `true` if there were more rows than `limit` |
| `results[].rows_affected` | Rows changed by INSERT, UPDATE or DELETE |
| `results[].message` | For example `3 row(s) inserted` |
| `results[].timings` | Microseconds for parsing and running |
| `columns`, `dataset`, `count` (top level) | A copy of the **last** result, like QuestDB's `/exec`. Left out with `compat=0`. |

Values: numbers are JSON numbers; `TIMESTAMP` and `DATE` are UTC text like `"2026-09-09T05:15:00.000Z"`; `DECIMAL` is text (`"1500.25"`), so it stays exact; `BOOL` is `true`/`false`; NULL is `null`.

### POST runs anything

Send the SQL as the request body. `--data-binary` sends it unchanged.

```powershell
curl.exe -s http://127.0.0.1:9900/exec --data-binary "SELECT symbol, ltp FROM live_data LATEST ON timestamp PARTITION BY symbol LIMIT 2"
```

```json
{"query":"SELECT symbol, ltp FROM live_data LATEST ON timestamp PARTITION BY symbol LIMIT 2","results":[{"statement":"SELECT symbol, ltp FROM live_data LATEST ON timestamp PARTITION BY symbol LIMIT 2","columns":[{"name":"symbol","type":"SYMBOL"},{"name":"ltp","type":"DOUBLE"}],"dataset":[["CITY",527.1],["COAST",401.9]],"count":2,"truncated":false,"rows_affected":0,"message":"","timings":{"parse_us":35,"execute_us":150}}],"columns":[{"name":"symbol","type":"SYMBOL"},{"name":"ltp","type":"DOUBLE"}],"dataset":[["CITY",527.1],["COAST",401.9]],"count":2,"timings":{"parse_us":35,"execute_us":150}}
```

The body can also be a form: `query=<SQL>` with `Content-Type: application/x-www-form-urlencoded`.

Many statements in one request, with `compat=0`:

```powershell
curl.exe -s "http://127.0.0.1:9900/exec?compat=0" --data-binary "INSERT INTO brokers VALUES (21, 'Test Broker'); SELECT count(*) AS brokers FROM brokers"
```

```json
{
  "query": "INSERT INTO brokers VALUES (21, 'Test Broker'); SELECT count(*) AS brokers FROM brokers",
  "results": [
    {
      "statement": "INSERT INTO brokers VALUES (21, 'Test Broker')",
      "columns": [], "dataset": [], "count": 0, "truncated": false,
      "rows_affected": 1, "message": "1 row(s) inserted",
      "timings": { "parse_us": 13, "execute_us": 3454 }
    },
    {
      "statement": "SELECT count(*) AS brokers FROM brokers",
      "columns": [ { "name": "brokers", "type": "LONG" } ],
      "dataset": [ [6] ], "count": 1, "truncated": false,
      "rows_affected": 0, "message": "",
      "timings": { "parse_us": 13, "execute_us": 30 }
    }
  ],
  "timings": { "parse_us": 26, "execute_us": 3484 }
}
```

(formatted for reading)

### The GET rule

`GET /exec` only runs statements that **read**: `SELECT`, `SHOW ...`, `EXPLAIN`, `CHECK TABLE`, `USE`. Everything that changes data (`INSERT`, `UPDATE`, `DELETE`, `CREATE`, `DROP`, `ALTER`, `RENAME`, `CREATE VIEW`, `DROP VIEW`, `BACKUP DATABASE`, `CREATE DATABASE`, `DROP DATABASE`) must use **POST**.

Why: a link or an image on any web page can make your browser send a GET request. With this rule, such a page cannot change your data.

```powershell
# GET /exec only reads. SQL that changes data must use POST.
curl.exe -s -w "   (HTTP %{http_code})" -G http://127.0.0.1:9900/exec --data-urlencode "query=DELETE FROM brokers WHERE id = 21"
""
# The same SQL with POST works:
curl.exe -s "http://127.0.0.1:9900/exec?compat=0" --data-binary "DELETE FROM brokers WHERE id = 21"
```

```text
{"error":"this SQL changes data, so it must be sent with POST /exec (GET /exec only reads)"}   (HTTP 405)
{"query":"DELETE FROM brokers WHERE id = 21","results":[{"statement":"DELETE FROM brokers WHERE id = 21","columns":[],"dataset":[],"count":0,"truncated":false,"rows_affected":1,"message":"1 row(s) deleted","timings":{"parse_us":15,"execute_us":4637}}],"timings":{"parse_us":15,"execute_us":4637}}
```

(`-w "(HTTP %{http_code})"` makes curl print the HTTP status after the body.)

### Errors

A bad statement gets **HTTP 400** and an `error`. When KDB knows the place, `line` and `column` are separate fields:

```powershell
curl.exe -s -w "\nHTTP status: %{http_code}\n" http://127.0.0.1:9900/exec --data-binary "SELECT clsoe FROM ochl_day"
```

```text
{"query":"SELECT clsoe FROM ochl_day","results":[],"saved":0,"rolled_back":false,"error":"line 1, column 8: unknown column 'clsoe' (table 'ochl_day' has: time symbol open high low close volume)","line":1,"column":8}
HTTP status: 400
```

| HTTP status | Meaning |
|---|---|
| 200 | OK |
| 400 | The SQL or the request is wrong (syntax, duplicate key, missing query, ...) |
| 401 | Token missing or wrong |
| 403 | Refused for safety: cross-site request, a host name that is not allowed, missing rights, or a read-only database |
| 404 | No such route, or no such database (`db=`) |
| 409 | The database already exists, or it is in use and cannot be dropped now |
| 405 | GET /exec with SQL that changes data |
| 408 | The request did not arrive within 30 seconds, or the statement was stopped: statement timeout, `DELETE /exec/<id>`, server shutdown |
| 413 | Request body bigger than 64 MB, or the query keeps too much in memory (`--max-result-memory`, `--max-groups`) |
| 429 | Too many failed logins, or the user already runs `--max-queries-per-user` statements |
| 431 | Request headers bigger than 64 KB |
| 500 | Problem on the server: a damaged file, or the database is locked by another program |
| 503 | Busy: a table stayed locked by another transaction too long (`table 'x' is busy`), a `deadlock`, or the server is stopping. Try again a moment later. |
| 507 | The disk is full. Nothing of the request was saved. It works again once space is freed. |
| 304 | Not changed: the `If-None-Match` tag is still the same ([ETag](#format-columns-and-etag)). No body. |

With many statements, `results` holds the statements that ran **before** the error. The statements after the error did not run. Two fields say what was kept:

| Field | Meaning |
|---|---|
| `saved` | How many of the statements in `results` are saved. |
| `rolled_back` | `true` when the error undid an open transaction (or an `atomic=1` request): then nothing of it is saved, `saved` is `0`. |

### atomic=1: all or nothing

Normally each statement of a request is saved on its own. With `atomic=1`, the whole body is **one transaction**: when one statement fails, the ones before it are undone too.

```powershell
# atomic=1: the whole body is one transaction. The second INSERT fails, so the first is undone too.
curl.exe -s -w "   (HTTP %{http_code})" "http://127.0.0.1:9900/exec?atomic=1&compat=0" --data-binary "INSERT INTO brokers VALUES (22, 'New Broker'); INSERT INTO brokers VALUES (1, 'Keystone again')"
""
curl.exe -s -G http://127.0.0.1:9900/exec --data-urlencode "query=SELECT count(*) AS brokers FROM brokers WHERE id = 22" --data-urlencode "compat=0"
```

```text
{"query":"INSERT INTO brokers VALUES (22, 'New Broker'); INSERT INTO brokers VALUES (1, 'Keystone again')","results":[{"statement":"INSERT INTO brokers VALUES (22, 'New Broker')","columns":[],"dataset":[],"count":0,"truncated":false,"rows_affected":1,"message":"1 row(s) inserted","timings":{"parse_us":5,"execute_us":31}}],"saved":0,"rolled_back":true,"error":"a row with id='1' already exists in 'brokers'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it (the transaction was rolled back)"}   (HTTP 400)
{"query":"SELECT count(*) AS brokers FROM brokers WHERE id = 22","results":[{"statement":"SELECT count(*) AS brokers FROM brokers WHERE id = 22","columns":[{"name":"brokers","type":"LONG"}],"dataset":[[0]],"count":1,"truncated":false,"rows_affected":0,"message":"","timings":{"parse_us":9,"execute_us":63}}],"timings":{"parse_us":9,"execute_us":63}}
```

Broker 22 is not there: `"saved":0,"rolled_back":true`. Statements that cannot run in a transaction (`CREATE`, `DROP`, `ALTER`, `TRUNCATE`, `BACKUP DATABASE`, ...) are refused before anything runs. For a transaction over several requests, use `POST /session` (chapter 15).

### limit and truncated

```powershell
curl.exe -s -G "http://127.0.0.1:9900/exec" --data-urlencode "query=SELECT time, close FROM ochl_minutes WHERE symbol = 'CITY'" --data-urlencode "limit=2" --data-urlencode "compat=0"
```

```json
{"query":"SELECT time, close FROM ochl_minutes WHERE symbol = 'CITY'","results":[{"statement":"SELECT time, close FROM ochl_minutes WHERE symbol = 'CITY'","columns":[{"name":"time","type":"TIMESTAMP"},{"name":"close","type":"DOUBLE"}],"dataset":[["2026-09-09T05:15:00.000Z",512.1],["2026-09-09T05:16:00.000Z",511.9]],"count":2,"truncated":true,"rows_affected":0,"message":"","timings":{"parse_us":46,"execute_us":347}}],"timings":{"parse_us":46,"execute_us":347}}
```

`"truncated":true` tells you that more rows exist. If you need all rows, use a bigger `limit`, `/exp`, or read page by page with `ORDER BY time LIMIT 10000 OFFSET ...`.

### format=columns and ETag

A chart or a program that works column by column can ask for one list per column. It is also shorter, because the column names are not repeated:

```powershell
# format=columns: one list per column instead of one list per row.
curl.exe -s -G http://127.0.0.1:9900/exec --data-urlencode "query=SELECT symbol, close FROM ochl_day WHERE time IN '2026-09-10'" --data-urlencode "format=columns" --data-urlencode "compat=0"
""
# Every answer with rows has an ETag. curl saves it, then sends it back as If-None-Match:
# while the rows are the same, the answer is 304 and has no body.
$url = "http://127.0.0.1:9900/exec?compat=0&query=SELECT%20count(*)%20AS%20brokers%20FROM%20brokers"
curl.exe -s --etag-save etag.txt $url
""
"saved ETag: $(Get-Content etag.txt)"
curl.exe -s -w "(HTTP %{http_code})" --etag-compare etag.txt $url
```

```text
{"query":"SELECT symbol, close FROM ochl_day WHERE time IN '2026-09-10'","results":[{"statement":"SELECT symbol, close FROM ochl_day WHERE time IN '2026-09-10'","columns":[{"name":"symbol","type":"SYMBOL"},{"name":"close","type":"DOUBLE"}],"dataset":{"symbol":["CITY","COAST","VOLT"],"close":[504.9,376.1,191.2]},"count":3,"truncated":false,"rows_affected":0,"message":"","timings":{"parse_us":15,"execute_us":203}}],"timings":{"parse_us":15,"execute_us":203}}
{"query":"SELECT count(*) AS brokers FROM brokers","results":[{"statement":"SELECT count(*) AS brokers FROM brokers","columns":[{"name":"brokers","type":"LONG"}],"dataset":[[6]],"count":1,"truncated":false,"rows_affected":0,"message":"","timings":{"parse_us":10,"execute_us":196}}],"timings":{"parse_us":10,"execute_us":196}}
saved ETag: "08452937-5r"
(HTTP 304)
```

- With `format=columns`, `dataset` is an object: `{"symbol": [...], "close": [...]}`. The top-level copy (without `compat=0`) has the same form.
- An `/exec` answer with rows has an **ETag** header: a short tag made from the rows of the last statement. Send it back as `If-None-Match`. While the rows are the same, the answer is **304** with no body, so a dashboard that asks every few seconds does not download the same rows again.
- `curl --etag-save` and `--etag-compare` do this for you. In other programs, keep the `ETag` header and send it back.
- One case has no ETag: `compat=0` in the row format, when the result is not kept in the result cache (`cache=0`, or a query with `now()` or `random()`).

## /exp: download CSV

```powershell
curl.exe -s -G http://127.0.0.1:9900/exp --data-urlencode "query=SELECT time, symbol, close FROM ochl_day WHERE time IN '2026-09-10'" -o closes.csv
Get-Content closes.csv
```

```text
time,symbol,close
2026-09-10T00:00:00.000Z,CITY,504.9
2026-09-10T00:00:00.000Z,COAST,376.1
2026-09-10T00:00:00.000Z,VOLT,191.2
```

- Header line, then rows. Lines end with CRLF. Text with commas or quotes is quoted.
- NULL is an empty field. Times are UTC.
- The answer has `Content-Disposition: attachment; filename="kdb-export.csv"`, so a browser downloads it. Change the name with `&filename=day.csv`.
- `/exp` accepts only reading statements. Anything else:

```powershell
curl.exe -s -w "   (HTTP %{http_code})" -G http://127.0.0.1:9900/exp --data-urlencode "query=INSERT INTO brokers VALUES (22, 'Export Test')"
```

```text
{"error":"CSV export needs a SELECT, SHOW or EXPLAIN statement"}   (HTTP 400)
```

## /imp: load CSV

`POST /imp` loads a CSV file into a table, the way QuestDB's `/imp` does. Send the file as a form part named `data` (or the CSV itself as the body).

```powershell
curl.exe -s -F "data=@day_closes.csv" "http://127.0.0.1:9900/imp?name=day_closes&timestamp=time&partitionBy=YEAR&fmt=json"
```

```text
{"status":"OK","location":"day_closes","rowsRejected":0,"rowsImported":2,"header":true,"partitionBy":"YEAR","timestamp":"time","columns":[{"name":"time","type":"TIMESTAMP","size":8,"errors":0},{"name":"symbol","type":"STRING","size":0,"errors":0},{"name":"close","type":"DOUBLE","size":8,"errors":0},{"name":"volume","type":"LONG","size":8,"errors":0}]}
```

| Parameter | Meaning | Default |
|---|---|---|
| `name` | The table. A new name makes a new table. | the file name without `.csv` |
| `timestamp` | New table: its time column (a `TIMESERIES` table) | none (a relational table) |
| `partitionBy` | New table: `NONE`, `DAY`, `MONTH` or `YEAR` (needs `timestamp`) | `NONE` |
| `overwrite` | `true`: drop the table and make it again from the file | `false` |
| `atomicity` | A value that does not fit its column: `skipCol` makes it NULL, `skipRow` leaves the row out, `abort` loads nothing | `skipCol` |
| `delimiter` | `,`, `;`, `\t` or `|` | found from the first line |
| `forceHeader` | `true`: the first line is a header | found from the first line |
| `fmt` | `json` for the JSON answer above; otherwise a short text answer | text |
| `db` | The database | the default database |

- **Header.** The first line is a header when its values match the table's columns, or when none of them looks like data (a number, `true`/`false`, a time). Columns are matched by name, in any order. Without a header, the values go to the table's columns in order.
- **New tables.** Each column's type comes from its values: `BOOLEAN`, `LONG`, `DOUBLE`, `DATE`, `TIMESTAMP`, else `STRING`. A form part named `schema` may give types: `[{"name":"symbol","type":"SYMBOL"}]`. Making (or dropping, with `overwrite`) a table needs the admin role.
- **Values.** An empty field is NULL; `""` is an empty text. Quoted values may hold commas, quotes (`""`) and line breaks. Times like `2026-09-10T00:00:00.000000Z` work; a long number in a time column is microseconds since 1970 (QuestDB).
- **Keys.** A table with a `DEDUP KEY` keeps the newest row of each key, as QuestDB's `DEDUP UPSERT KEYS` does.
- **All or nothing.** Rows the server refuses (a missing time, a `NOT NULL` column) follow `atomicity` too. What is loaded is one transaction.
- **Speed.** Rows go in the way the line protocol writes them: whole partitions are sorted and written at once.

```powershell
curl.exe -s -w "   (HTTP %{http_code})" -F "data=@bad.csv" "http://127.0.0.1:9900/imp?name=day_closes&atomicity=abort&fmt=json"
```

```text
{"status":"line 2, column 'close': 'abc' is not a number (atomicity=abort: nothing was imported)"}   (HTTP 400)
```

## POST /write: line protocol

For live feeds and sensors, the **line protocol** of InfluxDB (also used by QuestDB) is the fastest way to load rows. Each line is one row: `table,tag=text field=value,field=value time`.

```powershell
# Two new live prices in the line format: table,tag=text field=value,... time
$lines = "live_data,symbol=CITY ltp=528.5,ltv=120i,volume=45120i 1789031700`nlive_data,symbol=VOLT ltp=192.4,ltv=80i,volume=21000i 1789031700"
curl.exe -s -w "(HTTP %{http_code})" "http://127.0.0.1:9900/write?precision=s" --data-binary $lines
""
curl.exe -s -G http://127.0.0.1:9900/exec --data-urlencode "query=SELECT timestamp, symbol, ltp, ltv, volume FROM live_data WHERE timestamp = '2026-09-10T15:00:00+05:45'" --data-urlencode "compat=0"
```

```text
(HTTP 204)
{"query":"SELECT timestamp, symbol, ltp, ltv, volume FROM live_data WHERE timestamp = '2026-09-10T15:00:00+05:45'","results":[{"statement":"SELECT timestamp, symbol, ltp, ltv, volume FROM live_data WHERE timestamp = '2026-09-10T15:00:00+05:45'","columns":[{"name":"timestamp","type":"TIMESTAMP"},{"name":"symbol","type":"SYMBOL"},{"name":"ltp","type":"DOUBLE"},{"name":"ltv","type":"LONG"},{"name":"volume","type":"LONG"}],"dataset":[["2026-09-10T09:15:00.000Z","CITY",528.5,120,45120],["2026-09-10T09:15:00.000Z","VOLT",192.4,80,21000]],"count":2,"truncated":false,"rows_affected":0,"message":"","timings":{"parse_us":12,"execute_us":58}}],"timings":{"parse_us":12,"execute_us":58}}
```

- A good request answers **204** and has no body. All lines of one request are one transaction: all or nothing.
- The table must exist. Tags (before the first space) fill `SYMBOL` or `STRING` columns. Whole numbers need an `i` at the end (`120i`).
- The time at the end is in nanoseconds, unless you say `precision=s`, `ms` or `u` (microseconds). Without `precision=`, times that look like seconds or milliseconds are refused with 400, so wrong dates do not get in. Always send `precision=` when your times are not nanoseconds.
- The help topic **Line protocol** has every rule.

## GET /api/info

Everything the console's sidebar shows.

```powershell
$info = Invoke-RestMethod http://127.0.0.1:9900/api/info
"version: $($info.version)   log LSN: $($info.last_lsn)   damaged files: $($info.damaged.Count)"
$info.tables | Select-Object name, kind, partition, timestamp_column, rows | Format-Table -AutoSize
```

```text
version: 0.2.0-dev   log LSN: 32   damaged files: 0

name         kind       partition timestamp_column rows
----         ----       --------- ---------------- ----
brokers      relational NONE                          6
trade_log    timeseries DAY       date               32
live_data    timeseries DAY       timestamp          12
ochl_day     timeseries YEAR      time               57
ochl_minutes timeseries MONTH     time              956
securities   relational NONE                          5
```

The JSON has these fields (the start of a real answer, cut):

```json
{"dir":"market","version":"0.2.0-dev","opened_ms":1789113512561,"server_time_ms":1789113526709,"last_lsn":1098,"data_files":10,"data_bytes":75739,"tables":[{"name":"brokers","kind":"relational","partition":"NONE","timestamp_column":"","rows":7,"bytes":336,"columns":[{"name":"id","type":"INT","primary_key":true,"not_null":false,"computed":false,"references":""},{"name":"name","type":"STRING","primary_key":false,"not_null":true,"computed":false,"references":""}],"create_sql":"CREATE TABLE brokers (\n  id INT PRIMARY KEY,\n  name STRING NOT NULL\n)"}, ...
```

| Field | Meaning |
|---|---|
| `dir`, `version` | Database folder and KDB version |
| `opened_ms`, `server_time_ms` | When the database was opened; the server clock (ms since 1970, UTC) |
| `last_lsn` | Number of the last change in the log |
| `data_files`, `data_bytes` | Count and size of the data files |
| `tables[]` | `name`, `kind`, `partition`, `timestamp_column`, `rows`, `bytes`, `columns[]`, `create_sql` |
| `damaged[]` | Damaged files (empty when all is OK) |
| `recovery_summary` | What happened when the database was opened |
| `backup_dir`, `last_backup` | Backup folder and the newest backup (or `null`) |
| `auth_required` | Token mode |
| `read_only` | The database (or the whole server) takes no changes |
| `protection` | The server's `statement_timeout_ms`, `max_result_bytes`, `max_groups`, `max_queries_per_user`, `safe_updates`, `running` statements, `server_read_only`, `audit` |
| `backup_schedule` | With `--backup-schedule`: `schedule`, `copy_to`, `next_run_ms`, `last_run_ms`, `last_run_ok`, `last_ok_ms`, `running`, `warning`, and `databases[]` of the last run (`ok`, `error`, `dir`, `files`, `bytes`, `copy_ok`, `copy_error`, ...) |

## POST /api/check

```powershell
curl.exe -s -X POST http://127.0.0.1:9900/api/check
```

```json
{"ok":true,"files_checked":11,"bytes_checked":76566,"wal_segments_checked":1,"problems":[],"elapsed_us":11880}
```

`ok` is `false` when there is damage; `problems` then lists it. For big databases this reads every file, so it can take time.

## POST /api/backup and GET /api/backups

```powershell
curl.exe -s -X POST http://127.0.0.1:9900/api/backup
```

```json
{"name":"20260923-120933-857","dir":"backups/20260923-120933-857","created_ms":1790165373857,"created":"2026-09-23T12:09:33.857Z","end_lsn":32,"checkpoint_lsn":32,"files":9,"bytes":194672}
```

```powershell
curl.exe -s http://127.0.0.1:9900/api/backups
```

```json
{"backups":[{"name":"20260923-120933-857","dir":"backups/20260923-120933-857","created_ms":1790165373857,"created":"2026-09-23T12:09:33.857Z","end_lsn":32,"checkpoint_lsn":32,"files":9,"bytes":194672}]}
```

- Without `--backups`, `/api/backup` answers HTTP 400 `no backup folder is set; start KDB with a backup folder (for example --backups D:/kdb_backups)`.
- After each backup the server removes old backups: it keeps the newest of each of the last 7 days and 4 weeks.
- `BACKUP DATABASE` (as SQL, with POST) does the same:

```powershell
curl.exe -s "http://127.0.0.1:9900/exec?compat=0" --data-binary "BACKUP DATABASE"
```

```json
{"query":"BACKUP DATABASE","results":[{"statement":"BACKUP DATABASE","columns":[{"name":"backup","type":"STRING"},{"name":"files","type":"LONG"},{"name":"bytes","type":"LONG"},{"name":"log_lsn","type":"LONG"}],"dataset":[["backups/20260923-120934-350",9,194672,32]],"count":1,"truncated":false,"rows_affected":0,"message":"backup created and verified","timings":{"parse_us":8,"execute_us":51416}}],"timings":{"parse_us":8,"execute_us":51416}}
```

A daily backup script for a running server (see chapter 7):

```powershell
# daily-backup-server.ps1
$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/api/backup"
"backup $($r.name): $($r.files) files, $($r.bytes) bytes"
$c = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/api/check"
if (-not $c.ok) { Write-Output "CHECK FOUND A PROBLEM: $($c.problems -join '; ')"; exit 2 }
"check ok: $($c.files_checked) files"
```

```text
backup 20260923-121039-826: 9 files, 195468 bytes
check ok: 14 files
```

## Many databases

`kdb serve` without a folder serves **every database in the data folder** (chapter 1). Each request chooses its database:

- the parameter `db=<name>` (in the URL, or as a form field), or
- the header `X-KDB-Database: <name>` (handy when a program talks to one database all the time).

`db=` wins when both are given. Without either, the default database is used (`--db <name>`, else `default`, which is created when first used). Names ignore case.

This example starts a second server on port 9946 for the data folder `kdb-data`:

```powershell
# A server for a whole data folder: every database in it, chosen per request.
# --pg-port 0: the first server already has the Postgres port 8832.
$server = Start-Process kdb -ArgumentList "serve", "--data-dir", "kdb-data", "--port", "9946", "--pg-port", "0" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 1
$u = "http://127.0.0.1:9946"

# Create two databases.
Invoke-RestMethod -Method Post "$u/api/databases?name=market" | ConvertTo-Json -Compress
Invoke-RestMethod -Method Post "$u/api/databases" -ContentType "application/json" -Body '{"name":"demo"}' | ConvertTo-Json -Compress

# The same table name in both, with different rows: db=<name> or the X-KDB-Database header picks the database.
$sql = "CREATE TABLE prices (symbol SYMBOL PRIMARY KEY, close DOUBLE)"
$null = Invoke-RestMethod -Method Post "$u/exec?db=market" -ContentType "text/plain" -Body "$sql; INSERT INTO prices VALUES ('CITY', 527.1), ('COAST', 401.9)"
$null = Invoke-RestMethod -Method Post "$u/exec" -Headers @{ "X-KDB-Database" = "demo" } -ContentType "text/plain" -Body "$sql; INSERT INTO prices VALUES ('TEST', 1)"
curl.exe -s "$u/exp?db=market&query=SELECT%20*%20FROM%20prices"
curl.exe -s "$u/exp?db=demo&query=SELECT%20*%20FROM%20prices"

# A query in market can read a table of demo: database.table
curl.exe -s -G "$u/exp" --data-urlencode "db=market" --data-urlencode "query=SELECT symbol, close FROM prices UNION ALL SELECT symbol, close FROM demo.prices"

# Every database, with its table count.
(Invoke-RestMethod "$u/api/databases").databases | Select-Object name, tables, default | Format-Table -AutoSize

# A database that does not exist.
curl.exe -s -w "   (HTTP %{http_code})" "$u/exec?db=nope&query=SELECT%201"
""

# Drop one: its folder moves to kdb-data\_trash.
(Invoke-RestMethod -Method Delete "$u/api/databases/demo").dropped
"demo folder: $(Test-Path kdb-data\demo)   folders in _trash: $((Get-ChildItem kdb-data\_trash).Count)"

Stop-Process -Id $server.Id
```

```text
{"name":"market","created":true}
{"name":"demo","created":true}
symbol,close
CITY,527.1
COAST,401.9
symbol,close
TEST,1
symbol,close
CITY,527.1
COAST,401.9
TEST,1

name   tables default
----   ------ -------
demo        1   False
market      1   False

{"error":"database 'nope' does not exist; create it with CREATE DATABASE nope"}   (HTTP 404)
True
demo folder: False   folders in _trash: 1
```

A query can also **read** a table of another database on the same server: write `database.table`, like `demo.prices` above. It works in `SELECT`, `JOIN`, subqueries and `INSERT ... SELECT`. A statement only **changes** tables of its own database. The user needs the right to read the other database. The help topic **Queries across databases** has more.

### GET /api/databases

```json
{"databases":[{"name":"demo","dir":"kdb-data/demo","default":false,"open":true,"tables":1,"bytes":235},{"name":"market","dir":"kdb-data/market","default":false,"open":true,"tables":1,"bytes":235}],"default":"default","data_dir":"kdb-data","can_create":true}
```

| Field | Meaning |
|---|---|
| `databases[]` | Every database, sorted by name: `name`, `dir` (its folder), `default`, `open`, `tables`, `bytes` (data files). When a database cannot be opened (for example another program uses it), `tables` is `null` and `error` says why. |
| `default` | The database used when a request has no `db=` |
| `data_dir` | The data folder (empty for `kdb serve <folder>`) |
| `can_create` | `false` for `kdb serve <folder>`: that server has one database and cannot create or drop others |

Listing opens every database, so the list can count its tables.

### POST /api/databases and DELETE /api/databases/&lt;name&gt;

| Request | Answer |
|---|---|
| `POST /api/databases?name=market` (or form `name=market`, or JSON `{"name":"market"}`) | `200 {"name":"market","created":true}`; `409` if it exists; `400` for a bad name |
| `DELETE /api/databases/demo` | `200 {"name":"demo","dropped":true,"moved_to":"kdb-data/_trash/1789136015339-demo"}`; `404` if it does not exist; `409` while a request uses it |
| `GET /api/databases/demo` | `405`: changes need POST or DELETE |

A dropped database is **not deleted**. Its folder moves to `<data folder>/_trash/<time in ms>-<name>`. To get it back, stop the server and move the folder back into the data folder.

### Database statements in SQL

`/exec` also runs `CREATE DATABASE`, `DROP DATABASE`, `SHOW DATABASES` and `USE` (chapter 11). `CREATE` and `DROP DATABASE` need POST. `USE name` changes the database only for the **rest of that request**:

```powershell
curl.exe -s "http://127.0.0.1:9946/exec?compat=0" --data-binary "USE market; SELECT count(*) FROM prices"
```

```json
{"query":"USE market; SELECT count(*) FROM prices","results":[{"statement":"USE market","columns":[],"dataset":[],"count":0,"truncated":false,"rows_affected":0,"message":"using database 'market'","timings":{"parse_us":0,"execute_us":8}},{"statement":"SELECT count(*) FROM prices","columns":[{"name":"count(*)","type":"LONG"}],"dataset":[[2]],"count":1,"truncated":false,"rows_affected":0,"message":"","timings":{"parse_us":22,"execute_us":91}}],"timings":{"parse_us":22,"execute_us":99}}
```

The next request uses `db=` (or the default database) again.

## Cursors: read a big result bit by bit

`/exec` returns at most 1,000,000 rows at once, and a big result is a big reply. A **cursor** runs the SELECT once, keeps the rows on the server, and gives them to you a few at a time.

| Request | Answer |
|---|---|
| `POST /cursor` with one SELECT as the body | `{"cursor":"<id>","columns":[...],"rows":N}` |
| `GET /cursor/<id>?fetch=N` | the next N rows (default 1,000): `{"cursor","columns","dataset","count","done"}`. `done` is true when no rows are left. |
| `DELETE /cursor/<id>` | `{"cursor":"<id>","closed":true}` |

```powershell
# A cursor: the server runs the SELECT once and keeps the rows; you read them bit by bit.
$c = Invoke-RestMethod -Method Post "http://127.0.0.1:9900/cursor" -ContentType "text/plain" `
  -Body "SELECT time, symbol, close FROM ochl_minutes WHERE time IN '2026-09-10' ORDER BY time, symbol"
"rows kept: $($c.rows)   columns: $(($c.columns | ForEach-Object { $_.name }) -join ', ')"

# GET only reads the kept rows: 3 at a time.
foreach ($i in 1..2) {
  $page = Invoke-RestMethod "http://127.0.0.1:9900/cursor/$($c.cursor)?fetch=3"
  $page.dataset | ForEach-Object { $_ -join ' | ' }
  "count: $($page.count)   done: $($page.done)"
}

# Close it. A closed (or unknown) cursor answers 404.
(Invoke-RestMethod -Method Delete "http://127.0.0.1:9900/cursor/$($c.cursor)").closed
curl.exe -s -o NUL -w "HTTP %{http_code}" "http://127.0.0.1:9900/cursor/$($c.cursor)?fetch=3"
""
```

```text
rows kept: 476   columns: time, symbol, close
2026-09-10T05:15:00.000Z | CITY  | 504.4
2026-09-10T05:15:00.000Z | COAST | 380
2026-09-10T05:16:00.000Z | CITY  | 504.6
count: 3   done: False
2026-09-10T05:16:00.000Z | COAST | 379.6
2026-09-10T05:17:00.000Z | CITY  | 504.2
2026-09-10T05:17:00.000Z | COAST | 380.1
count: 3   done: False
True
HTTP 404
```

- The rows are a snapshot: changes after `POST /cursor` do not change them. They stay in the server's memory until the cursor is closed.
- A cursor closes by itself after 10 minutes without a `GET`. At most 16 cursors per database are open at the same time (SQL cursors from chapter 13 count too). At most 10 million rows per cursor.
- `GET /cursor/<id>` only reads (the rule above: GET never changes data). Opening needs POST, closing needs DELETE.
- Use the same `db=` for all three requests: a cursor belongs to one database.

## Clients

Every client below does the same three things: POST the SQL to `/exec?compat=0`, read `results`, and turn HTTP errors into error messages. The files are in `examples/08-http-api/`.

### PowerShell

```powershell
$sql = "SELECT symbol, sum(quantity) AS shares FROM trade_log WHERE date IN '2026-09-10' GROUP BY symbol ORDER BY shares DESC"
$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/exec?compat=0" -Body $sql -ContentType "text/plain; charset=utf-8"

$result = $r.results[0]
$names = $result.columns | ForEach-Object { $_.name }
"columns: $($names -join ', ')"
foreach ($row in $result.dataset) { "  $($row -join ' | ')" }
```

```text
columns: symbol, shares
  COAST | 2850
  CITY  | 910
  TELCO | 770
  VOLT  | 400
```

To send a `.sql` file with non-English text, send the **bytes** of the file, so no encoding is lost:

```powershell
# Send a whole .sql file in one request.
@"
INSERT OR REPLACE INTO ochl_day VALUES ('2026-09-14', 'COAST', 378.5, 381.0, 377.2, 380.4, 99000);
INSERT OR REPLACE INTO ochl_day VALUES ('2026-09-14', 'VOLT', 193.7, 196.0, 192.8, 195.1, 70500);
"@ | Set-Content load.sql -Encoding UTF8

$body = [System.IO.File]::ReadAllBytes((Resolve-Path load.sql))
$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/exec?compat=0" -Body $body -ContentType "text/plain; charset=utf-8"
$r.results | ForEach-Object { $_.message }
```

```text
1 row(s) inserted
1 row(s) inserted
```

### Python (standard library only)

`client.py`:

```python
# client.py - query KDB from Python. Only the standard library is used.
import json
import os
import urllib.error
import urllib.parse
import urllib.request

KDB = os.environ.get("KDB_URL", "http://127.0.0.1:9900")
TOKEN = ""  # set this if the server was started with --token

def kdb(sql, limit=10000):
    url = KDB + "/exec?" + urllib.parse.urlencode({"limit": limit, "compat": 0})
    req = urllib.request.Request(url, data=sql.encode("utf-8"), method="POST")
    req.add_header("Content-Type", "text/plain; charset=utf-8")
    if TOKEN:
        req.add_header("Authorization", "Bearer " + TOKEN)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)["results"]
    except urllib.error.HTTPError as e:
        body = json.load(e)
        raise RuntimeError(f"KDB error (HTTP {e.code}): {body['error']}") from None

# Insert a row (INSERT OR REPLACE: safe to run again).
print(kdb("INSERT OR REPLACE INTO ochl_day VALUES "
          "('2026-09-13', 'CITY', 505, 509, 503.1, 508.2, 91000)")[0]["message"])

# Read rows as dictionaries.
res = kdb("SELECT time, symbol, close FROM ochl_day WHERE symbol = 'CITY' AND time >= '2026-09-09'")[0]
names = [c["name"] for c in res["columns"]]
for row in res["dataset"]:
    print(dict(zip(names, row)))

# Errors become exceptions.
try:
    kdb("SELECT clsoe FROM ochl_day")
except RuntimeError as err:
    print(err)
```

```powershell
python client.py
```

```text
1 row(s) inserted
{'time': '2026-09-09T00:00:00.000Z', 'symbol': 'CITY', 'close': 504.6}
{'time': '2026-09-10T00:00:00.000Z', 'symbol': 'CITY', 'close': 504.9}
{'time': '2026-09-13T00:00:00.000Z', 'symbol': 'CITY', 'close': 508.2}
KDB error (HTTP 400): line 1, column 8: unknown column 'clsoe' (table 'ochl_day' has: time symbol open high low close volume)
```

Tested with Python 3.15. To turn a time text into a Python `datetime`: `datetime.fromisoformat(t.replace("Z", "+00:00"))`.

### Node.js (18 or newer)

`client.mjs`:

```javascript
// client.mjs - query KDB from Node.js 18 or newer (fetch is built in).
const KDB = process.env.KDB_URL || "http://127.0.0.1:9900";
const TOKEN = ""; // set this if the server was started with --token

async function kdb(sql, limit = 10000) {
  const res = await fetch(`${KDB}/exec?limit=${limit}&compat=0`, {
    method: "POST",
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      ...(TOKEN ? { Authorization: `Bearer ${TOKEN}` } : {}),
    },
    body: sql,
  });
  const body = await res.json();
  if (!res.ok) throw new Error(`KDB error (HTTP ${res.status}): ${body.error}`);
  return body.results;
}

const [res] = await kdb(
  "SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol ORDER BY pct_change DESC"
);
const names = res.columns.map((c) => c.name);
for (const row of res.dataset) {
  console.log(Object.fromEntries(names.map((n, i) => [n, row[i]])));
}

try {
  await kdb("INSERT INTO brokers VALUES (58, 'Duplicate')");
} catch (err) {
  console.log(err.message);
}
```

```powershell
node client.mjs
```

```text
{ symbol: 'CITY', ltp: 527.1, pct_change: 2.71 }
{ symbol: 'TELCO', ltp: 897.7, pct_change: 1.9 }
{ symbol: 'COAST', ltp: 401.9, pct_change: 0.7 }
{ symbol: 'VOLT', ltp: 184, pct_change: -0.86 }
KDB error (HTTP 400): a row with id='58' already exists in 'brokers'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it
```

Tested with Node 24.

### Go (standard library only)

`client.go`:

```go
// client.go - query KDB from Go (standard library only).
// Run: go run client.go
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
)

var kdbURL = "http://127.0.0.1:9900"

const token = "" // set this if the server was started with --token

type column struct {
	Name string `json:"name"`
	Type string `json:"type"`
}

type result struct {
	Statement    string          `json:"statement"`
	Columns      []column        `json:"columns"`
	Dataset      [][]interface{} `json:"dataset"`
	Count        int             `json:"count"`
	RowsAffected int             `json:"rows_affected"`
	Message      string          `json:"message"`
}

type response struct {
	Results []result `json:"results"`
	Error   string   `json:"error"`
	Line    int      `json:"line"`
	Column  int      `json:"column"`
}

func query(sql string) ([]result, error) {
	u := kdbURL + "/exec?" + url.Values{"compat": {"0"}, "limit": {"10000"}}.Encode()
	req, err := http.NewRequest("POST", u, strings.NewReader(sql))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "text/plain; charset=utf-8")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	var r response
	if err := json.Unmarshal(body, &r); err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("KDB error (HTTP %d): %s", resp.StatusCode, r.Error)
	}
	return r.Results, nil
}

func main() {
	if u := os.Getenv("KDB_URL"); u != "" {
		kdbURL = u
	}
	res, err := query("SELECT time, first(open) AS open, last(close) AS close FROM ochl_minutes " +
		"WHERE symbol = 'CITY' AND time IN '2026-09-10' SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu'")
	if err != nil {
		panic(err)
	}
	for _, row := range res[0].Dataset {
		// Times are strings like "2026-09-10T05:15:00.000Z"; numbers are float64.
		fmt.Printf("%v open=%v close=%v\n", row[0], row[1], row[2])
	}

	if _, err := query("DELETE FROM brokers WHERE id = 58"); err != nil {
		fmt.Println(err)
	}
}
```

```powershell
go run client.go
```

```text
2026-09-10T05:15:00.000Z open=504.6 close=505.3
2026-09-10T06:15:00.000Z open=505.3 close=502.7
2026-09-10T07:15:00.000Z open=502.7 close=502.6
2026-09-10T08:15:00.000Z open=502.6 close=504.9
KDB error (HTTP 400): cannot remove brokers(id) = '58': table 'trade_log' column 'buyer' still refers to it (foreign key 'trade_log_buyer_fkey')
```

Tested with Go 1.26. Parse times with `time.Parse(time.RFC3339Nano, s)`. A Go app can also use its PostgreSQL driver `pgx` on port 8832 (chapter 14). This HTTP client needs no driver at all.

### C# (.NET 6 or newer)

`Client.cs` (**not run** while writing this tutorial: there was no .NET SDK on the test PC):

```csharp
// Client.cs - query KDB from C# (.NET 6 or newer).
// NOT RUN while writing the tutorial (no .NET SDK on that computer).
// Use it in a console project: dotnet new console, then replace Program.cs.
using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

class KdbClient
{
    static readonly HttpClient Http = new HttpClient { BaseAddress = new Uri("http://127.0.0.1:9900") };
    const string Token = ""; // set this if the server was started with --token

    static async Task<JsonElement> Query(string sql)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "/exec?compat=0&limit=10000");
        request.Content = new StringContent(sql, Encoding.UTF8, "text/plain");
        if (Token != "") request.Headers.Add("Authorization", "Bearer " + Token);
        using var response = await Http.SendAsync(request);
        var text = await response.Content.ReadAsStringAsync();
        var json = JsonDocument.Parse(text).RootElement.Clone();
        if (!response.IsSuccessStatusCode)
            throw new Exception($"KDB error (HTTP {(int)response.StatusCode}): {json.GetProperty("error").GetString()}");
        return json.GetProperty("results");
    }

    static async Task Main()
    {
        var results = await Query("SELECT symbol, close FROM ochl_day WHERE time IN '2026-09-10'");
        foreach (var row in results[0].GetProperty("dataset").EnumerateArray())
            Console.WriteLine($"{row[0].GetString()} {row[1].GetDouble()}");
    }
}
```

## Access token

A second server on another port, with a token. Every `kdb serve` also opens the PostgreSQL port 8832 (chapter 14), and only one server can have it, so a second server needs `--pg-port 0` (off) or another port:

```powershell
kdb serve tokendb --port 9944 --pg-port 0 --token change-me-please
```

Then:

```powershell
curl.exe -s http://127.0.0.1:9944/health
""
curl.exe -s -w "   (HTTP %{http_code})" "http://127.0.0.1:9944/exec?query=SELECT%201"
""
curl.exe -s -w "   (HTTP %{http_code})" -H "Authorization: Bearer wrong" "http://127.0.0.1:9944/exec?query=SELECT%201"
""
curl.exe -s -H "Authorization: Bearer change-me-please" "http://127.0.0.1:9944/exec?query=SELECT%201%20AS%20one&compat=0"
""
curl.exe -s --cookie "kdb_token=change-me-please" "http://127.0.0.1:9944/exp?query=SELECT%201%20AS%20one"
```

```text
{"status":"ok","version":"0.2.0-dev","server_time_ms":1789114675621,"auth_required":true,"login":false}
{"error":"access token required"}   (HTTP 401)
{"error":"wrong access token"}   (HTTP 401)
{"query":"SELECT 1 AS one","results":[{"statement":"SELECT 1 AS one","columns":[{"name":"one","type":"LONG"}],"dataset":[[1]],"count":1,"truncated":false,"rows_affected":0,"message":"","timings":{"parse_us":26,"execute_us":16}}],"timings":{"parse_us":26,"execute_us":16}}
one
1
```

- Send the token as `Authorization: Bearer <token>` (programs) or as the cookie `kdb_token=<token>` (the console does this).
- `/health` works without a token.
- The 401 answer has the header `WWW-Authenticate: Bearer realm="kdb"`.
- The token can do everything. For programs that should only read, or only write one database, use **users** instead.

## Stop a slow request

`kdb serve` stops every statement after `--statement-timeout` (60 s by default) with HTTP 408. Send your own shorter time, or give the request an id so that you can stop it:

| Header | Does |
|---|---|
| `X-KDB-Statement-Timeout: 5s` | a shorter time for this request (admins may also make it longer) |
| `X-KDB-Request-Id: report-17` | `DELETE /exec/report-17` stops it (your own requests; admins: all) |
| `X-KDB-Safe-Updates: on` | refuse `UPDATE` and `DELETE` without `WHERE` (`off` when the server has `--safe-updates`) |

```text
{"query":"SELECT ...","results":[],"error":"canceling statement due to user request"}   (HTTP 408)
```

Closing the connection also stops the statement. Nothing of a stopped change is saved. Chapter 21 has the details.

## Users and logins

When the data folder has users (`CREATE USER`, or `kdb user add`), every request needs a login. Chapter 16 explains users and roles; here is only the HTTP part.

| How | Send | For |
|---|---|---|
| HTTP Basic | `curl -u name:password ...` (header `Authorization: Basic ...`) | scripts; KDB remembers a good password for 10 minutes, so it is not slow |
| Log in once | `POST /api/login` with `{"user":"...","password":"..."}` (JSON or form; users with two-factor login add `"code":"123456"`, chapter 21). The answer has `token` and sets the cookie `kdb_login` (HttpOnly, SameSite=Strict, 12 hours). Then send `Authorization: Bearer <token>`. | apps, the web console |
| Log out | `POST /api/logout` with the cookie or the Bearer token | |
| The `--token` | `Authorization: Bearer <token>` | everything, as before |

| Answer | Means |
|---|---|
| 401 `{"error":"login required: ...","login":true}` | no login, or a wrong password. The header is `WWW-Authenticate: Basic realm="kdb"` (the console gets `Bearer`, so the browser shows no password box). |
| 403 `{"error":"INSERT needs role write on database 'shop'; user 'report' has read"}` | logged in, but the role is too weak |
| 429 `{"error":"too many failed logins; try again in 4 s"}` and `Retry-After` | 5 failed logins for one user from one address: wait 1 s, 2 s, 4 s, ... up to 15 minutes |

Rights per route: `read` for `/exec` and `/exp` with reading SQL, `/api/info`, `/api/backups` and cursors; `write` for changing SQL and `/write`; `admin` on the database for schema changes, `/api/check` and `/api/backup`; ROLE `admin` for `POST /api/databases`, `DELETE /api/databases/<name>` and user statements. `GET /api/databases` lists only the databases the user may read. A transaction session (`POST /session`) can only be used by the user who opened it.

## Safety rules of the API

The server refuses requests that a web page in your browser could send behind your back:

```powershell
curl.exe -s -w "   (HTTP %{http_code})" -H "Sec-Fetch-Site: cross-site" "http://127.0.0.1:9900/exec?query=SELECT%201"
""
curl.exe -s -w "   (HTTP %{http_code})" -H "Origin: http://example.com" "http://127.0.0.1:9900/exec?query=SELECT%201"
""
curl.exe -s -w "   (HTTP %{http_code})" -H "Host: market.example.com" "http://127.0.0.1:9900/exec?query=SELECT%201"
```

```text
{"error":"cross-site requests are not allowed"}   (HTTP 403)
{"error":"cross-origin requests are not allowed"}   (HTTP 403)
{"error":"host name 'market.example.com' is not allowed without an access token; use localhost or start the server with --token"}   (HTTP 403)
```

| Rule | Why |
|---|---|
| GET /exec and /exp only read | Links and images can send GET requests |
| Browser requests from other sites get 403 | A bad web page must not use your local KDB |
| Without a token, the `Host` must be `localhost` or `127.x.x.x` | Stops DNS rebinding. A reverse proxy needs `--token` or users. |
| `kdb serve --bind 0.0.0.0` without `--token` and without users does not start | Nobody can open all data to the network by mistake |
| Login cookies are `HttpOnly` and `SameSite=Strict`; `POST /api/login` from another site gets 403 | Scripts and other sites cannot steal or use a login |
| Failed logins are logged and slowed down | Guessing passwords does not work |
| The token is compared in constant time | Guessing it by timing does not work |

Programs like curl, Python, Go and Node do not send `Sec-Fetch-Site` or `Origin`, so they are not affected. JavaScript in a web page on **another** site cannot call KDB (there are no CORS headers). Call KDB from your backend (for example the 006 Go app), not from browser code.

## Limits

| Limit | Value |
|---|---|
| Rows per statement (`limit`) | default 10,000 for /exec, 1,000,000 for /exp; at most 1,000,000 |
| Request body | 64 MB |
| Request headers | 64 KB |
| Time to send a request | 30 seconds |
| Idle keep-alive connection | closed after 30 seconds |
| Worker threads | 8: at most 8 requests run at once, the next ones wait for a free worker |
| Open cursors (`/cursor`) | 16 per database; unused ones close after 10 minutes |
| Open sessions (`/session`) | 1,000; unused ones close after 10 minutes |
| Writers at the same time | one per table; writers of different tables run together |
| Readers at the same time | many; a read never waits for another read |
| Time of one statement | `--statement-timeout` (60 s) |
| Statements of one user at the same time | `--max-queries-per-user` (32) |

Reads see the last committed rows. They do not wait for an open transaction, only for a statement that is running right now (usually a millisecond; a long `CALL` or trigger can take longer, see `--reader-yield` in chapter 15). A writer waits only for another writer of the **same** table: at most 5 seconds, then HTTP 503 `table 'x' is busy` (chapter 15).

## Not available yet

| Feature | QuestDB has it | KDB |
|---|---|---|
| ILP over its own TCP port | yes (port 9009) | no. Send the same lines over HTTP: [POST /write](#post-write-line-protocol). |
| HTTPS | no (use a proxy) | no (use a proxy) |

The PostgreSQL protocol is there: port 8832, for `psql`, DBeaver, Go `pgx` and Python `psycopg` (chapter 14).

## Try it yourself

1. With curl, get the newest live price of TELCO as JSON, without the QuestDB copy.
2. Download all COAST daily candles as `coast.csv`.
3. In Python, insert a stock index snapshot row and read it back. (Create the table first with POST.)

<details>
<summary>Answers</summary>

1. ```powershell
   curl.exe -s -G http://127.0.0.1:9900/exec --data-urlencode "query=SELECT symbol, ltp, timestamp FROM live_data WHERE symbol = 'TELCO' LATEST ON timestamp PARTITION BY symbol" --data-urlencode "compat=0"
   ```
2. ```powershell
   curl.exe -s -G http://127.0.0.1:9900/exp --data-urlencode "query=SELECT * FROM ochl_day WHERE symbol = 'COAST' ORDER BY time" -o coast.csv
   ```
3. With `kdb()` from `client.py`:
   ```python
   kdb("CREATE TABLE IF NOT EXISTS index_live (time TIMESTAMP, name SYMBOL, value DOUBLE) "
       "TIMESERIES(time) PARTITION BY DAY DEDUP KEY (name, time)")
   kdb("INSERT OR REPLACE INTO index_live VALUES ('2026-09-10T15:00:00+05:45', 'MARKET', 2650.5)")
   print(kdb("SELECT * FROM index_live")[0]["dataset"])
   ```
   It prints `[['2026-09-10T09:15:00.000Z', 'MARKET', 2650.5]]`.

</details>

---

Next: [9. Backup and safety](09-backup-and-safety.md)
