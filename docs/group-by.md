# GROUP BY and HAVING

> Make one row per group (per symbol, per broker, per account) with totals like count, sum and max, and filter the groups with HAVING.

- Category: Querying
- Keywords: group, groups, spill, ROLLUP, CUBE, GROUPING SETS, GROUPING, grand total, rollup, cube, grouping sets, subtotals, temporary files, many groups, max\_groups, window with GROUP BY, GROUP BY, HAVING, aggregate, totals, subtotal, summary, report, implicit GROUP BY, group key, not grouped, count per, sum per, group by, having, implicit
- See also: [Aggregate functions](functions-aggregate.md), [SAMPLE BY](sample-by.md), [SELECT (distinct)](select.md#distinct), [ORDER BY, LIMIT, OFFSET](order-by-limit.md), [Window and series functions](functions-window.md), [Joins](joins.md)

`GROUP BY` puts the rows that have the same value (for example the same symbol) into one **group**, and gives **one output row per group**.
In the select list you use **aggregates** like `count(*)`, `sum(x)`, `avg(x)`, `min(x)` and `max(x)`: they make one value from all the rows of a group. The full list is in [aggregate functions](functions-aggregate.md).

`HAVING` keeps only some groups, like `WHERE` keeps only some rows.
For groups by time (candles per minute, day, week, month), use [SAMPLE BY](sample-by.md).

**Example: September 2026 summary per symbol** (sample data: sample)

```sql
SELECT symbol,
       count(*)             AS days,
       min(low)             AS lowest,
       max(high)            AS highest,
       round(avg(close), 2) AS avg_close,
       sum(volume)          AS total_volume
FROM ochl_day
WHERE time IN '2026-09'
GROUP BY symbol
ORDER BY total_volume DESC;
```

Result:

| symbol (SYMBOL) | days (LONG) | lowest (DOUBLE) | highest (DOUBLE) | avg_close (DOUBLE) | total_volume (DOUBLE) |
|---|---|---|---|---|---|
| COAST | 8 | 364.1 | 398.8 | 374.73 | 910270 |
| CITY | 8 | 494.1 | 512.4 | 500.18 | 876210 |
| VOLT | 8 | 167.3 | 192.1 | 179.3 | 713310 |

(3 rows)

<a id="group-by"></a>

## GROUP BY

Syntax:

```sql
SELECT key, ..., aggregate(...), ...
FROM ...
[WHERE condition]
GROUP BY expression, ...
[HAVING condition]
[ORDER BY ...]
```

Rows with equal values in **all** the `GROUP BY` expressions are one group. A key can be a column or an expression (`date_trunc('month', time)`, `upper(symbol)`).

| Part | Meaning |
|---|---|
| `expression, ...` | the group keys: one output row for each different combination |
| `aggregate(...)` | a value computed from all the rows of the group |

- **Returns:** one row per group. The order of the groups is not fixed: add `ORDER BY`.
- **NULL:** `NULL` key values make their own group. Aggregates skip `NULL` values (`count(*)` counts every row).
- **Notes:** a select **alias can be used in `GROUP BY`**: `GROUP BY month` groups by the column written as `date_trunc('month', time) AS month`. Writing the expression again does the same thing. An alias still cannot be used in `HAVING`.
- `GROUP BY 1` means the first column of the select list, as in PostgreSQL (`GROUP BY 1, 2`: the first two). It cannot point at an aggregate.
- `ORDER BY` after `GROUP BY` can use the output columns (names, aliases, positions) and expressions of them (`ORDER BY q / n`), but not other table columns and not new aggregates.
- A window function (`rank() OVER`, `lag(...) OVER`, `sum(...) OVER ()`) can sit next to `GROUP BY`. It runs **after** the groups are made, over the grouped rows, as in PostgreSQL: its arguments and its `ORDER BY` use the group keys and aggregates, like `rank() OVER (ORDER BY sum(quantity) DESC)`. See [window functions](functions-window.md).
- With no matching rows, `GROUP BY` gives **0 rows**. Without `GROUP BY`, aggregates give **one row** (`count(*)` is `0`, `sum` is `NULL`).

**Example: Broker turnover as buyer on 2026-09-10** (sample data: sample)

```sql
SELECT f.buyer, b.name, count(*) AS trades, sum(f.amount) AS bought
FROM trade_log f
JOIN brokers b ON b.id = f.buyer
WHERE f.date IN '2026-09-10'
GROUP BY f.buyer, b.name
ORDER BY bought DESC;
```

Result:

| buyer (INT) | name (STRING) | trades (LONG) | bought (DOUBLE) |
|---|---|---|---|
| 49 | Online Securities | 5 | 960370 |
| 45 | Imperial Securities | 5 | 695950 |
| 58 | Northgate Securities | 4 | 260190 |
| 1 | Keystone Securities | 7 | 239420 |
| 34 | Vision Securities | 3 | 205450 |

(5 rows)

**Example: Two keys: shares per broker per symbol** (sample data: sample)

```sql
SELECT buyer, symbol, sum(quantity) AS shares
FROM trade_log
WHERE date IN '2026-09-10' AND buyer IN (1, 58)
GROUP BY buyer, symbol
ORDER BY buyer, symbol;
```

Result:

| buyer (INT) | symbol (SYMBOL) | shares (LONG) |
|---|---|---|
| 1 | CITY | 170 |
| 1 | COAST | 200 |
| 1 | TELCO | 50 |
| 1 | VOLT | 150 |
| 58 | COAST | 560 |
| 58 | VOLT | 200 |

(6 rows)

**Example: An expression as the key: average close per month** (sample data: sample)

```sql
SELECT date_trunc('month', time) AS month, round(avg(close), 2) AS avg_close, count(*) AS days
FROM ochl_day
WHERE symbol = 'CITY'
GROUP BY date_trunc('month', time)
ORDER BY month;
```

Result:

| month (TIMESTAMP) | avg_close (DOUBLE) | days (LONG) |
|---|---|---|
| 2025-12-01T00:00:00.000Z | 540.9 | 4 |
| 2026-08-01T00:00:00.000Z | 508.49 | 7 |
| 2026-09-01T00:00:00.000Z | 500.18 | 8 |

(3 rows)

**Example: Accounting: debit, credit and balance per account** (sample data: query-app)

```sql
SELECT a.code, a.name,
       coalesce(sum(l.debit), 0)  AS debit,
       coalesce(sum(l.credit), 0) AS credit,
       coalesce(sum(l.debit), 0) - coalesce(sum(l.credit), 0) AS balance
FROM ledger l
JOIN accounts a ON a.code = l.account
GROUP BY a.code, a.name
ORDER BY a.code;
```

Result:

| code (INT) | name (STRING) | debit (DECIMAL(2)) | credit (DECIMAL(2)) | balance (DECIMAL(2)) |
|---|---|---|---|---|
| 1000 | Cash | 30000.00 | 25000.00 | 5000.00 |
| 1100 | Bank - City | 518850.00 | 288530.00 | 230320.00 |
| 1200 | Shares at cost | 257500.00 | 10300.00 | 247200.00 |
| 2000 | Broker payable | 257500.00 | 257500.00 | 0.00 |
| 3000 | Owner capital | 0 | 500000.00 | -500000.00 |
| 4000 | Dividend income | 0 | 6250.00 | -6250.00 |
| 4100 | Gain on sale | 0 | 2300.00 | -2300.00 |
| 5000 | Broker commission | 1030.00 | 0 | 1030.00 |
| 5100 | Office rent | 25000.00 | 0 | 25000.00 |

(9 rows)

**Example: App users per plan, with NULL cities counted apart** (sample data: query-app)

```sql
SELECT plan, count(*) AS users, count(city) AS with_city, min(created_at) AS first_signup
FROM app_users
GROUP BY plan
ORDER BY users DESC;
```

Result:

| plan (STRING) | users (LONG) | with_city (LONG) | first_signup (TIMESTAMP) |
|---|---|---|---|
| free | 4 | 2 | 2026-02-11T03:45:00.000Z |
| pro | 3 | 3 | 2026-01-05T04:15:00.000Z |
| admin | 1 | 1 | 2026-01-01T03:15:00.000Z |

(3 rows)

**Example: Posts per forum thread** (sample data: content-forum)

```sql
SELECT t.title, count(*) AS posts, max(p.created_at) AS last_post
FROM posts p
JOIN threads t ON t.id = p.thread_id
GROUP BY t.title
ORDER BY posts DESC;
```

Result:

| title (STRING) | posts (LONG) | last_post (TIMESTAMP) |
|---|---|---|
| Is CITY a good buy? | 6 | 2026-09-01T06:15:00.000Z |
| Hydropower IPOs this month | 2 | 2026-09-02T03:25:00.000Z |

(2 rows)

**Example: Sort by a calculation of the output columns: average trade size** (sample data: sample)

```sql
SELECT symbol, count(*) AS n, sum(quantity) AS q
FROM trade_log
GROUP BY symbol
ORDER BY q / n DESC;
```

Result:

| symbol (SYMBOL) | n (LONG) | q (LONG) |
|---|---|---|
| TELCO | 6 | 2770 |
| COAST | 11 | 3070 |
| CITY | 11 | 2420 |
| VOLT | 4 | 400 |

(4 rows)

**Example: No rows: GROUP BY gives nothing, a plain aggregate gives one row** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades FROM trade_log WHERE symbol = 'ACME' GROUP BY symbol;
SELECT count(*) AS trades, sum(quantity) AS shares FROM trade_log WHERE symbol = 'ACME';
```

Result:

`SELECT symbol, count(*) AS trades FROM trade_log WHERE symbol = 'ACME' GROUP BY symbol`

| symbol (SYMBOL) | trades (LONG) |
|---|---|

(0 rows)

`SELECT count(*) AS trades, sum(quantity) AS shares FROM trade_log WHERE symbol = 'ACME'`

| trades (LONG) | shares (STRING) |
|---|---|
| 0 | NULL |

(1 row)

**Example: An alias as the GROUP BY key** (sample data: sample)

```sql
SELECT date_trunc('month', time) AS month, count(*) AS candles FROM ochl_day GROUP BY month ORDER BY month;
```

Result:

| month (TIMESTAMP) | candles (LONG) |
|---|---|
| 2025-12-01T00:00:00.000Z | 12 |
| 2026-08-01T00:00:00.000Z | 21 |
| 2026-09-01T00:00:00.000Z | 24 |

(3 rows)

**Example: GROUP BY 1: the first column of the select list** (sample data: sample)

```sql
SELECT symbol, sum(quantity) AS shares FROM trade_log GROUP BY 1;
```

Result:

| symbol (SYMBOL) | shares (LONG) |
|---|---|
| CITY | 2420 |
| COAST | 3070 |
| TELCO | 2770 |
| VOLT | 400 |

(4 rows)

**Example: A window function over the groups: each symbol's share of all trades** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades,
       round(count(*) * 100.0 / sum(count(*)) OVER (), 1) AS pct
FROM trade_log
GROUP BY symbol
ORDER BY trades DESC;
```

Result:

| symbol (SYMBOL) | trades (LONG) | pct (DOUBLE) |
|---|---|---|
| CITY | 11 | 34.4 |
| COAST | 11 | 34.4 |
| TELCO | 6 | 18.8 |
| VOLT | 4 | 12.5 |

(4 rows)

**Example: Rank the groups: a window function over sum()** (sample data: sample)

```sql
SELECT symbol, sum(quantity) AS shares,
       rank() OVER (ORDER BY sum(quantity) DESC) AS place
FROM trade_log
GROUP BY symbol
ORDER BY place;
```

Result:

| symbol (SYMBOL) | shares (LONG) | place (LONG) |
|---|---|---|
| COAST | 3070 | 1 |
| TELCO | 2770 | 2 |
| CITY | 2420 | 3 |
| VOLT | 400 | 4 |

(4 rows)

**Example: Month after month: lag() of the monthly average** (sample data: sample)

```sql
SELECT date_trunc('month', time) AS month,
       round(avg(close), 2) AS avg_close,
       round(lag(avg(close)) OVER (ORDER BY date_trunc('month', time)), 2) AS previous_month
FROM ochl_day
WHERE symbol = 'CITY'
GROUP BY date_trunc('month', time)
ORDER BY month;
```

Result:

| month (TIMESTAMP) | avg_close (DOUBLE) | previous_month (DOUBLE) |
|---|---|---|
| 2025-12-01T00:00:00.000Z | 540.9 | NULL |
| 2026-08-01T00:00:00.000Z | 508.49 | 540.9 |
| 2026-09-01T00:00:00.000Z | 500.18 | 508.49 |

(3 rows)

<a id="grouping-sets"></a>

## ROLLUP, CUBE and GROUPING SETS

Syntax:

```sql
GROUP BY ROLLUP (a, b)
GROUP BY CUBE (a, b)
GROUP BY GROUPING SETS ((a, b), (a), ())
GROUP BY key, ROLLUP (a, b)
GROUPING(a [, b ...])
```

Subtotals and a grand total in one query, as in PostgreSQL. The query groups once for each **grouping set** and gives the rows of all of them together.

| Written | The grouping sets |
|---|---|
| `ROLLUP (a, b)` | `(a, b)`, `(a)`, `()`: the groups, a subtotal per `a`, the grand total |
| `CUBE (a, b)` | `(a, b)`, `(a)`, `(b)`, `()`: every combination |
| `GROUPING SETS ((a, b), (a), ())` | exactly the sets listed; `()` is the grand total |
| `key, ROLLUP (a, b)` | `key` is in every set: `(key, a, b)`, `(key, a)`, `(key)` |
| `ROLLUP (a, (b, c))` | `(b, c)` counts as one item: `(a, b, c)`, `(a)`, `()` |

- **Returns:** the rows of each set, one set after the other. A key that is **not in the row's set is `NULL`** there. Aggregates still use the real values of all the rows of the group.
- `GROUPING(a, b)` tells a subtotal `NULL` from a `NULL` in the data: one bit per argument, `1` when that key is not grouped in the row's set. The leftmost argument is the highest bit, so with `ROLLUP (a, b)` it is `0` for the groups, `1` for the subtotals and `3` for the grand total. Its arguments must be `GROUP BY` keys.
- `ORDER BY`, `LIMIT` and `DISTINCT` are for the whole result. `ORDER BY` may use a result column, an aggregate or `GROUPING(...)`.
- The grand total `()` always gives one row, even when no row matches.
- **Notes:** a key may be a column, an expression, an alias or a position (`ROLLUP (1)`). `CUBE` takes at most 12 items; a query may have at most 4096 sets.
- Not with `SAMPLE BY`, `LATEST ON`, `DISTINCT ON`, `SELECT *` or window functions (group in a subquery, and put the window outside).

**Example: Shares per symbol and buyer, a subtotal per symbol, and the grand total** (sample data: sample)

```sql
SELECT symbol, buyer, sum(quantity) AS shares, GROUPING(symbol, buyer) AS level
FROM trade_log
WHERE date IN '2026-09-10' AND buyer IN (1, 58)
GROUP BY ROLLUP (symbol, buyer)
ORDER BY level, symbol, buyer;
```

Result:

| symbol (SYMBOL) | buyer (INT) | shares (LONG) | level (LONG) |
|---|---|---|---|
| CITY | 1 | 170 | 0 |
| COAST | 1 | 200 | 0 |
| COAST | 58 | 560 | 0 |
| TELCO | 1 | 50 | 0 |
| VOLT | 1 | 150 | 0 |
| VOLT | 58 | 200 | 0 |
| CITY | NULL | 170 | 1 |
| COAST | NULL | 760 | 1 |
| TELCO | NULL | 50 | 1 |
| VOLT | NULL | 350 | 1 |
| NULL | NULL | 1330 | 3 |

(11 rows)

**Example: CUBE: totals per symbol, per buyer, and both** (sample data: sample)

```sql
SELECT symbol, buyer, count(*) AS trades
FROM trade_log
WHERE date IN '2026-09-10' AND buyer IN (1, 58) AND symbol IN ('CITY', 'VOLT')
GROUP BY CUBE (symbol, buyer)
ORDER BY GROUPING(symbol, buyer), symbol, buyer;
```

Result:

| symbol (SYMBOL) | buyer (INT) | trades (LONG) |
|---|---|---|
| CITY | 1 | 3 |
| VOLT | 1 | 2 |
| VOLT | 58 | 1 |
| CITY | NULL | 3 |
| VOLT | NULL | 3 |
| NULL | 1 | 5 |
| NULL | 58 | 1 |
| NULL | NULL | 6 |

(8 rows)

**Example: GROUPING SETS: a row per month, a row per symbol, and the grand total** (sample data: sample)

```sql
SELECT date_trunc('month', time) AS month, symbol, round(avg(close), 2) AS avg_close
FROM ochl_day
WHERE symbol IN ('CITY', 'VOLT')
GROUP BY GROUPING SETS ((month), (symbol), ())
ORDER BY month, symbol;
```

Result:

| month (TIMESTAMP) | symbol (SYMBOL) | avg_close (DOUBLE) |
|---|---|---|
| 2025-12-01T00:00:00.000Z | NULL | 367.29 |
| 2026-08-01T00:00:00.000Z | NULL | 342.06 |
| 2026-09-01T00:00:00.000Z | NULL | 339.74 |
| NULL | CITY | 511.81 |
| NULL | VOLT | 180.97 |
| NULL | NULL | 346.39 |

(6 rows)

**Example: GROUPING() names the total rows** (sample data: sample)

```sql
SELECT CASE WHEN GROUPING(symbol) = 1 THEN 'all symbols' ELSE symbol END AS symbol, sum(quantity) AS shares
FROM trade_log
WHERE date IN '2026-09-10'
GROUP BY ROLLUP (symbol)
ORDER BY GROUPING(symbol), shares DESC;
```

Result:

| symbol (SYMBOL) | shares (LONG) |
|---|---|
| COAST | 2850 |
| CITY | 910 |
| TELCO | 770 |
| VOLT | 400 |
| all symbols | 4930 |

(5 rows)

**Example: GROUPING() needs a GROUP BY key** (sample data: sample; shows an error)

```sql
SELECT symbol, GROUPING(buyer), count(*) FROM trade_log GROUP BY ROLLUP (symbol);
```

Result:

Error: `line 1, column 25: GROUPING(buyer): the argument must be one of the GROUP BY expressions`

<a id="big-group-by"></a>

## Big GROUP BY: many groups and memory

A `GROUP BY` can make millions of groups, for example one per day, symbol and broker. KDB keeps it fast and keeps the server safe.

| Situation | What happens |
|---|---|
| Up to 5 keys, each a `SYMBOL`, a whole number, a `DATE` or a `TIMESTAMP` (also `date_trunc` or `to_char` of a time) | The groups are added up a block of rows at a time, on all threads. 30 days of one row per symbol and broker (31,500 groups) take about 16 ms. Two keys that are each a `SYMBOL` or an `INT` (`GROUP BY symbol, buyer`) are kept as one number per group, which is 5-15% faster again. What else keeps a query on this fast path: [GROUP BY with many groups](performance-tips.md#many-groups). |
| A `STRING` or `DOUBLE` key, or 5 keys and more | The same result, but the rows are grouped one by one, which is slower. |
| The groups need more than **half of `--max-result-memory`** (1 GB by default), or more than `SET work_mem` | Row by row: the rows of the groups that do not fit yet are written to sorted temporary files in the database folder (`_tmp/`) and added up after the scan, one group at a time. On the fast path (since 2026-10-02): the groups themselves, with their totals so far, go to 64 temporary files chosen by the key, and each file is finished on its own after the scan; about twice the time of the same query in memory, instead of many times. **The result is the same, only slower** (a sum of `DOUBLE` values may differ in its last digit). The files are removed when the query ends. |
| The temporary files would pass **16 GB** for one query | The query stops: `the GROUP BY needs more than 16384 MB of temporary files (max_spill_bytes)`. |
| More than `--max-groups` groups (5,000,000 by default) | The query stops: `the query makes more than N groups (max_groups)`. |

- **Notes:** `SAMPLE BY` and a read-only database never write temporary files: they keep every group in memory, and only `--max-groups` stops them.
- `ORDER BY ... LIMIT` over hundreds of thousands of groups still turns every group into a row before the sort, so it is slower than the same query without `ORDER BY`.
- The limits are server settings: see [protection](protection.md) and [limits](limits.md).
- To make fewer groups: add a `WHERE` on time, group by fewer columns, or use a longer [SAMPLE BY](sample-by.md) interval.

<a id="implicit-group-by"></a>

## Implicit GROUP BY

Syntax:

```sql
SELECT key, ..., aggregate(...), ... FROM ... [WHERE ...]
```

Like QuestDB, KDB does not need the words `GROUP BY`. When the select list has an aggregate and there is no `GROUP BY`, **every select item that is not an aggregate becomes a group key**.

| Select list | Groups by |
|---|---|
| `symbol, max(high)` | `symbol` |
| `symbol, buyer, sum(quantity)` | `symbol, buyer` |
| `upper(symbol) AS s, count(*)` | `upper(symbol)` |
| `count(*), sum(volume)` | nothing: one row for all rows |
| `'orders' AS t, count(*)` | nothing: a fixed value is not a key, so there is one row even when no row matches (as in PostgreSQL) |
| `time, symbol, last(close) ... SAMPLE BY 1d` | `symbol` (the time column is the bucket) |

- **Returns:** the same as the query with `GROUP BY` of those items.
- **Notes:** in PostgreSQL this is an error. In KDB it is allowed, but **every extra column adds a key**: adding `close` to `SELECT symbol, count(*)` splits the groups by close price. Writing `GROUP BY` makes the query clearer for readers.

**Example: No GROUP BY: symbol is not an aggregate, so it is the key** (sample data: sample)

```sql
SELECT symbol, max(high) AS highest FROM ochl_day WHERE time IN '2026-09';
```

Result:

| symbol (SYMBOL) | highest (DOUBLE) |
|---|---|
| CITY | 512.4 |
| COAST | 398.8 |
| VOLT | 192.1 |

(3 rows)

**Example: The same with GROUP BY** (sample data: sample)

```sql
SELECT symbol, max(high) AS highest FROM ochl_day WHERE time IN '2026-09' GROUP BY symbol;
```

Result:

| symbol (SYMBOL) | highest (DOUBLE) |
|---|---|
| CITY | 512.4 |
| COAST | 398.8 |
| VOLT | 192.1 |

(3 rows)

**Example: Careful: one more column is one more key** (sample data: sample)

```sql
SELECT symbol, round(close / 10) AS price_band, count(*) AS days
FROM ochl_day
WHERE time IN '2026-09' AND symbol = 'COAST';
```

Result:

| symbol (SYMBOL) | price_band (DOUBLE) | days (LONG) |
|---|---|---|
| COAST | 37 | 3 |
| COAST | 38 | 5 |

(2 rows)

**Example: Only aggregates: one row for the whole table** (sample data: query-app)

```sql
SELECT count(*) AS lines, sum(debit) AS total_debit, sum(credit) AS total_credit FROM ledger;
```

Result:

| lines (LONG) | total_debit (DECIMAL(2)) | total_credit (DECIMAL(2)) |
|---|---|---|
| 17 | 1089880.00 | 1089880.00 |

(1 row)

<a id="having"></a>

## HAVING

Syntax:

```sql
SELECT ... FROM ... [WHERE ...] GROUP BY ... HAVING condition
```

`HAVING` keeps only the groups where the condition is true. It runs **after** the groups are made, so it can use aggregates. `WHERE` runs **before**, on single rows.

| | `WHERE` | `HAVING` |
|---|---|---|
| runs on | rows | groups |
| can use aggregates (`sum(x) > 10`) | no | yes |
| runs | before grouping | after grouping |

- **Returns:** only the groups where the condition is `true`.
- **NULL:** a condition that is `NULL` removes the group.
- **Notes:** a select **alias cannot be used in `HAVING`**: write `HAVING sum(amount) > 500000`, not `HAVING bought > 500000`.
- `HAVING` needs `GROUP BY` or an aggregate in the query. A key column can be used too: `HAVING symbol LIKE 'N%'` (but `WHERE` is faster for that).
- Put conditions on single rows in `WHERE`: fewer rows are grouped, and time conditions skip partitions.

**Example: Symbols with 800 shares or more on 2026-09-10** (sample data: sample)

```sql
SELECT symbol, sum(quantity) AS shares, count(*) AS trades
FROM trade_log
WHERE date IN '2026-09-10'
GROUP BY symbol
HAVING sum(quantity) >= 800
ORDER BY shares DESC;
```

Result:

| symbol (SYMBOL) | shares (LONG) | trades (LONG) |
|---|---|---|
| COAST | 2850 | 9 |
| CITY | 910 | 7 |

(2 rows)

**Example: Symbols that moved more than 20 dollars in September** (sample data: sample)

```sql
SELECT symbol, max(high) - min(low) AS price_range
FROM ochl_day
WHERE time IN '2026-09'
GROUP BY symbol
HAVING max(high) - min(low) > 20;
```

Result:

| symbol (SYMBOL) | price_range (DOUBLE) |
|---|---|
| COAST | 34.7 |
| VOLT | 24.8 |

(2 rows)

**Example: Journal entries that do not balance (none, in a correct book)** (sample data: query-app)

```sql
SELECT entry_id, sum(debit) AS debit, sum(credit) AS credit
FROM ledger
GROUP BY entry_id
HAVING sum(debit) != sum(credit);
```

Result:

| entry_id (INT) | debit (STRING) | credit (STRING) |
|---|---|---|

(0 rows)

**Example: Cities with two or more app users** (sample data: query-app)

```sql
SELECT city, count(*) AS users
FROM app_users
WHERE city IS NOT NULL
GROUP BY city
HAVING count(*) >= 2;
```

Result:

| city (STRING) | users (LONG) |
|---|---|
| Kathmandu | 2 |
| Pokhara | 2 |

(2 rows)

**Example: An alias cannot be used in HAVING** (sample data: sample; shows an error)

```sql
SELECT buyer, sum(amount) AS bought FROM trade_log GROUP BY buyer HAVING bought > 500000;
```

Result:

Error: `line 1, column 74: unknown column 'bought' (table 'trade_log' has: date transaction_id symbol buyer seller quantity rate amount)`

**Example: HAVING without groups or aggregates** (sample data: sample; shows an error)

```sql
SELECT symbol FROM trade_log HAVING symbol = 'TELCO';
```

Result:

Error: `line 1, column 44: HAVING needs GROUP BY or aggregates`

<a id="not-grouped"></a>

## Columns that are not grouped

Syntax:

```sql
SELECT key, other_column, aggregate(...) FROM ... GROUP BY key
```

In PostgreSQL, a column in the select list that is neither a `GROUP BY` key nor inside an aggregate is an error. **KDB gives no error.** It shows the value of **one row of the group** (the first row it read), which is usually not the value you want.

- **Notes:** do not use this. Put the column in `GROUP BY`, or use an aggregate that says which value you want: `first(x)`, `last(x)` (by time), `min(x)`, `max(x)`.
- Without `GROUP BY`, the same column becomes a key instead (see [implicit GROUP BY](group-by.md#implicit-group-by)).

**Example: time is not grouped: KDB shows the time of one row (2025-12-28), not of the highest price** (sample data: sample)

```sql
SELECT symbol, time, max(high) AS highest FROM ochl_day GROUP BY symbol;
```

Result:

| symbol (SYMBOL) | time (TIMESTAMP) | highest (DOUBLE) |
|---|---|---|
| CITY | 2025-12-28T00:00:00.000Z | 546.2 |
| COAST | 2025-12-28T00:00:00.000Z | 429.9 |
| VOLT | 2025-12-28T00:00:00.000Z | 199.7 |

(3 rows)

**Example: Say what you want: the first and the last day of each symbol** (sample data: sample)

```sql
SELECT symbol, min(time) AS first_day, max(time) AS last_day, max(high) AS highest
FROM ochl_day
GROUP BY symbol;
```

Result:

| symbol (SYMBOL) | first_day (TIMESTAMP) | last_day (TIMESTAMP) | highest (DOUBLE) |
|---|---|---|---|
| CITY | 2025-12-28T00:00:00.000Z | 2026-09-10T00:00:00.000Z | 546.2 |
| COAST | 2025-12-28T00:00:00.000Z | 2026-09-10T00:00:00.000Z | 429.9 |
| VOLT | 2025-12-28T00:00:00.000Z | 2026-09-10T00:00:00.000Z | 199.7 |

(3 rows)

**Example: The latest close of each symbol: last(close) uses the time order** (sample data: sample)

```sql
SELECT symbol, last(close) AS latest_close, first(close) AS first_close
FROM ochl_day
GROUP BY symbol;
```

Result:

| symbol (SYMBOL) | latest_close (DOUBLE) | first_close (DOUBLE) |
|---|---|---|
| CITY | 504.9 | 542.2 |
| COAST | 376.1 | 424.8 |
| VOLT | 191.2 | 191.7 |

(3 rows)
