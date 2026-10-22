# ORDER BY, LIMIT, OFFSET

> Sort the result, and give back only the first rows or one page of rows.

- Category: Querying
- Keywords: sort, order, sorting, ORDER BY, ASC, DESC, ascending, descending, NULLS FIRST, NULLS LAST, NULLS, FIRST, LAST, LIMIT, OFFSET, top N, first rows, paging, pagination, page, next page, LIMIT a, b, order by, limit, offset, asc, desc, paging
- See also: [SELECT](select.md), [WHERE (row-comparison)](where.md#row-comparison), [GROUP BY and HAVING](group-by.md), [UNION and subqueries (union-all)](union-subqueries.md#union-all), [Window and series functions](functions-window.md), [EXPLAIN](explain.md)

`ORDER BY` sorts the rows of the result. `LIMIT` keeps only the first rows, and `OFFSET` skips rows before them.
They run **last**, after `WHERE`, `GROUP BY` and the select list, so they work on the final result.

Without `ORDER BY`, the order of the rows is not promised. Always add `ORDER BY` when the order matters (a "top 10", a page of posts, a report).

**Example: The 3 days with the biggest volume, then the next 3** (sample data: sample)

```sql
SELECT time, symbol, volume FROM ochl_day ORDER BY volume DESC LIMIT 3;
SELECT time, symbol, volume FROM ochl_day ORDER BY volume DESC LIMIT 3 OFFSET 3;
```

Result:

`SELECT time, symbol, volume FROM ochl_day ORDER BY volume DESC LIMIT 3`

| time (TIMESTAMP) | symbol (SYMBOL) | volume (DOUBLE) |
|---|---|---|
| 2026-09-09T00:00:00.000Z | COAST | 186330 |
| 2026-09-10T00:00:00.000Z | COAST | 186200 |
| 2026-09-10T00:00:00.000Z | CITY | 183040 |

(3 rows)

`SELECT time, symbol, volume FROM ochl_day ORDER BY volume DESC LIMIT 3 OFFSET 3`

| time (TIMESTAMP) | symbol (SYMBOL) | volume (DOUBLE) |
|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 182390 |
| 2026-08-31T00:00:00.000Z | CITY | 159240 |
| 2026-09-03T00:00:00.000Z | VOLT | 145930 |

(3 rows)

<a id="order-by"></a>

## ORDER BY

Syntax:

```sql
ORDER BY sort_key [ASC | DESC] [NULLS FIRST | NULLS LAST], ...
```

A `sort_key` can be:

| Sort key | Example | Meaning |
|---|---|---|
| an output column name or alias | `ORDER BY change_pct` | the value of that output column |
| a position | `ORDER BY 2` | the 2nd output column (counts from 1) |
| a table column | `ORDER BY volume` | also when it is not in the select list |
| an expression | `ORDER BY abs(close - open)` | the value of the expression for each row |

With many keys, the second key sorts rows that are equal in the first key, and so on.

- **Returns:** the same rows, sorted.
- **Notes:** text is sorted by its bytes: `'A'` comes before `'B'`, and **every capital letter comes before every small letter** (`'Z'` before `'a'`). This is PostgreSQL's `COLLATE "C"`. For dictionary order write `ORDER BY name COLLATE "en_US"` ([COLLATE](#collate)), or `ORDER BY lower(name)`.
- An alias can be used alone (`ORDER BY move`), but not inside an expression (`ORDER BY abs(move)` is an error in a query without `GROUP BY`): write the expression again.
- After `GROUP BY` or with aggregates, `ORDER BY` can only use the output columns (names, aliases, positions) and expressions of them, like `ORDER BY q / n`.
- After `UNION ALL`, `ORDER BY` can only use output column names or positions (see [UNION ALL](union-subqueries.md#union-all)).
- Rows that are equal in every key keep the order they came in. For stable pages, end with a unique column (like `id`).
- `ORDER BY ... LIMIT n` on a big table only keeps the best `n` rows while it reads, so it is fast. `ORDER BY time DESC LIMIT n` on a time-series table even stops early: it reads the newest rows first (see [LIMIT](performance-tips.md#limit)).

**Example: Top gainers of the day, sorted by an alias** (sample data: sample)

```sql
SELECT symbol, open, close, round((close - open) / open * 100, 2) AS change_pct
FROM ochl_day
WHERE time IN '2026-09-10'
ORDER BY change_pct DESC;
```

Result:

| symbol (SYMBOL) | open (DOUBLE) | close (DOUBLE) | change_pct (DOUBLE) |
|---|---|---|---|
| VOLT | 185.6 | 191.2 | 3.02 |
| CITY | 504.6 | 504.9 | 0.06 |
| COAST | 380.1 | 376.1 | -1.05 |

(3 rows)

**Example: Sector first, then symbol inside each sector** (sample data: sample)

```sql
SELECT sector, symbol, name FROM securities ORDER BY sector, symbol;
```

Result:

| sector (STRING) | symbol (SYMBOL) | name (STRING) |
|---|---|---|
| Banking | CITY | City Bank Limited |
| Banking | COAST | Coastal Bank Limited |
| Energy | VOLT | Volt River Hydropower Limited |
| Investment | ACME | Acme Investment Company |
| Telecom | TELCO | Northwind Telecom Limited |

(5 rows)

**Example: Sort by a column that is not shown, and by an expression** (sample data: sample)

```sql
SELECT symbol, close FROM ochl_day WHERE time IN '2026-09-10' ORDER BY abs(close - open) DESC;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) |
|---|---|
| VOLT | 191.2 |
| COAST | 376.1 |
| CITY | 504.9 |

(3 rows)

**Example: Newest news first** (sample data: content-news)

```sql
SELECT published_at, symbol, title FROM news ORDER BY published_at DESC LIMIT 3;
```

Result:

| published_at (TIMESTAMP) | symbol (STRING) | title (STRING) |
|---|---|---|
| 2026-09-02T03:15:00.000Z | COAST | Coastal Bank merger talks |
| 2026-09-01T02:15:00.000Z | NULL | Market index closes at 2,840 |
| 2026-08-15T04:15:00.000Z | VOLT | Hydropower company plans IPO |

(3 rows)

**Example: Sort by position: the 3rd column (type), then the 2nd (name)** (sample data: query-app)

```sql
SELECT code, name, type FROM accounts WHERE type IN ('income', 'expense') ORDER BY 3, 2;
```

Result:

| code (INT) | name (STRING) | type (STRING) |
|---|---|---|
| 5000 | Broker commission | expense |
| 5100 | Office rent | expense |
| 4000 | Dividend income | income |
| 4100 | Gain on sale | income |

(4 rows)

**Example: Capital letters come before small letters; lower() fixes it** (sample data: query-app)

```sql
SELECT email FROM app_users WHERE id IN (2, 4, 6) ORDER BY email;
SELECT email FROM app_users WHERE id IN (2, 4, 6) ORDER BY lower(email);
```

Result:

`SELECT email FROM app_users WHERE id IN (2, 4, 6) ORDER BY email`

| email (STRING) |
|---|
| GITA.RAI@Gmail.com |
| anita_m@hotmail.com |
| sita.k@yahoo.com |

(3 rows)

`SELECT email FROM app_users WHERE id IN (2, 4, 6) ORDER BY lower(email)`

| email (STRING) |
|---|
| anita_m@hotmail.com |
| GITA.RAI@Gmail.com |
| sita.k@yahoo.com |

(3 rows)

**Example: An alias inside an expression is not known** (sample data: sample; shows an error)

```sql
SELECT symbol, close - open AS move FROM ochl_day WHERE time IN '2026-09-10' ORDER BY abs(move);
```

Result:

Error: `line 1, column 91: unknown column 'move' (table 'ochl_day' has: time symbol open high low close volume)`

**Example: A position must be one of the columns** (sample data: sample; shows an error)

```sql
SELECT id, name FROM brokers ORDER BY 3;
```

Result:

Error: `line 1, column 39: ORDER BY 3: there are only 2 columns`

<a id="asc-desc"></a>

## ASC, DESC

Syntax:

```sql
ORDER BY sort_key ASC
ORDER BY sort_key DESC
```

`ASC` (ascending) sorts small to big: 1, 2, 3; A, B, C; old times first. It is the default.
`DESC` (descending) sorts big to small: 3, 2, 1; new times first.

- **Notes:** `ASC` or `DESC` belongs to one sort key. `ORDER BY a DESC, b` sorts `a` big first, and `b` small first.
- `DESC` also changes where `NULL` goes by default (see [NULLS FIRST, NULLS LAST](order-by-limit.md#nulls-first-last)).

**Example: Brokers by turnover, biggest first; equal turnover by id, smallest first** (sample data: sample)

```sql
SELECT buyer, sum(amount) AS turnover
FROM trade_log
WHERE date IN '2026-09-10'
GROUP BY buyer
ORDER BY turnover DESC, buyer ASC;
```

Result:

| buyer (INT) | turnover (DOUBLE) |
|---|---|
| 49 | 960370 |
| 45 | 695950 |
| 58 | 260190 |
| 1 | 239420 |
| 34 | 205450 |

(5 rows)

**Example: The last 3 minutes of COAST on 2026-09-10** (sample data: sample)

```sql
SELECT time, close, volume FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10'
ORDER BY time DESC
LIMIT 3;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|
| 2026-09-10T09:14:00.000Z | 376.1 | 1060 |
| 2026-09-10T09:13:00.000Z | 376.2 | 1320 |
| 2026-09-10T09:12:00.000Z | 376 | 1150 |

(3 rows)

<a id="collate"></a>

## COLLATE: dictionary order

Syntax:

```sql
sort_key COLLATE "name"
a COLLATE "name" = b      (also <, >, BETWEEN, IN)
```

`COLLATE` picks the order for one `ORDER BY` key or one comparison. Without it, text compares byte by byte.

| Name | Order | Example |
|---|---|---|
| `"C"`, `"POSIX"`, `"default"` | bytes (the same as no `COLLATE`) | `Apple, Zebra, apple` |
| `"en_US"`, `"en_US.utf8"`, `"und-x-icu"`, `"unicode"`, other language names | dictionary: letters first, case and accents only break ties | `apple, Apple, ěa, Zebra` |
| `nocase` | like the dictionary, and `'a' = 'A'` | `'apple' COLLATE nocase = 'APPLE'` is true |
| `natural` | like the dictionary, and digits compare as numbers | `file2, file10` |

- **Returns:** a comparison gives `true` or `false`; `ORDER BY` sorts. `SELECT name COLLATE "en_US"` gives `name` unchanged.
- **Notes:** every language name uses the same dictionary order (a letter with an accent sorts right after the plain letter). An unknown name is an error.
- In `ORDER BY`, write the column or expression with `COLLATE`, not an alias or a position.
- `COLLATE` after a column type in `CREATE TABLE` is still read and ignored: write it in the query.
- Sorting with `COLLATE` works out a sort key for every row, so it is slower than a plain `ORDER BY`.

**Example: Byte order, then dictionary order** (sample data: query-app)

```sql
SELECT email FROM app_users WHERE id IN (2, 4, 6) ORDER BY email;
SELECT email FROM app_users WHERE id IN (2, 4, 6) ORDER BY email COLLATE "en_US";
```

Result:

`SELECT email FROM app_users WHERE id IN (2, 4, 6) ORDER BY email`

| email (STRING) |
|---|
| GITA.RAI@Gmail.com |
| anita_m@hotmail.com |
| sita.k@yahoo.com |

(3 rows)

`SELECT email FROM app_users WHERE id IN (2, 4, 6) ORDER BY email COLLATE en_US`

| email (STRING) |
|---|
| anita_m@hotmail.com |
| GITA.RAI@Gmail.com |
| sita.k@yahoo.com |

(3 rows)

**Example: Case-insensitive match and natural order** (sample data: sample)

```sql
SELECT 'Zebra' < 'apple' AS bytes, 'Zebra' COLLATE "en_US" < 'apple' AS dictionary,
       'apple' COLLATE nocase = 'APPLE' AS same, 'file2' COLLATE natural < 'file10' AS natural;
```

Result:

| bytes (BOOL) | dictionary (BOOL) | same (BOOL) | natural (BOOL) |
|---|---|---|---|
| true | false | true | true |

(1 row)

**Example: An unknown collation** (sample data: sample; shows an error)

```sql
SELECT 'a' COLLATE klingon = 'a';
```

Result:

Error: `line 1, column 20: collation "klingon" does not exist; KarelaDB knows "C", "en_US" (and other language names), "nocase" and "natural"`

<a id="nulls-first-last"></a>

## NULLS FIRST, NULLS LAST

Syntax:

```sql
ORDER BY sort_key [ASC | DESC] NULLS FIRST
ORDER BY sort_key [ASC | DESC] NULLS LAST
```

Say where rows with a `NULL` sort key go: before all other rows (`NULLS FIRST`) or after them (`NULLS LAST`).

| Written | NULL rows go |
|---|---|
| `ORDER BY x` or `ORDER BY x ASC` | last (like `NULLS LAST`) |
| `ORDER BY x DESC` | first (like `NULLS FIRST`) |
| `ORDER BY x ... NULLS FIRST` | first |
| `ORDER BY x ... NULLS LAST` | last |

- **Notes:** the defaults are the same as in PostgreSQL: `NULL` counts as bigger than every value.
- A common case: "last login, newest first" should show users who never logged in at the end: `ORDER BY last_login DESC NULLS LAST`.

**Example: Recently active users first, never logged in last** (sample data: query-app)

```sql
SELECT username, last_login FROM app_users ORDER BY last_login DESC NULLS LAST;
```

Result:

| username (STRING) | last_login (TIMESTAMP) |
|---|---|
| bikash | 2026-09-11T04:20:00.000Z |
| gita | 2026-09-11T00:45:00.000Z |
| ram | 2026-09-10T14:30:00.000Z |
| suman | 2026-09-10T03:55:00.000Z |
| sita | 2026-09-09T02:15:00.000Z |
| anita | 2026-08-30T06:15:00.000Z |
| hari_99 | NULL |
| test_user | NULL |

(8 rows)

**Example: Without NULLS LAST, DESC puts NULL first** (sample data: query-app)

```sql
SELECT username, last_login FROM app_users ORDER BY last_login DESC LIMIT 3;
```

Result:

| username (STRING) | last_login (TIMESTAMP) |
|---|---|
| hari_99 | NULL |
| test_user | NULL |
| bikash | 2026-09-11T04:20:00.000Z |

(3 rows)

**Example: Securities without a close today at the top** (sample data: sample)

```sql
SELECT s.symbol, d.close
FROM securities s
LEFT JOIN ochl_day d ON d.symbol = s.symbol AND d.time IN '2026-09-10'
ORDER BY d.close NULLS FIRST;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) |
|---|---|
| ACME | NULL |
| TELCO | NULL |
| VOLT | 191.2 |
| COAST | 376.1 |
| CITY | 504.9 |

(5 rows)

**Example: NULLS needs FIRST or LAST** (sample data: sample; shows an error)

```sql
SELECT id FROM brokers ORDER BY id NULLS;
```

Result:

Error: `line 1, column 41: expected FIRST or LAST after NULLS but found ';'`

<a id="limit"></a>

## LIMIT

Syntax:

```sql
LIMIT n
LIMIT n OFFSET m
LIMIT ALL
LIMIT lo, hi
LIMIT -n
LIMIT -n, -m
FETCH FIRST n ROWS ONLY
```

Gives back at most `n` rows. With `ORDER BY`, these are the first `n` rows in that order (a "top n").

| Argument | Type | Meaning |
|---|---|---|
| `n` | whole number, 0 or more | the most rows to give back; `LIMIT 0` gives no rows (only the columns) |

- **Returns:** the first `n` rows, or fewer when there are fewer.
- **Notes:** `LIMIT` comes after `ORDER BY`, at the very end of the query. With `UNION ALL`, it works on all the rows together.
- `n` must be a plain number: not an expression, not negative.
- `LIMIT ALL` means no limit. The QuestDB form `LIMIT lo, hi` gives rows `lo + 1` to `hi`, so `LIMIT 10, 20` is the same as `LIMIT 10 OFFSET 10`. The standard `FETCH FIRST n ROWS ONLY` works too.
- `LIMIT -n` (QuestDB) gives the **last** `n` rows, still in their own order. On a time-series table these are the newest rows by time, and KarelaDB reads only the newest partitions to find them. `LIMIT -n, -m` gives the last `n` rows without the final `m`: `LIMIT -5, -2` is the 3 rows before the last 2. It cannot be used with `OFFSET` or `FOR UPDATE`.
- Server programs (`kareladb sql`, HTTP `/exec`) also cut very big results; see [limits](limits.md).

**Example: The 5 biggest trades of the trade log** (sample data: sample)

```sql
SELECT transaction_id, symbol, quantity, rate, amount FROM trade_log ORDER BY amount DESC LIMIT 5;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | quantity (LONG) | rate (DOUBLE) | amount (DOUBLE) |
|---|---|---|---|---|
| 100001 | TELCO | 1000 | 881 | 881000 |
| 100007 | TELCO | 1000 | 879 | 879000 |
| 100017 | TELCO | 500 | 881 | 440500 |
| 100031 | COAST | 1000 | 402 | 402000 |
| 100015 | COAST | 1000 | 398 | 398000 |

(5 rows)

**Example: Only the column names: LIMIT 0** (sample data: query-app)

```sql
SELECT * FROM app_users LIMIT 0;
```

Result:

| id (INT) | username (STRING) | email (STRING) | full_name (STRING) | city (STRING) | plan (STRING) | created_at (TIMESTAMP) | last_login (TIMESTAMP) |
|---|---|---|---|---|---|---|---|

(0 rows)

**Example: The newest post of the forum** (sample data: content-forum)

```sql
SELECT id, author, body, created_at FROM posts ORDER BY created_at DESC LIMIT 1;
```

Result:

| id (LONG) | author (STRING) | body (STRING) | created_at (TIMESTAMP) |
|---|---|---|---|
| 8 | gita | Which ones? | 2026-09-02T03:25:00.000Z |

(1 row)

**Example: LIMIT -n: the newest 3 daily candles of CITY, oldest first (QuestDB)** (sample data: sample)

```sql
SELECT time, symbol, close FROM ochl_day WHERE symbol = 'CITY' LIMIT -3;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 |

(3 rows)

**Example: LIMIT -n, -m: the last 5 rows without the final 2** (sample data: sample)

```sql
SELECT id FROM brokers ORDER BY id LIMIT -5, -2;
```

Result:

| id (INT) |
|---|
| 1 |
| 34 |
| 45 |

(3 rows)

**Example: LIMIT lo, hi gives the rows between them (QuestDB)** (sample data: sample)

```sql
SELECT id FROM brokers ORDER BY id LIMIT 2, 4;
SELECT id FROM brokers ORDER BY id LIMIT 2 OFFSET 2;
SELECT id FROM brokers ORDER BY id FETCH FIRST 2 ROWS ONLY;
```

Result:

`SELECT id FROM brokers ORDER BY id LIMIT 2 OFFSET 2`

| id (INT) |
|---|
| 45 |
| 49 |

(2 rows)

`SELECT id FROM brokers ORDER BY id LIMIT 2 OFFSET 2`

| id (INT) |
|---|
| 45 |
| 49 |

(2 rows)

`SELECT id FROM brokers ORDER BY id LIMIT 2`

| id (INT) |
|---|
| 1 |
| 34 |

(2 rows)

<a id="offset"></a>

## OFFSET

Syntax:

```sql
LIMIT n OFFSET m
```

Skips the first `m` rows, then gives back at most `n` rows.

| Argument | Type | Meaning |
|---|---|---|
| `m` | whole number, 0 or more | how many rows to skip |

- **Returns:** rows `m + 1` to `m + n`. When `m` is past the end, no rows.
- **Notes:** `OFFSET` may be written after `LIMIT`, or by itself (then there is no limit), or before `LIMIT` as PostgreSQL allows. `OFFSET m ROWS` is accepted too.
- KarelaDB still makes and sorts the skipped rows, so a big `OFFSET` is slow. See [paging](order-by-limit.md#paging).

**Example: Rows 4 to 6 by volume** (sample data: sample)

```sql
SELECT time, symbol, volume FROM ochl_day ORDER BY volume DESC LIMIT 3 OFFSET 3;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | volume (DOUBLE) |
|---|---|---|
| 2026-09-09T00:00:00.000Z | CITY | 182390 |
| 2026-08-31T00:00:00.000Z | CITY | 159240 |
| 2026-09-03T00:00:00.000Z | VOLT | 145930 |

(3 rows)

**Example: Past the end: no rows** (sample data: sample)

```sql
SELECT id, name FROM brokers ORDER BY id LIMIT 5 OFFSET 10;
```

Result:

| id (INT) | name (STRING) |
|---|---|

(0 rows)

**Example: OFFSET by itself: skip rows, keep the rest** (sample data: sample)

```sql
SELECT id, name FROM brokers ORDER BY id OFFSET 2;
```

Result:

| id (INT) | name (STRING) |
|---|---|
| 45 | Imperial Securities |
| 49 | Online Securities |
| 58 | Northgate Securities |

(3 rows)

<a id="paging"></a>

## Paging

Syntax:

```sql
-- page p (1, 2, 3, ...) with k rows per page:
ORDER BY key, unique_column LIMIT k OFFSET (p - 1) * k

-- keyset paging: the page after the last row shown
WHERE (key, unique_column) < (last_key, last_unique) ORDER BY key DESC, unique_column DESC LIMIT k
```

An app shows long lists one **page** at a time: 20 forum posts, then the next 20.

There are two ways:

| Way | How | Good | Not good |
|---|---|---|---|
| `LIMIT` + `OFFSET` | page 3 = `LIMIT 20 OFFSET 40` | simple; can jump to any page number | slow for deep pages; rows move between pages when new rows arrive |
| keyset paging | "the 20 rows after the last row I showed" with a [row comparison](where.md#row-comparison) | fast on every page; no rows are skipped or shown twice | only "next page" and "previous page" |

- **Notes:** the page order must be **unique**: add a unique column like `id` as the last sort key. Otherwise rows with equal keys can move from one page to another.
- For the offset, KarelaDB needs a whole number: compute `(p - 1) * k` in your program.

**Example: Forum posts, 3 per page: page 1** (sample data: content-forum)

```sql
SELECT id, author, created_at FROM posts ORDER BY created_at DESC, id DESC LIMIT 3 OFFSET 0;
```

Result:

| id (LONG) | author (STRING) | created_at (TIMESTAMP) |
|---|---|---|
| 8 | gita | 2026-09-02T03:25:00.000Z |
| 7 | hari | 2026-09-02T03:15:00.000Z |
| 6 | sita | 2026-09-01T06:15:00.000Z |

(3 rows)

**Example: Page 2** (sample data: content-forum)

```sql
SELECT id, author, created_at FROM posts ORDER BY created_at DESC, id DESC LIMIT 3 OFFSET 3;
```

Result:

| id (LONG) | author (STRING) | created_at (TIMESTAMP) |
|---|---|---|
| 5 | ram | 2026-09-01T05:45:00.000Z |
| 4 | gita | 2026-09-01T05:15:00.000Z |
| 3 | hari | 2026-09-01T04:35:00.000Z |

(3 rows)

**Example: Page 2 with keyset paging: after post 6, the last row of page 1** (sample data: content-forum)

```sql
SELECT id, author, created_at FROM posts
WHERE (created_at, id) < ('2026-09-01T12:00:00+05:45', 6)
ORDER BY created_at DESC, id DESC
LIMIT 3;
```

Result:

| id (LONG) | author (STRING) | created_at (TIMESTAMP) |
|---|---|---|
| 5 | ram | 2026-09-01T05:45:00.000Z |
| 4 | gita | 2026-09-01T05:15:00.000Z |
| 3 | hari | 2026-09-01T04:35:00.000Z |

(3 rows)

**Example: A ledger page for the accountant: 5 lines per page, page 2** (sample data: query-app)

```sql
SELECT line_id, entry_date, account, debit, credit, memo
FROM ledger
ORDER BY entry_date, line_id
LIMIT 5 OFFSET 5;
```

Result:

| line_id (INT) | entry_date (TIMESTAMP) | account (INT) | debit (DECIMAL(2)) | credit (DECIMAL(2)) | memo (STRING) |
|---|---|---|---|---|---|
| 6 | 2026-09-03T00:00:00.000Z | 1100 | NULL | 257500.00 | Pay the broker |
| 7 | 2026-09-03T00:00:00.000Z | 5000 | 1030.00 | NULL | Commission on the CITY buy |
| 8 | 2026-09-03T00:00:00.000Z | 1100 | NULL | 1030.00 | Commission on the CITY buy |
| 9 | 2026-09-04T00:00:00.000Z | 1000 | 30000.00 | NULL | Take cash from the bank |
| 10 | 2026-09-04T00:00:00.000Z | 1100 | NULL | 30000.00 | Take cash from the bank |

(5 rows)
