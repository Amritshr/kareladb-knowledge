# Sample data

> The small made-up stock market dataset that most help examples use, with a few rows of each.

- Category: Getting started
- Keywords: sample, fixture, demo data, example data, stock market, tutorial data, schema.sql, sample-data.sql, securities, brokers, ochl_day, ochl_minutes, trade_log, live_data, candles, trades
- See also: [Quick start](quick-start.md), [CREATE TABLE](create-table.md), [SAMPLE BY](sample-by.md), [LATEST ON](latest-on.md), [Joins](joins.md)

Most examples in this help use a small **made-up** stock market dataset: companies, brokers, price candles, trades and live prices. The names and prices only look real. It is just one example of what KDB stores; the same SQL works for sensor readings, logs and metrics, accounting, users and logins, or any app's data. The examples call it the fixture `sample`. Every example starts with a fresh copy, so an example that changes rows does not change the next one.

| Table | Kind | Rows | What it holds |
|---|---|---|---|
| `securities` | relational | 5 | companies: CITY, COAST, VOLT, TELCO, ACME |
| `brokers` | relational | 5 | broker numbers and names |
| `ochl_day` | time-series, `PARTITION BY YEAR` | 57 | daily candles of CITY, COAST, VOLT: 4 days of 2025-12 and 15 days of 2026-08 and 2026-09 |
| `ochl_minutes` | time-series, `PARTITION BY MONTH` | 956 | one-minute candles of CITY and COAST on 2026-09-09 and 2026-09-10 |
| `trade_log` | time-series, `PARTITION BY DAY` | 32 | trades on 2026-09-09 and 2026-09-10 |
| `live_data` | time-series, `PARTITION BY DAY` | 12 | live prices of CITY, COAST, VOLT, TELCO at three times on 2026-09-10 |

To load the same data into your own database, see [quick start](quick-start.md#sample-data). The files are `docs/tutorial/examples/setup/schema.sql` and `sample-data.sql`.

**Example: All tables and their row counts** (sample data: sample)

```sql
SHOW TABLES;
```

Result:

| name (STRING) | kind (STRING) | partition (STRING) | columns (INT) | rows (LONG) |
|---|---|---|---|---|
| brokers | relational | NONE | 2 | 5 |
| live_data | timeseries | DAY | 12 | 12 |
| ochl_day | timeseries | YEAR | 7 | 57 |
| ochl_minutes | timeseries | MONTH | 7 | 956 |
| securities | relational | NONE | 3 | 5 |
| trade_log | timeseries | DAY | 8 | 32 |

(6 rows)

## securities

Syntax:

```sql
CREATE TABLE securities (
  symbol SYMBOL PRIMARY KEY,
  name   STRING NOT NULL,
  sector STRING
);
```

One row per listed company. `symbol` is the key.

| Column | Type | Meaning |
|---|---|---|
| `symbol` | `SYMBOL` | stock symbol, like `CITY` |
| `name` | `STRING` | company name |
| `sector` | `STRING` | business sector, like `Banking` |

**Example: All companies** (sample data: sample)

```sql
SELECT symbol, name, sector FROM securities ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | name (STRING) | sector (STRING) |
|---|---|---|
| ACME | Acme Investment Company | Investment |
| CITY | City Bank Limited | Banking |
| COAST | Coastal Bank Limited | Banking |
| TELCO | Northwind Telecom Limited | Telecom |
| VOLT | Volt River Hydropower Limited | Energy |

(5 rows)

**Example: Last daily close with the company name (a join)** (sample data: sample)

```sql
SELECT s.symbol, s.name, d.close
FROM ochl_day d JOIN securities s ON s.symbol = d.symbol
WHERE d.time IN '2026-09-10'
ORDER BY s.symbol;
```

Result:

| symbol (SYMBOL) | name (STRING) | close (DOUBLE) |
|---|---|---|
| CITY | City Bank Limited | 504.9 |
| COAST | Coastal Bank Limited | 376.1 |
| VOLT | Volt River Hydropower Limited | 191.2 |

(3 rows)

## brokers

Syntax:

```sql
CREATE TABLE brokers (
  id   INT PRIMARY KEY,
  name STRING NOT NULL
);
```

One row per broker. `trade_log.buyer` and `trade_log.seller` point to `brokers(id)` with `REFERENCES`.

| Column | Type | Meaning |
|---|---|---|
| `id` | `INT` | broker number |
| `name` | `STRING` | broker name |

**Example: All brokers** (sample data: sample)

```sql
SELECT id, name FROM brokers ORDER BY id;
```

Result:

| id (INT) | name (STRING) |
|---|---|
| 1 | Keystone Securities |
| 34 | Vision Securities |
| 45 | Imperial Securities |
| 49 | Online Securities |
| 58 | Northgate Securities |

(5 rows)

## ochl_day

Syntax:

```sql
CREATE TABLE ochl_day (
  time   TIMESTAMP ROUND 1d,
  symbol SYMBOL,
  open   DOUBLE,
  high   DOUBLE,
  low    DOUBLE,
  close  DOUBLE,
  volume DOUBLE
) TIMESERIES(time) PARTITION BY YEAR DEDUP KEY (symbol, time);
```

Daily candles (open, high, low, close and volume). `time` is the trading date at 00:00 UTC. `ROUND 1d` cuts every time down to the day, and `DEDUP KEY (symbol, time)` allows one row per symbol per day.

- **Notes:** the data has two parts: 2025-12-28 to 2025-12-31, and 2026-08-23 to 2026-09-10 (trading days of a Sunday-to-Thursday trading week, as on some exchanges). So there are two partitions: `2025` and `2026`.

**Example: Daily candles of one day** (sample data: sample)

```sql
SELECT time, symbol, open, high, low, close, volume FROM ochl_day WHERE time IN '2026-09-10' ORDER BY symbol;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.6 | 507 | 500.7 | 504.9 | 183040 |
| 2026-09-10T00:00:00.000Z | COAST | 380.1 | 382 | 373.2 | 376.1 | 186200 |
| 2026-09-10T00:00:00.000Z | VOLT | 185.6 | 192.1 | 184.2 | 191.2 | 41470 |

(3 rows)

**Example: How many days per symbol** (sample data: sample)

```sql
SELECT symbol, count(*) AS days, min(time) AS first_day, max(time) AS last_day FROM ochl_day GROUP BY symbol ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | days (LONG) | first_day (TIMESTAMP) | last_day (TIMESTAMP) |
|---|---|---|---|
| CITY | 19 | 2025-12-28T00:00:00.000Z | 2026-09-10T00:00:00.000Z |
| COAST | 19 | 2025-12-28T00:00:00.000Z | 2026-09-10T00:00:00.000Z |
| VOLT | 19 | 2025-12-28T00:00:00.000Z | 2026-09-10T00:00:00.000Z |

(3 rows)

## ochl_minutes

Syntax:

```sql
CREATE TABLE ochl_minutes (
  time   TIMESTAMP ROUND 1m,
  symbol SYMBOL,
  open   DOUBLE,
  high   DOUBLE,
  low    DOUBLE,
  close  DOUBLE,
  volume DOUBLE
) TIMESERIES(time) PARTITION BY MONTH DEDUP KEY (symbol, time);
```

One-minute candles. The market is open 11:00 to 15:00 local time (+05:45, Nepal time), which is 05:15 to 09:15 UTC, so a full day has 240 minutes.

- **Notes:** only CITY (480 rows) and COAST (476 rows) have minute candles, on 2026-09-09 and 2026-09-10.

**Example: The first 5 minutes of CITY on 2026-09-10 (11:00 Nepal time)** (sample data: sample)

```sql
SELECT time, symbol, open, high, low, close, volume
FROM ochl_minutes
WHERE symbol = 'CITY' AND time >= '2026-09-10T11:00:00+05:45'
ORDER BY time
LIMIT 5;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|---|
| 2026-09-10T05:15:00.000Z | CITY | 504.6 | 504.6 | 504.4 | 504.4 | 960 |
| 2026-09-10T05:16:00.000Z | CITY | 504.4 | 504.7 | 504.3 | 504.6 | 700 |
| 2026-09-10T05:17:00.000Z | CITY | 504.6 | 504.9 | 504 | 504.2 | 150 |
| 2026-09-10T05:18:00.000Z | CITY | 504.2 | 504.6 | 504.1 | 504.4 | 1050 |
| 2026-09-10T05:19:00.000Z | CITY | 504.4 | 504.8 | 504.1 | 504.5 | 450 |

(5 rows)

**Example: Minute candles turned into hourly candles** (sample data: sample)

```sql
SELECT time, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-09'
SAMPLE BY 1h;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-09T05:00:00.000Z | 398 | 398.8 | 392.2 | 392.9 | 33000 |
| 2026-09-09T06:00:00.000Z | 392.9 | 393.6 | 387.4 | 387.7 | 43470 |
| 2026-09-09T07:00:00.000Z | 387.7 | 389.2 | 381.6 | 382.3 | 49820 |
| 2026-09-09T08:00:00.000Z | 382.3 | 384.2 | 379.2 | 380 | 49500 |
| 2026-09-09T09:00:00.000Z | 380 | 380.9 | 379.4 | 380.1 | 10540 |

(5 rows)

## trade_log

Syntax:

```sql
CREATE TABLE trade_log (
  date           TIMESTAMP ROUND 1d,
  transaction_id LONG,
  symbol         SYMBOL,
  buyer          INT REFERENCES brokers(id),
  seller         INT REFERENCES brokers(id),
  quantity       LONG,
  rate           DOUBLE,
  amount         DOUBLE AS (quantity * rate)
) TIMESERIES(date) PARTITION BY DAY DEDUP KEY (date, transaction_id);
```

Every trade of the day: who bought, who sold, how many shares and at what rate. `amount` is a **computed column**: it is not stored, KDB works it out from `quantity * rate` when you read it.

- **Notes:** a broker that trades point to cannot be deleted from `brokers`.

**Example: The first trades of 2026-09-10 with broker names** (sample data: sample)

```sql
SELECT f.transaction_id, f.symbol, b.name AS buyer, s.name AS seller, f.quantity, f.rate, f.amount
FROM trade_log f
JOIN brokers b ON b.id = f.buyer
JOIN brokers s ON s.id = f.seller
WHERE f.date IN '2026-09-10'
ORDER BY f.transaction_id
LIMIT 5;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | buyer (STRING) | seller (STRING) | quantity (LONG) | rate (DOUBLE) | amount (DOUBLE) |
|---|---|---|---|---|---|---|
| 100009 | COAST | Vision Securities | Imperial Securities | 50 | 400 | 20000 |
| 100010 | CITY | Keystone Securities | Imperial Securities | 50 | 517 | 25850 |
| 100011 | VOLT | Keystone Securities | Northgate Securities | 50 | 184 | 9200 |
| 100012 | VOLT | Northgate Securities | Imperial Securities | 200 | 184 | 36800 |
| 100013 | COAST | Northgate Securities | Keystone Securities | 50 | 398 | 19900 |

(5 rows)

**Example: Turnover per symbol** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades, sum(quantity) AS shares, sum(amount) AS turnover
FROM trade_log
GROUP BY symbol
ORDER BY turnover DESC;
```

Result:

| symbol (SYMBOL) | trades (LONG) | shares (LONG) | turnover (DOUBLE) |
|---|---|---|---|
| TELCO | 6 | 2770 | 2438260 |
| CITY | 11 | 2420 | 1247230 |
| COAST | 11 | 3070 | 1227510 |
| VOLT | 4 | 400 | 73950 |

(4 rows)

## live_data

Syntax:

```sql
CREATE TABLE live_data (
  timestamp        TIMESTAMP,
  symbol           SYMBOL,
  ltp              DOUBLE,
  ltv              LONG,
  point_change     DOUBLE,
  pct_change       DOUBLE,
  open             DOUBLE,
  high             DOUBLE,
  low              DOUBLE,
  avg_traded_price DOUBLE,
  prev_close       DOUBLE,
  volume           LONG
) TIMESERIES(timestamp) PARTITION BY DAY DEDUP KEY (timestamp, symbol);
```

Snapshots of live market prices: last traded price (`ltp`), last traded volume (`ltv`), change from the previous close, and the day's open, high, low and volume so far.

- **Notes:** the snapshots are at 11:05, 13:00 and 14:59 Nepal time on 2026-09-10. The time column is called `timestamp`; that word is not reserved.

**Example: The latest price of every symbol** (sample data: sample)

```sql
SELECT timestamp, symbol, ltp, pct_change, volume
FROM live_data
LATEST ON timestamp PARTITION BY symbol
ORDER BY symbol;
```

Result:

| timestamp (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) | pct_change (DOUBLE) | volume (LONG) |
|---|---|---|---|---|
| 2026-09-10T09:14:00.000Z | CITY | 527.1 | 2.71 | 75490 |
| 2026-09-10T09:14:00.000Z | COAST | 401.9 | 0.7 | 35210 |
| 2026-09-10T09:14:00.000Z | TELCO | 897.7 | 1.9 | 69340 |
| 2026-09-10T09:14:00.000Z | VOLT | 184 | -0.86 | 55940 |

(4 rows)

**Example: All snapshots of TELCO** (sample data: sample)

```sql
SELECT timestamp, ltp, point_change, pct_change FROM live_data WHERE symbol = 'TELCO' ORDER BY timestamp;
```

Result:

| timestamp (TIMESTAMP) | ltp (DOUBLE) | point_change (DOUBLE) | pct_change (DOUBLE) |
|---|---|---|---|
| 2026-09-10T05:20:00.000Z | 860.5 | -20.5 | -2.33 |
| 2026-09-10T07:15:00.000Z | 869 | -12 | -1.36 |
| 2026-09-10T09:14:00.000Z | 897.7 | 16.7 | 1.9 |

(3 rows)
