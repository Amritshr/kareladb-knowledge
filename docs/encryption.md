# Encryption at rest

> CREATE DATABASE x WITH (encryption = on) - every file, log record and backup of it is encrypted; without the master key a copied disk shows nothing.

- Category: Users & security
- Keywords: encryption, encrypted, encryption at rest, at rest, encrypt, AES, AES-256, AES-256-GCM, GCM, ChaCha20, ChaCha20-Poly1305, master key, data key, key file, KDB_MASTER_KEY, KDB_MASTER_KEY_FILE, KDB_MASTER_KEY_PREVIOUS, KDB_MASTER_KEY_PREVIOUS_FILE, _encryption.key, kdb key, key rotation, rotate key, WITH (encryption , TDE, stolen disk, snapshot
- See also: [Databases and the data folder](databases.md), [TLS (https and sslmode=require)](tls.md), [Keeping kdb serve safe](server-security.md), [Backup, check, repair and restore](backup-and-safety.md), [kdb info, check, repair, dump-file](cli-maintenance.md)

An **encrypted database** keeps every file on disk encrypted: the tables, the log, the manifests and its backups. Someone who copies the disk, a VPS snapshot or a backup sees only random bytes. Only a KDB server that has the **master key** can read it.

It is **off by default**. You choose it for each database when you create it.

| | Plain database | Encrypted database |
|---|---|---|
| Files on disk | readable with a hex editor | random bytes |
| Backups | readable | encrypted too, and useless without the master key |
| Needs | nothing | the master key when the server starts |
| Queries | - | the same SQL, the same results |
| Speed | - | see [speed](#speed) |

Not covered: someone logged in to the running server as the `kdb` system user or as root can read the key and the memory. [Users and roles](users-and-roles.md) and [TLS](tls.md) protect the running server; encryption at rest protects the disk.

<a id="turn-on"></a>

## Turn it on

1. Make a master key once, and keep it **outside** the data folder:

```bash
kdb key new > /etc/kdb/master.key        # 64 hex characters
chmod 600 /etc/kdb/master.key
```

2. Give it to the server, in one of these ways:

Syntax:

```sql
KDB_MASTER_KEY=<64 hex characters, or base64 of 32 bytes>
KDB_MASTER_KEY_FILE=<a file holding the key as text, or 32 raw bytes>
```

3. Create the database encrypted:

```sql
CREATE DATABASE payroll WITH (encryption = on);
USE payroll;
CREATE TABLE salaries (name STRING, amount DECIMAL(2));
```

- **Returns:** `database 'payroll' created encrypted`.
- `WITH (encryption = on, pg_compat = on)` gives both options together ([CREATE DATABASE](databases.md#create-database)).
- Without a master key, `CREATE DATABASE ... WITH (encryption = on)` fails with `encryption = on needs a master key` and makes nothing.
- A database is encrypted or plain for its whole life. `ALTER DATABASE` cannot switch it, and `CREATE DATABASE IF NOT EXISTS ... WITH (encryption = on)` leaves a plain database that exists plain. To encrypt data you have, create an encrypted database and copy the tables into it (`INSERT INTO new_db.t SELECT * FROM old_db.t`).
- `GET /api/databases` shows `"encrypted": true` for each encrypted database.

In Docker, pass the key file as a secret and point `KDB_MASTER_KEY_FILE` at it, for example `-v /etc/kdb/master.key:/run/secrets/kdb_master_key:ro -e KDB_MASTER_KEY_FILE=/run/secrets/kdb_master_key`. Never put it in the data volume.

<a id="keys"></a>

## Keys

There are two keys, so that changing the master key never rewrites your data:

| Key | What it is | Where it is |
|---|---|---|
| master key | 256 bits you give the server | `KDB_MASTER_KEY` or `KDB_MASTER_KEY_FILE`, never in the data folder |
| data key | 256 random bits, one per database | `<database>/_encryption.key`, **wrapped** (encrypted) by the master key |

- The server refuses to start when `KDB_MASTER_KEY_FILE` is inside the data folder: a copy of the folder would hold the key too.
- An encrypted database opened without the master key, or with another one, is refused with a clear message (`... is encrypted: give the server its master key ...`). It is never reported as damage, and nothing is changed.
- **Keep the master key safe and keep a copy.** Without it the data cannot be read by anyone, KDB included.

<a id="rotate"></a>

## Change the master key

Do this when a key may have leaked, or someone who knew it left:

1. `kdb key new` for the new key.
2. Start the server with the **new** key in `KDB_MASTER_KEY` and the **old** one in `KDB_MASTER_KEY_PREVIOUS` (or the `..._FILE` forms).
3. Each encrypted database re-wraps its data key with the new master key when it opens. It takes milliseconds, and no data file is rewritten. The server log says `the data key is now wrapped by the new master key`.
4. Re-wrap the backups too: `kdb key rotate <backups folder>` (same variables).
5. Remove `KDB_MASTER_KEY_PREVIOUS`.

```bash
KDB_MASTER_KEY_FILE=/etc/kdb/new.key KDB_MASTER_KEY_PREVIOUS_FILE=/etc/kdb/old.key \
  kdb key rotate /data/_backups/payroll
```

Backups you do not re-wrap still need the old key. Keep old keys as long as backups that need them exist.

<a id="backups"></a>

## Backups and restore

- A backup of an encrypted database is encrypted too. Its files are copied as the encrypted bytes they are, and it takes the wrapped data key along (`_encryption.key`).
- `kdb verify-backup`, `kdb restore` and `POST /api/restore` need the master key. The restored database is encrypted with the same data key.
- A copy made off the machine (`--backup-copy`) is encrypted too.

<a id="what"></a>

## What is encrypted

| Part | How |
|---|---|
| table files, catalog, manifests, backup manifests, temporary GROUP BY files | the whole file, in 64 KB pieces, each with AES-256-GCM and its own check |
| the log (`wal/`, `wal_archive/`) | every record body on its own. Record headers (length, number, checksum) and commit times stay plain, so recovery after a crash works exactly as before |
| `kdb.lock`, `_encryption.key` | not encrypted (the key file holds only the wrapped key) |
| memory | not encrypted (see above) |

- Every file gets a key of its own, made from the data key and a random value in the file's header. Every piece has a fresh random nonce.
- Any changed byte, a piece moved inside a file, or a piece taken from another file fails its check and is reported as damage. A plain file put into an encrypted database is refused, never read as data.
- The cipher is **AES-256-GCM** where the CPU has AES instructions (every x86-64 CPU since about 2010). Without them, new files use **ChaCha20-Poly1305**, which is fast in plain code. Each file says which one it uses, so a database moved between computers still opens.

<a id="speed"></a>

## Speed

Measured on the development PC (Windows, x86-64 with AES instructions), a table of 1 million rows in 12 day partitions, a GROUP BY over all of it:

| Work | Plain | Encrypted |
|---|---|---|
| AES-256-GCM on one core | - | about 3-3.9 GB/s |
| scan of loaded data (in memory) | 292 ms | 302 ms (about +3%, within noise) |
| first scan after opening (reads and decrypts the files) | 749 ms | 883 ms (about +18%) |
| size of the data files | 60.2 MB | 61.6 MB (+2.3%) |

- **The first read after opening misses the goal.** The goal was at most 10% slower than a plain database; the first scan after opening was about 18% slower in this measurement. Work to close that gap is still open.
- Queries on data already in memory do not decrypt anything: they cost the same.
- Reading files, writing files (checkpoints, loads) and the log cost a little more CPU. A disk is slower than the cipher.
- Without AES instructions (old or small CPUs) ChaCha20-Poly1305 runs at about 550 MB/s on one core.
