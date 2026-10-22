# Correlation and regression

> Do two series move together? corr, covariance, a straight trend line (regr_slope, regr_intercept, regr_r2), and the beta and alpha of a share against the market.

- Category: Functions — statistics
- Keywords: correlation, correlation coefficient, Pearson, pearson, correl, covariance, covar, covariance\_samp, covariance\_pop, regression, linear regression, least squares, trend line, line of best fit, slope, intercept, r squared, R2, rsq, coefficient of determination, beta, market beta, systematic risk, alpha, Jensen's alpha, excess return, market index, diversification, pairs, y and x
- See also: [Statistics functions](functions-statistics.md), [Returns and risk](functions-returns-risk.md), [Trend indicators (linearreg)](functions-indicators-trend.md#linearreg), [Window and series functions (aggregates)](functions-window.md#aggregates), [Joins](joins.md)

These aggregates look at **pairs** of numbers: one `y` and one `x` on each row, for example the return of CITY and the return of a market index on the same day. They answer two questions:

- **Do the two move together?** The **correlation** is a number from `-1` to `1`. `1`: when one goes up, the other always goes up too. `-1`: when one goes up, the other goes down. `0`: no straight-line link. Traders use it to spread risk: two shares with a low correlation do not fall on the same days so often (this is **diversification**).
- **What straight line fits best?** A **linear regression** finds the line `y = slope × x + intercept` that is closest to all points (the "least squares" line). The slope tells how much `y` changes when `x` changes by 1.

They follow these rules:

- **Argument order:** `y` first, `x` second, like PostgreSQL: `regr_slope(close, day_no)` is the slope of close against the day number. For `corr` and `covar_*` the order does not change the result.
- **NULL:** a row where `y` or `x` is NULL is **skipped** (the whole pair). With no pairs left the result is `NULL`, except `regr_count`, which gives `0`.
- They take numbers. Text gives an error `needs numbers`.
- They work with `GROUP BY`, `SAMPLE BY`, `HAVING` and `OVER (...)` (for example a moving 5-day correlation), like the other [aggregates](functions-aggregate.md).
- They give a `DOUBLE`, except `regr_count` (`LONG`).

**Use returns, not prices.** Two share prices that both trend up for months look strongly correlated even when their daily moves have nothing to do with each other. Compare the **daily changes** (`pct_change(close)`, or [pct_return](functions-returns-risk.md#pct_return)). To put two series side by side, make each one in a subquery and join them on `time`.

**Example: Which shares move together? Correlation of the daily % changes of every pair** (sample data: sample)

```sql
SELECT a.symbol AS share_a, b.symbol AS share_b, count(*) AS days,
       round(corr(a.r, b.r), 3) AS correlation
FROM (SELECT time, symbol, pct_change(close) OVER (PARTITION BY symbol ORDER BY time) AS r
      FROM ochl_day WHERE time >= '2026-08-23') a
JOIN (SELECT time, symbol, pct_change(close) OVER (PARTITION BY symbol ORDER BY time) AS r
      FROM ochl_day WHERE time >= '2026-08-23') b
  ON a.time = b.time AND a.symbol < b.symbol
GROUP BY a.symbol, b.symbol
ORDER BY correlation DESC;
```

Result:

| share_a (SYMBOL) | share_b (SYMBOL) | days (LONG) | correlation (DOUBLE) |
|---|---|---|---|
| COAST | VOLT | 15 | 0.366 |
| CITY | VOLT | 15 | 0.217 |
| CITY | COAST | 15 | 0.032 |

(3 rows)

## corr

Syntax:

```sql
corr(y, x)
corr(y, x) OVER (...)
```

The **Pearson correlation** of `y` and `x`: a number from `-1` to `1` that tells how well the points lie on one straight line. Above about `0.7` is a strong link, below about `0.3` a weak one.

| Argument | Type | Meaning |
|---|---|---|
| `y` | number | the first value of each pair |
| `x` | number | the second value of each pair |

- **Returns:** `DOUBLE` from `-1` to `1`.
- **NULL:** pairs with a NULL are skipped. `NULL` with fewer than 2 pairs, and when all `x` or all `y` values are the same (a flat line has no correlation).
- **Notes:** correlation is not cause: two shares can move together because the whole market moves. `corr(y, x)` is the same as `corr(x, y)`.

**Example: CITY and COAST: daily returns joined on the day** (sample data: sample)

```sql
SELECT count(*) AS days, regr_count(a.r, b.r) AS pairs, round(corr(a.r, b.r), 3) AS correlation
FROM (SELECT time, pct_change(close) AS r FROM ochl_day WHERE symbol = 'CITY' AND time >= '2026-08-23') a
JOIN (SELECT time, pct_change(close) AS r FROM ochl_day WHERE symbol = 'COAST' AND time >= '2026-08-23') b
  ON a.time = b.time;
```

Result:

| days (LONG) | pairs (LONG) | correlation (DOUBLE) |
|---|---|---|
| 15 | 14 | 0.032 |

(1 row)

**Example: Moving 5-day correlation (with OVER)** (sample data: sample)

```sql
SELECT time, round(corr(city_r, coast_r) OVER (ORDER BY time ROWS 4 PRECEDING), 3) AS corr_5d
FROM (SELECT a.time AS time, a.r AS city_r, b.r AS coast_r
      FROM (SELECT time, pct_change(close) AS r FROM ochl_day WHERE symbol = 'CITY' AND time >= '2026-08-23') a
      JOIN (SELECT time, pct_change(close) AS r FROM ochl_day WHERE symbol = 'COAST' AND time >= '2026-08-23') b
        ON a.time = b.time) t
ORDER BY time;
```

Result:

| time (TIMESTAMP) | corr_5d (DOUBLE) |
|---|---|
| 2026-08-23T00:00:00.000Z | NULL |
| 2026-08-24T00:00:00.000Z | NULL |
| 2026-08-25T00:00:00.000Z | 1 |
| 2026-08-26T00:00:00.000Z | 0.939 |
| 2026-08-27T00:00:00.000Z | 0.326 |
| 2026-08-30T00:00:00.000Z | -0.208 |
| 2026-08-31T00:00:00.000Z | -0.149 |
| 2026-09-01T00:00:00.000Z | -0.091 |
| 2026-09-02T00:00:00.000Z | -0.063 |
| 2026-09-03T00:00:00.000Z | -0.331 |
| 2026-09-06T00:00:00.000Z | -0.174 |
| 2026-09-07T00:00:00.000Z | 0.584 |
| 2026-09-08T00:00:00.000Z | 0.293 |
| 2026-09-09T00:00:00.000Z | 0.386 |
| 2026-09-10T00:00:00.000Z | 0.424 |

(15 rows)

**Example: Why returns: today's price and yesterday's price look strongly linked** (sample data: sample)

```sql
SELECT round(corr(close, prev_close), 3) AS price_corr
FROM (SELECT close, lag(close) AS prev_close
      FROM ochl_day
      WHERE symbol = 'CITY' AND time >= '2026-08-23') t;
```

Result:

| price_corr (DOUBLE) |
|---|
| 0.78 |

(1 row)

<a id="covar_pop"></a>

## covar_pop

Syntax:

```sql
covar_pop(y, x)
```

The **population covariance**: the average of `(y - average y) × (x - average x)`. It is positive when `y` and `x` are often above their averages at the same time, negative when one is above while the other is below. It divides by `n`, the number of pairs.

| Argument | Type | Meaning |
|---|---|---|
| `y` | number | the first value of each pair |
| `x` | number | the second value of each pair |

- **Returns:** `DOUBLE`. Its unit is the unit of `y` times the unit of `x`, so the size is hard to read; `corr` is the same idea scaled to `-1 ... 1`.
- **NULL:** pairs with a NULL are skipped. One pair gives `0`; no pairs give `NULL`.

**Example: Pairs with a NULL are skipped: only 3 pairs count** (sample data: sample)

```sql
SELECT regr_count(y, x) AS pairs, covar_pop(y, x) AS covar_pop, covar_samp(y, x) AS covar_samp
FROM (SELECT 1 AS x, 2 AS y UNION ALL SELECT 2, 4 UNION ALL SELECT 3, 5
      UNION ALL SELECT 4, NULL UNION ALL SELECT NULL, 9) t;
```

Result:

| pairs (LONG) | covar_pop (DOUBLE) | covar_samp (DOUBLE) |
|---|---|---|
| 3 | 1 | 1.5 |

(1 row)

<a id="covar_samp"></a>

## covar_samp

Syntax:

```sql
covar_samp(y, x)
```

The **sample covariance**: like `covar_pop`, but it divides by `n - 1`. Use it when your rows are only a part of a longer history, as for returns (see "sample or population" in [statistics](functions-statistics.md)).

| Argument | Type | Meaning |
|---|---|---|
| `y` | number | the first value of each pair |
| `x` | number | the second value of each pair |

- **Returns:** `DOUBLE`.
- **NULL:** pairs with a NULL are skipped. `NULL` with fewer than 2 pairs.
- **Notes:** `covar_samp(y, x) / (stddev(y) × stddev(x))` is `corr(y, x)` (when no pair has a NULL).

**Example: Covariance of price and volume, minute by minute** (sample data: sample)

```sql
SELECT round(covar_samp(close, volume), 1) AS covar_samp,
       round(covar_pop(close, volume), 1) AS covar_pop,
       round(corr(close, volume), 3) AS corr
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10';
```

Result:

| covar_samp (DOUBLE) | covar_pop (DOUBLE) | corr (DOUBLE) |
|---|---|---|
| 0.8 | 0.8 | 0.001 |

(1 row)

**Example: One pair: covar_pop is 0, covar_samp and corr are NULL** (sample data: sample)

```sql
SELECT covar_pop(y, x) AS covar_pop, covar_samp(y, x) AS covar_samp, corr(y, x) AS corr
FROM (SELECT 1 AS x, 5 AS y) t;
```

Result:

| covar_pop (DOUBLE) | covar_samp (STRING) | corr (STRING) |
|---|---|---|
| 0 | NULL | NULL |

(1 row)

<a id="regr_slope"></a>

## regr_slope

Syntax:

```sql
regr_slope(y, x)
```

The **slope** of the best straight line through the points: how much `y` goes up when `x` goes up by 1. With `x` = the day number and `y` = the close, it is the trend in dollars per day.

| Argument | Type | Meaning |
|---|---|---|
| `y` | number | the value to explain, for example `close` |
| `x` | number | the value that explains it, for example the day or minute number |

- **Returns:** `DOUBLE`. Positive: an up trend; negative: a down trend.
- **NULL:** pairs with a NULL are skipped. `NULL` when all `x` values are the same (also with only one pair).
- **Notes:** the same as `regr_sxy(y, x) / regr_sxx(y, x)`. Number the rows with `row_number()` in a subquery. For a slope for every candle over the last `n` candles, use [linearreg_slope](functions-indicators-trend.md#linearreg_slope).

**Example: Trend line of VOLT since 23 August: dollars per trading day** (sample data: sample)

```sql
SELECT round(regr_slope(close, day_no), 3) AS dollars_per_day,
       round(regr_intercept(close, day_no), 2) AS line_at_day_0,
       round(regr_r2(close, day_no), 3) AS r2
FROM (SELECT row_number() AS day_no, close
      FROM ochl_day
      WHERE symbol = 'VOLT' AND time >= '2026-08-23') t;
```

Result:

| dollars_per_day (DOUBLE) | line_at_day_0 (DOUBLE) | r2 (DOUBLE) |
|---|---|---|
| 0.673 | 172.21 | 0.247 |

(1 row)

**Example: Intraday trend of each share on 10 September: dollars per minute** (sample data: sample)

```sql
SELECT symbol, round(regr_slope(close, minute_no), 4) AS dollars_per_minute, round(regr_r2(close, minute_no), 3) AS r2
FROM (SELECT symbol, close, row_number() OVER (PARTITION BY symbol ORDER BY time) AS minute_no
      FROM ochl_minutes
      WHERE time IN '2026-09-10') t
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | dollars_per_minute (DOUBLE) | r2 (DOUBLE) |
|---|---|---|
| CITY | -0.0031 | 0.021 |
| COAST | -0.028 | 0.848 |

(2 rows)

<a id="regr_intercept"></a>

## regr_intercept

Syntax:

```sql
regr_intercept(y, x)
```

The **intercept** of the best straight line: the value of the line where `x` is `0`. Together with the slope it gives the line: `y = regr_slope × x + regr_intercept`.

| Argument | Type | Meaning |
|---|---|---|
| `y` | number | the value to explain |
| `x` | number | the value that explains it |

- **Returns:** `DOUBLE`.
- **NULL:** pairs with a NULL are skipped. `NULL` when all `x` values are the same.
- **Notes:** the same as `regr_avgy - regr_slope × regr_avgx`. To draw the line or guess the next value, compute `regr_intercept(y, x) + regr_slope(y, x) × next_x`.

**Example: Where would the VOLT trend line be on day 16?** (sample data: sample)

```sql
SELECT round(regr_intercept(close, day_no) + regr_slope(close, day_no) * 16, 2) AS line_day_16,
       max(day_no) AS last_day
FROM (SELECT row_number() AS day_no, close
      FROM ochl_day
      WHERE symbol = 'VOLT' AND time >= '2026-08-23') t;
```

Result:

| line_day_16 (DOUBLE) | last_day (LONG) |
|---|---|
| 182.97 | 15 |

(1 row)

<a id="regr_r2"></a>

## regr_r2

Syntax:

```sql
regr_r2(y, x)
```

The **R squared** (coefficient of determination), from `0` to `1`: how much of the ups and downs of `y` the straight line explains. `1`: all points are on the line. `0`: the line explains nothing. For a trend line, a high R squared means a clean, steady trend.

| Argument | Type | Meaning |
|---|---|---|
| `y` | number | the value to explain |
| `x` | number | the value that explains it |

- **Returns:** `DOUBLE` from `0` to `1`.
- **NULL:** pairs with a NULL are skipped. `NULL` when all `x` values are the same. When `x` changes but all `y` values are the same, the result is `1` (like PostgreSQL).
- **Notes:** when no pair has a NULL, it is `corr(y, x)` squared.

**Example: A flat y: R squared 1, slope 0, corr NULL** (sample data: sample)

```sql
SELECT regr_r2(y, x) AS r2, regr_slope(y, x) AS slope, corr(y, x) AS corr
FROM (SELECT 1 AS x, 5 AS y UNION ALL SELECT 2, 5) t;
```

Result:

| r2 (DOUBLE) | slope (DOUBLE) | corr (STRING) |
|---|---|---|
| 1 | 0 | NULL |

(1 row)

<a id="regr_count"></a>

## regr_count

Syntax:

```sql
regr_count(y, x)
```

The number of pairs where **both** `y` and `x` are not NULL: the rows the other `regr_` functions really use.

| Argument | Type | Meaning |
|---|---|---|
| `y` | any number | the first value of each pair |
| `x` | any number | the second value of each pair |

- **Returns:** `LONG`.
- **NULL:** never `NULL`: no pairs give `0`.
- **Notes:** check it next to a correlation or a beta: a number made from 3 pairs means little.

**Example: The first day of a return series has no return: 15 days, 14 pairs** (sample data: sample)

```sql
SELECT count(*) AS days, regr_count(a.r, b.r) AS pairs
FROM (SELECT time, pct_change(close) AS r FROM ochl_day WHERE symbol = 'CITY' AND time >= '2026-08-23') a
JOIN (SELECT time, pct_change(close) AS r FROM ochl_day WHERE symbol = 'VOLT' AND time >= '2026-08-23') b
  ON a.time = b.time;
```

Result:

| days (LONG) | pairs (LONG) |
|---|---|
| 15 | 14 |

(1 row)

**Example: No rows: regr_count is 0, corr is NULL** (sample data: sample)

```sql
SELECT regr_count(close, volume) AS pairs, corr(close, volume) AS corr
FROM ochl_day
WHERE symbol = 'NONE';
```

Result:

| pairs (LONG) | corr (STRING) |
|---|---|
| 0 | NULL |

(1 row)

<a id="regr_avgx"></a>

## regr_avgx, regr_avgy

Syntax:

```sql
regr_avgx(y, x)
regr_avgy(y, x)
```

The average of `x` (`regr_avgx`) or of `y` (`regr_avgy`), taken **only over the pairs** where both values are not NULL. So it can be different from `avg(x)`, which also counts rows where `y` is NULL.

| Argument | Type | Meaning |
|---|---|---|
| `y` | number | the first value of each pair |
| `x` | number | the second value of each pair |

- **Returns:** `DOUBLE`.
- **NULL:** pairs with a NULL are skipped. No pairs give `NULL`.

**Example: avg counts every value, regr_avgx only the full pairs** (sample data: sample)

```sql
SELECT avg(x) AS avg_x, regr_avgx(y, x) AS regr_avgx, avg(y) AS avg_y, round(regr_avgy(y, x), 4) AS regr_avgy
FROM (SELECT 1 AS x, 2 AS y UNION ALL SELECT 2, 4 UNION ALL SELECT 3, 5
      UNION ALL SELECT 4, NULL UNION ALL SELECT NULL, 9) t;
```

Result:

| avg_x (DOUBLE) | regr_avgx (DOUBLE) | avg_y (DOUBLE) | regr_avgy (DOUBLE) |
|---|---|---|---|
| 2.5 | 2 | 5 | 3.6667 |

(1 row)

<a id="regr_sxx"></a>

## regr_sxx, regr_syy, regr_sxy

Syntax:

```sql
regr_sxx(y, x)
regr_syy(y, x)
regr_sxy(y, x)
```

The sums that the regression is made from, over the full pairs:

| Function | Sum |
|---|---|
| `regr_sxx(y, x)` | `sum((x - avg x)²)` |
| `regr_syy(y, x)` | `sum((y - avg y)²)` |
| `regr_sxy(y, x)` | `sum((x - avg x) × (y - avg y))` |

| Argument | Type | Meaning |
|---|---|---|
| `y` | number | the first value of each pair |
| `x` | number | the second value of each pair |

- **Returns:** `DOUBLE`.
- **NULL:** pairs with a NULL are skipped. One pair gives `0`; no pairs give `NULL`.
- **Notes:** `regr_slope = regr_sxy / regr_sxx`, and `corr = regr_sxy / sqrt(regr_sxx × regr_syy)`. You rarely need them yourself.

**Example: Build the slope from the sums** (sample data: sample)

```sql
SELECT regr_sxx(y, x) AS sxx, round(regr_syy(y, x), 4) AS syy, regr_sxy(y, x) AS sxy,
       regr_sxy(y, x) / regr_sxx(y, x) AS slope_by_hand, regr_slope(y, x) AS slope
FROM (SELECT 1 AS x, 2 AS y UNION ALL SELECT 2, 4 UNION ALL SELECT 3, 5) t;
```

Result:

| sxx (DOUBLE) | syy (DOUBLE) | sxy (DOUBLE) | slope_by_hand (DOUBLE) | slope (DOUBLE) |
|---|---|---|---|---|
| 2 | 4.6667 | 3 | 1.5 | 1.5 |

(1 row)

## beta

Syntax:

```sql
beta(stock_return, market_return)
beta(stock_return, market_return) OVER (...)
```

The **beta** of a share: how strongly it follows the market. It is the regression slope of the share's returns (`y`) against the market's returns (`x`), for example a stock market index.

- beta `1`: the share moves like the market.
- beta above `1` (like `1.5`): the share moves more; when the market rises 1%, it rises about 1.5% on average, and falls more too. It is riskier.
- beta below `1`: a calmer share. Near `0`: no link with the market. Negative: it tends to move the other way.

| Argument | Type | Meaning |
|---|---|---|
| `stock_return` | number | the return of the share on each day (`y`) |
| `market_return` | number | the return of the market on the same day (`x`) |

- **Returns:** `DOUBLE`.
- **NULL:** pairs with a NULL are skipped. `NULL` with fewer than 2 pairs, and when the market return is the same on every row.
- **Notes:** the same number as `regr_slope(stock_return, market_return)`. Both returns must be in the same unit (both % or both fractions) and for the same days: join the two series on `time`. Beta from a few weeks of data changes a lot; use months or years of history for real decisions.

**Example: Beta of each share against the market index** (sample data: sample, analysis-market)

```sql
SELECT s.symbol, regr_count(s.r, m.r) AS days,
       round(beta(s.r, m.r), 3) AS beta,
       round(corr(s.r, m.r), 3) AS corr,
       round(regr_r2(s.r, m.r), 3) AS r2
FROM (SELECT time, symbol, pct_change(close) OVER (PARTITION BY symbol ORDER BY time) AS r
      FROM ochl_day WHERE time >= '2026-08-23') s
JOIN (SELECT time, pct_change(close) AS r
      FROM market_index WHERE time >= '2026-08-23') m
  ON s.time = m.time
GROUP BY s.symbol
ORDER BY beta DESC;
```

Result:

| symbol (SYMBOL) | days (LONG) | beta (DOUBLE) | corr (DOUBLE) | r2 (DOUBLE) |
|---|---|---|---|---|
| VOLT | 14 | 3.322 | 0.705 | 0.497 |
| COAST | 14 | 1.962 | 0.686 | 0.47 |
| CITY | 14 | 0.862 | 0.462 | 0.214 |

(3 rows)

## alpha

Syntax:

```sql
alpha(stock_return, market_return)
alpha(stock_return, market_return, risk_free)
```

The **alpha** (Jensen's alpha) of a share: the part of its average return that the market does **not** explain. After taking away what its beta would give, a positive alpha means the share did better than the market risk predicts; a negative alpha means worse. Fund managers try to "make alpha".

It is `(avg(stock) - risk_free) - beta × (avg(market) - risk_free)`.

| Argument | Type | Meaning |
|---|---|---|
| `stock_return` | number | the return of the share on each day (`y`) |
| `market_return` | number | the return of the market on the same day (`x`) |
| `risk_free` | number | the return without risk for **one period** (for example a fixed deposit rate per day), in the same unit as the returns; default `0` |

- **Returns:** `DOUBLE`, in the unit of the returns **per period**: with daily returns in %, `0.05` means +0.05% a day.
- **NULL:** pairs with a NULL are skipped. `NULL` with fewer than 2 pairs, when the market return is the same on every row, and when `risk_free` is NULL.
- **Notes:** `risk_free` must be a constant; it is read from the first row. A yearly rate must first be changed to the period: 6% a year is about `6 / 250 = 0.024`% a trading day.

**Example: Alpha and beta of each share (daily returns in %)** (sample data: sample, analysis-market)

```sql
SELECT s.symbol,
       round(beta(s.r, m.r), 3) AS beta,
       round(alpha(s.r, m.r), 4) AS alpha_pct_per_day,
       round(avg(s.r), 4) AS avg_return_pct
FROM (SELECT time, symbol, pct_change(close) OVER (PARTITION BY symbol ORDER BY time) AS r
      FROM ochl_day WHERE time >= '2026-08-23') s
JOIN (SELECT time, pct_change(close) AS r
      FROM market_index WHERE time >= '2026-08-23') m
  ON s.time = m.time
GROUP BY s.symbol
ORDER BY alpha_pct_per_day DESC;
```

Result:

| symbol (SYMBOL) | beta (DOUBLE) | alpha_pct_per_day (DOUBLE) | avg_return_pct (DOUBLE) |
|---|---|---|---|
| VOLT | 3.322 | 0.4136 | 0.4088 |
| CITY | 0.862 | -0.0385 | -0.0397 |
| COAST | 1.962 | -0.2682 | -0.271 |

(3 rows)

**Example: With a risk-free return of 0.024% a day** (sample data: sample)

```sql
SELECT round(alpha(y, x), 5) AS alpha, round(alpha(y, x, 0.024), 5) AS alpha_with_risk_free, round(beta(y, x), 3) AS beta
FROM (SELECT 1.0 AS x, 2.0 AS y UNION ALL SELECT 2.0, 3.0 UNION ALL SELECT -1.0, -1.0) t;
```

Result:

| alpha (DOUBLE) | alpha_with_risk_free (DOUBLE) | beta (DOUBLE) |
|---|---|---|
| 0.42857 | 0.43714 | 1.357 |

(1 row)

**Example: Returns must be numbers** (sample data: sample; shows an error)

```sql
SELECT beta(symbol, close) FROM ochl_day;
```

Result:

Error: `line 1, column 8: beta: needs numbers, got 'CITY'`
