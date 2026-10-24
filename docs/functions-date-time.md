# Date and time functions

> Take a time apart, find the weekday, quarter and week, cut, add and build times, count days or months between times, fiscal years (also Nepal's), and write a time as text.

- Category: Functions — date and time
- Keywords: date, time, timestamp, UTC, milliseconds, weekday, weekday, trading day, holiday, truncate time, timestamp\_floor, timestamp floor, local midnight, start of month, start of week, add days, add months, date\_add, timestampadd, interval, month end, difference between dates, age, date\_diff, timestampdiff, format date, strftime, date\_format, format, time zone, timezone, Nepal time, NPT, Asia/Kathmandu, +05:45, 20700000, current\_timestamp, getdate, EXTRACT, datepart, date part, epoch, ISO week, week number, weekofyear, dayofyear, day of year, quarter of the year, end of month, EOMONTH, last day of month, build a date, date from parts, datefromparts, how old, time between, financial year, FY, fiscal year, Nepal fiscal year, Nepali fiscal year, Shrawan, Bikram Sambat, BS year, arthik barsa, to\_timezone, to\_utc, AT TIME ZONE, timestamp\_ceil, round up time, timestamp\_floor\_utc, time\_bucket, date\_bin, bucket, TimescaleDB, today, yesterday, tomorrow, interval\_start, interval\_end, days\_in\_month, is\_leap\_year, leap year, is\_end\_of\_month, day\_of\_week\_sunday\_first, millis, to\_pg\_date, sysdate, timestamp\_sequence, timestamp\_shuffle, QuestDB
- See also: [Conversion functions (to_timestamp)](functions-conversion.md#to_timestamp), [Conversion functions (cast)](functions-conversion.md#cast), [Time and time zones](time-and-time-zones.md), [SAMPLE BY](sample-by.md), [SAMPLE BY (time-zone)](sample-by.md#time-zone), [WHERE (in-interval)](where.md#in-interval), [Aggregate functions](functions-aggregate.md), [Finance and price functions](functions-finance.md)

KarelaDB keeps a `TIMESTAMP` as the number of **milliseconds** (1/1000 of a second) since 1970-01-01, in **UTC**. UTC is the world clock time with no time zone. A local time is UTC plus its zone offset: Nepal is `+05:45` (11:00 in Kathmandu is 05:15 UTC), New York is `-04:00` in summer (07:00 there is 11:00 UTC).

- Every function here works on the [session's time zone](time-and-time-zones.md#session-time-zone), which is **UTC** unless the session ran `SET TIME ZONE` or the server has `--timezone`. A time zone given in the call wins: [date_trunc](#date_trunc)`(unit, t, zone)`, [timestamp_floor](#timestamp_floor), [to_timezone and to_utc](#to_timezone), [to_char](#to_char)`(t, format, zone)`. `hour()` of 11:00 local time in Nepal is `5`. See [Local time](#nepal-time).
- A time argument can be a `TIMESTAMP`, a `DATE`, time text like `'2026-09-10T11:00:00+05:45'`, or a whole number (milliseconds since 1970).
- A `NULL` argument gives `NULL`.
- Text that is not a time is an error: `year('hello')`.
- `to_timestamp` and `to_date` change a value into a time: see [conversion functions](functions-conversion.md#to_timestamp).
- For reports: [date_part](#date_part) takes any part of a time, [quarter](#quarter) and [week_of_year](#week_of_year) group by quarter and week, [last_day](#last_day) finds the month end, and [fiscal_year](#fiscal_year) and [nepal_fiscal_year](#nepal_fiscal_year) group by financial year.

**Example: CITY volume per Nepal clock hour** (sample data: sample)

```sql
SELECT hour(time + 20700000) AS nepal_hour,
       count(*) AS candles,
       sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
GROUP BY hour(time + 20700000)
ORDER BY nepal_hour;
```

Result:

| nepal_hour (LONG) | candles (LONG) | volume (DOUBLE) |
|---|---|---|
| 11 | 60 | 47020 |
| 12 | 60 | 41230 |
| 13 | 60 | 46180 |
| 14 | 60 | 48610 |

(4 rows)

<a id="now"></a>

## now, systimestamp

Syntax:

```sql
now()
systimestamp()
```

The current time. `systimestamp` is the same function.

- **Returns:** `TIMESTAMP` (UTC).
- **NULL:** never `NULL`.
- **Notes:** the value is the same for the whole statement, so every row of one `SELECT` or `INSERT` gets the same time. As a column `DEFAULT now()`, a new row gets the time it was inserted. The PostgreSQL names `CURRENT_TIMESTAMP`, [current_date](#current_date), [localtimestamp](#localtimestamp), [transaction_timestamp](#transaction_timestamp), `statement_timestamp` and `clock_timestamp` give the same time, and so does QuestDB's [sysdate](#sysdate).

**Example**

```sql
SELECT now() > '2026-01-01' AS after_2026, now() = systimestamp() AS same_time, year(now()) >= 2026 AS year_ok;
```

Result:

| after_2026 (BOOL) | same_time (BOOL) | year_ok (BOOL) |
|---|---|---|
| true | true | true |

(1 row)

**Example: Save the login time of an app user**

Setup:

```sql
CREATE TABLE logins (user_id INT, logged_in_at TIMESTAMP DEFAULT now());
INSERT INTO logins (user_id) VALUES (7);
```

```sql
SELECT user_id, logged_in_at > '2026-01-01' AS has_time FROM logins;
```

Result:

| user_id (INT) | has_time (BOOL) |
|---|---|
| 7 | true |

(1 row)

**Example: The PostgreSQL names give the same time**

```sql
SELECT now() = current_timestamp AS same_1, now() = current_timestamp() AS same_2, now() = localtimestamp AS same_3;
```

Result:

| same_1 (BOOL) | same_2 (BOOL) | same_3 (BOOL) |
|---|---|---|
| true | true | true |

(1 row)

**Example: getdate is not KarelaDB SQL** (shows an error)

```sql
SELECT getdate();
```

Result:

Error: `line 1, column 8: unknown function 'getdate'`

## year

Syntax:

```sql
year(t)
```

The year of the UTC date: `year('2026-09-10')` is `2026`.

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

- **Returns:** `LONG`.
- **NULL:** `year(NULL)` is `NULL`.
- **Notes:** the date is the date on the [session's clock](time-and-time-zones.md#session-time-zone), UTC unless set. In a UTC session a time just after midnight in Nepal (before 05:45) still belongs to the day before; on 1 January that is even the year before.

**Example**

```sql
SELECT year('2026-09-10T08:30:15Z') AS a, year(CAST('2025-12-31' AS DATE)) AS b, year('2026-01-01T02:00:00+05:45') AS nepal_new_year, year(NULL) AS c;
```

Result:

| a (LONG) | b (LONG) | nepal_new_year (LONG) | c (STRING) |
|---|---|---|---|
| 2026 | 2025 | 2025 | NULL |

(1 row)

**Example: Average CITY close per year** (sample data: sample)

```sql
SELECT year(time) AS year, round(avg(close), 2) AS avg_close, count(*) AS days
FROM ochl_day
WHERE symbol = 'CITY'
GROUP BY year(time)
ORDER BY year;
```

Result:

| year (LONG) | avg_close (DOUBLE) | days (LONG) |
|---|---|---|
| 2025 | 540.9 | 4 |
| 2026 | 504.05 | 15 |

(2 rows)

**Example: Text that is not a full date** (shows an error)

```sql
SELECT year('2026-09');
```

Result:

Error: `line 1, column 8: year: argument 1 must be a time, got '2026-09'`

## month

Syntax:

```sql
month(t)
```

The month of the UTC date, from `1` (January) to `12` (December).

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

- **Returns:** `LONG`.
- **NULL:** `month(NULL)` is `NULL`.
- **Notes:** for the month name use [to_char](#to_char) with `Mon` or `Month`. For the first moment of the month use [date_trunc](#date_trunc)`('month', t)`.

**Example**

```sql
SELECT month('2026-09-10') AS a, month(CAST('2025-12-28' AS DATE)) AS b;
```

Result:

| a (LONG) | b (LONG) |
|---|---|
| 9 | 12 |

(1 row)

**Example: Month report: trading days and volume per symbol** (sample data: sample)

```sql
SELECT year(time) AS year, month(time) AS month, symbol,
       count(*) AS days, sum(volume) AS volume
FROM ochl_day
WHERE symbol IN ('CITY', 'VOLT')
GROUP BY year(time), month(time), symbol
ORDER BY year, month, symbol;
```

Result:

| year (LONG) | month (LONG) | symbol (SYMBOL) | days (LONG) | volume (DOUBLE) |
|---|---|---|---|---|
| 2025 | 12 | CITY | 4 | 255090 |
| 2025 | 12 | VOLT | 4 | 409650 |
| 2026 | 8 | CITY | 7 | 855550 |
| 2026 | 8 | VOLT | 7 | 677070 |
| 2026 | 9 | CITY | 8 | 876210 |
| 2026 | 9 | VOLT | 8 | 713310 |

(6 rows)

## day

Syntax:

```sql
day(t)
```

The day of the month of the UTC date, from `1` to `31`.

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

- **Returns:** `LONG`.
- **NULL:** `day(NULL)` is `NULL`.
- **Notes:** the UTC day and the Nepal day differ between 00:00 and 05:45 Nepal time. Add `20700000` ms (5 h 45 min) to get the Nepal day.

**Example**

```sql
SELECT day('2026-09-10T20:00:00Z') AS a, day('2026-09-02T02:30:00+05:45') AS utc_day, day(CAST('2026-09-02T02:30:00+05:45' AS TIMESTAMP) + 20700000) AS nepal_day;
```

Result:

| a (LONG) | utc_day (LONG) | nepal_day (LONG) |
|---|---|---|
| 10 | 1 | 2 |

(1 row)

**Example: App sign-ups per day: the UTC day and the Nepal day** (sample data: fn-dates)

```sql
SELECT day(created_at) AS utc_day, day(created_at + 20700000) AS nepal_day, count(*) AS signups
FROM signups
GROUP BY day(created_at), day(created_at + 20700000)
ORDER BY nepal_day, utc_day;
```

Result:

| utc_day (LONG) | nepal_day (LONG) | signups (LONG) |
|---|---|---|
| 1 | 1 | 3 |
| 1 | 2 | 1 |
| 2 | 2 | 1 |
| 3 | 3 | 3 |
| 4 | 4 | 1 |
| 6 | 6 | 1 |

(6 rows)

## hour

Syntax:

```sql
hour(t)
```

The hour of the UTC time, from `0` to `23`.

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

- **Returns:** `LONG`.
- **NULL:** `hour(NULL)` is `NULL`.
- **Notes:** UTC. `hour('2026-09-10T11:00:00+05:45')` is `5`, not `11`. Use `hour(time + 20700000)` for the Nepal clock hour (20700000 ms is 5 h 45 min; this is always right because Nepal has no summer time). A `DATE` has hour `0`. Text without a zone is read as UTC.

**Example**

```sql
SELECT hour('2026-09-10 11:00:00') AS no_zone_is_utc, hour('2026-09-10T11:00:00+05:45') AS nepal_11_in_utc, hour(CAST('2026-09-10T11:00:00+05:45' AS TIMESTAMP) + 20700000) AS nepal_hour;
```

Result:

| no_zone_is_utc (LONG) | nepal_11_in_utc (LONG) | nepal_hour (LONG) |
|---|---|---|
| 11 | 5 | 11 |

(1 row)

**Example: Forum posts per Nepal hour of the day** (sample data: fn-dates)

```sql
SELECT hour(created_at + 20700000) AS nepal_hour, count(*) AS posts
FROM forum_posts
GROUP BY hour(created_at + 20700000)
ORDER BY posts DESC, nepal_hour
LIMIT 5;
```

Result:

| nepal_hour (LONG) | posts (LONG) |
|---|---|
| 10 | 2 |
| 11 | 2 |
| 14 | 2 |
| 8 | 1 |
| 9 | 1 |

(5 rows)

## minute

Syntax:

```sql
minute(t)
```

The minute of the UTC time, from `0` to `59`.

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

- **Returns:** `LONG`.
- **NULL:** `minute(NULL)` is `NULL`.
- **Notes:** Nepal is 45 minutes off from a whole hour, so the minute changes too: 11:07 in Nepal is 05:22 UTC.

**Example**

```sql
SELECT minute('2026-09-10T11:07:30+05:45') AS utc_minute, minute(CAST('2026-09-10T11:07:30+05:45' AS TIMESTAMP) + 20700000) AS nepal_minute;
```

Result:

| utc_minute (LONG) | nepal_minute (LONG) |
|---|---|
| 22 | 7 |

(1 row)

**Example: COAST candles in the first 5 minutes of the day (Nepal 11:00-11:04)** (sample data: sample)

```sql
SELECT time, open, close
FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10'
  AND hour(time + 20700000) = 11 AND minute(time + 20700000) < 5;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | 380.1 | 380 |
| 2026-09-10T05:16:00.000Z | 380 | 379.6 |
| 2026-09-10T05:17:00.000Z | 379.6 | 380.1 |
| 2026-09-10T05:18:00.000Z | 380.1 | 380.4 |
| 2026-09-10T05:19:00.000Z | 380.4 | 380.7 |

(5 rows)

## second

Syntax:

```sql
second(t)
```

The second of the UTC time, from `0` to `59`. Milliseconds are not included.

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

- **Returns:** `LONG`.
- **NULL:** `second(NULL)` is `NULL`.
- **Notes:** for the milliseconds use [to_char](#to_char) with `MS`.

**Example**

```sql
SELECT second('2026-09-10T11:00:59.999Z') AS a, second('2026-09-10T11:00:05+05:45') AS b;
```

Result:

| a (LONG) | b (LONG) |
|---|---|
| 59 | 5 |

(1 row)

<a id="day_of_week"></a>

## day_of_week

Syntax:

```sql
day_of_week(t)
```

The weekday of the UTC date as a number: `0` = Sunday, `1` = Monday, ... `6` = Saturday.

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

- **Returns:** `LONG`.
- **NULL:** `day_of_week(NULL)` is `NULL`.
- **Notes:** Sunday is `0` (like PostgreSQL `EXTRACT(DOW ...)`). For the name use [to_char](#to_char) with `Dy` or `Day`. `to_char(t, 'D')` counts from `1` = Sunday instead.

**Example**

```sql
SELECT day_of_week('2026-09-06') AS sunday, day_of_week('2026-09-10') AS thursday, day_of_week(CAST('2026-09-12' AS DATE)) AS saturday;
```

Result:

| sunday (LONG) | thursday (LONG) | saturday (LONG) |
|---|---|---|
| 0 | 4 | 6 |

(1 row)

**Example: Trading days per weekday (a Sunday-to-Thursday week)** (sample data: sample)

```sql
SELECT day_of_week(time) AS dow, count(*) AS candles, round(avg(volume)) AS avg_volume
FROM ochl_day
GROUP BY day_of_week(time)
ORDER BY dow;
```

Result:

| dow (LONG) | candles (LONG) | avg_volume (DOUBLE) |
|---|---|---|
| 0 | 12 | 97458 |
| 1 | 12 | 91830 |
| 2 | 12 | 83335 |
| 3 | 12 | 96533 |
| 4 | 9 | 114613 |

(5 rows)

<a id="is_trading_day"></a>

## is_trading_day

Syntax:

```sql
is_trading_day(t)
```

`true` when the UTC date is a Sunday, Monday, Tuesday, Wednesday or Thursday: a Sunday-to-Thursday trading week, as on some exchanges. `false` on Friday and Saturday.

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

- **Returns:** `BOOL`.
- **NULL:** `is_trading_day(NULL)` is `NULL`.
- **Notes:** this one-argument form knows no holidays and one fixed week. For a market's own weekdays (also a week that changed, like NEPSE's in April 2026) and its holidays, make a [trading calendar](calendars.md) and write `is_trading_day('nepse', t)`; `next_trading_day`, `prev_trading_day` and `trading_days_between` come with it.

**Example**

```sql
SELECT is_trading_day('2026-09-10') AS thursday, is_trading_day('2026-09-11') AS friday, is_trading_day('2026-09-12') AS saturday, is_trading_day('2026-09-13') AS sunday;
```

Result:

| thursday (BOOL) | friday (BOOL) | saturday (BOOL) | sunday (BOOL) |
|---|---|---|---|
| true | false | false | true |

(1 row)

**Example: App sign-ups on trading days and on the weekend (Nepal date)** (sample data: fn-dates)

```sql
SELECT is_trading_day(created_at + 20700000) AS trading_day, count(*) AS signups
FROM signups
GROUP BY is_trading_day(created_at + 20700000)
ORDER BY trading_day;
```

Result:

| trading_day (BOOL) | signups (LONG) |
|---|---|
| false | 1 |
| true | 9 |

(2 rows)

<a id="date_part"></a>

## date_part, extract

Syntax:

```sql
date_part(field, t)
extract(field FROM t)
extract(field, t)
```

Takes one part of a time: the year, the month, the hour, the weekday, the week number and so on. `date_part('month', '2026-09-10')` is `9`. `extract(month FROM t)` is the SQL standard way to write the same thing; `extract('month', t)` also works.

| Argument | Type | Meaning |
|---|---|---|
| `field` | text (a word after `extract`) | the part you want; see the table below (any case, `years`, `months`, ... also work) |
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

| Field | Gives | 2026-09-10 05:20:30.250 UTC gives |
|---|---|---|
| `year` | the year | `2026` |
| `quarter` | quarter of the year, 1-4 | `3` |
| `month` | 1-12 | `9` |
| `week` | ISO week number, 1-53 (see [week_of_year](#week_of_year)) | `37` |
| `day` | day of the month, 1-31 | `10` |
| `dow` | weekday, `0` = Sunday ... `6` = Saturday | `4` |
| `isodow` | weekday, `1` = Monday ... `7` = Sunday | `4` |
| `doy` | day of the year, 1-366 | `253` |
| `hour` | 0-23 | `5` |
| `minute` | 0-59 | `20` |
| `second` | seconds **with** the milliseconds, as a `DOUBLE` | `30.25` |
| `millisecond` | the seconds counted in milliseconds, 0-59999 | `30250` |
| `epoch` | seconds since 1970-01-01 UTC, as a `DOUBLE` | `1789017630.25` |
| `isoyear` | the year the ISO week belongs to | `2026` |
| `decade` | the year / 10 | `202` |
| `century` | the century | `21` |

- **Returns:** `LONG`; `DOUBLE` for `second` and `epoch`.
- **NULL:** `NULL` when `field` or `t` is `NULL`.
- **Notes:** UTC, like every function on this page: add `20700000` for Nepal time. An unknown field is an error that lists the fields. `extract(field FROM t)` is PostgreSQL style; `date_part` has the same result.
- **Speed:** `GROUP BY extract(hour FROM t)` (any field above) on a `TIMESTAMP` column is read by the column engine: 3 million rows by hour of the day take about 5 ms (400 ms before 2026-10-24).

**Example**

```sql
SELECT date_part('year', '2026-09-10T05:20:30.250Z') AS year,
       extract(month FROM '2026-09-10T05:20:30.250Z') AS month,
       extract('dow', '2026-09-10') AS dow,
       date_part('isodow', '2026-09-13') AS isodow_sunday,
       date_part('doy', CAST('2026-09-10' AS DATE)) AS doy,
       date_part('second', '2026-09-10T05:20:30.250Z') AS second,
       date_part('epoch', '2026-09-10T00:00:00Z') AS epoch;
```

Result:

| year (LONG) | month (LONG) | dow (LONG) | isodow_sunday (LONG) | doy (LONG) | second (DOUBLE) | epoch (DOUBLE) |
|---|---|---|---|---|---|---|
| 2026 | 9 | 4 | 7 | 253 | 30.25 | 1788998400 |

(1 row)

**Example: App sales per year and quarter** (sample data: analysis-finance)

```sql
SELECT extract(year FROM invoice_date) AS year, extract(quarter FROM invoice_date) AS quarter,
       count(*) AS invoices, sum(amount) AS sales
FROM invoices
GROUP BY extract(year FROM invoice_date), extract(quarter FROM invoice_date)
ORDER BY year, quarter;
```

Result:

| year (LONG) | quarter (LONG) | invoices (LONG) | sales (DECIMAL(2)) |
|---|---|---|---|
| 2025 | 2 | 1 | 12000.00 |
| 2025 | 3 | 3 | 15000.00 |
| 2025 | 4 | 1 | 4500.00 |
| 2026 | 1 | 2 | 13500.00 |
| 2026 | 2 | 1 | 4500.00 |
| 2026 | 3 | 4 | 30000.00 |

(6 rows)

**Example: Traded volume per Nepal weekday (0 = Sunday)** (sample data: sample)

```sql
SELECT date_part('dow', time + 20700000) AS nepal_weekday, count(*) AS minutes, sum(volume) AS volume
FROM ochl_minutes
GROUP BY date_part('dow', time + 20700000)
ORDER BY nepal_weekday;
```

Result:

| nepal_weekday (LONG) | minutes (LONG) | volume (DOUBLE) |
|---|---|---|
| 3 | 480 | 368720 |
| 4 | 476 | 369240 |

(2 rows)

**Example: An unknown field lists the fields you can use** (shows an error)

```sql
SELECT date_part('fortnight', '2026-09-10');
```

Result:

Error: `line 1, column 8: date_part: unknown field 'fortnight'; use year, quarter, month, week, day, dow, isodow, doy, hour, minute, second, millisecond, epoch, isoyear, decade or century`

## quarter

Syntax:

```sql
quarter(t)
```

The quarter of the year of the UTC date: `1` for January-March, `2` for April-June, `3` for July-September, `4` for October-December. For a fiscal year that does not start in January, use [fiscal_quarter](#fiscal_quarter).

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

- **Returns:** `LONG`.
- **NULL:** `quarter(NULL)` is `NULL`.
- **Notes:** the same as `date_part('quarter', t)` and `to_char(t, 'Q')`. For the first day of the quarter use [date_trunc](#date_trunc)`('quarter', t)`.

**Example**

```sql
SELECT quarter('2026-01-01') AS jan, quarter('2026-06-30') AS jun, quarter('2026-09-10T05:15:00Z') AS sep, quarter(CAST('2026-12-31' AS DATE)) AS dec;
```

Result:

| jan (LONG) | jun (LONG) | sep (LONG) | dec (LONG) |
|---|---|---|---|
| 1 | 2 | 3 | 4 |

(1 row)

**Example: Volume of every symbol per quarter** (sample data: sample)

```sql
SELECT year(time) AS year, quarter(time) AS quarter, symbol, count(*) AS days, sum(volume) AS volume
FROM ochl_day
GROUP BY year(time), quarter(time), symbol
ORDER BY year, quarter, symbol;
```

Result:

| year (LONG) | quarter (LONG) | symbol (SYMBOL) | days (LONG) | volume (DOUBLE) |
|---|---|---|---|---|
| 2025 | 4 | CITY | 4 | 255090 |
| 2025 | 4 | COAST | 4 | 206980 |
| 2025 | 4 | VOLT | 4 | 409650 |
| 2026 | 3 | CITY | 15 | 1731760 |
| 2026 | 3 | COAST | 15 | 1467530 |
| 2026 | 3 | VOLT | 15 | 1390380 |

(6 rows)

<a id="day_of_year"></a>

## day_of_year

Syntax:

```sql
day_of_year(t)
```

The day number in the year of the UTC date: `1` for 1 January, `365` for 31 December (`366` in a leap year).

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

- **Returns:** `LONG`.
- **NULL:** `day_of_year(NULL)` is `NULL`.
- **Notes:** the same as `date_part('doy', t)`. Useful to compare the same day of different years ("how far into the year are we?").

**Example**

```sql
SELECT day_of_year('2026-01-01') AS first_day, day_of_year('2026-09-10') AS today, day_of_year('2026-12-31') AS last_day, day_of_year(CAST('2024-12-31' AS DATE)) AS leap_year;
```

Result:

| first_day (LONG) | today (LONG) | last_day (LONG) | leap_year (LONG) |
|---|---|---|---|
| 1 | 253 | 365 | 366 |

(1 row)

**Example: How much of the year had passed on each candle day?** (sample data: sample)

```sql
SELECT time, day_of_year(time) AS day_no, round(day_of_year(time) * 100.0 / 365, 1) AS year_done_pct
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-08'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | day_no (LONG) | year_done_pct (DOUBLE) |
|---|---|---|
| 2026-09-08T00:00:00.000Z | 251 | 68.8 |
| 2026-09-09T00:00:00.000Z | 252 | 69 |
| 2026-09-10T00:00:00.000Z | 253 | 69.3 |

(3 rows)

<a id="week_of_year"></a>

## week_of_year

Syntax:

```sql
week_of_year(t)
```

The **ISO week number** of the UTC date, from `1` to `53`. ISO weeks start on **Monday**, and week 1 is the week that has the first Thursday of the year. So the first days of January can be in week 52 or 53 of the year before, and the last days of December in week 1 of the next year.

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

- **Returns:** `LONG`.
- **NULL:** `week_of_year(NULL)` is `NULL`.
- **Notes:** the same as `date_part('week', t)`. When you group by week across a new year, also group by `date_part('isoyear', t)`, not by `year(t)`. A Sunday-to-Thursday trading week (as on some exchanges) starts on Sunday: for that, use [date_trunc](#date_trunc)`('week', t)` instead.

**Example**

```sql
SELECT week_of_year('2026-09-10') AS thursday, week_of_year('2026-01-01') AS new_year_2026,
       week_of_year('2027-01-01') AS new_year_2027, date_part('isoyear', '2027-01-01') AS its_iso_year;
```

Result:

| thursday (LONG) | new_year_2026 (LONG) | new_year_2027 (LONG) | its_iso_year (LONG) |
|---|---|---|---|
| 37 | 1 | 53 | 2026 |

(1 row)

**Example: Forum posts per ISO week** (sample data: fn-dates)

```sql
SELECT date_part('isoyear', created_at) AS iso_year, week_of_year(created_at) AS week, count(*) AS posts
FROM forum_posts
GROUP BY date_part('isoyear', created_at), week_of_year(created_at)
ORDER BY iso_year, week;
```

Result:

| iso_year (LONG) | week (LONG) | posts (LONG) |
|---|---|---|
| 2026 | 33 | 1 |
| 2026 | 34 | 3 |
| 2026 | 35 | 4 |
| 2026 | 36 | 3 |
| 2026 | 37 | 3 |

(5 rows)

<a id="date_trunc"></a>

## date_trunc

Syntax:

```sql
date_trunc(unit, t)
date_trunc(unit, t, time_zone)
```

Cuts the time down to the start of its year, month, week, day, hour, minute or second. `date_trunc('month', '2026-09-10T08:30:00Z')` is `2026-09-01T00:00:00.000Z`. Use it to put rows into groups by time.

| Argument | Type | Meaning |
|---|---|---|
| `unit` | text | `'year'`, `'quarter'`, `'month'`, `'week'`, `'day'`, `'hour'`, `'minute'`, `'second'` or `'ms'` (any case). Short and plural forms also work: `'d'`, `'h'`, `'m'` (minute), `'s'`, `'days'`, `'hours'`, ... |
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |
| `time_zone` | text | optional: cut on this zone's clock, like `'Asia/Kathmandu'` or `'+05:45'` (the PostgreSQL form). The [zone names](time-and-time-zones.md#time-zone-names) are the same as for SAMPLE BY. |

- **Returns:** a `DATE` when `t` is a `DATE` and there is no zone; else a `TIMESTAMP`. With a zone the result is the start on that clock, as a UTC time: `date_trunc('day', '2026-09-10T02:00:00Z', 'Asia/Kathmandu')` is `2026-09-09T18:15:00.000Z` (Nepal midnight of 10 Sep).
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:**
  - Without a zone: the [session's clock](time-and-time-zones.md#session-time-zone), which is UTC unless set. Then `date_trunc('day', ...)` gives UTC midnight, which is 05:45 in Nepal. Give the zone, or `SET TIME ZONE 'Asia/Kathmandu'`, for Nepal days, as [SAMPLE BY ... TIME ZONE](sample-by.md#time-zone) does.
  - Zones that change for summer time (like `Europe/London`) are refused.
  - `'week'` starts on **Sunday** (as in a Sunday-to-Thursday trading week).
  - Careful: `'w'` and `'weeks'` are not the same as `'week'`. They make 7-day steps counted from 1970-01-01, which was a Thursday, so they start on Thursday.
  - `'m'` is a minute, not a month. `'quarter'` gives 1 January, 1 April, 1 July or 1 October (only this spelling; for the quarter number use [quarter](#quarter)).
  - For candles of any size (15 minutes, 1 hour) use [SAMPLE BY](sample-by.md).

**Example**

```sql
SELECT date_trunc('year', '2026-09-10T08:30:00Z') AS year, date_trunc('month', '2026-09-10T08:30:00Z') AS month, date_trunc('week', '2026-09-10T08:30:00Z') AS week_sunday, date_trunc('hour', '2026-09-10T08:30:00Z') AS hour, date_trunc('month', CAST('2026-09-10' AS DATE)) AS date_stays_date;
```

Result:

| year (TIMESTAMP) | month (TIMESTAMP) | week_sunday (TIMESTAMP) | hour (TIMESTAMP) | date_stays_date (DATE) |
|---|---|---|---|---|
| 2026-01-01T00:00:00.000Z | 2026-09-01T00:00:00.000Z | 2026-09-06T00:00:00.000Z | 2026-09-10T08:00:00.000Z | 2026-09-01 |

(1 row)

**Example: Forum posts per week** (sample data: fn-dates)

```sql
SELECT date_trunc('week', created_at) AS week, count(*) AS posts, count(DISTINCT author) AS authors
FROM forum_posts
GROUP BY date_trunc('week', created_at)
ORDER BY week;
```

Result:

| week (TIMESTAMP) | posts (LONG) | authors (LONG) |
|---|---|---|
| 2026-08-16T00:00:00.000Z | 3 | 3 |
| 2026-08-23T00:00:00.000Z | 4 | 4 |
| 2026-08-30T00:00:00.000Z | 3 | 3 |
| 2026-09-06T00:00:00.000Z | 4 | 4 |

(4 rows)

**Example: Monthly candles of CITY from daily candles** (sample data: sample)

```sql
SELECT date_trunc('month', time) AS month,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close
FROM ochl_day
WHERE symbol = 'CITY'
GROUP BY date_trunc('month', time)
ORDER BY month;
```

Result:

| month (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) |
|---|---|---|---|---|
| 2025-12-01T00:00:00.000Z | 540.3 | 546.2 | 536.4 | 542.4 |
| 2026-08-01T00:00:00.000Z | 505 | 517 | 500.1 | 505.7 |
| 2026-09-01T00:00:00.000Z | 504.9 | 512.4 | 494.1 | 504.9 |

(3 rows)

**Example: 'week' and 'w' are different**

```sql
SELECT date_trunc('week', '2026-09-10') AS week_from_sunday, date_trunc('w', '2026-09-10') AS w_from_thursday;
```

Result:

| week_from_sunday (TIMESTAMP) | w_from_thursday (TIMESTAMP) |
|---|---|
| 2026-09-06T00:00:00.000Z | 2026-09-10T00:00:00.000Z |

(1 row)

**Example: Start of the quarter: sales per quarter** (sample data: analysis-finance)

```sql
SELECT date_trunc('quarter', invoice_date) AS quarter_start, count(*) AS invoices, sum(amount) AS sales
FROM invoices
GROUP BY date_trunc('quarter', invoice_date)
ORDER BY quarter_start;
```

Result:

| quarter_start (TIMESTAMP) | invoices (LONG) | sales (DECIMAL(2)) |
|---|---|---|
| 2025-04-01T00:00:00.000Z | 1 | 12000.00 |
| 2025-07-01T00:00:00.000Z | 3 | 15000.00 |
| 2025-10-01T00:00:00.000Z | 1 | 4500.00 |
| 2026-01-01T00:00:00.000Z | 2 | 13500.00 |
| 2026-04-01T00:00:00.000Z | 1 | 4500.00 |
| 2026-07-01T00:00:00.000Z | 4 | 30000.00 |

(6 rows)

**Example: Decade is not a unit** (shows an error)

```sql
SELECT date_trunc('decade', '2026-09-10');
```

Result:

Error: `line 1, column 8: date_trunc: unit must be year, month, week, day, hour, minute, second or ms`

**Example: The UTC day and the Nepal day of the same moments**

```sql
SELECT t, date_trunc('day', t) AS utc_midnight, date_trunc('day', t, 'Asia/Kathmandu') AS nepal_midnight,
       date_trunc('month', t, 'Asia/Kathmandu') AS nepal_month
FROM (SELECT CAST('2026-09-09T20:00:00Z' AS TIMESTAMP) AS t
      UNION ALL SELECT CAST('2026-08-31T19:00:00Z' AS TIMESTAMP)) x
ORDER BY t;
```

Result:

| t (TIMESTAMP) | utc_midnight (TIMESTAMP) | nepal_midnight (TIMESTAMP) | nepal_month (TIMESTAMP) |
|---|---|---|---|
| 2026-08-31T19:00:00.000Z | 2026-08-31T00:00:00.000Z | 2026-08-31T18:15:00.000Z | 2026-08-31T18:15:00.000Z |
| 2026-09-09T20:00:00.000Z | 2026-09-09T00:00:00.000Z | 2026-09-09T18:15:00.000Z | 2026-08-31T18:15:00.000Z |

(2 rows)

**Example: Sign-ups per Nepal day, as times** (sample data: fn-dates)

```sql
SELECT date_trunc('day', created_at, 'Asia/Kathmandu') AS nepal_day, count(*) AS signups
FROM signups
GROUP BY date_trunc('day', created_at, 'Asia/Kathmandu')
ORDER BY nepal_day;
```

Result:

| nepal_day (TIMESTAMP) | signups (LONG) |
|---|---|
| 2026-08-31T18:15:00.000Z | 3 |
| 2026-09-01T18:15:00.000Z | 2 |
| 2026-09-02T18:15:00.000Z | 3 |
| 2026-09-03T18:15:00.000Z | 1 |
| 2026-09-05T18:15:00.000Z | 1 |

(5 rows)

<a id="timestamp_floor"></a>

## timestamp_floor

Syntax:

```sql
timestamp_floor(unit, t)
timestamp_floor(unit, t, time_zone)
timestamp_floor(unit, t, origin)
```

The QuestDB function: cuts the time down to a whole number of units. `timestamp_floor('15m', '2026-09-10T05:22:10Z')` is `2026-09-10T05:15:00.000Z`.

| Argument | Type | Meaning |
|---|---|---|
| `unit` | text | an optional count and one letter: `T` millisecond, `s` second, `m` minute, `h` hour, `d` day, `w` week, `M` month, `y` year. `'15m'`, `'4h'`, `'1d'`, `'M'`. Upper and lower case matter (`m` minute, `M` month). |
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |
| `time_zone` | text | optional: cut on this zone's clock, like `'Asia/Kathmandu'` or `'+05:45'` |
| `origin` | a time | optional instead of a zone: count the units from this time, not from 1970-01-01 |

- **Returns:** `TIMESTAMP`, in UTC. With a zone it is the start on that clock: `timestamp_floor('1d', t, 'Asia/Kathmandu')` is Nepal midnight, shown as 18:15 UTC the day before.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:**
  - Counts start at 1970-01-01 00:00 (on the zone's clock when one is given): `'2d'` gives days 0, 2, 4, ... from then, `'3M'` gives January, April, July and October. Weeks start on **Monday**; for Sunday weeks use [date_trunc](#date_trunc)`('week', t)` or [SAMPLE BY ... WEEK START SUNDAY](sample-by.md#week-start).
  - `U` (microseconds) is not a unit: KarelaDB keeps milliseconds.
  - For candles, [SAMPLE BY](sample-by.md) does the same cut and the aggregates in one step.

**Example: Cut one moment by several units**

```sql
SELECT timestamp_floor('15m', '2026-09-10T05:22:10Z') AS quarter_hour,
       timestamp_floor('1d', '2026-09-09T20:00:00Z') AS utc_day,
       timestamp_floor('1d', '2026-09-09T20:00:00Z', 'Asia/Kathmandu') AS nepal_day,
       timestamp_floor('w', '2026-09-10T05:00:00Z') AS monday,
       timestamp_floor('3M', '2026-09-10T05:00:00Z') AS quarter_month,
       timestamp_floor('2d', '2026-09-10T05:00:00Z', '2026-09-01') AS two_days_from_sep_1;
```

Result:

| quarter_hour (TIMESTAMP) | utc_day (TIMESTAMP) | nepal_day (TIMESTAMP) | monday (TIMESTAMP) | quarter_month (TIMESTAMP) | two_days_from_sep_1 (TIMESTAMP) |
|---|---|---|---|---|---|
| 2026-09-10T05:15:00.000Z | 2026-09-09T00:00:00.000Z | 2026-09-09T18:15:00.000Z | 2026-09-07T00:00:00.000Z | 2026-07-01T00:00:00.000Z | 2026-09-09T00:00:00.000Z |

(1 row)

**Example: Nepal-hour candles with timestamp_floor, like SAMPLE BY 1h TIME ZONE** (sample data: sample)

```sql
SELECT timestamp_floor('1h', time, 'Asia/Kathmandu') AS hour, first(open) AS open, last(close) AS close, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
GROUP BY timestamp_floor('1h', time, 'Asia/Kathmandu')
ORDER BY hour;
```

Result:

| hour (TIMESTAMP) | open (DOUBLE) | close (DOUBLE) | minutes (LONG) |
|---|---|---|---|
| 2026-09-10T05:15:00.000Z | 504.6 | 505.3 | 60 |
| 2026-09-10T06:15:00.000Z | 505.3 | 502.7 | 60 |
| 2026-09-10T07:15:00.000Z | 502.7 | 502.6 | 60 |
| 2026-09-10T08:15:00.000Z | 502.6 | 504.9 | 60 |

(4 rows)

**Example: An unknown unit** (shows an error)

```sql
SELECT timestamp_floor('1x', '2026-09-10');
```

Result:

Error: `line 1, column 8: timestamp_floor: unit must be T, s, m, h, d, w, M or y with an optional count, like '15m' or '1d'; got '1x'`

`timestamp_floor_utc(unit, t [, zone])` is QuestDB's name for the same function: its answer is in UTC, and KarelaDB's always is.

**Speed:** `GROUP BY timestamp_floor(...)` on a `TIMESTAMP` column is read by the column engine, as fast as [date_trunc](#date_trunc): 3 million rows in 1-minute groups take about 18 ms (it was 1.7 s before 2026-10-24). Only `M` and `y` counted from an origin of your own are worked out row by row.

<a id="time_bucket"></a>

## time_bucket, date_bin

Syntax:

```sql
time_bucket(width, t)
time_bucket(width, t, offset)
time_bucket(width, t, origin)
date_bin(stride, t, origin)
```

Puts a time into a bucket of a fixed width and gives the bucket's start. `time_bucket` is the TimescaleDB function; `date_bin` is the PostgreSQL 14 one. `time_bucket(INTERVAL '15 minutes', '2026-10-24T10:37:12Z')` is `2026-10-24T10:30:00.000Z`.

| Argument | Type | Meaning |
|---|---|---|
| `width`, `stride` | interval: `INTERVAL '15 minutes'` or text like `'1 day'` | the size of a bucket. `time_bucket` also takes months and years (`'1 month'`, `'3 months'`, `'1 year'`); `date_bin` does not, as in PostgreSQL |
| `t` | `TIMESTAMP`, `DATE` or time text | the time |
| `offset` | interval | optional: move every bucket by this much, like `INTERVAL '5 hours 45 minutes'` for Nepal days |
| `origin` | a time | a bucket starts here, and every `width` before and after it. Needed for `date_bin` |

- **Returns:** `TIMESTAMP`, in UTC. `time_bucket` of a `DATE` gives a `DATE`. `time_bucket(10, n)` on whole numbers gives `n` rounded down to a multiple of 10.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:**
  - Without an origin, `time_bucket` counts from Monday 2000-01-03 (so `'1 week'` starts on Monday) and month widths from 2000-01-01, as TimescaleDB does.
  - A width mixing months with days or hours (`'1 month 2 days'`) is an error, so is a width of zero or less.
  - Buckets are cut on UTC's clock, not the session's. For local days give an offset or an origin at local midnight.
  - TimescaleDB's third-argument form with a zone name (`time_bucket('1 day', t, 'Asia/Kathmandu')`) is not supported: it is an error, never a wrong bucket. Give the offset instead (`INTERVAL '5 hours 45 minutes'`), or use [timestamp_floor](#timestamp_floor) with a zone.
  - **Speed:** as a `GROUP BY` key on a `TIMESTAMP` column both are read by the column engine, as fast as [date_trunc](#date_trunc). Month widths from an origin that is not the first of a month at midnight are worked out row by row.

**Example: Buckets of one moment**

```sql
SELECT time_bucket(INTERVAL '15 minutes', TIMESTAMP '2026-10-24 10:37:12') AS quarter_hour,
       time_bucket('1 week', TIMESTAMP '2026-10-24 10:00') AS monday,
       time_bucket('3 months', TIMESTAMP '2026-11-24') AS quarter,
       time_bucket(INTERVAL '1 day', TIMESTAMP '2026-10-24 03:00', INTERVAL '5 hours 45 minutes') AS day_from_0545,
       date_bin('15 minutes', TIMESTAMP '2020-02-11 15:44:17', TIMESTAMP '2001-01-01 00:02:30') AS from_origin;
```

Result:

| quarter_hour (TIMESTAMP) | monday (TIMESTAMP) | quarter (TIMESTAMP) | day_from_0545 (TIMESTAMP) | from_origin (TIMESTAMP) |
|---|---|---|---|---|
| 2026-10-24T10:30:00.000Z | 2026-10-19T00:00:00.000Z | 2026-10-01T00:00:00.000Z | 2026-10-23T05:45:00.000Z | 2020-02-11T15:32:30.000Z |

(1 row)

**Example: Half-hour candles of CITY with time_bucket** (sample data: sample)

```sql
SELECT time_bucket(INTERVAL '30 minutes', time) AS bucket, first(open) AS open, max(high) AS high, min(low) AS low,
       last(close) AS close
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
GROUP BY bucket
ORDER BY bucket;
```

Result:

| bucket (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T05:00:00.000Z | 504.6 | 505.3 | 503.9 | 504.4 |
| 2026-09-10T05:30:00.000Z | 504.4 | 507 | 503.8 | 506.4 |
| 2026-09-10T06:00:00.000Z | 506.4 | 506.6 | 504.9 | 505.4 |
| 2026-09-10T06:30:00.000Z | 505.4 | 505.9 | 500.7 | 501.2 |
| 2026-09-10T07:00:00.000Z | 501.2 | 503.3 | 500.7 | 502.5 |
| 2026-09-10T07:30:00.000Z | 502.5 | 504.1 | 502.1 | 502.6 |
| 2026-09-10T08:00:00.000Z | 502.6 | 505.4 | 501.9 | 504.8 |
| 2026-09-10T08:30:00.000Z | 504.8 | 507 | 503.9 | 505 |
| 2026-09-10T09:00:00.000Z | 505 | 506.1 | 504.3 | 504.9 |

(9 rows)

**Example: Grafana with TimescaleDB on: $__timeGroup(time, 1h) becomes this** (sample data: sample)

```sql
SELECT time_bucket('3600.000s', time) AS time, avg(close) AS close
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
GROUP BY 1
ORDER BY 1;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) |
|---|---|
| 2026-09-10T05:00:00.000Z | 505.244444444444 |
| 2026-09-10T06:00:00.000Z | 504.555 |
| 2026-09-10T07:00:00.000Z | 502.686666666667 |
| 2026-09-10T08:00:00.000Z | 504.516666666667 |
| 2026-09-10T09:00:00.000Z | 505.12 |

(5 rows)

**Example: date_bin takes no months** (shows an error)

```sql
SELECT date_bin('1 month', TIMESTAMP '2026-10-24', TIMESTAMP '2000-01-01');
```

Result:

Error: `line 1, column 8: date_bin: timestamps cannot be binned into intervals containing months or years`

<a id="timestamp_ceil"></a>

## timestamp_ceil

Syntax:

```sql
timestamp_ceil(unit, t)
timestamp_ceil(unit, t, time_zone)
timestamp_ceil(unit, t, origin)
```

The QuestDB function: moves the time **up** to the next whole unit. A time that is already on a whole unit stays as it is: `timestamp_ceil('1h', '06:00')` is `06:00`.

| Argument | Type | Meaning |
|---|---|---|
| `unit` | text | as for [timestamp_floor](#timestamp_floor): `'15m'`, `'1h'`, `'1d'`, `'M'`, ... |
| `t` | a time | the time |
| `time_zone` or `origin` | text or a time | optional, as for [timestamp_floor](#timestamp_floor) |

- **Returns:** `TIMESTAMP`, in UTC.
- **NULL:** `NULL` when any argument is `NULL`.

**Example: Round up to the quarter hour, the day and the month**

```sql
SELECT timestamp_ceil('15m', '2026-09-10T05:22:10Z') AS quarter_hour,
       timestamp_ceil('15m', '2026-09-10T05:30:00Z') AS already_whole,
       timestamp_ceil('1d', '2026-09-10T05:22:10Z') AS next_midnight,
       timestamp_ceil('M', '2026-09-10T05:22:10Z') AS next_month;
```

Result:

| quarter_hour (TIMESTAMP) | already_whole (TIMESTAMP) | next_midnight (TIMESTAMP) | next_month (TIMESTAMP) |
|---|---|---|---|
| 2026-09-10T05:30:00.000Z | 2026-09-10T05:30:00.000Z | 2026-09-11T00:00:00.000Z | 2026-10-01T00:00:00.000Z |

(1 row)

<a id="today"></a>

## today, yesterday, tomorrow

Syntax:

```sql
today()
today(time_zone)
today(t)
yesterday(...)
tomorrow(...)
```

QuestDB's day intervals: the whole day, from 00:00 to 23:59:59.999. Use them after `IN`: `WHERE time IN today()` ([interval lists](where.md#interval-lists)).

| Argument | Type | Meaning |
|---|---|---|
| `time_zone` | text | optional: the day on this zone's clock, like `'Asia/Kathmandu'` |
| `t` | a time | optional: the day of this time instead of now |

- **Returns:** the interval as text, `('2026-09-10T00:00:00.000Z', '2026-09-10T23:59:59.999Z')`. [interval_start and interval_end](#interval) take the two ends out.
- **Notes:** the day is taken once, when the statement starts.

**Example: Today's rows, and the start of tomorrow** (sample data: sample)

```sql
SELECT count(*) AS rows_today, interval_start(tomorrow()) AS tomorrow_starts
FROM live_data WHERE timestamp IN today();
```

Result:

| rows_today (LONG) | tomorrow_starts (TIMESTAMP) |
|---|---|
| 0 | 2026-10-25T00:00:00.000Z |

(1 row)

**Example: The day of a given time, and the day before it**

```sql
SELECT today('2026-09-10T20:00:00Z') AS that_day, interval_start(yesterday('2026-09-10T20:00:00Z')) AS day_before;
```

Result:

| that_day (STRING) | day_before (TIMESTAMP) |
|---|---|
| ('2026-09-10T00:00:00.000Z', '2026-09-10T23:59:59.999Z') | 2026-09-09T00:00:00.000Z |

(1 row)

<a id="interval"></a>

## interval, interval_start, interval_end

Syntax:

```sql
interval(from, to)
interval_start(an_interval)
interval_end(an_interval)
```

`interval` makes a QuestDB interval from two times, both included. `interval_start` and `interval_end` give its first and last moment.

| Argument | Type | Meaning |
|---|---|---|
| `from`, `to` | a time | the first and the last moment; `to` must not be before `from` |
| `an_interval` | text | an interval from `interval()`, `today()`, `yesterday()` or `tomorrow()` |

- **Returns:** `interval` gives text `('from', 'to')`; `interval_start` and `interval_end` give a `TIMESTAMP`.
- **NULL:** `NULL` when an argument is `NULL`.

**Example: An interval and its two ends**

```sql
SELECT interval('2026-09-10T05:15:00Z', '2026-09-10T09:15:00Z') AS session,
       interval_start(interval('2026-09-10T05:15:00Z', '2026-09-10T09:15:00Z')) AS opens,
       interval_end(interval('2026-09-10T05:15:00Z', '2026-09-10T09:15:00Z')) AS closes;
```

Result:

| session (STRING) | opens (TIMESTAMP) | closes (TIMESTAMP) |
|---|---|---|
| ('2026-09-10T05:15:00.000Z', '2026-09-10T09:15:00.000Z') | 2026-09-10T05:15:00.000Z | 2026-09-10T09:15:00.000Z |

(1 row)

**Example: The end must not be before the start** (shows an error)

```sql
SELECT interval('2026-09-10', '2026-09-09');
```

Result:

Error: `line 1, column 8: interval: the end 2026-09-09T00:00:00.000Z is before the start 2026-09-10T00:00:00.000Z`

<a id="days_in_month"></a>

## days_in_month, is_leap_year, is_end_of_month, day_of_week_sunday_first, millis, to_pg_date

Syntax:

```sql
days_in_month(t)
is_leap_year(t)
is_leap_year(year)
is_end_of_month(t)
day_of_week_sunday_first(t)
millis(t)
to_pg_date(t)
```

Small QuestDB calendar functions.

| Function | Returns |
|---|---|
| `days_in_month(t)` | the days in the month of `t`: 28 to 31 |
| `is_leap_year(t)` | `true` when the year of `t` (or the year number) has 29 February |
| `is_end_of_month(t)` | `true` on the last day of the month |
| `day_of_week_sunday_first(t)` | 1 Sunday, 2 Monday, ... 7 Saturday |
| `millis(t)` | the milliseconds of the second: 0 to 999 |
| `to_pg_date(t)` | the day of `t` as a `DATE` |

- **NULL:** `NULL` for a `NULL` argument.
- **Notes:** the day is taken on the [session's time zone](time-and-time-zones.md#session-time-zone), as for [day_of_week](#day_of_week). KarelaDB's own `day_of_week` is 0 Sunday to 6 Saturday; a database set to the QuestDB dialect numbers it as QuestDB does, 1 Monday to 7 Sunday.

**Example: Facts about a date**

```sql
SELECT days_in_month('2028-02-10') AS feb_2028_days,
       is_leap_year('2028-02-10') AS leap_2028,
       is_leap_year(2026) AS leap_2026,
       is_end_of_month('2026-09-30') AS month_end,
       day_of_week_sunday_first('2026-09-27') AS sunday,
       millis('2026-09-10T05:15:00.250Z') AS ms,
       to_pg_date('2026-09-10T20:00:00Z') AS day;
```

Result:

| feb_2028_days (LONG) | leap_2028 (BOOL) | leap_2026 (BOOL) | month_end (BOOL) | sunday (LONG) | ms (LONG) | day (DATE) |
|---|---|---|---|---|---|---|
| 29 | true | false | true | 1 | 250 | 2026-09-10 |

(1 row)

<a id="sysdate"></a>

## sysdate

Syntax:

```sql
sysdate()
```

QuestDB's clock: the time now, the same as [now](#now)`()`.

- **Returns:** `TIMESTAMP` (KarelaDB keeps milliseconds, which is what QuestDB's `DATE` holds).

**Example: sysdate is now**

```sql
SELECT sysdate() = now() AS same;
```

Result:

| same (BOOL) |
|---|
| true |

(1 row)

<a id="timestamp_sequence"></a>

## timestamp_sequence, timestamp_shuffle

Syntax:

```sql
timestamp_sequence(start, step_microseconds)
timestamp_shuffle(from, to)
```

QuestDB's test-data helpers. `timestamp_sequence` gives `start` on the first row, `start + step` on the next, and so on. `timestamp_shuffle` gives a random time from `from` to `to`.

| Argument | Type | Meaning |
|---|---|---|
| `start` | a time | the first time |
| `step_microseconds` | whole number | the step, in **microseconds** as in QuestDB (`60000000` is one minute); KarelaDB keeps milliseconds, so the time is cut to the millisecond |
| `from`, `to` | a time | the range for a random time, both ends included |

- **Returns:** `TIMESTAMP`.
- **Notes:** each use of `timestamp_sequence` in a query counts its own rows.

**Example: One row a minute, with long_sequence**

```sql
SELECT x, timestamp_sequence('2026-09-10T05:15:00Z', 60000000) AS time
FROM long_sequence(4);
```

Result:

| x (LONG) | time (TIMESTAMP) |
|---|---|
| 1 | 2026-09-10T05:15:00.000Z |
| 2 | 2026-09-10T05:16:00.000Z |
| 3 | 2026-09-10T05:17:00.000Z |
| 4 | 2026-09-10T05:18:00.000Z |

(4 rows)

**Example: Random times in one day**

```sql
SELECT count(*) AS inside FROM (SELECT timestamp_shuffle('2026-09-10', '2026-09-11') AS t FROM long_sequence(100)) s
WHERE t >= '2026-09-10' AND t <= '2026-09-11';
```

Result:

| inside (LONG) |
|---|
| 100 |

(1 row)

<a id="to_timezone"></a>

## to_timezone, to_utc

Syntax:

```sql
to_timezone(t, time_zone)
to_utc(t, time_zone)
```

The QuestDB functions. `to_timezone` shows a UTC time on the clock of a zone: `to_timezone('2026-09-10T05:15:00Z', 'Asia/Kathmandu')` is `2026-09-10T11:00:00.000Z`. `to_utc` is the other way round: it reads `t` as that zone's clock and gives the UTC time.

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |
| `time_zone` | text | a zone name like `'Asia/Kathmandu'`, or an offset like `'+05:45'` |

- **Returns:** `TIMESTAMP`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:**
  - The result of `to_timezone` holds the Nepal clock time but still ends with `Z`. Use it for `hour()`, `day()` and showing, not to store.
  - `to_utc(t, 'Asia/Kathmandu')` is the same as `t AT TIME ZONE 'Asia/Kathmandu'`.
  - Zones that change for summer time are refused.

**Example: UTC to the Nepal clock and back**

```sql
SELECT to_timezone('2026-09-10T05:15:00Z', 'Asia/Kathmandu') AS nepal_clock,
       to_utc('2026-09-10T11:00:00Z', 'Asia/Kathmandu') AS utc,
       hour(to_timezone('2026-09-10T05:15:00Z', 'Asia/Kathmandu')) AS nepal_hour;
```

Result:

| nepal_clock (TIMESTAMP) | utc (TIMESTAMP) | nepal_hour (LONG) |
|---|---|---|
| 2026-09-10T11:00:00.000Z | 2026-09-10T05:15:00.000Z | 11 |

(1 row)

**Example: A zone with summer time: London is +01:00 in September, +00:00 in January**

```sql
SELECT to_timezone('2026-09-10T05:15:00Z', 'Europe/London') AS september, to_timezone('2026-01-10T05:15:00Z', 'Europe/London') AS january;
```

Result:

| september (TIMESTAMP) | january (TIMESTAMP) |
|---|---|
| 2026-09-10T06:15:00.000Z | 2026-01-10T05:15:00.000Z |

(1 row)

<a id="last_day"></a>

## last_day

Syntax:

```sql
last_day(t)
```

The **last day of the month** of the UTC date: `last_day('2026-02-10')` is `2026-02-28`. Accountants use it for the month-end date of a report (like Excel `EOMONTH(date, 0)`).

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |

- **Returns:** `DATE`, also for a `TIMESTAMP`.
- **NULL:** `last_day(NULL)` is `NULL`.
- **Notes:** knows leap years (29 February). For the first day of the month use [date_trunc](#date_trunc)`('month', t)`. For the month end of the next month: `last_day(dateadd('month', 1, t))`.

**Example**

```sql
SELECT last_day('2026-02-10') AS feb, last_day('2028-02-10T10:00:00Z') AS leap_feb, last_day(CAST('2026-09-10' AS DATE)) AS sep,
       last_day(dateadd('month', 1, '2026-09-10')) AS next_month_end;
```

Result:

| feb (DATE) | leap_feb (DATE) | sep (DATE) | next_month_end (DATE) |
|---|---|---|---|
| 2026-02-28 | 2028-02-29 | 2026-09-30 | 2026-10-31 |

(1 row)

**Example: Month-end report date of every invoice** (sample data: analysis-finance)

```sql
SELECT last_day(invoice_date) AS month_end, count(*) AS invoices, sum(amount) AS sales
FROM invoices
WHERE invoice_date >= '2026-01-01'
GROUP BY last_day(invoice_date)
ORDER BY month_end;
```

Result:

| month_end (DATE) | invoices (LONG) | sales (DECIMAL(2)) |
|---|---|---|
| 2026-01-31 | 1 | 1500.00 |
| 2026-03-31 | 1 | 12000.00 |
| 2026-05-31 | 1 | 4500.00 |
| 2026-07-31 | 2 | 13500.00 |
| 2026-08-31 | 1 | 4500.00 |
| 2026-09-30 | 1 | 12000.00 |

(6 rows)

## dateadd

Syntax:

```sql
dateadd(unit, amount, t)
```

Adds `amount` units to the time. A negative amount goes back. `dateadd('d', 7, '2026-09-10')` is one week later.

| Argument | Type | Meaning |
|---|---|---|
| `unit` | text | `'y'` (years), `'month'` or `'mo'` (months), `'w'` (weeks), `'d'` (days), `'h'` (hours), `'m'` (minutes), `'s'` (seconds), `'ms'`. Long forms also work: `'year'`, `'months'`, `'week'`, `'day'`, `'hour'`, `'minute'`, ... (any case) |
| `amount` | whole number | how many units; negative to go back |
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the start time |

- **Returns:** a `DATE` when `t` is a `DATE`; else a `TIMESTAMP`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:**
  - Months and years follow the calendar. When the day does not exist in the new month, you get the last day of that month: 31 January + 1 month is 28 February.
  - `'m'` is minutes. Write `'month'` or `'mo'` for months.
  - With a `DATE`, the result is a `DATE`, so hours are cut off: `dateadd('h', 30, date)` gives the next day.
  - `amount` must be a whole number: `1.5` is an error. For 1.5 days use `36` hours.
  - A `TIMESTAMP` plus a number of milliseconds (`time + 3600000`) also works; see [arithmetic operators](functions-math.md#operators).

**Example**

```sql
SELECT dateadd('d', 7, '2026-09-10T05:15:00Z') AS next_week, dateadd('month', 1, '2026-01-31') AS end_of_feb, dateadd('y', 1, CAST('2024-02-29' AS DATE)) AS leap_day_plus_year, dateadd('m', -90, '2026-09-10T05:15:00Z') AS minus_90_minutes, dateadd('h', 30, CAST('2026-09-10' AS DATE)) AS date_stays_date;
```

Result:

| next_week (TIMESTAMP) | end_of_feb (TIMESTAMP) | leap_day_plus_year (DATE) | minus_90_minutes (TIMESTAMP) | date_stays_date (DATE) |
|---|---|---|---|---|
| 2026-09-17T05:15:00.000Z | 2026-02-28T00:00:00.000Z | 2025-02-28 | 2026-09-10T03:45:00.000Z | 2026-09-11 |

(1 row)

**Example: When does the 7-day free trial of each new user end?** (sample data: fn-dates)

```sql
SELECT id, email, created_at, dateadd('d', 7, created_at) AS trial_ends
FROM signups
WHERE created_at >= '2026-09-03'
ORDER BY id;
```

Result:

| id (INT) | email (STRING) | created_at (TIMESTAMP) | trial_ends (TIMESTAMP) |
|---|---|---|---|
| 6 | anita@hotmail.com | 2026-09-03T02:35:00.000Z | 2026-09-10T02:35:00.000Z |
| 7 | suman@gmail.com | 2026-09-03T14:00:00.000Z | 2026-09-10T14:00:00.000Z |
| 8 | maya@gmail.com | 2026-09-03T18:05:00.000Z | 2026-09-10T18:05:00.000Z |
| 9 | kiran@gmail.com | 2026-09-04T04:25:00.000Z | 2026-09-11T04:25:00.000Z |
| 10 | nabin@yahoo.com | 2026-09-06T06:15:00.000Z | 2026-09-13T06:15:00.000Z |

(5 rows)

**Example: The 10-year listing anniversary of each company** (sample data: fn-dates)

```sql
SELECT symbol, listed_on, dateadd('y', 10, listed_on) AS ten_years
FROM listings
ORDER BY listed_on;
```

Result:

| symbol (STRING) | listed_on (DATE) | ten_years (DATE) |
|---|---|---|
| CITY | 1986-01-01 | 1996-01-01 |
| COAST | 1998-07-28 | 2008-07-28 |
| TELCO | 2008-07-11 | 2018-07-11 |
| ACME | 2015-05-08 | 2025-05-08 |
| VOLT | 2019-08-28 | 2029-08-28 |

(5 rows)

**Example: The amount must be a whole number** (shows an error)

```sql
SELECT dateadd('d', 1.5, '2026-09-10');
```

Result:

Error: `line 1, column 8: dateadd: the amount must be a whole number`

## datediff

Syntax:

```sql
datediff(unit, from, to)
```

How many whole units there are from `from` to `to`. `datediff('d', '2026-09-01', '2026-09-10')` is `9`.

| Argument | Type | Meaning |
|---|---|---|
| `unit` | text | `'y'` (years), `'month'` or `'mo'` (months), `'w'` (weeks), `'d'` (days), `'h'` (hours), `'m'` (minutes), `'s'` (seconds), `'ms'`; long forms like `'year'`, `'months'`, `'day'`, `'hours'` also work |
| `from` | `TIMESTAMP`, `DATE`, time text or milliseconds | the start |
| `to` | `TIMESTAMP`, `DATE`, time text or milliseconds | the end |

- **Returns:** `LONG`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:**
  - The result is negative when `to` is before `from`.
  - Parts are dropped, not rounded: 5 hours 59 minutes is `5` hours. For a negative result they are dropped toward zero (`-5`, not `-6`).
  - Months and years count **whole calendar months**, like [dateadd](#dateadd): from 10 January 10:00 to 10 February 09:00 is `0` months (one hour short), and from 31 January to 28 February is `1` month (the month end is reached). Years are whole months / 12. For the months, days and hours together use [age](#age).
  - The order of the arguments is like SQL Server (`unit, from, to`).

**Example**

```sql
SELECT datediff('d', '2026-09-01', '2026-09-10') AS days, datediff('d', '2026-09-10', '2026-09-01') AS negative, datediff('h', '2026-09-10T00:00:00Z', '2026-09-10T05:59:00Z') AS hours_cut, datediff('m', '2026-09-10T11:00:00+05:45', '2026-09-10T15:00:00+05:45') AS market_minutes;
```

Result:

| days (LONG) | negative (LONG) | hours_cut (LONG) | market_minutes (LONG) |
|---|---|---|---|
| 9 | -9 | 5 | 240 |

(1 row)

**Example: How long each company has been listed (up to 2026-09-11)** (sample data: fn-dates)

```sql
SELECT symbol, listed_on,
       datediff('d', listed_on, '2026-09-11') AS days,
       datediff('w', listed_on, '2026-09-11') AS weeks,
       year('2026-09-11') - year(listed_on) AS calendar_years
FROM listings
ORDER BY listed_on;
```

Result:

| symbol (STRING) | listed_on (DATE) | days (LONG) | weeks (LONG) | calendar_years (LONG) |
|---|---|---|---|---|
| CITY | 1986-01-01 | 14863 | 2123 | 40 |
| COAST | 1998-07-28 | 10272 | 1467 | 28 |
| TELCO | 2008-07-11 | 6636 | 948 | 18 |
| ACME | 2015-05-08 | 4144 | 592 | 11 |
| VOLT | 2019-08-28 | 2571 | 367 | 7 |

(5 rows)

**Example: First and last day of the sample candles** (sample data: sample)

```sql
SELECT min(time) AS first_day, max(time) AS last_day, datediff('d', min(time), max(time)) AS days_between
FROM ochl_day;
```

Result:

| first_day (TIMESTAMP) | last_day (TIMESTAMP) | days_between (LONG) |
|---|---|---|
| 2025-12-28T00:00:00.000Z | 2026-09-10T00:00:00.000Z | 256 |

(1 row)

**Example: Whole months and years between two dates**

```sql
SELECT datediff('month', '2026-01-01', '2026-09-10') AS months,
       datediff('month', '2026-01-10T10:00:00Z', '2026-02-10T09:00:00Z') AS one_hour_short,
       datediff('month', '2026-01-31', '2026-02-28') AS to_month_end,
       datediff('y', '2025-09-11', '2026-09-10') AS one_day_short,
       datediff('years', '1998-07-28', '2026-09-10') AS years;
```

Result:

| months (LONG) | one_hour_short (LONG) | to_month_end (LONG) | one_day_short (LONG) | years (LONG) |
|---|---|---|---|---|
| 8 | 0 | 1 | 0 | 28 |

(1 row)

**Example: Quarter is not a unit of datediff** (shows an error)

```sql
SELECT datediff('quarter', '2026-01-01', '2026-09-10');
```

Result:

Error: `line 1, column 8: datediff: unit must be y, month, w, d, h, m, s or ms`

## age

Syntax:

```sql
age(t)
age(to, from)
```

The time between two times, written like a person says it: `'28 years 1 mon 13 days'`. With one argument it is the time from `t` to **today** (today's UTC midnight), like PostgreSQL. Use it to show how old a company listing, an account or a user is.

| Argument | Type | Meaning |
|---|---|---|
| `to` | `TIMESTAMP`, `DATE`, time text or milliseconds | the later time |
| `from` | `TIMESTAMP`, `DATE`, time text or milliseconds | the earlier time |
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | one argument: the time to count from, up to today at 00:00 UTC |

- **Returns:** `STRING` with years, months (`mon`), days, and `hh:mm:ss` when there are hours (plus `.mmm` for milliseconds). Parts that are 0 are left out; equal times give `'00:00:00'`.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** the order is **later first**, like PostgreSQL. When `to` is before `from`, every part is negative: `'-1 mons -1 days'`. The result is text, so you cannot add or compare it as a number: for a number use [datediff](#datediff). With one argument the result changes every day.

**Example**

```sql
SELECT age('2026-09-10', '1998-07-28') AS listed_age,
       age('2026-09-10T15:30:00Z', '2026-09-10T11:00:00Z') AS hours,
       age('2026-09-11', '2025-09-11') AS one_year,
       age('2026-03-01', '2026-01-31') AS month_and_day,
       age('2026-01-31', '2026-03-01') AS negative;
```

Result:

| listed_age (STRING) | hours (STRING) | one_year (STRING) | month_and_day (STRING) | negative (STRING) |
|---|---|---|---|---|
| 28 years 1 mon 13 days | 04:30:00 | 1 year | 1 mon 1 day | -1 mons -1 days |

(1 row)

**Example: How long each company has been listed (up to 2026-09-11)** (sample data: fn-dates)

```sql
SELECT symbol, listed_on, age('2026-09-11', listed_on) AS listed_for
FROM listings
ORDER BY listed_on;
```

Result:

| symbol (STRING) | listed_on (DATE) | listed_for (STRING) |
|---|---|---|
| CITY | 1986-01-01 | 40 years 8 mons 10 days |
| COAST | 1998-07-28 | 28 years 1 mon 14 days |
| TELCO | 2008-07-11 | 18 years 2 mons |
| ACME | 2015-05-08 | 11 years 4 mons 3 days |
| VOLT | 2019-08-28 | 7 years 14 days |

(5 rows)

**Example: One argument: counted up to today's midnight (UTC)**

```sql
SELECT age('2000-01-01') = age(date_trunc('day', now()), '2000-01-01') AS same;
```

Result:

| same (BOOL) |
|---|
| true |

(1 row)

<a id="make_date"></a>

## make_date

Syntax:

```sql
make_date(year, month, day)
```

Builds a `DATE` from three numbers: `make_date(2026, 9, 10)` is `2026-09-10`. Useful when a table keeps the year, month and day in separate columns, or to build the start of a fiscal year.

| Argument | Type | Meaning |
|---|---|---|
| `year` | whole number | -9999 to 9999 |
| `month` | whole number | 1 to 12 |
| `day` | whole number | 1 to the last day of that month |

- **Returns:** `DATE`.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** a date that does not exist (30 February) is an error, not the next month. A number with a fraction (`2026.5`) is an error.

**Example**

```sql
SELECT make_date(2026, 9, 10) AS d, make_date(2028, 2, 29) AS leap_day, make_date(year('2026-09-10'), 7, 17) AS fiscal_year_start;
```

Result:

| d (DATE) | leap_day (DATE) | fiscal_year_start (DATE) |
|---|---|---|
| 2026-09-10 | 2028-02-29 | 2026-07-17 |

(1 row)

**Example: Invoices from the start of Nepal's fiscal year 2083/84** (sample data: analysis-finance)

```sql
SELECT id, invoice_date, customer, amount
FROM invoices
WHERE invoice_date >= make_date(2026, 7, 17)
ORDER BY invoice_date;
```

Result:

| id (INT) | invoice_date (TIMESTAMP) | customer (STRING) | amount (DECIMAL(2)) |
|---|---|---|---|
| 10 | 2026-07-20T00:00:00.000Z | hari | 1500.00 |
| 11 | 2026-08-25T00:00:00.000Z | gita | 4500.00 |
| 12 | 2026-09-10T00:00:00.000Z | maya | 12000.00 |

(3 rows)

**Example: 30 February does not exist** (shows an error)

```sql
SELECT make_date(2026, 2, 30);
```

Result:

Error: `line 1, column 8: make_date: date 2026-2-30 does not exist`

<a id="make_timestamp"></a>

## make_timestamp

Syntax:

```sql
make_timestamp(year, month, day, hour, minute, second)
```

Builds a `TIMESTAMP` from its parts. The parts are **UTC**. `second` may have a fraction: `30.5` is 30 seconds and 500 milliseconds.

| Argument | Type | Meaning |
|---|---|---|
| `year`, `month`, `day` | whole numbers | the date, as in [make_date](#make_date) |
| `hour` | whole number | 0 to 23 |
| `minute` | whole number | 0 to 59 |
| `second` | number | 0 to less than 60, with a fraction for milliseconds |

- **Returns:** `TIMESTAMP` (UTC).
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** a date that does not exist, or a time out of range (`24:00`), is an error. For a **Nepal** clock time subtract `20700000` ms (5 h 45 min): `make_timestamp(2026, 9, 10, 11, 0, 0) - 20700000` is 11:00 in Kathmandu.

**Example**

```sql
SELECT make_timestamp(2026, 9, 10, 5, 15, 30.5) AS utc_time,
       make_timestamp(2026, 9, 10, 11, 0, 0) - 20700000 AS market_opens;
```

Result:

| utc_time (TIMESTAMP) | market_opens (TIMESTAMP) |
|---|---|
| 2026-09-10T05:15:30.500Z | 2026-09-10T05:15:00.000Z |

(1 row)

**Example: Hour 24 is out of range** (shows an error)

```sql
SELECT make_timestamp(2026, 9, 10, 24, 0, 0);
```

Result:

Error: `line 1, column 8: make_timestamp: the time of day is out of range`

<a id="to_char"></a>

## to_char

Syntax:

```sql
to_char(t, format)
to_char(t, format, time_zone)
```

Writes a time as text in the format you want. `to_char('2026-09-10T08:30:00Z', 'DD Mon YYYY')` is `10 Sep 2026`. With a time zone, the time is first moved to that zone: this is the easy way to show **Nepal time**. To write a **number** (`to_char(1234.5, 'FM999,999.00')`), see [to_char for numbers](functions-text.md#to_char-number).

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time |
| `format` | text | the pattern; the codes are in the table below |
| `time_zone` | text | optional: a zone name like `'Asia/Kathmandu'`, or an offset like `'+05:45'` or `'-03:00'`. Without it: UTC |

Format codes (upper and lower case matter):

| Code | Meaning | 2026-09-10 15:30:05.042 UTC gives |
|---|---|---|
| `YYYY` | year, 4 digits | `2026` |
| `YY` | last 2 digits of the year | `26` |
| `MM` | month number, 2 digits | `09` |
| `Mon` / `MON` / `mon` | short month name | `Sep` / `SEP` / `sep` |
| `Month` / `MONTH` / `month` | full month name | `September` / `SEPTEMBER` / `september` |
| `DD` | day of the month, 2 digits | `10` |
| `DDD` | day of the year, 3 digits (001-366) | `253` |
| `Dy` / `DY` / `dy` | short weekday name | `Thu` / `THU` / `thu` |
| `Day` / `DAY` / `day` | full weekday name | `Thursday` / `THURSDAY` / `thursday` |
| `D` | weekday number, `1` = Sunday ... `7` = Saturday | `5` |
| `HH24` | hour 00-23 | `15` |
| `HH12`, `HH` | hour 01-12 | `03` |
| `MI` | minute, 2 digits | `30` |
| `SS` | second, 2 digits | `05` |
| `MS` | millisecond, 3 digits | `042` |
| `AM`, `PM` | `AM` or `PM` (both codes give the right one) | `PM` |
| `am`, `pm` | `am` or `pm` | `pm` |
| `Q` | quarter of the year, 1-4 | `3` |
| `FM` | accepted and ignored (names are never padded; numbers stay 2 digits) | |
| `"text"` | text in double quotes is copied as it is | |

Time zones: `UTC`, `GMT`, `Z`, `Etc/UTC`, `Asia/Kathmandu`, `Asia/Katmandu`, `NPT`, `Asia/Kolkata`, `Asia/Calcutta`, `IST`, `Asia/Colombo`, `Asia/Dhaka`, `Asia/Thimphu`, `Asia/Karachi`, `Asia/Dubai`, `Asia/Bangkok`, `Asia/Jakarta`, `Asia/Shanghai`, `Asia/Hong_Kong`, `Asia/Singapore`, `Asia/Taipei`, `Asia/Tokyo`, `Asia/Seoul` (any case), or an offset with a sign: `'+05:45'`, `'-03:00'`.

- **Returns:** `STRING`.
- **NULL:** `NULL` when any argument is `NULL` (also a `NULL` time zone).
- **Notes:**
  - Every other character is copied as it is: `-`, `/`, `:`, spaces, and letters that are not a code.
  - Careful with words: letters that are a code are replaced. `'Date: DD'` gives `5ate: 10`, because `D` is the weekday number. Put words in double quotes: `'"Date:" DD'`.
  - Zones that change for summer time (like `Europe/London`) are refused. An offset needs its sign: `'05:45'` and `'+0545'` are errors.
  - `WW` (week of the year) and other PostgreSQL codes are not supported; they are copied as text.
  - The result is text, so `ORDER BY` on it sorts like text: `'Aug 2026'` comes before `'Sep 2025'`. Also select a sortable form like `'YYYY-MM'` and order by that (after `GROUP BY`, `ORDER BY` can only use result columns).

**Example**

```sql
SELECT to_char('2026-09-10T15:30:05.042Z', 'YYYY-MM-DD HH24:MI:SS.MS') AS iso,
       to_char('2026-09-10T15:30:05.042Z', 'Dy, DD Mon YYYY HH12:MI AM') AS english,
       to_char('2026-09-10T15:30:05.042Z', 'DDD Q D') AS day_of_year_quarter_weekday,
       to_char(CAST('2026-09-10' AS DATE), 'DD/MM/YYYY') AS from_date;
```

Result:

| iso (STRING) | english (STRING) | day_of_year_quarter_weekday (STRING) | from_date (STRING) |
|---|---|---|---|
| 2026-09-10 15:30:05.042 | Thu, 10 Sep 2026 03:30 PM | 253 3 5 | 10/09/2026 |

(1 row)

**Example: Show a UTC time in Nepal time**

```sql
SELECT to_char('2026-09-10T05:15:00Z', 'YYYY-MM-DD HH24:MI') AS utc,
       to_char('2026-09-10T05:15:00Z', 'YYYY-MM-DD HH24:MI', 'Asia/Kathmandu') AS nepal,
       to_char('2026-09-10T05:15:00Z', 'HH12:MI am', '+05:45') AS nepal_12h,
       to_char('2026-09-10T05:15:00Z', 'HH24:MI', 'Asia/Tokyo') AS tokyo;
```

Result:

| utc (STRING) | nepal (STRING) | nepal_12h (STRING) | tokyo (STRING) |
|---|---|---|---|
| 2026-09-10 05:15 | 2026-09-10 11:00 | 11:00 am | 14:15 |

(1 row)

**Example: Last COAST trades of the day with the Nepal clock time** (sample data: sample)

```sql
SELECT to_char(time, 'HH24:MI', 'Asia/Kathmandu') AS nepal_time, close, volume
FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10'
ORDER BY time DESC
LIMIT 3;
```

Result:

| nepal_time (STRING) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|
| 14:59 | 376.1 | 1060 |
| 14:58 | 376.2 | 1320 |
| 14:57 | 376 | 1150 |

(3 rows)

**Example: App sign-ups per Nepal date** (sample data: fn-dates)

```sql
SELECT to_char(created_at, 'YYYY-MM-DD', 'Asia/Kathmandu') AS nepal_date, count(*) AS signups
FROM signups
GROUP BY to_char(created_at, 'YYYY-MM-DD', 'Asia/Kathmandu')
ORDER BY nepal_date;
```

Result:

| nepal_date (STRING) | signups (LONG) |
|---|---|
| 2026-09-01 | 3 |
| 2026-09-02 | 2 |
| 2026-09-03 | 3 |
| 2026-09-04 | 1 |
| 2026-09-06 | 1 |

(5 rows)

**Example: Month report with month names** (sample data: sample)

```sql
SELECT to_char(time, 'YYYY-MM') AS sort_key, to_char(time, 'Mon YYYY') AS month,
       round(sum(close * volume) / 1000000, 2) AS turnover_millions
FROM ochl_day
WHERE symbol = 'VOLT'
GROUP BY to_char(time, 'YYYY-MM'), to_char(time, 'Mon YYYY')
ORDER BY sort_key;
```

Result:

| sort_key (STRING) | month (STRING) | turnover_millions (DOUBLE) |
|---|---|---|
| 2025-12 | Dec 2025 | 79.27 |
| 2026-08 | Aug 2026 | 119.22 |
| 2026-09 | Sep 2026 | 128.05 |

(3 rows)

**Example: Words in the format: use double quotes**

```sql
SELECT to_char('2026-09-10', 'Date: DD') AS wrong, to_char('2026-09-10', '"Date:" DD') AS right;
```

Result:

| wrong (STRING) | right (STRING) |
|---|---|
| 5ate: 10 | Date: 10 |

(1 row)

**Example: Zones with summer time are refused** (shows an error)

```sql
SELECT to_char('2026-09-10T05:15:00Z', 'HH24:MI', 'Europe/London');
```

Result:

Error: `line 1, column 8: to_char: time zone 'Europe/London' is not supported (it may change for daylight saving); use a fixed offset like '+05:45'`

<a id="fiscal_year"></a>

## fiscal_year

Syntax:

```sql
fiscal_year(t)
fiscal_year(t, start_month)
fiscal_year(t, start_month, start_day)
```

The **fiscal year** (financial year) of a date, as the calendar year in which that fiscal year **starts**. A fiscal year is the 12-month year a company or a government uses for its accounts and taxes. It often does not start on 1 January: in Nepal it starts in mid-July, in India on 1 April.

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the date |
| `start_month` | whole number | the month the fiscal year starts, 1-12; default `7` (July, Nepal) |
| `start_day` | whole number | the day of that month it starts, 1-28; default `17` (see the notes) |

- **Returns:** `LONG`: `2025` means the fiscal year that started in 2025 (for Nepal: 2025-07-17 to 2026-07-16).
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:**
  - The default start is **17 July**, about Shrawan 1, the start of Nepal's fiscal year. For Nepal's own name of the year (like `2082/83`) use [nepal_fiscal_year](#nepal_fiscal_year).
  - Careful: `start_day` has the default `17` also when you give only `start_month`. For India write `fiscal_year(t, 4, 1)`, not `fiscal_year(t, 4)`.
  - `start_month` outside 1-12 or `start_day` outside 1-28 is an error.
  - The date is the UTC date: add `20700000` for a Nepal date just after midnight.

**Example**

```sql
SELECT fiscal_year('2026-07-16') AS last_day_of_fy_2025, fiscal_year('2026-07-17') AS first_day_of_fy_2026,
       fiscal_year('2026-03-31', 4, 1) AS india_before_april, fiscal_year('2026-04-01', 4, 1) AS india_april,
       fiscal_year('2026-09-10', 1, 1) AS calendar_year;
```

Result:

| last_day_of_fy_2025 (LONG) | first_day_of_fy_2026 (LONG) | india_before_april (LONG) | india_april (LONG) | calendar_year (LONG) |
|---|---|---|---|---|
| 2025 | 2026 | 2025 | 2026 | 2026 |

(1 row)

**Example: Sales per fiscal year (Nepal start, 17 July)** (sample data: analysis-finance)

```sql
SELECT fiscal_year(invoice_date) AS fiscal_year, count(*) AS invoices, sum(amount) AS sales
FROM invoices
GROUP BY fiscal_year(invoice_date)
ORDER BY fiscal_year;
```

Result:

| fiscal_year (LONG) | invoices (LONG) | sales (DECIMAL(2)) |
|---|---|---|
| 2024 | 2 | 13500.00 |
| 2025 | 7 | 48000.00 |
| 2026 | 3 | 18000.00 |

(3 rows)

**Example: Day 29 or later cannot start a fiscal year** (shows an error)

```sql
SELECT fiscal_year('2026-09-10', 1, 31);
```

Result:

Error: `line 1, column 8: fiscal_year: the start month must be 1-12 and the start day 1-28`

<a id="fiscal_quarter"></a>

## fiscal_quarter

Syntax:

```sql
fiscal_quarter(t)
fiscal_quarter(t, start_month)
fiscal_quarter(t, start_month, start_day)
```

The quarter **inside the fiscal year**, from `1` to `4`. Each fiscal quarter is 3 months counted from the start day: with the Nepal start (17 July), quarter 1 is 17 July to 16 October, quarter 2 is 17 October to 16 January, and so on. Banks and listed companies in Nepal publish their quarterly reports by these quarters.

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the date |
| `start_month` | whole number | the month the fiscal year starts, 1-12; default `7` |
| `start_day` | whole number | the day it starts, 1-28; default `17` |

- **Returns:** `LONG`, 1 to 4.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** the same start rules as [fiscal_year](#fiscal_year) (also the default day `17` when only `start_month` is given). With `fiscal_quarter(t, 1, 1)` it is the calendar quarter, like [quarter](#quarter).

**Example**

```sql
SELECT fiscal_quarter('2026-07-17') AS q1_start, fiscal_quarter('2026-10-16') AS q1_end, fiscal_quarter('2026-10-17') AS q2_start,
       fiscal_quarter('2027-07-16') AS q4_end, fiscal_quarter('2026-09-10', 4, 1) AS india, fiscal_quarter('2026-09-10', 1, 1) AS calendar;
```

Result:

| q1_start (LONG) | q1_end (LONG) | q2_start (LONG) | q4_end (LONG) | india (LONG) | calendar (LONG) |
|---|---|---|---|---|---|
| 1 | 1 | 2 | 4 | 2 | 3 |

(1 row)

**Example: Quarterly sales report of the fiscal year** (sample data: analysis-finance)

```sql
SELECT nepal_fiscal_year(invoice_date) AS fiscal_year, fiscal_quarter(invoice_date) AS quarter,
       count(*) AS invoices, sum(amount) AS sales
FROM invoices
GROUP BY nepal_fiscal_year(invoice_date), fiscal_quarter(invoice_date)
ORDER BY fiscal_year, quarter;
```

Result:

| fiscal_year (STRING) | quarter (LONG) | invoices (LONG) | sales (DECIMAL(2)) |
|---|---|---|---|
| 2081/82 | 4 | 2 | 13500.00 |
| 2082/83 | 1 | 2 | 13500.00 |
| 2082/83 | 2 | 2 | 6000.00 |
| 2082/83 | 3 | 1 | 12000.00 |
| 2082/83 | 4 | 2 | 16500.00 |
| 2083/84 | 1 | 3 | 18000.00 |

(6 rows)

<a id="nepal_fiscal_year"></a>

## nepal_fiscal_year

Syntax:

```sql
nepal_fiscal_year(t)
```

The name of **Nepal's fiscal year** of a date, as Nepal writes it in the Bikram Sambat (BS) calendar: `'2083/84'`. Nepal's fiscal year (arthik barsa) starts on **Shrawan 1**, which is about 16 or 17 July, and ends at the end of Ashadh the next year. Companies, banks and the tax office in Nepal use it for their reports.

| Argument | Type | Meaning |
|---|---|---|
| `t` | `TIMESTAMP`, `DATE`, time text or milliseconds | the date |

- **Returns:** `STRING` like `'2082/83'`: the BS year in which the fiscal year starts, a slash, and the last two digits of the next BS year.
- **NULL:** `nepal_fiscal_year(NULL)` is `NULL`.
- **Notes:**
  - KarelaDB does **not** convert dates to the BS calendar. It uses a fixed start of **17 July** every year and adds 57 years. Shrawan 1 moves by a day between years, so a date on 16 or 17 July can be in the wrong year; check those days with the official calendar when it matters.
  - The same as `fiscal_year(t)` plus 57, written as a text. The date is the UTC date.

**Example**

```sql
SELECT nepal_fiscal_year('2026-07-16') AS before_shrawan, nepal_fiscal_year('2026-07-17') AS shrawan_1,
       nepal_fiscal_year('2026-09-10') AS today, nepal_fiscal_year(CAST('2000-01-01' AS DATE)) AS year_2000;
```

Result:

| before_shrawan (STRING) | shrawan_1 (STRING) | today (STRING) | year_2000 (STRING) |
|---|---|---|---|
| 2082/83 | 2083/84 | 2083/84 | 2056/57 |

(1 row)

**Example: Sales per Nepal fiscal year** (sample data: analysis-finance)

```sql
SELECT nepal_fiscal_year(invoice_date) AS fiscal_year, min(invoice_date) AS first_invoice, max(invoice_date) AS last_invoice,
       count(*) AS invoices, sum(amount) AS sales
FROM invoices
GROUP BY nepal_fiscal_year(invoice_date)
ORDER BY fiscal_year;
```

Result:

| fiscal_year (STRING) | first_invoice (TIMESTAMP) | last_invoice (TIMESTAMP) | invoices (LONG) | sales (DECIMAL(2)) |
|---|---|---|---|---|
| 2081/82 | 2025-06-20T00:00:00.000Z | 2025-07-16T00:00:00.000Z | 2 | 13500.00 |
| 2082/83 | 2025-07-17T00:00:00.000Z | 2026-07-10T00:00:00.000Z | 7 | 48000.00 |
| 2083/84 | 2026-07-20T00:00:00.000Z | 2026-09-10T00:00:00.000Z | 3 | 18000.00 |

(3 rows)

**Example: Expenses of the accounting book per fiscal year** (sample data: query-app)

```sql
SELECT nepal_fiscal_year(l.entry_date) AS fiscal_year, a.name AS expense, sum(l.debit) AS amount
FROM ledger l
JOIN accounts a ON a.code = l.account
WHERE a.type = 'expense'
GROUP BY nepal_fiscal_year(l.entry_date), a.name
ORDER BY fiscal_year, expense;
```

Result:

| fiscal_year (STRING) | expense (STRING) | amount (DECIMAL(2)) |
|---|---|---|
| 2083/84 | Broker commission | 1030.00 |
| 2083/84 | Office rent | 25000.00 |

(2 rows)

<a id="nepal-time"></a>

## Local time, for example Nepal

Syntax:

```sql
'2026-09-10T11:00:00+05:45'        -- write Nepal times with +05:45
to_timezone(time, 'Asia/Kathmandu')  -- the Nepal clock time (also time + 20700000)
to_char(time, format, 'Asia/Kathmandu')
time IN '2026-09-10' TIME ZONE 'Asia/Kathmandu'
date_trunc('day', time, 'Asia/Kathmandu')
SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu'
```

KarelaDB stores and shows every time in UTC. These tips use Nepal time as the example local zone: UTC + 5 hours 45 minutes, all year (Nepal has no summer time). For another zone change the offset and the milliseconds, for example `-05:00` and `- 18000000` for New York in winter. In a zone with summer time the fixed number is right for only part of the year.

| Task | Write |
|---|---|
| Put a Nepal time into KarelaDB | `'2026-09-10T11:00:00+05:45'` (without `+05:45` the text is read as UTC) |
| Nepal hour, minute, day, weekday | `hour(to_timezone(time, 'Asia/Kathmandu'))`, or add 20700000 ms: `day_of_week(time + 20700000)` |
| Show a time in Nepal time | `to_char(time, 'YYYY-MM-DD HH24:MI', 'Asia/Kathmandu')` |
| Rows of one Nepal day | `WHERE time IN '2026-09-10' TIME ZONE 'Asia/Kathmandu'` (see [time IN](where.md#in-interval)) |
| Nepal midnight of a time | `date_trunc('day', time, 'Asia/Kathmandu')` or `timestamp_floor('1d', time, 'Asia/Kathmandu')` |
| Store daily bars at Nepal midnight | a column `time TIMESTAMP ROUND 1d TIME ZONE 'Asia/Kathmandu'` (see [TIME ZONE](sample-by.md#time-zone)) |
| Candles by Nepal hours or days | `SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu'` (see [TIME ZONE](sample-by.md#time-zone)) |
| QuestDB `to_timezone(time, 'Asia/Kathmandu')` (UTC to the local clock) | the same: [to_timezone](#to_timezone) |
| QuestDB `to_utc(time, 'Asia/Kathmandu')` (a local clock to UTC) | the same: [to_utc](#to_timezone), or `time AT TIME ZONE 'Asia/Kathmandu'` |

- **Notes:** `to_timezone(...)` and `+ 20700000` give a `TIMESTAMP` that is shown with `Z` but holds the Nepal clock time. Use them inside `hour()`, `day()` and so on, not to store. `NPT` and `Asia/Kathmandu` are the same zone. More in [time and time zones](time-and-time-zones.md).

**Example: QuestDB to_timezone and to_utc, and the older ways**

```sql
SELECT to_timezone('2026-09-10T05:15:00Z', 'Asia/Kathmandu') AS to_timezone,
       CAST('2026-09-10T05:15:00Z' AS TIMESTAMP) + 20700000 AS plus_ms,
       to_utc('2026-09-10T11:00:00Z', 'Asia/Kathmandu') AS to_utc,
       CAST('2026-09-10T11:00:00Z' AS TIMESTAMP) AT TIME ZONE 'Asia/Kathmandu' AS at_time_zone;
```

Result:

| to_timezone (TIMESTAMP) | plus_ms (TIMESTAMP) | to_utc (TIMESTAMP) | at_time_zone (TIMESTAMP) |
|---|---|---|---|
| 2026-09-10T11:00:00.000Z | 2026-09-10T11:00:00.000Z | 2026-09-10T05:15:00.000Z | 2026-09-10T05:15:00.000Z |

(1 row)

**Example: One market opening minute (11:00 in Nepal), three ways**

```sql
SELECT CAST('2026-09-10T11:00:00+05:45' AS TIMESTAMP) AS stored_utc,
       hour('2026-09-10T11:00:00+05:45') AS utc_hour,
       hour(CAST('2026-09-10T11:00:00+05:45' AS TIMESTAMP) + 20700000) AS nepal_hour;
```

Result:

| stored_utc (TIMESTAMP) | utc_hour (LONG) | nepal_hour (LONG) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | 5 | 11 |

(1 row)

**Example: All minute candles of one Nepal trading day** (sample data: sample)

```sql
SELECT count(*) AS candles, min(time) AS first_utc, max(time) AS last_utc
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10' TIME ZONE 'Asia/Kathmandu';
```

Result:

| candles (LONG) | first_utc (TIMESTAMP) | last_utc (TIMESTAMP) |
|---|---|---|
| 240 | 2026-09-10T05:15:00.000Z | 2026-09-10T09:14:00.000Z |

(1 row)

**Example: Hourly COAST candles on the Nepal clock** (sample data: sample)

```sql
SELECT time, count(*) AS minutes, first(open) AS open, last(close) AS close
FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10'
SAMPLE BY 1h TIME ZONE 'Asia/Kathmandu';
```

Result:

| time (TIMESTAMP) | minutes (LONG) | open (DOUBLE) | close (DOUBLE) |
|---|---|---|---|
| 2026-09-10T05:15:00.000Z | 60 | 380.1 | 381.3 |
| 2026-09-10T06:15:00.000Z | 56 | 381.3 | 378.4 |
| 2026-09-10T07:15:00.000Z | 60 | 378.4 | 376.4 |
| 2026-09-10T08:15:00.000Z | 60 | 376.4 | 376.1 |

(4 rows)

<a id="current_date"></a>

## current_date

Syntax:

```sql
current_date
current_date()
```

Today's date on the [session's clock](time-and-time-zones.md#session-time-zone) (UTC unless `SET TIME ZONE` names a zone). The PostgreSQL name; KarelaDB gives the same as `CAST(now() AS DATE)`.

- **Returns:** `DATE`.
- **NULL:** never `NULL`.
- **Notes:** UTC, not Nepal time. After 18:15 Nepal time it is already the next UTC day, so for a Nepal day use `CAST(now() + 20700000 AS DATE)` (see [Nepal time](#nepal-time)). It may be written with or without `()`.

**Example: Save the day a user logged in**

Setup:

```sql
CREATE TABLE user_logins (user_id INT PRIMARY KEY, login_day DATE DEFAULT current_date);
INSERT INTO user_logins (user_id) VALUES (7);
```

```sql
SELECT user_id, login_day = current_date AS logged_in_today FROM user_logins;
```

Result:

| user_id (INT) | logged_in_today (BOOL) |
|---|---|
| 7 | true |

(1 row)

**Example: Today in UTC and on the Nepal clock**

```sql
SELECT current_date AS utc_day,
       CAST(now() + 20700000 AS DATE) AS nepal_day,
       current_date = CAST(now() AS DATE) AS same_as_now;
```

Result:

| utc_day (DATE) | nepal_day (DATE) | same_as_now (BOOL) |
|---|---|---|
| 2026-10-24 | 2026-10-24 | true |

(1 row)

<a id="current_time"></a>

## current_time, localtime

Syntax:

```sql
current_time
current_time()
localtime
localtime()
```

The clock time of day now, on the [session's clock](time-and-time-zones.md#session-time-zone) (UTC unless set), as text: `HH:MM:SS.mmm`. `localtime` is the same function.

- **Returns:** `STRING`, 12 characters, like `05:15:00.000`.
- **NULL:** never `NULL`.
- **Notes:** KarelaDB has no `TIME` type, so this is text. To compare times of day, compare the text (`current_time < '09:00:00.000'`) or use `hour(now())`. For a Nepal clock time use `to_str(now() + 20700000, 'HH:mm:ss')`.

**Example: Is the market session open right now (Nepal clock)?**

```sql
SELECT current_time AS utc_time_of_day,
       to_str(now() + 20700000, 'HH:mm') AS nepal_clock,
       localtime = current_time AS localtime_is_the_same;
```

Result:

| utc_time_of_day (STRING) | nepal_clock (STRING) | localtime_is_the_same (BOOL) |
|---|---|---|
| 07:56:05.513 | 13:41 | true |

(1 row)

<a id="localtimestamp"></a>

## localtimestamp

Syntax:

```sql
localtimestamp
localtimestamp()
localtimestamp(digits)
```

The time now on the [session's clock](time-and-time-zones.md#session-time-zone), the PostgreSQL name for a time without a zone. In a UTC session it is the same as `now()`; after `SET TIME ZONE 'Asia/Kathmandu'` it is 5 h 45 min later (the Nepal wall clock, still shown with `Z`).

| Argument | Type | Meaning |
|---|---|---|
| `digits` | `INT` | how many digits after the second PostgreSQL would keep; KarelaDB always keeps milliseconds, so it changes nothing |

- **Returns:** `TIMESTAMP`.
- **NULL:** never `NULL`.
- **Notes:** the same value for the whole statement, like `now()`.

**Example**

```sql
SELECT localtimestamp = now() AS same_as_now, year(localtimestamp) >= 2026 AS year_ok;
```

Result:

| same_as_now (BOOL) | year_ok (BOOL) |
|---|---|
| true | true |

(1 row)

<a id="transaction_timestamp"></a>

## transaction_timestamp, statement_timestamp, clock_timestamp

Syntax:

```sql
transaction_timestamp()
statement_timestamp()
clock_timestamp()
```

Three PostgreSQL names for the time now. In PostgreSQL they differ (start of the transaction, start of the statement, the clock right now). KarelaDB gives the same time for all three: the time the statement started.

- **Returns:** `TIMESTAMP`.
- **NULL:** never `NULL`.
- **Notes:** `clock_timestamp()` in PostgreSQL moves on inside one statement; in KarelaDB it does not, so you cannot use it to time a loop. Use it only for app code that came from PostgreSQL.

**Example: All three are the time this statement started**

```sql
SELECT transaction_timestamp() = statement_timestamp() AS same_1,
       statement_timestamp() = clock_timestamp() AS same_2,
       clock_timestamp() = now() AS same_as_now;
```

Result:

| same_1 (BOOL) | same_2 (BOOL) | same_as_now (BOOL) |
|---|---|---|
| true | true | true |

(1 row)

<a id="make_interval"></a>

## make_interval

Syntax:

```sql
make_interval(years, months, weeks, days, hours, minutes, seconds)
```

Builds an interval (a length of time) from numbers. Every argument may be left out from the right; what is left out is `0`.

| Argument | Type | Meaning |
|---|---|---|
| `years` | number | years (12 months each) |
| `months` | number | months |
| `weeks` | number | weeks (7 days each) |
| `days` | number | days |
| `hours` | number | hours |
| `minutes` | number | minutes |
| `seconds` | number | seconds |

- **Returns:** `INTERVAL`. Add it to a time with `+`, take it off with `-`.
- **NULL:** any `NULL` argument gives `NULL`.
- **Notes:** a fraction is carried down, as PostgreSQL does: half a month becomes 15 days, half a day becomes 12 hours. Text that is a number (`'3'`) is accepted, so a driver parameter works. `INTERVAL '15 minutes'` writes the same thing shorter.

**Example: The candle 15 minutes after each market minute** (sample data: sample)

```sql
SELECT time, time + make_interval(0, 0, 0, 0, 0, 15, 0) AS fifteen_minutes_later
FROM ochl_minutes
WHERE symbol = 'CITY'
ORDER BY time
LIMIT 3;
```

Result:

| time (TIMESTAMP) | fifteen_minutes_later (TIMESTAMP) |
|---|---|
| 2026-09-09T05:15:00.000Z | 2026-09-09T05:30:00.000Z |
| 2026-09-09T05:16:00.000Z | 2026-09-09T05:31:00.000Z |
| 2026-09-09T05:17:00.000Z | 2026-09-09T05:32:00.000Z |

(3 rows)

**Example: Years, months, weeks and a fraction**

```sql
SELECT make_interval(1, 2, 0, 3) AS year_month_day,
       make_interval(0, 0, 2) AS two_weeks,
       make_interval(0, 0, 0, 0, 1, 30) AS ninety_minutes,
       make_interval(0, 0.5) AS half_a_month;
```

Result:

| year_month_day (INTERVAL) | two_weeks (INTERVAL) | ninety_minutes (INTERVAL) | half_a_month (INTERVAL) |
|---|---|---|---|
| 1 year 2 mons 3 days | 14 days | 01:30:00 | 15 days |

(1 row)

<a id="justify_days"></a>

## justify_days, justify_hours, justify_interval

Syntax:

```sql
justify_days(interval)
justify_hours(interval)
justify_interval(interval)
```

Write an interval in bigger units: `justify_days` turns every 30 days into a month, `justify_hours` turns every 24 hours into a day, and `justify_interval` does both and also makes the signs agree.

| Argument | Type | Meaning |
|---|---|---|
| `interval` | `INTERVAL` | the length of time to tidy up |

- **Returns:** `INTERVAL`.
- **NULL:** a `NULL` interval gives `NULL`. A value that is not an `INTERVAL` is an error.
- **Notes:** a month counts as 30 days here, as in PostgreSQL. So `justify_days` is for showing a length to a reader, not for exact day counts; use [datediff](#datediff) for those.

**Example: 45 days and 50 hours, written for a reader**

```sql
SELECT justify_days(INTERVAL '45 days') AS in_months,
       justify_hours(INTERVAL '50 hours') AS in_days,
       justify_interval(INTERVAL '45 days 50 hours') AS both;
```

Result:

| in_months (INTERVAL) | in_days (INTERVAL) | both (INTERVAL) |
|---|---|---|
| 1 mon 15 days | 2 days 02:00:00 | 1 mon 17 days 02:00:00 |

(1 row)

**Example: How long a dividend book closure lasted**

```sql
SELECT justify_interval(make_interval(0, 0, 0, 40, 30)) AS book_closure_length;
```

Result:

| book_closure_length (INTERVAL) |
|---|
| 1 mon 11 days 06:00:00 |

(1 row)
