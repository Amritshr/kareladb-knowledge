# 18. Content data: companies, reports, news and a forum

- Category: Tutorial

## What you will learn

- How to store company data, quarterly numbers, financial reports, news and forum posts in KarelaDB.
- The `JSON` type: store flexible data, read one value, change one value.
- The `BYTES` type: store hashes and small files.
- Text functions that work with text in any language (the examples use Nepali).
- How triggers keep forum counters (posts, votes) correct.
- Limits, and why big files should stay outside the database.

All examples are in examples/18-content-data/. The output under each example is real. The numbers are made up.

## The plan

A trading app needs more than prices. It also needs:

| Data | Table | Special types |
|---|---|---|
| Company details | `companies` | `JSON` for details that differ between companies |
| Numbers per quarter | `fundamentals` | `DECIMAL` for exact money, `JSON` for extra numbers |
| Financial reports | `reports` | `JSON` for the statements, `BYTES` for a file hash |
| News | `news` | text in any language, `JSON` tags |
| Forum | `forum_categories`, `forum_threads`, `forum_posts`, `forum_votes` | replies with `REFERENCES`, counters with triggers |

These are **relational** tables (chapter 3): each row has an id, and rows are changed often. Prices and candles stay in time-series tables.

## Step 1: the company tables

01-schema.sql:

```sql
CREATE TABLE companies (
  symbol STRING PRIMARY KEY,
  name STRING NOT NULL,
  name_ne STRING,
  sector STRING NOT NULL,
  listed_shares LONG,
  paid_up_capital DECIMAL(2),
  listed_on DATE,
  profile JSON DEFAULT '{}'
);

CREATE TABLE fundamentals (
  id LONG PRIMARY KEY AUTO,
  symbol STRING NOT NULL REFERENCES companies(symbol),
  fiscal_year STRING NOT NULL,
  quarter INT NOT NULL CHECK (quarter BETWEEN 1 AND 4),
  period_end DATE NOT NULL,
  eps DECIMAL(2),
  book_value DECIMAL(2),
  net_profit DECIMAL(2),
  extra JSON DEFAULT '{}'
);
CREATE UNIQUE INDEX fundamentals_one_per_quarter ON fundamentals (symbol, fiscal_year, quarter);

CREATE TABLE reports (
  id LONG PRIMARY KEY AUTO,
  symbol STRING NOT NULL REFERENCES companies(symbol),
  fiscal_year STRING NOT NULL,
  kind STRING NOT NULL,
  published_at TIMESTAMP NOT NULL,
  statements JSON NOT NULL,
  pdf_url STRING,
  pdf_sha256 BYTES
);

CREATE TABLE news (
  id LONG PRIMARY KEY AUTO,
  symbol STRING REFERENCES companies(symbol),
  published_at TIMESTAMP NOT NULL,
  lang STRING NOT NULL DEFAULT 'en',
  title STRING NOT NULL,
  body STRING NOT NULL,
  source_url STRING,
  tags JSON DEFAULT '[]'
);
```

```text
table 'companies' created

table 'fundamentals' created

index 'fundamentals_one_per_quarter' created on table 'fundamentals' (0 rows)

table 'reports' created

table 'news' created
```

Why these types:

- **Money is `DECIMAL(2)`**, never `DOUBLE`. `DECIMAL` is exact (chapter 3).
- The fiscal year is text like `'2082/83'`, because it is a year of a local calendar (here the Bikram Sambat year used in Nepal). `period_end` is the normal (AD) date, so you can sort and filter by time.
- `CREATE UNIQUE INDEX` makes sure there is only one row per company, year and quarter. [Chapter 17](17-indexes-and-search.md) explains indexes.
- `CHECK (quarter BETWEEN 1 AND 4)` refuses a wrong quarter (chapter 15).

## Step 2: JSON

Some data is different for every company. A bank has branches and NPL (bad loans). A hydropower company has megawatts and rivers. Do not make 50 columns that are mostly empty. Put such data in a `JSON` column.

02-companies.sql:

```sql
INSERT INTO companies VALUES
  ('CITY', 'City Bank Limited', 'सिटी बैंक लिमिटेड', 'Banking', 270578640, 27057864000.00, '1985-07-12',
   '{"website": "https://www.citybank.com", "head_office": "Kathmandu", "ceo": "A. Sharma", "branches": 270}'),
  ...
  ('VOLT', 'Volt River Hydropower Limited', 'भोल्ट रिभर जलविद्युत लिमिटेड', 'Energy', 105900000, 10590000000.00, '2019-01-21',
   '{"website": "https://www.voltriverhydro.com", "capacity_mw": 456, "rivers": ["Volt River"]}');

SELECT symbol, name_ne, length(name_ne) AS letters, octet_length(name_ne) AS bytes, sector
FROM companies ORDER BY symbol;

SELECT symbol,
       json_value(profile, '$.head_office') AS office,
       profile ->> 'website' AS website,
       json_value(profile, '$.capacity_mw') AS mw,
       profile -> 'rivers' ->> 0 AS river
FROM companies ORDER BY symbol;
```

```text
3 row(s) inserted

symbol | name_ne                      | letters | bytes | sector
-------+------------------------------+---------+-------+--------
CITY   | सिटी बैंक लिमिटेड            |      17 |    47 | Banking
COAST  | कोस्टल बैंक लिमिटेड          |      19 |    53 | Banking
VOLT   | भोल्ट रिभर जलविद्युत लिमिटेड |      28 |    78 | Energy
(3 rows, 0.1 ms)

symbol | office    | website                        | mw   | river
-------+-----------+--------------------------------+------+-----------
CITY   | Kathmandu | https://www.citybank.com       | NULL | NULL
COAST  | Kathmandu | https://www.coastalbank.com    | NULL | NULL
VOLT   | NULL      | https://www.voltriverhydro.com |  456 | Volt River
(3 rows, 0.1 ms)
```

What you see:

- `length()` counts **letters** (17). `octet_length()` counts **bytes** (47). A Nepali letter takes 3 bytes.
- A **path** starts with `$`. `$.head_office` is the key `head_office`. `$.rivers[0]` is the first element of the array `rivers`.
- A key that is not there gives `NULL`. It is not an error.

### How to read JSON

| You write | You get | Type of the result |
|---|---|---|
| `json_extract(doc, '$.a.b')` | the part, as JSON | `JSON` |
| `doc -> 'a' -> 'b'` | the same, shorter | `JSON` |
| `doc -> 0` | array element 0 (`-> -1` is the last one) | `JSON` |
| `doc ->> 'a'` | the part as text | `STRING` |
| `json_value(doc, '$.a')` | text, a whole number (`LONG`), a decimal number (`DOUBLE`) or `true`/`false` | depends on the value |
| `json_value_text` / `json_value_double` / `json_value_long` / `json_value_bool` | always this type (NULL if it does not fit) | `STRING` / `DOUBLE` / `LONG` / `BOOL` |
| `json_type(doc, '$.a')` | `object`, `array`, `string`, `number`, `boolean` or `null` | `STRING` |
| `json_array_length(doc, '$.a')` | number of elements | `LONG` |
| `json_keys(doc)` | the keys, as a JSON array | `JSON` |

Paths: `$.a.b`, `$.list[0]`, `$.list[-1]` (last), `$.list[last]`, `$."key with spaces"`, `$['key']`.

## Step 3: numbers per quarter

03-fundamentals.sql:

```sql
INSERT INTO fundamentals (symbol, fiscal_year, quarter, period_end, eps, book_value, net_profit, extra) VALUES
  ('CITY', '2082/83', 2, '2026-01-13', 10.85, 181.20, 1467500000.00, '{"npl_pct": 2.91, "car_pct": 12.8, "deposits": 431200000000}'),
  ('CITY', '2082/83', 3, '2026-04-13', 11.40, 184.05, 2310200000.00, '{"npl_pct": 2.75, "car_pct": 13.1, "deposits": 442900000000}'),
  ('CITY', '2082/83', 4, '2026-07-16', 12.10, 187.60, 3270100000.00, '{"npl_pct": 2.60, "car_pct": 13.4, "deposits": 455000000000, "audited": false}'),
  ('COAST', '2082/83', 4, '2026-07-16', 6.35, 158.90, 1011000000.00, '{"npl_pct": 4.10, "car_pct": 12.2}'),
  ('VOLT', '2082/83', 4, '2026-07-16', 3.20, 102.40, 338900000.00, '{"energy_gwh": 2105.4, "plant_factor_pct": 52.7}');

SELECT fiscal_year, quarter, period_end, eps, book_value FROM fundamentals
WHERE symbol = 'CITY' ORDER BY period_end;

SELECT symbol, quarter,
       json_value(extra, '$.npl_pct') AS npl,
       CAST(json_value_text(extra, '$.car_pct') AS DECIMAL(2)) AS car,
       json_type(extra, '$.audited') AS audited_type
FROM fundamentals WHERE fiscal_year = '2082/83' AND quarter = 4 ORDER BY symbol;

SELECT symbol, extra ->> 'npl_pct' AS npl FROM fundamentals
WHERE quarter = 4 AND json_value_double(extra, '$.npl_pct') > 3;

UPDATE fundamentals SET extra = json_set(extra, '$.audited', TRUE, '$.auditor', 'CA firm A')
WHERE symbol = 'CITY' AND quarter = 4;
SELECT json_value(extra, '$.audited') AS audited, extra ->> 'auditor' AS auditor, extra ->> 'npl_pct' AS npl
FROM fundamentals WHERE symbol = 'CITY' AND quarter = 4;
```

```text
5 row(s) inserted

fiscal_year | quarter | period_end | eps   | book_value
------------+---------+------------+-------+-----------
2082/83     |       2 | 2026-01-13 | 10.85 |     181.20
2082/83     |       3 | 2026-04-13 | 11.40 |     184.05
2082/83     |       4 | 2026-07-16 | 12.10 |     187.60
(3 rows, 0.1 ms)

symbol | quarter | npl  | car   | audited_type
-------+---------+------+-------+-------------
CITY   |       4 |  2.6 | 13.40 | boolean
COAST  |       4 |  4.1 | 12.20 | NULL
VOLT   |       4 | NULL |  NULL | NULL
(3 rows, 0.1 ms)

symbol | npl
-------+-----
COAST  | 4.10
(1 row, 0.1 ms)

1 row(s) updated

audited | auditor   | npl
--------+-----------+-----
true    | CA firm A | 2.60
(1 row, 0.1 ms)
```

Notes:

- `json_value` gives `2.6` as a `DOUBLE`. For **exact** money or percent, take the text and cast it: `CAST(json_value_text(extra, '$.car_pct') AS DECIMAL(2))`.
- `->>` keeps the number as it was written: `4.10`.
- `json_set(doc, path, value, path, value, ...)` changes or adds keys. The other keys stay. Use it in `UPDATE`.

### How to change JSON

| Function | What it does |
|---|---|
| `json_set(doc, path, value, ...)` | adds the key, or replaces its value |
| `json_insert(doc, path, value, ...)` | adds only; a key that is already there stays |
| `json_replace(doc, path, value, ...)` | replaces only; a missing key is not added |
| `json_remove(doc, path, ...)` | removes keys or array elements |
| `json_array_append(doc, path, value)` | adds a value at the end of an array |
| `json_object('k', v, ...)`, `json_array(v, ...)` | builds new JSON |

The value can be text (`'yes'` becomes `"yes"`), a number, `TRUE`/`FALSE`, `NULL` (becomes `null`), or JSON (`json('{"a": 1}')`, or another JSON column). If the parent of the path does not exist, nothing changes.

### Bad JSON is refused

04-bad-json.sql:

```sql
INSERT INTO fundamentals (symbol, fiscal_year, quarter, period_end, extra) VALUES
  ('COAST', '2082/83', 3, '2026-04-13', '{"npl_pct": 4.3}'),
  ('VOLT', '2082/83', 3, '2026-04-13', '{"energy_gwh": 1850.2,}');
```

```text
error: row 2: column 'extra' (JSON): not valid JSON: a JSON object cannot end with ',' at character 23 (near '}')
```

The message says the row, the column and the character. Nothing was saved (also not row 1).

How KarelaDB keeps JSON:

- It checks the text is valid JSON (RFC 8259). Keys need double quotes. `true`, `false` and `null` are lower case.
- It removes spaces between the parts. `{ "a" : 1 }` is saved as `{"a":1}`.
- It keeps the order of the keys and the digits of numbers (`2.60` stays `2.60`).
- A key written twice: a lookup finds the last one.
- JSON `null` is a value. It is not SQL `NULL`: `profile IS NULL` is false for `'null'`.

## Step 4: reports, and BYTES

A report has statements (balance sheet, income statement). Put them in a `JSON` column. The **PDF file stays outside the database** (see [Big files](#big-files-keep-them-outside)). KarelaDB keeps its address and its SHA-256 hash.

05-reports.sql:

```sql
INSERT INTO reports (symbol, fiscal_year, kind, published_at, statements, pdf_url, pdf_sha256) VALUES
  ('CITY', '2082/83', 'quarterly', '2026-08-01T10:15:00+05:45',
   '{"income": {"interest_income": 9820.5, "operating_profit": 4410.2, "net_profit": 3270.1},
     "balance_sheet": {"total_assets": 612300.8, "deposits": 455000.0, "loans": 402100.3},
     "unit": "USD million"}',
   'https://files.example.com/city/2082-83-q4.pdf',
   X'9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A08'),
  ('VOLT', '2082/83', 'quarterly', '2026-08-03T16:00:00+05:45',
   '{"income": {"sales": 1520.4, "net_profit": 338.9}, "unit": "USD million"}',
   'https://files.example.com/volt/2082-83-q4.pdf', NULL);

SELECT symbol,
       json_value(statements, '$.income.net_profit') AS net_profit,
       statements -> 'balance_sheet' ->> 'total_assets' AS assets,
       json_keys(statements) AS parts,
       length(pdf_sha256) AS hash_bytes,
       left(hex(pdf_sha256), 16) AS hash_start
FROM reports ORDER BY symbol;

SELECT to_base64(X'00FF10') AS b64, from_base64('AP8Q') AS back, X'0102' || X'00' AS joined,
       '\x6869'::BYTES AS from_text, octet_length('नेपाल'::BYTES) AS utf8_bytes;
```

```text
2 row(s) inserted

symbol | net_profit | assets   | parts                             | hash_bytes | hash_start
-------+------------+----------+-----------------------------------+------------+-----------------
CITY   |     3270.1 | 612300.8 | ["income","balance_sheet","unit"] |         32 | 9f86d081884c7d65
VOLT   |      338.9 | NULL     | ["income","unit"]                 |       NULL | NULL
(2 rows, 0.2 ms)

b64  | back     | joined   | from_text | utf8_bytes
-----+----------+----------+-----------+-----------
AP8Q | \x00ff10 | \x010200 | \x6869    |         15
(1 row, 0.1 ms)
```

About `BYTES`:

- `BYTES` holds any bytes, also zero bytes. Good for hashes, keys, small images and signatures.
- Write bytes as `X'0A0B'` or as text `'\x0a0b'`. Other text is saved as its UTF-8 bytes.
- KarelaDB **shows** bytes as `\x` and hex (`\x00ff10`), in the shell, in CSV and in the HTTP API. This is the same as PostgreSQL. `'\x...'` reads back as the same bytes.
- On `BYTES`, `length()` and `substring()` count bytes.
- Functions: `hex()`, `unhex()`, `to_base64()`, `from_base64()`, `encode(b, 'hex' | 'base64')`, `decode(t, 'hex' | 'base64')`, and `||` to join.

## Step 5: news and text search

06-news.sql:

```sql
INSERT INTO news (symbol, published_at, lang, title, body, source_url, tags) VALUES
  ('CITY', '2026-08-01T11:00:00+05:45', 'en', 'City Bank profit rises 18%',
   'City Bank reported a net profit of 3.27 billion dollars for Q4 of 2082/83.', 'https://news.example.com/1', '["results", "banking"]'),
  ('CITY', '2026-08-02T09:30:00+05:45', 'ne', 'सिटी बैंकको नाफा १८ प्रतिशतले बढ्यो',
   'सिटी बैंकले आर्थिक वर्ष २०८२/८३ को चौथो त्रैमासिकमा ३ अर्ब २७ करोड नाफा कमाएको छ।', 'https://news.example.com/2', '["results"]'),
  ('VOLT', '2026-08-20T14:00:00+05:45', 'en', 'Volt River sells record energy',
   'The plant produced 2105 GWh this year. Contact: info@voltriverhydro.com', NULL, '["hydro", "energy"]'),
  (NULL, '2026-09-01T08:00:00+05:45', 'en', 'Market index closes at 2,840',
   'The market gained 1.2% today. Banking stocks led the gains.', NULL, '[]');

SELECT id, lang, left(title, 30) AS preview, length(body) AS letters FROM news ORDER BY published_at;

SELECT id, title FROM news WHERE title ILIKE '%profit%' OR body ILIKE '%profit%' ORDER BY id;
SELECT id, title FROM news WHERE body LIKE '%नाफा%';

SELECT id, regexp_substr(body, '[\w.]+@[\w.]+\w') AS email FROM news WHERE regexp_like(body, '\w+@\w+');

SELECT to_char(published_at, 'YYYY-MM', '+05:45') AS month, lang, count(*) AS items
FROM news ORDER BY month, lang;

SELECT id, json_array_length(tags) AS tag_count, tags ->> 0 AS first_tag FROM news ORDER BY id;
```

```text
4 row(s) inserted

id | lang | preview                        | letters
---+------+--------------------------------+--------
 1 | en   | City Bank profit rises 18%     |      74
 2 | ne   | सिटी बैंकको नाफा १८ प्रतिशतले  |      81
 3 | en   | Volt River sells record energy |      71
 4 | en   | Market index closes at 2,840   |      59
(4 rows, 0.1 ms)

id | title
---+---------------------------
 1 | City Bank profit rises 18%
(1 row, 0.0 ms)

id | title
---+------------------------------------
 2 | सिटी बैंकको नाफा १८ प्रतिशतले बढ्यो
(1 row, 0.0 ms)

id | email
---+------------------------
 3 | info@voltriverhydro.com
(1 row, 0.1 ms)

month   | lang | items
--------+------+------
2026-08 | en   |     2
2026-08 | ne   |     1
2026-09 | en   |     1
(3 rows, 0.1 ms)

id | tag_count | first_tag
---+-----------+----------
 1 |         2 | results
 2 |         1 | results
 3 |         2 | hydro
 4 |         0 | NULL
(4 rows, 0.0 ms)
```

Notes:

- `left(title, 30)` cuts after 30 **letters**, never in the middle of a Nepali letter.
- `ILIKE` is `LIKE` that ignores upper and lower case of English letters. In `LIKE`, `%` is any text and `_` is one letter (also one Nepali letter). Write `\%` to find a real `%`.
- `LIKE '%word%'`, `ILIKE` and `regexp_like` read **every row**. That is fine for thousands of rows. For big tables, use **full-text search with an index**: [chapter 17](17-indexes-and-search.md).
- `to_char(time, format, zone)` makes text from a time. Use it to group reports by month, quarter (`Q`) or year in a local time, such as Nepal (`'+05:45'` or `'Asia/Kathmandu'`) or New York in summer (`'-04:00'`).
- Regular expressions support `\d`, `\w` (also Nepali letters), `\s`, `[...]`, `(...)`, `|`, `*`, `+`, `?`, `{n,m}`. KarelaDB never backtracks, so a bad pattern cannot hang the server.

### Text functions

| Function | Example | Result |
|---|---|---|
| `length(s)`, `octet_length(s)` | `length('नेपाल')`, `octet_length('नेपाल')` | `5`, `15` |
| `substring(s, from, len)` | `substring('नेपाल', 2, 2)` | `ेप` |
| `left(s, n)`, `right(s, n)` | `right('CITY', 3)` | `ITY` |
| `upper(s)`, `lower(s)` | `upper('city नेपाल')` | `CITY नेपाल` |
| `trim(s [, chars])`, `ltrim`, `rtrim` | `rtrim('नेपाल।।', '।')` | `नेपाल` |
| `replace(s, from, to)` | `replace('a-b', '-', '/')` | `a/b` |
| `split_part(s, sep, n)` | `split_part('2082/83', '/', 1)` | `2082` |
| `strpos(s, part)`, `position(part IN s)` | `position('बैंक' IN 'नेपाल बैंक')` | `7` |
| `starts_with`, `ends_with` | `ends_with('CITY', 'TY')` | `true` |
| `lpad(s, n, fill)`, `rpad` | `lpad('7', 3, '0')` | `007` |
| `concat(a, b)`, `a \|\| b`, `concat_ws(sep, ...)` | `'CITY' \|\| '-' \|\| 2082` | `CITY-2082` |
| `regexp_like`, `regexp_substr`, `regexp_count`, `regexp_replace` | `regexp_replace('a1b2', '\d', '#', 'g')` | `a#b#` |
| `coalesce`, `nullif`, `greatest`, `least` | `coalesce(name_ne, name)` | the first that is not NULL |

`a || b` gives NULL when a or b is NULL. `concat(a, b)` skips NULL. The SQL reference (chapter 11) lists every function.

## Step 6: the forum

07-forum-schema.sql (the triggers are shortened here; the file has all of them):

```sql
CREATE TABLE users (
  id INT PRIMARY KEY AUTO,
  name STRING NOT NULL UNIQUE
);

CREATE TABLE forum_categories (
  id INT PRIMARY KEY AUTO,
  slug STRING NOT NULL UNIQUE,
  title STRING NOT NULL,
  thread_count INT NOT NULL DEFAULT 0
);

CREATE TABLE forum_threads (
  id LONG PRIMARY KEY AUTO,
  category_id INT NOT NULL REFERENCES forum_categories(id),
  symbol STRING REFERENCES companies(symbol),
  user_id INT NOT NULL REFERENCES users(id),
  title STRING NOT NULL,
  created TIMESTAMP NOT NULL,
  post_count INT NOT NULL DEFAULT 0,
  last_post_at TIMESTAMP
);

CREATE TABLE forum_posts (
  id LONG PRIMARY KEY AUTO,
  thread_id LONG NOT NULL REFERENCES forum_threads(id),
  parent_id LONG REFERENCES forum_posts(id),
  user_id INT NOT NULL REFERENCES users(id),
  body STRING NOT NULL,
  created TIMESTAMP NOT NULL,
  score INT NOT NULL DEFAULT 0,
  meta JSON DEFAULT '{}'
);

CREATE TABLE forum_votes (
  id LONG PRIMARY KEY AUTO,
  post_id LONG NOT NULL REFERENCES forum_posts(id),
  user_id INT NOT NULL REFERENCES users(id),
  value INT NOT NULL CHECK (value IN (1, -1))
);
CREATE UNIQUE INDEX forum_votes_one_per_user ON forum_votes (user_id, post_id);

CREATE TRIGGER count_posts AFTER INSERT ON forum_posts EXECUTE BEGIN
  FOR r IN (SELECT thread_id, count(*) AS n, max(created) AS last FROM NEW GROUP BY thread_id) DO
    UPDATE forum_threads SET post_count = post_count + r.n, last_post_at = greatest(last_post_at, r.last)
    WHERE id = r.thread_id;
  END FOR;
END;

CREATE TRIGGER score_new_votes AFTER INSERT ON forum_votes EXECUTE BEGIN
  FOR r IN (SELECT post_id, sum(value) AS v FROM NEW GROUP BY post_id) DO
    UPDATE forum_posts SET score = score + r.v WHERE id = r.post_id;
  END FOR;
END;

CREATE TRIGGER score_changed_votes AFTER UPDATE ON forum_votes EXECUTE BEGIN
  FOR r IN (SELECT post_id, sum(value) AS v FROM OLD GROUP BY post_id) DO
    UPDATE forum_posts SET score = score - r.v WHERE id = r.post_id;
  END FOR;
  FOR r IN (SELECT post_id, sum(value) AS v FROM NEW GROUP BY post_id) DO
    UPDATE forum_posts SET score = score + r.v WHERE id = r.post_id;
  END FOR;
END;
```

The ideas:

- **Replies**: `parent_id REFERENCES forum_posts(id)`. A reply points to the post it answers. The first post of a thread has `parent_id` NULL.
- **One vote per user**: the unique index on `(user_id, post_id)`.
- **Counters**: `thread_count`, `post_count` and `score` are kept by triggers. A trigger runs in the same transaction as the change. So the counter is never wrong, also after a crash. Counting on every page view (`count(*)`) would be slower.
- Triggers run **once per statement**. They read all new rows from `NEW` and old rows from `OLD` (chapter 13). This is why they use `GROUP BY`.

08-forum-posts.sql:

```sql
INSERT INTO users (name) VALUES ('ram'), ('sita'), ('hari');
INSERT INTO forum_categories (slug, title) VALUES ('banking', 'Banking stocks'), ('hydro', 'Hydropower');

INSERT INTO forum_threads (category_id, symbol, user_id, title, created) VALUES
  (1, 'CITY', 1, 'CITY Q4 results: good or bad?', '2026-08-01T12:00:00+05:45'),
  (2, 'VOLT', 2, 'VOLT dividend this year?', '2026-08-21T09:00:00+05:45');

INSERT INTO forum_posts (thread_id, parent_id, user_id, body, created, meta) VALUES
  (1, NULL, 1, 'Profit is up 18%. I think the price will go up.', '2026-08-01T12:00:00+05:45', '{"device": "android"}'),
  (2, NULL, 2, 'Energy sales were a record. Dividend soon?', '2026-08-21T09:00:00+05:45', '{}');
INSERT INTO forum_posts (thread_id, parent_id, user_id, body, created) VALUES
  (1, 1, 2, 'But NPL is still 2.6%. Wait for the next quarter.', '2026-08-01T12:30:00+05:45');
INSERT INTO forum_posts (thread_id, parent_id, user_id, body, created, meta) VALUES
  (1, 3, 1, 'NPL went down from 2.91%. That is good news.', '2026-08-01T13:05:00+05:45', '{"edited": true}'),
  (1, 1, 3, 'नाफा राम्रो छ, तर मूल्य पहिले नै बढिसकेको छ।', '2026-08-01T15:40:00+05:45', '{"lang": "ne"}');

INSERT INTO forum_votes (post_id, user_id, value) VALUES (1, 2, 1), (1, 3, 1), (3, 1, -1), (3, 3, 1), (5, 1, 1);

SELECT slug, thread_count FROM forum_categories ORDER BY id;
SELECT id, title, post_count, last_post_at FROM forum_threads ORDER BY id;

SELECT p.id, p.parent_id, u.name, p.score, left(p.body, 30) AS text
FROM forum_posts p JOIN users u ON u.id = p.user_id
WHERE p.thread_id = 1 ORDER BY p.created;

SELECT parent_id, count(*) AS answers FROM forum_posts WHERE parent_id IS NOT NULL ORDER BY parent_id;
SELECT id, score FROM forum_posts ORDER BY score DESC, id LIMIT 1;
```

```text
3 row(s) inserted

2 row(s) inserted

2 row(s) inserted

2 row(s) inserted

1 row(s) inserted

2 row(s) inserted

5 row(s) inserted

slug    | thread_count
--------+-------------
banking |            1
hydro   |            1
(2 rows, 0.0 ms)

id | title                         | post_count | last_post_at
---+-------------------------------+------------+-------------------------
 1 | CITY Q4 results: good or bad? |          4 | 2026-08-01T09:55:00.000Z
 2 | VOLT dividend this year?      |          1 | 2026-08-21T03:15:00.000Z
(2 rows, 0.0 ms)

id | parent_id | name | score | text
---+-----------+------+-------+-------------------------------
 1 |      NULL | ram  |     2 | Profit is up 18%. I think the
 3 |         1 | sita |     0 | But NPL is still 2.6%. Wait fo
 4 |         3 | ram  |     0 | NPL went down from 2.91%. That
 5 |         1 | hari |     1 | नाफा राम्रो छ, तर मूल्य पहिले
(4 rows, 0.1 ms)

parent_id | answers
----------+--------
        1 |       2
        3 |       1
(2 rows, 0.1 ms)

id | score
---+------
 1 |     2
(1 row, 0.0 ms)
```

A reply must be its own `INSERT`: the post it answers must already be saved. In an app this is always true, because people answer posts they can see.

### A second vote is refused

09-vote-twice.sql:

```sql
INSERT INTO forum_votes (post_id, user_id, value) VALUES (1, 2, 1);
```

```text
error: duplicate value violates unique index 'forum_votes_one_per_user' on table 'forum_votes': a row with user_id='2', post_id='1' already exists
```

In the app, show "you already voted", or change the vote with `UPDATE`:

10-change-vote.sql:

```sql
UPDATE forum_votes SET value = -1 WHERE user_id = 3 AND post_id = 3;
DELETE FROM forum_votes WHERE user_id = 1 AND post_id = 5;
SELECT id, score FROM forum_posts ORDER BY id;

INSERT INTO forum_posts (thread_id, parent_id, user_id, body, created)
VALUES (2, 2, 3, 'Last year they paid 10% bonus shares.', '2026-08-22T10:00:00+05:45')
RETURNING id, thread_id;
SELECT id, post_count, last_post_at FROM forum_threads ORDER BY id;

SELECT id, regexp_substr(body, '\d+(\.\d+)?%') AS percent FROM forum_posts
WHERE regexp_like(body, '\d%') ORDER BY id;
```

```text
1 row(s) updated

1 row(s) deleted

id | score
---+------
 1 |     2
 2 |     0
 3 |    -2
 4 |     0
 5 |     0
(5 rows, 0.0 ms)

id | thread_id
---+----------
 6 |         2
(1 row, 0.7 ms)
1 row(s) inserted

id | post_count | last_post_at
---+------------+-------------------------
 1 |          4 | 2026-08-01T09:55:00.000Z
 2 |          2 | 2026-08-22T04:15:00.000Z
(2 rows, 0.0 ms)

id | percent
---+--------
 1 | 18%
 3 | 2.6%
 4 | 2.91%
 6 | 10%
(4 rows, 0.1 ms)
```

- Post 3 had +1 and −1. Hari changed +1 to −1, so the score went from 0 to −2.
- `RETURNING id` gives the new post's id at once (chapter 15).

## Step 7: JSON over HTTP

The HTTP API (chapter 8) sends a `JSON` column as a **real JSON object**, not as a string. `BYTES` are sent as a string with `\x` and hex. CSV export (`/exp`) writes JSON as text.

11-http.ps1 (it starts a server on port 9948):

```powershell
curl.exe -s "$url/exec?compat=0" --data-binary "SELECT symbol, statements -> 'income' AS income, pdf_sha256 FROM reports WHERE symbol = 'CITY'"

$r = Invoke-RestMethod -Method Post "$url/exec" -Body "SELECT symbol, statements FROM reports ORDER BY symbol"
foreach ($row in $r.dataset) { "{0}: net profit {1} {2}" -f $row[0], $row[1].income.net_profit, $row[1].unit }

curl.exe -s -G "$url/exp" --data-urlencode "query=SELECT id, tags FROM news ORDER BY id"
```

```text
{"query":"SELECT symbol, statements -> 'income' AS income, pdf_sha256 FROM reports WHERE symbol = 'CITY'","results":[{"statement":"SELECT symbol, statements -> 'income' AS income, pdf_sha256 FROM reports WHERE symbol = 'CITY'","columns":[{"name":"symbol","type":"STRING"},{"name":"income","type":"JSON"},{"name":"pdf_sha256","type":"BYTES"}],"dataset":[["CITY",{"interest_income":9820.5,"operating_profit":4410.2,"net_profit":3270.1},"\\x9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"]],"count":1,"truncated":false,"rows_affected":0,"message":"","timings":{"parse_us":32,"execute_us":289}}],"timings":{"parse_us":32,"execute_us":289}}
CITY: net profit 3270.1 USD million
VOLT: net profit 338.9 USD million
id,tags
1,"[""results"",""banking""]"
2,"[""results""]"
3,"[""hydro"",""energy""]"
4,[]
```

In JSON, a backslash is written twice, so `"\\x9f86..."` is the text `\x9f86...`.

Other ways in and out:

- `kareladb sql market "..." --format json` also writes JSON columns as objects.
- The PostgreSQL protocol (chapter 14) sends `JSON` as type `json` and `BYTES` as type `bytea`.
- The line protocol (`POST /write`) can fill `JSON` and `BYTES` columns from text fields: `news_feed,symbol=CITY payload="{\"price\": 512.5}"`. Bad JSON is refused with the line number.

## Big files: keep them outside

A `STRING`, `JSON` or `BYTES` value can be **at most 16 MB**. A bigger value gets this error:

```text
column 'body' (STRING): the value is 17000000 bytes; the limit is 16 MB (16777216 bytes). Keep big files outside the database and store their path or URL
```

Values of 1 MB work well: through INSERT, UPDATE, SELECT, the log, checkpoints, restarts, `/exec` and the line protocol (tested).

For PDF files, images and videos, the best plan is:

1. Save the file in a folder or an object store (for example S3-compatible storage).
2. In KarelaDB, store the path or URL (`pdf_url STRING`) and the hash (`pdf_sha256 BYTES`).
3. When you read the file, check the hash.

Why: every change in KarelaDB is written to the log and later to table files, and backups copy everything. Big files make the log, backups and restarts slow. Small things (hashes, thumbnails of a few KB, signatures) are fine in `BYTES`.

Other limits:

| Limit | Value |
|---|---|
| One text, JSON or BYTES value | 16 MB |
| JSON nesting | 256 levels |
| HTTP request body | 64 MB |
| Regular expression | 4096 bytes; `{n,m}` up to 1000; very big jobs stop with an error |

## Summary

| Need | Use |
|---|---|
| Data that differs between rows | a `JSON` column; read with `->`, `->>`, `json_value` |
| Exact numbers from JSON | `CAST(json_value_text(doc, '$.x') AS DECIMAL(2))` |
| Change one key | `UPDATE ... SET doc = json_set(doc, '$.key', value)` |
| Hashes, small binary data | `BYTES`, written `X'0A0B'`, shown `\x0a0b` |
| Text in any language | normal `STRING`; `length`, `left`, `substring` count letters |
| Search in a few thousand rows | `ILIKE`, `LIKE`, `regexp_like` |
| Search in big tables | full-text index, [chapter 17](17-indexes-and-search.md) |
| Counters (posts, votes) | triggers |
| One vote per user | `CREATE UNIQUE INDEX ... (user_id, post_id)` |
| Big files | outside KarelaDB; store the URL and a hash |

## Try it yourself

1. Add `"dividend_pct": 10` to the `profile` of VOLT.
2. List the companies whose profile has a key `branches`, with the number of branches.
3. Find forum posts written in Nepali (hint: `meta ->> 'lang'`, or `regexp_like(body, '[ऀ-ॿ]')`).

<details>
<summary>Answers</summary>

1. `UPDATE companies SET profile = json_set(profile, '$.dividend_pct', 10) WHERE symbol = 'VOLT';`
2. `SELECT symbol, json_value(profile, '$.branches') AS branches FROM companies WHERE json_type(profile, '$.branches') IS NOT NULL;`
3. `SELECT id, body FROM forum_posts WHERE regexp_like(body, '[ऀ-ॿ]');`

</details>

---

Next: [19. Analysis functions](19-analysis-functions.md)
