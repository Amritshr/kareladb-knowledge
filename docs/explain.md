# EXPLAIN

> See how KarelaDB will read the tables for a query, without running it; with ANALYZE, run it and see what really happened.

- Category: Querying
- Keywords: EXPLAIN, plan, query plan, EXPLAIN ANALYZE, ANALYZE, actual rows, Execution Time, Planning Time, EXPLAIN (FORMAT JSON), FORMAT JSON, BUFFERS, VERBOSE, EXPLAIN WITH, EXPLAIN DELETE, EXPLAIN UPDATE, EXPLAIN INSERT, EXPLAIN CALL, depends on runtime value, explain plan, slow query, partitions skipped, key range, full scan, hash join, nested loop, filter while scanning, filter after joins, read only key range(s), use index, no index, a scan is cheaper, skipped by column stats, zone maps, KARELADB\_NO\_ZONE\_MAPS, answer from saved stats, answer from the partition list, KARELADB\_NO\_PARTITION\_ANSWERS, stored column(s) per row, KARELADB\_NO\_COLUMN\_MASK, engine: column, engine: row, column engine, row engine, speed
- See also: [SELECT (from)](select.md#from), [Joins (join)](joins.md#join), [SAMPLE BY (sample-by)](sample-by.md#sample-by), [LATEST ON (latest-on)](latest-on.md#latest-on), [Partitions, SORT BY and DEDUP KEY (partition-by)](partitions-and-dedup.md#partition-by), [Indexes](indexes.md), [UNION and subqueries (from-subquery)](union-subqueries.md#from-subquery), [Transactions](transactions.md), [pg_stat_activity and pg_stat_statements (pg-stat-statements)](server-activity.md#pg-stat-statements)

`EXPLAIN` shows the **plan** of a query: which tables KarelaDB reads, how many partitions it skips, how it joins, groups and sorts. It does not run the query and does not show rows. [`EXPLAIN ANALYZE`](explain.md#explain-analyze) runs it and adds the real rows and times.

Use it when a query is slow. The most important lines are:

- `scan table ... (1 of 2 partitions ...)`: the time filter lets KarelaDB skip whole partition files. "2 of 2" on a big table means **every** file is read. The `about N rows` in that line is an estimate of the whole table's size, not what the query reads.
- `..., 3 skipped by column stats)` inside that bracket: a condition like `rate > 900` ruled those partitions out from the smallest and biggest value each one holds (see [zone maps](explain.md#zone-maps)).
- `read only N key range(s) of each partition`: KarelaDB jumps straight to the rows of the symbols you asked for.
- `answer from saved stats ...` or `answer from the partition list ...`: KarelaDB answers without reading the rows at all (see [answers without reading rows](explain.md#saved-stats)).

**Example: One symbol, one month: KarelaDB reads 1 of 2 partitions, and only CITY's rows** (sample data: sample)

```sql
EXPLAIN SELECT time, close FROM ochl_day WHERE symbol = 'CITY' AND time IN '2026-09';
```

Result:

| plan (STRING) |
|---|
| scan table ochl_day (1 of 2 partitions, about 57 rows) |
| read only 1 key range(s) of each partition |
| build 3 of 7 stored column(s) per row: time, symbol, close |
| filter while scanning: 2 condition(s) |
| engine: column |

(5 rows)

<a id="explain"></a>

## EXPLAIN

Syntax:

```sql
EXPLAIN SELECT ...
EXPLAIN WITH name AS (SELECT ...) SELECT ...
```

Shows the plan of a `SELECT`, one line per step, in a result with one column called `plan`.

- **Returns:** rows of text, one step per row (see [the plan lines](explain.md#plan-lines)).
- **Notes:**
  - The main query does **not** run. But KarelaDB checks it first: an unknown table or column gives the same error as the query itself.
  - A subquery in `FROM`, a view, and `IN (SELECT ...)` / `(SELECT ...)` values **are** run, because the plan needs their results. EXPLAIN of a query on a slow view is slow too.
  - `INSERT`, `UPDATE`, `DELETE` and `CALL` can be explained too: see [EXPLAIN INSERT, UPDATE, DELETE](explain.md#explain-change) and [EXPLAIN CALL](explain.md#explain-call). `EXPLAIN SELECT ... FOR UPDATE` is an error.
  - `EXPLAIN SELECT` without `FROM` gives an empty plan.
  - With `UNION ALL`, only the first part is described, plus a line `union all with N more part(s)`.
  - In the command line table format long lines are cut. Use `kareladb sql ... --format csv` to see the whole plan.
  - A user with the `read` role can run EXPLAIN.

**Example: Candles: filter, sample, group, sort and limit** (sample data: sample)

```sql
EXPLAIN SELECT time, symbol, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close
FROM ochl_minutes
WHERE time IN '2026-09-10'
SAMPLE BY 15m
ORDER BY symbol, time
LIMIT 10 OFFSET 5;
```

Result:

| plan (STRING) |
|---|
| scan table ochl_minutes (1 of 1 partitions, about 956 rows) |
| build 6 of 7 stored column(s) per row: time, symbol, open, high, low, close |
| filter while scanning: 1 condition(s) |
| sample by SAMPLE BY 15m |
| group by 1 key(s), 4 aggregate(s) |
| sort by 2 key(s) |
| limit 10 offset 5 |
| engine: column |

(8 rows)

**Example: Trade log with the buyer and seller names** (sample data: sample)

```sql
EXPLAIN SELECT f.transaction_id, b.name AS buyer, s.name AS seller, f.amount
FROM trade_log f
JOIN brokers b ON f.buyer = b.id
LEFT JOIN brokers s ON f.seller = s.id
WHERE f.date IN '2026-09-10' AND b.name LIKE 'N%'
ORDER BY f.amount DESC
LIMIT 5;
```

Result:

| plan (STRING) |
|---|
| scan table trade_log (1 of 2 partitions, about 32 rows) |
| join (key lookup on id) table brokers (1 of 1 partitions, about 5 rows) |
| left join (key lookup on id) table brokers (1 of 1 partitions, about 5 rows) |
| build 6 of 7 stored column(s) per row: date, transaction_id, buyer, seller, quantity, rate |
| filter while scanning: 1 condition(s) |
| sort by 1 key(s) |
| limit 5 |
| engine: row (a join) |

(8 rows)

**Example: Latest live price of each symbol** (sample data: sample)

```sql
EXPLAIN SELECT symbol, ltp, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol;
```

Result:

| plan (STRING) |
|---|
| scan table live_data (1 of 1 partitions, about 12 rows) |
| build 4 of 12 stored column(s) per row: timestamp, symbol, ltp, pct_change |
| latest row per partition on timestamp |
| engine: column |

(4 rows)

**Example: A subquery in FROM is run first: the plan shows its row count** (sample data: sample)

```sql
EXPLAIN SELECT t.symbol, t.trades
FROM (SELECT symbol, count(*) AS trades FROM trade_log GROUP BY symbol) t
WHERE t.trades > 5;
```

Result:

| plan (STRING) |
|---|
| scan result of t (3 rows) |
| push 1 condition(s) into subquery t as HAVING |
| filter while scanning: 1 condition(s) |
| engine: row (reads a subquery or view result) |

(4 rows)

**Example: The query is checked: unknown columns are errors** (sample data: sample; shows an error)

```sql
EXPLAIN SELECT time, clsoe FROM ochl_day;
```

Result:

Error: `line 1, column 22: unknown column 'clsoe' (table 'ochl_day' has: time symbol open high low close volume)`

**Example: Schema statements have no plan** (sample data: sample; shows an error)

```sql
EXPLAIN DROP TABLE trade_log;
```

Result:

Error: `line 1, column 9: expected SELECT, WITH, INSERT, UPDATE, DELETE or CALL after EXPLAIN but found 'DROP'`

<a id="explain-analyze"></a>

## EXPLAIN ANALYZE

Syntax:

```sql
EXPLAIN ANALYZE [VERBOSE] SELECT ...        (ANALYSE works too, as in PostgreSQL)
EXPLAIN (ANALYZE [true | false] [, FORMAT TEXT | JSON] [, VERBOSE] [, BUFFERS] [, COSTS] [, TIMING] [, SUMMARY] [, SETTINGS] [, WAL]) SELECT ...
```

Runs the query, then shows its plan and what really happened: the rows and the time of every part of the query, which engine read each table, the partitions read and skipped, and the memory it held.

- **Returns:** the plan lines of [EXPLAIN](explain.md#explain), then:

| Line | Meaning |
|---|---|
| `actual: N row(s) in T ms` | the rows the query gave, and the time it took to run |
| `-> table: N row(s) in T ms, engine: ..., partitions: k of n read (s skipped)` | one line per part of the query that ran: the query itself, then each subquery, view, `WITH` query and `UNION ALL` part, moved in by two spaces per level. `engine:` is `column` or `row (why)`, as in [the plan lines](explain.md#plan-lines). `(no FROM)` for a part without a table |
| `steps: prepare ..., scan and aggregate ..., sort ..., limit and result ...` | where that part's time went. `prepare` binds the query and runs the subqueries it reads; the main step is `scan and filter`, `scan and aggregate`, `scan and sample by`, `scan and window functions`, `scan, join and filter` or `answer from the partition list` |
| `partitions read: N` | partition files read in all, subqueries included |
| `memory: M held at most` | the most the query held at one time, by its own count of kept rows, groups and join tables (the same count the [memory limit](cli-serve.md#memory-limit) uses) |
| `Planning Time: T ms`, `Execution Time: T ms` | as in PostgreSQL: making the plan (with the subqueries it runs), and running the query |

- **Notes:**
  - The query really runs, with its [time limit](protection.md#statement-timeout) and memory limits, and can be cancelled. Its rows are not sent.
  - Only a `SELECT` that changes nothing is run. `EXPLAIN ANALYZE` of `INSERT`, `UPDATE`, `DELETE` or `CALL`, of `SELECT ... FOR UPDATE`, and of `WITH x AS (DELETE ...) SELECT ...` is refused, and nothing is changed: use `EXPLAIN` without `ANALYZE` for their plan. (PostgreSQL would run them and change the data.)
  - `VERBOSE`, `BUFFERS`, `COSTS`, `SUMMARY` and `SETTINGS` are accepted; KarelaDB has no costs or buffer counts to add. `TIMING` and `WAL` need `ANALYZE`, as in PostgreSQL. `FORMAT XML` and `YAML` are not supported.
  - Times are wall-clock milliseconds of this run; run it twice to see the effect of files already in memory.

**Example: Where the time of a candle report goes: the column engine, 1 of 2 partitions** (sample data: sample)

```sql
EXPLAIN ANALYZE SELECT symbol, max(high) AS high, min(low) AS low FROM ochl_day WHERE time IN '2026-09' GROUP BY symbol ORDER BY symbol;
```

Result:

| plan (STRING) |
|---|
| scan table ochl_day (1 of 2 partitions, about 57 rows) |
| build 4 of 7 stored column(s) per row: time, symbol, high, low |
| filter while scanning: 1 condition(s) |
| group by 1 key(s), 2 aggregate(s) |
| sort by 1 key(s) |
| engine: column |
| actual: 3 row(s) in 0.489 ms |
|   -> ochl_day: 3 row(s) in 0.466 ms, engine: column, partitions: 1 of 2 read (1 skipped) |
|      steps: prepare 0.019 ms, scan and aggregate 0.446 ms |
| partitions read: 1 |
| memory: 2016 bytes held at most (the statement's own count of the rows, groups and joins it keeps) |
| Planning Time: 0.223 ms |
| Execution Time: 0.489 ms |

(13 rows)

**Example: A join runs on the row engine; its subquery is a part of its own** (sample data: sample)

```sql
EXPLAIN ANALYZE SELECT b.name, t.trades
FROM (SELECT buyer, count(*) AS trades FROM trade_log GROUP BY buyer) t
JOIN brokers b ON t.buyer = b.id
ORDER BY t.trades DESC LIMIT 3;
```

Result:

| plan (STRING) |
|---|
| scan result of t (5 rows) |
| join (hash on 1 key(s)) table brokers (1 of 1 partitions, about 5 rows) |
| sort by 1 key(s) |
| limit 3 |
| engine: row (a join) |
| actual: 3 row(s) in 0.332 ms |
|   -> t, brokers: 3 row(s) in 0.318 ms, engine: row (a join) |
|      steps: prepare 0.091 ms, scan, join and filter 0.217 ms, sort 0.009 ms, limit and result 0.002 ms |
|     -> trade_log: 5 row(s) in 0.062 ms, engine: row (a condition, group key or aggregate the column engine does not do), partitions: 2 of 2 read |
|        steps: prepare 0.021 ms, scan and aggregate 0.039 ms, result 0.002 ms |
| partitions read: 3 |
| memory: 1059 bytes held at most (the statement's own count of the rows, groups and joins it keeps) |
| Planning Time: 0.792 ms |
| Execution Time: 0.332 ms |

(14 rows)

**Example: A change is not run** (sample data: sample; shows an error)

```sql
EXPLAIN ANALYZE DELETE FROM trade_log;
```

Result:

Error: `EXPLAIN ANALYZE runs the statement to measure it, and KarelaDB does that for SELECT only: an INSERT, UPDATE, DELETE or CALL would really change data. Use EXPLAIN without ANALYZE for its plan`

<a id="explain-json"></a>

## EXPLAIN (FORMAT JSON)

Syntax:

```sql
EXPLAIN (FORMAT JSON) SELECT | INSERT | UPDATE | DELETE | CALL ...
EXPLAIN (ANALYZE, FORMAT JSON) SELECT ...
```

The plan as one JSON value, for tools: one row in the column `plan`.

- **Returns:** `[{"Plan": {"Node Type": "Query", "Plan Lines": [...]}}]`. With `ANALYZE` the plan also has `"Actual Rows"`, `"Actual Total Time"` and `"Plans"`: one object per part of the query that ran, with `"Relation Name"`, `"Depth"`, `"Engine"`, `"Actual Rows"`, `"Actual Total Time"`, `"Steps"` (`[{"Step": ..., "Time": ...}]`) and, for a table, `"Partitions Total"`, `"Partitions Read"`, `"Partitions Skipped"`, `"Partitions Skipped By Column Stats"`. Next to `"Plan"` come `"Partitions Read"`, `"Peak Memory Bytes"`, `"Planning Time"` and `"Execution Time"`.
- **Notes:** the shape is PostgreSQL's (an array with one object holding `"Plan"`), but KarelaDB's plan is a list of steps, not a tree of costed nodes: its lines are in `"Plan Lines"`. Times are milliseconds.

**Example: The plan of a report, for a tool** (sample data: sample)

```sql
EXPLAIN (FORMAT JSON) SELECT symbol, last(close) AS close FROM ochl_day GROUP BY symbol;
```

Result:

| plan (STRING) |
|---|
| [{"Plan": {"Node Type": "Query", "Plan Lines": ["scan table ochl_day (2 of 2 partitions, about 57 rows)", "build 3 of 7 stored column(s) per row: time, symbol, close", "group by 1 key(s), 1 aggrega... |

(1 row)

**Example: What really happened, as JSON** (sample data: sample)

```sql
EXPLAIN (ANALYZE, FORMAT JSON) SELECT count(*) AS trades FROM trade_log WHERE date IN '2026-09-10';
```

Result:

| plan (STRING) |
|---|
| [{"Plan": {"Node Type": "Query", "Plan Lines": ["scan table trade_log (1 of 2 partitions, about 32 rows)", "build 1 of 7 stored column(s) per row: date", "filter while scanning: 1 condition(s)", "g... |

(1 row)

<a id="explain-change"></a>

## EXPLAIN INSERT, UPDATE, DELETE

Syntax:

```sql
EXPLAIN DELETE FROM table [WHERE ...]
EXPLAIN UPDATE table SET ... [WHERE ...]
EXPLAIN INSERT INTO table [(columns)] SELECT ...
EXPLAIN INSERT INTO table [(columns)] VALUES (...), ...
```

Shows how the statement finds its rows: partitions, key ranges, index. **No row is changed.**

- **Returns:** rows of text in the column `plan`.
- **Notes:**
  - `DELETE` and `UPDATE` start with `delete from table t (k of n partitions, about r rows)` or `update table t (...)`. Then come the same lines as for a `SELECT` scan: `use index ...` or `read only k key range(s) ...`, and `filter while scanning: k condition(s)`. `UPDATE` ends with `set k column(s)`.
  - `INSERT ... SELECT` shows `insert into table t the rows of this query:` and the plan of the `SELECT` under it, moved in by two spaces.
  - `INSERT ... VALUES` shows only how many rows it has.
  - Other lines: `run the WITH queries first`, `find the rows with the column engine and take them from its scan` (a big keyed table, a condition without an index that the column engine checks; `KARELADB_NO_VECTOR_MATCHES=1` gives the older `find the rows with the column engine, then read only them by their keys`), `look up the key of every row for a clash` (`ON CONFLICT`, `INSERT OR REPLACE`), `find the target rows by t.id IN (1, 2), then match them with the rows of USING` (or `FROM`; `match every row with the rows of USING` when no part of the WHERE finds them first), `return k item(s) per row` (`RETURNING`).
  - An `UPDATE` or `DELETE` uses an index whenever one fits: it has no `no index: ...` choice. Partitions ruled out by column stats are left out of `k of n`, but the plan does not say how many.
  - The same rights are needed as for the statement itself: `EXPLAIN DELETE` needs `DELETE` on the table.
  - With `UPDATE ... FROM` or `DELETE ... USING`, conditions that use the other table are counted as `filter after matching`.

**Example: Delete one day of one symbol: 1 partition, 1 key range** (sample data: sample)

```sql
EXPLAIN DELETE FROM ochl_day WHERE symbol = 'CITY' AND time IN '2026-09-10';
SELECT count(*) AS rows_still_there FROM ochl_day WHERE symbol = 'CITY' AND time IN '2026-09-10';
```

Result:

`EXPLAIN DELETE FROM ochl_day WHERE symbol = 'CITY' AND time IN '2026-09-10'`

| plan (STRING) |
|---|
| delete from table ochl_day (1 of 2 partitions, about 57 rows) |
| read only 1 key range(s) of each partition |
| filter while scanning: 2 condition(s) |

(3 rows)

`SELECT count(*) AS rows_still_there FROM ochl_day WHERE symbol = 'CITY' AND time IN '2026-09-10'`

| rows_still_there (LONG) |
|---|
| 1 |

(1 row)

**Example: An update of the trades of one day** (sample data: sample)

```sql
EXPLAIN UPDATE trade_log SET rate = rate * 1.01 WHERE date IN '2026-09-10' AND symbol = 'CITY';
```

Result:

| plan (STRING) |
|---|
| update table trade_log (1 of 2 partitions, about 32 rows) |
| read only 1 key range(s) of each partition |
| filter while scanning: 2 condition(s) |
| set 1 column(s) |

(4 rows)

**Example: Copy CITY's closes of September into another table** (sample data: sample)

Setup:

```sql
CREATE TABLE city_closes (time TIMESTAMP, close DOUBLE) TIMESERIES(time) PARTITION BY MONTH;
```

```sql
EXPLAIN INSERT INTO city_closes SELECT time, close FROM ochl_day WHERE symbol = 'CITY' AND time IN '2026-09';
```

Result:

| plan (STRING) |
|---|
| insert into table city_closes the rows of this query: |
|   scan table ochl_day (1 of 2 partitions, about 57 rows) |
|   read only 1 key range(s) of each partition |
|   build 3 of 7 stored column(s) per row: time, symbol, close |
|   filter while scanning: 2 condition(s) |
|   engine: column |

(6 rows)

<a id="explain-call"></a>

## EXPLAIN CALL

Syntax:

```sql
EXPLAIN CALL procedure(argument, ...)
```

Shows the plan of every statement in the [procedure](procedures.md), with the arguments you give. **Nothing runs** and nothing is changed.

- **Returns:** rows of text in the column `plan`: first `procedure name(param = value, ...)`, then `step N: <statement>` for each statement, with its plan moved in under it.
- **Notes:**
  - A variable whose value needs no table (`DECLARE k LONG DEFAULT 5`, `SET d2 = dateadd('d', -1, d)`) is worked out, and its value is shown (`k = 5`).
  - A variable that needs a query (`DEFAULT (SELECT ...)`), a `FETCH` or a loop gets `depends on runtime value`. So does every statement that uses it.
  - An `IF` whose condition is known shows `true` or `false`, and only the branch that would run. Otherwise it shows `depends on runtime value` and every branch.
  - `WHILE` and `FOR` bodies are shown once, as `every pass` or `every row`.
  - A `CALL` of another procedure is not opened: explain that one on its own.
  - `WITH DEBUG` cannot be added: use [CALL ... WITH DEBUG](procedures.md#with-debug) to run the procedure and see what each step did.

**Example: The plan of a procedure that clears one day of one symbol** (sample data: sample)

Setup:

```sql
CREATE PROCEDURE clear_day(d TIMESTAMP, sym SYMBOL) AS BEGIN
  DECLARE left_rows LONG DEFAULT (SELECT count(*) FROM ochl_day WHERE symbol = sym);
  DECLARE d_end TIMESTAMP DEFAULT dateadd('d', 1, d);
  DELETE FROM ochl_day WHERE symbol = sym AND time >= d AND time < d_end;
  IF left_rows > 100 THEN
    PRINT 'many rows';
  END IF;
END;
```

```sql
EXPLAIN CALL clear_day('2026-09-10T00:00:00Z', 'CITY');
```

Result:

| plan (STRING) |
|---|
| procedure clear_day(d = 2026-09-10T00:00:00.000Z, sym = 'CITY') |
| step 1: DECLARE left_rows LONG DEFAULT (SELECT count(*) FROM ochl_day WHERE symbol = sym) |
|   left_rows: depends on runtime value |
| step 2: DECLARE d_end TIMESTAMP DEFAULT dateadd('d', 1, d) |
|   d_end = 2026-09-11T00:00:00.000Z |
| step 3: DELETE FROM ochl_day WHERE symbol = sym AND time >= d AND time < d_end |
|   delete from table ochl_day (1 of 2 partitions, about 57 rows) |
|   read only 1 key range(s) of each partition |
|   filter while scanning: 3 condition(s) |
| step 4: IF left_rows > 100 THEN: depends on runtime value |
|   step 5: PRINT 'many rows' |

(11 rows)

**Example: EXPLAIN CALL does not take WITH DEBUG** (sample data: sample; shows an error)

Setup:

```sql
CREATE PROCEDURE clear_day(d TIMESTAMP, sym SYMBOL) AS BEGIN
  DELETE FROM ochl_day WHERE symbol = sym AND time >= d;
END;
```

```sql
EXPLAIN CALL clear_day('2026-09-10T00:00:00Z', 'CITY') WITH DEBUG;
```

Result:

Error: `line 1, column 9: EXPLAIN CALL does not run the procedure, so WITH DEBUG has nothing to show; use CALL ... WITH DEBUG`

<a id="plan-lines"></a>

## The plan lines

Syntax:

```sql
aggregates pushed into the k UNION ALL parts: each part groups its own table first
window functions over grouped rows: the grouping runs first as a subquery
answer from the partition list of table name (k of n partitions; no other rows read)
scan table name (k of n partitions, about r rows[, s skipped by column stats])
scan result of name (r rows)
push k condition(s) into view | subquery name [after its windows]
push k rank limit(s) into subquery name
time range from the calendar condition(s): col >= 'start' AND < 'end'
use index name (...)
no index: name would read r row(s), a scan is cheaper[; it reads only the storage keys those rows lie between]
no index: the column stats rule out every partition
answer from saved stats of table name: ...
join | left join | asof join | cross join (hash on k key(s) | key lookup on columns | index lookup on column | nested loop) table name (...)
read only k key range(s) of each partition
build k of n stored column(s) per row: columns
filter while scanning: k condition(s)
filter after joins: k condition(s)
latest row per partition on column
sample by SAMPLE BY ...
group by k key(s), m aggregate(s)
k window/series function(s)
distinct
sort by k key(s)
limit n [offset m]
union all with k more part(s)
delete from | update table name (k of n partitions, about r rows)
set k column(s)
insert into table name the rows of this query:
```

The lines come in this order. A line is missing when the query does not have that step.

| Line | Meaning |
|---|---|
| `aggregates pushed into the k UNION ALL parts ...` | A `GROUP BY` over a `UNION ALL` in `FROM`: each part groups its own table first (see [UNION ALL](union-subqueries.md)). |
| `window functions over grouped rows ...` | A window function over a `GROUP BY` result: the grouping runs first. |
| `answer from the partition list ...` | See [answers without reading rows](explain.md#saved-stats). It is then the whole plan, with `sort by` and `limit` after it. |
| `scan table t (k of n partitions, about r rows)` | The first table of `FROM`. KarelaDB reads `k` of its `n` partition files; the others are skipped because of the time filter, the symbols, or [column stats](explain.md#zone-maps). `about r rows` is only an **estimate** of the size of the **whole** table. It is not the number of rows this query reads or matches: for that, run `SELECT count(*)` with the same `WHERE`. |
| `scan result of name (r rows)` | The first source is a subquery or a view. It has already run and gave `r` rows. A subquery without a name (`FROM (SELECT ...)` with no alias) shows as `a subquery`; in part n of a `UNION ALL` it shows as `subquery n`, so the parts can be told apart (also in `EXPLAIN ANALYZE`). |
| `push k condition(s) into ...` | Conditions of your `WHERE` also run inside the view or subquery, so it makes fewer rows (see [views](views.md)). With `after its windows`: they run inside a window query right after its window values are worked out, so it makes only the rows you keep (see [views](views.md#where-pushdown)). |
| `push k rank limit(s) into ...` | `rn <= N` on a `row_number`, `rank` or `dense_rank` column of a window query: the rows above N are dropped inside it, and `row_number()` orders only the first N rows of each partition (see [views](views.md#where-pushdown)). |
| `time range from the calendar condition(s): ...` | `EXTRACT(YEAR FROM ts) = 2026 AND EXTRACT(MONTH FROM ts) = 8`, `year(ts) = 2026`, `date_trunc('month', ts) = '2026-08-01'` and the like on a `TIMESTAMP` column: KarelaDB puts the time range they mean (in UTC) in their place: it keeps exactly the same rows, and partitions, indexes, key ranges and the column engine can use it. |
| `use index name (...)` | A secondary index finds the rows (see [indexes](indexes.md)). |
| `count from the index (no rows read)` | `SELECT count(*)` whose whole `WHERE` the index answers exactly (a [full-text](full-text-search.md) `MATCH`, or the `WHERE` of a partial index): the answer is the index's own count, and no row is read. |
| `index gives the first n row(s) in order` | A `LIMIT` (plus `OFFSET`) the index answers alone, with no `ORDER BY` or one by the table's key: only the first `n` rows the index finds are read. |
| `no index: the column stats rule out every partition` | The [column stats](explain.md#zone-maps) show that no partition can hold a match, so the answer is empty and no index is read. |
| `no index: name would read r row(s), a scan is cheaper` | An index fits, but it finds so many rows that reading the partitions is faster (see [when an index is used](indexes.md#when-used)). |
| `...; it reads only the storage keys those rows lie between` | A relational table with an index on a time column: rows written together have nearby times, so the rows the index finds lie in one stretch of the table. The scan reads only that stretch (the `read only 1 key range(s)` line), on all threads. When the index finds more than a quarter of the table, KarelaDB scans the whole table instead: that is faster than walking the index. |
| `answer from saved stats of table t: ...` | `count`, `sum`, `min`, `max` of whole partitions come from numbers the files keep (see [answers without reading rows](explain.md#saved-stats)). |
| `join (hash on k key(s)) table t` | An inner join. KarelaDB builds a lookup on the `a = b` conditions of `ON`: fast. |
| `join (key lookup on columns) table t` | The `ON` conditions give the first columns of `t`'s key (its `PRIMARY KEY`, or `SORT BY` / `DEDUP KEY` with the time column): each left row reads only its own rows of `t`, and nothing is built first. Chosen when the left side is small next to `t` (see [joins](joins.md#join-speed)). |
| `join (index lookup on column) table t` | The same through an index on that column of `t`. |
| `left join ...`, `asof join ...`, `cross join ...` | The other kinds of [joins](joins.md#join). |
| `(nested loop)` | The join has no `a = b` condition, so every left row is checked with every right row: slow for big tables. |
| `read only k key range(s) of each partition` | Rows are stored sorted (by symbol, then time). `symbol = '...'` or `symbol IN (...)` lets KarelaDB read only those parts of each file. It also follows a `...reads only the storage keys ...` line. |
| `build k of n stored column(s) per row: ...` | The columns KarelaDB takes out of each stored row: only the ones the query uses. A `SELECT *` reads them all and has no such line. |
| `filter while scanning: k condition(s)` | Parts of `WHERE` (joined by `AND`) that use only the first table. They are checked while the rows are read. |
| `filter after joins: k condition(s)` | Parts of `WHERE` that use a joined table. They are checked after the join. |
| `latest row per partition on col` | [LATEST ON](latest-on.md#latest-on). |
| `sample by ...` | [SAMPLE BY](sample-by.md#sample-by) with its options. |
| `group by k key(s), m aggregate(s)` | Grouping. Aggregates in `HAVING` are counted too. |
| `k window/series function(s)` | `sma`, `lag`, `row_number`, ... |
| `distinct`, `sort by k key(s)`, `limit n offset m` | `SELECT DISTINCT`, `ORDER BY`, `LIMIT` / `OFFSET`. |
| `newest first: reads time >= '...' first, then older time windows only while fewer than n rows are found` | `ORDER BY time DESC LIMIT n` (also the newest `n` buckets of a `SAMPLE BY`) reads the newest rows first and stops once it has `n` (see [LIMIT](performance-tips.md#limit)). The time is where the first stretch starts; when the table has few rows, the line is left out and the query reads them all. After a view or subquery that only filters one table it says `(the view v read as a filter on its table)`. |
| `oldest first: reads time < '...' first, then newer time windows only while fewer than n rows are found` | The same for `ORDER BY time LIMIT n`: the oldest rows or buckets. |
| `union all with k more part(s)` | The other parts of a `UNION ALL`. |
| `engine: column` | The last line. The **column engine** reads the table: whole columns at a time, on all threads. This is the fast way. With window functions it says `engine: column (finds the rows; ...)`: the rows are found that way, then the window functions go row by row. A `GROUP BY` over two joined tables says `engine: column (hash join)` (see [GROUP BY over a join](joins.md#join-column-engine)). |
| `engine: row (why)` | The **row engine** reads the table one row at a time: slower on big tables. The brackets say why, for example `a join`, `an expression in the SELECT list`, `SAMPLE BY months or years`, or `a condition the column engine does not do` (see [WHERE: fast conditions](where.md#fast-conditions)). |

- **Notes:**
  - Only the **first** table in `FROM` skips partitions. A time filter on a joined table does not make it read less: its line always shows all partitions. Put the big time-series table first.
  - A function around the column (`upper(symbol) = 'CITY'`) stops the key ranges: the `read only ...` line disappears.
  - For a `DATE` time column, KarelaDB also reads the partition of the next day, to be safe.
  - The `engine:` line uses the same tests the query uses when it runs. Only the data can still change it: a partition whose `min` / `max` column holds a NaN is read by the row engine. Which conditions keep a query in the fast column engine: see [WHERE: fast conditions](where.md#fast-conditions).

**Example: Good: the symbol is written plainly, so KarelaDB reads 2 key ranges** (sample data: sample)

```sql
EXPLAIN SELECT time, symbol, close FROM ochl_day WHERE symbol IN ('CITY', 'COAST') AND time >= '2026-09-01';
```

Result:

| plan (STRING) |
|---|
| scan table ochl_day (1 of 2 partitions, about 57 rows) |
| read only 2 key range(s) of each partition |
| build 3 of 7 stored column(s) per row: time, symbol, close |
| filter while scanning: 2 condition(s) |
| engine: column |

(5 rows)

**Example: Slow: a function around symbol reads every row of every partition** (sample data: sample)

```sql
EXPLAIN SELECT time, symbol, close FROM ochl_day WHERE upper(symbol) = 'CITY';
```

Result:

| plan (STRING) |
|---|
| scan table ochl_day (2 of 2 partitions, about 57 rows) |
| build 3 of 7 stored column(s) per row: time, symbol, close |
| filter while scanning: 1 condition(s) |
| engine: row (a condition the column engine does not do) |

(4 rows)

**Example: Which engine: the same report, fast and slow** (sample data: sample)

```sql
EXPLAIN SELECT symbol, avg(close) AS avg_close FROM ochl_day WHERE close > 500 GROUP BY symbol;
EXPLAIN SELECT symbol, avg(close) AS avg_close FROM ochl_day WHERE upper(symbol) = 'CITY' GROUP BY symbol;
```

Result:

`EXPLAIN SELECT symbol, avg(close) AS avg_close FROM ochl_day WHERE close > 500 GROUP BY symbol`

| plan (STRING) |
|---|
| scan table ochl_day (2 of 2 partitions, about 57 rows) |
| build 3 of 7 stored column(s) per row: time, symbol, close |
| filter while scanning: 1 condition(s) |
| group by 1 key(s), 1 aggregate(s) |
| engine: column |

(5 rows)

`EXPLAIN SELECT symbol, avg(close) AS avg_close FROM ochl_day WHERE upper(symbol) = 'CITY' GROUP BY s`

| plan (STRING) |
|---|
| scan table ochl_day (2 of 2 partitions, about 57 rows) |
| build 3 of 7 stored column(s) per row: time, symbol, close |
| filter while scanning: 1 condition(s) |
| group by 1 key(s), 1 aggregate(s) |
| engine: row (a condition, group key or aggregate the column engine does not do) |

(5 rows)

**Example: Big table first: the time filter skips partitions** (sample data: sample)

```sql
EXPLAIN SELECT b.name, sum(f.amount) AS turnover
FROM trade_log f JOIN brokers b ON f.buyer = b.id
WHERE f.date IN '2026-09-10'
GROUP BY b.name ORDER BY turnover DESC LIMIT 3;
```

Result:

| plan (STRING) |
|---|
| scan table trade_log (1 of 2 partitions, about 32 rows) |
| join (key lookup on id) table brokers (1 of 1 partitions, about 5 rows) |
| build 4 of 7 stored column(s) per row: date, buyer, quantity, rate |
| filter while scanning: 1 condition(s) |
| group by 1 key(s), 1 aggregate(s) |
| sort by 1 key(s) |
| limit 3 |
| engine: row (a condition, join column, group key or aggregate the column engine does not do) |

(8 rows)

**Example: Big table second: every trade log partition is read** (sample data: sample)

```sql
EXPLAIN SELECT b.name, sum(f.amount) AS turnover
FROM brokers b JOIN trade_log f ON f.buyer = b.id
WHERE f.date IN '2026-09-10'
GROUP BY b.name ORDER BY turnover DESC LIMIT 3;
```

Result:

| plan (STRING) |
|---|
| scan table brokers (1 of 1 partitions, about 5 rows) |
| join (hash on 1 key(s)) table trade_log (2 of 2 partitions, about 32 rows) |
| group by 1 key(s), 1 aggregate(s) |
| sort by 1 key(s) |
| limit 3 |
| engine: row (a condition, join column, group key or aggregate the column engine does not do) |

(6 rows)

**Example: No a = b condition: a nested loop** (sample data: sample)

```sql
EXPLAIN SELECT s.symbol, b.name FROM securities s CROSS JOIN brokers b;
```

Result:

| plan (STRING) |
|---|
| scan table securities (1 of 1 partitions, about 5 rows) |
| cross join (nested loop) table brokers (1 of 1 partitions, about 5 rows) |
| build 1 of 3 stored column(s) per row: symbol |
| engine: row (a join) |

(4 rows)

**Example: Live prices with the last minute candle, and a moving average** (sample data: sample)

```sql
EXPLAIN SELECT l.timestamp, l.symbol, l.ltp, m.close
FROM live_data l
ASOF JOIN ochl_minutes m ON l.symbol = m.symbol;
EXPLAIN SELECT time, close, sma(close, 3) AS sma3 FROM ochl_day WHERE symbol = 'CITY';
```

Result:

`EXPLAIN SELECT l.timestamp, l.symbol, l.ltp, m.close FROM live_data AS l ASOF JOIN ochl_minutes AS m`

| plan (STRING) |
|---|
| scan table live_data (1 of 1 partitions, about 12 rows) |
| asof join (hash on 1 key(s)) table ochl_minutes (1 of 1 partitions, about 956 rows) |
| build 3 of 12 stored column(s) per row: timestamp, symbol, ltp |
| engine: row (a join) |

(4 rows)

`EXPLAIN SELECT time, close, sma(close, 3) AS sma3 FROM ochl_day WHERE symbol = 'CITY'`

| plan (STRING) |
|---|
| scan table ochl_day (2 of 2 partitions, about 57 rows) |
| read only 1 key range(s) of each partition |
| build 3 of 7 stored column(s) per row: time, symbol, close |
| filter while scanning: 1 condition(s) |
| 1 window/series function(s) |
| engine: column (finds the rows; the window functions then run row by row) |

(6 rows)

**Example: DISTINCT and UNION ALL** (sample data: sample)

```sql
EXPLAIN SELECT DISTINCT symbol FROM trade_log;
EXPLAIN SELECT symbol FROM trade_log WHERE buyer = 58 UNION ALL SELECT symbol FROM trade_log WHERE seller = 58;
```

Result:

`EXPLAIN SELECT DISTINCT symbol FROM trade_log`

| plan (STRING) |
|---|
| distinct: run as a GROUP BY of every column |
| scan table trade_log (2 of 2 partitions, about 32 rows) |
| build 2 of 7 stored column(s) per row: date, symbol |
| group by 1 key(s), 0 aggregate(s) |
| engine: row (a condition, group key or aggregate the column engine does not do) |

(5 rows)

`EXPLAIN SELECT symbol FROM trade_log WHERE buyer = 58 UNION ALL SELECT symbol FROM trade_log WHERE s`

| plan (STRING) |
|---|
| scan table trade_log (2 of 2 partitions, about 32 rows) |
| build 3 of 7 stored column(s) per row: date, symbol, buyer |
| filter while scanning: 1 condition(s) |
| engine: row (a condition the column engine does not do) |
| union all with 1 more part(s) |

(5 rows)

**Example: A DATE time column also reads the next day's partition**

Setup:

```sql
CREATE TABLE daily_nav (day DATE, fund SYMBOL, nav DOUBLE) TIMESERIES(day) PARTITION BY DAY;
INSERT INTO daily_nav VALUES ('2026-09-08', 'GRWF', 10.2), ('2026-09-09', 'GRWF', 10.3), ('2026-09-10', 'GRWF', 10.1);
```

```sql
EXPLAIN SELECT day, nav FROM daily_nav WHERE day = '2026-09-09';
```

Result:

| plan (STRING) |
|---|
| scan table daily_nav (2 of 3 partitions, about 3 rows) |
| build 2 of 3 stored column(s) per row: day, nav |
| filter while scanning: 1 condition(s) |
| engine: column |

(4 rows)

**Example: Over 10,000 rows: an index that finds a fifth of them is not used** (sample data: sample)

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, broker INT, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO ticks SELECT m.time, m.symbol, b.id, m.close FROM ochl_minutes m CROSS JOIN brokers b CROSS JOIN securities s;
CREATE INDEX ticks_broker ON ticks (broker);
```

```sql
EXPLAIN SELECT time, price FROM ticks WHERE broker = 58;
```

Result:

| plan (STRING) |
|---|
| scan table ticks (2 of 2 partitions, about 23900 rows) |
| no index: ticks_broker would read 4780 row(s), a scan is cheaper; it reads only the storage keys those rows lie between |
| read only 1 key range(s) of each partition |
| build 3 of 4 stored column(s) per row: time, broker, price |
| filter while scanning: 1 condition(s) |
| engine: column |

(6 rows)

**Example: An index on buyer: buyer = 58 uses it, a condition with OR does not** (sample data: sample)

Setup:

```sql
CREATE INDEX trade_log_buyer ON trade_log (buyer);
```

```sql
EXPLAIN SELECT transaction_id, symbol, quantity FROM trade_log WHERE buyer = 58;
EXPLAIN SELECT transaction_id, symbol, quantity FROM trade_log WHERE buyer = 58 OR seller = 58;
```

Result:

`EXPLAIN SELECT transaction_id, symbol, quantity FROM trade_log WHERE buyer = 58`

| plan (STRING) |
|---|
| scan table trade_log (2 of 2 partitions, about 32 rows) |
| use index trade_log_buyer (buyer = value) |
| build 5 of 7 stored column(s) per row: date, transaction_id, symbol, buyer, quantity |
| filter while scanning: 1 condition(s) |
| engine: row (a condition the column engine does not do) |

(5 rows)

`EXPLAIN SELECT transaction_id, symbol, quantity FROM trade_log WHERE buyer = 58 OR seller = 58`

| plan (STRING) |
|---|
| scan table trade_log (2 of 2 partitions, about 32 rows) |
| build 6 of 7 stored column(s) per row: date, transaction_id, symbol, buyer, seller, quantity |
| filter while scanning: 1 condition(s) |
| engine: row (a condition the column engine does not do) |

(4 rows)

**Example: A full-text count and a first page: the index answers them alone** (sample data: content-news)

Setup:

```sql
CREATE FULLTEXT INDEX news_text ON news (title, body);
```

```sql
EXPLAIN SELECT count(*) FROM news WHERE MATCH(title, body, 'bank');
EXPLAIN SELECT id FROM news WHERE MATCH(title, body, 'bank') LIMIT 2;
```

Result:

`EXPLAIN SELECT count(*) FROM news WHERE match(title, body, 'bank')`

| plan (STRING) |
|---|
| scan table news (1 of 1 partitions, about 5 rows) |
| use index news_text (full-text search) |
| count from the index (no rows read) |
| answer from saved stats of table news: 1 of 1 partitions from the partition list and their files' stats (0 in memory, 0 partitions loaded, 0 file headers read); 0 partitions scanned |
| build 0 of 5 stored column(s) per row:  |
| group by 0 key(s), 1 aggregate(s) |
| engine: column |

(7 rows)

`EXPLAIN SELECT id FROM news WHERE match(title, body, 'bank') LIMIT 2`

| plan (STRING) |
|---|
| scan table news (1 of 1 partitions, about 5 rows) |
| use index news_text (full-text search) |
| index gives the first 2 row(s) in order |
| build 1 of 5 stored column(s) per row: id |
| limit 2 |
| engine: column |

(6 rows)

**Example: Unnamed subqueries in a UNION ALL: subquery 1, subquery 2** (sample data: sample)

```sql
EXPLAIN ANALYZE SELECT symbol FROM (SELECT symbol FROM trade_log WHERE buyer = 58)
UNION ALL SELECT symbol FROM (SELECT symbol FROM trade_log WHERE seller = 58);
```

Result:

| plan (STRING) |
|---|
| scan result of subquery 1 (6 rows) |
| engine: row (reads a subquery or view result) |
| union all with 1 more part(s) |
| actual: 10 row(s) in 0.338 ms |
|   -> subquery 1: 6 row(s) in 0.218 ms, engine: row (reads a subquery or view result) |
|      steps: prepare 0.213 ms, scan and filter 0.004 ms, result 0.001 ms |
|     -> trade_log: 6 row(s) in 0.177 ms, engine: row (a condition the column engine does not do), partitions: 2 of 2 read |
|        steps: prepare 0.069 ms, scan and filter 0.105 ms, result 0.002 ms |
|   -> subquery 2: 4 row(s) in 0.057 ms, engine: row (reads a subquery or view result) |
|      steps: prepare 0.055 ms, scan and filter 0.002 ms, result 0.001 ms |
|     -> trade_log: 4 row(s) in 0.031 ms, engine: row (a condition the column engine does not do), partitions: 1 of 2 read (1 skipped, 1 of them by column stats) |
|        steps: prepare 0.016 ms, scan and filter 0.015 ms, result 0.001 ms |
| partitions read: 3 |
| memory: 0 bytes held at most (the statement's own count of the rows, groups and joins it keeps) |
| Planning Time: 1.596 ms |
| Execution Time: 0.338 ms |

(16 rows)

<a id="zone-maps"></a>

## Zone maps: partitions skipped by column stats

Syntax:

```sql
scan table t (k of n partitions, about r rows, s skipped by column stats)
```

Every partition file keeps the smallest and the biggest value of each column. When a condition cannot be true for any value in that range, KarelaDB skips the whole partition. `rate > 900` skips a partition whose biggest `rate` is 883.

| Condition | Skips partitions |
|---|---|
| `col = value`, `<`, `<=`, `>`, `>=` | yes |
| `col BETWEEN a AND b`, `col IN (a, b, c)` | yes |
| `time IN '2026-09'` on another `TIMESTAMP` or `DATE` column | yes |
| `!=`, `NOT BETWEEN`, `NOT IN`, `IS NULL`, `col1 > col2` | no |

- **Columns:** whole numbers, `FLOAT`, `DOUBLE`, `DECIMAL`, `DATE` and `TIMESTAMP`. `SYMBOL` columns are skipped in their own way, by the names each partition holds.
- **Notes:**
  - It works whether the partition is **in memory or not**. For a partition not in memory, KarelaDB reads only the stats part of its file (a few hundred bytes) once and keeps it, also after the rows are pushed out of memory. A file written again (after `UPDATE`, `DELETE` or new rows) has its stats read again.
  - Rows written since the last checkpoint are checked one by one (up to 4,096 per partition). More than that and the partition is read.
  - It works for `SELECT`, `UPDATE` and `DELETE`, in both engines. The result never changes: only what is read.
  - Set `KARELADB_NO_ZONE_MAPS=1` in the environment to turn it off (and the [saved stats answers](explain.md#saved-stats) with it), for a before-and-after timing.

**Example: The biggest rate is 883, so rate > 900 skips both partitions** (sample data: sample)

```sql
SELECT date, max(rate) AS top_rate FROM trade_log GROUP BY date ORDER BY date;
EXPLAIN SELECT transaction_id, rate FROM trade_log WHERE rate > 900;
```

Result:

`SELECT date, max(rate) AS top_rate FROM trade_log GROUP BY date ORDER BY date`

| date (TIMESTAMP) | top_rate (DOUBLE) |
|---|---|
| 2026-09-09T00:00:00.000Z | 881 |
| 2026-09-10T00:00:00.000Z | 883 |

(2 rows)

`EXPLAIN SELECT transaction_id, rate FROM trade_log WHERE rate > 900`

| plan (STRING) |
|---|
| scan table trade_log (0 of 2 partitions, about 32 rows, 2 skipped by column stats) |
| build 3 of 7 stored column(s) per row: date, transaction_id, rate |
| filter while scanning: 1 condition(s) |
| engine: row (a condition the column engine does not do) |

(4 rows)

<a id="saved-stats"></a>

## Answers without reading rows

Syntax:

```sql
answer from saved stats of table t: a of p partitions from the partition list and their files' stats (...); k partitions scanned
answer from the partition list of table t (k of n partitions; no other rows read)
```

Some questions are answered from what KarelaDB already knows about each partition, without loading its rows.

| Query | Answered from |
|---|---|
| `SELECT count(*), count(col), sum(col), avg(col), min(col), max(col) FROM t` | the row count of each partition and the stats its file keeps |
| `SELECT DISTINCT day FROM t` on a table `PARTITION BY DAY`, and `min`, `max`, `count(DISTINCT ...)` of it | the list of partitions |

- **Saved stats:** the query has no `GROUP BY`, no math inside the aggregate, and a `WHERE` only on the time column (a comparison, `BETWEEN` or `time IN '...'`). A partition is answered from its stats when it has no unsaved changes and all its rows are inside the time range. The other partitions are read as usual: `k partitions scanned`. A plain `SELECT count(*) FROM t` also counts a partition with unsaved changes without reading it, when the changes are new rows: rows timed after (or before) every saved row of that partition, as a live feed writes them, or rows of a table without a key. A delete, or a change inside the saved time range, makes that partition read. A `sum` of `DOUBLE` values may differ in the last digit from reading every row.
- **Partition list:** the time value must be the same for every row of a partition, like a `DATE` column of a table with daily partitions.
- **Notes:**
  - Not on a table with [computed columns](create-table.md), not with a `symbol = ...` condition, and not with `first` or `last`.
  - Set `KARELADB_NO_PARTITION_ANSWERS=1` to turn off the partition list answers.

**Example: Count, lowest, highest and total volume of every daily candle: no row is read** (sample data: sample)

```sql
EXPLAIN SELECT count(*) AS candles, min(low) AS lowest, max(high) AS highest, sum(volume) AS volume FROM ochl_day;
SELECT count(*) AS candles, min(low) AS lowest, max(high) AS highest, sum(volume) AS volume FROM ochl_day;
```

Result:

`EXPLAIN SELECT count(*) AS candles, min(low) AS lowest, max(high) AS highest, sum(volume) AS volume `

| plan (STRING) |
|---|
| scan table ochl_day (2 of 2 partitions, about 57 rows) |
| answer from saved stats of table ochl_day: 2 of 2 partitions from the partition list and their files' stats (0 in memory, 0 partitions loaded, 2 file headers read); 0 partitions scanned |
| build 4 of 7 stored column(s) per row: time, high, low, volume |
| group by 0 key(s), 4 aggregate(s) |
| engine: column |

(5 rows)

`SELECT count(*) AS candles, min(low) AS lowest, max(high) AS highest, sum(volume) AS volume FROM och`

| candles (LONG) | lowest (DOUBLE) | highest (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|
| 57 | 167.3 | 546.2 | 5461390 |

(1 row)

**Example: The days of a table with daily partitions come from the partition list**

Setup:

```sql
CREATE TABLE fills (day DATE, symbol SYMBOL, qty LONG) TIMESERIES(day) PARTITION BY DAY;
INSERT INTO fills VALUES ('2026-09-08', 'CITY', 10), ('2026-09-09', 'CITY', 20), ('2026-09-09', 'VOLT', 5), ('2026-09-10', 'VOLT', 7);
```

```sql
EXPLAIN SELECT DISTINCT day FROM fills ORDER BY day;
SELECT DISTINCT day FROM fills ORDER BY day;
```

Result:

`EXPLAIN SELECT DISTINCT day FROM fills ORDER BY day`

| plan (STRING) |
|---|
| answer from the partition list of table fills (3 of 3 partitions; no other rows read) |
| sort by 1 key(s) |

(2 rows)

`SELECT DISTINCT day FROM fills ORDER BY day`

| day (DATE) |
|---|
| 2026-09-08 |
| 2026-09-09 |
| 2026-09-10 |

(3 rows)
