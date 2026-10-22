# Prices adjusted for splits and bonus shares

> Read a price table as if every split and bonus share had always been there - a chart without the jump on the ex-date - while the table keeps the traded prices.

- Category: Time-series
- Keywords: ADJUSTED BY, adjusted prices, adjusted close, adjusted candles, adjust, split, stock split, bonus share, bonus shares, right share, corporate action, corporate actions, ex\_date, ex-date, factor, adjustment factor, back-adjusted, unadjusted, PRICES, VOLUMES, NEPSE
- See also: [Candles cookbook](candles-cookbook.md), [Trading calendars](calendars.md), [SELECT](select.md), [Views](views.md), [Joins](joins.md)

When a company gives a **bonus share** or **splits** its shares, the price falls on the **ex-date**: one old share became more shares, each worth less. A chart of the traded prices then shows a jump that was never a loss. An **adjusted** price divides every price before the ex-date by the same factor, so the history lines up with today's shares.

`ADJUSTED BY` reads a table that way. Nothing is written: the table keeps the prices as they were traded, and you choose per query which ones you want.

Syntax:

```sql
SELECT ... FROM table [alias] ADJUSTED BY actions [PRICES (column, ...)] [VOLUMES (column, ...)] ...
```

<a id="actions"></a>

## The table of corporate actions

One row per symbol and ex-date. It needs these three columns (other columns are allowed):

| Column | Type | Meaning |
|---|---|---|
| `symbol` | `STRING` or `SYMBOL` | the symbol, as in the price table's `symbol` column |
| `ex_date` | `TIMESTAMP` or `DATE` | the first day that trades with the new number of shares |
| `factor` | a number | how many shares one old share became: `2` for a 1:1 bonus or a 2-for-1 split, `1.1` for a 10% bonus |

**Example: A 10% bonus, then a 2-for-1 split**

```sql
CREATE TABLE corp_actions (symbol STRING, ex_date TIMESTAMP, factor DOUBLE, PRIMARY KEY (symbol, ex_date));
INSERT INTO corp_actions VALUES ('CITY', '2026-08-15', 1.1), ('CITY', '2026-09-10', 2);
SELECT * FROM corp_actions;
```

Result:

`CREATE TABLE corp_actions (`

```text
table 'corp_actions' created
```

`INSERT INTO corp_actions VALUES ('CITY', '2026-08-15', 1.1), ('CITY', '2026-09-10', 2)`

```text
2 row(s) inserted
```

`SELECT * FROM corp_actions`

| symbol (STRING) | ex_date (TIMESTAMP) | factor (DOUBLE) |
|---|---|---|
| CITY | 2026-08-15T00:00:00.000Z | 1.1 |
| CITY | 2026-09-10T00:00:00.000Z | 2 |

(2 rows)

<a id="rule"></a>

## How a row is adjusted

| Row | Prices | Volumes |
|---|---|---|
| before an ex-date of its symbol | divided by the product of the factors of **every later** ex-date | multiplied by that product |
| on or after the symbol's last ex-date | as stored | as stored |
| of a symbol with no actions | as stored | as stored |

So turnover (price x volume) stays the same, as it should: the money traded did not change.

**Example: Daily closes of CITY, as traded and adjusted**

```sql
CREATE TABLE corp_actions (symbol STRING, ex_date TIMESTAMP, factor DOUBLE, PRIMARY KEY (symbol, ex_date));
INSERT INTO corp_actions VALUES ('CITY', '2026-08-15', 1.1), ('CITY', '2026-09-10', 2);
CREATE TABLE day_bars (time TIMESTAMP, symbol SYMBOL, close DOUBLE, volume LONG) TIMESERIES(time) PARTITION BY MONTH;
INSERT INTO day_bars VALUES ('2026-08-14', 'CITY', 880, 100), ('2026-08-15', 'CITY', 800, 110),
                            ('2026-09-09', 'CITY', 820, 90), ('2026-09-10', 'CITY', 410, 200);
SELECT b.time, b.close AS traded, a.close AS adjusted, a.volume AS adjusted_volume
FROM day_bars b
JOIN (SELECT time, close, volume FROM day_bars ADJUSTED BY corp_actions WHERE symbol = 'CITY') a ON a.time = b.time
ORDER BY b.time;
```

Result:

`CREATE TABLE corp_actions (`

```text
table 'corp_actions' created
```

`INSERT INTO corp_actions VALUES ('CITY', '2026-08-15', 1.1), ('CITY', '2026-09-10', 2)`

```text
2 row(s) inserted
```

`CREATE TABLE day_bars (`

```text
table 'day_bars' created
```

`INSERT INTO day_bars VALUES ('2026-08-14', 'CITY', 880, 100), ('2026-08-15', 'CITY', 800, 110), ('20`

```text
4 row(s) inserted
```

`SELECT b.time, b.close AS traded, a.close AS adjusted, a.volume AS adjusted_volume FROM day_bars AS `

| time (TIMESTAMP) | traded (DOUBLE) | adjusted (DOUBLE) | adjusted_volume (LONG) |
|---|---|---|---|
| 2026-08-14T00:00:00.000Z | 880 | 400 | 220 |
| 2026-08-15T00:00:00.000Z | 800 | 400 | 220 |
| 2026-09-09T00:00:00.000Z | 820 | 410 | 180 |
| 2026-09-10T00:00:00.000Z | 410 | 410 | 200 |

(4 rows)

The 14 August close of 880 was before both ex-dates: 880 / (1.1 x 2) = 400. The 9 September close was only before the split: 820 / 2 = 410. From the split on, prices are as traded.

<a id="columns"></a>

## Which columns change

Without `PRICES (...)` and `VOLUMES (...)`, the columns are found by name:

| Kind | Column names |
|---|---|
| prices (divided) | `open`, `high`, `low`, `close`, `price`, `rate`, `vwap`, `ltp`, `prev_close`, `avg_price` |
| volumes (multiplied) | `volume`, `qty`, `quantity`, `shares` |

Every other column (the time, the symbol, turnover, counts) is as stored. Name the columns yourself when yours have other names; `()` changes none of that kind:

**Example: Only the close, volumes as traded**

```sql
CREATE TABLE corp_actions (symbol STRING, ex_date TIMESTAMP, factor DOUBLE, PRIMARY KEY (symbol, ex_date));
INSERT INTO corp_actions VALUES ('CITY', '2026-09-10', 2);
CREATE TABLE day_bars (time TIMESTAMP, symbol SYMBOL, close DOUBLE, volume LONG) TIMESERIES(time) PARTITION BY MONTH;
INSERT INTO day_bars VALUES ('2026-09-09', 'CITY', 820, 90), ('2026-09-10', 'CITY', 410, 200);
SELECT time, close, volume FROM day_bars ADJUSTED BY corp_actions PRICES (close) VOLUMES () ORDER BY time;
```

Result:

`CREATE TABLE corp_actions (`

```text
table 'corp_actions' created
```

`INSERT INTO corp_actions VALUES ('CITY', '2026-09-10', 2)`

```text
1 row(s) inserted
```

`CREATE TABLE day_bars (`

```text
table 'day_bars' created
```

`INSERT INTO day_bars VALUES ('2026-09-09', 'CITY', 820, 90), ('2026-09-10', 'CITY', 410, 200)`

```text
2 row(s) inserted
```

`SELECT time, close, volume FROM day_bars ADJUSTED BY corp_actions PRICES (close) VOLUMES () ORDER BY`

| time (TIMESTAMP) | close (DOUBLE) | volume (LONG) |
|---|---|---|
| 2026-09-09T00:00:00.000Z | 410 | 90 |
| 2026-09-10T00:00:00.000Z | 410 | 200 |

(2 rows)

A whole-number volume column stays a whole number (rounded): 10 shares before a 1.5 bonus are 15.

<a id="use"></a>

## Filters, candles and indicators

Everything after `FROM t ADJUSTED BY actions` sees the adjusted values: `WHERE close > 100`, `SAMPLE BY`, `GROUP BY`, `sma(close, 20) OVER (...)`. A condition on a column that is not adjusted (`symbol`, `time`) is also run before the adjustment, so `WHERE symbol = 'CITY'` reads one symbol's rows only.

**Example: Weekly adjusted candles**

```sql
CREATE TABLE corp_actions (symbol STRING, ex_date TIMESTAMP, factor DOUBLE, PRIMARY KEY (symbol, ex_date));
INSERT INTO corp_actions VALUES ('CITY', '2026-09-10', 2);
CREATE TABLE day_bars (time TIMESTAMP, symbol SYMBOL, close DOUBLE, volume LONG) TIMESERIES(time) PARTITION BY MONTH;
INSERT INTO day_bars VALUES ('2026-09-07', 'CITY', 800, 90), ('2026-09-08', 'CITY', 840, 90),
                            ('2026-09-09', 'CITY', 820, 90), ('2026-09-10', 'CITY', 410, 200), ('2026-09-11', 'CITY', 420, 150);
SELECT time, first(close) AS open, max(close) AS high, min(close) AS low, last(close) AS close, sum(volume) AS volume
FROM day_bars ADJUSTED BY corp_actions
WHERE symbol = 'CITY'
SAMPLE BY 7d ALIGN TO CALENDAR;
```

Result:

`CREATE TABLE corp_actions (`

```text
table 'corp_actions' created
```

`INSERT INTO corp_actions VALUES ('CITY', '2026-09-10', 2)`

```text
1 row(s) inserted
```

`CREATE TABLE day_bars (`

```text
table 'day_bars' created
```

`INSERT INTO day_bars VALUES ('2026-09-07', 'CITY', 800, 90), ('2026-09-08', 'CITY', 840, 90), ('2026`

```text
5 row(s) inserted
```

`SELECT time, first(close) AS open, max(close) AS high, min(close) AS low, last(close) AS close, sum(`

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (LONG) |
|---|---|---|---|---|---|
| 2026-09-03T00:00:00.000Z | 400 | 420 | 400 | 410 | 540 |
| 2026-09-10T00:00:00.000Z | 410 | 420 | 410 | 420 | 350 |

(2 rows)

- **Speed:** the adjusted rows are worked out for each query; filter by symbol and time when the table is big.
- **Views:** `CREATE VIEW adjusted_days AS SELECT ... FROM day_bars ADJUSTED BY corp_actions` keeps the adjusted reading under a name.
- **Rights:** the query reads both tables, so it needs the right to read both.

<a id="errors"></a>

## Errors

| Message | Why |
|---|---|
| `table '...' needs the columns symbol, ex_date and factor` | the actions table has other column names |
| `table '...' has no time column` | the price table needs `TIMESERIES(time)` (or `TIMESTAMP(col)`) to know which rows come first |
| `has no column symbol` | the price table needs a `symbol` column to match the actions by |
| `ADJUSTED BY works on a table of this database` | not on a subquery, a function, a view, `AS OF` or another database's table |
