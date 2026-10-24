# Keeping kareladb serve safe

> Keep the server on 127.0.0.1, use users or a token, put HTTPS in front, and pick strong passwords.

- Category: Users & security
- Keywords: security, safe, secure, KARELADB\_TOKEN, Docker, internet, vps, firewall, --bind, --token, bind address, 0.0.0.0, 127.0.0.1, localhost, access token, login, log in, logout, HTTP Basic, Bearer, cookie, kdb\_login, kdb\_auth, X-KDB-CSRF, HTTPS, TLS, SSL, certificate, reverse proxy, Caddy, nginx, SSH tunnel, X-Forwarded-Proto, failed logins, too many failed logins, 429, 401, 403, cross-site, CSRF, DNS rebinding, password rules, SCRAM, checklist
- See also: [Users and roles](users-and-roles.md), [Security functions](functions-security.md), [kareladb serve](cli-serve.md), [kareladb user](cli-users.md), [Logins, tokens and roles over HTTP](http-login.md), [PostgreSQL protocol (port 8832)](postgres-protocol.md), [Backup, check, repair and restore](backup-and-safety.md)

`kareladb serve` gives full access to your data over the network: the HTTP API, the web console and the PostgreSQL port. This page says how to keep strangers out.

The short rules:

1. Keep the default `--bind 127.0.0.1`. Then only programs on the same computer can connect.
2. Create **users** with long passwords (see [Users and roles](users-and-roles.md)). Then every request needs a login.
3. For access from other computers, turn on [TLS](tls.md) (`--tls-cert`: https and `sslmode=require`), or put a web server with HTTPS in front, or use an SSH tunnel.
4. Keep the data folder and the backups private: whoever can read them can read everything, without a login.

| Server | Login needed? |
|---|---|
| `--bind 127.0.0.1` (default), no `--token`, no users | **No.** Only programs on this computer can connect. |
| the data folder has users | **Yes**, for every request except `/health`, `POST /api/login` and the console page itself |
| started with `--token <secret>` | **Yes.** The token works like an admin. With users too, both work. |
| `--bind 0.0.0.0` (or any address that is not `127.x`) with no token and no users | **Refused:** `kareladb serve` does not start |

**HTTP: Is a login needed on this server?**

```http
GET /health
```

Response:

HTTP 200 (application/json)

```text
{
  "status": "ok",
  "version": "0.2.0-dev",
  "product": "KarelaDB",
  "server_time_ms": 1792825098244,
  "auth_required": false,
  "login": false,
  "tls": false,
  "ready": true,
  "standby": false,
  "role": "leader"
}
```

<a id="bind"></a>

## --bind

Syntax:

```sql
kareladb serve [--bind 127.0.0.1 | --bind <address>] ...
```

The network address the server listens on. It is used for the HTTP port and the PostgreSQL port.

| Value | Meaning |
|---|---|
| `127.0.0.1` | the default. Only programs on the same computer can connect. |
| `0.0.0.0` | every network card: other computers can connect too |
| one address, like `192.168.1.20` | only that network card |

- **Returns:** nothing; the start-up lines show the console address.
- **Notes:**
  - Any address that does not start with `127.` needs users or `--token`, or `kareladb serve` refuses to start. (`localhost` counts as local.)
  - Your app's backend on the same VPS reaches KarelaDB on `127.0.0.1`. You almost never need `0.0.0.0`.
  - The [Docker image](install-packages.md#docker) must listen on `0.0.0.0`, because a published port cannot reach the container's own `127.0.0.1`. So it refuses to start without `KARELADB_TOKEN` (`-e KARELADB_TOKEN=<token>`). Publish the port only to where it is needed, for example `-p 127.0.0.1:9900:9900`.
  - Also close ports 9900 (HTTP) and 8832 (PostgreSQL) in the firewall. Open only SSH, 80 and 443.
  - Without a login, KarelaDB still refuses requests that a browser marks as coming from another web site, and requests whose `Host` is not `localhost` or `127.x` (a trick called DNS rebinding). So a bad web page open in your browser can not reach your local server.

**Command line: 0.0.0.0 without users and without a token is refused** (shows an error)

```bash
kareladb serve --bind 0.0.0.0
```

Output:

```text
cold store 'archive': folder ./cold-archive
error: --bind 0.0.0.0 without --token and without users would let anyone who can reach this computer
read, change and delete every database. Do one of these first:
  1. create an admin user:   kareladb user add <name> --role admin
  2. or start with a secret:  --token <long random text>
  3. or keep --bind 127.0.0.1 and put a web server with HTTPS in front of KarelaDB
See docs/tutorial/16-users-passwords-security.md
```

exit code 1

**HTTP: A request from another web site is refused**

```http
GET /exec?query=SELECT%201
Sec-Fetch-Site: cross-site
```

Response:

HTTP 403 (application/json)

```text
{"error": "cross-site requests are not allowed"}
```

**HTTP: A request sent by a page of another web site is refused**

```http
GET /exec?query=SELECT%201
Origin: http://evil.example.com
```

Response:

HTTP 403 (application/json)

```text
{"error": "cross-origin requests are not allowed"}
```

<a id="token"></a>

## --token

Syntax:

```sql
kareladb serve --token <long random text>
```

A secret that every request must send, as `Authorization: Bearer <token>`. It gives **full** rights (like an admin on every database).

| Argument | Type | Meaning |
|---|---|---|
| `<token>` | text | the secret. Use 32 or more random characters, for example from `SELECT random_token()`. |

- **Returns:** nothing; the start-up line `access` says `token required`.
- **Notes:**
  - The token is **one** secret for everybody. Users are better: each program gets its own password and only the role it needs, and you can remove one user without changing the others.
  - With users **and** a token, both work. PostgreSQL clients can use the token as the password.
  - Other people on the same computer can see command lines (`ps`, Task Manager). Start the server from a file only you can read (for example a systemd unit), or use users.
  - The web console asks for the token and the server keeps it in an `HttpOnly`, `SameSite=Strict` cookie (`kdb_auth`), so page scripts cannot read it. Changes sent with that cookie also need the `X-KDB-CSRF` header ([CSRF](http-login.md#csrf)); the console sends it by itself.

**Example: Make a strong token or password**

```sql
SELECT random_token() AS token_for_kdb_serve, random_token(24) AS password_for_a_program;
```

Result:

| token_for_kdb_serve (STRING) | password_for_a_program (STRING) |
|---|---|
| IC_XZ83_TwvAqxj-73nk9ZgcycLhjhHIiPwZVlBl9SE | S7P9pzdNNfTGLoR5TvqA453aKdUKn9MP |

(1 row)

**Command line: A server with a token**

```bash
kareladb serve --token 3kD9vQx7LmN2pR8sT4wY6zA1bC5eF0gH
```

Output:

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      ./kdb-data (from KDB_DATA_DIR; one folder per database)
  default   default (used when a request names no database)
  backups   ./kdb-data/_backups/<database name> (from default)
  access    token required
  capacity  32 HTTP threads (default), 500 PostgreSQL connections (default), lock wait 5 s (default)
  lanes     reads using 100 ms of CPU (three times in a row) wait for one of 16 heavy slots, at most 16 HTTP in line (--lanes on)
  reads     32 reads run at once (the CPUs, at least 2; follows the CPU limit), the rest wait in line (--read-slots)
  commits   synced to disk before they are confirmed (--sync-commits always)
  time zone Asia/Katmandu (the computer's); also timers and backup schedules
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    26.95 GB for the whole process (85% of the machine's memory); table data 512.0 MB of it (--memory)
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log on (SHOW AUDIT)
  logs      slow queries >= 1000 ms to ./kdb-data/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  the default database is created when it is first used

Press Ctrl+C to stop.
```

<a id="logins"></a>

## Users and logins

Syntax:

```sql
HTTP Basic:   Authorization: Basic base64(user:password)
Log in once:  POST /api/login  {"user": "...", "password": "..."}   ->  token
Then:         Authorization: Bearer <token>     (or the kdb_login cookie in a browser)
Log out:      POST /api/logout
```

When the data folder has users, every request needs a login. Create users with [CREATE USER](users-and-roles.md#create-user) or [kareladb user add](cli-users.md). The details of each route are in [HTTP login](http-login.md).

| Way | Used by | Notes |
|---|---|---|
| **HTTP Basic** (user and password on each request) | scripts, `curl -u` | KarelaDB remembers a good password for 10 minutes, so it is not slow |
| **`POST /api/login`**, then `Authorization: Bearer <token>` | apps | the token is random (256 bits); KarelaDB keeps only its SHA-256, in memory |
| **Cookie** `kdb_login` | the web console | `HttpOnly` (page scripts can not read it) and `SameSite=Strict` (other sites can not use it). A change also needs the `X-KDB-CSRF` header ([CSRF](http-login.md#csrf)). |
| **SCRAM-SHA-256** | PostgreSQL drivers on port 8832 | the password never crosses the network |

- **Returns:** a wrong login gets HTTP 401 `{"error":"wrong user name or password","login":true}`. A statement the user may not run gets HTTP 403 (see [roles](users-and-roles.md#roles)).
- **Notes:**
  - A login ends after **12 hours**, at log out, when the server restarts, and when the user's password changes or the user is dropped.
  - **Failed logins:** after 5 failures for one user from one address (or 20 from one address for any users), that address must wait: 1 second, then 2, 4, 8, ... up to 15 minutes. Meanwhile the answer is HTTP 429 `too many failed logins; try again in 1 s`. A good login ends the wait for that user.
  - Every failed login is written to the server's output with the user name and the address, never the password: `login failed: user 'admin' from 127.0.0.1 (wrong password; 5 failures in a row); next try allowed in 1 s`.
  - The answer for an unknown user takes as long as for a wrong password, so nobody can find out which names exist.
  - Behind a reverse proxy every request comes from `127.0.0.1`, so the waiting is shared by everyone who tries the same user name.
  - `kareladb sql` and `kareladb shell` never ask for a login. They open the files directly.
  - Users belong to a data folder. A server started with one database folder by its path (`kareladb serve D:\kdb\market`) has no users; use `--data-dir`.

**Command line: With a user, the server asks for a login**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
> Long-Admin-Passw0rd
kareladb serve
```

Output:

`> kareladb user add admin --role admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb serve`

```text
cold store 'archive': folder ./cold-archive
KarelaDB 0.2.0-dev
  console   http://127.0.0.1:9900
  data      ./kdb-data (from KDB_DATA_DIR; one folder per database)
  default   default (used when a request names no database)
  backups   ./kdb-data/_backups/<database name> (from default)
  access    login required (1 user)
  capacity  32 HTTP threads (default), 500 PostgreSQL connections (default), lock wait 5 s (default)
  lanes     reads using 100 ms of CPU (three times in a row) wait for one of 16 heavy slots, at most 16 HTTP in line (--lanes on)
  reads     32 reads run at once (the CPUs, at least 2; follows the CPU limit), the rest wait in line (--read-slots)
  commits   synced to disk before they are confirmed (--sync-commits always)
  time zone Asia/Katmandu (the computer's); also timers and backup schedules
  readers   read while a long trigger or CALL writes (--reader-yield on); idle open transaction rolled back after 30 s (default)
  memory    26.95 GB for the whole process (85% of the machine's memory); table data 512.0 MB of it (--memory)
  cpu       32 CPUs (the machine's); 16 query threads (half of the CPUs, follows the limit), limits checked every 10 s
  limits    statement timeout 1 min, result memory 1.00 GB, 5000000 groups, 32 statements per user
  safety    writes allowed; DROP TABLE kept 7 days (UNDROP TABLE); audit log on (SHOW AUDIT)
  logs      slow queries >= 1000 ms to ./kdb-data/_logs/slow_queries.jsonl; pg_stat_statements on; metrics at /metrics
  recovery  the default database is created when it is first used

Press Ctrl+C to stop.
```

**HTTP: A server without users has nothing to log in to**

```http
POST /api/login
Content-Type: application/json

{"user": "admin", "password": "Long-Admin-Passw0rd"}
```

Response:

HTTP 400 (application/json)

```text
{
  "error": "this server has no users yet; create one with CREATE USER <name> WITH PASSWORD '...' ROLE admin"
}
```

<a id="https"></a>

## HTTPS in front

Syntax:

```sql
browser  --HTTPS-->  Caddy or nginx (port 443)  --HTTP-->  kareladb serve on 127.0.0.1:9900
```

Over plain HTTP, anyone on the network path can read passwords and tokens. When people or programs on **other** computers must reach KarelaDB, either turn on KarelaDB's own [TLS](tls.md), or put a web server with HTTPS (a **reverse proxy**) in front and keep KarelaDB on `127.0.0.1`. A proxy also gets free certificates by itself and renews them.

- **Returns:** not a KarelaDB setting.
- **Notes:**
  - Caddy gets a free certificate by itself (see the first block below). With nginx, also send `X-Forwarded-Proto` (second block).
  - When the proxy sends `X-Forwarded-Proto: https`, KarelaDB marks its login cookie `Secure` (only sent over HTTPS).
  - KarelaDB still asks for the login behind the proxy. Create users first.
  - Even simpler for yourself: do not open the console to the internet at all. Use an **SSH tunnel** from your PC: `ssh -L 9900:127.0.0.1:9900 you@your-vps`, then open `http://127.0.0.1:9900` on your PC.
  - A proxy does not cover the PostgreSQL port. Turn on KarelaDB's [TLS](tls.md) for it (`sslmode=require`), or reach it through an SSH tunnel.

Caddy, file `/etc/caddy/Caddyfile`:

```text
kdb.example.com {
    reverse_proxy 127.0.0.1:9900
}
```

nginx, inside the `server { listen 443 ssl; ... }` block:

```text
location / {
    proxy_pass http://127.0.0.1:9900;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

<a id="password-rules"></a>

## Password rules

Syntax:

```sql
at least 12 characters, not the user name, at most 1024 bytes;  long and random is best
```

What KarelaDB needs from the password of a database user, and what is wise.

| Rule | Detail |
|---|---|
| KarelaDB refuses | fewer than 12 characters, the user name itself, or more than 1024 bytes |
| Wise for people | 16 or more characters; a few random words are easy to remember. Admins: also [two-factor login](two-factor-login.md) |
| Wise for programs | 20 or more random characters from a password manager or `random_token(24)`; programs keep them in their settings |
| Never | the same password as your email or bank; a password on the command line; a password in a web page's JavaScript |

- **Returns:** a too short password gets `the password is too short: use at least 12 characters (a password manager can make a long random one)`. Passwords set before this rule keep working.
- **Notes:**
  - KarelaDB keeps two things per user: a PBKDF2-SHA-256 hash with 600,000 rounds (slow to guess), and a SCRAM-SHA-256 secret with only 4,096 rounds (the PostgreSQL default, faster to guess). This is why database users should have **long random** passwords.
  - `kareladb user add` reads the password from a prompt or a pipe (`echo "the password" | kareladb user add report --role read`), never from the command line.
  - SQL text with `PASSWORD '...'` may end up in your own scripts and logs. The web console's history and KarelaDB's statement echo show `PASSWORD '***'`.
  - The passwords of **your app's** users are a different matter: store them with [password_hash](functions-security.md#password-hash).

**Example: A too short password is refused** (shows an error)

```sql
CREATE USER admin WITH PASSWORD 'ktm2026' ROLE admin;
```

Result:

Error: `the password is too short: use at least 12 characters (a password manager can make a long random one)`

<a id="checklist"></a>

## Checklist

Syntax:

```sql
bind 127.0.0.1  +  users  +  HTTPS or SSH tunnel  +  firewall  +  private data and backups
```

A small Linux VPS with your app and KarelaDB on the same machine. [Chapter 16](../tutorial/16-users-passwords-security.md) shows each step with commands.

| Check | Why |
|---|---|
| KarelaDB runs as its own system user; data and backups are `chmod 700` (on Linux and macOS KarelaDB makes new files `0600` and new folders `0700` itself; folders made by an older version keep their rights, so `chmod -R go-rwx` them once) | a file copy needs no login |
| `--bind 127.0.0.1` (the default); ports 9900 and 8832 closed in the firewall | strangers can not even connect |
| an `admin` user with a long random password; each app has its own user with the smallest role | one leaked password does not open everything |
| [TLS](tls.md), HTTPS (Caddy or nginx) or an SSH tunnel for the console and the PostgreSQL port | passwords are not sent in plain text |
| every `kareladb` program updated before the first user was created | old versions do not know users and would serve without a login |
| app passwords stored with `password_hash`; session tokens random and stored as `sha256` | a stolen table does not give the passwords |
| nightly backup copied to another place, restore tested | backups hold the password hashes: keep them private too |
| server output checked for `login failed` now and then | see who tries to guess |

- **Returns:** not a statement.
- **Notes:** rights are per database; [table rights](table-rights.md) change them for single tables (no column or row rights). Logins are kept in the data folder (hashes only), so a restart logs nobody out. Give each app its own [API token](api-tokens.md). More protection (timeouts, audit log, scheduled backups): [protection](protection.md).
