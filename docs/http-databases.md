# Databases over HTTP (/api/databases)

> List the databases of a server, create a new one, and drop one (its folder moves to _trash).

- Category: HTTP API
- Keywords: api/databases, list databases, create database, drop database, \_trash, can\_create, data\_dir, default database, --data-dir, --db, 409, name rules
- See also: [Databases and the data folder](databases.md), [HTTP API overview (database)](http-overview.md#database), [Health, info, check and backup over HTTP](http-server-info.md), [kareladb serve](cli-serve.md)

A server started for a **data folder** (`kareladb serve`, or `kareladb serve --data-dir <folder>`) serves every database in that folder. A **database** is one folder with its own tables. These routes list, create and drop them.

- Every other route picks its database with `db=<name>` or the header `X-KDB-Database` ([choosing the database](http-overview.md#database)).
- The same can be done in SQL: `SHOW DATABASES`, `CREATE DATABASE`, `DROP DATABASE` ([databases](databases.md)).
- A server started for one folder (`kareladb serve D:\kdb\market`) has just that one database and cannot create or drop others.

## GET /api/databases

Syntax:

```sql
GET /api/databases
```

Lists the databases of the server, sorted by name.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| (none) | - | This route does not use `db=` | - |

| Answer field | Meaning |
|---|---|
| `databases[]` | One object for each database you may read |
| `databases[].name` | The database name |
| `databases[].dir` | Its folder |
| `databases[].default` | `true` for the default database (used when a request has no `db=`) |
| `databases[].open` | `true` when the server has it open now |
| `databases[].opening` | `true` while a request is opening it (a big database can take minutes) |
| `databases[].opening_ms` | Only while it opens: for how long, in milliseconds |
| `databases[].opening_phase` | Only while it opens: what it does now, such as `replaying log` (details in [/api/stats](http-server-info.md#api-stats)) |
| `databases[].busy` | Only when `true`: a write or checkpoint held the database, so `tables`, `bytes` and `wal_archive_bytes` are from the last listing that got in. The list never waits for a database |
| `databases[].tables` | Number of tables, or `null` when it is not open |
| `databases[].bytes` | Size of its data files, or `0` when it is not open |
| `databases[].error` | Only when an open database cannot be read: why |
| `databases[].wal_archive_max_bytes` | Old log the database keeps for repairs and restores (`0` = none) |
| `databases[].wal_archive_source` | `database` when it has its own `ALTER DATABASE ... SET WAL_ARCHIVE`, else `server` (the server default) |
| `databases[].wal_archive_bytes` | Old log on disk now, or `null` when it is not open |
| `default` | The name of the default database |
| `data_dir` | The data folder (empty for `kareladb serve <folder>`) |
| `can_create` | `true` when you may create and drop databases here: the server has a data folder, and you have full rights |
| `wal_archive_default_bytes` | The server default for old log kept per database (`wal_archive_mb` in `kareladb.conf`, or `KARELADB_WAL_ARCHIVE_MB`) |

- **Status codes:** 200; 401 without a needed login.
- **Notes:** listing never opens a database, so it answers at once, also while a big one is being opened. A database is opened by the first request that uses it (`db=<name>`); until then it is listed with `open: false` and no table count. With users, the list has only the databases the user may read, and `can_create` is `true` only for a user whose own ROLE is `admin`. The default database is made the first time it is used, so on a new server it may not be in the list yet.
- **About the example below:** the server that made this help has one database for each example (named `h1`, `h2`, ...), so its list is longer than yours will be. `demo` is the database of this example.

**HTTP: Every database of the server**

```http
GET /api/databases
```

Response:

HTTP 200 (application/json)

```text
{
  "databases": [
    {
      "name": "h119",
      "dir": "kdb-data/h119",
      "default": false,
      "encrypted": false,
      "open": true,
      "tables": 1,
      "bytes": 266,
      "opening": false,
      "wal_archive_max_bytes": 1073741824,
      "wal_archive_source": "server",
      "wal_archive_bytes": 0,
      "result_cache_bytes": 268435456,
      "result_cache_source": "server"
    },
    {
      "name": "demo",
      "dir": "kdb-data/demo",
      "default": false,
      "encrypted": false,
      "open": true,
      "tables": 0,
      "bytes": 0,
      "opening": false,
      "wal_archive_max_bytes": 1073741824,
      "wal_archive_source": "server",
      "wal_archive_bytes": 0,
      "result_cache_bytes": 268435456,
      "result_cache_source": "server"
    },
    {
      "name": "h1409",
      "dir": "kdb-data/h1409",
      "default": false,
      "encrypted": false,
      "open": true,
      "tables": 0,
      "bytes": 0,
      "opening": false,
      "wal_archive_max_bytes": 1073741824,
      "wal_archive_source": "server",
      "wal_archive_bytes": 0,
      "result_cache_bytes": 268435456,
      "result_cache_source": "server"
    },
    {
      "name": "h186",
      "dir": "kdb-data/h186",
      "default": false,
      "encrypted": false,
      "open": true,
      "tables": 0,
      "bytes": 0,
      "opening": false,
      "wal_archive_max_bytes": 1073741824,
      "wal_archive_source": "server",
      "wal_archive_bytes": 0,
      "result_cache_bytes": 268435456,
      "result_cache_source": "server"
    },
    {
      "name": "h187",
      "dir": "kdb-data/h187",
      "default": false,
      "encrypted": false,
      "open": true,
      "tables": 0,
      "bytes": 0,
      "opening": false,
      "wal_archive_max_bytes": 1073741824,
      "wal_archive_source": "server",
      "wal_archive_bytes": 0,
      "result_cache_bytes": 268435456,
      "result_cache_source": "server"
    },
    {
      "name": "h245",
      "dir": "kdb-data/h245",
      "default": false,
      "encrypted": false,
      "open": true,
      "tables": 0,
      "bytes": 0,
      "opening": false,
      "wal_archive_max_bytes": 1073741824,
      "wal_archive_source": "server",
      "wal_archive_bytes": 0,
      "result_cache_bytes": 268435456,
      "result_cache_source": "server"
    },
    {
      "name": "h326",
      "dir": "kdb-data/h326",
      "default": false,
      "encrypted": false,
      "open": true,
      "tables": 6,
      "bytes": 73878,
      "opening": false,
      "wal_archive_max_bytes": 1073741824,
      "wal_archive_source": "server",
      "wal_archive_bytes": 0,
      "result_cache_bytes": 268435456,
      "result_cache_source": "server"
    },
    {
      "name": "h327",
      "dir": "kdb-data/h327",
      "default": false,
      "encrypted": false,
      "open": true,
      "tables": 6,
      "bytes": 73878,
      "opening": false,
      "wal_archive_max_bytes": 1073741824,
      "wal_archive_source": "server",
      "wal_archive_bytes": 0,
      "result_cache_bytes": 268435456,
      "result_cache_source": "server"
    },
    {
      "name": "h60",
      "dir": "kdb-data/h60",
      "default": false,
      "encrypted": false,
      "open": true,
      "tables": 0,
      "bytes": 0,
      "opening": false,
      "wal_archive_max_bytes": 1073741824,
      "wal_archive_source": "server",
      "wal_archive_bytes": 0,
      "result_cache_bytes": 268435456,
      "result_cache_source": "server"
    }
  ],
  "default": "default",
  "data_dir": "kdb-data",
  "can_create": true,
  "wal_archive_default_bytes": 1073741824
}
```

```powershell
$d = Invoke-RestMethod http://127.0.0.1:9900/api/databases
"default: $($d.default)   can_create: $($d.can_create)"
$d.databases | Select-Object name, tables, bytes, default | Format-Table -AutoSize
```

```python
import requests

d = requests.get("http://127.0.0.1:9900/api/databases").json()
for db in d["databases"]:
    print(db["name"], db["tables"], db["bytes"])
```

## POST /api/databases

Syntax:

```sql
POST /api/databases?name=<name>
POST /api/databases        body: {"name": "<name>"}
POST /api/databases        body: name=<name>  (Content-Type: application/x-www-form-urlencoded)
```

Creates an empty database: a new folder in the data folder.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `name` | URL, form field, or JSON body | The new database's name: letters, digits, `_` and `-`, at most 64 characters. Case is ignored. | required |

| Answer field | Meaning |
|---|---|
| `name` | The name of the new database |
| `created` | `true` |

- **Status codes:** 200 created; 400 no name or a bad name; 401/403 login or role; 409 a database with this name already exists.
- **Notes:** needs full rights (the `--token`, a server without login, or a user whose own ROLE is `admin`). A `GET` never creates a database. A server for one folder (`kareladb serve <folder>`) refuses. In SQL: `CREATE DATABASE name` (with `POST /exec`).

**HTTP: Create with ?name=, then with a JSON body**

```http
POST /api/databases?name=help_shop
###
POST /api/databases
Content-Type: application/json

{"name": "help_forum"}
###
POST /exec?db=help_shop&compat=0

CREATE TABLE items (id INT PRIMARY KEY, name STRING);
SHOW TABLES
```

Response:

`POST /api/databases?name=help_shop`

HTTP 200 (application/json)

```text
{"name": "help_shop", "created": true}
```

`POST /api/databases`

HTTP 200 (application/json)

```text
{"name": "help_forum", "created": true}
```

`POST /exec?db=help_shop&compat=0`

HTTP 200 (application/json)

```text
{
  "query": "CREATE TABLE items (id INT PRIMARY KEY, name STRING);\nSHOW TABLES",
  "results": [
    {
      "statement": "CREATE TABLE items (\n  id INT PRIMARY KEY,\n  name STRING\n)",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "table 'items' created",
      "timings": {"parse_us": 24, "execute_us": 5394}
    },
    {
      "statement": "SHOW TABLES",
      "columns": [
        {"name": "name", "type": "STRING"},
        {"name": "kind", "type": "STRING"},
        {"name": "partition", "type": "STRING"},
        {"name": "columns", "type": "INT"},
        {"name": "rows", "type": "LONG"}
      ],
      "dataset": [
        ["items", "relational", "NONE", 2, 0]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 24, "execute_us": 16}
    }
  ],
  "timings": {"parse_us": 48, "execute_us": 5410}
}
```

**HTTP: The same name again**

```http
POST /api/databases?name=help_twice
###
POST /api/databases?name=HELP_TWICE
```

Response:

`POST /api/databases?name=help_twice`

HTTP 200 (application/json)

```text
{"name": "help_twice", "created": true}
```

`POST /api/databases?name=HELP_TWICE`

HTTP 409 (application/json)

```text
{"error": "database 'help_twice' already exists"}
```

**HTTP: A name with a space**

```http
POST /api/databases
Content-Type: application/x-www-form-urlencoded

name=my shop
```

Response:

HTTP 400 (application/json)

```text
{"error": "bad database name 'my shop': use only letters, digits, _ and -"}
```

```bash
curl -s -X POST "http://127.0.0.1:9900/api/databases?name=shop"
```

```powershell
Invoke-RestMethod -Method Post "http://127.0.0.1:9900/api/databases" -ContentType "application/json" -Body '{"name":"shop"}'
```

```js
const res = await fetch("http://127.0.0.1:9900/api/databases", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ name: "shop" }),
});
console.log(res.status, await res.json());
```

<a id="delete-api-databases"></a>

## DELETE /api/databases/<name>

Syntax:

```sql
DELETE /api/databases/<name>
```

Drops a database. Its folder is **not deleted**: it moves to `<data folder>/_trash/<time in ms>-<name>`.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `<name>` | path | The database to drop | required |

| Answer field | Meaning |
|---|---|
| `name` | The database |
| `dropped` | `true` |
| `moved_to` | The folder in `_trash` where it went |

- **Status codes:** 200 dropped; 401/403 login or role; 404 no such database; 405 for `GET` (dropping needs `DELETE`); 409 a request is using it right now, try again.
- **Notes:** needs full rights, like creating. Dropping also removes every `GRANT` on that database. To get a dropped database back: stop the server and move its folder from `_trash` back into the data folder (with the old name). In SQL: `DROP DATABASE name`.

**HTTP: Create, drop, and the database is gone**

```http
POST /api/databases?name=help_scratch
###
DELETE /api/databases/help_scratch
###
GET /exec?db=help_scratch&query=SELECT 1
```

Response:

`POST /api/databases?name=help_scratch`

HTTP 200 (application/json)

```text
{"name": "help_scratch", "created": true}
```

`DELETE /api/databases/help_scratch`

HTTP 200 (application/json)

```text
{
  "name": "help_scratch",
  "dropped": true,
  "moved_to": "kdb-data/_trash/1792816943671-help_scratch"
}
```

`GET /exec?db=help_scratch&query=SELECT 1`

HTTP 404 (application/json)

```text
{"error": "database 'help_scratch' does not exist; create it with CREATE DATABASE help_scratch"}
```

**HTTP: A database that does not exist**

```http
DELETE /api/databases/help_never_made
```

Response:

HTTP 404 (application/json)

```text
{"error": "database 'help_never_made' does not exist"}
```

**HTTP: GET cannot drop**

```http
GET /api/databases/help_scratch
```

Response:

HTTP 405 (application/json)

```text
{"error": "method GET is not allowed here"}
```

```bash
curl -s -X DELETE "http://127.0.0.1:9900/api/databases/shop"
```

```powershell
(Invoke-RestMethod -Method Delete "http://127.0.0.1:9900/api/databases/shop").moved_to
```

```csharp
using var http = new HttpClient();
var res = await http.DeleteAsync("http://127.0.0.1:9900/api/databases/shop");
Console.WriteLine($"{(int)res.StatusCode} {await res.Content.ReadAsStringAsync()}");
```
