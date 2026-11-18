# How KarelaDB works

> One page on the design of KarelaDB, covering the files on disk, the log and checksums that protect a commit, how a query is run, how writers and readers share the data, and how copies and clusters work.

- Category: How it works
- Keywords: architecture, system design, design, internals, how it works, storage engine, write-ahead log, WAL, checkpoint, manifest, CRC32C, checksum, block file, partition, zone map, column engine, row engine, vectorised, group commit, table lock, snapshot reads, row lock, MVCC, standby, cluster, witness, failover, recovery, repair, backup, encryption, integrity
- See also: [The log (WAL): what KarelaDB promises](wal-guarantees.md), [On-disk file format (version 1)](file-format.md), [Backup, check, repair and restore](backup-and-safety.md), [Transactions](transactions.md), [Cluster: automatic failover (--cluster-peers, kareladb witness)](cluster.md), [Standby server: a live read-only copy (--standby-of, kareladb promote)](standby.md), [Encryption at rest](encryption.md), [EXPLAIN](explain.md), [Performance tips](performance-tips.md), [HFT and low latency](hft-and-low-latency.md), [Benchmark report](benchmark-report.md)

This page is the map. Each part names the page that has the details. Where something is a **choice you make** (a setting), the page says so. Where a number is given it comes from the measured pages ([benchmark report](benchmark-report.md), [test report](test-report.md)).

<a id="pieces"></a>

## The pieces

| Piece | What it does | Detail |
|---|---|---|
| The log (WAL) | Every change is written to the log first. A change counts as committed when its commit record is on disk. | [wal-guarantees](wal-guarantees.md) |
| Data files | One file per table partition (`PARTITION BY YEAR`, `MONTH`, `DAY`, or no partitioning). They are a faster copy of the log, written by a checkpoint. | [file-format](file-format.md), [partitions-and-dedup](partitions-and-dedup.md) |
| Manifest | A list of the current data files, with two slots so a crash in the middle of a save leaves one whole slot. | [file-format](file-format.md) |
| Checksums | A CRC32C on every log record and every block of every file. | [Checksums](#checksums) |
| Query engines | A column engine for the common shapes, a row engine for the rest. | [Queries](#queries) |
| Locks | A lock per table, row locks on keyed tables, and an option for snapshot reads. | [Writers and readers](#locks) |
| Copies | A standby that follows the log, and a cluster that elects a leader. | [Copies and clusters](#copies) |

<a id="checksums"></a>

## Checksums

KarelaDB uses **CRC32C (Castagnoli)** everywhere it must notice a changed bit:

| Where | What the checksum covers |
|---|---|
| A log record | The record header and its payload. It is checked last, so a search through damaged bytes stays fast. |
| A block of a data file | One CRC per block, stored in a table at the end of the file. The table has its own CRC. |
| A file header and trailer | Each has its own CRC. A manifest slot and a backup segment are checked too. |
| A whole file | A digest (a CRC over the header and the CRC table). The manifest stores the digest and the size of every file, and a file is used only if both match. |
| An encrypted database | The CRC covers the encrypted bytes. Each log record is also authenticated (AEAD), so it cannot be moved or changed without being noticed. See [encryption](encryption.md). |

When a check fails, KarelaDB names the file and block. A damaged data file goes down a **repair ladder**: an older version of the file, then a backup, then the log. An unrepairable log stops the open unless you choose `kareladb repair --accept-log-loss`. See [backup-and-safety](backup-and-safety.md) and [wal-guarantees](wal-guarantees.md).

<a id="commit"></a>

## A commit, in order

1. The change is written to the log as data records and **one commit record**, in one buffer. A change never spans two log segments, and the commit record comes last.
2. The log is flushed (`fsync`). With the default `--sync-commits always`, writers that commit at the same moment share one flush (**group commit**). Each one still waits for its own position in the log.
3. Only then does the client hear "committed".
4. A **checkpoint** later writes the changed tables as new data files, verifies them, flushes the log and folders, saves the manifest, and only then moves the old files to a trash folder.

After a crash the next open reads the log, keeps every change with a complete commit record and drops the rest. Two settings trade safety for speed on purpose (`batch` and `synchronous_commit = off`); [wal-guarantees](wal-guarantees.md) says exactly what each can lose. In every mode the database itself is never damaged by a power cut.

<a id="queries"></a>

## How a query runs

| Step | What happens |
|---|---|
| Plan | `EXPLAIN` shows the plan: which partitions are read, which index is used, which engine runs it ([explain](explain.md)). |
| Skip work | Partitions outside the time range are not opened. **Zone maps** (the minimum and maximum of each column per file and block) skip files and blocks that cannot match a filter. Saved statistics answer `count`, `min` and `max` without reading rows. |
| Column engine | The common shapes (filters, `GROUP BY`, `SAMPLE BY`, some joins) run over columns in chunks of 65,536 rows with a selection vector, using several threads. The sums, minimums and maximums use AVX2 where the CPU has it. |
| Row engine | Shapes the column engine does not take run row by row, on one thread. `EXPLAIN` says `engine: row` so you can see it. |

[performance-tips](performance-tips.md) says how to write queries that stay on the column engine.

<a id="locks"></a>

## Writers and readers

- A writer takes a lock on each table it changes. Writers of **different tables** run at the same time.
- On a table with a primary key, `SELECT ... FOR UPDATE` locks only the rows it returns, and `NOWAIT` and `SKIP LOCKED` work ([transactions](transactions.md#for-update)).
- Readers can be set to read a snapshot, so a long write does not make a `SELECT` wait ([transactions](transactions.md#snapshot-reads), [transactions](transactions.md#per-table-reads)).
- Each database has its own log, so one database cannot slow the commits of another.

<a id="copies"></a>

## Copies and clusters

- A **standby** follows the primary's log, applies whole transactions in order, and refuses writes. It checks the position of the last transaction on every request, so two copies that have drifted apart stop with an error and never mix ([standby](standby.md)).
- A **cluster** adds a witness and elections. A new leader starts a new term and a new log timeline, and an old leader that lost its lease is fenced, so two primaries cannot both write ([cluster](cluster.md)).
- The **change stream** gives the same log per table, exactly once, resumable ([change-stream](change-stream.md)).

<a id="limits"></a>

## What the design does not do

- It does not detect a disk or file system that ignores `fsync`. Every promise above depends on the flush being real.
- It is not a kernel-bypass or JIT engine. See [hft-and-low-latency](hft-and-low-latency.md) for what was measured and what was refused.
- Known limits are on [limits](limits.md).
