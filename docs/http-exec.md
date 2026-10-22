# Run SQL over HTTP (/exec, /exp)

> Run SQL with GET or POST /exec and get JSON, or download the rows of a SELECT as CSV with /exp.

- Category: HTTP API
- Keywords: exec, /exec, exp, /exp, query, limit, compat, compat, cache, result cache, benchmark, SET result\_cache, cache\_now\_ms, result\_cache\_now\_ms, truncated, dataset, columns, count, timings, rows\_affected, QuestDB, CSV export, download CSV, filename, Content-Disposition, form field, many statements, results array, error line column, --data-binary, --data-urlencode, NaN, nan, Infinity, timestamp as text, epoch milliseconds, statement failed, partial success, atomic, atomic, X-KDB-Atomic, all or nothing, rolled\_back, saved, sqlstate, constraint, error code
- See also: [HTTP API overview](http-overview.md), [Sessions and cursors over HTTP](http-sessions-and-cursors.md), [Databases over HTTP (/api/databases)](http-databases.md), [SELECT](select.md), [Transactions](transactions.md), [How KarelaDB stores data](data-formats.md)

`/exec` runs SQL and answers with **JSON**. `/exp` runs a SELECT and answers with a **CSV file** (text with one row per line and commas between the values, which Excel opens).

- `GET` only runs SQL that reads. `POST` runs any SQL.
- Each request uses one database: `db=<name>` or the header `X-KDB-Database` ([choosing the database](http-overview.md#database)).
- The answer looks like QuestDB's `/exec`, so QuestDB clients keep working ([moving from QuestDB](../tutorial/10-migrating-from-questdb.md)).

**HTTP: Close prices of CITY** (sample data: sample)

```http
GET /exec?compat=0&query=SELECT time, close FROM ochl_day WHERE symbol = 'CITY' ORDER BY time LIMIT 3
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "SELECT time, close FROM ochl_day WHERE symbol = 'CITY' ORDER BY time LIMIT 3",
  "results": [
    {
      "statement": "SELECT time, close FROM ochl_day WHERE symbol = 'CITY' ORDER BY time LIMIT 3",
      "columns": [
        {"name": "time", "type": "TIMESTAMP"},
        {"name": "close", "type": "DOUBLE"}
      ],
      "dataset": [
        ["2025-12-28T00:00:00.000Z", 542.2],
        ["2025-12-29T00:00:00.000Z", 539.7],
        ["2025-12-30T00:00:00.000Z", 539.3]
      ],
      "count": 3,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 32, "execute_us": 279}
    }
  ],
  "timings": {"parse_us": 32, "execute_us": 279}
}
```

## GET /exec

Syntax:

```sql
GET /exec?query=<SQL>[&db=<name>][&limit=N][&compat=0][&cache=0][&format=rows|columns][&nan=null|string][&session=<id>]
```

Runs SQL that only **reads** (`SELECT`, `SHOW ...`, `EXPLAIN`, `CHECK TABLE`, `USE`) and answers with JSON. SQL that changes data gets **405**: use [POST /exec](http-exec.md#post-exec).

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `query` | URL | The SQL. One or more statements, split by `;`. Encode spaces and `'` in the URL (`curl -G --data-urlencode` does it). | required |
| `db` | URL | The database. The header `X-KDB-Database: <name>` does the same. | the default database |
| `limit` | URL | Most rows each statement gives back. `0` or less means 1,000,000. QuestDB style `limit=10,500` uses the second number. | 10,000 |
| `compat` | URL | `compat=0` (or `false`) leaves out the copy of the last result at the top level. | `1` |
| `cache` | URL | `cache=0` (or `off`, `false`) runs a SELECT fresh: it is not taken from the [result cache](performance-tips.md#result-cache) and not kept there. Use it to time the engine in a benchmark. For a whole session: `SET result_cache = off`. A SELECT that must always be ready can be [pinned](pinned-queries.md). | `1` |
| `cache_now_ms` | URL | A SELECT with `now()` (or `current_date`) may be answered by a kept result up to this old, like `500` or `2s`. Without it such a SELECT is never kept. For a whole session: `SET result_cache_now_ms = 500`. | `0` |
| `format` | URL | `columns`: every `dataset` as one array per column ([format=columns](#format)) | `rows` |
| `nan` | URL | `string`: NaN, Infinity and -Infinity as the JSON strings `"NaN"`, `"Infinity"`, `"-Infinity"` instead of `null` ([nan=string](#nan)) | `null` |
| `session` | URL | A session id from [POST /session](http-sessions-and-cursors.md#post-session). The header `X-KDB-Session: <id>` does the same. | none |
| `If-None-Match` | header | The `ETag` of an earlier answer: a **304** with no body while the rows are the same ([ETag](#etag)) | none |

| Answer field | Meaning |
|---|---|
| `query` | The SQL you sent (only the first 4,096 bytes of a very long text) |
| `results[]` | One object for each statement, in order |
| `results[].statement` | The statement, as KarelaDB wrote it back |
| `results[].columns[]` | `name` and `type` of each column (`LONG`, `DOUBLE`, `TIMESTAMP`, ...) |
| `results[].dataset` | The rows. Each row is a list of values in column order. |
| `results[].count` | Number of rows in `dataset` |
| `results[].truncated` | `true` when there were more rows than `limit` |
| `results[].rows_affected` | Rows changed by `INSERT`, `UPDATE` or `DELETE` |
| `results[].message` | A short message, like `1 row(s) inserted` |
| `results[].timings` | `parse_us` and `execute_us`: microseconds (millionths of a second) to read and to run the statement |
| `columns`, `dataset`, `count` | A copy of the **last** result at the top level, as QuestDB answers. Not there with `compat=0`. |
| `timings` | The sum of the timings of all statements |

How values look in `dataset`:

| KarelaDB type | JSON value |
|---|---|
| `INT`, `LONG`, `DOUBLE`, ... | a number: `512.4` |
| a whole number bigger than 9,007,199,254,740,992 (2^53) | text: `"9007199254740993"`, so JavaScript does not lose digits |
| `DECIMAL(s)` | text with exactly `s` places: `"1500.25"` (it stays exact) |
| `TIMESTAMP` | UTC text: `"2026-09-10T05:15:00.000Z"` |
| `DATE` | text: `"2026-09-10"` |
| `BOOL` | `true` or `false` |
| `SYMBOL`, `STRING` | text |
| `JSON` | the JSON itself (an object or a list), not a text |
| NULL, and a number that is not real (like `sqrt(-1)`) | `null` |
| a `DOUBLE` that is NaN, Infinity or -Infinity | `null`, as QuestDB writes it; `"NaN"`, `"Infinity"`, `"-Infinity"` with [nan=string](#nan) |

- **Times are text, not numbers:** every `TIMESTAMP`, also `min(time)` and `max(time)`, comes as text like `"2026-09-10T05:15:00.000Z"`. In JavaScript `Number(value)` gives `NaN`; use `Date.parse(value)` (milliseconds). Or ask SQL for a number: `CAST(time AS LONG)` gives milliseconds since 1970-01-01 UTC, `date_part('epoch', time)` gives seconds.
- **Status codes:** 200 OK; 304 the `If-None-Match` tag still fits; 400 bad SQL, no `query`, or a `format` that is not `rows` or `columns`; 401/403 [login or role](http-login.md); 404 unknown database or session; 405 SQL that changes data; 408 the statement ran past the statement timeout; 500 server trouble (damaged file); 503 the database is busy with another transaction, or the server is stopping.
- **Notes:** GET must only read because a link or picture on another web page can make your browser send a GET. `limit` cuts each statement's rows, so `"truncated": true` tells you more rows exist: use a bigger `limit`, [GET /exp](http-exec.md#get-exp) or a [cursor](http-sessions-and-cursors.md#post-cursor).
- **10,000 rows:** without `limit`, `/exec` gives back at most 10,000 rows per statement, so a forgotten `WHERE` cannot send millions of rows to a browser. Ask for more with `limit=` (up to 1,000,000).

**HTTP: The QuestDB shape: the last result also at the top level** (sample data: sample)

```http
GET /exec?query=SELECT symbol, sector FROM securities ORDER BY symbol LIMIT 2
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "SELECT symbol, sector FROM securities ORDER BY symbol LIMIT 2",
  "results": [
    {
      "statement": "SELECT symbol, sector FROM securities ORDER BY symbol LIMIT 2",
      "columns": [
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "sector", "type": "STRING"}
      ],
      "dataset": [
        ["ACME", "Investment"],
        ["CITY", "Banking"]
      ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 23, "execute_us": 157}
    }
  ],
  "columns": [
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "sector", "type": "STRING"}
  ],
  "dataset": [
    ["ACME", "Investment"],
    ["CITY", "Banking"]
  ],
  "count": 2,
  "timings": {"parse_us": 23, "execute_us": 157}
}
```

**HTTP: limit=2 and truncated** (sample data: sample)

```http
GET /exec?compat=0&limit=2&query=SELECT time, close FROM ochl_minutes WHERE symbol = 'CITY' ORDER BY time
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "SELECT time, close FROM ochl_minutes WHERE symbol = 'CITY' ORDER BY time",
  "results": [
    {
      "statement": "SELECT time, close FROM ochl_minutes WHERE symbol = 'CITY' ORDER BY time",
      "columns": [
        {"name": "time", "type": "TIMESTAMP"},
        {"name": "close", "type": "DOUBLE"}
      ],
      "dataset": [
        ["2026-09-09T05:15:00.000Z", 512.1],
        ["2026-09-09T05:16:00.000Z", 511.9]
      ],
      "count": 2,
      "truncated": true,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 26, "execute_us": 245}
    }
  ],
  "timings": {"parse_us": 26, "execute_us": 245}
}
```

**HTTP: cache=0: computed now, not taken from the result cache** (sample data: sample)

```http
GET /exec?compat=0&cache=0&query=SELECT symbol, count(*) FROM ochl_day GROUP BY symbol ORDER BY symbol LIMIT 3
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "SELECT symbol, count(*) FROM ochl_day GROUP BY symbol ORDER BY symbol LIMIT 3",
  "results": [
    {
      "statement": "SELECT symbol, count(*) FROM ochl_day GROUP BY symbol ORDER BY symbol LIMIT 3",
      "columns": [
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "count(*)", "type": "LONG"}
      ],
      "dataset": [
        ["CITY", 19],
        ["COAST", 19],
        ["VOLT", 19]
      ],
      "count": 3,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 20, "execute_us": 423}
    }
  ],
  "timings": {"parse_us": 20, "execute_us": 423}
}
```

**HTTP: How each type looks in JSON**

```http
GET /exec?compat=0&query=SELECT CAST('2026-09-10T05:15:00Z' AS TIMESTAMP) AS ts, CAST('2026-09-10' AS DATE) AS day, CAST(1500.25 AS DECIMAL(2)) AS price, 9007199254740993 AS big, true AS ok, NULL AS nothing, 'नेपाल' AS text, sqrt(-1) AS not_real
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "SELECT CAST('2026-09-10T05:15:00Z' AS TIMESTAMP) AS ts, CAST('2026-09-10' AS DATE) AS day, CAST(1500.25 AS DECIMAL(2)) AS price, 9007199254740993 AS big, true AS ok, NULL AS nothing, 'नेपाल' AS text, sqrt(-1) AS not_real",
  "results": [
    {
      "statement": "SELECT CAST('2026-09-10T05:15:00Z' AS TIMESTAMP) AS ts, CAST('2026-09-10' AS DATE) AS day, CAST(1500.25 AS DECIMAL(2)) AS price, 9007199254740993 AS big, TRUE AS ok, NULL AS nothing, 'नेपाल' AS text, sqrt(-1) AS not_real",
      "columns": [
        {"name": "ts", "type": "TIMESTAMP"},
        {"name": "day", "type": "DATE"},
        {"name": "price", "type": "DECIMAL(2)"},
        {"name": "big", "type": "LONG"},
        {"name": "ok", "type": "BOOL"},
        {"name": "nothing", "type": "STRING"},
        {"name": "text", "type": "STRING"},
        {"name": "not_real", "type": "STRING"}
      ],
      "dataset": [
        ["2026-09-10T05:15:00.000Z", "2026-09-10", "1500.25", "9007199254740993", true, null, "नेपाल", null]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 49, "execute_us": 98}
    }
  ],
  "timings": {"parse_us": 49, "execute_us": 98}
}
```

**HTTP: The first time as text and as numbers** (sample data: sample)

```http
GET /exec?compat=0&query=SELECT min(time) AS first, CAST(min(time) AS LONG) AS first_ms, date_part('epoch', min(time)) AS first_seconds FROM ochl_day WHERE symbol = 'CITY'
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "SELECT min(time) AS first, CAST(min(time) AS LONG) AS first_ms, date_part('epoch', min(time)) AS first_seconds FROM ochl_day WHERE symbol = 'CITY'",
  "results": [
    {
      "statement": "SELECT min(time) AS first, CAST(min(time) AS LONG) AS first_ms, date_part('epoch', min(time)) AS first_seconds FROM ochl_day WHERE symbol = 'CITY'",
      "columns": [
        {"name": "first", "type": "TIMESTAMP"},
        {"name": "first_ms", "type": "LONG"},
        {"name": "first_seconds", "type": "DOUBLE"}
      ],
      "dataset": [
        ["2025-12-28T00:00:00.000Z", 1766880000000, 1766880000]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 145, "execute_us": 797}
    }
  ],
  "timings": {"parse_us": 145, "execute_us": 797}
}
```

**HTTP: SQL that changes data needs POST** (sample data: sample)

```http
GET /exec?query=UPDATE ochl_day SET close = 0 WHERE symbol = 'CITY'
```

Response:

HTTP 405 (application/json)

```text
{"error": "this SQL changes data, so it must be sent with POST /exec (GET /exec only reads)"}
```

**HTTP: No query**

```http
GET /exec
```

Response:

HTTP 400 (application/json)

```text
{"error": "missing query: use /exec?query=<SQL> or POST the SQL as the body"}
```

With `curl`, let it encode the SQL (`-G` puts the data into the URL):

```bash
curl -s -G "http://127.0.0.1:9900/exec" --data-urlencode "query=SELECT symbol, close FROM ochl_day WHERE symbol = 'CITY' LIMIT 2" --data-urlencode "compat=0"
```

```powershell
$q = [uri]::EscapeDataString("SELECT symbol, close FROM ochl_day WHERE symbol = 'CITY' LIMIT 2")
$r = Invoke-RestMethod "http://127.0.0.1:9900/exec?compat=0&query=$q"
$r.results[0].dataset | ForEach-Object { $_ -join " | " }
```

## POST /exec

Syntax:

```sql
POST /exec[?db=<name>][&limit=N][&compat=0][&cache=0][&format=rows|columns][&nan=null|string][&session=<id>][&atomic=1]
body: the SQL text
   or a form (Content-Type: application/x-www-form-urlencoded) with the field query=<SQL>
```

Runs **any** SQL: `INSERT`, `UPDATE`, `CREATE TABLE`, `CALL`, `BEGIN`, many statements at once. The answer has the same fields as [GET /exec](http-exec.md#get-exec).

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| body | body | The SQL. Send it as plain text (`Content-Type: text/plain; charset=utf-8`), in UTF-8. | required |
| `query` | form field | The SQL, when the body is a form. Without a `query=` field the whole body is the SQL. | - |
| `db` | URL or form field | The database. Or the header `X-KDB-Database`. | the default database |
| `limit` | URL or form field | Most rows per statement (as for GET) | 10,000 |
| `compat` | URL or form field | `compat=0` leaves out the top-level copy | `1` |
| `cache` | URL | `cache=0` skips the result cache (as for GET) | `1` |
| `format` | URL or form field | `columns`: one array per column (as for GET) | `rows` |
| `nan` | URL | `string`: NaN and the infinities as JSON strings (as for GET) | `null` |
| `session` | URL, form field or header `X-KDB-Session` | Run inside a [session](http-sessions-and-cursors.md#post-session): `BEGIN` in one request, `COMMIT` in a later one | none |
| `atomic` | URL, form field or header `X-KDB-Atomic` | `1`: the whole body is **one transaction**, all or nothing (see [atomic=1](#atomic)) | `0` |

| Answer field | Meaning |
|---|---|
| `query`, `results[]`, `columns`, `dataset`, `count`, `timings` | as in [GET /exec](http-exec.md#get-exec) |
| `error` | (only on an error) what went wrong |
| `sqlstate` | (only on an error) the same five-character code the [PostgreSQL port](postgres-protocol.md#errors) sends: `23505` duplicate key, `23503` foreign key, `42P01` unknown table, the code of a trigger's `RAISE ... USING ERRCODE`, ... |
| `table`, `constraint`, `column_name` | (only on a `23505` or `23503` error) the table and constraint it was about, like `users` and `users_email_key`, and the column when the constraint has one |
| `line`, `column` | (only on an error, when KarelaDB knows it) where in the text you sent. Counted in characters, from 1. |
| `saved` | (only on an error) how many entries of `results`, from the first, are **saved**. The same with or without `compat=0`. |
| `rolled_back` | (only on an error) `true` when a transaction was rolled back by the error: the entries after `saved` ran but are **not** saved |

- **Status codes:** 200 OK; 304 (as for GET); 400 bad SQL (syntax, unknown column, duplicate key, ...) or a damaged compressed body; 401/403 [login or role](http-login.md); 404 unknown database or session; 408 statement timeout; 413 body over 64 MB (counted after unpacking); 500 server trouble; 503 database busy, the server is stopping, or the system was short of memory for a moment ([send it again](backup-and-safety.md#out-of-memory); a 500 that says `applied in memory` must not be sent again); **507 the disk is full** (the write was not saved; it works again once space is freed).
- **Compressed body:** a body sent with `Content-Encoding: gzip` or `deflate` is unpacked before it is read. Handy for a long `INSERT` script.
- **Many statements:** they run one after the other. Each one is saved when it is done (unless you opened a transaction with `BEGIN`). When one statement fails:

| What | Value |
|---|---|
| HTTP status | **not 200**: 400 for bad SQL, a table that already exists, a duplicate key, ...; the other codes above for other trouble |
| `error` | at the top level of the answer: what went wrong (with `line` and `column` when KarelaDB knows them) |
| `results` | only the statements that ran **before** the failed one. The failed statement is **not** in `results`. |
| `saved` | how many of `results` are saved. Without `BEGIN` in the body: all of them. |
| `rolled_back` | `true` when the body had a `BEGIN` without `COMMIT` before the error (or `atomic=1`, or a session's open transaction): those statements were undone |
| statements after it | did **not** run |

- **Check the status code or `error` first.** A client that only reads `results` sees the statements that worked and can think a failed `CREATE TABLE` worked too.
- Read `saved`, not the length of `results`, to know what is really in the database.
- **A syntax error** in any statement is found **before** anything runs: status 400, `results` is empty, and nothing is saved, not even the statements before it.
- **Notes:** `curl --data` sends the body labelled as a form; that still works, because a form without a `query=` field is taken as the SQL. Use `--data-binary` so curl does not change line breaks. To send a `.sql` file with text in any language (Nepali, Chinese, ...), send the file's bytes. A body can be up to 64 MB (a big batch of INSERTs); for fast loading also see the [line protocol](line-protocol.md).

**HTTP: Two statements: an INSERT and a SELECT** (sample data: sample)

```http
POST /exec?compat=0
Content-Type: text/plain; charset=utf-8

INSERT INTO brokers VALUES (99, 'Himalayan Securities');
SELECT id, name FROM brokers WHERE id >= 58 ORDER BY id
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "INSERT INTO brokers VALUES (99, 'Himalayan Securities');\nSELECT id, name FROM brokers WHERE id >= 58 ORDER BY id",
  "results": [
    {
      "statement": "INSERT INTO brokers VALUES (99, 'Himalayan Securities')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 16, "execute_us": 502}
    },
    {
      "statement": "SELECT id, name FROM brokers WHERE id >= 58 ORDER BY id",
      "columns": [
        {"name": "id", "type": "INT"},
        {"name": "name", "type": "STRING"}
      ],
      "dataset": [
        [58, "Northgate Securities"],
        [99, "Himalayan Securities"]
      ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 16, "execute_us": 145}
    }
  ],
  "timings": {"parse_us": 32, "execute_us": 647}
}
```

**HTTP: The second INSERT fails: the first one ran and is kept** (sample data: sample; shows an error)

```http
POST /exec?compat=0

INSERT INTO brokers VALUES (98, 'Everest Capital');
INSERT INTO brokers VALUES (98, 'Everest Capital again');
SELECT count(*) FROM brokers
###
GET /exec?compat=0&query=SELECT id, name FROM brokers WHERE id = 98
```

Response:

`POST /exec?compat=0`

HTTP 400 (application/json)

```text
{
  "query": "INSERT INTO brokers VALUES (98, 'Everest Capital');\nINSERT INTO brokers VALUES (98, 'Everest Capital again');\nSELECT count(*) FROM brokers",
  "results": [
    {
      "statement": "INSERT INTO brokers VALUES (98, 'Everest Capital')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 8, "execute_us": 480}
    }
  ],
  "saved": 1,
  "rolled_back": false,
  "error": "a row with id='98' already exists in 'brokers'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it",
  "sqlstate": "23505",
  "table": "brokers",
  "constraint": "brokers_pkey",
  "column_name": "id"
}
```

`GET /exec?compat=0&query=SELECT id, name FROM brokers WHERE id = 98`

HTTP 200 (application/json)

```text
{
  "query": "SELECT id, name FROM brokers WHERE id = 98",
  "results": [
    {
      "statement": "SELECT id, name FROM brokers WHERE id = 98",
      "columns": [
        {"name": "id", "type": "INT"},
        {"name": "name", "type": "STRING"}
      ],
      "dataset": [
        [98, "Everest Capital"]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 10, "execute_us": 57}
    }
  ],
  "timings": {"parse_us": 10, "execute_us": 57}
}
```

**HTTP: A failed CREATE TABLE: status 400, the first two statements are kept, the last did not run**

```http
POST /exec?compat=0

CREATE TABLE notes (id LONG PRIMARY KEY, body STRING);
INSERT INTO notes VALUES (1, 'first');
CREATE TABLE notes (id LONG);
INSERT INTO notes VALUES (2, 'second')
```

Response:

HTTP 400 (application/json)

```text
{
  "query": "CREATE TABLE notes (id LONG PRIMARY KEY, body STRING);\nINSERT INTO notes VALUES (1, 'first');\nCREATE TABLE notes (id LONG);\nINSERT INTO notes VALUES (2, 'second')",
  "results": [
    {
      "statement": "CREATE TABLE notes (\n  id LONG PRIMARY KEY,\n  body STRING\n)",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "table 'notes' created",
      "timings": {"parse_us": 5, "execute_us": 12697}
    },
    {
      "statement": "INSERT INTO notes VALUES (1, 'first')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 5, "execute_us": 2053}
    }
  ],
  "saved": 2,
  "rolled_back": false,
  "error": "table 'notes' already exists; expected a new table name, or CREATE TABLE IF NOT EXISTS",
  "sqlstate": "42P07"
}
```

**HTTP: A syntax error in the second statement: nothing runs, not even the first** (sample data: sample; shows an error)

```http
POST /exec?compat=0

INSERT INTO brokers VALUES (97, 'Test Securities');
SELEC count(*) FROM brokers
###
GET /exec?compat=0&query=SELECT count(*) AS rows_with_id_97 FROM brokers WHERE id = 97
```

Response:

`POST /exec?compat=0`

HTTP 400 (application/json)

```text
{
  "query": "INSERT INTO brokers VALUES (97, 'Test Securities');\nSELEC count(*) FROM brokers",
  "results": [],
  "saved": 0,
  "rolled_back": false,
  "error": "line 2, column 1: expected a statement (CREATE, DROP, RENAME, ALTER, SHOW, INSERT, UPDATE, DELETE, BACKUP, CHECK, SELECT, EXPLAIN, CALL, BEGIN, COMMIT, ROLLBACK, SAVEPOINT, DECLARE, FETCH or CLOSE) but found 'SELEC'",
  "sqlstate": "42601",
  "line": 2,
  "column": 1
}
```

`GET /exec?compat=0&query=SELECT count(*) AS rows_with_id_97 FROM brokers WHERE id = 97`

HTTP 200 (application/json)

```text
{
  "query": "SELECT count(*) AS rows_with_id_97 FROM brokers WHERE id = 97",
  "results": [
    {
      "statement": "SELECT count(*) AS rows_with_id_97 FROM brokers WHERE id = 97",
      "columns": [
        {"name": "rows_with_id_97", "type": "LONG"}
      ],
      "dataset": [
        [0]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 16, "execute_us": 108}
    }
  ],
  "timings": {"parse_us": 16, "execute_us": 108}
}
```

**HTTP: BEGIN in the body: the error rolls back what came after it** (sample data: sample; shows an error)

```http
POST /exec?compat=0

INSERT INTO brokers VALUES (95, 'Peak Securities');
BEGIN;
INSERT INTO brokers VALUES (94, 'Valley Capital');
INSERT INTO brokers VALUES (94, 'Valley Capital again')
###
GET /exec?compat=0&query=SELECT id FROM brokers WHERE id IN (94, 95)
```

Response:

`POST /exec?compat=0`

HTTP 400 (application/json)

```text
{
  "query": "INSERT INTO brokers VALUES (95, 'Peak Securities');\nBEGIN;\nINSERT INTO brokers VALUES (94, 'Valley Capital');\nINSERT INTO brokers VALUES (94, 'Valley Capital again')",
  "results": [
    {
      "statement": "INSERT INTO brokers VALUES (95, 'Peak Securities')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 6, "execute_us": 514}
    },
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 6, "execute_us": 4}
    },
    {
      "statement": "INSERT INTO brokers VALUES (94, 'Valley Capital')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 6, "execute_us": 27}
    }
  ],
  "saved": 1,
  "rolled_back": true,
  "error": "a row with id='94' already exists in 'brokers'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it (the transaction was rolled back)",
  "sqlstate": "23505",
  "table": "brokers",
  "constraint": "brokers_pkey",
  "column_name": "id"
}
```

`GET /exec?compat=0&query=SELECT id FROM brokers WHERE id IN (94, 95)`

HTTP 200 (application/json)

```text
{
  "query": "SELECT id FROM brokers WHERE id IN (94, 95)",
  "results": [
    {
      "statement": "SELECT id FROM brokers WHERE id IN (94, 95)",
      "columns": [
        {"name": "id", "type": "INT"}
      ],
      "dataset": [
        [95]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 25, "execute_us": 57}
    }
  ],
  "timings": {"parse_us": 25, "execute_us": 57}
}
```

<a id="format"></a>

### One array per column: format=columns

`?format=columns` writes every `dataset` as an object with one array per column instead of an array of rows:

**HTTP: format=columns: one array per column** (sample data: sample)

```http
GET /exec?compat=0&format=columns&query=SELECT symbol, close FROM ochl_day WHERE symbol = 'CITY' ORDER BY time LIMIT 3
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "SELECT symbol, close FROM ochl_day WHERE symbol = 'CITY' ORDER BY time LIMIT 3",
  "results": [
    {
      "statement": "SELECT symbol, close FROM ochl_day WHERE symbol = 'CITY' ORDER BY time LIMIT 3",
      "columns": [
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "close", "type": "DOUBLE"}
      ],
      "dataset": {
        "symbol": ["CITY", "CITY", "CITY"],
        "close": [542.2, 539.7, 539.3]
      },
      "count": 3,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 20, "execute_us": 279}
    }
  ],
  "timings": {"parse_us": 20, "execute_us": 279}
}
```

- A chart, a spreadsheet or a columnar file gets the shape it stores, with no reshaping on the client.
- The cells are the same as in the row form: times as ISO strings, JSON columns as JSON, `null` for NULL.
- Two result columns with one name: the later one wins (an object holds one of each name). Give them aliases.
- `format=rows` is the default. Anything else is a 400.

<a id="nan"></a>

### NaN and Infinity: nan=string

JSON has no numbers for NaN, Infinity and -Infinity. By default `/exec` writes them as `null`, as QuestDB's `/exec` does, so an old client reads them as it always did. A `null` there cannot be told from a real `NULL`, though: with `?nan=string` they come as the strings `"NaN"`, `"Infinity"` and `"-Infinity"` (the spelling PostgreSQL and JavaScript use; `Number("NaN")` is `NaN`).

**HTTP: The same row, both ways**

```http
GET /exec?compat=0&query=SELECT 'NaN'::float8 AS nan, 'Infinity'::float8 AS inf, NULL::float8 AS nothing, 1.5::float8 AS number
###
GET /exec?compat=0&nan=string&query=SELECT 'NaN'::float8 AS nan, 'Infinity'::float8 AS inf, NULL::float8 AS nothing, 1.5::float8 AS number
```

Response:

`GET /exec?compat=0&query=SELECT 'NaN'::float8 AS nan, 'Infinity'::float8 AS inf, NULL::float8 AS nothing, 1.5::float8 AS number`

HTTP 200 (application/json)

```text
{
  "query": "SELECT 'NaN'::float8 AS nan, 'Infinity'::float8 AS inf, NULL::float8 AS nothing, 1.5::float8 AS number",
  "results": [
    {
      "statement": "SELECT CAST('NaN' AS DOUBLE) AS nan, CAST('Infinity' AS DOUBLE) AS inf, CAST(NULL AS DOUBLE) AS nothing, CAST(1.5 AS DOUBLE) AS number",
      "columns": [
        {"name": "nan", "type": "DOUBLE"},
        {"name": "inf", "type": "DOUBLE"},
        {"name": "nothing", "type": "STRING"},
        {"name": "number", "type": "DOUBLE"}
      ],
      "dataset": [
        [null, null, null, 1.5]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 11, "execute_us": 18}
    }
  ],
  "timings": {"parse_us": 11, "execute_us": 18}
}
```

`GET /exec?compat=0&nan=string&query=SELECT 'NaN'::float8 AS nan, 'Infinity'::float8 AS inf, NULL::float8 AS nothing, 1.5::float8 AS number`

HTTP 200 (application/json)

```text
{
  "query": "SELECT 'NaN'::float8 AS nan, 'Infinity'::float8 AS inf, NULL::float8 AS nothing, 1.5::float8 AS number",
  "results": [
    {
      "statement": "SELECT CAST('NaN' AS DOUBLE) AS nan, CAST('Infinity' AS DOUBLE) AS inf, CAST(NULL AS DOUBLE) AS nothing, CAST(1.5 AS DOUBLE) AS number",
      "columns": [
        {"name": "nan", "type": "DOUBLE"},
        {"name": "inf", "type": "DOUBLE"},
        {"name": "nothing", "type": "STRING"},
        {"name": "number", "type": "DOUBLE"}
      ],
      "dataset": [
        ["NaN", "Infinity", null, 1.5]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 3, "execute_us": 33}
    }
  ],
  "timings": {"parse_us": 3, "execute_us": 33}
}
```

- Only `DOUBLE` and `FLOAT` values change; `NULL` stays `null`.
- `nan=null` is the default. Anything else is a 400.
- The PostgreSQL port always sends `NaN`, `Infinity` and `-Infinity`.

<a id="etag"></a>

### Nothing to send: ETag and If-None-Match

Every `/exec` reply that carries a dataset names it in an `ETag` header - a checksum of the dataset's bytes, its size and its shape. A client that keeps the last answer sends the tag back:

```text
POST /exec?compat=0
If-None-Match: "102625ff-1bcr"

SELECT time, close FROM ochl_day WHERE symbol = 'CITY' ORDER BY time

HTTP/1.1 304 Not Modified
```

- While the data is the same the answer is a **304 with no body**: a page that refreshes every few seconds costs the query, not the bytes.
- The query still runs (or comes from the result cache); only the sending is saved.
- The tag changes as soon as any row the query reads changes, because it is made from the answer itself; with the result cache on, a repeated query with the same tag is answered from memory.
- The row and column shapes have different tags.

<a id="atomic"></a>

### All or nothing: atomic=1

With `atomic=1` (or the header `X-KDB-Atomic: 1`) the whole body runs as **one transaction**. When any statement fails, **every** statement of the body is rolled back.

| Case | Answer |
|---|---|
| all statements work | 200, the normal answer. Everything is saved together. |
| a statement fails | not 200, `error`, `"saved": 0`, `"rolled_back": true`. Nothing is saved. |
| the body has a statement that cannot run in a transaction | 400 **before anything runs**, `"results": []` |

- **Allowed:** `SELECT`, `SHOW`, `EXPLAIN`, `INSERT`, `UPDATE`, `DELETE`, `CALL`, cursors, `CHECK TABLE`.
- **Refused:** `CREATE`, `DROP`, `ALTER`, `RENAME`, `REFRESH VIEW`, `BACKUP DATABASE`, `USE`, `SET`, users and grants (KarelaDB cannot roll these back), and `BEGIN`, `COMMIT`, `ROLLBACK` (the body is already a transaction). The message is `atomic=1: CREATE TABLE cannot run inside a transaction ...`.
- `atomic=1` cannot be used with a session (`X-KDB-Session`): there, send `BEGIN` ... `COMMIT` yourself.
- `line` and `column` of an error still count in the text you sent.
- Other writers wait until the body is done, as with `BEGIN` ... `COMMIT`. Keep atomic bodies short.

**HTTP: atomic=1: the second INSERT fails, so the first one is rolled back too** (sample data: sample; shows an error)

```http
POST /exec?compat=0&atomic=1

INSERT INTO brokers VALUES (96, 'Summit Capital');
INSERT INTO brokers VALUES (96, 'Summit Capital again')
###
GET /exec?compat=0&query=SELECT count(*) AS rows_with_id_96 FROM brokers WHERE id = 96
```

Response:

`POST /exec?compat=0&atomic=1`

HTTP 400 (application/json)

```text
{
  "query": "INSERT INTO brokers VALUES (96, 'Summit Capital');\nINSERT INTO brokers VALUES (96, 'Summit Capital again')",
  "results": [
    {
      "statement": "INSERT INTO brokers VALUES (96, 'Summit Capital')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 2, "execute_us": 95}
    }
  ],
  "saved": 0,
  "rolled_back": true,
  "error": "a row with id='96' already exists in 'brokers'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it (the transaction was rolled back)",
  "sqlstate": "23505",
  "table": "brokers",
  "constraint": "brokers_pkey",
  "column_name": "id"
}
```

`GET /exec?compat=0&query=SELECT count(*) AS rows_with_id_96 FROM brokers WHERE id = 96`

HTTP 200 (application/json)

```text
{
  "query": "SELECT count(*) AS rows_with_id_96 FROM brokers WHERE id = 96",
  "results": [
    {
      "statement": "SELECT count(*) AS rows_with_id_96 FROM brokers WHERE id = 96",
      "columns": [
        {"name": "rows_with_id_96", "type": "LONG"}
      ],
      "dataset": [
        [0]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 11, "execute_us": 59}
    }
  ],
  "timings": {"parse_us": 11, "execute_us": 59}
}
```

**HTTP: atomic=1 with statements that all work** (sample data: sample)

```http
POST /exec?compat=0&atomic=1

INSERT INTO brokers VALUES (93, 'Delta Securities');
UPDATE brokers SET name = 'Delta Securities Ltd' WHERE id = 93;
SELECT id, name FROM brokers WHERE id = 93
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "INSERT INTO brokers VALUES (93, 'Delta Securities');\nUPDATE brokers SET name = 'Delta Securities Ltd' WHERE id = 93;\nSELECT id, name FROM brokers WHERE id = 93",
  "results": [
    {
      "statement": "INSERT INTO brokers VALUES (93, 'Delta Securities')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 3, "execute_us": 82}
    },
    {
      "statement": "UPDATE brokers SET name = 'Delta Securities Ltd' WHERE id = 93",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) updated",
      "timings": {"parse_us": 3, "execute_us": 23}
    },
    {
      "statement": "SELECT id, name FROM brokers WHERE id = 93",
      "columns": [
        {"name": "id", "type": "INT"},
        {"name": "name", "type": "STRING"}
      ],
      "dataset": [
        [93, "Delta Securities Ltd"]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 3, "execute_us": 25}
    }
  ],
  "timings": {"parse_us": 9, "execute_us": 130}
}
```

**HTTP: atomic=1 refuses CREATE TABLE before anything runs**

```http
POST /exec?compat=0&atomic=1

CREATE TABLE notes (id LONG PRIMARY KEY);
INSERT INTO notes VALUES (1)
```

Response:

HTTP 400 (application/json)

```text
{
  "query": "CREATE TABLE notes (id LONG PRIMARY KEY);\nINSERT INTO notes VALUES (1)",
  "results": [],
  "saved": 0,
  "rolled_back": false,
  "error": "atomic=1: CREATE TABLE cannot run inside a transaction (a rollback cannot undo it), so nothing was run; send it in a request without atomic=1",
  "sqlstate": "XX000"
}
```

**HTTP: A form field query= (what an HTML form or curl --data-urlencode sends)** (sample data: sample)

```http
POST /exec
Content-Type: application/x-www-form-urlencoded

compat=0&limit=3&query=SELECT symbol, ltp FROM live_data LATEST ON timestamp PARTITION BY symbol ORDER BY symbol
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "SELECT symbol, ltp FROM live_data LATEST ON timestamp PARTITION BY symbol ORDER BY symbol",
  "results": [
    {
      "statement": "SELECT symbol, ltp FROM live_data LATEST ON timestamp PARTITION BY symbol ORDER BY symbol",
      "columns": [
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "ltp", "type": "DOUBLE"}
      ],
      "dataset": [
        ["CITY", 527.1],
        ["COAST", 401.9],
        ["TELCO", 897.7]
      ],
      "count": 3,
      "truncated": true,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 30, "execute_us": 212}
    }
  ],
  "timings": {"parse_us": 30, "execute_us": 212}
}
```

**HTTP: Create a table and write rows in one request**

```http
POST /exec?compat=0

CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO ticks VALUES ('2026-09-10T05:15:00Z', 'CITY', 512.4), ('2026-09-10T05:15:01Z', 'COAST', 380.1);
SELECT * FROM ticks
```

Response:

HTTP 200 (application/json)

```text
{
  "query": "CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;\nINSERT INTO ticks VALUES ('2026-09-10T05:15:00Z', 'CITY', 512.4), ('2026-09-10T05:15:01Z', 'COAST', 380.1);\nSELECT * FROM ticks",
  "results": [
    {
      "statement": "CREATE TABLE ticks (\n  time TIMESTAMP,\n  symbol SYMBOL,\n  price DOUBLE\n) TIMESERIES(time) PARTITION BY DAY",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "table 'ticks' created",
      "timings": {"parse_us": 11, "execute_us": 13509}
    },
    {
      "statement": "INSERT INTO ticks VALUES ('2026-09-10T05:15:00Z', 'CITY', 512.4), ('2026-09-10T05:15:01Z', 'COAST', 380.1)",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 2,
      "message": "2 row(s) inserted",
      "timings": {"parse_us": 11, "execute_us": 2044}
    },
    {
      "statement": "SELECT * FROM ticks",
      "columns": [
        {"name": "time", "type": "TIMESTAMP"},
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "price", "type": "DOUBLE"}
      ],
      "dataset": [
        ["2026-09-10T05:15:00.000Z", "CITY", 512.4],
        ["2026-09-10T05:15:01.000Z", "COAST", 380.1]
      ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 11, "execute_us": 41}
    }
  ],
  "timings": {"parse_us": 33, "execute_us": 15594}
}
```

Clients (not run by the help build; [chapter 8](../tutorial/08-http-api.md) has tested ones with real output):

```bash
curl -s "http://127.0.0.1:9900/exec?compat=0" --data-binary "INSERT INTO brokers VALUES (99, 'Himalayan Securities')"
curl -s "http://127.0.0.1:9900/exec?compat=0" -H "Content-Type: text/plain; charset=utf-8" --data-binary @load.sql
```

```powershell
$body = [System.IO.File]::ReadAllBytes((Resolve-Path load.sql))   # the bytes: no encoding is lost
$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/exec?compat=0" -Body $body -ContentType "text/plain; charset=utf-8"
$r.results | ForEach-Object { $_.message }
```

```python
import requests

def kareladb(sql, db=None, limit=10000):
    params = {"compat": 0, "limit": limit}
    if db:
        params["db"] = db
    r = requests.post("http://127.0.0.1:9900/exec", params=params, data=sql.encode("utf-8"),
                      headers={"Content-Type": "text/plain; charset=utf-8"})
    body = r.json()
    if r.status_code != 200:
        raise RuntimeError(f"KarelaDB error (HTTP {r.status_code}): {body['error']}")
    return body["results"]

res = kareladb("SELECT symbol, close FROM ochl_day WHERE symbol = 'CITY' LIMIT 3")[0]
names = [c["name"] for c in res["columns"]]
for row in res["dataset"]:
    print(dict(zip(names, row)))
```

```js
async function kareladb(sql, db) {
  const url = `http://127.0.0.1:9900/exec?compat=0${db ? `&db=${encodeURIComponent(db)}` : ""}`;
  const res = await fetch(url, { method: "POST", headers: { "Content-Type": "text/plain; charset=utf-8" }, body: sql });
  const body = await res.json();
  if (!res.ok) throw new Error(`KarelaDB error (HTTP ${res.status}): ${body.error}`);
  return body.results;
}
const [res] = await kareladb("SELECT symbol, close FROM ochl_day LIMIT 3");
console.log(res.dataset);
```

```csharp
static readonly HttpClient Http = new HttpClient { BaseAddress = new Uri("http://127.0.0.1:9900") };

static async Task<JsonElement> Kdb(string sql)
{
    var content = new StringContent(sql, Encoding.UTF8, "text/plain");
    using var res = await Http.PostAsync("/exec?compat=0", content);
    var json = JsonDocument.Parse(await res.Content.ReadAsStringAsync()).RootElement.Clone();
    if (!res.IsSuccessStatusCode)
        throw new Exception($"KarelaDB error (HTTP {(int)res.StatusCode}): {json.GetProperty("error").GetString()}");
    return json.GetProperty("results");
}
```

## GET /exp

Syntax:

```sql
GET /exp?query=<SQL>[&db=<name>][&limit=N][&filename=<name.csv>]
```

Runs SQL that reads and answers with the rows of the **last** statement as a CSV file. A browser downloads it.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `query` | URL | `SELECT`, `SHOW` or `EXPLAIN` | required |
| `db` | URL | The database (or the header `X-KDB-Database`) | the default database |
| `limit` | URL | Most rows: any number, also above a million (`limit=50000000` for a whole big table). `0` or less means 1,000,000. | 1,000,000 |
| `filename` | URL | The name of the downloaded file. Only letters, digits, `-`, `_` and `.` are kept; at most 100 characters. | `kdb-export.csv` |

| Answer | Meaning |
|---|---|
| `Content-Type: text/csv; charset=utf-8` | a CSV file in UTF-8 |
| `Content-Disposition: attachment; filename="..."` | tells a browser to save it with that name |
| `X-KDB-Rows` | the rows in the file |
| `X-KDB-Truncated` | `true` when `limit` (or the default of 1,000,000) cut rows off: more rows exist. `false` when the file holds every row |
| first line | the column names |
| next lines | one row each; lines end with CR LF (`\r\n`, as Windows and Excel expect) |

- **Status codes:** 200 OK; 400 no `query`, bad SQL, or SQL that is not a `SELECT`, `SHOW` or `EXPLAIN`; 401/403 [login or role](http-login.md); 404 unknown database.
- **Big exports are streamed.** One `SELECT` of the columns of one table (with a `WHERE`, no `ORDER BY`, `GROUP BY` or join) is sent while it is read, so the server never holds the whole file: millions of rows go out at a few million rows a second, beyond `max_result_memory`. Once the file passes about 16 MB the answer is sent with `Transfer-Encoding: chunked`, and `X-KDB-Rows` and `X-KDB-Truncated` come at its end as trailer fields (`Trailer: X-KDB-Rows, X-KDB-Truncated`; `curl -D -` shows them after the body). A smaller file has them as headers. Other queries (`ORDER BY`, `GROUP BY`, joins, several statements) are made whole first, within the memory limits.
- **An error part way** through a streamed export (the client left, the server stops) ends the connection without the last chunk, so the client sees a cut-off download, never a short file that looks whole.
- **Time:** a streamed export is one statement until its last row is sent, so the statement timeout (`kareladb serve --statement-timeout`, 60 s by default) counts the sending too. For a very big table over a slow link, raise it or export by time ranges.
- **Notes:** NULL is an empty field. Text with a comma, a quote, a line break, or a space at the start or end is put in `"..."` (a `"` inside becomes `""`). Times are UTC like `2026-09-10T00:00:00.000Z`. Errors are JSON (`query`, `error`, `line`, `column`), not CSV. `/exp` accepts only reading SQL even with POST, and does not use sessions.

**HTTP: Daily closes as CSV, with a file name** (sample data: sample)

```http
GET /exp?filename=closes-2026-09-10.csv&query=SELECT time, symbol, close FROM ochl_day WHERE time IN '2026-09-10' ORDER BY symbol
```

Response:

HTTP 200 (text/csv)

```text
time,symbol,close
2026-09-10T00:00:00.000Z,CITY,504.9
2026-09-10T00:00:00.000Z,COAST,376.1
2026-09-10T00:00:00.000Z,VOLT,191.2
```

**HTTP: Text with commas and quotes, and NULL**

```http
GET /exp?query=SELECT 'City Bank, Kathmandu' AS name, 'the "best" bank' AS note, NULL AS empty, 512.4 AS price
```

Response:

HTTP 200 (text/csv)

```text
name,note,empty,price
"City Bank, Kathmandu","the ""best"" bank",,512.4
```

**HTTP: Only SQL that reads can be exported** (sample data: sample)

```http
GET /exp?query=DELETE FROM brokers
```

Response:

HTTP 400 (application/json)

```text
{"error": "CSV export needs a SELECT, SHOW or EXPLAIN statement"}
```

```bash
curl -s -G "http://127.0.0.1:9900/exp" --data-urlencode "query=SELECT * FROM ochl_day WHERE symbol = 'COAST' ORDER BY time" -o coast.csv
```

```powershell
$q = [uri]::EscapeDataString("SELECT * FROM ochl_day WHERE symbol = 'COAST' ORDER BY time")
Invoke-WebRequest "http://127.0.0.1:9900/exp?query=$q" -OutFile coast.csv
Import-Csv coast.csv | Select-Object -First 3
```

```python
import requests

r = requests.get("http://127.0.0.1:9900/exp",
                 params={"query": "SELECT * FROM ochl_day WHERE symbol = 'COAST' ORDER BY time"})
r.raise_for_status()
open("coast.csv", "wb").write(r.content)
```

## POST /exp

Syntax:

```sql
POST /exp[?db=<name>][&limit=N][&filename=<name.csv>]
body: the SQL text, or a form with the field query=<SQL>
```

The same as [GET /exp](http-exec.md#get-exp), with the SQL in the body. Use it when the query is too long for a URL.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| body | body | `SELECT`, `SHOW` or `EXPLAIN` (or a form field `query=`) | required |
| `db`, `limit`, `filename` | URL or form field | as for GET /exp | as for GET /exp |

| Answer | Meaning |
|---|---|
| CSV file | as for [GET /exp](http-exec.md#get-exp) |

- **Status codes:** 200 OK; 400 no SQL, bad SQL, or SQL that changes data; 401/403 login or role; 404 unknown database.
- **Notes:** POST does not allow changes here: `/exp` only exports.

**HTTP: A long SELECT in the body** (sample data: sample)

```http
POST /exp?filename=volume.csv

SELECT symbol, sum(quantity) AS shares, round(sum(amount), 2) AS amount
FROM trade_log
GROUP BY symbol
ORDER BY shares DESC
```

Response:

HTTP 200 (text/csv)

```text
symbol,shares,amount
COAST,3070,1227510
TELCO,2770,2438260
CITY,2420,1247230
VOLT,400,73950
```

```js
// Node 18+: save a CSV export.
import fs from "node:fs";
const res = await fetch("http://127.0.0.1:9900/exp?filename=volume.csv", {
  method: "POST",
  headers: { "Content-Type": "text/plain; charset=utf-8" },
  body: "SELECT symbol, sum(quantity) AS shares FROM trade_log GROUP BY symbol",
});
if (!res.ok) throw new Error((await res.json()).error);
fs.writeFileSync("volume.csv", Buffer.from(await res.arrayBuffer()));
```
