# Sessions and cursors over HTTP

> Keep a transaction open over several HTTP requests with a session, and read a big result a part at a time with a cursor.

- Category: HTTP API
- Keywords: session, /session, X-KDB-Session, transaction over HTTP, BEGIN COMMIT over HTTP, idle\_timeout\_ms, cursor, /cursor, fetch, done, big result, paging, read in parts, snapshot, database is busy, 503
- See also: [Transactions](transactions.md), [Cursors](cursors.md), [Run SQL over HTTP (/exec, /exp)](http-exec.md), [HTTP API overview](http-overview.md)

Normally every HTTP request stands alone: a `BEGIN` in one `/exec` request cannot be finished by a `COMMIT` in the next one. Two tools help:

- A **session** keeps a transaction (`BEGIN` ... `COMMIT`: several changes that are saved all together or not at all) open between requests. Open one with `POST /session`, then send its id in the header `X-KDB-Session` with each `/exec`.
- A **cursor** runs one `SELECT` once, keeps its rows on the server, and gives them to you a few at a time. Use it for results too big for one answer.

More about transactions: [Transactions](transactions.md). SQL cursors inside procedures (`DECLARE ... CURSOR`): [Cursors](cursors.md).

## POST /session

Syntax:

```sql
POST /session
```

Opens a session and gives back its id. Send the id with every request that belongs to it:

Syntax:

```sql
X-KDB-Session: <id>        (a header on /exec)
/exec?session=<id>         (or a URL parameter or form field)
```

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| (none) | - | The request has no body | - |

| Answer field | Meaning |
|---|---|
| `session` | The session id: 32 random hex characters. Keep it secret: it is like a key to the open transaction. |
| `idle_timeout_ms` | A session unused this long is closed, and its open transaction is rolled back (undone). 600,000 ms = 10 minutes. |

- **Status codes:** 200; 401 without a needed login; 503 too many open sessions (at most 1,000): close unused ones.
- **Notes:**
  - A session belongs to the user who opened it. Another user's session id answers 404, as if it did not exist.
  - A session may run SQL on several databases (`db=` on each request); `DELETE /session/<id>` ends it on all of them.
  - **One writer per table:** while a session has an open `BEGIN`, other changes to the tables it used (other requests, the line protocol) **wait** up to the lock timeout (5 seconds unless set: `SET lock_timeout = '20s'` in the session, or the header `X-KDB-Lock-Timeout: 20s` on one request; see [lock timeout](transactions.md#lock-timeout)), then fail with HTTP 503 `table 'x' is busy: ...`. Changes to other tables go on. Reads do not wait: they see the rows as they were before the open transaction. Keep transactions short.
  - An open transaction with no statement for **30 seconds** is rolled back by the database. The session then gets an error until it sends `ROLLBACK`.
  - Without a session, a transaction cannot stay open after its request: a `BEGIN` without `COMMIT` is rolled back at the end of the request, and the answer is an error (see the example below). Send `BEGIN; ...; COMMIT` in one `POST /exec`, or use a session.

**HTTP: Without a session: BEGIN without COMMIT is rolled back** (sample data: sample; shows an error)

```http
POST /exec?compat=0

BEGIN;
INSERT INTO brokers VALUES (72, 'Never Saved Securities')
###
GET /exec?compat=0&query=SELECT count(*) AS saved FROM brokers WHERE id = 72
```

Response:

`POST /exec?compat=0`

HTTP 400 (application/json)

```text
{
  "query": "BEGIN;\nINSERT INTO brokers VALUES (72, 'Never Saved Securities')",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 9, "execute_us": 4}
    },
    {
      "statement": "INSERT INTO brokers VALUES (72, 'Never Saved Securities')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 9, "execute_us": 89}
    }
  ],
  "saved": 0,
  "rolled_back": true,
  "error": "BEGIN without COMMIT: the transaction was rolled back (end it with COMMIT to save the changes)",
  "sqlstate": "XX000"
}
```

`GET /exec?compat=0&query=SELECT count(*) AS saved FROM brokers WHERE id = 72`

HTTP 200 (application/json)

```text
{
  "query": "SELECT count(*) AS saved FROM brokers WHERE id = 72",
  "results": [
    {
      "statement": "SELECT count(*) AS saved FROM brokers WHERE id = 72",
      "columns": [
        {"name": "saved", "type": "LONG"}
      ],
      "dataset": [
        [0]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 14, "execute_us": 72}
    }
  ],
  "timings": {"parse_us": 14, "execute_us": 72}
}
```

**HTTP: A transaction over four requests** (sample data: sample)

```http
POST /session
###
POST /exec?compat=0
X-KDB-Session: {{session}}

BEGIN;
INSERT INTO brokers VALUES (70, 'Transaction Test Securities');
###
GET /exec?compat=0&query=SELECT count(*) AS others_see FROM brokers WHERE id = 70
###
POST /exec?compat=0
X-KDB-Session: {{session}}

COMMIT
###
GET /exec?compat=0&query=SELECT count(*) AS after_commit FROM brokers WHERE id = 70
###
DELETE /session/{{session}}
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "7e3111c959d2a5cdd57598e6749d5d53", "idle_timeout_ms": 600000}
```

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN;\nINSERT INTO brokers VALUES (70, 'Transaction Test Securities');",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 9, "execute_us": 4}
    },
    {
      "statement": "INSERT INTO brokers VALUES (70, 'Transaction Test Securities')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 9, "execute_us": 98}
    }
  ],
  "timings": {"parse_us": 18, "execute_us": 102}
}
```

`GET /exec?compat=0&query=SELECT count(*) AS others_see FROM brokers WHERE id = 70`

HTTP 200 (application/json)

```text
{
  "query": "SELECT count(*) AS others_see FROM brokers WHERE id = 70",
  "results": [
    {
      "statement": "SELECT count(*) AS others_see FROM brokers WHERE id = 70",
      "columns": [
        {"name": "others_see", "type": "LONG"}
      ],
      "dataset": [
        [0]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 17, "execute_us": 91}
    }
  ],
  "timings": {"parse_us": 17, "execute_us": 91}
}
```

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "COMMIT",
  "results": [
    {
      "statement": "COMMIT",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction committed: 1 change(s) saved",
      "timings": {"parse_us": 9, "execute_us": 440}
    }
  ],
  "timings": {"parse_us": 9, "execute_us": 440}
}
```

`GET /exec?compat=0&query=SELECT count(*) AS after_commit FROM brokers WHERE id = 70`

HTTP 200 (application/json)

```text
{
  "query": "SELECT count(*) AS after_commit FROM brokers WHERE id = 70",
  "results": [
    {
      "statement": "SELECT count(*) AS after_commit FROM brokers WHERE id = 70",
      "columns": [
        {"name": "after_commit", "type": "LONG"}
      ],
      "dataset": [
        [1]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 16, "execute_us": 113}
    }
  ],
  "timings": {"parse_us": 16, "execute_us": 113}
}
```

`DELETE /session/{{session}}`

HTTP 200 (application/json)

```text
{"session": "7e3111c959d2a5cdd57598e6749d5d53", "closed": true}
```

**HTTP: ROLLBACK undoes the changes of the session** (sample data: sample)

```http
POST /session
###
POST /exec?compat=0
X-KDB-Session: {{session}}

BEGIN;
UPDATE ochl_day SET close = 0 WHERE symbol = 'CITY';
SELECT max(close) AS inside_the_transaction FROM ochl_day WHERE symbol = 'CITY'
###
POST /exec?compat=0&session={{session}}

ROLLBACK;
SELECT max(close) AS after_rollback FROM ochl_day WHERE symbol = 'CITY'
###
DELETE /session/{{session}}
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "bca7eb0846996b79391ac25a4756166b", "idle_timeout_ms": 600000}
```

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN;\nUPDATE ochl_day SET close = 0 WHERE symbol = 'CITY';\nSELECT max(close) AS inside_the_transaction FROM ochl_day WHERE symbol = 'CITY'",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 15, "execute_us": 5}
    },
    {
      "statement": "UPDATE ochl_day SET close = 0 WHERE symbol = 'CITY'",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 19,
      "message": "19 row(s) updated",
      "timings": {"parse_us": 15, "execute_us": 348}
    },
    {
      "statement": "SELECT max(close) AS inside_the_transaction FROM ochl_day WHERE symbol = 'CITY'",
      "columns": [
        {"name": "inside_the_transaction", "type": "DOUBLE"}
      ],
      "dataset": [
        [0]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 15, "execute_us": 187}
    }
  ],
  "timings": {"parse_us": 45, "execute_us": 540}
}
```

`POST /exec?compat=0&session={{session}}`

HTTP 200 (application/json)

```text
{
  "query": "ROLLBACK;\nSELECT max(close) AS after_rollback FROM ochl_day WHERE symbol = 'CITY'",
  "results": [
    {
      "statement": "ROLLBACK",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction rolled back: 1 change(s) undone",
      "timings": {"parse_us": 16, "execute_us": 25}
    },
    {
      "statement": "SELECT max(close) AS after_rollback FROM ochl_day WHERE symbol = 'CITY'",
      "columns": [
        {"name": "after_rollback", "type": "DOUBLE"}
      ],
      "dataset": [
        [542.4]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 16, "execute_us": 114}
    }
  ],
  "timings": {"parse_us": 32, "execute_us": 139}
}
```

`DELETE /session/{{session}}`

HTTP 200 (application/json)

```text
{"session": "bca7eb0846996b79391ac25a4756166b", "closed": true}
```

A transfer between two accounts in Python, with the `requests` library:

```python
import requests

KarelaDB = "http://127.0.0.1:9900"

def run(sql, session=None):
    headers = {"Content-Type": "text/plain; charset=utf-8"}
    if session:
        headers["X-KDB-Session"] = session
    r = requests.post(f"{KarelaDB}/exec", params={"compat": 0, "db": "shop"}, data=sql.encode("utf-8"), headers=headers)
    body = r.json()
    if r.status_code != 200:
        raise RuntimeError(f"HTTP {r.status_code}: {body['error']}")
    return body["results"]

session = requests.post(f"{KarelaDB}/session").json()["session"]
try:
    run("BEGIN", session)
    run("UPDATE accounts SET balance = balance - 500 WHERE id = 1", session)
    balance = run("SELECT balance FROM accounts WHERE id = 1", session)[0]["dataset"][0][0]
    if float(balance) < 0:
        run("ROLLBACK", session)          # not enough money: undo
    else:
        run("UPDATE accounts SET balance = balance + 500 WHERE id = 2", session)
        run("COMMIT", session)
finally:
    requests.delete(f"{KarelaDB}/session/{session}")   # rolls back anything still open
```

```js
// Node 18+
const KarelaDB = "http://127.0.0.1:9900";
const { session } = await (await fetch(`${KarelaDB}/session`, { method: "POST" })).json();
const run = async (sql) => {
  const res = await fetch(`${KarelaDB}/exec?compat=0`, { method: "POST", headers: { "X-KDB-Session": session }, body: sql });
  const body = await res.json();
  if (!res.ok) throw new Error(body.error);
  return body.results;
};
try {
  await run("BEGIN");
  await run("INSERT INTO orders VALUES (1, 'CITY', 10)");
  await run("COMMIT");
} finally {
  await fetch(`${KarelaDB}/session/${session}`, { method: "DELETE" });
}
```

```powershell
$kdb = "http://127.0.0.1:9900"
$s = (Invoke-RestMethod -Method Post "$kdb/session").session
$h = @{ "X-KDB-Session" = $s }
Invoke-RestMethod -Method Post "$kdb/exec?compat=0" -Headers $h -ContentType "text/plain" -Body "BEGIN; INSERT INTO brokers VALUES (71, 'Test')" | Out-Null
Invoke-RestMethod -Method Post "$kdb/exec?compat=0" -Headers $h -ContentType "text/plain" -Body "COMMIT" | Out-Null
Invoke-RestMethod -Method Delete "$kdb/session/$s" | Out-Null
```

<a id="delete-session"></a>

## DELETE /session/<id>

Syntax:

```sql
DELETE /session/<id>
```

Closes a session. Its open transaction is **rolled back** (nothing of it is saved) and its SQL cursors are closed.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `<id>` | path | The id from `POST /session` | required |

| Answer field | Meaning |
|---|---|
| `session` | The id |
| `closed` | `true` |

- **Status codes:** 200; 401 without a needed login; 404 no such session (already closed, closed after 10 minutes unused, or opened by another user).
- **Notes:** always close sessions you opened (in a `finally` block), even after an error. A request with a closed session id answers 404 `session '...' does not exist: it was closed, or unused for more than 600 s (its open transaction was rolled back). Open a new one with POST /session`. A server restart closes every session.

**HTTP: Closing the session undoes the open transaction** (sample data: sample)

```http
POST /session
###
POST /exec?compat=0
X-KDB-Session: {{session}}

BEGIN;
DELETE FROM ochl_day WHERE symbol = 'CITY'
###
DELETE /session/{{session}}
###
GET /exec?compat=0&query=SELECT count(*) AS city_days_still_there FROM ochl_day WHERE symbol = 'CITY'
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "e0fde0f03e1f1989d93ea6254af8615a", "idle_timeout_ms": 600000}
```

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN;\nDELETE FROM ochl_day WHERE symbol = 'CITY'",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 14, "execute_us": 7}
    },
    {
      "statement": "DELETE FROM ochl_day WHERE symbol = 'CITY'",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 19,
      "message": "19 row(s) deleted",
      "timings": {"parse_us": 14, "execute_us": 348}
    }
  ],
  "timings": {"parse_us": 28, "execute_us": 355}
}
```

`DELETE /session/{{session}}`

HTTP 200 (application/json)

```text
{"session": "e0fde0f03e1f1989d93ea6254af8615a", "closed": true}
```

`GET /exec?compat=0&query=SELECT count(*) AS city_days_still_there FROM ochl_day WHERE symbol = 'CITY'`

HTTP 200 (application/json)

```text
{
  "query": "SELECT count(*) AS city_days_still_there FROM ochl_day WHERE symbol = 'CITY'",
  "results": [
    {
      "statement": "SELECT count(*) AS city_days_still_there FROM ochl_day WHERE symbol = 'CITY'",
      "columns": [
        {"name": "city_days_still_there", "type": "LONG"}
      ],
      "dataset": [
        [19]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 22, "execute_us": 163}
    }
  ],
  "timings": {"parse_us": 22, "execute_us": 163}
}
```

**HTTP: A closed session cannot be used**

```http
POST /session
###
DELETE /session/{{session}}
###
POST /exec?compat=0
X-KDB-Session: {{session}}

SELECT 1
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "8edc551161508c4ca7edfffb131edce8", "idle_timeout_ms": 600000}
```

`DELETE /session/{{session}}`

HTTP 200 (application/json)

```text
{"session": "8edc551161508c4ca7edfffb131edce8", "closed": true}
```

`POST /exec?compat=0`

HTTP 404 (application/json)

```text
{
  "error": "session '8edc551161508c4ca7edfffb131edce8' does not exist: it was closed, or unused for more than 600 s (its open transaction was rolled back). Open a new one with POST /session"
}
```

## POST /cursor

Syntax:

```sql
POST /cursor[?db=<name>]
body: one SELECT
```

Runs one `SELECT`, keeps all its rows on the server, and answers with the cursor's id. Read the rows with [GET /cursor/&lt;id&gt;](http-sessions-and-cursors.md#get-cursor).

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| body | body | Exactly one `SELECT` (or a form field `query=`) | required |
| `db` | URL | The database (or the header `X-KDB-Database`). Use the same database for all requests of this cursor. | the default database |

| Answer field | Meaning |
|---|---|
| `cursor` | The cursor id (16 hex characters, hard to guess) |
| `columns[]` | `name` and `type` of each column |
| `rows` | How many rows the cursor holds |

- **Status codes:** 200; 400 not exactly one SELECT, bad SQL, more than 10,000,000 rows, or too many open cursors; 401/403 login or role (needs `read`); 404 unknown database.
- **Notes:**
  - The rows are a **snapshot**: changes after `POST /cursor` do not change them. A cursor never sees a transaction that is still open.
  - The rows stay in the server's memory until the cursor is closed or done, so close it when you are finished.
  - At most 16 cursors per database are open at the same time (SQL cursors of procedures count too). An unused cursor closes after 10 minutes.
  - At most 10,000,000 rows per cursor: narrow the SELECT with `WHERE`.

**HTTP: Open a cursor, read 3 rows twice, close it** (sample data: sample)

```http
POST /cursor

SELECT time, symbol, close FROM ochl_minutes WHERE time IN '2026-09-10' ORDER BY time, symbol
###
GET /cursor/{{cursor}}?fetch=3
###
GET /cursor/{{cursor}}?fetch=3
###
DELETE /cursor/{{cursor}}
```

Response:

`POST /cursor`

HTTP 200 (application/json)

```text
{
  "cursor": "36a80b5cca6d9384",
  "columns": [
    {"name": "time", "type": "TIMESTAMP"},
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "close", "type": "DOUBLE"}
  ],
  "rows": 476
}
```

`GET /cursor/{{cursor}}?fetch=3`

HTTP 200 (application/json)

```text
{
  "cursor": "36a80b5cca6d9384",
  "columns": [
    {"name": "time", "type": "TIMESTAMP"},
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "close", "type": "DOUBLE"}
  ],
  "dataset": [
    ["2026-09-10T05:15:00.000Z", "CITY", 504.4],
    ["2026-09-10T05:15:00.000Z", "COAST", 380],
    ["2026-09-10T05:16:00.000Z", "CITY", 504.6]
  ],
  "count": 3,
  "done": false
}
```

`GET /cursor/{{cursor}}?fetch=3`

HTTP 200 (application/json)

```text
{
  "cursor": "36a80b5cca6d9384",
  "columns": [
    {"name": "time", "type": "TIMESTAMP"},
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "close", "type": "DOUBLE"}
  ],
  "dataset": [
    ["2026-09-10T05:16:00.000Z", "COAST", 379.6],
    ["2026-09-10T05:17:00.000Z", "CITY", 504.2],
    ["2026-09-10T05:17:00.000Z", "COAST", 380.1]
  ],
  "count": 3,
  "done": false
}
```

`DELETE /cursor/{{cursor}}`

HTTP 200 (application/json)

```text
{"cursor": "36a80b5cca6d9384", "closed": true}
```

**HTTP: A cursor needs exactly one SELECT** (sample data: sample)

```http
POST /cursor

DELETE FROM brokers WHERE id = 1
```

Response:

HTTP 400 (application/json)

```text
{
  "query": "DELETE FROM brokers WHERE id = 1",
  "error": "a cursor needs exactly one SELECT statement",
  "sqlstate": "XX000"
}
```

<a id="get-cursor"></a>

## GET /cursor/<id>

Syntax:

```sql
GET /cursor/<id>[?fetch=N]
```

Gives the next `N` rows of the cursor. It only reads rows that are already kept, so GET is right here.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `<id>` | path | The id from `POST /cursor` | required |
| `fetch` | URL | How many rows: 1 or more, at most 1,000,000 | 1,000 |
| `db` | URL | The same database as `POST /cursor` (or the header `X-KDB-Database`) | the default database |

| Answer field | Meaning |
|---|---|
| `cursor` | The id |
| `columns[]` | `name` and `type` of each column |
| `dataset` | The rows, in the same form as [/exec](http-exec.md#get-exec) |
| `count` | Number of rows in this answer |
| `done` | `true` when no rows are left after these |

- **Status codes:** 200; 400 `fetch must be a number of rows, 1 or more`; 401/403 login or role; 404 no such cursor (closed, unused for 10 minutes, or another database).
- **Notes:** after `done` is `true`, the kept rows are freed, but the id stays until you close it (further GETs give 0 rows). Read in a loop until `done`.

**HTTP: Read until done** (sample data: sample)

```http
POST /cursor

SELECT symbol, name FROM securities ORDER BY symbol
###
GET /cursor/{{cursor}}?fetch=2
###
GET /cursor/{{cursor}}?fetch=2
###
GET /cursor/{{cursor}}?fetch=2
###
DELETE /cursor/{{cursor}}
```

Response:

`POST /cursor`

HTTP 200 (application/json)

```text
{
  "cursor": "fd81d111a57ff2e7",
  "columns": [
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "name", "type": "STRING"}
  ],
  "rows": 5
}
```

`GET /cursor/{{cursor}}?fetch=2`

HTTP 200 (application/json)

```text
{
  "cursor": "fd81d111a57ff2e7",
  "columns": [
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "name", "type": "STRING"}
  ],
  "dataset": [
    ["ACME", "Acme Investment Company"],
    ["CITY", "City Bank Limited"]
  ],
  "count": 2,
  "done": false
}
```

`GET /cursor/{{cursor}}?fetch=2`

HTTP 200 (application/json)

```text
{
  "cursor": "fd81d111a57ff2e7",
  "columns": [
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "name", "type": "STRING"}
  ],
  "dataset": [
    ["COAST", "Coastal Bank Limited"],
    ["TELCO", "Northwind Telecom Limited"]
  ],
  "count": 2,
  "done": false
}
```

`GET /cursor/{{cursor}}?fetch=2`

HTTP 200 (application/json)

```text
{
  "cursor": "fd81d111a57ff2e7",
  "columns": [
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "name", "type": "STRING"}
  ],
  "dataset": [
    ["VOLT", "Volt River Hydropower Limited"]
  ],
  "count": 1,
  "done": true
}
```

`DELETE /cursor/{{cursor}}`

HTTP 200 (application/json)

```text
{"cursor": "fd81d111a57ff2e7", "closed": true}
```

**HTTP: fetch must be 1 or more** (sample data: sample)

```http
POST /cursor

SELECT symbol FROM securities
###
GET /cursor/{{cursor}}?fetch=0
```

Response:

`POST /cursor`

HTTP 200 (application/json)

```text
{
  "cursor": "18a31579e88292de",
  "columns": [
    {"name": "symbol", "type": "SYMBOL"}
  ],
  "rows": 5
}
```

`GET /cursor/{{cursor}}?fetch=0`

HTTP 400 (application/json)

```text
{"error": "fetch must be a number of rows, 1 or more"}
```

Reading a big result in Python, 5,000 rows at a time:

```python
import requests

KarelaDB = "http://127.0.0.1:9900"
params = {"db": "market"}
c = requests.post(f"{KarelaDB}/cursor", params=params,
                  data="SELECT time, symbol, close FROM ochl_minutes ORDER BY time".encode("utf-8")).json()
if "error" in c:
    raise RuntimeError(c["error"])
print("rows:", c["rows"])
try:
    while True:
        page = requests.get(f"{KarelaDB}/cursor/{c['cursor']}", params={**params, "fetch": 5000}).json()
        for time, symbol, close in page["dataset"]:
            pass  # use the row
        if page["done"]:
            break
finally:
    requests.delete(f"{KarelaDB}/cursor/{c['cursor']}", params=params)
```

```csharp
using var http = new HttpClient { BaseAddress = new Uri("http://127.0.0.1:9900") };
var open = await http.PostAsync("/cursor?db=market", new StringContent("SELECT time, close FROM ochl_minutes ORDER BY time", Encoding.UTF8, "text/plain"));
var cursor = JsonDocument.Parse(await open.Content.ReadAsStringAsync()).RootElement.GetProperty("cursor").GetString();
try
{
    while (true)
    {
        var page = JsonDocument.Parse(await http.GetStringAsync($"/cursor/{cursor}?db=market&fetch=5000")).RootElement;
        foreach (var row in page.GetProperty("dataset").EnumerateArray()) { /* use row[0], row[1] */ }
        if (page.GetProperty("done").GetBoolean()) break;
    }
}
finally
{
    await http.DeleteAsync($"/cursor/{cursor}?db=market");
}
```

<a id="delete-cursor"></a>

## DELETE /cursor/<id>

Syntax:

```sql
DELETE /cursor/<id>
```

Closes a cursor and frees its rows.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `<id>` | path | The id from `POST /cursor` | required |
| `db` | URL | The same database as `POST /cursor` | the default database |

| Answer field | Meaning |
|---|---|
| `cursor` | The id |
| `closed` | `true` |

- **Status codes:** 200; 401/403 login or role; 404 no such cursor.
- **Notes:** a cursor you forget closes by itself after 10 minutes, but until then it uses memory and one of the 16 places.

**HTTP: After closing, the cursor is gone** (sample data: sample)

```http
POST /cursor

SELECT id, name FROM brokers
###
DELETE /cursor/{{cursor}}
###
GET /cursor/{{cursor}}
```

Response:

`POST /cursor`

HTTP 200 (application/json)

```text
{
  "cursor": "20c058b6a39b4b56",
  "columns": [
    {"name": "id", "type": "INT"},
    {"name": "name", "type": "STRING"}
  ],
  "rows": 5
}
```

`DELETE /cursor/{{cursor}}`

HTTP 200 (application/json)

```text
{"cursor": "20c058b6a39b4b56", "closed": true}
```

`GET /cursor/{{cursor}}`

HTTP 404 (application/json)

```text
{"error": "cursor '20c058b6a39b4b56' does not exist (an unused cursor closes after 10 minutes)"}
```
