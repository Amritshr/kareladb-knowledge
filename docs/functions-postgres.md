# PostgreSQL-compatible functions

> Functions a PostgreSQL app expects: arrays, sequence numbers (nextval), who you are and what you may do (current_user, has_table_privilege), comments (COMMENT ON), advisory locks and session settings, so app code runs on KDB without changes.

- Category: Postgres protocol
- Keywords: PostgreSQL functions, to\_regclass, pg\_relation\_size, pg\_total\_relation\_size, pg\_table\_size, pg\_indexes\_size, pg\_database\_size, pg\_size\_pretty, table size, database size, current\_database, postgres compatibility, array, ARRAY\[\], arrays, list of values, watchlist, tags, sequence, auto number, order number, invoice number, advisory lock, named lock, job lock, one worker at a time, pg\_advisory, nextval, currval, lastval, setval, unnest, cardinality, current\_setting, set\_config, SET LOCAL, session setting, custom setting, current\_user, session\_user, current\_role, current\_schema, current\_schemas, current\_catalog, version, has\_table\_privilege, has\_column\_privilege, has\_database\_privilege, has\_schema\_privilege, pg\_has\_role, privileges, rights, COMMENT ON, comment, description, obj\_description, col\_description, pg\_get\_indexdef, pg\_get\_constraintdef, pg\_get\_viewdef, pg\_get\_expr, format\_type, pg\_table\_is\_visible
- See also: [PostgreSQL protocol (port 8832)](postgres-protocol.md), [JSON functions](functions-json.md), [Text functions](functions-text.md), [Date and time functions](functions-date-time.md), [Constraints](constraints.md), [Transactions](transactions.md)

A PostgreSQL app sends more than plain SQL. It also calls **arrays**, **sequences** and **advisory locks**.
KDB answers all three with the PostgreSQL names, so the same app code runs here.

- An **array** is a list of values in one value: `ARRAY['CITY', 'COAST']`. KDB keeps an array as a [JSON](functions-json.md) list, so a `JSON` column can hold one and every JSON function still works on it.
- A **sequence** is a counter the database keeps for you: order numbers, invoice numbers. `nextval` gives the next one. See `CREATE SEQUENCE` in [constraints](constraints.md#auto) for how to make one.
- An **advisory lock** is a name (a number) your app takes so two copies of it do not do the same job twice.

The other PostgreSQL function names live with their own kind: the JSON ones in [JSON functions](functions-json.md), the time ones in [date and time](functions-date-time.md), `initcap`, `md5`, `to_str` and `string_to_array` in [text functions](functions-text.md).

**Example: A watchlist as one array value** (sample data: sample)

```sql
SELECT ARRAY['CITY', 'COAST', 'VOLT'] AS watchlist,
       cardinality(ARRAY['CITY', 'COAST', 'VOLT']) AS how_many,
       array_to_string(ARRAY['CITY', 'COAST', 'VOLT'], ', ') AS shown;
```

Result:

| watchlist (TEXT[]) | how_many (LONG) | shown (STRING) |
|---|---|---|
| ["CITY","COAST","VOLT"] | 3 | CITY, COAST, VOLT |

(1 row)

<a id="arrays"></a>

## Arrays in KDB

Syntax:

```sql
ARRAY[value, value, ...]        an array value
'["CITY","COAST"]'              JSON text an array function reads as an array
'{CITY,COAST}'                  PostgreSQL array text an array function reads too
```

An array is a list of values kept as one value. KDB stores it as a JSON list, so `ARRAY['CITY','COAST']` shows as `["CITY","COAST"]` and fits in a `JSON` column.

- **Counting starts at 1**, as in PostgreSQL: the first element is number 1.
- An array may hold text, numbers, `TRUE`/`FALSE` and `NULL` mixed together. KDB does not check that all elements are of one type.
- The functions on this page also read **text**: text that starts with `[` as JSON, text that starts with `{` as PostgreSQL array text (`'{CITY,COAST}'`). So a value a PostgreSQL driver sends still works.
- A `JSON` **column** keeps JSON only. To save a PostgreSQL array text in one, read it first: `string_to_array(t, ',')`, or `array_cat(t, ARRAY[])`.
- There are no arrays of arrays with their own functions. `array_length(a, 2)` (a second dimension) always gives `NULL`.
- To store a list, use a `JSON` column. To take a list apart into rows, use [unnest](functions-postgres.md#unnest).

**Example: A watchlist column an app reads and writes** (sample data: sample)

Setup:

```sql
CREATE TABLE watchlists (user_id INT PRIMARY KEY, symbols JSON);
INSERT INTO watchlists VALUES (1, '["CITY","COAST"]'), (2, array_cat('{VOLT,ACME}', ARRAY[]));
```

```sql
SELECT user_id, symbols, cardinality(symbols) AS how_many,
       symbols ->> 0 AS first_symbol
FROM watchlists ORDER BY user_id;
```

Result:

| user_id (INT) | symbols (JSON) | how_many (LONG) | first_symbol (STRING) |
|---|---|---|---|
| 1 | ["CITY","COAST"] | 2 | CITY |
| 2 | ["VOLT","ACME"] | 2 | VOLT |

(2 rows)

## array_append

Syntax:

```sql
array_append(array, value)
```

The array with one more value at the **end**.

| Argument | Type | Meaning |
|---|---|---|
| `array` | array (`JSON` list, or array text) | the list to add to |
| `value` | any | the value to put at the end |

- **Returns:** the new array (`JSON`). The old one is not changed.
- **NULL:** `array_append(NULL, 'CITY')` is `["CITY"]` (a NULL array counts as empty). A `NULL` value is added as JSON `null`.
- **Notes:** PostgreSQL writes this as `array || value`. In KDB `||` joins text, so use the function name.

**Example: Add a company to a user's watchlist** (sample data: sample)

Setup:

```sql
CREATE TABLE watchlists (user_id INT PRIMARY KEY, symbols JSON);
INSERT INTO watchlists VALUES (1, '["CITY","COAST"]');
```

```sql
UPDATE watchlists SET symbols = array_append(symbols, 'VOLT') WHERE user_id = 1;
SELECT user_id, symbols FROM watchlists;
```

Result:

`UPDATE watchlists SET symbols = array_append(symbols, 'VOLT') WHERE user_id = 1`

```text
1 row(s) updated
```

`SELECT user_id, symbols FROM watchlists`

| user_id (INT) | symbols (JSON) |
|---|---|
| 1 | ["CITY","COAST","VOLT"] |

(1 row)

## array_prepend

Syntax:

```sql
array_prepend(value, array)
```

The array with one more value at the **front**. The value comes first, the array second (as in PostgreSQL).

| Argument | Type | Meaning |
|---|---|---|
| `value` | any | the value to put in front |
| `array` | array | the list to add to |

- **Returns:** the new array (`JSON`).
- **NULL:** a `NULL` array counts as empty. A `NULL` value is put in front as JSON `null`.

**Example** (sample data: sample)

```sql
SELECT array_prepend('ACME', ARRAY['CITY', 'COAST']) AS watchlist;
```

Result:

| watchlist (JSON) |
|---|
| ["ACME","CITY","COAST"] |

(1 row)

## array_cat

Syntax:

```sql
array_cat(array1, array2)
```

The two arrays joined into one, in order.

| Argument | Type | Meaning |
|---|---|---|
| `array1` | array | the first list |
| `array2` | array | the list added after it |

- **Returns:** the joined array (`JSON`).
- **NULL:** only when **both** are `NULL`. One `NULL` counts as an empty list.

**Example: One watchlist for two users** (sample data: sample)

```sql
SELECT array_cat(ARRAY['CITY', 'COAST'], ARRAY['VOLT']) AS together,
       array_cat(NULL, ARRAY['TELCO']) AS one_side_null,
       array_cat(NULL, NULL) AS both_null;
```

Result:

| together (TEXT[]) | one_side_null (TEXT[]) | both_null (TEXT[]) |
|---|---|---|
| ["CITY","COAST","VOLT"] | ["TELCO"] | NULL |

(1 row)

## array_remove

Syntax:

```sql
array_remove(array, value)
```

The array without **every** element equal to `value`.

| Argument | Type | Meaning |
|---|---|---|
| `array` | array | the list |
| `value` | any | the value to take out (all of them) |

- **Returns:** the shorter array (`JSON`). Nothing equal: the same array.
- **NULL:** `array_remove(NULL, x)` is `NULL`. `array_remove(a, NULL)` takes the `null` elements out.

**Example: A user removes a company from the watchlist** (sample data: sample)

Setup:

```sql
CREATE TABLE watchlists (user_id INT PRIMARY KEY, symbols JSON);
INSERT INTO watchlists VALUES (1, '["CITY","COAST","CITY"]');
```

```sql
UPDATE watchlists SET symbols = array_remove(symbols, 'CITY') WHERE user_id = 1;
SELECT user_id, symbols FROM watchlists;
```

Result:

`UPDATE watchlists SET symbols = array_remove(symbols, 'CITY') WHERE user_id = 1`

```text
1 row(s) updated
```

`SELECT user_id, symbols FROM watchlists`

| user_id (INT) | symbols (JSON) |
|---|---|
| 1 | ["COAST"] |

(1 row)

## array_position

Syntax:

```sql
array_position(array, value [, start])
```

Which place `value` has in the array. The first place is `1`.

| Argument | Type | Meaning |
|---|---|---|
| `array` | array | the list to look in |
| `value` | any | the value to find |
| `start` | `INT` | look from this place on (default `1`) |

- **Returns:** `LONG`, the place of the **first** match, or `NULL` when the value is not there.
- **NULL:** a `NULL` array gives `NULL`. `array_position(a, NULL)` finds a `null` element.

**Example: Where is VOLT in the watchlist?** (sample data: sample)

```sql
SELECT array_position(ARRAY['CITY', 'COAST', 'VOLT'], 'VOLT') AS at_place,
       array_position(ARRAY['CITY', 'COAST', 'VOLT'], 'TELCO') AS not_there,
       array_position(ARRAY['CITY', 'COAST', 'CITY'], 'CITY', 2) AS from_place_2;
```

Result:

| at_place (LONG) | not_there (STRING) | from_place_2 (LONG) |
|---|---|---|
| 3 | NULL | 3 |

(1 row)

<a id="array_length"></a>

## array_length, array_upper

Syntax:

```sql
array_length(array, dimension)
array_upper(array, dimension)
```

How many elements the array has. `dimension` must be `1`; KDB has one dimension only. `array_upper` gives the number of the last place, which is the same number.

| Argument | Type | Meaning |
|---|---|---|
| `array` | array | the list |
| `dimension` | `INT` | always `1` |

- **Returns:** `LONG`.
- **NULL:** an **empty** array gives `NULL` (that is what PostgreSQL does; use `cardinality` for `0`). A `NULL` array, or a dimension that is not `1`, also gives `NULL`.

**Example** (sample data: sample)

```sql
SELECT array_length(ARRAY['CITY', 'COAST'], 1) AS how_many,
       array_upper(ARRAY['CITY', 'COAST'], 1) AS last_place,
       array_length(ARRAY[], 1) AS empty_list,
       array_length(ARRAY['CITY'], 2) AS no_second_dimension;
```

Result:

| how_many (LONG) | last_place (LONG) | empty_list (STRING) | no_second_dimension (STRING) |
|---|---|---|---|
| 2 | 2 | NULL | NULL |

(1 row)

## cardinality

Syntax:

```sql
cardinality(array)
```

How many elements the array has, counting an empty array as `0`.

| Argument | Type | Meaning |
|---|---|---|
| `array` | array | the list |

- **Returns:** `LONG`.
- **NULL:** `cardinality(NULL)` is `NULL`. An empty array gives `0`, not `NULL`.
- **Notes:** this is the safe one to use in `WHERE`: `cardinality(symbols) > 0`.

**Example: How many companies each user follows** (sample data: sample)

Setup:

```sql
CREATE TABLE watchlists (user_id INT PRIMARY KEY, symbols JSON);
INSERT INTO watchlists VALUES (1, '["CITY","COAST"]'), (2, '[]'), (3, NULL);
```

```sql
SELECT user_id, cardinality(symbols) AS follows, array_length(symbols, 1) AS same_but_null_when_empty
FROM watchlists ORDER BY user_id;
```

Result:

| user_id (INT) | follows (LONG) | same_but_null_when_empty (LONG) |
|---|---|---|
| 1 | 2 | 2 |
| 2 | 0 | NULL |
| 3 | NULL | NULL |

(3 rows)

## array_to_string

Syntax:

```sql
array_to_string(array, separator [, null_text])
```

The elements written one after the other with `separator` between them.

| Argument | Type | Meaning |
|---|---|---|
| `array` | array | the list |
| `separator` | `STRING` | text put between two elements |
| `null_text` | `STRING` | what a `NULL` element is written as; without it `NULL` elements are left out |

- **Returns:** `STRING`.
- **NULL:** a `NULL` array or a `NULL` separator gives `NULL`.

**Example: A watchlist in one line for an email** (sample data: sample)

```sql
SELECT array_to_string(ARRAY['CITY', 'COAST', 'VOLT'], ', ') AS watchlist,
       array_to_string(ARRAY['CITY', NULL, 'VOLT'], ', ') AS nulls_left_out,
       array_to_string(ARRAY['CITY', NULL, 'VOLT'], ', ', '?') AS nulls_shown;
```

Result:

| watchlist (STRING) | nulls_left_out (STRING) | nulls_shown (STRING) |
|---|---|---|
| CITY, COAST, VOLT | CITY, VOLT | CITY, ?, VOLT |

(1 row)

## unnest

Syntax:

```sql
unnest(array)
```

Turns one array into **many rows**, one row per element, in order.

| Argument | Type | Meaning |
|---|---|---|
| `array` | array | the list to take apart |

- **Returns:** one row per element.
- **NULL:** a `NULL` array gives **no rows**.
- **Notes:** this is how a PostgreSQL app sends a list of symbols in one parameter: `WHERE symbol IN (SELECT unnest($1))`.

**Example: One row per company in the list** (sample data: sample)

```sql
SELECT unnest(ARRAY['CITY', 'COAST', 'VOLT']) AS symbol;
```

Result:

| symbol (STRING) |
|---|
| CITY |
| COAST |
| VOLT |

(3 rows)

**Example: An app sends a watchlist and asks for those companies** (sample data: sample)

```sql
SELECT symbol, name, sector
FROM securities
WHERE symbol IN (SELECT unnest(ARRAY['CITY', 'VOLT']))
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | name (STRING) | sector (STRING) |
|---|---|---|
| CITY | City Bank Limited | Banking |
| VOLT | Volt River Hydropower Limited | Energy |

(2 rows)

## nextval

Syntax:

```sql
nextval('sequence_name')
```

The next number of a sequence. Each call gives a number that was never given before, even when many connections ask at the same time.

| Argument | Type | Meaning |
|---|---|---|
| `sequence_name` | `STRING` | the sequence name in **single quotes**; `'public.orders_id_seq'` and `'"Name"'` are accepted too |

- **Returns:** `LONG`.
- **NULL:** a `NULL` name gives `NULL`.
- **Notes:** make the sequence first with `CREATE SEQUENCE order_no_seq START WITH 1001`. A number that was given is never given again, also when the transaction is rolled back - so there can be gaps. A sequence that does not exist is an error. For a simple id column, `PRIMARY KEY AUTO` is easier (see [constraints](constraints.md#auto)).

**Example: Order numbers from a sequence**

Setup:

```sql
CREATE SEQUENCE order_no_seq START WITH 1001;
CREATE TABLE orders (order_no LONG PRIMARY KEY, symbol SYMBOL, quantity LONG);
```

```sql
INSERT INTO orders VALUES (nextval('order_no_seq'), 'CITY', 100),
                          (nextval('order_no_seq'), 'COAST', 50);
SELECT * FROM orders ORDER BY order_no;
```

Result:

`INSERT INTO orders VALUES (nextval('order_no_seq'), 'CITY', 100), (nextval('order_no_seq'), 'COAST',`

```text
2 row(s) inserted
```

`SELECT * FROM orders ORDER BY order_no`

| order_no (LONG) | symbol (SYMBOL) | quantity (LONG) |
|---|---|---|
| 1001 | CITY | 100 |
| 1002 | COAST | 50 |

(2 rows)

## currval

Syntax:

```sql
currval('sequence_name')
```

The number this connection got **last** from that sequence. It does not move the sequence on.

| Argument | Type | Meaning |
|---|---|---|
| `sequence_name` | `STRING` | the sequence name in single quotes |

- **Returns:** `LONG`.
- **NULL:** a `NULL` name gives `NULL`.
- **Notes:** it is an error before this connection has called `nextval` on that sequence. Another connection's numbers are never shown, so `currval` is safe to read after an insert.

**Example: The order number just given**

Setup:

```sql
CREATE SEQUENCE order_no_seq START WITH 1001;
CREATE TABLE orders (order_no LONG PRIMARY KEY, symbol SYMBOL);
```

```sql
INSERT INTO orders VALUES (nextval('order_no_seq'), 'CITY');
SELECT currval('order_no_seq') AS my_order_no;
```

Result:

`INSERT INTO orders VALUES (nextval('order_no_seq'), 'CITY')`

```text
1 row(s) inserted
```

`SELECT currval('order_no_seq') AS my_order_no`

| my_order_no (LONG) |
|---|
| 1001 |

(1 row)

**Example: currval before nextval is an error** (shows an error)

Setup:

```sql
CREATE SEQUENCE order_no_seq;
```

```sql
SELECT currval('order_no_seq');
```

Result:

Error: `currval of sequence 'order_no_seq' is not yet defined in this session (call nextval first)`

## lastval

Syntax:

```sql
lastval()
```

The number this connection got last from **any** sequence.

- **Returns:** `LONG`.
- **NULL:** never `NULL`.
- **Notes:** it is an error before this connection has called `nextval` at all. With more than one sequence, `currval('name')` says clearly which one you mean.

**Example: The last number of any sequence**

Setup:

```sql
CREATE SEQUENCE order_no_seq START WITH 1001;
CREATE SEQUENCE invoice_no_seq START WITH 500;
```

```sql
SELECT nextval('order_no_seq') AS order_no, nextval('invoice_no_seq') AS invoice_no;
SELECT lastval() AS last_of_any, currval('order_no_seq') AS last_order_no;
```

Result:

`SELECT nextval('order_no_seq') AS order_no, nextval('invoice_no_seq') AS invoice_no`

| order_no (LONG) | invoice_no (LONG) |
|---|---|
| 1001 | 500 |

(1 row)

`SELECT lastval() AS last_of_any, currval('order_no_seq') AS last_order_no`

| last_of_any (LONG) | last_order_no (LONG) |
|---|---|
| 500 | 1001 |

(1 row)

## setval

Syntax:

```sql
setval('sequence_name', value)
setval('sequence_name', value, is_called)
```

Sets the sequence to `value`. Use it after loading old rows, so new numbers start above them.

| Argument | Type | Meaning |
|---|---|---|
| `sequence_name` | `STRING` | the sequence name in single quotes |
| `value` | `LONG` | the number to set |
| `is_called` | `BOOL` | `TRUE` (default): `value` counts as already given, so the next `nextval` is `value + 1`. `FALSE`: the next `nextval` gives `value` itself. |

- **Returns:** `LONG`, the `value` you gave.
- **NULL:** a `NULL` name or a `NULL` value gives `NULL` and changes nothing.
- **Notes:** a value outside the sequence's `MINVALUE`/`MAXVALUE` is an error. `setval` is written to disk at once; a `ROLLBACK` does not take it back.

**Example: Move the counter above the order numbers already loaded**

Setup:

```sql
CREATE SEQUENCE order_no_seq START WITH 1;
CREATE TABLE orders (order_no LONG PRIMARY KEY, symbol SYMBOL);
INSERT INTO orders VALUES (5000, 'CITY'), (5001, 'COAST');
```

```sql
SELECT setval('order_no_seq', (SELECT max(order_no) FROM orders)) AS set_to;
INSERT INTO orders VALUES (nextval('order_no_seq'), 'VOLT');
SELECT * FROM orders ORDER BY order_no;
```

Result:

`SELECT setval('order_no_seq', (SELECT max(order_no) FROM orders)) AS set_to`

| set_to (LONG) |
|---|
| 5001 |

(1 row)

`INSERT INTO orders VALUES (nextval('order_no_seq'), 'VOLT')`

```text
1 row(s) inserted
```

`SELECT * FROM orders ORDER BY order_no`

| order_no (LONG) | symbol (SYMBOL) |
|---|---|
| 5000 | CITY |
| 5001 | COAST |
| 5002 | VOLT |

(3 rows)

**Example: is_called = FALSE: the next number is the one you gave**

Setup:

```sql
CREATE SEQUENCE order_no_seq;
```

```sql
SELECT setval('order_no_seq', 7000, FALSE) AS set_to;
SELECT nextval('order_no_seq') AS next_number;
```

Result:

`SELECT setval('order_no_seq', 7000, FALSE) AS set_to`

| set_to (LONG) |
|---|
| 7000 |

(1 row)

`SELECT nextval('order_no_seq') AS next_number`

| next_number (LONG) |
|---|
| 7000 |

(1 row)

<a id="sizes"></a>

## Names and sizes: to_regclass, pg_relation_size, ...

Syntax:

```sql
to_regclass('name')
pg_relation_size(relation [, 'main'])
pg_table_size(relation)
pg_indexes_size(relation)
pg_total_relation_size(relation)
pg_database_size(name_or_oid)
pg_size_pretty(bytes)
current_database()
```

| Function | Returns |
|---|---|
| `to_regclass('name')` | the name of the table, index, view or sequence, or `NULL` when there is none |
| `pg_relation_size`, `pg_table_size`, `pg_total_relation_size` | `LONG` bytes of the table on disk |
| `pg_indexes_size` | `LONG`, always `0` |
| `pg_database_size` | `LONG` bytes of every file of the database: tables, the log, kept versions |
| `pg_size_pretty(bytes)` | text like `8192 bytes`, `24 kB`, `1536 MB`, exactly as PostgreSQL writes it |
| `current_database()` | the database's name |

- **Arguments:** a relation is a name in single quotes (`'public.orders'` and `'"Orders"'` work) or an oid from `pg_class`.
- **Returns:** a table's size is its partition files plus its new rows that are still in the log (they move into the files at the next checkpoint), so a table that was just filled is never `0`.
- **NULL:** a `NULL` argument, or an oid nothing has, gives `NULL`. A name that does not exist is an error (`42P01`), as in PostgreSQL.
- **Notes:** KDB keeps indexes in memory only (built from the rows when the database opens), so they take `0` bytes on disk. `pg_database_size` measures only the database the statement runs in.
- **Waits:** a size reads the table the way a query of it does. `pg_total_relation_size('t')` waits for a statement that is writing `t` (never for writers of other tables), even with snapshot reads on. With an oid or a column instead of a name in quotes - `pg_total_relation_size(c.oid)` over `pg_class` - the size waits for every writer, as `SHOW TABLES` does.

**Example: How big are the tables?**

Setup:

```sql
CREATE TABLE orders (id LONG PRIMARY KEY, symbol SYMBOL, quantity LONG);
INSERT INTO orders VALUES (1, 'CITY', 100), (2, 'VOLT', 50);
```

```sql
SELECT to_regclass('orders') AS found, to_regclass('orderz') AS missing,
       pg_total_relation_size('orders') > 0 AS has_bytes,
       pg_size_pretty(10240) AS ten_kb, pg_size_pretty(1610612736) AS big;
```

Result:

| found (STRING) | missing (STRING) | has_bytes (BOOL) | ten_kb (STRING) | big (STRING) |
|---|---|---|---|---|
| orders | NULL | true | 10 kB | 1536 MB |

(1 row)

<a id="session-info"></a>

## Who and where: current_user, version()

Syntax:

```sql
current_user   current_role   user   session_user
current_schema   current_schemas(include_implicit)   current_catalog
version()
```

| Function | Returns |
|---|---|
| `current_user`, `current_role`, `user` | the user whose rights your statements use: after `SET ROLE` that user, else who logged in |
| `session_user` | who logged in, whatever `SET ROLE` did |
| `current_schema`, `current_schema()` | `public`: every table is in it |
| `current_schemas(false)` | `{public}`; with `true` also `pg_catalog`, which is searched first |
| `current_catalog` | the database's name, like `current_database()` |
| `version()` | `PostgreSQL 14.0 (KDB ...), compatible server` - drivers read the `14` |

- The same answers over HTTP [`/exec`](http-exec.md) and the [Postgres port](postgres-protocol.md). With an [API token](api-tokens.md) you are its user.
- **No user:** with the server's `--token` or a local tool (`kdb sql`) there is no user; the name is `kdb`. On the Postgres port of a server without users it is the name the client connected as.
- Write the first four without brackets, as SQL does. A column of that name wins: `SELECT user FROM _audit_log` reads the column.

**Example: Who am I, and on what?**

```sql
SELECT current_user, session_user, current_schema, current_catalog,
       version() LIKE 'PostgreSQL 14%' AS pg14;
```

Result:

| current_user (STRING) | session_user (STRING) | current_schema (STRING) | current_catalog (STRING) | pg14 (BOOL) |
|---|---|---|---|---|
| kdb | kdb | public | demo | true |

(1 row)

<a id="privileges"></a>

## Rights: has_table_privilege and friends

Syntax:

```sql
has_table_privilege([user,] table, privilege)
has_column_privilege([user,] table, column, privilege)
has_database_privilege([user,] database, privilege)
has_schema_privilege([user,] schema, privilege)
pg_has_role([user,] role, privilege)
```

`TRUE` when the user may do it now: the same rules the statements are checked with - the user's [role](users-and-roles.md), changed by [GRANT / REVOKE ... ON TABLE](table-rights.md).

| Function | Privileges | `TRUE` when |
|---|---|---|
| `has_table_privilege` | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER` | `SELECT` needs role `read`, the changes `write` (`TRUNCATE` counts as `DELETE`), each changed by the table's grants; `REFERENCES` and `TRIGGER` need `ddl` |
| `has_column_privilege` | `SELECT`, `INSERT`, `UPDATE`, `REFERENCES` | as for the table: KDB has no rights per column |
| `has_database_privilege` | `CONNECT`, `TEMPORARY` (`TEMP`), `CREATE` | any role on that database; `CREATE` needs `ddl` |
| `has_schema_privilege` | `USAGE`, `CREATE` | `USAGE` of `public` needs a role; `pg_catalog` and `information_schema` are open to all. `CREATE` in `public` needs `ddl` |
| `pg_has_role` | `MEMBER`, `USAGE` | the role is the user, or one of `read`, `write`, `ddl`, `admin` the user has here |

- **user:** a user name; without it, the current user. `public` is PostgreSQL's everyone and has no rights. A user whose own `ROLE` is `admin` has every right, as a PostgreSQL superuser.
- **privilege:** one word or a list, `'SELECT, INSERT'`: `TRUE` when any of them is allowed. `... WITH GRANT OPTION` is `TRUE` only for an admin: KDB has no grant options.
- **Objects:** a name (`'orders'`, `'public.orders'`) or an oid from `pg_class` or `pg_database`. An oid nothing has gives `NULL`; a name that does not exist is an error.
- **Errors**, as PostgreSQL: `22023` unrecognized privilege type, `42704` a user that does not exist, `42P01` a table, `42703` a column, `3D000` a database, `3F000` a schema.

**Example: What a read-only user may do**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER charts WITH PASSWORD 'Chart-app-secret-11' ROLE read;
CREATE TABLE orders (id LONG PRIMARY KEY, quantity LONG);
```

```sql
SELECT has_table_privilege('charts', 'orders', 'SELECT') AS reads,
       has_table_privilege('charts', 'orders', 'INSERT') AS writes,
       has_schema_privilege('charts', 'public', 'CREATE') AS creates,
       pg_has_role('charts', 'read', 'MEMBER') AS is_reader;
```

Result:

| reads (BOOL) | writes (BOOL) | creates (BOOL) | is_reader (BOOL) |
|---|---|---|---|
| true | false | false | true |

(1 row)

**Example: A privilege PostgreSQL does not have** (shows an error)

Setup:

```sql
CREATE TABLE orders (id LONG PRIMARY KEY);
```

```sql
SELECT has_table_privilege('orders', 'DROP');
```

Result:

Error: `line 1, column 8: has_table_privilege: unrecognized privilege type: "DROP"`

<a id="comments"></a>

## Comments and definitions: COMMENT ON, obj_description, pg_get_indexdef

Syntax:

```sql
COMMENT ON TABLE table IS 'text' | NULL
COMMENT ON COLUMN table.column IS 'text' | NULL
obj_description(table [, 'pg_class'])       col_description(table, column_number)
pg_get_indexdef(index [, column, pretty])   pg_get_constraintdef(constraint_oid [, pretty])
pg_get_viewdef(view [, pretty])             format_type(type_oid, typmod)
pg_table_is_visible(relation)               pg_get_expr(text, relation)
```

`COMMENT ON` keeps a description with a table or a column. It stays after a restart, and `\d+` in psql shows it. `IS NULL` (or `IS ''`) removes it. It needs role `ddl`, like `ALTER TABLE`.

| Function | Returns |
|---|---|
| `obj_description(t, 'pg_class')` | the table's comment, `NULL` when none |
| `col_description(t, n)` | the comment of column `n` (1 = the first), `NULL` when none |
| `pg_get_indexdef(i)` | the `CREATE INDEX` line of an index (also of `t_pkey`); with a column number, that key only |
| `pg_get_constraintdef(oid)` | `PRIMARY KEY (id)`, `CHECK (...)`, `FOREIGN KEY ... REFERENCES ...`, by the oid in `pg_constraint` |
| `pg_get_viewdef(v)` | the view's `SELECT`; `NULL` for a table |
| `format_type(oid, typmod)` | the type as PostgreSQL writes it: `integer`, `character varying(45)`, `numeric(10,2)` |
| `pg_table_is_visible(oid)` | `TRUE`: everything is in `public` |

- `COMMENT ON` other objects (an index, a function, a schema) is accepted and says it is not kept. A view is not a table: `COMMENT ON TABLE v` is error `42809`.
- `pg_get_partkeydef` and `pg_get_functiondef` give `NULL`: KDB tables are not PostgreSQL partitioned tables and `pg_proc` lists no functions. `pg_get_serial_sequence('t', 'id')` gives `public.t_id_seq` for a `SERIAL` column: that is the name of the column's counter, which `nextval`, `currval`, `setval`, `lastval` and `ALTER SEQUENCE ... RESTART WITH n` take, so a `pg_dump` restore that ends with `SELECT setval('t_id_seq', max)` works as it is. The counter only goes up: a `setval` below the ids already in the table means their largest + 1.
- Over HTTP, `'orders'::regclass` stays the name `'orders'`; these functions take the name as well as an oid.

**Example: Describe a table and a column**

Setup:

```sql
CREATE TABLE orders (id LONG PRIMARY KEY, quantity LONG);
```

```sql
COMMENT ON TABLE orders IS 'one row per order';
COMMENT ON COLUMN orders.quantity IS 'shares, never negative';
SELECT obj_description('orders'::regclass, 'pg_class') AS about_table,
       col_description('orders'::regclass, 2) AS about_quantity;
```

Result:

`COMMENT ON TABLE orders IS 'one row per order'`

```text
COMMENT
```

`COMMENT ON COLUMN orders.quantity IS 'shares, never negative'`

```text
COMMENT
```

`SELECT obj_description(CAST('orders' AS STRING), 'pg_class') AS about_table, col_description(CAST('o`

| about_table (STRING) | about_quantity (STRING) |
|---|---|
| one row per order | shares, never negative |

(1 row)

**Example: The SQL behind an index, a key and a type**

Setup:

```sql
CREATE TABLE orders (id LONG PRIMARY KEY, symbol VARCHAR(12));
CREATE INDEX orders_symbol ON orders (symbol);
```

```sql
SELECT pg_get_indexdef('orders_symbol'::regclass) AS index_sql,
       pg_get_indexdef('orders_pkey'::regclass) AS key_sql,
       format_type(1043, 16) AS symbol_type;
```

Result:

| index_sql (STRING) | key_sql (STRING) | symbol_type (STRING) |
|---|---|---|
| CREATE INDEX orders_symbol ON public.orders USING btree (symbol) | CREATE UNIQUE INDEX orders_pkey ON public.orders USING btree (id) | character varying(12) |

(1 row)

<a id="advisory-locks"></a>

## Advisory locks

Syntax:

```sql
pg_advisory_lock(key)            take a lock, wait if someone else has it
pg_try_advisory_lock(key)        take it only if it is free (TRUE / FALSE)
pg_advisory_unlock(key)          give it back
```

An **advisory lock** is a name your app agrees on. It locks **no table and no row** - it only stops two copies of your program from doing the same job at the same time.

Say your app closes the trading day at 15:05: it reads the trade log and writes the daily candles. If two copies of the app run, the job must run once. Each copy asks for the lock `918273`; the one that gets it does the job, the other one skips it.

| Part | Meaning |
|---|---|
| `key` | the lock name as a whole number (`BIGINT`), for example `918273` |
| `key1, key2` | two `INT` numbers instead of one; they are a **different** set of names (so `(1, 2)` and the single number 1 never meet) |
| `_shared` | many holders at the same time (readers); a lock without `_shared` waits until no one holds the key |
| `_xact` | the lock ends by itself with the transaction |
| `pg_try_*` | never waits: `TRUE` when the lock was taken, `FALSE` when someone else has it |

- Locks of **different databases** never meet, even with the same number.
- A session lock is held until it is given back **as many times as it was taken**, or until the connection closes. Over HTTP, a statement without a [session](http-sessions-and-cursors.md#post-session) is its own session, so its locks end with the statement.
- Waiting has a limit of **30 seconds** (PostgreSQL waits forever). After that the statement fails with a "locked" error; try again later.
- A `SELECT pg_advisory_xact_lock(...)` sent on its own waits **without holding up the database**, also inside `BEGIN ... COMMIT`: other readers and writers go on, and the waiter gets the lock as soon as the holder commits. A lock call inside a procedure or a longer statement list waits in place.
- On the Postgres port, `pg_try_*` and `pg_advisory_unlock*` are typed `bool` before they run, so a driver can read them into a boolean (Go: `bool`).
- `SET statement_timeout` also ends the wait (see [protection](protection.md#statement-timeout)).

**Example: Only one copy of the app closes the day** (sample data: sample)

```sql
SELECT pg_try_advisory_lock(918273) AS i_do_the_job;
SELECT count(*) AS trades_to_sum FROM trade_log;
SELECT pg_advisory_unlock(918273) AS given_back;
```

Result:

`SELECT pg_try_advisory_lock(918273) AS i_do_the_job`

| i_do_the_job (BOOL) |
|---|
| true |

(1 row)

`SELECT count(*) AS trades_to_sum FROM trade_log`

| trades_to_sum (LONG) |
|---|
| 32 |

(1 row)

`SELECT pg_advisory_unlock(918273) AS given_back`

| given_back (BOOL) |
|---|
| true |

(1 row)

<a id="pg_advisory_lock"></a>

## pg_advisory_lock, pg_advisory_lock_shared

Syntax:

```sql
pg_advisory_lock(key)
pg_advisory_lock(key1, key2)
pg_advisory_lock_shared(key)
pg_advisory_lock_shared(key1, key2)
```

Takes a **session** lock and waits until it is free. The lock is held until `pg_advisory_unlock` gives it back, or the connection closes.

| Argument | Type | Meaning |
|---|---|---|
| `key` | `LONG` | the lock name as one whole number |
| `key1`, `key2` | `INT` | the lock name as two numbers (a different set of names) |

- **Returns:** nothing (PostgreSQL calls this `void`; KDB shows an empty value).
- **NULL:** a `NULL` key gives `NULL` and takes no lock.
- **Notes:** `_shared` lets several connections hold the same key at once; a lock without `_shared` waits for all of them. Taking the same key twice in one connection works and needs two unlocks. Waiting stops after 30 seconds with an error.

**Example: Take the day-close lock, do the work, give it back** (sample data: sample)

```sql
SELECT pg_advisory_lock(918273) AS taken;
SELECT symbol, sum(quantity) AS shares FROM trade_log GROUP BY symbol ORDER BY symbol;
SELECT pg_advisory_unlock(918273) AS given_back;
```

Result:

`SELECT pg_advisory_lock(918273) AS taken`

| taken (STRING) |
|---|
|  |

(1 row)

`SELECT symbol, sum(quantity) AS shares FROM trade_log GROUP BY symbol ORDER BY symbol`

| symbol (SYMBOL) | shares (LONG) |
|---|---|
| CITY | 2420 |
| COAST | 3070 |
| TELCO | 2770 |
| VOLT | 400 |

(4 rows)

`SELECT pg_advisory_unlock(918273) AS given_back`

| given_back (BOOL) |
|---|
| true |

(1 row)

<a id="pg_advisory_xact_lock"></a>

## pg_advisory_xact_lock, pg_advisory_xact_lock_shared

Syntax:

```sql
pg_advisory_xact_lock(key)
pg_advisory_xact_lock(key1, key2)
pg_advisory_xact_lock_shared(key)
pg_advisory_xact_lock_shared(key1, key2)
```

The same, but the lock ends **with the transaction**. There is no unlock function for it.

| Argument | Type | Meaning |
|---|---|---|
| `key` | `LONG` | the lock name as one whole number |
| `key1`, `key2` | `INT` | the lock name as two numbers |

- **Returns:** nothing (`void`).
- **NULL:** a `NULL` key gives `NULL` and takes no lock.
- **Notes:** `COMMIT` and `ROLLBACK` free it. A statement outside `BEGIN ... COMMIT` is its own transaction, so the lock ends with that statement. This is the safest kind: a crash in the middle cannot leave the lock behind.

**Example: The lock is gone after COMMIT** (sample data: sample)

Setup:

```sql
BEGIN;
SELECT pg_advisory_xact_lock(918273) AS taken_for_this_transaction;
COMMIT;
```

```sql
SELECT pg_try_advisory_lock(918273) AS free_again;
```

Result:

| free_again (BOOL) |
|---|
| true |

(1 row)

<a id="pg_try_advisory_lock"></a>

## pg_try_advisory_lock, pg_try_advisory_lock_shared

Syntax:

```sql
pg_try_advisory_lock(key)
pg_try_advisory_lock(key1, key2)
pg_try_advisory_lock_shared(key)
pg_try_advisory_lock_shared(key1, key2)
```

Takes a **session** lock only if it is free right now. It never waits.

| Argument | Type | Meaning |
|---|---|---|
| `key` | `LONG` | the lock name as one whole number |
| `key1`, `key2` | `INT` | the lock name as two numbers |

- **Returns:** `BOOL`. `TRUE` the lock is yours, `FALSE` someone else holds it.
- **NULL:** a `NULL` key gives `NULL`.
- **Notes:** this is the one to use for "do this job only if nobody else is doing it". Remember to call `pg_advisory_unlock` with the same key when the job is done.

**Example: Skip the job when another copy already has the lock** (sample data: sample)

```sql
SELECT pg_try_advisory_lock(918273) AS first_call,
       pg_try_advisory_lock(918273) AS same_connection_again;
SELECT pg_advisory_unlock(918273) AS unlock_1, pg_advisory_unlock(918273) AS unlock_2;
```

Result:

`SELECT pg_try_advisory_lock(918273) AS first_call, pg_try_advisory_lock(918273) AS same_connection_a`

| first_call (BOOL) | same_connection_again (BOOL) |
|---|---|
| true | true |

(1 row)

`SELECT pg_advisory_unlock(918273) AS unlock_1, pg_advisory_unlock(918273) AS unlock_2`

| unlock_1 (BOOL) | unlock_2 (BOOL) |
|---|---|
| true | true |

(1 row)

<a id="pg_try_advisory_xact_lock"></a>

## pg_try_advisory_xact_lock, pg_try_advisory_xact_lock_shared

Syntax:

```sql
pg_try_advisory_xact_lock(key)
pg_try_advisory_xact_lock(key1, key2)
pg_try_advisory_xact_lock_shared(key)
pg_try_advisory_xact_lock_shared(key1, key2)
```

Takes a **transaction** lock only if it is free right now. It never waits, and it ends with the transaction.

| Argument | Type | Meaning |
|---|---|---|
| `key` | `LONG` | the lock name as one whole number |
| `key1`, `key2` | `INT` | the lock name as two numbers |

- **Returns:** `BOOL`. `TRUE` the lock is yours until the transaction ends, `FALSE` someone else holds it.
- **NULL:** a `NULL` key gives `NULL`.
- **Notes:** nothing to unlock: `COMMIT` or `ROLLBACK` frees it.

**Example: Take it only if free, inside a transaction** (sample data: sample)

```sql
BEGIN;
SELECT pg_try_advisory_xact_lock(918273) AS got_it;
COMMIT;
```

Result:

`BEGIN`

```text
transaction started
```

`SELECT pg_try_advisory_xact_lock(918273) AS got_it`

| got_it (BOOL) |
|---|
| true |

(1 row)

`COMMIT`

```text
transaction committed: 0 change(s) saved
```

<a id="pg_advisory_unlock"></a>

## pg_advisory_unlock, pg_advisory_unlock_shared

Syntax:

```sql
pg_advisory_unlock(key)
pg_advisory_unlock(key1, key2)
pg_advisory_unlock_shared(key)
pg_advisory_unlock_shared(key1, key2)
```

Gives back one **session** lock this connection holds.

| Argument | Type | Meaning |
|---|---|---|
| `key` | `LONG` | the lock name as one whole number |
| `key1`, `key2` | `INT` | the lock name as two numbers |

- **Returns:** `BOOL`. `TRUE` a lock was given back, `FALSE` this connection did not hold that key.
- **NULL:** a `NULL` key gives `NULL`.
- **Notes:** use `_shared` for a lock taken with `pg_advisory_lock_shared`. A key taken twice needs two unlocks. Transaction locks (`_xact`) cannot be unlocked this way; they end with the transaction.

**Example: Unlocking a key you do not hold gives FALSE** (sample data: sample)

```sql
SELECT pg_try_advisory_lock(918273) AS taken;
SELECT pg_advisory_unlock(918273) AS given_back,
       pg_advisory_unlock(918273) AS again,
       pg_advisory_unlock(55) AS never_held;
```

Result:

`SELECT pg_try_advisory_lock(918273) AS taken`

| taken (BOOL) |
|---|
| true |

(1 row)

`SELECT pg_advisory_unlock(918273) AS given_back, pg_advisory_unlock(918273) AS again, pg_advisory_un`

| given_back (BOOL) | again (BOOL) | never_held (BOOL) |
|---|---|---|
| true | false | false |

(1 row)

## pg_advisory_unlock_all

Syntax:

```sql
pg_advisory_unlock_all()
```

Gives back **every** session lock this connection holds.

- **Returns:** nothing (`void`).
- **NULL:** never `NULL`.
- **Notes:** transaction locks are not touched; they end with the transaction. A closing connection does this by itself, so you rarely need to call it.

**Example: Clean up after a job** (sample data: sample)

```sql
SELECT pg_advisory_lock(918273) AS lock_1;
SELECT pg_advisory_lock(918274) AS lock_2;
SELECT pg_advisory_unlock_all() AS all_given_back;
SELECT pg_try_advisory_lock(918273) AS free_again;
```

Result:

`SELECT pg_advisory_lock(918273) AS lock_1`

| lock_1 (STRING) |
|---|
|  |

(1 row)

`SELECT pg_advisory_lock(918274) AS lock_2`

| lock_2 (STRING) |
|---|
|  |

(1 row)

`SELECT pg_advisory_unlock_all() AS all_given_back`

| all_given_back (STRING) |
|---|
|  |

(1 row)

`SELECT pg_try_advisory_lock(918273) AS free_again`

| free_again (BOOL) |
|---|
| true |

(1 row)

<a id="settings"></a>

## Session settings: current_setting, set_config

Syntax:

```sql
current_setting(name)               the value, an error when it was never set
current_setting(name, missing_ok)   the value, or NULL when missing_ok is TRUE
set_config(name, value, is_local)   sets it and returns the value
SET name = 'value'                  the same as set_config(name, value, FALSE) (Postgres port)
SET LOCAL name = 'value'            the same as set_config(name, value, TRUE) (Postgres port)
```

A **setting** is a named text value your connection keeps. Apps use names of their own with a dot in them, like `app.allow_edit`, to tell a [trigger](triggers.md) what the next statement may do.

| Part | Meaning |
|---|---|
| `name` | the setting's name, any case; your own names have a dot: `nchartpro.allow_identity_update` |
| `value` | text |
| `is_local` | `TRUE`: only until the transaction ends (`COMMIT` or `ROLLBACK`); `FALSE`: until the connection closes |
| `missing_ok` | `TRUE`: a name never set gives `NULL` instead of an error |

- A value belongs to **one connection** (over HTTP, one [session](http-sessions-and-cursors.md#post-session)). Another connection never sees it.
- Triggers and procedures that your statement sets off see your values. Triggers made `DEFERRED` run later, outside your connection, so they do not.
- A `LOCAL` value outside `BEGIN ... COMMIT` lasts for the call only, as each call is its own transaction. On the Postgres port, `SET LOCAL` outside a transaction does nothing and sends warning `25P01`, as PostgreSQL does.
- After a `LOCAL` value ends, the name reads `''` (empty text), as in PostgreSQL.
- Built-in names answer too: `current_setting('TimeZone')` is the session's zone (`UTC` unless `SET TIME ZONE` or `kdb serve --timezone` names one).

**Example: Set a value, read it back, and ask for one never set** (sample data: sample)

```sql
SELECT set_config('app.allow_edit', 'on', TRUE) AS set_to,
       current_setting('app.allow_edit') AS read_back,
       current_setting('app.never_set', TRUE) AS missing,
       current_setting('TimeZone') AS time_zone;
```

Result:

| set_to (STRING) | read_back (STRING) | missing (STRING) | time_zone (STRING) |
|---|---|---|---|
| on | on | NULL | UTC |

(1 row)

A trigger that lets a DBA through only when the statement asked for it:

```sql
CREATE FUNCTION guard_email() RETURNS trigger AS $$
BEGIN
  IF current_setting('app.allow_edit', true) = 'on' THEN
    RETURN NEW;
  END IF;
  IF NEW.email IS DISTINCT FROM OLD.email THEN
    RAISE EXCEPTION 'email is write-once';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- the DBA, on the Postgres port:
BEGIN;
SET LOCAL app.allow_edit = 'on';
UPDATE users SET email = 'new@x.com' WHERE id = 7;
COMMIT;   -- the setting ends here
```
