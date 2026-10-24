# How KarelaDB stores data

> A short tour of the files in a KarelaDB database folder - data files, blocks and checksums, the log, the manifest and backups.

- Category: Data formats
- Keywords: file format, on-disk format, files, folder, kdb.lock, \_manifest.a, \_manifest.b, manifest, wal, wal\_archive, \_trash, WAL, write-ahead log, log segment, LSN, checkpoint, block, CRC32C, checksum, digest, copy-on-write, version, partition file, column file, backup.kdb, .partial, timeline, FORMAT.md, little-endian, manifest keys, removed manifest keys, column stats
- See also: [Backup, check, repair and restore](backup-and-safety.md), [kareladb info, check, repair, dump-file](cli-maintenance.md), [Partitions, SORT BY and DEDUP KEY](partitions-and-dedup.md), [Limits (disk-memory)](limits.md#disk-memory)

This page explains, in simple words, what KarelaDB writes to the disk and why. You do not need it to use KarelaDB. It helps to understand `kareladb info`, `kareladb check` and the messages about damage.
The exact bytes, for developers, are in docs/FORMAT.md. When that file and the code disagree, the code is right.

**Do not change or delete files in a database folder by hand.** Use `kareladb` commands. To copy a database, stop every program that uses it, or better use [kareladb backup](backup-and-safety.md#kareladb-backup).

The format is the same on Windows, Linux and macOS, so a database folder can move between them.

<a id="folder"></a>

## The database folder

Syntax:

```sql
<database>/
  kdb.lock                   locked while a program has the database open
  _manifest.a  _manifest.b   the list of current files, saved twice
  files/                     data files: files/<name>.v<version>.kdb
  wal/                       the write-ahead log (the newest changes)
  wal_archive/               older log files, kept for backups and repairs
  _trash/                    files taken out of use, deleted after 24 hours
```

A database is one folder. In a data folder, each database is a sub-folder, plus `_trash` (dropped databases) and `_system` (the server's users).

| Name | What it is |
|---|---|
| `kdb.lock` | An empty file. While a program has the database open, the operating system **locks** it, so a second program gets `the database is open in another program`. Do not delete it: when no program runs, the lock is free anyway. |
| `_manifest.a`, `_manifest.b` | The **manifest**: the list of the current data files, their versions, sizes and checksums, and the log positions. Two copies (see [manifest](#manifest)). |
| `files/` | The **data files**: `files/catalog.v6.kdb` (the list of tables and columns) and `files/t/<table number>/<partition>.v<version>.kdb` (the rows of one partition). A table [split by symbol](partitions-and-dedup.md#partition-by-symbol) adds the symbol to the partition name, as hex: `2026-09/s-43495459` is month `2026-09`, symbol `CITY`. |
| `wal/` | The **write-ahead log** (WAL): every change is written here first (see [the log](#wal)). |
| `wal_archive/` | Old log files that the data files no longer need. Only backups and repairs use them. The oldest are deleted when this folder is over its limit: 1 GB by default, changed with [ALTER DATABASE ... SET WAL_ARCHIVE](databases.md#wal-archive) or on the [Settings page](console-settings.md#wal-archive). |
| `_trash/` | Files taken out of use: old versions, damaged files moved away by a repair, unknown files. Folders older than 24 hours are deleted when the database opens. |

**Command line: kareladb info lists what the manifest says** (sample data: sample)

```bash
kareladb info market
```

Output:

```text
database        market
manifest        copy a, sequence 9
last shutdown   clean
log position    30 (saved in files up to 30)
newest change   2026-10-24 08:46:30
features        batched_log_sync, block_stats, compressed_log, partition_format_2
manifest keys   26

FILE                                      VERSION       SIZE          LSN  STATUS
catalog                                         6     2.1 KB           30  ok
t/1/all                                         7      777 B           30  ok
t/2/all                                         8      556 B           30  ok
t/3/2025                                        9     1.7 KB           30  ok
t/3/2026                                       10     3.6 KB           30  ok
t/4/2026-09                                    11    57.0 KB           30  ok
t/5/2026-09-09                                 12     1.4 KB           30  ok
t/5/2026-09-10                                 13     2.4 KB           30  ok
t/6/2026-09-10                                 14     2.7 KB           30  ok

9 files, 72.1 KB, 0 marked damaged
(STATUS is what the manifest records. To read every block and find new damage, run: kareladb check)
```

`t/4/2026-09` is table number 4 (tables are numbered in the order they were made; here `ochl_minutes`), partition `2026-09`. `all` is a table without partitions. `VERSION 11` is the file `files/t/4/2026-09.v11.kdb`.

<a id="data-files"></a>

## Data files are never changed

Syntax:

```sql
files/t/<table number>/<partition>.v<version>.kdb
```

A data file is written **once** and then never changed (this is called copy-on-write).

1. Changes first go into the log and into memory.
2. From time to time (a **checkpoint**), KarelaDB writes a **new version** of each changed partition: a new file with the next version number.
3. KarelaDB reads the new file back and checks it.
4. Only then it saves the manifest, which now names the new version.

- A crash at any moment leaves the old version complete. There is never a half-changed file.
- KarelaDB keeps the **2 previous versions** of every file, for the repair ladder. Older ones go to `_trash`.
- A checkpoint happens after about 1 million changes, every 5 minutes, when the changes use a quarter of `--memory`, about 2 seconds after the last write when at least 10,000 changes wait, when a database closes, before a backup or a schema change, and when you ask for one with [CHECKPOINT](backup-and-safety.md#checkpoint). On a busy database a write may leave its checkpoint to a background thread, but only until the changes use half of `--memory`, or for at most 5 seconds; after that the next write waits for the checkpoint, so unsaved changes cannot grow without limit. Rows a load (`POST /write`, `POST /imp`, `COPY`) keeps in column form count as 1/8 of a change, so a bulk load checkpoints about every 8 million rows (or at a quarter of `--memory`, whichever comes first) instead of every million: each checkpoint writes every partition it touched whole, and on a big load into a few partitions most of those bytes were rows already on disk (since 2026-10-02).
- One partition file holds all columns of that partition, column after column, with the number of rows, the smallest and biggest value and the sum of each column (the **column stats**).
- KarelaDB uses the column stats without reading the rows: a `WHERE` skips a partition in memory (or a block of 65,536 rows in it) whose values cannot match, and `count`, `min`, `max` and `sum` of a partition that is not in memory are answered from its file's stats, without loading the rows. [EXPLAIN](explain.md) shows both. This needed no change of the files: partition files have had the stats since 2026-09-12.

**Command line: One data file: the table securities** (sample data: sample)

```bash
kareladb dump-file market/files/t/1/all.v7.kdb
```

Output:

```text
file         market/files/t/1/all.v7.kdb
type         data file
version      1
data         693 B
block size   65536
LSN          30
id           1
created      2026-10-24 08:46:30
blocks       1
digest       1d198644
OK: all blocks match their checksums
```

<a id="checksums"></a>

## Blocks and CRC32C checksums

Syntax:

```sql
[ header 64 bytes ][ block 1 ][ block 2 ] ... [ checksum table ][ trailer 16 bytes ]
```

Every KarelaDB file (data files, manifests, `backup.kdb`) is cut into **blocks** of 64 KB. Each block has a **CRC32C checksum**: a 4-byte number made from the bytes of the block.

- When KarelaDB reads a block, it computes the number again. If one bit on the disk has changed, the numbers differ, and KarelaDB says `block N (bytes ...) failed its checksum`. It **never** returns data from a bad block.
- The **header** (the first 64 bytes) says what the file is: its type, the format version, the block size, the data length, the log position, and when it was made. It has its own checksum.
- The **trailer** at the end holds the number of blocks and a checksum of the checksum table, so a file that was cut short is noticed.
- The **digest** is one checksum over the header and all block checksums. The manifest keeps it for each file, so KarelaDB also notices a whole file that was replaced by another one.
- The header is written **last**. A file that a crash interrupted has no valid header and is never used.
- `crc32c hardware: yes` in `kareladb version` means the CPU computes these checksums with fast special instructions.

**Command line: Check every block of one file** (sample data: sample)

```bash
kareladb dump-file market/_manifest.a
```

Output:

```text
file         market/_manifest.a
type         manifest
version      1
data         2.3 KB
block size   65536
LSN          30
id           9
created      2026-10-24 08:46:30
blocks       1
digest       936554ec
OK: all blocks match their checksums
```

<a id="wal"></a>

## The write-ahead log (WAL)

Syntax:

```sql
wal/00000000000000000001.log      a log file (segment), named after its first LSN
record: length | checksum | LSN | transaction id | type (data or commit) | data
```

Every change is first written to the **log**, and the log is on the disk before KarelaDB says a statement is done.

- Each record in the log gets the next number: the **LSN** (log sequence number). `kareladb info` shows `log position` = the newest LSN.
- A transaction is its data records plus one **commit** record. The whole transaction is written in one piece and saved with **one** disk sync. Without its commit record, a transaction does not count.
- Every record has its own checksum.
- A log file (a **segment**) grows to 64 MB; then a new one starts. Log files that the data files no longer need move to `wal_archive/`.
- **After a crash**, KarelaDB reads the log from the position the data files have, and replays every committed transaction. `kareladb info` then shows `last shutdown: not clean`, which is normal.
- **A torn tail:** a power cut can leave the last, unconfirmed transaction half written at the end of the log. KarelaDB notices it and cuts it off (`dropped an unfinished write at the end of the log`). Nothing confirmed is lost.
- **Damage in the middle** of the log, in records that are still needed, is refused with a clear message. See [after damage](backup-and-safety.md#after-damage).
- With `--sync-commits batch`, several transactions share one disk sync every 10 ms.

<a id="manifest"></a>

## The manifest: two copies

Syntax:

```sql
_manifest.a   _manifest.b    the newer valid copy (highest sequence number) wins
```

The manifest is the list of what is current: every data file with its version, size, digest and log position, the previous versions, which files are marked damaged, and whether the last shutdown was clean.

- It is saved in two files. A save always writes over the **older** copy. So if a crash happens during a save, the other copy is still complete.
- When opening, KarelaDB reads both and uses the valid copy with the highest **sequence** number. `kareladb info` shows `manifest copy b, sequence 12`.
- If one copy is damaged, KarelaDB notes it and writes over it at the next save.
- It is saved at every checkpoint, after a recovery, and when the database closes (then with `clean shutdown`).

<a id="manifest-keys"></a>

### Manifest keys

Besides the file list, the manifest keeps small **keys** for the tables:

| Key | What it holds |
|---|---|
| `rows.<file>` | the row count of a partition file |
| `sym.<file>` | which symbols a partition file holds, so a `WHERE symbol = ...` skips files without opening them |
| `rowid.<table number>`, `auto.<table number>` | the next row id and the next `AUTO` value of a table |

- Every checkpoint rewrites the manifest with all its keys. Since 2026-09-23 the keys of a dropped table (and of partition files that are gone) are removed at the next checkpoint, and once when a database is opened for writing. Older builds left them behind for ever.
- The open then says `removed N manifest keys left behind by dropped tables`. `kareladb info` shows `manifest keys N`, and how many of them belong to files that are gone.
- This is no change of the format: an older KarelaDB opens such a manifest as before.

**Command line: Which copy is newest** (sample data: sample)

```bash
kareladb info market
kareladb dump-file market/_manifest.b
```

Output:

`> kareladb info market`

```text
database        market
manifest        copy a, sequence 9
last shutdown   clean
log position    30 (saved in files up to 30)
newest change   2026-10-24 08:46:30
features        batched_log_sync, block_stats, compressed_log, partition_format_2
manifest keys   26

FILE                                      VERSION       SIZE          LSN  STATUS
catalog                                         6     2.1 KB           30  ok
t/1/all                                         7      777 B           30  ok
t/2/all                                         8      556 B           30  ok
t/3/2025                                        9     1.7 KB           30  ok
t/3/2026                                       10     3.6 KB           30  ok
t/4/2026-09                                    11    57.0 KB           30  ok
t/5/2026-09-09                                 12     1.4 KB           30  ok
t/5/2026-09-10                                 13     2.4 KB           30  ok
t/6/2026-09-10                                 14     2.7 KB           30  ok

9 files, 72.1 KB, 0 marked damaged
(STATUS is what the manifest records. To read every block and find new damage, run: kareladb check)
```

`> kareladb dump-file market/_manifest.b`

```text
file         market/_manifest.b
type         manifest
version      1
data         2.3 KB
block size   65536
LSN          30
id           8
created      2026-10-24 08:46:30
blocks       1
digest       58a232b8
OK: all blocks match their checksums
```

In the header of a manifest, `id` is its sequence number. The copy that `kareladb info` names has the higher one; the other copy is one save older.

<a id="backups"></a>

## Backup folders

Syntax:

```sql
<backups-dir>/
  20260911-161530-123/          a backup; the name is the UTC time
    backup.kdb                  the list of the backup, written last
    files/<name>.v<N>.kdb       the current version of every data file
    wal/<first LSN>.log         the log files needed to replay from those files
  20260912-...-.partial/        an unfinished backup: never used, removed later
```

- A backup holds only the **current** version of each file, plus the log files needed. With `--hard-links`, the data files are hard links; log files are always copied.
- `backup.kdb` is a KarelaDB block file too (with checksums). It is written **last**, after every file was copied and synced. Then the whole backup is read again. Only then the folder gets its final name (without `.partial`).
- A backup knows which database it came from (a random id made when the database was created) and its log history. Repairs and `--logs-from` never use a backup or log of another database.
- **Restore** copies the files into a new folder, checks every copy, adds newer log files from `--logs-from`, cuts the log at `--until`, and writes a new manifest. The log is replayed when the new database is first opened. The restored database starts a new log **history** (timeline), so old log files of the abandoned history are never mixed in.

**Command line: A backup, and its list** (sample data: sample)

```bash
kareladb backup market backups
kareladb backups backups
```

Output:

`> kareladb backup market backups`

```text
backup created and verified: backups/20261024-030137-397
  9 files, 190.0 KB, log up to 30
```

`> kareladb backups backups`

```text
BACKUP                 CREATED               FILES       SIZE      LOG LSN
20261024-030137-397    2026-10-24 08:46:37       9   190.0 KB           30
1 backups
```

<a id="indexes"></a>

## Indexes are not stored

Syntax:

```sql
CREATE INDEX ...     only the definition is saved (in the catalog)
```

For `CREATE INDEX`, KarelaDB saves only the **definition** in the catalog. The index itself lives in memory. It is built from the rows after the database opens: `kareladb serve` builds every index on a background thread right after the open, and a query that needs one before that builds it itself.

- So `kareladb check`, `kareladb repair`, backups and restores have nothing to check for indexes, and an index can never be old or damaged after a crash.
- The cost: after a start, building a big index takes a while. A query that needs it early waits for it (see [indexes](indexes.md#warm)).

**Example: An index on a sample table: only its definition is saved** (sample data: sample)

```sql
CREATE INDEX trade_log_buyer ON trade_log (buyer);
SHOW INDEXES;
```

Result:

`CREATE INDEX trade_log_buyer ON trade_log (buyer)`

```text
index 'trade_log_buyer' created on table 'trade_log' (32 rows)
```

`SHOW INDEXES`

| name (STRING) | table (STRING) | kind (STRING) | columns (STRING) | built (BOOL) | rows (LONG) | memory_bytes (LONG) | create_sql (STRING) | building (BOOL) |
|---|---|---|---|---|---|---|---|---|
| trade_log_buyer | trade_log | INDEX | buyer | true | 32 | 1777 | CREATE INDEX trade_log_buyer ON trade_log (buyer) | false |

(1 row)
