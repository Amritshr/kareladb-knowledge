# kareladb user

> Add, list and remove the users of the KarelaDB server, set their passwords and roles, from the command line.

- Category: Command line
- Keywords: users, user management, reset-2fa, two-factor, add user, password, change password, reset password, role, admin, ddl, write, read, none, list users, remove user, delete user, first user, last admin, --role, pipe password, \_system
- See also: [Users and roles](users-and-roles.md), [Keeping kareladb serve safe](server-security.md), [kareladb serve](cli-serve.md), [Logins, tokens and roles over HTTP](http-login.md)

`kareladb user` manages the **users of the server**: the people and programs that log in to `kareladb serve` (the web console, the HTTP API, the PostgreSQL port).
They are not the users of your app (for those, see [users and roles](users-and-roles.md)).

- Users belong to the **data folder**. KarelaDB keeps them in a hidden database `_system` inside it. Use `--data-dir <folder>` (or `KARELADB_DATA_DIR`) to choose the data folder.
- As soon as one user exists, the server asks every request for a login.
- `kareladb user` works only while `kareladb serve` is **stopped**. While the server runs, it has the users open; use SQL in its console then (`CREATE USER`, `ALTER USER`, `DROP USER`, `SHOW USERS`, `GRANT`, `REVOKE`).
- **Passwords are never given on the command line** (other users of the computer could see command lines). `kareladb user add` and `kareladb user passwd` ask for the password on the keyboard (the typed text is not shown, and you type it twice), or read one line from a pipe.

| Role | May do |
|---|---|
| `none` | nothing, until a `GRANT` on a database |
| `read` | `SELECT`, `SHOW`, `EXPLAIN`, CSV export, cursors, transactions |
| `write` | everything of `read`, and `INSERT`, `UPDATE`, `DELETE`, `CALL`, the line protocol |
| `admin` | everything, also `CREATE`/`ALTER`/`DROP`, `BACKUP`, `CHECK`, databases and users |

A role given here is for **every** database. For one database only, use `GRANT ... ON DATABASE` in SQL. Details: [users and roles](users-and-roles.md).

`kareladb user reset-2fa <name>` turns [two-factor login](two-factor-login.md#kareladb-user-reset-2fa) off for a user who lost the phone.

## kareladb user add

Syntax:

```sql
kareladb user add <name> [--role admin|ddl|write|read|none] [--data-dir <folder>]
```

Adds a user. The password is asked for, or read from a pipe.

| Option | Meaning | Default |
|---|---|---|
| `<name>` | Letters, digits, `_` and `-`, 1 to 63 characters. `Bob` and `bob` are the same user. | required |
| `--role` | `admin`, `ddl`, `write`, `read` or `none` | `admin` for the first user, `none` for later users |
| `--data-dir <folder>` | The data folder that gets the user | `KARELADB_DATA_DIR`, else `data` next to kareladb |

- **Exit code:** `0` added; `1` for every error.
- **The first user must be `admin`.** Otherwise nobody could manage users after the server starts asking for logins.
- **Password:** at least 12 characters, not the user name, at most 1024 bytes. Long random passwords (20 characters or more, from a password manager) are best for programs.
- Adding a user takes a moment: the password is hashed slowly on purpose (PBKDF2, 600,000 rounds), so a stolen copy is hard to guess.
- **From a script:** pipe the password, for example `Get-Content admin-password.txt | kareladb user add admin --role admin`. Keep that file readable only by you.

**Command line: The first user, with the password from a pipe**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
```

Output:

```text
user 'admin' added with role admin in ./kdb-data
```

**Command line: More users: a report reader and an app with no role yet**

```bash
kareladb user add admin
> Long-Admin-Passw0rd
kareladb user add report --role read
> Reports-only-secret-7
kareladb user add shop_app
> Another-long-secret-42
kareladb user list
```

Output:

`> kareladb user add admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb user add report --role read`

```text
user 'report' added with role read in ./kdb-data
```

`> kareladb user add shop_app`

```text
user 'shop_app' added with role none in ./kdb-data
```

`> kareladb user list`

```text
USER                     ROLE   GRANTS                         CHANGED
admin                    admin  -                              2026-10-24 12:24:37
report                   read   -                              2026-10-24 12:24:37
shop_app                 none   -                              2026-10-24 12:24:38
3 users in ./kdb-data
```

**Command line: The first user must be admin**

```bash
kareladb user add report --role read
> Reports-only-secret-7
```

Output:

```text
error: Invalid argument: the first user must have ROLE admin (CREATE USER name WITH PASSWORD '...' ROLE admin): once a user exists the server asks for a login, and only an admin can manage users
```

exit code 1

**Command line: A password that is too short**

```bash
kareladb user add admin --role admin
> short
```

Output:

```text
error: the password is too short: use at least 12 characters (a password manager can make a long random one)
```

exit code 1

```powershell
# Typed on the keyboard (not run here)
PS> kareladb user add admin --role admin --data-dir E:\kdb-data
New password:
Type it again:
user 'admin' added with role admin in E:/kdb-data
```

```bash
# Linux, as the kareladb system user, password from a file only root can read (not run here)
sudo cat /root/kdb-admin-password | sudo -u kdb kareladb user add admin --role admin --data-dir /srv/kareladb/data
```

## kareladb user passwd

Syntax:

```sql
kareladb user passwd <name> [--data-dir <folder>]
```

Sets a new password for a user. The password is asked for, or read from a pipe.

- **Exit code:** `0` set; `1` for every error (unknown user, short password, passwords not the same).
- Every login of that user ends at once (web console sessions and `POST /api/login` tokens). They must log in again with the new password.
- The new password is asked for before KarelaDB looks for the user, so a wrong name is reported after you typed the password.
- In SQL: `ALTER USER <name> WITH PASSWORD '...'` (every user may change their own password).

**Command line: A new password**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
kareladb user passwd admin
> Even-Longer-Admin-Passw0rd-2026
```

Output:

`> kareladb user add admin --role admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb user passwd admin`

```text
new password set for user 'admin'; logins with the old password end
```

**Command line: An unknown user**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
kareladb user passwd nobody
> Some-long-password-1
```

Output:

`> kareladb user add admin --role admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb user passwd nobody`

```text
error: Not found: user 'nobody' does not exist
```

exit code 1

## kareladb user role

Syntax:

```sql
kareladb user role <name> admin|ddl|write|read|none [--data-dir <folder>]
```

Changes the role of a user. The role is for every database.

- **Exit code:** `0` changed; `1` for every error.
- **The last admin** cannot lose the admin role while other users exist. Make another user admin first.
- In SQL: `ALTER USER <name> ROLE write`.

**Command line: Give the app the right to write**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
kareladb user add shop_app
> Another-long-secret-42
kareladb user role shop_app write
kareladb user list
```

Output:

`> kareladb user add admin --role admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb user add shop_app`

```text
user 'shop_app' added with role none in ./kdb-data
```

`> kareladb user role shop_app write`

```text
user 'shop_app' now has role write
```

`> kareladb user list`

```text
USER                     ROLE   GRANTS                         CHANGED
admin                    admin  -                              2026-10-24 12:24:37
shop_app                 write  -                              2026-10-24 12:24:38
2 users in ./kdb-data
```

**Command line: The last admin keeps the role**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
kareladb user add report --role read
> Reports-only-secret-7
kareladb user role admin read
```

Output:

`> kareladb user add admin --role admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb user add report --role read`

```text
user 'report' added with role read in ./kdb-data
```

`> kareladb user role admin read`

```text
error: Invalid argument: 'admin' is the last user with ROLE admin; make another user admin first (ALTER USER <name> ROLE admin), or nobody could manage users any more
```

exit code 1

**Command line: A role that does not exist**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
kareladb user role admin superuser
```

Output:

`> kareladb user add admin --role admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb user role admin superuser`

```text
error: the role must be admin, ddl, write, read or none (got 'superuser')
```

exit code 1

## kareladb user list

Syntax:

```sql
kareladb user list [--data-dir <folder>]
```

Lists the users: name, role, grants (roles on single databases) and the time of the last change (local time). It never shows passwords or hashes.

- **Exit code:** `0`, also when there are no users (then it says `no users in <folder> yet`).
- `GRANTS` shows `-`, or `database=role` for each `GRANT` (for example `shop=write`). Grants are made with SQL: `GRANT write ON DATABASE shop TO shop_app`.
- In SQL: `SHOW USERS`.

**Command line: No users yet**

```bash
kareladb user list
```

Output:

```text
no users in ./kdb-data yet (add one with: kareladb user add <name> --role admin)
```

**Command line: Users, and a grant made with SQL in kareladb shell**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
kareladb user add shop_app
> Another-long-secret-42
kareladb shell
> CREATE DATABASE shop;
> GRANT write ON DATABASE shop TO shop_app;
kareladb user list
```

Output:

`> kareladb user add admin --role admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb user add shop_app`

```text
user 'shop_app' added with role none in ./kdb-data
```

`> kareladb shell`

```text
KarelaDB 0.2.0-dev shell on default (data folder ./kdb-data)
End statements with ';'. Type .help for commands, .exit to quit.
kareladb> database 'shop' created
kareladb> user 'shop_app' has role write on database 'shop'
kareladb>
```

`> kareladb user list`

```text
USER                     ROLE   GRANTS                         CHANGED
admin                    admin  -                              2026-10-24 12:24:38
shop_app                 none   shop=write                     2026-10-24 12:24:38
2 users in ./kdb-data
```

## kareladb user remove

Syntax:

```sql
kareladb user remove <name> [--data-dir <folder>]
```

Removes a user. It can no longer log in.

- **Exit code:** `0` removed; `1` for every error (unknown user, the last admin).
- **The last admin** cannot be removed while other users exist.
- To stop the server asking for logins, remove every user. The last user (an admin) can be removed when it is alone.
- In SQL: `DROP USER <name>`.

**Command line: Remove a user**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
kareladb user add report --role read
> Reports-only-secret-7
kareladb user remove report
kareladb user list
```

Output:

`> kareladb user add admin --role admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb user add report --role read`

```text
user 'report' added with role read in ./kdb-data
```

`> kareladb user remove report`

```text
user 'report' removed
```

`> kareladb user list`

```text
USER                     ROLE   GRANTS                         CHANGED
admin                    admin  -                              2026-10-24 12:24:38
1 user in ./kdb-data
```

**Command line: The last admin cannot be removed while others exist**

```bash
kareladb user add admin --role admin
> Long-Admin-Passw0rd
kareladb user add report --role read
> Reports-only-secret-7
kareladb user remove admin
```

Output:

`> kareladb user add admin --role admin`

```text
user 'admin' added with role admin in ./kdb-data
```

`> kareladb user add report --role read`

```text
user 'report' added with role read in ./kdb-data
```

`> kareladb user remove admin`

```text
error: Invalid argument: 'admin' is the last user with ROLE admin; make another user admin first (ALTER USER <name> ROLE admin), or nobody could manage users any more
```

exit code 1

<a id="errors"></a>

## Errors of kareladb user

Syntax:

```sql
usage: kareladb user add <name> [--role admin|ddl|write|read|none]
error: no password given (type it, or pipe it in: echo <password> | kareladb user add ...)
error: the users database (...) is open in another program, for example a running kareladb serve; ...
```

| Message | Why | Fix |
|---|---|---|
| `usage: kareladb user ...` | Unknown sub-command, or a missing or extra argument | See the syntax above |
| `no password given` | The pipe was empty | Pipe one line, or type it |
| `the password is too short` | Fewer than 12 characters | A longer password (a password manager can make one) |
| `the password must not be the user name` | The password is the user name | Another password |
| `the two passwords are not the same; nothing was changed` | You typed two different passwords | Type it again |
| `the first user must have ROLE admin` | The first user had `--role read`, `write` or `none` | `--role admin` (or no `--role`) |
| `is the last user with ROLE admin` | The change would leave no admin | Make another user admin first |
| `user '...' already exists` / `does not exist` | Wrong name | `kareladb user list` |
| `bad user name` | Other characters than letters, digits, `_`, `-` | Change the name |
| `the users database ... is open in another program` | `kareladb serve` runs on this data folder | Stop the server, or use SQL in its console |
| `no users in <folder> yet` (for passwd, role, remove) | The data folder has no users; exit code `1` | Check `--data-dir` |

**Command line: A missing argument**

```bash
kareladb user add
```

Output:

```text
usage: kareladb user add <name> [--role admin|ddl|write|read|none]
       kareladb user passwd <name>
       kareladb user role <name> admin|ddl|write|read|none
       kareladb user list
       kareladb user remove <name>
       kareladb user reset-2fa <name>   turn two-factor login off (a lost phone)
       [--data-dir <folder>]  (the password is asked for, or read from a pipe)
```

exit code 1
