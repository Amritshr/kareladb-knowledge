# Conditional and NULL functions

> Choose a value with CASE, replace NULL with coalesce, and turn a value into NULL with nullif.

- Category: Functions — conditional and NULL
- Keywords: if, if then else, else, switch, decode, iif, ifnull, nvl, isnull, zeroifnull, default value, empty text, missing value, three-valued logic, unknown, NULL 
- See also: [WHERE](where.md), [Operators](operators.md), [Conversion functions](functions-conversion.md), [Aggregate functions (sum)](functions-aggregate.md#sum), [GROUP BY and HAVING](group-by.md)

These tools choose a value for each row.

- `CASE` is SQL's "if ... then ... else". It gives the value of the first condition that is true.
- `coalesce` gives the first value that is not `NULL`. Use it to show `0` or `'-'` instead of an empty cell.
- `nullif` does the opposite: it turns one value (like `0` or `''`) into `NULL`.

`NULL` means "no value" or "not known". The last entry, [NULL rules](functions-conditional.md#null-rules), lists how every part of KarelaDB treats it.

**Example: Label each CITY day as up, down or flat** (sample data: sample)

```sql
SELECT time, open, close,
       CASE WHEN close > open THEN 'up'
            WHEN close < open THEN 'down'
            ELSE 'flat' END AS direction
FROM ochl_day
WHERE symbol = 'CITY'
LIMIT 5;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | close (DOUBLE) | direction (STRING) |
|---|---|---|---|
| 2025-12-28T00:00:00.000Z | 540.3 | 542.2 | up |
| 2025-12-29T00:00:00.000Z | 540.6 | 539.7 | down |
| 2025-12-30T00:00:00.000Z | 538.5 | 539.3 | up |
| 2025-12-31T00:00:00.000Z | 540.4 | 542.4 | up |
| 2026-08-23T00:00:00.000Z | 505 | 507.9 | up |

(5 rows)

The examples below also use two small tables: `ledger` (an accounting book with money in `DECIMAL(2)`) and `app_users` (people who signed up in an app).

Setup used by the examples below:

```sql
CREATE TABLE ledger (
  id      INT PRIMARY KEY,
  day     DATE,
  account STRING,
  debit   DECIMAL(2),
  credit  DECIMAL(2),
  note    STRING
);
INSERT INTO ledger VALUES
  (1, '2026-08-05', 'Cash', 5000.00, NULL, 'Opening balance'),
  (2, '2026-08-20', 'Rent', 1200.50, NULL, NULL),
  (3, '2026-09-01', 'Cash', NULL, 750.25, 'Shop sale'),
  (4, '2026-09-03', 'Bank', 300.00, NULL, '');

CREATE TABLE app_users (
  id        INT PRIMARY KEY,
  name      STRING NOT NULL,
  phone     STRING,
  email     STRING,
  plan      STRING,
  signed_up TIMESTAMP
);
INSERT INTO app_users VALUES
  (1, 'Sita', '9841000001', 'sita@example.com', 'pro', '2026-09-08T10:00:00+05:45'),
  (2, 'Ram', NULL, 'ram@example.com', 'free', '2026-09-08T18:30:00+05:45'),
  (3, 'Hari', '9851000003', NULL, NULL, '2026-09-09T09:15:00+05:45'),
  (4, 'Gita', NULL, NULL, 'trial', '2026-09-10T12:00:00+05:45');
```

<a id="case"></a>

## CASE WHEN

Syntax:

```sql
CASE WHEN condition THEN result
     [WHEN condition THEN result ...]
     [ELSE other_result]
END
```

KarelaDB checks the conditions from top to bottom. The result of the **first** true condition is the answer. When no condition is true, the answer is the `ELSE` value, or `NULL` when there is no `ELSE`.

| Part | Type | Meaning |
|---|---|---|
| `condition` | true/false | a test like `close > open` or `plan IS NULL` |
| `result` | any | the value when this condition is true |
| `other_result` | any | the value when no condition is true (optional) |

- **Returns:** the value of the chosen branch.
- **NULL:** a condition that is `NULL` counts as not true, so KarelaDB goes on to the next `WHEN`. Without `ELSE`, no match gives `NULL`.
- **Notes:**
  - A condition must be true, false or `NULL`. `CASE WHEN 1 THEN ...` is an error (write `WHEN x = 1`).
  - Only the chosen branch is worked out. The other results are not computed.
  - You can use `CASE` everywhere a value can go: `SELECT`, `WHERE`, `ORDER BY`, `GROUP BY`, inside `sum(...)`, and inside another `CASE`.
  - KarelaDB does not make the branches one type. `CASE WHEN ... THEN 1 ELSE 'low' END` gives a number in some rows and text in others. Give every branch the same type.
  - `GROUP BY` cannot use the name after `AS`. Repeat the whole `CASE` in `GROUP BY` (see the example).

**Example: Live price moves in five groups** (sample data: sample)

```sql
SELECT symbol, ltp, pct_change,
       CASE WHEN pct_change >= 2  THEN 'strong up'
            WHEN pct_change > 0   THEN 'up'
            WHEN pct_change = 0   THEN 'flat'
            WHEN pct_change > -2  THEN 'down'
            ELSE 'strong down' END AS move
FROM live_data
LATEST ON timestamp PARTITION BY symbol;
```

Result:

| symbol (SYMBOL) | ltp (DOUBLE) | pct_change (DOUBLE) | move (STRING) |
|---|---|---|---|
| CITY | 527.1 | 2.71 | strong up |
| COAST | 401.9 | 0.7 | up |
| TELCO | 897.7 | 1.9 | up |
| VOLT | 184 | -0.86 | down |

(4 rows)

**Example: Count up days and down days per symbol (CASE inside sum)** (sample data: sample)

```sql
SELECT symbol,
       sum(CASE WHEN close > open THEN 1 ELSE 0 END) AS up_days,
       sum(CASE WHEN close < open THEN 1 ELSE 0 END) AS down_days,
       count(*) AS days
FROM ochl_day
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | up_days (LONG) | down_days (LONG) | days (LONG) |
|---|---|---|---|
| CITY | 12 | 7 | 19 |
| COAST | 8 | 11 | 19 |
| VOLT | 10 | 9 | 19 |

(3 rows)

**Example: Group rows by a CASE: repeat it in GROUP BY**

```sql
SELECT CASE WHEN phone IS NULL THEN 'no phone' ELSE 'has phone' END AS phone_status,
       count(*) AS users
FROM app_users
GROUP BY CASE WHEN phone IS NULL THEN 'no phone' ELSE 'has phone' END
ORDER BY phone_status;
```

Result:

| phone_status (STRING) | users (LONG) |
|---|---|
| has phone | 2 |
| no phone | 2 |

(2 rows)

**Example: Or group by the AS name, which is shorter**

```sql
SELECT CASE WHEN phone IS NULL THEN 'no phone' ELSE 'has phone' END AS phone_status,
       count(*) AS users
FROM app_users
GROUP BY phone_status
ORDER BY phone_status;
```

Result:

| phone_status (STRING) | users (LONG) |
|---|---|
| has phone | 2 |
| no phone | 2 |

(2 rows)

**Example: The condition must be true or false** (shows an error)

```sql
SELECT CASE WHEN 1 THEN 'yes' ELSE 'no' END;
```

Result:

Error: `line 1, column 18: a condition must be true or false, got '1'`

<a id="case-simple"></a>

## CASE value WHEN

Syntax:

```sql
CASE value
     WHEN match THEN result
     [WHEN match THEN result ...]
     [ELSE other_result]
END
```

The short form. KarelaDB compares `value` with each `match`, like `value = match`, and gives the result of the first one that is equal.

| Part | Type | Meaning |
|---|---|---|
| `value` | any | the value to look at, worked out once |
| `match` | any | a value to compare with |
| `result`, `other_result` | any | as in [CASE WHEN](functions-conditional.md#case) |

- **Returns:** the value of the chosen branch.
- **NULL:** `NULL` never matches, not even `WHEN NULL`. Use `CASE WHEN value IS NULL THEN ...` for that.
- **Notes:**
  - Numbers match numeric text: `CASE 5 WHEN '5' THEN ...` matches.
  - Values that cannot be compared (a number and `'abc'`) simply do not match. There is no error, unlike `=`.

**Example**

```sql
SELECT CASE 'COAST' WHEN 'CITY' THEN 1 WHEN 'COAST' THEN 2 ELSE 0 END AS a,
       CASE 5 WHEN '5' THEN 'text five matches' END AS b,
       CASE NULL WHEN NULL THEN 'matched' ELSE 'no match' END AS c;
```

Result:

| a (LONG) | b (STRING) | c (STRING) |
|---|---|---|
| 2 | text five matches | no match |

(1 row)

**Example: Sort sectors in your own order** (sample data: sample)

```sql
SELECT symbol, sector
FROM securities
ORDER BY CASE sector WHEN 'Banking' THEN 1
                     WHEN 'Energy' THEN 2
                     ELSE 3 END,
         symbol;
```

Result:

| symbol (SYMBOL) | sector (STRING) |
|---|---|
| CITY | Banking |
| COAST | Banking |
| VOLT | Energy |
| ACME | Investment |
| TELCO | Telecom |

(5 rows)

**Example: Plan names for an app report**

```sql
SELECT name,
       CASE plan WHEN 'pro' THEN 'Paid'
                 WHEN 'trial' THEN 'Trial (14 days)'
                 WHEN 'free' THEN 'Free'
                 ELSE 'Not chosen' END AS plan_name
FROM app_users
ORDER BY id;
```

Result:

| name (STRING) | plan_name (STRING) |
|---|---|
| Sita | Paid |
| Ram | Free |
| Hari | Not chosen |
| Gita | Trial (14 days) |

(4 rows)

**Example: END is missing** (shows an error)

```sql
SELECT CASE plan WHEN 'pro' THEN 'Paid' FROM app_users;
```

Result:

Error: `line 1, column 41: expected an operator (AND, OR, =, +, ...), WHEN, ELSE or END to close the CASE that starts at line 1, column 8 but found 'FROM'`

## coalesce

Syntax:

```sql
coalesce(value, value, ...)
```

Gives the first value that is not `NULL`. `coalesce(phone, 'no phone')` shows the phone, or `'no phone'` when there is none.

| Argument | Type | Meaning |
|---|---|---|
| `value` | any | 1 to 64 values, checked from left to right |

- **Returns:** the first value that is not `NULL`, with its own type.
- **NULL:** `NULL` only when every value is `NULL`.
- **Notes:**
  - KarelaDB stops at the first value that is not `NULL`. The values after it are not worked out.
  - The values keep their types. `coalesce(debit, 0)` gives a `DECIMAL(2)` in some rows and the whole number `0` in others. Then `sum` of it becomes a `DOUBLE`. For exact money write `coalesce(debit, 0::DECIMAL(2))`.
  - Other databases call this `ifnull`, `nvl` or `isnull`. KarelaDB has only `coalesce`.

**Example**

```sql
SELECT coalesce(NULL, 'n/a') AS a, coalesce(NULL, NULL, 3) AS b, coalesce(7, 8) AS c, coalesce(NULL, NULL) AS d;
```

Result:

| a (STRING) | b (LONG) | c (LONG) | d (STRING) |
|---|---|---|---|
| n/a | 3 | 7 | NULL |

(1 row)

**Example: Show something instead of an empty cell**

```sql
SELECT name,
       coalesce(phone, email, 'no contact') AS contact,
       coalesce(plan, 'free') AS plan
FROM app_users
ORDER BY id;
```

Result:

| name (STRING) | contact (STRING) | plan (STRING) |
|---|---|---|
| Sita | 9841000001 | pro |
| Ram | ram@example.com | free |
| Hari | 9851000003 | free |
| Gita | no contact | trial |

(4 rows)

**Example: Ledger totals per account: keep DECIMAL(2) exact**

```sql
SELECT account,
       sum(coalesce(debit, 0::DECIMAL(2)))  AS total_debit,
       sum(coalesce(credit, 0::DECIMAL(2))) AS total_credit,
       sum(coalesce(debit, 0)) AS mixed_types
FROM ledger
GROUP BY account
ORDER BY account;
```

Result:

| account (STRING) | total_debit (DECIMAL(2)) | total_credit (DECIMAL(2)) | mixed_types (DECIMAL(2)) |
|---|---|---|---|
| Bank | 300.00 | 0.00 | 300.00 |
| Cash | 5000.00 | 750.25 | 5000 |
| Rent | 1200.50 | 0.00 | 1200.50 |

(3 rows)

In the `Cash` row, `mixed_types` is `5000` (a `DOUBLE`), not `5000.00`: one row added the `DECIMAL(2)` value `5000.00` and the other row added the whole number `0`.

**Example: coalesce needs at least one value** (shows an error)

```sql
SELECT coalesce();
```

Result:

Error: `line 1, column 8: function 'coalesce' takes 1 to 64 argument(s), got 0`

## nullif

Syntax:

```sql
nullif(value, other)
```

Gives `NULL` when `value` equals `other`. Otherwise it gives `value`. It is a short way to write `CASE WHEN value = other THEN NULL ELSE value END`.

| Argument | Type | Meaning |
|---|---|---|
| `value` | any | the value to give back |
| `other` | any | when `value` equals this, the answer is `NULL` |

- **Returns:** `value` (with its type) or `NULL`.
- **NULL:** `nullif(NULL, x)` is `NULL`. `nullif(x, NULL)` is `x`.
- **Notes:**
  - Equal means the same as `=`: `nullif(5, 5.0)` and `nullif(5, '5')` are `NULL`. Text is compared exactly (`'a'` is not `'A'`).
  - Values that cannot be compared give back `value`, without an error.
  - Division by zero is an error, as in PostgreSQL, so `x / nullif(y, 0)` is the way to get `NULL` for it. `nullif` is also useful for `''` or a "no data" marker like `-1`.

**Example**

```sql
SELECT nullif(5, 5) AS a, nullif(10, 0) AS b, nullif(5, '5') AS c, nullif('a', 'A') AS d, nullif(NULL, 1) AS e;
```

Result:

| a (STRING) | b (LONG) | c (STRING) | d (STRING) | e (STRING) |
|---|---|---|---|---|
| NULL | 10 | NULL | a | NULL |

(1 row)

**Example: Empty notes count as no note**

```sql
SELECT id, note,
       nullif(note, '') AS clean_note,
       coalesce(nullif(note, ''), '(no note)') AS shown
FROM ledger
ORDER BY id;
```

Result:

| id (INT) | note (STRING) | clean_note (STRING) | shown (STRING) |
|---|---|---|---|
| 1 | Opening balance | Opening balance | Opening balance |
| 2 | NULL | NULL | (no note) |
| 3 | Shop sale | Shop sale | Shop sale |
| 4 |  | NULL | (no note) |

(4 rows)

**Example: Average only over rows that really have a value** (sample data: sample)

```sql
SELECT symbol,
       round(avg(quantity), 1) AS avg_all,
       round(avg(nullif(quantity, 1000)), 1) AS avg_without_1000_lots,
       count(nullif(quantity, 1000)) AS trades_not_1000
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | avg_all (DOUBLE) | avg_without_1000_lots (DOUBLE) | trades_not_1000 (LONG) |
|---|---|---|---|
| CITY | 220 | 220 | 11 |
| COAST | 279.1 | 118.9 | 9 |
| TELCO | 461.7 | 192.5 | 4 |
| VOLT | 100 | 100 | 4 |

(4 rows)

<a id="null-rules"></a>

## NULL rules

Syntax:

```sql
value IS NULL      value IS NOT NULL
coalesce(value, default)      nullif(value, other)
```

`NULL` means "no value". Almost everything that touches `NULL` gives `NULL`, because the answer is not known. Use [`IS NULL`](where.md) to test for it: `x = NULL` is never true.

| Where | What `NULL` does | Example | Result |
|---|---|---|---|
| `+ - * / %` | gives `NULL` | `NULL + 1` | `NULL` |
| `= <> < > <= >=` | gives `NULL` (not true, not false) | `NULL = NULL` | `NULL` |
| `IS NULL`, `IS NOT NULL` | the only safe test | `NULL IS NULL` | `true` |
| `AND` | `false` wins, else `NULL` | `FALSE AND NULL`, `TRUE AND NULL` | `false`, `NULL` |
| `OR` | `true` wins, else `NULL` | `TRUE OR NULL`, `FALSE OR NULL` | `true`, `NULL` |
| `NOT` | gives `NULL` | `NOT NULL` | `NULL` |
| `IN (...)` | `NULL` when nothing matched and the list has a `NULL` | `3 IN (1, NULL)` | `NULL` |
| `BETWEEN`, `LIKE` | gives `NULL` | `NULL LIKE 'a%'` | `NULL` |
| `WHERE`, `HAVING`, `CASE WHEN` | `NULL` counts as not true: the row is left out, the next `WHEN` is tried | | |
| `\|\|` | gives `NULL`; `concat` skips `NULL` instead | `'a' \|\| NULL` | `NULL` |
| most functions | `NULL` in, `NULL` out | `abs(NULL)` | `NULL` |
| `coalesce`, `greatest`, `least`, `concat`, `concat_ws` | skip `NULL` values | `coalesce(NULL, 2)` | `2` |
| aggregates (`sum`, `avg`, `min`, `count(x)`, ...) | ignore `NULL` rows; `count(*)` counts every row | | |
| `ORDER BY` | `NULL` counts as the biggest value: last with `ASC`, first with `DESC` (change with `NULLS FIRST` / `NULLS LAST`) | | |
| `CAST(NULL AS type)` | stays `NULL` | `NULL::INT` | `NULL` |

- **Notes:** `3 NOT IN (1, NULL)` is `NULL`, not `true`. A `NOT IN` list with a `NULL` in it never keeps a row. See also [aggregates](functions-aggregate.md#count-star).

**Example**

```sql
SELECT NULL + 1 AS plus, NULL = NULL AS equal, NULL IS NULL AS is_null,
       FALSE AND NULL AS and_false, TRUE OR NULL AS or_true,
       3 IN (1, NULL) AS in_list, 3 NOT IN (1, NULL) AS not_in_list, 'a' || NULL AS joined;
```

Result:

| plus (STRING) | equal (STRING) | is_null (BOOL) | and_false (BOOL) | or_true (BOOL) | in_list (STRING) | not_in_list (STRING) | joined (STRING) |
|---|---|---|---|---|---|---|---|
| NULL | NULL | true | false | true | NULL | NULL | NULL |

(1 row)

**Example: = NULL finds nothing; IS NULL finds the rows**

```sql
SELECT (SELECT count(*) FROM app_users WHERE phone = NULL) AS with_equals_null,
       (SELECT count(*) FROM app_users WHERE phone IS NULL) AS with_is_null;
```

Result:

| with_equals_null (LONG) | with_is_null (LONG) |
|---|---|
| 0 | 2 |

(1 row)

**Example: count(*) counts rows, count(x) skips NULL**

```sql
SELECT count(*) AS users, count(phone) AS with_phone, count(email) AS with_email, count(plan) AS with_plan
FROM app_users;
```

Result:

| users (LONG) | with_phone (LONG) | with_email (LONG) | with_plan (LONG) |
|---|---|---|---|
| 4 | 2 | 2 | 3 |

(1 row)
