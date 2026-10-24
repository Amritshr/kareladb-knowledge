# Cursors

> Run a query once, keep its rows, and read them a few at a time.

- Category: Cursors
- Keywords: cursor, CURSOR, DECLARE CURSOR, NEXT, ALL, paging, page by page, read in parts, big result, snapshot, FETCH NEXT, FETCH ALL, too many open cursors, is not open
- See also: [Sessions and cursors over HTTP](http-sessions-and-cursors.md), [The procedure language (local-cursors)](procedure-language.md#local-cursors), [Transactions](transactions.md), [ORDER BY, LIMIT, OFFSET](order-by-limit.md), [13. Functions, procedures and triggers](../tutorial/13-functions-procedures-triggers.md)

A **cursor** runs a `SELECT` once and keeps its rows. Then you read the rows a part at a time with `FETCH`, and end with `CLOSE`.
Use it when a result is too big to read at once, for example to send a long trade log to an app page by page.

- The rows are a **snapshot** (a copy made at `DECLARE`): changes to the table after that do not change what `FETCH` returns.
- A cursor lives until `CLOSE`, or until the end of the text or session (see [where a cursor lives](cursors.md#lifetime)).
- Over HTTP, `POST /cursor` does the same job (see [cursors over HTTP](cursors.md#http)).
- Inside a procedure, a cursor reads one row at a time into variables: see [cursors in a body](procedure-language.md#local-cursors).

**Example: The trade log of one day, 5 trades at a time** (sample data: sample)

```sql
DECLARE trades CURSOR FOR
  SELECT transaction_id, symbol, buyer, seller, quantity, rate
  FROM trade_log WHERE date = '2026-09-10' ORDER BY transaction_id;
FETCH NEXT 5 FROM trades;
FETCH NEXT 5 FROM trades;
CLOSE trades;
```

Result:

`DECLARE trades CURSOR FOR SELECT transaction_id, symbol, buyer, seller, quantity, rate FROM trade_lo`

```text
cursor 'trades' declared: 24 row(s)
```

`FETCH NEXT 5 FROM trades`

| transaction_id (LONG) | symbol (SYMBOL) | buyer (INT) | seller (INT) | quantity (LONG) | rate (DOUBLE) |
|---|---|---|---|---|---|
| 100009 | COAST | 34 | 45 | 50 | 400 |
| 100010 | CITY | 1 | 45 | 50 | 517 |
| 100011 | VOLT | 1 | 58 | 50 | 184 |
| 100012 | VOLT | 58 | 45 | 200 | 184 |
| 100013 | COAST | 58 | 1 | 50 | 398 |

(5 rows)

```text
5 row(s) fetched, 19 left
```

`FETCH NEXT 5 FROM trades`

| transaction_id (LONG) | symbol (SYMBOL) | buyer (INT) | seller (INT) | quantity (LONG) | rate (DOUBLE) |
|---|---|---|---|---|---|
| 100014 | COAST | 45 | 49 | 20 | 399.5 |
| 100015 | COAST | 49 | 45 | 1000 | 398 |
| 100016 | VOLT | 34 | 1 | 50 | 185 |
| 100017 | TELCO | 49 | 34 | 500 | 881 |
| 100018 | CITY | 45 | 1 | 500 | 516 |

(5 rows)

```text
5 row(s) fetched, 14 left
```

`CLOSE trades`

```text
cursor 'trades' closed
```

<a id="declare-cursor"></a>

## DECLARE CURSOR

Syntax:

```sql
DECLARE name CURSOR FOR SELECT ...
```

Runs the query at once and keeps all its rows under a name.

| Part | Meaning |
|---|---|
| `name` | the cursor name. Upper and lower case are the same. |
| `SELECT ...` | one query. Not `SHOW`, not `EXPLAIN`. Use `ORDER BY` when the order of the parts matters. |

- **Returns:** `cursor 'name' declared: N row(s)`.
- **Notes:**
  - The query runs **once**, now. Its rows stay in memory until the cursor is closed.
  - A name that is already open in the same text or session is an error: `CLOSE` it first.
  - `DECLARE name TYPE` (a variable) works only inside a procedure or trigger body.
  - At most 16 open cursors per database, and at most 10 million rows per cursor (see [limits](cursors.md#limits)).
  - `DECLARE ... CURSOR` works inside `BEGIN ... COMMIT`, and then it sees the changes of the transaction.

**Example: A snapshot: rows deleted after DECLARE are still fetched** (sample data: sample)

```sql
DECLARE s CURSOR FOR SELECT symbol, sector FROM securities ORDER BY symbol;
DELETE FROM securities WHERE sector = 'Banking';
FETCH ALL FROM s;
SELECT count(*) AS securities_now FROM securities;
```

Result:

`DECLARE s CURSOR FOR SELECT symbol, sector FROM securities ORDER BY symbol`

```text
cursor 's' declared: 5 row(s)
```

`DELETE FROM securities WHERE sector = 'Banking'`

```text
2 row(s) deleted
```

`FETCH ALL FROM s`

| symbol (SYMBOL) | sector (STRING) |
|---|---|
| ACME | Investment |
| CITY | Banking |
| COAST | Banking |
| TELCO | Telecom |
| VOLT | Energy |

(5 rows)

```text
5 row(s) fetched, no more rows
```

`SELECT count(*) AS securities_now FROM securities`

| securities_now (LONG) |
|---|
| 3 |

(1 row)

**Example: The same name twice** (shows an error)

```sql
DECLARE c CURSOR FOR SELECT 1 AS x;
DECLARE c CURSOR FOR SELECT 2 AS x;
```

Result:

```text
cursor 'c' declared: 1 row(s)
```

Error: `cursor 'c' is already open; CLOSE it first`

**Example: Only a SELECT** (shows an error)

```sql
DECLARE c CURSOR FOR SHOW TABLES;
```

Result:

Error: `line 1, column 22: expected a query (SELECT ...) after CURSOR FOR but found 'SHOW'`

<a id="fetch"></a>

## FETCH

Syntax:

```sql
FETCH name
FETCH [FROM] name
FETCH NEXT [FROM] name
FETCH NEXT count FROM name
FETCH count FROM name
FETCH ALL FROM name
```

Returns the next rows of the cursor and moves past them.

| Form | Rows |
|---|---|
| `FETCH c`, `FETCH FROM c`, `FETCH NEXT FROM c` | the next 1 row |
| `FETCH NEXT 100 FROM c`, `FETCH 100 FROM c` | the next 100 rows (fewer at the end) |
| `FETCH ALL FROM c` | all rows that are left |

- **Returns:** the rows (with the columns of the query), and the message `N row(s) fetched, M left` or `N row(s) fetched, no more rows`.
- **Notes:**
  - With a count or `ALL`, the word `FROM` is needed: `FETCH NEXT 5 c` is an error.
  - The count must be 1 or more.
  - After the last row, `FETCH` returns 0 rows (not an error). The cursor stays open until `CLOSE`.
  - There is no going back (`PRIOR`, `ABSOLUTE`): a cursor only moves forward.
  - `FETCH ... INTO variables` works only inside a procedure or trigger body.

**Example: All forms of FETCH** (sample data: sample)

```sql
DECLARE s CURSOR FOR SELECT symbol, sector FROM securities ORDER BY symbol;
FETCH s;
FETCH NEXT FROM s;
FETCH 2 FROM s;
FETCH ALL FROM s;
FETCH ALL FROM s;
```

Result:

`DECLARE s CURSOR FOR SELECT symbol, sector FROM securities ORDER BY symbol`

```text
cursor 's' declared: 5 row(s)
```

`FETCH NEXT 1 FROM s`

| symbol (SYMBOL) | sector (STRING) |
|---|---|
| ACME | Investment |

(1 row)

```text
1 row(s) fetched, 4 left
```

`FETCH NEXT 1 FROM s`

| symbol (SYMBOL) | sector (STRING) |
|---|---|
| CITY | Banking |

(1 row)

```text
1 row(s) fetched, 3 left
```

`FETCH NEXT 2 FROM s`

| symbol (SYMBOL) | sector (STRING) |
|---|---|
| COAST | Banking |
| TELCO | Telecom |

(2 rows)

```text
2 row(s) fetched, 1 left
```

`FETCH ALL FROM s`

| symbol (SYMBOL) | sector (STRING) |
|---|---|
| VOLT | Energy |

(1 row)

```text
1 row(s) fetched, no more rows
```

`FETCH ALL FROM s`

| symbol (SYMBOL) | sector (STRING) |
|---|---|

(0 rows)

```text
0 row(s) fetched, no more rows
```

**Example: Minute candles of CITY, one hour at a time** (sample data: sample)

```sql
DECLARE m CURSOR FOR
  SELECT time, open, high, low, close, volume
  FROM ochl_minutes WHERE symbol = 'CITY' AND time IN '2026-09-10' ORDER BY time;
FETCH NEXT 60 FROM m;
FETCH NEXT 60 FROM m;
CLOSE m;
```

Result:

`DECLARE m CURSOR FOR SELECT time, open, high, low, close, volume FROM ochl_minutes WHERE symbol = 'C`

```text
cursor 'm' declared: 240 row(s)
```

`FETCH NEXT 60 FROM m`

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-10T05:15:00.000Z | 504.6 | 504.6 | 504.4 | 504.4 | 960 |
| 2026-09-10T05:16:00.000Z | 504.4 | 504.7 | 504.3 | 504.6 | 700 |
| 2026-09-10T05:17:00.000Z | 504.6 | 504.9 | 504 | 504.2 | 150 |
| 2026-09-10T05:18:00.000Z | 504.2 | 504.6 | 504.1 | 504.4 | 1050 |
| 2026-09-10T05:19:00.000Z | 504.4 | 504.8 | 504.1 | 504.5 | 450 |

(first 5 of 60 rows)

```text
60 row(s) fetched, 180 left
```

`FETCH NEXT 60 FROM m`

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-10T06:15:00.000Z | 505.3 | 505.4 | 505.1 | 505.4 | 1210 |
| 2026-09-10T06:16:00.000Z | 505.4 | 505.7 | 505.2 | 505.6 | 1080 |
| 2026-09-10T06:17:00.000Z | 505.6 | 505.9 | 505.6 | 505.8 | 290 |
| 2026-09-10T06:18:00.000Z | 505.8 | 506 | 505.6 | 505.6 | 330 |
| 2026-09-10T06:19:00.000Z | 505.6 | 505.7 | 505.2 | 505.4 | 270 |

(first 5 of 60 rows)

```text
60 row(s) fetched, 120 left
```

`CLOSE m`

```text
cursor 'm' closed
```

**Example: FROM is needed with a count** (shows an error)

```sql
DECLARE c CURSOR FOR SELECT 1 AS x;
FETCH NEXT 5 c;
```

Result:

Error: `line 2, column 14: expected FROM and the cursor name, as in FETCH NEXT 100 FROM c, but found 'c'`

**Example: A count of 0** (shows an error)

```sql
DECLARE c CURSOR FOR SELECT 1 AS x;
FETCH 0 FROM c;
```

Result:

Error: `line 2, column 7: expected a row count of 1 or more but found '0'`

<a id="close"></a>

## CLOSE

Syntax:

```sql
CLOSE name
```

Closes the cursor and frees the memory of its rows.

- **Returns:** `cursor 'name' closed`.
- **Notes:** closing a cursor that is not open is an error. Cursors also close by themselves at the end of the text, the end of the session, and after 10 minutes without `FETCH`. Still, close them when you are done: only 16 can be open.

**Example** (sample data: sample)

```sql
DECLARE b CURSOR FOR SELECT id, name FROM brokers ORDER BY id;
FETCH NEXT 2 FROM b;
CLOSE b;
```

Result:

`DECLARE b CURSOR FOR SELECT id, name FROM brokers ORDER BY id`

```text
cursor 'b' declared: 5 row(s)
```

`FETCH NEXT 2 FROM b`

| id (INT) | name (STRING) |
|---|---|
| 1 | Keystone Securities |
| 34 | Vision Securities |

(2 rows)

```text
2 row(s) fetched, 3 left
```

`CLOSE b`

```text
cursor 'b' closed
```

**Example: A cursor that is not open** (shows an error)

```sql
CLOSE b;
```

Result:

Error: `cursor 'b' is not open`

<a id="lifetime"></a>

## Where a cursor lives

Syntax:

```sql
kareladb sql db "DECLARE ...; FETCH ...; CLOSE ..."     -- one text
kareladb shell db                                        -- one session: many lines
POST /session, then X-KDB-Session on POST /exec     -- one HTTP session: many requests
```

A cursor belongs to the text or the session that declared it.

| Where | The cursor lives until |
|---|---|
| one text: `kareladb sql`, `POST /exec` without a session, the web console | `CLOSE`, or the end of that text |
| `kareladb shell` | `CLOSE`, or the end of the shell |
| an HTTP session ([`POST /session`](http-sessions-and-cursors.md)) | `CLOSE`, or the end of the session |
| a procedure body (`OPEN`) | the end of the procedure |
| an HTTP cursor (`POST /cursor`) | `DELETE /cursor/<id>` |

All of them also close after **10 minutes** without `FETCH`. Another session cannot see your cursor, even with the same name.

- **Notes:**
  - When a statement of one text fails, the cursors of that text are closed too. In `kareladb shell` and in an HTTP session, cursors stay open after an error.
  - `ROLLBACK` does not close cursors: their rows were already read at `DECLARE`.

**Command line: Two kareladb sql commands: the cursor of the first is gone** (sample data: sample; shows an error)

```bash
kareladb sql market "DECLARE b CURSOR FOR SELECT id, name FROM brokers ORDER BY id; FETCH NEXT 2 FROM b"
kareladb sql market "FETCH NEXT 2 FROM b"
```

Output:

`> kareladb sql market "DECLARE b CURSOR FOR SELECT id, name FROM brokers ORDER BY id; FETCH NEXT 2 FROM b"`

```text
cursor 'b' declared: 5 row(s)

id | name               
---+--------------------
 1 | Keystone Securities
34 | Vision Securities  
(2 rows, 0.0 ms)
2 row(s) fetched, 3 left
```

`> kareladb sql market "FETCH NEXT 2 FROM b"`

```text
error: cursor 'b' is not open (DECLARE b CURSOR FOR SELECT ... first; an unused cursor closes after 10 minutes)
```

exit code 1

**Command line: kareladb shell: the cursor stays from one line to the next** (sample data: sample)

```bash
kareladb shell market
> DECLARE b CURSOR FOR SELECT id, name FROM brokers ORDER BY id;
> FETCH NEXT 2 FROM b;
> FETCH NEXT 2 FROM b;
> FETCH ALL FROM b;
> CLOSE b;
> .exit
```

Output:

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> cursor 'b' declared: 5 row(s)
kareladb> id | name               
---+--------------------
 1 | Keystone Securities
34 | Vision Securities  
(2 rows, 0.0 ms)
2 row(s) fetched, 3 left
kareladb> id | name               
---+--------------------
45 | Imperial Securities
49 | Online Securities  
(2 rows, 0.0 ms)
2 row(s) fetched, 1 left
kareladb> id | name                
---+---------------------
58 | Northgate Securities
(1 row, 0.0 ms)
1 row(s) fetched, no more rows
kareladb> cursor 'b' closed
kareladb>
```

**HTTP: An HTTP session: DECLARE in one request, FETCH in the next** (sample data: sample)

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

DECLARE b CURSOR FOR SELECT id, name FROM brokers ORDER BY id
###
POST /exec
X-KDB-Session: {{session}}

FETCH NEXT 3 FROM b
###
DELETE /session/{{session}}
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "9a69742d738daf79c5a200d20ae64a66", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "DECLARE b CURSOR FOR SELECT id, name FROM brokers ORDER BY id",
  "results": [
    {
      "statement": "DECLARE b CURSOR FOR SELECT id, name FROM brokers ORDER BY id",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "cursor 'b' declared: 5 row(s)",
      "timings": {"parse_us": 35, "execute_us": 303}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 35, "execute_us": 303}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "FETCH NEXT 3 FROM b",
  "results": [
    {
      "statement": "FETCH NEXT 3 FROM b",
      "columns": [
        {"name": "id", "type": "INT"},
        {"name": "name", "type": "STRING"}
      ],
      "dataset": [
        [1, "Keystone Securities"],
        [34, "Vision Securities"],
        [45, "Imperial Securities"]
      ],
      "count": 3,
      "truncated": false,
      "rows_affected": 0,
      "message": "3 row(s) fetched, 2 left",
      "timings": {"parse_us": 14, "execute_us": 8}
    }
  ],
  "columns": [
    {"name": "id", "type": "INT"},
    {"name": "name", "type": "STRING"}
  ],
  "dataset": [
    [1, "Keystone Securities"],
    [34, "Vision Securities"],
    [45, "Imperial Securities"]
  ],
  "count": 3,
  "timings": {"parse_us": 14, "execute_us": 8}
}
```

`DELETE /session/{{session}}`

HTTP 200 (application/json)

```text
{"session": "9a69742d738daf79c5a200d20ae64a66", "closed": true}
```

<a id="http"></a>

## Cursors over HTTP: POST /cursor

Syntax:

```sql
POST   /cursor                 body: one SELECT     -> {"cursor": "<id>", "columns": [...], "rows": N}
GET    /cursor/<id>?fetch=N                          -> {"cursor", "columns", "dataset", "count", "done"}
DELETE /cursor/<id>                                  -> {"cursor": "<id>", "closed": true}
```

An app does not need SQL cursor statements over HTTP. `POST /cursor` runs one `SELECT` and keeps the rows on the server; `GET /cursor/<id>?fetch=N` returns the next N rows; `DELETE` closes it.
The full description is in [HTTP sessions and cursors](http-sessions-and-cursors.md).

- **Notes:**
  - `fetch` is 1,000 when you do not give it. `done` is `true` when no rows are left.
  - The id is long and random, so another client cannot guess it. No session is needed.
  - Use the same database (`db=` or the header `X-KDB-Database`) for all requests of one cursor.
  - HTTP cursors count toward the same 16 open cursors of the database.
  - A closed or unknown cursor answers HTTP 404.

**HTTP: Page through the trade log over HTTP** (sample data: sample)

```http
POST /cursor

SELECT transaction_id, symbol, quantity, rate FROM trade_log WHERE date = '2026-09-09' ORDER BY transaction_id
###
GET /cursor/{{cursor}}?fetch=3
###
GET /cursor/{{cursor}}?fetch=3
###
DELETE /cursor/{{cursor}}
###
GET /cursor/{{cursor}}?fetch=3
```

Response:

`POST /cursor`

HTTP 200 (application/json)

```text
{
  "cursor": "2027cfc9affbc0e2",
  "columns": [
    {"name": "transaction_id", "type": "LONG"},
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "quantity", "type": "LONG"},
    {"name": "rate", "type": "DOUBLE"}
  ],
  "rows": 8
}
```

`GET /cursor/{{cursor}}?fetch=3`

HTTP 200 (application/json)

```text
{
  "cursor": "2027cfc9affbc0e2",
  "columns": [
    {"name": "transaction_id", "type": "LONG"},
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "quantity", "type": "LONG"},
    {"name": "rate", "type": "DOUBLE"}
  ],
  "dataset": [
    [100001, "TELCO", 1000, 881],
    [100002, "CITY", 10, 515],
    [100003, "CITY", 500, 513]
  ],
  "count": 3,
  "done": false
}
```

`GET /cursor/{{cursor}}?fetch=3`

HTTP 200 (application/json)

```text
{
  "cursor": "2027cfc9affbc0e2",
  "columns": [
    {"name": "transaction_id", "type": "LONG"},
    {"name": "symbol", "type": "SYMBOL"},
    {"name": "quantity", "type": "LONG"},
    {"name": "rate", "type": "DOUBLE"}
  ],
  "dataset": [
    [100004, "CITY", 500, 514.5],
    [100005, "CITY", 500, 517],
    [100006, "COAST", 200, 401]
  ],
  "count": 3,
  "done": false
}
```

`DELETE /cursor/{{cursor}}`

HTTP 200 (application/json)

```text
{"cursor": "2027cfc9affbc0e2", "closed": true}
```

`GET /cursor/{{cursor}}?fetch=3`

HTTP 404 (application/json)

```text
{"error": "cursor '2027cfc9affbc0e2' does not exist (an unused cursor closes after 10 minutes)"}
```

<a id="limits"></a>

## Limits of cursors

Syntax:

```sql
DECLARE c17 CURSOR FOR SELECT ...   -- error when 16 cursors are open in the database
```

| Limit | Value |
|---|---|
| Open cursors in one database (SQL and HTTP together) | 16 (`DatabaseOptions::max_cursors`) |
| A cursor without `FETCH` closes after | 10 minutes (`DatabaseOptions::cursor_idle_ms`) |
| Rows in one cursor | 10 million. A bigger query is refused: narrow it with `WHERE`. |
| Rows of one `FETCH` | the row limit of the request (for example `/exec` returns at most 1,000,000 rows) |
| Memory | all rows of an open cursor are kept in memory until it closes |

**Example: The 17th open cursor** (shows an error)

```sql
DECLARE c1 CURSOR FOR SELECT 1 AS x;
DECLARE c2 CURSOR FOR SELECT 2 AS x;
DECLARE c3 CURSOR FOR SELECT 3 AS x;
DECLARE c4 CURSOR FOR SELECT 4 AS x;
DECLARE c5 CURSOR FOR SELECT 5 AS x;
DECLARE c6 CURSOR FOR SELECT 6 AS x;
DECLARE c7 CURSOR FOR SELECT 7 AS x;
DECLARE c8 CURSOR FOR SELECT 8 AS x;
DECLARE c9 CURSOR FOR SELECT 9 AS x;
DECLARE c10 CURSOR FOR SELECT 10 AS x;
DECLARE c11 CURSOR FOR SELECT 11 AS x;
DECLARE c12 CURSOR FOR SELECT 12 AS x;
DECLARE c13 CURSOR FOR SELECT 13 AS x;
DECLARE c14 CURSOR FOR SELECT 14 AS x;
DECLARE c15 CURSOR FOR SELECT 15 AS x;
DECLARE c16 CURSOR FOR SELECT 16 AS x;
DECLARE c17 CURSOR FOR SELECT 17 AS x;
```

Result:

`DECLARE c1 CURSOR FOR SELECT 1 AS x`

```text
cursor 'c1' declared: 1 row(s)
```

`DECLARE c2 CURSOR FOR SELECT 2 AS x`

```text
cursor 'c2' declared: 1 row(s)
```

`DECLARE c3 CURSOR FOR SELECT 3 AS x`

```text
cursor 'c3' declared: 1 row(s)
```

`DECLARE c4 CURSOR FOR SELECT 4 AS x`

```text
cursor 'c4' declared: 1 row(s)
```

`DECLARE c5 CURSOR FOR SELECT 5 AS x`

```text
cursor 'c5' declared: 1 row(s)
```

`DECLARE c6 CURSOR FOR SELECT 6 AS x`

```text
cursor 'c6' declared: 1 row(s)
```

`DECLARE c7 CURSOR FOR SELECT 7 AS x`

```text
cursor 'c7' declared: 1 row(s)
```

`DECLARE c8 CURSOR FOR SELECT 8 AS x`

```text
cursor 'c8' declared: 1 row(s)
```

`DECLARE c9 CURSOR FOR SELECT 9 AS x`

```text
cursor 'c9' declared: 1 row(s)
```

`DECLARE c10 CURSOR FOR SELECT 10 AS x`

```text
cursor 'c10' declared: 1 row(s)
```

`DECLARE c11 CURSOR FOR SELECT 11 AS x`

```text
cursor 'c11' declared: 1 row(s)
```

`DECLARE c12 CURSOR FOR SELECT 12 AS x`

```text
cursor 'c12' declared: 1 row(s)
```

`DECLARE c13 CURSOR FOR SELECT 13 AS x`

```text
cursor 'c13' declared: 1 row(s)
```

`DECLARE c14 CURSOR FOR SELECT 14 AS x`

```text
cursor 'c14' declared: 1 row(s)
```

`DECLARE c15 CURSOR FOR SELECT 15 AS x`

```text
cursor 'c15' declared: 1 row(s)
```

`DECLARE c16 CURSOR FOR SELECT 16 AS x`

```text
cursor 'c16' declared: 1 row(s)
```

Error: `too many open cursors (16); CLOSE the ones you do not need (an unused cursor also closes after 10 minutes)`
