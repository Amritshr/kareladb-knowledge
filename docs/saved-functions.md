# Saved functions

> Save a formula with a name, and use it in any query like a built-in function.

- Category: Saved functions
- Keywords: function, user-defined function, UDF, formula, RETURNS, OR REPLACE, FUNCTIONS, CREATE OR REPLACE FUNCTION, calls itself, built-in function, nested too deeply
- See also: [Stored procedures](procedures.md), [The procedure language](procedure-language.md), [Views](views.md), [Math functions](functions-math.md), [13. Functions, procedures and triggers](../tutorial/13-functions-procedures-triggers.md)

A **saved function** is a formula with a name. Its body is **one expression** (one formula, like `(close - open) / open * 100`).
You write the formula once. Then every query can use it, like `round` or `concat`.

- KarelaDB keeps the function in the database. It is still there after a restart and in a backup.
- A call costs nothing extra: when the query starts, KarelaDB puts the body in the place of the call.
- Only **one expression**. For many steps, variables or loops, use a [stored procedure](procedures.md).

**Example: The change of each share today, in percent** (sample data: sample)

```sql
CREATE FUNCTION change_pct(price DOUBLE, prev DOUBLE) RETURNS DOUBLE
AS ((price - prev) / prev * 100);

SELECT symbol, open, close, round(change_pct(close, open), 2) AS change
FROM ochl_day
WHERE time IN '2026-09-10'
ORDER BY change DESC;
```

Result:

`CREATE FUNCTION change_pct(price DOUBLE, prev DOUBLE) RETURNS DOUBLE AS ((price - prev) / prev * 100`

```text
function 'change_pct' created
```

`SELECT symbol, open, close, round(change_pct(close, open), 2) AS change FROM ochl_day WHERE time IN `

| symbol (SYMBOL) | open (DOUBLE) | close (DOUBLE) | change (DOUBLE) |
|---|---|---|---|
| VOLT | 185.6 | 191.2 | 3.02 |
| CITY | 504.6 | 504.9 | 0.06 |
| COAST | 380.1 | 376.1 | -1.05 |

(3 rows)

<a id="create-function"></a>

## CREATE FUNCTION

Syntax:

```sql
CREATE [OR REPLACE] FUNCTION name(parameter TYPE, ...) [RETURNS TYPE] AS (expression)
CREATE [OR REPLACE] FUNCTION name() [RETURNS TYPE] AS (expression)
```

Saves a new function. `OR REPLACE` changes a function that already exists.

| Part | Meaning |
|---|---|
| `name` | the name of the function. Upper and lower case are the same (`Tax` and `tax` are one function). |
| `parameter TYPE` | an input value and its type (`INT`, `DOUBLE`, `DECIMAL(2)`, `STRING`, `TIMESTAMP`, ...). Write `()` for a function without inputs. |
| `RETURNS TYPE` | optional. The result is changed to this type (like `CAST`). Without it, the result keeps the type of the expression. |
| `AS (expression)` | the body: one expression in brackets. It can use the parameters, operators, `CASE`, built-in functions and other saved functions. |

- **Returns:** the message `function 'name' created` (or `replaced`).
- **Notes:**
  - Each argument is changed to the type of its parameter, like `CAST`. So `change_pct('5', '4')` works: the text becomes a `DOUBLE`.
  - `RETURNS DECIMAL(2)` fails when the value has more than 2 decimals, for example `112.9887`. Round first: `AS (round(amount * 0.13, 2))`.
  - Without `OR REPLACE`, a name that is already used gives an error.
  - KarelaDB checks the body when you create the function: unknown functions, wrong argument counts and a function that calls itself are refused at once. The [rules](saved-functions.md#rules) list everything a body cannot hold.
  - There are no default values for parameters, and no two functions with the same name and other parameters.

**Example: VAT of 13% on an amount of money, exact to the cent**

```sql
CREATE FUNCTION vat(amount DECIMAL(2)) RETURNS DECIMAL(2) AS (round(amount * 0.13, 2));

SELECT vat(1000) AS on_1000, vat(99.99) AS on_99_99, 99.99 + vat(99.99) AS total;
```

Result:

`CREATE FUNCTION vat(amount DECIMAL(2)) RETURNS DECIMAL(2) AS (round(amount * 0.13, 2))`

```text
function 'vat' created
```

`SELECT vat(1000) AS on_1000, vat(99.99) AS on_99_99, 99.99 + vat(99.99) AS total`

| on_1000 (DECIMAL(2)) | on_99_99 (DECIMAL(2)) | total (DECIMAL(2)) |
|---|---|---|
| 130.00 | 13.00 | 112.99 |

(1 row)

**Example: One function uses another: up, down or flat days** (sample data: sample)

```sql
CREATE FUNCTION change_pct(price DOUBLE, prev DOUBLE) RETURNS DOUBLE
AS ((price - prev) / prev * 100);

CREATE FUNCTION move(price DOUBLE, prev DOUBLE) RETURNS STRING
AS (CASE WHEN change_pct(price, prev) > 0.5 THEN 'up'
         WHEN change_pct(price, prev) < -0.5 THEN 'down'
         ELSE 'flat' END);

SELECT move(close, open) AS move, count(*) AS days
FROM ochl_day
WHERE symbol = 'CITY'
GROUP BY move(close, open)
ORDER BY move;
```

Result:

`CREATE FUNCTION change_pct(price DOUBLE, prev DOUBLE) RETURNS DOUBLE AS ((price - prev) / prev * 100`

```text
function 'change_pct' created
```

`CREATE FUNCTION move(price DOUBLE, prev DOUBLE) RETURNS STRING AS (CASE WHEN change_pct(price, prev)`

```text
function 'move' created
```

`SELECT move(close, open) AS move, count(*) AS days FROM ochl_day WHERE symbol = 'CITY' GROUP BY move`

| move (STRING) | days (LONG) |
|---|---|
| down | 4 |
| flat | 13 |
| up | 2 |

(3 rows)

**Example: Change a function with OR REPLACE**

```sql
CREATE FUNCTION fee(amount DOUBLE) RETURNS DOUBLE AS (amount * 0.004);
SELECT fee(100000) AS old_fee;

CREATE OR REPLACE FUNCTION fee(amount DOUBLE) RETURNS DOUBLE AS (greatest(amount * 0.0036, 10));
SELECT fee(100000) AS new_fee, fee(1000) AS small_trade;
```

Result:

`CREATE FUNCTION fee(amount DOUBLE) RETURNS DOUBLE AS (amount * 0.004)`

```text
function 'fee' created
```

`SELECT fee(100000) AS old_fee`

| old_fee (DOUBLE) |
|---|
| 400 |

(1 row)

`CREATE OR REPLACE FUNCTION fee(amount DOUBLE) RETURNS DOUBLE AS (greatest(amount * 0.0036, 10))`

```text
function 'fee' replaced
```

`SELECT fee(100000) AS new_fee, fee(1000) AS small_trade`

| new_fee (DOUBLE) | small_trade (DOUBLE) |
|---|---|
| 360 | 10 |

(1 row)

**Example: The name is already used** (shows an error)

```sql
CREATE FUNCTION fee(amount DOUBLE) AS (amount * 0.004);
CREATE FUNCTION fee(amount DOUBLE) AS (amount * 0.0036);
```

Result:

```text
function 'fee' created
```

Error: `function 'fee' already exists; use CREATE OR REPLACE FUNCTION to change it`

**Example: RETURNS DECIMAL(2) with too many decimals** (shows an error)

```sql
CREATE FUNCTION with_vat(amount DOUBLE) RETURNS DECIMAL(2) AS (amount * 1.13);
SELECT with_vat(99.99);
```

Result:

```text
function 'with_vat' created
```

Error: `line 2, column 8: cannot convert '112.98869999999998' to DECIMAL(2): 112.98869999999998 has more than 2 decimal places`

<a id="use"></a>

## Using a saved function

Syntax:

```sql
SELECT name(argument, ...) ... FROM ... WHERE name(...) ... GROUP BY name(...) ORDER BY name(...)
```

Call a saved function like a built-in one: its name and the arguments in brackets.
It works in `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY`, in [views](views.md), in [procedures](procedures.md) and in [triggers](triggers.md).

- **Returns:** the value of the body, for each row.
- **Notes:**
  - The number of arguments must match the parameters.
  - Aggregates go **around** the call: `sum(change_pct(close, open))` works. They cannot go inside the body.
  - A saved function **cannot** be used in a computed column (`AS (...)` in `CREATE TABLE`), and not with `DISTINCT` or `OVER`.
  - Views and procedures always use the newest body: after `CREATE OR REPLACE FUNCTION`, a view that uses it gives the new result.
  - The column name of an unnamed call is the call itself, like `change_pct(1, 2)`. Use `AS` to give it a better name.

**Example: Big trades only: a function in WHERE** (sample data: sample)

```sql
CREATE FUNCTION trade_value(quantity LONG, rate DOUBLE) RETURNS DOUBLE AS (quantity * rate);

SELECT transaction_id, symbol, quantity, rate, trade_value(quantity, rate) AS value
FROM trade_log
WHERE trade_value(quantity, rate) >= 250000
ORDER BY value DESC;
```

Result:

`CREATE FUNCTION trade_value(quantity LONG, rate DOUBLE) RETURNS DOUBLE AS (quantity * rate)`

```text
function 'trade_value' created
```

`SELECT transaction_id, symbol, quantity, rate, trade_value(quantity, rate) AS value FROM trade_log W`

| transaction_id (LONG) | symbol (SYMBOL) | quantity (LONG) | rate (DOUBLE) | value (DOUBLE) |
|---|---|---|---|---|
| 100001 | TELCO | 1000 | 881 | 881000 |
| 100007 | TELCO | 1000 | 879 | 879000 |
| 100017 | TELCO | 500 | 881 | 440500 |
| 100031 | COAST | 1000 | 402 | 402000 |
| 100015 | COAST | 1000 | 398 | 398000 |
| 100005 | CITY | 500 | 517 | 258500 |
| 100018 | CITY | 500 | 516 | 258000 |
| 100004 | CITY | 500 | 514.5 | 257250 |
| 100003 | CITY | 500 | 513 | 256500 |

(9 rows)

**Example: A view uses the newest body of the function**

```sql
CREATE FUNCTION fee(amount DOUBLE) RETURNS DOUBLE AS (amount * 0.004);
CREATE VIEW fee_on_lakh AS SELECT fee(100000) AS fee;
SELECT * FROM fee_on_lakh;

CREATE OR REPLACE FUNCTION fee(amount DOUBLE) RETURNS DOUBLE AS (amount * 0.0036);
SELECT * FROM fee_on_lakh;
```

Result:

`CREATE FUNCTION fee(amount DOUBLE) RETURNS DOUBLE AS (amount * 0.004)`

```text
function 'fee' created
```

`CREATE VIEW fee_on_lakh AS SELECT fee(100000) AS fee`

```text
view 'fee_on_lakh' created
```

`SELECT * FROM fee_on_lakh`

| fee (DOUBLE) |
|---|
| 400 |

(1 row)

`CREATE OR REPLACE FUNCTION fee(amount DOUBLE) RETURNS DOUBLE AS (amount * 0.0036)`

```text
function 'fee' replaced
```

`SELECT * FROM fee_on_lakh`

| fee (DOUBLE) |
|---|
| 360 |

(1 row)

**Example: Wrong number of arguments** (shows an error)

```sql
CREATE FUNCTION change_pct(price DOUBLE, prev DOUBLE) RETURNS DOUBLE AS ((price - prev) / prev * 100);
SELECT change_pct(110);
```

Result:

```text
function 'change_pct' created
```

Error: `line 2, column 8: function 'change_pct' takes 2 argument(s) (price DOUBLE, prev DOUBLE), got 1`

**Example: Not in a computed column** (shows an error)

```sql
CREATE FUNCTION trade_value(quantity LONG, rate DOUBLE) RETURNS DOUBLE AS (quantity * rate);
CREATE TABLE trades (quantity LONG, rate DOUBLE, value DOUBLE AS (trade_value(quantity, rate)));
```

Result:

```text
function 'trade_value' created
```

Error: `computed column 'value' cannot use the saved function 'trade_value'; computed columns can use built-in functions only`

<a id="rules"></a>

## Rules for the body

Syntax:

```sql
AS (expression using only the parameters)
```

The body is checked when you create the function. These things are refused:

| Not allowed | Why | What to do |
|---|---|---|
| a column of a table | the function does not know any table | give the column as an argument: `f(close)` |
| a subquery `(SELECT ...)`, `EXISTS`, `IN (SELECT ...)` | a function works on one row | use a [procedure](procedures.md) or a [view](views.md) |
| aggregates (`sum`, `avg`, ...) and window functions (`sma`, `lag`, ...) | they need many rows | call them around the function: `sum(f(x))` |
| `*` | | |
| the name of a built-in function (`round`, `pct_change`, ...) | the name is already taken | choose another name |
| calling itself (also through another function) | it would never end | |
| more than 16 levels of functions calling functions | | |

- **Notes:** `DROP FUNCTION` does not check who uses a function. A function, view or procedure that uses a dropped function fails when it runs, with `unknown function`.

**Example: A built-in name** (shows an error)

```sql
CREATE FUNCTION pct_change(price DOUBLE, prev DOUBLE) AS ((price - prev) / prev * 100);
```

Result:

Error: `'pct_change' is a built-in function; choose another name for the function`

**Example: A column that is not a parameter** (shows an error)

```sql
CREATE FUNCTION day_range(high DOUBLE) AS (high - low);
```

Result:

Error: `the body of function 'day_range' uses low, which is not one of its parameters (high DOUBLE); a function can only use its parameters`

**Example: An aggregate inside the body** (shows an error)

```sql
CREATE FUNCTION total(x DOUBLE) AS (sum(x));
```

Result:

Error: `the body of function 'total' cannot use 'sum': aggregate and window functions work on many rows (call them around the function instead)`

**Example: A subquery inside the body** (shows an error)

```sql
CREATE FUNCTION last_close(s STRING) AS ((SELECT last(close) FROM ochl_day WHERE symbol = s));
```

Result:

Error: `the body of function 'last_close' cannot use a subquery`

**Example: Two functions that call each other** (shows an error)

```sql
CREATE FUNCTION a(x DOUBLE) AS (x + 1);
CREATE FUNCTION b(x DOUBLE) AS (a(x) * 2);
CREATE OR REPLACE FUNCTION a(x DOUBLE) AS (b(x));
```

Result:

`CREATE FUNCTION a(x DOUBLE) AS (x + 1)`

```text
function 'a' created
```

`CREATE FUNCTION b(x DOUBLE) AS (a(x) * 2)`

```text
function 'b' created
```

Error: `in function 'a': in function 'b': function 'a' calls itself (a -> b -> a); a saved function cannot call itself`

<a id="drop-function"></a>

## DROP FUNCTION

Syntax:

```sql
DROP FUNCTION [IF EXISTS] name
```

Removes a saved function.

- **Returns:** `function 'name' dropped`. With `IF EXISTS`, a name that does not exist gives the message `function 'name' does not exist` and no error.
- **Notes:** KarelaDB does not check who uses the function. Other functions, views, procedures and triggers that use it fail later, when they run.

**Example**

```sql
CREATE FUNCTION fee(amount DOUBLE) RETURNS DOUBLE AS (amount * 0.004);
DROP FUNCTION fee;
DROP FUNCTION IF EXISTS fee;
```

Result:

`CREATE FUNCTION fee(amount DOUBLE) RETURNS DOUBLE AS (amount * 0.004)`

```text
function 'fee' created
```

`DROP FUNCTION fee`

```text
function 'fee' dropped
```

`DROP FUNCTION IF EXISTS fee`

```text
function 'fee' does not exist
```

**Example: A function that used the dropped one fails when it runs** (shows an error)

```sql
CREATE FUNCTION a(x DOUBLE) AS (x + 1);
CREATE FUNCTION b(x DOUBLE) AS (a(x) * 2);
DROP FUNCTION a;
SELECT b(1);
```

Result:

`CREATE FUNCTION a(x DOUBLE) AS (x + 1)`

```text
function 'a' created
```

`CREATE FUNCTION b(x DOUBLE) AS (a(x) * 2)`

```text
function 'b' created
```

`DROP FUNCTION a`

```text
function 'a' dropped
```

Error: `line 4, column 8: in function 'b': unknown function 'a'`

**Example: Without IF EXISTS, a missing name is an error** (shows an error)

```sql
DROP FUNCTION no_such_function;
```

Result:

Error: `function 'no_such_function' does not exist`

<a id="show-functions"></a>

## SHOW FUNCTIONS

Syntax:

```sql
SHOW FUNCTIONS
```

Lists the saved functions of the database, in name order.

| Column | Meaning |
|---|---|
| `name` | the function name |
| `arguments` | the parameters and their types |
| `returns` | the `RETURNS` type, or `NULL` when there is none |
| `definition` | the whole `CREATE FUNCTION` statement |

- **Notes:** built-in functions are not listed. The text table of `kareladb sql` cuts long text after 48 characters; use `--format csv` or `--format json` to see the whole definition.

**Example**

```sql
CREATE FUNCTION change_pct(price DOUBLE, prev DOUBLE) RETURNS DOUBLE AS ((price - prev) / prev * 100);
CREATE FUNCTION vat(amount DECIMAL(2)) RETURNS DECIMAL(2) AS (round(amount * 0.13, 2));
CREATE FUNCTION greeting(name STRING) AS (concat('Namaste, ', name));
SHOW FUNCTIONS;
```

Result:

`CREATE FUNCTION change_pct(price DOUBLE, prev DOUBLE) RETURNS DOUBLE AS ((price - prev) / prev * 100`

```text
function 'change_pct' created
```

`CREATE FUNCTION vat(amount DECIMAL(2)) RETURNS DECIMAL(2) AS (round(amount * 0.13, 2))`

```text
function 'vat' created
```

`CREATE FUNCTION greeting(name STRING) AS (concat('Namaste, ', name))`

```text
function 'greeting' created
```

`SHOW FUNCTIONS`

| name (STRING) | arguments (STRING) | returns (STRING) | definition (STRING) |
|---|---|---|---|
| change_pct | price DOUBLE, prev DOUBLE | DOUBLE | CREATE FUNCTION change_pct(price DOUBLE, prev DOUBLE) RETURNS DOUBLE AS ((price - prev) / prev * 100) |
| greeting | name STRING | NULL | CREATE FUNCTION greeting(name STRING) AS (concat('Namaste, ', name)) |
| vat | amount DECIMAL(2) | DECIMAL(2) | CREATE FUNCTION vat(amount DECIMAL(2)) RETURNS DECIMAL(2) AS (round(amount * 0.13, 2)) |

(3 rows)
