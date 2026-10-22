# View data page (browse and edit rows)

> Look at the rows of a table in the console and change them with forms - add, edit and delete - without writing SQL.

- Category: Web console
- Keywords: data page, View data, browse, browser, table browser, edit row, change row, add row, insert row, delete row, new table, phpMyAdmin, WHERE filter, paging, per page, sort column, primary key, read-only, time-series, no primary key, Open in SQL
- See also: [Web console](web-console.md), [Settings page (data folder, old log, capacity, program files and users)](console-settings.md), [Monitor panel (memory, processor, caches)](console-monitor.md), [INSERT](insert.md), [UPDATE and DELETE](update-delete.md), [Constraints](constraints.md), [CREATE TABLE](create-table.md), [Table rights - GRANT ON TABLE](table-rights.md)

The **View data** page of the [web console](web-console.md) (Home menu) shows the tables of the chosen database and the rows inside them. You can add, change and delete rows with a form instead of writing [INSERT](insert.md), [UPDATE and DELETE](update-delete.md) by hand.

Everything it does goes through `/exec`, so a user may only do what their [role](users-and-roles.md) allows: a `read` user sees the rows and no buttons, a `write` user may change them, and an `admin` may also make tables.

<a id="screen"></a>

## The screen

```text
+--------------------+------------------------------------------------------------------------+
| TABLES             | trades  timeseries - by DAY          [Add row] [Open in SQL] [Refresh]  |
| [Find a table   ]  | WHERE [ qty > 10                          ] [Apply] [Filter columns...] |
|  trades    69.3M   |      | date       | symbol   | broker   | qty  | rate   |               |
|  items         5   |      | [(all)  v] | [CITY v] | [(all) v]| LONG | DOUBLE |               |
|                    |      | 2026-09-11 | CITY     | 58       |  100 | 512.40 |               |
|                    |      | 2026-09-11 | CITY     | 12       |   50 | 512.00 |               |
| [New table]        | Rows 1-50 of 4,112   < 1 2 3 ... 83 > Last     Per page [50 v]         |
+--------------------+------------------------------------------------------------------------+
```

| Part | What it is |
|---|---|
| Left list | every table of the database, with its row count. Type in the box to find one. |
| **New table** | a small form for `CREATE TABLE`; it shows the statement it will run before it runs it (admins only) |
| **WHERE** box | an extra condition, exactly as you would write it in SQL. Press Enter or **Apply**. |
| **Filter columns...** | tick the columns that get a list of their values in the heading (symbol, date, broker ...). Pick a value from a list to see only its rows; several lists combine. The list holds each different value once, newest first for a time column, at most 500. |
| Column heads | click one to sort the **whole table** by it (not only the page); click again for the other direction. A time-series table opens newest first. |
| **Edit** / **Delete** | change or remove that one row |
| **Add row** | a form with one box per column |
| **Open in SQL** | puts the `SELECT` this page is showing into the Home page ([SQL editor](web-console.md#editor)), to change it by hand |
| Pager | page numbers, `<` `>` and **Last**; 25 to 500 rows a page; how many rows the filters found |

The page remembers the table you were looking at, the rows-per-page and each table's filter columns, so coming back opens where you left off. A value list is one `SELECT DISTINCT` per column, read once per table (and again on **Refresh**): on a table of many million rows it takes a moment, and the rows show first.

<a id="editable"></a>

## Which tables can be edited

To change or delete **one** row, KarelaDB has to be able to name that row on its own. That is what a [`PRIMARY KEY`](constraints.md#primary-key) is for.

| Table | Browse | Add a row | Edit or delete one row |
|---|---|---|---|
| relational, with `PRIMARY KEY` | yes | yes | **yes** |
| relational, without a key | yes | yes | no |
| time-series (`TIMESERIES(...)`) | yes | yes | no |

A [time-series table](create-table.md) has a `DEDUP KEY`, not a primary key, and the same key may appear more than once. A form that edited "the row" could quietly change several, so the page does not offer it and says why instead. Use the SQL editor on Home with a `WHERE` you have checked, and run the matching `SELECT` first to see what it will hit.

- The primary key column itself cannot be changed in the edit form: it is the name the row is found by. Delete the row and add a new one to change a key.
- A `PRIMARY KEY AUTO` column is left out of the add form; the server hands the value out.
- Computed columns are left out too: the engine works them out.

<a id="sql"></a>

## What it sends

Nothing is hidden. Each button sends one ordinary statement:

| Button | Statement |
|---|---|
| **Add row** | `INSERT INTO items (name, qty) VALUES ('bolt', 12)` |
| **Save** (edit) | `UPDATE items SET qty = 137 WHERE id = 2` |
| **Delete** | `DELETE FROM items WHERE id = 2` |
| **New table** | the `CREATE TABLE` shown in the form |

- Only the boxes you actually changed go into the `SET` list.
- An empty box means `NULL`.
- Text is quoted and `'` inside it is doubled. A number box that does not hold a number is refused before anything is sent, with a message that says which column.
- Anything the server refuses (a `NOT NULL` column left empty, a `CHECK` that fails, a missing `REFERENCES` row, a role that is too weak) is shown as it came back, so the reason is the server's own.

**Example: A table the View data page can fully edit**

```sql
CREATE TABLE items (
  id     INT PRIMARY KEY AUTO,
  name   STRING NOT NULL,
  qty    INT,
  price  DOUBLE
);
INSERT INTO items (name, qty, price) VALUES ('bolt', 12, 0.45), ('nut', 40, 0.12);
SELECT * FROM items;
```

Result:

`CREATE TABLE items (`

```text
table 'items' created
```

`INSERT INTO items (name, qty, price) VALUES ('bolt', 12, 0.45), ('nut', 40, 0.12)`

```text
2 row(s) inserted
```

`SELECT * FROM items`

| id (INT) | name (STRING) | qty (INT) | price (DOUBLE) |
|---|---|---|---|
| 1 | bolt | 12 | 0.45 |
| 2 | nut | 40 | 0.12 |

(2 rows)

<a id="notes"></a>

## Notes

- The row count under the pager is a real `SELECT count(*)` with the same filter, so it is the true number, not an estimate.
- Big values are cut off in the grid; the full text is in the cell's tooltip. For the whole value use the SQL editor on Home.
- The page reads at most one page of rows at a time, so opening a table with millions of rows costs the same as opening a small one.
- Rights per table ([table rights](table-rights.md)) apply here as everywhere else: a table you may not read is not listed.
