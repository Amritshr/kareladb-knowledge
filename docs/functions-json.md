# JSON functions

> Check, read, build and change JSON values, like company profiles and report numbers.

- Category: Functions — JSON and bytes
- Keywords: JSON, JSONB, json path, $., [last], nested data, document, profile, settings, key, array, object, ->, ->>, @>, <@, ?, ?|, ?&, key exists, GIN, USING GIN, JSON index, jsonpath, SQL/JSON path, jsonb_path_exists, jsonb_path_match, jsonb_path_query, jsonb_path_query_array, jsonb_path_query_first, @?, @@, filter JSON, like_regex, keyvalue, jsonb_pretty, pretty JSON, jsonb_strip_nulls, json_strip_nulls, remove nulls, jsonb_set_lax, jsonb_insert, jsonb_object, array_to_json, get key, change JSON, build JSON, delete key, #-, remove key, JSON to rows, jsonb_each, json_each, jsonb_each_text, jsonb_array_elements, json_array_elements, jsonb_array_elements_text, jsonb_object_keys, json_to_record, json_to_recordset, jsonb_populate_record, jsonb_populate_recordset, bulk insert from JSON
- See also: [Bytes, hex and base64](functions-bytes.md), [Column types](column-types.md), [UPDATE and DELETE](update-delete.md), [Conversion functions](functions-conversion.md), [Text functions](functions-text.md)

JSON is a text format for data with names and lists: `{"branches": 270, "tags": ["bank"]}`.
Some data is different for every row. A bank has branches; a hydropower company has megawatts.
Put such data in a `JSON` column, and read it with the functions on this page.

- A **path** says which part you want: `'$.office.city'` or `'$.tags[0]'` (see [JSON paths](functions-json.md#json-paths)).
- A path that is not in the document gives `NULL`. It is not an error.
- Most functions also take **text** that holds JSON. KDB checks the text first; bad JSON is an error.
- A `NULL` argument gives `NULL` (except `json_object` and `json_array`, which turn `NULL` into JSON `null`).
- The result tables show a JSON value after reading it: a JSON string shows without its quotes, JSON `null` shows as `NULL`, and `2.50` can show as `2.5`. HTTP answers in JSON do the same. To see the exact saved text, add `::STRING` (some examples do).

Every example on this page has two small tables, `companies` and `fundamentals` (open "Setup" under an example to see them).
[Chapter 18](../tutorial/18-content-data.md) of the tutorial shows the same tables step by step.

Setup used by the examples below:

```sql
CREATE TABLE companies (
  symbol STRING PRIMARY KEY,
  name STRING NOT NULL,
  sector STRING NOT NULL,
  profile JSON DEFAULT '{}'
);
INSERT INTO companies VALUES
  ('CITY', 'City Bank Limited', 'Banking',
   '{"website": "https://www.citybank.example.com", "office": {"city": "Kathmandu", "phone": "01-5970015"}, "branches": 270, "tags": ["bank", "A class"]}'),
  ('COAST', 'Coastal Bank Limited', 'Banking',
   '{"website": "https://www.coastalbank.example.com", "office": {"city": "Kathmandu"}, "branches": 380, "tags": ["bank"]}'),
  ('VOLT', 'Volt River Hydropower Limited', 'Energy',
   '{"website": "https://www.voltriver.example.com", "capacity_mw": 456, "rivers": ["Volt River"], "name_ne": "भोल्ट रिभर"}');
CREATE TABLE fundamentals (
  id LONG PRIMARY KEY AUTO,
  symbol STRING NOT NULL,
  fiscal_year STRING NOT NULL,
  quarter INT NOT NULL,
  eps DECIMAL(2),
  extra JSON DEFAULT '{}'
);
INSERT INTO fundamentals (symbol, fiscal_year, quarter, eps, extra) VALUES
  ('CITY', '2082/83', 3, 11.40, '{"npl_pct": 2.75, "car_pct": 13.1, "deposits": 442900000000}'),
  ('CITY', '2082/83', 4, 12.10, '{"npl_pct": 2.60, "car_pct": 13.4, "deposits": 455000000000, "audited": false}'),
  ('COAST', '2082/83', 4, 6.35, '{"npl_pct": 4.10, "car_pct": 12.2}'),
  ('VOLT', '2082/83', 4, 3.20, '{"energy_gwh": 2105.4, "plant_factor_pct": 52.7}');
```

**Example: Read the company profiles**

```sql
SELECT symbol,
       json_value(profile, '$.office.city') AS city,
       profile ->> 'website' AS website,
       json_value(profile, '$.branches') AS branches,
       profile -> 'rivers' ->> 0 AS river
FROM companies
ORDER BY symbol;
```

Result:

| symbol (STRING) | city (STRING) | website (STRING) | branches (LONG) | river (STRING) |
|---|---|---|---|---|
| CITY | Kathmandu | https://www.citybank.example.com | 270 | NULL |
| COAST | Kathmandu | https://www.coastalbank.example.com | 380 | NULL |
| VOLT | NULL | https://www.voltriver.example.com | NULL | Volt River |

(3 rows)

<a id="json-column"></a>

## JSON column type

Syntax:

```sql
column_name JSON [DEFAULT '{}']
column_name JSONB
```

A `JSON` column keeps checked JSON. `JSONB` is another name for the same type. The [column types](column-types.md) topic lists all types.

- **Check:** KDB refuses text that is not valid JSON. The error says the row, the column and the character.
- **Spaces:** spaces between the parts are removed. `{ "a" : 1 }` is saved as `{"a":1}`.
- **Order:** the order of the keys stays. The digits of numbers stay (`2.60` stays `2.60`).
- **Values:** a number, `TRUE` or `FALSE` put into a `JSON` column becomes JSON (`5`, `true`). Text must be JSON text.
- **NULL:** SQL `NULL` is "no value". The JSON text `'null'` is a value: `profile IS NULL` is false for it.
- **Size:** at most 16 MB per value, and at most 256 levels of `{ }` and `[ ]` inside each other.
- **Compare:** two JSON values are equal when their text (without spaces) is equal. So `{"a":1,"b":2}` is **not** equal to `{"b":2,"a":1}`. A JSON number compared with a SQL number is compared by value.
- **Notes:** `ORDER BY`, `min` and `max` on JSON values compare the JSON **text**, so `10` comes before `9`. To sort by a number inside JSON, use `json_value_double(...)` or `json_value(...)`.

**Example: Spaces are removed; SQL NULL and JSON null are different**

Setup:

```sql
CREATE TABLE app_settings (user_id LONG PRIMARY KEY, settings JSON);
INSERT INTO app_settings VALUES
  (1, '{ "theme" : "dark", "lang" : "ne" }'),
  (2, 'null'),
  (3, NULL),
  (4, 5);
```

```sql
SELECT user_id, settings::STRING AS saved_text, settings IS NULL AS is_sql_null, json_type(settings) AS kind
FROM app_settings
ORDER BY user_id;
```

Result:

| user_id (LONG) | saved_text (STRING) | is_sql_null (BOOL) | kind (STRING) |
|---|---|---|---|
| 1 | {"theme":"dark","lang":"ne"} | false | object |
| 2 | null | false | null |
| 3 | NULL | true | NULL |
| 4 | 5 | false | number |

(4 rows)

**Example: Bad JSON is refused** (shows an error)

```sql
INSERT INTO fundamentals (symbol, fiscal_year, quarter, extra)
VALUES ('VOLT', '2082/83', 3, '{"energy_gwh": 1850.2,}');
```

Result:

Error: `column 'extra' (JSON): not valid JSON: a JSON object cannot end with ',' at character 23 (near '}')`

**Example: Most read news: sort by the number, not by the JSON**

Setup:

```sql
CREATE TABLE news (id LONG PRIMARY KEY, title STRING, stats JSON);
INSERT INTO news VALUES
  (1, 'Market index gains 12 points', '{"views": 9}'),
  (2, 'City Bank profit rises 18%', '{"views": 120}'),
  (3, 'Volt River output up', '{"views": 10}');
```

```sql
SELECT id, title, stats -> 'views' AS views FROM news ORDER BY stats -> 'views' DESC;
SELECT id, title, json_value_long(stats, '$.views') AS views FROM news ORDER BY views DESC;
```

Result:

`SELECT id, title, stats -> 'views' AS views FROM news ORDER BY stats -> 'views' DESC`

| id (LONG) | title (STRING) | views (JSON) |
|---|---|---|
| 2 | City Bank profit rises 18% | 120 |
| 3 | Volt River output up | 10 |
| 1 | Market index gains 12 points | 9 |

(3 rows)

`SELECT id, title, json_value_long(stats, '$.views') AS views FROM news ORDER BY views DESC`

| id (LONG) | title (STRING) | views (LONG) |
|---|---|---|
| 2 | City Bank profit rises 18% | 120 |
| 3 | Volt River output up | 10 |
| 1 | Market index gains 12 points | 9 |

(3 rows)

<a id="json-paths"></a>

## JSON paths

Syntax:

```sql
'$'                    the whole document
'$.key'                a key of an object
'$.key.inner'          a key inside a key
'$.list[0]'            element 0 of an array (the first one)
'$.list[-1]'           the last element ([-2] is the one before it)
'$.list[last]'         the last element, too
'$."key with spaces"'  a key with spaces, dots or other signs
'$["key"]'  '$[''key'']'   the same, in brackets
```

A path is text that points to one part of a JSON value. It always starts with `$`. It is used by `json_extract`, `json_value`, `json_set` and the other functions with a `path` argument.

| Part | Meaning |
|---|---|
| `$` | the whole document |
| `.name` | the key `name` of an object |
| `[n]` | element `n` of an array; `0` is the first |
| `[-n]`, `[last]` | counted from the end; `[-1]` and `[last]` are the last element |
| `."..."`, `["..."]`, `['...']` | a key written in quotes |

- **Missing:** a key or element that is not there gives `NULL`. A number on an object, or a key on an array, also gives `NULL`.
- **Notes:** a key written twice in one object: the path finds the **last** one.
- **Not supported:** wildcards (`$.items[*]`, `$.*`), ranges, filters and `..`. They give an error. `[-0]` is an error (the last element is `[-1]`).
  PostgreSQL's full path language, with all of these, is in [jsonb_path_query and @?](functions-json.md#jsonpath).
- A path must be text in quotes. A column or a number in its place is an error.

**Example: Different paths on one company profile**

```sql
SELECT json_extract(profile, '$.office.city') AS city,
       json_extract(profile, '$.tags[0]') AS first_tag,
       json_extract(profile, '$.tags[-1]') AS last_tag,
       json_extract(profile, '$.tags[last]') AS also_last,
       json_extract(profile, '$.tags[5]') AS no_such_tag
FROM companies
WHERE symbol = 'CITY';
```

Result:

| city (JSON) | first_tag (JSON) | last_tag (JSON) | also_last (JSON) | no_such_tag (STRING) |
|---|---|---|---|---|
| "Kathmandu" | "bank" | "A class" | "A class" | NULL |

(1 row)

**Example: Keys with spaces or dots need quotes**

```sql
SELECT json_extract('{"net profit": 3270.1, "q4.audited": true}', '$."net profit"') AS a,
       json_extract('{"net profit": 3270.1, "q4.audited": true}', '$["q4.audited"]') AS b,
       json_extract('{"net profit": 3270.1, "q4.audited": true}', '$.q4.audited') AS without_quotes;
```

Result:

| a (JSON) | b (JSON) | without_quotes (STRING) |
|---|---|---|
| 3270.1 | true | NULL |

(1 row)

**Example: Wildcards are not supported** (shows an error)

```sql
SELECT json_extract(profile, '$.tags[*]') FROM companies;
```

Result:

Error: `line 1, column 8: json_extract: JSON path '$.tags[*]' is not valid: wildcards (*) are not supported (paths look like '$.company.sector', '$.items[0]' or '$."key with spaces"')`

**Example: A path must start with $** (shows an error)

```sql
SELECT json_extract(profile, 'office.city') FROM companies;
```

Result:

Error: `line 1, column 8: json_extract: JSON path 'office.city' is not valid: it must start with $ (paths look like '$.company.sector', '$.items[0]' or '$."key with spaces"')`

## json

Syntax:

```sql
json(text)
```

Checks that `text` is valid JSON and gives it as a `JSON` value, without extra spaces. `CAST(text AS JSON)` and `text::JSON` do the same.

| Argument | Type | Meaning |
|---|---|---|
| `text` | `STRING` (or `JSON`) | JSON text, like `'{"a": 1}'` |

- **Returns:** `JSON`.
- **NULL:** `json(NULL)` is `NULL`. `json('null')` is the JSON value `null`.
- **Notes:** bad JSON is an error that says what is wrong and at which character. Keys and strings need double quotes (`"a"`), and `true`, `false`, `null` are lower case.
- Use `json(...)` when you put JSON **inside** other JSON with `json_object`, `json_array` or `json_set`. Without it, the text is saved as a JSON string.

**Example**

```sql
SELECT json('{ "symbol" : "CITY", "close" : 512.50 }')::STRING AS saved_text,
       json('[1, 2, 3]') AS list,
       CAST('{"a": 1}' AS JSON) AS with_cast,
       json('{"name_ne": "सिटी बैंक"}') AS nepali;
```

Result:

| saved_text (STRING) | list (JSON) | with_cast (JSON) | nepali (JSON) |
|---|---|---|---|
| {"symbol":"CITY","close":512.50} | [1,2,3] | {"a":1} | {"name_ne":"सिटी बैंक"} |

(1 row)

**Example: Single quotes are not JSON** (shows an error)

```sql
SELECT json('{''symbol'': ''CITY''}');
```

Result:

Error: `line 1, column 8: json: argument 1 is not valid JSON: expected a key in double quotes at character 2 (near ''symbol': 'C...')`

**Example: true, false and null are lower case** (shows an error)

```sql
SELECT json('{"listed": TRUE}');
```

Result:

Error: `line 1, column 8: json: argument 1 is not valid JSON: expected a JSON value (true, false and null are lower case) at character 12 (near 'TRUE}')`

## to_json

Syntax:

```sql
to_json(value)
```

Turns one SQL value into JSON. Text becomes a JSON string with `"` around it. Numbers and `TRUE`/`FALSE` stay as they are.

| Argument | Type | Meaning |
|---|---|---|
| `value` | any type | the value to turn into JSON |

- **Returns:** `JSON`.
- **NULL:** `to_json(NULL)` is SQL `NULL` (not JSON `null`).
- **Notes:** a `DECIMAL` keeps its digits (`2.50`); a `DOUBLE` does not (`2.5`). A time becomes a string like `"2026-09-10T05:15:00.000Z"`. A `JSON` value stays the same. `BYTES` become a string like `"\\x0a0b"`.
- `to_json('{"a": 1}')` gives a JSON **string**, not an object. Use `json(...)` to read JSON text.

**Example**

```sql
SELECT to_json('City "Bank"')::STRING AS text_value,
       to_json(512.50)::STRING AS double_value,
       to_json(CAST(2.50 AS DECIMAL(2)))::STRING AS exact,
       to_json(TRUE)::STRING AS yes,
       to_json(CAST('2026-09-10T05:15:00Z' AS TIMESTAMP))::STRING AS time_value,
       to_json('{"a": 1}')::STRING AS still_text;
```

Result:

| text_value (STRING) | double_value (STRING) | exact (STRING) | yes (STRING) | time_value (STRING) | still_text (STRING) |
|---|---|---|---|---|---|
| "City \\"Bank\\"" | 512.5 | 2.50 | true | "2026-09-10T05:15:00.000Z" | "{\\"a\\": 1}" |

(1 row)

## json_valid

Syntax:

```sql
json_valid(text)
```

`true` when `text` is valid JSON, else `false`. It never gives an error, so it is good for checking data before you insert it.

| Argument | Type | Meaning |
|---|---|---|
| `text` | `STRING` (or any value) | the text to check |

- **Returns:** `BOOL`.
- **NULL:** `json_valid(NULL)` is `NULL`.
- **Notes:** a number, `TRUE` or a `JSON` value is valid. `BYTES` are never valid. Empty text is not valid.

**Example**

```sql
SELECT json_valid('{"npl_pct": 2.75}') AS good,
       json_valid('{"npl_pct": 2.75,}') AS extra_comma,
       json_valid('{npl_pct: 2.75}') AS no_quotes,
       json_valid('') AS empty,
       json_valid(NULL) AS nothing;
```

Result:

| good (BOOL) | extra_comma (BOOL) | no_quotes (BOOL) | empty (BOOL) | nothing (STRING) |
|---|---|---|---|---|
| true | false | false | false | NULL |

(1 row)

**Example: Find bad rows in imported text before loading them**

Setup:

```sql
CREATE TABLE import_raw (line_no LONG PRIMARY KEY, symbol STRING, extra_text STRING);
INSERT INTO import_raw VALUES
  (1, 'CITY', '{"npl_pct": 2.91}'),
  (2, 'COAST', '{"npl_pct": 4.3,}'),
  (3, 'VOLT', '{"energy_gwh": 1850.2}');
```

```sql
SELECT line_no, symbol, extra_text
FROM import_raw
WHERE NOT json_valid(extra_text);
```

Result:

| line_no (LONG) | symbol (STRING) | extra_text (STRING) |
|---|---|---|
| 2 | COAST | {"npl_pct": 4.3,} |

(1 row)

## json_extract

Syntax:

```sql
json_extract(doc, path)
```

The part of `doc` at `path`, as JSON. A string stays in quotes (`"Kathmandu"`), and objects and arrays stay whole.

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document |
| `path` | `STRING` | a [JSON path](functions-json.md#json-paths) like `'$.office.city'` |

- **Returns:** `JSON`.
- **NULL:** `NULL` when an argument is `NULL`, or the path is not in the document.
- **Notes:** `doc -> 'key'` is a short way to write `json_extract(doc, '$.key')` (see [->, ->>](functions-json.md#arrow)). To get a plain SQL value (text without quotes, a number), use `json_value`.

**Example**

```sql
SELECT symbol,
       json_extract(profile, '$.office') AS office,
       json_extract(profile, '$.office.city')::STRING AS city_json_text,
       json_value(profile, '$.office.city') AS city_value,
       json_extract(profile, '$.tags') AS tags
FROM companies
ORDER BY symbol;
```

Result:

| symbol (STRING) | office (JSON) | city_json_text (STRING) | city_value (STRING) | tags (JSON) |
|---|---|---|---|---|
| CITY | {"city":"Kathmandu","phone":"01-5970015"} | "Kathmandu" | Kathmandu | ["bank","A class"] |
| COAST | {"city":"Kathmandu"} | "Kathmandu" | Kathmandu | ["bank"] |
| VOLT | NULL | NULL | NULL | NULL |

(3 rows)

**Example: The text must be valid JSON** (shows an error)

```sql
SELECT json_extract('CITY', '$.a');
```

Result:

Error: `line 1, column 8: json_extract: argument 1 is not valid JSON: expected a JSON value (an object, array, string, number, true, false or null) at character 1 (near 'CITY')`

## json_value

Syntax:

```sql
json_value(doc, path)
```

The part of `doc` at `path` as a normal SQL value. The type depends on the JSON value:

| JSON value | SQL result |
|---|---|
| `"text"` | `STRING` without quotes |
| a whole number like `270` | `LONG` |
| a number with a point or `e`, like `2.60` | `DOUBLE` (`2.6`) |
| `true`, `false` | `BOOL` |
| `null`, an object, an array | `NULL` |

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document |
| `path` | `STRING` | a [JSON path](functions-json.md#json-paths) |

- **Returns:** `STRING`, `LONG`, `DOUBLE` or `BOOL`; `NULL` when the path is missing.
- **NULL:** `NULL` when an argument is `NULL`.
- **Notes:** a whole number too big for `LONG` comes back as `DOUBLE`. The result type can change from row to row. When you need one type, use `json_value_text`, `json_value_double`, `json_value_long` or `json_value_bool`.
- A `DOUBLE` is not exact. For money, take the text and cast it: `CAST(json_value_text(doc, '$.price') AS DECIMAL(2))`.

**Example**

```sql
SELECT json_value(profile, '$.office.city') AS city,
       json_value(profile, '$.branches') AS branches,
       json_value(profile, '$.tags') AS tags_is_array,
       json_value(profile, '$.no_such_key') AS missing
FROM companies
WHERE symbol = 'CITY';
```

Result:

| city (STRING) | branches (LONG) | tags_is_array (STRING) | missing (STRING) |
|---|---|---|---|
| Kathmandu | 270 | NULL | NULL |

(1 row)

**Example: Banks with bad loans (NPL) above 3 percent**

```sql
SELECT f.symbol, c.name, json_value(f.extra, '$.npl_pct') AS npl_pct
FROM fundamentals f
JOIN companies c ON c.symbol = f.symbol
WHERE f.quarter = 4 AND json_value(f.extra, '$.npl_pct') > 3;
```

Result:

| symbol (STRING) | name (STRING) | npl_pct (DOUBLE) |
|---|---|---|
| COAST | Coastal Bank Limited | 4.1 |

(1 row)

**Example: Nepali text inside JSON: letters count as one**

```sql
SELECT json_value(profile, '$.name_ne') AS name_ne,
       length(json_value(profile, '$.name_ne')) AS letters
FROM companies
WHERE symbol = 'VOLT';
```

Result:

| name_ne (STRING) | letters (LONG) |
|---|---|
| भोल्ट रिभर | 10 |

(1 row)

## json_value_text

Syntax:

```sql
json_value_text(doc, path)
```

The part at `path` always as text. A JSON string comes without quotes. A number keeps its digits as written (`2.60`). An object or array comes as its JSON text.

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document |
| `path` | `STRING` | a [JSON path](functions-json.md#json-paths) |

- **Returns:** `STRING`.
- **NULL:** `NULL` when an argument is `NULL`, the path is missing, or the value is JSON `null`.
- **Notes:** this is the safe way to read exact numbers: `CAST(json_value_text(...) AS DECIMAL(2))`. `doc ->> 'key'` gives the same text for one key.

**Example: Exact percent values for a report**

```sql
SELECT symbol, quarter,
       json_value_text(extra, '$.car_pct') AS car_text,
       CAST(json_value_text(extra, '$.npl_pct') AS DECIMAL(2)) AS npl_exact,
       json_value(extra, '$.npl_pct') AS npl_double
FROM fundamentals
WHERE symbol IN ('CITY', 'COAST')
ORDER BY symbol, quarter;
```

Result:

| symbol (STRING) | quarter (INT) | car_text (STRING) | npl_exact (DECIMAL(2)) | npl_double (DOUBLE) |
|---|---|---|---|---|
| CITY | 3 | 13.1 | 2.75 | 2.75 |
| CITY | 4 | 13.4 | 2.60 | 2.6 |
| COAST | 4 | 12.2 | 4.10 | 4.1 |

(3 rows)

**Example**

```sql
SELECT json_value_text(profile, '$.office') AS office_json,
       json_value_text(profile, '$.branches') AS branches_text
FROM companies
WHERE symbol = 'CITY';
```

Result:

| office_json (STRING) | branches_text (STRING) |
|---|---|
| {"city":"Kathmandu","phone":"01-5970015"} | 270 |

(1 row)

## json_value_double

Syntax:

```sql
json_value_double(doc, path)
```

The part at `path` as a `DOUBLE` number. A JSON number works, and so does a JSON string that holds a number (`"12.5"`).

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document |
| `path` | `STRING` | a [JSON path](functions-json.md#json-paths) |

- **Returns:** `DOUBLE`.
- **NULL:** `NULL` when an argument is `NULL`, the path is missing, or the value is not a number (`"abc"`, `true`, an object).
- **Notes:** it never gives an error for a wrong value, so it is safe in `WHERE` and `ORDER BY`.

**Example**

```sql
SELECT json_value_double('{"close": 512.5}', '$.close') AS number,
       json_value_double('{"close": "512.5"}', '$.close') AS number_in_text,
       json_value_double('{"close": "n/a"}', '$.close') AS not_a_number,
       json_value_double('{"close": true}', '$.close') AS bool_value;
```

Result:

| number (DOUBLE) | number_in_text (DOUBLE) | not_a_number (STRING) | bool_value (STRING) |
|---|---|---|---|
| 512.5 | 512.5 | NULL | NULL |

(1 row)

**Example: Hydropower plants with a plant factor above 50 percent**

```sql
SELECT symbol, json_value_double(extra, '$.plant_factor_pct') AS plant_factor
FROM fundamentals
WHERE json_value_double(extra, '$.plant_factor_pct') > 50;
```

Result:

| symbol (STRING) | plant_factor (DOUBLE) |
|---|---|
| VOLT | 52.7 |

(1 row)

## json_value_long

Syntax:

```sql
json_value_long(doc, path)
```

The part at `path` as a `LONG` (a whole number). `12` and `12.0` work, and so does a string like `"42"`. `12.5` does not fit and gives `NULL`.

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document |
| `path` | `STRING` | a [JSON path](functions-json.md#json-paths) |

- **Returns:** `LONG`.
- **NULL:** `NULL` when an argument is `NULL`, the path is missing, or the value is not a whole number (or too big for `LONG`).

**Example**

```sql
SELECT json_value_long('{"branches": 270}', '$.branches') AS a,
       json_value_long('{"branches": 270.0}', '$.branches') AS b,
       json_value_long('{"branches": "270"}', '$.branches') AS c,
       json_value_long('{"branches": 270.5}', '$.branches') AS d,
       json_value_long('{"branches": 99999999999999999999}', '$.branches') AS too_big;
```

Result:

| a (LONG) | b (LONG) | c (LONG) | d (STRING) | too_big (STRING) |
|---|---|---|---|---|
| 270 | 270 | 270 | NULL | NULL |

(1 row)

**Example: Total branches of all banks**

```sql
SELECT sum(json_value_long(profile, '$.branches')) AS branches
FROM companies
WHERE sector = 'Banking';
```

Result:

| branches (LONG) |
|---|
| 650 |

(1 row)

## json_value_bool

Syntax:

```sql
json_value_bool(doc, path)
```

The part at `path` as `BOOL`. JSON `true` and `false` work, and so do the strings `"true"` and `"false"`.

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document |
| `path` | `STRING` | a [JSON path](functions-json.md#json-paths) |

- **Returns:** `BOOL`.
- **NULL:** `NULL` when an argument is `NULL`, the path is missing, or the value is something else (`1`, `"yes"`, an object).

**Example**

```sql
SELECT json_value_bool('{"audited": true}', '$.audited') AS a,
       json_value_bool('{"audited": "false"}', '$.audited') AS b,
       json_value_bool('{"audited": 1}', '$.audited') AS c,
       json_value_bool('{"audited": "yes"}', '$.audited') AS d;
```

Result:

| a (BOOL) | b (BOOL) | c (STRING) | d (STRING) |
|---|---|---|---|
| true | false | NULL | NULL |

(1 row)

**Example: Quarter results that are not audited yet**

```sql
SELECT symbol, fiscal_year, quarter
FROM fundamentals
WHERE json_value_bool(extra, '$.audited') = FALSE;
```

Result:

| symbol (STRING) | fiscal_year (STRING) | quarter (INT) |
|---|---|---|
| CITY | 2082/83 | 4 |

(1 row)

## json_type

Syntax:

```sql
json_type(doc)
json_type(doc, path)
```

The kind of JSON value: `object`, `array`, `string`, `number`, `boolean` or `null`.

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document |
| `path` | `STRING` | optional [JSON path](functions-json.md#json-paths); default `'$'` (the whole document) |

- **Returns:** `STRING`.
- **NULL:** SQL `NULL` when an argument is `NULL` or the path is missing. For a JSON `null` value it gives the text `'null'`.
- **Notes:** use it to tell "the key is missing" (`NULL`) from "the key is there with `null`" (`'null'`).

**Example**

```sql
SELECT json_type(profile) AS whole,
       json_type(profile, '$.office') AS office,
       json_type(profile, '$.tags') AS tags,
       json_type(profile, '$.branches') AS branches,
       json_type(profile, '$.website') AS website,
       json_type(profile, '$.capacity_mw') AS missing
FROM companies
WHERE symbol = 'CITY';
```

Result:

| whole (STRING) | office (STRING) | tags (STRING) | branches (STRING) | website (STRING) | missing (STRING) |
|---|---|---|---|---|---|
| object | object | array | number | string | NULL |

(1 row)

**Example: Which quarters have the audited key at all**

```sql
SELECT symbol, quarter, json_type(extra, '$.audited') AS audited_type
FROM fundamentals
ORDER BY symbol, quarter;
```

Result:

| symbol (STRING) | quarter (INT) | audited_type (STRING) |
|---|---|---|
| CITY | 3 | NULL |
| CITY | 4 | boolean |
| COAST | 4 | NULL |
| VOLT | 4 | NULL |

(4 rows)

## json_array_length

Syntax:

```sql
json_array_length(doc)
json_array_length(doc, path)
```

The number of elements in a JSON array. Elements inside inner arrays are not counted.

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document |
| `path` | `STRING` | optional [JSON path](functions-json.md#json-paths) to the array; default `'$'` |

- **Returns:** `LONG`.
- **NULL:** `NULL` when an argument is `NULL`, the path is missing, or the value is not an array.

**Example**

```sql
SELECT symbol,
       json_array_length(profile, '$.tags') AS tags,
       json_array_length(profile, '$.rivers') AS rivers
FROM companies
ORDER BY symbol;
```

Result:

| symbol (STRING) | tags (LONG) | rivers (LONG) |
|---|---|---|
| CITY | 2 | NULL |
| COAST | 1 | NULL |
| VOLT | NULL | 1 |

(3 rows)

**Example**

```sql
SELECT json_array_length('[1, [2, 3], {"a": [4]}]') AS top_level_only,
       json_array_length('[]') AS empty,
       json_array_length('{"a": 1}') AS not_an_array;
```

Result:

| top_level_only (LONG) | empty (LONG) | not_an_array (STRING) |
|---|---|---|
| 3 | 0 | NULL |

(1 row)

## json_keys

Syntax:

```sql
json_keys(doc)
json_keys(doc, path)
```

The keys of a JSON object, as a JSON array of strings, in the order they are written.

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document |
| `path` | `STRING` | optional [JSON path](functions-json.md#json-paths) to the object; default `'$'` |

- **Returns:** `JSON` (an array).
- **NULL:** `NULL` when an argument is `NULL`, the path is missing, or the value is not an object.
- **Notes:** a key written twice is listed once.

**Example: Which extra numbers each company reports**

```sql
SELECT symbol, quarter, json_keys(extra) AS keys
FROM fundamentals
ORDER BY symbol, quarter;
```

Result:

| symbol (STRING) | quarter (INT) | keys (JSON) |
|---|---|---|
| CITY | 3 | ["npl_pct","car_pct","deposits"] |
| CITY | 4 | ["npl_pct","car_pct","deposits","audited"] |
| COAST | 4 | ["npl_pct","car_pct"] |
| VOLT | 4 | ["energy_gwh","plant_factor_pct"] |

(4 rows)

**Example**

```sql
SELECT json_keys(profile, '$.office') AS office_keys,
       json_array_length(json_keys(profile)) AS number_of_keys
FROM companies
WHERE symbol = 'CITY';
```

Result:

| office_keys (JSON) | number_of_keys (LONG) |
|---|---|
| ["city","phone"] | 4 |

(1 row)

## json_object

Syntax:

```sql
json_object(key, value [, key, value ...])
```

Builds a JSON object from pairs of key and value. Text values become JSON strings; numbers, `TRUE`/`FALSE` and `JSON` values are put in as they are.

| Argument | Type | Meaning |
|---|---|---|
| `key` | `STRING` | the name of the key (a number is turned into text) |
| `value` | any type | the value; `NULL` becomes JSON `null` |

- **Returns:** `JSON`. `json_object()` with no arguments is `{}`.
- **NULL:** a `NULL` value becomes `null`. A `NULL` key is an error.
- **Notes:** an odd number of arguments is an error. When a key is written twice, the last value wins. At most 64 arguments.
- To put JSON inside, pass a `JSON` value (a JSON column, or `json('...')`). Plain text like `'["bank"]'` becomes a string.

**Example: A JSON answer for an app, made from table columns**

```sql
SELECT json_object('symbol', symbol,
                   'name', name,
                   'city', json_value(profile, '$.office.city'),
                   'tags', profile -> 'tags',
                   'listed', TRUE) AS api_answer
FROM companies
WHERE symbol = 'COAST';
```

Result:

| api_answer (JSON) |
|---|
| {"symbol":"COAST","name":"Coastal Bank Limited","city":"Kathmandu","tags":["bank"],"listed":true} |

(1 row)

**Example: Text is not JSON until you use json()**

```sql
SELECT json_object('tags', '["bank"]') AS as_text,
       json_object('tags', json('["bank"]')) AS as_json,
       json_object('note', NULL, 'note', 'second') AS last_wins;
```

Result:

| as_text (JSON) | as_json (JSON) | last_wins (JSON) |
|---|---|---|
| {"tags":"[\\"bank\\"]"} | {"tags":["bank"]} | {"note":"second"} |

(1 row)

**Example: Keys and values must come in pairs** (shows an error)

```sql
SELECT json_object('symbol', 'CITY', 'price');
```

Result:

Error: `line 1, column 8: json_object: needs pairs of key and value, like json_object('symbol', 'CITY', 'price', 512.5)`

## json_array

Syntax:

```sql
json_array([value, value ...])
```

Builds a JSON array from the values, in order.

| Argument | Type | Meaning |
|---|---|---|
| `value` | any type | an element; `NULL` becomes JSON `null` |

- **Returns:** `JSON`. `json_array()` with no arguments is `[]`.
- **NULL:** a `NULL` value becomes `null`.
- **Notes:** text becomes a JSON string; use `json('...')` to put an object or array inside. At most 64 values.

**Example**

```sql
SELECT json_array('CITY', 512.5, TRUE, NULL) AS mixed,
       json_array(json('{"q": 3}'), json('{"q": 4}')) AS objects,
       json_array() AS empty;
```

Result:

| mixed (JSON) | objects (JSON) | empty (JSON) |
|---|---|---|
| ["CITY",512.5,true,null] | [{"q":3},{"q":4}] | [] |

(1 row)

**Example: Open, high, low and close of one day as a small array** (sample data: sample)

```sql
SELECT time, json_array(open, high, low, close) AS ohlc
FROM ochl_day
WHERE symbol = 'CITY'
LIMIT 3;
```

Result:

| time (TIMESTAMP) | ohlc (JSON) |
|---|---|
| 2025-12-28T00:00:00.000Z | [540.3,542.5,539.2,542.2] |
| 2025-12-29T00:00:00.000Z | [540.6,542.1,538.8,539.7] |
| 2025-12-30T00:00:00.000Z | [538.5,540.5,536.4,539.3] |

(3 rows)

## json_set

Syntax:

```sql
json_set(doc, path, value [, path, value ...])
```

Changes `doc`: puts `value` at `path`. A key that is there gets the new value; a key that is not there is added. The other keys stay. Use it in `UPDATE`.

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document to change |
| `path` | `STRING` | a [JSON path](functions-json.md#json-paths) |
| `value` | any type | the new value (text becomes a JSON string; use `json('...')` for JSON) |

- **Returns:** `JSON` (the changed document; the table is changed only by `UPDATE`).
- **NULL:** `NULL` when `doc` or a `path` is `NULL`. A `NULL` value puts JSON `null`.
- **Notes:** when the parent of the path is not there (`$.a.b` without `a`), nothing changes and there is no error. An array index after the end (`$.tags[9]`) adds at the end. More pairs are done one after the other.
- **Differences:** works like `JSON_SET` in MySQL. PostgreSQL's `jsonb_set` is different (paths like `'{a,b}'`).

**Example: Mark a quarter as audited and add the auditor**

Setup:

```sql
UPDATE fundamentals
SET extra = json_set(extra, '$.audited', TRUE, '$.auditor', 'CA firm A')
WHERE symbol = 'CITY' AND quarter = 4;
```

```sql
SELECT extra::STRING AS extra FROM fundamentals WHERE symbol = 'CITY' AND quarter = 4;
```

Result:

| extra (STRING) |
|---|
| {"npl_pct":2.60,"car_pct":13.4,"deposits":455000000000,"audited":true,"auditor":"CA firm A"} |

(1 row)

**Example: Change, add, and a missing parent**

```sql
SELECT json_set('{"theme": "light"}', '$.theme', 'dark') AS changed,
       json_set('{"theme": "light"}', '$.lang', 'ne') AS added,
       json_set('{"theme": "light"}', '$.notify.email', FALSE) AS no_parent,
       json_set('{"tags": ["bank"]}', '$.tags[9]', 'A class') AS array_end;
```

Result:

| changed (JSON) | added (JSON) | no_parent (JSON) | array_end (JSON) |
|---|---|---|---|
| {"theme":"dark"} | {"theme":"light","lang":"ne"} | {"theme":"light"} | {"tags":["bank","A class"]} |

(1 row)

**Example: Paths and values must come in pairs** (shows an error)

```sql
SELECT json_set('{"a": 1}', '$.a', 2, '$.b');
```

Result:

Error: `line 1, column 8: json_set: needs pairs of path and value after the document, like json_set(doc, '$.price', 512.5)`

## json_insert

Syntax:

```sql
json_insert(doc, path, value [, path, value ...])
```

Like `json_set`, but it only **adds**. A key or array element that is already there keeps its old value.

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document to change |
| `path` | `STRING` | a [JSON path](functions-json.md#json-paths) |
| `value` | any type | the value to add |

- **Returns:** `JSON`.
- **NULL:** `NULL` when `doc` or a `path` is `NULL`. A `NULL` value adds JSON `null`.
- **Notes:** good for default values: "set it only when it is not set yet".

**Example: Add a default language, but do not change a user's choice**

```sql
SELECT json_insert('{"theme": "dark"}', '$.lang', 'en') AS new_key,
       json_insert('{"theme": "dark", "lang": "ne"}', '$.lang', 'en') AS kept,
       json_insert('{"tags": ["bank"]}', '$.tags[1]', 'A class') AS array_end;
```

Result:

| new_key (JSON) | kept (JSON) | array_end (JSON) |
|---|---|---|
| {"theme":"dark","lang":"en"} | {"theme":"dark","lang":"ne"} | {"tags":["bank","A class"]} |

(1 row)

## json_replace

Syntax:

```sql
json_replace(doc, path, value [, path, value ...])
```

Like `json_set`, but it only **changes** what is there. A missing key is not added.

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document to change |
| `path` | `STRING` | a [JSON path](functions-json.md#json-paths) |
| `value` | any type | the new value |

- **Returns:** `JSON`.
- **NULL:** `NULL` when `doc` or a `path` is `NULL`. A `NULL` value puts JSON `null`.

**Example**

```sql
SELECT json_replace('{"branches": 270}', '$.branches', 272) AS changed,
       json_replace('{"branches": 270}', '$.atms', 400) AS not_added;
```

Result:

| changed (JSON) | not_added (JSON) |
|---|---|
| {"branches":272} | {"branches":270} |

(1 row)

**Example: Update the phone only for companies that have one**

Setup:

```sql
UPDATE companies
SET profile = json_replace(profile, '$.office.phone', '01-5970099');
```

```sql
SELECT symbol, profile -> 'office' AS office FROM companies ORDER BY symbol;
```

Result:

| symbol (STRING) | office (JSON) |
|---|---|
| CITY | {"city":"Kathmandu","phone":"01-5970099"} |
| COAST | {"city":"Kathmandu"} |
| VOLT | NULL |

(3 rows)

## json_remove

Syntax:

```sql
json_remove(doc, path [, path ...])
```

Removes the keys or array elements at the paths.

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document to change |
| `path` | `STRING` | a [JSON path](functions-json.md#json-paths); up to 63 paths |

- **Returns:** `JSON`.
- **NULL:** `NULL` when `doc` or a `path` is `NULL`.
- **Notes:** a path that is not there changes nothing. Paths are done one after the other, so after removing `[0]` the next element becomes `[0]`. Removing `'$'` (the whole document) is an error.

**Example**

```sql
SELECT json_remove('{"npl_pct": 2.6, "car_pct": 13.4, "draft": true}', '$.draft') AS one_key,
       json_remove('{"tags": ["bank", "old", "A class"]}', '$.tags[1]') AS one_element,
       json_remove('{"a": 1}', '$.no_such_key') AS nothing_to_remove;
```

Result:

| one_key (JSON) | one_element (JSON) | nothing_to_remove (JSON) |
|---|---|---|
| {"npl_pct":2.6,"car_pct":13.4} | {"tags":["bank","A class"]} | {"a":1} |

(1 row)

**Example: Remove a key from every row**

Setup:

```sql
UPDATE fundamentals SET extra = json_remove(extra, '$.deposits');
```

```sql
SELECT symbol, quarter, extra::STRING AS extra FROM fundamentals ORDER BY symbol, quarter;
```

Result:

| symbol (STRING) | quarter (INT) | extra (STRING) |
|---|---|---|
| CITY | 3 | {"npl_pct":2.75,"car_pct":13.1} |
| CITY | 4 | {"npl_pct":2.60,"car_pct":13.4,"audited":false} |
| COAST | 4 | {"npl_pct":4.10,"car_pct":12.2} |
| VOLT | 4 | {"energy_gwh":2105.4,"plant_factor_pct":52.7} |

(4 rows)

**Example: The whole document cannot be removed** (shows an error)

```sql
SELECT json_remove('{"a": 1}', '$');
```

Result:

Error: `line 1, column 8: json_remove: cannot remove the whole JSON document ($)`

## json_array_append

Syntax:

```sql
json_array_append(doc, path, value)
```

Adds `value` at the end of the array at `path`.

| Argument | Type | Meaning |
|---|---|---|
| `doc` | `JSON` or JSON text | the document to change |
| `path` | `STRING` | a [JSON path](functions-json.md#json-paths) to an array (`'$'` when `doc` itself is the array) |
| `value` | any type | the new element; use `json('...')` to add an object or array |

- **Returns:** `JSON`.
- **NULL:** `NULL` when `doc` or `path` is `NULL`. A `NULL` value adds JSON `null`.
- **Notes:** exactly one path and one value. When the path is missing or is not an array, nothing changes (MySQL would make an array; KDB does not).

**Example: Add a tag to a company**

Setup:

```sql
UPDATE companies
SET profile = json_array_append(profile, '$.tags', 'dividend 2082/83')
WHERE symbol = 'CITY';
```

```sql
SELECT profile -> 'tags' AS tags FROM companies WHERE symbol = 'CITY';
```

Result:

| tags (JSON) |
|---|
| ["bank","A class","dividend 2082/83"] |

(1 row)

**Example**

```sql
SELECT json_array_append('[1, 2]', '$', 3) AS number,
       json_array_append('[1, 2]', '$', json('[3, 4]')) AS inner_array,
       json_array_append('{"tags": "bank"}', '$.tags', 'x') AS not_an_array;
```

Result:

| number (JSON) | inner_array (JSON) | not_an_array (JSON) |
|---|---|---|
| [1,2,3] | [1,2,[3,4]] | {"tags":"bank"} |

(1 row)

<a id="arrow"></a>

## ->, ->>

Syntax:

```sql
doc -> 'key'      doc -> 0      doc -> -1
doc ->> 'key'     doc ->> 0
doc -> 'a' -> 'b' ->> 0
```

Short ways to take one step into JSON. `->` gives the part as `JSON`. `->>` gives it as text: a string without quotes, other values as their JSON text.

| Right side | Meaning |
|---|---|
| `'key'` | the key of an object |
| `0`, `1`, ... | an element of an array (`0` is the first) |
| `-1`, `-2`, ... | counted from the end (`-1` is the last) |

- **Returns:** `->` gives `JSON`; `->>` gives `STRING`.
- **NULL:** `NULL` when either side is `NULL`, or the key or element is not there. `->>` on JSON `null` gives `NULL`.
- **Notes:** each arrow takes **one** step. `doc -> 'office.city'` looks for a key named `office.city`, and `doc -> '$.office'` looks for a key named `$.office`: both give `NULL`. Chain arrows, or use a [path](functions-json.md#json-paths) function.
- The left side can be a `JSON` value or text that holds JSON (bad JSON is an error).
- The result of `->>` is text, so `doc ->> 'n' + 1` is an error. Use `CAST(doc ->> 'n' AS LONG)`, or `json_value(...)`.
- **Differences:** the same as PostgreSQL for one step. MySQL's `->` takes a path (`doc -> '$.a'`); KDB's does not. The PostgreSQL operators `#>` and `#>>` take a whole path at once and work too: `profile #> '{office,city}'` is [json_extract_path](functions-json.md#json_extract_path) and `#>>` is [json_extract_path_text](functions-json.md#json_extract_path_text). The key tests `?`, `?|`, `?&` and the containment tests `@>`, `<@` are in [the next section](functions-json.md#contains).
- **Speed:** `doc ->> 'key' = 'text'` (also `<>`, `<`, `IN (...)`) in a `WHERE` is read straight from the stored JSON of each row, without building the row first. A [GIN index](functions-json.md#gin) makes it faster still when few rows match.

**Example: Company website, city and first tag**

```sql
SELECT symbol,
       profile ->> 'website' AS website,
       profile -> 'office' ->> 'city' AS city,
       CAST(profile -> 'tags' -> 0 AS STRING) AS first_tag_json,
       profile -> 'tags' ->> -1 AS last_tag_text
FROM companies
ORDER BY symbol;
```

Result:

| symbol (STRING) | website (STRING) | city (STRING) | first_tag_json (STRING) | last_tag_text (STRING) |
|---|---|---|---|---|
| CITY | https://www.citybank.example.com | Kathmandu | "bank" | A class |
| COAST | https://www.coastalbank.example.com | Kathmandu | "bank" | bank |
| VOLT | https://www.voltriver.example.com | NULL | NULL | NULL |

(3 rows)

**Example: One step at a time**

```sql
SELECT profile -> 'office' -> 'city' AS chained,
       profile -> 'office.city' AS dotted_key,
       profile -> '$.office' AS path_text
FROM companies
WHERE symbol = 'CITY';
```

Result:

| chained (JSON) | dotted_key (STRING) | path_text (STRING) |
|---|---|---|
| "Kathmandu" | NULL | NULL |

(1 row)

**Example: Filter and group by a JSON key**

```sql
SELECT profile -> 'office' ->> 'city' AS city, count(*) AS companies
FROM companies
GROUP BY profile -> 'office' ->> 'city'
ORDER BY city;
```

Result:

| city (STRING) | companies (LONG) |
|---|---|
| Kathmandu | 2 |
| NULL | 1 |

(2 rows)

**Example: ->> gives text: cast it before you calculate** (shows an error)

```sql
SELECT profile ->> 'branches' + 10 FROM companies WHERE symbol = 'CITY';
```

Result:

Error: `line 1, column 31: '270' and '10' are not both numbers`

<a id="contains"></a>

## @>, <@, ?, ?|, ?&

Syntax:

```sql
doc @> '{"key": value}'      doc holds all of this
'{"key": value}' <@ doc      the same, the other way round
doc ? 'key'                  doc has this top-level key
doc ?| ARRAY['a', 'b']       doc has at least one of these keys
doc ?& ARRAY['a', 'b']       doc has all of these keys
```

The PostgreSQL `jsonb` tests. Each gives `TRUE` or `FALSE`, so they go in a `WHERE`.

| Test | True when |
|---|---|
| `a @> b` | every key of `b` is in `a` with a value that holds `b`'s value, at every level. A list in `b` is held when each of its elements is in `a`'s list, in any order. |
| `a <@ b` | `b @> a` |
| `doc ? 'k'` | an object with the key `k` at the top, a list with the string `"k"`, or the string `"k"` |
| `doc ?\| keys` | `doc ? k` for at least one `k` of the array |
| `doc ?& keys` | `doc ? k` for every `k` of the array (an empty array: always) |

- **Numbers** compare by value: `{"n": 1}` holds `{"n": 1.0}`. A string never equals a number: `{"n": 1}` does not hold `{"n": "1"}`.
- **Lists:** `[1, 2, [1, 3]] @> [1, 3]` is false (the 3 is only inside the inner list); `@> [[1, 3]]` is true. At the top, a list holds a single value: `'["a", "b"]' @> '"a"'`.
- `?` looks at the **top level** only: `'{"a": {"b": 1}}' ? 'b'` is false.
- The keys of `?|` and `?&` are a text array: `ARRAY['a', 'b']` or `'{a,b}'`.
- **NULL:** `NULL` when either side is `NULL`.
- On two arrays, `@>` and `<@` work as before: `ARRAY[1, 2, 3] @> ARRAY[3, 1]`.
- **Speed:** a [GIN index](functions-json.md#gin) on the column finds the rows without reading every document.

**Example: Banks with an A class tag, and companies with a capacity**

```sql
SELECT symbol FROM companies WHERE profile @> '{"tags": ["A class"]}';
SELECT symbol FROM companies WHERE profile @> '{"office": {"city": "Kathmandu"}}' ORDER BY symbol;
SELECT symbol FROM companies WHERE profile ? 'capacity_mw';
```

Result:

`SELECT symbol FROM companies WHERE profile @> '{"tags": ["A class"]}'`

| symbol (STRING) |
|---|
| CITY |

(1 row)

`SELECT symbol FROM companies WHERE profile @> '{"office": {"city": "Kathmandu"}}' ORDER BY symbol`

| symbol (STRING) |
|---|
| CITY |
| COAST |

(2 rows)

`SELECT symbol FROM companies WHERE profile ? 'capacity_mw'`

| symbol (STRING) |
|---|
| VOLT |

(1 row)

**Example: Any or all of some keys**

```sql
SELECT symbol,
       profile ?| ARRAY['rivers', 'branches'] AS has_one,
       profile ?& ARRAY['office', 'branches'] AS has_both,
       '{"branches": 270}' <@ profile AS has_270
FROM companies
ORDER BY symbol;
```

Result:

| symbol (STRING) | has_one (BOOL) | has_both (BOOL) | has_270 (BOOL) |
|---|---|---|---|
| CITY | true | true | true |
| COAST | true | true | false |
| VOLT | true | false | false |

(3 rows)

<a id="jsonpath"></a>

## SQL/JSON path: jsonb_path_query, @?, @@

Syntax:

```sql
jsonb_path_exists(document, 'path' [, vars [, silent]])       TRUE when the path finds anything
jsonb_path_match(document, 'path' [, vars [, silent]])        the TRUE / FALSE the path gives
jsonb_path_query(document, 'path' [, vars [, silent]])        one row per item the path finds
jsonb_path_query_array(document, 'path' [, vars [, silent]])  the items as one JSON list
jsonb_path_query_first(document, 'path' [, vars [, silent]])  the first item, or NULL
document @? 'path'                                            jsonb_path_exists, never an error
document @@ 'path'                                            jsonb_path_match, never an error
```

PostgreSQL's JSON path language: find parts of a document, keep the ones a filter likes, and do sums on them.
It is bigger than the simple `'$.a.b'` [paths](functions-json.md#json-paths) of `json_extract`.

| Path part | Meaning |
|---|---|
| `$` | the whole document |
| `.key`, `."key with spaces"`, `.*` | a key; any key |
| `[0]`, `[last]`, `[last - 1]`, `[1 to 3]`, `[0, 2]`, `[*]` | elements of a list (`0` is the first) |
| `.**`, `.**{2}`, `.**{1 to last}` | every value below, at any level (or those levels) |
| `? (condition)` | keeps the items the condition is true for; `@` is the item |
| `==`, `!=`, `<>`, `<`, `<=`, `>`, `>=` | compare (numbers by value, text by its characters) |
| `&&`, `\|\|`, `!( )` | and, or, not |
| `exists (path)`, `(condition) is unknown` | a path finds something; a comparison could not be made |
| `like_regex "pattern" flag "i"`, `starts with "text"` | text tests (flags `i`, `s`, `q`) |
| `+`, `-`, `*`, `/`, `%` | sums on single numbers |
| `.type()`, `.size()`, `.double()`, `.abs()`, `.floor()`, `.ceiling()`, `.keyvalue()` | methods |
| `$name` | a variable from `vars` (a JSON object: `'{"min": 100}'`) |

- **Lax** (the default): a key step on a list looks inside its elements, an element step on a single value treats it as a list of one, and a key that is not there finds nothing. Write `strict $...` to make such mistakes errors.
- **Returns:** `BOOL` for `_exists`, `_match`, `@?` and `@@`; `JSON` for the others (PostgreSQL's `jsonb`: Postgres clients get it as `jsonb`, written `{"a": 1}`).
- **NULL:** a `NULL` document, path or vars gives `NULL` (and `jsonb_path_query` no rows). `@@` gives `NULL` when the answer is unknown.
- **Errors:** with the SQLSTATE PostgreSQL uses, such as `2203A` (`strict` and no such key), `22038` (a sum on more than one number) and `42601` (a mistake in the path). `silent => true` (the fourth argument) turns the "not found" and "wrong type" errors into no result, as `@?` and `@@` always do.
- **Speed:** the path is read once per statement, not once per row. `doc @? '...'`, `doc @@ '...'` and the calls with `silent` true run in the column engine on the stored text, like `->>`.
- **Differences:** `.datetime()` and the `like_regex` flags `m` and `x` are an error (PostgreSQL has no `x` either).

**Example: Companies with more than 300 branches, and every tag as a row**

```sql
SELECT symbol FROM companies WHERE profile @? '$.branches ? (@ > 300)';
SELECT symbol, jsonb_path_query(profile, '$.tags[*]') AS tag FROM companies ORDER BY symbol;
```

Result:

`SELECT symbol FROM companies WHERE profile @? '$.branches ? (@ > 300)'`

| symbol (STRING) |
|---|
| COAST |

(1 row)

`SELECT symbol, jsonb_path_query(profile, '$.tags[*]') AS tag FROM companies ORDER BY symbol`

| symbol (STRING) | tag (JSON) |
|---|---|
| CITY | "bank" |
| CITY | "A class" |
| COAST | "bank" |

(3 rows)

**Example: A condition as the whole path, and a value given as a variable**

```sql
SELECT symbol,
       profile @@ '$.branches > 300' AS many_branches,
       jsonb_path_exists(profile, '$.branches ? (@ >= $min)', '{"min": 270}') AS at_least_270
FROM companies
ORDER BY symbol;
```

Result:

| symbol (STRING) | many_branches (BOOL) | at_least_270 (BOOL) |
|---|---|---|
| CITY | false | true |
| COAST | true | true |
| VOLT | false | false |

(3 rows)

**Example: Lists and sums**

```sql
SELECT jsonb_path_query_array('{"eps": [12.1, 6.35, 3.2]}', '$.eps[*] ? (@ > 5)') AS big,
       jsonb_path_query_first('{"eps": [12.1, 6.35, 3.2]}', '$.eps[last]') AS last_one,
       jsonb_path_query_first('{"eps": [12.1, 6.35, 3.2]}', '$.eps.size()') AS how_many,
       jsonb_path_query_first('{"eps": [12.1, 6.35, 3.2]}', '$.eps[0] / 2') AS half;
```

Result:

| big (JSON) | last_one (JSON) | how_many (JSON) | half (JSON) |
|---|---|---|---|
| [12.1,6.35] | 3.2 | 3 | 6.0500000000000000 |

(1 row)

**Example: Every key and value of an object, and text tests**

```sql
SELECT jsonb_path_query('{"npl_pct": 2.6, "car_pct": 13.4}', '$.keyvalue()') AS pair;
SELECT symbol FROM companies WHERE profile @? '$.website ? (@ like_regex "coastal|volt" flag "i")' ORDER BY symbol;
```

Result:

`SELECT jsonb_path_query('{"npl_pct": 2.6, "car_pct": 13.4}', '$.keyvalue()') AS pair`

| pair (JSON) |
|---|
| {"id":0,"key":"car_pct","value":13.4} |
| {"id":0,"key":"npl_pct","value":2.6} |

(2 rows)

`SELECT symbol FROM companies WHERE profile @? '$.website ? (@ like_regex "coastal|volt" flag "i")' O`

| symbol (STRING) |
|---|
| COAST |
| VOLT |

(2 rows)

**Example: strict: a key that is not there is an error** (shows an error)

```sql
SELECT jsonb_path_query('{"branches": 270}', 'strict $.office');
```

Result:

Error: `line 1, column 8: jsonb_path_query: JSON object does not contain key "office"`

**Example: silent: the same mistake gives no result**

```sql
SELECT count(*) FROM jsonb_path_query('{"branches": 270}', 'strict $.office', '{}', true);
```

Result:

| count(*) (LONG) |
|---|
| 0 |

(1 row)

<a id="gin"></a>

## GIN index on a JSON column

Syntax:

```sql
CREATE INDEX name ON table USING GIN (json_column)
```

An index of the keys and values inside every document of the column. It finds the rows for:

| Condition | Example |
|---|---|
| `@>` a JSON value | `extra @> '{"category": "auth"}'` |
| `?`, `?\|`, `?&` | `extra ? 'error'` |
| `->>` equal to text, or `IN` a list of texts | `extra ->> 'category' = 'auth'`, `extra -> 'user' ->> 'role' IN ('admin', 'owner')` |

- The index finds the rows that **may** match; the condition is then checked on those rows. So the answer is always the same as without the index.
- `EXPLAIN` shows `use index name (JSON keys and values ...)` when it is used. It is not used for `<>`, `<`, `>`, or for `@> '{}'` (nothing to look up).
- Like every KDB index it lives in memory and is built from the rows when first needed (see [indexes](indexes.md)). It costs roughly the size of the keys and values it holds.
- `USING GIN` on a column that is not `JSON` makes an ordinary index, as before.
- An index made with `USING GIN` before 2026-09-24 is an ordinary index on the whole value: drop it and create it again to get this kind.

**Example: Find log rows by a key inside the JSON**

Setup:

```sql
CREATE TABLE app_logs (id LONG PRIMARY KEY, message STRING, extra JSON);
INSERT INTO app_logs VALUES
  (1, 'login ok', '{"category": "auth", "user": {"id": 7}}'),
  (2, 'feed loaded', '{"category": "feed", "items": 20}'),
  (3, 'login failed', '{"category": "auth", "user": {"id": 9}, "error": "bad password"}');
CREATE INDEX app_logs_extra ON app_logs USING GIN (extra);
```

```sql
SELECT id, message FROM app_logs WHERE extra ->> 'category' = 'auth' ORDER BY id;
SELECT id, message FROM app_logs WHERE extra @> '{"user": {"id": 9}}';
SELECT id, message FROM app_logs WHERE extra ? 'error';
```

Result:

`SELECT id, message FROM app_logs WHERE extra ->> 'category' = 'auth' ORDER BY id`

| id (LONG) | message (STRING) |
|---|---|
| 1 | login ok |
| 3 | login failed |

(2 rows)

`SELECT id, message FROM app_logs WHERE extra @> '{"user": {"id": 9}}'`

| id (LONG) | message (STRING) |
|---|---|
| 3 | login failed |

(1 row)

`SELECT id, message FROM app_logs WHERE extra ? 'error'`

| id (LONG) | message (STRING) |
|---|---|
| 3 | login failed |

(1 row)

<a id="json_build_object"></a>

## json_build_object, jsonb_build_object

Syntax:

```sql
json_build_object(key, value [, key, value ...])
jsonb_build_object(key, value [, key, value ...])
```

Builds a JSON object from pairs: first a key, then its value, then the next pair. `jsonb_build_object` is the same function under the PostgreSQL `jsonb` name.

| Argument | Type | Meaning |
|---|---|---|
| `key` | `STRING` (a number is turned into text) | the key name |
| `value` | any | the value for that key; `JSON` stays JSON |

- **Returns:** `JSON` (an object). With no arguments: `{}`.
- **NULL:** a `NULL` **value** becomes JSON `null`. A `NULL` **key** is an error.
- **Notes:** an odd number of arguments is an error. [json_object](functions-json.md#json_object) does the same thing with the same shape.

**Example: A company card for the app**

```sql
SELECT json_build_object('symbol', symbol, 'name', name, 'sector', sector,
                         'city', profile ->> 'office.city') AS card
FROM companies
WHERE symbol = 'CITY';
```

Result:

| card (JSON) |
|---|
| {"symbol":"CITY","name":"City Bank Limited","sector":"Banking","city":null} |

(1 row)

**Example: Pairs must be complete** (shows an error)

```sql
SELECT json_build_object('symbol');
```

Result:

Error: `line 1, column 8: json_build_object needs pairs of key and value (an even number of arguments)`

<a id="json_build_array"></a>

## json_build_array, jsonb_build_array

Syntax:

```sql
json_build_array(value [, value ...])
jsonb_build_array(value [, value ...])
```

Builds a JSON list from the values, in order. `jsonb_build_array` is the same function under the PostgreSQL `jsonb` name.

| Argument | Type | Meaning |
|---|---|---|
| `value` | any | one element of the list; `JSON` stays JSON |

- **Returns:** `JSON` (a list). With no arguments: `[]`.
- **NULL:** a `NULL` value becomes JSON `null`. The result is never `NULL`.
- **Notes:** `ARRAY[...]` builds the same value and is shorter to write (see [arrays](functions-postgres.md#arrays)).

**Example: Quarter results as a small list**

```sql
SELECT symbol, json_build_array(fiscal_year, quarter, eps) AS row_as_list
FROM fundamentals
WHERE symbol = 'CITY'
ORDER BY quarter;
```

Result:

| symbol (STRING) | row_as_list (JSON) |
|---|---|
| CITY | ["2082/83",3,11.40] |
| CITY | ["2082/83",4,12.10] |

(2 rows)

## to_jsonb

Syntax:

```sql
to_jsonb(value)
```

Turns one SQL value into JSON: text becomes a JSON string with `"` around it, a number stays a number, `TRUE`/`FALSE` stay `true`/`false`, and a `JSON` value stays as it is.

| Argument | Type | Meaning |
|---|---|---|
| `value` | any | the value to turn into JSON |

- **Returns:** `JSON`.
- **NULL:** `to_jsonb(NULL)` is `NULL` (SQL NULL, not JSON `null`).
- **Notes:** the same as [to_json](functions-json.md#to_json); PostgreSQL apps write `to_jsonb`. Use it to make the new value for [jsonb_set](functions-json.md#jsonb_set), so text is not read as JSON by mistake.

**Example**

```sql
SELECT to_jsonb(symbol) AS as_json_string,
       to_jsonb(eps) AS as_number,
       to_jsonb(extra) AS json_stays_json
FROM fundamentals
WHERE symbol = 'VOLT';
```

Result:

| as_json_string (JSON) | as_number (JSON) | json_stays_json (JSON) |
|---|---|---|
| "VOLT" | 3.20 | {"energy_gwh":2105.4,"plant_factor_pct":52.7} |

(1 row)

<a id="row_to_json"></a>

## row_to_json, to_json_row

Syntax:

```sql
row_to_json(value)
to_json_row(value)
```

Turns a value into JSON, the way a PostgreSQL app calls it on a row. KDB has no whole-row value, so give it a list or an object you built yourself.

| Argument | Type | Meaning |
|---|---|---|
| `value` | any | the value to turn into JSON |

- **Returns:** `JSON`.
- **NULL:** `row_to_json(NULL)` is `NULL`.
- **Notes:** for a whole row, build it with `json_build_object('column', column, ...)`. `SELECT row_to_json(t) FROM table t`, the usual PostgreSQL way, does not work here.

**Example: One row of the company list as JSON**

```sql
SELECT row_to_json(json_build_object('symbol', symbol, 'name', name)) AS row_json
FROM companies
ORDER BY symbol;
```

Result:

| row_json (JSON) |
|---|
| {"symbol":"CITY","name":"City Bank Limited"} |
| {"symbol":"COAST","name":"Coastal Bank Limited"} |
| {"symbol":"VOLT","name":"Volt River Hydropower Limited"} |

(3 rows)

## jsonb_set

Syntax:

```sql
jsonb_set(document, path_array, new_value)
jsonb_set(document, path_array, new_value, create_missing)
```

The document with one part set to `new_value`. The path is an **array of steps** (`'{office,city}'`), not a `$.` path.

| Argument | Type | Meaning |
|---|---|---|
| `document` | `JSON` | the document to change |
| `path_array` | array or array text | the steps down to the part, like `'{office,city}'` or `ARRAY['tags', 0]` |
| `new_value` | `JSON` | the new value; use `to_jsonb(x)` for text or a number |
| `create_missing` | `BOOL` | `TRUE` (default): add the key when it is not there. `FALSE`: only change a key that is already there. |

- **Returns:** `JSON`. The saved row does not change until you `UPDATE` it.
- **NULL:** a `NULL` document gives `NULL`. A `NULL` path gives the document back. A `NULL` new value gives `NULL` (as PostgreSQL does).
- **Notes:** a new value that is not JSON is an error - `'A'` is not JSON, `to_jsonb('A')` is. [json_set](functions-json.md#json_set) does the same with a `'$.office.city'` path.

**Example: Mark a quarter as audited**

Setup:

```sql
UPDATE fundamentals
SET extra = jsonb_set(extra, '{audited}', 'true')
WHERE symbol = 'COAST' AND quarter = 4;
```

```sql
SELECT symbol, quarter, extra FROM fundamentals WHERE symbol = 'COAST';
```

Result:

| symbol (STRING) | quarter (INT) | extra (JSON) |
|---|---|---|
| COAST | 4 | {"npl_pct":4.10,"car_pct":12.2,"audited":true} |

(1 row)

**Example: create_missing = FALSE changes only keys that are there**

```sql
SELECT jsonb_set(extra, '{npl_pct}', '3.00') AS changed,
       jsonb_set(extra, '{rating}', to_jsonb('A'), FALSE) AS not_added,
       jsonb_set(extra, '{rating}', to_jsonb('A')) AS added
FROM fundamentals
WHERE symbol = 'COAST' AND quarter = 4;
```

Result:

| changed (JSON) | not_added (JSON) | added (JSON) |
|---|---|---|
| {"npl_pct":3.00,"car_pct":12.2} | {"npl_pct":4.10,"car_pct":12.2} | {"npl_pct":4.10,"car_pct":12.2,"rating":"A"} |

(1 row)

**Example: The new value must be JSON** (shows an error)

```sql
SELECT jsonb_set(extra, '{rating}', 'A') FROM fundamentals WHERE symbol = 'COAST';
```

Result:

Error: `line 1, column 8: jsonb_set: the new value is not JSON (use to_jsonb(...) for text)`

## jsonb_set_lax

Syntax:

```sql
jsonb_set_lax(document, path_array, new_value [, create_missing [, null_value_treatment]])
```

[jsonb_set](functions-json.md#jsonb_set) that says what a `NULL` new value means, instead of giving `NULL`.

| `null_value_treatment` | A `NULL` new value ... |
|---|---|
| `'use_json_null'` (default) | sets the part to JSON `null` |
| `'delete_key'` | removes the part (as `#-`) |
| `'return_target'` | leaves the document as it is |
| `'raise_exception'` | is an error (SQLSTATE `22004`) |

- **Returns:** `JSON` (`jsonb`). A new value that is not `NULL` works exactly as in `jsonb_set`.
- **NULL:** a `NULL` document, path or `create_missing` gives `NULL`. A `NULL` treatment, or a word not in the table, is an error.

**Example: Clear a key when the app sends no value**

```sql
SELECT jsonb_set_lax('{"phone": "01-5970015", "city": "Kathmandu"}', '{phone}', NULL, true, 'delete_key') AS removed,
       jsonb_set_lax('{"phone": "01-5970015", "city": "Kathmandu"}', '{phone}', NULL) AS json_null;
```

Result:

| removed (JSON) | json_null (JSON) |
|---|---|
| {"city":"Kathmandu"} | {"phone":null,"city":"Kathmandu"} |

(1 row)

## jsonb_insert

Syntax:

```sql
jsonb_insert(document, path_array, new_value [, insert_after])
```

The document with `new_value` added at the path, never replacing anything (PostgreSQL).

- **In a list:** the last step is a place; the value goes **before** it (`insert_after` true: after it). `-1` is the last element. A place past either end adds at that end.
- **In an object:** the last step is a new key. A key that is already there is an error (SQLSTATE `22023`): use [jsonb_set](functions-json.md#jsonb_set) to change it.
- **Returns:** `JSON` (`jsonb`). When the path's parent is not there, the document comes back unchanged.
- **NULL:** any `NULL` argument gives `NULL`.

**Example: Add a tag at the front, at the end, and a new key**

```sql
SELECT jsonb_insert(profile, '{tags,0}', '"listed"') AS first_tag,
       jsonb_insert(profile, '{tags,-1}', '"retail"', true) AS last_tag,
       jsonb_insert(profile, '{office,fax}', '"01-5970016"') AS with_fax
FROM companies
WHERE symbol = 'CITY';
```

Result:

| first_tag (JSON) | last_tag (JSON) | with_fax (JSON) |
|---|---|---|
| {"website":"https://www.citybank.example.com","office":{"city":"Kathmandu","phone":"01-5970015"},"branches":270,"tags":["listed","bank","A class"]} | {"website":"https://www.citybank.example.com","office":{"city":"Kathmandu","phone":"01-5970015"},"branches":270,"tags":["bank","A class","retail"]} | {"website":"https://www.citybank.example.com","office":{"city":"Kathmandu","phone":"01-5970015","fax":"01-5970016"},"branches":270,"tags":["bank","A class"]} |

(1 row)

**Example: An existing key is not replaced** (shows an error)

```sql
SELECT jsonb_insert('{"branches": 270}', '{branches}', '300');
```

Result:

Error: `line 1, column 8: jsonb_insert: cannot replace existing key (use jsonb_set to replace the value of a key)`

<a id="jsonb_strip_nulls"></a>

## jsonb_strip_nulls, json_strip_nulls

Syntax:

```sql
jsonb_strip_nulls(document)
json_strip_nulls(document)
```

The document without the keys whose value is JSON `null`, at every level. A `null` inside a list stays.

- **Returns:** `JSON` (`jsonb_strip_nulls`: `jsonb`). **NULL:** `NULL` gives `NULL`.
- **Notes:** a key written twice counts once in `jsonb_strip_nulls`, with its last value (`{"a":1,"a":null}` gives `{}`); `json_strip_nulls` keeps both and removes only the `null` one.

**Example**

```sql
SELECT jsonb_strip_nulls('{"eps": 12.1, "dividend": null, "notes": {"audit": null}, "q": [null, 1]}') AS stripped;
```

Result:

| stripped (JSON) |
|---|
| {"eps":12.1,"notes":{},"q":[null,1]} |

(1 row)

## jsonb_pretty

Syntax:

```sql
jsonb_pretty(document)
```

The document as text on many lines, four spaces per level, exactly as PostgreSQL writes it (keys in `jsonb` order: shorter keys first).

- **Returns:** `STRING`. **NULL:** `NULL` gives `NULL`.

**Example**

```sql
SELECT jsonb_pretty(profile) FROM companies WHERE symbol = 'COAST';
```

Result:

| jsonb_pretty(profile) (STRING) |
|---|
| {     "tags": [         "bank"     ],     "office": {         "city": "Kathmandu"     },     "website": "https://www.coastalbank.example.com",     "branches": 380 } |

(1 row)

## jsonb_object

Syntax:

```sql
jsonb_object('{key, value, key, value ...}')
jsonb_object('{{key, value}, {key, value} ...}')
jsonb_object(keys_array, values_array)
```

A JSON object from a text array of pairs, or from a list of keys and a list of values (PostgreSQL). Every value becomes a JSON **string**.

- **Returns:** `JSON` (`jsonb`). A key given twice keeps its last value.
- **NULL:** a `NULL` value becomes JSON `null`; a `NULL` key is an error (`22004`). An odd number of elements, rows that are not pairs, or lists of different lengths are errors (`2202E`).

**Example**

```sql
SELECT jsonb_object('{city,Kathmandu,branches,270}') AS from_pairs,
       jsonb_object(ARRAY['city', 'branches'], ARRAY['Pokhara', '12']) AS from_two_lists;
```

Result:

| from_pairs (JSON) | from_two_lists (JSON) |
|---|---|
| {"city":"Kathmandu","branches":"270"} | {"city":"Pokhara","branches":"12"} |

(1 row)

## array_to_json

Syntax:

```sql
array_to_json(array [, pretty])
```

An array as a JSON list: `ARRAY[1, 2]` gives `[1,2]`, `ARRAY['a', 'b']` gives `["a","b"]`.

- **Returns:** `JSON`. With `pretty` true: the text PostgreSQL gives, a line break after each comma of the outer list (as `STRING`, since KDB keeps JSON values compact).
- **NULL:** `NULL` gives `NULL`.

**Example**

```sql
SELECT array_to_json(ARRAY[513, 515.6, 527.1]) AS prices;
```

Result:

| prices (JSON) |
|---|
| [513,515.6,527.1] |

(1 row)

<a id="json_extract_path"></a>

## json_extract_path, jsonb_extract_path

Syntax:

```sql
json_extract_path(document, key [, key ...])
jsonb_extract_path(document, key [, key ...])
```

The part of the document at those steps, **as JSON**. Each step is one argument: a key of an object, or the number of a place in a list (counting from `0`).

| Argument | Type | Meaning |
|---|---|---|
| `document` | `JSON` | the document to read |
| `key` | `STRING` | one step down: a key name, or a number for a list |

- **Returns:** `JSON`. With no steps: the whole document.
- **NULL:** a step that is not there gives `NULL`. A `NULL` document gives `NULL`.
- **Notes:** the same as the operator `document #> '{office,city}'`. For plain text instead of JSON use [json_extract_path_text](functions-json.md#json_extract_path_text). For a `'$.office.city'` path use [json_extract](functions-json.md#json_extract).

**Example: City and first tag of a company**

```sql
SELECT json_extract_path(profile, 'office', 'city') AS city,
       json_extract_path(profile, 'tags', '0') AS first_tag,
       json_extract_path(profile, 'office', 'street') AS not_there
FROM companies
WHERE symbol = 'CITY';
```

Result:

| city (JSON) | first_tag (JSON) | not_there (STRING) |
|---|---|---|
| "Kathmandu" | "bank" | NULL |

(1 row)

<a id="json_extract_path_text"></a>

## json_extract_path_text, jsonb_extract_path_text

Syntax:

```sql
json_extract_path_text(document, key [, key ...])
jsonb_extract_path_text(document, key [, key ...])
```

The same as `json_extract_path`, but the answer is **text**: a JSON string comes back without its quotes.

| Argument | Type | Meaning |
|---|---|---|
| `document` | `JSON` | the document to read |
| `key` | `STRING` | one step down: a key name, or a number for a list |

- **Returns:** `STRING`.
- **NULL:** a step that is not there, or a JSON `null`, gives `NULL`.
- **Notes:** the same as the operator `document #>> '{office,city}'`. Text cannot be used in sums: cast it first (`::DOUBLE`).

**Example: Company office cities as plain text**

```sql
SELECT symbol,
       json_extract_path_text(profile, 'office', 'city') AS city,
       json_extract_path_text(profile, 'website') AS website
FROM companies
ORDER BY symbol;
```

Result:

| symbol (STRING) | city (STRING) | website (STRING) |
|---|---|---|
| CITY | Kathmandu | https://www.citybank.example.com |
| COAST | Kathmandu | https://www.coastalbank.example.com |
| VOLT | NULL | https://www.voltriver.example.com |

(3 rows)

<a id="json_typeof"></a>

## json_typeof, jsonb_typeof

Syntax:

```sql
json_typeof(value)
jsonb_typeof(value)
```

What kind of JSON the value is: `object`, `array`, `string`, `number`, `boolean` or `null`.

| Argument | Type | Meaning |
|---|---|---|
| `value` | `JSON` (or text that holds JSON) | the value to look at |

- **Returns:** `STRING`.
- **NULL:** a SQL `NULL` gives `NULL`. The JSON value `null` gives the text `null`.
- **Notes:** the same as [json_type](functions-json.md#json_type). Use it before you read a part whose shape is not the same in every row.

**Example: Which profiles have a list of tags?**

```sql
SELECT symbol,
       json_typeof(profile) AS profile_is,
       jsonb_typeof(profile -> 'tags') AS tags_is
FROM companies
ORDER BY symbol;
```

Result:

| symbol (STRING) | profile_is (STRING) | tags_is (STRING) |
|---|---|---|
| CITY | object | array |
| COAST | object | array |
| VOLT | object | NULL |

(3 rows)

## jsonb_array_length

Syntax:

```sql
jsonb_array_length(json_array)
```

How many elements a JSON list has.

| Argument | Type | Meaning |
|---|---|---|
| `json_array` | `JSON` | a JSON list |

- **Returns:** `LONG`.
- **NULL:** a `NULL` value gives `NULL`.
- **Notes:** the PostgreSQL name for [json_array_length](functions-json.md#json_array_length); both give the same number. A value that is not a list gives `NULL`, as in PostgreSQL.

**Example: How many tags does a company have**

```sql
SELECT symbol, jsonb_array_length(profile -> 'tags') AS tags
FROM companies
WHERE symbol = 'CITY';
```

Result:

| symbol (STRING) | tags (LONG) |
|---|---|
| CITY | 2 |

(1 row)

**Example: The same number three ways**

```sql
SELECT symbol,
       json_array_length(profile -> 'tags') AS tags,
       cardinality(profile -> 'tags') AS same_number
FROM companies
ORDER BY symbol;
```

Result:

| symbol (STRING) | tags (LONG) | same_number (LONG) |
|---|---|---|
| CITY | 2 | 2 |
| COAST | 1 | 1 |
| VOLT | NULL | NULL |

(3 rows)

<a id="jsonb-delete"></a>

## -, #- (delete from a document)

Syntax:

```sql
document - 'key'
document - ARRAY['key1', 'key2']
document - position
document #- '{step,step,...}'
```

The document without some part of it (PostgreSQL). The saved row does not change until you `UPDATE` it.

| Form | What goes |
|---|---|
| `doc - 'key'` | that key of an object; in a list, every string element equal to `'key'` |
| `doc - ARRAY['a', 'b']` | each of those keys |
| `doc - 2` | the element at that place of a list, counting from `0`; `-1` is the last |
| `doc #- '{office,city}'` | the part the path points to; a number step is a place in a list |

- **Returns:** `JSON`. A key or place that is not there leaves the document as it is.
- **NULL:** a `NULL` document or argument gives `NULL`.
- **Notes:** a number on an object (`'{"a":1}'::jsonb - 0`) and anything on a plain value (`'5'::jsonb - 'a'`) is an error, as in PostgreSQL. A path step that is not a number where the document has a list is an error too. [json_remove](functions-json.md#json_remove) does the same with `'$.a'` paths.

**Example: Leave out keys, list elements and a nested part**

```sql
SELECT profile - 'website' AS no_website,
       profile - ARRAY['website', 'office'] AS two_keys_less,
       profile -> 'tags' - 0 AS tags_without_first,
       profile #- '{office,phone}' AS no_phone
FROM companies
WHERE symbol = 'CITY';
```

Result:

| no_website (JSON) | two_keys_less (JSON) | tags_without_first (JSON) | no_phone (JSON) |
|---|---|---|---|
| {"office":{"city":"Kathmandu","phone":"01-5970015"},"branches":270,"tags":["bank","A class"]} | {"branches":270,"tags":["bank","A class"]} | ["A class"] | {"website":"https://www.citybank.example.com","office":{"city":"Kathmandu"},"branches":270,"tags":["bank","A class"]} |

(1 row)

**Example: A number on an object is an error** (shows an error)

```sql
SELECT '{"a": 1}'::jsonb - 0;
```

Result:

Error: `line 1, column 26: cannot delete from object using integer index`

<a id="json-rows"></a>

## JSON to rows: jsonb_each, jsonb_array_elements, ...

Syntax:

```sql
SELECT * FROM jsonb_each(document)                -- key, value (JSON)
SELECT * FROM jsonb_each_text(document)           -- key, value (text)
SELECT * FROM jsonb_array_elements(list)          -- value (JSON)
SELECT * FROM jsonb_array_elements_text(list)     -- value (text)
SELECT * FROM jsonb_object_keys(document)         -- jsonb_object_keys
```

These functions make **rows** from one JSON value, as in PostgreSQL: one row per key of an object, or per element of a list. The `json_` names (`json_each`, `json_array_elements`, ...) are the same functions.

| Function | Rows | Columns |
|---|---|---|
| `jsonb_each(doc)` | one per key | `key` (text), `value` (JSON) |
| `jsonb_each_text(doc)` | one per key | `key`, `value` (text: a string without quotes, JSON `null` as `NULL`) |
| `jsonb_array_elements(list)` | one per element | `value` (JSON) |
| `jsonb_array_elements_text(list)` | one per element | `value` (text) |
| `jsonb_object_keys(doc)` | one per key | `jsonb_object_keys` (text) |

- **In FROM:** the argument is a value: a constant, a `$1` parameter, or a subquery like `(SELECT profile FROM companies WHERE symbol = 'CITY')`. A column of another table in the same `FROM` (PostgreSQL's `FROM t, jsonb_each(t.doc)`) is **not** supported yet.
- **In the SELECT list:** `jsonb_array_elements`, `jsonb_array_elements_text` and `jsonb_object_keys` also work, one row per element for each row, like [unnest](functions-postgres.md#unnest). That is the way to split a column of every row.
- **NULL:** a `NULL` value gives no rows.
- **Notes:** a value of the wrong shape is an error, as in PostgreSQL: `jsonb_each` of a list, `jsonb_array_elements` of an object. `AS e(k, v)` renames the columns.

**Example: Every key and value of a profile**

```sql
SELECT key, value
FROM jsonb_each_text((SELECT profile FROM companies WHERE symbol = 'COAST'));
```

Result:

| key (STRING) | value (STRING) |
|---|---|
| website | https://www.coastalbank.example.com |
| office | {"city":"Kathmandu"} |
| branches | 380 |
| tags | ["bank"] |

(4 rows)

**Example: One row per tag of every company (SELECT list)**

```sql
SELECT symbol, jsonb_array_elements_text(profile -> 'tags') AS tag
FROM companies
WHERE profile ? 'tags'
ORDER BY symbol, tag;
```

Result:

| symbol (STRING) | tag (STRING) |
|---|---|
| CITY | A class |
| CITY | bank |
| COAST | bank |

(3 rows)

**Example: The keys of a document**

```sql
SELECT * FROM jsonb_object_keys('{"npl_pct": 2.6, "car_pct": 13.4}');
```

Result:

| jsonb_object_keys (STRING) |
|---|
| npl_pct |
| car_pct |

(2 rows)

**Example: Not an object** (shows an error)

```sql
SELECT * FROM jsonb_each('[1, 2]');
```

Result:

Error: `line 1, column 15: jsonb_each: cannot deconstruct an array as an object`

<a id="json_to_record"></a>

## json_to_record, json_to_recordset

Syntax:

```sql
SELECT * FROM json_to_record(document) AS r(column TYPE, ...)
SELECT * FROM json_to_recordset(list_of_objects) AS r(column TYPE, ...)
```

A JSON object as one row, or a list of objects as rows, with the columns and types you write after the alias (PostgreSQL). An app can send many rows as one JSON parameter and insert them with one statement. `jsonb_to_record` and `jsonb_to_recordset` are the same.

| Argument | Type | Meaning |
|---|---|---|
| `document` / `list_of_objects` | `JSON` or text | `{"id": 1, ...}` or `[{"id": 1, ...}, {"id": 2, ...}]` |
| `AS r(column TYPE, ...)` | | each column and its type; a column is read from the key with its name |

- **Returns:** rows with those columns. A key that is missing, or JSON `null`, gives `NULL`. Keys without a column are left out.
- **Types:** each value is converted as `CAST(value AS TYPE)`: `"2.5"` and `2.5` both give a `DOUBLE`; a `JSON` column keeps the part as JSON; a `TEXT` column gets a string without its quotes, anything else as JSON text. A value that does not fit the type is an error that names the column and the row.
- **NULL:** a `NULL` value gives no rows.

**Example: Rows from a JSON list, as an app would send them**

```sql
SELECT *
FROM json_to_recordset('[{"symbol": "CITY", "eps": 12.1, "audited": true},
                         {"symbol": "COAST", "eps": "6.35"}]') AS r(symbol TEXT, eps DOUBLE, audited BOOL);
```

Result:

| symbol (STRING) | eps (DOUBLE) | audited (BOOL) |
|---|---|---|
| CITY | 12.1 | true |
| COAST | 6.35 | NULL |

(2 rows)

**Example: Each column needs a type** (shows an error)

```sql
SELECT * FROM json_to_record('{"id": 1}') AS r(id);
```

Result:

Error: `line 1, column 15: json_to_record: column 'id' needs a type, as in AS r(id INT, sym TEXT)`

<a id="jsonb_populate_record"></a>

## jsonb_populate_record, jsonb_populate_recordset

Syntax:

```sql
SELECT * FROM jsonb_populate_record(NULL::table_name, document)
SELECT * FROM jsonb_populate_recordset(NULL::table_name, list_of_objects)
```

Like [json_to_record](#json_to_record), but the columns and their types are those of a **table** (PostgreSQL's row type). `json_populate_record(set)` is the same.

- **Returns:** rows with the table's columns, each value converted as an `INSERT` into that column would do it. Missing keys give `NULL`.
- **Notes:** the first argument must be written `NULL::table_name`; KDB does not take a row of values there. It is only for `FROM` (and `INSERT INTO t SELECT * FROM ...`).

**Example: Insert rows sent as JSON into a table**

Setup:

```sql
INSERT INTO fundamentals (id, symbol, fiscal_year, quarter, eps)
SELECT id, symbol, fiscal_year, quarter, eps
FROM jsonb_populate_recordset(NULL::fundamentals,
     '[{"id": 90, "symbol": "VOLT", "fiscal_year": "2083/84", "quarter": 1, "eps": "1.10"}]');
```

```sql
SELECT id, symbol, quarter, eps FROM fundamentals WHERE id = 90;
```

Result:

| id (LONG) | symbol (STRING) | quarter (INT) | eps (DECIMAL(2)) |
|---|---|---|---|
| 90 | VOLT | 1 | 1.10 |

(1 row)
