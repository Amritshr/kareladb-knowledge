# Web console

> The browser page of kdb serve - run SQL, see results as a grid or a chart, switch databases, check health, make backups and open this help.

- Category: Web console
- Keywords: console, web console, browser, pages, tabs, Home menu, SQL page, Dashboards, Data page, View data, Monitor panel, Settings page, right side, flyout, panel, pin, Samples, Databases panel, Tools panel, Purge trash, Delete all data, Terminal, activity log, log, Timers tab, New timer, Run now, Keep data for, object tabs, web folder, web\_dir, KDB\_WEB\_DIR, console not installed, editor, Run, Run all, Ctrl+Enter, Ctrl+Shift+Enter, F1, history, grid, result grid, chart, candles, Export CSV, table list, health box, Check now, Backup now, database picker, New database, login form, Log out, token box, theme, dark, light, Help menu, Documentation, Examples, Keyboard shortcuts, About KDB, #sql, link with SQL, Try in console, dashboard
- See also: [Dashboard page (many charts on one page)](console-dashboards.md), [View data page (browse and edit rows)](console-data-page.md), [Keep data page (how long tables keep their rows)](console-keep-data.md), [Monitor panel (memory, processor, caches)](console-monitor.md), [Settings page (data folder, old log, capacity, program files and users)](console-settings.md), [Comments and suggestions](feedback.md), [HTTP API overview (get)](http-overview.md#get), [Run SQL over HTTP (/exec, /exp)](http-exec.md), [Logins, tokens and roles over HTTP](http-login.md), [Databases over HTTP (/api/databases)](http-databases.md), [Health, info, check and backup over HTTP](http-server-info.md), [kdb serve](cli-serve.md), [Databases and the data folder](databases.md)

The **web console** is a web page inside `kdb serve`. Open it in a browser to write SQL, run it, and look at the results. It needs no internet and no other software. Its files are plain files in the folder `web/` next to the kdb program, not inside the program ([where kdb finds them](install-packages.md#folders)).

Pick a page from the **Home** menu at the top left. The button shows where you are, for example `Home / Dashboard`.

| Menu item | What it is for |
|---|---|
| **Home** | write and run statements, see results as a grid or a chart (this page) |
| **Dashboard** | [many charts on one page](console-dashboards.md), saved in the database |
| **View data** | [browse tables and change rows](console-data-page.md) with forms instead of SQL |
| **Keep data** | [how long each table keeps its rows](console-keep-data.md): keep the last months or years, drop what is older |
| **Settings** | [where the data is kept, how much old log each database keeps, and who may log in](console-settings.md) |

The buttons down the right side open panels over the page: **Monitor**, **Health**, **Samples**, **Databases**, **Tools** and the **Terminal** ([right side](#right-side)).

**Comments and suggestions** in the [Help menu](#help-menu) opens one more page: a form to send a message to whoever runs the server ([feedback](feedback.md)).

The page you were on last opens again when you come back.

- Start the server, then open `http://127.0.0.1:9900` in Chrome, Edge or Firefox.
- Everything the console does goes through the [HTTP API](http-overview.md), so everything it can do, a program can do too.
- Tutorial: [chapter 6, web console](../tutorial/06-web-console.md).

**Command line: Start the server; the console address is on the second line**

```bash
kdb serve --backups backups
```

Output:

```text
KDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      ./kdb-data (from KDB_DATA_DIR; one folder per database)
  default   default (used when a request names no database)
  backups   backups/<database name> (from --backups)
  access    no token
  capacity  32 HTTP threads (default), 500 PostgreSQL connections (default), lock wait 5 s (default)
  lanes     reads using 100 ms of CPU (three times in a row) wait for one of 16 heavy slots, at most 16 HTTP in line (--lanes on)
  reads     32 reads run at once (the CPUs, at least 2; follows the CPU limit), the rest wait in line (--read-slots)
  commits   synced to disk before they are confirmed (--sync-commits always)
  time zone Asia/Katmandu (the computer's); also timers and backup schedules
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    26.95 GB for the whole process (85% of the machine's memory); table data 512.0 MB of it (--memory)
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log on (SHOW AUDIT)
  logs      slow queries >= 1000 ms to ./kdb-data/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  the default database is created when it is first used

Press Ctrl+C to stop.
```

<a id="open"></a>

## Open the console

Syntax:

```sql
kdb serve [<database folder>] [--data-dir <folder>] [--port 9900] [--bind 127.0.0.1] [--backups <folder>] [--token <secret>]
http://127.0.0.1:9900/
```

| Server started as | What the console shows |
|---|---|
| `kdb serve` or `kdb serve --data-dir <folder>` | every database of the data folder; **New database** is there |
| `kdb serve D:\kdb\market` (one folder) | just that database; no **New database** |
| with a data folder (or `--backups <folder>`) | **Backup now** and **Restore a backup** work |
| with `--token <secret>` | a box that asks for the token once |
| on a data folder with users | a **Log in** form |

- Keep the server window open while you use the console. Stop the server with **Ctrl+C**.
- From another computer, do not open the port to the network: use an SSH tunnel (`ssh -L 9900:127.0.0.1:9900 you@server`) and open `http://127.0.0.1:9900` on your own PC ([server security](server-security.md)).
- The page only loads files from the KDB server itself (its `Content-Security-Policy` says so), and it cannot be put inside another site's page.
- The console files are read from the `web` folder when the browser asks for them. When that folder is missing, the server still runs and the API works; the page at `/` says the console is not installed and lists the folders KDB looked in. The banner of `kdb serve` says so too.
- Copying a new console into the folder shows at the next page load, with no restart. The browser keeps its copy only until the file changes (the server answers `304 Not Modified` while it is the same).

**HTTP: The console page is there (HEAD: only the headers)**

```http
HEAD /
```

Response:

HTTP 200 (text/html)

<a id="screen"></a>

## The screen

```text
+-------------------------------------------------------------------------------------------+
| KDB [Home v]  Database [market v] New database   boss (admin) Log out  * Connected  Help   |
+-----------------------+----------------------------------------------------------+--------+
| OBJECTS       Refresh | [Run Ctrl+Enter] [Run all Ctrl+Shift+Enter] [History]  Rows | Monitor|
| [Tables 6][Views][Trig]|  1  SELECT time, open, high, low, close, volume          | Health |
| [Procs][Funcs][Timers] |  2  FROM ochl_day WHERE symbol = 'CITY';                | Samples|
|  > brokers     REL    |========================= (drag) ============================| Databa.|
|  > ochl_day    TS     | [1 SELECT time, ...] [2 Error]                           | ------ |
|  ...                  | [Grid][Chart]  message                      [Export CSV] | Tools  |
|                       |                                                          |Terminal|
|  > Indexes            |  #  time                      open   high ...            |        |
|                       |========================= (drag) ============================|        |
|                       | TERMINAL [All][Queries][Writes][Timers][Errors]  Pause Clear x|        |
|                       | 14:19:02.114 PG  10.0.0.5  market  3 ms  1 row  SELECT ...    |        |
+-----------------------+----------------------------------------------------------+--------+
| 19 rows | parse 0.05 ms  execute 0.34 ms  round trip 12 ms           Server 2026-09-11 14:19 |
+-------------------------------------------------------------------------------------------+
```

| Part | What it is |
|---|---|
| Top bar | the **Home** menu, the database picker, **New database**, folder and version, the logged-in user and **Log out**, the connection state, **Help**, the theme button |
| Left side | one tab each for [Tables, Views, Triggers, Procedures, Functions and Timers](#tables) |
| Editor | where you write SQL, with the **Run**, **Run all**, **History** buttons and the **Rows** limit |
| Results | one tab per statement; each result as a **Grid** or a **Chart**; **Export CSV** |
| Terminal | a live log of what the server does ([terminal](#terminal)); shown and hidden with the **Terminal** button |
| Right side | buttons that open the [Monitor, Health, Samples, Databases and Tools panels](#right-side) |
| Status bar | rows, times, and the server's clock |

The lines between the editor, the results and the terminal can be dragged; the console remembers the sizes.

<a id="editor"></a>

## Editor

Write SQL here. Keywords, text and numbers get colors, and lines have numbers.

| Button or key | What it does |
|---|---|
| **Run** or `Ctrl+Enter` | Runs the statement under the cursor. When text is selected, runs only the selection. |
| **Run all** or `Ctrl+Shift+Enter` | Runs everything in the editor |
| **Rows** | The most rows each statement gives back: 1,000, 10,000 (default), 100,000 or 1,000,000 |
| `Tab` | Puts in two spaces |

- Statements are split at `;`. "The statement under the cursor" is the text between the `;` before and after the cursor.
- The editor text is kept in your browser, so it is still there next time.
- With many statements, each result gets a **tab** (`1 SELECT ...`, `2 ...`).
- When a statement fails, a red **error bar** shows the message. Its position (`line 2, column 8`) is counted in **your editor**, the line number turns red, and clicking the position moves the cursor there. The statements before the error ran and are kept: the error tab says `Before it: 1 statement(s) ran and are kept`.
- Statements like `INSERT` show their message (`3 row(s) inserted`) and the rows affected.
- After `CREATE`, `DROP`, `ALTER` or `RENAME`, the table list reloads by itself. After `USE name;` the database picker switches to that database.
- Ready statements to start with, with **Insert** and **Run** buttons, are in the **Samples** panel on the right. It opens by itself on your first visit.

The console runs each statement with [POST /exec](http-exec.md#post-exec)`?compat=0&limit=<Rows>`.

<a id="history"></a>

## History

**History** lists the last 50 statements you ran, newest first, with the time. Click one to put it back at the end of the editor.

- The history is kept only in this browser.
- Passwords are never kept: `PASSWORD 'secret'` and the text in `password_hash('...')` and `password_verify('...')` are saved as `'***'`.
- `Escape` closes the list.

<a id="grid"></a>

## Results grid

The grid shows the rows of one result.

| Action | What it does |
|---|---|
| Click a column header | Sort: small to big, then big to small, then back to the first order (sorting uses the rows already loaded) |
| Drag the right edge of a header | Change the column width |
| Click a cell | Select it |
| `Ctrl+C`, or double-click a cell | Copy its value |
| Hover over long text | See all of it |

- The header shows the column's name and type (`DOUBLE`, `TIMESTAMP`, ...). Numbers are right-aligned.
- NULL shows as `null`. Times are UTC, as the API sends them.
- When the result was cut by the **Rows** limit, the bar says `Row limit reached: showing the first N rows.`
- The grid draws only the rows you can see, so it stays fast with a million rows.

<a id="chart"></a>

## Chart

Click **Chart** above a result. The console looks at the columns and picks the chart that fits best: **candles** for `time, open, high, low, close` (with volume bars when there is a `volume` column), a **line** for a time column with numbers, a **bar** chart for a text column with numbers, and so on. The button is off when no chart fits (a chart needs at least one number column).

The bar above the chart:

| Control | What it does |
|---|---|
| Chart type list | Choose another chart. Types that do not fit the columns are greyed out and say what they need. |
| **Columns** | Choose which column is the time or category, the values, the series (one line per value of a text column), and "One chart per" |
| Symbol list | When a text column has several values (many symbols), the chart shows one of them; pick it here |
| **Indicators** | (time charts) Add SMA, EMA, Bollinger bands, RSI, MACD or stochastic, and set their periods |
| **Log** | A logarithmic value scale (values must be above 0) |
| **No gaps** | (time charts) Leave out time without rows (nights, weekends, holidays), so every row has the same width |
| Legend | Click a name to hide or show that series |
| **Reset**, **PNG**, **CSV**, **Full screen** | Reset the zoom; save the chart as a picture; save the chart's rows as a CSV file (from the browser, no new query); fill the whole screen |
| **Add to dashboard** | Put this statement and this chart on a [dashboard](console-dashboards.md) as a new panel |

Chart types:

| Group | Types |
|---|---|
| Price | Candlestick, OHLC bars |
| Time | Line, Step line, Area, Stacked area |
| Compare | Bar (vertical), Bar (horizontal), Grouped bar, Stacked bar |
| Spread | Histogram, Box plot, Scatter, Bubble |
| Share | Pie, Donut, Treemap |
| Heatmap | Calendar heatmap, Matrix heatmap |
| Number | KPI number, Gauge |
| Table | A table with green/red change columns, color scales and a sparkline (a small price line) per row |

| Mouse or key (on the chart) | What it does |
|---|---|
| Mouse wheel, or `+` and `-` | Zoom in and out |
| Drag, or `Shift` + arrow keys | Move |
| Double-click, `Home` or `0` | Reset the zoom |
| Move the mouse, or arrow keys | A crosshair and a tooltip with the values of that row |
| Two fingers (touch screen) | Pinch to zoom |
| `F` | Full screen; `Esc` leaves it |

- Times on the chart are in **your computer's time zone** (for example Nepal time on a PC set to Nepal). The grid shows UTC.
- Big price series (100,000 bars) still zoom and move smoothly.
- The console remembers your chart settings for each statement, and whether you last used Grid or Chart.
- The chart follows the dark or light theme.

**Example: A good query for candles** (sample data: sample)

```sql
SELECT time, open, high, low, close, volume
FROM ochl_day
WHERE symbol = 'CITY'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| 2025-12-28T00:00:00.000Z | 540.3 | 542.5 | 539.2 | 542.2 | 85290 |
| 2025-12-29T00:00:00.000Z | 540.6 | 542.1 | 538.8 | 539.7 | 52010 |
| 2025-12-30T00:00:00.000Z | 538.5 | 540.5 | 536.4 | 539.3 | 95460 |
| 2025-12-31T00:00:00.000Z | 540.4 | 546.2 | 538.9 | 542.4 | 22330 |
| 2026-08-23T00:00:00.000Z | 505 | 508.4 | 502 | 507.9 | 125050 |

(first 5 of 19 rows)

<a id="dashboards"></a>

## Charts and dashboards

A chart you like can go on a **dashboard**: a page of several charts, each from its own query, that refresh by themselves. Click **Add to dashboard** on the chart bar, pick a dashboard (or **A new dashboard**) and give the panel a title. The dashboard opens with the new panel; click **Save** there to keep it. The dashboard page is explained in [dashboards](console-dashboards.md).

**Example: Rows for a bar chart: shares traded per symbol** (sample data: sample)

```sql
SELECT symbol, sum(quantity) AS shares
FROM trade_log
GROUP BY symbol
ORDER BY shares DESC;
```

Result:

| symbol (SYMBOL) | shares (LONG) |
|---|---|
| COAST | 3070 |
| TELCO | 2770 |
| CITY | 2420 |
| VOLT | 400 |

(4 rows)

<a id="export-csv"></a>

## Export CSV

**Export CSV** downloads all rows of the shown result as a CSV file.

- It runs the statement **again** on the server with [GET /exp](http-exec.md#get-exp) (up to 1,000,000 rows, not only the rows in the grid). So it is offered only for `SELECT`, `SHOW` and `EXPLAIN`.
- The file name comes from the table after `FROM`, for example `ochl_day.csv` (else `kdb-export.csv`).
- Times are UTC. NULL is an empty field.

<a id="tables"></a>

## Object list

The left side lists the objects of the chosen database, one tab for each kind: **Tables**, **Views**, **Triggers**, **Procedures**, **Functions** and **Timers**. Each tab shows how many there are. The console remembers the tab you picked.

- **Indexes** are in the Tables tab, under the tables. Click **Indexes** to close or open that group.
- Click the small arrow of a view, trigger, procedure or function to see its statement. **Open in editor** puts the statement into the editor.
- A procedure or function also has **Run on a timer...**: it opens the [timer form](#timers) with `CALL name(...)` or `SELECT name(...)` filled in.

**Folders.** A database with many objects can be tidied into folders: **+ Folder** at the top of a tab makes one, and you drag a table, view, trigger, procedure or function onto it. A folder exists in every tab, so `floorsheet` can hold the floor-sheet tables in the Tables tab and the floor-sheet procedures in the Procedures tab. Hover a folder's heading to rename (✎) or remove (×) it; removing a folder only puts its objects back in the plain list. Folders change nothing but this list: no name, statement or query is affected. They are saved in the table `_console_groups` of the database, so every browser sees the same folders; the first folder creates that table, which needs the admin role, and dragging needs the write role.

**Tables**

| Mark | Meaning |
|---|---|
| `TS` badge | a time-series table (with its partition: `DAY`, `MONTH`, `YEAR`) |
| `REL` badge | a relational table |
| `TS` on a column | the table's time column |
| `PK` | primary key |
| `FK` | `REFERENCES` another table (hover to see which) |
| `FX` | a computed column |

| Action | What it does |
|---|---|
| Click the small arrow | Show the columns and their types |
| Click a table or column name | Put the name into the editor at the cursor |
| Double-click a table name | Run `SHOW COLUMNS FROM <table>` |
| **Refresh** | Reload the object lists and the health panel |

The list comes from [GET /api/info](http-server-info.md#get-api-info). It also reloads every 30 seconds while the page is visible.

<a id="timers"></a>

## Timers

A **timer** runs SQL by itself on a schedule, for example `CALL refresh_prices();` every 5 minutes, so a table stays up to date without anybody running anything. The server runs it, so it goes on when no browser is open. Full details: [timers](timers.md).

| In the Timers tab | What it does |
|---|---|
| **New timer** | A form: name, schedule, the SQL, and whether it is turned on. **Run** picks a procedure or function of this database. |
| **Keep data for...** | Pick time-series tables and how long they keep their rows. It sets a TTL, or makes a monthly timer that drops old partitions. The [Keep data page](console-keep-data.md) does the same for one table at a time. |
| **Reload** | Reads the list again (it also refreshes by itself while the tab is open) |
| The dot before a name | green: the last run worked; red: it failed; blue: running now; dashed: turned off |
| Click the arrow | Next run, last run, how long it took, rows, the error, and how many runs |
| **Run now** | Runs it once now, whatever the schedule says |
| **Turn off** / **Turn on** | Stops or starts running it on the schedule |
| **Edit**, **Delete** | Change the schedule or the SQL; delete the timer (the procedure stays) |

Schedules: `every 30s`, `every 5m`, `every 2h`, `hourly`, `hourly :15`, `daily 16:00`, `daily 02:00,13:30`, `weekdays 11:00`, `monthly 1 02:00`. The form offers the common ones as quick picks. Times are the server computer's local time.

- A run that is still going when the next one is due is skipped, never started twice.
- A timer belongs to the database chosen at the top, and runs with the rights of the user who saved it.
- Any user who may read the database sees its timers. Saving, changing, deleting and **Run now** need the `admin` role on that database, and each of them is written to the [audit log](audit-log.md).

<a id="right-side"></a>

## Right side: Monitor, Health, Samples, Databases

The buttons down the right side open a **panel** over the page. The same button closes it again; so do the **x** and `Esc`.

| Button | The panel |
|---|---|
| **Monitor** | memory, processor, caches and the statements running now ([Monitor](console-monitor.md)) |
| **Health** | damaged files, backups, **Check now** and **Backup now** ([health](#health-box)); the button gets a red dot while a file is damaged |
| **Samples** | ready statements with **Insert** and **Run** |
| **Databases** | every database with its tables, size, folder and old log (`wal_archive`: its limit, whether it is its own or the server default, and the size on disk); click one to use it; **New database**; **Old log** sets a database's own limit, **Off**, or the server default again ([SET WAL_ARCHIVE](databases.md#wal-archive)); **Delete** |
| **Tools** | **Purge trash** frees disk space in the whole data folder ([PURGE TRASH ALL](databases.md#purge-trash)); **Delete all data** empties every table of the chosen database after you type its name ([TRUNCATE ALL TABLES](databases.md#truncate-all-tables)) |
| **Terminal** | not a panel: shows or hides the [terminal](#terminal) at the bottom of Home |

- A panel floats over the page and closes when you click somewhere else. The **pin** button keeps it open beside the page instead.
- Drag its left edge to make it wider. Double-click the edge for the normal width.
- The console remembers the open panel, the pin and the widths.

<a id="terminal"></a>

## Terminal

The **terminal** at the bottom of Home is a live log of what the server does: every statement, write, timer run, login and backup, as it happens. It shows where the data comes from, for example a program on the PostgreSQL port or a timer.

```text
14:19:02.114  PG     10.0.0.5 app    market   3 ms       1 row  SELECT price FROM ochl_day WHERE ...
14:19:02.530  HTTP   10.0.0.9        market  12 ms  12,000 rows  12,000 rows into trade_log (line protocol)
14:20:00.004  TIMER  refresh_prices  market  41 ms    350 rows  CALL refresh_prices();
```

| Column or control | What it is |
|---|---|
| Time | when it finished, with milliseconds, in your computer's time zone |
| Source | `HTTP` (statements, `/write` and CSV imports), `PG` (PostgreSQL port), `TIMER`, `BACKUP` (a scheduled backup), `DEFERRED` (a job of a [deferred trigger](triggers.md)), or the kind, such as `LOGIN` |
| From | the address of the program, and the user |
| Database, time, rows | where it ran, how long it took, how many rows |
| **All**, **Queries**, **Writes**, **Timers**, **Errors** | show only that kind of line |
| **This database** | only lines of the database chosen at the top |
| Filter text | only lines with that text |
| **Pause**, **Clear**, **x** | stop adding lines, empty the list, hide the terminal |

- The terminal is hidden when the page opens. It shows up by itself when you **Run** a statement, and the **Terminal** button shows or hides it any time.
- Click a line to see all of its text; double-click a statement to put it into the editor. Failed lines are red.
- While the terminal is hidden, the **Terminal** button counts the new lines.
- The console's own background reads (the lists on the left, the monitor) are not logged, so they do not fill it.
- Users who are not admins see only their own lines.

<a id="health-box"></a>

## Health panel

| Line | Meaning |
|---|---|
| `OK - no damaged files` (green) or `DAMAGED (n)` (red) | files KDB knows are damaged, with their names |
| **Last backup** | how long ago (`just now`, `3 h ago`), `never`, or `no backup folder`; `(copy failed)` when the [copy command](backup-schedule.md#backup-command) failed. Hover it for the folder, the schedule and the last copy. |
| **Data** | size and number of the data files |
| **Log LSN** | the number of the last change in the log; it grows with every change |
| **Opened** | when the server opened the database |
| **Recovery at open** | what KDB did when it opened the database (it opens by itself when something was wrong) |
| **Check now** | reads every block of every file and the log ([POST /api/check](http-server-info.md#post-api-check)). Example message: `OK: 11 files (76.1 KB) and 1 log segments read in 1.50 ms. No damage.` |
| **Backup now** | makes a verified backup ([POST /api/backup](http-server-info.md#post-api-backup)). Example message: `Backup 20260911-083519-806 created and verified: 9 files, 222.3 KB.` The button is off when backups are off (`--backups off`). |
| **Restore a backup** | opens a small form: the backups of this database, how far back a restore **up to** a time can go ([the window](backup-and-safety.md#pitr-window)), a time (empty = the backup as it was) and a **new** name. **Restore** makes the new database while this one keeps running ([POST /api/restore](http-server-info.md#api-restore)). Then **Swap ... in** gives this database the restored data and the new one the old data ([swap](http-server-info.md#api-swap)); it asks first. |

If **Check now** finds damage: stop the server and run `kdb repair` ([backup and safety](backup-and-safety.md)).

<a id="databases"></a>

## Database picker and New database

- The **Database** list at the top shows the databases of the server. Everything on the page uses the chosen one: the editor, the object lists, the health panel, timers and backups. The console adds `db=<name>` to each request.
- The **Databases** panel on the right shows the same databases with their tables, size and folder. Click one to use it.
- The browser remembers the choice. When that database is gone, the console uses the server's default database.
- **New database** asks for a name (letters, digits, `_` and `-`, at most 64; `_trash` and Windows device names like `con` are not allowed). The new, empty database is chosen right away. It uses [POST /api/databases](http-databases.md#post-api-databases).
- `USE demo;`, `CREATE DATABASE x;` and `DROP DATABASE x;` in the editor also update the list. Dropping the chosen database moves the console back to the default database. A dropped database's folder moves to `_trash`.
- With users, the list shows only the databases you may read, and **New database** only for a user with ROLE `admin`.

<a id="login"></a>

## Login form and token box

**Users.** When the data folder has users, the console shows **Log in**. Type the user name and password.

- After the login, the top bar shows the user and role, for example `boss (admin)`, and a **Log out** button.
- The login is kept in a cookie that scripts cannot read (`HttpOnly`) and that works only on this site (`SameSite=Strict`). It ends after 12 hours, at **Log out**, when the server restarts, or when the password changes.
- A wrong password keeps the form open with `Wrong user name or password.` After 5 wrong tries, wait a moment.
- Each statement runs with your role. A refused one shows the error, for example `INSERT needs role write on database 'shop'; user 'report' has read`.

**Token.** On a server started with `--token`, the console shows **Access token required**. Type the token once.

- The server keeps it in a cookie that scripts cannot read (`HttpOnly`, `SameSite=Strict`). CSV downloads work with it too.
- **Remember on this computer for 30 days** is on at first. Clear it and the browser forgets the token when it closes.
- **Log out** at the top makes this browser forget the token.
- A token an older console kept in the browser's storage is moved into the cookie once, then deleted there.
- The console sends the `X-KDB-CSRF` header with every change by itself ([CSRF](http-login.md#csrf)).

The connection state at the top says `Connected`, `Offline` (the server does not answer), `Token required` or `Login required`. More: [logins and tokens](http-login.md).

<a id="theme"></a>

## Theme

The button at the top right switches between the **dark** theme (the default) and the **light** theme. The browser remembers the choice. The help panel and charts follow the theme.

<a id="help-menu"></a>

## Help menu

The **Help** button in the top bar opens a menu:

| Item | What it does |
|---|---|
| **Documentation** | Opens this help in a panel on the right side of the console. Drag its left edge to make it wider; **Open in new tab** shows it as a full page; **Close** or `Esc` closes it. |
| **Help for word under cursor** (`F1`) | Opens the help for the keyword or function at the cursor in the editor: on `round(` it opens the function `round`, on `ORDER` in `ORDER BY` it opens `ORDER BY`. Inside a text `'...'` or a `--` comment, it opens the help's start page. |
| **Examples...** | A list of the ready examples of this help, with a search box and a preview. **Insert into editor** puts the chosen example (with the tables it needs) at the end of the editor; then press `Ctrl+Enter`. **Open in help** shows it in the help. |
| **Keyboard shortcuts** | The table below |
| **Comments and suggestions** | A form to send a comment, a problem or an idea to whoever runs this server. An admin also sees the messages sent so far and marks them read or done ([feedback](feedback.md)). |
| **About KDB** | The version, the database and its folder, the data folder, number of tables, the backup folder, how you are logged in, the help's version, and the server address |

- In the help panel, every SQL example has **Insert into editor**, which puts that SQL (with its setup) into the console editor.
- The help comes from [GET /help/](http-overview.md#get-help): a folder of pages next to the kdb program, not inside it. When no help folder is installed, the panel says so and how to build it.
- The menu works with the keyboard: `Arrow down` opens it, arrows move, `Enter` chooses, `Esc` closes.

<a id="shortcuts"></a>

## Keyboard shortcuts

| Keys | What it does |
|---|---|
| `Ctrl+Enter` | Run the statement under the cursor (or the selected text) |
| `Ctrl+Shift+Enter` | Run every statement in the editor |
| `Tab` | Put two spaces in the editor |
| `F1` | Help for the keyword or function under the cursor |
| `Ctrl+C` (in the grid) | Copy the selected cell |
| Double-click a cell | Copy that cell |
| `Esc` | Close a menu, the History list, a dialog or the help panel |
| `/` (in the help) | Jump to the help's search box |

On a Mac, use `Cmd` instead of `Ctrl`.

<a id="sql-link"></a>

## Open the console with SQL in the editor

Syntax:

```sql
http://127.0.0.1:9900/#sql=<URL-encoded SQL>
```

A link of this form opens the console and puts the SQL at the end of the editor, selected, ready for `Ctrl+Enter`. It does **not** run the SQL by itself.

- **URL-encoded** means special characters are written as `%` codes: a space is `%20`, a `'` is `%27`, a `,` is `%2C`. JavaScript's `encodeURIComponent`, Python's `urllib.parse.quote` and PowerShell's `[uri]::EscapeDataString` do it.
- The `#sql=...` part is removed from the address after it is read, so reloading the page does not add the SQL again.
- The **Try in console** button of examples in this help (when the help is opened as a page, not inside the console) uses such a link.
- The part after `#` never goes to the server, so the SQL does not appear in server logs.

```text
http://127.0.0.1:9900/#sql=SELECT%20symbol%2C%20close%20FROM%20ochl_day%20WHERE%20symbol%20%3D%20%27CITY%27%20LIMIT%205
```

```powershell
$sql = "SELECT symbol, close FROM ochl_day WHERE symbol = 'CITY' LIMIT 5"
Start-Process ("http://127.0.0.1:9900/#sql=" + [uri]::EscapeDataString($sql))
```

```python
import urllib.parse, webbrowser
sql = "SELECT symbol, close FROM ochl_day WHERE symbol = 'CITY' LIMIT 5"
webbrowser.open("http://127.0.0.1:9900/#sql=" + urllib.parse.quote(sql, safe=""))
```
