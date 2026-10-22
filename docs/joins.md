# Joins

> Put rows of two or more tables side by side: JOIN, LEFT / RIGHT / FULL JOIN, USING, CROSS JOIN, and ASOF / LT / SPLICE JOIN for time series.

- Category: Querying
- Keywords: join, JOIN, hash join, join speed, key lookup, index lookup, index nested loop join, KDB_NO_COLUMN_JOIN, engine: column (hash join), GROUP BY over a join, join another database, INNER JOIN, INNER, ON, LEFT JOIN, LEFT OUTER JOIN, LEFT, OUTER, CROSS JOIN, CROSS, ASOF JOIN, ASOF, as of, time join, table alias, self join, join subquery, RIGHT JOIN, RIGHT OUTER JOIN, FULL JOIN, FULL OUTER JOIN, USING, JOIN USING, LT JOIN, SPLICE JOIN, RIGHT, FULL, LT, SPLICE, comma join, ambiguous column, join, left join, asof, cross join
- See also: [SELECT (from)](select.md#from), [WHERE](where.md), [GROUP BY and HAVING](group-by.md), [UNION and subqueries (correlated)](union-subqueries.md#correlated), [LATEST ON](latest-on.md), [EXPLAIN](explain.md)

A **join** puts rows of two tables side by side. For example, a trade in `trade_log` has only the broker number (`buyer = 58`); a join with `brokers` adds the broker's name.

`ON` says which rows belong together. Give each table a short name (an **alias**) and write `alias.column` for the columns.

| Join | Rows you get |
|---|---|
| `JOIN` (or `INNER JOIN`) | only the rows that have a match on both sides |
| `LEFT JOIN` (or `LEFT OUTER JOIN`) | every row of the left table; `NULL` columns when the right side has no match |
| `RIGHT JOIN` (or `RIGHT OUTER JOIN`) | every row of the right table; `NULL` columns when the left side has no match |
| `FULL JOIN` (or `FULL OUTER JOIN`) | every row of both tables, side by side where they match |
| `CROSS JOIN` | every left row with every right row |
| `ASOF JOIN` | for each left row, the last right row at or before its time |
| `LT JOIN` | for each left row, the last right row strictly before its time |
| `SPLICE JOIN` | every row of both time-series tables in time order, each with the other table's last row so far |

**Example: The 5 biggest trades of the day, with the buyer's and the seller's names** (sample data: sample)

```sql
SELECT f.transaction_id, f.symbol, b.name AS buyer, s.name AS seller, f.quantity, f.rate, f.amount
FROM trade_log f
JOIN brokers b ON f.buyer = b.id
JOIN brokers s ON f.seller = s.id
WHERE f.date IN '2026-09-10'
ORDER BY f.amount DESC
LIMIT 5;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | buyer (STRING) | seller (STRING) | quantity (LONG) | rate (DOUBLE) | amount (DOUBLE) |
|---|---|---|---|---|---|---|
| 100017 | TELCO | Online Securities | Vision Securities | 500 | 881 | 440500 |
| 100031 | COAST | Imperial Securities | Northgate Securities | 1000 | 402 | 402000 |
| 100015 | COAST | Online Securities | Imperial Securities | 1000 | 398 | 398000 |
| 100018 | CITY | Imperial Securities | Keystone Securities | 500 | 516 | 258000 |
| 100023 | COAST | Northgate Securities | Keystone Securities | 500 | 399 | 199500 |

(5 rows)

<a id="join"></a>

## JOIN, INNER JOIN

Syntax:

```sql
FROM left_table [[AS] alias]
[INNER] JOIN right_table [[AS] alias] { ON condition | USING (column, ...) }
[[INNER] JOIN ... ON ...] ...
```

For each row of the left side, KDB finds the rows of the right table where the `ON` condition is true, and gives one output row for each match. A row with no match is left out.

| Part | Meaning |
|---|---|
| `right_table` | a table, a [view](views.md), `(SELECT ...) alias`, or a table of another database: `otherdb.table` (see [queries across databases](cross-database-queries.md)) |
| `ON condition` | which rows match; usually `a.key = b.key`, and more conditions with `AND` |

- **Returns:** one row per matching pair. The columns of all tables can be used in the select list, `WHERE`, `GROUP BY` and `ORDER BY`.
- **NULL:** a `NULL` key never matches anything (not even another `NULL`).
- **Notes:** `ON` (or [`USING`](#using)) is required. The `a = b` parts of `ON` are used to find matches fast (a hash join); a join without any `=` between the two tables checks every pair (slow for big tables).
- A join on **one** `=` between number columns (ids, `DATE` or `TIMESTAMP` values) is the fastest kind: the numbers themselves are the keys of the hash join. Joining on a text column, or on two `=`, works the same way but makes a text key for every row.
- The first table in `FROM` is read with its time and symbol filters. A **joined** table is either looked up by key for each left row, or read completely into memory (see [join speed](#join-speed)). Put the big time-series table first and join small tables to it.
- The comma form `FROM a, b` is a `CROSS JOIN`; an `a.x = b.x` in `WHERE` makes it a hash join. `JOIN ... ON` says the same more clearly.
- A `RIGHT`, `FULL` or `SPLICE JOIN` after a comma is refused: PostgreSQL reads `FROM a, b RIGHT JOIN c` as `a, (b RIGHT JOIN c)`, and joining left to right would give other rows. Write `CROSS JOIN` for the comma (left to right), or put the joins after the comma in a subquery.
- At most 63 tables in one query.

**Example: Security names with the close price of the day** (sample data: sample)

```sql
SELECT s.symbol, s.name, s.sector, d.close
FROM ochl_day d
JOIN securities s ON s.symbol = d.symbol
WHERE d.time IN '2026-09-10'
ORDER BY s.symbol;
```

Result:

| symbol (SYMBOL) | name (STRING) | sector (STRING) | close (DOUBLE) |
|---|---|---|---|
| CITY | City Bank Limited | Banking | 504.9 |
| COAST | Coastal Bank Limited | Banking | 376.1 |
| VOLT | Volt River Hydropower Limited | Energy | 191.2 |

(3 rows)

**Example: Turnover by sector** (sample data: sample)

```sql
SELECT s.sector, count(*) AS trades, sum(f.quantity) AS shares, sum(f.amount) AS turnover
FROM trade_log f
JOIN securities s ON f.symbol = s.symbol
WHERE f.date IN '2026-09-10'
GROUP BY s.sector
ORDER BY turnover DESC;
```

Result:

| sector (STRING) | trades (LONG) | shares (LONG) | turnover (DOUBLE) |
|---|---|---|---|
| Banking | 16 | 3760 | 1609170 |
| Telecom | 4 | 770 | 678260 |
| Energy | 4 | 400 | 73950 |

(3 rows)

**Example: Accounting: totals per account type (a small trial balance)** (sample data: query-app)

```sql
SELECT a.type, sum(l.debit) AS debit, sum(l.credit) AS credit
FROM ledger l
JOIN accounts a ON a.code = l.account
GROUP BY a.type
ORDER BY a.type;
```

Result:

| type (STRING) | debit (DECIMAL(2)) | credit (DECIMAL(2)) |
|---|---|---|
| asset | 806350.00 | 323830.00 |
| equity | NULL | 500000.00 |
| expense | 26030.00 | NULL |
| income | NULL | 8550.00 |
| liability | 257500.00 | 257500.00 |

(5 rows)

**Example: Forum posts with the author's app plan** (sample data: query-app, content-forum)

```sql
SELECT p.id, p.author, u.plan, u.city, p.body
FROM posts p
INNER JOIN app_users u ON u.username = p.author
WHERE p.thread_id = 1
ORDER BY p.id;
```

Result:

| id (LONG) | author (STRING) | plan (STRING) | city (STRING) | body (STRING) |
|---|---|---|---|---|
| 1 | ram | pro | Kathmandu | CITY dividend looks good this year. |
| 2 | sita | free | Pokhara | I agree, the profit grew 18%. |
| 4 | gita | pro | Dharan | What about the bonus shares? |
| 5 | ram | pro | Kathmandu | Bonus is 10% this time. |
| 6 | sita | free | Pokhara | सिटी बैंकको नाफा राम्रो छ। |

(5 rows)

**Example: ON is required** (sample data: sample; shows an error)

```sql
SELECT * FROM trade_log f JOIN brokers b;
```

Result:

Error: `line 1, column 41: expected ON or USING (columns) and a join condition after the joined table but found ';'`

<a id="join-speed"></a>

### Join speed: key lookup or hash

KDB picks one of two ways to find the rows of a joined table (`JOIN` and `LEFT JOIN`):

| Way | When | Cost |
|---|---|---|
| **key lookup** | The `a = b` parts of `ON` give the first columns of the joined table's key: its `PRIMARY KEY`, or for a time-series table its `SORT BY` / `DEDUP KEY` columns including the time column. Or they give the first column of an [index](indexes.md) of the joined table. | Each left row reads only its own rows. A login row joined to its user among 100,000 users reads one user. |
| **hash** | Any other `ON`, or a left side with many rows (more than about a quarter of the joined table) | The joined table is read once (only the columns the query uses), then every left row is matched in it. Its rows are not copied: the hash points at them where they already are in memory, and a row is built only when a left row matches it. |

- `EXPLAIN` shows the choice: `join (key lookup on id) table users`, `join (index lookup on email) table users` or `join (hash on 1 key(s)) table users`.
- When KDB cannot tell in advance how many left rows there are (a `WHERE` on a column without an index), it starts with lookups and switches to the hash once they cost more.
- A key of type `DOUBLE` or `DECIMAL` is always joined with the hash.
- A `GROUP BY` over joined rows keeps no copy of the joined tables' rows either, and `ORDER BY ... LIMIT n` keeps only the best n rows while it groups. A report that joins 20,000 users to their accounts and transfers and shows the top 20 runs about twice as fast as before (2026-10-02).

**Example: Each trade looks up its buyer by the brokers' PRIMARY KEY** (sample data: sample)

```sql
EXPLAIN SELECT f.transaction_id, b.name
FROM trade_log f
JOIN brokers b ON b.id = f.buyer
WHERE f.date IN '2026-09-10';
```

Result:

| plan (STRING) |
|---|
| scan table trade_log (1 of 2 partitions, about 32 rows) |
| join (key lookup on id) table brokers (1 of 1 partitions, about 5 rows) |
| build 3 of 7 stored column(s) per row: date, transaction_id, buyer |
| filter while scanning: 1 condition(s) |
| engine: row (a join) |

(5 rows)

<a id="join-column-engine"></a>

### GROUP BY over a join: the column engine

Since 2026-10-02 a `GROUP BY` (or a plain `count(*)`, `sum`, ...) over **two** tables joined on **one** pair of columns runs on the column engine: the joined table is read once into a hash, the first table is read column by column on all threads, and no joined row is ever made. On 400,000 rows joined to 40,000 that is about 10 times faster than the row engine.

It is used when all of these hold:

| What | Allowed |
|---|---|
| Tables | two stored tables (not a subquery or view), `JOIN` or `LEFT JOIN` |
| `ON` | one `a.x = b.y` of whole-number columns (`BYTE` .. `LONG`) or of text columns (`SYMBOL`, `STRING`), plus conditions on the joined table alone |
| `WHERE` | conditions the column engine does (see [WHERE: fast conditions](where.md#fast-conditions)) on either table; with `LEFT JOIN`, on the first table only |
| `GROUP BY` | up to 4 plain columns of either table; no `SAMPLE BY` |
| Aggregates | `count(*)`, `count(col)`, `sum`, `avg`, `min`, `max` of plain columns (`sum`/`avg` of numbers, `min`/`max` also of times and dates) |
| Elsewhere | the `SELECT` list, `HAVING` and `ORDER BY` read only the group columns and the aggregates |

- `EXPLAIN` then ends with `engine: column (hash join)`; otherwise `engine: row (...)` says why not.
- A first table with a filter, joined to a big table (over 65,536 rows) that it can look up by key or index, stays on the row engine: a few lookups are cheaper than reading the whole joined table.
- The answers are the same on both engines, in the same order. `KDB_NO_COLUMN_JOIN=1` sends every join back to the row engine, for comparing.

<a id="left-join"></a>

## LEFT JOIN, LEFT OUTER JOIN

Syntax:

```sql
FROM left_table [[AS] alias]
LEFT [OUTER] JOIN right_table [[AS] alias] ON condition
```

Like `JOIN`, but **every row of the left table stays**. When the right table has no matching row, its columns are `NULL`. `OUTER` is an optional word.

- **Returns:** at least one row for each left row.
- **NULL:** the right side's columns are `NULL` for left rows without a match. `count(right.column)` counts them as 0.
- **Notes:** a condition on the right table belongs in `ON` when you want to keep the left rows. In `WHERE` it removes the rows where the right side is `NULL`, so the `LEFT JOIN` acts like a plain `JOIN` (see the two examples below).
- To keep the rows of the right table instead, use [RIGHT JOIN](#right-join); for both, [FULL JOIN](#full-join).

**Example: Every security, also the ones without trades** (sample data: sample)

```sql
SELECT s.symbol, count(f.transaction_id) AS trades
FROM securities s
LEFT JOIN trade_log f ON f.symbol = s.symbol
GROUP BY s.symbol
ORDER BY trades DESC, s.symbol;
```

Result:

| symbol (SYMBOL) | trades (LONG) |
|---|---|
| CITY | 11 |
| COAST | 11 |
| TELCO | 6 |
| VOLT | 4 |
| ACME | 0 |

(5 rows)

**Example: The day's close for every security: the condition on the day is in ON** (sample data: sample)

```sql
SELECT s.symbol, d.close
FROM securities s
LEFT JOIN ochl_day d ON d.symbol = s.symbol AND d.time IN '2026-09-10'
ORDER BY s.symbol;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) |
|---|---|
| ACME | NULL |
| CITY | 504.9 |
| COAST | 376.1 |
| TELCO | NULL |
| VOLT | 191.2 |

(5 rows)

**Example: The same condition in WHERE removes ACME and TELCO** (sample data: sample)

```sql
SELECT s.symbol, d.close
FROM securities s
LEFT JOIN ochl_day d ON d.symbol = s.symbol
WHERE d.time IN '2026-09-10'
ORDER BY s.symbol;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) |
|---|---|
| CITY | 504.9 |
| COAST | 376.1 |
| VOLT | 191.2 |

(3 rows)

**Example: App users and how many forum posts they wrote** (sample data: query-app, content-forum)

```sql
SELECT u.username, count(p.id) AS posts, max(p.created_at) AS last_post
FROM app_users u
LEFT OUTER JOIN posts p ON p.author = u.username
GROUP BY u.username
ORDER BY posts DESC, u.username;
```

Result:

| username (STRING) | posts (LONG) | last_post (TIMESTAMP) |
|---|---|---|
| gita | 2 | 2026-09-02T03:25:00.000Z |
| ram | 2 | 2026-09-01T05:45:00.000Z |
| sita | 2 | 2026-09-01T06:15:00.000Z |
| anita | 0 | NULL |
| bikash | 0 | NULL |
| hari_99 | 0 | NULL |
| suman | 0 | NULL |
| test_user | 0 | NULL |

(8 rows)

**Example: Find what is missing: brokers who sold nothing on 2026-09-09** (sample data: sample)

```sql
SELECT b.id, b.name
FROM brokers b
LEFT JOIN trade_log f ON f.seller = b.id AND f.date IN '2026-09-09'
WHERE f.transaction_id IS NULL;
```

Result:

| id (INT) | name (STRING) |
|---|---|
| 58 | Northgate Securities |

(1 row)

<a id="right-join"></a>

## RIGHT JOIN, RIGHT OUTER JOIN

Syntax:

```sql
FROM left_table [[AS] alias]
RIGHT [OUTER] JOIN right_table [[AS] alias] { ON condition | USING (column, ...) }
```

The mirror of `LEFT JOIN`: **every row of the right table stays**. When no left row matches it, the left side's columns are `NULL`. It is the same as swapping the two tables in a `LEFT JOIN`, but keeps the column order you wrote.

- **Returns:** at least one row for each right row.
- **NULL:** a right row whose key is `NULL` matches nothing and still comes out, with `NULL` on the left.
- **Notes:** `WHERE` is checked after the join, on the added rows too: `WHERE left.col IS NULL` finds the right rows without a match.
- The right table is read into memory (a hash join), as for `LEFT JOIN` with the hash. The rows that no left row matched come after the others, unless you `ORDER BY`.

**Example: Every security, also the ones nobody traded on 2026-09-10** (sample data: sample)

```sql
SELECT s.symbol, count(f.transaction_id) AS trades
FROM (SELECT * FROM trade_log WHERE date IN '2026-09-10') f
RIGHT JOIN securities s ON f.symbol = s.symbol
GROUP BY s.symbol
ORDER BY s.symbol;
```

Result:

| symbol (SYMBOL) | trades (LONG) |
|---|---|
| ACME | 0 |
| CITY | 7 |
| COAST | 9 |
| TELCO | 4 |
| VOLT | 4 |

(5 rows)

**Example: Only the right rows without a match** (sample data: sample)

```sql
SELECT s.symbol
FROM ochl_minutes m
RIGHT JOIN securities s ON m.symbol = s.symbol
WHERE m.symbol IS NULL
ORDER BY s.symbol;
```

Result:

| symbol (SYMBOL) |
|---|
| ACME |
| TELCO |
| VOLT |

(3 rows)

<a id="full-join"></a>

## FULL JOIN, FULL OUTER JOIN

Syntax:

```sql
FROM left_table [[AS] alias]
FULL [OUTER] JOIN right_table [[AS] alias] { ON condition | USING (column, ...) }
```

Every row of **both** tables: the pairs that match side by side, then the left rows without a match (right side `NULL`) and the right rows without a match (left side `NULL`). Use it to compare two lists.

- **Returns:** at least max(left rows, right rows) rows.
- **Notes:** with `USING (id)`, the one `id` column holds whichever side's value is there (see [USING](#using)).

**Example: Symbols with live prices, symbols that are not banks, or both** (sample data: sample)

```sql
SELECT l.symbol AS live, s.symbol AS not_a_bank
FROM (SELECT DISTINCT symbol FROM live_data) l
FULL JOIN (SELECT symbol FROM securities WHERE sector <> 'Banking') s ON l.symbol = s.symbol
ORDER BY coalesce(l.symbol, s.symbol);
```

Result:

| live (SYMBOL) | not_a_bank (SYMBOL) |
|---|---|
| NULL | ACME |
| CITY | NULL |
| COAST | NULL |
| TELCO | TELCO |
| VOLT | VOLT |

(5 rows)

**Example: FULL JOIN after a comma is refused** (sample data: sample; shows an error)

```sql
SELECT count(*) FROM brokers b, securities s FULL JOIN live_data l ON l.symbol = s.symbol;
```

Result:

Error: `line 1, column 46: FULL JOIN after a comma join is ambiguous: PostgreSQL joins it before the comma, KDB after. Write CROSS JOIN instead of the comma to join left to right, or put the joins after the comma in a subquery: FROM a, (SELECT ... FROM b RIGHT JOIN c ON ...) s`

<a id="using"></a>

## USING

Syntax:

```sql
JOIN right_table [[AS] alias] USING (column, ...)
```

`USING (id)` is `ON left.id = right.id` for columns that have the same name in both tables (PostgreSQL). It works with `JOIN`, `LEFT JOIN`, `RIGHT JOIN` and `FULL JOIN`.

| What you write | Means |
|---|---|
| `SELECT *` | each `USING` column **once**, first, then the other columns of each table |
| `id` (no table name) | the joined `id`: the left one for `JOIN` and `LEFT JOIN`, the right one for `RIGHT JOIN`, `coalesce(left.id, right.id)` for `FULL JOIN` |
| `a.id`, `b.id` | each table's own column, as always; `a.*` still shows all of `a` |

- **Notes:** the column must be in the right table and in exactly one table on the left; otherwise write `ON a.col = b.col`.

**Example: The day's candle for each security, joined on the column both tables have** (sample data: sample)

```sql
SELECT * FROM securities JOIN (SELECT symbol, close FROM ochl_day WHERE time IN '2026-09-10') d USING (symbol)
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | name (STRING) | sector (STRING) | close (DOUBLE) |
|---|---|---|---|
| CITY | City Bank Limited | Banking | 504.9 |
| COAST | Coastal Bank Limited | Banking | 376.1 |
| VOLT | Volt River Hydropower Limited | Energy | 191.2 |

(3 rows)

**Example: A column that is not in both tables** (sample data: sample; shows an error)

```sql
SELECT * FROM securities s JOIN brokers b USING (symbol);
```

Result:

Error: `line 1, column 28: column 'symbol' in USING is not in the right table 'b'`

<a id="cross-join"></a>

## CROSS JOIN

Syntax:

```sql
FROM left_table [[AS] alias]
CROSS JOIN right_table [[AS] alias]
```

Every row of the left side with every row of the right table. There is no `ON`.

- **Returns:** (left rows) × (right rows) rows. 5 brokers × 5 securities = 25 rows.
- **Notes:** the result grows very fast. Filter with `WHERE`, and use it only with small tables.
- Useful to make a full grid (every broker with every symbol), or to compare every row with a few other rows.

**Example: How many pairs** (sample data: sample)

```sql
SELECT count(*) AS pairs FROM brokers b CROSS JOIN securities s;
```

Result:

| pairs (LONG) |
|---|
| 25 |

(1 row)

**Example: Broker buy and sell summary of the day** (sample data: sample)

```sql
SELECT b.id, b.name,
       sum(CASE WHEN f.buyer  = b.id THEN f.quantity ELSE 0 END) AS bought,
       sum(CASE WHEN f.seller = b.id THEN f.quantity ELSE 0 END) AS sold
FROM brokers b
CROSS JOIN trade_log f
WHERE f.date IN '2026-09-10'
GROUP BY b.id, b.name
ORDER BY bought DESC;
```

Result:

| id (INT) | name (STRING) | bought (LONG) | sold (LONG) |
|---|---|---|---|
| 49 | Online Securities | 1740 | 340 |
| 45 | Imperial Securities | 1560 | 1520 |
| 58 | Northgate Securities | 760 | 1270 |
| 1 | Keystone Securities | 570 | 1100 |
| 34 | Vision Securities | 300 | 700 |

(5 rows)

**Example: CROSS JOIN has no ON** (sample data: sample; shows an error)

```sql
SELECT b.name FROM brokers b CROSS JOIN securities s ON s.symbol = 'TELCO';
```

Result:

Error: `line 1, column 54: expected JOIN, LEFT JOIN, RIGHT JOIN, FULL JOIN, ASOF JOIN, LT JOIN, SPLICE JOIN, CROSS JOIN, WHERE, LATEST ON, SAMPLE BY, GROUP BY, UNION ALL, ORDER BY, LIMIT, ';' or the end of the input but found 'ON'`

<a id="asof-join"></a>

## ASOF JOIN

Syntax:

```sql
FROM left_table [[AS] alias]
ASOF JOIN right_table [[AS] alias] [ON condition]
```

A join by **time**. For each row of the left table, KDB takes the **last row of the right table whose time is at or before the left row's time**. With `ON`, the right row must also match the `ON` condition (usually the same symbol).

This answers questions like "what was the last candle when this live price came in?" or "what was the price when this trade happened?".

| Part | Meaning |
|---|---|
| `left_table` | a time-series table (its `TIMESERIES` column is the time) |
| `right_table` | a time-series table, or a subquery whose result has a time column |
| `ON a.symbol = b.symbol` | match only rows of the same symbol; other `AND` conditions are checked too |
| `ON (symbol)` | QuestDB's short form of the same: the listed columns are equal in both tables |

- **Returns:** one row for each left row. When no right row is early enough (or none matches `ON`), the right columns are `NULL`, like a `LEFT JOIN`.
- **Notes:** both sides must have a time column: a relational table gives the error `ASOF JOIN needs a time column in both tables`.
- "At or before" includes the same time. For strictly before, use [LT JOIN](#lt-join).
- Without `ON`, any row of the right table can match, whatever its symbol.
- QuestDB's `TOLERANCE` is not there yet.

**Example: Live prices with the last minute candle at or before each snapshot** (sample data: sample)

```sql
SELECT l.timestamp, l.symbol, l.ltp, m.time AS candle_time, m.close AS candle_close
FROM live_data l
ASOF JOIN ochl_minutes m ON l.symbol = m.symbol
WHERE l.symbol IN ('CITY', 'COAST')
ORDER BY l.symbol, l.timestamp;
```

Result:

| timestamp (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) | candle_time (TIMESTAMP) | candle_close (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T05:20:00.000Z | CITY | 513 | 2026-09-10T05:20:00.000Z | 504.6 |
| 2026-09-10T07:15:00.000Z | CITY | 515.6 | 2026-09-10T07:15:00.000Z | 502.3 |
| 2026-09-10T09:14:00.000Z | CITY | 527.1 | 2026-09-10T09:14:00.000Z | 504.9 |
| 2026-09-10T05:20:00.000Z | COAST | 390.6 | 2026-09-10T05:20:00.000Z | 380.9 |
| 2026-09-10T07:15:00.000Z | COAST | 391.4 | 2026-09-10T07:15:00.000Z | 377.8 |
| 2026-09-10T09:14:00.000Z | COAST | 401.9 | 2026-09-10T09:14:00.000Z | 376.1 |

(6 rows)

**Example: No match: there are no minute candles for TELCO, so the right side is NULL** (sample data: sample)

```sql
SELECT l.timestamp, l.symbol, l.ltp, m.time AS candle_time, m.close
FROM live_data l
ASOF JOIN ochl_minutes m ON l.symbol = m.symbol
WHERE l.symbol = 'TELCO';
```

Result:

| timestamp (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) | candle_time (TIMESTAMP) | close (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T05:20:00.000Z | TELCO | 860.5 | NULL | NULL |
| 2026-09-10T07:15:00.000Z | TELCO | 869 | NULL | NULL |
| 2026-09-10T09:14:00.000Z | TELCO | 897.7 | NULL | NULL |

(3 rows)

**Example: Trade rate compared with the day's close** (sample data: sample)

```sql
SELECT f.transaction_id, f.symbol, f.rate, d.close AS day_close, round(f.rate - d.close, 2) AS above_close
FROM trade_log f
ASOF JOIN ochl_day d ON f.symbol = d.symbol
WHERE f.date IN '2026-09-10' AND f.symbol = 'COAST'
ORDER BY f.transaction_id
LIMIT 4;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | rate (DOUBLE) | day_close (DOUBLE) | above_close (DOUBLE) |
|---|---|---|---|---|
| 100009 | COAST | 400 | 376.1 | 23.9 |
| 100013 | COAST | 398 | 376.1 | 21.9 |
| 100014 | COAST | 399.5 | 376.1 | 23.4 |
| 100015 | COAST | 398 | 376.1 | 21.9 |

(4 rows)

**Example: An extra ON condition: the last minute with more than 1400 shares** (sample data: sample)

```sql
SELECT l.timestamp, l.ltp, m.time AS big_minute, m.volume
FROM live_data l
ASOF JOIN ochl_minutes m ON l.symbol = m.symbol AND m.volume > 1400
WHERE l.symbol = 'CITY';
```

Result:

| timestamp (TIMESTAMP) | ltp (DOUBLE) | big_minute (TIMESTAMP) | volume (DOUBLE) |
|---|---|---|---|
| 2026-09-10T05:20:00.000Z | 513 | 2026-09-10T05:20:00.000Z | 1420 |
| 2026-09-10T07:15:00.000Z | 515.6 | 2026-09-10T07:10:00.000Z | 1440 |
| 2026-09-10T09:14:00.000Z | 527.1 | 2026-09-10T08:53:00.000Z | 1480 |

(3 rows)

**Example: Both tables need a time column** (sample data: sample; shows an error)

```sql
SELECT l.symbol, s.name FROM live_data l ASOF JOIN securities s ON l.symbol = s.symbol;
```

Result:

Error: `line 1, column 42: ASOF JOIN needs a time column in both tables (TIMESERIES tables)`

<a id="lt-join"></a>

## LT JOIN

Syntax:

```sql
FROM left_table [[AS] alias]
LT JOIN right_table [[AS] alias] [ON condition | ON (column, ...)]
```

Like `ASOF JOIN`, but the right row must be **strictly earlier** than the left row (QuestDB). A right row at the same time is skipped. Use it to pair a row with the one before it, for example each day's candle with the previous day's.

- **Returns:** one row for each left row; `NULL` right columns when no right row is earlier.
- **Notes:** the same rules as `ASOF JOIN`: both tables need a time column, and `ON` may add conditions besides the keys.

**Example: Each day's close with the close of the day before** (sample data: sample)

```sql
SELECT d.time, d.close, p.time AS prev_day, p.close AS prev_close
FROM ochl_day d
LT JOIN ochl_day p ON (symbol)
WHERE d.symbol = 'CITY' AND d.time >= '2026-09-06'
ORDER BY d.time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | prev_day (TIMESTAMP) | prev_close (DOUBLE) |
|---|---|---|---|
| 2026-09-06T00:00:00.000Z | 499 | 2026-09-03T00:00:00.000Z | 497.9 |
| 2026-09-07T00:00:00.000Z | 498.7 | 2026-09-06T00:00:00.000Z | 499 |
| 2026-09-08T00:00:00.000Z | 497.5 | 2026-09-07T00:00:00.000Z | 498.7 |
| 2026-09-09T00:00:00.000Z | 504.6 | 2026-09-08T00:00:00.000Z | 497.5 |
| 2026-09-10T00:00:00.000Z | 504.9 | 2026-09-09T00:00:00.000Z | 504.6 |

(5 rows)

<a id="splice-join"></a>

## SPLICE JOIN

Syntax:

```sql
FROM left_table [[AS] alias]
SPLICE JOIN right_table [[AS] alias] [ON a.key = b.key | ON (column, ...)]
```

A **full** time join (QuestDB): the rows of both tables are merged in time order. Each row comes out once, with the latest row of the other table so far (of the same key with `ON`). Rows of the two tables with the same time (and key) come out as one pair.

- **Returns:** at least as many rows as both tables together, minus the pairs of the same time. A row before any row of the other table has `NULL` on that side.
- **Notes:** `ON` takes only equal columns. `SPLICE JOIN` must be the first join of the query (joins after it are fine); both tables need a time column.
- The rows come out in time order. Rows of **one** table with the same time come in that table's order (for a table with `SORT BY (symbol, time)`, by symbol).
- With keys, every row of both tables is kept. QuestDB 9.4.3 pairs rows the same way for one key, but with several keys it drops some right rows and pairs some rows with an older row of their key; KDB keeps them all.

**Example: Live prices and a few minute candles on one time line (05:20 has both: one pair)** (sample data: sample)

```sql
SELECT l.timestamp, l.ltp, m.time AS candle, m.close
FROM (SELECT * FROM live_data WHERE symbol = 'CITY') l
SPLICE JOIN (SELECT * FROM ochl_minutes
             WHERE symbol = 'CITY' AND time >= '2026-09-10T05:17:00Z' AND time < '2026-09-10T05:23:00Z') m;
```

Result:

| timestamp (TIMESTAMP) | ltp (DOUBLE) | candle (TIMESTAMP) | close (DOUBLE) |
|---|---|---|---|
| NULL | NULL | 2026-09-10T05:17:00.000Z | 504.2 |
| NULL | NULL | 2026-09-10T05:18:00.000Z | 504.4 |
| NULL | NULL | 2026-09-10T05:19:00.000Z | 504.5 |
| 2026-09-10T05:20:00.000Z | 513 | 2026-09-10T05:20:00.000Z | 504.6 |
| 2026-09-10T05:20:00.000Z | 513 | 2026-09-10T05:21:00.000Z | 505.1 |
| 2026-09-10T05:20:00.000Z | 513 | 2026-09-10T05:22:00.000Z | 504.9 |
| 2026-09-10T07:15:00.000Z | 515.6 | 2026-09-10T05:22:00.000Z | 504.9 |
| 2026-09-10T09:14:00.000Z | 527.1 | 2026-09-10T05:22:00.000Z | 504.9 |

(8 rows)

<a id="aliases"></a>

## Table aliases

Syntax:

```sql
FROM table [AS] alias
JOIN table [AS] alias ON ...
alias.column
alias.*
```

An alias is a short name for a table in one query. After you give one, use it for the columns: `f.symbol`. `AS` is optional.

- **Notes:** when a column name is in more than one table (like `symbol` or `name`), you **must** write `alias.column`. Otherwise KDB says `column 'symbol' is in more than one table`.
- The same table can be joined twice with two aliases (`brokers b` and `brokers s` in the first example).
- The words `ASOF`, `CROSS`, `FULL`, `INNER`, `LATEST`, `LEFT`, `LT`, `RIGHT`, `SAMPLE`, `SPLICE`, `UNION`, `USING` and a few more cannot be an alias without `AS`, because they start the next part of the query.

**Example: One table joined twice, with AS and long aliases: who sold to whom** (sample data: sample)

```sql
SELECT f.transaction_id, buyer_broker.name AS buyer, seller_broker.name AS seller
FROM trade_log AS f
JOIN brokers AS buyer_broker ON buyer_broker.id = f.buyer
JOIN brokers AS seller_broker ON seller_broker.id = f.seller
WHERE seller_broker.name = 'Keystone Securities'
ORDER BY f.transaction_id
LIMIT 3;
```

Result:

| transaction_id (LONG) | buyer (STRING) | seller (STRING) |
|---|---|---|
| 100002 | Imperial Securities | Keystone Securities |
| 100013 | Northgate Securities | Keystone Securities |
| 100016 | Vision Securities | Keystone Securities |

(3 rows)

**Example: A column in two tables needs the alias** (sample data: sample; shows an error)

```sql
SELECT symbol, name FROM trade_log f JOIN securities s ON s.symbol = f.symbol;
```

Result:

Error: `line 1, column 8: column 'symbol' is in more than one table; write it as table.column`

<a id="join-subquery"></a>

## Joining a subquery

Syntax:

```sql
JOIN (SELECT ...) alias ON condition
LEFT JOIN (SELECT ...) alias ON condition
ASOF JOIN (SELECT ...) alias ON condition
```

The right side of a join can be the result of another query in `( )`. Give it an alias, so you can write `alias.column`. This is how you join a table with **totals** or with the **latest row** of something.

- **Notes:** the subquery runs once, before the join. To use columns of the tables before it, write `LATERAL (SELECT ...)` (see [correlated subqueries](union-subqueries.md#correlated)).
- A subquery in `FROM` (the left side) also works: see [FROM](select.md#from).

**Example: Each security with its latest live price** (sample data: sample)

```sql
SELECT s.symbol, s.name, l.ltp, l.pct_change
FROM securities s
LEFT JOIN (SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol) l
  ON l.symbol = s.symbol
ORDER BY s.symbol;
```

Result:

| symbol (SYMBOL) | name (STRING) | ltp (DOUBLE) | pct_change (DOUBLE) |
|---|---|---|---|
| ACME | Acme Investment Company | NULL | NULL |
| CITY | City Bank Limited | 527.1 | 2.71 |
| COAST | Coastal Bank Limited | 401.9 | 0.7 |
| TELCO | Northwind Telecom Limited | 897.7 | 1.9 |
| VOLT | Volt River Hydropower Limited | 184 | -0.86 |

(5 rows)

**Example: Each trade as a share of the symbol's total quantity of the day** (sample data: sample)

```sql
SELECT f.transaction_id, f.symbol, f.quantity, t.total,
       round(f.quantity * 100.0 / t.total, 1) AS pct_of_day
FROM trade_log f
JOIN (SELECT symbol, sum(quantity) AS total FROM trade_log WHERE date IN '2026-09-10' GROUP BY symbol) t
  ON t.symbol = f.symbol
WHERE f.date IN '2026-09-10' AND f.symbol = 'CITY'
ORDER BY pct_of_day DESC;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | quantity (LONG) | total (LONG) | pct_of_day (DOUBLE) |
|---|---|---|---|---|
| 100018 | CITY | 500 | 910 | 54.9 |
| 100029 | CITY | 200 | 910 | 22 |
| 100024 | CITY | 100 | 910 | 11 |
| 100010 | CITY | 50 | 910 | 5.5 |
| 100022 | CITY | 20 | 910 | 2.2 |
| 100027 | CITY | 20 | 910 | 2.2 |
| 100030 | CITY | 20 | 910 | 2.2 |

(7 rows)

**Example: Account balances with the account names** (sample data: query-app)

```sql
SELECT a.code, a.name, b.balance
FROM accounts a
JOIN (SELECT account, coalesce(sum(debit), 0) - coalesce(sum(credit), 0) AS balance
      FROM ledger GROUP BY account) b
  ON b.account = a.code
WHERE a.type = 'asset'
ORDER BY a.code;
```

Result:

| code (INT) | name (STRING) | balance (DECIMAL(2)) |
|---|---|---|
| 1000 | Cash | 5000.00 |
| 1100 | Bank - City | 230320.00 |
| 1200 | Shares at cost | 247200.00 |

(3 rows)

**Example: Without an alias it still works, but the columns have no name to use** (sample data: sample)

```sql
SELECT b.id, b.name, count(*) AS trades
FROM brokers b JOIN (SELECT buyer FROM trade_log) ON buyer = b.id
GROUP BY b.id, b.name
ORDER BY b.id;
```

Result:

| id (INT) | name (STRING) | trades (LONG) |
|---|---|---|
| 1 | Keystone Securities | 9 |
| 34 | Vision Securities | 5 |
| 45 | Imperial Securities | 6 |
| 49 | Online Securities | 6 |
| 58 | Northgate Securities | 6 |

(5 rows)
