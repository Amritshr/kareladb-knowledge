# SQL basics

> How KDB reads SQL text: statements, names, text, numbers, TRUE/FALSE/NULL, comments, errors and reserved words.

- Category: Getting started
- Keywords: syntax, statement, semicolon, ;, case, upper case, lower case, identifier, name, quoted name, double quotes, string, text, single quote, escape quote, number, integer, float, scientific notation, boolean, constant, comment, --, /*, error message, line and column, syntax error, reserved word, keyword, three-valued logic, IS NULL, IS NOT NULL, unknown, alias
- See also: [Quick start](quick-start.md), [Operators](operators.md), [Conditional and NULL functions](functions-conditional.md), [Column types](column-types.md), [SELECT](select.md), [WHERE](where.md)

**SQL** is the language you use to talk to KDB. A **statement** is one command, like `SELECT` or `INSERT`. This page shows the small rules that every statement follows.

**Example: Names, text, numbers, NULL and a comment in one query**

```sql
-- the price of one CITY share, and a note
SELECT 'CITY' AS symbol,
       512.45 AS "Last Price",   /* a name with a space needs double quotes */
       100 AS quantity,
       512.45 * 100 AS amount,
       'City''s bank' AS note,
       NULL AS broker;
```

Result:

| symbol (STRING) | Last Price (DOUBLE) | quantity (LONG) | amount (DOUBLE) | note (STRING) | broker (STRING) |
|---|---|---|---|---|---|
| CITY | 512.45 | 100 | 51245 | City's bank | NULL |

(1 row)

<a id="statements"></a>

## Statements and ;

Syntax:

```sql
statement ; statement ; ...
```

A text can hold many statements. Put `;` between them. The `;` after the last statement is optional. Extra `;` are ignored.

- When you send a text (with `kdb sql`, a file, or HTTP `/exec`), KDB first checks the **grammar** of the whole text. If one statement has a syntax error, **no** statement runs. (`kdb shell` runs what you typed each time a line ends with `;`.)
- Then the statements run one by one. Each one is saved on its own.
- At the first error while running, KDB **stops**. The statements before it stay saved. The statements after it do not run.
- One statement is all or nothing: an `INSERT` of 5000 rows with one bad row saves no row.
- **Notes:** to make many statements succeed or fail together, use [BEGIN ... COMMIT](transactions.md).

**Example: Three statements, one result each**

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
INSERT INTO brokers VALUES (58, 'Northgate Securities');;
SELECT id, name FROM brokers
```

Result:

`CREATE TABLE brokers (`

```text
table 'brokers' created
```

`INSERT INTO brokers VALUES (58, 'Northgate Securities')`

```text
1 row(s) inserted
```

`SELECT id, name FROM brokers`

| id (INT) | name (STRING) |
|---|---|
| 58 | Northgate Securities |

(1 row)

**Example: A script stops at the first error; row 21 stays saved** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
```

```sql
INSERT INTO brokers VALUES (21, 'Test Broker A');
INSERT INTO brokers VALUES (21, 'Test Broker B');
INSERT INTO brokers VALUES (22, 'Test Broker C');
```

Result:

```text
1 row(s) inserted
```

Error: `a row with id='21' already exists in 'brokers'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it`

**Example: A syntax error in the second statement: the first does not run either** (shows an error)

```sql
CREATE TABLE notes (id INT, body STRING);
SELEC * FROM notes;
```

Result:

Error: `line 2, column 1: expected a statement (CREATE, DROP, RENAME, ALTER, SHOW, INSERT, UPDATE, DELETE, BACKUP, CHECK, SELECT, EXPLAIN, CALL, BEGIN, COMMIT, ROLLBACK, SAVEPOINT, DECLARE, FETCH or CLOSE) but found 'SELEC'`

<a id="case"></a>

## Upper and lower case

Syntax:

```sql
SELECT = select = Select
ochl_day = OCHL_DAY = Ochl_Day
'CITY' <> 'city'
```

Keywords, table names, column names and function names do not care about case. **Text values do**: `'CITY'` is not `'city'`.

- A table or column keeps the spelling you used in `CREATE TABLE`. `SHOW TABLES` shows that spelling.
- A column name in the result keeps the spelling of the alias you wrote.
- **Notes:** in PostgreSQL, a name in double quotes is case sensitive. In KDB it is not: `"Total"` and `"total"` are the same name.

**Example: Any case works for names; text compares exactly**

```sql
CREATE TABLE Brokers (Id INT PRIMARY KEY, Name STRING);
INSERT INTO BROKERS (ID, NAME) VALUES (58, 'Northgate Securities');
select id, name, name = 'northgate securities' AS same_text, upper(name) = 'NORTHGATE SECURITIES' AS same_upper from brokers;
```

Result:

`CREATE TABLE Brokers (`

```text
table 'Brokers' created
```

`INSERT INTO BROKERS (ID, NAME) VALUES (58, 'Northgate Securities')`

```text
1 row(s) inserted
```

`SELECT id, name, name = 'northgate securities' AS same_text, upper(name) = 'NORTHGATE SECURITIES' AS`

| Id (INT) | Name (STRING) | same_text (BOOL) | same_upper (BOOL) |
|---|---|---|---|
| 58 | Northgate Securities | false | true |

(1 row)

<a id="names"></a>

## Names and "quoted names"

Syntax:

```sql
name
"any name"
"a name with a "" inside"
```

A **name** (also called identifier) names a table, column, alias, view or index. A plain name has letters, digits and `_`, and does not start with a digit. Letters of any language (Nepali, Chinese, ...) also work.

Write a name in **double quotes** when it:

- is a [reserved word](#reserved-words), like `"order"` or `"select"`;
- has a space or another special character, like `"Total Amount"`;
- starts with a digit, like `"1st_level"`.

| Part | Rule |
|---|---|
| Plain name | letters (any language), digits, `_`; not starting with a digit |
| Quoted name | any characters; a `"` inside is written twice: `""` |
| Empty name `""` | not allowed |

- **Notes:** `time`, `date`, `timestamp`, `symbol`, `partition`, `open`, `close`, `volume`, `value` and `key` are **not** reserved. Use them freely as column names.

**Example: A forum table with a column called order**

```sql
CREATE TABLE posts (id LONG PRIMARY KEY, "order" INT, "Posted By" STRING, body STRING);
INSERT INTO posts VALUES (1, 1, 'ram', 'First post');
SELECT id, "order", "Posted By" FROM posts ORDER BY "order";
```

Result:

`CREATE TABLE posts (`

```text
table 'posts' created
```

`INSERT INTO posts VALUES (1, 1, 'ram', 'First post')`

```text
1 row(s) inserted
```

`SELECT id, "order", "Posted By" FROM posts ORDER BY "order"`

| id (LONG) | order (INT) | Posted By (STRING) |
|---|---|---|
| 1 | 1 | ram |

(1 row)

**Example: Names in any language work without quotes (here Nepali)**

```sql
CREATE TABLE कम्पनी (चिन्ह STRING PRIMARY KEY, नाम STRING);
INSERT INTO कम्पनी VALUES ('CITY', 'नमस्ते');
SELECT चिन्ह, नाम FROM कम्पनी;
```

Result:

`CREATE TABLE कम्पनी (`

```text
table 'कम्पनी' created
```

`INSERT INTO कम्पनी VALUES ('CITY', 'नमस्ते')`

```text
1 row(s) inserted
```

`SELECT चिन्ह, नाम FROM कम्पनी`

| चिन्ह (STRING) | नाम (STRING) |
|---|---|
| CITY | नमस्ते |

(1 row)

**Example: A reserved word without quotes** (shows an error)

```sql
CREATE TABLE orders (id INT, order STRING);
```

Result:

Error: `line 1, column 30: expected a column name but found the reserved word 'order' (write it in double quotes, "order", to use it as a name)`

<a id="text"></a>

## Text: 'single quotes'

Syntax:

```sql
'text'
'City''s bank'
''
```

Text (also called a string) goes in **single quotes**. A `'` inside the text is written twice: `''`. Text may have many lines and any language (UTF-8).

- There are no backslash escapes: `'a\nb'` is the four characters `a`, `\`, `n`, `b`.
- `''` is an empty text. It is **not** NULL.
- Double quotes `"..."` are for names, never for text. `WHERE symbol = "CITY"` looks for a **column** called CITY.
- **Notes:** bytes are written `X'0A0B'`; see [BYTES](column-types.md#bytes). Times are text too: `'2026-09-10T11:00:00+05:45'`; see [TIMESTAMP](column-types.md#timestamp).

**Example: Quotes inside text, empty text, text in another language**

```sql
SELECT 'City''s bank' AS name,
       '' AS empty, '' IS NULL AS empty_is_null,
       'नेपाल' AS nepali,
       'a\nb' AS no_escapes;
```

Result:

| name (STRING) | empty (STRING) | empty_is_null (BOOL) | nepali (STRING) | no_escapes (STRING) |
|---|---|---|---|---|
| City's bank |  | false | नेपाल | a\\nb |

(1 row)

**Example: Double quotes mean a column name, not text** (shows an error)

```sql
CREATE TABLE securities (symbol SYMBOL PRIMARY KEY, name STRING);
SELECT name FROM securities WHERE symbol = "CITY";
```

Result:

```text
table 'securities' created
```

Error: `line 2, column 44: unknown column 'CITY' (table 'securities' has: symbol name)`

**Example: Text without its closing quote** (shows an error)

```sql
SELECT 'Northgate;
```

Result:

Error: `line 1, column 8: expected a closing ' to end the string that starts here but found the end of the input`

<a id="numbers"></a>

## Numbers

Syntax:

```sql
42    -7    512.45    .5    1.5e3    2E-4
```

A number without a point or `e` is a whole number (type `LONG`). A number with a point or `e` is a `DOUBLE`.

| Written | Type | Range |
|---|---|---|
| `42`, `-7` | `LONG` | -9223372036854775808 to 9223372036854775807 |
| `512.45`, `.5`, `1.5e3` | `DOUBLE` | about ±1.8e308, 15 digits |

- There is no `,` or `_` inside a number: write `1000000`, not `1,000,000`.
- A number put into a column is converted to the column type; see [column types](column-types.md).
- `/` always gives a `DOUBLE`: `10 / 4` is `2.5`. See [arithmetic](functions-math.md#operators).
- **Notes:** for exact money, the column type matters, not the literal: use `DECIMAL(2)` columns. For amounts with more than about 15 digits, write the value as text: `'123456789012345.67'`.

**Example: Kinds of numbers**

```sql
SELECT 42 AS whole, -7 AS negative, 512.45 AS price, .5 AS half, 1.5e3 AS thousand_five, 2E-4 AS small, 10 / 4 AS division;
```

Result:

| whole (LONG) | negative (LONG) | price (DOUBLE) | half (DOUBLE) | thousand_five (DOUBLE) | small (DOUBLE) | division (DOUBLE) |
|---|---|---|---|---|---|---|
| 42 | -7 | 512.45 | 0.5 | 1500 | 0.0002 | 2.5 |

(1 row)

**Example: A whole number that is too big** (shows an error)

```sql
SELECT 9223372036854775808;
```

Result:

Error: `line 1, column 8: expected an integer between -9223372036854775808 and 9223372036854775807 but found '9223372036854775808'`

<a id="constants"></a>

## TRUE, FALSE and NULL

Syntax:

```sql
TRUE    FALSE    NULL
```

`TRUE` and `FALSE` are the two `BOOL` values. `NULL` means "no value" or "unknown". Every column type can hold `NULL`, unless the column is `NOT NULL`.

- `NULL` is not `0`, not `''` and not `FALSE`.
- Use `IS NULL` and `IS NOT NULL` to test for `NULL`. See [NULL logic](#null-logic).
- **Notes:** a `BOOL` is not a number: `TRUE = 1` is an error. A `BOOL` column accepts `1`/`0` and `'true'`/`'false'` when a row is written.

**Example: The three constants**

```sql
SELECT TRUE AS yes, FALSE AS no, NULL AS nothing, NULL IS NULL AS is_null, NOT FALSE AS not_false;
```

Result:

| yes (BOOL) | no (BOOL) | nothing (STRING) | is_null (BOOL) | not_false (BOOL) |
|---|---|---|---|---|
| true | false | NULL | true | true |

(1 row)

**Example: A user who has not verified the email yet**

```sql
CREATE TABLE users (id LONG PRIMARY KEY AUTO, email STRING NOT NULL, verified BOOL NOT NULL DEFAULT FALSE, phone STRING);
INSERT INTO users (email) VALUES ('ram@example.com');
INSERT INTO users (email, verified, phone) VALUES ('sita@example.com', TRUE, '9800000000');
SELECT id, email, verified, phone, phone IS NULL AS no_phone FROM users;
```

Result:

`CREATE TABLE users (`

```text
table 'users' created
```

`INSERT INTO users (email) VALUES ('ram@example.com')`

```text
1 row(s) inserted
```

`INSERT INTO users (email, verified, phone) VALUES ('sita@example.com', TRUE, '9800000000')`

```text
1 row(s) inserted
```

`SELECT id, email, verified, phone, phone IS NULL AS no_phone FROM users`

| id (LONG) | email (STRING) | verified (BOOL) | phone (STRING) | no_phone (BOOL) |
|---|---|---|---|---|
| 1 | ram@example.com | false | NULL | true |
| 2 | sita@example.com | true | 9800000000 | false |

(2 rows)

<a id="comments"></a>

## Comments

Syntax:

```sql
-- to the end of the line
/* between these marks, also over many lines */
```

KDB skips comments. Use them to explain a script.

- `/* ... */` comments do not nest: the first `*/` ends the comment.
- A `/*` without `*/` is an error that shows where the comment starts.

**Example: Both kinds of comments in a report query**

Setup:

```sql
CREATE TABLE ledger (id LONG PRIMARY KEY AUTO, account INT, amount DECIMAL(2));
INSERT INTO ledger (account, amount) VALUES (1, 1000.00), (1, -250.50), (2, 250.50);
```

```sql
/* Balance per account.
   Used by the daily report. */
SELECT account,            -- the account number
       sum(amount) AS balance
FROM ledger
GROUP BY account
ORDER BY account;
```

Result:

| account (INT) | balance (DECIMAL(2)) |
|---|---|
| 1 | 749.50 |
| 2 | 250.50 |

(2 rows)

**Example: A comment that is not closed** (shows an error)

```sql
SELECT 1 /* forgot to close
```

Result:

Error: `line 1, column 10: expected '*/' to close the comment that starts here but found the end of the input`

<a id="errors"></a>

## Error messages

Syntax:

```sql
error: line L, column C: expected ... but found ...
error: <what is wrong>
```

When KDB cannot run a statement, it prints `error:` and a message. Messages about the SQL text say **where**: `line 3, column 8` is the place in the text you sent (in a file: the line of the file). They also say what KDB expected there.

| Message starts with | Meaning |
|---|---|
| `expected ... but found ...` | the grammar is wrong at that place |
| `unknown column 'x' (table 't' has: ...)` | a typing mistake; the message lists the real columns |
| `table or view 'x' does not exist` | wrong table name, or the wrong database |
| `a row with ... already exists` | a duplicate key; see [INSERT](insert.md#duplicates) |
| `column 'x' (TYPE): ...` | a value does not fit the column; see [column types](column-types.md) |

- **Returns:** exit code `1` from `kdb sql`; HTTP status 400 from the HTTP API.
- **Notes:** a missing comma is not an error: `SELECT symbol close` means "column `symbol`, named `close`". [Chapter 12](../tutorial/12-troubleshooting.md) lists many messages and their fixes.

**Example: The message points to line 3, column 8** (shows an error)

Setup:

```sql
CREATE TABLE ochl_day (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time);
```

```sql
SELECT time,
       symbol,
       clsoe
FROM ochl_day;
```

Result:

Error: `line 3, column 8: unknown column 'clsoe' (table 'ochl_day' has: time symbol close)`

**Example: What the grammar wanted** (shows an error)

Setup:

```sql
CREATE TABLE ochl_day (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time);
```

```sql
SELECT symbol close FROM ochl_day WHERE;
```

Result:

Error: `line 1, column 40: expected an expression (a value, column name, function call or '(') but found ';'`

<a id="reserved-words"></a>

## Reserved words

Syntax:

```sql
ALTER AND AS BETWEEN CASE CREATE DEFAULT DELETE DISTINCT DROP ELSE END
FALSE FROM GROUP IN INSERT INTO IS JOIN LIKE LIMIT NOT NULL ON OR ORDER
PRIMARY REFERENCES SELECT SET TABLE THEN TO TRUE UNIQUE UPDATE VALUES WHEN WHERE
```

These 40 words have a fixed meaning. They cannot be a table, column or alias name, unless you write them in double quotes: `"order"`, `"from"`.

- All other words are normal names, also words like `CHECK`, `INDEX`, `BEGIN`, `KEY`, `USER`, `DATE`, `TIME`, `OPEN` and `CLOSE`: KDB knows them from their place in the statement.
- **Notes:** PostgreSQL reserves more words. A name that works in KDB may need quotes in PostgreSQL.

**Example: Columns called time, date, open, close, key and value need no quotes**

```sql
CREATE TABLE prices (time TIMESTAMP, date DATE, open DOUBLE, close DOUBLE, key STRING, value DOUBLE) TIMESERIES(time);
INSERT INTO prices VALUES ('2026-09-10', '2026-09-10', 504.6, 504.9, 'CITY', 1);
SELECT time, date, open, close, key, value FROM prices;
```

Result:

`CREATE TABLE prices (`

```text
table 'prices' created
```

`INSERT INTO prices VALUES ('2026-09-10', '2026-09-10', 504.6, 504.9, 'CITY', 1)`

```text
1 row(s) inserted
```

`SELECT time, date, open, close, key, value FROM prices`

| time (TIMESTAMP) | date (DATE) | open (DOUBLE) | close (DOUBLE) | key (STRING) | value (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-10T00:00:00.000Z | 2026-09-10 | 504.6 | 504.9 | CITY | 1 |

(1 row)

**Example: A reserved word as a column name** (shows an error)

```sql
CREATE TABLE transfers (id INT, from INT, to_account INT);
```

Result:

Error: `line 1, column 33: expected a column name but found the reserved word 'from' (write it in double quotes, "from", to use it as a name)`

<a id="clause-words"></a>

## Clause words

Syntax:

```sql
ASOF CROSS FULL HAVING INNER LATEST LEFT LT OVER REFRESH RIGHT SAMPLE SPLICE UNION USING
```

These 15 words start a part of a query (a **clause**), like `LEFT JOIN` or `SAMPLE BY`. They **can** be table and column names. But they cannot be a short alias without `AS`: write `SELECT 1 AS left`, not `SELECT 1 left`.

| Word | Used in |
|---|---|
| `INNER`, `LEFT`, `RIGHT`, `FULL`, `CROSS`, `USING` | [joins](joins.md) |
| `ASOF`, `LT`, `SPLICE` | [time joins](joins.md#asof-join) |
| `HAVING` | [GROUP BY](group-by.md) |
| `LATEST` | [LATEST ON](latest-on.md) |
| `SAMPLE` | [SAMPLE BY](sample-by.md) |
| `UNION` | [UNION ALL](union-subqueries.md) |
| `OVER` | [window functions](functions-window.md) |
| `REFRESH` | `CREATE CACHED VIEW ... REFRESH ON COMMIT` ([views](views.md)) |

**Example: Clause words as column names, and as aliases with AS**

```sql
CREATE TABLE t (left INT, right INT, sample INT, latest INT);
INSERT INTO t VALUES (1, 2, 3, 4);
SELECT left, right, sample AS union, latest AS over FROM t;
```

Result:

`CREATE TABLE t (`

```text
table 't' created
```

`INSERT INTO t VALUES (1, 2, 3, 4)`

```text
1 row(s) inserted
```

`SELECT left, right, sample AS union, latest AS over FROM t`

| left (INT) | right (INT) | union (INT) | over (INT) |
|---|---|---|---|
| 1 | 2 | 3 | 4 |

(1 row)

**Example: RIGHT JOIN: every broker, also the ones without trades**

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING);
CREATE TABLE trades (id LONG PRIMARY KEY, buyer INT);
INSERT INTO brokers VALUES (1, 'Alpha'), (2, 'Beta');
INSERT INTO trades VALUES (10, 1);
```

```sql
SELECT brokers.name, trades.id FROM trades RIGHT JOIN brokers ON trades.buyer = brokers.id ORDER BY brokers.name;
```

Result:

| name (STRING) | id (LONG) |
|---|---|
| Alpha | 10 |
| Beta | NULL |

(2 rows)

**Example: A clause word as a short alias** (shows an error)

```sql
SELECT 1 left;
```

Result:

Error: `line 1, column 10: expected an operator, AS, ',', FROM, WHERE, GROUP BY, UNION ALL, ORDER BY, LIMIT, ';' or the end of the input but found 'left'`

<a id="null-logic"></a>

## NULL logic

Syntax:

```sql
value IS NULL
value IS NOT NULL
NULL = anything   ->  NULL (unknown)
```

`NULL` means "unknown". So most things done with `NULL` give `NULL` again:

| Expression | Result | Why |
|---|---|---|
| `NULL + 1` | `NULL` | unknown plus 1 is unknown |
| `NULL = NULL` | `NULL` | two unknown values may differ |
| `TRUE AND NULL` | `NULL` | depends on the unknown value |
| `FALSE AND NULL` | `FALSE` | false whatever the unknown value is |
| `TRUE OR NULL` | `TRUE` | true whatever the unknown value is |
| `NOT NULL` | `NULL` | |
| `3 IN (1, NULL)` | `NULL` | 3 might be the unknown value |
| `NULL IS NULL` | `TRUE` | the right way to test |

- `WHERE` and `HAVING` keep a row only when the condition is `TRUE`. A `NULL` condition drops the row, like `FALSE`.
- So `WHERE phone = NULL` finds nothing. Write `WHERE phone IS NULL`.
- `WHERE v <> 5` also drops the rows where `v` is `NULL`.
- Aggregates skip `NULL`: `count(v)` counts only values, `sum(v)` adds only values. `count(*)` counts all rows.
- `ORDER BY v` puts `NULL` last (with `DESC`: first).
- **Notes:** `coalesce(v, 0)` gives `0` for `NULL`; see [conditional functions](functions-conditional.md).

**Example: NULL in expressions**

```sql
SELECT NULL + 1 AS plus, NULL = NULL AS equal, TRUE AND NULL AS and_true, FALSE AND NULL AS and_false,
       TRUE OR NULL AS or_true, 3 IN (1, NULL) AS in_list, NULL IS NULL AS is_null;
```

Result:

| plus (STRING) | equal (STRING) | and_true (STRING) | and_false (BOOL) | or_true (BOOL) | in_list (STRING) | is_null (BOOL) |
|---|---|---|---|---|---|---|
| NULL | NULL | NULL | false | true | NULL | true |

(1 row)

**Example: Users without a phone: = NULL finds nothing, IS NULL works**

Setup:

```sql
CREATE TABLE users (id INT PRIMARY KEY, email STRING, phone STRING);
INSERT INTO users VALUES (1, 'ram@example.com', NULL), (2, 'sita@example.com', '9800000000'), (3, 'hari@example.com', NULL);
```

```sql
SELECT id FROM users WHERE phone = NULL;
SELECT id FROM users WHERE phone IS NULL;
SELECT id FROM users WHERE phone <> '9800000000';
SELECT count(*) AS users, count(phone) AS with_phone FROM users;
```

Result:

`SELECT id FROM users WHERE phone = NULL`

| id (INT) |
|---|

(0 rows)

`SELECT id FROM users WHERE phone IS NULL`

| id (INT) |
|---|
| 1 |
| 3 |

(2 rows)

`SELECT id FROM users WHERE phone != '9800000000'`

| id (INT) |
|---|

(0 rows)

`SELECT count(*) AS users, count(phone) AS with_phone FROM users`

| users (LONG) | with_phone (LONG) |
|---|---|
| 3 | 1 |

(1 row)
