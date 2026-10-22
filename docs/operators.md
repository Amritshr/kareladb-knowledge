# Operators

> Every operator of KDB SQL, which one is done first, and what NULL does to each of them.

- Category: Querying
- Keywords: operator, precedence, order of operations, parentheses, +, -, \*, /, %, ||, concat, join text, -\>, -\>\>, ::, cast, , !, \<\>, NULL rules, three-valued logic, unary minus, precedence, ||, ::, -\>, -\>\>, int\_division, integer division, integer division, int\_division, 7 / 2
- See also: [WHERE](where.md), [Math functions (operators)](functions-math.md#operators), [Conversion functions](functions-conversion.md), [JSON functions](functions-json.md), [Conditional and NULL functions](functions-conditional.md), [Text functions](functions-text.md)

An **operator** is a sign or a word between values, like `+`, `=`, `AND` or `||`.
When an expression has many operators, KDB does the tight ones first: `2 + 3 * 4` is `14`, because `*` binds tighter than `+`.
Use `( )` to choose the order yourself, and to make long conditions easy to read.

**Example: A trade log report line: value, commission and a flag** (sample data: sample)

```sql
SELECT transaction_id, symbol,
       quantity * rate AS value,
       round(quantity * rate * 0.4 / 100, 2) AS commission,
       quantity >= 500 AND rate > 500 AS big_bank_trade
FROM trade_log
WHERE date IN '2026-09-10' AND symbol IN ('CITY', 'COAST')
ORDER BY value DESC
LIMIT 4;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | value (DOUBLE) | commission (DOUBLE) | big_bank_trade (BOOL) |
|---|---|---|---|---|
| 100031 | COAST | 402000 | 1608 | false |
| 100015 | COAST | 398000 | 1592 | false |
| 100018 | CITY | 258000 | 1032 | true |
| 100023 | COAST | 199500 | 798 | false |

(4 rows)

<a id="precedence"></a>

## Operator precedence

Syntax:

```sql
OR
AND
NOT
=  ==  !=  <>  <  <=  >  >=   IS [NOT] NULL   [NOT] IN   [NOT] BETWEEN   [NOT] LIKE   [NOT] ILIKE
+  -  ||
*  /  %
-value
::  ->  ->>
```

From loose (done **last**) to tight (done **first**):

| Level | Operators | Example | Means |
|---|---|---|---|
| 1 | `OR` | `a OR b AND c` | `a OR (b AND c)` |
| 2 | `AND` | `a AND b OR c` | `(a AND b) OR c` |
| 3 | `NOT` | `NOT a = b` | `NOT (a = b)` |
| 4 | `=` `==` `!=` `<>` `<` `<=` `>` `>=`, `IS [NOT] NULL`, `[NOT] IN`, `[NOT] BETWEEN`, `[NOT] LIKE`, `[NOT] ILIKE` | `a + 1 = b * 2` | `(a + 1) = (b * 2)` |
| 5 | `+` `-` `\|\|` | `'x' \|\| 1 + 2` | `('x' \|\| 1) + 2` (an error: write `'x' \|\| (1 + 2)`) |
| 6 | `*` `/` `%` | `2 + 3 * 4` | `2 + (3 * 4)` |
| 7 | `-` before a value | `-2 * 3` | `(-2) * 3` |
| 8 | `::` `->` `->>`, then values, columns, function calls, `CASE`, `CAST`, `( )` | `'5'::INT * 2` | `('5'::INT) * 2` |

- **Notes:** operators of the same level are done from left to right: `10 - 4 - 3` is `3`, and `a = b IS NULL` means `(a = b) IS NULL`.
- `a = b = c` is an error when `c` is not true or false: the first `=` gives `true` or `false`, which is then compared with `c`.
- `AND` and `OR` stop early: `false AND ...` and `true OR ...` do not compute the right side.
- Nesting is limited to 100 levels of `( )` and operators.

**Example** (sample data: sample)

```sql
SELECT 2 + 3 * 4 AS a, (2 + 3) * 4 AS b, 10 - 4 - 3 AS c, -2 * 3 AS d,
       1 = 1 OR 1 = 2 AND 1 = 3 AS e, NOT 1 = 2 AND 2 = 2 AS f, 2 + 3 BETWEEN 4 AND 6 AS g;
```

Result:

| a (LONG) | b (LONG) | c (LONG) | d (LONG) | e (BOOL) | f (BOOL) | g (BOOL) |
|---|---|---|---|---|---|---|
| 14 | 20 | 3 | -6 | true | true | true |

(1 row)

**Example: Mixing AND and OR: ( ) change the answer** (sample data: sample)

```sql
SELECT count(*) AS without_parens FROM trade_log WHERE symbol = 'TELCO' OR symbol = 'COAST' AND quantity >= 1000;
SELECT count(*) AS with_parens FROM trade_log WHERE (symbol = 'TELCO' OR symbol = 'COAST') AND quantity >= 1000;
```

Result:

`SELECT count(*) AS without_parens FROM trade_log WHERE symbol = 'TELCO' OR symbol = 'COAST' AND quan`

| without_parens (LONG) |
|---|
| 8 |

(1 row)

`SELECT count(*) AS with_parens FROM trade_log WHERE (symbol = 'TELCO' OR symbol = 'COAST') AND quant`

| with_parens (LONG) |
|---|
| 4 |

(1 row)

**Example: || and + are on the same level** (sample data: sample; shows an error)

```sql
SELECT 'Total: ' || 2 + 3 AS label;
```

Result:

Error: `line 1, column 23: 'Total: 2' and '3' are not both numbers`

**Example: The fix: ( ) around the sum** (sample data: sample)

```sql
SELECT 'Total: ' || (2 + 3) AS label;
```

Result:

| label (STRING) |
|---|
| Total: 5 |

(1 row)

<a id="arithmetic"></a>

## Arithmetic: + - * / %

Syntax:

```sql
a + b    a - b    a * b    a / b    a % b    -a
```

Add, subtract, multiply, divide and remainder. The full rules are in [arithmetic operators](functions-math.md#operators).

| Operator | Result |
|---|---|
| `+` `-` `*` | `LONG` for whole numbers (an `INT` result past `INT` becomes a `LONG`), else `DOUBLE`. A result too big for `LONG` is an error: "bigint out of range" (SQLSTATE `22003`) |
| `/` | `DOUBLE`: `7 / 2` is `3.5`. After `SET int_division = integer`, whole number / whole number is a whole number, as in PostgreSQL: `7 / 2` is `3` ([integer division](operators.md#integer-division)) |
| `%` | the remainder: `7 % 2` is `1` |
| `TIMESTAMP + number` | the time plus that many **milliseconds** |
| `TIMESTAMP - TIMESTAMP` | the milliseconds between the two times |
| `DATE + number` | the date plus that many days |

- **NULL:** `NULL` on either side gives `NULL`.
- **Notes:** dividing by zero (`5 / 0`, `5.0 / 0`, `5 % 0`) stops the query with "division by zero" (SQLSTATE `22012`), as in PostgreSQL. Write `x / NULLIF(y, 0)` to get `NULL` instead.
- Text is not a number: `'abc' + 1` is an error. `+` does **not** join text; use `||`.
- `TRUE + 1` is an error: `BOOL` is not a number.

**Example: Daily range and change in percent** (sample data: sample)

```sql
SELECT symbol, round(high - low, 2) AS day_range, round((close - open) / open * 100, 2) AS change_pct
FROM ochl_day
WHERE time IN '2026-09-10';
```

Result:

| symbol (SYMBOL) | day_range (DOUBLE) | change_pct (DOUBLE) |
|---|---|---|
| CITY | 6.3 | 0.06 |
| COAST | 8.8 | -1.05 |
| VOLT | 7.9 | 3.02 |

(3 rows)

**Example: Nepal clock hour: add 5 h 45 min in milliseconds** (sample data: sample)

```sql
SELECT hour(time + 20700000) AS npt_hour, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
GROUP BY hour(time + 20700000)
ORDER BY npt_hour;
```

Result:

| npt_hour (LONG) | volume (DOUBLE) |
|---|---|
| 11 | 47020 |
| 12 | 41230 |
| 13 | 46180 |
| 14 | 48610 |

(4 rows)

**Example** (sample data: sample)

```sql
SELECT 7 / 2 AS a, 7 % 2 AS b, 5 / NULLIF(0, 0) AS c, 9223372036854775807 * 2.0 AS big_as_double, CAST('2026-09-10' AS DATE) + 1 AS next_day;
```

Result:

| a (DOUBLE) | b (LONG) | c (STRING) | big_as_double (DOUBLE) | next_day (DATE) |
|---|---|---|---|---|
| 3.5 | 1 | NULL | 1.84467440737096e+19 | 2026-09-11 |

(1 row)

**Example: Dividing by zero is an error** (sample data: sample; shows an error)

```sql
SELECT 5 / 0;
```

Result:

Error: `line 1, column 10: division by zero`

**Example: + does not join text** (sample data: sample; shows an error)

```sql
SELECT 'CITY' + 1;
```

Result:

Error: `line 1, column 15: 'CITY' and '1' are not both numbers`

<a id="integer-division"></a>

## Integer division: SET int_division

Syntax:

```sql
SET int_division = integer | float | default
```

In KDB, `/` gives a `DOUBLE`: `7 / 2` is `3.5`. PostgreSQL gives `3`: a whole number divided by a whole number stays a whole number there. An app written for PostgreSQL may count on that, for example to read `sum(ms) / 1000` into an integer.

| Setting | `7 / 2` | `-7 / 2` | `7 / 2.0` |
|---|---|---|---|
| `float` (the default) | `3.5` | `-3.5` | `3.5` |
| `integer` | `3` | `-3` | `3.5` |

- **Returns:** with `integer`, `LONG` / `LONG` is a `LONG`, cut toward zero. When either side is a `DOUBLE`, the result is still a `DOUBLE`; a `DECIMAL` divided by a `DECIMAL` or a whole number is an exact `DECIMAL` in both settings ([DECIMAL](column-types.md#decimal)).
- **Scope:** the setting is for the **session**: the rest of one `/exec` request, a shell, or one Postgres connection. Triggers and procedures that its statements run use it too. `default` goes back to what the session started with.
- **Postgres port:** `kdb serve --pg-int-division on` (or `KDB_PG_INT_DIVISION=on`) makes `integer` the start value of every Postgres connection. A connection can also ask for it in its connection string (the startup parameter `int_division=integer`), or send `SET int_division = integer`. `SHOW int_division` gives the value.
- **Table expressions:** a table's own `CHECK`, `DEFAULT`, computed columns, index expressions and materialized view queries always use the default `DOUBLE` division, whatever the session that writes or reads. They are shared by every session, so the answer must not depend on who asked. A query in `integer` mode does not use an index on an expression with `/`; it reads the table instead.
- **Notes:** division by zero is an error in both modes. To get a `DOUBLE` in `integer` mode, cast one side: `CAST(x AS DOUBLE) / y`. To get a whole number in `float` mode, use `trunc(x / y)`.

**Example: The same division in both modes** (sample data: sample)

```sql
SELECT 7 / 2 AS a, -7 / 2 AS b, 7 / 2.0 AS c;
SET int_division = integer;
SELECT 7 / 2 AS a, -7 / 2 AS b, 7 / 2.0 AS c, 7 / NULLIF(0, 0) AS d;
```

Result:

`SELECT 7 / 2 AS a, -7 / 2 AS b, 7 / 2.0 AS c`

| a (DOUBLE) | b (DOUBLE) | c (DOUBLE) |
|---|---|---|
| 3.5 | -3.5 | 3.5 |

(1 row)

`SET int_division = 'integer'`

```text
whole number / whole number gives a whole number for this session (7 / 2 = 3)
```

`SELECT 7 / 2 AS a, -7 / 2 AS b, 7 / 2.0 AS c, 7 / nullif(0, 0) AS d`

| a (LONG) | b (LONG) | c (DOUBLE) | d (STRING) |
|---|---|---|---|
| 3 | -3 | 3.5 | NULL |

(1 row)

**Example: An average in whole shares, as a PostgreSQL app expects** (sample data: sample)

```sql
SET int_division = integer;
SELECT symbol, sum(quantity) / count(*) AS avg_whole_shares FROM trade_log WHERE date IN '2026-09-10' GROUP BY symbol ORDER BY symbol LIMIT 3;
```

Result:

`SET int_division = 'integer'`

```text
whole number / whole number gives a whole number for this session (7 / 2 = 3)
```

`SELECT symbol, sum(quantity) / count(*) AS avg_whole_shares FROM trade_log WHERE date IN '2026-09-10`

| symbol (SYMBOL) | avg_whole_shares (LONG) |
|---|---|
| CITY | 130 |
| COAST | 316 |
| TELCO | 192 |

(3 rows)

**Example: Only integer and float** (sample data: sample; shows an error)

```sql
SET int_division = half;
```

Result:

Error: `int_division must be integer or float, not 'half'`

<a id="comparison"></a>

## Comparison operators

Syntax:

```sql
a = b    a == b    a != b    a <> b    a < b    a <= b    a > b    a >= b
```

Compare two values and give `true` or `false`. They are mostly used in [WHERE](where.md#comparison), but a comparison is a normal value: you can put it in the select list.

- **Returns:** `BOOL`.
- **NULL:** `NULL` on either side gives `NULL`.
- **Notes:** a text compared with a `TIMESTAMP` or `DATE` is read as a time. A number compared with a text that holds a number is compared as numbers. Other mixes (text with a number, a BOOL with a number) are an error.
- `IS NULL`, `IN`, `BETWEEN`, `LIKE` and `ILIKE` are on the same level; see [WHERE](where.md).

**Example: Up day or down day, as a true/false column** (sample data: sample)

```sql
SELECT time, close, close > open AS up_day, close = high AS closed_at_high
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-09-06';
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | up_day (BOOL) | closed_at_high (BOOL) |
|---|---|---|---|
| 2026-09-06T00:00:00.000Z | 180.1 | true | false |
| 2026-09-07T00:00:00.000Z | 176.9 | false | false |
| 2026-09-08T00:00:00.000Z | 182.4 | true | false |
| 2026-09-09T00:00:00.000Z | 187.3 | true | false |
| 2026-09-10T00:00:00.000Z | 191.2 | true | false |

(5 rows)

**Example: A BOOL cannot be compared with a number** (sample data: sample; shows an error)

```sql
SELECT 1 = 1 = 1;
```

Result:

Error: `line 1, column 14: cannot compare BOOL 'true' with LONG '1'`

<a id="concat"></a>

## || : join text

Syntax:

```sql
value || value
```

Joins two values into one text. Numbers, times and `TRUE`/`FALSE` are turned into text first.

- **Returns:** `STRING`. Two `BYTES` values give `BYTES`.
- **NULL:** `NULL` on either side gives `NULL`. To skip NULL values, use `concat(...)` or `coalesce(x, '')` (see [text functions](functions-text.md)).
- **Notes:** `||` is on the same level as `+` and `-`. Put `( )` around calculations: `'Total: ' || (a + b)`.

**Example: A label for a chart legend** (sample data: sample)

```sql
SELECT symbol || ' - ' || name AS label FROM securities WHERE sector = 'Banking';
```

Result:

| label (STRING) |
|---|
| CITY - City Bank Limited |
| COAST - Coastal Bank Limited |

(2 rows)

**Example: Full name with city; NULL makes the whole text NULL** (sample data: query-app)

```sql
SELECT username, full_name || ' (' || city || ')' AS shown,
       full_name || ' (' || coalesce(city, 'no city') || ')' AS shown_safe
FROM app_users
WHERE id IN (1, 6, 8);
```

Result:

| username (STRING) | shown (STRING) | shown_safe (STRING) |
|---|---|---|
| ram | Ram Sharma (Kathmandu) | Ram Sharma (Kathmandu) |
| anita | NULL | Anita Magar (no city) |
| test_user | NULL | NULL |

(3 rows)

**Example** (sample data: sample)

```sql
SELECT 'CITY' || '-' || 1 AS a, 5.5 || '%' AS b, 'x' || NULL AS c;
```

Result:

| a (STRING) | b (STRING) | c (STRING) |
|---|---|---|
| CITY-1 | 5.5% | NULL |

(1 row)

<a id="json"></a>

## -> and ->> : parts of JSON

Syntax:

```sql
json -> 'key'      json -> index
json ->> 'key'     json ->> index
```

`->` takes a part of a JSON value and gives it as JSON. `->>` gives the part as text. An index counts from 0; `-1` is the last element. The JSON functions are explained in [JSON functions](functions-json.md).

- **Returns:** `->` gives `JSON`, `->>` gives `STRING`.
- **NULL:** `NULL` when the key or index is not there, or when the value is `NULL`.
- **Notes:** you can chain them: `doc -> 'a' -> 'b' ->> 0`. They bind as tight as `::`, from left to right, so `doc ->> 'n'::INT` means `(doc ->> 'n')::INT`.

**Example** (sample data: sample)

```sql
SELECT '{"symbol": "CITY", "prices": [512, 515.5, 509]}' ->> 'symbol' AS symbol,
       '{"symbol": "CITY", "prices": [512, 515.5, 509]}' -> 'prices' AS prices,
       '{"symbol": "CITY", "prices": [512, 515.5, 509]}' -> 'prices' ->> -1 AS last_price;
```

Result:

| symbol (STRING) | prices (JSON) | last_price (STRING) |
|---|---|---|
| CITY | [512,515.5,509] | 509 |

(1 row)

<a id="cast"></a>

## :: : change the type

Syntax:

```sql
value::TYPE
value::DECIMAL(scale)
```

`x::TYPE` is the short form of `CAST(x AS TYPE)`. See [conversion functions](functions-conversion.md) for every type and rule.

- **Returns:** the value in the new type.
- **NULL:** `NULL` stays `NULL`.
- **Notes:** `::` binds tighter than every other operator: `'5'::INT * 2` is `10`, and `-5::STRING` is the text `-5`.
- A value that cannot be changed is an error, for example `'abc'::INT`, or `512.456::DECIMAL(2)` (too many decimal places: use `round(x, 2)` first).

**Example** (sample data: sample)

```sql
SELECT '42'::INT + 1 AS a, 512.45::DECIMAL(2) AS b, '2026-09-10T11:00:00+05:45'::TIMESTAMP AS c, 7::DOUBLE / 2 AS d;
```

Result:

| a (LONG) | b (DECIMAL(2)) | c (TIMESTAMP) | d (DOUBLE) |
|---|---|---|---|
| 43 | 512.45 | 2026-09-10T05:15:00.000Z | 3.5 |

(1 row)

**Example: Volume as a whole number** (sample data: sample)

```sql
SELECT time, symbol, volume::LONG AS volume FROM ochl_day WHERE time IN '2026-09-10';
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | volume (LONG) |
|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 183040 |
| 2026-09-10T00:00:00.000Z | COAST | 186200 |
| 2026-09-10T00:00:00.000Z | VOLT | 41470 |

(3 rows)

**Example: Not a number** (sample data: sample; shows an error)

```sql
SELECT 'abc'::INT;
```

Result:

Error: `line 1, column 13: cannot convert 'abc' to INT`

<a id="null"></a>

## NULL rules

`NULL` means "no value" or "unknown". Most operators give `NULL` when a value is `NULL`, because the answer is unknown too.

| Operator | With NULL | Example | Result |
|---|---|---|---|
| `+` `-` `*` `/` `%` | `NULL` | `NULL + 1` | `NULL` |
| `\|\|` | `NULL` | `'a' \|\| NULL` | `NULL` |
| `=` `!=` `<` ... | `NULL` | `NULL = NULL` | `NULL` |
| `AND` | `false` wins, else `NULL` | `FALSE AND NULL` | `false` |
| `OR` | `true` wins, else `NULL` | `TRUE OR NULL` | `true` |
| `NOT` | `NULL` | `NOT NULL` | `NULL` |
| `IN (list)` | `NULL` when the value is `NULL`, or when it is not found and the list has a `NULL` | `2 IN (1, NULL)` | `NULL` |
| `BETWEEN`, `LIKE`, `ILIKE` | `NULL` | `NULL LIKE '%'` | `NULL` |
| `IS NULL`, `IS NOT NULL` | never `NULL` | `NULL IS NULL` | `true` |
| `::`, `CAST` | `NULL` | `NULL::INT` | `NULL` |

- **Notes:** `WHERE`, `HAVING` and join `ON` keep a row only when the condition is `true`; `NULL` counts as false (see [NULL in WHERE](where.md#null-in-where)).
- Aggregates like `sum`, `avg`, `min` and `count(x)` skip `NULL` values. `count(*)` counts every row.
- Use `coalesce(x, 0)` to use a default instead of `NULL` (see [conditional functions](functions-conditional.md)).

**Example** (sample data: sample)

```sql
SELECT NULL + 1 AS plus, NULL = NULL AS equals, FALSE AND NULL AS and_false, TRUE OR NULL AS or_true,
       NOT NULL AS not_null, NULL IS NULL AS is_null, coalesce(NULL, 0) + 1 AS with_default;
```

Result:

| plus (STRING) | equals (STRING) | and_false (BOOL) | or_true (BOOL) | not_null (STRING) | is_null (BOOL) | with_default (LONG) |
|---|---|---|---|---|---|---|
| NULL | NULL | false | true | NULL | true | 1 |

(1 row)

**Example: Balance of each account: NULL debits and credits need coalesce** (sample data: query-app)

```sql
SELECT account,
       sum(debit) - sum(credit) AS wrong_when_one_side_is_empty,
       coalesce(sum(debit), 0) - coalesce(sum(credit), 0) AS balance
FROM ledger
GROUP BY account
ORDER BY account;
```

Result:

| account (INT) | wrong_when_one_side_is_empty (DECIMAL(2)) | balance (DECIMAL(2)) |
|---|---|---|
| 1000 | 5000.00 | 5000.00 |
| 1100 | 230320.00 | 230320.00 |
| 1200 | 247200.00 | 247200.00 |
| 2000 | 0.00 | 0.00 |
| 3000 | NULL | -500000.00 |
| 4000 | NULL | -6250.00 |
| 4100 | NULL | -2300.00 |
| 5000 | NULL | 1030.00 |
| 5100 | NULL | 25000.00 |

(9 rows)
