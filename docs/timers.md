# Timers

> Let the server run a procedure, a function or any SQL by itself at set times, so a table stays up to date.

- Category: Stored procedures
- Keywords: timer, timers, schedule, scheduled job, job, cron, every, hourly, daily, weekdays, sun-thu, mon-fri, trading week, trading days, holidays, trading nepse 15:05, catch up, skipped, monthly, retention, keep data for, run on time, back to back, timer\_workers, --timer-workers, KARELADB\_TIMER\_WORKERS, GET /api/timers, POST /api/timers, POST /api/timers/\<name\>/run, \_timers
- See also: [Stored procedures](procedures.md), [Saved functions](saved-functions.md), [Triggers](triggers.md), [Trading calendars](calendars.md), [Backups on a schedule](backup-schedule.md), [HTTP API overview](http-overview.md)

A **timer** is saved SQL that the server runs by itself at set times, inside one database. Most timers call a [procedure](procedures.md), so a table of totals, candles or reports is kept up to date without a cron job outside KarelaDB.

| Part | Example | Rule |
|---|---|---|
| name | `daily_totals` | 1 to 64 letters, digits, `_` and `-`; unique in its database (case does not matter) |
| schedule | `every 5m` | see [Schedules](#schedules) |
| SQL | `CALL refresh_daily_totals()` | any SQL of that database, up to 64 KB; it must parse when the timer is saved |
| enabled | `true` | a timer that is off does not run on its schedule, but **Run now** still works |

- Timers run while `kareladb serve` runs. They are saved in the table `_timers` of the hidden `_system` database, or of the served database when `kareladb serve` runs on one folder, so they survive restarts and are part of every backup.
- A timer runs with the rights of the user who saved it last. Saved with the token, it may do everything.
- **Who may do what.** Reading the list needs `read` on the database. Saving, running, turning off and deleting a timer need `admin` on that database, as `CREATE TRIGGER` and `CREATE PROCEDURE` do, because a timer is saved code that runs later by itself.
- **Audited.** Every save, **Run now**, turn on or off and delete is one row in the [audit log](audit-log.md) with the event `timer`, the user, the database and the timer's name.
- A timer works inside its own database: `USE`, `CREATE DATABASE`, `DROP DATABASE`, `SET` and user statements are refused.

<a id="schedules"></a>

## Schedules

Times are the local time of the computer the server runs on, or the zone of `kareladb serve --timezone Asia/Kathmandu` when it is set (a container runs on UTC, so set it there: `daily 15:10` then runs at 15:10 Nepal time).

| Schedule | Runs |
|---|---|
| `every 10s` | every 10 seconds (1 second to 24 hours: `s`, `m` or `h`) |
| `every 5m` | every 5 minutes, counted from midnight: 00:00, 00:05, 00:10 ... |
| `every 2h` | every 2 hours from midnight |
| `hourly` | at minute 0 of every hour |
| `hourly :15` | at minute 15 of every hour |
| `daily 16:00` | every day at 16:00 |
| `daily 02:00,13:30` | several times a day |
| `weekdays 11:00` | Monday to Friday at 11:00 |
| `sun-thu 11:00` | Sunday to Thursday at 11:00. Name the days for a week that is not Monday to Friday, like a Nepal market week |
| `mon,wed,fri 09:30` | on the days named, at 09:30 (`weekly mon,wed,fri 09:30` is the same). Days: `sun mon tue wed thu fri sat`; a range may go past Saturday (`fri-sun`) |
| `monthly 1 02:00` | on the 1st of every month at 02:00 (a day from 1 to 28, so no month is skipped) |
| `trading nepse 15:05` | at 15:05 on the trading days of the [trading calendar](calendars.md) `nepse` of the timer's database: its weekdays era by era, without its holidays, with its extra trading days. Several times: `trading nepse 11:00,15:05` |

- `mon-fri 11:00` is the same as `weekdays 11:00`.
- A `trading` timer needs its calendar when it is saved (`there is no calendar 'nepse' in database ...` otherwise). It follows the calendar as it changes: a holiday added in the morning is skipped that afternoon. The day is the date of the run on the timer clock above.
- When the calendar is dropped, the timer is due every day and each run fails with `calendar 'nepse' does not exist`, so it never stops quietly. Make the calendar again, or give the timer another schedule.

<a id="runs"></a>

## How a run works

- **One at a time.** A timer never runs twice at once. When it is still running at its next due time, that due time runs as soon as the run ends: a **catch-up** run (`caught_up`). More due times during the same run get no run of their own.
- **No back-to-back runs.** A catch-up runs only when the run before it took less than one interval and ended before the next regular time - for example a run that started late because no worker was free. A timer that takes longer than its interval (an `every 10s` that takes 11 s) keeps its regular times (0 s, 20 s, 40 s ...) instead of running all the time, and each due time in between is skipped with the reason.
- **Nothing is dropped quietly.** A due time that gets no run is counted in `skipped`, with the time (`last_skip_ms`) and the reason (`last_skip_reason`), and written to the server log and the activity log. This covers a run that is still going, a computer that was busy or asleep, a clock set forward, and a server that was stopped: after a start, the due times missed while it was down are counted, not run.
- **One slow timer does not make others late.** Two workers are always there; when both are busy and another timer is due, a worker is added (up to three), so the other timer starts on time. Each running timer is one more writer at the database, so the limit is small. Change it with `timer_workers` in `kareladb.conf`, `kareladb serve --timer-workers N` or `KARELADB_TIMER_WORKERS` (1 to 64; the flag wins, then `kareladb.conf`, then the environment). `1` runs one timer at a time.
- **Clock changes.** The server sleeps on a clock that nobody sets, and looks at least once a second. When the computer's clock is set back, every next run is planned again; set forward, the due times jumped over are counted as skipped.
- **Each statement commits by itself.** To make all of it one step, put the SQL in a procedure: `CALL` runs a procedure as one transaction.
- **A transaction left open is rolled back** at the end of the run (for example `BEGIN; INSERT ...` without `COMMIT`).
- **Time limit:** a run is stopped after 10 minutes.
- **On time on a busy database.** A run's writes go into the database ahead of the requests that wait there (a checkpoint waiting for a bulk load, readers that keep coming). A run still waits for what is running right then: a long read, a schema change, or a checkpoint that is writing files. `last_late_ms` and `max_late_ms` show how late runs were.
- **Errors** are kept: the last error, how many runs failed, and the server log gets one line per failed run.

<a id="console"></a>

## In the console

Open **Timers** in the web console. The list shows each timer's schedule, the next and last run, the result and the last error. **New timer** saves one, **Run now** runs one straight away, and the switch turns one off or on.

The **Monitor** (the flyout on the right) has a **Timers** block with the timers of every database you may read, trouble first: when each last ran and whether it failed, how many seconds late it started, how many runs failed in the last 24 hours, and the last error. It comes from `timers` in `GET /api/stats`, which holds the same fields as below.

**Keep data for...** is for old data: pick the tables and how long to keep (6 months, 1 year, ...). It either sets a [TTL](alter-table.md#set-ttl) on each table, so KarelaDB drops the old partitions by itself, or saves one monthly timer that runs `ALTER TABLE ... DROP PARTITION OLDER THAN ...` for every table on the day and time you choose. Both drop whole partitions and never single rows.

<a id="get-api-timers"></a>

## GET /api/timers

Syntax:

```sql
GET /api/timers[?db=<name>]
```

The timers of one database (the default database without `db=`), and how their runs went. Needs read rights on the database.

| Field | Meaning |
|---|---|
| `name`, `database`, `schedule`, `sql`, `enabled` | the timer as saved |
| `created_by` | whose rights the runs use; empty = the token |
| `next_run_ms` | when it runs next (Unix milliseconds); 0 when it is off |
| `last_run_ms`, `last_ok`, `last_error` | the last run; `last_ok` is `null` before the first run. Kept across restarts |
| `last_took_ms`, `last_rows` | how long the last run took, and the rows it changed (or returned) |
| `last_due_ms` | when the last run was due by its schedule (Unix milliseconds) |
| `last_late_ms`, `max_late_ms` | how long after its due time the last run got its first write into the database (or started, if it only reads), and the worst of that since the server started |
| `runs`, `failures` | counts since the server started |
| `skipped`, `last_skip_ms`, `last_skip_reason` | due times that got no run of their own since the server started (with the ones missed while it was stopped), the last of them, and why |
| `caught_up` | runs that started right after the previous run ended, because their due time came while it ran |
| `failures_24h` | failed runs in about the last 24 hours (counted per clock hour); 0 after a restart |
| `running` | it is running now |

`now_ms` at the top is the server's clock, to show "in 3 minutes" correctly.

<a id="post-api-timers"></a>

## POST /api/timers

Syntax:

```sql
POST /api/timers[?db=<name>]
Content-Type: application/json

{"name": "...", "schedule": "...", "sql": "...", "enabled": true}
```

Creates a timer, or replaces the one with that name. Needs admin rights (a timer is saved code that later runs with the rights of whoever saved it, like a trigger), and is written to the audit log. Returns the timer. A bad name, schedule or SQL is a 400 that says what is wrong.

**HTTP: A timer that keeps the shop totals up to date every 5 minutes**

Setup:

```text
CREATE TABLE sales (time TIMESTAMP, shop STRING, amount DOUBLE) TIMESTAMP(time);
CREATE TABLE shop_totals (shop STRING PRIMARY KEY, amount DOUBLE, updated TIMESTAMP);
INSERT INTO sales VALUES (now(), 'north', 120.5), (now(), 'south', 80), (now(), 'north', 42);
CREATE PROCEDURE refresh_shop_totals() AS BEGIN
  FOR s IN (SELECT shop, sum(amount) AS amount FROM sales GROUP BY shop) DO
    INSERT OR REPLACE INTO shop_totals VALUES (s.shop, s.amount, now());
  END FOR;
END;
```

```http
POST /api/timers
Content-Type: application/json

{"name": "shop_totals", "schedule": "every 5m", "sql": "CALL refresh_shop_totals()"}
###
POST /api/timers/shop_totals/run
###
POST /exec?compat=0

SELECT shop, amount FROM shop_totals ORDER BY shop
```

Response:

`POST /api/timers`

HTTP 200 (application/json)

```text
{
  "name": "shop_totals",
  "database": "demo",
  "schedule": "every 5m",
  "sql": "CALL refresh_shop_totals()",
  "enabled": true,
  "created_ms": 1792817468497,
  "updated_ms": 1792817468497,
  "created_by": "",
  "next_run_ms": 1792817700000,
  "last_run_ms": 0,
  "last_due_ms": 0,
  "last_late_ms": 0,
  "max_late_ms": 0,
  "last_ok": null,
  "last_error": "",
  "last_took_ms": 0,
  "last_rows": 0,
  "runs": 0,
  "failures": 0,
  "failures_24h": 0,
  "skipped": 0,
  "last_skip_ms": 0,
  "last_skip_reason": "",
  "caught_up": 0,
  "running": false
}
```

`POST /api/timers/shop_totals/run`

HTTP 200 (application/json)

```text
{"name": "shop_totals", "finished": true, "ok": true, "error": "", "took_ms": 3, "rows": 2}
```

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "SELECT shop, amount FROM shop_totals ORDER BY shop",
  "results": [
    {
      "statement": "SELECT shop, amount FROM shop_totals ORDER BY shop",
      "columns": [
        {"name": "shop", "type": "STRING"},
        {"name": "amount", "type": "DOUBLE"}
      ],
      "dataset": [
        ["north", 162.5],
        ["south", 80]
      ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 17, "execute_us": 41}
    }
  ],
  "timings": {"parse_us": 17, "execute_us": 41}
}
```

**HTTP: A schedule that is not valid**

```http
POST /api/timers
Content-Type: application/json

{"name": "bad_one", "schedule": "every day", "sql": "SELECT 1"}
```

Response:

HTTP 400 (application/json)

```text
{
  "error": "bad \"every\" schedule 'every day'; use a schedule like \"every 10s\", \"every 5m\", \"every 2h\", \"hourly\", \"hourly :15\", \"daily 16:00\", \"daily 02:00,13:30\", \"weekdays 11:00\", \"sun-thu 11:00\", \"mon,wed,fri 09:30\", \"monthly 1 02:00\" or \"trading nepse 15:05\" (the trading days of CREATE CALENDAR nepse)"
}
```

<a id="run"></a>

## Run, turn off, delete

Syntax:

```sql
POST /api/timers/<name>/run[?db=<name>]
POST /api/timers/<name>/enable[?db=<name>]     {"enabled": false}
POST /api/timers/<name>/delete[?db=<name>]
```

| Route | Returns |
|---|---|
| `run` | `{"name", "finished", "ok", "error", "took_ms", "rows"}`. Waits up to one minute; after that `finished` is `false` and the run goes on (the result then shows in `GET /api/timers`). 409 when the timer is running already |
| `enable` | the timer. `{"enabled": true}` turns it on again |
| `delete` | `{"deleted": true}` |

An unknown timer is a 404. All three need admin rights and `POST`, and each is written to the audit log.

**HTTP: Turn a timer off, then delete it**

```http
POST /api/timers
Content-Type: application/json

{"name": "nightly", "schedule": "daily 02:00", "sql": "SELECT 1"}
###
POST /api/timers/nightly/enable
Content-Type: application/json

{"enabled": false}
###
POST /api/timers/nightly/delete
###
GET /api/timers
```

Response:

`POST /api/timers`

HTTP 200 (application/json)

```text
{
  "name": "nightly",
  "database": "demo",
  "schedule": "daily 02:00",
  "sql": "SELECT 1",
  "enabled": true,
  "created_ms": 1792817468428,
  "updated_ms": 1792817468428,
  "created_by": "",
  "next_run_ms": 1792872900000,
  "last_run_ms": 0,
  "last_due_ms": 0,
  "last_late_ms": 0,
  "max_late_ms": 0,
  "last_ok": null,
  "last_error": "",
  "last_took_ms": 0,
  "last_rows": 0,
  "runs": 0,
  "failures": 0,
  "failures_24h": 0,
  "skipped": 0,
  "last_skip_ms": 0,
  "last_skip_reason": "",
  "caught_up": 0,
  "running": false
}
```

`POST /api/timers/nightly/enable`

HTTP 200 (application/json)

```text
{
  "name": "nightly",
  "database": "demo",
  "schedule": "daily 02:00",
  "sql": "SELECT 1",
  "enabled": false,
  "created_ms": 1792817468428,
  "updated_ms": 1792817468462,
  "created_by": "",
  "next_run_ms": 0,
  "last_run_ms": 0,
  "last_due_ms": 0,
  "last_late_ms": 0,
  "max_late_ms": 0,
  "last_ok": null,
  "last_error": "",
  "last_took_ms": 0,
  "last_rows": 0,
  "runs": 0,
  "failures": 0,
  "failures_24h": 0,
  "skipped": 0,
  "last_skip_ms": 0,
  "last_skip_reason": "",
  "caught_up": 0,
  "running": false
}
```

`POST /api/timers/nightly/delete`

HTTP 200 (application/json)

```text
{"deleted": true}
```

`GET /api/timers`

HTTP 200 (application/json)

```text
{
  "now_ms": 1792817468483,
  "timers": []
}
```

<a id="notes"></a>

## Good to know

- `DROP DATABASE` deletes the database's timers too, so a new database with the same name starts with none. A timer left over from an older KarelaDB (or a database folder removed by hand) can still be deleted: `POST /api/timers/<name>/delete?db=<name>` works while the database is gone, for a server admin.
- A timer that runs often writes its last result back to `_timers` only when the result changes, or once a minute.
- For alerts, `/metrics` has `kdb_timer_failures_total` and `kdb_timer_late_seconds_max` for all timers, and per timer `kdb_timer_failures_24h{database,timer}` and `kdb_timer_last_late_seconds{database,timer}`.
- For backups at set times use the [backup schedule](backup-schedule.md), not a timer.
