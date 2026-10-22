# Returns and risk

> Returns, drawdown, volatility, z-score and the risk numbers of an investment: Sharpe, Sortino, Calmar, information ratio, value at risk and expected shortfall.

- Category: Functions — statistics
- Keywords: return, returns, daily return, monthly return, simple return, simple return, log return, logarithmic return, continuous return, cumulative return, total return, growth, drawdown, peak, MDD, maximum drawdown, volatility, annualized volatility, historical volatility, risk, risk-free rate, z-score, standard score, standardize, normalize, min-max scaling, sharpe, Sharpe ratio, sortino, Sortino ratio, downside deviation, calmar, Calmar ratio, information ratio, tracking error, benchmark, VaR, value at risk, CVaR, conditional value at risk, expected shortfall, portfolio, mutual fund, NAV, periods per year, annualize, 240 trading days
- See also: [Window and series functions (pct-change)](functions-window.md#pct-change), [Statistics functions](functions-statistics.md), [Correlation and regression](functions-correlation.md), [Finance and price functions (cagr)](functions-finance.md#cagr), [Technical indicators](functions-indicators.md), [Window and series functions (cummax)](functions-window.md#cummax)

A **return** is how much an investment grew: a price that goes from 500 to 510 has a return of `0.02` (2%). **Risk** is how much the returns jump up and down, and how deep the losses can be. The functions on this page measure both.

There are two kinds:

- **Series functions** give a value for **every row**: `pct_return`, `log_return`, `cum_return`, `drawdown`, `volatility`, `zscore`, `minmax_scale`. They follow the rules of the [technical indicators](functions-indicators.md):
  - Without `OVER`, all result rows are one series in time order. With **many symbols**, always write `OVER (PARTITION BY symbol ORDER BY time)`.
  - `WHERE` runs first: the function only sees the rows that `WHERE` keeps.
  - They cannot be in the same `SELECT` as `GROUP BY`, `SAMPLE BY` or an aggregate.
- **Aggregates** give **one value per group**: `max_drawdown`, `sharpe_ratio`, `sortino_ratio`, `calmar_ratio`, `information_ratio`, `value_at_risk`, `expected_shortfall`. Like `avg`, they work with `GROUP BY`, skip NULL values, and give `NULL` for no rows. Most of them read **returns**, not prices. So the usual query has two steps: the returns in a subquery, the aggregate outside.

More rules:

- **Returns are fractions:** `0.025` means +2.5%. Multiply by 100 for percent. (The older [pct_change](functions-window.md#pct-change) already gives percent: `2.5`.)
- **Periods per year:** some functions take `periods`, the number of returns in one year. They use it to give a **yearly** (annualized) number. Use `240` for daily returns of a market with about 240 trading days a year (`252` is usual for US markets), `52` for weekly and `12` for monthly returns. Without it the number is "per period" (per day, per month).
- **Warm-up:** at the start of a series there are not enough rows yet, and the result is `NULL`:

| Function | First value on row | NULL rows at the start |
|---|---|---|
| `pct_return(x)`, `log_return(x)` | 2 | 1 |
| `pct_return(x, k)`, `log_return(x, k)` | k + 1 | k |
| `cum_return(x)`, `drawdown(x)` | 1 | 0 |
| `volatility(price, n)` | n + 1 | n |
| `zscore(x, n)`, `minmax_scale(x, n)` | n | n - 1 |

- **Data of the examples:** the daily candles (`ochl_day`) have a gap between 2025-12-31 and 2026-08-23, so the daily examples use `time >= '2026-08-23'`. `fund_nav` holds the month-start NAV (the price of one unit) of two made-up mutual funds, GROWTH and INCOME, from 2024-09 to 2026-08.

**Example: VOLT: daily return, total return and drawdown** (sample data: sample, analysis-market)

```sql
SELECT time, close,
       round(pct_return(close), 4) AS daily_return,
       round(cum_return(close), 4) AS total_return,
       round(drawdown(close), 4) AS drawdown
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | daily_return (DOUBLE) | total_return (DOUBLE) | drawdown (DOUBLE) |
|---|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 181 | NULL | 0 | 0 |
| 2026-08-24T00:00:00.000Z | 178.5 | -0.0138 | -0.0138 | -0.0138 |
| 2026-08-25T00:00:00.000Z | 176.8 | -0.0095 | -0.0232 | -0.0232 |
| 2026-08-26T00:00:00.000Z | 174.2 | -0.0147 | -0.0376 | -0.0376 |
| 2026-08-27T00:00:00.000Z | 173.3 | -0.0052 | -0.0425 | -0.0425 |
| 2026-08-30T00:00:00.000Z | 173 | -0.0017 | -0.0442 | -0.0442 |
| 2026-08-31T00:00:00.000Z | 172.6 | -0.0023 | -0.0464 | -0.0464 |
| 2026-09-01T00:00:00.000Z | 169 | -0.0209 | -0.0663 | -0.0663 |
| 2026-09-02T00:00:00.000Z | 171.5 | 0.0148 | -0.0525 | -0.0525 |
| 2026-09-03T00:00:00.000Z | 176 | 0.0262 | -0.0276 | -0.0276 |
| 2026-09-06T00:00:00.000Z | 180.1 | 0.0233 | -0.005 | -0.005 |
| 2026-09-07T00:00:00.000Z | 176.9 | -0.0178 | -0.0227 | -0.0227 |
| 2026-09-08T00:00:00.000Z | 182.4 | 0.0311 | 0.0077 | 0 |
| 2026-09-09T00:00:00.000Z | 187.3 | 0.0269 | 0.0348 | 0 |
| 2026-09-10T00:00:00.000Z | 191.2 | 0.0208 | 0.0564 | 0 |

(15 rows)

**Example: Risk report of two funds: monthly returns inside, the risk numbers outside** (sample data: sample, analysis-market)

```sql
SELECT fund,
       count(r) AS months,
       round(avg(r) * 100, 2) AS avg_month_pct,
       round(sharpe_ratio(r, 0, 12), 2) AS sharpe,
       round(sortino_ratio(r, 0, 12), 2) AS sortino,
       round(calmar_ratio(r, 12), 2) AS calmar,
       round(max_drawdown(nav) * 100, 2) AS max_drawdown_pct,
       round(value_at_risk(r, 0.95) * 100, 2) AS var95_pct
FROM (SELECT time, fund, nav,
             pct_return(nav) OVER (PARTITION BY fund ORDER BY time) AS r
      FROM fund_nav) t
GROUP BY fund
ORDER BY fund;
```

Result:

| fund (SYMBOL) | months (LONG) | avg_month_pct (DOUBLE) | sharpe (DOUBLE) | sortino (DOUBLE) | calmar (DOUBLE) | max_drawdown_pct (DOUBLE) | var95_pct (DOUBLE) |
|---|---|---|---|---|---|---|---|
| GROWTH | 23 | 0.89 | 1.35 | 2.33 | 1.26 | -8.61 | 3.09 |
| INCOME | 23 | 0.33 | 2.85 | 6.76 | 4.5 | -0.89 | 0.39 |

(2 rows)

<a id="pct_return"></a>

## pct_return, percent_return, returns

Syntax:

```sql
pct_return(x)
pct_return(x, k)
pct_return(x, k) OVER ([PARTITION BY ...] [ORDER BY ...])
percent_return(x [, k])
returns(x [, k])
```

The **simple return**: the change from `k` rows before, as a fraction: `x / previous x - 1`. On daily closes it is the **daily return**; `0.012` means the price rose 1.2%. `percent_return` and `returns` are the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` or a fund's NAV |
| `k` | whole number, 1 or more | how many rows back; default `1`. `5` on daily candles is the return over 5 trading days (about one week) |

- **Returns:** `DOUBLE`, a fraction (`0.012` = +1.2%).
- **NULL:** `NULL` for the first `k` rows, when this or the earlier value is `NULL`, and when the earlier value is `0`.
- **Notes:** the same as `pct_change(x) / 100`, but `pct_return` can look `k` rows back. `ROWS` inside `OVER` is ignored.

**Example: Daily return of each symbol: a fraction, and pct_change in percent** (sample data: sample, analysis-market)

```sql
SELECT time, symbol, close,
       round(pct_return(close) OVER (PARTITION BY symbol ORDER BY time), 5) AS daily_return,
       round(pct_change(close) OVER (PARTITION BY symbol ORDER BY time), 3) AS change_pct
FROM ochl_day
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | daily_return (DOUBLE) | change_pct (DOUBLE) |
|---|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | NULL | NULL |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 0.01427 | 1.427 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 0.00059 | 0.059 |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | NULL | NULL |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 0.00769 | 0.769 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | -0.01052 | -1.052 |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | NULL | NULL |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 0.02686 | 2.686 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 0.02082 | 2.082 |

(9 rows)

**Example: Return over the last 5 trading days** (sample data: sample, analysis-market)

```sql
SELECT time, close, lag(close, 5) AS close_5_days_ago,
       round(pct_return(close, 5) * 100, 2) AS return_5d_pct
FROM ochl_day
WHERE symbol = 'COAST' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | close_5_days_ago (DOUBLE) | return_5d_pct (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 391 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 384.9 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 379.8 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 373 | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 367.1 | NULL | NULL |
| 2026-08-30T00:00:00.000Z | 372.4 | 391 | -4.76 |
| 2026-08-31T00:00:00.000Z | 368.2 | 384.9 | -4.34 |
| 2026-09-01T00:00:00.000Z | 367.4 | 379.8 | -3.26 |
| 2026-09-02T00:00:00.000Z | 369.2 | 373 | -1.02 |
| 2026-09-03T00:00:00.000Z | 373.2 | 367.1 | 1.66 |
| 2026-09-06T00:00:00.000Z | 375.4 | 372.4 | 0.81 |
| 2026-09-07T00:00:00.000Z | 379.2 | 368.2 | 2.99 |
| 2026-09-08T00:00:00.000Z | 377.2 | 367.4 | 2.67 |
| 2026-09-09T00:00:00.000Z | 380.1 | 369.2 | 2.95 |
| 2026-09-10T00:00:00.000Z | 376.1 | 373.2 | 0.78 |

(15 rows)

**Example: NULL and zero prices** (sample data: sample, analysis-market)

Setup:

```sql
CREATE TABLE prices (time TIMESTAMP, close DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO prices VALUES ('2026-09-01', 100), ('2026-09-02', 110), ('2026-09-03', NULL),
  ('2026-09-04', 99), ('2026-09-05', 121), ('2026-09-06', 0), ('2026-09-07', 50);
```

```sql
SELECT time, close,
       round(pct_return(close), 4) AS pct_return,
       round(log_return(close), 4) AS log_return,
       round(cum_return(close), 4) AS cum_return,
       round(drawdown(close), 4) AS drawdown
FROM prices
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | pct_return (DOUBLE) | log_return (DOUBLE) | cum_return (DOUBLE) | drawdown (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 100 | NULL | NULL | 0 | 0 |
| 2026-09-02T00:00:00.000Z | 110 | 0.1 | 0.0953 | 0.1 | 0 |
| 2026-09-03T00:00:00.000Z | NULL | NULL | NULL | NULL | NULL |
| 2026-09-04T00:00:00.000Z | 99 | NULL | NULL | -0.01 | -0.1 |
| 2026-09-05T00:00:00.000Z | 121 | 0.2222 | 0.2007 | 0.21 | 0 |
| 2026-09-06T00:00:00.000Z | 0 | -1 | NULL | -1 | -1 |
| 2026-09-07T00:00:00.000Z | 50 | NULL | NULL | -0.5 | -0.5868 |

(7 rows)

<a id="log_return"></a>

## log_return

Syntax:

```sql
log_return(x)
log_return(x, k)
log_return(x, k) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **log return**: `ln(x / previous x)`. For small moves it is almost the same as the simple return: a rise from 507.9 to 510.3 is `0.00473` as a simple return and `0.00471` as a log return. Traders like it because log returns **add up**: the sum of the daily log returns is the log return of the whole period.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price |
| `k` | whole number, 1 or more | how many rows back; default `1` |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `k` rows, when this or the earlier value is `NULL`, and when the ratio is `0` or less (a price of `0`).
- **Notes:** `exp(log return) - 1` is the simple return. [volatility](functions-returns-risk.md#volatility) is made from log returns.

**Example: Log returns add up to the log return of the whole period** (sample data: sample, analysis-market)

```sql
SELECT symbol, first(close) AS first_close, last(close) AS last_close,
       round(sum(lr), 6) AS sum_of_log_returns,
       round(ln(last(close) / first(close)), 6) AS log_of_whole_period,
       round(exp(sum(lr)) - 1, 6) AS total_return
FROM (SELECT time, symbol, close,
             log_return(close) OVER (PARTITION BY symbol ORDER BY time) AS lr
      FROM ochl_day
      WHERE time >= '2026-08-23') t
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | first_close (DOUBLE) | last_close (DOUBLE) | sum_of_log_returns (DOUBLE) | log_of_whole_period (DOUBLE) | total_return (DOUBLE) |
|---|---|---|---|---|---|
| CITY | 507.9 | 504.9 | -0.005924 | -0.005924 | -0.005907 |
| COAST | 391 | 376.1 | -0.038852 | -0.038852 | -0.038107 |
| VOLT | 181 | 191.2 | 0.054823 | 0.054823 | 0.056354 |

(3 rows)

**Example: Simple and log return of CITY's last 4 minutes** (sample data: sample, analysis-market)

```sql
SELECT time, close, simple_return, log_return
FROM (SELECT time, close,
             round(pct_return(close), 6) AS simple_return,
             round(log_return(close), 6) AS log_return
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 4;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | simple_return (DOUBLE) | log_return (DOUBLE) |
|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | -0.000396 | -0.000396 |
| 2026-09-10T09:13:00.000Z | 505.1 | 0.000594 | 0.000594 |
| 2026-09-10T09:12:00.000Z | 504.8 | 0.000595 | 0.000594 |
| 2026-09-10T09:11:00.000Z | 504.5 | -0.000198 | -0.000198 |

(4 rows)

<a id="cum_return"></a>

## cum_return

Syntax:

```sql
cum_return(x)
cum_return(x) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **cumulative (total) return**: the change from the **first** value of the series to this row, `x / first x - 1`. It answers "how much did I make since I bought on the first day?".

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price or NAV |

- **Returns:** `DOUBLE`, a fraction. The first row is `0`.
- **NULL:** `NULL` on rows where `x` is `NULL` (the first value that is not NULL is the start). `NULL` on every row when the first value is `0`.
- **Notes:** it takes prices, not returns. `100 × (1 + cum_return)` is the value of 100 dollars invested at the start.

**Example: What became of 100 dollars in each fund (the last 4 months)** (sample data: sample, analysis-market)

```sql
SELECT time, fund, nav, growth_of_100
FROM (SELECT time, fund, nav,
             round(100 * (1 + cum_return(nav) OVER (PARTITION BY fund ORDER BY time)), 2) AS growth_of_100
      FROM fund_nav) t
WHERE time >= '2026-05-01'
ORDER BY fund, time;
```

Result:

| time (TIMESTAMP) | fund (SYMBOL) | nav (DOUBLE) | growth_of_100 (DOUBLE) |
|---|---|---|---|
| 2026-05-01T00:00:00.000Z | GROWTH | 11.31 | 113.1 |
| 2026-06-01T00:00:00.000Z | GROWTH | 11.66 | 116.6 |
| 2026-07-01T00:00:00.000Z | GROWTH | 11.94 | 119.4 |
| 2026-08-01T00:00:00.000Z | GROWTH | 12.18 | 121.8 |
| 2026-05-01T00:00:00.000Z | INCOME | 10.58 | 105.8 |
| 2026-06-01T00:00:00.000Z | INCOME | 10.65 | 106.5 |
| 2026-07-01T00:00:00.000Z | INCOME | 10.71 | 107.1 |
| 2026-08-01T00:00:00.000Z | INCOME | 10.78 | 107.8 |

(8 rows)

**Example: Total return of every symbol since 23 August** (sample data: sample, analysis-market)

```sql
SELECT symbol, close, total_return_pct
FROM (SELECT time, symbol, close,
             round(cum_return(close) OVER (PARTITION BY symbol ORDER BY time) * 100, 2) AS total_return_pct
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE time IN '2026-09-10'
ORDER BY total_return_pct DESC;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | total_return_pct (DOUBLE) |
|---|---|---|
| VOLT | 191.2 | 5.64 |
| CITY | 504.9 | -0.59 |
| COAST | 376.1 | -3.81 |

(3 rows)

## drawdown

Syntax:

```sql
drawdown(x)
drawdown(x) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **drawdown**: how far the price is below its **highest value so far** (the peak), as a fraction: `x / peak - 1`. `-0.05` means 5% below the peak. It is `0` on a new high. Traders use it to see how painful a fall was, and when the price got back to its old high.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price or NAV |

- **Returns:** `DOUBLE`, `0` or less.
- **NULL:** `NULL` on rows where `x` is `NULL` (NULL values do not change the peak), and while the peak is `0` or less.
- **Notes:** the peak is the running maximum, the same as [cummax](functions-window.md#cummax). The deepest drawdown of a group is the aggregate [max_drawdown](functions-returns-risk.md#max_drawdown).

**Example: VOLT: the peak so far and the drawdown from it** (sample data: sample, analysis-market)

```sql
SELECT time, close, cummax(close) AS peak, round(drawdown(close) * 100, 2) AS drawdown_pct
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | peak (DOUBLE) | drawdown_pct (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 181 | 181 | 0 |
| 2026-08-24T00:00:00.000Z | 178.5 | 181 | -1.38 |
| 2026-08-25T00:00:00.000Z | 176.8 | 181 | -2.32 |
| 2026-08-26T00:00:00.000Z | 174.2 | 181 | -3.76 |
| 2026-08-27T00:00:00.000Z | 173.3 | 181 | -4.25 |
| 2026-08-30T00:00:00.000Z | 173 | 181 | -4.42 |
| 2026-08-31T00:00:00.000Z | 172.6 | 181 | -4.64 |
| 2026-09-01T00:00:00.000Z | 169 | 181 | -6.63 |
| 2026-09-02T00:00:00.000Z | 171.5 | 181 | -5.25 |
| 2026-09-03T00:00:00.000Z | 176 | 181 | -2.76 |
| 2026-09-06T00:00:00.000Z | 180.1 | 181 | -0.5 |
| 2026-09-07T00:00:00.000Z | 176.9 | 181 | -2.27 |
| 2026-09-08T00:00:00.000Z | 182.4 | 182.4 | 0 |
| 2026-09-09T00:00:00.000Z | 187.3 | 187.3 | 0 |
| 2026-09-10T00:00:00.000Z | 191.2 | 191.2 | 0 |

(15 rows)

**Example: Days when a share was more than 3% below its peak** (sample data: sample, analysis-market)

```sql
SELECT time, symbol, close, drawdown_pct
FROM (SELECT time, symbol, close,
             round(drawdown(close) OVER (PARTITION BY symbol ORDER BY time) * 100, 2) AS drawdown_pct
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE drawdown_pct < -3
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | drawdown_pct (DOUBLE) |
|---|---|---|---|
| 2026-09-02T00:00:00.000Z | CITY | 496.4 | -3.29 |
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | -3.08 |
| 2026-08-26T00:00:00.000Z | COAST | 373 | -4.6 |
| 2026-08-27T00:00:00.000Z | COAST | 367.1 | -6.11 |
| 2026-08-30T00:00:00.000Z | COAST | 372.4 | -4.76 |
| 2026-08-31T00:00:00.000Z | COAST | 368.2 | -5.83 |
| 2026-09-01T00:00:00.000Z | COAST | 367.4 | -6.04 |
| 2026-09-02T00:00:00.000Z | COAST | 369.2 | -5.58 |
| 2026-09-03T00:00:00.000Z | COAST | 373.2 | -4.55 |
| 2026-09-06T00:00:00.000Z | COAST | 375.4 | -3.99 |
| 2026-09-07T00:00:00.000Z | COAST | 379.2 | -3.02 |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | -3.53 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | -3.81 |
| 2026-08-26T00:00:00.000Z | VOLT | 174.2 | -3.76 |
| 2026-08-27T00:00:00.000Z | VOLT | 173.3 | -4.25 |
| 2026-08-30T00:00:00.000Z | VOLT | 173 | -4.42 |
| 2026-08-31T00:00:00.000Z | VOLT | 172.6 | -4.64 |
| 2026-09-01T00:00:00.000Z | VOLT | 169 | -6.63 |
| 2026-09-02T00:00:00.000Z | VOLT | 171.5 | -5.25 |

(19 rows)

## volatility

Syntax:

```sql
volatility(price, n)
volatility(price, n, periods)
volatility(price, n, periods) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **historical volatility**: how much the price jumps, as a fraction. It is the sample standard deviation of the last `n` log returns. With `periods` it is made yearly: × `sqrt(periods)`. A yearly volatility of `0.25` means the price usually moves about 25% up or down in a year. High volatility means high risk.

| Argument | Type | Meaning |
|---|---|---|
| `price` | number | the price, usually `close` |
| `n` | whole number, 2 or more | how many returns to use (`20` is about one month of trading days) |
| `periods` | number, more than 0 | returns per year, to make it yearly: `240` for daily candles; default `1` (per period, not yearly) |

- **Returns:** `DOUBLE`, a fraction.
- **NULL:** `NULL` for the first `n` rows (the first row has no return). `NULL` when one of the `n` returns is missing (a `NULL` price, or a price of `0` or less).
- **Notes:** it uses **log** returns and divides by `n - 1`, like most charting programs. For small daily moves it is almost the same as [stddev](functions-statistics.md#stddev) of the last `n` simple returns. `ROWS` inside `OVER` is ignored.

**Example: CITY: 5-day volatility per day, and made yearly with 240 trading days** (sample data: sample, analysis-market)

```sql
SELECT time, close,
       round(volatility(close, 5), 5) AS vol_per_day,
       round(volatility(close, 5, 240) * 100, 1) AS vol_per_year_pct
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | vol_per_day (DOUBLE) | vol_per_year_pct (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 507.9 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 510.3 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 513.3 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 513.2 | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 505.9 | NULL | NULL |
| 2026-08-30T00:00:00.000Z | 503.1 | 0.00829 | 12.8 |
| 2026-08-31T00:00:00.000Z | 505.7 | 0.00838 | 13 |
| 2026-09-01T00:00:00.000Z | 502.4 | 0.0073 | 11.3 |
| 2026-09-02T00:00:00.000Z | 496.4 | 0.00755 | 11.7 |
| 2026-09-03T00:00:00.000Z | 497.9 | 0.00712 | 11 |
| 2026-09-06T00:00:00.000Z | 499 | 0.00732 | 11.3 |
| 2026-09-07T00:00:00.000Z | 498.7 | 0.00638 | 9.9 |
| 2026-09-08T00:00:00.000Z | 497.5 | 0.00603 | 9.3 |
| 2026-09-09T00:00:00.000Z | 504.6 | 0.00647 | 10 |
| 2026-09-10T00:00:00.000Z | 504.9 | 0.00658 | 10.2 |

(15 rows)

**Example: Which share is most volatile? 10-day yearly volatility on 10 September** (sample data: sample, analysis-market)

```sql
SELECT symbol, close, vol_year_pct
FROM (SELECT time, symbol, close,
             round(volatility(close, 10, 240) OVER (PARTITION BY symbol ORDER BY time) * 100, 1) AS vol_year_pct
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE time IN '2026-09-10'
ORDER BY vol_year_pct DESC;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | vol_year_pct (DOUBLE) |
|---|---|---|
| VOLT | 191.2 | 29.6 |
| COAST | 376.1 | 14.2 |
| CITY | 504.9 | 11.1 |

(3 rows)

**Example: n must be 2 or more** (sample data: sample, analysis-market; shows an error)

```sql
SELECT volatility(close, 1) FROM ochl_day;
```

Result:

Error: `line 1, column 8: volatility: the period must be a whole number of rows (2 or more)`

## zscore

Syntax:

```sql
zscore(x)
zscore(x) OVER ([PARTITION BY ...] [ORDER BY ...] [ROWS ...])
zscore(x, n)
zscore(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **z-score** (standard score): how many standard deviations `x` is above (`+`) or below (`-`) the average: `(x - average) / stddev`. `0` is a normal value; above `2` or below `-2` is unusual. Traders use it to find strange volume, or a price far from its average ("mean reversion").

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the value |
| `n` | whole number, 2 or more | optional: compare with the last `n` rows (this row and the `n - 1` before it) |

Which values it compares with:

| Call | Average and stddev of |
|---|---|
| `zscore(x)` or `zscore(x) OVER (PARTITION BY ...)` | all rows of the series (or of the part) |
| `zscore(x) OVER (... ORDER BY time)` | the first row to this row (running) |
| `zscore(x) OVER (... ORDER BY time ROWS 4 PRECEDING)` | the frame: this row and the 4 before it |
| `zscore(x, n)` | the last `n` rows; `NULL` until there are `n` rows |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` when `x` is `NULL`, when there are fewer than 2 values, and when all values are equal (stddev `0`). Without `n`, NULL values in the window are skipped; with `n`, a NULL in the last `n` rows gives `NULL`.
- **Notes:** it uses the sample standard deviation (divide by `n - 1`), like [stddev](functions-statistics.md#stddev).

**Example: How unusual is the volume? z-score of each day's volume per symbol** (sample data: sample, analysis-market)

```sql
SELECT time, symbol, volume, volume_z
FROM (SELECT time, symbol, volume,
             round(zscore(volume) OVER (PARTITION BY symbol), 2) AS volume_z
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | volume (DOUBLE) | volume_z (DOUBLE) |
|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 34400 | -2 |
| 2026-09-09T00:00:00.000Z | CITY | 182390 | 1.65 |
| 2026-09-10T00:00:00.000Z | CITY | 183040 | 1.67 |
| 2026-09-08T00:00:00.000Z | COAST | 60980 | -0.77 |
| 2026-09-09T00:00:00.000Z | COAST | 186330 | 1.85 |
| 2026-09-10T00:00:00.000Z | COAST | 186200 | 1.85 |
| 2026-09-08T00:00:00.000Z | VOLT | 136770 | 1.19 |
| 2026-09-09T00:00:00.000Z | VOLT | 94410 | 0.05 |
| 2026-09-10T00:00:00.000Z | VOLT | 41470 | -1.38 |

(9 rows)

**Example: Rolling 5-day z-score against the running z-score** (sample data: sample, analysis-market)

```sql
SELECT time, close,
       round(zscore(close, 5), 3) AS z_last_5_days,
       round(zscore(close) OVER (ORDER BY time), 3) AS z_since_start
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | z_last_5_days (DOUBLE) | z_since_start (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 507.9 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 510.3 | NULL | 0.707 |
| 2026-08-25T00:00:00.000Z | 513.3 | NULL | 1.035 |
| 2026-08-26T00:00:00.000Z | 513.2 | NULL | 0.782 |
| 2026-08-27T00:00:00.000Z | 505.9 | -1.297 | -1.297 |
| 2026-08-30T00:00:00.000Z | 503.1 | -1.338 | -1.432 |
| 2026-08-31T00:00:00.000Z | 505.7 | -0.54 | -0.71 |
| 2026-09-01T00:00:00.000Z | 502.4 | -0.855 | -1.261 |
| 2026-09-02T00:00:00.000Z | 496.4 | -1.638 | -1.842 |
| 2026-09-03T00:00:00.000Z | 497.9 | -0.832 | -1.325 |
| 2026-09-06T00:00:00.000Z | 499 | -0.341 | -1.024 |
| 2026-09-07T00:00:00.000Z | 498.7 | -0.081 | -0.982 |
| 2026-09-08T00:00:00.000Z | 497.5 | -0.388 | -1.082 |
| 2026-09-09T00:00:00.000Z | 504.6 | 1.75 | 0.106 |
| 2026-09-10T00:00:00.000Z | 504.9 | 1.124 | 0.153 |

(15 rows)

<a id="minmax_scale"></a>

## minmax_scale

Syntax:

```sql
minmax_scale(x)
minmax_scale(x) OVER ([PARTITION BY ...] [ORDER BY ...] [ROWS ...])
minmax_scale(x, n)
minmax_scale(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

Puts `x` on a scale from `0` to `1`: `(x - lowest) / (highest - lowest)`. `0` is the lowest value, `1` the highest, `0.5` the middle. Use it to draw shares with very different prices on one chart, or to see where today's close sits in its recent range.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the value |
| `n` | whole number, 1 or more | optional: the lowest and highest of the last `n` rows |

The values it compares with are chosen like [zscore](functions-returns-risk.md#zscore): all rows, the window frame, or the last `n` rows.

- **Returns:** `DOUBLE` from `0` to `1`.
- **NULL:** `NULL` when `x` is `NULL`, and when the lowest and highest are equal (for example the first row of a running window). With `n`: `NULL` for the first `n - 1` rows, and when a value in the last `n` rows is `NULL`.
- **Notes:** `minmax_scale(close, 14)` on a close is close to the fast stochastic, which uses the high and low of the candles instead.

**Example: Three shares with different prices on one 0-1 scale** (sample data: sample, analysis-market)

```sql
SELECT time, symbol, close, scaled
FROM (SELECT time, symbol, close,
             round(minmax_scale(close) OVER (PARTITION BY symbol), 3) AS scaled
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE time >= '2026-09-08'
ORDER BY time, symbol;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | scaled (DOUBLE) |
|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | 0.065 |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | 0.423 |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | 0.604 |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 0.485 |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 0.544 |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 0.824 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 0.503 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 0.377 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 1 |

(9 rows)

**Example: Where is the close in its 5-day range? (0 = at the low, 1 = at the high)** (sample data: sample, analysis-market)

```sql
SELECT time, close, round(minmax_scale(close, 5), 3) AS place_in_5_day_range
FROM ochl_day
WHERE symbol = 'COAST' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | place_in_5_day_range (DOUBLE) |
|---|---|---|
| 2026-08-23T00:00:00.000Z | 391 | NULL |
| 2026-08-24T00:00:00.000Z | 384.9 | NULL |
| 2026-08-25T00:00:00.000Z | 379.8 | NULL |
| 2026-08-26T00:00:00.000Z | 373 | NULL |
| 2026-08-27T00:00:00.000Z | 367.1 | 0 |
| 2026-08-30T00:00:00.000Z | 372.4 | 0.298 |
| 2026-08-31T00:00:00.000Z | 368.2 | 0.087 |
| 2026-09-01T00:00:00.000Z | 367.4 | 0.051 |
| 2026-09-02T00:00:00.000Z | 369.2 | 0.396 |
| 2026-09-03T00:00:00.000Z | 373.2 | 1 |
| 2026-09-06T00:00:00.000Z | 375.4 | 1 |
| 2026-09-07T00:00:00.000Z | 379.2 | 1 |
| 2026-09-08T00:00:00.000Z | 377.2 | 0.8 |
| 2026-09-09T00:00:00.000Z | 380.1 | 1 |
| 2026-09-10T00:00:00.000Z | 376.1 | 0.149 |

(15 rows)

<a id="max_drawdown"></a>

## max_drawdown

Syntax:

```sql
max_drawdown(price)
max_drawdown(price) OVER (...)
```

The **maximum drawdown**: the biggest fall from a peak to a later low, as a fraction. `-0.086` means that at the worst moment, an investor who bought at the top had lost 8.6%. It is the deepest value of [drawdown](functions-returns-risk.md#drawdown). Fund reports show it next to the return.

| Argument | Type | Meaning |
|---|---|---|
| `price` | number | the price or NAV (not returns) |

- **Returns:** `DOUBLE`, `0` or less. `0` when the price never fell.
- **NULL:** NULL prices are skipped. `NULL` when there are no prices, or when a price is `0` or less.
- **Notes:** an aggregate that needs **time order**: it reads the rows by their time (or in the order they come, when there is no time column). With `OVER (ORDER BY time)` it gives the worst drawdown so far on every row.

**Example: Worst fall of each fund** (sample data: sample, analysis-market)

```sql
SELECT fund, first(nav) AS start_nav, last(nav) AS end_nav,
       round(max_drawdown(nav) * 100, 2) AS max_drawdown_pct
FROM fund_nav
GROUP BY fund
ORDER BY fund;
```

Result:

| fund (SYMBOL) | start_nav (DOUBLE) | end_nav (DOUBLE) | max_drawdown_pct (DOUBLE) |
|---|---|---|---|
| GROWTH | 10 | 12.18 | -8.61 |
| INCOME | 10 | 10.78 | -0.89 |

(2 rows)

**Example: Drawdown of the day and the worst drawdown so far** (sample data: sample, analysis-market)

```sql
SELECT time, close,
       round(drawdown(close) * 100, 2) AS drawdown_pct,
       round(max_drawdown(close) OVER (ORDER BY time) * 100, 2) AS worst_so_far_pct
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | drawdown_pct (DOUBLE) | worst_so_far_pct (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 181 | 0 | 0 |
| 2026-08-24T00:00:00.000Z | 178.5 | -1.38 | -1.38 |
| 2026-08-25T00:00:00.000Z | 176.8 | -2.32 | -2.32 |
| 2026-08-26T00:00:00.000Z | 174.2 | -3.76 | -3.76 |
| 2026-08-27T00:00:00.000Z | 173.3 | -4.25 | -4.25 |
| 2026-08-30T00:00:00.000Z | 173 | -4.42 | -4.42 |
| 2026-08-31T00:00:00.000Z | 172.6 | -4.64 | -4.64 |
| 2026-09-01T00:00:00.000Z | 169 | -6.63 | -6.63 |
| 2026-09-02T00:00:00.000Z | 171.5 | -5.25 | -6.63 |
| 2026-09-03T00:00:00.000Z | 176 | -2.76 | -6.63 |
| 2026-09-06T00:00:00.000Z | 180.1 | -0.5 | -6.63 |
| 2026-09-07T00:00:00.000Z | 176.9 | -2.27 | -6.63 |
| 2026-09-08T00:00:00.000Z | 182.4 | 0 | -6.63 |
| 2026-09-09T00:00:00.000Z | 187.3 | 0 | -6.63 |
| 2026-09-10T00:00:00.000Z | 191.2 | 0 | -6.63 |

(15 rows)

<a id="sharpe_ratio"></a>

## sharpe_ratio

Syntax:

```sql
sharpe_ratio(returns)
sharpe_ratio(returns, risk_free)
sharpe_ratio(returns, risk_free, periods)
```

The **Sharpe ratio**: how much return you get for each unit of risk. It is the average return above the risk-free rate, divided by the standard deviation of the returns: `(avg(returns) - risk_free) / stddev(returns) × sqrt(periods)`. Bigger is better: above `1` (yearly) is good, above `2` very good. The **risk-free rate** is what a safe investment pays, like a bank fixed deposit.

| Argument | Type | Meaning |
|---|---|---|
| `returns` | number | one return per row, as a fraction (from [pct_return](functions-returns-risk.md#pct_return)) |
| `risk_free` | number | the safe return **per period**, as a fraction; default `0`. A fixed deposit of 6% a year is `0.06 / 12` = `0.005` per month |
| `periods` | number | returns per year, to make the ratio yearly (`12` for monthly, `240` for daily stock returns); default `1` |

- **Returns:** `DOUBLE`.
- **NULL:** NULL returns are skipped. `NULL` with fewer than 2 returns, when all returns are equal, when `risk_free` or `periods` is `NULL`, and when `periods` is `0` or less.
- **Notes:** it uses the sample standard deviation. `risk_free` and `periods` are read once, from the first row. A ratio made from a few returns (a few weeks of data) is not reliable.

**Example: Sharpe ratio of each fund: per month, per year, and above a 6% fixed deposit** (sample data: sample, analysis-market)

```sql
SELECT fund,
       round(sharpe_ratio(r), 3) AS per_month,
       round(sharpe_ratio(r, 0, 12), 3) AS per_year,
       round(sharpe_ratio(r, 0.06 / 12, 12), 3) AS per_year_above_fd
FROM (SELECT time, fund, pct_return(nav) OVER (PARTITION BY fund ORDER BY time) AS r
      FROM fund_nav) t
GROUP BY fund
ORDER BY fund;
```

Result:

| fund (SYMBOL) | per_month (DOUBLE) | per_year (DOUBLE) | per_year_above_fd (DOUBLE) |
|---|---|---|---|
| GROWTH | 0.39 | 1.351 | 0.588 |
| INCOME | 0.822 | 2.847 | -1.495 |

(2 rows)

**Example: Yearly Sharpe ratio of the shares from daily returns (only 14 returns: just a demo)** (sample data: sample, analysis-market)

```sql
SELECT symbol, count(r) AS returns, round(avg(r) * 100, 3) AS avg_day_pct,
       round(sharpe_ratio(r, 0, 240), 2) AS sharpe_year
FROM (SELECT time, symbol, pct_return(close) OVER (PARTITION BY symbol ORDER BY time) AS r
      FROM ochl_day
      WHERE time >= '2026-08-23') t
GROUP BY symbol
ORDER BY sharpe_year DESC;
```

Result:

| symbol (SYMBOL) | returns (LONG) | avg_day_pct (DOUBLE) | sharpe_year (DOUBLE) |
|---|---|---|---|
| VOLT | 14 | 0.409 | 3.36 |
| CITY | 14 | -0.04 | -0.82 |
| COAST | 14 | -0.271 | -3.67 |

(3 rows)

<a id="sortino_ratio"></a>

## sortino_ratio

Syntax:

```sql
sortino_ratio(returns)
sortino_ratio(returns, target)
sortino_ratio(returns, target, periods)
```

The **Sortino ratio**: like the Sharpe ratio, but it only counts the **bad** jumps as risk. Rises above the target do not hurt an investor, so only returns below `target` go into the risk (the **downside deviation**). `(avg(returns) - target) / downside deviation × sqrt(periods)`. Bigger is better.

| Argument | Type | Meaning |
|---|---|---|
| `returns` | number | one return per row, as a fraction |
| `target` | number | the smallest return you are happy with, per period; default `0` |
| `periods` | number | returns per year, to make it yearly; default `1` |

- **Returns:** `DOUBLE`.
- **NULL:** NULL returns are skipped. `NULL` when no return is below `target` (no downside), when `target` or `periods` is `NULL`, and when `periods` is `0` or less.
- **Notes:** the downside deviation is `sqrt(sum(min(0, return - target)²) / number of returns)`: it divides by **all** returns, like most fund reports. A fund with rare, small losses has a Sortino ratio much bigger than its Sharpe ratio.

**Example: Sortino against Sharpe for both funds** (sample data: sample, analysis-market)

```sql
SELECT fund,
       round(sharpe_ratio(r, 0, 12), 2) AS sharpe,
       round(sortino_ratio(r, 0, 12), 2) AS sortino,
       round(sortino_ratio(r, 0.005, 12), 2) AS sortino_target_half_pct
FROM (SELECT time, fund, pct_return(nav) OVER (PARTITION BY fund ORDER BY time) AS r
      FROM fund_nav) t
GROUP BY fund
ORDER BY fund;
```

Result:

| fund (SYMBOL) | sharpe (DOUBLE) | sortino (DOUBLE) | sortino_target_half_pct (DOUBLE) |
|---|---|---|---|
| GROWTH | 1.35 | 2.33 | 0.84 |
| INCOME | 2.85 | 6.76 | -1.43 |

(2 rows)

<a id="calmar_ratio"></a>

## calmar_ratio

Syntax:

```sql
calmar_ratio(returns, periods)
```

The **Calmar ratio**: the yearly return divided by the maximum drawdown. It answers "how much did I earn per year for each 1% of the worst fall?". Bigger is better; above `1` is good. Fund reports usually use the last 36 monthly returns.

| Argument | Type | Meaning |
|---|---|---|
| `returns` | number | one return per row, as a fraction, in time order |
| `periods` | number | returns per year: `12` for monthly, `240` for daily stock returns (needed) |

- **Returns:** `DOUBLE`.
- **NULL:** NULL returns are skipped. `NULL` when the value never fell (no drawdown), when `periods` is `NULL`, `0` or less, and when the investment lost everything.
- **Notes:** the yearly return is compounded, like [cagr](functions-finance.md#cagr): `(product of (1 + return)) ^ (periods / number of returns) - 1`. The drawdown comes from the same returns, in time order. Both arguments are needed.

**Example: Calmar ratio of each fund, with its drawdown** (sample data: sample, analysis-market)

```sql
SELECT fund, count(r) AS months,
       round(max_drawdown(nav) * 100, 2) AS max_drawdown_pct,
       round(calmar_ratio(r, 12), 2) AS calmar
FROM (SELECT time, fund, nav, pct_return(nav) OVER (PARTITION BY fund ORDER BY time) AS r
      FROM fund_nav) t
GROUP BY fund
ORDER BY fund;
```

Result:

| fund (SYMBOL) | months (LONG) | max_drawdown_pct (DOUBLE) | calmar (DOUBLE) |
|---|---|---|---|
| GROWTH | 23 | -8.61 | 1.26 |
| INCOME | 23 | -0.89 | 4.5 |

(2 rows)

**Example: The number of periods per year is needed** (sample data: sample, analysis-market; shows an error)

```sql
SELECT calmar_ratio(nav) FROM fund_nav;
```

Result:

Error: `line 1, column 8: function 'calmar_ratio' takes 2 argument(s), got 1`

<a id="information_ratio"></a>

## information_ratio

Syntax:

```sql
information_ratio(returns, benchmark)
information_ratio(returns, benchmark, periods)
```

The **information ratio**: how well an investment beats a **benchmark** (a market index), for the risk of being different from it. It is the average of `returns - benchmark`, divided by the standard deviation of that difference (the **tracking error**), × `sqrt(periods)`. Above `0` the share did better than the index; above `0.5` (yearly) is good.

| Argument | Type | Meaning |
|---|---|---|
| `returns` | number | the returns of the share or fund |
| `benchmark` | number | the returns of the index on the same days |
| `periods` | number | returns per year, to make it yearly; default `1` |

- **Returns:** `DOUBLE`.
- **NULL:** a row where `returns` or `benchmark` is `NULL` is skipped. `NULL` with fewer than 2 rows, when the difference is always the same (tracking error `0`), and when `periods` is `NULL`, `0` or less.
- **Notes:** join the share and the index on the time, and make both returns in the same subquery.

**Example: Did the shares beat the market index? (daily returns since 23 August)** (sample data: sample, analysis-market)

```sql
SELECT symbol, count(r) AS days,
       round(avg(r - m) * 100, 3) AS avg_excess_day_pct,
       round(information_ratio(r, m), 3) AS per_day,
       round(information_ratio(r, m, 240), 2) AS per_year
FROM (SELECT d.time, d.symbol,
             pct_return(d.close) OVER (PARTITION BY d.symbol ORDER BY d.time) AS r,
             pct_return(i.close) OVER (PARTITION BY d.symbol ORDER BY d.time) AS m
      FROM ochl_day d
      JOIN market_index i ON i.time = d.time
      WHERE d.time >= '2026-08-23') t
GROUP BY symbol
ORDER BY per_year DESC;
```

Result:

| symbol (SYMBOL) | days (LONG) | avg_excess_day_pct (DOUBLE) | per_day (DOUBLE) | per_year (DOUBLE) |
|---|---|---|---|---|
| VOLT | 14 | 0.41 | 0.252 | 3.9 |
| CITY | 14 | -0.038 | -0.058 | -0.89 |
| COAST | 14 | -0.27 | -0.294 | -4.55 |

(3 rows)

<a id="value_at_risk"></a>

## value_at_risk

Syntax:

```sql
value_at_risk(returns, confidence)
```

The **value at risk (VaR)**: a loss that is **not** passed in most periods. With `confidence` `0.95`, a VaR of `0.031` means: in 95 months of 100 the loss is at most 3.1%; in about 5 of 100 it is bigger. Banks and brokers use it to set limits: "the 1-day 95% VaR of this position is $12,000".

| Argument | Type | Meaning |
|---|---|---|
| `returns` | number | one return per row, as a fraction |
| `confidence` | number, more than 0 and less than 1 | how sure: `0.95` or `0.99` |

- **Returns:** `DOUBLE`, the loss as a **positive** fraction. It is negative when even the bad returns are gains.
- **NULL:** NULL returns are skipped. `NULL` with no returns, and when `confidence` is `NULL`.
- **Notes:** this is **historical** VaR: minus the `1 - confidence` percentile of the returns you have, with the same interpolation as [percentile](functions-aggregate.md#percentile). It needs many returns to be useful. Multiply by the money invested to get an amount of money. `confidence` is read once, from the first row.

**Example: 95% monthly VaR of each fund, and in dollars for 500,000 invested** (sample data: sample, analysis-market)

```sql
SELECT fund,
       round(value_at_risk(r, 0.95) * 100, 2) AS var95_pct,
       round(value_at_risk(r, 0.95) * 500000) AS var95_dollars
FROM (SELECT time, fund, pct_return(nav) OVER (PARTITION BY fund ORDER BY time) AS r
      FROM fund_nav) t
GROUP BY fund
ORDER BY fund;
```

Result:

| fund (SYMBOL) | var95_pct (DOUBLE) | var95_dollars (DOUBLE) |
|---|---|---|
| GROWTH | 3.09 | 15433 |
| INCOME | 0.39 | 1927 |

(2 rows)

**Example: Confidence is a fraction, not a percent** (sample data: sample, analysis-market; shows an error)

```sql
SELECT value_at_risk(close, 95) FROM ochl_day;
```

Result:

Error: `line 1, column 8: value_at_risk: the confidence level must be more than 0 and less than 1, like 0.95, got 95`

<a id="expected_shortfall"></a>

## expected_shortfall

Syntax:

```sql
expected_shortfall(returns, confidence)
```

The **expected shortfall** (also called CVaR, conditional value at risk): the **average** loss in the bad periods that [value_at_risk](functions-returns-risk.md#value_at_risk) leaves out. VaR says "in the worst 5% of months you lose at least this much"; expected shortfall says "and in those months you lose this much on average". It is always the same as VaR or bigger.

| Argument | Type | Meaning |
|---|---|---|
| `returns` | number | one return per row, as a fraction |
| `confidence` | number, more than 0 and less than 1 | how sure: `0.95` or `0.99` |

- **Returns:** `DOUBLE`, the average loss as a **positive** fraction.
- **NULL:** NULL returns are skipped. `NULL` with no returns, and when `confidence` is `NULL`.
- **Notes:** it is minus the average of the returns at or below the `1 - confidence` percentile.

**Example: Both funds: VaR and expected shortfall of monthly returns, at 90% and 95%** (sample data: sample, analysis-market)

```sql
SELECT fund,
       round(value_at_risk(r, 0.90) * 100, 2) AS var90_pct,
       round(expected_shortfall(r, 0.90) * 100, 2) AS es90_pct,
       round(value_at_risk(r, 0.95) * 100, 2) AS var95_pct,
       round(expected_shortfall(r, 0.95) * 100, 2) AS es95_pct
FROM (SELECT time, fund, pct_return(nav) OVER (PARTITION BY fund ORDER BY time) AS r
      FROM fund_nav) t
GROUP BY fund
ORDER BY fund;
```

Result:

| fund (SYMBOL) | var90_pct (DOUBLE) | es90_pct (DOUBLE) | var95_pct (DOUBLE) | es95_pct (DOUBLE) |
|---|---|---|---|---|
| GROWTH | 2.31 | 3.08 | 3.09 | 3.45 |
| INCOME | 0.28 | 0.42 | 0.39 | 0.48 |

(2 rows)

**Example: The worst monthly returns of GROWTH, to see where the numbers come from** (sample data: sample, analysis-market)

```sql
SELECT time, round(r * 100, 2) AS return_pct
FROM (SELECT time, pct_return(nav) AS r FROM fund_nav WHERE fund = 'GROWTH') t
WHERE r < 0
ORDER BY r
LIMIT 4;
```

Result:

| time (TIMESTAMP) | return_pct (DOUBLE) |
|---|---|
| 2026-04-01T00:00:00.000Z | -3.73 |
| 2025-02-01T00:00:00.000Z | -3.17 |
| 2025-03-01T00:00:00.000Z | -2.35 |
| 2025-01-01T00:00:00.000Z | -2.13 |

(4 rows)
