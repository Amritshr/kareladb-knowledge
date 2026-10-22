# Volatility indicators and bands

> How much the price moves: true range, ATR in percent, Bollinger bands, Keltner and Donchian channels.

- Category: Functions — technical indicators
- Keywords: volatility, bands, channel, envelope, breakout, squeeze, true range, TR, TRANGE, normalized ATR, NATR, ATR percent, Bollinger bands, Bollinger, BBANDS, BB, upper band, lower band, middle band, %B, percent b, bandwidth, band width, Bollinger squeeze, Keltner channel, Keltner, KC, Donchian channel, Donchian, price channel, turtle, 20-day high, stop loss, position size, stock market
- See also: [Technical indicators](functions-indicators.md), [Momentum indicators](functions-indicators-momentum.md), [Trend indicators](functions-indicators-trend.md), [Volume indicators](functions-indicators-volume.md), [Returns and risk (volatility)](functions-returns-risk.md#volatility), [Window and series functions](functions-window.md)

**Volatility** is how much the price moves up and down. A share whose price jumps 3% a day is more volatile (more risky) than a share that moves 0.5% a day. Volatility tells you nothing about the direction.

Traders use volatility to:

- put a **stop-loss** (a price where you sell to stop a bigger loss) far enough away that normal moves do not hit it;
- draw **bands** (or channels) around the price. A band is a line above and a line below the price. When the price leaves a band, something unusual happens: a **breakout** (a strong move out of the normal range).

These functions are **series functions**, like [sma and atr](functions-indicators.md). The same rules apply:

- **Order:** without `OVER`, all result rows are one series in time order. With **many symbols**, always write `OVER (PARTITION BY symbol ORDER BY time)`.
- **Period:** `n` is how many candles the indicator looks back, a whole number of 1 or more.
- **WHERE runs first**, and candles made with `SAMPLE BY` must be made in a subquery: see the rules in [technical indicators](functions-indicators.md).
- **Warm-up:** at the start of a series there are not enough candles yet, and the result is `NULL`:

| Function (default periods) | First value on candle | NULL candles at the start |
|---|---|---|
| `trange(high, low, close)` | 2 | 1 |
| `natr(high, low, close, n)` (n = 14) | n + 1 | n |
| `bb_upper`, `bb_middle`, `bb_lower`, `bb_percent_b`, `bb_width` `(x, n)` (n = 20) | n | n - 1 |
| `kc_middle(high, low, close, n)` (n = 20) | n | n - 1 |
| `kc_upper`, `kc_lower` `(high, low, close, n, mult, atr_n)` (20, 2, 10) | the bigger of n and atr_n + 1 | one less |
| `dc_upper`, `dc_middle`, `dc_lower` `(high, low, n)` (n = 20) | n | n - 1 |

- **NULL prices:** `trange`, the Bollinger bands and the Donchian channel look at a window of candles: a NULL makes the windows that hold it `NULL`, and then the values come back. `natr` and the Keltner channel are built step by step (like `ema` and `atr`): one NULL makes this and **every later** value `NULL`. Leave NULL candles out with `WHERE`.
- **Same as TA-Lib:** `trange`, `natr` and the Bollinger bands give the same numbers as TA-Lib (TRANGE, NATR, BBANDS with a simple moving average).
- **Returns** `DOUBLE`. Use `round(x, 2)` for prices.

**Example: Bollinger bands, ATR in percent and the 20-minute channel of CITY (the last 5 minutes)** (sample data: sample)

```sql
SELECT time, close, lower_band, middle_band, upper_band, natr14, low_20, high_20
FROM (SELECT time, close,
             round(bb_lower(close, 20, 2), 2) AS lower_band,
             round(bb_middle(close, 20, 2), 2) AS middle_band,
             round(bb_upper(close, 20, 2), 2) AS upper_band,
             round(natr(high, low, close, 14), 3) AS natr14,
             dc_lower(high, low, 20) AS low_20,
             dc_upper(high, low, 20) AS high_20
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | lower_band (DOUBLE) | middle_band (DOUBLE) | upper_band (DOUBLE) | natr14 (DOUBLE) | low_20 (DOUBLE) | high_20 (DOUBLE) |
|---|---|---|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 504.1 | 504.97 | 505.84 | 0.122 | 503.9 | 506.1 |
| 2026-09-10T09:13:00.000Z | 505.1 | 504.04 | 504.95 | 505.85 | 0.12 | 503.9 | 506.1 |
| 2026-09-10T09:12:00.000Z | 504.8 | 504.04 | 504.94 | 505.84 | 0.121 | 503.9 | 506.1 |
| 2026-09-10T09:11:00.000Z | 504.5 | 504.03 | 504.94 | 505.84 | 0.122 | 503.9 | 506.1 |
| 2026-09-10T09:10:00.000Z | 504.6 | 504.08 | 504.98 | 505.87 | 0.13 | 503.9 | 506.1 |

(5 rows)

<a id="trange"></a>

## trange, true_range

Syntax:

```sql
trange(high, low, close)
true_range(high, low, close)
trange(high, low, close) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **true range** of one candle: the biggest of `high - low`, `|high - previous close|` and `|low - previous close|`. It is how far the price really moved in that candle, a **gap** included (a gap is when a candle opens far away from the previous close). `true_range` is the same function. The [atr](functions-indicators.md#atr) is the average of the true range.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close (the previous candle's close is used) |

- **Returns:** `DOUBLE`, in the same unit as the prices.
- **NULL:** `NULL` for the first candle (it has no previous close). A NULL `high` or `low` makes only that candle `NULL`. When the previous close is NULL, only `high - low` is used.
- **Notes:** there is no period. The same as TA-Lib TRANGE. The result can show rounding digits (`9.80000000000001`): use `round(x, 2)`.

**Example: A gap counts: COAST on 9 September** (sample data: sample)

```sql
SELECT time, high, low, prev_close, round(high - low, 2) AS high_minus_low, true_range
FROM (SELECT time, high, low,
             lag(close) AS prev_close,
             round(trange(high, low, close), 2) AS true_range
      FROM ochl_day
      WHERE symbol = 'COAST' AND time >= '2026-09-03') t
ORDER BY time;
```

Result:

| time (TIMESTAMP) | high (DOUBLE) | low (DOUBLE) | prev_close (DOUBLE) | high_minus_low (DOUBLE) | true_range (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-03T00:00:00.000Z | 373.6 | 364.1 | NULL | 9.5 | NULL |
| 2026-09-06T00:00:00.000Z | 378.5 | 372.5 | 373.2 | 6 | 6 |
| 2026-09-07T00:00:00.000Z | 381.1 | 373.2 | 375.4 | 7.9 | 7.9 |
| 2026-09-08T00:00:00.000Z | 380.2 | 374.7 | 379.2 | 5.5 | 5.5 |
| 2026-09-09T00:00:00.000Z | 398.8 | 379.2 | 377.2 | 19.6 | 21.6 |
| 2026-09-10T00:00:00.000Z | 382 | 373.2 | 380.1 | 8.8 | 8.8 |

(6 rows)

**Example: Plain 5-day average of the true range against Wilder's ATR** (sample data: sample)

```sql
SELECT time, true_range,
       round(avg(true_range) OVER (ORDER BY time ROWS 4 PRECEDING), 2) AS avg_5,
       atr5
FROM (SELECT time,
             round(trange(high, low, close), 2) AS true_range,
             round(atr(high, low, close, 5), 2) AS atr5
      FROM ochl_day
      WHERE symbol = 'VOLT' AND time >= '2026-08-23') t
ORDER BY time;
```

Result:

| time (TIMESTAMP) | true_range (DOUBLE) | avg_5 (DOUBLE) | atr5 (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | NULL | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 5.1 | 5.1 | NULL |
| 2026-08-25T00:00:00.000Z | 9.4 | 7.25 | NULL |
| 2026-08-26T00:00:00.000Z | 6.4 | 6.97 | NULL |
| 2026-08-27T00:00:00.000Z | 2.9 | 5.95 | NULL |
| 2026-08-30T00:00:00.000Z | 3.6 | 5.48 | 5.48 |
| 2026-08-31T00:00:00.000Z | 4.3 | 5.32 | 5.24 |
| 2026-09-01T00:00:00.000Z | 5.3 | 4.5 | 5.26 |
| 2026-09-02T00:00:00.000Z | 5.6 | 4.34 | 5.32 |
| 2026-09-03T00:00:00.000Z | 5.8 | 4.92 | 5.42 |
| 2026-09-06T00:00:00.000Z | 11.5 | 6.5 | 6.64 |
| 2026-09-07T00:00:00.000Z | 8.9 | 7.42 | 7.09 |
| 2026-09-08T00:00:00.000Z | 6.6 | 7.68 | 6.99 |
| 2026-09-09T00:00:00.000Z | 7.8 | 8.12 | 7.15 |
| 2026-09-10T00:00:00.000Z | 7.9 | 8.54 | 7.3 |

(15 rows)

**Example: high, low and close are all needed** (sample data: sample; shows an error)

```sql
SELECT trange(high, low) FROM ochl_day;
```

Result:

Error: `line 1, column 8: function 'trange' takes 3 argument(s), got 2`

## natr

Syntax:

```sql
natr(high, low, close)
natr(high, low, close, n)
natr(high, low, close, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **normalized ATR**: the [atr](functions-indicators.md#atr) divided by the close, times 100. So it is the ATR in **percent** of the price. With `natr` you can compare a 500-dollar share with a 180-dollar share: `1.5` means the price moves about 1.5% in one candle. The same as TA-Lib NATR.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close |
| `n` | whole number, 1 or more | the ATR period; default `14` |

- **Returns:** `DOUBLE`, a percent.
- **NULL:** `NULL` for the first `n` candles. A close of `0` gives `NULL`. **Careful:** a NULL `high`, `low` or `close` makes this and every later value of the series `NULL`.
- **Notes:** `natr(high, low, close, n)` is `atr(high, low, close, n) / close * 100` of the same candle.

**Example: Which share moves most? 5-day NATR on the last day** (sample data: sample)

```sql
SELECT symbol, close, natr5
FROM (SELECT time, symbol, close,
             round(natr(high, low, close, 5) OVER (PARTITION BY symbol ORDER BY time), 2) AS natr5
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE time IN '2026-09-10'
ORDER BY natr5 DESC;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | natr5 (DOUBLE) |
|---|---|---|
| VOLT | 191.2 | 3.82 |
| COAST | 376.1 | 2.58 |
| CITY | 504.9 | 1.45 |

(3 rows)

**Example: A stop-loss 2 × NATR percent below the close is the same as 2 × ATR** (sample data: sample)

```sql
SELECT symbol, close, round(natr5, 2) AS natr5,
       round(close * (1 - 2 * natr5 / 100), 1) AS stop_from_natr,
       round(close - 2 * atr5, 1) AS stop_from_atr
FROM (SELECT time, symbol, close,
             natr(high, low, close, 5) OVER (PARTITION BY symbol ORDER BY time) AS natr5,
             atr(high, low, close, 5) OVER (PARTITION BY symbol ORDER BY time) AS atr5
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE time IN '2026-09-10'
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | natr5 (DOUBLE) | stop_from_natr (DOUBLE) | stop_from_atr (DOUBLE) |
|---|---|---|---|---|
| CITY | 504.9 | 1.45 | 490.2 | 490.2 |
| COAST | 376.1 | 2.58 | 356.7 | 356.7 |
| VOLT | 191.2 | 3.82 | 176.6 | 176.6 |

(3 rows)

**Example: NATR 14 of COAST's one-minute candles (the last 5 minutes)** (sample data: sample)

```sql
SELECT time, close, natr14
FROM (SELECT time, close, round(natr(high, low, close), 4) AS natr14
      FROM ochl_minutes
      WHERE symbol = 'COAST') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | natr14 (DOUBLE) |
|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 0.1513 |
| 2026-09-10T09:13:00.000Z | 376.2 | 0.1526 |
| 2026-09-10T09:12:00.000Z | 376 | 0.1522 |
| 2026-09-10T09:11:00.000Z | 375.5 | 0.1477 |
| 2026-09-10T09:10:00.000Z | 375.6 | 0.1508 |

(5 rows)

<a id="bb_upper"></a>

## bb_upper, bb_middle, bb_lower

Syntax:

```sql
bb_upper(x)    bb_upper(x, n)    bb_upper(x, n, mult)
bb_middle(x)   bb_middle(x, n)   bb_middle(x, n, mult)
bb_lower(x)    bb_lower(x, n)    bb_lower(x, n, mult)
bb_upper(x, n, mult) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The three **Bollinger bands**. The middle band is the [sma](functions-indicators.md#sma) of the last `n` prices. The upper band is the middle band plus `mult` × the **standard deviation** of those prices (a number for how far the prices are from their average); the lower band is the middle band minus the same amount. When the price jumps around, the bands get wide; when the market is quiet, they get narrow.

With `mult` 2, most closes stay between the bands. A close **above the upper band** is a strong move up (a breakout), or a sign that the price went too far and may come back. A close below the lower band is the same, downward.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | how many candles; default `20` |
| `mult` | number | how many standard deviations away; default `2` (`2.5` is allowed) |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles. A NULL value makes the `n` results whose window holds it `NULL`; after that the bands come back.
- **Notes:**
  - The standard deviation divides by `n` (population), like John Bollinger and TA-Lib BBANDS.
  - `bb_middle` is the same as `sma(x, n)`. It takes `mult` too, so you can copy the same arguments to all three.
  - With a small `n` the close cannot leave the bands: with `n` of 5 or less and `mult` 2, it is always inside. Use the usual `n` of 20, or a smaller `mult`.

**Example: 4-day bands of CITY with mult 1.5: is the close inside?** (sample data: sample)

```sql
SELECT time, close, lower_band, middle_band, upper_band,
       CASE WHEN upper_band IS NULL THEN NULL
            WHEN close > upper_band THEN 'above'
            WHEN close < lower_band THEN 'below'
            ELSE 'inside' END AS place
FROM (SELECT time, close,
             round(bb_lower(close, 4, 1.5), 2) AS lower_band,
             round(bb_middle(close, 4, 1.5), 2) AS middle_band,
             round(bb_upper(close, 4, 1.5), 2) AS upper_band
      FROM ochl_day
      WHERE symbol = 'CITY' AND time >= '2026-08-23') t
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | lower_band (DOUBLE) | middle_band (DOUBLE) | upper_band (DOUBLE) | place (STRING) |
|---|---|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 507.9 | NULL | NULL | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 510.3 | NULL | NULL | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 513.3 | NULL | NULL | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 513.2 | 507.81 | 511.18 | 514.54 | inside |
| 2026-08-27T00:00:00.000Z | 505.9 | 506.16 | 510.68 | 515.19 | below |
| 2026-08-30T00:00:00.000Z | 503.1 | 502.15 | 508.88 | 515.6 | inside |
| 2026-08-31T00:00:00.000Z | 505.7 | 501.34 | 506.98 | 512.61 | inside |
| 2026-09-01T00:00:00.000Z | 502.4 | 501.96 | 504.28 | 506.59 | inside |
| 2026-09-02T00:00:00.000Z | 496.4 | 496.79 | 501.9 | 507.01 | below |
| 2026-09-03T00:00:00.000Z | 497.9 | 495.08 | 500.6 | 506.12 | inside |
| 2026-09-06T00:00:00.000Z | 499 | 495.61 | 498.93 | 502.24 | inside |
| 2026-09-07T00:00:00.000Z | 498.7 | 496.49 | 498 | 499.51 | inside |
| 2026-09-08T00:00:00.000Z | 497.5 | 497.37 | 498.28 | 499.18 | inside |
| 2026-09-09T00:00:00.000Z | 504.6 | 495.84 | 499.95 | 504.06 | above |
| 2026-09-10T00:00:00.000Z | 504.9 | 496.39 | 501.43 | 506.46 | inside |

(15 rows)

**Example: Breakouts: the minutes where the close crosses above the upper band (20, 2)** (sample data: sample)

```sql
SELECT time, symbol, close, round(upper_band, 3) AS upper_band
FROM (SELECT time, symbol, close, upper_band,
             lag(close) OVER (PARTITION BY symbol ORDER BY time) AS prev_close,
             lag(upper_band) OVER (PARTITION BY symbol ORDER BY time) AS prev_upper
      FROM (SELECT time, symbol, close,
                   bb_upper(close, 20, 2) OVER (PARTITION BY symbol ORDER BY time) AS upper_band
            FROM ochl_minutes
            WHERE time IN '2026-09-10') a) b
WHERE close > upper_band AND prev_close <= prev_upper
ORDER BY time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | upper_band (DOUBLE) |
|---|---|---|---|
| 2026-09-10T05:42:00.000Z | CITY | 505.7 | 505.579 |
| 2026-09-10T06:03:00.000Z | COAST | 380.9 | 380.614 |
| 2026-09-10T06:24:00.000Z | CITY | 506.4 | 506.264 |
| 2026-09-10T07:26:00.000Z | CITY | 503.1 | 503.087 |
| 2026-09-10T07:35:00.000Z | COAST | 378.8 | 378.617 |
| 2026-09-10T07:41:00.000Z | CITY | 503.6 | 503.6 |
| 2026-09-10T07:43:00.000Z | CITY | 503.7 | 503.7 |
| 2026-09-10T08:21:00.000Z | CITY | 504.2 | 504.179 |
| 2026-09-10T08:28:00.000Z | COAST | 378 | 377.938 |
| 2026-09-10T08:39:00.000Z | CITY | 506.3 | 506.298 |
| 2026-09-10T08:42:00.000Z | CITY | 506.9 | 506.823 |

(11 rows)

**Example: Wider bands with mult 3** (sample data: sample)

```sql
SELECT time, close,
       round(bb_lower(close, 5, 2), 2) AS lower_2,
       round(bb_lower(close, 5, 3), 2) AS lower_3,
       round(bb_upper(close, 5, 2), 2) AS upper_2,
       round(bb_upper(close, 5, 3), 2) AS upper_3
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-09-03'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | lower_2 (DOUBLE) | lower_3 (DOUBLE) | upper_2 (DOUBLE) | upper_3 (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-03T00:00:00.000Z | 176 | NULL | NULL | NULL | NULL |
| 2026-09-06T00:00:00.000Z | 180.1 | NULL | NULL | NULL | NULL |
| 2026-09-07T00:00:00.000Z | 176.9 | NULL | NULL | NULL | NULL |
| 2026-09-08T00:00:00.000Z | 182.4 | NULL | NULL | NULL | NULL |
| 2026-09-09T00:00:00.000Z | 187.3 | 172.38 | 168.3 | 188.7 | 192.78 |
| 2026-09-10T00:00:00.000Z | 191.2 | 173.38 | 168.28 | 193.78 | 198.88 |

(6 rows)

**Example: mult must be a number** (sample data: sample; shows an error)

```sql
SELECT bb_upper(close, 20, 'two') FROM ochl_day;
```

Result:

Error: `line 1, column 8: bb_upper: the factor must be a number, got 'two'`

<a id="bb_percent_b"></a>

## bb_percent_b

Syntax:

```sql
bb_percent_b(x)
bb_percent_b(x, n)
bb_percent_b(x, n, mult)
bb_percent_b(x, n, mult) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**%B** ("percent B") says where the price is between the Bollinger bands: `(x - lower band) / (upper band - lower band)`.

| %B | The price is |
|---|---|
| more than `1` | above the upper band |
| `1` | on the upper band |
| `0.5` | on the middle band |
| `0` | on the lower band |
| less than `0` | below the lower band |

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | how many candles; default `20` |
| `mult` | number | how many standard deviations; default `2` |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles, and when the bands are equal (all `n` prices are the same). A NULL value makes the windows that hold it `NULL`.
- **Notes:** one number instead of three lines: easy to use in `WHERE` or `CASE`.

**Example: Where is VOLT inside its 5-day bands?** (sample data: sample)

```sql
SELECT time, close, pct_b,
       CASE WHEN pct_b > 1 THEN 'above the bands'
            WHEN pct_b < 0 THEN 'below the bands'
            WHEN pct_b >= 0.5 THEN 'upper half'
            ELSE 'lower half' END AS zone
FROM (SELECT time, close, round(bb_percent_b(close, 5), 3) AS pct_b
      FROM ochl_day
      WHERE symbol = 'VOLT' AND time >= '2026-08-23') t
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | pct_b (DOUBLE) | zone (STRING) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 181 | NULL | lower half |
| 2026-08-24T00:00:00.000Z | 178.5 | NULL | lower half |
| 2026-08-25T00:00:00.000Z | 176.8 | NULL | lower half |
| 2026-08-26T00:00:00.000Z | 174.2 | NULL | lower half |
| 2026-08-27T00:00:00.000Z | 173.3 | 0.192 | lower half |
| 2026-08-30T00:00:00.000Z | 173 | 0.248 | lower half |
| 2026-08-31T00:00:00.000Z | 172.6 | 0.271 | lower half |
| 2026-09-01T00:00:00.000Z | 169 | 0.022 | lower half |
| 2026-09-02T00:00:00.000Z | 171.5 | 0.439 | lower half |
| 2026-09-03T00:00:00.000Z | 176 | 0.895 | upper half |
| 2026-09-06T00:00:00.000Z | 180.1 | 0.906 | upper half |
| 2026-09-07T00:00:00.000Z | 176.9 | 0.639 | upper half |
| 2026-09-08T00:00:00.000Z | 182.4 | 0.837 | upper half |
| 2026-09-09T00:00:00.000Z | 187.3 | 0.914 | upper half |
| 2026-09-10T00:00:00.000Z | 191.2 | 0.874 | upper half |

(15 rows)

**Example: %B of both symbols at the last minute (20, 2)** (sample data: sample)

```sql
SELECT symbol, close, pct_b
FROM (SELECT time, symbol, close,
             round(bb_percent_b(close) OVER (PARTITION BY symbol ORDER BY time), 3) AS pct_b
      FROM ochl_minutes) t
WHERE time = '2026-09-10T09:14:00Z'
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | pct_b (DOUBLE) |
|---|---|---|
| CITY | 504.9 | 0.46 |
| COAST | 376.1 | 0.901 |

(2 rows)

<a id="bb_width"></a>

## bb_width

Syntax:

```sql
bb_width(x)
bb_width(x, n)
bb_width(x, n, mult)
bb_width(x, n, mult) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **Bollinger band width**: `(upper band - lower band) / middle band`. It is how far apart the bands are, as a part of the price. `0.02` means the bands are 2% of the price apart. Very small widths are a **squeeze**: the market is quiet, and traders wait for a big move to start.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 1 or more | how many candles; default `20` |
| `mult` | number | how many standard deviations; default `2` |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles, and when the middle band is `0`. A NULL value makes the windows that hold it `NULL`.
- **Notes:** a part, not a percent: multiply by 100 for percent.

**Example: The quietest minutes of COAST: the smallest band width** (sample data: sample)

```sql
SELECT time, close, round(bb_width(close) * 100, 3) AS width_pct
FROM ochl_minutes
WHERE symbol = 'COAST'
ORDER BY width_pct
LIMIT 3;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | width_pct (DOUBLE) |
|---|---|---|
| 2026-09-10T08:04:00.000Z | 378 | 0.229 |
| 2026-09-10T08:03:00.000Z | 377.8 | 0.24 |
| 2026-09-10T06:01:00.000Z | 380.3 | 0.246 |

(3 rows)

**Example: Daily 5-day band width of every symbol** (sample data: sample)

```sql
SELECT time, symbol, close,
       round(bb_width(close, 5) OVER (PARTITION BY symbol ORDER BY time), 4) AS width
FROM ochl_day
WHERE time >= '2026-09-01'
ORDER BY time DESC, symbol
LIMIT 9;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | width (DOUBLE) |
|---|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 0.0252 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 0.019 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 0.1111 |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 0.0207 |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 0.0266 |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 0.0904 |
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | 0.0074 |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | 0.0368 |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | 0.084 |

(9 rows)

<a id="kc_upper"></a>

## kc_upper, kc_lower

Syntax:

```sql
kc_upper(high, low, close)
kc_upper(high, low, close, n)
kc_upper(high, low, close, n, mult)
kc_upper(high, low, close, n, mult, atr_n)
kc_lower(high, low, close, n, mult, atr_n)
kc_upper(high, low, close, n, mult, atr_n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **Keltner channel**: a middle line, the [ema](functions-indicators.md#ema) of the close, and two lines `mult` × [atr](functions-indicators.md#atr) above and below it. It looks like the Bollinger bands, but the width comes from the ATR, so it changes more smoothly. A close above the upper line shows a strong up trend; a close below the lower line a strong down trend.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close |
| `n` | whole number, 1 or more | the EMA period; default `20` |
| `mult` | number | how many ATRs away; default `2` |
| `atr_n` | whole number, 1 or more | the ATR period; default `10` |

- **Returns:** `DOUBLE`.
- **NULL:** the first value is on candle `n` or candle `atr_n + 1`, whichever comes later (candle 20 with the defaults). **Careful:** a NULL `high`, `low` or `close` makes this and every later value of the series `NULL`.
- **Notes:** the middle line is [kc_middle](functions-indicators-volatility.md#kc_middle). The EMA starts with the SMA of the first `n` closes and the ATR is Wilder's, like `ema` and `atr`.

**Example: Keltner channel of CITY's one-minute candles (the last 5 minutes)** (sample data: sample)

```sql
SELECT time, close, kc_low, kc_mid, kc_high
FROM (SELECT time, close,
             round(kc_lower(high, low, close), 2) AS kc_low,
             round(kc_middle(high, low, close), 2) AS kc_mid,
             round(kc_upper(high, low, close), 2) AS kc_high
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | kc_low (DOUBLE) | kc_mid (DOUBLE) | kc_high (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 503.83 | 505.06 | 506.28 |
| 2026-09-10T09:13:00.000Z | 505.1 | 503.87 | 505.07 | 506.27 |
| 2026-09-10T09:12:00.000Z | 504.8 | 503.87 | 505.07 | 506.27 |
| 2026-09-10T09:11:00.000Z | 504.5 | 503.87 | 505.1 | 506.32 |
| 2026-09-10T09:10:00.000Z | 504.6 | 503.82 | 505.16 | 506.5 |

(5 rows)

**Example: The squeeze: Bollinger bands inside the Keltner channel** (sample data: sample)

```sql
SELECT symbol, count(*) AS minutes, count_if(bb_high < kc_high AND bb_low > kc_low) AS squeeze_minutes
FROM (SELECT symbol,
             bb_upper(close) OVER (PARTITION BY symbol ORDER BY time) AS bb_high,
             bb_lower(close) OVER (PARTITION BY symbol ORDER BY time) AS bb_low,
             kc_upper(high, low, close) OVER (PARTITION BY symbol ORDER BY time) AS kc_high,
             kc_lower(high, low, close) OVER (PARTITION BY symbol ORDER BY time) AS kc_low
      FROM ochl_minutes) t
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | minutes (LONG) | squeeze_minutes (LONG) |
|---|---|---|
| CITY | 480 | 242 |
| COAST | 476 | 171 |

(2 rows)

**Example: The first value: candle 5 (n = 3, atr_n = 4)** (sample data: sample)

```sql
SELECT time, close,
       round(kc_upper(high, low, close, 3, 2, 4), 2) AS kc_high,
       round(kc_lower(high, low, close, 3, 2, 4), 2) AS kc_low
FROM ochl_day
WHERE symbol = 'COAST' AND time >= '2026-08-23'
ORDER BY time
LIMIT 6;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | kc_high (DOUBLE) | kc_low (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 391 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 384.9 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 379.8 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 373 | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 367.1 | 389.81 | 356.41 |
| 2026-08-30T00:00:00.000Z | 372.4 | 390.88 | 354.63 |

(6 rows)

<a id="kc_middle"></a>

## kc_middle

Syntax:

```sql
kc_middle(high, low, close)
kc_middle(high, low, close, n)
kc_middle(high, low, close, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The middle line of the [Keltner channel](functions-indicators-volatility.md#kc_upper): the `n`-candle [ema](functions-indicators.md#ema) of the close.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high (read, but not used in the value) |
| `low` | number | the candle's low (read, but not used in the value) |
| `close` | number | the candle's close |
| `n` | whole number, 1 or more | the EMA period; default `20` |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles. **Careful:** a NULL `high`, `low` or `close` makes this and every later value `NULL`.
- **Notes:** the same as `ema(close, n)` when no price is NULL. It takes `high` and `low` so the three Keltner functions can have the same first arguments.

**Example: kc_middle is the EMA of the close** (sample data: sample)

```sql
SELECT time, close,
       round(kc_middle(high, low, close, 5), 3) AS kc_mid,
       round(ema(close, 5), 3) AS ema5
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-08-23'
ORDER BY time
LIMIT 7;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | kc_mid (DOUBLE) | ema5 (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 507.9 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 510.3 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 513.3 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 513.2 | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 505.9 | 510.12 | 510.12 |
| 2026-08-30T00:00:00.000Z | 503.1 | 507.78 | 507.78 |
| 2026-08-31T00:00:00.000Z | 505.7 | 507.087 | 507.087 |

(7 rows)

<a id="dc_upper"></a>

## dc_upper, dc_middle, dc_lower

Syntax:

```sql
dc_upper(high, low)    dc_upper(high, low, n)
dc_middle(high, low)   dc_middle(high, low, n)
dc_lower(high, low)    dc_lower(high, low, n)
dc_upper(high, low, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **Donchian channel**: `dc_upper` is the highest high of the last `n` candles, `dc_lower` the lowest low, and `dc_middle` is halfway between them. This candle is one of the `n`.

When the price goes above the highest high of the last 20 candles, it is a **breakout**. The famous "turtle traders" bought such breakouts and sold when the price fell below the lowest low of the last 10 candles.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `n` | whole number, 1 or more | how many candles; default `20` |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles. A NULL `high` or `low` makes the `n` results whose window holds it `NULL`; after that the channel comes back.
- **Notes:**
  - `dc_upper(high, low, n)` is like `max(high) OVER (... ROWS n-1 PRECEDING)`, but it waits until it has `n` candles.
  - Because this candle is inside the window, the close can never be above `dc_upper` of the same candle. To find a breakout, compare the close with the **previous** candle's value: `lag(...)` in an outer query.

**Example: 5-day channel of VOLT, and max(high) over the same rows** (sample data: sample)

```sql
SELECT time, high, low,
       dc_lower(high, low, 5) AS low_5,
       dc_middle(high, low, 5) AS middle_5,
       dc_upper(high, low, 5) AS high_5,
       max(high) OVER (ORDER BY time ROWS 4 PRECEDING) AS max_high_5
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-08-23'
ORDER BY time
LIMIT 7;
```

Result:

| time (TIMESTAMP) | high (DOUBLE) | low (DOUBLE) | low_5 (DOUBLE) | middle_5 (DOUBLE) | high_5 (DOUBLE) | max_high_5 (DOUBLE) |
|---|---|---|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 182.6 | 178.2 | NULL | NULL | NULL | 182.6 |
| 2026-08-24T00:00:00.000Z | 183.6 | 178.5 | NULL | NULL | NULL | 183.6 |
| 2026-08-25T00:00:00.000Z | 182.2 | 172.8 | NULL | NULL | NULL | 183.6 |
| 2026-08-26T00:00:00.000Z | 178.4 | 172 | NULL | NULL | NULL | 183.6 |
| 2026-08-27T00:00:00.000Z | 175.9 | 173 | 172 | 177.8 | 183.6 | 183.6 |
| 2026-08-30T00:00:00.000Z | 174.2 | 170.6 | 170.6 | 177.1 | 183.6 | 183.6 |
| 2026-08-31T00:00:00.000Z | 175.6 | 171.3 | 170.6 | 176.4 | 182.2 | 182.2 |

(7 rows)

**Example: Turtle breakout: the close is above the high of the previous 20 minutes** (sample data: sample)

```sql
SELECT time, symbol, close, prev_high_20
FROM (SELECT time, symbol, close,
             lag(high_20) OVER (PARTITION BY symbol ORDER BY time) AS prev_high_20
      FROM (SELECT time, symbol, close,
                   dc_upper(high, low, 20) OVER (PARTITION BY symbol ORDER BY time) AS high_20
            FROM ochl_minutes
            WHERE time IN '2026-09-10') a) b
WHERE close > prev_high_20
ORDER BY time
LIMIT 6;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | prev_high_20 (DOUBLE) |
|---|---|---|---|
| 2026-09-10T05:42:00.000Z | CITY | 505.7 | 505.6 |
| 2026-09-10T05:43:00.000Z | CITY | 506 | 505.7 |
| 2026-09-10T05:44:00.000Z | CITY | 506.5 | 506.2 |
| 2026-09-10T06:03:00.000Z | COAST | 380.9 | 380.7 |
| 2026-09-10T06:04:00.000Z | COAST | 381 | 380.9 |
| 2026-09-10T06:15:00.000Z | COAST | 381.5 | 381.4 |

(6 rows)

**Example: The period must be 1 or more** (sample data: sample; shows an error)

```sql
SELECT dc_upper(high, low, 0) FROM ochl_day;
```

Result:

Error: `line 1, column 8: dc_upper: the period must be a whole number of rows (1 or more)`
