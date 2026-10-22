# Change stream and live subscriptions: changes('t'), GET /api/changes, GET /api/subscribe

> Every committed INSERT, UPDATE and DELETE of a table as an ordered stream you can resume from its LSN, in SQL or over HTTP, and queries that push their changed rows.

- Category: HTTP API
- Keywords: change stream, changes, cdc, change data capture, GET /api/changes, api/changes, GET /api/subscribe, api/subscribe, subscribe, SUBSCRIBE, live query, push, server-sent events, sse, EventSource, Last-Event-ID, lsn, resume, exactly once, wal_archive
- See also: [Change revisions: GET /api/rev and kdb_rev()](revisions.md), [Backup, check, repair and restore](backup-and-safety.md), [Run SQL over HTTP (/exec, /exp)](http-exec.md), [Databases and the data folder](databases.md)

Every committed change of a table is already in KDB's log, in commit order, numbered by a **log sequence number** (LSN). The change stream reads it back:

- in SQL: `SELECT * FROM changes('t')`
- over HTTP: `GET /api/changes?table=t&from=<lsn>`, as server-sent events or JSON

A reader keeps the LSN it read last and asks for what came after it. It gets **every change exactly once, in commit order**, also after a restart or a crash of the server, because the stream only shows commits that are safe on disk and the log is what the server itself replays.

Nothing extra is written for this: a commit costs what it cost before.

<a id="changes"></a>

## changes('t')

Syntax:

```sql
SELECT * FROM changes('<table>' [, after_lsn [, max_rows]])
```

| Column | Meaning |
|---|---|
| `lsn` | the transaction's commit LSN. All rows of one transaction share it |
| `seq` | the row's place inside its transaction (0, 1, 2, ...) |
| `committed_at` | when the transaction committed |
| `op` | `upsert`, `delete` or `ddl` |
| `key` | `delete`: the row's partition and key (hex); `ddl`: the statement; otherwise NULL |
| the table's columns | `upsert`: the row as it is after the change; NULL for `delete` and `ddl` |

A table column named like one of the first five (a column `lsn`) is shown as `row_lsn`.

| op | Made by |
|---|---|
| `upsert` | `INSERT`, `UPDATE`, `POST /write`, `POST /imp`, `COPY`, a trigger. The log keeps the row after the change, so an INSERT and an UPDATE look the same |
| `delete` | `DELETE`, and the old row of an UPDATE that moved it to another key. The log keeps the key, not the old row |
| `ddl` | a schema change that names the table: `TRUNCATE`, `ALTER TABLE`, `DROP PARTITION`, `CREATE TABLE`; also a `DELETE` that removed whole partitions ([DELETE](update-delete.md#delete)), as `ALTER TABLE ... DROP PARTITION` |

Arguments:

| Argument | Meaning |
|---|---|
| `after_lsn` | only changes committed after this LSN. `0` or none: from the oldest change the kept log still holds |
| `max_rows` | stop after about this many rows. It stops **between transactions**, never inside one, so reading on from the last `lsn` never skips a row. A transaction bigger than `max_rows` comes whole on its own |

Without `max_rows`, a read of more than 100,000 rows is an error: read in parts. `WHERE lsn > x` and a plain `LIMIT n` are passed down, so they read only what they need:

**Example: Every change of a table, in order**

```sql
CREATE TABLE acct (id INT PRIMARY KEY, name STRING, bal DOUBLE);
INSERT INTO acct VALUES (1, 'Asha', 10), (2, 'Bikash', 20);
UPDATE acct SET bal = 15 WHERE id = 1;
DELETE FROM acct WHERE id = 2;
SELECT seq, op, id, name, bal FROM changes('acct') WHERE op <> 'ddl';
```

Result:

`CREATE TABLE acct (`

```text
table 'acct' created
```

`INSERT INTO acct VALUES (1, 'Asha', 10), (2, 'Bikash', 20)`

```text
2 row(s) inserted
```

`UPDATE acct SET bal = 15 WHERE id = 1`

```text
1 row(s) updated
```

`DELETE FROM acct WHERE id = 2`

```text
1 row(s) deleted
```

`SELECT seq, op, id, name, bal FROM changes('acct') WHERE op != 'ddl'`

| seq (INT) | op (STRING) | id (INT) | name (STRING) | bal (DOUBLE) |
|---|---|---|---|---|
| 0 | upsert | 1 | Asha | 10 |
| 1 | upsert | 2 | Bikash | 20 |
| 0 | upsert | 1 | Asha | 15 |
| 0 | delete | NULL | NULL | NULL |

(4 rows)

To read on, remember the largest `lsn` you have **fully** read and ask for `changes('acct', that_lsn)` or `WHERE lsn > that_lsn`. Be careful with a SQL `LIMIT`: it cuts exactly, maybe inside a transaction. The `max_rows` argument and `GET /api/changes` never do.

<a id="api-changes"></a>

## GET /api/changes

Syntax:

```sql
GET /api/changes?table=<name>[&from=<lsn>][&limit=<n>][&wait=<ms>][&format=sse|json][&db=<name>]
```

| Parameter | Meaning |
|---|---|
| `table` | the table (required) |
| `from` | read after this LSN (`0` or none: from the oldest kept). Without it the `Last-Event-ID` header is used, which a browser's `EventSource` sends when it asks again |
| `limit` | about this many rows at most (default 1000); whole transactions only |
| `wait` | with nothing new, wait up to this many ms for a commit (default 25000 for events, 0 for JSON; at most 55000) |
| `format` | `sse` (default): server-sent events. `json`: one JSON object |

As **server-sent events**, each change is an event `change` whose data is `{"lsn", "seq", "committed_at", "op", "key", "row"}`. The last change of each transaction carries `id: <lsn>`. The answer ends with an event `position` whose id is where to read on. A browser needs nothing more than:

```js
const es = new EventSource('/api/changes?table=trades');
es.addEventListener('change', (e) => apply(JSON.parse(e.data)));
// EventSource asks again by itself, sending the last id it saw:
// nothing is missed and nothing comes twice.
```

Each request waits for a commit, answers, and ends; the client then asks again (`retry: 1000`). A change arrives within milliseconds of its commit. At most a quarter of the server's HTTP threads (`--threads`) wait at once; the others answer at once with what there is, so waiting readers never take the threads `/exec` needs.

As **JSON** (`format=json`): `{"table", "changes": [...], "next", "more", "durable_lsn", "oldest_lsn"}`. Read on with `from=<next>`; `more: true` means more is ready now.

**HTTP: The changes of a table as JSON**

Setup:

```text
CREATE TABLE acct (id INT PRIMARY KEY, name STRING, bal DOUBLE);
INSERT INTO acct VALUES (1, 'Asha', 10);
```

```http
GET /api/changes?table=acct&format=json
```

Response:

HTTP 200 (application/json)

```text
{
  "table": "acct",
  "changes": [
    {
      "lsn": 2,
      "seq": 0,
      "committed_at": "2026-10-22T05:43:31.573Z",
      "op": "ddl",
      "key": "CREATE TABLE acct (\n  id INT PRIMARY KEY,\n  name STRING,\n  bal DOUBLE\n)",
      "row": null
    },
    {
      "lsn": 4,
      "seq": 0,
      "committed_at": "2026-10-22T05:43:31.577Z",
      "op": "upsert",
      "key": null,
      "row": {"id": 1, "name": "Asha", "bal": 10}
    }
  ],
  "next": 4,
  "more": false,
  "durable_lsn": 4,
  "oldest_lsn": 1
}
```

It needs read rights on the table: role `read` on the database, or `GRANT SELECT` on the table. An unknown table is a 404.

<a id="retention"></a>

## How long changes are kept

The stream reads the log, and the log is kept as long as the database's `wal_archive` setting allows: `ALTER DATABASE ... SET WAL_ARCHIVE = '2GB'`, the server default `KDB_WAL_ARCHIVE_MB` / `wal_archive_mb` in `kdb.conf` (1 GB unless set). A reader that falls further behind than that is **never** given a stream with a hole: `changes()` fails and `GET /api/changes` answers **410 Gone**, with `gone_before`, the first LSN still kept. Such a reader starts again from a fresh copy of the table (`SELECT *`) and then reads on from `oldest_lsn`.

A slow or lost reader cannot fill the disk: it keeps no log for itself. While one read runs (milliseconds), only the log after its position stays where it is; older log and replaced data files are cleaned up as usual. Readers never slow down writers: a poll does not list the log folders.

<a id="api-subscribe"></a>

## GET /api/subscribe

A **live query**: the answer of one `SELECT`, and afterwards only the rows a commit changed.

Syntax:

```sql
GET /api/subscribe?query=SUBSCRIBE SELECT ...[&wait=<ms>][&db=<name>]
```

1. The first request answers at once with an event `snapshot`: `{"table", "symbol", "columns", "rows"}` and an id: `<subscription>.<version>`, naming the subscription and the answer the client has.
2. Asked again with that id (`Last-Event-ID`, or `&id=`), the request waits until a commit changes the table, runs the query again, and sends an event `rows`: `{"columns", "rows", "removed"}` with the rows that are **new or changed**, and how many rows left the answer. A candle query over `date_trunc` buckets gets the one bucket a trade changed, as its new version.
3. With nothing changed before `wait` ends, the answer has no `rows` event, only the id to ask again with.

An answer lost on the way (a dropped connection, a proxy timeout) is not lost for the client: it asks again with the id it really has, and gets the same change again. An id with a version the server no longer keeps gets a fresh `snapshot`, which replaces everything the client has. A client that reconnects while its old request still waits takes over: the old request ends and the new one answers, so an `EventSource` never gets an error and stops.

When the `WHERE` picks one value of the table's [revision column](revisions.md#rev-column) (`WHERE symbol = 'NABIL'`), only a commit of that symbol wakes the subscriber: a NEPSE trade does not. Otherwise any commit of the table does.

```js
const q = encodeURIComponent(`SUBSCRIBE SELECT date_trunc('minute', time) AS m, first(price) AS open,
  max(price) AS high, min(price) AS low, last(price) AS close
  FROM trades WHERE symbol = 'NABIL' GROUP BY m ORDER BY m`);
const es = new EventSource('/api/subscribe?query=' + q);
es.addEventListener('snapshot', (e) => drawAll(JSON.parse(e.data).rows));
es.addEventListener('rows', (e) => JSON.parse(e.data).rows.forEach(upsertCandle));
```

Limits: one table (no joins, subqueries in `FROM`, `UNION` or `WITH`); at most 10,000 rows in the answer; 10,000 subscriptions per server (when that is reached, the one asked for longest ago makes room, and its client gets a fresh `snapshot` when it asks again); a subscription nobody asked for in 2 minutes is dropped, and asking with an unknown id gives a fresh `snapshot`. The query runs with the caller's rights, like `/exec`.

`SUBSCRIBE` sent to `/exec` or the PostgreSQL port is an error that points here: those answer once and cannot push.
