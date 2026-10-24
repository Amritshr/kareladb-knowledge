# Time and time zones

> How KarelaDB stores times (UTC milliseconds), how to write a local time with its offset (like +05:45), the session's time zone (SET TIME ZONE, --timezone), time zone names, and time ranges with IN '...'.

- Category: Time-series
- Keywords: time, times, UTC, Z, time zone, timezone, summer time, daylight saving, DST, America/New\_York, Europe/London, tzdata, zoneinfo, KARELADB\_ZONEINFO, SET TIME ZONE, SHOW TIME ZONE, --timezone, KARELADB\_TIMEZONE, CURRENT\_DATE, today, local time, zone offset, NPT, Nepal time, +05:45, Asia/Kathmandu, Asia/Katmandu, Asia/Kolkata, IST, GMT, daylight saving, TIMESTAMP, DATE, milliseconds, microseconds, epoch, time format, date format, ISO 8601, IN 'interval', time range, interval, trading hours, 20700000, to\_char, market open, market close
- See also: [SAMPLE BY (time-zone)](sample-by.md#time-zone), [WHERE (in-interval)](where.md#in-interval), [WHERE (between)](where.md#between), [Partitions, SORT BY and DEDUP KEY (partition-by)](partitions-and-dedup.md#partition-by), [Date and time functions](functions-date-time.md), [Operators (arithmetic)](operators.md#arithmetic), [Column types](column-types.md)

KarelaDB keeps every time in **UTC** (world time, the time at longitude 0). A local time is UTC plus or minus an offset: New York in summer is `-04:00`, Tokyo is `+09:00`. Most examples here use Nepal time (NPT), which is **5 hours 45 minutes ahead** of UTC and has no daylight saving time. So 11:00 in Kathmandu is 05:15 UTC.

Three rules cover almost everything:

1. When you **write** a local time, add its zone offset, for example `+05:45`: `'2026-09-10T11:00:00+05:45'`.
2. A time **without** a zone is UTC: `'2026-09-10 11:00:00'` is 11:00 UTC, which is 16:45 in Nepal.
3. KarelaDB always **shows** times in UTC, with a `Z` at the end.

To make `CURRENT_DATE`, `::date`, `date_trunc` and `EXTRACT` work on the Nepal clock, set the [session's time zone](#session-time-zone): `SET TIME ZONE 'Asia/Kathmandu'`, or start the server with `--timezone Asia/Kathmandu`.

**Example: A trading day: 11:00 to 15:00 Nepal time is 05:15 to 09:15 UTC** (sample data: sample)

```sql
SELECT min(time) AS first_minute, max(time) AS last_minute, count(*) AS minutes
FROM ochl_minutes
WHERE symbol = 'CITY' AND time >= '2026-09-10T11:00:00+05:45' AND time < '2026-09-10T15:00:00+05:45';
```

Result:

| first_minute (TIMESTAMP) | last_minute (TIMESTAMP) | minutes (LONG) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | 2026-09-10T09:14:00.000Z | 240 |

(1 row)

<a id="storage"></a>

## Storage

Syntax:

```sql
TIMESTAMP    milliseconds since 1970-01-01 00:00:00 UTC
DATE         days since 1970-01-01
```

A `TIMESTAMP` column holds one number: milliseconds since the start of 1970 in UTC. It does not keep the time zone you wrote. A `DATE` column holds only a day, with no time and no zone.

- **Returns:** a `TIMESTAMP` is shown as `2026-09-10T05:15:00.000Z`, a `DATE` as `2026-09-10`.
- **NULL:** a time can be `NULL` (no value).
- **Notes:**
  - Milliseconds only. More digits after the second are **cut**: `.1234567` becomes `.123`. QuestDB keeps microseconds; KarelaDB does not.
  - Partitions (the files of a time-series table) are made by the **UTC** date. See [PARTITION BY](partitions-and-dedup.md#partition-by).
  - `ROUND 1d` on a column cuts times to the UTC day when a row is written ([create-table](create-table.md)). `ROUND 1d TIME ZONE 'Asia/Kathmandu'` cuts to Nepal midnight instead ([TIME ZONE](sample-by.md#time-zone)).
  - Adding a number to a `TIMESTAMP` adds milliseconds; `TIMESTAMP - TIMESTAMP` gives milliseconds. Adding a number to a `DATE` adds days ([operators](operators.md#arithmetic)).

**Example: The same moment written three ways is one stored value** (sample data: sample)

Setup:

```sql
CREATE TABLE time_test (time TIMESTAMP, note STRING) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO time_test VALUES
  ('2026-09-10T11:00:00+05:45', 'Nepal time with +05:45'),
  ('2026-09-10T05:15:00Z',      'UTC with Z'),
  (1789017300000,               'milliseconds since 1970'),
  ('2026-09-10T05:15:00.1234567Z', 'seven digits: cut to milliseconds');
```

```sql
SELECT time, note FROM time_test;
```

Result:

| time (TIMESTAMP) | note (STRING) |
|---|---|
| 2026-09-10T05:15:00.000Z | Nepal time with +05:45 |
| 2026-09-10T05:15:00.000Z | UTC with Z |
| 2026-09-10T05:15:00.000Z | milliseconds since 1970 |
| 2026-09-10T05:15:00.123Z | seven digits: cut to milliseconds |

(4 rows)

**Example: Milliseconds between two times, and one minute later** (sample data: sample)

```sql
SELECT CAST('2026-09-10T09:15:00Z' AS TIMESTAMP) - CAST('2026-09-10T05:15:00Z' AS TIMESTAMP) AS ms_open,
       (CAST('2026-09-10T09:15:00Z' AS TIMESTAMP) - CAST('2026-09-10T05:15:00Z' AS TIMESTAMP)) / 3600000 AS hours_open,
       CAST('2026-09-10T11:00:00+05:45' AS TIMESTAMP) + 60000 AS one_minute_later;
```

Result:

| ms_open (LONG) | hours_open (DOUBLE) | one_minute_later (TIMESTAMP) |
|---|---|---|
| 14400000 | 4 | 2026-09-10T05:16:00.000Z |

(1 row)

**Example: A DATE column: days, no time** (sample data: sample)

Setup:

```sql
CREATE TABLE holidays (day DATE, name STRING) TIMESERIES(day) PARTITION BY YEAR;
INSERT INTO holidays VALUES ('2026-10-20', 'Dashain'), ('2026-11-08', 'Tihar');
```

```sql
SELECT day, day + 1 AS next_day, CAST(day AS TIMESTAMP) AS as_timestamp, name FROM holidays;
```

Result:

| day (DATE) | next_day (DATE) | as_timestamp (TIMESTAMP) | name (STRING) |
|---|---|---|---|
| 2026-10-20 | 2026-10-21 | 2026-10-20T00:00:00.000Z | Dashain |
| 2026-11-08 | 2026-11-09 | 2026-11-08T00:00:00.000Z | Tihar |

(2 rows)

<a id="time-text"></a>

## Time text

Syntax:

```sql
'YYYY-MM-DD'
'YYYY-MM-DD HH:MM[:SS[.fff]]'
'YYYY-MM-DDTHH:MM[:SS[.fff]]'
'...Z'  |  '...+HH:MM'  |  '...+HHMM'  |  '...-HH:MM'
number  (milliseconds since 1970, UTC)
```

KarelaDB reads a time from text in these forms. It reads them in `INSERT`, `UPDATE`, `CAST`, and when text is compared with a time column in `WHERE`.

| You write | KarelaDB reads it as |
|---|---|
| `'2026-09-10'` | 00:00 UTC of that day |
| `'2026-09-10 11:00'` or `'2026-09-10T11:00:00'` | 11:00 **UTC** (not Nepal time!) |
| `'2026-09-10T11:00:00Z'` | 11:00 UTC |
| `'2026-09-10T11:00:00+05:45'` or `'...+0545'` | 11:00 Nepal time = 05:15 UTC |
| `'2026-09-10T11:00:00-03:00'` | 11:00 at UTC-3 = 14:00 UTC |
| `'2026-09-10T11:00:00.250Z'` | with milliseconds |
| `1789017300000` | milliseconds since 1970 (UTC) |

- **NULL:** `NULL` stays `NULL`.
- **Notes:**
  - The year has 4 digits; month, day, hour, minute and second have **2 digits**. `'2026-9-10'` and `'10/09/2026'` are errors.
  - `T` or one space goes between the date and the time. No space before the zone: `'... 11:00:00 +05:45'` is an error.
  - The date must exist: `'2026-02-30'` and hour `24` are errors.
  - Only in `IN '...'` can the text stop after the year or month (`'2026-09'`). In `>=`, `<`, `=` and `BETWEEN` the text needs at least the day.
  - Newer KarelaDB builds also read `'+05:45:00'` (with seconds), which PostgreSQL drivers send.
  - Change other formats in your program before you send them.

**Example: Many spellings of a time** (sample data: sample)

```sql
SELECT CAST('2026-09-10' AS TIMESTAMP) AS date_only,
       CAST('2026-09-10 11:00' AS TIMESTAMP) AS no_zone_is_utc,
       CAST('2026-09-10T11:00:00+05:45' AS TIMESTAMP) AS nepal,
       CAST('2026-09-10T11:00:00+0545' AS TIMESTAMP) AS nepal_no_colon,
       CAST('2026-09-10T11:00:00-03:00' AS TIMESTAMP) AS brazil,
       CAST(1789017300000 AS TIMESTAMP) AS from_ms;
```

Result:

| date_only (TIMESTAMP) | no_zone_is_utc (TIMESTAMP) | nepal (TIMESTAMP) | nepal_no_colon (TIMESTAMP) | brazil (TIMESTAMP) | from_ms (TIMESTAMP) |
|---|---|---|---|---|---|
| 2026-09-10T00:00:00.000Z | 2026-09-10T11:00:00.000Z | 2026-09-10T05:15:00.000Z | 2026-09-10T05:15:00.000Z | 2026-09-10T14:00:00.000Z | 2026-09-10T05:15:00.000Z |

(1 row)

**Example: Text compared with a time column is read as a time** (sample data: sample)

```sql
SELECT time, symbol, close
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2026-09-08' AND time < '2026-09-11';
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-08T00:00:00.000Z | CITY | 497.5 |
| 2026-09-09T00:00:00.000Z | CITY | 504.6 |
| 2026-09-10T00:00:00.000Z | CITY | 504.9 |

(3 rows)

**Example: Month and day need two digits** (sample data: sample; shows an error)

```sql
SELECT time, close FROM ochl_day WHERE time >= '2026-9-1';
```

Result:

Error: `line 1, column 45: cannot compare TIMESTAMP '2025-12-28T00:00:00.000Z' with STRING '2026-9-1'`

**Example: Day/month/year is not a time** (sample data: sample; shows an error)

```sql
INSERT INTO ochl_day VALUES ('10/09/2026', 'CITY', 1, 1, 1, 1, 1);
```

Result:

Error: `column 'time' (TIMESTAMP): '10/09/2026' is not a time like '2026-09-11 11:00:00' (UTC) or '2026-09-11T11:00:00+05:45'`

**Example: Seconds in the zone, as PostgreSQL drivers send it** (sample data: sample)

```sql
SELECT CAST('2026-09-10T11:00:00+05:45:00' AS TIMESTAMP) AS a;
```

Result:

| a (TIMESTAMP) |
|---|
| 2026-09-10T05:15:00.000Z |

(1 row)

<a id="nepal-time"></a>

## A local time: Nepal +05:45

Syntax:

```sql
'YYYY-MM-DDTHH:MM:SS+05:45'
time + 20700000                          -- the Nepal clock time, still marked Z
SAMPLE BY interval TIME ZONE 'Asia/Kathmandu'
to_char(time, 'YYYY-MM-DD HH24:MI', 'Asia/Kathmandu')
```

The examples use Nepal Standard Time, UTC + 5 hours 45 minutes, all year; any other fixed offset works the same way. 5 h 45 min is **20,700,000 milliseconds**.

| Sample market event | Nepal time | UTC |
|---|---|---|
| Market opens | 11:00 | 05:15 |
| Market closes | 15:00 | 09:15 |
| Nepal midnight | 00:00 | 18:15 of the day before |

- **Notes:**
  - **The most common mistake:** a local time written without its offset (here `+05:45`). KarelaDB reads it as UTC, and the row is 5 h 45 min wrong. Fix bad rows with `UPDATE t SET time = time - 20700000 WHERE ...` (check the DEDUP KEY first).
  - `hour()`, `day()`, `date_trunc()` and `is_trading_day()` work on the [session's time zone](#session-time-zone), which is **UTC** unless you set one. `time IN '...'` is always UTC. For the Nepal hour in a UTC session write `hour(to_timezone(time, 'Asia/Kathmandu'))`. For Nepal days: `time IN '2026-09-10' TIME ZONE 'Asia/Kathmandu'`, `date_trunc('day', time, 'Asia/Kathmandu')` ([date functions](functions-date-time.md#date_trunc)).
  - `time + 20700000` shows the Nepal clock, but the result still ends with `Z`. Use it only for showing or for `hour()`, never to store.
  - For candles on the Nepal clock use [SAMPLE BY ... TIME ZONE](sample-by.md#time-zone).
  - The whole trading day of the sample data (05:15 to 09:15 UTC) is inside one UTC day, so `time IN '2026-09-10'` finds exactly one trading day.
  - `to_char(t, format, 'Asia/Kathmandu')` makes Nepal-time text; it is in newer KarelaDB builds ([date and time functions](functions-date-time.md)).

**Example: Trades between 11:00 and 11:05 Nepal time** (sample data: sample)

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

**Example: The mistake: Nepal time without +05:45 finds nothing** (sample data: sample)

```sql
SELECT count(*) AS rows_found
FROM ochl_minutes
WHERE symbol = 'CITY' AND time >= '2026-09-10 11:00:00' AND time < '2026-09-10 11:05:00';
```

Result:

| rows_found (LONG) |
|---|
| 0 |

(1 row)

**Example: Volume per Nepal clock hour** (sample data: sample)

```sql
SELECT hour(time + 20700000) AS npt_hour, sum(volume) AS volume
FROM ochl_minutes
WHERE symbol = 'CITY' AND time IN '2026-09-10'
GROUP BY hour(time + 20700000)
ORDER BY npt_hour;
```

Result:

| npt_hour (LONG) | volume (DOUBLE) |
|---|---|
| 11 | 47020 |
| 12 | 41230 |
| 13 | 46180 |
| 14 | 48610 |

(4 rows)

**Example: Show a time as Nepal time text** (sample data: sample)

```sql
SELECT timestamp, to_char(timestamp, 'YYYY-MM-DD HH24:MI', 'Asia/Kathmandu') AS nepal_time
FROM live_data
WHERE symbol = 'CITY';
```

Result:

| timestamp (TIMESTAMP) | nepal_time (STRING) |
|---|---|
| 2026-09-10T05:20:00.000Z | 2026-09-10 11:05 |
| 2026-09-10T07:15:00.000Z | 2026-09-10 13:00 |
| 2026-09-10T09:14:00.000Z | 2026-09-10 14:59 |

(3 rows)

**Example: Fix rows that were written without +05:45** (sample data: sample)

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO ticks VALUES ('2026-09-10 11:00:00', 'CITY', 510), ('2026-09-10 11:01:00', 'CITY', 511);
```

```sql
SELECT time, price FROM ticks;
UPDATE ticks SET time = time - 20700000 WHERE time IN '2026-09-10';
SELECT time, price FROM ticks;
```

Result:

`SELECT time, price FROM ticks`

| time (TIMESTAMP) | price (DOUBLE) |
|---|---|
| 2026-09-10T11:00:00.000Z | 510 |
| 2026-09-10T11:01:00.000Z | 511 |

(2 rows)

`UPDATE ticks SET time = time - 20700000 WHERE time IN '2026-09-10'`

```text
2 row(s) updated
```

`SELECT time, price FROM ticks`

| time (TIMESTAMP) | price (DOUBLE) |
|---|---|
| 2026-09-10T05:15:00.000Z | 510 |
| 2026-09-10T05:16:00.000Z | 511 |

(2 rows)

<a id="session-time-zone"></a>

## The session's time zone: SET TIME ZONE

Syntax:

```sql
SET TIME ZONE 'Asia/Kathmandu'      -- also: SET timezone = 'Asia/Kathmandu', SET TIME ZONE '+05:45'
SET TIME ZONE LOCAL                 -- back to the server's zone (also DEFAULT, RESET TIME ZONE)
SHOW TIME ZONE                      -- also SHOW timezone, current_setting('TimeZone')
kareladb serve --timezone Asia/Kathmandu -- the server's zone: env KARELADB_TIMEZONE, kareladb.conf "timezone"; else the computer's
ALTER USER asha SET timezone = 'Asia/Kathmandu' -- one user's zone: their sessions start on it
X-KDB-Time-Zone: Asia/Kathmandu     -- HTTP header: the zone for one request
```

Times are still **stored** in UTC. The time zone only decides on which **day** and at which **clock time** a stored moment falls. A session starts with its user's zone when an admin gave the user one ([ALTER USER ... SET timezone](users-and-roles.md#user-timezone)), else the server's: `kareladb serve --timezone`, else **the computer's own zone** (`SHOW TIME ZONE` says which; a container without a zone is UTC). `SET TIME ZONE` changes it for the rest of the session: a PostgreSQL connection, an HTTP session (`X-KDB-Session`), or the rest of one `/exec` request.

| What | In a UTC session | With `SET TIME ZONE 'Asia/Kathmandu'` |
|---|---|---|
| `CURRENT_DATE` | today in UTC | today in Nepal |
| `LOCALTIMESTAMP`, `LOCALTIME`, `CURRENT_TIME` | UTC clock | Nepal clock |
| `t::date`, `CAST(t AS DATE)`, `to_date(t)` | UTC day | Nepal day |
| `date_trunc('day', t)` | UTC midnight | Nepal midnight (18:15 UTC the day before) |
| `EXTRACT(hour FROM t)`, `hour(t)`, `day(t)`, `day_of_week(t)` | UTC | Nepal clock |
| `to_char(t, format)` | UTC | Nepal clock |
| a `DATE` compared with a `TIMESTAMP`: `t >= CURRENT_DATE` | UTC midnight | Nepal midnight |
| `now()::text` over PostgreSQL | `... +00` | `... +05:45` |

- **Returns:** `SHOW TIME ZONE` gives one row with the column `TimeZone`.
- **NULL:** not affected.
- **Notes:**
  - What stays in UTC: how times are stored and shown in results (`...Z`), `now()`, time text without an offset (`'2026-09-10 11:00'` is still 11:00 UTC), `time IN '...'`, `SAMPLE BY` (add `TIME ZONE` to it), partitions, and the buckets of a [materialized view](views.md#materialized-view).
  - A zone written in a call wins: `date_trunc('day', t, 'UTC')` and `to_char(t, format, 'UTC')` keep UTC.
  - A value that is already a clock time is not moved again: `now() AT TIME ZONE 'Asia/Kathmandu'`, `to_timezone(...)` and `LOCALTIMESTAMP`.
  - Zones with summer time (`'America/New_York'`, `'Europe/London'`) work too: each moment is shown on the offset in force at that moment ([summer time](#summer-time)).
  - The PostgreSQL port tells the driver the zone (`TimeZone`) when it connects and after each `SET TIME ZONE`. With `--pg-timestamptz`, `TIMESTAMP` columns are sent as text on the session's clock, like `2026-09-10 11:00:00+05:45`.
  - `--timezone` also sets the clock of timer and backup schedules: `daily 15:10` runs at 15:10 on that clock. Without it, schedules use the machine's clock (UTC in a container).
  - An `+05:45` offset means 5 h 45 min **ahead** of UTC, as everywhere in KarelaDB. (PostgreSQL reads `SET TIME ZONE '+05:45'` the other way round.)

**Example: Logins per UTC day and per Nepal day: 18:30 UTC is 00:15 the next day in Nepal** (sample data: sample)

Setup:

```sql
CREATE TABLE logins (time TIMESTAMP, user_name STRING) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO logins VALUES ('2026-09-09T18:00:00Z', 'asha'), ('2026-09-09T18:30:00Z', 'bikash'), ('2026-09-10T03:00:00Z', 'chandra');
```

```sql
SELECT time::date AS utc_day, count(*) AS logins FROM logins GROUP BY 1 ORDER BY 1;
SET TIME ZONE 'Asia/Kathmandu';
SELECT time::date AS nepal_day, count(*) AS logins FROM logins GROUP BY 1 ORDER BY 1;
```

Result:

`SELECT CAST(time AS DATE) AS utc_day, count(*) AS logins FROM logins GROUP BY 1 ORDER BY 1`

| utc_day (DATE) | logins (LONG) |
|---|---|
| 2026-09-09 | 2 |
| 2026-09-10 | 1 |

(2 rows)

`SET timezone = 'Asia/Kathmandu'`

```text
the time zone of this session is Asia/Kathmandu; times are still stored as UTC
```

`SELECT CAST(time AS DATE) AS nepal_day, count(*) AS logins FROM logins GROUP BY 1 ORDER BY 1`

| nepal_day (DATE) | logins (LONG) |
|---|---|
| 2026-09-09 | 1 |
| 2026-09-10 | 2 |

(2 rows)

**Example: Today, the clock and the text of now() on the Nepal clock** (sample data: sample)

```sql
SET TIME ZONE 'Asia/Kathmandu';
SELECT CURRENT_DATE AS today_in_nepal, LOCALTIMESTAMP AS nepal_clock, now() AS utc_now,
       now()::text AS as_text, current_setting('TimeZone') AS zone;
SHOW TIME ZONE;
```

Result:

`SET timezone = 'Asia/Kathmandu'`

```text
the time zone of this session is Asia/Kathmandu; times are still stored as UTC
```

`SELECT current_date() AS today_in_nepal, localtimestamp() AS nepal_clock, now() AS utc_now, CAST(now`

| today_in_nepal (DATE) | nepal_clock (TIMESTAMP) | utc_now (TIMESTAMP) | as_text (STRING) | zone (STRING) |
|---|---|---|---|---|
| 2026-10-24 | 2026-10-24T10:27:40.956Z | 2026-10-24T04:42:40.956Z | 2026-10-24 10:27:40.956+05:45 | Asia/Kathmandu |

(1 row)

`SHOW timezone`

| TimeZone (STRING) |
|---|
| Asia/Kathmandu |

(1 row)

**Example: A day on the Nepal clock: DATE '2026-09-10' stands for Nepal midnight, 18:15 UTC on the 9th** (sample data: sample)

Setup:

```sql
CREATE TABLE logins (time TIMESTAMP, user_name STRING) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO logins VALUES ('2026-09-09T18:00:00Z', 'asha'), ('2026-09-09T18:30:00Z', 'bikash'), ('2026-09-10T03:00:00Z', 'chandra');
```

```sql
SET TIME ZONE 'Asia/Kathmandu';
SELECT time, user_name, to_char(time, 'YYYY-MM-DD HH24:MI') AS nepal_clock
FROM logins WHERE time >= DATE '2026-09-10' AND time < DATE '2026-09-11';
```

Result:

`SET timezone = 'Asia/Kathmandu'`

```text
the time zone of this session is Asia/Kathmandu; times are still stored as UTC
```

`SELECT time, user_name, to_char(time, 'YYYY-MM-DD HH24:MI') AS nepal_clock FROM logins WHERE time >=`

| time (TIMESTAMP) | user_name (STRING) | nepal_clock (STRING) |
|---|---|---|
| 2026-09-09T18:30:00.000Z | bikash | 2026-09-10 00:15 |
| 2026-09-10T03:00:00.000Z | chandra | 2026-09-10 08:45 |

(2 rows)

**Example: New York in summer and in winter: noon UTC is 08:00 in July and 07:00 in January** (sample data: sample)

```sql
SET TIME ZONE 'America/New_York';
SELECT to_char(TIMESTAMP '2026-07-01 12:00:00', 'HH24:MI') AS july, to_char(TIMESTAMP '2026-01-15 12:00:00', 'HH24:MI') AS january;
```

Result:

`SET timezone = 'America/New_York'`

```text
the time zone of this session is America/New_York; times are still stored as UTC
```

`SELECT to_char(CAST('2026-07-01 12:00:00' AS TIMESTAMP), 'HH24:MI') AS july, to_char(CAST('2026-01-1`

| july (STRING) | january (STRING) |
|---|---|
| 08:00 | 07:00 |

(1 row)

<a id="time-zone-names"></a>

## Time zone names

Syntax:

```sql
'UTC' | 'GMT' | 'Z' | 'Etc/UTC'
'Asia/Kathmandu' | 'Asia/Katmandu' | 'NPT'
'Asia/Kolkata' | 'Asia/Calcutta' | 'IST' | 'Asia/Colombo'
'Asia/Dhaka' | 'Asia/Thimphu' | 'Asia/Karachi' | 'Asia/Dubai'
'Asia/Bangkok' | 'Asia/Jakarta' | 'Asia/Shanghai' | 'Asia/Hong_Kong'
'Asia/Singapore' | 'Asia/Taipei' | 'Asia/Tokyo' | 'Asia/Seoul'
'+HH:MM' | '-HH:MM'
```

The zone names KarelaDB knows, for `SET TIME ZONE`, `kareladb serve --timezone`, `SAMPLE BY ... TIME ZONE`, `time IN '...' TIME ZONE`, `ROUND ... TIME ZONE`, `date_trunc(unit, t, zone)`, `timestamp_floor`, `to_timezone`, `to_utc` and `to_char`.

| Name | Offset from UTC |
|---|---|
| `UTC`, `GMT`, `Z`, `Etc/UTC` | +00:00 |
| `Asia/Kathmandu`, `Asia/Katmandu`, `NPT` | **+05:45** |
| `Asia/Kolkata`, `Asia/Calcutta`, `IST`, `Asia/Colombo` | +05:30 |
| `Asia/Dhaka`, `Asia/Thimphu` | +06:00 |
| `Asia/Karachi` | +05:00 |
| `Asia/Dubai` | +04:00 |
| `Asia/Bangkok`, `Asia/Jakarta` | +07:00 |
| `Asia/Shanghai`, `Asia/Hong_Kong`, `Asia/Singapore`, `Asia/Taipei` | +08:00 |
| `Asia/Tokyo`, `Asia/Seoul` | +09:00 |
| `'+05:45'`, `'-03:00'`, ... | that offset (2-digit hours 00-23, minutes 00-59) |

- **Notes:**
  - Names do not care about case: `'asia/kathmandu'` works.
  - The names above have a **fixed** offset and need nothing more. Every other name of the IANA time zone list (`'Europe/London'`, `'America/New_York'`, `'Australia/Sydney'`, ...) works too, with its summer time: see [summer time](#summer-time).
  - `IST` here means India Standard Time.

**Example: The same hour buckets with a name and with an offset** (sample data: sample)

```sql
SELECT time, count(*) AS minutes FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10' SAMPLE BY 1h TIME ZONE 'npt';

SELECT time, count(*) AS minutes FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10' SAMPLE BY 1h TIME ZONE '+05:45';
```

Result:

`SELECT time, count(*) AS minutes FROM ochl_minutes WHERE symbol = 'COAST' AND time IN '2026-09-10' S`

| time (TIMESTAMP) | minutes (LONG) |
|---|---|
| 2026-09-10T05:15:00.000Z | 60 |
| 2026-09-10T06:15:00.000Z | 56 |
| 2026-09-10T07:15:00.000Z | 60 |
| 2026-09-10T08:15:00.000Z | 60 |

(4 rows)

`SELECT time, count(*) AS minutes FROM ochl_minutes WHERE symbol = 'COAST' AND time IN '2026-09-10' S`

| time (TIMESTAMP) | minutes (LONG) |
|---|---|
| 2026-09-10T05:15:00.000Z | 60 |
| 2026-09-10T06:15:00.000Z | 56 |
| 2026-09-10T07:15:00.000Z | 60 |
| 2026-09-10T08:15:00.000Z | 60 |

(4 rows)

<a id="summer-time"></a>

## Zones with summer time

A zone with **summer time** (daylight saving time) has two offsets a year: New York is `-05:00` in winter and `-04:00` in summer. KarelaDB takes the rules from the IANA time zone files that every Linux keeps (package `tzdata`), so each moment gets the offset that was in force at that moment, in any year.

| Where | A zone with summer time |
|---|---|
| `SET TIME ZONE`, `kareladb serve --timezone`, `X-KDB-Time-Zone` | yes: `CURRENT_DATE`, `::date`, `date_trunc`, `EXTRACT`, `to_char`, a `DATE` met by a `TIMESTAMP` |
| `t AT TIME ZONE 'zone'`, `to_timezone`, `to_utc` | yes |
| `SAMPLE BY ... TIME ZONE 'zone'` | yes: a day bucket is 23 or 25 hours on the days the clocks change |
| [calendars](calendars.md) `TIME ZONE` | yes |
| `ROUND ... TIME ZONE`, `time IN '...' TIME ZONE`, the zone argument of `date_trunc(unit, t, zone)`, `to_char(t, format, zone)`, `timestamp_floor` | not yet: fixed offsets only (an error says so) |

- **Where the files are:** KarelaDB looks in `KARELADB_ZONEINFO`, `TZDIR`, `/usr/share/zoneinfo`, then a `zoneinfo` folder next to the program. The Docker image has them. Without them a zone with summer time is an error that says where KarelaDB looked; fixed zones always work.
- **A time that happens twice** (the hour after the clocks go back) is the first of the two; **a time that never happens** (the hour skipped when they go forward) is read with the offset from before the change, as in PostgreSQL.

**Example: Day buckets in New York around the March change: 8 March is 23 hours long** (sample data: sample)

```sql
CREATE TABLE ticks_ny (time TIMESTAMP, v INT) TIMESERIES(time);
INSERT INTO ticks_ny VALUES ('2026-03-08T04:30:00Z', 1), ('2026-03-08T06:00:00Z', 1), ('2026-03-09T03:30:00Z', 1), ('2026-03-09T04:30:00Z', 1);
SELECT time AS day_starts_utc, count() AS ticks FROM ticks_ny SAMPLE BY 1d TIME ZONE 'America/New_York';
```

Result:

`CREATE TABLE ticks_ny (`

```text
table 'ticks_ny' created
```

`INSERT INTO ticks_ny VALUES ('2026-03-08T04:30:00Z', 1), ('2026-03-08T06:00:00Z', 1), ('2026-03-09T0`

```text
4 row(s) inserted
```

`SELECT time AS day_starts_utc, count() AS ticks FROM ticks_ny SAMPLE BY 1d TIME ZONE 'America/New_Yo`

| day_starts_utc (TIMESTAMP) | ticks (LONG) |
|---|---|
| 2026-03-07T05:00:00.000Z | 1 |
| 2026-03-08T05:00:00.000Z | 2 |
| 2026-03-09T04:00:00.000Z | 1 |

(3 rows)

**Example: AT TIME ZONE: noon UTC on the New York clock, summer and winter** (sample data: sample)

```sql
SELECT TIMESTAMPTZ '2026-07-01 12:00:00+00' AT TIME ZONE 'America/New_York' AS july,
       TIMESTAMPTZ '2026-01-15 12:00:00+00' AT TIME ZONE 'America/New_York' AS january;
```

Result:

| july (TIMESTAMP) | january (TIMESTAMP) |
|---|---|
| 2026-07-01T08:00:00.000Z | 2026-01-15T07:00:00.000Z |

(1 row)

**Example: An offset needs two digits for the hour** (sample data: sample; shows an error)

```sql
SELECT time, count(*) FROM ochl_minutes SAMPLE BY 1h TIME ZONE '+5:45';
```

Result:

Error: `offset '+5:45' must look like '00:15', '+05:45' or '-03:00'`

<a id="in-interval"></a>

## IN 'interval' for time ranges

Syntax:

```sql
time_column [NOT] IN 'YYYY'
time_column [NOT] IN 'YYYY-MM'
time_column [NOT] IN 'YYYY-MM-DD'
time_column [NOT] IN 'YYYY-MM-DDTHH[:MM[:SS]]'
time_column [NOT] IN '...+HH:MM'
```

`time IN '2026-09'` is true for every time **inside** that month. The text says how big the range is: a year, a month, a day, an hour, a minute or a second. It is the easy way to filter a time-series table by time, and KarelaDB then reads only the partitions of that range.

| You write | Range (start included, end not included) |
|---|---|
| `time IN '2026'` | 2026-01-01 00:00 UTC to 2027-01-01 00:00 UTC |
| `time IN '2026-09'` | the whole month of September 2026 (UTC) |
| `time IN '2026-09-10'` | the whole UTC day |
| `time IN '2026-09-10T11'` | the hour 11:00 to 12:00 UTC |
| `time IN '2026-09-10T11:05'` | one minute |
| `time IN '2026-09-10+05:45'` | the whole **Nepal** day (18:15 UTC the day before, to 18:15 UTC) |
| `time IN '2026-09-10T12+05:45'` | the hour 12:00 to 13:00 Nepal time |

- **Returns:** `TRUE` or `FALSE`. `NOT IN '...'` is true outside the range.
- **NULL:** a `NULL` time gives `NULL`, so the row is not kept.
- **Notes:**
  - Without an offset the range is in **UTC**. With `+05:45` it is in Nepal time: the same text, one more part.
  - It works for `TIMESTAMP` and `DATE` columns. For a `DATE`, a day that touches the range counts.
  - Better than `BETWEEN` for whole days: `time BETWEEN '2026-09-07' AND '2026-09-09'` **includes** the end moment `2026-09-09T00:00:00` and nothing later on that day.
  - QuestDB's forms with `;` work too: `'2026-09-10;1d'` stretches the end by a day, and `'2026-09-10T05:15;4h;1d;5'` repeats a window five days in a row. See [WHERE](where.md#interval-lists).
  - The left side must be a time: `symbol IN '2026'` is an error. For a list of values write `IN ('a', 'b')` ([WHERE](where.md#in-interval)).

**Example: A month, a day, an hour** (sample data: sample)

```sql
SELECT count(*) AS days_in_sept FROM ochl_day WHERE symbol = 'CITY' AND time IN '2026-09';
SELECT count(*) AS minutes_on_the_10th FROM ochl_minutes WHERE symbol = 'CITY' AND time IN '2026-09-10';
SELECT count(*) AS minutes_12_to_13_npt FROM ochl_minutes WHERE symbol = 'CITY' AND time IN '2026-09-10T12+05:45';
```

Result:

`SELECT count(*) AS days_in_sept FROM ochl_day WHERE symbol = 'CITY' AND time IN '2026-09'`

| days_in_sept (LONG) |
|---|
| 8 |

(1 row)

`SELECT count(*) AS minutes_on_the_10th FROM ochl_minutes WHERE symbol = 'CITY' AND time IN '2026-09-`

| minutes_on_the_10th (LONG) |
|---|
| 240 |

(1 row)

`SELECT count(*) AS minutes_12_to_13_npt FROM ochl_minutes WHERE symbol = 'CITY' AND time IN '2026-09`

| minutes_12_to_13_npt (LONG) |
|---|
| 60 |

(1 row)

**Example: One minute on the Nepal clock** (sample data: sample)

```sql
SELECT time, symbol, open, close
FROM ochl_minutes
WHERE time IN '2026-09-10T11:00+05:45';
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | close (DOUBLE) |
|---|---|---|---|
| 2026-09-10T05:15:00.000Z | CITY | 504.6 | 504.4 |
| 2026-09-10T05:15:00.000Z | COAST | 380.1 | 380 |

(2 rows)

**Example: BETWEEN '2026-09-09' AND '2026-09-10' misses the trading hours of the 10th** (sample data: sample)

```sql
SELECT count(*) AS with_between FROM ochl_minutes
WHERE symbol = 'COAST' AND time BETWEEN '2026-09-09' AND '2026-09-10';

SELECT count(*) AS two_whole_days FROM ochl_minutes
WHERE symbol = 'COAST' AND time >= '2026-09-09' AND time < '2026-09-11';
```

Result:

`SELECT count(*) AS with_between FROM ochl_minutes WHERE symbol = 'COAST' AND time BETWEEN '2026-09-0`

| with_between (LONG) |
|---|
| 240 |

(1 row)

`SELECT count(*) AS two_whole_days FROM ochl_minutes WHERE symbol = 'COAST' AND time >= '2026-09-09' `

| two_whole_days (LONG) |
|---|
| 476 |

(1 row)

**Example: Everything except one day** (sample data: sample)

```sql
SELECT count(*) AS rows_not_on_the_10th FROM ochl_minutes WHERE time NOT IN '2026-09-10';
```

Result:

| rows_not_on_the_10th (LONG) |
|---|
| 480 |

(1 row)

**Example: Not a time range** (sample data: sample; shows an error)

```sql
SELECT count(*) FROM ochl_day WHERE time IN '2026-09-10 to 2026-09-11';
```

Result:

Error: `line 1, column 42: '2026-09-10 to 2026-09-11' is not a time range like '2026-09', '2026-09-11', '2026-09-11;1d' or '2026-09-11T10:00;30m;1d;5'`

**Example: The left side must be a time** (sample data: sample; shows an error)

```sql
SELECT count(*) FROM ochl_day WHERE symbol IN '2026';
```

Result:

Error: `line 1, column 44: IN '...' needs a time or date on the left`

<a id="output"></a>

## Times in results

Syntax:

```sql
TIMESTAMP  ->  YYYY-MM-DDTHH:MM:SS.fffZ
DATE       ->  YYYY-MM-DD
```

Every time in a result is shown in **UTC**, with 3 digits of milliseconds and a `Z`. The web console, `kareladb sql`, the HTTP API and the PostgreSQL protocol all get UTC times.

- **Notes:**
  - Your program changes UTC to Nepal time for the screen (for example in Go: `t.In(time.FixedZone("NPT", 20700))`).
  - `SAMPLE BY ... TIME ZONE` buckets are also shown in UTC: the Nepal hour 11:00 is `05:15:00.000Z`.
  - `now()` is the current UTC time. It is the same value in the whole statement.
  - Over the PostgreSQL protocol a `TIMESTAMP` is sent as `timestamp without time zone` (the value is UTC) unless the server runs with `--pg-timestamptz`. With it, the text is on the [session's clock](#session-time-zone) with its offset.

**Example: Live snapshots were written in Nepal time; they come back in UTC** (sample data: sample)

```sql
SELECT timestamp, symbol, ltp
FROM live_data
WHERE symbol = 'TELCO';
```

Result:

| timestamp (TIMESTAMP) | symbol (SYMBOL) | ltp (DOUBLE) |
|---|---|---|
| 2026-09-10T05:20:00.000Z | TELCO | 860.5 |
| 2026-09-10T07:15:00.000Z | TELCO | 869 |
| 2026-09-10T09:14:00.000Z | TELCO | 897.7 |

(3 rows)

**Example: now() and a DATE** (sample data: sample)

```sql
SELECT now() > '2026-01-01' AS is_after_new_year, CAST('2026-09-10T20:00:00+05:45' AS DATE) AS utc_date;
```

Result:

| is_after_new_year (BOOL) | utc_date (DATE) |
|---|---|
| true | 2026-09-10 |

(1 row)
