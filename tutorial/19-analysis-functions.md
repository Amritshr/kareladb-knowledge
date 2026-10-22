# 19. Analysis functions

- Category: Tutorial

### What you will learn

- Statistics over many rows: correlation, regression, skewness, percentiles, mode and more.
- Window functions: ranks, `first_value`, `lag` with a default, and frames with `FOLLOWING` and `RANGE '5 days'`.
- Returns and risk: returns, drawdown, volatility, Sharpe, Sortino, Calmar, beta, alpha, value at risk.
- Technical indicators: WMA, DEMA, TEMA, KAMA, HMA, MACD, stochastic, Bollinger bands, ADX, Aroon, Parabolic SAR, Ichimoku, OBV, MFI, SuperTrend, Heikin-Ashi, linear regression and more.
- Math, finance and date functions: `log`, `gcd`, `width_bucket`, `round_tick`, `pmt`, `irr`, `xirr`, `extract`, `age`, fiscal years.
- Table functions and pivots: `generate_series`, `long_sequence`, `PIVOT`.
- A cookbook: top gainers per day, 20-day volatility, drawdown, MACD crossovers, a Bollinger squeeze, a correlation matrix and turnover by sector and month.

All examples are in examples/19-analysis-functions/. The output under the cookbook examples is real. The prices are made up.

Chapter 5 explains `SAMPLE BY`, `GROUP BY` and the first window functions (`sma`, `ema`, `rsi`, `atr`, `lag`). Read it first.

### How to read this chapter

Every function has a short section:

- **Syntax**: how to write it. `[x]` means x is optional.
- **Returns**: the type of the result.
- **NULLs**: what happens with NULL values and with too few rows.

Three kinds of functions are in this chapter:

| Kind | Used where | Example |
|---|---|---|
| **Scalar** | anywhere: `SELECT`, `WHERE`, `ORDER BY` | `round_tick(close)` |
| **Aggregate** | with `GROUP BY` or `SAMPLE BY`, alone, or with `OVER (...)` | `corr(a, b)` |
| **Window / series** | in the `SELECT` list; without `OVER` they run in time order | `macd(close) OVER (PARTITION BY symbol ORDER BY time)` |

Rules for window and series functions (the same as in chapter 5):

- Without `OVER`, all result rows are **one series** in time order. With many symbols, always write `OVER (PARTITION BY symbol ORDER BY time)`.
- `WHERE` runs first. An indicator only sees the rows that `WHERE` keeps. Compute on more history in a subquery, filter outside.
- With `GROUP BY` or `SAMPLE BY`, a window function works on the **groups**: its arguments must be aggregates or group keys, for example `sma(last(close), 2)` or `rank() OVER (ORDER BY sum(volume) DESC)`. A plain column that is not a group key (`sma(close, 2)`) gives `column 'close' is used by a window function in a query with aggregates, so it must be a key of the groups`.
- One window function cannot be inside another (`macd(sma(close, 3))`). Use one subquery per step.
- The new aggregates work only in the row engine. Queries that use them do not use the fast column engine, so they are slower on very big tables (see [Speed](#speed)).

### The sample candles

The cookbook uses daily candles for the five symbols of the sample data (chapter 1). The sample table `ochl_day` is short, so this chapter makes a longer, made-up price history with a view. The view itself uses `generate_series` from this chapter:

01-candles.sql:

```sql
CREATE VIEW candles AS
SELECT time, symbol, sector,
       round(close * (1 + 0.006 * sin(n * 1.3 + k)), 1) AS open,
       round(greatest(close, close * (1 + 0.006 * sin(n * 1.3 + k))) * (1.004 + 0.003 * abs(sin(n * 0.7 + k))), 1) AS high,
       round(least(close, close * (1 + 0.006 * sin(n * 1.3 + k))) * (0.996 - 0.003 * abs(cos(n * 0.9 + k))), 1) AS low,
       close, volume
FROM (
  SELECT time, symbol, sector, n, k,
         round(base * (1 + 0.08 * sin(n / 11.0 + k) + 0.04 * sin(n / 3.0 + 2 * k) + 0.0004 * n * (k - 2)), 1) AS close,
         round(50000 + 30000 * abs(sin(n * 0.37 + k))) AS volume
  FROM (
    SELECT d AS time, s.symbol AS symbol, s.sector AS sector, datediff('d', '2026-01-01', d) AS n,
           CASE s.symbol WHEN 'CITY' THEN 0 WHEN 'COAST' THEN 1 WHEN 'VOLT' THEN 2 WHEN 'TELCO' THEN 3 ELSE 4 END AS k,
           CASE s.symbol WHEN 'CITY' THEN 500 WHEN 'COAST' THEN 380 WHEN 'VOLT' THEN 180 WHEN 'TELCO' THEN 900 ELSE 250 END AS base
    FROM generate_series('2026-01-01'::TIMESTAMP, '2026-09-10'::TIMESTAMP, '1 day') AS g(d)
    CROSS JOIN securities s
    WHERE is_trading_day(d)
  ) a
) b;
```

Each symbol has 181 trading days:

```sql
SELECT symbol, count(*) AS days, min(time) AS first_day, max(time) AS last_day, min(close) AS low, max(close) AS high
FROM candles GROUP BY symbol ORDER BY symbol;
```

```text
view 'candles' created

symbol | days | first_day                | last_day                 | low   | high  
-------+------+--------------------------+--------------------------+-------+-------
ACME   |  181 | 2026-01-01T00:00:00.000Z | 2026-09-10T00:00:00.000Z |   223 |  327.1
CITY   |  181 | 2026-01-01T00:00:00.000Z | 2026-09-10T00:00:00.000Z | 371.8 |  542.9
COAST  |  181 | 2026-01-01T00:00:00.000Z | 2026-09-10T00:00:00.000Z | 299.1 |  419.4
TELCO  |  181 | 2026-01-01T00:00:00.000Z | 2026-09-10T00:00:00.000Z | 805.8 | 1076.2
VOLT   |  181 | 2026-01-01T00:00:00.000Z | 2026-09-10T00:00:00.000Z | 158.8 |  201.2
(5 rows, 5.3 ms)
```

---

## Part 1: Aggregates

Aggregates look at many rows and give one value. Use them alone, with `GROUP BY`, with `SAMPLE BY`, or with `OVER (...)` for a moving window (for example `corr(a, b) OVER (ORDER BY time ROWS 19 PRECEDING)`).

The general NULL rule: **rows with NULL in a used argument are skipped**. For two-value aggregates (like `corr(y, x)`) the whole pair is skipped. With no rows left, the result is NULL (`regr_count`, `count_if` and `approx_count_distinct` give 0).

### Correlation and regression

| Name | Syntax | Meaning | NULLs / too few rows |
|---|---|---|---|
| `corr` | `corr(y, x)` | Pearson correlation, -1 to 1 | NULL when y or x does not change |
| `covar_pop` | `covar_pop(y, x)` | population covariance (divide by n) | NULL with no pairs |
| `covar_samp` | `covar_samp(y, x)` | sample covariance (divide by n - 1) | NULL with fewer than 2 pairs |
| `regr_slope` | `regr_slope(y, x)` | slope of the best straight line y = a + b·x | NULL when x does not change |
| `regr_intercept` | `regr_intercept(y, x)` | a of that line | NULL when x does not change |
| `regr_r2` | `regr_r2(y, x)` | how well the line fits, 0 to 1 | NULL when x does not change; 1 when only y does not change |
| `regr_count` | `regr_count(y, x)` | number of pairs without NULL | 0 with no pairs |
| `regr_avgx`, `regr_avgy` | `regr_avgx(y, x)` | average of x (of y) over the pairs | NULL with no pairs |
| `regr_sxx`, `regr_syy`, `regr_sxy` | `regr_sxx(y, x)` | sum of squared differences from the average | NULL with no pairs |
| `beta` | `beta(asset_returns, market_returns)` | how much the asset moves with the market | NULL with fewer than 2 pairs |
| `alpha` | `alpha(asset_returns, market_returns [, risk_free])` | return not explained by beta, per period | NULL with fewer than 2 pairs |

The argument order is **y first, then x**, as in PostgreSQL.

#### corr

- **Syntax:** `corr(y, x)`
- **Description:** the Pearson correlation of two columns. 1 means they move together, -1 means they move opposite, 0 means no straight-line relation.
- **Arguments:** y, x: numbers.
- **Returns:** DOUBLE between -1 and 1.
- **NULLs:** pairs with a NULL are skipped. NULL when fewer than 2 pairs, or when one column never changes.
- **Example:** `SELECT corr(n.close, u.close) FROM candles n JOIN candles u ON n.time = u.time WHERE n.symbol = 'CITY' AND u.symbol = 'VOLT'`

#### covar_pop

- **Syntax:** `covar_pop(y, x)`
- **Description:** population covariance: the average of (y - average y) × (x - average x).
- **Returns:** DOUBLE. **NULLs:** pairs with a NULL are skipped; NULL with no pairs.
- **Example:** `SELECT covar_pop(volume, close) FROM candles WHERE symbol = 'COAST'`

#### covar_samp

- **Syntax:** `covar_samp(y, x)`
- **Description:** sample covariance: like `covar_pop`, but divided by n - 1.
- **Returns:** DOUBLE. **NULLs:** pairs with a NULL are skipped; NULL with fewer than 2 pairs.
- **Example:** `SELECT covar_samp(volume, close) FROM candles WHERE symbol = 'COAST'`

#### regr_slope

- **Syntax:** `regr_slope(y, x)`
- **Description:** the slope b of the least-squares line y = a + b·x.
- **Returns:** DOUBLE. **NULLs:** pairs with a NULL are skipped; NULL when x never changes.
- **Example:** trend of the close per day: `SELECT symbol, regr_slope(close, datediff('d', '2026-01-01', time)) FROM candles GROUP BY symbol`

#### regr_intercept

- **Syntax:** `regr_intercept(y, x)`
- **Description:** the a of the least-squares line y = a + b·x (the value of y where x = 0).
- **Returns:** DOUBLE. **NULLs:** as `regr_slope`.
- **Example:** `SELECT regr_intercept(close, volume) FROM candles WHERE symbol = 'TELCO'`

#### regr_r2

- **Syntax:** `regr_r2(y, x)`
- **Description:** R², how much of the change in y the line explains (0 = nothing, 1 = everything).
- **Returns:** DOUBLE from 0 to 1. **NULLs:** NULL when x never changes; 1 when y never changes but x does.
- **Example:** `SELECT regr_r2(close, volume) FROM candles WHERE symbol = 'TELCO'`

#### regr_count

- **Syntax:** `regr_count(y, x)`
- **Description:** the number of rows where both y and x are not NULL.
- **Returns:** LONG. **NULLs:** 0 when there are no such rows.
- **Example:** `SELECT regr_count(close, volume) FROM candles`

#### regr_avgx

- **Syntax:** `regr_avgx(y, x)`, `regr_avgy(y, x)`
- **Description:** the average of x (or y), using only rows where both are not NULL.
- **Returns:** DOUBLE. **NULLs:** NULL with no pairs.
- **Example:** `SELECT regr_avgx(close, volume), regr_avgy(close, volume) FROM candles`

#### regr_sxx

- **Syntax:** `regr_sxx(y, x)`, `regr_syy(y, x)`, `regr_sxy(y, x)`
- **Description:** Σ(x - avg x)², Σ(y - avg y)² and Σ(x - avg x)(y - avg y) over the pairs.
- **Returns:** DOUBLE. **NULLs:** NULL with no pairs.
- **Example:** `SELECT regr_sxy(close, volume) / regr_sxx(close, volume) FROM candles` (the same as `regr_slope`)

#### beta

- **Syntax:** `beta(asset_returns, market_returns)`
- **Description:** beta of an asset against a benchmark: covariance / variance of the benchmark. Beta 1.2 means the asset moved 1.2 % when the market moved 1 %.
- **Arguments:** two columns of returns (for example from `pct_return`, see Part 3). Returns, not prices.
- **Returns:** DOUBLE. **NULLs:** pairs with a NULL are skipped; NULL with fewer than 2 pairs or when the benchmark never changes.
- **Example:** see [Beta against a benchmark](#beta-against-a-benchmark).

#### alpha

- **Syntax:** `alpha(asset_returns, market_returns [, risk_free])`
- **Description:** Jensen's alpha per period: (average asset return - risk_free) - beta × (average market return - risk_free). risk_free is a return per period (default 0). Multiply by the periods in a year (for example 240 or 252 trading days) for a simple yearly number.
- **Returns:** DOUBLE. **NULLs:** as `beta`.
- **Example:** see [Beta against a benchmark](#beta-against-a-benchmark).

### Shape of the data

| Name | Syntax | Meaning | NULLs / too few rows |
|---|---|---|---|
| `skewness` (`skew`) | `skewness(x)` | sample skewness (like Excel `SKEW`, pandas `skew`) | NULL with fewer than 3 values or no change |
| `skewness_pop` | `skewness_pop(x)` | population skewness | NULL with no change |
| `kurtosis` (`kurt`) | `kurtosis(x)` | sample excess kurtosis (like Excel `KURT`, pandas `kurt`) | NULL with fewer than 4 values or no change |
| `kurtosis_pop` | `kurtosis_pop(x)` | population excess kurtosis | NULL with no change |
| `geomean` (`geometric_mean`) | `geomean(x)` | geometric mean | NULL if a value is 0 or less |
| `harmonic_mean` | `harmonic_mean(x)` | harmonic mean | NULL if a value is 0 or less |
| `mode` | `mode(x)` or `mode() WITHIN GROUP (ORDER BY x)` | most frequent value | a tie gives the smallest value |
| `percentile_cont` (`quantile_cont`) | `percentile_cont(x, p)` or `percentile_cont(p) WITHIN GROUP (ORDER BY x)` | value at fraction p, between values | p must be 0 to 1 |
| `percentile_disc` (`quantile_disc`) | `percentile_disc(x, p)` or `... WITHIN GROUP (ORDER BY x)` | first real value at or above fraction p | any type that can be sorted |
| `median_abs_deviation` (`mad`) | `mad(x)` | median of \|x - median\| | NULL with no values |
| `iqr` | `iqr(x)` | 75th minus 25th percentile | NULL with no values |
| `range` | `range(x)` | max - min (for times: milliseconds, for DATE: days) | NULL with no values |
| `entropy` | `entropy(x)` | Shannon entropy of the values, in bits | NULL with no values |

#### skewness

- **Syntax:** `skewness(x)` (also `skew(x)`)
- **Description:** sample skewness, adjusted for the number of values (Fisher-Pearson G1, the same as Excel `SKEW` and pandas `skew()`). Positive: a long tail of big values. Negative: a long tail of small values.
- **Returns:** DOUBLE. **NULLs:** NULL values are skipped. NULL with fewer than 3 values or when all values are equal.
- **Example:** `SELECT symbol, round(skewness(r), 3) FROM (SELECT symbol, pct_return(close) OVER (PARTITION BY symbol ORDER BY time) AS r FROM candles) x GROUP BY symbol`

#### skewness_pop

- **Syntax:** `skewness_pop(x)`
- **Description:** population skewness g1 = m3 / m2^1.5, without the adjustment.
- **Returns:** DOUBLE. **NULLs:** NULL when all values are equal.
- **Example:** `SELECT skewness_pop(close) FROM candles WHERE symbol = 'CITY'`

#### kurtosis

- **Syntax:** `kurtosis(x)` (also `kurt(x)`)
- **Description:** sample excess kurtosis (G2, the same as Excel `KURT` and pandas `kurt()`). 0 is like a normal distribution; bigger means more extreme values ("fat tails").
- **Returns:** DOUBLE. **NULLs:** NULL with fewer than 4 values or when all values are equal.
- **Example:** `SELECT kurtosis(r) FROM (SELECT pct_return(close) AS r FROM candles WHERE symbol = 'TELCO') x`

#### kurtosis_pop

- **Syntax:** `kurtosis_pop(x)`
- **Description:** population excess kurtosis g2 = m4 / m2² - 3.
- **Returns:** DOUBLE. **NULLs:** NULL when all values are equal.
- **Example:** `SELECT kurtosis_pop(close) FROM candles WHERE symbol = 'TELCO'`

#### geomean

- **Syntax:** `geomean(x)` (also `geometric_mean(x)`)
- **Description:** the n-th root of the product of n values. For growth rates use `geomean(1 + r) - 1`.
- **Returns:** DOUBLE. **NULLs:** NULL values are skipped. NULL when any value is 0 or less.
- **Example:** `SELECT geomean(1 + r) - 1 AS avg_daily_growth FROM (SELECT pct_return(close) AS r FROM candles WHERE symbol = 'VOLT') x`

#### harmonic_mean

- **Syntax:** `harmonic_mean(x)`
- **Description:** n / Σ(1/x). The right average for ratios like P/E.
- **Returns:** DOUBLE. **NULLs:** NULL values are skipped. NULL when any value is 0 or less.
- **Example:** `SELECT harmonic_mean(close) FROM candles WHERE symbol = 'COAST'`

#### mode

- **Syntax:** `mode(x)` or `mode() WITHIN GROUP (ORDER BY x)`
- **Description:** the value that appears most often. Works for any type (numbers, text, times).
- **Returns:** the type of x. **NULLs:** NULL values are skipped. A tie gives the smallest value.
- **Example:** `SELECT mode(round(close, 0)) FROM candles WHERE symbol = 'CITY'`

#### percentile_cont

- **Syntax:** `percentile_cont(x, p)` or `percentile_cont(p) WITHIN GROUP (ORDER BY x)`; also `quantile_cont`
- **Description:** the value at fraction p of the sorted values, with linear interpolation between two values (the same rule as `median` and `percentile`). `p = 0.5` is the median.
- **Arguments:** x: numbers. p: a constant from 0 to 1 (the older `percentile(x, p)` also accepts 90 for 0.9; this one does not).
- **Returns:** DOUBLE. **NULLs:** NULL values are skipped. A NULL p gives NULL. `WITHIN GROUP (ORDER BY x DESC)` is not supported: use 1 - p.
- **Example:** `SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY volume) FROM candles`

#### percentile_disc

- **Syntax:** `percentile_disc(x, p)` or `percentile_disc(p) WITHIN GROUP (ORDER BY x)`; also `quantile_disc`
- **Description:** the first sorted value whose position is at or above fraction p. It is always one of the real values, so it also works for text and times.
- **Returns:** the type of x. **NULLs:** NULL values are skipped.
- **Example:** `SELECT percentile_disc(0.5) WITHIN GROUP (ORDER BY time) FROM candles`

#### median_abs_deviation

- **Syntax:** `median_abs_deviation(x)` (also `mad(x)`)
- **Description:** the median of the distances from the median. A robust measure of spread (not changed much by one extreme value). Multiply by 1.4826 to compare with a standard deviation.
- **Returns:** DOUBLE. **NULLs:** NULL values are skipped.
- **Example:** `SELECT symbol, mad(close) FROM candles GROUP BY symbol`

#### iqr

- **Syntax:** `iqr(x)`
- **Description:** interquartile range: `percentile_cont(x, 0.75) - percentile_cont(x, 0.25)`.
- **Returns:** DOUBLE. **NULLs:** NULL values are skipped.
- **Example:** `SELECT iqr(volume) FROM candles`

#### range

- **Syntax:** `range(x)`
- **Description:** `max(x) - min(x)`. Whole numbers stay whole numbers. For TIMESTAMP values it gives milliseconds, for DATE values days.
- **Returns:** LONG, DECIMAL or DOUBLE. **NULLs:** NULL values are skipped.
- **Example:** daily price range: `SELECT time, symbol, range(close) FROM ochl_minutes SAMPLE BY 1d`

#### entropy

- **Syntax:** `entropy(x)`
- **Description:** Shannon entropy of the distribution of values, in bits: -Σ p·log2(p). 0 means every value is the same.
- **Returns:** DOUBLE. **NULLs:** NULL values are skipped.
- **Example:** `SELECT entropy(buyer) FROM trade_log WHERE symbol = 'CITY'`

### Counting, conditions and picking rows

| Name | Syntax | Meaning | NULLs |
|---|---|---|---|
| `count_if` | `count_if(condition)` | rows where the condition is true | 0 with no rows |
| `sum_if` | `sum_if(x, condition)` | sum of x where the condition is true | NULL when no row matches |
| `avg_if` | `avg_if(x, condition)` | average of x where the condition is true | NULL when no row matches |
| `bool_and` (`every`) | `bool_and(b)` | true if every value is true | NULL values skipped |
| `bool_or` | `bool_or(b)` | true if any value is true | NULL values skipped |
| `arg_min` (`argmin`, `min_by`) | `arg_min(x, y)` | x of the row with the smallest y | rows with NULL y skipped |
| `arg_max` (`argmax`, `max_by`) | `arg_max(x, y)` | x of the row with the biggest y | rows with NULL y skipped |
| `approx_count_distinct` | `approx_count_distinct(x)` | number of different values (exact in KDB) | 0 with no rows |
| `sum_of_squares` | `sum_of_squares(x)` | Σx² | NULL with no values |
| `product` | `product(x)` | x1 × x2 × ... | NULL with no values, or when too big |
| `weighted_avg` (`wavg`) | `weighted_avg(x, weight)` | Σ(x·weight) / Σweight | NULL when the weights add up to 0 |
| `twap` | `twap(price, time)` | time-weighted average price | NULL with no rows |

#### count_if

- **Syntax:** `count_if(condition)`
- **Description:** counts the rows where the condition is true. The same as `count(CASE WHEN condition THEN 1 END)`.
- **Returns:** LONG. **NULLs:** a NULL condition is not counted. 0 with no rows.
- **Example:** up days per symbol: `SELECT symbol, count_if(close > open) AS up_days, count(*) AS days FROM candles GROUP BY symbol`

#### sum_if

- **Syntax:** `sum_if(x, condition)`
- **Description:** the sum of x over the rows where the condition is true. Whole numbers stay whole numbers.
- **Returns:** like `sum`. **NULLs:** NULL x values and rows where the condition is false or NULL are skipped. NULL when nothing is added.
- **Example:** `SELECT symbol, sum_if(volume, close > open) AS up_volume FROM candles GROUP BY symbol`

#### avg_if

- **Syntax:** `avg_if(x, condition)`
- **Description:** the average of x over the rows where the condition is true.
- **Returns:** DOUBLE. **NULLs:** as `sum_if`.
- **Example:** `SELECT avg_if(close - open, close > open) FROM candles`

#### bool_and

- **Syntax:** `bool_and(b)` (also `every(b)`)
- **Description:** true when every value is true.
- **Returns:** BOOL. **NULLs:** NULL values are skipped; NULL with no values.
- **Example:** did the price go up every day this week? `SELECT symbol, bool_and(close > open) FROM candles WHERE time >= '2026-09-06' GROUP BY symbol`

#### bool_or

- **Syntax:** `bool_or(b)`
- **Description:** true when at least one value is true.
- **Returns:** BOOL. **NULLs:** as `bool_and`.
- **Example:** `SELECT symbol, bool_or(high > 1000) FROM candles GROUP BY symbol`

#### arg_min

- **Syntax:** `arg_min(x, y)` (also `argmin`, `min_by`)
- **Description:** the value of x in the row where y is smallest. On a tie, the earliest row (by time) wins.
- **Returns:** the type of x. **NULLs:** rows where y is NULL are skipped; x may be NULL.
- **Example:** the day of the lowest close: `SELECT symbol, arg_min(time, close) FROM candles GROUP BY symbol`

#### arg_max

- **Syntax:** `arg_max(x, y)` (also `argmax`, `max_by`)
- **Description:** the value of x in the row where y is biggest. On a tie, the earliest row wins.
- **Returns:** the type of x. **NULLs:** as `arg_min`.
- **Example:** `SELECT symbol, arg_max(time, volume) AS busiest_day FROM candles GROUP BY symbol`

#### approx_count_distinct

- **Syntax:** `approx_count_distinct(x)`
- **Description:** the number of different values. KDB counts exactly; the name is for programs written for other databases.
- **Returns:** LONG. **NULLs:** NULL values are not counted; 0 with no rows.
- **Example:** `SELECT approx_count_distinct(buyer) FROM trade_log`

#### sum_of_squares

- **Syntax:** `sum_of_squares(x)`
- **Description:** Σx² (not the differences from the average: for those use `regr_sxx(x, x)`).
- **Returns:** DOUBLE. **NULLs:** NULL values are skipped.
- **Example:** `SELECT sqrt(sum_of_squares(r) / count(r)) FROM (SELECT pct_return(close) AS r FROM candles WHERE symbol = 'CITY') x`

#### product

- **Syntax:** `product(x)`
- **Description:** all values multiplied. For a total return: `product(1 + r) - 1`.
- **Returns:** DOUBLE. **NULLs:** NULL values are skipped. NULL when the result is too big for a DOUBLE.
- **Example:** `SELECT product(1 + r) - 1 AS total_return FROM (SELECT pct_return(close) AS r FROM candles WHERE symbol = 'COAST') x`

#### weighted_avg

- **Syntax:** `weighted_avg(x, weight)` (also `wavg`)
- **Description:** Σ(x × weight) / Σweight. `vwap(price, volume)` is the same with the volume as weight.
- **Returns:** DOUBLE. **NULLs:** rows where x or weight is NULL are skipped. NULL when the weights add up to 0.
- **Example:** `SELECT weighted_avg(rate, quantity) FROM trade_log WHERE symbol = 'CITY'`

#### twap

- **Syntax:** `twap(price, time)`
- **Description:** time-weighted average price. Each price counts for the time until the next price. The last price has no time after it, so it does not count (unless it is the only price). When every price has the same time, the plain average.
- **Arguments:** price: numbers. time: TIMESTAMP, DATE or milliseconds.
- **Returns:** DOUBLE. **NULLs:** rows where price or time is NULL are skipped.
- **Example:** `SELECT symbol, twap(ltp, timestamp) FROM live_data GROUP BY symbol`

### Text and JSON lists

| Name | Syntax | Meaning | NULLs |
|---|---|---|---|
| `string_agg` | `string_agg(x, separator)` | values joined as text, in time order | NULL values skipped |
| `listagg` | `listagg(x [, separator])` | the same; separator default `,` | NULL values skipped |
| `array_agg` (`json_agg`) | `array_agg(x)` | a JSON array of the values, in time order | NULL values become `null` |

#### string_agg

- **Syntax:** `string_agg(x, separator)`; `string_agg(DISTINCT x, separator)` for different values only
- **Description:** joins the values as text. The rows are joined in time order (the table's time column), or in the order they were read for tables without one.
- **Returns:** STRING. **NULLs:** NULL values are skipped. NULL when there is nothing to join.
- **Example:** `SELECT sector, string_agg(symbol, ', ') FROM securities GROUP BY sector`

#### listagg

- **Syntax:** `listagg(x [, separator])`
- **Description:** the same as `string_agg`; the separator is `,` when not given (Oracle's name).
- **Returns:** STRING. **NULLs:** as `string_agg`.
- **Example:** `SELECT listagg(symbol) FROM securities`

#### array_agg

- **Syntax:** `array_agg(x)` (also `json_agg(x)`)
- **Description:** a JSON array of all values, in time order. Use the JSON functions of chapter 18 to read it.
- **Returns:** JSON. **NULLs:** NULL values become `null` in the array. NULL with no rows.
- **Example:** `SELECT symbol, array_agg(close) FROM candles WHERE time >= '2026-09-06' GROUP BY symbol`

### Risk aggregates

These work on a column of **returns** (for example `pct_return(close)`, Part 3), in time order. Use a subquery to make the returns first. `periods` is the number of periods in one year: about 240 or 252 trading days (it depends on the exchange), 52 for weeks, 12 for months.

| Name | Syntax | Meaning | NULLs / too few rows |
|---|---|---|---|
| `sharpe_ratio` | `sharpe_ratio(r [, risk_free [, periods]])` | (average r - risk_free) / standard deviation × √periods | NULL with fewer than 2 returns or no change |
| `sortino_ratio` | `sortino_ratio(r [, target [, periods]])` | like Sharpe, but only falls below target count as risk | NULL when no return is below target |
| `calmar_ratio` | `calmar_ratio(r, periods)` | yearly growth / largest drawdown | NULL when there is no drawdown |
| `information_ratio` | `information_ratio(r, benchmark_r [, periods])` | average extra return / its standard deviation × √periods | NULL with fewer than 2 pairs |
| `max_drawdown` | `max_drawdown(price)` | largest fall from a peak, as a negative fraction | NULL if a price is 0 or less |
| `value_at_risk` | `value_at_risk(r, confidence)` | loss that is not passed with this confidence (historical) | NULL with no returns |
| `expected_shortfall` | `expected_shortfall(r, confidence)` | average loss in the worst cases beyond value at risk | NULL with no returns |

#### sharpe_ratio

- **Syntax:** `sharpe_ratio(r [, risk_free [, periods]])`
- **Description:** (average of r - risk_free) / sample standard deviation of r × √periods. risk_free is a return per period (default 0). periods default 1 (no yearly scaling). The same definition as the Python package empyrical.
- **Returns:** DOUBLE. **NULLs:** NULL returns are skipped. NULL with fewer than 2 returns or when every return is the same.
- **Example:** `SELECT symbol, round(sharpe_ratio(r, 0, 240), 2) FROM (SELECT symbol, time, pct_return(close) OVER (PARTITION BY symbol ORDER BY time) AS r FROM candles) x GROUP BY symbol`

#### sortino_ratio

- **Syntax:** `sortino_ratio(r [, target [, periods]])`
- **Description:** (average of r - target) / downside deviation × √periods. The downside deviation is √(average of min(0, r - target)²) over all returns (as empyrical). target default 0, periods default 1.
- **Returns:** DOUBLE. **NULLs:** NULL returns are skipped. NULL when no return is below the target.
- **Example:** `SELECT sortino_ratio(r, 0, 240) FROM (SELECT time, pct_return(close) AS r FROM candles WHERE symbol = 'CITY') x`

#### calmar_ratio

- **Syntax:** `calmar_ratio(r, periods)`
- **Description:** yearly growth rate / |max drawdown|. Wealth starts at 1 and is multiplied by (1 + r) for each return in time order. Yearly growth = wealth^(periods / number of returns) - 1. The drawdown is measured on that wealth, from the start value 1.
- **Returns:** DOUBLE. **NULLs:** NULL returns are skipped. NULL when the wealth never falls, or falls to 0 or less.
- **Example:** `SELECT calmar_ratio(r, 240) FROM (SELECT time, pct_return(close) AS r FROM candles WHERE symbol = 'VOLT') x`

#### information_ratio

- **Syntax:** `information_ratio(r, benchmark_r [, periods])`
- **Description:** average of (r - benchmark_r) / sample standard deviation of (r - benchmark_r) × √periods.
- **Returns:** DOUBLE. **NULLs:** pairs with a NULL are skipped; NULL with fewer than 2 pairs.
- **Example:** see [Beta against a benchmark](#beta-against-a-benchmark).

#### max_drawdown

- **Syntax:** `max_drawdown(price)`
- **Description:** the largest fall from a previous peak, in time order, as a fraction: -0.25 means the price fell 25 % below its highest point. 0 when the price never fell. Works on **prices** (for returns use `calmar_ratio`, or `product` in a subquery).
- **Returns:** DOUBLE, 0 or less. **NULLs:** NULL prices are skipped. NULL when a price is 0 or less.
- **Example:** `SELECT symbol, round(max_drawdown(close) * 100, 1) AS max_dd_pct FROM candles GROUP BY symbol`

#### value_at_risk

- **Syntax:** `value_at_risk(r, confidence)`
- **Description:** historical value at risk: the loss (as a positive number) that the returns did not pass in `confidence` of the cases. It is `-percentile_cont(r, 1 - confidence)`. 0.03 with confidence 0.95 means: on 95 % of days the loss was 3 % or less.
- **Arguments:** confidence: more than 0 and less than 1, like 0.95 or 0.99.
- **Returns:** DOUBLE. **NULLs:** NULL returns are skipped.
- **Example:** `SELECT symbol, value_at_risk(r, 0.95) FROM (SELECT symbol, time, pct_return(close) OVER (PARTITION BY symbol ORDER BY time) AS r FROM candles) x GROUP BY symbol`

#### expected_shortfall

- **Syntax:** `expected_shortfall(r, confidence)`
- **Description:** conditional value at risk: the average of the returns at or below the value-at-risk level, as a positive loss.
- **Returns:** DOUBLE. **NULLs:** NULL returns are skipped.
- **Example:** `SELECT expected_shortfall(r, 0.95) FROM (SELECT time, pct_return(close) AS r FROM candles WHERE symbol = 'TELCO') x`

### Money over time

| Name | Syntax | Meaning | NULLs |
|---|---|---|---|
| `xnpv` | `xnpv(rate, amount, date)` | net present value of cash flows on dates (Excel `XNPV`) | rows with NULL skipped |
| `xirr` | `xirr(amount, date [, guess])` | yearly rate that makes XNPV 0 (Excel `XIRR`) | NULL without both signs |

#### xnpv

- **Syntax:** `xnpv(rate, amount, date)`
- **Description:** Σ amount / (1 + rate)^(days since the first date / 365), like Excel `XNPV`. The first date is the earliest date.
- **Returns:** DOUBLE. **NULLs:** rows with a NULL amount or date are skipped. NULL when rate is -1 or less.
- **Example:** `SELECT xnpv(0.09, amount, d) FROM cash_flows` (a table with an `amount` DOUBLE and a `d` DATE column)

#### xirr

- **Syntax:** `xirr(amount, date [, guess])`
- **Description:** the yearly rate r where `xnpv(r, amount, date)` is 0, like Excel `XIRR`. Money you pay is negative, money you get is positive. Useful for the real return of a stock portfolio with buys, dividends and sells on different dates.
- **Returns:** DOUBLE (0.12 = 12 % per year). **NULLs:** rows with a NULL are skipped. NULL when all amounts have the same sign or no rate is found.
- **Example:** `SELECT xirr(amount, d) FROM cash_flows` (for Excel's example -10000, 2750, 4250, 3250, 2750 the result is 0.3733625...)

---

## Part 2: Window functions

### OVER and frames

A window function gets `OVER (...)`:

```sql
fn(...) OVER ([PARTITION BY expr, ...] [ORDER BY expr [ASC|DESC], ...] [frame])
```

The **frame** says which rows of the partition each row looks at. Aggregates (`sum`, `avg`, `corr`, ...), `first_value`, `last_value`, `nth_value`, `zscore` and `minmax_scale` use the frame. Ranks, `lag`, `lead` and the indicators ignore it.

| Frame | Rows for each row |
|---|---|
| no frame, no `ORDER BY` | the whole partition |
| no frame, with `ORDER BY` | from the first row of the partition to this row (running) |
| `ROWS n PRECEDING` | this row and n rows before it |
| `ROWS BETWEEN n PRECEDING AND m FOLLOWING` | n rows before to m rows after |
| `ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING` | this row to the last row |
| `ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING` | the 5 rows before, without this row |
| `RANGE BETWEEN '5 days' PRECEDING AND CURRENT ROW` | rows whose time is at most 5 days before this row's time |
| `RANGE BETWEEN 10 PRECEDING AND 10 FOLLOWING` | rows whose ORDER BY value is within 10 of this row's value |
| `RANGE BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING` | this row, rows with the same ORDER BY value, and all after |

Rules:

- Bounds: `UNBOUNDED PRECEDING`, `n PRECEDING`, `CURRENT ROW`, `n FOLLOWING`, `UNBOUNDED FOLLOWING`. The end must not be before the start.
- `ROWS n PRECEDING` without `BETWEEN` means `ROWS BETWEEN n PRECEDING AND CURRENT ROW`. `RANGE ... PRECEDING` alone is the same for RANGE.
- `RANGE` with a distance needs exactly one `ORDER BY` value, a number or a time. For TIMESTAMP write text like `'5 days'`, `'2 hours'`, `'30 minutes'`, `'1 week'` (or `INTERVAL '5 days'`), or a number of milliseconds. For DATE a number is days. Months and years are not supported (they have no fixed length).
- With `RANGE`, `CURRENT ROW` includes the rows with the **same** ORDER BY value (peers). A row with a NULL ORDER BY value has the other NULL rows as its peers.
- A frame with no rows gives NULL (`count` gives 0).
- Frames that start at the first row, or end at the last row, are computed in one pass. Other `BETWEEN` frames add up every frame again: `ROWS BETWEEN 200 PRECEDING AND 200 FOLLOWING` on a million rows is slow.

Example: the average close of the week around each day, and the volume of the last 7 calendar days (there are no candles on Fridays and Saturdays, so 7 days are 5 rows):

```sql
SELECT time, close,
       round(avg(close) OVER (ORDER BY time ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING), 2) AS centered_avg,
       sum(volume) OVER (ORDER BY time RANGE BETWEEN '6 days' PRECEDING AND CURRENT ROW) AS volume_7d
FROM candles WHERE symbol = 'CITY' AND time >= '2026-08-25';
```

02-frames.sql:

```text
time                     | close | centered_avg | volume_7d
-------------------------+-------+--------------+----------
2026-08-25T00:00:00.000Z | 423.5 |       413.83 |     68026
2026-08-26T00:00:00.000Z | 413.6 |       407.23 |    126161
2026-08-27T00:00:00.000Z | 404.4 |       402.96 |    179019
2026-08-30T00:00:00.000Z | 387.4 |        395.5 |    257039
2026-08-31T00:00:00.000Z | 385.9 |       390.38 |    337039
2026-09-01T00:00:00.000Z | 386.2 |       387.62 |    346933
2026-09-02T00:00:00.000Z |   388 |       389.42 |    360859
2026-09-03T00:00:00.000Z | 390.6 |       391.38 |    371217
2026-09-06T00:00:00.000Z | 396.4 |       392.76 |    361444
2026-09-07T00:00:00.000Z | 395.7 |       392.86 |    357067
2026-09-08T00:00:00.000Z | 393.1 |       391.16 |    358678
2026-09-09T00:00:00.000Z | 388.5 |       389.85 |    366060
2026-09-10T00:00:00.000Z | 382.1 |        387.9 |    378213
(13 rows, 4.9 ms)
```

### Ranking and position

| Name | Syntax | Meaning | NULLs |
|---|---|---|---|
| `row_number`, `rank`, `dense_rank` | `rank() OVER (...)` | see chapter 5 | NULL ORDER BY values sort last |
| `percent_rank` | `percent_rank() OVER (...)` | (rank - 1) / (rows - 1), 0 to 1 | one row gives 0 |
| `cume_dist` | `cume_dist() OVER (...)` | share of rows at or before this row's value, 0 to 1 | |
| `ntile` | `ntile(n) OVER (...)` | bucket number 1..n of about equal size | |
| `first_value` | `first_value(x) OVER (...)` | x of the first row of the frame | may be NULL |
| `last_value` | `last_value(x) OVER (...)` | x of the last row of the frame | may be NULL |
| `nth_value` | `nth_value(x, n) OVER (...)` | x of the n-th row of the frame | NULL when the frame is shorter |
| `lag`, `lead` | `lag(x [, k [, default]])` | x of k rows before (after) | default when there is no such row |

#### percent_rank

- **Syntax:** `percent_rank() OVER ([PARTITION BY ...] ORDER BY ...)`
- **Description:** relative rank: (rank - 1) / (rows in the partition - 1). The first row is 0, the last 1. Equal values get the same number.
- **Returns:** DOUBLE. **NULLs:** NULL ORDER BY values sort last. A partition of one row gives 0.
- **Example:** `SELECT symbol, time, percent_rank() OVER (PARTITION BY time ORDER BY volume) FROM candles WHERE time = '2026-09-10'`

#### cume_dist

- **Syntax:** `cume_dist() OVER ([PARTITION BY ...] ORDER BY ...)`
- **Description:** cumulative distribution: (rows with a value before or equal to this row's value) / rows in the partition.
- **Returns:** DOUBLE, more than 0 up to 1. **NULLs:** NULL ORDER BY values sort last.
- **Example:** `SELECT time, close, cume_dist() OVER (ORDER BY close) FROM candles WHERE symbol = 'TELCO'`

#### ntile

- **Syntax:** `ntile(n) OVER ([PARTITION BY ...] ORDER BY ...)`
- **Description:** splits the rows into n buckets numbered 1 to n. When the rows do not divide evenly, the first buckets get one row more (as PostgreSQL).
- **Arguments:** n: a whole number, 1 or more.
- **Returns:** LONG.
- **Example:** quartile of today's volume: `SELECT symbol, ntile(4) OVER (ORDER BY volume DESC) FROM candles WHERE time = '2026-09-10'`

#### first_value

- **Syntax:** `first_value(x) OVER (...)`
- **Description:** the value of x in the first row of the frame. Unlike `first(x)`, NULL is not skipped.
- **Returns:** the type of x. **NULLs:** NULL when that row's x is NULL, or the frame is empty.
- **Example:** `SELECT time, close, close / first_value(close) OVER (PARTITION BY symbol ORDER BY time) - 1 AS since_start FROM candles`

#### last_value

- **Syntax:** `last_value(x) OVER (...)`
- **Description:** the value of x in the last row of the frame. With the default running frame that is the current row; use `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` for the last row of the partition.
- **Returns:** the type of x. **NULLs:** NULL when that row's x is NULL, or the frame is empty.
- **Example:** `SELECT time, last_value(close) OVER (PARTITION BY symbol ORDER BY time ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) FROM candles`

#### nth_value

- **Syntax:** `nth_value(x, n) OVER (...)`
- **Description:** the value of x in the n-th row of the frame (1 = first).
- **Returns:** the type of x. **NULLs:** NULL when the frame has fewer than n rows.
- **Example:** `SELECT time, nth_value(close, 2) OVER (PARTITION BY symbol ORDER BY time) FROM candles`

#### lag

- **Syntax:** `lag(x [, k [, default]])`, `lead(x [, k [, default]])`
- **Description:** the value of x k rows before (lag) or after (lead) this row; k default 1. The third argument is new: the value to use when there is no such row (instead of NULL). It is evaluated for the current row.
- **Returns:** the type of x. **NULLs:** NULL (or the default) at the start (lag) or end (lead) of the partition.
- **Example:** `SELECT time, close - lag(close, 1, open) OVER (PARTITION BY symbol ORDER BY time) AS change FROM candles`

### Cumulative values

| Name | Syntax | Meaning | NULLs |
|---|---|---|---|
| `cumsum` | `cumsum(x)` | running total (chapter 5) | NULL values skipped |
| `cumprod` | `cumprod(x)` | running product | NULL values skipped; NULL before the first value |
| `cummax` | `cummax(x)` | highest value so far | NULL values skipped |
| `cummin` | `cummin(x)` | lowest value so far | NULL values skipped |

#### cumprod

- **Syntax:** `cumprod(x)` or `cumprod(x) OVER (PARTITION BY ... ORDER BY ...)`
- **Description:** the product of all values from the first row to this row (pandas `cumprod`). For growth of 1 dollar: `cumprod(1 + r)`.
- **Returns:** DOUBLE. **NULLs:** NULL values are skipped (the product stays). NULL before the first value.
- **Example:** `SELECT time, cumprod(1 + r) FROM (SELECT time, pct_return(close) AS r FROM candles WHERE symbol = 'CITY') x`

#### cummax

- **Syntax:** `cummax(x)` or `cummax(x) OVER (...)`
- **Description:** the highest value from the first row to this row (any type that can be compared).
- **Returns:** the type of x. **NULLs:** NULL values are skipped. NULL before the first value.
- **Example:** `SELECT time, close, cummax(high) OVER (PARTITION BY symbol ORDER BY time) AS highest_so_far FROM candles`

#### cummin

- **Syntax:** `cummin(x)` or `cummin(x) OVER (...)`
- **Description:** the lowest value from the first row to this row.
- **Returns:** the type of x. **NULLs:** as `cummax`.
- **Example:** `SELECT time, cummin(low) OVER (PARTITION BY symbol ORDER BY time) FROM candles`

---

## Part 3: Returns and risk (series)

These run over the rows in time order, like `sma`. Use `OVER (PARTITION BY symbol ORDER BY time)` for many symbols.

| Name | Syntax | Meaning | First value / NULLs |
|---|---|---|---|
| `pct_return` (`returns`, `percent_return`) | `pct_return(price [, k])` | price / price k rows before - 1 | row k+1; NULL when a price is NULL or the old one is 0 |
| `log_return` | `log_return(price [, k])` | ln(price / price k rows before) | row k+1; NULL when the ratio is 0 or less |
| `pct_change` | `pct_change(price)` | the same as `pct_return × 100` (chapter 5) | row 2 |
| `cum_return` | `cum_return(price)` | price / first price - 1 | row 1 |
| `drawdown` | `drawdown(price)` | price / highest price so far - 1 | row 1 |
| `volatility` | `volatility(price, n [, periods])` | standard deviation of the last n log returns × √periods | row n+1 |
| `zscore` | `zscore(x [, n])` | (x - average) / standard deviation | with n: row n |
| `minmax_scale` | `minmax_scale(x [, n])` | (x - min) / (max - min), 0 to 1 | with n: row n |
| `max_drawdown` | `max_drawdown(price) OVER (...)` | the aggregate of Part 1 as a running value | row 1 |

#### pct_return

- **Syntax:** `pct_return(price [, k])`; also `returns(price [, k])` and `percent_return(price [, k])`
- **Description:** simple return over k rows (default 1): price / price k rows before - 1. 0.02 means +2 %. `pct_change` gives the same in percent.
- **Returns:** DOUBLE. **NULLs:** NULL for the first k rows, when either price is NULL, or when the old price is 0.
- **Example:** `SELECT time, symbol, pct_return(close) OVER (PARTITION BY symbol ORDER BY time) FROM candles`

#### log_return

- **Syntax:** `log_return(price [, k])`
- **Description:** ln(price / price k rows before). Log returns add up over time: the sum of daily log returns is the log return of the whole period.
- **Returns:** DOUBLE. **NULLs:** NULL for the first k rows, when a price is NULL, or when the ratio is 0 or less.
- **Example:** `SELECT time, log_return(close, 5) OVER (PARTITION BY symbol ORDER BY time) AS week_log_return FROM candles`

#### cum_return

- **Syntax:** `cum_return(price)`
- **Description:** return since the first row of the partition: price / first price - 1.
- **Returns:** DOUBLE. **NULLs:** NULL for a NULL price; NULL values before the first price are skipped. NULL when the first price is 0.
- **Example:** `SELECT time, symbol, round(cum_return(close) OVER (PARTITION BY symbol ORDER BY time) * 100, 1) AS pct_since_start FROM candles`

#### drawdown

- **Syntax:** `drawdown(price)`
- **Description:** how far the price is below its highest price so far: price / running max - 1. 0 at a new high, -0.1 when 10 % below the high.
- **Returns:** DOUBLE, 0 or less. **NULLs:** NULL for a NULL price; NULL while the highest price is 0 or less.
- **Example:** see [Drawdown](#drawdown) in the cookbook.

#### volatility

- **Syntax:** `volatility(price, n [, periods])`
- **Description:** rolling volatility: the sample standard deviation of the last n log returns, times √periods. periods default 1 (daily volatility); use 240 or 252 (trading days) for yearly volatility.
- **Arguments:** n: whole number, 2 or more. periods: a number more than 0.
- **Returns:** DOUBLE. **NULLs:** NULL for the first n rows and while one of the last n+1 prices is NULL or 0 or less.
- **Example:** see [20-day volatility](#20-day-volatility).

#### zscore

- **Syntax:** `zscore(x [, n])`
- **Description:** how many standard deviations x is away from the average. With n: the average and the sample standard deviation of the last n rows. Without n: of the frame (the whole partition without ORDER BY, or with a `ROWS`/`RANGE` frame).
- **Returns:** DOUBLE. **NULLs:** NULL for a NULL x. With n: NULL for the first n - 1 rows and while a NULL is in the last n rows. Without n: NULL values in the frame are skipped. NULL when the standard deviation is 0.
- **Example:** unusual volume: `SELECT time, symbol, zscore(volume, 20) OVER (PARTITION BY symbol ORDER BY time) AS vol_z FROM candles`

#### minmax_scale

- **Syntax:** `minmax_scale(x [, n])`
- **Description:** (x - min) / (max - min) of the last n rows (or of the frame without n). 0 = at the low, 1 = at the high.
- **Returns:** DOUBLE from 0 to 1. **NULLs:** as `zscore`; NULL when max = min.
- **Example:** where is the close in its 52-week range? `SELECT time, minmax_scale(close, 240) OVER (PARTITION BY symbol ORDER BY time) FROM candles`

---

## Part 4: Technical indicators

All indicators are series functions over candles in time order. Most follow **TA-Lib**: the same formulas, and the first value on the same row as TA-Lib (the "warm-up" rows before it are NULL). Where TA-Lib versions differ for flat prices (a window where high = low, or no price change), KDB follows TA-Lib 0.6. The table says whose definition each one uses.

NULL rules for indicators:

- **Window indicators** (a fixed number of rows: WMA, Bollinger, Donchian, stochastic %K, CCI, Williams %R, Aroon, linear regression, ...): the result is NULL while a NULL input is inside the window, and comes back after it.
- **Running indicators** (they carry a value from row to row: EMA-based ones, MACD, KAMA, ADX, Parabolic SAR, OBV, A/D, MFI, SuperTrend, Heikin-Ashi): a NULL input makes the result NULL **from that row to the end** of the partition. Remove bad rows with `WHERE close IS NOT NULL` first.
- A period must be a whole number constant. `wma(close, volume)` is an error.

Defaults: arguments in `[ ]` can be left out; the default is shown after `=`.

### Moving averages

| Name | Syntax | Definition | First value (row) |
|---|---|---|---|
| `sma` | `sma(x, n)` | chapter 5 | n |
| `ema` | `ema(x, n)` | chapter 5 (TA-Lib) | n |
| `wma` | `wma(x, n)` | TA-Lib WMA: weights 1..n, newest heaviest | n |
| `dema` | `dema(x, n)` | TA-Lib DEMA: 2·EMA - EMA(EMA) | 2n - 1 |
| `tema` | `tema(x, n)` | TA-Lib TEMA: 3·EMA - 3·EMA(EMA) + EMA(EMA(EMA)) | 3n - 2 |
| `trima` | `trima(x, n)` | TA-Lib TRIMA: triangular weights | n |
| `kama` | `kama(x, n)` | TA-Lib KAMA (fast 2, slow 30) | n + 1 |
| `hma` | `hma(x, n)` | Hull: WMA(2·WMA(x, n/2) - WMA(x, n), √n) | n + ⌊√n⌋ - 1 |
| `vwma` | `vwma(price, volume, n)` | Σ(price·volume) / Σvolume of n rows | n |

#### wma

- **Syntax:** `wma(x, n)`
- **Description:** weighted moving average of the last n rows. The newest row has weight n, the oldest weight 1 (TA-Lib `WMA`).
- **Returns:** DOUBLE. **NULLs:** window rule; first value on row n.
- **Example:** `SELECT time, round(wma(close, 10) OVER (PARTITION BY symbol ORDER BY time), 2) FROM candles`

#### dema

- **Syntax:** `dema(x, n)`
- **Description:** double exponential moving average: 2·EMA(x) - EMA(EMA(x)), both EMAs as TA-Lib (started with an SMA). Reacts faster than EMA.
- **Returns:** DOUBLE. **NULLs:** running rule; first value on row 2n - 1.
- **Example:** `SELECT time, dema(close, 10) FROM candles WHERE symbol = 'CITY'`

#### tema

- **Syntax:** `tema(x, n)`
- **Description:** triple exponential moving average: 3·EMA1 - 3·EMA2 + EMA3, where EMA2 is the EMA of EMA1 and EMA3 the EMA of EMA2 (TA-Lib `TEMA`).
- **Returns:** DOUBLE. **NULLs:** running rule; first value on row 3n - 2.
- **Example:** `SELECT time, tema(close, 10) FROM candles WHERE symbol = 'CITY'`

#### trima

- **Syntax:** `trima(x, n)`
- **Description:** triangular moving average: the middle rows get the most weight (weights 1, 2, ..., 2, 1). The same as TA-Lib `TRIMA` (an SMA of an SMA).
- **Returns:** DOUBLE. **NULLs:** window rule; first value on row n.
- **Example:** `SELECT time, trima(close, 10) FROM candles WHERE symbol = 'COAST'`

#### kama

- **Syntax:** `kama(x, n)`
- **Description:** Kaufman adaptive moving average (TA-Lib `KAMA`). The efficiency ratio over n rows (net change / sum of all changes) picks a speed between a 2-row and a 30-row EMA. It follows trends and stays flat in noise.
- **Returns:** DOUBLE. **NULLs:** running rule; first value on row n + 1.
- **Example:** `SELECT time, kama(close, 10) FROM candles WHERE symbol = 'VOLT'`

#### hma

- **Syntax:** `hma(x, n)`
- **Description:** Hull moving average (Alan Hull; not in TA-Lib): WMA(2·WMA(x, n/2) - WMA(x, n), ⌊√n⌋), with n/2 rounded down. Smooth and fast.
- **Arguments:** n: 2 or more.
- **Returns:** DOUBLE. **NULLs:** window rule; first value on row n + ⌊√n⌋ - 1.
- **Example:** `SELECT time, hma(close, 16) FROM candles WHERE symbol = 'TELCO'`

#### vwma

- **Syntax:** `vwma(price, volume, n)`
- **Description:** volume-weighted moving average of the last n rows: Σ(price × volume) / Σvolume (TradingView `ta.vwma`).
- **Returns:** DOUBLE. **NULLs:** window rule; NULL when the volumes add up to 0.
- **Example:** `SELECT time, vwma(close, volume, 20) FROM candles WHERE symbol = 'CITY'`

VWAP for a trading session or a rolling window needs no new function: `vwap(close, volume) OVER (PARTITION BY symbol, date_trunc('day', time) ORDER BY time)` (session, on minute candles) and `vwap(close, volume) OVER (PARTITION BY symbol ORDER BY time ROWS 19 PRECEDING)` (rolling).

### MACD

| Name | Syntax | Definition | First value (row) |
|---|---|---|---|
| `macd` | `macd(x [, fast = 12, slow = 26, signal = 9])` | TA-Lib MACD line | slow + signal - 1 (34) |
| `macd_signal` | `macd_signal(x [, 12, 26, 9])` | EMA of the MACD line | slow + signal - 1 |
| `macd_hist` | `macd_hist(x [, 12, 26, 9])` | line - signal | slow + signal - 1 |

#### macd

- **Syntax:** `macd(x [, fast [, slow [, signal]]])`, defaults 12, 26, 9
- **Description:** the MACD line: EMA(x, fast) - EMA(x, slow), exactly as TA-Lib `MACD`: both EMAs start on row `slow` (the fast EMA starts with the SMA of the `fast` rows ending there), and all three outputs start on row slow + signal - 1, where the signal line has its first value. (TradingView shows the line 8 rows earlier; the values after row 34 agree once the EMAs have settled.) If slow is smaller than fast they are swapped, as in TA-Lib.
- **Returns:** DOUBLE. **NULLs:** running rule.
- **Example:** see [MACD crossover signals](#macd-crossover-signals).

#### macd_signal

- **Syntax:** `macd_signal(x [, fast [, slow [, signal]]])`
- **Description:** the signal line: an EMA (TA-Lib style) of the MACD line over `signal` rows.
- **Returns:** DOUBLE. **NULLs:** running rule.
- **Example:** `SELECT time, macd(close), macd_signal(close) FROM candles WHERE symbol = 'CITY'`

#### macd_hist

- **Syntax:** `macd_hist(x [, fast [, slow [, signal]]])`
- **Description:** the histogram: MACD line - signal line. It changes sign when the lines cross.
- **Returns:** DOUBLE. **NULLs:** running rule.
- **Example:** `SELECT time, macd_hist(close, 12, 26, 9) FROM candles WHERE symbol = 'CITY'`

### Oscillators

| Name | Syntax | Definition | First value (row) |
|---|---|---|---|
| `rsi` | `rsi(x, n)` | chapter 5 (Wilder, TA-Lib start) | n + 1 |
| `stoch_k` | `stoch_k(high, low, close [, k = 14, k_smooth = 3, d = 3])` | TA-Lib STOCH slow %K | k + k_smooth + d - 2 |
| `stoch_d` | `stoch_d(high, low, close [, 14, 3, 3])` | TA-Lib STOCH slow %D | k + k_smooth + d - 2 |
| `stochf_k` | `stochf_k(high, low, close [, n = 14])` | raw (fast) %K | n |
| `stochrsi_k` | `stochrsi_k(x [, n = 14, k = 5, d = 3])` | TA-Lib STOCHRSI fast %K | n + k + d - 1 |
| `stochrsi_d` | `stochrsi_d(x [, 14, 5, 3])` | TA-Lib STOCHRSI fast %D | n + k + d - 1 |
| `willr` (`williams_r`) | `willr(high, low, close [, n = 14])` | TA-Lib WILLR, -100 to 0 | n |
| `cci` | `cci(high, low, close [, n = 20])` | TA-Lib CCI | n |
| `roc` | `roc(x [, n = 10])` | TA-Lib ROC: (x / x n rows before - 1) × 100 | n + 1 |
| `rocp` | `rocp(x [, n = 10])` | (x - old) / old | n + 1 |
| `rocr` | `rocr(x [, n = 10])` | x / old | n + 1 |
| `mom` (`momentum`) | `mom(x [, n = 10])` | x - x n rows before | n + 1 |
| `trix` | `trix(x [, n = 30])` | TA-Lib TRIX: 1-row ROC of a triple EMA | 3n - 1 |

#### stoch_k

- **Syntax:** `stoch_k(high, low, close [, k [, k_smooth [, d]]])`, defaults 14, 3, 3
- **Description:** slow stochastic %K (TA-Lib `STOCH` with SMA smoothing): raw %K = 100 × (close - lowest low of k rows) / (highest high - lowest low), 0 when the high equals the low; slow %K = SMA of raw %K over k_smooth rows. As in TA-Lib, %K and %D both start on row k + k_smooth + d - 2. TA-Lib's own default k is 5; KDB uses the common 14.
- **Returns:** DOUBLE, 0 to 100. **NULLs:** window rule.
- **Example:** `SELECT time, stoch_k(high, low, close), stoch_d(high, low, close) FROM candles WHERE symbol = 'COAST'`

#### stoch_d

- **Syntax:** `stoch_d(high, low, close [, k [, k_smooth [, d]]])`
- **Description:** slow %D: SMA of slow %K over d rows.
- **Returns:** DOUBLE, 0 to 100. **NULLs:** window rule.
- **Example:** `SELECT time FROM (SELECT time, stoch_k(high, low, close) AS k, stoch_d(high, low, close) AS d FROM candles WHERE symbol = 'COAST') s WHERE k > 80 AND d > 80`

#### stochf_k

- **Syntax:** `stochf_k(high, low, close [, n])`
- **Description:** the raw (fast) stochastic %K of the last n rows, without smoothing.
- **Returns:** DOUBLE, 0 to 100. **NULLs:** window rule; first value on row n.
- **Example:** `SELECT time, stochf_k(high, low, close, 5) FROM candles WHERE symbol = 'COAST'`

#### stochrsi_k

- **Syntax:** `stochrsi_k(x [, n [, k [, d]]])`, defaults 14, 5, 3 (TA-Lib's defaults)
- **Description:** stochastic RSI %K (TA-Lib `STOCHRSI`): the fast stochastic of RSI(n) over k rows. The RSI is TA-Lib's (a flat start gives 0).
- **Returns:** DOUBLE, 0 to 100. **NULLs:** running rule (the RSI); first value on row n + k + d - 1.
- **Example:** `SELECT time, stochrsi_k(close), stochrsi_d(close) FROM candles WHERE symbol = 'VOLT'`

#### stochrsi_d

- **Syntax:** `stochrsi_d(x [, n [, k [, d]]])`
- **Description:** SMA of stochastic RSI %K over d rows.
- **Returns:** DOUBLE, 0 to 100. **NULLs:** as `stochrsi_k`.
- **Example:** `SELECT time, stochrsi_d(close, 14, 14, 3) FROM candles WHERE symbol = 'VOLT'`

#### willr

- **Syntax:** `willr(high, low, close [, n])` (also `williams_r`), default 14
- **Description:** Williams %R (TA-Lib `WILLR`): -100 × (highest high - close) / (highest high - lowest low) over n rows. 0 = at the high, -100 = at the low; 0 when the high equals the low.
- **Returns:** DOUBLE, -100 to 0. **NULLs:** window rule; first value on row n.
- **Example:** `SELECT time, willr(high, low, close) FROM candles WHERE symbol = 'TELCO'`

#### cci

- **Syntax:** `cci(high, low, close [, n])`, default 20
- **Description:** commodity channel index (TA-Lib `CCI`): (typical price - its n-row average) / (0.015 × mean absolute deviation). Typical price = (high + low + close) / 3. 0 when the deviation is 0.
- **Returns:** DOUBLE. **NULLs:** window rule; first value on row n.
- **Example:** `SELECT time, cci(high, low, close) FROM candles WHERE symbol = 'TELCO'`

#### roc

- **Syntax:** `roc(x [, n])`, default 10
- **Description:** rate of change in percent (TA-Lib `ROC`): (x / x n rows before - 1) × 100.
- **Returns:** DOUBLE. **NULLs:** NULL when a value is NULL or the old value is 0 (TA-Lib gives 0 there).
- **Example:** `SELECT time, roc(close, 10) FROM candles WHERE symbol = 'CITY'`

#### rocp

- **Syntax:** `rocp(x [, n])`
- **Description:** rate of change as a fraction (TA-Lib `ROCP`): (x - old) / old.
- **Returns:** DOUBLE. **NULLs:** as `roc`.
- **Example:** `SELECT time, rocp(close) FROM candles WHERE symbol = 'CITY'`

#### rocr

- **Syntax:** `rocr(x [, n])`
- **Description:** rate of change ratio (TA-Lib `ROCR`): x / old.
- **Returns:** DOUBLE. **NULLs:** as `roc`.
- **Example:** `SELECT time, rocr(close, 3) FROM candles WHERE symbol = 'CITY'`

#### mom

- **Syntax:** `mom(x [, n])` (also `momentum`), default 10
- **Description:** momentum (TA-Lib `MOM`): x - x n rows before.
- **Returns:** DOUBLE. **NULLs:** NULL when a value is NULL.
- **Example:** `SELECT time, momentum(close, 5) FROM candles WHERE symbol = 'CITY'`

#### trix

- **Syntax:** `trix(x [, n])`, default 30
- **Description:** TRIX (TA-Lib): the 1-row rate of change in percent of EMA(EMA(EMA(x, n))).
- **Returns:** DOUBLE. **NULLs:** running rule; first value on row 3n - 1.
- **Example:** `SELECT time, trix(close, 10) FROM candles WHERE symbol = 'VOLT'`

### Volatility and bands

| Name | Syntax | Definition | First value (row) |
|---|---|---|---|
| `atr` | `atr(high, low, close, n)` | chapter 5 (TA-Lib) | n + 1 |
| `natr` | `natr(high, low, close [, n = 14])` | TA-Lib NATR: ATR / close × 100 | n + 1 |
| `trange` (`true_range`) | `trange(high, low, close)` | TA-Lib TRANGE | 2 |
| `bb_upper`, `bb_middle`, `bb_lower` | `bb_upper(x [, n = 20, k = 2])` | Bollinger: SMA ± k × population std. dev. | n |
| `bb_percent_b` | `bb_percent_b(x [, 20, 2])` | (x - lower) / (upper - lower) | n |
| `bb_width` | `bb_width(x [, 20, 2])` | (upper - lower) / middle | n |
| `kc_upper`, `kc_middle`, `kc_lower` | `kc_upper(high, low, close [, n = 20, mult = 2, atr_n = 10])` | Keltner: EMA(close, n) ± mult × ATR(atr_n) | max(n, atr_n + 1) |
| `dc_upper`, `dc_middle`, `dc_lower` | `dc_upper(high, low [, n = 20])` | Donchian: highest high / middle / lowest low | n |

#### natr

- **Syntax:** `natr(high, low, close [, n])`, default 14
- **Description:** normalized ATR (TA-Lib `NATR`): ATR(n) / close × 100, so symbols with different prices can be compared.
- **Returns:** DOUBLE. **NULLs:** running rule; NULL when close is 0.
- **Example:** `SELECT symbol, natr(high, low, close) OVER (PARTITION BY symbol ORDER BY time) FROM candles`

#### trange

- **Syntax:** `trange(high, low, close)` (also `true_range`)
- **Description:** true range (TA-Lib `TRANGE`): the biggest of high - low, |high - previous close|, |low - previous close|. The first row is NULL (no previous close), as in TA-Lib.
- **Returns:** DOUBLE. **NULLs:** NULL when a value of this row or the previous close is NULL.
- **Example:** `SELECT time, trange(high, low, close) FROM candles WHERE symbol = 'CITY'`

#### bb_upper

- **Syntax:** `bb_upper(x [, n [, k]])`, `bb_middle(x [, n [, k]])`, `bb_lower(x [, n [, k]])`; defaults 20, 2
- **Description:** Bollinger bands: middle = SMA(x, n); upper and lower = middle ± k × the **population** standard deviation of the last n values (as John Bollinger and TA-Lib `BBANDS` with SMA). TA-Lib's own default n is 5; KDB uses the common 20.
- **Returns:** DOUBLE. **NULLs:** window rule; first value on row n.
- **Example:** `SELECT time, close, bb_lower(close), bb_middle(close), bb_upper(close) FROM candles WHERE symbol = 'CITY'`

#### bb_percent_b

- **Syntax:** `bb_percent_b(x [, n [, k]])`
- **Description:** %b: where x is inside the bands: 0 = at the lower band, 1 = at the upper band (it can be below 0 or above 1).
- **Returns:** DOUBLE. **NULLs:** window rule; NULL when the bands are equal (no change).
- **Example:** `SELECT time, bb_percent_b(close) FROM candles WHERE symbol = 'CITY'`

#### bb_width

- **Syntax:** `bb_width(x [, n [, k]])`
- **Description:** band width: (upper - lower) / middle, a fraction (multiply by 100 for percent). Small values mean a "squeeze" (quiet prices).
- **Returns:** DOUBLE. **NULLs:** window rule; NULL when the middle is 0.
- **Example:** see [Bollinger squeeze filter](#bollinger-squeeze-filter).

#### kc_upper

- **Syntax:** `kc_upper(high, low, close [, n [, mult [, atr_n]]])`, `kc_lower(...)`, `kc_middle(high, low, close [, n])`; defaults 20, 2, 10
- **Description:** Keltner channels (the Linda Raschke version): middle = EMA(close, n) as TA-Lib; upper and lower = middle ± mult × ATR(atr_n) (TA-Lib ATR).
- **Returns:** DOUBLE. **NULLs:** running rule; first value when both the EMA and the ATR have values.
- **Example:** `SELECT time, kc_lower(high, low, close), kc_upper(high, low, close) FROM candles WHERE symbol = 'VOLT'`

#### dc_upper

- **Syntax:** `dc_upper(high, low [, n])`, `dc_lower(high, low [, n])`, `dc_middle(high, low [, n])`; default 20
- **Description:** Donchian channels: the highest high, the lowest low, and their middle, over the last n rows (this row included, as TradingView).
- **Returns:** DOUBLE. **NULLs:** window rule; first value on row n.
- **Example:** new 20-day highs: `SELECT time, symbol FROM (SELECT time, symbol, high, dc_upper(high, low, 20) OVER (PARTITION BY symbol ORDER BY time) AS top FROM candles) x WHERE high = top`

### Trend strength and direction

| Name | Syntax | Definition | First value (row) |
|---|---|---|---|
| `plus_di`, `minus_di` | `plus_di(high, low, close [, n = 14])` | TA-Lib PLUS_DI / MINUS_DI | n + 1 |
| `dx` | `dx(high, low, close [, n = 14])` | TA-Lib DX | n + 1 |
| `adx` | `adx(high, low, close [, n = 14])` | TA-Lib ADX | 2n |
| `adxr` | `adxr(high, low, close [, n = 14])` | TA-Lib ADXR | 3n - 1 |
| `aroon_up` | `aroon_up(high [, n = 14])` | TA-Lib AROON up | n + 1 |
| `aroon_down` | `aroon_down(low [, n = 14])` | TA-Lib AROON down | n + 1 |
| `aroon_osc` | `aroon_osc(high, low [, n = 14])` | TA-Lib AROONOSC | n + 1 |
| `sar` (`parabolic_sar`) | `sar(high, low [, acceleration = 0.02, maximum = 0.2])` | TA-Lib SAR | 2 |
| `supertrend` | `supertrend(high, low, close [, n = 10, multiplier = 3])` | TradingView `ta.supertrend` | n |
| `supertrend_direction` | `supertrend_direction(high, low, close [, 10, 3])` | 1 up, -1 down | n |
| `linearreg` (`linreg`) | `linearreg(x [, n = 14])` | TA-Lib LINEARREG | n |
| `linearreg_slope` | `linearreg_slope(x [, 14])` | TA-Lib LINEARREG_SLOPE | n |
| `linearreg_intercept` | `linearreg_intercept(x [, 14])` | TA-Lib LINEARREG_INTERCEPT | n |
| `linearreg_angle` | `linearreg_angle(x [, 14])` | TA-Lib LINEARREG_ANGLE (degrees) | n |
| `tsf` | `tsf(x [, 14])` | TA-Lib TSF: the line's value one row ahead | n |

#### plus_di

- **Syntax:** `plus_di(high, low, close [, n])`, `minus_di(high, low, close [, n])`; default 14
- **Description:** directional indicators (TA-Lib `PLUS_DI`, `MINUS_DI`): Wilder-smoothed +DM (or -DM) divided by the smoothed true range, × 100. As TA-Lib, the first n - 1 moves are added up and the n-th is the first smoothing step.
- **Arguments:** n: 2 or more.
- **Returns:** DOUBLE, 0 to 100. **NULLs:** running rule; 0 when the true range is 0.
- **Example:** `SELECT time, plus_di(high, low, close), minus_di(high, low, close) FROM candles WHERE symbol = 'CITY'`

#### dx

- **Syntax:** `dx(high, low, close [, n])`
- **Description:** directional movement index (TA-Lib `DX`): 100 × |+DI - -DI| / (+DI + -DI).
- **Returns:** DOUBLE, 0 to 100. **NULLs:** running rule. When it cannot be computed (no movement) the value before it is kept (0 on the first row).
- **Example:** `SELECT time, dx(high, low, close) FROM candles WHERE symbol = 'CITY'`

#### adx

- **Syntax:** `adx(high, low, close [, n])`, default 14
- **Description:** average directional index (TA-Lib `ADX`): the average of the first n DX values, then Wilder smoothing. Above 25 is often read as a strong trend.
- **Returns:** DOUBLE, 0 to 100. **NULLs:** running rule; first value on row 2n.
- **Example:** `SELECT time, symbol, adx(high, low, close) OVER (PARTITION BY symbol ORDER BY time) FROM candles`

#### adxr

- **Syntax:** `adxr(high, low, close [, n])`
- **Description:** ADX rating (TA-Lib `ADXR`): (ADX + ADX n - 1 rows before) / 2.
- **Returns:** DOUBLE. **NULLs:** running rule; first value on row 3n - 1.
- **Example:** `SELECT time, adxr(high, low, close) FROM candles WHERE symbol = 'CITY'`

#### aroon_up

- **Syntax:** `aroon_up(high [, n])`, `aroon_down(low [, n])`; default 14
- **Description:** Aroon (TA-Lib `AROON`): 100 × (n - rows since the highest high) / n, over the last n + 1 rows. When the extreme appears twice, the newest one counts (as TA-Lib). `aroon_down` uses the lowest low.
- **Returns:** DOUBLE, 0 to 100. **NULLs:** window rule; first value on row n + 1.
- **Example:** `SELECT time, aroon_up(high), aroon_down(low) FROM candles WHERE symbol = 'COAST'`

#### aroon_osc

- **Syntax:** `aroon_osc(high, low [, n])`
- **Description:** Aroon oscillator (TA-Lib `AROONOSC`): aroon up - aroon down.
- **Returns:** DOUBLE, -100 to 100. **NULLs:** window rule.
- **Example:** `SELECT time, aroon_osc(high, low, 25) FROM candles WHERE symbol = 'COAST'`

#### sar

- **Syntax:** `sar(high, low [, acceleration [, maximum]])` (also `parabolic_sar`), defaults 0.02 and 0.2
- **Description:** Parabolic SAR (TA-Lib `SAR`). The first direction comes from the first two candles (down when the low fell more than the high rose). The value is a stop level below the price in an up trend and above it in a down trend; it flips when the price crosses it.
- **Returns:** DOUBLE. **NULLs:** running rule; first value on row 2.
- **Example:** `SELECT time, close, sar(high, low) FROM candles WHERE symbol = 'TELCO'`

#### supertrend

- **Syntax:** `supertrend(high, low, close [, n [, multiplier]])`, defaults 10 and 3
- **Description:** SuperTrend exactly as TradingView's `ta.supertrend(multiplier, n)`: bands (high + low) / 2 ± multiplier × ATR, where the ATR is TradingView's (`ta.rma` of the true range, the first true range = high - low). The line is the lower band in an up trend and the upper band in a down trend.
- **Returns:** DOUBLE. **NULLs:** running rule; first value on row n.
- **Example:** `SELECT time, close, supertrend(high, low, close) FROM candles WHERE symbol = 'VOLT'`

#### supertrend_direction

- **Syntax:** `supertrend_direction(high, low, close [, n [, multiplier]])`
- **Description:** the trend of `supertrend`: **1 = up, -1 = down**. (TradingView's `direction` uses the opposite signs: -1 for up.)
- **Returns:** LONG. **NULLs:** running rule.
- **Example:** the days the trend changed (`lag` needs its own level, and the filter one more): `SELECT time, d FROM (SELECT time, d, lag(d) AS prev FROM (SELECT time, supertrend_direction(high, low, close) AS d FROM candles WHERE symbol = 'VOLT') s) x WHERE d != prev`

#### linearreg

- **Syntax:** `linearreg(x [, n])` (also `linreg`), default 14
- **Description:** linear regression (TA-Lib `LINEARREG`): the least-squares line through the last n values, and its value on the current row.
- **Returns:** DOUBLE. **NULLs:** window rule; first value on row n.
- **Example:** `SELECT time, close, linearreg(close, 20) FROM candles WHERE symbol = 'CITY'`

#### linearreg_slope

- **Syntax:** `linearreg_slope(x [, n])` (also `linreg_slope`)
- **Description:** the slope of that line: change per row (TA-Lib `LINEARREG_SLOPE`).
- **Returns:** DOUBLE. **NULLs:** window rule.
- **Example:** `SELECT symbol, linearreg_slope(close, 20) OVER (PARTITION BY symbol ORDER BY time) FROM candles`

#### linearreg_intercept

- **Syntax:** `linearreg_intercept(x [, n])` (also `linreg_intercept`)
- **Description:** the line's value on the oldest row of the window (TA-Lib `LINEARREG_INTERCEPT`).
- **Returns:** DOUBLE. **NULLs:** window rule.
- **Example:** `SELECT time, linearreg_intercept(close) FROM candles WHERE symbol = 'CITY'`

#### linearreg_angle

- **Syntax:** `linearreg_angle(x [, n])` (also `linreg_angle`)
- **Description:** atan(slope) in degrees (TA-Lib `LINEARREG_ANGLE`). It depends on the price scale, so compare it only within one symbol.
- **Returns:** DOUBLE, -90 to 90. **NULLs:** window rule.
- **Example:** `SELECT time, linearreg_angle(close) FROM candles WHERE symbol = 'CITY'`

#### tsf

- **Syntax:** `tsf(x [, n])`
- **Description:** time series forecast (TA-Lib `TSF`): the regression line's value one row after the current row.
- **Returns:** DOUBLE. **NULLs:** window rule.
- **Example:** `SELECT time, close, tsf(close, 14) FROM candles WHERE symbol = 'CITY'`

### Ichimoku

| Name | Syntax | Meaning | First value (row) |
|---|---|---|---|
| `ichimoku_tenkan` | `ichimoku_tenkan(high, low [, n = 9])` | (highest high + lowest low) / 2 of n rows | n |
| `ichimoku_kijun` | `ichimoku_kijun(high, low [, n = 26])` | the same over 26 rows | n |
| `ichimoku_senkou_a` | `ichimoku_senkou_a(high, low [, tenkan = 9, kijun = 26, shift = 26])` | (tenkan + kijun) / 2 from `shift` rows before | kijun + shift |
| `ichimoku_senkou_b` | `ichimoku_senkou_b(high, low [, n = 52, shift = 26])` | 52-row middle from `shift` rows before | n + shift |
| `ichimoku_chikou` | `ichimoku_chikou(close [, shift = 26])` | the close `shift` rows **after** this row | NULL on the last `shift` rows |

#### ichimoku_tenkan

- **Syntax:** `ichimoku_tenkan(high, low [, n])`
- **Description:** conversion line: (highest high + lowest low) / 2 over the last n rows.
- **Returns:** DOUBLE. **NULLs:** window rule.
- **Example:** `SELECT time, ichimoku_tenkan(high, low), ichimoku_kijun(high, low) FROM candles WHERE symbol = 'CITY'`

#### ichimoku_kijun

- **Syntax:** `ichimoku_kijun(high, low [, n])`
- **Description:** base line: the same as tenkan over 26 rows.
- **Returns:** DOUBLE. **NULLs:** window rule.
- **Example:** as `ichimoku_tenkan`.

#### ichimoku_senkou_a

- **Syntax:** `ichimoku_senkou_a(high, low [, tenkan [, kijun [, shift]]])`
- **Description:** leading span A. A chart draws it `shift` rows **ahead**; a table has no future rows, so KDB puts on each row the value that was computed `shift` rows before (the cloud as drawn over that row). Pass shift 25 to match TradingView, which draws it 25 bars ahead.
- **Returns:** DOUBLE. **NULLs:** window rule.
- **Example:** price above the cloud: `SELECT time FROM (SELECT time, close, ichimoku_senkou_a(high, low) AS a, ichimoku_senkou_b(high, low) AS b FROM candles WHERE symbol = 'CITY') x WHERE close > greatest(a, b)`

#### ichimoku_senkou_b

- **Syntax:** `ichimoku_senkou_b(high, low [, n [, shift]])`
- **Description:** leading span B: the n-row middle price (default 52) from `shift` rows before.
- **Returns:** DOUBLE. **NULLs:** window rule.
- **Example:** as `ichimoku_senkou_a`.

#### ichimoku_chikou

- **Syntax:** `ichimoku_chikou(close [, shift])`
- **Description:** lagging span: a chart draws today's close `shift` rows back. On a table row it is the close `shift` rows **later** (like `lead(close, 26)`). The last `shift` rows are NULL. It looks into the future: never use it for a trading signal on the newest day.
- **Returns:** DOUBLE. **NULLs:** NULL on the last `shift` rows.
- **Example:** `SELECT time, ichimoku_chikou(close) FROM candles WHERE symbol = 'CITY'`

### Volume

| Name | Syntax | Definition | First value (row) |
|---|---|---|---|
| `obv` | `obv(close, volume)` | TA-Lib OBV (starts with the first volume) | 1 |
| `ad` (`ad_line`) | `ad(high, low, close, volume)` | TA-Lib AD (accumulation/distribution) | 1 |
| `cmf` | `cmf(high, low, close, volume [, n = 20])` | Chaikin money flow | n |
| `adosc` (`chaikin_osc`) | `adosc(high, low, close, volume [, fast = 3, slow = 10])` | TA-Lib ADOSC | slow |
| `mfi` | `mfi(high, low, close, volume [, n = 14])` | TA-Lib MFI | n + 1 |
| `efi` (`force_index`) | `efi(close, volume [, n = 13])` | Elder's force index, EMA of (change × volume) | n + 1 |
| `eom` (`ease_of_movement`) | `eom(high, low, volume [, n = 14, divisor = 100000000])` | ease of movement (pandas-ta) | n + 1 |

#### obv

- **Syntax:** `obv(close, volume)`
- **Description:** on-balance volume (TA-Lib `OBV`): starts with the first row's volume, then adds the volume on up closes and subtracts it on down closes.
- **Returns:** DOUBLE. **NULLs:** running rule.
- **Example:** `SELECT time, obv(close, volume) OVER (PARTITION BY symbol ORDER BY time) FROM candles`

#### ad

- **Syntax:** `ad(high, low, close, volume)` (also `ad_line`)
- **Description:** accumulation/distribution line (TA-Lib `AD`): running sum of ((close - low) - (high - close)) / (high - low) × volume. Rows with high = low add nothing.
- **Returns:** DOUBLE. **NULLs:** running rule.
- **Example:** `SELECT time, ad(high, low, close, volume) FROM candles WHERE symbol = 'COAST'`

#### cmf

- **Syntax:** `cmf(high, low, close, volume [, n])`, default 20
- **Description:** Chaikin money flow: Σ(money flow multiplier × volume) / Σvolume over n rows; the multiplier is ((close - low) - (high - close)) / (high - low), 0 when high = low.
- **Returns:** DOUBLE, -1 to 1. **NULLs:** window rule; NULL when the volumes add up to 0.
- **Example:** `SELECT time, cmf(high, low, close, volume) FROM candles WHERE symbol = 'COAST'`

#### adosc

- **Syntax:** `adosc(high, low, close, volume [, fast [, slow]])` (also `chaikin_osc`), defaults 3 and 10
- **Description:** Chaikin oscillator (TA-Lib `ADOSC`): EMA(A/D, fast) - EMA(A/D, slow). As in TA-Lib, both EMAs start from the first A/D value (not an SMA).
- **Returns:** DOUBLE. **NULLs:** running rule; first value on row max(fast, slow).
- **Example:** `SELECT time, adosc(high, low, close, volume) FROM candles WHERE symbol = 'COAST'`

#### mfi

- **Syntax:** `mfi(high, low, close, volume [, n])`, default 14
- **Description:** money flow index (TA-Lib `MFI`): a volume-weighted RSI of the typical price. 100 × positive flow / (positive + negative flow) over n rows. A row whose typical price did not change adds no flow; 0 when there is no flow at all (as TA-Lib 0.6).
- **Returns:** DOUBLE, 0 to 100. **NULLs:** running rule; first value on row n + 1.
- **Example:** `SELECT time, mfi(high, low, close, volume) FROM candles WHERE symbol = 'TELCO'`

#### efi

- **Syntax:** `efi(close, volume [, n])` (also `force_index`), default 13
- **Description:** Elder's force index: (close - previous close) × volume, smoothed with an EMA of n rows that starts with an SMA (TA-Lib style EMA).
- **Returns:** DOUBLE. **NULLs:** running rule; first value on row n + 1.
- **Example:** `SELECT time, efi(close, volume) FROM candles WHERE symbol = 'TELCO'`

#### eom

- **Syntax:** `eom(high, low, volume [, n [, divisor]])` (also `ease_of_movement`), defaults 14 and 100000000
- **Description:** ease of movement (as pandas-ta `eom`): distance = middle price - previous middle price; box ratio = (volume / divisor) / (high - low); EOM = SMA(distance / box ratio, n).
- **Returns:** DOUBLE. **NULLs:** window rule; a row with high = low or volume 0 is NULL and makes its windows NULL.
- **Example:** `SELECT time, eom(high, low, volume) FROM candles WHERE symbol = 'TELCO'`

### Heikin-Ashi

| Name | Syntax | Meaning |
|---|---|---|
| `ha_open` | `ha_open(open, high, low, close)` | first row (open + close) / 2, then (previous ha_open + previous ha_close) / 2 |
| `ha_close` | `ha_close(open, high, low, close)` | (open + high + low + close) / 4 |
| `ha_high` | `ha_high(open, high, low, close)` | biggest of high, ha_open, ha_close |
| `ha_low` | `ha_low(open, high, low, close)` | smallest of low, ha_open, ha_close |

#### ha_open

- **Syntax:** `ha_open(open, high, low, close)`
- **Description:** Heikin-Ashi open. All four `ha_` functions take the same four arguments, so a chart can ask for the whole candle at once.
- **Returns:** DOUBLE. **NULLs:** running rule.
- **Example:** `SELECT time, ha_open(open, high, low, close) AS o, ha_high(open, high, low, close) AS h, ha_low(open, high, low, close) AS l, ha_close(open, high, low, close) AS c FROM candles WHERE symbol = 'CITY'`

#### ha_close

- **Syntax:** `ha_close(open, high, low, close)`
- **Description:** Heikin-Ashi close: the average of the four prices of the row.
- **Returns:** DOUBLE. **NULLs:** running rule.
- **Example:** as `ha_open`.

#### ha_high

- **Syntax:** `ha_high(open, high, low, close)`
- **Description:** Heikin-Ashi high: max(high, ha_open, ha_close).
- **Returns:** DOUBLE. **NULLs:** running rule.
- **Example:** as `ha_open`.

#### ha_low

- **Syntax:** `ha_low(open, high, low, close)`
- **Description:** Heikin-Ashi low: min(low, ha_open, ha_close).
- **Returns:** DOUBLE. **NULLs:** running rule.
- **Example:** as `ha_open`.

---

## Part 5: Scalar functions

A NULL argument gives NULL for every function in this part (except `random()` and `setseed()`, which take none or one).

### Math

| Name | Syntax | Meaning | Example | Result |
|---|---|---|---|---|
| `trunc` (`truncate`) | `trunc(x [, d])` | cut toward zero to d decimals | `trunc(-2.7)` | `-2` |
| `cbrt` | `cbrt(x)` | cube root | `cbrt(27)` | `3` |
| `log` | `log(x)`, `log(base, x)` | natural log; log with a base | `log(2, 8)` | `3` |
| `log2` | `log2(x)` | log base 2 | `log2(8)` | `3` |
| `gcd`, `lcm` | `gcd(a, b)` | greatest common divisor, least common multiple | `lcm(4, 6)` | `12` |
| `factorial` | `factorial(n)` | n! (LONG up to 20, DOUBLE above) | `factorial(5)` | `120` |
| `pi` | `pi()` | 3.14159... | | |
| `degrees`, `radians` | `degrees(x)` | radians to degrees and back | `degrees(pi())` | `180` |
| `sin` `cos` `tan` `cot` | `sin(x)` | trigonometry (radians) | `cos(0)` | `1` |
| `asin` `acos` `atan` `atan2` | `atan2(y, x)` | inverse trigonometry | `atan2(1, 1)` | `0.785...` |
| `sinh` `cosh` `tanh` `asinh` `acosh` `atanh` | `tanh(x)` | hyperbolic functions | `tanh(0)` | `0` |
| `width_bucket` | `width_bucket(x, low, high, count)` | bucket number for a histogram | `width_bucket(5.35, 0.024, 10.06, 5)` | `3` |
| `clamp` | `clamp(x, low, high)` | x kept between low and high | `clamp(15, 0, 10)` | `10` |
| `safe_divide` | `safe_divide(a, b)` | a / b, NULL when b is 0 | `safe_divide(1, 0)` | NULL |
| `div0` | `div0(a, b)` | a / b, 0 when b is 0 | `div0(1, 0)` | `0` |
| `percent` | `percent(a, b)` | a / b × 100, NULL when b is 0 | `percent(1, 4)` | `25` |
| `is_nan`, `is_inf`, `is_finite` | `is_finite(x)` | tests for special DOUBLE values | `is_finite(2)` | `true` |
| `random` (`rand`) | `random()` | random DOUBLE, 0 or more and less than 1 | | |
| `setseed` | `setseed(s)` | fixes the random numbers, s from -1 to 1 | | NULL |
| `normal_cdf` | `normal_cdf(x [, mean, sd])` | normal distribution: P(X ≤ x) | `normal_cdf(1.96)` | `0.975...` |
| `normal_pdf` | `normal_pdf(x [, mean, sd])` | normal density | | |
| `normal_inv` | `normal_inv(p [, mean, sd])` | x where P(X ≤ x) = p | `normal_inv(0.975)` | `1.9599...` |

#### trunc

- **Syntax:** `trunc(x [, decimals])` (also `truncate`)
- **Description:** removes digits toward zero: `trunc(2.79, 1)` is 2.7, `trunc(-2.7)` is -2. Whole numbers stay whole numbers.
- **Returns:** LONG for a whole number with decimals ≥ 0, else DOUBLE. **NULLs:** NULL argument gives NULL.
- **Example:** `SELECT trunc(close, 0) FROM candles`

#### cbrt

- **Syntax:** `cbrt(x)`
- **Description:** cube root; also works for negative numbers.
- **Returns:** DOUBLE. **Example:** `SELECT cbrt(-8)` gives -2.

#### log

- **Syntax:** `log(x)` or `log(base, x)`
- **Description:** with one argument the natural log (the same as `ln`, as in QuestDB; PostgreSQL's `log(x)` is base 10, use `log10`). With two arguments the log of x in the given base.
- **Returns:** DOUBLE. **NULLs:** NULL for x ≤ 0, or a base ≤ 0 or equal to 1.
- **Example:** `SELECT log(2, 1024)` gives 10.

#### log2

- **Syntax:** `log2(x)`
- **Description:** log base 2.
- **Returns:** DOUBLE. **NULLs:** NULL for x ≤ 0.
- **Example:** `SELECT log2(8)` gives 3.

#### gcd

- **Syntax:** `gcd(a, b)`, `lcm(a, b)`
- **Description:** greatest common divisor and least common multiple of two whole numbers. `gcd(0, 5)` is 5; `lcm` with a 0 is 0.
- **Returns:** LONG. **NULLs:** NULL argument gives NULL. Error for a number that is not whole, or when the result does not fit in a LONG.
- **Example:** lot sizes: `SELECT lcm(10, 25)` gives 50.

#### factorial

- **Syntax:** `factorial(n)`
- **Description:** 1 × 2 × ... × n. `factorial(0)` is 1.
- **Returns:** LONG for n up to 20, DOUBLE above (NULL above 170). Error for a negative n.
- **Example:** `SELECT factorial(10)` gives 3628800.

#### pi

- **Syntax:** `pi()`
- **Returns:** DOUBLE 3.141592653589793.
- **Example:** `SELECT degrees(pi() / 2)` gives 90.

#### degrees

- **Syntax:** `degrees(radians)`, `radians(degrees)`
- **Description:** converts between radians and degrees.
- **Returns:** DOUBLE. **Example:** `SELECT radians(180)` gives 3.14159....

#### sin

- **Syntax:** `sin(x)`, `cos(x)`, `tan(x)`, `cot(x)`, `asin(x)`, `acos(x)`, `atan(x)`, `atan2(y, x)`, `sinh(x)`, `cosh(x)`, `tanh(x)`, `asinh(x)`, `acosh(x)`, `atanh(x)`
- **Description:** trigonometric and hyperbolic functions; angles in radians. `atan2(y, x)` is the angle of the point (x, y).
- **Returns:** DOUBLE. **NULLs:** NULL outside the domain (`asin(2)`, `acosh(0.5)`, `atanh(1)`).
- **Example:** the sample candles view uses `sin` to make prices.

#### width_bucket

- **Syntax:** `width_bucket(x, low, high, count)`
- **Description:** splits [low, high) into `count` equal buckets and gives the bucket of x, 1 to count. Below low gives 0, at or above high gives count + 1 (as PostgreSQL). low may be bigger than high (buckets then go down).
- **Returns:** LONG. **NULLs:** NULL argument gives NULL. Error when low = high or count < 1.
- **Example:** see [Histograms](#histograms).

#### clamp

- **Syntax:** `clamp(x, low, high)`
- **Description:** low when x < low, high when x > high, else x. Works for numbers, text and times.
- **Returns:** the type of the chosen value. **NULLs:** NULL argument gives NULL. Error when low > high.
- **Example:** `SELECT clamp(pct_change, -10, 10) FROM live_data` (for a market with a daily limit of ±10 %)

#### safe_divide

- **Syntax:** `safe_divide(a, b)`
- **Description:** a / b, but NULL when b is 0. (KDB's `/` already gives NULL for a division by zero; this name is for programs written for BigQuery.)
- **Returns:** DOUBLE. **Example:** `SELECT safe_divide(sum_if(volume, close > open), sum(volume)) FROM candles`

#### div0

- **Syntax:** `div0(a, b)`
- **Description:** a / b, but 0 when b is 0 (Snowflake's `DIV0`).
- **Returns:** DOUBLE. **Example:** `SELECT div0(1, 0)` gives 0.

#### percent

- **Syntax:** `percent(a, b)`
- **Description:** a / b × 100.
- **Returns:** DOUBLE. **NULLs:** NULL when b is 0.
- **Example:** `SELECT symbol, percent(sum(volume), (SELECT sum(volume) FROM candles)) FROM candles GROUP BY symbol`

#### is_nan

- **Syntax:** `is_nan(x)`, `is_inf(x)`, `is_finite(x)`
- **Description:** tests for "not a number", infinity, and a normal finite number. KDB stores a NaN in a DOUBLE column as NULL, so these are mostly for values made in a query.
- **Returns:** BOOL. **NULLs:** NULL argument gives NULL.
- **Example:** `SELECT is_finite(1.5)`

#### random

- **Syntax:** `random()` (also `rand()`)
- **Description:** a random DOUBLE, 0 or more and less than 1. A new value for every call and every row. A query that uses it is never taken from the query result cache.
- **Returns:** DOUBLE. **Example:** a random sample of rows: `SELECT * FROM candles WHERE random() < 0.01`

#### setseed

- **Syntax:** `setseed(s)`
- **Description:** sets the start of `random()` so the numbers repeat, s from -1 to 1. It changes the random numbers for the whole server. With several query threads the order of rows can still change the numbers.
- **Returns:** NULL. **Example:** `SELECT setseed(0.42)`

#### normal_cdf

- **Syntax:** `normal_cdf(x [, mean [, sd]])`, `normal_pdf(x [, mean [, sd]])`; defaults 0 and 1
- **Description:** the normal distribution: the probability of a value ≤ x, and the density at x.
- **Returns:** DOUBLE. **NULLs:** error when sd ≤ 0.
- **Example:** `SELECT normal_cdf(-1.645)` gives about 0.05.

#### normal_inv

- **Syntax:** `normal_inv(p [, mean [, sd]])`
- **Description:** the inverse: x where the probability of a value ≤ x is p. Useful for a normal (parametric) value at risk: `-(avg(r) + normal_inv(0.05) * stddev(r))`.
- **Returns:** DOUBLE. **NULLs:** error when p is not between 0 and 1.
- **Example:** `SELECT normal_inv(0.975)` gives 1.959963984540054.

### Prices

| Name | Syntax | Meaning | Example | Result |
|---|---|---|---|---|
| `round_tick` | `round_tick(price [, tick = 0.1])` | nearest price on the tick grid | `round_tick(512.35)` | `512.4` |
| `floor_tick` | `floor_tick(price [, tick = 0.1])` | tick price at or below | `floor_tick(512.37)` | `512.3` |
| `ceil_tick` | `ceil_tick(price [, tick = 0.1])` | tick price at or above | `ceil_tick(512.31)` | `512.4` |
| `pivot_point` | `pivot_point(high, low, close [, method])` | pivot point P | `pivot_point(110, 90, 100)` | `100` |
| `pivot_level` | `pivot_level(high, low, close, level [, method])` | support and resistance levels | `pivot_level(110, 90, 100, 'r1')` | `110` |

#### round_tick

- **Syntax:** `round_tick(price [, tick])`, `floor_tick(price [, tick])`, `ceil_tick(price [, tick])`; tick default 0.1
- **Description:** puts a price on the tick grid (for example, prices that move in steps of 0.1, that is 10 cents). The result is rounded to the tick's decimals, so `round_tick(512.35)` is 512.4, not 512.4000000001. Half a tick goes up (away from zero).
- **Returns:** DOUBLE. **NULLs:** NULL argument gives NULL. Error when tick ≤ 0.
- **Example:** a 2 % target price on the grid: `SELECT symbol, ceil_tick(close * 1.02) FROM candles WHERE time = '2026-09-10'`

#### pivot_point

- **Syntax:** `pivot_point(high, low, close [, method])`
- **Description:** the pivot point P of a period. `'classic'` (default), `'fibonacci'` and `'camarilla'`: P = (H + L + C) / 3. `'woodie'`: P = (H + L + 2C) / 4. Use the **previous** period's high, low and close for today's levels (see the example of `pivot_level`).
- **Returns:** DOUBLE.
- **Example:** `SELECT pivot_point(high, low, close) FROM candles`

#### pivot_level

- **Syntax:** `pivot_level(high, low, close, level [, method])`
- **Description:** one pivot level. `level` is `'p'`, `'r1'`, `'r2'`, `'r3'`, `'s1'`, `'s2'`, `'s3'` (and `'r4'`, `'s4'` for Camarilla). With R = high - low:

| Method | R1 / S1 | R2 / S2 | R3 / S3 | R4 / S4 |
|---|---|---|---|---|
| classic (also `'standard'`) | 2P - L / 2P - H | P ± R | H + 2(P - L) / L - 2(H - P) | - |
| woodie | as classic, with Woodie's P | P ± R | as classic | - |
| fibonacci | P ± 0.382·R | P ± 0.618·R | P ± R | - |
| camarilla | C ± R·1.1/12 | C ± R·1.1/6 | C ± R·1.1/4 | C ± R·1.1/2 |

- **Returns:** DOUBLE. **NULLs:** NULL argument gives NULL. Error for an unknown level or method.
- **Example:** today's levels from yesterday's candle:

```sql
SELECT time, symbol, pivot_level(ph, pl, pc, 's1') AS s1, pivot_point(ph, pl, pc) AS p, pivot_level(ph, pl, pc, 'r1') AS r1
FROM (SELECT time, symbol,
             lag(high) OVER (PARTITION BY symbol ORDER BY time) AS ph,
             lag(low) OVER (PARTITION BY symbol ORDER BY time) AS pl,
             lag(close) OVER (PARTITION BY symbol ORDER BY time) AS pc
      FROM candles) x
WHERE time = '2026-09-10';
```

### Finance

| Name | Syntax | Meaning (Excel's function of the same name) |
|---|---|---|
| `cagr` | `cagr(start_value, end_value, years)` | compound yearly growth rate |
| `compound_interest` | `compound_interest(principal, rate, years [, times_per_year = 1])` | interest earned |
| `fv` | `fv(rate, nper, pmt [, pv = 0, type = 0])` | future value |
| `pv` | `pv(rate, nper, pmt [, fv = 0, type = 0])` | present value |
| `pmt` | `pmt(rate, nper, pv [, fv = 0, type = 0])` | payment per period |
| `nper` | `nper(rate, pmt, pv [, fv = 0, type = 0])` | number of periods |
| `npv` | `npv(rate, value1, value2, ...)` | net present value, first value one period away |
| `irr` | `irr(value0, value1, ...)` | internal rate of return per period |

Excel's sign rule: money you pay is negative, money you get is positive. `type` 0 = payments at the end of each period, 1 = at the start. `rate` is per period (`0.12 / 12` for 12 % a year paid monthly).

#### cagr

- **Syntax:** `cagr(start_value, end_value, years)`
- **Description:** (end / start)^(1 / years) - 1.
- **Returns:** DOUBLE. **NULLs:** NULL when start ≤ 0, end < 0 or years ≤ 0.
- **Example:** `SELECT cagr(100, 200, 5)` gives 0.1487 (14.87 % a year).

#### compound_interest

- **Syntax:** `compound_interest(principal, rate, years [, times_per_year])`
- **Description:** the interest earned: principal × ((1 + rate / times)^(times × years) - 1). Add the principal for the final amount.
- **Returns:** DOUBLE. **Example:** `SELECT compound_interest(100000, 0.08, 3, 4)` (8 % a year, paid quarterly, 3 years).

#### fv

- **Syntax:** `fv(rate, nper, pmt [, pv [, type]])`
- **Description:** future value of a series of equal payments (Excel `FV`).
- **Returns:** DOUBLE. **Example:** `SELECT fv(0.06 / 12, 10, -200, -500, 1)` gives 2581.40 (Excel's example).

#### pv

- **Syntax:** `pv(rate, nper, pmt [, fv [, type]])`
- **Description:** present value (Excel `PV`).
- **Returns:** DOUBLE. **Example:** `SELECT pv(0.08 / 12, 240, 500)` gives -59777.15.

#### pmt

- **Syntax:** `pmt(rate, nper, pv [, fv [, type]])`
- **Description:** payment per period of a loan (Excel `PMT`).
- **Returns:** DOUBLE. **Example:** `SELECT pmt(0.08 / 12, 10, 10000)` gives -1037.03 (Excel's example).

#### nper

- **Syntax:** `nper(rate, pmt, pv [, fv [, type]])`
- **Description:** number of periods (Excel `NPER`).
- **Returns:** DOUBLE. **NULLs:** NULL when there is no answer.
- **Example:** `SELECT nper(0.12 / 12, -100, -1000, 10000, 1)` gives 59.67.

#### npv

- **Syntax:** `npv(rate, value1, value2, ...)`
- **Description:** Σ value_i / (1 + rate)^i, i from 1 (Excel `NPV`: the first value is one period away). Up to 63 values. For values in rows with dates, use the aggregate `xnpv`.
- **Returns:** DOUBLE. **NULLs:** a NULL value gives NULL.
- **Example:** `SELECT npv(0.1, -10000, 3000, 4200, 6800)` gives 1188.44.

#### irr

- **Syntax:** `irr(value0, value1, ...)`
- **Description:** the rate per period where the net present value (value0 at time 0) is 0 (Excel `IRR`). Newton's method, then bisection.
- **Returns:** DOUBLE. **NULLs:** NULL when all values have the same sign or no rate is found.
- **Example:** `SELECT irr(-70000, 12000, 15000, 18000, 21000, 26000)` gives 0.0866.

### Dates for reports

All in **UTC** (for a local clock add its offset, for example `20700000` ms for Nepal, +05:45; chapter 4).

| Name | Syntax | Meaning | Example | Result |
|---|---|---|---|---|
| `extract`, `date_part` | `extract(field FROM t)`, `date_part('field', t)` | a part of a time | `extract(dow FROM '2026-09-11')` | `5` |
| `date_trunc` | `date_trunc('quarter', t)` | new unit `quarter` (chapter 11 has the others) | `date_trunc('quarter', '2026-08-15')` | `2026-07-01T00:00:00.000Z` |
| `datediff` | `datediff('month', a, b)` | new units `month` and `year` (whole calendar months) | `datediff('month', '2026-01-31', '2026-02-28')` | `1` |
| `age` | `age(a [, b])` | the time from b to a as text | `age('2026-09-11', '2020-01-05')` | `6 years 8 mons 6 days` |
| `quarter` | `quarter(t)` | 1 to 4 | `quarter('2026-09-11')` | `3` |
| `day_of_year` | `day_of_year(t)` | 1 to 366 | `day_of_year('2026-02-01')` | `32` |
| `week_of_year` | `week_of_year(t)` | ISO week, 1 to 53 | `week_of_year('2027-01-01')` | `53` |
| `last_day` | `last_day(t)` | last day of the month (DATE) | `last_day('2024-02-10')` | `2024-02-29` |
| `make_date` | `make_date(year, month, day)` | a DATE | `make_date(2026, 9, 11)` | `2026-09-11` |
| `make_timestamp` | `make_timestamp(y, m, d, h, mi, s)` | a TIMESTAMP (s may have decimals) | | |
| `fiscal_year` | `fiscal_year(t [, start_month = 7, start_day = 17])` | the year the fiscal year starts in | `fiscal_year('2026-07-16')` | `2025` |
| `fiscal_quarter` | `fiscal_quarter(t [, 7, 17])` | quarter of the fiscal year | `fiscal_quarter('2026-10-17')` | `2` |
| `nepal_fiscal_year` | `nepal_fiscal_year(t)` | Nepal's fiscal year in Bikram Sambat years | `nepal_fiscal_year('2026-09-11')` | `2083/84` |

#### extract

- **Syntax:** `extract(field FROM t)` or `date_part('field', t)`
- **Description:** fields: `year`, `quarter`, `month`, `week` (ISO), `isoyear`, `day`, `dow` (0 = Sunday ... 6 = Saturday), `isodow` (1 = Monday ... 7 = Sunday), `doy` (day of the year), `hour`, `minute`, `second` (with the milliseconds as decimals), `millisecond` (seconds × 1000 + ms, as PostgreSQL), `epoch` (seconds since 1970), `decade`, `century`.
- **Returns:** LONG; DOUBLE for `second` and `epoch`. **NULLs:** NULL argument gives NULL. Error for an unknown field.
- **Example:** `SELECT extract(month FROM time) AS m, sum(volume) FROM candles ORDER BY m`

#### age

- **Syntax:** `age(a, b)` or `age(b)`
- **Description:** the time from b to a in years, months, days and clock time, as text in PostgreSQL's style: `6 years 8 mons 6 days`, `1 mon 1 day`, `06:30:00`. With one argument, from b to today (midnight UTC). When b is after a, every part is negative.
- **Returns:** STRING. **NULLs:** NULL argument gives NULL.
- **Example:** `SELECT symbol, age(max(time), min(time)) FROM candles GROUP BY symbol`

#### quarter

- **Syntax:** `quarter(t)`
- **Description:** the calendar quarter, 1 (January to March) to 4.
- **Returns:** LONG. **Example:** `SELECT quarter(time) AS q, sum(volume) FROM candles`

#### day_of_year

- **Syntax:** `day_of_year(t)`
- **Description:** 1 for January 1, up to 366.
- **Returns:** LONG. **Example:** `SELECT day_of_year('2026-12-31')` gives 365.

#### week_of_year

- **Syntax:** `week_of_year(t)`
- **Description:** the ISO week number (weeks start on Monday; week 1 has the year's first Thursday). Early January days can be in week 52 or 53 of the year before.
- **Returns:** LONG. **Example:** `SELECT week_of_year('2027-01-01')` gives 53.

#### last_day

- **Syntax:** `last_day(t)`
- **Description:** the last day of t's month.
- **Returns:** DATE. **Example:** month-end rows: `SELECT * FROM candles WHERE to_date(time) = last_day(time)`

#### make_date

- **Syntax:** `make_date(year, month, day)`
- **Description:** a DATE from its parts.
- **Returns:** DATE. **NULLs:** error when the day does not exist (`make_date(2026, 2, 29)`).
- **Example:** `SELECT make_date(2026, 7, 17)`

#### make_timestamp

- **Syntax:** `make_timestamp(year, month, day, hour, minute, second)`
- **Description:** a TIMESTAMP (UTC) from its parts; second may have decimals.
- **Returns:** TIMESTAMP. **NULLs:** error for a day or time that does not exist.
- **Example:** `SELECT make_timestamp(2026, 9, 11, 5, 15, 0)` is 11:00 in Nepal time (+05:45).

#### fiscal_year

- **Syntax:** `fiscal_year(t [, start_month [, start_day]])`
- **Description:** the (Gregorian) year in which t's fiscal year starts. Nepal's fiscal year starts on Shrawan 1 of the Bikram Sambat calendar, which is July 16 or 17. KDB does not know the BS calendar: it uses a fixed start day, July 17 by default. In a year where Shrawan 1 is July 16, that one day is counted in the old year; pass `7, 16` for such a year. For a calendar year use `fiscal_year(t, 1, 1)`.
- **Returns:** LONG. **NULLs:** error when the start day is not 1 to 28.
- **Example:** `SELECT fiscal_year(time) AS fy, symbol, sum(volume) FROM candles`

#### fiscal_quarter

- **Syntax:** `fiscal_quarter(t [, start_month [, start_day]])`
- **Description:** 1 to 4: the quarter of the fiscal year. Quarters are 3 months from the start day (with the default: July 17 to October 16 is quarter 1).
- **Returns:** LONG. **Example:** `SELECT fiscal_quarter('2026-10-17')` gives 2.

#### nepal_fiscal_year

- **Syntax:** `nepal_fiscal_year(t)`
- **Description:** the fiscal year as company reports in Nepal write it, in Bikram Sambat years: `2083/84` for July 17, 2026 to July 16, 2027. It is `fiscal_year(t) + 57` and the next year, with the same start-day rule.
- **Returns:** STRING. **Example:** `SELECT nepal_fiscal_year(time) AS fy, sum(volume) FROM candles`

---

## Part 6: Tables of numbers and pivots

### generate_series and long_sequence

`generate_series` is a **table function**: write it in `FROM` like a table.

```sql
SELECT ... FROM generate_series(start, stop [, step]) [[AS] alias [(column)]]
SELECT ... FROM long_sequence(count)
```

| Form | Rows | Column type |
|---|---|---|
| `generate_series(1, 10)` | 1, 2, ..., 10 | LONG |
| `generate_series(10, 1, -3)` | 10, 7, 4, 1 | LONG |
| `generate_series(0, 1, 0.25)` | 0, 0.25, 0.5, 0.75, 1 | DOUBLE |
| `generate_series('2026-01-01'::TIMESTAMP, '2026-01-31'::TIMESTAMP, '1 day')` | every day | TIMESTAMP |
| `generate_series('2026-01-31'::TIMESTAMP, '2026-12-31'::TIMESTAMP, '1 month')` | month ends (Jan 31, Feb 28, ...) | TIMESTAMP |
| `long_sequence(5)` | x = 1, ..., 5 (QuestDB) | LONG |

Rules:

- The arguments must be constants (or `now()`, `dateadd(...)`, ...). They cannot use columns of other tables.
- Steps for times: `'1 day'`, `'6 hours'`, `'15 minutes'`, `'1 week'`, `'1 month'`, `'3 months'`, `'1 year'`, or a number of milliseconds. Month steps keep the day where they can (day clamped at month end). Without a step: 1 day. Two DATE values with a whole-day step give DATE rows.
- The column name: the name in `AS alias(column)`, else the alias, else `generate_series` (`x` for `long_sequence`).
- The last value is included when the steps reach it exactly. A step of 0 is an error. At most 10 million rows. A NULL argument gives no rows.
- A result is a normal source: join it, filter it, group it, use indicators on it.

#### generate_series

- **Syntax:** `generate_series(start, stop [, step])`
- **Description:** rows from start to stop, step by step. See the table above.
- **Returns:** a table with one column (LONG, DOUBLE, TIMESTAMP or DATE).
- **NULLs:** a NULL argument gives no rows.
- **Example:** every trading day of September 2026 and whether CITY has a candle on it:

```sql
SELECT d, count(c.close) AS candles
FROM generate_series('2026-09-01'::TIMESTAMP, '2026-09-10'::TIMESTAMP, '1 day') AS g(d)
LEFT JOIN candles c ON c.time = g.d AND c.symbol = 'CITY'
WHERE is_trading_day(d)
GROUP BY d ORDER BY d;
```

#### long_sequence

- **Syntax:** `long_sequence(count)`
- **Description:** rows x = 1 to count (the QuestDB function).
- **Returns:** a table with one LONG column `x`.
- **Example:** `SELECT x, x * x FROM long_sequence(5)`

### PIVOT

```sql
SELECT ... FROM source PIVOT (aggregate(x) [AS name], ... FOR column IN (value [AS name], ...)) [[AS] alias]
```

PIVOT turns values of one column into columns. Every column of the source that PIVOT does not use (not in the aggregates, not the FOR column) becomes a group key: one row per key. `source` is a table, a view, a subquery or a table function.

| Part | Rule |
|---|---|
| aggregates | any aggregate: `sum`, `count(*)`, `avg`, `max`, `last`, `corr`, ... |
| FOR column | a column or expression of the source |
| IN values | constants. A value without `AS` gives a column named after the value |
| column names | one aggregate: the value's name; several: `value_name`, like `jan_total` |
| missing combinations | NULL (`count` gives 0) |

It is the same as a GROUP BY with `CASE`: `sum(CASE WHEN month = 1 THEN turnover END) AS jan, ...`. PIVOT writes that for you. Put the columns you do not need out of the source with a subquery, or they become group keys.

#### PIVOT

- **Syntax:** see above.
- **Description:** one row per combination of the other columns, one column per value (and aggregate).
- **NULLs:** a combination with no rows gives NULL (0 for `count`). Rows where the FOR column is NULL match no value.
- **Example:** see [Monthly turnover by sector](#monthly-turnover-by-sector).

---

## Part 7: Cookbook

All recipes use the `candles` view from the start of this chapter.

### Top gainers per day

The change from the day before is a window over each symbol. The rank inside each day is a second window over the result, so it needs one more subquery level (`PARTITION BY time`).

03-cook-top-gainers.sql:

```sql
-- The two best symbols of each day, by the change from the day before.
SELECT time, symbol, chg_pct, place
FROM (
  SELECT time, symbol, chg_pct, rank() OVER (PARTITION BY time ORDER BY chg_pct DESC) AS place
  FROM (
    SELECT time, symbol, round(pct_return(close) OVER (PARTITION BY symbol ORDER BY time) * 100, 2) AS chg_pct
    FROM candles
  ) d
  WHERE chg_pct IS NOT NULL
) r
WHERE place <= 2 AND time >= '2026-09-06'
ORDER BY time, place;
```

```text
time                     | symbol | chg_pct | place
-------------------------+--------+---------+------
2026-09-06T00:00:00.000Z | TELCO  |    5.44 |     1
2026-09-06T00:00:00.000Z | CITY   |    1.48 |     2
2026-09-07T00:00:00.000Z | TELCO  |    1.33 |     1
2026-09-07T00:00:00.000Z | VOLT   |    1.27 |     2
2026-09-08T00:00:00.000Z | VOLT   |    1.73 |     1
2026-09-08T00:00:00.000Z | TELCO  |    0.98 |     2
2026-09-09T00:00:00.000Z | VOLT   |    1.94 |     1
2026-09-09T00:00:00.000Z | TELCO  |    0.56 |     2
2026-09-10T00:00:00.000Z | VOLT   |    2.13 |     1
2026-09-10T00:00:00.000Z | TELCO  |    0.17 |     2
(10 rows, 5.8 ms)
```

### 20-day volatility

`volatility(close, 20, 240)` is the standard deviation of the last 20 daily log returns, scaled to a year of 240 trading days. The inner query computes it for every day; the outer one keeps the last day.

04-cook-volatility.sql:

```sql
-- Yearly volatility from the last 20 daily log returns (240 trading days a year).
SELECT symbol, round(close, 1) AS close, round(vol_20d * 100, 1) AS vol_pct
FROM (
  SELECT time, symbol, close, volatility(close, 20, 240) OVER (PARTITION BY symbol ORDER BY time) AS vol_20d
  FROM candles
) v
WHERE time = '2026-09-10'
ORDER BY vol_pct DESC;
```

```text
symbol | close  | vol_pct
-------+--------+--------
CITY   |  382.1 |    29.6
VOLT   |  177.1 |    27.9
COAST  |  299.1 |    26.8
TELCO  | 1073.4 |    21.8
ACME   |  312.2 |    21.2
(5 rows, 5.1 ms)
```

### Drawdown

`drawdown(close)` is the fall from the highest close so far. `max_drawdown` is the worst of it, and `arg_min(time, dd)` finds the day of the lowest point. Compute the drawdown on all days first, then filter the days to show.

05-cook-drawdown.sql:

```sql
-- The largest fall from a peak for every symbol, and the day of the lowest point.
SELECT symbol, round(max_drawdown(close) * 100, 1) AS max_dd_pct, arg_min(time, dd) AS worst_day
FROM (SELECT time, symbol, close, drawdown(close) OVER (PARTITION BY symbol ORDER BY time) AS dd FROM candles) x
GROUP BY symbol
ORDER BY max_dd_pct;

-- The drawdown of COAST on the last days.
SELECT time, close, round(drawdown(close) * 100, 2) AS dd_pct
FROM (SELECT time, close FROM candles WHERE symbol = 'COAST') n
WHERE time >= '2026-09-01';
```

```text
symbol | max_dd_pct | worst_day               
-------+------------+-------------------------
CITY   |      -31.5 | 2026-07-05T00:00:00.000Z
COAST  |      -28.7 | 2026-09-10T00:00:00.000Z
VOLT   |      -20.9 | 2026-04-08T00:00:00.000Z
TELCO  |      -18.6 | 2026-08-12T00:00:00.000Z
ACME   |      -16.8 | 2026-05-21T00:00:00.000Z
(5 rows, 5.2 ms)

time                     | close | dd_pct
-------------------------+-------+-------
2026-09-01T00:00:00.000Z | 330.7 |      0
2026-09-02T00:00:00.000Z | 329.8 |  -0.27
2026-09-03T00:00:00.000Z | 327.5 |  -0.97
2026-09-06T00:00:00.000Z | 314.3 |  -4.96
2026-09-07T00:00:00.000Z | 309.2 |   -6.5
2026-09-08T00:00:00.000Z | 304.6 |  -7.89
2026-09-09T00:00:00.000Z | 301.1 |  -8.95
2026-09-10T00:00:00.000Z | 299.1 |  -9.56
(8 rows, 4.4 ms)
```

### MACD crossover signals

The MACD histogram (line - signal) changes sign when the lines cross. `lag(hist)` in one more level gives yesterday's histogram. A cross from below is a buy signal, a cross from above a sell signal.

06-cook-macd-crossover.sql:

```sql
-- Days when the MACD line crosses its signal line.
SELECT time, symbol, round(line, 3) AS macd, round(sig, 3) AS signal,
       CASE WHEN hist > 0 THEN 'BUY' ELSE 'SELL' END AS action
FROM (
  SELECT time, symbol, line, sig, hist, lag(hist) OVER (PARTITION BY symbol ORDER BY time) AS prev_hist
  FROM (
    SELECT time, symbol,
           macd(close) OVER (PARTITION BY symbol ORDER BY time) AS line,
           macd_signal(close) OVER (PARTITION BY symbol ORDER BY time) AS sig,
           macd_hist(close) OVER (PARTITION BY symbol ORDER BY time) AS hist
    FROM candles
  ) m
) x
WHERE (hist > 0 AND prev_hist <= 0) OR (hist < 0 AND prev_hist >= 0)
ORDER BY time DESC, symbol
LIMIT 8;
```

```text
time                     | symbol | macd    | signal  | action
-------------------------+--------+---------+---------+-------
2026-09-07T00:00:00.000Z | VOLT   |  -3.953 |  -4.085 | BUY   
2026-09-02T00:00:00.000Z | VOLT   |  -4.098 |  -4.059 | SELL  
2026-08-27T00:00:00.000Z | VOLT   |  -4.054 |  -4.171 | BUY   
2026-08-24T00:00:00.000Z | CITY   |   8.463 |   9.102 | SELL  
2026-08-19T00:00:00.000Z | TELCO  | -19.481 | -20.742 | BUY   
2026-08-11T00:00:00.000Z | ACME   |  -4.911 |  -5.082 | BUY   
2026-08-05T00:00:00.000Z | COAST  |    6.99 |   7.709 | SELL  
2026-07-28T00:00:00.000Z | VOLT   |   4.393 |   4.919 | SELL  
(8 rows, 5.9 ms)
```

### Bollinger squeeze filter

A squeeze is a quiet market: the Bollinger band width is close to its lowest value of the last 120 days. Often a big move follows. `min(width) OVER (... ROWS 119 PRECEDING)` is the lowest width of 120 rows.

07-cook-bollinger-squeeze.sql:

```sql
-- A squeeze: the Bollinger band width is near its lowest of the last 120 days.
SELECT time, symbol, round(width * 100, 2) AS width_pct, round(lowest * 100, 2) AS lowest_120d_pct
FROM (
  SELECT time, symbol, width, min(width) OVER (PARTITION BY symbol ORDER BY time ROWS 119 PRECEDING) AS lowest
  FROM (SELECT time, symbol, bb_width(close, 20, 2) OVER (PARTITION BY symbol ORDER BY time) AS width FROM candles) b
) s
WHERE width <= lowest * 1.05 AND time >= '2026-08-20'
ORDER BY time, symbol;
```

```text
time                     | symbol | width_pct | lowest_120d_pct
-------------------------+--------+-----------+----------------
2026-08-24T00:00:00.000Z | CITY   |     10.77 |           10.77
2026-08-25T00:00:00.000Z | CITY   |     10.77 |           10.77
(2 rows, 5.6 ms)
```

### Correlation matrix of sectors

First the daily return of every sector (the average return of its symbols), then `corr` for every pair of sectors with a self-join, then `PIVOT` to turn the pairs into a matrix. 1 on the diagonal; values near 0 mean the sectors move independently.

08-cook-correlation-matrix.sql:

```sql
-- Daily return of each sector (the average of its symbols), then the correlation of every pair of sectors.
SELECT *
FROM (
  SELECT a.sector AS sector, b.sector AS other, round(corr(a.r, b.r), 2) AS c
  FROM (SELECT time, sector, avg(r) AS r
        FROM (SELECT time, sector, pct_return(close) OVER (PARTITION BY symbol ORDER BY time) AS r FROM candles) x
        GROUP BY time, sector) a
  JOIN (SELECT time, sector, avg(r) AS r
        FROM (SELECT time, sector, pct_return(close) OVER (PARTITION BY symbol ORDER BY time) AS r FROM candles) x
        GROUP BY time, sector) b ON a.time = b.time
  GROUP BY a.sector, b.sector
) pairs
PIVOT (max(c) FOR other IN ('Banking' AS banking, 'Energy' AS energy, 'Investment' AS investment, 'Telecom' AS telecom))
ORDER BY sector;
```

```text
sector     | banking | energy | investment | telecom
-----------+---------+--------+------------+--------
Banking    |       1 |  -0.63 |       0.15 |   -0.06
Energy     |   -0.63 |      1 |      -0.59 |   -0.18
Investment |    0.15 |  -0.59 |          1 |   -0.19
Telecom    |   -0.06 |  -0.18 |      -0.19 |       1
(4 rows, 12.4 ms)
```

### Monthly turnover by sector

Sectors as rows, months as columns. The subquery keeps only the three columns PIVOT needs; every other column would become a group key. The outer query rounds to millions.

09-cook-pivot-turnover.sql:

```sql
-- Turnover (close x volume) in millions: sectors as rows, months as columns.
SELECT sector, round(jun / 1000000, 1) AS jun, round(jul / 1000000, 1) AS jul, round(aug / 1000000, 1) AS aug, round(sep / 1000000, 1) AS sep
FROM (SELECT sector, month(time) AS m, close * volume AS turnover FROM candles WHERE time >= '2026-06-01') t
PIVOT (sum(turnover) FOR m IN (6 AS jun, 7 AS jul, 8 AS aug, 9 AS sep))
ORDER BY sector;
```

```text
sector     | jun    | jul    | aug    | sep  
-----------+--------+--------+--------+------
Banking    | 1213.6 | 1131.2 | 1198.2 | 392.5
Energy     |  260.5 |  288.6 |  264.9 |  92.1
Investment |  431.3 |  434.7 |    445 |   168
Telecom    | 1412.1 | 1563.6 | 1382.9 | 611.1
(4 rows, 5.3 ms)
```

### Histograms

`width_bucket(x, -4, 4, 8)` puts each daily return into a 1 % bucket from -4 % to +4 %. Bucket 0 means below -4 %, bucket 9 means +4 % or more. Items that are not aggregates are the group keys.

10-cook-histogram.sql:

```sql
-- How often did CITY move by how much? Buckets of 1 % from -4 % to +4 %.
SELECT bucket, -5 + bucket AS from_pct, count(*) AS days
FROM (SELECT width_bucket(pct_return(close) * 100, -4, 4, 8) AS bucket FROM candles WHERE symbol = 'CITY') h
WHERE bucket IS NOT NULL
ORDER BY bucket;
```

```text
bucket | from_pct | days
-------+----------+-----
     0 |       -5 |    5
     1 |       -4 |    5
     2 |       -3 |   16
     3 |       -2 |   24
     4 |       -1 |   46
     5 |        0 |   42
     6 |        1 |   25
     7 |        2 |    8
     8 |        3 |    4
     9 |        4 |    5
(10 rows, 5.1 ms)
```

### Beta against a benchmark

The sample data has no market index, so the "market" here is the average daily return of the five symbols. Join each symbol's returns to the market returns by day, then use `beta`, `alpha`, `information_ratio` and `corr` with `GROUP BY`. With a real index table, join to its returns instead.

11-cook-beta.sql:

```sql
-- Beta, alpha and information ratio of each symbol against a "market" made of all five symbols.
SELECT s.symbol, round(beta(s.r, m.r), 2) AS beta, round(alpha(s.r, m.r) * 240 * 100, 2) AS alpha_pct_year,
       round(information_ratio(s.r, m.r, 240), 2) AS info_ratio, round(corr(s.r, m.r), 2) AS corr
FROM (SELECT time, symbol, pct_return(close) OVER (PARTITION BY symbol ORDER BY time) AS r FROM candles) s
JOIN (SELECT time, avg(r) AS r
      FROM (SELECT time, pct_return(close) OVER (PARTITION BY symbol ORDER BY time) AS r FROM candles) x
      GROUP BY time) m ON s.time = m.time
GROUP BY s.symbol
ORDER BY beta DESC;
```

```text
symbol | beta  | alpha_pct_year | info_ratio | corr 
-------+-------+----------------+------------+------
CITY   |  2.12 |         -25.23 |      -1.06 |  0.45
COAST  |   1.9 |         -35.58 |      -1.51 |  0.43
TELCO  |  1.87 |          32.33 |       1.27 |  0.45
ACME   |   1.2 |          39.01 |       1.65 |  0.31
VOLT   | -2.08 |         -10.52 |      -0.04 | -0.49
(5 rows, 12.0 ms)
```

### Risk report

All risk aggregates work on daily returns: make them in a subquery, then group by symbol.

12-cook-risk.sql:

```sql
-- Risk report per symbol, from daily returns.
SELECT symbol, count(r) AS days,
       round(sharpe_ratio(r, 0, 240), 2) AS sharpe,
       round(sortino_ratio(r, 0, 240), 2) AS sortino,
       round(calmar_ratio(r, 240), 2) AS calmar,
       round(value_at_risk(r, 0.95) * 100, 2) AS var95_pct,
       round(expected_shortfall(r, 0.95) * 100, 2) AS es95_pct,
       round(skewness(r), 2) AS skew
FROM (SELECT time, symbol, pct_return(close) OVER (PARTITION BY symbol ORDER BY time) AS r FROM candles) x
GROUP BY symbol
ORDER BY sharpe DESC;
```

```text
symbol | days | sharpe | sortino | calmar | var95_pct | es95_pct | skew 
-------+------+--------+---------+--------+-----------+----------+------
ACME   |  180 |   1.45 |    2.31 |   2.28 |      1.91 |     3.34 |  0.31
TELCO  |  180 |   1.05 |    1.59 |   1.42 |      1.88 |      3.7 |  0.16
VOLT   |  180 |  -0.16 |   -0.23 |  -0.35 |      1.98 |      4.1 | -0.01
CITY   |  180 |  -1.08 |   -1.46 |  -0.96 |      3.25 |     4.44 |  0.05
COAST  |  180 |   -1.5 |   -1.98 |  -1.26 |      2.67 |     4.43 |  0.01
(5 rows, 6.3 ms)
```

### Many indicators at once

Indicators need the history before the days you show: compute them on all rows inside, filter the days outside (`trend` is `supertrend_direction`: 1 up, -1 down).

13-cook-indicators.sql:

```sql
-- Many indicators on the last days of one symbol.
SELECT time, close, rsi, round(stoch_k, 1) AS stoch_k, round(adx, 1) AS adx, round(sar, 1) AS sar, trend, round(bb_pb, 2) AS bb_pb
FROM (
  SELECT time, close,
         round(rsi(close, 14), 1) AS rsi,
         stoch_k(high, low, close) AS stoch_k,
         adx(high, low, close, 14) AS adx,
         sar(high, low) AS sar,
         supertrend_direction(high, low, close, 10, 3) AS trend,
         bb_percent_b(close, 20, 2) AS bb_pb
  FROM candles WHERE symbol = 'VOLT'
) i
WHERE time >= '2026-09-01';
```

```text
time                     | close | rsi  | stoch_k | adx  | sar   | trend | bb_pb
-------------------------+-------+------+---------+------+-------+-------+------
2026-09-01T00:00:00.000Z | 166.3 | 35.3 |    40.9 | 25.2 | 174.6 |    -1 |  0.31
2026-09-02T00:00:00.000Z | 164.8 | 33.5 |    37.3 | 25.7 | 174.4 |    -1 |  0.29
2026-09-03T00:00:00.000Z | 163.7 | 32.2 |    31.1 | 26.2 |   174 |    -1 |  0.26
2026-09-06T00:00:00.000Z | 165.1 | 35.7 |    28.6 | 26.4 | 173.3 |    -1 |  0.33
2026-09-07T00:00:00.000Z | 167.2 | 40.6 |    33.4 | 25.8 | 172.6 |    -1 |  0.44
2026-09-08T00:00:00.000Z | 170.1 | 46.6 |      47 | 24.2 |   172 |    -1 |  0.63
2026-09-09T00:00:00.000Z | 173.4 | 52.5 |    63.6 | 23.2 | 162.6 |    -1 |  0.87
2026-09-10T00:00:00.000Z | 177.1 | 58.1 |    79.3 | 22.7 | 162.9 |     1 |  1.06
(8 rows, 5.0 ms)
```

### Pivot levels on the tick grid

Today's pivot levels come from yesterday's high, low and close (`lag`). `round_tick` puts them on a 0.1 price grid (10 cents).

14-cook-pivots-ticks.sql:

```sql
-- Today's pivot levels from yesterday's candle, on the price tick grid.
SELECT symbol,
       round_tick(pivot_level(ph, pl, pc, 's1')) AS s1,
       round_tick(pivot_point(ph, pl, pc)) AS p,
       round_tick(pivot_level(ph, pl, pc, 'r1')) AS r1,
       round_tick(pivot_level(ph, pl, pc, 'r1', 'camarilla')) AS cam_r1
FROM (SELECT time, symbol,
             lag(high) OVER (PARTITION BY symbol ORDER BY time) AS ph,
             lag(low) OVER (PARTITION BY symbol ORDER BY time) AS pl,
             lag(close) OVER (PARTITION BY symbol ORDER BY time) AS pc
      FROM candles) x
WHERE time = '2026-09-10'
ORDER BY symbol;
```

```text
symbol | s1     | p      | r1     | cam_r1
-------+--------+--------+--------+-------
ACME   |  312.3 |  314.5 |  316.9 |  315.2
CITY   |  385.5 |  387.9 |  390.9 |    389
COAST  |  298.9 |  301.4 |  303.6 |  301.5
TELCO  | 1063.8 | 1072.2 | 1079.9 | 1073.1
VOLT   |  172.1 |  173.9 |  175.2 |  173.7
(5 rows, 5.4 ms)
```

### Nepal fiscal year

`nepal_fiscal_year` and `fiscal_quarter` group rows by a fiscal year that starts in mid-July, as in Nepal (see the note in [fiscal_year](#fiscal-year)).

15-cook-fiscal-year.sql:

```sql
-- Volume per Nepal fiscal year and fiscal quarter.
SELECT nepal_fiscal_year(time) AS fy, fiscal_quarter(time) AS q, count(*) AS rows_, sum(volume) AS volume
FROM candles
ORDER BY fy, q;

SELECT extract(year FROM '2026-09-11') AS y, extract(quarter FROM '2026-09-11') AS q, week_of_year('2026-09-11') AS week,
       age('2026-09-11', '2020-01-05') AS age, datediff('month', '2026-01-31', '2026-02-28') AS months;
```

```text
fy      | q | rows_ | volume  
--------+---+-------+---------
2082/83 | 2 |    55 |  3827816
2082/83 | 3 |   325 | 22483660
2082/83 | 4 |   325 | 22400713
2083/84 | 1 |   200 | 13842460
(4 rows, 8.3 ms)

y    | q | week | age                   | months
-----+---+------+-----------------------+-------
2026 | 3 |   37 | 6 years 8 mons 6 days |      1
(1 row, 0.1 ms)
```

### Calendars with generate_series

`generate_series` makes rows of numbers or days. A LEFT JOIN to it shows the days without data.

16-cook-generate-series.sql:

```sql
SELECT count(*) AS n, sum(generate_series) AS total FROM generate_series(1, 100);

SELECT m, day(m) AS day FROM generate_series('2026-01-31'::TIMESTAMP, '2026-05-31'::TIMESTAMP, '1 month') AS s(m);

-- Days without a candle (Fridays and Saturdays) in the first week of September.
SELECT d, day_of_week(d) AS dow, count(c.close) AS candles
FROM generate_series('2026-09-01'::TIMESTAMP, '2026-09-07'::TIMESTAMP, '1 day') AS g(d)
LEFT JOIN candles c ON c.time = g.d AND c.symbol = 'CITY'
GROUP BY d
ORDER BY d;
```

```text
n   | total
----+------
100 |  5050
(1 row, 0.2 ms)

m                        | day
-------------------------+----
2026-01-31T00:00:00.000Z |  31
2026-02-28T00:00:00.000Z |  28
2026-03-31T00:00:00.000Z |  31
2026-04-30T00:00:00.000Z |  30
2026-05-31T00:00:00.000Z |  31
(5 rows, 0.1 ms)

d                        | dow | candles
-------------------------+-----+--------
2026-09-01T00:00:00.000Z |   2 |       1
2026-09-02T00:00:00.000Z |   3 |       1
2026-09-03T00:00:00.000Z |   4 |       1
2026-09-04T00:00:00.000Z |   5 |       0
2026-09-05T00:00:00.000Z |   6 |       0
2026-09-06T00:00:00.000Z |   0 |       1
2026-09-07T00:00:00.000Z |   1 |       1
(7 rows, 4.9 ms)
```

### Loans and savings

A 5-year loan of $500,000 at 10 % a year paid monthly (EMI), a monthly saving of $5000 for 10 years at 8 %, the yearly growth of a share from $400 to $510 in 3 years, and the IRR of a bond-like investment.

17-cook-finance.sql:

```sql
SELECT round(pmt(0.10 / 12, 60, 500000), 2) AS emi_5y_loan,
       round(fv(0.08 / 12, 120, -5000), 2) AS sip_10y,
       round(cagr(400, 510, 3) * 100, 2) AS cagr_pct,
       round(irr(-100000, 8000, 8000, 8000, 120000) * 100, 2) AS irr_pct;
```

```text
emi_5y_loan | sip_10y   | cagr_pct | irr_pct
------------+-----------+----------+--------
  -10623.52 | 914730.18 |     8.44 |   10.56
(1 row, 0.3 ms)
```

---

### Speed

- The new aggregates, window frames with `BETWEEN`, and all functions of this chapter run in the **row engine**. A `GROUP BY` query with only `count`, `sum`, `avg`, `min`, `max`, `first` and `last` on plain columns uses the faster column engine; add `corr(...)` and the whole query uses the row engine. On the sample data this does not matter; on tens of millions of rows it can be several times slower.
- Indicators over windows (WMA, Bollinger, Donchian, CCI, linear regression, `zscore(x, n)`, ...) do about n steps per row: `bb_upper(close, 200)` over a million rows is about 200 million steps.
- Aggregates that keep all values (`percentile_cont`, `percentile_disc`, `mode`, `mad`, `iqr`, `value_at_risk`, `expected_shortfall`, `string_agg`, `array_agg`) sort the values again for every row when used with a running `OVER (... ORDER BY ...)` frame. Use `ROWS n PRECEDING` for moving versions over long partitions.

### Try it yourself

1. Which symbol had the biggest drawdown in the sample candles? Use `max_drawdown`.
2. Write the 10-day correlation between CITY's and COAST's daily returns for every day.
3. How many trading days does each month of 2026 have? Use `generate_series` and `is_trading_day`.

<details>
<summary>Answers</summary>

1. `SELECT symbol, max_drawdown(close) AS dd FROM candles GROUP BY symbol ORDER BY dd LIMIT 1`
2. `SELECT time, corr(a, b) OVER (ORDER BY time ROWS 9 PRECEDING) FROM (SELECT n.time AS time, n.r AS a, i.r AS b FROM (SELECT time, pct_return(close) AS r FROM candles WHERE symbol = 'CITY') n JOIN (SELECT time, pct_return(close) AS r FROM candles WHERE symbol = 'COAST') i ON n.time = i.time) x`
3. `SELECT month(d) AS m, count_if(is_trading_day(d)) AS days FROM generate_series('2026-01-01'::TIMESTAMP, '2026-12-31'::TIMESTAMP, '1 day') AS g(d) ORDER BY m`

</details>

---

Next: [20. Charts and dashboards](20-charts-and-dashboards.md)
