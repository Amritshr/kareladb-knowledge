# Two-factor login (TOTP)

> A database user can log in to the console and POST /api/login with a password and a 6-digit code from an authenticator app.

- Category: Users & security
- Keywords: two-factor, 2FA, TOTP, step-up, step\_up\_actions, step\_up\_minutes, X-KDB-TOTP, /api/step-up, step\_up\_required, one-time code, authenticator app, Google Authenticator, Microsoft Authenticator, otpauth, ENABLE TOTP, DISABLE TOTP, code, lost phone, reset-2fa, password policy, password rules, 12 characters
- See also: [Users and roles](users-and-roles.md), [Logins, tokens and roles over HTTP](http-login.md), [Keeping kareladb serve safe](server-security.md), [kareladb user](cli-users.md), [Audit log](audit-log.md)

With two-factor login, a stolen password is not enough: the login also needs the 6-digit code that an authenticator app on the phone shows (it changes every 30 seconds, RFC 6238).

Use it for **people** (admins in the web console). Programs keep a user without two-factor login: HTTP Basic and the PostgreSQL port cannot ask for a code, so they refuse a two-factor user.

<a id="enable-totp"></a>

## ALTER USER ... ENABLE TOTP

Syntax:

```sql
ALTER USER <name> ENABLE TOTP
ALTER USER <name> DISABLE TOTP
```

Makes a new secret for the user and turns two-factor login on. The answer has an `otpauth://` URI and the secret: put one of them into the authenticator app **now**. It is shown only this once.

- **Returns:** one row `user`, `otpauth_uri`, `secret`, and the message `two-factor login is on for user 'boss': ...`.
- **Notes:**
  - Users may do it for themselves; admins for everyone. `DISABLE TOTP` turns it off.
  - The console and `POST /api/login` then ask for the code after a right password: `{"error":"enter the 6-digit code from your authenticator app","totp":true}`. Send it as `"code"` with the password.
  - A code works once, 30 seconds before or after its time too. Wrong codes count as failed logins (after 5 the address must wait) and are in the [audit log](audit-log.md).
  - Older KarelaDB programs refuse a data folder with two-factor users.

**Example: Turn two-factor login on for an admin**

```sql
CREATE USER boss WITH PASSWORD 'Long-Admin-Passw0rd' ROLE admin;
ALTER USER boss ENABLE TOTP;
```

Result:

`CREATE USER boss WITH PASSWORD '***' ROLE admin`

```text
user 'boss' created with role admin
```

`ALTER USER boss ENABLE TOTP`

| user (STRING) | otpauth_uri (STRING) | secret (STRING) |
|---|---|---|
| boss | otpauth://totp/KarelaDB:boss?secret=EOKMM4XA4WUIVD3DRDVH4DGBG5LJ3GMH&issuer=KarelaDB&algorithm=SHA1&digits=6&period=30 | EOKMM4XA4WUIVD3DRDVH4DGBG5LJ3GMH |

(1 row)

```text
two-factor login is on for user 'boss': add the otpauth URI (or the secret) to an authenticator app now; it is shown only once
```

<a id="kareladb-user-reset-2fa"></a>

## kareladb user reset-2fa

Syntax:

```sql
kareladb user reset-2fa <name> [--data-dir <folder>]
```

Turns two-factor login off for a user who lost the phone, while `kareladb serve` is stopped. The user logs in with the password only until `ALTER USER <name> ENABLE TOTP` is run again.

- **Returns:** `two-factor login is off for user 'boss'; ...`, or `user 'boss' has no two-factor login; nothing to do`.
- **Notes:** the change is written to the audit log of the data folder.

**Command line: A user without two-factor login: nothing to do**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
> Long-Admin-Passw0rd
kareladb user reset-2fa admin
```

Output:

`> kareladb user add admin --role admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb user reset-2fa admin`

```text
user 'admin' has no two-factor login; nothing to do
```

<a id="password-policy"></a>

## Password policy

Syntax:

```sql
at least 12 characters, at most 1024 bytes, not the user name
```

KarelaDB refuses a new password of a database user that is too short or is the user name. Characters are counted, not bytes (12 letters of any language, such as Nepali, are fine). Passwords set before this rule keep working.

**Example: A too short password is refused** (shows an error)

```sql
CREATE USER admin WITH PASSWORD 'ktm-2026' ROLE admin;
```

Result:

Error: `the password is too short: use at least 12 characters (a password manager can make a long random one)`

<a id="token-rotation"></a>

## Session tokens

Every login gets a new random token. When the login request still carries an old login (the `kdb_login` cookie or a Bearer token), that old login ends: a token somebody planted before the login is worth nothing afterwards.

<a id="step-up"></a>

## Step-up codes for dangerous actions

Syntax:

```sql
kareladb.conf:    "step_up_actions": "on", "step_up_minutes": 5
environment: KARELADB_STEP_UP_ACTIONS=on  KARELADB_STEP_UP_MINUTES=5
```

A console left open is a risk: anyone at that desk could drop a table. With `step_up_actions` on, a few dangerous actions also need a two-factor code typed in the last `step_up_minutes` (5 by default). It is off by default.

| Needs a fresh code | |
|---|---|
| SQL | `DROP TABLE`, `DROP DATABASE`, `CREATE USER`, `ALTER USER`, `DROP USER`, `GRANT`, `REVOKE`, `ALTER SYSTEM` |
| HTTP | `POST /api/settings`, `DELETE /api/databases/<name>` |

- **How to give the code:** the console shows a code box by itself and then runs the action again. Programs send the header `X-KDB-TOTP: 123456` with the request, or call `POST /api/step-up` with `{"code": "123456"}` once; the code then counts for that login for `step_up_minutes`.
- **Without a code:** the answer is 403 with `"code": "step_up_required"`, the action, and `"totp": true`.
- **A login with a code counts too:** right after logging in, the first dangerous action needs no second code.
- **Users without two-factor login** are refused with `"totp": false` and a message to enrol: `ALTER USER <name> ENABLE TOTP`. Enrolling yourself never needs a code.
- **Not asked:** the server's access token (`--token`) and a local server without logins have no user to ask.
- **Changing it:** `POST /api/settings` with `{"step_up_actions": "on"}` or `{"step_up_minutes": 10}` saves to kareladb.conf and works at once. `step_up_minutes` also takes a time like `"30s"`.
- **Not covered yet:** the PostgreSQL port. A user with two-factor login cannot log in there at all; keep other users off it, or give them no admin role, while step-up matters.

```text
POST /exec   DROP TABLE trades
-> 403 {"error":"DROP TABLE needs a fresh two-factor code: send it as the header X-KDB-TOTP, or once with
        POST /api/step-up {\"code\": \"123456\"} (good for 5 minutes)","code":"step_up_required",
        "action":"DROP TABLE","totp":true,"step_up_minutes":5}
```
