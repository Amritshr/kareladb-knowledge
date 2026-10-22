# Aggregate functions

> Make one value from many rows: count, sum, avg, min, max, first, last, median, percentile, vwap, twap, conditional counts and sums, the row of the maximum, and lists of text.

- Category: Functions — aggregate
- Keywords: aggregate, group, total, average, mean, count rows, how many, number of rows, biggest, smallest, highest, lowest, open high low close, candle, turnover, count(), distinct count, uniq, quantile, p90, p95, volume weighted average price, implicit GROUP BY, HAVING, aggregate in WHERE, conditional count, countif, COUNT FILTER, sumif, SUM FILTER, averageif, multiply all, all true, any true, bool\_all, row of the maximum, day of the highest close, row of the minimum, group\_concat, join text, comma list, collect list, JSON array, jsonb\_agg, JSON object, jsonb\_object\_agg, weighted average, SUMPRODUCT, time weighted average price, TWAP
- See also: [GROUP BY and HAVING](group-by.md), [SAMPLE BY](sample-by.md), [Statistics functions](functions-statistics.md), [Window and series functions (aggregates)](functions-window.md#aggregates), [Conditional and NULL functions (coalesce)](functions-conditional.md#coalesce), [Candles cookbook](candles-cookbook.md), [PIVOT](pivot.md)

An **aggregate** function reads many rows and gives back one value. For example, `sum(quantity)` adds up the quantity of every row.

- With `GROUP BY` (or `SAMPLE BY`) you get one result row for each **group**. A group is all the rows with the same key, for example the same symbol.
- Without `GROUP BY`, all rows are one group, and you get one row.
- **Implicit GROUP BY:** like QuestDB, KDB groups by itself. Every select item that is **not** inside an aggregate becomes a group key. `SELECT symbol, max(high) FROM ochl_day` gives one row per symbol.
- Aggregates **skip NULL values**. `avg` of 10, NULL and 20 is 15. Only `count(*)` counts every row, and `first` and `last` take the first / last row's value even when it is NULL (as in QuestDB; `first_not_null` and `last_not_null` skip NULLs).
- On **no rows** (without GROUP BY) `count` gives `0` and the others give `NULL`. With GROUP BY, no rows give no groups.
- Aggregates can only be in the select list and in `HAVING`. To keep only some groups, use `HAVING` ([group-by](group-by.md)), not `WHERE`.
- `GROUP BY` can use a name from the select list (`GROUP BY band` when `band` is an alias) or a position: `GROUP BY 1` is the first column, as in PostgreSQL.
- Put `OVER (...)` after an aggregate to get a running total or a moving value for **every** row instead of one row per group ([window functions](functions-window.md#aggregates)).
- More aggregates have their own pages: spread and shape ([statistics](functions-statistics.md)), correlation and regression ([correlation](functions-correlation.md)), Sharpe ratio and drawdown ([returns and risk](functions-returns-risk.md)), and `xnpv`, `xirr` ([finance](functions-finance.md)).

**Example: A daily candle for each symbol, made from one-minute candles** (sample data: sample)

```sql
SELECT symbol,
       first(open)  AS open,
       max(high)    AS high,
       min(low)     AS low,
       last(close)  AS close,
       sum(volume)  AS volume,
       count(*)     AS minutes
FROM ochl_minutes
WHERE time IN '2026-09-10'
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) | minutes (LONG) |
|---|---|---|---|---|---|---|
| CITY | 504.6 | 507 | 500.7 | 504.9 | 183040 | 240 |
| COAST | 380.1 | 382 | 373.2 | 376.1 | 186200 | 236 |

(2 rows)

**Example: Aggregates cannot be used in WHERE** (sample data: sample; shows an error)

```sql
SELECT symbol FROM trade_log WHERE sum(quantity) > 1000;
```

Result:

Error: `line 1, column 36: 'sum' works on many rows and can only be used in a SELECT list or HAVING`

**Example: GROUP BY can use the AS name of a column** (sample data: sample)

```sql
SELECT floor(rate / 100) * 100 AS band, count(*) AS trades
FROM trade_log
GROUP BY band
ORDER BY band;
```

Result:

| band (DOUBLE) | trades (LONG) |
|---|---|
| 100 | 4 |
| 300 | 7 |
| 400 | 4 |
| 500 | 11 |
| 800 | 6 |

(5 rows)

<a id="count-star"></a>

## count(*)

Syntax:

```sql
count(*)
count()
```

The number of rows. NULL values do not matter here: every row counts. `count()` without `*` is the same (QuestDB style).

- **Returns:** `LONG`.
- **NULL:** rows with NULL values are counted too.
- **Notes:** on no rows, `count(*)` is `0` (without GROUP BY). With GROUP BY, a group with no rows does not exist, so you do not get a `0` row for it.

**Example: Trades per symbol on one day** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades
FROM trade_log
WHERE date IN '2026-09-10'
GROUP BY symbol
ORDER BY trades DESC;
```

Result:

| symbol (SYMBOL) | trades (LONG) |
|---|---|
| COAST | 9 |
| CITY | 7 |
| TELCO | 4 |
| VOLT | 4 |

(4 rows)

**Example: New app users per Nepal day** (sample data: fn-dates)

```sql
SELECT to_date(created_at + 20700000) AS nepal_day, count(*) AS signups
FROM signups
GROUP BY to_date(created_at + 20700000)
ORDER BY nepal_day;
```

Result:

| nepal_day (DATE) | signups (LONG) |
|---|---|
| 2026-09-01 | 3 |
| 2026-09-02 | 2 |
| 2026-09-03 | 3 |
| 2026-09-04 | 1 |
| 2026-09-06 | 1 |

(5 rows)

**Example: No rows: count is 0, sum is NULL** (sample data: sample)

```sql
SELECT count(*) AS rows, count() AS rows_again, sum(close) AS total
FROM ochl_day
WHERE symbol = 'TELCO';
```

Result:

| rows (LONG) | rows_again (LONG) | total (STRING) |
|---|---|---|
| 0 | 0 | NULL |

(1 row)

<a id="count"></a>

## count(x)

Syntax:

```sql
count(x)
```

The number of rows where `x` is **not** NULL.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the value to look at |

- **Returns:** `LONG`.
- **NULL:** rows where `x` is NULL are not counted.
- **Notes:** `count(*) - count(x)` is the number of NULL values.

**Example: Users who gave their city, and users who never logged in** (sample data: query-app)

```sql
SELECT count(*) AS users,
       count(city) AS with_city,
       count(*) - count(last_login) AS never_logged_in
FROM app_users;
```

Result:

| users (LONG) | with_city (LONG) | never_logged_in (LONG) |
|---|---|---|
| 8 | 6 | 2 |

(1 row)

<a id="count-distinct"></a>

## count(DISTINCT x)

Syntax:

```sql
count(DISTINCT x)
```

The number of **different** values of `x`. The same value many times counts once.

- **Returns:** `LONG`.
- **NULL:** NULL is not counted as a value.
- **Notes:** numbers are compared by value, so `1` and `1.0` are one value. `count(DISTINCT x)` and [count_distinct](functions-aggregate.md#count_distinct) are the same. Only `count` accepts `DISTINCT` inside.

**Example: How many different brokers bought each symbol** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades, count(DISTINCT buyer) AS buying_brokers
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | trades (LONG) | buying_brokers (LONG) |
|---|---|---|
| CITY | 11 | 4 |
| COAST | 11 | 5 |
| TELCO | 6 | 5 |
| VOLT | 4 | 3 |

(4 rows)

**Example: NULL is not a value; 1 and 1.0 are the same value**

```sql
SELECT count(*) AS rows, count(x) AS not_null, count(DISTINCT x) AS different
FROM (SELECT NULL AS x UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1.0 UNION ALL SELECT 2) t;
```

Result:

| rows (LONG) | not_null (LONG) | different (LONG) |
|---|---|---|
| 5 | 4 | 2 |

(1 row)

<a id="count_distinct"></a>

## count_distinct

Syntax:

```sql
count_distinct(x)
```

The number of different values of `x`, without NULL. The same as `count(DISTINCT x)`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the value to look at |

- **Returns:** `LONG`.
- **NULL:** NULL is not counted.

**Example: Posts and different writers per forum topic** (sample data: fn-dates)

```sql
SELECT topic, count(*) AS posts, count_distinct(author) AS writers
FROM forum_posts
GROUP BY topic
ORDER BY posts DESC;
```

Result:

| topic (STRING) | posts (LONG) | writers (LONG) |
|---|---|---|
| Market today | 5 | 5 |
| CITY dividend | 3 | 3 |
| Hydro IPOs | 3 | 2 |
| COAST merger | 3 | 3 |

(4 rows)

## sum

Syntax:

```sql
sum(x)
```

The total of all values of `x`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value to add up |

- **Returns:** `LONG` when every value is a whole number, an exact `DECIMAL` when every value is a `DECIMAL` (with the largest scale of them), else `DOUBLE`.
- **NULL:** NULL values are skipped. When there are no values (or all are NULL), the result is `NULL`, not `0`. Write `coalesce(sum(x), 0)` to get `0` ([coalesce](functions-conditional.md#coalesce)); for a `DECIMAL(2)` column write `coalesce(sum(x), CAST(0 AS DECIMAL(2)))`, because a plain `0` is a `LONG`.
- **Notes:** a `LONG` total too big for 64 bits (more than about 9.2e18) is an error: `sum() is out of range` (SQLSTATE `22003`). A `DECIMAL` total is exact up to 38 digits, also past 64 bits; only past that is it an error. It never comes back rounded. For an approximate total add `DOUBLE` values: `sum(x::DOUBLE)`. Text gives an error (`sum needs numbers`). For money, use `DECIMAL(2)` columns: their sum is exact.
- **DOUBLE totals:** a `DOUBLE` total is **compensated** (the Neumaier method): the rounding error of each step is carried along and added back, so the total does not depend on the order of the rows and is as close to the exact total as a `DOUBLE` can be. QuestDB's plain `sum` adds without this, so its last digit can differ: five NEPSE volumes that add up to exactly 55128735 give 55128734.99999999 there. QuestDB's `ksum` and `nsum` give KDB's answer; KDB accepts both names as `sum`.

**Example: Broker buy totals on one day (trade log)** (sample data: sample)

```sql
SELECT buyer, b.name, count(*) AS trades, sum(quantity) AS shares, sum(amount) AS turnover
FROM trade_log f JOIN brokers b ON b.id = f.buyer
WHERE date IN '2026-09-10'
GROUP BY buyer, b.name
ORDER BY turnover DESC;
```

Result:

| buyer (INT) | name (STRING) | trades (LONG) | shares (LONG) | turnover (DOUBLE) |
|---|---|---|---|---|
| 49 | Online Securities | 5 | 1740 | 960370 |
| 45 | Imperial Securities | 5 | 1560 | 695950 |
| 58 | Northgate Securities | 4 | 760 | 260190 |
| 1 | Keystone Securities | 7 | 570 | 239420 |
| 34 | Vision Securities | 3 | 300 | 205450 |

(5 rows)

**Example: Accounting month report: debit and credit per account type (DECIMAL stays exact)** (sample data: query-app)

```sql
SELECT a.type, sum(l.debit) AS debit, sum(l.credit) AS credit
FROM ledger l JOIN accounts a ON a.code = l.account
WHERE l.entry_date IN '2026-09'
GROUP BY a.type
ORDER BY a.type;
```

Result:

| type (STRING) | debit (DECIMAL(2)) | credit (DECIMAL(2)) |
|---|---|---|
| asset | 806350.00 | 323830.00 |
| equity | NULL | 500000.00 |
| expense | 26030.00 | NULL |
| income | NULL | 8550.00 |
| liability | 257500.00 | 257500.00 |

(5 rows)

**Example: No values give NULL; coalesce makes it 0.00** (sample data: query-app)

```sql
SELECT sum(debit) AS debit,
       coalesce(sum(debit), CAST(0 AS DECIMAL(2))) AS debit_or_zero
FROM ledger
WHERE account = 3000;
```

Result:

| debit (STRING) | debit_or_zero (DECIMAL(2)) |
|---|---|
| NULL | 0.00 |

(1 row)

**Example: Check the books: every journal entry must have debits = credits** (sample data: query-app)

```sql
SELECT entry_id, count(*) AS lines, sum(debit) AS debit, sum(credit) AS credit,
       sum(debit) = sum(credit) AS balanced
FROM ledger
GROUP BY entry_id
ORDER BY entry_id;
```

Result:

| entry_id (INT) | lines (LONG) | debit (DECIMAL(2)) | credit (DECIMAL(2)) | balanced (BOOL) |
|---|---|---|---|---|
| 1 | 2 | 500000.00 | 500000.00 | true |
| 2 | 2 | 257500.00 | 257500.00 | true |
| 3 | 2 | 257500.00 | 257500.00 | true |
| 4 | 2 | 1030.00 | 1030.00 | true |
| 5 | 2 | 30000.00 | 30000.00 | true |
| 6 | 2 | 25000.00 | 25000.00 | true |
| 7 | 2 | 6250.00 | 6250.00 | true |
| 8 | 3 | 12600.00 | 12600.00 | true |

(8 rows)

**Example: A DOUBLE total is compensated: exactly 55128735, not 55128734.99999999**

```sql
CREATE TABLE vol (v DOUBLE);
INSERT INTO vol VALUES (15380798.2), (10594146.6), (12320992.8), (6619323.5), (10213473.9);
SELECT sum(v) = 55128735 AS exact, ksum(v) = sum(v) AS same_as_ksum FROM vol;
```

Result:

`CREATE TABLE vol (`

```text
table 'vol' created
```

`INSERT INTO vol VALUES (15380798.2), (10594146.6), (12320992.8), (6619323.5), (10213473.9)`

```text
5 row(s) inserted
```

`SELECT sum(v) = 55128735 AS exact, sum(v) = sum(v) AS same_as_ksum FROM vol`

| exact (BOOL) | same_as_ksum (BOOL) |
|---|---|
| true | true |

(1 row)

**Example: Text cannot be added** (sample data: sample; shows an error)

```sql
SELECT sum(symbol) FROM trade_log;
```

Result:

Error: `line 1, column 8: sum needs numbers, got 'CITY'`

## avg

Syntax:

```sql
avg(x)
```

The average (mean): the sum of the values divided by how many values there are.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value |

- **Returns:** `DOUBLE`, also for `LONG` input. For `DECIMAL` input an exact `DECIMAL` with at least 16 significant digits, as in PostgreSQL: `avg` of `1.50` and `2.50` is `2.0000000000000000`. Use `round(avg(x), 2)` for a report ([round](functions-math.md#round)).
- **NULL:** NULL values are skipped: they do not count as 0. No values give `NULL`.

**Example: Average close and volume per symbol in September** (sample data: sample)

```sql
SELECT symbol, round(avg(close), 2) AS avg_close, round(avg(volume)) AS avg_volume
FROM ochl_day
WHERE time IN '2026-09'
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | avg_close (DOUBLE) | avg_volume (DOUBLE) |
|---|---|---|
| CITY | 500.18 | 109526 |
| COAST | 374.73 | 113784 |
| VOLT | 179.3 | 89164 |

(3 rows)

**Example: NULL is skipped, not counted as 0**

```sql
SELECT avg(x) AS avg, sum(x) / count(*) AS sum_by_all_rows
FROM (SELECT 10 AS x UNION ALL SELECT NULL UNION ALL SELECT 20) t;
```

Result:

| avg (DOUBLE) | sum_by_all_rows (DOUBLE) |
|---|---|
| 15 | 10 |

(1 row)

## min

Syntax:

```sql
min(x)
```

The smallest value. Works for numbers, text (A before B), times and dates, and `BOOL` (`false` before `true`).

- **Returns:** the type of `x`.
- **NULL:** NULL values are skipped. No values give `NULL`.
- **Notes:** values of different kinds (a number and a text) give an error.

**Example: Lowest price and first trade day of each symbol** (sample data: sample)

```sql
SELECT symbol, min(low) AS lowest, min(time) AS first_day
FROM ochl_day
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | lowest (DOUBLE) | first_day (TIMESTAMP) |
|---|---|---|
| CITY | 494.1 | 2025-12-28T00:00:00.000Z |
| COAST | 364.1 | 2025-12-28T00:00:00.000Z |
| VOLT | 167.3 | 2025-12-28T00:00:00.000Z |

(3 rows)

**Example: Text and dates** (sample data: query-app)

```sql
SELECT min(username) AS first_name_a_to_z, min(created_at) AS first_signup, min(last_login) AS oldest_login
FROM app_users;
```

Result:

| first_name_a_to_z (STRING) | first_signup (TIMESTAMP) | oldest_login (TIMESTAMP) |
|---|---|---|
| anita | 2026-01-01T03:15:00.000Z | 2026-08-30T06:15:00.000Z |

(1 row)

## max

Syntax:

```sql
max(x)
```

The biggest value. Works for numbers, text, times and dates, and `BOOL`.

- **Returns:** the type of `x`.
- **NULL:** NULL values are skipped. No values give `NULL`.
- **Notes:** values of different kinds give an error.

**Example: High, low and range of each symbol since 23 August** (sample data: sample)

```sql
SELECT symbol, max(high) AS highest, min(low) AS lowest, round(max(high) - min(low), 2) AS range
FROM ochl_day
WHERE time >= '2026-08-23'
GROUP BY symbol
ORDER BY range DESC;
```

Result:

| symbol (SYMBOL) | highest (DOUBLE) | lowest (DOUBLE) | range (DOUBLE) |
|---|---|---|---|
| COAST | 398.8 | 364.1 | 34.7 |
| VOLT | 192.1 | 167.3 | 24.8 |
| CITY | 517 | 494.1 | 22.9 |

(3 rows)

**Example: The last login of every plan** (sample data: query-app)

```sql
SELECT plan, count(*) AS users, max(last_login) AS latest_login
FROM app_users
GROUP BY plan
ORDER BY plan;
```

Result:

| plan (STRING) | users (LONG) | latest_login (TIMESTAMP) |
|---|---|---|
| admin | 1 | 2026-09-11T04:20:00.000Z |
| free | 4 | 2026-09-09T02:15:00.000Z |
| pro | 3 | 2026-09-11T00:45:00.000Z |

(3 rows)

## first

Syntax:

```sql
first(x)
```

The value of `x` in the **earliest** row. On a time-series table, earliest means the smallest time. `first(open)` is the open price of a candle.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the value to take |

- **Returns:** the type of `x`.
- **NULL:** the earliest row's value, **even when it is NULL**, as in QuestDB. To skip NULLs, use [first_not_null](#first_not_null). No rows give `NULL`.
- **Notes:** the order is the table's time column, not `ORDER BY`. On a relational table (no time column) it is the order of the primary key. When many rows have the **same** time, KDB takes the first in storage order; do not count on which one.
- **Changed 2026-09-25:** before, `first` and `last` skipped NULLs (what `first_not_null` and `last_not_null` do now).

**Example: Open, close and change of each symbol in September** (sample data: sample)

```sql
SELECT symbol, first(open) AS open, last(close) AS close,
       round((last(close) - first(open)) / first(open) * 100, 2) AS change_pct
FROM ochl_day
WHERE time IN '2026-09'
GROUP BY symbol
ORDER BY change_pct DESC;
```

Result:

| symbol (SYMBOL) | open (DOUBLE) | close (DOUBLE) | change_pct (DOUBLE) |
|---|---|---|---|
| VOLT | 171.3 | 191.2 | 11.62 |
| COAST | 367 | 376.1 | 2.48 |
| CITY | 504.9 | 504.9 | 0 |

(3 rows)

**Example: The first post of each thread** (sample data: content-forum)

```sql
SELECT thread_id, first(author) AS started_by, first(created_at) AS started, count(*) AS posts
FROM posts
GROUP BY thread_id
ORDER BY thread_id;
```

Result:

| thread_id (LONG) | started_by (STRING) | started (TIMESTAMP) | posts (LONG) |
|---|---|---|---|
| 1 | ram | 2026-09-01T04:15:00.000Z | 6 |
| 2 | hari | 2026-09-02T03:15:00.000Z | 2 |

(2 rows)

## last

Syntax:

```sql
last(x)
```

The value of `x` in the **latest** row (the biggest time). `last(close)` is the close price of a candle.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the value to take |

- **Returns:** the type of `x`.
- **NULL:** the latest row's value, **even when it is NULL**, as in QuestDB. To skip NULLs, use [last_not_null](#first_not_null).
- **Notes:** same order rules as [first](functions-aggregate.md#first). For the newest **row** per symbol, [LATEST ON](latest-on.md) is faster.

**Example: The last price of every symbol in the live data** (sample data: sample)

```sql
SELECT symbol, last(ltp) AS ltp, last(timestamp) AS at, max(high) AS day_high
FROM live_data
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | ltp (DOUBLE) | at (TIMESTAMP) | day_high (DOUBLE) |
|---|---|---|---|
| CITY | 527.1 | 2026-09-10T09:14:00.000Z | 528.1 |
| COAST | 401.9 | 2026-09-10T09:14:00.000Z | 402.9 |
| TELCO | 897.7 | 2026-09-10T09:14:00.000Z | 898.7 |
| VOLT | 184 | 2026-09-10T09:14:00.000Z | 186.6 |

(4 rows)

**Example: 15-minute candles with SAMPLE BY** (sample data: sample)

```sql
SELECT time, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
SAMPLE BY 15m
LIMIT 4;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-10T05:15:00.000Z | 504.6 | 505.3 | 503.9 | 504.4 | 13210 |
| 2026-09-10T05:30:00.000Z | 504.4 | 506.8 | 503.8 | 506.5 | 11690 |
| 2026-09-10T05:45:00.000Z | 506.5 | 507 | 505.3 | 506.4 | 11270 |
| 2026-09-10T06:00:00.000Z | 506.4 | 506.6 | 504.9 | 505.3 | 10850 |

(4 rows)

<a id="first_not_null"></a>

## first_not_null, last_not_null

Syntax:

```sql
first_not_null(x)
last_not_null(x)
```

The value of `x` in the earliest / latest row where `x` is **not** NULL (QuestDB). Use them when a missing value must not become the answer, for example a candle whose first minute has no open price yet.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the value to take |

- **Returns:** the type of `x`.
- **NULL:** rows where `x` is NULL are skipped. When every value is NULL (or there are no rows), the result is `NULL`.
- **Notes:** same order rules as [first](#first). They work with `GROUP BY`, `SAMPLE BY` and `OVER (...)`.

**Example: first keeps a NULL first row, first_not_null skips it**

Setup:

```sql
CREATE TABLE px (time TIMESTAMP, symbol SYMBOL, open DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO px VALUES ('2026-09-10T05:00:00Z', 'CITY', NULL), ('2026-09-10T05:01:00Z', 'CITY', 512.5),
                      ('2026-09-10T05:02:00Z', 'CITY', 513), ('2026-09-10T05:03:00Z', 'CITY', NULL);
```

```sql
SELECT symbol, first(open), first_not_null(open), last(open), last_not_null(open) FROM px GROUP BY symbol;
```

Result:

| symbol (SYMBOL) | first(open) (DOUBLE) | first_not_null(open) (DOUBLE) | last(open) (DOUBLE) | last_not_null(open) (DOUBLE) |
|---|---|---|---|---|
| CITY | NULL | 512.5 | NULL | 513 |

(1 row)

## median

Syntax:

```sql
median(x)
```

The middle value: half of the values are smaller, half are bigger. With an even number of values, it is the average of the two in the middle. Unlike `avg`, one very big trade does not move the median much.

- **Returns:** `DOUBLE`.
- **NULL:** NULL values are skipped. No values give `NULL`.
- **Notes:** the same as `percentile(x, 0.5)`. KDB keeps all values of a group in memory to find it.

**Example: Typical trade size: median against average** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades, median(quantity) AS median_qty, round(avg(quantity), 1) AS avg_qty
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | trades (LONG) | median_qty (DOUBLE) | avg_qty (DOUBLE) |
|---|---|---|---|
| CITY | 11 | 100 | 220 |
| COAST | 11 | 50 | 279.1 |
| TELCO | 6 | 350 | 461.7 |
| VOLT | 4 | 75 | 100 |

(4 rows)

**Example: Even number of values: the average of the two in the middle**

```sql
SELECT median(x) AS median
FROM (SELECT 1 AS x UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 100) t;
```

Result:

| median (DOUBLE) |
|---|
| 2.5 |

(1 row)

## percentile

Syntax:

```sql
percentile(x, p)
```

The value below which a part `p` of the values lie. `percentile(x, 0.9)` is the value that 90% of the values are at or below. Between two values, KDB goes the right part of the way from one to the other (linear interpolation, like PostgreSQL `percentile_cont`).

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |
| `p` | number | the part, from `0` to `1` (`0.9`). A number **above 1** is read as a percent (`90` means `0.9`) |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values of `x` are skipped. No values give `NULL`.
- **Notes:** `p` below 0 is taken as 0 (the smallest value); a percent above 100 is taken as 100. Careful: `1` means 100%, but `1.5` means **1.5%**. `p` is read once, from the first row. A `p` that is not a number is an error.

**Example: Big trades: 90th percentile of the trade amount per symbol** (sample data: sample)

```sql
SELECT symbol, percentile(amount, 0.9) AS p90_amount, max(amount) AS biggest
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | p90_amount (DOUBLE) | biggest (DOUBLE) |
|---|---|---|
| CITY | 258000 | 258500 |
| COAST | 398000 | 402000 |
| TELCO | 880000 | 881000 |
| VOLT | 31370 | 36800 |

(4 rows)

**Example: 0.9 and 90 are the same; values in between are interpolated**

```sql
SELECT percentile(x, 0.9) AS p90, percentile(x, 90) AS p90_percent, percentile(x, 0.25) AS p25, percentile(x, 0) AS p0, percentile(x, 1) AS p100
FROM (SELECT 10 AS x UNION ALL SELECT 20 UNION ALL SELECT 30 UNION ALL SELECT 40 UNION ALL SELECT 50) t;
```

Result:

| p90 (DOUBLE) | p90_percent (DOUBLE) | p25 (DOUBLE) | p0 (DOUBLE) | p100 (DOUBLE) |
|---|---|---|---|---|
| 46 | 46 | 20 | 10 | 50 |

(1 row)

**Example: p must be a number** (sample data: sample; shows an error)

```sql
SELECT percentile(rate, 'high') FROM trade_log;
```

Result:

Error: `line 1, column 8: percentile needs a number like 0.95`

## vwap

Syntax:

```sql
vwap(price, volume)
```

The **volume-weighted average price**: `sum(price × volume) / sum(volume)`. A trade of 1,000 shares counts 100 times more than a trade of 10 shares. Traders use VWAP as the "fair" average price of a day.

| Argument | Type | Meaning |
|---|---|---|
| `price` | number | price of each trade or candle |
| `volume` | number | how many shares |

- **Returns:** `DOUBLE`.
- **NULL:** a row where `price` or `volume` is NULL is skipped. When the total volume is 0 (or there are no rows), the result is `NULL`.

**Example: VWAP per symbol from the trade log** (sample data: sample)

```sql
SELECT symbol, sum(quantity) AS shares, round(vwap(rate, quantity), 2) AS vwap, round(avg(rate), 2) AS plain_avg
FROM trade_log
WHERE date IN '2026-09-10'
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | shares (LONG) | vwap (DOUBLE) | plain_avg (DOUBLE) |
|---|---|---|---|
| CITY | 910 | 516.3 | 516 |
| COAST | 2850 | 399.77 | 399.28 |
| TELCO | 770 | 880.86 | 880.75 |
| VOLT | 400 | 184.88 | 185 |

(4 rows)

**Example: Hourly VWAP from one-minute candles (Nepal hours)** (sample data: sample)

```sql
SELECT time, round(vwap(close, volume), 2) AS vwap, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10'
SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu';
```

Result:

| time (TIMESTAMP) | vwap (DOUBLE) | volume (DOUBLE) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | 380.44 | 47660 |
| 2026-09-10T06:15:00.000Z | 379.71 | 45870 |
| 2026-09-10T07:15:00.000Z | 377.6 | 43950 |
| 2026-09-10T08:15:00.000Z | 375.67 | 48720 |

(4 rows)

**Example: Both arguments are needed** (sample data: sample; shows an error)

```sql
SELECT vwap(rate) FROM trade_log;
```

Result:

Error: `line 1, column 8: function 'vwap' takes 2 argument(s), got 1`

<a id="twap"></a>

## twap

Syntax:

```sql
twap(price, time)
```

The **time-weighted average price**. Each price counts for the time until the next price. A price that stayed for 2 hours counts twice as much as a price that stayed for 1 hour. Traders use TWAP to judge a price when trades came at uneven times, for example live price snapshots.

| Argument | Type | Meaning |
|---|---|---|
| `price` | number | the price |
| `time` | `TIMESTAMP`, `DATE` or whole number (milliseconds) | when this price started |

- **Returns:** `DOUBLE`.
- **NULL:** a row where `price` or `time` is NULL is skipped. No rows give `NULL`.
- **Notes:**
  - The rows are sorted by `time` first; the order in the table does not matter.
  - The **last** price has no time after it, so it gets no weight (it is only used when it is the only price).
  - When every price has the same time, the result is the plain average.
  - Unlike [vwap](functions-aggregate.md#vwap), the volume does not matter. With prices at even steps (one-minute candles) TWAP is almost the plain average.

**Example: Live prices came at 11:05, 13:00 and 14:59: TWAP against the plain average** (sample data: sample)

```sql
SELECT symbol, round(twap(ltp, timestamp), 2) AS twap, round(avg(ltp), 2) AS plain_avg
FROM live_data
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | twap (DOUBLE) | plain_avg (DOUBLE) |
|---|---|---|
| CITY | 514.32 | 518.57 |
| COAST | 391.01 | 394.63 |
| TELCO | 864.82 | 875.73 |
| VOLT | 184.51 | 184.33 |

(4 rows)

**Example: How it works: 513 for 115 minutes and 515.6 for 119 minutes; 527.1 is the last price** (sample data: sample)

```sql
SELECT timestamp, ltp FROM live_data WHERE symbol = 'CITY' ORDER BY timestamp;
SELECT round((513 * 115 + 515.6 * 119) / 234.0, 2) AS by_hand, round(twap(ltp, timestamp), 2) AS twap
FROM live_data
WHERE symbol = 'CITY';
```

Result:

`SELECT timestamp, ltp FROM live_data WHERE symbol = 'CITY' ORDER BY timestamp`

| timestamp (TIMESTAMP) | ltp (DOUBLE) |
|---|---|
| 2026-09-10T05:20:00.000Z | 513 |
| 2026-09-10T07:15:00.000Z | 515.6 |
| 2026-09-10T09:14:00.000Z | 527.1 |

(3 rows)

`SELECT round((513 * 115 + 515.6 * 119) / 234.0, 2) AS by_hand, round(twap(ltp, timestamp), 2) AS twa`

| by_hand (DOUBLE) | twap (DOUBLE) |
|---|---|
| 514.32 | 514.32 |

(1 row)

**Example: Hourly TWAP of one-minute closes** (sample data: sample)

```sql
SELECT time, round(twap(close, time), 2) AS twap, round(avg(close), 2) AS plain_avg
FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10'
SAMPLE BY 1h
LIMIT 3;
```

Result:

| time (TIMESTAMP) | twap (DOUBLE) | plain_avg (DOUBLE) |
|---|---|---|
| 2026-09-10T05:00:00.000Z | 380.41 | 380.39 |
| 2026-09-10T06:00:00.000Z | 380.32 | 380.31 |
| 2026-09-10T07:00:00.000Z | 378.05 | 378.06 |

(3 rows)

<a id="weighted_avg"></a>

## weighted_avg, wavg

Syntax:

```sql
weighted_avg(x, weight)
wavg(x, weight)
```

The **weighted average**: `sum(x × weight) / sum(weight)`. A row with weight 2 counts twice as much as a row with weight 1. `wavg` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the values |
| `weight` | number | how much each value counts |

- **Returns:** `DOUBLE`.
- **NULL:** a row where `x` or `weight` is NULL is skipped. When the total weight is 0 (or there are no rows), the result is `NULL`.
- **Notes:** with price and volume it is the same as [vwap](functions-aggregate.md#vwap). Use it for other weights: the average buy price of a portfolio (weight = shares), the average interest rate of loans (weight = loan amount).

**Example: Average buy rate of each broker, weighted by the shares bought** (sample data: sample)

```sql
SELECT buyer, count(*) AS trades, sum(quantity) AS shares,
       round(weighted_avg(rate, quantity), 2) AS avg_rate_weighted,
       round(avg(rate), 2) AS avg_rate_plain
FROM trade_log
WHERE symbol = 'CITY'
GROUP BY buyer
ORDER BY buyer;
```

Result:

| buyer (INT) | trades (LONG) | shares (LONG) | avg_rate_weighted (DOUBLE) | avg_rate_plain (DOUBLE) |
|---|---|---|---|---|
| 1 | 5 | 1170 | 515.06 | 515.5 |
| 34 | 1 | 500 | 514.5 | 514.5 |
| 45 | 3 | 530 | 515.94 | 515.33 |
| 49 | 2 | 220 | 517.77 | 516.75 |

(4 rows)

**Example: Average interest rate of three loans**

```sql
SELECT round(wavg(rate_pct, amount), 3) AS weighted_rate, round(avg(rate_pct), 3) AS plain_avg
FROM (SELECT 500000 AS amount, 9.5 AS rate_pct
      UNION ALL SELECT 100000, 12.0
      UNION ALL SELECT 50000, 14.0) loans;
```

Result:

| weighted_rate (DOUBLE) | plain_avg (DOUBLE) |
|---|---|
| 10.231 | 11.833 |

(1 row)

<a id="count_if"></a>

## count_if

Syntax:

```sql
count_if(condition)
```

Counts the rows where the condition is **true**. `count_if(plan = 'pro')` is the number of pro users. It is shorter than `sum(CASE WHEN plan = 'pro' THEN 1 ELSE 0 END)`.

| Argument | Type | Meaning |
|---|---|---|
| `condition` | true/false | a comparison or any true/false expression |

- **Returns:** `LONG`.
- **NULL:** rows where the condition is NULL are not counted. No rows give `0`, not NULL.
- **Notes:** the condition must be true/false: `count_if(plan)` is an error. PostgreSQL writes `count(*) FILTER (WHERE ...)`; KDB has no `FILTER`, use `count_if`.

**Example: App users per city: all, pro, and who logged in since 10 September** (sample data: query-app)

```sql
SELECT city, count(*) AS users,
       count_if(plan = 'pro') AS pro_users,
       count_if(last_login >= '2026-09-10') AS active_users
FROM app_users
GROUP BY city
ORDER BY users DESC, city;
```

Result:

| city (STRING) | users (LONG) | pro_users (LONG) | active_users (LONG) |
|---|---|---|---|
| Kathmandu | 2 | 1 | 1 |
| Pokhara | 2 | 1 | 1 |
| NULL | 2 | 0 | 0 |
| Dharan | 1 | 1 | 1 |
| Lalitpur | 1 | 0 | 1 |

(5 rows)

**Example: Up days of each symbol in the last 5 days (with OVER)** (sample data: sample)

```sql
SELECT time, symbol, open, close,
       count_if(close > open) OVER (PARTITION BY symbol ORDER BY time ROWS 4 PRECEDING) AS up_days_of_5
FROM ochl_day
WHERE time >= '2026-08-30'
ORDER BY symbol, time
LIMIT 8;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | close (DOUBLE) | up_days_of_5 (LONG) |
|---|---|---|---|---|
| 2026-08-30T00:00:00.000Z | CITY | 507.3 | 503.1 | 0 |
| 2026-08-31T00:00:00.000Z | CITY | 502.5 | 505.7 | 1 |
| 2026-09-01T00:00:00.000Z | CITY | 504.9 | 502.4 | 1 |
| 2026-09-02T00:00:00.000Z | CITY | 502.1 | 496.4 | 1 |
| 2026-09-03T00:00:00.000Z | CITY | 497.7 | 497.9 | 2 |
| 2026-09-06T00:00:00.000Z | CITY | 497.4 | 499 | 3 |
| 2026-09-07T00:00:00.000Z | CITY | 497.3 | 498.7 | 3 |
| 2026-09-08T00:00:00.000Z | CITY | 498.2 | 497.5 | 3 |

(8 rows)

**Example: The argument must be a condition** (sample data: query-app; shows an error)

```sql
SELECT count_if(plan) FROM app_users;
```

Result:

Error: `line 1, column 8: count_if: needs a condition (true/false), got 'pro'`

<a id="sum_if"></a>

## sum_if

Syntax:

```sql
sum_if(x, condition)
```

Adds up `x` only in the rows where the condition is **true**. Shorter than `sum(CASE WHEN condition THEN x END)`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value to add |
| `condition` | true/false | which rows to add |

- **Returns:** `LONG` when every added value is a whole number, `DECIMAL` when they are all `DECIMAL` of the same scale (money stays exact), else `DOUBLE`.
- **NULL:** rows where `x` is NULL or the condition is not true are skipped. When no row is added, the result is `NULL` (like `sum`); wrap it in `coalesce(..., 0)` for 0.
- **Notes:** a condition that is not true/false is an error. A whole-number total too big for 64 bits (a `DECIMAL` one past 38 digits) is an error, as for [sum](#sum).

**Example: Money into and out of the bank account, and only the CITY entries** (sample data: query-app)

```sql
SELECT sum(debit) AS money_in, sum(credit) AS money_out,
       sum_if(debit, memo LIKE '%CITY%') AS city_in,
       sum_if(credit, memo LIKE '%CITY%') AS city_out
FROM ledger
WHERE account = 1100;
```

Result:

| money_in (DECIMAL(2)) | money_out (DECIMAL(2)) | city_in (DECIMAL(2)) | city_out (DECIMAL(2)) |
|---|---|---|---|
| 518850.00 | 288530.00 | 18850.00 | 1030.00 |

(1 row)

**Example: Buy and sell turnover of broker 1 on each day** (sample data: sample)

```sql
SELECT date,
       sum_if(amount, buyer = 1) AS bought,
       sum_if(amount, seller = 1) AS sold,
       coalesce(sum_if(amount, buyer = 1), 0) - coalesce(sum_if(amount, seller = 1), 0) AS net
FROM trade_log
GROUP BY date
ORDER BY date;
```

Result:

| date (TIMESTAMP) | bought (DOUBLE) | sold (DOUBLE) | net (DOUBLE) |
|---|---|---|---|
| 2026-09-09T00:00:00.000Z | 515000 | 5150 | 509850 |
| 2026-09-10T00:00:00.000Z | 239420 | 486650 | -247230 |

(2 rows)

<a id="avg_if"></a>

## avg_if

Syntax:

```sql
avg_if(x, condition)
```

The average of `x` over only the rows where the condition is **true**.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |
| `condition` | true/false | which rows to use |

- **Returns:** `DOUBLE`.
- **NULL:** rows where `x` is NULL or the condition is not true are skipped. When no row is left, the result is `NULL`.

**Example: Average volume on up days and on down days** (sample data: sample)

```sql
SELECT symbol,
       round(avg_if(volume, close > open)) AS avg_volume_up_days,
       round(avg_if(volume, close < open)) AS avg_volume_down_days
FROM ochl_day
WHERE time >= '2026-08-23'
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | avg_volume_up_days (DOUBLE) | avg_volume_down_days (DOUBLE) |
|---|---|---|
| CITY | 123828 | 102885 |
| COAST | 95953 | 99090 |
| VOLT | 87421 | 97304 |

(3 rows)

<a id="product"></a>

## product

Syntax:

```sql
product(x)
```

All values multiplied together. Traders use it to **compound** daily returns: a rise of 1% and then 2% is `1.01 × 1.02 = 1.0302`, a growth of 3.02%.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |

- **Returns:** `DOUBLE`. A result too big for a `DOUBLE` is `NULL`.
- **NULL:** NULL values are skipped. No values give `NULL`.
- **Notes:** for a running product on every row, use [cumprod](functions-window.md#cumprod).

**Example: Growth in September: multiply the daily price ratios** (sample data: sample)

```sql
SELECT symbol, count(ratio) AS days, round(product(ratio), 4) AS growth
FROM (SELECT symbol, close / lag(close) OVER (PARTITION BY symbol ORDER BY time) AS ratio
      FROM ochl_day
      WHERE time >= '2026-09-01') t
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | days (LONG) | growth (DOUBLE) |
|---|---|---|
| CITY | 7 | 1.005 |
| COAST | 7 | 1.0237 |
| VOLT | 7 | 1.1314 |

(3 rows)

**Example**

```sql
SELECT product(x) AS product FROM (SELECT 2 AS x UNION ALL SELECT 3 UNION ALL SELECT NULL UNION ALL SELECT 4) t;
```

Result:

| product (DOUBLE) |
|---|
| 24 |

(1 row)

<a id="bool_and"></a>

## bool_and, every

Syntax:

```sql
bool_and(condition)
every(condition)
```

`true` when the condition is true in **every** row, else `false`. `every` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `condition` | true/false | the check for each row |

- **Returns:** `BOOLEAN`.
- **NULL:** NULL values are skipped. No values give `NULL`.
- **Notes:** the argument must be true/false: `bool_and(plan)` is an error.

**Example: Did every user log in? Is every email good? Is there an admin?** (sample data: query-app)

```sql
SELECT bool_and(last_login IS NOT NULL) AS all_logged_in,
       every(email LIKE '%@%') AS all_emails_have_at,
       bool_or(plan = 'admin') AS has_admin
FROM app_users;
```

Result:

| all_logged_in (BOOL) | all_emails_have_at (BOOL) | has_admin (BOOL) |
|---|---|---|
| false | true | true |

(1 row)

**Example: Did the share close above its open on every day of the week?** (sample data: sample)

```sql
SELECT symbol, bool_and(close > open) AS up_every_day, bool_or(close > open) AS up_some_day
FROM ochl_day
WHERE time >= '2026-09-06'
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | up_every_day (BOOL) | up_some_day (BOOL) |
|---|---|---|
| CITY | false | true |
| COAST | false | true |
| VOLT | false | true |

(3 rows)

<a id="bool_or"></a>

## bool_or

Syntax:

```sql
bool_or(condition)
```

`true` when the condition is true in **at least one** row, else `false`.

| Argument | Type | Meaning |
|---|---|---|
| `condition` | true/false | the check for each row |

- **Returns:** `BOOLEAN`.
- **NULL:** NULL values are skipped. No values give `NULL`.
- **Notes:** see the examples of [bool_and](functions-aggregate.md#bool_and).

**Example: Which brokers made a trade of 1,000 shares or more?** (sample data: sample)

```sql
SELECT buyer, count(*) AS trades, bool_or(quantity >= 1000) AS has_big_trade
FROM trade_log
GROUP BY buyer
ORDER BY buyer;
```

Result:

| buyer (INT) | trades (LONG) | has_big_trade (BOOL) |
|---|---|---|
| 1 | 9 | false |
| 34 | 5 | false |
| 45 | 6 | true |
| 49 | 6 | true |
| 58 | 6 | true |

(5 rows)

<a id="arg_max"></a>

## arg_max, argmax, max_by

Syntax:

```sql
arg_max(value, by)
argmax(value, by)
max_by(value, by)
```

The `value` from the row where `by` is **biggest**. `arg_max(time, close)` answers "on which day was the close highest?". `max(close)` only gives the highest close, not its day. `argmax` and `max_by` are the same function.

| Argument | Type | Meaning |
|---|---|---|
| `value` | any type | what to give back |
| `by` | number, text or time | what to find the biggest of |

- **Returns:** the type of `value`.
- **NULL:** rows where `by` is NULL are skipped. When the best row's `value` is NULL, the result is NULL. No rows give `NULL`.
- **Notes:** when several rows share the biggest `by`, the first one in time order wins.

**Example: The day of the highest close and of the lowest close** (sample data: sample)

```sql
SELECT symbol,
       max(close) AS highest_close, arg_max(time, close) AS highest_day,
       min(close) AS lowest_close, arg_min(time, close) AS lowest_day
FROM ochl_day
WHERE time >= '2026-08-23'
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | highest_close (DOUBLE) | highest_day (TIMESTAMP) | lowest_close (DOUBLE) | lowest_day (TIMESTAMP) |
|---|---|---|---|---|
| CITY | 513.3 | 2026-08-25T00:00:00.000Z | 496.4 | 2026-09-02T00:00:00.000Z |
| COAST | 391 | 2026-08-23T00:00:00.000Z | 367.1 | 2026-08-27T00:00:00.000Z |
| VOLT | 191.2 | 2026-09-10T00:00:00.000Z | 169 | 2026-09-01T00:00:00.000Z |

(3 rows)

**Example: The user who logged in last, and the newest user's plan** (sample data: query-app)

```sql
SELECT max_by(username, last_login) AS last_seen_user,
       argmax(plan, created_at) AS newest_users_plan
FROM app_users;
```

Result:

| last_seen_user (STRING) | newest_users_plan (STRING) |
|---|---|
| bikash | free |

(1 row)

<a id="arg_min"></a>

## arg_min, argmin, min_by

Syntax:

```sql
arg_min(value, by)
argmin(value, by)
min_by(value, by)
```

The `value` from the row where `by` is **smallest**. `arg_min(username, created_at)` is the first user who signed up. `argmin` and `min_by` are the same function.

| Argument | Type | Meaning |
|---|---|---|
| `value` | any type | what to give back |
| `by` | number, text or time | what to find the smallest of |

- **Returns:** the type of `value`.
- **NULL:** rows where `by` is NULL are skipped. No rows give `NULL`.
- **Notes:** when several rows share the smallest `by`, the first one in time order wins. See also the example of [arg_max](functions-aggregate.md#arg_max).

**Example: First user of each plan, and the cheapest trade of each symbol** (sample data: sample, query-app)

```sql
SELECT plan, arg_min(username, created_at) AS first_user FROM app_users GROUP BY plan ORDER BY plan;
SELECT symbol, min(rate) AS lowest_rate, min_by(transaction_id, rate) AS trade, argmin(buyer, rate) AS buyer
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

`SELECT plan, arg_min(username, created_at) AS first_user FROM app_users GROUP BY plan ORDER BY plan`

| plan (STRING) | first_user (STRING) |
|---|---|
| admin | bikash |
| free | sita |
| pro | ram |

(3 rows)

`SELECT symbol, min(rate) AS lowest_rate, min_by(transaction_id, rate) AS trade, argmin(buyer, rate) `

| symbol (SYMBOL) | lowest_rate (DOUBLE) | trade (LONG) | buyer (LONG) |
|---|---|---|---|
| CITY | 513 | 100003 | 1 |
| COAST | 398 | 100013 | 58 |
| TELCO | 878 | 100021 | 1 |
| VOLT | 184 | 100011 | 1 |

(4 rows)

<a id="string_agg"></a>

## string_agg

Syntax:

```sql
string_agg(text, separator)
```

Joins the values of many rows into one text, with `separator` between them: `'ram, hari_99'`. Useful for a short list per group in a report.

| Argument | Type | Meaning |
|---|---|---|
| `text` | any type | the value of each row (numbers and times are written as text) |
| `separator` | text | what goes between two values, like `', '` |

- **Returns:** `STRING`.
- **NULL:** NULL values are skipped. No values give `NULL`. A NULL separator joins without anything between.
- **Notes:**
  - The values come in the order of the rows: time order for a time-series table, else the order the rows come in. `string_agg(x, ',' ORDER BY x)` is not supported: sort the rows in a subquery first.
  - Both arguments are needed; [listagg](functions-aggregate.md#listagg) has `','` as the default.

**Example: Usernames per city** (sample data: query-app)

```sql
SELECT city, count(*) AS users, string_agg(username, ', ') AS usernames
FROM app_users
GROUP BY city
ORDER BY city;
```

Result:

| city (STRING) | users (LONG) | usernames (STRING) |
|---|---|---|
| Dharan | 1 | gita |
| Kathmandu | 2 | ram, hari_99 |
| Lalitpur | 1 | bikash |
| Pokhara | 2 | sita, suman |
| NULL | 2 | anita, test_user |

(5 rows)

**Example: The trades of VOLT on each day, in one line** (sample data: sample)

```sql
SELECT date, string_agg(quantity || ' @ ' || rate, ' | ') AS trades
FROM trade_log
WHERE symbol = 'VOLT'
GROUP BY date
ORDER BY date;
```

Result:

| date (TIMESTAMP) | trades (STRING) |
|---|---|
| 2026-09-10T00:00:00.000Z | 50 @ 184 \| 200 @ 184 \| 50 @ 185 \| 100 @ 187 |

(1 row)

**Example: Sort the rows in a subquery to choose the order** (sample data: sample)

```sql
SELECT string_agg(symbol, ' > ') AS biggest_first
FROM (SELECT symbol, sum(amount) AS turnover FROM trade_log GROUP BY symbol ORDER BY turnover DESC) t;
```

Result:

| biggest_first (STRING) |
|---|
| TELCO > CITY > COAST > VOLT |

(1 row)

<a id="listagg"></a>

## listagg

Syntax:

```sql
listagg(text)
listagg(text, separator)
```

The same as [string_agg](functions-aggregate.md#string_agg), but the separator is optional: without it, the values are joined with `','`. The name comes from Oracle and Snowflake.

| Argument | Type | Meaning |
|---|---|---|
| `text` | any type | the value of each row |
| `separator` | text | what goes between two values; default `','` |

- **Returns:** `STRING`.
- **NULL:** NULL values are skipped. No values give `NULL`.

**Example: Symbols per sector** (sample data: sample)

```sql
SELECT sector, listagg(symbol) AS symbols, listagg(symbol, ' / ') AS with_slash
FROM securities
GROUP BY sector
ORDER BY sector;
```

Result:

| sector (STRING) | symbols (STRING) | with_slash (STRING) |
|---|---|---|
| Banking | CITY,COAST | CITY / COAST |
| Energy | VOLT | VOLT |
| Investment | ACME | ACME |
| Telecom | TELCO | TELCO |

(4 rows)

<a id="array_agg"></a>

## array_agg, json_agg, jsonb_agg

Syntax:

```sql
array_agg(x)
json_agg(x)
jsonb_agg(x)
```

Collects the values of many rows into one **JSON array**: `[513,515.6,527.1]`. An app can read the array in one piece, for example the points of a small chart. `json_agg` and `jsonb_agg` are the same function; Postgres clients get `jsonb_agg` as PostgreSQL's `jsonb` type (`[513, 515.6, 527.1]`).

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the value of each row |

- **Returns:** `JSON`. Numbers stay numbers, text and times become JSON text (`"..."`).
- **NULL:** NULL values are **kept** as `null` in the array. No rows give `NULL`.
- **Notes:** the values come in the order of the rows (time order for a time-series table). Read the array with the [JSON functions](functions-json.md).

**Example: The live prices of each symbol as a JSON array, for a sparkline chart** (sample data: sample)

```sql
SELECT symbol, array_agg(ltp) AS prices
FROM live_data
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | prices (DOUBLE[]) |
|---|---|
| CITY | [513,515.6,527.1] |
| COAST | [390.6,391.4,401.9] |
| TELCO | [860.5,869,897.7] |
| VOLT | [184,185,184] |

(4 rows)

**Example: NULL values stay in the array** (sample data: query-app)

```sql
SELECT plan, json_agg(full_name) AS names, array_agg(id) AS ids
FROM app_users
GROUP BY plan
ORDER BY plan;
```

Result:

| plan (STRING) | names (JSON) | ids (INT[]) |
|---|---|---|
| admin | ["Bikash Shrestha"] | [5] |
| free | ["Sita Karki","Hari Thapa","Anita Magar",null] | [2,3,6,8] |
| pro | ["Ram Sharma","Gita Rai","Suman Gurung"] | [1,4,7] |

(3 rows)

<a id="json_object_agg"></a>

## json_object_agg, jsonb_object_agg

Syntax:

```sql
json_object_agg(key, value)
jsonb_object_agg(key, value)
```

Collects the rows into one **JSON object**: the key of each row, and its value. `{"CITY":513,"COAST":287.5}`.

| Argument | Type | Meaning |
|---|---|---|
| `key` | any type but JSON | the key; a number becomes text (`1` gives `"1"`) |
| `value` | any type | its value; `JSON` stays JSON |

- **Returns:** `JSON`. `jsonb_object_agg` keeps each key once, with the **last** value given; `json_object_agg` keeps every pair. Postgres clients get `jsonb_object_agg` as `jsonb` (`{"a": 1, "b": 2}`, keys in `jsonb` order).
- **NULL:** a `NULL` value becomes JSON `null`. A `NULL` key is an error (SQLSTATE `22023`), as in PostgreSQL. No rows give `NULL`.
- **Notes:** `ORDER BY` inside the call sets the order of the keys: `jsonb_object_agg(k, v ORDER BY k)`. PostgreSQL writes `json_object_agg` as `{ "a" : 1 }`; KDB keeps JSON compact: `{"a":1}`.

**Example: Prices by symbol in one object (a symbol seen twice keeps its last row)** (sample data: sample)

```sql
SELECT jsonb_object_agg(symbol, ltp ORDER BY symbol) AS prices
FROM live_data;
```

Result:

| prices (JSON) |
|---|
| {"CITY":527.1,"COAST":401.9,"TELCO":897.7,"VOLT":184} |

(1 row)
