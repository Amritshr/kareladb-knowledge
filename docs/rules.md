# Rules

> Name a check, the trading hours or the dedup choice of a table once, and KDB applies it to every row written - saying which rule refused a row and why.

- Category: Tables
- Keywords: rule, rules, CREATE RULE, ALTER RULE, DROP RULE, SHOW RULES, kdb_rules, price guard, value range, session hours, trading hours, ON FAIL SKIP, ON FAIL REJECT, dedup_keep, keep first, check rule
- See also: [CREATE TABLE](create-table.md), [Trading calendars](calendars.md), [Partitions, SORT BY and DEDUP KEY](partitions-and-dedup.md), [Time and time zones](time-and-time-zones.md)

A **rule** is a named check or setting of one table. It applies to every row written to the table - `INSERT`, `UPDATE`, `COPY`, `/imp`, `/write` and line protocol - and a row it refuses says **which rule and why**. Rules are listed by `SHOW RULES`, switched off and on by `ALTER RULE`, and saved with the table.

| Kind | Example | What it does |
|---|---|---|
| check | `CHECK (close > 0)` | every new or changed row must not make the condition false |
| session | `SESSION '11:00' TO '15:00' TIME ZONE 'Asia/Kathmandu' CALENDAR nepse` | the row's time must be inside the hours, on a trading day of the calendar |
| setting | `SET dedup_keep = 'first'` | which of two rows with the same DEDUP KEY stays |

<a id="create-rule"></a>

## CREATE RULE

Syntax:

```sql
CREATE RULE [IF NOT EXISTS] name ON table
    CHECK (condition)
  | SESSION 'HH:MM' TO 'HH:MM' [TIME ZONE 'zone'] [CALENDAR calendar]
  | SET dedup_keep = 'first' | 'last'
  [ON FAIL REJECT | SKIP] [MESSAGE 'text']
```

| Part | Meaning |
|---|---|
| `CHECK (condition)` | a condition on the values of one row, as a `CHECK` constraint. A condition that is `NULL` passes (standard SQL): write `close IS NOT NULL AND close > 0` to refuse a missing price |
| `SESSION ... TO ...` | the row's time, on the clock of `TIME ZONE` (UTC when not given), from the first time to the second (both included). With `CALENDAR`, only on its trading days ([calendars](calendars.md)). The table needs a time column |
| `ON FAIL REJECT` | the default: the statement fails, and nothing of it is written (PostgreSQL code `23514`) |
| `ON FAIL SKIP` | the row is left out and the statement goes on: the answer says `..., 1 left out by rules (ON FAIL SKIP)`. An `UPDATE` that would break the rule is refused instead (a row already there is never left out) |
| `MESSAGE 'text'` | your words in the refusal, before the reason |
| `SET dedup_keep = 'first'` | a row whose DEDUP KEY the table holds already is left out, whatever the write asked (also `INSERT OR REPLACE` and `/write`). `'last'` is the default: the new row replaces the old one. The table needs a `DEDUP KEY` |

- **Rows already there:** a new rule checks rows written from then on. Find older rows that break it with `SELECT ... WHERE NOT (condition)`.
- **Names:** a rule name is unique in the database. `DROP TABLE` drops the table's rules with it.
- **Role:** `ddl`, like `CREATE TABLE`.
- **Not yet:** `SET null_compare` (comparisons with `NULL` as QuestDB does them) is refused with that reason; comparisons follow standard SQL.

**Example: A price guard: the refused row names its rule** (shows an error)

Setup:

```sql
CREATE TABLE ohlc (time TIMESTAMP, symbol SYMBOL, open DOUBLE, close DOUBLE) TIMESERIES(time) PARTITION BY DAY;
CREATE RULE price_guard ON ohlc CHECK (open > 0 AND close > 0) MESSAGE 'prices must be above 0';
```

```sql
INSERT INTO ohlc VALUES ('2026-10-01T05:30:00Z', 'NABIL', 500, 0);
```

Result:

Error: `rule 'price_guard' of table 'ohlc' refused the row: prices must be above 0 (open > 0 AND close > 0 is false for the row open='500', close='0')`

**Example: ON FAIL SKIP leaves the bad row out and keeps the others**

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE, qty DOUBLE) TIMESERIES(time) PARTITION BY DAY;
CREATE RULE no_negative_qty ON ticks CHECK (qty >= 0) ON FAIL SKIP;
```

```sql
INSERT INTO ticks VALUES ('2026-10-01T05:30:00Z', 'NABIL', 500, 10), ('2026-10-01T05:31:00Z', 'NABIL', 501, -3),
  ('2026-10-01T05:32:00Z', 'NABIL', 502, 7);
```

Result:

```text
2 row(s) inserted, 1 left out by rules (ON FAIL SKIP)
```

**Example: Trading hours of NEPSE: 11:00 to 15:00 in Kathmandu, on its trading days** (shows an error)

Setup:

```sql
CREATE CALENDAR nepse_days (TIME ZONE 'Asia/Kathmandu', ERA FROM '2022-01-01' DAYS sun-thu);
CREATE TABLE trades (time TIMESTAMP, symbol SYMBOL, price DOUBLE) TIMESERIES(time) PARTITION BY DAY;
CREATE RULE nepse_hours ON trades SESSION '11:00' TO '15:00' TIME ZONE 'Asia/Kathmandu' CALENDAR nepse_days;
```

```sql
INSERT INTO trades VALUES ('2026-10-01T10:30:00Z', 'NABIL', 500);
```

Result:

Error: `rule 'nepse_hours' of table 'trades' refused the row: its time 2026-10-01T16:15:00 Asia/Kathmandu is outside the session 11:00 to 15:00`

<a id="alter-rule"></a>

## ALTER RULE

Syntax:

```sql
ALTER RULE [IF EXISTS] name ENABLE | DISABLE | RENAME TO new_name
```

A disabled rule stays, and checks nothing until `ENABLE`.

<a id="drop-rule"></a>

## DROP RULE

Syntax:

```sql
DROP RULE [IF EXISTS] name [, name ...]
```

<a id="show-rules"></a>

## See the rules: SHOW RULES

`SHOW RULES` is `SELECT * FROM kdb_rules`: one row per rule.

| Column | Meaning |
|---|---|
| `rule`, `table_name` | the rule and its table |
| `kind` | `check`, `session` or `set` |
| `definition` | what follows `ON table` in its `CREATE RULE` |
| `on_fail` | `reject` or `skip` (empty for a setting) |
| `message`, `enabled` | its message, and whether it is on |

**Example: All rules of the database**

Setup:

```sql
CREATE TABLE quotes (time TIMESTAMP, symbol SYMBOL, bid DOUBLE, ask DOUBLE) TIMESERIES(time) PARTITION BY DAY;
CREATE RULE spread_ok ON quotes CHECK (ask >= bid) MESSAGE 'ask below bid';
```

```sql
SHOW RULES;
```

Result:

| rule (STRING) | table_name (STRING) | kind (STRING) | definition (STRING) | on_fail (STRING) | message (STRING) | enabled (BOOL) |
|---|---|---|---|---|---|---|
| spread_ok | quotes | check | CHECK (ask >= bid) | reject | ask below bid | true |

(1 row)
