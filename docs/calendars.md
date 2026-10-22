# Trading calendars

> Say which days a market trades - its weekdays, how they changed over the years, and its holidays - and ask it in SQL and in timers.

- Category: Time-series
- Keywords: missing days, gaps, data gaps, missing bars, missing_bars, calendar, calendars, trading calendar, trading day, trading days, market days, business days, working days, holiday, holidays, era, eras, trading week, sun-thu, mon-fri, week change, NEPSE, CREATE CALENDAR, ALTER CALENDAR, DROP CALENDAR, ADD HOLIDAY, ADD TRADING DAY, is_trading_day, next_trading_day, prev_trading_day, trading_days_between, suggest_calendar_eras, kdb_calendars, trading nepse 15:05
- See also: [Date and time functions](functions-date-time.md), [Timers](timers.md), [Time and time zones](time-and-time-zones.md), [SAMPLE BY](sample-by.md)

A **trading calendar** says which days a market trades. It lives in one database, next to its tables, and SQL functions and [timers](timers.md) read it.

A market's week can change. NEPSE traded **Sunday to Thursday** until 2026-04-05, then **Monday to Friday** from 2026-04-10. So a calendar is a list of **eras**: each era says from which day on which weekdays trade. On top of the eras come single days:

| Part | Example | Meaning |
|---|---|---|
| era | `ERA FROM '2022-01-01' DAYS sun-thu` | from this day on, these weekdays trade (until the next era) |
| holiday | `HOLIDAY '2026-10-20' 'Dashain'` | no trading on a day the era trades |
| extra trading day | `TRADING DAY '2022-01-07' 'Friday session'` | a session on a day the era does not trade |
| time zone | `TIME ZONE 'Asia/Kathmandu'` | which clock a `TIMESTAMP` is read on (UTC when not given) |

- A day before the first era is not a trading day (unless it is an extra trading day).
- Weekdays: `sun mon tue wed thu fri sat` (or the full names). A range may go past Saturday: `fri-sun`. A list: `mon,wed,fri`.
- Dates are written `'yyyy-mm-dd'`.

<a id="create-calendar"></a>

## CREATE CALENDAR

Syntax:

```sql
CREATE CALENDAR [IF NOT EXISTS] name (
  [TIME ZONE 'zone',]
  ERA FROM 'date' DAYS weekdays [, ERA FROM 'date' DAYS weekdays ...]
  [, HOLIDAY 'date' ['note'] ...]
  [, TRADING DAY 'date' ['note'] ...]
)
```

- A calendar needs at least one era. Two eras cannot start on the same day.
- `TIME ZONE` takes any zone: `'Asia/Kathmandu'`, `'UTC'`, `'+05:45'`, or one with summer time such as `'America/New_York'` (a moment's day is on the offset in force then; [summer time](time-and-time-zones.md#summer-time)).
- **Role:** `ddl`, like `CREATE TYPE`. It is saved at once, so it cannot go inside `BEGIN` ... `COMMIT`.

**Example: NEPSE: Sunday to Thursday, then Monday to Friday**

```sql
CREATE CALENDAR nepse (
  TIME ZONE 'Asia/Kathmandu',
  ERA FROM '2022-01-01' DAYS sun-thu,
  ERA FROM '2026-04-10' DAYS mon-fri
);
SELECT is_trading_day('nepse', '2026-04-05') AS sun_before,
       is_trading_day('nepse', '2026-04-10') AS fri_after,
       is_trading_day('nepse', '2026-04-12') AS sun_after;
```

Result:

`CREATE CALENDAR nepse (TIME ZONE 'Asia/Kathmandu', ERA FROM '2022-01-01' DAYS 'sun-thu', ERA FROM '2`

```text
calendar 'nepse' created: 2 era(s), 0 holiday(s), 0 extra trading day(s)
```

`SELECT is_trading_day('nepse', '2026-04-05') AS sun_before, is_trading_day('nepse', '2026-04-10') AS`

| sun_before (BOOL) | fri_after (BOOL) | sun_after (BOOL) |
|---|---|---|
| true | true | false |

(1 row)

<a id="alter-calendar"></a>

## ALTER CALENDAR

Syntax:

```sql
ALTER CALENDAR [IF EXISTS] name ADD HOLIDAY 'date' ['note'] [, 'date' ['note'] ...]
ALTER CALENDAR [IF EXISTS] name DROP HOLIDAY 'date' [, 'date' ...]
ALTER CALENDAR [IF EXISTS] name ADD TRADING DAY 'date' ['note'] [, ...]
ALTER CALENDAR [IF EXISTS] name DROP TRADING DAY 'date' [, ...]
ALTER CALENDAR [IF EXISTS] name ADD ERA FROM 'date' DAYS weekdays
ALTER CALENDAR [IF EXISTS] name DROP ERA FROM 'date'
ALTER CALENDAR [IF EXISTS] name SET TIME ZONE 'zone'
```

| Rule | What happens |
|---|---|
| A holiday that is there already | its note is replaced |
| A day that is a holiday and is added as a trading day (or the other way) | refused: drop it first |
| A holiday on a day its era does not trade anyway (a Saturday) | kept, and the answer says so |
| `DROP HOLIDAY` of a day that is not a holiday | refused |
| `DROP ERA` of the last era | refused: a calendar needs one era |
| A day listed twice in one statement | refused |

The next query sees the change (also a [cached](performance-tips.md) result).

**Example: Holidays, one statement for many**

```sql
CREATE CALENDAR nepse (ERA FROM '2022-01-01' DAYS sun-thu, ERA FROM '2026-04-10' DAYS mon-fri);
ALTER CALENDAR nepse ADD HOLIDAY '2026-10-20' 'Dashain', '2026-10-21' 'Dashain', '2026-10-22' 'Dashain';
SELECT is_trading_day('nepse', '2026-10-21') AS holiday,
       next_trading_day('nepse', '2026-10-19') AS after_dashain;
```

Result:

`CREATE CALENDAR nepse (ERA FROM '2022-01-01' DAYS 'sun-thu', ERA FROM '2026-04-10' DAYS 'mon-fri')`

```text
calendar 'nepse' created: 2 era(s), 0 holiday(s), 0 extra trading day(s)
```

`ALTER CALENDAR nepse ADD HOLIDAY '2026-10-20' 'Dashain', '2026-10-21' 'Dashain', '2026-10-22' 'Dasha`

```text
calendar 'nepse' altered: 3 holiday(s) added
```

`SELECT is_trading_day('nepse', '2026-10-21') AS holiday, next_trading_day('nepse', '2026-10-19') AS `

| holiday (BOOL) | after_dashain (DATE) |
|---|---|
| false | 2026-10-23 |

(1 row)

**Example: An extra Friday session in the Sunday-Thursday years**

```sql
CREATE CALENDAR nepse (ERA FROM '2022-01-01' DAYS sun-thu, ERA FROM '2026-04-10' DAYS mon-fri);
ALTER CALENDAR nepse ADD TRADING DAY '2022-01-07' 'Friday session';
SELECT is_trading_day('nepse', '2022-01-07') AS extra, is_trading_day('nepse', '2022-01-14') AS plain_friday;
```

Result:

`CREATE CALENDAR nepse (ERA FROM '2022-01-01' DAYS 'sun-thu', ERA FROM '2026-04-10' DAYS 'mon-fri')`

```text
calendar 'nepse' created: 2 era(s), 0 holiday(s), 0 extra trading day(s)
```

`ALTER CALENDAR nepse ADD TRADING DAY '2022-01-07' 'Friday session'`

```text
calendar 'nepse' altered: 1 extra trading day(s) added
```

`SELECT is_trading_day('nepse', '2022-01-07') AS extra, is_trading_day('nepse', '2022-01-14') AS plai`

| extra (BOOL) | plain_friday (BOOL) |
|---|---|
| true | false |

(1 row)

**Example: A holiday cannot also be a trading day** (shows an error)

Setup:

```sql
CREATE CALENDAR nepse (ERA FROM '2022-01-01' DAYS sun-thu);
ALTER CALENDAR nepse ADD HOLIDAY '2026-10-20';
```

```sql
ALTER CALENDAR nepse ADD TRADING DAY '2026-10-20';
```

Result:

Error: `'2026-10-20' is a holiday of calendar nepse; DROP HOLIDAY '2026-10-20' first`

<a id="drop-calendar"></a>

## DROP CALENDAR

Syntax:

```sql
DROP CALENDAR [IF EXISTS] name [, name ...]
```

A timer with a `trading` schedule on a dropped calendar fails every day and says why, until you make the calendar again or change the schedule.

<a id="functions"></a>

## The functions

The calendar is named as text. It may come first or last: `is_trading_day('nepse', ts)` and `is_trading_day(ts, 'nepse')` are the same.

| Function | Returns | Meaning |
|---|---|---|
| `is_trading_day(cal, d)` | `BOOL` | `d` is a trading day |
| `next_trading_day(cal, d)` | `DATE` | the first trading day after `d` |
| `prev_trading_day(cal, d)` | `DATE` | the last trading day before `d`; `NULL` before the first one |
| `trading_days_between(cal, from, to)` | `LONG` | trading days `d` with `from <= d < to`; negative when `to` is before `from` (the rule of NumPy's `busday_count`) |

- **Which day:** a `DATE` or `'2026-04-10'` is that day. A `TIMESTAMP` is the day it falls on in the calendar's time zone: `2026-04-10 20:00 UTC` is Saturday 01:45 in Kathmandu.
- **NULL:** any `NULL` argument gives `NULL`.
- **Errors:** a calendar that does not exist is an error, never a quiet `false`.
- `is_trading_day(t)` with **one** argument is the old fixed Sunday-to-Thursday week on the UTC date, with no holidays ([date functions](functions-date-time.md#is_trading_day)).
- **Speed:** the calendar is looked up once per query and thread; each row is a few comparisons. `trading_days_between` counts whole weeks at once, so a range of ten years costs no more than a week.

**Example: Around the week change**

```sql
CREATE CALENDAR nepse (ERA FROM '2022-01-01' DAYS sun-thu, ERA FROM '2026-04-10' DAYS mon-fri);
SELECT next_trading_day('nepse', '2026-04-02') AS after_thu,
       next_trading_day('nepse', '2026-04-10') AS after_fri,
       prev_trading_day('nepse', '2026-04-13') AS before_mon,
       trading_days_between('nepse', '2026-04-01', '2026-04-15') AS days_1_to_14;
```

Result:

`CREATE CALENDAR nepse (ERA FROM '2022-01-01' DAYS 'sun-thu', ERA FROM '2026-04-10' DAYS 'mon-fri')`

```text
calendar 'nepse' created: 2 era(s), 0 holiday(s), 0 extra trading day(s)
```

`SELECT next_trading_day('nepse', '2026-04-02') AS after_thu, next_trading_day('nepse', '2026-04-10')`

| after_thu (DATE) | after_fri (DATE) | before_mon (DATE) | days_1_to_14 (LONG) |
|---|---|---|---|
| 2026-04-05 | 2026-04-13 | 2026-04-10 | 10 |

(1 row)

**Example: Rows that fall on a day the market was closed**

```sql
CREATE CALENDAR nepse (TIME ZONE 'Asia/Kathmandu', ERA FROM '2022-01-01' DAYS sun-thu, ERA FROM '2026-04-10' DAYS mon-fri);
CREATE TABLE ticks (ts TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESTAMP(ts) PARTITION BY DAY;
INSERT INTO ticks VALUES ('2026-04-09T05:15:00Z', 'CITY', 510), ('2026-04-10T05:15:00Z', 'CITY', 512),
                         ('2026-04-11T05:15:00Z', 'CITY', 511), ('2026-04-12T05:15:00Z', 'CITY', 513);
SELECT ts, price FROM ticks WHERE NOT is_trading_day('nepse', ts) ORDER BY ts;
```

Result:

`CREATE CALENDAR nepse (TIME ZONE 'Asia/Kathmandu', ERA FROM '2022-01-01' DAYS 'sun-thu', ERA FROM '2`

```text
calendar 'nepse' created: 2 era(s), 0 holiday(s), 0 extra trading day(s)
```

`CREATE TABLE ticks (`

```text
table 'ticks' created
```

`INSERT INTO ticks VALUES ('2026-04-09T05:15:00Z', 'CITY', 510), ('2026-04-10T05:15:00Z', 'CITY', 512`

```text
4 row(s) inserted
```

`SELECT ts, price FROM ticks WHERE NOT is_trading_day('nepse', ts) ORDER BY ts`

| ts (TIMESTAMP) | price (DOUBLE) |
|---|---|
| 2026-04-11T05:15:00.000Z | 511 |
| 2026-04-12T05:15:00.000Z | 513 |

(2 rows)

<a id="missing-days"></a>

## Find missing days

A trading day with no row is a gap in your data (a feed that stopped, a day not loaded). List the calendar's trading days between a symbol's first and last row with `generate_series`, and keep those without a row:

**Example: Trading days of CITY with no daily bar**

```sql
CREATE CALENDAR nepse (TIME ZONE 'Asia/Kathmandu', ERA FROM '2026-04-10' DAYS mon-fri, HOLIDAY '2026-09-24' 'holiday');
CREATE TABLE day_bars (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY MONTH;
INSERT INTO day_bars VALUES ('2026-09-21', 'CITY', 510), ('2026-09-23', 'CITY', 512), ('2026-09-25', 'CITY', 515);
SELECT d AS missing_day
FROM generate_series((SELECT min(time) FROM day_bars WHERE symbol = 'CITY')::DATE,
                     (SELECT max(time) FROM day_bars WHERE symbol = 'CITY')::DATE) AS d
WHERE is_trading_day('nepse', d)
  AND d NOT IN (SELECT time::DATE FROM day_bars WHERE symbol = 'CITY');
```

Result:

`CREATE CALENDAR nepse (TIME ZONE 'Asia/Kathmandu', ERA FROM '2026-04-10' DAYS 'mon-fri', HOLIDAY '20`

```text
calendar 'nepse' created: 1 era(s), 1 holiday(s), 0 extra trading day(s)
```

`CREATE TABLE day_bars (`

```text
table 'day_bars' created
```

`INSERT INTO day_bars VALUES ('2026-09-21', 'CITY', 510), ('2026-09-23', 'CITY', 512), ('2026-09-25',`

```text
3 row(s) inserted
```

`SELECT d AS missing_day FROM generate_series(CAST((SELECT min(time) FROM day_bars WHERE symbol = 'CI`

| missing_day (DATE) |
|---|
| 2026-09-22 |

(1 row)

22 September is missing; 24 September is a holiday, so it is not.

<a id="kdb_calendars"></a>

## See the calendars: kdb_calendars

`SELECT * FROM kdb_calendars` lists every calendar of the database: one row per era, holiday and extra trading day.

| Column | Meaning |
|---|---|
| `calendar` | the calendar's name |
| `time_zone` | its zone (`UTC` when none was given) |
| `kind` | `era`, `holiday` or `trading day` |
| `day` | the era's first day, or the day |
| `days` | an era's weekdays (`sun-thu`) |
| `note` | the note of a holiday or trading day |

**Example: What the calendar holds**

```sql
CREATE CALENDAR nepse (ERA FROM '2022-01-01' DAYS sun-thu, ERA FROM '2026-04-10' DAYS mon-fri);
ALTER CALENDAR nepse ADD HOLIDAY '2026-10-20' 'Dashain';
SELECT kind, day, days, note FROM kdb_calendars WHERE calendar = 'nepse' ORDER BY day;
```

Result:

`CREATE CALENDAR nepse (ERA FROM '2022-01-01' DAYS 'sun-thu', ERA FROM '2026-04-10' DAYS 'mon-fri')`

```text
calendar 'nepse' created: 2 era(s), 0 holiday(s), 0 extra trading day(s)
```

`ALTER CALENDAR nepse ADD HOLIDAY '2026-10-20' 'Dashain'`

```text
calendar 'nepse' altered: 1 holiday(s) added
```

`SELECT kind, day, days, note FROM kdb_calendars WHERE calendar = 'nepse' ORDER BY day`

| kind (STRING) | day (DATE) | days (STRING) | note (STRING) |
|---|---|---|---|
| era | 2022-01-01 | sun-thu | NULL |
| era | 2026-04-10 | mon-fri | NULL |
| holiday | 2026-10-20 | NULL | Dashain |

(3 rows)

<a id="suggest_calendar_eras"></a>

## Find the eras in your data: suggest_calendar_eras

Syntax:

```sql
suggest_calendar_eras(time [, 'zone'])
```

An aggregate: it looks at the days that have rows and writes a report as text:

- how many days of each weekday have data, per year, and how many of the era's weekdays have **no** data (holidays, or gaps in your data);
- the eras it found, and the days with data outside their era's weekdays (extra sessions);
- a `CREATE CALENDAR` statement to start from (and `ADD TRADING DAY` for the extra sessions).

How it decides: each week gets the weekdays that have data in most of the weeks around it (4 before, 4 after), so one holiday or one extra session does not count. Weeks in a row with the same weekdays are an era; an era is at least 8 weeks. Where two eras meet, the new era starts on the day that leaves the fewest days outside their era.

- Give the zone of the market when the times are UTC and a session could cross midnight UTC. The day is the local day in that zone.
- Check the days without data before you add them as holidays: they may be gaps in your data.

**Example: The weekdays of the sample candles** (sample data: sample)

```sql
SELECT suggest_calendar_eras(time, 'Asia/Kathmandu') AS report FROM ochl_day;
```

Result:

| report (STRING) |
|---|
| year    sun   mon   tue   wed   thu   fri   sat   no_data 2025      1     1     1     1     0     0     0      0 2026      3     3     3     3     3     0     0    166 eras: 2025-12-28 sun-thu era ... |

(1 row)

<a id="timers"></a>

## Timers on trading days

A [timer](timers.md#schedules) with the schedule `trading nepse 15:05` runs at 15:05 on the trading days of calendar `nepse` of its database only. It follows the calendar as it changes: a holiday added in the morning is skipped that afternoon. When the calendar is dropped, each run fails and says so.

<a id="stored"></a>

## How it is stored

Calendars are part of the database's catalog, like tables and [ENUM types](column-types.md#enum): in every backup, kept across restarts, and replayed from the log after a crash. A database with a calendar needs a KDB from 2026-09-25 or newer (feature `calendars`, see [versions](versions.md)).
