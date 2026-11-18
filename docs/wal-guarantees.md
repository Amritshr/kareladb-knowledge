# The log (WAL): what KarelaDB promises

> What a commit guarantees after a kill, a power cut or a full disk, how the log, checksums, checkpoint and recovery work, and the known limits of the promise.

- Category: How it works
- Keywords: WAL, write-ahead log, log, commit record, LSN, CRC, CRC32C, checksum, fsync, durability, durable, crash, power cut, torn write, torn tail, recovery, checkpoint, manifest, timeline, group commit, sync\_commits, synchronous\_commit, torn end, log cut, archive, wal\_archive, repair, accept-log-loss, ACID, atomic, full disk
- See also: [How KarelaDB works](how-it-works.md), [On-disk file format (version 1)](file-format.md), [Backup, check, repair and restore](backup-and-safety.md), [Performance tips](performance-tips.md), [Cluster: automatic failover (--cluster-peers, kareladb witness)](cluster.md), [Transactions](transactions.md)

Written 2026-10-25 from the code. Byte layouts are in
[the file format](file-format.md) sections 4 to 7; this page says what each rule guarantees. Where
a sentence says "not checked", the code was not traced to the end and the statement is open.

## 1. In one paragraph

Every change is first written to the log as records, and the last record of the change is a
**commit record**. A change is committed when its commit record is on disk, and not before.
After a crash, recovery reads the log, keeps every change that has a complete commit record and
drops the rest. The data files are only a faster copy of the log: a **checkpoint** writes them,
and the **log cut** (moving old segments to `wal_archive/`) happens only when no file needs
those records any more.

## 2. The protocol, step by step

### 2.1 Records and their order

| Rule | What the code does | What it guarantees |
|---|---|---|
| Every record has the next LSN | `next_lsn_` goes up by one per data record and by one for the commit record. A packed record takes as many LSNs as the records it holds. | The log has no holes: the reader expects exactly `previous LSN + 1` and treats anything else as damage or a gap. |
| A change is: data records, then one commit record | `WalWriter::Commit` encodes all records and the commit record into **one buffer**. The transaction id is the LSN of its first record. | A reader sees either the whole change or a change without a commit record, which it does not apply. |
| A change never spans two segments | If `offset + size > 64 MB` (and the segment is not empty), a new segment is started first. | The records of one change are always next to each other. (A change bigger than 64 MB gets a segment of its own.) |
| The commit record comes last | The reader counts the data records of a transaction. A commit is **valid** only if `commit LSN - txn id` equals the number of data records read. | A commit record can never "complete" a change that lost a record in the middle. This is reported as `incomplete transaction`, a lost range. |
| A very big change is streamed | `CommitStream` writes the records a few MB at a time and then the commit record. On an error the segment is cut back to where the change began. | A failed big change leaves the log as it was. |
| Commit time never goes back | `Store::Commit` writes `max(now, last commit time)`. | The log's times are in order, so `--until` and point-in-time restore are well defined. |

### 2.2 Checksums

| Where | What is checked |
|---|---|
| Every record | A CRC32C over the record header (without the CRC field) and the payload. It is checked **last** when the reader looks at a record, so a search through damaged bytes stays fast. |
| A record is accepted only if | type is 1, 2 or 3; `0 < txn id <= LSN`; a commit record has the length the segment's format says (8 bytes, or 16 in a batched segment); the length fits in the file and is at most 256 MB; the CRC matches; **and its LSN is exactly the next one expected**. A record that is valid but has the wrong LSN is not taken. |
| A record of a type this build does not know | Accepted if its checksum is good, then refused as "needs a newer KarelaDB", never as damage. |
| Encrypted database | The CRC covers the encrypted bytes. Each data record is also authenticated (AEAD) with its LSN, transaction id and type, so a record cannot be moved or changed without being noticed. Record headers and commit records stay plain, so recovery finds a torn end the same way. |
| Segment header | 64 bytes with its own checksum; the segment's name must match the first LSN in it, and its owner (timeline) must be one the manifest knows. |
| Data files and manifest | Not part of the log, but the checkpoint depends on them: see 2.5. |

### 2.3 What "committed" means: the three sync modes

The log is a file that is written and then flushed (`fsync`). What a client is told, and when,
depends on the mode. Statements below are for `kareladb serve`; the embedded library has the same
two options (`sync_commits`, `group_commit` in `StoreOptions`; the C API exposes `sync_commits`).

| Mode | How to get it | The client is told "committed" | A crash of the program (kill, out-of-memory kill, `docker rm -f`) | A power cut or operating-system crash |
|---|---|---|---|---|
| **always** (default) | `--sync-commits always` | After the log is flushed to the disk. Writers that commit at the same moment share one flush (group commit); each one still waits for its own LSN to be flushed. | Loses nothing that was confirmed. | Loses nothing that was confirmed. |
| **batch** | `--sync-commits batch` | As soon as the record is written to the log file (handed to the operating system). A background thread flushes at most every `sync_interval_ms` (10 ms). | Loses nothing confirmed: the bytes are in the operating system's cache. | Can lose the commits of the last ~10 ms that were confirmed. The database is **never damaged**: it opens at an older, complete state. |
| **always, with an early answer** | `SET synchronous_commit = off` (one session or one request), `WITH (synchronous_commit = off)` on a table, cache tables and the key-value store's tables | As soon as the record is in the log buffer; `SyncSoon` hands it to the file at most once a millisecond and the flusher thread flushes within about 10 ms. A commit that also changes a table that waits is not answered early. | Can lose the commits of the last few ms (the ones not yet handed to the file, or made while a flush was running). | Can lose about the last 10 ms. |

Facts that hold in every mode:

- The log record is written **before** the change is applied in memory (in the main write path,
  the database code, and in the materialized-view refresh,
  `CommitLog` comes before `ApplyChanges`; the flush wait comes later, at the end of the
  writer), so memory never holds a change the log has no record of, unless the flush itself
  fails (next point).
- A **checkpoint, a backup and `Close` always flush the log first** (`Publish`, `Close` and the
  backup snapshot call `SyncLog`). The manifest therefore never names an LSN that is not on disk.
- If the flush fails for a **full disk**, the writer cuts the segment back to the last durable
  point and keeps working (writes get HTTP 507 / SQLSTATE `53100` until there is room). In group
  commit the rows are already applied in memory and reach the log once space is back; the answer
  says so, and is not "try again" (a client that sent them again would write them twice).
- For any other write or flush error the writer **stops**: later writes fail until the database is
  reopened, and recovery checks the log. A flush error is never ignored, because after a failed
  `fsync` the operating system may have dropped the pages.
- A change too big for memory (`CommitStream`, rows spilled to a temporary file) always waits for
  the disk, whatever `synchronous_commit` says.
- On a cluster leader with synchronous standbys, "committed" also waits for a standby to hold the
  record ([cluster](cluster.md)); if the leader loses its lease while waiting, the
  answer is `Unconfirmed` (the record is on this node's disk, but may be lost).

**Open question (not checked):** whether a reader on another session can see a change in the few
milliseconds between its being applied in memory and the flush, in group-commit mode (the writer
gives up its table locks before the flush so that the next writer can share it). If a power cut
comes then, that change is lost even though a reader saw it; the writer was never told it was
committed.

### 2.4 The log format and the sync mode

A segment written with group commit or `batch` is in the **batched format** (header flag 1):
the commit record carries 16 bytes, the commit time and **the highest LSN that was flushed when
the record was written**. This is what lets recovery tell a torn end from real damage (2.6). A
store that syncs every commit separately (`group_commit = false`, tests and tools) writes the
plain format with 8-byte commit records. A segment is never continued by a store in the other
mode: a new segment starts.

A segment is flushed to the disk before the next segment is created, so **only the last segment
can have a torn end**. The log is written into a file that was filled with zeros ahead of the
records, so a flush writes data only and does not change the file's size on every commit; a zero
byte is never a record type, so a reader stops at the zeros.

### 2.5 Checkpoint

A checkpoint writes the changed tables as new data files, then publishes them
(`Store::Publish`). The order is the guarantee:

1. Each new file is written as a block file with a checksum on every block and a digest over the
   file, and re-read and verified (`verify_on_publish`, on by default).
2. The log is flushed up to the last LSN (`SyncLog`).
3. The folders holding the new files are flushed (`SyncDir`).
4. The manifest is saved. It has two slots (`_manifest.a`, `_manifest.b`) and each save
   overwrites the slot with the **lower** sequence number; the slot being written counts as
   invalid, so a crash in the middle leaves the other slot whole. The manifest records
   `checkpoint_lsn` (every change up to it is in the data files), `durable_lsn` (the log holds
   everything up to it) and, for every file, the LSN it holds.
5. Only after the manifest is durable do the old files move to `_trash/` (after about an hour
   they are deleted), and old log may be archived.

A crash between any two steps leaves either the old manifest (old files, all log intact) or the
new manifest (new files, all verified). Files that no manifest lists are moved to
`_trash/<ms>-unused/` at the next open.

### 2.6 Recovery (what the next open does)

1. Read both manifest slots and use the valid one with the higher sequence number.
2. Load the data files; a damaged one goes down the repair ladder (older version, then backup).
3. Replay starts at `replay_after = min(checkpoint_lsn, LSN of every current file)`. The whole
   log from there is **checked first** and replayed second, so nothing is applied from a log that
   turns out damaged.
4. Every transaction with a valid commit record is applied, in LSN order. Data records with no
   commit record at the end are **not committed**; they are cut off.
5. Torn end versus damage. A bad record in the **last** segment is a torn end (a power cut wrote
   the pages in any order) unless a later valid record proves otherwise: in a plain segment, a
   record of a **newer transaction**; in a batched segment, a **commit record that says the bad
   record was already flushed**. Only then is it damage. A bad record in an earlier segment is
   always damage, because that segment was flushed completely before the next one was made.
6. Damage in a range that is already in the data files is a note only. Damage in records that
   must be replayed is **Corruption**: the open stops with the byte and the LSNs. The ways out
   are a backup (`kareladb restore`), a repair that fills the range from a backup, or
   `kareladb repair --accept-log-loss`.
7. The log writer then continues the last segment from its last valid byte (and drops the torn
   bytes) if that segment is whole, in the current timeline and in the same sync mode; otherwise
   a new segment starts. The manifest is saved with `durable_lsn = last LSN` before the writer
   creates anything.

### 2.7 The log cut

There are four different cuts; they are easy to mix up.

| Cut | When | What is lost |
|---|---|---|
| **Torn tail** | Every open after a crash. | Only an unfinished change (no commit record), or in batch mode, changes whose flush had not finished. Never a change that was flushed. |
| **Archiving** | After a checkpoint. A finished segment moves from `wal/` to `wal_archive/` when the next segment's first LSN minus one is at most `min(checkpoint_lsn, LSN of every current file)`, and no snapshot (backup, change stream, AS OF read) pins it. | Nothing: the segment is only moved. Open never needs it again. |
| **Trimming** | `wal_archive` over its size limit (1 GB per database by default). Oldest archived segments are deleted first, never one the current files need to open. | The ability to repair from an old previous version or restore to a time before it. Repair then uses a backup. |
| **Log loss accepted** | `kareladb repair --accept-log-loss`, after unrepairable damage. The log is cut at the damage and every later segment is deleted. A new timeline starts above every file LSN. | Every change after the damage. The repair names the first and last lost LSN. |

A **timeline** is the log's history. A restore, a repair that cuts the log and a cluster
leader's new term each start a new timeline in a new segment. A segment whose owner is not in
the manifest's history belongs to another database or to a history that was dropped, and is
**never replayed**.

## 3. What is guaranteed, in one table

| Promise | Holds when | Because |
|---|---|---|
| A confirmed commit survives a power cut | `--sync-commits always`, no early answer | The client waits for the flush of its own LSN. |
| A confirmed commit survives a kill of the program | `always` and `batch` | The record is in the operating system before the answer. In the early-answer mode: up to a millisecond of commits can be lost. |
| A change is applied all or nothing | Always | One buffer, one commit record, a record count in the commit check. |
| The database is never damaged by a power cut | All modes | Only the last segment can be torn; recovery drops an unconfirmed tail; data files are published by a manifest swap. |
| Old data files are never deleted before their replacement is durable | Always | The manifest is saved before the old files go to `_trash`. |
| A damaged log is never replayed in part and ignored | Always | The log is scanned completely before replay; unrepairable damage stops the open. |
| A full disk loses nothing that was confirmed | `always` | The segment is cut back to the last durable point; the writer waits for space. |
| Nothing is confirmed after another node may have become leader | Cluster | A fenced store refuses commits (`SetStandby`). |

## 4. Known limits of the guarantee

- `durable_lsn` is saved at a checkpoint and at close, not at every commit. After a crash,
  damage to the very last transactions with no newer valid record after them looks exactly like
  an unfinished write and is dropped ([file format](file-format.md), "Known limit"). In `always` mode those were
  confirmed to clients, so this needs both a crash and damage of the log's last bytes.
- A disk or file system that does not honor `fsync` (some virtual disks, write caches without
  power-loss protection) breaks every promise above. KarelaDB cannot detect it.
- `batch` and the early-answer settings trade durability for speed on purpose; the numbers are
  in [performance tips](performance-tips.md#sync-commits).
- The data folder's own checks (`kareladb check`, scrub) read the log of older segments only
  when asked (`check_all_segments`); a normal open does not read segments that every data file
  already covers.
