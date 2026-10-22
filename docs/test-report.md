# Test report

> How KarelaDB is tested as of 2026-09-23, what each test proves, the real results, and what is not tested yet.

- Category: Quality
- Keywords: test report, tests, testing, quality, QA, crash test, powercut test, power cut, corrupt test, fuzz test, text fuzz, dirty input, pattern denial of service, disk full test, stress test, soak test, ctest, unit tests, console tests, e2e, help examples, tutorial check, Linux build, Docker image, sanitizer, what is not tested
- See also: [About KarelaDB](about-kareladb.md), [Benchmark report](benchmark-report.md), [Backup, check, repair and restore](backup-and-safety.md), [Protection - timeouts, limits, safe updates, read-only](protection.md), [Versions and upgrades](versions.md), [Limits](limits.md)

Every number on this page comes from a report file in the KarelaDB source folder, or from a run named on this page. The file is named at the end of each section. Most runs are from **2026-09-23**; the ones from 2026-09-12 say so.

<a id="summary"></a>

## Summary

| Test suite | What it proves | Latest result | Date |
|---|---|---|---|
| C++ test programs | 56 programs in `CMakeLists.txt`: storage, SQL, server, PostgreSQL, users, indexes, locks, zone maps, disk full | each change ran the programs it touched, all pass; one stale expectation fixed (see [below](#unit-tests)) | 2026-09-23 |
| `crash_test` | a writer killed at a random moment loses no confirmed change | **pass** after every engine change of the day, for example 200 kills and 27,991 confirmed transfers after the table-locks merge | 2026-09-23 |
| `powercut_test` | a power cut, even during recovery, loses no synced change | **pass**: 300 cuts per log mode, 0 repairs | 2026-09-23 |
| `corrupt_test 1000` | damaged files are always found; wrong data is never returned | **pass**: 1,000 rounds, wrong data 0 | 2026-09-12 |
| `test_disk_full` | a full disk loses no committed row, gives a clear error, and writes resume | **pass**: 24 rounds × 3 log modes × 2 fault places; 5 faults found and fixed | 2026-09-23 |
| `test_text_fuzz` | junk text, broken UTF-8 and nasty patterns crash nothing and hang nothing | **pass**: 12,132 statements, 0 crashes, 0 hangs | 2026-09-23 |
| `fuzz_test`, seeds 1 to 5 | broken SQL, line protocol, HTTP and PostgreSQL input crash nothing | **pass** | 2026-09-12 |
| `stress_test`, 20 s and 5 min | many writers, readers, transfers and schema changes at once lose nothing | **pass**: 0 failures | 2026-09-12 |
| sanitizer build | memory and undefined-behaviour errors | one finding in 52 tests (`HmacKey::Mac`), fixed | 2026-09-23 |
| console and HTTP API tests | the web console in headless Chrome, the HTTP API, the help menu, timers, settings | **286 of 287 pass**; the one failure is an out-of-date expectation | 2026-09-23 |
| soak | a real server under steady load | **30 minutes, 0 errors**, every row accounted for | 2026-09-23 |
| help examples | every example in this help runs on a real server | **1,900 examples** in the last full build | 2026-09-22 |
| tutorial examples | every tutorial step gives the saved output | **280 of 280 pass** | 2026-09-12 |
| Linux build and Docker image | the same code and tests on Debian 12 and Alpine | **all pass** | 2026-09-12 |

Source: reports/table-locks-merge.md, reports/keyless-runs.md, reports/zone-maps.md, reports/warm-at-open.md, reports/disk-full.md, reports/text-fuzz.md, reports/soak.md, TASKS.md "Done 2026-09-23", reports/qa-tests.md, docs/help/README.md, reports/tutorial-check.md, reports/linux-build.md, reports/docker-image.md.

<a id="safety"></a>

## Storage safety: crash, power cut, damage

These tests attack the part of a database that loses data: the moment a write is only half done.

| Test | What it does |
|---|---|
| `crash_test` | A child process writes (key-value work and bank transfers). The parent kills it at a random moment. Every confirmed change must be there, nothing unconfirmed, and the totals must be right. |
| `powercut_test` | A fake disk throws away every write that was not synced, as a power cut does, also during recovery. |
| `corrupt_test` | Flips bytes, cuts and deletes files. Damage must always be found and repaired from the previous version or the backup. |

Runs after the engine changes of 2026-09-23 (each change must pass both before it is merged):

| After | `crash_test` | `powercut_test` |
|---|---|---|
| keyless tables written as runs | pass (71 s) | pass (93 s) |
| table-level write locks and group commit | pass: 200 kills, 27,991 confirmed transfers; again on the merged master (90 s) | pass: 300 cuts; again on the merged master (236 s) |
| zone maps | pass | pass |
| indexes built at open, pinned queries | pass: 200 key-value kills, 200 bank kills, 11,128 confirmed transfers | pass: 300 cuts per mode; with batched syncs 45 torn log tails dropped, 0 repairs |

The long runs of 2026-09-12, 1,000 rounds each:

| Test | Result |
|---|---|
| `crash_test 1000` | **pass**: 1,000 kills, 37,843 confirmed transfers, 987 unclean opens |
| `powercut_test 1000` | **pass**: 1,000 cuts, 72,555 confirmed operations, 89 cuts during recovery, 129 torn log tails dropped, 0 repairs |
| `corrupt_test 1000` | **pass**: 1,000 rounds, wrong data 0 (30 minutes) |

**One honest note on power cuts.** With `--sync-commits batch` (a flush every 10 ms) 135 of 300 cuts lost writes that had been confirmed to the client but not yet flushed. That is the trade batch mode makes for speed. `--sync-commits always` loses nothing, at about 4.8 ms per commit on this laptop's SSD. In both modes nothing was ever *wrong*: a write is either there or not, never half applied.

Source: reports/keyless-runs.md, reports/table-locks-merge.md, reports/zone-maps.md, reports/warm-at-open.md, reports/qa-tests.md.

<a id="disk-full"></a>

## A full disk

`test_disk_full` gives the database a fake disk that fills up after a random number of bytes (0 to 30,000), so the fault lands in a commit, a group flush, the start of a log file, a partition file or the manifest. It runs 24 rounds for each of 3 log modes and 2 places of the fault (at the write, or at the flush), about 40 seconds.

Each round: insert until the disk is full (never a crash), check that the count equals the confirmed rows, check that 3 more inserts and a checkpoint are refused and lose nothing, free the space, insert and checkpoint again, then close and reopen: no damage, no repair, the exact count, no abandoned file.

| Log mode | Writes resume without a reopen |
|---|---|
| one flush per commit | 24 of 24 rounds, both fault places |
| batched flushes, fault at the write | 24 of 24 |
| group commit (the default of `kareladb serve`) | 1 of 24: the database stops and must be reopened, by design for now |
| batched flushes, fault at the flush | a known limit: writes confirmed since the last flush are lost, a reopen recovers |

Over HTTP: `/write` answers 204, then 507 `{"code":"disk full"}`; an `INSERT` over `POST /exec` answers 507; a `SELECT` still answers 200 with the right rows; `/health` answers 200. The PostgreSQL port gives SQLSTATE `53100`.

The test found **5 faults**, all fixed: a full disk stopped the store until a restart; a failed start of a log file could leave a file the next open called corrupt; a failed manifest save stopped the store; a clean-shutdown mark was written after a failed flush; half-written partition files were left on the full disk. The real behaviour on a full disk is in [limits](limits.md#disk-memory).

Not done yet: a run on a real full volume (a small virtual disk), not only the fake one.

Source: reports/disk-full.md.

<a id="text-fuzz"></a>

## Dirty text and pattern attacks

`test_text_fuzz` puts junk into a table with a full-text index and searches it: NUL bytes, broken and overlong UTF-8, emoji, Devanagari joiners, 1 MB texts, 256 KB search texts, every query-syntax character. Half the rows go in as SQL text, half as parameters. A statement that reaches the 10 s timeout counts as a hang.

| What | Result |
|---|---|
| statements run | 12,132 |
| errors (all from `regexp_like` with a junk pattern, as expected) | 287 |
| crashes, hangs, timeouts | **0** |
| junk rows found by their clean word | 3,000 of 3,000, and 50 of 50 again after a reopen |
| `LIKE` checked against a simple second matcher | 300,000 random patterns, all agree |
| slowest statement | 3.1 s: `MATCH` with a 256 KB search text |

It also timed patterns that make other databases hang. `LIKE` stays at 1 to 7 µs per row whatever the pattern. The regular expression engine never backtracks, but costs 26 to 345 µs per row, so `regexp_like` over 200,000 rows takes 5 to 69 s.

It found one fault, fixed the same day: rows written since the last checkpoint were scanned without looking at the statement timeout. A 300 ms timeout let an 18.5 s scan run to its end; now the scan stops after 0.94 s.

Source: reports/text-fuzz.md.

<a id="unit-tests"></a>

## SQL and server tests

Each C++ test is its own program, registered in `CMakeLists.txt`: **56 programs**. Five of them are long (`crash_test`, `powercut_test`, `corrupt_test`, `fuzz_test`, `stress_test`), and `test_text_fuzz` takes about 7 minutes.

| Group | Test programs | What they check |
|---|---|---|
| Storage (12) | `test_env`, `test_allocator`, `test_crc32c`, `test_inflate`, `test_crypto`, `test_block_file`, `test_wal`, `test_manifest`, `test_store`, `test_backup`, `powercut_test`, `corrupt_test` | each part of the storage code alone |
| Database (30) | `test_sql_parser`, `test_catalog`, `test_database`, `test_tables`, `test_select`, `test_cross_database`, `test_vector`, `test_ingest`, `test_partition`, `test_windows`, `test_manager`, `test_procedures`, `test_txn_readers`, `test_table_locks`, `test_group_spill`, `test_param_pruning`, `test_symbol_pruning`, `test_zone_maps`, `test_view_pushdown`, `test_indexes`, `test_accounting`, `test_memory_budget`, `test_auto_ids`, `test_result_cache`, `test_analysis`, `test_pg_ddl`, `test_sql_features`, `test_mviews`, `crash_test`, `test_text_fuzz` | SQL, tables, queries, both engines, locks, transactions |
| Server (15) | `test_server`, `test_memory_limit`, `test_ilp`, `test_types`, `test_pg`, `test_users`, `test_protection`, `test_disk_full`, `test_pg_dml`, `test_versions`, `test_timers`, `test_activity`, `test_trigger_jobs`, `fuzz_test`, `stress_test` | the HTTP server, line protocol, PostgreSQL port, users, protection, the memory limit |

Tests that compare two ways of getting the same answer:

| Test | What it compares |
|---|---|
| `test_vector` | 437 queries through the column engine and the row engine, 1 to 8 threads, a tiny memory budget, 8 clients; the column engine ran 390 of them. The text of every value must be equal to 17 digits. |
| `test_zone_maps` | 102 queries with zone maps on and off; the rows must be equal to the last bit, and with maps on never more partitions read. Over the run: 13,390 partitions and 1,655 blocks skipped. |
| `test_indexes` | two databases, one with indexes and one without; every query equal, also after random changes, a replay and while indexes are built at open |
| `test_result_cache` | cached against fresh results after random changes; a pinned result kept and refreshed |
| `test_tables` ("keyless runs") | the same 10,000 rows through three write paths; equal after a power cut, a checkpoint, a restart and a `DELETE` |

**No single run of all 56 programs was recorded on 2026-09-23.** Each change ran the programs it touched (the reports list them), and all passed. Two tests were fixed on the way: `test_trigger_jobs` expected a lookup map that the faster duplicate check no longer needs, and `test_ingest` had a race where a background checkpoint left nothing to replay. The last full short-suite run is from 2026-09-12: 33 of 33 programs passed (there were 33 then).

Source: CMakeLists.txt, reports/zone-maps.md, reports/warm-at-open.md, reports/keyless-runs.md, TASKS.md "Done 2026-09-23 evening", bench/results/2026-09-12-ctest-short.txt.

<a id="console-tests"></a>

## Web console and HTTP API tests

The files in `tests/console/` start a real `kareladb serve` on ports 9930 to 9939 and test the page logic, the HTTP API, and the console in a real headless Chrome. Run on 2026-09-23 with the current `build/bin/kareladb.exe`, one file at a time:

| File | Tests | Pass |
|---|---|---|
| `unit.test.mjs` (page logic) | 69 | 69 |
| `charts.test.mjs` (charts and dashboards logic) | 53 | 53 |
| `api.test.mjs` (HTTP API, many databases, pinned queries) | 60 | 60 |
| `help.test.mjs` (help menu and pages) | 19 | 19 |
| `settings.test.mjs` | 22 | 22 |
| `activity.test.mjs` | 12 | 12 |
| `timers.test.mjs` | 8 | 8 |
| `reported-fixes.test.mjs` | 11 | 10 |
| `write-exec-views.test.mjs` | 6 | 6 |
| `e2e.test.mjs` (browser) | 18 | 18 |
| `dashboard.e2e.test.mjs` (browser) | 9 | 9 |
| **All** | **287** | **286** |

The one failure is `EXPLAIN CALL plans each statement with the real arguments`. The test expects `delete from table px (1 of 3 partitions ...)` for a `DELETE ... WHERE symbol = 'CITY' AND time >= '2026-09-10'`. KarelaDB now says `0 of 3`: the only partition from that day holds no `CITY` row, so it is rightly skipped. The expectation is older than that skip.

Source: runs of `node --test tests/console/<file>` on 2026-09-23, tests/console/README.md.

<a id="fuzz-stress"></a>

## Fuzz and stress

**Fuzz test** (2026-09-12). Valid input is damaged at random and sent to the SQL engine, the line protocol, a running HTTP server and a running PostgreSQL port. Every 100 rounds the servers must still answer, and at the end the database is reopened and checked.

| Seeds | Rounds (SQL / line protocol / HTTP / PostgreSQL) | Result |
|---|---|---|
| 1, 2, 3 | 4,000 / 4,000 / 2,000 / 2,000 | **pass**: no crash, no hang, slowest statement 142 ms |
| 4, 5 (lighter edits that reach the executor more often) | 4,000 / 4,000 / 2,000 / 2,000 | **pass** |

**Stress test** (2026-09-12). At the same time: 4 line-protocol writers, bank transfers over 4 PostgreSQL connections and 2 HTTP sessions with `CHECK (balance >= 0)`, 6 readers checking that the bank total never changes, a thread creating, altering and dropping tables, and 2 query threads.

| Run | Rows written | Transfers | Reads | Schema rounds | Queries | Failures |
|---|---|---|---|---|---|---|
| 20 s | 357,500 | 1,064 | 5,692 | 56 | 3,086 | 0 |
| 5 min | 3,323,000 | 8,539 | 49,897 | 508 | 24,647 | 0 |

**Contention** (2026-09-23, before the table-locks merge): 4 line-protocol writers and 2 SQL writers flat out beside 16 query lanes: no row lost, 0 errors; reads slowed 2 to 3 times at the median, never starved. A 2.1 GB backup under 16 query lanes and 2 writers finished and verified in 7 s, 0 errors.

Source: reports/qa-tests.md, reports/table-locks-merge.md.

<a id="soak"></a>

## Soak

The owner asked for a 48-hour soak. **That has not been done.** Two shorter runs exist.

| | 2026-09-23 | 2026-09-12 |
|---|---|---|
| build | master after the table-locks merge | the code of that day |
| length | 1,826 s (about 30 minutes) | 2,046 s (34 minutes) |
| line-protocol rows written = stored | 19,895,600 = 19,895,600 | 8,738,400 = 8,738,400 |
| SQL rows inserted | 1,362,400 (1,348,540 left after 59 `DELETE` cycles, exact) | 479,350 (474,526 left, exact) |
| queries answered | 64,637 | 23,707 |
| `DELETE` cycles, checkpoints | 59 of 59, 14 of 14 | 67 of 67, 16 of 16 |
| errors | **0** | **0** |
| memory sampled | **no** | yes: 45.7 MB to 1,550 MB while the data grew; 158 to 190 MB per million rows in the second half; no sign of a leak |

The 2026-09-23 run shared the machine with a sanitizer build and a fuzz run. Its memory was not sampled, so the 34-minute run is still the only memory record.

Source: reports/soak.md (and its addendum of 2026-09-23).

<a id="linux-docker"></a>

## Linux and Docker

On 2026-09-12 KarelaDB built and passed every test on Linux in Docker, on the same Windows PC.

| | Linux (Debian 12, g++ 12) | Windows (MinGW ucrt64) |
|---|---|---|
| Build | clean, no warnings, 14.6 s | clean |
| 33 quick tests (all there were then) | all pass | all pass |
| crash, power cut, damage, fuzz, stress | all pass | all pass |

A database made on Windows was opened on Linux, written to there, and read back on Windows. The **Docker image** (Alpine and one static `kareladb` program) passed all 33 tests then, and the help build inside it ran 1,799 examples with 0 failed. The Linux runs have not been repeated since the table-locks, zone-map and warm-at-open work.

Source: reports/linux-build.md, reports/docker-image.md.

<a id="examples"></a>

## Help and tutorial examples

The examples in this help are not pasted text. The help build starts a real server, runs **every** example and fails if an example gives an error it did not expect.

| Check | Result |
|---|---|
| help examples, `node tools/help/build_help.mjs` | **1,900 examples** in 158 topics, last full build 2026-09-22 |
| help coverage, `node tools/help/coverage.mjs` | "Everything has help" (2026-09-12: 408 of 408 functions, 175 of 175 SQL keywords, 28 of 28 HTTP routes) |
| tutorial, `docs/tutorial/examples/verify.ps1` | **280 of 280 pass** (2026-09-12) |

Source: docs/help/README.md, reports/help-coverage.md, reports/tutorial-check.md.

<a id="not-tested"></a>

## Not tested, or not finished

| What | State |
|---|---|
| 48-hour soak with memory sampled from outside | not done; the command is written in reports/soak.md |
| a full disk on a real volume | not done; only the fake disk of `test_disk_full` |
| group commit on a full disk | stops the database until a reopen; changing that is the owner's decision |
| one run of all 56 C++ test programs on the same build | not recorded on 2026-09-23 |
| Linux and Docker runs of the 2026-09-23 code | not done |
| contention test on the merged table-locks build | not done yet (the run above is from before the merge) |
| a real isolation test (read a balance, decide, write) | not done; the balance check only proves the sum is kept |
| `psql \d <table>` from a real psql | not run (no psql on the test PC); every query psql 14 to 16 sends for `\d`, `\d+`, `\dt`, `\di` and `\dv` answers in `test_pg psql_describe` |
| the statement timeout inside one row | not checked: one 16 MB value in a slow regular expression runs to its end |
| more slow statements than HTTP workers | the others wait for a free worker (a `SELECT 1` waited 18.6 s behind 12 slow scans) |

Source: reports/soak.md, reports/disk-full.md, reports/text-fuzz.md, reports/table-locks-merge.md, reports/pg-copy-and-catalog.md, TASKS.md.
