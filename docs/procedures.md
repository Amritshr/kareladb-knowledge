# Stored procedures

> Save many SQL steps under one name and run them with CALL, as one transaction.

- Category: Stored procedures
- Keywords: procedure, stored procedure, CALL, PROCEDURES, DEBUG, WITH DEBUG, debug, print result, CREATE OR REPLACE PROCEDURE, one transaction, call each other too deeply, READ ONLY, read-only procedure, cannot be READ ONLY, --read-only-calls, KARELADB\_READ\_ONLY\_CALLS, rounding, 6 decimals, match old system
- See also: [The procedure language](procedure-language.md), [Triggers](triggers.md), [Transactions](transactions.md), [Saved functions](saved-functions.md), [13. Functions, procedures and triggers](../tutorial/13-functions-procedures-triggers.md)

A **stored procedure** (or just "procedure") is a list of SQL statements with a name. You run it with `CALL name(...)`.
KarelaDB keeps it in the database, like a table. Your app, the web console and `kareladb sql` can all call it.

- A procedure can have **variables**, `IF`, loops, cursors and errors (see [the procedure language](procedure-language.md)).
- **A `CALL` is one transaction** (a group of changes that are saved together, or not at all). If one step fails, nothing of the `CALL` is saved.

A real job: after the market closes, a trading app builds the daily candle of each share from the one-minute candles.

**Example: End of day: build the daily candles from the minute candles** (sample data: sample)

```sql
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

CALL end_of_day('2026-09-10');
```

Result:

`CREATE PROCEDURE end_of_day(day DATE) AS BEGIN`

```text
procedure 'end_of_day' created
```

`CALL end_of_day('2026-09-10')`

```text
procedure 'end_of_day' done: 2 row(s) changed
```

`SELECT symbol, open, high, low, close, volume FROM ochl_day WHERE time = day ORDER BY symbol`

| symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| CITY | 504.6 | 507 | 500.7 | 504.9 | 183040 |
| COAST | 380.1 | 382 | 373.2 | 376.1 | 186200 |
| VOLT | 185.6 | 192.1 | 184.2 | 191.2 | 41470 |

(3 rows)

`print`

| output (STRING) |
|---|
| 476 minute candles read |

(1 row)

<a id="create-procedure"></a>

## CREATE PROCEDURE

Syntax:

```sql
CREATE [OR REPLACE] PROCEDURE name(parameter TYPE, ...) [READ ONLY] AS BEGIN
  statement;
  statement;
  ...
END
```

Saves a procedure. `OR REPLACE` changes one that already exists.

| Part | Meaning |
|---|---|
| `name` | the procedure name. Upper and lower case are the same. |
| `parameter TYPE` | an input value and its type, like `day DATE` or `amt DECIMAL(2)`. Write `()` for none. |
| `READ ONLY` | optional: the procedure changes no data. KarelaDB refuses a body that does, and every `CALL` of it runs like a `SELECT`. See [a CALL that only reads](procedures.md#read-only-call). |
| `BEGIN ... END` | the body. Every statement in it ends with `;`. |

What a body can hold: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `CALL`, `SHOW ...`, `EXPLAIN`, and the procedure statements `DECLARE`, `SET`, `IF`, `WHILE`, `FOR`, `OPEN`, `FETCH`, `CLOSE`, `RETURN`, `RAISE` and `PRINT` ([the procedure language](procedure-language.md)).

- **Returns:** `procedure 'name' created` (or `replaced`).
- **Notes:**
  - `CREATE`, `DROP`, `ALTER`, `BACKUP`, `BEGIN`, `COMMIT` and `ROLLBACK` cannot be used inside a body. A `CALL` is already one transaction.
  - KarelaDB checks the **grammar** of the body when you create the procedure. Tables and columns are checked only when it runs, so a procedure can use a table that you create later.
  - `found` cannot be a parameter name: every procedure already has a variable `FOUND`.
  - **A column name wins over a parameter with the same name.** Give parameters names that are not column names (`amt`, not `amount`; `wanted`, not `name`).
  - `CREATE PROCEDURE` cannot be used inside `BEGIN ... COMMIT`.
  - In `kareladb shell`, KarelaDB knows that `CREATE PROCEDURE ... BEGIN ... END;` is one statement, even with `;` inside.

Setup used by the examples below:

```sql
-- A small bank: accounts, and a ledger with one row for every transfer.
CREATE TABLE accounts (
  id INT PRIMARY KEY,
  owner STRING NOT NULL,
  balance DECIMAL(2) NOT NULL DEFAULT 0
);
CREATE TABLE ledger (
  id LONG PRIMARY KEY AUTO,
  from_account INT NOT NULL REFERENCES accounts(id),
  to_account INT NOT NULL REFERENCES accounts(id),
  amount DECIMAL(2) NOT NULL,
  created TIMESTAMP DEFAULT now()
);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0), (3, 'Hari', 500);
```

**Example: Accounting: move money between two accounts (double entry)**

```sql
CREATE PROCEDURE transfer(from_id INT, to_id INT, amt DECIMAL(2)) AS BEGIN
  DECLARE have DECIMAL(2);
  IF amt <= 0 THEN
    RAISE 'the amount must be more than 0';
  END IF;
  SET have = (SELECT balance FROM accounts WHERE id = from_id);
  IF have IS NULL THEN
    RAISE concat('account ', from_id, ' does not exist');
  ELSIF have < amt THEN
    RAISE concat('not enough money: account ', from_id, ' has ', have, ', the transfer needs ', amt);
  END IF;
  UPDATE accounts SET balance = balance - amt WHERE id = from_id;
  UPDATE accounts SET balance = balance + amt WHERE id = to_id;
  INSERT INTO ledger (from_account, to_account, amount) VALUES (from_id, to_id, amt);
  PRINT concat('moved ', amt, ' from account ', from_id, ' to account ', to_id);
END;

CALL transfer(1, 2, 250.50);
SELECT id, owner, balance FROM accounts ORDER BY id;
```

Result:

`CREATE PROCEDURE transfer(from_id INT, to_id INT, amt DECIMAL(2)) AS BEGIN`

```text
procedure 'transfer' created
```

`CALL transfer(1, 2, 250.50)`

```text
procedure 'transfer' done: 3 row(s) changed
```

`print`

| output (STRING) |
|---|
| moved 250.50 from account 1 to account 2 |

(1 row)

`SELECT id, owner, balance FROM accounts ORDER BY id`

| id (INT) | owner (STRING) | balance (DECIMAL(2)) |
|---|---|---|
| 1 | Ram | 749.50 |
| 2 | Sita | 250.50 |
| 3 | Hari | 500.00 |

(3 rows)

**Example: Forum: a new post and its topic counter in one step**

```sql
CREATE TABLE topics (id INT PRIMARY KEY, title STRING NOT NULL, posts LONG NOT NULL DEFAULT 0);
CREATE TABLE posts (id LONG PRIMARY KEY AUTO, topic_id INT NOT NULL REFERENCES topics(id), author STRING, body STRING, created TIMESTAMP DEFAULT now());
INSERT INTO topics (id, title) VALUES (1, 'CITY quarterly results');

CREATE PROCEDURE add_post(topic INT, who STRING, text STRING) AS BEGIN
  IF length(trim(text)) = 0 THEN
    RAISE 'a post cannot be empty';
  END IF;
  INSERT INTO posts (topic_id, author, body) VALUES (topic, who, text);
  UPDATE topics SET posts = posts + 1 WHERE id = topic;
END;

CALL add_post(1, 'ram', 'Profit is up 12%.');
CALL add_post(1, 'sita', 'Good for the dividend.');
SELECT id, title, posts FROM topics;
```

Result:

`CREATE TABLE topics (`

```text
table 'topics' created
```

`CREATE TABLE posts (`

```text
table 'posts' created
```

`INSERT INTO topics (id, title) VALUES (1, 'CITY quarterly results')`

```text
1 row(s) inserted
```

`CREATE PROCEDURE add_post(topic INT, who STRING, text STRING) AS BEGIN`

```text
procedure 'add_post' created
```

`CALL add_post(1, 'ram', 'Profit is up 12%.')`

```text
procedure 'add_post' done: 2 row(s) changed
```

`CALL add_post(1, 'sita', 'Good for the dividend.')`

```text
procedure 'add_post' done: 2 row(s) changed
```

`SELECT id, title, posts FROM topics`

| id (INT) | title (STRING) | posts (LONG) |
|---|---|---|
| 1 | CITY quarterly results | 2 |

(1 row)

**Example: Tables are checked when the procedure runs, not when it is created** (shows an error)

```sql
CREATE PROCEDURE count_archive() AS BEGIN
  SELECT count(*) AS rows_in_archive FROM archive;
END;
CREATE TABLE audit (id INT PRIMARY KEY);
CALL count_archive();
```

Result:

`CREATE PROCEDURE count_archive() AS BEGIN`

```text
procedure 'count_archive' created
```

`CREATE TABLE audit (`

```text
table 'audit' created
```

Error: `procedure 'count_archive', line 2 col 43: table or view 'archive' does not exist`

**Example: BEGIN cannot be used inside a body** (shows an error)

```sql
CREATE PROCEDURE p() AS BEGIN
  BEGIN;
  UPDATE accounts SET balance = 0;
  COMMIT;
END;
```

Result:

Error: `line 2, column 3: BEGIN cannot be used inside a procedure or trigger body: the whole CALL is one transaction (use RAISE to undo all of it)`

**Example: CREATE cannot be used inside a body** (shows an error)

```sql
CREATE PROCEDURE make_table() AS BEGIN
  CREATE TABLE archive (id INT);
END;
```

Result:

Error: `line 2, column 3: CREATE cannot be used inside a procedure or trigger body; expected SELECT, INSERT, UPDATE, DELETE, CALL, DECLARE, SET, IF, WHILE, FOR, OPEN, FETCH, CLOSE, RETURN, RAISE, PRINT or NOTIFY`

**Example: The name is already used** (shows an error)

```sql
CREATE PROCEDURE hello() AS BEGIN PRINT 'hello'; END;
CREATE PROCEDURE hello() AS BEGIN PRINT 'namaste'; END;
```

Result:

```text
procedure 'hello' created
```

Error: `procedure 'hello' already exists; use CREATE OR REPLACE PROCEDURE to change it`

<a id="call"></a>

## CALL

Syntax:

```sql
CALL name(argument, ...)
CALL name()
CALL name(argument, ...) WITH DEBUG
```

Runs a procedure. Each argument can be a value or an expression, like `'2026-09-10'` or `dateadd('d', -1, now())`.

- **Returns:** more than one result:
  1. the message `procedure 'name' done: N row(s) changed` (N counts the rows changed by `INSERT`, `UPDATE` and `DELETE` in the procedure and in the procedures it calls);
  2. the rows of every `SELECT` in the procedure, in order;
  3. a result called `print` with one row (column `output`) for each `PRINT`.
  The web console, `kareladb sql` and `POST /exec` show them like several statements.
- **Notes:**
  - Each argument is changed to the type of its parameter: `CALL end_of_day('2026-09-10')` turns the text into a `DATE`. A value that does not fit is an error.
  - The number of arguments must match.
  - Inside the body a parameter or variable is a plain value. `WHERE time >= day` skips partitions like a written date, also with `dateadd('d', 1, day)` around it. See [performance tips](performance-tips.md#parameters).
  - A procedure may `CALL` another procedure, or itself, at most **16 levels** deep.
  - `CALL` is one transaction: see [A CALL is one transaction](procedures.md#call-transaction).
  - When the `CALL` fails, the `print` lines from before the error are still returned, next to the error. Nothing that the procedure changed is saved.
  - Add `WITH DEBUG` to see every step: [CALL ... WITH DEBUG](procedures.md#with-debug).

**Example: Transfer, then look at the books**

```sql
CREATE PROCEDURE transfer(from_id INT, to_id INT, amt DECIMAL(2)) AS BEGIN
  IF (SELECT balance FROM accounts WHERE id = from_id) < amt THEN
    RAISE concat('not enough money in account ', from_id);
  END IF;
  UPDATE accounts SET balance = balance - amt WHERE id = from_id;
  UPDATE accounts SET balance = balance + amt WHERE id = to_id;
  INSERT INTO ledger (from_account, to_account, amount) VALUES (from_id, to_id, amt);
  SELECT id, owner, balance FROM accounts WHERE id IN (from_id, to_id) ORDER BY id;
  PRINT concat('ledger rows now: ', (SELECT count(*) FROM ledger));
END;
CALL transfer(3, 2, 120);
```

Result:

`CREATE PROCEDURE transfer(from_id INT, to_id INT, amt DECIMAL(2)) AS BEGIN`

```text
procedure 'transfer' created
```

`CALL transfer(3, 2, 120)`

```text
procedure 'transfer' done: 3 row(s) changed
```

`SELECT id, owner, balance FROM accounts WHERE id IN (from_id, to_id) ORDER BY id`

| id (INT) | owner (STRING) | balance (DECIMAL(2)) |
|---|---|---|
| 2 | Sita | 120.00 |
| 3 | Hari | 380.00 |

(2 rows)

`print`

| output (STRING) |
|---|
| ledger rows now: 1 |

(1 row)

**Example: A text argument becomes a DATE** (sample data: sample)

```sql
CREATE PROCEDURE trades_of(day DATE) AS BEGIN
  SELECT symbol, count(*) AS trades, sum(quantity) AS shares
  FROM trade_log WHERE date = day GROUP BY symbol ORDER BY symbol;
END;
CALL trades_of('2026-09-09');
```

Result:

`CREATE PROCEDURE trades_of(day DATE) AS BEGIN`

```text
procedure 'trades_of' created
```

`CALL trades_of('2026-09-09')`

```text
procedure 'trades_of' done: 0 row(s) changed
```

`SELECT symbol, count(*) AS trades, sum(quantity) AS shares FROM trade_log WHERE date = day GROUP BY `

| symbol (SYMBOL) | trades (LONG) | shares (LONG) |
|---|---|---|
| CITY | 4 | 1510 |
| COAST | 2 | 220 |
| TELCO | 2 | 2000 |

(3 rows)

**Example: Wrong number of arguments** (shows an error)

```sql
CREATE PROCEDURE pay(to_id INT, amt DECIMAL(2)) AS BEGIN
  UPDATE accounts SET balance = balance + amt WHERE id = to_id;
END;
CALL pay(2);
```

Result:

```text
procedure 'pay' created
```

Error: `procedure 'pay' takes 2 argument(s) (to_id INT, amt DECIMAL(2)), got 1`

**Example: An argument that does not fit the type** (shows an error)

```sql
CREATE PROCEDURE close_account(account INT) AS BEGIN
  DELETE FROM accounts WHERE id = account;
END;
CALL close_account('Ram');
```

Result:

```text
procedure 'close_account' created
```

Error: `argument 1 of procedure 'close_account': variable 'account' (INT): 'Ram' is not a whole number`

**Example: No such procedure** (shows an error)

```sql
CALL no_such_procedure();
```

Result:

Error: `procedure 'no_such_procedure' does not exist (SHOW PROCEDURES lists them)`

**Example: A procedure that calls itself too often** (shows an error)

```sql
CREATE PROCEDURE countdown(n INT) AS BEGIN
  PRINT n;
  IF n > 0 THEN
    CALL countdown(n - 1);
  END IF;
END;
CALL countdown(3);
CALL countdown(20);
```

Result:

`CREATE PROCEDURE countdown(n INT) AS BEGIN`

```text
procedure 'countdown' created
```

`CALL countdown(3)`

```text
procedure 'countdown' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| 3 |
| 2 |
| 1 |
| 0 |

(4 rows)

`print`

| output (STRING) |
|---|
| 20 |
| 19 |
| 18 |
| 17 |
| 16 |
| 15 |
| 14 |
| 13 |
| 12 |
| 11 |
| 10 |
| 9 |
| 8 |
| 7 |
| 6 |
| 5 |

(16 rows)

Error: `procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedure 'countdown', line 4: procedures call each other too deeply (more than 16 levels, at procedure 'countdown')`

<a id="call-transaction"></a>

## A CALL is one transaction

Syntax:

```sql
CALL name(...)                        -- one transaction by itself
BEGIN; CALL a(...); CALL b(...); COMMIT;   -- part of a bigger transaction
```

All changes of a `CALL` are saved **together** when it ends, with one write to the log (the file where KarelaDB writes every change first).
If any statement fails, or `RAISE` runs, **nothing** of the `CALL` is saved, also not the steps before the error.

- Statements inside the procedure see the changes made earlier in the same `CALL`.
- Inside `BEGIN ... COMMIT`, a `CALL` is part of that bigger transaction. An error in the `CALL` rolls back (undoes) the whole transaction. See [transactions](transactions.md).
- Triggers that the procedure fires are part of the same transaction too.
- At most 10 million changed rows in one transaction.
- Before it starts, a `CALL` locks every table its body (and the procedures and triggers it sets off) reads or changes, until it ends. Writers of other tables go on meanwhile; writers of these tables wait. A body with [`EXECUTE`](procedure-language.md#execute) of text made while it runs locks every table. See [one writer per table](transactions.md#one-writer).
- A long `CALL` lets readers of its tables in between its statements ([reader yield](transactions.md#reader-yield), on unless the server turns it off). One long statement inside it still makes them wait until it ends. Readers of other tables do not wait at all ([per-table reads](transactions.md#per-table-reads)).
- A `CALL` that changes nothing is not a transaction at all: it locks nothing and runs like a `SELECT`. See [a CALL that only reads](procedures.md#read-only-call).

In this example the first `UPDATE` takes 100 from Ram. Then the ledger row fails, because account 99 does not exist. The whole `CALL` is undone, so Ram still has 1000.

**Command line: A failed CALL saves nothing** (shows an error)

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL DEFAULT 0);
CREATE TABLE ledger (id LONG PRIMARY KEY AUTO, from_account INT NOT NULL REFERENCES accounts(id), to_account INT NOT NULL REFERENCES accounts(id), amount DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
CREATE PROCEDURE transfer(from_id INT, to_id INT, amt DECIMAL(2)) AS BEGIN
  UPDATE accounts SET balance = balance - amt WHERE id = from_id;
  UPDATE accounts SET balance = balance + amt WHERE id = to_id;
  INSERT INTO ledger (from_account, to_account, amount) VALUES (from_id, to_id, amt);
END;
```

```bash
kareladb sql market "CALL transfer(1, 99, 100)"
kareladb sql market "SELECT id, owner, balance FROM accounts ORDER BY id"
```

Output:

`> kareladb sql market "CALL transfer(1, 99, 100)"`

```text
error: procedure 'transfer', line 4: column 'to_account' = '99' has no matching row in accounts(id)
```

exit code 1

`> kareladb sql market "SELECT id, owner, balance FROM accounts ORDER BY id"`

```text
id | owner | balance
---+-------+--------
 1 | Ram   | 1000.00
 2 | Sita  |    0.00
(2 rows, 0.2 ms)
```

**Example: Two CALLs in one transaction, then ROLLBACK**

```sql
CREATE PROCEDURE deposit(account INT, amt DECIMAL(2)) AS BEGIN
  UPDATE accounts SET balance = balance + amt WHERE id = account;
END;
BEGIN;
CALL deposit(2, 100);
CALL deposit(3, 100);
SELECT id, balance FROM accounts ORDER BY id;
ROLLBACK;
SELECT id, balance FROM accounts ORDER BY id;
```

Result:

`CREATE PROCEDURE deposit(account INT, amt DECIMAL(2)) AS BEGIN`

```text
procedure 'deposit' created
```

`BEGIN`

```text
transaction started
```

`CALL deposit(2, 100)`

```text
procedure 'deposit' done: 1 row(s) changed
```

`CALL deposit(3, 100)`

```text
procedure 'deposit' done: 1 row(s) changed
```

`SELECT id, balance FROM accounts ORDER BY id`

| id (INT) | balance (DECIMAL(2)) |
|---|---|
| 1 | 1000.00 |
| 2 | 100.00 |
| 3 | 600.00 |

(3 rows)

`ROLLBACK`

```text
transaction rolled back: 2 change(s) undone
```

`SELECT id, balance FROM accounts ORDER BY id`

| id (INT) | balance (DECIMAL(2)) |
|---|---|
| 1 | 1000.00 |
| 2 | 0.00 |
| 3 | 500.00 |

(3 rows)

<a id="read-only-call"></a>

## A CALL that only reads

Syntax:

```sql
CREATE PROCEDURE name(...) READ ONLY AS BEGIN ... END   -- promised: it never changes data
CALL name(...)                                          -- runs like a SELECT
```

A procedure that only reads (a report, a lookup, a chart query) runs like a `SELECT`:

- it locks no table and starts no transaction;
- it does not wait for writers of the tables it reads, and it does not make readers wait;
- it sees the last committed rows, like a `SELECT`. Changes of an open transaction are not seen.
- a long one does not hold writers up either: when a writer waits, it lets it in between two of its statements. So each statement sees the rows committed when that statement starts.

KarelaDB works this out by itself before each `CALL`, from everything the body runs: the procedures it calls, the views and saved functions it uses.
A `CALL` stays a normal transaction (it locks its tables) when its body, or anything it calls, has one of these:

| In the body | Why |
|---|---|
| `INSERT`, `UPDATE`, `DELETE` | it changes data |
| `SELECT ... FOR UPDATE` | it locks rows for a later change |
| `nextval`, `setval`, `set_config`, `pg_advisory_...`, `pg_sleep` | they change state, or wait on purpose |
| [`EXECUTE`](procedure-language.md#execute) of text made while it runs (`'...' \|\| name`) | KarelaDB cannot tell what it runs |
| `SHOW ...`, `information_schema` or `pg_catalog` | they read the whole database |
| `EXPLAIN CALL` | it works through another procedure's steps |

`EXPLAIN` of anything else only shows a plan, so it does not count as a change.

Write **`READ ONLY`** to make it a promise:

- `CREATE PROCEDURE` refuses a body that changes data, with the reason: `procedure 'x' cannot be READ ONLY: it changes table 'accounts'`.
- If a procedure it calls is later replaced by one that writes, its `CALL` fails before it runs: `procedure 'x' is declared READ ONLY, but it changes table ...`. Nothing is changed.

- **Notes:**
  - Inside `BEGIN ... COMMIT`, a read-only `CALL` is part of the transaction and sees its changes, like any statement there.
  - `kareladb serve --read-only-calls off` (or `KARELADB_READ_ONLY_CALLS=off`) makes every `CALL` a transaction again, as before. `READ ONLY` is then only checked when the procedure is created.
  - A database with a `READ ONLY` procedure cannot be opened by a KarelaDB older than 2026-09-24 ([versions](versions.md)).

**Example: A report procedure that only reads**

```sql
CREATE PROCEDURE rich_accounts(at_least DECIMAL(2)) READ ONLY AS BEGIN
  SELECT id, owner, balance FROM accounts WHERE balance >= at_least ORDER BY id;
  PRINT concat((SELECT count(*) FROM ledger), ' ledger rows');
END;
CALL rich_accounts(100);
```

Result:

`CREATE PROCEDURE rich_accounts(at_least DECIMAL(2)) READ ONLY AS BEGIN`

```text
procedure 'rich_accounts' created
```

`CALL rich_accounts(100)`

```text
procedure 'rich_accounts' done: 0 row(s) changed
```

`SELECT id, owner, balance FROM accounts WHERE balance >= at_least ORDER BY id`

| id (INT) | owner (STRING) | balance (DECIMAL(2)) |
|---|---|---|
| 1 | Ram | 1000.00 |
| 3 | Hari | 500.00 |

(2 rows)

`print`

| output (STRING) |
|---|
| 0 ledger rows |

(1 row)

**Example: READ ONLY refuses a body that changes data** (shows an error)

```sql
CREATE PROCEDURE empty_accounts() READ ONLY AS BEGIN
  UPDATE accounts SET balance = 0;
END;
```

Result:

Error: `procedure 'empty_accounts' cannot be READ ONLY: it changes table 'accounts'. Take READ ONLY away to let it change data`

<a id="rounding"></a>

## Matching another system's rounding

A `DOUBLE` keeps about 16 digits: `9609.0 / 17` is `565.2352941176...` in KarelaDB.
Many programs round a rate before they store it, for example to 6 places: `565.235294`.

When a procedure takes over a job from such a program, round the same way, with [`round(x, 6)`](functions-math.md#round):

| Where | Why |
|---|---|
| every rate or ratio the procedure stores | the stored numbers then equal the old program's, digit for digit |
| both sides of a comparison in a filter | a difference in the 7th place can flip `a > b`, so a row appears or disappears |

- `round` halves go away from zero (`round(0.5)` is `1`), like `math.Round` in Go.
- Compare the two systems' tables to the same number of places. A check that allows a tiny difference does not show that one side stores more digits.
- For money that must add up exactly, use a [`DECIMAL`](column-types.md#decimal) column instead.

**Example: Store the buy rate rounded to 6 places**

Setup:

```sql
CREATE TABLE broker_day (broker INT, amount DOUBLE, quantity LONG);
INSERT INTO broker_day VALUES (1, 9609, 17), (2, 1245.5, 3);
CREATE TABLE broker_rate (broker INT PRIMARY KEY, buy_rate DOUBLE, buy_rate_full DOUBLE);
CREATE PROCEDURE build_rates() AS BEGIN
  DELETE FROM broker_rate;
  INSERT INTO broker_rate SELECT broker, round(amount / quantity, 6), amount / quantity FROM broker_day;
END;
```

```sql
CALL build_rates();
SELECT broker, buy_rate, buy_rate_full FROM broker_rate ORDER BY broker;
```

Result:

`CALL build_rates()`

```text
procedure 'build_rates' done: 2 row(s) changed
```

`SELECT broker, buy_rate, buy_rate_full FROM broker_rate ORDER BY broker`

| broker (INT) | buy_rate (DOUBLE) | buy_rate_full (DOUBLE) |
|---|---|---|
| 1 | 565.235294 | 565.235294117647 |
| 2 | 415.166667 | 415.166666666667 |

(2 rows)

**Example: Round both sides before a filter compares them**

```sql
SELECT 9609.0 / 17 > 565.235294 AS full_is_bigger,
       round(9609.0 / 17, 6) > 565.235294 AS rounded_is_bigger;
```

Result:

| full_is_bigger (BOOL) | rounded_is_bigger (BOOL) |
|---|---|
| true | false |

(1 row)

<a id="with-debug"></a>

## CALL ... WITH DEBUG

Syntax:

```sql
CALL name(argument, ...) WITH DEBUG
```

Runs the procedure and adds a result called `debug`, with one row for every step it took.
Use it to find out why a procedure does something you did not expect.

| Column | Meaning |
|---|---|
| `step` | 1, 2, 3, ... in the order the steps started |
| `routine` | the procedure the step is in, or `trigger name` for a trigger. Empty for the `CALL` itself. |
| `statement` | the statement, or the control line: `IF ... THEN`, `ELSIF ... THEN`, `ELSE`, `WHILE ... DO`, `FOR r IN (...) DO`, `FOR r: row 2 of 5` |
| `rows` | rows changed (`INSERT`, `UPDATE`, `DELETE`, `CALL`), rows returned (`SELECT`), rows read (`OPEN`, `FOR`) |
| `time_us` | the time of the step in microseconds (millionths of a second). The first row is the whole `CALL`. |
| `changes` | variables that got a new value (`have=1000.00`), the result of a condition (`true` or `false`), the `PRINT` text, the values of a `FOR` row, or `failed: <error>`. A statement that read a table also says `partitions read: N`; so do `IF`, `WHILE` and `FOR` lines whose query read one, and the `CALL` row counts the whole call. |

- **Returns:** the usual results of the `CALL`, and the `debug` result last.
- **Notes:**
  - With `WITH DEBUG`, the `PRINT` lines are in the `debug` result; there is no separate `print` result.
  - When the `CALL` fails, the `debug` rows up to the error are still returned, and the last one says `failed`.
  - Triggers that run during the `CALL` add their steps too.
  - At most 100,000 steps are kept. Long statement text is cut after 200 characters.
  - `time_us` is different every time you run it.
  - `partitions read` shows whether a time filter skipped partitions: a step that reads all of them where you expected one needs a look. Rows scanned are not counted. To see the plan without running anything, use [EXPLAIN CALL](explain.md#explain-call).

**Example: Every step of a transfer**

```sql
CREATE PROCEDURE transfer(from_id INT, to_id INT, amt DECIMAL(2)) AS BEGIN
  DECLARE have DECIMAL(2) DEFAULT (SELECT balance FROM accounts WHERE id = from_id);
  IF have < amt THEN
    RAISE concat('not enough money in account ', from_id);
  ELSIF amt >= 500 THEN
    PRINT 'big transfer: check it by hand';
  END IF;
  UPDATE accounts SET balance = balance - amt WHERE id = from_id;
  UPDATE accounts SET balance = balance + amt WHERE id = to_id;
  INSERT INTO ledger (from_account, to_account, amount) VALUES (from_id, to_id, amt);
END;
CALL transfer(1, 2, 600) WITH DEBUG;
```

Result:

`CREATE PROCEDURE transfer(from_id INT, to_id INT, amt DECIMAL(2)) AS BEGIN`

```text
procedure 'transfer' created
```

`CALL transfer(1, 2, 600) WITH DEBUG`

```text
procedure 'transfer' done: 3 row(s) changed
```

`debug`

| step (LONG) | routine (STRING) | statement (STRING) | rows (LONG) | time_us (LONG) | changes (STRING) |
|---|---|---|---|---|---|
| 1 |  | CALL transfer(1, 2, 600) WITH DEBUG | 3 | 660 |  |
| 2 | transfer | DECLARE have DECIMAL(2) DEFAULT (SELECT balance FROM accounts WHERE id = from_id) | 0 | 80 | have=1000.00 |
| 3 | transfer | IF have < amt THEN | 0 | 7 | false |
| 4 | transfer | ELSIF amt >= 500 THEN | 0 | 2 | true |
| 5 | transfer | PRINT 'big transfer: check it by hand' | 0 | 0 | big transfer: check it by hand |
| 6 | transfer | UPDATE accounts SET balance = balance - amt WHERE id = from_id | 1 | 49 |  |
| 7 | transfer | UPDATE accounts SET balance = balance + amt WHERE id = to_id | 1 | 9 |  |
| 8 | transfer | INSERT INTO ledger (from_account, to_account, amount) VALUES (from_id, to_id, amt) | 1 | 69 |  |

(8 rows)

**Example: The debug rows of a CALL that fails** (shows an error)

```sql
CREATE PROCEDURE transfer(from_id INT, to_id INT, amt DECIMAL(2)) AS BEGIN
  DECLARE have DECIMAL(2) DEFAULT (SELECT balance FROM accounts WHERE id = from_id);
  IF have < amt THEN
    RAISE concat('not enough money in account ', from_id, ': it has ', have);
  END IF;
  UPDATE accounts SET balance = balance - amt WHERE id = from_id;
  UPDATE accounts SET balance = balance + amt WHERE id = to_id;
END;
CALL transfer(2, 1, 50) WITH DEBUG;
```

Result:

`CREATE PROCEDURE transfer(from_id INT, to_id INT, amt DECIMAL(2)) AS BEGIN`

```text
procedure 'transfer' created
```

`debug`

| step (LONG) | routine (STRING) | statement (STRING) | rows (LONG) | time_us (LONG) | changes (STRING) |
|---|---|---|---|---|---|
| 1 |  | CALL transfer(2, 1, 50) WITH DEBUG | 0 | 175 | failed |
| 2 | transfer | DECLARE have DECIMAL(2) DEFAULT (SELECT balance FROM accounts WHERE id = from_id) | 0 | 83 | have=0.00 |
| 3 | transfer | IF have < amt THEN | 0 | 5 | true |
| 4 | transfer | RAISE concat('not enough money in account ', from_id, ': it has ', have) | 0 | 53 | failed: not enough money in account 2: it has 0.00 |

(4 rows)

Error: `procedure 'transfer', line 4: not enough money in account 2: it has 0.00`

<a id="drop-procedure"></a>

## DROP PROCEDURE

Syntax:

```sql
DROP PROCEDURE [IF EXISTS] name
```

Removes a procedure.

- **Returns:** `procedure 'name' dropped`. With `IF EXISTS`, a name that does not exist gives the message `procedure 'name' does not exist` and no error.
- **Notes:** KarelaDB does not check who uses the procedure. Other procedures and triggers that `CALL` it fail when they run, with `procedure 'name' does not exist`. `DROP PROCEDURE` cannot be used inside `BEGIN ... COMMIT`.

**Example**

```sql
CREATE PROCEDURE hello() AS BEGIN PRINT 'hello'; END;
DROP PROCEDURE hello;
DROP PROCEDURE IF EXISTS hello;
```

Result:

`CREATE PROCEDURE hello() AS BEGIN`

```text
procedure 'hello' created
```

`DROP PROCEDURE hello`

```text
procedure 'hello' dropped
```

`DROP PROCEDURE IF EXISTS hello`

```text
procedure 'hello' does not exist
```

**Example: A trigger that calls a dropped procedure fails** (shows an error)

```sql
CREATE TABLE posts (id INT PRIMARY KEY, body STRING);
CREATE PROCEDURE recount() AS BEGIN PRINT 'counting'; END;
CREATE TRIGGER count_posts AFTER INSERT ON posts EXECUTE CALL recount();
DROP PROCEDURE recount;
INSERT INTO posts VALUES (1, 'hello');
```

Result:

`CREATE TABLE posts (`

```text
table 'posts' created
```

`CREATE PROCEDURE recount() AS BEGIN`

```text
procedure 'recount' created
```

`CREATE TRIGGER count_posts AFTER INSERT ON posts EXECUTE CALL recount()`

```text
trigger 'count_posts' created on table 'posts'
```

`DROP PROCEDURE recount`

```text
procedure 'recount' dropped
```

Error: `trigger 'count_posts', line 1: procedure 'recount' does not exist (SHOW PROCEDURES lists them)`

<a id="show-procedures"></a>

## SHOW PROCEDURES

Syntax:

```sql
SHOW PROCEDURES
```

Lists the procedures of the database, in name order.

| Column | Meaning |
|---|---|
| `name` | the procedure name |
| `arguments` | the parameters and their types |
| `definition` | the whole `CREATE PROCEDURE` statement, written again by KarelaDB (one statement per line) |

- **Notes:** the line numbers in error messages (`procedure 'transfer', line 4: ...`) count the lines of this `definition`: `CREATE PROCEDURE ... AS BEGIN` is line 1. The text table of `kareladb sql` cuts long text after 48 characters; use `--format csv` or `--format json` to see all of it.

**Example**

```sql
CREATE PROCEDURE deposit(account INT, amt DECIMAL(2)) AS BEGIN
  UPDATE accounts SET balance = balance + amt WHERE id = account;
END;
CREATE PROCEDURE hello() AS BEGIN PRINT 'hello'; END;
SHOW PROCEDURES;
```

Result:

`CREATE PROCEDURE deposit(account INT, amt DECIMAL(2)) AS BEGIN`

```text
procedure 'deposit' created
```

`CREATE PROCEDURE hello() AS BEGIN`

```text
procedure 'hello' created
```

`SHOW PROCEDURES`

| name (STRING) | arguments (STRING) | definition (STRING) |
|---|---|---|
| deposit | account INT, amt DECIMAL(2) | CREATE PROCEDURE deposit(account INT, amt DECIMAL(2)) AS BEGIN   UPDATE accounts SET balance = balance + amt WHERE id = account; END |
| hello |  | CREATE PROCEDURE hello() AS BEGIN   PRINT 'hello'; END |

(2 rows)
