# API tokens

> Named, revocable secrets for apps - each acts as one user, and DROP TOKEN stops it at once.

- Category: Users & security
- Keywords: API token, api tokens, token, tokens, CREATE TOKEN, DROP TOKEN, SHOW TOKENS, revoke, revoke token, kdbt\_, Bearer, Authorization, EXPIRES, personal access token, service token, app token, 401
- See also: [Users and roles](users-and-roles.md), [Logins, tokens and roles over HTTP](http-login.md), [Keeping kareladb serve safe](server-security.md), [Protection - timeouts, limits, safe updates, read-only](protection.md)

An **API token** is a long secret an app sends with every request, like the server's `--token`. The difference: you can have **many**, each has a **name**, each acts as **one user** (with that user's rights), and you can **remove one** without touching the others.

| | `--token` of `kareladb serve` | API token |
|---|---|---|
| How many | one | as many as you like |
| Rights | everything | the rights of its user |
| Change or revoke | restart the server with another one | `DROP TOKEN name`, at once |
| Kept | on the command line | in the data folder (only its hash) |

Give each app its own token. When one app is retired or its secret leaks, drop that token; the other apps go on.

**Example: A token for the chart app, a read-only user**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER charts WITH PASSWORD 'Chart-app-secret-11' ROLE read;
```

```sql
CREATE TOKEN chart_app FOR USER charts EXPIRES IN 90 DAYS;
SHOW TOKENS;
```

Result:

`CREATE TOKEN chart_app FOR USER charts EXPIRES IN 90 DAYS`

| name (STRING) | user (STRING) | token (STRING) | expires (TIMESTAMP) |
|---|---|---|---|
| chart_app | charts | kdbt_uz5bsgkQzttWQOa_Ymxt1T2fvhN73iugFgTMjWDs1Ic | 2027-01-22T03:01:35.562Z |

(1 row)

```text
token 'chart_app' for user 'charts' created: copy it now, it is shown only this once. Send it as Authorization: Bearer <token>
```

`SHOW TOKENS`

| name (STRING) | user (STRING) | prefix (STRING) | created (TIMESTAMP) | expires (TIMESTAMP) | expired (BOOL) | created_by (STRING) | last_used (TIMESTAMP) |
|---|---|---|---|---|---|---|---|
| chart_app | charts | kdbt_uz5b... | 2026-10-24T03:01:35.590Z | 2027-01-22T03:01:35.562Z | false | NULL | NULL |

(1 row)

## CREATE TOKEN

Syntax:

```sql
CREATE TOKEN name [FOR USER user] [EXPIRES IN n DAYS]
```

Makes a new token and shows its secret **once**.

| Part | Meaning |
|---|---|
| `name` | letters, digits, `_` and `-`, 1 to 63 characters; unique (case does not matter). Say which app uses it. |
| `FOR USER user` | the user it acts as. Without it: the user who runs the statement. |
| `EXPIRES IN n DAYS` | it stops working after that many days (1 to 99999). Without it: never. |

- **Returns:** one row `name`, `user`, `token`, `expires`. The `token` looks like `kdbt_` and 43 more letters. Copy it now: KarelaDB keeps only its SHA-256, so nobody can show it again.
- **Notes:**
  - Any user may make a token for **themselves**. A token for another user needs `ROLE admin`.
  - The app sends it as `Authorization: Bearer kdbt_...` on the HTTP API (`/exec`, `/write`, `/imp`, `/api/...`). It is not a password for the PostgreSQL port; use the user's password there.
  - It can do exactly what its user can do, including [table rights](table-rights.md), the user's [time limit](users-and-roles.md#statement-timeout) and [rate limit](protection.md#rate-limits). For a read-only app, make a user with `ROLE read` and a token for it.
  - A new password for the user does **not** end the user's tokens (apps keep working). `DROP USER` removes the user's tokens.
  - The session that runs it needs a user: with the server's `--token` or in `kareladb sql`, write `FOR USER`.

**Example: Two apps, two tokens for one user**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE USER loader WITH PASSWORD 'Loader-secret-long-5' ROLE write;
```

```sql
CREATE TOKEN price_feed FOR USER loader;
CREATE TOKEN backfill FOR USER loader EXPIRES IN 7 DAYS;
```

Result:

`CREATE TOKEN price_feed FOR USER loader`

| name (STRING) | user (STRING) | token (STRING) | expires (TIMESTAMP) |
|---|---|---|---|
| price_feed | loader | kdbt_LArMJU2exBFxafYguXKkFvn1YKQBoOjspr5oTXJuygk | NULL |

(1 row)

```text
token 'price_feed' for user 'loader' created: copy it now, it is shown only this once. Send it as Authorization: Bearer <token>
```

`CREATE TOKEN backfill FOR USER loader EXPIRES IN 7 DAYS`

| name (STRING) | user (STRING) | token (STRING) | expires (TIMESTAMP) |
|---|---|---|---|
| backfill | loader | kdbt_kAMtmceCipXcT7j4TcITCXPvtlhUAXISD7H7Emrb5hU | 2026-10-31T03:01:35.782Z |

(1 row)

```text
token 'backfill' for user 'loader' created: copy it now, it is shown only this once. Send it as Authorization: Bearer <token>
```

**Example: The name is taken** (shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE TOKEN price_feed FOR USER admin;
```

```sql
CREATE TOKEN price_feed FOR USER admin;
```

Result:

Error: `token 'price_feed' already exists`

**Example: A token acts as a user** (shows an error)

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
```

```sql
CREATE TOKEN price_feed;
```

Result:

Error: `CREATE TOKEN needs FOR USER <name> here: this session has no user (the server's --token, or a local tool), and a token always acts as one user`

## DROP TOKEN

Syntax:

```sql
DROP TOKEN [IF EXISTS] name
```

Revokes a token. Every request with it gets `401` from then on: `the API token is wrong, has expired or was dropped (SHOW TOKENS)`.

- **Returns:** `token 'name' dropped: it stops working at once`.
- **Notes:** a user may drop their own tokens; other users' tokens need `ROLE admin`.

**Example**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE TOKEN price_feed FOR USER admin;
```

```sql
DROP TOKEN price_feed;
DROP TOKEN IF EXISTS price_feed;
```

Result:

`DROP TOKEN price_feed`

```text
token 'price_feed' dropped: it stops working at once
```

`DROP TOKEN IF EXISTS price_feed`

```text
token 'price_feed' does not exist
```

## SHOW TOKENS

Syntax:

```sql
SHOW TOKENS
```

Lists the tokens. Never the secrets: only the first letters, so you can tell which one an app has.

| Column | Meaning |
|---|---|
| `name`, `user` | the token and the user it acts as |
| `prefix` | its first letters, like `kdbt_Ab3x...` |
| `created`, `expires` | when it was made; when it stops (`NULL` = never) |
| `expired` | `true` once `expires` has passed |
| `created_by` | who made it (`NULL`: the `--token` or a local tool) |
| `last_used` | its last request since the server started (`NULL`: none yet) |

- **Notes:** an admin sees every token; other users see their own. The web console lists them on the **Settings** page, where you can make and remove them too.

**Example**

Setup:

```sql
CREATE USER admin WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
CREATE TOKEN price_feed FOR USER admin EXPIRES IN 30 DAYS;
```

```sql
SHOW TOKENS;
```

Result:

| name (STRING) | user (STRING) | prefix (STRING) | created (TIMESTAMP) | expires (TIMESTAMP) | expired (BOOL) | created_by (STRING) | last_used (TIMESTAMP) |
|---|---|---|---|---|---|---|---|
| price_feed | admin | kdbt_NEKC... | 2026-10-24T03:01:36.250Z | 2026-11-23T03:01:36.216Z | false | NULL | NULL |

(1 row)

<a id="kept"></a>

## Where tokens and logins are kept

Both live in the hidden `_system` database of the data folder, as **hashes only**:

| Table | Holds |
|---|---|
| `api_tokens` | name, user, the SHA-256 of the secret, its first letters, times |
| `login_sessions` | the SHA-256 of each login token of `POST /api/login` and the console, its user and when it ends |

So a server restart logs nobody out, and apps with a token go on. A login still ends after 12 hours, at logout, or when the user gets a new password or is dropped. An older KarelaDB program does not know these tables: there, tokens do not work and everyone logs in again.
