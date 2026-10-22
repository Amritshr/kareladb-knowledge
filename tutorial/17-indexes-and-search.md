# 17. Indexes and search

- Category: Tutorial

## What you will learn

- Why a query can be slow, and how an index makes it fast.
- `CREATE INDEX`, `CREATE UNIQUE INDEX`, `DROP INDEX`, `SHOW INDEXES`.
- A forum: pages of a thread, replies, and fast "next page" links.
- News: full-text search in English, Nepali or any other language with `MATCH`, `search_rank` and `highlight`.
- How to see if a query uses an index (`EXPLAIN`).
- How fast it is, and the limits.

All examples are in examples/17-indexes-and-search/. The output under each example is real.

## Why indexes

Every table has a **storage key**: the `PRIMARY KEY`, or `SORT BY` / `DEDUP KEY` of a time-series table (chapter 3). Rows are kept in the order of this key. So `WHERE id = 5` finds the row at once.

A condition on another column is different. `WHERE thread_id = 7` must read **every row** of the table and check each one. With 10 rows this is fast. With 1 million forum posts it is slow.

An **index** is a second, sorted list of one or more columns. Each entry points to its row. With an index on `thread_id`, KDB jumps to the posts of thread 7 and reads only those.

| Without index | With index |
|---|---|
| Reads every row | Reads only the rows it needs |
| 1 million posts: tens of milliseconds, more with long text | 1 million posts: about 0.05 ms |
| Writes are a little faster | Every write also changes the index |

Create an index for the columns your app uses in `WHERE` and `ORDER BY` again and again. Do not create indexes you do not use.

## Where the index lives

An index is kept **in memory**. KDB does not write it to disk:

- When the database opens, `kdb serve` **builds every index at once**, on a background thread. The first query then finds it ready. Building takes about 0.2 seconds per million rows (a full-text index: about 2 seconds for 200,000 news articles). Queries and writes go on while it builds.
- A query that needs an index before the build is done builds it itself, as before. `kdb sql` and `kdb shell` do not build at open: there the **first query that needs an index builds it**. `kdb serve --warm-indexes off` (or `KDB_WARM_INDEXES=off`) makes the server do the same.
- After that, every change (`INSERT`, `UPDATE`, `DELETE`, `InsertRows`, line protocol, `ROLLBACK`) also changes the index.
- After a crash or a power cut, the index is built again from the rows. It can never be old or broken. `kdb check`, `kdb repair` and backups have nothing extra to do.
- Only the **definition** (`CREATE INDEX ...`) is saved, with the table.
- A slow query that a page asks again and again (a dashboard, a front page) can be **pinned**: the server keeps its result ready in the result cache and makes it again after a write. See the help topic **Pinned queries** (`/api/pins`).

## Step 1: the forum tables

01-forum-schema.sql:

```sql
CREATE TABLE threads (
  id LONG PRIMARY KEY,
  title STRING NOT NULL,
  created_at TIMESTAMP NOT NULL
);

CREATE TABLE posts (
  id LONG PRIMARY KEY,
  thread_id LONG NOT NULL REFERENCES threads(id),
  parent_id LONG,
  author STRING NOT NULL,
  body STRING NOT NULL,
  created_at TIMESTAMP NOT NULL
);

-- Pages of a thread, newest first.
CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id);
-- The replies of a post.
CREATE INDEX posts_parent ON posts (parent_id);
-- Posts of one author.
CREATE INDEX posts_author ON posts (author);
```

```text
table 'threads' created

table 'posts' created

index 'posts_thread_time' created on table 'posts' (0 rows)

index 'posts_parent' created on table 'posts' (0 rows)

index 'posts_author' created on table 'posts' (0 rows)
```

- A reply has the `id` of the post it answers in `parent_id`. A post that starts a discussion has `parent_id` NULL.
- `posts_thread_time` has **three columns**. The order matters: first `thread_id`, then `created_at`, then `id`. It helps `WHERE thread_id = ...`, and also `WHERE thread_id = ... ORDER BY created_at`. It does **not** help `WHERE created_at > ...` alone, because `created_at` is not the first column.
- You can create an index on a table that already has rows. KDB builds it at once.

The syntax:

```sql
CREATE [UNIQUE | FULLTEXT] INDEX [IF NOT EXISTS] name ON table (column, ...);
DROP INDEX [IF EXISTS] name;
SHOW INDEXES [FROM table];
```

Index names are unique in the whole database. A good habit: `table_columns`, for example `posts_thread_time`.

Then some posts: 02-forum-data.sql.

## Step 2: pages of a thread

A forum shows a thread in pages of 20 posts, newest first. Here the pages have 3 posts, so the example stays short.

03-thread-pages.sql:

```sql
-- Page 1 of thread 1: the 3 newest posts.
SELECT id, author, created_at FROM posts
WHERE thread_id = 1
ORDER BY created_at DESC, id DESC
LIMIT 3;

-- Page 2: the 3 posts older than the last row of page 1 (created_at and id of post 4).
SELECT id, author, created_at FROM posts
WHERE thread_id = 1 AND (created_at, id) < ('2026-09-01T11:00:00+05:45', 4)
ORDER BY created_at DESC, id DESC
LIMIT 3;
```

```text
id | author | created_at
---+--------+-------------------------
 6 | sita   | 2026-09-01T06:15:00.000Z
 5 | ram    | 2026-09-01T05:45:00.000Z
 4 | gita   | 2026-09-01T05:15:00.000Z
(3 rows, 0.4 ms)

id | author | created_at
---+--------+-------------------------
 3 | hari   | 2026-09-01T04:35:00.000Z
 2 | sita   | 2026-09-01T04:20:00.000Z
 1 | ram    | 2026-09-01T04:15:00.000Z
(3 rows, 0.1 ms)
```

How it works:

1. The index `(thread_id, created_at, id)` already has the posts of thread 1 sorted by time. KDB reads them from the newest end and **stops after 3 rows**. It does not read the other posts, not even the other posts of the thread.
2. For the next page, the app remembers `created_at` and `id` of the **last row** it showed (post 4). The **row comparison** `(created_at, id) < ('...', 4)` means: older than post 4, or the same time and a smaller id. KDB starts reading the index right there.

This is called **keyset pagination**. Page 1000 is as fast as page 1.

Why not `LIMIT 20 OFFSET 20000`? `OFFSET` must still count the 20,000 rows before the page. It gets slower on every page. Use `OFFSET` only for small tables.

Why `id` in the index and in `ORDER BY`? Two posts can have the same `created_at`. `id` makes the order exact, so no post is shown twice or skipped between pages.

## Step 3: replies and authors

04-replies.sql:

```sql
-- Posts that start a discussion (not replies) in thread 1.
SELECT id, author, body FROM posts WHERE thread_id = 1 AND parent_id IS NULL ORDER BY created_at;

-- The replies to post 1.
SELECT id, author, body FROM posts WHERE parent_id = 1 ORDER BY created_at;

-- How many posts each author wrote in thread 1.
SELECT author, count(*) AS posts FROM posts WHERE thread_id = 1 GROUP BY author ORDER BY author;
```

```text
id | author | body
---+--------+------------------------------------
 1 | ram    | CITY dividend looks good this year.
 4 | gita   | What about the bonus shares?
 6 | sita   | सिटी बैंकको नाफा राम्रो छ।
(3 rows, 0.4 ms)

id | author | body
---+--------+-----------------------------------
 2 | sita   | I agree, the profit grew 18%.
 3 | hari   | Price is high now. Wait for a dip.
(2 rows, 0.1 ms)

author | posts
-------+------
gita   |     1
hari   |     1
ram    |     2
sita   |     2
(4 rows, 0.1 ms)
```

- `parent_id IS NULL` can also use an index.
- Aggregates (`count`, `sum`, `GROUP BY`) read only the rows the index finds.

## Step 4: does my query use an index?

Put `EXPLAIN` before the query. 05-explain.sql (CSV output, so the lines are not cut):

```sql
EXPLAIN SELECT id FROM posts WHERE thread_id = 1 ORDER BY created_at DESC, id DESC LIMIT 20;
EXPLAIN SELECT id FROM posts WHERE parent_id = 1;
-- No index on body: the table is read.
EXPLAIN SELECT id FROM posts WHERE body = 'Which ones?';
```

```text
plan
"scan table posts (1 of 1 partitions, about 8 rows)"
"use index posts_thread_time (thread_id = value, rows in ORDER BY order, stops after 20 row(s))"
"build 3 of 6 stored column(s) per row: id, thread_id, created_at"
filter while scanning: 1 condition(s)
sort by 2 key(s)
limit 20
plan
"scan table posts (1 of 1 partitions, about 8 rows)"
use index posts_parent (parent_id = value)
"build 2 of 6 stored column(s) per row: id, parent_id"
filter while scanning: 1 condition(s)
plan
"scan table posts (1 of 1 partitions, about 8 rows)"
"build 2 of 6 stored column(s) per row: id, body"
filter while scanning: 1 condition(s)
```

The line `use index <name>` says which index is used. No such line: every row is read.
The line `build 3 of 6 stored column(s)` says that KDB reads only the columns the query needs, not the long `body` text of every post.

**When KDB uses an index** (plain index, columns `(a, b, c)`):

| Your query | Uses the index |
|---|---|
| `a = 5`, `a IN (1, 2, 3)`, `a IS NULL` | yes |
| `a = 5 AND b = 7` | yes, both columns |
| `a = 5 AND b > 100`, `b BETWEEN ...`, `b LIKE 'abc%'` | yes: `a` exactly, then a range of `b` |
| `a = 5 ORDER BY b DESC LIMIT 20` | yes, and it stops after 20 rows |
| `a = 5 AND (b, c) < (x, y) ORDER BY b DESC, c DESC LIMIT 20` | yes: keyset pagination |
| `b = 7` alone | no: `b` is not the first column |
| `a = 5 OR b = 7` | no: `OR` |
| `lower(a) = 'x'`, `a + 1 = 6` | only with an expression index on exactly that expression: `CREATE INDEX ix ON t (lower(a))` |
| `a != 5`, `a NOT IN (...)`, `a LIKE '%abc'` | no |

Other rules:

- `UPDATE ... WHERE` and `DELETE ... WHERE` use indexes too.
- In a `JOIN`, only the first table (after `FROM`) uses an index.
- When an index would find more than a quarter of the table (for example `status = 'active'` on most rows), reading the whole table is faster, and KDB does that.
- The result is always the same, with or without an index. Only the speed changes.

## Step 5: UNIQUE indexes

A `UNIQUE` index makes sure no two rows have the same values. Use it for email addresses, user names, or "one row per company per quarter".

06-unique.sql:

```sql
-- One account per email address.
CREATE TABLE users (id LONG PRIMARY KEY, email STRING NOT NULL, name STRING);
CREATE UNIQUE INDEX users_email ON users (email);
INSERT INTO users VALUES (1, 'ram@example.com', 'Ram'), (2, 'sita@example.com', 'Sita');
INSERT INTO users VALUES (3, 'ram@example.com', 'Another Ram');
```

```text
table 'users' created

index 'users_email' created on table 'users' (0 rows)

2 row(s) inserted
error: duplicate value violates unique index 'users_email' on table 'users': a row with email='ram@example.com' already exists
[exit code 1]
```

- The error names the index and the value. Your app can look for the word `unique` in the message and show "this email is already used".
- The check covers every way of writing: `INSERT`, `INSERT OR REPLACE`, `UPDATE`, `InsertRows`, transactions. Nothing is written when the check fails.
- Two rows may swap their values in one `UPDATE`.
- `NULL` values never clash: many rows may have a NULL email.
- `CREATE UNIQUE INDEX` on a table that already has two equal values fails, and names the value. Fix the rows first.
- A `UNIQUE` index can have several columns: `CREATE UNIQUE INDEX votes_one_per_user ON votes (user_id, post_id)` (chapter 18 uses this).

## Step 6: news and full-text search

`LIKE '%bank%'` reads every row and checks every letter. For thousands of news articles that is slow. A **FULLTEXT index** keeps a list of words: for each word, the articles that have it.

07-news-schema.sql:

```sql
CREATE TABLE news (
  id LONG PRIMARY KEY,
  symbol STRING,
  published_at TIMESTAMP NOT NULL,
  title STRING NOT NULL,
  body STRING
);

-- Search in the title and the body together.
CREATE FULLTEXT INDEX news_text ON news (title, body);
-- The newest news of a company.
CREATE INDEX news_symbol_time ON news (symbol, published_at);

INSERT INTO news VALUES
  (1, 'CITY', '2026-08-01T11:00:00+05:45', 'City Bank profit rises 18%',
      'City Bank reported a net profit of 3.27 billion dollars. The bank will pay a 12.5% dividend.'),
  (2, 'CITY', '2026-08-01T11:30:00+05:45', 'सिटी बैंकको नाफा बढ्यो',
      'सिटी बैंकले चौथो त्रैमासिकमा ३ अर्ब २७ करोड नाफा कमाएको छ। लाभांश १२.५ प्रतिशत।'),
  (3, 'VOLT', '2026-08-15T10:00:00+05:45', 'Hydropower company plans IPO',
      'Volt River Hydropower will sell new shares. The IPO opens next month.'),
  (4, NULL,    '2026-09-01T08:00:00+05:45', 'Market index closes at 2,840',
      'Banks and hydropower shares moved up. City Bank led the gainers.'),
  (5, 'COAST',  '2026-09-02T09:00:00+05:45', 'Coastal bank merger talks',
      'Coastal Bank is in talks about a merger. No loan changes are planned.');
```

```text
table 'news' created

index 'news_text' created on table 'news' (0 rows)

index 'news_symbol_time' created on table 'news' (0 rows)

5 row(s) inserted
```

A FULLTEXT index works on STRING (and SYMBOL, JSON) columns. With several columns, they are searched together as one text.

### How text is cut into words

| Rule | Example |
|---|---|
| Letters and digits of any language make words | `सिटी बैंकको नाफा` is 3 words |
| English letters: case does not matter | `Bank` = `bank` = `BANK` |
| Punctuation separates words, also `।` and `॥` | `छ।` is the word `छ` |
| A number keeps its dot; a comma inside a number is dropped | `12.5` is one word; `1,234.5` is `1234.5` |
| Devanagari digits are the same as 0-9 | `१२.५` = `12.5` |
| Words must be the same; there is no stemming | `bank` does not find `banks`; `बैंक` does not find `बैंकले` (use `बैंक*`) |

### Searching

08-search.sql:

```sql
-- Every word must be there (English letters: any case).
SELECT id, title FROM news WHERE MATCH(title, body, 'city bank') ORDER BY id;

-- The best matches first.
SELECT id, title, round(search_rank(title, body, 'bank'), 3) AS rank
FROM news
WHERE MATCH(title, body, 'bank')
ORDER BY rank DESC
LIMIT 3;

-- Nepali words; a number with a dot is one word (१२.५ is the same as 12.5).
SELECT id, title FROM news WHERE MATCH(title, body, 'नाफा') ORDER BY id;
SELECT id FROM news WHERE MATCH(title, body, '12.5') ORDER BY id;

-- An exact phrase, a prefix, and a word that must not be there.
SELECT id FROM news WHERE MATCH(title, body, '"net profit"');
SELECT id FROM news WHERE MATCH(title, body, 'hydro*') ORDER BY id;
SELECT id FROM news WHERE MATCH(title, body, 'bank -merger') ORDER BY id;

-- Full-text search together with other conditions.
SELECT id, title FROM news WHERE MATCH(title, body, 'bank') AND published_at >= '2026-09-01' ORDER BY id;
```

```text
id | title
---+-----------------------------
 1 | City Bank profit rises 18%
 4 | Market index closes at 2,840
(2 rows, 0.4 ms)

id | title                        | rank
---+------------------------------+------
 1 | City Bank profit rises 18%   | 0.806
 5 | Coastal bank merger talks    | 0.751
 4 | Market index closes at 2,840 | 0.562
(3 rows, 0.1 ms)

id | title
---+-----------------------
 2 | सिटी बैंकको नाफा बढ्यो
(1 row, 0.0 ms)

id
--
 1
 2
(2 rows, 0.0 ms)

id
--
 1
(1 row, 0.0 ms)

id
--
 3
 4
(2 rows, 0.0 ms)

id
--
 1
 4
(2 rows, 0.0 ms)

id | title
---+-----------------------------
 4 | Market index closes at 2,840
 5 | Coastal bank merger talks
(2 rows, 0.0 ms)
```

The search text:

| You write | It finds rows that |
|---|---|
| `city bank` | have both words, anywhere |
| `"net profit"` | have these words next to each other, in this order (not across title and body). The index keeps the place of every word, so a phrase is found in the index too. |
| `hydro*` | have a word that starts with `hydro` (`hydropower`) |
| `bank -merger` | have `bank` but not `merger` |

A search needs at least one word without `-`.

**`search_rank(columns..., 'words')`** says how well a row matches: higher is better, 0 when the row does not match. It uses the BM25 formula: a word that is rare in the table counts more than a common word, a word that is there many times counts more, and a long text counts a little less. Use the same columns and words as in `MATCH`.

`ORDER BY search_rank(...) DESC LIMIT 20` together with `MATCH(...)` is the fastest form: KDB takes the 20 best rows straight from the index and reads only those rows.

`MATCH` and `search_rank` also work **without** a FULLTEXT index. Then KDB reads every row.

### Highlight the words

`highlight(columns..., 'words')` returns the text with the found words inside `<b>` and `</b>`, for a search result page.

09-highlight.sql:

```sql
SELECT id, highlight(title, 'bank') AS title FROM news WHERE MATCH(title, body, 'bank') ORDER BY id;
```

```text
id,title
1,City <b>Bank</b> profit rises 18%
4,"Market index closes at 2,840"
5,Coastal <b>bank</b> merger talks
```

Row 4 matched because its **body** has `Bank`; the highlighted column here is only the title.

`highlight` does not change any other character. If users can type `<` or `&` (in a forum they can), do not put the result into a web page as it is: escape the text in your app first.

### Changes

10-news-changes.sql:

```sql
UPDATE news SET body = 'Coastal Bank and Harbor Bank signed the merger.' WHERE id = 5;
SELECT id FROM news WHERE MATCH(title, body, 'harbor');
DELETE FROM news WHERE id = 4;
SELECT id FROM news WHERE MATCH(title, body, 'gainers');
```

```text
1 row(s) updated

id
--
 5
(1 row, 0.2 ms)

1 row(s) deleted

id
--
(0 rows, 0.0 ms)
```

11-news-explain.sql:

```sql
EXPLAIN SELECT id FROM news WHERE MATCH(title, body, 'bank') ORDER BY search_rank(title, body, 'bank') DESC LIMIT 20;
EXPLAIN SELECT id, title FROM news WHERE symbol = 'CITY' ORDER BY published_at DESC LIMIT 10;
```

```text
plan
"scan table news (1 of 1 partitions, about 4 rows)"
"use index news_text (full-text search, best 20 row(s) by search_rank)"
"build 3 of 5 stored column(s) per row: id, title, body"
filter while scanning: 1 condition(s)
sort by 1 key(s)
limit 20
plan
"scan table news (1 of 1 partitions, about 4 rows)"
"use index news_symbol_time (symbol = value, rows in ORDER BY order, stops after 10 row(s))"
"build 4 of 5 stored column(s) per row: id, symbol, published_at, title"
filter while scanning: 1 condition(s)
sort by 1 key(s)
limit 10
```

## Step 7: see and remove indexes

12-show-indexes.sql:

```sql
-- kdb sql opens the database again, so no index is in memory yet. The first query builds one.
SHOW INDEXES FROM posts;
SELECT count(*) AS posts FROM posts WHERE thread_id = 1;
SHOW INDEXES FROM posts;
SHOW CREATE TABLE users;
```

```text
name,table,kind,columns,built,rows,memory_bytes,create_sql,building
posts_thread_time,posts,INDEX,"thread_id, created_at, id",false,,,"CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id)",false
posts_parent,posts,INDEX,parent_id,false,,,CREATE INDEX posts_parent ON posts (parent_id),false
posts_author,posts,INDEX,author,false,,,CREATE INDEX posts_author ON posts (author),false
posts
6
name,table,kind,columns,built,rows,memory_bytes,create_sql,building
posts_thread_time,posts,INDEX,"thread_id, created_at, id",true,8,400,"CREATE INDEX posts_thread_time ON posts (thread_id, created_at, id)",false
posts_parent,posts,INDEX,parent_id,false,,,CREATE INDEX posts_parent ON posts (parent_id),false
posts_author,posts,INDEX,author,false,,,CREATE INDEX posts_author ON posts (author),false
create_sql
"CREATE TABLE users (
  id LONG PRIMARY KEY,
  email STRING NOT NULL,
  name STRING
)"
CREATE UNIQUE INDEX users_email ON users (email)
```

- `built` is `true` when the index is in memory now; `rows` and `memory_bytes` show its size.
- `building` is `true` while the server's background thread builds it right after the database opened. `kdb sql` never builds at open, so here it is always `false`.
- `SHOW CREATE TABLE` gives the table and then one `CREATE INDEX` line per index. Run them in this order to make the same table again.

13-drop-index.sql:

```sql
DROP INDEX posts_author;
DROP INDEX IF EXISTS posts_author;
ALTER TABLE posts DROP COLUMN parent_id;
```

```text
index 'posts_author' dropped

index 'posts_author' does not exist
error: cannot drop column 'parent_id' from table 'posts': index 'posts_parent' uses it; DROP INDEX posts_parent first
[exit code 1]
```

- A column that an index uses cannot be dropped. `RENAME COLUMN` and `RENAME TABLE` keep the index working.
- `DROP TABLE` also drops the table's indexes.
- `CREATE INDEX` and `DROP INDEX` cannot run inside `BEGIN ... COMMIT`.

## How fast

Measured with `kdb_bench_indexes` (bench/bench_indexes.cpp) on the test PC (Windows, 16 threads for KDB, release build). Query times are the middle value of many runs and include parsing the SQL.

| What | Rows | Time |
|---|---|---|
| `CREATE INDEX posts_thread ON posts (thread_id, created_at, id)` | 1,000,000 posts | 170 ms |
| Build of that index when the database opens (`kdb sql`: by the first query) | 1,000,000 posts | 150-320 ms, once |
| `SELECT * FROM posts WHERE author = 'user123'` (10 rows) | 1,000,000 posts | 0.03-0.04 ms |
| Forum page: `WHERE thread_id = x ORDER BY created_at DESC LIMIT 20` | 1,000,000 posts | 0.05-0.06 ms |
| Keyset page: `... AND (created_at, id) < (?, ?) ORDER BY created_at DESC, id DESC LIMIT 20` | 1,000,000 posts | 0.06-0.07 ms |
| `INSERT` of one post (two indexes kept up to date, log saved to disk) | 1,000,000 posts | 0.3-1.8 ms (mostly the disk) |
| `CREATE FULLTEXT INDEX news_text ON news (title, body)` | 200,000 articles, 216 MB of text | 1.0-1.1 s |
| Build of that index when the database opens (`kdb sql`: by the first search) | 200,000 articles | 1.6 s, once |
| Top 20 by `search_rank` for common words | 200,000 articles (23,000 to 199,000 matches) | 6-15 ms |
| `UPDATE` of one article (full-text index kept up to date) | 200,000 articles | 0.4-2 ms |
| Memory: `posts_thread` / `posts_author` / `news_text` | | 50 MB / 35 MB / 102 MB |

Run it yourself: `.\build\bin\kdb_bench_indexes.exe 1000000 200000`.

## Tips

- An index on `(a, b)` also serves queries on `a` alone. You do not need a second index on `(a)`.
- Put the column you compare with `=` first, and the column you sort or compare with `<` / `>` next.
- For "latest N rows of X" add the time column after X: `(symbol, published_at)`, `(thread_id, created_at, id)`.
- Time-series tables already sort by `SORT BY`. Indexes help them for other columns, like `broker` in a trade log table.
- Every index costs memory (about the size of its column values plus 20-30 bytes per row) and makes writes a little slower. Big line-protocol imports into a table with indexes are slower; create the indexes after a big first import.
- The limits are listed in [known limitations](known-limitations.md).

## What you learned

- An index is a sorted list of columns that points to rows. It lives in memory. `kdb serve` builds it from the rows right after the database opens; `kdb sql` builds it when first needed.
- `CREATE INDEX` makes `=`, `IN`, ranges and `ORDER BY ... LIMIT` fast. `EXPLAIN` shows `use index`.
- Keyset pagination with a row comparison `(created_at, id) < (?, ?)` keeps every page fast.
- `CREATE UNIQUE INDEX` refuses duplicates.
- `CREATE FULLTEXT INDEX` with `MATCH`, `search_rank` and `highlight` searches text in English, Nepali and other languages.
