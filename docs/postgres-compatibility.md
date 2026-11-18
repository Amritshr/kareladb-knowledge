# PostgreSQL compatibility matrix

> One row per PostgreSQL feature - protocol, statements, queries, types, functions, catalogs - saying whether it works and is tested, works with a difference, or is refused, and which test file covers it.

- Category: Postgres protocol
- Keywords: postgresql compatibility, compatible with PostgreSQL, PostgreSQL support, compatibility matrix, supported, not supported, refused, differences from PostgreSQL, PostgreSQL features, what works, what does not work, migrate from PostgreSQL, ORM, Prisma, SQLAlchemy, Django, JDBC, extensions, pg\_stat, ON CONFLICT, REPEATABLE READ, NUMERIC, schemas, inheritance, partitioning, tablespace, EXCLUDE, DEFERRABLE, tsvector, range types, hstore, PostGIS, COPY, LISTEN, logical replication, SCRAM, md5
- See also: [PostgreSQL protocol (port 8832)](postgres-protocol.md), [Transactions](transactions.md), [Column types](column-types.md), [Limits](limits.md), [PostgreSQL-compatible functions](functions-postgres.md), [Time and time zones](time-and-time-zones.md), [The procedure language](procedure-language.md)

KarelaDB is **not** PostgreSQL. It speaks PostgreSQL's wire protocol on port 8832 ([PostgreSQL protocol](postgres-protocol.md)) and understands a large part of PostgreSQL's SQL. This page says, feature by feature, what you can expect. It was written from the program's code and tests on 2026-10-25, and every statement marked *by hand* was run on a build of that day.

<a id="legend"></a>

## How to read the tables

| Mark | Meaning |
|---|---|
| **Yes** | Works as in PostgreSQL, and an automated test covers it (the file is in the last column). |
| **Yes, by hand** | Works as in PostgreSQL. It was run by hand on 2026-10-25, but no automated test is named for it. It can still break without a test failing. |
| **Differs** | Works, but the answer, the rules or the limits are not PostgreSQL's. The column says how. Read it before you move an application. |
| **Refused** | KarelaDB refuses it with an error that names the problem. Nothing is run and nothing is saved. A few rows say *accepted and ignored*: the statement is accepted so that tools do not stop, and does nothing. |

The tests are in `tests/`. `test_pg*.cpp` run a real PostgreSQL client against a real server. `tests/pg_go/main.go` (the pgx driver) and `tests/pg_python/check_pg8000.py` (the pg8000 driver) are run by hand against a server.

Rows that say **Differs** or **Refused** are the ones to plan for. The ones that matter most for an application that moves from PostgreSQL:

| Difference | Where |
|---|---|
| `REPEATABLE READ` is a table lock, not a snapshot | [transactions](#transactions) below |
| `NUMERIC` with no precision is a `DOUBLE` column | [types](#types) below |
| `7 / 2` is `3.5` and text sorts by bytes, unless `kdb.pg_compat` is on | [options](#options) below |
| There are no schemas except `public` | [objects](#objects) below |
| A `TIMESTAMP` is in milliseconds, not microseconds | [types](#types) below |
| `CREATE PROCEDURE ... LANGUAGE plpgsql AS $$ ... $$` is not accepted | [functions and procedures](#routines) below |

<a id="options"></a>

## Settings that change the answers

Three settings make KarelaDB answer like PostgreSQL where it does not by default. All are off by default and do not change anything while off.

| Setting | Effect | Details |
|---|---|---|
| `SET kdb.pg_compat = on` (or `--pg-compat on`, or `ALTER DATABASE ... SET pg_compat = on`) | PostgreSQL 14's answers: exact decimal literals and `::numeric`, `RANGE` window frames, PostgreSQL's `NULL` order in windows, `en_US` text order, a plain `TIMESTAMP` as the session's wall clock | [PostgreSQL-compatible results](postgres-protocol.md#pg-compat) |
| `SET int_division = integer` (or `--pg-int-division on`) | whole number / whole number gives a whole number | [integer division](postgres-protocol.md#int-division) |
| `--pg-timestamptz` | `TIMESTAMP` columns are sent as `timestamptz` | [times](postgres-protocol.md#times) |

Tests: `tests/test_pg_compat.cpp`, `tests/test_pg.cpp`.

<a id="protocol"></a>

## Protocol and connection

| Feature | Status | What is different, or what happens | Tested by |
|---|---|---|---|
| Simple query protocol (psql, `Query` message) | Yes | | `tests/test_pg.cpp` |
| Extended protocol: `Parse`, `Bind`, `Describe`, `Execute`, `Sync`, named and unnamed statements and portals | Yes | A prepared statement whose table changed shape (a column added) gets `0A000` `cached plan must not change result type`; prepare it again. The type of a `$1` comes from where it is used. | `tests/test_pg.cpp`, `tests/pg_go/main.go` |
| Row limits on `Execute` (JDBC `setFetchSize`) | Yes | | `tests/test_pg.cpp` |
| Binary parameters and binary results | Yes | The types are in [PostgreSQL protocol: types](postgres-protocol.md#types) | `tests/test_pg.cpp`, `tests/pg_go/main.go` |
| Pipelines and batches (several `Execute`, one `Sync`; pgx `SendBatch`, JDBC `executeBatch`) | Yes | The whole pipeline waits for one disk sync | `tests/test_pg.cpp`, `tests/pg_go/main.go` |
| `COPY ... FROM STDIN` and `COPY ... TO STDOUT` (text, CSV, binary) | Yes | One transaction. A very big `COPY` gets `54000` | `tests/test_pg.cpp` |
| `COPY ... FROM 'file'` and `TO 'file'` (a file on the server) | Refused | Use `FROM STDIN` / `TO STDOUT`; `\copy` in psql does. For a file on the server use [read_csv](loading-data.md#read-csv) | `tests/test_pg.cpp` |
| Login with SCRAM-SHA-256 | Yes | The only password method offered | `tests/test_pg.cpp`, `tests/test_users.cpp`, `tests/test_crypto.cpp` |
| Login with `md5`, a cleartext password, or channel binding (`SCRAM-SHA-256-PLUS`) | Refused | The server only asks for SCRAM-SHA-256, so a client that can do nothing else cannot log in. A client that picks another SASL mechanism gets `28000`; one that asks for channel binding gets `08P01` | code in `src/server/pg_server.cpp` |
| Login with GSSAPI/Kerberos, SSPI, client certificates, LDAP | Refused | Not offered; a GSS encryption request is answered `N` (no) | code in `src/server/pg_server.cpp` |
| TLS (`SSLRequest`, `sslmode=require`, `verify-full`) | Yes | Needs `--tls-cert`. Without it, `sslmode=require` fails | `tests/test_tls.cpp` |
| `CancelRequest` (Ctrl+C in psql) | Yes | | `tests/test_protection.cpp` |
| `pg_cancel_backend`, `pg_terminate_backend` | Yes | | `tests/test_backends.cpp` |
| `NegotiateProtocolVersion` (a newer client) | Yes, by hand | Answers with protocol 3.0 | code in `src/server/pg_server.cpp` |
| Startup parameters (`options=-c ...`, `timezone`, `application_name`, `kdb.pg_compat`, `int_division`) | Yes | | `tests/test_pg.cpp` |
| `LISTEN`, `NOTIFY`, `pg_notify()`, `UNLISTEN` | Yes | Notifications are sent when the transaction commits. See [LISTEN and NOTIFY](listen-notify.md) | `tests/test_pg.cpp`, `tests/console/notify-ttl.test.mjs` |
| `SET`, `SHOW`, `RESET`, `SHOW ALL` | Differs | Names are checked against KarelaDB's own list of settings ([settings](server-settings.md)); an unknown name gives `42704`. Settings that PostgreSQL has and KarelaDB does not use are accepted and kept for the client | `tests/test_pg.cpp`, `tests/test_backends.cpp` |
| `SET statement_timeout`, `idle_in_transaction_session_timeout`, `idle_session_timeout`, `lock_timeout` | Yes | | `tests/test_protection.cpp`, `tests/test_backends.cpp`, `tests/test_table_locks.cpp` |
| `SET synchronous_commit = off` | Yes | The disk sync follows within about 10 ms. See [performance tips](performance-tips.md#synchronous-commit) | `tests/test_pg.cpp`, `tests/test_database.cpp` |
| Function-call messages (the old `F` message) | Refused | `08P01` | code in `src/server/pg_server.cpp` |
| Streaming replication, logical decoding, `pg_dump`, `pg_basebackup` | Refused | Not implemented. Use [backups](backup-and-safety.md), a [standby](standby.md) or the [change stream](change-stream.md) | not tested |
| More than 500 connections | Differs | `53300` after 500 logged-in connections (`--max-connections`) | `tests/test_pg.cpp` |

<a id="transactions"></a>

## Transactions and locking

| Feature | Status | What is different, or what happens | Tested by |
|---|---|---|---|
| `BEGIN`, `COMMIT`, `ROLLBACK`, `START TRANSACTION`, `END`, `ABORT` | Yes | A failed statement aborts the transaction (`25P02` after it), as in PostgreSQL | `tests/test_pg.cpp`, `tests/test_procedures.cpp` |
| `SAVEPOINT`, `RELEASE`, `ROLLBACK TO` | Yes | | `tests/test_pg.cpp`, `tests/test_procedures.cpp` |
| `READ COMMITTED` | Differs | A plain `SELECT` takes no lock and sees what is committed when it starts. A write still locks its table or rows until the end. See [visibility rules](transactions.md#isolation-rules) | `tests/test_pg.cpp`, `tests/test_row_locks.cpp`, `tests/test_procedures.cpp` |
| `READ UNCOMMITTED` | Yes | Works as `READ COMMITTED`, as in PostgreSQL | `tests/test_pg.cpp` |
| `SERIALIZABLE` (KarelaDB's default; PostgreSQL's default is `READ COMMITTED`) | Differs | By locks, not by conflict detection: a reader of a table holds it until the end, and a writer that waits too long gets `40001`. See [visibility rules](transactions.md#isolation-rules) | `tests/test_pg.cpp`, `tests/test_table_locks.cpp` |
| `REPEATABLE READ` | Differs | **Runs as `SERIALIZABLE`.** There is no snapshot of the database at `BEGIN`. `SHOW transaction_isolation` still says `repeatable read` | `tests/test_pg.cpp` (the level is accepted); the behaviour is in [transactions](transactions.md#isolation-rules) |
| `BEGIN READ ONLY`, `SET TRANSACTION READ ONLY`, `default_transaction_read_only` | Yes | `25006` for a change | `tests/test_pg.cpp`, `tests/test_server.cpp` |
| `DEFERRABLE` transactions | Differs | Accepted; changes nothing | by hand |
| `SELECT ... FOR UPDATE [NOWAIT \| SKIP LOCKED]` | Differs | Row locks on a table with a primary key, one table, no join. `FOR SHARE`, `FOR NO KEY UPDATE`, `FOR KEY SHARE` take the same lock as `FOR UPDATE` (stricter than PostgreSQL). See [FOR UPDATE](transactions.md#for-update) | `tests/test_row_locks.cpp`, `tests/test_reader_tables.cpp`, `tests/test_pg.cpp` |
| Row-level locks for `UPDATE` / `DELETE` | Differs | By primary key only. An `INSERT` still holds the whole table until `COMMIT` | `tests/test_row_locks.cpp` |
| `LOCK TABLE` (all eight modes) | Yes | | `tests/test_table_locks.cpp` |
| Deadlock detection (`40P01`) | Yes | | `tests/test_table_locks.cpp` |
| Advisory locks (`pg_advisory_lock`, `pg_advisory_xact_lock`, `pg_try_...`, `..._shared`, `pg_advisory_unlock_all`) | Yes | A wait ends after 30 seconds | `tests/test_pg_dml.cpp`, `tests/test_pg.cpp`, `tests/test_backends.cpp` |
| `PREPARE TRANSACTION` / `COMMIT PREPARED` (two-phase commit) | Refused | Syntax error | by hand |
| SQL-level `PREPARE name AS ...` / `EXECUTE name` | Refused | Syntax error in KarelaDB SQL. The protocol-level prepared statements of every driver work; `DEALLOCATE` and `DISCARD ALL` are accepted | by hand; `tests/test_pg.cpp` for `DISCARD` |
| `DECLARE ... CURSOR`, `FETCH`, `CLOSE` | Differs | 16 open cursors per database, 10 million rows each ([cursors](cursors.md)) | `tests/test_procedures.cpp`, `tests/test_server.cpp` |
| DDL inside `BEGIN ... COMMIT` | Refused | `cannot be used inside a transaction` for `CREATE`, `ALTER`, `DROP`. PostgreSQL allows it | `tests/test_procedures.cpp` |
| Serialization failure `40001` | Differs | Comes from a lock wait that ran out, not from a conflict check | `tests/test_table_locks.cpp` |

<a id="dml"></a>

## Statements: writing data

| Feature | Status | What is different, or what happens | Tested by |
|---|---|---|---|
| `INSERT ... VALUES`, multi-row | Yes | | `tests/test_pg_dml.cpp` |
| `INSERT ... SELECT` | Yes | | `tests/test_pg_dml.cpp`, `tests/test_database.cpp` |
| `INSERT ... ON CONFLICT (cols) DO UPDATE / DO NOTHING`, `EXCLUDED`, `ON CONSTRAINT`, a `WHERE` on the target and on `DO UPDATE` | Yes | The target must be a key (primary key or unique) | `tests/test_pg_dml.cpp` |
| `INSERT OR REPLACE`, `INSERT OR IGNORE` | Differs | KarelaDB's own spelling; not PostgreSQL's. See [INSERT](insert.md) | `tests/test_database.cpp` |
| `RETURNING` on `INSERT`, `UPDATE`, `DELETE`, `MERGE` | Yes | `RETURNING` does not return rows an `ON CONFLICT DO NOTHING` skipped, as in PostgreSQL | `tests/test_pg_dml.cpp`, `tests/test_merge.cpp`, `tests/test_pg.cpp` |
| `UPDATE ... FROM` | Yes | | `tests/test_pg_dml.cpp` |
| `DELETE ... USING` | Yes | | `tests/test_pg_dml.cpp` |
| `MERGE` | Yes | `WHEN MATCHED / NOT MATCHED [BY SOURCE]`, `RETURNING`. Refused into a table with row-level security policies for the user | `tests/test_merge.cpp` |
| `TRUNCATE` | Yes | | `tests/test_sql_features.cpp`, `tests/test_server.cpp` |
| Data-modifying CTE (`WITH x AS (UPDATE ... RETURNING ...)`) | Yes | | `tests/test_pg_dml.cpp` |
| `SELECT ... INTO newtable` | Refused | Syntax error. Use `CREATE TABLE ... AS SELECT` | by hand |
| `COPY` | See [protocol](#protocol) | | |
| `ALTER SYSTEM`, `VACUUM`, `ANALYZE`, `REINDEX`, `CLUSTER` | Refused | Syntax error ("expected a statement"). KarelaDB needs none of them: statistics are kept as it writes ([saved stats](performance-tips.md#saved-stats)) | by hand |
| `CHECKPOINT` | Yes, by hand | Writes the changes to the files | by hand |

<a id="objects"></a>

## Statements: tables, indexes and other objects

| Feature | Status | What is different, or what happens | Tested by |
|---|---|---|---|
| `CREATE TABLE` with `PRIMARY KEY`, `NOT NULL`, `UNIQUE`, `DEFAULT`, `CHECK` | Yes | | `tests/test_pg_ddl.cpp` |
| `FOREIGN KEY ... REFERENCES`, `ON DELETE / ON UPDATE CASCADE \| SET NULL \| RESTRICT \| NO ACTION` | Yes | A foreign key is checked at every statement | `tests/test_pg_ddl.cpp`, `tests/test_pg.cpp` |
| `DEFERRABLE INITIALLY DEFERRED` constraints | Refused | `DEFERRABLE constraints are not supported` | `tests/test_pg.cpp` |
| `EXCLUDE` constraints | Refused | `EXCLUDE constraints are not supported by KarelaDB` | by hand |
| `SERIAL`, `BIGSERIAL`, `SMALLSERIAL` | Differs | The column must be the table's single-column primary key ([tutorial chapter 22](../tutorial/22-postgresql-compatibility.md)) | `tests/test_pg_ddl.cpp` |
| `GENERATED ALWAYS AS IDENTITY` | Differs | Same rule: the identity column must be the primary key | `tests/test_pg_ddl.cpp` |
| `GENERATED ALWAYS AS (expr) STORED` | Yes | | `tests/test_pg_ddl.cpp` |
| `CREATE TEMP TABLE` | Differs | One session's (the session's name for it is mangled in `SHOW TABLES`) | `tests/test_server.cpp`, `tests/test_pg_ddl.cpp` |
| `CREATE UNLOGGED TABLE` | Refused | `every KarelaDB table is written to the log and kept. Use CREATE TABLE` | `tests/test_pg_ddl.cpp` |
| `CREATE TABLE ... (LIKE other)` | Refused | List the columns | by hand |
| `CREATE TABLE ... AS SELECT` | Yes | | `tests/test_database.cpp`, `tests/test_correct_006.cpp` |
| Inheritance (`INHERITS`) and declarative partitioning (`PARTITION BY RANGE ...` of a table with partitions) | Refused | Use `TIMESERIES(time) PARTITION BY DAY \| MONTH \| YEAR` ([partitions](partitions-and-dedup.md)) | `tests/test_pg.cpp` |
| `TABLESPACE` | Differs | Accepted and ignored | by hand |
| Schemas other than `public` (`CREATE SCHEMA`, `s1.t`) | Differs | `CREATE SCHEMA` is accepted and does nothing. `s1.t` is read as table `t` of **database** `s1`. Use separate databases ([cross-database queries](cross-database-queries.md)) | `tests/test_pg_ddl.cpp` |
| `public.t` | Yes | The same as `t` | by hand |
| `ALTER TABLE ... ADD / DROP COLUMN [IF [NOT] EXISTS]`, `RENAME COLUMN`, `RENAME TO` | Yes | | `tests/test_pg_ddl.cpp`, `tests/test_catalog.cpp` |
| `ALTER COLUMN ... TYPE`, `SET / DROP DEFAULT`, `SET / DROP NOT NULL` | Differs | A type change rewrites the table. The type of a time column, of a `SORT BY` column and of a `DEDUP KEY` column cannot change ([alter table](alter-table.md)) | `tests/test_pg_ddl.cpp`, `tests/test_schema_beside_writers.cpp` |
| `ALTER TABLE ... ADD CONSTRAINT` (check, unique, foreign key, primary key) | Yes | | `tests/test_pg_ddl.cpp` |
| `ALTER TABLE ... SET SCHEMA`, `OWNER TO` | Refused | Syntax error | by hand |
| `DROP TABLE [IF EXISTS]` | Differs | Refused while a view, materialized view or foreign key uses the table; `CASCADE` drops them | `tests/test_database.cpp`, `tests/test_correct_006.cpp` |
| `CREATE INDEX` (also `UNIQUE`, partial `WHERE`, expression, `IF NOT EXISTS`, `CONCURRENTLY`) | Differs | `CONCURRENTLY` is accepted. Two indexes on the same columns are refused. `USING gin`, `hash` and `brin` are accepted | `tests/test_indexes.cpp`, `tests/test_pg_ddl.cpp` |
| Views (`CREATE [OR REPLACE] VIEW`) | Differs | The view's query must start with `SELECT`: a view that starts with `WITH` is refused (put the `WITH` inside a subquery) | `tests/test_view_pushdown.cpp`, `tests/test_database.cpp` |
| Materialized views | Differs | Must be a `GROUP BY` over a time bucket of a time-partitioned table, refreshed by partition ([materialized views](views.md#materialized-view)) | `tests/test_mviews.cpp` |
| `CREATE SEQUENCE`, `nextval`, `currval`, `setval`, `lastval` | Yes | | `tests/test_pg_ddl.cpp`, `tests/test_pg.cpp` |
| `CREATE TYPE ... AS ENUM` | Yes | `ALTER TYPE ... ADD VALUE` works | `tests/test_enum_types.cpp` |
| `CREATE TYPE ... AS (composite)`, range types, `CREATE DOMAIN` | Refused | Syntax error ("expected TABLE, VIEW, ...") | by hand |
| `CREATE EXTENSION` | Differs | Accepted and ignored: the common functions of `pgcrypto`, `uuid-ossp`, `pg_trgm` are built in. Others (PostGIS, `hstore`, `ltree`, `cube`) are not there | `tests/test_pg_ddl.cpp` |
| `CREATE RULE`, `CREATE EVENT TRIGGER`, `CREATE PUBLICATION`, `CREATE SUBSCRIPTION`, foreign data wrappers and `CREATE FOREIGN TABLE` | Refused | Syntax error. KarelaDB has its own `CREATE RULE name ON table CHECK (...)` | by hand |
| `COMMENT ON` | Yes | Shown by `obj_description` and `\d+` | `tests/test_pg_ddl.cpp`, `tests/test_pg.cpp`, `tests/test_users.cpp` |
| `GRANT`, `REVOKE` | Differs | Rights are per database, table and column, for KarelaDB users ([table rights](table-rights.md)) | `tests/test_users.cpp` |
| `CREATE ROLE`, `ALTER ROLE` | Refused | Use `CREATE USER` ([users and roles](users-and-roles.md)). `SET ROLE name` takes a KarelaDB user's rights | `tests/test_users.cpp`, `tests/test_pg.cpp` |
| Row-level security (`CREATE POLICY`, `ENABLE ROW LEVEL SECURITY`, `pg_policies`) | Yes | See [row rights](table-rights.md#row-rights). `MERGE` into such a table is refused | `tests/test_pg.cpp`, `tests/test_protection.cpp`, `tests/test_merge.cpp` |

<a id="routines"></a>

## Functions and procedures

| Feature | Status | What is different, or what happens | Tested by |
|---|---|---|---|
| `CREATE FUNCTION ... LANGUAGE plpgsql` that `RETURNS TABLE`, `SETOF`, or has `OUT` parameters | Yes | The body runs once per call. A function a query calls only reads | `tests/test_plpgsql_functions.cpp` |
| `CREATE FUNCTION ... RETURNS INT / TEXT / ...` (one plain value) | Differs | **Recorded, but never run.** KarelaDB prints a `WARNING` when you create it. Use a [saved function](saved-functions.md) for a one-value function | `tests/test_plpgsql_functions.cpp` |
| `CREATE FUNCTION ... LANGUAGE sql` | Differs | Same as the row above | by hand |
| `CREATE FUNCTION ... RETURNS trigger` and `CREATE TRIGGER ... FOR EACH ROW EXECUTE FUNCTION` | Differs | `BEFORE` and `AFTER` row triggers on `INSERT`, `UPDATE`, `DELETE`. A `BEFORE` trigger whose function changes the trigger's own table is refused when the trigger is made. A table with triggers cannot be dropped or renamed until they are dropped | `tests/test_row_triggers_before.cpp`, `tests/test_row_triggers_after.cpp` |
| `FOR EACH STATEMENT` triggers with `EXECUTE FUNCTION`, `INSTEAD OF` triggers | Refused | Write a KarelaDB trigger (`CREATE TRIGGER ... EXECUTE BEGIN ... END`), which already runs once per statement | `tests/test_procedures.cpp` |
| `CREATE PROCEDURE ... AS $$ ... $$ LANGUAGE plpgsql` | Refused | KarelaDB's form is `CREATE PROCEDURE p() AS BEGIN ... END` ([procedures](procedures.md)). `OUT` parameters of procedures are not there | `tests/test_procedures.cpp` |
| `CALL` | Yes | | `tests/test_procedures.cpp` |
| `DO $$ ... $$` | Differs | Only `IF`, `RAISE`, `NULL` and SQL statements. `DECLARE`, loops, `PERFORM`, `EXECUTE` and `EXCEPTION` are refused (write a [procedure](procedures.md) for those). A DO block is not one transaction: statements before an error stay | `tests/test_pg_ddl.cpp`, `tests/test_pg.cpp` |
| In procedures: `EXCEPTION WHEN ...`, `RAISE ... USING ERRCODE`, `LOOP`, `EXIT`, `CONTINUE`, `CASE` | Yes | An error that no `WHEN` names ends the `CALL` and undoes it | `tests/test_procedures.cpp`, `tests/test_plpgsql_functions.cpp` |
| Other languages (`plpython`, `plperl`, `plv8`, C) | Refused | | not tested |

<a id="queries"></a>

## Queries

| Feature | Status | What is different, or what happens | Tested by |
|---|---|---|---|
| `JOIN` (inner, `LEFT`, `RIGHT`, `FULL`, `CROSS`), `USING`, `NATURAL JOIN` | Yes | | `tests/test_joins.cpp`, `tests/test_sql_features.cpp` |
| `LATERAL` | Yes | | `tests/test_pg_dml.cpp`, `tests/test_sql_features.cpp` |
| Correlated subqueries, `EXISTS`, `IN (SELECT ...)`, scalar subqueries | Yes | | `tests/test_pg_dml.cpp`, `tests/test_sql_features.cpp` |
| `WITH` (CTE), `WITH RECURSIVE` | Yes | A recursive query stops at 100,000 rounds or 10 million rows | `tests/test_pg_dml.cpp` |
| `UNION [ALL]`, `INTERSECT`, `EXCEPT` | Yes | | `tests/test_pg_dml.cpp`, `tests/test_vector.cpp` |
| `DISTINCT ON` | Yes | | `tests/test_pg_dml.cpp`, `tests/test_select.cpp` |
| `GROUPING SETS`, `ROLLUP`, `CUBE` | Yes | | `tests/test_sql_features.cpp`, `tests/test_sql_parser.cpp` |
| `GROUP BY` ordinal (`GROUP BY 1`), `HAVING` | Yes | | `tests/fuzz_test.cpp`, `tests/test_sql_features.cpp`, `tests/test_select.cpp` |
| Aggregate `FILTER (WHERE ...)`, `DISTINCT` and `ORDER BY` inside aggregates | Yes | | `tests/test_function_gaps.cpp`, `tests/test_pg_dml.cpp` |
| Window functions, named `WINDOW`, `ROWS`, `RANGE` and `GROUPS` frames, `EXCLUDE`, `IGNORE NULLS` | Differs | The default frame counts equal rows one by one (`ROWS`); PostgreSQL's `RANGE` default only with `pg_compat` on. `IGNORE NULLS` works for `first_value`, `last_value`, and `lag` / `lead` with an offset of 1 | `tests/test_windows.cpp`, `tests/test_analysis.cpp`, `tests/test_sql_features.cpp` |
| `percentile_cont`, `percentile_disc`, `mode` `WITHIN GROUP` | Yes | Hypothetical-set aggregates (`rank(1) WITHIN GROUP`) are refused | `tests/test_analysis.cpp` |
| `ORDER BY ... NULLS FIRST \| LAST`, `LIMIT`, `OFFSET`, `FETCH FIRST n ROWS ONLY` | Yes | | `tests/test_vector.cpp`, `tests/test_pg_dml.cpp` |
| `ORDER BY ... USING op` | Refused | Syntax error | by hand |
| `VALUES` as a table, with column aliases | Yes | | `tests/test_sql_parser.cpp`, `tests/test_procedures.cpp` |
| `generate_series` (numbers and times) | Yes | Up to 10 million rows | `tests/test_snapshot_reads.cpp`, `tests/test_analysis.cpp` |
| `unnest`, `unnest` of several arrays, set-returning functions in `FROM` | Yes | | `tests/test_pg_dml.cpp` |
| `WITH ORDINALITY` | Refused | Syntax error | by hand |
| `TABLESAMPLE` | Differs | Accepted; the sample is new on each run, no `REPEATABLE (seed)` | `tests/test_sql_features.cpp` |
| `SELECT ... FROM ONLY t` | Refused | There is no inheritance | by hand |
| `IS [NOT] DISTINCT FROM`, `BETWEEN`, `IN`, `ANY` / `ALL` with an array | Yes | | `tests/test_procedures.cpp`, `tests/test_pg_dml.cpp` |
| `BETWEEN SYMMETRIC`, `LIKE ... ESCAPE 'c'`, `OVERLAPS` | Refused | Syntax error | by hand |
| `LIKE`, `ILIKE`, `SIMILAR TO`, `~`, `~*` | Yes | `~` uses KarelaDB's own regular-expression engine: no back references or look-around ([regex](functions-regex.md)) | `tests/test_vector.cpp`, `tests/test_sql_features.cpp` |
| Row comparison `(a, b) < (x, y)` | Yes | | `tests/test_sql_parser.cpp` |
| `COLLATE "C"`, `COLLATE "pg_en_US"` | Differs | Text order is by bytes unless `pg_compat` is on ([text order](postgres-protocol.md#pg-compat)) | `tests/test_pg_compat.cpp` |
| `AT TIME ZONE` | Yes | Zones with summer time work in `time IN ... TIME ZONE`, `date_trunc`, `to_char` and `time_bucket` | `tests/test_time_zone.cpp`, `tests/test_pg_dml.cpp` |
| `EXPLAIN`, `EXPLAIN ANALYZE` | Differs | The plan text is KarelaDB's own ([explain](explain.md)) | `tests/test_backends.cpp`, `tests/test_view_pushdown.cpp` |
| Number syntax `1_000`, `0x1F`; operators `^`, `\|/`, `@` | Refused | Syntax error. Write `power(2, 3)`, `sqrt(4)`, `abs(x)` | by hand |
| `E'...'`, `$$ ... $$`, `U&'...'` strings | Yes, by hand | | by hand |

<a id="types"></a>

## Types

The wire types are in [PostgreSQL protocol: types](postgres-protocol.md#types); the stored types in [column types](column-types.md).

| PostgreSQL type | Status | What is different, or what happens | Tested by |
|---|---|---|---|
| `smallint`, `integer`, `bigint`, `real`, `double precision`, `boolean`, `text`, `varchar(n)`, `char(n)`, `name` | Yes | `varchar(n)` is checked: a longer value is refused. `text` and `name` are `STRING` | `tests/test_types.cpp`, `tests/test_pg_ddl.cpp` |
| `numeric(p, s)` / `decimal(p, s)` | Yes | Exact, up to 38 digits. A result past 38 digits is `22003` | `tests/test_decimal.cpp`, `tests/test_pg_ddl.cpp` |
| `numeric` with **no** precision | Differs | **A `DOUBLE` column, not exact.** `CREATE TABLE t (amount NUMERIC)` makes a `DOUBLE`; `x::numeric` and a decimal literal such as `0.1` are `DOUBLE` too. `pg_compat` fixes the literals and `::numeric` in a query, **not** the column. Write `NUMERIC(p, s)` or `DECIMAL(2)` for money ([warning](column-types.md#decimal)) | `tests/test_pg_compat.cpp`, `tests/test_decimal.cpp` |
| `date`, `time` | Yes | `time` has no zone | `tests/test_pg.cpp`, `tests/test_time_ranges.cpp` |
| `timestamp`, `timestamptz` | Differs | One exact moment in **UTC**, in **milliseconds**: microseconds are cut. A `timestamp(3)` or `(6)` precision is accepted. `timetz` is refused | `tests/test_pg.cpp`, `tests/test_time_zone.cpp` |
| `interval` | Differs | Kept as milliseconds (a `LONG`), so a month is 30 days (`INTERVAL '1 month' = INTERVAL '30 days'` is true). `TIME + INTERVAL` is refused | `tests/test_pg.cpp`, `tests/test_time_ranges.cpp` |
| `uuid` | Yes | A text that is not a UUID is refused | `tests/test_pg.cpp`, `tests/test_types.cpp` |
| `json`, `jsonb` | Differs | Both are `JSON`. Keys are kept in the order written; `jsonb` does not sort or merge keys | `tests/test_pg.cpp`, `tests/test_json_path.cpp` |
| `bytea` | Yes | | `tests/test_pg.cpp`, `tests/test_crypto.cpp` |
| Arrays (`int[]`, `text[]`, `ARRAY[...]`, `a[1]`) | Differs | A one-dimensional list, stored as JSON and shown as `[1,2]`, not `{1,2}`. See [arrays](functions-postgres.md#arrays) | `tests/test_pg_dml.cpp`, `tests/test_types.cpp` |
| Enum types | Yes | | `tests/test_enum_types.cpp` |
| `inet`, `cidr`, `macaddr`, `xml`, `money`, `oid`, `regclass` | Differs | Accepted as a cast or column type; stored as text (`money` as `DOUBLE`, `oid` as `LONG`). Functions on `inet` are in [functions-postgres](functions-postgres.md#ip) | `tests/test_function_gaps.cpp`, `tests/test_pg_ddl.cpp` |
| `serial` | Differs | See [objects](#objects) | `tests/test_pg_ddl.cpp` |
| Range types (`int4range`, `tsrange`, `daterange`), multiranges | Refused | | by hand |
| `hstore`, `ltree`, `cube`, `point`, `box`, geometric types, `bit` / `varbit`, `tsvector`, `tsquery` | Refused | Use [full-text search](full-text-search.md) (`FULLTEXT INDEX`, `match`) and [geometry](geometry-and-cad.md) | by hand |
| Composite and domain types | Refused | | by hand |

<a id="functions"></a>

## Functions by group

A function name that KarelaDB does not know gives `42883`.

| Group | Status | What is different, or what happens | Tested by |
|---|---|---|---|
| Text: `||`, `lower`, `upper`, `length`, `substring(x FROM n FOR m)`, `position(a IN b)`, `overlay`, `trim`, `btrim`, `lpad`, `rpad`, `left`, `right`, `split_part`, `replace`, `translate`, `repeat`, `reverse`, `strpos`, `starts_with`, `initcap`, `chr`, `ascii`, `to_hex`, `md5`, `format`, `quote_ident`, `quote_literal` | Yes | | `tests/test_types.cpp`, `tests/test_pg_strings.cpp`, `tests/test_vector.cpp` |
| Regular expressions: `regexp_replace`, `regexp_matches`, `regexp_split_to_array`, `regexp_split_to_table` | Differs | Own engine: no back references or look-around; limits in [limits](limits.md#values) | `tests/test_pg_strings.cpp`, `tests/test_types.cpp` |
| `string_agg`, `array_agg` (also with `DISTINCT` and `ORDER BY`), `json_agg`, `jsonb_agg`, `json_object_agg` | Yes | | `tests/test_function_gaps.cpp`, `tests/test_analysis.cpp` |
| Numbers: `abs`, `round`, `ceil`, `floor`, `trunc`, `mod`, `power`, `sqrt`, `exp`, `ln`, `log`, `sign`, `pi`, `degrees`, `sin` ... `atan2`, `width_bucket`, `random`, `setseed` | Yes | `div()` is not there: with `int_division = integer`, `7 / 2` is `3` | `tests/test_analysis.cpp`, `tests/test_vector.cpp` |
| Bit operators on integers (`&`, `\|`, `#`, `~`, `<<`, `>>`) and `bit_and`, `bit_or` | Yes, by hand | | by hand |
| Statistics: `stddev`, `variance`, `corr`, `covar_pop`, `covar_samp`, `regr_slope`, `bool_and`, `bool_or`, `every` | Yes | | `tests/test_analysis.cpp` |
| Dates and times: `now()`, `current_date`, `current_timestamp`, `localtimestamp`, `date_trunc`, `date_part`, `extract`, `age`, `make_date`, `make_interval`, `date_bin`, `to_char`, `to_date`, `to_timestamp` | Yes | `timeofday()` is not there | `tests/test_time_zone.cpp`, `tests/test_to_timestamp_format.cpp`, `tests/test_vector.cpp` |
| `clock_timestamp()`, `statement_timestamp()`, `transaction_timestamp()` | Yes, by hand | | by hand |
| JSON: `->`, `->>`, `#>`, `#>>`, `@>`, `?`, `-`, `jsonb_set`, `jsonb_build_object`, `json_build_object`, `to_json`, `row_to_json`, `jsonb_each`, `jsonb_object_keys`, `jsonb_array_elements`, `jsonb_to_recordset`, `jsonb_typeof`, `jsonb_pretty`, `jsonb_path_query` | Yes | `jsonb_each` and similar give rows, so they go in `FROM`. See [JSON functions](functions-json.md) | `tests/test_function_gaps.cpp`, `tests/test_json_path.cpp`, `tests/test_pg.cpp` |
| Arrays: `array_length`, `array_to_string`, `string_to_array`, `cardinality`, `array_position`, `array_cat`, `array_append`, `array_remove`, `unnest`, `= ANY(array)`, `@>`, `\|\|` | Yes | | `tests/test_pg_dml.cpp`, `tests/test_types.cpp` |
| UUID and random: `gen_random_uuid()` | Yes | `uuid_generate_v4()` is not there; use `gen_random_uuid()` | `tests/test_types.cpp` |
| Security: `crypt`, `gen_salt`, `digest`, `sha256`, `gen_random_bytes`, `encode`, `decode`, `convert_from` | Yes | | `tests/test_crypto.cpp` |
| System information: `version()`, `current_database()`, `current_user`, `session_user`, `current_schema()`, `current_setting`, `set_config`, `pg_typeof`, `pg_backend_pid`, `pg_sleep`, `pg_is_in_recovery`, `to_regclass`, `pg_relation_size`, `pg_size_pretty`, `has_table_privilege` | Yes | `version()` says `PostgreSQL 14.0 (KDB ...)`. `pg_backend_pid()` is the connection number | `tests/test_pg.cpp`, `tests/test_meta_functions.cpp`, `tests/test_correct_006.cpp`, `tests/test_users.cpp` |
| Catalog helpers: `pg_get_viewdef`, `pg_get_indexdef`, `pg_get_constraintdef`, `pg_get_expr`, `format_type`, `obj_description`, `pg_get_serial_sequence`, `pg_table_is_visible` | Yes | `pg_get_triggerdef` is not there; `pg_get_functiondef` gives NULL | `tests/test_pg.cpp`, `tests/test_users.cpp` |
| `txid_current`, `pg_current_wal_lsn`, `pg_postmaster_start_time`, `inet_client_addr`, `pg_column_size`, `pg_encoding_to_char`, `pg_read_file`, `lo_import`, `dblink` | Refused | `42883`. Server files are never readable from SQL | by hand |
| Full-text: `to_tsvector`, `to_tsquery`, `plainto_tsquery`, `ts_rank`, `@@` | Refused | KarelaDB has its own: `CREATE FULLTEXT INDEX`, `match()`, `search_rank()`, `highlight()` ([full-text search](full-text-search.md)). `unaccent`, `soundex` are not there | `tests/test_indexes.cpp` |
| Fuzzy text: `similarity`, `levenshtein` | Yes, by hand | From `pg_trgm` / `fuzzystrmatch`; more are in [functions-text](functions-text.md) | by hand |
| PostGIS (`ST_...`), `earth_distance`, `cube` | Refused | | by hand |

<a id="catalogs"></a>

## Catalogs and statistics views

Read-only, worked out from KarelaDB's own tables when read. Details in [PostgreSQL protocol: the catalog](postgres-protocol.md#catalog).

| View or command | Status | What is different, or what happens | Tested by |
|---|---|---|---|
| `information_schema.tables`, `columns`, `views`, `schemata`, `sequences`, `table_constraints`, `key_column_usage`, `constraint_column_usage`, `referential_constraints`, `check_constraints` | Yes | | `tests/test_pg_ddl.cpp`, `tests/test_pg.cpp`, `tests/test_meta_functions.cpp` |
| `information_schema.routines`, `triggers`, `parameters` | Refused | `table or view ... does not exist` | by hand |
| `pg_class`, `pg_attribute`, `pg_type`, `pg_index`, `pg_indexes`, `pg_constraint`, `pg_namespace`, `pg_database`, `pg_roles`, `pg_settings`, `pg_tables`, `pg_views`, `pg_sequences`, `pg_enum`, `pg_description`, `pg_attrdef`, `pg_am`, `pg_collation` | Yes | One schema, `public`. `pg_index` has no index statistics; index sizes show `0 bytes` | `tests/test_pg.cpp`, `tests/test_enum_types.cpp`, `tests/test_catalog.cpp` |
| `pg_user`, `pg_matviews`, `pg_tablespace`, `pg_stat_user_tables`, `pg_replication_slots`, `pg_auth_members`, `pg_extension`, `pg_trigger`, `pg_proc`, `pg_depend`, `pg_language`, `pg_operator`, `pg_foreign_server`, `pg_shdescription`, `pg_available_extensions` | Differs | They exist so tools can read them. Some are always empty (`pg_trigger`, `pg_proc`, `pg_extension`, `pg_depend`, `pg_operator`, `pg_language`); do not use them to find your functions or triggers | by hand |
| `pg_stat_activity`, `pg_locks`, `pg_stat_statements` | Yes | Own columns are a subset of PostgreSQL's ([activity](server-activity.md#pg-stat-activity)) | `tests/test_backends.cpp`, `tests/test_table_locks.cpp` |
| `pg_stat_database`, `pg_stats`, `pg_stat_user_indexes`, `pg_statio_user_tables`, `pg_stat_bgwriter`, `pg_stat_replication`, `pg_prepared_statements`, `pg_cursors` | Refused | `table or view ... does not exist`. Tools that read them (pgAdmin's dashboards, `pg_stat_statements` extensions) may stop | by hand |
| psql `\l`, `\dt`, `\dt+`, `\di`, `\di+`, `\dv`, `\du`, `\d table`, `\d+ table` | Yes | Tested with the exact queries psql 14, 15 and 16 send | `tests/test_pg.cpp` (`TestPsqlDescribe`) |
| psql `\df`, `\dn`, `\dx`, `\dT`, `\dp`, pgAdmin's tree | Not tested | May stop on a catalog view that is not there | not tested |
| DBeaver's connect-time and navigator queries | Yes | Tested for what DBeaver reads when it connects; the full navigator is not | `tests/test_pg.cpp` |
| Npgsql type loading | Differs | Connect with `Server Compatibility Mode=NoTypeLoading` | not tested |

<a id="drivers"></a>

## Drivers and tools

| Client | Status | Tested by |
|---|---|---|
| Go `pgx` v5 (pool, `QueryRow`, `CollectRows`, `Begin`, `SendBatch`, `CopyFrom`) | Yes | `tests/pg_go/main.go` (run by hand against a server) |
| Python `pg8000` | Yes | `tests/pg_python/check_pg8000.py` (run by hand) |
| psql 14, 15, 16 | Yes (catalog queries); an interactive session was not run in the test suite | `tests/test_pg.cpp` |
| DBeaver | Yes for the SQL editor; the navigator reads a catalog that is only partly there | `tests/test_pg.cpp` |
| Node `pg`, Python `psycopg`, C# `Npgsql`, JDBC | Not tested against a server in the suite; they use the same protocol messages as the tested clients (JDBC's fetch size and batches are covered at the message level) | `tests/test_pg.cpp` (messages only) |
| ORMs and migration tools (SQLAlchemy, Django, Prisma, Entity Framework, Flyway, Alembic) | Not tested | They read the catalog and send DDL that may be refused. Try your own schema first |
| The NChartPro application (006, pgx) | Not re-measured | `tests/app_compat/` holds the 2,146 statements it sends. The last pass rate (34.3 %) is from 2026-09-12 and is out of date: much of the SQL it needed then (`RETURNING`, `ON CONFLICT`, CTEs, correlated subqueries, `float8` casts, `to_char`) works now. Run `tests/app_compat/run_compat.mjs` for a current number |

<a id="method"></a>

## How this page was made

1. The protocol rows come from `src/server/pg_server.cpp` and `tests/test_pg.cpp`.
2. Each statement, type, function and catalog row was run by hand with `kareladb sql` on a build of 2026-10-25, and the result recorded: it ran, or it gave the error quoted. A row with *by hand* has no test file in `tests/` that names the feature.
3. Each test file was found by searching `tests/` for the feature's words. A file listed covers the feature, not necessarily every detail of it.
4. The differences come from the code and from [limits](limits.md), [known limitations](../tutorial/known-limitations.md) and [tutorial chapter 22](../tutorial/22-postgresql-compatibility.md).

If a row is wrong or out of date, the program wins: test the statement. When a feature is added or removed, change its row in the same commit.
