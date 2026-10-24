# CSV import over HTTP (POST /imp)

> Send a CSV file to kareladb serve and it loads the rows, making the table from the file when it is new - QuestDB's /imp.

- Category: HTTP API
- Keywords: /imp, imp, CSV import, timings, Server-Timing, parse\_ms, lock\_wait\_ms, wal\_ms, apply\_ms, durable\_ms, durable, queued, gzip upload, import CSV, upload CSV, load a file, QuestDB import, multipart, form-data, overwrite, atomicity, skipCol, skipRow, abort, forceHeader, partitionBy, delimiter, fmt, rowsImported, rowsRejected, schema
- See also: [Line protocol (POST /write)](line-protocol.md), [Loading many rows](loading-data.md), [Run SQL over HTTP (/exec, /exp)](http-exec.md), [HTTP API overview](http-overview.md), [CREATE TABLE](create-table.md), [Partitions, SORT BY and DEDUP KEY](partitions-and-dedup.md)

`POST /imp` loads a **CSV file** into a table. It is QuestDB's import route, so a QuestDB script or the QuestDB web console can send here without changes.

- A table that is **not there yet** is made from the file: the column names come from the first line, the types from the values.
- A table that **is** there gets the rows added (upserted, like the [line protocol](line-protocol.md#post-write)).
- Everything is written in **one transaction**: after a good answer all rows are in, after an error nothing changed.

For SQL, use [POST /exec](http-exec.md#post-exec). For a fast live feed, use the [line protocol](line-protocol.md). More ways to load data: [loading data](loading-data.md).

## POST /imp

Syntax:

```sql
POST /imp?name=<table>[&db=<name>]
         [&overwrite=true][&atomicity=skipCol|skipRow|abort]
         [&timestamp=<column>&partitionBy=DAY|MONTH|YEAR|NONE]
         [&delimiter=,][&forceHeader=true][&fmt=json]
body: the CSV itself, or multipart/form-data with a file part named "data"
```

Reads the CSV, makes the table when it is new, and writes the rows.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `name` | URL | The table to load into. Without it, the file name of the upload (without `.csv`) is used. | required |
| `db` | URL | The database (or the header `X-KDB-Database`). Without it: the one database that already has the table ([which database](#which-database)). | see the left |
| `overwrite` | URL | `true`: drop the table first and make it again from the file. | `false` |
| `atomicity` | URL | What a value that does not fit its column does: `skipCol` the value becomes `NULL`, `skipRow` the whole row is left out, `abort` nothing at all is written. | `skipCol` |
| `dedup` | URL | `skip`: no duplicate lookups in days that already hold rows. **A key already stored may then be there twice**; the answer has `dedupSkipped` ([dedup=skip](partitions-and-dedup.md#dedup-skip)). | `on` |
| `timestamp` | URL | Which column is the time column of a **new** table (`TIMESERIES(...)`). | none |
| `partitionBy` | URL | `NONE`, `DAY`, `MONTH` or `YEAR` for a **new** table. Anything but `NONE` needs `timestamp=`. | `NONE` |
| `delimiter` | URL | The character between the values; `\t` or `tab` for a tab. Without it KarelaDB guesses from the first lines. | guessed |
| `forceHeader` | URL | `true`: the first line is column names. Without it KarelaDB decides: names that match the table, or a first line with nothing that looks like data. | guessed |
| `fmt` | URL | `json`: answer as JSON. Anything else: a short text answer. | text |
| `schema` | form part | JSON that sets column types: `[{"name": "close", "type": "DOUBLE"}]`. | types guessed |

| Answer (with `fmt=json`) | Meaning |
|---|---|
| `status` | `"OK"`, or the error message |
| `database` | the database the rows went into |
| `location` | the table the rows went into |
| `rowsImported` | how many rows were written |
| `rowsRejected` | how many rows were left out (`atomicity=skipRow`) |
| `header` | whether the first line was read as column names |
| `partitionBy`, `timestamp` | the table's partitioning and time column |
| `columns` | one entry per column: `name`, `type`, `size` in bytes, `errors` (values that did not fit) |
| `timings` | where the time of the request went, in milliseconds ([timings](#timings)) |

- **Status codes:** 200 loaded (read `rowsRejected`: a 200 can still have left rows out); 400 a bad CSV, a bad parameter, an unknown column, `atomicity=abort` with a bad value, or no `db` when the database cannot be worked out; 401/403 login or role (403 also when a [table right](table-rights.md) does not allow inserts into this table); 404 unknown database; 405 for a `GET`; 408 a trigger ran past the statement timeout; 413 body over 64 MB (counted after unpacking); 500 server trouble (nothing written); 503 while the server is stopping; 507 the disk is full: free space, then send the same file again, unless the message says `do not send it again` (the disk filled while the log was flushed: the rows are already in the table and are saved once space is back, see [backup and safety](backup-and-safety.md)).
- **Roles:** loading into a table that is there needs the **write** role. Making a table (a new name, or `overwrite=true`) needs **admin**.
- **Types of a new table:** `BOOLEAN`, `LONG`, `DOUBLE`, `DATE`, `TIMESTAMP`, else `STRING`. Send `schema` (or make the table yourself with [CREATE TABLE](create-table.md)) when you want `SYMBOL`, `DECIMAL(2)` or a `PRIMARY KEY`.
- **Notes:**
  - Rows are **upserted**: a row with the same `PRIMARY KEY` or `DEDUP KEY` replaces the old one, so sending the same file twice makes no duplicates.
  - The first 5000 lines are read first, to find the header and the types. A column whose later values do not fit follows `atomicity`.
  - The body may be compressed with `Content-Encoding: gzip` or `deflate`. The 64 MB limit counts the unpacked CSV. A damaged body gives 400 and imports nothing. With curl: `gzip -c prices.csv | curl --data-binary @- -H "Content-Encoding: gzip" "http://127.0.0.1:9900/imp?name=prices"`.
  - [Triggers](triggers.md) run once for the whole request, like the line protocol. Their time counts toward the [statement timeout](protection.md#statement-timeout); send `X-KDB-Statement-Timeout` for a longer one (admins only). A trigger that runs too long gives status 408 and `trigger <name>: statement timeout (<N> s) (nothing was imported)`.

<a id="timings"></a>

### When the OK comes, and where the time went

An OK from `/imp` (200) or [`/write`](line-protocol.md#post-write) (204) means the rows are **written and safe on disk**. Nothing is queued for later: the answer waits for the log's disk sync. A server crash right after the OK loses none of these rows.

Each answer says where its time went. `/imp` with `fmt=json` has a `timings` object; `/write` answers 204 with no body, so it sends the same numbers in the standard `Server-Timing` header (browser developer tools show it). All are milliseconds with 3 decimals.

| Field | `Server-Timing` | What the time was spent on |
|---|---|---|
| `parse_ms` | `parse` | reading the body (after unpacking gzip) and building the rows, before any lock |
| `lock_wait_ms` | `lock` | waiting behind other writes of the same tables, or for a transaction that holds one |
| `wal_ms` | `wal` | writing the log and waiting for its disk sync. Writers that arrive together share one sync |
| `apply_ms` | `apply` | checking the rows (keys, rules) and putting them in the table |
| `trigger_ms` | `trigger` | [triggers](triggers.md) the rows fired inside the request |
| `durable_ms` | | from the start until the rows were on disk: the moment the OK can go out |
| `total_ms` | `total` | the whole request |

The five steps add up to `total_ms`. A slow load then shows at a glance what to fix:

- a large `lock_wait_ms`: other writers or a long transaction hold the table. Send fewer, bigger requests, or write to separate tables.
- a large `wal_ms`: the disk is slow to sync. Bigger requests share one sync between more rows.
- a large `parse_ms`: the body is big. Several senders at once parse in parallel.

The activity log (`GET /api/activity`) keeps the same numbers for each write event, and `GET /api/stats` adds them up since the start under `writes` (`line_protocol` and `csv_import`: `requests`, `rows` and the sum of each step; a step's average is its sum divided by `requests`). `bench/parallel-write.mjs` sends from 1, 2, 4 and 8 senders at once and prints rows per second with the average of each step.

<a id="which-database"></a>

### Which database, without db=

A QuestDB client has no `db=` to send, so `/imp` works out the database from the table name:

| The server has | Without `db=` the rows go to |
|---|---|
| one database | that database |
| several, and one of them has the table | that database (the default one wins when it is among several that have it) |
| several, and more than one has the table (not the default) | nothing: 400, add `db=` |
| several, and none has the table | nothing: 400, add `db=` or create the table first |

KarelaDB refuses rather than guessing, so a load meant for another database never makes a new table with guessed types in the default one. The answer's `database` says where the rows went.

**HTTP: A new table straight from a CSV of daily closes**

```http
POST /imp?name=day_closes&timestamp=time&partitionBy=YEAR&fmt=json
Content-Type: text/csv

time,symbol,close
2026-09-09T00:00:00Z,CITY,502.10
2026-09-09T00:00:00Z,COAST,374.80
2026-09-10T00:00:00Z,CITY,504.90
2026-09-10T00:00:00Z,COAST,376.10
###
GET /exec?compat=0&query=SELECT * FROM day_closes ORDER BY time, symbol
```

Response:

`POST /imp?name=day_closes&timestamp=time&partitionBy=YEAR&fmt=json`

HTTP 200 (application/json)

```text
{
  "status": "OK",
  "database": "demo",
  "location": "day_closes",
  "rowsRejected": 0,
  "rowsImported": 4,
  "header": true,
  "partitionBy": "YEAR",
  "timestamp": "time",
  "columns": [
    {"name": "time", "type": "TIMESTAMP", "size": 8, "errors": 0},
    {"name": "symbol", "type": "STRING", "size": 0, "errors": 0},
    {"name": "close", "type": "DOUBLE", "size": 8, "errors": 0}
  ],
  "timings": {
    "parse_ms": 5.491,
    "lock_wait_ms": 0.012,
    "wal_ms": 0.478,
    "apply_ms": 1.417,
    "trigger_ms": 0,
    "durable_ms": 7.398,
    "total_ms": 7.398
  }
}
```

`GET /exec?compat=0&query=SELECT * FROM day_closes ORDER BY time, symbol`

HTTP 200 (application/json)

```text
{
  "query": "SELECT * FROM day_closes ORDER BY time, symbol",
  "results": [
    {
      "statement": "SELECT * FROM day_closes ORDER BY time, symbol",
      "columns": [
        {"name": "time", "type": "TIMESTAMP"},
        {"name": "symbol", "type": "STRING"},
        {"name": "close", "type": "DOUBLE"}
      ],
      "dataset": [
        ["2026-09-09T00:00:00.000Z", "CITY", 502.1],
        ["2026-09-09T00:00:00.000Z", "COAST", 374.8],
        ["2026-09-10T00:00:00.000Z", "CITY", 504.9],
        ["2026-09-10T00:00:00.000Z", "COAST", 376.1]
      ],
      "count": 4,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 19, "execute_us": 77}
    }
  ],
  "timings": {"parse_us": 19, "execute_us": 77}
}
```

**HTTP: Add rows to a table that already exists** (sample data: sample)

```http
POST /imp?name=securities&fmt=json

symbol,name,sector
SUMMIT,Summit Bank Limited,Banking
###
GET /exec?compat=0&query=SELECT symbol, name FROM securities ORDER BY symbol
```

Response:

`POST /imp?name=securities&fmt=json`

HTTP 200 (application/json)

```text
{
  "status": "OK",
  "database": "demo",
  "location": "securities",
  "rowsRejected": 0,
  "rowsImported": 1,
  "header": true,
  "partitionBy": "NONE",
  "columns": [
    {"name": "symbol", "type": "SYMBOL", "size": 0, "errors": 0},
    {"name": "name", "type": "STRING", "size": 0, "errors": 0},
    {"name": "sector", "type": "STRING", "size": 0, "errors": 0}
  ],
  "timings": {
    "parse_ms": 0.112,
    "lock_wait_ms": 0.01,
    "wal_ms": 1.612,
    "apply_ms": 0.982,
    "trigger_ms": 0,
    "durable_ms": 2.716,
    "total_ms": 2.716
  }
}
```

`GET /exec?compat=0&query=SELECT symbol, name FROM securities ORDER BY symbol`

HTTP 200 (application/json)

```text
{
  "query": "SELECT symbol, name FROM securities ORDER BY symbol",
  "results": [
    {
      "statement": "SELECT symbol, name FROM securities ORDER BY symbol",
      "columns": [
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "name", "type": "STRING"}
      ],
      "dataset": [
        ["ACME", "Acme Investment Company"],
        ["CITY", "City Bank Limited"],
        ["COAST", "Coastal Bank Limited"],
        ["SUMMIT", "Summit Bank Limited"],
        ["TELCO", "Northwind Telecom Limited"],
        ["VOLT", "Volt River Hydropower Limited"]
      ],
      "count": 6,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 20, "execute_us": 233}
    }
  ],
  "timings": {"parse_us": 20, "execute_us": 233}
}
```

**HTTP: The short text answer (no fmt=json)**

```http
POST /imp?name=broker_list

id,name
58,Northgate Securities
45,Sani Securities
```

Response:

HTTP 200 (text/plain)

```text
Database: demo
Location: broker_list
Rows handled: 2
Rows imported: 2
0 | id | LONG | 0 errors
1 | name | STRING | 0 errors
```

**HTTP: A bad value: skipCol (the default) makes it NULL and keeps the row**

Setup:

```text
CREATE TABLE day_closes2 (symbol SYMBOL PRIMARY KEY, close DOUBLE);
```

```http
POST /imp?name=day_closes2&fmt=json

symbol,close
CITY,504.90
COAST,not a number
###
GET /exec?compat=0&query=SELECT * FROM day_closes2 ORDER BY symbol
```

Response:

`POST /imp?name=day_closes2&fmt=json`

HTTP 200 (application/json)

```text
{
  "status": "OK",
  "database": "demo",
  "location": "day_closes2",
  "rowsRejected": 0,
  "rowsImported": 2,
  "header": true,
  "partitionBy": "NONE",
  "columns": [
    {"name": "symbol", "type": "SYMBOL", "size": 0, "errors": 0},
    {"name": "close", "type": "DOUBLE", "size": 8, "errors": 1}
  ],
  "timings": {
    "parse_ms": 0.05,
    "lock_wait_ms": 0.01,
    "wal_ms": 0.453,
    "apply_ms": 1.516,
    "trigger_ms": 0,
    "durable_ms": 2.029,
    "total_ms": 2.029
  }
}
```

`GET /exec?compat=0&query=SELECT * FROM day_closes2 ORDER BY symbol`

HTTP 200 (application/json)

```text
{
  "query": "SELECT * FROM day_closes2 ORDER BY symbol",
  "results": [
    {
      "statement": "SELECT * FROM day_closes2 ORDER BY symbol",
      "columns": [
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "close", "type": "DOUBLE"}
      ],
      "dataset": [
        ["CITY", 504.9],
        ["COAST", null]
      ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 15, "execute_us": 80}
    }
  ],
  "timings": {"parse_us": 15, "execute_us": 80}
}
```

**HTTP: skipRow leaves the bad row out**

Setup:

```text
CREATE TABLE day_closes3 (symbol SYMBOL PRIMARY KEY, close DOUBLE);
```

```http
POST /imp?name=day_closes3&atomicity=skipRow&fmt=json

symbol,close
CITY,504.90
COAST,not a number
###
GET /exec?compat=0&query=SELECT * FROM day_closes3 ORDER BY symbol
```

Response:

`POST /imp?name=day_closes3&atomicity=skipRow&fmt=json`

HTTP 200 (application/json)

```text
{
  "status": "OK",
  "database": "demo",
  "location": "day_closes3",
  "rowsRejected": 1,
  "rowsImported": 1,
  "header": true,
  "partitionBy": "NONE",
  "columns": [
    {"name": "symbol", "type": "SYMBOL", "size": 0, "errors": 0},
    {"name": "close", "type": "DOUBLE", "size": 8, "errors": 1}
  ],
  "timings": {
    "parse_ms": 0.036,
    "lock_wait_ms": 0.006,
    "wal_ms": 0.415,
    "apply_ms": 1.828,
    "trigger_ms": 0,
    "durable_ms": 2.285,
    "total_ms": 2.285
  }
}
```

`GET /exec?compat=0&query=SELECT * FROM day_closes3 ORDER BY symbol`

HTTP 200 (application/json)

```text
{
  "query": "SELECT * FROM day_closes3 ORDER BY symbol",
  "results": [
    {
      "statement": "SELECT * FROM day_closes3 ORDER BY symbol",
      "columns": [
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "close", "type": "DOUBLE"}
      ],
      "dataset": [
        ["CITY", 504.9]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 13, "execute_us": 73}
    }
  ],
  "timings": {"parse_us": 13, "execute_us": 73}
}
```

**HTTP: atomicity=abort: one bad value and nothing is written**

Setup:

```text
CREATE TABLE day_closes4 (symbol SYMBOL PRIMARY KEY, close DOUBLE);
```

```http
POST /imp?name=day_closes4&atomicity=abort&fmt=json

symbol,close
CITY,504.90
COAST,not a number
```

Response:

HTTP 400 (application/json)

```text
{
  "status": "line 3: column 'close': 'not a number' is not a number (atomicity=abort: nothing was imported)"
}
```

**HTTP: A tab-separated file** (sample data: sample)

```http
POST /imp?name=broker_notes&delimiter=tab&fmt=json

id	note
58	top buyer of the day
45	sold CITY
```

Response:

HTTP 200 (application/json)

```text
{
  "status": "OK",
  "database": "demo",
  "location": "broker_notes",
  "rowsRejected": 0,
  "rowsImported": 2,
  "header": true,
  "partitionBy": "NONE",
  "columns": [
    {"name": "id", "type": "LONG", "size": 8, "errors": 0},
    {"name": "note", "type": "STRING", "size": 0, "errors": 0}
  ],
  "timings": {
    "parse_ms": 5.437,
    "lock_wait_ms": 0.014,
    "wal_ms": 0.367,
    "apply_ms": 0.908,
    "trigger_ms": 0,
    "durable_ms": 6.726,
    "total_ms": 6.726
  }
}
```

**HTTP: The table must be named**

```http
POST /imp

symbol,close
CITY,504.90
```

Response:

HTTP 400 (text/plain)

```text
name the table: POST /imp?name=table (or send a file with a name)
```

**HTTP: Importing needs POST**

```http
GET /imp?name=day_closes
```

Response:

HTTP 405 (application/json)

```text
{"error": "method GET is not allowed here"}
```

Clients (not run by the help build):

```powershell
# QuestDB's own way: a multipart upload with a file part named "data".
curl.exe -s -F "data=@day_closes.csv" `
  "http://127.0.0.1:9900/imp?name=day_closes&timestamp=time&partitionBy=YEAR&fmt=json&db=market"
```

```python
import requests

with open("day_closes.csv", "rb") as f:
    r = requests.post("http://127.0.0.1:9900/imp",
                      params={"name": "day_closes", "timestamp": "time",
                              "partitionBy": "YEAR", "fmt": "json", "db": "market"},
                      files={"data": ("day_closes.csv", f, "text/csv")})
answer = r.json()
if answer["status"] != "OK":
    raise RuntimeError(answer["status"])
print(answer["rowsImported"], "rows in", answer["location"])
```
