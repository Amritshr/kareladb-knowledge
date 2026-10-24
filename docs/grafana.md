# Grafana and Prometheus

> Draw KarelaDB data in Grafana through the PostgreSQL port, watch the server with Prometheus, and use the two ready dashboards.

- Category: Postgres protocol
- Keywords: Grafana, grafana-oss, dashboard, dashboards, panel, panels, Prometheus, scrape, /metrics, Telegraf, PostgreSQL data source, grafana-postgresql-datasource, data source, datasource, provisioning, $\_\_timeFilter, $\_\_timeGroup, $\_\_timeGroupAlias, $\_\_timeFrom, $\_\_timeTo, $\_\_unixEpochFilter, $\_\_unixEpochGroup, $\_\_interval, $\_\_rate\_interval, template variable, \_\_text, \_\_value, multi-value, candlestick, candles, OHLC, TimescaleDB, time\_bucket, array\_lower, function in FROM, kdb\_snapshot\_reads\_total, integrations/grafana, docker compose, outputs.http, chunked
- See also: [PostgreSQL protocol (port 8832)](postgres-protocol.md), [Health, info, check and backup over HTTP (metrics)](http-server-info.md#metrics), [Line protocol (POST /write)](line-protocol.md), [SAMPLE BY](sample-by.md), [LATEST ON](latest-on.md), [Performance tips](performance-tips.md), [API tokens](api-tokens.md), [Users and roles](users-and-roles.md)

Grafana draws charts from databases. KarelaDB works with it in two ways:

| What | How | Grafana data source |
|---|---|---|
| Your data: prices, trades, sensor readings | SQL over the [PostgreSQL port](postgres-protocol.md) (8832) | the built-in **PostgreSQL** data source |
| The server's health: requests, latency, memory | Prometheus reads [GET /metrics](http-server-info.md#metrics) | **Prometheus** |

Two ready dashboards, the data source files and a `docker-compose.yml` are in the folder `integrations/grafana` of the KarelaDB source. Everything on this page was run with Grafana 11.6.0 and Prometheus 3.1.0 on 2026-10-22: every panel of both dashboards came back with rows through Grafana's own `/api/ds/query`.

<a id="data-source"></a>

## Connect the PostgreSQL data source

In Grafana: **Connections**, **Data sources**, **Add data source**, **PostgreSQL**.

| Field | Value |
|---|---|
| Host URL | `127.0.0.1:8832`; Grafana in Docker and KarelaDB on the same computer: `host.docker.internal:8832`; in `docker-compose.yml`: `kareladb:8832` |
| Database name | a KarelaDB database, like `market` |
| Username | a KarelaDB user with `ROLE read` (below); without KarelaDB users, any name |
| Password | that user's password (the server's token also works, but it gives Grafana full rights: below) |
| TLS/SSL Mode | `disable` without TLS; `require` when `kareladb serve` runs with [TLS](tls.md) |
| Version | `14` (KarelaDB says it is PostgreSQL 14) |
| TimescaleDB | **off** (KarelaDB has no `time_bucket`; [macros](#macros)) |

**Save & test** answers `Database Connection OK`.

- Grafana only reads. Give it a user that may only read, so a panel can never change data. Anyone who may edit a panel can send any SQL through the data source, so with the server's token (`KARELADB_TOKEN`, `--token`, full rights) as the password they could `DROP` or `DELETE` anything: use the token only for a quick try on your own computer.

**Example: A read-only user for Grafana** (sample data: sample)

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER grafana WITH PASSWORD 'Grafana-reads-only-7' ROLE read;
SHOW USERS;
```

Result:

`CREATE USER admin WITH PASSWORD '***' ROLE admin`

```text
user 'admin' created with role admin
```

`CREATE USER grafana WITH PASSWORD '***' ROLE read`

```text
user 'grafana' created with role read
```

`SHOW USERS`

| name (STRING) | role (STRING) | grants (STRING) | created (TIMESTAMP) | changed (TIMESTAMP) | table_grants (STRING) | two_factor (BOOL) | statement_timeout (STRING) | priority (STRING) |
|---|---|---|---|---|---|---|---|---|
| admin | admin | NULL | 2026-10-24T06:40:10.959Z | 2026-10-24T06:40:10.959Z | NULL | false | NULL | NULL |
| grafana | read | NULL | 2026-10-24T06:40:11.015Z | 2026-10-24T06:40:11.015Z | NULL | false | NULL | NULL |

(2 rows)

- An API token is not a password for the PostgreSQL port ([API tokens](api-tokens.md)): Grafana logs in with the user's password.
- The query editor lists tables and columns for the **Builder** mode. KarelaDB answers the exact catalog SQL Grafana 11 sends (it reads the `search_path` with `array_lower` and with `string_to_array(...)` used as a table).

Instead of clicking, Grafana can read the data source from a file at start (`integrations/grafana/provisioning/datasources/kareladb.yaml`). Grafana fills `${...}` from its own environment, so the password is not in the file. Never put the server's token in Grafana's environment:

```yaml
apiVersion: 1
datasources:
  - name: KarelaDB
    type: grafana-postgresql-datasource
    uid: kareladb-pg
    url: ${KARELADB_PG_HOST}          # 127.0.0.1:8832
    user: grafana
    jsonData:
      database: ${KARELADB_DATABASE}  # market
      sslmode: disable
      postgresVersion: 1400
      timescaledb: false
    secureJsonData:
      password: ${KARELADB_GRAFANA_PASSWORD}   # the grafana user's (ROLE read)
```

<a id="macros"></a>

## The macros

Grafana changes its macros into plain SQL before it sends the query. The table shows what KarelaDB receives for a dashboard showing 2026-09-09 to 2026-09-11.

| Macro | KarelaDB receives | Works |
|---|---|---|
| `$__timeFilter(time)` | `time BETWEEN '2026-09-09T00:00:00Z' AND '2026-09-11T00:00:00Z'` | yes |
| `$__timeFrom()`, `$__timeTo()` | `'2026-09-09T00:00:00Z'`, `'2026-09-11T00:00:00Z'` | yes |
| `$__time(time)` | `time AS "time"` | yes |
| `$__timeEpoch(time)` | `extract(epoch from time) as "time"` | yes |
| `$__timeGroup(time, 1h)` | `floor(extract(epoch from time)/3600)*3600` | yes, on the column engine |
| `$__timeGroupAlias(time, 1h)` | the same with `AS "time"` | yes, on the column engine |
| `$__timeGroup(time, 1h, 0)`, `NULL`, `previous` | the same; Grafana fills the missing buckets itself | yes |
| `$__unixEpochFilter(col)`, `$__unixEpochFrom()`, `$__unixEpochTo()` | `col >= 1788912000 AND col <= 1789084800` | yes, for a column of whole seconds |
| `$__unixEpochGroup(col, 1h)`, `$__unixEpochGroupAlias` | `floor((col)/3600)*3600` | yes |
| `$__interval`, `$__interval_ms` | `2m`, `120000`: the width of one point on the panel | yes |
| TimescaleDB on: `$__timeGroup` as `time_bucket(...)` | `time_bucket('3600.000s',time)` | **no**: keep TimescaleDB off |

- `$__unixEpochFilter(extract(epoch from time))` does not work: Grafana's macro reader stops at the first `)`. Use `$__timeFilter(time)` on a time column.
- `$__timeGroup` is the same SQL for every database, so it comes from Grafana's own code. KarelaDB sees the shape `floor(extract(epoch from col)/N)*N` and groups it in the column engine like `date_trunc`, with exactly the rows the row-by-row engine gives (4 million rows into 3,169 five-minute buckets: 34 ms instead of 6.2 s). That is for buckets of whole seconds and of 1/2, 1/4 or 1/8 second. A bucket like `0.1` (Grafana's `100ms`, `50ms`, `1ms` intervals) is not exact in a computer's floating point, so `floor(.../0.1)` must be worked out row by row to give the same edges as PostgreSQL; such a query runs on the row engine. A panel **Min interval** of `1s` keeps every panel on the fast path.

The panel query and what reaches KarelaDB, run on the sample data:

```text
SELECT $__timeGroupAlias(time, 1h), symbol AS metric, last(close) AS close
FROM ochl_minutes
WHERE $__timeFilter(time)
GROUP BY 1, 2
ORDER BY 1
```

**Example: $__timeGroupAlias(time, 1h) as KarelaDB receives it** (sample data: sample)

```sql
SELECT floor(extract(epoch from time)/3600)*3600 AS "time", symbol AS metric, last(close) AS close
FROM ochl_minutes
WHERE time BETWEEN '2026-09-09T00:00:00Z' AND '2026-09-11T00:00:00Z'
GROUP BY 1, 2
ORDER BY 1
LIMIT 6;
```

Result:

| time (DOUBLE) | metric (SYMBOL) | close (DOUBLE) |
|---|---|---|
| 1788930000 | CITY | 507.8 |
| 1788930000 | COAST | 392.9 |
| 1788933600 | CITY | 506 |
| 1788933600 | COAST | 387.7 |
| 1788937200 | CITY | 509.4 |
| 1788937200 | COAST | 382.3 |

(6 rows)

(The `LIMIT 6` only keeps this page short.) `time` comes back as seconds since 1970, which Grafana reads as a time.

<a id="formats"></a>

## Time series and table panels

| Format (under the query) | What the query must give |
|---|---|
| **Time series** | a column named `time` (a `TIMESTAMP`, or seconds since 1970), then number columns. A text column named `metric` makes one line per value (`symbol AS metric`). Rows sorted by `time`. |
| **Table** | any columns; Grafana shows them as they come |

- Several numbers per row without a `metric` column make one line per number column.
- A `TIMESTAMP` column is sent as PostgreSQL `timestamp` (UTC). Set the dashboard's time zone, not the query's.

<a id="variables"></a>

## Template variables

A variable is a list the dashboard user picks from. Its query runs over the same data source.

| Variable query | Gives |
|---|---|
| `SELECT DISTINCT symbol FROM ochl_minutes ORDER BY 1` | one value per row |
| `SELECT name AS __text, symbol AS __value FROM securities ORDER BY symbol` | `__text` is shown, `__value` goes into the SQL |

**Example: A variable with names shown and symbols used** (sample data: sample)

```sql
SELECT name AS __text, symbol AS __value FROM securities ORDER BY symbol;
```

Result:

| __text (STRING) | __value (SYMBOL) |
|---|---|
| Acme Investment Company | ACME |
| City Bank Limited | CITY |
| Coastal Bank Limited | COAST |
| Northwind Telecom Limited | TELCO |
| Volt River Hydropower Limited | VOLT |

(5 rows)

How Grafana puts a variable into the SQL:

| Variable | Write | KarelaDB receives |
|---|---|---|
| one value | `symbol = '$symbol'` | `symbol = 'CITY'` |
| multi-value or **All** | `symbol IN ($symbols)` | `symbol IN ('CITY','COAST')` (Grafana adds the quotes) |

**Example: A multi-value variable as KarelaDB receives it** (sample data: sample)

```sql
SELECT symbol, sum(quantity) AS volume, sum(amount) AS amount
FROM trade_log
WHERE date BETWEEN '2026-09-09T00:00:00Z' AND '2026-09-11T00:00:00Z' AND symbol IN ('CITY','COAST')
GROUP BY symbol
ORDER BY symbol;
```

Result:

| symbol (SYMBOL) | volume (LONG) | amount (DOUBLE) |
|---|---|---|
| CITY | 2420 | 1247230 |
| COAST | 3070 | 1227510 |

(2 rows)

<a id="candles"></a>

## Candles with SAMPLE BY

[SAMPLE BY](sample-by.md) cuts the time into equal buckets and is the fastest way to draw candles: one bucket per point of the panel with `SAMPLE BY $__interval`. Give the panel a **Min interval** of the data's own step (`1m` for one-minute candles), so a narrow time range does not ask for buckets smaller than the data. Use Grafana's **Candlestick** panel: it finds the columns `open`, `high`, `low`, `close` and `volume` by name.

```text
SELECT time, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE $__timeFilter(time) AND symbol = '$symbol'
SAMPLE BY $__interval
```

**Example: Thirty-minute candles of CITY, as KarelaDB receives them** (sample data: sample)

```sql
SELECT time, first(open) AS open, max(high) AS high, min(low) AS low, last(close) AS close, sum(volume) AS volume
FROM ochl_minutes
WHERE time BETWEEN '2026-09-09T00:00:00Z' AND '2026-09-11T00:00:00Z' AND symbol = 'CITY'
SAMPLE BY 30m
LIMIT 5;
```

Result:

| time (TIMESTAMP) | open (DOUBLE) | high (DOUBLE) | low (DOUBLE) | close (DOUBLE) | volume (DOUBLE) |
|---|---|---|---|---|---|
| 2026-09-09T05:00:00.000Z | 512 | 512.4 | 509.8 | 510.7 | 13730 |
| 2026-09-09T05:30:00.000Z | 510.7 | 511.5 | 507 | 507.8 | 22270 |
| 2026-09-09T06:00:00.000Z | 507.8 | 507.8 | 504.2 | 504.8 | 24120 |
| 2026-09-09T06:30:00.000Z | 504.8 | 506.3 | 504 | 506 | 20990 |
| 2026-09-09T07:00:00.000Z | 506 | 508.9 | 505.8 | 507.6 | 25210 |

(5 rows)

<a id="fast-panels"></a>

## Fast panels

A dashboard runs every panel's query on each refresh, for every person looking at it. These keep each query short:

| Do | Why |
|---|---|
| `WHERE $__timeFilter(time)` on the table's [designated time column](partitions-and-dedup.md) | only the partitions in the time range are read ([EXPLAIN](explain.md) says "1 of 2 partitions") |
| `SAMPLE BY $__interval` or `$__timeGroupAlias(time, $__interval)` | one row per point of the panel, worked out in the column engine; never thousands of raw rows for Grafana to thin out |
| `symbol = '$symbol'` or `symbol IN ($symbols)` on a `SYMBOL` column | a SYMBOL compare is a number compare ([SYMBOL columns](performance-tips.md#symbol)) |
| [LATEST ON](latest-on.md) for "last price" tables and stat panels | reads the newest rows of each symbol, not the whole range |
| A **Min interval** on the panel, and `LIMIT` on table panels | a narrow range or a big table cannot ask for a million rows |
| TimescaleDB off, no `time_bucket` | `$__timeGroup` is grouped by the column engine; `time_bucket` does not exist |

**Example: Only the day in the time range is read, in the column engine** (sample data: sample)

Setup:

```sql
CREATE TABLE ticks (time TIMESTAMP, symbol SYMBOL, price DOUBLE, qty LONG) TIMESERIES(time) PARTITION BY DAY;
INSERT INTO ticks SELECT CAST(1788912000000 + (x - 1) * 60000 AS TIMESTAMP), CASE WHEN x % 2 = 0 THEN 'CITY' ELSE 'COAST' END, 100 + x % 7, x % 50
FROM long_sequence(2880);
```

```sql
EXPLAIN SELECT floor(extract(epoch from time)/300)*300 AS "time", symbol AS metric, sum(qty) AS volume
FROM ticks
WHERE time BETWEEN '2026-09-10T00:00:00Z' AND '2026-09-10T23:59:59Z'
GROUP BY 1, 2
ORDER BY 1;
```

Result:

| plan (STRING) |
|---|
| scan table ticks (1 of 2 partitions, about 2880 rows) |
| build 3 of 4 stored column(s) per row: time, symbol, qty |
| filter while scanning: 1 condition(s) |
| group by 2 key(s), 1 aggregate(s) |
| sort by 1 key(s) |
| engine: column |

(6 rows)

(Two days of one-minute ticks, so the table has two day partitions.)

- A table with a computed column (`amount DOUBLE AS (quantity * rate)`, like the sample's `trade_log`) is still grouped row by row, even when the query does not read that column; `EXPLAIN` says `engine: row`.
- Grafana's relative ranges (`now-6h`) give new times on every refresh, so the [result cache](performance-tips.md#result-cache) seldom answers them. A fixed range (a past day) is answered from the cache after the first look.
- The PostgreSQL port has its own line in the server dashboard (statement latency, `pg`). A slow panel shows up in `GET /api/slow-queries` with its full SQL, macros already replaced.

<a id="prometheus"></a>

## Prometheus: the server's health

[GET /metrics](http-server-info.md#metrics) gives the server's counters in Prometheus's text format: requests, statement latency (HTTP and PostgreSQL), memory, result cache, WAL and checkpoint writes, lock waits, snapshot reads per database (`kdb_snapshot_reads_total`), slow statements and disk use. A scrape never waits for a database lock. Metric names start with `kdb_` and stay that way, so alerts and dashboards keep working.

`/metrics` needs only the `read` right, so never give Prometheus the server's token. Make a read-only user; Prometheus logs in with its name and password, or with an [API token](api-tokens.md) of it:

**Example: A token for Prometheus** (sample data: sample)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER monitor WITH PASSWORD 'Monitor-reads-only-9' ROLE read;
```

```sql
CREATE TOKEN prometheus FOR USER monitor;
```

Result:

| name (STRING) | user (STRING) | token (STRING) | expires (TIMESTAMP) |
|---|---|---|---|
| prometheus | monitor | kdbt_Hek8EHkI0eOSgLPa9_w3JpN95AxPbzoe5qUZoL8FEl0 | NULL |

(1 row)

```text
token 'prometheus' for user 'monitor' created: copy it now, it is shown only this once. Send it as Authorization: Bearer <token>
```

Put the user's password in a file next to `prometheus.yml`, one line, and point the scrape job at the HTTP port:

```yaml
scrape_configs:
  - job_name: kareladb
    metrics_path: /metrics
    basic_auth:
      username: monitor
      password_file: /etc/prometheus/kareladb_password
    # or the token: authorization: { type: Bearer, credentials_file: /etc/prometheus/kareladb_token }
    static_configs:
      - targets: ["127.0.0.1:9900"]
```

- In Prometheus, **Status**, **Targets** shows the job `up`. A `401` there is a wrong or missing token.
- Add Prometheus to Grafana as a **Prometheus** data source (`http://127.0.0.1:9090`).
- Only open databases have per-database lines (`database="market"`); counters start at 0 when the server starts, which `rate()` handles.

<a id="dashboards"></a>

## The ready dashboards

| File in `integrations/grafana/dashboards` | Data source | Panels |
|---|---|---|
| `kareladb-server.json` (KarelaDB server) | Prometheus | version, uptime, requests per second and by status, HTTP latency p50 / p95 / p99, statement latency by protocol, statements and errors, slow statements, lock waits, memory by kind, resident memory and limit, processor, WAL and checkpoint writes, snapshot reads, result cache and partition loads, disk use |
| `kareladb-market.json` (KarelaDB market example) | PostgreSQL | candles of a symbol (SAMPLE BY), last daily close (LATEST ON), volume per day, close by symbol (`$__timeGroupAlias` with fill), traded amount, trades; variables for the symbol and a multi-value symbol list |

The market dashboard reads the help's [sample data](sample-data.md) in a database named `market` ([quick start](quick-start.md#sample-data) loads it); its time range is 2026-09-09 to 2026-09-11, the days the sample holds.

**Import one by hand:** **Dashboards**, **New**, **Import**, upload the JSON file. Each dashboard has a data source picker at the top (`KarelaDB`, `Prometheus`); pick yours there.

**Load them at start (provisioning):** mount the folders into Grafana:

| Folder | Mount at |
|---|---|
| `integrations/grafana/provisioning` | `/etc/grafana/provisioning` |
| `integrations/grafana/dashboards` | `/var/lib/grafana/dashboards/kareladb` |

They appear in a **KarelaDB** folder. Set `KARELADB_PG_HOST`, `KARELADB_DATABASE`, `KARELADB_GRAFANA_PASSWORD` (the read-only user's) and `KARELADB_PROMETHEUS_URL` in Grafana's environment.

**All three together:** `integrations/grafana/docker-compose.yml` builds the `kareladb` image from the source and starts KarelaDB, Prometheus and Grafana. A one-off step makes the users `admin`, `grafana` (`ROLE read`) and `monitor` (`ROLE read`); only KarelaDB and that step see the server's token:

```bash
cd integrations/grafana
export KARELADB_TOKEN=$(openssl rand -hex 32)
export KARELADB_ADMIN_PASSWORD=$(openssl rand -hex 16)
export KARELADB_GRAFANA_PASSWORD=$(openssl rand -hex 16)
export KARELADB_MONITOR_PASSWORD=$(openssl rand -hex 16)
printf %s "$KARELADB_MONITOR_PASSWORD" > prometheus/kareladb_password
docker compose up -d --build
# Grafana: http://127.0.0.1:3000 (admin / admin)
```

Then load the sample data into the database `market` and open **Dashboards**, **KarelaDB**. `node verify.mjs http://admin:<password>@127.0.0.1:3000` runs every panel query and every variable through Grafana and says which ones gave rows.

<a id="telegraf"></a>

## Telegraf

Telegraf collects metrics (processor, memory, disks, many services) and can write them to KarelaDB with the [line protocol](line-protocol.md). Each measurement becomes a table that `POST /write` makes by itself; Grafana then reads it with SQL. Use Telegraf's **http** output:

```toml
[[outputs.http]]
  url = "http://127.0.0.1:9900/write?db=metrics&precision=ns"
  method = "POST"
  data_format = "influx"
  [outputs.http.headers]
    Authorization = "Bearer ${KARELADB_TELEGRAF_TOKEN}"   # an API token of a user with write on metrics
    Content-Type = "text/plain; charset=utf-8"
```

- Make the database first (`CREATE DATABASE metrics`); `/write` makes tables, not databases.
- Telegraf's `influxdb` and `influxdb_v2` outputs send the body in chunks without a length, which KarelaDB answers with `501 chunked request bodies are not supported`; the `http` output sends the length. The `influxdb_v2` output also sends `Authorization: Token ...`, and KarelaDB takes only `Bearer`.
- Tested with Telegraf 1.33.0: `inputs.cpu` and `inputs.mem` made the tables `cpu` and `mem`, with a `timestamp` column for `$__timeFilter(timestamp)`.

<a id="troubleshooting"></a>

## When it does not work

| Grafana says | Why | Fix |
|---|---|---|
| `password authentication failed for user "grafana"` | wrong password, or a user that is not a KarelaDB user on a server with users | the user's password, or the token on a server without users |
| `pq: SSL is not enabled on the server` | TLS/SSL Mode `require` on a server without TLS | `disable`, or turn [TLS](tls.md) on |
| `connections from other computers need a password` | no token and no users, and Grafana runs in Docker (another address) | start the server with a token or make a user |
| `database 'x' does not exist` | the Database name field | a database from `SHOW DATABASES` |
| `unknown function 'time_bucket'` | TimescaleDB is on in the data source | turn it off; `$__timeGroup` works without it |
| `db has no time column` | Time series format without a `time` column | `AS "time"`, `$__time(col)` or `$__timeGroupAlias(...)` |
| Prometheus target `down`, `401` | a wrong password in `password_file`, or a wrong token | the password or a token of a user with `read` |
