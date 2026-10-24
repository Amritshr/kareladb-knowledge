# Line protocol (POST /write)

> Load many rows fast with the InfluxDB line format over HTTP - one line per row, answered with 204.

- Category: Writing data
- Keywords: line protocol, ILP, InfluxDB, auto-create, create table from lines, ilp\_auto\_create, KARELADB\_ILP\_AUTO\_CREATE, influx, /write, /api/v2/write, precision, nanoseconds, seconds, milliseconds, 1970, timestamps look like seconds, tag, field, measurement, ticks, live feed, bulk load, 204, 503, 507, disk full, table is busy, errorId, QuestDB ILP, upsert, upsert, merge, partial update, 3i, integer suffix, t suffix, Telegraf
- See also: [INSERT](insert.md), [Loading many rows](loading-data.md), [Triggers](triggers.md), [HTTP API overview](http-overview.md), [CREATE TABLE](create-table.md), [Performance tips](performance-tips.md), [Grafana and Prometheus](grafana.md)

The **line protocol** is a very short text format for rows, made by InfluxDB and used by QuestDB. Each line is one row. It is faster to make and to read than `INSERT` statements, so it is good for live feeds (market ticks or sensor readings every second) and big loads.

```text
live_data,symbol=CITY ltp=528.5,ltv=120i,volume=45120i 1789103700000000000
```

- Send the lines as the body of `POST /write`. A good request answers **204** (OK, no body).
- A table that is not there is **made from the lines**, as QuestDB does ([new tables](#new-tables)). Columns of a table that is there must already exist: add them with [ALTER TABLE](alter-table.md).
- All lines of one request are written together, as one transaction: all or nothing.

For a few rows, or rows that need SQL, use [INSERT](insert.md) with [POST /exec](http-exec.md#post-exec). More ways to load data: [loading data](loading-data.md).

<a id="format"></a>

## Line format

Syntax:

```sql
<table>[,<tag>=<text>...] <field>=<value>[,<field>=<value>...] [<timestamp>]
```

| Part | Meaning |
|---|---|
| `<table>` | The table name (called the "measurement" in InfluxDB). Case is ignored. |
| `,<tag>=<text>` | A text value for a `SYMBOL` or `STRING` column, with no quotes. Tags come before the first space. |
| ` <field>=<value>` | A value for any column. Fields come after the first space, separated by commas. At least one field is needed. |
| ` <timestamp>` | A whole number: the time for the table's time column (the `TIMESERIES(...)` column). In nanoseconds unless `precision=` says otherwise (see [the wrong unit](#wrong-unit)). Without it, the server's clock is used. |

Field values:

| Written | Kind | Goes into columns of type |
|---|---|---|
| `512.4`, `-3`, `1e6` | a decimal number | `DOUBLE`, `FLOAT`, `DECIMAL` |
| `120i` | a whole number (`i` at the end) | `INT`, `LONG`, `SHORT`, `BYTE`, and also `DOUBLE`, `DECIMAL` |
| `120u` | a whole number without sign (`u`), up to 2^63-1 | the same as `i` |
| `"text"` | text in double quotes | `STRING`, `SYMBOL`, `JSON`, `BYTES`, and any other type that can read that text (like `INSERT` does: `"2026-09-11"` for a `DATE`) |
| `t`, `true`, `f`, `false` (also `T`, `True`, `TRUE`, ...) | a boolean | `BOOL` |
| `1789103700000000t` | a time in **microseconds** (`t` at the end, as QuestDB writes it). **Only** microseconds: see [the wrong unit](#wrong-unit) | `TIMESTAMP`, `DATE` |

Rules for writing lines:

- A space, a comma or `=` inside a table name, tag name or tag value is written with a backslash: `\ `, `\,`, `\=`.
- In a `"text"` value, write `\"` for a quote and `\\` for a backslash. Text may hold commas, spaces and even line breaks.
- Empty lines and lines starting with `#` are skipped. Lines may end with `\n` or `\r\n`.
- Columns not in a line get their `DEFAULT`, or NULL.
- A decimal number like `5.0` cannot go into an `INT` or `LONG` column: write `5i`.
- The time column itself cannot be a field: send its value as the line's timestamp.
- KarelaDB keeps times in milliseconds. Finer parts (microseconds, nanoseconds) are cut off.
- `precision=` is only for the timestamp at the **end** of the line. A `TIMESTAMP` field always needs microseconds and `t`.

<a id="wrong-unit"></a>

## Times in the wrong unit

A time in the wrong unit is the easiest way to load wrong data: `1757750400` read as nanoseconds is 1.7 seconds after midnight on 1 January 1970. KarelaDB **refuses** such a request with 400 and says how to fix it. Nothing of the request is written.

| You send | KarelaDB answers |
|---|---|
| No `precision=`, and **every** line timestamp is before 1990 as nanoseconds, while one of them is a 1990-2200 time in seconds, milliseconds or microseconds | 400 `timestamps look like seconds (1757750400) but precision= is not set: add ?precision=s` |
| A `t` field whose number is a 1990-2200 time in seconds or milliseconds (`1757750400000t`) | 400 `column 'at' cannot take 1757750400000t: a t value is microseconds, and this number looks like milliseconds ...; write 1757750400000000t` |
| A plain whole number for a `TIMESTAMP` or `DATE` field (`at=1757750400000` or `at=1757750400000i`) | 400 `... cannot take the plain number 1757750400000i: a time field needs microseconds with a t suffix (this number looks like milliseconds: write 1757750400000000t)` |

- **Always send `precision=`** when your timestamps are not nanoseconds. With `precision=` the numbers are taken as sent, with no check.
- The ranges of seconds, milliseconds and microseconds do not overlap, so the message names the one unit that fits. KarelaDB never guesses and writes.
- Real nanosecond data still goes in, also a small test time like `5`: no unit makes that a 1990-2200 time.
- **QuestDB:** QuestDB takes the same bodies without an error and writes 1970 times. A plain integer for a `TIMESTAMP` field is read as microseconds there; KarelaDB refuses it, because apps often mean milliseconds.

**HTTP: Seconds without precision=: refused, nothing written** (sample data: sample)

```http
POST /write

live_data,symbol=CITY ltp=530.0 1789103700
```

Response:

HTTP 400 (application/json)

```text
{
  "code": "invalid",
  "message": "error in line 1: timestamps look like seconds (1789103700) but precision= is not set: add ?precision=s (without it they are read as nanoseconds and would land on 1970-01-01T00:00:01.789Z)",
  "line": 1,
  "errorId": "342fec1b753c-1"
}
```

**HTTP: The same line with precision=s** (sample data: sample)

```http
POST /write?precision=s

live_data,symbol=CITY ltp=530.0 1789103700
###
GET /exec?compat=0&query=SELECT timestamp, symbol, ltp FROM live_data WHERE timestamp = '2026-09-11T05:15:00Z' AND symbol = 'CITY'
```

Response:

`POST /write?precision=s`

HTTP 204

`GET /exec?compat=0&query=SELECT timestamp, symbol, ltp FROM live_data WHERE timestamp = '2026-09-11T05:15:00Z' AND symbol = 'CITY'`

HTTP 200 (application/json)

```text
{
  "query": "SELECT timestamp, symbol, ltp FROM live_data WHERE timestamp = '2026-09-11T05:15:00Z' AND symbol = 'CITY'",
  "results": [
    {
      "statement": "SELECT timestamp, symbol, ltp FROM live_data WHERE timestamp = '2026-09-11T05:15:00Z' AND symbol = 'CITY'",
      "columns": [
        {"name": "timestamp", "type": "TIMESTAMP"},
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "ltp", "type": "DOUBLE"}
      ],
      "dataset": [
        ["2026-09-11T05:15:00.000Z", "CITY", 530]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 27, "execute_us": 151}
    }
  ],
  "timings": {"parse_us": 27, "execute_us": 151}
}
```

**HTTP: A TIMESTAMP field in milliseconds: refused**

Setup:

```text
CREATE TABLE orders_log (time TIMESTAMP, symbol SYMBOL, placed TIMESTAMP) TIMESERIES(time) PARTITION BY DAY;
```

```http
POST /write?precision=ms

orders_log,symbol=CITY placed=1789103700000t 1789103700000
```

Response:

HTTP 400 (application/json)

```text
{
  "code": "invalid",
  "message": "error in line 1: table 'orders_log', column 'placed' cannot take 1789103700000t: a t value is microseconds, and this number looks like milliseconds (it would be 1970-01-21T16:58:23.700Z); write 1789103700000000t",
  "line": 1,
  "errorId": "342fec1b753c-2"
}
```

<a id="merge"></a>

## Update some columns: upsert=merge

By default a line **replaces the whole row** with the same key: a column not in the line becomes its `DEFAULT` or NULL. With `upsert=merge`, a column not in the line **keeps the value it has**.

| `upsert=` | A column missing from the line | Speed |
|---|---|---|
| `replace` (default) | becomes `DEFAULT` or NULL | fastest: rows are not looked up |
| `merge` | keeps its stored value; a new key is a normal insert | slower: every row is looked up by its key |

- `merge` needs a `PRIMARY KEY` or `DEDUP KEY`. A table without one is refused: `upsert=merge needs a PRIMARY KEY or DEDUP KEY ...`.
- Two lines with the same key in one request are merged in order.
- `NOT NULL` and `CHECK` rules are checked on the merged row. A new key still needs its `NOT NULL` fields.

**HTTP: Change the balance, keep the name and plan**

Setup:

```text
CREATE TABLE accounts (id LONG PRIMARY KEY, name STRING, balance DOUBLE, plan STRING DEFAULT 'free');
```

```http
POST /write

accounts id=1i,name="Sita",balance=100,plan="pro"
###
POST /write?upsert=merge

accounts id=1i,balance=150
###
GET /exec?compat=0&query=SELECT id, name, balance, plan FROM accounts
```

Response:

`POST /write`

HTTP 204

`POST /write?upsert=merge`

HTTP 204

`GET /exec?compat=0&query=SELECT id, name, balance, plan FROM accounts`

HTTP 200 (application/json)

```text
{
  "query": "SELECT id, name, balance, plan FROM accounts",
  "results": [
    {
      "statement": "SELECT id, name, balance, plan FROM accounts",
      "columns": [
        {"name": "id", "type": "LONG"},
        {"name": "name", "type": "STRING"},
        {"name": "balance", "type": "DOUBLE"},
        {"name": "plan", "type": "STRING"}
      ],
      "dataset": [
        [1, "Sita", 150, "pro"]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 17, "execute_us": 67}
    }
  ],
  "timings": {"parse_us": 17, "execute_us": 67}
}
```

**HTTP: Without merge the missing columns are reset**

Setup:

```text
CREATE TABLE accounts (id LONG PRIMARY KEY, name STRING, balance DOUBLE, plan STRING DEFAULT 'free');
```

```http
POST /write

accounts id=1i,name="Sita",balance=100,plan="pro"
###
POST /write

accounts id=1i,balance=150
###
GET /exec?compat=0&query=SELECT id, name, balance, plan FROM accounts
```

Response:

`POST /write`

HTTP 204

`POST /write`

HTTP 204

`GET /exec?compat=0&query=SELECT id, name, balance, plan FROM accounts`

HTTP 200 (application/json)

```text
{
  "query": "SELECT id, name, balance, plan FROM accounts",
  "results": [
    {
      "statement": "SELECT id, name, balance, plan FROM accounts",
      "columns": [
        {"name": "id", "type": "LONG"},
        {"name": "name", "type": "STRING"},
        {"name": "balance", "type": "DOUBLE"},
        {"name": "plan", "type": "STRING"}
      ],
      "dataset": [
        [1, null, 150, "free"]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 33, "execute_us": 76}
    }
  ],
  "timings": {"parse_us": 33, "execute_us": 76}
}
```

<a id="new-tables"></a>

## A table that is not there

When the lines name a table the database does not have, `POST /write` makes it, as QuestDB does, and then writes the rows. The columns come from every line of the request for that table, in the order they first appear:

| In the line | Column type |
|---|---|
| a tag (`symbol=CITY`) | `SYMBOL` |
| `512.4` | `DOUBLE` |
| `120i` | `LONG` |
| `"text"` | `STRING` |
| `t`, `f`, `true`, `false` | `BOOLEAN` |
| `1789103700000000t` | `TIMESTAMP` |
| the timestamp at the end | the time column `timestamp` (`TIMESTAMP`) |

- The table is a time-series table: `TIMESERIES(timestamp) PARTITION BY DAY`, without a `DEDUP KEY`, as QuestDB makes it. Add a key later with [DEDUP ENABLE](alter-table.md#dedup-enable), or make the table yourself first when you want other types or a key.
- Making a table needs the role **ddl** (like [/imp](loading-data.md)). A user with role `write` gets 403 for a table that is not there.
- A column sent as two kinds (`3i` in one line, `1.5` in another) is refused with 400, and no table is made: a guess could lose digits. So is a field named `timestamp`.
- A request with a bad line makes no table.
- The admin turns this off with `--ilp-auto-create off`, `"ilp_auto_create": "off"` in kareladb.conf, or `KARELADB_ILP_AUTO_CREATE=off`. Then a table that is not there is an error, 400 `table 'x' does not exist; create it first`.
- Columns are not added to a table that is already there: a line with a new field is an error. Add the column with `ALTER TABLE ... ADD COLUMN`.

**HTTP: A table that is not there is made from the lines**

```http
POST /write

market_index,name=MAIN value=2650.5,trades=1200i 1789103700000000000
###
GET /exec?compat=0&query=SHOW COLUMNS FROM market_index
```

Response:

`POST /write`

HTTP 204

`GET /exec?compat=0&query=SHOW COLUMNS FROM market_index`

HTTP 200 (application/json)

```text
{
  "query": "SHOW COLUMNS FROM market_index",
  "results": [
    {
      "statement": "SHOW COLUMNS FROM market_index",
      "columns": [
        {"name": "name", "type": "STRING"},
        {"name": "type", "type": "STRING"},
        {"name": "primary_key", "type": "BOOL"},
        {"name": "not_null", "type": "BOOL"},
        {"name": "computed", "type": "BOOL"},
        {"name": "references", "type": "STRING"}
      ],
      "dataset": [
        ["name", "SYMBOL", false, false, false, null],
        ["value", "DOUBLE", false, false, false, null],
        ["trades", "LONG", false, false, false, null],
        ["timestamp", "TIMESTAMP", false, false, false, null]
      ],
      "count": 4,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 5, "execute_us": 9}
    }
  ],
  "timings": {"parse_us": 5, "execute_us": 9}
}
```

## POST /write

Syntax:

```sql
POST /write[?db=<name>][&precision=n|u|ms|s][&upsert=replace|merge]
body: lines of the line protocol (UTF-8)
```

Parses every line, then writes all the rows in **one transaction**. Rows are **upserted**: a row with the same key as an existing row (its `PRIMARY KEY` or `DEDUP KEY`) replaces it, like `INSERT OR REPLACE`. So sending the same lines twice does not make duplicates in a table with a key.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| body | body | The lines | required |
| `db` | URL | The database (or the header `X-KDB-Database`). InfluxDB's `bucket` and `org` are ignored. | the default database |
| `precision` | URL | The unit of the timestamps at the end of the lines: `n` or `ns` nanoseconds, `u` or `us` microseconds, `ms` milliseconds, `s` seconds. Without it, timestamps that plainly are seconds, milliseconds or microseconds are refused ([the wrong unit](#wrong-unit)). | `n` |
| `upsert` | URL | `replace`: a line replaces the whole row. `merge`: columns missing from a line keep their stored values ([merge](#merge)). | `replace` |
| `dedup` | URL | `skip`: no duplicate lookups in days that already hold rows, for trusted loads of new rows. **A key already stored may then be there twice**; repair with `DEDUP TABLE` ([dedup=skip](partitions-and-dedup.md#dedup-skip)). | `on` |
| `wait` | URL | `trigger`: answer only after the [deferred trigger](triggers.md#deferred) jobs of these rows ended, with `200` and `{"rows":N,"jobs":[...],"done":true}`. | no wait: `204` |
| `wait_timeout` | URL | With `wait=trigger`: the longest wait, like `10min`. Jobs still running then show `"status":"running"`. | no limit |

| Answer | Meaning |
|---|---|
| `204 No Content` | All lines were written and are on disk. There is no body; the `Server-Timing` header says where the time went ([timings](http-import.md#timings)). |
| `code` | (error) `"invalid"` for a bad request or line, `"internal error"` for trouble on the server |
| `message` | (error) what is wrong. About a line it starts with `error in line N:` |
| `line` | (error) the line number (from 1), or `0` when the error is not about one line |
| `errorId` | (error) a unique id of this error, to find it in logs |

- **Status codes:** 204 written; 400 a bad line, an unknown column (or table, when making tables is off), a value of the wrong type, a time in the wrong unit, a bad `precision` or `upsert`, a damaged compressed body, or a compression other than gzip and deflate; 401/403 login or role (needs `write`, and `ddl` to make a table); 404 unknown database; 405 for `GET`; 408 a trigger ran past the statement timeout; 413 body over 64 MB (counted after unpacking); 500 server trouble (nothing written); 503 busy: another writer or transaction held the table for longer than the lock wait (5 s), with the message `table 'x' is busy: ...` or `database is busy: ...` (nothing written; send it again); 507 the disk is full or has less than 64 MB free, with `"code": "disk full"` (nothing written; see [loading data](loading-data.md#speed)).
- **Notes:**
  - When **any** line is wrong, **nothing** of the request is written. Fix the line and send the request again.
  - [Triggers](triggers.md) run **once per request** (not once per line), in the same transaction. `CHECK`, `NOT NULL` and `REFERENCES` rules are checked for every row.
  - An immediate `INSERT` trigger on a table makes the loads **into that table** go row by row, several times slower. A trigger on another table does not slow this one. For a table you load in bulk, make the trigger [DEFERRED](triggers.md#deferred).
  - Rows are written as columns, one piece per partition, also into a table with no `DEDUP KEY`. What a day that already has rows costs depends on the keys: [how loads find duplicates](partitions-and-dedup.md#load-dedup).
  - Loads into different tables run at the same time; loads into one table take turns.
  - [Deferred triggers](triggers.md#deferred) do not run inside the request: it returns when the rows are committed, and each deferred trigger gets one job with exactly these rows. Add `wait=trigger` to wait for the jobs.
  - The fastest load is one new day per request: the rows need no duplicate lookups ([speed](performance-tips.md#line-protocol)).
  - A trigger's time counts toward the [statement timeout](protection.md#statement-timeout) (60 s by default). An admin's loader may send `X-KDB-Statement-Timeout: 5min` for triggers that need longer. A trigger that runs too long gives status 408 with `"line": 0` and the message `trigger <name>: statement timeout (<N> s)`: nothing of the request is written, and it is not about a line of the body.
  - Big bodies are read on several threads. For speed, send many lines per request (for example 1,000 to 100,000), not one request per line.
  - A body may be compressed: send `Content-Encoding: gzip` or `Content-Encoding: deflate`. The 64 MB limit counts the **unpacked** lines, so a small body that unpacks to more is refused with 413 `request body is too large once decompressed`. A damaged body gives 400 `the gzip request body could not be decompressed: ...` and writes nothing.
  - Chunked bodies are not supported: send `Content-Length`.

```bash
# Market ticks from a file, sent gzip-compressed
gzip -c ticks.lp | curl --data-binary @- -H "Content-Encoding: gzip" "http://127.0.0.1:9900/write?precision=ms"
```
  - **QuestDB:** QuestDB creates missing tables and columns; KarelaDB refuses them with a clear message. QuestDB's line protocol over TCP (port 9009) is not available: use HTTP. The error answer has QuestDB's shape.

**HTTP: Three market ticks, times in seconds** (sample data: sample)

```http
POST /write?precision=s

live_data,symbol=CITY ltp=528.5,ltv=120i,volume=45120i 1789103700
live_data,symbol=COAST ltp=402.3,ltv=50i,volume=30110i 1789103700
live_data,symbol=CITY ltp=529.0,ltv=80i,volume=45200i 1789103760
###
GET /exec?compat=0&query=SELECT timestamp, symbol, ltp, ltv, volume FROM live_data WHERE timestamp >= '2026-09-11T05:15:00Z' ORDER BY timestamp, symbol
```

Response:

`POST /write?precision=s`

HTTP 204

`GET /exec?compat=0&query=SELECT timestamp, symbol, ltp, ltv, volume FROM live_data WHERE timestamp >= '2026-09-11T05:15:00Z' ORDER BY timestamp, symbol`

HTTP 200 (application/json)

```text
{
  "query": "SELECT timestamp, symbol, ltp, ltv, volume FROM live_data WHERE timestamp >= '2026-09-11T05:15:00Z' ORDER BY timestamp, symbol",
  "results": [
    {
      "statement": "SELECT timestamp, symbol, ltp, ltv, volume FROM live_data WHERE timestamp >= '2026-09-11T05:15:00Z' ORDER BY timestamp, symbol",
      "columns": [
        {"name": "timestamp", "type": "TIMESTAMP"},
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "ltp", "type": "DOUBLE"},
        {"name": "ltv", "type": "LONG"},
        {"name": "volume", "type": "LONG"}
      ],
      "dataset": [
        ["2026-09-11T05:15:00.000Z", "CITY", 528.5, 120, 45120],
        ["2026-09-11T05:15:00.000Z", "COAST", 402.3, 50, 30110],
        ["2026-09-11T05:16:00.000Z", "CITY", 529, 80, 45200]
      ],
      "count": 3,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 19, "execute_us": 102}
    }
  ],
  "timings": {"parse_us": 19, "execute_us": 102}
}
```

**HTTP: The same moment in three precisions** (sample data: sample)

```http
POST /write

live_data,symbol=TELCO ltp=900.1 1789103700123456789
###
POST /write?precision=u

live_data,symbol=VOLT ltp=190.5 1789103700123456
###
POST /write?precision=ms

live_data,symbol=ACME ltp=250.2 1789103700123
###
GET /exec?compat=0&query=SELECT timestamp, symbol, ltp FROM live_data WHERE timestamp >= '2026-09-11' ORDER BY symbol
```

Response:

`POST /write`

HTTP 204

`POST /write?precision=u`

HTTP 204

`POST /write?precision=ms`

HTTP 204

`GET /exec?compat=0&query=SELECT timestamp, symbol, ltp FROM live_data WHERE timestamp >= '2026-09-11' ORDER BY symbol`

HTTP 200 (application/json)

```text
{
  "query": "SELECT timestamp, symbol, ltp FROM live_data WHERE timestamp >= '2026-09-11' ORDER BY symbol",
  "results": [
    {
      "statement": "SELECT timestamp, symbol, ltp FROM live_data WHERE timestamp >= '2026-09-11' ORDER BY symbol",
      "columns": [
        {"name": "timestamp", "type": "TIMESTAMP"},
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "ltp", "type": "DOUBLE"}
      ],
      "dataset": [
        ["2026-09-11T05:15:00.123Z", "ACME", 250.2],
        ["2026-09-11T05:15:00.123Z", "TELCO", 900.1],
        ["2026-09-11T05:15:00.123Z", "VOLT", 190.5]
      ],
      "count": 3,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 23, "execute_us": 109}
    }
  ],
  "timings": {"parse_us": 23, "execute_us": 109}
}
```

**HTTP: Every kind of value**

Setup:

```text
CREATE TABLE feed (
  time TIMESTAMP, symbol SYMBOL, price DOUBLE, qty LONG, amount DECIMAL(2),
  final BOOL, note STRING, trade_day DATE, payload JSON
) TIMESERIES(time) PARTITION BY DAY;
```

```http
POST /write?precision=ms

feed,symbol=CITY price=512.4,qty=100i,amount=51240.5,final=t,note="first, \"big\" buyer",trade_day="2026-09-11",payload="{\"broker\": 58}" 1789103700000
feed,symbol=City\ Bank price=513,qty=5u,final=false,trade_day=1789103700000000t 1789103701000
###
GET /exec?compat=0&query=SELECT * FROM feed ORDER BY time
```

Response:

`POST /write?precision=ms`

HTTP 204

`GET /exec?compat=0&query=SELECT * FROM feed ORDER BY time`

HTTP 200 (application/json)

```text
{
  "query": "SELECT * FROM feed ORDER BY time",
  "results": [
    {
      "statement": "SELECT * FROM feed ORDER BY time",
      "columns": [
        {"name": "time", "type": "TIMESTAMP"},
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "price", "type": "DOUBLE"},
        {"name": "qty", "type": "LONG"},
        {"name": "amount", "type": "DECIMAL(2)"},
        {"name": "final", "type": "BOOL"},
        {"name": "note", "type": "STRING"},
        {"name": "trade_day", "type": "DATE"},
        {"name": "payload", "type": "JSON"}
      ],
      "dataset": [
        [
          "2026-09-11T05:15:00.000Z",
          "CITY",
          512.4,
          100,
          "51240.50",
          true,
          "first, \"big\" buyer",
          "2026-09-11",
          {"broker": 58}
        ],
        ["2026-09-11T05:15:01.000Z", "City Bank", 513, 5, null, false, null, "2026-09-11", null]
      ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 10, "execute_us": 81}
    }
  ],
  "timings": {"parse_us": 10, "execute_us": 81}
}
```

**HTTP: Send a correction: the same key replaces the row** (sample data: sample)

```http
POST /write?precision=s

live_data,symbol=COAST ltp=402.3 1789103700
###
POST /write?precision=s

live_data,symbol=COAST ltp=402.8 1789103700
###
GET /exec?compat=0&query=SELECT timestamp, symbol, ltp FROM live_data WHERE timestamp = '2026-09-11T05:15:00Z'
```

Response:

`POST /write?precision=s`

HTTP 204

`POST /write?precision=s`

HTTP 204

`GET /exec?compat=0&query=SELECT timestamp, symbol, ltp FROM live_data WHERE timestamp = '2026-09-11T05:15:00Z'`

HTTP 200 (application/json)

```text
{
  "query": "SELECT timestamp, symbol, ltp FROM live_data WHERE timestamp = '2026-09-11T05:15:00Z'",
  "results": [
    {
      "statement": "SELECT timestamp, symbol, ltp FROM live_data WHERE timestamp = '2026-09-11T05:15:00Z'",
      "columns": [
        {"name": "timestamp", "type": "TIMESTAMP"},
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "ltp", "type": "DOUBLE"}
      ],
      "dataset": [
        ["2026-09-11T05:15:00.000Z", "COAST", 402.8]
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

**HTTP: Line 2 is wrong: nothing is written** (sample data: sample; shows an error)

```http
POST /write?precision=s

live_data,symbol=CITY ltp=530.0 1789103820
live_data,symbol=COAST ltp=403.0,volume=12.5 1789103820
live_data,symbol=TELCO ltp=901.0 1789103820
###
GET /exec?compat=0&query=SELECT count(*) AS rows_at_05_17 FROM live_data WHERE timestamp = '2026-09-11T05:17:00Z'
```

Response:

`POST /write?precision=s`

HTTP 400 (application/json)

```text
{
  "code": "invalid",
  "message": "error in line 2: table 'live_data', column 'volume' is LONG and cannot take a float; write whole numbers with an i suffix, like 3i",
  "line": 2,
  "errorId": "342fec1b753c-3"
}
```

`GET /exec?compat=0&query=SELECT count(*) AS rows_at_05_17 FROM live_data WHERE timestamp = '2026-09-11T05:17:00Z'`

HTTP 200 (application/json)

```text
{
  "query": "SELECT count(*) AS rows_at_05_17 FROM live_data WHERE timestamp = '2026-09-11T05:17:00Z'",
  "results": [
    {
      "statement": "SELECT count(*) AS rows_at_05_17 FROM live_data WHERE timestamp = '2026-09-11T05:17:00Z'",
      "columns": [
        {"name": "rows_at_05_17", "type": "LONG"}
      ],
      "dataset": [
        [0]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 17, "execute_us": 126}
    }
  ],
  "timings": {"parse_us": 17, "execute_us": 126}
}
```

**HTTP: Every column must exist** (sample data: sample)

```http
POST /write

live_data,symbol=CITY ltp=530.0,turnover=1250000.5 1789103700000000000
```

Response:

HTTP 400 (application/json)

```text
{
  "code": "invalid",
  "message": "error in line 1: table 'live_data' has no column 'turnover'; add it first (ALTER TABLE live_data ADD COLUMN ...)",
  "line": 1,
  "errorId": "342fec1b753c-4"
}
```

**HTTP: A trigger runs once for the whole request** (sample data: sample)

Setup:

```text
CREATE TABLE write_log (id INT PRIMARY KEY AUTO, rows_written LONG);
CREATE TRIGGER count_ticks AFTER INSERT ON live_data EXECUTE BEGIN
  FOR r IN (SELECT count(*) AS n FROM NEW) DO
    INSERT INTO write_log (rows_written) VALUES (r.n);
  END FOR;
END;
```

```http
POST /write?precision=s

live_data,symbol=CITY ltp=531.0 1789104000
live_data,symbol=COAST ltp=404.0 1789104000
live_data,symbol=TELCO ltp=902.0 1789104000
###
GET /exec?compat=0&query=SELECT * FROM write_log
```

Response:

`POST /write?precision=s`

HTTP 204

`GET /exec?compat=0&query=SELECT * FROM write_log`

HTTP 200 (application/json)

```text
{
  "query": "SELECT * FROM write_log",
  "results": [
    {
      "statement": "SELECT * FROM write_log",
      "columns": [
        {"name": "id", "type": "INT"},
        {"name": "rows_written", "type": "LONG"}
      ],
      "dataset": [
        [1, 3]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 11, "execute_us": 60}
    }
  ],
  "timings": {"parse_us": 11, "execute_us": 60}
}
```

**HTTP: Bad precision**

```http
POST /write?precision=minutes

live_data,symbol=CITY ltp=530.0 1
```

Response:

HTTP 400 (application/json)

```text
{
  "code": "invalid",
  "message": "unsupported precision 'minutes': use n, u, ms or s",
  "line": 0,
  "errorId": "342fec1b753c-5"
}
```

**HTTP: Writing needs POST**

```http
GET /write
```

Response:

HTTP 405 (application/json)

```text
{"error": "method GET is not allowed here"}
```

Clients (not run by the help build):

```bash
curl -s -i "http://127.0.0.1:9900/write?db=market&precision=s" --data-binary @ticks.lp
```

```powershell
# Send a file of lines. -i shows the 204 status; on an error the JSON says which line.
$lines = Get-Content ticks.lp -Raw
Invoke-WebRequest -Method Post -Uri "http://127.0.0.1:9900/write?db=market&precision=s" -Body $lines -ContentType "text/plain; charset=utf-8" |
  Select-Object StatusCode
```

```python
import time
import requests

def write_ticks(ticks, db="market"):
    # ticks: list of (symbol, ltp, volume). One request for all of them.
    now = int(time.time())
    body = "\n".join(f"live_data,symbol={s} ltp={ltp},volume={vol}i {now}" for s, ltp, vol in ticks)
    r = requests.post("http://127.0.0.1:9900/write", params={"db": db, "precision": "s"},
                      data=body.encode("utf-8"))
    if r.status_code != 204:
        e = r.json()
        raise RuntimeError(f"line {e['line']}: {e['message']}")

write_ticks([("CITY", 528.5, 45120), ("COAST", 402.3, 30110)])
```

```js
// Node 18+: a live feed that sends the ticks of each second in one request.
const lines = ticks.map((t) => `live_data,symbol=${t.symbol} ltp=${t.ltp},volume=${t.volume}i ${t.timeMs}`).join("\n");
const res = await fetch("http://127.0.0.1:9900/write?db=market&precision=ms", { method: "POST", body: lines });
if (res.status !== 204) {
  const e = await res.json();
  throw new Error(`line ${e.line}: ${e.message}`);
}
```

```csharp
using var http = new HttpClient();
var body = new StringContent("live_data,symbol=CITY ltp=528.5,volume=45120i 1789103700\n", Encoding.UTF8, "text/plain");
var res = await http.PostAsync("http://127.0.0.1:9900/write?db=market&precision=s", body);
if ((int)res.StatusCode != 204) Console.WriteLine(await res.Content.ReadAsStringAsync());
```

## POST /api/v2/write

Syntax:

```sql
POST /api/v2/write[?db=<name>][&precision=n|u|ms|s]
body: lines of the line protocol
```

The same as [POST /write](line-protocol.md#post-write), at the path InfluxDB 2 clients use. Everything (parameters, answers, errors) is the same.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `db` | URL | The database (or the header `X-KDB-Database`). `bucket` and `org` are ignored. | the default database |
| `precision` | URL | `n`, `u`, `ms` or `s` (also `ns`, `us`) | `n` |

| Answer | Meaning |
|---|---|
| 204, or `{"code", "message", "line", "errorId"}` | as for [POST /write](line-protocol.md#post-write) |

- **Status codes:** as for POST /write.
- **Notes:** an InfluxDB client library can send here when its URL is the KarelaDB server and the database is given with `db=` (or the `X-KDB-Database` header). With a KarelaDB `--token`, send it as `Authorization: Bearer <token>`; InfluxDB's `Authorization: Token ...` is not accepted. The client's gzip setting can stay on: gzip bodies are unpacked.

**HTTP: The InfluxDB 2 path** (sample data: sample)

```http
POST /api/v2/write?db=demo&precision=ms&bucket=ignored

live_data,symbol=VOLT ltp=191.0,volume=70500i 1789103700000
###
GET /exec?compat=0&query=SELECT timestamp, symbol, ltp, volume FROM live_data WHERE symbol = 'VOLT' AND timestamp >= '2026-09-11'
```

Response:

`POST /api/v2/write?db=demo&precision=ms&bucket=ignored`

HTTP 204

`GET /exec?compat=0&query=SELECT timestamp, symbol, ltp, volume FROM live_data WHERE symbol = 'VOLT' AND timestamp >= '2026-09-11'`

HTTP 200 (application/json)

```text
{
  "query": "SELECT timestamp, symbol, ltp, volume FROM live_data WHERE symbol = 'VOLT' AND timestamp >= '2026-09-11'",
  "results": [
    {
      "statement": "SELECT timestamp, symbol, ltp, volume FROM live_data WHERE symbol = 'VOLT' AND timestamp >= '2026-09-11'",
      "columns": [
        {"name": "timestamp", "type": "TIMESTAMP"},
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "ltp", "type": "DOUBLE"},
        {"name": "volume", "type": "LONG"}
      ],
      "dataset": [
        ["2026-09-11T05:15:00.000Z", "VOLT", 191, 70500]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 22, "execute_us": 101}
    }
  ],
  "timings": {"parse_us": 22, "execute_us": 101}
}
```
