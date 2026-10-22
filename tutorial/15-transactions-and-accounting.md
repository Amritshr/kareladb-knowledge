# 15. Transactions and accounting

- Category: Tutorial

## What you will learn

- Keep users (register and login) and money (accounts and a ledger) in KDB.
- Stop bad data with **CHECK constraints** (for example: no balance below zero).
- Move money with a **transaction**: all steps are saved, or none.
- Get a new id back with **RETURNING**.
- Keep a transaction open over **many requests** (kdb shell, HTTP, PostgreSQL protocol).
- What happens when many programs write at the same time, and what the **timeouts** do.
- What happens on an **error** and after a **crash**.

The examples use a new, empty database `market`. Each example is a file in `examples/15-transactions-and-accounting/`. The results are real.

## The rules in short

| Rule | What it means for you |
|---|---|
| One writer per table | While one transaction is open, other changes of its tables **wait**; changes of other tables go on. Two transfers never mix. |
| Reads do not wait | A `SELECT` of another program sees the data **as it was before** the open transaction. It never sees half of a transfer. |
| All or nothing | `COMMIT` saves all changes of the transaction in one log write. An error saves nothing. |
| Crash safe | After a crash or power cut, every transaction that got `COMMIT` OK is there. A transaction without `COMMIT` is not there at all. |
| CHECK | A row that breaks a `CHECK` is never written. |

## The tables

```sql
-- Users who can log in, their accounts, and every movement of money.
CREATE TABLE users (
  id INT PRIMARY KEY AUTO,
  email STRING NOT NULL UNIQUE,
  password_hash STRING NOT NULL,
  created TIMESTAMP DEFAULT now()
);

CREATE TABLE accounts (
  id INT PRIMARY KEY AUTO,
  user_id INT NOT NULL REFERENCES users(id),
  balance DECIMAL(2) NOT NULL DEFAULT 0 CHECK (balance >= 0)
);

CREATE TABLE ledger (
  id LONG PRIMARY KEY AUTO,
  from_account INT NOT NULL REFERENCES accounts(id),
  to_account INT NOT NULL REFERENCES accounts(id),
  amount DECIMAL(2) NOT NULL,
  created TIMESTAMP DEFAULT now(),
  CONSTRAINT positive_amount CHECK (amount > 0),
  CONSTRAINT two_accounts CHECK (from_account != to_account)
);
```

```text
table 'users' created

table 'accounts' created

table 'ledger' created
```

Some choices here are important for money:

- **`DECIMAL(2)`** for money, never `DOUBLE`. A `DECIMAL` is exact: `0.10 + 0.20` is `0.30`.
- **`NOT NULL`** on every money column. A `CHECK` lets `NULL` pass, so use both.
- The **ledger** keeps every movement. Never update or delete ledger rows. To undo a transfer, write a new transfer back.

## Register and login

KDB has the functions `password_hash(password)` and `password_verify(password, hash)`. They keep only a salted, slow hash of the password, never the password itself.

```sql
-- Register two users. RETURNING gives the new AUTO id back.
INSERT INTO users (email, password_hash) VALUES ('ram@example.com', password_hash('ram-secret-1')) RETURNING id, email;
INSERT INTO users (email, password_hash) VALUES ('sita@example.com', password_hash('sita-secret-2')) RETURNING id, email;
```

```text
id | email
---+----------------
 1 | ram@example.com
(1 row, 0.9 ms)
1 row(s) inserted

id | email
---+-----------------
 2 | sita@example.com
(1 row, 0.4 ms)
1 row(s) inserted
```

`UNIQUE` refuses a second user with the same email:

```sql
-- The same email again: UNIQUE refuses it.
INSERT INTO users (email, password_hash) VALUES ('ram@example.com', password_hash('other')) RETURNING id;
```

```text
error: column 'email' must be unique: 'ram@example.com' is already used
```

Login: find the user by email and check the password.

```sql
-- Login: find the user by email, check the password against the saved hash.
SELECT id, password_verify('ram-secret-1', password_hash) AS password_ok
FROM users WHERE email = 'ram@example.com';

SELECT id, password_verify('wrong password', password_hash) AS password_ok
FROM users WHERE email = 'ram@example.com';
```

```text
id | password_ok
---+------------
 1 | true
(1 row, 53.8 ms)

id | password_ok
---+------------
 1 | false
(1 row, 50.7 ms)
```

`password_verify` is slow **on purpose** (about 50 ms), so an attacker cannot try many passwords fast. In your app, give the same message for "no such email" and "wrong password".

In a real app, send the email and the password as **parameters** (`$1`, `$2` in the PostgreSQL protocol), never glued into the SQL text.

## RETURNING: get the new id

`INSERT`, `UPDATE` and `DELETE` can end with `RETURNING` and a list of columns or expressions. You get the rows back like from a `SELECT`:

```sql
-- One account for each user. Ram starts with 1000.00.
INSERT INTO accounts (user_id, balance) VALUES (1, 1000), (2, 0) RETURNING id, user_id, balance;
```

```text
id | user_id | balance
---+---------+--------
 1 |       1 | 1000.00
 2 |       2 |    0.00
(2 rows, 2.0 ms)
2 row(s) inserted
```

| Statement | `RETURNING` gives |
|---|---|
| `INSERT` | the new rows, with `AUTO` ids and `DEFAULT` values filled in |
| `UPDATE` | the rows after the change |
| `DELETE` | the deleted rows |

`RETURNING *` gives all columns. If the `RETURNING` list has an error (an unknown column), nothing is written.

## CHECK constraints

A `CHECK` is a rule for every row. KDB checks it on `INSERT`, `INSERT OR REPLACE`, `UPDATE`, `InsertRows` and the line protocol. A row that makes the condition **false** is not written, and the statement fails:

```sql
-- A balance below zero breaks the CHECK constraint: nothing is written.
UPDATE accounts SET balance = balance - 5000 WHERE id = 1;
```

```text
error: CHECK constraint 'accounts_balance_check' of table 'accounts' failed: balance >= 0 is false for the row id='1', balance='-4000.00'
```

The message names the **constraint**, the **table** and the **row** (its key and the columns the rule uses).

Two ways to write a `CHECK`:

```sql
balance DECIMAL(2) NOT NULL CHECK (balance >= 0)              -- after a column
CONSTRAINT positive_amount CHECK (amount > 0)                 -- after the columns, with a name
```

Without a name, KDB makes one: `table_column_check` (for a column) or `table_check`. `SHOW CREATE TABLE` shows every `CHECK` with its name:

```sql
SHOW CREATE TABLE accounts;
```

```text
create_sql
"CREATE TABLE accounts (
  id INT PRIMARY KEY AUTO,
  user_id INT NOT NULL REFERENCES users(id),
  balance DECIMAL(2) NOT NULL DEFAULT 0,
  CONSTRAINT accounts_balance_check CHECK (balance >= 0)
)"
```

Add or remove a rule later:

```sql
ALTER TABLE accounts ADD CONSTRAINT max_balance CHECK (balance <= 10000000);
ALTER TABLE accounts DROP CONSTRAINT max_balance;
```

`ADD` first reads every row of the table. If a row already breaks the rule, the rule is refused, and the message names that row.

| CHECK rule | Detail |
|---|---|
| NULL | `NULL` passes (the result is not false). Add `NOT NULL` when the value must be there. |
| What it can use | The columns of the same row, operators, `CASE`, built-in functions (`length(email) > 3`, `amount BETWEEN 1 AND 100000`). |
| What it cannot use | Other rows, subqueries, aggregates (`sum`), window functions, saved functions, computed columns. |
| Columns | A column used by a `CHECK` cannot be dropped. `RENAME COLUMN` also renames it inside the `CHECK`. |

## A transfer

Moving money needs **four** changes: take money from one account, give it to the other, write the ledger row, and save. They must happen together.

```sql
-- Move 250.50 from account 1 to account 2: all steps together, or none.
BEGIN;
SELECT id, balance FROM accounts WHERE id IN (1, 2) ORDER BY id FOR UPDATE;
UPDATE accounts SET balance = balance - 250.50 WHERE id = 1;
UPDATE accounts SET balance = balance + 250.50 WHERE id = 2;
INSERT INTO ledger (from_account, to_account, amount) VALUES (1, 2, 250.50) RETURNING id;
COMMIT;

SELECT id, balance FROM accounts ORDER BY id;
```

```text
transaction started

id | balance
---+--------
 1 | 1000.00
 2 |    0.00
(2 rows, 0.2 ms)

1 row(s) updated

1 row(s) updated

id
--
 1
(1 row, 0.0 ms)
1 row(s) inserted

transaction committed: 3 change(s) saved

id | balance
---+--------
 1 |  749.50
 2 |  250.50
(2 rows, 0.0 ms)
```

Why each part is there:

| Part | Why |
|---|---|
| `BEGIN` | Starts the transaction. Every table it changes (or reads with `FOR UPDATE`) is locked from then on until `COMMIT` or `ROLLBACK`: no other program can change those tables meanwhile. |
| `SELECT ... FOR UPDATE` | Reads the balances. Your app can check them (for example, show "not enough money" before trying). `FOR UPDATE` tells the reader: these rows are read to be changed. In KDB it locks the table `accounts` at once, so the balances you just read cannot change before your `UPDATE`. Other databases need it too: write it, and your SQL stays correct everywhere. |
| `balance = balance - 250.50` | Let the database do the math, in one statement. **Do not** read the balance in your app, subtract there, and write the result back (`SET balance = 749.50`) outside a transaction: two programs could both read 1000.00. |
| `CHECK (balance >= 0)` | Even if your app forgets to check, the database refuses a negative balance. |
| `RETURNING id` | The ledger id, for the receipt. |
| `COMMIT` | Saves all changes with one log write. |

## When something goes wrong

Ram has 749.50 now. He tries to send 900.00:

```sql
-- Ram has 749.50. A transfer of 900.00 fails at the first UPDATE.
BEGIN;
UPDATE accounts SET balance = balance - 900 WHERE id = 1;
UPDATE accounts SET balance = balance + 900 WHERE id = 2;
INSERT INTO ledger (from_account, to_account, amount) VALUES (1, 2, 900) RETURNING id;
COMMIT;
```

```text
transaction started
error: CHECK constraint 'accounts_balance_check' of table 'accounts' failed: balance >= 0 is false for the row id='1', balance='-150.50' (the transaction was rolled back)
```

The first `UPDATE` fails. The whole transaction is **rolled back**: nothing of it is saved. The books are the same as before:

```sql
-- Nothing of the failed transfer was saved. Check the books.
SELECT id, balance FROM accounts ORDER BY id;

SELECT sum(balance) AS total_money FROM accounts;

SELECT from_account, to_account, count(*) AS transfers, sum(amount) AS moved
FROM ledger GROUP BY from_account, to_account ORDER BY from_account;
```

```text
id | balance
---+--------
 1 |  749.50
 2 |  250.50
(2 rows, 0.2 ms)

total_money
-----------
    1000.00
(1 row, 0.1 ms)

from_account | to_account | transfers | moved
-------------+------------+-----------+-------
           1 |          2 |         1 | 250.50
(1 row, 0.1 ms)
```

Run queries like these every night. The total must not change (except for money that comes in from outside), and every balance must match its ledger rows.

| What happens | Result |
|---|---|
| A statement fails (CHECK, REFERENCES, UNIQUE, a typing error, ...) | The transaction is rolled back. Nothing is saved. |
| Your app sends `ROLLBACK` | Nothing is saved. |
| The client disconnects before `COMMIT` | Rolled back. |
| No statement for 30 seconds | Rolled back (see [Timeouts](#timeouts)). |
| KDB crashes or the power goes off before `COMMIT` returns | Nothing is saved. |
| `COMMIT` returned OK | Saved, also after a crash or power cut. |
| The disk is full at `COMMIT` | `COMMIT` returns an error, and nothing is saved. |

## A transaction over many requests

A transaction can go over many requests when the program keeps a **session**:

- **kdb shell**: one session for the whole shell.
- **HTTP**: `POST /session`, then the header `X-KDB-Session` on every `/exec`.
- **PostgreSQL protocol** (psql, and drivers for Python, Go, Node, Java, .NET): every connection is a session. Use `BEGIN` and `COMMIT` as usual.

Inside a session there is one more rule: **after an error, the session accepts only `ROLLBACK`**. Your next statements do not run by mistake outside the transaction:

```powershell
# In kdb shell, a transaction goes over many lines. After an error, only ROLLBACK is accepted.
@"
BEGIN;
UPDATE accounts SET balance = balance + 10 WHERE id = 2;
UPDATE accounts SET balance = balance - 10000 WHERE id = 1;
UPDATE accounts SET balance = balance + 1 WHERE id = 2;
ROLLBACK;
SELECT id, balance FROM accounts ORDER BY id;
.exit
"@ | kdb shell market
```

```text
KDB 0.2.0-dev shell on market
End statements with ';'. Type .help for commands, .exit to quit.
kdb> transaction started
kdb> 1 row(s) updated
kdb> error: CHECK constraint 'accounts_balance_check' of table 'accounts' failed: balance >= 0 is false for the row id='1', balance='-9250.50' (the transaction was rolled back; send ROLLBACK to end it)
kdb> error: the transaction of this session was rolled back (a statement in it failed); nothing of it was saved. Send ROLLBACK to end it, then start again
kdb> transaction rolled back (it was already rolled back: a statement in it failed)
kdb> id | balance
---+--------
 1 |  749.50
 2 |  250.50
(2 rows, 0.1 ms)
kdb>
```

The third line (`+ 1` for account 2) was **not** run: it would have given money without taking it anywhere. `COMMIT` in this state also fails (`COMMIT saved nothing: ...`), so your app cannot think the transfer was saved.

### Over HTTP

```text
POST   /session                 -> {"session": "<id>", "idle_timeout_ms": 600000}
POST   /exec  (header X-KDB-Session: <id>)   BEGIN, UPDATE, ..., COMMIT
DELETE /session/<id>            -> {"session": "<id>", "closed": true}   an open transaction is rolled back
```

PowerShell:

```powershell
$url = "http://127.0.0.1:9900"
$s = Invoke-RestMethod -Method Post "$url/session"
$h = @{ "X-KDB-Session" = $s.session }
$r = Invoke-RestMethod -Method Post "$url/exec" -Headers $h -Body "BEGIN"
$r.results[0].message
$r = Invoke-RestMethod -Method Post "$url/exec" -Headers $h -Body "UPDATE accounts SET balance = balance - 100 WHERE id = 1 RETURNING balance"
"balance inside the transaction: " + $r.dataset[0][0]
$r = Invoke-RestMethod -Method Post "$url/exec" -Body "SELECT balance FROM accounts WHERE id = 1"
"balance seen by another request: " + $r.dataset[0][0]
$r = Invoke-RestMethod -Method Post "$url/exec" -Headers $h -Body "UPDATE accounts SET balance = balance + 100 WHERE id = 2; INSERT INTO ledger (from_account, to_account, amount) VALUES (1, 2, 100) RETURNING id"
"ledger id: " + $r.results[1].dataset[0][0]
$r = Invoke-RestMethod -Method Post "$url/exec" -Headers $h -Body "COMMIT"
$r.results[0].message
$r = Invoke-RestMethod -Method Post "$url/exec" -Body "SELECT balance FROM accounts WHERE id = 1"
"balance after COMMIT: " + $r.dataset[0][0]
$r = Invoke-RestMethod -Method Delete "$url/session/$($s.session)"
"session closed: " + $r.closed
```

```text
transaction started
balance inside the transaction: 649.50
balance seen by another request: 749.50
ledger id: 2
transaction committed: 3 change(s) saved
balance after COMMIT: 649.50
session closed: True
```

The request **without** the session header saw 749.50: the open transaction was not committed yet.

| HTTP session rule | Detail |
|---|---|
| Id | Random and long, so nobody can guess another client's session. Keep it secret like a password. |
| Unused | A session without a request for 10 minutes is closed (its open transaction was already rolled back after 30 seconds). |
| Unknown or closed id | `/exec` answers `404` with `session '...' does not exist`. |
| Busy | `table 'x' is busy`, `database is busy` and `deadlock` are answered with `503`: try again a moment later. |

## Many programs at the same time

KDB locks **tables**, not the whole database. A writer locks every table it uses until its statement ends; inside `BEGIN` ... `COMMIT` it keeps them until the transaction ends. Two transfers can never mix, and every transaction sees the data exactly as the one before it left it (this is called *serializable*).

- **Writers of the same table wait.** While session A has an open transaction that changed `accounts`, session B's `UPDATE`, `INSERT`, `DELETE` or `CALL` on `accounts` **waits** until A ends. Writers wait in a queue: the one that came first goes first. Line-protocol writes and `InsertRows` into that table wait too.
- **Writers of other tables do not wait.** A price feed into `live_data` goes on while a transfer holds `accounts` and `ledger`.
- **What is locked:** the tables a statement changes and reads, and what it sets off: tables its triggers and procedures use, and tables linked to it by `REFERENCES`.
- **Deadlock:** when A waits for a table B holds, and B then needs a table A holds, one of them gets `deadlock: ...` at once and is rolled back. Run it again. Use the tables in the same order in every transaction (`accounts`, then `ledger`), and it cannot happen.
- **Schema changes** (`CREATE`, `ALTER`, `DROP`, `TRUNCATE`) lock every table. They wait until no transaction is open.
- **Readers do not wait for an open transaction.** Session B's `SELECT` runs at once and sees the data **without** A's changes. Inside A, a `SELECT` sees A's own changes.
- A normal statement without `BEGIN` is its own small transaction, so it also waits for an open transaction that holds its table.
- **Commits share the disk.** Writers that commit at the same moment share one wait for the disk (group commit). Each one is still told "committed" only when its changes are on the disk.

A read can still wait for a writer's **running** statement, usually a millisecond. A long `CALL` or a slow trigger body can make reads wait for seconds. `kdb serve --reader-yield on` (in Docker: `KDB_READER_YIELD=on`) lets reads in between the statements of such a writer: they read the last committed rows at once.

A transfer takes about a millisecond, so waiting is short. It becomes a problem only when a transaction stays open for a long time. **Never** keep a transaction open while you wait for a person (a click, a form, an SMS code). Read first, ask the person, then do `BEGIN ... COMMIT` quickly.

## Timeouts

| Option (`DatabaseOptions`) | Default | What happens |
|---|---|---|
| `lock_timeout_ms` | 5000 (5 s) | A writer that waited this long for a table gets the error `table 'x' is busy: another transaction has held it for N ms; waited 5000 ms ...` (a schema change: `database is busy: ...`). Nothing of its statement was done. Try again. |
| `idle_transaction_timeout_ms` | 30000 (30 s) | A transaction with no statement for this long is rolled back. Its session's next statement gets `the transaction of this session was rolled back (it was open without a statement for ...)`. Send `ROLLBACK` and start again. |

In your app:

- On `table 'x' is busy`, `database is busy` or `deadlock`: wait a little (for example 100 ms) and run the **whole** transaction again.
- On any error inside a transaction: send `ROLLBACK`, then show an error or try the whole transaction again. Never continue with the next statement.

## After a crash

Changes of a transaction are written to the log only at `COMMIT`, in one write, and KDB waits until the disk has them. So:

- a transaction that got `COMMIT` OK is there after a crash or a power cut;
- a transaction without `COMMIT` leaves **no trace**, not even half of a transfer.

KDB tests this all the time. `test_accounting` runs 8 threads doing 2,000 random transfers (with errors, rollbacks and clients that go away) while readers check the total at every moment, and copies the database folder in the middle of open transactions and opens the copies. `crash_test` kills a program doing transfers more than 200 times at random moments and checks every time: the total is the same, no balance is negative, the ledger matches the balances, and every confirmed transfer is there.

## Checklist for an accounting app

1. Money columns: `DECIMAL(2) NOT NULL`, with `CHECK` rules for what must never happen (`balance >= 0`, `amount > 0`).
2. Keep a ledger. Never update or delete its rows; correct a mistake with a new row.
3. Every transfer: `BEGIN`, `SELECT ... FOR UPDATE`, `UPDATE ... SET balance = balance ± amount`, `INSERT INTO ledger ... RETURNING id`, `COMMIT`.
4. On any error: `ROLLBACK`. On `table 'x' is busy`, `database is busy` or `deadlock`: try the whole transaction again.
5. Keep transactions short. No waiting for people inside a transaction.
6. Use parameters (`$1`), not SQL glued together from user input.
7. Store `password_hash(...)`, check with `password_verify(...)`.
8. Check the books every night (total, and balances against the ledger), and make a backup (chapter 9).

## Try it yourself

1. Add a rule so that one transfer can move at most 50,000.00.
2. Ram sends 100.00 to himself (account 1 to account 1). What happens?
3. Your app does: `SELECT balance FROM accounts WHERE id = 1` (749.50), then without `BEGIN`: `UPDATE accounts SET balance = 649.50 WHERE id = 1`. Why is this wrong, even with the `CHECK`?

<details>
<summary>Answers</summary>

1. `ALTER TABLE ledger ADD CONSTRAINT max_amount CHECK (amount <= 50000);`
2. The ledger `INSERT` breaks `CHECK (from_account != to_account)` (`two_accounts`). The transaction is rolled back, so the two `UPDATE`s before it are undone too.
3. Between the `SELECT` and the `UPDATE`, another program can change the balance (for example, a transfer in or out). Your `UPDATE` then writes an old number and the other change is lost. Use `balance = balance - 100` inside `BEGIN ... COMMIT`.

</details>

---

Back to the index. Also read the [known limitations](known-limitations.md).
