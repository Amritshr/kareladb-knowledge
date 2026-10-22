# Transactions

> BEGIN, COMMIT and ROLLBACK: save many changes together, or none of them.

- Category: Transactions
- Keywords: transaction, TRANSACTION, WORK, BEGIN TRANSACTION, BEGIN WORK, COMMIT WORK, ROLLBACK WORK, START, atomic, all or nothing, rollback, undo, FOR UPDATE, SELECT FOR UPDATE, SKIP LOCKED, NOWAIT, job queue, --per-table-reads, KDB\_PER\_TABLE\_READS, SELECT 1 waits, readers wait, checkpoint, BEGIN without COMMIT, cannot be used inside a transaction, database is busy, table is busy, deadlock, duplicate key while busy, taken key, table lock, --reader-yield, KDB\_READER\_YIELD, reader yield, --snapshot-reads, KDB\_SNAPSHOT\_READS, snapshot, snapshot reads, MVCC, writers at the same time, group commit, lock, lock\_timeout\_ms, lock\_timeout, SET lock\_timeout, --lock-timeout, KDB\_LOCK\_TIMEOUT, X-KDB-Lock-Timeout, 55P03, idle\_transaction\_timeout\_ms, idle\_in\_transaction\_session\_timeout, --idle-in-transaction-timeout, KDB\_IDLE\_IN\_TRANSACTION\_TIMEOUT, session, double entry, ledger, accounting, SAVEPOINT, RELEASE SAVEPOINT, ROLLBACK TO SAVEPOINT, ROLLBACK TO, savepoints, 25P02, 3B001, isolation, isolation level, SERIALIZABLE, READ COMMITTED, SET TRANSACTION, BEGIN ISOLATION LEVEL, default\_transaction\_isolation, transaction\_isolation, 40001, serialization\_failure, 40P01, lost update, READ ONLY, BEGIN READ ONLY, read-only transaction, SET TRANSACTION READ ONLY, default\_transaction\_read\_only, transaction\_read\_only, 25006, READ WRITE, LOCK TABLE, LOCK, IN SHARE MODE, ACCESS EXCLUSIVE, lock modes, LOCK TABLE NOWAIT, pg\_locks, pg\_blocking\_pids, log\_lock\_waits, deadlock\_timeout, --log-lock-waits, KDB\_LOG\_LOCK\_WAITS, --deadlock-timeout, KDB\_DEADLOCK\_TIMEOUT, 25P01, who is blocking, lock waits, txn\_spill\_mb, --txn-spill-mb, KDB\_TXN\_SPILL\_MB, transaction too big for memory, txn\_spills, big transaction
- See also: [Stored procedures](procedures.md), [Triggers](triggers.md), [Cursors](cursors.md), [Sessions and cursors over HTTP](http-sessions-and-cursors.md), [kdb sql and kdb shell](cli-sql-and-shell.md), [Constraints](constraints.md), [15. Transactions and accounting](../tutorial/15-transactions-and-accounting.md)

A **transaction** is a group of changes that KDB saves **together, or not at all**. Nobody ever sees half of it.

Moving money is the classic case. A transfer is three changes: take money from one account, give it to the other, and write a ledger row (a row in the list of all transfers). If only the first change is saved, money is lost. Put them in a transaction.

- Start it with `BEGIN`. Save it with `COMMIT`. Undo it with `ROLLBACK`.
- When any statement in it fails, KDB undoes the whole transaction.
- KDB writes the changes to its log (the file where every change is saved first) only at `COMMIT`, in one write. After a crash or a power cut, a committed transaction is there completely, and an unfinished one is not there at all.

**Example: Accounting: a transfer between two accounts, then check the books**

Setup:

```sql
CREATE TABLE accounts (
  id INT PRIMARY KEY,
  owner STRING NOT NULL,
  opening DECIMAL(2) NOT NULL,
  balance DECIMAL(2) NOT NULL
);
CREATE TABLE ledger (
  id LONG PRIMARY KEY AUTO,
  from_account INT NOT NULL REFERENCES accounts(id),
  to_account INT NOT NULL REFERENCES accounts(id),
  amount DECIMAL(2) NOT NULL,
  note STRING,
  created TIMESTAMP DEFAULT now()
);
INSERT INTO accounts VALUES (1, 'Ram', 1000, 1000), (2, 'Sita', 0, 0), (3, 'Hari', 500, 500);
```

```sql
BEGIN;
UPDATE accounts SET balance = balance - 250.50 WHERE id = 1;
UPDATE accounts SET balance = balance + 250.50 WHERE id = 2;
INSERT INTO ledger (from_account, to_account, amount, note) VALUES (1, 2, 250.50, 'rent');
COMMIT;

-- Check the books: the total never changes, and every balance matches the ledger.
SELECT sum(opening) AS money_at_start, sum(balance) AS money_now FROM accounts;
SELECT a.id, a.owner, a.balance,
       a.opening + coalesce(i.total_in, 0) - coalesce(o.total_out, 0) AS from_ledger,
       a.balance = a.opening + coalesce(i.total_in, 0) - coalesce(o.total_out, 0) AS ok
FROM accounts a
LEFT JOIN (SELECT to_account, sum(amount) AS total_in FROM ledger GROUP BY to_account) i ON i.to_account = a.id
LEFT JOIN (SELECT from_account, sum(amount) AS total_out FROM ledger GROUP BY from_account) o ON o.from_account = a.id
ORDER BY a.id;
```

Result:

`BEGIN`

```text
transaction started
```

`UPDATE accounts SET balance = balance - 250.50 WHERE id = 1`

```text
1 row(s) updated
```

`UPDATE accounts SET balance = balance + 250.50 WHERE id = 2`

```text
1 row(s) updated
```

`INSERT INTO ledger (from_account, to_account, amount, note) VALUES (1, 2, 250.50, 'rent')`

```text
1 row(s) inserted
```

`COMMIT`

```text
transaction committed: 3 change(s) saved
```

`SELECT sum(opening) AS money_at_start, sum(balance) AS money_now FROM accounts`

| money_at_start (DECIMAL(2)) | money_now (DECIMAL(2)) |
|---|---|
| 1500.00 | 1500.00 |

(1 row)

`SELECT a.id, a.owner, a.balance, a.opening + coalesce(i.total_in, 0) - coalesce(o.total_out, 0) AS f`

| id (INT) | owner (STRING) | balance (DECIMAL(2)) | from_ledger (DECIMAL(2)) | ok (BOOL) |
|---|---|---|---|---|
| 1 | Ram | 749.50 | 749.50 | true |
| 2 | Sita | 250.50 | 250.50 | true |
| 3 | Hari | 500.00 | 500.00 | true |

(3 rows)

<a id="begin"></a>

## BEGIN

Syntax:

```sql
BEGIN
BEGIN TRANSACTION
BEGIN WORK
```

Starts a transaction. The statements after it are saved only at `COMMIT`.
`BEGIN`, `BEGIN TRANSACTION` and `BEGIN WORK` are the same.

- **Returns:** `transaction started`.
- **Notes:**
  - Inside the transaction you can use `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `CALL`, `SHOW ...`, `EXPLAIN`, `CHECK TABLE` and [cursors](cursors.md). Other statements are [not allowed](transactions.md#not-inside).
  - A `SELECT` inside the transaction sees its own changes. Other sessions do not see them until `COMMIT`.
  - Only one transaction can be open. A second `BEGIN` is an error, and the open transaction is rolled back.
  - While the transaction is open, **other writers of the same tables wait** (see [one writer per table](transactions.md#one-writer)). Keep transactions short.
  - `BEGIN` cannot be used inside a procedure or trigger body: a `CALL` is already one transaction.
  - `START TRANSACTION` (the MySQL spelling) is not supported. Write `BEGIN`.

**Example: The SELECT inside sees the change; after ROLLBACK it is gone** (sample data: sample)

```sql
BEGIN TRANSACTION;
UPDATE securities SET sector = 'Banks' WHERE symbol = 'CITY';
SELECT symbol, sector FROM securities WHERE symbol = 'CITY';
ROLLBACK;
SELECT symbol, sector FROM securities WHERE symbol = 'CITY';
```

Result:

`BEGIN`

```text
transaction started
```

`UPDATE securities SET sector = 'Banks' WHERE symbol = 'CITY'`

```text
1 row(s) updated
```

`SELECT symbol, sector FROM securities WHERE symbol = 'CITY'`

| symbol (SYMBOL) | sector (STRING) |
|---|---|
| CITY | Banks |

(1 row)

`ROLLBACK`

```text
transaction rolled back: 1 change(s) undone
```

`SELECT symbol, sector FROM securities WHERE symbol = 'CITY'`

| symbol (SYMBOL) | sector (STRING) |
|---|---|
| CITY | Banking |

(1 row)

**Example: BEGIN twice** (shows an error)

```sql
BEGIN;
BEGIN;
```

Result:

```text
transaction started
```

Error: `a transaction is already open; COMMIT or ROLLBACK it first (the transaction was rolled back)`

<a id="commit"></a>

## COMMIT

Syntax:

```sql
COMMIT
COMMIT TRANSACTION
COMMIT WORK
```

Saves every change of the open transaction, with one write to the log, and ends the transaction.

- **Returns:** `transaction committed: N change(s) saved`. N counts the log records (about one per changed row, plus the changes made by triggers and procedures).
- **Notes:**
  - When `COMMIT` returns OK, the changes are safe on disk, also after a crash or a power cut.
  - `COMMIT` without an open transaction is an error.
  - If the disk is full at `COMMIT`, it returns an error and nothing is saved.
  - In a session (`kdb shell`, HTTP session) whose transaction was already rolled back by an error, `COMMIT` fails with `COMMIT saved nothing`, so your app cannot think it was saved.

**Example: App sign-up: the user and the first audit row, together**

Setup:

```sql
CREATE TABLE app_users (id INT PRIMARY KEY, email STRING NOT NULL, created TIMESTAMP DEFAULT now());
CREATE TABLE audit_log (id LONG PRIMARY KEY AUTO, action STRING, detail STRING);
```

```sql
BEGIN WORK;
INSERT INTO app_users (id, email) VALUES (1, 'ram@example.com');
INSERT INTO audit_log (action, detail) VALUES ('sign-up', 'user 1: ram@example.com');
COMMIT WORK;
SELECT u.id, u.email, a.action FROM app_users u JOIN audit_log a ON a.detail = concat('user ', u.id, ': ', u.email);
```

Result:

`BEGIN`

```text
transaction started
```

`INSERT INTO app_users (id, email) VALUES (1, 'ram@example.com')`

```text
1 row(s) inserted
```

`INSERT INTO audit_log (action, detail) VALUES ('sign-up', 'user 1: ram@example.com')`

```text
1 row(s) inserted
```

`COMMIT`

```text
transaction committed: 2 change(s) saved
```

`SELECT u.id, u.email, a.action FROM app_users AS u JOIN audit_log AS a ON a.detail = concat('user ',`

| id (INT) | email (STRING) | action (STRING) |
|---|---|---|
| 1 | ram@example.com | sign-up |

(1 row)

**Example: COMMIT without BEGIN** (shows an error)

```sql
COMMIT;
```

Result:

Error: `COMMIT without BEGIN: no transaction is open`

<a id="rollback"></a>

## ROLLBACK

Syntax:

```sql
ROLLBACK
ROLLBACK TRANSACTION
ROLLBACK WORK
```

Undoes every change of the open transaction and ends it. The data is exactly as it was before `BEGIN`.

- **Returns:** `transaction rolled back: N change(s) undone`.
- **Notes:**
  - Changes made by triggers and by `CALL`s inside the transaction are undone too.
  - `ROLLBACK` without an open transaction is an error, except in a session whose transaction was already rolled back by an error: there `ROLLBACK` ends it and answers `transaction rolled back (it was already rolled back: ...)`.
  - Cursors declared inside the transaction stay open after `ROLLBACK` (their rows were read at `DECLARE`).

**Example: Forum: undo a post and its counter**

Setup:

```sql
CREATE TABLE topics (id INT PRIMARY KEY, posts LONG NOT NULL DEFAULT 0);
CREATE TABLE posts (id LONG PRIMARY KEY, topic_id INT NOT NULL, body STRING);
INSERT INTO topics (id) VALUES (1);
```

```sql
BEGIN;
INSERT INTO posts VALUES (1, 1, 'Buy CITY now!!!');
UPDATE topics SET posts = posts + 1 WHERE id = 1;
SELECT id, posts FROM topics;
ROLLBACK WORK;
SELECT id, posts FROM topics;
SELECT count(*) AS posts FROM posts;
```

Result:

`BEGIN`

```text
transaction started
```

`INSERT INTO posts VALUES (1, 1, 'Buy CITY now!!!')`

```text
1 row(s) inserted
```

`UPDATE topics SET posts = posts + 1 WHERE id = 1`

```text
1 row(s) updated
```

`SELECT id, posts FROM topics`

| id (INT) | posts (LONG) |
|---|---|
| 1 | 1 |

(1 row)

`ROLLBACK`

```text
transaction rolled back: 2 change(s) undone
```

`SELECT id, posts FROM topics`

| id (INT) | posts (LONG) |
|---|---|
| 1 | 0 |

(1 row)

`SELECT count(*) AS posts FROM posts`

| posts (LONG) |
|---|
| 0 |

(1 row)

**Example: ROLLBACK without BEGIN** (shows an error)

```sql
ROLLBACK;
```

Result:

Error: `ROLLBACK without BEGIN: no transaction is open`

<a id="savepoint"></a>

## SAVEPOINT

Syntax:

```sql
SAVEPOINT name
ROLLBACK [WORK | TRANSACTION] TO [SAVEPOINT] name
RELEASE [SAVEPOINT] name
```

A **savepoint** is a mark inside `BEGIN ... COMMIT`. `ROLLBACK TO` undoes only the work after the mark; the work before it stays, and the transaction goes on.

| Statement | What it does |
|---|---|
| `SAVEPOINT name` | marks the point. A name used again marks a new point: the newest one counts. |
| `ROLLBACK TO SAVEPOINT name` | undoes every change after the mark. The mark stays, so you can go back to it again. Later marks are gone. |
| `RELEASE SAVEPOINT name` | forgets the mark and every later one. The changes stay in the transaction. |

- **Returns:** `savepoint name set`, `rolled back to savepoint name: N row change(s) undone`, `savepoint name released`.
- **Errors:** outside `BEGIN ... COMMIT`: `SAVEPOINT can only be used inside BEGIN ... COMMIT` (PostgreSQL `25P01`). A name that is not there: `savepoint 'x' does not exist in this transaction` (`3B001`).
- **Notes:**
  - Nothing is saved until `COMMIT`. `ROLLBACK` (without `TO`) still undoes the whole transaction.
  - Rows for [DEFERRED triggers](triggers.md#deferred) that a `ROLLBACK TO` undid make no job.
  - Not inside a procedure or trigger body: the whole `CALL` is one transaction there.
  - Table locks stay until the transaction ends, also for tables only the undone part used (as in PostgreSQL).

**Example: Keep the order, undo the discount**

Setup:

```sql
CREATE TABLE orders (id INT PRIMARY KEY, symbol SYMBOL, qty LONG, price DECIMAL(2));
```

```sql
BEGIN;
INSERT INTO orders VALUES (1, 'CITY', 10, 510.00);
SAVEPOINT before_discount;
UPDATE orders SET price = price * 0.5 WHERE id = 1;
ROLLBACK TO SAVEPOINT before_discount;
INSERT INTO orders VALUES (2, 'COAST', 5, 385.00);
COMMIT;
SELECT * FROM orders ORDER BY id;
```

Result:

`BEGIN`

```text
transaction started
```

`INSERT INTO orders VALUES (1, 'CITY', 10, 510.00)`

```text
1 row(s) inserted
```

`SAVEPOINT before_discount`

```text
savepoint before_discount set
```

`UPDATE orders SET price = price * 0.5 WHERE id = 1`

```text
1 row(s) updated
```

`ROLLBACK TO SAVEPOINT before_discount`

```text
rolled back to savepoint before_discount: 1 row change(s) undone
```

`INSERT INTO orders VALUES (2, 'COAST', 5, 385.00)`

```text
1 row(s) inserted
```

`COMMIT`

```text
transaction committed: 2 change(s) saved
```

`SELECT * FROM orders ORDER BY id`

| id (INT) | symbol (SYMBOL) | qty (LONG) | price (DECIMAL(2)) |
|---|---|---|---|
| 1 | CITY | 10 | 510.00 |
| 2 | COAST | 5 | 385.00 |

(2 rows)

### After an error: ROLLBACK TO SAVEPOINT

In a session (an HTTP session, `kdb shell`, the PostgreSQL protocol), an error after a savepoint does **not** throw the transaction away. As in PostgreSQL:

1. The work after the newest savepoint is undone, and the transaction is **aborted**: every statement is refused with `current transaction is aborted ...` (`25P02`), except these.
2. `ROLLBACK TO SAVEPOINT name` goes back to that mark and makes the transaction usable again.
3. `ROLLBACK` ends it. `COMMIT` saves nothing and says so.

Without a savepoint, an error still rolls back the whole transaction ([when a statement fails](#errors)).

**HTTP: A duplicate key after a savepoint: go back and go on**

Setup:

```text
CREATE TABLE users (id INT PRIMARY KEY, email STRING UNIQUE);
INSERT INTO users VALUES (1, 'ram@example.np');
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; INSERT INTO users VALUES (2, 'sita@example.np'); SAVEPOINT before_hari
###
POST /exec
X-KDB-Session: {{session}}

INSERT INTO users VALUES (3, 'ram@example.np')
###
POST /exec
X-KDB-Session: {{session}}

ROLLBACK TO SAVEPOINT before_hari; INSERT INTO users VALUES (3, 'hari@example.np'); COMMIT
###
POST /exec

SELECT id, email FROM users ORDER BY id
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "ab37d2c476871d5a558032bd594384f8", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; INSERT INTO users VALUES (2, 'sita@example.np'); SAVEPOINT before_hari",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 13, "execute_us": 5}
    },
    {
      "statement": "INSERT INTO users VALUES (2, 'sita@example.np')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 13, "execute_us": 48}
    },
    {
      "statement": "SAVEPOINT before_hari",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "savepoint before_hari set",
      "timings": {"parse_us": 13, "execute_us": 6}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 39, "execute_us": 59}
}
```

`POST /exec`

HTTP 400 (application/json)

```text
{
  "query": "INSERT INTO users VALUES (3, 'ram@example.np')",
  "results": [],
  "saved": 0,
  "rolled_back": true,
  "error": "column 'email' must be unique: 'ram@example.np' is already used (the transaction is aborted; send ROLLBACK TO SAVEPOINT before_hari to go on from the savepoint, or ROLLBACK to end it)",
  "sqlstate": "23505",
  "table": "users",
  "constraint": "users_email_key",
  "column_name": "email"
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "ROLLBACK TO SAVEPOINT before_hari; INSERT INTO users VALUES (3, 'hari@example.np'); COMMIT",
  "results": [
    {
      "statement": "ROLLBACK TO SAVEPOINT before_hari",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "rolled back to savepoint before_hari: 0 row change(s) undone",
      "timings": {"parse_us": 6, "execute_us": 6}
    },
    {
      "statement": "INSERT INTO users VALUES (3, 'hari@example.np')",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 6, "execute_us": 31}
    },
    {
      "statement": "COMMIT",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction committed: 2 change(s) saved",
      "timings": {"parse_us": 6, "execute_us": 8}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 18, "execute_us": 45}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "SELECT id, email FROM users ORDER BY id",
  "results": [
    {
      "statement": "SELECT id, email FROM users ORDER BY id",
      "columns": [
        {"name": "id", "type": "INT"},
        {"name": "email", "type": "STRING"}
      ],
      "dataset": [
        [1, "ram@example.np"],
        [2, "sita@example.np"],
        [3, "hari@example.np"]
      ],
      "count": 3,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 38, "execute_us": 100}
    }
  ],
  "columns": [
    {"name": "id", "type": "INT"},
    {"name": "email", "type": "STRING"}
  ],
  "dataset": [
    [1, "ram@example.np"],
    [2, "sita@example.np"],
    [3, "hari@example.np"]
  ],
  "count": 3,
  "timings": {"parse_us": 38, "execute_us": 100}
}
```

<a id="atomic"></a>

## What is one transaction by itself

Syntax:

```sql
INSERT ... / UPDATE ... / DELETE ...    -- one statement: all its rows, or none
CALL procedure(...)                     -- the whole procedure
a statement that fires triggers         -- the statement and all its triggers
```

You do not always need `BEGIN`. These are each **one transaction by themselves**:

| What | All or nothing |
|---|---|
| one `INSERT`, `UPDATE` or `DELETE` | all its rows are written, or none (an `INSERT` of 1,000 rows with one bad row writes nothing) |
| one `CALL` | every change of the procedure, and of the procedures it calls (see [procedures](procedures.md#call-transaction)) |
| a statement that fires [triggers](triggers.md) | the statement and everything its triggers change |

- **Notes:**
  - Several statements **without** `BEGIN` are separate transactions. When the third one fails, the first two stay saved.
  - Inside `BEGIN ... COMMIT`, all of these become part of the bigger transaction.
  - At most **10 million changed rows** in one transaction (`DatabaseOptions::max_transaction_rows`). Until `COMMIT`, KDB keeps the old version of every changed row in memory.
  - A long transaction's log records go to a temporary file once they pass 64 MB (see [big transactions](#txn-spill)).

**Command line: One INSERT with a bad row writes no row** (shows an error)

Setup:

```text
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
INSERT INTO brokers VALUES (1, 'Keystone Securities');
```

```bash
kdb sql market "INSERT INTO brokers VALUES (34, 'Vision Securities'), (45, 'Imperial Securities'), (1, 'Keystone again')"
kdb sql market "SELECT id, name FROM brokers ORDER BY id"
```

Output:

`> kdb sql market "INSERT INTO brokers VALUES (34, 'Vision Securities'), (45, 'Imperial Securities'), (1, 'Keystone again')"`

```text
error: row 3: a row with id='1' already exists in 'brokers'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it
```

exit code 1

`> kdb sql market "SELECT id, name FROM brokers ORDER BY id"`

```text
id | name               
---+--------------------
 1 | Keystone Securities
(1 row, 0.3 ms)
```

**Command line: Without BEGIN, the statements before the error stay saved** (shows an error)

Setup:

```text
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
INSERT INTO brokers VALUES (1, 'Keystone Securities');
```

```bash
kdb sql market "INSERT INTO brokers VALUES (34, 'Vision Securities'); INSERT INTO brokers VALUES (1, 'Keystone again'); INSERT INTO brokers VALUES (45, 'Imperial Securities')"
kdb sql market "SELECT id, name FROM brokers ORDER BY id"
```

Output:

`> kdb sql market "INSERT INTO brokers VALUES (34, 'Vision Securities'); INSERT INTO brokers VALUES (1, 'Keystone again'); INSERT INTO brokers VALUES (45, 'Imperial Securities')"`

```text
1 row(s) inserted
error: a row with id='1' already exists in 'brokers'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it
```

exit code 1

`> kdb sql market "SELECT id, name FROM brokers ORDER BY id"`

```text
id | name               
---+--------------------
 1 | Keystone Securities
34 | Vision Securities  
(2 rows, 0.3 ms)
```

<a id="errors"></a>

## When a statement fails

Syntax:

```sql
BEGIN; statement; failing statement;   -- the whole transaction is rolled back here
```

When a statement inside `BEGIN ... COMMIT` fails (a duplicate key, `REFERENCES`, a `CHECK`, `RAISE` in a procedure or trigger, a typing error in a column name, ...), **KDB rolls back the whole transaction** at once.

- **Returns:** the error of the statement, with `(the transaction was rolled back)` at the end.
- **Notes:**
  - In one text (`kdb sql`, `POST /exec`, the web console), the statements after the error do not run.
  - In a session (`kdb shell`, an HTTP session, the PostgreSQL protocol) the session then accepts **only `ROLLBACK`** (or `COMMIT`, which fails). So your next statements cannot run outside the transaction by mistake.
  - With a [savepoint](#savepoint) set, the error undoes only the work after it, and `ROLLBACK TO SAVEPOINT` lets the transaction go on.
  - A syntax error is found before anything runs: then no statement of the text runs at all.

**Example: A transfer to an account that does not exist** (shows an error)

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
CREATE TABLE ledger (id LONG PRIMARY KEY AUTO, from_account INT NOT NULL REFERENCES accounts(id), to_account INT NOT NULL REFERENCES accounts(id), amount DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```sql
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 99;
INSERT INTO ledger (from_account, to_account, amount) VALUES (1, 99, 100);
COMMIT;
```

Result:

`BEGIN`

```text
transaction started
```

`UPDATE accounts SET balance = balance - 100 WHERE id = 1`

```text
1 row(s) updated
```

`UPDATE accounts SET balance = balance + 100 WHERE id = 99`

```text
0 row(s) updated
```

Error: `column 'to_account' = '99' has no matching row in accounts(id) (the transaction was rolled back)`

**Command line: Ram still has 1000.00 after that** (shows an error)

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
CREATE TABLE ledger (id LONG PRIMARY KEY AUTO, from_account INT NOT NULL REFERENCES accounts(id), to_account INT NOT NULL REFERENCES accounts(id), amount DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```bash
kdb sql market "BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1; INSERT INTO ledger (from_account, to_account, amount) VALUES (1, 99, 100); COMMIT"
kdb sql market "SELECT id, owner, balance FROM accounts ORDER BY id"
```

Output:

`> kdb sql market "BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1; INSERT INTO ledger (from_account, to_account, amount) VALUES (1, 99, 100); COMMIT"`

```text
transaction started

1 row(s) updated
error: column 'to_account' = '99' has no matching row in accounts(id) (the transaction was rolled back)
```

exit code 1

`> kdb sql market "SELECT id, owner, balance FROM accounts ORDER BY id"`

```text
id | owner | balance
---+-------+--------
 1 | Ram   | 1000.00
 2 | Sita  |    0.00
(2 rows, 0.4 ms)
```

<a id="no-commit"></a>

## A text that ends without COMMIT

Syntax:

```sql
BEGIN; statement; ...   <end of the text>   -- rolled back
```

`kdb sql`, `POST /exec` without a session, and the web console run one text at a time. A transaction cannot stay open after its text ends:
when the text ends without `COMMIT` or `ROLLBACK`, KDB **rolls it back** and returns an error.

- **Returns:** the error `BEGIN without COMMIT: the transaction was rolled back (end it with COMMIT to save the changes)`, after the results of the statements that ran.
- **Notes:** in `kdb shell`, in an HTTP session and over the PostgreSQL protocol, the transaction stays open until you send `COMMIT` or `ROLLBACK` (or leave). Leaving the shell or closing the session rolls it back.

**Example: Forgot the COMMIT** (shows an error)

Setup:

```sql
CREATE TABLE brokers (id INT PRIMARY KEY, name STRING NOT NULL);
```

```sql
BEGIN;
INSERT INTO brokers VALUES (58, 'Northgate Securities');
SELECT count(*) AS brokers FROM brokers;
```

Result:

`BEGIN`

```text
transaction started
```

`INSERT INTO brokers VALUES (58, 'Northgate Securities')`

```text
1 row(s) inserted
```

`SELECT count(*) AS brokers FROM brokers`

| brokers (LONG) |
|---|
| 1 |

(1 row)

Error: `BEGIN without COMMIT: the transaction was rolled back (end it with COMMIT to save the changes)`

<a id="not-inside"></a>

## Statements not allowed inside a transaction

Syntax:

```sql
CREATE ...  DROP ...  ALTER ...  RENAME ...  BACKUP DATABASE   -- before BEGIN or after COMMIT
```

Changes of the database structure cannot be undone like rows, so they are refused inside `BEGIN ... COMMIT`:
`CREATE` / `DROP` / `ALTER` of tables, views, indexes, functions, procedures and triggers, `RENAME TABLE`, and `BACKUP DATABASE`.
Run them before `BEGIN` or after `COMMIT`.

- **Returns:** the error `CREATE TABLE cannot be used inside a transaction; COMMIT or ROLLBACK first`. The open transaction is rolled back.
- **Notes:** the same statements are also not allowed inside a procedure or trigger body.

**Example: CREATE TABLE inside a transaction** (shows an error)

```sql
BEGIN;
CREATE TABLE archive (id INT PRIMARY KEY);
```

Result:

```text
transaction started
```

Error: `CREATE TABLE cannot be used inside a transaction; COMMIT or ROLLBACK first (the transaction was rolled back)`

**Example: CREATE PROCEDURE inside a transaction** (shows an error)

```sql
BEGIN;
CREATE PROCEDURE hello() AS BEGIN PRINT 'hello'; END;
```

Result:

```text
transaction started
```

Error: `CREATE PROCEDURE cannot be used inside a transaction; COMMIT or ROLLBACK first (the transaction was rolled back)`

<a id="for-update"></a>

## SELECT ... FOR UPDATE

Syntax:

```sql
SELECT columns FROM table WHERE ... FOR UPDATE
```

A `SELECT` that says: "I read these rows because I will change them". Write it at the start of a transaction, before the `UPDATE`s.

- **Returns:** the rows, like a normal `SELECT`.
- **Notes:**
  - On a table with a **primary key**, `FOR UPDATE` locks the **rows it returns**, until your transaction ends (`COMMIT`, `ROLLBACK`, the session closing, or the [idle limit](#idle-timeout)). The rest of the table stays free: other sessions read it, change other rows, and lock other rows with their own `FOR UPDATE`.
  - Another transaction that wants one of your locked rows:

    | It runs | What happens |
    |---|---|
    | `SELECT ... FOR UPDATE` | waits until your transaction ends (up to the [lock timeout](#lock-timeout)) |
    | `SELECT ... FOR UPDATE NOWAIT` | fails **at once**: `could not obtain lock on row in relation "jobs"` (HTTP 503, PostgreSQL `55P03`) |
    | `SELECT ... FOR UPDATE SKIP LOCKED` | leaves your rows out and returns the next free ones; `LIMIT` and `OFFSET` count after the skipping |
    | `UPDATE` or `DELETE` of the row | waits until your transaction ends (up to the lock timeout) |
    | a plain `SELECT` | reads it at once: row locks never stop a reader |

  - So a job queue works with many workers: each one runs `BEGIN; SELECT ... ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED`, does the job, then `UPDATE ...; COMMIT`, and no two workers get the same job.
  - Two transactions that each wait for a row the other one locked get `deadlock: ...` at once (PostgreSQL `40P01`) instead of both waiting. Roll back and try again.
  - A row your transaction **changed** (`UPDATE`, `DELETE`, `INSERT`) is still locked with its whole table until `COMMIT`, as every change is. Meanwhile:

    | Another session runs | What happens |
    |---|---|
    | `SELECT ... FOR UPDATE SKIP LOCKED` inside its own `BEGIN` | waits a moment (50 ms) and then returns **no rows** |
    | `SELECT ... FOR UPDATE SKIP LOCKED` without `BEGIN` | skips the rows you locked **and the rows you changed**, and returns the next free ones at once, as in PostgreSQL. It keeps no lock on them. Rows you added are not seen until `COMMIT`. |
    | `SELECT ... FOR UPDATE NOWAIT` | fails at once with `table 'x' is busy` |

    So in a job worker, do the work first and send the `UPDATE` just before `COMMIT`: then the jobs table is held only for a few milliseconds. A worker that marks its job `running` early and then works on it makes the queue look empty to the others until it commits.
  - `kdb serve --skip-locked-beside on` (off by default) makes `SKIP LOCKED` inside `BEGIN` return the free rows too, and lock them. The catch, until a change stops holding the whole table: the row you got is not free for your `UPDATE`. That `UPDATE` waits for the other transaction's `COMMIT`, and fails with `40001` after the [lock timeout](#lock-timeout) (5 seconds unless set) when that transaction stays open longer. If the other transaction then changes that row too, one of the two gets `deadlock: ...` at once. Turn it on only when your workers commit quickly and retry `40001` and `deadlock`.
  - With either setting, `SKIP LOCKED` returns **no rows** while another transaction holds the table in a way that names no rows: a `FOR UPDATE` that locks tables (a join, a subquery), a change of more than 4,096 rows of the table, a `DELETE` of every row or a bulk load. It also returns no rows when the table is held by a statement that is running right now for more than 50 ms.
  - On a table **without** a primary key there is no key to lock a row by: `FOR UPDATE` locks the whole table until your transaction ends, and `SKIP LOCKED` returns no rows while another transaction holds it.
  - Without `BEGIN` (no transaction), `FOR UPDATE` locks the rows only while the statement runs.
  - `FOR UPDATE` goes at the very end of the `SELECT`, after `ORDER BY` and `LIMIT`. Row locks are taken for a `SELECT` from one table; with a join, `GROUP BY`, `DISTINCT` or a view it locks the tables, as before.
  - `FOR SHARE`, `FOR NO KEY UPDATE` and `FOR KEY SHARE` take the same lock as `FOR UPDATE`, with `NOWAIT` and `SKIP LOCKED` too. In PostgreSQL two sessions may both hold `FOR SHARE` on one row; in KDB the second one waits (or `NOWAIT` fails, or `SKIP LOCKED` skips the row). That is stricter, never looser: nothing gets through that PostgreSQL would stop. It is only slower when many readers share rows.

**Example: Read the balances to be changed, then move the money**

Setup:

```sql
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```sql
BEGIN;
SELECT id, balance FROM accounts WHERE id IN (1, 2) ORDER BY id FOR UPDATE;
UPDATE accounts SET balance = balance - 250.50 WHERE id = 1;
UPDATE accounts SET balance = balance + 250.50 WHERE id = 2;
COMMIT;
SELECT id, owner, balance FROM accounts ORDER BY id;
```

Result:

`BEGIN`

```text
transaction started
```

`SELECT id, balance FROM accounts WHERE id IN (1, 2) ORDER BY id FOR UPDATE`

| id (INT) | balance (DECIMAL(2)) |
|---|---|
| 1 | 1000.00 |
| 2 | 0.00 |

(2 rows)

`UPDATE accounts SET balance = balance - 250.50 WHERE id = 1`

```text
1 row(s) updated
```

`UPDATE accounts SET balance = balance + 250.50 WHERE id = 2`

```text
1 row(s) updated
```

`COMMIT`

```text
transaction committed: 2 change(s) saved
```

`SELECT id, owner, balance FROM accounts ORDER BY id`

| id (INT) | owner (STRING) | balance (DECIMAL(2)) |
|---|---|---|
| 1 | Ram | 749.50 |
| 2 | Sita | 250.50 |

(2 rows)

**HTTP: SKIP LOCKED: another session holds job 1, so this worker gets job 2**

Setup:

```text
CREATE TABLE jobs (id INT PRIMARY KEY, state STRING);
INSERT INTO jobs VALUES (1, 'new'), (2, 'new'), (3, 'new');
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; SELECT id FROM jobs WHERE state = 'new' ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED
###
POST /exec

SELECT id, state FROM jobs WHERE state = 'new' ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "aeed33335b556ca67e8dfc88daeadbaa", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; SELECT id FROM jobs WHERE state = 'new' ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 23, "execute_us": 6}
    },
    {
      "statement": "SELECT id FROM jobs WHERE state = 'new' ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED",
      "columns": [
        {"name": "id", "type": "INT"}
      ],
      "dataset": [
        [1]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 23, "execute_us": 151}
    }
  ],
  "columns": [
    {"name": "id", "type": "INT"}
  ],
  "dataset": [
    [1]
  ],
  "count": 1,
  "timings": {"parse_us": 46, "execute_us": 157}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "SELECT id, state FROM jobs WHERE state = 'new' ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED",
  "results": [
    {
      "statement": "SELECT id, state FROM jobs WHERE state = 'new' ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED",
      "columns": [
        {"name": "id", "type": "INT"},
        {"name": "state", "type": "STRING"}
      ],
      "dataset": [
        [2, "new"]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 66, "execute_us": 84}
    }
  ],
  "columns": [
    {"name": "id", "type": "INT"},
    {"name": "state", "type": "STRING"}
  ],
  "dataset": [
    [2, "new"]
  ],
  "count": 1,
  "timings": {"parse_us": 66, "execute_us": 84}
}
```

**HTTP: NOWAIT: a locked row is an error at once**

Setup:

```text
CREATE TABLE jobs (id INT PRIMARY KEY, state STRING);
INSERT INTO jobs VALUES (1, 'new'), (2, 'new');
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; SELECT id FROM jobs WHERE id = 1 FOR UPDATE
###
POST /exec

SELECT id FROM jobs WHERE id = 1 FOR UPDATE NOWAIT
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "91ede6e2c499432dfd6ae7ad40f6f98d", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; SELECT id FROM jobs WHERE id = 1 FOR UPDATE",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 16, "execute_us": 4}
    },
    {
      "statement": "SELECT id FROM jobs WHERE id = 1 FOR UPDATE",
      "columns": [
        {"name": "id", "type": "INT"}
      ],
      "dataset": [
        [1]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 16, "execute_us": 64}
    }
  ],
  "columns": [
    {"name": "id", "type": "INT"}
  ],
  "dataset": [
    [1]
  ],
  "count": 1,
  "timings": {"parse_us": 32, "execute_us": 68}
}
```

`POST /exec`

HTTP 503 (application/json)

```text
{
  "query": "SELECT id FROM jobs WHERE id = 1 FOR UPDATE NOWAIT",
  "results": [],
  "saved": 0,
  "rolled_back": false,
  "error": "could not obtain lock on row in relation \"jobs\": another transaction holds it (SELECT ... FOR UPDATE), and FOR UPDATE NOWAIT does not wait",
  "sqlstate": "55P03"
}
```

**HTTP: NOWAIT on a row nobody locked: the row**

Setup:

```text
CREATE TABLE jobs (id INT PRIMARY KEY, state STRING);
INSERT INTO jobs VALUES (1, 'new'), (2, 'new');
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; SELECT id FROM jobs WHERE id = 1 FOR UPDATE
###
POST /exec

SELECT id FROM jobs WHERE id = 2 FOR UPDATE NOWAIT
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "12fda51f843e6372cb7f667626ffcc65", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; SELECT id FROM jobs WHERE id = 1 FOR UPDATE",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 21, "execute_us": 4}
    },
    {
      "statement": "SELECT id FROM jobs WHERE id = 1 FOR UPDATE",
      "columns": [
        {"name": "id", "type": "INT"}
      ],
      "dataset": [
        [1]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 21, "execute_us": 71}
    }
  ],
  "columns": [
    {"name": "id", "type": "INT"}
  ],
  "dataset": [
    [1]
  ],
  "count": 1,
  "timings": {"parse_us": 42, "execute_us": 75}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "SELECT id FROM jobs WHERE id = 2 FOR UPDATE NOWAIT",
  "results": [
    {
      "statement": "SELECT id FROM jobs WHERE id = 2 FOR UPDATE NOWAIT",
      "columns": [
        {"name": "id", "type": "INT"}
      ],
      "dataset": [
        [2]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 25, "execute_us": 61}
    }
  ],
  "columns": [
    {"name": "id", "type": "INT"}
  ],
  "dataset": [
    [2]
  ],
  "count": 1,
  "timings": {"parse_us": 25, "execute_us": 61}
}
```

<a id="kdb-shell"></a>

## Transactions in kdb shell

Syntax:

```sql
kdb shell database
kdb> BEGIN;
kdb> ...;
kdb> COMMIT;
```

In [`kdb shell`](cli-sql-and-shell.md), one transaction can go over many lines: the shell keeps one session for the whole time.

- **Notes:**
  - If you leave the shell (`.exit`) with a transaction still open, it is rolled back.
  - After an error inside the transaction, the shell accepts only `ROLLBACK` (see [when a statement fails](transactions.md#errors)).
  - The shell knows that `CREATE PROCEDURE ... BEGIN ... END;` is one statement, so `BEGIN` inside a procedure does not start a transaction.

**Command line: A transfer typed line by line**

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```bash
kdb shell market
> BEGIN;
> UPDATE accounts SET balance = balance - 250.50 WHERE id = 1;
> UPDATE accounts SET balance = balance + 250.50 WHERE id = 2;
> SELECT id, owner, balance FROM accounts ORDER BY id;
> COMMIT;
> .exit
```

Output:

```text
KDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kdb> transaction started
kdb> 1 row(s) updated
kdb> 1 row(s) updated
kdb> id | owner | balance
---+-------+--------
 1 | Ram   |  749.50
 2 | Sita  |  250.50
(2 rows, 0.2 ms)
kdb> transaction committed: 2 change(s) saved
kdb>
```

In the next example, the `INSERT` fails (id 1 is already used). The shell then refuses the next `UPDATE`, so it cannot take 10 from Ram outside the transaction. `ROLLBACK` ends the failed transaction.
The shell writes error lines to a separate output (stderr), so on this page they are shown at the end. In a real window, each error comes right after its line.

**Command line: After an error, only ROLLBACK is accepted**

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```bash
kdb shell market
> BEGIN;
> UPDATE accounts SET balance = balance + 10 WHERE id = 2;
> INSERT INTO accounts VALUES (1, 'Ram again', 0);
> UPDATE accounts SET balance = balance - 10 WHERE id = 1;
> ROLLBACK;
> SELECT id, owner, balance FROM accounts ORDER BY id;
> .exit
```

Output:

```text
KDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kdb> transaction started
kdb> 1 row(s) updated
kdb> kdb> kdb> transaction rolled back (it was already rolled back: a statement in it failed)
kdb> id | owner | balance
---+-------+--------
 1 | Ram   | 1000.00
 2 | Sita  |    0.00
(2 rows, 0.2 ms)
kdb> 
error: a row with id='1' already exists in 'accounts'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it (the transaction was rolled back; send ROLLBACK to end it)
error: the transaction of this session was rolled back (a statement in it failed); nothing of it was saved. Send ROLLBACK to end it, then start again
```

<a id="http"></a>

## Transactions over HTTP

Syntax:

```sql
POST /session                               -> {"session": "<id>", ...}
POST /exec   X-KDB-Session: <id>   BEGIN; ...
POST /exec   X-KDB-Session: <id>   ...; COMMIT
DELETE /session/<id>
```

`POST /exec` without a session runs one text: a transaction must end in the same request.
To keep a transaction open **over many requests**, open a session with `POST /session`, and send its id in the header `X-KDB-Session` with every `/exec`. See [HTTP sessions and cursors](http-sessions-and-cursors.md).

- **Notes:**
  - A request **without** the session header does not see the open transaction's changes. It sees the data as it was before `BEGIN`.
  - A transaction with no statement for 30 seconds is rolled back. Change it with `SET idle_in_transaction_session_timeout` or for the server (see [idle transactions](transactions.md#idle-timeout)). A session without a request for 10 minutes is closed.
  - `DELETE /session/<id>` rolls back an open transaction.
  - Over the [PostgreSQL protocol](postgres-protocol.md), every connection is a session: use `BEGIN` and `COMMIT` as usual.

**HTTP: A transfer over two requests; another request does not see it until COMMIT**

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1
###
POST /exec

SELECT id, balance FROM accounts ORDER BY id
###
POST /exec
X-KDB-Session: {{session}}

UPDATE accounts SET balance = balance + 100 WHERE id = 2; COMMIT
###
POST /exec

SELECT id, balance FROM accounts ORDER BY id
###
DELETE /session/{{session}}
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "c6c2e2f850f77619986b3b53723d9d39", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 24, "execute_us": 9}
    },
    {
      "statement": "UPDATE accounts SET balance = balance - 100 WHERE id = 1",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) updated",
      "timings": {"parse_us": 24, "execute_us": 74}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 48, "execute_us": 83}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "SELECT id, balance FROM accounts ORDER BY id",
  "results": [
    {
      "statement": "SELECT id, balance FROM accounts ORDER BY id",
      "columns": [
        {"name": "id", "type": "INT"},
        {"name": "balance", "type": "DECIMAL(2)"}
      ],
      "dataset": [
        [1, "1000.00"],
        [2, "0.00"]
      ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 27, "execute_us": 63}
    }
  ],
  "columns": [
    {"name": "id", "type": "INT"},
    {"name": "balance", "type": "DECIMAL(2)"}
  ],
  "dataset": [
    [1, "1000.00"],
    [2, "0.00"]
  ],
  "count": 2,
  "timings": {"parse_us": 27, "execute_us": 63}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "UPDATE accounts SET balance = balance + 100 WHERE id = 2; COMMIT",
  "results": [
    {
      "statement": "UPDATE accounts SET balance = balance + 100 WHERE id = 2",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) updated",
      "timings": {"parse_us": 18, "execute_us": 56}
    },
    {
      "statement": "COMMIT",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction committed: 2 change(s) saved",
      "timings": {"parse_us": 18, "execute_us": 13}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 36, "execute_us": 69}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "SELECT id, balance FROM accounts ORDER BY id",
  "results": [
    {
      "statement": "SELECT id, balance FROM accounts ORDER BY id",
      "columns": [
        {"name": "id", "type": "INT"},
        {"name": "balance", "type": "DECIMAL(2)"}
      ],
      "dataset": [
        [1, "900.00"],
        [2, "100.00"]
      ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 2, "execute_us": 91}
    }
  ],
  "columns": [
    {"name": "id", "type": "INT"},
    {"name": "balance", "type": "DECIMAL(2)"}
  ],
  "dataset": [
    [1, "900.00"],
    [2, "100.00"]
  ],
  "count": 2,
  "timings": {"parse_us": 2, "execute_us": 91}
}
```

`DELETE /session/{{session}}`

HTTP 200 (application/json)

```text
{"session": "c6c2e2f850f77619986b3b53723d9d39", "closed": true}
```

<a id="one-writer"></a>

## One writer per table

Syntax:

```sql
session A: BEGIN; UPDATE accounts SET ... WHERE id = 1;  -- A locks row 1 of accounts (row-level locks)
session B: INSERT INTO ticks ...;                         -- B goes at once: another table
session C: UPDATE accounts SET ... WHERE id = 2;          -- C goes at once: another row
session C: UPDATE accounts SET ... WHERE id = 1;          -- C waits for A's row (5 s unless set), then "a row of table 'accounts' is locked"
session C: SELECT ... FROM accounts;                      -- C does not wait for A's open transaction: it reads the data without A's changes
session A: COMMIT;                                        -- row 1 is free; the next writer goes
```

A reader waits only while a writer's **statement** runs (see [reader yield](transactions.md#reader-yield) for long triggers and `CALL`s). Between A's requests nothing runs, so C reads at once.

A writer **locks every table it uses** until its statement ends. Inside `BEGIN` ... `COMMIT` it keeps them until the transaction ends - except where it only updated rows by their key: there it holds just those rows (row-level locks, in the table below). Writers of **different tables** run at the same time. Writers of the **same table** take turns, so two transfers can never mix, and every transaction sees the data exactly as the one before it left it (this is called *serializable*).

| Rule | Detail |
|---|---|
| Other tables | Writers of different tables do not wait for each other's locks: a live tick feed and a big load into another table run side by side. They can still wait a little for work the whole database shares: a checkpoint that writes the changes to disk, and the disk sync of a commit. |
| The same table | A second writer waits until the first one ends, first come, first served. Line-protocol writes and bulk loads wait the same way. |
| What is locked | The tables a statement changes and reads, and what it sets off: tables its triggers and procedures use, tables linked to it by foreign keys, and `_audit_log` for audited tables. A procedure or trigger whose [`EXECUTE`](procedure-language.md#execute) text is made while it runs (`format(...)`, `'...' \|\| name`), and a read of `information_schema` or `pg_catalog` in a writer, lock every table. `EXECUTE` of text written out in the body locks only the tables of that text. |
| Row-level locks | Inside `BEGIN` ... `COMMIT`, an `UPDATE` of rows of a table with a primary key locks **those rows**, not the table, until the transaction ends. Between its statements the transaction gives the table back: another transaction may change **other rows** of it at once, and one that meets a locked row waits for it, as in PostgreSQL (after the lock timeout: `a row of table 'x' is locked`, `55P03`, or `40001` inside its own transaction). Two transactions that wait for each other's rows: one gets `deadlock: ...` at once. A `ROLLBACK` puts back only its own rows. What still keeps the **whole table** until `COMMIT`: an `INSERT` or `DELETE` in it, an `UPDATE` that changes a row's key, and any change of a table with another `UNIQUE` column or unique index, a foreign key (either way) or a trigger - rows the transaction holds could clash with another writer's there. A read in another transaction does not hold up such a transaction. Turn it off with `KDB_NO_ROW_LOCKS=1` (every table a transaction writes stays locked until it ends, as before). |
| `SELECT ... FOR UPDATE` | On a table with a primary key it locks only the rows it returns, not the table, until the transaction ends: other writers of the table go on, and only a writer of one of those rows waits ([row locks](#for-update)). |
| Several writers at once | `kdb serve --table-writers many`: requests that touch a table only by single rows and their primary key run on it at the same time, waiting only for the same row ([several writers of one table](#shared-writers)). Off by default. |
| Several tables | The tables of one request are locked all at once, always in the same order, so two such requests never wait for each other. |
| Deadlock | A transaction that needs one more table in a later request can meet another transaction that waits for one of its tables. KDB sees this at once: the one that would wait gets `deadlock: ...` (HTTP status 503) and is rolled back. Run it again. |
| Busy | A writer that waited the [lock timeout](#lock-timeout) (5 seconds unless set) gets `table 'x' is busy: ...` (HTTP status 503, PostgreSQL `55P03`; `40001` inside its own `BEGIN ... COMMIT`, see [isolation](#isolation)). Nothing of its statement was done: try the whole transaction again a moment later. |
| A taken key | An `INSERT ... VALUES` that waits for a busy table looks its keys up in the **committed** rows while it waits. A key that is already there gives the duplicate key error **at once** (PostgreSQL `23505`, HTTP status 400, with the table and constraint named), not `55P03` after the lock timeout. Inside `BEGIN` the transaction ends, as after any `23505`. A key that only the other transaction has added, deleted or changed is not decided yet: the `INSERT` waits for it. When that transaction commits, the `INSERT` gets `23505` (if the key is now taken) or goes in; when it rolls back, the row goes in. A key it deleted is never reported as taken. This covers the primary key, `UNIQUE` columns, plain unique indexes and a time-series `DEDUP KEY` that includes the time column, with literal values or `$1` parameters (not values worked out by an expression, `ON CONFLICT`, or a table with an `INSERT` trigger: those wait as before). |
| Schema changes of a table | `CREATE TABLE`, `ALTER TABLE` (`RENAME` too), `DROP TABLE`, `CREATE INDEX`, `DROP INDEX`, `CREATE`, `ALTER` and `DROP TRIGGER` and `TRUNCATE` lock only their table (and the tables its foreign keys point at). `CREATE TABLE ... AS` locks the tables its query reads. `CREATE`, `REFRESH` and `DROP MATERIALIZED VIEW` lock the view and its table. They wait for writers of that table, like any writer (`table 'x' is busy: ...`). `CREATE TABLE` (also `IF NOT EXISTS` and `AS SELECT`), `ALTER TABLE` (not `SET TTL`, `SET (dedup_insert ...)` or `DEDUP`), `RENAME TABLE` and `CREATE` / `DROP INDEX` do not wait for writers of **other** tables at all: they run beside them, also beside one long `INSERT ... SELECT`, `COPY` or `CALL` that never pauses. Only a writer that named the new table before it existed is waited for. The other schema changes of a table (`DROP TABLE`, triggers, `TRUNCATE`, materialized views) wait for a long writer of other tables only until it pauses between two of its statements ([reader yield](#reader-yield)). Only the wait for writers counts against the lock timeout: a long `SELECT` or read-only `CALL` is waited for as long as it runs, then the schema change runs. Readers wait while the schema change itself runs, which is short. Turn it off with `kdb serve --ddl-beside-writers off` (they wait for the pause again) or `--scoped-ddl off` (every schema change locks every table). |
| Views, procedures, functions | change a definition, not a table: they lock no table, and writers of tables go on (creating or altering a `CACHED` view and `REFRESH VIEW` lock the tables its query reads). They still wait for a writer that may use the old definition next: a view change for a running writer that reads a view, a procedure or function change for a running writer that runs a procedure, a function or a plpgsql trigger (a long `CALL`, say). After the lock timeout that is `database is busy: ...`. |
| Other schema changes | Sequences, `BACKUP`, `DEDUP TABLE`, a change of a table a materialized view reads, a `CREATE TABLE ... AS` whose query reads `information_schema`, and a schema change sent in one request with statements it affects (`CREATE OR REPLACE PROCEDURE p ...; CALL p()`, or `CREATE VIEW v ...; INSERT ... SELECT FROM v`) lock every table: they wait until no transaction is open, and after the lock timeout get `database is busy: ...`. While such a change waits for a writer that was already running, writers of other tables still go ahead of it. Once that writer ends, new writers wait behind the change, so it is never kept out. |
| Schema statements with nothing to do | lock nothing and answer at once: `CREATE TABLE IF NOT EXISTS` of a table that is there, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` of a column that is there, `DROP COLUMN IF EXISTS`, `DROP TABLE IF EXISTS`, `DROP INDEX IF EXISTS` and `DROP VIEW IF EXISTS` of something that is not there, `CREATE INDEX IF NOT EXISTS` and `CREATE VIEW IF NOT EXISTS` of one that is there, `CREATE EXTENSION`, and a `COMMENT ON` that changes nothing (the same text again, or an object whose comments KDB does not keep). So the `CREATE ... IF NOT EXISTS` an app sends at start-up never waits for a long writer. |
| A request that cannot get its locks | none of its statements ran. The error says so: `... (none of the 2 statements of this request was run)`. Send the whole request again. |
| Readers and open transactions | A `SELECT` does not wait for an open transaction between its requests: it runs at once and sees the data **without** that transaction's changes. A read never waits for another read. |
| Readers and a running writer | A `SELECT` waits only while a writer runs on a table it reads (a statement, a long `CALL`, a trigger, a `POST /write`). `SELECT 1`, a login lookup and reads of other tables answer at once ([readers during a long writer](transactions.md#per-table-reads)). With [reader yield](transactions.md#reader-yield) (on unless turned off), a long `CALL`, trigger or request of many statements lets readers of its tables in between its statements; with it off, they wait for the writer's whole request. |
| A `CALL` that only reads | is a reader, not a writer: it locks nothing, like a `SELECT` ([a CALL that only reads](procedures.md#read-only-call)). |
| What a reader sees | the last committed state when its request starts, for every table at once. A commit that changes several tables (a trigger that fills three tables) is seen whole or not at all. The statements of one read-only request all see the same state. |
| Idle | A transaction with no statement for 30 seconds is rolled back, so a forgotten transaction cannot block everybody. The time is a setting: see [idle transactions](transactions.md#idle-timeout). |
| Commits | Writers that commit at the same moment share one wait for the disk (group commit). Each one is still told "committed" only when its changes are on the disk - unless its session set `SET synchronous_commit = off` ([performance tips](performance-tips.md#synchronous-commit)): then it is told at once and the disk follows within about 10 ms. |
| Per database | The locks are for one database. Transactions on other databases do not wait. |

- **Notes:** a transfer takes about a millisecond, so waiting is short. **Never** keep a transaction open while you wait for a person (a click, a form, an SMS code). Read first, ask the person, then do `BEGIN ... COMMIT` quickly.
- Use the tables in the same order in every transaction (for example `accounts`, then `ledger`), or send the whole transaction in one request. Then deadlocks cannot happen.

**HTTP: A writer of another table goes at once**

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
CREATE TABLE ticks (symbol SYMBOL, price DOUBLE);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1
###
POST /exec

INSERT INTO ticks VALUES ('CITY', 505.5)
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "f7e759966764a764063c635d46f4e31d", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 14, "execute_us": 6}
    },
    {
      "statement": "UPDATE accounts SET balance = balance - 100 WHERE id = 1",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) updated",
      "timings": {"parse_us": 14, "execute_us": 73}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 28, "execute_us": 79}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "INSERT INTO ticks VALUES ('CITY', 505.5)",
  "results": [
    {
      "statement": "INSERT INTO ticks VALUES ('CITY', 505.5)",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 32, "execute_us": 19}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 32, "execute_us": 19}
}
```

**HTTP: Another row of the same table goes at once (row-level locks)**

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1
###
POST /exec

UPDATE accounts SET balance = 0 WHERE id = 2
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "b53794a14362801a49dbfdae615461bd", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 12, "execute_us": 4}
    },
    {
      "statement": "UPDATE accounts SET balance = balance - 100 WHERE id = 1",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) updated",
      "timings": {"parse_us": 12, "execute_us": 42}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 24, "execute_us": 46}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "UPDATE accounts SET balance = 0 WHERE id = 2",
  "results": [
    {
      "statement": "UPDATE accounts SET balance = 0 WHERE id = 2",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) updated",
      "timings": {"parse_us": 23, "execute_us": 34}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 23, "execute_us": 34}
}
```

**HTTP: The same row waits 5 seconds, then gets 'a row of table ... is locked'**

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1
###
POST /exec

UPDATE accounts SET balance = 0 WHERE id = 1
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "2fcad7bfc65a0a969b174771e5c08a0e", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 11, "execute_us": 3}
    },
    {
      "statement": "UPDATE accounts SET balance = balance - 100 WHERE id = 1",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) updated",
      "timings": {"parse_us": 11, "execute_us": 39}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 22, "execute_us": 42}
}
```

`POST /exec`

HTTP 503 (application/json)

```text
{
  "query": "UPDATE accounts SET balance = 0 WHERE id = 1",
  "results": [],
  "saved": 0,
  "rolled_back": false,
  "error": "a row of table 'accounts' is locked: another transaction changed it or took it with SELECT ... FOR UPDATE, and is still open; waited 5013 ms (lock_timeout: SET lock_timeout, or kdb serve --lock-timeout). Try again, or keep transactions short",
  "sqlstate": "55P03"
}
```

**HTTP: A transaction that inserted keeps the whole table: another writer waits, then gets 'table ... is busy'**

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; INSERT INTO accounts VALUES (3, 'Hari', 0)
###
POST /exec

UPDATE accounts SET balance = 0 WHERE id = 2
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "ccf8379d5ccea6c1117951a641db70db", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; INSERT INTO accounts VALUES (3, 'Hari', 0)",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 9, "execute_us": 5}
    },
    {
      "statement": "INSERT INTO accounts VALUES (3, 'Hari', 0)",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) inserted",
      "timings": {"parse_us": 9, "execute_us": 47}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 18, "execute_us": 52}
}
```

`POST /exec`

HTTP 503 (application/json)

```text
{
  "query": "UPDATE accounts SET balance = 0 WHERE id = 2",
  "results": [],
  "saved": 0,
  "rolled_back": false,
  "error": "table 'accounts' is busy: another transaction has held it for 5027 ms; waited 5003 ms (lock_timeout: SET lock_timeout, or kdb serve --lock-timeout). Try again, or keep transactions short",
  "sqlstate": "55P03"
}
```

**HTTP: An INSERT of a key that is taken gets 23505 at once, even while the table is busy**

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1
###
POST /exec

INSERT INTO accounts VALUES (2, 'Hari', 50)
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "3663ba76f5b8fcea203f7cb874c34c46", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 24, "execute_us": 5}
    },
    {
      "statement": "UPDATE accounts SET balance = balance - 100 WHERE id = 1",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) updated",
      "timings": {"parse_us": 24, "execute_us": 56}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 48, "execute_us": 61}
}
```

`POST /exec`

HTTP 400 (application/json)

```text
{
  "query": "INSERT INTO accounts VALUES (2, 'Hari', 50)",
  "results": [],
  "saved": 0,
  "rolled_back": false,
  "error": "a row with id='2' already exists in 'accounts'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it",
  "sqlstate": "23505",
  "table": "accounts",
  "constraint": "accounts_pkey",
  "column_name": "id"
}
```

**HTTP: CREATE TABLE IF NOT EXISTS of a table that is there goes at once, even while a transaction is open**

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1
###
POST /exec

CREATE TABLE IF NOT EXISTS accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS owner STRING
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "938dc0eedc33ef8407f39dac500ead73", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 1",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 17, "execute_us": 4}
    },
    {
      "statement": "UPDATE accounts SET balance = balance - 100 WHERE id = 1",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) updated",
      "timings": {"parse_us": 17, "execute_us": 47}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 34, "execute_us": 51}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "CREATE TABLE IF NOT EXISTS accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);\nALTER TABLE accounts ADD COLUMN IF NOT EXISTS owner STRING",
  "results": [
    {
      "statement": "CREATE TABLE IF NOT EXISTS accounts (\n  id INT PRIMARY KEY,\n  owner STRING NOT NULL,\n  balance DECIMAL(2) NOT NULL\n)",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "table 'accounts' already exists",
      "timings": {"parse_us": 17, "execute_us": 1}
    },
    {
      "statement": "ALTER TABLE accounts ADD COLUMN IF NOT EXISTS owner STRING",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "table 'accounts' not changed (already as asked)",
      "timings": {"parse_us": 17, "execute_us": 0}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 34, "execute_us": 1}
}
```

<a id="isolation"></a>

## Isolation: what a transaction sees

Syntax:

```sql
BEGIN [ISOLATION LEVEL READ COMMITTED | SERIALIZABLE]
SET TRANSACTION ISOLATION LEVEL READ COMMITTED        -- this transaction only (inside BEGIN)
SET default_transaction_isolation = 'read committed'  -- the session's transactions from now on
SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED
SHOW transaction_isolation
```

KDB's transactions are **serializable** unless you ask for READ COMMITTED: every table a transaction reads or writes is locked until `COMMIT` or `ROLLBACK`. PostgreSQL's default is READ COMMITTED.

| | SERIALIZABLE (KDB's default) | READ COMMITTED |
|---|---|---|
| A `SELECT` in the transaction | locks the table until the end | locks nothing, unless the transaction already holds the table |
| Reading again after another session committed | the same rows (the other session had to wait) | the new rows |
| "Read v, write v + 1" from many clients | never loses an update; clients take turns | can lose updates, as in PostgreSQL: use `UPDATE ... SET v = v + 1` or `SELECT ... FOR UPDATE` |
| Tables the transaction wrote | read inside it: it sees its own changes | the same |

- **What a refusal is:** a transaction never sees half of another one. Instead, a writer that waits too long for a table is refused:

| Error | SQLSTATE | HTTP | What to do |
|---|---|---|---|
| `table 'x' is busy` inside `BEGIN ... COMMIT` | `40001` (serialization_failure) | 503 | `ROLLBACK` and run the whole transaction again. Drivers and frameworks retry this code by themselves. |
| `table 'x' is busy` for a statement outside a transaction | `55P03` (lock_not_available) | 503 | send it again |
| `deadlock: ...` | `40P01` (deadlock_detected) | 503 | the transaction was rolled back: run it again |
| `FOR UPDATE NOWAIT` on a busy table | `55P03` | 503 | as in PostgreSQL |

- **Notes:**
  - `REPEATABLE READ` is taken as `SERIALIZABLE`, `READ UNCOMMITTED` as `READ COMMITTED` (as PostgreSQL does). A database may always give more than asked.
  - READ COMMITTED leaves only a `SELECT` sent **on its own** outside the locks. A `SELECT` in the same request as `BEGIN` or a write, `SELECT ... FOR UPDATE`, and a read that joins a table the transaction holds, lock their tables as before.
  - `SET TRANSACTION` outside `BEGIN ... COMMIT` changes nothing (PostgreSQL gives a warning, `25P01`).
  - Readers outside any transaction never lock: they see the last committed rows ([one writer per table](#one-writer)).

**HTTP: READ COMMITTED: another session writes the table this transaction read**

Setup:

```text
CREATE TABLE counter (k INT PRIMARY KEY, v LONG);
INSERT INTO counter VALUES (1, 10);
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN ISOLATION LEVEL READ COMMITTED
###
POST /exec
X-KDB-Session: {{session}}

SELECT v FROM counter WHERE k = 1
###
POST /exec

UPDATE counter SET v = 11 WHERE k = 1
###
POST /exec
X-KDB-Session: {{session}}

SELECT v FROM counter WHERE k = 1
###
POST /exec
X-KDB-Session: {{session}}

COMMIT
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "29d98ffec3c666650a313a55dbe88401", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN ISOLATION LEVEL READ COMMITTED",
  "results": [
    {
      "statement": "BEGIN ISOLATION LEVEL READ COMMITTED",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 8, "execute_us": 10}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 8, "execute_us": 10}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "SELECT v FROM counter WHERE k = 1",
  "results": [
    {
      "statement": "SELECT v FROM counter WHERE k = 1",
      "columns": [
        {"name": "v", "type": "LONG"}
      ],
      "dataset": [
        [10]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 40, "execute_us": 64}
    }
  ],
  "columns": [
    {"name": "v", "type": "LONG"}
  ],
  "dataset": [
    [10]
  ],
  "count": 1,
  "timings": {"parse_us": 40, "execute_us": 64}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "UPDATE counter SET v = 11 WHERE k = 1",
  "results": [
    {
      "statement": "UPDATE counter SET v = 11 WHERE k = 1",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 1,
      "message": "1 row(s) updated",
      "timings": {"parse_us": 19, "execute_us": 50}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 19, "execute_us": 50}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "SELECT v FROM counter WHERE k = 1",
  "results": [
    {
      "statement": "SELECT v FROM counter WHERE k = 1",
      "columns": [
        {"name": "v", "type": "LONG"}
      ],
      "dataset": [
        [11]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 4, "execute_us": 112}
    }
  ],
  "columns": [
    {"name": "v", "type": "LONG"}
  ],
  "dataset": [
    [11]
  ],
  "count": 1,
  "timings": {"parse_us": 4, "execute_us": 112}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "COMMIT",
  "results": [
    {
      "statement": "COMMIT",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction committed: 0 change(s) saved",
      "timings": {"parse_us": 11, "execute_us": 10}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 11, "execute_us": 10}
}
```

<a id="read-only"></a>

## Read-only transactions

Syntax:

```sql
BEGIN READ ONLY                               -- also START TRANSACTION READ ONLY (PostgreSQL port)
BEGIN ISOLATION LEVEL READ COMMITTED, READ ONLY
SET TRANSACTION READ ONLY | READ WRITE        -- this transaction only (inside BEGIN)
SET default_transaction_read_only = on | off  -- the session's transactions from now on
SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY
SHOW transaction_read_only
```

A read-only transaction refuses every change, as in PostgreSQL. Use it for reports and checks that must never write by mistake.

| In a read-only transaction | Result |
|---|---|
| `SELECT`, `SHOW`, `EXPLAIN`, cursors, a `CALL` of a procedure that only reads | runs |
| `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `COPY ... FROM` | refused |
| `CREATE`, `ALTER`, `DROP` of tables, views, indexes, procedures, databases and users | refused |
| `SELECT ... FOR UPDATE`, `WITH x AS (UPDATE ...)`, `nextval()`, `setval()` | refused |
| a `CALL` or `DO` block whose body changes data | refused at the first change |

- **The error:** `cannot execute INSERT in a read-only transaction`, SQLSTATE `25006` (HTTP 403). Inside `BEGIN ... COMMIT` the transaction is aborted, as in PostgreSQL: send `ROLLBACK`. Nothing is written.
- **Notes:**
  - With `default_transaction_read_only = on`, a statement sent on its own is read-only too. `BEGIN READ WRITE` (or `SET TRANSACTION READ WRITE` first in the block) writes once, for that transaction.
  - `SET TRANSACTION READ WRITE` after the transaction ran a query is refused (`25001`), as in PostgreSQL.
  - Over HTTP, `BEGIN READ ONLY` works in one request. `SET default_transaction_read_only` and `SET TRANSACTION` need an [HTTP session](http-sessions-and-cursors.md) (`POST /session`): without one there is nowhere to keep them, so they are refused.
  - One session's setting never changes another session.
  - To make a whole database or server read-only for everyone, use `ALTER DATABASE ... SET READ ONLY` or `kdb serve --read-only` instead.

**HTTP: A report session that cannot write by mistake** (shows an error)

Setup:

```text
CREATE TABLE report_src (k INT PRIMARY KEY, v LONG);
INSERT INTO report_src VALUES (1, 10);
```

```http
POST /exec

BEGIN READ ONLY; SELECT v FROM report_src; COMMIT
###
POST /exec

BEGIN READ ONLY; UPDATE report_src SET v = 0 WHERE k = 1
```

Response:

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN READ ONLY; SELECT v FROM report_src; COMMIT",
  "results": [
    {
      "statement": "BEGIN READ ONLY",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 7, "execute_us": 3}
    },
    {
      "statement": "SELECT v FROM report_src",
      "columns": [
        {"name": "v", "type": "LONG"}
      ],
      "dataset": [
        [10]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 7, "execute_us": 54}
    },
    {
      "statement": "COMMIT",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction committed: 0 change(s) saved",
      "timings": {"parse_us": 7, "execute_us": 2}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 21, "execute_us": 59}
}
```

`POST /exec`

HTTP 403 (application/json)

```text
{
  "query": "BEGIN READ ONLY; UPDATE report_src SET v = 0 WHERE k = 1",
  "results": [
    {
      "statement": "BEGIN READ ONLY",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 14, "execute_us": 4}
    }
  ],
  "saved": 0,
  "rolled_back": true,
  "error": "cannot execute UPDATE in a read-only transaction (the transaction was rolled back)",
  "sqlstate": "25006"
}
```

<a id="lock-timeout"></a>

## How long a writer waits: lock_timeout

Syntax:

```sql
kdb serve --lock-timeout 20s              the server (default 5s; 0 = no limit)
KDB_LOCK_TIMEOUT=20s                      the same, for Docker
"lock_timeout_ms": 20000                  the same, in kdb.conf
SET lock_timeout = '20s' | 20000 | 0 | DEFAULT     one session (HTTP session or PostgreSQL connection)
X-KDB-Lock-Timeout: 20s                   one HTTP request
```

| Where | Detail |
|---|---|
| The server | A flag wins, then `kdb.conf`, then `KDB_LOCK_TIMEOUT`, then 5 seconds. The console's Settings page shows the value and where it came from. |
| One session | `SET lock_timeout` lasts for the session, like in PostgreSQL. A plain number is milliseconds. `DEFAULT` (or `RESET lock_timeout`) goes back to the server's. `SHOW lock_timeout` gives the value in milliseconds. |
| One request | The HTTP header `X-KDB-Lock-Timeout` sets it for that request only: `/exec`, the line protocol (`POST /write`) and CSV import (`POST /imp`). |
| Loads | Rows from the line protocol, `/imp` and a PostgreSQL `COPY` wait in a write queue. Each caller keeps its own lock timeout there, also while it waits behind other loads of the same table. A cancel or a server stop ends its wait at once, and nothing of it is written. |
| `0` | Wait without a limit. A statement timeout, a cancel or a server stop still ends the wait at once. |
| The error | `table 'x' is busy: another transaction has held it for N ms; waited M ms ...`. When only writers that came first are in the way (they wait too), it says `other writers came first and wait for it too`. |

Many small writers of one table (counters, logins) that should queue instead of failing: raise the lock timeout for them, and keep each transaction short.

<a id="lock-table"></a>

## LOCK TABLE, pg_locks and lock waits

Syntax:

```sql
LOCK [TABLE] name [, name ...] [IN mode MODE] [NOWAIT]      only inside BEGIN ... COMMIT
mode: ACCESS SHARE | ROW SHARE | ROW EXCLUSIVE | SHARE UPDATE EXCLUSIVE
    | SHARE | SHARE ROW EXCLUSIVE | EXCLUSIVE | ACCESS EXCLUSIVE (the default)
SELECT relation::regclass, mode, granted, pid FROM pg_locks        who holds and who waits
SELECT pg_blocking_pids(pid)                                       who a waiting pid waits for
SET log_lock_waits = on;  SET deadlock_timeout = '1s'              a log line for a long wait
```

`LOCK TABLE` takes a table lock in one of PostgreSQL's eight modes and keeps it until the transaction ends (`COMMIT` or `ROLLBACK`). The modes keep each other out as in PostgreSQL:

| You lock with | Other transactions can still | They wait to |
|---|---|---|
| `ACCESS SHARE` | read and change the table | drop or rebuild it (`ACCESS EXCLUSIVE`) |
| `ROW SHARE`, `ROW EXCLUSIVE` | read and change it | take `SHARE` or stronger (`ROW SHARE`: `EXCLUSIVE` or stronger) |
| `SHARE` | read it, and take `SHARE` too | change it (`INSERT`, `UPDATE`, `DELETE`) |
| `SHARE ROW EXCLUSIVE`, `EXCLUSIVE` | read it | change it, or lock it in `SHARE` or stronger |
| `ACCESS EXCLUSIVE` | nothing | read it or change it. A plain `SELECT` of the table waits too |

| Rule | Detail |
|---|---|
| Only in a transaction | Outside `BEGIN ... COMMIT` it fails with `LOCK TABLE can only be used in transaction blocks` (`25P01`), as in PostgreSQL. In a procedure body it lasts until the request's transaction ends. |
| `NOWAIT` | A table another transaction holds in a conflicting mode fails at once with `could not obtain lock on relation "t"` (`55P03`, HTTP 503: try again), and the transaction is rolled back, as in PostgreSQL. Without `NOWAIT` it waits the [lock timeout](#lock-timeout). |
| A view | locks the tables the view reads, in the same mode. |
| KDB's own writers | still take turns on a table as always ([one writer per table](#one-writer)): two `UPDATE`s of one table never run at once. `pg_locks` shows a writer's lock as `RowExclusiveLock` (it changes the table), `RowShareLock` (`SELECT ... FOR UPDATE`) or `AccessShareLock` (it reads the table in its transaction). |
| Readers | A plain `SELECT` waits only for `ACCESS EXCLUSIVE`. A read that started before the lock was granted runs to its end. The session that holds the lock reads on. |
| Deadlock | Two transactions that wait for each other: one gets `deadlock: process 12 waits for ExclusiveLock on table 't1'; blocked by process 34. Process 34 waits for ...` (`40P01`, HTTP 503) at once and is rolled back. Run it again. |
| Rights | `ACCESS SHARE` needs the right to read the table; the other modes the right to change it. A read-only transaction may take up to `ROW EXCLUSIVE`. |

`pg_locks` lists the table locks of the database: one row per table and mode, `granted` true for a held lock and false for one waited for (then `waitstart` says since when). `pid` is the same number `pg_stat_activity` and `pg_backend_pid()` give for that connection or HTTP session. A lock of every table (a schema change, `BACKUP`) shows as `AccessExclusiveLock` on each table. Over the PostgreSQL port `relation::regclass` gives the table's name; over HTTP join `pg_class` on `oid`.

`pg_locks`, `pg_stat_activity` and `pg_stat_statements` read no table, so a transaction can look at them (`BEGIN; LOCK TABLE t; SELECT * FROM pg_locks`) without taking any other table and without waiting for anyone.

`pg_blocking_pids(pid)` gives the pids a waiting pid waits for: those holding a lock in its way, and those that came first and wait for the same table. `{}` when it does not wait.

`log_lock_waits` (off by default) writes one line to the server log when a statement has waited for a table lock longer than `deadlock_timeout` (1 second by default), naming it, the lock, who holds it and who waits: `kdb: LOG: process 12 still waiting for RowExclusiveLock on relation 16448 ('t') of database 'main' after 1003 ms; process holding the lock: 34; wait queue: 12`. Set it for the server with `kdb serve --log-lock-waits on --deadlock-timeout 1s` (`KDB_LOG_LOCK_WAITS`, `KDB_DEADLOCK_TIMEOUT`), or for one session with `SET`. KDB finds a deadlock at once whatever `deadlock_timeout` is: it only says when the line is written.

**HTTP: SHARE mode: another transaction reads the table, its UPDATE would wait; pg_locks shows the lock**

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; LOCK TABLE accounts IN SHARE MODE
###
POST /exec

SELECT owner, balance FROM accounts ORDER BY id;
SELECT c.relname, l.mode, l.granted FROM pg_locks l JOIN pg_class c ON c.oid = l.relation
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "18667f6568b87caad682354243a60541", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; LOCK TABLE accounts IN SHARE MODE",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 7, "execute_us": 4}
    },
    {
      "statement": "LOCK TABLE accounts IN SHARE MODE",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "LOCK TABLE",
      "timings": {"parse_us": 7, "execute_us": 3}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 14, "execute_us": 7}
}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "SELECT owner, balance FROM accounts ORDER BY id;\nSELECT c.relname, l.mode, l.granted FROM pg_locks l JOIN pg_class c ON c.oid = l.relation",
  "results": [
    {
      "statement": "SELECT owner, balance FROM accounts ORDER BY id",
      "columns": [
        {"name": "owner", "type": "STRING"},
        {"name": "balance", "type": "DECIMAL(2)"}
      ],
      "dataset": [
        ["Ram", "1000.00"],
        ["Sita", "0.00"]
      ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 18, "execute_us": 64}
    },
    {
      "statement": "SELECT c.relname, l.mode, l.granted FROM pg_locks AS l JOIN pg_class AS c ON c.oid = l.relation",
      "columns": [
        {"name": "relname", "type": "STRING"},
        {"name": "mode", "type": "STRING"},
        {"name": "granted", "type": "BOOL"}
      ],
      "dataset": [
        ["accounts", "ShareLock", true]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 18, "execute_us": 131}
    }
  ],
  "columns": [
    {"name": "relname", "type": "STRING"},
    {"name": "mode", "type": "STRING"},
    {"name": "granted", "type": "BOOL"}
  ],
  "dataset": [
    ["accounts", "ShareLock", true]
  ],
  "count": 1,
  "timings": {"parse_us": 36, "execute_us": 195}
}
```

**HTTP: NOWAIT on a table another transaction holds: 55P03 at once**

Setup:

```text
CREATE TABLE accounts (id INT PRIMARY KEY, owner STRING NOT NULL, balance DECIMAL(2) NOT NULL);
INSERT INTO accounts VALUES (1, 'Ram', 1000), (2, 'Sita', 0);
```

```http
POST /session

###
POST /exec
X-KDB-Session: {{session}}

BEGIN; LOCK TABLE accounts IN SHARE MODE
###
POST /exec

BEGIN; LOCK TABLE accounts IN ACCESS EXCLUSIVE MODE NOWAIT
```

Response:

`POST /session`

HTTP 200 (application/json)

```text
{"session": "4715e1b78204942da6d204e9b1644327", "idle_timeout_ms": 600000}
```

`POST /exec`

HTTP 200 (application/json)

```text
{
  "query": "BEGIN; LOCK TABLE accounts IN SHARE MODE",
  "results": [
    {
      "statement": "BEGIN",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "transaction started",
      "timings": {"parse_us": 8, "execute_us": 4}
    },
    {
      "statement": "LOCK TABLE accounts IN SHARE MODE",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "LOCK TABLE",
      "timings": {"parse_us": 8, "execute_us": 1}
    }
  ],
  "columns": [],
  "dataset": [],
  "count": 0,
  "timings": {"parse_us": 16, "execute_us": 5}
}
```

`POST /exec`

HTTP 503 (application/json)

```text
{
  "query": "BEGIN; LOCK TABLE accounts IN ACCESS EXCLUSIVE MODE NOWAIT",
  "results": [],
  "saved": 0,
  "rolled_back": false,
  "error": "could not obtain lock on relation \"accounts\" (none of the 2 statements of this request was run)",
  "sqlstate": "55P03"
}
```

<a id="idle-timeout"></a>

## Idle transactions: idle_in_transaction_session_timeout

Syntax:

```sql
kdb serve --idle-in-transaction-timeout 5min    the server (default 30s; 0 = never)
KDB_IDLE_IN_TRANSACTION_TIMEOUT=5min            the same, for Docker
"idle_in_transaction_timeout_ms": 300000        the same, in kdb.conf
SET idle_in_transaction_session_timeout = '5min' | 300000 | 0 | DEFAULT   one session
```

An open `BEGIN` ... `COMMIT` that sends no statement for this long is rolled back. This happens when another writer needs its tables, or at its own next statement. Its session then gets an error until it sends `ROLLBACK`. So a client that died in the middle of a transaction cannot keep its tables locked for ever.

| Where | Detail |
|---|---|
| The server | A flag wins, then `kdb.conf`, then `KDB_IDLE_IN_TRANSACTION_TIMEOUT`, then 30 seconds. The start-up lines and the console's Settings page show it and where it came from. |
| One session | `SET idle_in_transaction_session_timeout` lasts for the session (an HTTP session or a PostgreSQL connection), like in PostgreSQL. A plain number is milliseconds. `0` = never. `DEFAULT` (or `RESET`) goes back to the server's. `SHOW idle_in_transaction_session_timeout` gives it in milliseconds on the PostgreSQL port. |
| The error | `the transaction of this session was rolled back (it was open without a statement for N ms; the limit is M ms ...)`. |

<a id="per-table-reads"></a>

## Readers during a long writer

Syntax:

```sql
kdb serve --per-table-reads on|off     (default on)
KDB_PER_TABLE_READS=off                (the same, for Docker; a flag wins)
```

A reader waits only for writers that are **running right now on a table it reads**.

| Reader | While a long `CALL`, trigger or bulk load writes table `t` |
|---|---|
| `SELECT 1`, a read of other tables | answers at once |
| A read of `t` (or of a table the writer only reads) | waits for the statement running now: the writer lets it in between its statements ([reader yield](#reader-yield), on by default). With reader yield off, it waits until the writer's request ends. With [snapshot reads](#snapshot-reads) on, it does not wait |
| `SHOW ...`, `information_schema`, `pg_catalog` | waits: it reads every table (not `pg_locks`, `pg_stat_activity`, `pg_stat_statements`: they read no table) |
| Any read, while a writer runs dynamic SQL (`EXECUTE format(...)`) or a schema change inside a `CALL` | waits: that writer may touch every table |

| During a checkpoint | |
|---|---|
| Writing the partition files (can take seconds) | readers go on; writers wait |
| Taking open transactions out, publishing the new files | everybody waits (milliseconds) |

- **Notes:**
  - Readers still see only committed rows: a table a running writer holds is never read until it is done.
  - A checkpoint that waits for a long writer does not hold readers back meanwhile.
  - `off` goes back to the old rule: every reader waits for every running writer and for the whole checkpoint.

<a id="reader-yield"></a>

## Readers of the writer's tables: reader yield

Syntax:

```sql
kdb serve --reader-yield on|off        (default on)
KDB_READER_YIELD=off                   (the same, for Docker; a flag wins)
```

A writer's request can run for many seconds: a `CALL` that builds a day of candles, an immediate trigger, a request with many statements.
Readers never see its changes before it commits. Readers of **other** tables never wait for it ([above](#per-table-reads)). For readers of **its** tables, this switch decides whether they **wait** meanwhile. The start-up lines say which one is in use (`readers ...`).

| | off | on (default) |
|---|---|---|
| A `SELECT` of the writer's tables while it runs | waits until the writer's request ends | answers soon, with the rows as the last commit left them |
| How | readers and writers take turns at the database | between two statements of the writer's body or request, the writer steps aside and lets waiting readers in. Its table locks stay, so no other writer gets its tables. |
| Cost | none | a pause is free when nobody waits. A reader of a table the writer already changed makes the writer take its changes out and put them back, so the writer keeps at least about two thirds of its time. |

- **Notes:**
  - The pause comes only **between** statements. One long statement (a big `INSERT ... SELECT`, a big `UPDATE`) still makes readers wait until it ends.
  - Readers see a committed state, never half of one: a commit that fills three tables is seen whole or not at all.
  - Writers of other tables do not need this switch: they never wait for each other.
  - The switch is for the whole server, not per database.
  - A deferred trigger job pauses the same way. See [deferred triggers](triggers.md#deferred).

<a id="snapshot-reads"></a>

## Readers of the writer's tables: snapshot reads

Syntax:

```sql
kdb serve --snapshot-reads on|off      (default off)
KDB_SNAPSHOT_READS=on                  (the same, for Docker; a flag wins)
```

With snapshot reads on, a reader of a table that a writer is changing **does not wait**, not even for one long statement. It reads a **snapshot** of the table: the rows committed when the read started.

| | reader yield only | snapshot reads on |
|---|---|---|
| A `SELECT` of `t` while a long `CALL`, trigger job or `INSERT ... SELECT` writes `t` | waits for the statement running now | answers at once, with the committed rows |
| A `SELECT` of `t` while a session's `BEGIN` holds changes of `t` | answers at once (the transaction is taken out for it) | answers at once (the transaction stays in) |
| A read-only `CALL` of `t` | waits like a `SELECT` | reads snapshots, each statement of its body the rows committed when it starts |
| What the writer pays | takes its changes out and puts them back for readers | nothing: when a reader holds a snapshot of a partition it changes next, it leaves the snapshot's unsaved rows as they are and writes on a new layer on top (since 2026-10-02; before, it copied them all) |

- **Notes:**
  - A writer that is about to finish (within 20 ms, a short write and its disk sync) is still waited for: a snapshot for every read of a table written many times a second would slow its writer down. Once a snapshot is taken, readers during the same long writer use it at once.
  - A snapshot never holds uncommitted rows, and never half of a commit: all the tables of one transaction or none of them.
  - A snapshot waits until the rows it holds are on disk, as the writer that made them does.
  - Tables with an index get snapshots too, while a writer is busy on them, **at any size** (since 2026-10-02). A read of the snapshot still uses a plain or expression index (`CREATE INDEX`): it checks each row the index finds against the snapshot, and also finds the rows the writer changed or deleted since. So a lookup stays a lookup, never sees an uncommitted row, and `EXPLAIN` shows the index as usual.
  - A full-text or JSON index is not used on a snapshot, and neither is an index that is not built in memory yet (after a restart, before its first use): such a read scans the snapshot instead. A table like that with more than 1,000,000 rows is not scanned: its readers wait for the writer, as before. `--snapshot-index-rows N` (`KDB_SNAPSHOT_INDEX_ROWS`) moves that line; `0` means indexed tables never get snapshots.
  - An open transaction that sits idle (`BEGIN`, a change, then nothing) gives readers of an indexed table no snapshot: they take it out of their way and use the index on the table itself, as without snapshot reads.
  - Materialized views are still read as before (the reader waits).
  - One statement that writes a table applies its rows in one step at the end. A reader of that same table waits for that step (up to about a second per million rows), never for the whole statement.
  - Readers that use a snapshot, snapshots taken and snapshots reused show in `GET /api/stats` (`snapshot_reads`, `snapshots_taken`, `snapshots_reused`).
  - `GET /api/stats` itself reads snapshots too (since 2026-10-02): the row counts of a table a writer is changing are its committed rows, and it answers at once instead of saying `"busy": true` until the writer is done.
  - **Layers** (since 2026-10-02). The unsaved rows of a partition (changed since the last checkpoint) are shared between the table and its snapshots. A writer that changes such a partition freezes them as a layer and writes on a new one, so its cost is the rows it writes, not the rows the partition holds. Reads merge the layers. When no snapshot holds a layer any more, the next write to the partition folds it back; a checkpoint folds them all. A partition keeps at most 6 layers: past that, the two smallest neighbours become one.
  - `GET /api/stats` counts them since the server started:

| Field | What it counts |
|---|---|
| `snapshot_delta_freezes` | layers frozen because a snapshot held them when a writer came |
| `snapshot_delta_folds` | layers folded back once no snapshot held them |
| `snapshot_delta_merges` | pairs of layers made one (past 6 layers in a partition) |
| `snapshot_delta_copies` | full copies of a partition's unsaved rows (only an `ALTER TABLE` makes one now) |
| `snapshot_delta_layers` | frozen layers the tables hold right now (0 when the stats are read while a job runs) |

  A `snapshot_delta_layers` that stays high while nobody reads means a partition was not written since its last snapshot ended: the next write or checkpoint frees it.

<a id="shared-writers"></a>

## Several writers of one table

Syntax:

```sql
kdb serve --table-writers one|many     (default one)
KDB_TABLE_WRITERS=many                 (the same, for Docker; a flag wins)
```

With `many`, several users change **one table at the same time**, as long as each of their requests touches the table only by **single rows and their primary key**:

| Allowed on the shared table | Not allowed (the request takes the whole table, as before) |
|---|---|
| `INSERT INTO t VALUES (...)` (a row, or a few) | `INSERT ... SELECT`, `ON CONFLICT DO UPDATE` |
| `UPDATE t SET ... WHERE id = x` (`x` a value, a parameter or a procedure variable; the key itself is not set) | `UPDATE ... WHERE balance > 0`, `UPDATE ... FROM`, an `UPDATE` without `WHERE` |
| `DELETE FROM t WHERE id = x` | `DELETE` of a range, with `USING` or `RETURNING` |
| `SET v = (SELECT a, b FROM t WHERE id = x)` in a procedure or trigger body | a `SELECT` statement, a `FOR` loop's query, a view, a CTE, a join |
| a `CALL` or a trigger made of the statements above | `BEGIN ... COMMIT` across requests, `LOCK TABLE`, `SELECT ... FOR UPDATE` |

The table must be a plain table with a one-column `PRIMARY KEY`, no foreign key either way, no other `UNIQUE` column or index, no `AUTO` column, no `FOR EACH ROW` trigger and no materialized view built from it (statement triggers are fine). Other tables of the same request are not affected: each is held shared or whole on its own.

- **What you get:** eight users running a bank-transfer `CALL` no longer take turns on the accounts table; their statements overlap and more of their commits share one disk sync.
- **The same row:** a second writer of a row waits for the first one's end (the lock timeout applies), then reads the row as that writer left it, committed or rolled back: `balance = balance - 10` twice gives the same balance as one after the other, as PostgreSQL's row locks do. Two inserts of one key give one row and one `already exists` (`23505`). A read of a row another writer is changing waits for it: a request never sees a change that is not committed.
- **Deadlock:** two writers that wait for each other's rows get `deadlock: ...` (`40P01`) at once, like two transactions that wait for each other's tables. Run the request again.
- **Readers:** a `SELECT` of the table waits for all of its writers, or reads a snapshot with [snapshot reads](#snapshot-reads) on; it never sees half a statement.
- **The escape hatch:** a request that turns out to need more of the table than its statements showed (rare) takes the whole table for itself, waiting for the other writers to end; `GET /api/stats` counts it in `shared_writer_upgrades`, next to `shared_writers` (requests that held a table shared) and `shared_row_waits`.

<a id="txn-spill"></a>

## Big transactions: log records on disk

Syntax:

```sql
kdb serve --txn-spill-mb 64            (default 64; 0 = never)
KDB_TXN_SPILL_MB=64                    (the same, for Docker; a flag wins)
```

A transaction writes its changes to the log only at `COMMIT`. Until then KDB keeps the **log records** (the changes, ready to be written). A long `CALL`, a [deferred trigger](triggers.md#deferred) job or a big `BEGIN ... COMMIT` can make many of them.

Since 2026-10-02, once they pass **64 MB**, KDB moves them to a temporary file in the database's `_tmp` folder. Only where each record starts stays in memory.

| When | What happens to the file |
|---|---|
| `COMMIT` | read back in order and written into the log, then removed |
| `ROLLBACK` | removed |
| `ROLLBACK TO SAVEPOINT` | cut back to where the savepoint was |
| a crash | removed when the database opens again (those records were never committed) |

- **Notes:**
  - With a memory limit (`--memory-limit`), the line is at most 1/16 of it. Under a 512 MB limit that is 32 MB.
  - Only the log records go to disk. The changed rows themselves stay in memory until `COMMIT`, so a transaction still stops at a quarter of the memory limit ("transaction too big for memory") when its rows alone need that much.
  - Example: one `CALL` that inserts 2 million rows under a 512 MB memory limit was stopped at 1.5 million rows. With its 64 MB of log records on disk it finishes, and the heap stays near 230 MB.
  - A commit of spilled records always waits for the disk, even with `SET synchronous_commit = off`.
  - `GET /api/stats` counts them per database: `txn_spills` (transactions that used a file) and `txn_spilled_bytes`.
  - `0` keeps every record in memory, as before.

**Example: The line where log records go to disk**

```sql
SELECT name, setting, unit, source FROM pg_settings WHERE name = 'txn_spill_mb';
```

Result:

| name (STRING) | setting (STRING) | unit (STRING) | source (STRING) |
|---|---|---|---|
| txn_spill_mb | 64 | MB | default |

(1 row)

<a id="accounting"></a>

## Accounting with CHECK constraints

Syntax:

```sql
balance DECIMAL(2) NOT NULL CHECK (balance >= 0)
BEGIN; UPDATE ...; UPDATE ...; INSERT INTO ledger ...; COMMIT;
```

A `CHECK` constraint (a rule that every row must follow, see [constraints](constraints.md)) makes the database itself refuse a balance below zero. Together with a transaction, a transfer that would break the rule saves **nothing**.

Checklist for money:

1. Money columns are `DECIMAL(2) NOT NULL` (exact, never `DOUBLE`), with `CHECK` rules for what must never happen.
2. Keep a ledger. Never update or delete its rows; correct a mistake with a new transfer back.
3. Every transfer: `BEGIN`, `UPDATE ... SET balance = balance - amount`, `UPDATE ... + amount`, `INSERT INTO ledger`, `COMMIT`. Let the database do the math; do not write a balance that your app computed.
4. On any error: `ROLLBACK`. On `table ... is busy`, `database is busy` or `deadlock`: run the whole transaction again.
5. Check the books every night (the total, and every balance against the ledger), like in the first example of this page.

**Example: A transfer of more than the balance saves nothing** (shows an error)

Setup:

```sql
CREATE TABLE accounts (
  id INT PRIMARY KEY,
  owner STRING NOT NULL,
  balance DECIMAL(2) NOT NULL DEFAULT 0 CHECK (balance >= 0)
);
CREATE TABLE ledger (
  id LONG PRIMARY KEY AUTO,
  from_account INT NOT NULL REFERENCES accounts(id),
  to_account INT NOT NULL REFERENCES accounts(id),
  amount DECIMAL(2) NOT NULL,
  CONSTRAINT positive_amount CHECK (amount > 0)
);
INSERT INTO accounts VALUES (1, 'Ram', 749.50), (2, 'Sita', 250.50);
```

```sql
BEGIN;
UPDATE accounts SET balance = balance + 900 WHERE id = 2;
UPDATE accounts SET balance = balance - 900 WHERE id = 1;
INSERT INTO ledger (from_account, to_account, amount) VALUES (1, 2, 900);
COMMIT;
```

Result:

`BEGIN`

```text
transaction started
```

`UPDATE accounts SET balance = balance + 900 WHERE id = 2`

```text
1 row(s) updated
```

Error: `CHECK constraint 'accounts_balance_check' of table 'accounts' failed: balance >= 0 is false for the row id='1', balance='-150.50' (the transaction was rolled back)`

Without `CHECK` constraints (or in an older KDB), a `BEFORE UPDATE` trigger can refuse the same change: see [triggers](triggers.md#before-after).
