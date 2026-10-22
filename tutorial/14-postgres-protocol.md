# 14. PostgreSQL protocol

- Category: Tutorial

## What you will learn

- How `kareladb serve` speaks the **PostgreSQL protocol** on port **8832**.
- How to connect from Go (`pgx`), Python, Node, `psql` and DBeaver.
- How KarelaDB types become Postgres types. How times work.
- Transactions, error codes, and what does not work yet.

KarelaDB is not PostgreSQL. But it speaks the same "wire protocol" (the messages between a program and the database). So a normal Postgres driver can send SQL to KarelaDB and read the rows. You write **KarelaDB SQL** (chapter 11). Much everyday PostgreSQL SQL works too: `SERIAL`, `ON CONFLICT`, `RETURNING`, `WITH`, arrays, `information_schema` (chapters 22 and 23).

## Start the server

`kareladb serve` starts the Postgres port together with the HTTP port:

```powershell
kareladb serve --token my-long-secret
```

```text
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  postgres  127.0.0.1:8832 (PostgreSQL protocol, no TLS; password = the token)
  ...
```

Options:

| Option | Meaning | Default |
|---|---|---|
| `--pg-port N` | The Postgres port. `--pg-port 0` turns it off. | `8832` |
| `--bind ADDRESS` | The address for **both** ports (HTTP and Postgres). | `127.0.0.1` |
| `--token T` | The password for every Postgres user. | none |
| `--pg-timestamptz` | Send KarelaDB `TIMESTAMP` as `timestamptz` (see [Times](#times)). | off |

## Security: read this first

- **No TLS.** KarelaDB answers "no" when a client asks for TLS (SSL). The password is safe (SCRAM-SHA-256 never sends it), but **the data is not encrypted**.
- So keep port 8832 on `127.0.0.1` (the default). Your Go backend on the same VPS connects to `127.0.0.1`.
- From your PC, use an **SSH tunnel**:

  ```powershell
  ssh -N -L 8832:127.0.0.1:8832 user@your-vps
  ```

  Then connect to `127.0.0.1:8832` on your PC. The tunnel encrypts everything.
- **Without `--token`**, only programs on the same computer (`127.x.x.x`) can connect, and no password is asked. Other computers are refused.
- **With `--token`**, every user name works, and the password is the token.
- **With users** (chapter 16), log in with a KarelaDB user name and its password (SCRAM-SHA-256). Each statement runs with that user's role; a refused one gets SQLSTATE `42501`. Connecting needs at least `read` on the database. With users **and** `--token`, a name that is not a KarelaDB user may still log in with the token. Failed logins are slowed down like HTTP logins.
- Clients must use `sslmode=disable` or `sslmode=prefer` (the default of most drivers). `sslmode=require` fails, because there is no TLS.

## Connection settings

| Setting | Value |
|---|---|
| Host | `127.0.0.1` |
| Port | `8832` |
| User | any name (for example `app`) |
| Password | the `--token` value |
| Database | a KarelaDB database name, like `db=` in the HTTP API. Empty, `postgres` or the user name means the **default** database. |

A connection string:

```text
postgres://app:my-long-secret@127.0.0.1:8832/market?sslmode=disable
```

## Go (pgx)

This is how the NChartPro backend connects. Nothing special is needed.

```go
package main

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, "postgres://app:my-long-secret@127.0.0.1:8832/market?sslmode=disable")
	if err != nil {
		panic(err)
	}
	defer pool.Close()

	// Parameters $1, $2, ... work. The values never become part of the SQL text.
	_, err = pool.Exec(ctx, "INSERT INTO securities (symbol, name, sector) VALUES ($1, $2, $3)",
		"COAST", "Coastal Bank", "Banking")
	if err != nil {
		panic(err)
	}

	rows, err := pool.Query(ctx,
		"SELECT time, close, volume FROM ochl_day WHERE symbol = $1 AND time >= $2 ORDER BY time",
		"CITY", time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC))
	if err != nil {
		panic(err)
	}
	defer rows.Close()
	for rows.Next() {
		var t time.Time
		var close, volume float64
		if err := rows.Scan(&t, &close, &volume); err != nil {
			panic(err)
		}
		fmt.Println(t.Format("2006-01-02"), close, volume)
	}
}
```

Everything pgx does works: the pool, `QueryRow`, `pgx.CollectRows` with `RowToStructByName`, `Begin`/`Commit`/`Rollback`, batches (`SendBatch`), and all query modes (the default cached statements, `QueryExecModeSimpleProtocol`, `Exec`, `DescribeExec`, `CacheDescribe`).

The test program `tests/pg_go/main.go` checks all of this against a real server. Its real output:

```text
ok   connect and ping (SCRAM-SHA-256 login)
ok   version() = "PostgreSQL 14.0 (KDB 0.2.0-dev), compatible server", database "default"
ok   create table
ok   insert with parameters (int, text, float, numeric, bool, time, NULL)
ok   select with a parameter: {ID:1 Email:asha@example.com Balance:10.5 Active:true Created:2026-09-11 05:15:00.123 +0000 UTC} price 512.40
ok   pgx.CollectRows into structs: 2 rows
ok   LIKE, IN and LIMIT parameters
ok   transactions: rollback and commit
ok   unique violation: SQLSTATE 23505 (a row with id='1' already exists in 'users'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it)
ok   unknown table 42P01; error inside a transaction, then rollback
ok   batch of 4 statements
ok   query modes: simple protocol, exec, describe exec, cache describe
ALL OK
```

Run it yourself:

```powershell
kareladb serve --data-dir D:\kdb-pg-test --port 9950 --pg-port 8850 --token secret-token
# in another window:
cd tests\pg_go
go run . "postgres://app:secret-token@127.0.0.1:8850/default"
```

## Python

`psycopg` (version 3) and `psycopg2` use the normal Postgres protocol, so they work the same way. The pure-Python driver **pg8000** was tested (`tests/pg_python/check_pg8000.py`):

```python
import pg8000.native

con = pg8000.native.Connection("app", host="127.0.0.1", port=8832,
                               database="market", password="my-long-secret")
rows = con.run("SELECT time, close FROM ochl_day WHERE symbol = :s ORDER BY time", s="CITY")
for t, close in rows:
    print(t, close)
con.close()
```

With psycopg:

```python
import psycopg

with psycopg.connect("host=127.0.0.1 port=8832 dbname=market user=app password=my-long-secret sslmode=disable") as con:
    for row in con.execute("SELECT symbol, close FROM ochl_day WHERE close > %s", (500,)):
        print(row)
```

(psycopg was not run on the test PC: it has no build for its Python version yet.)

## Node (pg)

```javascript
const { Client } = require('pg');

const client = new Client({
  host: '127.0.0.1', port: 8832, user: 'app',
  password: 'my-long-secret', database: 'market',
});
await client.connect();
const res = await client.query('SELECT symbol, close FROM ochl_day WHERE symbol = $1', ['CITY']);
console.log(res.rows);
await client.end();
```

This was tested. **Note about times:** `node-pg` reads a `timestamp` (without time zone) as your computer's **local** time. On a PC set to Nepal time (+05:45), 05:15 UTC comes back as 23:30 of the day before. Start the server with `--pg-timestamptz` and times come back right.

Numbers: `node-pg` gives `LONG` and `DECIMAL` values as strings (`'182390'`, `'512.40'`), as with PostgreSQL.

## psql

```powershell
$env:PGPASSWORD = "my-long-secret"
psql "host=127.0.0.1 port=8832 dbname=market user=app sslmode=disable"
```

```text
market=> SELECT symbol, close FROM ochl_day WHERE symbol = 'CITY' LIMIT 2;
market=> BEGIN;
market=*> INSERT INTO brokers VALUES (99, 'Test Broker');
market=*> ROLLBACK;
```

Plain SQL works. KarelaDB also answers the Postgres catalog (`pg_catalog`, `information_schema`), so `\l` (databases), `\dt` (tables), `\di` (indexes) and `\du` work. A full `\d ochl_day` still fails on one of the queries psql sends; use `SHOW COLUMNS FROM ochl_day;` and `SHOW CREATE TABLE ochl_day;` instead. `\du` shows one user, `kareladb`: use `SHOW USERS;` for the real list.

`\copy` works too, because psql sends it as `COPY ... FROM STDIN` (see [Loading many rows: COPY](#loading-many-rows-copy)).

(psql is not installed on the test PC, so this example was not run.)

## DBeaver

1. **New Database Connection** → **PostgreSQL**.
2. Host `127.0.0.1`, port `8832`, database `market`, user `app`, password = the token.
3. **Driver properties**: set `sslmode` to `disable`.
4. **Connection settings → Initialization**: turn off "Show all databases".
5. Open an **SQL editor** and run KarelaDB SQL.

The SQL editor and the result grid work. The **Database Navigator** (the tree of schemas and tables) reads the Postgres catalog, which KarelaDB answers: it lists the tables, their columns with types and defaults, indexes and constraints. Sizes stay empty, and row counts are not known.

(DBeaver was not run on the test PC.)

## Types

| KarelaDB type | Postgres type (OID) | Go (pgx) |
|---|---|---|
| `BOOL` | `bool` (16) | `bool` |
| `BYTE`, `SHORT` | `int2` (21) | `int16` |
| `INT` | `int4` (23) | `int32` |
| `LONG` | `int8` (20) | `int64` |
| `FLOAT` | `float4` (700) | `float32` |
| `DOUBLE` | `float8` (701) | `float64` |
| `DECIMAL(s)` | `numeric` (1700) | `pgtype.Numeric`, `float64`, `string` |
| `DATE` | `date` (1082) | `time.Time` |
| `TIMESTAMP` | `timestamp` (1114), or `timestamptz` (1184) with `--pg-timestamptz` | `time.Time` |
| `SYMBOL`, `STRING` | `text` (25) | `string` |
| `JSON` | `json` (114) | `string`, `[]byte`, a struct |
| `BYTES` | `bytea` (17) | `[]byte` |

Values go both ways in **text** and **binary** form. A driver picks the form; you do not have to.

**Parameters get their type from where you use them.** In `WHERE volume > $1`, `$1` is `LONG` because `volume` is `LONG`. In `INSERT INTO t (a, b) VALUES ($1, $2)`, each parameter gets its column's type. A parameter KarelaDB cannot place (`SELECT $1`) has no type; the driver then sends it as text.

**Computed columns.** Before a query runs, KarelaDB works out the type of each result column. For columns, `count(*)`, `sum`, `avg`, arithmetic and most functions it knows the type. For a few (a saved function, say) it runs the query once with empty values to learn it. If a type is still unknown, the column is `text`. When Go then says `cannot scan text into *float64`, add a cast: `SELECT my_func(close)::DOUBLE AS x ...`.

## Times

KarelaDB keeps a `TIMESTAMP` as one exact moment in **UTC** (chapter 4).

By default it is sent as Postgres `timestamp` (without time zone), like QuestDB does. With this type, drivers **drop the time zone** of a value you send:

- pgx: a Go `time.Time` in a local time (for example 11:00 +05:45) is stored as 11:00 **UTC**. Always send **UTC** times: `t.UTC()`.
- node-pg: times you read come back in the computer's local time zone (see above).

Start the server with **`--pg-timestamptz`** to send `TIMESTAMP` as `timestamptz`. Then every driver keeps the exact moment, in any time zone. pgx then gives `time.Time` values in the local time zone of the Go program (the same moment). Choose one setting and keep it.

Times have **milliseconds**. Microseconds from a driver are cut.

## Transactions

`BEGIN`, `COMMIT` and `ROLLBACK` work across messages, one transaction per connection. Postgres forms are accepted too: `BEGIN ISOLATION LEVEL ...`, `START TRANSACTION`, `END`, `ABORT`. (Every KarelaDB transaction is serializable; the level is ignored.)

When a statement fails inside a transaction, the transaction is **aborted**, like in PostgreSQL. Every next statement gets error `25P02` until you send `ROLLBACK` (a `COMMIT` then also rolls back, and its tag is `ROLLBACK`). pgx does this for you: `tx.Rollback(ctx)`.

- **One writer per table** (chapter 15). While one connection has an open transaction, a change of one of its tables from another connection waits up to 5 seconds, then fails with `55P03` (`table 'x' is busy`). Changes of other tables go on; a deadlock fails at once with `40P01`. Reads do not wait. Keep transactions short.
- A transaction with no statement for **30 seconds** is rolled back. The connection then gets `25P02` until it sends `ROLLBACK`.
- When a connection closes, its open transaction is rolled back.

`INSERT`, `UPDATE` and `DELETE` with `RETURNING` give rows, like a `SELECT` (in Go: `pool.QueryRow(ctx, "INSERT ... RETURNING id", ...).Scan(&id)`).

## Errors

Errors carry a **SQLSTATE** code, so `errors.As(err, &pgErr)` and `pgErr.Code` work in Go:

| Code | Meaning |
|---|---|
| `42601` | Syntax error (the message has `line X, column Y`; the error also has the position) |
| `42P01` | Unknown table or view |
| `42703` | Unknown column |
| `23505` | Unique key used twice (PRIMARY KEY, UNIQUE) |
| `23503` | REFERENCES: the row it points to is missing, or is still used |
| `23502` | NOT NULL column without a value |
| `23514` | CHECK constraint failed |
| `25P02` | The transaction failed before (or was idle too long); send ROLLBACK |
| `55P03` | Busy: another transaction held the table for 5 seconds; try again |
| `40P01` | Deadlock: two transactions waited for each other; this one was rolled back. Run it again |
| `42501` | The user's role or table rights do not allow this statement |
| `57014` | The statement was stopped: statement timeout, a CancelRequest, server shutdown |
| `54000` | The query keeps too much in memory (`--max-result-memory`, `--max-groups`) |
| `25006` | The database or the server is read-only |
| `28P01` | Wrong password |
| `3D000` | Unknown database |
| `53300` | Too many connections (at most 100) |
| `XX000` | Anything else (read the message) |

## What drivers send, and KarelaDB answers

Drivers send a few Postgres commands that KarelaDB SQL does not have. KarelaDB answers them itself:

| Command | Answer |
|---|---|
| `SET name = value` / `SET name TO value` | accepted and remembered (`client_encoding` must be UTF8) |
| `SET statement_timeout = 5000` (or `'5s'`), `SET safe_updates = on` | KarelaDB uses them (chapter 21); a user who is not an admin can only make the timeout shorter than the server's |
| CancelRequest (Ctrl+C in psql, a cancelled context in pgx) | stops the running statement of that connection: `57014` |
| `SHOW server_version`, `SHOW TimeZone`, ... | the setting; `server_version` is `14.0 (KarelaDB ...)` |
| `SELECT version()` | `PostgreSQL 14.0 (KDB 0.2.0-dev), compatible server` |
| `SELECT current_database()` | the KarelaDB database name |
| `SELECT current_user`, `current_schema()` | the user name, `public` |
| `RESET ...`, `DISCARD ALL`, `DEALLOCATE ...` | accepted |

`SHOW TABLES`, `SHOW COLUMNS FROM t` and the other KarelaDB `SHOW` statements still work as KarelaDB statements.

## Loading many rows: COPY

`COPY` is the fast way to load many rows over this port. pgx `CopyFrom` sends it, and so does psql's `\copy`. It loads hundreds of thousands of rows a second, about 1,000 times faster than one `INSERT` per round trip.

| Written as | What it does |
|---|---|
| `COPY t (a, b) FROM STDIN (FORMAT binary)` | what pgx `CopyFrom` sends; the fastest form |
| `COPY t FROM STDIN` | text: tab between values, `\N` for NULL |
| `COPY t FROM STDIN WITH (FORMAT csv, HEADER)` | CSV, with quotes and an optional header line |
| `COPY t TO STDOUT`, `COPY (SELECT ...) TO STDOUT` | reads rows out, in text, CSV or binary |

```go
rows := [][]any{{int64(101), "Everest Capital"}, {int64(102), "Summit Traders"}}
n, err := pool.CopyFrom(ctx, pgx.Identifier{"brokers"}, []string{"id", "name"}, pgx.CopyFromRows(rows))
```

- **All or nothing.** One bad row (a wrong type, a key used twice, an empty `NOT NULL` column) fails the whole `COPY`, and nothing is written. The error names the row: `COPY brokers: row 301: ...`.
- Inside `BEGIN` ... `COMMIT` the rows join the transaction; `ROLLBACK` removes them.
- A file name instead of `STDIN` or `STDOUT` is refused: KarelaDB never reads or writes files on the server for a client.

## Not supported yet

- **TLS** (use localhost or an SSH tunnel).
- A few parts of the **Postgres catalog**: a full psql `\d <table>` (use `SHOW COLUMNS`), sizes and row counts in the catalog tables, the real user list in `pg_roles` (use `SHOW USERS`).
- **Postgres SQL** that KarelaDB does not have (for example `::regclass`, `MERGE`). Chapters 22 and 23 list what works.
- `LISTEN`/`NOTIFY` (accepted, but no notifications come), functions calls of the old protocol, `SAVEPOINT`.
- Parameters in `FILL(...)`, `SAMPLE BY` and other places where KarelaDB needs a fixed value. `LIMIT $1` and `OFFSET $1` work.
- A simple query with several statements is not one transaction: statements before an error stay done. Use `BEGIN` ... `COMMIT`.
- `SET ROLE`, `CREATE ROLE`, PostgreSQL's full `GRANT` syntax: KarelaDB has users with roles per database (chapter 16) and `GRANT SELECT|INSERT|UPDATE|DELETE ON TABLE t TO user` (chapter 21); no column or row rights.
- Users with **two-factor login** (chapter 21) cannot log in on this port (a driver cannot ask for the code). Give programs their own user.
