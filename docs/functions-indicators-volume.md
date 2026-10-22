# Volume indicators

> Is money flowing in or out? On-balance volume, the A/D line, Chaikin money flow and oscillator, MFI, force index and ease of movement.

- Category: Functions — technical indicators
- Keywords: volume, money flow, buying pressure, selling pressure, accumulation, distribution, divergence, on-balance volume, on balance volume, OBV, accumulation/distribution, accumulation distribution, A/D line, AD, Chaikin money flow, CMF, Chaikin oscillator, Chaikin A/D oscillator, ADOSC, money flow index, MFI, volume RSI, force index, Elder force index, EFI, ease of movement, EMV, EOM, stock market
- See also: [Technical indicators](functions-indicators.md), [Volatility indicators and bands](functions-indicators-volatility.md), [Momentum indicators](functions-indicators-momentum.md), [Trend indicators](functions-indicators-trend.md), [Aggregate functions (vwap)](functions-aggregate.md#vwap), [Window and series functions](functions-window.md)

**Volume** is how many shares were traded in a candle. A price move on big volume means many people agree with it; a move on small volume is weak. **Volume indicators** mix the price and the volume to show if money is flowing **into** a share (buying pressure, "accumulation") or **out of** it (selling pressure, "distribution").

A common use is a **divergence**: the price goes sideways or down, but the volume indicator goes up. That can mean big buyers are collecting the share before the price rises.

These functions are **series functions**, like [sma and atr](functions-indicators.md). The same rules apply:

- **Order:** without `OVER`, all result rows are one series in time order. With **many symbols**, always write `OVER (PARTITION BY symbol ORDER BY time)`.
- **Period:** `n` is how many candles the indicator looks back, a whole number of 1 or more.
- **WHERE runs first**, and candles made with `SAMPLE BY` must be made in a subquery: see the rules in [technical indicators](functions-indicators.md). `obv` and `ad` are running totals, so their numbers depend on the first row the series has.
- **Warm-up:** at the start of a series there are not enough candles yet, and the result is `NULL`:

| Function (default periods) | First value on candle | NULL candles at the start |
|---|---|---|
| `obv(close, volume)` | 1 | 0 |
| `ad(high, low, close, volume)` | 1 | 0 |
| `cmf(high, low, close, volume, n)` (n = 20) | n | n - 1 |
| `adosc(high, low, close, volume, fast, slow)` (3, 10) | the bigger of fast and slow | one less |
| `mfi(high, low, close, volume, n)` (n = 14) | n + 1 | n |
| `efi(close, volume, n)` (n = 13) | n + 1 | n |
| `eom(high, low, volume, n, divisor)` (14, 100000000) | n + 1 | n |

- **NULL values:** `cmf` and `eom` look at a window of candles: a NULL makes the windows that hold it `NULL`, and then the values come back. `obv`, `ad`, `adosc`, `mfi` and `efi` are built step by step: one NULL makes this and **every later** value `NULL`. Leave NULL candles out with `WHERE`.
- **Same as TA-Lib:** `obv`, `ad`, `adosc` and `mfi` give the same numbers as TA-Lib (OBV, AD, ADOSC, MFI). `cmf` (Chaikin), `efi` (Elder) and `eom` (Arms) are not in TA-Lib; they use the usual formulas written on each entry.
- **Returns** `DOUBLE`.

**Example: Volume indicators of CITY's one-minute candles (the last 5 minutes)** (sample data: sample)

```sql
SELECT time, close, volume, obv, ad, cmf20, adosc, mfi14, efi13
FROM (SELECT time, close, volume,
             obv(close, volume) AS obv,
             round(ad(high, low, close, volume)) AS ad,
             round(cmf(high, low, close, volume), 3) AS cmf20,
             round(adosc(high, low, close, volume)) AS adosc,
             round(mfi(high, low, close, volume), 1) AS mfi14,
             round(efi(close, volume)) AS efi13
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) | obv (DOUBLE) | ad (DOUBLE) | cmf20 (DOUBLE) | adosc (DOUBLE) | mfi14 (DOUBLE) | efi13 (DOUBLE) |
|---|---|---|---|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | 1000 | 13660 | -17532 | -0.031 | -513 | 34.3 | -46 |
| 2026-09-10T09:13:00.000Z | 505.1 | 460 | 14660 | -17389 | -0.06 | -560 | 47.3 | -20 |
| 2026-09-10T09:12:00.000Z | 504.8 | 390 | 14200 | -17542 | 0.02 | -662 | 50.5 | -47 |
| 2026-09-10T09:11:00.000Z | 504.5 | 1350 | 13810 | -17932 | -0.041 | -646 | 47.7 | -74 |
| 2026-09-10T09:10:00.000Z | 504.6 | 1340 | 15160 | -16582 | 0.013 | -159 | 59.3 | -64 |

(5 rows)

**Example: A NULL volume: cmf comes back, obv stays NULL** (sample data: sample)

Setup:

```sql
CREATE TABLE candles (time TIMESTAMP, high DOUBLE, low DOUBLE, close DOUBLE, volume DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO candles VALUES ('2026-09-01', 11, 9, 10, 100), ('2026-09-02', 12, 10, 11, 200), ('2026-09-03', 13, 11, 12, NULL),
  ('2026-09-04', 14, 12, 13, 400), ('2026-09-05', 13, 11, 12, 500), ('2026-09-06', 15, 12, 14, 600);
```

```sql
SELECT time, close, volume, obv(close, volume) AS obv, round(cmf(high, low, close, volume, 2), 3) AS cmf2
FROM candles
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) | obv (DOUBLE) | cmf2 (DOUBLE) |
|---|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 10 | 100 | 100 | NULL |
| 2026-09-02T00:00:00.000Z | 11 | 200 | 300 | 0 |
| 2026-09-03T00:00:00.000Z | 12 | NULL | NULL | NULL |
| 2026-09-04T00:00:00.000Z | 13 | 400 | NULL | NULL |
| 2026-09-05T00:00:00.000Z | 12 | 500 | NULL | 0 |
| 2026-09-06T00:00:00.000Z | 14 | 600 | NULL | 0.182 |

(6 rows)

## obv

Syntax:

```sql
obv(close, volume)
obv(close, volume) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**On-balance volume**: a running total of the volume. When the close is higher than the previous close, the candle's volume is **added**; when it is lower, the volume is **subtracted**; when it is the same, nothing changes. When OBV rises, the volume is bigger on up days than on down days: buyers are stronger. Only the direction of OBV matters, not the number itself.

| Argument | Type | Meaning |
|---|---|---|
| `close` | number | the candle's close |
| `volume` | number | the candle's volume |

- **Returns:** `DOUBLE`.
- **NULL:** never `NULL` at the start. **Careful:** a NULL `close` or `volume` makes this and every later value `NULL`.
- **Notes:** like TA-Lib, the first candle's OBV is its own volume. Because it is a running total, the number depends on where the series starts; compare its **changes**, not its level.

**Example: Up day: add the volume. Down day: subtract it** (sample data: sample)

```sql
SELECT time, close, volume, obv(close, volume) AS obv
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-09-01'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) | obv (DOUBLE) |
|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 169 | 58850 | 58850 |
| 2026-09-02T00:00:00.000Z | 171.5 | 21770 | 80620 |
| 2026-09-03T00:00:00.000Z | 176 | 145930 | 226550 |
| 2026-09-06T00:00:00.000Z | 180.1 | 78550 | 305100 |
| 2026-09-07T00:00:00.000Z | 176.9 | 135560 | 169540 |
| 2026-09-08T00:00:00.000Z | 182.4 | 136770 | 306310 |
| 2026-09-09T00:00:00.000Z | 187.3 | 94410 | 400720 |
| 2026-09-10T00:00:00.000Z | 191.2 | 41470 | 442190 |

(8 rows)

**Example: Divergence: price change and OBV change since 23 August** (sample data: sample)

```sql
SELECT symbol, count(*) AS days,
       round(last(close) - first(close), 1) AS price_change,
       last(obv) - first(obv) AS obv_change
FROM (SELECT time, symbol, close,
             obv(close, volume) OVER (PARTITION BY symbol ORDER BY time) AS obv
      FROM ochl_day
      WHERE time >= '2026-08-23') t
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | days (LONG) | price_change (DOUBLE) | obv_change (DOUBLE) |
|---|---|---|---|
| CITY | 15 | -3 | 226090 |
| COAST | 15 | -14.9 | 65740 |
| VOLT | 15 | 10.2 | -246280 |

(3 rows)

<a id="ad"></a>

## ad, ad_line

Syntax:

```sql
ad(high, low, close, volume)
ad_line(high, low, close, volume)
ad(high, low, close, volume) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **accumulation/distribution line** (A/D line). For every candle it finds where the close is inside the candle, with the **money flow multiplier** `((close - low) - (high - close)) / (high - low)`: `1` when the close is at the high, `-1` when it is at the low, `0` in the middle. The A/D line is the running total of `multiplier × volume`. A rising line means the closes are near the highs on big volume: accumulation. `ad_line` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close |
| `volume` | number | the candle's volume |

- **Returns:** `DOUBLE`.
- **NULL:** never `NULL` at the start. **Careful:** a NULL argument makes this and every later value `NULL`.
- **Notes:** a candle with `high = low` adds nothing. Unlike `obv`, it does not look at the previous close, only at the candle itself. The same as TA-Lib AD.

**Example: The multiplier of each day and the A/D line of CITY** (sample data: sample)

```sql
SELECT time, high, low, close, volume,
       round(((close - low) - (high - close)) / (high - low), 3) AS multiplier,
       round(ad(high, low, close, volume)) AS ad_line
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-03'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) | multiplier (DOUBLE) | ad_line (DOUBLE) |
|---|---|---|---|---|---|---|
| 2026-09-03T00:00:00.000Z | 500.9 | 495.5 | 497.9 | 101000 | -0.111 | -11222 |
| 2026-09-06T00:00:00.000Z | 500.1 | 496 | 499 | 74950 | 0.463 | 23511 |
| 2026-09-07T00:00:00.000Z | 501 | 495 | 498.7 | 117080 | 0.233 | 50829 |
| 2026-09-08T00:00:00.000Z | 501.1 | 497.5 | 497.5 | 34400 | -1 | 16429 |
| 2026-09-09T00:00:00.000Z | 512.4 | 504 | 504.6 | 182390 | -0.857 | -139905 |
| 2026-09-10T00:00:00.000Z | 507 | 500.7 | 504.9 | 183040 | 0.333 | -78892 |

(6 rows)

**Example: A/D line of both symbols at the end of each day (one-minute candles)** (sample data: sample)

```sql
SELECT time, symbol, close, ad_line
FROM (SELECT time, symbol, close,
             round(ad_line(high, low, close, volume) OVER (PARTITION BY symbol ORDER BY time)) AS ad_line
      FROM ochl_minutes) t
WHERE time IN ('2026-09-09T09:14:00Z', '2026-09-10T09:14:00Z')
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | ad_line (DOUBLE) |
|---|---|---|---|
| 2026-09-09T09:14:00.000Z | CITY | 504.6 | -14867 |
| 2026-09-10T09:14:00.000Z | CITY | 504.9 | -17532 |
| 2026-09-09T09:14:00.000Z | COAST | 380.1 | -19693 |
| 2026-09-10T09:14:00.000Z | COAST | 376.1 | -9254 |

(4 rows)

## cmf

Syntax:

```sql
cmf(high, low, close, volume)
cmf(high, low, close, volume, n)
cmf(high, low, close, volume, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**Chaikin money flow**: over the last `n` candles, the sum of `multiplier × volume` divided by the sum of the volume (the multiplier is the one of [ad](functions-indicators-volume.md#ad)). It is between `-1` and `1`. **Above 0** means buying pressure (closes near the highs); **below 0** means selling pressure. Many traders look for values above `0.1` or below `-0.1`.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close |
| `volume` | number | the candle's volume |
| `n` | whole number, 1 or more | how many candles; default `20` |

- **Returns:** `DOUBLE` from -1 to 1.
- **NULL:** `NULL` for the first `n - 1` candles, and when the total volume of the window is `0`. A NULL argument makes the `n` results whose window holds it `NULL`; after that CMF comes back.
- **Notes:** a candle with `high = low` counts with multiplier `0` (its volume still counts in the total).

**Example: Buying or selling pressure? 5-day CMF of every symbol** (sample data: sample)

```sql
SELECT time, symbol, close, cmf5,
       CASE WHEN cmf5 > 0 THEN 'buying' WHEN cmf5 < 0 THEN 'selling' END AS pressure
FROM (SELECT time, symbol, close,
             round(cmf(high, low, close, volume, 5) OVER (PARTITION BY symbol ORDER BY time), 3) AS cmf5
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | cmf5 (DOUBLE) | pressure (STRING) |
|---|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | -0.072 | selling |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | -0.274 | selling |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | -0.114 | selling |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | 0.337 | buying |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | -0.077 | selling |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | -0.267 | selling |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | 0.238 | buying |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 0.283 | buying |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 0.254 | buying |

(9 rows)

**Example: 20-minute CMF at the last minute of the day** (sample data: sample)

```sql
SELECT symbol, close, cmf20
FROM (SELECT time, symbol, close,
             round(cmf(high, low, close, volume) OVER (PARTITION BY symbol ORDER BY time), 3) AS cmf20
      FROM ochl_minutes) t
WHERE time = '2026-09-10T09:14:00Z'
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | cmf20 (DOUBLE) |
|---|---|---|
| CITY | 504.9 | -0.031 |
| COAST | 376.1 | -0.015 |

(2 rows)

<a id="adosc"></a>

## adosc, chaikin_osc

Syntax:

```sql
adosc(high, low, close, volume)
adosc(high, low, close, volume, fast, slow)
chaikin_osc(high, low, close, volume, fast, slow)
adosc(high, low, close, volume, fast, slow) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **Chaikin oscillator** (Chaikin A/D oscillator): the fast EMA of the [A/D line](functions-indicators-volume.md#ad) minus its slow EMA. It shows if the A/D line speeds up or slows down, like [MACD](functions-indicators-momentum.md#macd) does for the price. When it crosses **above 0**, buying pressure is growing (a buy signal); below 0, selling pressure is growing. `chaikin_osc` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close |
| `volume` | number | the candle's volume |
| `fast` | whole number, 1 or more | the fast EMA period; default `3` |
| `slow` | whole number, 1 or more | the slow EMA period; default `10` |

- **Returns:** `DOUBLE`, in the unit of `volume`.
- **NULL:** the first value is on candle `max(fast, slow)`: candle 10 with the defaults. **Careful:** a NULL argument makes this and every later value `NULL`.
- **Notes:** like TA-Lib ADOSC, both EMAs start at the first A/D value (not at an SMA like [ema](functions-indicators.md#ema)), so the first values still depend on the start. Load more candles than you show.

**Example: Chaikin oscillator of CITY (the last 5 minutes)** (sample data: sample)

```sql
SELECT time, close, osc
FROM (SELECT time, close, round(adosc(high, low, close, volume)) AS osc
      FROM ochl_minutes
      WHERE symbol = 'CITY') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | osc (DOUBLE) |
|---|---|---|
| 2026-09-10T09:14:00.000Z | 504.9 | -513 |
| 2026-09-10T09:13:00.000Z | 505.1 | -560 |
| 2026-09-10T09:12:00.000Z | 504.8 | -662 |
| 2026-09-10T09:11:00.000Z | 504.5 | -646 |
| 2026-09-10T09:10:00.000Z | 504.6 | -159 |

(5 rows)

**Example: Signals: the oscillator crosses 0** (sample data: sample)

```sql
SELECT time, close, round(osc) AS osc, CASE WHEN osc > 0 THEN 'BUY' ELSE 'SELL' END AS signal
FROM (SELECT time, close, osc, lag(osc) AS prev_osc
      FROM (SELECT time, close, chaikin_osc(high, low, close, volume, 3, 10) AS osc
            FROM ochl_minutes
            WHERE symbol = 'CITY' AND time IN '2026-09-10') a) b
WHERE (osc > 0 AND prev_osc <= 0) OR (osc < 0 AND prev_osc >= 0)
ORDER BY time
LIMIT 6;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | osc (DOUBLE) | signal (STRING) |
|---|---|---|---|
| 2026-09-10T05:39:00.000Z | 505.2 | 420 | BUY |
| 2026-09-10T05:52:00.000Z | 506.3 | -310 | SELL |
| 2026-09-10T06:10:00.000Z | 505.9 | 211 | BUY |
| 2026-09-10T06:13:00.000Z | 505.4 | -162 | SELL |
| 2026-09-10T06:16:00.000Z | 505.6 | 311 | BUY |
| 2026-09-10T06:21:00.000Z | 505.2 | -189 | SELL |

(6 rows)

## mfi

Syntax:

```sql
mfi(high, low, close, volume)
mfi(high, low, close, volume, n)
mfi(high, low, close, volume, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

The **money flow index**, a number from 0 to 100. It is often called the "volume RSI": it works like [rsi](functions-indicators.md#rsi), but with money instead of price. Each candle has a **typical price** `(high + low + close) / 3` and a **money flow** `typical price × volume`. The money flow counts as positive when the typical price is higher than the previous one, negative when it is lower. MFI is `100 × positive / (positive + negative)` over the last `n` candles. Above **80** traders call the share overbought; below **20**, oversold.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `close` | number | the candle's close |
| `volume` | number | the candle's volume |
| `n` | whole number, 1 or more | how many candles; default `14` |

- **Returns:** `DOUBLE` from 0 to 100.
- **NULL:** `NULL` for the first `n` candles (the first candle has no previous typical price). **Careful:** a NULL argument makes this and every later value `NULL`.
- **Notes:** the same as TA-Lib MFI. Only falls in the window give `0`; only rises give `100`. When the total money flow of the window is less than 1 (for example no volume), MFI is `0`.

**Example: Overbought (80 or more) and oversold (20 or less) days, 5-day MFI** (sample data: sample)

```sql
SELECT time, symbol, close, mfi5,
       CASE WHEN mfi5 >= 80 THEN 'overbought' ELSE 'oversold' END AS zone
FROM (SELECT time, symbol, close,
             round(mfi(high, low, close, volume, 5) OVER (PARTITION BY symbol ORDER BY time), 1) AS mfi5
      FROM ochl_day
      WHERE time >= '2026-08-23') t
WHERE mfi5 >= 80 OR mfi5 <= 20
ORDER BY time, symbol;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | mfi5 (DOUBLE) | zone (STRING) |
|---|---|---|---|---|
| 2026-08-30T00:00:00.000Z | VOLT | 173 | 0 | oversold |
| 2026-08-31T00:00:00.000Z | CITY | 505.7 | 14.3 | oversold |
| 2026-08-31T00:00:00.000Z | VOLT | 172.6 | 10.9 | oversold |
| 2026-09-01T00:00:00.000Z | CITY | 502.4 | 0 | oversold |
| 2026-09-01T00:00:00.000Z | VOLT | 169 | 12.2 | oversold |
| 2026-09-02T00:00:00.000Z | CITY | 496.4 | 0 | oversold |
| 2026-09-03T00:00:00.000Z | CITY | 497.9 | 18.6 | oversold |
| 2026-09-06T00:00:00.000Z | VOLT | 180.1 | 83.8 | overbought |
| 2026-09-07T00:00:00.000Z | COAST | 379.2 | 86.3 | overbought |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | 87 | overbought |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 89.6 | overbought |

(11 rows)

**Example: MFI 14 against RSI 14 of COAST (the last 5 minutes)** (sample data: sample)

```sql
SELECT time, close, mfi14, rsi14
FROM (SELECT time, close,
             round(mfi(high, low, close, volume), 1) AS mfi14,
             round(rsi(close, 14), 1) AS rsi14
      FROM ochl_minutes
      WHERE symbol = 'COAST') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | mfi14 (DOUBLE) | rsi14 (DOUBLE) |
|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 68.9 | 59.4 |
| 2026-09-10T09:13:00.000Z | 376.2 | 58.8 | 60.9 |
| 2026-09-10T09:12:00.000Z | 376 | 54 | 59 |
| 2026-09-10T09:11:00.000Z | 375.5 | 43.1 | 53.9 |
| 2026-09-10T09:10:00.000Z | 375.6 | 36.4 | 55.2 |

(5 rows)

**Example: high, low, close and volume are all needed** (sample data: sample; shows an error)

```sql
SELECT mfi(high, low, close) FROM ochl_day;
```

Result:

Error: `line 1, column 8: function 'mfi' takes 4 to 5 argument(s), got 3`

<a id="efi"></a>

## efi, force_index

Syntax:

```sql
efi(close, volume)
efi(close, volume, n)
force_index(close, volume, n)
efi(close, volume, n) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**Elder's force index**: the **force** of one candle is `(close - previous close) × volume`, so a big move on big volume is a big force. `efi` is the [ema](functions-indicators.md#ema) of the force over `n` candles. Above 0, buyers are in control; below 0, sellers. `force_index` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `close` | number | the candle's close |
| `volume` | number | the candle's volume |
| `n` | whole number, 1 or more | the EMA period; default `13` (traders also use `2` for short signals) |

- **Returns:** `DOUBLE`, in price × shares (for example dollars × shares).
- **NULL:** `NULL` for the first `n` candles (the first candle has no force). **Careful:** a NULL argument makes this and every later value `NULL`.
- **Notes:** the EMA starts with the plain average of the first `n` forces, like `ema`.

**Example: The force of each day and its 3-day EMA (VOLT)** (sample data: sample)

```sql
SELECT time, close, volume,
       round((close - lag(close)) * volume) AS force,
       round(efi(close, volume, 3)) AS efi3
FROM ochl_day
WHERE symbol = 'VOLT' AND time >= '2026-08-30'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) | force (DOUBLE) | efi3 (DOUBLE) |
|---|---|---|---|---|
| 2026-08-30T00:00:00.000Z | 173 | 93050 | NULL | NULL |
| 2026-08-31T00:00:00.000Z | 172.6 | 48550 | -19420 | NULL |
| 2026-09-01T00:00:00.000Z | 169 | 58850 | -211860 | NULL |
| 2026-09-02T00:00:00.000Z | 171.5 | 21770 | 54425 | -58952 |
| 2026-09-03T00:00:00.000Z | 176 | 145930 | 656685 | 298867 |
| 2026-09-06T00:00:00.000Z | 180.1 | 78550 | 322055 | 310461 |
| 2026-09-07T00:00:00.000Z | 176.9 | 135560 | -433792 | -61666 |
| 2026-09-08T00:00:00.000Z | 182.4 | 136770 | 752235 | 345285 |
| 2026-09-09T00:00:00.000Z | 187.3 | 94410 | 462609 | 403947 |
| 2026-09-10T00:00:00.000Z | 191.2 | 41470 | 161733 | 282840 |

(10 rows)

**Example: 13-minute force index of COAST (the last 5 minutes)** (sample data: sample)

```sql
SELECT time, close, volume, force13
FROM (SELECT time, close, volume, round(force_index(close, volume)) AS force13
      FROM ochl_minutes
      WHERE symbol = 'COAST') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) | force13 (DOUBLE) |
|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 1060 | 104 |
| 2026-09-10T09:13:00.000Z | 376.2 | 1320 | 140 |
| 2026-09-10T09:12:00.000Z | 376 | 1150 | 119 |
| 2026-09-10T09:11:00.000Z | 375.5 | 680 | 43 |
| 2026-09-10T09:10:00.000Z | 375.6 | 1200 | 61 |

(5 rows)

<a id="eom"></a>

## eom, ease_of_movement

Syntax:

```sql
eom(high, low, volume)
eom(high, low, volume, n)
eom(high, low, volume, n, divisor)
ease_of_movement(high, low, volume, n, divisor)
eom(high, low, volume, n, divisor) OVER ([PARTITION BY ...] [ORDER BY ...])
```

**Ease of movement** (Richard Arms): how easily the price moves. A big positive value means the price went **up easily**, on little volume; a big negative value means it went down easily. Values near 0 mean the price needed a lot of volume to move. `ease_of_movement` is the same function.

For each candle: the **distance** is `(high + low) / 2 - (previous high + previous low) / 2`, the **box ratio** is `(volume / divisor) / (high - low)`, and the candle's value is `distance / box ratio`. `eom` is the [sma](functions-indicators.md#sma) of these values over `n` candles.

| Argument | Type | Meaning |
|---|---|---|
| `high` | number | the candle's high |
| `low` | number | the candle's low |
| `volume` | number | the candle's volume |
| `n` | whole number, 1 or more | how many candles; default `14` |
| `divisor` | number, not 0 | scales the volume; default `100000000` |

- **Returns:** `DOUBLE`. The size depends on `divisor`; only the sign and the changes matter.
- **NULL:** `NULL` for the first `n` candles (the first candle has no previous high and low). A candle with volume `0` or a NULL value makes the windows that hold it `NULL`; after that EOM comes back.
- **Notes:** a candle with `high = low` counts as `0`. The default divisor is made for very big volumes; with small volumes (hundreds or thousands of shares per minute) a divisor like `10000` gives easier numbers. It does not change the sign.

**Example: EOM 14 of COAST with the default divisor and with 10000 (the last 5 minutes)** (sample data: sample)

```sql
SELECT time, close, eom_default, eom_10000
FROM (SELECT time, close,
             round(eom(high, low, volume), 1) AS eom_default,
             round(eom(high, low, volume, 14, 10000), 3) AS eom_10000
      FROM ochl_minutes
      WHERE symbol = 'COAST') t
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | eom_default (DOUBLE) | eom_10000 (DOUBLE) |
|---|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 460.9 | 0.046 |
| 2026-09-10T09:13:00.000Z | 376.2 | -634.5 | -0.063 |
| 2026-09-10T09:12:00.000Z | 376 | 3122.5 | 0.312 |
| 2026-09-10T09:11:00.000Z | 375.5 | 395.9 | 0.04 |
| 2026-09-10T09:10:00.000Z | 375.6 | -1109.3 | -0.111 |

(5 rows)

**Example: Did VOLT rise easily? 3-day EOM** (sample data: sample)

```sql
SELECT time, close, volume, eom3,
       CASE WHEN eom3 > 0 THEN 'up easily' WHEN eom3 < 0 THEN 'down easily' END AS reading
FROM (SELECT time, close, volume, round(ease_of_movement(high, low, volume, 3, 10000), 2) AS eom3
      FROM ochl_day
      WHERE symbol = 'VOLT' AND time >= '2026-08-23') t
WHERE time >= '2026-09-01'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) | eom3 (DOUBLE) | reading (STRING) |
|---|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 169 | 58850 | -0.97 | down easily |
| 2026-09-02T00:00:00.000Z | 171.5 | 21770 | 1.09 | up easily |
| 2026-09-03T00:00:00.000Z | 176 | 145930 | 1.13 | up easily |
| 2026-09-06T00:00:00.000Z | 180.1 | 78550 | 3.88 | up easily |
| 2026-09-07T00:00:00.000Z | 176.9 | 135560 | 2.21 | up easily |
| 2026-09-08T00:00:00.000Z | 182.4 | 136770 | 2.14 | up easily |
| 2026-09-09T00:00:00.000Z | 187.3 | 94410 | 1.71 | up easily |
| 2026-09-10T00:00:00.000Z | 191.2 | 41470 | 3.2 | up easily |

(8 rows)

**Example: The divisor must not be 0** (sample data: sample; shows an error)

```sql
SELECT eom(high, low, volume, 14, 0) FROM ochl_day;
```

Result:

Error: `line 1, column 8: eom: the divisor must not be 0`
