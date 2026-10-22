# SELECT

> Choose the columns and values that a query gives back, and the table they come from.

- Category: Querying
- Keywords: query, read rows, columns, \*, table.\*, AS, alias, column name, FROM, DISTINCT, unique rows, SELECT without FROM, calculator, missing comma, select, from, distinct
- See also: [WHERE](where.md), [ORDER BY, LIMIT, OFFSET](order-by-limit.md), [GROUP BY and HAVING](group-by.md), [Joins](joins.md), [UNION and subqueries](union-subqueries.md), [Views](views.md)

`SELECT` reads data. You say which values you want (the **select list**), and from which table (`FROM`).
Every other part (`WHERE`, `GROUP BY`, `ORDER BY`, ...) is optional and has its own help page.

A select item can be a column, a calculation, a function or a constant. Give it a name with `AS`.

**Example: Today's change of every symbol, like a market summary** (sample data: sample)

```sql
SELECT symbol, open, close,
       round(close - open, 2) AS change,
       round((close - open) / open * 100, 2) AS change_pct
FROM ochl_day
WHERE time IN '2026-09-10'
ORDER BY change_pct DESC;
```

Result:

| symbol (SYMBOL) | open (DOUBLE) | close (DOUBLE) | change (DOUBLE) | change_pct (DOUBLE) |
|---|---|---|---|---|
| VOLT | 185.6 | 191.2 | 5.6 | 3.02 |
| CITY | 504.6 | 504.9 | 0.3 | 0.06 |
| COAST | 380.1 | 376.1 | -4 | -1.05 |

(3 rows)

<a id="select-list"></a>

## SELECT

Syntax:

```sql
SELECT [DISTINCT] item [[AS] alias], ...
[FROM source [JOIN ...]]
[WHERE condition]
[LATEST ON time PARTITION BY column, ...]
[SAMPLE BY interval ...]
[GROUP BY expression, ...]
[HAVING condition]
[UNION ALL SELECT ...]
[ORDER BY expression [ASC | DESC], ...]
[LIMIT n [OFFSET m]]
```

The parts must be written in this order. KDB does the work in another order:

| Step | Part | What happens |
|---|---|---|
| 1 | `FROM`, `JOIN` | read the tables |
| 2 | `WHERE` | keep only the rows that match |
| 3 | `LATEST ON` | keep the newest row of each group |
| 4 | `SAMPLE BY`, `GROUP BY` | make groups and compute `sum`, `max`, ... |
| 5 | `HAVING` | keep only the groups that match |
| 6 | window functions | `lag`, `sma`, `row_number`, ... |
| 7 | select list, `DISTINCT` | compute the output columns |
| 8 | `UNION ALL` | add the rows of the next query |
| 9 | `ORDER BY`, `LIMIT`, `OFFSET` | sort and cut |

| Item | Example |
|---|---|
| a column | `close` |
| a column of one table (with joins) | `f.symbol` |
| a calculation | `high - low` |
| a function | `round(close, 1)`, `upper(name)` |
| an aggregate | `count(*)`, `max(high)` (see [GROUP BY](group-by.md)) |
| a constant | `'hello'`, `100`, `TRUE`, `NULL` |
| all columns | `*`, `f.*` |

- **Returns:** a table of rows. The column names come from the aliases, else from the items.
- **Notes:** names of tables, columns and functions do not care about case (`CLOSE` is `close`). Text values do: `'CITY'` is not `'city'`.

**Example: Trade log: the value of each trade on 2026-09-09** (sample data: sample)

```sql
SELECT transaction_id, symbol, quantity, rate, quantity * rate AS value
FROM trade_log
WHERE date IN '2026-09-09'
ORDER BY value DESC
LIMIT 4;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | quantity (LONG) | rate (DOUBLE) | value (DOUBLE) |
|---|---|---|---|---|
| 100001 | TELCO | 1000 | 881 | 881000 |
| 100007 | TELCO | 1000 | 879 | 879000 |
| 100005 | CITY | 500 | 517 | 258500 |
| 100004 | CITY | 500 | 514.5 | 257250 |

(4 rows)

**Example: App users: name, email and plan** (sample data: query-app)

```sql
SELECT username, lower(email) AS email, upper(plan) AS plan
FROM app_users
WHERE id <= 4;
```

Result:

| username (STRING) | email (STRING) | plan (STRING) |
|---|---|---|
| ram | ram.sharma@gmail.com | PRO |
| sita | sita.k@yahoo.com | FREE |
| hari_99 | hari99@gmail.com | FREE |
| gita | gita.rai@gmail.com | PRO |

(4 rows)

**Example: Accounting: the amount of each journal line, debit or credit** (sample data: query-app)

```sql
SELECT line_id, entry_id, account, coalesce(debit, 0) - coalesce(credit, 0) AS amount, memo
FROM ledger
WHERE entry_id IN (2, 8);
```

Result:

| line_id (INT) | entry_id (INT) | account (INT) | amount (DECIMAL(2)) | memo (STRING) |
|---|---|---|---|---|
| 3 | 2 | 1200 | 257500.00 | Buy 500 CITY at 515 |
| 4 | 2 | 2000 | -257500.00 | Buy 500 CITY at 515 |
| 15 | 8 | 1100 | 12600.00 | Sell 20 CITY at 630 |
| 16 | 8 | 1200 | -10300.00 | Sell 20 CITY at 630 |
| 17 | 8 | 4100 | -2300.00 | Sell 20 CITY at 630 |

(5 rows)

<a id="star"></a>

## *, table.*

Syntax:

```sql
SELECT * FROM table
SELECT alias.*, other_item, ... FROM table alias JOIN ...
```

`*` means every column of every table in `FROM`, in table order. `alias.*` means every column of one table.

- **Returns:** the stored columns and the computed columns (`AS (...)`) of the table.
- **Notes:** `*` cannot be used together with aggregates or `SAMPLE BY`. In programs, list the columns you need: KDB then takes only those columns out of each stored row, which is faster on wide tables (`EXPLAIN` shows `build 3 of 7 stored column(s) per row`), and a new column in the table does not change your result.

**Example** (sample data: sample)

```sql
SELECT * FROM brokers;
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

**Example: All columns of the trade, plus the buyer's name** (sample data: sample)

```sql
SELECT f.*, b.name AS buyer_name
FROM trade_log f
JOIN brokers b ON b.id = f.buyer
WHERE f.transaction_id = 100017;
```

Result:

| date (TIMESTAMP) | transaction_id (LONG) | symbol (SYMBOL) | buyer (INT) | seller (INT) | quantity (LONG) | rate (DOUBLE) | amount (DOUBLE) | buyer_name (STRING) |
|---|---|---|---|---|---|---|---|---|
| 2026-09-10T00:00:00.000Z | 100017 | TELCO | 49 | 34 | 500 | 881 | 440500 | Online Securities |

(1 row)

**Example: * and count(*) do not mix** (sample data: sample; shows an error)

```sql
SELECT *, count(*) FROM brokers;
```

Result:

Error: `line 1, column 8: * cannot be combined with aggregates or SAMPLE BY`

<a id="alias"></a>

## AS: column names

Syntax:

```sql
item AS alias
item alias
item AS "any name"
```

`AS` gives an output column a name. The word `AS` is optional.

| Written | Column name |
|---|---|
| `close` | `close` |
| `close AS last_price` | `last_price` |
| `close * 2` (no alias) | `close * 2` |
| `count(*)` (no alias) | `count(*)` |
| `close AS "Close Price"` | `Close Price` (double quotes keep spaces and case) |

- **Notes:** a **missing comma** is not an error: `SELECT symbol close` gives one column named `close` that holds the symbol. Check your commas.
- A reserved word (like `order`, `select`, `from`) needs double quotes: `AS "order"`.
- The words `ASOF`, `CROSS`, `FULL`, `HAVING`, `INNER`, `LATEST`, `LEFT`, `LT`, `OVER`, `REFRESH`, `RIGHT`, `SAMPLE`, `SPLICE`, `UNION` and `USING` need `AS` to be an alias: `close AS left` works, `close left` does not.
- An alias can be used in `ORDER BY`, but not in `WHERE`, `GROUP BY` or `HAVING` (write the expression again there). See [ORDER BY](order-by-limit.md#order-by) and [GROUP BY](group-by.md#group-by).

**Example** (sample data: sample)

```sql
SELECT symbol, close AS last_price, close last, close * 2, round(close) AS "Close (whole dollars)"
FROM ochl_day
WHERE time IN '2026-09-10';
```

Result:

| symbol (SYMBOL) | last_price (DOUBLE) | last (DOUBLE) | close * 2 (DOUBLE) | Close (whole dollars) (DOUBLE) |
|---|---|---|---|---|
| CITY | 504.9 | 504.9 | 1009.8 | 505 |
| COAST | 376.1 | 376.1 | 752.2 | 376 |
| VOLT | 191.2 | 191.2 | 382.4 | 191 |

(3 rows)

**Example: Aggregates without an alias get their text as the name** (sample data: sample)

```sql
SELECT symbol, count(*), max(high) AS highest
FROM ochl_day
GROUP BY symbol;
```

Result:

| symbol (SYMBOL) | count(*) (LONG) | highest (DOUBLE) |
|---|---|---|
| CITY | 19 | 546.2 |
| COAST | 19 | 429.9 |
| VOLT | 19 | 199.7 |

(3 rows)

**Example: A missing comma quietly renames the column** (sample data: sample)

```sql
SELECT symbol close FROM securities LIMIT 2;
```

Result:

| close (SYMBOL) |
|---|
| ACME |
| CITY |

(2 rows)

**Example: A reserved word as a name needs double quotes** (sample data: sample; shows an error)

```sql
SELECT symbol AS order FROM securities;
```

Result:

Error: `line 1, column 18: expected an alias after AS but found the reserved word 'order' (write it in double quotes, "order", to use it as a name)`

**Example: The fix** (sample data: sample)

```sql
SELECT symbol AS "order" FROM securities LIMIT 2;
```

Result:

| order (SYMBOL) |
|---|
| ACME |
| CITY |

(2 rows)

<a id="select-without-from"></a>

## SELECT without FROM

Syntax:

```sql
SELECT expression [[AS] alias], ...
```

Without `FROM`, KDB computes the values once and gives one row. Use it like a calculator, or to test a function.

- **Returns:** one row.
- **Notes:** `WHERE` still works (a false condition gives 0 rows). `*` needs a `FROM` table.

**Example** (sample data: sample)

```sql
SELECT 1 + 1 AS two, round(100000 * 1.08, 2) AS with_interest, upper('city') AS symbol;
```

Result:

| two (LONG) | with_interest (DOUBLE) | symbol (STRING) |
|---|---|---|
| 2 | 108000 | CITY |

(1 row)

**Example: What is 11:00 Nepal time in UTC?** (sample data: sample)

```sql
SELECT CAST('2026-09-10T11:00:00+05:45' AS TIMESTAMP) AS market_open_utc;
```

Result:

| market_open_utc (TIMESTAMP) |
|---|
| 2026-09-10T05:15:00.000Z |

(1 row)

**Example: * needs a table** (sample data: sample; shows an error)

```sql
SELECT *;
```

Result:

Error: `line 1, column 8: * needs a FROM table`

<a id="from"></a>

## FROM

Syntax:

```sql
FROM table [[AS] alias]
FROM database.table [[AS] alias]
FROM view [[AS] alias]
FROM (SELECT ...) [AS] alias
```

`FROM` names the table the rows come from. It can also be a [view](views.md) or a [subquery](union-subqueries.md#from-subquery) in `( )`.

| Part | Meaning |
|---|---|
| `table` | a relational or time-series table of the current database |
| `database.table` | a table of another database on the same server (see [queries across databases](cross-database-queries.md)) |
| `alias` | a short name for the table, used as `alias.column` (see [table aliases](joins.md#aliases)) |
| `(SELECT ...) alias` | the rows of another query; the alias is required |

- **Notes:** without `ORDER BY`, a time-series table gives rows partition by partition, sorted by its `SORT BY` columns (usually symbol, then time). A relational table gives rows in key order. Do not depend on this: add `ORDER BY` when the order matters.
- Names with capital letters or spaces can be written in double quotes: `FROM "Ochl_Day"` is the same table as `FROM ochl_day`.

**Example: A table with a short name** (sample data: sample)

```sql
SELECT s.symbol, s.sector FROM securities AS s WHERE s.sector = 'Banking';
```

Result:

| symbol (SYMBOL) | sector (STRING) |
|---|---|
| CITY | Banking |
| COAST | Banking |

(2 rows)

**Example: Rows of a subquery: trades per symbol, only the busy ones** (sample data: sample)

```sql
SELECT t.symbol, t.trades
FROM (SELECT symbol, count(*) AS trades FROM trade_log GROUP BY symbol) t
WHERE t.trades > 5;
```

Result:

| symbol (SYMBOL) | trades (LONG) |
|---|---|
| CITY | 11 |
| COAST | 11 |
| TELCO | 6 |

(3 rows)

**Example: A wrong table name** (sample data: sample; shows an error)

```sql
SELECT * FROM ochl_days;
```

Result:

Error: `line 1, column 15: table or view 'ochl_days' does not exist`

<a id="distinct"></a>

## DISTINCT

Syntax:

```sql
SELECT DISTINCT item, ... FROM ...
```

`DISTINCT` removes repeated rows from the result. Two rows are the same when **all** their output columns are equal.

- **Returns:** each different row once.
- **NULL:** `NULL` values count as equal, so many `NULL` rows become one.
- **Notes:** to count different values, use `count(DISTINCT x)` (see [aggregate functions](functions-aggregate.md)). `DISTINCT` works on the output columns, after `GROUP BY`.
- `SELECT DISTINCT day` on a table with one partition per day is answered from the list of partitions, without reading rows (see [answers without reading rows](explain.md#saved-stats)).

**Example** (sample data: sample)

```sql
SELECT DISTINCT sector FROM securities ORDER BY sector;
```

Result:

| sector (STRING) |
|---|
| Banking |
| Energy |
| Investment |
| Telecom |

(4 rows)

**Example: Which broker bought which symbol on 2026-09-09** (sample data: sample)

```sql
SELECT DISTINCT buyer, symbol
FROM trade_log
WHERE date IN '2026-09-09'
ORDER BY buyer, symbol;
```

Result:

| buyer (INT) | symbol (SYMBOL) |
|---|---|
| 1 | CITY |
| 34 | CITY |
| 34 | COAST |
| 45 | CITY |
| 49 | TELCO |
| 58 | COAST |
| 58 | TELCO |

(7 rows)

**Example: Cities of app users (NULL appears once)** (sample data: query-app)

```sql
SELECT DISTINCT city FROM app_users ORDER BY city;
```

Result:

| city (STRING) |
|---|
| Dharan |
| Kathmandu |
| Lalitpur |
| Pokhara |
| NULL |

(5 rows)

**Example: Count different values instead** (sample data: sample)

```sql
SELECT count(DISTINCT symbol) AS symbols_traded, count(*) AS trades FROM trade_log;
```

Result:

| symbols_traded (LONG) | trades (LONG) |
|---|---|
| 4 | 32 |

(1 row)
