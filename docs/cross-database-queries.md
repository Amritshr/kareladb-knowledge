# Queries across databases

> Read a table of another database on the same server as database.table - in SELECT, JOIN, subqueries and INSERT ... SELECT.

- Category: Databases & folders
- Keywords: cross-database, cross database, other database, another database, database.table, db.table, otherdb.table, reference data, shared tables, copy a table between databases, join two databases, INSERT INTO ... SELECT from another database, dblink, linked server, three-part name, changes only the database it runs in
- See also: [Databases and the data folder](databases.md), [Joins](joins.md), [UNION and subqueries](union-subqueries.md), [Users and roles](users-and-roles.md), [Table rights - GRANT ON TABLE](table-rights.md), [The procedure language (execute)](procedure-language.md#execute)

One KDB server holds many [databases](databases.md). A query can read a table of **another database** on the same server. Write the database name, a dot and the table name: `refdata.companies`.

A real setup: one database `refdata` holds the company list. Every app database reads it from there instead of keeping its own copy.

**Example: Company names from a shared reference database**

Setup:

```sql
CREATE DATABASE refdata;
USE refdata;
CREATE TABLE companies (symbol STRING PRIMARY KEY, name STRING, sector STRING);
INSERT INTO companies VALUES ('CITY', 'City Bank', 'Bank'), ('HYDRO', 'River Hydro', 'Energy'), ('MART', 'Metro Mart', 'Retail');
```

```sql
CREATE TABLE trades (id LONG PRIMARY KEY, symbol STRING, qty LONG);
INSERT INTO trades VALUES (1, 'CITY', 100), (2, 'HYDRO', 40), (3, 'CITY', 25);
SELECT t.id, t.symbol, c.name, t.qty
FROM trades t JOIN refdata.companies c ON t.symbol = c.symbol
ORDER BY t.id;
```

Result:

`CREATE TABLE trades (`

```text
table 'trades' created
```

`INSERT INTO trades VALUES (1, 'CITY', 100), (2, 'HYDRO', 40), (3, 'CITY', 25)`

```text
3 row(s) inserted
```

`SELECT t.id, t.symbol, c.name, t.qty FROM trades AS t JOIN refdata.companies AS c ON t.symbol = c.sy`

| id (LONG) | symbol (STRING) | name (STRING) | qty (LONG) |
|---|---|---|---|
| 1 | CITY | City Bank | 100 |
| 2 | HYDRO | River Hydro | 40 |
| 3 | CITY | City Bank | 25 |

(3 rows)

<a id="names"></a>

## Name a table of another database

Syntax:

```sql
database.table
database.public.table
"database"."table"
```

| Written | Means |
|---|---|
| `companies` | the table in the database you are using |
| `refdata.companies` | the table `companies` of the database `refdata` |
| `refdata.public.companies` | the same; PostgreSQL apps write the schema `public` |
| `demo.companies`, when you use `demo` | your own database: the same as `companies` |

- **Notes:**
  - Database names ignore upper and lower case, like everywhere in KDB.
  - With no alias, the table name is the alias: `SELECT companies.name FROM refdata.companies`.
  - It works over HTTP, the PostgreSQL port, `kdb shell`, `kdb sql --data-dir` and the web console. A `Database` opened on its own, without the server's databases, gives an error.

<a id="what-works"></a>

## What works

| Statement | Example |
|---|---|
| `SELECT` | `SELECT * FROM refdata.companies` |
| `JOIN`, `LEFT JOIN`, `CROSS JOIN`, `ASOF JOIN` | `FROM trades t JOIN refdata.companies c ON t.symbol = c.symbol` |
| subqueries: `IN`, `EXISTS`, a value, `FROM (SELECT ...)` | `WHERE symbol IN (SELECT symbol FROM refdata.companies)` |
| `WITH` | `WITH banks AS (SELECT * FROM refdata.companies WHERE sector = 'Bank') ...` |
| `INSERT INTO t SELECT ...` | copies rows from the other database into this one |
| `CREATE TABLE t AS SELECT ...` | makes a copy in this database |
| `UPDATE` / `DELETE` with a subquery | `DELETE FROM trades WHERE symbol NOT IN (SELECT symbol FROM refdata.companies)` |
| views, procedures, triggers, [EXECUTE](procedure-language.md#execute) | the other table is read each time they run |

**Example: Copy the banks into this database, and count trades of banks**

Setup:

```sql
CREATE DATABASE refdata;
USE refdata;
CREATE TABLE companies (symbol STRING PRIMARY KEY, name STRING, sector STRING);
INSERT INTO companies VALUES ('CITY', 'City Bank', 'Bank'), ('HYDRO', 'River Hydro', 'Energy'), ('LAKE', 'Lake Bank', 'Bank');
```

```sql
CREATE TABLE trades (id LONG PRIMARY KEY, symbol STRING, qty LONG);
INSERT INTO trades VALUES (1, 'CITY', 100), (2, 'HYDRO', 40), (3, 'LAKE', 25);
CREATE TABLE banks (symbol STRING PRIMARY KEY, name STRING);
INSERT INTO banks SELECT symbol, name FROM refdata.companies WHERE sector = 'Bank';
SELECT count(*) AS bank_trades, sum(qty) AS bank_qty
FROM trades WHERE symbol IN (SELECT symbol FROM refdata.companies WHERE sector = 'Bank');
```

Result:

`CREATE TABLE trades (`

```text
table 'trades' created
```

`INSERT INTO trades VALUES (1, 'CITY', 100), (2, 'HYDRO', 40), (3, 'LAKE', 25)`

```text
3 row(s) inserted
```

`CREATE TABLE banks (`

```text
table 'banks' created
```

`INSERT INTO banks SELECT symbol, name FROM refdata.companies WHERE sector = 'Bank'`

```text
2 row(s) inserted
```

`SELECT count(*) AS bank_trades, sum(qty) AS bank_qty FROM trades WHERE symbol IN (SELECT symbol FROM`

| bank_trades (LONG) | bank_qty (LONG) |
|---|---|
| 2 | 125 |

(1 row)

<a id="writes"></a>

## Changes stay in your database

A statement changes only the database it runs in. `INSERT`, `UPDATE` and `DELETE` of `otherdb.table` are refused. To change the other database, run the statement there (`USE refdata`, or `db=refdata` over HTTP). From there, your database's tables can be read as `yourdb.table`.

**Example: Writing into another database is refused** (shows an error)

Setup:

```sql
CREATE DATABASE refdata;
USE refdata;
CREATE TABLE companies (symbol STRING PRIMARY KEY, name STRING, sector STRING);
```

```sql
INSERT INTO refdata.companies VALUES ('NEW', 'New Company', 'Bank');
```

Result:

Error: `line 1, column 1: INSERT of table 'refdata.companies' is not allowed: a statement changes only the database it runs in ('demo'). Run it in database 'refdata' (USE refdata), where the tables of 'demo' can be read as demo.<table>`

**Example: A database that is not there** (shows an error)

```sql
SELECT * FROM nowhere.companies;
```

Result:

Error: `line 1, column 15: database 'nowhere' does not exist (SHOW DATABASES lists them) (in nowhere.companies)`

<a id="rights"></a>

## Rights

The other table is checked with **that** database's rights.

| To read `refdata.companies` a user needs | |
|---|---|
| role `read` on `refdata` | or `GRANT SELECT ON TABLE companies` made in `refdata` |
| no `REVOKE SELECT ON TABLE companies` in `refdata` | a revoke there wins over the role |
| role `admin` on `refdata` | only for `_audit_log` and dropped tables |

- **Notes:** the user also needs the usual rights in the database the statement runs in, for example `write` for an `INSERT ... SELECT`. See [users and roles](users-and-roles.md) and [table rights](table-rights.md).

<a id="speed"></a>

## Speed

A `SELECT` that reads only tables of **one** other database, and uses nothing of yours (no table, view, saved function or type of your database), is sent to that database whole. It runs there as if you had sent it yourself: `SELECT count(*) FROM market.prices` is answered from the saved row counts and copies no row, and a `GROUP BY` or `SAMPLE BY` over years runs next to the data. The answer is the same.

Any other statement reads the other table into your database first. Your conditions go with the read, so it skips partitions, uses the column engine and sends only the rows that match.

| Condition | Goes to the other database |
|---|---|
| `WHERE` of a query with only that table | yes |
| `WHERE p.time >= ...` in a join, written as `alias.column` | yes |
| a bare column name in a join (`WHERE time >= ...`) | no: it may belong to another table |
| `ON c.sector = 'Bank'` of a `JOIN` or `LEFT JOIN` | yes |
| `WHERE` on the right table of a `LEFT JOIN`, or of an `ASOF JOIN` | no: it would change the result |

- **Notes:**
  - When a statement also uses your database (a join with your table, for example), the matching rows come over to your database, then the join, `GROUP BY` and the rest run here.
  - In a join, write `alias.column` in `WHERE`, so a time range reaches the other table.
  - A change in the other database shows at once: a statement sent there whole is kept only in that database's [result cache](performance-tips.md), which a write there clears, and other results with its tables are never kept.

**Example: One day of prices from another database: only that day's partition is read**

Setup:

```sql
CREATE DATABASE market;
USE market;
CREATE TABLE prices (time TIMESTAMP, symbol STRING, close DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO prices VALUES ('2026-09-09T10:00:00Z', 'CITY', 510.0), ('2026-09-10T10:00:00Z', 'CITY', 512.5), ('2026-09-10T10:00:00Z', 'HYDRO', 88.2);
```

```sql
CREATE TABLE holdings (symbol STRING PRIMARY KEY, qty LONG);
INSERT INTO holdings VALUES ('CITY', 100), ('HYDRO', 50);
SELECT h.symbol, h.qty * p.close AS value
FROM holdings h JOIN market.prices p ON h.symbol = p.symbol
WHERE p.time >= '2026-09-10' AND p.time < '2026-09-11'
ORDER BY h.symbol;
```

Result:

`CREATE TABLE holdings (`

```text
table 'holdings' created
```

`INSERT INTO holdings VALUES ('CITY', 100), ('HYDRO', 50)`

```text
2 row(s) inserted
```

`SELECT h.symbol, h.qty * p.close AS value FROM holdings AS h JOIN market.prices AS p ON h.symbol = p`

| symbol (STRING) | value (DOUBLE) |
|---|---|
| CITY | 51250 |
| HYDRO | 4410 |

(2 rows)

<a id="locks"></a>

## Locks

- A statement reads the other database's tables **before** it takes the lock of its own database. So a statement never waits for two databases at once, and two databases that read each other at the same time do not wait for each other.
- Reading is like any other reader of that database: it sees committed rows only, and an open `BEGIN ... COMMIT` there does not make it wait.
- Inside a procedure, trigger or `EXECUTE`, your database is already locked. Then the read waits at most `lock_timeout_ms` (5 seconds by default) for a long writer of the other database, and fails with `database is busy ... Try again`.
- The rows are read when the statement starts. Transactions do not span databases: a `ROLLBACK` here does not touch the other database.
