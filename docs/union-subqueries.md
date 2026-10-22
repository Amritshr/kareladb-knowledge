# UNION and subqueries

> Put the rows of two queries together, and use one query inside another.

- Category: Querying
- Keywords: UNION, UNION ALL, ALL, subquery, sub-query, nested query, inner query, EXISTS, NOT EXISTS, IN (SELECT), NOT IN (SELECT), scalar subquery, derived table, correlated subquery, INTERSECT, EXCEPT, UNION DISTINCT, combine results
- See also: [SELECT (from)](select.md#from), [WHERE (in-list)](where.md#in-list), [Joins (join)](joins.md#join), [Joins (left-join)](joins.md#left-join), [GROUP BY and HAVING (group-by)](group-by.md#group-by), [ORDER BY, LIMIT, OFFSET (order-by)](order-by-limit.md#order-by), [Views](views.md)

A **subquery** is a `SELECT` inside another statement, always in `( )`. `UNION ALL` puts the rows of two or more `SELECT`s one after the other.

- A subquery that uses no column of the outer query runs **once**, before the outer query. Then KDB uses the result like a fixed value, a fixed list or a small table.
- A subquery **may use columns of the outer query** (a "correlated" subquery): see [Correlated subqueries](union-subqueries.md#correlated).
- Subqueries work in `SELECT`, `INSERT`, `UPDATE` and `DELETE` (also inside `CREATE VIEW` and `EXPLAIN`).
- Subqueries and views can be nested at most 16 levels deep.

**Example: Brokers who bought or sold TELCO: a subquery with UNION ALL inside** (sample data: sample)

```sql
SELECT id, name
FROM brokers
WHERE id IN (SELECT buyer FROM trade_log WHERE symbol = 'TELCO'
             UNION ALL
             SELECT seller FROM trade_log WHERE symbol = 'TELCO')
ORDER BY name;
```

Result:

| id (INT) | name (STRING) |
|---|---|
| 45 | Imperial Securities |
| 1 | Keystone Securities |
| 58 | Northgate Securities |
| 49 | Online Securities |
| 34 | Vision Securities |

(5 rows)

<a id="union-all"></a>

## UNION ALL

Syntax:

```sql
SELECT ... [FROM ... WHERE ... GROUP BY ...]
UNION ALL
SELECT ... [FROM ... WHERE ... GROUP BY ...]
[UNION ALL SELECT ...] ...
[ORDER BY result_column | position [ASC | DESC], ...]
[LIMIT n [OFFSET m]]
```

Runs each `SELECT` and puts all their rows into one result. Rows that are the same are **kept** (that is the meaning of `ALL`).

| Part | Meaning |
|---|---|
| each `SELECT` | a normal query: it can have `FROM`, joins, `WHERE`, `GROUP BY`, `SAMPLE BY`, `HAVING` |
| `ORDER BY`, `LIMIT` at the end | work on **all** rows together |

- **Returns:** the rows of the first part, then the rows of the second part, and so on. The column **names** come from the first part.
- **NULL:** NULL values are kept like any other value.
- **Notes:**
  - Every part must have the same number of columns.
  - KDB does not check that the column types match. Put the same kind of value in the same position, or the column mixes numbers and text.
  - `ORDER BY` after `UNION ALL` can only use a result column name, an alias of the first part, or a position (`ORDER BY 2`). An expression like `ORDER BY amount * 2` is an error.
  - One part cannot have its own `ORDER BY` or `LIMIT`. Wrap that part in `FROM (SELECT ... LIMIT n) t` (example below).
  - `UNION` (without ALL) removes rows that are the same. `INTERSECT` keeps rows found in both parts, `EXCEPT` rows of the first part that are not in the second. With `ALL` they count copies. `INTERSECT` goes before `UNION` and `EXCEPT`.

**Example: Broker 58: what it bought and sold, per symbol** (sample data: sample)

```sql
SELECT symbol, 'buy' AS side, sum(quantity) AS shares FROM trade_log WHERE buyer = 58 GROUP BY symbol
UNION ALL
SELECT symbol, 'sell' AS side, sum(quantity) AS shares FROM trade_log WHERE seller = 58 GROUP BY symbol
ORDER BY symbol, side;
```

Result:

| symbol (SYMBOL) | side (STRING) | shares (LONG) |
|---|---|---|
| CITY | sell | 20 |
| COAST | buy | 760 |
| COAST | sell | 1200 |
| TELCO | buy | 1000 |
| VOLT | buy | 200 |
| VOLT | sell | 50 |

(6 rows)

**Example: Turnover of each broker on one day (bought + sold)** (sample data: sample)

```sql
SELECT broker, sum(amount) AS turnover, count(*) AS trades
FROM (
  SELECT buyer AS broker, amount FROM trade_log WHERE date IN '2026-09-10'
  UNION ALL
  SELECT seller AS broker, amount FROM trade_log WHERE date IN '2026-09-10'
) t
GROUP BY broker
ORDER BY turnover DESC;
```

Result:

| broker (INT) | turnover (DOUBLE) | trades (LONG) |
|---|---|---|
| 45 | 1288160 | 11 |
| 49 | 1173580 | 9 |
| 34 | 773260 | 9 |
| 58 | 761690 | 8 |
| 1 | 726070 | 11 |

(5 rows)

A `GROUP BY` over a `UNION ALL` like the one above is grouped part by part: each part sums its own rows in the column engine and the outer query adds up one row per broker and part, so it costs about as much as the two parts on their own. `EXPLAIN` shows it as `aggregates pushed into the 2 UNION ALL parts`. See [GROUP BY with many groups](performance-tips.md#many-groups) for what it covers.

Only `sum`, `count`, `min` and `max` can be added up part by part. With `avg`, `first`, `last` or `count(DISTINCT ...)` the parts are not grouped first, but their rows still go straight into the groups without being kept: `EXPLAIN` says `read part by part into the grouping (not kept)`.

**Example: EXPLAIN: grouped part by part, and read part by part** (sample data: sample)

```sql
EXPLAIN SELECT broker, sum(amount) AS turnover, count(*) AS trades
FROM (SELECT buyer AS broker, amount FROM trade_log WHERE date IN '2026-09-10'
      UNION ALL
      SELECT seller AS broker, amount FROM trade_log WHERE date IN '2026-09-10') t
GROUP BY broker;
EXPLAIN SELECT broker, avg(amount) AS avg_amount
FROM (SELECT buyer AS broker, amount FROM trade_log WHERE date IN '2026-09-10'
      UNION ALL
      SELECT seller AS broker, amount FROM trade_log WHERE date IN '2026-09-10') t
GROUP BY broker;
```

Result:

`EXPLAIN SELECT broker, sum(amount) AS turnover, count(*) AS trades FROM (SELECT buyer AS broker, amo`

| plan (STRING) |
|---|
| aggregates pushed into the 2 UNION ALL parts: each part groups its own table first |
| scan result of t (0 rows) |
| group by 1 key(s), 2 aggregate(s) |
| engine: row (reads a subquery or view result) |

(4 rows)

`EXPLAIN SELECT broker, avg(amount) AS avg_amount FROM (SELECT buyer AS broker, amount FROM trade_log`

| plan (STRING) |
|---|
| scan rows of t read part by part into the grouping (not kept) |
| group by 1 key(s), 1 aggregate(s) |
| engine: row (reads a subquery or view result) |

(3 rows)

**Example: One activity list from news and forum posts, newest first**

Setup:

```sql
CREATE TABLE news (id LONG PRIMARY KEY, title STRING, published_at TIMESTAMP);
CREATE TABLE forum_posts (id LONG PRIMARY KEY, title STRING, created_at TIMESTAMP);
INSERT INTO news VALUES
  (1, 'Market index gains 12 points', '2026-09-10T15:10:00+05:45'),
  (2, 'CITY announces bonus shares', '2026-09-09T16:00:00+05:45');
INSERT INTO forum_posts VALUES
  (10, 'Is VOLT a good buy now?', '2026-09-10T13:20:00+05:45'),
  (11, 'Hydro stocks after the monsoon', '2026-09-08T09:00:00+05:45');
```

```sql
SELECT 'news' AS kind, id, title, published_at AS at FROM news
UNION ALL
SELECT 'forum', id, title, created_at FROM forum_posts
ORDER BY at DESC
LIMIT 3;
```

Result:

| kind (STRING) | id (LONG) | title (STRING) | at (TIMESTAMP) |
|---|---|---|---|
| news | 1 | Market index gains 12 points | 2026-09-10T09:25:00.000Z |
| forum | 10 | Is VOLT a good buy now? | 2026-09-10T07:35:00.000Z |
| news | 2 | CITY announces bonus shares | 2026-09-09T10:15:00.000Z |

(3 rows)

**Example: Different values in the same column: KDB does not stop you**

```sql
SELECT 1 AS n, 'a' AS t
UNION ALL
SELECT 'x', 2;
```

Result:

| n (LONG) | t (STRING) |
|---|---|
| 1 | a |
| x | 2 |

(2 rows)

**Example: LIMIT for one part: wrap it in FROM ( )** (sample data: sample)

```sql
SELECT * FROM (SELECT transaction_id, symbol, amount FROM trade_log WHERE date IN '2026-09-09' ORDER BY amount DESC LIMIT 1) a
UNION ALL
SELECT * FROM (SELECT transaction_id, symbol, amount FROM trade_log WHERE date IN '2026-09-10' ORDER BY amount DESC LIMIT 1) b;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | amount (DOUBLE) |
|---|---|---|
| 100001 | TELCO | 881000 |
| 100017 | TELCO | 440500 |

(2 rows)

**Example: Symbols that traded and also have a daily candle (no copies)** (sample data: sample)

```sql
SELECT symbol FROM trade_log
INTERSECT
SELECT symbol FROM ochl_day
ORDER BY 1;
```

Result:

| symbol (SYMBOL) |
|---|
| CITY |
| COAST |
| VOLT |

(3 rows)

**Example: Every part needs the same number of columns** (sample data: sample; shows an error)

```sql
SELECT symbol FROM trade_log
UNION ALL
SELECT symbol, close FROM ochl_day;
```

Result:

Error: `UNION ALL part 2 has 2 columns, the first part has 1`

**Example: ORDER BY after UNION ALL needs a result column** (sample data: sample; shows an error)

```sql
SELECT symbol, quantity FROM trade_log
UNION ALL
SELECT symbol, volume FROM ochl_day
ORDER BY quantity * 2;
```

Result:

Error: `line 4, column 19: ORDER BY after UNION ALL must name a result column or position`

**Example: A part cannot have its own LIMIT** (sample data: sample; shows an error)

```sql
SELECT symbol FROM securities LIMIT 1
UNION ALL
SELECT 'X';
```

Result:

Error: `line 2, column 1: expected OFFSET, ';' or the end of the input but found 'UNION'`

<a id="scalar-subquery"></a>

## (SELECT ...) as a value

Syntax:

```sql
(SELECT expression FROM ... [WHERE ...] [LIMIT 1])
```

A subquery in `( )` where a value is expected: in the `SELECT` list, in `WHERE`, in `HAVING` or in a join's `ON`. It must return **0 or 1 row**.

- **Returns:** the value of the first column of that row.
- **NULL:** when the subquery returns no row, the value is `NULL`.
- **Notes:**
  - More than one row is an error: `subquery returned 3 rows; a value needs exactly one (add LIMIT 1?)`.
  - With more than one column, KDB uses the **first** column and does not complain. Select only one column.
  - The subquery runs once, so every row of the outer query gets the same value.

**Example: Each close next to the best close of the day** (sample data: sample)

```sql
SELECT symbol, close,
       (SELECT max(close) FROM ochl_day WHERE time IN '2026-09-10') AS best_close,
       round(close / (SELECT max(close) FROM ochl_day WHERE time IN '2026-09-10') * 100, 1) AS pct_of_best
FROM ochl_day
WHERE time IN '2026-09-10';
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | best_close (DOUBLE) | pct_of_best (DOUBLE) |
|---|---|---|---|
| CITY | 504.9 | 504.9 | 100 |
| COAST | 376.1 | 504.9 | 74.5 |
| VOLT | 191.2 | 504.9 | 37.9 |

(3 rows)

**Example: The trade at the highest CITY rate** (sample data: sample)

```sql
SELECT date, transaction_id, buyer, seller, quantity, rate
FROM trade_log
WHERE symbol = 'CITY'
  AND rate = (SELECT max(rate) FROM trade_log WHERE symbol = 'CITY');
```

Result:

| date (TIMESTAMP) | transaction_id (LONG) | buyer (INT) | seller (INT) | quantity (LONG) | rate (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-10T00:00:00.000Z | 100029 | 49 | 45 | 200 | 518 |

(1 row)

**Example: The last trading day in the table, without typing the date** (sample data: sample)

```sql
SELECT time, symbol, close
FROM ochl_day
WHERE time = (SELECT max(time) FROM ochl_day)
ORDER BY close DESC;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.9 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 |
| 2026-09-10T00:00:00.000Z | VOLT | 191.2 |

(3 rows)

**Example: Symbols with more trades than the average symbol** (sample data: sample)

```sql
SELECT symbol, count(*) AS trades
FROM trade_log
GROUP BY symbol
HAVING count(*) > (SELECT avg(n) FROM (SELECT symbol, count(*) AS n FROM trade_log GROUP BY symbol) t);
```

Result:

| symbol (SYMBOL) | trades (LONG) |
|---|---|
| CITY | 11 |
| COAST | 11 |

(2 rows)

**Example: No row gives NULL** (sample data: sample)

```sql
SELECT (SELECT max(close) FROM ochl_day WHERE symbol = 'TELCO') AS telco_best_close;
```

Result:

| telco_best_close (STRING) |
|---|
| NULL |

(1 row)

**Example: More than one row is an error** (sample data: sample; shows an error)

```sql
SELECT symbol, (SELECT close FROM ochl_day WHERE time IN '2026-09-10') AS close
FROM securities;
```

Result:

Error: `line 1, column 16: subquery returned 3 rows; a value needs exactly one (add LIMIT 1?)`

<a id="in-subquery"></a>

## IN (SELECT ...), NOT IN (SELECT ...)

Syntax:

```sql
expression IN (SELECT column FROM ... [WHERE ...])
expression NOT IN (SELECT column FROM ... [WHERE ...])
```

True when the value is (or is not) one of the values the subquery returns. It works like `IN ('a', 'b', ...)` with the list made by the subquery (see [IN](where.md#in-list)).

- **Returns:** `TRUE` or `FALSE` (or `NULL`, see below).
- **NULL:** a `NULL` on the left gives `NULL`. When the value is not found and the list has a `NULL`, the result is `NULL` too, so `NOT IN` keeps **no** rows. Add `WHERE column IS NOT NULL` inside the subquery.
- **Notes:**
  - An empty subquery gives an empty list: `IN` is false for every row, `NOT IN` is true.
  - With more than one column, KDB uses the **first** column. To match two columns at once, write `(a, b) IN (SELECT x, y FROM ...)` (see [row IN](where.md#row-in)).
  - The subquery can use `UNION ALL`, `GROUP BY`, `ORDER BY` and `LIMIT`.
  - For a symbol column, `IN (SELECT ...)` still lets KDB read only the rows of those symbols (see [EXPLAIN](explain.md#explain)).
  - In `UPDATE` and `DELETE` too: in `SET` and in the `WHERE`.

**Example: Securities with a trade of 1000 shares or more** (sample data: sample)

```sql
SELECT symbol, name
FROM securities
WHERE symbol IN (SELECT symbol FROM trade_log WHERE quantity >= 1000);
```

Result:

| symbol (SYMBOL) | name (STRING) |
|---|---|
| COAST | Coastal Bank Limited |
| TELCO | Northwind Telecom Limited |

(2 rows)

**Example: Securities with no daily candles yet** (sample data: sample)

```sql
SELECT symbol, name, sector
FROM securities
WHERE symbol NOT IN (SELECT symbol FROM ochl_day);
```

Result:

| symbol (SYMBOL) | name (STRING) | sector (STRING) |
|---|---|---|
| ACME | Acme Investment Company | Investment |
| TELCO | Northwind Telecom Limited | Telecom |

(2 rows)

**Example: Candles of the 3 symbols with the biggest turnover (TELCO has no candles)** (sample data: sample)

```sql
SELECT time, symbol, close, volume
FROM ochl_day
WHERE time IN '2026-09-10'
  AND symbol IN (SELECT symbol
                 FROM (SELECT symbol, sum(amount) AS turnover FROM trade_log
                       WHERE date IN '2026-09-10' GROUP BY symbol
                       ORDER BY turnover DESC LIMIT 3) top3);
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.9 | 183040 |
| 2026-09-10T00:00:00.000Z | COAST | 376.1 | 186200 |

(2 rows)

**Example: Users who wrote a post, for an app**

Setup:

```sql
CREATE TABLE app_users (id LONG PRIMARY KEY, name STRING, banned BOOL);
CREATE TABLE posts (id LONG PRIMARY KEY, user_id LONG, title STRING);
INSERT INTO app_users VALUES (1, 'sita', FALSE), (2, 'ram', FALSE), (3, 'hari', TRUE);
INSERT INTO posts VALUES (100, 1, 'COAST results'), (101, 3, 'Buy now!!!'), (102, 1, 'Hydro outlook');
```

```sql
SELECT id, name FROM app_users WHERE id IN (SELECT user_id FROM posts) ORDER BY id;
SELECT id, name FROM app_users WHERE id NOT IN (SELECT user_id FROM posts);
```

Result:

`SELECT id, name FROM app_users WHERE id IN (SELECT user_id FROM posts) ORDER BY id`

| id (LONG) | name (STRING) |
|---|---|
| 1 | sita |
| 3 | hari |

(2 rows)

`SELECT id, name FROM app_users WHERE id NOT IN (SELECT user_id FROM posts)`

| id (LONG) | name (STRING) |
|---|---|
| 2 | ram |

(1 row)

**Example: A NULL in the list: NOT IN keeps nothing**

Setup:

```sql
CREATE TABLE app_users (id LONG PRIMARY KEY, name STRING);
CREATE TABLE posts (id LONG PRIMARY KEY, user_id LONG);
INSERT INTO app_users VALUES (1, 'sita'), (2, 'ram');
INSERT INTO posts VALUES (100, 1), (101, NULL);
```

```sql
SELECT name FROM app_users WHERE id NOT IN (SELECT user_id FROM posts);
SELECT name FROM app_users WHERE id NOT IN (SELECT user_id FROM posts WHERE user_id IS NOT NULL);
```

Result:

`SELECT name FROM app_users WHERE id NOT IN (SELECT user_id FROM posts)`

| name (STRING) |
|---|

(0 rows)

`SELECT name FROM app_users WHERE id NOT IN (SELECT user_id FROM posts WHERE user_id IS NOT NULL)`

| name (STRING) |
|---|
| ram |

(1 row)

**Example: Clean up posts of users who are gone**

Setup:

```sql
CREATE TABLE app_users (id LONG PRIMARY KEY, name STRING);
CREATE TABLE posts (id LONG PRIMARY KEY, user_id LONG);
INSERT INTO app_users VALUES (1, 'sita');
INSERT INTO posts VALUES (100, 1), (101, 9);
```

```sql
DELETE FROM posts WHERE user_id NOT IN (SELECT id FROM app_users);
SELECT * FROM posts;
```

Result:

`DELETE FROM posts WHERE user_id NOT IN (SELECT id FROM app_users)`

```text
1 row(s) deleted
```

`SELECT * FROM posts`

| id (LONG) | user_id (LONG) |
|---|---|
| 100 | 1 |

(1 row)

<a id="exists"></a>

## EXISTS, NOT EXISTS

Syntax:

```sql
EXISTS (SELECT ... FROM ... [WHERE ...])
NOT EXISTS (SELECT ... FROM ... [WHERE ...])
```

`EXISTS` is true when the subquery returns at least one row. What the subquery selects does not matter (`SELECT 1` is usual).

- **Returns:** `TRUE` or `FALSE`, never `NULL`.
- **NULL:** a row full of NULL values still counts as a row.
- **Notes:** because the subquery cannot use outer columns, `EXISTS` is the **same for every row**: all rows are kept or none. It is useful as an on/off switch ("only if there is any big trade today"). To test each row ("securities that have trades"), use [IN (SELECT ...)](union-subqueries.md#in-subquery) or a join.

**Example: Show today's candles only if today's trade log is loaded** (sample data: sample)

```sql
SELECT symbol, close
FROM ochl_day
WHERE time IN '2026-09-10'
  AND EXISTS (SELECT 1 FROM trade_log WHERE date IN '2026-09-10');
```

Result:

| symbol (SYMBOL) | close (DOUBLE) |
|---|---|
| CITY | 504.9 |
| COAST | 376.1 |
| VOLT | 191.2 |

(3 rows)

**Example: As a column: is there any trade of 1000 shares or more?** (sample data: sample)

```sql
SELECT EXISTS (SELECT 1 FROM trade_log WHERE quantity >= 1000) AS big_trade,
       NOT EXISTS (SELECT 1 FROM trade_log WHERE quantity > 5000) AS no_huge_trade;
```

Result:

| big_trade (BOOL) | no_huge_trade (BOOL) |
|---|---|
| true | true |

(1 row)

**Example: Accounting check: warn when a journal entry does not balance**

Setup:

```sql
CREATE TABLE journal (entry_id LONG, line INT, account STRING, debit DECIMAL(2), credit DECIMAL(2));
INSERT INTO journal VALUES
  (1, 1, 'Cash', 5000.00, 0), (1, 2, 'Sales', 0, 5000.00),
  (2, 1, 'Rent', 1200.00, 0), (2, 2, 'Cash', 0, 1000.00);
```

```sql
SELECT EXISTS (SELECT entry_id FROM journal GROUP BY entry_id HAVING sum(debit) != sum(credit)) AS has_unbalanced_entry;
SELECT entry_id, sum(debit) AS debit, sum(credit) AS credit
FROM journal GROUP BY entry_id HAVING sum(debit) != sum(credit);
```

Result:

`SELECT EXISTS (SELECT entry_id FROM journal GROUP BY entry_id HAVING sum(debit) != sum(credit)) AS h`

| has_unbalanced_entry (BOOL) |
|---|
| true |

(1 row)

`SELECT entry_id, sum(debit) AS debit, sum(credit) AS credit FROM journal GROUP BY entry_id HAVING su`

| entry_id (LONG) | debit (DECIMAL(2)) | credit (DECIMAL(2)) |
|---|---|---|
| 2 | 1200.00 | 1000.00 |

(1 row)

<a id="from-subquery"></a>

## FROM (SELECT ...) alias

Syntax:

```sql
SELECT ... FROM (SELECT ...) [AS] alias [JOIN ...] [WHERE ...] ...
SELECT ... FROM table t JOIN (SELECT ...) [AS] alias ON condition
```

Uses the result of a query as a table. This is also called a **derived table**. The subquery **needs a name** (the alias).

| Part | Meaning |
|---|---|
| `(SELECT ...)` | any query, also with `GROUP BY`, `SAMPLE BY`, window functions, `UNION ALL`, `ORDER BY` and `LIMIT` |
| `alias` | the name of the result; write `alias.column` in the outer query |

- **Returns:** the columns of the subquery, with their names or aliases. Give every computed column an alias, so the outer query can name it.
- **Notes:**
  - Use it to work in steps: make candles inside, compute an indicator outside; group inside, filter or join outside.
  - When the subquery has a `TIMESTAMP` column, the outer query can use `SAMPLE BY` on it.
  - A subquery in `FROM` or `JOIN` keeps all its rows in memory. Filter by time **inside** it for big tables.
  - One exception: when the outer query is a `GROUP BY` and the subquery is its only source, and the subquery (or each `UNION ALL` part of it) is a plain `SELECT` of one table with no `GROUP BY`, `DISTINCT`, `ORDER BY` or `LIMIT` of its own, its rows go **straight into the groups**, one after another. Only the groups are kept, so millions of rows fit (and very many groups go to disk, see [big GROUP BY](group-by.md#big-group-by)).

**Example: Group inside, filter outside** (sample data: sample)

```sql
SELECT t.symbol, t.trades, t.shares
FROM (SELECT symbol, count(*) AS trades, sum(quantity) AS shares FROM trade_log GROUP BY symbol) t
WHERE t.trades > 5
ORDER BY t.shares DESC;
```

Result:

| symbol (SYMBOL) | trades (LONG) | shares (LONG) |
|---|---|---|
| COAST | 11 | 3070 |
| TELCO | 6 | 2770 |
| CITY | 11 | 2420 |

(3 rows)

**Example: Weekly candles inside, 2-week moving average outside** (sample data: sample)

```sql
SELECT time, close, sma(close, 2) AS sma2
FROM (
  SELECT time, last(close) AS close
  FROM ochl_day
  WHERE symbol = 'CITY' AND time IN '2026'
  SAMPLE BY 1w WEEK START SUNDAY
) w;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | sma2 (DOUBLE) |
|---|---|---|
| 2026-08-23T00:00:00.000Z | 505.9 | NULL |
| 2026-08-30T00:00:00.000Z | 497.9 | 501.9 |
| 2026-09-06T00:00:00.000Z | 504.9 | 501.4 |

(3 rows)

**Example: Join each trade to the symbol's total for the day** (sample data: sample)

```sql
SELECT f.transaction_id, f.symbol, f.quantity, d.total,
       round(f.quantity * 100.0 / d.total, 1) AS pct_of_day
FROM trade_log f
JOIN (SELECT symbol, sum(quantity) AS total FROM trade_log WHERE date IN '2026-09-10' GROUP BY symbol) AS d
  ON d.symbol = f.symbol
WHERE f.date IN '2026-09-10' AND f.symbol = 'COAST'
ORDER BY pct_of_day DESC
LIMIT 4;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | quantity (LONG) | total (LONG) | pct_of_day (DOUBLE) |
|---|---|---|---|---|
| 100015 | COAST | 1000 | 2850 | 35.1 |
| 100031 | COAST | 1000 | 2850 | 35.1 |
| 100023 | COAST | 500 | 2850 | 17.5 |
| 100026 | COAST | 200 | 2850 | 7 |

(4 rows)

**Example: A cash book from two tables, with a running balance**

Setup:

```sql
CREATE TABLE sales (id LONG PRIMARY KEY, day DATE, amount DECIMAL(2));
CREATE TABLE expenses (id LONG PRIMARY KEY, day DATE, amount DECIMAL(2));
INSERT INTO sales VALUES (1, '2026-09-01', 25000.00), (2, '2026-09-03', 18000.00);
INSERT INTO expenses VALUES (1, '2026-09-02', 12000.00), (2, '2026-09-03', 2500.50);
```

```sql
SELECT day, kind, amount, cumsum(amount) OVER (ORDER BY day, kind) AS balance
FROM (
  SELECT day, 'sale' AS kind, amount FROM sales
  UNION ALL
  SELECT day, 'expense', -amount FROM expenses
) book
ORDER BY day, kind;
```

Result:

| day (DATE) | kind (STRING) | amount (DECIMAL(2)) | balance (DOUBLE) |
|---|---|---|---|
| 2026-09-01 | sale | 25000.00 | 25000 |
| 2026-09-02 | expense | -12000.00 | 13000 |
| 2026-09-03 | expense | -2500.50 | 10499.5 |
| 2026-09-03 | sale | 18000.00 | 28499.5 |

(4 rows)

**Example: The subquery needs no name** (sample data: sample)

```sql
SELECT count(*) FROM (SELECT symbol FROM securities);
```

Result:

| count(*) (LONG) |
|---|
| 5 |

(1 row)

<a id="correlated"></a>

## Correlated subqueries

Syntax:

```sql
SELECT ..., (SELECT ... FROM t2 WHERE t2.col = t1.col) FROM t1
SELECT ... FROM t1 WHERE [NOT] EXISTS (SELECT 1 FROM t2 WHERE t2.col = t1.col)
SELECT ... FROM t1 LEFT JOIN LATERAL (SELECT ... WHERE t2.col = t1.col) x ON TRUE
```

A **correlated** subquery uses a column of the outer query (`t1.col` above).

- **Speed:** KDB does not run it again for every outer row. When the subquery joins the outer row with `=` (`t2.col = t1.col`), it runs once per **different** outer value first, with that value as a constant, so an index on `t2.col` answers it. Once the outer query has asked for more values than that pays for (one value per 256 rows of `t2` when `col` has an index or is the primary key, at least 8; 8 without an index), KDB reads `t2` once, builds a hash table by `col` and looks every further outer row up in it. So a page about one user costs a few index lookups (0.4 ms where the old plan took 930 ms on 300,000 logins), and a report over every user costs one pass over `t2`. Other subqueries run once per different outer value.
- **Returns:** a value subquery gives NULL when no row matches (`count(*)` gives 0). It is an error when it finds more than one row; add `LIMIT 1` or an aggregate.
- **Notes:** a join with `GROUP BY` or a window function (`lag(x) OVER (PARTITION BY ...)`) gives the same answers and is often easier to read.

**Example: The best close of each symbol, as a subquery per row** (sample data: sample)

```sql
SELECT s.symbol,
       (SELECT max(close) FROM ochl_day d WHERE d.symbol = s.symbol) AS best_close
FROM securities s
ORDER BY s.symbol;
```

Result:

| symbol (SYMBOL) | best_close (DOUBLE) |
|---|---|
| ACME | NULL |
| CITY | 542.4 |
| COAST | 426.5 |
| TELCO | NULL |
| VOLT | 196.4 |

(5 rows)

**Example: The same question as a LEFT JOIN with GROUP BY** (sample data: sample)

```sql
SELECT s.symbol, max(d.close) AS best_close
FROM securities s
LEFT JOIN ochl_day d ON d.symbol = s.symbol
GROUP BY s.symbol
ORDER BY s.symbol;
```

Result:

| symbol (SYMBOL) | best_close (DOUBLE) |
|---|---|
| ACME | NULL |
| CITY | 542.4 |
| COAST | 426.5 |
| TELCO | NULL |
| VOLT | 196.4 |

(5 rows)

**Example: Symbols with at least one trade: EXISTS with an outer column** (sample data: sample)

```sql
SELECT symbol FROM securities s
WHERE EXISTS (SELECT 1 FROM trade_log f WHERE f.symbol = s.symbol)
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) |
|---|
| CITY |
| COAST |
| TELCO |
| VOLT |

(4 rows)

**Example: The same test with IN (SELECT ...)** (sample data: sample)

```sql
SELECT symbol FROM securities
WHERE symbol IN (SELECT symbol FROM trade_log)
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) |
|---|
| CITY |
| COAST |
| TELCO |
| VOLT |

(4 rows)

**Example: Latest close per symbol compared with the day before: a window function instead** (sample data: sample)

```sql
SELECT symbol, prev_close, close, round((close - prev_close) / prev_close * 100, 2) AS change_pct
FROM (
  SELECT time, symbol, close, lag(close) OVER (PARTITION BY symbol ORDER BY time) AS prev_close
  FROM ochl_day
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
