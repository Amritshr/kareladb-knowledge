# Full-text search

> Find rows that contain words, rank the best matches first, and mark the found words in bold.

- Category: Indexes & search
- Keywords: full-text, fulltext, text search, search engine, find words, FULLTEXT, BM25, relevance, ranking, best matches, phrase, prefix, wildcard, exclude word, stemming, stem, stop words, language, case folding, Porter, Nepali search, Devanagari, bold, search result page, news search, forum search, how the index is used, count from the index, text match is checked on them, word positions
- See also: [Indexes](indexes.md), [Text functions](functions-text.md), [Regular expressions](functions-regex.md), [WHERE](where.md), [EXPLAIN](explain.md)

**Full-text search** finds rows that contain some **words**, like a search box on a website. `LIKE '%bank%'` must read every row and check every letter; it also finds `bank` inside `embankment`. A **FULLTEXT index** keeps a list of words, and for each word the rows that have it. So a search in 200,000 news articles takes a few milliseconds.

Three functions work together:

- [match](full-text-search.md#match) says **if** a row has the words (use it in `WHERE`).
- [search_rank](full-text-search.md#search-rank) says **how well** a row matches (use it in `ORDER BY`).
- [highlight](full-text-search.md#highlight) returns the text with the found words inside `<b>` and `</b>`.

The examples use a `news` table: `id`, `symbol`, `published_at`, `title`, `body`, with articles in English and Nepali.

**Example: A news search page: the 3 best articles for 'bank'** (sample data: content-news)

Setup:

```sql
CREATE FULLTEXT INDEX news_text ON news (title, body);
```

```sql
SELECT id,
       highlight(title, 'bank') AS title,
       round(search_rank(title, body, 'bank'), 3) AS rank
FROM news
WHERE MATCH(title, body, 'bank')
ORDER BY search_rank(title, body, 'bank') DESC
LIMIT 3;
```

Result:

| id (LONG) | title (STRING) | rank (DOUBLE) |
|---|---|---|
| 5 | Coastal <b>Bank</b> merger talks | 0.845 |
| 1 | City <b>Bank</b> profit rises 18% | 0.816 |
| 4 | Market index closes at 2,840 | 0.562 |

(3 rows)

<a id="create-fulltext-index"></a>

## CREATE FULLTEXT INDEX

Syntax:

```sql
CREATE FULLTEXT INDEX [IF NOT EXISTS] name ON table (column [, column ...]) [WITH (language = 'english')]
```

Makes a full-text index on one or more text columns. With several columns, they are searched together as one text.

| Argument | Type | Meaning |
|---|---|---|
| `name` | name | the index name, unique in the whole database |
| `table` | name | the table |
| `column` | names | 1 to 16 `STRING`, `SYMBOL` or `JSON` columns |
| `language` | text | optional: `'english'` cuts words to their stem and leaves out stop words (see [Language](full-text-search.md#language)); `'simple'` is the default |

- **Returns:** a message: `index 'name' created on table 'table' (N rows)`.
- **NULL:** a `NULL` column counts as empty text.
- **Notes:**
  - A query uses the index when `match(...)` names **the same columns** as the index (the order of the columns does not matter). `match(title, 'bank')` does not use an index on `(title, body)`.
  - `match`, `search_rank` and `highlight` also work **without** an index. Then KarelaDB reads every row. That is fine for small tables.
  - Like every index it lives in memory. `kareladb serve` builds it on a background thread right after the database opens, after the other indexes (see [built at open](indexes.md#warm)); a query that needs it sooner builds it itself. It takes a few seconds for 200,000 articles. `INSERT`, `UPDATE` and `DELETE` keep it up to date.
  - Since 2026-10-02 the words of each partition are also saved on disk, so a restart does not split every row into words again (see [segments on disk](#segments)).
  - The index keeps where each word is in the text, so a phrase (`"net profit"`) is also found from the index. With them, the index took a little less memory than the text itself (302 MB for 378 MB of news, measured before 2026-10-02).
  - Since 2026-10-02 the index is smaller and its searches skip more. Where a row is: two numbers (partition, row), about 40 bytes a row instead of about 200. The rows of a word are packed in blocks of 128; each block notes its last row, so a search for a rare word with a common one jumps over whole blocks of the common word. Each block also notes the highest count of the word in it, for faster top-N ranking later.
  - `GET /api/stats` shows its memory under `memory`: `fulltext_index_bytes` (part of `index_bytes`), with `fulltext_indexes`, `fulltext_docs` and `fulltext_terms` (distinct words). JSON (GIN) indexes are counted there too.
  - `DROP INDEX`, `SHOW INDEXES` and the other rules of [indexes](indexes.md) are the same. A FULLTEXT index cannot be `UNIQUE`.
  - A column of another type (`LONG`, `TIMESTAMP`, ...) gives an error.

**Example: Search news in the title and the body** (sample data: content-news)

```sql
CREATE FULLTEXT INDEX news_text ON news (title, body);
SELECT id, title FROM news WHERE MATCH(title, body, 'city bank') ORDER BY id;
```

Result:

`CREATE FULLTEXT INDEX news_text ON news (title, body)`

```text
index 'news_text' created on table 'news' (5 rows)
```

`SELECT id, title FROM news WHERE match(title, body, 'city bank') ORDER BY id`

| id (LONG) | title (STRING) |
|---|---|
| 1 | City Bank profit rises 18% |
| 4 | Market index closes at 2,840 |

(2 rows)

**Example: EXPLAIN shows the index** (sample data: content-news)

Setup:

```sql
CREATE FULLTEXT INDEX news_text ON news (title, body);
```

```sql
EXPLAIN SELECT id FROM news WHERE MATCH(body, title, 'bank');
EXPLAIN SELECT id FROM news WHERE MATCH(title, 'bank');
```

Result:

`EXPLAIN SELECT id FROM news WHERE match(body, title, 'bank')`

| plan (STRING) |
|---|
| scan table news (1 of 1 partitions, about 5 rows) |
| use index news_text (full-text search) |
| build 1 of 5 stored column(s) per row: id |
| engine: column |

(4 rows)

`EXPLAIN SELECT id FROM news WHERE match(title, 'bank')`

| plan (STRING) |
|---|
| scan table news (1 of 1 partitions, about 5 rows) |
| build 2 of 5 stored column(s) per row: id, title |
| filter while scanning: 1 condition(s) |
| engine: row (a condition the column engine does not do) |

(4 rows)

The first query uses `news_text` (same columns, other order). The second names only `title`, so it reads the table.

**Example: Forum: search the posts** (sample data: content-forum)

Setup:

```sql
CREATE FULLTEXT INDEX posts_body ON posts (body);
```

```sql
SELECT id, thread_id, author, body FROM posts WHERE MATCH(body, 'bonus') ORDER BY id;
```

Result:

| id (LONG) | thread_id (LONG) | author (STRING) | body (STRING) |
|---|---|---|---|
| 4 | 1 | gita | What about the bonus shares? |
| 5 | 1 | ram | Bonus is 10% this time. |

(2 rows)

**Example: Changes are in the index at once** (sample data: content-news)

Setup:

```sql
CREATE FULLTEXT INDEX news_text ON news (title, body);
```

```sql
UPDATE news SET body = 'Coastal Bank Bank and Prabhu Bank signed the merger.' WHERE id = 5;
SELECT id FROM news WHERE MATCH(title, body, 'prabhu');
DELETE FROM news WHERE id = 4;
SELECT id FROM news WHERE MATCH(title, body, 'gainers');
```

Result:

`UPDATE news SET body = 'Coastal Bank Bank and Prabhu Bank signed the merger.' WHERE id = 5`

```text
1 row(s) updated
```

`SELECT id FROM news WHERE match(title, body, 'prabhu')`

| id (LONG) |
|---|
| 5 |

(1 row)

`DELETE FROM news WHERE id = 4`

```text
1 row(s) deleted
```

`SELECT id FROM news WHERE match(title, body, 'gainers')`

| id (LONG) |
|---|

(0 rows)

**Example: Only text columns** (sample data: content-news; shows an error)

```sql
CREATE FULLTEXT INDEX news_time ON news (published_at);
```

Result:

Error: `index 'news_time' on table 'news' is FULLTEXT but column 'published_at' is TIMESTAMP; expected STRING (text) columns`

<a id="language"></a>

## Language: stems and stop words

Syntax:

```sql
CREATE FULLTEXT INDEX name ON table (columns) WITH (language = 'english')
```

By default a search finds **whole words** only: `planning` does not find `plans`. An index made `WITH (language = 'english')` cuts each word to its **stem** first (the Porter2 English stemmer), so `plans`, `planned` and `planning` are all `plan`.

What `'english'` changes:

| Rule | Example |
|---|---|
| English words become their stem | `running`, `runs`, `run` are one word; `ran` stays `ran` |
| Stop words are left out | `the`, `of`, `and`, `is`, ... are not in the index; a search for `the` alone finds nothing |
| Upper and lower case match for Latin, Greek and Cyrillic letters | `CAFÉ` = `café`, `МОСКВА` = `москва` |
| Phrases skip stop words | `"talks about a merger"` finds `talks about the merger` |
| A prefix is stemmed too, and is never a stop word | `planning*` finds `plans`; `the*` finds `theory` |

- **Notes:**
  - The search text is cut with the **same** rules as the rows. `match`, `search_rank` and `highlight` on the columns of such an index use them too, also when they read the rows instead of the index.
  - Words with digits, Nepali and other scripts are not stemmed.
  - An index without the option (or `language = 'simple'`) works exactly as before.
  - To change the language of an index, `DROP INDEX` it and create it again. A table has one FULLTEXT index for the same columns.
  - Other languages give an error. Data with such an index needs KarelaDB 2026-10-02 or newer (see [versions](versions.md)).

**Example: 'planning' finds 'plans' and 'planned' only with the English analyzer** (sample data: content-news)

Setup:

```sql
CREATE FULLTEXT INDEX news_en ON news (title, body) WITH (language = 'english');
```

```sql
SELECT id, title FROM news WHERE MATCH(title, body, 'planning') ORDER BY id;
SELECT id, highlight(body, 'shares') AS body FROM news WHERE MATCH(title, body, 'share') ORDER BY id;
SELECT match('Coastal Bank plans', 'planning') AS without_index;
```

Result:

`SELECT id, title FROM news WHERE match(title, body, 'planning') ORDER BY id`

| id (LONG) | title (STRING) |
|---|---|
| 3 | Hydropower company plans IPO |
| 5 | Coastal Bank merger talks |

(2 rows)

`SELECT id, highlight(body, 'shares') AS body FROM news WHERE match(title, body, 'share') ORDER BY id`

| id (LONG) | body (STRING) |
|---|---|
| 3 | Volt River Hydropower will sell new <b>shares</b>. The IPO opens next month. |
| 4 | Banks and hydropower <b>shares</b> moved up. City Bank led the gainers. |

(2 rows)

`SELECT match('Coastal Bank plans', 'planning') AS without_index`

| without_index (BOOL) |
|---|
| false |

(1 row)

**Example: Stop words do not count in a phrase** (sample data: content-news)

Setup:

```sql
CREATE FULLTEXT INDEX news_en ON news (title, body) WITH (language = 'english');
```

```sql
SELECT id FROM news WHERE MATCH(title, body, '"talks about the merger"');
SELECT count(*) AS found FROM news WHERE MATCH(title, body, 'the');
```

Result:

`SELECT id FROM news WHERE match(title, body, '"talks about the merger"')`

| id (LONG) |
|---|
| 5 |

(1 row)

`SELECT count(*) AS found FROM news WHERE match(title, body, 'the')`

| found (LONG) |
|---|
| 0 |

(1 row)

**Example: Only english and simple** (sample data: content-news; shows an error)

```sql
CREATE FULLTEXT INDEX news_fr ON news (title, body) WITH (language = 'french');
```

Result:

Error: `index 'news_fr' on table 'news' has language 'french'; expected 'english' or 'simple'`

<a id="match"></a>

## match

Syntax:

```sql
match(column [, column ...], 'words')
MATCH(column [, column ...], 'words')
```

`true` when the text of the columns has the words of the search text. The search text can have phrases, prefixes and words that must not be there (see [Search text](full-text-search.md#search-syntax)).

| Argument | Type | Meaning |
|---|---|---|
| `column` | STRING, SYMBOL or JSON (other values are turned into text) | the text to search; several columns are searched as one text |
| `words` | STRING | the search text; always the **last** argument |

- **Returns:** `BOOL`.
- **NULL:** `NULL` search text gives `NULL` (the row is not found). A `NULL` column counts as empty text.
- **Notes:**
  - English letters A-Z: case does not matter. Other letters must be the same.
  - Whole words only, no stemming: `bank` does not find `banks`. Use a prefix (`bank*`), or an index made [WITH (language = 'english')](full-text-search.md#language).
  - Every word must be there. There is no `OR` inside the search text. For "one word or the other" write two calls: `MATCH(body, 'bonus') OR MATCH(body, 'dividend')` (this reads every row).
  - A search with no word to find (empty, only `-word`, only `*`) finds nothing.
  - At least 2 arguments (1 column and the words), at most 64.

**Example: Every word must be there, in any order and any case** (sample data: content-news)

```sql
SELECT id, title FROM news WHERE MATCH(title, body, 'BANK city') ORDER BY id;
```

Result:

| id (LONG) | title (STRING) |
|---|---|
| 1 | City Bank profit rises 18% |
| 4 | Market index closes at 2,840 |

(2 rows)

**Example: Nepali words, and the same number in Devanagari digits** (sample data: content-news)

```sql
SELECT id, title FROM news WHERE MATCH(title, body, 'नाफा') ORDER BY id;
SELECT id FROM news WHERE MATCH(title, body, '१२.५') ORDER BY id;
```

Result:

`SELECT id, title FROM news WHERE match(title, body, 'नाफा') ORDER BY id`

| id (LONG) | title (STRING) |
|---|---|
| 2 | सिटी बैंकको नाफा बढ्यो |

(1 row)

`SELECT id FROM news WHERE match(title, body, '१२.५') ORDER BY id`

| id (LONG) |
|---|
| 1 |
| 2 |

(2 rows)

**Example: Search together with other conditions** (sample data: content-news)

```sql
SELECT id, symbol, title
FROM news
WHERE MATCH(title, body, 'bank') AND published_at >= '2026-09-01'
ORDER BY id;
```

Result:

| id (LONG) | symbol (STRING) | title (STRING) |
|---|---|---|
| 4 | NULL | Market index closes at 2,840 |
| 5 | COAST | Coastal Bank merger talks |

(2 rows)

**Example: match on plain text values** (sample data: content-news)

```sql
SELECT match('City Bank profit rises', 'BANK') AS a,
       match('City Bank profit rises', 'banks') AS b,
       match('City Bank profit rises', 'bank*') AS c,
       match('City Bank', NULL) AS d;
```

Result:

| a (BOOL) | b (BOOL) | c (BOOL) | d (STRING) |
|---|---|---|---|
| true | false | true | NULL |

(1 row)

**Example: The search text is missing** (sample data: content-news; shows an error)

```sql
SELECT id FROM news WHERE MATCH(title);
```

Result:

Error: `line 1, column 27: function 'match' takes 2 to 64 argument(s), got 1`

<a id="fulltext-speed"></a>

## How the index is used

Syntax:

```sql
use index name (full-text search)
use index other (...) (r row(s), the text match is checked on them)
```

With a FULLTEXT index on the same columns as `match`, KarelaDB **always** uses it. It never goes back to reading the text of every row, even for a word that is in most rows.

| Query | What KarelaDB does |
|---|---|
| `WHERE MATCH(...)` | finds the rows in the index, then reads only those rows |
| `SELECT count(*) ... WHERE MATCH(...)` and nothing else in `WHERE` | counts in the index; no row is read |
| a phrase, `"hydro power"` | answered from the word positions in the index |
| `ORDER BY search_rank(...) DESC LIMIT n` | takes the `n` best rows from the index (see [search_rank](full-text-search.md#search-rank)) |
| `ORDER BY id LIMIT n`, or no `ORDER BY`, on a table with `id` as its `PRIMARY KEY` | reads only the first `n` matching rows |
| `MATCH(...) AND symbol = 'COAST'`, with an index on `symbol` too | uses the index that finds fewer rows; the other condition is checked on those rows only |
| `MATCH(...) OR MATCH(...)` | no index: every row is read |

- **Notes:**
  - The `ORDER BY ... LIMIT` shortcut is for relational tables only, when `ORDER BY` is the first key columns, ascending, and those columns are numbers or times that cannot be `NULL`. On a time-series table the matching rows are sorted after they are found.
  - `EXPLAIN` shows the index it picks, but not the count or the `LIMIT` shortcut: those are decided while the query runs.

**Example: A symbol finds fewer rows than the word: its index goes first** (sample data: content-news)

Setup:

```sql
CREATE FULLTEXT INDEX news_text ON news (title, body);
CREATE INDEX news_symbol ON news (symbol);
```

```sql
EXPLAIN SELECT id FROM news WHERE MATCH(title, body, 'bank');
EXPLAIN SELECT id FROM news WHERE MATCH(title, body, 'bank') AND symbol = 'COAST';
SELECT id, title FROM news WHERE MATCH(title, body, 'bank') AND symbol = 'COAST';
```

Result:

`EXPLAIN SELECT id FROM news WHERE match(title, body, 'bank')`

| plan (STRING) |
|---|
| scan table news (1 of 1 partitions, about 5 rows) |
| use index news_text (full-text search) |
| build 1 of 5 stored column(s) per row: id |
| engine: column |

(4 rows)

`EXPLAIN SELECT id FROM news WHERE match(title, body, 'bank') AND symbol = 'COAST'`

| plan (STRING) |
|---|
| scan table news (1 of 1 partitions, about 5 rows) |
| use index news_symbol (symbol = value) (1 row(s), the text match is checked on them) |
| build 4 of 5 stored column(s) per row: id, symbol, title, body |
| filter while scanning: 2 condition(s) |
| engine: row (a condition the column engine does not do) |

(5 rows)

`SELECT id, title FROM news WHERE match(title, body, 'bank') AND symbol = 'COAST'`

| id (LONG) | title (STRING) |
|---|---|
| 5 | Coastal Bank merger talks |

(1 row)

**Example: Count the articles with a phrase: from the index** (sample data: content-news)

Setup:

```sql
CREATE FULLTEXT INDEX news_text ON news (title, body);
```

```sql
SELECT count(*) AS articles FROM news WHERE MATCH(title, body, '"city bank"');
```

Result:

| articles (LONG) |
|---|
| 2 |

(1 row)

<a id="segments"></a>

## Segments on disk

Splitting text into words is the slow part of building a full-text index. Since 2026-10-02 KarelaDB saves the words of each partition in a file, a **segment**, so the next open builds the index from those files and reads no row.

| When | What happens |
|---|---|
| the database closes, or checkpoints while it is idle | a segment is written for each partition whose files changed since its last segment |
| the index is built (at open, or by the first query) | a partition with a segment that fits takes its words from it; the others are read and split into words as before |
| a segment is damaged | it is ignored, the server log says `warning: damaged full-text segment ...`, and that partition is read; the next close writes it again |
| the partition changed after its segment was written | the segment is ignored (it names the exact files it was made for) |
| `DROP INDEX`, `DROP TABLE`, a partition dropped | its segments go to `_trash` at the next close or idle checkpoint |
| a partition only grows (new rows after its last one, [tail files](partitions-and-dedup.md#tail-files)) | only the new rows are written, in a small extra segment next to the old one (see below) |

- **Notes:**
  - The segments are in the folder `fts/` of the database. They are a copy of what the rows already say: deleting the folder only makes the next build slower. Backups do not copy them.
  - JSON (`USING GIN`) indexes get segments too.
  - An encrypted database encrypts its segments like every other file.
  - `kareladb check` reads every segment and prints a `WARNING` for a damaged one. It does not count as damage: KarelaDB never uses a damaged segment.
  - `GET /api/stats` counts them under `search`: `segments_written`, `segment_extensions`, `segments_merged`, `segments_loaded`, `segment_rows_loaded`, `segments_damaged`, `segments_stale`, and `rows_indexed` (rows a build still split into words). After a clean restart `rows_indexed` stays at 0.
  - An older KarelaDB ignores the folder and opens the database as before. `kareladb downgrade` to a KarelaDB from before 2026-10-02 moves the segments to `_trash`.

**Growing partitions.** A table that gets new rows all day (a news feed, a log) would write the segment of today's partition again at every quiet moment, for a few new rows. Instead, KarelaDB writes only the new rows in an extra segment (`fts/<name>.1.kfs`, `.2.kfs`, ...) that names the segment before it. Small extra segments are merged into one as they pile up, and into a new whole segment when they reach half of it, so a partition never has more than 5 files. Old ones go to `_trash`.

| What | Why it is safe |
|---|---|
| a power cut while segments are written or merged | each file is written whole and then renamed; the next open uses the old segments or the new one, and when they do not fit together it reads that partition's rows |
| a partition rewritten whole, or changed by `UPDATE` / `DELETE` | its next segment is a new whole one; the extra ones go to `_trash` |

`/api/stats` `search` also shows `segment_extensions` (extra segments written) and `segments_merged` (older segments a merge replaced). The result is faster restarts: after a clean shutdown no row is read to build a full-text index, even on a table that grows all day.

<a id="search-rank"></a>

## search_rank

Syntax:

```sql
search_rank(column [, column ...], 'words')
```

A number that says how well a row matches: higher is better, `0` when the row does not match. It uses the **BM25** formula (the formula of most search engines):

- a word that is rare in the table counts more than a common word,
- a word that is there many times counts more,
- a long text counts a little less.

| Argument | Type | Meaning |
|---|---|---|
| `column` | STRING, SYMBOL or JSON | the text; use the same columns as in `match` |
| `words` | STRING | the search text; use the same words as in `match` |

- **Returns:** `DOUBLE`, `0` or more.
- **NULL:** `NULL` search text gives `NULL`.
- **Notes:**
  - The number depends on **all rows** of the table (how rare each word is). Compare ranks only inside one query. When rows change, the rank of the same row can change.
  - Words with `-` do not add to the rank.
  - **The fastest form:** `WHERE MATCH(cols, 'words') ORDER BY search_rank(cols, 'words') DESC LIMIT n`, with the same columns and the same words, and a FULLTEXT index on those columns. KarelaDB takes the `n` best rows straight from the index. [EXPLAIN](explain.md) then says `best n row(s) by search_rank, top-k by rank (WAND)`.
  - **Only the best rows are ranked:** in that form KarelaDB keeps the `n` best rows found so far. A row, or a whole block of 128 rows of a word, that cannot rank above the `n`-th best even with the most mentions of each word is skipped without working out its rank. The answer is the same as ranking every match. Conditions on other columns (`AND category = 3`) are fine: when they turn rows down, KarelaDB looks for more. `search` in [`GET /api/stats`](http-server-info.md#api-stats) counts the ranks worked out (`bm25_evaluations`), the top-n searches (`top_k_searches`) and what they skipped (`skipped_blocks`, `skipped_docs`).
  - Without a FULLTEXT index on the same columns, `search_rank` reads the whole table once per query.
  - On values that are not columns of a table (`search_rank('bank bank', 'bank')`), the value is ranked alone, as if it were the only row.

**Example: The best matches first** (sample data: content-news)

Setup:

```sql
CREATE FULLTEXT INDEX news_text ON news (title, body);
```

```sql
SELECT id, title, round(search_rank(title, body, 'bank'), 3) AS rank
FROM news
WHERE MATCH(title, body, 'bank')
ORDER BY rank DESC;
```

Result:

| id (LONG) | title (STRING) | rank (DOUBLE) |
|---|---|---|
| 5 | Coastal Bank merger talks | 0.845 |
| 1 | City Bank profit rises 18% | 0.816 |
| 4 | Market index closes at 2,840 | 0.562 |

(3 rows)

**Example: Rows that do not match get 0** (sample data: content-news)

```sql
SELECT id, round(search_rank(title, body, 'city bank'), 3) AS rank FROM news ORDER BY id;
```

Result:

| id (LONG) | rank (DOUBLE) |
|---|---|
| 1 | 1.961 |
| 2 | 0 |
| 3 | 0 |
| 4 | 1.476 |
| 5 | 0 |

(5 rows)

**Example: The fast top-20 form: EXPLAIN says 'best 20 row(s) by search_rank'** (sample data: content-news)

Setup:

```sql
CREATE FULLTEXT INDEX news_text ON news (title, body);
```

```sql
EXPLAIN SELECT id, title FROM news
WHERE MATCH(title, body, 'bank')
ORDER BY search_rank(title, body, 'bank') DESC
LIMIT 20;
```

Result:

| plan (STRING) |
|---|
| scan table news (1 of 1 partitions, about 5 rows) |
| use index news_text (full-text search, best 20 row(s) by search_rank, top-k by rank (WAND)) |
| build 3 of 5 stored column(s) per row: id, title, body |
| filter while scanning: 1 condition(s) |
| sort by 1 key(s) |
| limit 20 |
| engine: row (a condition the column engine does not do) |

(7 rows)

**Example: Forum: the best posts for 'bonus'** (sample data: content-forum)

Setup:

```sql
CREATE FULLTEXT INDEX posts_body ON posts (body);
```

```sql
SELECT id, author, body, round(search_rank(body, 'bonus'), 3) AS rank
FROM posts
WHERE MATCH(body, 'bonus')
ORDER BY search_rank(body, 'bonus') DESC
LIMIT 5;
```

Result:

| id (LONG) | author (STRING) | body (STRING) | rank (DOUBLE) |
|---|---|---|---|
| 4 | gita | What about the bonus shares? | 1.319 |
| 5 | ram | Bonus is 10% this time. | 1.319 |

(2 rows)

<a id="highlight"></a>

## highlight

Syntax:

```sql
highlight(column [, column ...], 'words')
```

Returns the text with every found word inside `<b>` and `</b>`, for a search result page.

| Argument | Type | Meaning |
|---|---|---|
| `column` | STRING, SYMBOL or JSON | the text to show; several columns are joined with one space into one text |
| `words` | STRING | the search text (the same as in `match`) |

- **Returns:** `STRING`.
- **NULL:** `NULL` search text gives `NULL`. A `NULL` column is left out; when every column is `NULL` the result is `NULL`.
- **Notes:**
  - `highlight` does not check that the row matches. A row may match because of its `body`, while you highlight only its `title` (the title then has no `<b>`).
  - Each word of a phrase is marked alone, wherever it is. A prefix (`bank*`) marks the whole word (`<b>Banks</b>`). Words with `-` are not marked.
  - **Web pages:** `highlight` changes no other character. When users can type `<` or `&` (in a forum they can), escape the text first. See the last example.

**Example: Mark the search word in the titles** (sample data: content-news)

```sql
SELECT id, highlight(title, 'bank') AS title
FROM news
WHERE MATCH(title, body, 'bank')
ORDER BY id;
```

Result:

| id (LONG) | title (STRING) |
|---|---|
| 1 | City <b>Bank</b> profit rises 18% |
| 4 | Market index closes at 2,840 |
| 5 | Coastal <b>Bank</b> merger talks |

(3 rows)

**Example: Nepali text, a phrase and a prefix** (sample data: content-news)

```sql
SELECT id, highlight(body, 'नाफा १२.५') AS body FROM news WHERE id = 2;
SELECT id, highlight(title, body, '"net profit" bank*') AS text FROM news WHERE id = 1;
```

Result:

`SELECT id, highlight(body, 'नाफा १२.५') AS body FROM news WHERE id = 2`

| id (LONG) | body (STRING) |
|---|---|
| 2 | सिटी बैंकले चौथो त्रैमासिकमा ३ अर्ब २७ करोड <b>नाफा</b> कमाएको छ। लाभांश <b>१२.५</b> प्रतिशत। |

(1 row)

`SELECT id, highlight(title, body, '"net profit" bank*') AS text FROM news WHERE id = 1`

| id (LONG) | text (STRING) |
|---|---|
| 1 | City <b>Bank</b> <b>profit</b> rises 18% City <b>Bank</b> reported a <b>net</b> <b>profit</b> of $3.27 billion. The <b>bank</b> will pay a 12.5% dividend. |

(1 row)

**Example: Forum: escape what users typed, then highlight (safe for a web page)** (sample data: content-forum)

Setup:

```sql
INSERT INTO posts VALUES (9, 2, 7, 'ram', 'Is <b>ACME</b> a hydro IPO & a good buy?', '2026-09-02T09:30:00+05:45');
```

```sql
SELECT id,
       highlight(replace(replace(replace(body, '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), 'hydro ipo') AS safe_html
FROM posts
WHERE MATCH(body, 'hydro ipo')
ORDER BY id;
```

Result:

| id (LONG) | safe_html (STRING) |
|---|---|
| 9 | Is &lt;b&gt;ACME&lt;/b&gt; a <b>hydro</b> <b>IPO</b> &amp; a good buy? |

(1 row)

In the last example the `<b>` that the user typed became `&lt;b&gt;`, so only the search words are bold. (A search for the words `amp`, `lt` or `gt` would then also mark letters inside `&amp;`, `&lt;` and `&gt;`.)

<a id="search-syntax"></a>

## Search text

Syntax:

```sql
word word       every word must be there, anywhere, in any order
"word word"     these words next to each other, in this order
word*           a word that starts with these letters
-word           this word must not be there
-"word word"    this phrase must not be there
```

How KarelaDB cuts text (and the search text) into **words**:

| Rule | Example |
|---|---|
| Letters and digits of any language make words | `सिटी बैंकको नाफा` is 3 words |
| English letters A-Z: case does not matter; other letters must be the same | `Bank` = `bank`; `Café` is not `CAFÉ` |
| Everything else separates words: spaces, punctuation, `।`, `॥`, emoji | `छ।` is the word `छ`; `ram@example.com` is `ram`, `example`, `com` |
| A number keeps its dot; a comma inside a number is dropped | `12.5` is one word; `2,840` is `2840` |
| Devanagari digits are the same as 0-9 | `१२.५` = `12.5` |
| Numbers are words, not values | `1234.50` is not `1234.5` |
| No stemming | `bank` does not find `banks`; `बैंक` does not find `बैंकले` (use `बैंक*`); an English index stems, see [Language](full-text-search.md#language) |

- **Notes:**
  - There is no `OR`, no `AND` word, no brackets, no fuzzy search, no synonyms, and no stop words unless the index is [English](full-text-search.md#language). `bank OR merger` looks for three words, and one of them is `or`.
  - A phrase does not cross from one column to the next: the end of `title` and the start of `body` are not "next to each other".
  - Words joined by punctuation in the search text work like a phrase: `city-bank` is the same as `"city bank"`.
  - A prefix works on one word only: `net-prof*` and `"net prof*"` do not find `net profit`.
  - At least one word must be without `-`. `-merger` alone finds nothing.

**Example: A phrase, a prefix, and a word that must not be there** (sample data: content-news)

```sql
SELECT id FROM news WHERE MATCH(title, body, '"net profit"') ORDER BY id;
SELECT id FROM news WHERE MATCH(title, body, 'hydro*') ORDER BY id;
SELECT id FROM news WHERE MATCH(title, body, 'bank -merger') ORDER BY id;
```

Result:

`SELECT id FROM news WHERE match(title, body, '"net profit"') ORDER BY id`

| id (LONG) |
|---|
| 1 |

(1 row)

`SELECT id FROM news WHERE match(title, body, 'hydro*') ORDER BY id`

| id (LONG) |
|---|
| 3 |
| 4 |

(2 rows)

`SELECT id FROM news WHERE match(title, body, 'bank -merger') ORDER BY id`

| id (LONG) |
|---|
| 1 |
| 4 |

(2 rows)

**Example: Nepali: a word ending needs a prefix search** (sample data: content-news)

```sql
SELECT id FROM news WHERE MATCH(title, body, 'बैंक') ORDER BY id;
SELECT id FROM news WHERE MATCH(title, body, 'बैंक*') ORDER BY id;
```

Result:

`SELECT id FROM news WHERE match(title, body, 'बैंक') ORDER BY id`

| id (LONG) |
|---|

(0 rows)

`SELECT id FROM news WHERE match(title, body, 'बैंक*') ORDER BY id`

| id (LONG) |
|---|
| 2 |

(1 row)

**Example: Numbers: 2,840 and 2840 are the same word** (sample data: content-news)

```sql
SELECT id, title FROM news WHERE MATCH(title, body, '2840');
SELECT id, title FROM news WHERE MATCH(title, body, '2,840');
```

Result:

`SELECT id, title FROM news WHERE match(title, body, '2840')`

| id (LONG) | title (STRING) |
|---|---|
| 4 | Market index closes at 2,840 |

(1 row)

`SELECT id, title FROM news WHERE match(title, body, '2,840')`

| id (LONG) | title (STRING) |
|---|---|
| 4 | Market index closes at 2,840 |

(1 row)

**Example: OR is not an operator, and a search needs a word to find** (sample data: content-news)

```sql
SELECT id FROM news WHERE MATCH(title, body, 'bank OR merger') ORDER BY id;
SELECT id FROM news WHERE MATCH(title, body, '-merger') ORDER BY id;
SELECT id FROM news WHERE MATCH(title, body, 'bank') OR MATCH(title, body, 'hydropower') ORDER BY id;
```

Result:

`SELECT id FROM news WHERE match(title, body, 'bank OR merger') ORDER BY id`

| id (LONG) |
|---|

(0 rows)

`SELECT id FROM news WHERE match(title, body, '-merger') ORDER BY id`

| id (LONG) |
|---|

(0 rows)

`SELECT id FROM news WHERE match(title, body, 'bank') OR match(title, body, 'hydropower') ORDER BY id`

| id (LONG) |
|---|
| 1 |
| 3 |
| 4 |
| 5 |

(4 rows)
