# 6. Web console

- Category: Tutorial

## What you will learn

- How to start the server and open the console in a browser.
- Every part of the console screen: the Home menu, database list, objects, editor, results grid, chart, terminal and the panels on the right (Monitor, Health, Samples, Databases, Tools).
- How to use an access token, and how to keep the server safe.

## Start the server

```powershell
kdb serve market --backups backups
```

```text
KDB 0.2.0-dev
  console   http://127.0.0.1:9900
  postgres  127.0.0.1:8832 (PostgreSQL protocol, no TLS; no password on this computer only)
  data      market
  backups   backups
  access    no token
  commits   synced to disk before they are confirmed (--sync-commits always)
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log off
  recovery  manifest copy: b, last shutdown: clean

Press Ctrl+C to stop.
```

Then open <http://127.0.0.1:9900> in Chrome, Edge or Firefox. While the server runs, it prints one line per request, for example `2026-09-11 14:07:33  GET /health 200 0 ms`.

`kdb serve market` serves **one** database folder (here the folder `market`). To serve **every database in the data folder** (chapter 1), start it without a folder:

```powershell
kdb serve --backups backups
```

```text
KDB 0.2.0-dev
  console   http://127.0.0.1:9900
  postgres  127.0.0.1:8832 (PostgreSQL protocol, no TLS; no password on this computer only)
  data      D:/AMP/TechnivsProject/01_NChartPro/KDB/build/bin/data (from program folder; one folder per database)
  default   default (used when a request names no database)
  backups   backups/<database name>
  access    no token
  commits   synced to disk before they are confirmed (--sync-commits always)
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log on (SHOW AUDIT)
  recovery  the default database is created when it is first used

Press Ctrl+C to stop.
```

Then the console can switch between databases and create new ones (see [Databases](#databases) below). Each database backs up into its own sub-folder of the backup folder, so backups never mix.

| Option | Meaning | Default |
|---|---|---|
| `--data-dir FOLDER` | The data folder to serve (without a database folder argument) | `KDB_DATA_DIR`, else `data` next to `kdb.exe` |
| `--db NAME` | The database used when a request names none. In the data folder it is created when first used. | `default` (or the name you gave) |
| `--port N` | TCP port | `9900` |
| `--bind ADDRESS` | Which network address to listen on. `127.0.0.1` = this computer only. `0.0.0.0` = all networks. | `127.0.0.1` |
| `--backups FOLDER` | Backup folder. Needed for the **Backup now** button and `BACKUP DATABASE`. Also used by repairs. | not set |
| `--token SECRET` | Every request needs this token (see below). | no token |
| `--memory MB` | Memory for table data kept loaded. Data over this is read from disk again when needed, which is slower. On a PC or VPS with years of market history (about 1.5 GB on disk), `--memory 4096` keeps queries fast. | `512` |

- **Stop the server with Ctrl+C.** KDB then closes the database cleanly (`database closed cleanly`).
- If the window is closed or the process is killed, nothing committed is lost. The next start replays the log and shows `last shutdown: not clean (crash or kill)`.
- Only one server (or other `kdb` command) can use a database folder at a time.

To check from PowerShell that the page is there:

```powershell
$page = Invoke-WebRequest http://127.0.0.1:9900/ -UseBasicParsing
"HTTP $($page.StatusCode), $($page.Headers['Content-Type'])"
if ($page.Content -match '<title>(.*?)</title>') { "title: $($Matches[1])" }
```

```text
HTTP 200, text/html; charset=utf-8
title: KDB console
```

The console needs no internet. Its files are plain files in the folder `web` next to `kdb` (in a source checkout: `web/console`). Chapter 1 lists where KDB looks. A new console needs only the files copied, not a new program. When KDB finds no console files, the page says so and lists the folders it looked in.

## The screen

```text
+-------------------------------------------------------------------------------------------+
| KDB [Home v]  Database [market v] New database   market v0.2.0-dev  * Connected  Help      |  <- top bar
+-----------------------+----------------------------------------------------------+--------+
| OBJECTS       Refresh | [Run Ctrl+Enter] [Run all Ctrl+Shift+Enter] [History]  Rows | Monitor|
| [Tables 6][Views][Trig]|  1  SELECT time, open, high, low, close, volume          | Health |  <- right side
| [Procs][Funcs][Timers] |  2  FROM ochl_day WHERE symbol = 'CITY';                | Samples|
|  > brokers     REL    | Error  line 2, column 8  unknown column ...               | Databa.|
|  > ochl_day    TS     |========================= (drag) ============================| Tools  |
|  ...                  | [1 SELECT time, ...] [2 Error]                           | ------ |
|  > Indexes            | [Grid][Chart]  message                      [Export CSV] |Terminal|
|                       |  #  time                      open   high ...            |        |
|                       |========================= (drag) ============================|        |
|                       | TERMINAL [All][Queries][Writes][Timers][Errors]  Pause Clear x|        |
|                       | 14:19:02.114 HTTP 127.0.0.1  market  3 ms  2 rows  SELECT ... |        |
+-----------------------+----------------------------------------------------------+--------+
| 19 rows | parse 0.05 ms  execute 0.34 ms  round trip 12 ms           Server 2026-09-11 14:19 |  <- status bar
+-------------------------------------------------------------------------------------------+
```

The lines between the editor, the results and the terminal can be dragged. The console remembers the sizes.

### Top bar

| Part | What it shows |
|---|---|
| **Home** menu | The pages: **Home** (this page: editor, grid, chart), **Dashboard** (many charts on one page, chapter 20), **View data** (browse tables and change rows with forms), **Keep data** (how long each table keeps its rows), **Settings** (where the data is kept, and who may log in). The button shows where you are, for example `Home / Dashboard`. |
| **Database** list | The database everything on the page uses: editor, object lists, health, timers, backups. See [Databases](#databases). |
| **New database** | Creates a database in the server's data folder. Only shown when the server serves a data folder. |
| Folder name, version | The folder of the chosen database, and the KDB version |
| User and **Log out** | Only when the data folder has users (see [Login](#login-users)) |
| Connection dot | `Connected`, `Offline` (the server does not answer), `Token required` or `Login required` |
| **Help** | The help pages, the tutorial, keyboard shortcuts. Press **F1** on a word in the editor to open its help page. |
| Light / Dark button | Changes the colors. The browser remembers your choice. |

### Right side: Monitor, Health, Samples, Databases, Tools, Terminal

The buttons down the right side open a **panel** over the page. The same button closes it again; so do the **x** and `Esc`. The **pin** keeps a panel open beside the page. Drag its left edge to make it wider.

| Button | The panel |
|---|---|
| **Monitor** | Memory, processor, caches and the statements running now. **Cancel** stops a statement that was sent with a request id (chapter 8). |
| **Health** | Damaged files, backups, **Check now** and **Backup now** ([Health](#health-panel)). The button gets a red dot while a file is damaged. |
| **Samples** | Ready statements with **Insert** and **Run**. It opens by itself on your first visit. |
| **Databases** | Every database with its tables, size and folder. Click one to use it. **New database** and **Delete**. |
| **Tools** | **Purge trash** frees disk space in the whole data folder. **Delete all data** empties every table of the chosen database, after you type its name. |
| **Terminal** | Not a panel: shows or hides the terminal at the bottom of Home. |

### Terminal

The **terminal** under the results is a live log of what the server does: every statement, write, timer run, login and backup, from the console, from programs over HTTP, and from the PostgreSQL port.

- It is hidden when the page opens. It shows up by itself when you **Run** a statement. The **Terminal** button shows or hides it at any time, and counts the new lines while it is hidden.
- **All**, **Queries**, **Writes**, **Timers**, **Errors** show only that kind of line. A filter box keeps only lines with your text.
- Click a line to see all of its text. Double-click a statement to put it into the editor. Failed lines are red.
- Users who are not admins see only their own lines. The server keeps the last 5,000 events in memory (`--activity-log-size`).

### Databases

- The **Database** list at the top shows every database the server has. Pick one: the object lists and the health panel reload, and every statement you run goes to that database (the console adds `db=<name>` to each request, chapter 8).
- The browser **remembers** your choice. If that database is gone, the console uses the server's default database.
- **New database** asks for a name (letters, digits, `_` and `-`, at most 64). Wrong names are refused at once. The new database is chosen right away and is empty.
- **Delete** next to a database in the **Databases** panel (right-hand rail) drops it. You type its name to confirm. Only a server admin sees the button. Like `DROP DATABASE`, it moves the folder to `_trash` in the data folder, and it is refused while a request or shell still uses the database.
- `USE demo;` in the editor also switches the list to `demo`.
- `CREATE DATABASE x;` and `DROP DATABASE x;` in the editor work too; the list reloads after them. If you drop the chosen database, the console goes back to the default database. `DROP DATABASE` never deletes data: the folder moves to `_trash` in the data folder.
- With `kdb serve market` (one folder), the list has just that database and there is no **New database** button.

The list comes from `GET /api/databases`:

```powershell
$d = Invoke-RestMethod http://127.0.0.1:9900/api/databases
"default: $($d.default)   can_create: $($d.can_create)"
$d.databases | Select-Object name, tables, default | Format-Table -AutoSize
```

```text
default: market  can_create: False

name  tables default
----  ------ -------
market     6    True
```

### Objects (left side)

The left side has one tab for each kind of object: **Tables**, **Views**, **Triggers**, **Procedures**, **Functions** and **Timers**. Each tab shows how many there are. Indexes are in the Tables tab, under the tables.

- Click the small arrow of a view, trigger, procedure or function to see its statement. **Open in editor** puts it into the editor.
- **Timers** run SQL by themselves on a schedule, for example `CALL refresh_prices();` every 5 minutes. **New timer** opens a form. The server runs them, also when no browser is open.
- **+ Folder** makes a folder, and you drag objects onto it. Folders only tidy this list. They are kept in the table `_console_groups`, so every browser sees them.

In the Tables tab:

- Every table with a badge: `TS` = time-series, `REL` = relational, and the partition (`DAY`, `MONTH`, `YEAR`).
- Click the small arrow to see the columns with their types. Marks: `TS` = time column, `PK` = primary key, `FK` = REFERENCES, `FX` = computed column.
- **Click** a table or column name: its name is put into the editor at the cursor.
- **Double-click** a table name: runs `SHOW COLUMNS FROM <table>`.
- **Refresh** reloads the lists and the health panel. They also reload by themselves after `CREATE`, `DROP`, `ALTER` or `RENAME`, and every 30 seconds.

### Editor

- Type SQL. Keywords, text and numbers get colors. Line numbers are on the left.
- The text stays in your browser. It is still there when you open the console again.
- `Tab` puts in two spaces.
- **Rows** (top right) is the most rows a query returns: 1,000 to 1,000,000. When a result is cut, the console says `Row limit reached`.

### Keyboard shortcuts

| Keys | What it does |
|---|---|
| `Ctrl+Enter` | Run the statement under the cursor. If you selected text, run only the selection. |
| `Ctrl+Shift+Enter` | Run everything in the editor |
| `Tab` | Insert two spaces |
| `Escape` | Close the History list, or the open panel |
| `F1` | Open the help page of the word under the cursor |
| `Ctrl+C` (in the grid) | Copy the selected cell |
| Mac | Use `Cmd` instead of `Ctrl` |

### Running statements

- Statements are split at `;`. "The statement under the cursor" is the one between the `;` before and after the cursor.
- With many statements, each result gets a **tab** above the results (`1 SELECT ...`, `2 ...`).
- If a statement fails, a red **error bar** appears under the editor. The position (`line 2, column 8`) is counted in **your editor**, and the line is marked red. Click the position to jump there.
- The statements before the error ran and are saved. The error tab says so: `Before it: 1 statement(s) ran and are kept`.
- Statements like INSERT show a message (`3 row(s) inserted`) and the rows affected.

### History

**History** lists the last 50 statements you ran, newest first, with the time. Click one to put it back into the editor. The history is kept in this browser only.

### Grid

The grid shows the rows of a result.

- The column header shows the name and the type (`DOUBLE`, `TIMESTAMP`, ...). Numbers are right-aligned.
- **Click a header** to sort: first click small-to-big, second click big-to-small, third click back to the original order. Sorting happens in the browser, on the rows already loaded.
- **Drag the right edge** of a header to change the column width.
- **Click a cell** to select it. `Ctrl+C` or **double-click** copies its value.
- Empty values show as `null`. Long text shows fully when you hover over it.
- The grid is fast also with many rows: it only draws the rows you can see.

### Chart

Click **Chart** above the result. The chart button works when the result has a number column. KDB picks the chart from the columns, for example:

- a `TIMESTAMP` or `DATE` column and columns named `open`, `high`, `low`, `close`: **candles**, with bars for a `volume` column;
- a time column and other numbers: **lines**;
- a text column and a number: **bars**; one row of numbers: a big **KPI number**.

Change the chart with the chart type list above the chart: line, area, bars, pie, donut, treemap, heatmaps, histogram, box plot, scatter, gauge, table and more. **Columns** chooses the columns, **Indicators** adds SMA, EMA, Bollinger, RSI, MACD or stochastic. **Chapter 20 explains every chart type and the dashboards.**

If the result has a SYMBOL or STRING column with more than one value (for example many symbols), a **symbol list** appears. The chart shows one symbol at a time (lines with up to 8 symbols get one line per symbol).

| Action | What it does |
|---|---|
| Mouse wheel | Zoom in and out around the mouse |
| Drag (hold the left button) | Move left and right |
| Double-click | Reset the view (candles: the last 200 bars) |
| Move the mouse | Crosshair. The top line shows date, O, H, L, C, change % and volume of that candle. The price and the date are marked on the axes. |
| Click a name in the legend | Hide or show that line |
| Arrow keys, `+`, `-`, `Home` (click the chart or press Tab first) | Move from candle to candle, zoom, reset |

- Candles have no gaps for days without trading (Friday, Saturday, holidays): each bar is one row. Untick **No gaps** to see real time.
- Times on the chart axis are shown in **your computer's time zone** (Nepal time on a PC set to Nepal). The grid shows UTC.
- Good queries for the chart: `SELECT time, open, high, low, close, volume FROM ochl_day WHERE symbol = 'CITY'`, or the candle queries of chapter 5.

### Export CSV

**Export CSV** downloads all rows of the result as a CSV file. It runs the statement **again** on the server (up to 1,000,000 rows), so it is only offered for `SELECT`, `SHOW` and `EXPLAIN`. The file name comes from the table name, for example `ochl_day.csv`. Times are UTC in ISO format.

### Health panel

| Line | Meaning |
|---|---|
| `OK - no damaged files` (green) / `DAMAGED (n)` (red) | Damaged files that KDB knows about, with their names |
| Last backup | How long ago (`just now`, `3 h ago`), `never`, or `no backup folder` |
| Data | Size of the data files and how many |
| Log LSN | Number of the last change in the log. It grows with every change. |
| Opened | When the server opened the database |
| Recovery at open | What KDB did when it opened the database. It opens by itself if there was a problem. |
| **Check now** | Reads every block of every file and the log. Example message: `OK: 11 files (76.1 KB) and 1 log segments read in 1.50 ms. No damage.` |
| **Backup now** | Makes a verified backup into the `--backups` folder. Example message: `Backup 20260911-083519-806 created and verified: 9 files, 222.3 KB.` The button is off when the server has no backup folder. |

If **Check now** finds damage, stop the server and run `kdb repair` (chapter 9).

### Status bar (bottom)

- Left: the number of rows, and the times: `parse` and `execute` on the server, `round trip` including the network.
- Right: the server's clock, in your local time zone.

## Login (users)

When the data folder has users (chapter 16), the console shows **Log in** instead of the token box. Type the user name and password. After the login the top bar shows the user and role, for example `boss (admin)`, and a **Log out** button. The top bar dot says `Login required` while nobody is logged in.

- The login is kept in a cookie that scripts cannot read (`HttpOnly`) and that works only on this site (`SameSite=Strict`). It ends after 12 hours, at **Log out**, when the server restarts, or when the password changes.
- A wrong password keeps the form open with `Wrong user name or password.` After 5 wrong tries, wait a moment before the next one.
- Each statement runs with the user's role. A refused statement shows the error, for example `INSERT needs role write on database 'shop'; user 'report' has read`.
- The history of the editor never keeps passwords: `PASSWORD 'secret'` and the text in `password_hash('...')` are saved as `'***'`.

## Access token

Start the server with a token:

```powershell
kdb serve market --token change-me-please
```

- The console asks for the token once (**Access token required**). The browser keeps it (local storage and a cookie for this site only).
- Programs send it in a header: `Authorization: Bearer change-me-please` (chapter 8).
- A wrong or missing token gets HTTP 401.
- `/health` works without a token. It only says `auth_required: true`.

Choose a long random token, for example:

```powershell
[Convert]::ToBase64String((1..24 | ForEach-Object { Get-Random -Maximum 256 }) -as [byte[]])
```

## Security notes

| Situation | What to do |
|---|---|
| Only you, on this PC | Default (`--bind 127.0.0.1`, no token) is fine. |
| Other PCs in the office must connect | `--bind 0.0.0.0 --token <long secret>`. Open the port only in the Windows firewall for your office network. |
| Access over the internet | Do **not** open port 9900 to the internet. Put a reverse proxy with HTTPS (for example nginx or Caddy) in front, keep `--bind 127.0.0.1`, and use `--token`. |

What KDB does to protect you:

- Without a token, KDB listens on `127.0.0.1` only. If you use `--bind 0.0.0.0` **without** a token, the server prints a big **WARNING**: anyone who can reach the port can read, change and delete all data.
- The HTTP API refuses requests from other web sites (HTTP 403 `cross-site requests are not allowed`), so a bad web page in your browser cannot use your local KDB.
- Without a token, the server only accepts the host names `localhost` and `127.x.x.x` (HTTP 403 otherwise). This stops "DNS rebinding" attacks. A reverse proxy that changes the `Host` header therefore needs `--token`.
- `GET /exec` only runs statements that read. Changes must use `POST` (chapter 8).
- There is **no HTTPS** inside KDB. Use a reverse proxy.
- The token gives full access: everyone with the token can change and delete data. For people and programs that should do less, make **users** with roles instead (chapter 16).

## Try it yourself

1. Start the server with a backup folder. Make a backup with the button. Open the **Health** panel on the right.
2. Run the weekly candle query from chapter 5 for VOLT and look at it as a chart. Zoom in, then double-click.
3. Run `SELECT clsoe FROM ochl_day;` on line 3 of the editor. Which position does the error bar show?

<details>
<summary>Answers</summary>

1. `kdb serve market --backups backups`, then **Backup now**. "Last backup" changes to `just now`.
2. ```sql
   SELECT time, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
   FROM ochl_day WHERE symbol = 'VOLT' SAMPLE BY 1w WEEK START SUNDAY;
   ```
   Then click **Chart**.
3. `line 3, column 8`. The console counts lines in your editor, not in the statement.

</details>

---

Next: [7. Command line and scripts](07-command-line-and-scripts.md)
