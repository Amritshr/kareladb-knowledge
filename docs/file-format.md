# On-disk file format (version 1)

> The byte layout of every KarelaDB file: headers, block files with a CRC per block, the log, the manifest, backups, partition files and indexes, and how each is checked when opened.

- Category: How it works
- Keywords: file format, on-disk format, format version, CRC32C, checksum, block file, header, manifest, WAL record, segment, backup format, partition file, little-endian, LSN, digest, NeedsNewer, stored-format features, corruption, repair ladder, torn tail
- See also: [How KarelaDB works](how-it-works.md), [The log (WAL): what KarelaDB promises](wal-guarantees.md), [Backup, check, repair and restore](backup-and-safety.md), [Versions and upgrades](versions.md)

This spec describes what the Phase 1 code writes. When this file and the code disagree, the code is right.

General rules:

- All integers are **little-endian**.
- `u8/u16/u32/u64` are unsigned integers. `str` is `u32 length` followed by that many bytes, with no terminator.
- CRC means **CRC32C (Castagnoli)**: reflected polynomial `0x82F63B78`, start value `0xFFFFFFFF`, final XOR `0xFFFFFFFF`.
- An LSN (log sequence number) is a `u64` log position. The first LSN is 1. Every WAL record gets the next number.
- Paths stored on disk are relative and use `/`.

---

## 1. Database folder

| Path | What it is | Written by |
|---|---|---|
| `kdb.lock` | Empty file. While the database is open, a process holds an exclusive OS lock on it (`LockFileEx` on Windows, `fcntl(F_SETLK)` on POSIX). A second opener gets `Locked`. | `Store::Open` |
| `_manifest.a`, `_manifest.b` | Two manifest copies ([section 5](#5-manifest)). | `ManifestStore::Save` |
| `wal/` | Live WAL segments ([section 4](#4-write-ahead-log-wal)). | `WalWriter` |
| `wal_archive/` | Old segments that are no longer needed to replay, kept for backups and repair. Oldest segments are deleted when the total size is over `wal_archive_max_bytes` (default 1 GiB; `0` = keep none, `kWalArchiveNoLimit` = keep all). It can change while open (`Store::SetWalArchiveMaxBytes`, from `ALTER DATABASE ... SET WAL_ARCHIVE` or the server's `wal_archive_mb`); a smaller limit trims at once. | `Store::ArchiveOldWal`, `Store::TrimWalArchiveLocked` |
| `files/<name>.v<N>.kdb` | Data file versions (block files, type 3). Never changed after publish. | layer above + `Store::Publish` |
| `_trash/<ms>-<reason>/<rel path>` | Files taken out of use. `<ms>` = Unix ms when moved. Folders older than `trash_keep_ms` (default 24 h) are removed when the database opens. | `Store::TrashFile` |

**Data file names.** `<name>` may contain only `A-Z a-z 0-9 _ - . /`. It is at most 512 characters, has no `..` and no `//`, and does not start or end with `/`. A `/` makes subfolders. `<N>` comes from the manifest's `next_version` counter. There is one counter for the whole database, and it only goes up.

**Trash reasons.** `replaced` (an old version was pushed out by publish or drop), `damaged` (moved away by the repair ladder), `unused` (a file under `files/` that the manifest does not list, found at open), `stale` (a leftover file at a new version path).

**Publish.** The new file is fully verified, its folder is synced, and then the manifest is saved. The old `current` becomes `previous[0]`. Anything past `keep_previous_versions` (default 2) goes to trash. Trashing and WAL archiving wait while a backup snapshot is active.

---

## 2. File header (64 bytes)

Every KarelaDB file starts with this header.

| Offset | Size | Type | Field |
|---:|---:|---|---|
| 0 | 4 | bytes | magic `"KDB1"` |
| 4 | 2 | u16 | format version = `1` |
| 6 | 2 | u16 | file type (see below) |
| 8 | 4 | u32 | header size = `64` |
| 12 | 4 | u32 | block size (block files) or `0` |
| 16 | 8 | u64 | data length in bytes |
| 24 | 8 | u64 | LSN (the contents are complete up to this LSN) |
| 32 | 8 | u64 | id (meaning depends on the type) |
| 40 | 8 | u64 | created, Unix ms |
| 48 | 8 | u64 | owner: for WAL segments, the id of the log history (timeline) that wrote it; 0 for other files |
| 56 | 4 | — | reserved, zero |
| 60 | 4 | u32 | CRC of bytes 0..59 |

A decoder rejects the header (Corruption) if the file is shorter than 64 bytes, the magic is wrong, the CRC does not match, the header size is not 64, or the version is 0. A version above 1 with a good CRC is **NeedsNewer** ("this database needs a newer KarelaDB"), not Corruption ([section 11](#11-stored-format-features-versions)).

| Type | Value | block size | data length | LSN | id |
|---|---:|---|---|---|---|
| WAL segment | 1 | 0 | 0 | first LSN | first LSN (must match the file name) |
| Manifest | 2 | 65536 | payload bytes | `checkpoint_lsn` | manifest `seq` |
| Data file | 3 | chosen by the writer | payload bytes | file LSN | chosen by the writer (not checked) |
| Backup manifest | 4 | 65536 | payload bytes | `end_lsn` | `created_ms` |
| Catalog | 5 | reserved, not written in Phase 1 | | | |

---

## 3. Block file

Data files, manifests and `backup.kdb` use this layout.

| Offset | Size | Content |
|---|---|---|
| 0 | 64 | file header |
| 64 | `D` = data length | data, cut into blocks of `B` = block size bytes. The last block can be shorter. |
| 64 + D | 4 × `n` | CRC table: one u32 CRC per block, in block order |
| 64 + D + 4n | 16 | trailer |

`n = ceil(D / B)`. An empty file has `n = 0` and an empty table. `B` must be between 512 and 67,108,864 (64 MiB). The default is 65536.

**Trailer (16 bytes)**

| Offset | Size | Type | Field |
|---:|---:|---|---|
| 0 | 4 | u32 | block count `n` |
| 4 | 4 | u32 | CRC of the whole CRC table |
| 8 | 4 | bytes | magic `"KDBE"` |
| 12 | 4 | u32 | CRC of trailer bytes 0..11 |

**Checks when opening** (all failures are Corruption): the header is valid; the type is the expected one; the block size is in range; the file size is exactly `64 + D + 4n + 16`; the trailer magic and CRC are good; the trailer block count equals `n`; the table CRC is good. Each block's own CRC is checked when that block is read.

**Digest** = CRC over the 64 header bytes, then continued over the CRC table bytes (`crc32c::Extend`). The manifest stores the digest and the file size for every version. A file is used only if both match. The header contains `created_ms`, so two files with the same data still have different digests.

**Write order**: data blocks, CRC table, trailer, **header last**, truncate to the final size, sync, close. If a crash happens before the header is written, the file fails to open. Only manifest slots are overwritten in place (opened with truncate). All other block files are created new.

Table data files keep one table partition each; their data is described in [section 8](#8-table-partition-files).

---

## 4. Write-ahead log (WAL)

**Segment name**: the first LSN as 20 zero-padded decimal digits, then `.log`. Example: `00000000000000000001.log` (24 characters). Other names in `wal/` are ignored.

**Segment file**: a 64-byte header (type 1), then records one after another. There is no trailer.

**Record** (25-byte header + payload)

| Offset | Size | Type | Field |
|---:|---:|---|---|
| 0 | 4 | u32 | payload length `n` (at most 268,435,456 = 256 MiB) |
| 4 | 4 | u32 | CRC over bytes 0..3 and bytes 8..(25+n−1), which is the whole record except this field |
| 8 | 8 | u64 | LSN |
| 16 | 8 | u64 | transaction id = LSN of the transaction's first record |
| 24 | 1 | u8 | type: `1` data, `2` commit, `3` packed (since 2026-10-02) |
| 25 | n | bytes | payload. For a commit record: u64 commit time in Unix ms (`n = 8`); in a segment written with group commit or `--sync-commits batch` (header flag 1) `n = 16`: the commit time, then the highest LSN that was synced when the record was written. What each rule guarantees: [docs/design/wal-guarantees.md](wal-guarantees.md) |

**Packed records** (type 3, since 2026-10-02; feature `compressed_log`; on unless `KARELADB_WAL_COMPRESS=off`). A commit whose data records hold at least 64 KiB writes them packed: the records are encoded as plain data records (type 1, header and CRC as above, never encrypted), cut at record ends into groups of about 16 MiB, and each group becomes one packed record when that is smaller than writing its records one by one (else they are written as before). A packed record takes the LSNs of the records it holds: its LSN is the first one's, and the next record's LSN is `LSN + count`. Its txn id is the transaction's. Payload (little-endian):

| Offset | Size | Field |
|---:|---:|---|
| 0 | 4 | `count`: data records inside (at least 1) |
| 4 | 4 | raw length: bytes of those records as plain data records (at most 1 GiB) |
| 8 | 4 | block size (1 MiB when written by this KarelaDB) |
| 12 | | the raw bytes in blocks of `block size` (the last one shorter), each `u32` stored length (top bit set: stored as is, else LZ-packed with the column codec's byte packer, `format/column_codec.h`), then the bytes |

The blocks are packed on up to 8 threads at once (at most half the CPUs). A reader unpacks a packed record when its commit is read, and checks every record inside like a record read from the file: LSN equal to the next expected, the transaction's id, type 1, CRC; anything else is Corruption ("does not unpack"). The transaction it hands on has every record unpacked, so replay, standbys, change streams, AS OF and backups see plain records. The commit record is never packed, so torn-tail detection works as before. In an encrypted segment the blocks are packed first, then encrypted: the payload is `count | raw length | block size | nonce 12 B | blocks encrypted | tag 16 B`, with LSN, txn id, type 3 and the 12-byte head as additional data. A build from before 2026-10-02 refuses type 3 as "needs a newer KDB" (builds from before the KarelaDB name, 2026-10-22, say KDB). A store opened with packing off does not continue a last segment that holds packed records: it starts a new segment.

**Transactions and commit**

- A transaction with `k` data records uses LSNs `t .. t+k−1` (all with txn id `t`) and then one commit record with LSN `t+k`. With `k = 0` it is only a commit record whose LSN equals `t`.
- The whole transaction is encoded into one buffer, written with one write, and made durable with **one sync**. "Committed" means that sync has returned. If the write or sync fails, the writer truncates the segment back to where it was before.
- A transaction never spans two segments. If the segment already has records and `offset + size > wal_segment_bytes` (default 64 MiB, minimum 4096), a new segment named after the next LSN is started first. A new segment is created, its header is written, the file is synced, and then the folder is synced.
- Commit times never go backwards: the store uses `max(now, last commit time)`.
- A commit is **valid** only if `txn id ≤ commit LSN` and the number of data records seen for that transaction equals `commit LSN − txn id`.

**Log histories (timelines).** The manifest keeps a list of `(timeline id, first LSN)`, oldest first. Every segment header's `owner` is the timeline that wrote it. A restore, or a repair that cuts the log, adds a new random timeline and always starts it in a new segment. When reading:

- a segment whose owner is not in the list (another database, or a history abandoned by a restore) is **never replayed**: Corruption;
- a segment of timeline `k` may only hold LSNs below the first LSN of timeline `k+1`;
- a gap that ends exactly where a timeline starts is accepted (those records were cut on purpose) and reported as a note.

**Reading** (`ScanWal`). Segments come from `wal_archive/` and `wal/` together, sorted by first LSN. If the same name is in both folders, the `wal/` copy is used. A segment that only holds records ≤ `after_lsn` is not read at all (fast startup), except by scrub. A record is accepted when the type is 1, 2 or 3, `0 < txn id ≤ LSN`, a commit has `n = 8` (`n = 16` in a segment with header flag 1), a packed record has `n ≥ 12` and `count ≥ 1`, `n` fits in the file and is at most 256 MiB, the CRC matches (checked last, so searching damaged data is fast), and **its LSN equals the next expected LSN**.

**Damage rules.** A "lost range" means some LSNs cannot be read. A lost range is only a *note* if every LSN in it is ≤ `after_lsn`: those changes are already in the data files. Otherwise it is **Corruption**, and the scan records the damaged segment and byte offset.

| Situation | Result |
|---|---|
| Bad record, and a valid record with LSN ≥ expected is found later in the same **non-last** segment (searched byte by byte) | **Mid-log damage**: lost range from the expected LSN up to that record, then reading continues from it |
| Bad record in the **last** segment, and a later valid record belongs to a **newer** transaction (txn id > expected LSN) | Mid-log damage (as above) |
| Bad record in the **last** segment, and later valid records (if any) all belong to the same unfinished transaction | **Torn tail**: a power cut wrote pages of the unconfirmed last transaction out of order. The bytes from the bad record on are dropped |
| Bad record, nothing valid after it, and this is **not** the last segment | Lost range up to the next segment's first LSN ("damaged end of segment") |
| Segment header is bad, and this is the last segment with size ≤ 64 bytes | Torn tail (the header never reached the disk; the segment was empty) |
| Segment header is bad (or the type/id does not match the name), last segment, size > 64 | Corruption |
| Segment header is bad, not the last segment | Lost range up to the next segment |
| Gap between segments, or the oldest segment starts after `after_lsn + 1` | Lost range ("missing log segment") |
| A segment's first LSN is below the expected LSN | Corruption ("segments overlap") |
| Segment owner not in the timeline list, or records past the point where its timeline was cut | Corruption (never replayed) |
| Commit record but data records are missing | Lost range `txn id .. commit LSN` |
| Data records with no commit at the end of the log | Not committed. Ignored and cut off as part of the torn tail |

On open, the store also treats "the log ends before `durable_lsn`" as damage (when those records are still needed). When the writer reopens, it truncates the last live segment to its last valid byte and appends from there, but only if that segment belongs to the current timeline; otherwise the tail is cut and a new segment starts. If a write, sync or new segment fails, the writer stops and the store refuses writes until it is reopened (recovery re-checks the log).

**Known limit:** `durable_lsn` is saved at publish and close, not at every commit. Damage to the very last transactions of the log after a crash, with no newer valid record after them, looks exactly like an unfinished write and is dropped.

---

## 5. Manifest

Each slot is a block file of type 2. The header LSN is `checkpoint_lsn` and the header id is `seq`. The payload is:

| # | Type | Field |
|---|---|---|
| 1 | u32 | manifest format = `1` |
| 2 | u64 | `seq` (save counter; must be > 0 and equal to the header id) |
| 3 | u64 | `next_version` (next data file version number) |
| 4 | u64 | `checkpoint_lsn` (every change up to here is in the data files) |
| 5 | u64 | `durable_lsn` (the WAL is known to hold every record up to here) |
| 6 | u64 | `data_ms` (commit time of the newest change the files may contain) |
| 7 | u64 | `db_id` (random, set when the database is created; copied by restore) |
| 8 | u32 | timeline count `T` (decoder rejects `T > 100000`) |
| 9 | `T` × (u64 id, u64 first LSN) | log histories, oldest first; the last one is current |
| 10 | u8 | `clean_shutdown` (1 = closed normally) |
| 11 | u32 | entry count `E` |
| 12 | `E` × entry | entries, sorted by name (byte order) |
| 13 | u32 | meta count `M` |
| 14 | `M` × (str key, str value) | free key/value pairs for higher layers, sorted by key |

**Entry**

| Type | Field |
|---|---|
| str | logical name, e.g. `tables/ochl_day/2026/close` |
| u8 | `damaged` (1 = could not be loaded or repaired) |
| str | `damage_reason` |
| FileVersion | `current` (`version = 0` means there is no current file) |
| u32 | previous count `P` (a decoder rejects `P > 1000`) |
| `P` × FileVersion | previous versions, newest first |

**FileVersion**

| Type | Field |
|---|---|
| str | `path`, relative to the database folder, e.g. `files/kv/shard0.v12.kdb` |
| u64 | `version` |
| u64 | `lsn` (the file holds every change up to this LSN) |
| u64 | `size` (whole file size in bytes) |
| u32 | `digest` (see [section 3](#3-block-file)) |

The decoder must use up exactly every payload byte. Otherwise the slot is Corruption.

**A/B slot rule**

- **Load**: read both slots. A slot is valid if the block file is good, the payload decodes, and `seq == header id ≠ 0`. Use the valid slot with the **highest `seq`**. If a slot is damaged, a note is added and that slot is overwritten by the next save.
  - Neither file exists: this is a new database, unless `files/` or WAL segments exist. In that case it is Corruption ("restore from a backup").
  - Both files exist but neither is valid: Corruption.
- **Save**: the new `seq` must be greater than both slot seqs. The payload is written over the slot with the **lower** seq (a missing or invalid slot counts as 0; if equal, `a` is used). While it is being written that slot counts as invalid, so a crash always leaves the other slot as it was. The folder is synced when a slot file is created.
- Saved: after recovery (`clean_shutdown = 0`, `durable_lsn = last LSN`), on every publish, and on close (`clean_shutdown = 1`).

**WAL retention**: `OpenNeedsWalAfter = min(checkpoint_lsn, lsn of every current version)`. A live segment (not the active one) is moved to `wal_archive/` when the next segment's `first LSN − 1 ≤ OpenNeedsWalAfter`. Archived segments over `wal_archive_max_bytes` (0 = all of them) are deleted oldest first, after a checkpoint, at the end of a backup, and at once when the limit is made smaller; a segment is never deleted while the next segment's `first LSN − 1 > OpenNeedsWalAfter`. Log needed only to repair from a previous version may be deleted (the repair ladder then finds it missing and uses a backup).

**Checkpoint LSN of unchanged files**: when a checkpoint publishes with a full checkpoint LSN `C`, every current version that is not damaged gets `lsn = max(lsn, C)` in the manifest, also files the checkpoint did not rewrite: they had no changes, so they hold every change up to `C`. The LSN in the file header stays the LSN it was written at.

---

## 6. Backups

**Folder layout**

```
<backups-root>/
  20260911-161530-123/          UTC time YYYYMMDD-HHMMSS-mmm (plus "-2", "-3", ... if the name is taken)
    backup.kdb                  backup manifest, written last
    files/<name>.v<N>.kdb       current version of every entry that is not damaged (same relative path)
    wal/<first LSN>.log         log segments needed to replay from those files
  20260912-...-.partial/        unfinished backup: ignored by list/restore, removed by prune
```

**Creating a backup**: take a store snapshot (this pauses trashing and WAL archiving). Copy the data files; with `use_hard_links` they are hard links, and a copy is used if linking fails. Copy the WAL segments, which always are real copies. Only the synced length of the active segment is copied. Segment `i` is skipped when it is not the last one and `segs[i+1].first LSN − 1 ≤ needed_after`, where `needed_after = min(checkpoint_lsn, lsn of every current, not-damaged file)`. Then sync the folders, write `backup.kdb`, and run a full **verify**. Only after that is `<name>.partial` renamed to `<name>` and the root folder synced.

**backup.kdb**: a block file of type 4. The header LSN is `end_lsn` and the header id is `created_ms`. The payload is:

| # | Type | Field |
|---|---|---|
| 1 | u32 | backup format = `1` |
| 2 | u64 | `created_ms` |
| 3 | str | `source_dir` (database folder path at backup time) |
| 4 | str | database manifest, encoded as in [section 5](#5-manifest) |
| 5 | u64 | `end_lsn` (the copied log holds every record up to here) |
| 6 | u32 | segment count `S` |
| 7 | `S` × segment | `str name`, `u64 length` (bytes copied), `u32 crc` (CRC of those bytes) |

**Verify**: `backup.kdb` is readable. Every listed data file opens, its digest matches the manifest, and all its blocks pass their CRC. Every segment's first `length` bytes match `crc`. A scan of the WAL from `needed_after` succeeds and reaches at least `end_lsn`.

**Restore** (to a missing or empty folder):

1. Verify the backup.
2. If `--until` is earlier than the manifest's `data_ms`, refuse: the backup already has newer changes, so an older backup is needed.
3. Create `wal/ wal_archive/ files/ _trash/`, copy the files and segments, and check every copy (digest + blocks, segment CRCs).
4. Optionally (`--logs-from <old database folder>`) roll forward with that database's `wal_archive/` and `wal/`. Its timeline list is used only if it has the same `db_id` and continues the backup's history; if its manifest is unreadable, only segments of the backup's own history are usable. Segments the backup does not have are copied. A segment the backup has is replaced only if the old copy is longer and its first `length` bytes match the backup's `crc`.
5. Scan the log with the timeline checks. Cut it at the `--until` time or at damage/foreign segments: truncate the segment at the cut offset (or delete it if the offset is ≤ 64) and delete all later segments. Trim an unfinished tail.
6. Without `--until`, the log must reach `end_lsn` and every file LSN, else Corruption (a bad copy).
7. Write `_manifest.a` with `seq = 1`, `clean_shutdown = 0`, `durable_lsn = last LSN`, the timelines used, plus a **new timeline** starting at `last LSN + 1`. The log is replayed when the database is first opened.

**Prune**: backups are sorted newest first. Always keep the newest one. Keep the newest backup of each of the last `keep_daily` UTC days and of the last `keep_weekly` weeks (weeks start on Sunday, UTC). Delete the rest. Also delete `.partial` folders whose name sorts before the newest complete backup.

---

## 7. Recovery order and the repair ladder

| Step | Action |
|---|---|
| 0 | Create the folder (unless read-only), lock `kdb.lock`, create `wal/ wal_archive/ files/ _trash/`. Remove old trash folders (unless read-only). |
| 1 | Load the manifest by the A/B slot rule. |
| 2 | `replay_after = min(checkpoint_lsn, lsn of each current, not-damaged file)`. For each entry in name order, load `current`: the file exists, the block file opens as type 3, the size and digest match the manifest, and the state machine accepts it. If this fails with Corruption or NotFound, go down the **repair ladder** (below). Any other error (for example, access denied) stops the open and changes nothing. |
| 3 | **Check the log** with a dry scan from `replay_after` (with timeline checks). It is also damage if the log ends before `durable_lsn` while those records are needed. If there is damage: **(a)** from a *usable* backup (see below): for missing LSNs, copy the backup segments that cover them into `wal_archive/`; for damaged bytes, use the backup's copy of that segment only if its CRC matches, it is longer than the damaged offset, and it is byte-identical to the live segment before the damage; write it plus the live bytes after it to `<segment>.repair` and rename it over the segment (up to 4 tries). **(b)** With `accept_log_loss` (`kareladb repair --accept-log-loss`), truncate at the damage (or delete the segment if the offset is ≤ 64), delete later segments, report the lost LSNs, and start a **new timeline** above every file LSN. New commits are accepted at once. **(c)** Otherwise refuse to open (Corruption). |
| 4 | Replay every valid committed transaction with commit LSN > `replay_after`, in LSN order. Drop the torn tail. |
| 5 | (read-write only) Move files in `files/` that the manifest does not list to `_trash/<ms>-unused/`. |
| 6 | Save the manifest: `clean_shutdown = 0`, `durable_lsn = last LSN`, `checkpoint_lsn = min(checkpoint_lsn, last LSN)`. |
| 7 | Open the WAL writer. It continues the last segment in `wal/` from its last valid byte when that segment is intact and belongs to the current timeline; otherwise it cuts the tail and starts a new segment at `last LSN + 1` (after a log cut or restore, or when the last segment is in the archive). Failing to move unused files to `_trash` is only a note. |

A backup is **usable** for repair only if it has the same `db_id`, its timeline list is a prefix of ours, and — if it was taken on an older timeline — its `end_lsn` is below the point where our history branched off. So a database never repairs itself from another database's backup, or from a backup of a history a restore abandoned.

**Repair ladder for one damaged data file**

| Rung | Try | Condition | On success |
|---|---|---|---|
| a | Previous versions still on disk, newest first | A dry scan from `prev.lsn` must succeed, or fail only at an LSN after the damaged file's LSN (damage there hurts every choice equally). The version must pass the same load checks. | Move the damaged current and any newer previous versions to `_trash/<ms>-damaged/`. That version becomes current. Replay from its LSN. |
| b | *Usable* backups from every `backup_roots` folder, newest first (read-write only) | The entry is in the backup and not damaged there. The backup copy opens, its digest matches, and all blocks verify. Log segments that are not on disk are copied from the backup into `wal_archive/`. A dry scan from the backup file's LSN must pass (same rule as rung a). | If it is the same version and path, the damaged file is trashed and the backup copy is put in its place. If it is older, it gets a new version number and path. Load it, trash the old current and all previous versions, and replay from its LSN. |
| c | Give up on this file only | — | Set `damaged = 1` and the reason in the manifest. Call `StateMachine::OnDamaged`. The rest of the database opens normally. A later open tries the file again. |

When the database is opened read-only (`kareladb check`), rung **a** is tried but nothing is trashed, rung **b** and log patching are skipped, and nothing is written.

---

## 8. Table partition files

One data file per table partition. The logical name is `t/<table id>/<partition>`, where `<partition>` is `2026`, `2026-09`, `2026-09-11` (PARTITION BY YEAR / MONTH / DAY) or `all`. It is a block file of type 3 ([section 3](#3-block-file)): header LSN = the checkpoint that wrote it, header id = table id. The block CRCs protect every byte below; the partition layout adds its own sizes and checks so a file that passes the CRCs but is still wrong (a writer bug, a CRC collision) gives Corruption, never a crash or a huge allocation.

**Format 2** is written since 2026-09-11. Format 1 files (below) are still read. The first u32 of the data tells them apart.

**Header (40 bytes)**

| Offset | Size | Type | Field |
|---:|---:|---|---|
| 0 | 4 | u32 | partition format = `2` |
| 4 | 4 | bytes | signature `"KPRT"` |
| 8 | 4 | u32 | table id |
| 12 | 4 | u32 | column count `k` (at most 100,000) |
| 16 | 8 | u64 | row count `n` |
| 24 | 8 | u64 | data bytes = size of the whole data (header included); must equal the block file data length |
| 32 | 4 | u32 | flags: bit 0 = a column stats section follows the column sections (always set since 2026-09-12); bit 1 = the sections are **packed** (since 2026-09-25, below). A reader refuses unknown flags. |
| 36 | 4 | u32 | CRC of header bytes 0..35, continued over the `k` column entries |

**Column entry (40 bytes each, `k` of them: the stored columns in table order)**

| Offset | Size | Type | Field |
|---:|---:|---|---|
| 0 | 4 | u32 | column id |
| 4 | 1 | u8 | column type: 0 BOOL, 1 BYTE, 2 SHORT, 3 INT, 4 LONG, 5 FLOAT, 6 DOUBLE, 7 DECIMAL, 8 DATE, 9 TIMESTAMP, 10 SYMBOL, 11 STRING, 12 JSON, 13 BYTES, 14 DECIMAL128, 15 UUID (12 and 13 since 2026-09-11, 14 since 2026-09-25, 15 since 2026-10-02; written only for tables that have such columns; older builds refuse the file as "unknown column type") |
| 5 | 3 | — | reserved, zero |
| 8 | 8 | u64 | null bytes: `0` = the column has no NULL (section left out), or `n` |
| 16 | 8 | u64 | value bytes |
| 24 | 8 | u64 | dictionary length bytes |
| 32 | 8 | u64 | text bytes |

**Sections** follow the entries directly, without padding:

1. row ids: `n` × i64
2. then for each column entry, in entry order: null flags (`n` × u8, 1 = NULL; only when null bytes = `n`), values, dictionary lengths, text:

| Type | value bytes | dictionary length bytes | text bytes |
|---|---|---|---|
| BOOL (0/1), BYTE, SHORT, INT, LONG, DECIMAL (scaled integer), DATE (days), TIMESTAMP (ms UTC) | `8n`: i64 per row | 0 | 0 |
| FLOAT, DOUBLE | `8n`: IEEE-754 double per row | 0 | 0 |
| SYMBOL | `4n`: u32 dictionary index per row | `4d`: u32 length of each of the `d` dictionary values | the `d` values, one after another |
| STRING, JSON, BYTES | `4n`: u32 length per row | 0 | all row values, one after another (JSON: normalized JSON text; BYTES: the raw bytes, zero bytes included) |

3. with flag bit 0: **column stats**, one 80-byte entry per column entry, in entry order:

| Offset | Size | Type | Field |
|---:|---:|---|---|
| 0 | 8 | u64 | non-NULL rows (at most `n`) |
| 8 | 1 | u8 | 1 = a FLOAT/DOUBLE value is NaN, else 0 |
| 9 | 7 | — | reserved, zero |
| 16 | 8 | i64 | integer-backed types (BOOL as 0/1, integers, DECIMAL scaled, DATE, TIMESTAMP): min of the non-NULL values |
| 24 | 8 | i64 | ... max (min ≤ max when there is a non-NULL row; both 0 otherwise) |
| 32 | 16 | u64 low, i64 high | ... exact sum as a 128-bit integer |
| 48 | 8 | f64 | FLOAT/DOUBLE: min of the non-NULL values that are not NaN, taken in row order where only a strictly smaller value replaces the current one (+inf when none) |
| 56 | 8 | f64 | ... max, the same way (−inf when none) |
| 64 | 16 | f64, f64 | ... compensated (Neumaier) sum `s`, `c` of every non-NULL value in row order; the sum is `s + c` |

Fields that do not apply to the column's type are 0 (or the ±inf above). They let a reader answer count/sum/min/max and skip blocks by value range without reading the rows. A file without the flag (older) gets its stats counted when it is loaded; so does a table column the file does not have.

A NULL row still has its value slot (0, or an empty text). Each section is one raw little-endian array: on little-endian CPUs (x86, ARM64) it is written straight from the column's memory and read straight into it, one copy each way. A big-endian CPU swaps the bytes.

**Checks when loading** (all Corruption): format is 1 or 2; signature; `k` and `n ≤ data length / 8`; header CRC; table id; data bytes = block file data length; no unknown flag; known type and zero reserved bytes; null bytes is 0 or `n`; value, dictionary and text bytes fit the type (table above); every section fits in the bytes still left, checked **before** anything is allocated or read; the sections end exactly at the end of the data; dictionary and string lengths add up to the text bytes; every SYMBOL index is below the dictionary size; a stats entry has non-NULL rows ≤ `n`, a NaN flag of 0 or 1, zero reserved bytes and min ≤ max; the rebuilt storage keys are strictly increasing.

**Columns** are matched to the table by column id **and** type. A file column the table no longer has (DROP COLUMN, or a type that no longer matches) is skipped without being read. A table column the file does not have (ADD COLUMN) gets the column's DEFAULT, else NULL.

**Storage keys are not stored.** Load rebuilds them from the key columns (plus the row id when the table has no unique key), with the same encoding as `AppendKeyPart`, and checks that they are strictly increasing. Measured on a 400,000-row month of minute candles: storing the keys made the file 45% bigger (34.8 MB instead of 24.0 MB) and the write 1.5x slower, and the load was not faster (15.4 ms instead of 15.5 ms), because reading and checking 10.8 MB more costs as much as rebuilding them. Keys rebuilt from checked columns also can never disagree with the columns.

**Packed files** (flag bit 1, since 2026-09-25; feature `column_compression`). A table with `compression = on` has its **sealed** partitions written this way: every partition whose time bucket (the part before any `/`) is older than the table's newest one. A table without time partitions has none. The header, column entries and stats section are exactly as above; the sections between them hold the same numbers through the column codecs, and the entry sizes are the packed sizes:

1. row ids: u64 byte count, then an integer stream of `n` values
2. per column entry: null flags as an integer stream of `n` values (only when null bytes > 0); values as an integer stream (two streams, low words then high words, for DECIMAL128 and UUID), a double stream, or for SYMBOL a stream of `n` indexes and for STRING/JSON/BYTES a stream of `n` lengths; for SYMBOL a dictionary section of u32 entry count `d` and a stream of `d` lengths; the text as a byte stream

An **integer stream** is chunks of 1,024 values (the last one shorter), each starting with a u8 form: `0` raw (i64 each); `1` frame: i64 base, u8 width `w` ≤ 56, then each value − base in `w` bits, low bits first; `2` delta: i64 first value, i64 smallest step, u8 width, then each step − smallest step in `w` bits; `3` runs: u16 run count, i64 base, u8 width, the run values − base, u8 width, each run length − 1. Arithmetic wraps like the CPU's. u32 and u8 arrays are widened to i64 and must fit again when read. A **double stream** is chunks of 1,024: `16` raw (IEEE bits); `17` decimal: u8 scale `s` ≤ 9, then an integer chunk of `k`, the value being `k / 10^s` (written only when every value of the chunk reads back bit for bit, so never for NaN, infinities or −0.0); `18` XOR: u64 bits of the first value, u8 shift `z`, then an integer chunk of each value's bits XOR the previous value's, shifted right by `z`. A **byte stream** is blocks of up to 1 MB: u8 form (`32` as is, `33` LZ), u32 bytes it holds, u32 bytes stored, the bytes; LZ is sequences of token (literal count << 4 | match length − 4, 15 = more length bytes of 255 follow), literals, u16 offset back, more match length; the last sequence has literals only.

Every chunk picks the smallest form for its own values. Every decoder checks each length against the bytes it was given and must end exactly at the end of its section (Corruption otherwise); `n` must be at most (data bytes / 10 + 1) × 1,024. Load decodes packed sections into the same arrays a raw file fills, so nothing after the load sees a difference. A packed partition written again (a change, `SET (compression = off)` and `COMPRESS TABLE`, or `kareladb downgrade`) follows the table's setting then.

**Tail files** (since 2026-10-02; feature `partition_tails`; `kareladb serve --tail-files on`). Rows appended after the last storage key of a partition may be saved in a **tail**: a normal partition file (format 2, never packed) of just those rows, under its own manifest entry `t/<id>/<partition>.tail<k>.b<v>`, where `k` = 1, 2, ... counts the partition's tails and `v` is the version number of the partition file the tail extends. A partition's saved rows are its file's rows followed by those of each tail in `k` order; every tail's first key must be above the last key before it (Corruption otherwise). A tail whose `v` is not the version of the partition file the reader uses (a repair or a read `AS OF` chose another one) is not read; the log is replayed from that file's LSN instead, and the next checkpoint writes the partition whole. Writing a partition whole drops all its tails. The manifest meta `rows.<partition file>` counts the file and its tails, and `sym.<partition file>` (still naming the file) summarizes them all; `lastkey.<partition file>` = `<file path>|<tail count>|<hex of the last storage key>` lets a checkpoint tell new rows from old without reading the file (ignored when the path or count differ). The partition file's manifest LSN is raised with every checkpoint like any unchanged file's; a read `AS OF` takes the header LSN of the file and of each tail for such a partition, not the point, and replays the log from there.

**Delta files** (since 2026-10-02; feature `partition_deltas`; on unless `KARELADB_NO_PARTITION_DELTA=1`). A checkpoint of a partition whose changes since its file was written whole (replaced, updated, new and deleted rows) are at most 1/16 of its rows may save them in a **delta** instead of writing the partition: one manifest entry `t/<id>/<partition>.delta.b<v>` per partition, `v` = the version of the partition file it applies to; each such checkpoint writes a new version of that entry holding all the changes so far. Its data (inside the block file) is little-endian: `u32` 0x4C44504B ("KPDL"), `u32` format 1, `u64` row count of the file and tails it applies to (checked on read: Corruption when they hold another count), `u64` n, n deleted storage keys (`u32` length + bytes, strictly increasing), `u64` length + the rows it adds or replaces as partition bytes (format 2, unpacked; 0 = none). A reader takes the file's rows, then its tails', drops every row whose key is deleted or replaced, and merges in the delta's rows in key order; deleted and replaced keys never overlap. A delta whose `v` is not the version of the partition file the reader uses is not read, like a stale tail, and the next checkpoint writes the partition whole. Writing a partition whole drops its delta; a checkpoint does so (compaction) when the delta file passes 1/8 of the bytes of the partition file and its tails, or when the delta bytes written since the last whole write pass them; that running total is the manifest meta `deltaw.<partition file>` = `<delta entry name>|<bytes>` (ignored when it names another delta). No tail is added while a partition has a delta (new rows go into the delta). `rows.<partition file>` and `sym.<partition file>` describe the rows with the delta applied; `lastkey.<partition file>` is empty. A read `AS OF` groups a delta with its partition file like a tail.

**Format 1** (written before 2026-09-11): u32 format = `1`, u32 table id, u64 row count `n`, u32 column count; per column u32 column id and u8 type; `n` × u64 row ids; then per column `n` × u8 null flags followed by the values: u64 per row for BOOL/integers/DECIMAL/DATE/TIMESTAMP, u64 IEEE bits per row for FLOAT/DOUBLE, `u32 d` + `d` × `str` + `n` × u32 index for SYMBOL, `n` × `str` for STRING. The whole data must be used. A format 1 partition is written again as format 2 the next time a checkpoint changes it.

## 9. Table log records

Each WAL data record of a database starts with a u8 type. `str` = u32 length + bytes. A record whose table no longer exists is skipped. Replay applies a change only to a partition whose file LSN is below the commit LSN.

| Type | Payload after the type byte |
|---|---|
| `'D'` | `str` normalized SQL of a schema change (also views and routines) |
| `'U'` | u32 table id, then one row: u64 row id, u32 stored column count, per column u32 column id, u8 type, u8 null flag, and when not NULL the value (u8 BOOL, u64 IEEE bits FLOAT/DOUBLE, `str` SYMBOL/STRING/JSON/BYTES, u64 other types). Type codes as in [section 8](#8-table-partition-files). A `'V'` record also ends after about 64 MB of text, so big values never make a record over the 256 MiB limit |
| `'V'` | u32 table id, u32 row count, then that many rows as in `'U'` |
| `'K'` | u32 table id, `str` partition, `str` storage key: a delete |
| `'C'` | u32 table id, `str` partition, then a **run**: the rest of the record is a partition in format 2 ([section 8](#8-table-partition-files): header, row ids, column sections), rows sorted by storage key, one row per key |

A run holds upserts of one partition that need no lookups (an `InsertRows` upsert, as sent by the line protocol, into a table whose unique key decides where a row is stored and without REFERENCES/UNIQUE/AUTO columns). Written from the column arrays in one go, it is much cheaper than a `'V'` record, and replay loads it back as columns (same checks as a partition file; columns matched by id and type, added columns get their DEFAULT). A transaction writes a table's `'U'`/`'V'`/`'K'` records before its `'C'` records: runs are newer than the other changes of the same partition.

## 10. Indexes (CREATE INDEX)

**Only the definition is stored.** There is no index file, no manifest entry and no log record of index data. An index is built in memory from the table's rows when it is first needed after the database opens (a query, a UNIQUE check, `search_rank`), or when `CREATE INDEX` runs. After that, every change of a row (`Apply*` calls, rollbacks, log replay) is applied to it. So `kareladb check`, `kareladb repair`, backups and restores have nothing to check for indexes, and an index can never be old or damaged after a crash.

**Catalog part `'I'`** (in the catalog's format 2 part list, after `dedup_key`; a table without indexes has no `'I'` part):

| Type | Field |
|---|---|
| u32 | index part format = `1` |
| u32 | index count `n` |
| `n` × index | `str` name, u8 kind (`0` INDEX, `1` UNIQUE, `2` FULLTEXT), u32 column count `c`, `c` × u32 column id |

Columns are stored by column id, so `RENAME COLUMN` and `RENAME TABLE` need no change. A decoder refuses (Corruption) an unknown part format, an unknown kind, counts larger than the bytes left, or bytes left over. The catalog check also refuses a missing column, a computed column, a column listed twice, more than 16 columns, a FULLTEXT index on a column that is not STRING/SYMBOL/JSON, and two indexes of one table with the same name.

**Log.** `CREATE [UNIQUE | FULLTEXT] INDEX name ON table (columns)` and `DROP INDEX name` are `'D'` records ([section 9](#9-table-log-records)), replayed like other schema changes.

**Older KarelaDB builds.** A build that does not know catalog format 2 refuses the catalog ("format version 2 is not supported"). A build that knows format 2 but not part `'I'` refuses it ("a part this KarelaDB build does not know (tag 73); open the database with a newer KarelaDB"). A build that does not know the SQL `CREATE INDEX` fails to replay such a `'D'` record and refuses to open. No older build opens a database with an index and then ignores it (for example, writes duplicates into a UNIQUE index).

**ENUM types: catalog format 3** (`CREATE TYPE name AS ENUM (...)`, 2026-09-25). Written only while the database has an ENUM type; it is format 2 plus this section after the last table:

| Type | Field |
|---|---|
| u32 | section format = `1` |
| u32 | next type oid (the first is 700000000) |
| u32 | type count `n` |
| `n` × type | `str` name, u32 oid, u32 label count `k`, `k` × `str` label (in sort order) |

A column of such a type is a SYMBOL (type code 7) whose part `'T'` spelling is `ENUM:` + the type's name; the catalog links it to the type when it is read, and refuses (Corruption) a column whose type is missing. `CREATE TYPE`, `ALTER TYPE ... ADD VALUE` and `DROP TYPE` are `'D'` records, replayed like other schema changes. A build without the `enum_types` feature refuses such a database at open (NeedsNewer); one that reads catalogs only up to format 2 refuses format 3 the same way.

**Trading calendars: catalog format 4** (`CREATE CALENDAR name (...)`, 2026-09-25). Written only while the database has a calendar; it is format 3 (the ENUM section is always there, maybe with no types) plus this section after it:

| Type | Field |
|---|---|
| u32 | section format = `1` |
| u32 | calendar count `n` |
| `n` × calendar | `str` name, `str` time zone (`""` = UTC), u32 era count `k`, `k` × (u64 first day, u8 weekdays: bit 0 = Sunday), u32 day count `m`, `m` × (u64 day, u8 `1` = extra trading day / `0` = holiday, `str` note) |

Days are days since 1970-01-01, sorted, one entry per day; eras are sorted by their first day. The reader checks the order, the weekdays (never 0) and the zone, and refuses anything else as damage. `CREATE`, `ALTER` and `DROP CALENDAR` are `'D'` records, replayed like other schema changes. A build without the `calendars` feature refuses such a database at open (NeedsNewer); one that reads catalogs only up to format 3 refuses format 4 the same way.

**Entries in memory** (for developers): a plain index entry is the key parts of the indexed columns (`AppendKeyPart`, so byte order is value order, NULL first), then the row's partition name as a text key part, then its storage key. Entries are kept in one sorted array plus a small tree of changes. A full-text index keeps, per word, a list of (document, count) pairs as varints, and per document its place and word count.

## 11. Stored-format features (versions)

**Rule:** a newer KarelaDB reads everything an older KarelaDB wrote. An older KarelaDB refuses what a newer KarelaDB wrote with status **NeedsNewer** (`Code::kNeedsNewer`, message `this database needs a newer KarelaDB: ...`, or `this database needs a newer KDB: ...` from a build before the KarelaDB name (2026-10-22), `kareladb` exit code 3), never Corruption, so no repair ladder, trash purge or manifest save starts.

**Feature list.** Manifest meta key `features`, value `v1:` followed by feature names joined by `,` (sorted). A value that does not start with `v1:` is NeedsNewer. A new database gets `v1:` at once. A database written before feature lists has no key: it opens as before, the database layer works out its features (catalog, manifest entries and meta, replayed log records, sync mode) and saves the list in the next checkpoint's manifest.

**Check at open** (`Store::Recover`, right after the manifest is loaded, before old trash is purged or any file is read): every name must be in this build's table, else NeedsNewer. Backups: `VerifyBackup` and `RestoreBackup` check the backup's manifest the same way, before copying.

**Recording.** A feature is saved in the manifest before the first data that needs it (`Store::RecordFeatures` saves a manifest with only the list changed), or in the same manifest save as that data (checkpoint). The list only grows, except by `kareladb downgrade` (below).

"Since" is the build that first writes the **name**. A build before that date refuses a database whose list has the name.

| Feature | Since (0.2.0-dev) | Stored change | Recorded |
|---|---|---|---|
| `views` | 2026-09-10 | `views` file | before `CREATE VIEW` is logged |
| `partition_format_2` | 2026-09-11 | partition files format 2 ([section 8](#8-table-partition-files)) | checkpoint that publishes partition files |
| `block_stats` | 2026-09-11 | partition flag bit 0, stats section | same |
| `runs` | 2026-09-11 | log record `'C'` | before the first commit with a `'C'` record |
| `auto_meta` | 2026-09-11 | manifest meta `auto.<table id>` | checkpoint that writes it |
| `json`, `bytes` | 2026-09-11 | column type codes 12, 13 (catalog, partition files, log rows) | before the schema statement is logged |
| `check` | 2026-09-11 | catalog format 2, part `'C'` | same |
| `indexes` | 2026-09-11 | catalog part `'I'` | same |
| `routines` | 2026-09-11 | `routines` file | before `CREATE FUNCTION/PROCEDURE/TRIGGER` is logged |
| `users` | 2026-09-11 | `_system` table `users` | before the table is made (in `_system`) |
| `batched_log_sync` | 2026-09-11 | log segments in the batched format: header flag `kWalFlagBatchedSync` (1), commit records of 16 bytes (commit time, then the highest LSN synced when it was written; [section 4](#4-write-ahead-log-wal)). Group commit (the default since 2026-09-23) and `--sync-commits batch` write it, so every database a newer KarelaDB opened has it | manifest saved by recovery, before the first batched segment |
| `audit` | 2026-09-12 | catalog part `'A'`, log record `'P'`, `_audit_log` table | before `SET AUDIT ON` writes anything |
| `table_grants`, `totp` | 2026-09-12 | columns `table_grants`, `totp` of `_system` table `users` | before the column is made (in `_system`) |
| `row_policies` | 2026-10-02 | `_system` table `row_policies` (one row per policy: key, database, table_name, name, commands, roles, using_sql, check_sql; a row with an empty name marks a table with row-level security on), made at the first `CREATE POLICY` or `ENABLE ROW LEVEL SECURITY` | before the table is made (in `_system`) |
| `trash` | 2026-09-12 | tables renamed `_dropped_<ms>_<name>` | before `DROP TABLE` into the trash is logged |
| `database_settings`, `dialects` | 2026-09-12 | `_system` tables `database_settings`, `database_dialects` | before the table is made (in `_system`) |
| `pg_catalog_parts` | 2026-09-12 | catalog parts `'T'`, `'K'`, `'F'`, `'X'` | before the schema statement is logged |
| `sequences` | 2026-09-12 | `sequences` file, `CREATE/ALTER SEQUENCE` log records | before the statement is logged |
| `dedup_change` | 2026-09-12 | `ALTER TABLE ... DEDUP ENABLE/DISABLE` on a table with rows: one commit with the schema change, the dropped partitions and every row again. Only the log needs it: after a checkpoint the files are sorted by the new key, as for a table made with it | before that commit |
| `plpgsql_triggers` | 2026-09-12 | plpgsql functions and `FOR EACH ROW` triggers: new definition kinds in the `routines` file | before the definition is logged |
| `cached_views` | 2026-09-13 | `CREATE CACHED VIEW`: the cached views and `REFRESH ON COMMIT`, after the views in the `views` file | before `CREATE VIEW` is logged |
| `deferred_triggers` | 2026-09-13 | `CREATE TRIGGER ... DEFERRED` in the `routines` file, job records in the log, files `trigger_queue` and `q/<job id>` | before the definition, the first job or the queue file |
| `materialized_views` | 2026-09-13 | catalog part `'M'`, `REFRESH MATERIALIZED VIEW` log records, manifest meta `mv_dirty.<id>` | before the statement is logged |
| `table_ttl` | 2026-09-13 | catalog part `'L'` | before the schema statement is logged |
| `read_only_procedures` | 2026-09-24 | `CREATE PROCEDURE ... READ ONLY` in the `routines` file | before the definition is logged |
| `dedup_insert` | 2026-09-24 | `WITH (dedup_insert = 'upsert')`: catalog part `'U'` | before the schema statement is logged |
| `decimal128` | 2026-09-25 | `NUMERIC(p, s)` with p > 18: column type code 14 (16-byte values) in the catalog, partition files and log rows | before the schema statement is logged |
| `uuid` | 2026-10-02 | `UUID` columns: column type code 15 in the catalog, partition files and log rows. A value is two 64-bit words like DECIMAL128: the UUID's first 8 bytes big-endian as the low word, the last 8 as the high word (NULL in the null flags). Log rows hold the two words as two u64. Key parts (sort keys, PRIMARY KEY, DEDUP KEY, indexes) are those of the canonical text (36 lower-case characters with dashes), so a STRING column declared UUID before 2026-10-02 (it stays a STRING) has the same keys | before the schema statement is logged |
| `column_grants` | 2026-10-02 | column `column_grants` of `_system` table `users` (one line per column rule: database, table, column, allow bits, deny bits, split by tabs), made at the first column `GRANT` / `REVOKE` | before the column is made (in `_system`) |
| `fulltext_segments` | 2026-10-02 | full-text and JSON index segments `fts/t<table id>-<index name, hex>-<partition, hex>.kfs` (block files; data: `KFTS`, format 1, index definition, partition, the partition's saved files as path, version, size and digest of the file and each tail, a word dictionary, then per row in storage-key order its key, length and words with positions as varints). A cache outside the manifest and backups, used only when the partition's files are exactly those named; anything else is ignored and the rows read. Extensions `fts/<same name>.<level>.kfs` (level 1-4): format 2, one more str after the identity: the identity of the segment they extend; they hold only the rows after its last key, for partitions that only grew by tail files | **never recorded**: an older build ignores the folder |
| `dedup_generated_key` | 2026-09-25 | a stored generated column in a `DEDUP KEY` (an older build refuses such a catalog) | before the schema statement is logged |
| `symbol_partitions` | 2026-09-25 | `PARTITION BY <time>, SYMBOL(col)`: catalog part `'P'` (u32 format 1, u32 column id); partition files `t/<id>/<time>/s-<hex>` and `.../null` | before the schema statement is logged, and at every checkpoint |
| `round_time_zone` | 2026-09-25 | `TIMESTAMP ROUND ... TIME ZONE 'zone'`: catalog part `'R'` (u32 format 1, u32 n, n × (u32 column id, str zone)) | same |
| `round_time_zone_rules` | 2026-10-25 | catalog part `'R'` with a zone that is not a fixed offset (`Europe/London`): the same bytes; the column is cut on that zone's clock of each date, and an open without the zone files still succeeds (writes into the column fail) | before the schema statement is logged |
| `row_ttl` | 2026-09-25 | `CREATE TABLE ... WITH (ttl_column = c)`: catalog part `'E'` (u32 format 1, u32 column id of the TIMESTAMP column), only for such a table. An older build would show rows that have expired, so it must refuse the catalog. `kareladb downgrade` names each such table; the way back is a copy of the rows into a table without `ttl_column` and `DROP TABLE` | before the schema statement is logged, and at every checkpoint |
| `enum_types` | 2026-09-25 | `CREATE TYPE ... AS ENUM`: catalog format 3, the ENUM types after the last table | before `CREATE TYPE` is logged |
| `column_compression` | 2026-09-25 | `WITH / SET (compression = on)`: catalog part `'Z'` (u8 1, only while on) and packed partition files (flag bit 1, [section 8](#8-table-partition-files)). `kareladb downgrade` writes packed files of tables set back to `off` unpacked; a table still `on` blocks it | before the schema statement is logged, and at every checkpoint |
| `calendars` | 2026-09-25 | `CREATE CALENDAR`: catalog format 4, the trading calendars after the ENUM types | before `CREATE CALENDAR` is logged |
| `materialized_view_sample_by` | 2026-09-26 | `CREATE MATERIALIZED VIEW ... AS (SELECT ... SAMPLE BY ...)`: a SAMPLE BY query in catalog part `'M'`, refreshed bucket by bucket | before the statement is logged |
| `comments` | 2026-09-26 | `COMMENT ON TABLE / COLUMN`: catalog part `'N'` (u32 format 1, `str` table comment (`""` = none), u32 `n`, `n` × (u32 column id, `str` comment)), only while a comment is set. The statement is a `'D'` record (`COMMENT ON ... IS '...'`), replayed like other schema changes | before the first comment is logged, and at every checkpoint |
| `partition_tails` | 2026-10-02 | tail files ([section 8](#8-table-partition-files)): manifest entries `t/<id>/<partition>.tail<k>.b<version>` and meta keys `lastkey.<partition file>`. `kareladb downgrade` writes every partition with tails whole again, which drops them | in the manifest save that publishes the first tail |
| `partition_deltas` | 2026-10-02 | delta files ([section 8](#8-table-partition-files)): manifest entries `t/<id>/<partition>.delta.b<version>`. `kareladb downgrade` writes every partition with a delta whole again, which drops it | in the manifest save that publishes the first delta |
| `compressed_log` | 2026-10-02 | packed log records, type 3 ([section 4](#4-write-ahead-log-wal)): the data records of a commit with at least 64 KiB of them, written compressed. Every store that packs (the default; `KARELADB_WAL_COMPRESS=off` stops it) uses it. `kareladb downgrade` to an older KarelaDB opens the data with packing off: no new packed record, the last segment is not continued, and the checkpoint leaves no packed record the older KarelaDB has to replay | manifest saved by recovery, before the log writer can write a packed record |
| `cold_storage` | 2026-10-22 | cold storage: catalog part `'O'` (u32 format 1, `str` store name, u64 cold_after in ms), only while a store is set; partitions moved to an object store keep a **stub** as their manifest entry: a block file (type 3) with header flag 1 (`kStubFlag`, the only flag a block data file has), path `files/t/<id>/<partition>.cold.v<N>.kdb`, data `KCOLD1\n\0`, u32 format 1, then `str` store, `str` object key, u64 size, `str` SHA-256 (32 bytes), u64 the file's block-file digest, u64 its version, u64 its LSN, u64 moved at (Unix ms), `str` the file's 64-byte header, `str` its first block, `str` its checksum table and trailer. The object is the partition file, byte for byte. Manifest meta `cold.up.<object key>` (an upload in progress) and `cold.own.<object key>` (an object the database made and deletes once no stub names it). `kareladb downgrade` names each table and cold partition | before the schema statement is logged (catalog), and before the manifest save that publishes the first stub |
| `search_analyzer` | 2026-10-02 | `CREATE FULLTEXT INDEX ... WITH (language = 'english')`: catalog part `'S'` (u32 format 1, u32 `n`, `n` × (`str` index name, `str` language)), only while an index has a language. An older build would cut the words without stemming and stop words and give other answers, so it must refuse the catalog. `kareladb downgrade` names each such index; the way back is `DROP INDEX` and an index without the option | before the statement is logged, and at every checkpoint |

Catalog-based features are worked out on a copy of the catalog with the statement applied, before the statement's log record is written, and again from the catalog at every checkpoint.

**Parts `'P'` and `'R'` before their names.** Builds from 2026-09-13 (`'R'`) and 2026-09-18 (`'P'`) to 2026-09-24 wrote these parts without a feature name. An older build still refused such a database, but only when it read the catalog ("has part 'P', which this KarelaDB build does not know"). Since 2026-09-25 the next checkpoint adds the name, so the list says it at once. A build of 2026-09-18 to 2026-09-24 reads part `'P'` but does not know the name: it refuses such a database now. `kareladb downgrade --to` counts a feature from the date of its name, so it refuses it too.

**Changes without a new name** (they write nothing an older build misreads): see `docs/help/topics/versions.md` ("Changes that need no format change").

**Going back.** Because the list only grows, it can name features the data no longer uses (a dropped column, a dropped procedure). `kareladb downgrade <db> --to <version>` (or `--known <names>`):

1. opens the database and works out what uses each feature now: catalog (per table, column, index, constraint; a dropped table in the trash counts), views, sequences, routines (`Routines::StoredFeatureUses`), manifest entries and meta, the log's sync mode;
2. refuses, changing nothing and making no backup, when a used feature is not read by the target; it names each use and how to remove it;
3. makes a verified backup (unless `--no-backup`), then a checkpoint, so nothing in the log needs replay: features only log records use (`runs`, `dedup_change`, trigger job records, `audit`'s `'P'` records) are then unused. Partition files that still hold a column the table no longer has (DROP COLUMN or a type change only change the catalog) with a type code the target does not know (`json` 12, `bytes` 13, `decimal128` 14, `uuid` 15) are written again by that checkpoint (`TableStore::RewriteAtNextCheckpoint`), with only the table's columns now: the target's reader refuses a file with an unknown type code even when no table column uses it. Step 1 finds them by reading every partition file's header and column entries (`PartitionData::ReadFileColumns`), never the rows, and does not count them as refusing;
4. saves the list as exactly the used features (`Store::ReplaceFeatures`), then runs `kareladb check`.

The target reads a feature when the feature's "Since" is not newer: `--to 2026-09-13` is a build of that date; `--to 0.2.0-dev` is the last build of that version. With `--data-dir` and no `<db>` it does every database of the data folder, `_system` too, and checks them all before it changes any.

It never writes data in an older format. A database that uses a newer feature must stop using it first (for example `ALTER TABLE t DROP COLUMN c` for a 128-bit `NUMERIC`). Files that stay once made keep their feature: the `views`, `routines`, `sequences` and `trigger_queue` files. `kareladb features <db>` prints the same walk without changing anything.

**Other NeedsNewer checks** (data a newer KarelaDB wrote even without a new feature name): file header version > 1; a block file type above the known ones; manifest format > 1; backup format > 1; catalog format > 3 (or an ENUM section format > 1), an unknown catalog part tag, part format > 1, index kind, column type or flag, table kind or partition; partition file format 3..999, unknown partition flags or column type; a WAL record with a good CRC and a type other than 1 and 2; unknown WAL segment header flags; a database log record type other than `D U K V C P`, a `'P'` kind other than 1, a `'D'` record whose SQL does not parse; a row in the log with an unknown column type; routines file format > 1 or an unknown definition kind or SQL that does not parse; sequences file format > 1; a manifest entry name other than `catalog`, `views`, `routines`, `sequences`, `t/...`. When either manifest slot is NeedsNewer, the load is NeedsNewer (the other slot is not used).

**kareladb check / repair** open the store with a state machine that also decodes the catalog, reads format numbers of the other files and checks log record types (`CheckDatabaseFileFormat`, `CheckDatabaseLogFormat`), so they exit with 3.

**Adding a stored-format change:** add a feature to the table in the feature table (never rename or reuse a name), record it before the first write that needs it, make the reader give NeedsNewer for the new value, and add it here and to `docs/help/topics/versions.md`.
