# LATEST ON

> Keep only the newest row of each symbol (or of each group of columns).

- Category: Time-series
- Keywords: LATEST, LATEST ON, PARTITION BY, newest row, last row, latest price, last price, LTP, live prices, last login, most recent, LATEST BY, QuestDB, top movers, gainers
- See also: [SAMPLE BY](sample-by.md), [WHERE](where.md), [Time and time zones](time-and-time-zones.md), [Candles cookbook (top-gainers)](candles-cookbook.md#top-gainers), [Joins (asof-join)](joins.md#asof-join)

`LATEST ON` keeps **one row per group: the row with the newest time**. The usual use is "the last price of every symbol" from a table of live price snapshots.

- Write it after `WHERE` and before `SAMPLE BY`, `GROUP BY` and `ORDER BY`.
- It works like QuestDB's `LATEST ON ... PARTITION BY ...`, so queries from the 006 app run unchanged.

**Example: Live market: the last snapshot of every symbol** (sample data: sample)

```sql
SELECT symbol, ltp, point_change, pct_change, timestamp
FROM live_data
LATEST ON timestamp PARTITION BY symbol
ORDER BY pct_change DESC;
```

Result:

| symbol (SYMBOL) | ltp (DOUBLE) | point_change (DOUBLE) | pct_change (DOUBLE) | timestamp (TIMESTAMP) |
|---|---|---|---|---|
| CITY | 527.1 | 13.9 | 2.71 | 2026-09-10T09:14:00.000Z |
| TELCO | 897.7 | 16.7 | 1.9 | 2026-09-10T09:14:00.000Z |
| COAST | 401.9 | 2.8 | 0.7 | 2026-09-10T09:14:00.000Z |
| VOLT | 184 | -1.6 | -0.86 | 2026-09-10T09:14:00.000Z |

(4 rows)

<a id="latest-on"></a>

## LATEST ON

Syntax:

```sql
SELECT ...
FROM table
[WHERE condition]
LATEST ON time_column PARTITION BY column [, column ...]
[GROUP BY ...] [HAVING ...]
[ORDER BY ...] [LIMIT n]
```

For each different value of the `PARTITION BY` columns, keeps only the row with the biggest `time_column`. All other rows are dropped before the SELECT list is computed.

| Part | Type | Meaning |
|---|---|---|
| `time_column` | `TIMESTAMP` or `DATE` column | "newest" means the biggest value of this column |
| `column, ...` | column names | the groups: one row is kept per different value (or per different combination of values) |

- **Returns:** one row per group. Without `ORDER BY`, the rows come oldest first (by the kept time). Add `ORDER BY` when the order matters.
- **NULL:** rows whose time is `NULL` are skipped. A `NULL` in a `PARTITION BY` column is a group of its own.
- **Notes:**
  - `PARTITION BY` here means "per group". It has nothing to do with the `PARTITION BY` of `CREATE TABLE` (the files on disk).
  - It works on one table, a view, or a subquery with an alias. It does **not** work with joins.
  - It also works on relational tables that have a `TIMESTAMP` column (for example the last login of every user).
  - When two rows of a group have the same newest time, KarelaDB keeps the one it reads last.
  - On a table split by symbol (`PARTITION BY ..., SYMBOL(symbol)`, see [partitions](partitions-and-dedup.md#partition-by-symbol)), `LATEST ON time PARTITION BY symbol` reads only the last rows of each symbol's newest file, on all threads, not the whole table. With `PARTITION BY YEAR` or `MONTH` that holds without a `WHERE` or with only `symbol = ...` / `symbol IN (...)`; other conditions read the files in full.
  - `WHERE` runs **before** `LATEST ON` (see [the next part](latest-on.md#where-first)).
  - Aggregates, window functions, `ORDER BY` and `LIMIT` run **after** it, on the kept rows only.
  - The column names must be plain names: `PARTITION BY upper(symbol)` is not allowed.
  - QuestDB's older `LATEST BY symbol` works too: it is `LATEST ON` the table's own time column `PARTITION BY symbol`. It needs a time-series table (one with `TIMESERIES(...)`), and it may stand before or after `WHERE`; the `WHERE` still picks the rows first.
  - KarelaDB keeps one row per group while it reads. More groups than `--max-groups` (5,000,000 by default) stop the query with `the query makes more than N groups (max_groups)`; see [protection](protection.md).

**Example: The newest daily candle of every symbol** (sample data: sample)

```sql
SELECT time, symbol, close, volume
FROM ochl_day
LATEST ON time PARTITION BY symbol;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 183040 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 186200 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 | 41470 |

(3 rows)

**Example: Two columns: the last trade of each broker in each symbol** (sample data: sample)

```sql
SELECT buyer, symbol, date, transaction_id, quantity, rate
FROM trade_log
LATEST ON date PARTITION BY buyer, symbol
ORDER BY buyer, symbol
LIMIT 6;
```

Result:

| buyer (INT) | symbol (SYMBOL) | date (TIMESTAMP) | transaction_id (LONG) | quantity (LONG) | rate (DOUBLE) |
|---|---|---|---|---|---|
| 1 | CITY | 2026-09-10T00:00:00.000Z | 100024 | 100 | 514.5 |
| 1 | COAST | 2026-09-10T00:00:00.000Z | 100026 | 200 | 400 |
| 1 | TELCO | 2026-09-10T00:00:00.000Z | 100021 | 50 | 878 |
| 1 | VOLT | 2026-09-10T00:00:00.000Z | 100020 | 100 | 187 |
| 34 | CITY | 2026-09-09T00:00:00.000Z | 100004 | 500 | 514.5 |
| 34 | COAST | 2026-09-10T00:00:00.000Z | 100009 | 50 | 400 |

(6 rows)

**Example: App users: the last person who logged in from each city** (sample data: query-app)

```sql
SELECT city, username, last_login
FROM app_users
LATEST ON last_login PARTITION BY city
ORDER BY last_login DESC;
```

Result:

| city (STRING) | username (STRING) | last_login (TIMESTAMP) |
|---|---|---|
| Lalitpur | bikash | 2026-09-11T04:20:00.000Z |
| Dharan | gita | 2026-09-11T00:45:00.000Z |
| Kathmandu | ram | 2026-09-10T14:30:00.000Z |
| Pokhara | suman | 2026-09-10T03:55:00.000Z |
| NULL | anita | 2026-08-30T06:15:00.000Z |

(5 rows)

**Example: News: the newest article of each company** (sample data: content-news)

```sql
SELECT symbol, published_at, title
FROM news
LATEST ON published_at PARTITION BY symbol
ORDER BY published_at DESC;
```

Result:

| symbol (STRING) | published_at (TIMESTAMP) | title (STRING) |
|---|---|---|
| COAST | 2026-09-02T03:15:00.000Z | Coastal Bank merger talks |
| NULL | 2026-09-01T02:15:00.000Z | Market index closes at 2,840 |
| VOLT | 2026-08-15T04:15:00.000Z | Hydropower company plans IPO |
| CITY | 2026-08-01T05:45:00.000Z | सिटी बैंकको नाफा बढ्यो |

(4 rows)

**Example: Accounting: the last journal line of each account** (sample data: query-app)

```sql
SELECT account, entry_date, debit, credit, memo
FROM ledger
LATEST ON entry_date PARTITION BY account
ORDER BY account;
```

Result:

| account (INT) | entry_date (TIMESTAMP) | debit (DECIMAL(2)) | credit (DECIMAL(2)) | memo (STRING) |
|---|---|---|---|---|
| 1000 | 2026-09-05T00:00:00.000Z | NULL | 25000.00 | September rent |
| 1100 | 2026-09-10T00:00:00.000Z | 12600.00 | NULL | Sell 20 CITY at 630 |
| 1200 | 2026-09-10T00:00:00.000Z | NULL | 10300.00 | Sell 20 CITY at 630 |
| 2000 | 2026-09-03T00:00:00.000Z | 257500.00 | NULL | Pay the broker |
| 3000 | 2026-09-01T00:00:00.000Z | NULL | 500000.00 | Owner puts money in the bank |
| 4000 | 2026-09-08T00:00:00.000Z | NULL | 6250.00 | CITY cash dividend |
| 4100 | 2026-09-10T00:00:00.000Z | NULL | 2300.00 | Sell 20 CITY at 630 |
| 5000 | 2026-09-03T00:00:00.000Z | 1030.00 | NULL | Commission on the CITY buy |
| 5100 | 2026-09-05T00:00:00.000Z | 25000.00 | NULL | September rent |

(9 rows)

<a id="where-first"></a>

## WHERE with LATEST ON

Syntax:

```sql
SELECT ... FROM table
WHERE condition
LATEST ON time_column PARTITION BY column, ...
```

`WHERE` removes rows first. `LATEST ON` then picks the newest of the rows that are left. So `WHERE` changes **which** row is the newest.

- **Notes:**
  - "The last price before 13:30 Nepal time" is `WHERE timestamp < '...13:30:00+05:45'`, then `LATEST ON`.
  - "The last price today" is `WHERE timestamp IN '2026-09-10'`: a symbol with no row today is not in the result at all.
  - To filter the **kept** rows (for example "only symbols that are up now"), put the LATEST ON query in a subquery and write the condition outside. A condition in `WHERE` would pick an older row instead.
  - A time condition in `WHERE` also makes the query fast: KarelaDB reads only the partitions of that time.

**Example: The last price of each symbol before 13:30 Nepal time** (sample data: sample)

```sql
SELECT symbol, ltp, timestamp
FROM live_data
WHERE timestamp < '2026-09-10T13:30:00+05:45'
LATEST ON timestamp PARTITION BY symbol;
```

Result:

| symbol (SYMBOL) | ltp (DOUBLE) | timestamp (TIMESTAMP) |
|---|---|---|
| CITY | 515.6 | 2026-09-10T07:15:00.000Z |
| COAST | 391.4 | 2026-09-10T07:15:00.000Z |
| TELCO | 869 | 2026-09-10T07:15:00.000Z |
| VOLT | 185 | 2026-09-10T07:15:00.000Z |

(4 rows)

**Example: The same text as the 006 app (live_movers.go)** (sample data: sample)

```sql
SELECT symbol, ltp, point_change, pct_change, volume
FROM live_data
WHERE symbol IN ('CITY', 'COAST') AND timestamp >= '2026-09-10T00:00:00.000000Z'
LATEST ON timestamp PARTITION BY symbol;
```

Result:

| symbol (SYMBOL) | ltp (DOUBLE) | point_change (DOUBLE) | pct_change (DOUBLE) | volume (LONG) |
|---|---|---|---|---|
| CITY | 527.1 | 13.9 | 2.71 | 75490 |
| COAST | 401.9 | 2.8 | 0.7 | 35210 |

(2 rows)

**Example: Wrong and right: symbols whose LAST change is below zero** (sample data: sample)

```sql
-- Wrong: WHERE runs first, so you get the last FALLING row of each symbol (old rows).
SELECT symbol, pct_change, timestamp
FROM live_data
WHERE pct_change < 0
LATEST ON timestamp PARTITION BY symbol;

-- Right: take the newest row first, then filter.
SELECT symbol, pct_change, timestamp
FROM (SELECT symbol, pct_change, timestamp FROM live_data LATEST ON timestamp PARTITION BY symbol) t
WHERE pct_change < 0;
```

Result:

`SELECT symbol, pct_change, timestamp FROM live_data WHERE pct_change < 0 LATEST ON timestamp PARTITI`

| symbol (SYMBOL) | pct_change (DOUBLE) | timestamp (TIMESTAMP) |
|---|---|---|
| CITY | -0.04 | 2026-09-10T05:20:00.000Z |
| COAST | -1.93 | 2026-09-10T07:15:00.000Z |
| TELCO | -1.36 | 2026-09-10T07:15:00.000Z |
| VOLT | -0.86 | 2026-09-10T09:14:00.000Z |

(4 rows)

`SELECT symbol, pct_change, timestamp FROM (SELECT symbol, pct_change, timestamp FROM live_data LATES`

| symbol (SYMBOL) | pct_change (DOUBLE) | timestamp (TIMESTAMP) |
|---|---|---|
| VOLT | -0.86 | 2026-09-10T09:14:00.000Z |

(1 row)

**Example: The last close of 2025 (the year before)** (sample data: sample)

```sql
SELECT time, symbol, close
FROM ochl_day
WHERE time IN '2025'
LATEST ON time PARTITION BY symbol;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2025-12-31T00:00:00.000Z | CITY | 542.4 |
| 2025-12-31T00:00:00.000Z | COAST | 426.5 |
| 2025-12-31T00:00:00.000Z | VOLT | 194.3 |

(3 rows)

<a id="latest-on-other-clauses"></a>

## LATEST ON with other clauses

Syntax:

```sql
SELECT ... FROM table [WHERE ...]
LATEST ON time_column PARTITION BY column, ...
[ORDER BY ...] [LIMIT n]
```

The other parts of the query see only the kept rows.

- **Notes:**
  - `ORDER BY ... LIMIT n` after LATEST ON gives a "top n" list of the newest rows.
  - `count(*)` after LATEST ON counts the kept rows, so it is `1` per group.
  - A view or a subquery can be the source: `FROM (SELECT ...) t LATEST ON ...`.

**Example: Top 2 gainers right now** (sample data: sample)

```sql
SELECT symbol, ltp, pct_change
FROM live_data
LATEST ON timestamp PARTITION BY symbol
ORDER BY pct_change DESC
LIMIT 2;
```

Result:

| symbol (SYMBOL) | ltp (DOUBLE) | pct_change (DOUBLE) |
|---|---|---|
| CITY | 527.1 | 2.71 |
| TELCO | 897.7 | 1.9 |

(2 rows)

**Example: Up or down, with CASE** (sample data: sample)

```sql
SELECT symbol, pct_change,
       CASE WHEN pct_change > 0 THEN 'up' WHEN pct_change < 0 THEN 'down' ELSE 'flat' END AS direction
FROM live_data
LATEST ON timestamp PARTITION BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | pct_change (DOUBLE) | direction (STRING) |
|---|---|---|
| CITY | 2.71 | up |
| COAST | 0.7 | up |
| TELCO | 1.9 | up |
| VOLT | -0.86 | down |

(4 rows)

**Example: Aggregates run after LATEST ON: one row per symbol is left** (sample data: sample)

```sql
SELECT symbol, count(*) AS rows_left
FROM live_data
LATEST ON timestamp PARTITION BY symbol;
```

Result:

| symbol (SYMBOL) | rows_left (LONG) |
|---|---|
| CITY | 1 |
| COAST | 1 |
| TELCO | 1 |
| VOLT | 1 |

(4 rows)

<a id="latest-on-errors"></a>

## Errors

Syntax:

```sql
LATEST ON time_column PARTITION BY column, ...
```

The common mistakes and their messages.

| Mistake | Message |
|---|---|
| `LATEST ON timestamp` without `PARTITION BY` | `expected PARTITION BY after LATEST ON timestamp` |
| the column after `LATEST ON` is not a time | `LATEST ON needs a TIMESTAMP or DATE column` |
| an unknown column | `LATEST ON: unknown column '...'` |
| a query with a `JOIN` | `LATEST ON works on a single table (no joins)` |
| `LATEST BY` on a table without a time column | `LATEST BY needs a table with a time column` |

- **Notes:** to use LATEST ON rows in a join, put the LATEST ON query in a subquery and join the subquery.

**Example: PARTITION BY is needed** (sample data: sample; shows an error)

```sql
SELECT symbol, ltp FROM live_data LATEST ON timestamp;
```

Result:

Error: `line 1, column 54: expected PARTITION BY after LATEST ON timestamp, as in LATEST ON timestamp PARTITION BY symbol, but found ';'`

**Example: The column must be a time** (sample data: sample; shows an error)

```sql
SELECT symbol, ltp FROM live_data LATEST ON symbol PARTITION BY symbol;
```

Result:

Error: `LATEST ON needs a TIMESTAMP or DATE column, 'symbol' is SYMBOL`

**Example: No joins** (sample data: sample; shows an error)

```sql
SELECT l.symbol, s.name, l.ltp
FROM live_data l JOIN securities s ON s.symbol = l.symbol
LATEST ON timestamp PARTITION BY symbol;
```

Result:

Error: `LATEST ON works on a single table (no joins)`

**Example: The fix: LATEST ON in a subquery, then the join** (sample data: sample)

```sql
SELECT l.symbol, s.name, l.ltp, l.pct_change
FROM (SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol) l
JOIN securities s ON s.symbol = l.symbol
ORDER BY l.pct_change DESC;
```

Result:

| symbol (SYMBOL) | name (STRING) | ltp (DOUBLE) | pct_change (DOUBLE) |
|---|---|---|---|
| CITY | City Bank Limited | 527.1 | 2.71 |
| TELCO | Northwind Telecom Limited | 897.7 | 1.9 |
| COAST | Coastal Bank Limited | 401.9 | 0.7 |
| VOLT | Volt River Hydropower Limited | 184 | -0.86 |

(4 rows)

**Example: QuestDB's LATEST BY: the same as LATEST ON the time column** (sample data: sample)

```sql
SELECT symbol, ltp FROM live_data LATEST BY symbol ORDER BY symbol;
SELECT symbol, ltp FROM live_data LATEST ON timestamp PARTITION BY symbol ORDER BY symbol;
```

Result:

`SELECT symbol, ltp FROM live_data LATEST BY symbol ORDER BY symbol`

| symbol (SYMBOL) | ltp (DOUBLE) |
|---|---|
| CITY | 527.1 |
| COAST | 401.9 |
| TELCO | 897.7 |
| VOLT | 184 |

(4 rows)

`SELECT symbol, ltp FROM live_data LATEST ON timestamp PARTITION BY symbol ORDER BY symbol`

| symbol (SYMBOL) | ltp (DOUBLE) |
|---|---|
| CITY | 527.1 |
| COAST | 401.9 |
| TELCO | 897.7 |
| VOLT | 184 |

(4 rows)

**Example: LATEST BY needs a time-series table** (sample data: sample; shows an error)

```sql
SELECT id FROM brokers LATEST BY id;
```

Result:

Error: `LATEST BY needs a table with a time column (a TIMESERIES table); for other tables write LATEST ON <time column> PARTITION BY ...`
