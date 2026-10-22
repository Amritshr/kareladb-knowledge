# Logins, tokens and roles over HTTP

> How a program or the console proves who it is - the access token, HTTP Basic, POST /api/login - and the 401, 403 and 429 answers.

- Category: HTTP API
- Keywords: login, logout, api/login, api/logout, api/me, api/session, whoami, token, --token, Bearer, Authorization, HTTP Basic, curl -u, cookie, kdb\_login, kdb\_auth, kdb\_token, CSRF, X-KDB-CSRF, remember me, HttpOnly, SameSite, 401, 403, 429, Retry-After, WWW-Authenticate, roles, read, write, admin, password, session token, failed logins
- See also: [Users and roles](users-and-roles.md), [Keeping kdb serve safe](server-security.md), [HTTP API overview (auth)](http-overview.md#auth), [kdb user](cli-users.md), [PostgreSQL protocol (port 8832) (passwords)](postgres-protocol.md#passwords)

A server can be open, need a **token**, or need a **user login**. This page shows how to send each one over HTTP.

| Server | Login needed? |
|---|---|
| `kdb serve` on `127.0.0.1` (the default), no `--token`, no users | **No.** Only programs on the same computer can connect. |
| started with `--token <secret>` | **Yes**: the token. It may do everything. |
| the data folder has **users** (`CREATE USER`, `kdb user add`) | **Yes**: a user name and password, or a login token. Each user may do only what their role allows. With `--token` too, the token also works. |
| `--bind 0.0.0.0` (not 127.x) without `--token` and without users | the server does not start |

- `GET /health`, `POST /api/login`, `POST /api/session`, `POST /api/logout` and the console page need no login. `/health` says `auth_required` and `login` (users exist).
- Making users and roles: [users and roles](users-and-roles.md). Keeping a server on the internet safe: [server security](server-security.md).
- Tutorial: [chapter 16, users, passwords and security](../tutorial/16-users-passwords-security.md).

The examples below that need users or a token run on their own new `kdb serve` (a fresh data folder), so you see the real answers. On a new server without users, the first `CREATE USER ... ROLE admin` can be sent without a login; from then on every request needs one.

<a id="ways"></a>

## Ways to send a login

| How | Send | Good for |
|---|---|---|
| The access token | header `Authorization: Bearer <token>` | a server started with `--token` |
| HTTP Basic | header `Authorization: Basic <base64 of user:password>` (`curl -u user:password`) | scripts. A good password is remembered for 10 minutes, so it is not slow. |
| A login token | `POST /api/login` once, then `Authorization: Bearer <token>` | apps that make many requests |
| An API token | `CREATE TOKEN app FOR USER u` once, then `Authorization: Bearer kdbt_...` ([API tokens](api-tokens.md)) | apps and services: many named tokens, each revoked on its own |
| The login cookie | `POST /api/login` sets the cookie `kdb_login` | browsers: the web console |
| The token cookie | `POST /api/session` turns a token into the cookie `kdb_auth` | browsers: the web console, when you paste a token |

- **Base64** is a way to write any bytes as plain letters; `curl -u` and every HTTP library do it for you.
- A **cookie** is a small value the browser keeps and sends back by itself. KDB's cookies are `HttpOnly` (JavaScript in the page cannot read them) and `SameSite=Strict` (other web sites cannot make the browser send them).
- A change sent with a cookie (not a `GET`) also needs the header `X-KDB-CSRF`. See [CSRF](http-login.md#csrf). A header login needs nothing extra.
- On a server that needs no login, the `Authorization` header is not checked at all.

## POST /api/login

Syntax:

```sql
POST /api/login
body: {"user": "<name>", "password": "<password>"[, "code": "<6 digits>"]}
   or user=<name>&password=<password>[&code=<6 digits>]  (Content-Type: application/x-www-form-urlencoded)
```

Checks a user name and password. On success it starts a **login session** (12 hours), sets the cookie `kdb_login`, and gives back a token for `Authorization: Bearer <token>`.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `user` | JSON body or form field | The user name (case is ignored) | required |
| `password` | JSON body or form field | The password | required |
| `code` | JSON body or form field | The code of the authenticator app, for a user with [two-factor login](two-factor-login.md) | - |
| `X-KDB-Console` | header | Sent by the web console: then the answer has no `token` (the console uses only the cookie) | not sent |

| Answer field | Meaning |
|---|---|
| `user` | The user name as it is stored |
| `role` | The user's own ROLE: `admin`, `write`, `read` or `none` (for every database) |
| `grants` | Roles on single databases, like `{"shop": "write"}` |
| `expires_ms` | When the login ends (ms since 1970, UTC) |
| `token` | The login token (43 characters). Send it as `Authorization: Bearer <token>`. |
| `csrf` | The `X-KDB-CSRF` value for changes sent with the cookie ([CSRF](http-login.md#csrf)) |
| header `Set-Cookie` | `kdb_login=<token>; Path=/; HttpOnly; SameSite=Strict; Max-Age=43200` (and `Secure` over [TLS](tls.md), or when a proxy sends `X-Forwarded-Proto: https`) |

- **Status codes:** 200 logged in; 400 no user name, or the server has no users; 401 `{"error": "wrong user name or password", "login": true}` (the same text for an unknown user, so nobody can find out which names exist); 403 the request comes from another web site; 429 too many failed logins, with a `Retry-After` header (seconds to wait).
- **Notes:**
  - A login ends after 12 hours, at `POST /api/logout`, or when the user gets a new password or is dropped. A server restart does not end it: logins are kept in the data folder, as hashes only ([where](api-tokens.md#kept)).
  - KDB keeps only the SHA-256 of the token, never the token itself.
  - After 5 failed logins for one user from one address, that user must wait before the next try from that address: 1 s, 2 s, 4 s, ... up to 15 minutes. A good login ends the waiting for that user.
  - After 20 failed logins for one user from all addresses together, that user waits everywhere (someone is guessing from many machines).
  - Only the user who failed waits. Other users, and the right `--token` (with any name, on the [PostgreSQL port](postgres-protocol.md#passwords) too), still work from the same address. This matters behind Docker or a NAT, where every client has the same address.
  - Every failed login is printed in the server's output with the user name and address (never the password).
  - The same users log in on the [PostgreSQL port](postgres-protocol.md#passwords).

**HTTP: The first user, a login, the token, and logout**

```http
POST /exec?compat=0

CREATE USER boss WITH PASSWORD 'boss-secret-1' ROLE admin
###
GET /exec?compat=0&query=SELECT 1 AS one
###
POST /api/login
Content-Type: application/json

{"user": "boss", "password": "boss-secret-1"}
###
GET /exec?compat=0&query=SELECT 1 AS one
Authorization: Bearer {{token}}
###
POST /api/logout
Authorization: Bearer {{token}}
###
GET /exec?compat=0&query=SELECT 1 AS one
Authorization: Bearer {{token}}
```

Response:

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "CREATE USER boss WITH PASSWORD 'boss-secret-1' ROLE admin",
  "results": [
    {
      "statement": "CREATE USER boss WITH PASSWORD '***' ROLE admin",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "user 'boss' created with role admin",
      "timings": {"parse_us": 0, "execute_us": 168626}
    }
  ],
  "timings": {"parse_us": 0, "execute_us": 168626}
}
```

`GET /exec?compat=0&query=SELECT 1 AS one`

HTTP 401 (application/json)

```text
{
  "error": "login required: log in (POST /api/login), or send a user name and password (HTTP Basic)",
  "login": true
}
```

`POST /api/login`

HTTP 200 (application/json)

```text
{
  "user": "boss",
  "role": "admin",
  "grants": {},
  "expires_ms": 1792691051375,
  "csrf": "6add673dff4486d3334de25d2d56f4eb",
  "token": "ddmM7HyYgI-RWGiA7sCk2US_DZikXzBnrjhDFkr2bQE"
}
```

`GET /exec?compat=0&query=SELECT 1 AS one`

HTTP 200 (application/json)

```text
{
  "query": "SELECT 1 AS one",
  "results": [
    {
      "statement": "SELECT 1 AS one",
      "columns": [
        {"name": "one", "type": "LONG"}
      ],
      "dataset": [
        [1]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 23, "execute_us": 58}
    }
  ],
  "timings": {"parse_us": 23, "execute_us": 58}
}
```

`POST /api/logout`

HTTP 200 (application/json)

```text
{"logged_out": true}
```

`GET /exec?compat=0&query=SELECT 1 AS one`

HTTP 401 (application/json)

```text
{"error": "the login token is wrong or has expired; log in again (POST /api/login)", "login": true}
```

**HTTP: Wrong passwords: 401, then 429 after 5 tries**

```http
POST /exec?compat=0

CREATE USER boss WITH PASSWORD 'boss-secret-1' ROLE admin
###
POST /api/login
Content-Type: application/json

{"user": "boss", "password": "guess-1"}
###
POST /api/login
Content-Type: application/json

{"user": "boss", "password": "guess-2"}
###
POST /api/login
Content-Type: application/json

{"user": "boss", "password": "guess-3"}
###
POST /api/login
Content-Type: application/json

{"user": "boss", "password": "guess-4"}
###
POST /api/login
Content-Type: application/json

{"user": "boss", "password": "guess-5"}
###
POST /api/login
Content-Type: application/json

{"user": "boss", "password": "boss-secret-1"}
```

Response:

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "CREATE USER boss WITH PASSWORD 'boss-secret-1' ROLE admin",
  "results": [
    {
      "statement": "CREATE USER boss WITH PASSWORD '***' ROLE admin",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "user 'boss' created with role admin",
      "timings": {"parse_us": 0, "execute_us": 163793}
    }
  ],
  "timings": {"parse_us": 0, "execute_us": 163793}
}
```

`POST /api/login`

HTTP 401 (application/json)

```text
{"error": "wrong user name or password", "login": true}
```

`POST /api/login`

HTTP 401 (application/json)

```text
{"error": "wrong user name or password", "login": true}
```

`POST /api/login`

HTTP 401 (application/json)

```text
{"error": "wrong user name or password", "login": true}
```

`POST /api/login`

HTTP 401 (application/json)

```text
{"error": "wrong user name or password", "login": true}
```

`POST /api/login`

HTTP 401 (application/json)

```text
{"error": "wrong user name or password", "login": true}
```

`POST /api/login`

HTTP 429 (application/json)

```text
{"error": "too many failed logins; try again in 1 s", "login": true}
```

The 429 answer also has the header `Retry-After: 1`. Even the right password must wait until then.

A login with `curl -i` shows the cookie (from [chapter 16](../tutorial/16-users-passwords-security.md), real output of a server with the user `shop_app`):

```bash
curl -s -i -H "Content-Type: application/json" --data '{"user":"shop_app","password":"Another-long-secret-42"}' http://127.0.0.1:9900/api/login
```

```text
HTTP/1.1 200 OK
Set-Cookie: kdb_login=472axoBncSsNLsieeFTU2Vz8Nomiuun3fYBWjd80u5E; Path=/; HttpOnly; SameSite=Strict; Max-Age=43200
{"user":"shop_app","role":"none","grants":{"shop":"write"},"expires_ms":1789188565554,"token":"472axoBncSsNLsieeFTU2Vz8Nomiuun3fYBWjd80u5E"}
```

On a server without users:

**HTTP: A login on a server without users**

```http
POST /api/login
Content-Type: application/json

{"user": "asha", "password": "not-a-real-password"}
```

Response:

HTTP 400 (application/json)

```text
{
  "error": "this server has no users yet; create one with CREATE USER <name> WITH PASSWORD '...' ROLE admin"
}
```

**HTTP: No user name**

```http
POST /api/login
Content-Type: application/json

{"password": "secret"}
```

Response:

HTTP 400 (application/json)

```text
{"error": "send the user name and password: {\"user\": \"...\", \"password\": \"...\"}"}
```

Log in once, then use the token (Python, `requests`):

```python
import requests

KDB = "http://127.0.0.1:9900"
r = requests.post(f"{KDB}/api/login", json={"user": "shop_app", "password": "Another-long-secret-42"})
if r.status_code == 429:
    raise RuntimeError(f"too many failed logins: wait {r.headers['Retry-After']} s")
if r.status_code != 200:
    raise RuntimeError(r.json()["error"])
auth = {"Authorization": "Bearer " + r.json()["token"]}

rows = requests.post(f"{KDB}/exec", params={"db": "shop", "compat": 0},
                     data="SELECT count(*) FROM orders", headers=auth).json()
print(rows["results"][0]["dataset"])

requests.post(f"{KDB}/api/logout", headers=auth)
```

```js
// Node 18+
const KDB = "http://127.0.0.1:9900";
const login = await fetch(`${KDB}/api/login`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ user: "shop_app", password: process.env.KDB_PASSWORD }),
});
const me = await login.json();
if (!login.ok) throw new Error(me.error);
const auth = { Authorization: `Bearer ${me.token}` };
const res = await fetch(`${KDB}/exec?db=shop&compat=0`, { method: "POST", headers: auth, body: "SELECT 1" });
console.log(res.status, (await res.json()).results);
```

```powershell
$login = Invoke-RestMethod -Method Post "http://127.0.0.1:9900/api/login" -ContentType "application/json" `
  -Body (@{ user = "shop_app"; password = $env:KDB_PASSWORD } | ConvertTo-Json)
$auth = @{ Authorization = "Bearer $($login.token)" }
Invoke-RestMethod -Method Post "http://127.0.0.1:9900/exec?db=shop&compat=0" -Headers $auth -ContentType "text/plain" -Body "SELECT 1"
```

```csharp
using var http = new HttpClient { BaseAddress = new Uri("http://127.0.0.1:9900") };
var login = await http.PostAsJsonAsync("/api/login", new { user = "shop_app", password = Environment.GetEnvironmentVariable("KDB_PASSWORD") });
var body = await login.Content.ReadFromJsonAsync<JsonElement>();
if (!login.IsSuccessStatusCode) throw new Exception(body.GetProperty("error").GetString());
http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", body.GetProperty("token").GetString());
```

<a id="logout"></a>

## POST /api/logout

Syntax:

```sql
POST /api/logout
```

Ends a login session: the one of the `Authorization: Bearer <token>` header, and the one of the `kdb_login` cookie. It also ends the console session of the `kdb_auth` cookie on the server, and tells the browser to forget the cookies `kdb_login` and `kdb_auth`.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `Authorization: Bearer <token>` | header | The login token to end | - |
| `kdb_login` | cookie | The login cookie to end | - |

| Answer field | Meaning |
|---|---|
| `logged_out` | always `true` |
| header `Set-Cookie` | `kdb_login=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0` and the same for `kdb_auth` (removes the cookies) |

- **Status codes:** always 200, also when there was no login.
- **Notes:** after logout the token answers 401 `the login token is wrong or has expired; log in again (POST /api/login)`. HTTP Basic has nothing to log out: just stop sending the password. The `--token` cannot be logged out.

**HTTP: Log out (here without a login: still 200)**

```http
POST /api/logout
```

Response:

HTTP 200 (application/json)

```text
{"logged_out": true}
```

## GET /api/me

Syntax:

```sql
GET /api/me
```

Who am I? The user of this request's login, and the role. The web console shows it at the top ("boss (admin)").

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| (a login) | header or cookie | Any of the [ways to send a login](http-login.md#ways) | - |

| Answer field | Meaning |
|---|---|
| `user` | The user name, or `null` (the token, or a server without login) |
| `role` | The user's own ROLE; `admin` for full access |
| `grants` | Roles on single databases: `{"shop": "write"}` |
| `full_access` | `true` for the `--token`, and on a server without login |
| `two_factor` | `true` when this user has [two-factor login](two-factor-login.md) on |
| `login_required` | `true` when requests need a login or token |
| `users` | `true` when the data folder has users |
| `cookie` | `true` when this request logged in with a cookie |
| `csrf` | Only with a cookie login: the `X-KDB-CSRF` value for changes ([CSRF](http-login.md#csrf)) |

- **Status codes:** 200; 401 without a needed login (the answer then has `"login": true` when users exist).
- **Notes:** a program can call it after start to check that its password or token works.

**HTTP: On a server without token and users: full access**

```http
GET /api/me
```

Response:

HTTP 200 (application/json)

```text
{
  "user": null,
  "role": "admin",
  "grants": {},
  "full_access": true,
  "two_factor": false,
  "login_required": false,
  "users": false,
  "cookie": false,
  "step_up_actions": false,
  "step_up_minutes": 5,
  "step_up_until_ms": 0
}
```

**HTTP: A user with a grant on one database**

```http
POST /exec?compat=0

CREATE USER boss WITH PASSWORD 'boss-secret-1' ROLE admin;
CREATE USER shop_app WITH PASSWORD 'Another-long-secret-42';
CREATE DATABASE shop;
GRANT write ON DATABASE shop TO shop_app
###
POST /api/login
Content-Type: application/json

{"user": "shop_app", "password": "Another-long-secret-42"}
###
GET /api/me
Authorization: Bearer {{token}}
```

Response:

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "CREATE USER boss WITH PASSWORD 'boss-secret-1' ROLE admin;\nCREATE USER shop_app WITH PASSWORD 'Another-long-secret-42';\nCREATE DATABASE shop;\nGRANT write ON DATABASE shop TO shop_app",
  "results": [
    {
      "statement": "CREATE USER boss WITH PASSWORD '***' ROLE admin",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "user 'boss' created with role admin",
      "timings": {"parse_us": 0, "execute_us": 162348}
    },
    {
      "statement": "CREATE USER shop_app WITH PASSWORD '***'",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "user 'shop_app' created with role none",
      "timings": {"parse_us": 0, "execute_us": 60424}
    },
    {
      "statement": "CREATE DATABASE shop",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "database 'shop' created",
      "timings": {"parse_us": 0, "execute_us": 9231}
    },
    {
      "statement": "GRANT write ON DATABASE shop TO shop_app",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "user 'shop_app' has role write on database 'shop'",
      "timings": {"parse_us": 0, "execute_us": 1761}
    }
  ],
  "timings": {"parse_us": 0, "execute_us": 233764}
}
```

`POST /api/login`

HTTP 200 (application/json)

```text
{
  "user": "shop_app",
  "role": "none",
  "grants": {"shop": "write"},
  "expires_ms": 1792691051520,
  "csrf": "5993b92d7d2144c05a35e348320d66f3",
  "token": "DX6j_aIpvcyeyR62ZcpAJIjbbb62tzatkYwCMvnLlbI"
}
```

`GET /api/me`

HTTP 200 (application/json)

```text
{
  "user": "shop_app",
  "role": "none",
  "grants": {"shop": "write"},
  "full_access": false,
  "two_factor": false,
  "login_required": true,
  "users": true,
  "cookie": false,
  "step_up_actions": false,
  "step_up_minutes": 5,
  "step_up_until_ms": 0
}
```

<a id="token"></a>

## The access token (--token)

Syntax:

```sql
kdb serve --token <long random secret>
Authorization: Bearer <token>
```

The simplest protection: one secret for everything. Whoever sends it may do **everything**, like an admin.

| Situation | Answer |
|---|---|
| no token sent | 401 `{"error": "access token required"}` |
| a wrong token | 401 `{"error": "wrong access token"}` |
| the right token | the normal answer |

- The 401 answer has the header `WWW-Authenticate: Bearer realm="kdb"`.
- The web console asks for the token once and hands it to [`POST /api/session`](http-login.md#session). The server keeps the token and gives the browser an `HttpOnly` cookie with a random session id, so no script in the page can read the token, and the cookie never holds it. CSV downloads work with that cookie too.
- Older consoles kept the token in the browser's storage and in a cookie `kdb_token`. The new console moves it into the `HttpOnly` cookie once and deletes both. The server still reads `kdb_token` for one more release.
- The token is compared in constant time, so it cannot be guessed by measuring answer times.
- It is also the password of the [PostgreSQL port](postgres-protocol.md#passwords) when there are no users.
- Pick a long random token (20 or more characters). For programs that should only read, or only use one database, use **users** instead.

**HTTP: A server started with --token change-me-please** (shows an error)

```http
GET /health
###
GET /exec?compat=0&query=SELECT 1 AS one
###
GET /exec?compat=0&query=SELECT 1 AS one
Authorization: Bearer wrong
###
GET /exec?compat=0&query=SELECT 1 AS one
Authorization: Bearer change-me-please
```

Response:

`GET /health`

HTTP 200 (application/json)

```text
{
  "status": "ok",
  "version": "0.2.0-dev",
  "server_time_ms": 1792647851208,
  "auth_required": true,
  "login": false,
  "tls": false,
  "ready": true,
  "standby": false
}
```

`GET /exec?compat=0&query=SELECT 1 AS one`

HTTP 401 (application/json)

```text
{"error": "access token required"}
```

`GET /exec?compat=0&query=SELECT 1 AS one`

HTTP 401 (application/json)

```text
{"error": "wrong access token"}
```

`GET /exec?compat=0&query=SELECT 1 AS one`

HTTP 200 (application/json)

```text
{
  "query": "SELECT 1 AS one",
  "results": [
    {
      "statement": "SELECT 1 AS one",
      "columns": [
        {"name": "one", "type": "LONG"}
      ],
      "dataset": [
        [1]
      ],
      "count": 1,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 35, "execute_us": 72}
    }
  ],
  "timings": {"parse_us": 35, "execute_us": 72}
}
```

```bash
curl -s -H "Authorization: Bearer change-me-please" "http://127.0.0.1:9900/exec?compat=0&query=SELECT%201"
```

```powershell
$h = @{ Authorization = "Bearer $env:KDB_TOKEN" }
Invoke-RestMethod "http://127.0.0.1:9900/api/info" -Headers $h
```

<a id="session"></a>

## POST /api/session

Syntax:

```sql
POST /api/session[?remember=1]
Authorization: Bearer <token>
```

Starts a console session for a token and gives the browser the cookie `kdb_auth`. The web console calls it when you paste a token. The server keeps the token in its memory; the cookie holds only a random session id. The cookie is `HttpOnly`, so no script in the page can read it.

| Parameter | Where | Meaning | Default |
|---|---|---|---|
| `Authorization: Bearer <token>` | header | The `--token`, an [API token](api-tokens.md) or a login token | required |
| `remember` | query | `1`: the session lasts 30 days. Without it the session lasts 12 hours, and the browser forgets the cookie when it closes. | not sent |

A console session ends when:

| What happens | Why |
|---|---|
| its time is up (12 hours, or 30 days with `remember`) | a forgotten browser does not stay logged in |
| [`POST /api/logout`](http-login.md#logout) with the cookie | the server forgets the id: a copied cookie stops working too |
| the pasted token stops working (`DROP TOKEN`, an ended login) | the session has the token's rights, checked on every request |
| the server restarts | sessions live in memory only: paste the token again |

- A cookie from an older KDB held the token itself. The server no longer takes it: the console asks for the token once more.

| Answer field | Meaning |
|---|---|
| `user` | The token's user, or `null` for the `--token` |
| `role` | The role; `admin` for the `--token` |
| `full_access` | `true` for the `--token` |
| `remember` | `true` when the cookie is kept 30 days |
| `csrf` | The `X-KDB-CSRF` value for changes sent with the cookie ([CSRF](http-login.md#csrf)) |
| header `Set-Cookie` | `kdb_auth=<session id>; Path=/; HttpOnly; SameSite=Strict` (with `Max-Age=2592000` for `remember`, and `Secure` over [TLS](tls.md)) |

- **Status codes:** 200; 400 no `Authorization: Bearer` header; 401 a wrong token; 403 the request comes from another web site.
- **Notes:** programs do not need it. They send `Authorization: Bearer <token>` with every request. [`POST /api/logout`](http-login.md#logout) makes the browser forget the cookie.

**HTTP: The console hands over a token and gets a session cookie**

```http
POST /api/session
Authorization: Bearer change-me-please
```

Response:

HTTP 200 (application/json)

```text
{
  "user": null,
  "role": "admin",
  "full_access": true,
  "remember": false,
  "csrf": "d940cd8cd42f3877ccaf73469a7f075f"
}
```

<a id="csrf"></a>

## CSRF: the X-KDB-CSRF header

A browser sends cookies by itself, even when another web site makes it send a request. That is called **CSRF** (cross-site request forgery). So a request that logged in with a **cookie** and changes something must also send the header `X-KDB-CSRF`.

| Request | Needs `X-KDB-CSRF`? |
|---|---|
| `GET` or `HEAD` (only reads) | no |
| `POST`, `PUT`, `DELETE` with the cookie `kdb_login` or `kdb_auth` | **yes** |
| any request with `Authorization: Bearer` or `Basic` | no: another web site cannot set that header |
| the old cookie `kdb_token` | no, but the request must come from the console (`X-KDB-Console`) |

- The value comes in the `csrf` field of [`POST /api/login`](http-login.md#post-api-login), [`POST /api/session`](http-login.md#session) and [`GET /api/me`](http-login.md#get-api-me). Another web site cannot read it.
- The value belongs to the cookie. A new login gives a new value.
- The web console sends it by itself (`window.KdbConsole.api`).
- Without it the answer is 403 with `"csrf": true`.

**HTTP: A change with the cookie: refused without the header, done with it** (shows an error)

```http
POST /api/session
Authorization: Bearer change-me-please
###
POST /exec?compat=0
Cookie: kdb_auth=change-me-please

CREATE TABLE notes (id INT, text STRING)
###
POST /exec?compat=0
Cookie: kdb_auth=change-me-please
X-KDB-CSRF: {{csrf}}

CREATE TABLE notes (id INT, text STRING)
```

Response:

`POST /api/session`

HTTP 200 (application/json)

```text
{
  "user": null,
  "role": "admin",
  "full_access": true,
  "remember": false,
  "csrf": "35b07c9baa23af37a447fc6924202791"
}
```

`POST /exec?compat=0`

HTTP 401 (application/json)

```text
{"error": "the saved access token is no longer accepted; enter it again"}
```

`POST /exec?compat=0`

HTTP 401 (application/json)

```text
{"error": "the saved access token is no longer accepted; enter it again"}
```

<a id="basic"></a>

## HTTP Basic

Syntax:

```sql
Authorization: Basic <base64 of name:password>
curl -u <name>:<password> ...
```

Sends the user name and password with **every** request. KDB checks the password once and then remembers it for 10 minutes, so it stays fast.

- Good for scripts and tools that cannot keep a token.
- A wrong password: 401 `wrong user name or password`. Many wrong passwords: 429 with `Retry-After`.
- On a server with users, a request with no login gets `WWW-Authenticate: Basic realm="kdb"`, so a browser shows its own password box. The console sends `X-KDB-Console: 1` and gets `Bearer` instead (no browser box).
- On a server without users, Basic is refused: 401 `this server has no users yet`.

The header below is the base64 of `reader:reader-secret-1`, what `curl -u reader:reader-secret-1` sends. The user `reader` has role `read`, so reading works and writing is refused:

**HTTP: HTTP Basic with a read-only user** (sample data: sample)

```http
POST /exec?compat=0

CREATE USER boss WITH PASSWORD 'boss-secret-1' ROLE admin;
CREATE USER reader WITH PASSWORD 'reader-secret-1' ROLE read
###
GET /exec?compat=0&query=SELECT symbol, name FROM securities ORDER BY symbol LIMIT 2
Authorization: Basic cmVhZGVyOnJlYWRlci1zZWNyZXQtMQ==
###
POST /exec?compat=0
Authorization: Basic cmVhZGVyOnJlYWRlci1zZWNyZXQtMQ==

INSERT INTO brokers VALUES (99, 'Not Allowed Securities')
```

Response:

`POST /exec?compat=0`

HTTP 200 (application/json)

```text
{
  "query": "CREATE USER boss WITH PASSWORD 'boss-secret-1' ROLE admin;\nCREATE USER reader WITH PASSWORD 'reader-secret-1' ROLE read",
  "results": [
    {
      "statement": "CREATE USER boss WITH PASSWORD '***' ROLE admin",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "user 'boss' created with role admin",
      "timings": {"parse_us": 0, "execute_us": 166112}
    },
    {
      "statement": "CREATE USER reader WITH PASSWORD '***' ROLE read",
      "columns": [],
      "dataset": [],
      "count": 0,
      "truncated": false,
      "rows_affected": 0,
      "message": "user 'reader' created with role read",
      "timings": {"parse_us": 0, "execute_us": 62273}
    }
  ],
  "timings": {"parse_us": 0, "execute_us": 228385}
}
```

`GET /exec?compat=0&query=SELECT symbol, name FROM securities ORDER BY symbol LIMIT 2`

HTTP 200 (application/json)

```text
{
  "query": "SELECT symbol, name FROM securities ORDER BY symbol LIMIT 2",
  "results": [
    {
      "statement": "SELECT symbol, name FROM securities ORDER BY symbol LIMIT 2",
      "columns": [
        {"name": "symbol", "type": "SYMBOL"},
        {"name": "name", "type": "STRING"}
      ],
      "dataset": [
        ["ACME", "Acme Investment Company"],
        ["CITY", "City Bank Limited"]
      ],
      "count": 2,
      "truncated": false,
      "rows_affected": 0,
      "message": "",
      "timings": {"parse_us": 23, "execute_us": 245}
    }
  ],
  "timings": {"parse_us": 23, "execute_us": 245}
}
```

`POST /exec?compat=0`

HTTP 403 (application/json)

```text
{
  "query": "INSERT INTO brokers VALUES (99, 'Not Allowed Securities')",
  "results": [],
  "saved": 0,
  "rolled_back": false,
  "error": "INSERT needs role write on database 'demo'; user 'reader' has read",
  "sqlstate": "42501"
}
```

```bash
curl -s -u reader:reader-secret-1 "http://127.0.0.1:9900/exec?db=market&compat=0&query=SELECT%20count(*)%20FROM%20ochl_day"
```

```python
import requests
r = requests.get("http://127.0.0.1:9900/exec", params={"db": "shop", "query": "SELECT count(*) FROM app_users"},
                 auth=("report", "Reports-only-secret-7"))
```

<a id="roles"></a>

## Roles: what each route needs

Each user has a **role**: `none`, `read`, `write` or `admin`. The user's own ROLE counts for every database; a `GRANT ... ON DATABASE` gives a role on one database. KDB uses the stronger of the two.

| Route | Needs |
|---|---|
| `GET /health`, `POST /api/login`, `POST /api/logout`, the console files | nothing |
| `GET /api/me`, `POST /session`, `DELETE /session/<id>`, `POST /api/feedback` | any login |
| `/exec` and `/exp` with SQL that reads, `BEGIN`/`COMMIT`/`ROLLBACK` | `read` on the database |
| `GET /api/info`, `GET /api/disk`, `GET /api/backups`, `GET /api/trigger-queue`, `GET /api/stats`, `GET /api/timers`, `GET /api/pins`, `/cursor` | `read` |
| `/exec` with `INSERT`, `UPDATE`, `DELETE`, `CALL`; `POST /write`, `POST /imp` into a table that is there | `write` |
| `/exec` with `CREATE`/`ALTER`/`DROP` of tables, views, functions, procedures, triggers, indexes; `BACKUP DATABASE`, `CHECK TABLE`; `POST /api/check`, `POST /api/backup`; a new table with `POST /imp`; saving, running and removing [timers](timers.md); pinning and unpinning [statements](pinned-queries.md) | `admin` on the database |
| `POST /api/databases`, `DELETE /api/databases/<name>`, `GET /api/settings`, `POST /api/settings`, `POST /api/restart`, `GET /api/audit`, `GET /api/feedback`, `POST /api/feedback/<id>`, `CREATE USER`, `GRANT`, ... | the user's own ROLE `admin` |
| `GET /api/databases` | any login; lists only the databases the user may read |

- A session (`POST /session`) can only be used by the user who opened it.
- Rights are per database, and per table with [table rights](table-rights.md); not per column or row.
- Users with [two-factor login](two-factor-login.md) send `"code"` with `POST /api/login`; without it the answer is 401 with `"totp": true`.

<a id="errors"></a>

## 401, 403 and 429 answers

| Answer | Means | What to do |
|---|---|---|
| 401 `{"error": "login required: log in (POST /api/login), or send a user name and password (HTTP Basic)", "login": true}` | no login on a server with users | log in |
| 401 `{"error": "wrong user name or password", "login": true}` | a wrong name or password | check them |
| 401 `{"error": "the login token is wrong or has expired; log in again (POST /api/login)"}` | an old or wrong login token | log in again |
| 401 `{"error": "your login has expired; log in again"}` | an old login cookie | log in again |
| 401 `{"error": "access token required"}` / `{"error": "wrong access token"}` | a server with `--token` | send the right token |
| 403 `{"error": "INSERT needs role write on database 'shop'; user 'report' has read"}` | logged in, but the role is too weak | use another user, or `GRANT` |
| 403 `{"error": "cross-site requests are not allowed"}` | a browser request from another site | call KDB from your backend |
| 403 `{"error": "this change came with a login cookie but without the right X-KDB-CSRF header; ...", "csrf": true}` | a change sent with a cookie but no `X-KDB-CSRF` | send the `csrf` value, see [CSRF](http-login.md#csrf) |
| 429 `{"error": "too many failed logins; try again in 4 s", "login": true}` and `Retry-After: 4` | too many failed logins | wait that many seconds |

The 403 role message is shown for real in [HTTP Basic](http-login.md#basic). In a 401 answer, `"login": true` tells a program that the server has users (so it should log in, not ask for a token).

**HTTP: A request from another web site is refused before any login check**

```http
POST /api/login
Content-Type: application/json
Origin: http://evil.example

{"user": "boss", "password": "boss-secret-1"}
```

Response:

HTTP 403 (application/json)

```text
{"error": "cross-origin requests are not allowed"}
```
