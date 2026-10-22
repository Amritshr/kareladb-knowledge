# 22. PostgreSQL schema compatibility

- Category: Tutorial

## What you will learn

The NChartPro app creates its PostgreSQL tables itself when it starts (`pgdb.CreateAllTables()`). This chapter shows what KDB does with those statements:

- **Part A.** PostgreSQL type names (`SERIAL`, `VARCHAR(n)`, `NUMERIC(p,s)`, `UUID`, `TEXT[]`, ...).
- **Part B.** `CREATE TABLE` forms: constraints, composite keys, `CREATE TABLE ... AS`, `TEMP` tables.
- **Part C.** Foreign keys with `ON DELETE CASCADE`, `SET NULL`, `SET DEFAULT`, `RESTRICT`.
- **Part D.** `ALTER TABLE` forms.
- **Part E.** PostgreSQL index forms: partial and expression indexes.
- **Part F.** Sequences: `nextval`, `currval`, `setval`.
- **Part G.** `CREATE SCHEMA`, `CREATE EXTENSION`, `COMMENT ON`, `DO $$ ... $$` blocks.
- **Part H.** `information_schema` and `pg_catalog` views.
- **Part I.** plpgsql trigger functions and `FOR EACH ROW` triggers: what KDB runs.
- **Part J.** Times: local time and UTC when you move data.
- What is **different** from PostgreSQL, what **older KDB** programs do, and **speed**.

Chapter 14 explains how to connect with the PostgreSQL protocol. This chapter is about the schema (tables, keys, indexes); chapter 23 is about queries and data changes (`ON CONFLICT`, `WITH`, subqueries, arrays). The output under each example is real.

## The short version

| PostgreSQL | KDB |
|---|---|
| `SERIAL`, `BIGSERIAL`, `GENERATED ... AS IDENTITY` | Works for a single-column `PRIMARY KEY` (`AUTO` id). |
| `VARCHAR(n)`, `CHAR(n)`, `NUMERIC(p,s)` | Works. Lengths, precision and scale are checked. |
| `UUID`, `TIME`, `INTERVAL`, `TEXT[]`, `JSONB`, `INET` | Works, with a KDB type underneath (Part A). |
| `PRIMARY KEY (a, b)`, `UNIQUE (a, b)`, `FOREIGN KEY (a, b)` | Works. |
| `ON DELETE CASCADE / SET NULL / SET DEFAULT / RESTRICT`, `ON UPDATE CASCADE` | Works, also inside `BEGIN ... COMMIT`. |
| `ALTER TABLE ... ALTER COLUMN ... TYPE / SET DEFAULT / SET NOT NULL`, `ADD CONSTRAINT` | Works. Rows are checked, or written again. |
| `CREATE UNIQUE INDEX ... (lower(email))`, `... WHERE cond` | Works. |
| `CREATE SEQUENCE`, `nextval('s')` | Works. A number is never given twice, also after a crash. |
| `information_schema.tables / columns / table_constraints`, `pg_indexes`, `pg_constraint`, ... | Read-only views. |
| `DO $$ BEGIN IF ... THEN ...; END IF; END $$` | Works for `IF`, `RAISE` and SQL statements. |
| `CREATE EXTENSION`, `CREATE SCHEMA`, `COMMENT ON` | Accepted. Nothing changes. |
| `CREATE FUNCTION ... RETURNS trigger LANGUAGE plpgsql` with a `BEFORE UPDATE ... FOR EACH ROW` trigger | Works for `IF`, `RAISE EXCEPTION`, `NEW.col := ...` and `RETURN NEW` (Part I). Other plpgsql is refused with a clear message. |

When the app's PostgreSQL startup DDL runs on KDB, **802 of 809** statements work (99%). Before this work it was 198 of 809. The 7 others are listed at the end of the chapter.

---

## Part A: Types

Write the PostgreSQL name. KDB keeps the name (so `SHOW CREATE TABLE` and `information_schema.columns` show it) and stores the value in a KDB type.

| PostgreSQL | KDB stores as | Rule |
|---|---|---|
| `SMALLINT`, `INT2` | `SHORT` | |
| `INTEGER`, `INT`, `INT4` | `INT` | |
| `BIGINT`, `INT8` | `LONG` | |
| `SMALLSERIAL`, `SERIAL`, `BIGSERIAL` | `SHORT` / `INT` / `LONG` `PRIMARY KEY AUTO` | Only as the single-column `PRIMARY KEY`. See below. |
| `GENERATED {ALWAYS \| BY DEFAULT} AS IDENTITY` | same as `SERIAL` | |
| `REAL`, `FLOAT4`, `FLOAT(1..24)` | `FLOAT` | |
| `DOUBLE PRECISION`, `FLOAT8`, `FLOAT(25..53)` | `DOUBLE` | `FLOAT` alone is KDB's 4-byte `FLOAT` (in PostgreSQL it is 8 bytes). |
| `NUMERIC(p,s)`, `DECIMAL(p,s)`, `NUMERIC(p)` | `DECIMAL(s)` | Rounded to `s` places (half away from zero). More than `p` digits → error `numeric field overflow`. `s` at most 18. |
| `NUMERIC` (no precision) | `DOUBLE` | About 15 exact digits. |
| `DECIMAL(s)` (one number) | `DECIMAL(s)` | KDB meaning: `s` is the **scale** (chapter 11). |
| `MONEY` | `DECIMAL(2)` | Rounded to 2 places. |
| `VARCHAR(n)`, `CHARACTER VARYING(n)` | `STRING` | At most `n` **characters** (letters of any language, such as Nepali, count as characters). |
| `CHAR(n)`, `BPCHAR` | `STRING` | At most `n` characters. Not padded with spaces. |
| `TEXT`, `VARCHAR`, `CITEXT`, `NAME` | `STRING` | `CITEXT` is not case-insensitive: use `lower(col)` (and a `lower(col)` index). |
| `BOOLEAN` | `BOOL` | |
| `DATE` | `DATE` | |
| `TIMESTAMP`, `TIMESTAMPTZ`, `TIMESTAMP WITH TIME ZONE` | `TIMESTAMP` | Milliseconds, UTC. Text with an offset (`+05:45`) is converted. See Part J. |
| `TIME`, `TIMETZ` | `STRING` | Checked and written as `HH:MM:SS[.fff][zone]`: `'9:30'` becomes `'09:30:00'`. |
| `INTERVAL` | `LONG` | Milliseconds. `'7 days'` is `604800000`. A month counts as 30 days. |
| `UUID` | `STRING` | Checked. Written in lower case with dashes. |
| `JSON`, `JSONB` | `JSON` | Chapter 18. `jsonb` operators like `@>` are not there. |
| `BYTEA` | `BYTES` | |
| `INET`, `CIDR`, `MACADDR`, `XML` | `STRING` | Not checked. |
| `type[]` (`TEXT[]`, `INT[]`, ...) | `JSON` array | `'{a,"b c",NULL}'` becomes `["a","b c",null]`. Numbers and booleans are checked. |

```sql
CREATE TABLE ev (id SERIAL PRIMARY KEY, at_time TIME, took INTERVAL, at TIMESTAMPTZ);
INSERT INTO ev (at_time, took, at) VALUES ('9:30', '1 day 02:00:00', '2026-09-11 10:00:00+05:45')
  RETURNING at_time, took, at;
```

```text
table 'ev' created

at_time  | took     | at
---------+----------+-------------------------
09:30:00 | 93600000 | 2026-09-11T04:15:00.000Z
(1 row, 8.6 ms)
1 row(s) inserted
```

Errors use the PostgreSQL words, so the app's error checks still work. Over the PostgreSQL protocol they have the PostgreSQL error codes:

| Message | Code |
|---|---|
| `value too long for type VARCHAR(40) (48 characters, at most 40)` | `22001` |
| `numeric field overflow: ...` | `22003` |
| `invalid input syntax for type uuid: 'not-a-uuid'` | `22P02` |

### SERIAL must be the primary key

KDB gives `AUTO` ids only to the `PRIMARY KEY`. A `SERIAL` column that is not the primary key is refused, with the fix in the message:

```text
error: line 1, column 24: column 'code' is SERIAL (or IDENTITY) but not the PRIMARY KEY; in KDB such a column must be the table's single-column PRIMARY KEY (id SERIAL PRIMARY KEY). For other columns use a sequence: code INT NOT NULL DEFAULT nextval('t_serial_code_seq')
```

`AUTO` ids work like a sequence: a failed or rolled back insert also uses up an id, so there can be gaps.

---

## Part B: CREATE TABLE

A small forum, written as PostgreSQL:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS public.forum_users (
  user_id    SERIAL PRIMARY KEY,
  email      VARCHAR(120) NOT NULL UNIQUE,
  name       VARCHAR(40) NOT NULL,
  balance    NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS forum_posts (
  post_id   BIGSERIAL PRIMARY KEY,
  user_id   INTEGER REFERENCES forum_users(user_id) ON DELETE SET NULL,
  parent_id BIGINT REFERENCES forum_posts(post_id) ON DELETE CASCADE,
  title     TEXT NOT NULL,
  tags      TEXT[] NOT NULL DEFAULT '{}',
  public_id UUID NOT NULL DEFAULT gen_random_uuid()
);
CREATE TABLE IF NOT EXISTS post_likes (
  post_id BIGINT NOT NULL,
  user_id INT NOT NULL,
  CONSTRAINT post_likes_pkey PRIMARY KEY (post_id, user_id),
  CONSTRAINT post_likes_post_fk FOREIGN KEY (post_id) REFERENCES forum_posts(post_id) ON DELETE CASCADE,
  CONSTRAINT post_likes_user_fk FOREIGN KEY (user_id) REFERENCES forum_users(user_id) ON DELETE CASCADE
);
COMMENT ON TABLE post_likes IS 'one row per like';
```

```text
extension 'pgcrypto' accepted: its common functions are built in or not needed

table 'forum_users' created

table 'forum_posts' created

table 'post_likes' created

comment accepted (KDB does not keep comments)
```

```sql
INSERT INTO forum_users (email, name) VALUES ('ram@example.com', 'Ram'), ('sita@example.com', 'Sita')
  RETURNING user_id, balance, created_at;
INSERT INTO forum_posts (user_id, title, tags) VALUES (1, 'CITY results', '{bank,"q1 2083"}') RETURNING post_id, tags;
```

```text
user_id | balance | created_at
--------+---------+-------------------------
      1 |    0.00 | 2026-09-11T19:01:54.203Z
      2 |    0.00 | 2026-09-11T19:01:54.203Z
(2 rows, 2.1 ms)
2 row(s) inserted

post_id | tags
--------+-------------------
      1 | ["bank","q1 2083"]
(1 row, 2.1 ms)
1 row(s) inserted
```

The rules are checked for every written row:

```text
INSERT INTO forum_users (email, name, balance) VALUES ('hari@example.com', 'Hari', 12.345) RETURNING user_id, balance;
user_id | balance
--------+--------
      3 |   12.35

INSERT INTO forum_users (email, name) VALUES ('ram@example.com', 'Ram again');
error: column 'email' must be unique: 'ram@example.com' is already used

INSERT INTO forum_posts (user_id, title) VALUES (99, 'Nobody');
error: column 'user_id' = '99' has no matching row in forum_users(user_id)

INSERT INTO forum_users (email, name, balance) VALUES ('gita@example.com', 'Gita', -5);
error: CHECK constraint 'forum_users_balance_check' of table 'forum_users' failed: balance >= 0 is false for the row user_id='5', balance='-5.00'
```

### What CREATE TABLE accepts

| Form | What KDB does |
|---|---|
| `IF NOT EXISTS`, `public.name` | As in PostgreSQL. `public.` and `pg_catalog.` are removed from names. |
| `NOT NULL`, `NULL`, `DEFAULT expr`, `CHECK (...)`, `UNIQUE`, `PRIMARY KEY` | As in PostgreSQL. |
| `REFERENCES t` (no column) | Refers to the primary key of `t`. |
| `CONSTRAINT name ...` | The name is kept. It is used in errors, `DROP CONSTRAINT` and the catalog views. |
| `PRIMARY KEY (a, b)` | Rows are stored by the key. `INSERT OR REPLACE` uses it. |
| `UNIQUE (a, b)` | A unique index named like PostgreSQL (`table_a_b_key`). |
| `FOREIGN KEY (a, b) REFERENCES t (x, y)` | Checked when any part is not NULL (`MATCH SIMPLE`). |
| `GENERATED ALWAYS AS (expr) STORED` | A KDB computed column (worked out when read, not stored). |
| `CREATE TABLE t AS SELECT ...` `[WITH NO DATA]` | Types come from the query. Table and rows are written together. |
| `CREATE TEMP` / `TEMPORARY` / `UNLOGGED TABLE` | A normal table (it stays after the session). |
| `WITH (fillfactor = 70)`, `WITHOUT OIDS`, `TABLESPACE x` | Accepted and ignored. |
| `INHERITS (...)`, `PARTITION BY RANGE (...)` | Refused. Use KDB `TIMESERIES` tables (chapter 3). |
| `DEFERRABLE` | Refused. KDB checks keys at every statement. |

Table constraints (`PRIMARY KEY (...)`, `CONSTRAINT ... CHECK`) must come **after** the columns.

---

## Part C: Foreign key actions

`forum_posts.parent_id` has `ON DELETE CASCADE`, and `post_likes` has `ON DELETE CASCADE` to both tables. Add replies and likes, then delete post 1:

```sql
INSERT INTO forum_posts (user_id, parent_id, title) VALUES (2, 1, 'Good numbers'), (1, 2, 'Agree');
INSERT INTO post_likes VALUES (1, 2), (2, 1), (3, 2);
DELETE FROM forum_posts WHERE post_id = 1;
SELECT post_id, user_id, parent_id, title FROM forum_posts ORDER BY post_id;
SELECT * FROM post_likes ORDER BY post_id;
```

```text
2 row(s) inserted

3 row(s) inserted

1 row(s) deleted

post_id | user_id | parent_id | title
--------+---------+-----------+------
(0 rows, 0.1 ms)

post_id | user_id
--------+--------
(0 rows, 0.1 ms)
```

Post 1 took its reply (2), the reply's reply (3) and all three likes with it. `forum_posts.user_id` has `ON DELETE SET NULL`:

```sql
INSERT INTO forum_posts (user_id, title) VALUES (2, 'Sita post');
DELETE FROM forum_users WHERE user_id = 2;
SELECT post_id, user_id, title FROM forum_posts ORDER BY post_id;
```

```text
1 row(s) inserted

1 row(s) deleted

post_id | user_id | title
--------+---------+----------
      5 |    NULL | Sita post
(1 row, 0.3 ms)
```

| Action | What happens to the rows that refer to the deleted (or changed) row |
|---|---|
| `NO ACTION` (default), `RESTRICT` | The statement is refused: `cannot remove forum_users(user_id) = '1': table 'forum_posts' column 'user_id' still refers to it (foreign key 'forum_posts_user_id_fkey')`. |
| `CASCADE` | `ON DELETE`: they are deleted too (and their children, at most 32 levels). `ON UPDATE`: they get the new key. |
| `SET NULL` | Their column becomes NULL. Refused if the column is `NOT NULL`. |
| `SET DEFAULT` | Their column gets its `DEFAULT`. The default must exist in the parent. |

The rules:

- All changes of one statement, with every cascade, are **one transaction**. If one part fails (a `CHECK`, a `NOT NULL`, a `RESTRICT` deeper down), nothing changes.
- Inside `BEGIN ... COMMIT` it works the same. `ROLLBACK` brings back the parent and all children.
- After a crash, the log has the whole change or none of it.
- KDB finds the child rows with the child's key or an index when there is one. Without one, it reads the child table. For big child tables, add an index on the foreign key column (`CREATE INDEX ... ON child (parent_id)`), as in PostgreSQL.
- A table that another table refers to cannot be dropped (`DROP TABLE ... CASCADE` is not supported).
- In one `INSERT` with many rows, a row can refer to a row **before** it in the same statement (a tree). PostgreSQL also allows a row that comes later.

---

## Part D: ALTER TABLE

```sql
ALTER TABLE forum_users ADD COLUMN IF NOT EXISTS phone VARCHAR(15), ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE forum_users ALTER COLUMN name TYPE VARCHAR(80), ALTER COLUMN balance SET DEFAULT 100;
ALTER TABLE forum_users ALTER COLUMN phone SET NOT NULL;
```

```text
table 'forum_users' altered
table 'forum_users' altered
error: column 'phone' of table 'forum_users' contains NULL values; set them first (UPDATE ... SET phone = ... WHERE phone IS NULL)
```

| Form | What KDB does |
|---|---|
| `ADD [COLUMN] [IF NOT EXISTS] col type [rules]` | Old rows get the `DEFAULT`. |
| `DROP [COLUMN] [IF EXISTS] col [CASCADE]` | Refused while an index, `CHECK` or multi-column key uses the column; `CASCADE` drops them. |
| `ALTER [COLUMN] col SET DEFAULT expr` / `DROP DEFAULT` | Only new rows. |
| `ALTER [COLUMN] col SET NOT NULL` / `DROP NOT NULL` | `SET NOT NULL` checks all rows first. |
| `ALTER [COLUMN] col [SET DATA] TYPE type [USING expr]` | Every row is converted and written again, in the same transaction as the change. A value that does not fit stops it and nothing changes. |
| `RENAME [COLUMN] a TO b`, `RENAME TO new_name` | As in PostgreSQL. |
| `ADD [CONSTRAINT name] UNIQUE (...)` / `PRIMARY KEY (...)` / `FOREIGN KEY (...) REFERENCES ...` / `CHECK (...)` | Existing rows are checked. `ADD PRIMARY KEY` writes the rows again, stored by the new key. |
| `... NOT VALID` | For `CHECK` and `FOREIGN KEY`: old rows are not checked, new rows are. |
| `DROP CONSTRAINT [IF EXISTS] name` | Any named constraint, except the `PRIMARY KEY` (rows are stored by it). |
| Several actions with commas | All of them or none. |
| `ALTER TABLE IF EXISTS`, `ONLY`, `OWNER TO`, `VALIDATE CONSTRAINT` | Accepted. |
| `ENABLE` / `DISABLE TRIGGER name` | KDB triggers (chapter 13). |

`ALTER TABLE` and `CREATE INDEX` cannot be used between `BEGIN` and `COMMIT` (chapter 13). A `DO` block can use them, outside a transaction (Part G).

---

## Part E: Indexes

```sql
CREATE UNIQUE INDEX IF NOT EXISTS uq_forum_users_email_lower ON forum_users (lower(email));
INSERT INTO forum_users (email, name) VALUES ('RAM@example.com', 'Ram 2');
CREATE UNIQUE INDEX IF NOT EXISTS uq_one_admin ON forum_users (is_admin) WHERE is_admin;
CREATE INDEX IF NOT EXISTS idx_posts_tags ON forum_posts USING gin (tags);
SELECT indexname FROM pg_indexes WHERE tablename = 'forum_users' ORDER BY indexname;
```

```text
index 'uq_forum_users_email_lower' created on table 'forum_users' (2 rows)
error: duplicate value violates unique index 'uq_forum_users_email_lower' on table 'forum_users': a row with the same (lower(email)) already exists
index 'uq_one_admin' created on table 'forum_users' (0 rows)
index 'idx_posts_tags' created on table 'forum_posts' (1 rows)

indexname
--------------------------
forum_users_email_key
forum_users_pkey
uq_forum_users_email_lower
uq_one_admin
(4 rows, 0.1 ms)
```

| Form | What KDB does |
|---|---|
| `CREATE [UNIQUE] INDEX [CONCURRENTLY] [IF NOT EXISTS] [name] ON [ONLY] t [USING btree \| hash \| gin \| gist] (...)` | Accepted. Without a name, KDB names it like PostgreSQL (`t_col_idx`). `USING` is only remembered. |
| `(col DESC NULLS LAST, col text_pattern_ops)` | Accepted. The order words are remembered; KDB indexes work both ways. |
| `(lower(email))`, `(COALESCE(a, ''))` | An expression index. |
| `... WHERE condition` | A partial index: only rows where the condition is true. |
| `INCLUDE (...)`, `WITH (...)`, `TABLESPACE` | Accepted and ignored. |
| An index on a `GENERATED` column | Indexes the column's expression. |
| `DROP INDEX [CONCURRENTLY] [IF EXISTS] a, b [CASCADE]` | Drops them. The index of a `UNIQUE` constraint needs `ALTER TABLE ... DROP CONSTRAINT`. |

**Unique** expression and partial indexes are checked on every write (also inside transactions and after `ROLLBACK`). **Non-unique** ones are built and used too: `WHERE lower(email) = 'a@x.np'` uses `(lower(email))`, and a query whose `WHERE` has every part of a partial index's own `WHERE` uses that index. `EXPLAIN` shows it as `use index <name> (...)`. An expression key part works for `expr = constant` only (no ranges, no `IN (...)`, no `ORDER BY` on it); those queries scan.

---

## Part F: Sequences

```sql
CREATE SEQUENCE IF NOT EXISTS invoice_no START WITH 1000;
SELECT nextval('invoice_no') AS a, nextval('invoice_no') AS b;
SELECT setval('invoice_no', 5000);
CREATE TABLE invoices (invoice_no BIGINT PRIMARY KEY DEFAULT nextval('invoice_no'), amount NUMERIC(12,2));
INSERT INTO invoices (amount) VALUES (10), (20) RETURNING invoice_no;
```

```text
sequence 'invoice_no' created

a    | b
-----+-----
1000 | 1001
(1 row, 2.8 ms)

setval('invoice_no', 5000)
--------------------------
                      5000
(1 row, 2.0 ms)

table 'invoices' created

invoice_no
----------
      5001
      5002
(2 rows, 3.9 ms)
2 row(s) inserted
```

| Form | Meaning |
|---|---|
| `CREATE SEQUENCE [IF NOT EXISTS] s [AS type] [INCREMENT [BY] n] [MINVALUE n] [MAXVALUE n] [START [WITH] n] [CACHE n] [[NO] CYCLE] [OWNED BY t.c]` | A new sequence. |
| `ALTER SEQUENCE s RESTART [WITH n]` / `INCREMENT BY n` / ... | Changes it. |
| `DROP SEQUENCE [IF EXISTS] s, ...` | Removes it. |
| `nextval('s')` | The next number. |
| `currval('s')` | The last `nextval` of **this session**. Before that: an error, as in PostgreSQL. |
| `setval('s', n [, is_called])` | The next `nextval` gives `n + 1` (or `n` with `false`). |
| `lastval()` | The last `nextval` of this session, of any sequence. |

**A number is never given twice.** Not after a rollback, not after a restart, not after a crash. KDB writes a mark to the log before it gives out the next 32 numbers. After a crash, the sequence starts after the mark, so a few numbers can be skipped (as in PostgreSQL).

Over HTTP every request is a new session, so `currval` works only inside one request (`SELECT nextval('s'); SELECT currval('s')`). Over the PostgreSQL protocol, the session is the connection.

---

## Part G: Other statements

| Statement | What KDB does |
|---|---|
| `CREATE SCHEMA [IF NOT EXISTS] name` | Accepted: `schema 'reporting' accepted: KDB has no schemas; use a separate database for its tables`. |
| `CREATE EXTENSION [IF NOT EXISTS] pgcrypto` | Accepted for `pgcrypto`, `uuid-ossp`, `citext`, `plpgsql`, `pg_trgm`, `btree_gin`, `btree_gist`, `unaccent`. Other names are refused. |
| `COMMENT ON TABLE / COLUMN / INDEX ... IS '...'` | Accepted. The comment is not kept. |
| `CREATE TEMP TABLE t AS SELECT ...` | A normal table with the rows (`table 'tmp_ids' created with 1 row(s)`). |

### DO blocks

The app uses `DO $$ ... $$` blocks to change the schema only once:

```sql
DO $$ BEGIN
  IF to_regclass('public.forum_posts') IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'forum_posts' AND column_name = 'views') THEN
    ALTER TABLE forum_posts ADD COLUMN views INT NOT NULL DEFAULT 0;
    RAISE NOTICE 'column views added';
  END IF;
END $$;
```

```text
table 'forum_posts' altered; NOTICE: column views added
```

A DO block may use:

- SQL statements (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `ALTER TABLE`, `CREATE INDEX`, `DROP INDEX`, ...), each ending with `;`.
- `IF ... THEN ... [ELSIF ... THEN ...] [ELSE ...] END IF;` The condition can use `EXISTS (SELECT ...)`, `(SELECT count(*) ...)`, `to_regclass('name')`, `information_schema` and `pg_catalog` views.
- `RAISE NOTICE / WARNING / INFO 'text %', value;` adds a line to the message. `RAISE EXCEPTION 'text %', value;` stops with an error.
- `NULL;`

`DECLARE`, `PERFORM`, `EXECUTE`, loops, `RETURN` and `EXCEPTION` handlers are refused with a message. Write a KDB procedure (chapter 13), or do the work in the Go code.

**A DO block is not one transaction.** Each statement is saved when it runs. If a later statement fails, the earlier ones stay. The app's blocks are written to run again safely (they check first), so this is fine for them.

Of the app's 23 DO blocks, 19 work. Two fail only because the test tool joins the lines of the Go source and a `--` comment then hides the rest of the block (in the app they work). One is built by Go code at run time. One (`actionsimport`) compares `count(*)` with a value the tool cannot fill in.

---

## Part H: Catalog views

These read-only views describe the current database. They are made when a query reads them and kept until the schema changes.

| `information_schema` | `pg_catalog` |
|---|---|
| `tables`, `columns`, `views`, `schemata`, `sequences` | `pg_namespace`, `pg_class`, `pg_attribute`, `pg_type`, `pg_database` |
| `table_constraints`, `key_column_usage`, `constraint_column_usage` | `pg_index`, `pg_indexes`, `pg_constraint` |
| `referential_constraints`, `check_constraints` | `pg_tables`, `pg_views`, `pg_sequences` |

Every table is in the schema `public`.

```sql
SELECT column_name, data_type, character_maximum_length AS len, numeric_precision AS p, numeric_scale AS s, is_nullable, column_default
FROM information_schema.columns WHERE table_name = 'forum_users' ORDER BY ordinal_position;
```

```text
column_name | data_type                | len  | p    | s    | is_nullable | column_default
------------+--------------------------+------+------+------+-------------+---------------------------------------------
user_id     | integer                  | NULL |   32 |    0 | NO          | nextval('forum_users_user_id_seq'::regclass)
email       | character varying        |  120 | NULL | NULL | NO          | NULL
name        | character varying        |   80 | NULL | NULL | NO          | NULL
balance     | numeric                  | NULL |   12 |    2 | NO          | 100
created_at  | timestamp with time zone | NULL | NULL | NULL | NO          | now()
mobile      | character varying        |   15 | NULL | NULL | YES         | NULL
is_admin    | boolean                  | NULL | NULL | NULL | NO          | FALSE
(7 rows, 0.3 ms)
```

```sql
SELECT constraint_name, constraint_type FROM information_schema.table_constraints WHERE table_name = 'post_likes' ORDER BY 1;
```

```text
constraint_name    | constraint_type
-------------------+----------------
post_likes_pkey    | PRIMARY KEY
post_likes_post_fk | FOREIGN KEY
post_likes_user_fk | FOREIGN KEY
(3 rows, 0.1 ms)
```

The views have the columns apps and tools use most. They are not complete copies of PostgreSQL's views: `psql`'s `\d` and some ORMs ask for more and may still fail.

---

## Part I: plpgsql functions and triggers

KDB runs a small part of plpgsql: a **trigger function** (`RETURNS trigger ... LANGUAGE plpgsql`) with a `BEFORE UPDATE ... FOR EACH ROW` trigger. This is the form of the app's two trigger functions. KDB runs the body for every changed row.

The body may use:

- `IF ... THEN ... [ELSIF ...] [ELSE ...] END IF`
- `RAISE EXCEPTION 'text with % places', value, ...`
- `NEW.col := value` (change the new row)
- `NEW.col` and `OLD.col` in conditions and values
- `RETURN NEW`

**1. Refuse a change** (`user_register_block_identity_update`):

```sql
CREATE TABLE user_register (user_id SERIAL PRIMARY KEY, email VARCHAR(200), referral_code VARCHAR(20));
INSERT INTO user_register (email, referral_code) VALUES ('ram@example.com', 'R1'), ('sita@example.com', 'S1');

CREATE OR REPLACE FUNCTION user_register_block_identity_update() RETURNS trigger AS $fn$
BEGIN
  IF OLD.email IS NOT NULL AND OLD.email <> '' AND NEW.email IS DISTINCT FROM OLD.email THEN
    RAISE EXCEPTION 'user_register.email is write-once (user %)', OLD.user_id;
  END IF;
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

CREATE TRIGGER trg_user_register_immutable BEFORE UPDATE ON user_register
  FOR EACH ROW EXECUTE FUNCTION user_register_block_identity_update();

UPDATE user_register SET referral_code = 'R2' WHERE user_id = 1;
UPDATE user_register SET email = 'new@example.com' WHERE user_id = 2;
```

```text
trigger function 'user_register_block_identity_update' created (plpgsql, run by KDB for every row a BEFORE UPDATE trigger sees)

row trigger 'trg_user_register_immutable' created on table 'user_register': it runs 'user_register_block_identity_update' for every row of a BEFORE UPDATE

1 row(s) updated
error: trigger 'trg_user_register_immutable' on table 'user_register' stopped the change: user_register.email is write-once (user 2)
```

The `%` is filled in from the row's own `OLD.user_id`. Nothing of the refused `UPDATE` is written.

**2. Change the new row** (`ticker_alias_reset_confirmation`):

```sql
CREATE TABLE ticker_alias (alias_id SERIAL PRIMARY KEY, swap_ratio NUMERIC(10,4), confirmed BOOLEAN NOT NULL DEFAULT FALSE, notes TEXT);
INSERT INTO ticker_alias (swap_ratio, confirmed) VALUES (1.5, TRUE);

CREATE FUNCTION ticker_alias_reset_confirmation() RETURNS trigger AS $$
BEGIN
  IF OLD.confirmed AND NEW.swap_ratio IS DISTINCT FROM OLD.swap_ratio THEN
    NEW.confirmed := FALSE;
    NEW.notes := COALESCE(NEW.notes || ' | ', '') || 'confirmation reset';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ticker_alias_reset_confirmation BEFORE UPDATE ON ticker_alias
  FOR EACH ROW EXECUTE FUNCTION ticker_alias_reset_confirmation();

UPDATE ticker_alias SET swap_ratio = 1.6 WHERE alias_id = 1;
SELECT alias_id, swap_ratio, confirmed, notes FROM ticker_alias;
```

```text
alias_id | swap_ratio | confirmed | notes
---------+------------+-----------+-------------------
       1 |     1.6000 | false     | confirmation reset
(1 row, 0.2 ms)
```

What KDB refuses, with a clear message when you create it (nothing is accepted and then quietly not run):

| You write | KDB says |
|---|---|
| `AFTER UPDATE ... FOR EACH ROW` | `AFTER ... FOR EACH ROW triggers are not supported by KDB; a plpgsql row trigger must be BEFORE (...)` |
| `BEFORE INSERT` or `BEFORE DELETE ... FOR EACH ROW` | `only BEFORE UPDATE ... FOR EACH ROW plpgsql triggers are supported by KDB; INSERT row triggers are not (...)` |
| `DECLARE`, `PERFORM`, loops or SQL statements in the body | the name of the part that is not supported, and what the body may use |
| A function that does not `RETURNS trigger` (`LANGUAGE sql`, for example) | a `WARNING`: the function is recorded but **not run**. Write a KDB function or procedure for it (chapter 13). |

For other work, write a **KDB trigger** (chapter 13). It runs once per statement and sees all changed rows in the tables `OLD` and `NEW`. A KDB trigger and a plpgsql row trigger can be on the same table.

The PostgreSQL function of the app lets a person skip the check with `SET LOCAL nchartpro.allow_identity_update = 'on'`. In KDB, an admin runs `ALTER TABLE user_register DISABLE TRIGGER trg_user_register_immutable`, makes the fix, and runs `ENABLE TRIGGER` again.

---

## Part J: Times (local time and UTC)

KDB stores every `TIMESTAMP` in **UTC** (chapter 4). The NChartPro PostgreSQL server runs with `TZ=Asia/Kathmandu` (Nepal time, +05:45). That matters when you move data:

| PostgreSQL column | What it holds | When you move it to KDB |
|---|---|---|
| `TIMESTAMPTZ` | An exact moment. | Export it **with** its offset (`2026-08-25 10:08:38+05:45`). KDB converts it to UTC. Nothing else to do. |
| `TIMESTAMP` (no time zone) | **Local wall-clock time** (for this app, Nepal time). `DEFAULT CURRENT_TIMESTAMP` and `now()` wrote local time. | **Subtract the zone offset** (5 hours 45 minutes here), or add `+05:45` to the text before you insert it. |
| `DATE` | A calendar day. | Keep it as it is. |
| `TIME` | A clock time ("show at 10:00"). | Keep it as it is. It stays local clock time. |

```sql
SELECT ('2026-08-25 10:08:38' || '+05:45')::TIMESTAMP AS utc;
SELECT '2026-08-25 10:08:38'::timestamp - INTERVAL '5 hours 45 minutes' AS utc;
```

```text
utc
------------------------
2026-08-25T04:23:38.000Z
(1 row, 0.1 ms)

utc
------------------------
2026-08-25T04:23:38.000Z
(1 row, 0.1 ms)
```

After the move:

- `now()` and `CURRENT_TIMESTAMP` in KDB are **UTC**. `WHERE expires_at > now()` is right when both sides are UTC.
- To show local time, add the zone offset (here 5 hours 45 minutes, `20700000` ms): `to_char(blocked_at + 20700000, 'YYYY-MM-DD HH24:MI:SS')`.
- To compare a `TIME` column with the local clock, use the local time: `to_char(now() + 20700000, 'HH24:MI:SS')`.
- Over the PostgreSQL protocol, start `kdb serve` with `--pg-timestamptz` so Go gets the exact moment (chapter 14).

**Never mix** local times and UTC times in one column. Move all rows of a table the same way.

---

## What is different from PostgreSQL

- `SERIAL` and `IDENTITY` only for the single-column primary key.
- `NUMERIC` without precision is a `DOUBLE`. `NUMERIC(p,s)` allows at most 18 decimal places, and the value times 10^s must fit a 64-bit number (about 18 digits).
- `FLOAT` alone is 4 bytes. `CHAR(n)` is not padded. `CITEXT` is not case-insensitive.
- `INTERVAL` is a number of milliseconds; a month is 30 days.
- `TIMESTAMPTZ` and `TIMESTAMP` are the same KDB type (UTC).
- `GENERATED ... STORED` columns are worked out when read, not stored.
- A `DO` block is not one transaction.
- Expression index keys work for `expr = constant` only; ranges, `IN (...)` and `ORDER BY` on them scan.
- The `PRIMARY KEY` of a table cannot be dropped. `DROP TABLE ... CASCADE`, `DEFERRABLE` constraints, `INHERITS` and declarative partitions are not supported.
- Table constraints must come after the columns.
- `CREATE`, `ALTER` and `DROP` are not allowed inside `BEGIN ... COMMIT`.
- Schemas other than `public` do not exist.

## The app's startup DDL on KDB

`node tests/app_compat/run_compat.mjs` replays the app's startup statements: 809 for PostgreSQL and 39 for QuestDB. 802 PostgreSQL statements work (checked on 2026-09-23). The 7 that do not are faults of the test tool, not of KDB:

| Count | What | Why |
|---|---|---|
| 3 | 2 DO blocks and 1 plpgsql function with a `--` comment inside | The test tool joins the lines of the Go source, so the comment hides the rest (the function then has no `END`). With the app's real text, with its line breaks, they work. |
| 1 | The trigger of that function | It fails because its function failed. |
| 1 | The other plpgsql trigger | The test schema still has an old hand-written KDB trigger with the same name. |
| 2 | DO blocks built by Go code at run time (`{{...}}` parts) | The test tool cannot fill in the parts. |

Over the whole app (2,143 statements: reads, writes and startup DDL, PostgreSQL and QuestDB), **1,971 work (92%)** on the same day.

The QuestDB statements (`SYMBOL INDEX`, `TIMESTAMP(ts)`, `DEDUP UPSERT KEYS`, `DROP PARTITION LIST`) are not PostgreSQL. KDB has its own `TIMESERIES` form for them (chapter 10).

## Older KDB programs

A database is written in a way older KDB programs understand, **until** you use a new feature:

| New feature | Stored as | An older KDB program |
|---|---|---|
| PostgreSQL types, named `UNIQUE`, `PRIMARY KEY (a, b)`, `FOREIGN KEY (a, b)`, partial or expression indexes | New parts of the table description (`T`, `K`, `F`, `X`) | Refuses to open the database: `needs a newer KDB`. Nothing is damaged. |
| Sequences | A new file `sequences` and log records | Refuses to open the database: `needs a newer KDB`. |
| plpgsql trigger functions and row triggers | New kinds in the file `routines` (feature `plpgsql_triggers`) | Refuses to open the database: `needs a newer KDB`. |
| `ALTER COLUMN TYPE`, `ADD PRIMARY KEY` | Rows written again, in one transaction with the change | Normal rows. |

Tables that use none of this stay in the old format. **Update every `kdb` program before you run the app's PostgreSQL schema on a database.**

## Speed

- Plain KDB tables pay nothing: the new checks run only for columns with a PostgreSQL rule.
- A `UNIQUE` column uses an index in memory, so an insert does not read the table.
- Foreign key actions look up the child rows with keys and indexes. A child table without an index on the foreign key column is read in full for each deleted parent.
- The catalog views are made once per schema change.
- A `CREATE TABLE`, `ALTER TABLE` or `CREATE INDEX` that changes something takes about 20 ms on the test PC (it saves the table descriptions). An `IF NOT EXISTS` that changes nothing is faster. The whole app check (3,024 requests, with all startup DDL) took 15 seconds.
- `ALTER COLUMN ... TYPE` and `ADD PRIMARY KEY` write every row again: slow for very big tables.
