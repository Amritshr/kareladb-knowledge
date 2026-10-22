# TLS (https and sslmode=require)

> Encrypt both ports with one certificate - https:// for the HTTP API and the console, sslmode=require for PostgreSQL clients.

- Category: Users & security
- Keywords: TLS, SSL, https, certificate, cert, key, PEM, self-signed, --tls-cert, --tls-key, --tls-required, KDB_TLS_CERT, KDB_TLS_KEY, KDB_TLS_REQUIRED, tls_cert, tls_key, sslmode, require, verify-full, sslrootcert, sslnegotiation, direct, encryption, 28000, Secure cookie, curl -k, Lets Encrypt, openssl
- See also: [Keeping kdb serve safe](server-security.md), [PostgreSQL protocol (port 8832)](postgres-protocol.md), [kdb serve](cli-serve.md), [Logins, tokens and roles over HTTP](http-login.md), [API tokens](api-tokens.md)

With TLS on, everything between a client and KDB is encrypted: passwords, tokens and data. One certificate serves **both** ports.

| Port | Clients connect with |
|---|---|
| HTTP (9900) | `https://host:9900` (browsers, `curl`, HTTP libraries) |
| PostgreSQL (8832) | `sslmode=require` (or `verify-full`), also `sslnegotiation=direct` of PostgreSQL 17 |

- TLS 1.2 and 1.3 only. It needs a `kdb` built with OpenSSL: `kdb --version` shows `tls: OpenSSL ...` (the Docker image and the packages have it).
- Without TLS, keep KDB on `127.0.0.1` and put a web server with HTTPS in front, or use an SSH tunnel ([server security](server-security.md#https)).

<a id="turn-on"></a>

## Turn it on

Syntax:

```sql
kdb serve --tls-cert cert.pem --tls-key key.pem [--tls-required on|off]
kdb serve --tls-cert auto
kdb.conf:  "tls_cert": "/data/cert.pem", "tls_key": "/data/key.pem"
env:       KDB_TLS_CERT=/data/cert.pem  KDB_TLS_KEY=/data/key.pem  KDB_TLS_REQUIRED=on
```

| Setting | Meaning | Default |
|---|---|---|
| `--tls-cert FILE` | the certificate in PEM: the server's first, then the chain | off |
| `--tls-key FILE` | its private key in PEM (without a passphrase) | - |
| `--tls-cert auto` | KDB makes a **self-signed** certificate once, in `<data folder>/_tls/`, and keeps using it | - |
| `--tls-required on\|off` | `on`: plain connections are refused, except from this computer (`127.x`) | `on` |

- A flag wins, then `kdb.conf`, then the environment. They are read when the server starts; after renewing a certificate, restart the server.
- The start-up lines say what is used: `console https://...`, `postgres ... (TLS: sslmode=require ...)` and a `tls` line with the file.
- A wrong file stops the server with the reason, for example `a certificate needs its key too` or `the TLS key does not belong to the certificate`.
- Plain connections from `127.x` still work with `--tls-required on`, so a health check or a tool on the same computer needs no certificate.

```bash
kdb serve --data-dir kdb-data --bind 0.0.0.0 --token "long-random-secret-1" --tls-cert auto
```

<a id="auto"></a>

## A self-signed certificate (auto)

`--tls-cert auto` makes `kdb-cert.pem` and `kdb-key.pem` in `<data folder>/_tls/` the first time (EC P-256, valid 10 years, for `localhost`, `127.0.0.1` and the `--bind` address), and uses the same pair after every restart.

- The data is encrypted, but a client can not tell by itself that it talks to **your** server. Tell it which certificate to trust:
  - `curl --cacert kdb-data/_tls/kdb-cert.pem https://localhost:9900/health`
  - `psql "host=localhost port=8832 sslmode=verify-full sslrootcert=kdb-data/_tls/kdb-cert.pem ..."`
- `sslmode=require` and `curl -k` encrypt without checking the certificate.
- A browser warns once for a self-signed certificate. For people on the internet, use a real certificate (Let's Encrypt, or your company's) with `--tls-cert` and `--tls-key`.
- In Docker: `-e KDB_TLS_CERT=auto`. The pair is kept in the `/data` volume, so it survives a rebuild.

<a id="clients"></a>

## What changes for clients

| Client | Before | With TLS |
|---|---|---|
| browser, console | `http://host:9900` | `https://host:9900` |
| `curl` | `curl http://...` | `curl https://...` (`-k` or `--cacert` for self-signed) |
| psql, DBeaver, drivers | `sslmode=disable` | `sslmode=require`, or `verify-full` with the certificate |
| plain `http://` from another computer | answered | `400`: `This KDB server speaks HTTPS only: use https:// ...` |
| plain PostgreSQL from another computer | answered | SQLSTATE `28000`: `this server requires TLS: connect with sslmode=require` |

- Over https the login cookie is marked `Secure` (the browser sends it only over https). `GET /health` says `"tls": true` for a request that came over TLS.
- With `--tls-required off`, one port takes both: a client that starts with TLS gets TLS, a plain one gets plain.
- A PostgreSQL client that sends more bytes right after its SSL request, before the handshake, is disconnected (that is how a man in the middle could slip commands in; CVE-2021-23214 in PostgreSQL).

<a id="docker"></a>

## Docker

Inside a container KDB must listen on all addresses (`--bind 0.0.0.0`), so the published ports decide who can reach it:

| `docker run` | Reachable from |
|---|---|
| `-p 9900:9900 -p 8832:8832` | every computer that can reach this one |
| `-p 127.0.0.1:9900:9900 -p 127.0.0.1:8832:8832` | this computer only |

Through Docker's port mapping, clients reach KDB from Docker's own address, not from `127.x`: with TLS on, they must use TLS. The image's health check runs inside the container on `127.0.0.1`, so it keeps working.
