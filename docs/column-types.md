# Column types

> Every column type, its range, how NULL is kept, and which values it accepts.

- Category: Tables
- Keywords: data type, type, types, column type, conversion, convert value, range, overflow, out of range, NULL storage, money, exact, precision, BOOL, BOOLEAN, BYTE, SHORT, INT, INTEGER, LONG, BIGINT, FLOAT, DOUBLE, DECIMAL, NUMERIC, DATE, TIMESTAMP, SYMBOL, STRING, VARCHAR, TEXT, JSON, JSONB, BYTES, BYTEA, BLOB, UUID, gen\_random\_uuid, ENUM, CREATE TYPE, ALTER TYPE, DROP TYPE, pg\_enum, label, hex, utf-8, time zone, +05:45, milliseconds
- See also: [CREATE TABLE](create-table.md), [INSERT](insert.md), [Conversion functions](functions-conversion.md), [Time and time zones](time-and-time-zones.md), [SQL basics](sql-basics.md)

Every column has a **type**. The type says what values the column holds, and how much space one value takes. When a row is written, KDB **converts** each value to the column type, or refuses the row with a clear message.

| Type | Also written | Size | Values | Use it for |
|---|---|---|---|---|
| [`BOOL`](#bool) | `BOOLEAN` | 1 byte | `TRUE`, `FALSE` | yes/no flags |
| [`BYTE`](#byte) | | 1 byte | -127 to 127 | very small numbers |
| [`SHORT`](#short) | | 2 bytes | -32767 to 32767 | small numbers |
| [`INT`](#int) | `INTEGER` | 4 bytes | -2147483647 to 2147483647 | broker ids, counts |
| [`LONG`](#long) | `BIGINT` | 8 bytes | about ±9.2 × 10^18 | ids, share quantities |
| [`FLOAT`](#float) | | 4 bytes | about 7 digits | rarely needed |
| [`DOUBLE`](#double) | | 8 bytes | about 15 digits | prices, volumes, indicators |
| [`DECIMAL(s)`](#decimal) | | 8 bytes | exact, up to 18 digits, `s` after the point | **money** |
| [`NUMERIC(p, s)`](#decimal) | `DECIMAL(p, s)` | 8 or 16 bytes | exact, up to 38 digits | big money totals, TPoint |
| [`DATE`](#date) | | 4 bytes | a day | birthdays, report dates |
| [`TIMESTAMP`](#timestamp) | | 8 bytes | a moment in UTC, in milliseconds | candle and trade times |
| [`SYMBOL`](#symbol) | | 4 bytes | text that repeats a lot | stock symbols, sectors |
| [`STRING`](#string) | `VARCHAR`, `TEXT` | length + text | any text, up to 16 MB | names, posts, news |
| [`JSON`](#json) | `JSONB` | length + text | checked JSON, up to 16 MB | flexible extra data |
| [`BYTES`](#bytes) | `BYTEA`, `BLOB` | length + bytes | any bytes, up to 16 MB | hashes, keys, small files |
| [`UUID`](#uuid) | | 16 bytes | a UUID like `a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11` | ids made by apps, `gen_random_uuid()` |
| [an ENUM type](#enum) | made by `CREATE TYPE ... AS ENUM` | 4 bytes | one label of a fixed list | order status, moods, levels |

- Every type can hold `NULL`. For number types, the smallest value is used to keep `NULL`. That is why `BYTE` goes to -127, not -128.
- Type names do not care about case. `VARCHAR(100)` with a length is **not** accepted: write `STRING`.
- You cannot change the type of a column later ([ALTER TABLE](alter-table.md)).
- To convert in a query, use `CAST(x AS TYPE)` or `x::TYPE`; see [conversion functions](functions-conversion.md).

**Example: All basic types in one table**

```sql
CREATE TABLE type_demo (
  b BOOL, i8 BYTE, i16 SHORT, i32 INT, i64 LONG, f FLOAT, d DOUBLE, m DECIMAL(2),
  day DATE, ts TIMESTAMP, sym SYMBOL, txt STRING
);
INSERT INTO type_demo VALUES
  (TRUE, 127, 32767, 2147483647, 270578640, 1.5, 512.45, 1500.25,
   '2026-09-10', '2026-09-10T11:00:00+05:45', 'CITY', 'City Bank Limited'),
  (NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
SELECT * FROM type_demo;
```

Result:

`CREATE TABLE type_demo (`

```text
table 'type_demo' created
```

`INSERT INTO type_demo VALUES (TRUE, 127, 32767, 2147483647, 270578640, 1.5, 512.45, 1500.25, '2026-0`

```text
2 row(s) inserted
```

`SELECT * FROM type_demo`

| b (BOOL) | i8 (BYTE) | i16 (SHORT) | i32 (INT) | i64 (LONG) | f (FLOAT) | d (DOUBLE) | m (DECIMAL(2)) | day (DATE) | ts (TIMESTAMP) | sym (SYMBOL) | txt (STRING) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| true | 127 | 32767 | 2147483647 | 270578640 | 1.5 | 512.45 | 1500.25 | 2026-09-10 | 2026-09-10T05:15:00.000Z | CITY | City Bank Limited |
| NULL | NULL | NULL | NULL | NULL | NULL | NULL | NULL | NULL | NULL | NULL | NULL |

(2 rows)

<a id="bool"></a>

## BOOL, BOOLEAN

Syntax:

```sql
column BOOL
column BOOLEAN
```

`TRUE` or `FALSE`.

| Value written | Stored as |
|---|---|
| `TRUE`, `FALSE` | itself |
| `1`, `0` | `TRUE`, `FALSE` |
| `'true'`, `'false'`, `'t'`, `'f'`, `'1'`, `'0'` (any case) | `TRUE`, `FALSE` |
| anything else (`2`, `1.0`, `'yes'`) | error |

- **NULL:** `NULL` is allowed unless the column is `NOT NULL`; it is kept as a special third value.
- **Notes:** in a query, a `BOOL` is not a number: `TRUE = 1` is an error.

**Example: Verified users, written in different ways**

```sql
CREATE TABLE users (id INT PRIMARY KEY, verified BOOL, is_admin BOOLEAN NOT NULL DEFAULT FALSE);
INSERT INTO users (id, verified) VALUES (1, TRUE), (2, 0), (3, 'true'), (4, NULL);
SELECT id, verified, is_admin FROM users;
```

Result:

`CREATE TABLE users (`

```text
table 'users' created
```

`INSERT INTO users (id, verified) VALUES (1, TRUE), (2, 0), (3, 'true'), (4, NULL)`

```text
4 row(s) inserted
```

`SELECT id, verified, is_admin FROM users`

| id (INT) | verified (BOOL) | is_admin (BOOL) |
|---|---|---|
| 1 | true | false |
| 2 | false | false |
| 3 | true | false |
| 4 | NULL | false |

(4 rows)

**Example: 'yes' is not a BOOL** (shows an error)

Setup:

```sql
CREATE TABLE users (id INT PRIMARY KEY, verified BOOL);
```

```sql
INSERT INTO users VALUES (1, 'yes');
```

Result:

Error: `column 'verified' (BOOL): 'yes' is not true or false`

<a id="byte"></a>

## BYTE

Syntax:

```sql
column BYTE
```

A whole number from -127 to 127, in 1 byte.

- **NULL:** kept as -128, so -128 itself cannot be stored.
- Accepts the same values as [INT](#int).

**Example: Star rating of a forum post**

```sql
CREATE TABLE ratings (post_id LONG, stars BYTE NOT NULL);
INSERT INTO ratings VALUES (1, 5), (2, 3);
SELECT post_id, stars FROM ratings;
```

Result:

`CREATE TABLE ratings (`

```text
table 'ratings' created
```

`INSERT INTO ratings VALUES (1, 5), (2, 3)`

```text
2 row(s) inserted
```

`SELECT post_id, stars FROM ratings`

| post_id (LONG) | stars (BYTE) |
|---|---|
| 1 | 5 |
| 2 | 3 |

(2 rows)

**Example: Too big for BYTE** (shows an error)

Setup:

```sql
CREATE TABLE t (v BYTE);
```

```sql
INSERT INTO t VALUES (200);
```

Result:

Error: `column 'v' (BYTE): 200 is out of range (-127 to 127)`

<a id="short"></a>

## SHORT

Syntax:

```sql
column SHORT
```

A whole number from -32767 to 32767, in 2 bytes.

- **NULL:** kept as -32768.
- Accepts the same values as [INT](#int).

**Example: Fiscal quarter and year numbers**

```sql
CREATE TABLE results (symbol SYMBOL, fiscal_year SHORT, quarter SHORT);
INSERT INTO results VALUES ('CITY', 2082, 4);
SELECT symbol, fiscal_year, quarter FROM results;
```

Result:

`CREATE TABLE results (`

```text
table 'results' created
```

`INSERT INTO results VALUES ('CITY', 2082, 4)`

```text
1 row(s) inserted
```

`SELECT symbol, fiscal_year, quarter FROM results`

| symbol (SYMBOL) | fiscal_year (SHORT) | quarter (SHORT) |
|---|---|---|
| CITY | 2082 | 4 |

(1 row)

<a id="int"></a>

## INT, INTEGER

Syntax:

```sql
column INT
column INTEGER
```

A whole number from -2147483647 to 2147483647, in 4 bytes.

| Value written | Stored as |
|---|---|
| a whole number: `42`, `-7` | itself |
| a `DOUBLE` with no fraction: `5.0`, `1e3` | `5`, `1000` |
| a `DECIMAL` with no fraction: `12.00` | `12` |
| text with a whole number: `'42'` | `42` |
| `TRUE`, `FALSE` | `1`, `0` |
| `5.5`, `'5.0'`, `'abc'` | error: not a whole number |
| a number outside the range | error: out of range |

- **NULL:** kept as the smallest `INT` (-2147483648).
- **Notes:** use `LONG` when a number might grow past 2 billion (ids of a big table, share quantities, money in cents).

**Example: Broker ids written as numbers and as text**

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING, branch_count INTEGER);
INSERT INTO brokers VALUES (58, 'Northgate Securities', 5), ('45', 'Imperial Securities', 2.0);
SELECT id, name, branch_count FROM brokers ORDER BY id;
```

Result:

`CREATE TABLE brokers (`

```text
table 'brokers' created
```

`INSERT INTO brokers VALUES (58, 'Northgate Securities', 5), ('45', 'Imperial Securities', 2.0)`

```text
2 row(s) inserted
```

`SELECT id, name, branch_count FROM brokers ORDER BY id`

| id (INT) | name (STRING) | branch_count (INT) |
|---|---|---|
| 45 | Imperial Securities | 2 |
| 58 | Northgate Securities | 5 |

(2 rows)

**Example: A number out of range** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING);
```

```sql
INSERT INTO brokers VALUES (3000000000, 'Too Big');
```

Result:

Error: `column 'id' (INT): 3000000000 is out of range (-2147483647 to 2147483647)`

**Example: A fraction for a whole-number column** (shows an error)

Setup:

```sql
CREATE TABLE trade_log_small (id INT, quantity INT);
```

```sql
INSERT INTO trade_log_small VALUES (1, 10.5);
```

Result:

Error: `column 'quantity' (INT): 10.5 is not a whole number`

<a id="long"></a>

## LONG, BIGINT

Syntax:

```sql
column LONG
column BIGINT
```

A whole number from -9223372036854775807 to 9223372036854775807, in 8 bytes.

- Accepts the same values as [INT](#int).
- **NULL:** kept as the smallest `LONG` (-9223372036854775808).
- **Notes:** a good type for `PRIMARY KEY AUTO` ids, transaction numbers and share quantities.

**Example: Transaction ids and quantities**

```sql
CREATE TABLE trades (transaction_id BIGINT PRIMARY KEY, quantity LONG);
INSERT INTO trades VALUES (2026091000012345, 270578640);
SELECT transaction_id, quantity FROM trades;
```

Result:

`CREATE TABLE trades (`

```text
table 'trades' created
```

`INSERT INTO trades VALUES (2026091000012345, 270578640)`

```text
1 row(s) inserted
```

`SELECT transaction_id, quantity FROM trades`

| transaction_id (LONG) | quantity (LONG) |
|---|---|
| 2026091000012345 | 270578640 |

(1 row)

<a id="float"></a>

## FLOAT

Syntax:

```sql
column FLOAT
```

A number with a fraction, in 4 bytes. It keeps about **7** digits, so `512.45` comes back as `512.450012207031`.

- Accepts numbers and text like `'512.5'`. Bigger than about 3.4e38 is an error.
- **NULL:** kept as NaN (not a number).
- **Notes:** use `DOUBLE` for prices. `FLOAT` only saves space when you have very many rows and need few digits. Indexes are not used on `FLOAT` columns.

**Example: FLOAT keeps fewer digits than DOUBLE**

```sql
CREATE TABLE t (f FLOAT, d DOUBLE);
INSERT INTO t VALUES (512.45, 512.45);
SELECT f, d FROM t;
```

Result:

`CREATE TABLE t (`

```text
table 't' created
```

`INSERT INTO t VALUES (512.45, 512.45)`

```text
1 row(s) inserted
```

`SELECT f, d FROM t`

| f (FLOAT) | d (DOUBLE) |
|---|---|
| 512.450012207031 | 512.45 |

(1 row)

<a id="double"></a>

## DOUBLE

Syntax:

```sql
column DOUBLE
```

A number with a fraction, in 8 bytes, with about **15** digits. Fast, and good for prices, volumes, percentages and indicators.

- Accepts numbers, `DECIMAL` values and text like `'512.5'` or `'1.5e3'`.
- **NULL:** kept as NaN.
- **Notes:** a `DOUBLE` is **not exact**: `0.1 + 0.2` is not exactly `0.3`. For money that must add up exactly, use [DECIMAL](#decimal). In a **relational table** a NaN is stored as NaN, as in PostgreSQL: the text `'NaN'`, a NaN an expression makes (`CAST('NaN' AS DOUBLE)`, `x * 'NaN'`) and a driver's NaN parameter. It is shown as `NaN` and is **not** `IS NULL`; write `NULL` for a missing value. (Before 2026-09-25 a NaN from an expression was stored as `NULL`.) The HTTP API writes NaN and infinities as JSON `null` unless you ask for `?nan=string` ([/exec](http-exec.md)).
- **NaN in a time-series table:** stored as `NULL`, as QuestDB does (since 2026-10-02). So `open IS NULL OR open <= 0`, the price guard written for QuestDB, also finds a bar whose price came in as NaN. A [CHECK](constraints.md#check) still sees the NaN first and refuses it, and a `NOT NULL` column refuses it too. Rows written before 2026-10-02 keep their NaN.
- **NaN in comparisons:** as in PostgreSQL, a NaN equals only another NaN and is **bigger than every number**, `Infinity` too: `100 = 'NaN'` is false, `'NaN' > 0` is true, `ORDER BY` puts NaN after every number, and `max()` of a column with a NaN is NaN. In `GROUP BY`, `DISTINCT`, `count(DISTINCT x)`, `UNION` and `PARTITION BY` all NaNs make one group of their own, apart from the NULLs. A [CHECK](constraints.md#check) is stricter: there every comparison with a NaN is false, so `CHECK (price > 0)` keeps it out. Find NaN with [is_nan(x)](functions-math.md#is_nan) or `x = 'NaN'`.

**Example: Prices, and why DOUBLE is not for money**

```sql
CREATE TABLE prices (symbol SYMBOL, ltp DOUBLE, pct_change DOUBLE);
INSERT INTO prices VALUES ('CITY', 527.1, '2.71'), ('COAST', 401.9, 0.7);
SELECT symbol, ltp, pct_change FROM prices;
SELECT 0.1 + 0.2 AS sum, 0.1 + 0.2 = 0.3 AS equal;
```

Result:

`CREATE TABLE prices (`

```text
table 'prices' created
```

`INSERT INTO prices VALUES ('CITY', 527.1, '2.71'), ('COAST', 401.9, 0.7)`

```text
2 row(s) inserted
```

`SELECT symbol, ltp, pct_change FROM prices`

| symbol (SYMBOL) | ltp (DOUBLE) | pct_change (DOUBLE) |
|---|---|---|
| CITY | 527.1 | 2.71 |
| COAST | 401.9 | 0.7 |

(2 rows)

`SELECT 0.1 + 0.2 AS sum, 0.1 + 0.2 = 0.3 AS equal`

| sum (DOUBLE) | equal (BOOL) |
|---|---|
| 0.3 | false |

(1 row)

**Example: A NaN is stored as NaN, however it is written**

```sql
CREATE TABLE readings (id INT, v DOUBLE);
INSERT INTO readings VALUES (1, 'NaN'), (2, CAST('NaN' AS DOUBLE)), (3, 12.5);
SELECT id, v, v IS NULL AS is_null, is_nan(v) AS is_nan FROM readings ORDER BY id;
```

Result:

`CREATE TABLE readings (`

```text
table 'readings' created
```

`INSERT INTO readings VALUES (1, 'NaN'), (2, CAST('NaN' AS DOUBLE)), (3, 12.5)`

```text
3 row(s) inserted
```

`SELECT id, v, v IS NULL AS is_null, is_nan(v) AS is_nan FROM readings ORDER BY id`

| id (INT) | v (DOUBLE) | is_null (BOOL) | is_nan (BOOL) |
|---|---|---|---|
| 1 | NULL | false | true |
| 2 | NULL | false | true |
| 3 | 12.5 | false | false |

(3 rows)

**Example: In a time-series table a NaN is NULL, as in QuestDB**

```sql
CREATE TABLE bars (time TIMESTAMP, symbol SYMBOL, open DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO bars VALUES ('2026-09-24T05:15:00Z', 'CITY', 'NaN'), ('2026-09-24T05:15:00Z', 'COAST', 0),
  ('2026-09-24T05:15:00Z', 'RIVER', 512.5);
SELECT symbol, open IS NULL AS is_null FROM bars ORDER BY symbol;
SELECT symbol FROM bars WHERE open IS NULL OR open <= 0 ORDER BY symbol;
```

Result:

`CREATE TABLE bars (`

```text
table 'bars' created
```

`INSERT INTO bars VALUES ('2026-09-24T05:15:00Z', 'CITY', 'NaN'), ('2026-09-24T05:15:00Z', 'COAST', 0`

```text
3 row(s) inserted
```

`SELECT symbol, open IS NULL AS is_null FROM bars ORDER BY symbol`

| symbol (SYMBOL) | is_null (BOOL) |
|---|---|
| CITY | true |
| COAST | false |
| RIVER | false |

(3 rows)

`SELECT symbol FROM bars WHERE open IS NULL OR open <= 0 ORDER BY symbol`

| symbol (SYMBOL) |
|---|
| CITY |
| COAST |

(2 rows)

**Example: A guard for bad prices: missing, zero or less, or NaN**

Setup:

```sql
CREATE TABLE ticks (id INT, open DOUBLE);
INSERT INTO ticks VALUES (1, 100), (2, 0), (3, 'NaN'), (4, NULL), (5, -1);
```

```sql
SELECT id FROM ticks WHERE open IS NULL OR open <= 0 OR open = 'NaN' ORDER BY id;
SELECT id, open FROM ticks ORDER BY open;
```

Result:

`SELECT id FROM ticks WHERE open IS NULL OR open <= 0 OR open = 'NaN' ORDER BY id`

| id (INT) |
|---|
| 2 |
| 3 |
| 4 |
| 5 |

(4 rows)

`SELECT id, open FROM ticks ORDER BY open`

| id (INT) | open (DOUBLE) |
|---|---|
| 5 | -1 |
| 2 | 0 |
| 1 | 100 |
| 3 | NULL |
| 4 | NULL |

(5 rows)

**Example: Text that is not a number** (shows an error)

Setup:

```sql
CREATE TABLE prices (symbol SYMBOL, ltp DOUBLE);
```

```sql
INSERT INTO prices VALUES ('CITY', 'n/a');
```

Result:

Error: `column 'ltp' (DOUBLE): 'n/a' is not a number`

<a id="decimal"></a>

## DECIMAL(s)

Syntax:

```sql
column DECIMAL(scale)
column NUMERIC(precision, scale)
```

An **exact** number with `scale` digits after the point. `DECIMAL(2)` is right for dollars and cents: `0.10 + 0.20` is exactly `0.30`.

| Argument | Type | Meaning |
|---|---|---|
| `scale` | 0 to 18 (`DECIMAL(s)`), 0 to 38 (`NUMERIC(p, s)`) | digits after the point |
| `precision` | 1 to 38 | all digits. Up to 18 the value takes 8 bytes; more takes 16 |

| Value written | Stored as (`DECIMAL(2)`) |
|---|---|
| `1500.25`, `12`, `'99.5'`, `'1.500'` | `1500.25`, `12.00`, `99.50`, `1.50` |
| more digits after the point: `10.555` | **error**: KDB never rounds money by itself |
| more than 18 digits: `123456789012345678.12` | error (`numeric value out of range`): use `NUMERIC(24,2)` |

- **NULL:** a `DECIMAL(s)` keeps it as the smallest `LONG`; a 16-byte `NUMERIC` keeps a flag.
- **Math is exact**, as in PostgreSQL. `DECIMAL` with `DECIMAL`, a whole number or a written decimal (`balance * 1.15`) gives a `DECIMAL`: `+` and `-` keep the larger scale, `*` adds the scales, `/` gives at least 16 significant digits (`10.00 / 3` is `3.3333333333333333`). A `DOUBLE` on either side gives a `DOUBLE`.
- **Notes:** `sum` is exact up to 38 digits, also past 64 bits. `avg` is exact too: `avg` of `1.50` and `2.50` is `2.0000000000000000`. `round(x, 2)` of a `DECIMAL` rounds half away from zero and stays `DECIMAL`.
- **Notes:** a result past 38 digits is an error (`numeric value out of range`, SQLSTATE `22003`), never a rounded number.
- **Notes:** a `NUMERIC(p, s)` column rounds extra places half away from zero (PostgreSQL does too), and refuses more than `p - s` digits before the point (`numeric field overflow`). `DECIMAL(s)` refuses extra places.
- **Notes:** a number written with more than 15 digits (`123456789012345678.12`) is read exactly, not as a `DOUBLE`.
- **Notes:** a table made from a query (`CREATE TABLE ... AS`, a materialized view) stores `avg` or a division of a `DECIMAL` as a `DOUBLE`: their places change with the values, so no one scale fits later rows. A `sum` is stored as `NUMERIC(38, s)`. Write `round(avg(x), 2)` or a cast to keep a `DECIMAL` of your own places.
- **Notes:** the line protocol writes a float field (`price=12.34`) exactly. A field with more places than the column (`1.2100000000000002`, as some clients print doubles) is rounded to the column's places when it is that close to them.
- **Notes:** a result written back to a `DECIMAL(2)` column (`UPDATE ... SET balance = balance * 1.015`) must fit its 2 places. Round it the way your rule says: `round(balance * 1.015, 2)`.

**Example: A wallet balance: exact money**

```sql
CREATE TABLE wallet (id INT PRIMARY KEY, balance DECIMAL(2) NOT NULL);
INSERT INTO wallet VALUES (1, 1000.00), (2, '0.10');
UPDATE wallet SET balance = balance - 250.50 WHERE id = 1;
UPDATE wallet SET balance = balance + 0.20 WHERE id = 2;
SELECT id, balance FROM wallet ORDER BY id;
SELECT sum(balance) AS total FROM wallet;
```

Result:

`CREATE TABLE wallet (`

```text
table 'wallet' created
```

`INSERT INTO wallet VALUES (1, 1000.00), (2, '0.10')`

```text
2 row(s) inserted
```

`UPDATE wallet SET balance = balance - 250.50 WHERE id = 1`

```text
1 row(s) updated
```

`UPDATE wallet SET balance = balance + 0.20 WHERE id = 2`

```text
1 row(s) updated
```

`SELECT id, balance FROM wallet ORDER BY id`

| id (INT) | balance (DECIMAL(2)) |
|---|---|
| 1 | 749.50 |
| 2 | 0.30 |

(2 rows)

`SELECT sum(balance) AS total FROM wallet`

| total (DECIMAL(2)) |
|---|
| 749.80 |

(1 row)

**Example: Interest with too many decimal places is refused** (shows an error)

Setup:

```sql
CREATE TABLE wallet (id INT PRIMARY KEY, balance DECIMAL(2) NOT NULL);
INSERT INTO wallet VALUES (1, 100.50);
```

```sql
UPDATE wallet SET balance = balance * 1.015 WHERE id = 1;
```

Result:

Error: `column 'balance' (DECIMAL(2)): 102.00750 has more than 2 decimal places`

**Example: Round it the way your business rule says**

Setup:

```sql
CREATE TABLE wallet (id INT PRIMARY KEY, balance DECIMAL(2) NOT NULL);
INSERT INTO wallet VALUES (1, 100.50);
```

```sql
UPDATE wallet SET balance = round(balance * 1.015, 2) WHERE id = 1;
SELECT id, balance FROM wallet;
```

Result:

`UPDATE wallet SET balance = round(balance * 1.015, 2) WHERE id = 1`

```text
1 row(s) updated
```

`SELECT id, balance FROM wallet`

| id (INT) | balance (DECIMAL(2)) |
|---|---|
| 1 | 102.01 |

(1 row)

**Example: Paid-up capital with many digits: exact as written**

```sql
CREATE TABLE companies (symbol STRING PRIMARY KEY, paid_up_capital DECIMAL(2));
INSERT INTO companies VALUES ('CITY', 27057864000123.45);
SELECT symbol, paid_up_capital FROM companies;
```

Result:

`CREATE TABLE companies (`

```text
table 'companies' created
```

`INSERT INTO companies VALUES ('CITY', 27057864000123.45)`

```text
1 row(s) inserted
```

`SELECT symbol, paid_up_capital FROM companies`

| symbol (STRING) | paid_up_capital (DECIMAL(2)) |
|---|---|
| CITY | 27057864000123.45 |

(1 row)

**Example: Exact math: DECIMAL results, as in PostgreSQL**

```sql
CREATE TABLE orders (id INT PRIMARY KEY, price DECIMAL(2), qty DECIMAL(4));
INSERT INTO orders VALUES (1, 10.25, 3.5), (2, 0.10, 0.2);
SELECT id, price * qty AS amount, price * 1.13 AS with_vat, price / 3 AS third FROM orders ORDER BY id;
SELECT sum(price) AS total, avg(price) AS average FROM orders;
```

Result:

`CREATE TABLE orders (`

```text
table 'orders' created
```

`INSERT INTO orders VALUES (1, 10.25, 3.5), (2, 0.10, 0.2)`

```text
2 row(s) inserted
```

`SELECT id, price * qty AS amount, price * 1.13 AS with_vat, price / 3 AS third FROM orders ORDER BY `

| id (INT) | amount (DECIMAL(6)) | with_vat (DECIMAL(4)) | third (DECIMAL(16)) |
|---|---|---|---|
| 1 | 35.875000 | 11.5825 | 3.4166666666666667 |
| 2 | 0.020000 | 0.1130 | 0.03333333333333333333 |

(2 rows)

`SELECT sum(price) AS total, avg(price) AS average FROM orders`

| total (DECIMAL(2)) | average (DECIMAL(16)) |
|---|---|
| 10.35 | 5.1750000000000000 |

(1 row)

**Example: NUMERIC(30,2): money past 18 digits**

```sql
CREATE TABLE ledger (id INT PRIMARY KEY, amount NUMERIC(30,2));
INSERT INTO ledger VALUES (1, 1234567890123456789012.34), (2, 92233720368547758.07);
SELECT sum(amount) AS total, max(amount) - min(amount) AS spread FROM ledger;
SELECT id, amount * 1000 AS scaled FROM ledger ORDER BY id;
```

Result:

`CREATE TABLE ledger (`

```text
table 'ledger' created
```

`INSERT INTO ledger VALUES (1, 1234567890123456789012.34), (2, 92233720368547758.07)`

```text
2 row(s) inserted
```

`SELECT sum(amount) AS total, max(amount) - min(amount) AS spread FROM ledger`

| total (DECIMAL(38,2)) | spread (DECIMAL(38,2)) |
|---|---|
| 1234660123843825336770.41 | 1234475656403088241254.27 |

(1 row)

`SELECT id, amount * 1000 AS scaled FROM ledger ORDER BY id`

| id (INT) | scaled (DECIMAL(38,2)) |
|---|---|
| 1 | 1234567890123456789012340.00 |
| 2 | 92233720368547758070.00 |

(2 rows)

**Example: Past 38 digits is an error, never a rounded number** (shows an error)

```sql
SELECT 99999999999999999999999999999999999999 + 1;
```

Result:

Error: `line 1, column 47: numeric value out of range: the result needs more than 38 digits (the most a DECIMAL / NUMERIC holds)`

<a id="date"></a>

## DATE

Syntax:

```sql
column DATE
```

A calendar day without a time, like `2026-09-10`, in 4 bytes (days since 1970-01-01).

| Value written | Stored as |
|---|---|
| `'2026-09-10'` | that day |
| a time as text: `'2026-09-10T20:00:00+05:45'` | the **UTC** date of that time (here 2026-09-10, because 20:00 Nepal time is 14:15 UTC) |
| a `TIMESTAMP` | its UTC date |
| a number, `'10/09/2026'`, `'2026-9-10'` | error |

- **NULL:** kept as the smallest `INT`.
- **Notes:** `date + 1` is the next day. Shown as `2026-09-10`. A `DATE` can be the time column of a time-series table.

**Example: Company listing dates and report dates**

```sql
CREATE TABLE companies (symbol STRING PRIMARY KEY, listed_on DATE, last_report DATE);
INSERT INTO companies VALUES ('CITY', '1985-07-12', '2026-07-16'), ('VOLT', '2019-01-21', NULL);
SELECT symbol, listed_on, last_report, last_report + 90 AS next_report_due FROM companies;
```

Result:

`CREATE TABLE companies (`

```text
table 'companies' created
```

`INSERT INTO companies VALUES ('CITY', '1985-07-12', '2026-07-16'), ('VOLT', '2019-01-21', NULL)`

```text
2 row(s) inserted
```

`SELECT symbol, listed_on, last_report, last_report + 90 AS next_report_due FROM companies`

| symbol (STRING) | listed_on (DATE) | last_report (DATE) | next_report_due (DATE) |
|---|---|---|---|
| CITY | 1985-07-12 | 2026-07-16 | 2026-10-14 |
| VOLT | 2019-01-21 | NULL | NULL |

(2 rows)

**Example: A date in another format** (shows an error)

Setup:

```sql
CREATE TABLE companies (symbol STRING PRIMARY KEY, listed_on DATE);
```

```sql
INSERT INTO companies VALUES ('CITY', '12/07/1985');
```

Result:

Error: `column 'listed_on' (DATE): '12/07/1985' is not a date like '2026-09-11'`

<a id="timestamp"></a>

## TIMESTAMP

Syntax:

```sql
column TIMESTAMP [ROUND interval]
```

A moment in time, stored as milliseconds since 1970-01-01 **UTC**, in 8 bytes. KDB always shows it in UTC with a `Z`: `2026-09-10T05:15:00.000Z`.

| Value written | Read as |
|---|---|
| `'2026-09-10T11:00:00+05:45'` (or `+0545`) | 11:00 Nepal time = 05:15 UTC |
| `'2026-09-10T07:00:00-04:00'` | 07:00 New York summer time = 11:00 UTC |
| `'2026-09-10 11:00:00'` (no zone) | 11:00 **UTC** (not local time!) |
| `'2026-09-10T11:00:00Z'` | 11:00 UTC |
| `'2026-09-10'` | 00:00 UTC |
| `'2026-09-10T05:15:00.250Z'` | with milliseconds; more than 3 digits are cut |
| `1789017300000` | milliseconds since 1970-01-01 UTC |
| a `DATE` | 00:00 UTC of that day |
| `'10/09/2026'`, `'2026-9-10'`, `'2026-02-30'`, `1.5`, `TRUE` | error |

- **NULL:** kept as the smallest `LONG`. A time-series table needs a value in its time column.
- **Notes:** **always add the zone offset to a local time**, for example `+05:45` for Nepal or `-04:00` for New York in summer. Without it, the time is read as UTC and is wrong by the offset. `ROUND` cuts times down when they are written; see [ROUND](create-table.md#round). More in [time and time zones](time-and-time-zones.md).

**Example: The same market open (11:00 in Nepal) written in different ways**

```sql
CREATE TABLE time_test (time TIMESTAMP, note STRING);
INSERT INTO time_test VALUES
  ('2026-09-10T11:00:00+05:45', 'Nepal time with +05:45'),
  ('2026-09-10T11:00:00+0545',  'Nepal time without the colon'),
  ('2026-09-10 05:15:00',       'no zone = UTC'),
  ('2026-09-10T05:15:00Z',      'Z = UTC'),
  (1789017300000,               'milliseconds since 1970'),
  ('2026-09-10T11:00:00',       'Nepal time WITHOUT +05:45: wrong');
SELECT time, note FROM time_test;
```

Result:

`CREATE TABLE time_test (`

```text
table 'time_test' created
```

`INSERT INTO time_test VALUES ('2026-09-10T11:00:00+05:45', 'Nepal time with +05:45'), ('2026-09-10T1`

```text
6 row(s) inserted
```

`SELECT time, note FROM time_test`

| time (TIMESTAMP) | note (STRING) |
|---|---|
| 2026-09-10T05:15:00.000Z | Nepal time with +05:45 |
| 2026-09-10T05:15:00.000Z | Nepal time without the colon |
| 2026-09-10T05:15:00.000Z | no zone = UTC |
| 2026-09-10T05:15:00.000Z | Z = UTC |
| 2026-09-10T05:15:00.000Z | milliseconds since 1970 |
| 2026-09-10T11:00:00.000Z | Nepal time WITHOUT +05:45: wrong |

(6 rows)

**Example: A time in a local format** (shows an error)

Setup:

```sql
CREATE TABLE trades (time TIMESTAMP, symbol SYMBOL);
```

```sql
INSERT INTO trades VALUES ('10/09/2026 11:00', 'CITY');
```

Result:

Error: `column 'time' (TIMESTAMP): '10/09/2026 11:00' is not a time like '2026-09-11 11:00:00' (UTC) or '2026-09-11T11:00:00+05:45'`

<a id="symbol"></a>

## SYMBOL

Syntax:

```sql
column SYMBOL
```

Text that repeats a lot, like stock symbols, sectors or order types. Each different text is kept once in a list; every row keeps only a 4-byte number that points into the list. So a `SYMBOL` column of millions of rows is small and fast to compare.

- Accepts anything; numbers, `BOOL` values and times are written as text.
- **NULL:** `NULL` is allowed; it is kept as a special number that is not in the list.
- **Notes:** in queries a `SYMBOL` works like text. A `REFERENCES` from a `SYMBOL` column may point to a `STRING` key. Use `STRING` for text that is different in almost every row (names, messages): the list would get as big as the table. The default [SORT BY](create-table.md#sort-by) of a time-series table starts with its first `SYMBOL` column.

**Example: Symbols and sectors**

```sql
CREATE TABLE securities (symbol SYMBOL PRIMARY KEY, name STRING NOT NULL, sector SYMBOL);
INSERT INTO securities VALUES ('CITY', 'City Bank Limited', 'Banking'), ('COAST', 'Coastal Bank Limited', 'Banking');
SELECT sector, count(*) AS companies FROM securities GROUP BY sector;
```

Result:

`CREATE TABLE securities (`

```text
table 'securities' created
```

`INSERT INTO securities VALUES ('CITY', 'City Bank Limited', 'Banking'), ('COAST', 'Coastal Bank Limi`

```text
2 row(s) inserted
```

`SELECT sector, count(*) AS companies FROM securities GROUP BY sector`

| sector (SYMBOL) | companies (LONG) |
|---|---|
| Banking | 2 |

(1 row)

<a id="enum"></a>

## ENUM types (CREATE TYPE)

Syntax:

```sql
CREATE TYPE name AS ENUM ('label', 'label', ...)
ALTER TYPE name ADD VALUE [IF NOT EXISTS] 'label' [BEFORE | AFTER 'label']
DROP TYPE [IF EXISTS] name [, name ...]
column name
```

A fixed list of labels, as in PostgreSQL. You make the type once, then use its name as a column type. A column of the type takes **only** its labels. It is kept like a [`SYMBOL`](#symbol): 4 bytes a row.

| Rule | What happens |
|---|---|
| Value | must be one of the labels, exactly (case counts); anything else is refused with `invalid input value for enum ...` (Postgres code `22P02`) |
| Order | `ORDER BY`, `<`, `<=`, `>`, `>=` and `BETWEEN` follow the order the labels were listed in, not the alphabet. This works through a view, a subquery and a `WITH` query too. The other side is a label: `'paid'`, `'paid'::order_status` or `CAST('paid' AS order_status)`. Against another column or an expression, the text is compared |
| Cast | `'happy'::mood` and `CAST('happy' AS mood)` check the label too |
| New label | `ALTER TYPE ... ADD VALUE` puts it at the end, or `BEFORE` / `AFTER` a label |
| Change type | `ALTER TABLE ... ALTER COLUMN c TYPE other_type` checks every row: it is refused if a row holds a value that is not a label of the new type |
| Drop | `DROP TYPE` is refused while a column uses the type (code `2BP01`); drop or change the column first |

- **NULL:** `NULL` is allowed unless the column is `NOT NULL`.
- **Notes:** a label is 1 to 63 bytes. Labels cannot be renamed or removed: rows already hold them. `min()` and `max()` still compare the text. Arrays of an ENUM type are not supported (use `TEXT[]`). `pg_type` lists the type (`typtype` `'e'`) and `pg_enum` its labels; the Postgres port sends a column of the type as text, under the type's own oid ([types](postgres-protocol.md#types)).

**Example: Order status in the order the order moves**

```sql
CREATE TYPE order_status AS ENUM ('new', 'paid', 'shipped', 'delivered');
CREATE TABLE orders (id INT PRIMARY KEY, status order_status NOT NULL DEFAULT 'new');
INSERT INTO orders VALUES (1, 'shipped'), (2, 'new'), (3, 'delivered'), (4, 'paid');
SELECT id, status FROM orders ORDER BY status;
SELECT id FROM orders WHERE status >= 'shipped' ORDER BY id;
```

Result:

`CREATE TYPE order_status AS ENUM ('new', 'paid', 'shipped', 'delivered')`

```text
type 'order_status' created
```

`CREATE TABLE orders (`

```text
table 'orders' created
```

`INSERT INTO orders VALUES (1, 'shipped'), (2, 'new'), (3, 'delivered'), (4, 'paid')`

```text
4 row(s) inserted
```

`SELECT id, status FROM orders ORDER BY status`

| id (INT) | status (SYMBOL) |
|---|---|
| 2 | new |
| 4 | paid |
| 1 | shipped |
| 3 | delivered |

(4 rows)

`SELECT id FROM orders WHERE status >= 'shipped' ORDER BY id`

| id (INT) |
|---|
| 1 |
| 3 |

(2 rows)

**Example: Label order through a view, with a cast**

```sql
CREATE TYPE order_status AS ENUM ('new', 'paid', 'shipped', 'delivered');
CREATE TABLE orders (id INT PRIMARY KEY, status order_status);
INSERT INTO orders VALUES (1, 'shipped'), (2, 'new'), (3, 'delivered'), (4, 'paid');
CREATE VIEW open_orders AS SELECT * FROM orders;
SELECT id FROM open_orders WHERE status < 'shipped'::order_status ORDER BY id;
```

Result:

`CREATE TYPE order_status AS ENUM ('new', 'paid', 'shipped', 'delivered')`

```text
type 'order_status' created
```

`CREATE TABLE orders (`

```text
table 'orders' created
```

`INSERT INTO orders VALUES (1, 'shipped'), (2, 'new'), (3, 'delivered'), (4, 'paid')`

```text
4 row(s) inserted
```

`CREATE VIEW open_orders AS SELECT * FROM orders`

```text
view 'open_orders' created
```

`SELECT id FROM open_orders WHERE status < CAST('shipped' AS order_status) ORDER BY id`

| id (INT) |
|---|
| 2 |
| 4 |

(2 rows)

**Example: Only the labels are taken** (shows an error)

Setup:

```sql
CREATE TYPE order_status AS ENUM ('new', 'paid', 'shipped', 'delivered');
CREATE TABLE orders (id INT PRIMARY KEY, status order_status);
```

```sql
INSERT INTO orders VALUES (1, 'lost');
```

Result:

Error: `invalid input value for enum order_status: "lost"`

**Example: Add a label between two others**

```sql
CREATE TYPE order_status AS ENUM ('new', 'paid', 'shipped', 'delivered');
ALTER TYPE order_status ADD VALUE 'packed' AFTER 'paid';
SELECT enumlabel FROM pg_enum ORDER BY enumsortorder;
```

Result:

`CREATE TYPE order_status AS ENUM ('new', 'paid', 'shipped', 'delivered')`

```text
type 'order_status' created
```

`ALTER TYPE order_status ADD VALUE 'packed' AFTER 'paid'`

```text
type 'order_status' altered: label 'packed' added
```

`SELECT enumlabel FROM pg_enum ORDER BY enumsortorder`

| enumlabel (STRING) |
|---|
| new |
| paid |
| packed |
| shipped |
| delivered |

(5 rows)

**Example: A type in use cannot be dropped** (shows an error)

Setup:

```sql
CREATE TYPE order_status AS ENUM ('new', 'paid');
CREATE TABLE orders (id INT PRIMARY KEY, status order_status);
```

```sql
DROP TYPE order_status;
```

Result:

Error: `cannot drop type order_status because other objects depend on it: column 'status' of table 'orders' uses it; drop that column or change its type first`

<a id="string"></a>

## STRING, VARCHAR, TEXT

Syntax:

```sql
column STRING
column VARCHAR
column TEXT
```

Any text in UTF-8 (any language: English, Nepali, Chinese, emoji), up to 16 MB per value. `VARCHAR` and `TEXT` are the same type.

- Accepts anything; a number, `BOOL` or time is written as its text (`12` becomes `'12'`, a time becomes `'2026-09-10T00:00:00.000Z'`).
- **NULL:** `NULL` is allowed; it is kept as a special length. The empty text `''` is not `NULL`.
- **Notes:** KDB has no length limit on text. `VARCHAR(255)` is **read and the number ignored**, so a PostgreSQL script runs; nothing is cut at 255. Keep PDF files and images outside the database, and store their path or URL.

**Example: A news article in two languages**

```sql
CREATE TABLE news (id LONG PRIMARY KEY AUTO, lang STRING NOT NULL DEFAULT 'en', title VARCHAR NOT NULL, body TEXT NOT NULL);
INSERT INTO news (lang, title, body) VALUES
  ('en', 'City Bank profit rises 18%', 'City Bank reported a net profit of $3.27 billion.'),
  ('ne', 'सिटी बैंकको नाफा बढ्यो', 'सिटी बैंकले ३.२७ अर्ब नाफा कमायो।');
SELECT id, lang, title FROM news ORDER BY id;
```

Result:

`CREATE TABLE news (`

```text
table 'news' created
```

`INSERT INTO news (lang, title, body) VALUES ('en', 'City Bank profit rises 18%', 'City Bank reported`

```text
2 row(s) inserted
```

`SELECT id, lang, title FROM news ORDER BY id`

| id (LONG) | lang (STRING) | title (STRING) |
|---|---|---|
| 1 | en | City Bank profit rises 18% |
| 2 | ne | सिटी बैंकको नाफा बढ्यो |

(2 rows)

**Example: VARCHAR(255): the number is read and ignored**

Setup:

```sql
CREATE TABLE users (id INT PRIMARY KEY, email VARCHAR(255));
```

```sql
SHOW COLUMNS FROM users;
```

Result:

| name (STRING) | type (STRING) | primary_key (BOOL) | not_null (BOOL) | computed (BOOL) | references (STRING) |
|---|---|---|---|---|---|
| id | INT | true | false | false | NULL |
| email | STRING | false | false | false | NULL |

(2 rows)

<a id="json"></a>

## JSON, JSONB

Syntax:

```sql
column JSON
column JSONB
```

A JSON document (objects, arrays, text, numbers, `true`, `false`, `null`), up to 16 MB. `JSONB` is the same type. KDB checks that the text is valid JSON and removes the spaces between the parts.

| Value written | Stored as |
|---|---|
| JSON text: `'{ "a" : 1 }'` | `{"a":1}` (keys stay in their order; numbers keep their digits, `2.50` stays `2.50`) |
| a number or `TRUE`/`FALSE` | `5`, `true` |
| bad JSON: `'{"a": 1,}'`, `'hello'` | error with the character position |

- **NULL:** SQL `NULL` is allowed (kept as a special length). The JSON text `'null'` is a JSON value, not SQL `NULL`: `IS NULL` is false for it.
- **Notes:** read parts with `->`, `->>` and `json_value(...)`; change them with `json_set(...)`. See [chapter 18](../tutorial/18-content-data.md). Two JSON values are equal only when their text is equal, so `{"a":1,"b":2}` is not equal to `{"b":2,"a":1}`. The examples below show JSON with `CAST(... AS STRING)`, so you see the exact stored text.

**Example: Company profiles that differ per company**

```sql
CREATE TABLE companies (symbol STRING PRIMARY KEY, profile JSON DEFAULT '{}');
INSERT INTO companies VALUES
  ('CITY', '{ "head_office": "Kathmandu", "branches": 270 }'),
  ('VOLT', '{"capacity_mw": 456, "rivers": ["Volt River"]}');
INSERT INTO companies (symbol) VALUES ('COAST');
SELECT symbol, CAST(profile AS STRING) AS profile, profile ->> 'head_office' AS office FROM companies ORDER BY symbol;
```

Result:

`CREATE TABLE companies (`

```text
table 'companies' created
```

`INSERT INTO companies VALUES ('CITY', '{ "head_office": "Kathmandu", "branches": 270 }'), ('VOLT', '`

```text
2 row(s) inserted
```

`INSERT INTO companies (symbol) VALUES ('COAST')`

```text
1 row(s) inserted
```

`SELECT symbol, CAST(profile AS STRING) AS profile, profile ->> 'head_office' AS office FROM companie`

| symbol (STRING) | profile (STRING) | office (STRING) |
|---|---|---|
| CITY | {"head_office":"Kathmandu","branches":270} | Kathmandu |
| COAST | {} | NULL |
| VOLT | {"capacity_mw":456,"rivers":["Volt River"]} | NULL |

(3 rows)

**Example: JSON of different kinds, and JSON null**

```sql
CREATE TABLE settings (id INT PRIMARY KEY, value JSONB);
INSERT INTO settings VALUES (1, '[1, 2.50]'), (2, 5), (3, TRUE), (4, 'null'), (5, NULL);
SELECT id, CAST(value AS STRING) AS stored_text, value IS NULL AS is_sql_null FROM settings ORDER BY id;
```

Result:

`CREATE TABLE settings (`

```text
table 'settings' created
```

`INSERT INTO settings VALUES (1, '[1, 2.50]'), (2, 5), (3, TRUE), (4, 'null'), (5, NULL)`

```text
5 row(s) inserted
```

`SELECT id, CAST(value AS STRING) AS stored_text, value IS NULL AS is_sql_null FROM settings ORDER BY`

| id (INT) | stored_text (STRING) | is_sql_null (BOOL) |
|---|---|---|
| 1 | [1,2.50] | false |
| 2 | 5 | false |
| 3 | true | false |
| 4 | null | false |
| 5 | NULL | true |

(5 rows)

**Example: Bad JSON is refused** (shows an error)

Setup:

```sql
CREATE TABLE fundamentals (id INT PRIMARY KEY, extra JSON);
```

```sql
INSERT INTO fundamentals VALUES (1, '{"npl_pct": 4.3,}');
```

Result:

Error: `column 'extra' (JSON): not valid JSON: a JSON object cannot end with ',' at character 17 (near '}')`

<a id="bytes"></a>

## BYTES, BYTEA, BLOB

Syntax:

```sql
column BYTES
column BYTEA
column BLOB
X'0A0B'    '\x0a0b'
```

Any bytes, also zero bytes, up to 16 MB. `BYTEA` and `BLOB` are the same type. Good for password salts, SHA-256 hashes, keys, signatures and small images.

| Value written | Stored as |
|---|---|
| `X'0A0B'` (hex, right after the `X`) | the bytes 0A 0B |
| `'\x0a0b'` (text that starts with `\x`) | the bytes 0A 0B |
| other text: `'hi'` | its UTF-8 bytes (68 69) |
| a number | error |

- **NULL:** `NULL` is allowed (kept as a special length). `X''` is zero bytes, not `NULL`.
- **Notes:** KDB **shows** bytes as `\x` and hex (`\x0a0b`), in the shell, in CSV and in the HTTP API, like PostgreSQL. On `BYTES`, `length()` counts bytes. Functions: `hex()`, `unhex()`, `to_base64()`, `from_base64()`.

**Example: The SHA-256 hash of a report PDF**

```sql
CREATE TABLE reports (id LONG PRIMARY KEY AUTO, pdf_url STRING, pdf_sha256 BYTES);
INSERT INTO reports (pdf_url, pdf_sha256) VALUES
  ('https://files.example.com/city/2082-83-q4.pdf', X'9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A08'),
  ('https://files.example.com/volt/2082-83-q4.pdf', NULL);
SELECT id, pdf_sha256, length(pdf_sha256) AS bytes FROM reports ORDER BY id;
```

Result:

`CREATE TABLE reports (`

```text
table 'reports' created
```

`INSERT INTO reports (pdf_url, pdf_sha256) VALUES ('https://files.example.com/city/2082-83-q4.pdf', u`

```text
2 row(s) inserted
```

`SELECT id, pdf_sha256, length(pdf_sha256) AS bytes FROM reports ORDER BY id`

| id (LONG) | pdf_sha256 (BYTES) | bytes (LONG) |
|---|---|---|
| 1 | \\x9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08 | 32 |
| 2 | NULL | NULL |

(2 rows)

**Example: Three ways to write bytes**

```sql
CREATE TABLE keys (id INT PRIMARY KEY, k BYTEA, b BLOB);
INSERT INTO keys VALUES (1, X'00FF10', '\x00ff10'), (2, 'hi', X'');
SELECT id, k, b FROM keys ORDER BY id;
```

Result:

`CREATE TABLE keys (`

```text
table 'keys' created
```

`INSERT INTO keys VALUES (1, unhex('00FF10'), '\x00ff10'), (2, 'hi', unhex(''))`

```text
2 row(s) inserted
```

`SELECT id, k, b FROM keys ORDER BY id`

| id (INT) | k (BYTES) | b (BYTES) |
|---|---|---|
| 1 | \\x00ff10 | \\x00ff10 |
| 2 | \\x6869 | \\x |

(2 rows)

**Example: Hex with a bad digit** (shows an error)

Setup:

```sql
CREATE TABLE keys (id INT PRIMARY KEY, k BYTES);
```

```sql
INSERT INTO keys VALUES (1, '\xZZ');
```

Result:

Error: `column 'k' (BYTES): '\xZZ' is not hex bytes; write them like '\x0a0b' or X'0A0B'`

<a id="uuid"></a>

## UUID

Syntax:

```sql
column UUID
'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid
```

A UUID, kept in **16 bytes** (as text it would take 36 characters and more). It reads back as text: 36 lower-case characters with dashes, as in PostgreSQL.

| Value written | Stored as |
|---|---|
| `'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'` | itself |
| upper case, `{...}` braces, or the 32 digits without dashes | the same UUID: `a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11` |
| `gen_random_uuid()` | a new random UUID (version 4) |
| text that is no UUID: `'abc'` | error `invalid input syntax for type uuid` (SQLSTATE 22P02) |

- **NULL:** `NULL` is allowed (kept in a flag, not in the 16 bytes).
- **Compare and find:** `id = 'A0EEBC99-...'` finds the row in any spelling. `ORDER BY` sorts like the text. A `PRIMARY KEY`, `DEDUP KEY` or index on a UUID column works like on text.
- **Convert:** `CAST(id AS TEXT)` or `id::text` gives the text; `'...'::uuid` reads any spelling and gives the lower-case text.
- **Older data:** a `UUID` column made before 2026-10-02 stays a text column with the UUID rule; it reads and compares the same. `ALTER TABLE t ALTER COLUMN c TYPE UUID` moves it to 16 bytes. A KDB build before 2026-10-02 cannot open a table with a 16-byte `UUID` column ([versions](versions.md)).
- **From text:** `ALTER TABLE t ALTER COLUMN c TYPE UUID` also turns a `TEXT` column of UUIDs into a `UUID` column. Every value is checked first: if one is no UUID, the error names it and the column stays as it was.
- **Postgres port:** a UUID column, `x::uuid` and an older UUID text column go out as type `uuid` (OID 2950), in text or binary (16 bytes). Drivers like pgx, JDBC and psycopg read them as their own UUID type and can send a `uuid` parameter or `COPY ... (FORMAT binary)` the same way.
- **Loading:** `/imp` (CSV) and `POST /write` (line protocol: a tag or a string field) read any spelling into a UUID column. A value that is no UUID counts as a bad value, like any other. A new table made by `/imp` or `/write` keeps such a column as `STRING`; make the table first to get `UUID`.

**Example: Turn a text column of UUIDs into a UUID column**

```sql
CREATE TABLE devices (id TEXT, name STRING);
INSERT INTO devices VALUES ('A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11', 'Gate'), ('{c0eebc999c0b4ef8bb6d6bb9bd380a13}', 'Pump');
ALTER TABLE devices ALTER COLUMN id TYPE UUID;
SELECT id, name FROM devices ORDER BY id;
```

Result:

`CREATE TABLE devices (`

```text
table 'devices' created
```

`INSERT INTO devices VALUES ('A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11', 'Gate'), ('{c0eebc999c0b4ef8bb6d`

```text
2 row(s) inserted
```

`ALTER TABLE devices ALTER COLUMN id TYPE UUID`

```text
table 'devices' altered (2 row change(s) written)
```

`SELECT id, name FROM devices ORDER BY id`

| id (UUID) | name (STRING) |
|---|---|
| a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11 | Gate |
| c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13 | Pump |

(2 rows)

**Example: A value that is no UUID stops the change** (shows an error)

Setup:

```sql
CREATE TABLE devices (id TEXT, name STRING);
INSERT INTO devices VALUES ('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Gate'), ('pump-1', 'Pump');
```

```sql
ALTER TABLE devices ALTER COLUMN id TYPE UUID;
```

Result:

Error: `cannot change column 'id' of table 'devices': a row already there does not fit (column 'id' (UUID): invalid input syntax for type uuid: 'pump-1')`

**Example: Users keyed by a UUID**

```sql
CREATE TABLE app_users (id UUID PRIMARY KEY, name STRING);
INSERT INTO app_users VALUES
  ('A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11', 'Asha'),
  ('{b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12}', 'Bikash');
SELECT id, name FROM app_users ORDER BY id;
SELECT name FROM app_users WHERE id = 'a0eebc999c0b4ef8bb6d6bb9bd380a11';
```

Result:

`CREATE TABLE app_users (`

```text
table 'app_users' created
```

`INSERT INTO app_users VALUES ('A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11', 'Asha'), ('{b0eebc99-9c0b-4ef8`

```text
2 row(s) inserted
```

`SELECT id, name FROM app_users ORDER BY id`

| id (UUID) | name (STRING) |
|---|---|
| a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11 | Asha |
| b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12 | Bikash |

(2 rows)

`SELECT name FROM app_users WHERE id = 'a0eebc999c0b4ef8bb6d6bb9bd380a11'`

| name (STRING) |
|---|
| Asha |

(1 row)

**Example: Text that is no UUID is refused** (shows an error)

Setup:

```sql
CREATE TABLE app_users (id UUID PRIMARY KEY, name STRING);
```

```sql
INSERT INTO app_users VALUES ('not-a-uuid', 'Chandra');
```

Result:

Error: `column 'id' (UUID): invalid input syntax for type uuid: 'not-a-uuid'`
