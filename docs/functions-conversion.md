# Conversion functions

> Change a value from one type to another with CAST, ::, to_timestamp and to_date.

- Category: Functions — conversion
- Keywords: convert, conversion, type conversion, change type, cast, ::, to number, to text, parse number, parse date, epoch, unix time, milliseconds, cannot convert, INTEGER, BIGINT, BOOLEAN, VARCHAR, TEXT, JSONB, BYTEA, BLOB, FLOAT, SHORT, BYTE
- See also: [Column types](column-types.md), [Date and time functions (to_char)](functions-date-time.md#to_char), [Conditional and NULL functions (coalesce)](functions-conditional.md#coalesce), [Math functions (round)](functions-math.md#round), [JSON functions](functions-json.md), [Operators](operators.md)

A value has a type: a number, a text, a time and so on. Sometimes a value has the wrong type for what you want to do. A price read from a text file is the text `'512.50'`, not a number. `CAST` changes the type.

- `CAST(x AS type)` and `x::type` do the same thing.
- `to_timestamp(x)` turns text or seconds into a time; `to_date(x)` turns text or milliseconds into a date.
- KarelaDB never guesses. When a value does not fit the new type, you get an error like `cannot convert '5.5' to INT`. It does not round or cut the value for you.
- `NULL` stays `NULL` in every conversion.

The rules are the same as when a value goes into a table column of that type (see [column types](column-types.md)). The entries "Into ..." below list them for each type.

**Example: Prices, quantities and times that arrived as text**

Setup:

```sql
CREATE TABLE price_import (line INT PRIMARY KEY, symbol STRING, price STRING, qty STRING, traded STRING, is_buy STRING);
INSERT INTO price_import VALUES
  (1, 'CITY', '512.50', '100', '2026-09-10T11:05:00+05:45', 'true'),
  (2, 'COAST',  '398',    '20',  '2026-09-10T13:00:00+05:45', 'false'),
  (3, 'VOLT', '184.0',  '50',  '2026-09-10T14:59:00+05:45', '1');
```

```sql
SELECT symbol,
       CAST(price AS DOUBLE) * CAST(qty AS LONG) AS amount,
       CAST(traded AS TIMESTAMP) AS traded_utc,
       is_buy::BOOL AS is_buy
FROM price_import
ORDER BY line;
```

Result:

| symbol (STRING) | amount (DOUBLE) | traded_utc (TIMESTAMP) | is_buy (BOOL) |
|---|---|---|---|
| CITY | 51250 | 2026-09-10T05:20:00.000Z | true |
| COAST | 7960 | 2026-09-10T07:15:00.000Z | false |
| VOLT | 9200 | 2026-09-10T09:14:00.000Z | true |

(3 rows)

The examples below also use this small accounting table. Money is kept in `DECIMAL(2)`: an exact number with 2 places after the point.

Setup used by the examples below:

```sql
CREATE TABLE ledger (
  id      INT PRIMARY KEY,
  day     DATE,
  account STRING,
  amount  DECIMAL(2)
);
INSERT INTO ledger VALUES
  (1, '2026-09-01', 'Sales', 1250.00),
  (2, '2026-09-02', 'Sales', 899.99),
  (3, '2026-09-02', 'Rent', 1200.50);
```

<a id="cast"></a>

## CAST

Syntax:

```sql
CAST(value AS type)
```

Changes `value` into `type`.

| Argument | Type | Meaning |
|---|---|---|
| `value` | any | the value to change |
| `type` | a type name | `BOOL` (`BOOLEAN`), `BYTE`, `SHORT`, `INT` (`INTEGER`), `LONG` (`BIGINT`), `FLOAT`, `DOUBLE`, `DECIMAL(s)`, `DATE`, `TIMESTAMP`, `SYMBOL`, `STRING` (`VARCHAR`, `TEXT`), `JSON` (`JSONB`), `BYTES` (`BYTEA`, `BLOB`) |

- **Returns:** a value of `type`.
- **NULL:** `CAST(NULL AS type)` is `NULL`.
- **Notes:**
  - When the value does not fit, the error is `cannot convert '...' to TYPE`. For JSON and BYTES the message also says what is wrong.
  - `DECIMAL` without a scale means `DOUBLE`. Write `CAST(x AS DECIMAL(2))` when you want exact money. A length like `VARCHAR(10)` or `CHAR(3)` is read and **ignored**: nothing is cut.
  - Many things need no `CAST`. Text compared with a time is read as a time (`time >= '2026-09-01'`). `||` joins numbers as text (`'CITY' || 1`).
  - To turn a time into formatted text, use [to_char](functions-date-time.md#to_char), not `CAST`.

**Example**

```sql
SELECT CAST('512.5' AS DOUBLE) + 1 AS a,
       CAST(42 AS STRING) AS b,
       CAST('2026-09-10T11:00:00+05:45' AS TIMESTAMP) AS c,
       CAST('12.5' AS DECIMAL(2)) AS d,
       CAST(NULL AS INT) AS e;
```

Result:

| a (DOUBLE) | b (STRING) | c (TIMESTAMP) | d (DECIMAL(2)) | e (STRING) |
|---|---|---|---|---|
| 513.5 | 42 | 2026-09-10T05:15:00.000Z | 12.50 | NULL |

(1 row)

**Example: 13% VAT on each ledger line, as exact money**

```sql
SELECT id, account, amount,
       CAST(round(amount * 0.13, 2) AS DECIMAL(2)) AS vat,
       amount * 0.13 AS vat_as_double
FROM ledger
ORDER BY id;
```

Result:

| id (INT) | account (STRING) | amount (DECIMAL(2)) | vat (DECIMAL(2)) | vat_as_double (DECIMAL(4)) |
|---|---|---|---|---|
| 1 | Sales | 1250.00 | 162.50 | 162.5000 |
| 2 | Sales | 899.99 | 117.00 | 116.9987 |
| 3 | Rent | 1200.50 | 156.07 | 156.0650 |

(3 rows)

**Example: Into a whole number: the fraction is rounded**

```sql
SELECT CAST(5.5 AS INT) AS half_up, CAST(5.4 AS INT) AS down, CAST(-5.5 AS INT) AS negative;
```

Result:

| half_up (LONG) | down (LONG) | negative (LONG) |
|---|---|---|
| 6 | 5 | -6 |

(1 row)

**Example: DECIMAL without a scale is DOUBLE**

```sql
SELECT CAST('12.50' AS DECIMAL) AS as_double, CAST('12.50' AS DECIMAL(2)) AS exact_money;
```

Result:

| as_double (DOUBLE) | exact_money (DECIMAL(2)) |
|---|---|
| 12.5 | 12.50 |

(1 row)

<a id="cast-short"></a>

## :: (short cast)

Syntax:

```sql
value::type
```

The short way to write `CAST(value AS type)`. `'42'::INT` is `CAST('42' AS INT)`. It comes from PostgreSQL.

- **Returns:** a value of `type`, as with [CAST](functions-conversion.md#cast).
- **NULL:** `NULL::INT` is `NULL`.
- **Notes:** `::` holds on to the value right before it, more tightly than any operator. `2 + 3::DOUBLE` changes only `3`. Put `( )` around a longer expression: `(2 + 3)::STRING`.

**Example**

```sql
SELECT '42'::INT + 1 AS a, 2 + 3::DOUBLE AS b, (2 + 3)::STRING AS c, '12.5'::DECIMAL(2) AS d, NULL::BOOL AS e;
```

Result:

| a (LONG) | b (DOUBLE) | c (STRING) | d (DECIMAL(2)) | e (STRING) |
|---|---|---|---|---|
| 43 | 5 | 5 | 12.50 | NULL |

(1 row)

**Example: Filter candles with a Nepal time written as text** (sample data: sample)

```sql
SELECT time, symbol, close
FROM ochl_minutes
WHERE symbol = 'COAST'
  AND time >= '2026-09-10T11:00:00+05:45'::TIMESTAMP
  AND time <  '2026-09-10T11:03:00+05:45'::TIMESTAMP;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T05:15:00.000Z | COAST | 380 |
| 2026-09-10T05:16:00.000Z | COAST | 379.6 |
| 2026-09-10T05:17:00.000Z | COAST | 380.1 |

(3 rows)

**Example: A length after VARCHAR is read and ignored**

```sql
SELECT CAST('CITY' AS VARCHAR(10)) AS a, CAST('CITY' AS VARCHAR(3)) AS nothing_is_cut;
```

Result:

| a (STRING) | nothing_is_cut (STRING) |
|---|---|
| CITY | CITY |

(1 row)

<a id="to_timestamp"></a>

## to_timestamp

Syntax:

```sql
to_timestamp(value)
```

Makes a `TIMESTAMP` (a moment in time, stored in UTC) from time text, a `DATE` or a number of seconds.

| Argument | Type | Meaning |
|---|---|---|
| `value` | text, `DATE`, `TIMESTAMP` or number | time text like `'2026-09-10T11:00:00+05:45'`, or seconds since 1970-01-01 UTC (a fraction is allowed) |

- **Returns:** `TIMESTAMP`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:**
  - A number means **seconds**, as in PostgreSQL and Unix time: `to_timestamp(1789020900)`. A fraction keeps the milliseconds: `to_timestamp(1789020900.25)`. Before 2026-09-25 a number meant milliseconds.
  - Milliseconds, like JavaScript's `Date.now()`: divide by 1000.0 first, or cast: `CAST(ms AS TIMESTAMP)`.
  - With one argument the text must look like `YYYY-MM-DD`, then optional `T` or space and `HH:MM:SS.fff`, then optional `Z` or `+05:45`. Text without a zone is UTC. For any other shape, give a format (below).
  - A `DATE` becomes midnight UTC of that day.

<a id="to_timestamp-format"></a>

### to_timestamp(text, format)

Syntax:

```sql
to_timestamp(text, format)
```

Reads a time from text written in any shape, such as `'23/10/2026 14:05'`. The format says where each part is. Two styles of format work:

| Part | PostgreSQL words | QuestDB letters |
|---|---|---|
| year | `YYYY`, `YY` | `yyyy`, `yy` |
| month | `MM`, `Mon` (Oct), `Month` (October) | `MM`, `MMM`, `MMMM` |
| day | `DD`, `DDD` (day of the year) | `dd` |
| hour | `HH24` (0-23), `HH12` or `HH` (1-12) | `HH` (0-23), `hh` (1-12) |
| minute, second | `MI`, `SS` | `mm`, `ss` |
| after the point | `MS` (3 digits), `US` (6), `FF1`-`FF6` | `SSS` (milliseconds) |
| AM / PM | `AM`, `PM`, `A.M.` | `a` |
| zone | `TZH:TZM`, `OF` | `Z`, `z` |
| text as it is | `"T"` | `'T'` or a letter with no meaning, like `T` |

- **Returns:** `TIMESTAMP`. **NULL:** `NULL` in, `NULL` out.
- **Which style:** in a database with the QuestDB dialect, QuestDB letters. Anywhere else, a format with lower-case `y` and upper-case `MM` (`'yyyy-MM-dd'`) or `HH:mm` is QuestDB letters; everything else is PostgreSQL words, in any case (`'yyyy-mm-dd'` is PostgreSQL: `mm` is the month).
- **Clock:** PostgreSQL words without a zone read the time on the session's clock (`SET TIME ZONE`), as PostgreSQL does. QuestDB letters without a zone read UTC, as QuestDB does.
- **PostgreSQL words are lenient:** any separator stands for another (`'YYYY-MM-DD'` reads `'2026/10/23'`). **QuestDB letters are exact:** every character must match.
- A day that does not exist, like 30 February, is an error, not 2 March.
- A constant format is read once for the whole query, not once per row.

**Example: Times written by people and by other systems**

```sql
SELECT to_timestamp('23/10/2026 14:05', 'DD/MM/YYYY HH24:MI') AS pg_words,
       to_timestamp('23/10/2026 14:05', 'dd/MM/yyyy HH:mm') AS questdb_letters,
       to_timestamp('05 Oct 2026 02:15 PM', 'DD Mon YYYY HH12:MI AM') AS with_pm,
       to_timestamp('2026-10-23 11:00 +05:45', 'YYYY-MM-DD HH24:MI TZH:TZM') AS nepal_time,
       to_timestamp('20261023143005', 'YYYYMMDDHH24MISS') AS no_separators;
```

Result:

| pg_words (TIMESTAMP) | questdb_letters (TIMESTAMP) | with_pm (TIMESTAMP) | nepal_time (TIMESTAMP) | no_separators (TIMESTAMP) |
|---|---|---|---|---|
| 2026-10-23T14:05:00.000Z | 2026-10-23T14:05:00.000Z | 2026-10-05T14:15:00.000Z | 2026-10-23T05:15:00.000Z | 2026-10-23T14:30:05.000Z |

(1 row)

**Example: A day that does not exist** (shows an error)

```sql
SELECT to_timestamp('2026-02-30', 'YYYY-MM-DD');
```

Result:

Error: `line 1, column 8: to_timestamp: date/time field value out of range: "2026-02-30"`

**Example**

```sql
SELECT to_timestamp('2026-09-10T11:00:00+05:45') AS nepal_text,
       to_timestamp('2026-09-10') AS date_text,
       to_timestamp(1789020900) AS from_seconds,
       to_timestamp(1789020900.25) AS with_fraction,
       to_timestamp(1789020900000 / 1000.0) AS from_ms,
       to_timestamp(NULL) AS nothing;
```

Result:

| nepal_text (TIMESTAMP) | date_text (TIMESTAMP) | from_seconds (TIMESTAMP) | with_fraction (TIMESTAMP) | from_ms (TIMESTAMP) | nothing (STRING) |
|---|---|---|---|---|---|
| 2026-09-10T05:15:00.000Z | 2026-09-10T00:00:00.000Z | 2026-09-10T06:15:00.000Z | 2026-09-10T06:15:00.250Z | 2026-09-10T06:15:00.000Z | NULL |

(1 row)

**Example: App sign-up times sent as milliseconds**

Setup:

```sql
CREATE TABLE app_signups (user_id INT PRIMARY KEY, name STRING, created_ms LONG);
INSERT INTO app_signups VALUES (1, 'Sita', 1788900300000), (2, 'Ram', 1788928200000), (3, 'Hari', 1789020900000);
```

```sql
SELECT user_id, name, created_ms, to_timestamp(created_ms / 1000.0) AS created, CAST(created_ms AS TIMESTAMP) AS same
FROM app_signups
ORDER BY user_id;
```

Result:

| user_id (INT) | name (STRING) | created_ms (LONG) | created (TIMESTAMP) | same (TIMESTAMP) |
|---|---|---|---|---|
| 1 | Sita | 1788900300000 | 2026-09-08T20:45:00.000Z | 2026-09-08T20:45:00.000Z |
| 2 | Ram | 1788928200000 | 2026-09-09T04:30:00.000Z | 2026-09-09T04:30:00.000Z |
| 3 | Hari | 1789020900000 | 2026-09-10T06:15:00.000Z | 2026-09-10T06:15:00.000Z |

(3 rows)

**Example: Text that is not a time** (shows an error)

```sql
SELECT to_timestamp('10/09/2026');
```

Result:

Error: `line 1, column 8: to_timestamp: argument 1 must be a time, got '10/09/2026'`

<a id="to_date"></a>

## to_date

Syntax:

```sql
to_date(value)
to_date(text, format)
```

Makes a `DATE` (a day without a clock time) from time text, a `TIMESTAMP` or a number of milliseconds. It keeps the **UTC** date.

With a `format`, the text is read in that shape, with the same words as [to_timestamp(text, format)](#to_timestamp): PostgreSQL's `DD/MM/YYYY` or QuestDB's `dd/MM/yyyy`. The date is the one written: no time zone moves it, as in PostgreSQL.

| Argument | Type | Meaning |
|---|---|---|
| `value` | text, `TIMESTAMP`, `DATE` or whole number | a time, or milliseconds since 1970-01-01 UTC |

- **Returns:** `DATE`.
- **NULL:** `NULL` in, `NULL` out.
- **Notes:**
  - The date is the UTC date. Nepal is 5 hours 45 minutes ahead of UTC, so between 00:00 and 05:45 Nepal time the UTC date is the day before. For the Nepal date write `to_date(time + 20700000)` (20700000 ms = 5 h 45 min).
  - `to_date(86400000)` works (a number of milliseconds), but `CAST(86400000 AS DATE)` is an error. `CAST` into `DATE` does not take numbers.

**Example**

```sql
SELECT to_date('2026-09-10T20:00:00Z') AS a,
       to_date('2026-09-10T03:00:00+05:45') AS nepal_3am_is_utc_day_before,
       to_date(86400000) AS b,
       to_date(NULL) AS c;
```

Result:

| a (DATE) | nepal_3am_is_utc_day_before (DATE) | b (DATE) | c (STRING) |
|---|---|---|---|
| 2026-09-10 | 2026-09-09 | 1970-01-02 | NULL |

(1 row)

**Example: A date written day first**

```sql
SELECT to_date('25/09/2026', 'DD/MM/YYYY') AS pg_words,
       to_date('2026-09-25', 'yyyy-MM-dd') AS questdb_letters;
```

Result:

| pg_words (DATE) | questdb_letters (DATE) |
|---|---|
| 2026-09-25 | 2026-09-25 |

(1 row)

**Example: Sign-ups per day: UTC date and Nepal date**

Setup:

```sql
CREATE TABLE app_signups (user_id INT PRIMARY KEY, name STRING, created TIMESTAMP);
INSERT INTO app_signups VALUES
  (1, 'Sita', '2026-09-09T02:30:00+05:45'),
  (2, 'Ram',  '2026-09-09T10:15:00+05:45'),
  (3, 'Hari', '2026-09-09T15:45:00+05:45'),
  (4, 'Gita', '2026-09-10T12:00:00+05:45');
```

```sql
SELECT to_date(created) AS utc_day, count(*) AS signups
FROM app_signups GROUP BY to_date(created) ORDER BY utc_day;

SELECT to_date(created + 20700000) AS nepal_day, count(*) AS signups
FROM app_signups GROUP BY to_date(created + 20700000) ORDER BY nepal_day;
```

Result:

`SELECT to_date(created) AS utc_day, count(*) AS signups FROM app_signups GROUP BY to_date(created) O`

| utc_day (DATE) | signups (LONG) |
|---|---|
| 2026-09-08 | 1 |
| 2026-09-09 | 2 |
| 2026-09-10 | 1 |

(3 rows)

`SELECT to_date(created + 20700000) AS nepal_day, count(*) AS signups FROM app_signups GROUP BY to_da`

| nepal_day (DATE) | signups (LONG) |
|---|---|
| 2026-09-09 | 3 |
| 2026-09-10 | 1 |

(2 rows)

**Example: true is not a time** (shows an error)

```sql
SELECT to_date(TRUE);
```

Result:

Error: `line 1, column 8: to_date: argument 1 must be a time, got 'true'`

<a id="into-integers"></a>

## Into integers

Syntax:

```sql
CAST(value AS BYTE | SHORT | INT | INTEGER | LONG | BIGINT)
```

Whole numbers. The types differ only in size:

| Type | Smallest | Biggest |
|---|---|---|
| `BYTE` | -127 | 127 |
| `SHORT` | -32767 | 32767 |
| `INT`, `INTEGER` | -2147483647 | 2147483647 |
| `LONG`, `BIGINT` | -9223372036854775807 | 9223372036854775807 |

| From | Result |
|---|---|
| a whole number | the same number, if it is in range |
| `DOUBLE` | rounded to the nearest whole number: `5.4` gives `5`, `5.5` gives `6`, `-5.5` gives `-6` |
| `DECIMAL(s)` | rounded the same way: `1.50` gives `2` |
| text | a number like `'42'`, `' -7'` or `'5.5'` (spaces before are allowed, spaces after are not); a fraction is rounded |
| `TRUE` / `FALSE` | `1` / `0` |
| `TIMESTAMP` | the milliseconds since 1970-01-01, as PostgreSQL apps expect |
| `DATE`, `JSON`, `BYTES` | error |

- **Returns:** the chosen integer type.
- **NULL:** stays `NULL`.
- **Notes:**
  - A fraction is **rounded to the nearest** whole number, half away from zero, as PostgreSQL does. To cut instead, use [floor](functions-math.md#floor), [ceil](functions-math.md#ceil) or [trunc](functions-math.md#trunc) first.
  - A number too big for the type is still an error: `CAST(300 AS BYTE)`.
  - For the milliseconds of a time, `CAST(t AS LONG)` works; `time - 0::TIMESTAMP` does the same.

**Example**

```sql
SELECT CAST('42' AS INT) AS a, CAST(5.0 AS INT) AS b, CAST(TRUE AS INT) AS c,
       CAST(CAST('2.00' AS DECIMAL(2)) AS LONG) AS d, CAST(round(512.5) AS INT) AS e, CAST(-127 AS BYTE) AS f;
```

Result:

| a (LONG) | b (LONG) | c (LONG) | d (LONG) | e (LONG) | f (LONG) |
|---|---|---|---|---|---|
| 42 | 5 | 1 | 2 | 513 | -127 |

(1 row)

**Example: Shares per trade from text, and a time as milliseconds** (sample data: sample)

```sql
SELECT transaction_id, symbol,
       CAST(quantity AS STRING) AS qty_text,
       CAST(CAST(quantity AS STRING) AS LONG) + 1 AS back_to_number,
       date - 0::TIMESTAMP AS date_ms
FROM trade_log
ORDER BY transaction_id
LIMIT 3;
```

Result:

| transaction_id (LONG) | symbol (SYMBOL) | qty_text (STRING) | back_to_number (LONG) | date_ms (LONG) |
|---|---|---|---|---|
| 100001 | TELCO | 1000 | 1001 | 1788912000000 |
| 100002 | CITY | 10 | 11 | 1788912000000 |
| 100003 | CITY | 500 | 501 | 1788912000000 |

(3 rows)

**Example: A fraction is rounded to the nearest whole number**

```sql
SELECT CAST(512.5 AS INT) AS a, CAST(512.4 AS INT) AS b, CAST('5.5' AS INT) AS from_text;
```

Result:

| a (LONG) | b (LONG) | from_text (LONG) |
|---|---|---|
| 513 | 512 | 6 |

(1 row)

**Example: Too big for BYTE** (shows an error)

```sql
SELECT CAST(300 AS BYTE);
```

Result:

Error: `line 1, column 8: cannot convert '300' to BYTE`

**Example: A TIMESTAMP gives its milliseconds; a DATE does not** (shows an error)

```sql
SELECT CAST(CAST('2026-09-10' AS TIMESTAMP) AS LONG) AS milliseconds;
SELECT CAST(CAST('2026-09-10' AS DATE) AS LONG);
```

Result:

| milliseconds (LONG) |
|---|
| 1788998400000 |

(1 row)

Error: `line 2, column 8: cannot convert '2026-09-10' to LONG`

<a id="into-double"></a>

## Into DOUBLE and FLOAT

Syntax:

```sql
CAST(value AS DOUBLE | FLOAT)
```

Numbers with a fraction. `DOUBLE` keeps about 15 digits. `FLOAT` is smaller and keeps about 7 digits.

| From | Result |
|---|---|
| any number (`LONG`, `DOUBLE`, `DECIMAL`) | the number |
| text | a number like `'512.5'`, `'-3'` or `'1e3'` |
| `BOOL`, times, `JSON`, `BYTES` | error |

- **Returns:** `DOUBLE` or `FLOAT`.
- **NULL:** stays `NULL`.
- **Notes:**
  - A `DOUBLE` cannot hold every decimal exactly. `0.1 + 0.2` is shown as `0.3`, but the real value is `0.30000000000000004` (see [Into STRING](functions-conversion.md#into-string)). For money use `DECIMAL(2)`.
  - `FLOAT` loses digits: `CAST(0.1 AS FLOAT)` shows `0.100000001490116`. A value above about 3.4e38 is an error.
  - `/` already gives a `DOUBLE` (`7 / 2` is `3.5`), so `CAST(7 AS DOUBLE) / 2` is not needed (it is after `SET int_division = integer`: [integer division](operators.md#integer-division)).

**Example**

```sql
SELECT CAST('512.5' AS DOUBLE) AS a, CAST('1e3' AS DOUBLE) AS b,
       CAST(CAST('1.25' AS DECIMAL(2)) AS DOUBLE) AS c, CAST(0.1 AS FLOAT) AS d, 0.1 + 0.2 AS e;
```

Result:

| a (DOUBLE) | b (DOUBLE) | c (DOUBLE) | d (DOUBLE) | e (DOUBLE) |
|---|---|---|---|---|
| 512.5 | 1000 | 1.25 | 0.100000001490116 | 0.3 |

(1 row)

**Example: Ledger amounts as DOUBLE for a chart**

```sql
SELECT day, account, amount, CAST(amount AS DOUBLE) AS amount_double
FROM ledger
ORDER BY id;
```

Result:

| day (DATE) | account (STRING) | amount (DECIMAL(2)) | amount_double (DOUBLE) |
|---|---|---|---|
| 2026-09-01 | Sales | 1250.00 | 1250 |
| 2026-09-02 | Sales | 899.99 | 899.99 |
| 2026-09-02 | Rent | 1200.50 | 1200.5 |

(3 rows)

**Example: Text that is not a number** (shows an error)

```sql
SELECT CAST('$512' AS DOUBLE);
```

Result:

Error: `line 1, column 8: cannot convert '$512' to DOUBLE`

<a id="into-decimal"></a>

## Into DECIMAL(s)

Syntax:

```sql
CAST(value AS DECIMAL(scale))
```

An exact number with `scale` places after the point. `DECIMAL(2)` is right for dollars and cents.

| From | Result |
|---|---|
| a whole number | `7` becomes `7.00` |
| `DECIMAL` | the same value with the new scale, if no digit is lost |
| `DOUBLE` | the value rounded to `scale` places: `12.345` gives `12.35` for `DECIMAL(2)` |
| text | a number like `'1250.75'`; more places than `scale` are rounded |
| `BOOL`, times, `JSON`, `BYTES` | error |

| Part | Meaning |
|---|---|
| `scale` | `DECIMAL(s)`: 0 to 18 (18 digits in all). `NUMERIC(p, s)`: 0 to 38, `p` up to 38 digits |

- **Returns:** `DECIMAL(scale)`.
- **NULL:** stays `NULL`.
- **Notes:**
  - More places than `scale` are **rounded** to the nearest, half away from zero. `CAST(round(x, 2) AS DECIMAL(2))` says the same thing and is clearer to read.
  - `DECIMAL` **without** a scale is not exact money: it is the same as `DOUBLE`.
  - Arithmetic with `DECIMAL` values (`amount * 0.13`, `debit - credit`) is exact and gives a `DECIMAL`, as in PostgreSQL ([DECIMAL](column-types.md#decimal)). CAST it to `DECIMAL(2)` to show it with 2 places. `sum` and `avg` of `DECIMAL` values are `DECIMAL` too ([sum](functions-aggregate.md#sum)).
  - A `DOUBLE` like `0.1 + 0.2` is close enough to `0.30`, so `CAST(0.1 + 0.2 AS DECIMAL(2))` gives `0.30`.
  - `DECIMAL(s)` keeps 18 digits in 64 bits: with 2 places the largest value is `92233720368547758.07`. `NUMERIC(p, s)` keeps its `p` digits, up to 38: `CAST(x AS NUMERIC(24,2))` holds 22 digits before the point, and more is an error that names the type you wrote: `cannot convert '...' to NUMERIC(24,2): numeric field overflow`.

**Example**

```sql
SELECT CAST(7 AS DECIMAL(2)) AS a, CAST('1250.75' AS DECIMAL(2)) AS b, CAST(1500.256 AS DECIMAL(3)) AS c,
       CAST(0.1 + 0.2 AS DECIMAL(2)) AS d, CAST(CAST('1.5' AS DECIMAL(1)) AS DECIMAL(3)) AS e;
```

Result:

| a (DECIMAL(2)) | b (DECIMAL(2)) | c (DECIMAL(3)) | d (DECIMAL(2)) | e (DECIMAL(3)) |
|---|---|---|---|---|
| 7.00 | 1250.75 | 1500.256 | 0.30 | 1.500 |

(1 row)

**Example: Month report: totals and average per account, exact to the cent**

```sql
SELECT account,
       sum(amount) AS total,
       CAST(round(avg(amount), 2) AS DECIMAL(2)) AS average,
       count(*) AS lines
FROM ledger
WHERE day IN '2026-09'
GROUP BY account
ORDER BY account;
```

Result:

| account (STRING) | total (DECIMAL(2)) | average (DECIMAL(2)) | lines (LONG) |
|---|---|---|---|
| Rent | 1200.50 | 1200.50 | 1 |
| Sales | 2149.99 | 1075.00 | 2 |

(2 rows)

**Example: Too many places are rounded, not refused**

```sql
SELECT CAST(12.345 AS DECIMAL(2)) AS rounded_up, CAST(12.344 AS DECIMAL(2)) AS rounded_down,
       CAST('1250.756' AS DECIMAL(2)) AS from_text;
```

Result:

| rounded_up (DECIMAL(2)) | rounded_down (DECIMAL(2)) | from_text (DECIMAL(2)) |
|---|---|---|
| 12.35 | 12.34 | 1250.76 |

(1 row)

**Example: NUMERIC(24,2) holds 24 digits**

```sql
SELECT CAST(123456789012345678.12 AS NUMERIC(24,2)) AS big, CAST(1 AS NUMERIC(20,2)) / 3 AS third;
```

Result:

| big (DECIMAL(38,2)) | third (DECIMAL(38,20)) |
|---|---|
| 123456789012345678.12 | 0.33333333333333333333 |

(1 row)

<a id="into-timestamp"></a>

## Into TIMESTAMP

Syntax:

```sql
CAST(value AS TIMESTAMP)
```

A moment in time, stored as milliseconds since 1970-01-01 UTC. KarelaDB always shows it in UTC, like `2026-09-10T05:15:00.000Z`.

| From | Result |
|---|---|
| time text | `'2026-09-10'`, `'2026-09-10 11:00'`, `'2026-09-10T11:00:00.123'`, with an optional `Z`, `+05:45` or `+0545` at the end. No zone means UTC |
| `DATE` | midnight UTC of that day |
| a whole number | that many milliseconds after 1970-01-01 UTC |
| `DOUBLE`, `BOOL`, `JSON`, `BYTES` | error |

- **Returns:** `TIMESTAMP`.
- **NULL:** stays `NULL`.
- **Notes:**
  - A local time must be written with its zone offset, for example `+05:45` for Nepal. `'2026-09-10 11:00'` is 11:00 **UTC**, which is 16:45 in Nepal.
  - Zone names (`NPT`, `Asia/Kathmandu`) are not allowed inside the text. Only an offset like `+05:45`.
  - Other date orders (`'10/09/2026'`), one-digit months (`'2026-9-1'`) and `24:00` are errors. More than 3 digits after the second are cut to milliseconds.
  - The same as [to_timestamp](functions-conversion.md#to_timestamp).

**Example**

```sql
SELECT CAST('2026-09-10T11:00:00+05:45' AS TIMESTAMP) AS nepal_11am,
       CAST('2026-09-10 11:00' AS TIMESTAMP) AS utc_11am,
       CAST(CAST('2026-09-10' AS DATE) AS TIMESTAMP) AS from_date,
       CAST(0 AS TIMESTAMP) AS zero,
       CAST('2026-09-10T11:00:00.123456+0545' AS TIMESTAMP) AS micro_cut;
```

Result:

| nepal_11am (TIMESTAMP) | utc_11am (TIMESTAMP) | from_date (TIMESTAMP) | zero (TIMESTAMP) | micro_cut (TIMESTAMP) |
|---|---|---|---|---|
| 2026-09-10T05:15:00.000Z | 2026-09-10T11:00:00.000Z | 2026-09-10T00:00:00.000Z | 1970-01-01T00:00:00.000Z | 2026-09-10T05:15:00.123Z |

(1 row)

**Example: Market open and close (Nepal time) as UTC times** (sample data: sample)

```sql
SELECT symbol, count(*) AS minutes, min(time) AS first_minute, max(time) AS last_minute
FROM ochl_minutes
WHERE time >= CAST('2026-09-10T11:00:00+05:45' AS TIMESTAMP)
  AND time <  CAST('2026-09-10T15:00:00+05:45' AS TIMESTAMP)
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | minutes (LONG) | first_minute (TIMESTAMP) | last_minute (TIMESTAMP) |
|---|---|---|---|
| CITY | 240 | 2026-09-10T05:15:00.000Z | 2026-09-10T09:14:00.000Z |
| COAST | 236 | 2026-09-10T05:15:00.000Z | 2026-09-10T09:14:00.000Z |

(2 rows)

**Example: Day/month/year order is not read** (shows an error)

```sql
SELECT CAST('10/09/2026' AS TIMESTAMP);
```

Result:

Error: `line 1, column 8: cannot convert '10/09/2026' to TIMESTAMP`

<a id="into-date"></a>

## Into DATE

Syntax:

```sql
CAST(value AS DATE)
```

A day without a clock time, shown like `2026-09-10`.

| From | Result |
|---|---|
| date text | `'2026-09-10'` |
| time text | the **UTC** date of that time |
| `TIMESTAMP` | the UTC date |
| numbers, `BOOL`, `JSON`, `BYTES` | error (use [to_date](functions-conversion.md#to_date) for milliseconds) |

- **Returns:** `DATE`.
- **NULL:** stays `NULL`.
- **Notes:**
  - `'2026-09-10T03:00:00+05:45'` is 21:15 UTC on 9 September, so its `DATE` is `2026-09-09`.
  - A date that does not exist (`'2026-02-30'`) is an error.
  - `DATE + 1` is the next day.

**Example**

```sql
SELECT CAST('2026-09-10' AS DATE) AS a,
       CAST('2026-09-10T03:00:00+05:45' AS DATE) AS nepal_early_morning,
       CAST(CAST('2026-09-10T23:59:00Z' AS TIMESTAMP) AS DATE) AS b,
       CAST('2026-09-10' AS DATE) + 1 AS next_day;
```

Result:

| a (DATE) | nepal_early_morning (DATE) | b (DATE) | next_day (DATE) |
|---|---|---|---|
| 2026-09-10 | 2026-09-09 | 2026-09-10 | 2026-09-11 |

(1 row)

**Example: Trades per day from the trade log** (sample data: sample)

```sql
SELECT CAST(date AS DATE) AS trade_day, count(*) AS trades, sum(quantity) AS shares
FROM trade_log
GROUP BY CAST(date AS DATE)
ORDER BY trade_day;
```

Result:

| trade_day (DATE) | trades (LONG) | shares (LONG) |
|---|---|---|
| 2026-09-09 | 8 | 3730 |
| 2026-09-10 | 24 | 4930 |

(2 rows)

**Example: There is no 30 February** (shows an error)

```sql
SELECT CAST('2026-02-30' AS DATE);
```

Result:

Error: `line 1, column 8: cannot convert '2026-02-30' to DATE`

**Example: CAST into DATE does not take a number** (shows an error)

```sql
SELECT CAST(20260910 AS DATE);
```

Result:

Error: `line 1, column 8: cannot convert '20260910' to DATE`

<a id="into-bool"></a>

## Into BOOL

Syntax:

```sql
CAST(value AS BOOL | BOOLEAN)
```

`true` or `false`.

| From | Result |
|---|---|
| `TRUE` / `FALSE` | the same |
| the whole numbers `1` / `0` | `true` / `false`; any other number is an error |
| text | `'true'`, `'t'`, `'1'` are `true`; `'false'`, `'f'`, `'0'` are `false` (any letter case) |
| `DOUBLE`, times, `JSON`, `BYTES` | error |

- **Returns:** `BOOL`.
- **NULL:** stays `NULL`.
- **Notes:** `'yes'`, `'no'`, `2` and `1.0` are errors. Map them with [CASE](functions-conditional.md#case-simple) first.

**Example**

```sql
SELECT CAST(1 AS BOOL) AS a, CAST(0 AS BOOL) AS b, CAST('TRUE' AS BOOL) AS c, CAST('f' AS BOOL) AS d, '1'::BOOLEAN AS e;
```

Result:

| a (BOOL) | b (BOOL) | c (BOOL) | d (BOOL) | e (BOOL) |
|---|---|---|---|---|
| true | false | true | false | true |

(1 row)

**Example: A yes/no column from an import** (shows an error)

```sql
SELECT CAST('yes' AS BOOL);
```

Result:

Error: `line 1, column 8: cannot convert 'yes' to BOOL`

**Example: Map yes/no with CASE, then it works**

```sql
SELECT answer, CASE lower(answer) WHEN 'yes' THEN TRUE WHEN 'no' THEN FALSE END AS agreed
FROM (SELECT 'Yes' AS answer UNION ALL SELECT 'no') t;
```

Result:

| answer (STRING) | agreed (BOOL) |
|---|---|
| Yes | true |
| no | false |

(2 rows)

<a id="into-string"></a>

## Into STRING and SYMBOL

Syntax:

```sql
CAST(value AS STRING | VARCHAR | TEXT | SYMBOL)
```

Text. Every value can become text.

| From | Text |
|---|---|
| whole number | `42` |
| `DOUBLE` | the shortest form that reads back the same: `512.5`, `0.30000000000000004` |
| `DECIMAL(s)` | with all `s` places: `1.50` |
| `BOOL` | `true` / `false` |
| `TIMESTAMP` | UTC in ISO form: `2026-09-10T05:15:00.000Z` |
| `DATE` | `2026-09-10` |
| `JSON` | the JSON text; a JSON string keeps its quotes (`"text"`) |
| `BYTES` | hex with `\x` in front: `\x4e41` |

- **Returns:** `STRING` (or `SYMBOL`).
- **NULL:** stays `NULL`. An empty text `''` is not `NULL`.
- **Notes:**
  - For a time in another format or in Nepal time use [to_char](functions-date-time.md#to_char).
  - To get the text inside a JSON string without quotes, use `->>` or `json_value_text` ([JSON functions](functions-json.md)).
  - `||` already turns numbers into text: `'CITY-' || 1`.

**Example**

```sql
SELECT CAST(42 AS STRING) AS a, CAST(512.5 AS TEXT) AS b, CAST(CAST('1.50' AS DECIMAL(2)) AS VARCHAR) AS c,
       CAST(TRUE AS STRING) AS d, CAST(CAST('2026-09-10T11:00:00+05:45' AS TIMESTAMP) AS STRING) AS e,
       CAST(0.1 + 0.2 AS STRING) AS f;
```

Result:

| a (STRING) | b (STRING) | c (STRING) | d (STRING) | e (STRING) | f (STRING) |
|---|---|---|---|---|---|
| 42 | 512.5 | 1.50 | true | 2026-09-10T05:15:00.000Z | 0.30000000000000004 |

(1 row)

**Example: A label for a chart: symbol, date and close** (sample data: sample)

```sql
SELECT symbol || ' ' || CAST(CAST(time AS DATE) AS STRING) || ': ' || CAST(close AS STRING) AS label
FROM ochl_day
WHERE symbol = 'VOLT'
ORDER BY time DESC
LIMIT 3;
```

Result:

| label (STRING) |
|---|
| VOLT 2026-09-10: 191.2 |
| VOLT 2026-09-09: 187.3 |
| VOLT 2026-09-08: 182.4 |

(3 rows)

**Example: JSON and BYTES as text**

```sql
SELECT CAST(CAST('{"a": 1}' AS JSON) AS STRING) AS json_object,
       CAST(CAST('"text"' AS JSON) AS STRING) AS json_string,
       CAST(CAST('NA' AS BYTES) AS STRING) AS bytes;
```

Result:

| json_object (STRING) | json_string (STRING) | bytes (STRING) |
|---|---|---|
| {"a":1} | "text" | \\x4e41 |

(1 row)

<a id="into-json"></a>

## Into JSON

Syntax:

```sql
CAST(value AS JSON | JSONB)
```

A JSON document (a text format for data, like `{"name": "Sita", "tags": [1, 2]}`). KarelaDB checks it and stores it without extra spaces.

| From | Result |
|---|---|
| text | parsed as JSON; bad JSON is an error that says where the problem is |
| numbers, `DECIMAL` | a JSON number: `5`, `1.50` |
| `BOOL` | `true` / `false` |
| `TIMESTAMP`, `DATE`, `BYTES` | a JSON string with their text: `"2026-09-10"` |

- **Returns:** `JSON`.
- **NULL:** SQL `NULL` stays `NULL`. The text `'null'` becomes the JSON value `null`, which is **not** SQL `NULL` (`IS NULL` is false).
- **Notes:**
  - A text value must be valid JSON. The word `CITY` is not JSON; `'"CITY"'` (with double quotes inside) is. See [JSON functions](functions-json.md) for reading parts of a document.
  - The result tables on this page show a JSON string without its quotes, and a JSON `null` as `NULL`.

**Example**

```sql
SELECT CAST('{"symbol": "CITY", "levels": [500, 520]}' AS JSON) AS a,
       CAST(5 AS JSON) AS b, CAST(TRUE AS JSONB) AS c,
       CAST(CAST('2026-09-10' AS DATE) AS JSON) AS d,
       CAST('null' AS JSON) AS json_null, CAST('null' AS JSON) IS NULL AS is_sql_null;
```

Result:

| a (JSON) | b (JSON) | c (JSON) | d (JSON) | json_null (JSON) | is_sql_null (BOOL) |
|---|---|---|---|---|---|
| {"symbol":"CITY","levels":[500,520]} | 5 | true | "2026-09-10" | NULL | false |

(1 row)

**Example: App settings saved as JSON text**

Setup:

```sql
CREATE TABLE user_settings (user_id INT PRIMARY KEY, settings STRING);
INSERT INTO user_settings VALUES (1, '{ "theme": "dark",  "alerts": ["CITY", "COAST"] }'), (2, '{"theme": "light", "alerts": []}');
```

```sql
SELECT user_id, CAST(settings AS JSON) AS settings_json
FROM user_settings
ORDER BY user_id;
```

Result:

| user_id (INT) | settings_json (JSON) |
|---|---|
| 1 | {"theme":"dark","alerts":["CITY","COAST"]} |
| 2 | {"theme":"light","alerts":[]} |

(2 rows)

**Example: Keys need double quotes** (shows an error)

```sql
SELECT CAST('{theme: "dark"}' AS JSON);
```

Result:

Error: `line 1, column 8: cannot convert '{theme: "dark"}' to JSON: not valid JSON: expected a key in double quotes at character 2 (near 'theme: "dark...')`

<a id="into-bytes"></a>

## Into BYTES

Syntax:

```sql
CAST(value AS BYTES | BYTEA | BLOB)
```

Raw bytes, shown as hex with `\x` in front (`\x0a0b`).

| From | Result |
|---|---|
| text that starts with `\x` | read as hex digits: `'\x4e41'` is the two bytes 4e and 41 |
| other text | its UTF-8 bytes: `'NA'` is `\x4e41`; a Nepali letter is 3 bytes |
| `X'0A0B'` | already bytes |
| numbers, `BOOL`, times, `JSON` | error |

- **Returns:** `BYTES`.
- **NULL:** stays `NULL`.
- **Notes:** `CAST(bytes AS STRING)` does not give the letters back; it gives the hex text. See [bytes functions](functions-bytes.md) for `hex`, `unhex` and base64.

**Example**

```sql
SELECT CAST('\x4e41' AS BYTES) AS from_hex, CAST('CITY' AS BYTEA) AS from_text,
       CAST(X'0A0B' AS BLOB) AS literal, CAST('नेपाल' AS BYTES) AS nepali, length(CAST('नेपाल' AS BYTES)) AS byte_count;
```

Result:

| from_hex (BYTES) | from_text (BYTES) | literal (BYTES) | nepali (BYTES) | byte_count (LONG) |
|---|---|---|---|---|
| \\x4e41 | \\x43495459 | \\x0a0b | \\xe0a4a8e0a587e0a4aae0a4bee0a4b2 | 15 |

(1 row)

**Example: Bad hex digits** (shows an error)

```sql
SELECT CAST('\xZZ' AS BYTES);
```

Result:

Error: `line 1, column 8: cannot convert '\xZZ' to BYTES: '\xZZ' is not hex bytes; write them like '\x0a0b' or X'0A0B'`

**Example: A number is not bytes** (shows an error)

```sql
SELECT CAST(5 AS BYTES);
```

Result:

Error: `line 1, column 8: cannot convert '5' to BYTES: expected bytes like X'0A0B' or '\x0a0b', got LONG 5`
