# PIVOT

> Turn the values of one column into columns, like a pivot table in Excel: turnover per symbol with one column per day.

- Category: Querying
- Keywords: PIVOT, pivot table, cross tab, crosstab, rows to columns, values as columns, spread out, columns per month, columns per day, Excel pivot, wide table, long to wide
- See also: [GROUP BY and HAVING](group-by.md), [Aggregate functions (sum_if)](functions-aggregate.md#sum_if), [Aggregate functions (count_if)](functions-aggregate.md#count_if), [Conditional and NULL functions (case)](functions-conditional.md#case), [UNION and subqueries](union-subqueries.md)

A **pivot table** turns rows into columns. `GROUP BY symbol, date` gives one row for each symbol and day ("long" data). A pivot gives one row for each symbol and **one column for each day** ("wide" data), which is easier to read in a report:

| symbol | sep_09 | sep_10 |
|---|---|---|
| CITY | 777400 | 469830 |
| COAST | 88170 | 1139340 |

There are two ways to get it in KDB:

1. **The manual way (works today):** one aggregate per column, each with its own condition: `sum_if(amount, date = '2026-09-09') AS sep_09` ([sum_if](functions-aggregate.md#sum_if), [count_if](functions-aggregate.md#count_if)), or `sum(CASE WHEN date = '2026-09-09' THEN amount END)`.
2. **The PIVOT clause:** write the aggregate once and list the values: `PIVOT (sum(amount) FOR date IN ('2026-09-09' AS sep_09, '2026-09-10' AS sep_10))`.

**Coming soon:** the kdb program this page was built with reads the `PIVOT` clause and checks its spelling, but does not apply it yet: a query with `PIVOT` returns the rows **as if PIVOT were not there**. Until the next build, use the manual way. The PIVOT examples below show their results after that build.

**Example: The manual way: turnover per symbol, one column per day** (sample data: sample)

```sql
SELECT symbol,
       sum_if(amount, date = '2026-09-09') AS sep_09,
       sum_if(amount, date = '2026-09-10') AS sep_10,
       sum(amount) AS total
FROM trade_log
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | sep_09 (DOUBLE) | sep_10 (DOUBLE) | total (DOUBLE) |
|---|---|---|---|
| CITY | 777400 | 469830 | 1247230 |
| COAST | 88170 | 1139340 | 1227510 |
| TELCO | 1760000 | 678260 | 2438260 |
| VOLT | NULL | 73950 | 73950 |

(4 rows)

**Example: The manual way: app users per city, one column per plan** (sample data: query-app)

```sql
SELECT coalesce(city, '(none)') AS city,
       count_if(plan = 'free') AS free,
       count_if(plan = 'pro') AS pro,
       count_if(plan = 'admin') AS admin
FROM app_users
GROUP BY coalesce(city, '(none)')
ORDER BY city;
```

Result:

| city (STRING) | free (LONG) | pro (LONG) | admin (LONG) |
|---|---|---|---|
| (none) | 2 | 0 | 0 |
| Dharan | 0 | 1 | 0 |
| Kathmandu | 1 | 1 | 0 |
| Lalitpur | 0 | 0 | 1 |
| Pokhara | 1 | 1 | 0 |

(5 rows)

<a id="pivot-clause"></a>

## PIVOT (...)

Syntax:

```sql
SELECT ... FROM source PIVOT (aggregate(x) [AS name] [, ...]
                              FOR column IN (value [AS name] [, ...])) [[AS] alias]
SELECT ... FROM source [AS] alias PIVOT (...)
```

`PIVOT` comes right after a source in `FROM`: a table, a view or a subquery. For every value in the `IN (...)` list it makes a new column. The column holds the aggregate of the rows where `column` has that value.

| Part | Meaning |
|---|---|
| `aggregate(x) [AS name]` | what goes into the new columns, like `sum(amount)` or `count(id)`. Any aggregate works; you can list more than one |
| `FOR column` | the column whose values become new columns (the day, the month, the plan) |
| `IN (value [AS name], ...)` | the values to spread out, as constants: `'2026-09-09'`, `1`, `'pro'`. `AS name` names the new column. With more than one aggregate there is a column for each value and aggregate, named value name, `_`, aggregate name: `week1_debit` |

- **The other columns** of the source (not in the aggregate and not the `FOR` column) become the **group keys**: one result row for each of their value combinations. So pivot a subquery that has only the columns you need: `(SELECT symbol, date, amount FROM trade_log) f`.
- **NULL:** a value from the `IN` list that has no rows gives `NULL` in its column (like `sum` of no rows). Rows whose `FOR` column is not in the list are not used.
- **Notes:**
  - A source can have only one `PIVOT`.
  - The values must be written out. A pivot over "all days in the table" needs to know the days first: find them with `SELECT DISTINCT date ...`, then write the query.
  - For a dynamic list of columns in an app, build the SQL text in the app, or use the manual way.

**Example: Turnover per symbol, one column per day** (sample data: sample)

```sql
SELECT symbol, sep_09, sep_10
FROM (SELECT symbol, date, amount FROM trade_log) f
PIVOT (sum(amount) FOR date IN ('2026-09-09' AS sep_09, '2026-09-10' AS sep_10))
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | sep_09 (DOUBLE) | sep_10 (DOUBLE) |
|---|---|---|
| CITY | 777400 | 469830 |
| COAST | 88170 | 1139340 |
| TELCO | 1760000 | 678260 |
| VOLT | NULL | 73950 |

(4 rows)

**Example: App users per city, one column per plan** (sample data: query-app)

```sql
SELECT city, free, pro, admin
FROM (SELECT city, plan, id FROM app_users) u
PIVOT (count(id) FOR plan IN ('free' AS free, 'pro' AS pro, 'admin' AS admin))
ORDER BY city;
```

Result:

| city (STRING) | free (LONG) | pro (LONG) | admin (LONG) |
|---|---|---|---|
| Dharan | 0 | 1 | 0 |
| Kathmandu | 1 | 1 | 0 |
| Lalitpur | 0 | 0 | 1 |
| Pokhara | 1 | 1 | 0 |
| NULL | 2 | 0 | 0 |

(5 rows)

**Example: Two aggregates: debit and credit per account, before and after 6 September** (sample data: query-app)

```sql
SELECT account, name, week1_debit, week1_credit, week2_debit, week2_credit
FROM (SELECT l.account, a.name,
             CASE WHEN l.entry_date < '2026-09-06' THEN 1 ELSE 2 END AS week,
             l.debit, l.credit
      FROM ledger l JOIN accounts a ON a.code = l.account) j
PIVOT (sum(debit) AS debit, sum(credit) AS credit FOR week IN (1 AS week1, 2 AS week2))
ORDER BY account;
```

Result:

| account (INT) | name (STRING) | week1_debit (DECIMAL(2)) | week1_credit (DECIMAL(2)) | week2_debit (DECIMAL(2)) | week2_credit (DECIMAL(2)) |
|---|---|---|---|---|---|
| 1000 | Cash | 30000.00 | 25000.00 | NULL | NULL |
| 1100 | Bank - City | 500000.00 | 288530.00 | 18850.00 | NULL |
| 1200 | Shares at cost | 257500.00 | NULL | NULL | 10300.00 |
| 2000 | Broker payable | 257500.00 | 257500.00 | NULL | NULL |
| 3000 | Owner capital | NULL | 500000.00 | NULL | NULL |
| 4000 | Dividend income | NULL | NULL | NULL | 6250.00 |
| 4100 | Gain on sale | NULL | NULL | NULL | 2300.00 |
| 5000 | Broker commission | 1030.00 | NULL | NULL | NULL |
| 5100 | Office rent | 25000.00 | NULL | NULL | NULL |

(9 rows)

**Example: The same report the manual way (works today)** (sample data: query-app)

```sql
SELECT a.name,
       sum_if(l.debit, l.entry_date < '2026-09-06') AS debit_week1,
       sum_if(l.debit, l.entry_date >= '2026-09-06') AS debit_week2,
       sum_if(l.credit, l.entry_date < '2026-09-06') AS credit_week1,
       sum_if(l.credit, l.entry_date >= '2026-09-06') AS credit_week2
FROM ledger l JOIN accounts a ON a.code = l.account
GROUP BY a.name
ORDER BY a.name;
```

Result:

| name (STRING) | debit_week1 (DECIMAL(2)) | debit_week2 (DECIMAL(2)) | credit_week1 (DECIMAL(2)) | credit_week2 (DECIMAL(2)) |
|---|---|---|---|---|
| Bank - City | 500000.00 | 18850.00 | 288530.00 | NULL |
| Broker commission | 1030.00 | NULL | NULL | NULL |
| Broker payable | 257500.00 | NULL | 257500.00 | NULL |
| Cash | 30000.00 | NULL | 25000.00 | NULL |
| Dividend income | NULL | NULL | NULL | 6250.00 |
| Gain on sale | NULL | NULL | NULL | 2300.00 |
| Office rent | 25000.00 | NULL | NULL | NULL |
| Owner capital | NULL | NULL | 500000.00 | NULL |
| Shares at cost | 257500.00 | NULL | NULL | 10300.00 |

(9 rows)

**Example: FOR and the column are needed** (sample data: sample; shows an error)

```sql
SELECT * FROM trade_log PIVOT (sum(amount) IN ('CITY'));
```

Result:

Error: `line 1, column 55: expected FOR and the column to spread out, as in PIVOT (sum(turnover) FOR month IN (1, 2)), but found ')'`

**Example: A source can have only one PIVOT** (sample data: sample; shows an error)

```sql
SELECT *
FROM trade_log PIVOT (sum(amount) FOR symbol IN ('CITY')) f
PIVOT (sum(amount) FOR symbol IN ('COAST'));
```

Result:

Error: `line 3, column 1: a source can have only one PIVOT`
