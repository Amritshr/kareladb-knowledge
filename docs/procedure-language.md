# The procedure language

> Variables, IF, WHILE, FOR, RETURN, RAISE, PRINT and cursors inside a procedure or trigger body.

- Category: Stored procedures
- Keywords: variable, variables, loop, THEN, DO, IN, INTO, OPEN, FOUND, EXECUTE, dynamic SQL, EXECUTE format, USING, INTO STRICT, table name in a variable, sp_executesql, PREPARE, END IF, END WHILE, END FOR, FETCH INTO, OPEN cursor, declared twice, column name wins, WHILE loop ran, body, procedure body, trigger body
- See also: [Stored procedures](procedures.md), [Triggers](triggers.md), [Cursors](cursors.md), [Transactions](transactions.md), [13. Functions, procedures and triggers](../tutorial/13-functions-procedures-triggers.md)

These statements work only inside the body (`BEGIN ... END`) of a [procedure](procedures.md) or a [trigger](triggers.md).
Every statement ends with `;`.

| Statement | What it does |
|---|---|
| `SELECT`, `INSERT`, `UPDATE`, `DELETE` | as usual. A `SELECT` returns its rows as an extra result of the `CALL`. |
| `CALL other(...)` | runs another procedure (at most 16 levels deep) |
| `SHOW ...`, `EXPLAIN SELECT ...` | as usual; the rows are an extra result |
| [`DECLARE name TYPE [DEFAULT expr]`](procedure-language.md#declare) | makes a variable |
| [`SET name = expr`](procedure-language.md#set) | gives a variable a new value |
| [`IF ... THEN ... ELSIF ... ELSE ... END IF`](procedure-language.md#if) | chooses what to run |
| [`WHILE cond DO ... END WHILE`](procedure-language.md#while) | repeats while a condition is true |
| [`FOR r IN (SELECT ...) DO ... END FOR`](procedure-language.md#for) | runs once for every row of a query |
| [`RETURN`](procedure-language.md#return) | stops the procedure; its changes are kept |
| [`RAISE expr`](procedure-language.md#raise) | stops with an error; **everything is undone** |
| [`PRINT expr`](procedure-language.md#print) | adds a line to the `print` result |
| [`EXECUTE text [INTO v, ...] [USING a, ...]`](procedure-language.md#execute) | runs SQL made while the procedure runs (dynamic SQL) |
| [`DECLARE c CURSOR FOR SELECT`, `OPEN`, `FETCH ... INTO`, `CLOSE`](procedure-language.md#local-cursors) | reads a query one row at a time |

Not allowed in a body: `CREATE`, `DROP`, `ALTER`, `RENAME`, `BACKUP`, `BEGIN`, `COMMIT`, `ROLLBACK`.

**Example: Brokerage fee of a stock trade, with variables and IF**

```sql
CREATE PROCEDURE fee_of(amount_in DECIMAL(2)) AS BEGIN
  DECLARE rate DOUBLE;
  DECLARE fee DECIMAL(2);
  IF amount_in <= 50000 THEN
    SET rate = 0.0036;
  ELSIF amount_in <= 500000 THEN
    SET rate = 0.0033;
  ELSE
    SET rate = 0.0027;
  END IF;
  SET fee = round(greatest(amount_in * rate, 10), 2);
  PRINT concat('amount ', amount_in, ': rate ', rate * 100, '%, fee ', fee);
END;

CALL fee_of(1500);
CALL fee_of(258500);
CALL fee_of(881000);
```

Result:

`CREATE PROCEDURE fee_of(amount_in DECIMAL(2)) AS BEGIN`

```text
procedure 'fee_of' created
```

`CALL fee_of(1500)`

```text
procedure 'fee_of' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| amount 1500.00: rate 0.36%, fee 10.00 |

(1 row)

`CALL fee_of(258500)`

```text
procedure 'fee_of' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| amount 258500.00: rate 0.33%, fee 853.05 |

(1 row)

`CALL fee_of(881000)`

```text
procedure 'fee_of' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| amount 881000.00: rate 0.27%, fee 2378.70 |

(1 row)

<a id="declare"></a>

## DECLARE

Syntax:

```sql
DECLARE name TYPE
DECLARE name TYPE DEFAULT expression
```

Makes a variable: a named place for one value, like `have` or `total`.

| Part | Meaning |
|---|---|
| `name` | the variable name. Upper and lower case are the same. |
| `TYPE` | any column type: `INT`, `LONG`, `DOUBLE`, `DECIMAL(2)`, `STRING`, `SYMBOL`, `BOOL`, `DATE`, `TIMESTAMP`, ... |
| `DEFAULT expression` | the first value. It may use parameters, earlier variables and a subquery `(SELECT ...)`. Without `DEFAULT`, the value is `NULL`. |

- **Notes:**
  - Use a variable by its name in any expression: `WHERE id = from_id`, `VALUES (day, total)`.
  - Parameters are variables too: `SET` can change them.
  - A value is changed to the variable's type. A value that does not fit is an error (`'abc' is not a whole number`).
  - **A column name wins over a variable with the same name.** Inside `SELECT ... FROM securities`, the name `name` means the column, not your variable. Give variables names that are not column names.
  - A variable lives until the end of the procedure (not only until the end of an `IF` or loop). A `DECLARE` inside a loop fails the second time round: `variable 'x' is declared twice`. Declare before the loop.
  - Every procedure and trigger already has the variable `FOUND` (see [cursors in a body](procedure-language.md#local-cursors)). You cannot declare it.
  - `DECLARE name CURSOR FOR SELECT ...` makes a cursor, not a variable.

**Example: Variables of many types, with and without DEFAULT**

```sql
CREATE PROCEDURE show_types() AS BEGIN
  DECLARE qty INT DEFAULT 500;
  DECLARE rate DOUBLE DEFAULT 514.5;
  DECLARE amount_npr DECIMAL(2) DEFAULT qty * rate;
  DECLARE symbol_name SYMBOL DEFAULT 'CITY';
  DECLARE trade_day DATE DEFAULT '2026-09-10';
  DECLARE note STRING;
  PRINT concat(qty, ' x ', rate, ' = ', amount_npr, ' for ', symbol_name, ' on ', trade_day);
  PRINT coalesce(note, 'note is NULL');
END;
CALL show_types();
```

Result:

`CREATE PROCEDURE show_types() AS BEGIN`

```text
procedure 'show_types' created
```

`CALL show_types()`

```text
procedure 'show_types' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| 500 x 514.5 = 257250.00 for CITY on 2026-09-10 |
| note is NULL |

(2 rows)

**Example: The trap: a column name wins over a variable** (sample data: sample)

```sql
CREATE PROCEDURE count_sector_wrong(name STRING) AS BEGIN
  SELECT count(*) AS shares FROM securities WHERE sector = name;
END;
CREATE PROCEDURE count_sector(wanted STRING) AS BEGIN
  SELECT count(*) AS shares FROM securities WHERE sector = wanted;
END;
CALL count_sector_wrong('Banking');
CALL count_sector('Banking');
```

Result:

`CREATE PROCEDURE count_sector_wrong(name STRING) AS BEGIN`

```text
procedure 'count_sector_wrong' created
```

`CREATE PROCEDURE count_sector(wanted STRING) AS BEGIN`

```text
procedure 'count_sector' created
```

`CALL count_sector_wrong('Banking')`

```text
procedure 'count_sector_wrong' done: 0 row(s) changed
```

`SELECT count(*) AS shares FROM securities WHERE sector = name`

| shares (LONG) |
|---|
| 0 |

(1 row)

`CALL count_sector('Banking')`

```text
procedure 'count_sector' done: 0 row(s) changed
```

`SELECT count(*) AS shares FROM securities WHERE sector = wanted`

| shares (LONG) |
|---|
| 2 |

(1 row)

**Example: DECLARE inside a loop** (shows an error)

```sql
CREATE PROCEDURE p() AS BEGIN
  DECLARE i INT DEFAULT 0;
  WHILE i < 3 DO
    DECLARE doubled INT DEFAULT i * 2;
    SET i = i + 1;
  END WHILE;
END;
CALL p();
```

Result:

```text
procedure 'p' created
```

Error: `procedure 'p', line 4: variable 'doubled' is declared twice`

<a id="set"></a>

## SET

Syntax:

```sql
SET name = expression
SET name = (SELECT one_value FROM ...)
```

Gives a variable (or a parameter) a new value.

- **Notes:**
  - The variable must be declared first.
  - `SET x = (SELECT ...)` takes one value from a query. **No row** gives `NULL`. **More than one row** is an error: add `WHERE` or `LIMIT 1`.
  - The value is changed to the variable's type, like `CAST`.
  - A `DECIMAL(2)` variable refuses a value with more decimals (`1000.105 has more than 2 decimal places`). It does not round by itself: use `round(value, 2)`.
  - The query sees the changes made earlier in the same `CALL`.
  - `UPDATE` and `DELETE` may hold a subquery. Reading the value into a variable with `SET` first is often clearer, and lets you use it more than once. For many rows, use a [`FOR`](procedure-language.md#for) loop.

**Example: Read a balance into a variable, then change it**

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL DEFAULT 0);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);

CREATE PROCEDURE check_balance(account INT) AS BEGIN
  DECLARE have DECIMAL(2);
  SET have = (SELECT balance FROM accounts WHERE id = account);
  PRINT concat('account ', account, ' has ', coalesce(CAST(have AS STRING), 'no row: NULL'));
  SET have = have + round(have * 0.00105, 2);
  PRINT concat('with interest: ', have);
END;
CALL check_balance(1);
CALL check_balance(7);
```

Result:

`CREATE TABLE accounts (`

```text
table 'accounts' created
```

`INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0)`

```text
2 row(s) inserted
```

`CREATE PROCEDURE check_balance(account INT) AS BEGIN`

```text
procedure 'check_balance' created
```

`CALL check_balance(1)`

```text
procedure 'check_balance' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| account 1 has 1000.00 |
| with interest: 1001.05 |

(2 rows)

`CALL check_balance(7)`

```text
procedure 'check_balance' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| account 7 has no row: NULL |
| with interest:  |

(2 rows)

**Example: A subquery inside UPDATE: use a variable instead**

```sql
CREATE TABLE topics (id INT PRIMARY KEY, posts LONG NOT NULL DEFAULT 0);
CREATE TABLE posts (id LONG PRIMARY KEY, topic_id INT NOT NULL);
INSERT INTO topics (id) VALUES (1);
INSERT INTO posts VALUES (1, 1), (2, 1), (3, 1);

CREATE PROCEDURE recount(topic INT) AS BEGIN
  DECLARE n LONG;
  SET n = (SELECT count(*) FROM posts WHERE topic_id = topic);
  UPDATE topics SET posts = n WHERE id = topic;
END;
CALL recount(1);
SELECT * FROM topics;
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

`INSERT INTO topics (id) VALUES (1)`

```text
1 row(s) inserted
```

`INSERT INTO posts VALUES (1, 1), (2, 1), (3, 1)`

```text
3 row(s) inserted
```

`CREATE PROCEDURE recount(topic INT) AS BEGIN`

```text
procedure 'recount' created
```

`CALL recount(1)`

```text
procedure 'recount' done: 1 row(s) changed
```

`SELECT * FROM topics`

| id (INT) | posts (LONG) |
|---|---|
| 1 | 3 |

(1 row)

**Example: The same with the subquery inside UPDATE**

```sql
CREATE TABLE topics (id INT PRIMARY KEY, posts LONG NOT NULL DEFAULT 0);
CREATE TABLE posts (id LONG PRIMARY KEY, topic_id INT NOT NULL);
INSERT INTO topics (id) VALUES (1);
INSERT INTO posts VALUES (1, 1), (2, 1), (3, 1);

CREATE PROCEDURE recount(topic INT) AS BEGIN
  UPDATE topics SET posts = (SELECT count(*) FROM posts WHERE topic_id = topic) WHERE id = topic;
END;
CALL recount(1);
SELECT * FROM topics;
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

`INSERT INTO topics (id) VALUES (1)`

```text
1 row(s) inserted
```

`INSERT INTO posts VALUES (1, 1), (2, 1), (3, 1)`

```text
3 row(s) inserted
```

`CREATE PROCEDURE recount(topic INT) AS BEGIN`

```text
procedure 'recount' created
```

`CALL recount(1)`

```text
procedure 'recount' done: 1 row(s) changed
```

`SELECT * FROM topics`

| id (INT) | posts (LONG) |
|---|---|
| 1 | 3 |

(1 row)

**Example: A variable that is not declared** (shows an error)

```sql
CREATE PROCEDURE p() AS BEGIN
  SET total = 1;
END;
CALL p();
```

Result:

```text
procedure 'p' created
```

Error: `procedure 'p', line 2: variable 'total' is not declared (DECLARE total <type> first)`

**Example: DECIMAL(2) does not round by itself** (shows an error)

```sql
CREATE PROCEDURE p() AS BEGIN
  DECLARE have DECIMAL(2) DEFAULT 1000;
  SET have = have + 0.105;
END;
CALL p();
```

Result:

```text
procedure 'p' created
```

Error: `procedure 'p', line 3: variable 'have' (DECIMAL(2)): 1000.105 has more than 2 decimal places`

**Example: A query that gives two rows** (shows an error)

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, balance DECIMAL(2));
INSERT INTO accounts VALUES (1, 1000), (2, 0);
CREATE PROCEDURE p() AS BEGIN
  DECLARE have DECIMAL(2);
  SET have = (SELECT balance FROM accounts);
END;
CALL p();
```

Result:

`CREATE TABLE accounts (`

```text
table 'accounts' created
```

`INSERT INTO accounts VALUES (1, 1000), (2, 0)`

```text
2 row(s) inserted
```

`CREATE PROCEDURE p() AS BEGIN`

```text
procedure 'p' created
```

Error: `procedure 'p', line 3 col 14: subquery returned 2 rows; a value needs exactly one (add LIMIT 1?)`

<a id="if"></a>

## IF, ELSIF, ELSEIF, ELSE

Syntax:

```sql
IF condition THEN
  statements;
[ELSIF condition THEN
  statements;] ...
[ELSE
  statements;]
END IF
```

Runs the statements of the **first** condition that is true. When no condition is true, it runs the `ELSE` part (if there is one).
`ELSEIF` is the same as `ELSIF`.

- **Notes:**
  - The condition must be `TRUE` or `FALSE`: `IF 1 THEN` is an error.
  - A `NULL` condition counts as **false**, like in `WHERE`.
  - `EXISTS (SELECT ...)` and `(SELECT ...) > 0` work as conditions.
  - End it with `END IF;` (not only `END;`).

**Example: NULL is not true: the ELSE part runs**

```sql
CREATE PROCEDURE p(x INT) AS BEGIN
  IF x > 0 THEN
    PRINT concat(x, ' is positive');
  ELSEIF x <= 0 THEN
    PRINT concat(x, ' is zero or negative');
  ELSE
    PRINT 'x is NULL: both conditions are not true';
  END IF;
END;
CALL p(5);
CALL p(-2);
CALL p(NULL);
```

Result:

`CREATE PROCEDURE p(x INT) AS BEGIN`

```text
procedure 'p' created
```

`CALL p(5)`

```text
procedure 'p' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| 5 is positive |

(1 row)

`CALL p(-2)`

```text
procedure 'p' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| -2 is zero or negative |

(1 row)

`CALL p(NULL)`

```text
procedure 'p' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| x is NULL: both conditions are not true |

(1 row)

**Example: A condition with EXISTS** (sample data: sample)

```sql
CREATE PROCEDURE has_trades(wanted SYMBOL, day DATE) AS BEGIN
  IF EXISTS (SELECT 1 FROM trade_log WHERE symbol = wanted AND date = day) THEN
    PRINT concat(wanted, ' traded on ', day);
  ELSE
    PRINT concat(wanted, ' did not trade on ', day);
  END IF;
END;
CALL has_trades('VOLT', '2026-09-10');
CALL has_trades('VOLT', '2026-09-09');
```

Result:

`CREATE PROCEDURE has_trades(wanted SYMBOL, day DATE) AS BEGIN`

```text
procedure 'has_trades' created
```

`CALL has_trades('VOLT', '2026-09-10')`

```text
procedure 'has_trades' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| VOLT traded on 2026-09-10 |

(1 row)

`CALL has_trades('VOLT', '2026-09-09')`

```text
procedure 'has_trades' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| VOLT did not trade on 2026-09-09 |

(1 row)

**Example: A number is not a condition** (shows an error)

```sql
CREATE PROCEDURE p() AS BEGIN
  IF 1 THEN
    PRINT 'yes';
  END IF;
END;
CALL p();
```

Result:

```text
procedure 'p' created
```

Error: `procedure 'p', line 2: the condition 1 must be TRUE or FALSE, but it is 1`

**Example: END without IF** (shows an error)

```sql
CREATE PROCEDURE p(x INT) AS BEGIN
  IF x > 0 THEN
    PRINT 'positive';
  END;
END;
```

Result:

Error: `line 4, column 6: expected IF after END to close the IF that starts at line 2 but found ';'`

<a id="while"></a>

## WHILE

Syntax:

```sql
WHILE condition DO
  statements;
END WHILE
```

Runs the statements again and again, as long as the condition is true. The condition is checked before each round.

- **Notes:**
  - A `NULL` condition counts as false: the loop stops.
  - A loop stops with an error after **10 million rounds**, so a loop that never ends cannot hold the database for ever. The whole `CALL` is then undone.
  - `RETURN` inside the loop stops the whole procedure.
  - To read rows one by one, a [`FOR`](procedure-language.md#for) loop is shorter.

**Example: Savings: how many years until 1 lakh becomes 2 lakh at 8%?**

```sql
CREATE PROCEDURE years_to_double(start DECIMAL(2), rate DOUBLE) AS BEGIN
  DECLARE money DECIMAL(2) DEFAULT start;
  DECLARE years INT DEFAULT 0;
  WHILE money < start * 2 DO
    SET money = round(money * (1 + rate), 2);
    SET years = years + 1;
  END WHILE;
  PRINT concat(years, ' years: ', money);
END;
CALL years_to_double(100000, 0.08);
```

Result:

`CREATE PROCEDURE years_to_double(start DECIMAL(2), rate DOUBLE) AS BEGIN`

```text
procedure 'years_to_double' created
```

`CALL years_to_double(100000, 0.08)`

```text
procedure 'years_to_double' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| 10 years: 215892.49 |

(1 row)

**Example: A loop that never ends is stopped** (shows an error)

```sql
CREATE PROCEDURE forever() AS BEGIN
  DECLARE i LONG DEFAULT 0;
  WHILE true DO
    SET i = i + 1;
  END WHILE;
END;
CALL forever();
```

Result:

```text
procedure 'forever' created
```

Error: `procedure 'forever', line 3: the WHILE loop ran 10000000 times and was stopped (does its condition ever become false?)`

<a id="for"></a>

## FOR

Syntax:

```sql
FOR row_name IN (SELECT ...) DO
  statements;   -- use row_name.column
END FOR
```

Runs the query once, then runs the statements once for every row. `row_name.column` is a value of the current row.

| Part | Meaning |
|---|---|
| `row_name` | a name for the current row, like `r` or `c` |
| `(SELECT ...)` | any query, in brackets. Give computed columns a name with `AS` (`sum(volume) AS volume`), so you can write `r.volume`. |

- **Notes:**
  - The query runs **once**, before the first round. Changes that the loop makes to the same table do not add rows to the loop.
  - A column that the row does not have is an error that lists the columns it has.
  - In a trigger, `FOR r IN (SELECT ... FROM NEW) DO` goes over the changed rows (see [NEW, OLD](triggers.md#new-old)).
  - FOR loops can be nested; use different row names.
  - `RETURN` inside the loop stops the whole procedure.

**Example: Market data: daily candles from the trade log** (sample data: sample)

```sql
CREATE PROCEDURE candles_from_trade_log(day DATE) AS BEGIN
  DECLARE made INT DEFAULT 0;
  FOR t IN (SELECT symbol, first(rate) AS open, max(rate) AS high, min(rate) AS low,
                   last(rate) AS close, sum(quantity) AS volume
            FROM trade_log WHERE date = day GROUP BY symbol) DO
    INSERT OR REPLACE INTO ochl_day VALUES (day, t.symbol, t.open, t.high, t.low, t.close, t.volume);
    SET made = made + 1;
  END FOR;
  PRINT concat(made, ' daily candles made for ', day);
END;

CALL candles_from_trade_log('2026-09-09');
SELECT time, symbol, open, high, low, close, volume FROM ochl_day
WHERE time IN '2026-09-09' AND symbol IN ('CITY', 'COAST', 'TELCO') ORDER BY symbol;
```

Result:

`CREATE PROCEDURE candles_from_trade_log(day DATE) AS BEGIN`

```text
procedure 'candles_from_trade_log' created
```

`CALL candles_from_trade_log('2026-09-09')`

```text
procedure 'candles_from_trade_log' done: 3 row(s) changed
```

`print`

| output (STRING) |
|---|
| 3 daily candles made for 2026-09-09 |

(1 row)

`SELECT time, symbol, open, high, low, close, volume FROM ochl_day WHERE time IN '2026-09-09' AND sym`

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 515 | 517 | 513 | 517 | 1510 |
| 2026-09-09T00:00:00.000Z | COAST | 401 | 401 | 398.5 | 398.5 | 220 |
| 2026-09-09T00:00:00.000Z | TELCO | 881 | 881 | 879 | 879 | 2000 |

(3 rows)

**Example: Month-end interest for every account, one row at a time**

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL DEFAULT 0);
CREATE TABLE interest_paid (account INT, amount DECIMAL(2), paid TIMESTAMP DEFAULT now());
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0), (3, 'Hari', 25000);

CREATE PROCEDURE pay_interest(yearly DOUBLE) AS BEGIN
  DECLARE interest DECIMAL(2);
  FOR a IN (SELECT id, balance FROM accounts WHERE balance > 0 ORDER BY id) DO
    SET interest = round(a.balance * yearly / 12, 2);
    UPDATE accounts SET balance = balance + interest WHERE id = a.id;
    INSERT INTO interest_paid (account, amount) VALUES (a.id, interest);
  END FOR;
END;

CALL pay_interest(0.06);
SELECT id, owner, balance FROM accounts ORDER BY id;
```

Result:

`CREATE TABLE accounts (`

```text
table 'accounts' created
```

`CREATE TABLE interest_paid (`

```text
table 'interest_paid' created
```

`INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0), (3, 'Hari', 25000)`

```text
3 row(s) inserted
```

`CREATE PROCEDURE pay_interest(yearly DOUBLE) AS BEGIN`

```text
procedure 'pay_interest' created
```

`CALL pay_interest(0.06)`

```text
procedure 'pay_interest' done: 4 row(s) changed
```

`SELECT id, owner, balance FROM accounts ORDER BY id`

| id (INT) | owner (STRING) | balance (DECIMAL(2)) |
|---|---|---|
| 1 | Ram | 1005.00 |
| 2 | Sita | 0.00 |
| 3 | Hari | 25125.00 |

(3 rows)

**Example: A column the row does not have** (shows an error)

```sql
CREATE PROCEDURE p() AS BEGIN
  FOR r IN (SELECT 'CITY' AS symbol, 514.5 AS ltp) DO
    PRINT r.price;
  END FOR;
END;
CALL p();
```

Result:

```text
procedure 'p' created
```

Error: `procedure 'p', line 3 col 11: row 'r' has no column 'price' (it has: symbol ltp)`

<a id="return"></a>

## RETURN

Syntax:

```sql
RETURN
```

Stops the procedure at once. The statements after it do not run.
The changes made **before** `RETURN` are kept (unlike `RAISE`).

- **Notes:** `RETURN` has no value: a procedure does not return a value. To give something back, use `SELECT` (an extra result) or `PRINT`. In a procedure called by another one, `RETURN` stops only the inner procedure.

**Example: Stop early when there is nothing to do**

```sql
CREATE TABLE orders (id INT PRIMARY KEY, status STRING);
INSERT INTO orders VALUES (1, 'open'), (2, 'done');

CREATE PROCEDURE close_open_orders() AS BEGIN
  IF NOT EXISTS (SELECT 1 FROM orders WHERE status = 'open') THEN
    PRINT 'no open orders';
    RETURN;
  END IF;
  UPDATE orders SET status = 'done' WHERE status = 'open';
  PRINT 'open orders closed';
END;

CALL close_open_orders();
CALL close_open_orders();
SELECT * FROM orders ORDER BY id;
```

Result:

`CREATE TABLE orders (`

```text
table 'orders' created
```

`INSERT INTO orders VALUES (1, 'open'), (2, 'done')`

```text
2 row(s) inserted
```

`CREATE PROCEDURE close_open_orders() AS BEGIN`

```text
procedure 'close_open_orders' created
```

`CALL close_open_orders()`

```text
procedure 'close_open_orders' done: 1 row(s) changed
```

`print`

| output (STRING) |
|---|
| open orders closed |

(1 row)

`CALL close_open_orders()`

```text
procedure 'close_open_orders' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| no open orders |

(1 row)

`SELECT * FROM orders ORDER BY id`

| id (INT) | status (STRING) |
|---|---|
| 1 | done |
| 2 | done |

(2 rows)

<a id="raise"></a>

## RAISE

Syntax:

```sql
RAISE expression
```

Stops with an error. The text of the error is the value of the expression.
**Everything the `CALL` changed is undone** (and the whole transaction, when the `CALL` runs inside `BEGIN ... COMMIT`).
In a `BEFORE` trigger, `RAISE` refuses the change.

- **Returns:** the error `procedure 'name', line N: <your text>` (or `trigger 'name', line N: ...`). `line N` is the line in the definition that [SHOW PROCEDURES](procedures.md#show-procedures) prints.
- **Notes:** the expression can be any value: `RAISE 'text'`, `RAISE concat('account ', id, ' is closed')`, even a number. The error's SQLSTATE is always `P0001` (you cannot choose another here), and there is no way to catch an error inside the procedure.

**Example: Accounting: never let a balance go below zero** (shows an error)

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL DEFAULT 0);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);

CREATE PROCEDURE withdraw(account INT, amt DECIMAL(2)) AS BEGIN
  UPDATE accounts SET balance = balance - amt WHERE id = account;
  IF (SELECT balance FROM accounts WHERE id = account) < 0 THEN
    RAISE concat('not enough money in account ', account, ' for ', amt);
  END IF;
END;

CALL withdraw(1, 400);
CALL withdraw(1, 700);
```

Result:

`CREATE TABLE accounts (`

```text
table 'accounts' created
```

`INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0)`

```text
2 row(s) inserted
```

`CREATE PROCEDURE withdraw(account INT, amt DECIMAL(2)) AS BEGIN`

```text
procedure 'withdraw' created
```

`CALL withdraw(1, 400)`

```text
procedure 'withdraw' done: 1 row(s) changed
```

Error: `procedure 'withdraw', line 4: not enough money in account 1 for 700.00`

The first `CALL` was saved. The second one took 700 first, then `RAISE` undid it. So Ram has 600:

**Command line: After the RAISE: only the first withdrawal is saved** (shows an error)

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL DEFAULT 0);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
CREATE PROCEDURE withdraw(account INT, amt DECIMAL(2)) AS BEGIN
  UPDATE accounts SET balance = balance - amt WHERE id = account;
  IF (SELECT balance FROM accounts WHERE id = account) < 0 THEN
    RAISE concat('not enough money in account ', account, ' for ', amt);
  END IF;
END;
```

```bash
kdb sql market "CALL withdraw(1, 400)"
kdb sql market "CALL withdraw(1, 700)"
kdb sql market "SELECT id, owner, balance FROM accounts ORDER BY id"
```

Output:

`> kdb sql market "CALL withdraw(1, 400)"`

```text
procedure 'withdraw' done: 1 row(s) changed
```

`> kdb sql market "CALL withdraw(1, 700)"`

```text
error: procedure 'withdraw', line 4: not enough money in account 1 for 700.00
```

exit code 1

`> kdb sql market "SELECT id, owner, balance FROM accounts ORDER BY id"`

```text
id | owner | balance
---+-------+--------
 1 | Ram   |  600.00
 2 | Sita  |    0.00
(2 rows, 0.3 ms)
```

<a id="print"></a>

## PRINT

Syntax:

```sql
PRINT expression
```

Adds one line to a result called `print` (one column, `output`). Use it for messages and for debugging.

- **Returns:** after the other results of the `CALL` (or of the statement that fired a trigger), a result `print` with all `PRINT` lines in order.
- **Notes:**
  - The value is written as text. `NULL` is written as `NULL`.
  - With `CALL ... WITH DEBUG`, the lines are in the `debug` result instead.
  - When the `CALL` fails, the lines from before the error are still returned.

**Example: Sign-up report for the app admin**

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, email STRING NOT NULL, created TIMESTAMP DEFAULT now());
INSERT INTO app_users (email) VALUES ('ram@example.com'), ('sita@example.com'), ('hari@example.com');

CREATE PROCEDURE signup_report() AS BEGIN
  PRINT concat('users: ', (SELECT count(*) FROM app_users));
  PRINT concat('newest: ', (SELECT email FROM app_users ORDER BY id DESC LIMIT 1));
  PRINT NULL;
  PRINT 3.5;
END;
CALL signup_report();
```

Result:

`CREATE TABLE app_users (`

```text
table 'app_users' created
```

`INSERT INTO app_users (email) VALUES ('ram@example.com'), ('sita@example.com'), ('hari@example.com')`

```text
3 row(s) inserted
```

`CREATE PROCEDURE signup_report() AS BEGIN`

```text
procedure 'signup_report' created
```

`CALL signup_report()`

```text
procedure 'signup_report' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| users: 3 |
| newest: hari@example.com |
| NULL |
| 3.5 |

(4 rows)

<a id="execute"></a>

## EXECUTE (dynamic SQL)

Syntax:

```sql
EXECUTE text;
EXECUTE text INTO variable, ...;
EXECUTE text INTO STRICT variable, ...;
EXECUTE text [INTO ...] USING value, ...;
```

Runs SQL that is made while the procedure runs. Use it when a table or column name comes from an argument. It works as in PostgreSQL PL/pgSQL.

| Part | What it does |
|---|---|
| `text` | any expression that gives the SQL text, for example [format](functions-text.md#format)`(...)` or `'...' \|\| name` |
| `USING a, b` | the values of `$1`, `$2`, ... in the text. They go in as **values**, never as SQL. |
| `INTO v, w` | puts the first row into the variables (one variable for each column). No row: the variables become `NULL`. |
| `INTO STRICT v` | the same, but exactly one row is needed; no row or more rows is an error |

- **Notes:**
  - Put values in with `USING`, or with `%L` of `format`. Put names in with `%I` of `format` or `quote_ident`. Then a quote in a value cannot change the statement.
  - The text may hold `SELECT`, `INSERT`, `UPDATE`, `DELETE` (with `RETURNING` for `INTO`), `CALL`, `EXPLAIN` or `SHOW`: what a body may hold. `CREATE`, `DROP`, `BEGIN` and `COMMIT` are refused.
  - The statement runs with the **rights of the user who called** the procedure, inside the same transaction. An error undoes the whole `CALL`.
  - `FOUND` is `TRUE` when the statement gave or changed at least one row.
  - A `SELECT` without `INTO` returns its rows as an extra result of the `CALL`.
  - Speed: a date in `USING` skips partitions like a date written in the SQL. `CALL ... WITH DEBUG` shows the text that ran and `partitions read`.
  - The text is parsed each time it runs. In a loop over many rows, a normal statement with variables is faster.
  - Locks: KDB locks the tables a `CALL` uses before it starts. Text written out in the body (`EXECUTE 'INSERT INTO t VALUES ($1)' USING x`) is known then, so only its tables are locked. Text made while the procedure runs (`format(...)`, `'...' || name`) could name any table, so such a `CALL` (or trigger) locks **every** table of the database while it runs, and writers of all other tables wait for it. See [one writer per table](transactions.md#one-writer).

**Example: One procedure for two tables: the table name is an argument**

```sql
CREATE TABLE daily_prices (symbol STRING, close DOUBLE);
CREATE TABLE weekly_prices (symbol STRING, close DOUBLE);
CREATE PROCEDURE add_price(tbl STRING, sym STRING, px DOUBLE) AS BEGIN
  EXECUTE format('INSERT INTO %I VALUES ($1, $2)', tbl) USING sym, px;
END;
CALL add_price('daily_prices', 'CITY', 512.5);
CALL add_price('weekly_prices', 'CITY', 509.0);
CALL add_price('daily_prices', 'it''s; DROP TABLE daily_prices', 1);
SELECT * FROM daily_prices;
```

Result:

`CREATE TABLE daily_prices (`

```text
table 'daily_prices' created
```

`CREATE TABLE weekly_prices (`

```text
table 'weekly_prices' created
```

`CREATE PROCEDURE add_price(tbl STRING, sym STRING, px DOUBLE) AS BEGIN`

```text
procedure 'add_price' created
```

`CALL add_price('daily_prices', 'CITY', 512.5)`

```text
procedure 'add_price' done: 1 row(s) changed
```

`CALL add_price('weekly_prices', 'CITY', 509.0)`

```text
procedure 'add_price' done: 1 row(s) changed
```

`CALL add_price('daily_prices', 'it''s; DROP TABLE daily_prices', 1)`

```text
procedure 'add_price' done: 1 row(s) changed
```

`SELECT * FROM daily_prices`

| symbol (STRING) | close (DOUBLE) |
|---|---|
| CITY | 512.5 |
| it's; DROP TABLE daily_prices | 1 |

(2 rows)

**Example: A count into a variable**

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, email STRING);
INSERT INTO app_users (email) VALUES ('ram@example.com'), ('sita@example.com');
CREATE PROCEDURE row_count(tbl STRING) AS BEGIN
  DECLARE n LONG;
  EXECUTE 'SELECT count(*) FROM ' || quote_ident(tbl) INTO n;
  PRINT concat(tbl, ': ', n, ' rows');
END;
CALL row_count('app_users');
```

Result:

`CREATE TABLE app_users (`

```text
table 'app_users' created
```

`INSERT INTO app_users (email) VALUES ('ram@example.com'), ('sita@example.com')`

```text
2 row(s) inserted
```

`CREATE PROCEDURE row_count(tbl STRING) AS BEGIN`

```text
procedure 'row_count' created
```

`CALL row_count('app_users')`

```text
procedure 'row_count' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| app_users: 2 rows |

(1 row)

**Example: INTO STRICT needs exactly one row** (shows an error)

```sql
CREATE TABLE app_users (id INT PRIMARY KEY, email STRING);
CREATE PROCEDURE email_of(user_id INT) AS BEGIN
  DECLARE e STRING;
  EXECUTE 'SELECT email FROM app_users WHERE id = $1' INTO STRICT e USING user_id;
END;
CALL email_of(7);
```

Result:

`CREATE TABLE app_users (`

```text
table 'app_users' created
```

`CREATE PROCEDURE email_of(user_id INT) AS BEGIN`

```text
procedure 'email_of' created
```

Error: `procedure 'email_of', line 3: EXECUTE ... INTO STRICT: the query gave no row`

**Example: Only the statements a body may hold** (shows an error)

```sql
CREATE PROCEDURE make_table(tbl STRING) AS BEGIN
  EXECUTE format('CREATE TABLE %I (a INT)', tbl);
END;
CALL make_table('t2');
```

Result:

```text
procedure 'make_table' created
```

Error: `procedure 'make_table', line 2: EXECUTE runs SELECT, INSERT, UPDATE, DELETE, CALL, EXPLAIN or SHOW, the statements a procedure body may hold; not CREATE TABLE t2 (   a INT )`

<a id="local-cursors"></a>

## Cursors in a body: DECLARE CURSOR, OPEN, FETCH INTO, CLOSE

Syntax:

```sql
DECLARE cursor_name CURSOR FOR SELECT ...;
OPEN cursor_name;
FETCH cursor_name INTO variable, variable, ...;
FETCH [NEXT] [FROM] cursor_name INTO variable, ...;
CLOSE cursor_name;
FOUND   -- TRUE when the last FETCH read a row
```

A cursor reads a query **one row at a time**.

| Statement | What it does |
|---|---|
| `DECLARE c CURSOR FOR SELECT ...` | names the query. It does not run yet. |
| `OPEN c` | runs the query and keeps its rows |
| `FETCH c INTO a, b` | puts the next row into the variables (one variable for each column) and sets `FOUND` |
| `CLOSE c` | forgets the rows. You can `OPEN` it again (the query runs again). |

- **Notes:**
  - `FOUND` is `TRUE` when `FETCH` read a row, and `FALSE` when there was no row left. When there is no row, the variables keep their old values.
  - `FETCH ... INTO` reads one row. `FETCH NEXT 5` and `FETCH ALL` are for [SQL cursors](cursors.md) outside a body.
  - `OPEN` of an open cursor, and `FETCH` of a cursor that is not open, are errors.
  - A cursor of a body belongs to that one `CALL`. It closes by itself when the procedure ends, and it does not count toward the 16 SQL cursors.
  - A `FOR` loop is shorter for one query. A cursor is useful when you read two queries side by side, or stop early.

**Example: The biggest trade of a day, with a cursor loop** (sample data: sample)

```sql
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

Result:

`CREATE PROCEDURE biggest_trade(day DATE) AS BEGIN`

```text
procedure 'biggest_trade' created
```

`CALL biggest_trade('2026-09-10')`

```text
procedure 'biggest_trade' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| biggest trade on 2026-09-10: 1000 shares of COAST |

(1 row)

**Example: FOUND after the last row**

```sql
CREATE PROCEDURE p() AS BEGIN
  DECLARE n INT;
  DECLARE c CURSOR FOR SELECT 7 AS x;
  OPEN c;
  FETCH c INTO n;
  PRINT concat('found=', found, ', n=', n);
  FETCH c INTO n;
  PRINT concat('found=', found, ', n=', n, ' (the old value)');
  CLOSE c;
END;
CALL p();
```

Result:

`CREATE PROCEDURE p() AS BEGIN`

```text
procedure 'p' created
```

`CALL p()`

```text
procedure 'p' done: 0 row(s) changed
```

`print`

| output (STRING) |
|---|
| found=true, n=7 |
| found=false, n=7 (the old value) |

(2 rows)

**Example: One variable for each column** (shows an error)

```sql
CREATE PROCEDURE p() AS BEGIN
  DECLARE sym SYMBOL;
  DECLARE c CURSOR FOR SELECT 'CITY' AS symbol, 514.5 AS ltp;
  OPEN c;
  FETCH c INTO sym;
END;
CALL p();
```

Result:

```text
procedure 'p' created
```

Error: `procedure 'p', line 5: FETCH c INTO needs 2 variable(s), one for each column of the cursor (symbol, ltp), got 1`

**Example: FETCH before OPEN** (shows an error)

```sql
CREATE PROCEDURE p() AS BEGIN
  DECLARE n INT;
  DECLARE c CURSOR FOR SELECT 1 AS x;
  FETCH c INTO n;
END;
CALL p();
```

Result:

```text
procedure 'p' created
```

Error: `procedure 'p', line 4: cursor 'c' is not open (OPEN c first)`

<a id="limits"></a>

## Limits of the procedure language

| Limit | Value |
|---|---|
| Procedures calling procedures (also itself) | 16 levels |
| Triggers firing triggers | 16 levels |
| Rounds of one `WHILE` loop | 10 million |
| Rows changed in one `CALL` (one transaction) | 10 million |
| Steps kept by `WITH DEBUG` | 100,000 |
| Text of one statement in a debug row | 200 characters |

- **Notes:** there is no `LOOP`, `CASE` statement (the `CASE` expression works), `EXCEPTION` block, `EXIT` or `CONTINUE`. Use `WHILE` with a variable, and `RETURN`.

**Example: A syntax error is found when you create the procedure** (shows an error)

```sql
CREATE PROCEDURE p(x INT) AS BEGIN
  WHILE x > 0
    SET x = x - 1;
  END WHILE;
END;
```

Result:

Error: `line 3, column 5: expected an operator (AND, OR, =, +, ...) or DO after the WHILE condition but found 'SET'`
