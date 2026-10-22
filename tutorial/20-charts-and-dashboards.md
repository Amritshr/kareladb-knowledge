# 20. Charts and dashboards

- Category: Tutorial

### What you will learn

- How to see any query result as a chart: candles, lines, bars, pie, treemap, heatmaps, numbers and more.
- How KarelaDB picks a chart for you, and how to change it with one click.
- How to add indicators (SMA, EMA, Bollinger, RSI, MACD, stochastic) to candles.
- How to zoom, pan and read values with the mouse, a touch screen or the keyboard.
- How to build **dashboards**: many charts on one page, with pickers like `$symbol`, auto refresh, save, share and import.

Everything runs in the web console (chapter 6). No internet is needed. The charts are drawn by KarelaDB's own code: plain JavaScript files in the console folder (`web/charts` next to `kareladb`, `web/console/charts` in the source). No chart library is loaded from the internet.

### Before you start

Load the sample data (see the quick start) and start the server:

```powershell
kareladb serve demo
```

Open <http://127.0.0.1:9900>. The examples in this chapter use the tables `ochl_day`, `ochl_minutes`, `live_data` and `securities` of the sample data.

At the top left of the console is the **Home** menu. **Home** is the SQL page you know from chapter 6. **Dashboard** is new. The button shows where you are, for example `Home / Dashboard`. The console remembers which page you used last.

## Part 1: Charts from a query

### Your first chart

1. Choose **Home** in the **Home** menu at the top left.
2. Type this query and press **Ctrl+Enter**:

   ```sql
   SELECT time, open, high, low, close, volume FROM ochl_day WHERE symbol = 'CITY' ORDER BY time;
   ```

3. Click **Chart** above the result.

> **Picture:** a dark chart area. Green and red candles go from left to right. Under them is a smaller area with green and red volume bars. Prices are on the right side, dates at the bottom. At the top left a line shows the date, O, H, L, C, the change in % and the volume of the last candle.

4. Move the mouse over the candles. A dashed crosshair follows the mouse. The top line shows the candle under the mouse. The price and the date are marked on the axes.
5. Turn the mouse wheel to zoom. Drag to move left and right. Double-click to go back.

Above the chart there is a **toolbar**:

| Part | What it does |
|---|---|
| Chart type list | Shows the chart type (here **Candlestick**). Choose another type here. |
| **Columns** | Choose which columns the chart uses. |
| Symbol list | Only when the result has several symbols: the chart shows one symbol at a time. |
| **Indicators** | Add SMA, EMA, Bollinger bands, RSI, MACD or stochastic. |
| **Log** | Logarithmic price scale. Good for long periods with big moves. |
| **No gaps** | Leave out time without rows (nights, Friday and Saturday, holidays). Every candle gets the same width. |
| Legend | Names and colors of the lines. Click a name to hide or show that line. |
| **Reset** | Back to the first view (like double-click). |
| **PNG** | Save the chart as a picture. |
| **CSV** | Save the rows of the chart as a CSV file (no new query). |
| **Full screen** | Show only the chart. Press **Escape** to go back. |
| **Add to dashboard** | Put this query and this chart on a dashboard (Part 2). |

The console remembers the chart type and the columns for each query. Run the same query again and you get the same chart.

### How KarelaDB picks the chart

KarelaDB looks at the columns of the result and picks a chart. You can always change it.

| The result has | KarelaDB shows | Example query |
|---|---|---|
| a time column and `open`, `high`, `low`, `close` | **Candlestick** (volume bars when there is a `volume` column) | `SELECT time, open, high, low, close, volume FROM ochl_day WHERE symbol = 'CITY'` |
| a time column and numbers | **Line** | `SELECT time, close FROM ochl_day WHERE symbol = 'CITY'` |
| a time column, a symbol column (up to 8 symbols) and a number | **Line**, one line per symbol | `SELECT time, symbol, close FROM ochl_day` |
| a time column, many symbols (more than 8) and one number | **Matrix heatmap** (symbols down, days across) | `SELECT time, symbol, pct_change FROM ...` |
| a text column and a number | **Bar** (horizontal bars when the names are long or many) | `SELECT symbol, sum(volume) AS volume FROM ochl_day GROUP BY symbol` |
| a text column and a share that adds up to 100 (or 1) | **Donut** | `SELECT symbol, weight FROM my_portfolio` |
| two text columns like sector and symbol, and numbers | **Treemap** | see [Treemap](#treemap) |
| two label columns and a number, like a correlation table | **Matrix heatmap** | see [Matrix heatmap](#matrix-heatmap) |
| the same text many times and a number | **Box plot** (one box per text) | `SELECT symbol, (close - open) / open * 100 AS change_pct FROM ochl_day` |
| one number column | **Histogram** | `SELECT (close - open) / open * 100 AS change_pct FROM ochl_day` |
| two number columns | **Scatter** | `SELECT close, volume FROM ochl_day` |
| three number columns | **Bubble** (the third number is the size) | |
| one row of numbers | **KPI number** | `SELECT count(*) AS trades, sum(amount) AS amount FROM trade_log` |
| no number column | no chart: the **Chart** button is off | `SELECT symbol, name FROM securities` |

### All chart types

Open the chart type list to see them all. Types that do not fit the result are grey, with a short note of what they need (for example `Candlestick (needs a time column and open, high, low, close)`).

| Group | Types |
|---|---|
| Price | Candlestick, OHLC bars |
| Time | Line, Step line, Area, Stacked area |
| Compare | Bar (vertical), Bar (horizontal), Grouped bar, Stacked bar |
| Spread | Histogram, Box plot, Scatter, Bubble |
| Share | Pie, Donut, Treemap |
| Heatmap | Calendar heatmap, Matrix heatmap |
| Number | KPI number, Gauge |
| Table | Table (green and red change columns, color scales, sparklines) |

Colors: green and red always mean up and down. Lines and bars use eight other colors (blue, orange, violet, pink, yellow, cyan, brown, purple) that people with color blindness can also tell apart. The charts follow the **Light / Dark** button of the console.

### Choose the columns

Click **Columns**. A small box opens. What you can choose depends on the chart type:

| Chart type | Choices |
|---|---|
| Candlestick, OHLC | Time, Open, High, Low, Close, Volume, One chart per (for example `symbol`) |
| Line, Step, Area, Stacked area | Time (X), Values (Y, several), Series (group), One chart per |
| Bars | Category, Values (several), Series (group), Colors (one color per series, or green above 0 and red below) |
| Histogram | Value, Bins (how many bars; empty = chosen for you) |
| Box plot | Group, Value |
| Scatter, Bubble | X, Y, Size, Color, Label |
| Pie, Donut | Category, Value |
| Treemap | Group, Label, Size, Color (change) |
| Calendar heatmap | Date, Value, One chart per |
| Matrix heatmap | Columns (X), Rows (Y), Value; or Value columns (wide table) |
| KPI number | Numbers, Change column, Order by time, Minimum, Maximum |
| Gauge | Value, Order by time, Minimum, Maximum |
| Table | Green/red columns, Color scale columns, Sparkline: one row per, time, value |

Press **Escape** or **Close** to close the box.

### Candles, volume and indicators

#### Indicators from the menu

1. Run the candle query from [Your first chart](#your-first-chart) and click **Chart**.
2. Click **Indicators**.
3. Choose **RSI** in the list and click **Add**. A new area opens under the volume bars. It shows the RSI line with lines at 30 and 70.
4. Choose **MACD** and click **Add**. Another area shows the MACD line, the signal line and green/red histogram bars.
5. Choose **SMA** and click **Add**. A line is drawn over the candles.
6. Change the numbers in the box, for example `period 50` for SMA. The chart changes at once.
7. Click **Remove** to take an indicator away.

| Indicator | Where | Settings |
|---|---|---|
| SMA, EMA | over the candles | period (20) |
| Bollinger bands | over the candles, with a light band | period (20), mult (2) |
| RSI | own area, 0 to 100, lines at 30 and 70 | period (14) |
| MACD | own area: MACD, signal, histogram | fast (12), slow (26), signal (9) |
| Stochastic | own area, 0 to 100, lines at 20 and 80 | period (14), smooth (3), signal (3) |

The indicators are computed in the browser from the close prices of the rows. They also work on a line chart with one line.

At the top left of each area, a small line shows the values under the mouse, for example `RSI  RSI 14 56.21`.

#### Indicators from SQL

Chapter 19 has many indicator functions. When your query returns them as columns, the chart puts them in the right place by their name:

```sql
SELECT time, open, high, low, close, volume,
       sma(close, 5)  AS sma_5,
       rsi(close, 5)  AS rsi_5
FROM ochl_day WHERE symbol = 'CITY' ORDER BY time;
```

| Column name contains | Drawn |
|---|---|
| `sma`, `ema`, `wma`, `vwap`, `bb_upper`, `bb_middle`, `bb_lower`, `upper`, `lower` | a line over the candles |
| `rsi` | the RSI area (0 to 100) |
| `macd`, `signal`, `hist` | the MACD area; a name with `hist` is drawn as bars |
| `stoch`, `_k`, `_d` | the stochastic area |
| `atr`, `adx`, `cci`, `obv`, `mfi`, `roc`, `willr` | an own area with that name |
| any other number | over the candles when its values are near the prices, else an own area |

A name without `AS` works too, for example the column `sma(close, 20)`.

#### Big data: 100,000 candles

The chart stays fast with many rows. When you zoom out so far that several candles fall on one pixel, KarelaDB joins them: one candle then stands for 2, 4, 8, ... rows (first open, highest high, lowest low, last close, total volume). The top line then shows the time range, for example `2026-01-04 - 2026-02-11  O 505  H 530  L 498  C 521`. Zoom in and you see every candle again.

For more than 100,000 rows, raise **Rows** at the top of the editor. The most is 1,000,000 rows per query.

### Zoom, pan and read values

| Mouse or touch | What it does |
|---|---|
| Wheel | Zoom in and out around the mouse |
| Drag | Move left and right (scatter: in every direction) |
| Two fingers (phone, tablet) | Pinch to zoom, move to pan |
| Tap (phone) | Show the values at that place |
| Double-click | Reset |
| Move the mouse | Crosshair and values (candles and lines: top line; other charts: a small box next to the mouse) |

The chart can be used with the keyboard. Press **Tab** until the chart has a blue frame:

| Keys | What it does |
|---|---|
| **Left** / **Right** (or **Up** / **Down**) | Move a cursor from row to row, bar to bar, slice to slice. The values are shown and read out by screen readers. |
| **Shift** + arrow | Move the view |
| **+** / **-** | Zoom in / out |
| **Home** or **0** | Reset |
| **F** | Full screen |
| **Escape** | Hide the cursor, or leave full screen |

#### Log scale

Tick **Log** for a logarithmic price scale. The same percent move then has the same height at a low price and at a high price. Log works when all visible values are above 0. It is not offered for bars.

#### No gaps (trading-day time axis)

A stock market is open only some hours of some days (for example 11:00 to 15:00, Sunday to Thursday, as on some exchanges). With real time, a minute chart has big empty spaces for nights and weekends. With **No gaps**, those spaces are left out and each row gets the same width. The date labels are then placed on the first row of a new day, month or year.

- Candles and OHLC use **No gaps** from the start.
- Lines use it when the rows have big holes. Untick **No gaps** to see real time.

### Tables with colors and sparklines

Choose **Table** in the chart type list.

- Columns whose names mean a change (`change`, `pct_change`, `diff`, `gain`, `return`, ...) and columns with plus and minus values are **green** with ▲ when above 0 and **red** with ▼ when below. The arrows help people who cannot see colors well.
- In **Columns**, pick **Color scale columns** to color the cells from low (light) to high (dark). With plus and minus values the scale goes red - grey - green.
- Click a column name to sort.

**Sparklines:** when the result has a symbol, a time and a price, the table shows one row per symbol with the last price, the change in % and a small price line:

```sql
SELECT symbol, time, close FROM ochl_day ORDER BY time;
```

> **Picture:** a table with the columns `symbol`, `close`, `change %` and `trend`. Each row has a small line in the `trend` column. The line is green when the price went up, red when it went down.

A cell with a JSON list of numbers, like `[505.2, 507.1, 503.9]`, also becomes a sparkline.

The table shows at most 2,000 rows. The **Grid** view shows all rows.

### Examples for each chart type

All examples use the sample data. Run the query, click **Chart**, and choose the type when KarelaDB picks another one.

#### Line, step line, area

```sql
SELECT time, symbol, close FROM ochl_day ORDER BY time;
```

One line per symbol, with a legend. Choose **Step line** for prices that jump, or **Area** for one line with a light fill.

#### Stacked area

```sql
SELECT o.time, o.symbol, o.close * h.qty AS value
FROM ochl_day o
JOIN (SELECT 'CITY' AS symbol, 100 AS qty UNION ALL SELECT 'COAST', 150) h ON h.symbol = o.symbol
ORDER BY o.time;
```

Choose **Stacked area**. The layers add up to the total value of the two holdings.

#### Bars

```sql
SELECT symbol, sum(volume) AS volume FROM ochl_day GROUP BY symbol ORDER BY volume DESC;
```

> **Picture:** three blue bars with rounded tops, one per symbol, with the value on top of each bar.

For long names KarelaDB turns the bars sideways:

```sql
SELECT s.name, sum(o.volume) AS volume FROM ochl_day o JOIN securities s ON s.symbol = o.symbol GROUP BY s.name;
```

#### Grouped and stacked bars

```sql
SELECT time, symbol, volume FROM ochl_day WHERE time >= '2026-08-23' ORDER BY time;
```

Choose **Stacked bar**: one bar per day, one colored part per symbol. Choose **Grouped bar** to put the symbols side by side. In **Columns**, **Category** is `time`, **Values** is `volume` and **Series** is `symbol`.

Bars with plus and minus values: open **Columns** and choose **Colors: Green above 0, red below**.

#### Histogram

```sql
SELECT (close - open) / open * 100 AS change_pct FROM ochl_day;
```

How many days moved by how much. Hover over a bar to see the range and the number of days. Set **Bins** in **Columns** for more or fewer bars.

#### Box plot

```sql
SELECT symbol, (close - open) / open * 100 AS change_pct FROM ochl_day;
```

One box per symbol. The box goes from the 25% value to the 75% value; the thick line is the middle value (median). The thin lines reach the lowest and the highest normal values. Dots are unusual values (outliers). Hover over a box to see all numbers.

#### Scatter and bubble

```sql
SELECT close, volume FROM ochl_day;
```

One dot per row. Hover over a dot to see its values. For a bubble chart, return three numbers and choose **Bubble**; the third number is the size of the bubble. A text column in **Color** gives each group its own color and a legend.

#### Pie and donut

```sql
SELECT s.sector, sum(l.ltp * l.volume) AS turnover
FROM (SELECT symbol, ltp, volume FROM live_data LATEST ON timestamp PARTITION BY symbol) l
JOIN securities s ON s.symbol = l.symbol
GROUP BY s.sector;
```

Choose **Donut**. The middle shows the total. The legend shows the share of each sector in %. More than 8 parts are joined into **Other**.

#### Treemap

```sql
SELECT s.sector, l.symbol, l.ltp * l.volume AS turnover, l.pct_change
FROM (SELECT symbol, ltp, volume, pct_change FROM live_data LATEST ON timestamp PARTITION BY symbol) l
JOIN securities s ON s.symbol = l.symbol;
```

> **Picture:** big rectangles, one per sector, with the sector name on top. Inside, one box per symbol. A bigger box means more turnover. Green boxes went up, red boxes went down; the stronger the color, the bigger the move. Each box shows the symbol and the change, for example `CITY +2.71%`.

#### Calendar heatmap

```sql
SELECT time, (close - open) / open * 100 AS change_pct FROM ochl_day WHERE symbol = 'CITY';
```

Choose **Calendar heatmap**. One small square per day, in columns of weeks (a week starts on Sunday) and rows of weekdays. Green days went up, red days went down. When the days span less than about a year, the calendar shows only those weeks; otherwise one row per year.

#### Matrix heatmap

Daily moves of every symbol:

```sql
SELECT time, symbol, (close - open) / open * 100 AS change_pct FROM ochl_day ORDER BY time;
```

Choose **Matrix heatmap**. Symbols go down, days go across.

A correlation matrix (with the `corr` function of chapter 19):

```sql
SELECT a.symbol AS a, b.symbol AS b, corr(a.close, b.close) AS corr
FROM ochl_day a JOIN ochl_day b ON a.time = b.time
GROUP BY a.symbol, b.symbol;
```

KarelaDB picks the matrix by itself. Values from -1 to 1 get red (-1), grey (0) and green (1), and each cell shows its number when there is room.

#### KPI number and gauge

```sql
SELECT count(*) AS trades, sum(amount) AS amount FROM trade_log;
```

> **Picture:** two big numbers side by side, with the column names above them.

With several rows in time order, the KPI shows the last value, the change from the row before with ▲ or ▼, and a small line of all values:

```sql
SELECT time, close FROM ochl_day WHERE symbol = 'CITY' ORDER BY time;
```

Choose **KPI number**. For a **Gauge** (a half circle that fills up), set **Minimum** and **Maximum** in **Columns**. Without them the gauge uses 0 to a round number above the value (0 to 100 for names with `pct`, `rsi` or `share`).

## Part 2: Dashboards

A dashboard is a page with many charts. Each chart is a **panel**. A panel has a title, one SQL query and chart settings. Dashboards are saved **in the database** (table `_dashboards`), so they are in every backup.

### Open the example dashboards

Choose **Dashboard** in the **Home** menu at the top left. The first time, the list at the top left has three examples:

| Example | Panels |
|---|---|
| **Market overview** | Market turnover (KPI), advancers and decliners (KPI), market average close (area), top gainers and top losers (tables with green and red), sectors (treemap), turnover by symbol (bars). Refreshes every 5 seconds. |
| **Stock view** | Candles with volume, SMA 20, RSI 14 and MACD; last close (KPI); daily move % (calendar); size of daily moves (histogram). Pickers for symbol, from and to. |
| **Portfolio** | Portfolio value (area), allocation (donut), value by symbol (stacked area), holdings with trend (table with sparklines), a note. |

> **Picture (Market overview):** a row of three boxes at the top: a big number `126,481,156` for turnover, the numbers `3` and `1` for advancers and decliners, and a small area chart. Below are two tables with green ▲ and red ▼ values, then a treemap of sectors and horizontal bars of turnover.

The examples use the tables of the sample data. On your own database, open one and change the SQL of the panels (see [Edit a panel](#edit-a-panel)). Click **Save** to keep your own copy; the example itself does not change.

### Make your own dashboard

1. Open **Dashboard** in the **Home** menu, then **More** > **New dashboard**.
2. Type a title, for example `My watchlist`, and click **Create**. The empty dashboard opens in edit mode.
3. Click **Variables**, then **Add variable**. Fill in:
   - name: `symbol`
   - label: `Symbol`
   - type: **Values from SQL**
   - default value: `CITY`
   - SQL for the values: `SELECT DISTINCT symbol FROM ochl_day ORDER BY symbol`

   Click **OK**. A **Symbol** list appears under the title bar.
4. Click **Add panel**. Fill in:
   - Title: `Candles`
   - SQL:

     ```sql
     SELECT time, open, high, low, close, volume FROM ochl_day
     WHERE symbol = $symbol ORDER BY time
     ```

   Click **Run preview** (or press **Ctrl+Enter** in the SQL box). The chart appears on the right. Change the chart type or the columns there, if you want. Click **Add**.
5. Click **Add panel** again:
   - Title: `Volume share`
   - SQL: `SELECT symbol, sum(volume) AS volume FROM ochl_day GROUP BY symbol`
   - **Run preview**, choose **Donut** in the chart type list, click **Add**.
6. Click **Save**. The message says `Saved "My watchlist" in the table _dashboards of database demo.`
7. Click **Done** to leave edit mode.
8. Choose another symbol in the **Symbol** list. Every panel that uses `$symbol` runs again.

Reload the page: the Dashboards page and your dashboard open again.

### Add a chart from the SQL page

1. Run a query on the **Home** page and click **Chart**.
2. Pick the chart type and the columns.
3. Click **Add to dashboard** in the chart toolbar.
4. Choose the dashboard (or **A new dashboard**) and a panel title. Click **Add**.
5. The dashboard opens with the new panel. Click **Save**.

### Edit a panel

Each panel has a **...** button at its top right:

| Menu item | What it does |
|---|---|
| **Edit** | Change the title, the SQL, the number of rows, the chart type and the columns |
| **Refresh** | Run this panel again |
| **Open SQL in editor** | Put the SQL (with the variable values filled in) into the SQL page |
| **Save PNG**, **Save CSV** | Save the chart as a picture, or its rows as CSV |
| **Full screen** | Show only this chart |
| **Reset zoom** | Back to the first view |
| **Duplicate** | A copy of the panel |
| **Remove** | Delete the panel (edit mode only) |

In the panel editor, **Kind** can also be **Text note**: a panel with plain text, for example how to use the dashboard.

A panel runs **one** statement that **reads**: `SELECT` (also `WITH`, `SHOW`, `EXPLAIN`). The console sends it with `GET /exec`, and the server refuses SQL that changes data there (chapter 8). So a dashboard can never change or delete data, even when someone sends you a bad dashboard file.

On a dashboard, the mouse wheel scrolls the page. To zoom a chart, hold **Ctrl** and turn the wheel, or click the chart first.

### Move and resize panels

Click **Edit**. The panels get a grip (three lines) at the top left and a corner at the bottom right.

- **Move:** drag the top bar of a panel. A dashed box shows where it will go. Other panels move down to make room.
- **Resize:** drag the corner at the bottom right.
- **With the keyboard:** press **Tab** until the grip of a panel is selected. The **arrow keys** move the panel; **Shift + arrow keys** make it wider, narrower, taller or shorter.

The page has 12 columns. Panels move up when there is space above them, so there are no holes.

On a phone (narrow screen), the panels are shown one under the other, in the order top to bottom and left to right.

### Variables

A variable is a picker at the top of the dashboard. Write `$name` (or `${name}`) in the SQL of a panel.

| Type | Picker | Put into SQL as | Example |
|---|---|---|---|
| **Text** | a text box | a quoted text: `'CITY'` | `WHERE symbol = $symbol` |
| **List of values** | a list with the values you typed (`CITY, COAST, VOLT`) | `'COAST'` | `WHERE symbol = $symbol` |
| **Values from SQL** | a list with the first column of a query | `'COAST'` | `SELECT DISTINCT symbol FROM ochl_day ORDER BY symbol` |
| **Number** | a number box | `25` (only a number is allowed) | `LIMIT $top` |
| **Date** | a date box | `'2026-09-11'` | `WHERE time BETWEEN $from AND $to` |
| **Table or column name** | a text box | the name, only letters, digits and `_` | `SELECT * FROM $table` |
| **Interval** | a text box | `1d`, `15m`, `1M` | `SAMPLE BY $step` |

- **Many values:** tick **many values** for a list. Then write `IN ($symbols)`: `WHERE symbol IN ($symbols)` becomes `WHERE symbol IN ('CITY', 'COAST')`.
- **Dates relative to today:** a default of `today`, `today-30d`, `today-1w`, `today-3M` or `today-1y` is turned into a date when the dashboard opens. `now-2h` gives a time.
- A `$name` inside quotes (`'$symbol'`) or in a comment is not changed.
- The values you pick are remembered in your browser for each dashboard.

**Why this is safe:** text values are always written as SQL text with quotes, and a quote inside the value is doubled (`O'Brien` becomes `'O''Brien'`). A number must be a number, a date must look like a date, and a name may only have letters, digits and `_`. A wrong value shows an error in the panel and nothing runs. So a value like `CITY'; DROP TABLE x; --` stays harmless text.

### Auto refresh

The **Auto refresh** list has **Off**, **5 s**, **10 s**, **30 s**, **1 min**, **5 min** and **15 min**. With 5 s, every panel runs again every 5 seconds, for example for live prices from `live_data`.

- Auto refresh pauses while the browser tab is hidden and while a dialog is open.
- When you zoomed a chart, the zoom stays after a refresh. When the view showed the newest rows, it follows the new rows.
- The refresh interval is saved with the dashboard. **Refresh** runs all panels at once.
- The server keeps a result cache (`kareladb serve --cache-mb`, default 64 MB). A panel that asks the same question again, while the tables did not change, gets its answer from memory. So auto refresh is cheap.

### Save, share, export and import

**Save** writes the dashboard into the table `_dashboards` of the chosen database. The console makes the table the first time:

```sql
CREATE TABLE IF NOT EXISTS _dashboards (id STRING PRIMARY KEY, title STRING NOT NULL, body STRING NOT NULL, updated TIMESTAMP, updated_by STRING);
```

You can look at it on the SQL page:

```sql
SELECT id, title, updated, updated_by FROM _dashboards;
```

```text
id            | title        | updated                  | updated_by
--------------+--------------+--------------------------+-----------
my-watchlist  | My watchlist | 2026-09-11T08:15:02.113Z | null
```

(`updated_by` is the user name when the server has users.)

Each database has its own dashboards. Choose another database at the top and the list changes. `BACKUP DATABASE` and **Backup now** save the dashboards too.

The **More** menu:

| Item | What it does |
|---|---|
| **New dashboard** | An empty dashboard |
| **Duplicate** | A copy of this dashboard (Save to keep it) |
| **Export JSON file** | Download the dashboard as a `.json` file |
| **Copy JSON** | Copy the same text to the clipboard, to paste in a chat or email |
| **Import JSON** | Paste JSON or choose a `.json` file. The dashboard opens; click **Save** to keep it. An import never replaces a saved dashboard. |
| **Delete** | Delete the saved dashboard from the database |

A dashboard file looks like this (shortened):

```json
{
  "kdb_dashboard": 1,
  "id": "my-watchlist",
  "title": "My watchlist",
  "description": "",
  "refresh": 0,
  "variables": [
    { "name": "symbol", "label": "Symbol", "type": "query", "default": "CITY",
      "sql": "SELECT DISTINCT symbol FROM ochl_day ORDER BY symbol" }
  ],
  "panels": [
    { "id": "candles", "kind": "chart", "title": "Candles", "x": 0, "y": 0, "w": 6, "h": 5,
      "sql": "SELECT time, open, high, low, close, volume FROM ochl_day\nWHERE symbol = $symbol ORDER BY time",
      "chart": { "type": "candle", "indicators": [{ "kind": "rsi", "period": 14 }] },
      "limit": 10000 }
  ]
}
```

- `x`, `y`, `w`, `h`: place and size in grid units (12 columns; one row is 60 pixels).
- `chart`: the chart type and the columns, like in the **Columns** box.
- When a file is imported, KarelaDB checks it: unknown fields are dropped, wrong values are fixed, and panels never overlap.

### Who can do what

When the server has users (chapter 16), the role decides:

| Role on the database | Look at dashboards | Change them on the page | Save | Delete |
|---|---|---|---|---|
| `read` | yes | yes (not saved; use **Export JSON file**) | no, the **Save** button is off | no |
| `write` | yes | yes | yes, when the table `_dashboards` exists | yes |
| `admin` | yes | yes | yes; the first save creates `_dashboards` | yes |

The first dashboard in a database creates the table `_dashboards`. Creating a table needs the `admin` role. If a `write` user saves first, the message says: `The first dashboard in a database creates the table _dashboards. That needs the admin role; ...` Ask an admin to save one dashboard, or to run the `CREATE TABLE` above.

Panels run with the role of the person who looks at the dashboard. A `read` user sees only data that `read` may see.

### Limits

- A panel shows at most the rows set in **Rows at most** (up to 100,000). The SQL page can show up to 1,000,000 rows.
- Up to 60 panels and 20 variables per dashboard.
- A **Table** chart shows 2,000 rows (the Grid view shows all).
- Pie and donut show 8 parts at most; the rest is **Other**. Scatter colors: 8 groups at most.
- Indicators from the **Indicators** menu need one series (no **Series** column).
- Log scale is for line, candle, area and scatter charts, not for bars.
- Dashboards are shared with everyone who can open the database. There are no private dashboards; use a separate database for that.
- There is no "undo" in the dashboard editor. Leave without saving to go back (the console asks first).

### Try it yourself

1. Show the daily moves of CITY as a calendar heatmap. Which day had the biggest drop?
2. Make a chart of the CITY minute candles for 15 minutes, with Bollinger bands and a stochastic area.
3. Make a dashboard **Two stocks** with two variables `$a` and `$b` (lists of symbols) and a line panel that shows both closes.
4. A friend sends you a dashboard file. How do you open it without replacing your own dashboards?

<details>
<summary>Answers</summary>

1. Run
   ```sql
   SELECT time, (close - open) / open * 100 AS change_pct FROM ochl_day WHERE symbol = 'CITY';
   ```
   Click **Chart**, choose **Calendar heatmap**, and move the mouse over the reddest square. The box next to the mouse shows the date and the value.
2. Run
   ```sql
   SELECT time, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
   FROM ochl_minutes WHERE symbol = 'CITY' SAMPLE BY 15m;
   ```
   Click **Chart**, then **Indicators**: add **Bollinger bands** and **Stochastic**.
3. **More** > **New dashboard**, title `Two stocks`. **Variables**: add `a` and `b`, type **List of values**, values `CITY, COAST, VOLT`, defaults `CITY` and `COAST`. **Add panel** with
   ```sql
   SELECT time, symbol, close FROM ochl_day WHERE symbol IN ($a, $b) ORDER BY time
   ```
   KarelaDB draws one line per symbol. **Save**.
4. **More** > **Import JSON**, choose the file, **Open**. Check the SQL of the panels, then **Save**. An import always gets a new id, so it never replaces a saved dashboard.

</details>

---

Back to the tutorial overview
