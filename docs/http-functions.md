# Calling web services from SQL (http_get, http_post)

> http_get and http_post call a web address from SQL, a procedure or a timer. Off until an admin lists the hosts they may call.

- Category: Stored procedures
- Keywords: http\_get, http\_post, http, https, web service, webhook, call url, rest api, outbound, http\_functions, http\_timeout\_ms, KARELADB\_HTTP\_FUNCTIONS, allowlist, fetch, curl
- See also: [Stored procedures](procedures.md), [Timers](timers.md), [Triggers](triggers.md), [JSON functions](functions-json.md), [Users and roles](users-and-roles.md), [Settings page (data folder, old log, capacity, program files and users)](console-settings.md)

`http_get` and `http_post` let SQL call another service. A procedure can tell a settlement service that a day is done. A timer can ask a checker every hour.

- They are **off** until an admin lists the hosts they may call (the setting `http_functions`).
- They need role **write** on the database, because a call changes things outside it.
- Every call really runs. The answer is never kept in the result cache.
- The headers you send are never written to a log. They often hold a token.

**Example: On a server where nobody turned them on, a call is refused** (shows an error)

```sql
SELECT http_get('http://10.0.0.5:8080/health');
```

Result:

Error: `line 1, column 8: http_get: calling web addresses from SQL is off on this server; an admin turns it on by listing the hosts it may call in the setting http_functions (kareladb.conf, KARELADB_HTTP_FUNCTIONS or the Settings page)`

## http_get

Syntax:

```sql
http_get(url)
http_get(url, headers)
```

Sends a `GET` request and waits for the whole answer.

| Argument | Type | Meaning |
|---|---|---|
| `url` | text | `http://host[:port]/path` or `https://...`. |
| `headers` | JSON object | extra request headers, like `'{"Authorization":"Bearer abc"}'`. Optional. |

- **Returns:** `JSON` like `{"status":200,"headers":{"content-type":"application/json"},"body":"..."}`.
  - `status` is the HTTP status. A `404` or a `500` is an answer, not an error.
  - `headers` has the answer's headers, names in lower case.
  - `body` is the answer as text.
- **NULL:** a `NULL` url gives `NULL`. `NULL` headers count as none.
- **Errors:** the statement fails when the host is not allowed, the address cannot be reached, the time limit passes, or the answer is over 16 MB.

## http_post

Syntax:

```sql
http_post(url, body)
http_post(url, body, content_type)
http_post(url, body, content_type, headers)
```

Sends a `POST` request with a body.

| Argument | Type | Meaning |
|---|---|---|
| `url` | text | as for `http_get`. |
| `body` | text or JSON | what to send. |
| `content_type` | text | the `Content-Type`. Default `application/json` for a JSON value, else `text/plain; charset=utf-8`. |
| `headers` | JSON object | extra request headers. Optional. |

- **Returns:** the same JSON as `http_get`.

## Reading the answer

Use the JSON operators and functions on the result:

| You want | Write |
|---|---|
| the status | `json_value_long(r, '$.status')` |
| the body as text | `r ->> 'body'` |
| one header | `r -> 'headers' ->> 'content-type'` |
| a field of a JSON body | `json(r ->> 'body') ->> 'ok'` |

A procedure that calls a service and keeps what it said (it runs once `http_functions` lists `10.0.0.5:8080`):

```sql
CREATE TABLE settle_log (at TIMESTAMP, status INT, body STRING);

CREATE PROCEDURE settle_day() AS BEGIN
  INSERT INTO settle_log
  SELECT now(), json_value_long(r, '$.status'), r ->> 'body'
  FROM (SELECT http_post('http://10.0.0.5:8080/settle', json_object('day', current_date),
                         'application/json', '{"Authorization":"Bearer my-token"}') AS r) AS call;
END;
```

## Turning them on

| Setting | Where | Default | Meaning |
|---|---|---|---|
| `http_functions` | kareladb.conf, `KARELADB_HTTP_FUNCTIONS`, the Settings page | `off` | the hosts SQL may call, separated by commas |
| `http_timeout_ms` | kareladb.conf, `KARELADB_HTTP_TIMEOUT_MS`, the Settings page | `10000` | the most milliseconds one call may take, redirects included |

kareladb.conf wins over the environment. A save on the Settings page applies at once, without a restart.

How to write the list:

| Entry | Allows |
|---|---|
| `api.example.com` | that host, any port |
| `10.0.0.5:8080` | that address, port 8080 only |
| `*` | every host (still not `169.254.x.x`, see below) |
| `off` | nothing: the functions are off |

```text
{"http_functions": "settle.internal:8080, 10.0.0.5", "http_timeout_ms": 5000}
```

## What a call may do

| Rule | Why |
|---|---|
| `http://` and `https://` only | nothing else is a web service |
| https checks the certificate against the authorities the computer trusts | so nobody in between can answer instead |
| at most 3 redirects, each to an allowed host | a redirect cannot lead out of the list |
| `Authorization` and `Cookie` are not sent on to another host | a token is for the host it was written for |
| `169.254.x.x` and `0.x.x.x` are refused unless that host is listed by itself | clouds give out secret keys at 169.254.169.254 |
| at most 16 MB of answer | a big answer is an error, never a cut body |
| IPv4 only | |

- A self-signed certificate is not trusted. Call such a service on the local network over `http://`.
- On Linux the trusted authorities come from the usual CA bundle file (`/etc/ssl/certs/ca-certificates.crt` and others). Set `SSL_CERT_FILE` to use another file.
- A build without TLS says so when asked for `https://`.

## Who may call

| Caller | May call |
|---|---|
| no login (a local tool, the server token) | yes |
| a user with role `write` or `admin` | yes |
| a user with role `read` | no: "needs role write", also through a view |
| a procedure (`CALL` needs write), a trigger, a timer | yes |

The text of a statement goes to the activity log and the slow-query log. There, every argument after the address shows as `'***'`, so a token in the headers is never kept.
