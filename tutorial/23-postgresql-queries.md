# 23. PostgreSQL queries and data changes

- Category: Tutorial

## What you will learn

Chapter 22 is about the app's tables. This chapter is about the app's **queries and data changes**: the SQL a PostgreSQL app sends every day.

- **Part A.** Upserts: `INSERT ... ON CONFLICT`, `RETURNING`, `xmax`.
- **Part B.** `INSERT ... SELECT`, `UPDATE ... FROM`, `DELETE ... USING`, subqueries in data changes.
- **Part C.** `WITH` queries: plain, `RECURSIVE`, and `WITH x AS (UPDATE ...)`.
- **Part D.** Correlated subqueries, `EXISTS`, `LATERAL`, and why they stay fast.
- **Part E.** More query forms: `FILTER`, `DISTINCT ON`, `UNION` / `INTERSECT` / `EXCEPT`, `GROUP BY 1`.
- **Part F.** Casts, times and intervals.
- **Part G.** Arrays and JSON.
- **Part H.** Advisory locks.
- **Part I.** QuestDB apps: `ALTER DATABASE ... SET dialect`, `/imp`, `to_str`.
- What is **different** from PostgreSQL, and **speed**.

The output under each example is real (`kareladb sql`). Times print in KarelaDB's style (`2026-09-10T05:20:00.000Z`); over the PostgreSQL protocol they have PostgreSQL's style.

## The short version

| PostgreSQL | KarelaDB |
|---|---|
| `INSERT ... ON CONFLICT (key) DO NOTHING / DO UPDATE SET c = EXCLUDED.c` | Works, with `WHERE`, `ON CONSTRAINT` and `RETURNING (xmax = 0)`. |
| `INSERT ... SELECT`, `DEFAULT VALUES` | Works. |
| `UPDATE t SET ... FROM s WHERE ...`, `DELETE FROM t USING s WHERE ...` | Works. |
| Subqueries in `SET`, `WHERE` and `VALUES` | Works, correlated ones too. |
| `WITH`, `WITH RECURSIVE`, `WITH x AS (UPDATE ... RETURNING ...)` | Works. A statement with data-changing `WITH` queries is one transaction. |
| Correlated subqueries, `EXISTS`, `IN (SELECT ...)`, `LATERAL` | Works. The usual shapes become hash lookups. |
| `FILTER (WHERE ...)`, `agg(x ORDER BY y)`, `DISTINCT ON`, `GROUP BY 1`, `NULLS FIRST` | Works. |
| `UNION`, `INTERSECT`, `EXCEPT` (with or without `ALL`), `(VALUES ...) AS v(a, b)` | Works. |
| `x::type`, `CAST`, `DATE '...'`, `INTERVAL '...'`, `E'...'`, `CURRENT_TIMESTAMP` | Works. Casts round numbers as PostgreSQL does. |
| `INTERVAL` arithmetic, `AT TIME ZONE`, `EXTRACT(EPOCH FROM interval)`, `make_interval` | Works (time zones: fixed offsets and zones without daylight saving, such as `Asia/Kathmandu`; see Part F). |
| `= ANY($1)` with Go slices, `ARRAY[...]`, `array_agg`, `unnest`, `TEXT[]` results | Works, in text and binary form. |
| `jsonb_build_object`, `json_agg`, `jsonb_set`, `->`, `->>`, `#>>` | Works. JSON sorts like `jsonb` (9 before 10). |
| `pg_advisory_lock`, `pg_try_advisory_xact_lock`, ... | Real locks between sessions. |

When all 2143 statements of the app run on KarelaDB, **1971** work over HTTP (92.0%) and **1952** over the PostgreSQL protocol (91.1%) (checked on 2026-09-23). Before this work (and the schema work of chapter 22) it was 950 and 930. Most of the rest come from the test data or from table definitions the test schema left out (see the end).

---

## Part A: Upserts

`ON CONFLICT` says what to do when a new row has the key of a row that is there.

```sql
CREATE TABLE page_hits (page TEXT PRIMARY KEY, hits BIGINT NOT NULL, last_at TIMESTAMP);
INSERT INTO page_hits VALUES ('/chart', 5, '2026-09-10T05:00:00Z');

INSERT INTO page_hits (page, hits, last_at)
VALUES ('/chart', 1, '2026-09-11T05:00:00Z'), ('/news', 1, '2026-09-11T05:00:00Z')
ON CONFLICT (page) DO UPDATE SET hits = page_hits.hits + EXCLUDED.hits, last_at = EXCLUDED.last_at
RETURNING page, hits, (xmax = 0) AS inserted;
```

```
page   | hits | inserted
-------+------+---------
/chart |    6 | false
/news  |    1 | true
1 row(s) inserted, 1 updated
```

- `EXCLUDED.column` is the value of the new row. `page_hits.column` is the value that is there now.
- Write the table name (or the alias of `INSERT INTO t AS a`) before a column. A plain name is ambiguous in PostgreSQL.
- `RETURNING` gives the rows that were inserted or updated. `xmax` is 0 for an inserted row and 1 for an updated one.
- `DO UPDATE ... WHERE cond`: rows that do not match stay as they are and are not returned.
- `DO NOTHING` skips the row. Without a key list it means "any unique key".

```sql
INSERT INTO page_hits (page, hits) VALUES ('/news', 100) ON CONFLICT (page) DO NOTHING RETURNING page;
```

```
(0 rows)
0 row(s) inserted, 1 skipped (already there)
```

**Which keys.** The key list must be the primary key, a `DEDUP KEY`, a `UNIQUE` column or constraint, or a `UNIQUE INDEX` with exactly those columns (a partial index needs `ON CONFLICT (cols) WHERE ...`). `ON CONFLICT ON CONSTRAINT name` names it (`table_pkey` for the primary key). Another list is an error, as in PostgreSQL: "there is no unique key on (...)".

**Rules from PostgreSQL.**

- A key with a NULL never clashes.
- Two new rows with the same key in one `DO UPDATE` statement are an error ("cannot change the same row twice"). With `DO NOTHING` the first one wins.
- `SERIAL` numbers are used also for rows that end as updates (so ids can have gaps).

**Speed.** `DO NOTHING`, and `DO UPDATE SET` of every other column from `EXCLUDED`, on the table's own key, run as `INSERT OR IGNORE` / `INSERT OR REPLACE`: big batches go in without looking rows up one by one. Other forms look each row up by its key (or index).

## Part B: Copying and joined changes

`INSERT ... SELECT` copies the rows of a query. `DEFAULT VALUES` writes one row of defaults.

```sql
INSERT INTO ledger (user_id, amount, balance_after) SELECT user_id, 25, balance FROM wallets WHERE balance > 0;
INSERT INTO logs DEFAULT VALUES;
```

`UPDATE ... FROM` changes rows with values from other tables. `DELETE ... USING` deletes rows that have a match.

```sql
UPDATE wallets w SET balance = v.balance
FROM (VALUES (1, 10), (2, 20), (9, 90)) AS v(user_id, balance)
WHERE w.user_id = v.user_id
RETURNING w.user_id, w.balance;
```

```
user_id | balance
--------+--------
      1 |      10
      2 |      20
2 row(s) updated
```

```sql
DELETE FROM ledger l USING wallets w WHERE l.user_id = w.user_id AND w.balance < 15 RETURNING l.id;
```

- A row of the table changes once, also when it matches several rows of `FROM` (as in PostgreSQL, one of them is used).
- The join is a hash join: `WHERE w.user_id = v.user_id` does not compare every pair.
- Subqueries work in `SET`, `WHERE` and `VALUES`, also ones that use the row being changed:

```sql
UPDATE tickets t SET vote_count = (SELECT count(*) FROM votes v WHERE v.ticket_id = t.ticket_id);
DELETE FROM tickets WHERE NOT EXISTS (SELECT 1 FROM votes WHERE votes.ticket_id = tickets.ticket_id);
UPDATE ai_models SET is_default = TRUE WHERE (provider, model) = (SELECT provider, model FROM ai_models ORDER BY rank LIMIT 1);
```

## Part C: WITH queries

A `WITH` query names a result for the statement. KarelaDB runs it the first time the statement reads it, once, and keeps its rows for the statement.

`WITH RECURSIVE` runs its second part again on the rows found last, until no new rows come. `UNION` (without `ALL`) stops at rows it has seen, so a loop in the data ends.

```sql
WITH RECURSIVE upline(user_id, referred_by, lvl) AS (
  SELECT user_id, referred_by, 0 FROM referrals WHERE user_id = 4
  UNION ALL
  SELECT r.user_id, r.referred_by, u.lvl + 1 FROM referrals r JOIN upline u ON r.user_id = u.referred_by WHERE u.lvl < 20
)
SELECT user_id, lvl FROM upline ORDER BY lvl;
```

```
user_id | lvl
--------+----
      4 |   0
      3 |   1
      2 |   2
      1 |   3
```

A recursive query that never stops is stopped after 100,000 rounds or 10 million rows, with an error.

**WITH queries that change data.** The app's wallet top-up changes a row, writes a ledger row from the changed row, and returns it, in one statement:

```sql
WITH upd AS (UPDATE wallets SET balance = balance + 25 WHERE user_id = 1 RETURNING user_id, balance),
     led AS (INSERT INTO ledger (user_id, amount, balance_after) SELECT user_id, 25, balance FROM upd)
SELECT user_id, balance FROM upd;
```

```
user_id | balance
--------+--------
      1 |     125
```

- The data changes run first, in the order written. Then the main query runs.
- The statement is one transaction: when a part fails, nothing is written.
- Such a `SELECT` locks the tables it changes, as any writer does (chapter 15), and is never kept in the result cache.

## Part D: Correlated subqueries and LATERAL

A **correlated** subquery uses a column of the outer row.

```sql
SELECT t.ticket_id, t.title,
       (SELECT count(*) FROM votes v WHERE v.ticket_id = t.ticket_id) AS votes,
       EXISTS (SELECT 1 FROM votes v WHERE v.ticket_id = t.ticket_id AND v.user_id = 8) AS i_voted
FROM tickets t ORDER BY t.ticket_id;
```

```
ticket_id | title           | votes | i_voted
----------+-----------------+-------+--------
        1 | Dark mode       |     2 | true
        2 | Faster charts   |     1 | false
        3 | Nepali calendar |     0 | false
```

**How KarelaDB keeps this fast.** It does not run the subquery once per outer row.

- When the subquery joins the outer row with `=` (`v.ticket_id = t.ticket_id`), KarelaDB runs it **once** for all keys (grouped by `ticket_id`), puts the answers in a hash table, and every outer row looks its answer up. The work is one pass over `votes` plus one lookup per ticket.
- `count(*)` of a key without rows is 0, and `sum` is NULL, as in PostgreSQL.
- `EXISTS`, `NOT EXISTS`, `IN (SELECT ...)` and `NOT IN (SELECT ...)` work the same way (a set of keys).
- Other shapes (`v.amount > t.limit`) run once per **different** outer value, and the answers are kept for the statement.
- A subquery that uses no outer column runs once, before the query.
- A value subquery that finds two rows is an error, as in PostgreSQL. Add `LIMIT 1` or an aggregate.

`LATERAL` lets a `FROM` subquery use the tables before it:

```sql
SELECT t.title, last_vote.user_id
FROM tickets t
LEFT JOIN LATERAL (SELECT user_id FROM votes v WHERE v.ticket_id = t.ticket_id ORDER BY user_id DESC LIMIT 1) last_vote ON TRUE
ORDER BY t.ticket_id;
```

```
title           | user_id
----------------+--------
Dark mode       |       8
Faster charts   |       7
Nepali calendar |    NULL
```

A `LATERAL` subquery with an aggregate becomes a hash join; one with `ORDER BY ... LIMIT` runs per outer row (answers are kept for rows with the same key).

## Part E: More query forms

```sql
SELECT symbol,
       count(*) FILTER (WHERE qty >= 10) AS big_trades,
       string_agg(price::text, ' -> ' ORDER BY ts) AS path
FROM trades GROUP BY 1 ORDER BY 1;
```

```
symbol | big_trades | path
-------+------------+-----------
CITY   |          2 | 510 -> 512
COAST  |          0 | 900 -> 905
```

```sql
SELECT DISTINCT ON (symbol) symbol, ts, price FROM trades ORDER BY symbol, ts DESC;  -- the newest trade of each symbol
```

```
symbol | ts                       | price
-------+--------------------------+------
CITY   | 2026-09-10T05:20:00.000Z |   512
COAST  | 2026-09-10T05:30:00.000Z |   905
```

| Form | Meaning |
|---|---|
| `agg(x) FILTER (WHERE cond)` | The aggregate only sees rows where `cond` is true. |
| `array_agg(x ORDER BY y)`, `string_agg(x, ',' ORDER BY y)` | The rows come in that order. |
| `DISTINCT ON (a) ... ORDER BY a, b` | The first row of each `a` in `ORDER BY` order. |
| `GROUP BY 1`, `ORDER BY 2` | Position of a select column. An alias works too: `GROUP BY day`. |
| `ORDER BY sum(x)`, `HAVING count(*) > 1` | Aggregates that are not select columns. |
| `NULLS FIRST`, `NULLS LAST` | NULL counts as bigger than every value (first with `DESC`), as in PostgreSQL. |
| `LIMIT ALL`, `OFFSET n ROWS`, `FETCH FIRST n ROWS ONLY` | Also QuestDB's `LIMIT lo, hi`. |
| `UNION`, `INTERSECT`, `EXCEPT` [`ALL`] | Without `ALL` the result has no copies. `INTERSECT` goes first. |
| `(VALUES (1, 'a'), (2, 'b')) AS v(n, s)` | A small table of values. |
| `(a, b) < (x, y)`, `(a, b) = (SELECT ...)` | Row comparisons. |
| `FROM (SELECT ...)` | The subquery needs no alias. |

## Part F: Casts, times and intervals

```sql
SELECT '12.5'::numeric(6,1) AS n, 2.5::int AS rounded, E'tab\there' AS e,
       (DATE '2026-01-31' + INTERVAL '1 month')::date AS next_month;
```

```
n    | rounded | e        | next_month
-----+---------+----------+-----------
12.5 |       3 | tab	here | 2026-02-28
```

- Every PostgreSQL type name works after `::` and in `CAST`: `int4`, `float8`, `numeric(10,2)`, `text`, `varchar(20)`, `timestamptz`, `interval`, `text[]`, `bigint[]`, ...
- A cast to a whole number or to `numeric(p,s)` rounds half away from zero. Other places (a value for an `INT` column, an argument of a saved function) still refuse `2.5`.
- `x::text` of a time gives PostgreSQL's text: `2026-09-10 12:00:00` (with `+00` for a `timestamptz`).
- A text constant next to a number is read as a number: `'1.50' + 1` is `2.50` (a numeric parameter sent as text works too). Text from a column or a function is not: `doc ->> 'n' + 1` is an error; write `(doc ->> 'n')::int + 1`.
- `md5(text)` and `initcap(text)` work as in PostgreSQL.
- `CURRENT_TIMESTAMP`, `CURRENT_DATE`, `LOCALTIMESTAMP`, `now()` are the time the statement started. KarelaDB times are UTC.
- `DATE - DATE` is a number of days. A month added to the 31st ends on the last day of the next month.

**Intervals** keep months, days and time apart, as in PostgreSQL:

```sql
SELECT INTERVAL '1 day' - INTERVAL '1 hour' AS i, EXTRACT(EPOCH FROM INTERVAL '1 month') AS month_seconds,
       make_interval(days => 3, hours => 2) AS m;
```

```
i               | month_seconds | m
----------------+---------------+----------------
1 day -01:00:00 |       2592000 | 3 days 02:00:00
```

`justify_hours`, `justify_days` and `justify_interval` move 24 hours into a day and 30 days into a month. For comparing, a month counts as 30 days.

**AT TIME ZONE** follows PostgreSQL:

- `timestamp AT TIME ZONE z` reads a clock time of zone `z` and gives the instant (a `timestamptz`).
- `timestamptz AT TIME ZONE z` shows an instant as the clock time of zone `z` (a `timestamp`).

```sql
SELECT (TIMESTAMP '2026-09-10 12:00:00' AT TIME ZONE 'Asia/Kathmandu')::text AS utc_instant,
       (TIMESTAMPTZ '2026-09-10 06:15:00+00' AT TIME ZONE 'Asia/Kathmandu')::text AS local_clock;
```

```
utc_instant            | local_clock
-----------------------+--------------------
2026-09-10 06:15:00+00 | 2026-09-10 12:00:00
```

A `TIMESTAMP` column holds UTC instants in KarelaDB, so KarelaDB treats `now()`, `CURRENT_TIMESTAMP`, `timestamptz` casts and `TIMESTAMPTZ` columns as instants, and other `TIMESTAMP` values as clock times. Zones are fixed offsets (`'+05:45'`, `'UTC'`, `'Asia/Kathmandu'`, ...); zones with daylight saving time are refused.

## Part G: Arrays and JSON

KarelaDB keeps an array as a JSON array. Over the PostgreSQL protocol it is a real array (`text[]` is type 1009, `bigint[]` 1016, ...) in text and binary form, so `pgx` scans it into a Go slice and sends Go slices as parameters.

```sql
CREATE TABLE feeds (id BIGINT PRIMARY KEY, tags TEXT[], roles JSONB);
INSERT INTO feeds VALUES (1, '{market,ipo}', '{"admin": "sita"}'), (2, ARRAY['hydro'], '{}');
SELECT id, unnest(tags) AS tag FROM feeds ORDER BY id, tag;
```

```
id | tag
---+-------
 1 | ipo
 1 | market
 2 | hydro
```

| Form | Meaning |
|---|---|
| `x = ANY($1)`, `x <> ALL($1)` | `$1` is an array (a Go slice, `'{1,2}'`, or `ARRAY[...]`). A constant array becomes an `IN` list, so indexes and key ranges still work. |
| `ARRAY[1, 2]`, `ARRAY(SELECT ...)`, `'{a,b}'::text[]` | Make an array. |
| `tags[1]`, `cardinality(tags)`, `array_length(tags, 1)`, `array_to_string`, `string_to_array`, `array_append`, `array_remove`, `array_position` | Read and change arrays (from 1, as in PostgreSQL). |
| `array_agg(x)`, `(array_agg(x ORDER BY y))[1]` | Collect values. |
| `unnest(array)` | In `SELECT`: one row per element. In `FROM`: a table (`FROM unnest($1::int[]) AS u(id)`). |
| `tags @> ARRAY['a']`, `&&`, `<@` | Contains, overlaps, is contained. |

JSON functions: `jsonb_build_object`, `jsonb_build_array`, `json_agg` / `jsonb_agg` (with `ORDER BY`), `to_jsonb`, `row_to_json(t)`, `jsonb_set(doc, path, value, create)`, `jsonb_typeof`, `jsonb_array_length`, `->`, `->>`, `#>`, `#>>`.

```sql
UPDATE feeds SET roles = jsonb_set(roles, ARRAY['editor'], to_jsonb('ram'::text), true) WHERE id = 1 RETURNING roles;
```

```
roles
-------------------------------
{"admin":"sita","editor":"ram"}
```

JSON values sort like PostgreSQL's `jsonb`: numbers by value (9 before 10), strings by text, and null < strings < numbers < booleans < arrays < objects.

## Part H: Advisory locks

Advisory locks are named by a number (or two). KarelaDB keeps them between sessions of one database.

| Function | Meaning |
|---|---|
| `pg_advisory_lock(key)` | Waits until no other session holds the key, then holds it until `pg_advisory_unlock` or the session ends. |
| `pg_try_advisory_lock(key)` | The same without waiting: `true` or `false`. |
| `pg_advisory_xact_lock(key)`, `pg_try_advisory_xact_lock(key)` | Held until `COMMIT` / `ROLLBACK` (or the end of the statement outside `BEGIN`). |
| `pg_advisory_unlock(key)`, `pg_advisory_unlock_all()` | Let it go. `unlock` returns `false` when the session did not hold it. |
| `..._shared` forms | Several sessions may share the key; an exclusive lock waits for all of them. |

- `(a, b)` with two `int` keys is another lock than one `bigint` key, as in PostgreSQL.
- A session may take its own lock again; it must unlock it as many times.
- Waiting ends after 30 seconds with an error (PostgreSQL waits forever).
- A statement alone outside a transaction waits without holding any table lock, so the session that holds the key can go on working. Inside `BEGIN ... COMMIT` it waits holding the locks of the tables the transaction used; keep such waits short.
- Over HTTP without a session, locks end with the request.

## Part I: QuestDB apps

**The dialect.** `ALTER DATABASE qdb SET dialect = 'questdb'` makes a database read SQL the QuestDB way:

- A plain `INSERT` into a table with a `DEDUP KEY` replaces the row with the same key (QuestDB's `DEDUP UPSERT KEYS`).
- `CAST(time AS LONG)` gives microseconds since 1970 (PostgreSQL mode: milliseconds).

`SET dialect = 'postgres'` goes back. The setting is kept in `_system` and applies every time the database opens (chapter 21 has the other `ALTER DATABASE` settings).

**CSV import.** `POST /imp` takes a CSV file the way QuestDB does (chapter 8 has the details):

```bash
curl -F "data=@Ochl_Day.csv" "http://127.0.0.1:9900/imp?name=Ochl_Day&timestamp=time&partitionBy=DAY&fmt=json"
```

**Functions.** `to_str(time, 'yyyy-MM-dd HH:mm:ss')` formats a time with QuestDB's letters.

## What is different from PostgreSQL

- `WITH` queries that change data run before the main query and the main query sees their changes (PostgreSQL uses one snapshot). The app's statements give the same answers.
- A recursive `WITH` query stops with an error after 100,000 rounds or 10 million rows.
- Advisory locks wait at most 30 seconds.
- Time zones are fixed offsets; `AT TIME ZONE 'Europe/London'` is refused.
- A plain column name in `ON CONFLICT DO UPDATE SET` means the row that is there (PostgreSQL calls it ambiguous).
- Casting a whole number from `double precision` rounds half away from zero (PostgreSQL: to the nearest even number).
- Arrays have one dimension in binary form; nested arrays are sent as text.
- `refdata.companies` means the table `companies` of the **database** `refdata` on the same server (PostgreSQL would look for a schema `refdata`). You can read it in `SELECT`, joins, subqueries and `INSERT ... SELECT`. A statement changes only the database it runs in. `public.companies` is your own table. The help topic **Queries across databases** has the details.

## The app's queries on KarelaDB

`tests/app_compat/run_compat.mjs` runs all 2143 statements of the app against a fresh server with sample data.

| Statements | HTTP before | HTTP now | PostgreSQL protocol before | now |
|---|---|---|---|---|
| All 2143 | 950 (44.3%) | 1971 (92.0%) | 930 (43.4%) | 1952 (91.1%) |
| SELECT (786) | 549 | 734 | 548 | 734 |
| WITH (20) | 0 | 15 | 0 | 15 |
| INSERT (209) | 26 | 142 | 26 | 142 |
| UPDATE (164) | 81 | 156 | 79 | 155 |
| DELETE (72) | 55 | 56 | 55 | 55 |
| Schema statements (889, chapter 22) | 238 | 866 | 221 | 849 |

"Now" is the run of 2026-09-23. Over the PostgreSQL protocol a few QuestDB `ALTER` and `RENAME` statements of the test fail because the test tool replays them in another order (the column or table is already there), and a few test values (`'test'` for a number) are refused earlier, when the parameters are read.

Most of the statements that still fail are not about query support:

- 44 "no unique key" for `ON CONFLICT`: the test schema (`schema_kdb.sql`) was written for an older KarelaDB and left out composite keys. With the app's own `CREATE TABLE` they work.
- Sample values that do not fit (`'test'` for a number), and template parts the test cannot fill (`{{spec.conflict}}`).
- A few features of other chapters: QuestDB's `tables()` functions, and `COPY` sent over HTTP (over the PostgreSQL port `COPY` works, chapter 14).

## Speed

- A statement without the new forms runs the same code as before: the checks are a few flag tests.
- `ON CONFLICT` on the table's key with `DO NOTHING` or a full `DO UPDATE SET ... EXCLUDED` writes batches as fast as `INSERT OR REPLACE`.
- Correlated subqueries and `LATERAL` with `=` joins cost one pass over the inner table plus one hash lookup per outer row.
- A constant `= ANY(...)` becomes `IN (...)`: indexes, key ranges and the column engine still work.
- Queries with `FILTER` or `ORDER BY` inside an aggregate use the row engine.
