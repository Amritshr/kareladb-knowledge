# Regular expressions

> Find, count, cut out and replace text with patterns like \d+ (one or more digits).

- Category: Functions — text
- Keywords: regex, regexp, regular expression, pattern, pattern matching, flags, capture group, groups, back reference, look-ahead, lazy, greedy, ~, RLIKE, REGEXP, regexp_match, regexp_matches, regexp_split_to_array, regexp_split_to_table, split with a pattern, regexp_instr, validate email, Nepali digits
- See also: [Text functions](functions-text.md), [WHERE](where.md), [Full-text search](full-text-search.md)

A **regular expression** (regex) is a small pattern that describes text. `\d+` means "one or more digits". `^[A-Z]{2,8}$` means "only 2 to 8 capital letters". Use them to check what a user typed, to find numbers in a news article, or to clean text.

- A `NULL` argument gives `NULL`.
- Upper and lower case must match, unless you give the flag `'i'`.
- The pattern is found **anywhere** in the text. Put `^` at the start and `$` at the end to check the whole text.
- KDB never backtracks (tries the same text again and again). So no pattern can hang the server. A very big job stops with an error.
- Simple searches are easier with [LIKE and ILIKE](where.md). For searching words in many rows (a forum, news), use [full-text search](full-text-search.md). A regular expression reads every row.
- `x ~ 'pattern'` is the same as `regexp_like(x, 'pattern')` (`~*` ignores case). [SIMILAR TO](where.md#similar-to) is a whole-text match written with `%` and `_`.

**Example: Percent numbers people wrote in forum posts**

Setup:

```sql
CREATE TABLE forum_posts (id LONG PRIMARY KEY AUTO, body STRING NOT NULL);
INSERT INTO forum_posts (body) VALUES
  ('Profit is up 18%. I think the price will go up.'),
  ('But NPL is still 2.6%. Wait for the next quarter.'),
  ('नाफा राम्रो छ, तर मूल्य पहिले नै बढिसकेको छ।'),
  ('NPL went down from 2.91% to 2.6%. That is good news.');
```

```sql
SELECT id,
       regexp_substr(body, '\d+(\.\d+)?%') AS first_percent,
       regexp_count(body, '\d+(\.\d+)?%') AS percents
FROM forum_posts
WHERE regexp_like(body, '\d%')
ORDER BY id;
```

Result:

| id (LONG) | first_percent (STRING) | percents (LONG) |
|---|---|---|
| 1 | 18% | 1 |
| 2 | 2.6% | 1 |
| 4 | 2.91% | 2 |

(3 rows)

## regexp_like

Syntax:

```sql
regexp_like(text, pattern)
regexp_like(text, pattern, flags)
```

`true` when the pattern is found somewhere in the text.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING (a number is turned into text) | the text to search in |
| `pattern` | STRING | the [regular expression](functions-regex.md#syntax) |
| `flags` | STRING | `'i'` ignore upper and lower case of English letters; `'c'` case must match (the default) |

- **Returns:** `BOOL`.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** a wrong pattern is an error, not `false`. The flag `'g'` is not allowed here. For a simple "contains" check, `LIKE '%text%'` is enough.

**Example**

```sql
SELECT regexp_like('CITY', '^[A-Z]{2,8}$') AS a, regexp_like('city', '^[A-Z]{2,8}$') AS b, regexp_like('city', '^[A-Z]{2,8}$', 'i') AS ignore_case, regexp_like('CITY', 'IT') AS anywhere;
```

Result:

| a (BOOL) | b (BOOL) | ignore_case (BOOL) | anywhere (BOOL) |
|---|---|---|---|
| true | false | true | true |

(1 row)

**Example: Check an email and a mobile number (Nepal format) when a user registers**

```sql
SELECT email, phone,
       regexp_like(email, '^[\w.+-]+@[\w-]+(\.[\w-]+)+$') AS email_ok,
       regexp_like(phone, '^9[78]\d{8}$') AS phone_ok
FROM (SELECT 'ram.sharma@example.com' AS email, '9841234567' AS phone
      UNION ALL SELECT 'sita@@mail', '98412345'
      UNION ALL SELECT 'hari@northwind.example.com', '9761234567') AS signups;
```

Result:

| email (STRING) | phone (STRING) | email_ok (BOOL) | phone_ok (BOOL) |
|---|---|---|---|
| ram.sharma@example.com | 9841234567 | true | true |
| sita@@mail | 98412345 | false | false |
| hari@northwind.example.com | 9761234567 | true | true |

(3 rows)

**Example: Forum posts written in Nepali (Devanagari letters)**

Setup:

```sql
CREATE TABLE forum_posts (id LONG PRIMARY KEY AUTO, body STRING NOT NULL);
INSERT INTO forum_posts (body) VALUES ('Profit is up 18%.'), ('नाफा राम्रो छ।'), ('CITY को मूल्य बढ्यो');
```

```sql
SELECT id, body FROM forum_posts WHERE regexp_like(body, '[ऀ-ॿ]') ORDER BY id;
```

Result:

| id (LONG) | body (STRING) |
|---|---|
| 2 | नाफा राम्रो छ। |
| 3 | CITY को मूल्य बढ्यो |

(2 rows)

**Example: Look-ahead is not supported** (shows an error)

```sql
SELECT regexp_like('CITY', 'CI(?=TY)');
```

Result:

Error: `line 1, column 8: regexp_like: regular expression 'CI(?=TY)': (?...) forms other than (?:...) are not supported`

## regexp_substr

Syntax:

```sql
regexp_substr(text, pattern)
regexp_substr(text, pattern, flags)
```

The first part of the text that matches the pattern. `NULL` when nothing matches.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING (a number is turned into text) | the text to search in |
| `pattern` | STRING | the [regular expression](functions-regex.md#syntax) |
| `flags` | STRING | `'i'` ignore case; `'c'` case must match (the default) |

- **Returns:** `STRING`, or `NULL` when there is no match.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** it always gives the whole match; there is no argument for a group. To get only group 1, use `regexp_replace(text, '^.*?(pattern).*$', '\1')` (see the example below). The flag `'g'` is not allowed. Oracle and MySQL have more arguments (position, occurrence); KDB does not.

**Example**

```sql
SELECT regexp_substr('EPS 12.50, BVPS 245.3', '\d+\.\d+') AS first_number, regexp_substr('no digits', '\d+') AS none, regexp_substr('City city', 'CITY', 'i') AS ignore_case;
```

Result:

| first_number (STRING) | none (STRING) | ignore_case (STRING) |
|---|---|---|
| 12.50 | NULL | City |

(1 row)

**Example: Find the email address in news articles**

Setup:

```sql
CREATE TABLE news (id LONG PRIMARY KEY AUTO, title STRING NOT NULL, body STRING NOT NULL);
INSERT INTO news (title, body) VALUES
  ('City Bank profit rises 18%', 'City Bank reported a net profit of $3.27 billion for Q4 of 2082/83.'),
  ('Volt River sells record energy', 'The plant produced 2105 GWh this year. Contact: info@voltriver.example.com');
```

```sql
SELECT id, regexp_substr(body, '[\w.]+@[\w.]+\w') AS email
FROM news
WHERE regexp_like(body, '\w+@\w+');
```

Result:

| id (LONG) | email (STRING) |
|---|---|
| 2 | info@voltriver.example.com |

(1 row)

**Example: Only the number, without the % sign (a group)**

```sql
SELECT regexp_substr('Profit is up 18.5% this year', '\d+(\.\d+)?%') AS with_sign,
       regexp_replace('Profit is up 18.5% this year', '^.*?(\d+(\.\d+)?)%.*$', '\1') AS group_1;
```

Result:

| with_sign (STRING) | group_1 (STRING) |
|---|---|
| 18.5% | 18.5 |

(1 row)

## regexp_count

Syntax:

```sql
regexp_count(text, pattern)
regexp_count(text, pattern, flags)
```

How many times the pattern is found in the text. The matches do not overlap: after a match, the search goes on after its end.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING (a number is turned into text) | the text to search in |
| `pattern` | STRING | the [regular expression](functions-regex.md#syntax) |
| `flags` | STRING | `'i'` ignore case; `'c'` case must match (the default) |

- **Returns:** `LONG`. `0` when nothing matches.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** a pattern that can match empty text also counts the empty places: `regexp_count('abc', '')` is `4`.

**Example**

```sql
SELECT regexp_count('a1b22c333', '\d+') AS numbers, regexp_count('a1b22c333', '\d') AS digits, regexp_count('CITY city', 'city', 'i') AS ignore_case, regexp_count('abc', '') AS empty_pattern;
```

Result:

| numbers (LONG) | digits (LONG) | ignore_case (LONG) | empty_pattern (LONG) |
|---|---|---|---|
| 3 | 6 | 2 | 4 |

(1 row)

**Example: Words in English and Nepali posts**

Setup:

```sql
CREATE TABLE forum_posts (id LONG PRIMARY KEY AUTO, body STRING NOT NULL);
INSERT INTO forum_posts (body) VALUES ('Profit is up 18%. I think the price will go up.'), ('सिटी बैंकको नाफा १८ प्रतिशतले बढ्यो।');
```

```sql
SELECT id, regexp_count(body, '\w+') AS words, length(body) AS letters FROM forum_posts ORDER BY id;
```

Result:

| id (LONG) | words (LONG) | letters (LONG) |
|---|---|---|
| 1 | 11 | 47 |
| 2 | 6 | 36 |

(2 rows)

**Example: Hashtags in a post**

```sql
SELECT regexp_count('Buy #CITY and #VOLT now #market', '#\w+') AS tags,
       regexp_substr('Buy #CITY and #VOLT now #market', '#\w+') AS first_tag;
```

Result:

| tags (LONG) | first_tag (STRING) |
|---|---|
| 3 | #CITY |

(1 row)

## regexp_replace

Syntax:

```sql
regexp_replace(text, pattern, replacement)
regexp_replace(text, pattern, replacement, flags)
```

Replaces the **first** match of the pattern with `replacement`. With the flag `'g'` (global), it replaces **every** match.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING (a number is turned into text) | the text to change |
| `pattern` | STRING | the [regular expression](functions-regex.md#syntax) |
| `replacement` | STRING | the new text. `\1` to `\9` = the text of group 1 to 9; `\0` or `\&` = the whole match; a backslash written two times = one backslash |
| `flags` | STRING | any mix of `'g'` every match, `'i'` ignore case, `'c'` case must match. Example: `'gi'` |

- **Returns:** `STRING`. The text is unchanged when nothing matches.
- **NULL:** `NULL` when any argument is `NULL`.
- **Notes:** without `'g'` only the first match changes (like PostgreSQL; in MySQL every match changes). A group that took no part (or does not exist, like `\9` in a pattern with 1 group) puts in empty text. A group is a part of the pattern in `( )`; groups are numbered by their `(` from left to right. When `'i'` and `'c'` are both given, the last one wins.

**Example**

```sql
SELECT regexp_replace('a1b2c3', '\d', '#') AS first_only, regexp_replace('a1b2c3', '\d', '#', 'g') AS every, regexp_replace('City CITY', 'city', 'X', 'gi') AS ignore_case, regexp_replace('CITY', 'x', 'y') AS no_match;
```

Result:

| first_only (STRING) | every (STRING) | ignore_case (STRING) | no_match (STRING) |
|---|---|---|---|
| a#b2c3 | a#b#c# | X X | CITY |

(1 row)

**Example: Clean spaces in text a user typed**

```sql
SELECT '[' || regexp_replace(trim('  City    Bank   Limited '), '\s+', ' ', 'g') || ']' AS cleaned;
```

Result:

| cleaned (STRING) |
|---|
| [City Bank Limited] |

(1 row)

**Example: Groups: turn 2082/83 into 2082-2083**

```sql
SELECT regexp_replace('FY 2082/83', '(\d{2})(\d{2})/(\d{2})', '\1\2-\1\3') AS fiscal_year,
       regexp_replace('CITY', '.', '[\&]', 'g') AS whole_match;
```

Result:

| fiscal_year (STRING) | whole_match (STRING) |
|---|---|
| FY 2082-2083 | [C][I][T][Y] |

(1 row)

**Example: A URL part (slug) from a news title, and text without HTML tags**

```sql
SELECT lower(trim(regexp_replace('City Bank: Q4 Results!', '[^a-z0-9]+', '-', 'gi'), '-')) AS slug,
       regexp_replace('<p>Index <b>closes</b> at 2,840</p>', '<[^>]*>', '', 'g') AS plain_text,
       CAST(regexp_replace('$1,234,567', '[^0-9]', '', 'g') AS LONG) AS amount;
```

Result:

| slug (STRING) | plain_text (STRING) | amount (LONG) |
|---|---|---|
| city-bank-q4-results | Index closes at 2,840 | 1234567 |

(1 row)

**Example: Unknown flag** (shows an error)

```sql
SELECT regexp_replace('a1b2', '\d', '#', 'x');
```

Result:

Error: `line 1, column 8: regexp_replace: unknown flag 'x'; use 'i' to ignore case and 'g' to replace every match`

<a id="flags"></a>

## Flags

Syntax:

```sql
regexp_like(text, pattern, 'i')
regexp_replace(text, pattern, replacement, 'gi')
```

The last argument of the regexp functions is a text of flags. Each letter is one flag.

| Flag | Meaning | Allowed in |
|---|---|---|
| `i` | ignore upper and lower case (English letters A-Z only) | all four functions |
| `c` | case must match (this is the default) | all four functions |
| `g` | replace every match, not only the first | only `regexp_replace` |

- **NULL:** a `NULL` flags text gives `NULL`.
- **Notes:** an empty text `''` means no flags. Any other letter is an error. PostgreSQL flags like `n`, `s`, `x` or `m` are not supported here; `regexp_match` and friends take [PostgreSQL flags](#pg-flags). There are no flags inside the pattern: `(?i)` is an error.

**Example**

```sql
SELECT regexp_like('market', 'MARKET') AS default_case, regexp_like('market', 'MARKET', 'i') AS i_flag, regexp_like('market', 'MARKET', 'ic') AS last_wins, regexp_replace('a-b-c', '-', '+', 'g') AS g_flag;
```

Result:

| default_case (BOOL) | i_flag (BOOL) | last_wins (BOOL) | g_flag (STRING) |
|---|---|---|---|
| false | true | false | a+b+c |

(1 row)

**Example: The flag g only works in regexp_replace** (shows an error)

```sql
SELECT regexp_like('CITY', 'T', 'g');
```

Result:

Error: `line 1, column 8: regexp_like: unknown flag 'g'; use 'i' to ignore case`

## regexp_match

Syntax:

```sql
regexp_match(text, pattern)
regexp_match(text, pattern, flags)
```

The first match, as PostgreSQL gives it: an array of what each `(...)` group caught, or of the whole match when the pattern has no groups. `NULL` when nothing matches.

| Argument | Type | Meaning |
|---|---|---|
| `text` | STRING | the text to search |
| `pattern` | STRING | the regular expression |
| `flags` | STRING | optional [PostgreSQL flags](#pg-flags); `g` is refused (use `regexp_matches`) |

- **Returns:** an array of `STRING` (a `JSON` list; `{a,b}` on the Postgres port). A group that took no part is `NULL`.
- **Notes:** take one part with `[n]`: `(regexp_match('abc123', '(\d+)'))[1]` is `123`. A pattern written in the query is compiled once for all rows.

**Example**

```sql
SELECT regexp_match('abc123', '(\d+)') AS groups,
       (regexp_match('abc123', '(\d+)'))[1] AS digits,
       regexp_match('foobarbequebaz', 'bar.*que') AS whole,
       regexp_match('abc', 'x') AS no_match;
```

Result:

| groups (TEXT[]) | digits (STRING) | whole (TEXT[]) | no_match (TEXT[]) |
|---|---|---|---|
| ["123"] | 123 | ["barbeque"] | NULL |

(1 row)

**Example: Split a log line into its parts**

```sql
SELECT m[1] AS method, m[2] AS path, m[3]::int AS status
FROM (SELECT regexp_match('GET /api/quotes 200', '^(\w+) (\S+) (\d+)$') AS m) t;
```

Result:

| method (STRING) | path (STRING) | status (INT) |
|---|---|---|
| GET | /api/quotes | 200 |

(1 row)

## regexp_matches

Syntax:

```sql
regexp_matches(text, pattern)
regexp_matches(text, pattern, flags)
```

Like [regexp_match](#regexp-match), but it gives **rows**: one row (an array) per match with the flag `g`, at most one without it, and no row when nothing matches.

- **Returns:** rows of arrays of `STRING`. In `FROM` the column is named after the function or the alias: `FROM regexp_matches(...) AS m`.
- **Notes:** in `FROM` the arguments must be constants; for a column write `SELECT id, regexp_matches(col, ...) FROM t`. An empty match moves on by one character, as in PostgreSQL.

**Example**

```sql
SELECT m[1] AS key, m[2] AS value
FROM regexp_matches('k1=v1, k2=v2', '(\w+)=(\w+)', 'g') AS m;
```

Result:

| key (STRING) | value (STRING) |
|---|---|
| k1 | v1 |
| k2 | v2 |

(2 rows)

**Example**

```sql
SELECT count(*) AS digits FROM regexp_matches('a1b2c3', '\d', 'g');
```

Result:

| digits (LONG) |
|---|
| 3 |

(1 row)

<a id="regexp-split"></a>

## regexp_split_to_array, regexp_split_to_table

Syntax:

```sql
regexp_split_to_array(text, pattern [, flags])
regexp_split_to_table(text, pattern [, flags])
```

Cuts the text wherever the pattern matches. `_to_array` gives one list, `_to_table` one row per piece.

- **Returns:** an array of `STRING`, or rows of `STRING`.
- **Notes:** an empty text gives one empty piece. As in PostgreSQL an empty match only cuts between characters: `regexp_split_to_array('hello world', '\s*')` gives the 10 letters. The flag `g` is refused.

**Example**

```sql
SELECT regexp_split_to_array('a,b;c', '[,;]') AS parts,
       array_length(regexp_split_to_array('a,b;c', '[,;]'), 1) AS how_many;
```

Result:

| parts (TEXT[]) | how_many (LONG) |
|---|---|
| ["a","b","c"] | 3 |

(1 row)

**Example**

```sql
SELECT word FROM regexp_split_to_table('the quick  brown fox', '\s+') AS t(word);
```

Result:

| word (STRING) |
|---|
| the |
| quick |
| brown |
| fox |

(4 rows)

<a id="pg-flags"></a>

## PostgreSQL flags

`regexp_match`, `regexp_matches` and the split functions take PostgreSQL's flag letters:

| Flag | Meaning |
|---|---|
| `g` | every match (`regexp_matches` only) |
| `i` / `c` | ignore case / case must match; the last one wins |
| `q` | the pattern is plain text: `.` is a dot |
| `s`, `t` | accepted: what KDB always does (`.` matches a line break, no spaces-ignored syntax) |

- **Errors:** PostgreSQL's flags `n`, `m`, `p`, `w`, `x`, `b` and `e` are refused (SQLSTATE 0A000), because they would change what matches. Any other letter: "invalid regular expression option" (22023). A wrong pattern: SQLSTATE 2201B.

**Example**

```sql
SELECT regexp_match('ABC', 'b', 'i') AS i_flag, regexp_match('a.c', '.', 'q') AS q_flag;
```

Result:

| i_flag (TEXT[]) | q_flag (TEXT[]) |
|---|---|
| ["B"] | ["."] |

(1 row)

<a id="syntax"></a>

## Regular expression syntax

Syntax:

```sql
.   [abc]   [^abc]   [a-z]   [[:alpha:]]   \d \w \s \D \W \S
^   $   \b   \B
(group)   (?:group)   a|b
*   +   ?   {n}   {n,}   {n,m}   *?   +?   ??   {n,m}?
\.  \(  \n  \t  \r  \f  \v  \uXXXX
```

What you can write in a pattern. One character is one letter, also a Nepali letter or sign.

| You write | It matches |
|---|---|
| `a`, `न` | that character |
| `.` | any one character, also a line break |
| `[abc]` | one of a, b, c |
| `[^abc]` | one character that is **not** a, b or c |
| `[a-z]`, `[०-९]`, `[ऀ-ॿ]` | one character in the range (the last one is every Devanagari character) |
| `[[:alpha:]]` `[[:digit:]]` `[[:alnum:]]` `[[:upper:]]` `[[:lower:]]` `[[:space:]]` `[[:punct:]]` | English letters, digits 0-9, both, capitals, small letters, spaces, punctuation (only inside `[ ]`) |
| `\d` / `\D` | a digit 0-9 / not a digit |
| `\w` / `\W` | a word character: letters of any language (also Nepali letters, signs and digits ०-९), 0-9 and `_` / not one |
| `\s` / `\S` | a space, tab or line break / not one |
| `^` / `$` | the start / the end of the **whole** text |
| `\b` / `\B` | a word edge / not a word edge |
| `(...)` | a group with a number (for `\1` in `regexp_replace`) |
| `(?:...)` | a group without a number |
| `a|b` | a or b; the first one that matches wins (like Perl, Python and JavaScript) |
| `*` `+` `?` | 0 or more, 1 or more, 0 or 1 times (as many as possible) |
| `{n}` `{n,}` `{n,m}` | exactly n, n or more, n to m times |
| `*?` `+?` `??` `{n,m}?` | the same, but as few as possible (lazy) |
| `\.` `\(` `\[` `\$` ... | the punctuation character itself (a backslash written two times is one backslash) |
| `\n` `\t` `\r` `\f` `\v` | line break, tab, carriage return, form feed, vertical tab |
| `\u` and 4 hex digits | the character with that Unicode number |

**Not supported** (you get a clear error):

| You write | Instead |
|---|---|
| back references in the pattern: `(a)\1` | not possible; `\1` works only in the replacement of `regexp_replace` |
| look-ahead and look-behind: `(?=...)` `(?!...)` `(?<=...)` | match more text, then cut it with a group in `regexp_replace` |
| named groups `(?P<name>...)`, flags in the pattern `(?i)` | numbered groups; the flags argument |
| `\p{L}` and other Unicode classes | `\w`, or a range like `[ऀ-ॿ]` |
| `\A` `\z` `\Z` | `^` and `$` (they always mean the start and end of the whole text) |
| `[[:word:]]`, `[[:xdigit:]]` and other classes not in the table | `[\w]`, `[0-9a-fA-F]` |

- **Notes:** `\d` is only 0-9. For Nepali digits write `[०-९]`, or `[0-9०-९]` for both. `^` and `$` do not match at line breaks inside the text. A `{` that does not start a count like `{2}` is a normal character. `[[:alpha:]]`, `[[:upper:]]` and `[[:lower:]]` are English letters only; `\w` also has Nepali letters.
- **Limits:** a pattern can be at most 4096 bytes, have at most 32 numbered groups and counts up to `{1000}`. A pattern that becomes too big, or needs too much work for a very long text, stops with an error.
- In SQL text, a backslash is a normal character. Write `'\d+'` with one backslash. To put `'` in the pattern, write it twice: `'it''s'`.

**Example: Nepali and English digits**

```sql
SELECT regexp_like('१८', '\d') AS d_nepali, regexp_like('18', '\d') AS d_english,
       regexp_substr('नाफा १८ प्रतिशत', '[०-९]+') AS nepali_number,
       regexp_count('सिटी बैंकको नाफा १८ प्रतिशतले बढ्यो।', '\w+') AS nepali_words;
```

Result:

| d_nepali (BOOL) | d_english (BOOL) | nepali_number (STRING) | nepali_words (LONG) |
|---|---|---|---|
| false | true | १८ | 6 |

(1 row)

**Example: Greedy and lazy, and the first alternative wins**

```sql
SELECT regexp_substr('<b>CITY</b> and <b>COAST</b>', '<b>.*</b>') AS greedy,
       regexp_substr('<b>CITY</b> and <b>COAST</b>', '<b>.*?</b>') AS lazy,
       regexp_substr('CITY', 'CI|CITY') AS first_alternative,
       regexp_like('CITY Bank', '\bBank') AS word_edge,
       regexp_like('CITY Bank', '\bITY') AS no_word_edge;
```

Result:

| greedy (STRING) | lazy (STRING) | first_alternative (STRING) | word_edge (BOOL) | no_word_edge (BOOL) |
|---|---|---|---|---|
| <b>CITY</b> and <b>COAST</b> | <b>CITY</b> | CI | true | false |

(1 row)

**Example: ^ and $ are the start and end of the whole text**

```sql
SELECT regexp_like('line one
line two', '^line two') AS start_of_line_2,
       regexp_like('line one
line two', 'one.line') AS dot_matches_line_break;
```

Result:

| start_of_line_2 (BOOL) | dot_matches_line_break (BOOL) |
|---|---|
| false | true |

(1 row)

**Example: Back references are not supported** (shows an error)

```sql
SELECT regexp_like('CITY CITY', '(\w+) \1');
```

Result:

Error: `line 1, column 8: regexp_like: regular expression '(\w+) \1': back references like \1 are not supported in a pattern`

**Example: A broken pattern** (shows an error)

```sql
SELECT regexp_substr('CITY', '(CI');
```

Result:

Error: `line 1, column 8: regexp_substr: regular expression '(CI': '(' has no matching ')'`

**Example: Counts above 1000 are refused** (shows an error)

```sql
SELECT regexp_like('CITY', 'A{2000}');
```

Result:

Error: `line 1, column 8: regexp_like: regular expression 'A{2000}': a count in {n,m} is larger than 1000`
