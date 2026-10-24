# HTTP API overview

> How to talk to kareladb serve over HTTP - the address, choosing the database, JSON answers, errors, safety rules and limits.

- Category: HTTP API
- Keywords: HTTP, API, REST, Idempotency-Key, idempotent, retry, Idempotent-Replayed, 422, route, URL, base URL, port 9900, X-KDB-Database, db, JSON, error, status code, 304, 404, 405, 413, 431, 408, 501, 503, 507, disk full, CORS, OPTIONS, HEAD, Cache-Control, ETag, gzip, Content-Encoding, Accept-Encoding, compressed answers, --http-gzip, KARELADB\_HTTP\_GZIP, Vary, worker threads, poller, curl, Invoke-RestMethod, fetch, requests, web console, help page
- See also: [Run SQL over HTTP (/exec, /exp)](http-exec.md), [Logins, tokens and roles over HTTP](http-login.md), [Databases over HTTP (/api/databases)](http-databases.md), [Health, info, check and backup over HTTP](http-server-info.md), [Line protocol (POST /write)](line-protocol.md), [Keeping kareladb serve safe](server-security.md), [kareladb serve](cli-serve.md), [Limits](limits.md)

`kareladb serve` starts a small web server. Programs send it **HTTP requests** (the messages a browser or `curl` sends) and get **JSON** answers (text like `{"name": "value"}` that every language can read).

- A **route** is a method and a path, like `POST /exec`. The method says what you want: `GET` reads, `POST` changes or runs something, `DELETE` removes.
- The address is `http://127.0.0.1:9900` by default. `--port` and `--bind` of [kareladb serve](cli-serve.md) change it.
- The same server also gives the [web console](web-console.md) (`GET /`) and the [PostgreSQL port](postgres-protocol.md).

Tutorial: [chapter 8, HTTP API](../tutorial/08-http-api.md).

<a id="routes"></a>

## All routes

| Method and path | What it does | Help |
|---|---|---|
| `GET /health` | Is the server alive? | [GET /health](http-server-info.md#get-health) |
| `GET /exec?query=SQL` | Run SQL that only reads | [GET /exec](http-exec.md#get-exec) |
| `POST /exec` | Run any SQL | [POST /exec](http-exec.md#post-exec) |
| `GET /exp`, `POST /exp` | Run a SELECT, answer as a CSV file | [GET /exp](http-exec.md#get-exp) |
| `GET /v/<name>?param=value` | Run a saved query with its parameters (CREATE ENDPOINT) | [endpoints](http-endpoints.md) |
| `POST /write`, `POST /api/v2/write` | Load rows in the InfluxDB line format | [line protocol](line-protocol.md) |
| `POST /imp` | Load a CSV file into a table | [POST /imp](http-import.md#post-imp) |
| `DELETE /exec/<id>` | Stop a running statement | [DELETE /exec/<id>](protection.md#delete-exec) |
| `GET /api/info` | Tables, columns, sizes, damage, last backup | [GET /api/info](http-server-info.md#get-api-info) |
| `GET /api/disk` | What a database takes on disk, part by part | [GET /api/disk](http-server-info.md#api-disk) |
| `GET /api/rev` | Committed revision of a table and of each symbol: poll it, read again only on a change | [GET /api/rev](revisions.md#api-rev) |
| `GET /api/changes` | Every committed change of a table after an LSN, in order (server-sent events or JSON) | [GET /api/changes](change-stream.md#api-changes) |
| `GET /api/subscribe` | A live query: its answer, then the rows each commit changed | [GET /api/subscribe](change-stream.md#api-subscribe) |
| `POST /api/check` | Read every file and look for damage | [POST /api/check](http-server-info.md#post-api-check) |
| `POST /api/backup`, `GET /api/backups` | Make a backup, list backups | [POST /api/backup](http-server-info.md#post-api-backup) |
| `GET /api/trigger-queue` | Queues of deferred triggers, and a wait for their jobs | [GET /api/trigger-queue](http-server-info.md#api-trigger-queue) |
| `GET /api/stats` | Memory, processor, running statements, open databases | [GET /api/stats](http-server-info.md#api-stats) |
| `GET /api/settings`, `POST /api/settings`, `POST /api/restart` | The data folder and other saved settings; restart in place | [GET /api/settings](http-server-info.md#api-settings) |
| `GET /api/activity` | Recent server events for the console's activity panel | [activity](console-monitor.md#activity) |
| `GET /api/audit` | The audit log | [GET /api/audit](audit-log.md#api-audit) |
| `GET /api/timers`, `POST /api/timers`, `POST /api/timers/<name>/...` | SQL that runs on a schedule (admins) | [timers](timers.md) |
| `GET /api/pins`, `POST /api/pins`, `DELETE /api/pins` | Statements whose results are kept ready (admins) | [pinned queries](pinned-queries.md) |
| `GET /api/databases`, `POST /api/databases`, `DELETE /api/databases/<name>` | List, create and drop databases | [databases](http-databases.md) |
| `POST /session`, `DELETE /session/<id>` | A transaction over many requests | [sessions](http-sessions-and-cursors.md#post-session) |
| `POST /cursor`, `GET /cursor/<id>`, `DELETE /cursor/<id>` | Read a big result a part at a time | [cursors](http-sessions-and-cursors.md#post-cursor) |
| `POST /api/login`, `POST /api/logout`, `GET /api/me` | Log in and out, who am I | [logins](http-login.md) |
| `POST /api/feedback`, `GET /api/feedback`, `POST /api/feedback/<id>` | Send comments and suggestions; admins read and mark them | [comments and suggestions](feedback.md) |
| `GET /` | The web console | [GET /](http-overview.md#get) |
| `GET /help` | This help page | [GET /help](http-overview.md#get-help) |
| `GET /skill.md` | The Claude skill file | [GET /skill.md](http-overview.md#get-skill) |

Every `GET` route also answers `HEAD`: the same answer without the body.

<a id="database"></a>

## Choosing the database

One server can serve many databases. Each request picks **one**:

Syntax:

```sql
/exec?db=<name>            (a URL parameter, or a form field db=)
X-KDB-Database: <name>     (a header)
```

| Where | Meaning | Default |
|---|---|---|
| `db=<name>` | The database of this request. Wins when both are given. | - |
| `X-KDB-Database: <name>` | The same as a **header** (an extra line of the request). Handy when a program always uses one database. | - |
| neither | The server's default database: `--db <name>` of `kareladb serve`, else `default` (made when it is first used). | `default` |

- Names ignore case: `MARKET` and `market` are the same database.
- A server started for one folder (`kareladb serve D:\kdb\market`) has only that database.
- A database that does not exist gives **HTTP 404**.
- `GET /health` and `GET /api/databases` do not use a database.
- `USE other;` inside the SQL changes the database only for the rest of that one request.

**HTTP: The same database with db= and with the header** (sample data: sample)

```http
GET /exec?db=demo&compat=0&query=SELECT count(*) AS securities FROM securities
###
POST /exec?compat=0
X-KDB-Database: demo

SELECT symbol, name FROM securities ORDER BY symbol LIMIT 2
```

Response:

`GET /exec?db=demo&compat=0&query=SELECT count(*) AS securities FROM securities`

HTTP 200 (application/json)

```text
{
  "query": "SELECT count(*) AS securities FROM securities",
  "results": [
    {
      "statement": "SELECT count(*) AS securities FROM securities",
      "columns": [
        {"name": "securities", "type": "LONG"}
      ],
      "dataset": [
        [5]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 25, "execute_us": 66}
    }
  ],
  "timings": {"parse_us": 25, "execute_us": 66}
}
```

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "SELECT symbol, name FROM securities ORDER BY symbol LIMIT 2",
  "results": [
    {
      "statement": "SELECT symbol, name FROM securities ORDER BY symbol LIMIT 2",
      "columns": [
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "name", "type": "STRING"}
      ],
      "dataset": [
        ["ACME", "Acme Investment Company"],
        ["CITY", "City Bank Limited"]
      ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 40, "execute_us": 183}
    }
  ],
  "timings": {"parse_us": 40, "execute_us": 183}
}
```

**HTTP: A database that does not exist**

```http
GET /exec?db=no_such_db&query=SELECT 1
```

Response:

HTTP 404 (application/json)

```text
{"error": "database 'no_such_db' does not exist; create it with CREATE DATABASE no_such_db"}
```

<a id="answers"></a>

## Answers and errors

Every answer (except CSV files, the console page and `204`) is JSON with `Content-Type: application/json; charset=utf-8`.

A **status code** is the number at the start of every HTTP answer. `200` means OK. `400` and more means an error.

| Status | Meaning |
|---|---|
| `200` | OK |
| `204` | OK, no body (the [line protocol](line-protocol.md) answers this) |
| `304` | Not modified: the `If-None-Match` tag of `/exec`, or the browser's copy of a console or help file, is still current. No body. |
| `400` | The request or the SQL is wrong |
| `401` | A login or token is needed, or it is wrong ([logins](http-login.md)) |
| `403` | Refused: a cross-site request, a role that is too weak, or a host name that is not allowed |
| `404` | No such route, database, cursor or session |
| `405` | Wrong method: for example `GET /exec` with SQL that changes data, or `PUT` anywhere |
| `408` | The request did not arrive within 30 seconds, or a statement ran past the statement timeout |
| `409` | The database already exists, or is in use; or a [retried request](#idempotency-key) whose first answer was too big to keep |
| `422` | An [Idempotency-Key](#idempotency-key) used again for a different request |
| `413` | The body is bigger than 64 MB, or a statement passed a memory limit |
| `429` | Too many failed logins, too many statements at once, or over a [rate limit](protection.md#rate-limits): wait (see the `Retry-After` header) |
| `431` | The headers are bigger than 64 KB |
| `500` | Trouble on the server: a damaged file, a database locked by another program |
| `501` | A chunked body (`Transfer-Encoding: chunked`): send `Content-Length` instead |
| `503` | Busy: another transaction held the lock too long, or too many sessions. Also every new request while the server is **stopping**, with `Retry-After: 2` ([stopping](cli-serve.md#stop)). |
| `507` | The disk is full: nothing of the request was saved. It works again once space is freed. `/write` answers `{"code": "disk full", ...}`. |

An error answer has an `error` text. `/exec` adds `query`, the `results` of the statements that ran before the error, and `line` and `column` when KarelaDB knows the place:

**HTTP: An error with its position** (sample data: sample; shows an error)

```http
POST /exec?compat=0

SELECT clsoe FROM ochl_day
```

Response:

HTTP 400 (application/json)

```text
{
  "query": "SELECT clsoe FROM ochl_day",
  "results": [],
  "saved": 0,
  "rolled_back": false,
  "error": "line 1, column 8: unknown column 'clsoe' (table 'ochl_day' has: time symbol open high low close volume)",
  "sqlstate": "42703",
  "line": 1,
  "column": 8
}
```

**HTTP: A route that does not exist**

```http
GET /nothing-here
```

Response:

HTTP 404 (application/json)

```text
{"error": "not found"}
```

**HTTP: A method the route does not have**

```http
PUT /exec

SELECT 1
```

Response:

HTTP 405 (application/json)

```text
{"error": "method PUT is not allowed here"}
```

- **Notes:** a `405` answer has an `Allow` header with the methods the path has (here `GET, POST`). The [line protocol](line-protocol.md) has its own error shape: `{"code", "message", "line", "errorId"}`.

<a id="get-post"></a>

## GET reads, POST changes

`GET /exec` and `GET /exp` only run SQL that **reads**: `SELECT`, `SHOW ...`, `EXPLAIN`, `CHECK TABLE`, `USE`. SQL that changes something must be sent with `POST`. The answer to a GET that changes data is **405**. A GET also runs as a read-only transaction, so a `SELECT` that would change something is refused the same way: `nextval()` and `setval()`, a `WITH d AS (DELETE ... RETURNING *)`, a function that writes, `kv_set()`. `SUBSCRIBE` and `/exp` follow the same rule.

Why: a link or a picture on any web page can make your browser send a GET. So a bad page must not be able to change your data with a GET.

**HTTP: DELETE with GET is refused** (sample data: sample)

```http
GET /exec?query=DELETE FROM brokers WHERE id = 1
```

Response:

HTTP 405 (application/json)

```text
{"error": "this SQL changes data, so it must be sent with POST /exec (GET /exec only reads)"}
```

More in [GET /exec](http-exec.md#get-exec).

<a id="idempotency-key"></a>

## Retrying safely: Idempotency-Key

A client that sends a write and loses the answer (a timeout, a dropped connection) cannot know whether the write happened. Sent again, it might write twice. Give the request an **`Idempotency-Key`** header, any text you choose (up to 255 characters), and send the retry with the same key: KarelaDB answers it with the first answer and does not run it again.

**HTTP: The same key twice: one row, the second answer is the first** (sample data: sample)

```http
POST /exec?compat=0

CREATE TABLE idem_orders (id INT PRIMARY KEY, note STRING)
###
POST /exec?compat=0
Idempotency-Key: order-1001

INSERT INTO idem_orders VALUES (1, 'first')
###
POST /exec?compat=0
Idempotency-Key: order-1001

INSERT INTO idem_orders VALUES (1, 'first')
###
GET /exec?query=SELECT count(*) FROM idem_orders
```

Response:

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "CREATE TABLE idem_orders (id INT PRIMARY KEY, note STRING)",
  "results": [
    {
      "statement": "CREATE TABLE idem_orders (\n  id INT PRIMARY KEY,\n  note STRING\n)",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "table 'idem_orders' created",
      "timings": {"parse_us": 23, "execute_us": 1847}
    }
  ],
  "timings": {"parse_us": 23, "execute_us": 1847}
}
```

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "INSERT INTO idem_orders VALUES (1, 'first')",
  "results": [
    {
      "statement": "INSERT INTO idem_orders VALUES (1, 'first')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 23, "execute_us": 36}
    }
  ],
  "timings": {"parse_us": 23, "execute_us": 36}
}
```

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "INSERT INTO idem_orders VALUES (1, 'first')",
  "results": [
    {
      "statement": "INSERT INTO idem_orders VALUES (1, 'first')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 23, "execute_us": 36}
    }
  ],
  "timings": {"parse_us": 23, "execute_us": 36}
}
```

`GET /exec?query=SELECT count(*) FROM idem_orders`

HTTP 200 (application/json)

```text
{
  "query": "SELECT count(*) FROM idem_orders",
  "results": [
    {
      "statement": "SELECT count(*) FROM idem_orders",
      "columns": [
        {"name": "count(*)", "type": "LONG"}
      ],
      "dataset": [
        [1]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 38, "execute_us": 141}
    }
  ],
  "columns": [
    {"name": "count(*)", "type": "LONG"}
  ],
  "dataset": [
    [1]
  ],
  "count": 1,
  "timings": {"parse_us": 38, "execute_us": 141}
}
```

| Case | Answer |
|---|---|
| the same key and the same request again | the first answer, with the header `Idempotent-Replayed: true` |
| the same key while the first request still runs | waits for it, then its answer |
| the same key with a different request (another body or query string) | `422`: a new request needs a new key |
| the first answer was over 1 MB (a big `SELECT`) | `409`: it was done already, the answer was not kept |
| the first answer was `500` or more (busy, stopping) | not kept: the retry runs for real |

- **Where:** `POST /exec`, `POST /write`, `POST /api/v2/write` and `POST /imp`. A request without the header runs as always.
- **Whose:** a key belongs to the user (or token) and the database (`?db=`), so two users never share one.
- **How long:** keys are kept 24 hours, in memory, at most 64 MB of answers (the oldest go first). A restart forgets them.

<a id="auth"></a>

## Logins, tokens and cookies in short

| Server | What a request needs |
|---|---|
| `kareladb serve` on `127.0.0.1`, no `--token`, no users | Nothing. Only programs on the same computer can connect. |
| started with `--token <secret>` | `Authorization: Bearer <secret>`, or the cookie `kdb_auth` that `POST /api/session` sets |
| the data folder has users | a user name and password (HTTP Basic), or a login token from `POST /api/login` (as `Authorization: Bearer <token>` or the cookie `kdb_login`) |

- A **token** is a secret text that works like a password. A **cookie** is a small value the browser keeps and sends back by itself.
- `GET /health`, `POST /api/login`, `POST /api/session`, `POST /api/logout` and the console files need no login.
- A change sent with a cookie also needs the header `X-KDB-CSRF` ([CSRF](http-login.md#csrf)).
- Without a login you get **401**. With a login but a weak role you get **403**.

Everything about this: [logins, tokens and roles](http-login.md) and [server security](server-security.md).

<a id="safety"></a>

## Safety rules

The server refuses requests that a web page in your browser could send behind your back:

| Rule | Answer |
|---|---|
| The browser says the request comes from another site (header `Sec-Fetch-Site: cross-site` or `same-site`) | 403 `cross-site requests are not allowed` |
| Without a login: an `Origin` header that is not this server | 403 `cross-origin requests are not allowed` |
| Without `--token`: a `Host` that is not `localhost` or `127.x.x.x` (stops "DNS rebinding") | 403 `host name '...' is not allowed without an access token` |
| `kareladb serve --bind 0.0.0.0` without `--token` and without users | the server does not start |

Programs like `curl`, Python, Go, Node and C# do not send these headers, so they are not affected.

**HTTP: A request a browser marks as cross-site**

```http
GET /exec?query=SELECT 1
Sec-Fetch-Site: cross-site
```

Response:

HTTP 403 (application/json)

```text
{"error": "cross-site requests are not allowed"}
```

**HTTP: An Origin header from another site**

```http
GET /exec?query=SELECT 1
Origin: http://example.com
```

Response:

HTTP 403 (application/json)

```text
{"error": "cross-origin requests are not allowed"}
```

<a id="cors"></a>

## CORS

**CORS** is how a server allows JavaScript on *other* web sites to call it. KarelaDB sends **no** CORS headers, and `OPTIONS` requests get 405. So JavaScript in a page of another site cannot call KarelaDB. This is on purpose.

Call KarelaDB from your **backend** (your Go, Node, Python or C# server), not from browser code. The [web console](web-console.md) works because it is served by KarelaDB itself.

**HTTP: A browser's CORS check (OPTIONS) is not answered**

```http
OPTIONS /exec
```

Response:

HTTP 405 (application/json)

```text
{"error": "method OPTIONS is not allowed here"}
```

<a id="limits"></a>

## Limits

| Limit | Value | When it is passed |
|---|---|---|
| Request body | 64 MB; a gzip or deflate body (`Content-Encoding: gzip`) is unpacked first and counts unpacked | 413 `request body is too large` (`... once decompressed`) |
| Request headers | 64 KB | 431 `request headers are too large` |
| Time to send one request | 30 seconds | 408 |
| Idle keep-alive connection | answers say `Keep-Alive: timeout=30`; the server closes it after 35 seconds, so a request sent right at 30 seconds still finds it open | - |
| Chunked request bodies | not supported | 501 |
| Rows per statement (`limit=`) | `/exec`: 10,000 by default; `/exp`: 1,000,000; at most 1,000,000 | `"truncated": true` |
| SQL echoed back in `query` | the first 4,096 bytes | the rest is cut |
| HTTP threads | one poller thread, and a pool of workers: one per CPU thread, at least 8 (`kareladb serve --http-threads N`) | more requests wait for a free worker |
| Open sessions (`POST /session`) | 1,000; idle ones close after 10 minutes | 503 |
| Open cursors (`POST /cursor`) | 16 per database; idle ones close after 10 minutes | error |

- **Threads:** the poller accepts connections and watches the idle keep-alive ones. A worker reads, runs and answers one request at a time. An idle connection holds no worker, so a browser that keeps six connections open cannot block other clients. As many requests run at once as there are workers (`--http-threads`, by default the CPU threads and at least 8); the next ones wait in line.
- **Compressed bodies:** `POST /exec`, `POST /write` and `POST /imp` take a body sent with `Content-Encoding: gzip` (or `deflate`). A damaged one is a 400.

<a id="gzip-answers"></a>

### Compressed answers

A client that sends `Accept-Encoding: gzip` gets answers of 2 KB or more compressed: JSON from `/exec`, CSV from `/exp`, and the console's files. The answer then has `Content-Encoding: gzip`. Browsers, Go's `net/http`, Python `requests`, Node's `fetch` and `curl --compressed` send the header and unpack the answer by themselves, so nothing changes in your code - only fewer bytes travel (a 500-bar chart: 31 KB becomes about 7 KB).

| `kareladb serve --http-gzip` | Who gets compressed answers |
|---|---|
| `remote` (the default) | clients beyond this computer and its private networks (the internet, another site). A client on the same computer (`127.x`), on the same LAN (`10.x`, `172.16-31.x`, `192.168.x`) or in another container on this computer (Docker's bridge, `172.17.x`) gets plain answers: there the bytes arrive in less time than compressing them takes (a 10,000-row answer: 5-7 ms to compress, under a millisecond to send). |
| `on` | every client that asks |
| `off` | nobody |

- Answers that may come compressed have `Vary: Accept-Encoding`.
- A compressed answer carries its `ETag` as a weak tag (`W/"..."`). Send either form back in `If-None-Match`: both get the 304.
- The rows of a result from the [result cache](performance-tips.md#result-cache) are compressed once and kept, so a repeated chart read costs almost nothing more.
- `HEAD` requests and answers under 2 KB are never compressed. Also `KARELADB_HTTP_GZIP`.
- A [LISTEN stream](listen-notify.md#listen-http) (`GET /listen`, `text/event-stream`) is never compressed either: each notification must reach the client the moment it is sent.

API answers have `Cache-Control: no-store`, so no browser or proxy keeps a copy. The server prints one line per request, for example `2026-09-11 23:04:12  GET /health 200 0 ms`.

More limits: [Limits](limits.md).

<a id="clients"></a>

## Clients

Any HTTP client works. The same query from five languages (all send the SQL as the body of `POST /exec`):

```bash
curl -s "http://127.0.0.1:9900/exec?compat=0" --data-binary "SELECT symbol, close FROM ochl_day LIMIT 2"
```

```powershell
$r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:9900/exec?compat=0" `
  -ContentType "text/plain; charset=utf-8" -Body "SELECT symbol, close FROM ochl_day LIMIT 2"
$r.results[0].dataset | ForEach-Object { $_ -join " | " }
```

```python
import requests

r = requests.post("http://127.0.0.1:9900/exec", params={"compat": 0},
                  data="SELECT symbol, close FROM ochl_day LIMIT 2".encode("utf-8"),
                  headers={"Content-Type": "text/plain; charset=utf-8"})
body = r.json()
if r.status_code != 200:
    raise RuntimeError(body["error"])
print(body["results"][0]["dataset"])
```

```js
const res = await fetch("http://127.0.0.1:9900/exec?compat=0", {
  method: "POST",
  headers: { "Content-Type": "text/plain; charset=utf-8" },
  body: "SELECT symbol, close FROM ochl_day LIMIT 2",
});
const body = await res.json();
if (!res.ok) throw new Error(body.error);
console.log(body.results[0].dataset);
```

```csharp
using var http = new HttpClient();
var content = new StringContent("SELECT symbol, close FROM ochl_day LIMIT 2", Encoding.UTF8, "text/plain");
var res = await http.PostAsync("http://127.0.0.1:9900/exec?compat=0", content);
var json = JsonDocument.Parse(await res.Content.ReadAsStringAsync()).RootElement;
if (!res.IsSuccessStatusCode) throw new Exception(json.GetProperty("error").GetString());
Console.WriteLine(json.GetProperty("results")[0].GetProperty("dataset"));
```

On Windows PowerShell, write `curl.exe`, not `curl` (`curl` alone is another command there). These snippets are not run by the help build; [chapter 8](../tutorial/08-http-api.md) has tested clients with their real output.

<a id="get"></a>

## GET /

Syntax:

```sql
GET /
```

The [web console](web-console.md): a page for running SQL in the browser. Its files (`/index.html`, `/app.js`, `/logic.js`, `/style.css`, ...) are the `web` folder next to the program, not part of `kareladb.exe`, so it needs no internet and a new console needs no new program ([where kareladb finds it](install-packages.md#folders)).

| Answer | Meaning |
|---|---|
| `Content-Type: text/html; charset=utf-8` | an HTML page |
| `Content-Security-Policy`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer` | the page loads nothing from other sites and cannot be put inside another site's page |

- **Status codes:** 200; 304 when the browser's copy of a file is still current; 404 with a short page when the console files are not installed (it lists the folders KarelaDB looked in).
- **Notes:** the page itself needs no login; the console asks for the login or token when it calls the API. Open it at `http://127.0.0.1:9900/`.

**HTTP: Is the console there? (HEAD: the headers only)**

```http
HEAD /
```

Response:

HTTP 200 (text/html)

<a id="get-help"></a>

## GET /help, GET /help/

Syntax:

```sql
GET /help
GET /help/
```

This help, served by `kareladb serve`. Open `http://127.0.0.1:9900/help/` in a browser. In the web console, the **Help** menu and **F1** open it too ([web console](web-console.md#help-menu)).

The help is **not inside the kareladb program**. It is a folder of pages: `index.html` with the search, one page per topic, and `help.css`, `help.js`, `help-index.js`, `search-text.js`. `kareladb serve` sends the files of that folder. It looks for the folder here, and the first one found wins:

| Where | Example |
|---|---|
| `help_dir` in `kareladb.conf` | `"help_dir": "D:/kdb/help"` |
| the `KARELADB_HELP_DIR` environment variable | `KARELADB_HELP_DIR=/usr/local/share/kareladb/help` |
| a `help` folder next to the program | `C:\Programs\kareladb\help\` |
| `../share/kareladb/help` from the program folder | `/usr/local/bin/kareladb` uses `/usr/local/share/kareladb/help` |
| in a KarelaDB source folder, for a kareladb run from `build/bin` | `docs/help/site/` |

| Answer | Meaning |
|---|---|
| `GET /help` | `302` to `/help/`, so the links between pages work |
| `GET /help/`, `GET /help/<file>` | the home page, or one file of the folder |
| `Content-Security-Policy`, `X-Frame-Options: SAMEORIGIN` | the pages load nothing from other sites; only KarelaDB's own console may show them inside a frame |

- **Status codes:** 200; 302 for `/help`; 304 when the browser's copy is still current; 404 when the file is not there, or when no help folder is installed (the page then says so and how to build it).
- **Notes:** the help is made from `docs/help/topics/*.md` by `node tools/help/build_help.mjs`, which writes `docs/help/site/`. Changing the help does not need a new kareladb program: build the help, then copy the folder next to kareladb (the Docker image copies it when it is built). The pages need no internet and no login, and also work opened from disk.

```bash
curl -s http://127.0.0.1:9900/help/ -o kdb-help.html
```

**HTTP: The help home page**

```http
HEAD /help/
```

Response:

HTTP 200 (text/html)

<a id="get-skill"></a>

## GET /skill.md

Syntax:

```sql
GET /skill.md
```

The [Claude skill](install-packages.md#skill): one markdown file that tells an AI assistant in another project how to use KarelaDB. It is `skill/skill.md` next to the program (`.claude/skills/kareladb/SKILL.md` in the source), the same file `kareladb skill` prints.

| Answer | Meaning |
|---|---|
| `Content-Type: text/markdown; charset=utf-8` | the skill as plain markdown |

- **Status codes:** 200; 404 with a plain-text message when the skill file is not installed.
- **Notes:** it needs no login and holds no token. `kareladb skill install` adds this machine's address and token to its own copy.

```bash
mkdir -p ~/.claude/skills/kareladb
curl -s http://127.0.0.1:9900/skill.md -o ~/.claude/skills/kareladb/SKILL.md
```

**HTTP: Is the skill there? (HEAD: the headers only)**

```http
HEAD /skill.md
```

Response:

HTTP 200 (text/markdown)
