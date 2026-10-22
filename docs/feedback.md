# Comments and suggestions

> How people who use a KDB server send comments, suggestions and problem reports, and how its admins read them.

- Category: Web console
- Keywords: feedback, comment, comments, suggestion, suggestions, problem report, bug report, send feedback, contact, POST /api/feedback, GET /api/feedback, POST /api/feedback/\<id\>, \_feedback
- See also: [Web console](web-console.md), [Logins, tokens and roles over HTTP](http-login.md), [Users and roles](users-and-roles.md), [About KDB](about-kdb.md)

Anyone who may use a KDB server can send its admins a **comment**, a **suggestion** or a **problem** report. The message is saved on that server, in the table `_feedback`, so it survives restarts and is part of every backup.

| Who | What they can do | Where |
|---|---|---|
| anyone who can open the console (logged in, or with the token) | send a message | **Help > Comments and suggestions** |
| a server admin (the user's own `ROLE admin`, or the token) | read every message and mark it read or done | the same page, under **Received** |
| a program | the same, over HTTP | [POST /api/feedback](#post-api-feedback), [GET /api/feedback](#get-api-feedback), [POST /api/feedback/<id>](#mark-feedback) |

- Messages go to the admins of **this** server, not to the makers of KDB.
- A message can be up to 4,000 characters. A name or email for an answer is optional.
- One user can send at most 10 messages in 10 minutes (without a user name: one client address), so a script cannot fill the table.
- Messages are kept in the hidden `_system` database when the server has a data folder, or in the served database when `kdb serve` runs on one folder.

<a id="page"></a>

## The page in the console

Open **Help > Comments and suggestions**.

1. Pick what it is: **Comment**, **Suggestion** or **Problem**.
2. Write the message. **Ctrl+Enter** sends it too.
3. Optionally add a name or email, if you would like an answer.
4. Press **Send**. The page says which number the message was saved as.

A server admin also sees **Received**: every message, newest first, with its kind, time, sender and state. **New**, **Read**, **Done** and **All** filter the list; **Mark read**, **Mark done** and **Mark new** change a message's state.

<a id="post-api-feedback"></a>

## POST /api/feedback

Syntax:

```sql
POST /api/feedback
Content-Type: application/json

{"kind": "comment | suggestion | problem", "message": "...", "contact": "...", "page": "..."}
```

Saves one message. Needs a login or the token, like every `/api` route; no role is needed.

| Field | Needed | Rule |
|---|---|---|
| `kind` | no (default `comment`) | `comment`, `suggestion` or `problem` |
| `message` | yes | 1 to 4,000 characters, no control characters except line breaks and tabs |
| `contact` | no | up to 200 characters |
| `page` | no | where it was sent from, up to 200 characters |

- **Returns:** `{"id": 12, "saved": true}`.
- **Errors:** 400 with a message that says which field is wrong; 401 without a login; 429 after 10 messages in 10 minutes from one user (or one address, for the token).
- The server adds the time, the user name and the client address itself.

```text
curl -s -X POST "$KDB_URL/api/feedback" -H "Authorization: Bearer $KDB_TOKEN" \
  -H "Content-Type: application/json" \
  --data-binary '{"kind":"suggestion","message":"Please add a CSV export to dashboards.","contact":"ram@example.com"}'

{"id":1,"saved":true}
```

<a id="get-api-feedback"></a>

## GET /api/feedback

Syntax:

```sql
GET /api/feedback[?status=new|read|done][&limit=N]
```

Reads the messages, newest first, as columns and rows like [/exec](http-exec.md). Needs a **server admin**: the user's own `ROLE admin` or the token, because messages can hold names and email addresses.

| Parameter | Meaning | Default |
|---|---|---|
| `status` | only messages in this state: `new`, `read` or `done` | all |
| `limit` | at most this many rows; more than 1,000 counts as 1,000 | `100` |

| Column | Type | Meaning |
|---|---|---|
| `id` | `LONG` | the message number |
| `time` | `TIMESTAMP` | when it was sent (UTC) |
| `kind` | `STRING` | `comment`, `suggestion` or `problem` |
| `status` | `STRING` | `new`, `read` or `done` |
| `message` | `STRING` | the text |
| `contact` | `STRING` | the name or email given, or `NULL` |
| `page` | `STRING` | where it was sent from |
| `user` | `STRING` | the logged-in user, or `NULL` for the token |
| `client` | `STRING` | the client address |

- **Returns:** `{"columns": [...], "dataset": [[...], ...], "count": N}`. A server where nobody has sent anything yet answers with no rows.
- **Errors:** 400 for an unknown `status`; 401 without a login; 403 for a user who is not a server admin.

<a id="mark-feedback"></a>

## POST /api/feedback/<id>

Syntax:

```sql
POST /api/feedback/<id>
Content-Type: application/json

{"status": "new | read | done"}
```

Changes the state of one message. `status` can also be a query or form field (`?status=done`). Needs a **server admin**, like reading.

- **Returns:** `{"id": 12, "status": "done"}`.
- **Errors:** 400 when `<id>` is not a whole number above 0, or `status` is not `new`, `read` or `done`; 403 for a user who is not a server admin; 404 `there is no message #<id>`.

**HTTP: Send a suggestion, read the new ones, mark it done**

```http
POST /api/feedback
Content-Type: application/json

{"kind":"suggestion","message":"Please add a CSV export to dashboards.","contact":"ram@example.com","page":"console"}
###
GET /api/feedback?status=new
###
POST /api/feedback/{{id}}
Content-Type: application/json

{"status":"done"}
```

Response:

`POST /api/feedback`

HTTP 200 (application/json)

```text
{"id": 1, "saved": true}
```

`GET /api/feedback?status=new`

HTTP 200 (application/json)

```text
{
  "columns": [
    {"name": "id", "type": "LONG"},
    {"name": "time", "type": "TIMESTAMP"},
    {"name": "kind", "type": "STRING"},
    {"name": "status", "type": "STRING"},
    {"name": "message", "type": "STRING"},
    {"name": "contact", "type": "STRING"},
    {"name": "page", "type": "STRING"},
    {"name": "user", "type": "STRING"},
    {"name": "client", "type": "STRING"}
  ],
  "dataset": [
    [
      1,
      "2026-10-22T05:43:41.888Z",
      "suggestion",
      "new",
      "Please add a CSV export to dashboards.",
      "ram@example.com",
      "console",
      null,
      "127.0.0.1 (http)"
    ]
  ],
  "count": 1
}
```

`POST /api/feedback/{{id}}`

HTTP 200 (application/json)

```text
{"id": 1, "status": "done"}
```

**HTTP: A message number that does not exist**

```http
POST /api/feedback/999
Content-Type: application/json

{"status":"read"}
```

Response:

HTTP 404 (application/json)

```text
{"error": "there is no message #999"}
```
