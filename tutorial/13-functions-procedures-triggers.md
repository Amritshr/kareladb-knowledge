# 13. Functions, procedures and triggers

- Category: Tutorial

## What you will learn

- Save a formula once and use it in many queries (**functions**).
- Save several steps under one name and run them with `CALL` (**procedures**).
- Save several changes together, or none of them (**transactions**).
- Run SQL by itself when a table changes (**triggers**).
- Read a big result a few rows at a time (**cursors**).
- See every step a procedure takes (`WITH DEBUG`).

The examples use the database `market` with the fresh sample data. Each example is a file in `examples/13-functions-procedures-triggers/`. The results are real.

Functions, procedures and triggers are saved in the database like tables and views: they survive a restart, a crash and a backup.

## Saved functions

A saved function is a formula with a name. Its body is **one expression**.

```sql
CREATE [OR REPLACE] FUNCTION name(param TYPE, ...) [RETURNS TYPE] AS (expression);
DROP FUNCTION [IF EXISTS] name;
SHOW FUNCTIONS;
```

```sql
-- A saved function: the change from one price to another, in percent.
CREATE FUNCTION change_pct(price DOUBLE, prev DOUBLE) RETURNS DOUBLE
AS ((price - prev) / prev * 100);

SELECT symbol, open, close, round(change_pct(close, open), 2) AS change
FROM ochl_day
WHERE time IN '2026-09-10'
ORDER BY change DESC;

-- Functions can call other functions, and work in WHERE and GROUP BY.
CREATE FUNCTION move(price DOUBLE, prev DOUBLE) RETURNS STRING
AS (CASE WHEN change_pct(price, prev) > 0.5 THEN 'up' WHEN change_pct(price, prev) < -0.5 THEN 'down' ELSE 'flat' END);

SELECT move(close, open) AS move, count(*) AS days
FROM ochl_day
WHERE symbol = 'CITY'
GROUP BY move(close, open)
ORDER BY move;
```

```text
function 'change_pct' created

symbol | open  | close | change
-------+-------+-------+-------
VOLT   | 185.6 | 191.2 |   3.02
CITY   | 504.6 | 504.9 |   0.06
COAST  | 380.1 | 376.1 |  -1.05
(3 rows, 0.2 ms)

function 'move' created

move | days
-----+-----
down |    4
flat |   13
up   |    2
(3 rows, 0.2 ms)
```

**Why is it not called `pct_change`?** Because `pct_change` is already a built-in function (chapter 5). A saved function cannot have the name of a built-in one:

```sql
CREATE FUNCTION pct_change(price DOUBLE, prev DOUBLE) AS ((price - prev) / prev * 100);
```

```text
error: 'pct_change' is a built-in function; choose another name for the function
```

A function can only use its **parameters**, not the columns of a table. Give it the columns as arguments:

```sql
CREATE FUNCTION day_range(high DOUBLE) AS (high - low);
```

```text
error: the body of function 'day_range' uses low, which is not one of its parameters (high DOUBLE); a function can only use its parameters
```

| Rule | Detail |
|---|---|
| Speed | A call is replaced by its body when the query starts. `change_pct(close, open)` is exactly as fast as `(close - open) / open * 100`. |
| Types | Each argument is converted to the parameter's type (like `CAST`). `RETURNS` converts the result. |
| Body | One expression: operators, `CASE`, built-in functions like `round` or `concat`, and other saved functions. No subqueries, aggregates (`sum`) or window functions (`sma`) inside. Use them around the call: `sum(change_pct(close, open))`. |
| Nesting | A function may call other functions, at most 16 levels deep. A function cannot call itself, also not through another function. |
| Where | `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY`, views, procedures. **Not** in computed columns (`AS (...)` in `CREATE TABLE`). |
| Names | Not the name of a built-in function. Names do not care about case. |
| Change | `CREATE OR REPLACE FUNCTION` changes it. Views and procedures that use it get the new body. |

## Stored procedures

A procedure is a list of statements with a name. You run it with `CALL`.

```sql
CREATE [OR REPLACE] PROCEDURE name(param TYPE, ...) AS BEGIN
  statement;
  ...
END;
CALL name(arguments) [WITH DEBUG];
DROP PROCEDURE [IF EXISTS] name;
SHOW PROCEDURES;
```

This procedure builds the daily candles of one day from the minute candles (the job the app runs after the market closes):

```sql
-- End of day: build the daily candles of one day from the minute candles.
CREATE PROCEDURE end_of_day(day DATE) AS BEGIN
  DECLARE minutes LONG DEFAULT 0;
  SET minutes = (SELECT count(*) FROM ochl_minutes
                 WHERE time >= day AND time < dateadd('d', 1, day));
  IF minutes = 0 THEN
    RAISE concat('no minute candles for ', day);
  END IF;
  FOR c IN (SELECT symbol, first(open) AS open, max(high) AS high, min(low) AS low,
                   last(close) AS close, sum(volume) AS volume
            FROM ochl_minutes
            WHERE time >= day AND time < dateadd('d', 1, day)
            GROUP BY symbol) DO
    INSERT OR REPLACE INTO ochl_day VALUES (day, c.symbol, c.open, c.high, c.low, c.close, c.volume);
  END FOR;
  PRINT concat(minutes, ' minute candles read');
  SELECT symbol, open, high, low, close, volume FROM ochl_day WHERE time = day ORDER BY symbol;
END;
```

```text
procedure 'end_of_day' created
```

Now delete two daily candles and build them again:

```sql
-- Remove two daily candles, then build them again from the minute candles.
DELETE FROM ochl_day WHERE time IN '2026-09-10' AND symbol IN ('CITY', 'COAST');
CALL end_of_day('2026-09-10');
```

```text
2 row(s) deleted

procedure 'end_of_day' done: 2 row(s) changed

symbol | open  | high  | low   | close | volume
-------+-------+-------+-------+-------+-------
CITY   | 504.6 |   507 | 500.7 | 504.9 | 183040
COAST  | 380.1 |   382 | 373.2 | 376.1 | 186200
VOLT   | 185.6 | 192.1 | 184.2 | 191.2 |  41470
(3 rows, 0.1 ms)

output                 
-----------------------
476 minute candles read
(1 row, 0.0 ms)
```

A `CALL` returns more than one result: its own message, the rows of every `SELECT` in the procedure, and a result called `print` with the `PRINT` lines. The web console and `POST /exec` show them like several statements.

### What you can write in a procedure

| Statement | Meaning |
|---|---|
| `SELECT`, `INSERT`, `UPDATE`, `DELETE` | As usual. A `SELECT` returns its rows as an extra result of the `CALL`. |
| `DECLARE name TYPE [DEFAULT expr];` | A variable. Without `DEFAULT` it is NULL. |
| `SET name = expr;` | Give a variable a new value. `SET n = (SELECT count(*) FROM t);` takes a value from a query. |
| `IF cond THEN ... [ELSIF cond THEN ...] [ELSE ...] END IF;` | Choose. NULL counts as false. |
| `WHILE cond DO ... END WHILE;` | Repeat while the condition is true. |
| `FOR r IN (SELECT ...) DO ... END FOR;` | Once for every row of the query. `r.column` is a value of the current row. |
| `DECLARE c CURSOR FOR SELECT ...;` `OPEN c;` `FETCH c INTO a, b;` `CLOSE c;` | Read a query one row at a time (see [Cursors](#cursors)). |
| `CALL other(args);` | Run another procedure (at most 16 levels deep). |
| `RETURN;` | Stop the procedure. Its changes are kept. |
| `RAISE expr;` | Stop with an error. **Everything the `CALL` changed is undone.** |
| `PRINT expr;` | Add a line to the `print` result (a debug message). |

Every statement ends with `;`. `CREATE`, `DROP`, `ALTER`, `TRUNCATE`, `BACKUP`, `BEGIN` and `COMMIT` cannot be used inside a procedure.

### Variables and parameters

- Use them by name in any expression: `WHERE time >= day`, `VALUES (day, c.symbol)`.
- A **column name wins** over a variable with the same name. Give variables names that are not column names (`minutes`, not `volume`).
- Every procedure has a variable `FOUND` (true when the last `FETCH` read a row).
- A value is converted to the variable's type. `CALL end_of_day('2026-09-10')` turns the text into a `DATE`.

### RAISE: stop and undo

There are no minute candles for 2026-09-12:

```sql
CALL end_of_day('2026-09-12');
```

```text
error: procedure 'end_of_day', line 5: no minute candles for 2026-09-12
```

`line 5` is the line in the procedure as `SHOW PROCEDURES` prints it (`CREATE PROCEDURE ... AS BEGIN` is line 1, and each statement starts a new line).

**A `CALL` is one transaction.** Its changes are saved together at the end, with one write to the log. If any statement fails, or `RAISE` runs, nothing of the `CALL` is saved. Statements inside the procedure see the changes made earlier in the same `CALL`.

## Transactions: BEGIN, COMMIT, ROLLBACK

Normally every statement is saved on its own. Between `BEGIN` and `COMMIT`, statements are saved **together, or not at all**.

```sql
-- ROLLBACK: nothing is saved.
BEGIN;
DELETE FROM securities WHERE symbol = 'ACME';
SELECT count(*) AS securities FROM securities;
ROLLBACK;
SELECT count(*) AS securities FROM securities;

-- COMMIT: both rows are saved together, in one log write.
BEGIN;
INSERT INTO brokers VALUES (17, 'ABC Securities');
INSERT INTO brokers VALUES (18, 'Sagarmatha Securities');
COMMIT;
SELECT id, name FROM brokers WHERE id IN (17, 18);
```

```text
transaction started

1 row(s) deleted

securities
----------
         4
(1 row, 0.1 ms)

transaction rolled back: 1 change(s) undone

securities
----------
         5
(1 row, 0.0 ms)

transaction started

1 row(s) inserted

1 row(s) inserted

transaction committed: 2 change(s) saved

id | name                 
---+----------------------
17 | ABC Securities       
18 | Sagarmatha Securities
(2 rows, 0.0 ms)
```

When a statement fails, the whole transaction is undone:

```sql
-- The second INSERT fails (id 1 is already used), so the first one is undone too.
BEGIN;
INSERT INTO brokers VALUES (19, 'Trishakti Securities');
INSERT INTO brokers VALUES (1, 'Keystone Securities again');
COMMIT;
```

```text
transaction started

1 row(s) inserted
error: a row with id='1' already exists in 'brokers'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it (the transaction was rolled back)
```

| Rule | Detail |
|---|---|
| Where | In one text sent to `kareladb sql`, `POST /exec` or the web console. In `kareladb shell`, in an HTTP session (`POST /session`) and over the PostgreSQL protocol, a transaction can go over many requests (chapter 15). |
| No COMMIT | A text that ends without `COMMIT` is rolled back, with the error `BEGIN without COMMIT` (not in a session: there it stays open). |
| Crash | Changes are written to the log only at `COMMIT`. After a crash or power cut, a committed transaction is there completely, and a transaction without `COMMIT` is not there at all. |
| Not inside | `CREATE`, `DROP`, `ALTER`, `RENAME`, `TRUNCATE`, `BACKUP DATABASE`. Run them before `BEGIN` or after `COMMIT`. |
| Size | At most 10 million changed rows per transaction (`CALL` too). Until `COMMIT`, KarelaDB keeps the old version of every changed row in memory. |
| Others | While a session has an open transaction, other sessions **wait** before they change a table it used (at most 5 seconds, then `table 'x' is busy`); changes of other tables go on. Their reads do not wait for an open transaction: they see the rows without its changes. Chapter 15 explains this. |

## Triggers

A trigger runs SQL by itself every time a table is changed.

```sql
CREATE [OR REPLACE] TRIGGER name {BEFORE | AFTER} {INSERT | UPDATE | DELETE} ON table
  EXECUTE {CALL procedure(args) | one statement | BEGIN statements END};
CREATE [OR REPLACE] TRIGGER name AFTER INSERT ON table DEFERRED [TIMEOUT 10min]
  EXECUTE ...;                          -- runs after the commit, in the background
DROP TRIGGER [IF EXISTS] name;
ALTER TABLE table {ENABLE | DISABLE} TRIGGER name;
SHOW TRIGGERS;
```

The app shows the last price of every symbol. Instead of searching `live_data` every time, keep a small `latest_price` table up to date:

```sql
-- Keep the last price of every symbol in a small table, always up to date.
CREATE TABLE latest_price (symbol SYMBOL PRIMARY KEY, ltp DOUBLE, time TIMESTAMP);

CREATE TRIGGER keep_latest AFTER INSERT ON live_data EXECUTE BEGIN
  FOR r IN (SELECT symbol, last(ltp) AS ltp, max(timestamp) AS time FROM NEW GROUP BY symbol) DO
    INSERT OR REPLACE INTO latest_price VALUES (r.symbol, r.ltp, r.time);
  END FOR;
END;

INSERT INTO live_data VALUES
  ('2026-09-11T11:00:00+05:45', 'CITY', 528.0, 10, 0.9, 0.17, 527.1, 528.0, 527.1, 527.5, 527.1, 1200),
  ('2026-09-11T11:01:00+05:45', 'CITY', 529.5, 20, 2.4, 0.46, 527.1, 529.5, 527.1, 528.2, 527.1, 3400),
  ('2026-09-11T11:00:00+05:45', 'COAST', 402.5, 10, 0.6, 0.15, 401.9, 402.5, 401.9, 402.2, 401.9, 800);

SELECT symbol, ltp, time FROM latest_price ORDER BY symbol;
```

```text
table 'latest_price' created

trigger 'keep_latest' created on table 'live_data'

3 row(s) inserted

symbol | ltp   | time                    
-------+-------+-------------------------
CITY   | 529.5 | 2026-09-11T05:16:00.000Z
COAST  | 402.5 | 2026-09-11T05:15:00.000Z
(2 rows, 0.1 ms)
```

Inside a trigger, two tables exist:

| Table | INSERT | UPDATE | DELETE |
|---|---|---|---|
| `NEW` | the inserted rows | the rows after the change | (empty) |
| `OLD` | (empty) | the rows before the change | the deleted rows |

They have the columns of the changed table. Use them like tables: `SELECT ... FROM NEW`, `FROM OLD o JOIN NEW n ON o.id = n.id`.

### A BEFORE trigger can refuse a change

```sql
-- A BEFORE trigger can refuse a change.
CREATE TRIGGER check_price BEFORE INSERT ON live_data EXECUTE BEGIN
  IF EXISTS (SELECT 1 FROM NEW WHERE ltp <= 0) THEN
    RAISE 'ltp must be more than 0';
  END IF;
END;

INSERT INTO live_data VALUES
  ('2026-09-11T11:02:00+05:45', 'CITY', 0, 10, 0, 0, 527.1, 529.5, 527.1, 528.2, 527.1, 3500);
```

```text
trigger 'check_price' created on table 'live_data'
error: trigger 'check_price', line 3: ltp must be more than 0
```

Nothing was written, and `latest_price` did not change:

```sql
-- Nothing was written by the refused INSERT.
SELECT count(*) AS rows FROM live_data WHERE timestamp > '2026-09-11T11:01:00+05:45';
SELECT symbol, ltp FROM latest_price ORDER BY symbol;
SHOW TRIGGERS;
```

```text
rows
----
   0
(1 row, 0.3 ms)

symbol | ltp  
-------+------
CITY   | 529.5
COAST  | 402.5
(2 rows, 0.1 ms)

name        | table     | timing | event  | enabled | definition                                      
------------+-----------+--------+--------+---------+-------------------------------------------------
check_price | live_data | BEFORE | INSERT | true    | CREATE TRIGGER check_price BEFORE INSERT ON l...
keep_latest | live_data | AFTER  | INSERT | true    | CREATE TRIGGER keep_latest AFTER INSERT ON li...
(2 rows, 0.0 ms)
```

| Rule | Detail |
|---|---|
| How often | **Once per statement**, not once per row: once for an `INSERT` of 1,000 rows, once for a `Database::InsertRows` call, once for a `POST /write` (line protocol) request. A statement that changes no row does not run triggers. |
| Together | The trigger runs in the same transaction as the statement. If the trigger fails, the statement is undone too. |
| BEFORE / AFTER | `BEFORE` runs before the rows are written (use it to check them, `RAISE` refuses). `AFTER` runs after (the table already has the new rows). |
| Nesting | A trigger may change a table that has triggers. At most 16 levels: a trigger that fires itself stops with `triggers are nested too deeply`. |
| Order | Several triggers of the same kind on one table run in name order. |
| DROP TABLE | A table with triggers cannot be dropped or renamed: `table 'live_data' has triggers (...); DROP TRIGGER them first`. |
| Off for a while | `ALTER TABLE live_data DISABLE TRIGGER keep_latest;` and later `ENABLE TRIGGER`. |
| Speed | A trigger slows only its own table. Writes into that table (`InsertRows` calls and line-protocol requests too) are written one at a time, not grouped with other requests, and the loader waits for the trigger body. Writes into other tables are as fast as before. Keep trigger bodies short, or make a slow one `DEFERRED` (below). |

### Deferred triggers: slow work after the commit

A normal trigger runs **inside** the insert, so the loader waits for it. A trigger that builds summary tables from a whole day of trades can take seconds. Make it `DEFERRED`: the insert commits and returns at once, and the trigger's work runs after it, in the background of the server.

```sql
CREATE TABLE day_totals (symbol SYMBOL PRIMARY KEY, quantity LONG);

CREATE TRIGGER build_totals AFTER INSERT ON trade_log DEFERRED TIMEOUT 10min EXECUTE
  INSERT OR REPLACE INTO day_totals
  SELECT symbol, sum(quantity) FROM trade_log GROUP BY symbol;
```

```text
table 'day_totals' created

trigger 'build_totals' created on table 'trade_log' (deferred: it runs after each INSERT commits, one job at a time)
```

| Rule | Detail |
|---|---|
| Which | Only `AFTER INSERT` triggers can be deferred. |
| Jobs | Every insert (`INSERT`, `POST /write`, `POST /imp`, a `COMMIT` that inserted rows) makes one **job**. The jobs of a trigger run one at a time, oldest first. They are kept on disk, so a restart does not lose them. |
| Where they run | In a running server (`kareladb serve`). `kareladb sql` exits right after its statement, so a job it made runs the next time a server opens the database. |
| Failure | A failed job stops its trigger's queue. Nothing is skipped by itself. `RETRY TRIGGER QUEUE build_totals` runs it again; `SKIP TRIGGER JOB build_totals <id>` leaves it out. |
| Watch | `GET /api/trigger-queue` shows the queue and the lag. `POST /write?...&wait=trigger` answers only after its own jobs ended. |
| SHOW TRIGGERS | The timing column says `AFTER (deferred)`. |

The help topic **Triggers** has every detail.

## Cursors

A cursor reads the rows of a query one by one, or a few at a time.

### In a procedure

```sql
-- A cursor loop: read rows one at a time, stop when FOUND is false.
CREATE PROCEDURE biggest_trade(day DATE) AS BEGIN
  DECLARE sym SYMBOL;
  DECLARE qty LONG;
  DECLARE best_sym SYMBOL;
  DECLARE best_qty LONG DEFAULT 0;
  DECLARE trades CURSOR FOR
    SELECT symbol, quantity FROM trade_log WHERE date = day ORDER BY transaction_id;
  OPEN trades;
  FETCH trades INTO sym, qty;
  WHILE found DO
    IF qty > best_qty THEN
      SET best_qty = qty;
      SET best_sym = sym;
    END IF;
    FETCH trades INTO sym, qty;
  END WHILE;
  CLOSE trades;
  PRINT concat('biggest trade on ', day, ': ', best_qty, ' shares of ', best_sym);
END;

CALL biggest_trade('2026-09-10');
```

```text
procedure 'biggest_trade' created

procedure 'biggest_trade' done: 0 row(s) changed

output                                          
------------------------------------------------
biggest trade on 2026-09-10: 1000 shares of C...
(1 row, 0.0 ms)
```

`OPEN` runs the query. `FETCH ... INTO` puts the next row into the variables (one variable per column) and sets `FOUND`. A `FOR` loop is shorter for the same job; a cursor is useful when you read two queries side by side, or stop early.

### In SQL: read a big result bit by bit

```sql
-- Read a big result a few rows at a time.
DECLARE m CURSOR FOR
  SELECT time, symbol, close FROM ochl_minutes WHERE time IN '2026-09-10' ORDER BY time, symbol;
FETCH NEXT 3 FROM m;
FETCH NEXT 3 FROM m;
CLOSE m;
```

```text
cursor 'm' declared: 476 row(s)

time                     | symbol | close
-------------------------+--------+------
2026-09-10T05:15:00.000Z | CITY   | 504.4
2026-09-10T05:15:00.000Z | COAST  |   380
2026-09-10T05:16:00.000Z | CITY   | 504.6
(3 rows, 0.0 ms)
3 row(s) fetched, 473 left

time                     | symbol | close
-------------------------+--------+------
2026-09-10T05:16:00.000Z | COAST  | 379.6
2026-09-10T05:17:00.000Z | CITY   | 504.2
2026-09-10T05:17:00.000Z | COAST  | 380.1
(3 rows, 0.0 ms)
3 row(s) fetched, no more rows
```

`FETCH NEXT n FROM c`, `FETCH ALL FROM c` (the rest), `CLOSE c`. `DECLARE` runs the query once and keeps its rows (a snapshot): later changes to the table do not change what `FETCH` returns.

A cursor lives until `CLOSE`, until the end of the text (`kareladb sql`, `POST /exec`), or until the `kareladb shell` session ends.

### In kareladb shell: over many lines

In `kareladb shell`, a transaction and a cursor stay open from one line to the next:

```powershell
@"
BEGIN;
UPDATE securities SET sector = 'Banks' WHERE symbol = 'CITY';
SELECT symbol, sector FROM securities WHERE symbol = 'CITY';
ROLLBACK;
SELECT symbol, sector FROM securities WHERE symbol = 'CITY';
DECLARE s CURSOR FOR SELECT symbol FROM securities ORDER BY symbol;
FETCH NEXT 2 FROM s;
FETCH ALL FROM s;
CLOSE s;
CREATE PROCEDURE count_sector(wanted STRING) AS BEGIN
  DECLARE n LONG;
  SET n = (SELECT count(*) FROM securities WHERE sector = wanted);
  PRINT concat(wanted, ': ', n);
END;
CALL count_sector('Banking');
.exit
"@ | kareladb shell market
```

```text
KarelaDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> transaction started
kareladb> 1 row(s) updated
kareladb> symbol | sector
-------+-------
CITY   | Banks 
(1 row, 0.1 ms)
kareladb> transaction rolled back: 1 change(s) undone
kareladb> symbol | sector 
-------+--------
CITY   | Banking
(1 row, 0.0 ms)
kareladb> cursor 's' declared: 5 row(s)
kareladb> symbol
------
ACME  
CITY  
(2 rows, 0.0 ms)
2 row(s) fetched, 3 left
kareladb> symbol
------
COAST 
TELCO 
VOLT  
(3 rows, 0.0 ms)
3 row(s) fetched, no more rows
kareladb> cursor 's' closed
kareladb> ...> ...> ...> ...> procedure 'count_sector' created
kareladb> procedure 'count_sector' done: 0 row(s) changed

output    
----------
Banking: 2
(1 row, 0.0 ms)
kareladb>
```

The shell knows that a `CREATE PROCEDURE ... BEGIN ... END;` is one statement, even though it has `;` inside (the `...>` prompts). If you leave the shell with a transaction still open, it is rolled back. If a statement fails inside the transaction, the transaction is rolled back and the shell accepts only `ROLLBACK` until you send it (so the next lines cannot run outside the transaction by mistake).

**A trap:** the parameter is called `wanted`, not `name`. The table `securities` has a column `name`, and a column name wins over a variable: with a parameter called `name`, `WHERE sector = name` compares `sector` with the `name` column and counts 0.

### Over HTTP

`POST /cursor` with a `SELECT` as the body keeps the rows on the server. `GET /cursor/<id>?fetch=N` returns the next rows, `DELETE /cursor/<id>` closes it. Chapter 8 has the example ([Cursors](08-http-api.md#cursors-read-a-big-result-bit-by-bit)).

| Cursor rule | Detail |
|---|---|
| Open at the same time | At most 16 cursors per database (SQL and HTTP together). |
| Unused | A cursor closes after 10 minutes without `FETCH`. |
| Size | At most 10 million rows. The rows are kept in memory until the cursor closes. |

## Debugging: WITH DEBUG

`CALL ... WITH DEBUG` adds a result called `debug`, with one row for every step:

```sql
CALL end_of_day('2026-09-10') WITH DEBUG;
```

```text
procedure 'end_of_day' done: 2 row(s) changed

symbol | open  | high  | low   | close | volume
-------+-------+-------+-------+-------+-------
CITY   | 504.6 |   507 | 500.7 | 504.9 | 183040
COAST  | 380.1 |   382 | 373.2 | 376.1 | 186200
VOLT   | 185.6 | 192.1 | 184.2 | 191.2 |  41470
(3 rows, 0.0 ms)

step | routine    | statement                                        | rows | time_us | changes                                         
-----+------------+--------------------------------------------------+------+---------+-------------------------------------------------
   1 |            | CALL end_of_day('2026-09-10') WITH DEBUG         |    2 |    1268 | partitions read: 3                              
   2 | end_of_day | DECLARE minutes LONG DEFAULT 0                   |    0 |       2 | minutes=0                                       
   3 | end_of_day | SET minutes = (SELECT count(*) FROM ochl_minu... |    0 |     574 | minutes=476, partitions read: 1                 
   4 | end_of_day | IF minutes = 0 THEN                              |    0 |       2 | false                                           
   5 | end_of_day | FOR c IN (SELECT symbol, first(open) AS open,... |    2 |     340 | partitions read: 1                              
   6 | end_of_day | FOR c: row 1 of 2                                |    0 |       0 | c.symbol=CITY, c.open=504.6, c.high=507, c.lo...
   7 | end_of_day | INSERT OR REPLACE INTO ochl_day VALUES (day, ... |    1 |     131 |                                                 
   8 | end_of_day | FOR c: row 2 of 2                                |    0 |       0 | c.symbol=COAST, c.open=380.1, c.high=382, c.l...
   9 | end_of_day | INSERT OR REPLACE INTO ochl_day VALUES (day, ... |    1 |      14 |                                                 
  10 | end_of_day | PRINT concat(minutes, ' minute candles read')    |    0 |       5 | 476 minute candles read                         
  11 | end_of_day | SELECT symbol, open, high, low, close, volume... |    3 |      46 | partitions read: 1                              
(11 rows, 0.0 ms)
```

| Column | Meaning |
|---|---|
| `step` | 1, 2, 3, ... in the order the steps started |
| `routine` | the procedure (or `trigger name`) the step is in |
| `statement` | the statement, or the control line (`IF ... THEN`, `WHILE ... DO`, `FOR r: row 2 of 5`) |
| `rows` | rows changed (INSERT, UPDATE, DELETE), rows returned (SELECT), rows read (OPEN, FOR) |
| `time_us` | time of the step in microseconds (the first row: the whole `CALL`) |
| `changes` | variables that got a new value (`minutes=476`), the result of a condition (`true`/`false`), the `PRINT` text, or `failed: <error>`. A step that read table partitions adds how many: `partitions read: 1`. The first row counts them for the whole `CALL`. |

With `WITH DEBUG`, `PRINT` lines are in the `debug` result (there is no separate `print` result). When the `CALL` fails, the `debug` rows up to the error are still returned, and the last one says `failed`: `kareladb sql` and `kareladb shell` print them before the error, and `POST /exec` returns them in `results` next to the `error`. Triggers that run during the `CALL` add their steps too. At most 100,000 steps are recorded.

`time_us` changes every time you run it: the numbers above are from one run.

## Keeping the definitions

```sql
SHOW PROCEDURES;
ALTER TABLE live_data DISABLE TRIGGER check_price;
DROP TRIGGER check_price;
DROP FUNCTION move;
DROP FUNCTION IF EXISTS move;
SHOW FUNCTIONS;
```

```text
name          | arguments     | definition                                      
--------------+---------------+-------------------------------------------------
biggest_trade | day DATE      | CREATE PROCEDURE biggest_trade(day DATE) AS B...
count_sector  | wanted STRING | CREATE PROCEDURE count_sector(wanted STRING) ...
end_of_day    | day DATE      | CREATE PROCEDURE end_of_day(day DATE) AS BEGI...
(3 rows, 0.0 ms)

trigger 'check_price' disabled

trigger 'check_price' dropped

function 'move' dropped

function 'move' does not exist

name       | arguments                 | returns | definition                                      
-----------+---------------------------+---------+-------------------------------------------------
change_pct | price DOUBLE, prev DOUBLE | DOUBLE  | CREATE FUNCTION change_pct(price DOUBLE, prev...
(1 row, 0.0 ms)
```

The table format cuts long text after 48 characters. To see a whole definition, use `--format csv` or `--format json`: `kareladb sql market "SHOW PROCEDURES" --format csv`.

KarelaDB checks a procedure's statements for **syntax** when you create it, and for **tables and columns** when it runs. A procedure that uses a table you dropped later fails at `CALL` with a clear message. `DROP FUNCTION` and `DROP PROCEDURE` do not check who uses them (views, other procedures, triggers).

## Limits

| Limit | Value |
|---|---|
| Nesting of saved functions | 16 levels |
| Nesting of `CALL` | 16 levels |
| Nesting of triggers | 16 levels |
| Rows changed in one transaction (`BEGIN`/`COMMIT`, `CALL`, a statement with triggers) | 10 million (`DatabaseOptions::max_transaction_rows`) |
| Rounds of one `WHILE` loop | 10 million |
| Open cursors per database | 16 (`DatabaseOptions::max_cursors`) |
| Unused cursor closes after | 10 minutes (`DatabaseOptions::cursor_idle_ms`) |
| Rows in one cursor | 10 million |
| Steps in a `debug` result | 100,000 |

## Try it yourself

1. Write a function `day_range_pct(high DOUBLE, low DOUBLE, close DOUBLE)` that gives `(high - low) / close * 100`, and use it on `ochl_day` for 2026-09-10.
2. Why does `CALL end_of_day('2026-09-12')` leave `ochl_day` exactly as it was?
3. You want `latest_price` to also forget a symbol when all its `live_data` rows are deleted. Which trigger do you add, `BEFORE` or `AFTER`, and on which event?

<details>
<summary>Answers</summary>

1. `CREATE FUNCTION day_range_pct(high DOUBLE, low DOUBLE, close DOUBLE) RETURNS DOUBLE AS ((high - low) / close * 100);` then `SELECT symbol, round(day_range_pct(high, low, close), 2) FROM ochl_day WHERE time IN '2026-09-10';`
2. `RAISE` stops the procedure with an error, and a `CALL` is one transaction: nothing it did is saved. (Here it had not changed anything yet anyway.)
3. `AFTER DELETE ON live_data`. After the delete, the body can check `SELECT symbol FROM OLD` against what is left in `live_data`, and `DELETE FROM latest_price WHERE symbol = ...` for symbols with no rows left.

</details>

---

Back to the index. Also read the [known limitations](known-limitations.md).
