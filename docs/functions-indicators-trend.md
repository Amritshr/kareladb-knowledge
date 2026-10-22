# Trend indicators

> Is the price going up, down or sideways, and how strong is the move? ADX and DI, Aroon, parabolic SAR, Ichimoku, SuperTrend, linear regression and Heikin-Ashi candles.

- Category: Functions — technical indicators
- Keywords: cross\_above, cross\_below, crossover, crossunder, golden cross, death cross, moving average crossover, trend, trend strength, direction, up trend, down trend, sideways, directional movement, DMI, +DI, -DI, DX, average directional index, ADX, ADXR, Aroon, Aroon oscillator, parabolic SAR, SAR, stop and reverse, trailing stop, Ichimoku, Ichimoku cloud, kumo, tenkan-sen, conversion line, kijun-sen, base line, senkou span, chikou span, lagging span, SuperTrend, linear regression, LINEARREG, time series forecast, TSF, Heikin-Ashi, Heiken Ashi, HA candles, TA-Lib, TradingView, stock market
- See also: [Technical indicators](functions-indicators.md), [Momentum indicators](functions-indicators-momentum.md), [Volatility indicators and bands](functions-indicators-volatility.md), [Volume indicators](functions-indicators-volume.md), [Window and series functions](functions-window.md), [Correlation and regression (regr_slope)](functions-correlation.md#regr_slope), [Candles cookbook](candles-cookbook.md)

A **trend** is the main direction of the price over some time: up (higher highs and higher lows), down, or sideways (no clear direction). **Trend indicators** answer two questions for a trader: *which way* is the price going, and *how strong* is the move? Many traders only buy in an up trend and use a trend line as a **trailing stop**: a stop-loss price that moves up with the price, so you sell when the trend ends.

These indicators are **series functions**, like [sma and ema](functions-indicators.md). They give a value for every candle and follow the same rules:

- **Order:** without `OVER`, all result rows are one series in time order. With **many symbols**, always write `OVER (PARTITION BY symbol ORDER BY time)`.
- **Period:** `n` is a number of candles, a whole number. Every argument after the price columns has a default, so `adx(high, low, close)` is the usual 14-candle ADX.
- **WHERE runs first**, and candles from `SAMPLE BY` must be made in a subquery, with the indicator outside (see [technical indicators](functions-indicators.md)).
- **Warm-up:** the first candles have no value (`NULL`). With the default periods:

| Function | Default periods | First value on candle | NULL candles at the start |
|---|---|---|---|
| `plus_di`, `minus_di`, `dx` | n = 14 | n + 1 = 15 | 14 |
| `adx` | n = 14 | 2n = 28 | 27 |
| `adxr` | n = 14 | 3n - 1 = 41 | 40 |
| `aroon_up`, `aroon_down`, `aroon_osc` | n = 14 | n + 1 = 15 | 14 |
| `sar` | 0.02, 0.2 | 2 | 1 |
| `ichimoku_tenkan` | 9 | 9 | 8 |
| `ichimoku_kijun` | 26 | 26 | 25 |
| `ichimoku_senkou_a` | 9, 26, shift 26 | 26 + 26 = 52 | 51 |
| `ichimoku_senkou_b` | 52, shift 26 | 52 + 26 = 78 | 77 |
| `ichimoku_chikou` | shift 26 | 1 (but the **last** 26 candles are NULL) | 0 |
| `supertrend`, `supertrend_direction` | n = 10, 3 | n = 10 | 9 |
| `linearreg`, `linearreg_slope`, `linearreg_intercept`, `linearreg_angle`, `tsf` | n = 14 | n = 14 | 13 |
| `ha_open`, `ha_high`, `ha_low`, `ha_close` | none | 1 | 0 |

- **Same as TA-Lib:** DI, DX, ADX, ADXR, Aroon, SAR and the linear regression functions give the same numbers as TA-Lib. SuperTrend follows TradingView (`ta.supertrend`). Ichimoku and Heikin-Ashi use the usual textbook formulas.
- **NULL prices:** the step-by-step indicators (`plus_di`, `minus_di`, `dx`, `adx`, `adxr`, `sar`, `supertrend`, `supertrend_direction`, the `ha_` functions) **stop** at the first NULL: that candle and every later one is `NULL`. The window indicators (Aroon, Ichimoku, linear regression) come back once the NULL is out of their window. Leave NULL candles out with `WHERE`.
- **Returns** `DOUBLE`, except `supertrend_direction` (`LONG`). Use `round(x, 2)` for prices.

**Example: The trend of CITY in its last 5 minutes: ADX, DI, SuperTrend and SAR** (sample data: sample)

```sql
SELECT time, close, adx14, plus_di14, minus_di14, st_dir, sar
FROM (SELECT time, close,
             round(adx(high, low, close), 1) AS adx14,
             round(plus_di(high, low, close), 1) AS plus_di14,
             round(minus_di(high, low, close), 1) AS minus_di14,
             supertrend_direction(high, low, close) AS st_dir,
             round(sar(high, low), 2) AS sar
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | adx14 (DOUBLE) | plus_di14 (DOUBLE) | minus_di14 (DOUBLE) | st_dir (LONG) | sar (DOUBLE) |
|---|---|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 16.7 | 17.3 | 17.9 | -1 | 505.78 |
| 2026-09-10T09:13:00.000Z | 505.1 | 17.9 | 18.9 | 18.2 | -1 | 505.84 |
| 2026-09-10T09:12:00.000Z | 504.8 | 19.1 | 14 | 19.6 | -1 | 505.9 |
| 2026-09-10T09:11:00.000Z | 504.5 | 19.3 | 14.9 | 20.8 | -1 | 505.97 |
| 2026-09-10T09:10:00.000Z | 504.6 | 19.5 | 15 | 21.1 | -1 | 506.04 |

(5 rows)

**Example: A NULL high: the step-by-step indicators stop, the window ones come back** (sample data: sample)

Setup:

```sql
CREATE TABLE candles (time TIMESTAMP, open DOUBLE, high DOUBLE, low DOUBLE, close DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO candles VALUES
  ('2026-09-01', 10, 11, 9, 10.5), ('2026-09-02', 10.5, 12, 10, 11.5), ('2026-09-03', 11.5, 12.5, 11, 12),
  ('2026-09-04', 12, NULL, 11.5, 12.2), ('2026-09-05', 12.2, 13, 12, 12.8), ('2026-09-06', 12.8, 13.5, 12.5, 13.2),
  ('2026-09-07', 13.2, 14, 13, 13.9), ('2026-09-08', 13.9, 14.2, 13.1, 13.3);
```

```sql
SELECT time, high,
       round(sar(high, low), 2) AS sar,
       round(ha_close(open, high, low, close), 2) AS ha_close,
       round(aroon_up(high, 2), 1) AS aroon_up2,
       round(linearreg_slope(high, 2), 2) AS slope2
FROM candles
ORDER BY time;
```

Result:

| time (TIMESTAMP) | high (DOUBLE) | sar (DOUBLE) | ha_close (DOUBLE) | aroon_up2 (DOUBLE) | slope2 (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 11 | NULL | 10.13 | NULL | NULL |
| 2026-09-02T00:00:00.000Z | 12 | 9 | 11 | NULL | 1 |
| 2026-09-03T00:00:00.000Z | 12.5 | 9.06 | 11.75 | 100 | 0.5 |
| 2026-09-04T00:00:00.000Z | NULL | NULL | NULL | NULL | NULL |
| 2026-09-05T00:00:00.000Z | 13 | NULL | NULL | NULL | NULL |
| 2026-09-06T00:00:00.000Z | 13.5 | NULL | NULL | NULL | 0.5 |
| 2026-09-07T00:00:00.000Z | 14 | NULL | NULL | 100 | 0.5 |
| 2026-09-08T00:00:00.000Z | 14.2 | NULL | NULL | 100 | 0.2 |

(8 rows)

<a id="cross_above"></a>

## cross_above, cross_below

Syntax:

```sql
cross_above(a, b) OVER ([PARTITION BY ...] [ORDER BY ...])
cross_below(a, b) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**Crossings**: `cross_above` is `true` on the candle where `a` goes from at or below `b` to above it, `cross_below` where it goes from at or above `b` to below it. With two moving averages that is the **golden cross** (fast above slow) and the **death cross**. `crossover` and `crossunder` are other names for them (TradingView's).

| Argument | Type | Meaning |
|---|---|---|
| `a`, `b` | number | two series, or a series and a fixed level (`cross_above(rsi(close, 14), 30)`) |

- **Returns:** `BOOL`: `true` on the crossing candle, `false` on the others.
- **NULL:** on the first candle, and where `a` or `b` is `NULL` on this candle or the one before.
- **Notes:** `a` and `b` may themselves be indicators, as in `cross_above(sma(close, 20), sma(close, 50)) OVER (...)`: an indicator written inside another one without its own `OVER` takes the `PARTITION BY` and `ORDER BY` of the one it is in ([indicators inside indicators](candles-cookbook.md#moving-averages)).

**Example: Golden and death crosses of CITY: 3-day average against 8-day** (sample data: sample)

```sql
SELECT time, close, signal
FROM (
  SELECT time, close,
         CASE WHEN cross_above(sma(close, 3), sma(close, 8)) OVER (ORDER BY time) THEN 'golden'
              WHEN cross_below(sma(close, 3), sma(close, 8)) OVER (ORDER BY time) THEN 'death' END AS signal
  FROM ochl_day
  WHERE symbol = 'CITY' AND time IN '2026'
) s
WHERE signal IS NOT NULL
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | signal (STRING) |
|---|---|---|
| 2026-09-10T00:00:00.000Z | 504.9 | golden |

(1 row)

**Example: Symbols whose 3-day average crossed above their 8-day one on the last day** (sample data: sample)

```sql
SELECT symbol, time
FROM (
  SELECT symbol, time,
         cross_above(sma(close, 3), sma(close, 8)) OVER (PARTITION BY symbol ORDER BY time) AS up,
         row_number() OVER (PARTITION BY symbol ORDER BY time DESC) AS rn
  FROM ochl_day
) s
WHERE rn = 1 AND up
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | time (TIMESTAMP) |
|---|---|
| CITY | 2026-09-10T00:00:00.000Z |

(1 row)

<a id="plus_di"></a>

## plus_di, minus_di

Syntax:

```sql
plus_di(high, low, close)
plus_di(high, low, close, n)
minus_di(high, low, close, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **directional indicators** +DI and -DI (Welles Wilder's "directional movement"). **+DI** measures how strongly the highs push **up**; **-DI** how strongly the lows push **down**. Both are in percent of the [true range](functions-indicators.md#atr). When +DI is above -DI, the buyers are stronger (an up trend); when -DI is above +DI, the sellers are stronger. A cross of the two lines is a common buy or sell signal.

Each candle's upward move is `high - previous high`, its downward move is `previous low - low`; only the bigger one counts (and only when it is more than 0). Both moves and the true range get Wilder's smoothing over `n` candles, and `+DI = 100 × smoothed up move / smoothed true range`.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close |
| `n` | whole number, 2 or more | the period; default `14` |

- **Returns:** `DOUBLE` from 0 to 100.
- **NULL:** `NULL` for the first `n` candles. A NULL `high`, `low` or `close` makes that candle and every later one `NULL`.
- **Notes:** the same as TA-Lib `PLUS_DI` and `MINUS_DI`. Use [adx](#adx) to see whether the trend is strong enough to follow.

**Example: +DI and -DI of COAST in the last 5 minutes** (sample data: sample)

```sql
SELECT time, close, plus_di14, minus_di14,
       CASE WHEN plus_di14 > minus_di14 THEN 'buyers stronger' ELSE 'sellers stronger' END AS side
FROM (SELECT time, close,
             round(plus_di(high, low, close), 1) AS plus_di14,
             round(minus_di(high, low, close), 1) AS minus_di14
      FROM ochl_minutes
      WHERE symbol = 'COAST') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | plus_di14 (DOUBLE) | minus_di14 (DOUBLE) | side (STRING) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 27.7 | 14.4 | buyers stronger |
| 2026-09-10T09:13:00.000Z | 376.2 | 26.9 | 15.4 | buyers stronger |
| 2026-09-10T09:12:00.000Z | 376 | 29 | 16.7 | buyers stronger |
| 2026-09-10T09:11:00.000Z | 375.5 | 22.5 | 18.5 | buyers stronger |
| 2026-09-10T09:10:00.000Z | 375.6 | 23.8 | 19.5 | buyers stronger |

(5 rows)

**Example: DI crossover: the first 5 minutes of 10 September when CITY's +DI crossed above -DI** (sample data: sample)

```sql
SELECT time, close, plus_di14, minus_di14
FROM (SELECT time, close, plus_di14, minus_di14,
             lag(plus_di14) AS prev_plus, lag(minus_di14) AS prev_minus
      FROM (SELECT time, close,
                   round(plus_di(high, low, close), 1) AS plus_di14,
                   round(minus_di(high, low, close), 1) AS minus_di14
            FROM ochl_minutes
            WHERE symbol = 'CITY') a) b
WHERE plus_di14 > minus_di14 AND prev_plus <= prev_minus AND time IN '2026-09-10'
ORDER BY time
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | plus_di14 (DOUBLE) | minus_di14 (DOUBLE) |
|---|---|---|---|
| 2026-09-10T05:41:00.000Z | 505.4 | 18.5 | 16.6 |
| 2026-09-10T05:59:00.000Z | 506.4 | 22.6 | 16.4 |
| 2026-09-10T06:06:00.000Z | 505.5 | 16.2 | 14.7 |
| 2026-09-10T06:10:00.000Z | 505.9 | 15.1 | 14.9 |
| 2026-09-10T06:18:00.000Z | 505.6 | 19.7 | 19.3 |

(5 rows)

**Example: The period must be 2 or more** (sample data: sample; shows an error)

```sql
SELECT plus_di(high, low, close, 1) FROM ochl_day;
```

Result:

Error: `line 1, column 8: plus_di: the period must be a whole number of rows (2 or more)`

## dx

Syntax:

```sql
dx(high, low, close)
dx(high, low, close, n)
dx(high, low, close, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **directional movement index**: how far apart +DI and -DI are, `DX = 100 × |+DI - -DI| / (+DI + -DI)`. A big DX means one side (buyers or sellers) is much stronger. DX jumps a lot from candle to candle; most traders use its smooth average, [adx](#adx).

| Argument | Type | Meaning |
|---|---|---|
| `high`, `low`, `close` | number | the candle's high, low and close |
| `n` | whole number, 2 or more | the period; default `14` |

- **Returns:** `DOUBLE` from 0 to 100.
- **NULL:** `NULL` for the first `n` candles. A NULL price stops the series (that candle and every later one is `NULL`).
- **Notes:** the same as TA-Lib `DX`. When +DI and -DI are both 0, DX keeps its previous value.

**Example: DX jumps, ADX is smooth (CITY daily, 3-day period)** (sample data: sample)

```sql
SELECT time, close,
       round(dx(high, low, close, 3), 1) AS dx3,
       round(adx(high, low, close, 3), 1) AS adx3
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | dx3 (DOUBLE) | adx3 (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 507.9 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 510.3 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 513.3 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 513.2 | 100 | NULL |
| 2026-08-27T00:00:00.000Z | 505.9 | 20.9 | NULL |
| 2026-08-30T00:00:00.000Z | 503.1 | 36.4 | 52.4 |
| 2026-08-31T00:00:00.000Z | 505.7 | 51.1 | 52 |
| 2026-09-01T00:00:00.000Z | 502.4 | 17.9 | 40.6 |
| 2026-09-02T00:00:00.000Z | 496.4 | 70.9 | 50.7 |
| 2026-09-03T00:00:00.000Z | 497.9 | 70.9 | 57.5 |
| 2026-09-06T00:00:00.000Z | 499 | 70.9 | 61.9 |
| 2026-09-07T00:00:00.000Z | 498.7 | 77.7 | 67.2 |
| 2026-09-08T00:00:00.000Z | 497.5 | 71.7 | 68.7 |
| 2026-09-09T00:00:00.000Z | 504.6 | 74.4 | 70.6 |
| 2026-09-10T00:00:00.000Z | 504.9 | 27 | 56.1 |

(15 rows)

## adx

Syntax:

```sql
adx(high, low, close)
adx(high, low, close, n)
adx(high, low, close, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **average directional index**: the **strength** of the trend, from 0 to 100, without its direction. It is Wilder's average of [dx](#dx) over `n` candles. Traders read it like this:

- **below 20:** no real trend, the price moves sideways;
- **above 25:** a strong trend. Then look at [+DI and -DI](#plus_di) for the direction: +DI above -DI is a strong up trend, -DI above +DI a strong down trend;
- **ADX rising:** the trend is getting stronger.

| Argument | Type | Meaning |
|---|---|---|
| `high`, `low`, `close` | number | the candle's high, low and close |
| `n` | whole number, 2 or more | the period; default `14` |

- **Returns:** `DOUBLE` from 0 to 100.
- **NULL:** `NULL` for the first `2n - 1` candles (27 with the default 14). A NULL price stops the series.
- **Notes:** the same as TA-Lib `ADX`. Because it is an average of an average, ADX is slow: it needs about `2n` candles to start and more to settle. Load more history than you show.

**Example: Strong or weak trend? COAST in the last 5 minutes** (sample data: sample)

```sql
SELECT time, close, adx14, plus_di14, minus_di14,
       CASE WHEN adx14 > 25 AND plus_di14 > minus_di14 THEN 'strong up'
            WHEN adx14 > 25 THEN 'strong down'
            ELSE 'weak' END AS trend
FROM (SELECT time, close,
             round(adx(high, low, close), 1) AS adx14,
             round(plus_di(high, low, close), 1) AS plus_di14,
             round(minus_di(high, low, close), 1) AS minus_di14
      FROM ochl_minutes
      WHERE symbol = 'COAST') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | adx14 (DOUBLE) | plus_di14 (DOUBLE) | minus_di14 (DOUBLE) | trend (STRING) |
|---|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 17.7 | 27.7 | 14.4 | weak |
| 2026-09-10T09:13:00.000Z | 376.2 | 16.6 | 26.9 | 15.4 | weak |
| 2026-09-10T09:12:00.000Z | 376 | 15.8 | 29 | 16.7 | weak |
| 2026-09-10T09:11:00.000Z | 375.5 | 15 | 22.5 | 18.5 | weak |
| 2026-09-10T09:10:00.000Z | 375.6 | 15.4 | 23.8 | 19.5 | weak |

(5 rows)

**Example: How many minutes each symbol spent in a strong up, strong down or weak trend** (sample data: sample)

```sql
SELECT symbol, trend, count(*) AS minutes
FROM (SELECT symbol,
             CASE WHEN adx14 IS NULL THEN 'warm-up'
                  WHEN adx14 > 25 AND plus_di14 > minus_di14 THEN 'strong up'
                  WHEN adx14 > 25 THEN 'strong down'
                  ELSE 'weak' END AS trend
      FROM (SELECT symbol,
                   adx(high, low, close) OVER (PARTITION BY symbol ORDER BY time) AS adx14,
                   plus_di(high, low, close) OVER (PARTITION BY symbol ORDER BY time) AS plus_di14,
                   minus_di(high, low, close) OVER (PARTITION BY symbol ORDER BY time) AS minus_di14
            FROM ochl_minutes) a) b
GROUP BY symbol, trend
ORDER BY symbol, trend;
```

Result:

| symbol (SYMBOL) | trend (STRING) | minutes (LONG) |
|---|---|---|
| CITY | strong down | 153 |
| CITY | strong up | 73 |
| CITY | warm-up | 27 |
| CITY | weak | 227 |
| COAST | strong down | 159 |
| COAST | strong up | 16 |
| COAST | warm-up | 27 |
| COAST | weak | 274 |

(8 rows)

## adxr

Syntax:

```sql
adxr(high, low, close)
adxr(high, low, close, n)
adxr(high, low, close, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **average directional movement rating**: the average of today's [adx](#adx) and the ADX of `n - 1` candles ago. It is an even smoother trend strength. Some traders compare ADX with ADXR: ADX above ADXR means the trend is getting stronger.

| Argument | Type | Meaning |
|---|---|---|
| `high`, `low`, `close` | number | the candle's high, low and close |
| `n` | whole number, 2 or more | the period; default `14` |

- **Returns:** `DOUBLE` from 0 to 100.
- **NULL:** `NULL` for the first `3n - 2` candles (40 with the default 14). A NULL price stops the series.
- **Notes:** the same as TA-Lib `ADXR`.

**Example: ADX against ADXR: is the trend of CITY getting stronger?** (sample data: sample)

```sql
SELECT time, close, adx14, adxr14,
       CASE WHEN adx14 > adxr14 THEN 'stronger' ELSE 'weaker' END AS strength
FROM (SELECT time, close,
             round(adx(high, low, close), 1) AS adx14,
             round(adxr(high, low, close), 1) AS adxr14
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | adx14 (DOUBLE) | adxr14 (DOUBLE) | strength (STRING) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 16.7 | 21.4 | weaker |
| 2026-09-10T09:13:00.000Z | 505.1 | 17.9 | 22.9 | weaker |
| 2026-09-10T09:12:00.000Z | 504.8 | 19.1 | 24.5 | weaker |
| 2026-09-10T09:11:00.000Z | 504.5 | 19.3 | 25.5 | weaker |
| 2026-09-10T09:10:00.000Z | 504.6 | 19.5 | 26.2 | weaker |

(5 rows)

<a id="aroon_up"></a>

## aroon_up, aroon_down

Syntax:

```sql
aroon_up(high)
aroon_up(high, n)
aroon_down(low, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **Aroon** indicator ("dawn's early light" in Sanskrit) asks: how long ago was the highest high, and how long ago the lowest low? It looks at this candle and the `n` candles before it.

- `aroon_up = 100 × (n - candles since the highest high) / n`. **100** means today made a new `n`-candle high; **0** means the high was `n` candles ago.
- `aroon_down` is the same with the lowest low.
- Aroon up above 70 and Aroon down below 30 is a strong up trend; the other way round a strong down trend. When the two lines cross, the trend may be changing.

| Argument | Type | Meaning |
|---|---|---|
| `high` (or `low`) | number | the highs for `aroon_up`, the lows for `aroon_down` |
| `n` | whole number, 1 or more | the period; default `14` |

- **Returns:** `DOUBLE` from 0 to 100.
- **NULL:** `NULL` for the first `n` candles, and while a NULL value is in the window of `n + 1` candles.
- **Notes:** the same as TA-Lib `AROON`. When the highest high appears twice in the window, the later one counts.

**Example: Aroon of VOLT on daily candles (5-day period)** (sample data: sample)

```sql
SELECT time, high, low,
       round(aroon_up(high, 5), 1) AS aroon_up5,
       round(aroon_down(low, 5), 1) AS aroon_down5
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | high (DOUBLE) | low (DOUBLE) | aroon_up5 (DOUBLE) | aroon_down5 (DOUBLE) |
|---|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 182.6 | 178.2 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 183.6 | 178.5 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 182.2 | 172.8 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 178.4 | 172 | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 175.9 | 173 | NULL | NULL |
| 2026-08-30T00:00:00.000Z | 174.2 | 170.6 | 20 | 100 |
| 2026-08-31T00:00:00.000Z | 175.6 | 171.3 | 0 | 80 |
| 2026-09-01T00:00:00.000Z | 172.1 | 167.3 | 0 | 100 |
| 2026-09-02T00:00:00.000Z | 174.6 | 169 | 0 | 80 |
| 2026-09-03T00:00:00.000Z | 177.3 | 171.9 | 100 | 60 |
| 2026-09-06T00:00:00.000Z | 183.9 | 172.4 | 100 | 40 |
| 2026-09-07T00:00:00.000Z | 183.2 | 174.3 | 80 | 20 |
| 2026-09-08T00:00:00.000Z | 183.5 | 178.2 | 60 | 0 |
| 2026-09-09T00:00:00.000Z | 189.5 | 181.7 | 100 | 0 |
| 2026-09-10T00:00:00.000Z | 192.1 | 184.2 | 100 | 0 |

(15 rows)

<a id="aroon_osc"></a>

## aroon_osc

Syntax:

```sql
aroon_osc(high, low)
aroon_osc(high, low, n)
aroon_osc(high, low, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **Aroon oscillator**: `aroon_up(high, n) - aroon_down(low, n)`, one line from -100 to 100. Above 0, the recent high is newer than the recent low (the price is climbing); below 0, the other way round. Near +100 or -100, the trend is strong.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `n` | whole number, 1 or more | the period; default `14` |

- **Returns:** `DOUBLE` from -100 to 100.
- **NULL:** `NULL` for the first `n` candles, and while a NULL high or low is in the window.
- **Notes:** the same as TA-Lib `AROONOSC`. Both `high` and `low` are needed: `aroon_osc(high, 5)` reads `5` as the lows.

**Example: Aroon oscillator of every symbol on the last day** (sample data: sample)

```sql
SELECT time, symbol, close, aroon_osc5
FROM (SELECT time, symbol, close,
             round(aroon_osc(high, low, 5) OVER (PARTITION BY symbol ORDER BY time), 1) AS aroon_osc5
      FROM ochl_day) t
WHERE time IN '2026-09-10'
ORDER BY aroon_osc5 DESC;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | aroon_osc5 (DOUBLE) |
|---|---|---|---|
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 100 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 80 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 40 |

(3 rows)

<a id="sar"></a>

## sar, parabolic_sar

Syntax:

```sql
sar(high, low)
sar(high, low, acceleration, maximum)
parabolic_sar(high, low, acceleration, maximum) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **parabolic SAR** ("stop and reverse"). On a chart it is a row of dots: **below** the candles in an up trend, **above** them in a down trend. Traders use it as a **trailing stop**: in an up trend, sell when the price falls under the dot. When the price crosses the dot, the SAR jumps to the other side and the trend is "reversed". `parabolic_sar` is the same function.

Each candle, the dot moves toward the price by `acceleration factor × (extreme price - SAR)`. The factor starts at `acceleration`, grows by `acceleration` every time the trend makes a new high (or low), and never goes above `maximum`. So the dot follows the price faster the longer the trend lasts.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `acceleration` | number, more than 0 | the start and the step of the factor; default `0.02` |
| `maximum` | number, more than 0 | the biggest factor; default `0.2` |

- **Returns:** `DOUBLE` (a price).
- **NULL:** `NULL` for the first candle. A NULL `high` or `low` stops the series (that candle and every later one is `NULL`).
- **Notes:** the same as TA-Lib `SAR`. The first trend (up or down) is chosen from the first two candles. An `acceleration` bigger than `maximum` is lowered to `maximum`. A smaller `acceleration` gives a slower dot, further from the price.

**Example: SAR of CITY's daily candles: where the trend reversed** (sample data: sample)

```sql
SELECT time, low, high, close, sar,
       CASE WHEN sar <= low THEN 'dot below: up trend'
            WHEN sar >= high THEN 'dot above: down trend' END AS trend
FROM (SELECT time, low, high, close, round(sar(high, low), 2) AS sar
      FROM ochl_day
      WHERE symbol = 'CITY' AND time >= '2026-08-23') t
ORDER BY time;
```

Result:

| time (TIMESTAMP) | low (DOUBLE) | high (DOUBLE) | close (DOUBLE) | sar (DOUBLE) | trend (STRING) |
|---|---|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 502 | 508.4 | 507.9 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 508.2 | 510.9 | 510.3 | 502 | dot below: up trend |
| 2026-08-25T00:00:00.000Z | 507.6 | 517 | 513.3 | 502.18 | dot below: up trend |
| 2026-08-26T00:00:00.000Z | 508 | 515.3 | 513.2 | 502.77 | dot below: up trend |
| 2026-08-27T00:00:00.000Z | 505.5 | 514.3 | 505.9 | 503.34 | dot below: up trend |
| 2026-08-30T00:00:00.000Z | 501.7 | 511.2 | 503.1 | 517 | dot above: down trend |
| 2026-08-31T00:00:00.000Z | 500.1 | 506 | 505.7 | 516.69 | dot above: down trend |
| 2026-09-01T00:00:00.000Z | 501.3 | 507.3 | 502.4 | 516.03 | dot above: down trend |
| 2026-09-02T00:00:00.000Z | 494.1 | 502.8 | 496.4 | 515.39 | dot above: down trend |
| 2026-09-03T00:00:00.000Z | 495.5 | 500.9 | 497.9 | 514.12 | dot above: down trend |
| 2026-09-06T00:00:00.000Z | 496 | 500.1 | 499 | 512.91 | dot above: down trend |
| 2026-09-07T00:00:00.000Z | 495 | 501 | 498.7 | 511.79 | dot above: down trend |
| 2026-09-08T00:00:00.000Z | 497.5 | 501.1 | 497.5 | 510.72 | dot above: down trend |
| 2026-09-09T00:00:00.000Z | 504 | 512.4 | 504.6 | 494.1 | dot below: up trend |
| 2026-09-10T00:00:00.000Z | 500.7 | 507 | 504.9 | 494.47 | dot below: up trend |

(15 rows)

**Example: A trailing stop from the SAR, for the last 5 minutes of CITY** (sample data: sample)

```sql
SELECT time, close, sar_stop,
       CASE WHEN sar_stop < close THEN 'hold: sell below the stop' ELSE 'down trend: stay out' END AS action
FROM (SELECT time, close, round(sar(high, low), 2) AS sar_stop
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | sar_stop (DOUBLE) | action (STRING) |
|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 505.78 | down trend: stay out |
| 2026-09-10T09:13:00.000Z | 505.1 | 505.84 | down trend: stay out |
| 2026-09-10T09:12:00.000Z | 504.8 | 505.9 | down trend: stay out |
| 2026-09-10T09:11:00.000Z | 504.5 | 505.97 | down trend: stay out |
| 2026-09-10T09:10:00.000Z | 504.6 | 506.04 | down trend: stay out |

(5 rows)

**Example: A slower SAR: acceleration 0.01, maximum 0.1** (sample data: sample)

```sql
SELECT time, close,
       round(sar(high, low), 2) AS sar_default,
       round(parabolic_sar(high, low, 0.01, 0.1), 2) AS sar_slow
FROM ochl_day
WHERE symbol = 'COAST' AND time >= '2026-09-01'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | sar_default (DOUBLE) | sar_slow (DOUBLE) |
|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 367.4 | NULL | NULL |
| 2026-09-02T00:00:00.000Z | 369.2 | 365.3 | 365.3 |
| 2026-09-03T00:00:00.000Z | 373.2 | 373.6 | 373.6 |
| 2026-09-06T00:00:00.000Z | 375.4 | 364.1 | 364.1 |
| 2026-09-07T00:00:00.000Z | 379.2 | 364.1 | 364.1 |
| 2026-09-08T00:00:00.000Z | 377.2 | 364.78 | 364.44 |
| 2026-09-09T00:00:00.000Z | 380.1 | 365.43 | 364.77 |
| 2026-09-10T00:00:00.000Z | 376.1 | 367.43 | 365.79 |

(8 rows)

**Example: acceleration and maximum must be more than 0** (sample data: sample; shows an error)

```sql
SELECT sar(high, low, 0, 0.2) FROM ochl_day;
```

Result:

Error: `line 1, column 8: sar: the acceleration and the maximum must be more than 0`

<a id="ichimoku_tenkan"></a>

## ichimoku_tenkan, ichimoku_kijun

Syntax:

```sql
ichimoku_tenkan(high, low)
ichimoku_tenkan(high, low, n)
ichimoku_kijun(high, low, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**Ichimoku** ("one look" in Japanese) is a whole trend system drawn on the chart. Its lines are middle prices: `(highest high + lowest low) / 2` of the last `n` candles.

- `ichimoku_tenkan` is the **tenkan-sen** (conversion line), a fast line: default 9 candles.
- `ichimoku_kijun` is the **kijun-sen** (base line), a slow line: default 26 candles.
- Tenkan above kijun is a sign of an up trend; a cross of tenkan above kijun is a buy signal ("TK cross").

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `n` | whole number, 1 or more | the period; default `9` for tenkan, `26` for kijun |

- **Returns:** `DOUBLE` (a price).
- **NULL:** `NULL` for the first `n - 1` candles, and while a NULL high or low is in the window.
- **Notes:** the classic periods 9, 26 and 52 were made for a 6-day trading week. Some traders use other periods; all of them can be changed.

**Example: Tenkan and kijun of COAST in the last 5 minutes** (sample data: sample)

```sql
SELECT time, close, tenkan, kijun,
       CASE WHEN tenkan > kijun THEN 'up' WHEN tenkan < kijun THEN 'down' ELSE 'flat' END AS signal
FROM (SELECT time, close,
             round(ichimoku_tenkan(high, low), 2) AS tenkan,
             round(ichimoku_kijun(high, low), 2) AS kijun
      FROM ochl_minutes
      WHERE symbol = 'COAST') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | tenkan (DOUBLE) | kijun (DOUBLE) | signal (STRING) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 375.45 | 375.4 | up |
| 2026-09-10T09:13:00.000Z | 376.2 | 375.35 | 375.25 | up |
| 2026-09-10T09:12:00.000Z | 376 | 375.3 | 375.05 | up |
| 2026-09-10T09:11:00.000Z | 375.5 | 375 | 374.85 | up |
| 2026-09-10T09:10:00.000Z | 375.6 | 375 | 374.75 | up |

(5 rows)

<a id="ichimoku_senkou_a"></a>

## ichimoku_senkou_a

Syntax:

```sql
ichimoku_senkou_a(high, low)
ichimoku_senkou_a(high, low, short, long, shift)
ichimoku_senkou_a(high, low, short, long, shift) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**Senkou span A**, the first edge of the Ichimoku **cloud** (kumo): `(tenkan + kijun) / 2`, made `shift` candles ago. A chart draws the cloud 26 candles ahead of the price; KarelaDB puts on each row the cloud value that the chart shows **under that candle**, so you can compare it with the row's price directly.

| Argument | Type | Meaning |
|---|---|---|
| `high`, `low` | number | the candle's high and low |
| `short` | whole number, 1 or more | the tenkan period; default `9` |
| `long` | whole number, 1 or more | the kijun period; default `26` |
| `shift` | whole number, 0 or more | how many candles back the value was made; default `26` |

- **Returns:** `DOUBLE` (a price).
- **NULL:** `NULL` for the first `long + shift - 1` candles (51 with the defaults; when `short` is the bigger period, `short + shift - 1`), and while a NULL high or low is in the window.
- **Notes:** with `shift` 0 you get the value made on this candle, as a chart would draw it 26 candles later.

**Example: Senkou span A with shift 0 is the average of tenkan and kijun** (sample data: sample)

```sql
SELECT time, tenkan, kijun, span_a_now
FROM (SELECT time,
             round(ichimoku_tenkan(high, low), 2) AS tenkan,
             round(ichimoku_kijun(high, low), 2) AS kijun,
             round(ichimoku_senkou_a(high, low, 9, 26, 0), 2) AS span_a_now
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 3;
```

Result:

| time (TIMESTAMP) | tenkan (DOUBLE) | kijun (DOUBLE) | span_a_now (DOUBLE) |
|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 505.1 | 505.35 | 505.23 |
| 2026-09-10T09:13:00.000Z | 505.2 | 505.35 | 505.28 |
| 2026-09-10T09:12:00.000Z | 505.2 | 505.35 | 505.28 |

(3 rows)

<a id="ichimoku_senkou_b"></a>

## ichimoku_senkou_b

Syntax:

```sql
ichimoku_senkou_b(high, low)
ichimoku_senkou_b(high, low, n, shift)
ichimoku_senkou_b(high, low, n, shift) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**Senkou span B**, the second edge of the Ichimoku cloud: the middle price `(highest high + lowest low) / 2` of the last `n` candles (default 52), made `shift` candles ago. Together with [senkou span A](#ichimoku_senkou_a):

- price **above** the cloud (above both spans): up trend;
- price **below** the cloud: down trend;
- price **inside** the cloud: no clear trend. A thick cloud is strong support or resistance (a price level that is hard to break).

| Argument | Type | Meaning |
|---|---|---|
| `high`, `low` | number | the candle's high and low |
| `n` | whole number, 1 or more | the period; default `52` |
| `shift` | whole number, 0 or more | how many candles back the value was made; default `26` |

- **Returns:** `DOUBLE` (a price).
- **NULL:** `NULL` for the first `n + shift - 1` candles (77 with the defaults), and while a NULL high or low is in the window.

**Example: Is CITY above, below or inside the Ichimoku cloud?** (sample data: sample)

```sql
SELECT time, close, span_a, span_b,
       CASE WHEN close > greatest(span_a, span_b) THEN 'above the cloud: up trend'
            WHEN close < least(span_a, span_b) THEN 'below the cloud: down trend'
            ELSE 'inside the cloud' END AS position
FROM (SELECT time, close,
             round(ichimoku_senkou_a(high, low), 2) AS span_a,
             round(ichimoku_senkou_b(high, low), 2) AS span_b
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | span_a (DOUBLE) | span_b (DOUBLE) | position (STRING) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 505.95 | 504.45 | inside the cloud |
| 2026-09-10T09:13:00.000Z | 505.1 | 505.93 | 504.45 | inside the cloud |
| 2026-09-10T09:12:00.000Z | 504.8 | 505.88 | 504.45 | inside the cloud |
| 2026-09-10T09:11:00.000Z | 504.5 | 505.65 | 504.45 | inside the cloud |
| 2026-09-10T09:10:00.000Z | 504.6 | 505.48 | 504.45 | inside the cloud |

(5 rows)

<a id="ichimoku_chikou"></a>

## ichimoku_chikou

Syntax:

```sql
ichimoku_chikou(close)
ichimoku_chikou(close, shift)
ichimoku_chikou(close, shift) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**Chikou span** (the lagging line) of Ichimoku. A chart draws today's close `shift` candles **back** in time. So in KarelaDB, each row gets the close from `shift` rows **later**. It lets you compare the price then with the price 26 candles later: chikou above the old price means the price has risen since.

| Argument | Type | Meaning |
|---|---|---|
| `close` | number | the candle's close |
| `shift` | whole number, 0 or more | how many candles later the close comes from; default `26` |

- **Returns:** `DOUBLE` (a price).
- **NULL:** the **last** `shift` candles are `NULL` (there is no later close yet). A NULL close gives `NULL` on the row `shift` candles before it.
- **Notes:** the same as `lead(close, shift)` ([lead](functions-window.md#lead)). Because it looks into the future of each row, never use it as a signal on the last rows.

**Example: Chikou with shift 5 on CITY's daily closes: the last 5 days are NULL** (sample data: sample)

```sql
SELECT time, close, ichimoku_chikou(close, 5) AS close_5_days_later
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-08-30'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | close_5_days_later (DOUBLE) |
|---|---|---|
| 2026-08-30T00:00:00.000Z | 503.1 | 499 |
| 2026-08-31T00:00:00.000Z | 505.7 | 498.7 |
| 2026-09-01T00:00:00.000Z | 502.4 | 497.5 |
| 2026-09-02T00:00:00.000Z | 496.4 | 504.6 |
| 2026-09-03T00:00:00.000Z | 497.9 | 504.9 |
| 2026-09-06T00:00:00.000Z | 499 | NULL |
| 2026-09-07T00:00:00.000Z | 498.7 | NULL |
| 2026-09-08T00:00:00.000Z | 497.5 | NULL |
| 2026-09-09T00:00:00.000Z | 504.6 | NULL |
| 2026-09-10T00:00:00.000Z | 504.9 | NULL |

(10 rows)

## supertrend

Syntax:

```sql
supertrend(high, low, close)
supertrend(high, low, close, n, multiplier)
supertrend(high, low, close, n, multiplier) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**SuperTrend** is one line that follows the price. In an **up trend** the line is **below** the price, in a **down trend** it is **above**. When the close crosses the line, the trend flips. Traders like it as a simple trailing stop: in an up trend, sell when the close falls below the SuperTrend line.

The line is `(high + low) / 2 ± multiplier × ATR`. The ATR (average true range, see [atr](functions-indicators.md#atr)) makes the line keep a bigger distance when the price moves a lot. The line only moves toward the price, never away, until the trend flips. Use [supertrend_direction](#supertrend_direction) to know which side the line is on.

| Argument | Type | Meaning |
|---|---|---|
| `high`, `low`, `close` | number | the candle's high, low and close |
| `n` | whole number, 1 or more | the ATR period; default `10` |
| `multiplier` | number | how many ATRs away the line is; default `3` |

- **Returns:** `DOUBLE` (a price).
- **NULL:** `NULL` for the first `n - 1` candles. A NULL price stops the series (that candle and every later one is `NULL`).
- **Notes:** the same as TradingView `ta.supertrend(multiplier, n)`. Its ATR is TradingView's: the first true range is `high - low`, and the first ATR is on candle `n`. So it is a little different from KarelaDB's [atr](functions-indicators.md#atr), which starts on candle `n + 1`. A bigger `multiplier` gives fewer, later flips.

**Example: SuperTrend of CITY in the last 5 minutes** (sample data: sample)

```sql
SELECT time, close, supertrend, direction,
       CASE WHEN direction = 1 THEN 'up: line is the stop below' ELSE 'down: line is above' END AS meaning
FROM (SELECT time, close,
             round(supertrend(high, low, close), 2) AS supertrend,
             supertrend_direction(high, low, close) AS direction
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | supertrend (DOUBLE) | direction (LONG) | meaning (STRING) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 506.15 | -1 | down: line is above |
| 2026-09-10T09:13:00.000Z | 505.1 | 506.15 | -1 | down: line is above |
| 2026-09-10T09:12:00.000Z | 504.8 | 506.15 | -1 | down: line is above |
| 2026-09-10T09:11:00.000Z | 504.5 | 506.15 | -1 | down: line is above |
| 2026-09-10T09:10:00.000Z | 504.6 | 506.15 | -1 | down: line is above |

(5 rows)

**Example: Daily SuperTrend of every symbol (5 days, multiplier 2) on the last day** (sample data: sample)

```sql
SELECT time, symbol, close, st, direction
FROM (SELECT time, symbol, close,
             round(supertrend(high, low, close, 5, 2) OVER (PARTITION BY symbol ORDER BY time), 2) AS st,
             supertrend_direction(high, low, close, 5, 2) OVER (PARTITION BY symbol ORDER BY time) AS direction
      FROM ochl_day) t
WHERE time IN '2026-09-10'
ORDER BY symbol;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | st (DOUBLE) | direction (LONG) |
|---|---|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 511.5 | -1 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 384.2 | -1 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 173.34 | 1 |

(3 rows)

<a id="supertrend_direction"></a>

## supertrend_direction

Syntax:

```sql
supertrend_direction(high, low, close)
supertrend_direction(high, low, close, n, multiplier)
supertrend_direction(high, low, close, n, multiplier) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The side of the [SuperTrend](#supertrend) line: **1** for an up trend (the line is below the price), **-1** for a down trend (the line is above). When it changes from -1 to 1, traders take it as a **buy** signal; from 1 to -1 as a **sell** signal.

| Argument | Type | Meaning |
|---|---|---|
| `high`, `low`, `close` | number | the candle's high, low and close |
| `n` | whole number, 1 or more | the ATR period; default `10` |
| `multiplier` | number | how many ATRs away the line is; default `3` |

- **Returns:** `LONG`: `1` or `-1`.
- **NULL:** `NULL` for the first `n - 1` candles. A NULL price stops the series.
- **Notes:** **careful:** TradingView's `ta.supertrend` gives the opposite sign (-1 for up). KarelaDB uses 1 for up because it is easier to read. The first value is always `-1`, like TradingView's first value.

**Example: SuperTrend flips of CITY: buy and sell signals** (sample data: sample)

```sql
SELECT time, close, supertrend,
       CASE WHEN direction = 1 THEN 'BUY' ELSE 'SELL' END AS signal
FROM (SELECT time, close, supertrend, direction, lag(direction) AS prev_direction
      FROM (SELECT time, close,
                   round(supertrend(high, low, close), 2) AS supertrend,
                   supertrend_direction(high, low, close) AS direction
            FROM ochl_minutes
            WHERE symbol = 'CITY') a) b
WHERE direction <> prev_direction
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | supertrend (DOUBLE) | signal (STRING) |
|---|---|---|---|
| 2026-09-09T06:47:00.000Z | 505.8 | 504.08 | BUY |
| 2026-09-09T08:42:00.000Z | 508.2 | 510.31 | SELL |
| 2026-09-10T05:43:00.000Z | 506 | 504.19 | BUY |
| 2026-09-10T06:34:00.000Z | 504.8 | 506.76 | SELL |
| 2026-09-10T07:13:00.000Z | 502.9 | 501.07 | BUY |
| 2026-09-10T08:52:00.000Z | 504.7 | 506.91 | SELL |

(6 rows)

**Example: How many minutes COAST spent in each SuperTrend direction, per day** (sample data: sample)

```sql
SELECT to_date(time) AS day, direction, count(*) AS minutes
FROM (SELECT time, supertrend_direction(high, low, close) AS direction
      FROM ochl_minutes
      WHERE symbol = 'COAST') t
WHERE direction IS NOT NULL
GROUP BY to_date(time), direction
ORDER BY day, direction;
```

Result:

| day (DATE) | direction (LONG) | minutes (LONG) |
|---|---|---|
| 2026-09-09 | -1 | 200 |
| 2026-09-09 | 1 | 31 |
| 2026-09-10 | -1 | 149 |
| 2026-09-10 | 1 | 87 |

(4 rows)

<a id="linearreg"></a>

## linearreg, linreg

Syntax:

```sql
linearreg(x)
linearreg(x, n)
linreg(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

A **moving linear regression**. For every candle, KarelaDB draws the best straight line through the last `n` values (the "least squares" line: the one with the smallest squared distances to the points). `linearreg` is the value of that line **on this candle**. It is a moving average that follows the trend with less delay than [sma](functions-indicators.md#sma). `linreg` is the same function.

The other functions of this family read the same line: [linearreg_slope](#linearreg_slope) (its steepness), [linearreg_intercept](#linearreg_intercept) (its start), [linearreg_angle](#linearreg_angle) and [tsf](#tsf) (the next candle's forecast).

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 2 or more | how many candles the line goes through; default `14` |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles, and while a NULL value is in the window.
- **Notes:** the same as TA-Lib `LINEARREG`. For one line through **all** rows of a group, use the aggregate [regr_slope](functions-correlation.md#regr_slope).

**Example: Linear regression line against SMA (CITY daily, 5 days)** (sample data: sample)

```sql
SELECT time, close,
       round(linearreg(close, 5), 2) AS linreg5,
       round(sma(close, 5), 2) AS sma5
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-08-23'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | linreg5 (DOUBLE) | sma5 (DOUBLE) |
|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 507.9 | NULL | NULL |
| 2026-08-24T00:00:00.000Z | 510.3 | NULL | NULL |
| 2026-08-25T00:00:00.000Z | 513.3 | NULL | NULL |
| 2026-08-26T00:00:00.000Z | 513.2 | NULL | NULL |
| 2026-08-27T00:00:00.000Z | 505.9 | 509.9 | 510.12 |
| 2026-08-30T00:00:00.000Z | 503.1 | 504.8 | 509.16 |
| 2026-08-31T00:00:00.000Z | 505.7 | 503.18 | 508.24 |
| 2026-09-01T00:00:00.000Z | 502.4 | 501.7 | 506.06 |
| 2026-09-02T00:00:00.000Z | 496.4 | 498.76 | 502.7 |
| 2026-09-03T00:00:00.000Z | 497.9 | 497.16 | 501.1 |
| 2026-09-06T00:00:00.000Z | 499 | 496.7 | 500.28 |
| 2026-09-07T00:00:00.000Z | 498.7 | 497.92 | 498.88 |
| 2026-09-08T00:00:00.000Z | 497.5 | 498.5 | 497.9 |
| 2026-09-09T00:00:00.000Z | 504.6 | 501.92 | 499.54 |
| 2026-09-10T00:00:00.000Z | 504.9 | 504.48 | 500.94 |

(15 rows)

**Example: The period must be 2 or more: one point makes no line** (sample data: sample; shows an error)

```sql
SELECT linreg(close, 1) FROM ochl_day;
```

Result:

Error: `line 1, column 8: linreg: the period must be a whole number of rows (2 or more)`

<a id="linearreg_slope"></a>

## linearreg_slope, linreg_slope

Syntax:

```sql
linearreg_slope(x)
linearreg_slope(x, n)
linreg_slope(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **slope** of the moving regression line: how much the line goes up (or down, when negative) per candle. On one-minute closes, a slope of `0.05` means the trend adds about 5 cents a minute. A positive slope is an up trend, a negative slope a down trend; a bigger number is a steeper trend. `linreg_slope` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 2 or more | how many candles; default `14` |

- **Returns:** `DOUBLE` (price per candle).
- **NULL:** `NULL` for the first `n - 1` candles, and while a NULL value is in the window.
- **Notes:** the same as TA-Lib `LINEARREG_SLOPE`. To compare shares with different prices, divide by the price: `slope / close × 100` is the trend in percent per candle.

**Example: Trend of the last 14 minutes, per symbol, at the close** (sample data: sample)

```sql
SELECT time, symbol, close, slope14, round(slope14 / close * 100 * 60, 3) AS pct_per_hour
FROM (SELECT time, symbol, close,
             round(linearreg_slope(close, 14) OVER (PARTITION BY symbol ORDER BY time), 4) AS slope14
      FROM ochl_minutes) t
WHERE time = '2026-09-10T09:14:00Z'
ORDER BY symbol;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | slope14 (DOUBLE) | pct_per_hour (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | CITY | 504.9 | -0.0534 | -0.635 |
| 2026-09-10T09:14:00.000Z | COAST | 376.1 | 0.107 | 1.707 |

(2 rows)

<a id="linearreg_intercept"></a>

## linearreg_intercept, linreg_intercept

Syntax:

```sql
linearreg_intercept(x)
linearreg_intercept(x, n)
linreg_intercept(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **intercept** of the moving regression line: the value of the line on the **first** (oldest) candle of its window. With the slope, it gives the whole line: `linearreg = intercept + slope × (n - 1)`. `linreg_intercept` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 2 or more | how many candles; default `14` |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles, and while a NULL value is in the window.
- **Notes:** the same as TA-Lib `LINEARREG_INTERCEPT`.

**Example: Intercept + slope × (n - 1) is the linearreg value** (sample data: sample)

```sql
SELECT time, close,
       round(linearreg_intercept(close, 5), 2) AS intercept5,
       round(linearreg_slope(close, 5), 3) AS slope5,
       round(linearreg_intercept(close, 5) + linearreg_slope(close, 5) * 4, 2) AS line_today,
       round(linearreg(close, 5), 2) AS linreg5
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-09-01'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | intercept5 (DOUBLE) | slope5 (DOUBLE) | line_today (DOUBLE) | linreg5 (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 169 | NULL | NULL | NULL | NULL |
| 2026-09-02T00:00:00.000Z | 171.5 | NULL | NULL | NULL | NULL |
| 2026-09-03T00:00:00.000Z | 176 | NULL | NULL | NULL | NULL |
| 2026-09-06T00:00:00.000Z | 180.1 | NULL | NULL | NULL | NULL |
| 2026-09-07T00:00:00.000Z | 176.9 | 169.82 | 2.44 | 179.58 | 179.58 |
| 2026-09-08T00:00:00.000Z | 182.4 | 172.84 | 2.27 | 181.92 | 181.92 |
| 2026-09-09T00:00:00.000Z | 187.3 | 175.56 | 2.49 | 185.52 | 185.52 |
| 2026-09-10T00:00:00.000Z | 191.2 | 177.06 | 3.26 | 190.1 | 190.1 |

(8 rows)

<a id="linearreg_angle"></a>

## linearreg_angle, linreg_angle

Syntax:

```sql
linearreg_angle(x)
linearreg_angle(x, n)
linreg_angle(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The slope of the moving regression line as an **angle in degrees**: `atan(slope)` changed to degrees. Near `0` is flat; near `90` a very steep rise, near `-90` a very steep fall. `linreg_angle` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 2 or more | how many candles; default `14` |

- **Returns:** `DOUBLE` from -90 to 90.
- **NULL:** `NULL` for the first `n - 1` candles, and while a NULL value is in the window.
- **Notes:** the same as TA-Lib `LINEARREG_ANGLE`. The angle depends on the price unit (dollars per candle), so a 500-dollar share shows steeper angles than a 50-dollar share with the same move in percent. Only compare angles of the same share.

**Example: Angle of the 14-minute trend of COAST** (sample data: sample)

```sql
SELECT time, close, angle14
FROM (SELECT time, close, round(linearreg_angle(close), 1) AS angle14
      FROM ochl_minutes
      WHERE symbol = 'COAST') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | angle14 (DOUBLE) |
|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 6.1 |
| 2026-09-10T09:13:00.000Z | 376.2 | 4.2 |
| 2026-09-10T09:12:00.000Z | 376 | 1.8 |
| 2026-09-10T09:11:00.000Z | 375.5 | -0.4 |
| 2026-09-10T09:10:00.000Z | 375.6 | -1.8 |

(5 rows)

## tsf

Syntax:

```sql
tsf(x)
tsf(x, n)
tsf(x, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **time series forecast**: the moving regression line carried **one candle further**. It is a simple guess of the next value if the trend of the last `n` candles goes on: `tsf = linearreg + slope`.

| Argument | Type | Meaning |
|---|---|---|
| `x` | number | the price, usually `close` |
| `n` | whole number, 2 or more | how many candles; default `14` |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` for the first `n - 1` candles, and while a NULL value is in the window.
- **Notes:** the same as TA-Lib `TSF`. It is only a straight line: it does not know news or sudden turns.

**Example: Forecast against the real next close (CITY daily, 5 days)** (sample data: sample)

```sql
SELECT time, close, forecast_for_next_day, next_close,
       round(next_close - forecast_for_next_day, 2) AS error
FROM (SELECT time, close,
             round(tsf(close, 5), 2) AS forecast_for_next_day,
             lead(close) AS next_close
      FROM ochl_day
      WHERE symbol = 'CITY' AND time >= '2026-08-23') t
WHERE forecast_for_next_day IS NOT NULL
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | forecast_for_next_day (DOUBLE) | next_close (DOUBLE) | error (DOUBLE) |
|---|---|---|---|---|
| 2026-08-27T00:00:00.000Z | 505.9 | 509.79 | 503.1 | -6.69 |
| 2026-08-30T00:00:00.000Z | 503.1 | 502.62 | 505.7 | 3.08 |
| 2026-08-31T00:00:00.000Z | 505.7 | 500.65 | 502.4 | 1.75 |
| 2026-09-01T00:00:00.000Z | 502.4 | 499.52 | 496.4 | -3.12 |
| 2026-09-02T00:00:00.000Z | 496.4 | 496.79 | 497.9 | 1.11 |
| 2026-09-03T00:00:00.000Z | 497.9 | 495.19 | 499 | 3.81 |
| 2026-09-06T00:00:00.000Z | 499 | 494.91 | 498.7 | 3.79 |
| 2026-09-07T00:00:00.000Z | 498.7 | 497.44 | 497.5 | 0.06 |
| 2026-09-08T00:00:00.000Z | 497.5 | 498.8 | 504.6 | 5.8 |
| 2026-09-09T00:00:00.000Z | 504.6 | 503.11 | 504.9 | 1.79 |
| 2026-09-10T00:00:00.000Z | 504.9 | 506.25 | NULL | NULL |

(11 rows)

<a id="ha_open"></a>

## ha_open, ha_high, ha_low, ha_close

Syntax:

```sql
ha_open(open, high, low, close)
ha_high(open, high, low, close)
ha_low(open, high, low, close)
ha_close(open, high, low, close) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**Heikin-Ashi** ("average bar" in Japanese) candles are smoothed candles. Each one mixes the candle with the one before, so the chart shows long runs of same-colored candles in a trend and fewer false turns. Many traders read them like this: green candles with no lower wick mean a strong up trend.

| Function | Formula |
|---|---|
| `ha_close` | `(open + high + low + close) / 4` |
| `ha_open` | `(previous ha_open + previous ha_close) / 2`; on the first candle `(open + close) / 2` |
| `ha_high` | the biggest of `high`, `ha_open` and `ha_close` |
| `ha_low` | the smallest of `low`, `ha_open` and `ha_close` |

| Argument | Type | Meaning |
|---|---|---|
| `open`, `high`, `low`, `close` | number | the normal candle |

- **Returns:** `DOUBLE` (a price).
- **NULL:** every candle has a value, from the first. A NULL `open`, `high`, `low` or `close` stops the series (that candle and every later one is `NULL`).
- **Notes:** all four arguments are needed for every function, in the order open, high, low, close. The Heikin-Ashi close is **not** a real trade price: use the normal close for orders and stop-losses.

**Example: Heikin-Ashi candles of VOLT, with their color** (sample data: sample)

```sql
SELECT time, open, close, ha_open, ha_high, ha_low, ha_close,
       CASE WHEN ha_close >= ha_open THEN 'green' ELSE 'red' END AS ha_color
FROM (SELECT time, open, close,
             round(ha_open(open, high, low, close), 2) AS ha_open,
             round(ha_high(open, high, low, close), 2) AS ha_high,
             round(ha_low(open, high, low, close), 2) AS ha_low,
             round(ha_close(open, high, low, close), 2) AS ha_close
      FROM ochl_day
      WHERE symbol = 'VOLT' AND time >= '2026-08-23') t
ORDER BY time;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | close (DOUBLE) | ha_open (DOUBLE) | ha_high (DOUBLE) | ha_low (DOUBLE) | ha_close (DOUBLE) | ha_color (STRING) |
|---|---|---|---|---|---|---|---|
| 2026-08-23T00:00:00.000Z | 182.4 | 181 | 181.7 | 182.6 | 178.2 | 181.05 | red |
| 2026-08-24T00:00:00.000Z | 179.8 | 178.5 | 181.38 | 183.6 | 178.5 | 180.1 | red |
| 2026-08-25T00:00:00.000Z | 179.3 | 176.8 | 180.74 | 182.2 | 172.8 | 177.78 | red |
| 2026-08-26T00:00:00.000Z | 177.6 | 174.2 | 179.26 | 179.26 | 172 | 175.55 | red |
| 2026-08-27T00:00:00.000Z | 175.4 | 173.3 | 177.4 | 177.4 | 173 | 174.4 | red |
| 2026-08-30T00:00:00.000Z | 172.5 | 173 | 175.9 | 175.9 | 170.6 | 172.58 | red |
| 2026-08-31T00:00:00.000Z | 173.7 | 172.6 | 174.24 | 175.6 | 171.3 | 173.3 | red |
| 2026-09-01T00:00:00.000Z | 171.3 | 169 | 173.77 | 173.77 | 167.3 | 169.93 | red |
| 2026-09-02T00:00:00.000Z | 170.6 | 171.5 | 171.85 | 174.6 | 169 | 171.43 | red |
| 2026-09-03T00:00:00.000Z | 172.7 | 176 | 171.64 | 177.3 | 171.64 | 174.48 | green |
| 2026-09-06T00:00:00.000Z | 174.2 | 180.1 | 173.06 | 183.9 | 172.4 | 177.65 | green |
| 2026-09-07T00:00:00.000Z | 181.4 | 176.9 | 175.35 | 183.2 | 174.3 | 178.95 | green |
| 2026-09-08T00:00:00.000Z | 178.7 | 182.4 | 177.15 | 183.5 | 177.15 | 180.7 | green |
| 2026-09-09T00:00:00.000Z | 182 | 187.3 | 178.93 | 189.5 | 178.93 | 185.13 | green |
| 2026-09-10T00:00:00.000Z | 185.6 | 191.2 | 182.03 | 192.1 | 182.03 | 188.28 | green |

(15 rows)

**Example: 30-minute Heikin-Ashi candles: SAMPLE BY inside, Heikin-Ashi outside** (sample data: sample)

```sql
SELECT time,
       round(ha_open(open, high, low, close), 2) AS ha_open,
       round(ha_high(open, high, low, close), 2) AS ha_high,
       round(ha_low(open, high, low, close), 2) AS ha_low,
       round(ha_close(open, high, low, close), 2) AS ha_close
FROM (SELECT time, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close
      FROM ochl_minutes
      WHERE symbol = 'COAST' AND time IN '2026-09-10'
      SAMPLE BY 30m) c
ORDER BY time;
```

Result:

| time (TIMESTAMP) | ha_open (DOUBLE) | ha_high (DOUBLE) | ha_low (DOUBLE) | ha_close (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T05:00:00.000Z | 380.9 | 382 | 379.4 | 380.8 |
| 2026-09-10T05:30:00.000Z | 380.85 | 381.9 | 379 | 380.58 |
| 2026-09-10T06:00:00.000Z | 380.71 | 382 | 379.3 | 380.15 |
| 2026-09-10T06:30:00.000Z | 380.43 | 380.7 | 378.8 | 379.58 |
| 2026-09-10T07:00:00.000Z | 380 | 380 | 376.9 | 378.3 |
| 2026-09-10T07:30:00.000Z | 379.15 | 379.15 | 376.9 | 377.93 |
| 2026-09-10T08:00:00.000Z | 378.54 | 378.54 | 375.7 | 377.55 |
| 2026-09-10T08:30:00.000Z | 378.04 | 378.04 | 373.2 | 376.05 |
| 2026-09-10T09:00:00.000Z | 377.05 | 377.05 | 374.3 | 375.6 |

(9 rows)
