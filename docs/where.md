# WHERE

> Keep only the rows you want, with comparisons, IN, BETWEEN, LIKE, IS NULL and time ranges.

- Category: Querying
- Keywords: filter, condition, rows, AND, OR, NOT, , , !, \<\>, \<, \<, \>, \>, BETWEEN, NOT BETWEEN, IN, NOT IN, time IN, interval, LIKE, NOT LIKE, %, \_, escape, ILIKE, NOT ILIKE, IS NULL, IS NOT NULL, NULL, row comparison, tuple IN, (a, b) IN, composite key, IN VALUES, keyset paging, seek paging, fast conditions, column engine, row engine, where, like, ilike, SIMILAR TO, NOT SIMILAR TO, similar to, similar\_to\_escape, between
- See also: [SELECT](select.md), [Operators](operators.md), [ORDER BY, LIMIT, OFFSET (paging)](order-by-limit.md#paging), [Time and time zones](time-and-time-zones.md), [Conditional and NULL functions](functions-conditional.md), [Regular expressions](functions-regex.md)

`WHERE` keeps the rows where the condition is **true**. Rows where it is false or `NULL` are left out.

On a time-series table, a condition on the time column (like `time IN '2026-09'`) also makes the query fast: KarelaDB does not read the other partitions (files). A condition like `symbol = 'CITY'` lets KarelaDB jump straight to that symbol's rows. Some shapes of condition are much faster than others: see [fast conditions](where.md#fast-conditions).

**Example: CITY and VOLT closes above 190 in September 2026** (sample data: sample)

```sql
SELECT time, symbol, close
FROM ochl_day
WHERE symbol IN ('CITY', 'VOLT') AND close > 190 AND time IN '2026-09'
ORDER BY time, symbol
LIMIT 5;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-01T00:00:00.000Z | CITY | 502.4 |
| 2026-09-02T00:00:00.000Z | CITY | 496.4 |
| 2026-09-03T00:00:00.000Z | CITY | 497.9 |
| 2026-09-06T00:00:00.000Z | CITY | 499 |
| 2026-09-07T00:00:00.000Z | CITY | 498.7 |

(5 rows)

<a id="where"></a>

## WHERE

Syntax:

```sql
SELECT ... FROM ... WHERE condition
UPDATE table SET ... WHERE condition
DELETE FROM table WHERE condition
```

The condition is an expression that gives `true` or `false`. You can use columns of every table in `FROM` and `JOIN`, functions, and [subqueries](union-subqueries.md).

- **Returns:** only the rows where the condition is `true`.
- **NULL:** a condition that gives `NULL` counts as false (see [NULL in WHERE](where.md#null-in-where)).
- **Notes:** `WHERE` runs before `GROUP BY`, `SAMPLE BY` and window functions. To filter groups, use [HAVING](group-by.md#having).
- A select alias cannot be used in `WHERE`. Write the expression again.
- The condition must be true or false: `WHERE close` is an error.
- Aggregates like `count(*)` cannot be used in `WHERE`.

**Example: Pro users of the app** (sample data: query-app)

```sql
SELECT id, username, city
FROM app_users
WHERE plan = 'pro';
```

Result:

| id (INT) | username (STRING) | city (STRING) |
|---|---|---|
| 1 | ram | Kathmandu |
| 4 | gita | Dharan |
| 7 | suman | Pokhara |

(3 rows)

**Example: Ledger lines of the bank account in the first week of September** (sample data: query-app)

```sql
SELECT entry_date, debit, credit, memo
FROM ledger
WHERE account = 1100 AND entry_date >= '2026-09-01' AND entry_date < '2026-09-08'
ORDER BY line_id;
```

Result:

| entry_date (TIMESTAMP) | debit (DECIMAL(2)) | credit (DECIMAL(2)) | memo (STRING) |
|---|---|---|---|
| 2026-09-01T00:00:00.000Z | 500000.00 | NULL | Owner puts money in the bank |
| 2026-09-03T00:00:00.000Z | NULL | 257500.00 | Pay the broker |
| 2026-09-03T00:00:00.000Z | NULL | 1030.00 | Commission on the CITY buy |
| 2026-09-04T00:00:00.000Z | NULL | 30000.00 | Take cash from the bank |

(4 rows)

**Example: Forum posts written by sita** (sample data: content-forum)

```sql
SELECT id, thread_id, body
FROM posts
WHERE author = 'sita';
```

Result:

| id (LONG) | thread_id (LONG) | body (STRING) |
|---|---|---|
| 2 | 1 | I agree, the profit grew 18%. |
| 6 | 1 | सिटी बैंकको नाफा राम्रो छ। |

(2 rows)

**Example: The condition must be true or false** (sample data: sample; shows an error)

```sql
SELECT symbol FROM ochl_day WHERE close;
```

Result:

Error: `line 1, column 35: a condition must be true or false, got '542.2'`

**Example: An alias is not known in WHERE** (sample data: sample; shows an error)

```sql
SELECT symbol, close - open AS change FROM ochl_day WHERE change > 0;
```

Result:

Error: `line 1, column 59: unknown column 'change' (table 'ochl_day' has: time symbol open high low close volume)`

<a id="and-or-not"></a>

## AND, OR, NOT

Syntax:

```sql
condition AND condition
condition OR condition
NOT condition
```

| Operator | True when |
|---|---|
| `a AND b` | both are true |
| `a OR b` | at least one is true |
| `NOT a` | `a` is false |

- **NULL:** `true OR NULL` is `true`, `false AND NULL` is `false`. Other mixes with `NULL` give `NULL` (and the row is left out).
- **Notes:** `NOT` binds tighter than `AND`, and `AND` binds tighter than `OR`. So `a OR b AND c` means `a OR (b AND c)`. Use `( )` whenever you mix `AND` and `OR`.
- Both sides must be true or false: `1 AND 2` is an error.

**Example: Without ( ): the price and the day apply only to COAST, so CITY rows of every day come back** (sample data: sample)

```sql
SELECT time, symbol, close
FROM ochl_day
WHERE symbol = 'CITY' OR symbol = 'COAST' AND close > 400
  AND time IN '2026-09-10'
LIMIT 4;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2025-12-28T00:00:00.000Z | CITY | 542.2 |
| 2025-12-29T00:00:00.000Z | CITY | 539.7 |
| 2025-12-30T00:00:00.000Z | CITY | 539.3 |
| 2025-12-31T00:00:00.000Z | CITY | 542.4 |

(4 rows)

**Example: The same with ( ): now the time and price apply to both symbols** (sample data: sample)

```sql
SELECT time, symbol, close
FROM ochl_day
WHERE (symbol = 'CITY' OR symbol = 'COAST') AND close > 400
  AND time IN '2026-09-10';
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.9 |

(1 row)

**Example: Trades where broker 58 was the buyer or the seller, but not with broker 1** (sample data: sample)

```sql
SELECT transaction_id, symbol, buyer, seller, quantity
FROM trade_log
WHERE (buyer = 58 OR seller = 58) AND NOT (buyer = 1 OR seller = 1);
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | buyer (INT) | seller (INT) | quantity (LONG) |
|---|---|---|---|---|
| 100006 | COAST | 58 | 45 | 200 |
| 100001 | TELCO | 58 | 34 | 1000 |
| 100030 | CITY | 45 | 58 | 20 |
| 100019 | COAST | 58 | 34 | 10 |
| 100031 | COAST | 45 | 58 | 1000 |
| 100012 | VOLT | 58 | 45 | 200 |

(6 rows)

**Example** (sample data: sample)

```sql
SELECT TRUE AND NULL AS a, FALSE AND NULL AS b, TRUE OR NULL AS c, FALSE OR NULL AS d, NOT NULL AS e;
```

Result:

| a (STRING) | b (BOOL) | c (BOOL) | d (STRING) | e (STRING) |
|---|---|---|---|---|
| NULL | false | true | NULL | NULL |

(1 row)

<a id="comparison"></a>

## =, ==, !=, <>, <, <=, >, >=

Syntax:

```sql
a = b     a == b
a != b    a <> b
a < b     a <= b     a > b     a >= b
```

Compare two values. `==` is the same as `=`, and `<>` is the same as `!=`.

| Left | Right | How they are compared |
|---|---|---|
| number | number | by value (`5 = 5.0` is true) |
| text | text | letter by letter, by byte: capital letters come before small letters, and case matters |
| TIMESTAMP or DATE | text | the text is read as a time: `time >= '2026-09-01'` |
| number | text that is a number | as numbers: `id = '34'` is true for 34 |
| text | text that is not a number, with a number | error `cannot compare` |

- **Returns:** `true` or `false`.
- **NULL:** `NULL` on either side gives `NULL`. Even `NULL = NULL` is `NULL`. Use [IS NULL](where.md#is-null).
- **Notes:** a time text without a zone is **UTC**. For a local time add its offset, for example `+05:45`: `time >= '2026-09-10T11:00:00+05:45'`. See [time text](time-and-time-zones.md#time-text).
- A time text must be `YYYY-MM-DD` with two digits: `'2026-9-1'` is an error.

**Example: The first 5 minutes after the market opened (11:00 Nepal time)** (sample data: sample)

```sql
SELECT time, symbol, close
FROM ochl_minutes
WHERE symbol = 'CITY'
  AND time >= '2026-09-10T11:00:00+05:45'
  AND time <  '2026-09-10T11:05:00+05:45';
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | CITY | 504.4 |
| 2026-09-10T05:16:00.000Z | CITY | 504.6 |
| 2026-09-10T05:17:00.000Z | CITY | 504.2 |
| 2026-09-10T05:18:00.000Z | CITY | 504.4 |
| 2026-09-10T05:19:00.000Z | CITY | 504.5 |

(5 rows)

**Example: Big trades: 1000 shares or more** (sample data: sample)

```sql
SELECT transaction_id, symbol, quantity, rate FROM trade_log WHERE quantity >= 1000;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | quantity (LONG) | rate (DOUBLE) |
|---|---|---|---|
| 100001 | TELCO | 1000 | 881 |
| 100007 | TELCO | 1000 | 879 |
| 100015 | COAST | 1000 | 398 |
| 100031 | COAST | 1000 | 402 |

(4 rows)

**Example** (sample data: sample)

```sql
SELECT 5 = 5.0 AS a, 5 == 5 AS b, 'CITY' <> 'city' AS c, 'B' < 'a' AS d, 34 = '34' AS e;
```

Result:

| a (BOOL) | b (BOOL) | c (BOOL) | d (BOOL) | e (BOOL) |
|---|---|---|---|---|
| true | true | true | true | true |

(1 row)

**Example: Text that is not a number cannot be compared with a number** (sample data: sample; shows an error)

```sql
SELECT * FROM brokers WHERE name = 58;
```

Result:

Error: `line 1, column 34: cannot compare STRING 'Keystone Securities' with LONG '58'`

**Example: A time must be written YYYY-MM-DD** (sample data: sample; shows an error)

```sql
SELECT time, close FROM ochl_day WHERE time >= '2026-9-1';
```

Result:

Error: `line 1, column 45: cannot compare TIMESTAMP '2025-12-28T00:00:00.000Z' with STRING '2026-9-1'`

<a id="between"></a>

## BETWEEN, NOT BETWEEN

Syntax:

```sql
value [NOT] BETWEEN low AND high
```

`x BETWEEN a AND b` is the same as `x >= a AND x <= b`. **Both ends are included.**

| Argument | Type | Meaning |
|---|---|---|
| `value` | number, text or time | the value to test |
| `low`, `high` | the same kind | the smallest and the biggest allowed value |

- **Returns:** `true` or `false`. `NOT BETWEEN` gives the opposite.
- **NULL:** `NULL` when any of the three values is `NULL`.
- **Notes:** for times, `BETWEEN '2026-09-07' AND '2026-09-09'` stops at `2026-09-09T00:00:00`: the rest of 9 September is **not** included. For whole days use `time >= '2026-09-07' AND time < '2026-09-10'`, or [time IN](where.md#in-interval).

**Example: Days when COAST closed between 375 and 380** (sample data: sample)

```sql
SELECT time, close FROM ochl_day
WHERE symbol = 'COAST' AND close BETWEEN 375 AND 380;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) |
|---|---|
| 2026-08-25T00:00:00.000Z | 379.8 |
| 2026-09-06T00:00:00.000Z | 375.4 |
| 2026-09-07T00:00:00.000Z | 379.2 |
| 2026-09-08T00:00:00.000Z | 377.2 |
| 2026-09-10T00:00:00.000Z | 376.1 |

(5 rows)

**Example: BETWEEN with times: the end is the start of the last day** (sample data: sample)

```sql
SELECT time, symbol, close FROM ochl_day
WHERE symbol = 'VOLT' AND time BETWEEN '2026-09-07' AND '2026-09-09';
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-07T00:00:00.000Z | VOLT | 176.9 |
| 2026-09-08T00:00:00.000Z | VOLT | 182.4 |
| 2026-09-09T00:00:00.000Z | VOLT | 187.3 |

(3 rows)

**Example: Minutes where CITY was outside its normal band** (sample data: sample)

```sql
SELECT time, close FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10' AND close NOT BETWEEN 501 AND 507;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) |
|---|---|
| 2026-09-10T06:57:00.000Z | 500.9 |

(1 row)

<a id="in-list"></a>

## IN (list), NOT IN (list)

Syntax:

```sql
value [NOT] IN (value, value, ...)
value [NOT] IN (SELECT ...)
```

True when the value is equal to one of the values in the list. For a list from a query, see [IN (SELECT ...)](union-subqueries.md#in-subquery).

- **Returns:** `true` or `false`.
- **NULL:** `NULL` when the value is `NULL`. When the value is not found and the list has a `NULL`, the result is `NULL`, not `false`. So `x NOT IN (1, NULL)` is never true: keep `NULL` out of `NOT IN` lists.
- **Notes:** `symbol IN ('CITY', 'COAST')` on a time-series table reads only those symbols' rows (fast).
- `IN 'text'` without `( )` is a [time range](where.md#in-interval), not a list.

**Example: Banks only** (sample data: sample)

```sql
SELECT symbol, name FROM securities WHERE symbol IN ('CITY', 'COAST');
```

Result:

| symbol (SYMBOL) | name (STRING) |
|---|---|
| CITY | City Bank Limited |
| COAST | Coastal Bank Limited |

(2 rows)

**Example: Journal lines that are not income or expense** (sample data: query-app)

```sql
SELECT line_id, account, debit, credit FROM ledger
WHERE account NOT IN (4000, 4100, 5000, 5100) AND entry_id >= 7;
```

Result:

| line_id (INT) | account (INT) | debit (DECIMAL(2)) | credit (DECIMAL(2)) |
|---|---|---|---|
| 13 | 1100 | 6250.00 | NULL |
| 15 | 1100 | 12600.00 | NULL |
| 16 | 1200 | NULL | 10300.00 |

(3 rows)

**Example: NULL in the list** (sample data: sample)

```sql
SELECT 1 IN (1, NULL) AS found, 2 IN (1, NULL) AS not_found, 2 NOT IN (1, NULL) AS not_in;
```

Result:

| found (BOOL) | not_found (STRING) | not_in (STRING) |
|---|---|---|
| true | NULL | NULL |

(1 row)

**Example: A list needs ( )** (sample data: sample; shows an error)

```sql
SELECT * FROM securities WHERE symbol IN 'CITY';
```

Result:

Error: `line 1, column 42: expected a time interval string such as '2026-09', '2026-09-11T10:00' or '2026-09-11;1d' after IN (for a list of values write IN ('a', 'b')) but found 'CITY'`

<a id="in-interval"></a>

## time IN 'interval'

Syntax:

```sql
time_column [NOT] IN 'YYYY'
time_column [NOT] IN 'YYYY-MM'
time_column [NOT] IN 'YYYY-MM-DD'
time_column [NOT] IN 'YYYY-MM-DDTHH[:MM[:SS]]'
time_column [NOT] IN 'text+05:45'
time_column [NOT] IN 'text' TIME ZONE 'zone'
time_column [NOT] IN 'text;stretch'
time_column [NOT] IN 'text;stretch;period;count'
time_column [NOT] IN today() | yesterday() | tomorrow() | interval(from, to)
```

A text after `IN` (without `( )`) means **the whole period** that the text names: a year, a month, a day, an hour, a minute or a second.

| Written | Rows from | Up to (not included) |
|---|---|---|
| `time IN '2026'` | 2026-01-01 00:00 UTC | 2027-01-01 00:00 UTC |
| `time IN '2026-09'` | 2026-09-01 00:00 UTC | 2026-10-01 00:00 UTC |
| `time IN '2026-09-10'` | 2026-09-10 00:00 UTC | 2026-09-11 00:00 UTC |
| `time IN '2026-09-10T11'` | 11:00 UTC | 12:00 UTC |
| `time IN '2026-09-10+05:45'` | 2026-09-10 00:00 Nepal time (09-09 18:15 UTC) | 2026-09-11 00:00 Nepal time |
| `time IN '2026-09-10T11+05:45'` | 11:00 Nepal time | 12:00 Nepal time |
| `time IN '2026-09-10' TIME ZONE 'Asia/Kathmandu'` | 2026-09-10 00:00 Nepal time | 2026-09-11 00:00 Nepal time |
| `time IN '2026-09' TIME ZONE 'Asia/Kathmandu'` | 1 September 00:00 Nepal time | 1 October 00:00 Nepal time |

- **Returns:** `true` or `false`. `NOT IN` gives the opposite.
- **NULL:** a `NULL` time gives `NULL`.
- **Notes:** without a zone, the period is in **UTC**. The whole trading day of the sample data (05:15 to 09:15 UTC) is inside one UTC day, so `time IN '2026-09-10'` is fine for market data. For a Nepal calendar day (daily bars stored at Nepal midnight) add `TIME ZONE 'Asia/Kathmandu'`, or `+05:45` in the text. Not both: text with its own offset and TIME ZONE is an error.
- `TIME ZONE` takes the same [zone names](time-and-time-zones.md#time-zone-names) as SAMPLE BY. On a `DATE` column it changes nothing: a date is already a calendar day.
- On the time column of a time-series table, KarelaDB reads only the partitions of that period.
- The left side must be a `TIMESTAMP` or `DATE`.
- QuestDB's longer forms with `;` and `today()` work too: see [interval lists](where.md#interval-lists).
- More: [times and time zones](time-and-time-zones.md#in-interval).

**Example: All daily candles of September 2026, per symbol** (sample data: sample)

```sql
SELECT symbol, count(*) AS days, min(low) AS lowest, max(high) AS highest
FROM ochl_day
WHERE time IN '2026-09'
GROUP BY symbol;
```

Result:

| symbol (SYMBOL) | days (LONG) | lowest (DOUBLE) | highest (DOUBLE) |
|---|---|---|---|
| CITY | 8 | 494.1 | 512.4 |
| COAST | 8 | 364.1 | 398.8 |
| VOLT | 8 | 167.3 | 192.1 |

(3 rows)

**Example: The 12:00 Nepal hour of CITY on 2026-09-10** (sample data: sample)

```sql
SELECT count(*) AS minutes, min(time) AS first_minute, max(time) AS last_minute
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10T12+05:45';
```

Result:

| minutes (LONG) | first_minute (TIMESTAMP) | last_minute (TIMESTAMP) |
|---|---|---|
| 60 | 2026-09-10T06:15:00.000Z | 2026-09-10T07:14:00.000Z |

(1 row)

**Example: Users who joined in September by Nepal date** (sample data: query-app)

```sql
SELECT username, created_at
FROM app_users
WHERE created_at IN '2026-09+05:45';
```

Result:

| username (STRING) | created_at (TIMESTAMP) |
|---|---|
| test_user | 2026-08-31T18:15:00.000Z |

(1 row)

**Example: Everything except 2026** (sample data: sample)

```sql
SELECT count(*) AS old_rows FROM ochl_day WHERE time NOT IN '2026';
```

Result:

| old_rows (LONG) |
|---|
| 12 |

(1 row)

**Example: Only times can be IN a period** (sample data: sample; shows an error)

```sql
SELECT * FROM ochl_day WHERE symbol IN '2026';
```

Result:

Error: `line 1, column 37: IN '...' needs a time or date on the left`

<a id="interval-lists"></a>

## Interval lists, today() and DECLARE

Syntax:

```sql
time_column IN 'text;stretch'
time_column IN 'text;stretch;period;count'
time_column IN today() | yesterday() | tomorrow() | interval(from, to)
DECLARE @name := value [, @name := value ...] SELECT ... @name ...
```

The QuestDB forms of a time filter. Each part after a `;` is a count and a unit: `T` millisecond, `s` second, `m` minute, `h` hour, `d` day, `w` week, `M` month, `y` year.

| Written | Rows |
|---|---|
| `time IN '2026-09-10;1d'` | the day 2026-09-10 and one more day: to the end of 2026-09-11 |
| `time IN '2026-09-10T05:15;30m'` | 05:15 to the end of 05:45 |
| `time IN '2026-09-07T05:15;1h;1d;5'` | 05:15 to the end of 06:15, on five days in a row |
| `time IN '2026-09-01;1d;1w;4'` | two days at the start of four weeks in a row |
| `time IN today()` | today, 00:00 to 23:59:59.999 UTC |
| `time IN yesterday('Asia/Kathmandu')` | yesterday on the Nepal clock |
| `time IN interval('2026-09-10T05:15', '2026-09-10T06:00')` | from the first time to the second, both included |

- **Returns:** `true` or `false`. `NOT IN` gives the opposite.
- **Notes:**
  - The stretch moves the **end** later: the first part names a period, the stretch adds to its end.
  - `text;stretch;period;count` repeats the window `count` times, each one `period` after the one before. The count is at most 100,000.
  - On the time column of a time-series table, KarelaDB reads only the partitions that meet one of the windows, and skips the blocks in the gaps between them, as for a plain `time IN '2026-09-10'`.
  - `today()`, `yesterday()`, `tomorrow()` and `interval()` are worked out once, when the query starts. The value after `IN` must be the same for every row: `time IN interval(time, time)` is an error.
  - `TIME ZONE` goes with a text only. Give `today()` the zone instead: `today('Asia/Kathmandu')`.
  - `DECLARE @name := value` in front of a query sets a name for a value. Each `@name` in the query stands for that value, as if it were written there. A name holds only for its own statement.

**Example: A day and the day after, with ;1d** (sample data: sample)

```sql
SELECT symbol, count(*) AS days FROM ochl_day WHERE time IN '2026-09-09;1d' GROUP BY symbol ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | days (LONG) |
|---|---|
| CITY | 2 |
| COAST | 2 |
| VOLT | 2 |

(3 rows)

**Example: The first hour of trading on five days (05:15 to 06:15 UTC)** (sample data: sample)

```sql
SELECT timestamp_floor('1d', time) AS day, count(*) AS minutes, min(time) AS first_minute, max(time) AS last_minute
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-07T05:15;59m;1d;5'
GROUP BY timestamp_floor('1d', time)
ORDER BY day;
```

Result:

| day (TIMESTAMP) | minutes (LONG) | first_minute (TIMESTAMP) | last_minute (TIMESTAMP) |
|---|---|---|---|
| 2026-09-09T00:00:00.000Z | 60 | 2026-09-09T05:15:00.000Z | 2026-09-09T06:14:00.000Z |
| 2026-09-10T00:00:00.000Z | 60 | 2026-09-10T05:15:00.000Z | 2026-09-10T06:14:00.000Z |

(2 rows)

**Example: Today's live prices** (sample data: sample)

```sql
SELECT count(*) AS rows_today FROM live_data WHERE timestamp IN today();
```

Result:

| rows_today (LONG) |
|---|
| 0 |

(1 row)

**Example: interval(from, to): both ends are included** (sample data: sample)

```sql
SELECT count(*) AS minutes FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN interval('2026-09-10T05:15:00Z', '2026-09-10T05:19:00Z');
```

Result:

| minutes (LONG) |
|---|
| 5 |

(1 row)

**Example: DECLARE names a value for the query** (sample data: sample)

```sql
DECLARE @day := '2026-09-10', @sym := 'CITY'
SELECT symbol, close FROM ochl_day WHERE time IN @day AND symbol = @sym;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) |
|---|---|
| CITY | 504.9 |

(1 row)

**Example: A count is needed after a period** (sample data: sample; shows an error)

```sql
SELECT count(*) FROM ochl_day WHERE time IN '2026-09-10;1d;1d';
```

Result:

Error: `line 1, column 42: '2026-09-10;1d;1d' has a period but no count: write time;stretch;period;count, as in '2026-09-11T10:00;30m;1d;5'`

<a id="like"></a>

## LIKE, NOT LIKE

Syntax:

```sql
text [NOT] LIKE 'pattern'
```

Matches text with a simple pattern.

| In the pattern | Matches |
|---|---|
| `%` | any text, also empty text |
| `_` | exactly one character (also one letter of another language, like Nepali) |
| `\%`, `\_`, `\\` | the character `%`, `_` or `\` itself |
| any other character | itself; **case matters** |

- **Returns:** `true` or `false`. `NOT LIKE` gives the opposite.
- **NULL:** `NULL` when the text or the pattern is `NULL`.
- **Notes:** the whole text must match: `'CITY' LIKE 'CIT'` is false, `'CITY' LIKE 'CIT%'` is true.
- A number or symbol on the left is compared as its text.
- For patterns that ignore case, use [ILIKE](where.md#ilike). For more power, use [regular expressions](functions-regex.md).

**Example: Securities with Bank in the name** (sample data: sample)

```sql
SELECT symbol, name FROM securities WHERE name LIKE '%Bank%';
```

Result:

| symbol (SYMBOL) | name (STRING) |
|---|---|
| CITY | City Bank Limited |
| COAST | Coastal Bank Limited |

(2 rows)

**Example: Gmail users (case matters: GITA.RAI@Gmail.com is not found)** (sample data: query-app)

```sql
SELECT username, email FROM app_users WHERE email LIKE '%@gmail.com';
```

Result:

| username (STRING) | email (STRING) |
|---|---|
| ram | ram.sharma@gmail.com |
| hari_99 | hari99@gmail.com |
| suman | suman.gurung@gmail.com |

(3 rows)

**Example: Usernames of exactly 4 characters** (sample data: query-app)

```sql
SELECT username FROM app_users WHERE username LIKE '____';
```

Result:

| username (STRING) |
|---|
| sita |
| gita |

(2 rows)

**Example: Posts that do not say CITY** (sample data: content-forum)

```sql
SELECT id, author, body FROM posts WHERE body NOT LIKE '%CITY%';
```

Result:

| id (LONG) | author (STRING) | body (STRING) |
|---|---|---|
| 2 | sita | I agree, the profit grew 18%. |
| 3 | hari | Price is high now. Wait for a dip. |
| 4 | gita | What about the bonus shares? |
| 5 | ram | Bonus is 10% this time. |
| 6 | sita | सिटी बैंकको नाफा राम्रो छ। |
| 7 | hari | Two hydro IPOs open next week. |
| 8 | gita | Which ones? |

(7 rows)

**Example: Usernames with a real _ in them: write \_** (sample data: query-app)

```sql
SELECT username FROM app_users WHERE username LIKE '%\_%';
```

Result:

| username (STRING) |
|---|
| hari_99 |
| test_user |

(2 rows)

**Example: A price of 100% or more in a note: \% is the % sign** (sample data: sample)

```sql
SELECT '100% up' LIKE '100\%%' AS a, '1000 up' LIKE '100\%%' AS b;
```

Result:

| a (BOOL) | b (BOOL) |
|---|---|
| true | false |

(1 row)

<a id="ilike"></a>

## ILIKE, NOT ILIKE

Syntax:

```sql
text [NOT] ILIKE 'pattern'
```

Like [LIKE](where.md#like), but English letters match in any case: `'City' ILIKE 'CIT%'` is true.

- **Returns:** `true` or `false`. `NOT ILIKE` gives the opposite.
- **NULL:** `NULL` when the text or the pattern is `NULL`.
- **Notes:** only the English letters A-Z are changed. Languages without upper and lower case (like Nepali) work the same as with `LIKE`.
- In PostgreSQL `ILIKE` works the same way.

**Example: Gmail users in any case** (sample data: query-app)

```sql
SELECT username, email FROM app_users WHERE email ILIKE '%@gmail.com';
```

Result:

| username (STRING) | email (STRING) |
|---|---|
| ram | ram.sharma@gmail.com |
| hari_99 | hari99@gmail.com |
| gita | GITA.RAI@Gmail.com |
| suman | suman.gurung@gmail.com |

(4 rows)

**Example: Search securities by a word the user typed** (sample data: sample)

```sql
SELECT symbol, name FROM securities WHERE name ILIKE '%hydro%' OR symbol ILIKE 'acme';
```

Result:

| symbol (SYMBOL) | name (STRING) |
|---|---|
| ACME | Acme Investment Company |
| VOLT | Volt River Hydropower Limited |

(2 rows)

**Example** (sample data: sample)

```sql
SELECT 'City' ILIKE 'CIT%' AS a, 'City' NOT ILIKE 'cit%' AS b, 'City' LIKE 'CIT%' AS c;
```

Result:

| a (BOOL) | b (BOOL) | c (BOOL) |
|---|---|---|
| true | false | false |

(1 row)

<a id="similar-to"></a>

## SIMILAR TO, NOT SIMILAR TO

Syntax:

```sql
text [NOT] SIMILAR TO 'pattern' [ESCAPE 'c']
```

A pattern between `LIKE` and a [regular expression](functions-regex.md). The **whole** text must match.

| In the pattern | Means |
|---|---|
| `%` | any text, also none |
| `_` | any one character |
| `a\|b` | `a` or `b` |
| `(...)` | a group |
| `*` `+` `?` `{2}` `{2,4}` | repeat the thing before |
| `[abc]` `[a-z]` | one of these characters |
| `.` `^` `$` | just the character |
| `\%` | a real `%` (`\` is the escape; `ESCAPE '#'` picks another one) |

- **Returns:** `true` or `false`. `NOT SIMILAR TO` gives the opposite.
- **NULL:** `NULL` when the text or the pattern is `NULL`.
- **Notes:** upper and lower case must match. It works like PostgreSQL's `SIMILAR TO`: KarelaDB turns the pattern into a regular expression (`similar_to_escape('a%')` shows it) and reads every row.

**Example: Codes that are two letters and then 2 to 4 digits** (sample data: sample)

```sql
SELECT code, code SIMILAR TO '[A-Z]{2}[0-9]{2,4}' AS ok
FROM (VALUES ('NP123'), ('N1234'), ('AB12'), ('AB12345')) AS c(code);
```

Result:

| code (STRING) | ok (BOOL) |
|---|---|
| NP123 | true |
| N1234 | false |
| AB12 | true |
| AB12345 | false |

(4 rows)

**Example: One word or another, anywhere in the text** (sample data: sample)

```sql
SELECT 'hydro power' SIMILAR TO '%(hydro|solar)%' AS a, 'wind' NOT SIMILAR TO '%(hydro|solar)%' AS b,
       '50%' SIMILAR TO '50#%' ESCAPE '#' AS c;
```

Result:

| a (BOOL) | b (BOOL) | c (BOOL) |
|---|---|---|
| true | true | true |

(1 row)

<a id="is-null"></a>

## IS NULL, IS NOT NULL

Syntax:

```sql
value IS NULL
value IS NOT NULL
```

`NULL` means "no value". `IS NULL` is true when there is no value. `IS NOT NULL` is true when there is one.

- **Returns:** always `true` or `false`, never `NULL`.
- **Notes:** `x = NULL` does **not** work: it is always `NULL`, so no row matches. Use `x IS NULL`.
- NaN ("not a number") in a `DOUBLE` or `FLOAT` column:
  - A NaN made by an expression (`CAST('NaN' AS DOUBLE)`, `'nan'::double`, a driver's NaN parameter) is stored as `NULL`, so `IS NULL` finds it. `0 / 0.0` is an error (division by zero).
  - The text `'NaN'` written straight into the column is stored as NaN. It is **not** `NULL`: find it with [is_nan(x)](functions-math.md#is_nan). See [DOUBLE](column-types.md#double).

**Example: Users who never logged in** (sample data: query-app)

```sql
SELECT id, username, created_at FROM app_users WHERE last_login IS NULL;
```

Result:

| id (INT) | username (STRING) | created_at (TIMESTAMP) |
|---|---|---|
| 3 | hari_99 | 2026-03-20T13:00:00.000Z |
| 8 | test_user | 2026-08-31T18:15:00.000Z |

(2 rows)

**Example: News about the whole market (no symbol)** (sample data: content-news)

```sql
SELECT id, title FROM news WHERE symbol IS NULL;
```

Result:

| id (LONG) | title (STRING) |
|---|---|
| 4 | Market index closes at 2,840 |

(1 row)

**Example: Credit lines of the ledger** (sample data: query-app)

```sql
SELECT line_id, account, credit, memo FROM ledger WHERE credit IS NOT NULL AND entry_id <= 3;
```

Result:

| line_id (INT) | account (INT) | credit (DECIMAL(2)) | memo (STRING) |
|---|---|---|---|
| 2 | 3000 | 500000.00 | Owner puts money in the bank |
| 4 | 2000 | 257500.00 | Buy 500 CITY at 515 |
| 6 | 1100 | 257500.00 | Pay the broker |

(3 rows)

**Example: = NULL finds nothing** (sample data: query-app)

```sql
SELECT count(*) AS with_equals FROM app_users WHERE last_login = NULL;
SELECT count(*) AS with_is_null FROM app_users WHERE last_login IS NULL;
```

Result:

`SELECT count(*) AS with_equals FROM app_users WHERE last_login = NULL`

| with_equals (LONG) |
|---|
| 0 |

(1 row)

`SELECT count(*) AS with_is_null FROM app_users WHERE last_login IS NULL`

| with_is_null (LONG) |
|---|
| 2 |

(1 row)

<a id="row-comparison"></a>

## Row comparison: (a, b) < (x, y)

Syntax:

```sql
(a, b, ...) = (x, y, ...)
(a, b, ...) != (x, y, ...)
(a, b, ...) < (x, y, ...)       also <=, >, >=
```

Compares lists of values in order, like words in a dictionary: first `a` with `x`; only when they are equal, `b` with `y`, and so on.

| Written | Means |
|---|---|
| `(a, b) < (x, y)` | `a < x OR (a = x AND b < y)` |
| `(a, b) <= (x, y)` | `a < x OR (a = x AND b <= y)` |
| `(a, b) = (x, y)` | `a = x AND b = y` |
| `(a, b) != (x, y)` | `a != x OR b != y` |

- **Returns:** `true` or `false` (or `NULL`, by the rules of `AND` and `OR`).
- **Notes:** both lists must have the same number of values. A list can be compared with another list, or looked up with [(a, b) IN](where.md#row-in).
- The main use is **keyset paging** (also called seek paging): to get the next page, ask for the rows **after the last row you showed**, in `ORDER BY` order. It stays fast on page 1000, unlike `OFFSET` (see [paging](order-by-limit.md#paging)).
- A list cannot hold a subquery or a window function.

**Example: Keyset paging of forum posts, newest first: page 1** (sample data: content-forum)

```sql
SELECT id, author, created_at FROM posts
ORDER BY created_at DESC, id DESC
LIMIT 3;
```

Result:

| id (LONG) | author (STRING) | created_at (TIMESTAMP) |
|---|---|---|
| 8 | gita | 2026-09-02T03:25:00.000Z |
| 7 | hari | 2026-09-02T03:15:00.000Z |
| 6 | sita | 2026-09-01T06:15:00.000Z |

(3 rows)

**Example: Page 2: the rows after the last row of page 1 (post 6)** (sample data: content-forum)

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

**Example: Daily candles after (CITY, 2026-09-08), in symbol and time order** (sample data: sample)

```sql
SELECT symbol, time, close FROM ochl_day
WHERE (symbol, time) > ('CITY', '2026-09-08') AND time IN '2026-09'
ORDER BY symbol, time
LIMIT 4;
```

Result:

| symbol (SYMBOL) | time (TIMESTAMP) | close (DOUBLE) |
|---|---|---|
| CITY | 2026-09-09T00:00:00.000Z | 504.6 |
| CITY | 2026-09-10T00:00:00.000Z | 504.9 |
| COAST | 2026-09-01T00:00:00.000Z | 367.4 |
| COAST | 2026-09-02T00:00:00.000Z | 369.2 |

(4 rows)

**Example** (sample data: sample)

```sql
SELECT (2, 5) < (2, 7) AS a, (1, 'b') >= (1, 'a') AS b, (1, 2) = (1, 2) AS c, (1, NULL) = (1, 2) AS d;
```

Result:

| a (BOOL) | b (BOOL) | c (BOOL) | d (STRING) |
|---|---|---|---|
| true | true | true | NULL |

(1 row)

**Example: Both lists need the same number of values** (sample data: sample; shows an error)

```sql
SELECT symbol FROM ochl_day WHERE (symbol, time) < ('CITY', '2026-09-08', 1);
```

Result:

Error: `line 1, column 50: the two lists compared have 2 and 3 values; expected the same number`

<a id="row-in"></a>

## (a, b) IN a list of keys

Syntax:

```sql
(a, b, ...) [NOT] IN ((x1, y1, ...), (x2, y2, ...), ...)
(a, b, ...) [NOT] IN (VALUES (x1, y1, ...), (x2, y2, ...), ...)
(a, b, ...) [NOT] IN (SELECT x, y, ... FROM ...)
```

True when the values of the row are equal, **all together**, to one of the listed keys. `(symbol, time) IN (('CITY', '2026-09-10'), ('COAST', '2026-09-09'))` means `(symbol = 'CITY' AND time = '2026-09-10') OR (symbol = 'COAST' AND time = '2026-09-09')`.

- **Returns:** `true` or `false`. `NOT IN` gives the opposite.
- **NULL:** a key with a `NULL` that is not ruled out by another value is unknown: `('CITY', NULL)` never matches, and `NOT IN` a list holding it is never true for CITY rows.
- **Notes:**
  - Works in `SELECT`, `UPDATE` and `DELETE`. Every key must have as many values as the list; a subquery must give that many columns.
  - Fast for long key lists: when the list covers the table's first key columns (the `PRIMARY KEY`, or the `SORT BY` / `DEDUP KEY` of a time-series table), KarelaDB reads only those keys, and with the time column it reads only the partitions of those times. Deleting 200 `(symbol, time)` bars spread over a year reads their own partitions, not the whole year.
  - A subquery that uses columns of the outer query is not supported here; write `EXISTS (SELECT ... WHERE x = a AND y = b)`.

**Example: Two daily candles picked by (symbol, day)** (sample data: sample)

```sql
SELECT symbol, time, close FROM ochl_day
WHERE (symbol, time) IN (('CITY', '2026-09-10'), ('COAST', '2026-09-09'))
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | time (TIMESTAMP) | close (DOUBLE) |
|---|---|---|
| CITY | 2026-09-10T00:00:00.000Z | 504.9 |
| COAST | 2026-09-09T00:00:00.000Z | 380.1 |

(2 rows)

**Example: The same keys from a VALUES list and from a table** (sample data: sample)

Setup:

```sql
CREATE TABLE picks (symbol STRING, day TIMESTAMP);
INSERT INTO picks VALUES ('CITY', '2026-09-10'), ('COAST', '2026-09-09');
```

```sql
SELECT symbol, time, close FROM ochl_day WHERE (symbol, time) IN (VALUES ('CITY', '2026-09-10'), ('COAST', '2026-09-09')) ORDER BY symbol;
SELECT symbol, time, close FROM ochl_day WHERE (symbol, time) IN (SELECT symbol, day FROM picks) ORDER BY symbol;
EXPLAIN SELECT symbol, time, close FROM ochl_day WHERE (symbol, time) IN (('CITY', '2026-09-10'), ('COAST', '2026-09-09'));
```

Result:

`SELECT symbol, time, close FROM ochl_day WHERE (symbol, time) IN (('CITY', '2026-09-10'), ('COAST', `

| symbol (SYMBOL) | time (TIMESTAMP) | close (DOUBLE) |
|---|---|---|
| CITY | 2026-09-10T00:00:00.000Z | 504.9 |
| COAST | 2026-09-09T00:00:00.000Z | 380.1 |

(2 rows)

`SELECT symbol, time, close FROM ochl_day WHERE (symbol, time) IN (SELECT symbol, day FROM picks) ORD`

| symbol (SYMBOL) | time (TIMESTAMP) | close (DOUBLE) |
|---|---|---|
| CITY | 2026-09-10T00:00:00.000Z | 504.9 |
| COAST | 2026-09-09T00:00:00.000Z | 380.1 |

(2 rows)

`EXPLAIN SELECT symbol, time, close FROM ochl_day WHERE (symbol, time) IN (('CITY', '2026-09-10'), ('`

| plan (STRING) |
|---|
| scan table ochl_day (1 of 2 partitions, about 57 rows) |
| read only 2 key range(s) of each partition |
| build 3 of 7 stored column(s) per row: time, symbol, close |
| filter while scanning: 1 condition(s) |
| engine: row (a lookup of whole keys: a binary search per partition) |

(5 rows)

**Example: Every key needs as many values as the list** (sample data: sample; shows an error)

```sql
SELECT * FROM ochl_day WHERE (symbol, time) IN (('CITY'), ('COAST'));
```

Result:

Error: `line 1, column 50: expected a list of 2 values like (1, 'x') for each item of (a, b) IN (...), got 'CITY'`

<a id="null-in-where"></a>

## NULL in WHERE

`WHERE` keeps a row only when the condition is `true`. When the condition is `NULL` (unknown), the row is **left out**, the same as `false`.

This surprises people with `!=` and `NOT IN`: a row whose value is `NULL` is not "different from Kathmandu", it is unknown, so it is not shown.

- **Notes:** `HAVING` and the `ON` of a join treat `NULL` the same way.
- To keep `NULL` rows, say so: `city != 'Kathmandu' OR city IS NULL`, or use `coalesce(city, '') != 'Kathmandu'` (see [coalesce](functions-conditional.md)).

**Example: Users not in Kathmandu: the users without a city are missing** (sample data: query-app)

```sql
SELECT username, city FROM app_users WHERE city != 'Kathmandu';
```

Result:

| username (STRING) | city (STRING) |
|---|---|
| sita | Pokhara |
| gita | Dharan |
| bikash | Lalitpur |
| suman | Pokhara |

(4 rows)

**Example: Keep the NULL cities too** (sample data: query-app)

```sql
SELECT username, city FROM app_users WHERE city != 'Kathmandu' OR city IS NULL;
```

Result:

| username (STRING) | city (STRING) |
|---|---|
| sita | Pokhara |
| gita | Dharan |
| bikash | Lalitpur |
| anita | NULL |
| suman | Pokhara |
| test_user | NULL |

(6 rows)

**Example: The same with coalesce** (sample data: query-app)

```sql
SELECT username, coalesce(city, '(no city)') AS city FROM app_users WHERE coalesce(city, '') <> 'Kathmandu';
```

Result:

| username (STRING) | city (STRING) |
|---|---|
| sita | Pokhara |
| gita | Dharan |
| bikash | Lalitpur |
| anita | (no city) |
| suman | Pokhara |
| test_user | (no city) |

(6 rows)

<a id="fast-conditions"></a>

## Fast conditions

Syntax:

```sql
column op value [AND column op value ...]
```

KarelaDB runs a query in one of two ways. The **column engine** reads whole columns at a time, on all threads. The **row engine** looks at one row after another. The column engine is many times faster. It takes a query only when **every** part of the `WHERE` (the parts joined by `AND`) has one of these shapes:

| Shape | Example |
|---|---|
| a column against a value: `=`, `!=`, `<`, `<=`, `>`, `>=` | `close > 190`, `symbol = 'CITY'`, `time >= '2026-09-01'` |
| `[NOT] BETWEEN` two values | `close BETWEEN 375 AND 380` |
| `[NOT] IN` a list of values | `symbol IN ('CITY', 'COAST')` |
| `=` or `IN` on **one** column, joined by `OR` | `symbol = 'CITY' OR symbol = 'COAST'` (the same as an `IN` list) |
| `[NOT] LIKE`, `[NOT] ILIKE` on a `SYMBOL` or `STRING` column | `name LIKE '%Bank%'`, `symbol ILIKE 'c%'` |
| `time [NOT] IN 'period'` | `time IN '2026-09'` |
| `IS [NOT] NULL` | `last_login IS NULL` |
| a column against a column of the same kind | `close > open`, `buyer = seller` |
| `NOT`, `OR` and `AND` of the shapes above, nested any way | `NOT (volume <= 0 AND high = low AND open = close)`, `buyer = 58 OR seller = 58` |
| one member of a `JSON` column against text | `extra_data->>'category' = 'auth'` |

These send the whole query to the row engine. The result is the same, only slower:

| Shape | Example | Faster way |
|---|---|---|
| a function around the column | `upper(symbol) = 'CITY'`, `abs(close) > 1` | `symbol = 'CITY'` |
| math on the column | `close * 2 > 400`, `close - open > 5` | `close > 200`; keep the column alone on one side |
| `LIKE` on a number or time column | `quantity LIKE '1%'` | a range: `quantity >= 100 AND quantity < 200` |
| a `STRING` column against a number, or a `JSON` / `BYTES` column (other than `->>` against text) | `code = 34` on a text column of numbers | compare text with text: `code = '34'` |
| a column against a column of another kind | `quantity > rate` (`LONG` and `DOUBLE`) | |

- **Notes:**
  - A table with [computed columns](create-table.md) (`amount DOUBLE AS (...)`) always uses the row engine.
  - The column engine runs `GROUP BY` and aggregates, `LATEST ON`, `ORDER BY column LIMIT n`, and plain lists of columns. What else keeps a `GROUP BY` in it: see [GROUP BY with many groups](performance-tips.md#many-groups).
  - `LIKE 'CITY'` without `%` or `_` is the same as `= 'CITY'`: it also reads only CITY's rows.
  - Inside `NOT`, `OR` and `AND` a comparison with a `NULL` is still `NULL`, as on the row engine: `NOT (volume > 10)` does not keep a row whose `volume` is `NULL`. One shape the column engine cannot read anywhere in the tree (`NOT (close * 2 > 400)`) sends the query to the row engine.
  - Only a plain `OR` on one column (the same as an `IN` list) or a lone `symbol = ...` lets KarelaDB skip other symbols' partitions; an `OR` across columns reads them all, in the column engine.
  - `EXTRACT(YEAR FROM time) = 2026 AND EXTRACT(MONTH FROM time) = 8`, `year(time) = 2026` and `date_trunc('month', time) = '2026-08-01'` on a `TIMESTAMP` column are fast too: KarelaDB reads them as the time range they mean (in UTC), so only that month's partitions are read (EXPLAIN: `time range from the calendar condition(s)`). `EXTRACT(MONTH FROM time) = 8` alone, without a year, is not a range and uses the row engine, and so does a month or day that no date has (`0`, `13`): it keeps no row.
  - A condition on a number, `DATE` or `TIMESTAMP` column also lets KarelaDB skip partitions whose values are all outside it (see [zone maps](explain.md#zone-maps)).

**Example: Fast: every part is a column against a value** (sample data: sample)

```sql
SELECT time, symbol, close
FROM ochl_day
WHERE (symbol = 'CITY' OR symbol = 'COAST') AND close > 400 AND time IN '2026-09'
ORDER BY time, symbol
LIMIT 4;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-01T00:00:00.000Z | CITY | 502.4 |
| 2026-09-02T00:00:00.000Z | CITY | 496.4 |
| 2026-09-03T00:00:00.000Z | CITY | 497.9 |
| 2026-09-06T00:00:00.000Z | CITY | 499 |

(4 rows)

**Example: Fast too: a chart that leaves out empty bars with NOT ( ... AND ... )** (sample data: sample)

```sql
SELECT time, open, high, low, close, volume
FROM ochl_day
WHERE symbol = 'CITY' AND NOT (volume <= 0 AND high = low AND open = close)
ORDER BY time DESC
LIMIT 3;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-10T00:00:00.000Z | 504.6 | 507 | 500.7 | 504.9 | 183040 |
| 2026-09-09T00:00:00.000Z | 512 | 512.4 | 504 | 504.6 | 182390 |
| 2026-09-08T00:00:00.000Z | 498.2 | 501.1 | 497.5 | 497.5 | 34400 |

(3 rows)

**Example: Slow and fast ways to ask the same thing: the same rows either way** (sample data: sample)

```sql
SELECT count(*) AS slow FROM ochl_day WHERE upper(symbol) = 'CITY' AND close * 2 > 1000;
SELECT count(*) AS fast FROM ochl_day WHERE symbol = 'CITY' AND close > 500;
```

Result:

`SELECT count(*) AS slow FROM ochl_day WHERE upper(symbol) = 'CITY' AND close * 2 > 1000`

| slow (LONG) |
|---|
| 14 |

(1 row)

`SELECT count(*) AS fast FROM ochl_day WHERE symbol = 'CITY' AND close > 500`

| fast (LONG) |
|---|
| 14 |

(1 row)
