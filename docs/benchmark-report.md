# Benchmark report

> How fast KarelaDB is against QuestDB and PostgreSQL on the same PC, and what each engine change of 2026-09-23 gave, including where KarelaDB is still slower and what is not measured.

- Category: Quality
- Keywords: benchmark report, benchmarks, speed, performance, how fast, QuestDB, PostgreSQL, KarelaDB vs QuestDB, KarelaDB vs PostgreSQL, rows per second, p50, latency, result cache, memory footprint, disk footprint, full-text search speed, news search, floor sheet, keyless, table locks, group commit, zone maps, saved stats, column mask, warm at open, A/B, index speed, slow parts, known slow, not measured
- See also: [About KarelaDB](about-kareladb.md), [Test report](test-report.md), [Performance tips](performance-tips.md), [Indexes](indexes.md), [Full-text search](full-text-search.md), [PostgreSQL protocol (port 8832)](postgres-protocol.md), [Limits](limits.md)

Every number on this page comes from a report or result file in the KarelaDB source folder, named under each section. Nothing is rounded beyond what those files say.

Two kinds of measurement are on this page:

- **Head-to-head**: KarelaDB and another database answer the same question on the same PC, and the answers are compared before the times.
- **KarelaDB-only A/B**: the same KarelaDB question before and after one change, the two builds interleaved in the same minutes. These say how much a change gave, not how KarelaDB stands against anyone.

<a id="setup"></a>

## Setup

| Benchmark | Kind | Date | Against | Data | Rounds | Noise |
|---|---|---|---|---|---|---|
| [Time-series](#vs-questdb) | head-to-head | 2026-09-12 | QuestDB 10.0.1, native | 1,000,000 rows, 527 symbols | p50 of many runs, cache off and on | clean machine, just restarted |
| [Time-series re-run](#vs-questdb-0923) | head-to-head | 2026-09-23 | QuestDB 10.0.1 in Docker | 100,000 to 2,000,000 rows | 1 run per size | other work on the PC |
| [Floor-sheet load](#floorsheet) | head-to-head | 2026-09-23 | QuestDB 10.0.1 in Docker | 814,535 real trades | 7 rounds, alternating, medians | 3 s quiet before each load |
| [Floor-sheet queries](#floorsheet) | head-to-head | 2026-09-22 | QuestDB of the 006 app | 1,530,394 real trades, 30 days | 9 runs, `cache=0` | quiet machine |
| [News search](#news-search) | head-to-head | 2026-09-23 | PostgreSQL 18.6 (GIN index) in Docker | 200,000 articles, 378 MB of text | 21 runs per query | a sanitizer build and a fuzz run for the phrase re-run |
| [App workload](#relational) | head-to-head | 2026-09-12 and 2026-09-23 | PostgreSQL 18.4 native; 18.6 in Docker | 20,000 users, accounts, posts; 8 clients | median of 9; 2 interleaved rounds | busy PC both days |
| [PostgreSQL wire](#pg-wire) | head-to-head | 2026-09-12 | QuestDB 10.0.1 | 50,000 rows, 8 clients | median of 9 | busy PC |
| [Indexes](#indexes) | head-to-head | 2026-09-12 | QuestDB 10.0.1 | 1,000,000 posts | 1 complete run | busy PC |
| [Memory and disk](#footprint) | head-to-head | 2026-09-12 | QuestDB 10.0.1 | 1,000,000 minute candles | median of 3 | busy PC |
| [Engine changes](#engine) | KarelaDB-only A/B | 2026-09-23 | the build before | 1,000,000 rows, one thread | 7-round medians, `cache=0` | agents on the PC |

- **Machine:** Intel Core i9-14900HX, 32 threads, 32 GB RAM, Windows 11, the same disk for both databases.
- **KarelaDB:** 0.2.0-dev, Release build, usually `--sync-commits batch` (QuestDB does not flush every commit either).
- **Fair rules:** the same client for both databases, every write timed until the rows can be read back, and row counts and checksums compared so both answered the same question. A benchmark checks `"truncated"`: `/exec` answers at most 10,000 rows unless `limit` is passed.
- **Docker:** on 2026-09-23 the opponents ran in throwaway Docker containers, so every request to them crossed Docker Desktop's network. Their single-request numbers are much lower than on 2026-09-12, when they ran natively. Compare within one day, not across days.

<a id="vs-questdb"></a>

## KarelaDB vs QuestDB: time-series, 2026-09-12

Head-to-head. **Writes** (rows per second, higher is better). The two QuestDB numbers are its results in the cache-off and the cache-on round.

| Test | QuestDB | KarelaDB (cache off) | KarelaDB (cache on) | Result |
|---|---|---|---|---|
| Bulk load, 20,000 rows per request (line protocol) | 865k / 853k | 1.04M | 1.36M | KarelaDB 1.2-1.6x |
| SQL INSERT, 100 rows per request | 6.8k / 8.9k | 144k | 166k | KarelaDB 19-21x |
| One row per request (line protocol) | 10.6k / 11.1k | 11.8k | 13.7k | KarelaDB 1.1-1.2x |
| One row per request (SQL) | 3.3k / 3.2k | 9.4k | 11.6k | KarelaDB 2.9-3.7x |
| Replace 10% of the rows (dedup upsert) | 724k / 698k | 1.17M | 1.14M | KarelaDB 1.6x |
| Parallel load, 8 clients, 8 tables | 2.63M / 3.04M | 3.52M | 4.13M | KarelaDB 1.3x |
| Delete all rows of one symbol | not possible | 3.3 ms | 4.7 ms | KarelaDB only |

**Queries** (p50 milliseconds at the client, including HTTP and JSON; lower is better).

| Test | QuestDB | KarelaDB (cache off) | KarelaDB (cache on) |
|---|---|---|---|
| count + sum, all rows | 0.171 / 0.183 | 0.335 | 0.142 |
| 1 symbol, 1 day (218 rows) | 0.290 / 0.346 | 0.236 | 0.176 |
| 1 symbol, all days to 1h candles | 0.299 / 0.290 | 0.331 | 0.170 |
| All symbols, 1 day to daily candles (527) | 2.88 / 2.99 | 2.36 | 0.475 |
| Latest row per symbol, `LATEST ON` (527) | 0.271 / 0.240 | 0.416 | 0.239 (tie) |
| `GROUP BY symbol`, all rows (527) | 2.78 / 2.58 | 1.50 | 0.850 |
| `ORDER BY volume DESC LIMIT 10` | 0.746 / 1.10 | 0.321 | 0.122 |
| Parallel queries, 8 clients (queries per second) | 817 / 783 | 5,193 | 9,744 |

- **Writes:** KarelaDB won every test, from 1.1x to 21x, and it can delete rows, which QuestDB cannot.
- **Queries with the cache on** (the normal setting): KarelaDB won every test; `LATEST ON` is a tie. It answered 12x more parallel queries.
- **Queries with the cache off** (the engine alone): KarelaDB won 6 of 8. It was slower on `count + sum` over all rows and on `LATEST ON`. (`count + sum` of a whole table is now answered from [saved stats](#engine); not re-measured against QuestDB with the cache off.)
- **First run of a query:** QuestDB 1.0-7.6 ms, KarelaDB 0.43-4.7 ms.

Source: reports/benchmark-vs-questdb.md, bench/results/2026-09-12-clean-cache-off.json, bench/results/2026-09-12-clean-cache-on.json.

<a id="vs-questdb-0923"></a>

## KarelaDB vs QuestDB: time-series re-run, 2026-09-23

Head-to-head, one run per size, QuestDB in Docker, KarelaDB with `--memory 4096` and the harness's default result cache (on). Only the writes are shown: the query lines of these runs are cache hits on the KarelaDB side, and every QuestDB request paid Docker's network.

| Rows per second, 1,000,000 rows | QuestDB | KarelaDB |
|---|---|---|
| Bulk load, 20,000 rows per request (line protocol) | 726,048 | 1,370,726 |
| SQL INSERT, 100 rows per request | 6,830 | 120,228 |
| Replace 10% of the rows (line protocol upsert) | 610,207 | 866,090 |
| Parallel load, 8 clients, 8 tables (line protocol) | 1,598,723 | 4,054,938 |

At 100,000 and 2,000,000 rows the order is the same (bulk load 1,427,713 against 418,983, and 997,864 against 668,739 rows per second). Read this as "KarelaDB's writes did not get slower since 2026-09-12", not as a new margin.

Source: bench/results/2026-09-23-100k.json, bench/results/2026-09-23-1m.json, bench/results/2026-09-23-2m.json.

<a id="floorsheet"></a>

## Floor sheet: KarelaDB vs QuestDB

**Load**, head-to-head, 2026-09-23. 814,535 real trades (15 days), 8 columns with three `SYMBOL` columns, `PARTITION BY DAY`, 20,000 rows per `POST /write`, medians of 7 alternating rounds.

| | QuestDB | KarelaDB | |
|---|---|---|---|
| before: the floor sheet has no `DEDUP KEY`, so KarelaDB wrote it row by row | 686,476 rows/s | 438,373 rows/s | KarelaDB 36% slower |
| after: keyless tables written as runs, 3 s quiet before each load | 677,540 rows/s | **918,067 rows/s** | KarelaDB 35% faster, 6 of 7 rounds won |
| after, no pause between loads | 700,202 rows/s | 814,553 rows/s | KarelaDB 16% faster |
| the candle table (with a `DEDUP KEY`), same day | 726,048 rows/s | 1,370,726 rows/s | KarelaDB 1.9x |

**Queries**, head-to-head, 2026-09-22, in the container on real data (1,530,394 trades over 30 days), `cache=0`, every answer equal to QuestDB's:

| Query | KarelaDB engine | KarelaDB wall | QuestDB | Before (2026-09-18) |
|---|---|---|---|---|
| BUY by stock and broker | 11.9 ms | 19.2 ms | 23.9 ms | 20.0 / 29.0 ms |
| SELL by stock and broker | 13.3 ms | 21.0 ms | 24.1 ms | 19.3 / 28.0 ms |
| BUY + SELL in one (`UNION ALL`) | 118.6 ms | 129.7 ms | 243.9 ms | 1,337 ms against QuestDB's 365 ms |

The `UNION ALL` form went from 3.6x slower to 1.9x faster: each part is now grouped in the column engine before the parts are added up.

Found on the way: QuestDB 10.0.1 lost the first 20,000-row request after a `DROP TABLE` and `CREATE TABLE` of the same name, in 5 of 6 cycles, while answering 204 to it. Benchmarks now use a fresh table name per round.

Source: reports/keyless-runs.md, bench/results/2026-09-23-1m.json, reports/floorsheet-filter-speed.md.

<a id="news-search"></a>

## News search: KarelaDB vs PostgreSQL

Head-to-head, 2026-09-23. 200,000 articles (a title of 8 words, a body of 250 words, 378 MB of text), 21 runs per query. PostgreSQL 18.6 gets its best practice: a stored `tsvector` column with a GIN index, searched with the `simple` configuration (no stemming, like KarelaDB). KarelaDB gets `CREATE FULLTEXT INDEX` on title and body. Top-20 lists are ranked differently by design (BM25 against `ts_rank_cd`), so those are compared on row count only.

| Query | Rows | KarelaDB | PostgreSQL | |
|---|---|---|---|---|
| load 200,000 articles | | 3.9 s (51,514/s) | 49.2 s (4,068/s) | KarelaDB 12.7x |
| build the full-text index | | 2.18 s | 9.07 s | KarelaDB 4.2x |
| common word, count | 182,571 | 3.6 ms | 250 ms | KarelaDB 69x |
| mid word, count | 40,255 | 0.66 ms | 82 ms | KarelaDB 124x |
| two words AND, count | 35,095 | 3.6 ms | 86 ms | KarelaDB 24x |
| prefix `hydro*`, count | 151,463 | 10 ms | 284 ms | KarelaDB 28x |
| rare word, ids | 218 | 0.36 ms | 0.64 ms | KarelaDB 1.8x |
| word + symbol + month | 9 | 0.54 ms | **0.48 ms** | PostgreSQL 1.1x |
| common word, top 20 by rank | 20 | 7.3 ms | 408 ms | KarelaDB 56x |
| mid word, top 20 by rank | 20 | 16.9 ms | 384 ms | KarelaDB 23x |
| two words, top 20 by rank | 20 | 5.5 ms | 364 ms | KarelaDB 66x |
| 8 clients, ranked search | | 348/s | 23/s | KarelaDB 15x |
| common word, all 182,571 ids | 182,571 | 188 ms | 636 ms | KarelaDB 3.4x |
| phrase "hydro power", count | about 2,376 | **9.7 ms** (was 2,347 ms) | 295 ms | KarelaDB 30x |

- Before the fixes of that day, on 20,000 shorter articles, a common-word count took 351 ms in KarelaDB against 2.5 ms in PostgreSQL. Three faults caused it (a planner that dropped the index for common words, `count(*)` fetching every row, `LIMIT` not reaching the index). All three are fixed.
- The phrase line: word positions were added to the index the same afternoon. The 9.7 ms was measured with a sanitizer build and a fuzz run on the PC; a quiet re-run is owed. The phrase counts differ by 3 rows (2,376 against 2,379) because PostgreSQL also finds a phrase across the end of the title and the start of the body.
- `word + symbol + month` is the one line PostgreSQL still wins. KarelaDB now lets the cheaper of the text index and the plain index go first; that is **not measured yet**.

Source: reports/news-search.md (with its addendum), bench/postgres/results/2026-09-23-search-200k-r1.json.

<a id="relational"></a>

## App workload: KarelaDB vs PostgreSQL

Head-to-head. Sign-ups, logins, transfers, forum posts, full-text search and a report join, 20,000 rows, 8 clients.

**2026-09-12**, PostgreSQL 18.4 native, median of 9 runs:

| Test | KarelaDB ops/s | PostgreSQL ops/s | KarelaDB won | Verdict |
|---|---|---|---|---|
| sign-up (user and account, one transaction) | 3,203 | 943 | 9/9 | **KarelaDB faster** |
| login (lookup by unique login) | 11,858 | 10,367 | 5/9 | no clear difference |
| transfer (BEGIN, 3 statements, COMMIT) | 2,696 | 829 | 9/9 | **KarelaDB faster** |
| post a thread (5 posts, one transaction) | 1,322 | 694 | 8/8 | **KarelaDB faster** |
| 8 clients transferring | 1,343 | 4,661 | 0/8 | **PostgreSQL faster** |
| read a thread page (up to 50 posts) | 5,105 | 11,111 | 0/8 | **PostgreSQL faster** |
| forum full-text search (top 20) | 147 | 2,576 | 0/8 | **PostgreSQL faster** |
| report join (users, accounts, transfers) | 19 | 68 | 0/8 | **PostgreSQL faster** |

**2026-09-23**, PostgreSQL 18.6 in Docker, the build before and after the table-locks merge interleaved in the same minutes (master, merged, master, merged). A sanitizer build and a fuzz test ran on the PC throughout.

| Test | KarelaDB before the merge | KarelaDB after the merge | PostgreSQL, same runs |
|---|---|---|---|
| 8 clients transferring | 689 and 604/s | **1,821 and 1,981/s** | 861 to 988/s |
| 8 clients transferring, p50 | 11.7 and 13.5 ms | 4.4 and 4.0 ms | 8.6 and 8.7 ms |
| forum full-text search (top 20) | 2,846 and 2,840/s | 2,673 and 3,177/s | 834 to 923/s |
| read a thread page | 3,664 and 3,071/s | 3,166 and 3,847/s | 875 to 1,310/s |
| report join | 18 and 17/s | 16 and 18/s | 59 to 63/s |

- **Many writers:** table-level write locks and group commit took 8 clients transferring from 604 to 1,981 per second: 3x the build before, 2x PostgreSQL in the same minutes. Balances were conserved in every run.
- **Forum search:** it lost 17x on 2026-09-12. With `LIMIT` pushed into the index it went from 7.16 ms to 0.265 ms per search (PostgreSQL 0.843 ms), and wins about 3x now.
- **Read with care:** PostgreSQL in Docker did far fewer single-client operations than PostgreSQL native on 2026-09-12 (sign-up 123 to 408/s against 943/s). So the single-client lines of 2026-09-23 are left out here; they measure Docker's network as much as PostgreSQL.
- **Report join:** PostgreSQL is still 3.5x faster. That is the join engine (rows are copied three times on the way out).

Source: reports/benchmark-postgres.md, bench/results/2026-09-12-relational-medians.txt, reports/table-locks-merge.md, bench/postgres/results/2026-09-23-locks-master-r1.json, -r2.json, 2026-09-23-locks-merged-r1.json, -r2.json, reports/news-search.md.

<a id="pg-wire"></a>

## PostgreSQL wire protocol: KarelaDB vs QuestDB

Head-to-head, 2026-09-12. A Go client (pgx v5) over the PostgreSQL port, 50,000 rows, 8 clients, 9 runs. A winner is named only when the paired sign test gives p below 0.05 (8 or 9 wins out of 9).

| Test | KarelaDB ops/s | QuestDB ops/s | KarelaDB won | Verdict |
|---|---|---|---|---|
| connect (fresh connection) | 1,431 | 1,583 | 3/9 | no clear difference |
| simple query `SELECT 1` | 14,917 | 12,000 | 5/9 | no clear difference |
| prepared query `id=$1` | 6,331 | 7,834 | 2/9 | no clear difference |
| INSERT 1 row | 12,368 | 13,293 | 4/9 | no clear difference |
| INSERT 1,000 rows in one statement | 104 | 62 | 9/9 | **KarelaDB faster** |
| SELECT 1 row | 6,417 | 6,903 | 2/9 | no clear difference |
| SELECT 500 rows | 3,511 | 3,193 | 5/9 | no clear difference |
| SELECT 50,000 rows | 66 | 79 | 3/9 | no clear difference |
| 8 clients, SELECT 500 | 12,788 | 12,043 | 6/9 | no clear difference |

Eight of nine tests are a tie. A 50,000-row `SELECT` ran at 66 per second over the PostgreSQL port against 25 over HTTP `/exec` (KarelaDB against itself, 9 of 9): the PostgreSQL port sends binary, HTTP builds JSON.

Source: reports/benchmark-postgres.md, bench/results/2026-09-12-pgwire-medians.txt.

<a id="indexes"></a>

## Indexes, and indexes built at open

Head-to-head, 2026-09-12, 1,000,000 forum posts, one complete run, p50 milliseconds. QuestDB has no full-text index, so it answers with `LIKE '%word%'`.

| Query | Rows | KarelaDB no index | KarelaDB with index | QuestDB | Against QuestDB |
|---|---|---|---|---|---|
| lookup `author = x` | 63 | 5.41 | 0.35 | 0.57 | KarelaDB 1.6x |
| range scan `status` + 1 month | 10,708 | 1.74 | 10.76 | 0.26 | QuestDB 42x |
| keyset page 1 | 20 | 1.81 | 281.93 | 12.74 | QuestDB 22x |
| `OFFSET` page 10,000 | 20 | 373.87 | 347.35 | 9.65 | QuestDB 36x |
| search a rare word, top 20 by rank | 20 | 15,091 | 0.49 | 27.35 (no rank) | KarelaDB 56x |
| phrase search | 28,101 | 7,603 | 3,721 | not possible | KarelaDB only |

The full-text lines of this table are from before the search fixes of 2026-09-23; see [news search](#news-search) for today's numbers.

**Indexes built at open**, KarelaDB-only A/B, 2026-09-23. Indexes live in memory and were built by the first query that needed them after a restart. Now `kareladb serve` builds them on a background thread right after the open. First request after a restart, 200,000 posts, 4 indexes, 9 rounds, cache off:

| First request after a restart | Built by the query | Built at open | Warm won |
|---|---|---|---|
| lookup `author = x` | 89.7 ms | 1.5 ms | 9/9 |
| range scan `status` + 1 month | 77.8 ms | 6.7 ms | 9/9 |
| common word, count | 774.4 ms | 3.1 ms | 9/9 |
| all indexes ready after the open | | 685 ms | |

The open itself did not get slower (274 against 291 ms, ranges overlap). One line got slower by direction only: keyset page 1, 23.0 against 26.4 ms, inside the round-to-round spread.

Source: reports/benchmark-indexes-and-footprint.md, bench/results/2026-09-12-indexes-1m-bench3-full.json, reports/warm-at-open.md, bench/results/2026-09-23-warm-restart-r1.json to -r9.json.

<a id="footprint"></a>

## Memory and disk

Head-to-head, 2026-09-12, 1,000,000 minute candles, median of 3 runs. QuestDB's memory is the **whole Java server**, so only its growth is close to fair.

| | QuestDB | KarelaDB `--memory 2048` | KarelaDB `--memory 256` |
|---|---|---|---|
| load (line protocol, timed until readable) | 672,442 rows/s | 842,872 rows/s | 855,944 rows/s |
| disk after a checkpoint | 230.9 MB | 120.3 MB | 164.7 MB |
| memory at start, empty database | 633 MB (whole JVM) | 9.95 MB | 11.1 MB |
| working set after the load | 657 MB | 112 MB | 139 MB |
| peak working set over the run | 1,507 MB (whole JVM) | 229 MB | 231 MB |

Source: reports/benchmark-indexes-and-footprint.md, bench/results/2026-09-12-indexes-and-footprint-tables.txt.

<a id="engine"></a>

## Engine changes of 2026-09-23

KarelaDB-only A/B. 1,000,000 rows, one thread, `?cache=0`, 7-round medians, before and after on the same build, unless the line says otherwise.

| Change | Query or load | Before | After |
|---|---|---|---|
| a trigger on one table no longer slows loads into the others | 20,000-row load into a table without a trigger | 34 ms | 8 ms |
| the same trigger made `DEFERRED` (on the real floor sheet) | 20,000-row load | 103 ms | 9 ms |
| `LIKE` / `ILIKE` / `NOT LIKE` in the column engine | `sym LIKE 'S6%'` | 242 ms | 1.2 ms |
| | `NOT LIKE` | 243 ms | 3.3 ms |
| | `ILIKE` | 230 ms | 2.2 ms |
| `col = a OR col = b` as an IN list | `sum(qty) WHERE sym = 'S1' OR sym = 'S2'` | 151 ms | 0.30 ms |
| | `qty = 7 OR qty = 9` | 115 ms | 12 ms |
| branch-free filters in the column engine | random `LONG x > L` | 4.68 ms | 0.67 ms |
| | random `DOUBLE y > L` | 7.03 ms | 0.62 ms |
| | `b BETWEEN ...` | 8.77 ms | 0.84 ms |
| | `a > X AND b < Y`, on the thread pool | 1.17 ms | 0.49 ms |
| `count`, `sum`, `min`, `max` from saved stats | 4,000,000 rows in 200 day files, after a restart | 99.7 ms, 200 partition loads | 0.28 ms, 0 loads |
| the row path builds only the columns it reads (21-column table) | `count(*) WHERE a * 1 > X` | 460 ms | 210 ms |
| | `ORDER BY ... LIMIT 10` | 554 ms | 268 ms |
| | `GROUP BY` | 549 ms | 242 ms |
| | `SELECT *` (must build every column) | 465 ms | 436 ms |
| manifest keys of dropped tables removed | 300 partitions, one table dropped: manifest size | 1,128 KB | 573 KB |
| | checkpoint | 24.6 ms | 14.7 ms |
| zone maps (814,535 floor-sheet trades, 15 day files, HTTP round trip) | `contract > p99`: 14 of 15 files skipped | 0.93 ms | 0.56 ms |
| | a value above every file: 15 of 15 skipped | 1.66 ms | 0.59 ms |
| | `rate > p99`: nothing skipped | 1.99 ms | 2.15 ms (noise) |
| stop flag read in the scan of unsaved rows (200,000 rows) | a 300 ms timeout | 308.8 s, never stopped | 0.94 s, stopped |
| keyless tables written as runs | floor-sheet load, rows/s | 438,373 | 918,067 |
| table-level write locks + group commit | 8 clients transferring | 604/s | 1,981/s |

Older engine A/Bs: window frames `corr(...) ROWS 199 PRECEDING` 9,536 to 431 ms (2026-09-12); `count(*), sum(volume)` after replaced rows 164 to 44 µs (2026-09-12); the `UNION ALL` buy-and-sell query 1,750 to 29.2 ms on synthetic data (2026-09-22).

Source: TASKS.md "Done 2026-09-23" and "Done 2026-09-23 evening", reports/zone-maps.md, reports/text-fuzz.md, reports/keyless-runs.md, reports/table-locks-merge.md, reports/window-frame-fast-path.md, reports/column-engine-speed.md, reports/floorsheet-filter-speed.md.

<a id="request-time"></a>

## Where the time of one request goes

KarelaDB-only, 2026-09-23 evening, the container on 9900 through Docker Desktop and a native build on Windows loopback, same minutes:

| Path | Round trip |
|---|---|
| the engine alone (server time of `SELECT 1`) | 8-10 µs |
| `/exec` through Docker Desktop | 448-800 µs |
| `/health` (does nothing) through Docker Desktop | 465-685 µs |
| `/exec` on Windows loopback | 48-103 µs |
| a bare Node server on Windows loopback | 49-80 µs |

So the socket path is under 2% of a request through Docker and under 15% on loopback. The rest is Docker Desktop's network and the `/exec` path itself.

Source: TASKS.md, "Re-judged 2026-09-23 evening, measured".

<a id="still-slow"></a>

## Where KarelaDB is still slower, or not measured

| Where | Measured | Source |
|---|---|---|
| joins with `GROUP BY` | report join 16-18/s against PostgreSQL's 59-63/s (2026-09-23) | reports/table-locks-merge.md |
| `SELECT 1` throughput | flat at about 3,000 requests/s with 8 clients (p50 469 to 2,071 µs), while `/health` does about 19,000/s: the ceiling is in the `/exec` path | TASKS.md, HFT item 1 |
| opening a big data folder | 124 to 233 s for 11,104 partitions (9.5 GB): one file open of 10 to 16 ms per partition | TASKS.md, item E |
| more slow statements than HTTP workers | a `SELECT 1` waited 18.6 s behind 12 slow scans on the 8 workers | reports/text-fuzz.md |
| `regexp_like` | 26 to 345 µs per row: 5 to 69 s over 200,000 rows | reports/text-fuzz.md |
| text + cheap filter | `word + symbol + month` 0.54 ms against PostgreSQL's 0.48 ms; the new plan is not measured | reports/news-search.md |
| zone maps on prices | `rate > p99` skips no file: every day holds the top prices | reports/zone-maps.md |
| index choice | an index used where a scan is faster: keyset page 1 1.81 ms without, 281.93 ms with (2026-09-12) | reports/benchmark-indexes-and-footprint.md |
| deep pages | `OFFSET` page 10,000: 347 ms against QuestDB's 9.65 ms (2026-09-12) | reports/benchmark-indexes-and-footprint.md |
| `ORDER BY` over many groups | 377-580 ms on 270,000+ groups against 44-54 ms without the `ORDER BY` | reports/floorsheet-filter-speed.md |
| the outer step of a `UNION ALL` grouping | about 90 ms of the 118.6 ms floor-sheet query runs on the row path | reports/floorsheet-filter-speed.md |
| commit with a flush | 4.8 ms per commit with `--sync-commits always`: the SSD's own flush | reports/performance-and-cache.md |
| not measured | a quiet re-run of the news search after the phrase and planner changes; the contention test on the merged table-locks build; any benchmark on Linux; the numbers on 9900 since the last image rebuild | TASKS.md, reports/news-search.md, reports/table-locks-merge.md |

What changed since the list of 2026-09-12: **many writers at once** (then 1,343 against PostgreSQL's 4,661 transfers/s) and **full-text search** (then 147 against 2,576 searches/s, and a common-word count 11.8x slower than QuestDB's scan) are now KarelaDB wins. They are not on this list any more.

Source: the files named in the table.
