# Monitor panel (memory, processor, caches)

> What the server is doing right now - memory it holds, processor it uses, what each database keeps in memory, deferred trigger queues, and the statements running this second.

- Category: Web console
- Keywords: monitor, timers, timer failures, late timer, Monitor panel, monitoring, memory, RAM, resident, working set, processor, CPU, threads, uptime, running statements, cancel statement, kill query, result cache, cache hits, cached results, memory budget, loaded partitions, pending rows, checkpoint, open cursors, log position, LSN, deferred trigger queue, trigger lag, failed job, /api/stats, activity, activity log, server log, terminal, what the server is doing, GET /api/activity, --activity-log-size, X-KDB-Quiet, slow statements, slow queries, --slow-query-ms, disk use, on disk, trash, metrics
- See also: [Web console](web-console.md), [Settings page (data folder, old log, capacity, program files and users)](console-settings.md), [View data page (browse and edit rows)](console-data-page.md), [Health, info, check and backup over HTTP](http-server-info.md), [Performance tips](performance-tips.md), [Protection - timeouts, limits, safe updates, read-only](protection.md), [kareladb serve](cli-serve.md), [Triggers](triggers.md)

The **Monitor** panel of the [web console](web-console.md) shows the inside of a running `kareladb serve`: how much memory the process holds, how busy the processor is, what each open database keeps in memory, and which statements are running right now. Open it with the **Monitor** button on the [right side](web-console.md#right-side) of the console. It is a panel, not a page: pin it to keep it open beside the page you work on.

It reads [`GET /api/stats`](http-server-info.md#api-stats) every couple of seconds. Everything there is a counter already in memory, so asking often costs almost nothing: no file is read and no database is opened to answer it.

- Any login that may **read** can see the panel. A `read` user sees only their own running statements, because statement text can hold values; an `admin` sees everyone's.
- **Refresh** at the top picks 2, 5, 10 or 30 seconds, or **Off**; **Now** reads the numbers at once. The panel stops asking while it is closed or the browser tab is hidden.
- `/api/stats` holds more than the panel shows, for example the zone map counters (`zone_partition_skips`, `zone_block_skips`), `cache_pinned` and the memory of each database by kind. Read it from a script for those ([GET /api/stats](http-server-info.md#api-stats)).

<a id="opening"></a>

## Warnings and databases opening

At the top, in a yellow frame, the server's `warnings`: today, a database far bigger than `--memory` ([why it matters](cli-serve.md#memory-warning)).

Below them, one card per database being opened right now. A big database replays the log written after its last checkpoint, which over a slow disk takes minutes, and its first request waits that long. The card shows what the open does now (`checking log`, `replaying log`, `loading tables`, ...), for how long, how much of the log is replayed, and how many table files it went through. When the numbers move, the open is working; the card goes away when the database is open.

In a database's card, a **Checkpoint** line shows a checkpoint writing changes to partition files: the table, partitions written of how many, and for how long. **Busy** means a write or a checkpoint held the database when the panel asked: the memory numbers are live, the tables and queues are from the reading before. The panel never waits for a busy database.

<a id="process"></a>

## The server process

| Number | What it means |
|---|---|
| **Memory in RAM** | what the operating system says this process holds now (Windows: working set; Linux: `VmRSS`). The bar is its share of the RAM in the computer. |
| **Most it ever held** | the highest that number has been since the server started |
| **Processor** | share of one processor used between the last two readings. 100 % means one processor fully busy; on 8 processors the most is 800 %. It is blank until the panel has asked twice. |
| **Running for** | how long the process has been up |
| **Threads** | threads the process runs now: the query threads (`--threads`), the HTTP server (one thread that accepts connections and a pool of workers that answer requests, `--http-threads`), the PostgreSQL port, and the background threads (checkpoints, timers, the audit log) |
| **Open handles** | open files and sockets |
| **Free RAM on this computer** | what a program could still get. Inside a container this is the container's limit, not the host's RAM. |
| **Processors** | processors the process may use |

Memory in RAM is bigger than the memory budget below it: the budget covers **table data**, while the process also holds indexes, results being built, and the program itself.

<a id="running"></a>

## Statements running now

One line per statement, over HTTP and the [PostgreSQL port](postgres-protocol.md) together:

| Column | What it is |
|---|---|
| **Elapsed** | how long it has been running |
| **Lane** | `fast`, `normal` or `heavy` ([priority lanes](cli-serve.md#lanes)); `heavy (waiting)` while a report waits for a heavy slot |
| **User** | the user who sent it, or `(token)` for the [access token](http-login.md#token) |
| **Database** | which database it runs against |
| **From** | the address it came from, and which port (`http` or `pg`) |
| **Statement** | the first 200 characters |
| **Cancel** | stops it: `DELETE /exec/<id>`. It becomes `stopping` until it winds down. |

**Cancel** needs a name to cancel by, which is the `X-KDB-Request-Id` header the client sent. A client that sent none shows `no id` instead; it still stops on its own [statement timeout](protection.md). The console itself always sends one. There is no **Cancel** at all on a server started without query protection (`can_cancel` is `false` in `/api/stats`).

A statement that is stuck is usually one of the things in [performance tips](performance-tips.md): a `SELECT` with no time range on a big time-series table, a join without a matching key, or a `GROUP BY` over too many groups.

<a id="lanes"></a>

## Lanes

Shown while [priority lanes](cli-serve.md#lanes) are on: the heavy slots in use, how many reports wait for one, how many statement shapes are known to be heavy, and whether heavy statements run at a lower CPU priority here. The table has one line per lane: how many run and wait now, how many started since the server did, how many had to wait and for how long (average and longest), how many were refused because the HTTP line was full (only requests sent with priority `low`), how many ran at once because it was full (heavy only by history), and how many gave up waiting (a timeout or a cancel).

<a id="slow"></a>

## Slow statements

The newest 20 statements that took at least the slow-query threshold (`kareladb serve --slow-query-ms`, 1 second by default), from [`GET /api/slow-queries`](http-server-info.md#slow-queries). They are kept in a file on disk, so last night's slow statement is still here in the morning, after a restart too.

| Column | What it is |
|---|---|
| **When** | when it ended |
| **Took** | how long it ran |
| **User**, **Database** | who sent it (the token's name for the [access token](audit-log.md)), and where |
| **Statement** | the statement; `failed:` in front when it did not succeed. Point at it for the whole text and the error. |

The list is read every 10 seconds at most, and at once with **Now**.

<a id="timers"></a>

## Timers

Every [timer](timers.md) of the databases you may read, also of databases not open yet. Timers in trouble come first: failing now, then failed in the last 24 hours, then the latest to start. The title counts the timers with failures.

| Column | What it is |
|---|---|
| **Timer** | `database.name`; `(off)` when it is turned off. Point at it for the schedule, the next run and the SQL. |
| **Last run** | how long ago it last ran and whether that run was `ok` or `failed` (red); `running now` while it runs |
| **Late** | how many seconds after its due time the last run got its write in; yellow above 5 s. Point at it for the worst since the server started. |
| **Failed 24 h** | runs that failed in about the last 24 hours (red when not 0). Point at it for the count since the server started. |
| **Last error** | the last run's error, or `-` |

The numbers come with the rest of `/api/stats` (`timers`), from memory: nothing is read from disk for them.

<a id="databases"></a>

## Each database

Only databases that are **open** are listed. A database opens the first time it is used, so a server that has just started may show none - that is not a fault.

| Number | What it means |
|---|---|
| **Rows held in memory** | saved partition data kept in memory, against the budget (`--memory`, 512 MB by default). When it is full, the partitions used longest ago are dropped and read again when next needed. |
| **Waiting to be written** | changes that are in the log but not yet in the partition files. A checkpoint writes them; it starts by itself at a quarter of the memory budget. |
| **Result cache** | memory holding results of repeated queries (`--cache-mb` or `cache_mb` in kareladb.conf, 256 MB by default; 0 turns it off) |
| **Cache hits** | share of queries answered from that cache since the database was opened |
| **Cached results** | how many results are in that cache now |
| **Open cursors** | [cursors](cursors.md) a client has open (`POST /cursor`) |
| **Log position** | the last change written to the log (the LSN) |
| **On disk** | what the database takes on disk. The bar is the share that is data; point at it for the parts: data, older versions, trash, log, old log. Measured once a minute. Older versions and trash go by themselves (`keep_versions`, `trash_keep_hours`, `trash_max_mb` in [kareladb.conf](cli-serve.md#kareladb-conf)); the [Keep data page](console-keep-data.md) frees them at once. |
| **Open for** | how long ago the server opened this database |

A database with [deferred triggers](triggers.md#deferred) also shows **Deferred trigger queues**, one line per trigger:

| Column | What it means |
|---|---|
| **Trigger**, **Table** | the trigger and the table it watches |
| **Waiting** | jobs not finished yet |
| **Lag** | how long the oldest waiting job has waited (`-` when none waits) |
| **Running** | the job running now and its rows, or `-` |
| **Failed job** | a job that failed and stopped the queue, with its error. Fix the cause, then run `RETRY TRIGGER QUEUE <trigger>`. |

The same numbers come from [GET /api/trigger-queue](http-server-info.md#api-trigger-queue), which can also wait until the jobs are done.

**Tables** opens a line per table:

| Column | What it means |
|---|---|
| **Rows** | rows saved in partition files |
| **In memory** | how much of that table's data is in memory now |
| **Partitions** / **Loaded** | how many partitions the table has, and how many are in memory |
| **Not yet written** | rows changed since the last checkpoint |

This is the quickest way to see which table is using the memory budget, and whether a big load has been written to disk yet.

<a id="activity"></a>

## Server activity

The [terminal](web-console.md#terminal) at the bottom of the Home page shows what the server has done lately, newest at the bottom: every statement that ended, every bulk load and where it came from, timer runs, deferred trigger jobs, logins and backups. It reads `GET /api/activity`, described here.

| Kind | One event for |
|---|---|
| `query` | a statement over HTTP (`/exec`, `/exp`, `/cursor`) or the [PostgreSQL port](postgres-protocol.md), when it ends |
| `write` | a `POST /write` ([line protocol](line-protocol.md)) or `POST /imp` ([CSV import](http-import.md)) request: its rows and tables |
| `timer` | a run of a [timer](timers.md) |
| `trigger` | a job of a [deferred trigger](triggers.md#deferred) that finished or failed (client `(deferred trigger)`) |
| `login` | a login that worked, a failed login, a lockout |
| `backup` | a backup made from the console or the [backup schedule](backup-schedule.md) |
| `server` | the server started or stops |

- It is kept **in memory only**: the last 5,000 events (`kareladb serve --activity-log-size N`, `0` turns it off). A restart starts it empty. For a record that is kept, use the [audit log](audit-log.md).
- Passwords, secrets and tokens in SQL show as `'***'`, and long statements are cut to 300 characters.
- A bulk load is **one** event per request, never one per row, so logging does not slow loading down.
- Requests with the header `X-KDB-Quiet: 1` are not logged. The console sends it with its own background refreshes.

Syntax:

```sql
GET /api/activity[?after=<seq>][&limit=<n>][&db=<name>]
```

| Parameter | Meaning |
|---|---|
| `after` | only events with a larger `seq`. Leave it out for the newest events. |
| `limit` | at most this many events (default 500, at most 2000) |
| `db` | only events of this database |

The reply is `{"seq", "dropped", "events"}`. `seq` is the newest event's number: send it back as `after` to get only what is new. `dropped` is `true` when some events after `after` were already pushed out of memory.

| Event field | Meaning |
|---|---|
| `seq`, `ms` | its number, and when it happened (Unix milliseconds) |
| `kind`, `level` | see the table above; `level` is `info`, `ok` or `error` |
| `user` | who did it; empty for the access token |
| `client` | where it came from: `10.0.0.5 (pg)`, `127.0.0.1 (http)`, `(timer refresh_prices)` |
| `database`, `text` | the database, and the statement or a message like `12,000 rows into trade_log (line protocol)` |
| `rows`, `took_ms`, `error` | rows changed or returned (`-1` = not known), how long it took, and the error |

An admin (or the token) sees every event; any other user sees only their own.

**HTTP: Run a statement, then read the newest events**

```http
POST /exec?compat=0

SELECT 1 + 1 AS two
###
GET /api/activity?limit=2
```

Response:

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "SELECT 1 + 1 AS two",
  "results": [
    {
      "statement": "SELECT 1 + 1 AS two",
      "columns": [
        {"name": "two", "type": "LONG"}
      ],
      "dataset": [
        [2]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 39, "execute_us": 103}
    }
  ],
  "timings": {"parse_us": 39, "execute_us": 103}
}
```

`GET /api/activity?limit=2`

HTTP 200 (application/json)

```text
{
  "seq": 3,
  "dropped": false,
  "events": [
    {
      "seq": 2,
      "ms": 1792813293394,
      "kind": "query",
      "level": "ok",
      "user": "",
      "client": "127.0.0.1 (http)",
      "database": "h119",
      "text": "CREATE TABLE acct (id INT PRIMARY KEY, name STRING, bal DOUBLE); INSERT INTO acct VALUES (1, 'Asha', 10);",
      "rows": 1,
      "took_ms": 44,
      "error": ""
    },
    {
      "seq": 3,
      "ms": 1792813301882,
      "kind": "query",
      "level": "ok",
      "user": "",
      "client": "127.0.0.1 (http)",
      "database": "demo",
      "text": "SELECT 1 + 1 AS two",
      "rows": 1,
      "took_ms": 0,
      "error": ""
    }
  ]
}
```

<a id="not"></a>

## What it does not show

- Numbers of the past: the panel keeps nothing, so a reload starts fresh. For a history, let Prometheus read [`GET /metrics`](http-server-info.md#metrics), or read `/api/stats` from a script every minute and keep the rows in a table.
- Statements that finished long ago. The [activity](#activity) keeps only the recent ones in memory; the [audit log](audit-log.md) (`SHOW AUDIT`) keeps who changed what.
- Damage and backups; those are in the [Health panel](web-console.md#health-box) on the right side of the console and in [`/api/info`](http-server-info.md#get-api-info).

```bash
curl -s -H "Authorization: Bearer $KARELADB_TOKEN" http://127.0.0.1:9900/api/stats
```
