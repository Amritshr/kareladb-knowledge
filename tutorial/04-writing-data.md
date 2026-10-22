# 4. Writing data

- Category: Tutorial

## What you will learn

- How to insert, replace, update and delete rows.
- How to write times, and how KDB stores them (UTC).
- A safe way to fix bad data. (This is the main reason KDB was made.)

The examples use the database `market` with the sample data. They change the data, so run them in order.

## Every change is saved at once

When KDB says `1 row(s) inserted`, the change is already on the disk. There is no `COMMIT` to type. A power cut after that message does not lose the row (chapter 9 explains how).

**One statement is all or nothing.** If an INSERT with 5000 rows has one bad row, **no** row is saved.

## INSERT

Insert many rows in one statement. It is much faster than one statement per row.

```sql
INSERT INTO ochl_day (time, symbol, open, high, low, close, volume) VALUES
  ('2026-09-13', 'CITY', 505.0, 509.0, 503.1, 508.2, 91000),
  ('2026-09-13', 'COAST',  376.0, 379.9, 374.0, 378.5, 120500),
  ('2026-09-13', 'VOLT', 191.0, 194.2, 190.1, 193.7, 64000);

SELECT time, symbol, close FROM ochl_day WHERE time IN '2026-09-13';
```

```text
3 row(s) inserted

time                     | symbol | close
-------------------------+--------+------
2026-09-13T00:00:00.000Z | CITY   | 508.2
2026-09-13T00:00:00.000Z | COAST  | 378.5
2026-09-13T00:00:00.000Z | VOLT   | 193.7
(3 rows, 0.2 ms)
```

- The column list `(time, symbol, ...)` is optional. Without it, give a value for every column in table order (computed columns are skipped).
- Columns you do not list get their DEFAULT value, or NULL.
- Text and times go in single quotes. A `'` inside text is written twice: `'City''s'`.
- Numbers can also be given as text (`'99.5'`). KDB converts them to the column type.

A second row with the same DEDUP KEY `(symbol, time)` is refused:

```sql
INSERT INTO ochl_day VALUES ('2026-09-13', 'CITY', 505.0, 509.0, 503.1, 508.2, 91000);
```

```text
error: a row with symbol='CITY', time='2026-09-13T00:00:00.000Z' already exists in 'ochl_day'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it
```

## INSERT OR REPLACE

The close price for CITY on 2026-09-13 was wrong. Send the full, correct row again:

```sql
INSERT OR REPLACE INTO ochl_day VALUES ('2026-09-13', 'CITY', 505.0, 509.0, 503.1, 507.6, 91000);

SELECT time, symbol, close FROM ochl_day WHERE symbol = 'CITY' AND time IN '2026-09-13';
```

```text
0 row(s) inserted, 1 replaced

time                     | symbol | close
-------------------------+--------+------
2026-09-13T00:00:00.000Z | CITY   | 507.6
(1 row, 0.2 ms)
```

- A new key: the row is inserted.
- A key that exists: the **whole old row** is replaced by the new row. Columns you do not give become DEFAULT or NULL, not the old values. To change only some columns, use UPDATE.

This is the best statement for **imports**: you can run the same import file again and again. You never get double rows.

## INSERT OR IGNORE

Keeps the old row and skips the new one:

```sql
INSERT OR IGNORE INTO ochl_day VALUES
  ('2026-09-13', 'CITY', 1, 1, 1, 1, 1),
  ('2026-09-14', 'CITY', 507.6, 512.0, 506.0, 511.0, 64000);

SELECT time, symbol, close FROM ochl_day WHERE symbol = 'CITY' AND time >= '2026-09-13';
```

```text
1 row(s) inserted, 1 skipped (already there)

time                     | symbol | close
-------------------------+--------+------
2026-09-13T00:00:00.000Z | CITY   | 507.6
2026-09-14T00:00:00.000Z | CITY   |   511
(2 rows, 0.2 ms)
```

## How duplicates are found

| Table | What makes two rows "the same" | Without it |
|---|---|---|
| Relational with `PRIMARY KEY` | the same primary key value | - |
| Relational without a key | nothing | every INSERT adds rows |
| Time-series with `DEDUP KEY (a, time)` | the same values in all DEDUP KEY columns | - |
| Time-series without DEDUP KEY | nothing | every INSERT adds rows, also exact copies |
| Any column with `UNIQUE` | the same value in that column | - |

| Statement | Key is new | Key exists |
|---|---|---|
| `INSERT` | inserted | **error**, nothing is saved |
| `INSERT OR REPLACE` | inserted | old row replaced |
| `INSERT OR IGNORE` | inserted | new row skipped |

Duplicates **inside one statement** are found too: with INSERT OR REPLACE, the last one wins.

## UPDATE

`UPDATE table SET column = value, ... WHERE condition`. The new value can use the old values of the row.

```sql
UPDATE ochl_day SET volume = 95000 WHERE symbol = 'CITY' AND time IN '2026-09-13';

UPDATE live_data SET ltp = round(ltp, 0), point_change = round(point_change, 0) WHERE symbol = 'TELCO';

SELECT timestamp, symbol, ltp, point_change FROM live_data WHERE symbol = 'TELCO';
```

```text
1 row(s) updated

3 row(s) updated

timestamp                | symbol | ltp | point_change
-------------------------+--------+-----+-------------
2026-09-10T05:20:00.000Z | TELCO  | 861 |          -21
2026-09-10T07:15:00.000Z | TELCO  | 869 |          -12
2026-09-10T09:14:00.000Z | TELCO  | 898 |           17
(3 rows, 0.1 ms)
```

**Warning:** `UPDATE ... ` without `WHERE` changes **every row** of the table. Chapter 9 shows how to go back in time after such a mistake.

An UPDATE may change the time or key columns. KDB moves the row. But it refuses to make a duplicate:

```sql
UPDATE ochl_day SET time = '2026-09-13' WHERE symbol = 'CITY' AND time IN '2026-09-14';
```

```text
error: the update would create a second row with symbol='CITY', time='2026-09-13T00:00:00.000Z' in 'ochl_day'
```

Computed columns (`AS (...)`) cannot be set.

## DELETE

`DELETE FROM table WHERE condition`. Without WHERE it deletes every row.

```sql
SELECT count(*) AS rows_before FROM ochl_day WHERE time IN '2026-09-14';
DELETE FROM ochl_day WHERE time IN '2026-09-14';
SELECT count(*) AS rows_after FROM ochl_day WHERE time IN '2026-09-14';
```

```text
rows_before
-----------
          1
(1 row, 0.2 ms)

1 row(s) deleted

rows_after
----------
         0
(1 row, 0.0 ms)
```

**Tip:** before a DELETE or UPDATE, run a `SELECT count(*)` with the **same WHERE**. Check the number. Then run the change.

To empty a whole table, `TRUNCATE TABLE ochl_day` is much faster than `DELETE FROM ochl_day`. The table, its columns and indexes stay; only the rows go.

## DROP PARTITION: delete a whole day, month or year fast

```sql
SELECT count(*) AS rows_2025 FROM ochl_day WHERE time IN '2025';
ALTER TABLE ochl_day DROP PARTITION '2025';
SELECT count(*) AS rows_2025 FROM ochl_day WHERE time IN '2025';
```

```text
rows_2025
---------
       12
(1 row, 0.3 ms)

1 partition(s) of 'ochl_day' dropped

rows_2025
---------
        0
(1 row, 0.0 ms)
```

The name of a partition depends on `PARTITION BY`: `'2026'` (YEAR), `'2026-09'` (MONTH), `'2026-09-10'` (DAY). You can drop many at once: `DROP PARTITION '2026-09-09', '2026-09-10'`. To drop everything older than some time, write `ALTER TABLE ochl_day DROP PARTITION OLDER THAN 1 YEAR`. A table with a TTL does this by itself (chapter 3). If the partition does not exist, KDB lists the ones that do:

```sql
ALTER TABLE ochl_day DROP PARTITION '2024';
```

```text
error: table 'ochl_day' has no partition '2024'; partitions: 2026
```

## Times and time zones

KDB stores every `TIMESTAMP` in **UTC**, in milliseconds. It always shows times in UTC, with a `Z` at the end. Your data may use any local time, such as New York (`-04:00` in summer) or Nepal (`+05:45`). The examples here use Nepal time (NPT, **UTC+05:45**, no daylight saving) for a sample market that opens at 11:00 local time.

| Market event | Nepal time | UTC |
|---|---|---|
| Market opens | 11:00 | 05:15 |
| Market closes | 15:00 | 09:15 |
| Midnight | 00:00 | 18:15 the day before |

You can write a time in several ways:

```sql
CREATE TABLE time_test (time TIMESTAMP, note STRING) TIMESERIES(time) PARTITION BY DAY;

INSERT INTO time_test VALUES
  ('2026-09-10T11:00:00+05:45', 'Nepal time, with +05:45'),
  ('2026-09-10T11:00:00+0545',  'Nepal time, without the colon'),
  ('2026-09-10 05:15:00',       'no zone = UTC'),
  ('2026-09-10T05:15:00Z',      'Z = UTC'),
  ('2026-09-10T05:15:00.250Z',  'with milliseconds'),
  ('2026-09-10',                'only a date = 00:00 UTC'),
  (1789017300000,               'a number = milliseconds since 1970 (UTC)');

SELECT time, note FROM time_test;
```

```text
table 'time_test' created

7 row(s) inserted

time                     | note                                    
-------------------------+-----------------------------------------
2026-09-10T00:00:00.000Z | only a date = 00:00 UTC                 
2026-09-10T05:15:00.000Z | Nepal time, with +05:45                 
2026-09-10T05:15:00.000Z | Nepal time, without the colon           
2026-09-10T05:15:00.000Z | no zone = UTC                           
2026-09-10T05:15:00.000Z | Z = UTC                                 
2026-09-10T05:15:00.000Z | a number = milliseconds since 1970 (UTC)
2026-09-10T05:15:00.250Z | with milliseconds                       
(7 rows, 0.1 ms)
```

The rules:

| You write | KDB reads it as |
|---|---|
| `'2026-09-10T11:00:00+05:45'` | 11:00 Nepal time = 05:15 UTC |
| `'2026-09-10 11:00:00'` (no zone) | 11:00 **UTC** (not Nepal time!) |
| `'2026-09-10T11:00:00Z'` | 11:00 UTC |
| `'2026-09-10'` | 00:00 UTC |
| `1789017300000` | milliseconds since 1970-01-01 UTC |
| More than 3 digits after the second (`.000000`) | only milliseconds are kept |

The format must be `YYYY-MM-DD`. `'10/09/2026'` or `'2026-9-10'` are errors (see chapter 12).

**The most common mistake:** writing Nepal time without `+05:45`. KDB then thinks it is UTC, and the row is 5 hours 45 minutes wrong. **Always add `+05:45` to Nepal times.**

The same rules work in WHERE. Trades between 11:00 and 11:05 Nepal time:

```sql
SELECT time, symbol, close
FROM ochl_minutes
WHERE symbol = 'CITY'
  AND time >= '2026-09-10T11:00:00+05:45'
  AND time <  '2026-09-10T11:05:00+05:45';
```

```text
time                     | symbol | close
-------------------------+--------+------
2026-09-10T05:15:00.000Z | CITY   | 504.4
2026-09-10T05:16:00.000Z | CITY   | 504.6
2026-09-10T05:17:00.000Z | CITY   | 504.2
2026-09-10T05:18:00.000Z | CITY   | 504.4
2026-09-10T05:19:00.000Z | CITY   | 504.5
(5 rows, 0.8 ms)
```

`time IN '2026-09-10'` means the **UTC** day. For the sample market this is fine, because the whole trading day (05:15 to 09:15 UTC) is inside the same UTC day.

## A script stops at the first error

When you send many statements at once (a file, or `a; b; c`), KDB runs them one by one. **Each statement is saved on its own.** At the first error, KDB stops.

```sql
INSERT INTO brokers VALUES (21, 'Test Broker A');
INSERT INTO brokers VALUES (21, 'Test Broker B');
INSERT INTO brokers VALUES (22, 'Test Broker C');
```

```text
1 row(s) inserted
error: a row with id='21' already exists in 'brokers'. Use INSERT OR REPLACE to overwrite it, or INSERT OR IGNORE to skip it
```

```sql
SELECT id, name FROM brokers WHERE id IN (21, 22);
```

```text
id | name         
---+--------------
21 | Test Broker A
(1 row, 0.2 ms)
```

- Statement 1 ran and is saved.
- Statement 2 failed.
- Statement 3 did **not** run.

If many changes must succeed together, put them between `BEGIN;` and `COMMIT;` (chapter 13 and chapter 15). Then an error undoes all of them. Or put them in **one** statement, or make the import safe to repeat with INSERT OR REPLACE.

## Fixing mistakes: a safe workflow

Bad data happens: a wrong file is imported, a price is 10 times too big, a day is loaded twice. QuestDB cannot delete single rows. KDB can. Use these steps.

Example: an import made every COAST minute price on 2026-09-10 ten times too big. (The UPDATE below only creates this "bad import" for the example.)

```sql
UPDATE ochl_minutes SET open = open * 10, high = high * 10, low = low * 10, close = close * 10
WHERE symbol = 'COAST' AND time IN '2026-09-10';
```

**Step 1. Look at the data. Count the bad rows.**

```sql
SELECT count(*) AS rows, min(low) AS min_low, max(high) AS max_high
FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10';
```

```text
rows | min_low | max_high
-----+---------+---------
 236 |    3732 |     3820
(1 row, 0.3 ms)
```

236 rows, and the prices are near 3800 instead of 380. The WHERE is right.

**Step 2. Make a backup.** Then you can always go back.

```powershell
kdb backup market backups
```

```text
backup created and verified: backups/20260923-120922-256
  9 files, 217.4 KB, log up to 52
```

(If `kdb serve` is running, use `BACKUP DATABASE` or the console's **Backup now** button instead. See chapter 9.)

**Step 3. Delete only the bad rows.** Use the same WHERE as in step 1.

```sql
DELETE FROM ochl_minutes WHERE symbol = 'COAST' AND time IN '2026-09-10';
```

```text
236 row(s) deleted
```

The number is the same as in step 1. Good.

**Step 4. Load the correct rows** with INSERT OR REPLACE. (Here only two minutes, to keep the example short.)

```sql
INSERT OR REPLACE INTO ochl_minutes VALUES
  ('2026-09-10T11:00:00+05:45', 'COAST', 380.1, 380.4, 379.8, 380.2, 900),
  ('2026-09-10T11:01:00+05:45', 'COAST', 380.2, 380.5, 380.0, 380.3, 650);
```

**Step 5. Check the result.**

```sql
SELECT time, symbol, open, high, low, close, volume
FROM ochl_minutes
WHERE symbol = 'COAST' AND time IN '2026-09-10';
```

```text
2 row(s) inserted

time                     | symbol | open  | high  | low   | close | volume
-------------------------+--------+-------+-------+-------+-------+-------
2026-09-10T05:15:00.000Z | COAST  | 380.1 | 380.4 | 379.8 | 380.2 |    900
2026-09-10T05:16:00.000Z | COAST  | 380.2 | 380.5 |   380 | 380.3 |    650
(2 rows, 0.3 ms)
```

(The first line, `2 row(s) inserted`, is from step 4.)

If something went badly wrong (for example an UPDATE without WHERE), do not try to fix it row by row. **Restore to the time before the mistake** with `kdb restore --until` (chapter 9).

## Try it yourself

1. Insert a CITY live snapshot for `2026-09-10 14:30` Nepal time with ltp 520.5. Check that it is stored as `08:45` UTC.
2. Make every VOLT daily volume on 2026-09 ten percent bigger. First count the rows.
3. Delete all trade_log trades of broker 34 on 2026-09-09.

<details>
<summary>Answers</summary>

1. ```sql
   INSERT INTO live_data (timestamp, symbol, ltp) VALUES ('2026-09-10T14:30:00+05:45', 'CITY', 520.5);
   SELECT timestamp, ltp FROM live_data WHERE symbol = 'CITY' AND ltp = 520.5;
   ```
   The time is `2026-09-10T08:45:00.000Z`.
2. ```sql
   SELECT count(*) FROM ochl_day WHERE symbol = 'VOLT' AND time IN '2026-09';
   UPDATE ochl_day SET volume = volume * 1.1 WHERE symbol = 'VOLT' AND time IN '2026-09';
   ```
3. ```sql
   SELECT count(*) FROM trade_log WHERE date IN '2026-09-09' AND (buyer = 34 OR seller = 34);
   DELETE FROM trade_log WHERE date IN '2026-09-09' AND (buyer = 34 OR seller = 34);
   ```

</details>

---

Next: [5. Queries](05-queries.md)
