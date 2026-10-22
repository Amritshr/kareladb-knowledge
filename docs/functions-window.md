# Window and series functions

> Look at a series of rows: previous and next values, running totals, moving windows, time windows and ranks, with OVER (...).

- Category: Functions — window and series
- Keywords: window function, series function, analytic function, OVER, PARTITION BY, ROWS, PRECEDING, FOLLOWING, UNBOUNDED, UNBOUNDED FOLLOWING, CURRENT ROW, RANGE, RANGE BETWEEN, INTERVAL, frame, centered moving average, future rows, time window, last 7 days, running total, running product, cumulative product, running max, high so far, running min, percentile rank, cumulative distribution, quartile, decile, bucket, first value, last value, cumulative sum, moving sum, moving max, rolling, previous row, next row, previous close, change from yesterday, top N per group, ranking, running sum, cumulative, prev, shift, diff, next, percent change, rownum, row number, QUALIFY, window with GROUP BY
- See also: [Technical indicators](functions-indicators.md), [Aggregate functions](functions-aggregate.md), [Statistics functions](functions-statistics.md), [SAMPLE BY](sample-by.md), [UNION and subqueries](union-subqueries.md), [WHERE](where.md)

A **window function** (or series function) gives a value for **every row**, and it may look at other rows to make it: the row before, the rows of the same symbol, the last 5 rows. Unlike `GROUP BY`, the rows stay; nothing is merged.

- **Series functions** always work on a series: `lag`, `lead`, `cumsum`, `cumprod`, `cummax`, `cummin`, `pct_change`, `row_number`, `rank`, `dense_rank`, `percent_rank`, `cume_dist`, `ntile`, `first_value`, `last_value`, `nth_value`, and the indicators `sma`, `ema`, `rsi`, `atr` ([technical indicators](functions-indicators.md)).
- More series functions have their own pages: returns, drawdown and z-score ([returns and risk](functions-returns-risk.md)), and the indicator families [momentum](functions-indicators-momentum.md) (MACD, stochastic), [volatility](functions-indicators-volatility.md) (Bollinger bands), [trend](functions-indicators-trend.md) (ADX, supertrend) and [volume](functions-indicators-volume.md) (OBV, MFI).
- **Aggregates** (`sum`, `avg`, `min`, `max`, `count`, ...) become window functions when you write `OVER (...)` after them.

**The order of the series.** Without `OVER`, or with `OVER` but without `ORDER BY`, the series is **all result rows in time order** (the time column of the table). A table or subquery without a time column keeps the order the rows come in. Rows with the same time keep their storage order.

**Rules**

1. `WHERE` runs first: the series only has the rows that `WHERE` keeps. `LIMIT` and `ORDER BY` run after: they do not change the values.
2. The rows of the result are **not** sorted in series order by themselves. Add `ORDER BY time` (or `ORDER BY symbol, time`) to read them.
3. Window functions can only be in the **select list**. To filter on one (`WHERE rn = 1`), put the query in a subquery.
4. With `GROUP BY` or `SAMPLE BY` in the same `SELECT`, the window runs over the **groups**, after they are made: `sum(sum(qty)) OVER (ORDER BY time)` is a running total of the grouped sums. Inside `OVER`, use the group keys or aggregates, not the raw columns.
5. One window function cannot be inside another (`lag(sma(close, 3))`), and an aggregate cannot take a window function (`sum(lag(close) OVER (...))`). The error says so (PostgreSQL `42803`). Use one subquery level per step: `SELECT sum(x) FROM (SELECT lag(close) OVER (...) AS x FROM t) s`.

**Example: Yesterday's close, change and running volume of VOLT** (sample data: sample)

```sql
SELECT time, close,
       lag(close) AS prev_close,
       round(close - lag(close), 2) AS change,
       round(pct_change(close), 2) AS change_pct,
       cumsum(volume) AS running_volume
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-09-06'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | prev_close (DOUBLE) | change (DOUBLE) | change_pct (DOUBLE) | running_volume (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-06T00:00:00.000Z | 180.1 | NULL | NULL | NULL | 78550 |
| 2026-09-07T00:00:00.000Z | 176.9 | 180.1 | -3.2 | -1.78 | 214110 |
| 2026-09-08T00:00:00.000Z | 182.4 | 176.9 | 5.5 | 3.11 | 350880 |
| 2026-09-09T00:00:00.000Z | 187.3 | 182.4 | 4.9 | 2.69 | 445290 |
| 2026-09-10T00:00:00.000Z | 191.2 | 187.3 | 3.9 | 2.08 | 486760 |

(5 rows)

**Example: A sum of yesterday's closes: the window in a subquery** (sample data: sample)

```sql
SELECT round(sum(prev_close), 2) AS sum_prev_close
FROM (SELECT lag(close) OVER (ORDER BY time) AS prev_close FROM ochl_day WHERE symbol = 'VOLT') s;
```

Result:

| sum_prev_close (DOUBLE) |
|---|
| 3247.3 |

(1 row)

**Example: The same without the subquery is refused** (sample data: sample; shows an error)

```sql
SELECT sum(lag(close) OVER (ORDER BY time)) FROM ochl_day WHERE symbol = 'VOLT';
```

Result:

Error: `line 1, column 12: 'lag' is a window function and cannot be used inside the aggregate 'sum'; compute it in a subquery first: SELECT sum(x) FROM (SELECT lag(...) OVER (...) AS x FROM t) s`

**Example: Top trade of each symbol: the window inside, the filter outside** (sample data: sample)

```sql
SELECT symbol, transaction_id, buyer, amount
FROM (SELECT symbol, transaction_id, buyer, amount,
             row_number() OVER (PARTITION BY symbol ORDER BY amount DESC) AS rn
      FROM trade_log) t
WHERE rn = 1
ORDER BY amount DESC;
```

Result:

| symbol (SYMBOL) | transaction_id (LONG) | buyer (INT) | amount (DOUBLE) |
|---|---|---|---|
| TELCO | 100001 | 58 | 881000 |
| COAST | 100031 | 45 | 402000 |
| CITY | 100005 | 1 | 258500 |
| VOLT | 100012 | 58 | 36800 |

(4 rows)

<a id="over"></a>

## OVER (...)

Syntax:

```sql
function(arguments) OVER ()
function(arguments) OVER ([PARTITION BY expr, ...]
                          [ORDER BY expr [ASC | DESC], ...]
                          [ROWS n PRECEDING | ROWS UNBOUNDED PRECEDING
                           | ROWS BETWEEN start AND end
                           | RANGE BETWEEN start AND end])

start, end:  UNBOUNDED PRECEDING | n PRECEDING | CURRENT ROW | n FOLLOWING | UNBOUNDED FOLLOWING
```

`OVER` says which rows the function sees for each row: the **window**. All three parts are optional.

| OVER (...) | The window of each row |
|---|---|
| `OVER ()` | all result rows |
| `OVER (PARTITION BY symbol)` | all rows with the same symbol |
| `OVER (PARTITION BY symbol ORDER BY time)` | from the first row of that symbol to this row (a running value) |
| `OVER (PARTITION BY symbol ORDER BY time ROWS 4 PRECEDING)` | this row and the 4 rows before it (a moving value) |
| `OVER (ORDER BY time ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING)` | 2 rows before, this row and 2 rows after ([FOLLOWING](#rows-following)) |
| `OVER (ORDER BY time RANGE BETWEEN '7 days' PRECEDING AND CURRENT ROW)` | the rows of the last 7 days ([RANGE](#range)) |

- **Works with:** the series functions and every aggregate. Other functions give an error: `'upper' cannot be used with OVER`.
- **Notes:** the **frame** is the part of the window that an aggregate reads: `ROWS ...` or `RANGE ...`. A series function (`lag`, `sma`, `rank`, ...) uses `PARTITION BY` and `ORDER BY`, and ignores the frame; only `first_value`, `last_value`, `nth_value`, and `zscore` and `minmax_scale` without a period read it. There are no named windows (`WINDOW w AS`) and no `FILTER`. `DISTINCT` inside a window aggregate is ignored (`count(DISTINCT x) OVER ()` counts all values).

**Example: The same sum over three different windows** (sample data: sample)

```sql
SELECT time, volume,
       sum(volume) OVER () AS all_rows,
       sum(volume) OVER (ORDER BY time) AS running,
       sum(volume) OVER (ORDER BY time ROWS 1 PRECEDING) AS last_2_days
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-06'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | volume (DOUBLE) | all_rows (DOUBLE) | running (DOUBLE) | last_2_days (DOUBLE) |
|---|---|---|---|---|
| 2026-09-06T00:00:00.000Z | 74950 | 591860 | 74950 | 74950 |
| 2026-09-07T00:00:00.000Z | 117080 | 591860 | 192030 | 192030 |
| 2026-09-08T00:00:00.000Z | 34400 | 591860 | 226430 | 151480 |
| 2026-09-09T00:00:00.000Z | 182390 | 591860 | 408820 | 216790 |
| 2026-09-10T00:00:00.000Z | 183040 | 591860 | 591860 | 365430 |

(5 rows)

**Example: Only series functions and aggregates can have OVER** (sample data: sample; shows an error)

```sql
SELECT upper(symbol) OVER () FROM ochl_day;
```

Result:

Error: `line 1, column 8: 'upper' cannot be used with OVER`

<a id="partition-by"></a>

## PARTITION BY (window)

Syntax:

```sql
function(arguments) OVER (PARTITION BY expr [, expr ...] ...)
```

Splits the rows into separate series, one per value (for example one per symbol). The function starts again for every part: `lag` of the first CITY row is NULL, not the last COAST price.

| Argument | Type | Meaning |
|---|---|---|
| `expr` | any type | a column or expression; rows with equal values are one part |

- **NULL:** rows where the expression is NULL are one part together.
- **Notes:** without `PARTITION BY`, all rows are **one** series. With many symbols in the result, always use `PARTITION BY symbol`, or CITY's values mix with COAST's.
- **Fast sums of windows:** a `GROUP BY` over a subquery of `row_number`, `rank`, `dense_rank`, `lead` or `lag` over one table runs on the column engine when the `PARTITION BY` columns are the first columns the table is sorted by and include its time column (a floorsheet sorted by symbol, then time: `PARTITION BY time, symbol`), each call has one plain `ORDER BY` column, and the outer query uses `sum`, `count`, `min`, `max` or `avg`. A year of such a filter is then about 8 times faster. The answer is the same either way. A day with rows not saved yet is read the same way, and the step keeps at most 64 MB of window rows at a time; a NULL in the `ORDER BY` column runs the usual way.

**Example: Previous close per symbol** (sample data: sample)

```sql
SELECT time, symbol, close,
       lag(close) OVER (PARTITION BY symbol ORDER BY time) AS prev_close
FROM ochl_day
WHERE time >= '2026-09-09'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | prev_close (DOUBLE) |
|---|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | NULL |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 504.6 |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | NULL |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 380.1 |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | NULL |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 187.3 |

(6 rows)

**Example: Wrong: without PARTITION BY the symbols are one series** (sample data: sample)

```sql
SELECT time, symbol, close, lag(close) AS prev_close_mixed
FROM ochl_day
WHERE time >= '2026-09-09'
ORDER BY time, symbol;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | prev_close_mixed (DOUBLE) |
|---|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | NULL |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 504.6 |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 380.1 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 187.3 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 504.9 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 376.1 |

(6 rows)

**Example: Each symbol's share of the day's volume** (sample data: sample)

```sql
SELECT time, symbol, volume,
       round(volume * 100.0 / sum(volume) OVER (PARTITION BY time), 1) AS share_pct
FROM ochl_day
WHERE time >= '2026-09-09'
ORDER BY time, share_pct DESC;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | volume (DOUBLE) | share_pct (DOUBLE) |
|---|---|---|---|
| 2026-09-09T00:00:00.000Z | COAST | 186330 | 40.2 |
| 2026-09-09T00:00:00.000Z | CITY | 182390 | 39.4 |
| 2026-09-09T00:00:00.000Z | VOLT | 94410 | 20.4 |
| 2026-09-10T00:00:00.000Z | COAST | 186200 | 45.3 |
| 2026-09-10T00:00:00.000Z | CITY | 183040 | 44.6 |
| 2026-09-10T00:00:00.000Z | VOLT | 41470 | 10.1 |

(6 rows)

<a id="order-by"></a>

## ORDER BY (window)

Syntax:

```sql
function(arguments) OVER ([PARTITION BY ...] ORDER BY expr [ASC | DESC] [, expr [ASC | DESC] ...] ...)
```

The order of the rows inside the window. It decides what "previous" means for `lag`, what a running total adds up, and who is first for `rank`.

- **Default:** without `ORDER BY`, time order (see the top of this page).
- **NULL:** rows where the order value is NULL come **last**, also with `DESC`. `NULLS FIRST` is accepted here but has no effect yet.
- **Notes:**
  - This `ORDER BY` only orders the window. The result rows need their own `ORDER BY` at the end of the query.
  - An aggregate with `ORDER BY` and no `ROWS` is a **running** value: from the first row to this row. When two rows have the same order value, KDB still adds them one at a time (PostgreSQL would give both rows the same total; in KDB write `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` for that, see [RANGE](#range)).
  - With `DESC`, `lead` looks at the row that comes next in the window, which is the **earlier** time.

**Example: Biggest volume first: rank the days of COAST** (sample data: sample)

```sql
SELECT time, volume, row_number() OVER (ORDER BY volume DESC) AS volume_rank
FROM ochl_day
WHERE symbol = 'COAST' AND time >= '2026-09-06'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | volume (DOUBLE) | volume_rank (LONG) |
|---|---|---|
| 2026-09-06T00:00:00.000Z | 143620 | 3 |
| 2026-09-07T00:00:00.000Z | 113010 | 4 |
| 2026-09-08T00:00:00.000Z | 60980 | 5 |
| 2026-09-09T00:00:00.000Z | 186330 | 1 |
| 2026-09-10T00:00:00.000Z | 186200 | 2 |

(5 rows)

**Example: Running total of the day's turnover, trade by trade** (sample data: sample)

```sql
SELECT transaction_id, symbol, amount,
       sum(amount) OVER (ORDER BY transaction_id) AS running_turnover
FROM trade_log
WHERE date IN '2026-09-09'
ORDER BY transaction_id;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | amount (DOUBLE) | running_turnover (DOUBLE) |
|---|---|---|---|
| 100001 | TELCO | 881000 | 881000 |
| 100002 | CITY | 5150 | 886150 |
| 100003 | CITY | 256500 | 1142650 |
| 100004 | CITY | 257250 | 1399900 |
| 100005 | CITY | 258500 | 1658400 |
| 100006 | COAST | 80200 | 1738600 |
| 100007 | TELCO | 879000 | 2617600 |
| 100008 | COAST | 7970 | 2625570 |

(8 rows)

<a id="rows-preceding"></a>

## ROWS n PRECEDING

Syntax:

```sql
aggregate(x) OVER ([PARTITION BY ...] [ORDER BY ...] ROWS n PRECEDING)
```

A **moving** window: this row and the `n` rows before it (so `n + 1` rows). `ROWS 4 PRECEDING` is a 5-day window. At the start of a series there are fewer rows before, and the window is smaller.

| Argument | Type | Meaning |
|---|---|---|
| `n` | whole number, 0 or more | how many rows before this row; `0` is only this row |

- **Notes:** the short form of `ROWS BETWEEN n PRECEDING AND CURRENT ROW`. It has an effect on aggregates only. The first rows use a smaller window, they are **not** NULL (unlike `sma`, which is NULL until it has `n` rows: see [sma](functions-indicators.md#sma)).

**Example: 5-day high, 5-day low and 3-day average volume** (sample data: sample)

```sql
SELECT time, symbol, close,
       max(high) OVER (PARTITION BY symbol ORDER BY time ROWS 4 PRECEDING) AS high_5d,
       min(low) OVER (PARTITION BY symbol ORDER BY time ROWS 4 PRECEDING) AS low_5d,
       round(avg(volume) OVER (PARTITION BY symbol ORDER BY time ROWS 2 PRECEDING)) AS avg_vol_3d
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-01'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | high_5d (DOUBLE) | low_5d (DOUBLE) | avg_vol_3d (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-01T00:00:00.000Z | CITY | 502.4 | 507.3 | 501.3 | 83000 |
| 2026-09-02T00:00:00.000Z | CITY | 496.4 | 507.3 | 494.1 | 91675 |
| 2026-09-03T00:00:00.000Z | CITY | 497.9 | 507.3 | 494.1 | 94783 |
| 2026-09-06T00:00:00.000Z | CITY | 499 | 507.3 | 494.1 | 92100 |
| 2026-09-07T00:00:00.000Z | CITY | 498.7 | 507.3 | 494.1 | 97677 |
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | 502.8 | 494.1 | 75477 |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 512.4 | 495 | 111290 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 512.4 | 495 | 133277 |

(8 rows)

**Example: The short form only goes back: for rows after, write BETWEEN** (sample data: sample; shows an error)

```sql
SELECT sum(volume) OVER (ORDER BY time ROWS 2 FOLLOWING) FROM ochl_day;
```

Result:

Error: `line 1, column 40: a frame that starts after the current row needs an end: write BETWEEN n FOLLOWING AND ...`

<a id="rows-unbounded"></a>

## ROWS UNBOUNDED PRECEDING

Syntax:

```sql
aggregate(x) OVER ([PARTITION BY ...] [ORDER BY ...] ROWS UNBOUNDED PRECEDING)
```

A **running** window: from the first row of the part to this row. It is the same as `ORDER BY` without `ROWS`, written out.

- **Notes:** a running `max(high)` is the highest price so far ("all-time high up to this day").

**Example: Highest high so far, and the running number of trading days** (sample data: sample)

```sql
SELECT time, high,
       max(high) OVER (ORDER BY time ROWS UNBOUNDED PRECEDING) AS high_so_far,
       count(*) OVER (ORDER BY time ROWS UNBOUNDED PRECEDING) AS day_no
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-09-01'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | high (DOUBLE) | high_so_far (DOUBLE) | day_no (LONG) |
|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 172.1 | 172.1 | 1 |
| 2026-09-02T00:00:00.000Z | 174.6 | 174.6 | 2 |
| 2026-09-03T00:00:00.000Z | 177.3 | 177.3 | 3 |
| 2026-09-06T00:00:00.000Z | 183.9 | 183.9 | 4 |
| 2026-09-07T00:00:00.000Z | 183.2 | 183.9 | 5 |
| 2026-09-08T00:00:00.000Z | 183.5 | 183.9 | 6 |
| 2026-09-09T00:00:00.000Z | 189.5 | 189.5 | 7 |
| 2026-09-10T00:00:00.000Z | 192.1 | 192.1 | 8 |

(8 rows)

<a id="rows-between"></a>

## ROWS BETWEEN n PRECEDING AND CURRENT ROW

Syntax:

```sql
aggregate(x) OVER ([PARTITION BY ...] [ORDER BY ...] ROWS BETWEEN n PRECEDING AND CURRENT ROW)
aggregate(x) OVER ([PARTITION BY ...] [ORDER BY ...] ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
```

The long, standard SQL way to write `ROWS n PRECEDING` and `ROWS UNBOUNDED PRECEDING`. Both forms give the same result. With `BETWEEN`, the end can also be after this row: see [ROWS BETWEEN ... FOLLOWING](#rows-following).

**Example: Long and short form give the same moving sum** (sample data: sample)

```sql
SELECT time, volume,
       sum(volume) OVER (ORDER BY time ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS long_form,
       sum(volume) OVER (ORDER BY time ROWS 2 PRECEDING) AS short_form
FROM ochl_day
WHERE symbol = 'COAST' AND time >= '2026-09-06'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | volume (DOUBLE) | long_form (DOUBLE) | short_form (DOUBLE) |
|---|---|---|---|
| 2026-09-06T00:00:00.000Z | 143620 | 143620 | 143620 |
| 2026-09-07T00:00:00.000Z | 113010 | 256630 | 256630 |
| 2026-09-08T00:00:00.000Z | 60980 | 317610 | 317610 |
| 2026-09-09T00:00:00.000Z | 186330 | 360320 | 360320 |
| 2026-09-10T00:00:00.000Z | 186200 | 433510 | 433510 |

(5 rows)

**Example: The end of the frame cannot be before its start** (sample data: sample; shows an error)

```sql
SELECT sum(volume) OVER (ORDER BY time ROWS BETWEEN CURRENT ROW AND 2 PRECEDING) FROM ochl_day;
```

Result:

Error: `line 1, column 40: the frame ends before it starts; expected the end bound after the start bound`

<a id="rows-following"></a>

## ROWS BETWEEN ... FOLLOWING

Syntax:

```sql
aggregate(x) OVER ([PARTITION BY ...] [ORDER BY ...] ROWS BETWEEN start AND end)

start:  UNBOUNDED PRECEDING | n PRECEDING | CURRENT ROW | n FOLLOWING
end:    n PRECEDING | CURRENT ROW | n FOLLOWING | UNBOUNDED FOLLOWING
```

A frame that also reads rows **after** this row. `n FOLLOWING` is `n` rows after this row; `UNBOUNDED FOLLOWING` is up to the last row of the part. `ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING` is a **centered** moving window of 5 rows: this row is in the middle.

| Argument | Type | Meaning |
|---|---|---|
| `n` | whole number, 0 or more | how many rows before (`PRECEDING`) or after (`FOLLOWING`) this row |

- **NULL:** NULL values are skipped, as in the plain aggregate. A frame with no rows (for example `1 FOLLOWING AND 3 FOLLOWING` on the last row) gives `NULL` (`count` gives `0`).
- **Notes:**
  - Near the start and the end of a part, the frame is smaller; it is not NULL.
  - The end must not be before the start. A frame cannot start with `UNBOUNDED FOLLOWING`, and `ROWS n FOLLOWING` alone is an error: write `ROWS BETWEEN n FOLLOWING AND ...`.
  - Careful with trading signals: a value that reads future rows is fine for a chart, but a real trader did not know those prices yet.

**Example: Centered 5-day average, volume still to come, and the best close of the next 3 days** (sample data: sample)

```sql
SELECT time, close,
       round(avg(close) OVER (ORDER BY time ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING), 2) AS centered_avg,
       sum(volume) OVER (ORDER BY time ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS volume_from_here,
       max(close) OVER (ORDER BY time ROWS BETWEEN 1 FOLLOWING AND 3 FOLLOWING) AS next_3_days_max
FROM ochl_day
WHERE symbol = 'COAST' AND time >= '2026-09-01'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | centered_avg (DOUBLE) | volume_from_here (DOUBLE) | next_3_days_max (DOUBLE) |
|---|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 367.4 | 369.93 | 910270 | 375.4 |
| 2026-09-02T00:00:00.000Z | 369.2 | 371.3 | 844060 | 379.2 |
| 2026-09-03T00:00:00.000Z | 373.2 | 372.88 | 772910 | 379.2 |
| 2026-09-06T00:00:00.000Z | 375.4 | 374.84 | 690140 | 380.1 |
| 2026-09-07T00:00:00.000Z | 379.2 | 377.02 | 546520 | 380.1 |
| 2026-09-08T00:00:00.000Z | 377.2 | 377.6 | 433510 | 380.1 |
| 2026-09-09T00:00:00.000Z | 380.1 | 378.15 | 372530 | 376.1 |
| 2026-09-10T00:00:00.000Z | 376.1 | 377.8 | 186200 | NULL |

(8 rows)

**Example: Each day's share of the symbol's volume over all shown days (the full frame)** (sample data: sample)

```sql
SELECT time, symbol, volume,
       round(volume * 100.0 / sum(volume) OVER (PARTITION BY symbol ORDER BY time
                                                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING), 1) AS share_of_days_pct
FROM ochl_day
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | volume (DOUBLE) | share_of_days_pct (DOUBLE) |
|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 34400 | 8.6 |
| 2026-09-09T00:00:00.000Z | CITY | 182390 | 45.6 |
| 2026-09-10T00:00:00.000Z | CITY | 183040 | 45.8 |
| 2026-09-08T00:00:00.000Z | COAST | 60980 | 14.1 |
| 2026-09-09T00:00:00.000Z | COAST | 186330 | 43 |
| 2026-09-10T00:00:00.000Z | COAST | 186200 | 43 |
| 2026-09-08T00:00:00.000Z | VOLT | 136770 | 50.2 |
| 2026-09-09T00:00:00.000Z | VOLT | 94410 | 34.6 |
| 2026-09-10T00:00:00.000Z | VOLT | 41470 | 15.2 |

(9 rows)

<a id="range"></a>

## RANGE BETWEEN

Syntax:

```sql
aggregate(x) OVER ([PARTITION BY ...] ORDER BY value RANGE BETWEEN start AND end)
aggregate(x) OVER ([PARTITION BY ...] ORDER BY value RANGE distance PRECEDING)

distance:  number | 'interval text' | INTERVAL 'interval text'
```

A frame by **value**, not by row count. `RANGE BETWEEN '7 days' PRECEDING AND CURRENT ROW` reads every row whose time is at most 7 days before this row's time. This is what you want when rows are missing: a week has 5 trading days, and holidays make it fewer, so `ROWS 6 PRECEDING` is not always "one week".

| Part | Meaning |
|---|---|
| `n PRECEDING`, `n FOLLOWING` | rows whose `ORDER BY` value is at most `n` before or after this row's value |
| `'7 days'`, `INTERVAL '1 hour'` | a distance of time, for a `TIMESTAMP` or `DATE` `ORDER BY` value. Units: `ms`, `s`/`seconds`, `m`/`minutes`, `h`/`hours`, `d`/`days`, `w`/`weeks` |
| a plain number | milliseconds for a `TIMESTAMP`, days for a `DATE`, the value itself for a number |
| `CURRENT ROW` | this row **and its peers**: the rows with the same `ORDER BY` value |

- **NULL:** NULL values of `x` are skipped. Rows whose `ORDER BY` value is NULL are only peers of each other.
- **Notes:**
  - A distance needs exactly **one** `ORDER BY` value, and it must be a number or a time.
  - `'1 month'` and `'1 year'` are refused: they have no fixed length.
  - The distance must be 0 or more. With `ORDER BY ... DESC`, `PRECEDING` means the later times.
  - `RANGE '2 days' PRECEDING` (without BETWEEN) is short for `RANGE BETWEEN '2 days' PRECEDING AND CURRENT ROW`.

**Example: 7-day window by time against 7 rows: holidays make the difference** (sample data: sample)

```sql
SELECT time, close,
       count(*) OVER (ORDER BY time RANGE BETWEEN '7 days' PRECEDING AND CURRENT ROW) AS rows_in_7_days,
       round(avg(close) OVER (ORDER BY time RANGE BETWEEN '7 days' PRECEDING AND CURRENT ROW), 2) AS avg_7_days,
       count(*) OVER (ORDER BY time ROWS 6 PRECEDING) AS rows_in_7_rows
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | rows_in_7_days (LONG) | avg_7_days (DOUBLE) | rows_in_7_rows (LONG) |
|---|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 507.9 | 1 | 507.9 | 1 |
| 2026-08-24T00:00:00.000Z | 510.3 | 2 | 509.1 | 2 |
| 2026-08-25T00:00:00.000Z | 513.3 | 3 | 510.5 | 3 |
| 2026-08-26T00:00:00.000Z | 513.2 | 4 | 511.18 | 4 |
| 2026-08-27T00:00:00.000Z | 505.9 | 5 | 510.12 | 5 |
| 2026-08-30T00:00:00.000Z | 503.1 | 6 | 508.95 | 6 |
| 2026-08-31T00:00:00.000Z | 505.7 | 6 | 508.58 | 7 |
| 2026-09-01T00:00:00.000Z | 502.4 | 6 | 507.27 | 7 |
| 2026-09-02T00:00:00.000Z | 496.4 | 6 | 504.45 | 7 |
| 2026-09-03T00:00:00.000Z | 497.9 | 6 | 501.9 | 7 |
| 2026-09-06T00:00:00.000Z | 499 | 6 | 500.75 | 7 |
| 2026-09-07T00:00:00.000Z | 498.7 | 6 | 500.02 | 7 |
| 2026-09-08T00:00:00.000Z | 497.5 | 6 | 498.65 | 7 |
| 2026-09-09T00:00:00.000Z | 504.6 | 6 | 499.02 | 7 |
| 2026-09-10T00:00:00.000Z | 504.9 | 6 | 500.43 | 7 |

(15 rows)

**Example: Volume of the last hour, for every minute** (sample data: sample)

```sql
SELECT time, close,
       sum(volume) OVER (ORDER BY time RANGE BETWEEN INTERVAL '1 hour' PRECEDING AND CURRENT ROW) AS volume_last_hour
FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10'
ORDER BY time DESC
LIMIT 3;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume_last_hour (DOUBLE) |
|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 49370 |
| 2026-09-10T09:13:00.000Z | 376.2 | 49320 |
| 2026-09-10T09:12:00.000Z | 376 | 48630 |

(3 rows)

**Example: Numbers: trades of a similar size, and running totals where ties share one total** (sample data: sample)

```sql
SELECT transaction_id, quantity,
       count(*) OVER (ORDER BY quantity RANGE BETWEEN 10 PRECEDING AND 10 FOLLOWING) AS similar_trades,
       sum(quantity) OVER (ORDER BY quantity RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_with_peers,
       sum(quantity) OVER (ORDER BY quantity) AS running_row_by_row
FROM trade_log
WHERE symbol = 'COAST'
ORDER BY quantity, transaction_id;
```

Result:

| transaction_id (LONG) | quantity (LONG) | similar_trades (LONG) | running_with_peers (LONG) | running_row_by_row (LONG) |
|---|---|---|---|---|
| 100019 | 10 | 4 | 10 | 10 |
| 100008 | 20 | 4 | 70 | 30 |
| 100014 | 20 | 4 | 70 | 50 |
| 100028 | 20 | 4 | 70 | 70 |
| 100009 | 50 | 2 | 170 | 120 |
| 100013 | 50 | 2 | 170 | 170 |
| 100006 | 200 | 2 | 570 | 370 |
| 100026 | 200 | 2 | 570 | 570 |
| 100023 | 500 | 1 | 1070 | 1070 |
| 100015 | 1000 | 2 | 3070 | 2070 |
| 100031 | 1000 | 2 | 3070 | 3070 |

(11 rows)

**Example: Months have no fixed length** (sample data: sample; shows an error)

```sql
SELECT sum(volume) OVER (ORDER BY time RANGE BETWEEN '1 month' PRECEDING AND CURRENT ROW) FROM ochl_day;
```

Result:

Error: `line 1, column 8: sum: '1 month' is not a distance like '5 days', '2 hours' or '30 minutes' (months and years are not supported)`

## lag

Syntax:

```sql
lag(x)
lag(x, k)
lag(x, k) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The value of `x` in the row `k` places **before** this row in the series. `lag(close)` is the previous close.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the value to take |
| `k` | whole number, 1 or more | how many rows back; default `1` |

- **Returns:** the type of `x`.
- **NULL:** `NULL` for the first `k` rows (there is no row before). A NULL value is taken as it is.
- **Notes:** `k` must be a whole number of 1 or more, else the error `the period must be a whole number of rows`.

**Example: Gap up or down: today's open against yesterday's close** (sample data: sample)

```sql
SELECT time, symbol, open, prev_close, round(open - prev_close, 2) AS gap
FROM (SELECT time, symbol, open, lag(close) OVER (PARTITION BY symbol ORDER BY time) AS prev_close
      FROM ochl_day
      WHERE time >= '2026-09-06') t
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | prev_close (DOUBLE) | gap (DOUBLE) |
|---|---|---|---|---|
| 2026-09-06T00:00:00.000Z | CITY | 497.4 | NULL | NULL |
| 2026-09-07T00:00:00.000Z | CITY | 497.3 | 499 | -1.7 |
| 2026-09-08T00:00:00.000Z | CITY | 498.2 | 498.7 | -0.5 |
| 2026-09-09T00:00:00.000Z | CITY | 512 | 497.5 | 14.5 |
| 2026-09-10T00:00:00.000Z | CITY | 504.6 | 504.6 | 0 |
| 2026-09-06T00:00:00.000Z | COAST | 374.6 | NULL | NULL |
| 2026-09-07T00:00:00.000Z | COAST | 373.7 | 375.4 | -1.7 |
| 2026-09-08T00:00:00.000Z | COAST | 379.8 | 379.2 | 0.6 |
| 2026-09-09T00:00:00.000Z | COAST | 398 | 377.2 | 20.8 |
| 2026-09-10T00:00:00.000Z | COAST | 380.1 | 380.1 | 0 |
| 2026-09-06T00:00:00.000Z | VOLT | 174.2 | NULL | NULL |
| 2026-09-07T00:00:00.000Z | VOLT | 181.4 | 180.1 | 1.3 |
| 2026-09-08T00:00:00.000Z | VOLT | 178.7 | 176.9 | 1.8 |
| 2026-09-09T00:00:00.000Z | VOLT | 182 | 182.4 | -0.4 |
| 2026-09-10T00:00:00.000Z | VOLT | 185.6 | 187.3 | -1.7 |

(15 rows)

**Example: Close of 3 days ago** (sample data: sample)

```sql
SELECT time, close, lag(close, 3) AS close_3_days_ago
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-01'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | close_3_days_ago (DOUBLE) |
|---|---|---|
| 2026-09-01T00:00:00.000Z | 502.4 | NULL |
| 2026-09-02T00:00:00.000Z | 496.4 | NULL |
| 2026-09-03T00:00:00.000Z | 497.9 | NULL |
| 2026-09-06T00:00:00.000Z | 499 | 502.4 |
| 2026-09-07T00:00:00.000Z | 498.7 | 496.4 |
| 2026-09-08T00:00:00.000Z | 497.5 | 497.9 |
| 2026-09-09T00:00:00.000Z | 504.6 | 499 |
| 2026-09-10T00:00:00.000Z | 504.9 | 498.7 |

(8 rows)

**Example: lag cannot be used in WHERE: use a subquery** (sample data: sample; shows an error)

```sql
SELECT time, close FROM ochl_day WHERE close > lag(close);
```

Result:

Error: `line 1, column 48: 'lag' works over a series of rows and can only be used in a SELECT list`

## lead

Syntax:

```sql
lead(x)
lead(x, k)
lead(x, k) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The value of `x` in the row `k` places **after** this row. `lead(close)` is the next day's close. Useful to test a signal: "what happened the day after?"

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the value to take |
| `k` | whole number, 1 or more | how many rows forward; default `1` |

- **Returns:** the type of `x`.
- **NULL:** `NULL` for the last `k` rows.

**Example: Next day's close after each day** (sample data: sample)

```sql
SELECT time, symbol, close,
       lead(close) OVER (PARTITION BY symbol ORDER BY time) AS next_close
FROM ochl_day
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | next_close (DOUBLE) |
|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | 504.6 |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 504.9 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | NULL |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | 380.1 |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 376.1 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | NULL |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | 187.3 |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 191.2 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | NULL |

(9 rows)

**Example: Minutes between forum posts of a thread** (sample data: content-forum)

```sql
SELECT id, author, created_at,
       (lead(created_at) OVER (PARTITION BY thread_id ORDER BY created_at) - created_at) / 60000 AS minutes_to_next
FROM posts
ORDER BY thread_id, created_at;
```

Result:

| id (LONG) | author (STRING) | created_at (TIMESTAMP) | minutes_to_next (DOUBLE) |
|---|---|---|---|
| 1 | ram | 2026-09-01T04:15:00.000Z | 5 |
| 2 | sita | 2026-09-01T04:20:00.000Z | 15 |
| 3 | hari | 2026-09-01T04:35:00.000Z | 40 |
| 4 | gita | 2026-09-01T05:15:00.000Z | 30 |
| 5 | ram | 2026-09-01T05:45:00.000Z | 30 |
| 6 | sita | 2026-09-01T06:15:00.000Z | NULL |
| 7 | hari | 2026-09-02T03:15:00.000Z | 10 |
| 8 | gita | 2026-09-02T03:25:00.000Z | NULL |

(8 rows)

## cumsum

Syntax:

```sql
cumsum(x)
cumsum(x) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **running total**: the sum of `x` from the first row of the series to this row.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value to add |

- **Returns:** `LONG` when every value is a whole number, else `DOUBLE` (also for `DECIMAL`: use `sum(x) OVER (ORDER BY ...)` to keep a DECIMAL exact).
- **NULL:** NULL values are skipped: the total stays the same. Before the first value that is not NULL, the result is `NULL`.
- **Notes:** the same as `sum(x) OVER ([PARTITION BY ...] ORDER BY ...)`.

**Example: Running volume per symbol** (sample data: sample)

```sql
SELECT time, symbol, volume,
       cumsum(volume) OVER (PARTITION BY symbol ORDER BY time) AS running_volume
FROM ochl_day
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | volume (DOUBLE) | running_volume (DOUBLE) |
|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 34400 | 34400 |
| 2026-09-09T00:00:00.000Z | CITY | 182390 | 216790 |
| 2026-09-10T00:00:00.000Z | CITY | 183040 | 399830 |
| 2026-09-08T00:00:00.000Z | COAST | 60980 | 60980 |
| 2026-09-09T00:00:00.000Z | COAST | 186330 | 247310 |
| 2026-09-10T00:00:00.000Z | COAST | 186200 | 433510 |
| 2026-09-08T00:00:00.000Z | VOLT | 136770 | 136770 |
| 2026-09-09T00:00:00.000Z | VOLT | 94410 | 231180 |
| 2026-09-10T00:00:00.000Z | VOLT | 41470 | 272650 |

(9 rows)

**Example: Running balance of the bank account** (sample data: query-app)

```sql
SELECT line_id, memo, debit, credit,
       sum(debit) OVER (ORDER BY line_id) AS money_in_so_far,
       round(cumsum(coalesce(debit, 0) - coalesce(credit, 0)) OVER (ORDER BY line_id), 2) AS balance
FROM ledger
WHERE account = 1100
ORDER BY line_id;
```

Result:

| line_id (INT) | memo (STRING) | debit (DECIMAL(2)) | credit (DECIMAL(2)) | money_in_so_far (DECIMAL(2)) | balance (DOUBLE) |
|---|---|---|---|---|---|
| 1 | Owner puts money in the bank | 500000.00 | NULL | 500000.00 | 500000 |
| 6 | Pay the broker | NULL | 257500.00 | 500000.00 | 242500 |
| 8 | Commission on the CITY buy | NULL | 1030.00 | 500000.00 | 241470 |
| 10 | Take cash from the bank | NULL | 30000.00 | 500000.00 | 211470 |
| 13 | CITY cash dividend | 6250.00 | NULL | 506250.00 | 217720 |
| 15 | Sell 20 CITY at 630 | 12600.00 | NULL | 518850.00 | 230320 |

(6 rows)

**Example: New app users so far, per Nepal day** (sample data: fn-dates)

```sql
SELECT day, signups, cumsum(signups) AS total_users
FROM (SELECT to_date(created_at + 20700000) AS day, count(*) AS signups
      FROM signups
      GROUP BY to_date(created_at + 20700000)) t
ORDER BY day;
```

Result:

| day (DATE) | signups (LONG) | total_users (LONG) |
|---|---|---|
| 2026-09-01 | 3 | 3 |
| 2026-09-02 | 2 | 5 |
| 2026-09-03 | 3 | 8 |
| 2026-09-04 | 1 | 9 |
| 2026-09-06 | 1 | 10 |

(5 rows)

## cumprod

Syntax:

```sql
cumprod(x)
cumprod(x) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **running product**: all values of `x` from the first row to this row, multiplied. Traders use it to **compound** returns: if a share rises 1% and then 2%, it grew by `1.01 × 1.02 = 1.0302`. So `cumprod(1 + return)` is what 1 dollar has grown to.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value to multiply |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values are skipped: the product stays the same. Before the first value that is not NULL, the result is `NULL`. A product too big for a `DOUBLE` is `NULL`.
- **Notes:** a window function cannot be inside another, so compute the return in a subquery first. For the growth in percent, [cum_return](functions-returns-risk.md#cum_return) is shorter.

**Example: Growth of 1 dollar in VOLT, day by day** (sample data: sample)

```sql
SELECT time, close, ratio, round(cumprod(ratio), 4) AS growth_of_1
FROM (SELECT time, close, close / lag(close) AS ratio
      FROM ochl_day
      WHERE symbol = 'VOLT' AND time >= '2026-09-01') t
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | ratio (DOUBLE) | growth_of_1 (DOUBLE) |
|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 169 | NULL | NULL |
| 2026-09-02T00:00:00.000Z | 171.5 | 1.01479289940828 | 1.0148 |
| 2026-09-03T00:00:00.000Z | 176 | 1.02623906705539 | 1.0414 |
| 2026-09-06T00:00:00.000Z | 180.1 | 1.02329545454545 | 1.0657 |
| 2026-09-07T00:00:00.000Z | 176.9 | 0.98223209328151 | 1.0467 |
| 2026-09-08T00:00:00.000Z | 182.4 | 1.03109101187111 | 1.0793 |
| 2026-09-09T00:00:00.000Z | 187.3 | 1.02686403508772 | 1.1083 |
| 2026-09-10T00:00:00.000Z | 191.2 | 1.02082221035771 | 1.1314 |

(8 rows)

**Example: Text cannot be multiplied** (sample data: sample; shows an error)

```sql
SELECT cumprod(symbol) FROM ochl_day;
```

Result:

Error: `line 1, column 8: cumprod: needs numbers, got 'CITY'`

## cummax

Syntax:

```sql
cummax(x)
cummax(x) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **running maximum**: the biggest value of `x` from the first row to this row. On prices it is the "highest so far". Works for numbers, text and times.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number, text or time | the value |

- **Returns:** the type of `x`.
- **NULL:** NULL values are skipped. Before the first value that is not NULL, the result is `NULL`.
- **Notes:** the same as `max(x) OVER ([PARTITION BY ...] ORDER BY ...)`. Values of different kinds (a number and a text) give an error. For the fall from the highest price in percent, see [drawdown](functions-returns-risk.md#drawdown).

**Example: Record volume days, and how far the close is below its high so far** (sample data: sample)

```sql
SELECT time, volume, cummax(volume) AS record_volume,
       CASE WHEN volume = cummax(volume) THEN 'new record' END AS note,
       round(close / cummax(close) * 100 - 100, 2) AS below_high_pct
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | volume (DOUBLE) | record_volume (DOUBLE) | note (STRING) | below_high_pct (DOUBLE) |
|---|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 125050 | 125050 | new record | 0 |
| 2026-08-24T00:00:00.000Z | 130800 | 130800 | new record | 0 |
| 2026-08-25T00:00:00.000Z | 84980 | 130800 | NULL | 0 |
| 2026-08-26T00:00:00.000Z | 138310 | 138310 | new record | -0.02 |
| 2026-08-27T00:00:00.000Z | 122630 | 138310 | NULL | -1.44 |
| 2026-08-30T00:00:00.000Z | 94540 | 138310 | NULL | -1.99 |
| 2026-08-31T00:00:00.000Z | 159240 | 159240 | new record | -1.48 |
| 2026-09-01T00:00:00.000Z | 83000 | 159240 | NULL | -2.12 |
| 2026-09-02T00:00:00.000Z | 100350 | 159240 | NULL | -3.29 |
| 2026-09-03T00:00:00.000Z | 101000 | 159240 | NULL | -3 |
| 2026-09-06T00:00:00.000Z | 74950 | 159240 | NULL | -2.79 |
| 2026-09-07T00:00:00.000Z | 117080 | 159240 | NULL | -2.84 |
| 2026-09-08T00:00:00.000Z | 34400 | 159240 | NULL | -3.08 |
| 2026-09-09T00:00:00.000Z | 182390 | 182390 | new record | -1.69 |
| 2026-09-10T00:00:00.000Z | 183040 | 183040 | new record | -1.64 |

(15 rows)

**Example: The latest login so far, going through the users by id** (sample data: query-app)

```sql
SELECT id, username, last_login, cummax(last_login) OVER (ORDER BY id) AS latest_so_far
FROM app_users
ORDER BY id;
```

Result:

| id (INT) | username (STRING) | last_login (TIMESTAMP) | latest_so_far (TIMESTAMP) |
|---|---|---|---|
| 1 | ram | 2026-09-10T14:30:00.000Z | 2026-09-10T14:30:00.000Z |
| 2 | sita | 2026-09-09T02:15:00.000Z | 2026-09-10T14:30:00.000Z |
| 3 | hari_99 | NULL | 2026-09-10T14:30:00.000Z |
| 4 | gita | 2026-09-11T00:45:00.000Z | 2026-09-11T00:45:00.000Z |
| 5 | bikash | 2026-09-11T04:20:00.000Z | 2026-09-11T04:20:00.000Z |
| 6 | anita | 2026-08-30T06:15:00.000Z | 2026-09-11T04:20:00.000Z |
| 7 | suman | 2026-09-10T03:55:00.000Z | 2026-09-11T04:20:00.000Z |
| 8 | test_user | NULL | 2026-09-11T04:20:00.000Z |

(8 rows)

## cummin

Syntax:

```sql
cummin(x)
cummin(x) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **running minimum**: the smallest value of `x` from the first row to this row ("lowest so far"). Works for numbers, text and times.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number, text or time | the value |

- **Returns:** the type of `x`.
- **NULL:** NULL values are skipped. Before the first value that is not NULL, the result is `NULL`.
- **Notes:** the same as `min(x) OVER ([PARTITION BY ...] ORDER BY ...)`. Values of different kinds give an error.

**Example: Lowest low so far per symbol, and the bounce from it** (sample data: sample)

```sql
SELECT time, symbol, low, close, low_so_far, round((close - low_so_far) / low_so_far * 100, 2) AS above_low_pct
FROM (SELECT time, symbol, low, close,
             cummin(low) OVER (PARTITION BY symbol ORDER BY time) AS low_so_far
      FROM ochl_day
      WHERE time >= '2026-09-01') t
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | low (DOUBLE) | close (DOUBLE) | low_so_far (DOUBLE) | above_low_pct (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | 497.5 | 494.1 | 0.69 |
| 2026-09-09T00:00:00.000Z | CITY | 504 | 504.6 | 494.1 | 2.13 |
| 2026-09-10T00:00:00.000Z | CITY | 500.7 | 504.9 | 494.1 | 2.19 |
| 2026-09-08T00:00:00.000Z | COAST | 374.7 | 377.2 | 364.1 | 3.6 |
| 2026-09-09T00:00:00.000Z | COAST | 379.2 | 380.1 | 364.1 | 4.39 |
| 2026-09-10T00:00:00.000Z | COAST | 373.2 | 376.1 | 364.1 | 3.3 |
| 2026-09-08T00:00:00.000Z | VOLT | 178.2 | 182.4 | 167.3 | 9.03 |
| 2026-09-09T00:00:00.000Z | VOLT | 181.7 | 187.3 | 167.3 | 11.95 |
| 2026-09-10T00:00:00.000Z | VOLT | 184.2 | 191.2 | 167.3 | 14.29 |

(9 rows)

## pct_change

Syntax:

```sql
pct_change(x)
pct_change(x) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The change from the previous row, in percent: `(x - previous) / previous × 100`. On daily closes this is the **daily return**.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the value |

- **Returns:** `DOUBLE` (`2.5` means +2.5%).
- **NULL:** `NULL` for the first row, when this or the previous value is NULL, and when the previous value is `0`.

**Example: Daily return of every symbol** (sample data: sample)

```sql
SELECT time, symbol, close,
       round(pct_change(close) OVER (PARTITION BY symbol ORDER BY time), 2) AS return_pct
FROM ochl_day
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | return_pct (DOUBLE) |
|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | NULL |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 1.43 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 0.06 |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | NULL |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 0.77 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | -1.05 |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | NULL |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 2.69 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 2.08 |

(9 rows)

**Example: Growth of forum posts week by week** (sample data: fn-dates)

```sql
SELECT week, posts, round(pct_change(posts), 1) AS growth_pct
FROM (SELECT date_trunc('week', created_at) AS week, count(*) AS posts
      FROM forum_posts
      GROUP BY date_trunc('week', created_at)) t
ORDER BY week;
```

Result:

| week (TIMESTAMP) | posts (LONG) | growth_pct (DOUBLE) |
|---|---|---|
| 2026-08-16T00:00:00.000Z | 3 | NULL |
| 2026-08-23T00:00:00.000Z | 4 | 33.3 |
| 2026-08-30T00:00:00.000Z | 3 | -25 |
| 2026-09-06T00:00:00.000Z | 4 | 33.3 |

(4 rows)

## row_number

Syntax:

```sql
row_number()
row_number() OVER ([PARTITION BY ...] [ORDER BY ...])
```

Numbers the rows of each part: 1, 2, 3, ... Equal values still get different numbers.

- **Returns:** `LONG`.
- **Notes:** takes no argument. For rows with equal order values, which one gets the lower number follows their storage order; add a second `ORDER BY` value (like `time`) to make it fixed. Use it with a subquery for "top N per group".

**Example: Top 2 trades by amount per symbol** (sample data: sample)

```sql
SELECT symbol, pos, transaction_id, quantity, rate, amount
FROM (SELECT symbol, transaction_id, quantity, rate, amount,
             row_number() OVER (PARTITION BY symbol ORDER BY amount DESC, transaction_id) AS pos
      FROM trade_log) t
WHERE pos <= 2
ORDER BY symbol, pos;
```

Result:

| symbol (SYMBOL) | pos (LONG) | transaction_id (LONG) | quantity (LONG) | rate (DOUBLE) | amount (DOUBLE) |
|---|---|---|---|---|---|
| CITY | 1 | 100005 | 500 | 517 | 258500 |
| CITY | 2 | 100018 | 500 | 516 | 258000 |
| COAST | 1 | 100031 | 1000 | 402 | 402000 |
| COAST | 2 | 100015 | 1000 | 398 | 398000 |
| TELCO | 1 | 100001 | 1000 | 881 | 881000 |
| TELCO | 2 | 100007 | 1000 | 879 | 879000 |
| VOLT | 1 | 100012 | 200 | 184 | 36800 |
| VOLT | 2 | 100020 | 100 | 187 | 18700 |

(8 rows)

**Example: Page numbers for a list of forum posts: 3 posts per page** (sample data: content-forum)

```sql
SELECT id, author, floor((row_number() OVER (ORDER BY created_at) - 1) / 3) + 1 AS page
FROM posts
ORDER BY created_at;
```

Result:

| id (LONG) | author (STRING) | page (DOUBLE) |
|---|---|---|
| 1 | ram | 1 |
| 2 | sita | 1 |
| 3 | hari | 1 |
| 4 | gita | 2 |
| 5 | ram | 2 |
| 6 | sita | 2 |
| 7 | hari | 3 |
| 8 | gita | 3 |

(8 rows)

## rank

Syntax:

```sql
rank()
rank() OVER ([PARTITION BY ...] ORDER BY ...)
```

The place of the row in the window's order. Equal values get the **same** rank, and the next rank **skips**: 1, 1, 3.

- **Returns:** `LONG`.
- **Notes:** takes no argument (`rank(close)` is an error). Two rows tie when all their `ORDER BY` values are equal. Without `ORDER BY`, rows with the same time tie.

**Example: Rank the day's trades of COAST by quantity (ties share a rank)** (sample data: sample)

```sql
SELECT transaction_id, buyer, quantity,
       rank() OVER (ORDER BY quantity DESC) AS rank,
       dense_rank() OVER (ORDER BY quantity DESC) AS dense_rank,
       row_number() OVER (ORDER BY quantity DESC, transaction_id) AS row_number
FROM trade_log
WHERE date IN '2026-09-10' AND symbol = 'COAST'
ORDER BY quantity DESC, transaction_id;
```

Result:

| transaction_id (LONG) | buyer (INT) | quantity (LONG) | rank (LONG) | dense_rank (LONG) | row_number (LONG) |
|---|---|---|---|---|---|
| 100015 | 49 | 1000 | 1 | 1 | 1 |
| 100031 | 45 | 1000 | 1 | 1 | 2 |
| 100023 | 58 | 500 | 3 | 2 | 3 |
| 100026 | 1 | 200 | 4 | 3 | 4 |
| 100009 | 34 | 50 | 5 | 4 | 5 |
| 100013 | 58 | 50 | 5 | 4 | 6 |
| 100014 | 45 | 20 | 7 | 5 | 7 |
| 100028 | 49 | 20 | 7 | 5 | 8 |
| 100019 | 58 | 10 | 9 | 6 | 9 |

(9 rows)

**Example: Biggest gainer of each day** (sample data: sample)

```sql
SELECT time, symbol, change_pct,
       rank() OVER (PARTITION BY time ORDER BY change_pct DESC) AS place
FROM (SELECT time, symbol, round((close - open) / open * 100, 2) AS change_pct
      FROM ochl_day
      WHERE time >= '2026-09-08') t
ORDER BY time, place;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | change_pct (DOUBLE) | place (LONG) |
|---|---|---|---|
| 2026-09-08T00:00:00.000Z | VOLT | 2.07 | 1 |
| 2026-09-08T00:00:00.000Z | CITY | -0.14 | 2 |
| 2026-09-08T00:00:00.000Z | COAST | -0.68 | 3 |
| 2026-09-09T00:00:00.000Z | VOLT | 2.91 | 1 |
| 2026-09-09T00:00:00.000Z | CITY | -1.45 | 2 |
| 2026-09-09T00:00:00.000Z | COAST | -4.5 | 3 |
| 2026-09-10T00:00:00.000Z | VOLT | 3.02 | 1 |
| 2026-09-10T00:00:00.000Z | CITY | 0.06 | 2 |
| 2026-09-10T00:00:00.000Z | COAST | -1.05 | 3 |

(9 rows)

## dense_rank

Syntax:

```sql
dense_rank()
dense_rank() OVER ([PARTITION BY ...] ORDER BY ...)
```

Like `rank`, but without gaps: equal values get the same rank, and the next rank is one more: 1, 1, 2.

- **Returns:** `LONG`.
- **Notes:** takes no argument. Use it for "price levels": every different price gets the next number.

**Example: Price levels of VOLT's trades** (sample data: sample)

```sql
SELECT transaction_id, rate,
       dense_rank() OVER (ORDER BY rate DESC) AS price_level,
       rank() OVER (ORDER BY rate DESC) AS rank
FROM trade_log
WHERE symbol = 'VOLT'
ORDER BY rate DESC, transaction_id;
```

Result:

| transaction_id (LONG) | rate (DOUBLE) | price_level (LONG) | rank (LONG) |
|---|---|---|---|
| 100020 | 187 | 1 | 1 |
| 100016 | 185 | 2 | 2 |
| 100011 | 184 | 3 | 3 |
| 100012 | 184 | 3 | 3 |

(4 rows)

<a id="percent_rank"></a>

## percent_rank

Syntax:

```sql
percent_rank()
percent_rank() OVER ([PARTITION BY ...] ORDER BY ...)
```

The place of the row as a part from 0 to 1: `(rank - 1) / (rows - 1)`. The first row is `0`, the last is `1`. `0.9` means "90% of the other rows come before this one". It is the **percentile rank**.

- **Returns:** `DOUBLE` from 0 to 1.
- **NULL:** never `NULL`. A part with one row gives `0`.
- **Notes:** takes no argument. Equal values (peers) get the same result, like `rank`. Without `ORDER BY` all rows are peers, so every row gets `0`.

**Example: Where does each COAST trade size stand? percent_rank, cume_dist and rank** (sample data: sample)

```sql
SELECT transaction_id, quantity,
       rank() OVER (ORDER BY quantity) AS rank,
       round(percent_rank() OVER (ORDER BY quantity), 2) AS percent_rank,
       round(cume_dist() OVER (ORDER BY quantity), 2) AS cume_dist
FROM trade_log
WHERE symbol = 'COAST'
ORDER BY quantity, transaction_id;
```

Result:

| transaction_id (LONG) | quantity (LONG) | rank (LONG) | percent_rank (DOUBLE) | cume_dist (DOUBLE) |
|---|---|---|---|---|
| 100019 | 10 | 1 | 0 | 0.09 |
| 100008 | 20 | 2 | 0.1 | 0.36 |
| 100014 | 20 | 2 | 0.1 | 0.36 |
| 100028 | 20 | 2 | 0.1 | 0.36 |
| 100009 | 50 | 5 | 0.4 | 0.55 |
| 100013 | 50 | 5 | 0.4 | 0.55 |
| 100006 | 200 | 7 | 0.6 | 0.73 |
| 100026 | 200 | 7 | 0.6 | 0.73 |
| 100023 | 500 | 9 | 0.8 | 0.82 |
| 100015 | 1000 | 10 | 0.9 | 1 |
| 100031 | 1000 | 10 | 0.9 | 1 |

(11 rows)

**Example: How high are the last closes among all September closes of the same symbol? (100 = the highest)** (sample data: sample)

```sql
SELECT time, symbol, close, percentile_rank
FROM (SELECT time, symbol, close,
             round(percent_rank() OVER (PARTITION BY symbol ORDER BY close) * 100) AS percentile_rank
      FROM ochl_day
      WHERE time >= '2026-09-01') t
WHERE time >= '2026-09-09'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | percentile_rank (DOUBLE) |
|---|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 86 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 100 |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 100 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 57 |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 86 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 100 |

(6 rows)

<a id="cume_dist"></a>

## cume_dist

Syntax:

```sql
cume_dist()
cume_dist() OVER ([PARTITION BY ...] ORDER BY ...)
```

The **cumulative distribution**: the part of the rows (from 0 to 1) whose value is at or before this row's value. `0.75` means "75% of the rows have this value or a smaller one".

- **Returns:** `DOUBLE`, more than 0 and at most 1.
- **NULL:** never `NULL`.
- **Notes:** takes no argument. Peers (equal values) all count, so the last peer's position is used: three trades of 20 among 11 trades after one smaller trade give `4 / 11`. Without `ORDER BY` every row gets `1`. See the example of [percent_rank](functions-window.md#percent_rank).

**Example: What part of the app users signed up by each day?** (sample data: fn-dates)

```sql
SELECT id, created_at, round(cume_dist() OVER (ORDER BY created_at) * 100) AS pct_of_users_so_far
FROM signups
ORDER BY created_at;
```

Result:

| id (INT) | created_at (TIMESTAMP) | pct_of_users_so_far (DOUBLE) |
|---|---|---|
| 1 | 2026-09-01T03:30:00.000Z | 10 |
| 2 | 2026-09-01T07:55:00.000Z | 20 |
| 3 | 2026-09-01T16:20:00.000Z | 30 |
| 4 | 2026-09-01T20:45:00.000Z | 40 |
| 5 | 2026-09-02T05:15:00.000Z | 50 |
| 6 | 2026-09-03T02:35:00.000Z | 60 |
| 7 | 2026-09-03T14:00:00.000Z | 70 |
| 8 | 2026-09-03T18:05:00.000Z | 80 |
| 9 | 2026-09-04T04:25:00.000Z | 90 |
| 10 | 2026-09-06T06:15:00.000Z | 100 |

(10 rows)

## ntile

Syntax:

```sql
ntile(n)
ntile(n) OVER ([PARTITION BY ...] ORDER BY ...)
```

Cuts the rows of each part into `n` groups of (almost) the same size, in window order, and gives the group number: 1 to `n`. `ntile(4)` gives **quartiles**, `ntile(10)` **deciles**.

| Argument | Type | Meaning |
|---|---|---|
| `n` | whole number, 1 or more | how many groups |

- **Returns:** `LONG` from 1 to `n`.
- **NULL:** never `NULL`.
- **Notes:** when the rows do not divide evenly, the first groups get one row more: 11 rows in 3 groups are 4, 4 and 3 rows. Equal values can land in different groups (it counts positions, not values). `n` must be a constant whole number of 1 or more.

**Example: Quartiles of COAST's September closes (1 = highest)** (sample data: sample)

```sql
SELECT time, close, ntile(4) OVER (ORDER BY close DESC) AS quartile
FROM ochl_day
WHERE symbol = 'COAST' AND time >= '2026-09-01'
ORDER BY close DESC;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | quartile (LONG) |
|---|---|---|
| 2026-09-09T00:00:00.000Z | 380.1 | 1 |
| 2026-09-07T00:00:00.000Z | 379.2 | 1 |
| 2026-09-08T00:00:00.000Z | 377.2 | 2 |
| 2026-09-10T00:00:00.000Z | 376.1 | 2 |
| 2026-09-06T00:00:00.000Z | 375.4 | 3 |
| 2026-09-03T00:00:00.000Z | 373.2 | 3 |
| 2026-09-02T00:00:00.000Z | 369.2 | 4 |
| 2026-09-01T00:00:00.000Z | 367.4 | 4 |

(8 rows)

**Example: Three groups of trades by size: 11 rows are 4 + 4 + 3** (sample data: sample)

```sql
SELECT transaction_id, quantity, ntile(3) OVER (ORDER BY quantity, transaction_id) AS size_group
FROM trade_log
WHERE symbol = 'COAST'
ORDER BY quantity, transaction_id;
```

Result:

| transaction_id (LONG) | quantity (LONG) | size_group (LONG) |
|---|---|---|
| 100019 | 10 | 1 |
| 100008 | 20 | 1 |
| 100014 | 20 | 1 |
| 100028 | 20 | 1 |
| 100009 | 50 | 2 |
| 100013 | 50 | 2 |
| 100006 | 200 | 2 |
| 100026 | 200 | 2 |
| 100023 | 500 | 3 |
| 100015 | 1000 | 3 |
| 100031 | 1000 | 3 |

(11 rows)

**Example: The number of groups must be 1 or more** (sample data: sample; shows an error)

```sql
SELECT ntile(0) OVER (ORDER BY close) FROM ochl_day;
```

Result:

Error: `line 1, column 8: ntile: the number of buckets must be a whole number (1 or more)`

<a id="first_value"></a>

## first_value

Syntax:

```sql
first_value(x)
first_value(x) OVER ([PARTITION BY ...] [ORDER BY ...] [ROWS | RANGE BETWEEN ... AND ...])
```

The value of `x` in the **first row of the frame**. With `OVER (PARTITION BY symbol ORDER BY time)` it is the first price of the symbol, on every row.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the value to take |

- **Returns:** the type of `x`.
- **NULL:** `NULL` when that row's value is NULL (NULL values are **not** skipped), or when the frame has no rows.
- **Notes:** it reads the frame. Without `OVER`, or without `ORDER BY`, the frame is the whole part. With `ORDER BY` and no frame, the frame runs from the first row to this row. `ROWS 4 PRECEDING` makes it the value of 4 rows ago (or the first row, near the start). The aggregate [first](functions-aggregate.md#first) gives one value per group instead.

**Example: Change since the first day of the series, per symbol** (sample data: sample)

```sql
SELECT time, symbol, close, start_close, round((close - start_close) / start_close * 100, 2) AS change_pct
FROM (SELECT time, symbol, close,
             first_value(close) OVER (PARTITION BY symbol ORDER BY time) AS start_close
      FROM ochl_day
      WHERE time >= '2026-09-01') t
WHERE time >= '2026-09-09'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | start_close (DOUBLE) | change_pct (DOUBLE) |
|---|---|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 502.4 | 0.44 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 502.4 | 0.5 |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 367.4 | 3.46 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 367.4 | 2.37 |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 169 | 10.83 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 169 | 13.14 |

(6 rows)

**Example: Open of each one-minute candle against the day's first open** (sample data: sample)

```sql
SELECT time, open, first_value(open) AS day_open, round(open - first_value(open), 1) AS from_day_open
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
ORDER BY time DESC
LIMIT 3;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | day_open (DOUBLE) | from_day_open (DOUBLE) |
|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 505.1 | 504.6 | 0.5 |
| 2026-09-10T09:13:00.000Z | 504.8 | 504.6 | 0.2 |
| 2026-09-10T09:12:00.000Z | 504.5 | 504.6 | -0.1 |

(3 rows)

<a id="last_value"></a>

## last_value

Syntax:

```sql
last_value(x)
last_value(x) OVER ([PARTITION BY ...] [ORDER BY ...] [ROWS | RANGE BETWEEN ... AND ...])
```

The value of `x` in the **last row of the frame**.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the value to take |

- **Returns:** the type of `x`.
- **NULL:** `NULL` when that row's value is NULL (NULL values are not skipped), or when the frame has no rows.
- **Notes:** **careful:** with `ORDER BY` and no frame, the frame ends at this row, so `last_value` is just this row's value (the same as PostgreSQL). For the last value of the whole part, write `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`, or leave out `ORDER BY`.

**Example: The trap: without a frame, last_value is this row** (sample data: sample)

```sql
SELECT time, close,
       last_value(close) OVER (ORDER BY time) AS this_row,
       last_value(close) OVER (ORDER BY time ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS latest_close,
       last_value(close) AS also_latest
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-06'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | this_row (DOUBLE) | latest_close (DOUBLE) | also_latest (DOUBLE) |
|---|---|---|---|---|
| 2026-09-06T00:00:00.000Z | 499 | 499 | 504.9 | 504.9 |
| 2026-09-07T00:00:00.000Z | 498.7 | 498.7 | 504.9 | 504.9 |
| 2026-09-08T00:00:00.000Z | 497.5 | 497.5 | 504.9 | 504.9 |
| 2026-09-09T00:00:00.000Z | 504.6 | 504.6 | 504.9 | 504.9 |
| 2026-09-10T00:00:00.000Z | 504.9 | 504.9 | 504.9 | 504.9 |

(5 rows)

**Example: How far each day's close is from the latest close, per symbol** (sample data: sample)

```sql
SELECT time, symbol, close, latest, round(latest - close, 1) AS to_latest
FROM (SELECT time, symbol, close,
             last_value(close) OVER (PARTITION BY symbol ORDER BY time
                                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS latest
      FROM ochl_day
      WHERE time >= '2026-09-08') t
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | latest (DOUBLE) | to_latest (DOUBLE) |
|---|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | 504.9 | 7.4 |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 504.9 | 0.3 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 504.9 | 0 |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | 376.1 | -1.1 |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 376.1 | -4 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 376.1 | 0 |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | 191.2 | 8.8 |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 191.2 | 3.9 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 191.2 | 0 |

(9 rows)

<a id="nth_value"></a>

## nth_value

Syntax:

```sql
nth_value(x, n)
nth_value(x, n) OVER ([PARTITION BY ...] [ORDER BY ...] [ROWS | RANGE BETWEEN ... AND ...])
```

The value of `x` in row number `n` of the frame (`1` is the first row).

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the value to take |
| `n` | whole number, 1 or more | which row of the frame |

- **Returns:** the type of `x`.
- **NULL:** `NULL` when the frame has fewer than `n` rows (so with `ORDER BY` and no frame, the first `n - 1` rows are NULL), or when that value is NULL.
- **Notes:** `nth_value(x, 1)` is `first_value(x)`. `n` must be a constant whole number of 1 or more.

**Example: The second day's close, from the second day on** (sample data: sample)

```sql
SELECT time, close, nth_value(close, 2) OVER (ORDER BY time) AS second_close
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-06'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | second_close (DOUBLE) |
|---|---|---|
| 2026-09-06T00:00:00.000Z | 499 | NULL |
| 2026-09-07T00:00:00.000Z | 498.7 | 498.7 |
| 2026-09-08T00:00:00.000Z | 497.5 | 498.7 |
| 2026-09-09T00:00:00.000Z | 504.6 | 498.7 |
| 2026-09-10T00:00:00.000Z | 504.9 | 498.7 |

(5 rows)

**Example: The second-biggest trade of each symbol, on every row** (sample data: sample)

```sql
SELECT DISTINCT symbol, second_biggest
FROM (SELECT symbol,
             nth_value(amount, 2) OVER (PARTITION BY symbol ORDER BY amount DESC
                                        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS second_biggest
      FROM trade_log) t
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | second_biggest (DOUBLE) |
|---|---|
| CITY | 258000 |
| COAST | 398000 |
| TELCO | 879000 |
| VOLT | 18700 |

(4 rows)

**Example: Row numbers start at 1** (sample data: sample; shows an error)

```sql
SELECT nth_value(close, 0) OVER (ORDER BY time) FROM ochl_day;
```

Result:

Error: `line 1, column 8: nth_value: the row number must be a whole number (1 or more)`

<a id="aggregates"></a>

## Aggregates with OVER

Syntax:

```sql
count(*) OVER (...)    count(x) OVER (...)    sum(x) OVER (...)    avg(x) OVER (...)
min(x) OVER (...)      max(x) OVER (...)      first(x) OVER (...)  last(x) OVER (...)
median(x) OVER (...)   percentile(x, p) OVER (...)   stddev(x) OVER (...)   vwap(price, volume) OVER (...)
```

Every aggregate ([aggregate functions](functions-aggregate.md), [statistics](functions-statistics.md)) can be a window function, also the newer ones like `count_if`, `corr` or `sharpe_ratio`. It then gives a value for every row, computed over the row's window.

| Window | What you get |
|---|---|
| `OVER ()` or `OVER (PARTITION BY ...)` | the total of the whole part on every row (share of total, difference from the average) |
| `OVER (... ORDER BY ...)` | a running value: running total, highest so far |
| `OVER (... ORDER BY ... ROWS n PRECEDING)` | a moving value: 5-day sum, 20-day high, moving VWAP |

- **NULL:** NULL values are skipped, as in the plain aggregate.
- **Notes:** the window version works on the rows the `SELECT` gives: the table's rows, or the groups when there is a `GROUP BY` (then use aggregates inside it, as in `avg(sum(qty)) OVER ()`). `first` and `last` use the window's order.

**Example: Distance from the symbol's average close** (sample data: sample)

```sql
SELECT time, symbol, close,
       round(avg(close) OVER (PARTITION BY symbol), 2) AS avg_close,
       round(close - avg(close) OVER (PARTITION BY symbol), 2) AS diff
FROM ochl_day
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | avg_close (DOUBLE) | diff (DOUBLE) |
|---|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | 502.33 | -4.83 |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 502.33 | 2.27 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 502.33 | 2.57 |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | 377.8 | -0.6 |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 377.8 | 2.3 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 377.8 | -1.7 |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | 186.97 | -4.57 |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 186.97 | 0.33 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 186.97 | 4.23 |

(9 rows)

**Example: Moving 3-day VWAP** (sample data: sample)

```sql
SELECT time, close, volume,
       round(vwap(close, volume) OVER (ORDER BY time ROWS 2 PRECEDING), 2) AS vwap_3d
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-09-03'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) | vwap_3d (DOUBLE) |
|---|---|---|---|
| 2026-09-03T00:00:00.000Z | 176 | 145930 | 176 |
| 2026-09-06T00:00:00.000Z | 180.1 | 78550 | 177.43 |
| 2026-09-07T00:00:00.000Z | 176.9 | 135560 | 177.23 |
| 2026-09-08T00:00:00.000Z | 182.4 | 136770 | 179.76 |
| 2026-09-09T00:00:00.000Z | 187.3 | 94410 | 181.63 |
| 2026-09-10T00:00:00.000Z | 191.2 | 41470 | 185.44 |

(6 rows)

A window function can sit next to `GROUP BY`. It runs over the grouped rows, after the aggregates, as in PostgreSQL.

**Example: A window over groups: rank symbols by volume** (sample data: sample)

```sql
SELECT symbol, sum(volume) AS volume,
       rank() OVER (ORDER BY sum(volume) DESC) AS place
FROM ochl_day
GROUP BY symbol
ORDER BY place;
```

Result:

| symbol (SYMBOL) | volume (DOUBLE) | place (LONG) |
|---|---|---|
| CITY | 1986850 | 1 |
| VOLT | 1800030 | 2 |
| COAST | 1674510 | 3 |

(3 rows)

**Example: The same idea with GROUP BY inside, window outside** (sample data: sample)

```sql
SELECT day, turnover, sum(turnover) OVER (ORDER BY day) AS running_turnover
FROM (SELECT date AS day, sum(amount) AS turnover
      FROM trade_log
      GROUP BY date) t
ORDER BY day;
```

Result:

| day (TIMESTAMP) | turnover (DOUBLE) | running_turnover (DOUBLE) |
|---|---|---|
| 2026-09-09T00:00:00.000Z | 2625570 | 2625570 |
| 2026-09-10T00:00:00.000Z | 2361380 | 4986950 |

(2 rows)
