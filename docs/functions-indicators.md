# Technical indicators

> Moving averages (SMA, EMA, WMA, DEMA, TEMA, TRIMA, KAMA, HMA, VWMA), RSI and ATR on candles, per symbol, with the same results as TA-Lib.

- Category: Functions — technical indicators
- Keywords: indicator, technical analysis, TA-Lib, trading, chart, trend, momentum, volatility, moving average, MA, simple moving average, SMA, exponential moving average, EMA, weighted moving average, WMA, linear weighted moving average, double exponential moving average, DEMA, triple exponential moving average, TEMA, triangular moving average, TRIMA, Kaufman adaptive moving average, KAMA, adaptive moving average, efficiency ratio, Hull moving average, Hull, HMA, volume weighted moving average, VWMA, lag, relative strength index, RSI, overbought, oversold, average true range, ATR, true range, stop loss, crossover, golden cross, death cross, warm-up, period, vwap, volume weighted average price, stock market
- See also: [Momentum indicators](functions-indicators-momentum.md), [Volatility indicators and bands](functions-indicators-volatility.md), [Trend indicators](functions-indicators-trend.md), [Volume indicators](functions-indicators-volume.md), [Returns and risk](functions-returns-risk.md), [Window and series functions](functions-window.md), [Aggregate functions (vwap)](functions-aggregate.md#vwap), [Statistics functions](functions-statistics.md), [SAMPLE BY](sample-by.md), [Candles cookbook](candles-cookbook.md)

A **technical indicator** is a number made from past prices. Traders draw it on the chart next to the candles to see the **trend** (is the price going up?), the **momentum** (how strong is the move?) and the **volatility** (how big are the moves?). The price data is usually candles: `open`, `high`, `low`, `close`, `volume` per day or per minute.

The indicators are **series functions** ([window and series functions](functions-window.md)). They give a value for every candle, and they follow these rules:

- **Order:** without `OVER`, all result rows are one series in time order. With **many symbols**, always write `OVER (PARTITION BY symbol ORDER BY time)`, or the prices of different symbols mix.
- **Period:** `n` is the number of candles the indicator looks back, a whole number of 1 or more (`sma(close, 20)` is the 20-day average on daily candles).
- **Warm-up:** at the start of a series there are not enough candles yet, and the result is `NULL`:

| Function | First value on candle | NULL candles at the start |
|---|---|---|
| `sma(x, n)` | n | n - 1 |
| `ema(x, n)` | n | n - 1 |
| `wma(x, n)` | n | n - 1 |
| `trima(x, n)` | n | n - 1 |
| `vwma(price, volume, n)` | n | n - 1 |
| `kama(x, n)` | n + 1 | n |
| `hma(x, n)` | n + √n - 1 (√n rounded down) | n + √n - 2 |
| `dema(x, n)` | 2n - 1 | 2n - 2 |
| `tema(x, n)` | 3n - 2 | 3n - 3 |
| `rsi(x, n)` | n + 1 | n |
| `atr(high, low, close, n)` | n + 1 | n |

- **WHERE runs first:** the indicator only sees the rows that `WHERE` keeps. To show the last 5 days of a 20-day average, compute it on more history in a subquery, and filter outside.
- **Candles from SAMPLE BY or GROUP BY:** make the candles in a subquery, and put the indicator outside. An indicator in the same `SELECT` as `SAMPLE BY` is an error.
- **Same as TA-Lib:** `ema` starts with the SMA of the first `n` values; `rsi` and `atr` use Wilder's smoothing. The numbers match TA-Lib and most charting programs. `wma`, `dema`, `tema`, `trima` and `kama` match TA-Lib too. `hma` (Alan Hull's formula) and `vwma` (TradingView's `ta.vwma`) are not in TA-Lib.
- **Returns** `DOUBLE`. Use `round(x, 2)` for prices.

For the **volume-weighted average price** of a day or a candle, use the aggregate [vwap](functions-aggregate.md#vwap); with `OVER (... ROWS n PRECEDING)` it becomes a moving VWAP.

**More indicators** (they follow the same rules):

- [Momentum indicators](functions-indicators-momentum.md): MACD, stochastic, stochastic RSI, Williams %R, CCI, ROC, momentum, TRIX.
- [Volatility and bands](functions-indicators-volatility.md): true range, NATR, Bollinger bands, Keltner channels, Donchian channels.
- [Trend indicators](functions-indicators-trend.md): DMI and ADX, Aroon, parabolic SAR, Ichimoku, SuperTrend, linear regression, Heikin-Ashi candles.
- [Volume indicators](functions-indicators-volume.md): OBV, A/D line, CMF, Chaikin oscillator, MFI, force index, ease of movement.
- [Returns and risk](functions-returns-risk.md): returns, drawdown, volatility, Sharpe ratio and more.

**Example: All four indicators on COAST's daily candles** (sample data: sample)

```sql
SELECT time, close,
       round(sma(close, 5), 2) AS sma5,
       round(ema(close, 5), 2) AS ema5,
       round(rsi(close, 5), 1) AS rsi5,
       round(atr(high, low, close, 5), 2) AS atr5
FROM ochl_day
WHERE symbol = 'COAST' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | sma5 (DOUBLE) | ema5 (DOUBLE) | rsi5 (DOUBLE) | atr5 (DOUBLE) |
|---|---|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 391 | NULL | NULL | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 384.9 | NULL | NULL | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 379.8 | NULL | NULL | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 373 | NULL | NULL | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 367.1 | 379.16 | 379.16 | NULL | NULL |
| 2026-08-30T00:00:00.000Z | 372.4 | 375.44 | 376.91 | 18.2 | 8.92 |
| 2026-08-31T00:00:00.000Z | 368.2 | 372.1 | 374 | 15.4 | 9.04 |
| 2026-09-01T00:00:00.000Z | 367.4 | 369.62 | 371.8 | 14.8 | 7.87 |
| 2026-09-02T00:00:00.000Z | 369.2 | 368.86 | 370.94 | 22.5 | 7.08 |
| 2026-09-03T00:00:00.000Z | 373.2 | 370.08 | 371.69 | 37.9 | 7.56 |
| 2026-09-06T00:00:00.000Z | 375.4 | 370.68 | 372.93 | 45.4 | 7.25 |
| 2026-09-07T00:00:00.000Z | 379.2 | 372.88 | 375.02 | 56.7 | 7.38 |
| 2026-09-08T00:00:00.000Z | 377.2 | 374.84 | 375.75 | 49.9 | 7 |
| 2026-09-09T00:00:00.000Z | 380.1 | 377.02 | 377.2 | 58.8 | 9.92 |
| 2026-09-10T00:00:00.000Z | 376.1 | 377.6 | 376.83 | 45 | 9.7 |

(15 rows)

**Example: An indicator on a raw column with SAMPLE BY: an error** (sample data: sample; shows an error)

```sql
SELECT time, last(close) AS close, sma(close, 4) AS sma4
FROM ochl_minutes
WHERE symbol = 'COAST'
SAMPLE BY 15m;
```

Result:

Error: `line 1, column 40: column 'close' is used by a window function in a query with aggregates, so it must be a key of the groups: add it to the SELECT list or to GROUP BY`

**Example: Right: 15-minute candles inside, indicators outside** (sample data: sample)

```sql
SELECT time, close, round(sma(close, 4), 2) AS sma4, round(rsi(close, 4), 1) AS rsi4
FROM (SELECT time, last(close) AS close
      FROM ochl_minutes
      WHERE symbol = 'COAST' AND time IN '2026-09-10'
      SAMPLE BY 15m) c
ORDER BY time
LIMIT 8;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | sma4 (DOUBLE) | rsi4 (DOUBLE) |
|---|---|---|---|
| 2026-09-10T05:15:00.000Z | 381.7 | NULL | NULL |
| 2026-09-10T05:30:00.000Z | 380.2 | NULL | NULL |
| 2026-09-10T05:45:00.000Z | 379.7 | NULL | NULL |
| 2026-09-10T06:00:00.000Z | 381.3 | 380.73 | NULL |
| 2026-09-10T06:15:00.000Z | 379.6 | 380.2 | 30.2 |
| 2026-09-10T06:30:00.000Z | 379.9 | 380.13 | 35.1 |
| 2026-09-10T06:45:00.000Z | 379.2 | 380 | 28.8 |
| 2026-09-10T07:00:00.000Z | 378.4 | 379.28 | 22.6 |

(8 rows)

## sma

Syntax:

```sql
sma(x, n)
sma(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **simple moving average**: the average of the last `n` values (this candle and the `n - 1` before it). A 20-day SMA smooths out the daily noise and shows the trend. When the price is above its SMA, the trend is usually up; below, down. When a short SMA crosses above a long SMA, traders call it a buy signal (a "golden cross").

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | how many candles to average |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles. A NULL value makes the `n` results whose window holds it `NULL`; after that the SMA comes back.
- **Notes:** unlike `avg(x) OVER (... ROWS n-1 PRECEDING)`, which averages fewer values at the start, `sma` waits until it has `n` values. `ROWS` inside `OVER` is ignored for `sma`.

**Example: Is VOLT above its 5-day average?** (sample data: sample)

```sql
SELECT time, close, round(sma(close, 5), 2) AS sma5,
       CASE WHEN close > sma(close, 5) THEN 'above'
            WHEN close < sma(close, 5) THEN 'below' END AS trend
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | sma5 (DOUBLE) | trend (STRING) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 181 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 178.5 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 176.8 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 174.2 | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 173.3 | 176.76 | below |
| 2026-08-30T00:00:00.000Z | 173 | 175.16 | below |
| 2026-08-31T00:00:00.000Z | 172.6 | 173.98 | below |
| 2026-09-01T00:00:00.000Z | 169 | 172.42 | below |
| 2026-09-02T00:00:00.000Z | 171.5 | 171.88 | below |
| 2026-09-03T00:00:00.000Z | 176 | 172.42 | above |
| 2026-09-06T00:00:00.000Z | 180.1 | 173.84 | above |
| 2026-09-07T00:00:00.000Z | 176.9 | 174.7 | above |
| 2026-09-08T00:00:00.000Z | 182.4 | 177.38 | above |
| 2026-09-09T00:00:00.000Z | 187.3 | 180.54 | above |
| 2026-09-10T00:00:00.000Z | 191.2 | 183.58 | above |

(15 rows)

**Example: 3-day SMA of every symbol (PARTITION BY symbol)** (sample data: sample)

```sql
SELECT time, symbol, close,
       round(sma(close, 3) OVER (PARTITION BY symbol ORDER BY time), 2) AS sma3
FROM ochl_day
WHERE time >= '2026-09-06'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | sma3 (DOUBLE) |
|---|---|---|---|
| 2026-09-06T00:00:00.000Z | CITY | 499 | NULL |
| 2026-09-07T00:00:00.000Z | CITY | 498.7 | NULL |
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | 498.4 |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 500.27 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 502.33 |
| 2026-09-06T00:00:00.000Z | COAST | 375.4 | NULL |
| 2026-09-07T00:00:00.000Z | COAST | 379.2 | NULL |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | 377.27 |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 378.83 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 377.8 |
| 2026-09-06T00:00:00.000Z | VOLT | 180.1 | NULL |
| 2026-09-07T00:00:00.000Z | VOLT | 176.9 | NULL |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | 179.8 |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 182.2 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 186.97 |

(15 rows)

**Example: Moving average crossover: buy and sell signals (3-day against 5-day)** (sample data: sample)

```sql
SELECT time, symbol, close, fast, slow,
       CASE WHEN fast > slow THEN 'BUY' ELSE 'SELL' END AS signal
FROM (SELECT time, symbol, close, fast, slow,
             lag(fast) OVER (PARTITION BY symbol ORDER BY time) AS prev_fast,
             lag(slow) OVER (PARTITION BY symbol ORDER BY time) AS prev_slow
      FROM (SELECT time, symbol, close,
                   round(sma(close, 3) OVER (PARTITION BY symbol ORDER BY time), 2) AS fast,
                   round(sma(close, 5) OVER (PARTITION BY symbol ORDER BY time), 2) AS slow
            FROM ochl_day
            WHERE time >= '2026-08-23') a) b
WHERE (fast > slow AND prev_fast <= prev_slow) OR (fast < slow AND prev_fast >= prev_slow)
ORDER BY time, symbol;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | fast (DOUBLE) | slow (DOUBLE) | signal (STRING) |
|---|---|---|---|---|---|
| 2026-08-30T00:00:00.000Z | CITY | 503.1 | 507.4 | 509.16 | SELL |
| 2026-09-06T00:00:00.000Z | COAST | 375.4 | 372.6 | 370.68 | BUY |
| 2026-09-06T00:00:00.000Z | VOLT | 180.1 | 175.87 | 173.84 | BUY |
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | 498.4 | 497.9 | BUY |

(4 rows)

**Example: WHERE runs first: compute on all history, then keep the last 3 days** (sample data: sample)

```sql
SELECT time, close, round(sma(close, 3), 2) AS sma3_only_3_rows
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-08'
ORDER BY time;

SELECT time, close, sma3
FROM (SELECT time, close, round(sma(close, 3), 2) AS sma3 FROM ochl_day WHERE symbol = 'CITY') t
WHERE time >= '2026-09-08'
ORDER BY time;
```

Result:

`SELECT time, close, round(sma(close, 3), 2) AS sma3_only_3_rows FROM ochl_day WHERE symbol = 'CITY' `

| time (TIMESTAMP) | close (DOUBLE) | sma3_only_3_rows (DOUBLE) |
|---|---|---|
| 2026-09-08T00:00:00.000Z | 497.5 | NULL |
| 2026-09-09T00:00:00.000Z | 504.6 | NULL |
| 2026-09-10T00:00:00.000Z | 504.9 | 502.33 |

(3 rows)

`SELECT time, close, sma3 FROM (SELECT time, close, round(sma(close, 3), 2) AS sma3 FROM ochl_day WHE`

| time (TIMESTAMP) | close (DOUBLE) | sma3 (DOUBLE) |
|---|---|---|
| 2026-09-08T00:00:00.000Z | 497.5 | 498.4 |
| 2026-09-09T00:00:00.000Z | 504.6 | 500.27 |
| 2026-09-10T00:00:00.000Z | 504.9 | 502.33 |

(3 rows)

**Example: The period must be 1 or more** (sample data: sample; shows an error)

```sql
SELECT sma(close, 0) FROM ochl_day;
```

Result:

Error: `line 1, column 8: sma: the period must be a whole number of rows (1 or more)`

## ema

Syntax:

```sql
ema(x, n)
ema(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **exponential moving average**. Like the SMA, it smooths prices, but new prices count more than old ones, so it follows the price faster. Each new EMA is `previous EMA + k × (price - previous EMA)` with `k = 2 / (n + 1)`. The first EMA (on candle `n`) is the SMA of the first `n` prices, like TA-Lib.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | the period; bigger is smoother and slower |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles. **Careful:** one NULL value makes this and **every later** EMA of the series `NULL`. Leave NULL prices out with `WHERE close IS NOT NULL`.
- **Notes:** because every EMA depends on all earlier prices, the values of the first few candles after the warm-up still depend on where the series starts. Load more history than you show.

**Example: EMA follows the price faster than SMA** (sample data: sample)

```sql
SELECT time, close,
       round(sma(close, 5), 2) AS sma5,
       round(ema(close, 5), 2) AS ema5
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | sma5 (DOUBLE) | ema5 (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 181 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 178.5 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 176.8 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 174.2 | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 173.3 | 176.76 | 176.76 |
| 2026-08-30T00:00:00.000Z | 173 | 175.16 | 175.51 |
| 2026-08-31T00:00:00.000Z | 172.6 | 173.98 | 174.54 |
| 2026-09-01T00:00:00.000Z | 169 | 172.42 | 172.69 |
| 2026-09-02T00:00:00.000Z | 171.5 | 171.88 | 172.29 |
| 2026-09-03T00:00:00.000Z | 176 | 172.42 | 173.53 |
| 2026-09-06T00:00:00.000Z | 180.1 | 173.84 | 175.72 |
| 2026-09-07T00:00:00.000Z | 176.9 | 174.7 | 176.11 |
| 2026-09-08T00:00:00.000Z | 182.4 | 177.38 | 178.21 |
| 2026-09-09T00:00:00.000Z | 187.3 | 180.54 | 181.24 |
| 2026-09-10T00:00:00.000Z | 191.2 | 183.58 | 184.56 |

(15 rows)

**Example: 12- and 26-candle EMA of CITY's one-minute candles (the last 5)** (sample data: sample)

```sql
SELECT time, close, ema12, ema26, round(ema12 - ema26, 3) AS difference
FROM (SELECT time, close,
             round(ema(close, 12), 2) AS ema12,
             round(ema(close, 26), 2) AS ema26
      FROM ochl_minutes
      WHERE symbol = 'CITY' AND time IN '2026-09-10') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | ema12 (DOUBLE) | ema26 (DOUBLE) | difference (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 504.99 | 505.08 | -0.09 |
| 2026-09-10T09:13:00.000Z | 505.1 | 505 | 505.09 | -0.09 |
| 2026-09-10T09:12:00.000Z | 504.8 | 504.98 | 505.09 | -0.11 |
| 2026-09-10T09:11:00.000Z | 504.5 | 505.02 | 505.12 | -0.1 |
| 2026-09-10T09:10:00.000Z | 504.6 | 505.11 | 505.16 | -0.05 |

(5 rows)

**Example: A NULL price: SMA comes back, EMA stays NULL** (sample data: sample)

Setup:

```sql
CREATE TABLE prices (time TIMESTAMP, close DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO prices VALUES ('2026-09-01', 10), ('2026-09-02', 11), ('2026-09-03', NULL),
  ('2026-09-04', 13), ('2026-09-05', 12), ('2026-09-06', 14), ('2026-09-07', 15);
```

```sql
SELECT time, close, sma(close, 2) AS sma2, ema(close, 2) AS ema2, rsi(close, 2) AS rsi2
FROM prices
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | sma2 (DOUBLE) | ema2 (DOUBLE) | rsi2 (DOUBLE) |
|---|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 10 | NULL | NULL | NULL |
| 2026-09-02T00:00:00.000Z | 11 | 10.5 | 10.5 | NULL |
| 2026-09-03T00:00:00.000Z | NULL | NULL | NULL | 100 |
| 2026-09-04T00:00:00.000Z | 13 | NULL | NULL | 100 |
| 2026-09-05T00:00:00.000Z | 12 | 12.5 | NULL | 20 |
| 2026-09-06T00:00:00.000Z | 14 | 13 | NULL | 80.9523809523809 |
| 2026-09-07T00:00:00.000Z | 15 | 14.5 | NULL | 89.1891891891892 |

(7 rows)

## wma

Syntax:

```sql
wma(x, n)
wma(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **weighted moving average**. Like the SMA it averages the last `n` values, but newer prices count more: the newest price has weight `n`, the one before `n - 1`, and the oldest weight `1`. So it has less **lag** than the SMA. Lag means how many candles an average is late when the price turns.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | how many candles to average |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles. A NULL value makes the `n` results whose window holds it `NULL`; after that the WMA comes back.
- **Notes:** `wma(x, n) = (1 × oldest + 2 × next + ... + n × newest) / (1 + 2 + ... + n)`. The same as TA-Lib's `WMA`.

**Example: SMA and WMA of VOLT: the WMA turns sooner** (sample data: sample)

```sql
SELECT time, close, round(sma(close, 5), 2) AS sma5, round(wma(close, 5), 2) AS wma5
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | sma5 (DOUBLE) | wma5 (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 181 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 178.5 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 176.8 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 174.2 | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 173.3 | 176.76 | 175.45 |
| 2026-08-30T00:00:00.000Z | 173 | 175.16 | 174.19 |
| 2026-08-31T00:00:00.000Z | 172.6 | 173.98 | 173.34 |
| 2026-09-01T00:00:00.000Z | 169 | 172.42 | 171.68 |
| 2026-09-02T00:00:00.000Z | 171.5 | 171.88 | 171.37 |
| 2026-09-03T00:00:00.000Z | 176 | 172.42 | 172.75 |
| 2026-09-06T00:00:00.000Z | 180.1 | 173.84 | 175.31 |
| 2026-09-07T00:00:00.000Z | 176.9 | 174.7 | 176.33 |
| 2026-09-08T00:00:00.000Z | 182.4 | 177.38 | 178.89 |
| 2026-09-09T00:00:00.000Z | 187.3 | 180.54 | 182.2 |
| 2026-09-10T00:00:00.000Z | 191.2 | 183.58 | 185.75 |

(15 rows)

**Example: Close against its 5-day WMA, every symbol on the last day** (sample data: sample)

```sql
SELECT symbol, close, wma5,
       CASE WHEN close > wma5 THEN 'above' ELSE 'below' END AS position
FROM (SELECT time, symbol, close,
             round(wma(close, 5) OVER (PARTITION BY symbol ORDER BY time), 2) AS wma5
      FROM ochl_day) t
WHERE time IN '2026-09-10'
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | wma5 (DOUBLE) | position (STRING) |
|---|---|---|---|
| CITY | 504.9 | 502.12 | above |
| COAST | 376.1 | 377.75 | below |
| VOLT | 191.2 | 185.75 | above |

(3 rows)

## dema

Syntax:

```sql
dema(x, n)
dema(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **double exponential moving average**: `2 × EMA - EMA of the EMA`. Taking away the "EMA of the EMA" removes much of the EMA's lag, so the DEMA stays closer to the price. It also jumps around a little more.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | the period of both EMAs |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `2n - 2` candles (the second EMA needs `n` values of the first). **Careful:** like `ema`, one NULL value makes this and **every later** DEMA of the series `NULL`.
- **Notes:** the same as TA-Lib's `DEMA`. Load more history than you show: the first values depend on where the series starts.

**Example: EMA, DEMA and TEMA of CITY's one-minute candles (the last 5)** (sample data: sample)

```sql
SELECT time, close, ema10, dema10, tema10
FROM (SELECT time, close,
             round(ema(close, 10), 2) AS ema10,
             round(dema(close, 10), 2) AS dema10,
             round(tema(close, 10), 2) AS tema10
      FROM ochl_minutes
      WHERE symbol = 'CITY' AND time IN '2026-09-10') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | ema10 (DOUBLE) | dema10 (DOUBLE) | tema10 (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 504.96 | 504.86 | 504.84 |
| 2026-09-10T09:13:00.000Z | 505.1 | 504.98 | 504.87 | 504.84 |
| 2026-09-10T09:12:00.000Z | 504.8 | 504.95 | 504.79 | 504.7 |
| 2026-09-10T09:11:00.000Z | 504.5 | 504.98 | 504.82 | 504.71 |
| 2026-09-10T09:10:00.000Z | 504.6 | 505.09 | 505 | 504.93 |

(5 rows)

## tema

Syntax:

```sql
tema(x, n)
tema(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **triple exponential moving average**: `3 × EMA - 3 × EMA of the EMA + EMA of the EMA of the EMA`. It has even less lag than the DEMA, and it is the fastest of the EMA family.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | the period of the three EMAs |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `3n - 3` candles. **Careful:** one NULL value makes this and every later TEMA of the series `NULL`.
- **Notes:** the same as TA-Lib's `TEMA`. A long period needs many candles: `tema(close, 20)` has its first value on candle 58.

**Example: Warm-up: EMA on candle n, DEMA on candle 2n - 1, TEMA on candle 3n - 2** (sample data: sample)

```sql
SELECT time, close,
       round(ema(close, 3), 2) AS ema3,
       round(dema(close, 3), 2) AS dema3,
       round(tema(close, 3), 2) AS tema3
FROM ochl_day
WHERE symbol = 'COAST' AND time >= '2026-09-01'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | ema3 (DOUBLE) | dema3 (DOUBLE) | tema3 (DOUBLE) |
|---|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 367.4 | NULL | NULL | NULL |
| 2026-09-02T00:00:00.000Z | 369.2 | NULL | NULL | NULL |
| 2026-09-03T00:00:00.000Z | 373.2 | 369.93 | NULL | NULL |
| 2026-09-06T00:00:00.000Z | 375.4 | 372.67 | NULL | NULL |
| 2026-09-07T00:00:00.000Z | 379.2 | 375.93 | 379.02 | NULL |
| 2026-09-08T00:00:00.000Z | 377.2 | 376.57 | 378.43 | NULL |
| 2026-09-09T00:00:00.000Z | 380.1 | 378.33 | 380.15 | 380.13 |
| 2026-09-10T00:00:00.000Z | 376.1 | 377.22 | 377.57 | 376.82 |

(8 rows)

## trima

Syntax:

```sql
trima(x, n)
trima(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **triangular moving average**. The prices in the middle of the window count most, and the oldest and newest count least (the weights look like a triangle: 1, 2, 3, 2, 1). It is very smooth, but it has **more** lag than the SMA.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | how many candles to average |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles. A NULL value makes the `n` results whose window holds it `NULL`; after that the TRIMA comes back.
- **Notes:** it is the SMA of an SMA. The same as TA-Lib's `TRIMA`. Use it to see the calm, long trend, not for fast signals.

**Example: TRIMA is smoother and slower than SMA** (sample data: sample)

```sql
SELECT time, close, round(sma(close, 5), 2) AS sma5, round(trima(close, 5), 2) AS trima5
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | sma5 (DOUBLE) | trima5 (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 507.9 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 510.3 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 513.3 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 513.2 | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 505.9 | 510.12 | 511.19 |
| 2026-08-30T00:00:00.000Z | 503.1 | 509.16 | 510.16 |
| 2026-08-31T00:00:00.000Z | 505.7 | 508.24 | 507.7 |
| 2026-09-01T00:00:00.000Z | 502.4 | 506.06 | 505.34 |
| 2026-09-02T00:00:00.000Z | 496.4 | 502.7 | 503.38 |
| 2026-09-03T00:00:00.000Z | 497.9 | 501.1 | 501.38 |
| 2026-09-06T00:00:00.000Z | 499 | 500.28 | 499.39 |
| 2026-09-07T00:00:00.000Z | 498.7 | 498.88 | 498.4 |
| 2026-09-08T00:00:00.000Z | 497.5 | 497.9 | 498.23 |
| 2026-09-09T00:00:00.000Z | 504.6 | 499.54 | 499.07 |
| 2026-09-10T00:00:00.000Z | 504.9 | 500.94 | 500.33 |

(15 rows)

## kama

Syntax:

```sql
kama(x, n)
kama(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**Kaufman's adaptive moving average**. It changes its own speed. It looks at the **efficiency ratio** of the last `n` candles: the price change from start to end, divided by the sum of all the small up and down moves. When the price goes straight in one direction (ratio near 1), KAMA follows it fast. When the price only goes up and down (ratio near 0), KAMA hardly moves, so it gives fewer false signals in a sideways market.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | how many candles the efficiency ratio looks back |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n` candles. **Careful:** one NULL value makes this and every later KAMA of the series `NULL`.
- **Notes:** the same as TA-Lib's `KAMA`: its speed goes from a 2-candle EMA (fastest) to a 30-candle EMA (slowest). TA-Lib's usual period is 30; many traders use 10.

**Example: KAMA follows a straight move, and stays calm when the price goes up and down** (sample data: sample)

Setup:

```sql
CREATE TABLE moves (time TIMESTAMP, straight DOUBLE, zigzag DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO moves VALUES ('2026-09-01', 100, 100), ('2026-09-02', 101, 104), ('2026-09-03', 102, 100),
  ('2026-09-04', 103, 104), ('2026-09-05', 104, 100), ('2026-09-06', 105, 104), ('2026-09-07', 106, 100),
  ('2026-09-08', 107, 104);
```

```sql
SELECT time, straight, round(kama(straight, 3), 2) AS kama_straight,
       zigzag, round(kama(zigzag, 3), 2) AS kama_zigzag, round(ema(zigzag, 3), 2) AS ema_zigzag
FROM moves
ORDER BY time;
```

Result:

| time (TIMESTAMP) | straight (DOUBLE) | kama_straight (DOUBLE) | zigzag (DOUBLE) | kama_zigzag (DOUBLE) | ema_zigzag (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 100 | NULL | 100 | NULL | NULL |
| 2026-09-02T00:00:00.000Z | 101 | NULL | 104 | NULL | NULL |
| 2026-09-03T00:00:00.000Z | 102 | NULL | 100 | NULL | 101.33 |
| 2026-09-04T00:00:00.000Z | 103 | 102.44 | 104 | 100.28 | 102.67 |
| 2026-09-05T00:00:00.000Z | 104 | 103.14 | 100 | 100.26 | 101.33 |
| 2026-09-06T00:00:00.000Z | 105 | 103.96 | 104 | 100.52 | 102.67 |
| 2026-09-07T00:00:00.000Z | 106 | 104.87 | 100 | 100.49 | 101.33 |
| 2026-09-08T00:00:00.000Z | 107 | 105.82 | 104 | 100.73 | 102.67 |

(8 rows)

**Example: KAMA and EMA of COAST's one-minute candles (the last 5)** (sample data: sample)

```sql
SELECT time, close, kama10, ema10
FROM (SELECT time, close, round(kama(close, 10), 2) AS kama10, round(ema(close, 10), 2) AS ema10
      FROM ochl_minutes
      WHERE symbol = 'COAST' AND time IN '2026-09-10') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | kama10 (DOUBLE) | ema10 (DOUBLE) |
|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 375.38 | 375.59 |
| 2026-09-10T09:13:00.000Z | 376.2 | 375.27 | 375.47 |
| 2026-09-10T09:12:00.000Z | 376 | 375.09 | 375.31 |
| 2026-09-10T09:11:00.000Z | 375.5 | 375.02 | 375.16 |
| 2026-09-10T09:10:00.000Z | 375.6 | 375.01 | 375.09 |

(5 rows)

## hma

Syntax:

```sql
hma(x, n)
hma(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **Hull moving average** (by Alan Hull). It is both smooth and fast: it takes `2 × WMA of n/2 candles - WMA of n candles`, which runs a little ahead of the price, and then smooths that with a WMA of `√n` candles.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 2 or more | the period; `n/2` and `√n` are rounded down |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n + √n - 2` candles (`hma(close, 20)`: 22 candles). A NULL value gives NULL for a while; after that the HMA comes back.
- **Notes:** not in TA-Lib. Because it runs ahead of the price, the HMA can overshoot after a sharp turn.

**Example: HMA follows VOLT with little lag** (sample data: sample)

```sql
SELECT time, close, round(sma(close, 4), 2) AS sma4, round(hma(close, 4), 2) AS hma4
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | sma4 (DOUBLE) | hma4 (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 181 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 178.5 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 176.8 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 174.2 | 177.63 | NULL |
| 2026-08-27T00:00:00.000Z | 173.3 | 175.7 | 172.81 |
| 2026-08-30T00:00:00.000Z | 173 | 174.33 | 172.46 |
| 2026-08-31T00:00:00.000Z | 172.6 | 173.28 | 172.46 |
| 2026-09-01T00:00:00.000Z | 169 | 171.98 | 170.21 |
| 2026-09-02T00:00:00.000Z | 171.5 | 171.53 | 169.84 |
| 2026-09-03T00:00:00.000Z | 176 | 172.28 | 174.13 |
| 2026-09-06T00:00:00.000Z | 180.1 | 174.15 | 179.65 |
| 2026-09-07T00:00:00.000Z | 176.9 | 176.13 | 179.67 |
| 2026-09-08T00:00:00.000Z | 182.4 | 178.85 | 180.59 |
| 2026-09-09T00:00:00.000Z | 187.3 | 181.68 | 186.03 |
| 2026-09-10T00:00:00.000Z | 191.2 | 184.45 | 191.41 |

(15 rows)

**Example: The period must be 2 or more** (sample data: sample; shows an error)

```sql
SELECT hma(close, 1) FROM ochl_day;
```

Result:

Error: `line 1, column 8: hma: the period must be a whole number of rows (2 or more)`

## vwma

Syntax:

```sql
vwma(price, volume, n)
vwma(price, volume, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **volume-weighted moving average**: `sum(price × volume) / sum(volume)` of the last `n` candles. Candles with a big volume count more. When the VWMA is above the SMA, the higher prices came with more volume, which traders read as strong buying.

| Argument | Type | Meaning |
|---|---|---|
| `price` | number | the price, usually `close` |
| `volume` | number | the volume of the candle |
| `n` | whole number, 1 or more | how many candles |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles, and when the total volume of the window is `0`. A NULL price or volume makes the `n` results whose window holds it `NULL`; after that the VWMA comes back.
- **Notes:** the same as TradingView's `ta.vwma`. It is a moving [vwap](functions-aggregate.md#vwap) that waits until it has `n` candles.

**Example: VWMA and SMA of CITY's one-minute candles (the last 5)** (sample data: sample)

```sql
SELECT time, close, volume, vwma20, sma20
FROM (SELECT time, close, volume,
             round(vwma(close, volume, 20), 2) AS vwma20,
             round(sma(close, 20), 2) AS sma20
      FROM ochl_minutes
      WHERE symbol = 'CITY' AND time IN '2026-09-10') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) | vwma20 (DOUBLE) | sma20 (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 1000 | 504.91 | 504.97 |
| 2026-09-10T09:13:00.000Z | 505.1 | 460 | 504.88 | 504.95 |
| 2026-09-10T09:12:00.000Z | 504.8 | 390 | 504.88 | 504.94 |
| 2026-09-10T09:11:00.000Z | 504.5 | 1350 | 504.87 | 504.94 |
| 2026-09-10T09:10:00.000Z | 504.6 | 1340 | 504.91 | 504.98 |

(5 rows)

**Example: VWMA is a moving VWAP that waits for n candles** (sample data: sample)

```sql
SELECT time, close, volume,
       round(vwma(close, volume, 3), 2) AS vwma3,
       round(vwap(close, volume) OVER (ORDER BY time ROWS 2 PRECEDING), 2) AS moving_vwap
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-09-03'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) | vwma3 (DOUBLE) | moving_vwap (DOUBLE) |
|---|---|---|---|---|
| 2026-09-03T00:00:00.000Z | 176 | 145930 | NULL | 176 |
| 2026-09-06T00:00:00.000Z | 180.1 | 78550 | NULL | 177.43 |
| 2026-09-07T00:00:00.000Z | 176.9 | 135560 | 177.23 | 177.23 |
| 2026-09-08T00:00:00.000Z | 182.4 | 136770 | 179.76 | 179.76 |
| 2026-09-09T00:00:00.000Z | 187.3 | 94410 | 181.63 | 181.63 |
| 2026-09-10T00:00:00.000Z | 191.2 | 41470 | 185.44 | 185.44 |

(6 rows)

## rsi

Syntax:

```sql
rsi(x, n)
rsi(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **relative strength index**, a momentum number from 0 to 100. It compares the size of the recent rises with the size of the recent falls. Above **70**, traders call a share "overbought" (it rose a lot, it may fall back); below **30**, "oversold". The usual period is 14.

It is Wilder's RSI, like TA-Lib: the average gain and average loss of the first `n` changes, then `average = (previous average × (n - 1) + today's gain or loss) / n`, and `RSI = 100 - 100 / (1 + average gain / average loss)`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | the period, usually `14` |

- **Returns:** `DOUBLE` from 0 to 100.
- **NULL:** `NULL` for the first `n` candles (the first candle has no change). A NULL price counts as "no change" in both of its changes; the RSI goes on.
- **Notes:** only rises give `100`; only falls give `0`; a flat price (no rises, no falls) gives `50`.

**Example: RSI 14 on CITY's one-minute candles (the last 5 minutes)** (sample data: sample)

```sql
SELECT time, close, rsi14
FROM (SELECT time, close, round(rsi(close, 14), 1) AS rsi14
      FROM ochl_minutes
      WHERE symbol = 'CITY' AND time IN '2026-09-10') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | rsi14 (DOUBLE) |
|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 47.6 |
| 2026-09-10T09:13:00.000Z | 505.1 | 50.1 |
| 2026-09-10T09:12:00.000Z | 504.8 | 46.2 |
| 2026-09-10T09:11:00.000Z | 504.5 | 42 |
| 2026-09-10T09:10:00.000Z | 504.6 | 43 |

(5 rows)

**Example: Overbought or oversold? Daily RSI 5 of every symbol** (sample data: sample)

```sql
SELECT time, symbol, close, rsi5,
       CASE WHEN rsi5 >= 70 THEN 'overbought'
            WHEN rsi5 <= 30 THEN 'oversold'
            ELSE 'normal' END AS zone
FROM (SELECT time, symbol, close,
             round(rsi(close, 5) OVER (PARTITION BY symbol ORDER BY time), 1) AS rsi5
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | rsi5 (DOUBLE) | zone (STRING) |
|---|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | 31.6 | normal |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 63.1 | normal |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 64 | normal |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | 49.9 | normal |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 58.8 | normal |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 45 | normal |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | 67.5 | normal |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 76.1 | overbought |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 81.1 | overbought |

(9 rows)

**Example: Only rises: 100. Only falls: 0. Flat: 50** (sample data: sample)

```sql
SELECT time, rising, falling, flat,
       rsi(rising, 3) AS rsi_rising, rsi(falling, 3) AS rsi_falling, rsi(flat, 3) AS rsi_flat
FROM (SELECT time,
             100 + row_number() AS rising,
             100 - row_number() AS falling,
             100 AS flat
      FROM ochl_day
      WHERE symbol = 'VOLT' AND time >= '2026-09-06') t
ORDER BY time;
```

Result:

| time (TIMESTAMP) | rising (LONG) | falling (LONG) | flat (LONG) | rsi_rising (DOUBLE) | rsi_falling (DOUBLE) | rsi_flat (DOUBLE) |
|---|---|---|---|---|---|---|
| 2026-09-06T00:00:00.000Z | 101 | 99 | 100 | NULL | NULL | NULL |
| 2026-09-07T00:00:00.000Z | 102 | 98 | 100 | NULL | NULL | NULL |
| 2026-09-08T00:00:00.000Z | 103 | 97 | 100 | NULL | NULL | NULL |
| 2026-09-09T00:00:00.000Z | 104 | 96 | 100 | 100 | 0 | 50 |
| 2026-09-10T00:00:00.000Z | 105 | 95 | 100 | 100 | 0 | 50 |

(5 rows)

## atr

Syntax:

```sql
atr(high, low, close, n)
atr(high, low, close, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **average true range**: how much the price moves in one candle, on average, in the unit of the price (for example dollars). It measures **volatility**, not direction. Traders use it to place a stop-loss (for example 2 × ATR below the price) and to choose a position size.

The **true range** of a candle is the biggest of: `high - low`, `|high - previous close|` and `|low - previous close|`. So a gap from yesterday's close counts too. ATR is Wilder's average of the true range, like TA-Lib: the plain average of the first `n` true ranges, then `(previous ATR × (n - 1) + true range) / n`.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close |
| `n` | whole number, 1 or more | the period, usually `14` |

- **Returns:** `DOUBLE` (the same unit as the prices).
- **NULL:** `NULL` for the first `n` candles (the first candle has no previous close). **Careful:** a NULL `high`, `low` or `close` makes this and every later ATR of the series `NULL` (when it is in the first `n` candles, the table output can even show `NaN` once). Leave such candles out with `WHERE`.
- **Notes:** all four arguments are needed. To compare shares with very different prices, divide by the close: `atr / close × 100` is the ATR in percent.

**Example: ATR in dollars and in percent of the price** (sample data: sample)

```sql
SELECT time, symbol, close, atr5, round(atr5 / close * 100, 2) AS atr_pct
FROM (SELECT time, symbol, close,
             round(atr(high, low, close, 5) OVER (PARTITION BY symbol ORDER BY time), 2) AS atr5
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE time IN '2026-09-10'
ORDER BY atr_pct DESC;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | atr5 (DOUBLE) | atr_pct (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 7.3 | 3.82 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 9.7 | 2.58 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 7.33 | 1.45 |

(3 rows)

**Example: A stop-loss 2 × ATR below today's close** (sample data: sample)

```sql
SELECT symbol, close, atr5, round(close - 2 * atr5, 1) AS stop_loss
FROM (SELECT time, symbol, close,
             round(atr(high, low, close, 5) OVER (PARTITION BY symbol ORDER BY time), 2) AS atr5
      FROM ochl_day) t
WHERE time IN '2026-09-10'
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | atr5 (DOUBLE) | stop_loss (DOUBLE) |
|---|---|---|---|
| CITY | 504.9 | 7.65 | 489.6 |
| COAST | 376.1 | 9.99 | 356.1 |
| VOLT | 191.2 | 7.43 | 176.3 |

(3 rows)

**Example: high, low, close and the period are all needed** (sample data: sample; shows an error)

```sql
SELECT atr(close, 14) FROM ochl_day;
```

Result:

Error: `line 1, column 8: function 'atr' takes 4 argument(s), got 2`
