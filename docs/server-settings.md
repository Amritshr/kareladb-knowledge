# Settings - SET, SHOW ALL, ALTER SYSTEM

> One list of the server's settings behind pg_settings, SHOW ALL, SHOW PARAMETERS and GET /api/settings; SET for a session, ALTER SYSTEM and pg_reload_conf() for the server.

- Category: Postgres protocol
- Keywords: settings, pg_settings, SHOW ALL, SHOW PARAMETERS, SET, RESET, ALTER SYSTEM, pg_reload_conf, current_setting, work_mem, max_parallel_workers_per_gather, enable_hashjoin, enable_nestloop, enable_indexscan, log_statement, plan_cache_mode, plan cache, kdb.conf, kdb_settings, QuestDB, parameters, txn_spill_mb, memory_limit
- See also: [PostgreSQL protocol (port 8832)](postgres-protocol.md), [PostgreSQL-compatible functions](functions-postgres.md), [kdb serve](cli-serve.md), [Settings page (data folder, old log, capacity, program files and users)](console-settings.md), [Limits](limits.md), [Joins](joins.md), [Indexes](indexes.md)

KDB keeps **one list** of its settings. The same list is behind:

| Where | Shows |
|---|---|
| `SELECT * FROM pg_settings` | PostgreSQL's view: name, setting, unit, context, source, ... |
| `SHOW ALL` | name, value (as `SHOW` writes it: `4MB`, `5s`) and description |
| `SHOW PARAMETERS` | QuestDB's view: property path, environment variable, value, where it came from |
| `SELECT * FROM kdb_settings` | all of the above in one table, to filter with `WHERE` |
| `GET /api/settings` | the list under `"parameters"`, with the server's values |
| `SHOW work_mem`, `current_setting('work_mem')` | one setting, for this session |

Each setting says what KDB does with it (the `use` column of `kdb_settings`):

| use | Meaning |
|---|---|
| `applied` | KDB acts on it (`statement_timeout`, `work_mem`, `enable_hashjoin`, ...) |
| `shown` | kept and shown for clients, but KDB works the same either way (`DateStyle`, `search_path`) |
| `ignored` | accepted so PostgreSQL scripts run, with a NOTICE (`shared_buffers` in a session, `enable_seqscan`, `jit`, ...) |

<a id="set"></a>

## Change a setting for this session

Syntax:

```sql
SET name = value          SET name TO value
SET LOCAL name = value    until COMMIT or ROLLBACK
RESET name                RESET ALL
SHOW name                 SHOW ALL
```

A value can have a unit, as in PostgreSQL: `SET work_mem = '64MB'`, `SET statement_timeout = '5s'`. `SHOW` gives it back the same way. A bad value gives `22023`, an unknown name on `SHOW` gives `42704`.

The `context` column says when a setting may change:

| context | Changes with |
|---|---|
| `user` | `SET` in any session |
| `superuser` | `SET` by an admin (`log_statement`) |
| `sighup` | `ALTER SYSTEM` and `SELECT pg_reload_conf()` |
| `postmaster` | a restart: a `kdb serve` flag, `kdb.conf` or an environment variable (`55P02` on `SET`) |
| `internal` | never (`server_version`, `block_size`) |

Over HTTP, a `SET` lasts for the rest of the same request (and for the whole session when you use one: [sessions](http-sessions-and-cursors.md)).

**Example: Set and read a setting**

```sql
SET work_mem = '64MB';
SHOW work_mem;
SELECT name, setting, unit, source FROM pg_settings WHERE name IN ('work_mem', 'enable_hashjoin');
```

Result:

`SET work_mem = '64MB'`

```text
work_mem is 64MB for this session
```

`SHOW work_mem`

| work_mem (STRING) |
|---|
| 64MB |

(1 row)

`SELECT name, setting, unit, source FROM pg_settings WHERE name IN ('work_mem', 'enable_hashjoin')`

| name (STRING) | setting (STRING) | unit (STRING) | source (STRING) |
|---|---|---|---|
| enable_hashjoin | on | NULL | default |
| work_mem | 65536 | kB | session |

(2 rows)

<a id="planner"></a>

## The planner settings KDB applies

| Setting | Default | What it does |
|---|---|---|
| `work_mem` | `0` | how much a `GROUP BY` keeps in memory before its groups go to temporary files. `0` = half of the statement's working memory. Never more than three quarters of it |
| `max_parallel_workers_per_gather` | the server's threads | threads one statement's scans and aggregates may use, its own included. `0` or `1` = one thread |
| `enable_hashjoin` | `on` | `off`: equality joins compare every pair of rows (a nested loop) instead of building a hash |
| `enable_nestloop` | `on` | `off`: a join does not look each row's match up by key or index; it builds a hash |
| `enable_indexscan` | `on` | `off`: no secondary index finds rows; the table is scanned. A full-text search keeps its index |
| `log_statement` | `none` | `ddl`, `mod` or `all`: statements go to the server's log as `LOG:  statement: ...` (admins only) |
| `plan_cache_mode` | `auto` | `force_custom_plan`: this session's statements are parsed every time; they neither use nor fill the [plan cache](#plan-cache). `auto` and `force_generic_plan` use it |

The switches are there to compare answers and times, as in PostgreSQL. They are read once per statement, never per row.

<a id="memory"></a>

## Memory settings set at start

These change only with a restart (`postmaster`): a `kdb serve` flag or an environment variable.

| Setting | Default | Flag / variable | What it does |
|---|---|---|---|
| `memory_limit` | none | `--memory-limit`, `KDB_MEMORY_LIMIT` | one limit for everything the server holds |
| `shared_buffers` | 512 MB | `--memory`, `KDB_MEMORY` | table data kept loaded |
| `txn_spill_mb` | `64` | `--txn-spill-mb`, `KDB_TXN_SPILL_MB` | a transaction's log records past this many MB (or 1/16 of `memory_limit`) go to a temporary file until `COMMIT`. `0` = never. See [big transactions](transactions.md#txn-spill) |

**Example: Read the memory settings**

```sql
SELECT name, setting, unit, context FROM pg_settings WHERE name IN ('memory_limit', 'txn_spill_mb') ORDER BY name;
```

Result:

| name (STRING) | setting (STRING) | unit (STRING) | context (STRING) |
|---|---|---|---|
| memory_limit | 0 | kB | postmaster |
| txn_spill_mb | 64 | MB | postmaster |

(2 rows)

<a id="plan-cache"></a>

## The plan cache

An app sends the same small statement again and again: a key lookup, a price, a session check. Parsing it can take as long as running it. So the server keeps the parse of a statement it has seen, by its exact text, and the next run of the same text skips the parse.

| What | How |
|---|---|
| Who uses it | every client: `POST /exec`, `GET /exec` and the PostgreSQL port's simple query (prepared statements keep their own parse per connection) |
| What is kept | one `SELECT` the first time; one `INSERT ... VALUES`, `UPDATE` or `DELETE` when the same text comes a second time. Not `SELECT ... FOR UPDATE`, a `WITH` that changes rows, or a statement that names another database |
| Same statement, other values | an `INSERT ... VALUES`, `UPDATE`, `DELETE` or `CALL` is also kept by its *shape* - the text with its numbers and `'strings'` left out - the first time, per connection (or HTTP worker). The next text of that shape, `INSERT INTO t VALUES (1018, 'open')` after `(1017, 'paid')`, runs the kept parse with its own values put in: the same tree a parse would make, without the parse. Only when every value is a plain value; a `LIMIT`, a cast's precision, a `SIMILAR TO` pattern or a `GROUP BY` keeps the text parsed every time |
| Per database | each database has its own entries, even for the same text |
| After a schema change | `CREATE`, `ALTER` or `DROP` of a table: the next run parses the text again |
| Size | up to 2,048 texts of at most 2 KB each; when full, one not used lately goes |
| Planned on each run | which index, which engine and which partitions are worked out again every time, with the values of that run |

The answers never change: only the time to parse is saved. `GET /api/stats` shows it under `"plan_cache"`:

| Field | Meaning |
|---|---|
| `hits` | runs that skipped the parse |
| `misses` | statements it could keep that had to be parsed: the first time, or after a schema change |
| `entries` | parses kept now |
| `capacity` | texts it keeps at most |

To leave it out for one session, as PostgreSQL does for its own plan cache:

**Example: Parse every statement of this session**

```sql
SET plan_cache_mode = force_custom_plan;
SHOW plan_cache_mode;
```

Result:

`SET plan_cache_mode = 'force_custom_plan'`

```text
plan_cache_mode is force_custom_plan for this session
```

`SHOW plan_cache_mode`

| plan_cache_mode (STRING) |
|---|
| force_custom_plan |

(1 row)

<a id="alter-system"></a>

## Change a setting for the server

Syntax:

```sql
ALTER SYSTEM SET name = value
ALTER SYSTEM RESET name
ALTER SYSTEM RESET ALL
SELECT pg_reload_conf();
```

`ALTER SYSTEM` saves the value in `kdb.conf`, under `"system"`. It is in use after `SELECT pg_reload_conf()` (or the next start) for every new statement of every session that did not `SET` it itself. Only a server admin may run either. `ALTER SYSTEM` cannot run inside `BEGIN ... COMMIT`.

```text
ALTER SYSTEM SET work_mem = '256MB';
ALTER SYSTEM SET log_statement = 'ddl';
SELECT pg_reload_conf();       -- true
```

`kdb.conf` then holds:

```text
{
  "data_dir": "/data",
  "system": {"log_statement": "ddl", "work_mem": "262144"}
}
```

- Settings that only change with a restart (`port`, `shared_buffers`, `max_connections`, ...) give `55P02` and name the flag or `kdb.conf` key to use.
- A database folder served by its path (`kdb serve D:\kdb\market`) has no `kdb.conf` of its own: `ALTER SYSTEM` says so.
- A value in `kdb.conf` that is no longer valid is skipped with a warning in the server's log; the default is used.

<a id="fixes"></a>

## Also fixed on 2026-09-26

- `KDB_NO_ZONE_MAPS=0` (and every other `KDB_NO_*` switch set to `0`, `off`, `no` or `false`) now means **off**: the speed-up stays on. Some switches used to turn off for any value.
- An on/off variable set but empty (`KDB_SCOPED_DDL=` in a compose file) no longer stops the server: it counts as not set. `true`/`false`, `yes`/`no` and `1`/`0` work too.
- `kdb serve <folder>` (a database folder by its path) no longer takes `alert_webhook` from the default `kdb.conf`, like every other `kdb.conf` setting.
- `KDB_INDEX_MAX_VISITS` must be a whole number of 1 or more; any other value is ignored with a warning, instead of making ordered index reads give up at once.
- `kdb help` lists what `kdb.conf` may hold.
