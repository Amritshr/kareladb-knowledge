# 16. Users, passwords and security

- Category: Tutorial

## What you will learn

- **Part A.** How your app lets people register and log in, with KDB as the database: a users table, `password_hash`, `password_verify`, session tokens.
- **Part B.** Database users: who may use the KDB server itself, and what each one may do (roles).
- **Part C.** A checklist for a small VPS on the internet.

Chapter 15 uses the same register and login in a small accounting example. Part A is about the people who use **your app** (customers, staff). Part B is about the **programs and people that connect to KDB** (your app's backend, you in the web console, a report script). They are two different things. Most apps need both.

---

## Part A: users of your app

### Never store plain passwords

Do not put the password itself in a table. If somebody gets a copy of the database (a stolen backup, a bug, an old disk), they get every password. Many people use the same password for email and bank. So a leak hurts them far beyond your app.

Store a **password hash** instead:

- A hash is made from the password, but the password cannot be made back from the hash.
- KDB's `password_hash()` is **slow on purpose** (about 0.05 to 0.4 seconds). One login is still fast. But an attacker who stole the hashes can only try a few guesses per second, not billions.
- Each hash has a **random salt**. Two users with the same password get different hashes.

| Do | Do not |
|---|---|
| `password_hash('the password')` when the user registers | store the password, or `sha256(password)` (far too fast to guess) |
| `password_verify('typed password', password_hash)` when the user logs in | compare hashes with `=` (every hash has its own salt, so it never matches) |
| give the user a random session token after login | send the password again with every request |

### The tables

```sql
CREATE TABLE app_users (
  id INT PRIMARY KEY AUTO,
  email STRING NOT NULL UNIQUE,
  password_hash STRING NOT NULL,
  created_at TIMESTAMP DEFAULT now()
);
CREATE TABLE app_sessions (
  token_hash STRING PRIMARY KEY,
  user_id INT NOT NULL REFERENCES app_users(id),
  expires_at TIMESTAMP NOT NULL
);
```

- `email ... UNIQUE`: the same email cannot register twice.
- `app_sessions` keeps the **SHA-256 of the token**, not the token. Then a leaked copy of this table cannot be used to log in either.

### Register

Your backend receives the email and the password (over HTTPS). It runs:

```sql
INSERT INTO app_users (email, password_hash) VALUES ('sita@example.com', password_hash('correct horse battery'));
SELECT id, email, password_hash FROM app_users;
```

```text
1 row(s) inserted
id | email            | password_hash
---+------------------+-------------------------------------------------
 1 | sita@example.com | $pbkdf2-sha256$i=600000$TJZOjybZUId98CTZjROu0...
(1 row, 0.1 ms)
```

The hash looks like `$pbkdf2-sha256$i=600000$<salt>$<hash>`. It says how it was made (PBKDF2 with SHA-256, 600,000 rounds, as OWASP advises), so KDB can check it later, even if the default changes.

KDB hashes the password **before** the `INSERT` locks the table, so other writers of `users` do not wait for the slow hash. The statement KDB shows back has the hash, not the password, and the console's history saves `password_hash('***')`.

If the email is already used, the `INSERT` fails because of `UNIQUE`. Tell the user "this email is already registered".

### Log in

```sql
SELECT id FROM app_users
WHERE email = 'sita@example.com' AND password_verify('correct horse battery', password_hash);
```

```text
id
--
 1
(1 row, 53.5 ms)
```

With a wrong password there is no row:

```sql
SELECT id FROM app_users
WHERE email = 'sita@example.com' AND password_verify('wrong guess', password_hash);
```

```text
id
--
(0 rows, 52.2 ms)
```

Rules for the login:

- Call `password_verify` **once** per login. It is slow on purpose (see the time above).
- Show the same message for "no such email" and "wrong password", for example "wrong email or password". Then nobody can find out which emails are registered.
- Count failed logins in your app (per email and per IP address) and wait longer after each failure. KDB does this for its own logins (Part B), but not for your app's table.
- `password_verify` gives `false` for a damaged hash. It never gives an error. `NULL` in gives `NULL` out.

### Sessions: stay logged in

After a good login, make a random token and keep its hash:

```sql
SELECT random_token() AS token;
```

```text
token
-------------------------------------------
gag86m0anriIibqzs8qzIZSay4l6JKe8vUOI1WqeyJ8
(1 row, 0.0 ms)
```

`random_token()` gives 32 random bytes from the operating system as URL-safe text (43 characters). Your backend sends it to the browser as a cookie (`HttpOnly; Secure; SameSite=Lax` or `Strict`) and saves its hash with an expiry time:

```sql
INSERT INTO app_sessions VALUES (sha256('mR3v7yJ2nqKx0Qe8i4uX1t9LZbF5cH6aWgD2sP0oVkE'), 1, dateadd('d', 7, now()));
```

On **every request**, your backend finds the user of the token:

```sql
SELECT u.id, u.email
FROM app_sessions s JOIN app_users u ON u.id = s.user_id
WHERE s.token_hash = sha256('mR3v7yJ2nqKx0Qe8i4uX1t9LZbF5cH6aWgD2sP0oVkE') AND s.expires_at > now();
```

```text
id | email
---+-----------------
 1 | sita@example.com
(1 row, 0.1 ms)
```

This is fast: `sha256()` is not slow like `password_hash()`.

Log out:

```sql
DELETE FROM app_sessions WHERE token_hash = sha256('mR3v7yJ2nqKx0Qe8i4uX1t9LZbF5cH6aWgD2sP0oVkE');
```

Delete old sessions now and then: `DELETE FROM app_sessions WHERE expires_at < now();`

### Change a password, reset a password

- **Change** (the user knows the old one): check the old one with `password_verify`, then `UPDATE app_users SET password_hash = password_hash('new password') WHERE id = 1;` and delete the user's other sessions.
- **Reset** ("forgot password"): make a `random_token()`, save `sha256(token)` with a short expiry (for example 30 minutes) in a table like `app_sessions`, and email a link with the token. When the link is used, check it like a session, set the new password, and delete the reset row.

### Always use parameters

Never build SQL by gluing user text into it: `"... WHERE email = '" + email + "'"` lets a user write SQL (SQL injection). Use your driver's parameters (`$1`, `$2` with the PostgreSQL protocol), or put the text through a function that doubles every `'`.

### The functions

| Function | Gives | Use |
|---|---|---|
| `password_hash(text)` | `'$pbkdf2-sha256$i=600000$...'` | store a password (slow on purpose) |
| `password_hash(text, iterations)` | the same with 1,000 to 10,000,000 rounds | more rounds are slower and safer |
| `password_verify(text, hash)` | `true` / `false` | check a password; `false` for a damaged hash |
| `sha256(text)` | 64 hex characters | hash a token, a file name, ... (fast) |
| `hmac_sha256(key, text)` | 64 hex characters | sign a message with a secret key (webhooks) |
| `random_bytes(n)` | n random bytes as hex (n = 1 to 1024) | secrets, codes |
| `random_token()`, `random_token(n)` | n random bytes (default 32) as URL-safe base64 | session tokens, reset links, API keys |
| `gen_random_uuid()` | `'0465d47f-8194-4c94-a372-eda3b70504a0'` | random ids (UUID version 4) |

```sql
SELECT sha256('abc') AS hex, hmac_sha256('key', 'message') AS mac, gen_random_uuid() AS id, random_bytes(8) AS bytes;
```

```text
hex                                              | mac                                              | id                                   | bytes
-------------------------------------------------+--------------------------------------------------+--------------------------------------+-----------------
ba7816bf8f01cfea414140de5dae2223b00361a396177... | 6e9ef29b75fffc5b7abae527d58fdadb2fe42e7219011... | 0465d47f-8194-4c94-a372-eda3b70504a0 | 6614740117d2ce39
(1 row, 0.0 ms)
```

(`kdb sql` cuts long text in table output; the full values are there.)

The random functions give a new value for every row and every call. `DEFAULT gen_random_uuid()` gives each new row its own id.

**How slow is `password_hash`?** On a PC with SHA instructions in the CPU (most PCs and servers since about 2018) 600,000 rounds take about 0.05 to 0.1 seconds. Without them, about 0.4 seconds. KDB prints nothing about this; `test_crypto` shows the time on your computer. A small VPS with 1 CPU can do about 10 logins per second. That is fine for a normal app.

---

## Part B: database users and roles

### When does KDB ask for a login?

| Server | Login needed? |
|---|---|
| `kdb serve` on `127.0.0.1` (the default), no `--token`, no users | **No.** Only programs on the same computer can connect. This is how KDB worked before. |
| a data folder that has **users** | **Yes**, for every request (except `/health`, `/api/login` and the console page itself). |
| started with `--token <secret>` | **Yes**. The token works like an admin. With users, the token and the users both work. |
| `--bind 0.0.0.0` (or any address that is not 127.x) without `--token` and without users | **Refused**: `kdb serve` does not start (see below). |

`kdb shell` and `kdb sql` open the database files directly. They never ask for a login: whoever can read the data folder can do everything. Protect the folder with the file permissions of the operating system.

### Create the first user

Users belong to the **data folder** (they are kept in a hidden database `_system` in it). A server that opened one database folder by its path (`kdb serve D:\kdb\market`) has no users; use `--data-dir` for users.

The first user must have `ROLE admin`. With the server **stopped**:

```sh
kdb user add admin --role admin --data-dir /srv/kdb/data
```

KDB asks for the password twice (the typed text is not shown). From a script, pipe it in: `echo "the password" | kdb user add admin --role admin`. Never put a password on the command line: other users of the computer can see command lines.

Or with SQL, in `kdb shell` or in the console of a server that has no users yet:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER shop_app WITH PASSWORD 'Another-long-secret-42';
GRANT write ON DATABASE shop TO shop_app;
CREATE USER report WITH PASSWORD 'Reports-only-secret-7' ROLE read;
SHOW USERS;
```

```text
user 'admin' created with role admin
user 'shop_app' created with role none
user 'shop_app' has role write on database 'shop'
user 'report' created with role read
name     | role  | grants     | created                  | changed
---------+-------+------------+--------------------------+-------------------------
admin    | admin | NULL       | 2026-09-11T16:49:06.180Z | 2026-09-11T16:49:06.180Z
report   | read  | NULL       | 2026-09-11T16:49:06.284Z | 2026-09-11T16:49:06.284Z
shop_app | none  | shop=write | 2026-09-11T16:49:06.229Z | 2026-09-11T16:49:06.232Z
(3 rows, 0.0 ms)
```

As soon as the first user exists, a running server asks for a login.

`SHOW USERS` never shows passwords or hashes. A user who is not an admin sees only their own row.

### Roles

| Role | May do |
|---|---|
| `none` | nothing (until a `GRANT`) |
| `read` | `SELECT`, `SHOW`, `EXPLAIN`, CSV export, cursors, `BEGIN`/`COMMIT`/`ROLLBACK`, `/api/info`, list backups |
| `write` | everything of `read`, and `INSERT`, `UPDATE`, `DELETE`, `CALL`, line protocol (`/write`) |
| `admin` | everything of `write`, and `CREATE`/`ALTER`/`DROP` of tables, views, functions, procedures and triggers, `BACKUP`, `CHECK` |

- The **ROLE** of a user (`CREATE USER ... ROLE read`) is for **every** database.
- A **GRANT** is for **one** database: `GRANT write ON DATABASE shop TO shop_app`.
- KDB uses the stronger of the two.
- Only a user whose own ROLE is `admin` may create and drop databases and manage users (`CREATE USER`, `GRANT`, ...). `GRANT admin ON DATABASE shop` gives all rights inside `shop`, but not these.
- Every user may change their own password: `ALTER USER report WITH PASSWORD '...'`.

A refused statement gets an error that says what is missing, and nothing of it runs:

```text
{"error":"INSERT needs role write on database 'shop'; user 'report' has read"}   (HTTP 403)
```

Give each program only what it needs. Your app's backend: `write` on its own database (plus `admin` only when it must create tables). A report script: `read`. Keep `admin` for yourself.

### All user statements

```sql
CREATE USER [IF NOT EXISTS] name [WITH] PASSWORD 'secret' [ROLE admin|write|read|none];
ALTER USER name [WITH] PASSWORD 'new secret';
ALTER USER name ROLE read;
DROP USER [IF EXISTS] name;
SHOW USERS;
GRANT read|write|admin|ALL ON DATABASE db TO name;     -- ALL = admin
REVOKE [read|write|admin|ALL] ON DATABASE db FROM name;  -- removes the grant on that database
GRANT SELECT|INSERT|UPDATE|DELETE|ALL|DEFAULT ON TABLE t TO name;   -- chapter 21
REVOKE SELECT|INSERT|UPDATE|DELETE|ALL ON TABLE t FROM name;       -- chapter 21
ALTER USER name ENABLE TOTP;   -- two-factor login, chapter 21
```

| Rule | Detail |
|---|---|
| Names | letters, digits, `_` and `-`, 1 to 63 characters. `Bob` and `bob` are the same user. |
| Passwords | at least 12 characters, not the user name, at most 1024 bytes. Write `''` for a `'` inside. Older passwords keep working. |
| `REVOKE read` | takes away only a `read` grant. A `write` or `admin` grant stays (KDB says so); use `REVOKE ALL` to take away any grant. |
| Last admin | the last user with `ROLE admin` cannot be dropped or lose that role while other users exist. |
| New password | ends every login (session) of that user at once. |
| `DROP DATABASE` | also removes every `GRANT` on that database. |

The same with the `kdb` tool, when the server is stopped:

| Command | Does |
|---|---|
| `kdb user add <name> [--role admin\|write\|read\|none]` | add a user (the first one is admin) |
| `kdb user passwd <name>` | set a new password |
| `kdb user role <name> <role>` | change the role |
| `kdb user list` | names, roles and grants |
| `kdb user remove <name>` | remove a user |
| `kdb user reset-2fa <name>` | turn two-factor login off (a lost phone) |

All of them take `--data-dir <folder>`. While `kdb serve` runs, they refuse (the server has the users open); use SQL in the console then.

### Logging in

**Web console.** It shows a login form. After the login, the top bar shows the user and a **Log out** button. The login is kept in a cookie that scripts in the page cannot read (`HttpOnly`) and that other web sites cannot use (`SameSite=Strict`). It ends after 12 hours, at **Log out**, when the server restarts, or when the password changes.

**Programs: HTTP Basic.** Send the user name and password with each request. KDB remembers a good password for 10 minutes, so this is not slow:

```sh
curl -s -u report:Reports-only-secret-7 "http://127.0.0.1:9900/exec?db=shop&compat=0&query=SELECT%20id,%20email%20FROM%20app_users"
```

```text
{"query":"SELECT id, email FROM app_users","results":[{"statement":"SELECT id, email FROM app_users","columns":[{"name":"id","type":"INT"},{"name":"email","type":"STRING"}],"dataset":[[1,"sita@example.com"]],"count":1,"truncated":false,"rows_affected":0,"message":"","timings":{"parse_us":21,"execute_us":172}}],"timings":{"parse_us":21,"execute_us":172}}
```

**Programs: log in once.** `POST /api/login` gives a token. Send it as `Authorization: Bearer <token>`:

```sh
curl -s -i -H "Content-Type: application/json" --data '{"user":"shop_app","password":"Another-long-secret-42"}' http://127.0.0.1:9900/api/login
```

```text
HTTP/1.1 200 OK
Set-Cookie: kdb_login=472axoBncSsNLsieeFTU2Vz8Nomiuun3fYBWjd80u5E; Path=/; HttpOnly; SameSite=Strict; Max-Age=43200
{"user":"shop_app","role":"none","grants":{"shop":"write"},"expires_ms":1789188565554,"token":"472axoBncSsNLsieeFTU2Vz8Nomiuun3fYBWjd80u5E"}
```

**The `--token`** still works as before, and can do everything.

**PostgreSQL clients** (port 8832) log in with the same users (SCRAM-SHA-256). See the PostgreSQL chapter.

### Failed logins

Every failed login is written to the server's output, with the user name and the address (never the password):

```text
2026-09-11 22:34:25  login failed: user 'admin' from 127.0.0.1 (wrong password; 1 failure in a row)
2026-09-11 22:34:26  login failed: user 'admin' from 127.0.0.1 (wrong password; 5 failures in a row); next try allowed in 1 s
```

After 5 failures for one user from one address (or 20 from one address for any users), that address must wait before the next try: 1 second, then 2, 4, 8, ... up to 15 minutes. Meanwhile the answer is HTTP 429:

```text
{"error":"wrong user name or password","login":true}   (HTTP 401)
{"error":"too many failed logins; try again in 1 s","login":true}   (HTTP 429)
```

A good login ends the waiting for that user. Behind a reverse proxy every request comes from `127.0.0.1`, so the waiting is shared by everyone who tries the same user name.

`kdb serve --data-dir` also writes every login, failed login and lockout to the audit log (`SHOW AUDIT`, chapter 21). Every login gets a new token: a login request that still carries an old token ends that old login. For people, turn on two-factor login (`ALTER USER admin ENABLE TOTP`, chapter 21).

### How KDB keeps passwords

- A PBKDF2-HMAC-SHA-256 hash with 600,000 rounds and a random salt (the same as `password_hash`).
- A SCRAM-SHA-256 secret (salt, StoredKey, ServerKey, 4096 rounds, like PostgreSQL). The PostgreSQL protocol uses it, so the password never crosses the network.
- Login tokens are random (256 bits). KDB keeps only their SHA-256, and only in memory.
- Passwords and tokens are compared in constant time.

Because the SCRAM secret has only 4,096 rounds (the PostgreSQL default), use **long random passwords** for database users, for example 20 or more characters from a password manager. People never type them often: programs keep them in their settings.

---

## Part C: VPS checklist

A small Linux VPS (1-2 CPU, 1-2 GB memory) with your app and KDB on the same machine.

### 1. Run KDB as its own user

```sh
sudo useradd --system --home /srv/kdb --shell /usr/sbin/nologin kdb
sudo mkdir -p /srv/kdb/data /srv/kdb/backups
sudo ./install.sh --system          # from the unpacked Linux package (chapter 1)
sudo chown -R kdb:kdb /srv/kdb
sudo chmod 700 /srv/kdb/data /srv/kdb/backups
```

Only the `kdb` user (and root) can read the data and the backups.

`install.sh --system` puts the program in `/usr/local/bin/kdb` and its folders `web/`, `help/` and `skill/` in `/usr/local/share/kdb`, where `kdb` finds them by itself. Copying only the program works too, but then the server has no web console and no help pages.

### 2. Create users before the first start

```sh
sudo -u kdb kdb user add admin --role admin --data-dir /srv/kdb/data
sudo -u kdb kdb user add shop_app --role none --data-dir /srv/kdb/data
```

Then give `shop_app` its rights in SQL (`GRANT write ON DATABASE shop TO shop_app`) from the console, or run the app's `CREATE TABLE` statements as `admin` first.

### 3. Keep KDB on 127.0.0.1

```sh
kdb serve --data-dir /srv/kdb/data --backups /srv/kdb/backups
```

The default `--bind 127.0.0.1` means only programs on the VPS can connect. Your app's backend runs on the same VPS, so it can. Do **not** use `--bind 0.0.0.0` unless you really need it. Without a token and without users KDB refuses it anyway:

```text
error: --bind 0.0.0.0 without --token and without users would let anyone who can reach this computer
read, change and delete every database. Do one of these first:
  1. create an admin user:   kdb user add <name> --role admin
  2. or start with a secret:  --token <long random text>
  3. or keep --bind 127.0.0.1 and put a web server with HTTPS in front of KDB
See docs/tutorial/16-users-passwords-security.md
```

KDB has no HTTPS. Over plain HTTP, passwords and tokens can be read by anyone on the network path.

### 4. If you need the console from home: HTTPS in front

Use a web server that gets a free certificate by itself, for example Caddy. `/etc/caddy/Caddyfile`:

```text
kdb.example.com {
    reverse_proxy 127.0.0.1:9900
}
```

Caddy sends `X-Forwarded-Proto: https`; KDB then marks its login cookie `Secure`. KDB still asks for the login. Even better: do not open the console to the internet at all, and use an SSH tunnel from home:

```sh
ssh -L 9900:127.0.0.1:9900 you@your-vps
```

Then open <http://127.0.0.1:9900> on your own PC.

### 5. Firewall

Open only SSH and the web ports. Keep 9900 (HTTP API) and 8832 (PostgreSQL) closed:

```sh
sudo ufw default deny incoming
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

Also use SSH keys instead of SSH passwords, and keep the system updated (`sudo apt update && sudo apt upgrade`).

### 6. Start KDB with the system

`/etc/systemd/system/kdb.service`:

```ini
[Unit]
Description=KDB database
After=network.target

[Service]
User=kdb
ExecStart=/usr/local/bin/kdb serve --data-dir /srv/kdb/data --backups /srv/kdb/backups
Restart=on-failure
KillSignal=SIGINT
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
```

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now kdb
journalctl -u kdb -f          # the server's output, with "login failed" lines
```

For more protection in the same `ExecStart` line (statement timeouts, scheduled backups, `--safe-updates`), see [chapter 21](21-protection.md).

### 7. Backups, and a copy somewhere else

The easiest way: let the server do it, with a checked copy on a second disk ([chapter 21, Part C](21-protection.md#part-c-backups-on-a-schedule)):

```sh
kdb serve --data-dir /srv/kdb/data --backups /srv/kdb/backups --backup-schedule "daily 10:15" --backup-copy /mnt/backup/kdb
```

Or make a verified backup every night through the running server from a script (as a user with `admin` on that database):

```sh
curl -s -u admin:'the admin password' -X POST "http://127.0.0.1:9900/api/backup?db=shop"
```

Put that in a small script that reads the password from a file only root can read, and run it from `cron`. Then **copy the backups to another place** (another server, cloud storage): a backup on the same VPS is lost with the VPS. Test a restore now and then (chapter 9). Backups hold the password hashes of your app's users and the `_system` database: keep them as private as the data.

### 8. Short checklist

| Check | Done |
|---|---|
| KDB runs as its own user; data and backups are `chmod 700` | |
| `--bind 127.0.0.1` (the default); ports 9900 and 8832 closed in the firewall | |
| an `admin` user with a long random password; apps have their own users with the smallest role | |
| HTTPS (Caddy or nginx) or an SSH tunnel for the console | |
| app passwords stored with `password_hash`, checked with `password_verify` | |
| session tokens are random (`random_token`) and stored as `sha256` with an expiry | |
| nightly backup, copied off the VPS, restore tested | |
| `journalctl -u kdb` checked for `login failed` now and then (or `SHOW AUDIT WHERE event = 'login_failed'`) | |
| the protections of [chapter 21](21-protection.md#vps-checklist): timeouts, audit, scheduled backups, two-factor login for admins | |

---

## Limits

- Logins (sessions) are kept in memory: a restart logs everyone out.
- No HTTPS inside KDB; use a reverse proxy.
- Rights are per database, and per table with `GRANT ... ON TABLE` (chapter 21). No column or row rights.
- `kdb shell` and `kdb sql` do not ask for a login. Protect the data folder with file permissions.
- Old KDB versions do not know users. Never start an older `kdb` on a data folder that has users: it would serve it **without** a login.

---

Next: [Known limitations](known-limitations.md)
