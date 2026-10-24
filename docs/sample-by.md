# SAMPLE BY

> Put rows into time buckets (1 minute, 15 minutes, 1 hour, 1 day, 1 week, 1 month) and make candles.

- Category: Time-series
- Keywords: SAMPLE, candles, candle, OHLC, time bucket, bucket, resample, downsample, interval, 1m, 5m, 15m, 1h, 1d, 1w, 1M, 1y, ms, minute, hour, day, week, month, year, FILL, NONE, FILL per column, FROM, TO, FROM TO, PREV, LINEAR, empty buckets, gaps, ALIGN, CALENDAR, FIRST OBSERVATION, OBSERVATION, TIME ZONE, ZONE, Asia/Kathmandu, Nepal time, WITH OFFSET, WITH, WEEK START, WEEK, START, SUNDAY, MONDAY, timestamp\_floor, QuestDB
- See also: [Candles cookbook](candles-cookbook.md), [LATEST ON](latest-on.md), [Time and time zones](time-and-time-zones.md), [GROUP BY and HAVING (implicit-group-by)](group-by.md#implicit-group-by), [Aggregate functions](functions-aggregate.md), [Technical indicators](functions-indicators.md)

`SAMPLE BY` cuts time into equal pieces called **buckets** (for example 15 minutes) and makes one result row for each bucket. With `first`, `max`, `min`, `last` and `sum` this makes **candles** (open, high, low, close, volume).

- It works on time-series tables (tables with `TIMESERIES(column)`), and on a view or a subquery whose result has a `TIMESTAMP` column.
- The time column in the result is the **start** of each bucket, shown in UTC.
- A bucket with no rows gives no result row. Use [FILL](sample-by.md#fill) to get those rows.

**Example: 15-minute CITY candles made from 1-minute candles** (sample data: sample)

```sql
SELECT time,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
SAMPLE BY 15m
LIMIT 4;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-10T05:15:00.000Z | 504.6 | 505.3 | 503.9 | 504.4 | 13210 |
| 2026-09-10T05:30:00.000Z | 504.4 | 506.8 | 503.8 | 506.5 | 11690 |
| 2026-09-10T05:45:00.000Z | 506.5 | 507 | 505.3 | 506.4 | 11270 |
| 2026-09-10T06:00:00.000Z | 506.4 | 506.6 | 504.9 | 505.3 | 10850 |

(4 rows)

<a id="sample-by"></a>

## SAMPLE BY

Syntax:

```sql
SELECT time_column, [key_column, ...] aggregate, ...
FROM table | view | (SELECT ...) alias
[WHERE condition]
SAMPLE BY interval
    [FROM start] [TO end]
    [FILL(NONE | NULL | PREV | LINEAR | constant [, ...])]
    [ALIGN TO CALENDAR | ALIGN TO FIRST OBSERVATION]
    [TIME ZONE 'zone']
    [WITH OFFSET '+HH:MM']
    [WEEK START SUNDAY | MONDAY]
[GROUP BY expression, ...]
[HAVING condition]
[ORDER BY ...] [LIMIT n [OFFSET m]]
```

Makes one row for each bucket of time (and for each key, like `symbol`). The options after the interval can come in any order, but each option only once.

| Part | Meaning |
|---|---|
| `time_column` | the table's time column. In the result it holds the bucket start. You can leave it out of the SELECT list, or give it another name with `AS`. |
| `key_column` | a plain column (not inside an aggregate), like `symbol`. It becomes a group key: one row per bucket **per symbol** (the [implicit GROUP BY](group-by.md#implicit-group-by) rule). |
| `aggregate` | `first`, `last`, `max`, `min`, `sum`, `avg`, `count`, `vwap`, ... ([aggregate functions](functions-aggregate.md)) |
| `interval` | the bucket size: `15m`, `1h`, `1d`, `1w`, `1M`, ... (see [intervals](sample-by.md#intervals)) |

- **Returns:** one row per bucket and key. Without `ORDER BY` the rows come sorted by bucket start; rows of the same bucket come in the order their key was first seen. Add `ORDER BY symbol, time` when you want each symbol together.
- **NULL:** rows whose time is `NULL` are skipped. Aggregates skip `NULL` values, as always.
- **Notes:**
  - `first(x)` and `last(x)` use the **time order** of the rows: the open of the earliest row, the close of the latest row.
  - `WHERE` runs before `SAMPLE BY`. Always filter by time (`time IN '2026-09-10'`) so KarelaDB reads only the partitions it needs.
  - A plain column without an aggregate is a key, even when you did not mean it: `SELECT time, close ... SAMPLE BY 1d` gives one row per different `close` value.
  - A window function can sit next to `SAMPLE BY`: it runs **after** the candles are made, over the candles, like `lag(last(close)) OVER (PARTITION BY symbol ORDER BY time)`. With more than one symbol, always write `OVER (PARTITION BY symbol ORDER BY time)`: without it the series is all candles in time order, so the symbols are mixed. Making the candles in a [subquery](union-subqueries.md#from-subquery) and the indicator outside works too (see the [cookbook](candles-cookbook.md#indicators-on-candles)).
  - You may also write `GROUP BY symbol` after the SAMPLE BY options. It gives the same rows.
  - **Speed does not depend on the sort order.** A chart with no other key (`SELECT time, count(*), sum(volume) ... SAMPLE BY 1s`) over a table stored `SORT BY (symbol, time)`, the default, is about as fast as over the same rows stored by time: KarelaDB reads such a partition in stretches of time, not in stretches of rows. One day of 2,000,000 trades of 500 symbols at `1s`: 52 ms by (symbol, time), 44 ms by time.
  - Differences from QuestDB: `WEEK START SUNDAY` exists; `FROM` / `TO` also work with keys (like `symbol`) and with months; `TIME ZONE` takes zones with summer time too ([summer time](time-and-time-zones.md#summer-time)); times are milliseconds, not microseconds.

**Example: Daily candles for every symbol, made from minute candles** (sample data: sample)

```sql
SELECT time, symbol,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume, count(*) AS minutes
FROM ochl_minutes
SAMPLE BY 1d
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) | minutes (LONG) |
|---|---|---|---|---|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 512 | 512.4 | 504 | 504.6 | 182390 | 240 |
| 2026-09-10T00:00:00.000Z | CITY | 504.6 | 507 | 500.7 | 504.9 | 183040 | 240 |
| 2026-09-09T00:00:00.000Z | COAST | 398 | 398.8 | 379.2 | 380.1 | 186330 | 240 |
| 2026-09-10T00:00:00.000Z | COAST | 380.1 | 382 | 373.2 | 376.1 | 186200 | 236 |

(4 rows)

**Example: A window over the candles: yesterday's close next to today's** (sample data: sample)

```sql
SELECT time, symbol, last(close) AS close,
       lag(last(close)) OVER (PARTITION BY symbol ORDER BY time) AS prev_close
FROM ochl_day
WHERE time IN '2026-09' AND time < '2026-09-04'
SAMPLE BY 1d
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | prev_close (DOUBLE) |
|---|---|---|---|
| 2026-09-01T00:00:00.000Z | CITY | 502.4 | NULL |
| 2026-09-02T00:00:00.000Z | CITY | 496.4 | 502.4 |
| 2026-09-03T00:00:00.000Z | CITY | 497.9 | 496.4 |
| 2026-09-01T00:00:00.000Z | COAST | 367.4 | NULL |
| 2026-09-02T00:00:00.000Z | COAST | 369.2 | 367.4 |
| 2026-09-03T00:00:00.000Z | COAST | 373.2 | 369.2 |
| 2026-09-01T00:00:00.000Z | VOLT | 169 | NULL |
| 2026-09-02T00:00:00.000Z | VOLT | 171.5 | 169 |
| 2026-09-03T00:00:00.000Z | VOLT | 176 | 171.5 |

(9 rows)

**Example: Trade log: shares and turnover per day per symbol** (sample data: sample)

```sql
SELECT date, symbol, sum(quantity) AS shares, round(sum(amount), 2) AS turnover, count(*) AS trades
FROM trade_log
WHERE symbol IN ('CITY', 'COAST')
SAMPLE BY 1d
ORDER BY symbol, date;
```

Result:

| date (TIMESTAMP) | symbol (SYMBOL) | shares (LONG) | turnover (DOUBLE) | trades (LONG) |
|---|---|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 1510 | 777400 | 4 |
| 2026-09-10T00:00:00.000Z | CITY | 910 | 469830 | 7 |
| 2026-09-09T00:00:00.000Z | COAST | 220 | 88170 | 2 |
| 2026-09-10T00:00:00.000Z | COAST | 2850 | 1139340 | 9 |

(4 rows)

**Example: Weekly volume, only the big weeks (HAVING)** (sample data: sample)

```sql
SELECT time, symbol, sum(volume) AS volume
FROM ochl_day
WHERE time IN '2026'
SAMPLE BY 1w WEEK START SUNDAY
HAVING sum(volume) > 600000;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | volume (DOUBLE) |
|---|---|---|
| 2026-08-23T00:00:00.000Z | CITY | 601770 |
| 2026-09-06T00:00:00.000Z | COAST | 690140 |

(2 rows)

**Example: A plain column without an aggregate becomes a key** (sample data: sample)

```sql
SELECT time, close
FROM ochl_day
WHERE symbol = 'CITY' AND time IN '2026-09'
SAMPLE BY 1M;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) |
|---|---|
| 2026-09-01T00:00:00.000Z | 502.4 |
| 2026-09-01T00:00:00.000Z | 496.4 |
| 2026-09-01T00:00:00.000Z | 497.9 |
| 2026-09-01T00:00:00.000Z | 499 |
| 2026-09-01T00:00:00.000Z | 498.7 |
| 2026-09-01T00:00:00.000Z | 497.5 |
| 2026-09-01T00:00:00.000Z | 504.6 |
| 2026-09-01T00:00:00.000Z | 504.9 |

(8 rows)

**Example: SAMPLE BY on a relational table** (sample data: sample; shows an error)

```sql
SELECT id, count(*) FROM brokers SAMPLE BY 1d;
```

Result:

Error: `SAMPLE BY needs a table with a time column (a TIMESERIES table)`

<a id="intervals"></a>

## Intervals

Syntax:

```sql
SAMPLE BY n ms | n s | n m | n h | n d | n w | n M | n y
```

The interval is a whole number and a unit, written together without a space: `15m`, `4h`, `1M`.

| Unit | Meaning | Buckets start at |
|---|---|---|
| `ms` | milliseconds | every n milliseconds |
| `s` | seconds | every n seconds |
| `m` | **minutes** (small m) | full minutes: `:00`, `:15`, `:30`, ... |
| `h` | hours | full hours (UTC, or the [TIME ZONE](sample-by.md#time-zone) clock) |
| `d` | days | 00:00 UTC (or midnight of the TIME ZONE) |
| `w` | weeks | Monday 00:00, or Sunday with [WEEK START SUNDAY](sample-by.md#week-start) |
| `M` | **months** (capital M) | the 1st day of the month, 00:00 |
| `y` | years | 1 January, 00:00 |

- **Notes:**
  - `1m` is one minute and `1M` is one month. This is the most common mistake.
  - The other units do not care about case: `1H` is the same as `1h`.
  - Months and years follow the calendar: February is shorter than March.
  - The number must be 1 or more: `0d` is an error.

**Example: Monthly candles of VOLT** (sample data: sample)

```sql
SELECT time, symbol, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close
FROM ochl_day
WHERE symbol = 'VOLT'
SAMPLE BY 1M;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) |
|---|---|---|---|---|---|
| 2025-12-01T00:00:00.000Z | VOLT | 187.7 | 199.7 | 187.5 | 194.3 |
| 2026-08-01T00:00:00.000Z | VOLT | 182.4 | 183.6 | 170.6 | 172.6 |
| 2026-09-01T00:00:00.000Z | VOLT | 171.3 | 192.1 | 167.3 | 191.2 |

(3 rows)

**Example: 1m is a minute: 5 one-minute rows of COAST** (sample data: sample)

```sql
SELECT time, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10'
SAMPLE BY 1m
LIMIT 5;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | 380 | 190 |
| 2026-09-10T05:16:00.000Z | 379.6 | 1330 |
| 2026-09-10T05:17:00.000Z | 380.1 | 1010 |
| 2026-09-10T05:18:00.000Z | 380.4 | 320 |
| 2026-09-10T05:19:00.000Z | 380.7 | 400 |

(5 rows)

**Example: Yearly rows, and a 2-week bucket** (sample data: sample)

```sql
SELECT time, last(close) AS close, count(*) AS days FROM ochl_day WHERE symbol = 'COAST' SAMPLE BY 1y;
SELECT time, first(open) AS open, last(close) AS close FROM ochl_day WHERE symbol = 'COAST' AND time IN '2026' SAMPLE BY 2w WEEK START SUNDAY;
```

Result:

`SELECT time, last(close) AS close, count(*) AS days FROM ochl_day WHERE symbol = 'COAST' SAMPLE BY 1`

| time (TIMESTAMP) | close (DOUBLE) | days (LONG) |
|---|---|---|
| 2025-01-01T00:00:00.000Z | 426.5 | 4 |
| 2026-01-01T00:00:00.000Z | 376.1 | 15 |

(2 rows)

`SELECT time, first(open) AS open, last(close) AS close FROM ochl_day WHERE symbol = 'COAST' AND time`

| time (TIMESTAMP) | open (DOUBLE) | close (DOUBLE) |
|---|---|---|
| 2026-08-23T00:00:00.000Z | 392.1 | 373.2 |
| 2026-09-06T00:00:00.000Z | 374.6 | 376.1 |

(2 rows)

**Example: An unknown unit** (sample data: sample; shows an error)

```sql
SELECT time, count(*) FROM ochl_day SAMPLE BY 1x;
```

Result:

Error: `line 1, column 47: expected a time interval such as 1m, 1h, 1d or 1M (units: ms, s, m, h, d, w, M for month, y for year) but found '1x'`

<a id="fill"></a>

## FILL

Syntax:

```sql
SAMPLE BY interval FILL(NONE)
SAMPLE BY interval FILL(NULL)
SAMPLE BY interval FILL(PREV)
SAMPLE BY interval FILL(LINEAR)
SAMPLE BY interval FILL(constant)
SAMPLE BY interval FILL(rule, rule, ...)      -- one rule per aggregate column
```

Says what to do with **empty buckets** (buckets with no rows), for example minutes when a share did not trade.

| FILL | An empty bucket gets |
|---|---|
| (no FILL) or `FILL(NONE)` | no row |
| `FILL(NULL)` | a row with `NULL` in every aggregate column |
| `FILL(PREV)` | the values of the bucket before it |
| `FILL(LINEAR)` | values on a straight line between the bucket before and the bucket after |
| `FILL(0)`, `FILL(-1.5)`, `FILL('n/a')` | that constant |

- **Returns:** the same columns, with extra rows for the empty buckets. Key columns (like `symbol`) are copied into the new rows.
- **NULL:** `FILL(PREV)` gives `NULL` when there is no bucket before (for that key). `FILL(LINEAR)` gives `NULL` when a bucket before or after is missing.
- **Notes:**
  - `FILL(rule)` with one rule is for **all** aggregate columns: `FILL(PREV)` also copies the volume, and `FILL(0)` also sets the close to 0.
  - `FILL(rule, rule, ...)` gives **each aggregate column its own rule**, in the order of the SELECT list. Candles want `FILL(PREV, PREV, PREV, PREV, 0)`: open, high, low and close from the minute before, volume 0. Time and key columns (like `symbol`) do not count. A column that is an expression of aggregates (`last(close) * 2`) is one column.
  - With more than one rule, give exactly one per aggregate column. Too many or too few is an error that lists the columns. `NONE` cannot be mixed with other rules.
  - FILL only fills between the **first and the last bucket that have data** in the whole result. With many symbols, every symbol gets rows for that whole range. Use [FROM / TO](sample-by.md#from-to) to fill a fixed range instead.
  - FILL fills every bucket, also nights and holidays. `SAMPLE BY 1m FILL(PREV)` over two days makes about 1,200 extra minutes for the night. Filter one trading day with `WHERE time IN '...'`.
  - The constant is not checked against the column type: `FILL('n/a')` puts text into a number column.
  - FILL can make at most 10 million rows.
  - The value in FILL must be a constant: `FILL(close)` is an error.

**Example: COAST had no trades from 12:31 to 12:34 Nepal time: no FILL, then FILL(PREV)** (sample data: sample)

```sql
SELECT time, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST'
  AND time >= '2026-09-10T12:30:00+05:45' AND time < '2026-09-10T12:36:00+05:45'
SAMPLE BY 1m;

SELECT time, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST'
  AND time >= '2026-09-10T12:30:00+05:45' AND time < '2026-09-10T12:36:00+05:45'
SAMPLE BY 1m FILL(PREV);
```

Result:

`SELECT time, last(close) AS close, sum(volume) AS volume FROM ochl_minutes WHERE symbol = 'COAST' AN`

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|
| 2026-09-10T06:45:00.000Z | 380.2 | 620 |
| 2026-09-10T06:50:00.000Z | 379.8 | 800 |

(2 rows)

`SELECT time, last(close) AS close, sum(volume) AS volume FROM ochl_minutes WHERE symbol = 'COAST' AN`

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|
| 2026-09-10T06:45:00.000Z | 380.2 | 620 |
| 2026-09-10T06:46:00.000Z | 380.2 | 620 |
| 2026-09-10T06:47:00.000Z | 380.2 | 620 |
| 2026-09-10T06:48:00.000Z | 380.2 | 620 |
| 2026-09-10T06:49:00.000Z | 380.2 | 620 |
| 2026-09-10T06:50:00.000Z | 379.8 | 800 |

(6 rows)

**Example: FILL(NULL), FILL(LINEAR) and FILL(0) on the same gap** (sample data: sample)

```sql
SELECT time, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST' AND time >= '2026-09-10T12:30:00+05:45' AND time < '2026-09-10T12:36:00+05:45'
SAMPLE BY 1m FILL(NULL);

SELECT time, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST' AND time >= '2026-09-10T12:30:00+05:45' AND time < '2026-09-10T12:36:00+05:45'
SAMPLE BY 1m FILL(LINEAR);

SELECT time, last(close) AS close, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'COAST' AND time >= '2026-09-10T12:30:00+05:45' AND time < '2026-09-10T12:36:00+05:45'
SAMPLE BY 1m FILL(0);
```

Result:

`SELECT time, last(close) AS close, sum(volume) AS volume FROM ochl_minutes WHERE symbol = 'COAST' AN`

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|
| 2026-09-10T06:45:00.000Z | 380.2 | 620 |
| 2026-09-10T06:46:00.000Z | NULL | NULL |
| 2026-09-10T06:47:00.000Z | NULL | NULL |
| 2026-09-10T06:48:00.000Z | NULL | NULL |
| 2026-09-10T06:49:00.000Z | NULL | NULL |
| 2026-09-10T06:50:00.000Z | 379.8 | 800 |

(6 rows)

`SELECT time, last(close) AS close, sum(volume) AS volume FROM ochl_minutes WHERE symbol = 'COAST' AN`

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|
| 2026-09-10T06:45:00.000Z | 380.2 | 620 |
| 2026-09-10T06:46:00.000Z | 380.12 | 656 |
| 2026-09-10T06:47:00.000Z | 380.04 | 692 |
| 2026-09-10T06:48:00.000Z | 379.96 | 728 |
| 2026-09-10T06:49:00.000Z | 379.88 | 764 |
| 2026-09-10T06:50:00.000Z | 379.8 | 800 |

(6 rows)

`SELECT time, last(close) AS close, count(*) AS minutes FROM ochl_minutes WHERE symbol = 'COAST' AND `

| time (TIMESTAMP) | close (DOUBLE) | minutes (LONG) |
|---|---|---|
| 2026-09-10T06:45:00.000Z | 380.2 | 1 |
| 2026-09-10T06:46:00.000Z | 0 | 0 |
| 2026-09-10T06:47:00.000Z | 0 | 0 |
| 2026-09-10T06:48:00.000Z | 0 | 0 |
| 2026-09-10T06:49:00.000Z | 0 | 0 |
| 2026-09-10T06:50:00.000Z | 379.8 | 1 |

(6 rows)

**Example: A rule per column: close from the minute before, volume 0** (sample data: sample)

```sql
SELECT time, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST' AND time >= '2026-09-10T12:30:00+05:45' AND time < '2026-09-10T12:36:00+05:45'
SAMPLE BY 1m FILL(PREV, 0);
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|
| 2026-09-10T06:45:00.000Z | 380.2 | 620 |
| 2026-09-10T06:46:00.000Z | 380.2 | 0 |
| 2026-09-10T06:47:00.000Z | 380.2 | 0 |
| 2026-09-10T06:48:00.000Z | 380.2 | 0 |
| 2026-09-10T06:49:00.000Z | 380.2 | 0 |
| 2026-09-10T06:50:00.000Z | 379.8 | 800 |

(6 rows)

**Example: One rule per aggregate column, or one for all** (sample data: sample; shows an error)

```sql
SELECT time, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes WHERE symbol = 'COAST' SAMPLE BY 1m FILL(PREV, 0, 0);
```

Result:

Error: `FILL has 3 values but the query has 2 aggregate columns (close, volume); expected one FILL value for all of them, or one per aggregate column in SELECT order`

**Example: Two symbols: each symbol gets every minute of the whole range** (sample data: sample)

```sql
SELECT time, symbol, last(close) AS close
FROM ochl_minutes
WHERE time >= '2026-09-10T12:30:00+05:45' AND time < '2026-09-10T12:33:00+05:45'
  AND (symbol = 'COAST' OR time >= '2026-09-10T12:32:00+05:45')
SAMPLE BY 1m FILL(PREV)
ORDER BY symbol, time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T06:45:00.000Z | CITY | NULL |
| 2026-09-10T06:46:00.000Z | CITY | NULL |
| 2026-09-10T06:47:00.000Z | CITY | 503.1 |
| 2026-09-10T06:45:00.000Z | COAST | 380.2 |
| 2026-09-10T06:46:00.000Z | COAST | 380.2 |
| 2026-09-10T06:47:00.000Z | COAST | 380.2 |

(6 rows)

**Example: FILL needs a constant, not a column** (sample data: sample; shows an error)

```sql
SELECT time, last(close) AS close FROM ochl_minutes WHERE symbol = 'COAST' SAMPLE BY 1m FILL(close);
```

Result:

Error: `line 1, column 94: expected NONE, NULL, PREV, LINEAR or a constant such as 0 in FILL(...) but found 'close'`

<a id="from-to"></a>

## FROM / TO

Syntax:

```sql
SAMPLE BY interval FROM start TO end [FILL(...)]
SAMPLE BY interval FROM start [FILL(...)]
SAMPLE BY interval TO end [FILL(...)]
```

Sets the range of the buckets (QuestDB). The result runs from the bucket that holds `start` to the bucket before `end`, whatever rows there are.

| Part | Meaning |
|---|---|
| `start` | the first time: `'2026-09-10T05:00:00Z'`, a `DATE` or `TIMESTAMP` value, `$1`, `now()`. Rows before it are left out. |
| `end` | the time after the last one (**exclusive**, like `time < end`). Rows from it on are left out. |

- **Returns:** with `FILL`, one row for every bucket of the range (and every key), also before the first row and after the last one. Without `FILL`, only the buckets that have rows: `FROM` and `TO` then work like `WHERE time >= start AND time < end`.
- **NULL:** a `NULL` start or end is an error. `FILL(PREV)` gives `NULL` in the buckets before a key's first row.
- **Notes:**
  - The buckets keep their usual start ([ALIGN TO CALENDAR](sample-by.md#align-to-calendar), [TIME ZONE](sample-by.md#time-zone), [WITH OFFSET](sample-by.md#with-offset)). A `start` inside a bucket begins with that bucket, which then only has the rows from `start` on.
  - With no rows in the range and no key columns, every bucket is still a filled row (`FILL(0)` gives zeros). With key columns there is no key to fill, so there are no rows.
  - `FROM` and `TO` are constants: a column or a subquery is an error. Not with [ALIGN TO FIRST OBSERVATION](sample-by.md#align-to-first-observation).
  - The time conditions come from `FROM` / `TO` like a written `WHERE`, so KarelaDB reads only the partitions in the range.

**Example: Every minute from 12:28 to 12:35 Nepal time (TO is not included)** (sample data: sample)

```sql
SELECT time, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST'
SAMPLE BY 1m FROM '2026-09-10T12:28:00+05:45' TO '2026-09-10T12:36:00+05:45' FILL(PREV, 0);
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|
| 2026-09-10T06:43:00.000Z | 379.4 | 730 |
| 2026-09-10T06:44:00.000Z | 379.9 | 1380 |
| 2026-09-10T06:45:00.000Z | 380.2 | 620 |
| 2026-09-10T06:46:00.000Z | 380.2 | 0 |
| 2026-09-10T06:47:00.000Z | 380.2 | 0 |
| 2026-09-10T06:48:00.000Z | 380.2 | 0 |
| 2026-09-10T06:49:00.000Z | 380.2 | 0 |
| 2026-09-10T06:50:00.000Z | 379.8 | 800 |

(8 rows)

**Example: FROM / TO without FILL only cut the rows** (sample data: sample)

```sql
SELECT time, count(*) AS rows
FROM ochl_minutes
WHERE symbol = 'COAST'
SAMPLE BY 1h FROM '2026-09-10T11:00:00+05:45' TO '2026-09-10T13:00:00+05:45'
ALIGN TO CALENDAR TIME ZONE 'Asia/Kathmandu';
```

Result:

| time (TIMESTAMP) | rows (LONG) |
|---|---|
| 2026-09-10T05:15:00.000Z | 60 |
| 2026-09-10T06:15:00.000Z | 56 |

(2 rows)

**Example: FROM must be a time** (sample data: sample; shows an error)

```sql
SELECT time, sum(volume) FROM ochl_minutes SAMPLE BY 1m FROM 'soon';
```

Result:

Error: `line 1, column 62: SAMPLE BY FROM 'soon' is not a time; expected a time such as '2026-09-24T05:00:00Z'`

<a id="align-to-calendar"></a>

## ALIGN TO CALENDAR

Syntax:

```sql
SAMPLE BY interval ALIGN TO CALENDAR
```

Buckets start at round clock times: a `10m` bucket starts at `:00`, `:10`, `:20`, ...; a `1d` bucket at 00:00. This is the **default**, so you never need to write it. QuestDB queries that have it run unchanged.

- **Notes:** the clock is UTC. Use [TIME ZONE](sample-by.md#time-zone) or [WITH OFFSET](sample-by.md#with-offset) to move it.

**Example: 10-minute buckets on the clock, the first row is at 05:17** (sample data: sample)

```sql
SELECT time, first(open) AS open, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time >= '2026-09-10T05:17:00Z' AND time < '2026-09-10T05:40:00Z'
SAMPLE BY 10m ALIGN TO CALENDAR;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | minutes (LONG) |
|---|---|---|
| 2026-09-10T05:10:00.000Z | 504.6 | 3 |
| 2026-09-10T05:20:00.000Z | 504.5 | 10 |
| 2026-09-10T05:30:00.000Z | 504.4 | 10 |

(3 rows)

<a id="align-to-first-observation"></a>

## ALIGN TO FIRST OBSERVATION

Syntax:

```sql
SAMPLE BY interval ALIGN TO FIRST OBSERVATION
```

The first bucket starts at the time of the **first row** (after WHERE). The next buckets follow every interval from there.

- **Notes:**
  - Not with months or years (`1M`, `1y`): their length changes.
  - Not together with `TIME ZONE` or `WITH OFFSET`: those only move calendar buckets.
  - The start depends on the data. When a new earlier row comes in, all buckets move. For charts, calendar buckets are usually better.

**Example: The same rows: buckets start at the first row, 05:17** (sample data: sample)

```sql
SELECT time, first(open) AS open, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time >= '2026-09-10T05:17:00Z' AND time < '2026-09-10T05:40:00Z'
SAMPLE BY 10m ALIGN TO FIRST OBSERVATION;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | minutes (LONG) |
|---|---|---|
| 2026-09-10T05:17:00.000Z | 504.6 | 10 |
| 2026-09-10T05:27:00.000Z | 504.5 | 10 |
| 2026-09-10T05:37:00.000Z | 504.5 | 3 |

(3 rows)

**Example: Not with months** (sample data: sample; shows an error)

```sql
SELECT time, count(*) FROM ochl_day SAMPLE BY 1M ALIGN TO FIRST OBSERVATION;
```

Result:

Error: `ALIGN TO FIRST OBSERVATION needs a fixed interval, not months or years`

**Example: Not with TIME ZONE** (sample data: sample; shows an error)

```sql
SELECT time, count(*) FROM ochl_minutes SAMPLE BY 1h ALIGN TO FIRST OBSERVATION TIME ZONE 'Asia/Kathmandu';
```

Result:

Error: `line 1, column 81: TIME ZONE only applies to calendar buckets; expected ALIGN TO CALENDAR (or no ALIGN TO) instead of ALIGN TO FIRST OBSERVATION`

<a id="time-zone"></a>

## TIME ZONE

Syntax:

```sql
SAMPLE BY interval TIME ZONE 'zone'
SAMPLE BY interval TIME ZONE '+HH:MM' | '-HH:MM'
```

Makes the buckets follow the clock of that time zone: hours start at the full hour **of that clock**, days at its midnight, months at its 1st day.

| Argument | Type | Meaning |
|---|---|---|
| `zone` | text in single quotes | a name like `'Asia/Kathmandu'`, `'NPT'`, `'UTC'`, or a fixed offset like `'+05:45'`. The [list of names](time-and-time-zones.md#time-zone-names). Names do not care about case. |

- **Returns:** the same columns. The bucket times are **still shown in UTC**: the Nepal hour 11:00 is shown as `05:15:00.000Z`.
- **Notes:**
  - A zone with summer time (`'Europe/London'`, `'America/New_York'`) works too: a day bucket starts at local midnight of that day, so it is 23 or 25 hours long when the clocks change ([summer time](time-and-time-zones.md#summer-time)). Nepal has no summer time, so `'Asia/Kathmandu'` and `'+05:45'` are the same.
  - For `1m`, `5m` and `15m` buckets, UTC and Nepal buckets are the same (Nepal is 5 hours **45** minutes ahead). For `1h` and longer they are not.
  - **Daily rows: first check at what time the table stores a day.** Weeks, months and days of daily rows need TIME ZONE **only** when the rows are at local midnight. See the table below.
  - `SAMPLE BY` without `TIME ZONE` cuts on UTC, also after `SET TIME ZONE` (only functions like `date_trunc()` and `hour()` follow the [session's zone](time-and-time-zones.md#session-time-zone)). Without a zone, `ROUND` and `time IN 'YYYY-MM-DD'` work in UTC. Each has a zone form for local days: `time IN '2026-09-10' TIME ZONE 'Asia/Kathmandu'`, `date_trunc('day', time, 'Asia/Kathmandu')`, `timestamp_floor('1d', time, 'Asia/Kathmandu')` and a column `TIMESTAMP ROUND 1d TIME ZONE 'Asia/Kathmandu'`. For the Nepal hour use `hour(to_timezone(time, 'Asia/Kathmandu'))`.

| The table stores a day at | Example: the bar of Thu 10 Sep 2026 | Weeks and months | Filter one day |
|---|---|---|---|
| **00:00 UTC** of that date (like `ochl_day` in the samples) | `2026-09-10T00:00:00Z` | `SAMPLE BY 1w`, **no** TIME ZONE (with it, buckets are stamped 18:15 UTC of the day before) | `time IN '2026-09-10'` |
| **local midnight**, for example Nepal 00:00 | `2026-09-09T18:15:00Z` | `SAMPLE BY 1w TIME ZONE 'Asia/Kathmandu'` | `time IN '2026-09-10' TIME ZONE 'Asia/Kathmandu'` |

**Warning, local-midnight rows:** in UTC these rows belong to the **day before**. Everything that cuts days needs the zone, and nothing gives an error when it is left out:

| Without the zone (wrong for these rows) | With the zone |
|---|---|
| `SAMPLE BY 1w` starts each week at 00:00 UTC (05:45 in Nepal). The first bar of each week goes into the week **before**. | `SAMPLE BY 1w TIME ZONE 'Asia/Kathmandu'` |
| `time IN '2026-09-10'` does **not** find the bar of 10 Sep; it is in `time IN '2026-09-09'`. | `time IN '2026-09-10' TIME ZONE 'Asia/Kathmandu'` (still reads only the partitions of that day) |
| A column `TIMESTAMP ROUND 1d` cuts to the **UTC** day: `'2026-09-10T00:00:00+05:45'` is stored as `2026-09-09T00:00:00Z`, and the Nepal date is lost. | `TIMESTAMP ROUND 1d TIME ZONE 'Asia/Kathmandu'` keeps Nepal midnight |
| `date_trunc('day', time)` gives UTC midnight. | `date_trunc('day', time, 'Asia/Kathmandu')` or `timestamp_floor('1d', time, 'Asia/Kathmandu')`: Nepal midnight, shown in UTC |

The week mistake is the easiest to miss, because the result looks normal.

**Example: 1-hour candles: UTC hours, then Nepal hours** (sample data: sample)

```sql
SELECT time, first(open) AS open, last(close) AS close, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
SAMPLE BY 1h;

SELECT time, first(open) AS open, last(close) AS close, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu';
```

Result:

`SELECT time, first(open) AS open, last(close) AS close, count(*) AS minutes FROM ochl_minutes WHERE `

| time (TIMESTAMP) | open (DOUBLE) | close (DOUBLE) | minutes (LONG) |
|---|---|---|---|
| 2026-09-10T05:00:00.000Z | 504.6 | 506.4 | 45 |
| 2026-09-10T06:00:00.000Z | 506.4 | 501.2 | 60 |
| 2026-09-10T07:00:00.000Z | 501.2 | 502.6 | 60 |
| 2026-09-10T08:00:00.000Z | 502.6 | 505 | 60 |
| 2026-09-10T09:00:00.000Z | 505 | 504.9 | 15 |

(5 rows)

`SELECT time, first(open) AS open, last(close) AS close, count(*) AS minutes FROM ochl_minutes WHERE `

| time (TIMESTAMP) | open (DOUBLE) | close (DOUBLE) | minutes (LONG) |
|---|---|---|---|
| 2026-09-10T05:15:00.000Z | 504.6 | 505.3 | 60 |
| 2026-09-10T06:15:00.000Z | 505.3 | 502.7 | 60 |
| 2026-09-10T07:15:00.000Z | 502.7 | 502.6 | 60 |
| 2026-09-10T08:15:00.000Z | 502.6 | 504.9 | 60 |

(4 rows)

**Example: Nepal days: the bucket starts at Nepal midnight (18:15 UTC)** (sample data: sample)

```sql
SELECT time, symbol, first(open) AS open, last(close) AS close, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY'
SAMPLE BY 1d TIME ZONE '+05:45';
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | close (DOUBLE) | minutes (LONG) |
|---|---|---|---|---|
| 2026-09-08T18:15:00.000Z | CITY | 512 | 504.6 | 240 |
| 2026-09-09T18:15:00.000Z | CITY | 504.6 | 504.9 | 240 |

(2 rows)

**Example: India time for the same rows (UTC+05:30)** (sample data: sample)

```sql
SELECT time, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
SAMPLE BY 1h TIME ZONE 'Asia/Kolkata';
```

Result:

| time (TIMESTAMP) | minutes (LONG) |
|---|---|
| 2026-09-10T04:30:00.000Z | 15 |
| 2026-09-10T05:30:00.000Z | 60 |
| 2026-09-10T06:30:00.000Z | 60 |
| 2026-09-10T07:30:00.000Z | 60 |
| 2026-09-10T08:30:00.000Z | 45 |

(5 rows)

**Example: The same five trading days, stored at UTC midnight and at Nepal midnight** (sample data: sample)

Setup:

```sql
CREATE TABLE bars_utc (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY MONTH;
CREATE TABLE bars_local (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY MONTH;
INSERT INTO bars_utc VALUES ('2026-09-06T00:00:00Z', 'ACME', 1), ('2026-09-07T00:00:00Z', 'ACME', 2),
  ('2026-09-10T00:00:00Z', 'ACME', 3), ('2026-09-13T00:00:00Z', 'ACME', 4), ('2026-09-14T00:00:00Z', 'ACME', 5);
INSERT INTO bars_local VALUES ('2026-09-06T00:00:00+05:45', 'ACME', 1), ('2026-09-07T00:00:00+05:45', 'ACME', 2),
  ('2026-09-10T00:00:00+05:45', 'ACME', 3), ('2026-09-13T00:00:00+05:45', 'ACME', 4), ('2026-09-14T00:00:00+05:45', 'ACME', 5);
```

```sql
-- UTC midnight rows: no TIME ZONE. Weeks start Sunday 6 and Sunday 13 (00:00 UTC).
SELECT time, count(*) AS days, sum(close) AS total FROM bars_utc SAMPLE BY 1w WEEK START SUNDAY;

-- Nepal midnight rows WITHOUT TIME ZONE: wrong. Sunday bars fall into the week before.
SELECT time, count(*) AS days, sum(close) AS total FROM bars_local SAMPLE BY 1w WEEK START SUNDAY;

-- Nepal midnight rows WITH TIME ZONE: right. 18:15 UTC on Saturday is Sunday 00:00 in Nepal.
SELECT time, count(*) AS days, sum(close) AS total FROM bars_local SAMPLE BY 1w WEEK START SUNDAY TIME ZONE 'Asia/Kathmandu';
```

Result:

`SELECT time, count(*) AS days, sum(close) AS total FROM bars_utc SAMPLE BY 1w WEEK START SUNDAY`

| time (TIMESTAMP) | days (LONG) | total (DOUBLE) |
|---|---|---|
| 2026-09-06T00:00:00.000Z | 3 | 6 |
| 2026-09-13T00:00:00.000Z | 2 | 9 |

(2 rows)

`SELECT time, count(*) AS days, sum(close) AS total FROM bars_local SAMPLE BY 1w WEEK START SUNDAY`

| time (TIMESTAMP) | days (LONG) | total (DOUBLE) |
|---|---|---|
| 2026-08-30T00:00:00.000Z | 1 | 1 |
| 2026-09-06T00:00:00.000Z | 3 | 9 |
| 2026-09-13T00:00:00.000Z | 1 | 5 |

(3 rows)

`SELECT time, count(*) AS days, sum(close) AS total FROM bars_local SAMPLE BY 1w TIME ZONE 'Asia/Kath`

| time (TIMESTAMP) | days (LONG) | total (DOUBLE) |
|---|---|---|
| 2026-09-05T18:15:00.000Z | 3 | 6 |
| 2026-09-12T18:15:00.000Z | 2 | 9 |

(2 rows)

**Example: Nepal midnight rows: find one Nepal day and show the Nepal date** (sample data: sample)

Setup:

```sql
CREATE TABLE bars_local (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY MONTH;
INSERT INTO bars_local VALUES ('2026-09-10T00:00:00+05:45', 'CITY', 512.4), ('2026-09-13T00:00:00+05:45', 'CITY', 507.6);
```

```sql
-- The UTC date: finds nothing.
SELECT time, close FROM bars_local WHERE time IN '2026-09-10';

-- The Nepal date: finds the bar.
SELECT time, close,
       to_char(time, 'YYYY-MM-DD', 'Asia/Kathmandu') AS nepal_date,
       date_trunc('day', time) AS utc_midnight,
       date_trunc('day', time, 'Asia/Kathmandu') AS nepal_midnight
FROM bars_local WHERE time IN '2026-09-10' TIME ZONE 'Asia/Kathmandu';
```

Result:

`SELECT time, close FROM bars_local WHERE time IN '2026-09-10'`

| time (TIMESTAMP) | close (DOUBLE) |
|---|---|

(0 rows)

`SELECT time, close, to_char(time, 'YYYY-MM-DD', 'Asia/Kathmandu') AS nepal_date, date_trunc('day', t`

| time (TIMESTAMP) | close (DOUBLE) | nepal_date (STRING) | utc_midnight (TIMESTAMP) | nepal_midnight (TIMESTAMP) |
|---|---|---|---|---|
| 2026-09-09T18:15:00.000Z | 512.4 | 2026-09-10 | 2026-09-09T00:00:00.000Z | 2026-09-09T18:15:00.000Z |

(1 row)

**Example: ROUND 1d cuts to the UTC day; ROUND 1d TIME ZONE keeps the Nepal date** (sample data: sample)

Setup:

```sql
CREATE TABLE bars_round (time TIMESTAMP ROUND 1d, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY YEAR;
CREATE TABLE bars_nepal (time TIMESTAMP ROUND 1d TIME ZONE 'Asia/Kathmandu', symbol SYMBOL, close DOUBLE)
  TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (symbol, time);
```

```sql
-- 9 Sep 00:00 UTC: the Nepal date 10 Sep is lost.
INSERT INTO bars_round VALUES ('2026-09-10T00:00:00+05:45', 'CITY', 512.4);
SELECT time, close FROM bars_round;

-- Nepal midnight (18:15 UTC the day before). 15:00 the same Nepal day is the same key, so it replaces the bar.
INSERT INTO bars_nepal VALUES ('2026-09-10T00:00:00+05:45', 'CITY', 512.4);
INSERT OR REPLACE INTO bars_nepal VALUES ('2026-09-10T15:00:00+05:45', 'CITY', 514.0);
SELECT time, close, to_char(time, 'YYYY-MM-DD', 'Asia/Kathmandu') AS nepal_date FROM bars_nepal;
```

Result:

`INSERT INTO bars_round VALUES ('2026-09-10T00:00:00+05:45', 'CITY', 512.4)`

```text
1 row(s) inserted
```

`SELECT time, close FROM bars_round`

| time (TIMESTAMP) | close (DOUBLE) |
|---|---|
| 2026-09-09T00:00:00.000Z | 512.4 |

(1 row)

`INSERT INTO bars_nepal VALUES ('2026-09-10T00:00:00+05:45', 'CITY', 512.4)`

```text
1 row(s) inserted
```

`INSERT OR REPLACE INTO bars_nepal VALUES ('2026-09-10T15:00:00+05:45', 'CITY', 514.0)`

```text
0 row(s) inserted, 1 replaced
```

`SELECT time, close, to_char(time, 'YYYY-MM-DD', 'Asia/Kathmandu') AS nepal_date FROM bars_nepal`

| time (TIMESTAMP) | close (DOUBLE) | nepal_date (STRING) |
|---|---|---|
| 2026-09-09T18:15:00.000Z | 514 | 2026-09-10 |

(1 row)

**Example: ROUND TIME ZONE takes fixed offsets only, for now** (sample data: sample; shows an error)

```sql
CREATE TABLE bars_london (time TIMESTAMP ROUND 1d TIME ZONE 'Europe/London', close DOUBLE) TIMESERIES(time);
```

Result:

Error: `column 'time' of table 'bars_london' has ROUND ... TIME ZONE 'Europe/London', which is not supported (it may change for daylight saving); use a fixed offset like '+05:45'`

**Example: Hour buckets on the London clock (summer time: +01:00 in September)** (sample data: sample)

```sql
SELECT time, count(*) AS minutes FROM ochl_minutes WHERE symbol = 'COAST' AND time IN '2026-09-10'
SAMPLE BY 1h TIME ZONE 'Europe/London' LIMIT 3;
```

Result:

| time (TIMESTAMP) | minutes (LONG) |
|---|---|
| 2026-09-10T05:00:00.000Z | 45 |
| 2026-09-10T06:00:00.000Z | 56 |
| 2026-09-10T07:00:00.000Z | 60 |

(3 rows)

<a id="with-offset"></a>

## WITH OFFSET

Syntax:

```sql
SAMPLE BY interval WITH OFFSET '+HH:MM'
SAMPLE BY interval WITH OFFSET '-HH:MM'
```

Moves the start of every bucket by a fixed time. `SAMPLE BY 1h WITH OFFSET '+00:15'` makes hours that start at `:15` (UTC), which are the full hours of the Nepal clock.

| Argument | Type | Meaning |
|---|---|---|
| `'+HH:MM'` | text in single quotes | hours `00` to `23`, minutes `00` to `59`. `+` moves later, `-` moves earlier. `'00:15'` without a sign means `'+00:15'` (the QuestDB spelling). |

- **Notes:**
  - An offset is **not** a time zone. `SAMPLE BY 1d WITH OFFSET '+05:45'` makes days that start at 05:45 UTC, not at Nepal midnight. For Nepal days use `TIME ZONE 'Asia/Kathmandu'`.
  - For hours, `'+00:15'` and `'-00:45'` give the same buckets.
  - With `TIME ZONE`, the offset moves the buckets on that zone's clock.
  - Not with `ALIGN TO FIRST OBSERVATION`.
  - QuestDB's `SAMPLE BY 1h ALIGN TO CALENDAR WITH OFFSET '00:15'` runs unchanged and gives the same buckets.

**Example: Nepal-clock hours with an offset, written two ways** (sample data: sample)

```sql
SELECT time, first(open) AS open, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
SAMPLE BY 1h ALIGN TO CALENDAR WITH OFFSET '00:15';

SELECT time, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
SAMPLE BY 1h WITH OFFSET '-00:45';
```

Result:

`SELECT time, first(open) AS open, count(*) AS minutes FROM ochl_minutes WHERE symbol = 'CITY' AND ti`

| time (TIMESTAMP) | open (DOUBLE) | minutes (LONG) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | 504.6 | 60 |
| 2026-09-10T06:15:00.000Z | 505.3 | 60 |
| 2026-09-10T07:15:00.000Z | 502.7 | 60 |
| 2026-09-10T08:15:00.000Z | 502.6 | 60 |

(4 rows)

`SELECT time, count(*) AS minutes FROM ochl_minutes WHERE symbol = 'CITY' AND time IN '2026-09-10' SA`

| time (TIMESTAMP) | minutes (LONG) |
|---|---|
| 2026-09-10T05:15:00.000Z | 60 |
| 2026-09-10T06:15:00.000Z | 60 |
| 2026-09-10T07:15:00.000Z | 60 |
| 2026-09-10T08:15:00.000Z | 60 |

(4 rows)

**Example: Careful: an offset on days is not Nepal midnight** (sample data: sample)

```sql
SELECT time, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY'
SAMPLE BY 1d WITH OFFSET '+05:45';
```

Result:

| time (TIMESTAMP) | minutes (LONG) |
|---|---|
| 2026-09-08T05:45:00.000Z | 30 |
| 2026-09-09T05:45:00.000Z | 240 |
| 2026-09-10T05:45:00.000Z | 210 |

(3 rows)

**Example: TIME ZONE and WITH OFFSET together: Nepal hours that start at half past (10:30, 11:30, ...)** (sample data: sample)

```sql
SELECT time, first(open) AS open, last(close) AS close, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu' WITH OFFSET '+00:30';
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | close (DOUBLE) | minutes (LONG) |
|---|---|---|---|
| 2026-09-10T04:45:00.000Z | 504.6 | 506.5 | 30 |
| 2026-09-10T05:45:00.000Z | 506.5 | 503.8 | 60 |
| 2026-09-10T06:45:00.000Z | 503.8 | 503.6 | 60 |
| 2026-09-10T07:45:00.000Z | 503.6 | 505.7 | 60 |
| 2026-09-10T08:45:00.000Z | 505.7 | 504.9 | 30 |

(5 rows)

**Example: The hour needs two digits** (sample data: sample; shows an error)

```sql
SELECT time, count(*) FROM ochl_minutes SAMPLE BY 1h WITH OFFSET '5:45';
```

Result:

Error: `line 1, column 66: expected an offset in single quotes such as '+00:15' or '-05:45' after WITH OFFSET but found '5:45'`

<a id="week-start"></a>

## WEEK START

Syntax:

```sql
SAMPLE BY n w WEEK START SUNDAY
SAMPLE BY n w WEEK START MONDAY
```

Chooses the first day of a week bucket. The default is `MONDAY`. On a Sunday-to-Thursday trading week (as on some exchanges), weekly candles need `WEEK START SUNDAY`.

- **Returns:** week buckets that start at 00:00 UTC of that day (or of the TIME ZONE clock).
- **Notes:**
  - Only with a week interval (`1w`, `2w`, ...).
  - QuestDB cannot do this in SQL; the 006 app folds days into Sunday weeks in Go. In KarelaDB one query does it.
  - `ochl_day` rows are at 00:00 UTC, so these examples have no `TIME ZONE`. When your daily rows are at **local** midnight (Nepal 00:00 = 18:15 UTC the day before), add `TIME ZONE 'Asia/Kathmandu'`, or the weeks are stamped on the wrong day (see [TIME ZONE](sample-by.md#time-zone)).

**Example: Sunday-to-Thursday trading weeks of CITY** (sample data: sample)

```sql
SELECT time, symbol,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume, count(*) AS days
FROM ochl_day
WHERE symbol = 'CITY' AND time IN '2026'
SAMPLE BY 1w WEEK START SUNDAY;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) | days (LONG) |
|---|---|---|---|---|---|---|---|
| 2026-08-23T00:00:00.000Z | CITY | 505 | 517 | 502 | 505.9 | 601770 | 5 |
| 2026-08-30T00:00:00.000Z | CITY | 507.3 | 511.2 | 494.1 | 497.9 | 538130 | 5 |
| 2026-09-06T00:00:00.000Z | CITY | 497.4 | 512.4 | 495 | 504.9 | 591860 | 5 |

(3 rows)

With the default Monday weeks, Sunday 23 August goes into the week of Monday 17 August, alone:

**Example: The default week starts on Monday** (sample data: sample)

```sql
SELECT time, first(open) AS open, last(close) AS close, count(*) AS days
FROM ochl_day
WHERE symbol = 'CITY' AND time IN '2026'
SAMPLE BY 1w;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | close (DOUBLE) | days (LONG) |
|---|---|---|---|
| 2026-08-17T00:00:00.000Z | 505 | 507.9 | 1 |
| 2026-08-24T00:00:00.000Z | 508.3 | 503.1 | 5 |
| 2026-08-31T00:00:00.000Z | 502.5 | 499 | 5 |
| 2026-09-07T00:00:00.000Z | 497.3 | 504.9 | 4 |

(4 rows)

**Example: WEEK START with an hour interval** (sample data: sample; shows an error)

```sql
SELECT time, count(*) FROM ochl_minutes SAMPLE BY 1h WEEK START SUNDAY;
```

Result:

Error: `line 1, column 54: WEEK START needs a week interval; expected SAMPLE BY 1w (or 2w, ...) but the interval is 1h`
