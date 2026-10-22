# Text functions

> Change case, cut, trim, pad, search and join text. A letter of any language (Nepali, Chinese, ...) counts as one character.

- Category: Functions — text
- Keywords: text, string, STRING, ascii, chr, translate, overlay, PLACING, normalize, NFC, NFD, NFKC, NFKD, U&, to\_ascii, remove accents, bit\_length, to\_hex, parse\_ident, string\_to\_table, number format, format a number, VARCHAR, UTF-8, Unicode, Nepali, Devanagari, characters, letters, bytes, upper case, lower case, cut text, clean text, ||, join text, concatenate, lcase, ucase, len, mid, instr, locate, position IN, lengthb, format, sprintf, printf, string format, quote a name, quote a value, quote\_ident, quote\_literal, quote\_nullable, SQL injection
- See also: [Regular expressions](functions-regex.md), [WHERE](where.md), [Conversion functions](functions-conversion.md), [Bytes, hex and base64](functions-bytes.md), [Full-text search](full-text-search.md)

These functions work on text (`STRING`). KarelaDB keeps text as **UTF-8**. UTF-8 is the usual way to store the letters of every language. An English letter takes 1 byte; a Nepali letter like `न` takes 3 bytes.

- Text functions count **characters**, not bytes. `length('नेपाल')` is `5`. Only `octet_length` counts bytes.
- A `NULL` argument gives `NULL`. Only `concat`, `concat_ws`, `format` and `quote_nullable` take NULLs.
- A number, date or `true`/`false` is first turned into text: `length(12.50)` is `4`, because the text is `12.5`.
- `upper`, `lower` and `initcap` change the letters of every script that has capitals: English, `Ä`, `ě`, Vietnamese, Greek, Cyrillic, Armenian and more. Nepali (Devanagari) has no capitals, so it stays as it is.
- Searching (`replace`, `strpos`, `starts_with`, ...) cares about upper and lower case. To ignore case, use `lower()` on both sides, [ILIKE](where.md) or a [regular expression](functions-regex.md) with the flag `'i'`.
- To find text with a pattern, use [LIKE and ILIKE](where.md) or the [regular expression functions](functions-regex.md).

**Example: Clean labels for the company list** (sample data: sample)

```sql
SELECT symbol,
       lower(symbol) AS url_part,
       split_part(name, ' ', 1) AS first_word,
       length(name) AS letters,
       symbol || ' - ' || left(name, 20) AS label
FROM securities
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | url_part (STRING) | first_word (STRING) | letters (LONG) | label (STRING) |
|---|---|---|---|---|
| ACME | acme | Acme | 23 | ACME - Acme Investment Comp |
| CITY | city | City | 17 | CITY - City Bank Limited |
| COAST | coast | Coastal | 20 | COAST - Coastal Bank Limited |
| TELCO | telco | Northwind | 25 | TELCO - Northwind Telecom Li |
| VOLT | volt | Volt | 29 | VOLT - Volt River Hydropowe |

(5 rows)

## lower

Syntax:

```sql
lower(text)
```

The text with every capital letter made small: `lower('CITY')` is `city`, `lower('ÄÖ')` is `äö`, `lower('ΣΑΣ')` is `σασ`. Letters without capitals (Nepali) stay as they are.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING (a number is turned into text) | the text to change |

- **Returns:** `STRING`.
- **NULL:** `lower(NULL)` is `NULL`.
- **Notes:** each letter becomes one letter, as in PostgreSQL: `lower('İ')` is `i`.

**Example**

```sql
SELECT lower('CITY Bank') AS a, lower('नेपाल') AS nepali, lower('ÄBC') AS german, lower('ПРИВЕТ') AS russian, lower(NULL) AS b;
```

Result:

| a (STRING) | nepali (STRING) | german (STRING) | russian (STRING) | b (STRING) |
|---|---|---|---|---|
| city bank | नेपाल | äbc | привет | NULL |

(1 row)

**Example: Log in with the user name in any case**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, username STRING NOT NULL, email STRING);
INSERT INTO app_users (username, email) VALUES ('Ram_Sharma', 'ram@example.com'), ('sita', 'sita@example.com');
```

```sql
SELECT id, username FROM app_users WHERE lower(username) = lower('RAM_sharma');
```

Result:

| id (INT) | username (STRING) |
|---|---|
| 1 | Ram_Sharma |

(1 row)

## upper

Syntax:

```sql
upper(text)
```

The text with every small letter made capital: `upper('city')` is `CITY`, `upper('ěšč')` is `ĚŠČ`. Letters without capitals (Nepali) stay as they are.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING (a number is turned into text) | the text to change |

- **Returns:** `STRING`.
- **NULL:** `upper(NULL)` is `NULL`.
- **Notes:** `upper('ß')` stays `ß`, as in PostgreSQL (one letter becomes one letter).

**Example**

```sql
SELECT upper('city नेपाल') AS a, upper('Coast') AS b, upper('crème brûlée') AS french, upper(NULL) AS c;
```

Result:

| a (STRING) | b (STRING) | french (STRING) | c (STRING) |
|---|---|---|---|
| CITY नेपाल | COAST | CRÈME BRÛLÉE | NULL |

(1 row)

**Example: Clean stock symbols typed by users**

Setup:

```sql
CREATE TABLE watchlist (id INT PRIMARY KEY AUTO, typed STRING);
INSERT INTO watchlist (typed) VALUES ('  city '), ('Coast'), ('volt  ');
```

```sql
SELECT id, '[' || typed || ']' AS typed, upper(trim(typed)) AS symbol FROM watchlist ORDER BY id;
```

Result:

| id (INT) | typed (STRING) | symbol (STRING) |
|---|---|---|
| 1 | [  city ] | CITY |
| 2 | [Coast] | COAST |
| 3 | [volt  ] | VOLT |

(3 rows)

<a id="length"></a>

## length, char_length, character_length

Syntax:

```sql
length(text)
char_length(text)
character_length(text)
```

The number of characters in the text. A Nepali letter is one character. The three names are the same function.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING, BYTES, or a value turned into text | the value to measure |

- **Returns:** `LONG`.
- **NULL:** `length(NULL)` is `NULL`.
- **Notes:** on a `BYTES` value it counts bytes (see [bytes functions](functions-bytes.md)). Some Nepali letters are made of 2 characters: `के` is `क` plus the sign `े`, so `length('के')` is `2`.

**Example**

```sql
SELECT length('CITY') AS a, length('नेपाल') AS nepali, length('के') AS ke, char_length('') AS empty, character_length('City Bank') AS b, length(12.50) AS number, length(NULL) AS c;
```

Result:

| a (LONG) | nepali (LONG) | ke (LONG) | empty (LONG) | b (LONG) | number (LONG) | c (STRING) |
|---|---|---|---|---|---|---|
| 4 | 5 | 2 | 0 | 9 | 4 | NULL |

(1 row)

**Example: Refuse a forum post that is too short or too long**

```sql
SELECT body, length(body) AS letters, length(body) BETWEEN 10 AND 500 AS ok
FROM (SELECT 'Good results!' AS body
      UNION ALL SELECT 'नाफा राम्रो छ'
      UNION ALL SELECT 'ok') AS posts;
```

Result:

| body (STRING) | letters (LONG) | ok (BOOL) |
|---|---|---|
| Good results! | 13 | true |
| नाफा राम्रो छ | 13 | true |
| ok | 2 | false |

(3 rows)

**Example: Company names in English and Nepali**

Setup:

```sql
CREATE TABLE companies (symbol STRING PRIMARY KEY, name STRING, name_ne STRING);
INSERT INTO companies VALUES ('CITY', 'City Bank Limited', 'सिटी बैंक लिमिटेड'), ('VOLT', 'Volt River Hydropower Limited', 'भोल्ट रिभर जलविद्युत लिमिटेड');
```

```sql
SELECT symbol, length(name) AS name_letters, name_ne, length(name_ne) AS ne_letters FROM companies ORDER BY symbol;
```

Result:

| symbol (STRING) | name_letters (LONG) | name_ne (STRING) | ne_letters (LONG) |
|---|---|---|---|
| CITY | 17 | सिटी बैंक लिमिटेड | 17 |
| VOLT | 29 | भोल्ट रिभर जलविद्युत लिमिटेड | 28 |

(2 rows)

## octet_length

Syntax:

```sql
octet_length(text)
```

The number of **bytes** the text takes in UTF-8. An English letter is 1 byte; a Nepali letter is 3 bytes.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING, BYTES, or a value turned into text | the value to measure |

- **Returns:** `LONG`.
- **NULL:** `octet_length(NULL)` is `NULL`.
- **Notes:** use it when a limit is in bytes (for example a column in another program that takes at most 255 bytes). For letters people see, use `length`.

**Example**

```sql
SELECT length('नेपाल') AS letters, octet_length('नेपाल') AS bytes, octet_length('CITY') AS english_bytes, octet_length('') AS empty;
```

Result:

| letters (LONG) | bytes (LONG) | english_bytes (LONG) | empty (LONG) |
|---|---|---|---|
| 5 | 15 | 4 | 0 |

(1 row)

<a id="substr"></a>

## substr, substring

Syntax:

```sql
substr(text, start)
substr(text, start, count)
substring(text, start [, count])
```

A part of the text: `count` characters from character number `start`. The first character is number 1. Without `count`, you get everything to the end. `substring` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING (or BYTES) | the text to cut |
| `start` | whole number | the first character to keep; `1` = first. `0` or less starts before the text, so fewer characters are left |
| `count` | whole number | how many characters; must not be negative |

- **Returns:** `STRING` (`BYTES` for a `BYTES` value, counted in bytes).
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** `start` after the end gives empty text `''`, not an error. A negative `count` is an error. `start` and `count` must be whole numbers: `'2'` or `2.5` is an error. The PostgreSQL form `substring(text FROM 2 FOR 3)` works too, and means the same as `substring(text, 2, 3)`.

**Example**

```sql
SELECT substr('CITY', 3) AS a, substring('CITY', 2, 3) AS b, substr('नेपाल', 2, 2) AS nepali, substr('CITY', 0, 3) AS from_zero, substr('CITY', 10) AS after_end;
```

Result:

| a (STRING) | b (STRING) | nepali (STRING) | from_zero (STRING) | after_end (STRING) |
|---|---|---|---|---|
| TY | ITY | ेप | CI |  |

(1 row)

**Example: Nepali fiscal year 2082/83: first and last year**

```sql
SELECT substr('2082/83', 1, 4) AS first_year, substr('2082/83', 6) AS second_year;
```

Result:

| first_year (STRING) | second_year (STRING) |
|---|---|
| 2082 | 83 |

(1 row)

**Example: A negative count is an error** (shows an error)

```sql
SELECT substr('CITY', 2, -1);
```

Result:

Error: `line 1, column 8: substr: the length must not be negative, got -1`

**Example: The PostgreSQL FROM ... FOR form**

```sql
SELECT substring('CITY' FROM 2 FOR 3) AS from_for, substring('CITY' FROM 2) AS to_the_end;
```

Result:

| from_for (STRING) | to_the_end (STRING) |
|---|---|
| ITY | ITY |

(1 row)

## left

Syntax:

```sql
left(text, n)
```

The first `n` characters of the text. With a negative `n`, everything except the last `-n` characters.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text |
| `n` | whole number | how many characters to keep from the start; negative = how many to drop from the end |

- **Returns:** `STRING`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** it never cuts a Nepali letter in half. `n` bigger than the text gives the whole text.

**Example**

```sql
SELECT left('CITY', 3) AS a, left('CITY', -2) AS drop_last_2, left('नेपाल बैंक', 5) AS nepali, left('CITY', 99) AS whole;
```

Result:

| a (STRING) | drop_last_2 (STRING) | nepali (STRING) | whole (STRING) |
|---|---|---|---|
| CIT | CI | नेपाल | CITY |

(1 row)

**Example: Short preview of long company names** (sample data: sample)

```sql
SELECT symbol,
       CASE WHEN length(name) > 25 THEN left(name, 25) || '...' ELSE name END AS preview
FROM securities
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | preview (STRING) |
|---|---|
| ACME | Acme Investment Company |
| CITY | City Bank Limited |
| COAST | Coastal Bank Limited |
| TELCO | Northwind Telecom Limited |
| VOLT | Volt River Hydropower Lim... |

(5 rows)

## right

Syntax:

```sql
right(text, n)
```

The last `n` characters of the text. With a negative `n`, everything except the first `-n` characters.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text |
| `n` | whole number | how many characters to keep from the end; negative = how many to drop from the start |

- **Returns:** `STRING`.
- **NULL:** `NULL` when any argument is `NULL`.

**Example**

```sql
SELECT right('CITY', 3) AS a, right('CITY', -2) AS drop_first_2, right('नेपाल', 2) AS nepali;
```

Result:

| a (STRING) | drop_first_2 (STRING) | nepali (STRING) |
|---|---|---|
| ITY | TY | ाल |

(1 row)

**Example: Show only the last 4 digits of a phone number**

```sql
SELECT '******' || right('9841234567', 4) AS phone_shown;
```

Result:

| phone_shown (STRING) |
|---|
| ******4567 |

(1 row)

<a id="trim"></a>

## trim, btrim

Syntax:

```sql
trim(text)
trim(text, characters)
btrim(text [, characters])
```

Removes spaces from both ends of the text. With `characters`, it removes any of those characters from both ends instead. `btrim` is the same function.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text to clean |
| `characters` | STRING | the characters to remove, in any order; default: space, tab, carriage return and line break |

- **Returns:** `STRING`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** `characters` is a set of single characters, not a word: `trim('xyCITYyx', 'xy')` removes every `x` and `y` at the ends. Characters in the middle stay. The standard forms `trim(BOTH 'x' FROM text)`, `trim(LEADING 'x' FROM text)` and `trim(TRAILING 'x' FROM text)` work too; `LEADING` is [ltrim](#ltrim) and `TRAILING` is [rtrim](#rtrim).

**Example**

```sql
SELECT '[' || trim('  CITY  ') || ']' AS a, trim('xxCOASTxx', 'x') AS b, btrim('--a-b--', '-') AS c, trim('xyCITYyx', 'xy') AS d;
```

Result:

| a (STRING) | b (STRING) | c (STRING) | d (STRING) |
|---|---|---|---|
| [CITY] | COAST | a-b | CITY |

(1 row)

**Example: Clean a user name before saving it**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, username STRING NOT NULL);
```

```sql
INSERT INTO app_users (username) VALUES (lower(trim('   Hari_KC  ')));
SELECT id, '[' || username || ']' AS saved FROM app_users;
```

Result:

`INSERT INTO app_users (username) VALUES (lower(trim('   Hari_KC  ')))`

```text
1 row(s) inserted
```

`SELECT id, '[' || username || ']' AS saved FROM app_users`

| id (INT) | saved (STRING) |
|---|---|
| 1 | [hari_kc] |

(1 row)

**Example: The standard BOTH / LEADING / TRAILING forms**

```sql
SELECT trim(BOTH 'x' FROM 'xxCOASTxx') AS both_ends,
       trim(LEADING 'x' FROM 'xxCOASTxx') AS front_only,
       trim(TRAILING 'x' FROM 'xxCOASTxx') AS end_only;
```

Result:

| both_ends (STRING) | front_only (STRING) | end_only (STRING) |
|---|---|---|
| COAST | COASTxx | xxCOAST |

(1 row)

## ltrim

Syntax:

```sql
ltrim(text [, characters])
```

Like `trim`, but only at the **start** (left side) of the text.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text to clean |
| `characters` | STRING | the characters to remove; default: space, tab, carriage return and line break |

- **Returns:** `STRING`.
- **NULL:** `NULL` when any argument is `NULL`.

**Example**

```sql
SELECT '[' || ltrim('   CITY  ') || ']' AS a, ltrim('00042', '0') AS no_zeros;
```

Result:

| a (STRING) | no_zeros (STRING) |
|---|---|
| [CITY  ] | 42 |

(1 row)

## rtrim

Syntax:

```sql
rtrim(text [, characters])
```

Like `trim`, but only at the **end** (right side) of the text.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text to clean |
| `characters` | STRING | the characters to remove; default: space, tab, carriage return and line break |

- **Returns:** `STRING`.
- **NULL:** `NULL` when any argument is `NULL`.

**Example**

```sql
SELECT '[' || rtrim('  CITY   ') || ']' AS a, rtrim('नेपाल।।', '।') AS nepali_full_stop, rtrim('512.500', '0') AS price;
```

Result:

| a (STRING) | nepali_full_stop (STRING) | price (STRING) |
|---|---|---|
| [  CITY] | नेपाल | 512.5 |

(1 row)

## replace

Syntax:

```sql
replace(text, from, to)
```

Replaces **every** place where `from` is found in `text` with `to`.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text |
| `from` | STRING | the text to find (upper and lower case must match) |
| `to` | STRING | the new text; `''` removes `from` |

- **Returns:** `STRING`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** an empty `from` changes nothing. The search does not ignore case: `replace('City', 'city', 'x')` is `City`. For patterns (any digit, any space) use [regexp_replace](functions-regex.md#regexp-replace).

**Example**

```sql
SELECT replace('a-b-c', '-', '/') AS a, replace('City Bank', 'Bank', 'Bank Limited') AS b, replace('City', 'city', 'x') AS case_matters, replace('CITY', '', 'x') AS empty_from;
```

Result:

| a (STRING) | b (STRING) | case_matters (STRING) | empty_from (STRING) |
|---|---|---|---|
| a/b/c | City Bank Limited | City | CITY |

(1 row)

**Example: Turn a price with commas into a number**

```sql
SELECT CAST(replace('1,234,567.50', ',', '') AS DOUBLE) AS amount;
```

Result:

| amount (DOUBLE) |
|---|
| 1234567.5 |

(1 row)

## split_part

Syntax:

```sql
split_part(text, separator, n)
```

Splits the text at every `separator` and gives part number `n`. `1` is the first part, `-1` is the last part.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text to split |
| `separator` | STRING | the text between the parts (one or more characters) |
| `n` | whole number | the part: `1` first, `2` second, `-1` last, `-2` second last. `0` is an error |

- **Returns:** `STRING`. A part that does not exist gives empty text `''`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** an empty `separator` gives the whole text as part 1. PostgreSQL also allows negative `n` (since version 14); MySQL has no `split_part`.

**Example**

```sql
SELECT split_part('2082/83', '/', 1) AS a, split_part('2082/83', '/', -1) AS last, split_part('a,b', ',', 5) AS missing;
```

Result:

| a (STRING) | last (STRING) | missing (STRING) |
|---|---|---|
| 2082 | 83 |  |

(1 row)

**Example: The domain of each user's email**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, email STRING NOT NULL);
INSERT INTO app_users (email) VALUES ('ram@example.com'), ('sita@mail.com.np'), ('hari@example.com');
```

```sql
SELECT split_part(email, '@', 2) AS domain, count(*) AS users FROM app_users GROUP BY split_part(email, '@', 2) ORDER BY domain;
```

Result:

| domain (STRING) | users (LONG) |
|---|---|
| example.com | 2 |
| mail.com.np | 1 |

(2 rows)

**Example: Part number 0 does not exist** (shows an error)

```sql
SELECT split_part('2082/83', '/', 0);
```

Result:

Error: `line 1, column 8: split_part: the field number must not be 0 (1 = first, -1 = last)`

## strpos

Syntax:

```sql
strpos(text, part)
```

Where `part` first starts in `text`, as a character number (1 = first). `0` when it is not there.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text to search in |
| `part` | STRING | the text to find (case must match) |

- **Returns:** `LONG`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** the number counts characters, so it works with Nepali text. An empty `part` gives `1`. `position(part IN text)` does the same with the arguments the other way round.

**Example**

```sql
SELECT strpos('CITY', 'IT') AS a, strpos('नेपाल बैंक', 'बैंक') AS nepali, strpos('CITY', 'x') AS not_found, strpos('City', 'cit') AS case_matters;
```

Result:

| a (LONG) | nepali (LONG) | not_found (LONG) | case_matters (LONG) |
|---|---|---|---|
| 2 | 7 | 0 | 0 |

(1 row)

**Example: The user name before the @ of an email**

```sql
SELECT email, left(email, strpos(email, '@') - 1) AS name
FROM (SELECT 'ram.sharma@example.com' AS email UNION ALL SELECT 'sita@mail.com.np') AS e;
```

Result:

| email (STRING) | name (STRING) |
|---|---|
| ram.sharma@example.com | ram.sharma |
| sita@mail.com.np | sita |

(2 rows)

## position

Syntax:

```sql
position(part IN text)
position(part, text)
```

Where `part` first starts in `text`, as a character number (1 = first). `0` when it is not there. The same as `strpos(text, part)`.

| Argument | Type | Meaning |
|---|---|---|
| `part` | STRING | the text to find (case must match) |
| `text` | STRING | the text to search in |

- **Returns:** `LONG`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** `part` comes **first** here, but second in `strpos`.

**Example**

```sql
SELECT position('बैंक' IN 'नेपाल बैंक') AS nepali, position('TY' IN 'CITY') AS a, position('TY', 'CITY') AS b, position('x' IN 'CITY') AS not_found;
```

Result:

| nepali (LONG) | a (LONG) | b (LONG) | not_found (LONG) |
|---|---|---|---|
| 7 | 3 | 3 | 0 |

(1 row)

## starts_with

Syntax:

```sql
starts_with(text, prefix)
```

`true` when the text begins with `prefix`.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text |
| `prefix` | STRING | the start to look for (case must match) |

- **Returns:** `BOOL`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** an empty `prefix` is always `true`. `text LIKE 'NA%'` gives the same answer, and it can use an [index](indexes.md).

**Example**

```sql
SELECT starts_with('CITY', 'CI') AS a, starts_with('city', 'CI') AS case_matters, starts_with('CITY', '') AS empty;
```

Result:

| a (BOOL) | case_matters (BOOL) | empty (BOOL) |
|---|---|---|
| true | false | true |

(1 row)

**Example: Companies whose symbol starts with N** (sample data: sample)

```sql
SELECT symbol, name FROM securities WHERE starts_with(symbol, 'N') ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | name (STRING) |
|---|---|

(0 rows)

## ends_with

Syntax:

```sql
ends_with(text, suffix)
```

`true` when the text ends with `suffix`.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text |
| `suffix` | STRING | the end to look for (case must match) |

- **Returns:** `BOOL`.
- **NULL:** `NULL` when any argument is `NULL`.

**Example**

```sql
SELECT ends_with('CITY', 'TY') AS a, ends_with('CITY', 'ty') AS case_matters;
```

Result:

| a (BOOL) | case_matters (BOOL) |
|---|---|
| true | false |

(1 row)

**Example: Users with an email address in Nepal (.np)**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, email STRING NOT NULL);
INSERT INTO app_users (email) VALUES ('ram@example.com'), ('sita@mail.com.np'), ('hari@northwind.example.com');
```

```sql
SELECT id, email FROM app_users WHERE ends_with(lower(email), '.np') ORDER BY id;
```

Result:

| id (INT) | email (STRING) |
|---|---|
| 2 | sita@mail.com.np |

(1 row)

## lpad

Syntax:

```sql
lpad(text, length)
lpad(text, length, fill)
```

Makes the text `length` characters long by adding `fill` on the **left**. When the text is longer, it is cut to `length`.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING (a number is turned into text) | the text |
| `length` | whole number | the length you want, in characters (at most 10 000 000) |
| `fill` | STRING | what to add, repeated as needed; default one space |

- **Returns:** `STRING`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** `length` of 0 or less gives `''`. An empty `fill` gives the text unchanged. A text that is too long is cut at the **end** (like PostgreSQL).

**Example**

```sql
SELECT lpad('7', 3, '0') AS a, '[' || lpad('5', 3) || ']' AS spaces, lpad('ab', 7, 'xy') AS b, lpad('CITY', 3) AS cut, lpad('न', 3, 'क') AS nepali;
```

Result:

| a (STRING) | spaces (STRING) | b (STRING) | cut (STRING) | nepali (STRING) |
|---|---|---|---|---|
| 007 | [  5] | xyxyxab | CIT | ककन |

(1 row)

**Example: Invoice numbers with leading zeros**

Setup:

```sql
CREATE TABLE invoices (id INT PRIMARY KEY AUTO, amount DECIMAL(2));
INSERT INTO invoices (amount) VALUES (1500.00), (250.50), (99999.99);
```

```sql
SELECT 'INV-2082-' || lpad(id, 5, '0') AS invoice_no, amount FROM invoices ORDER BY id;
```

Result:

| invoice_no (STRING) | amount (DECIMAL(2)) |
|---|---|
| INV-2082-00001 | 1500.00 |
| INV-2082-00002 | 250.50 |
| INV-2082-00003 | 99999.99 |

(3 rows)

**Example: The length has a limit** (shows an error)

```sql
SELECT lpad('a', 20000000);
```

Result:

Error: `line 1, column 8: lpad: the length is larger than 10000000`

## rpad

Syntax:

```sql
rpad(text, length)
rpad(text, length, fill)
```

Makes the text `length` characters long by adding `fill` on the **right**. When the text is longer, it is cut to `length`.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING (a number is turned into text) | the text |
| `length` | whole number | the length you want, in characters (at most 10 000 000) |
| `fill` | STRING | what to add, repeated as needed; default one space |

- **Returns:** `STRING`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** the same rules as `lpad`.

**Example**

```sql
SELECT rpad('CITY', 8, '.') AS a, rpad('CITY', 3) AS cut, '[' || rpad('COAST', 6) || ']' AS spaces;
```

Result:

| a (STRING) | cut (STRING) | spaces (STRING) |
|---|---|---|
| CITY.... | CIT | [COAST ] |

(1 row)

**Example: A simple fixed-width price list** (sample data: sample)

```sql
SELECT rpad(symbol, 8, '.') || lpad(close, 8) AS line
FROM ochl_day
WHERE time = '2026-09-09'
ORDER BY symbol;
```

Result:

| line (STRING) |
|---|
| CITY....   504.6 |
| COAST...   380.1 |
| VOLT....   187.3 |

(3 rows)

## repeat

Syntax:

```sql
repeat(text, n)
```

The text written `n` times one after another.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text to repeat |
| `n` | whole number | how many times; 0 or less gives `''` |

- **Returns:** `STRING`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** the result can be at most 16 MB; a bigger one is an error.

**Example**

```sql
SELECT repeat('ab', 3) AS a, repeat('नम', 2) AS nepali, repeat('-', 0) AS zero;
```

Result:

| a (STRING) | nepali (STRING) | zero (STRING) |
|---|---|---|
| ababab | नमनम |  |

(1 row)

**Example: A text bar chart of the CITY close price** (sample data: sample)

```sql
SELECT time, close, repeat('#', floor((close - 500) / 2)) AS bar
FROM ochl_day
WHERE symbol = 'CITY'
ORDER BY time
LIMIT 6;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) | bar (STRING) |
|---|---|---|
| 2025-12-28T00:00:00.000Z | 542.2 | ##################### |
| 2025-12-29T00:00:00.000Z | 539.7 | ################### |
| 2025-12-30T00:00:00.000Z | 539.3 | ################### |
| 2025-12-31T00:00:00.000Z | 542.4 | ##################### |
| 2026-08-23T00:00:00.000Z | 507.9 | ### |
| 2026-08-24T00:00:00.000Z | 510.3 | ##### |

(6 rows)

## reverse

Syntax:

```sql
reverse(text)
```

The characters of the text in the opposite order: `reverse('CITY')` is `YTIC`.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING (or BYTES) | the text |

- **Returns:** `STRING` (`BYTES` for a `BYTES` value, byte by byte).
- **NULL:** `reverse(NULL)` is `NULL`.
- **Notes:** it works character by character. A Nepali vowel sign is its own character, so it lands on the other side of its letter: the result of Nepali text does not read well.

**Example**

```sql
SELECT reverse('CITY') AS a, reverse('12345') AS b, reverse('नेपाल') AS nepali;
```

Result:

| a (STRING) | b (STRING) | nepali (STRING) |
|---|---|---|
| YTIC | 54321 | लापेन |

(1 row)

## concat

Syntax:

```sql
concat(value, value, ...)
```

Joins the values into one text. `NULL` values are skipped. Numbers, dates and times are turned into text first.

| Argument | Type | Meaning |
|---|---|---|
| `value` | any type | 1 to 64 values to join |

- **Returns:** `STRING`. Never `NULL`: when every value is `NULL`, the result is `''`.
- **NULL:** `NULL` values are skipped.
- **Notes:** `a || b` also joins text, but it gives `NULL` when one side is `NULL`. `concat()` with no values is an error.

**Example**

```sql
SELECT concat('CITY', '-', 2082) AS a, concat('a', NULL, 'b') AS null_skipped, concat(NULL) AS all_null, concat('Close: ', 512.5) AS b;
```

Result:

| a (STRING) | null_skipped (STRING) | all_null (STRING) | b (STRING) |
|---|---|---|---|
| CITY-2082 | ab |  | Close: 512.5 |

(1 row)

**Example: Full name when the middle name is missing**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, first_name STRING, middle_name STRING, last_name STRING);
INSERT INTO app_users (first_name, middle_name, last_name) VALUES ('Ram', 'Bahadur', 'Thapa'), ('Sita', NULL, 'Sharma');
```

```sql
SELECT id,
       concat(first_name, ' ', middle_name, ' ', last_name) AS with_concat,
       first_name || ' ' || middle_name || ' ' || last_name AS with_pipes
FROM app_users ORDER BY id;
```

Result:

| id (INT) | with_concat (STRING) | with_pipes (STRING) |
|---|---|---|
| 1 | Ram Bahadur Thapa | Ram Bahadur Thapa |
| 2 | Sita  Sharma | NULL |

(2 rows)

## concat_ws

Syntax:

```sql
concat_ws(separator, value, value, ...)
```

Joins the values with `separator` between them. `NULL` values are skipped, and they get no separator. "ws" means "with separator".

| Argument | Type | Meaning |
|---|---|---|
| `separator` | STRING | the text put between two values |
| `value` | any type | 0 to 63 values to join |

- **Returns:** `STRING`.
- **NULL:** a `NULL` separator gives `NULL`. `NULL` values are skipped.

**Example**

```sql
SELECT concat_ws(', ', 'a', NULL, 'b') AS a, concat_ws('/', 2082, 83) AS fiscal_year, concat_ws(NULL, 'a', 'b') AS null_separator;
```

Result:

| a (STRING) | fiscal_year (STRING) | null_separator (STRING) |
|---|---|---|
| a, b | 2082/83 | NULL |

(1 row)

**Example: The full name from the example above, without double spaces**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, first_name STRING, middle_name STRING, last_name STRING);
INSERT INTO app_users (first_name, middle_name, last_name) VALUES ('Ram', 'Bahadur', 'Thapa'), ('Sita', NULL, 'Sharma');
```

```sql
SELECT id, concat_ws(' ', first_name, middle_name, last_name) AS full_name FROM app_users ORDER BY id;
```

Result:

| id (INT) | full_name (STRING) |
|---|---|
| 1 | Ram Bahadur Thapa |
| 2 | Sita Sharma |

(2 rows)

## format

Syntax:

```sql
format(text, value, value, ...)
```

Fills the places in `text` with the values, as PostgreSQL does. Its main use is SQL text for [EXECUTE](procedure-language.md#execute) in a procedure.

| Place | Puts in | A `NULL` value |
|---|---|---|
| `%s` | the value as text | nothing (empty text) |
| `%I` | a table or column name, in double quotes when needed | an error |
| `%L` | a value in single quotes, quotes inside doubled | `NULL` (no quotes) |
| `%%` | one `%` | |
| `%2$s` | the 2nd value (any place type); the next place takes the 3rd | |
| `%10s`, `%-10s` | at least 10 characters, filled with spaces on the left (or right with `-`) | |

- **Returns:** `STRING`. A `NULL` text gives `NULL`.
- **Notes:** text made with `%I` and `%L` is safe to run as SQL: a quote inside a value stays part of the value. Too few values, or another letter after `%`, is an error.

**Example**

```sql
SELECT format('%s has %s rows', 'trades', 120) AS plain,
       format('SELECT * FROM %I WHERE symbol = %L', 'Daily Prices', 'it''s') AS safe_sql,
       format('[%-6s][%6s][%L]', 'ab', 'cd', NULL) AS widths;
```

Result:

| plain (STRING) | safe_sql (STRING) | widths (STRING) |
|---|---|---|
| trades has 120 rows | SELECT * FROM "Daily Prices" WHERE symbol = 'it''s' | [ab    ][    cd][NULL] |

(1 row)

**Example: A NULL cannot be a name** (shows an error)

```sql
SELECT format('SELECT * FROM %I', NULL);
```

Result:

Error: `line 1, column 8: format: %I of format() got NULL: a NULL cannot be a table or column name`

## quote_ident

Syntax:

```sql
quote_ident(name)
```

The name as it can be written in SQL: as it is when it is all small letters, digits and `_` and not a reserved word, otherwise in double quotes (with `"` doubled). `quote_ident('close')` is `close`; `quote_ident('Close')` is `"Close"`.

- **Returns:** `STRING`.

<a id="quote_literal"></a>

## quote_literal, quote_nullable

Syntax:

```sql
quote_literal(value)
quote_nullable(value)
```

The value as SQL text in single quotes, with every `'` doubled: `quote_literal('it''s')` is `'it''s'`. A number is quoted too.

- **Returns:** `STRING`.
- **NULL:** `quote_literal(NULL)` is `NULL`; `quote_nullable(NULL)` is the text `NULL`, so the SQL still works.

**Example**

```sql
SELECT quote_ident('close') AS a, quote_ident('Daily Prices') AS b, quote_literal('O''Brien') AS c,
       quote_literal(42) AS d, quote_nullable(NULL) AS e;
```

Result:

| a (STRING) | b (STRING) | c (STRING) | d (STRING) | e (STRING) |
|---|---|---|---|---|
| close | "Daily Prices" | 'O''Brien' | '42' | NULL |

(1 row)

**Example: One CSV line per trading day** (sample data: sample)

```sql
SELECT concat_ws(',', symbol, open, high, low, close) AS csv_line
FROM ochl_day
WHERE symbol = 'COAST'
ORDER BY time
LIMIT 3;
```

Result:

| csv_line (STRING) |
|---|
| COAST,420.3,426.6,417.6,424.8 |
| COAST,425.9,428.9,421.2,424.2 |
| COAST,423.6,426.1,420.1,423 |

(3 rows)

<a id="concat-operator"></a>

## || (join text)

Syntax:

```sql
text || text
```

Joins two values into one text: `'CITY' || '-' || 2082` is `CITY-2082`. A number or date on one side is turned into text.

| Operand | Type | Meaning |
|---|---|---|
| left, right | any type | the two values to join |

- **Returns:** `STRING`. Two `BYTES` values give `BYTES`.
- **NULL:** `NULL` on either side gives `NULL`. Use `concat` or `coalesce` when a value can be `NULL`.
- **Notes:** `||` has the **same** priority as `+` and `-`, and they are done from left to right. So `'a' || 1 + 2` is `('a' || 1) + 2`, which is an error. PostgreSQL does `+` first. Write `'a' || (1 + 2)`. MySQL reads `||` as OR unless a setting is changed; KarelaDB always joins text.

**Example**

```sql
SELECT 'CITY' || '-' || 2082 AS a, 'Close: ' || 512.5 AS b, 'a' || NULL AS with_null, 'total ' || (1 + 2) AS brackets;
```

Result:

| a (STRING) | b (STRING) | with_null (STRING) | brackets (STRING) |
|---|---|---|---|
| CITY-2082 | Close: 512.5 | NULL | total 3 |

(1 row)

**Example: A link to each news article**

Setup:

```sql
CREATE TABLE news (id LONG PRIMARY KEY AUTO, title STRING NOT NULL, symbol STRING);
INSERT INTO news (title, symbol) VALUES ('City Bank profit rises 18%', 'CITY'), ('Market index closes at 2,840', NULL);
```

```sql
SELECT id, '/news/' || id || '-' || lower(replace(left(title, 20), ' ', '-')) AS url,
       'Stock: ' || symbol AS stock_line,
       'Stock: ' || coalesce(symbol, 'market') AS fixed
FROM news ORDER BY id;
```

Result:

| id (LONG) | url (STRING) | stock_line (STRING) | fixed (STRING) |
|---|---|---|---|
| 1 | /news/1-city-bank-profit-ris | Stock: CITY | Stock: CITY |
| 2 | /news/2-market-index-closes- | NULL | Stock: market |

(2 rows)

**Example: Without brackets, + is done after ||** (shows an error)

```sql
SELECT 'total ' || 1 + 2;
```

Result:

Error: `line 1, column 22: 'total 1' and '2' are not both numbers`

## initcap

Syntax:

```sql
initcap(text)
```

Every word gets a capital first letter and small letters after it: `initcap('city bank limited')` is `City Bank Limited`.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING (a number is turned into text) | the text to change |

- **Returns:** `STRING`.
- **NULL:** `initcap(NULL)` is `NULL`.
- **Notes:** a word ends at anything that is not a letter or a digit, so `ram-bahadur` becomes `Ram-Bahadur`. Letters of every script with capitals change (`élan` becomes `Élan`); Nepali letters stay as they are. Short words like "and" are capitalised too, so a company name that is already written correctly (`Coastal Bank`) is better left alone.

**Example: Tidy up a name a user typed**

```sql
SELECT initcap('city bank limited') AS company,
       initcap('RAM BAHADUR SHRESTHA') AS person,
       initcap('ram-bahadur kc') AS with_hyphen,
       initcap(NULL) AS nothing;
```

Result:

| company (STRING) | person (STRING) | with_hyphen (STRING) | nothing (STRING) |
|---|---|---|---|
| City Bank Limited | Ram Bahadur Shrestha | Ram-Bahadur Kc | NULL |

(1 row)

**Example: Company names in title case** (sample data: sample)

```sql
SELECT symbol, name, initcap(lower(name)) AS title_case
FROM securities
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | name (STRING) | title_case (STRING) |
|---|---|---|
| ACME | Acme Investment Company | Acme Investment Company |
| CITY | City Bank Limited | City Bank Limited |
| COAST | Coastal Bank Limited | Coastal Bank Limited |
| TELCO | Northwind Telecom Limited | Northwind Telecom Limited |
| VOLT | Volt River Hydropower Limited | Volt River Hydropower Limited |

(5 rows)

## md5

Syntax:

```sql
md5(text)
```

The MD5 hash of the text: 32 lower-case hex digits. The same text always gives the same digits.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING (a number or time is turned into text) | the text to hash |

- **Returns:** `STRING`, always 32 characters.
- **NULL:** `md5(NULL)` is `NULL`. `md5('')` is `d41d8cd98f00b204e9800998ecf8427e`.
- **Notes:** **never use MD5 for passwords.** It is broken for that: use [password_hash](functions-security.md#password_hash). MD5 is fine as a short fingerprint of a row, to see whether a file or a record changed. It is here because PostgreSQL apps call it. For a strong fingerprint use [sha256](functions-security.md#sha256).

**Example: A short fingerprint for each daily candle** (sample data: sample)

```sql
SELECT symbol, close, md5(symbol || ':' || CAST(time AS STRING)) AS row_key
FROM ochl_day
WHERE time IN '2026-09-10'
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | close (DOUBLE) | row_key (STRING) |
|---|---|---|
| CITY | 504.9 | 8c227f18b2f287859fb2008492cc191a |
| COAST | 376.1 | 7e95ad0adf2f1015de2a7078a3a221c6 |
| VOLT | 191.2 | 66b1f4d8c7af12a0fd60ade3702adfb1 |

(3 rows)

**Example: The same text always gives the same digits**

```sql
SELECT md5('CITY') AS a, md5('CITY') = md5('CITY') AS always_same, md5('') AS empty_text, md5(NULL) AS nothing;
```

Result:

| a (STRING) | always_same (BOOL) | empty_text (STRING) | nothing (STRING) |
|---|---|---|---|
| 859214628431995197c0558f7b5f8ffc | true | d41d8cd98f00b204e9800998ecf8427e | NULL |

(1 row)

## to_str

Syntax:

```sql
to_str(time, format)
```

Writes a time as text in the QuestDB format letters. QuestDB apps use this name; KarelaDB's own name for the same job is [to_char](functions-date-time.md#to_char).

| Argument | Type | Meaning |
|---|---|---|
| `time` | `TIMESTAMP`, `DATE`, time text or milliseconds | the time to write |
| `format` | `STRING` | the pattern, see the table below |

| Letters | Gives | Example |
|---|---|---|
| `yyyy`, `yy` | year, 4 or 2 digits | `2026`, `26` |
| `MM`, `MMM` | month number, month name | `09`, `Sep` |
| `dd` | day of the month | `10` |
| `HH`, `hh` | hour 0-23, hour 1-12 | `05`, `11` |
| `mm`, `ss`, `SSS` | minute, second, millisecond | `15`, `00`, `123` |
| `EEE` | weekday name | `Thu` |
| `a` | AM or PM | `AM` |
| `'text'` | text in single quotes is written as it is | `'at'` |

- **Returns:** `STRING`.
- **NULL:** `NULL` when the time or the format is `NULL`.
- **Notes:** everything is **UTC**. For a local clock add its offset first, for example 20700000 for Nepal: `to_str(time + 20700000, 'HH:mm')`. Letters KarelaDB does not know are written as they are. `UUU` (microseconds) is always `000`, because KarelaDB keeps milliseconds.

**Example: Minute candles with a readable clock** (sample data: sample)

```sql
SELECT to_str(time, 'yyyy-MM-dd') AS day,
       to_str(time, 'HH:mm') AS utc_clock,
       to_str(time + 20700000, 'HH:mm') AS nepal_clock,
       close
FROM ochl_minutes
WHERE symbol = 'CITY'
ORDER BY time
LIMIT 3;
```

Result:

| day (STRING) | utc_clock (STRING) | nepal_clock (STRING) | close (DOUBLE) |
|---|---|---|---|
| 2026-09-09 | 05:15 | 11:00 | 512.1 |
| 2026-09-09 | 05:16 | 11:01 | 511.9 |
| 2026-09-09 | 05:17 | 11:02 | 511.9 |

(3 rows)

**Example: A long date for a report heading** (sample data: sample)

```sql
SELECT to_str(time, 'EEE dd MMM yyyy') AS trading_day, symbol, close
FROM ochl_day
WHERE time IN '2026-09-10'
ORDER BY symbol;
```

Result:

| trading_day (STRING) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| Thu 10 Sep 2026 | CITY | 504.9 |
| Thu 10 Sep 2026 | COAST | 376.1 |
| Thu 10 Sep 2026 | VOLT | 191.2 |

(3 rows)

## string_to_array

Syntax:

```sql
string_to_array(text, separator)
string_to_array(text, separator, null_text)
```

Cuts the text into a list at every `separator`. The PostgreSQL way to turn `'CITY,COAST'` into a list of symbols.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text to cut |
| `separator` | STRING | the text between the parts; `NULL` cuts into single characters |
| `null_text` | STRING | a part equal to this becomes `NULL` |

- **Returns:** an array (a `JSON` list). See [arrays](functions-postgres.md#arrays).
- **NULL:** `string_to_array(NULL, ',')` is `NULL`. Empty text gives an empty list `[]`.
- **Notes:** an empty separator gives a list with the whole text in it. To go the other way use [array_to_string](functions-postgres.md#array_to_string); to make rows out of the list use [unnest](functions-postgres.md#unnest). To take one part only, [split_part](#split-part) is simpler.

**Example: A watchlist typed as one line**

```sql
SELECT string_to_array('CITY,COAST,VOLT', ',') AS symbols,
       cardinality(string_to_array('CITY,COAST,VOLT', ',')) AS how_many,
       string_to_array('CITY,,VOLT', ',', '') AS empty_part_is_null,
       string_to_array('MARKET', NULL) AS every_character;
```

Result:

| symbols (TEXT[]) | how_many (LONG) | empty_part_is_null (TEXT[]) | every_character (TEXT[]) |
|---|---|---|---|
| ["CITY","COAST","VOLT"] | 3 | ["CITY",null,"VOLT"] | ["M","A","R","K","E","T"] |

(1 row)

**Example: Show the companies of a typed watchlist** (sample data: sample)

```sql
SELECT symbol, name, sector
FROM securities
WHERE symbol IN (SELECT unnest(string_to_array('CITY,VOLT', ',')))
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | name (STRING) | sector (STRING) |
|---|---|---|
| CITY | City Bank Limited | Banking |
| VOLT | Volt River Hydropower Limited | Energy |

(2 rows)

## string_to_table

Syntax:

```sql
string_to_table(text, separator)
string_to_table(text, separator, null_text)
```

The same cut as [string_to_array](#string-to-array), but one **row** per part instead of one list. Use it in `FROM` or in the `SELECT` list.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text to cut |
| `separator` | STRING | the text between the parts; `NULL` cuts into single characters |
| `null_text` | STRING | a part equal to this becomes `NULL` |

- **Returns:** rows of `STRING`, one per part. In `FROM` the column is named after the function, or after the alias: `AS t(sym)`.
- **NULL:** `NULL` text gives no rows. Empty text gives no rows.
- **Notes:** in `FROM` the arguments must be constants. For a column write `SELECT id, string_to_table(col, ',') FROM t`.

**Example: A typed watchlist as rows**

```sql
SELECT sym FROM string_to_table('CITY,COAST,VOLT', ',') AS t(sym);
```

Result:

| sym (STRING) |
|---|
| CITY |
| COAST |
| VOLT |

(3 rows)

## ascii

Syntax:

```sql
ascii(text)
```

The number of the first character of the text (its Unicode code point). `ascii('A')` is `65`, `ascii('न')` is `2344`.

- **Returns:** `LONG`. Empty text gives `0`.
- **NULL:** `ascii(NULL)` is `NULL`.

**Example**

```sql
SELECT ascii('A') AS a, ascii('é') AS e_accent, ascii('नेपाल') AS na, ascii('') AS empty;
```

Result:

| a (LONG) | e_accent (LONG) | na (LONG) | empty (LONG) |
|---|---|---|---|
| 65 | 233 | 2344 | 0 |

(1 row)

## chr

Syntax:

```sql
chr(number)
```

The character with this Unicode number: `chr(65)` is `A`, `chr(2344)` is `न`. The opposite of [ascii](#ascii).

- **Returns:** `STRING` of one character.
- **Errors (as PostgreSQL, SQLSTATE 54000):** `0` ("null character not permitted"), a negative number, a number above 1114111, and the numbers 55296-57343 (they are not characters on their own).

**Example**

```sql
SELECT chr(65) AS a, chr(2344) AS na, chr(10) = E'\n' AS newline;
```

Result:

| a (STRING) | na (STRING) | newline (BOOL) |
|---|---|---|
| A | न | true |

(1 row)

**Example: 0 is not a character** (shows an error)

```sql
SELECT chr(0);
```

Result:

Error: `line 1, column 8: chr: null character not permitted`

## translate

Syntax:

```sql
translate(text, from, to)
```

Swaps single characters: each character of `from` becomes the character at the same place in `to`. A character of `from` with no partner in `to` is removed.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text to change |
| `from` | STRING | the characters to find |
| `to` | STRING | what they become, place by place |

- **Returns:** `STRING`.
- **Notes:** `translate('12345', '143', 'ax')` is `a2x5`: 1 becomes a, 4 becomes x, 3 is removed. A character named twice in `from` uses its first partner. It works on characters of any language. When `from` and `to` are written in the query, the swap table is made once for the whole query.

**Example**

```sql
SELECT translate('12345', '143', 'ax') AS pg_example,
       translate('résumé', 'é', 'e') AS no_accents,
       translate('98-41-234567', '-', '') AS digits_only;
```

Result:

| pg_example (STRING) | no_accents (STRING) | digits_only (STRING) |
|---|---|---|
| a2x5 | resume | 9841234567 |

(1 row)

## overlay

Syntax:

```sql
overlay(text PLACING new_text FROM start)
overlay(text PLACING new_text FROM start FOR count)
overlay(text, new_text, start [, count])
```

Puts `new_text` into `text` at character `start`, in place of `count` characters. Without `FOR`, as many characters as `new_text` has are replaced.

- **Returns:** `STRING` (`BYTES` when `text` is `BYTES`: then it counts bytes).
- **Notes:** `overlay('Txxxxas' PLACING 'hom' FROM 2 FOR 4)` is `Thomas`. `FOR 0` inserts without removing anything. A start past the end adds at the end.
- **Errors:** a start of `0` or less: "negative substring length not allowed" (SQLSTATE 22011), as PostgreSQL.

**Example**

```sql
SELECT overlay('Txxxxas' PLACING 'hom' FROM 2 FOR 4) AS thomas,
       overlay('98XXXXXX45' PLACING '******' FROM 3) AS masked,
       overlay('abc' PLACING '-' FROM 2 FOR 0) AS inserted;
```

Result:

| thomas (STRING) | masked (STRING) | inserted (STRING) |
|---|---|---|
| Thomas | 98******45 | a-bc |

(1 row)

## normalize

Syntax:

```sql
normalize(text)
normalize(text, NFC | NFD | NFKC | NFKD)
```

Brings text into one Unicode **normal form**. The same letter can be written two ways: `á` as one character, or as `a` followed by an accent mark. They look the same but do not compare equal until both are normalized.

| Form | What it does |
|---|---|
| `NFC` (the default) | joins a letter and its marks into one character where Unicode has one |
| `NFD` | takes such characters apart: letter, then marks |
| `NFKC` | like NFC, and turns look-alike characters into plain ones: `ﬁ` → `fi`, `²` → `2`, `①` → `1` |
| `NFKD` | like NFD with the same look-alike rule |

- **Returns:** `STRING`.
- **Notes:** the form is written as a bare word, as in PostgreSQL; `'NFC'` in quotes works too. Text of plain English letters comes back at once, unchanged.
- **Errors:** another form name: "invalid normalization form" (SQLSTATE 22023).

**Example**

```sql
SELECT normalize(U&'\0061\0301', NFC) = U&'\00E1' AS same_letter,
       length(normalize('á', NFD)) AS letters_nfd,
       normalize('ﬁle ²', NFKC) AS plain;
```

Result:

| same_letter (BOOL) | letters_nfd (LONG) | plain (STRING) |
|---|---|---|
| true | 2 | file 2 |

(1 row)

`U&'...'` is PostgreSQL's way to write characters by number: `\XXXX` (4 hex digits) or `\+XXXXXX` (6), and `\\` for a backslash.

## to_ascii

Syntax:

```sql
to_ascii(text)
to_ascii(text, 'LATIN1')
```

The text with accents taken off, in plain ASCII: `to_ascii('Karél')` is `Karel`.

- **Returns:** `STRING`.
- **Notes:** Latin-1 letters follow PostgreSQL's table (`Æ` → `A`, `ß` → `B`, `ÿ` → `y`). Other letters with accents keep their letter (`ě` → `e`). A PostgreSQL database in UTF-8 refuses `to_ascii` altogether; KarelaDB answers as a PostgreSQL database in LATIN1 does.
- **Errors:** a character with no ASCII form, such as Nepali letters: "has no ASCII equivalent" (SQLSTATE 22P05). Encodings other than LATIN1 are not supported (0A000).

**Example**

```sql
SELECT to_ascii('Karél') AS a, to_ascii('Škoda Ørsted') AS b;
```

Result:

| a (STRING) | b (STRING) |
|---|---|
| Karel | Skoda Orsted |

(1 row)

## bit_length

Syntax:

```sql
bit_length(text)
```

The size of the text in bits: 8 times [octet_length](#octet-length). `bit_length('jose')` is `32`; `bit_length('न')` is `24`.

- **Returns:** `LONG`. Works on `BYTES` too.

**Example**

```sql
SELECT bit_length('jose') AS english, bit_length('न') AS nepali_letter;
```

Result:

| english (LONG) | nepali_letter (LONG) |
|---|---|
| 32 | 24 |

(1 row)

## to_hex

Syntax:

```sql
to_hex(number)
```

A whole number in hexadecimal (base 16), small letters: `to_hex(255)` is `ff`.

- **Returns:** `STRING`.
- **Notes:** a negative number is written as PostgreSQL does: in 32 bits when it fits an `INT` (`to_hex(-1)` is `ffffffff`), else in 64 bits.

**Example**

```sql
SELECT to_hex(255) AS ff, to_hex(4096) AS big, to_hex(-1) AS minus_one;
```

Result:

| ff (STRING) | big (STRING) | minus_one (STRING) |
|---|---|---|
| ff | 1000 | ffffffff |

(1 row)

## parse_ident

Syntax:

```sql
parse_ident(name)
parse_ident(name, strict)
```

Splits a qualified name like `"SomeSchema".someTable` into its parts, the PostgreSQL way: quotes are taken off, a name without quotes is made lower case, `""` inside quotes is one quote.

- **Returns:** an array of `STRING` (a `JSON` list).
- **Notes:** with `strict` = `false`, text after the name is ignored: `parse_ident('a b', false)` is `{a}`.
- **Errors:** text that is not a valid name ("string is not a valid identifier", SQLSTATE 22023).

**Example**

```sql
SELECT parse_ident('"SomeSchema".someTable') AS parts,
       parse_ident('market.Trades')[2] AS table_part;
```

Result:

| parts (TEXT[]) | table_part (STRING) |
|---|---|
| ["SomeSchema","sometable"] | trades |

(1 row)

<a id="to_char-number"></a>

## to_char for numbers

Syntax:

```sql
to_char(number, format)
```

Writes a number as text with a picture of the digits, exactly as PostgreSQL does. (For times see [to_char](functions-date-time.md#to_char).)

| Code | Meaning |
|---|---|
| `9` | a digit; a blank when the number has no digit here |
| `0` | a digit, `0` when the number has none (leading zeros) |
| `.` or `D` | the decimal point |
| `,` or `G` | the thousands separator (left out before the first digit) |
| `FM` | no padding blanks and no trailing zeros |
| `S`, `MI`, `PL`, `SG` | the sign next to the number; `-` at that place; `+` at that place; `+` or `-` at that place |
| `PR` | a negative number in angle brackets: `<485>` |
| `L` | the money sign `$` |
| `RN` / `rn` | Roman numerals (1 to 3999) |
| `TH` / `th` | the ordinal ending: `1st`, `22nd`, `13th` |
| `V` | multiplies by 10 for each `9` after it |
| `EEEE` | scientific notation: `4.86e-04` |
| `"text"` | text as it is |

- **Returns:** `STRING`. Without `FM` the text starts with a place for the sign: `to_char(485, '999')` is ` 485`.
- **Notes:** a number with more digits than the picture has places shows `#` in every place. A `DECIMAL` (and a number written in the query, such as `1234.5`) is exact and rounds halves away from zero; a `DOUBLE` rounds as PostgreSQL's float8 does (at most 15 digits). A whole number with a time format (`'YYYY-MM-DD'`) is still read as milliseconds since 1970, as before. A format written in the query is read once for all rows.
- **Errors:** PostgreSQL's (SQLSTATE 42601): "multiple decimal points", "cannot use "S" twice", ...

**Example**

```sql
SELECT to_char(1234.5, 'FM999,999.00') AS money,
       to_char(-485, '999PR') AS bracket,
       to_char(7, 'FM000') AS padded,
       to_char(0.0004859, '9.99EEEE') AS sci,
       to_char(2026, 'FMRN') AS roman,
       to_char(22, 'FM99th') AS ordinal;
```

Result:

| money (STRING) | bracket (STRING) | padded (STRING) | sci (STRING) | roman (STRING) | ordinal (STRING) |
|---|---|---|---|---|---|
| 1,234.50 | <485> | 007 |  4.86e-04 | MMXXVI | 22nd |

(1 row)

**Example: Turnover in a report** (sample data: sample)

```sql
SELECT symbol, to_char(sum(close * volume), 'FM999,999,999,990.00') AS turnover
FROM ochl_day
GROUP BY symbol
ORDER BY symbol
LIMIT 3;
```

Result:

| symbol (SYMBOL) | turnover (STRING) |
|---|---|
| CITY | 1,012,051,301.00 |
| COAST | 640,748,179.00 |
| VOLT | 326,540,767.00 |

(3 rows)
