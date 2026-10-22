# Statistics functions

> Describe a set of numbers: spread (stddev, variance, mad, iqr, range), shape (skewness, kurtosis), other averages (geomean, harmonic_mean, mode) and exact percentiles.

- Category: Functions — statistics
- Keywords: statistics, spread, dispersion, std, standard deviation, volatility, risk, variance, sample, population, stdev, std, var, stddev\_population, variance\_samp, variance\_pop, shape, skew, asymmetry, kurt, fat tails, tail risk, crash risk, excess kurtosis, geometric mean, average growth, harmonic mean, average cost, most common value, most frequent, quantile, median\_cont, percentile\_continuous, percentile\_discrete, WITHIN GROUP, ordered-set aggregate, MAD, robust spread, outlier, interquartile range, quartile, max minus min, high low range, sum of squares, realized volatility, Shannon entropy, diversity, approx\_distinct, ndv
- See also: [Aggregate functions](functions-aggregate.md), [Correlation and regression](functions-correlation.md), [Returns and risk](functions-returns-risk.md), [Window and series functions (aggregates)](functions-window.md#aggregates), [Technical indicators](functions-indicators.md), [Math functions (sqrt)](functions-math.md#sqrt)

Statistics functions describe a set of numbers with one value. Most of them are **aggregates**: they read many rows and give one value per group, like `avg` ([aggregate functions](functions-aggregate.md)). They follow the same rules:

- They work with `GROUP BY`, `SAMPLE BY`, implicit GROUP BY and `HAVING`.
- They **skip NULL values**. No values give `NULL`.
- They take numbers (`LONG`, `DOUBLE`, `DECIMAL`, ...). Text gives an error. Only `mode`, `percentile_disc`, `entropy` and `approx_count_distinct` also take text and times, and `range` also takes times.
- They give a `DOUBLE`. Use `round(x, 3)` for a report. The exceptions say so in their entry: `mode` and `percentile_disc` give one of the values themselves, `range` keeps the type (`LONG`, `DECIMAL`), `approx_count_distinct` gives a `LONG`.
- With `OVER (...)` they give a moving value for every row, for example a 5-day volatility ([window functions](functions-window.md#aggregates)).

**Spread** means how far the values are from their average. Prices that jump up and down have a big spread; a steady price has a small one. Traders call the spread of price changes **volatility** (risk).

- The **variance** is the average of the squared distances from the average.
- The **standard deviation** is the square root of the variance. It has the same unit as the values (dollars for prices), so it is easier to read.

**Sample or population?**

- **Population:** your rows are *all* the values there are (all trades of one day). Divide by `n`, the number of values: `stddev_pop`, `var_pop`.
- **Sample:** your rows are only *a part* of a bigger story (the last 20 days of a share that trades for years). Divide by `n - 1`: `stddev`, `stddev_samp`, `variance`, `var_samp`. This is the usual choice for prices and returns, and what Excel's `STDEV` does.

With many rows the two are almost the same. With one row, the sample versions give `NULL` (you cannot guess a spread from one value) and the population versions give `0`.

**More on this page:** the **shape** of the values (`skewness`, `kurtosis`), other kinds of average (`geomean`, `harmonic_mean`, `mode`), exact percentiles (`percentile_cont`, `percentile_disc`, `WITHIN GROUP`), spread that big outliers do not move (`mad`, `iqr`), and `range`, `sum_of_squares`, `entropy`, `approx_count_distinct`. For two series together (correlation, beta) see [correlation and regression](functions-correlation.md); for returns, drawdown and the Sharpe ratio see [returns and risk](functions-returns-risk.md).

**Example: Which share moved most? Volatility of the daily % change since 23 August** (sample data: sample)

```sql
SELECT symbol,
       count(chg) AS days,
       round(avg(chg), 3) AS avg_change_pct,
       round(stddev(chg), 3) AS volatility_pct
FROM (SELECT symbol, pct_change(close) OVER (PARTITION BY symbol ORDER BY time) AS chg
      FROM ochl_day
      WHERE time >= '2026-08-23') t
GROUP BY symbol
ORDER BY volatility_pct DESC;
```

Result:

| symbol (SYMBOL) | days (LONG) | avg_change_pct (DOUBLE) | volatility_pct (DOUBLE) |
|---|---|---|---|
| VOLT | 14 | 0.409 | 1.885 |
| COAST | 14 | -0.271 | 1.145 |
| CITY | 14 | -0.04 | 0.746 |

(3 rows)

<a id="stddev"></a>

## stddev, stddev_samp

Syntax:

```sql
stddev(x)
stddev_samp(x)
```

The **sample** standard deviation: the square root of `variance(x)`. It divides by `n - 1`. `stddev_samp` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values are skipped. With fewer than 2 values the result is `NULL`.
- **Notes:** the same as PostgreSQL and QuestDB `stddev`. About two thirds of normal values lie within one standard deviation of the average.

**Example: Spread of the close price per symbol in September** (sample data: sample)

```sql
SELECT symbol, count(*) AS days, round(avg(close), 2) AS avg_close,
       round(stddev(close), 3) AS stddev_close, round(stddev_samp(close), 3) AS same
FROM ochl_day
WHERE time IN '2026-09'
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | days (LONG) | avg_close (DOUBLE) | stddev_close (DOUBLE) | same (DOUBLE) |
|---|---|---|---|---|
| CITY | 8 | 500.18 | 3.317 | 3.317 |
| COAST | 8 | 374.73 | 4.534 | 4.534 |
| VOLT | 8 | 179.3 | 7.554 | 7.554 |

(3 rows)

**Example: Moving 5-day spread of CITY (with OVER)** (sample data: sample)

```sql
SELECT time, close,
       round(stddev(close) OVER (ORDER BY time ROWS 4 PRECEDING), 3) AS stddev_5d
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-01'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | stddev_5d (DOUBLE) |
|---|---|---|
| 2026-09-01T00:00:00.000Z | 502.4 | NULL |
| 2026-09-02T00:00:00.000Z | 496.4 | 4.243 |
| 2026-09-03T00:00:00.000Z | 497.9 | 3.122 |
| 2026-09-06T00:00:00.000Z | 499 | 2.55 |
| 2026-09-07T00:00:00.000Z | 498.7 | 2.211 |
| 2026-09-08T00:00:00.000Z | 497.5 | 1.032 |
| 2026-09-09T00:00:00.000Z | 504.6 | 2.892 |
| 2026-09-10T00:00:00.000Z | 504.9 | 3.525 |

(8 rows)

**Example: One value is not enough for a sample: NULL** (sample data: sample)

```sql
SELECT buyer, count(*) AS trades, stddev(rate) AS sample, stddev_pop(rate) AS population
FROM trade_log
WHERE symbol = 'VOLT'
GROUP BY buyer
ORDER BY buyer;
```

Result:

| buyer (INT) | trades (LONG) | sample (DOUBLE) | population (DOUBLE) |
|---|---|---|---|
| 1 | 2 | 2.12132034355964 | 1.5 |
| 34 | 1 | NULL | 0 |
| 58 | 1 | NULL | 0 |

(3 rows)

<a id="stddev_pop"></a>

## stddev_pop

Syntax:

```sql
stddev_pop(x)
```

The **population** standard deviation: the square root of `var_pop(x)`. It divides by `n`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values are skipped. One value gives `0`; no values give `NULL`.
- **Notes:** always a little smaller than `stddev` on the same values.

**Example: Sample and population on the same four numbers**

```sql
SELECT stddev(x) AS sample, stddev_pop(x) AS population, avg(x) AS average
FROM (SELECT 2 AS x UNION ALL SELECT 4 UNION ALL SELECT 4 UNION ALL SELECT 6) t;
```

Result:

| sample (DOUBLE) | population (DOUBLE) | average (DOUBLE) |
|---|---|---|
| 1.63299316185545 | 1.4142135623731 | 4 |

(1 row)

**Example: Spread of the trade rate of all trades of one day** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades, min(rate) AS low, max(rate) AS high,
       round(stddev_pop(rate), 3) AS rate_spread
FROM trade_log
WHERE date IN '2026-09-10'
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | trades (LONG) | low (DOUBLE) | high (DOUBLE) | rate_spread (DOUBLE) |
|---|---|---|---|---|
| CITY | 7 | 514.5 | 518 | 1.102 |
| COAST | 9 | 398 | 402 | 1.227 |
| TELCO | 4 | 878 | 883 | 1.785 |
| VOLT | 4 | 184 | 187 | 1.225 |

(4 rows)

<a id="variance"></a>

## variance, var_samp

Syntax:

```sql
variance(x)
var_samp(x)
```

The **sample** variance: the sum of the squared distances from the average, divided by `n - 1`. `var_samp` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |

- **Returns:** `DOUBLE`. Its unit is the square of the values' unit (dollars²), so `stddev` is easier to read.
- **NULL:** NULL values are skipped. With fewer than 2 values the result is `NULL`.
- **Notes:** `sqrt(variance(x))` is `stddev(x)`.

**Example: Variance and its square root** (sample data: sample)

```sql
SELECT symbol,
       round(variance(close), 3) AS variance,
       round(var_samp(close), 3) AS same,
       round(sqrt(variance(close)), 3) AS sqrt_variance,
       round(stddev(close), 3) AS stddev
FROM ochl_day
WHERE time IN '2026-09'
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | variance (DOUBLE) | same (DOUBLE) | sqrt_variance (DOUBLE) | stddev (DOUBLE) |
|---|---|---|---|---|
| CITY | 10.999 | 10.999 | 3.317 | 3.317 |
| COAST | 20.556 | 20.556 | 4.534 | 4.534 |
| VOLT | 57.063 | 57.063 | 7.554 | 7.554 |

(3 rows)

**Example: Text is not a number** (sample data: sample; shows an error)

```sql
SELECT variance(symbol) FROM ochl_day;
```

Result:

Error: `line 1, column 8: variance needs numbers, got 'CITY'`

<a id="var_pop"></a>

## var_pop

Syntax:

```sql
var_pop(x)
```

The **population** variance: the sum of the squared distances from the average, divided by `n`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values are skipped. One value gives `0`; no values give `NULL`.

**Example: Population and sample variance of daily volume** (sample data: sample)

```sql
SELECT symbol, count(*) AS days,
       round(var_pop(volume)) AS var_pop,
       round(variance(volume)) AS var_samp
FROM ochl_day
WHERE time IN '2026-09'
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | days (LONG) | var_pop (DOUBLE) | var_samp (DOUBLE) |
|---|---|---|---|
| CITY | 8 | 2308808698 | 2638638513 |
| COAST | 8 | 2403607398 | 2746979884 |
| VOLT | 8 | 1939635473 | 2216726255 |

(3 rows)

**Example: One value: population variance 0, sample variance NULL**

```sql
SELECT var_pop(x) AS population, var_samp(x) AS sample
FROM (SELECT 512.5 AS x) t;
```

Result:

| population (DOUBLE) | sample (STRING) |
|---|---|
| 0 | NULL |

(1 row)

<a id="skewness"></a>

## skewness, skew

Syntax:

```sql
skewness(x)
skew(x)
```

The **skewness** tells if the values lean to one side. A normal "bell curve" has skewness `0`: big values above and below the average are equally common.

- **Negative skewness:** the long tail is on the low side. For returns: most days are small gains, but now and then there is a **big fall**. This is crash risk.
- **Positive skewness:** the long tail is on the high side: now and then a big jump up (like a lottery).

It is the **sample** skewness, the same as Excel `SKEW`. `skew` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values, usually returns |

- **Returns:** `DOUBLE`. About `-0.5` to `0.5` is nearly balanced.
- **NULL:** NULL values are skipped. `NULL` with fewer than 3 values, and when all values are the same.
- **Notes:** a few very big values change it a lot, so use many values (hundreds of returns). `skewness_pop` is the version without the small-sample correction.

**Example: Shape of the one-minute returns of CITY and COAST** (sample data: sample)

```sql
SELECT symbol, count(r) AS returns,
       round(skewness(r), 3) AS skewness, round(kurtosis(r), 3) AS kurtosis,
       round(min(r), 4) AS worst_pct, round(max(r), 4) AS best_pct
FROM (SELECT symbol, ln(close / lag(close) OVER (PARTITION BY symbol ORDER BY time)) * 100 AS r
      FROM ochl_minutes) t
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | returns (LONG) | skewness (DOUBLE) | kurtosis (DOUBLE) | worst_pct (DOUBLE) | best_pct (DOUBLE) |
|---|---|---|---|---|---|
| CITY | 479 | -0.258 | -0.905 | -0.1197 | 0.0998 |
| COAST | 475 | -0.195 | -1.01 | -0.1605 | 0.1336 |

(2 rows)

**Example: One big value makes a long tail to the right: positive skewness**

```sql
SELECT round(skewness(x), 3) AS skewness, round(skew(x), 3) AS same, round(avg(x), 2) AS average, median(x) AS median
FROM (SELECT 1 AS x UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 10) t;
```

Result:

| skewness (DOUBLE) | same (DOUBLE) | average (DOUBLE) | median (DOUBLE) |
|---|---|---|---|
| 2.197 | 2.197 | 3.17 | 2 |

(1 row)

<a id="skewness_pop"></a>

## skewness_pop

Syntax:

```sql
skewness_pop(x)
```

The **population** skewness: the same idea as `skewness`, without the correction for a small number of values. It is always a little closer to 0 than `skewness`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values are skipped. `NULL` with no values, and when all values are the same (also one value). Two different values give `0`.
- **Notes:** use it when your rows are all the values there are; for returns, `skewness` is the usual choice.

**Example: Daily returns since 23 August: sample and population versions** (sample data: sample)

```sql
SELECT symbol, count(r) AS days,
       round(skewness(r), 3) AS skewness, round(skewness_pop(r), 3) AS skewness_pop
FROM (SELECT symbol, pct_change(close) OVER (PARTITION BY symbol ORDER BY time) AS r
      FROM ochl_day
      WHERE time >= '2026-08-23') t
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | days (LONG) | skewness (DOUBLE) | skewness_pop (DOUBLE) |
|---|---|---|---|
| CITY | 14 | -0.17 | -0.151 |
| COAST | 14 | 0.099 | 0.088 |
| VOLT | 14 | 0.178 | 0.158 |

(3 rows)

**Example: Two values: skewness needs 3, skewness_pop gives 0**

```sql
SELECT skewness(x) AS skewness, skewness_pop(x) AS skewness_pop
FROM (SELECT 1 AS x UNION ALL SELECT 2) t;
```

Result:

| skewness (STRING) | skewness_pop (DOUBLE) |
|---|---|
| NULL | 0 |

(1 row)

<a id="kurtosis"></a>

## kurtosis, kurt

Syntax:

```sql
kurtosis(x)
kurt(x)
```

The **kurtosis** tells how often **very big values** come, compared with a normal bell curve. KDB gives the **excess** kurtosis: a normal curve has `0`.

- **Positive kurtosis ("fat tails"):** very big moves, up or down, happen more often than a bell curve says. Most share returns are like this: a model that expects a normal curve under-guesses the risk of a crash day.
- **Negative kurtosis:** the values stay inside a band; very big moves are rare.

It is the **sample** excess kurtosis, the same as Excel `KURT`. `kurt` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values, usually returns |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values are skipped. `NULL` with fewer than 4 values, and when all values are the same.
- **Notes:** like skewness, it needs many values to mean something. `kurtosis_pop` is the version without the small-sample correction.

**Example: Fat tails? Kurtosis of the daily returns of every symbol** (sample data: sample)

```sql
SELECT symbol, count(r) AS days, round(kurtosis(r), 3) AS kurtosis, round(kurt(r), 3) AS same
FROM (SELECT symbol, pct_change(close) OVER (PARTITION BY symbol ORDER BY time) AS r
      FROM ochl_day
      WHERE time >= '2026-08-23') t
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | days (LONG) | kurtosis (DOUBLE) | same (DOUBLE) |
|---|---|---|---|
| CITY | 14 | 0.349 | 0.349 |
| COAST | 14 | -1.705 | -1.705 |
| VOLT | 14 | -1.753 | -1.753 |

(3 rows)

**Example: One value far away from the others: big kurtosis**

```sql
SELECT round(kurtosis(x), 3) AS kurtosis, round(kurtosis_pop(x), 3) AS kurtosis_pop
FROM (SELECT 1 AS x UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 10) t;
```

Result:

| kurtosis (DOUBLE) | kurtosis_pop (DOUBLE) |
|---|---|
| 5.015 | 0.862 |

(1 row)

<a id="kurtosis_pop"></a>

## kurtosis_pop

Syntax:

```sql
kurtosis_pop(x)
```

The **population** excess kurtosis: the same idea as `kurtosis`, without the correction for a small number of values.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |

- **Returns:** `DOUBLE`. Never below `-2`.
- **NULL:** NULL values are skipped. `NULL` with no values, and when all values are the same.

**Example: Three values: kurtosis needs 4, kurtosis_pop works**

```sql
SELECT kurtosis(x) AS kurtosis, kurtosis_pop(x) AS kurtosis_pop
FROM (SELECT 1 AS x UNION ALL SELECT 2 UNION ALL SELECT 3) t;
```

Result:

| kurtosis (STRING) | kurtosis_pop (DOUBLE) |
|---|---|
| NULL | -1.5 |

(1 row)

<a id="geomean"></a>

## geomean, geometric_mean

Syntax:

```sql
geomean(x)
geometric_mean(x)
```

The **geometric mean**: multiply all `n` values, then take the n-th root. It is the right average for **growth factors** (1.10 for +10%). If a price goes +10% and then -10%, the plain average of the changes is 0%, but you lost money: the geometric mean of 1.10 and 0.90 is 0.995, a loss of 0.5% per period. `geometric_mean` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number, more than 0 | the values, for example `nav / previous nav` |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values are skipped. No values give `NULL`. If **any** value is `0` or less, the result is `NULL`.
- **Notes:** for returns, use growth factors (`1 + return`), take the geometric mean, then subtract 1. It is always at or below `avg(x)`.

**Example: +10% then -10%: the average says 0, the geometric mean says a loss**

```sql
SELECT round(avg(g), 5) AS avg_factor, round(geomean(g), 5) AS geomean_factor
FROM (SELECT 1.10 AS g UNION ALL SELECT 0.90) t;
```

Result:

| avg_factor (DOUBLE) | geomean_factor (DOUBLE) |
|---|---|
| 1 | 0.99499 |

(1 row)

**Example: True average monthly growth of two funds** (sample data: sample, analysis-market)

```sql
SELECT fund, count(g) AS months,
       round(avg(g) - 1, 5) AS avg_growth,
       round(geometric_mean(g) - 1, 5) AS true_avg_growth
FROM (SELECT fund, nav / lag(nav) OVER (PARTITION BY fund ORDER BY time) AS g
      FROM fund_nav) t
GROUP BY fund
ORDER BY fund;
```

Result:

| fund (SYMBOL) | months (LONG) | avg_growth (DOUBLE) | true_avg_growth (DOUBLE) |
|---|---|---|---|
| GROWTH | 23 | 0.00886 | 0.00861 |
| INCOME | 23 | 0.00328 | 0.00327 |

(2 rows)

**Example: A 0 or a negative value gives NULL**

```sql
SELECT geomean(x) AS geomean
FROM (SELECT 2 AS x UNION ALL SELECT 0 UNION ALL SELECT 8) t;
```

Result:

| geomean (STRING) |
|---|
| NULL |

(1 row)

<a id="harmonic_mean"></a>

## harmonic_mean

Syntax:

```sql
harmonic_mean(x)
```

The **harmonic mean**: `n / sum(1 / x)`. It is the right average for **rates and prices when the money is fixed**. If you invest the same amount every month (a SIP), you buy more units when the price is low, and your **average cost per unit** is the harmonic mean of the prices. It is also the usual average of P/E ratios.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number, more than 0 | the values |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values are skipped. No values give `NULL`. If **any** value is `0` or less, the result is `NULL`.
- **Notes:** always at or below `geomean(x)`, which is at or below `avg(x)`.

**Example: Average cost per unit with the same money every month for a year** (sample data: sample, analysis-market)

```sql
SELECT fund, count(*) AS months,
       round(harmonic_mean(nav), 4) AS avg_cost_per_unit,
       round(avg(nav), 4) AS avg_nav
FROM fund_nav
WHERE time >= '2025-09-01'
GROUP BY fund
ORDER BY fund;
```

Result:

| fund (SYMBOL) | months (LONG) | avg_cost_per_unit (DOUBLE) | avg_nav (DOUBLE) |
|---|---|---|---|
| GROWTH | 12 | 11.4256 | 11.4375 |
| INCOME | 12 | 10.5647 | 10.5658 |

(2 rows)

**Example: Average P/E of three shares**

```sql
SELECT round(harmonic_mean(pe), 2) AS harmonic, round(geomean(pe), 2) AS geometric, round(avg(pe), 2) AS plain
FROM (SELECT 10 AS pe UNION ALL SELECT 20 UNION ALL SELECT 40) t;
```

Result:

| harmonic (DOUBLE) | geometric (DOUBLE) | plain (DOUBLE) |
|---|---|---|
| 17.14 | 20 | 23.33 |

(1 row)

## mode

Syntax:

```sql
mode(x)
mode() WITHIN GROUP (ORDER BY x)
```

The **most common value**: the value that comes in the most rows. It works for numbers, text and times.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the values |

- **Returns:** the same type as `x`: one of the values.
- **NULL:** NULL values are skipped (they are never the answer). No values give `NULL`.
- **Notes:** when two values are equally common, the **smallest** one wins (for text: first in alphabet order). Equal numbers of different types count as one value (`1` and `1.0`). The `WITHIN GROUP` form is the PostgreSQL way to write the same thing ([WITHIN GROUP](#within-group)).

**Example: Most common trade size of each symbol** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades, mode(quantity) AS most_common_quantity
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | trades (LONG) | most_common_quantity (LONG) |
|---|---|---|
| CITY | 11 | 500 |
| COAST | 11 | 20 |
| TELCO | 6 | 1000 |
| VOLT | 4 | 50 |

(4 rows)

**Example: City with the most app users (Kathmandu and Pokhara tie: the smallest wins)** (sample data: query-app)

```sql
SELECT mode(city) AS top_city, count(city) AS users_with_city
FROM app_users;

SELECT city, count(*) AS users FROM app_users WHERE city IS NOT NULL GROUP BY city ORDER BY users DESC, city;
```

Result:

`SELECT mode(city) AS top_city, count(city) AS users_with_city FROM app_users`

| top_city (STRING) | users_with_city (LONG) |
|---|---|
| Kathmandu | 6 |

(1 row)

`SELECT city, count(*) AS users FROM app_users WHERE city IS NOT NULL GROUP BY city ORDER BY users DE`

| city (STRING) | users (LONG) |
|---|---|
| Kathmandu | 2 |
| Pokhara | 2 |
| Dharan | 1 |
| Lalitpur | 1 |

(4 rows)

<a id="percentile_cont"></a>

## percentile_cont, quantile_cont

Syntax:

```sql
percentile_cont(x, fraction)
percentile_cont(fraction) WITHIN GROUP (ORDER BY x)
quantile_cont(x, fraction)
```

The **continuous percentile**: the value below which the part `fraction` of the values lie. `percentile_cont(x, 0.9)` is the value that 90% of the values are at or below. Between two values it goes the right part of the way from one to the other (linear interpolation), so the answer may be a value that is not in the data. `quantile_cont` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |
| `fraction` | number from `0` to `1` | the part: `0.5` is the median, `0.9` the 90th percentile |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values of `x` are skipped. No values give `NULL`. A NULL `fraction` gives `NULL`.
- **Notes:** the same numbers as [percentile](functions-aggregate.md#percentile) and PostgreSQL `percentile_cont`, but strict: `fraction` must be from 0 to 1 (`90` is an error, not 90%). `fraction` is read once, from the first row. A `DOUBLE` result can show a tiny rounding rest (`950.000000000001`): use `round`.

**Example: Big trades: 90th percentile of the quantity per symbol** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades,
       round(percentile_cont(quantity, 0.5), 1) AS median_qty,
       round(percentile_cont(quantity, 0.9), 1) AS p90_qty,
       max(quantity) AS biggest
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | trades (LONG) | median_qty (DOUBLE) | p90_qty (DOUBLE) | biggest (LONG) |
|---|---|---|---|---|
| CITY | 11 | 100 | 500 | 500 |
| COAST | 11 | 50 | 1000 | 1000 |
| TELCO | 6 | 350 | 1000 | 1000 |
| VOLT | 4 | 75 | 170 | 200 |

(4 rows)

**Example: The same with the SQL standard spelling** (sample data: sample)

```sql
SELECT round(percentile_cont(0.9) WITHIN GROUP (ORDER BY quantity), 1) AS p90,
       round(quantile_cont(quantity, 0.9), 1) AS same
FROM trade_log;
```

Result:

| p90 (DOUBLE) | same (DOUBLE) |
|---|---|
| 950 | 950 |

(1 row)

**Example: The fraction must be from 0 to 1** (sample data: sample; shows an error)

```sql
SELECT percentile_cont(rate, 90) FROM trade_log;
```

Result:

Error: `line 1, column 8: percentile_cont: the fraction must be between 0 and 1, like 0.9, got 90`

<a id="percentile_disc"></a>

## percentile_disc, quantile_disc

Syntax:

```sql
percentile_disc(x, fraction)
percentile_disc(fraction) WITHIN GROUP (ORDER BY x)
quantile_disc(x, fraction)
```

The **discrete percentile**: the first value, in sorted order, at or above which the part `fraction` of the values lie. Unlike `percentile_cont`, the answer is always **one of the values**, never a value in between. So it also works for text and times. `quantile_disc` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type that can be sorted | the values: numbers, text, times |
| `fraction` | number from `0` to `1` | the part; `0` gives the smallest value, `1` the biggest |

- **Returns:** the same type as `x`.
- **NULL:** NULL values of `x` are skipped. No values give `NULL`. A NULL `fraction` gives `NULL`.
- **Notes:** with `n` values it takes the value at place `ceil(fraction × n)` in sorted order. Values that cannot be compared with each other (a number and a text) give an error.

**Example: Discrete and continuous 25th percentile of the trade rate** (sample data: sample)

```sql
SELECT symbol,
       percentile_disc(rate, 0.25) AS p25_disc,
       percentile_cont(rate, 0.25) AS p25_cont
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | p25_disc (DOUBLE) | p25_cont (DOUBLE) |
|---|---|---|
| CITY | 514.5 | 514.75 |
| COAST | 398 | 398.25 |
| TELCO | 879 | 879.5 |
| VOLT | 184 | 184 |

(4 rows)

**Example: The middle sign-up time of the app users (a TIMESTAMP)** (sample data: query-app)

```sql
SELECT percentile_disc(created_at, 0.5) AS middle_signup, quantile_disc(username, 0.5) AS middle_username
FROM app_users;
```

Result:

| middle_signup (TIMESTAMP) | middle_username (STRING) |
|---|---|
| 2026-03-20T13:00:00.000Z | hari_99 |

(1 row)

<a id="within-group"></a>

## WITHIN GROUP (ORDER BY ...)

Syntax:

```sql
percentile_cont(fraction) WITHIN GROUP (ORDER BY x)
percentile_disc(fraction) WITHIN GROUP (ORDER BY x)
mode() WITHIN GROUP (ORDER BY x)
```

The SQL standard (PostgreSQL) way to write `percentile_cont`, `percentile_disc` and `mode`. KDB reads `percentile_cont(0.9) WITHIN GROUP (ORDER BY x)` as `percentile_cont(x, 0.9)`, so both spellings give the same result. It helps when you copy SQL from PostgreSQL.

| Part | Meaning |
|---|---|
| `fraction` | the part from `0` to `1` (not for `mode`, which has empty `()`) |
| `ORDER BY x` | the values; exactly one, in ascending order |

- **Works with:** `percentile_cont`, `percentile_disc`, `quantile_cont`, `quantile_disc` and `mode`. Other functions give an error.
- **Notes:** `DESC` is not accepted: for the 90th percentile from the top, use `1 - 0.9 = 0.1`. Several values in `ORDER BY` are not accepted.

**Example: Volume of CITY's one-minute candles on 10 September** (sample data: sample)

```sql
SELECT percentile_cont(0.9) WITHIN GROUP (ORDER BY volume) AS p90,
       percentile_disc(0.9) WITHIN GROUP (ORDER BY volume) AS p90_disc,
       mode() WITHIN GROUP (ORDER BY volume) AS most_common
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10';
```

Result:

| p90 (DOUBLE) | p90_disc (DOUBLE) | most_common (DOUBLE) |
|---|---|---|
| 1341 | 1340 | 880 |

(1 row)

**Example: DESC is not accepted: use 1 - fraction** (sample data: sample; shows an error)

```sql
SELECT percentile_cont(0.1) WITHIN GROUP (ORDER BY rate DESC) FROM trade_log;
```

Result:

Error: `line 1, column 52: WITHIN GROUP needs exactly one ORDER BY value in ascending order (for DESC use 1 - fraction)`

**Example: Only percentiles and mode have WITHIN GROUP** (sample data: sample; shows an error)

```sql
SELECT avg(quantity) WITHIN GROUP (ORDER BY quantity) FROM trade_log;
```

Result:

Error: `line 1, column 22: WITHIN GROUP works with percentile_cont(fraction), percentile_disc(fraction) and mode(); write percentile_cont(0.5) WITHIN GROUP (ORDER BY x)`

<a id="median_abs_deviation"></a>

## median_abs_deviation, mad

Syntax:

```sql
median_abs_deviation(x)
mad(x)
```

The **median absolute deviation (MAD)**: first find the median, then the distance of every value from it, then the median of those distances. It is a measure of spread, like `stddev`, but **robust**: one huge trade or one wrong price hardly moves it. So it is good to find **outliers** (values far away from the rest). `mad` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values are skipped. No values give `NULL`.
- **Notes:** the raw MAD, without a scale factor. For values from a bell curve, `1.4826 × mad(x)` is about `stddev(x)`.

**Example: Spread of the trade size: stddev against the robust measures** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades, median(quantity) AS median_qty,
       mad(quantity) AS mad_qty, iqr(quantity) AS iqr_qty, round(stddev(quantity), 1) AS stddev_qty
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | trades (LONG) | median_qty (DOUBLE) | mad_qty (DOUBLE) | iqr_qty (DOUBLE) | stddev_qty (DOUBLE) |
|---|---|---|---|---|---|
| CITY | 11 | 100 | 90 | 480 | 228.3 |
| COAST | 11 | 50 | 40 | 330 | 384.6 |
| TELCO | 6 | 350 | 315 | 787.5 | 450.4 |
| VOLT | 4 | 75 | 25 | 75 | 70.7 |

(4 rows)

**Example: Unusual trades: more than 5 MADs above the median of their symbol** (sample data: sample)

```sql
SELECT f.transaction_id, f.symbol, f.quantity, s.median_qty, s.mad_qty
FROM trade_log f
JOIN (SELECT symbol, median(quantity) AS median_qty, median_abs_deviation(quantity) AS mad_qty
      FROM trade_log
      GROUP BY symbol) s ON f.symbol = s.symbol
WHERE f.quantity > s.median_qty + 5 * s.mad_qty
ORDER BY f.transaction_id;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | quantity (LONG) | median_qty (DOUBLE) | mad_qty (DOUBLE) |
|---|---|---|---|---|
| 100015 | COAST | 1000 | 50 | 40 |
| 100023 | COAST | 500 | 50 | 40 |
| 100031 | COAST | 1000 | 50 | 40 |

(3 rows)

## iqr

Syntax:

```sql
iqr(x)
```

The **interquartile range**: the 75th percentile minus the 25th percentile. The middle half of all values lies in this band. Like `mad`, the biggest and smallest values do not change it.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values are skipped. No values give `NULL`.
- **Notes:** the same as `percentile_cont(x, 0.75) - percentile_cont(x, 0.25)`. A common outlier rule: below `Q1 - 1.5 × iqr` or above `Q3 + 1.5 × iqr` (this is the box plot rule).

**Example: Middle half of the one-minute volume on 10 September** (sample data: sample)

```sql
SELECT symbol,
       percentile_cont(volume, 0.25) AS q1,
       percentile_cont(volume, 0.75) AS q3,
       iqr(volume) AS iqr
FROM ochl_minutes
WHERE time IN '2026-09-10'
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | q1 (DOUBLE) | q3 (DOUBLE) | iqr (DOUBLE) |
|---|---|---|---|
| CITY | 390 | 1112.5 | 722.5 |
| COAST | 400 | 1192.5 | 792.5 |

(2 rows)

## range

Syntax:

```sql
range(x)
range(x) OVER (...)
```

The biggest value minus the smallest: `max(x) - min(x)`. For prices it is the **high-low range**: how far the price travelled.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number, `TIMESTAMP` or `DATE` | the values |

- **Returns:** `LONG` for whole numbers, `DECIMAL` for `DECIMAL`, `DOUBLE` for other numbers. For `TIMESTAMP` values: the milliseconds between the first and the last time (`LONG`); for `DATE` values: the number of days (`LONG`).
- **NULL:** NULL values are skipped. No values give `NULL`.
- **Notes:** text gives the error `needs numbers or times`. The name is also a keyword of window frames (`RANGE BETWEEN`); as a function, `range(x)` works as usual.

**Example: Price range and time span of each symbol** (sample data: sample)

```sql
SELECT symbol, range(close) AS close_range, range(time) / 86400000 AS days_between_first_and_last
FROM ochl_day
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | close_range (DOUBLE) | days_between_first_and_last (DOUBLE) |
|---|---|---|
| CITY | 46 | 256 |
| COAST | 59.4 | 256 |
| VOLT | 27.4 | 256 |

(3 rows)

**Example: Moving 5-day range of the close (with OVER)** (sample data: sample)

```sql
SELECT time, close, round(range(close) OVER (ORDER BY time ROWS 4 PRECEDING), 2) AS range_5d
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-01'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | range_5d (DOUBLE) |
|---|---|---|
| 2026-09-01T00:00:00.000Z | 502.4 | 0 |
| 2026-09-02T00:00:00.000Z | 496.4 | 6 |
| 2026-09-03T00:00:00.000Z | 497.9 | 6 |
| 2026-09-06T00:00:00.000Z | 499 | 6 |
| 2026-09-07T00:00:00.000Z | 498.7 | 6 |
| 2026-09-08T00:00:00.000Z | 497.5 | 2.6 |
| 2026-09-09T00:00:00.000Z | 504.6 | 7.1 |
| 2026-09-10T00:00:00.000Z | 504.9 | 7.4 |

(8 rows)

**Example: DATE values give days** (sample data: fn-dates)

```sql
SELECT min(listed_on) AS oldest, max(listed_on) AS newest, range(listed_on) AS days_between
FROM listings;
```

Result:

| oldest (DATE) | newest (DATE) | days_between (LONG) |
|---|---|---|
| 1986-01-01 | 2019-08-28 | 12292 |

(1 row)

<a id="sum_of_squares"></a>

## sum_of_squares

Syntax:

```sql
sum_of_squares(x)
```

Adds up the square of every value: `x₁² + x₂² + ...`. On intraday log returns, the square root of this sum is the **realized volatility** of the day: how much the price really moved, minute by minute.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any number | the values |

- **Returns:** `DOUBLE`.
- **NULL:** NULL values are skipped. No values give `NULL`.
- **Notes:** it squares the values themselves, not their distance from the average (that is `regr_syy` or `var_pop(x) × count(x)`).

**Example: Realized volatility of each day from one-minute log returns (in %)** (sample data: sample)

```sql
SELECT time, symbol, count(r) AS returns, round(sqrt(sum_of_squares(r)), 4) AS realized_vol_pct
FROM (SELECT time, symbol,
             ln(close / lag(close) OVER (PARTITION BY symbol, date_trunc('day', time) ORDER BY time)) * 100 AS r
      FROM ochl_minutes) t
SAMPLE BY 1d
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | returns (LONG) | realized_vol_pct (DOUBLE) |
|---|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 239 | 1.0082 |
| 2026-09-10T00:00:00.000Z | CITY | 239 | 1.022 |
| 2026-09-09T00:00:00.000Z | COAST | 239 | 1.4068 |
| 2026-09-10T00:00:00.000Z | COAST | 235 | 1.4162 |

(4 rows)

**Example: NULL values are skipped**

```sql
SELECT sum_of_squares(x) AS sum_of_squares
FROM (SELECT 1.5 AS x UNION ALL SELECT NULL UNION ALL SELECT -2) t;
```

Result:

| sum_of_squares (DOUBLE) |
|---|
| 6.25 |

(1 row)

## entropy

Syntax:

```sql
entropy(x)
```

The **Shannon entropy** of the values, in bits: how **evenly** the rows are spread over the different values. `0` means every row has the same value. The biggest entropy comes when every value is equally common: with `k` different values it is `log2(k)` (2 values: 1, 4 values: 2). Use it to see if the trades of a share come from many brokers or from a few.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the values: numbers, text, times |

- **Returns:** `DOUBLE`, `0` or more.
- **NULL:** NULL values are skipped. No values give `NULL`.
- **Notes:** it is `-sum(p × log2(p))`, where `p` is the share of rows with each value.

**Example: Are the buyers of each share spread out or few?** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades, approx_count_distinct(buyer) AS buyers,
       round(entropy(buyer), 3) AS buyer_entropy, round(log2(approx_count_distinct(buyer)), 3) AS most_possible
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | trades (LONG) | buyers (LONG) | buyer_entropy (DOUBLE) | most_possible (DOUBLE) |
|---|---|---|---|---|
| CITY | 11 | 4 | 1.79 | 2 |
| COAST | 11 | 5 | 2.187 | 2.322 |
| TELCO | 6 | 5 | 2.252 | 2.322 |
| VOLT | 4 | 3 | 1.5 | 1.585 |

(4 rows)

**Example: How evenly are the app users spread over the plans?** (sample data: query-app)

```sql
SELECT round(entropy(plan), 3) AS plan_entropy, approx_count_distinct(plan) AS plans, count(*) AS users
FROM app_users;
```

Result:

| plan_entropy (DOUBLE) | plans (LONG) | users (LONG) |
|---|---|---|
| 1.406 | 3 | 8 |

(1 row)

**Example: All rows the same: entropy 0**

```sql
SELECT entropy(x) AS entropy
FROM (SELECT 'CITY' AS x UNION ALL SELECT 'CITY') t;
```

Result:

| entropy (DOUBLE) |
|---|
| 0 |

(1 row)

<a id="approx_count_distinct"></a>

## approx_count_distinct

Syntax:

```sql
approx_count_distinct(x)
```

The number of **different** values of `x`. Other databases (DuckDB, ClickHouse, BigQuery) guess this number to save memory. In KDB today the count is **exact**: it gives the same result as `count(DISTINCT x)`. The name exists so SQL from those databases works.

| Argument | Type | Meaning |
|---|---|---|
| `x` | any type | the values |

- **Returns:** `LONG`.
- **NULL:** NULL values are not counted. No values give `0`.
- **Notes:** equal numbers of different types count as one value (`1` and `1.0`). KDB keeps every different value in memory while it counts.

**Example: Different buyers and sellers of each share** (sample data: sample)

```sql
SELECT symbol, approx_count_distinct(buyer) AS buyers, count(DISTINCT buyer) AS same,
       approx_count_distinct(seller) AS sellers
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | buyers (LONG) | same (LONG) | sellers (LONG) |
|---|---|---|---|
| CITY | 4 | 4 | 5 |
| COAST | 5 | 5 | 5 |
| TELCO | 5 | 5 | 3 |
| VOLT | 3 | 3 | 4 |

(4 rows)

**Example: No rows: 0 (entropy and mode give NULL)** (sample data: sample)

```sql
SELECT approx_count_distinct(buyer) AS buyers, entropy(buyer) AS entropy, mode(buyer) AS mode
FROM trade_log
WHERE symbol = 'NONE';
```

Result:

| buyers (LONG) | entropy (STRING) | mode (STRING) |
|---|---|---|
| 0 | NULL | NULL |

(1 row)
