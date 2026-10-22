# Candles cookbook

> Ready market-data queries: candles from minute data and from trades, daily change, top gainers, volume leaders, 52-week high and low, moving averages and filled gaps.

- Category: Time-series
- Keywords: cookbook, recipes, candles, TA folders, indicator table, candles by timer, precompile, ta-folders.mjs, OHLC, candlestick, chart data, 5-minute candles, hourly candles, weekly candles, monthly candles, daily change, percent change, change %, top gainers, top losers, movers, volume leaders, turnover, broker turnover, 52-week high, 52-week low, moving average, SMA, EMA, RSI, crossover, golden cross, VWAP, gaps, missing minutes, FILL(PREV), stock market
- See also: [SAMPLE BY](sample-by.md), [LATEST ON](latest-on.md), [Technical indicators](functions-indicators.md), [Views (materialized-view)](views.md#materialized-view), [Timers](timers.md), [Trading calendars](calendars.md), [Window and series functions](functions-window.md), [Aggregate functions](functions-aggregate.md), [Time and time zones (nepal-time)](time-and-time-zones.md#nepal-time)

Copy these queries and change the symbol, the dates and the periods. All of them run on the sample market data (the prices are made up).

Most recipes use three building blocks:

- [SAMPLE BY](sample-by.md) makes candles: `first(open)`, `max(high)`, `min(low)`, `last(close)`, `sum(volume)`.
- [LATEST ON](latest-on.md) finds the newest row of each symbol.
- Series functions (`lag`, `sma`, `ema`, `rsi`, ...) with `OVER (PARTITION BY symbol ORDER BY time)` look at the rows before ([window functions](functions-window.md), [indicators](functions-indicators.md)).

<a id="candles-from-minutes"></a>

## Candles from minute data

Syntax:

```sql
SELECT time, symbol,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume
FROM ochl_minutes
WHERE time IN 'day'
SAMPLE BY 5m | 15m | 30m
ORDER BY symbol, time
```

Makes bigger candles from 1-minute candles. Open is the first open, close the last close, high the biggest high, low the smallest low, volume the sum.

- **Notes:**
  - For 5, 15 and 30 minutes, UTC and Nepal buckets are the same. For hours use the [next recipe](candles-cookbook.md#hourly-nepal).
  - Always filter by time: the query then reads only the partitions it needs.
  - A bucket with no trades gives no candle. See [filling gaps](candles-cookbook.md#fill-gaps).

**Example: 5-minute candles of both symbols, first 3 of each** (sample data: sample)

```sql
SELECT time, symbol,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume
FROM ochl_minutes
WHERE time IN '2026-09-09' AND time < '2026-09-09T11:15:00+05:45'
SAMPLE BY 5m
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|---|
| 2026-09-09T05:15:00.000Z | CITY | 512 | 512.4 | 511.2 | 512 | 4490 |
| 2026-09-09T05:20:00.000Z | CITY | 512 | 512.3 | 509.8 | 509.9 | 5340 |
| 2026-09-09T05:25:00.000Z | CITY | 509.9 | 511.3 | 509.8 | 510.7 | 3900 |
| 2026-09-09T05:15:00.000Z | COAST | 398 | 398.5 | 397.5 | 398.5 | 2640 |
| 2026-09-09T05:20:00.000Z | COAST | 398.5 | 398.8 | 397.2 | 397.7 | 4500 |
| 2026-09-09T05:25:00.000Z | COAST | 397.7 | 398.4 | 396.6 | 396.9 | 3260 |

(6 rows)

**Example: The newest 3 candles first (for a chart that loads backwards)** (sample data: sample)

```sql
SELECT time, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10'
SAMPLE BY 15m
ORDER BY time DESC
LIMIT 3;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-10T09:00:00.000Z | 375.5 | 376.5 | 374.3 | 376.1 | 14450 |
| 2026-09-10T08:45:00.000Z | 373.5 | 376.3 | 373.2 | 375.5 | 12030 |
| 2026-09-10T08:30:00.000Z | 377.6 | 377.9 | 373.4 | 373.5 | 10730 |

(3 rows)

<a id="hourly-nepal"></a>

## Hourly candles on a local clock (Nepal)

Syntax:

```sql
SELECT time, first(open), max(high), min(low), last(close), sum(volume)
FROM ochl_minutes
WHERE symbol = '...' AND time IN 'day'
SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu'
```

The sample market opens at 11:00 local time in Nepal (05:15 UTC). The same idea works for any zone, for example `America/New_York`. Plain `SAMPLE BY 1h` makes UTC hours, which cut the trading day at the wrong places. `TIME ZONE 'Asia/Kathmandu'` makes the hours 11:00, 12:00, 13:00 and 14:00 Nepal time.

- **Notes:**
  - The result times are in UTC: `05:15Z` is 11:00 in Nepal.
  - `vwap(price, volume)` is the volume-weighted average price of the candle.
  - QuestDB's `SAMPLE BY 1h ALIGN TO CALENDAR WITH OFFSET '00:15'` gives the same buckets and also runs.

**Example: Hourly candles with VWAP for both symbols** (sample data: sample)

```sql
SELECT time, symbol,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume, round(vwap(close, volume), 2) AS vwap
FROM ochl_minutes
WHERE time IN '2026-09-10'
SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) | vwap (DOUBLE) |
|---|---|---|---|---|---|---|---|
| 2026-09-10T05:15:00.000Z | CITY | 504.6 | 507 | 503.8 | 505.3 | 47020 | 505.3 |
| 2026-09-10T06:15:00.000Z | CITY | 505.3 | 506.6 | 500.7 | 502.7 | 41230 | 503.78 |
| 2026-09-10T07:15:00.000Z | CITY | 502.7 | 504.1 | 501.5 | 502.6 | 46180 | 502.84 |
| 2026-09-10T08:15:00.000Z | CITY | 502.6 | 507 | 502.2 | 504.9 | 48610 | 504.95 |
| 2026-09-10T05:15:00.000Z | COAST | 380.1 | 382 | 379 | 381.3 | 47660 | 380.44 |
| 2026-09-10T06:15:00.000Z | COAST | 381.3 | 382 | 377.9 | 378.4 | 45870 | 379.71 |
| 2026-09-10T07:15:00.000Z | COAST | 378.4 | 379.1 | 375.7 | 376.4 | 43950 | 377.6 |
| 2026-09-10T08:15:00.000Z | COAST | 376.4 | 378.3 | 373.2 | 376.1 | 48720 | 375.67 |

(8 rows)

<a id="candles-from-trades"></a>

## Daily candles from trade log trades

Syntax:

```sql
SELECT date, symbol,
       first(rate) AS open, max(rate) AS high, min(rate) AS low, last(rate) AS close,
       sum(quantity) AS volume, sum(amount) AS turnover, count(*) AS trades
FROM trade_log
SAMPLE BY 1d
```

Makes candles from single trades. The price is `rate`, the volume is `quantity`, the turnover is `amount` (quantity × rate).

- **Notes:**
  - The trade log has only the trade **date**, not the time of each trade. All trades of a day have the same time, so `first` and `last` follow the order the rows are stored in (here: by `transaction_id`). With a real trade time column, `first` and `last` follow the time.
  - To compare with the official candles, join the result with `ochl_day` on symbol and date.

**Example: Daily candles and turnover from trades** (sample data: sample)

```sql
SELECT date, symbol,
       first(rate) AS open, max(rate) AS high, min(rate) AS low, last(rate) AS close,
       sum(quantity) AS volume, round(sum(amount), 2) AS turnover, count(*) AS trades
FROM trade_log
SAMPLE BY 1d
ORDER BY symbol, date;
```

Result:

| date (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (LONG) | turnover (DOUBLE) | trades (LONG) |
|---|---|---|---|---|---|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 515 | 517 | 513 | 517 | 1510 | 777400 | 4 |
| 2026-09-10T00:00:00.000Z | CITY | 517 | 518 | 514.5 | 515 | 910 | 469830 | 7 |
| 2026-09-09T00:00:00.000Z | COAST | 401 | 401 | 398.5 | 398.5 | 220 | 88170 | 2 |
| 2026-09-10T00:00:00.000Z | COAST | 400 | 402 | 398 | 402 | 2850 | 1139340 | 9 |
| 2026-09-09T00:00:00.000Z | TELCO | 881 | 881 | 879 | 879 | 2000 | 1760000 | 2 |
| 2026-09-10T00:00:00.000Z | TELCO | 881 | 883 | 878 | 881 | 770 | 678260 | 4 |
| 2026-09-10T00:00:00.000Z | VOLT | 184 | 187 | 184 | 187 | 400 | 73950 | 4 |

(7 rows)

<a id="weekly-candles"></a>

## Weekly candles, Sunday to Thursday

Syntax:

```sql
SELECT time, symbol, first(open), max(high), min(low), last(close), sum(volume)
FROM ochl_day
WHERE time IN 'year'
SAMPLE BY 1w WEEK START SUNDAY
```

The sample market trades Sunday to Thursday, as some exchanges do. `WEEK START SUNDAY` makes each week start on Sunday, so one trading week is one candle.

- **Notes:** the daily rows are at 00:00 UTC, so do **not** add `TIME ZONE` here (the week would be stamped Saturday 18:15 UTC).

**Example: Weekly candles of every symbol** (sample data: sample)

```sql
SELECT time, symbol,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume
FROM ochl_day
WHERE time IN '2026'
SAMPLE BY 1w WEEK START SUNDAY
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|---|
| 2026-08-23T00:00:00.000Z | CITY | 505 | 517 | 502 | 505.9 | 601770 |
| 2026-08-30T00:00:00.000Z | CITY | 507.3 | 511.2 | 494.1 | 497.9 | 538130 |
| 2026-09-06T00:00:00.000Z | CITY | 497.4 | 512.4 | 495 | 504.9 | 591860 |
| 2026-08-23T00:00:00.000Z | COAST | 392.1 | 393.3 | 366.2 | 367.1 | 421000 |
| 2026-08-30T00:00:00.000Z | COAST | 368 | 375.4 | 364.1 | 373.2 | 356390 |
| 2026-09-06T00:00:00.000Z | COAST | 374.6 | 398.8 | 372.5 | 376.1 | 690140 |
| 2026-08-23T00:00:00.000Z | VOLT | 182.4 | 183.6 | 172 | 173.3 | 535470 |
| 2026-08-30T00:00:00.000Z | VOLT | 172.5 | 177.3 | 167.3 | 176 | 368150 |
| 2026-09-06T00:00:00.000Z | VOLT | 174.2 | 192.1 | 172.4 | 191.2 | 486760 |

(9 rows)

<a id="monthly-candles"></a>

## Monthly and yearly candles

Syntax:

```sql
SAMPLE BY 1M      -- month: capital M
SAMPLE BY 1y      -- year
```

`1M` is a calendar month; small `1m` is one minute. Months without rows are not shown.

**Example: Monthly candles of COAST** (sample data: sample)

```sql
SELECT time, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
FROM ochl_day
WHERE symbol = 'COAST'
SAMPLE BY 1M;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| 2025-12-01T00:00:00.000Z | 420.3 | 429.9 | 417.6 | 426.5 | 206980 |
| 2026-08-01T00:00:00.000Z | 392.1 | 393.3 | 364.2 | 368.2 | 557260 |
| 2026-09-01T00:00:00.000Z | 367 | 398.8 | 364.1 | 376.1 | 910270 |

(3 rows)

**Example: Yearly high, low and last close of every symbol** (sample data: sample)

```sql
SELECT time, symbol, max(high) AS year_high, min(low) AS year_low, last(close) AS year_close
FROM ochl_day
SAMPLE BY 1y
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | year_high (DOUBLE) | year_low (DOUBLE) | year_close (DOUBLE) |
|---|---|---|---|---|
| 2025-01-01T00:00:00.000Z | CITY | 546.2 | 536.4 | 542.4 |
| 2026-01-01T00:00:00.000Z | CITY | 517 | 494.1 | 504.9 |
| 2025-01-01T00:00:00.000Z | COAST | 429.9 | 417.6 | 426.5 |
| 2026-01-01T00:00:00.000Z | COAST | 398.8 | 364.1 | 376.1 |
| 2025-01-01T00:00:00.000Z | VOLT | 199.7 | 187.5 | 194.3 |
| 2026-01-01T00:00:00.000Z | VOLT | 192.1 | 167.3 | 191.2 |

(6 rows)

<a id="daily-change"></a>

## Daily change %

Syntax:

```sql
SELECT time, symbol, close,
       lag(close) OVER (PARTITION BY symbol ORDER BY time) AS prev_close,
       pct_change(close) OVER (PARTITION BY symbol ORDER BY time) AS change_pct
FROM ochl_day
```

The change from the day before: `(close - previous close) / previous close × 100`. `lag(close)` is the close of the row before; `pct_change(close)` computes the percent for you.

- **NULL:** the first row of each symbol has no day before, so its change is `NULL`.
- **Notes:**
  - Without `PARTITION BY symbol`, all rows are one series: COAST's first row would use CITY's last close.
  - `WHERE` runs before `lag`. With `WHERE time IN '2026-09-10'` alone there is no day before. Compute in a subquery over more days, and pick the day outside ([subqueries](union-subqueries.md#from-subquery)).

**Example: Change % of the last three days** (sample data: sample)

```sql
SELECT time, symbol, close,
       lag(close) OVER (PARTITION BY symbol ORDER BY time) AS prev_close,
       round(pct_change(close) OVER (PARTITION BY symbol ORDER BY time), 2) AS change_pct
FROM ochl_day
WHERE time >= '2026-09-08'
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | prev_close (DOUBLE) | change_pct (DOUBLE) |
|---|---|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | NULL | NULL |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 497.5 | 1.43 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 504.6 | 0.06 |
| 2026-09-08T00:00:00.000Z | COAST | 377.2 | NULL | NULL |
| 2026-09-09T00:00:00.000Z | COAST | 380.1 | 377.2 | 0.77 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 380.1 | -1.05 |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 | NULL | NULL |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 | 182.4 | 2.69 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 187.3 | 2.08 |

(9 rows)

**Example: Wrong: WHERE keeps one day, so there is no day before** (sample data: sample)

```sql
SELECT time, symbol, close, round(pct_change(close) OVER (PARTITION BY symbol ORDER BY time), 2) AS change_pct
FROM ochl_day
WHERE time IN '2026-09-10';
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | change_pct (STRING) |
|---|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | NULL |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | NULL |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | NULL |

(3 rows)

<a id="top-gainers"></a>

## Top gainers and losers

Syntax:

```sql
SELECT symbol, prev_close, close, change_pct
FROM (SELECT time, symbol, close, lag(close) OVER (PARTITION BY symbol ORDER BY time) AS prev_close
      FROM ochl_day WHERE time >= 'a few days before') t
WHERE time IN 'the day'
ORDER BY change_pct DESC
LIMIT 10
```

Gainers of a day: the change %, biggest first. Losers: the same with `ORDER BY change_pct` (smallest first).

- **Notes:**
  - The inner `WHERE time >= ...` should start a few days before the day you want (weekends and holidays have no rows). Then KDB does not read the whole table.
  - For the market **right now**, use the live snapshots with `LATEST ON` (second example).

**Example: Top gainers of 2026-09-10 from daily candles** (sample data: sample)

```sql
SELECT symbol, prev_close, close,
       round((close - prev_close) / prev_close * 100, 2) AS change_pct
FROM (
  SELECT time, symbol, close,
         lag(close) OVER (PARTITION BY symbol ORDER BY time) AS prev_close
  FROM ochl_day
  WHERE time >= '2026-09-01'
) t
WHERE time IN '2026-09-10'
ORDER BY change_pct DESC;
```

Result:

| symbol (SYMBOL) | prev_close (DOUBLE) | close (DOUBLE) | change_pct (DOUBLE) |
|---|---|---|---|
| VOLT | 187.3 | 191.2 | 2.08 |
| CITY | 504.6 | 504.9 | 0.06 |
| COAST | 380.1 | 376.1 | -1.05 |

(3 rows)

**Example: Top 2 gainers and top 2 losers right now (live snapshots)** (sample data: sample)

```sql
SELECT symbol, ltp, pct_change FROM live_data
LATEST ON timestamp PARTITION BY symbol
ORDER BY pct_change DESC LIMIT 2;

SELECT symbol, ltp, pct_change FROM live_data
LATEST ON timestamp PARTITION BY symbol
ORDER BY pct_change LIMIT 2;
```

Result:

`SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol ORDER BY pct_c`

| symbol (SYMBOL) | ltp (DOUBLE) | pct_change (DOUBLE) |
|---|---|---|
| CITY | 527.1 | 2.71 |
| TELCO | 897.7 | 1.9 |

(2 rows)

`SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol ORDER BY pct_c`

| symbol (SYMBOL) | ltp (DOUBLE) | pct_change (DOUBLE) |
|---|---|---|
| VOLT | 184 | -0.86 |
| COAST | 401.9 | 0.7 |

(2 rows)

<a id="volume-leaders"></a>

## Volume and turnover leaders

Syntax:

```sql
SELECT symbol, sum(volume) AS volume FROM ochl_day WHERE time IN 'day' GROUP BY symbol ORDER BY volume DESC LIMIT n
SELECT symbol, sum(quantity), sum(amount) AS turnover FROM trade_log WHERE date IN 'day' GROUP BY symbol ORDER BY turnover DESC
```

The most traded shares of a day, by volume (number of shares) or by turnover (money).

- **Notes:** the trade log has buyer and seller brokers, so you can also rank brokers. Each trade counts for its buyer **and** its seller: `UNION ALL` the two sides first.

**Example: Volume leaders of a day (daily candles)** (sample data: sample)

```sql
SELECT symbol, volume, close
FROM ochl_day
WHERE time IN '2026-09-10'
ORDER BY volume DESC
LIMIT 3;
```

Result:

| symbol (SYMBOL) | volume (DOUBLE) | close (DOUBLE) |
|---|---|---|
| COAST | 186200 | 376.1 |
| CITY | 183040 | 504.9 |
| VOLT | 41470 | 191.2 |

(3 rows)

**Example: Turnover leaders of a day (trade log)** (sample data: sample)

```sql
SELECT symbol, sum(quantity) AS shares, round(sum(amount), 2) AS turnover, count(*) AS trades
FROM trade_log
WHERE date IN '2026-09-10'
GROUP BY symbol
ORDER BY turnover DESC;
```

Result:

| symbol (SYMBOL) | shares (LONG) | turnover (DOUBLE) | trades (LONG) |
|---|---|---|---|
| COAST | 2850 | 1139340 | 9 |
| TELCO | 770 | 678260 | 4 |
| CITY | 910 | 469830 | 7 |
| VOLT | 400 | 73950 | 4 |

(4 rows)

**Example: Brokers with the biggest turnover (bought + sold)** (sample data: sample)

```sql
SELECT b.name, round(sum(t.amount), 2) AS turnover, count(*) AS trades
FROM (
  SELECT buyer AS broker, amount FROM trade_log WHERE date IN '2026-09-10'
  UNION ALL
  SELECT seller AS broker, amount FROM trade_log WHERE date IN '2026-09-10'
) t
JOIN brokers b ON b.id = t.broker
GROUP BY b.name
ORDER BY turnover DESC
LIMIT 3;
```

Result:

| name (STRING) | turnover (DOUBLE) | trades (LONG) |
|---|---|---|
| Imperial Securities | 1288160 | 11 |
| Online Securities | 1173580 | 9 |
| Vision Securities | 773260 | 9 |

(3 rows)

<a id="high-low-52w"></a>

## 52-week high and low

Syntax:

```sql
SELECT symbol, max(high) AS high_52w, min(low) AS low_52w
FROM ochl_day
WHERE time > dateadd('d', -365, now())
GROUP BY symbol
```

The highest high and lowest low of the last 365 days. `dateadd('d', -365, t)` is the time 365 days before `t` ([date and time functions](functions-date-time.md)).

- **Notes:** the examples use the fixed date `2026-09-10` so the result does not change. For "until today" write `now()`.

**Example: 52-week high and low of every symbol** (sample data: sample)

```sql
SELECT symbol, max(high) AS high_52w, min(low) AS low_52w
FROM ochl_day
WHERE time > dateadd('d', -365, CAST('2026-09-10' AS TIMESTAMP))
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | high_52w (DOUBLE) | low_52w (DOUBLE) |
|---|---|---|
| CITY | 546.2 | 494.1 |
| COAST | 429.9 | 364.1 |
| VOLT | 199.7 | 167.3 |

(3 rows)

**Example: How far the last close is below the 52-week high** (sample data: sample)

```sql
SELECT h.symbol, l.close, h.high_52w, h.low_52w,
       round((l.close - h.high_52w) / h.high_52w * 100, 2) AS below_high_pct
FROM (SELECT symbol, max(high) AS high_52w, min(low) AS low_52w
      FROM ochl_day
      WHERE time > dateadd('d', -365, CAST('2026-09-10' AS TIMESTAMP))
      GROUP BY symbol) h
JOIN (SELECT symbol, close FROM ochl_day LATEST ON time PARTITION BY symbol) l ON l.symbol = h.symbol
ORDER BY below_high_pct DESC;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | high_52w (DOUBLE) | low_52w (DOUBLE) | below_high_pct (DOUBLE) |
|---|---|---|---|---|
| VOLT | 191.2 | 199.7 | 167.3 | -4.26 |
| CITY | 504.9 | 546.2 | 494.1 | -7.56 |
| COAST | 376.1 | 429.9 | 364.1 | -12.51 |

(3 rows)

> Prices after a bonus share or a split jump on the ex-date. To chart or compute indicators over the history without that jump, read the table with [ADJUSTED BY](adjusted-prices.md).

<a id="moving-averages"></a>

## Moving averages and crossovers

Syntax:

```sql
sma(close, n) OVER (PARTITION BY symbol ORDER BY time)
ema(close, n) OVER (PARTITION BY symbol ORDER BY time)
rsi(close, n) OVER (PARTITION BY symbol ORDER BY time)
```

`sma` is the simple moving average of the last `n` rows, `ema` the exponential one, `rsi` the Relative Strength Index (0 to 100). See [indicator functions](functions-indicators.md) for all of them.

- **NULL:** before there are `n` rows (for `rsi`: `n + 1`), the result is `NULL`.
- **Notes:**
  - Use `PARTITION BY symbol` when the rows have many symbols.
  - Compute over **enough history** in a subquery, then filter the days you want to show outside.
  - An indicator can be inside another one: `lag(sma(close, 3)) OVER (...)`, `cross_above(sma(close, 3), sma(close, 5)) OVER (...)`. The inner one, written without `OVER`, takes the outer one's `PARTITION BY` and `ORDER BY`; KDB computes it first, in a subquery of its own.

**Example: 5-day SMA and EMA, newest rows of CITY** (sample data: sample)

```sql
SELECT time, symbol, close,
       round(sma(close, 5) OVER (PARTITION BY symbol ORDER BY time), 2) AS sma5,
       round(ema(close, 5) OVER (PARTITION BY symbol ORDER BY time), 2) AS ema5
FROM ochl_day
WHERE symbol = 'CITY' AND time IN '2026'
ORDER BY time DESC
LIMIT 3;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | sma5 (DOUBLE) | ema5 (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 500.94 | 502.22 |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 | 499.54 | 500.88 |
| 2026-09-08T00:00:00.000Z | CITY | 497.5 | 497.9 | 499.01 |

(3 rows)

**Example: RSI of every symbol on the last day (computed over all days)** (sample data: sample)

```sql
SELECT time, symbol, close, rsi5
FROM (
  SELECT time, symbol, close,
         round(rsi(close, 5) OVER (PARTITION BY symbol ORDER BY time), 1) AS rsi5
  FROM ochl_day
) t
WHERE time IN '2026-09-10'
ORDER BY rsi5 DESC;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | rsi5 (DOUBLE) |
|---|---|---|---|
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 79.4 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 55.1 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 43.7 |

(3 rows)

**Example: Crossover in one line: cross_above and cross_below** (sample data: sample)

```sql
SELECT time, close,
       CASE WHEN cross_above(sma(close, 3), sma(close, 5)) OVER (ORDER BY time) THEN 'BUY'
            WHEN cross_below(sma(close, 3), sma(close, 5)) OVER (ORDER BY time) THEN 'SELL'
            ELSE '' END AS signal
FROM ochl_day
WHERE symbol = 'VOLT' AND time IN '2026'
ORDER BY time DESC
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | signal (STRING) |
|---|---|---|
| 2026-09-10T00:00:00.000Z | 191.2 |  |
| 2026-09-09T00:00:00.000Z | 187.3 |  |
| 2026-09-08T00:00:00.000Z | 182.4 |  |
| 2026-09-07T00:00:00.000Z | 176.9 |  |
| 2026-09-06T00:00:00.000Z | 180.1 | BUY |

(5 rows)

**Example: Crossover written out: BUY when the 3-day SMA goes above the 5-day SMA** (sample data: sample)

```sql
SELECT time, close, fast, slow,
       CASE WHEN fast > slow AND prev_fast <= prev_slow THEN 'BUY'
            WHEN fast < slow AND prev_fast >= prev_slow THEN 'SELL'
            ELSE '' END AS signal
FROM (
  SELECT time, close, fast, slow, lag(fast) AS prev_fast, lag(slow) AS prev_slow
  FROM (
    SELECT time, close, round(sma(close, 3), 2) AS fast, round(sma(close, 5), 2) AS slow
    FROM ochl_day
    WHERE symbol = 'VOLT' AND time IN '2026'
  ) a
) b
WHERE time >= '2026-09-01';
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | fast (DOUBLE) | slow (DOUBLE) | signal (STRING) |
|---|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 169 | 171.53 | 172.42 |  |
| 2026-09-02T00:00:00.000Z | 171.5 | 171.03 | 171.88 |  |
| 2026-09-03T00:00:00.000Z | 176 | 172.17 | 172.42 |  |
| 2026-09-06T00:00:00.000Z | 180.1 | 175.87 | 173.84 | BUY |
| 2026-09-07T00:00:00.000Z | 176.9 | 177.67 | 174.7 |  |
| 2026-09-08T00:00:00.000Z | 182.4 | 179.8 | 177.38 |  |
| 2026-09-09T00:00:00.000Z | 187.3 | 182.2 | 180.54 |  |
| 2026-09-10T00:00:00.000Z | 191.2 | 186.97 | 183.58 |  |

(8 rows)

<a id="indicators-on-candles"></a>

## Indicators on candles

Syntax:

```sql
SELECT time, close, sma(close, n) AS sma
FROM (SELECT time, last(close) AS close FROM ... SAMPLE BY interval) candles
```

To put an indicator on weekly or hourly candles, make the candles in a subquery and compute the indicator outside. In one SELECT with `SAMPLE BY`, a window function runs over the candles, so it may only use the time bucket, group keys or aggregates, not a raw column like `close`.

- **Notes:** the subquery result has a `time` column, so the series functions outside use its time order.

**Example: SAMPLE BY and sma(close) in one SELECT: close is not a candle value** (sample data: sample; shows an error)

```sql
SELECT time, last(close) AS close, sma(close, 2) AS sma2
FROM ochl_day
WHERE symbol = 'CITY'
SAMPLE BY 1w WEEK START SUNDAY;
```

Result:

Error: `line 1, column 40: column 'close' is used by a window function in a query with aggregates, so it must be a key of the groups: add it to the SELECT list or to GROUP BY`

**Example: The fix: hourly Nepal candles inside, a 2-candle SMA outside** (sample data: sample)

```sql
SELECT time, close, round(sma(close, 2), 2) AS sma2
FROM (
  SELECT time, last(close) AS close
  FROM ochl_minutes
  WHERE symbol = 'CITY' AND time IN '2026-09-10'
  SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu'
) h;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | sma2 (DOUBLE) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | 505.3 | NULL |
| 2026-09-10T06:15:00.000Z | 502.7 | 504 |
| 2026-09-10T07:15:00.000Z | 502.6 | 502.65 |
| 2026-09-10T08:15:00.000Z | 504.9 | 503.75 |

(4 rows)

<a id="ta-folders"></a>

## Candle and indicator tables kept by a timer

Syntax:

```sql
-- 1. candles, kept up to date after every insert
CREATE MATERIALIZED VIEW ta_v_h1 AS (
  SELECT time, symbol, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
  FROM minute_table SAMPLE BY 1h ALIGN TO CALENDAR WITH OFFSET '00:15');
-- 2. a table for the candles plus indicator columns
CREATE TABLE ta_h1 (time TIMESTAMP, symbol SYMBOL, open DOUBLE, ..., rsi14 DOUBLE, ...) TIMESTAMP(time);
-- 3. a procedure that rebuilds it in one transaction
CREATE PROCEDURE ta_build_h1() AS BEGIN
  DELETE FROM ta_h1;
  INSERT INTO ta_h1 SELECT time, symbol, open, ..., rsi(close, 14) OVER (PARTITION BY symbol ORDER BY time) AS rsi14, ... FROM ta_v_h1;
END;
-- 4. a timer that runs it after each trading day (POST /api/timers)
{"name": "ta_h1", "schedule": "trading nepse 15:10", "sql": "REFRESH MATERIALIZED VIEW ta_v_h1 INCREMENTAL; CALL ta_build_h1()"}
```

Screeners and charts often read the same candles again and again: 5-minute, 15-minute, hourly, weekly and monthly, each with a set of indicators. Build them once in KDB, and read the table.

| Part | Why |
|---|---|
| [Materialized view](views.md#materialized-view) | Holds the candles. KDB updates only the buckets an insert touches. |
| Table with indicator columns | An indicator needs every candle before it, so it cannot be in the view. The procedure writes it. |
| [Procedure](procedures.md) | `DELETE` and `INSERT` in one `CALL` are one transaction: a reader sees the old rows or the new ones, never an empty table. |
| [Timer](timers.md) on a [calendar](calendars.md) | `trading nepse 15:10` runs after the close on trading days only. Start the server with `--timezone Asia/Kathmandu` so 15:10 is Nepal time. |

- **Notes:**
  - Nepal is UTC+05:45. 5- and 15-minute buckets are the same in UTC and Nepal time. Hours need `WITH OFFSET '00:15'` (or `TIME ZONE 'Asia/Kathmandu'`), see [hourly candles](candles-cookbook.md#hourly-nepal).
  - Weekly and monthly candles come from the day table: `SAMPLE BY 1w WEEK START SUNDAY` and `SAMPLE BY 1M`, see [weekly candles](candles-cookbook.md#weekly-candles).
  - Give each timeframe its own names. KDB names ignore case, so `ta_1m` and `ta_1M` would be the same table: use `m5`, `m15`, `h1`, `w1`, `mo1`.
  - `bench/006/ta-folders.mjs` in the source sets all of this up for the five timeframes, writes one file per symbol and timeframe, and with `--compare <folder>` checks the files against another set, column by column with a tolerance (`node bench/006/ta-folders.mjs` prints the help; `sql` prints the whole recipe).

**Example: Hourly Nepal candles with indicators, rebuilt by one CALL** (sample data: sample)

Setup:

```sql
CREATE MATERIALIZED VIEW ta_v_h1 AS (
  SELECT time, symbol, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
  FROM ochl_minutes SAMPLE BY 1h ALIGN TO CALENDAR WITH OFFSET '00:15');
CREATE TABLE ta_h1 (time TIMESTAMP, symbol SYMBOL, close DOUBLE, volume DOUBLE, sma3 DOUBLE, rsi3 DOUBLE) TIMESTAMP(time);
CREATE PROCEDURE ta_build_h1() AS BEGIN
  DELETE FROM ta_h1;
  INSERT INTO ta_h1
  SELECT time, symbol, close, volume,
         sma(close, 3) OVER (PARTITION BY symbol ORDER BY time),
         rsi(close, 3) OVER (PARTITION BY symbol ORDER BY time)
  FROM ta_v_h1;
END;
```

```sql
CALL ta_build_h1();
SELECT time, close, round(sma3, 2) AS sma3, round(rsi3, 1) AS rsi3
FROM ta_h1 WHERE symbol = 'CITY' ORDER BY time DESC LIMIT 4;
```

Result:

`CALL ta_build_h1()`

```text
procedure 'ta_build_h1' done: 16 row(s) changed
```

`SELECT time, close, round(sma3, 2) AS sma3, round(rsi3, 1) AS rsi3 FROM ta_h1 WHERE symbol = 'CITY' `

| time (TIMESTAMP) | close (DOUBLE) | sma3 (DOUBLE) | rsi3 (DOUBLE) |
|---|---|---|---|
| 2026-09-10T08:15:00.000Z | 504.9 | 503.4 | 59.9 |
| 2026-09-10T07:15:00.000Z | 502.6 | 503.53 | 31.7 |
| 2026-09-10T06:15:00.000Z | 502.7 | 504.2 | 32.4 |
| 2026-09-10T05:15:00.000Z | 505.3 | 506.53 | 50.7 |

(4 rows)

**Example: Weekly candles (Sunday weeks) with a 2-week EMA** (sample data: sample)

Setup:

```sql
CREATE MATERIALIZED VIEW ta_v_w1 AS (
  SELECT time, symbol, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
  FROM ochl_day SAMPLE BY 1w WEEK START SUNDAY);
```

```sql
SELECT time, close, round(ema(close, 2) OVER (PARTITION BY symbol ORDER BY time), 2) AS ema2
FROM ta_v_w1 WHERE symbol = 'VOLT' ORDER BY time DESC LIMIT 3;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | ema2 (DOUBLE) |
|---|---|---|
| 2026-09-06T00:00:00.000Z | 191.2 | 187 |
| 2026-08-30T00:00:00.000Z | 176 | 178.6 |
| 2026-08-23T00:00:00.000Z | 173.3 | 183.8 |

(3 rows)

<a id="fill-gaps"></a>

## Filling gaps in minute candles

Syntax:

```sql
SAMPLE BY 1m FILL(PREV)
-- open, high, low, close = the minute before, volume = 0: one rule per column
SAMPLE BY 1m FILL(PREV, PREV, PREV, PREV, 0)
-- every minute of a fixed range, also before the first trade
SAMPLE BY 1m FROM '...' TO '...' FILL(PREV, 0)
```

Some minutes have no trades, so there is no candle. A chart with a fixed number of minutes needs a row for every minute.

- **Notes:**
  - `FILL(PREV)` copies **every** column of the minute before, also the volume. That is right for the price, wrong for the volume.
  - `FILL(PREV, 0)` gives each aggregate column its own rule, in SELECT order: close from the minute before, volume 0.
  - `FROM ... TO ...` fills a fixed range of minutes (a chart window), `TO` not included. See [FROM / TO](sample-by.md#from-to).
  - FILL fills every empty minute between the first and the last row, also the night. Filter **one trading day** (or a shorter range).
  - Details: [FILL](sample-by.md#fill).

**Example: COAST had no trades from 12:31 to 12:34: FILL(PREV)** (sample data: sample)

```sql
SELECT time, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST' AND time >= '2026-09-10T12:30:00+05:45' AND time < '2026-09-10T12:36:00+05:45'
SAMPLE BY 1m FILL(PREV);
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|
| 2026-09-10T06:45:00.000Z | 380.2 | 620 |
| 2026-09-10T06:46:00.000Z | 380.2 | 620 |
| 2026-09-10T06:47:00.000Z | 380.2 | 620 |
| 2026-09-10T06:48:00.000Z | 380.2 | 620 |
| 2026-09-10T06:49:00.000Z | 380.2 | 620 |
| 2026-09-10T06:50:00.000Z | 379.8 | 800 |

(6 rows)

**Example: Candles with open, high, low, close from the minute before, volume 0** (sample data: sample)

```sql
SELECT time, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST'
SAMPLE BY 1m FROM '2026-09-10T12:30:00+05:45' TO '2026-09-10T12:36:00+05:45'
FILL(PREV, PREV, PREV, PREV, 0);
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-10T06:45:00.000Z | 379.9 | 380.4 | 379.9 | 380.2 | 620 |
| 2026-09-10T06:46:00.000Z | 379.9 | 380.4 | 379.9 | 380.2 | 0 |
| 2026-09-10T06:47:00.000Z | 379.9 | 380.4 | 379.9 | 380.2 | 0 |
| 2026-09-10T06:48:00.000Z | 379.9 | 380.4 | 379.9 | 380.2 | 0 |
| 2026-09-10T06:49:00.000Z | 379.9 | 380.4 | 379.9 | 380.2 | 0 |
| 2026-09-10T06:50:00.000Z | 380.2 | 380.2 | 379.8 | 379.8 | 800 |

(6 rows)
