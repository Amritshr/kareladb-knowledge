# Pinned queries

> Pin a SELECT so its result is always ready in the result cache - computed when the database opens, never pushed out, computed again after a write.

- Category: HTTP API
- Keywords: pin, pinned query, pinned statement, pins, keep a result ready, warm cache, preload, dashboard slow query, GET /api/pins, POST /api/pins, DELETE /api/pins, \_pinned\_queries, cache\_pinned
- See also: [Performance tips (result-cache)](performance-tips.md#result-cache), [Run SQL over HTTP (/exec, /exp)](http-exec.md), [Timers](timers.md), [Indexes (warm)](indexes.md#warm), [Monitor panel (memory, processor, caches)](console-monitor.md)

A **pinned query** is a `SELECT` the server keeps ready. Pin the slow question a dashboard asks on every load, and from then on every request for it is answered from the [result cache](performance-tips.md#result-cache):

- It is computed **when the database opens**, right after the indexes are [built at open](indexes.md#warm), before anyone asks.
- It is **never pushed out** of the result cache by other results, and it may take up to **three quarters** of the cache (an ordinary result is kept only up to a quarter).
- After a **write** to a table it reads, the server computes it again by itself once the database has been quiet for half a second, so the next request finds it fresh. On a database that is written all the time and is never quiet, it does so at the latest two seconds after the first write that made the result old. A request that comes before that computes it, as any query would.
- Pins are saved in the table `_pinned_queries` of the hidden `_system` database (like [timers](timers.md)), or of the served database when `kareladb serve` runs on one folder, so they survive restarts and are part of every backup.

The rules of the cache still apply: the statement must be one cacheable `SELECT` of this database (no `now()`, no random functions, no other database), and the **row limit is part of the key**: pin it with the `max_rows` the requests use (`/exec` sends 10,000 unless `limit=` says otherwise; the console sends 10,000).

A pin is saved code that later runs by itself, without a rights check: only a server **admin** can pin or unpin, and every change is written to the [audit log](audit-log.md) (event `pin`).

Pins are a feature of `kareladb serve`. A server started without them answers `/api/pins` with 404.

<a id="get-api-pins"></a>

## GET /api/pins

Syntax:

```sql
GET /api/pins[?db=<name>]
```

The pins of one database (the default database without `db=`). Needs read rights on the database.

| Field | Meaning |
|---|---|
| `database`, `sql`, `max_rows`, `enabled` | the pin as saved |
| `created_ms`, `created_by` | when it was saved and by whom; empty = the token |
| `open` | the database is open now; the fields below are live only then |
| `cached`, `cached_bytes` | its result is in the cache right now, and its size |
| `last_run_ms`, `last_ok`, `last_error` | the last time the server computed it by itself (at open, or after a write); `last_ok` is `null` before the first |
| `error` | why the database refused the pin when it was applied (a column that no longer exists, for example); empty when it took it |

`now_ms` at the top is the server's clock. `GET /api/stats` shows `cache_pinned` per database: how many pinned results are in the cache now.

<a id="post-api-pins"></a>

## POST /api/pins

Syntax:

```sql
POST /api/pins[?db=<name>]
Content-Type: application/json

{"sql": "SELECT ...", "max_rows": 10000, "enabled": true}
```

Pins a statement, or replaces the pin with the same SQL. Returns the pin.

| Field | Meaning |
|---|---|
| `sql` | one `SELECT`, at most 64 KB |
| `max_rows` | optional, 1 to 1,000,000 (default 10,000): the row limit the requests use |
| `enabled` | optional (default `true`); `false` keeps the pin saved without applying it |

A statement that is not one `SELECT`, does not parse, or reads another database is a 400 that says so. So is a `max_rows` out of range.

**HTTP: Pin the totals a dashboard shows on every load**

Setup:

```text
CREATE TABLE trades (id LONG PRIMARY KEY, symbol SYMBOL, qty LONG, price DOUBLE);
INSERT INTO trades VALUES (1, 'CITY', 100, 510.5), (2, 'CITY', 50, 512), (3, 'VOLT', 200, 301);
```

```http
POST /api/pins
Content-Type: application/json

{"sql": "SELECT symbol, sum(qty) AS qty, sum(qty * price) AS amount FROM trades GROUP BY symbol ORDER BY symbol"}
###
GET /api/pins
```

Response:

`POST /api/pins`

HTTP 200 (application/json)

```text
{
  "database": "demo",
  "sql": "SELECT symbol, sum(qty) AS qty, sum(qty * price) AS amount FROM trades GROUP BY symbol ORDER BY symbol",
  "max_rows": 10000,
  "enabled": true,
  "created_ms": 1792666991228,
  "created_by": "",
  "open": true,
  "cached": false,
  "cached_bytes": 0,
  "last_run_ms": 1792666991228,
  "last_ok": true,
  "last_error": "",
  "error": ""
}
```

`GET /api/pins`

HTTP 200 (application/json)

```text
{
  "now_ms": 1792666991280,
  "pins": [
    {
      "database": "demo",
      "sql": "SELECT symbol, sum(qty) AS qty, sum(qty * price) AS amount FROM trades GROUP BY symbol ORDER BY symbol",
      "max_rows": 10000,
      "enabled": true,
      "created_ms": 1792666991228,
      "created_by": "",
      "open": true,
      "cached": false,
      "cached_bytes": 0,
      "last_run_ms": 1792666991228,
      "last_ok": true,
      "last_error": "",
      "error": ""
    }
  ]
}
```

**HTTP: Only one SELECT can be pinned**

```http
POST /api/pins
Content-Type: application/json

{"sql": "DELETE FROM trades"}
```

Response:

HTTP 400 (application/json)

```text
{"error": "a pinned statement is one SELECT"}
```

<a id="delete-api-pins"></a>

## DELETE /api/pins

Syntax:

```sql
DELETE /api/pins[?db=<name>]
Content-Type: application/json

{"sql": "SELECT ..."}
```

Removes the pin with that SQL (also `?sql=<url-encoded SQL>`). Returns `{"deleted": true}`. Its cached result stays until the cache needs the room, like any other. An unknown pin is a 404; a request without the SQL is a 400.

**HTTP: Unpin it**

Setup:

```text
CREATE TABLE trades (id LONG PRIMARY KEY, symbol SYMBOL, qty LONG);
```

```http
POST /api/pins
Content-Type: application/json

{"sql": "SELECT symbol, sum(qty) FROM trades GROUP BY symbol"}
###
DELETE /api/pins
Content-Type: application/json

{"sql": "SELECT symbol, sum(qty) FROM trades GROUP BY symbol"}
```

Response:

`POST /api/pins`

HTTP 200 (application/json)

```text
{
  "database": "demo",
  "sql": "SELECT symbol, sum(qty) FROM trades GROUP BY symbol",
  "max_rows": 10000,
  "enabled": true,
  "created_ms": 1792666991280,
  "created_by": "",
  "open": true,
  "cached": false,
  "cached_bytes": 0,
  "last_run_ms": 1792666991281,
  "last_ok": true,
  "last_error": "",
  "error": ""
}
```

`DELETE /api/pins`

HTTP 200 (application/json)

```text
{"deleted": true}
```
