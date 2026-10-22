# Momentum indicators

> MACD, stochastic, stochastic RSI, Williams %R, CCI, rate of change, momentum and TRIX on candles, with the same results as TA-Lib.

- Category: Functions — technical indicators
- Keywords: momentum, oscillator, overbought, oversold, crossover, signal line, divergence, TA-Lib, MACD, moving average convergence divergence, signal line, histogram, stochastic, stochastic oscillator, slow stochastic, %K, %D, fast stochastic, STOCHF, stochastic RSI, StochRSI, STOCHRSI, Williams %R, WILLR, %R, commodity channel index, CCI, rate of change, ROC, ROCP, ROCR, MOM, TRIX, triple exponential average, stock market
- See also: [Technical indicators](functions-indicators.md), [Volatility indicators and bands](functions-indicators-volatility.md), [Trend indicators](functions-indicators-trend.md), [Volume indicators](functions-indicators-volume.md), [Returns and risk](functions-returns-risk.md), [Window and series functions](functions-window.md)

**Momentum** is the speed of a price move. A momentum indicator tells how strong a rise or a fall is, and when it gets weaker. Many of them are **oscillators**: numbers that swing between fixed levels (like 0 and 100). Near the top level a share is called **overbought** (it rose a lot and may fall back); near the bottom level **oversold**.

These are **series functions**, like [sma, ema, rsi and atr](functions-indicators.md), with the same rules:

- **Order:** without `OVER`, all result rows are one series in time order. With **many symbols**, always write `OVER (PARTITION BY symbol ORDER BY time)`.
- **Periods** are whole numbers of candles, written as constants (`macd(close, 12, 26, 9)`). You can leave out the ones at the end: they get the usual defaults.
- **Warm-up:** the first rows are `NULL` until there are enough candles. With the default periods:

| Function | Default periods | First value on candle | In general |
|---|---|---|---|
| `macd`, `macd_signal`, `macd_hist` | 12, 26, 9 | 34 | slow + signal - 1 |
| `stoch_k`, `stoch_d` | 14, 3, 3 | 18 | k + k_slowing + d - 2 |
| `stochf_k` | 14 | 14 | k |
| `stochrsi_k`, `stochrsi_d` | 14, 5, 3 | 21 | rsi_period + k + d - 1 |
| `willr` | 14 | 14 | n |
| `cci` | 20 | 20 | n |
| `roc`, `rocp`, `rocr`, `mom` | 10 | 11 | n + 1 |
| `trix` | 30 | 89 | 3n - 1 |

- **WHERE runs first**, and an indicator cannot be in the same `SELECT` as `SAMPLE BY` or `GROUP BY`: make the candles in a subquery (see [technical indicators](functions-indicators.md)).
- **NULL prices:** `macd`, `stochrsi` and `trix` are built from EMAs or Wilder averages. One NULL price makes that row and **every later** row `NULL`: leave NULL prices out with `WHERE close IS NOT NULL`. The others only look at a window of candles: they are NULL while the window holds the NULL, and then come back.
- **Same as TA-Lib:** the formulas and the first row with a value match TA-Lib.
- **Returns** `DOUBLE`.
- One series function cannot be inside another (`ema(trix(close, 30), 9)`): compute the first one in a subquery.

**Example: Momentum of CITY's one-minute candles: MACD, stochastic, Williams %R and CCI (the last 5)** (sample data: sample)

```sql
SELECT time, close, macd, stoch_k, willr, cci
FROM (SELECT time, close,
             round(macd(close), 3) AS macd,
             round(stoch_k(high, low, close), 1) AS stoch_k,
             round(willr(high, low, close), 1) AS willr,
             round(cci(high, low, close), 1) AS cci
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | macd (DOUBLE) | stoch_k (DOUBLE) | willr (DOUBLE) | cci (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | -0.093 | 35.2 | -66.7 | -6.3 |
| 2026-09-10T09:13:00.000Z | 505.1 | -0.091 | 29.3 | -55.6 | 16 |
| 2026-09-10T09:12:00.000Z | 504.8 | -0.109 | 21.5 | -72.2 | -57.3 |
| 2026-09-10T09:11:00.000Z | 504.5 | -0.099 | 28.9 | -84.2 | -80.9 |
| 2026-09-10T09:10:00.000Z | 504.6 | -0.054 | 38.8 | -78.9 | -57.7 |

(5 rows)

<a id="macd"></a>

## macd, macd_signal, macd_hist

Syntax:

```sql
macd(x [, fast [, slow [, signal]]])
macd_signal(x [, fast [, slow [, signal]]])
macd_hist(x [, fast [, slow [, signal]]])
macd(x, fast, slow, signal) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**MACD** (moving average convergence divergence) shows the trend and its strength with three lines:

- `macd`: the **MACD line**, `EMA(fast) - EMA(slow)` of the price. Above 0, the short-term average is above the long-term one: the price is going up.
- `macd_signal`: the **signal line**, an EMA of the MACD line over `signal` candles.
- `macd_hist`: the **histogram**, `macd - macd_signal`. It grows when the move gets stronger.

When the MACD line crosses **above** the signal line (the histogram turns from minus to plus), traders read it as a buy signal; crossing **below** is a sell signal.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `fast` | whole number, 1 or more | the short EMA period; default `12` |
| `slow` | whole number, 1 or more | the long EMA period; default `26` |
| `signal` | whole number, 1 or more | the EMA period of the signal line; default `9` |

- **Returns:** `DOUBLE`, in the unit of the price (for example dollars).
- **NULL:** all three are `NULL` for the first `slow + signal - 2` candles (33 with the defaults), like TA-Lib. **Careful:** one NULL price makes this and every later value `NULL`.
- **Notes:** when `fast` is bigger than `slow`, the two are swapped (like TA-Lib). Both EMAs start on candle `slow`, like TA-Lib's `MACD`; a chart that starts the fast EMA earlier shows slightly different first values. Load much more history than you show.

**Example: MACD, signal and histogram of CITY's one-minute candles (the last 5)** (sample data: sample)

```sql
SELECT time, close, macd, signal, hist
FROM (SELECT time, close,
             round(macd(close), 3) AS macd,
             round(macd_signal(close), 3) AS signal,
             round(macd_hist(close), 3) AS hist
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | macd (DOUBLE) | signal (DOUBLE) | hist (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | -0.093 | -0.062 | -0.031 |
| 2026-09-10T09:13:00.000Z | 505.1 | -0.091 | -0.054 | -0.037 |
| 2026-09-10T09:12:00.000Z | 504.8 | -0.109 | -0.045 | -0.063 |
| 2026-09-10T09:11:00.000Z | 504.5 | -0.099 | -0.029 | -0.069 |
| 2026-09-10T09:10:00.000Z | 504.6 | -0.054 | -0.012 | -0.042 |

(5 rows)

**Example: MACD crossovers: buy and sell signals of COAST on 10 September** (sample data: sample)

```sql
SELECT time, close, hist,
       CASE WHEN hist > 0 THEN 'BUY' ELSE 'SELL' END AS signal
FROM (SELECT time, close, hist, lag(hist) AS prev_hist
      FROM (SELECT time, close, round(macd_hist(close), 3) AS hist
            FROM ochl_minutes
            WHERE symbol = 'COAST') a) b
WHERE time IN '2026-09-10'
  AND ((hist > 0 AND prev_hist <= 0) OR (hist < 0 AND prev_hist >= 0))
ORDER BY time
LIMIT 6;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | hist (DOUBLE) | signal (STRING) |
|---|---|---|---|
| 2026-09-10T05:35:00.000Z | 380.8 | -0.026 | SELL |
| 2026-09-10T05:53:00.000Z | 380 | 0.02 | BUY |
| 2026-09-10T06:21:00.000Z | 380.7 | -0.041 | SELL |
| 2026-09-10T06:36:00.000Z | 380.4 | 0.03 | BUY |
| 2026-09-10T06:43:00.000Z | 379.4 | -0.031 | SELL |
| 2026-09-10T06:45:00.000Z | 380.2 | 0.013 | BUY |

(6 rows)

**Example: Short periods on daily candles: MACD 3, 6, 3 of every symbol on the last day** (sample data: sample)

```sql
SELECT time, symbol, close, macd, signal, hist
FROM (SELECT time, symbol, close,
             round(macd(close, 3, 6, 3) OVER (PARTITION BY symbol ORDER BY time), 2) AS macd,
             round(macd_signal(close, 3, 6, 3) OVER (PARTITION BY symbol ORDER BY time), 2) AS signal,
             round(macd_hist(close, 3, 6, 3) OVER (PARTITION BY symbol ORDER BY time), 2) AS hist
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE time IN '2026-09-10'
ORDER BY symbol;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | macd (DOUBLE) | signal (DOUBLE) | hist (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 1.02 | 0.2 | 0.83 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 0.61 | 0.83 | -0.22 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 3.77 | 2.93 | 0.85 |

(3 rows)

<a id="stoch_k"></a>

## stoch_k, stoch_d

Syntax:

```sql
stoch_k(high, low, close [, k [, k_slowing [, d]]])
stoch_d(high, low, close [, k [, k_slowing [, d]]])
stoch_k(high, low, close, k, k_slowing, d) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **slow stochastic oscillator**, from 0 to 100. It tells where the close is inside the range of the last `k` candles: 100 is at the highest high, 0 at the lowest low.

- The raw value is `(close - lowest low) / (highest high - lowest low) × 100` over the last `k` candles.
- `stoch_k` (**%K**) is the SMA of the raw value over `k_slowing` candles.
- `stoch_d` (**%D**) is the SMA of %K over `d` candles: a slower line.

Above **80** is overbought, below **20** oversold. When %K crosses above %D in the oversold zone, traders read it as a buy signal.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close |
| `k` | whole number, 1 or more | candles for the highest high and lowest low; default `14` |
| `k_slowing` | whole number, 1 or more | the SMA period of %K; default `3` |
| `d` | whole number, 1 or more | the SMA period of %D; default `3` |

- **Returns:** `DOUBLE` from 0 to 100.
- **NULL:** both are `NULL` for the first `k + k_slowing + d - 3` candles (17 with the defaults). Like TA-Lib, %K waits for %D, so `d` also changes when %K starts. A NULL price gives NULL while it is inside a window; then the values come back.
- **Notes:** when the highest high equals the lowest low (a flat market), the raw value is `0`. The same as TA-Lib's `STOCH` with SMA smoothing.

**Example: Slow stochastic 14, 3, 3 of COAST's one-minute candles (the last 5)** (sample data: sample)

```sql
SELECT time, close, k, d,
       CASE WHEN k >= 80 THEN 'overbought' WHEN k <= 20 THEN 'oversold' ELSE 'normal' END AS zone
FROM (SELECT time, close,
             round(stoch_k(high, low, close), 1) AS k,
             round(stoch_d(high, low, close), 1) AS d
      FROM ochl_minutes
      WHERE symbol = 'COAST') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | k (DOUBLE) | d (DOUBLE) | zone (STRING) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 87.3 | 87.2 | overbought |
| 2026-09-10T09:13:00.000Z | 376.2 | 88.6 | 82.5 | overbought |
| 2026-09-10T09:12:00.000Z | 376 | 85.8 | 71.2 | overbought |
| 2026-09-10T09:11:00.000Z | 375.5 | 73.1 | 52.8 | normal |
| 2026-09-10T09:10:00.000Z | 375.6 | 54.6 | 38.4 | normal |

(5 rows)

**Example: Stochastic 5, 3, 3 on daily candles, every symbol** (sample data: sample)

```sql
SELECT time, symbol, close, k, d
FROM (SELECT time, symbol, close,
             round(stoch_k(high, low, close, 5, 3, 3) OVER (PARTITION BY symbol ORDER BY time), 1) AS k,
             round(stoch_d(high, low, close, 5, 3, 3) OVER (PARTITION BY symbol ORDER BY time), 1) AS d
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | k (DOUBLE) | d (DOUBLE) |
|---|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | 37 | 30.7 |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 43 | 37.1 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 50.4 | 43.5 |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | 81.5 | 77.3 |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 70.7 | 78.2 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 45.6 | 65.9 |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | 75 | 73.3 |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 78.4 | 75.8 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 91 | 81.4 |

(9 rows)

**Example: %K crosses above %D: buy signals of CITY's one-minute candles on 10 September** (sample data: sample)

```sql
SELECT time, close, k, d
FROM (SELECT time, close, k, d, lag(k) AS prev_k, lag(d) AS prev_d
      FROM (SELECT time, close,
                   round(stoch_k(high, low, close), 1) AS k,
                   round(stoch_d(high, low, close), 1) AS d
            FROM ochl_minutes
            WHERE symbol = 'CITY') a) b
WHERE time IN '2026-09-10' AND k > d AND prev_k <= prev_d AND k < 30
ORDER BY time
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | k (DOUBLE) | d (DOUBLE) |
|---|---|---|---|
| 2026-09-10T05:18:00.000Z | 504.4 | 18.9 | 16.3 |
| 2026-09-10T05:30:00.000Z | 504.5 | 26.2 | 25.5 |
| 2026-09-10T06:06:00.000Z | 505.5 | 15.6 | 13.8 |
| 2026-09-10T06:37:00.000Z | 504.5 | 11.5 | 10 |
| 2026-09-10T06:48:00.000Z | 503.2 | 8.4 | 6.4 |

(5 rows)

<a id="stochf_k"></a>

## stochf_k

Syntax:

```sql
stochf_k(high, low, close [, k])
stochf_k(high, low, close, k) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **fast stochastic** %K: the raw stochastic value without smoothing, `(close - lowest low) / (highest high - lowest low) × 100` over the last `k` candles. It reacts at once, so it jumps more than [stoch_k](#stoch_k).

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close |
| `k` | whole number, 1 or more | how many candles; default `14` |

- **Returns:** `DOUBLE` from 0 to 100.
- **NULL:** `NULL` for the first `k - 1` candles. A NULL price gives NULL while it is inside the window; then the values come back.
- **Notes:** `0` when the highest high equals the lowest low. The same as the fast %K of TA-Lib's `STOCHF`. For the fast %D, take the `sma` of it over 3 candles in an outer query.

**Example: Fast %K and fast %D (SMA 3 of fast %K) of VOLT** (sample data: sample)

```sql
SELECT time, close, fast_k, round(sma(fast_k, 3), 1) AS fast_d
FROM (SELECT time, close, round(stochf_k(high, low, close, 5), 1) AS fast_k
      FROM ochl_day
      WHERE symbol = 'VOLT' AND time >= '2026-08-23') t
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | fast_k (DOUBLE) | fast_d (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 181 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 178.5 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 176.8 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 174.2 | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 173.3 | 11.2 | NULL |
| 2026-08-30T00:00:00.000Z | 173 | 18.5 | NULL |
| 2026-08-31T00:00:00.000Z | 172.6 | 17.2 | 15.6 |
| 2026-09-01T00:00:00.000Z | 169 | 15.3 | 17 |
| 2026-09-02T00:00:00.000Z | 171.5 | 48.8 | 27.1 |
| 2026-09-03T00:00:00.000Z | 176 | 87 | 50.4 |
| 2026-09-06T00:00:00.000Z | 180.1 | 77.1 | 71 |
| 2026-09-07T00:00:00.000Z | 176.9 | 57.8 | 74 |
| 2026-09-08T00:00:00.000Z | 182.4 | 89.9 | 74.9 |
| 2026-09-09T00:00:00.000Z | 187.3 | 87.5 | 78.4 |
| 2026-09-10T00:00:00.000Z | 191.2 | 95.4 | 90.9 |

(15 rows)

<a id="stochrsi_k"></a>

## stochrsi_k, stochrsi_d

Syntax:

```sql
stochrsi_k(x [, rsi_period [, k [, d]]])
stochrsi_d(x [, rsi_period [, k [, d]]])
stochrsi_k(x, rsi_period, k, d) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **stochastic RSI**, from 0 to 100. It puts the stochastic formula on the [RSI](functions-indicators.md#rsi) values instead of the prices: where is today's RSI inside the range of the last `k` RSI values? It moves faster than the RSI and reaches overbought (above 80) and oversold (below 20) more often.

- `stochrsi_k` (%K): `(RSI - lowest RSI) / (highest RSI - lowest RSI) × 100` over the last `k` RSI values.
- `stochrsi_d` (%D): the SMA of %K over `d` candles.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `rsi_period` | whole number, 1 or more | the RSI period; default `14` |
| `k` | whole number, 1 or more | how many RSI values for the range; default `5` |
| `d` | whole number, 1 or more | the SMA period of %D; default `3` |

- **Returns:** `DOUBLE` from 0 to 100.
- **NULL:** both are `NULL` for the first `rsi_period + k + d - 2` candles (20 with the defaults). **Careful:** the RSI inside is a Wilder average, so one NULL price makes this and every later value `NULL`.
- **Notes:** `0` when the RSI did not change over the `k` values. The same as TA-Lib's `STOCHRSI` (fast %K and fast %D).

**Example: Stochastic RSI 14, 5, 3 of CITY's one-minute candles (the last 5)** (sample data: sample)

```sql
SELECT time, close, rsi14, k, d
FROM (SELECT time, close,
             round(rsi(close, 14), 1) AS rsi14,
             round(stochrsi_k(close), 1) AS k,
             round(stochrsi_d(close), 1) AS d
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | rsi14 (DOUBLE) | k (DOUBLE) | d (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 47.6 | 69.4 | 82.4 |
| 2026-09-10T09:13:00.000Z | 505.1 | 50.1 | 100 | 59.3 |
| 2026-09-10T09:12:00.000Z | 504.8 | 46.2 | 77.8 | 25.9 |
| 2026-09-10T09:11:00.000Z | 504.5 | 42 | 0 | 3.6 |
| 2026-09-10T09:10:00.000Z | 504.6 | 43 | 0 | 3.6 |

(5 rows)

<a id="willr"></a>

## willr, williams_r

Syntax:

```sql
willr(high, low, close [, n])
williams_r(high, low, close [, n])
willr(high, low, close, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**Williams %R**, from **-100 to 0**. Like the stochastic, it shows where the close is inside the range of the last `n` candles, but counted down from the top: `0` is at the highest high, `-100` at the lowest low. Above **-20** is overbought, below **-80** oversold. `williams_r` is the same function.

`%R = (highest high - close) / (highest high - lowest low) × -100`

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close |
| `n` | whole number, 1 or more | how many candles; default `14` |

- **Returns:** `DOUBLE` from -100 to 0.
- **NULL:** `NULL` for the first `n - 1` candles. A NULL price gives NULL while it is inside the window; then the values come back.
- **Notes:** `%R = fast stochastic - 100`. When the highest high equals the lowest low, the result is `0` (like TA-Lib's `WILLR`).

**Example: Williams %R 5 of every symbol on the last three days** (sample data: sample)

```sql
SELECT time, symbol, close, wr,
       CASE WHEN wr >= -20 THEN 'overbought' WHEN wr <= -80 THEN 'oversold' ELSE 'normal' END AS zone
FROM (SELECT time, symbol, close,
             round(williams_r(high, low, close, 5) OVER (PARTITION BY symbol ORDER BY time), 1) AS wr
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | wr (DOUBLE) | zone (STRING) |
|---|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | -60.9 | normal |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | -44.8 | normal |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | -43.1 | normal |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | -22.9 | normal |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | -53.9 | normal |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | -86.3 | oversold |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | -10.1 | overbought |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | -12.5 | overbought |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | -4.6 | overbought |

(9 rows)

**Example: %R is the fast stochastic minus 100** (sample data: sample)

```sql
SELECT time, close,
       round(willr(high, low, close, 5), 2) AS willr5,
       round(stochf_k(high, low, close, 5) - 100, 2) AS fast_k_minus_100
FROM ochl_day
WHERE symbol = 'COAST' AND time >= '2026-09-03'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | willr5 (DOUBLE) | fast_k_minus_100 (DOUBLE) |
|---|---|---|---|
| 2026-09-03T00:00:00.000Z | 373.2 | NULL | NULL |
| 2026-09-06T00:00:00.000Z | 375.4 | NULL | NULL |
| 2026-09-07T00:00:00.000Z | 379.2 | NULL | NULL |
| 2026-09-08T00:00:00.000Z | 377.2 | NULL | NULL |
| 2026-09-09T00:00:00.000Z | 380.1 | -53.89 | -53.89 |
| 2026-09-10T00:00:00.000Z | 376.1 | -86.31 | -86.31 |

(6 rows)

## cci

Syntax:

```sql
cci(high, low, close [, n])
cci(high, low, close, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **commodity channel index**. It measures how far the **typical price** `(high + low + close) / 3` is from its average of the last `n` candles, compared with the usual distance. Most values are between **-100 and +100**. Above +100 the price is unusually high (a strong rise, or overbought); below -100 unusually low.

`CCI = (typical price - SMA of the typical price) / (0.015 × mean deviation)`. The **mean deviation** is the average distance of the `n` typical prices from their SMA.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close |
| `n` | whole number, 1 or more | how many candles; default `20` |

- **Returns:** `DOUBLE` (no fixed range).
- **NULL:** `NULL` for the first `n - 1` candles. A NULL price gives NULL while it is inside the window; then the values come back.
- **Notes:** `0` when all typical prices of the window are equal. The same as TA-Lib's `CCI`.

**Example: CCI 20 of COAST's one-minute candles (the last 5)** (sample data: sample)

```sql
SELECT time, close, cci20,
       CASE WHEN cci20 > 100 THEN 'above +100' WHEN cci20 < -100 THEN 'below -100' ELSE 'inside' END AS channel
FROM (SELECT time, close, round(cci(high, low, close), 1) AS cci20
      FROM ochl_minutes
      WHERE symbol = 'COAST') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | cci20 (DOUBLE) | channel (STRING) |
|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 148.5 | above +100 |
| 2026-09-10T09:13:00.000Z | 376.2 | 135.6 | above +100 |
| 2026-09-10T09:12:00.000Z | 376 | 129.4 | above +100 |
| 2026-09-10T09:11:00.000Z | 375.5 | 45.1 | inside |
| 2026-09-10T09:10:00.000Z | 375.6 | 43.4 | inside |

(5 rows)

**Example: CCI 5 on daily candles, every symbol on the last day** (sample data: sample)

```sql
SELECT symbol, close, cci5
FROM (SELECT time, symbol, close,
             round(cci(high, low, close, 5) OVER (PARTITION BY symbol ORDER BY time), 1) AS cci5
      FROM ochl_day) t
WHERE time IN '2026-09-10'
ORDER BY cci5 DESC;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | cci5 (DOUBLE) |
|---|---|---|
| VOLT | 191.2 | 108.6 |
| CITY | 504.9 | 56.2 |
| COAST | 376.1 | -38 |

(3 rows)

<a id="roc"></a>

## roc, rocp, rocr

Syntax:

```sql
roc(x [, n])
rocp(x [, n])
rocr(x [, n])
roc(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **rate of change**: how much the price changed against the price `n` candles ago. The three functions give the same change in three forms:

| Function | Formula | 10% rise gives |
|---|---|---|
| `roc` | `(x / x n candles ago - 1) × 100` | `10` (percent) |
| `rocp` | `(x - x n candles ago) / x n candles ago` | `0.1` (a fraction) |
| `rocr` | `x / x n candles ago` | `1.1` (a ratio) |

Above 0 (above 1 for `rocr`), the price is higher than `n` candles ago. When ROC gets smaller while the price still rises, the move is losing speed.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | how many candles back; default `10` |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n` candles, when this or the old price is NULL, and when the old price is `0`.
- **Notes:** the same as TA-Lib's `ROC`, `ROCP` and `ROCR`. `roc(close, 1)` is the same as [pct_change](functions-window.md#pct-change); for returns see [returns and risk](functions-returns-risk.md).

**Example: 5-day rate of change of CITY in three forms** (sample data: sample)

```sql
SELECT time, close,
       round(roc(close, 5), 2) AS roc5_pct,
       round(rocp(close, 5), 4) AS rocp5,
       round(rocr(close, 5), 4) AS rocr5
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | roc5_pct (DOUBLE) | rocp5 (DOUBLE) | rocr5 (DOUBLE) |
|---|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 507.9 | NULL | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 510.3 | NULL | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 513.3 | NULL | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 513.2 | NULL | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 505.9 | NULL | NULL | NULL |
| 2026-08-30T00:00:00.000Z | 503.1 | -0.95 | -0.0095 | 0.9905 |
| 2026-08-31T00:00:00.000Z | 505.7 | -0.9 | -0.009 | 0.991 |
| 2026-09-01T00:00:00.000Z | 502.4 | -2.12 | -0.0212 | 0.9788 |
| 2026-09-02T00:00:00.000Z | 496.4 | -3.27 | -0.0327 | 0.9673 |
| 2026-09-03T00:00:00.000Z | 497.9 | -1.58 | -0.0158 | 0.9842 |
| 2026-09-06T00:00:00.000Z | 499 | -0.81 | -0.0081 | 0.9919 |
| 2026-09-07T00:00:00.000Z | 498.7 | -1.38 | -0.0138 | 0.9862 |
| 2026-09-08T00:00:00.000Z | 497.5 | -0.98 | -0.0098 | 0.9902 |
| 2026-09-09T00:00:00.000Z | 504.6 | 1.65 | 0.0165 | 1.0165 |
| 2026-09-10T00:00:00.000Z | 504.9 | 1.41 | 0.0141 | 1.0141 |

(15 rows)

**Example: Which symbol rose most in the last 5 trading days?** (sample data: sample)

```sql
SELECT symbol, close, roc5
FROM (SELECT time, symbol, close,
             round(roc(close, 5) OVER (PARTITION BY symbol ORDER BY time), 2) AS roc5
      FROM ochl_day) t
WHERE time IN '2026-09-10'
ORDER BY roc5 DESC;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | roc5 (DOUBLE) |
|---|---|---|
| VOLT | 191.2 | 8.64 |
| CITY | 504.9 | 1.41 |
| COAST | 376.1 | 0.78 |

(3 rows)

<a id="mom"></a>

## mom, momentum

Syntax:

```sql
mom(x [, n])
momentum(x [, n])
mom(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **momentum**: the price now minus the price `n` candles ago, in the unit of the price. Above 0, the price is higher than `n` candles ago. `momentum` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | how many candles back; default `10` |

- **Returns:** `DOUBLE`, in the unit of the price.
- **NULL:** `NULL` for the first `n` candles, and when this or the old price is NULL.
- **Notes:** the same as TA-Lib's `MOM`. To compare shares with different prices, use [roc](#roc) (percent) instead.

**Example: 10-minute momentum of COAST (the last 5)** (sample data: sample)

```sql
SELECT time, close, mom10
FROM (SELECT time, close, round(momentum(close), 2) AS mom10
      FROM ochl_minutes
      WHERE symbol = 'COAST') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | mom10 (DOUBLE) |
|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 1.5 |
| 2026-09-10T09:13:00.000Z | 376.2 | 1.8 |
| 2026-09-10T09:12:00.000Z | 376 | 1.2 |
| 2026-09-10T09:11:00.000Z | 375.5 | 0.1 |
| 2026-09-10T09:10:00.000Z | 375.6 | 0.2 |

(5 rows)

**Example: The first n rows have no old price** (sample data: sample)

```sql
SELECT time, close, round(mom(close, 3), 1) AS mom3, round(close - lag(close, 3), 1) AS same
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-09-03'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | mom3 (DOUBLE) | same (DOUBLE) |
|---|---|---|---|
| 2026-09-03T00:00:00.000Z | 176 | NULL | NULL |
| 2026-09-06T00:00:00.000Z | 180.1 | NULL | NULL |
| 2026-09-07T00:00:00.000Z | 176.9 | NULL | NULL |
| 2026-09-08T00:00:00.000Z | 182.4 | 6.4 | 6.4 |
| 2026-09-09T00:00:00.000Z | 187.3 | 7.2 | 7.2 |
| 2026-09-10T00:00:00.000Z | 191.2 | 14.3 | 14.3 |

(6 rows)

## trix

Syntax:

```sql
trix(x [, n])
trix(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**TRIX**: the change from one candle to the next, in percent, of a **triple-smoothed EMA** (the EMA of the EMA of the EMA of the price). The triple smoothing removes the small moves, so TRIX shows only the bigger trend. Above 0 the trend is up, below 0 down. Traders often add a signal line (a 9-candle EMA of TRIX) and watch the crossings.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | the period of the three EMAs; default `30` |

- **Returns:** `DOUBLE` (percent: `0.05` means +0.05% per candle).
- **NULL:** `NULL` for the first `3n - 2` candles (88 with the default). **Careful:** one NULL price makes this and every later value `NULL`.
- **Notes:** the same as TA-Lib's `TRIX`. It needs many candles: use one-minute candles or a long daily history.

**Example: TRIX 30 of CITY's one-minute candles (the last 5)** (sample data: sample)

```sql
SELECT time, close, trix30
FROM (SELECT time, close, round(trix(close), 4) AS trix30
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | trix30 (DOUBLE) |
|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 0.0047 |
| 2026-09-10T09:13:00.000Z | 505.1 | 0.005 |
| 2026-09-10T09:12:00.000Z | 504.8 | 0.0053 |
| 2026-09-10T09:11:00.000Z | 504.5 | 0.0056 |
| 2026-09-10T09:10:00.000Z | 504.6 | 0.0059 |

(5 rows)

**Example: TRIX and its signal line: leave the warm-up rows out before the EMA** (sample data: sample)

```sql
SELECT time, trix15, round(ema(trix15, 9), 4) AS signal
FROM (SELECT time, trix15
      FROM (SELECT time, round(trix(close, 15), 4) AS trix15
            FROM ochl_minutes
            WHERE symbol = 'COAST') a
      WHERE trix15 IS NOT NULL) b
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | trix15 (DOUBLE) | signal (DOUBLE) |
|---|---|---|
| 2026-09-10T09:14:00.000Z | -0.0001 | -0.0035 |
| 2026-09-10T09:13:00.000Z | -0.0015 | -0.0044 |
| 2026-09-10T09:12:00.000Z | -0.0028 | -0.0051 |
| 2026-09-10T09:11:00.000Z | -0.0039 | -0.0057 |
| 2026-09-10T09:10:00.000Z | -0.0045 | -0.0061 |

(5 rows)
