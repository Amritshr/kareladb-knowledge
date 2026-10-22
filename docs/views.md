# Views

> Save a query with a name, and select from it like a table.

- Category: Views
- Keywords: VIEW, VIEWS, CREATE VIEW, CACHED, CACHED VIEW, CREATE CACHED VIEW, REFRESH, REFRESH ON COMMIT, REFRESH VIEW, REFRESH MATERIALIZED VIEW, CREATE MATERIALIZED VIEW, DROP MATERIALIZED VIEW, REFRESH ON INSERT, SAMPLE BY view, REFRESH MATERIALIZED VIEW CONCURRENTLY, materialized\_views(), views(), candles from ticks, REFRESH IMMEDIATE, WITH BASE, continuous aggregate, incremental refresh, summary table, DROP VIEW, SHOW VIEWS, IF NOT EXISTS, IF EXISTS, saved query, virtual table, materialized view, CREATE OR REPLACE VIEW, OR REPLACE, ALTER VIEW, change a view, kept the old definition
- See also: [SELECT (from)](select.md#from), [UNION and subqueries (from-subquery)](union-subqueries.md#from-subquery), [SAMPLE BY (sample-by)](sample-by.md#sample-by), [EXPLAIN (explain)](explain.md#explain), [Users and roles](users-and-roles.md)

A **view** is a saved `SELECT` with a name. You use the name in `FROM` like a table. Every time you select from the view, KDB runs its query again, so the view always shows the newest rows.

- Use views for queries you type often: weekly candles, a broker report, the list of active app users.
- A view does not store rows (a [cached view](#cached-view) keeps its result). You cannot `INSERT`, `UPDATE` or `DELETE` through a view.
- A view and a table cannot have the same name.
- `CREATE VIEW`, `ALTER VIEW` and `DROP VIEW` need the `admin` role, and they cannot be used inside `BEGIN` ... `COMMIT`.

**Example: Weekly candles of a Sunday-to-Thursday trading week, as a view** (sample data: sample)

```sql
CREATE VIEW candles_1w AS
SELECT time, symbol,
       first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close,
       sum(volume) AS volume
FROM ochl_day
SAMPLE BY 1w WEEK START SUNDAY;

SELECT * FROM candles_1w WHERE symbol = 'VOLT' AND time >= '2026-08-30';
```

Result:

`CREATE VIEW candles_1w AS SELECT time, symbol, first(open) AS open, max(high) AS high, min(low) AS l`

```text
view 'candles_1w' created
```

`SELECT * FROM candles_1w WHERE symbol = 'VOLT' AND time >= '2026-08-30'`

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|---|
| 2026-08-30T00:00:00.000Z | VOLT | 172.5 | 177.3 | 167.3 | 176 | 368150 |
| 2026-09-06T00:00:00.000Z | VOLT | 174.2 | 192.1 | 172.4 | 191.2 | 486760 |

(2 rows)

<a id="create-view"></a>

## CREATE VIEW

Syntax:

```sql
CREATE [OR REPLACE] VIEW name AS SELECT ...
CREATE VIEW IF NOT EXISTS name AS SELECT ...
CREATE [OR REPLACE] VIEW name AS (SELECT ...)
```

Saves the query under `name`. The query can be any `SELECT`: joins, `WHERE`, `GROUP BY`, `SAMPLE BY`, `LATEST ON`, window functions, subqueries, `UNION ALL`, `ORDER BY` and `LIMIT`.

| Part | Meaning |
|---|---|
| `OR REPLACE` | when a view with this name is already there, it gets the **new** query. Otherwise the view is created. |
| `IF NOT EXISTS` | when a view with this name is already there, **nothing changes**: the old query stays, even if you sent a different one. No error. |
| `name` | the view name; like table names it does not care about upper or lower case |
| `AS SELECT ...` | the query. The QuestDB form with brackets, `AS (SELECT ...)`, also works |

- **Returns:** the message `view 'name' created`, `view 'name' replaced` (with `OR REPLACE`), or `view 'name' already exists; kept the old definition` (with `IF NOT EXISTS`). Over the PostgreSQL port the last one also comes as a NOTICE.
- **Notes:**
  - **To change a view, use `CREATE OR REPLACE VIEW` or [ALTER VIEW](#alter-view), not `IF NOT EXISTS`.** An app that runs `CREATE VIEW IF NOT EXISTS` at startup keeps the first query forever.
  - `OR REPLACE` and `IF NOT EXISTS` cannot be used together.
  - KDB checks the query when you create the view. A query with an error is refused: `the view's query does not work: ...`. A new query may not read the view it replaces.
  - The check reads **no rows**: every table is read as if it were empty, so a view over a table of any size is created at once and never stops at a memory limit. Unknown tables, columns and functions are found by the check. A problem that only the data shows (too many groups, too many rows to keep) comes when the view is read.
  - Give every computed column a name with `AS`. Otherwise the column is called by its expression, like `count(*)`.
  - A name used by a table is refused: `a table named '...' already exists`. `CREATE TABLE` with the name of a view is refused too.
  - Without `OR REPLACE` or `IF NOT EXISTS`, a name that is already a view is refused.
  - A view can use other views (at most 16 levels deep).
  - The query is saved as KDB wrote it back (see [SHOW VIEWS](views.md#show-views)), not with your spaces and line breaks.

**Example: A broker report: buy and sell amount per broker per day** (sample data: sample)

```sql
CREATE VIEW broker_daily AS
SELECT date, broker, round(sum(bought), 2) AS bought, round(sum(sold), 2) AS sold
FROM (
  SELECT date, buyer AS broker, amount AS bought, 0 AS sold FROM trade_log
  UNION ALL
  SELECT date, seller AS broker, 0 AS bought, amount AS sold FROM trade_log
) t
GROUP BY date, broker;

SELECT d.date, b.name, d.bought, d.sold
FROM broker_daily d JOIN brokers b ON b.id = d.broker
WHERE d.date IN '2026-09-10'
ORDER BY d.bought DESC;
```

Result:

`CREATE VIEW broker_daily AS SELECT date, broker, round(sum(bought), 2) AS bought, round(sum(sold), 2`

```text
view 'broker_daily' created
```

`SELECT d.date, b.name, d.bought, d.sold FROM broker_daily AS d JOIN brokers AS b ON b.id = d.broker `

| date (TIMESTAMP) | name (STRING) | bought (DOUBLE) | sold (DOUBLE) |
|---|---|---|---|
| 2026-09-10T00:00:00.000Z | Online Securities | 960370 | 213210 |
| 2026-09-10T00:00:00.000Z | Imperial Securities | 695950 | 592210 |
| 2026-09-10T00:00:00.000Z | Northgate Securities | 260190 | 501500 |
| 2026-09-10T00:00:00.000Z | Keystone Securities | 239420 | 486650 |
| 2026-09-10T00:00:00.000Z | Vision Securities | 205450 | 567810 |

(5 rows)

**Example: QuestDB style with brackets, and IF NOT EXISTS: the second query is not used** (sample data: sample)

```sql
CREATE VIEW IF NOT EXISTS banks AS (SELECT symbol, name FROM securities WHERE sector = 'Banking');
CREATE VIEW IF NOT EXISTS banks AS (SELECT symbol FROM securities);
SELECT * FROM banks;
```

Result:

`CREATE VIEW IF NOT EXISTS banks AS SELECT symbol, name FROM securities WHERE sector = 'Banking'`

```text
view 'banks' created
```

`CREATE VIEW IF NOT EXISTS banks AS SELECT symbol FROM securities`

```text
view 'banks' already exists; kept the old definition
```

`SELECT * FROM banks`

| symbol (SYMBOL) | name (STRING) |
|---|---|
| CITY | City Bank Limited |
| COAST | Coastal Bank Limited |

(2 rows)

**Example: CREATE OR REPLACE VIEW gives the view a new query** (sample data: sample)

Setup:

```sql
CREATE VIEW banks AS SELECT symbol FROM securities WHERE sector = 'Banking';
```

```sql
CREATE OR REPLACE VIEW banks AS SELECT symbol, name FROM securities WHERE sector = 'Banking';
SELECT * FROM banks;
```

Result:

`CREATE OR REPLACE VIEW banks AS SELECT symbol, name FROM securities WHERE sector = 'Banking'`

```text
view 'banks' replaced
```

`SELECT * FROM banks`

| symbol (SYMBOL) | name (STRING) |
|---|---|
| CITY | City Bank Limited |
| COAST | Coastal Bank Limited |

(2 rows)

**Example: Active users of an app**

Setup:

```sql
CREATE TABLE app_users (id LONG PRIMARY KEY, username STRING, plan STRING, last_login TIMESTAMP);
INSERT INTO app_users VALUES
  (1, 'sita', 'pro', '2026-09-10T14:05:00+05:45'),
  (2, 'ram', 'free', '2026-06-01T09:00:00+05:45'),
  (3, 'gita', 'pro', NULL);
```

```sql
CREATE VIEW active_users AS
SELECT id, username, plan, last_login FROM app_users
WHERE last_login >= '2026-08-01';

SELECT * FROM active_users;
```

Result:

`CREATE VIEW active_users AS SELECT id, username, plan, last_login FROM app_users WHERE last_login >=`

```text
view 'active_users' created
```

`SELECT * FROM active_users`

| id (LONG) | username (STRING) | plan (STRING) | last_login (TIMESTAMP) |
|---|---|---|---|
| 1 | sita | pro | 2026-09-10T08:20:00.000Z |

(1 row)

**Example: The query is checked when the view is made** (sample data: sample; shows an error)

```sql
CREATE VIEW bad_view AS SELECT symbol, clsoe FROM ochl_day;
```

Result:

Error: `the view's query does not work: line 1, column 40: unknown column 'clsoe' (table 'ochl_day' has: time symbol open high low close volume)`

**Example: A second view with the same name** (sample data: sample; shows an error)

Setup:

```sql
CREATE VIEW banks AS SELECT symbol FROM securities WHERE sector = 'Banking';
```

```sql
CREATE VIEW banks AS SELECT symbol, name FROM securities;
```

Result:

Error: `view 'banks' already exists; to change its query use CREATE OR REPLACE VIEW or ALTER VIEW banks AS ..., or DROP VIEW it first`

**Example: A table already has this name** (sample data: sample; shows an error)

```sql
CREATE VIEW brokers AS SELECT id, name FROM brokers WHERE id < 40;
```

Result:

Error: `a table named 'brokers' already exists`

<a id="alter-view"></a>

## ALTER VIEW

Syntax:

```sql
ALTER VIEW name AS SELECT ...
ALTER VIEW name AS (SELECT ...)
```

Gives a view that is already there a new query. It is the same as `CREATE OR REPLACE VIEW`, except that the view **must** exist, and a [cached view](#cached-view) stays cached (with its `REFRESH ON COMMIT`).

- **Returns:** `view 'name' altered` (a cached view adds `(N row(s) cached)`).
- **Notes:**
  - No such view: `view 'name' does not exist; ALTER VIEW changes a view that is there (use CREATE VIEW)`.
  - Only the `AS` form is supported: there is no `ALTER VIEW ... RENAME TO` or `OWNER TO`.

**Example: Add a column to a view** (sample data: sample)

Setup:

```sql
CREATE VIEW banks AS SELECT symbol FROM securities WHERE sector = 'Banking';
```

```sql
ALTER VIEW banks AS SELECT symbol, name FROM securities WHERE sector = 'Banking';
SELECT * FROM banks;
```

Result:

`ALTER VIEW banks AS SELECT symbol, name FROM securities WHERE sector = 'Banking'`

```text
view 'banks' altered
```

`SELECT * FROM banks`

| symbol (SYMBOL) | name (STRING) |
|---|---|
| CITY | City Bank Limited |
| COAST | Coastal Bank Limited |

(2 rows)

**Example: ALTER VIEW needs a view that exists** (sample data: sample; shows an error)

```sql
ALTER VIEW banks AS SELECT symbol FROM securities;
```

Result:

Error: `view 'banks' does not exist; ALTER VIEW changes a view that is there (use CREATE VIEW)`

<a id="select-from-view"></a>

## Selecting from a view

Syntax:

```sql
SELECT ... FROM view_name [alias] [JOIN ...] [WHERE ...] [SAMPLE BY ...] [GROUP BY ...] ...
```

A view name works in `FROM` and in joins, like a table. Its columns are the columns of the view's query.

- **Returns:** the rows of the view's query, then filtered, grouped and sorted by your query.
- **Notes:**
  - The view's query runs every time. Parts of your `WHERE` that are safe to move go **into** the view's query, so it reads fewer rows and partitions (see [WHERE on a view](#where-pushdown)). The rest is applied after the view's query.
  - When the view has a `TIMESTAMP` column, you can use `SAMPLE BY` and `LATEST ON` on the view.
  - When a table, column or other view that the view uses is dropped, the view stays, but selecting from it fails: `view 'name': ... does not exist`.
  - `SHOW COLUMNS FROM view` does not work (it is for tables). Use `SELECT * FROM view LIMIT 1`.
  - `INSERT`, `UPDATE` and `DELETE` on a view fail with `table '...' does not exist`.

**Example: New rows show up at once: the query runs every time** (sample data: sample)

Setup:

```sql
CREATE VIEW city_trades AS SELECT date, transaction_id, quantity, rate FROM trade_log WHERE symbol = 'CITY';
```

```sql
SELECT count(*) AS trades FROM city_trades;
INSERT INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate) VALUES ('2026-09-10', 100033, 'CITY', 58, 1, 30, 519.0);
SELECT count(*) AS trades FROM city_trades;
```

Result:

`SELECT count(*) AS trades FROM city_trades`

| trades (LONG) |
|---|
| 11 |

(1 row)

`INSERT INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate) VALUES ('2026-09`

```text
1 row(s) inserted
```

`SELECT count(*) AS trades FROM city_trades`

| trades (LONG) |
|---|
| 12 |

(1 row)

**Example: Monthly candles made from a view of CITY's daily closes** (sample data: sample)

Setup:

```sql
CREATE VIEW city_daily AS SELECT time, close FROM ochl_day WHERE symbol = 'CITY';
```

```sql
SELECT time, first(close) AS first_close, last(close) AS last_close FROM city_daily SAMPLE BY 1M;
```

Result:

| time (TIMESTAMP) | first_close (DOUBLE) | last_close (DOUBLE) |
|---|---|---|
| 2025-12-01T00:00:00.000Z | 542.2 | 542.4 |
| 2026-08-01T00:00:00.000Z | 507.9 | 505.7 |
| 2026-09-01T00:00:00.000Z | 502.4 | 504.9 |

(3 rows)

**Example: A WHERE on the view goes into the view's query** (sample data: sample)

Setup:

```sql
CREATE VIEW day_closes AS SELECT time, symbol, close FROM ochl_day;
```

```sql
SELECT time, symbol, close FROM day_closes WHERE symbol = 'CITY' AND time IN '2026-09-10';
EXPLAIN SELECT time, symbol, close FROM day_closes WHERE symbol = 'CITY' AND time IN '2026-09-10';
```

Result:

`SELECT time, symbol, close FROM day_closes WHERE symbol = 'CITY' AND time IN '2026-09-10'`

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 2026-09-10T00:00:00.000Z | CITY | 504.9 |

(1 row)

`EXPLAIN SELECT time, symbol, close FROM day_closes WHERE symbol = 'CITY' AND time IN '2026-09-10'`

| plan (STRING) |
|---|
| view day_closes passes its rows through: push 2 condition(s) into its query, which runs as the statement |
| scan table ochl_day (1 of 2 partitions, about 57 rows) |
| read only 1 key range(s) of each partition |
| build 3 of 7 stored column(s) per row: time, symbol, close |
| filter while scanning: 2 condition(s) |
| engine: column |

(6 rows)

<a id="where-pushdown"></a>

### WHERE on a view

A condition of your `WHERE` also runs **inside** the view (or a `FROM (SELECT ...)` subquery) when that cannot change the result. Then the view builds only the rows you asked for: a weekly candle view filtered to one symbol builds that symbol's weeks, not every symbol's. `EXPLAIN` shows it as `push N condition(s) into view name`.

| A condition on a view column is moved in when the column is | Example |
|---|---|
| a plain column of the view | `SELECT time, symbol, close FROM ochl_day` |
| a `GROUP BY` or `SAMPLE BY` key (not the time column) | `symbol` in `SELECT time, symbol, sum(volume) ... SAMPLE BY 1w` |
| in `PARTITION BY` of every window function | `symbol` in `lag(close) OVER (PARTITION BY symbol ORDER BY time)` |
| a `LATEST ON ... PARTITION BY` column | `symbol` in `LATEST ON time PARTITION BY symbol` |

It stays outside (the view runs in full first) when:

- the condition uses an aggregate result (`volume > 1000` on `sum(volume) AS volume`), a function, a subquery or the `SAMPLE BY` time column;
- the view has `LIMIT`, `FILL`, `ALIGN TO FIRST OBSERVATION`, `DISTINCT ON`, `UNION` or `WITH`, or a window function without that column in `PARTITION BY`.

**Joins.** A view whose query joins views or subqueries takes a condition on one of its plain columns too (`d.time AS time`), and passes it on to the views it joins. In a query with a join, each view or subquery takes the conditions on its own columns (`WHERE d.time = '2026-10-15'` goes into `d`), and an `ON d.time = t.time` carries a condition on `d.time` over to `t`, as `t.time = '2026-10-15'`. So a join of two daily views read for one day builds one day of each, not every day. This is done for `JOIN`, `LEFT JOIN` and `CROSS JOIN` without `USING`. The right side of a `LEFT JOIN` takes only the carried conditions: a test like `b.n IS NULL` is true on the rows the join fills with NULL, so it stays outside.

A condition on a plain column of a **window** query that cannot move in front of the windows (`time = ...` when the windows are `PARTITION BY symbol`) still runs inside it, right **after** the window values are worked out: `lag()` still sees the rows before, but only the rows you keep are made. `EXPLAIN` shows it as `push N condition(s) into subquery name after its windows`. This happens when every column of the window query is a plain column, or a `row_number`, `rank`, `dense_rank`, `lag`, `lead`, `first_value` or `last_value` of a column (`lag` without a default value).

**lag() and a time range.** When every window function of the view is `lag(x)` or `lag(x, 1)`, all over the same `PARTITION BY` and `ORDER BY time`, and your `WHERE` gives the time a lower end (`time = '2026-10-15'`, `time >= ...`, `time > ...`, `BETWEEN`), the window gets only the rows of that range and, for each partition, its last row before the range. Those rows are read first: the range's rows, then for each of their partitions its last time before the range (`max(time)`, over the 8 days before it, the 16 before those, and so on, the last few partitions looked for by their key values alone), then the rows at those times, a few days per read, each read narrowed to the keys that end there (since 2026-10-17). The day's `lag()` values are the same as over all rows, and what the window holds does not grow with the table: on 2 years of trades a day of a broker-by-symbol view took 0.4 s instead of 2.2 s and about 1 GB. `EXPLAIN` says `the rows of view v's windows read first: the time range and each partition's last row before it, for lag (N rows)`. `KDB_NO_LAG_ROWS=1` reads every row of those days instead.

A condition like `rn <= 5` (also `rn < 6`, `rn = 1`, `5 >= rn`) on a `row_number`, `rank` or `dense_rank` column is a **rank limit**: the window query drops every row above the limit as soon as the ranks are known. With `row_number()` it also orders only the first 5 rows of each partition instead of all of them. The usual top-N-per-group query gets fast this way: `SELECT symbol, sum(qty) FROM (SELECT symbol, qty, ROW_NUMBER() OVER (PARTITION BY symbol ORDER BY qty DESC) AS rn FROM t WHERE ...) WHERE rn <= 5 GROUP BY symbol`. `EXPLAIN` shows it as `push 1 rank limit(s) into subquery`.

**A view joined to a table, then grouped** (since 2026-10-17). A `GROUP BY` over a view (or subquery) joined to a table, such as the turnover per broker and sector of a daily view joined to a sector map, groups the view first by the columns the rest of the query reads of it (its `GROUP BY`, `ON` and `WHERE` columns), and joins those groups: `SELECT d.broker, s.sector, sum(d.amt) FROM daily d JOIN sector s ON d.symbol = s.symbol GROUP BY d.broker, s.sector` adds up the view per broker and symbol, which a grouped view folds into its own grouping, so a year of the daily view is never built. Only `sum`, `min` and `max` of the view's own columns, every column written with its source's name (`d.amt`), an `INNER` or `LEFT JOIN` of two sources. A year of 006's broker-sector read: 9.3 s and 2.6 GB -> 0.37 s. `EXPLAIN` says `aggregates over a joined view: the view grouped first`. `KDB_NO_GROUP_BELOW_JOIN=1` turns it off.

**Only the sums you read.** When a view or `FROM (SELECT ...)` subquery has `GROUP BY`, a `sum`, `count` or `avg` column of it that your query never names is not worked out at all. A daily view with six sums, read for two of them, adds up two: less time, and less memory for the groups.

The result is always the same as without moving; only the time changes.

**A long time range in parts** (since 2026-10-16). A `GROUP BY` over a view (or a `FROM (SELECT ...)` subquery) for many days, such as a year of a window view summed per symbol, runs the view **a few days at a time** when the time column passes through every step of the view: it is a key of every `GROUP BY`, in the `PARTITION BY` of every window, and comes from the time column of a time-series table partitioned by time. Each part is the view with `time >= a AND time < b` moved inside as above, and its rows go straight into your `GROUP BY`; no window partition and no group can reach across two parts, so the answer is the same. A part holds whole partitions, as many as keep it well under `--max-result-memory` (about 8 KB of memory per row for a view with windows or joins, 512 bytes without); a partition bigger than that (a month of a materialized view) is cut into parts of whole days. A view that joins (since 2026-10-17) is split too when the time is a column of one of its sources (`d.time AS time`) and reaches each other source through an `ON d.time = t.time`, or that source is a small table without a time column (a sector map); after its first part such a view's parts are sized by what that part held. So a range far bigger than the memory limit is answered: 006's pump-and-dump filter over 5 months of 10M trades took 18 s where it stopped at `max_result_memory` before, and its OTM filter (the daily filter joined with a sum of itself) over a year 4.4 s where it ran out of memory. With 2 or more CPUs, two parts run at the same time (since 2026-10-17): the next part is worked out while this one runs or hands its rows on, and the rows still go on in time order, so the answer is the same to the last digit. At 2 CPUs a year of 006's OTM filter over materialized views took 2.0 s instead of 4.3 s, and two years of its Mkt hit view 32 s instead of 63 s. `KDB_NO_SPLIT_LANES=1` runs one part at a time. A range that fits in one part runs as before. `KDB_NO_TIME_SPLIT=1` turns it off.

**Example: Weekly candles of one symbol: only CITY's weeks are built** (sample data: sample)

Setup:

```sql
CREATE VIEW weekly AS SELECT time, symbol, first(open) AS open, last(close) AS close, sum(volume) AS volume
FROM ochl_day SAMPLE BY 1w;
```

```sql
SELECT * FROM weekly WHERE symbol = 'CITY';
EXPLAIN SELECT * FROM weekly WHERE symbol = 'CITY';
```

Result:

`SELECT * FROM weekly WHERE symbol = 'CITY'`

| time (TIMESTAMP) | symbol (SYMBOL) | open (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|
| 2025-12-22T00:00:00.000Z | CITY | 540.3 | 542.2 | 85290 |
| 2025-12-29T00:00:00.000Z | CITY | 540.6 | 542.4 | 169800 |
| 2026-08-17T00:00:00.000Z | CITY | 505 | 507.9 | 125050 |
| 2026-08-24T00:00:00.000Z | CITY | 508.3 | 503.1 | 571260 |
| 2026-08-31T00:00:00.000Z | CITY | 502.5 | 499 | 518540 |
| 2026-09-07T00:00:00.000Z | CITY | 497.3 | 504.9 | 516910 |

(6 rows)

`EXPLAIN SELECT * FROM weekly WHERE symbol = 'CITY'`

| plan (STRING) |
|---|
| view weekly passes its rows through: push 1 condition(s) into its query, which runs as the statement |
| scan table ochl_day (2 of 2 partitions, about 57 rows) |
| read only 1 key range(s) of each partition |
| build 5 of 7 stored column(s) per row: time, symbol, open, close, volume |
| filter while scanning: 1 condition(s) |
| sample by SAMPLE BY 1w |
| group by 1 key(s), 3 aggregate(s) |
| engine: column |

(8 rows)

**Example: A condition on an aggregate stays outside** (sample data: sample)

Setup:

```sql
CREATE VIEW weekly_volume AS SELECT time, symbol, sum(volume) AS volume FROM ochl_day SAMPLE BY 1w;
```

```sql
EXPLAIN SELECT * FROM weekly_volume WHERE volume > 1000;
```

Result:

| plan (STRING) |
|---|
| scan result of weekly_volume (18 rows) |
| filter while scanning: 1 condition(s) |
| engine: row (reads a subquery or view result) |

(3 rows)

**Example: Day change % of every symbol: lag() sees the day before, only one day of rows is made** (sample data: sample)

```sql
SELECT symbol, close, prev, round((close - prev) / prev * 100, 2) AS change_pct
FROM (SELECT symbol, time, close, lag(close) OVER (PARTITION BY symbol ORDER BY time) AS prev
      FROM ochl_day WHERE time >= '2026-09-01') d
WHERE time IN '2026-09-10'
ORDER BY symbol;
EXPLAIN SELECT symbol, close, prev FROM (SELECT symbol, time, close, lag(close) OVER (PARTITION BY symbol ORDER BY time) AS prev FROM ochl_day WHERE time >= '2026-09-01') d WHERE time IN '2026-09-10';
```

Result:

`SELECT symbol, close, prev, round((close - prev) / prev * 100, 2) AS change_pct FROM (SELECT symbol,`

| symbol (SYMBOL) | close (DOUBLE) | prev (DOUBLE) | change_pct (DOUBLE) |
|---|---|---|---|
| CITY | 504.9 | 504.6 | 0.06 |
| COAST | 376.1 | 380.1 | -1.05 |
| VOLT | 191.2 | 187.3 | 2.08 |

(3 rows)

`EXPLAIN SELECT symbol, close, prev FROM (SELECT symbol, time, close, lag(close) OVER (PARTITION BY s`

| plan (STRING) |
|---|
| scan result of d (3 rows) |
| push 1 condition(s) into subquery d after its windows |
| filter while scanning: 1 condition(s) |
| engine: row (reads a subquery or view result) |

(4 rows)

**Example: Latest live price per symbol, from a view** (sample data: sample)

Setup:

```sql
CREATE VIEW live_today AS SELECT timestamp, symbol, ltp, pct_change FROM live_data WHERE timestamp IN '2026-09-10';
```

```sql
SELECT symbol, ltp, pct_change FROM live_today LATEST ON timestamp PARTITION BY symbol ORDER BY pct_change DESC;
```

Result:

| symbol (SYMBOL) | ltp (DOUBLE) | pct_change (DOUBLE) |
|---|---|---|
| CITY | 527.1 | 2.71 |
| TELCO | 897.7 | 1.9 |
| COAST | 401.9 | 0.7 |
| VOLT | 184 | -0.86 |

(4 rows)

**Example: The table under a view was dropped** (shows an error)

Setup:

```sql
CREATE TABLE watchlist (symbol STRING PRIMARY KEY, note STRING);
CREATE VIEW my_watchlist AS SELECT symbol, note FROM watchlist;
DROP TABLE watchlist;
```

```sql
SELECT * FROM my_watchlist;
```

Result:

Error: `view 'my_watchlist': line 1, column 26: table or view 'watchlist' does not exist`

**Example: A view cannot be changed with INSERT** (sample data: sample; shows an error)

Setup:

```sql
CREATE VIEW banks AS SELECT symbol, name FROM securities WHERE sector = 'Banking';
```

```sql
INSERT INTO banks VALUES ('HARBOR', 'Harbor Bank Limited');
```

Result:

Error: `table 'banks' does not exist`

<a id="cached-view"></a>

## CREATE CACHED VIEW

Syntax:

```sql
CREATE [OR REPLACE] CACHED VIEW name AS SELECT ... [REFRESH ON COMMIT]
CREATE CACHED VIEW IF NOT EXISTS name AS SELECT ... [REFRESH ON COMMIT]
CREATE [OR REPLACE] CACHED VIEW name AS (SELECT ...) [REFRESH ON COMMIT]
```

`OR REPLACE` and `IF NOT EXISTS` work as for [CREATE VIEW](#create-view). A replaced cached view computes its rows again at once.

A cached (materialized) view runs its query once and **keeps the rows**. Selecting from it reads the kept rows, so a slow `GROUP BY` over a big table is paid once, not on every read.

| Form | When the rows are made new |
|---|---|
| `CREATE CACHED VIEW ...` | at `CREATE`, and when you run [REFRESH VIEW](#refresh-view) |
| `CREATE CACHED VIEW ... REFRESH ON COMMIT` | at the first read after a commit changed a table the view reads: `INSERT`, `UPDATE`, `DELETE`, `POST /write`, `POST /imp`, and rows written by triggers |

- **Returns:** `view 'name' created (N row(s) cached)`.
- **Notes:**
  - The kept rows live in memory. After a restart they are made again at the first read.
  - A `WHERE` on the view filters the kept rows; it does not run the view's query again.
  - `REFRESH ON COMMIT` is only allowed with `CACHED`. On a normal view it is an error.
  - `SHOW VIEWS` lists a cached view with kind `materialized`, and `ON COMMIT` in `refresh` when it has `REFRESH ON COMMIT`.
  - A view whose query fails (a table was dropped) gives the same error as a normal view.

**Example: Trades per symbol as a cached view** (sample data: sample)

```sql
CREATE CACHED VIEW trades_per_symbol AS
SELECT symbol, count(*) AS trades, sum(quantity) AS shares FROM trade_log GROUP BY symbol
REFRESH ON COMMIT;

SELECT * FROM trades_per_symbol ORDER BY trades DESC, symbol;
```

Result:

`CREATE CACHED VIEW trades_per_symbol AS SELECT symbol, count(*) AS trades, sum(quantity) AS shares F`

```text
view 'trades_per_symbol' created (4 row(s) cached)
```

`SELECT * FROM trades_per_symbol ORDER BY trades DESC, symbol`

| symbol (SYMBOL) | trades (LONG) | shares (LONG) |
|---|---|---|
| CITY | 11 | 2420 |
| COAST | 11 | 3070 |
| TELCO | 6 | 2770 |
| VOLT | 4 | 400 |

(4 rows)

**Example: Without REFRESH ON COMMIT the rows stay until REFRESH VIEW** (sample data: sample)

Setup:

```sql
CREATE CACHED VIEW city_trade_count AS SELECT count(*) AS trades FROM trade_log WHERE symbol = 'CITY';
```

```sql
SELECT trades FROM city_trade_count;
INSERT INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate) VALUES ('2026-09-10', 100034, 'CITY', 58, 1, 30, 519.0);
SELECT trades FROM city_trade_count;
REFRESH VIEW city_trade_count;
SELECT trades FROM city_trade_count;
```

Result:

`SELECT trades FROM city_trade_count`

| trades (LONG) |
|---|
| 11 |

(1 row)

`INSERT INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate) VALUES ('2026-09`

```text
1 row(s) inserted
```

`SELECT trades FROM city_trade_count`

| trades (LONG) |
|---|
| 11 |

(1 row)

`REFRESH VIEW city_trade_count`

```text
view 'city_trade_count' refreshed: 1 row(s)
```

`SELECT trades FROM city_trade_count`

| trades (LONG) |
|---|
| 12 |

(1 row)

**Example: With REFRESH ON COMMIT a new trade shows at the next read** (sample data: sample)

Setup:

```sql
CREATE CACHED VIEW city_trade_live AS SELECT count(*) AS trades FROM trade_log WHERE symbol = 'CITY' REFRESH ON COMMIT;
```

```sql
SELECT trades FROM city_trade_live;
INSERT INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate) VALUES ('2026-09-10', 100035, 'CITY', 58, 1, 30, 519.0);
SELECT trades FROM city_trade_live;
```

Result:

`SELECT trades FROM city_trade_live`

| trades (LONG) |
|---|
| 11 |

(1 row)

`INSERT INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate) VALUES ('2026-09`

```text
1 row(s) inserted
```

`SELECT trades FROM city_trade_live`

| trades (LONG) |
|---|
| 12 |

(1 row)

**Example: REFRESH ON COMMIT needs CACHED** (sample data: sample; shows an error)

```sql
CREATE VIEW trades_per_symbol AS
SELECT symbol, count(*) AS trades FROM trade_log GROUP BY symbol
REFRESH ON COMMIT;
```

Result:

Error: `line 3, column 1: REFRESH ON COMMIT is only for cached views; expected CREATE CACHED VIEW trades_per_symbol AS ...`

<a id="materialized-view"></a>

## CREATE MATERIALIZED VIEW

Syntax:

```sql
CREATE MATERIALIZED VIEW [IF NOT EXISTS] name
    [PARTITION BY DAY | MONTH | YEAR] [TTL n DAYS | ...] [REFRESH ON INSERT | REFRESH IMMEDIATE] [WITH BASE table]
    [INCREMENTAL] [KEY (column)] [LOOKBACK 'time span']
    AS SELECT time_bucket, ..., aggregates [, window calls] FROM table [WHERE ...] GROUP BY time_bucket, ... [HAVING ...]
CREATE MATERIALIZED VIEW name [KEY (column)] [LOOKBACK 'time span']
    AS SELECT time, ..., window calls FROM table [WHERE ...]
CREATE MATERIALIZED VIEW [IF NOT EXISTS] name [options]
    AS ( SELECT time, ..., aggregates FROM table [WHERE ...] SAMPLE BY interval [ALIGN TO CALENDAR ...] )
    [TIMESTAMP(time)] [PARTITION BY DAY | MONTH | YEAR] [TTL n DAYS | ...]
REFRESH MATERIALIZED VIEW [CONCURRENTLY] name [WITH DATA]
REFRESH MATERIALIZED VIEW name FULL | INCREMENTAL | RANGE FROM 'time' TO 'time' | FOR 'time' [TO 'time']
DROP MATERIALIZED VIEW [IF EXISTS] name
```

A materialized view is a **real table** that holds the result of a `GROUP BY` or `SAMPLE BY` query. Reading it is a plain table read: fast, and a `WHERE` on its time column skips partitions. The second form is QuestDB's: candles from ticks.

It stays up to date by itself. After each commit that changes rows of its table, a background thread computes again **only the time buckets those rows fall in** and writes only the view rows that changed. A tick at 10:04:31 makes a `SAMPLE BY 1m` view compute the 10:04 minute again, not the day. The commit does not wait for it, and readers and writers of other tables go on while it runs. Writers of the view's own table wait only while the new rows are computed, not while they are written into the view. Changes are applied in commit order. A **read of the view waits** until the view holds every commit made before the read (at most 2 seconds, usually a few milliseconds), so a candle read right after a tick includes that tick. Inside an open transaction the read takes the rows the view has.

| Part | Meaning |
|---|---|
| `PARTITION BY` | the view's own partitions. Default: the table's partitioning, or coarser when the time bucket needs it. With `SAMPLE BY`, QuestDB's rule: under an hour `DAY`, under a day `MONTH`, else `YEAR`. `HOUR` and `WEEK` are not supported |
| `TTL` | drop old partitions of the view (see [SET TTL](alter-table.md#set-ttl)) |
| `REFRESH ON INSERT`, `REFRESH IMMEDIATE` | optional; every materialized view is refreshed after inserts, updates and deletes. `REFRESH MANUAL`, `EVERY` and `PERIOD` are not supported |
| `WITH BASE table` | QuestDB: the table the view is refreshed from. It must be the table the query reads |
| `TIMESTAMP(time)` | QuestDB: the view's time column. It must be the time bucket |
| time bucket | with `GROUP BY`: the table's time column, `to_date(time)`, or `date_trunc('year' \| 'quarter' \| 'month' \| 'day' \| 'hour' \| 'minute' \| 'second', time)`. With `SAMPLE BY`: the table's time column in `SELECT`, which holds the start of each bucket |

| Refresh | What it does |
|---|---|
| `REFRESH MATERIALIZED VIEW v`, `... FULL` | drops every row of the view and writes them all again (a view too big for that: part by part, see the notes) |
| `... CONCURRENTLY v` | computes every row, compares, and writes only the rows that differ. Readers keep reading the old rows until it commits (a view too big for that: part by part) |
| `... INCREMENTAL` | now, what the background thread would do next: the buckets that changes of the table made stale |
| `... RANGE FROM 'a' TO 'b'` | the buckets that hold the times `a` to `b`, by difference |
| `... FOR 'a' [TO 'b']` | the view partitions that hold `a` to `b`, by difference |

- **Returns:** `materialized view 'name' created with N row(s), PARTITION BY DAY`.
- **Notes:**
  - The query must read **one** time-series table and `GROUP BY` a time bucket (or, with window calls, show the table's rows with their time column). The bucket must also be a column of the view.
  - **The key.** A view that groups by a `SYMBOL` column of its table (and shows it) has a key: a change marks its time bucket for that symbol only, and the refresh computes only those symbols there. `KEY (column)` names the key yourself (one of the columns the view groups by). `INCREMENTAL` may be written; every materialized view is incremental.
  - **Moving windows.** A view may use window calls that look back a fixed distance: `lag(x, n)`, `sma(x, n)`, `pct_change(x, n)`, or an aggregate over `ROWS BETWEEN n PRECEDING AND CURRENT ROW` or `RANGE '5 days' PRECEDING`. Every window must `PARTITION BY` the same column (the key) or none, and `ORDER BY` the view's time. A change at time t then computes its key again **from t to the end**, reading first the rows the windows look back over (the n earlier rows of that key, wherever they are, so weekends and holidays never cut a window short). `LOOKBACK '120 days'` makes it read at least that much more history. Refused, saying why: `ema`, `rsi`, `atr`, `cumsum` and ranks (they depend on every earlier row), `lead` and `FOLLOWING` (later rows), and a window without a frame (it reads every earlier row).
  - Refused, with a message that says why: joins, subqueries, `WITH`, `UNION`, `LATEST ON`, `DISTINCT`, `ORDER BY`, `LIMIT`, window calls other than those above, `now()` and `random()`, `date_trunc('week', ...)` (a week can cross a month end), and `SAMPLE BY` with `FILL` or `ALIGN TO FIRST OBSERVATION` (a bucket would depend on the buckets around it).
  - The time bucket is always on the **UTC** clock: a `'day'` bucket is a UTC day, even after `SET TIME ZONE` or with `kdb serve --timezone`. The view is rebuilt one UTC partition at a time, and a Nepal day (18:15 UTC to 18:15 UTC) would span two.
  - `INSERT`, `UPDATE`, `DELETE` and `TRUNCATE` on the view are refused. Change the table instead.
  - `DROP PARTITION` and `TTL` on the **table** do not remove rows from the view. A daily summary can outlive the raw trades. `TRUNCATE` of the table empties the view.
  - The table cannot be dropped or renamed while a view reads it.
  - How far behind a view is shows in `GET /api/stats` under `materialized_views` (`lag_ms`, `pending_ranges`, `pending_partitions`, `last_error`), and in `SELECT * FROM materialized_views()`: `refresh_base_table_txn = base_table_txn` once the view holds every commit of its table.
  - An insert, an `UPDATE` and a `DELETE` mark only the buckets of the rows they change (an `UPDATE` that changes a row's time marks its old and its new bucket). A delete that comes from a foreign key action marks the whole partition it touches; the refresh then compares that partition and still writes only what differs.
  - A refresh locks the view and its table like an `INSERT`. With `kdb serve --snapshot-reads on`, readers of the view read its rows before the refresh and do not wait.
  - **A bulk load is refreshed once it pauses.** While a table takes a stream of big writes (100,000 rows or more within a second, as `POST /write` with 100k-row bodies from several senders), its views are not refreshed between the requests: each refresh would hold the table for its query, which the loaders then wait for, and compute days the next requests change again. The views catch up in one refresh once no write request is running and none came for 0.3 s, at once when a query reads the view (it waits for that refresh as always), and at the latest 2 minutes after the oldest change. Single rows and small batches are refreshed right away, as before.
  - `SHOW CREATE TABLE name` gives the `CREATE MATERIALIZED VIEW` statement. `SHOW VIEWS` lists it with kind `materialized` and refresh `ON INSERT`.
  - A restart or a power cut never loses a refresh: what was waiting is refreshed after the database opens.
  - `materialized_views()` lists the materialized views with QuestDB's columns (`view_name`, `refresh_type`, `base_table_name`, `view_status`, ...) and KDB's own after them: `rows`, `disk_bytes`, `last_refresh_took_ms`, `refreshes` (since the database opened), `pending_ranges`, `pending_partitions`, `full_refresh_pending` and `lag_ms`. `views()` lists the plain views. To build a view again from nothing: `REFRESH MATERIALIZED VIEW name FULL`.
  - **A view too big to rebuild in one piece** (`FULL`, `CONCURRENTLY`, or the full rebuild after a restart) is rebuilt **part by part**: a few partitions of the table at a time, each part by difference and committed on its own, so the rebuild holds one part in memory, whatever the size of the table. That happens when the view has more rows than one query may make groups (`max_groups`) or keep (`max_result_memory`), or when the one-piece rebuild is stopped by the memory limit. Then the message ends in `, N written`, and while it runs a reader may see some parts rebuilt and others not yet (each part whole). A view that fits is rebuilt in one piece, as before: a reader sees all the old rows or all the new ones.
  - **A `REFRESH` that fails leaves the view as it was**: its rows stay, `view_status` stays `valid`, and only the statement gets the error. `invalid` (with `invalidation_reason`) means the background refresh that keeps the view up to date failed; it is tried again.

**Example: Daily turnover per symbol, kept up to date** (sample data: sample)

```sql
CREATE MATERIALIZED VIEW daily_symbol AS
SELECT date, symbol, count(*) AS trades, sum(quantity) AS shares, round(sum(amount), 2) AS turnover
FROM trade_log
GROUP BY date, symbol;

SELECT * FROM daily_symbol WHERE date IN '2026-09-10' ORDER BY turnover DESC LIMIT 3;
```

Result:

`CREATE MATERIALIZED VIEW daily_symbol REFRESH ON INSERT AS SELECT date, symbol, count(*) AS trades, `

```text
materialized view 'daily_symbol' created with 7 row(s), PARTITION BY DAY
```

`SELECT * FROM daily_symbol WHERE date IN '2026-09-10' ORDER BY turnover DESC LIMIT 3`

| date (TIMESTAMP) | symbol (SYMBOL) | trades (LONG) | shares (LONG) | turnover (DOUBLE) |
|---|---|---|---|---|
| 2026-09-10T00:00:00.000Z | COAST | 9 | 2850 | 1139340 |
| 2026-09-10T00:00:00.000Z | TELCO | 4 | 770 | 678260 |
| 2026-09-10T00:00:00.000Z | CITY | 7 | 910 | 469830 |

(3 rows)

**Example: A broker summary per month; a new trade shows after the refresh** (sample data: sample)

Setup:

```sql
CREATE MATERIALIZED VIEW broker_month AS
SELECT date_trunc('month', date) AS month, buyer AS broker, sum(quantity) AS bought
FROM trade_log GROUP BY month, broker;
```

```sql
INSERT INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate) VALUES ('2026-09-10', 100036, 'CITY', 58, 1, 1000, 519.0);
REFRESH MATERIALIZED VIEW broker_month FOR '2026-09-10';
SELECT month, broker, bought FROM broker_month WHERE broker = 58;
SHOW CREATE TABLE broker_month;
```

Result:

`INSERT INTO trade_log (date, transaction_id, symbol, buyer, seller, quantity, rate) VALUES ('2026-09`

```text
1 row(s) inserted
```

`REFRESH MATERIALIZED VIEW broker_month FOR '2026-09-10'`

```text
materialized view 'broker_month' refreshed: 5 row(s) from 2026-09-01T00:00:00.000Z to 2026-10-01T00:00:00.000Z, 2 written
```

`SELECT month, broker, bought FROM broker_month WHERE broker = 58`

| month (TIMESTAMP) | broker (INT) | bought (LONG) |
|---|---|---|
| 2026-09-01T00:00:00.000Z | 58 | 2960 |

(1 row)

`SHOW CREATE TABLE broker_month`

| create_sql (STRING) |
|---|
| CREATE MATERIALIZED VIEW broker_month PARTITION BY MONTH REFRESH ON INSERT AS SELECT date_trunc('month', date) AS month, buyer AS broker, sum(quantity) AS bought FROM trade_log GROUP BY month, broker |

(1 row)

**Example: One-minute candles from ticks (QuestDB form)** (sample data: sample)

Setup:

```sql
CREATE MATERIALIZED VIEW live_1m AS (
  SELECT timestamp, symbol, first(ltp) AS o, max(ltp) AS h, min(ltp) AS l, last(ltp) AS c, sum(ltv) AS v
  FROM live_data SAMPLE BY 1m
) PARTITION BY DAY;
```

```sql
INSERT INTO live_data (timestamp, symbol, ltp, ltv) VALUES ('2026-09-10T11:05:30+05:45', 'CITY', 514.5, 30);
REFRESH MATERIALIZED VIEW live_1m INCREMENTAL;
SELECT * FROM live_1m WHERE symbol = 'CITY' ORDER BY timestamp;
```

Result:

`INSERT INTO live_data (timestamp, symbol, ltp, ltv) VALUES ('2026-09-10T11:05:30+05:45', 'CITY', 514`

```text
1 row(s) inserted
```

`REFRESH MATERIALIZED VIEW live_1m INCREMENTAL`

```text
materialized view 'live_1m' refreshed incrementally: 2 row(s) changed
```

`SELECT * FROM live_1m WHERE symbol = 'CITY' ORDER BY timestamp`

| timestamp (TIMESTAMP) | symbol (SYMBOL) | o (DOUBLE) | h (DOUBLE) | l (DOUBLE) | c (DOUBLE) | v (LONG) |
|---|---|---|---|---|---|---|
| 2026-09-10T05:20:00.000Z | CITY | 513 | 514.5 | 513 | 514.5 | 80 |
| 2026-09-10T07:15:00.000Z | CITY | 515.6 | 515.6 | 515.6 | 515.6 | 20 |
| 2026-09-10T09:14:00.000Z | CITY | 527.1 | 527.1 | 527.1 | 527.1 | 20 |

(3 rows)

**Example: Materialized views and plain views in the catalog** (sample data: sample)

Setup:

```sql
CREATE MATERIALIZED VIEW live_1h AS (SELECT timestamp, symbol, last(ltp) AS c FROM live_data SAMPLE BY 1h);
CREATE VIEW city_live AS SELECT * FROM live_data WHERE symbol = 'CITY';
```

```sql
SELECT view_name, refresh_type, base_table_name, view_status FROM materialized_views();
SELECT view_name, view_status FROM views();
```

Result:

`SELECT view_name, refresh_type, base_table_name, view_status FROM materialized_views()`

| view_name (STRING) | refresh_type (STRING) | base_table_name (STRING) | view_status (STRING) |
|---|---|---|---|
| live_1h | immediate | live_data | valid |

(1 row)

`SELECT view_name, view_status FROM views()`

| view_name (STRING) | view_status (STRING) |
|---|---|
| city_live | valid |

(1 row)

**Example: Moving averages kept up to date: a corrected close recomputes that symbol from that day on** (sample data: sample)

Setup:

```sql
CREATE TABLE closes (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time) PARTITION BY MONTH;
INSERT INTO closes VALUES ('2026-09-01', 'NABIL', 500), ('2026-09-02', 'NABIL', 510), ('2026-09-03', 'NABIL', 505),
  ('2026-09-04', 'NABIL', 520), ('2026-09-07', 'NABIL', 530), ('2026-09-01', 'HDL', 900), ('2026-09-02', 'HDL', 910);
CREATE MATERIALIZED VIEW close_ma KEY (symbol) AS
  SELECT time, symbol, close,
         avg(close) OVER (PARTITION BY symbol ORDER BY time ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma3,
         lag(close, 1) OVER (PARTITION BY symbol ORDER BY time) AS prev
  FROM closes;
UPDATE closes SET close = 515 WHERE symbol = 'NABIL' AND time = '2026-09-03';
REFRESH MATERIALIZED VIEW close_ma INCREMENTAL;
```

```sql
SELECT * FROM close_ma WHERE symbol = 'NABIL' ORDER BY time;
```

Result:

| time (TIMESTAMP) | symbol (SYMBOL) | close (DOUBLE) | ma3 (DOUBLE) | prev (DOUBLE) |
|---|---|---|---|---|
| 2026-09-01T00:00:00.000Z | NABIL | 500 | 500 | NULL |
| 2026-09-02T00:00:00.000Z | NABIL | 510 | 505 | 500 |
| 2026-09-03T00:00:00.000Z | NABIL | 515 | 508.333333333333 | 510 |
| 2026-09-04T00:00:00.000Z | NABIL | 520 | 515 | 515 |
| 2026-09-07T00:00:00.000Z | NABIL | 530 | 521.666666666667 | 520 |

(5 rows)

**Example: Rebuild while readers keep reading (PostgreSQL)** (sample data: sample)

Setup:

```sql
CREATE MATERIALIZED VIEW live_5m AS (SELECT timestamp, symbol, sum(ltv) AS v FROM live_data SAMPLE BY 5m);
```

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY live_5m;
REFRESH MATERIALIZED VIEW live_5m FULL;
```

Result:

`REFRESH MATERIALIZED VIEW CONCURRENTLY live_5m`

```text
materialized view 'live_5m' refreshed: 12 row(s), 0 written
```

`REFRESH MATERIALIZED VIEW live_5m FULL`

```text
materialized view 'live_5m' refreshed: 12 row(s)
```

**Example: FILL cannot be kept bucket by bucket** (sample data: sample; shows an error)

```sql
CREATE MATERIALIZED VIEW gaps AS (SELECT timestamp, last(ltp) AS c FROM live_data SAMPLE BY 1m FILL(PREV));
```

Result:

Error: `materialized view 'gaps' cannot be refreshed partition by partition: SAMPLE BY with FILL is not supported (a filled bucket depends on the buckets around it); use FILL in a query of the view`

**Example: A view needs a time bucket in GROUP BY** (sample data: sample; shows an error)

```sql
CREATE MATERIALIZED VIEW per_symbol AS SELECT symbol, count(*) AS trades FROM trade_log GROUP BY symbol;
```

Result:

Error: `materialized view 'per_symbol' cannot be refreshed partition by partition: GROUP BY needs a time bucket of 'date': the column itself, to_date(date) or date_trunc('day' | 'month' | 'year' | 'hour' | ..., date)`

**Example: Rows of a view come only from its query** (sample data: sample; shows an error)

Setup:

```sql
CREATE MATERIALIZED VIEW daily_count AS SELECT date, count(*) AS trades FROM trade_log GROUP BY date;
```

```sql
DELETE FROM daily_count;
```

Result:

Error: `'daily_count' is a materialized view: its rows come from its query. Change the rows of its table instead, or run REFRESH MATERIALIZED VIEW daily_count`

<a id="refresh-view"></a>

## REFRESH VIEW

Syntax:

```sql
REFRESH VIEW name
REFRESH MATERIALIZED VIEW name
```

Runs the query of a [cached view](#cached-view) again and keeps the new rows.

- **Returns:** `view 'name' refreshed: N row(s)`.
- **Notes:**
  - It needs the `admin` role, and it cannot be used inside `BEGIN` ... `COMMIT`.
  - `MATERIALIZED` is optional; PostgreSQL writes it.
  - A view made with `REFRESH ON COMMIT` does not need it, but it does no harm.
  - For a [materialized view](#materialized-view) it rebuilds the view from its table; see there for `CONCURRENTLY`, `FULL`, `INCREMENTAL` and `RANGE`.

**Example: Make a cached view new after loading trades** (sample data: sample)

Setup:

```sql
CREATE CACHED VIEW shares_per_symbol AS SELECT symbol, sum(quantity) AS shares FROM trade_log GROUP BY symbol;
```

```sql
REFRESH VIEW shares_per_symbol;
SELECT * FROM shares_per_symbol ORDER BY shares DESC LIMIT 3;
```

Result:

`REFRESH VIEW shares_per_symbol`

```text
view 'shares_per_symbol' refreshed: 4 row(s)
```

`SELECT * FROM shares_per_symbol ORDER BY shares DESC LIMIT 3`

| symbol (SYMBOL) | shares (LONG) |
|---|---|
| COAST | 3070 |
| TELCO | 2770 |
| CITY | 2420 |

(3 rows)

**Example: A normal view has nothing to refresh** (sample data: sample; shows an error)

Setup:

```sql
CREATE VIEW banks AS SELECT symbol FROM securities WHERE sector = 'Banking';
```

```sql
REFRESH VIEW banks;
```

Result:

Error: `view 'banks' is not a cached view: it runs its query on every read, so there is nothing to refresh`

<a id="drop-view"></a>

## DROP VIEW

Syntax:

```sql
DROP VIEW [IF EXISTS] name
```

Removes the view. The tables and rows it reads are not touched.

| Part | Meaning |
|---|---|
| `IF EXISTS` | no error when there is no such view |

- **Returns:** `view 'name' dropped`, or `view 'name' does not exist` with `IF EXISTS`.
- **Notes:**
  - `DROP VIEW` does not check whether another view uses this view. That other view fails the next time it is used.
  - `DROP VIEW` only drops views. For a table, use `DROP TABLE` (see [create-table](create-table.md)).

**Example: Drop a view, then drop it again safely** (sample data: sample)

Setup:

```sql
CREATE VIEW banks AS SELECT symbol FROM securities WHERE sector = 'Banking';
```

```sql
DROP VIEW banks;
DROP VIEW IF EXISTS banks;
SHOW VIEWS;
```

Result:

`DROP VIEW banks`

```text
view 'banks' dropped
```

`DROP VIEW IF EXISTS banks`

```text
view 'banks' does not exist
```

`SHOW VIEWS`

| name (STRING) | query (STRING) | kind (STRING) | refresh (STRING) |
|---|---|---|---|

(0 rows)

**Example: No such view** (sample data: sample; shows an error)

```sql
DROP VIEW banks;
```

Result:

Error: `view 'banks' does not exist`

**Example: Dropping a view that another view uses** (sample data: sample; shows an error)

Setup:

```sql
CREATE VIEW broker_names AS SELECT id, name FROM brokers;
CREATE VIEW big_brokers AS SELECT name FROM broker_names WHERE id > 40;
```

```sql
DROP VIEW broker_names;
SELECT * FROM big_brokers;
```

Result:

```text
view 'broker_names' dropped
```

Error: `view 'big_brokers': line 1, column 18: table or view 'broker_names' does not exist`

<a id="show-views"></a>

## SHOW VIEWS

Syntax:

```sql
SHOW VIEWS
```

Lists the views of the current database.

| Column | Meaning |
|---|---|
| `name` | the view name, as it was written in `CREATE VIEW` |
| `query` | the saved `SELECT`, as KDB writes it back |
| `kind` | `simple`, `complex` or `materialized` (see [kinds of views](#view-kinds)) |
| `refresh` | `ON COMMIT` for a cached view made with `REFRESH ON COMMIT`, `ON INSERT` for a [materialized view](#materialized-view), else NULL |

- **Returns:** one row per view, sorted by name; no rows when there are no views.
- **Notes:** views are not listed by `SHOW TABLES`. The web console shows the same list, split by kind, under **Views** on the left.

**Example: The views of the database, their queries and kinds** (sample data: sample)

Setup:

```sql
CREATE VIEW banks AS SELECT symbol, name FROM securities WHERE sector = 'Banking';
CREATE CACHED VIEW trades_per_symbol AS (SELECT symbol, count(*) AS trades FROM trade_log GROUP BY symbol) REFRESH ON COMMIT;
```

```sql
SHOW VIEWS;
```

Result:

| name (STRING) | query (STRING) | kind (STRING) | refresh (STRING) |
|---|---|---|---|
| banks | SELECT symbol, name FROM securities WHERE sector = 'Banking' | simple | NULL |
| trades_per_symbol | SELECT symbol, count(*) AS trades FROM trade_log GROUP BY symbol | materialized | ON COMMIT |

(2 rows)

<a id="view-kinds"></a>

## Simple, complex and materialized views

`SHOW VIEWS` puts every view into one of three kinds. The kind is worked out from the view's query; you do not write it.

| Kind | What the query does | Example |
|---|---|---|
| `simple` | reads **one** table (or view) and works one row at a time: picks columns, computes values from one row, filters with `WHERE`, sorts | `SELECT symbol, name FROM securities WHERE sector = 'Energy'` |
| `complex` | anything more: `JOIN`, `GROUP BY`, `HAVING`, `SAMPLE BY`, `LATEST ON`, `DISTINCT`, `UNION`, `WITH`, an aggregate such as `count(*)`, a window function (`OVER`), or a subquery | `SELECT symbol, count(*) FROM trade_log GROUP BY symbol` |
| `materialized` | made with `CREATE CACHED VIEW`, whatever its query is | `CREATE CACHED VIEW ... REFRESH ON COMMIT` |

- In a **simple** view each row is one row of the table, so it is quick and easy to follow.
- A **complex** view makes new rows (one per group, per candle, per joined pair). Put a `WHERE` on the columns it groups by, or on its time column, to keep it fast.
- A **materialized** view keeps its result, so reading it is quick however slow its query is. Its rows are made new by [REFRESH VIEW](#refresh-view), or after each commit with `REFRESH ON COMMIT` (see [CREATE CACHED VIEW](#cached-view)).

**Example: One view of each kind** (sample data: sample)

Setup:

```sql
CREATE VIEW hydro AS SELECT symbol, name FROM securities WHERE sector = 'Energy';
CREATE VIEW trades_with_names AS
SELECT f.symbol, s.name, f.quantity FROM trade_log f JOIN securities s ON s.symbol = f.symbol;
CREATE CACHED VIEW shares_per_symbol AS
SELECT symbol, sum(quantity) AS shares FROM trade_log GROUP BY symbol
REFRESH ON COMMIT;
```

```sql
SHOW VIEWS;
```

Result:

| name (STRING) | query (STRING) | kind (STRING) | refresh (STRING) |
|---|---|---|---|
| hydro | SELECT symbol, name FROM securities WHERE sector = 'Energy' | simple | NULL |
| shares_per_symbol | SELECT symbol, sum(quantity) AS shares FROM trade_log GROUP BY symbol | materialized | ON COMMIT |
| trades_with_names | SELECT f.symbol, s.name, f.quantity FROM trade_log AS f JOIN securities AS s ON s.symbol = f.symbol | complex | NULL |

(3 rows)
