# HFT and low latency

> What was measured and decided about the usual high-frequency-trading engine ideas (kernel bypass, huge pages, JIT, lock-free ingestion, tiered storage), with the round-trip numbers behind each answer, and what KarelaDB is and is not for.

- Category: How it works
- Keywords: HFT, high-frequency trading, low latency, latency, io\_uring, DPDK, kernel bypass, HugePages, huge pages, cache line, false sharing, JIT, query compilation, lock-free, zero allocation, tiered storage, LSM, tick data, nanosecond, ILP, round trip, p50, microseconds, market data, feed handler
- See also: [How KarelaDB works](how-it-works.md), [Benchmark report](benchmark-report.md), [Performance tips](performance-tips.md), [Line protocol (POST /write)](line-protocol.md), [Column types](column-types.md), [Limits](limits.md)

KarelaDB is a time-series and relational database for trading data: candles, trades, order books of a market, accounts. It is **not a tick-to-trade engine** and does not claim to be one. This page records five ideas that high-frequency systems use, what was measured for each on 2026-09-23, and the decision. A decision here means "do it only if the gate on the measurement is met"; nothing was changed on the claim alone.

<a id="round-trip"></a>

## Where a request's time goes

| Path | Round trip |
|---|---|
| The engine alone (server-side time of `SELECT 1`) | 8 to 10 µs |
| `/exec` through Docker Desktop | 448 to 800 µs |
| `/health` (does nothing) through Docker Desktop | 465 to 685 µs |
| `/exec` on Windows loopback | 48 to 103 µs |
| A bare Node server on Windows loopback | 49 to 80 µs |

The network path is under 2% of a round trip through Docker and under 15% on loopback. A query that the engine answers in microseconds is therefore mostly waiting for the connection, not for the database.

One ceiling was found: `SELECT 1` with 8 clients stays flat at about 3,000 requests per second, while `/health` does about 19,000. The limit is in the `/exec` path, not in the sockets. It is listed as open on the [benchmark report](benchmark-report.md).

<a id="ideas"></a>

## The five ideas

| Idea | Decision | Why, with the measurement |
|---|---|---|
| **Kernel bypass** (io_uring, DPDK) | Rejected for io_uring; DPDK only as a customer deployment option | The network share is under 2% via Docker and under 15% on loopback, so the 30% gate cannot be met. io_uring is Linux-only and pays at 100,000 or more requests per second per core. DPDK reads packets from an owned network card and fits a market-data feed handler, which KarelaDB is not: its data arrives as [line protocol](line-protocol.md) over TCP and as HTTP bodies. |
| **Huge pages and cache-line alignment** | Closed, no change | A sequential scan gains under 1% (an 8 MB column is 2,048 page walks against a 180 to 215 ms pass). Only hash tables above about 300,000 groups might gain 3 to 10%, not measured. A false-sharing audit found three per-request cases worth 0.1 to 0.4% of a 0.11 to 0.26 ms round trip, none on the scan path. |
| **JIT query compilation** | Later, behind a gate | The common shapes already run in the vectorised column engine. A JIT would bound the gain at 2 to 2.5 times for narrow row-engine queries and about 1.05 times for wide ones. Widening what the column engine accepts gave 35 to 400 times on the shapes it fixed (for example `LIKE` on a SYMBOL column, 220 to 290 ms down to about 2 ms). A JIT also puts executable memory in the server, which is a security cost. |
| **Zero-allocation, lock-free ingestion** | Refused as stated | Locks are taken per request, not per row. The row builder makes about zero heap allocations per row for SYMBOL and number columns. A throwing allocator would turn a slow path into a crash in a server that also answers queries. Two small clean-ups (long strings, one reserve) are noted as later work. |
| **Tiered storage and LSM merging** | Already the design | The in-memory delta and runs are the hot tier, and partition files, evicted by last use, are the warm tier. Merging of old data is handled by compaction and by answering from saved statistics. |

<a id="offers"></a>

## What KarelaDB offers for tick and market data

- Time-series tables partitioned by day or month, with `SAMPLE BY`, `LATEST ON`, `ASOF JOIN` and candle and indicator functions ([candles-cookbook](candles-cookbook.md), [functions-indicators](functions-indicators.md)).
- Fast ingestion by [line protocol](line-protocol.md) and bulk load, with every commit synced to disk by default ([wal-guarantees](wal-guarantees.md)).
- A result cache, zone maps and saved statistics, so repeated and range queries do not scan everything ([explain](explain.md)).
- `TIMESTAMP` keeps **milliseconds**. Microseconds and nanoseconds are cut, so a tick feed recorded in nanoseconds must keep the exact time in a separate integer column ([limits](limits.md), [column-types](column-types.md)).

<a id="not"></a>

## What it does not offer

- No kernel-bypass networking, no CPU pinning or NUMA control, and no promise of microsecond round trips through HTTP or the PostgreSQL port.
- No co-location or feed-handler component.
- A group commit waits for the disk flush, 4.8 ms per commit on the SSD tested. `synchronous_commit = off` answers sooner and can lose the last few milliseconds in a power cut ([wal-guarantees](wal-guarantees.md)).

Sources are the source folder's task list entries "the peak HFT engine list, judged against the code" and "re-judged, measured", both dated 2026-09-23.
