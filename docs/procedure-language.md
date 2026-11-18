# The procedure language

> Variables, IF, WHILE, FOR, RETURN, RAISE, PRINT and cursors inside a procedure or trigger body; plpgsql functions with OUT parameters, RETURNS TABLE and RETURNS SETOF.

- Category: Stored procedures
- Keywords: OUT, INOUT, OUT parameters, RETURNS TABLE, RETURNS SETOF, SETOF, RETURN NEXT, RETURN QUERY, set-returning function, table function, LANGUAGE plpgsql, FOR i IN 1..10, WHILE LOOP, structure of query does not match, EXCEPTION, EXCEPTION WHEN, WHEN OTHERS, sqlstate, sqlerrm, unique\_violation, try catch, CASE statement, END CASE, LOOP, EXIT, CONTINUE, EXIT WHEN, break, variable, variables, loop, THEN, DO, IN, INTO, OPEN, FOUND, EXECUTE, dynamic SQL, EXECUTE format, USING, INTO STRICT, table name in a variable, sp\_executesql, PREPARE, END IF, END WHILE, END FOR, FETCH INTO, OPEN cursor, declared twice, column name wins, WHILE loop ran, body, procedure body, trigger body
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

<a id="case"></a>

## CASE (statement)

Syntax:

```sql
CASE value
  WHEN a [, b ...] THEN statements;
  ...
  [ELSE statements;]
END CASE

CASE
  WHEN condition THEN statements;
  ...
  [ELSE statements;]
END CASE
```

Runs the statements of the first `WHEN` that fits: the value is one of the listed ones, or (the second form) the condition is true. It is the same as an `IF ... ELSIF ...`.

- **Notes:** without `ELSE`, a value that no `WHEN` takes is an error (`case not found`), as in PostgreSQL, and the `CALL` is undone. Inside a `SELECT`, `CASE ... END` is the [expression](functions-conditional.md#case).

**Example: Sort orders by size**

Setup:

```sql
CREATE TABLE order_size (id LONG, size STRING);
CREATE PROCEDURE note_size(id LONG, qty LONG) AS BEGIN
  CASE
    WHEN qty >= 1000 THEN INSERT INTO order_size VALUES (id, 'large');
    WHEN qty >= 100 THEN INSERT INTO order_size VALUES (id, 'medium');
    ELSE INSERT INTO order_size VALUES (id, 'small');
  END CASE;
END;
```

```sql
CALL note_size(1, 5000);
CALL note_size(2, 150);
CALL note_size(3, 10);
SELECT * FROM order_size ORDER BY id;
```

Result:

`CALL note_size(1, 5000)`

```text
procedure 'note_size' done: 1 row(s) changed
```

`CALL note_size(2, 150)`

```text
procedure 'note_size' done: 1 row(s) changed
```

`CALL note_size(3, 10)`

```text
procedure 'note_size' done: 1 row(s) changed
```

`SELECT * FROM order_size ORDER BY id`

| id (LONG) | size (STRING) |
|---|---|
| 1 | large |
| 2 | medium |
| 3 | small |

(3 rows)

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
  - **Speed:** a statement in a loop is bound once and its variables are filled in on each round. A key written as an expression of a variable (`WHERE id = 2 * i + 1`) is worked out when the statement is bound, so that statement is bound again on every round; put the value in a variable first (`SET k = 2 * i + 1;` then `WHERE id = k`) to keep the fast form.

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

<a id="loop"></a>

## LOOP, EXIT, CONTINUE

Syntax:

```sql
LOOP
  statements;
END LOOP
EXIT [WHEN condition];
CONTINUE [WHEN condition];
```

`LOOP` runs its statements again and again until an `EXIT`. `EXIT` leaves the innermost `LOOP`, `WHILE` or `FOR` at once; `CONTINUE` skips the rest of this round and starts the next one (a `FOR` takes its next row). With `WHEN`, only when the condition is true.

- **Notes:**
  - `EXIT` and `CONTINUE` work from inside an `IF` too. Outside a loop they are an error when the procedure is made.
  - A `LOOP` that never reaches `EXIT` stops with an error after **10 million rounds**, as `WHILE` does; the `CALL` is undone.
  - `RETURN` inside a loop stops the whole procedure.

**Example: Odd numbers up to 7, skipping the even ones**

Setup:

```sql
CREATE TABLE odd_numbers (n LONG);
CREATE PROCEDURE fill_odd() AS BEGIN
  DECLARE i LONG DEFAULT 0;
  LOOP
    SET i = i + 1;
    CONTINUE WHEN i % 2 = 0;
    INSERT INTO odd_numbers VALUES (i);
    EXIT WHEN i >= 7;
  END LOOP;
END;
```

```sql
CALL fill_odd();
SELECT n FROM odd_numbers ORDER BY n;
```

Result:

`CALL fill_odd()`

```text
procedure 'fill_odd' done: 4 row(s) changed
```

`SELECT n FROM odd_numbers ORDER BY n`

| n (LONG) |
|---|
| 1 |
| 3 |
| 5 |
| 7 |

(4 rows)

**Example: Stop a FOR loop at the first big order**

Setup:

```sql
CREATE TABLE orders_in (id LONG, qty LONG);
CREATE TABLE first_orders (id LONG, qty LONG);
INSERT INTO orders_in VALUES (1, 50), (2, 200), (3, 5000), (4, 10);
CREATE PROCEDURE until_big() AS BEGIN
  FOR r IN (SELECT id, qty FROM orders_in ORDER BY id) DO
    IF r.qty >= 1000 THEN
      EXIT;
    END IF;
    INSERT INTO first_orders VALUES (r.id, r.qty);
  END FOR;
END;
```

```sql
CALL until_big();
SELECT id, qty FROM first_orders ORDER BY id;
```

Result:

`CALL until_big()`

```text
procedure 'until_big' done: 2 row(s) changed
```

`SELECT id, qty FROM first_orders ORDER BY id`

| id (LONG) | qty (LONG) |
|---|---|
| 1 | 50 |
| 2 | 200 |

(2 rows)

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

<a id="exception"></a>

## BEGIN ... EXCEPTION WHEN ... END

Syntax:

```sql
BEGIN
  statements;
EXCEPTION
  WHEN condition [OR condition ...] THEN
    statements;
  [WHEN ... THEN statements; ...]
END;
```

A block inside a body. When one of its statements fails with an error a `WHEN` names, the block's own changes are undone, the statements of that `WHEN` run, and the procedure goes on after `END`. Without `EXCEPTION`, `BEGIN ... END` just groups statements.

| Condition | Takes |
|---|---|
| `unique_violation`, `foreign_key_violation`, `not_null_violation`, `check_violation`, `division_by_zero`, `raise_exception`, ... | that error (PostgreSQL's condition names) |
| `data_exception`, `integrity_constraint_violation`, ... | every error of that class |
| `SQLSTATE '23505'` | the error with that code |
| `OTHERS` | any error |

- **Notes:**
  - In the handler, `sqlstate` is the error's code and `sqlerrm` its message.
  - An error no `WHEN` names ends the `CALL`, which is undone, as without the block.
  - Never taken, also not by `OTHERS`: a statement timeout or cancel, and a lock error (a deadlock, a lock wait that timed out). These end the `CALL`.
  - The block works inside `BEGIN ... COMMIT` too, beside the transaction's own `SAVEPOINT`s. Variables keep the values they got in the block.

**Example: Add a user; a taken email is noted, not an error**

Setup:

```sql
CREATE TABLE app_users (id LONG PRIMARY KEY, email STRING UNIQUE);
CREATE TABLE signup_log (email STRING, result STRING);
CREATE PROCEDURE sign_up(uid LONG, mail STRING) AS BEGIN
  BEGIN
    INSERT INTO app_users VALUES (uid, mail);
    INSERT INTO signup_log VALUES (mail, 'ok');
  EXCEPTION
    WHEN unique_violation THEN
      INSERT INTO signup_log VALUES (mail, concat('taken (', sqlstate, ')'));
  END;
END;
```

```sql
CALL sign_up(1, 'ram@example.com');
CALL sign_up(2, 'ram@example.com');
SELECT * FROM signup_log;
SELECT count(*) AS users FROM app_users;
```

Result:

`CALL sign_up(1, 'ram@example.com')`

```text
procedure 'sign_up' done: 2 row(s) changed
```

`CALL sign_up(2, 'ram@example.com')`

```text
procedure 'sign_up' done: 1 row(s) changed
```

`SELECT * FROM signup_log`

| email (STRING) | result (STRING) |
|---|---|
| ram@example.com | ok |
| ram@example.com | taken (23505) |

(2 rows)

`SELECT count(*) AS users FROM app_users`

| users (LONG) |
|---|
| 1 |

(1 row)

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
kareladb sql market "CALL withdraw(1, 400)"
kareladb sql market "CALL withdraw(1, 700)"
kareladb sql market "SELECT id, owner, balance FROM accounts ORDER BY id"
```

Output:

`> kareladb sql market "CALL withdraw(1, 400)"`

```text
procedure 'withdraw' done: 1 row(s) changed
```

`> kareladb sql market "CALL withdraw(1, 700)"`

```text
error: procedure 'withdraw', line 4: not enough money in account 1 for 700.00
```

exit code 1

`> kareladb sql market "SELECT id, owner, balance FROM accounts ORDER BY id"`

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
  - Locks: KarelaDB locks the tables a `CALL` uses before it starts. Text written out in the body (`EXECUTE 'INSERT INTO t VALUES ($1)' USING x`) is known then, so only its tables are locked. Text made while the procedure runs (`format(...)`, `'...' || name`) could name any table, so such a `CALL` (or trigger) locks **every** table of the database while it runs, and writers of all other tables wait for it. See [one writer per table](transactions.md#one-writer).

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

Error: `procedure 'make_table', line 2: EXECUTE runs SELECT, INSERT, UPDATE, DELETE, MERGE, CALL, EXPLAIN or SHOW, the statements a procedure body may hold; not CREATE TABLE t2 (   a INT )`

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

<a id="plpgsql-functions"></a>

## plpgsql functions: OUT parameters, RETURNS TABLE, RETURNS SETOF

Syntax:

```sql
CREATE [OR REPLACE] FUNCTION name([IN | OUT | INOUT] param TYPE, ...) [RETURNS record] AS $$
  [DECLARE name TYPE [:= value]; ...]
  BEGIN statements END
$$ LANGUAGE plpgsql
CREATE [OR REPLACE] FUNCTION name(param TYPE, ...) RETURNS TABLE (column TYPE, ...) AS $$ ... $$ LANGUAGE plpgsql
CREATE [OR REPLACE] FUNCTION name(param TYPE, ...) RETURNS SETOF type | SETOF table | SETOF record AS $$ ... $$ LANGUAGE plpgsql
```

PostgreSQL's plpgsql functions that a **query** calls, written as in PostgreSQL. An app's functions work unchanged.

| The function | It gives | Call it |
|---|---|---|
| `OUT` / `INOUT` parameters | one row: the `OUT` values at the end | `SELECT * FROM f(1)` gives the columns; `SELECT f(1)` gives the value (one `OUT`) or the row as text, like `(4,0.15)` |
| `RETURNS TABLE (a INT, b TEXT)` | a row for each `RETURN NEXT` (the columns' values now), and the rows of each `RETURN QUERY` | `SELECT * FROM f(3)`, in a join, a subquery, `WITH` or `LATERAL` |
| `RETURNS SETOF INT` | a row for each `RETURN NEXT value`, and the rows of `RETURN QUERY` | the same; the column is named after the function, or after the alias (`AS x`) |
| `RETURNS SETOF trades` | rows with the table's columns: `RETURN QUERY SELECT * FROM trades ...`, or `RETURN NEXT r` for a `FOR` row | the same |
| `RETURNS SETOF record` and `OUT` parameters | a row of the `OUT` values for each `RETURN NEXT` | the same |

The body is plpgsql:

| Statement | What it does |
|---|---|
| `name := value;` | gives a variable, a parameter or a `TABLE` column a value (`=` works too) |
| `IF`, `CASE`, `LOOP`, `EXIT`, `CONTINUE`, `BEGIN ... EXCEPTION ... END` | as in a procedure ([IF](procedure-language.md#if), [LOOP](procedure-language.md#loop), [EXCEPTION](procedure-language.md#exception)) |
| `WHILE cond LOOP ... END LOOP;` | repeats while `cond` is true |
| `FOR i IN [REVERSE] 1..n [BY 2] LOOP ... END LOOP;` | counts; `i` is an `INT` variable. The ends are worked out once |
| `FOR r IN SELECT ... LOOP ... END LOOP;` | runs once for every row; read a column as `r.column` |
| `RETURN NEXT [value];` | adds a row |
| `RETURN QUERY SELECT ...;` | adds the rows of the query |
| `RETURN;` | ends the function |
| `RAISE EXCEPTION 'text %', value;` | stops the query with that text; each `%` takes the next value (`%%` is `%`). `RAISE NOTICE` does nothing: a query has no place to show it |
| `NULL;` | does nothing |

- **Notes:**
  - The function runs **once per call**, when the query starts. So its arguments must be known then: values, `$1` parameters, a procedure's variables, or a subquery that stands alone. For a column of another table, write `LATERAL (SELECT * FROM f(t.col)) AS x`: it runs once for each value.
  - The body **only reads**. `INSERT`, `UPDATE`, `DELETE`, `CALL` and `EXECUTE` are refused when you create the function. A `SELECT` must say where its rows go: `RETURN QUERY SELECT ...`, `x := (SELECT ...)` or a `FOR` loop. To change data, write a [procedure](procedures.md).
  - A column name wins over a variable with the same name. In `RETURN QUERY SELECT ...`, write `t.symbol` when the function has a column `symbol` too.
  - `RETURN QUERY` must give as many columns as the function returns, or the call fails: `structure of query does not match function result type`.
  - Every parameter needs a name (`f(qty INT)`, not `f(INT)`). `DEFAULT` values, `VARIADIC`, `%TYPE`, cursors and `RAISE ... USING ERRCODE` are refused.
  - A plpgsql function **without** `OUT` parameters that returns one plain value (`RETURNS INT ... RETURN n`) is only recorded, with a warning. For a formula, use a [saved function](saved-functions.md).
  - Calls nest at most 16 levels deep (also into itself). One call gives at most 10 million rows. Its rows are kept in memory until the query has read them, so they count against the statement's memory like other kept rows (`max_result_memory`, and a quarter of `--memory-limit`): a call that needs more stops with the usual memory error (`the query keeps too many rows in memory`, SQLSTATE `54000`, or `memory full`, `53200`).
  - In a procedure, a value such as `IF f() > 25 THEN` is worked out again on every `CALL` and every pass of a loop: the function's tables may have changed.
  - A function that `RETURNS SETOF t` uses table `t`: `DROP TABLE t` is refused while it exists, and `DROP TABLE t CASCADE` drops the function too, as in PostgreSQL ([DROP TABLE](alter-table.md#drop-table)).
  - What the body reads is checked against the rights of the user who creates the function, as for a procedure.

**Example: OUT parameters: the fees of a trade as one row, or as a record**

```sql
CREATE FUNCTION split_fee(amount DOUBLE, OUT broker DOUBLE, OUT sebon DOUBLE) AS $$
BEGIN
  broker := amount * 0.004;
  sebon := amount * 0.00015;
END $$ LANGUAGE plpgsql;

SELECT * FROM split_fee(1000);
SELECT split_fee(1000) AS fees;
```

Result:

`CREATE FUNCTION split_fee(amount DOUBLE, OUT broker DOUBLE, OUT sebon DOUBLE) AS $$`

```text
function 'split_fee' created (plpgsql: its OUT parameters are one row, SELECT * FROM split_fee(...) or SELECT split_fee(...))
```

`SELECT * FROM split_fee(1000)`

| broker (DOUBLE) | sebon (DOUBLE) |
|---|---|
| 4 | 0.15 |

(1 row)

`SELECT split_fee(1000) AS fees`

| fees (STRING) |
|---|
| (4,0.15) |

(1 row)

**Example: RETURNS TABLE with RETURN QUERY, used like a table**

```sql
CREATE TABLE trades (id INT PRIMARY KEY, symbol STRING, qty INT, price DOUBLE);
INSERT INTO trades VALUES (1, 'NABIL', 10, 500), (2, 'NABIL', 5, 510), (3, 'CITY', 20, 300), (4, 'CITY', 1, 305);

CREATE FUNCTION turnover(min_qty INT) RETURNS TABLE (symbol TEXT, amount DOUBLE) AS $$
BEGIN
  RETURN QUERY SELECT t.symbol, sum(t.qty * t.price) FROM trades t
    WHERE t.qty >= min_qty GROUP BY t.symbol ORDER BY t.symbol;
END $$ LANGUAGE plpgsql;

SELECT * FROM turnover(5);
SELECT x.symbol, x.amount, count(*) AS big_trades
FROM turnover(5) x JOIN trades t ON t.symbol = x.symbol AND t.qty >= 5
GROUP BY x.symbol, x.amount ORDER BY x.symbol;
```

Result:

`CREATE TABLE trades (`

```text
table 'trades' created
```

`INSERT INTO trades VALUES (1, 'NABIL', 10, 500), (2, 'NABIL', 5, 510), (3, 'CITY', 20, 300), (4, 'CI`

```text
4 row(s) inserted
```

`CREATE FUNCTION turnover(min_qty INT) RETURNS TABLE (symbol STRING, amount DOUBLE) AS $$`

```text
function 'turnover' created (plpgsql: it returns rows, SELECT * FROM turnover(...))
```

`SELECT * FROM turnover(5)`

| symbol (STRING) | amount (DOUBLE) |
|---|---|
| CITY | 6000 |
| NABIL | 7550 |

(2 rows)

`SELECT x.symbol, x.amount, count(*) AS big_trades FROM turnover(5) AS x JOIN trades AS t ON t.symbol`

| symbol (STRING) | amount (DOUBLE) | big_trades (LONG) |
|---|---|---|
| CITY | 6000 | 1 |
| NABIL | 7550 | 2 |

(2 rows)

**Example: RETURNS SETOF INT with WHILE and RETURN NEXT: a big order in lots**

```sql
CREATE FUNCTION lots(total INT, lot INT) RETURNS SETOF INT AS $$
DECLARE left_over INT := total;
BEGIN
  WHILE left_over > 0 LOOP
    RETURN NEXT least(lot, left_over);
    left_over := left_over - lot;
  END LOOP;
END $$ LANGUAGE plpgsql;

SELECT * FROM lots(250, 100);
SELECT * FROM lots(250, 100) AS qty;
```

Result:

`CREATE FUNCTION lots(total INT, lot INT) RETURNS SETOF INT AS $$`

```text
function 'lots' created (plpgsql: it returns rows, SELECT * FROM lots(...))
```

`SELECT * FROM lots(250, 100)`

| lots (INT) |
|---|
| 100 |
| 100 |
| 50 |

(3 rows)

`SELECT * FROM lots(250, 100) AS qty`

| qty (INT) |
|---|
| 100 |
| 100 |
| 50 |

(3 rows)

**Example: A counting FOR, and the function once for each row with LATERAL**

```sql
CREATE FUNCTION squares(n INT) RETURNS TABLE (i INT, sq INT) AS $$
BEGIN
  FOR k IN 1..n LOOP
    i := k;
    sq := k * k;
    RETURN NEXT;
  END LOOP;
END $$ LANGUAGE plpgsql;

SELECT * FROM squares(3);
SELECT v.n, s.sq FROM (VALUES (1), (2)) v(n), LATERAL (SELECT * FROM squares(v.n)) s ORDER BY v.n, s.sq;
```

Result:

`CREATE FUNCTION squares(n INT) RETURNS TABLE (i INT, sq INT) AS $$`

```text
function 'squares' created (plpgsql: it returns rows, SELECT * FROM squares(...))
```

`SELECT * FROM squares(3)`

| i (INT) | sq (INT) |
|---|---|
| 1 | 1 |
| 2 | 4 |
| 3 | 9 |

(3 rows)

`SELECT v.n, s.sq FROM (VALUES (1), (2)) AS v(n) CROSS JOIN LATERAL (SELECT * FROM squares(v.n)) AS s`

| n (LONG) | sq (INT) |
|---|---|
| 1 | 1 |
| 2 | 1 |
| 2 | 4 |

(3 rows)

**Example: A function that changes data is refused** (shows an error)

```sql
CREATE TABLE notes (txt STRING);
CREATE FUNCTION add_note(t TEXT) RETURNS SETOF TEXT AS $$
BEGIN
  INSERT INTO notes VALUES (t);
  RETURN NEXT t;
END $$ LANGUAGE plpgsql;
```

Result:

Error: `line 2, column 56: in the body of plpgsql function 'add_note' (CREATE at line 2; positions below count from the opening $$): line 3, column 3: INSERT in a plpgsql function is not supported by KarelaDB: a function a query calls only reads (write a procedure, CREATE PROCEDURE ... AS BEGIN ... END, to change data)`

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
| plpgsql functions calling functions (also itself) | 16 levels |
| Rows one plpgsql function call gives | 10 million, within the statement's memory (`max_result_memory`) |

- **Notes:** a procedure has no `OUT` parameters: give results back with `SELECT` (an extra result) or `PRINT`. A function that gives rows is a [plpgsql function](procedure-language.md#plpgsql-functions).

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
