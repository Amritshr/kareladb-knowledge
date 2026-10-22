# Dashboard page (many charts on one page)

> Put many charts on one page, each from its own query, with pickers such as $symbol at the top and an automatic refresh. Dashboards are saved in the database.

- Category: Web console
- Keywords: dashboard, dashboards, Dashboard page, panel, chart panel, text note, Add panel, Add to dashboard, Edit, Variables, $symbol, $from, variable, picker, Auto refresh, refresh, Save, _dashboards, Export JSON, Import JSON, Copy JSON, Duplicate, example dashboards, Market overview, Stock view, Portfolio, today-30d
- See also: [Web console](web-console.md), [View data page (browse and edit rows)](console-data-page.md), [Monitor panel (memory, processor, caches)](console-monitor.md), [SELECT](select.md), [Users and roles](users-and-roles.md)

The **Dashboard** page of the [web console](web-console.md) (Home menu) shows many charts on one page. Each chart is a **panel**: one `SELECT` and the chart settings for it. The panels refresh by themselves, and pickers at the top (a symbol, a date range) change every panel at once.

- A dashboard belongs to the database chosen at the top. It is saved in the table `_dashboards` of that database, so backups keep it and roles apply.
- The list always holds three **example** dashboards: **Market overview**, **Stock view** and **Portfolio**. They are made for the [sample data](sample-data.md). **Save** on an example makes your own copy.
- A panel only reads: it runs its SQL with `GET /exec`, which refuses statements that change data. Each panel reads at most 10,000 rows; **Rows** in its editor picks 100, 1,000, 10,000 or 100,000.

<a id="screen"></a>

## The screen

```text
+---------------------------------------------------------------------------------------------+
| [Stock view v] [Stock view        ]          Auto refresh [30 s v] Refresh Edit Add panel Variables Save More |
| Symbol [CITY v]   From [2025-09-23]   To [2026-09-23]                                        |
| +------------------------------------------------------------+                              |
| | Candles, volume, RSI and MACD                          ... |                              |
| |  (chart)                                                   |                              |
| +------------------------------------------------------------+                              |
| +------------------+ +---------------------------------------+                              |
| | Last close   ... | | Daily move % (calendar)           ... |                              |
+---------------------------------------------------------------------------------------------+
```

| Control | What it does |
|---|---|
| Dashboard list | Opens another dashboard: yours, then the examples |
| Title box | The dashboard's name |
| **Auto refresh** | Runs every panel again every 5 s, 10 s, 30 s, 1 min, 5 min or 15 min, or **Off** |
| **Refresh** | Runs every panel again now |
| **Edit** | Turns on moving and resizing panels |
| **Add panel** | Opens the panel editor for a new panel |
| **Variables** | The pickers at the top ([variables](#variables)) |
| **Save** | Writes the dashboard to `_dashboards` |
| **More** | **New dashboard**, **Duplicate**, **Export JSON file**, **Copy JSON**, **Import JSON**, **Delete** |

The panels sit on a grid of 12 columns. In **Edit** mode, drag a panel by its move handle, or drag its bottom right corner to resize it. With the keyboard: arrow keys move it, `Shift` + arrow keys resize it.

<a id="panels"></a>

## Panels

Each panel has a **...** menu:

| Item | What it does |
|---|---|
| **Edit** | Opens the panel editor |
| **Refresh** | Runs this panel again |
| **Open SQL in editor** | Puts the panel's SQL, with the variables filled in, into the SQL editor on Home |
| **Save PNG**, **Save CSV** | The chart as a picture, or its rows as a CSV file |
| **Full screen**, **Reset zoom** | As on the [chart](web-console.md#chart) of the SQL editor |
| **Duplicate** | A copy of the panel |
| **Remove** | Takes the panel off (in **Edit** mode only) |

The panel editor has a title, a kind and, for a chart, the SQL. **Chart from SQL** is one `SELECT` and a chart; **Text note** is a few lines of text, for example how to use the dashboard. **Run preview** (or `Ctrl+Enter`) runs the SQL and shows the chart, with the same chart types and settings as the SQL editor.

The quickest way to make a panel: run a query on Home, pick a chart, and click **Add to dashboard** on the chart bar.

**Example: A good panel query: one symbol, a time range** (sample data: sample)

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

<a id="variables"></a>

## Variables

A **variable** is a picker at the top of the dashboard. Write `$name` (or `${name}`) in a panel's SQL and the picker's value goes there. **Variables** opens the list: a name, a label, a type and a default value.

| Type | The picker | Goes into the SQL as |
|---|---|---|
| Text | a text box | a quoted text: `'CITY'` |
| List of values | a list of values you type (`CITY, COAST, VOLT`) | a quoted text |
| Values from SQL | a list filled by a query (`SELECT DISTINCT symbol FROM ochl_day ORDER BY symbol`) | a quoted text |
| Number | a number box | the number |
| Date | a date box; the default may be `today`, `today-30d`, `today-1y` | a quoted date: `'2026-09-11'` |
| Table or column name | a text box | the name as it is (letters, digits and `_` only) |
| Interval | a text box: `1d`, `15m`, `1M` | as it is, for `SAMPLE BY $step` |

- Text is always quoted, and a `'` in it is doubled, so a picker can never change what the statement does.
- A list can allow **several** values; they go in as `'CITY', 'COAST'`, for `WHERE symbol IN ($symbols)`.
- `$name` inside a quoted text or a comment is left alone.
- A value that does not fit its type (a word in a number box) stops the panel with a message; nothing is sent.

**Example: What a panel with $symbol, $from and $to runs** (sample data: sample)

```sql
-- The panel SQL:  ... WHERE symbol = $symbol AND time >= $from AND time < $to
SELECT time, close
FROM ochl_day
WHERE symbol = 'CITY' AND time >= '2025-01-01' AND time < '2026-01-01'
ORDER BY time;
```

Result:

| time (TIMESTAMP) | close (DOUBLE) |
|---|---|
| 2025-12-28T00:00:00.000Z | 542.2 |
| 2025-12-29T00:00:00.000Z | 539.7 |
| 2025-12-30T00:00:00.000Z | 539.3 |
| 2025-12-31T00:00:00.000Z | 542.4 |

(4 rows)

<a id="save"></a>

## Saving, and who may do what

| Role on the database | Can |
|---|---|
| `read` | open and look at dashboards; export them as JSON |
| `write` | also save, change and delete them |
| `admin` | also save the **first** dashboard, which creates the table `_dashboards` |

- The first **Save** in a database runs `CREATE TABLE IF NOT EXISTS _dashboards (...)`. That needs the `admin` role. A `write` user who is first is asked to let an admin save one dashboard first, or to use **More > Export JSON file**.
- A changed dashboard says `Changed, not saved` next to its title. Opening another one first asks whether to drop the changes.
- **Export JSON file** and **Import JSON** move a dashboard to another database or another server. An imported dashboard opens at once; **Save** keeps it.

**Example: The table the first Save creates**

```sql
CREATE TABLE IF NOT EXISTS _dashboards (id STRING PRIMARY KEY, title STRING NOT NULL, body STRING NOT NULL, updated TIMESTAMP, updated_by STRING);
SHOW COLUMNS FROM _dashboards;
```

Result:

`CREATE TABLE IF NOT EXISTS _dashboards (`

```text
table '_dashboards' created
```

`SHOW COLUMNS FROM _dashboards`

| name (STRING) | type (STRING) | primary_key (BOOL) | not_null (BOOL) | computed (BOOL) | references (STRING) |
|---|---|---|---|---|---|
| id | STRING | true | false | false | NULL |
| title | STRING | false | true | false | NULL |
| body | STRING | false | true | false | NULL |
| updated | TIMESTAMP | false | false | false | NULL |
| updated_by | STRING | false | false | false | NULL |

(5 rows)
