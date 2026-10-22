# C API (kdb.h)

> Use KDB inside your own program with no server - open a folder, run SQL, read rows as text or native numbers - through the C header include/kdb.h and the kdb_c library.

- Category: C API
- Keywords: C API, kdb.h, kdb\_c, kdb.dll, libkdb.so, libkdb.dylib, embedded, embed, library, shared library, cgo, Go, golang, go-embedded, MinGW, database/sql, Rust, Python, ctypes, C#, P/Invoke, Swift, kdb\_open, kdb\_close, kdb\_exec, kdb\_exec\_values, kdb\_append, kdb\_result, kdb\_result\_free, kdb\_errmsg, kdb\_sqlstate, kdb\_last\_error, kdb\_session\_open, SQLSTATE, KDB\_BUILD\_C\_API, thread safety
- See also: [SQL basics](sql-basics.md), [Transactions](transactions.md), [INSERT](insert.md), [PostgreSQL protocol (port 8832)](postgres-protocol.md), [Run SQL over HTTP (/exec, /exp)](http-exec.md)

The C API puts the whole KDB engine inside your own program. There is no server, no port and no token: your program opens a database folder and runs SQL on it directly. The same SQL works as over HTTP or the PostgreSQL port.

| Part | Where |
|---|---|
| The header | `include/kdb.h` - plain C, so C, C++, Go (cgo), Rust, Python (ctypes), C# (P/Invoke) and Swift can call it |
| The library | `kdb.dll` (Windows), `libkdb.so` (Linux), `libkdb.dylib` (macOS) - the CMake target `kdb_c` |
| A full example | `tests/test_c_api.c` in the source |

Only the `kdb_` functions of the header leave the library. The ABI is stable: functions are only ever added, never changed or removed. `kdb_abi_version()` says which set a library has (1 today).

<a id="build"></a>

## Build the library

On Windows the library is built with the rest of KDB. On Linux and macOS ask for it, because it needs position-independent code, which costs the server program a little speed:

```text
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DKDB_BUILD_C_API=ON
cmake --build build --target kdb_c
```

The library lands in `build/bin`. On Windows it carries the C++ runtime inside, so `kdb.dll` needs no other DLL beside it.

<a id="exec"></a>

## Open, run SQL, read rows

```c
#include "kdb.h"
#include <stdio.h>

int main(void) {
  kdb_db* db;
  if (kdb_open("D:/data/app", "{\"memory_mb\": 256}", &db) != KDB_OK) {
    printf("open failed: %s\n", kdb_errmsg());
    return 1;
  }
  kdb_exec(db, "CREATE TABLE IF NOT EXISTS prices (sym SYMBOL, close DOUBLE, ts TIMESTAMP)", NULL, NULL);
  kdb_exec(db, "INSERT INTO prices VALUES ($1, $2, $3)", "[\"AAPL\", 101.5, \"2026-10-02T09:15:00Z\"]", NULL);

  kdb_result* r;
  if (kdb_exec(db, "SELECT sym, close, ts FROM prices WHERE close > $1", "[100]", &r) == KDB_OK) {
    for (int64_t i = 0; i < kdb_result_rows(r); i++)
      printf("%s %g %s\n", kdb_result_text(r, i, 0, NULL), kdb_result_double(r, i, 1),
             kdb_result_text(r, i, 2, NULL));
    kdb_result_free(r);
  }
  return kdb_close(db);
}
```

- `kdb_open` makes the folder when it is not there. One process at a time may open a folder; do not point it at the folder a running `kdb serve` uses.
- `kdb_exec` returns every row (there is no row limit). With several statements separated by `;`, the result is the last one's.
- Parameters `$1, $2, ...` come as a JSON array, or typed with `kdb_exec_values` and the helpers `kdb_int`, `kdb_double`, `kdb_text`, `kdb_bool`, `kdb_null`. A value never becomes SQL, so it is safe from SQL injection.
- Pass `NULL` for the result when you do not need it.

<a id="options"></a>

### Options of kdb_open

`options_json` may be `NULL` or an object with any of these. A name it does not know is an error, so a typo is never silently ignored.

| Option | Default | What it does |
|---|---|---|
| `memory_mb` | 512 | saved partition data kept in memory |
| `read_only` | false | open without writing anything |
| `sync_commits` | true | false: a commit returns before the disk sync (a power cut can lose the last ~10 ms) |
| `background` | true | false: no background threads (idle checkpoints, TTL, index warm-up, view refresh) - for short tools |
| `statement_timeout_ms` | 0 | stop a statement after this long (0 = no limit) |
| `lock_timeout_ms` | the engine's | how long a writer waits for a busy table |
| `min_free_mb` | 64 | refuse writes when the disk has less free |
| `encryption` | false | make a new database encrypted (needs `KDB_MASTER_KEY`) |

<a id="result"></a>

## Reading a result

| Function | Gives |
|---|---|
| `kdb_result_columns`, `kdb_result_rows` | the size |
| `kdb_result_column_name`, `kdb_result_column_type` | `"close"`, `"DOUBLE"` (the SQL type) |
| `kdb_result_type` | `KDB_NULL`, `KDB_BOOL`, `KDB_INT`, `KDB_DOUBLE` or `KDB_TEXT` |
| `kdb_result_int64`, `kdb_result_double` | the value as a native number |
| `kdb_result_text` | the value as text; `NULL` for SQL NULL |
| `kdb_result_rows_affected`, `kdb_result_message` | for INSERT, UPDATE, DELETE and DDL |

A TIMESTAMP is a `KDB_INT` of Unix milliseconds (UTC), and its text is `2026-10-02T09:15:00.000Z`. A DATE is days since 1970-01-01, text `2026-10-02`. A DECIMAL is exact text (`"512.40"`); `kdb_result_double` reads it as a number. A row or column out of range reads as NULL - never a crash.

Every pointer a result gives stays valid until `kdb_result_free`, even after `kdb_close`.

<a id="errors"></a>

## Errors and SQLSTATE

Every call that can fail returns a `kdb_code`: `KDB_OK` (0), `KDB_NOTFOUND`, `KDB_INVALID`, `KDB_LOCKED`, `KDB_MISUSE` (a NULL handle, bad JSON, an unknown option) and a few more. The message and the PostgreSQL SQLSTATE of the last failure on the calling thread stay until that thread's next call:

```c
if (kdb_exec(db, "INSERT INTO users (id) VALUES (1)", NULL, NULL) != KDB_OK) {
  if (strcmp(kdb_sqlstate(), "23505") == 0) puts("that id is taken");
  else printf("%s: %s\n", kdb_sqlstate(), kdb_errmsg());
}
```

| SQLSTATE | Means |
|---|---|
| `42P01` | no such table |
| `42703` | no such column |
| `42601` | a syntax error |
| `23505` | a duplicate key |
| `23503` | a REFERENCES row is missing |
| `23502` | NULL in a NOT NULL column |
| `55P03` | a lock wait ran out |

These are the same codes the PostgreSQL port sends. A call that works sets `00000`.

<a id="append"></a>

## Bulk rows: kdb_append

`kdb_append` writes many rows in one commit without any SQL text - the fastest way in. Values go row after row:

```c
const char* cols[] = {"sym", "close", "ts"};
kdb_value rows[] = {
  kdb_text("AAPL"), kdb_double(101.5), kdb_text("2026-10-02T09:15:00Z"),
  kdb_text("MSFT"), kdb_double(410.2), kdb_text("2026-10-02T09:15:00Z"),
};
uint64_t written;
kdb_append(db, "prices", cols, 3, rows, 2, KDB_APPEND_ERROR, &written);
```

All rows or none are written. The mode says what a row with a key that is taken does: `KDB_APPEND_ERROR` (fail, like INSERT), `KDB_APPEND_REPLACE`, `KDB_APPEND_IGNORE`, or `KDB_APPEND_UPSERT` (like REPLACE, faster).

<a id="sessions"></a>

## Transactions: sessions

Each `kdb_exec` is its own connection: a `BEGIN` there is rolled back when the call ends. To keep a transaction open across calls, open a session:

```c
uint64_t s;
kdb_session_open(db, &s);
kdb_exec_session(db, s, "BEGIN", NULL, NULL);
kdb_exec_session(db, s, "UPDATE accounts SET bal = bal - 10 WHERE id = 1", NULL, NULL);
kdb_exec_session(db, s, "UPDATE accounts SET bal = bal + 10 WHERE id = 2", NULL, NULL);
kdb_exec_session(db, s, "COMMIT", NULL, NULL);
kdb_session_close(db, s);  /* rolls back anything still open */
```

<a id="threads"></a>

## Threads

| Thing | Rule |
|---|---|
| A `kdb_db` | any number of threads at once; reads run side by side, writes one at a time per table, as in the server |
| A `kdb_result` | never changes after it is returned: many threads may read it; free it once |
| A session | one connection: use one per thread |
| Errors | kept per thread, so threads never see each other's message |
| `kdb_close` | the last call on a `kdb_db`: no other thread may still use it |

<a id="go"></a>

## From Go: the cgo package

`examples/go-embedded` in the source is a Go package over `kdb.h`. It gives Go code the shape of `database/sql`, with no server:

```go
db, err := kdb.Open("D:/data/app", &kdb.Options{MemoryMB: 256})
if err != nil { log.Fatal(err) }
defer db.Close()

db.Exec("CREATE TABLE IF NOT EXISTS prices (sym SYMBOL, close DOUBLE, ts TIMESTAMP)")
db.Exec("INSERT INTO prices VALUES ($1, $2, $3)", "AAPL", 101.5, time.Now())

rows, err := db.Query("SELECT sym, close, ts FROM prices WHERE close > $1", 100)
if err != nil { log.Fatal(err) }
defer rows.Close()
for rows.Next() {
  var sym string
  var close float64
  var ts time.Time
  if err := rows.Scan(&sym, &close, &ts); err != nil { log.Fatal(err) }
}
```

| Go | Does |
|---|---|
| `kdb.Open(path, opts)`, `db.Close()` | `kdb_open`, `kdb_close`; `opts` may be `nil` |
| `db.Exec(sql, args...)` | runs SQL; returns `RowsAffected` and `Message` |
| `db.Query(sql, args...)` | `Rows` with `Next`, `Scan`, `Columns`, `Value`, `Close` |
| `db.QueryRow(sql, args...).Scan(...)` | the first row; `kdb.ErrNoRows` when there is none |
| `db.Session()` | a session: `BEGIN ... COMMIT` across calls; `Close` rolls back what is still open |
| `db.Append(table, cols, rows, mode)` | `kdb_append`: many rows in one commit, no SQL text |

- Parameters may be `nil`, `bool`, any integer, `float32`/`float64`, `string`, `[]byte` and `time.Time` (sent as UTC text, which a TIMESTAMP or DATE column reads).
- `Scan` takes `*string`, `*[]byte`, `*int64`, `*int`, `*int32`, `*float64`, `*float32`, `*bool`, `*time.Time`, `*any`, and `sql.NullString`, `sql.NullInt64`, `sql.NullTime`, ... (anything with a `Scan` method). A NULL into a plain type is an error, as in `database/sql`.
- A TIMESTAMP or DATE column scans into `time.Time` (UTC).
- An error is a `*kdb.Error` with `Code`, `SQLState` and `Message`; `kdb.IsSQLState(err, "23505")` asks for one code.
- One `*kdb.DB` may be used by many goroutines at once. The package reads the error of a call inside the same C call, so a goroutine that Go moves to another thread never gets another call's SQLSTATE.
- A result holds all its rows, so `Next` never waits on the engine. A `Rows` that is never closed is freed later by the garbage collector; close it to free it at once.

<a id="go-build"></a>

### Building it

cgo needs a C compiler on `PATH` when the package is built, and the library when the program runs.

1. Build the library (see [Build the library](#build)). The package looks for it in `build/bin` (on Windows also the import library in `build/lib`) of the same source tree. For a library somewhere else, set `CGO_CFLAGS=-I<folder of kdb.h>` and `CGO_LDFLAGS=-L<folder of the library>`.
2. Build or test it with cgo on:

```text
cd examples/go-embedded
go test ./...
```

| System | Notes |
|---|---|
| Windows | cgo needs MinGW-w64 gcc on `PATH` (for example MSYS2: `C:\msys64\ucrt64\bin`); MSVC does not work with cgo. `kdb.dll` must be found when the program starts: put it next to your `.exe`, or `build\bin` on `PATH`. It carries its C++ runtime, so it needs no other DLL. |
| Linux | gcc or clang; build the library with `-DKDB_BUILD_C_API=ON`. The package sets an rpath to `build/bin`; a program you ship needs `libkdb.so` beside it or on `LD_LIBRARY_PATH`. |
| macOS | clang (the Xcode command line tools); as Linux, with `libkdb.dylib`. |

cgo is on by default when Go finds a C compiler. A cross build (another `GOOS` or `GOARCH`) turns it off, so build on the kind of system the program runs on.

To use the package from your own module, point at it with two lines in your `go.mod` - `require kdb v0.0.0` and `replace kdb => ../KDB/examples/go-embedded` - and `import "kdb"`.
