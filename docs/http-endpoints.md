# Saved queries as URLs (CREATE ENDPOINT)

> Save a SELECT with named parameters under a name; programs then call GET /v/<name>?param=value and get JSON, without sending SQL.

- Category: HTTP API
- Keywords: CREATE ENDPOINT, DROP ENDPOINT, endpoint, endpoints, saved query, saved queries, named query, REST endpoint, /v/, GET /v, URL parameters, query parameters, parameterized query, :name, DEFAULT, ROLE, API without SQL
- See also: [Run SQL over HTTP (/exec, /exp)](http-exec.md), [HTTP API overview](http-overview.md), [Users and roles](users-and-roles.md), [Views](views.md), [Saved functions](saved-functions.md)

An **endpoint** is a saved `SELECT` with **parameters**. A program calls it with a plain URL and gets the same JSON as [`/exec`](http-exec.md), without writing or sending any SQL:

```
GET /v/last_close?symbol=CITY&n=5
```

Why: the SQL lives in one place (the database), a client cannot change it, and each value from the URL is checked and used as a **value**, never as SQL text, so nobody can slip SQL in through a parameter.

<a id="create-endpoint"></a>

## CREATE ENDPOINT

Syntax:

```sql
CREATE [OR REPLACE] ENDPOINT [GET] /v/name [(param TYPE [DEFAULT value], ...)] [ROLE read | write | ddl | admin]
  AS SELECT ... :param ...
```

| Part | Meaning |
|---|---|
| `/v/name` | the URL: `GET /v/name`. Letters, digits and `_`. Writing `GET /v/` is optional: `CREATE ENDPOINT last_close (...)` is the same |
| `(param TYPE ...)` | the parameters, with a [type](column-types.md) each: `INT`, `LONG`, `DOUBLE`, `BOOL`, `TEXT`, `SYMBOL`, `TIMESTAMP`, `DATE` ... |
| `DEFAULT value` | used when the URL leaves the parameter out; a constant (`10`, `'NEPSE'`, `true`) |
| `ROLE` | the least [role](users-and-roles.md) a caller needs on the database to call it; `read` when not given |
| `AS SELECT` | one query; `:param` is where a parameter's value goes (`$1`, `$2` ... by position work too) |

- **Role:** `ddl`, like `CREATE FUNCTION`.
- **Only reads:** the query must be one `SELECT` (or `WITH ... SELECT`). Writes belong to [procedures](procedures.md).
- The tables are looked up when the endpoint is called, as for a [view](views.md): an endpoint may name a table made later.

**HTTP: Save the last closes of a symbol as an endpoint, then call it** (sample data: sample)

```http
POST /exec?compat=0

CREATE OR REPLACE ENDPOINT GET /v/last_close(symbol TEXT, n INT DEFAULT 3) AS
  SELECT time, close FROM ochl_day WHERE symbol = :symbol ORDER BY time DESC LIMIT :n
###
GET /v/last_close?symbol=CITY
###
GET /v/last_close?symbol=CITY&n=1
```

Response:

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "CREATE OR REPLACE ENDPOINT GET /v/last_close(symbol TEXT, n INT DEFAULT 3) AS\n  SELECT time, close FROM ochl_day WHERE symbol = :symbol ORDER BY time DESC LIMIT :n",
  "results": [
    {
      "statement": "CREATE OR REPLACE ENDPOINT GET /v/last_close(symbol STRING, n INT DEFAULT 3) ROLE read AS SELECT time , close FROM ochl_day WHERE symbol = $1 ORDER BY time DESC LIMIT $2",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "endpoint 'last_close' created: GET /v/last_close",
      "timings": {"parse_us": 47, "execute_us": 6600}
    }
  ],
  "timings": {"parse_us": 47, "execute_us": 6600}
}
```

`GET /v/last_close?symbol=CITY`

HTTP 200 (application/json)

```text
{
  "query": "SELECT time , close FROM ochl_day WHERE symbol = $1 ORDER BY time DESC LIMIT $2",
  "results": [
    {
      "statement": "SELECT time, close FROM ochl_day WHERE symbol = 'CITY' ORDER BY time DESC LIMIT 3",
      "columns": [
        {"name": "time", "type": "TIMESTAMP"},
        {"name": "close", "type": "DOUBLE"}
      ],
      "dataset": [
        ["2026-09-10T00:00:00.000Z", 504.9],
        ["2026-09-09T00:00:00.000Z", 504.6],
        ["2026-09-08T00:00:00.000Z", 497.5]
      ],
      "count": 3,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 11, "execute_us": 236}
    }
  ],
  "columns": [
    {"name": "time", "type": "TIMESTAMP"},
    {"name": "close", "type": "DOUBLE"}
  ],
  "dataset": [
    ["2026-09-10T00:00:00.000Z", 504.9],
    ["2026-09-09T00:00:00.000Z", 504.6],
    ["2026-09-08T00:00:00.000Z", 497.5]
  ],
  "count": 3,
  "timings": {"parse_us": 11, "execute_us": 236}
}
```

`GET /v/last_close?symbol=CITY&n=1`

HTTP 200 (application/json)

```text
{
  "query": "SELECT time , close FROM ochl_day WHERE symbol = $1 ORDER BY time DESC LIMIT $2",
  "results": [
    {
      "statement": "SELECT time, close FROM ochl_day WHERE symbol = 'CITY' ORDER BY time DESC LIMIT 1",
      "columns": [
        {"name": "time", "type": "TIMESTAMP"},
        {"name": "close", "type": "DOUBLE"}
      ],
      "dataset": [
        ["2026-09-10T00:00:00.000Z", 504.9]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 16, "execute_us": 137}
    }
  ],
  "columns": [
    {"name": "time", "type": "TIMESTAMP"},
    {"name": "close", "type": "DOUBLE"}
  ],
  "dataset": [
    ["2026-09-10T00:00:00.000Z", 504.9]
  ],
  "count": 1,
  "timings": {"parse_us": 16, "execute_us": 137}
}
```

<a id="call"></a>

## Calling an endpoint

Syntax:

```sql
GET /v/name?param=value&...[&db=<database>][&format=columns][&limit=<n>]
```

| Answer | When |
|---|---|
| `200` and the JSON of [`/exec`](http-exec.md) | it ran |
| `400` | a parameter is missing (and has no `DEFAULT`), is not of its type (`n=abc` for an `INT`), or is not a parameter of the endpoint. The message shows how to call it |
| `403` | the caller's role on the database is below the endpoint's `ROLE` |
| `404` | no endpoint of that name in the database |

- **Types:** whole-number types take whole numbers only, number types any number, `BOOL` takes `true` / `false` (also `1` / `0`). Every other type is passed as text, which the query compares or casts as it would a quoted value: `'2026-09-24'` for a `TIMESTAMP`.
- **Rights:** the query runs with the **caller's** rights, as on `/exec`. An endpoint never lets a user read a table they could not read with SQL.
- `db`, `format`, `nan`, `limit` and `cache` work as on [`/exec`](http-exec.md).

**HTTP: A wrong parameter is a 400 that says how to call it** (sample data: sample)

```http
POST /exec?compat=0

CREATE OR REPLACE ENDPOINT GET /v/closes(symbol TEXT, n INT) AS
  SELECT close FROM ochl_day WHERE symbol = :symbol ORDER BY time DESC LIMIT :n
###
GET /v/closes?symbol=CITY&n=three
```

Response:

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "CREATE OR REPLACE ENDPOINT GET /v/closes(symbol TEXT, n INT) AS\n  SELECT close FROM ochl_day WHERE symbol = :symbol ORDER BY time DESC LIMIT :n",
  "results": [
    {
      "statement": "CREATE OR REPLACE ENDPOINT GET /v/closes(symbol STRING, n INT) ROLE read AS SELECT close FROM ochl_day WHERE symbol = $1 ORDER BY time DESC LIMIT $2",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "endpoint 'closes' created: GET /v/closes",
      "timings": {"parse_us": 21, "execute_us": 6328}
    }
  ],
  "timings": {"parse_us": 21, "execute_us": 6328}
}
```

`GET /v/closes?symbol=CITY&n=three`

HTTP 400 (application/json)

```text
{"error": "parameter 'n': 'three' is not a whole number"}
```

<a id="drop-endpoint"></a>

## DROP ENDPOINT

Syntax:

```sql
DROP ENDPOINT [IF EXISTS] name
```

The URL answers `404` from then on.

<a id="stored"></a>

## How it is stored

An endpoint is kept with the database's functions and procedures, so a backup, a restore and a restart keep it. A database with an endpoint cannot be opened by a build from before 2026-10-03; it says it "needs a newer KDB" (its name then) and changes nothing.
