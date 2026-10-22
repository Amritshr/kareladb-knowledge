# LISTEN and NOTIFY

> Send a message to every client that listens on a channel when a transaction commits - over the PostgreSQL port (LISTEN) or HTTP (GET /listen, server-sent events).

- Category: Postgres protocol
- Keywords: LISTEN, NOTIFY, UNLISTEN, UNLISTEN *, pg_notify, notification, notifications, pub/sub, pubsub, publish, subscribe, PUBLISH, SUBSCRIBE, PSUBSCRIBE, pattern, pmessage, redis, push, event, events, channel, payload, NotificationResponse, GET /listen, /listen, server-sent events, SSE, EventSource, text/event-stream, payload string too long, channel name cannot be empty, 54000, trigger notify, LISTEN needs a connection that stays open
- See also: [PostgreSQL protocol (port 8832)](postgres-protocol.md), [Triggers](triggers.md), [Transactions](transactions.md), [Run SQL over HTTP (/exec, /exp)](http-exec.md), [CREATE TABLE (row-ttl)](create-table.md#row-ttl), [Key-value store (Redis-like) (kv-pubsub)](kv.md#kv-pubsub)

`NOTIFY` sends a short message on a **channel**. Every client that listens on that channel gets it, the moment the sending transaction commits. It works as in PostgreSQL 14, and web pages can listen over HTTP too.

| | How |
|---|---|
| Send | `NOTIFY orders, 'order 42 paid'` or `SELECT pg_notify('orders', 'order 42 paid')`, from any client, a [trigger](triggers.md) or a procedure |
| Listen (PostgreSQL port) | `LISTEN orders` on a connection that stays open ([below](#listen-pg)) |
| Listen (HTTP, web pages) | `GET /listen?channel=orders`: server-sent events ([below](#listen-http)); `?pattern=price.*` for every channel a pattern matches |
| Redis-style | `PUBLISH`, `PUBSUB` and keyspace events through `POST /kv` ([key-value store](kv.md#kv-pubsub)): the same channels, sent at once |

The rules, the same as PostgreSQL's:

- A message is delivered when its transaction **commits**, never after a `ROLLBACK`. `ROLLBACK TO SAVEPOINT` drops the ones sent after the savepoint.
- The same channel and payload sent twice in one transaction arrive **once**. Otherwise the order is kept.
- Channels belong to one database: a `NOTIFY` in `market` never reaches a listener of `app`.
- A message is a signal for clients connected **now**: nothing is stored, and nothing is sent again after a restart. Read the table after a message to get the data.

<a id="notify"></a>

## NOTIFY and pg_notify()

Syntax:

```sql
NOTIFY channel [, 'payload']
pg_notify(channel_text, payload_text)
```

| Part | Meaning |
|---|---|
| `channel` | a name. Without quotes it is lower case (`NOTIFY Orders` goes to `orders`); `"Orders"` keeps its case |
| `payload` | text of at most 7999 bytes; none = empty |
| `pg_notify(...)` | the same as a function, for a value made in the query. It takes the channel as written (no lower case) |

- **Returns:** `NOTIFY`; `pg_notify()` gives `NULL`.
- **Errors:** `payload string too long`, `channel name cannot be empty`, `channel name too long` (more than 63 bytes).
- Anyone who may read the database may send and listen, as in PostgreSQL.

**Example: Send inside a transaction: it goes out at COMMIT**

```sql
BEGIN;
NOTIFY orders, 'order 42 paid';
SELECT pg_notify('orders', 'order ' || 43 || ' paid');
COMMIT;
```

Result:

`BEGIN`

```text
transaction started
```

`NOTIFY orders, 'order 42 paid'`

```text
notification on channel 'orders': sent to its listeners when the transaction commits
```

`SELECT pg_notify('orders', 'order ' || 43 || ' paid')`

| pg_notify('orders', 'order ' \|\| 43 \|\| ' paid') (STRING) |
|---|
| NULL |

(1 row)

`COMMIT`

```text
transaction committed: 0 change(s) saved
```

**Example: A payload that is too long** (shows an error)

```sql
SELECT pg_notify('orders', repeat('x', 8000));
```

Result:

Error: `line 1, column 8: pg_notify: payload string too long`

<a id="notify-trigger"></a>

### From a trigger

A [trigger](triggers.md) can send a message for each new row. It is part of the statement's transaction: a failed insert sends nothing.

**Example: Tell the listeners about every paid order**

```sql
CREATE TABLE payments (id LONG PRIMARY KEY, amount DOUBLE);
CREATE TRIGGER tell_paid AFTER INSERT ON payments EXECUTE BEGIN
  SELECT pg_notify('payments', 'paid ' || id) FROM NEW;
END;
INSERT INTO payments VALUES (1, 250.0), (2, 99.5);
```

Result:

`CREATE TABLE payments (`

```text
table 'payments' created
```

`CREATE TRIGGER tell_paid AFTER INSERT ON payments EXECUTE BEGIN`

```text
trigger 'tell_paid' created on table 'payments'
```

`INSERT INTO payments VALUES (1, 250.0), (2, 99.5)`

```text
2 row(s) inserted
```

`SELECT pg_notify('payments', 'paid ' || id) FROM NEW`

| pg_notify('payments', 'paid ' \|\| id) (STRING) |
|---|
| NULL |
| NULL |

(2 rows)

<a id="listen-pg"></a>

## LISTEN on the PostgreSQL port

Syntax:

```sql
LISTEN channel
UNLISTEN channel | *
```

- The connection gets a `NotificationResponse` (channel, payload, the sender's process id) for each message. Drivers show them their own way: psql prints `Asynchronous notification "orders" with payload "..." received from server process with PID 17.`, pgx has `WaitForNotification`, psycopg `conn.notifies()`, node-pg the `notification` event.
- An idle connection gets it at once. A connection inside `BEGIN ... COMMIT` gets it when that transaction ends, as in PostgreSQL. Its own messages come right after its `COMMIT`.
- `LISTEN` inside `BEGIN ... COMMIT` starts at `COMMIT`, and not at all after `ROLLBACK`. `DISCARD ALL` stops every listen.

<a id="listen-http"></a>

## GET /listen: server-sent events

Syntax:

```sql
GET /listen?channel=orders[&channel=payments][&pattern=price.*][&db=name]
```

The reply is `text/event-stream` and stays open. A browser reads it with `EventSource`:

```js
const es = new EventSource('/listen?channel=orders');
es.onmessage = (e) => {
  const n = JSON.parse(e.data);  // {"channel":"orders","payload":"order 42 paid","pid":0}
  refreshOrders();
};
```

| Event | When |
|---|---|
| `listen` | once, when listening started: `{"channels":[...],"patterns":[...],"database":"..."}` |
| (message) | one per notification: `{"channel","payload","pid"}`; `pid` is 0 for a sender that is not a PostgreSQL connection; `"pattern"` too when it came through a pattern |
| `: ping` (a comment) | every 15 s, so a proxy keeps the stream open |
| `error` | the stream ends after it (see [limits](#limits)) |

- It needs a login, like [/exec](http-exec.md) (`Authorization: Bearer ...`, or the console's cookie). Up to 64 channels and patterns in one stream; the names are taken as written.
- `channel=` is Redis's `SUBSCRIBE`, `pattern=` its `PSUBSCRIBE`: a glob as `KEYS` takes it (`*` any text, `?` one character, `[abc]`, `\` before a special character). `/listen?pattern=price.*` gets `price.NABIL`, `price.HDL`, ... A message that matches a channel and a pattern of the same stream comes once for each.
- Over HTTP a channel may be up to 4096 bytes long (a [keyspace event](kv.md#kv-events) holds the whole key); `NOTIFY` keeps PostgreSQL's 63.
- `LISTEN` sent through `/exec` is refused with the way to do it: a request has no connection that stays open to be told.

<a id="limits"></a>

## Limits

- A listener that does not read keeps up to 32 MB of messages. Past that, it is **cut off**: the PostgreSQL connection ends with SQLSTATE `54000`, the HTTP stream with an `error` event. Nothing is lost quietly: connect again, `LISTEN` again, and read the table.
- At most 256 HTTP streams at once (`503` beyond).
- Messages of one sending connection arrive in commit order. Messages of two connections that commit at the same moment may arrive in either order.
