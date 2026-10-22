# Known limitations

- Category: Tutorial

This page lists what is missing, or works differently from QuestDB, in KDB `0.2.0-dev` (September 2026). Please check again after you update KDB.

## Problems found while writing this tutorial (all fixed)

Writing and running this tutorial found 12 bugs. All of them are fixed, and each one has a test now.

| # | Was | Now |
|---|---|---|
| 1 | `count()` without `*` crashed KDB (and the whole server over HTTP). | `count()` is the same as `count(*)`. |
| 2 | `WITH OFFSET '00:15'` (no sign) failed when the query ran. | Works; it means `'+00:15'`. |
| 3 | `time IN '2026-09+05:45'` (a month or year with an offset) selected the wrong range. | Selects exactly that month or year in that time zone. |
| 4 | `ADD COLUMN ... DEFAULT value`: rows already in the table got NULL. | They get the default value. |
| 5 | `kdb check` right after a restore reported missing `(previous)` files. | A restored database checks clean. |
| 6 | After `kdb repair --accept-log-loss`, `kdb check` kept reporting the cut log forever. | The cut is reported once, by the repair. Later checks are clean. |
| 7 | On Windows, non-English text in command-line arguments became `?`. | Text in any language (for example Nepali) works in `kdb sql market "..."`. |
| 8 | A DECIMAL written as a number with 15+ digits was refused with a wrong message. | Stored exactly up to about 15 digits; above that the message says to write it as text. |
| 9 | `PRIMARY KEY` on a time-series table was checked only inside one partition. | Refused when the table is created; use `DEDUP KEY (..., time)`. |
| 10 | Messages named port 9900 and "phase 3". | Messages point to the running server's console or HTTP API. |
| 11 | `kdb info` looked like a full damage check. | `kdb info` says it shows the recorded status and to run `kdb check`. |
| 12 | `kdb shell` ignored `.help` and other dot commands on the first line piped from PowerShell. | The byte order mark PowerShell adds is skipped. |

## Not available yet

### Connecting

- **PostgreSQL protocol** (port 8832, chapter 14) works for SQL and `COPY` (pgx `CopyFrom`, psql `\copy`), with TLS when `kdb serve --tls-cert` is set (`sslmode=require`), but: only the common parts of the Postgres catalog (`\l`, `\dt` and `\di` in psql work; a full `\d <table>` still fails on one of its queries, and ORMs that read the schema may too), no `SAVEPOINT`, no two-factor users. You write KDB SQL, not Postgres SQL. `TIMESTAMP` is sent as `timestamp` without time zone: send UTC times from Go, or start with `--pg-timestamptz`.
- **ILP** (InfluxDB line protocol) works over HTTP only (`POST /write`, like QuestDB's HTTP ILP). The separate TCP ILP port (QuestDB 9009) is not available.
- **`/imp` CSV upload**: works like QuestDB's (chapter 8). The `schema` part may only give column types (no date patterns).
- **One PostgreSQL port per machine.** Every `kdb serve` opens port 8832 as well as its HTTP port. A second `kdb serve` on the same machine stops with `port 8832 on 127.0.0.1 is already in use`; start it with `--pg-port 0` (off) or another port.
- **HTTPS**: `kdb serve --tls-cert` (docs/help/topics/tls.md), or a reverse proxy. Certificates are read at start: restart after renewing one.
- **Users and roles** (chapter 16): rights are per database (read, write, admin) and per table (`GRANT SELECT ON TABLE`, chapter 21), not per column or row. `CALL` and triggers ignore table rights. `kdb shell` and `kdb sql` do not check users.
- **CORS**: web pages on other sites cannot call KDB. Call it from your backend.
- `kdb.conf` holds only a few settings: `data_dir`, `wal_archive_mb`, `keep_versions`, `trash_keep_hours`, `web_dir`, `help_dir` and `skill_dir`. Everything else is a command-line option of `kdb serve`.
- No Windows service mode (the Linux package has a systemd unit, `kdb.service`). Stop the server with Ctrl+C; killing it is safe but is an unclean shutdown.
- **Replies are not compressed.** Request bodies may be sent with `Content-Encoding: gzip` or `deflate`.
- `/exec` answers **10,000 rows** unless the request passes `limit`; a cut answer says `"truncated": true`.
- The HTTP server has **8 worker threads**. More slow statements than that at once make every other request wait for a free worker (in a test, a `SELECT 1` waited 18.6 s behind 12 slow scans).
- **Other databases can be read, not written**: `SELECT ... FROM otherdb.t` works, `INSERT INTO otherdb.t` is refused. A transaction does not span databases.

### SQL statements

- `CREATE`, `DROP`, `ALTER` inside a transaction or a procedure.
- Row-level triggers (`FOR EACH ROW`), except a PostgreSQL `BEFORE UPDATE` trigger (chapter 22); `INSTEAD OF` triggers; triggers on views. KDB triggers run once per statement and read all rows from `NEW` / `OLD`. Only `AFTER INSERT` triggers can be `DEFERRED`, and the queue of deferred jobs has no length limit yet.
- Exception handlers in procedures (`EXCEPTION WHEN ...`), `SAVEPOINT`, nested `BEGIN ... END` blocks, `LOOP`, `CASE` as a statement. An error always ends the `CALL` and undoes it.
- Functions that return tables, functions with statements (a saved function is one expression), aggregates written as saved functions.
- `OUT` parameters of procedures (use `SELECT` or `PRINT` to give results back).
- Changing `PARTITION BY` or `SORT BY` of an existing table. (A column's type can change with `ALTER COLUMN ... TYPE`, chapter 22, but not the type of the time column or of a `SORT BY` / `DEDUP KEY` column. The dedup key itself changes with `ALTER TABLE ... DEDUP ENABLE UPSERT KEYS (...)`.)
- `NATURAL JOIN` (write `JOIN ... USING (columns)`). QuestDB's `ASOF JOIN ... TOLERANCE`.
- A recursive `WITH` query stops with an error after 100,000 rounds or 10 million rows. `WITH` queries that change data run before the main query, which sees their changes (chapter 23).
- Advisory locks wait at most 30 seconds (PostgreSQL waits forever). `AT TIME ZONE` takes fixed offsets and zones without daylight saving time only.
- Arrays are sent in binary form with one dimension only; nested arrays go as text.
- A series function inside another (`lag(sma(x, 3))`). Use a subquery. (A window function over `GROUP BY`, `SAMPLE BY` or aggregates works: `lag(sum(v)) OVER (ORDER BY time)`.)
- `DROP PARTITION LIST`, `LATEST BY`, `'2026-09-10;1d'` intervals (QuestDB forms). `DROP PARTITION OLDER THAN 6 MONTHS` works.
- JSON path wildcards (`$.items[*]`), JSON arrays as SQL rows (`json_each`; `unnest` works for arrays), the `jsonb` operator `?`.
- Regular expression back references (`\1` inside a pattern) and look-around (`(?=...)`). `\1` works in the replacement text of `regexp_replace`.

### Behaviour to know

- A `WHERE` on a view goes into the view's query only for the parts that are safe to move; the rest is applied after the view's query has run.
- **FILL** uses one rule for all columns (for example, `FILL(PREV)` also copies the volume).
- `TIME ZONE` accepts only zones without daylight saving time (a fixed zone such as Nepal, +05:45, is fine).
- `hour()`, `day()`, `date_trunc()`, `is_trading_day()` and `time IN '...'` work in **UTC**. For a local clock, add its offset (for example `20700000` ms for Nepal, +05:45).
- `is_trading_day()` does not know market holidays.
- `upper()`, `lower()`, `ILIKE` and the regular expression flag `'i'` change English letters only (many scripts, such as Nepali, have no upper case, so this is fine for them). `length()` counts characters; `octet_length()` counts bytes.
- A STRING, JSON or BYTES value can be at most 16 MB. Keep PDF files and images outside the database; store their path or URL and a hash (chapter 18).
- JSON keeps the order of keys and the spelling of numbers (`1.0` stays `1.0`). Two JSON values are equal only when their text is equal (after spaces are removed), so `{"a":1,"b":2}` is not equal to `{"b":2,"a":1}`.
- Times are stored in **milliseconds**. QuestDB microseconds are cut.
- KDB runs **one change at a time per table** (reads run together, and writers of different tables run at the same time). A long change makes the other writers of its tables wait.
- Only **one program** can open a database. `kdb backup` and `kdb check` need the database closed, or the server's API.
- `kdb sql` table format cuts text after 48 characters; use `--format csv`. With several SELECTs, CSV output has several header lines one after another.
- **Transactions** (`BEGIN` ... `COMMIT`, `CALL`, a statement with triggers) keep the old version of every changed row in memory until they end: at most 10 million changed rows. A statement that fails rolls back the whole transaction.
- **One writer per table** (chapter 15): while a session has an open `BEGIN`, every other change of the tables it used (statements, `CALL`, line protocol, `InsertRows`) **waits**, at most 5 seconds (fixed; no option changes it), then fails with `table 'x' is busy: ...`. Changes of other tables go on. Reads do not wait: they see the rows as they were before the open transaction. Keep transactions short. There are no row locks: two transactions on different accounts of the same table still run one after the other.
- A transaction with no statement for 30 seconds (`idle_transaction_timeout_ms`) is rolled back. After an error or this timeout, the session must send `ROLLBACK` before anything else.
- While another session's transaction is open, a read takes that transaction's changes out of memory for a moment, and its next statement puts them back. For a transaction with very many changed rows (millions), this makes its statements slower when many reads come in between.
- `SELECT ... FOR UPDATE` locks whole tables, not single rows. `FOR SHARE` and `FOR UPDATE OF t` work exactly as `FOR UPDATE`. `NOWAIT` fails at once when another transaction holds a table it needs, and `SKIP LOCKED` then returns no rows at once: every row of a held table counts as locked, so two job-queue workers never take two different jobs at the same moment.
- `SAVEPOINT`, `SET TRANSACTION ISOLATION LEVEL` and `READ ONLY` transactions are not supported (every transaction is serializable).
- `CHECK` constraints look at **one row**: no subqueries, aggregates, window functions, saved functions or computed columns in them. A `CHECK` cannot compare with other rows (for example "the sum of all balances"). A `NULL` value passes a `CHECK`; use `NOT NULL` too.
- `ALTER TABLE ... ADD CHECK` reads every row of the table once (slow for very big time-series tables).
- `AUTO` ids only go up, like a PostgreSQL sequence: the id of a deleted row, or of an insert that was rolled back, is **never used again**, so there can be gaps (1, 2, 4, ...). Do not use AUTO ids as a count of rows.
- `DECIMAL` arithmetic (`balance - 12.50`) is worked out with a double and rounded back to the column's scale. Values up to about 90 billion (2 decimal places) are exact; a result that cannot be made exact is refused with an error, never stored wrong.
- `RETURNING` gives the rows as they are written (for `DELETE`: as they were). With `INSERT OR IGNORE`, skipped rows are not returned.
- In a procedure, a **column name wins over a variable** with the same name. Name variables so they are not column names.
- KDB checks procedure and trigger bodies for syntax when they are created; unknown tables, columns and procedures are found only when they run. `DROP FUNCTION`, `DROP PROCEDURE` and `DROP VIEW` do not check who uses them.
- A table with triggers cannot be dropped or renamed; drop its triggers first.
- A table with an `INSERT` trigger that is not `DEFERRED` is loaded row by row (`InsertRows`, line protocol), with the trigger inside the write. Other tables of the database, and a table whose triggers are all `DEFERRED`, keep the fast way.
- A cursor keeps all its rows in memory (at most 10 million) until it is closed or unused for 10 minutes. At most 16 open cursors per database.
- A `WHILE` loop stops with an error after 10 million rounds.
- **Indexes live in memory** (chapter 17) and are built from the rows after every open: about 0.2 seconds per million rows for a plain index, about 1 second per 200 MB of text for a FULLTEXT index. `kdb serve` builds them on a background thread right after the open (`--warm-indexes`, on by default); a query that comes first builds the index itself, and `kdb sql` always builds on first use. A FULLTEXT index of a table with one partition makes writers of that table wait while it is built. A plain or FULLTEXT index bigger than `index_memory_bytes` (default 2 GB) is not built and queries read the table instead; `SHOW INDEXES` shows `built = false` then.
- Expression and partial indexes are built and used, but only in these shapes: an expression key part needs `expr = constant` with exactly the index's expression (no ranges, no `IN (...)`, no `ORDER BY` on it), and a partial index is used only when every part of its `WHERE` is also a condition of the query. `INCLUDE` columns are ignored.
- A query uses an index only for the **first table** in `FROM`, not for the tables of a `JOIN`. It does not use one for `OR`, `!=`, `NOT LIKE`, FLOAT columns, or text compared with a number. A function around the column (`lower(email) = ...`) needs an expression index on exactly that expression. When an index would read more than a quarter of the table, KDB reads the table instead. Use `EXPLAIN` to see what happens.
- Tables with an index are slower to write in big line-protocol batches: every row looks up the row it replaces. A table with a `UNIQUE` index cannot use the fast column-wise path for `InsertRows` at all.
- **Full-text search** finds whole words. There is no stemming: `bank` does not find `banks`, and `बैंक` does not find `बैंकले`. Use a prefix (`bank*`, `बैंक*`). There are no stop words, no `OR` inside the search text, no fuzzy search, and no synonyms.
- `search_rank` on a table without a FULLTEXT index on the same columns reads the whole table once per query. (A phrase such as `'"city bank"'` is answered from the index since 2026-09-23: it keeps every word's positions.)
- The **statement timeout** of `kdb serve` (chapter 21) is checked between rows (every 1,024 rows on the row path, once per batch in the column engine). One long step without rows in between (a huge sort, or one 16 MB value in a slow regular expression) finishes that step first. `kdb sql`, `kdb shell` and library apps have no timeout or memory limits.
- **A full disk**: a write gets HTTP 507 (`{"code":"disk full"}`) or SQLSTATE `53100`, and committed rows stay. With the default `--sync-commits always`, a full disk during the log flush **stops the whole database, reads too**, until it is reopened. An `INSERT` can get 507 although its rows were committed (the checkpoint after it failed): count before you send again.
- `DROP TABLE` of a table with named `UNIQUE`/`PRIMARY KEY` constraints skips the trash (no `UNDROP TABLE` for it). `UNDROP TABLE` does not bring back table rights.
- The web console's **Run** (Ctrl+Enter) finds a whole `CREATE PROCEDURE ... END` under the cursor, but a column or alias named `begin` right after `AS` confuses it; use **Run all** then.

### PostgreSQL schema (chapter 22)

- plpgsql runs only as a row trigger: `CREATE FUNCTION f() RETURNS trigger ... LANGUAGE plpgsql` used by a `BEFORE UPDATE ... FOR EACH ROW` trigger. `INSERT` and `AFTER` row triggers are refused. Any other plpgsql function is recorded with a warning and **never runs**. Write KDB triggers and procedures (chapter 13).
- `DO $$ ... $$` blocks may use only `IF`, `RAISE`, `NULL` and SQL statements (no `DECLARE`, loops, `PERFORM`, `EXECUTE`, `EXCEPTION`). A DO block is **not one transaction**: statements before an error stay.
- `SERIAL` / `IDENTITY` only for the single-column `PRIMARY KEY`. Use a sequence for other columns.
- `NUMERIC` without precision is a `DOUBLE`. `NUMERIC(p,s)`: at most 18 decimal places and about 18 digits in total. `FLOAT` alone is 4 bytes. `CHAR(n)` is not padded. `CITEXT` is not case-insensitive. `INTERVAL` is milliseconds (a month is 30 days). `INET`, `CIDR`, `MACADDR`, `XML` are not checked.
- `GENERATED ALWAYS AS (...) STORED` columns are worked out when read, not stored.
- The `PRIMARY KEY` cannot be dropped. `DROP TABLE ... CASCADE` is accepted but drops nothing else: a table that another table `REFERENCES` still cannot be dropped. `DEFERRABLE` constraints, `INHERITS`, `PARTITION BY RANGE`, `EXCLUDE` constraints and schemas other than `public` are not supported. Table constraints must come after the columns.
- In one `INSERT` of many rows, a row may refer (REFERENCES) only to rows before it, not to rows after it.
- A foreign key action reads the whole child table for each changed parent row when the child column has no key or index. Add an index on foreign key columns of big tables.
- `ALTER COLUMN ... TYPE` and `ADD PRIMARY KEY` write every row again (slow for very big tables).
- The catalog views have the common columns only. `TIMESTAMPTZ` columns are sent over the PostgreSQL protocol as `timestamp` unless the server runs with `--pg-timestamptz`.
- Older KDB programs refuse databases that use these features (`needs a newer KDB`) or cannot replay their log (sequences). Update every `kdb` program first.

### Analysis functions (chapter 19)

- The new aggregates (`corr`, `percentile_cont`, `mode`, `sharpe_ratio`, ...), window frames with `BETWEEN`, indicators and table functions run only in the **row engine**. A query that uses one of them never uses the fast column engine, so it is slower on very big tables.
- Aggregates that keep every value (`percentile_cont`, `percentile_disc`, `mode`, `mad`, `iqr`, `value_at_risk`, `expected_shortfall`, `string_agg`, `array_agg`) sort again for every row in a running `OVER (... ORDER BY ...)` window: slow for partitions of many thousand rows. Use `ROWS n PRECEDING`. `ROWS BETWEEN a PRECEDING AND b FOLLOWING` frames also add up every frame again.
- Window frames: no `GROUPS` frames, no `EXCLUDE`, no `RANGE` distances in months or years (use days), no named windows (`WINDOW w AS (...)`), no `IGNORE NULLS`.
- `WITHIN GROUP (ORDER BY x DESC)` is not supported (use `1 - fraction`). `approx_count_distinct` counts exactly (there is no approximate method).
- A series function still cannot be inside another one (`macd(sma(close, 3))`), and an aggregate cannot hold a window function (`sum(lag(close))` gives "queries are nested too deeply"). A window over aggregates works (`sum(sum(qty)) OVER (ORDER BY time)` with GROUP BY or SAMPLE BY). Use one subquery per step for the rest, as in the chapter's cookbook.
- **Running indicators** (EMA-based ones, MACD, KAMA, ADX, SAR, OBV, MFI, SuperTrend, Heikin-Ashi) stop at the first NULL input: every later row of that partition is NULL. Filter NULL rows first.
- The older `rsi(x, n)` keeps its KDB definition: a completely flat start gives 50 (TA-Lib gives 0), and a NULL price counts as no change. Otherwise it gives TA-Lib's values (tested within 1e-9). `stochrsi_k` uses TA-Lib's RSI.
- `macd` starts on row 34 (as TA-Lib); TradingView shows the MACD line from row 26. `supertrend_direction` gives 1 for an up trend, the opposite sign of TradingView's `direction`. `ichimoku_senkou_a/b` put the value computed `shift` rows before on each row (a table has no rows in the future); `ichimoku_chikou` reads rows in the future.
- `fiscal_year`, `fiscal_quarter` and `nepal_fiscal_year` use a fixed start day (July 17). They do not know the Bikram Sambat calendar: in a year where Shrawan 1 is July 16, that day is counted in the old fiscal year. There are no BS date conversions.
- `random()` and `setseed()` share one random generator for the whole server; with several query threads the numbers of a query can come in a different order.
- `generate_series` needs constant arguments (it cannot read columns of other tables) and makes at most 10 million rows. `PIVOT` needs the IN values written in the query (no dynamic pivot), and every column of the source that PIVOT does not use becomes a group key.

### Users, passwords and security

- **Logins live in memory.** A server restart logs everyone out (web console, `POST /api/login` tokens).
- **HTTPS** inside KDB needs `--tls-cert` (docs/help/topics/tls.md); otherwise use a reverse proxy (Caddy, nginx) or an SSH tunnel. Over plain HTTP, passwords and tokens can be read on the network.
- The failed-login limit counts per address. Behind a reverse proxy every client has the address `127.0.0.1`, so wrong passwords from one person also slow down others who log in as the **same** user.
- The **SCRAM-SHA-256** secret of a database user uses 4,096 rounds (like PostgreSQL); the password hash uses 600,000. Use long random passwords for database users.
- **Old KDB versions do not know users.** A `kdb` built before users existed would open a data folder with users and serve it **without** a login. Always update every `kdb` program first, and never start an old one on that folder.
- `password_hash` in `UPDATE ... SET password_hash = password_hash('x')` gives every changed row the same hash (one salt). Change passwords one row at a time.
- `ADD COLUMN id STRING DEFAULT gen_random_uuid()` gives all **old** rows one and the same value; new rows get their own. Do not use random functions in computed columns (`AS (...)`): the value changes each time the row is read.
- The HTTP cursors (`/cursor/<id>`) are not tied to a user: another user with `read` on the same database who knows the id can read the rows. The id is long and random; do not share it.
- **The audit log** (chapter 21) writes security events every 200 ms: a crash can lose the events of that last moment (data-change audit rows are in the same transaction and are never lost). It is not signed: whoever can change the data files can change it. A server on one folder path (`kdb serve D:\kdb\market`) has no security audit log.
- **Two-factor login** works only for HTTP logins (console, `POST /api/login`). HTTP Basic and the PostgreSQL port refuse users with two-factor login.
- **No encryption of the files** (data, log, backups). Protect them with file permissions. The plan is in `docs/design/encryption-at-rest.md`.
- Older KDB programs refuse databases with audited tables and data folders with table rights or two-factor users (they would ignore them). Update every `kdb` program first.
- User names and passwords go through `kdb user add` from stdin or a prompt, never the command line. The console history masks `PASSWORD '...'`, but your own scripts and logs may still contain passwords you typed into SQL.

### Versions and upgrades (chapter 24)

- **KDB programs built before 2026-09-12 do not read the feature list.** They still refuse most new data (new catalog parts, file formats), but not everything: for example they ignore sequences, table rights or the trash. Never open new data with an old program. Update every `kdb` program first.
- **There is no downgrade.** Once a feature is in a database's list, an older KDB that does not know it refuses the database, even after you drop the table that used it. Keep the backup that `kdb upgrade` makes if you may need the older KDB again.
- The list says *which* features a database uses, not *how much*. A database that used `JSON` once is refused by an older KDB without JSON, for as long as it exists.
- `CREATE TABLE ... AS SELECT` with a `JSON` or `BYTES` result column records that feature at the checkpoint right after the statement, not before it. A crash exactly between the two leaves the feature out of the list until the next checkpoint (the database itself is fine).
- `kdb check` reads the catalog, file format numbers and log record types, but not every value inside every row of the log: a row value of an unknown type is found when the database opens (the same "needs a newer KDB" message).
- `kdb upgrade` rewrites no files in this version: nothing needs it.

## Parts of this tutorial that were not run

Everything else in the tutorial was run and the output was copied from the run (see `examples/verify.ps1`). These parts were **not** run:

| Part | Why |
|---|---|
| Build commands for Linux and macOS (chapter 1) | The tutorial was written on Windows. |
| C# client (chapter 8) | No .NET SDK on the test PC. |
| `Register-ScheduledTask` and `cron` lines (chapter 7) | They would change the test PC. The backup script itself was run. |
| QuestDB `/exp` export commands (chapter 10) | No QuestDB on the test PC. The sample CSV files were written by hand in QuestDB style. |
| `kdb serve` banner with port 9900 (quick start, chapter 6) | Port 9900 was in use on the test PC; the banner was taken from a server on a test port, with only the port number changed. |
| Screen description of the web console (chapter 6) | Checked by using the console in a browser against a test server; screenshots are not included. |
