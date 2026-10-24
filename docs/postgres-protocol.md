# PostgreSQL protocol (port 8832)

> Connect to KarelaDB with PostgreSQL tools and drivers - psql, DBeaver, Python, Node, C#, Go - and what works and what does not.

- Category: Postgres protocol
- Keywords: postgres, postgresql, pg, wire protocol, port 8832, --pg-port, --pg-timestamptz, --pg-int-division, int\_division, integer division, pg\_compat, kdb.pg\_compat, --pg-compat, PostgreSQL-compatible results, NUMERIC, RANGE UNBOUNDED PRECEDING, NULLS FIRST, collation, en\_US, wall clock, psql, DBeaver, psycopg, psycopg2, pg8000, node-pg, Npgsql, pgx, Go, driver, SCRAM-SHA-256, sslmode, TLS, SSH tunnel, SQLSTATE, OID, timestamptz, $1, parameters, prepared statement, RETURNING, 25P02, 23505, 23503, 23001, P0001, ConstraintName, TableName, ERRCODE, RAISE, 55P03, 42501, 3D000, 28P01, 53100, disk full, 57014, pg\_catalog, information\_schema, COPY, COPY FROM STDIN, COPY TO STDOUT, CancelRequest, cancel query, streaming, big result, whole table, fetch size, setFetchSize, portal, max\_rows, PortalSuspended, max\_result\_memory
- See also: [Logins, tokens and roles over HTTP](http-login.md), [Users and roles](users-and-roles.md), [Transactions](transactions.md), [Column types](column-types.md), [Time and time zones](time-and-time-zones.md), [Keeping kareladb serve safe](server-security.md), [kareladb serve](cli-serve.md), [Grafana and Prometheus](grafana.md)

KarelaDB is not PostgreSQL, but `kareladb serve` speaks PostgreSQL's **wire protocol**: the messages a Postgres driver and the database send each other. So a normal Postgres driver or tool can connect to KarelaDB, send SQL and read the rows.

- You write **KarelaDB SQL** (the SQL of this help), not PostgreSQL's SQL.
- The port is **8832** (QuestDB uses 8812). It starts together with the HTTP port.
- Without [TLS](tls.md) the data is not encrypted: keep the port on `127.0.0.1`, or use an SSH tunnel. With `kareladb serve --tls-cert ...` clients connect with `sslmode=require`.

Tutorial: [chapter 14, PostgreSQL protocol](../tutorial/14-postgres-protocol.md). The Postgres port cannot be run by this help's example runner, so every example here is plain text; which ones were run on a real server is said under each.

<a id="start"></a>

## Start the Postgres port

Syntax:

```sql
kareladb serve [--pg-port 8832] [--pg-timestamptz] [--bind 127.0.0.1] [--token <secret>]
```

| Option | Meaning | Default |
|---|---|---|
| `--pg-port N` | The Postgres port. `--pg-port 0` turns it off. | `8832` |
| `--pg-timestamptz` | Send KarelaDB `TIMESTAMP` columns as Postgres `timestamptz` (a moment in time with a zone) instead of `timestamp`. See [times](postgres-protocol.md#times). | off |
| `--pg-int-division on\|off` | `on`: whole number / whole number gives a whole number on this port, as in PostgreSQL (`7 / 2` is `3`). Also `KARELADB_PG_INT_DIVISION`. See [integer division](postgres-protocol.md#int-division). | off |
| `--pg-compat on\|off` | `on`: PostgreSQL 14's answers for every database without its own `pg_compat` setting. Also `KARELADB_PG_COMPAT`. **Waiting for the owner's decision; keep it off.** See [PostgreSQL-compatible results](postgres-protocol.md#pg-compat). | off |
| `--bind ADDRESS` | The network address of **both** ports (HTTP and Postgres) | `127.0.0.1` |
| `--token SECRET` | The password of every Postgres user when there are no KarelaDB users | none |

When the port is on, `kareladb serve` prints a `postgres` line. Real output from [chapter 14](../tutorial/14-postgres-protocol.md):

```text
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  postgres  127.0.0.1:8832 (PostgreSQL protocol, no TLS; password = the token)
  ...
```

- If port 8832 is already used by another program, `kareladb serve` stops with `error: Postgres protocol port: ... (use --pg-port N, or --pg-port 0 to turn it off)`.
- At most 500 logged-in connections at the same time, for all databases together (`kareladb serve --max-connections N`, `KARELADB_MAX_CONNECTIONS` or `max_connections` in `kareladb.conf`; `0` = no limit). One more gets SQLSTATE `53300` (`sorry, too many clients already`). A closed connection's place is free again at once, so a pool that closes and reopens its connections gets them back.
- One message (for example one big INSERT) can be up to 256 MB.

<a id="settings"></a>

## Connection settings

| Setting | Value |
|---|---|
| Host | `127.0.0.1` (or the `--bind` address) |
| Port | `8832` |
| User | a KarelaDB user name; without KarelaDB users, any name (for example `app`) |
| Password | the KarelaDB user's password, or the `--token` ([passwords](postgres-protocol.md#passwords)) |
| Database | a KarelaDB database name, like `db=` of the HTTP API. Empty, `postgres`, `template1` or the user name (when no database has that name) means the **default** database. |
| SSL mode | without TLS: `disable` or `prefer` (`require` fails). With [TLS](tls.md) on: `require`, or `verify-full` with the certificate. |

A connection string (URL form and key=value form):

```text
postgres://app:my-long-secret@127.0.0.1:8832/market?sslmode=disable
host=127.0.0.1 port=8832 dbname=market user=app password=my-long-secret sslmode=disable
```

- An unknown database: the connection is refused with SQLSTATE `3D000` and `database 'x' does not exist`.
- The server's time zone is `UTC`, the encoding `UTF8`, `DateStyle` `ISO, MDY`. `server_version` is `14.0 (KarelaDB <version>)`, so drivers treat KarelaDB like PostgreSQL 14.

<a id="passwords"></a>

## Passwords and logins

| Server | How to log in |
|---|---|
| no KarelaDB users, no `--token` | no password. **Only** programs on the same computer (`127.x.x.x`) may connect; others get `28000` `connections from other computers need a password`. |
| `--token <secret>`, no users | any user name; the password is the token. Full rights. |
| KarelaDB users (`CREATE USER`, `kareladb user add`) | a KarelaDB user name and its password. Each statement runs with that user's role. |
| users **and** `--token` | KarelaDB users with their passwords; a name that is not a KarelaDB user may log in with the token (full rights) |

- The login uses **SCRAM-SHA-256**: the password itself never crosses the network, even without TLS. (Without [TLS](tls.md) the data does cross the network unencrypted.)
- A wrong password or an unknown user: `28P01` `password authentication failed for user "..."` (the same for both).
- Connecting as a KarelaDB user needs at least `read` on the database (`42501` otherwise). A statement the role does not allow gets `42501`, and nothing of it runs.
- Failed logins count together with HTTP logins: after 5 failures for one user from one address, the next try must wait (1 s, 2 s, 4 s, ... up to 15 minutes); meanwhile the answer is `28000` `too many failed logins; try again in N s`.
- The `--token` login is the exception: a name that must wait is not refused before the password. The right token still gets in (and ends the waiting); only a wrong token gets `28000` `too many failed logins; try again in N s`. Behind Docker every client has the same address and most send the same name (`postgres`), so one client with an old token cannot lock the others out. The token itself is therefore not slowed down by failed logins: make it long and random (for example `openssl rand -hex 32`).
- More: [users and roles](users-and-roles.md), [logins over HTTP](http-login.md).

## psql

`psql` is PostgreSQL's command line tool. Not run while writing this help (psql was not installed on the test PC).

```powershell
$env:PGPASSWORD = "my-long-secret"
psql "host=127.0.0.1 port=8832 dbname=market user=app sslmode=disable"
```

```text
market=> SELECT symbol, close FROM ochl_day WHERE symbol = 'CITY' LIMIT 2;
market=> BEGIN;
market=*> INSERT INTO brokers VALUES (99, 'Test Broker');
market=*> ROLLBACK;
market=> SHOW TABLES;
```

- Plain SQL works.
- The backslash commands read the Postgres catalog. KarelaDB answers them from a read-only catalog ([catalog](#catalog)). Tested with the exact queries psql 14, 15 and 16 send:

| Command | Shows |
|---|---|
| `\l`, `\dt`, `\dt+`, `\di`, `\di+`, `\dv`, `\du` | databases, tables, indexes, views, users |
| `\d table`, `\d+ table` | columns, types, defaults, NOT NULL, indexes, CHECKs, foreign keys, "Referenced by" |
| `\d view`, `\d+ view` | the view's columns and its query |
| `\d index` | the index's columns, method and table |

- Sizes in `\dt+` are real: the table's files on disk, plus its new rows still in the log. Indexes show `0 bytes`: KarelaDB keeps them in memory only. `SHOW TABLES;`, `SHOW COLUMNS FROM ochl_day;` and `SHOW DATABASES;` always work.
- `\copy` works: it sends `COPY ... FROM STDIN` or `TO STDOUT` ([COPY](#copy)).
- Ctrl+C sends a cancel request, which stops the running statement.

## DBeaver

DBeaver is a free database tool with a SQL editor. Not run while writing this help.

1. **New Database Connection**, then **PostgreSQL**.
2. Host `127.0.0.1`, port `8832`, database `market`, user `app`, password = the token (or the KarelaDB user's password).
3. **Driver properties**: set `sslmode` to `disable`.
4. **Connection settings**, **Initialization**: turn off "Show all databases".
5. Open an **SQL editor** and run KarelaDB SQL.

The SQL editor and the result grid work. The **Database Navigator** (the tree of schemas and tables) reads the Postgres catalog; KarelaDB has a read-only one ([catalog](#catalog)), but not everything DBeaver asks for. When the tree stays empty, use `SHOW TABLES` in the editor.

<a id="python"></a>

## Python (psycopg, pg8000)

With **psycopg** (version 3). Not run on the test PC (no psycopg build for its Python version yet):

```python
import psycopg

with psycopg.connect("host=127.0.0.1 port=8832 dbname=market user=app password=my-long-secret sslmode=disable") as con:
    # %s are parameters: psycopg sends the values apart from the SQL.
    for row in con.execute("SELECT symbol, close FROM ochl_day WHERE close > %s ORDER BY close DESC LIMIT 5", (500,)):
        print(row)

    with con.transaction():   # BEGIN ... COMMIT (ROLLBACK on an exception)
        con.execute("INSERT INTO brokers VALUES (%s, %s)", (99, "Test Broker"))
```

With **pg8000** (a Python-only driver). This was tested: `tests/pg_python/check_pg8000.py` runs these steps against a real server and prints `ALL OK`:

```python
import pg8000.native

con = pg8000.native.Connection("app", host="127.0.0.1", port=8832, database="market", password="my-long-secret")
print(con.run("SELECT version()")[0][0])
rows = con.run("SELECT time, close FROM ochl_day WHERE symbol = :s ORDER BY time", s="CITY")
for t, close in rows:
    print(t, close)
con.close()
```

- `TIMESTAMP` values come back as `datetime` without a zone; they are UTC. With `--pg-timestamptz` they come back with the UTC zone.
- `DECIMAL` comes back as `decimal.Decimal`.

<a id="node"></a>

## Node (pg)

The `pg` package. Tested ([chapter 14](../tutorial/14-postgres-protocol.md)):

```js
const { Client } = require("pg");

const client = new Client({ host: "127.0.0.1", port: 8832, user: "app", password: "my-long-secret", database: "market" });
await client.connect();
const res = await client.query("SELECT symbol, close FROM ochl_day WHERE symbol = $1 ORDER BY time DESC LIMIT 3", ["CITY"]);
console.log(res.rows);
await client.end();
```

- **Times:** `pg` reads a Postgres `timestamp` (without zone) as your computer's **local** time. On a PC in Nepal, 05:15 UTC comes back as 23:30 of the day before. Start the server with `--pg-timestamptz` and the times come back right.
- **Numbers:** `pg` gives `LONG` (int8) and `DECIMAL` (numeric) values as strings (`'182390'`, `'512.40'`), as with PostgreSQL.

<a id="csharp"></a>

## C# (Npgsql)

**Not tested** with KarelaDB. Npgsql normally reads the Postgres type catalog when it connects, and KarelaDB's catalog is only a small one: turn that off with `Server Compatibility Mode=NoTypeLoading`.

```csharp
using Npgsql;

var cs = "Host=127.0.0.1;Port=8832;Username=app;Password=my-long-secret;Database=market;" +
         "SSL Mode=Disable;Server Compatibility Mode=NoTypeLoading";
await using var dataSource = NpgsqlDataSource.Create(cs);

await using (var cmd = dataSource.CreateCommand("SELECT time, close FROM ochl_day WHERE symbol = $1 ORDER BY time"))
{
    cmd.Parameters.Add(new NpgsqlParameter { Value = "CITY" });
    await using var reader = await cmd.ExecuteReaderAsync();
    while (await reader.ReadAsync())
        Console.WriteLine($"{reader.GetDateTime(0):yyyy-MM-dd} {reader.GetDouble(1)}");
}

await using var conn = await dataSource.OpenConnectionAsync();
await using var tx = await conn.BeginTransactionAsync();
await using (var insert = new NpgsqlCommand("INSERT INTO brokers VALUES ($1, $2)", conn, tx))
{
    insert.Parameters.Add(new NpgsqlParameter { Value = 99 });
    insert.Parameters.Add(new NpgsqlParameter { Value = "Test Broker" });
    await insert.ExecuteNonQueryAsync();
}
await tx.CommitAsync();
```

For times, pick one setting: with `--pg-timestamptz`, send and read `DateTime` values with `Kind = Utc`.

<a id="go"></a>

## Go (pgx)

This is how the NChartPro backend connects. Tested: `tests/pg_go/main.go` checks all of this against a real server.

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

	// $1, $2, ... are parameters: the values never become part of the SQL text.
	_, err = pool.Exec(ctx, "INSERT INTO securities (symbol, name, sector) VALUES ($1, $2, $3)", "COAST", "Coastal Bank", "Banking")
	if err != nil {
		panic(err)
	}

	rows, err := pool.Query(ctx, "SELECT time, close, volume FROM ochl_day WHERE symbol = $1 AND time >= $2 ORDER BY time",
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

Real output of `tests/pg_go` (from [chapter 14](../tutorial/14-postgres-protocol.md)):

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

Everything pgx does works: the pool, `QueryRow`, `pgx.CollectRows` with `RowToStructByName`, `Begin`/`Commit`/`Rollback`, batches (`SendBatch`) and all query modes. Error codes: `errors.As(err, &pgErr)` and `pgErr.Code`.

<a id="parameters"></a>

## Parameters ($1, $2)

Syntax:

```sql
SELECT ... WHERE symbol = $1 AND time >= $2
INSERT INTO t (a, b) VALUES ($1, $2)
```

A **parameter** is a place for a value that the driver sends apart from the SQL text. Always use parameters for values that come from users: the value can never be read as SQL (no SQL injection).

- The values go into KarelaDB's syntax tree as values, never into the SQL text.
- **A parameter gets its type from where it is used.** In `WHERE volume > $1`, `$1` is `LONG` because `volume` is `LONG`. In `INSERT INTO t (a, b) VALUES ($1, $2)` each one gets its column's type. In `LIKE $1` it is text, in `LIMIT $1` a whole number.
- A parameter KarelaDB cannot place (`SELECT $1`) has no type; the driver then sends it as text.
- Parameters work in `WHERE`, `VALUES`, `SET`, `LIMIT`, `OFFSET`, function arguments and `CASE`. They do **not** work where KarelaDB needs a fixed value while reading the SQL: `SAMPLE BY`, `FILL(...)`, table and column names.
- Values can come in text or binary form; the driver chooses.
- **Result column types:** before a query runs, KarelaDB works out the type of each result column. If it cannot (a saved function, say), the column is `text`. When a driver then says `cannot scan text into *float64`, add a cast: `SELECT my_func(close)::DOUBLE AS x ...`.

<a id="types"></a>

## Types

| KarelaDB type | Postgres type (OID) | Go (pgx) | Python | Node (pg) |
|---|---|---|---|---|
| `BOOL` | `bool` (16) | `bool` | `bool` | boolean |
| `BYTE`, `SHORT` | `int2` (21) | `int16` | `int` | number |
| `INT` | `int4` (23) | `int32` | `int` | number |
| `LONG` | `int8` (20) | `int64` | `int` | string |
| `FLOAT` | `float4` (700) | `float32` | `float` | number |
| `DOUBLE` | `float8` (701) | `float64` | `float` | number |
| `DECIMAL(s)` | `numeric` (1700) | `pgtype.Numeric`, `float64`, `string` | `Decimal` | string |
| `DATE` | `date` (1082) | `time.Time` | `date` | Date |
| `TIMESTAMP` | `timestamp` (1114), or `timestamptz` (1184) with `--pg-timestamptz` | `time.Time` | `datetime` | Date |
| a column declared `TIMESTAMPTZ`, `x::timestamptz`, `now()`, `CURRENT_TIMESTAMP` | `timestamptz` (1184), always | `time.Time` | `datetime` | Date |
| `SYMBOL`, `STRING` | `text` (25) | `string` | `str` | string |
| `JSON` | `json` (114) | `string`, `[]byte`, a struct | `str` or parsed | object |
| `BYTES` | `bytea` (17) | `[]byte` | `bytes` | Buffer |
| a column declared `INTERVAL` | `interval` (1186) | `time.Duration`, `pgtype.Interval` | `timedelta` | object |
| a column of an [ENUM type](column-types.md#enum) | the type's own oid (as in `pg_type`), sent as text | `string` | `str` | string |

Parameters sent as `varchar`, `char`, `name` or `uuid` are taken as text; `jsonb` as `JSON`; `oid` as `LONG`.

A column declared `INTERVAL` keeps its length in **milliseconds** (a `LONG`). The Postgres port sends it as a real `interval`, in text (`00:15:03.548`) and in binary, and a parameter for it is typed `interval`. Over the HTTP API the same column is a number of milliseconds (`903548`), typed `LONG`.

A parameter next to such a column is typed `interval` too, and KarelaDB turns the interval you send into milliseconds before it runs. So a Go `time.Duration` works everywhere:

| Statement | `$1` | Comes back as |
|---|---|---|
| `WHERE d > $1`, `d BETWEEN $1 AND $2`, `SET d = $1` | `interval` | - |
| `SELECT d + $1`, `SET d = d - $1` | `interval` | `interval` |
| `SELECT d * 2`, `d / 2` | - | `interval` |
| `SELECT sum(d)`, `avg(d)`, `min(d)`, `max(d)` | - | `interval` |

To send milliseconds as a number instead, cast the parameter: `WHERE d > $1::bigint`. A client that types the parameter `int8` itself also sends milliseconds. Text that is not an interval is refused with `22007`.

<a id="times"></a>

## Times and --pg-timestamptz

KarelaDB keeps a `TIMESTAMP` as one exact moment in **UTC**, in milliseconds ([time and time zones](time-and-time-zones.md)).

By default it is sent as Postgres `timestamp` (without zone), like QuestDB does. With this type, drivers **drop the time zone** of a value you send:

- pgx: a Go `time.Time` in Nepal time (11:00 +05:45) is stored as 11:00 **UTC**. Always send UTC times: `t.UTC()`.
- node-pg: times you read come back in the computer's local time zone.

Start the server with **`--pg-timestamptz`** to send `TIMESTAMP` as `timestamptz`. Then every driver keeps the exact moment, in any time zone. Choose one setting for a server and keep it.

A column declared **`TIMESTAMPTZ`** is always sent as `timestamptz`, with or without the option. So are `x::timestamptz`, `now()` and `CURRENT_TIMESTAMP`, and a parameter next to them is typed `timestamptz`. pgx then sends a Go time as the moment it is: 11:00 +05:45 is stored as 05:15 UTC.

The session's time zone comes from the connection's `TimeZone` parameter (pgx `?timezone=Asia/Kathmandu`, libpq `options=-c TimeZone=...`), else from `SET TIME ZONE`, else the server's zone. A `timestamptz` shows that clock as text (`2026-09-25 11:00:00+05:45`), and `timestamptz` text without an offset is read on that clock. `RESET TIME ZONE` goes back to the connection's zone.

- Times have **milliseconds**. Microseconds from a driver are cut off.
- Time text a driver sends may have a zone: `Z`, `+05`, `+0545`, `+05:45`. Text without a zone is UTC.

<a id="transactions"></a>

## Transactions

Syntax:

```sql
BEGIN [ISOLATION LEVEL ...] | START TRANSACTION
COMMIT | END
ROLLBACK | ABORT
```

`BEGIN`, `COMMIT` and `ROLLBACK` work across messages, one transaction per connection. Every KarelaDB transaction is serializable; an isolation level you name is accepted and ignored. More: [transactions](transactions.md).

- When a statement fails inside a transaction, the transaction is **aborted**, like in PostgreSQL. The failed statement itself gets its own code (`23505` for a duplicate key, `23503` for a foreign key, ...). Every next statement gets `25P02` (`current transaction is aborted, commands ignored until end of transaction block`) until you send `ROLLBACK`. A `COMMIT` then also rolls back (its tag is `ROLLBACK`).
- **One writer per table.** While one connection has an open transaction, a change of one of its tables from another connection waits up to the lock timeout (5 seconds unless set; `SET lock_timeout = '20s'` for this connection, see [lock timeout](transactions.md#lock-timeout)), then fails with `55P03` (`table 'x' is busy`). Changes of other tables go on. Two transactions that would wait for each other: one fails at once with `40P01` (`deadlock`). Reads do not wait. Keep transactions short.
- An `INSERT` that gives up on a busy table gets `55P03`, even when its key looks taken: the writer holding the table may be freeing that key. Send it again; the retry gets `23505` if the key is really in use.
- A transaction with no statement for **30 seconds** is rolled back. The connection then gets `25P02` until it sends `ROLLBACK`. Change the time for the connection with `SET idle_in_transaction_session_timeout = '5min'` (`0` = never), or for the server with `--idle-in-transaction-timeout` ([idle transactions](transactions.md#idle-timeout)).
- When a connection closes, its open transaction is rolled back.
- A simple query with several statements (`INSERT ...; INSERT ...;` in one message) is **not** one transaction: statements before an error stay done. Use `BEGIN` ... `COMMIT`.
- `INSERT`, `UPDATE` and `DELETE` with `RETURNING` give rows, like a `SELECT` (in Go: `pool.QueryRow(ctx, "INSERT ... RETURNING id", ...).Scan(&id)`).
- `USE other_db` switches the connection's database; an open transaction of the old database is closed.

<a id="errors"></a>

## Error codes (SQLSTATE)

Errors carry a **SQLSTATE**: a five-character code that drivers show (`pgErr.Code` in Go, `e.sqlstate` in psycopg).

| Code | Meaning |
|---|---|
| `42601` | Syntax error (the message has `line X, column Y`; the error also has the position) |
| `42P01` | Unknown table or view |
| `42703` | Unknown column |
| `42P07` | The object already exists |
| `23505` | A unique key used twice (`PRIMARY KEY`, `UNIQUE`) |
| `23503` | `REFERENCES`: the row it points to is missing, or is still used |
| `23502` | A `NOT NULL` column without a value |
| `23514` | A `CHECK` rule failed |
| `25P02` | A statement **after** a failed one in the same transaction (or the transaction was idle too long): send `ROLLBACK` |
| `P0001` | A `RAISE EXCEPTION` in a trigger function, a `DO` block or a procedure, with no code given |
| `55P03` | Busy: another connection's transaction is open; try again |
| `40P01` | Deadlock: two transactions waited for each other; run it again |
| `57014` | The statement was stopped: the statement timeout, a cancel request, or `DELETE /exec/<id>` ([protection](protection.md)) |
| `54000` | A limit was passed: result memory, the number of groups, a message over 256 MB, a COPY too big |
| `25006` | The database or the server is read-only |
| `53100` | **The disk is full**: nothing of the statement was saved. It works again once space is freed ([disk full](backup-and-safety.md#disk-full)). |
| `22P02`, `22001`, `22003`, `22012` | A value that does not fit: bad text for the type, too long, a number too big, division by zero |
| `22021` | Text that is not UTF-8, or holds a NUL byte, in the SQL or a parameter: nothing of the message runs |
| `54001` | The statement is nested too deeply: too many brackets or subqueries inside each other |
| `42883` | Unknown function |
| `XX001` | A damaged data file ([after damage](backup-and-safety.md#after-damage)) |
| `0A000` | Not supported: data of a newer KarelaDB, or a changed prepared statement |
| `42501` | The user's role does not allow this |
| `28P01` | Wrong password or unknown user |
| `28000` | Login refused (no password allowed from another computer, too many failed logins) |
| `3D000` | Unknown database |
| `53300` | Too many connections (500 unless `--max-connections` sets another number) |
| `08P01` | A message KarelaDB does not support (old function calls) |
| `XX000` | Anything else: read the message |

**Which constraint.** A `23505` or `23503` error also says which table and which constraint it was about. The constraint has the name PostgreSQL would give it, or the name you gave it with `CONSTRAINT name`:

| Error field | Go (pgx) | Example |
|---|---|---|
| `s` schema | `pgErr.SchemaName` | `public` |
| `t` table | `pgErr.TableName` | `users` |
| `n` constraint | `pgErr.ConstraintName` | `users_pkey`, `users_email_key` (a `UNIQUE` column), `orders_user_id_fkey` (a `REFERENCES` column) |
| `c` column | `pgErr.ColumnName` | `email` (when the constraint has one column) |

When a row is still referred to (`DELETE` of a parent row), the table is the one that refers to it, as in PostgreSQL.

**Your own code.** A trigger function or a `DO` block can choose the code with `RAISE EXCEPTION '...' USING ERRCODE = '23001'`. A condition name works too (`ERRCODE = 'restrict_violation'`), and so do `RAISE SQLSTATE '23001' USING MESSAGE = '...'` and `RAISE unique_violation`. The client gets that code, so it can tell your rule from a real duplicate key. A name KarelaDB does not know gives `P0001`.

<a id="special"></a>

## Commands KarelaDB answers itself

Drivers and tools send a few PostgreSQL commands that KarelaDB SQL does not have. KarelaDB answers them itself:

| Command | Answer |
|---|---|
| `SET name = value`, `SET name TO value`, `SET NAMES ...` | checked against KarelaDB's list of settings and remembered; some change what KarelaDB does (`work_mem`, `enable_hashjoin`, ...), a restart-only one gives `55P02`. See [settings](server-settings.md). `client_encoding` must be UTF8 (`22023` otherwise) |
| `SET TIME ZONE 'Asia/Kathmandu'`, `SET timezone = ...`, `RESET TIME ZONE` | the session's clock for `CURRENT_DATE`, `::date`, `date_trunc`, `EXTRACT`, `to_char` ([time zones](time-and-time-zones.md#session-time-zone)); the driver gets `TimeZone` back. A zone with daylight saving time gives `22023` |
| `SET app.name = 'value'`, `SET LOCAL app.name = 'value'` | your own setting for this connection; `current_setting('app.name')` reads it, in triggers too. `LOCAL` ends with the transaction; outside `BEGIN` it only warns (`25P01`). See [session settings](functions-postgres.md#settings) |
| `SET synchronous_commit = off`, `SET LOCAL synchronous_commit = off` | this connection's commits (or this transaction's) do not wait for the disk sync, which follows within about 10 ms; a power cut or a crash of the program can lose the last of them. `SHOW` and `RESET` work. See [performance tips](performance-tips.md#synchronous-commit) |
| `SET SESSION CHARACTERISTICS ...`, `SET TRANSACTION ...` | accepted, ignored |
| `SHOW server_version`, `SHOW TimeZone`, `SHOW transaction_isolation`, ... | the setting (`server_version` is `14.0 (KarelaDB ...)`, `TimeZone` is the session's zone, `UTC` unless set); an unknown name gives `42704`. `SHOW ALL` lists every setting ([settings](server-settings.md)) |
| `SELECT version()` | `PostgreSQL 14.0 (KDB 0.2.0-dev), compatible server` |
| `SELECT current_database()` | the KarelaDB database name |
| `SELECT current_user`, `session_user`, `current_schema()`, `pg_backend_pid()` | the user name, the user name, `public`, the connection number (its `pid` in [pg_stat_activity](server-activity.md#pg-stat-activity)) |
| `RESET ...`, `DISCARD ALL`, `DEALLOCATE ...` | accepted |
| `LISTEN`, `UNLISTEN`, `NOTIFY`, `pg_notify()` | as in PostgreSQL: see [LISTEN and NOTIFY](listen-notify.md) |

`SHOW TABLES`, `SHOW COLUMNS FROM t`, `SHOW DATABASES` and the other KarelaDB `SHOW` statements still work as KarelaDB statements.

<a id="result-cache"></a>

### The result cache is on

Syntax:

```sql
SET result_cache = off | on      this connection
SHOW result_cache
```

A `SELECT` over this port uses the server's result cache, like `/exec`: the same query again gives the kept result while no table it read has changed. It is **on** for every new connection. For a benchmark that must time the engine, turn it off on each connection first (in a pgx pool: in `AfterConnect`). Without that, repeated queries with the same values measure the cache, not the query. `SHOW result_cache` says which one a connection has; `RESET result_cache` turns it on again.

A comment does not make a query a different one: `/* run 2 */ SELECT ...` is answered from the kept result of `SELECT ...` (the key is the statement as KarelaDB reads it, without comments or extra spaces). To time a second run, turn the cache off; a changed comment is not enough.

<a id="int-division"></a>

### Integer division

Syntax:

```sql
SET int_division = integer | float | default      this connection
SHOW int_division
postgres://app:secret@127.0.0.1:8832/market?sslmode=disable&int_division=integer
```

PostgreSQL gives `7 / 2 = 3`; KarelaDB gives `3.5` unless the connection asks for `integer`. An app that reads `sum(ms) / 1000` into a Go `int64` needs `integer`: `3.5` cannot be scanned into it.

| How | For |
|---|---|
| `kareladb serve --pg-int-division on` (or `KARELADB_PG_INT_DIVISION=on`) | every Postgres connection, from its start |
| `int_division=integer` in the connection string (a startup parameter; pgx and libpq send it) | that connection |
| `SET int_division = integer` (also `SET kdb.int_division = ...`) | that connection, from now on |

- With `integer`, `LONG` / `LONG` is a `LONG` cut toward zero (`-7 / 2` is `-3`), and a prepared statement describes the column as `int8`. A `DOUBLE` or `DECIMAL` side still gives a `DOUBLE`.
- `RESET int_division` and `SET int_division = default` go back to the start value: the server's `--pg-int-division`, or the connection string's.
- The rules are in [integer division](operators.md#integer-division).

<a id="pg-compat"></a>

### PostgreSQL-compatible results (kdb.pg_compat)

> **Waiting for the owner's decision.** This setting is **off** everywhere by
> default, and KarelaDB's own answers do not change. It exists so an app moving from
> PostgreSQL can be tried with PostgreSQL's answers; whether it becomes the
> default is not decided.

Syntax:

```sql
SET kdb.pg_compat = on | off | default            this session (also SET pg_compat = ...)
SHOW kdb.pg_compat
RESET kdb.pg_compat
CREATE DATABASE <name> WITH (pg_compat = on)
ALTER DATABASE <name> SET pg_compat = on | off | default
ALTER DATABASE <name> WITH (pg_compat = on | off)
kareladb serve --pg-compat on | off                    databases without their own setting (default off)
postgres://app:secret@127.0.0.1:8832/market?sslmode=disable&options=-c%20kdb.pg_compat%3Don
```

With `pg_compat` on, a statement gives PostgreSQL 14's answer where KarelaDB's own differs:

| What | KarelaDB (off) | PostgreSQL (on) |
|---|---|---|
| `7 / 2`, `-7 / 2` | `3.5`, `-3.5` | `3`, `-3` (the same as `int_division = integer`) |
| `0.1 + 0.2 = 0.3` | `false`: `0.1` is a `DOUBLE` | `true`: every decimal literal is an exact `NUMERIC` |
| `1.50::text` | `1.5` | `1.50` |
| `x::numeric`, `CAST(x AS NUMERIC)` (no precision) | a `DOUBLE` | the exact `NUMERIC` of `x` at its own scale (text `' 12.50 '` is `12.50`) |
| `count(*) OVER (ORDER BY x)` with equal `x` | `ROWS` frame: `1, 2, 3, 4` | `RANGE UNBOUNDED PRECEDING`: equal values count together, `1, 3, 3, 4` |
| `row_number() OVER (ORDER BY x DESC)` with a `NULL` `x` | the `NULL` row is last | the `NULL` row is first; `NULLS FIRST` / `NULLS LAST` in a window are followed |
| `ORDER BY name` | byte order: `Banana, Zebra, apple` | locale order: `apple, Banana, Zebra` |
| `'apple' < 'Banana'`, `name BETWEEN 'a' AND 'c'` | byte order | locale order |
| a plain `TIMESTAMP` on this port | UTC | the session's wall clock (see below) |

- **Where it comes from.** The session's `SET kdb.pg_compat` wins; then the connection string (`kdb.pg_compat=on` as a startup parameter, or `options=-c kdb.pg_compat=on`); then the database's own setting; then `kareladb serve --pg-compat`. `default` and `RESET` go back to the one before. It works over HTTP too (`SET kdb.pg_compat = on; SELECT ...`).
- **Text order.** The locale order is `"pg_en_US"`, which KarelaDB has built in (no ICU, no glibc): it follows PostgreSQL on Linux with `en_US.UTF-8`. Letters and digits first, then accents, then case (`apple` before `Apple`), and only then spaces and punctuation, so `'10.15% Prime'` sorts before `'10 % NMB'`. Among texts with the same letters, a mark that comes after fewer letters sorts first, and no mark at all sorts last (`'GBILD84/85'` before `'GBILD8485'`, as in PostgreSQL and in byte order). It follows glibc for Latin, Greek and Cyrillic text, not for every script. `=` and `<>` still compare the exact text. `COLLATE "C"` keeps byte order, and `COLLATE "pg_en_US"` gives this order in any session. `COLLATE "en_US"` stays KarelaDB's own dictionary order.
- **Timestamps.** A plain `TIMESTAMP` value goes out as the wall clock of the session's time zone (`SET TIME ZONE`, the `timezone` connection parameter, else the server's), and a `timestamp` parameter (text without an offset, or binary) is read as a wall clock time there. So a row written with `DEFAULT now()` and one written with a Go `time.Now()` hold the same time, and `created_at::date = CURRENT_DATE` is right for both. KarelaDB still stores the UTC moment: the same row read with `pg_compat` off, or over HTTP, shows UTC. A time written as text inside the SQL (`VALUES ('2026-09-25 11:00')`) is still read as UTC: send times as parameters.
- **`x::numeric` in a result.** Its type comes from the values, as in PostgreSQL, where a bare `numeric` has no fixed places: `CREATE TABLE ... AS SELECT x::numeric` makes a `NUMERIC(38, s)` column with the most places it met (`1.25` and `2.5` stay `1.25` and `2.50`, never rounded to whole numbers). An unnamed column is called `CAST(x AS NUMERIC)` with the setting on and `CAST(x AS DOUBLE)`, as always, with it off.
- **`ORDER BY` an alias or a position.** The rows are sorted by the value they show, worked out once: `SELECT nextval('s')::text AS id FROM t ORDER BY id` steps the sequence once per row, as in PostgreSQL.
- **Speed.** Nothing changes with the setting off. With it on, `ORDER BY` a text column and a text `<` / `>` are worked out row by row (an index cannot give the locale order); numbers and times keep every fast path.
- **Not changed.** The default isolation level. `min()` / `max()` of text and `GROUP BY` still use byte order. `CREATE TABLE ... NUMERIC` without a precision is still a `DOUBLE` column: write `NUMERIC(p, s)`. `'NaN'::numeric` is an error (KarelaDB's `NUMERIC` has no NaN). CHECK, DEFAULT, computed columns, index expressions and materialized views always use KarelaDB's own rules, whatever the session says.

<a id="streaming"></a>

## Big answers stream

A `SELECT` with a big answer sends its rows **while it reads them**, so a whole table can be read through the Postgres port: `SELECT * FROM trades` over 34 million rows used to stop at `--max-result-memory` (`54000`, `about 6609 MB; the limit is 1024 MB`).

- **Which queries:** a plain read with no `ORDER BY`, `GROUP BY`, `DISTINCT` or `OFFSET`: plain columns of one table (the fastest way: the rows are written straight from the stored columns and sent from a thread of their own, about 6 million rows a second on 2 CPUs), and also expressions, joins and a `WHERE` of any kind. A `LIMIT` works.
- **Small answers** (up to 64 MB of rows, or half of `--max-result-memory` when that is smaller) are made and sent as before, and may come from the [result cache](#result-cache). Only a bigger answer streams, and it is never cached.
- **Every way of asking:** a simple query (psql), an `Execute` with no row limit (pgx, Npgsql), an `Execute` with a row limit (JDBC `setFetchSize`, a named portal), and a `Describe` of the portal before its `Execute` (libpq, psycopg, pgx, JDBC). Drivers send that `Describe`, the `Execute` and the `Sync` in one packet: a plain `SELECT` of a table's columns is then described from the table, and any other query runs as its `Execute` would, the rows streamed behind the `RowDescription`. Rows that are not asked for yet - past a row limit, or all of them after a `Describe` sent on its own - wait in the database folder's `_tmp/` (in memory up to 8 MB, then in a file, encrypted when the database is), and are removed when the portal ends.
- **Several statements in one query string** (`SELECT 1; SELECT * FROM trades`) answer in order, so they do not stream.
- An error in the middle (the client went away, the statement timeout) ends the answer after the rows sent so far, as in PostgreSQL.
- A column whose type comes from its values (`CASE ... THEN x END`) needs a value that is not `NULL` among the first rows; when there is none, the answer is kept as before.

<a id="copy"></a>

## COPY

Syntax:

```sql
COPY <table> [(<column>, ...)] FROM STDIN [WITH (FORMAT text|csv|binary, HEADER, DELIMITER 'x', NULL 'x', QUOTE 'x', ESCAPE 'x')]
COPY <table> | (<SELECT ...>) TO STDOUT [WITH (...)]
```

`COPY` moves many rows in one go: pgx `CopyFrom`, psycopg `cursor.copy()`, psql `\copy`.

- `FROM STDIN` writes all rows as **one transaction**. A bad row fails the whole `COPY`, and nothing is written.
- It needs the same rights as an `INSERT` into those columns.
- KarelaDB never reads or writes a file on the server: only `FROM STDIN` and `TO STDOUT`. psql's `\copy` uses them, so it works with a file on your PC.
- The old spelling psql writes (`CSV HEADER`, `DELIMITER ','`, `BINARY`) works too.
- A very big `COPY` gets `54000` (`too much data for one COPY`): send it in several.

<a id="catalog"></a>

## The catalog

Tools and ORMs read the schema from PostgreSQL's catalog. KarelaDB works these out from its own tables when they are read (nothing is stored), all in the schema `public`:

| Schema | Views |
|---|---|
| `information_schema` | `tables`, `columns`, `views`, `schemata`, `sequences`, `table_constraints`, `key_column_usage`, `constraint_column_usage`, `referential_constraints`, `check_constraints` |
| `pg_catalog` | `pg_namespace`, `pg_class`, `pg_attribute`, `pg_type`, `pg_index`, `pg_indexes`, `pg_tables`, `pg_views`, `pg_constraint`, `pg_sequences`, `pg_database`, `pg_attrdef`, `pg_roles`, `pg_settings`, `pg_am`, `pg_collation`, `pg_range` (empty: no range types), `pg_policy` and `pg_policies` ([row rights](table-rights.md#row-rights)), and empty ones such as `pg_description`, `pg_inherits`, `pg_trigger` |

They only read. `pg_attribute` also lists the columns of every view and index.

On the PostgreSQL port, the catalog functions tools call work too: `pg_get_indexdef`, `pg_get_constraintdef`, `pg_get_viewdef`, `pg_get_expr`, `format_type`, `pg_table_is_visible`, and casts such as `'orders'::regclass`. On every port: `to_regclass`, `pg_relation_size`, `pg_total_relation_size`, `pg_database_size` and `pg_size_pretty` ([sizes](functions-postgres.md#sizes)), and QuestDB's `tables()` and `table_columns()` ([SHOW TABLES](show-tables.md#questdb-meta)).

<a id="limits"></a>

## What does not work

- Encryption **without** [TLS](tls.md) turned on. Use `127.0.0.1` or an SSH tunnel then: `ssh -N -L 8832:127.0.0.1:8832 user@your-vps`, and connect to `127.0.0.1:8832` on your PC.
- `COPY` with a file on the server (`COPY t FROM '/path'`): use `FROM STDIN` ([COPY](#copy)).
- The parts of the Postgres catalog that are not in the list above. An ORM that reads more of it (Entity Framework, Prisma introspection) may fail.
- **PostgreSQL SQL** that KarelaDB does not have (for example `::regclass`). `ON CONFLICT`, `WITH`, correlated subqueries, arrays (`= ANY($1)` with Go slices) and advisory locks work (tutorial chapter 23).
- The old function-call messages.
- `CREATE ROLE`: KarelaDB users and rights are per database ([users and roles](users-and-roles.md)). `SET ROLE name` takes the rights of a KarelaDB user ([SET ROLE](users-and-roles.md#set-role)).
- A prepared statement whose tables changed shape (a column added) gets `0A000` `cached plan must not change result type`: prepare it again (pgx does this by itself).
