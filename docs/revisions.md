# Change revisions: GET /api/rev and kdb_rev()

> A cheap number per table and per symbol that changes when committed rows change, so a chart polls it and reads its candles again only when they changed.

- Category: HTTP API
- Keywords: revision, revisions, rev, GET /api/rev, api/rev, kdb\_rev, candle rev, candle-rev, change signal, did it change, poll, polling, chart refresh, table\_rev, boot, rev column, per-symbol revision
- See also: [Performance tips (result-cache)](performance-tips.md#result-cache), [Pinned queries](pinned-queries.md), [Run SQL over HTTP (/exec, /exp)](http-exec.md), [CREATE TABLE](create-table.md)

A chart that shows NABIL's candles does not need to read them every few seconds. It can ask for NABIL's **revision** instead, and read the candles again only when the revision changed.

- A revision is a short text such as `a67f6ff8e720.1532`. Compare it for **equality** only; the number is not a count and not a time.
- It changes after every **committed** change of rows holding that value: `INSERT`, `UPDATE`, `DELETE`, `POST /write`, `POST /imp`, a trigger, a `CALL`.
- A change **inside an open transaction** does not move it. It moves at `COMMIT`. A rollback may move it too; the rows are then the same as before, and a read again simply gives them.
- Another value's writes never move it: a new NEPSE candle leaves NABIL's revision alone.
- A **restart** changes every revision (the part before the dot is new).
- It never waits for the database lock: it answers in well under a millisecond, even while a long `CALL` or bulk load writes.

<a id="rev-column"></a>

## Which column has revisions

Each table keeps revisions for the values of **one** column, when it has one of these:

| Table | Column with revisions |
|---|---|
| `PARTITION BY ..., SYMBOL(symbol)` | `symbol` (the column named in `SYMBOL(...)`) |
| `SORT BY (symbol, time)`, `DEDUP KEY (symbol, time)`, or a `PRIMARY KEY` whose first column is a `SYMBOL` | that first column |
| anything else (`SORT BY (time, symbol)`, no SYMBOL key) | none: every value gets the table's revision |

A table without a rev column still works: its values then change together, whenever any row of the table changes.

Revisions per value are for columns with **up to 10,000 values**, such as the symbols of a market. They live in memory, outside `--memory`. When a table's rev column gets more values than that (a `SYMBOL` primary key of customer ids, say), the table drops its list and goes on as if it had no rev column: every write then moves every value's revision. `rev_values` in `GET /api/stats` counts the values kept.

The same values decide what the [result cache](performance-tips.md#result-cache) keeps: a cached `WHERE symbol = 'NABIL'` result stays valid while only other symbols are written.

<a id="api-rev"></a>

## GET /api/rev

Syntax:

```sql
GET /api/rev?table=<name>&symbol=<value>[&symbol=<value> ...][&column=<name>][&db=<name>]
```

| Parameter | Meaning |
|---|---|
| `table` | the table (required) |
| `symbol` | a value of the rev column; repeat it for more (up to 1000). `value=` is the same |
| `column` | optional: the rev column's name. A different name is a 400 that names the right one |
| `db` | the database; the default database without it |

The answer:

| Field | Meaning |
|---|---|
| `table`, `column` | the table and its rev column (`null` when it has none) |
| `boot` | changes when the database opens again |
| `table_rev` | changes after every committed change of the table |
| `revs` | one revision per value asked for |

It needs read rights on the table: role `read` on the database, or `GRANT SELECT` on the table. An unknown table is a 404.

**HTTP: The revisions of two symbols**

Setup:

```text
CREATE TABLE candles (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time)
  PARTITION BY YEAR, SYMBOL(symbol) SORT BY (symbol, time) DEDUP KEY (symbol, time);
INSERT INTO candles VALUES ('2026-09-24T10:00:00Z', 'NABIL', 1510), ('2026-09-24T10:00:00Z', 'NEPSE', 2750);
```

```http
GET /api/rev?table=candles&symbol=NABIL&symbol=NEPSE
```

Response:

HTTP 200 (application/json)

```text
{
  "database": "demo",
  "table": "candles",
  "column": "symbol",
  "boot": "7461510af8ea",
  "table_rev": "7461510af8ea.0",
  "revs": {"NABIL": "7461510af8ea.0", "NEPSE": "7461510af8ea.0"}
}
```

**HTTP: Asking by the wrong column says which one has revisions**

Setup:

```text
CREATE TABLE candles (time TIMESTAMP, symbol SYMBOL, close DOUBLE) TIMESERIES(time)
  PARTITION BY YEAR, SYMBOL(symbol) SORT BY (symbol, time) DEDUP KEY (symbol, time);
```

```http
GET /api/rev?table=candles&column=close&symbol=NABIL
```

Response:

HTTP 400 (application/json)

```text
{"error": "table 'candles' keeps revisions per value of column 'symbol', not 'close'"}
```

A page that polls:

```js
let seen = null;
setInterval(async () => {
  const r = await (await fetch('/api/rev?table=candles&symbol=NABIL')).json();
  if (r.revs.NABIL !== seen) {
    seen = r.revs.NABIL;
    drawChart(await readCandles('NABIL'));  // only when NABIL changed
  }
}, 2000);
```

<a id="kdb_rev"></a>

## kdb_rev

Syntax:

```sql
kdb_rev('<table>')
kdb_rev('<table>', '<value>')
```

The same revisions in SQL, for clients that only speak the [PostgreSQL protocol](postgres-protocol.md). With one argument: the table's revision (`table_rev`). With two: the revision of that value of the rev column. It gives the same text as `GET /api/rev`, and needs the same right: reading the table (a user whose `SELECT` on it was revoked gets an error). Unlike the route it runs as a statement, so it waits for the database lock like any `SELECT`. A NULL argument gives NULL; an unknown table is an error.

**Example: A symbol's revision and the table's** (sample data: sample)

```sql
SELECT length(kdb_rev('ochl_minutes', 'CITY')) > 0 AS has_rev,
       kdb_rev('ochl_minutes', 'CITY') = kdb_rev('ochl_minutes', 'CITY') AS stable;
```

Result:

| has_rev (BOOL) | stable (BOOL) |
|---|---|
| true | true |

(1 row)
