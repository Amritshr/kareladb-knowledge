# Triggers

> SQL that runs by itself when rows of a table are inserted, updated or deleted.

- Category: Triggers
- Keywords: trigger, BEFORE, AFTER, EXECUTE, TRIGGERS, CREATE OR REPLACE TRIGGER, ENABLE TRIGGER, DISABLE TRIGGER, ENABLE, DISABLE, EXECUTE PROCEDURE, EXECUTE CALL, statement level, triggers are nested too deeply, has triggers, audit log, DEFERRED, deferred trigger, RETRY TRIGGER QUEUE, SKIP TRIGGER JOB, trigger queue, /api/trigger-queue, wait
- See also: [Stored procedures](procedures.md), [The procedure language](procedure-language.md), [Transactions](transactions.md), [ALTER, RENAME and DROP TABLE](alter-table.md), [13. Functions, procedures and triggers](../tutorial/13-functions-procedures-triggers.md)

A **trigger** is SQL that KarelaDB runs by itself every time a table changes. You do not call it.
Use it to keep another table up to date, to write an audit log (a list of who changed what), or to refuse bad changes.

- A trigger runs **once per statement**, not once per row. It reads the changed rows from the tables [`NEW` and `OLD`](triggers.md#new-old).
- It runs in the **same transaction** as the statement. If the trigger fails, the statement is undone too.

A real job: the app shows the last price of every share. Instead of searching `live_data` every time, a trigger keeps a small table `latest_price` up to date.

**Example: Market data: keep the latest price of every share up to date** (sample data: sample)

```sql
CREATE TABLE latest_price (symbol SYMBOL PRIMARY KEY, ltp DOUBLE, time TIMESTAMP);

CREATE TRIGGER keep_latest AFTER INSERT ON live_data EXECUTE BEGIN
  FOR r IN (SELECT symbol, last(ltp) AS ltp, max(timestamp) AS time FROM NEW GROUP BY symbol) DO
    INSERT OR REPLACE INTO latest_price VALUES (r.symbol, r.ltp, r.time);
  END FOR;
END;

INSERT INTO live_data VALUES
  ('2026-09-11T11:00:00+05:45', 'CITY', 528.0, 10, 0.9, 0.17, 527.1, 528.0, 527.1, 527.5, 527.1, 1200),
  ('2026-09-11T11:01:00+05:45', 'CITY', 529.5, 20, 2.4, 0.46, 527.1, 529.5, 527.1, 528.2, 527.1, 3400),
  ('2026-09-11T11:00:00+05:45', 'COAST', 402.5, 10, 0.6, 0.15, 401.9, 402.5, 401.9, 402.2, 401.9, 800);

SELECT symbol, ltp, time FROM latest_price ORDER BY symbol;
```

Result:

`CREATE TABLE latest_price (`

```text
table 'latest_price' created
```

`CREATE TRIGGER keep_latest AFTER INSERT ON live_data EXECUTE BEGIN`

```text
trigger 'keep_latest' created on table 'live_data'
```

`INSERT INTO live_data VALUES ('2026-09-11T11:00:00+05:45', 'CITY', 528.0, 10, 0.9, 0.17, 527.1, 528.`

```text
3 row(s) inserted
```

`SELECT symbol, ltp, time FROM latest_price ORDER BY symbol`

| symbol (SYMBOL) | ltp (DOUBLE) | time (TIMESTAMP) |
|---|---|---|
| CITY | 529.5 | 2026-09-11T05:16:00.000Z |
| COAST | 402.5 | 2026-09-11T05:15:00.000Z |

(2 rows)

<a id="create-trigger"></a>

## CREATE TRIGGER

Syntax:

```sql
CREATE [OR REPLACE] TRIGGER name {BEFORE | AFTER} {INSERT | UPDATE | DELETE} ON table
  EXECUTE CALL procedure(argument, ...)
CREATE [OR REPLACE] TRIGGER name {BEFORE | AFTER} {INSERT | UPDATE | DELETE} ON table
  EXECUTE PROCEDURE procedure(argument, ...)
CREATE [OR REPLACE] TRIGGER name {BEFORE | AFTER} {INSERT | UPDATE | DELETE} ON table
  EXECUTE {INSERT ... | UPDATE ... | DELETE ...}
CREATE [OR REPLACE] TRIGGER name {BEFORE | AFTER} {INSERT | UPDATE | DELETE} ON table
  EXECUTE BEGIN statement; ... END
```

Saves a trigger on a table. `OR REPLACE` changes a trigger that already exists.

| Part | Meaning |
|---|---|
| `name` | the trigger name. It must be unique in the database (not only in the table). |
| `BEFORE` / `AFTER` | run before the rows are written, or after. See [BEFORE and AFTER](triggers.md#before-after). |
| `INSERT` / `UPDATE` / `DELETE` | the kind of change. `INSERT OR REPLACE` and `INSERT OR IGNORE` are `INSERT`. One trigger has one kind: make two triggers for two kinds. |
| `ON table` | the table. It must exist. Not a view. |
| `EXECUTE CALL p(...)` | run a [procedure](procedures.md). Inside it, `NEW` and `OLD` work too. |
| `EXECUTE PROCEDURE p(...)` | the same as `EXECUTE CALL` (the PostgreSQL way to write it) |
| `EXECUTE INSERT/UPDATE/DELETE ...` | run one statement |
| `EXECUTE BEGIN ... END` | run a body, like a procedure body: variables, `IF`, `FOR`, `RAISE`, `PRINT` ([the procedure language](procedure-language.md)) |

- **Returns:** `trigger 'name' created on table 'table'` (or `replaced`).
- **Notes:**
  - A trigger fires for every way of writing: SQL, `POST /write` (line protocol), and bulk loads. A statement that changes no row does not fire it.
  - `EXECUTE SELECT ...` is not allowed. To copy the rows of `NEW` into another table, use `INSERT INTO other SELECT ... FROM NEW` or `BEGIN FOR r IN (SELECT ... FROM NEW) DO INSERT ... END FOR; END`.
  - `PRINT` lines of a trigger come back as a `print` result of the statement that fired it.
  - `CREATE TRIGGER` cannot be used inside `BEGIN ... COMMIT`.
  - Keep trigger bodies short: they run inside every change of the table. See [triggers and load speed](triggers.md#speed).

**Example: App users: write a sign-up audit log**

```sql
CREATE TABLE app_users (id INT PRIMARY KEY AUTO, email STRING NOT NULL, created TIMESTAMP DEFAULT now());
CREATE TABLE audit_log (id LONG PRIMARY KEY AUTO, time TIMESTAMP DEFAULT now(), action STRING, detail STRING);

CREATE TRIGGER log_signup AFTER INSERT ON app_users EXECUTE BEGIN
  FOR u IN (SELECT id, email FROM NEW ORDER BY id) DO
    INSERT INTO audit_log (action, detail) VALUES ('sign-up', concat('user ', u.id, ': ', u.email));
  END FOR;
END;

INSERT INTO app_users (email) VALUES ('ram@example.com'), ('sita@example.com');
INSERT INTO app_users (email) VALUES ('hari@example.com');
SELECT id, action, detail FROM audit_log ORDER BY id;
```

Result:

`CREATE TABLE app_users (`

```text
table 'app_users' created
```

`CREATE TABLE audit_log (`

```text
table 'audit_log' created
```

`CREATE TRIGGER log_signup AFTER INSERT ON app_users EXECUTE BEGIN`

```text
trigger 'log_signup' created on table 'app_users'
```

`INSERT INTO app_users (email) VALUES ('ram@example.com'), ('sita@example.com')`

```text
2 row(s) inserted
```

`INSERT INTO app_users (email) VALUES ('hari@example.com')`

```text
1 row(s) inserted
```

`SELECT id, action, detail FROM audit_log ORDER BY id`

| id (LONG) | action (STRING) | detail (STRING) |
|---|---|---|
| 1 | sign-up | user 1: ram@example.com |
| 2 | sign-up | user 2: sita@example.com |
| 3 | sign-up | user 3: hari@example.com |

(3 rows)

**Example: Forum: post counters kept by two triggers that call procedures**

```sql
CREATE TABLE topics (id INT PRIMARY KEY, title STRING NOT NULL, posts LONG NOT NULL DEFAULT 0);
CREATE TABLE posts (id LONG PRIMARY KEY AUTO, topic_id INT NOT NULL, author STRING, body STRING);

CREATE PROCEDURE count_new_posts() AS BEGIN
  FOR r IN (SELECT topic_id, count(*) AS n FROM NEW GROUP BY topic_id) DO
    UPDATE topics SET posts = posts + r.n WHERE id = r.topic_id;
  END FOR;
END;
CREATE PROCEDURE count_deleted_posts() AS BEGIN
  FOR r IN (SELECT topic_id, count(*) AS n FROM OLD GROUP BY topic_id) DO
    UPDATE topics SET posts = posts - r.n WHERE id = r.topic_id;
  END FOR;
END;
CREATE TRIGGER posts_added AFTER INSERT ON posts EXECUTE CALL count_new_posts();
CREATE TRIGGER posts_removed AFTER DELETE ON posts EXECUTE PROCEDURE count_deleted_posts();

INSERT INTO topics (id, title) VALUES (1, 'CITY results'), (2, 'Hydro IPOs');
INSERT INTO posts (topic_id, author, body) VALUES (1, 'ram', 'Profit is up'), (1, 'sita', 'Agree'), (2, 'hari', 'When?');
DELETE FROM posts WHERE author = 'sita';
SELECT id, title, posts FROM topics ORDER BY id;
```

Result:

`CREATE TABLE topics (`

```text
table 'topics' created
```

`CREATE TABLE posts (`

```text
table 'posts' created
```

`CREATE PROCEDURE count_new_posts() AS BEGIN`

```text
procedure 'count_new_posts' created
```

`CREATE PROCEDURE count_deleted_posts() AS BEGIN`

```text
procedure 'count_deleted_posts' created
```

`CREATE TRIGGER posts_added AFTER INSERT ON posts EXECUTE CALL count_new_posts()`

```text
trigger 'posts_added' created on table 'posts'
```

`CREATE TRIGGER posts_removed AFTER DELETE ON posts EXECUTE CALL count_deleted_posts()`

```text
trigger 'posts_removed' created on table 'posts'
```

`INSERT INTO topics (id, title) VALUES (1, 'CITY results'), (2, 'Hydro IPOs')`

```text
2 row(s) inserted
```

`INSERT INTO posts (topic_id, author, body) VALUES (1, 'ram', 'Profit is up'), (1, 'sita', 'Agree'), `

```text
3 row(s) inserted
```

`DELETE FROM posts WHERE author = 'sita'`

```text
1 row(s) deleted
```

`SELECT id, title, posts FROM topics ORDER BY id`

| id (INT) | title (STRING) | posts (LONG) |
|---|---|---|
| 1 | CITY results | 1 |
| 2 | Hydro IPOs | 1 |

(2 rows)

**Example: One statement: count the changes of a table**

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
CREATE TABLE stats (name STRING PRIMARY KEY, n LONG NOT NULL);
INSERT INTO stats VALUES ('broker inserts', 0);

CREATE TRIGGER count_broker_inserts AFTER INSERT ON brokers
  EXECUTE UPDATE stats SET n = n + 1 WHERE name = 'broker inserts';

INSERT INTO brokers VALUES (1, 'Keystone Securities'), (34, 'Vision Securities');
INSERT INTO brokers VALUES (45, 'Imperial Securities');
SELECT * FROM stats;
```

Result:

`CREATE TABLE brokers (`

```text
table 'brokers' created
```

`CREATE TABLE stats (`

```text
table 'stats' created
```

`INSERT INTO stats VALUES ('broker inserts', 0)`

```text
1 row(s) inserted
```

`CREATE TRIGGER count_broker_inserts AFTER INSERT ON brokers EXECUTE UPDATE stats SET n = n + 1 WHERE`

```text
trigger 'count_broker_inserts' created on table 'brokers'
```

`INSERT INTO brokers VALUES (1, 'Keystone Securities'), (34, 'Vision Securities')`

```text
2 row(s) inserted
```

`INSERT INTO brokers VALUES (45, 'Imperial Securities')`

```text
1 row(s) inserted
```

`SELECT * FROM stats`

| name (STRING) | n (LONG) |
|---|---|
| broker inserts | 2 |

(1 row)

**Example: EXECUTE SELECT is not allowed** (shows an error)

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
CREATE TRIGGER t AFTER INSERT ON brokers EXECUTE SELECT * FROM NEW;
```

Result:

Error: `line 2, column 50: expected CALL, INSERT, UPDATE, DELETE or BEGIN ... END after EXECUTE but found 'SELECT'`

**Example: The table must exist** (shows an error)

```sql
CREATE TRIGGER t AFTER INSERT ON orders EXECUTE BEGIN PRINT 'new order'; END;
```

Result:

Error: `table 'orders' does not exist`

<a id="before-after"></a>

## BEFORE and AFTER

Syntax:

```sql
CREATE TRIGGER name BEFORE {INSERT | UPDATE | DELETE} ON table EXECUTE ...
CREATE TRIGGER name AFTER {INSERT | UPDATE | DELETE} ON table EXECUTE ...
```

| | `BEFORE` | `AFTER` |
|---|---|---|
| runs | before the rows are written | after the rows are written |
| the table itself | does not have the change yet | already has the change |
| use it to | check the rows and refuse them with `RAISE` | change other tables |

- **Notes:**
  - Order: all `BEFORE` triggers of the table and event, then the change, then all `AFTER` triggers. Several triggers of the same kind run in **name order**.
  - A `BEFORE` trigger cannot change the rows that are being written (`UPDATE NEW` is an error). It can only accept them or refuse them.
  - `RAISE` in a `BEFORE` or `AFTER` trigger undoes the whole statement.

**Example: The order in which triggers run**

```sql
CREATE TABLE t (id INT PRIMARY KEY);
CREATE TRIGGER b_second BEFORE INSERT ON t EXECUTE BEGIN PRINT concat('before b_second, rows in t: ', (SELECT count(*) FROM t)); END;
CREATE TRIGGER a_first BEFORE INSERT ON t EXECUTE BEGIN PRINT concat('before a_first, rows in t: ', (SELECT count(*) FROM t)); END;
CREATE TRIGGER c_after AFTER INSERT ON t EXECUTE BEGIN PRINT concat('after c_after, rows in t: ', (SELECT count(*) FROM t)); END;
INSERT INTO t VALUES (1), (2);
```

Result:

`CREATE TABLE t (`

```text
table 't' created
```

`CREATE TRIGGER b_second BEFORE INSERT ON t EXECUTE BEGIN`

```text
trigger 'b_second' created on table 't'
```

`CREATE TRIGGER a_first BEFORE INSERT ON t EXECUTE BEGIN`

```text
trigger 'a_first' created on table 't'
```

`CREATE TRIGGER c_after AFTER INSERT ON t EXECUTE BEGIN`

```text
trigger 'c_after' created on table 't'
```

`INSERT INTO t VALUES (1), (2)`

```text
2 row(s) inserted
```

`print`

| output (STRING) |
|---|
| before a_first, rows in t: 0 |
| before b_second, rows in t: 0 |
| after c_after, rows in t: 2 |

(3 rows)

**Example: Market data: refuse a price of 0 or less** (sample data: sample; shows an error)

```sql
CREATE TRIGGER check_price BEFORE INSERT ON live_data EXECUTE BEGIN
  IF EXISTS (SELECT 1 FROM NEW WHERE ltp <= 0) THEN
    RAISE 'ltp must be more than 0';
  END IF;
END;

INSERT INTO live_data VALUES
  ('2026-09-11T11:02:00+05:45', 'CITY', 0, 10, 0, 0, 527.1, 529.5, 527.1, 528.2, 527.1, 3500);
```

Result:

```text
trigger 'check_price' created on table 'live_data'
```

Error: `trigger 'check_price', line 3: ltp must be more than 0`

**Example: Accounting: a balance may never go below zero** (shows an error)

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL DEFAULT 0);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);

CREATE TRIGGER no_negative_balance BEFORE UPDATE ON accounts EXECUTE BEGIN
  FOR r IN (SELECT id, balance FROM NEW WHERE balance < 0) DO
    RAISE concat('account ', r.id, ' would go below zero: ', r.balance);
  END FOR;
END;

UPDATE accounts SET balance = balance - 300 WHERE id = 1;
UPDATE accounts SET balance = balance - 300 WHERE id = 2;
```

Result:

`CREATE TABLE accounts (`

```text
table 'accounts' created
```

`INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0)`

```text
2 row(s) inserted
```

`CREATE TRIGGER no_negative_balance BEFORE UPDATE ON accounts EXECUTE BEGIN`

```text
trigger 'no_negative_balance' created on table 'accounts'
```

`UPDATE accounts SET balance = balance - 300 WHERE id = 1`

```text
1 row(s) updated
```

Error: `trigger 'no_negative_balance', line 3: account 2 would go below zero: -300.00`

<a id="new-old"></a>

## NEW, OLD

Syntax:

```sql
SELECT ... FROM NEW
SELECT ... FROM OLD
SELECT ... FROM OLD o JOIN NEW n ON o.id = n.id
```

Inside a trigger (and in a procedure that the trigger calls), two tables hold the changed rows. They have the columns of the changed table.

| Table | `INSERT` | `UPDATE` | `DELETE` |
|---|---|---|---|
| `NEW` | the inserted rows | the rows after the change | (empty) |
| `OLD` | (empty) | the rows before the change | the deleted rows |

- **Notes:**
  - Use them like read-only tables in `SELECT`, `FOR r IN (SELECT ... FROM NEW)`, `EXISTS (...)`, `SET` and `DECLARE ... DEFAULT (SELECT ...)`. `INSERT INTO NEW`, `UPDATE NEW` and `DELETE FROM NEW` are errors.
  - `INSERT`, `UPDATE` and `DELETE` cannot hold a subquery. So `UPDATE topics SET posts = posts + (SELECT count(*) FROM NEW)` is an error: put the count in a variable first, or loop with `FOR`.
  - For `INSERT OR REPLACE`, the trigger is an `INSERT` trigger: `NEW` holds all written rows, and `OLD` is **empty**, also for the rows that were replaced.
  - For `INSERT OR IGNORE`, `NEW` holds only the rows that were really inserted.
  - Outside a trigger, `NEW` and `OLD` do not exist (unless you have tables with these names).

**Example: Price change log: OLD and NEW side by side**

```sql
CREATE TABLE share_prices (symbol SYMBOL PRIMARY KEY, ltp DOUBLE);
CREATE TABLE price_changes (symbol SYMBOL, old_ltp DOUBLE, new_ltp DOUBLE, changed TIMESTAMP DEFAULT now());
INSERT INTO share_prices VALUES ('CITY', 514.5), ('COAST', 398.0), ('VOLT', 187.3);

CREATE TRIGGER log_price_change AFTER UPDATE ON share_prices EXECUTE BEGIN
  FOR r IN (SELECT o.symbol AS symbol, o.ltp AS old_ltp, n.ltp AS new_ltp
            FROM OLD o JOIN NEW n ON o.symbol = n.symbol
            WHERE o.ltp != n.ltp) DO
    INSERT INTO price_changes (symbol, old_ltp, new_ltp) VALUES (r.symbol, r.old_ltp, r.new_ltp);
  END FOR;
END;

UPDATE share_prices SET ltp = round(ltp * 1.02, 1) WHERE symbol IN ('CITY', 'COAST');
SELECT symbol, old_ltp, new_ltp FROM price_changes ORDER BY symbol;
```

Result:

`CREATE TABLE share_prices (`

```text
table 'share_prices' created
```

`CREATE TABLE price_changes (`

```text
table 'price_changes' created
```

`INSERT INTO share_prices VALUES ('CITY', 514.5), ('COAST', 398.0), ('VOLT', 187.3)`

```text
3 row(s) inserted
```

`CREATE TRIGGER log_price_change AFTER UPDATE ON share_prices EXECUTE BEGIN`

```text
trigger 'log_price_change' created on table 'share_prices'
```

`UPDATE share_prices SET ltp = round(ltp * 1.02, 1) WHERE symbol IN ('CITY', 'COAST')`

```text
2 row(s) updated
```

`SELECT symbol, old_ltp, new_ltp FROM price_changes ORDER BY symbol`

| symbol (SYMBOL) | old_ltp (DOUBLE) | new_ltp (DOUBLE) |
|---|---|---|
| CITY | 514.5 | 524.8 |
| COAST | 398 | 406 |

(2 rows)

**Example: Keep a copy of deleted users**

```sql
CREATE TABLE app_users (id INT PRIMARY KEY, email STRING NOT NULL);
CREATE TABLE deleted_users (id INT, email STRING, deleted TIMESTAMP DEFAULT now());
INSERT INTO app_users VALUES (1, 'ram@example.com'), (2, 'sita@example.com'), (3, 'spam@example.com');

CREATE TRIGGER keep_deleted BEFORE DELETE ON app_users EXECUTE BEGIN
  FOR u IN (SELECT id, email FROM OLD) DO
    INSERT INTO deleted_users (id, email) VALUES (u.id, u.email);
  END FOR;
END;

DELETE FROM app_users WHERE email LIKE 'spam%';
SELECT id, email FROM deleted_users;
```

Result:

`CREATE TABLE app_users (`

```text
table 'app_users' created
```

`CREATE TABLE deleted_users (`

```text
table 'deleted_users' created
```

`INSERT INTO app_users VALUES (1, 'ram@example.com'), (2, 'sita@example.com'), (3, 'spam@example.com'`

```text
3 row(s) inserted
```

`CREATE TRIGGER keep_deleted BEFORE DELETE ON app_users EXECUTE BEGIN`

```text
trigger 'keep_deleted' created on table 'app_users'
```

`DELETE FROM app_users WHERE email LIKE 'spam%'`

```text
1 row(s) deleted
```

`SELECT id, email FROM deleted_users`

| id (INT) | email (STRING) |
|---|---|
| 3 | spam@example.com |

(1 row)

**Example: What NEW and OLD hold for INSERT OR REPLACE and UPDATE**

```sql
CREATE TABLE t (id INT PRIMARY KEY, v INT);
CREATE TRIGGER show_insert AFTER INSERT ON t EXECUTE BEGIN
  PRINT concat('insert: NEW rows ', (SELECT count(*) FROM NEW), ', OLD rows ', (SELECT count(*) FROM OLD));
END;
CREATE TRIGGER show_update AFTER UPDATE ON t EXECUTE BEGIN
  PRINT concat('update: NEW rows ', (SELECT count(*) FROM NEW), ', OLD rows ', (SELECT count(*) FROM OLD));
END;
INSERT INTO t VALUES (1, 10);
INSERT OR REPLACE INTO t VALUES (1, 11), (2, 20);
UPDATE t SET v = v + 1;
```

Result:

`CREATE TABLE t (`

```text
table 't' created
```

`CREATE TRIGGER show_insert AFTER INSERT ON t EXECUTE BEGIN`

```text
trigger 'show_insert' created on table 't'
```

`CREATE TRIGGER show_update AFTER UPDATE ON t EXECUTE BEGIN`

```text
trigger 'show_update' created on table 't'
```

`INSERT INTO t VALUES (1, 10)`

```text
1 row(s) inserted
```

`print`

| output (STRING) |
|---|
| insert: NEW rows 1, OLD rows 0 |

(1 row)

`INSERT OR REPLACE INTO t VALUES (1, 11), (2, 20)`

```text
1 row(s) inserted, 1 replaced
```

`print`

| output (STRING) |
|---|
| insert: NEW rows 2, OLD rows 0 |

(1 row)

`UPDATE t SET v = v + 1`

```text
2 row(s) updated
```

`print`

| output (STRING) |
|---|
| update: NEW rows 2, OLD rows 2 |

(1 row)

**Example: NEW cannot be changed** (shows an error)

```sql
CREATE TABLE t (id INT PRIMARY KEY, v INT);
CREATE TRIGGER fix_value BEFORE INSERT ON t EXECUTE BEGIN
  UPDATE NEW SET v = 0 WHERE v < 0;
END;
INSERT INTO t VALUES (1, -5);
```

Result:

`CREATE TABLE t (`

```text
table 't' created
```

`CREATE TRIGGER fix_value BEFORE INSERT ON t EXECUTE BEGIN`

```text
trigger 'fix_value' created on table 't'
```

Error: `trigger 'fix_value', line 2: table 'NEW' does not exist`

<a id="once-per-statement"></a>

## Once per statement

Syntax:

```sql
INSERT INTO t VALUES (...), (...), (...)   -- the trigger runs once, NEW has 3 rows
```

A KarelaDB trigger is **statement level**: it runs once for each statement (or `POST /write` request, or bulk load call), and `NEW` / `OLD` hold all rows of that statement.
It is not "for each row" like in some other databases.

- **Notes:**
  - Write the body for many rows: `FOR r IN (SELECT ... FROM NEW)`, `GROUP BY`, `count(*)`.
  - A statement that changes no row (`UPDATE ... WHERE` with no match, `DELETE` of nothing) does not fire the trigger.

**Example: Three rows, one run**

```sql
CREATE TABLE floor_trades (id LONG PRIMARY KEY, symbol SYMBOL, quantity LONG);
CREATE TRIGGER report AFTER INSERT ON floor_trades EXECUTE BEGIN
  PRINT concat('trigger ran once for ', (SELECT count(*) FROM NEW), ' rows, ', (SELECT sum(quantity) FROM NEW), ' shares');
END;
INSERT INTO floor_trades VALUES (1, 'CITY', 10), (2, 'COAST', 500), (3, 'CITY', 40);
UPDATE floor_trades SET quantity = 0 WHERE symbol = 'TELCO';
```

Result:

`CREATE TABLE floor_trades (`

```text
table 'floor_trades' created
```

`CREATE TRIGGER report AFTER INSERT ON floor_trades EXECUTE BEGIN`

```text
trigger 'report' created on table 'floor_trades'
```

`INSERT INTO floor_trades VALUES (1, 'CITY', 10), (2, 'COAST', 500), (3, 'CITY', 40)`

```text
3 row(s) inserted
```

`print`

| output (STRING) |
|---|
| trigger ran once for 3 rows, 550 shares |

(1 row)

`UPDATE floor_trades SET quantity = 0 WHERE symbol = 'TELCO'`

```text
0 row(s) updated
```

<a id="per-user-results"></a>

## Per-user results kept up to date

An app shows every user their own watch list: the last price of each share they follow, and whether it passed their alert price. Working that out from the trades on every page view is slow. Instead, triggers keep a small **results table** with one row per user and share, and the app reads it by its key.

| Table | Holds | Changed by |
|---|---|---|
| `watchlist` | what each user follows, and their alert price | the app |
| `trades` | every trade (a time-series table) | the feed |
| `user_quotes` | one row per user and share: last price, time, alert | the triggers only |

- **Three triggers:** a new trade updates the rows of every user who follows that share. A new watch-list row gets its price at once from the latest trade. A removed watch-list row removes its result.
- **Upsert:** `INSERT ... ON CONFLICT (key) DO UPDATE` writes the row when it is new and changes it when it is there ([ON CONFLICT](insert.md#on-conflict)).
- **One row per share from `NEW`:** a write with many trades of one share gives the trigger many rows. `GROUP BY symbol` with `last(price)` makes it one, so each result row is written once.
- **Reading is a key lookup:** `WHERE user_name = 'ram'` on the key reads only that user's rows, however many users there are.
- **In memory:** a small table like `user_quotes` stays loaded; it is the last one KarelaDB unloads when memory is short ([memory limit](cli-serve.md#memory-limit)).

**Example: A watch list with alerts, kept up to date by triggers**

Setup:

```sql
CREATE TABLE watchlist (user_name STRING NOT NULL, symbol SYMBOL NOT NULL, alert_above DOUBLE, PRIMARY KEY (user_name, symbol));
CREATE TABLE trades (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
CREATE TABLE user_quotes (user_name STRING NOT NULL, symbol SYMBOL NOT NULL, price DOUBLE, time TIMESTAMP, alert BOOL,
  PRIMARY KEY (user_name, symbol));

-- A new trade: update every user who follows that share.
CREATE TRIGGER quotes_on_trade AFTER INSERT ON trades EXECUTE
  INSERT INTO user_quotes (user_name, symbol, price, time, alert)
  SELECT w.user_name, n.symbol, n.price, n.time, n.price > w.alert_above
  FROM (SELECT symbol, last(price) AS price, max(time) AS time FROM NEW GROUP BY symbol) n
  JOIN watchlist w ON w.symbol = n.symbol
  ON CONFLICT (user_name, symbol) DO UPDATE SET price = EXCLUDED.price, time = EXCLUDED.time, alert = EXCLUDED.alert;

-- A share added to a watch list: its latest trade right away.
CREATE TRIGGER quotes_on_follow AFTER INSERT ON watchlist EXECUTE
  INSERT INTO user_quotes (user_name, symbol, price, time, alert)
  SELECT n.user_name, n.symbol, t.price, t.time, t.price > n.alert_above
  FROM NEW n JOIN (SELECT symbol, price, time FROM trades LATEST ON time PARTITION BY symbol) t ON t.symbol = n.symbol
  ON CONFLICT (user_name, symbol) DO UPDATE SET price = EXCLUDED.price, time = EXCLUDED.time, alert = EXCLUDED.alert;

-- A share removed from a watch list: its result goes too.
CREATE TRIGGER quotes_on_unfollow AFTER DELETE ON watchlist EXECUTE
  DELETE FROM user_quotes WHERE (user_name, symbol) IN (SELECT user_name, symbol FROM OLD);
```

```sql
INSERT INTO watchlist VALUES ('ram', 'CITY', 520), ('ram', 'NABIL', 1300), ('sita', 'CITY', 500);
INSERT INTO trades VALUES ('2026-09-24T10:00:00Z', 'CITY', 498.0), ('2026-09-24T10:00:01Z', 'NABIL', 1250.0),
  ('2026-09-24T10:00:02Z', 'HIDCL', 180.0);
INSERT INTO trades VALUES ('2026-09-24T10:05:00Z', 'CITY', 505.5), ('2026-09-24T10:06:00Z', 'CITY', 512.0);
INSERT INTO watchlist VALUES ('sita', 'HIDCL', 175);
DELETE FROM watchlist WHERE user_name = 'ram' AND symbol = 'NABIL';

SELECT symbol, price, time, alert FROM user_quotes WHERE user_name = 'ram' ORDER BY symbol;
SELECT user_name, symbol, price FROM user_quotes WHERE alert ORDER BY user_name, symbol;
```

Result:

`INSERT INTO watchlist VALUES ('ram', 'CITY', 520), ('ram', 'NABIL', 1300), ('sita', 'CITY', 500)`

```text
3 row(s) inserted
```

`INSERT INTO trades VALUES ('2026-09-24T10:00:00Z', 'CITY', 498.0), ('2026-09-24T10:00:01Z', 'NABIL',`

```text
3 row(s) inserted
```

`INSERT INTO trades VALUES ('2026-09-24T10:05:00Z', 'CITY', 505.5), ('2026-09-24T10:06:00Z', 'CITY', `

```text
2 row(s) inserted
```

`INSERT INTO watchlist VALUES ('sita', 'HIDCL', 175)`

```text
1 row(s) inserted
```

`DELETE FROM watchlist WHERE user_name = 'ram' AND symbol = 'NABIL'`

```text
1 row(s) deleted
```

`SELECT symbol, price, time, alert FROM user_quotes WHERE user_name = 'ram' ORDER BY symbol`

| symbol (SYMBOL) | price (DOUBLE) | time (TIMESTAMP) | alert (BOOL) |
|---|---|---|---|
| CITY | 512 | 2026-09-24T10:06:00.000Z | false |

(1 row)

`SELECT user_name, symbol, price FROM user_quotes WHERE alert ORDER BY user_name, symbol`

| user_name (STRING) | symbol (SYMBOL) | price (DOUBLE) |
|---|---|---|
| sita | CITY | 512 |
| sita | HIDCL | 180 |

(2 rows)

- **Notes:**
  - A change of `alert_above` needs one more trigger (`AFTER UPDATE ON watchlist`) in the same way, or the app updates `user_quotes` itself.
  - For a feed that writes thousands of trades a second, make `quotes_on_trade` [DEFERRED](#deferred): loads stay fast, and the results follow a moment later.

<a id="speed"></a>

## Triggers and load speed

Syntax:

```sql
CREATE TRIGGER name AFTER INSERT ON table DEFERRED EXECUTE ...   -- for a table that is loaded in bulk
```

A normal (immediate) `INSERT` trigger must see the rows of each write in `NEW`, inside the write. So writes into **its own table** take the slower row-by-row way.
Writes into **other tables** are not slowed by it.

| Table | How a load into it is written |
|---|---|
| no `INSERT` trigger | the fast way: `POST /write` and bulk loads write the rows as sorted blocks |
| only [DEFERRED](triggers.md#deferred) triggers | the fast way too. The trigger runs after the commit. |
| a `BEFORE INSERT` or `AFTER INSERT` trigger that is not deferred | row by row, with the trigger inside the write. In a test with 20,000 rows: about 32 ms instead of 7 ms. |
| another table has an immediate trigger | the fast way (since 2026-09-23; before, one trigger anywhere in the database slowed every load) |

- **Notes:**
  - For a table that is loaded in bulk (a live feed, a floor sheet, a day of candles), make its triggers `DEFERRED`.
  - A disabled trigger does not count. `UPDATE` and `DELETE` triggers do not change how rows are inserted.
  - One `POST /write` with rows for several tables goes the slow way as a whole when one of its tables has an immediate `INSERT` trigger.
  - A trigger locks the tables its body uses, for as long as it runs (see [one writer per table](transactions.md#one-writer)). A body with [`EXECUTE`](procedure-language.md#execute) (dynamic SQL) locks **every** table of the database, because KarelaDB cannot know the tables before the text is made.

<a id="errors"></a>

## Errors in a trigger

Syntax:

```sql
statement -> BEFORE triggers -> change -> AFTER triggers   -- one transaction: all or nothing
```

A trigger runs in the same transaction as the statement that fired it.
If the trigger fails (an error, or `RAISE`), **the statement is undone too**, with everything the trigger changed before the error.
Inside `BEGIN ... COMMIT`, the whole transaction is rolled back.

- **Returns:** the error `trigger 'name', line N: <message>`.
- **Notes:**
  - A trigger may change a table that has triggers. At most **16 levels**: a trigger that fires itself again and again stops with `triggers are nested too deeply`.
  - Tables and columns in the body are checked when the trigger runs, not when it is created. A trigger that uses a dropped table or procedure makes every change of its table fail. Use `DISABLE TRIGGER` or `DROP TRIGGER`.

<a id="time-limit"></a>

## How long a trigger may run

Syntax:

```sql
statement time = the statement + its triggers      -- one statement timeout for all of it
error:  trigger <name>: statement timeout (<N> s)
```

A trigger's work counts toward the [statement timeout](protection.md#statement-timeout) of the statement that fired it, like a `CALL`.
The rule is the same for `INSERT`, `UPDATE` and `DELETE` over `/exec`, for [POST /write](line-protocol.md) and for [POST /imp](http-import.md).

| What | Detail |
|---|---|
| The limit | the server's `--statement-timeout` (60 s by default), or the request's `X-KDB-Statement-Timeout` header |
| Longer | only an admin (or the server token) may raise it, for example `X-KDB-Statement-Timeout: 10min` on a loader's `/write`. Other users can only make it shorter. |
| When it runs out | the trigger stops, and the **whole statement is undone**: the rows that fired it and everything the trigger wrote |
| Error | `trigger <name>: statement timeout (<N> s)`, HTTP status 408. It names the trigger, so a loader never takes it for a bad line of its data. |
| Running now | `GET /api/stats` lists it under `running` as `trigger <name> on <table>` |

- **Notes:**
  - A trigger that builds a day of candles may need several seconds, more on a big or cold day. Make it [DEFERRED](triggers.md#deferred): the load then returns at once and the work runs after it. Or move the work to a [timer](timers.md).
  - Readers never see a trigger's changes before it commits (in every table it wrote, all at once). Whether they **wait** for a long trigger depends on the server: with [reader yield](transactions.md#reader-yield) on, other sessions' `SELECT`s answer at once with the rows as the last commit left them; with it off (`kareladb serve --reader-yield off`), they wait until the trigger's statement ends.

**Command line: The refused INSERT wrote nothing** (shows an error)

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL DEFAULT 0);
CREATE TABLE audit_log (id LONG PRIMARY KEY AUTO, detail STRING);
CREATE TRIGGER log_accounts AFTER INSERT ON accounts EXECUTE BEGIN
  INSERT INTO audit_log (detail) VALUES ('accounts added');
  IF EXISTS (SELECT 1 FROM NEW WHERE balance > 100000) THEN
    RAISE 'a new account cannot start with more than 1 lakh';
  END IF;
END;
```

```bash
kareladb sql market "INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 500000)"
kareladb sql market "SELECT (SELECT count(*) FROM accounts) AS accounts, (SELECT count(*) FROM audit_log) AS audit_rows"
```

Output:

`> kareladb sql market "INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 500000)"`

```text
error: trigger 'log_accounts', line 4: a new account cannot start with more than 1 lakh
```

exit code 1

`> kareladb sql market "SELECT (SELECT count(*) FROM accounts) AS accounts, (SELECT count(*) FROM audit_log) AS audit_rows"`

```text
accounts | audit_rows
---------+-----------
       0 |          0
(1 row, 0.4 ms)
```

**Example: A trigger that fires itself** (shows an error)

```sql
CREATE TABLE t (id INT PRIMARY KEY);
CREATE TRIGGER again AFTER INSERT ON t EXECUTE BEGIN
  FOR r IN (SELECT id FROM NEW) DO
    INSERT INTO t VALUES (r.id + 1);
  END FOR;
END;
INSERT INTO t VALUES (1);
```

Result:

`CREATE TABLE t (`

```text
table 't' created
```

`CREATE TRIGGER again AFTER INSERT ON t EXECUTE BEGIN`

```text
trigger 'again' created on table 't'
```

Error: `trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: trigger 'again', line 3: triggers are nested too deeply (more than 16 levels): trigger 'again' on table 't' was fired by a change made by a trigger, again and again`

<a id="deferred"></a>

## Deferred triggers

Syntax:

```sql
CREATE [OR REPLACE] TRIGGER name AFTER INSERT ON table DEFERRED [TIMEOUT 600s]
  EXECUTE {CALL procedure(...) | INSERT ... | BEGIN statement; ... END}
```

A normal trigger runs **inside** the insert: the loader waits for it, the tables it uses stay locked the whole time, and the rows of its table are written [row by row](triggers.md#speed).
A **deferred** trigger runs **after** the insert is committed. The write returns at once; the trigger's work waits in a queue and runs in the background.

Use it when a trigger is slow, or when its table is loaded in bulk: a trigger that builds many summary tables from a day of trades.

| Rule | What it means |
|---|---|
| NEW | `NEW` holds exactly the rows that one write committed. They are kept with the job, so a later write cannot change them. |
| One job per write | Every `POST /write`, `POST /imp`, `INSERT` or `COMMIT` that inserts rows makes one **job** for each deferred trigger of the table. |
| Order | Jobs of a trigger run one at a time, in the order their writes committed. |
| Failure | A job that fails **runs again by itself**: 3 more tries, 1 s, 2 s and 4 s later (`kareladb serve --trigger-retries`). The jobs behind it wait. When every try failed, it **stops its trigger's queue**. The job and its rows stay. Nothing is ever skipped by itself. See [recovery](triggers.md#deferred-recovery). |
| Noticed | Each failed try and each stopped queue is an `error` event in the activity log, counts in `GET /api/stats`, and can be sent to a [webhook](triggers.md#deferred-alerts). |
| Queue limit | At most 10,000 jobs wait in one database (`kareladb serve --max-trigger-jobs`). A write past that is refused with `503` and the reason, usually a stopped queue. Nothing of it is stored. |
| All or nothing | A job's work and the record "job done" commit together. After a crash in the middle of a job, it runs again from the start. Its work is applied exactly once. |
| Restart | Waiting jobs and their rows survive a restart. A stopped queue is still stopped after the restart. |
| TIMEOUT | How long one job may run. Without it, the server's statement timeout. A job that runs out fails, and its queue stops. |

- **Returns:** `trigger 'name' created on table 'table' (deferred: ...)`.
- **Notes:**
  - Only `AFTER INSERT` triggers can be deferred.
  - The job reads the tables as they are when it runs. Other writes may have come in since.
  - A table with only deferred triggers keeps the fast write path: a new day of 250,000 rows is written in about 0.2 s.
  - A job is a writer like any other: it locks the tables its body reads and changes (not the trigger's own table, unless the body reads it by name). The next load into the trigger's table does not wait for a running job. A write (`/write`, `/imp` or SQL) into a table the job uses waits until the job commits, at most 5 seconds, then gets `table 'x' is busy: a deferred trigger job has held it for ...`.
  - A schema change (`CREATE`, `ALTER`, `DROP`, `TRUNCATE`) waits for the running job.
  - Readers see the tables as last committed. With [reader yield](transactions.md#reader-yield) on they read at once; with it off they wait for the job to end.
  - A deferred trigger cannot be dropped, or made normal again, while it has jobs in its queue. Wait for them, or skip them.
  - The activity log gets one `trigger` event per job, with its time and error.

**Example: A deferred trigger that builds daily totals**

```sql
CREATE TABLE trades (date TIMESTAMP, id LONG, symbol SYMBOL, quantity LONG, rate DOUBLE)
  TIMESERIES(date) PARTITION BY DAY SORT BY (symbol, id) DEDUP KEY (date, id);
CREATE TABLE daily_totals (date TIMESTAMP, symbol SYMBOL, quantity LONG, amount DOUBLE)
  TIMESERIES(date) PARTITION BY DAY DEDUP KEY (date, symbol);
CREATE TRIGGER build_totals AFTER INSERT ON trades DEFERRED TIMEOUT 10min EXECUTE
  INSERT OR REPLACE INTO daily_totals
  SELECT date, symbol, sum(quantity), sum(quantity * rate) FROM NEW GROUP BY date, symbol;
SHOW TRIGGERS;
```

Result:

`CREATE TABLE trades (`

```text
table 'trades' created
```

`CREATE TABLE daily_totals (`

```text
table 'daily_totals' created
```

`CREATE TRIGGER build_totals AFTER INSERT ON trades DEFERRED TIMEOUT '600000ms' EXECUTE INSERT OR REP`

```text
trigger 'build_totals' created on table 'trades' (deferred: it runs after each INSERT commits, one job at a time)
```

`SHOW TRIGGERS`

| name (STRING) | table (STRING) | timing (STRING) | event (STRING) | enabled (BOOL) | definition (STRING) |
|---|---|---|---|---|---|
| build_totals | trades | AFTER (deferred) | INSERT | true | CREATE TRIGGER build_totals AFTER INSERT ON trades DEFERRED TIMEOUT '600000ms' EXECUTE INSERT OR REPLACE INTO daily_totals SELECT date, symbol, sum(quantity), sum(quantity * rate) FROM NEW GROUP BY... |

(1 row)

**Example: Only AFTER INSERT can be deferred** (shows an error)

```sql
CREATE TABLE trades (date TIMESTAMP, id LONG) TIMESERIES(date) PARTITION BY DAY DEDUP KEY (date, id);
CREATE TABLE seen (id LONG);
CREATE TRIGGER t AFTER UPDATE ON trades DEFERRED EXECUTE INSERT INTO seen SELECT id FROM NEW;
```

Result:

`CREATE TABLE trades (`

```text
table 'trades' created
```

`CREATE TABLE seen (`

```text
table 'seen' created
```

Error: `trigger 't': only AFTER INSERT triggers can be DEFERRED (a deferred trigger runs after the inserted rows are committed)`

<a id="deferred-queue"></a>

### Watch and wait for the queue

Syntax:

```sql
GET  /api/trigger-queue?db=<name>[&trigger=<name>][&wait=30s]
POST /write?db=<name>&precision=s&wait=trigger[&wait_timeout=10min]
```

| Way | What you get |
|---|---|
| `GET /api/trigger-queue` | per trigger: `pending` jobs, `oldest_pending_age_ms` (the lag), `running_job`, `failed_job` (id, error, time), `last_done_job`. And a list `jobs` of every job not finished yet. `wait=30s` holds the answer until they finished or stand still. |
| `POST /write?...&wait=trigger` | the write answers only after its own jobs ended: `{"rows":..., "jobs":[{"id","status","took_ms","error",...}], "done":true}`. The rows are committed either way. |
| `GET /api/stats` | `trigger_queues` for every database. The console's Monitor shows them. |

Job status: `done`, `skipped`, `failed`, `running`, `waiting`, `retrying` (it failed and runs again by itself at `retry_at_ms`), or `blocked` (waiting behind a failed job).

Each queue also counts, since the database opened: `failures` (jobs that stopped the queue), `retries` (failed tries that ran again) and `refused_writes` (writes refused because the queue was full).

The queue fields are **inside `queues[]`**, one entry per trigger - not at the top of the answer:

```json
{"queues": [{"trigger": "fs_after_insert", "table": "floorsheet", "enabled": true,
             "pending": 1, "oldest_pending_age_ms": 850,
             "running_job": {"id": 3, "status": "running", ...}, "failed_job": null,
             "last_done_job": 2}],
 "jobs": [{"id": 3, "status": "running", ...}]}
```

A script that loads data and must wait until the trigger caught up. A job is finished when `last_done_job` is at least its id; the queue is idle when `pending` is 0 and `running_job` is `null`. Stop on `failed_job`, or the loop waits forever behind it:

```bash
# wait until the trigger fs_after_insert has no job left (up to 30 s per call)
while :; do
  q=$(curl -s -H "Authorization: Bearer $KARELADB_TOKEN" \
      "$KARELADB_URL/api/trigger-queue?db=mydb&trigger=fs_after_insert&wait=30s")
  echo "$q" | jq -e '.queues[0].failed_job != null' >/dev/null && { echo "job failed: $q"; exit 1; }
  echo "$q" | jq -e '.queues[0].pending == 0 and .queues[0].running_job == null' >/dev/null && break
done
```

- **Notes:**
  - Easier still: send the load with `&wait=trigger`, and it answers after its own jobs ended.
  - A `/write` without `wait=trigger` answers `204` with no body, so it gives no job id. Wait for the queue to be idle, as above, or read `last_done_job` before the load and wait until it grows.

<a id="deferred-recovery"></a>

### When a job fails: RETRY and SKIP

Syntax:

```sql
RETRY TRIGGER QUEUE trigger_name
SKIP TRIGGER JOB trigger_name job_id
```

| Statement | What it does |
|---|---|
| `RETRY TRIGGER QUEUE name` | runs the failed job again, then the jobs behind it. Fix the cause first (the data, or the trigger with `CREATE OR REPLACE TRIGGER`). |
| `SKIP TRIGGER JOB name id` | removes one job without running it. Its rows stay in the table, but the trigger never sees them. The next job runs. |

- **Notes:**
  - Both need the admin role. They cannot be used inside `BEGIN ... COMMIT`.
  - They lock no table. A long load, `CALL` or trigger job in the database does not make them wait or fail with `503 busy`.
  - `SKIP TRIGGER JOB` refuses the job that is running right now. Only a job that waits or has failed can be skipped.
  - Find the job id in `GET /api/trigger-queue`.
  - `RETRY TRIGGER QUEUE` on a job that waits for its next automatic try runs it now.

<a id="deferred-alerts"></a>

### Hearing about a failed job

The write that made a job succeeded, so nobody is told when the job fails. KarelaDB tells you in three places:

| Where | What |
|---|---|
| Activity log (console) | an `error` event for each failed try and for the job that stopped its queue |
| `GET /api/stats` | `alerts`: `trigger_jobs_failed`, `trigger_job_retries`, the `last` message, and how the webhook went (`webhook_sent`, `webhook_failed`, `webhook_last_error`) |
| A webhook | `kareladb serve --alert-webhook http://10.0.0.5:8080/kdb-alerts` (or `KARELADB_ALERT_WEBHOOK`, or `alert_webhook` in `kareladb.conf`) |

The webhook gets one JSON `POST` per event:

```json
{"source": "kdb", "event": "trigger_job_failed", "database": "market",
 "trigger": "build_totals", "table": "trades", "job": 42, "rows": 1500, "retries": 3,
 "error": "...", "time_ms": 1790000000000,
 "text": "KarelaDB market: trigger build_totals on trades, job 42 failed and stopped its queue ..."}
```

`event` is `trigger_job_retrying` for a try that will run again, `trigger_job_failed` when the queue stopped.

- **Notes:**
  - Plain `http://` to an IPv4 address or `localhost`. KarelaDB does not look up host names and sends no TLS. For Slack or Teams (https), point it at a small relay on your network.
  - Sending never slows the database: a background thread sends, with 5 s per try. When the receiver is down, the newest 100 wait and older ones are dropped (`webhook_dropped`).

<a id="enable-disable"></a>

## ALTER TABLE ... ENABLE TRIGGER, DISABLE TRIGGER

Syntax:

```sql
ALTER TABLE table DISABLE TRIGGER name
ALTER TABLE table ENABLE TRIGGER name
```

Turns a trigger off for a while, and on again. A disabled trigger stays saved but does not run.

- **Returns:** `trigger 'name' disabled` or `trigger 'name' enabled`.
- **Notes:**
  - The table must be the trigger's own table.
  - Use it for a big load of old data that the trigger must not see, then enable it again. Changes made while it was off are **not** replayed.
  - A new trigger is enabled. `SHOW TRIGGERS` shows the state in the column `enabled`. The state is kept after a restart.

**Example: Load old posts without counting them, then count again**

```sql
CREATE TABLE topics (id INT PRIMARY KEY, posts LONG NOT NULL DEFAULT 0);
CREATE TABLE posts (id LONG PRIMARY KEY, topic_id INT NOT NULL);
INSERT INTO topics (id) VALUES (1);
CREATE TRIGGER count_posts AFTER INSERT ON posts EXECUTE BEGIN
  DECLARE added LONG DEFAULT (SELECT count(*) FROM NEW);
  UPDATE topics SET posts = posts + added WHERE id = 1;
END;

ALTER TABLE posts DISABLE TRIGGER count_posts;
INSERT INTO posts VALUES (1, 1), (2, 1), (3, 1);
ALTER TABLE posts ENABLE TRIGGER count_posts;
INSERT INTO posts VALUES (4, 1);
SELECT id, posts FROM topics;
```

Result:

`CREATE TABLE topics (`

```text
table 'topics' created
```

`CREATE TABLE posts (`

```text
table 'posts' created
```

`INSERT INTO topics (id) VALUES (1)`

```text
1 row(s) inserted
```

`CREATE TRIGGER count_posts AFTER INSERT ON posts EXECUTE BEGIN`

```text
trigger 'count_posts' created on table 'posts'
```

`ALTER TABLE posts DISABLE TRIGGER count_posts`

```text
trigger 'count_posts' disabled
```

`INSERT INTO posts VALUES (1, 1), (2, 1), (3, 1)`

```text
3 row(s) inserted
```

`ALTER TABLE posts ENABLE TRIGGER count_posts`

```text
trigger 'count_posts' enabled
```

`INSERT INTO posts VALUES (4, 1)`

```text
1 row(s) inserted
```

`SELECT id, posts FROM topics`

| id (INT) | posts (LONG) |
|---|---|
| 1 | 1 |

(1 row)

**Example: The trigger is on another table** (shows an error)

```sql
CREATE TABLE topics (id INT PRIMARY KEY);
CREATE TABLE posts (id LONG PRIMARY KEY);
CREATE TRIGGER count_posts AFTER INSERT ON posts EXECUTE BEGIN PRINT 'new post'; END;
ALTER TABLE topics DISABLE TRIGGER count_posts;
```

Result:

`CREATE TABLE topics (`

```text
table 'topics' created
```

`CREATE TABLE posts (`

```text
table 'posts' created
```

`CREATE TRIGGER count_posts AFTER INSERT ON posts EXECUTE BEGIN`

```text
trigger 'count_posts' created on table 'posts'
```

Error: `trigger 'count_posts' is on table 'posts', not on 'topics'`

<a id="drop-trigger"></a>

## DROP TRIGGER

Syntax:

```sql
DROP TRIGGER [IF EXISTS] name
```

Removes a trigger. The table is not changed.

- **Returns:** `trigger 'name' dropped`. With `IF EXISTS`, a name that does not exist gives the message `trigger 'name' does not exist` and no error.
- **Notes:** you do not name the table: trigger names are unique in the database. `DROP TRIGGER` cannot be used inside `BEGIN ... COMMIT`.

**Example**

```sql
CREATE TABLE posts (id LONG PRIMARY KEY);
CREATE TRIGGER hello AFTER INSERT ON posts EXECUTE BEGIN PRINT 'new post'; END;
DROP TRIGGER hello;
DROP TRIGGER IF EXISTS hello;
INSERT INTO posts VALUES (1);
```

Result:

`CREATE TABLE posts (`

```text
table 'posts' created
```

`CREATE TRIGGER hello AFTER INSERT ON posts EXECUTE BEGIN`

```text
trigger 'hello' created on table 'posts'
```

`DROP TRIGGER hello`

```text
trigger 'hello' dropped
```

`DROP TRIGGER IF EXISTS hello`

```text
trigger 'hello' does not exist
```

`INSERT INTO posts VALUES (1)`

```text
1 row(s) inserted
```

**Example: A name that does not exist** (shows an error)

```sql
DROP TRIGGER hello;
```

Result:

Error: `trigger 'hello' does not exist`

<a id="show-triggers"></a>

## SHOW TRIGGERS

Syntax:

```sql
SHOW TRIGGERS
```

Lists all triggers of the database, in name order.

| Column | Meaning |
|---|---|
| `name` | the trigger name |
| `table` | the table it watches |
| `timing` | `BEFORE`, `AFTER`, or `AFTER (deferred)` for a [deferred trigger](triggers.md#deferred) |
| `event` | `INSERT`, `UPDATE` or `DELETE` |
| `enabled` | `true`, or `false` after `DISABLE TRIGGER` |
| `definition` | the whole `CREATE TRIGGER` statement |

**Example**

```sql
CREATE TABLE posts (id LONG PRIMARY KEY, topic_id INT);
CREATE TABLE audit_log (detail STRING);
CREATE TRIGGER log_post AFTER INSERT ON posts EXECUTE INSERT INTO audit_log VALUES ('post added');
CREATE TRIGGER check_post BEFORE INSERT ON posts EXECUTE BEGIN
  IF EXISTS (SELECT 1 FROM NEW WHERE topic_id IS NULL) THEN RAISE 'a post needs a topic'; END IF;
END;
ALTER TABLE posts DISABLE TRIGGER log_post;
SHOW TRIGGERS;
```

Result:

`CREATE TABLE posts (`

```text
table 'posts' created
```

`CREATE TABLE audit_log (`

```text
table 'audit_log' created
```

`CREATE TRIGGER log_post AFTER INSERT ON posts EXECUTE INSERT INTO audit_log VALUES ('post added')`

```text
trigger 'log_post' created on table 'posts'
```

`CREATE TRIGGER check_post BEFORE INSERT ON posts EXECUTE BEGIN`

```text
trigger 'check_post' created on table 'posts'
```

`ALTER TABLE posts DISABLE TRIGGER log_post`

```text
trigger 'log_post' disabled
```

`SHOW TRIGGERS`

| name (STRING) | table (STRING) | timing (STRING) | event (STRING) | enabled (BOOL) | definition (STRING) |
|---|---|---|---|---|---|
| check_post | posts | BEFORE | INSERT | true | CREATE TRIGGER check_post BEFORE INSERT ON posts EXECUTE BEGIN   IF EXISTS (SELECT 1 FROM NEW WHERE topic_id IS NULL) THEN     RAISE 'a post needs a topic';   END IF; END |
| log_post | posts | AFTER | INSERT | false | CREATE TRIGGER log_post AFTER INSERT ON posts EXECUTE INSERT INTO audit_log VALUES ('post added') |

(2 rows)

<a id="drop-table"></a>

## DROP TABLE and RENAME TABLE with triggers

Syntax:

```sql
DROP TRIGGER name;  -- first, for every trigger of the table
DROP TABLE table;
```

A table that has triggers cannot be dropped or renamed. This keeps triggers from pointing at a table that is gone.
Drop its triggers first (also the disabled ones).

- **Returns:** the error `table 'name' has triggers (...); DROP TRIGGER them first`.
- **Notes:** triggers of **other** tables that write into this table are not checked; they fail when they run.

**Example: DROP TABLE is refused** (shows an error)

```sql
CREATE TABLE posts (id LONG PRIMARY KEY);
CREATE TRIGGER count_posts AFTER INSERT ON posts EXECUTE BEGIN PRINT 'new post'; END;
DROP TABLE posts;
```

Result:

`CREATE TABLE posts (`

```text
table 'posts' created
```

`CREATE TRIGGER count_posts AFTER INSERT ON posts EXECUTE BEGIN`

```text
trigger 'count_posts' created on table 'posts'
```

Error: `table 'posts' has triggers (count_posts); DROP TRIGGER them first`

**Example: Drop the trigger, then the table**

```sql
CREATE TABLE posts (id LONG PRIMARY KEY);
CREATE TRIGGER count_posts AFTER INSERT ON posts EXECUTE BEGIN PRINT 'new post'; END;
DROP TRIGGER count_posts;
DROP TABLE posts;
```

Result:

`CREATE TABLE posts (`

```text
table 'posts' created
```

`CREATE TRIGGER count_posts AFTER INSERT ON posts EXECUTE BEGIN`

```text
trigger 'count_posts' created on table 'posts'
```

`DROP TRIGGER count_posts`

```text
trigger 'count_posts' dropped
```

`DROP TABLE posts`

```text
table 'posts' dropped; UNDROP TABLE posts brings it back within 7 days
```

**Example: RENAME TABLE is refused too** (shows an error)

```sql
CREATE TABLE posts (id LONG PRIMARY KEY);
CREATE TRIGGER count_posts AFTER INSERT ON posts EXECUTE BEGIN PRINT 'new post'; END;
RENAME TABLE posts TO forum_posts;
```

Result:

`CREATE TABLE posts (`

```text
table 'posts' created
```

`CREATE TRIGGER count_posts AFTER INSERT ON posts EXECUTE BEGIN`

```text
trigger 'count_posts' created on table 'posts'
```

Error: `table 'posts' has triggers (count_posts); DROP TRIGGER them first`
