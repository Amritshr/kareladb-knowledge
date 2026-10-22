# Math functions

> Round and cut numbers, take powers, roots and logarithms, divide safely, put values in buckets, and make random numbers.

- Category: Functions — math
- Keywords: math, number, rounding, %, +, -, \*, /, arithmetic, division by zero, truncate, cut decimals, cube root, log base 2, greatest common divisor, highest common factor, hcf, least common multiple, n!, combinations, histogram, bucket, bin, limit to a range, circuit limit, between bounds, divide by zero, ifnull division, zero if division by zero, ratio, percentage, banker's rounding, round half to even, NaN, not a number, infinity, inf, rand, random sample, shuffle, seed
- See also: [Trigonometry and probability](functions-math-more.md), [Finance and price functions](functions-finance.md), [Conversion functions](functions-conversion.md), [Aggregate functions](functions-aggregate.md)

These functions work on numbers: `INT`, `LONG`, `DOUBLE`, `DECIMAL` and the other number types. Sine, cosine and the normal distribution are in [trigonometry and probability](functions-math-more.md); money functions (interest, loans, NPV) are in [finance functions](functions-finance.md).

- A `NULL` argument gives `NULL` (except `greatest` and `least`, which skip NULLs).
- A result that is not a real number (like `sqrt(-1)` or `ln(0)`) is `NULL`, not an error.
- Text is not turned into a number by itself: `round('5')` is an error. Use `CAST('5' AS DOUBLE)`.

**Example: Price change of CITY, rounded to 2 decimals** (sample data: sample)

```sql
SELECT time, close,
       round(close - lag(close), 2) AS change,
       round((close - lag(close)) / lag(close) * 100, 2) AS change_pct
FROM ochl_day
WHERE symbol = 'CITY'
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | change (DOUBLE) | change_pct (DOUBLE) |
|---|---|---|---|
| 2025-12-28T00:00:00.000Z | 542.2 | NULL | NULL |
| 2025-12-29T00:00:00.000Z | 539.7 | -2.5 | -0.46 |
| 2025-12-30T00:00:00.000Z | 539.3 | -0.4 | -0.07 |
| 2025-12-31T00:00:00.000Z | 542.4 | 3.1 | 0.57 |
| 2026-08-23T00:00:00.000Z | 507.9 | -34.5 | -6.36 |

(5 rows)

## abs

Syntax:

```sql
abs(x)
```

The number without its minus sign: `abs(-5)` is `5`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value |

- **Returns:** the same type as `x` (INT stays INT, DECIMAL stays DECIMAL).
- **NULL:** `abs(NULL)` is `NULL`.

**Example**

```sql
SELECT abs(-5) AS a, abs(-2.75) AS b, abs(CAST(-3.5 AS DECIMAL(2))) AS c, abs(NULL) AS d;
```

Result:

| a (LONG) | b (DOUBLE) | c (DECIMAL(2)) | d (STRING) |
|---|---|---|---|
| 5 | 2.75 | 3.50 | NULL |

(1 row)

**Example: How far the close is from the open, for each day** (sample data: sample)

```sql
SELECT time, symbol, open, close, abs(close - open) AS move
FROM ochl_day
WHERE symbol = 'COAST'
ORDER BY move DESC
LIMIT 3;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | close (DOUBLE) | move (DOUBLE) |
|---|---|---|---|---|
| 2026-09-09T00:00:00.000Z | COAST | 398 | 380.1 | 17.9 |
| 2026-09-07T00:00:00.000Z | COAST | 373.7 | 379.2 | 5.5 |
| 2026-08-26T00:00:00.000Z | COAST | 378.1 | 373 | 5.10000000000002 |

(3 rows)

## round

Syntax:

```sql
round(x)
round(x, digits)
```

Rounds `x` to `digits` places after the decimal point. Halves go away from zero: `round(2.5)` is `3` and `round(-2.5)` is `-3`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value to round |
| `digits` | whole number | places after the point; default `0`. A negative number rounds to tens, hundreds, ... |

- **Returns:** `DOUBLE`. An `INT` or `LONG` with `digits` 0 or more comes back unchanged. A `DECIMAL` stays an exact `DECIMAL` with `digits` places: `round(2.345::NUMERIC(10,3), 2)` is `2.35`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** a `DOUBLE` can not hold every decimal exactly. `round` goes by the decimal a `DOUBLE` is written as, so `round(1.005, 2)` is `1.01` and `round(2.675, 2)` is `2.68`, as in PostgreSQL. For money that must be exact, use a `DECIMAL(2)` column.
- **Notes:** to store the same numbers as a program that rounds (for example to 6 places), round in the procedure too: [matching another system's rounding](procedures.md#rounding).

**Example**

```sql
SELECT round(512.456, 2) AS two_places, round(512.5) AS whole, round(-2.5) AS negative, round(1234.5, -2) AS hundreds, round(7) AS int_value, round(1.005, 2) AS half_cent;
```

Result:

| two_places (DOUBLE) | whole (DOUBLE) | negative (DOUBLE) | hundreds (DOUBLE) | int_value (LONG) | half_cent (DOUBLE) |
|---|---|---|---|---|---|
| 512.46 | 513 | -3 | 1200 | 7 | 1.01 |

(1 row)

**Example: Average close per symbol, rounded for a report** (sample data: sample)

```sql
SELECT symbol, round(avg(close), 2) AS avg_close, count(*) AS days
FROM ochl_day
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | avg_close (DOUBLE) | days (LONG) |
|---|---|---|
| CITY | 511.81 | 19 |
| COAST | 385.93 | 19 |
| VOLT | 180.97 | 19 |

(3 rows)

**Example: Text is not a number** (shows an error)

```sql
SELECT round('5');
```

Result:

Error: `line 1, column 8: round: argument 1 must be a number, got 5`

## round_half_even

Syntax:

```sql
round_half_even(x)
round_half_even(x, digits)
```

Rounds like [round](#round), but a value exactly **halfway** goes to the **even** neighbour: `round_half_even(2.5)` is `2`, `round_half_even(3.5)` is `4` (banker's rounding, QuestDB's `round_half_even`). Adding many rounded amounts then does not drift upwards.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value to round |
| `digits` | whole number | places after the point; default `0`. A negative number rounds to tens, hundreds, ... |

- **Returns:** the same kinds as `round`: a `DECIMAL` stays an exact `DECIMAL` with `digits` places, a whole number with `digits` 0 or more is unchanged, anything else is a `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** a `DOUBLE` is judged by the decimal it is written as, as `round` does: `round_half_even(0.125::float8, 2)` is `0.12`, and `round_half_even(0.1251::float8, 2)` is `0.13` because it is past the half. `round` itself still rounds halves away from zero.

**Example**

```sql
SELECT round_half_even(2.5) AS two, round_half_even(3.5) AS four, round_half_even(-2.5) AS minus_two,
       round_half_even(2.345, 2) AS even_cent, round_half_even(2.355, 2) AS up_cent, round_half_even(1250, -2) AS hundreds;
```

Result:

| two (DOUBLE) | four (DOUBLE) | minus_two (DOUBLE) | even_cent (DOUBLE) | up_cent (DOUBLE) | hundreds (LONG) |
|---|---|---|---|---|---|
| 2 | 4 | -2 | 2.34 | 2.36 | 1200 |

(1 row)

## floor

Syntax:

```sql
floor(x)
```

Rounds down to the whole number at or below `x`: `floor(5.7)` is `5`, `floor(-5.2)` is `-6`.

- **Returns:** `DOUBLE` for `DOUBLE` input; a `DECIMAL` gives an exact `DECIMAL` with no places; an `INT` or `LONG` comes back unchanged.
- **NULL:** `NULL` in, `NULL` out.

**Example**

```sql
SELECT floor(5.7) AS a, floor(-5.2) AS b, floor(9) AS c;
```

Result:

| a (DOUBLE) | b (DOUBLE) | c (LONG) |
|---|---|---|
| 5 | -6 | 9 |

(1 row)

**Example: Price bands of 10 dollars** (sample data: sample)

```sql
SELECT floor(close / 10) * 10 AS band, count(*) AS days
FROM ochl_day
WHERE symbol = 'CITY'
GROUP BY floor(close / 10) * 10
ORDER BY band;
```

Result:

| band (DOUBLE) | days (LONG) |
|---|---|
| 490 | 5 |
| 500 | 7 |
| 510 | 3 |
| 530 | 2 |
| 540 | 2 |

(5 rows)

<a id="ceil"></a>

## ceil, ceiling

Syntax:

```sql
ceil(x)
ceiling(x)
```

Rounds up to the whole number at or above `x`: `ceil(5.2)` is `6`, `ceil(-5.7)` is `-5`. `ceiling` is the same function.

- **Returns:** `DOUBLE` for `DOUBLE` input; a `DECIMAL` gives an exact `DECIMAL` with no places; an `INT` or `LONG` comes back unchanged.
- **NULL:** `NULL` in, `NULL` out.

**Example**

```sql
SELECT ceil(5.2) AS a, ceiling(-5.7) AS b, ceil(4) AS c;
```

Result:

| a (DOUBLE) | b (DOUBLE) | c (LONG) |
|---|---|---|
| 6 | -5 | 4 |

(1 row)

**Example: How many pages for 956 rows, 100 rows per page** (sample data: sample)

```sql
SELECT count(*) AS rows, ceil(count(*) / 100.0) AS pages FROM ochl_minutes;
```

Result:

| rows (LONG) | pages (DOUBLE) |
|---|---|
| 956 | 10 |

(1 row)

<a id="trunc"></a>

## trunc, truncate

Syntax:

```sql
trunc(x)
trunc(x, digits)
truncate(x, digits)
```

Cuts off the digits after `digits` places, without rounding: `trunc(512.789, 2)` is `512.78`, while `round` gives `512.79`. It moves toward zero: `trunc(-5.7)` is `-5` (but `floor(-5.7)` is `-6`). `truncate` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value to cut |
| `digits` | whole number | places after the point to keep; default `0`. A negative number cuts to tens, hundreds, ... |

- **Returns:** `DOUBLE`. An `INT` or `LONG` with `digits` 0 or more comes back unchanged (as a `LONG`).
- **NULL:** `NULL` when `x` or `digits` is `NULL`.
- **Notes:** `digits` must be a whole number: `trunc(5.99, 1.5)` is an error.

**Example**

```sql
SELECT trunc(512.789, 2) AS two_places, round(512.789, 2) AS rounded, trunc(-5.7) AS negative, floor(-5.7) AS floor, truncate(1234.5, -2) AS hundreds, trunc(7) AS int_value;
```

Result:

| two_places (DOUBLE) | rounded (DOUBLE) | negative (DOUBLE) | floor (DOUBLE) | hundreds (DOUBLE) | int_value (LONG) |
|---|---|---|---|---|---|
| 512.78 | 512.79 | -5 | -6 | 1200 | 7 |

(1 row)

**Example: Average trade rate: cut and rounded to 1 decimal** (sample data: sample)

```sql
SELECT symbol, avg(rate) AS avg_rate, trunc(avg(rate), 1) AS cut, round(avg(rate), 1) AS rounded
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | avg_rate (DOUBLE) | cut (DOUBLE) | rounded (DOUBLE) |
|---|---|---|---|
| CITY | 515.590909090909 | 515.5 | 515.6 |
| COAST | 399.363636363636 | 399.3 | 399.4 |
| TELCO | 880.5 | 880.5 | 880.5 |
| VOLT | 185 | 185 | 185 |

(4 rows)

**Example: digits must be a whole number** (shows an error)

```sql
SELECT trunc(5.99, 1.5);
```

Result:

Error: `line 1, column 8: trunc: argument 2 must be a whole number, got '1.5'`

## sqrt

Syntax:

```sql
sqrt(x)
```

Square root: `sqrt(16)` is `4`.

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out. A negative `x` also gives `NULL`.

**Example**

```sql
SELECT sqrt(16) AS a, sqrt(2) AS b, sqrt(-1) AS negative;
```

Result:

| a (DOUBLE) | b (DOUBLE) | negative (STRING) |
|---|---|---|
| 4 | 1.4142135623731 | NULL |

(1 row)

**Example: Daily volatility from the variance of the close** (sample data: sample)

```sql
SELECT symbol, round(sqrt(var_samp(close)), 3) AS stddev_close
FROM ochl_day
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | stddev_close (DOUBLE) |
|---|---|
| CITY | 16.198 |
| COAST | 21.379 |
| VOLT | 8.637 |

(3 rows)

## cbrt

Syntax:

```sql
cbrt(x)
```

The **cube root**: the number that, multiplied by itself three times, gives `x`. `cbrt(27)` is `3`, because 3 × 3 × 3 = 27. Unlike `sqrt`, it works for negative numbers: `cbrt(-8)` is `-2`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** `cbrt(x)` is the same as `pow(x, 1.0 / 3)` for positive `x`, but `pow` gives `NULL` for a negative `x`.

**Example**

```sql
SELECT cbrt(27) AS a, cbrt(-8) AS b, cbrt(2) AS c, pow(-8, 1.0 / 3) AS pow_negative;
```

Result:

| a (DOUBLE) | b (DOUBLE) | c (DOUBLE) | pow_negative (STRING) |
|---|---|---|---|
| 3 | -2 | 1.25992104989487 | NULL |

(1 row)

**Example: Growth per year: 1,00,000 became 1,33,100 in 3 years**

```sql
SELECT round((cbrt(133100.0 / 100000) - 1) * 100, 2) AS growth_pct_per_year;
```

Result:

| growth_pct_per_year (DOUBLE) |
|---|
| 10 |

(1 row)

<a id="pow"></a>

## pow, power

Syntax:

```sql
pow(x, y)
power(x, y)
```

`x` to the power `y`: `pow(2, 10)` is `1024`. `power` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the base |
| `y` | any number | the power; `0.5` is a square root |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` when an argument is `NULL`, or when the result is not a real number (too big, or a negative base with a fraction power).

**Example**

```sql
SELECT pow(2, 10) AS a, power(2, 0.5) AS b, pow(10, -2) AS c, pow(-8, 1.0 / 3) AS not_real;
```

Result:

| a (DOUBLE) | b (DOUBLE) | c (DOUBLE) | not_real (STRING) |
|---|---|---|---|
| 1024 | 1.4142135623731 | 0.01 | NULL |

(1 row)

**Example: Money after 5 years at 8% a year**

```sql
SELECT round(100000 * pow(1 + 0.08, 5), 2) AS amount;
```

Result:

| amount (DOUBLE) |
|---|
| 146932.81 |

(1 row)

## exp

Syntax:

```sql
exp(x)
```

The number e (2.718...) to the power `x`. It undoes `ln`.

- **Returns:** `DOUBLE`. `NULL` when the result is too big for a `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out.

**Example**

```sql
SELECT exp(0) AS a, exp(1) AS e, exp(ln(5)) AS back_to_5, exp(1000) AS too_big;
```

Result:

| a (DOUBLE) | e (DOUBLE) | back_to_5 (DOUBLE) | too_big (DOUBLE) |
|---|---|---|---|
| 1 | 2.71828182845905 | 5 | NULL |

(1 row)

<a id="ln"></a>

## ln, log

Syntax:

```sql
ln(x)
log(x)
```

`ln(x)` is the natural logarithm (base e). `log(x)` is base 10, as in PostgreSQL: `log(100)` is `2`, the same as `log10(100)`. `log(b, x)` is base `b`.

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out. `x` of 0 or less gives `NULL`.
- **Notes:** before 2026-09-25 `log(x)` was the natural logarithm. A query that meant ln should now say `ln`.

**Example**

```sql
SELECT ln(1) AS a, ln(exp(2)) AS b, log(100) AS base_10, log(2, 8) AS base_2, ln(0) AS zero;
```

Result:

| a (DOUBLE) | b (DOUBLE) | base_10 (DOUBLE) | base_2 (DOUBLE) | zero (STRING) |
|---|---|---|---|---|
| 0 | 2 | 2 | 3 | NULL |

(1 row)

**Example: Log returns of CITY** (sample data: sample)

```sql
SELECT time, close, round(ln(close / lag(close)), 5) AS log_return
FROM ochl_day
WHERE symbol = 'CITY'
LIMIT 4;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | log_return (DOUBLE) |
|---|---|---|
| 2025-12-28T00:00:00.000Z | 542.2 | NULL |
| 2025-12-29T00:00:00.000Z | 539.7 | -0.00462 |
| 2025-12-30T00:00:00.000Z | 539.3 | -0.00074 |
| 2025-12-31T00:00:00.000Z | 542.4 | 0.00573 |

(4 rows)

## log10

Syntax:

```sql
log10(x)
```

Logarithm base 10: `log10(1000)` is `3`.

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out. `x` of 0 or less gives `NULL`.

**Example**

```sql
SELECT log10(1000) AS a, log10(2) AS b, log10(-1) AS negative;
```

Result:

| a (DOUBLE) | b (DOUBLE) | negative (STRING) |
|---|---|---|
| 3 | 0.301029995663981 | NULL |

(1 row)

## log2

Syntax:

```sql
log2(x)
```

Logarithm base 2: how many times you double 1 to get `x`. `log2(8)` is `3`, because 1 → 2 → 4 → 8. For a price, `log2(new / old)` tells how many times the price **doubled**.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value, more than 0 |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out. `x` of 0 or less gives `NULL`.

**Example**

```sql
SELECT log2(8) AS a, log2(1024) AS b, log2(1000) AS c, log2(0) AS zero;
```

Result:

| a (DOUBLE) | b (DOUBLE) | c (DOUBLE) | zero (STRING) |
|---|---|---|---|
| 3 | 10 | 9.96578428466209 | NULL |

(1 row)

**Example: A share went from 100 to 800 dollars: how many doublings?**

```sql
SELECT log2(800.0 / 100) AS doublings, pow(2, log2(800.0 / 100)) * 100 AS back_to_price;
```

Result:

| doublings (DOUBLE) | back_to_price (DOUBLE) |
|---|---|
| 3 | 800 |

(1 row)

## sign

Syntax:

```sql
sign(x)
```

`-1` for a negative number, `0` for zero, `1` for a positive number.

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out.

**Example**

```sql
SELECT sign(-7) AS a, sign(0) AS b, sign(3.5) AS c;
```

Result:

| a (DOUBLE) | b (DOUBLE) | c (DOUBLE) |
|---|---|---|
| -1 | 0 | 1 |

(1 row)

**Example: Up, down or flat days** (sample data: sample)

```sql
SELECT sign(close - open) AS direction, count(*) AS days
FROM ochl_day
GROUP BY sign(close - open)
ORDER BY direction;
```

Result:

| direction (DOUBLE) | days (LONG) |
|---|---|
| -1 | 27 |
| 1 | 30 |

(2 rows)

## mod

Syntax:

```sql
mod(x, y)
x % y
```

The remainder after dividing `x` by `y`: `mod(10, 3)` is `1`. The `%` operator does the same.

- **Returns:** `LONG` when both are whole numbers, else `DOUBLE`. The sign follows `x`.
- **NULL:** `NULL` when an argument is `NULL`. A `y` of `0` is an error, "division by zero", as in PostgreSQL.

**Example**

```sql
SELECT mod(10, 3) AS a, 10 % 3 AS b, mod(-10, 3) AS c, mod(10.5, 3) AS d, mod(5, NULLIF(0, 0)) AS by_zero;
```

Result:

| a (LONG) | b (LONG) | c (LONG) | d (DOUBLE) | by_zero (STRING) |
|---|---|---|---|---|
| 1 | 1 | -1 | 1.5 | NULL |

(1 row)

**Example: Every 5th transaction of the trade log** (sample data: sample)

```sql
SELECT transaction_id, symbol, quantity
FROM trade_log
WHERE transaction_id % 5 = 0
ORDER BY transaction_id
LIMIT 4;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | quantity (LONG) |
|---|---|---|
| 100005 | CITY | 500 |
| 100010 | CITY | 50 |
| 100015 | COAST | 1000 |
| 100020 | VOLT | 100 |

(4 rows)

## greatest

Syntax:

```sql
greatest(value, value, ...)
```

The biggest of the values. `NULL` values are skipped. Works for numbers, text and times.

- **Returns:** the biggest value (its own type).
- **NULL:** `NULL` only when every value is `NULL`.
- **Notes:** values that cannot be compared (a number and a text) give an error. At most 64 values.

**Example**

```sql
SELECT greatest(3, 9, 4) AS a, greatest(3, NULL, 9) AS b, greatest('CITY', 'COAST') AS c, greatest(NULL, NULL) AS d;
```

Result:

| a (LONG) | b (LONG) | c (STRING) | d (STRING) |
|---|---|---|---|
| 9 | 9 | COAST | NULL |

(1 row)

**Example: The bigger of two prices** (sample data: sample)

```sql
SELECT time, open, close, greatest(open, close) AS body_top
FROM ochl_day
WHERE symbol = 'VOLT'
LIMIT 3;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | close (DOUBLE) | body_top (DOUBLE) |
|---|---|---|---|
| 2025-12-28T00:00:00.000Z | 187.7 | 191.7 | 191.7 |
| 2025-12-29T00:00:00.000Z | 192.9 | 196.4 | 196.4 |
| 2025-12-30T00:00:00.000Z | 195 | 192.3 | 195 |

(3 rows)

## least

Syntax:

```sql
least(value, value, ...)
```

The smallest of the values. `NULL` values are skipped. Works for numbers, text and times.

- **Returns:** the smallest value (its own type).
- **NULL:** `NULL` only when every value is `NULL`.
- **Notes:** values that cannot be compared give an error. At most 64 values.

**Example**

```sql
SELECT least(3, 9, 4) AS a, least(3, NULL, 9) AS b, least('2026-09-10', '2026-01-01') AS c;
```

Result:

| a (LONG) | b (LONG) | c (STRING) |
|---|---|---|
| 3 | 3 | 2026-01-01 |

(1 row)

**Example: A number and a text cannot be compared** (shows an error)

```sql
SELECT least(1, 'a');
```

Result:

Error: `line 1, column 8: least: values cannot be compared`

## gcd

Syntax:

```sql
gcd(a, b)
```

The **greatest common divisor**: the biggest whole number that divides both `a` and `b` with no remainder. `gcd(12, 18)` is `6`. Use it to make a ratio as small as possible, like a bonus share ratio of 20:100 that is really 1:5.

| Argument | Type | Meaning |
|---|---|---|
| `a` | whole number | the first value |
| `b` | whole number | the second value |

- **Returns:** `LONG`, 0 or more (the sign is ignored).
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** `gcd(0, 5)` is `5`. A number with a fraction (`12.5`) is an error; a `DOUBLE` like `12.0` is fine.

**Example**

```sql
SELECT gcd(12, 18) AS a, gcd(-12, 18) AS b, gcd(0, 5) AS c, gcd(7, 5) AS no_common;
```

Result:

| a (LONG) | b (LONG) | c (LONG) | no_common (LONG) |
|---|---|---|---|
| 6 | 6 | 5 | 1 |

(1 row)

**Example: Write a bonus share ratio in its smallest form**

```sql
SELECT bonus, held,
       bonus / gcd(bonus, held) AS bonus_small,
       held / gcd(bonus, held) AS held_small
FROM (SELECT 20 AS bonus, 100 AS held UNION ALL SELECT 15, 45 UNION ALL SELECT 7, 10) t;
```

Result:

| bonus (LONG) | held (LONG) | bonus_small (DOUBLE) | held_small (DOUBLE) |
|---|---|---|---|
| 20 | 100 | 1 | 5 |
| 15 | 45 | 1 | 3 |
| 7 | 10 | 7 | 10 |

(3 rows)

**Example: Only whole numbers** (shows an error)

```sql
SELECT gcd(12.5, 5);
```

Result:

Error: `line 1, column 8: gcd: argument 1 must be a whole number, got '12.5'`

## lcm

Syntax:

```sql
lcm(a, b)
```

The **least common multiple**: the smallest whole number that both `a` and `b` divide. `lcm(4, 6)` is `12`. If one thing happens every 4 days and another every 6 days, they happen on the same day every 12 days.

| Argument | Type | Meaning |
|---|---|---|
| `a` | whole number | the first value |
| `b` | whole number | the second value |

- **Returns:** `LONG`, 0 or more.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** `lcm(0, x)` is `0`. A result too big for a `LONG` is an error.

**Example**

```sql
SELECT lcm(4, 6) AS a, lcm(-4, 6) AS b, lcm(0, 5) AS c, lcm(7, 5) AS d;
```

Result:

| a (LONG) | b (LONG) | c (LONG) | d (LONG) |
|---|---|---|---|
| 12 | 12 | 0 | 35 |

(1 row)

**Example: The smallest order that fits a lot size of 10 and a lot size of 25**

```sql
SELECT lcm(10, 25) AS smallest_order;
```

Result:

| smallest_order (LONG) |
|---|
| 50 |

(1 row)

## factorial

Syntax:

```sql
factorial(n)
```

`n!`: the product 1 × 2 × 3 × ... × `n`. `factorial(5)` is `120`. It counts the ways to put `n` things in a row, and it is used to count **combinations** (how many ways to pick `k` things from `n`).

| Argument | Type | Meaning |
|---|---|---|
| `n` | whole number, 0 or more | how many things |

- **Returns:** `LONG` for `n` up to 20. From 21, the result is too big for a `LONG` and is a `DOUBLE` (not exact). From 171 it is too big even for a `DOUBLE`: `NULL`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** `factorial(0)` is `1`. A negative `n` or a fraction is an error.

**Example**

```sql
SELECT factorial(0) AS a, factorial(5) AS b, factorial(20) AS c, factorial(21) AS d, factorial(171) AS e;
```

Result:

| a (LONG) | b (LONG) | c (LONG) | d (DOUBLE) | e (STRING) |
|---|---|---|---|---|
| 1 | 120 | 2432902008176640000 | 5.10909421717094e+19 | NULL |

(1 row)

**Example: How many ways to pick 3 shares from the 5 securities?** (sample data: sample)

```sql
SELECT n, factorial(n) / (factorial(3) * factorial(n - 3)) AS ways_to_pick_3
FROM (SELECT count(*) AS n FROM securities) t;
```

Result:

| n (LONG) | ways_to_pick_3 (DOUBLE) |
|---|---|
| 5 | 10 |

(1 row)

**Example: A negative number is an error** (shows an error)

```sql
SELECT factorial(-1);
```

Result:

Error: `line 1, column 8: factorial: needs 0 or more, got -1`

## pi

Syntax:

```sql
pi()
```

The number π (3.14159...): the length around a circle divided by its width. You need it with [sin and cos](functions-math-more.md) and with [radians](#radians).

- **Returns:** `DOUBLE`.
- **NULL:** never `NULL`.

**Example**

```sql
SELECT pi() AS pi, round(pi(), 2) AS short, 2 * pi() AS full_circle_in_radians;
```

Result:

| pi (DOUBLE) | short (DOUBLE) | full_circle_in_radians (DOUBLE) |
|---|---|---|
| 3.14159265358979 | 3.14 | 6.28318530717959 |

(1 row)

## degrees

Syntax:

```sql
degrees(x)
```

Changes an angle in **radians** to **degrees**. A full circle is 360 degrees or 2π radians, so `degrees(pi())` is `180`. The functions `asin`, `acos`, `atan` and `atan2` give radians; use `degrees` to read them.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | an angle in radians |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out.

**Example**

```sql
SELECT degrees(pi()) AS half_circle, degrees(pi() / 2) AS right_angle, degrees(1) AS one_radian, degrees(atan(1)) AS atan_1;
```

Result:

| half_circle (DOUBLE) | right_angle (DOUBLE) | one_radian (DOUBLE) | atan_1 (DOUBLE) |
|---|---|---|---|
| 180 | 90 | 57.2957795130823 | 45 |

(1 row)

## radians

Syntax:

```sql
radians(x)
```

Changes an angle in **degrees** to **radians**, the unit that `sin`, `cos` and `tan` need. `radians(180)` is π.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | an angle in degrees |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` in, `NULL` out.

**Example**

```sql
SELECT radians(180) AS pi, radians(90) AS right_angle, round(sin(radians(30)), 4) AS sin_30_degrees;
```

Result:

| pi (DOUBLE) | right_angle (DOUBLE) | sin_30_degrees (DOUBLE) |
|---|---|---|
| 3.14159265358979 | 1.5707963267949 | 0.5 |

(1 row)

<a id="width_bucket"></a>

## width_bucket

Syntax:

```sql
width_bucket(x, low, high, count)
```

Cuts the range from `low` to `high` into `count` buckets of the same width, and says which bucket `x` falls in: `1` to `count`. A value below `low` is bucket `0`; a value at or above `high` is bucket `count + 1`. Use it to make a **histogram**: a count of values per bucket.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value to place |
| `low` | any number | where bucket 1 starts |
| `high` | any number | where the last bucket ends (not included) |
| `count` | whole number, 1 or more | how many buckets |

- **Returns:** `LONG`.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** each bucket includes its start and not its end. When `low` is bigger than `high`, the buckets count down. `low` and `high` must be different, else an error. Like PostgreSQL `width_bucket`.

**Example**

```sql
SELECT width_bucket(512, 400, 600, 4) AS a, width_bucket(399, 400, 600, 4) AS below, width_bucket(600, 400, 600, 4) AS at_high, width_bucket(450, 600, 400, 4) AS down;
```

Result:

| a (LONG) | below (LONG) | at_high (LONG) | down (LONG) |
|---|---|---|---|
| 3 | 0 | 5 | 4 |

(1 row)

**Example: Histogram of CITY's one-minute closes on 10 September** (sample data: sample)

```sql
SELECT width_bucket(close, 500, 510, 5) AS bucket,
       500 + (width_bucket(close, 500, 510, 5) - 1) * 2 AS from_price,
       count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
GROUP BY width_bucket(close, 500, 510, 5)
ORDER BY bucket;
```

Result:

| bucket (LONG) | from_price (LONG) | minutes (LONG) |
|---|---|---|
| 1 | 500 | 11 |
| 2 | 502 | 87 |
| 3 | 504 | 109 |
| 4 | 506 | 33 |

(4 rows)

**Example: Daily returns in 1% buckets from -3% to +3%** (sample data: sample)

```sql
SELECT width_bucket(chg, -3, 3, 6) AS bucket, count(*) AS days
FROM (SELECT pct_change(close) OVER (PARTITION BY symbol ORDER BY time) AS chg
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE chg IS NOT NULL
GROUP BY width_bucket(chg, -3, 3, 6)
ORDER BY bucket;
```

Result:

| bucket (LONG) | days (LONG) |
|---|---|
| 1 | 1 |
| 2 | 11 |
| 3 | 11 |
| 4 | 9 |
| 5 | 5 |
| 6 | 4 |
| 7 | 1 |

(7 rows)

## clamp

Syntax:

```sql
clamp(x, low, high)
```

Keeps `x` inside the range from `low` to `high`: below `low` gives `low`, above `high` gives `high`, else `x`. It is the same as `least(greatest(x, low), high)`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number, text or time | the value |
| `low` | same kind as `x` | the smallest allowed value |
| `high` | same kind as `x` | the biggest allowed value |

- **Returns:** the value that was chosen, with its own type.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** `low` bigger than `high` is an error. Values that cannot be compared (a number and a text) are an error.

**Example**

```sql
SELECT clamp(15, 0, 10) AS too_big, clamp(-3, 0, 10) AS too_small, clamp(4.5, 0, 10) AS inside, clamp('m', 'a', 'k') AS text;
```

Result:

| too_big (LONG) | too_small (LONG) | inside (DOUBLE) | text (STRING) |
|---|---|---|---|
| 10 | 0 | 4.5 | k |

(1 row)

**Example: Circuit limit: an order price must stay within 10% of yesterday's close**

Setup:

```sql
CREATE TABLE orders (id INT, symbol STRING, prev_close DOUBLE, price DOUBLE);
INSERT INTO orders VALUES (1, 'CITY', 504.9, 570.0), (2, 'COAST', 376.1, 390.0), (3, 'VOLT', 191.2, 160.0);
```

```sql
SELECT id, symbol, prev_close, price,
       clamp(price, round(prev_close * 0.9, 1), round(prev_close * 1.1, 1)) AS allowed_price
FROM orders
ORDER BY id;
```

Result:

| id (INT) | symbol (STRING) | prev_close (DOUBLE) | price (DOUBLE) | allowed_price (DOUBLE) |
|---|---|---|---|---|
| 1 | CITY | 504.9 | 570 | 555.4 |
| 2 | COAST | 376.1 | 390 | 390 |
| 3 | VOLT | 191.2 | 160 | 172.1 |

(3 rows)

**Example: The lower bound must not be bigger** (shows an error)

```sql
SELECT clamp(5, 10, 0);
```

Result:

Error: `line 1, column 8: clamp: the lower bound is bigger than the upper bound`

<a id="safe_divide"></a>

## safe_divide

Syntax:

```sql
safe_divide(x, y)
```

`x / y`, but `NULL` when `y` is `0`. The `/` operator stops the query with "division by zero" instead, as PostgreSQL does; `safe_divide` works like `SAFE_DIVIDE` in BigQuery, so copied SQL runs.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the number to divide |
| `y` | any number | the number to divide by |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` when an argument is `NULL` or `y` is `0`.
- **Notes:** to get `0` instead of `NULL`, use [div0](#div0).

**Example**

```sql
SELECT safe_divide(10, 4) AS a, safe_divide(10, 0) AS by_zero, 10 / NULLIF(0, 0) AS operator, safe_divide(NULL, 2) AS null_value;
```

Result:

| a (DOUBLE) | by_zero (STRING) | operator (STRING) | null_value (STRING) |
|---|---|---|---|
| 2.5 | NULL | NULL | NULL |

(1 row)

**Example: Average trade size, also on a day with no trades**

Setup:

```sql
CREATE TABLE broker_day (broker INT, trades INT, shares INT);
INSERT INTO broker_day VALUES (1, 12, 3400), (34, 0, 0), (45, 5, 1250);
```

```sql
SELECT broker, trades, shares, safe_divide(shares, trades) AS avg_trade_size
FROM broker_day
ORDER BY broker;
```

Result:

| broker (INT) | trades (INT) | shares (INT) | avg_trade_size (DOUBLE) |
|---|---|---|---|
| 1 | 12 | 3400 | 283.333333333333 |
| 34 | 0 | 0 | NULL |
| 45 | 5 | 1250 | 250 |

(3 rows)

## div0

Syntax:

```sql
div0(x, y)
```

`x / y`, but `0` when `y` is `0` (like `DIV0` in Snowflake). Use it when a zero is the right answer, for example so that a total over many rows is not hurt by a `NULL`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the number to divide |
| `y` | any number | the number to divide by |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` when an argument is `NULL`. A `y` of `0` gives `0`, not `NULL`.

**Example**

```sql
SELECT div0(10, 4) AS a, div0(10, 0) AS by_zero, div0(5, NULL) AS null_value;
```

Result:

| a (DOUBLE) | by_zero (DOUBLE) | null_value (STRING) |
|---|---|---|
| 2.5 | 0 | NULL |

(1 row)

**Example: safe_divide and div0 side by side**

Setup:

```sql
CREATE TABLE broker_day (broker INT, trades INT, shares INT);
INSERT INTO broker_day VALUES (1, 12, 3400), (34, 0, 0), (45, 5, 1250);
```

```sql
SELECT broker, safe_divide(shares, trades) AS safe_divide, div0(shares, trades) AS div0
FROM broker_day
ORDER BY broker;
```

Result:

| broker (INT) | safe_divide (DOUBLE) | div0 (DOUBLE) |
|---|---|---|
| 1 | 283.333333333333 | 283.333333333333 |
| 34 | NULL | 0 |
| 45 | 250 | 250 |

(3 rows)

## percent

Syntax:

```sql
percent(part, total)
```

`part` as a percent of `total`: `part / total × 100`. `percent(25, 200)` is `12.5`.

| Argument | Type | Meaning |
|---|---|---|
| `part` | any number | the part |
| `total` | any number | the whole |

- **Returns:** `DOUBLE` (`12.5` means 12.5%).
- **NULL:** `NULL` when an argument is `NULL` or `total` is `0`.

**Example**

```sql
SELECT percent(25, 200) AS a, percent(3, 4) AS b, percent(5, 0) AS zero_total;
```

Result:

| a (DOUBLE) | b (DOUBLE) | zero_total (STRING) |
|---|---|---|
| 12.5 | 75 | NULL |

(1 row)

**Example: Share of paying (pro) users in each city** (sample data: query-app)

```sql
SELECT city, count(*) AS users,
       sum(CASE WHEN plan = 'pro' THEN 1 ELSE 0 END) AS pro_users,
       round(percent(sum(CASE WHEN plan = 'pro' THEN 1 ELSE 0 END), count(*)), 1) AS pro_pct
FROM app_users
WHERE city IS NOT NULL
GROUP BY city
ORDER BY pro_pct DESC, city;
```

Result:

| city (STRING) | users (LONG) | pro_users (LONG) | pro_pct (DOUBLE) |
|---|---|---|---|
| Dharan | 1 | 1 | 100 |
| Kathmandu | 2 | 1 | 50 |
| Pokhara | 2 | 1 | 50 |
| Lalitpur | 1 | 0 | 0 |

(4 rows)

<a id="is_nan"></a>

## is_nan, is_inf, is_finite

Syntax:

```sql
is_nan(x)
is_inf(x)
is_finite(x)
```

A `DOUBLE` can hold three special values that are not normal numbers: **NaN** ("not a number", for example from `0 × infinity`), **inf** (infinity) and **-inf**. They can come from other programs or from a calculation that is too big. These functions test for them.

| Function | `true` when `x` is |
|---|---|
| `is_nan(x)` | NaN |
| `is_inf(x)` | inf or -inf |
| `is_finite(x)` | a normal number (not NaN, not inf) |

- **Returns:** `BOOL`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:** most KarelaDB math functions give `NULL` instead of NaN or inf. The `*` operator does not: `1e308 * 10` is inf. Text is an error.

**Example**

```sql
SELECT is_nan(CAST('NaN' AS DOUBLE)) AS nan, is_inf(CAST('-inf' AS DOUBLE)) AS minus_inf,
       is_finite(1e308 * 10) AS too_big_is_finite, is_finite(512.5) AS normal, is_nan(NULL) AS null_value;
```

Result:

| nan (BOOL) | minus_inf (BOOL) | too_big_is_finite (BOOL) | normal (BOOL) | null_value (STRING) |
|---|---|---|---|---|
| true | true | false | true | NULL |

(1 row)

**Example: Which values are normal numbers?**

```sql
SELECT name, is_nan(x) AS is_nan, is_inf(x) AS is_inf, is_finite(x) AS is_finite
FROM (SELECT 'price' AS name, 512.5 AS x
      UNION ALL SELECT 'too big', 1e308 * 10
      UNION ALL SELECT 'not a number', CAST('NaN' AS DOUBLE)) t;
```

Result:

| name (STRING) | is_nan (BOOL) | is_inf (BOOL) | is_finite (BOOL) |
|---|---|---|---|
| price | false | false | true |
| too big | false | true | false |
| not a number | true | false | false |

(3 rows)

<a id="random"></a>

## random, rand

Syntax:

```sql
random()
rand()
```

A random number from `0` up to (but not including) `1`. Every call gives a new number, also on every row. `rand` is the same function.

- **Returns:** `DOUBLE`, at least `0` and less than `1`.
- **NULL:** never `NULL`.
- **Notes:**
  - A random whole number from 1 to 6: `floor(random() * 6) + 1`.
  - `ORDER BY random() LIMIT n` picks `n` random rows.
  - Not safe for passwords or tokens: use [random_token](functions-security.md#random-token) for those.
  - Results with `random()` are never taken from a cache.

**Example: Every one-minute candle gets a random number, always from 0 to 1** (sample data: sample)

```sql
SELECT count(*) AS rows, min(r) >= 0 AS at_least_0, max(r) < 1 AS below_1
FROM (SELECT random() AS r FROM ochl_minutes) t;
```

Result:

| rows (LONG) | at_least_0 (BOOL) | below_1 (BOOL) |
|---|---|---|
| 956 | true | true |

(1 row)

**Example: Pick 3 app users for a survey (setseed makes the pick repeatable)** (sample data: query-app)

```sql
SELECT setseed(0.42);
SELECT username, city FROM app_users ORDER BY random() LIMIT 3;
```

Result:

`SELECT setseed(0.42)`

| setseed(0.42) (STRING) |
|---|
| NULL |

(1 row)

`SELECT username, city FROM app_users ORDER BY random() LIMIT 3`

| username (STRING) | city (STRING) |
|---|---|
| suman | Pokhara |
| anita | NULL |
| gita | Dharan |

(3 rows)

## setseed

Syntax:

```sql
setseed(seed)
```

Starts the random numbers from a fixed point, the **seed**. After the same `setseed`, `random()` gives the same numbers again, in the same order. Use it for tests and for a random sample that you can make again.

| Argument | Type | Meaning |
|---|---|---|
| `seed` | number from `-1` to `1` | the starting point |

- **Returns:** always `NULL`.
- **NULL:** `setseed(NULL)` gives `NULL` and changes nothing.
- **Notes:** the seed is shared by the whole kareladb program. On a server, another user's `random()` calls move the numbers on, so the order is only repeatable when nobody else uses `random()` at the same time.

**Example: The same seed gives the same numbers**

```sql
SELECT setseed(0.5);
SELECT round(random(), 4) AS first, round(random(), 4) AS second;
SELECT setseed(0.5);
SELECT round(random(), 4) AS first_again, round(random(), 4) AS second_again;
```

Result:

`SELECT setseed(0.5)`

| setseed(0.5) (STRING) |
|---|
| NULL |

(1 row)

`SELECT round(random(), 4) AS first, round(random(), 4) AS second`

| first (DOUBLE) | second (DOUBLE) |
|---|---|
| 0.1391 | 0.9194 |

(1 row)

`SELECT setseed(0.5)`

| setseed(0.5) (STRING) |
|---|
| NULL |

(1 row)

`SELECT round(random(), 4) AS first_again, round(random(), 4) AS second_again`

| first_again (DOUBLE) | second_again (DOUBLE) |
|---|---|
| 0.1391 | 0.9194 |

(1 row)

**Example: The seed must be from -1 to 1** (shows an error)

```sql
SELECT setseed(2);
```

Result:

Error: `line 1, column 8: setseed: the seed must be between -1 and 1`

<a id="operators"></a>

## Arithmetic operators

Syntax:

```sql
a + b    a - b    a * b    a / b    a % b    -a
```

| Operator | Result |
|---|---|
| `+` `-` `*` | `LONG` when both sides are whole numbers (an `INT` result past `INT` simply becomes a `LONG`), else `DOUBLE`. A result too big for `LONG` is an error: "bigint out of range" |
| `/` | `DOUBLE`: `7 / 2` is `3.5`. After `SET int_division = integer`, whole number / whole number is a whole number, as in PostgreSQL: `7 / 2` is `3` ([integer division](operators.md#integer-division)) |
| `%` | remainder, like `mod` |
| `TIMESTAMP + number` | the time plus that many milliseconds |
| `TIMESTAMP - TIMESTAMP` | milliseconds between the two times |
| `DATE + number` | the date plus that many days |

- **NULL:** `NULL` on either side gives `NULL`.
- **Division by zero:** `5 / 0`, `5.0 / 0` and `5 % 0` stop the query with "division by zero" (SQLSTATE `22012`), as in PostgreSQL. For `NULL` instead, write `x / NULLIF(y, 0)` or [safe_divide](#safe_divide).
- **Too big:** a whole-number result that does not fit a `LONG` stops the query (SQLSTATE `22003`). Cast one side to `DOUBLE` for an approximate answer.
- `*` and `/` are done before `+` and `-`. Use `( )` to change the order.

**Example**

```sql
SELECT 2 + 3 * 4 AS a, (2 + 3) * 4 AS b, 7 / 2 AS c, 7 % 2 AS d, 5 / NULLIF(0, 0) AS e, -2 * 3 AS f, NULL + 1 AS g;
```

Result:

| a (LONG) | b (LONG) | c (DOUBLE) | d (LONG) | e (STRING) | f (LONG) | g (STRING) |
|---|---|---|---|---|---|---|
| 14 | 20 | 3.5 | 1 | NULL | -6 | NULL |

(1 row)

**Example: Division by zero is an error** (shows an error)

```sql
SELECT 5 / 0;
```

Result:

Error: `line 1, column 10: division by zero`

**Example: Too big for a LONG** (shows an error)

```sql
SELECT 9223372036854775807 + 1;
```

Result:

Error: `line 1, column 28: bigint out of range (numeric value out of range)`

**Example: Times: add one hour, and the minutes between two times**

```sql
SELECT CAST('2026-09-10T05:15:00Z' AS TIMESTAMP) + 3600000 AS plus_one_hour,
       (CAST('2026-09-10T11:00:00Z' AS TIMESTAMP) - CAST('2026-09-10T05:15:00Z' AS TIMESTAMP)) / 60000 AS minutes;
```

Result:

| plus_one_hour (TIMESTAMP) | minutes (DOUBLE) |
|---|---|
| 2026-09-10T06:15:00.000Z | 345 |

(1 row)
