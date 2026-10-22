# 5. Queries

- Category: Tutorial

## What you will learn

- `SELECT` with `WHERE`, `ORDER BY`, `GROUP BY` and the special time filters.
- Candles with `SAMPLE BY` (1m, 15m, 1h in Nepal time, 1d, Sunday weeks, months), `LATEST ON` and joins.
- Indicators (`sma`, `ema`, `rsi`, `atr`, ...), window functions, views, and a cookbook of market-data queries.

The examples use the database `market` with the **fresh** sample data (load it again if you ran chapter 4). Each example is a file in `examples/05-queries/`.

## The order KDB works in

A query is written in this order:

```sql
SELECT ... FROM ... [JOIN ...] WHERE ... [LATEST ON ...] [SAMPLE BY ...] [GROUP BY ...] [HAVING ...]
[UNION ALL SELECT ...] [ORDER BY ...] [LIMIT n [OFFSET m]]
```

KDB runs it in this order:

| Step | Part | What happens |
|---|---|---|
| 1 | `FROM`, `JOIN` | Read the tables |
| 2 | `WHERE` | Keep only matching rows. A time condition skips whole partitions. |
| 3 | `LATEST ON` | Keep the newest row per group |
| 4 | `SAMPLE BY` / `GROUP BY` | Make groups, compute `sum`, `max`, ... |
| 5 | `HAVING` | Keep only matching groups |
| 6 | window functions | `sma`, `lag`, `row_number`, ... |
| 7 | `SELECT` list, `DISTINCT` | Compute the output columns |
| 8 | `UNION ALL` | Add rows of the next query |
| 9 | `ORDER BY`, `LIMIT`, `OFFSET` | Sort and cut |

## SELECT basics

```sql
SELECT * FROM brokers;

SELECT symbol, close,
       round(high - low, 2) AS day_range,
       round((close - open) / open * 100, 2) AS change_pct
FROM ochl_day
WHERE time IN '2026-09-10';
```

```text
id | name               
---+--------------------
 1 | Keystone Securities 
34 | Vision Securities  
45 | Imperial Securities
49 | Online Securities  
58 | Northgate Securities 
(5 rows, 0.3 ms)

symbol | close | day_range | change_pct
-------+-------+-----------+-----------
CITY   | 504.9 |       6.3 |       0.06
COAST  | 376.1 |       8.8 |      -1.05
VOLT   | 191.2 |       7.9 |       3.02
(3 rows, 0.2 ms)
```

- `AS name` gives a column a name. `AS` is optional: `close c` also works. So a **missing comma** (`symbol close`) is not an error: it names the column `close`.
- `/` always gives a decimal result: `7 / 2` is `3.5`.
- Without `round()`, `high - low` can show `6.30000000000001`. That is normal for DOUBLE.

## WHERE

```sql
SELECT time, symbol, close FROM ochl_day
WHERE symbol IN ('CITY', 'VOLT') AND close > 190 AND time IN '2026-09';

SELECT symbol, name FROM securities WHERE name LIKE '%Bank%';

SELECT time, symbol, close FROM ochl_day
WHERE symbol = 'COAST' AND time BETWEEN '2026-09-07' AND '2026-09-09';
```

```text
time                     | symbol | close
-------------------------+--------+------
2026-09-01T00:00:00.000Z | CITY   | 502.4
2026-09-02T00:00:00.000Z | CITY   | 496.4
2026-09-03T00:00:00.000Z | CITY   | 497.9
2026-09-06T00:00:00.000Z | CITY   |   499
2026-09-07T00:00:00.000Z | CITY   | 498.7
2026-09-08T00:00:00.000Z | CITY   | 497.5
2026-09-09T00:00:00.000Z | CITY   | 504.6
2026-09-10T00:00:00.000Z | CITY   | 504.9
2026-09-10T00:00:00.000Z | VOLT   | 191.2
(9 rows, 0.2 ms)

symbol | name                 
-------+----------------------
CITY   | City Bank Limited   
COAST  | Coastal Bank Limited
(2 rows, 0.1 ms)

time                     | symbol | close
-------------------------+--------+------
2026-09-07T00:00:00.000Z | COAST  | 379.2
2026-09-08T00:00:00.000Z | COAST  | 377.2
2026-09-09T00:00:00.000Z | COAST  | 380.1
(3 rows, 0.0 ms)
```

| Condition | Meaning |
|---|---|
| `=`, `!=` or `<>`, `<`, `<=`, `>`, `>=` | compare |
| `a AND b`, `a OR b`, `NOT a` | combine. Use `( )` when you mix AND and OR. |
| `x IN (1, 2, 3)` / `x NOT IN (...)` | one of a list |
| `x BETWEEN a AND b` | `a <= x <= b` (both ends included) |
| `x LIKE 'CI%'` | text pattern: `%` = any text, `_` = one character |
| `x IS NULL` / `x IS NOT NULL` | no value / has a value |
| `time IN '2026'` | the whole year 2026 (UTC) |
| `time IN '2026-09'` | the whole month (UTC) |
| `time IN '2026-09-10'` | the whole day (UTC) |
| `time IN '2026-09-10T11'` | that hour (UTC) |

- A text like `'2026-09-07'` compared with a time column is read as a time.
- `BETWEEN '2026-09-07' AND '2026-09-09'` ends at `2026-09-09T00:00:00`. For whole days, use `time >= '2026-09-07' AND time < '2026-09-10'`.
- For Nepal times, add `+05:45` (chapter 4).
- `NULL` never matches `=`. Use `IS NULL`.

## ORDER BY, LIMIT, OFFSET

```sql
SELECT time, symbol, volume FROM ochl_day ORDER BY volume DESC LIMIT 3;

SELECT time, symbol, volume FROM ochl_day ORDER BY volume DESC LIMIT 3 OFFSET 3;
```

```text
time                     | symbol | volume
-------------------------+--------+-------
2026-09-09T00:00:00.000Z | COAST  | 186330
2026-09-10T00:00:00.000Z | COAST  | 186200
2026-09-10T00:00:00.000Z | CITY   | 183040
(3 rows, 0.3 ms)

time                     | symbol | volume
-------------------------+--------+-------
2026-09-09T00:00:00.000Z | CITY   | 182390
2026-08-31T00:00:00.000Z | CITY   | 159240
2026-09-03T00:00:00.000Z | VOLT   | 145930
(3 rows, 0.1 ms)
```

- `ASC` (small first) is the default. `DESC` = big first.
- `ORDER BY 2` sorts by the second output column.
- `NULLS FIRST` / `NULLS LAST` choose where NULL goes.
- Without ORDER BY, time-series rows come sorted by partition, then by `SORT BY`. Do not depend on it: add ORDER BY when order matters.

## GROUP BY and aggregates

```sql
SELECT symbol,
       count(*)    AS days,
       min(low)    AS lowest,
       max(high)   AS highest,
       round(avg(close), 2) AS avg_close,
       sum(volume) AS total_volume
FROM ochl_day
WHERE time IN '2026-09'
GROUP BY symbol
ORDER BY total_volume DESC;
```

```text
symbol | days | lowest | highest | avg_close | total_volume
-------+------+--------+---------+-----------+-------------
COAST  |    8 |  364.1 |   398.8 |    374.73 |       910270
CITY   |    8 |  494.1 |   512.4 |    500.18 |       876210
VOLT   |    8 |  167.3 |   192.1 |     179.3 |       713310
(3 rows, 0.3 ms)
```

Aggregates: `count(*)`, `count(x)`, `count(DISTINCT x)`, `sum`, `avg`, `min`, `max`, `first`, `last`, `median`, `percentile(x, 0.9)`, `stddev`, `variance`, `vwap(price, volume)` and more (chapter 11).

`first(x)` and `last(x)` use the **time order** of the rows. `first(open)` is the open of the earliest row.

A `GROUP BY` with very many groups still works. When the groups need more than half of the memory for results, KDB writes some of them to temporary files and adds them up at the end. The result is the same, only slower. `kdb serve` stops a query with more than 5,000,000 groups (`--max-groups`, chapter 21).

### The implicit GROUP BY rule

Like QuestDB, KDB does not need GROUP BY. **Every column that is not inside an aggregate becomes a group key.**

```sql
-- No GROUP BY: symbol is not inside an aggregate, so KDB groups by symbol.
SELECT symbol, max(high) AS highest FROM ochl_day WHERE time IN '2026-09';
```

```text
symbol | highest
-------+--------
CITY   |   512.4
COAST  |   398.8
VOLT   |   192.1
(3 rows, 0.3 ms)
```

In normal SQL this would be an error. Writing `GROUP BY symbol` gives the same result and is clearer for readers.

### HAVING

`HAVING` filters groups (WHERE filters rows).

```sql
SELECT symbol, sum(quantity) AS shares, count(*) AS trades
FROM trade_log
WHERE date IN '2026-09-10'
GROUP BY symbol
HAVING sum(quantity) >= 800
ORDER BY shares DESC;
```

```text
symbol | shares | trades
-------+--------+-------
COAST  |   2850 |      9
CITY   |    910 |      7
(2 rows, 0.4 ms)
```

## SAMPLE BY: candles

`SAMPLE BY interval` puts rows into time buckets. It works on time-series tables. The time column in the output is the **start** of each bucket. Other plain columns (like `symbol`) become group keys, as above.

Intervals: `1s`, `1m` (minute), `5m`, `15m`, `1h`, `1d`, `1w` (week), `1M` (month, capital M), `1y`.

### 15-minute candles

```sql
SELECT time,
       first(open)  AS open,
       max(high)    AS high,
       min(low)     AS low,
       last(close)  AS close,
       sum(volume)  AS volume
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
SAMPLE BY 15m
LIMIT 4;
```

```text
time                     | open  | high  | low   | close | volume
-------------------------+-------+-------+-------+-------+-------
2026-09-10T05:15:00.000Z | 504.6 | 505.3 | 503.9 | 504.4 |  13210
2026-09-10T05:30:00.000Z | 504.4 | 506.8 | 503.8 | 506.5 |  11690
2026-09-10T05:45:00.000Z | 506.5 |   507 | 505.3 | 506.4 |  11270
2026-09-10T06:00:00.000Z | 506.4 | 506.6 | 504.9 | 505.3 |  10850
(4 rows, 1.0 ms)
```

05:15 UTC is 11:00 Nepal time. For 1m, 5m and 15m, UTC buckets and Nepal buckets are the same.

### 1-hour candles: use TIME ZONE

Without a time zone, hours start at the full **UTC** hour. The sample market opens at 05:15 UTC, so you get a small 45-minute candle, three full ones, and a 15-minute one:

```sql
SELECT time, first(open) AS open, last(close) AS close, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
SAMPLE BY 1h;
```

```text
time                     | open  | close | minutes
-------------------------+-------+-------+--------
2026-09-10T05:00:00.000Z | 504.6 | 506.4 |      45
2026-09-10T06:00:00.000Z | 506.4 | 501.2 |      60
2026-09-10T07:00:00.000Z | 501.2 | 502.6 |      60
2026-09-10T08:00:00.000Z | 502.6 |   505 |      60
2026-09-10T09:00:00.000Z |   505 | 504.9 |      15
(5 rows, 0.8 ms)
```

With `TIME ZONE 'Asia/Kathmandu'`, buckets follow the Nepal clock: four clean candles, 11:00, 12:00, 13:00 and 14:00 NPT.

```sql
SELECT time,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu';
```

```text
time                     | open  | high  | low   | close | volume | minutes
-------------------------+-------+-------+-------+-------+--------+--------
2026-09-10T05:15:00.000Z | 504.6 |   507 | 503.8 | 505.3 |  47020 |      60
2026-09-10T06:15:00.000Z | 505.3 | 506.6 | 500.7 | 502.7 |  41230 |      60
2026-09-10T07:15:00.000Z | 502.7 | 504.1 | 501.5 | 502.6 |  46180 |      60
2026-09-10T08:15:00.000Z | 502.6 |   507 | 502.2 | 504.9 |  48610 |      60
(4 rows, 0.7 ms)
```

The bucket times are still shown in UTC (`05:15Z` = 11:00 NPT).

Options of SAMPLE BY (any order, after the interval):

| Option | Meaning |
|---|---|
| `TIME ZONE 'Asia/Kathmandu'` | Buckets follow that clock. Also `'+05:45'`, `'UTC'`, `'Asia/Kolkata'` and a few more fixed zones. Zones with daylight saving (like `'Europe/London'`) are refused. |
| `WITH OFFSET '+00:15'` | Moves bucket starts by that amount. The sign (`+` or `-`) is needed. |
| `ALIGN TO CALENDAR` | Buckets on the clock (the default). |
| `ALIGN TO FIRST OBSERVATION` | Buckets start at the first row's time. Not with months or years. |
| `WEEK START SUNDAY` / `MONDAY` | For `1w`: which day starts the week. Default: Monday. |
| `FILL(NONE / NULL / PREV / LINEAR / value)` | What to do with empty buckets (see below). |

### Daily candles from minute candles

```sql
-- Daily candles made from minute candles.
SELECT time, symbol,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume
FROM ochl_minutes
SAMPLE BY 1d
ORDER BY symbol, time;
```

```text
time                     | symbol | open  | high  | low   | close | volume
-------------------------+--------+-------+-------+-------+-------+-------
2026-09-09T00:00:00.000Z | CITY   |   512 | 512.4 |   504 | 504.6 | 182390
2026-09-10T00:00:00.000Z | CITY   | 504.6 |   507 | 500.7 | 504.9 | 183040
2026-09-09T00:00:00.000Z | COAST  |   398 | 398.8 | 379.2 | 380.1 | 186330
2026-09-10T00:00:00.000Z | COAST  | 380.1 |   382 | 373.2 | 376.1 | 186200
(4 rows, 1.0 ms)
```

Without TIME ZONE the day bucket is stamped `00:00Z`, like the rows in `ochl_day`. With `TIME ZONE 'Asia/Kathmandu'` the bucket starts at Nepal midnight, which is shown as `18:15Z` of the day before. The trading hours are inside the same day either way.

### Weekly candles: Sunday to Thursday

The sample market has a Sunday-to-Thursday trading week (as on some exchanges). Use `WEEK START SUNDAY`:

```sql
SELECT time, symbol,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume
FROM ochl_day
WHERE symbol = 'CITY' AND time IN '2026'
SAMPLE BY 1w WEEK START SUNDAY;
```

```text
time                     | symbol | open  | high  | low   | close | volume
-------------------------+--------+-------+-------+-------+-------+-------
2026-08-23T00:00:00.000Z | CITY   |   505 |   517 |   502 | 505.9 | 601770
2026-08-30T00:00:00.000Z | CITY   | 507.3 | 511.2 | 494.1 | 497.9 | 538130
2026-09-06T00:00:00.000Z | CITY   | 497.4 | 512.4 |   495 | 504.9 | 591860
(3 rows, 0.3 ms)
```

2026-08-23, 08-30 and 09-06 are Sundays.

### Monthly candles

`1M` is a calendar month (capital `M`; small `m` is minutes).

```sql
SELECT time, symbol, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close
FROM ochl_day
WHERE symbol = 'VOLT'
SAMPLE BY 1M;
```

```text
time                     | symbol | open  | high  | low   | close
-------------------------+--------+-------+-------+-------+------
2025-12-01T00:00:00.000Z | VOLT   | 187.7 | 199.7 | 187.5 | 194.3
2026-08-01T00:00:00.000Z | VOLT   | 182.4 | 183.6 | 170.6 | 172.6
2026-09-01T00:00:00.000Z | VOLT   | 171.3 | 192.1 | 167.3 | 191.2
(3 rows, 0.6 ms)
```

Months with no rows (January to July 2026 here) are not shown. Use FILL if you need them.

### FILL: empty buckets

COAST had no trades from 12:31 to 12:34 Nepal time. Without FILL, those minutes are missing:

```sql
-- COAST had no trades from 12:31 to 12:34 Nepal time.
SELECT time, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST'
  AND time >= '2026-09-10T12:30:00+05:45' AND time < '2026-09-10T12:36:00+05:45'
SAMPLE BY 1m;

SELECT time, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST'
  AND time >= '2026-09-10T12:30:00+05:45' AND time < '2026-09-10T12:36:00+05:45'
SAMPLE BY 1m FILL(PREV);
```

```text
time                     | close | volume
-------------------------+-------+-------
2026-09-10T06:45:00.000Z | 380.2 |    620
2026-09-10T06:50:00.000Z | 379.8 |    800
(2 rows, 0.7 ms)

time                     | close | volume
-------------------------+-------+-------
2026-09-10T06:45:00.000Z | 380.2 |    620
2026-09-10T06:46:00.000Z | 380.2 |    620
2026-09-10T06:47:00.000Z | 380.2 |    620
2026-09-10T06:48:00.000Z | 380.2 |    620
2026-09-10T06:49:00.000Z | 380.2 |    620
2026-09-10T06:50:00.000Z | 379.8 |    800
(6 rows, 0.3 ms)
```

| FILL | Empty bucket gets | Example value for close |
|---|---|---|
| (none) or `FILL(NONE)` | no row | - |
| `FILL(NULL)` | NULL | `NULL` |
| `FILL(PREV)` | the values of the bucket before | `380.2` |
| `FILL(LINEAR)` | a value on the straight line between the neighbors | `380.12`, `380.04`, ... |
| `FILL(0)` | that constant | `0` |

FILL uses one rule for **every** aggregate column. `FILL(PREV)` also copies the volume (620 above), which is wrong for volume. If you need "close = previous, volume = 0", get the rows with `FILL(NULL)` and handle them in your program, or run two queries. The outputs of FILL(NULL), LINEAR and 0 are in `examples/05-queries/14-fill-other.out`.

FILL only fills between the first and the last bucket that have data.

## LATEST ON: the newest row per symbol

```sql
SELECT symbol, ltp, pct_change, timestamp
FROM live_data
LATEST ON timestamp PARTITION BY symbol
ORDER BY pct_change DESC;
```

```text
symbol | ltp   | pct_change | timestamp               
-------+-------+------------+-------------------------
CITY   | 527.1 |       2.71 | 2026-09-10T09:14:00.000Z
TELCO  | 897.7 |        1.9 | 2026-09-10T09:14:00.000Z
COAST  | 401.9 |        0.7 | 2026-09-10T09:14:00.000Z
VOLT   |   184 |      -0.86 | 2026-09-10T09:14:00.000Z
(4 rows, 0.2 ms)
```

- `LATEST ON <time column> PARTITION BY <columns>` keeps the row with the biggest time for each group.
- WHERE runs **before** LATEST ON. `WHERE timestamp >= '2026-09-10'` gives "the newest row of today".
- LATEST ON works on one table (no joins).

## JOIN

```sql
SELECT f.transaction_id, f.symbol, b.name AS buyer, s.name AS seller, f.quantity, f.rate, f.amount
FROM trade_log f
JOIN brokers b ON f.buyer = b.id
JOIN brokers s ON f.seller = s.id
WHERE f.date IN '2026-09-10'
ORDER BY f.amount DESC
LIMIT 5;
```

```text
transaction_id | symbol | buyer               | seller              | quantity | rate | amount
---------------+--------+---------------------+---------------------+----------+------+-------
        100017 | TELCO  | Online Securities   | Vision Securities   |      500 |  881 | 440500
        100031 | COAST  | Imperial Securities | Northgate Securities |     1000 |  402 | 402000
        100015 | COAST  | Online Securities   | Imperial Securities |     1000 |  398 | 398000
        100018 | CITY   | Imperial Securities | Keystone Securities |      500 |  516 | 258000
        100023 | COAST  | Northgate Securities | Keystone Securities |      500 |  399 | 199500
(5 rows, 0.4 ms)
```

- `f`, `b` and `s` are short names (aliases) for the tables. The same table (`brokers`) can be joined twice with two aliases.
- When a column name is in two tables, write `table.column` (for example `f.symbol`).

| Join | Rows you get |
|---|---|
| `JOIN` (or `INNER JOIN`) | only rows that match on both sides |
| `LEFT JOIN` (or `LEFT OUTER JOIN`) | all rows of the left table; NULL when the right side has no match |
| `CROSS JOIN` | every left row with every right row (careful: it can be huge) |
| `ASOF JOIN` | for each left row, the last right row at or before its time |

`LEFT JOIN`: every security, also the ones without trades:

```sql
SELECT s.symbol, count(f.transaction_id) AS trades
FROM securities s
LEFT JOIN trade_log f ON f.symbol = s.symbol
GROUP BY s.symbol
ORDER BY trades DESC, s.symbol;
```

```text
symbol | trades
-------+-------
CITY   |     11
COAST  |     11
TELCO  |      6
VOLT   |      4
ACME   |      0
(5 rows, 0.6 ms)
```

### ASOF JOIN

`ASOF JOIN` matches by time. For each row of the first table, it takes the **last row of the second table at or before that time** (with the same `ON` values). Both tables must be time-series tables.

```sql
-- For each live snapshot: the last minute candle at or before that time.
SELECT l.timestamp, l.symbol, l.ltp, m.time AS candle_time, m.close AS candle_close
FROM live_data l
ASOF JOIN ochl_minutes m ON l.symbol = m.symbol
WHERE l.symbol IN ('CITY', 'COAST')
ORDER BY l.symbol, l.timestamp;
```

```text
timestamp                | symbol | ltp   | candle_time              | candle_close
-------------------------+--------+-------+--------------------------+-------------
2026-09-10T05:20:00.000Z | CITY   |   513 | 2026-09-10T05:20:00.000Z |        504.6
2026-09-10T07:15:00.000Z | CITY   | 515.6 | 2026-09-10T07:15:00.000Z |        502.3
2026-09-10T09:14:00.000Z | CITY   | 527.1 | 2026-09-10T09:14:00.000Z |        504.9
2026-09-10T05:20:00.000Z | COAST  | 390.6 | 2026-09-10T05:20:00.000Z |        380.9
2026-09-10T07:15:00.000Z | COAST  | 391.4 | 2026-09-10T07:15:00.000Z |        377.8
2026-09-10T09:14:00.000Z | COAST  | 401.9 | 2026-09-10T09:14:00.000Z |        376.1
(6 rows, 1.0 ms)
```

(The sample live prices and minute prices are made up separately, so they do not agree.)

## Subqueries

```sql
-- IN (SELECT ...)
SELECT symbol, name FROM securities
WHERE symbol IN (SELECT symbol FROM trade_log WHERE quantity >= 1000);

-- a value from a subquery
SELECT symbol, close, (SELECT max(close) FROM ochl_day WHERE time IN '2026-09-10') AS best_close
FROM ochl_day WHERE time IN '2026-09-10';

-- FROM (SELECT ...) needs a name (here: t)
SELECT t.symbol, t.trades
FROM (SELECT symbol, count(*) AS trades FROM trade_log GROUP BY symbol) t
WHERE t.trades > 5;
```

```text
symbol | name                             
-------+----------------------------------
COAST  | Coastal Bank Limited            
TELCO  | Northwind Telecom Limited
(2 rows, 0.3 ms)

symbol | close | best_close
-------+-------+-----------
CITY   | 504.9 |      504.9
COAST  | 376.1 |      504.9
VOLT   | 191.2 |      504.9
(3 rows, 0.1 ms)

symbol | trades
-------+-------
CITY   |     11
COAST  |     11
TELCO  |      6
(3 rows, 0.1 ms)
```

Also available: `EXISTS (SELECT ...)` and `NOT IN (SELECT ...)`.

A subquery **may use columns of the outer query** ("correlated"), for example
`SELECT s.symbol, (SELECT max(close) FROM ochl_day d WHERE d.symbol = s.symbol) FROM securities s`.
KDB does not run it once per row: it reads the inner table once and looks every outer row up in that
result. See chapters 11 and 23.

## UNION ALL

```sql
SELECT symbol, 'buy' AS side, sum(quantity) AS shares FROM trade_log WHERE buyer = 58 GROUP BY symbol
UNION ALL
SELECT symbol, 'sell' AS side, sum(quantity) AS shares FROM trade_log WHERE seller = 58 GROUP BY symbol
ORDER BY symbol, side;
```

```text
symbol | side | shares
-------+------+-------
CITY   | sell |     20
COAST  | buy  |    760
COAST  | sell |   1200
TELCO  | buy  |   1000
VOLT   | buy  |    200
VOLT   | sell |     50
(6 rows, 0.4 ms)
```

- Every part must have the same number of columns.
- `ORDER BY` and `LIMIT` at the end work on all rows together. There they may only use output column names or positions.
- Only `UNION ALL` exists (it keeps duplicates). There is no `UNION`, `INTERSECT` or `EXCEPT`.

## CASE and CAST

```sql
SELECT symbol, pct_change,
       CASE WHEN pct_change > 0 THEN 'up'
            WHEN pct_change < 0 THEN 'down'
            ELSE 'flat' END AS direction
FROM live_data
LATEST ON timestamp PARTITION BY symbol;

SELECT CAST('512.5' AS DOUBLE) + 1 AS a,
       CAST(1500.256 AS DECIMAL(3)) AS b,
       CAST('2026-09-10T11:00:00+05:45' AS TIMESTAMP) AS c;
```

```text
symbol | pct_change | direction
-------+------------+----------
CITY   |       2.71 | up       
COAST  |        0.7 | up       
TELCO  |        1.9 | up       
VOLT   |      -0.86 | down     
(4 rows, 0.3 ms)

a     | b        | c                       
------+----------+-------------------------
513.5 | 1500.256 | 2026-09-10T05:15:00.000Z
(1 row, 0.1 ms)
```

- `CASE x WHEN 1 THEN 'a' WHEN 2 THEN 'b' END` (compare one value) also works.
- `x::INT` is the short form of `CAST(x AS INT)`.
- `SELECT` without `FROM` works: `SELECT 1 + 1`.

## DISTINCT

```sql
SELECT DISTINCT sector FROM securities ORDER BY sector;

SELECT count(DISTINCT symbol) AS symbols_traded FROM trade_log;
```

```text
sector    
----------
Banking   
Energy    
Investment
Telecom   
(4 rows, 0.2 ms)

symbols_traded
--------------
             4
(1 row, 0.2 ms)
```

## Indicators and window functions

These functions look at **a series of rows**, not one row.

### Indicators

```sql
SELECT time, close,
       round(sma(close, 3), 2) AS sma3,
       round(ema(close, 3), 2) AS ema3,
       round(rsi(close, 3), 1) AS rsi3,
       round(atr(high, low, close, 3), 2) AS atr3
FROM ochl_day
WHERE symbol = 'CITY' AND time IN '2026-09';
```

```text
time                     | close | sma3   | ema3   | rsi3 | atr3
-------------------------+-------+--------+--------+------+-----
2026-09-01T00:00:00.000Z | 502.4 |   NULL |   NULL | NULL | NULL
2026-09-02T00:00:00.000Z | 496.4 |   NULL |   NULL | NULL | NULL
2026-09-03T00:00:00.000Z | 497.9 |  498.9 |  498.9 | NULL | NULL
2026-09-06T00:00:00.000Z |   499 | 497.77 | 498.95 | 30.2 | 6.07
2026-09-07T00:00:00.000Z | 498.7 | 498.53 | 498.82 | 28.7 | 6.04
2026-09-08T00:00:00.000Z | 497.5 |  498.4 | 498.16 | 22.1 | 5.23
2026-09-09T00:00:00.000Z | 504.6 | 500.27 | 501.38 | 74.4 | 8.45
2026-09-10T00:00:00.000Z | 504.9 | 502.33 | 503.14 | 75.4 | 7.74
(8 rows, 0.4 ms)
```

| Function | Meaning | First value |
|---|---|---|
| `sma(x, n)` | simple moving average of the last n rows | row n |
| `ema(x, n)` | exponential moving average (starts with the SMA, like TA-Lib) | row n |
| `rsi(x, n)` | Wilder's RSI, 0 to 100 (like TA-Lib) | row n+1 |
| `atr(high, low, close, n)` | Wilder's average true range | row n+1 |
| `lag(x)` / `lag(x, k)` | the value k rows before (default 1) | row k+1 |
| `lead(x)` / `lead(x, k)` | the value k rows after | - |
| `pct_change(x)` | percent change from the row before | row 2 |
| `cumsum(x)` | running total | row 1 |
| `row_number()` | 1, 2, 3, ... | row 1 |
| `rank()` / `dense_rank()` | rank; equal values get the same rank | row 1 |

Before there are enough rows, the result is NULL.

### The series order

Series functions run in **time order** of the table's time column. Use `OVER (...)` to choose the order or to split the series:

```sql
SELECT time, close,
       lag(close) AS prev_close,
       lead(close) AS next_close,
       round(pct_change(close), 2) AS chg_pct,
       cumsum(volume) AS running_volume,
       row_number() OVER (ORDER BY volume DESC) AS volume_rank
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-09-06';
```

```text
time                     | close | prev_close | next_close | chg_pct | running_volume | volume_rank
-------------------------+-------+------------+------------+---------+----------------+------------
2026-09-06T00:00:00.000Z | 180.1 |       NULL |      176.9 |    NULL |          78550 |           4
2026-09-07T00:00:00.000Z | 176.9 |      180.1 |      182.4 |   -1.78 |         214110 |           2
2026-09-08T00:00:00.000Z | 182.4 |      176.9 |      187.3 |    3.11 |         350880 |           1
2026-09-09T00:00:00.000Z | 187.3 |      182.4 |      191.2 |    2.69 |         445290 |           3
2026-09-10T00:00:00.000Z | 191.2 |      187.3 |       NULL |    2.08 |         486760 |           5
(5 rows, 0.3 ms)
```

**Many symbols:** without `PARTITION BY`, all rows are one series, and CITY's SMA would use COAST's prices. Use `OVER (PARTITION BY symbol ORDER BY time)`:

```sql
SELECT time, symbol, close,
       round(sma(close, 3) OVER (PARTITION BY symbol ORDER BY time), 2) AS sma3
FROM ochl_day
WHERE time >= '2026-09-06'
ORDER BY symbol, time;
```

```text
time                     | symbol | close | sma3  
-------------------------+--------+-------+-------
2026-09-06T00:00:00.000Z | CITY   |   499 |   NULL
2026-09-07T00:00:00.000Z | CITY   | 498.7 |   NULL
2026-09-08T00:00:00.000Z | CITY   | 497.5 |  498.4
2026-09-09T00:00:00.000Z | CITY   | 504.6 | 500.27
2026-09-10T00:00:00.000Z | CITY   | 504.9 | 502.33
2026-09-06T00:00:00.000Z | COAST  | 375.4 |   NULL
2026-09-07T00:00:00.000Z | COAST  | 379.2 |   NULL
2026-09-08T00:00:00.000Z | COAST  | 377.2 | 377.27
2026-09-09T00:00:00.000Z | COAST  | 380.1 | 378.83
2026-09-10T00:00:00.000Z | COAST  | 376.1 |  377.8
2026-09-06T00:00:00.000Z | VOLT   | 180.1 |   NULL
2026-09-07T00:00:00.000Z | VOLT   | 176.9 |   NULL
2026-09-08T00:00:00.000Z | VOLT   | 182.4 |  179.8
2026-09-09T00:00:00.000Z | VOLT   | 187.3 |  182.2
2026-09-10T00:00:00.000Z | VOLT   | 191.2 | 186.97
(15 rows, 0.3 ms)
```

### Aggregates over a window: ROWS n PRECEDING

Any aggregate can run over a window of rows: `sum(x) OVER (PARTITION BY ... ORDER BY ... ROWS n PRECEDING)` uses the current row and up to n rows before it. `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` is the same as `ROWS 2 PRECEDING`.

```sql
SELECT time, symbol, volume,
       sum(volume) OVER (PARTITION BY symbol ORDER BY time ROWS 2 PRECEDING) AS vol_3d,
       round(avg(close) OVER (PARTITION BY symbol ORDER BY time ROWS 2 PRECEDING), 2) AS avg_close_3d,
       rank() OVER (PARTITION BY time ORDER BY volume DESC) AS rank_that_day
FROM ochl_day
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

```text
time                     | symbol | volume | vol_3d | avg_close_3d | rank_that_day
-------------------------+--------+--------+--------+--------------+--------------
2026-09-08T00:00:00.000Z | CITY   |  34400 |  34400 |        497.5 |             3
2026-09-09T00:00:00.000Z | CITY   | 182390 | 216790 |       501.05 |             2
2026-09-10T00:00:00.000Z | CITY   | 183040 | 399830 |       502.33 |             2
2026-09-08T00:00:00.000Z | COAST  |  60980 |  60980 |        377.2 |             2
2026-09-09T00:00:00.000Z | COAST  | 186330 | 247310 |       378.65 |             1
2026-09-10T00:00:00.000Z | COAST  | 186200 | 433510 |        377.8 |             1
2026-09-08T00:00:00.000Z | VOLT   | 136770 | 136770 |        182.4 |             1
2026-09-09T00:00:00.000Z | VOLT   |  94410 | 231180 |       184.85 |             3
2026-09-10T00:00:00.000Z | VOLT   |  41470 | 272650 |       186.97 |             3
(9 rows, 0.4 ms)
```

| OVER (...) | Window for each row |
|---|---|
| `OVER ()` | all rows (of the result) |
| `OVER (PARTITION BY symbol)` | all rows of that symbol |
| `OVER (PARTITION BY symbol ORDER BY time)` | from the first row of that symbol to this row (running) |
| `OVER (PARTITION BY symbol ORDER BY time ROWS 19 PRECEDING)` | this row and the 19 before it |

### Rule 1: WHERE runs first

Indicators only see the rows that WHERE keeps. A 3-day SMA on "the last 3 days" has only 3 rows to work with:

```sql
-- WHERE runs first. Here sma3 has only 3 days to use, so the first 2 rows are NULL:
SELECT time, close, round(sma(close, 3), 2) AS sma3
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-08';

-- Better: compute on more history inside, filter outside.
SELECT time, close, sma3
FROM (SELECT time, close, round(sma(close, 3), 2) AS sma3 FROM ochl_day WHERE symbol = 'CITY') t
WHERE time >= '2026-09-08';
```

```text
time                     | close | sma3  
-------------------------+-------+-------
2026-09-08T00:00:00.000Z | 497.5 |   NULL
2026-09-09T00:00:00.000Z | 504.6 |   NULL
2026-09-10T00:00:00.000Z | 504.9 | 502.33
(3 rows, 0.3 ms)

time                     | close | sma3  
-------------------------+-------+-------
2026-09-08T00:00:00.000Z | 497.5 |  498.4
2026-09-09T00:00:00.000Z | 504.6 | 500.27
2026-09-10T00:00:00.000Z | 504.9 | 502.33
(3 rows, 0.1 ms)
```

### Rule 2: with SAMPLE BY or GROUP BY, the window sees the groups

A window function in a query with `SAMPLE BY`, `GROUP BY` or aggregates runs **after** the groups are made. It reads one value per group, not the rows of the table. So it may only use the keys of the groups and aggregates. A plain column is refused:

```sql
SELECT time, last(close) AS close, sma(close, 2) AS sma2
FROM ochl_day
WHERE symbol = 'CITY'
SAMPLE BY 1w WEEK START SUNDAY;
```

```text
error: line 1, column 40: column 'close' is used by a window function in a query with aggregates, so it must be a key of the groups: add it to the SELECT list or to GROUP BY
```

`close` has many values in one week. Say which one you mean: the week's last close is `last(close)`. Put the aggregate inside the window function:

```sql
SELECT time, last(close) AS close, sma(last(close), 2) AS sma2
FROM ochl_day
WHERE symbol = 'CITY' AND time IN '2026'
SAMPLE BY 1w WEEK START SUNDAY;
```

```text
time                     | close | sma2 
-------------------------+-------+------
2026-08-23T00:00:00.000Z | 505.9 |  NULL
2026-08-30T00:00:00.000Z | 497.9 | 501.9
2026-09-06T00:00:00.000Z | 504.9 | 501.4
(3 rows, 0.5 ms)
```

A subquery gives the same result: the candles inside, the indicator outside. Use this form when the indicator needs several columns of the candle, or when you build it in steps.

```sql
SELECT time, close, sma(close, 2) AS sma2
FROM (
  SELECT time, last(close) AS close
  FROM ochl_day
  WHERE symbol = 'CITY' AND time IN '2026'
  SAMPLE BY 1w WEEK START SUNDAY
) w;
```

```text
time                     | close | sma2 
-------------------------+-------+------
2026-08-23T00:00:00.000Z | 505.9 |  NULL
2026-08-30T00:00:00.000Z | 497.9 | 501.9
2026-09-06T00:00:00.000Z | 504.9 | 501.4
(3 rows, 0.4 ms)
```

The same works with `GROUP BY`, for example a rank of the groups: `SELECT symbol, sum(volume) AS volume, rank() OVER (ORDER BY sum(volume) DESC) AS place FROM ochl_day GROUP BY symbol`.

A series function cannot be inside another one (`lag(sma(close, 3))`). Use one subquery level per step (see the moving average crossover in the cookbook).

## Views

A view is a saved query with a name. You use it like a table.

```sql
CREATE VIEW candles_1w AS
SELECT time, symbol,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume
FROM ochl_day
SAMPLE BY 1w WEEK START SUNDAY;

SELECT * FROM candles_1w WHERE symbol = 'VOLT' AND time >= '2026-08-30';
```

```text
view 'candles_1w' created

time                     | symbol | open  | high  | low   | close | volume
-------------------------+--------+-------+-------+-------+-------+-------
2026-08-30T00:00:00.000Z | VOLT   | 172.5 | 177.3 | 167.3 |   176 | 368150
2026-09-06T00:00:00.000Z | VOLT   | 174.2 | 192.1 | 172.4 | 191.2 | 486760
(2 rows, 0.4 ms)
```

```powershell
kdb sql market "SHOW VIEWS; DROP VIEW candles_1w; SHOW VIEWS" --format csv
```

```text
name,query
candles_1w,"SELECT time, symbol, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume FROM ochl_day SAMPLE BY 1w WEEK START SUNDAY"
name,query
```

- The view runs its query **every time** you use it.
- KDB moves a WHERE on the view into the view's query when it can, so it reads fewer rows. Here `symbol = 'VOLT'` is moved in; the time condition is applied to the weekly candles after they are made. `EXPLAIN` shows `push 1 condition(s) into view candles_1w`.
- `CREATE VIEW IF NOT EXISTS`, `DROP VIEW IF EXISTS` work.
- KDB checks the query when you create the view. A view with an error is refused.

A **cached view** runs its query once and keeps the rows. Reading it reads the kept rows, so a slow `GROUP BY` over a big table is paid once, not on every read. With `REFRESH ON COMMIT`, KDB makes the rows new at the first read after a change of a table the view reads:

```sql
CREATE CACHED VIEW trades_per_symbol AS
SELECT symbol, count(*) AS trades FROM trade_log
REFRESH ON COMMIT;
```

```text
view 'trades_per_symbol' created (4 row(s) cached)
```

- Without `REFRESH ON COMMIT`, the rows stay as they are until you run `REFRESH VIEW trades_per_symbol`.
- The kept rows live in memory. After a restart they are made again at the first read.
- A `WHERE` on a cached view filters the kept rows. It does not run the view's query again.

## EXPLAIN: what will KDB read?

`EXPLAIN` shows the plan, without running the query. Use CSV format so lines are not cut.

```powershell
kdb sql market "EXPLAIN SELECT time, close FROM ochl_day WHERE symbol = 'CITY' AND time IN '2026-09'" --format csv
```

```text
plan
"scan table ochl_day (1 of 2 partitions, about 57 rows)"
read only 1 key range(s) of each partition
"build 3 of 7 stored column(s) per row: time, symbol, close"
filter while scanning: 2 condition(s)
```

- `1 of 2 partitions`: the `2025` file is skipped because of the time condition.
- `read only 1 key range(s)`: rows are sorted by symbol and time, so KDB jumps straight to CITY's rows of September and reads nothing else. This works for `symbol = '...'`, `symbol IN (...)`, and a time range on top of them.
- `build 3 of 7 stored column(s)`: the table has 7 columns, but KDB makes only the 3 that the query needs (`symbol` for the filter, `time` and `close` for the result).

A second example with a join:

```sql
EXPLAIN SELECT b.name, sum(f.amount) AS turnover
FROM trade_log f JOIN brokers b ON f.buyer = b.id
WHERE f.date IN '2026-09-10'
GROUP BY b.name ORDER BY turnover DESC LIMIT 3;
```

```text
plan
"scan table trade_log (1 of 2 partitions, about 32 rows)"
"join (hash on 1 key(s)) table brokers (1 of 1 partitions, about 5 rows)"
filter while scanning: 1 condition(s)
"group by 1 key(s), 1 aggregate(s)"
sort by 1 key(s)
limit 3
```

Only the day 2026-09-10 is read. (For a `DATE` time column KDB also reads the partition of the next day, to be safe.)

**Speed tips:**

- Always filter time-series tables by time (`time IN '...'`, `>=`, `<`, `BETWEEN`) on the first table of the query.
- Filter by symbol with `symbol = '...'` or `symbol IN (...)` written plainly: `upper(symbol) = 'CITY'` or `concat(symbol, '') = ...` makes KDB read every row.
- Put the big table first in FROM, and join small tables to it.
- Select only the columns you need.

## Cookbook

Ready-made market-data queries. Each one is verified on the sample data.

### Weekly candles for all symbols

```sql
SELECT time, symbol,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume
FROM ochl_day
WHERE time IN '2026'
SAMPLE BY 1w WEEK START SUNDAY
ORDER BY symbol, time;
```

```text
time                     | symbol | open  | high  | low   | close | volume
-------------------------+--------+-------+-------+-------+-------+-------
2026-08-23T00:00:00.000Z | CITY   |   505 |   517 |   502 | 505.9 | 601770
2026-08-30T00:00:00.000Z | CITY   | 507.3 | 511.2 | 494.1 | 497.9 | 538130
2026-09-06T00:00:00.000Z | CITY   | 497.4 | 512.4 |   495 | 504.9 | 591860
2026-08-23T00:00:00.000Z | COAST  | 392.1 | 393.3 | 366.2 | 367.1 | 421000
2026-08-30T00:00:00.000Z | COAST  |   368 | 375.4 | 364.1 | 373.2 | 356390
2026-09-06T00:00:00.000Z | COAST  | 374.6 | 398.8 | 372.5 | 376.1 | 690140
2026-08-23T00:00:00.000Z | VOLT   | 182.4 | 183.6 |   172 | 173.3 | 535470
2026-08-30T00:00:00.000Z | VOLT   | 172.5 | 177.3 | 167.3 |   176 | 368150
2026-09-06T00:00:00.000Z | VOLT   | 174.2 | 192.1 | 172.4 | 191.2 | 486760
(9 rows, 0.4 ms)
```

### Top gainers and losers of a day (from daily candles)

```sql
SELECT symbol, prev_close, close,
       round((close - prev_close) / prev_close * 100, 2) AS change_pct
FROM (
  SELECT time, symbol, close,
         lag(close) OVER (PARTITION BY symbol ORDER BY time) AS prev_close
  FROM ochl_day
) t
WHERE time IN '2026-09-10'
ORDER BY change_pct DESC;
```

```text
symbol | prev_close | close | change_pct
-------+------------+-------+-----------
VOLT   |      187.3 | 191.2 |       2.08
CITY   |      504.6 | 504.9 |       0.06
COAST  |      380.1 | 376.1 |      -1.05
(3 rows, 0.4 ms)
```

For losers use `ORDER BY change_pct` (small first). Add `LIMIT 10` for a top 10. The inner query reads all days; for a big table add `WHERE time >= '2026-09-01'` inside (a few days before the day you want).

### Top gainers and losers right now (from live data)

```sql
-- Top gainers and losers right now, from the live snapshots.
SELECT symbol, ltp, pct_change
FROM live_data
LATEST ON timestamp PARTITION BY symbol
ORDER BY pct_change DESC
LIMIT 2;

SELECT symbol, ltp, pct_change
FROM live_data
LATEST ON timestamp PARTITION BY symbol
ORDER BY pct_change
LIMIT 2;
```

```text
symbol | ltp   | pct_change
-------+-------+-----------
CITY   | 527.1 |       2.71
TELCO  | 897.7 |        1.9
(2 rows, 0.2 ms)

symbol | ltp   | pct_change
-------+-------+-----------
VOLT   |   184 |      -0.86
COAST  | 401.9 |        0.7
(2 rows, 0.0 ms)
```

### Broker buy and sell summary (trade_log)

```sql
SELECT b.id, b.name,
       sum(CASE WHEN f.buyer  = b.id THEN f.quantity ELSE 0 END) AS bought,
       sum(CASE WHEN f.seller = b.id THEN f.quantity ELSE 0 END) AS sold,
       sum(CASE WHEN f.buyer  = b.id THEN f.quantity ELSE 0 END)
     - sum(CASE WHEN f.seller = b.id THEN f.quantity ELSE 0 END) AS net
FROM brokers b
CROSS JOIN trade_log f
WHERE f.date IN '2026-09-10'
GROUP BY b.id, b.name
ORDER BY net DESC;
```

```text
id | name                | bought | sold | net 
---+---------------------+--------+------+-----
49 | Online Securities   |   1740 |  340 | 1400
45 | Imperial Securities |   1560 | 1520 |   40
34 | Vision Securities   |    300 |  700 | -400
58 | Northgate Securities |    760 | 1270 | -510
 1 | Keystone Securities |    570 | 1100 | -530
(5 rows, 1.0 ms)
```

The CROSS JOIN makes (brokers × trades) rows. That is fine for one day. For many days and all ~90 brokers, use the next query per broker, or the UNION ALL form shown earlier.

One broker, per symbol, with amounts:

```sql
-- One broker (58), buy and sell per symbol, with amounts.
SELECT symbol,
       sum(CASE WHEN buyer  = 58 THEN quantity ELSE 0 END) AS buy_qty,
       sum(CASE WHEN seller = 58 THEN quantity ELSE 0 END) AS sell_qty,
       round(sum(CASE WHEN buyer  = 58 THEN amount ELSE 0 END), 2) AS buy_amount,
       round(sum(CASE WHEN seller = 58 THEN amount ELSE 0 END), 2) AS sell_amount
FROM trade_log
WHERE date IN '2026-09-10' AND (buyer = 58 OR seller = 58)
GROUP BY symbol
ORDER BY symbol;
```

```text
symbol | buy_qty | sell_qty | buy_amount | sell_amount
-------+---------+----------+------------+------------
CITY   |       0 |       20 |          0 |       10300
COAST  |     560 |     1200 |     223390 |      482000
VOLT   |     200 |       50 |      36800 |        9200
(3 rows, 0.4 ms)
```

### Volume-weighted average price (VWAP)

```sql
SELECT symbol,
       round(vwap(rate, quantity), 2) AS vwap,
       round(sum(amount) / sum(quantity), 2) AS vwap_by_hand,
       sum(quantity) AS shares,
       count(*) AS trades
FROM trade_log
WHERE date IN '2026-09-10'
GROUP BY symbol
ORDER BY symbol;
```

```text
symbol | vwap   | vwap_by_hand | shares | trades
-------+--------+--------------+--------+-------
CITY   |  516.3 |        516.3 |    910 |      7
COAST  | 399.77 |       399.77 |   2850 |      9
TELCO  | 880.86 |       880.86 |    770 |      4
VOLT   | 184.88 |       184.88 |    400 |      4
(4 rows, 0.4 ms)
```

### 52-week high and low

```sql
SELECT symbol, max(high) AS high_52w, min(low) AS low_52w
FROM ochl_day
WHERE time > dateadd('d', -365, CAST('2026-09-10' AS TIMESTAMP))
GROUP BY symbol
ORDER BY symbol;
```

```text
symbol | high_52w | low_52w
-------+----------+--------
CITY   |    546.2 |   494.1
COAST  |    429.9 |   364.1
VOLT   |    199.7 |   167.3
(3 rows, 0.4 ms)
```

For "until today", write `dateadd('d', -365, now())`.

### Moving average crossover

A BUY signal when the 3-day SMA goes above the 5-day SMA; SELL when it goes below.

```sql
SELECT time, close, fast, slow,
       CASE WHEN fast > slow AND prev_fast <= prev_slow THEN 'BUY'
            WHEN fast < slow AND prev_fast >= prev_slow THEN 'SELL'
            ELSE '' END AS signal
FROM (
  SELECT time, close, fast, slow, lag(fast) AS prev_fast, lag(slow) AS prev_slow
  FROM (
    SELECT time, close, round(sma(close, 3), 2) AS fast, round(sma(close, 5), 2) AS slow
    FROM ochl_day
    WHERE symbol = 'VOLT' AND time IN '2026'
  ) a
) b
WHERE time >= '2026-08-30';
```

```text
time                     | close | fast   | slow   | signal
-------------------------+-------+--------+--------+-------
2026-08-30T00:00:00.000Z |   173 |  173.5 | 175.16 |       
2026-08-31T00:00:00.000Z | 172.6 | 172.97 | 173.98 |       
2026-09-01T00:00:00.000Z |   169 | 171.53 | 172.42 |       
2026-09-02T00:00:00.000Z | 171.5 | 171.03 | 171.88 |       
2026-09-03T00:00:00.000Z |   176 | 172.17 | 172.42 |       
2026-09-06T00:00:00.000Z | 180.1 | 175.87 | 173.84 | BUY   
2026-09-07T00:00:00.000Z | 176.9 | 177.67 |  174.7 |       
2026-09-08T00:00:00.000Z | 182.4 |  179.8 | 177.38 |       
2026-09-09T00:00:00.000Z | 187.3 |  182.2 | 180.54 |       
2026-09-10T00:00:00.000Z | 191.2 | 186.97 | 183.58 |       
(10 rows, 0.4 ms)
```

For real use, choose periods like 20 and 50, and read enough history in the innermost query.

### Turnover by sector

```sql
SELECT s.sector, count(*) AS trades, sum(f.quantity) AS shares, sum(f.amount) AS turnover
FROM trade_log f
JOIN securities s ON f.symbol = s.symbol
WHERE f.date IN '2026-09-10'
GROUP BY s.sector
ORDER BY turnover DESC;
```

```text
sector  | trades | shares | turnover
--------+--------+--------+---------
Banking |     16 |   3760 |  1609170
Telecom |      4 |    770 |   678260
Energy  |      4 |    400 |    73950
(3 rows, 0.4 ms)
```

### Volume per Nepal clock hour

`hour()` gives the UTC hour. Add 5 hours 45 minutes (20700000 milliseconds) to get the Nepal hour:

```sql
-- hour() works in UTC. Add 5h45m (20700000 ms) to get the Nepal clock hour.
SELECT hour(time + 20700000) AS npt_hour, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
GROUP BY hour(time + 20700000)
ORDER BY npt_hour;
```

```text
npt_hour | volume
---------+-------
      11 |  47020
      12 |  41230
      13 |  46180
      14 |  48610
(4 rows, 0.7 ms)
```

## Try it yourself

1. Make 5-minute candles for COAST on 2026-09-09, only the first 3 candles.
2. For each symbol in `ochl_day`, show the day with the biggest volume in September 2026. (Hint: `rank() OVER (PARTITION BY symbol ORDER BY volume DESC)` in a subquery.)
3. Show each broker's total traded amount (bought + sold) on 2026-09-10, biggest first, using `UNION ALL`.

<details>
<summary>Answers</summary>

1. ```sql
   SELECT time, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
   FROM ochl_minutes
   WHERE symbol = 'COAST' AND time IN '2026-09-09'
   SAMPLE BY 5m
   LIMIT 3;
   ```
2. ```sql
   SELECT symbol, time, volume
   FROM (
     SELECT time, symbol, volume,
            rank() OVER (PARTITION BY symbol ORDER BY volume DESC) AS r
     FROM ochl_day
     WHERE time IN '2026-09'
   ) t
   WHERE r = 1
   ORDER BY symbol;
   ```
   Answer on the sample data: CITY 2026-09-10 (183040), COAST 2026-09-09 (186330), VOLT 2026-09-03 (145930).
3. ```sql
   SELECT broker, sum(amount) AS turnover
   FROM (
     SELECT buyer AS broker, amount FROM trade_log WHERE date IN '2026-09-10'
     UNION ALL
     SELECT seller AS broker, amount FROM trade_log WHERE date IN '2026-09-10'
   ) t
   GROUP BY broker
   ORDER BY turnover DESC;
   ```

</details>

---

Next: [6. Web console](06-web-console.md)
