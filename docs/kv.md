# Key-value store (Redis-like)

> GET, SET, INCR, EXPIRE, DEL, KEYS, MGET and the other Redis string commands, hashes, sets, sorted sets, lists (with BLPOP), SORT and WATCH / MULTI / EXEC over HTTP (POST /kv, one command or a pipeline) and as SQL functions (kv_get, kv_set, kv_incr); PUBLISH / SUBSCRIBE and keyspace events. Keys are kept in memory and in the table _kv.

- Category: HTTP API
- Keywords: key-value, key value, kv, redis, POST /kv, /kv, GET, SET, SET NX, SET XX, SET EX, SETNX, SETEX, PSETEX, GETSET, GETDEL, GETEX, MGET, MSET, MSETNX, INCR, INCRBY, DECR, DECRBY, INCRBYFLOAT, counter, rate limit, APPEND, STRLEN, GETRANGE, SUBSTR, SETRANGE, LCS, DEL, UNLINK, EXISTS, TYPE, EXPIRE, PEXPIRE, EXPIREAT, PEXPIREAT, PERSIST, TTL, PTTL, EXPIRETIME, PEXPIRETIME, expiry, KEYS, SCAN, RANDOMKEY, DBSIZE, RENAME, RENAMENX, COPY, FLUSHDB, FLUSHALL, PING, ECHO, TIME, COMMAND, INFO, PUBLISH, SPUBLISH, PUBSUB, PUBSUB NUMSUB, PUBSUB CHANNELS, SUBSCRIBE, PSUBSCRIBE, pub/sub, keyspace events, notify-keyspace-events, CONFIG SET, CONFIG GET, __keyspace@0__, __keyevent@0__, expired event, KDB_NOTIFY_KEYSPACE_EVENTS, pipeline, kv_get, kv_set, kv_incr, kv_del, kv_expire, kv_ttl, kv(), _kv, sync, session store, cache, OTP, one-time code, CONFIG, maxmemory, maxmemory-policy, allkeys-lru, volatile-ttl, noeviction, appendonly, MEMORY USAGE, MEMORY STATS, kv_memory, eviction, LRU, hash, HSET, HGET, HGETALL, HINCRBY, HDEL, set, SADD, SMEMBERS, SINTER, SUNION, SDIFF, sorted set, ZADD, ZRANGE, ZRANK, ZINCRBY, ZPOPMIN, leaderboard, list, LPUSH, RPUSH, LPOP, LRANGE, LMOVE, queue, BLPOP, BRPOP, BLMOVE, BZPOPMIN, blocking pop, SORT, WATCH, MULTI, EXEC, UNWATCH, DISCARD, optimistic lock, session, _kv_items
- See also: [CREATE TABLE (row-ttl)](create-table.md#row-ttl), [CREATE TABLE (cache-table)](create-table.md#cache-table), [Run SQL over HTTP (/exec, /exp)](http-exec.md), [PostgreSQL protocol (port 8832)](postgres-protocol.md), [LISTEN and NOTIFY](listen-notify.md)

Every database has a **key-value store** that answers Redis's commands with Redis 7's answers: `GET`, `SET` (with `EX`, `NX`, `XX`, `GET`, `KEEPTTL`), `INCR`, `EXPIRE`, `TTL`, `DEL`, `KEYS`, `MGET`, `MSET` and more, and [hashes, sets, sorted sets and lists](#kv-collections). Use it for counters, rate limits, login sessions, one-time codes, caches, leaderboards and job queues.

| | How |
|---|---|
| Over HTTP | `POST /kv` with one command or a list of them ([below](#kv-http)) |
| From SQL and the PostgreSQL port | `SELECT kv_incr('hits')`, `kv_get('k')`, `kv_set('k', 'v', 60)` ([below](#kv-sql)) |
| Look at the keys | `SELECT * FROM _kv` ([the table](#kv-table)) |
| Publish and subscribe | `PUBLISH news hi`, and `GET /listen?channel=news` to hear it ([below](#kv-pubsub)) |

Why it is fast: the keys are kept **in memory**, so a command is a look-up, not a SQL statement with a plan and table locks. The changes of many clients go to the disk **together**: one commit and one disk sync confirm all the changes that arrived meanwhile.

<a id="kv-http"></a>

## POST /kv

Syntax:

```sql
POST /kv[?db=name][&sync=on|off]
```

The body is one command, or a list of commands (a **pipeline**: one round trip for all of them). Words are JSON strings; a number may be written as a number.

```js
// one command
await fetch('/kv', { method: 'POST', body: JSON.stringify(['INCR', 'visits']) });   // -> [1]
// a pipeline
await fetch('/kv', { method: 'POST', body: JSON.stringify([
  ['SET', 'otp:1', '123456', 'EX', 120],
  ['GET', 'otp:1'],
  ['TTL', 'otp:1'],
]) });                                                                             // -> ["OK","123456",120]
```

Plain text works too, one command per line, as you would type it in redis-cli (`"..."` keeps spaces in a word):

```js
await fetch('/kv', { method: 'POST', body: 'SET greeting "hello world"\nGET greeting' });  // -> ["OK","hello world"]
```

The answer is always a JSON **array with one reply per command**:

| Redis reply | JSON |
|---|---|
| a value, `OK`, `PONG` | a string: `"123456"`, `"OK"` |
| nil (no such key) | `null` |
| a number | a number: `8` |
| a list (`MGET`, `KEYS`, `SCAN`) | an array |
| an error of that command | `{"error": "ERR value is not an integer or out of range"}` |

A command that fails does not stop the ones after it, as in a Redis pipeline. A body that is not a command list gets `400`.

- **Rights:** a body that only reads needs role `read` on the database; a body with any command that changes keys needs role `write`.
- **Database:** `?db=name`, as for `/exec`. Each database has its own keys.

<a id="kv-sync"></a>

### When the answer comes: sync

| | The answer comes | After a crash or power cut |
|---|---|---|
| default (`appendfsync everysec`) | at once, before the disk sync; the disk follows within milliseconds | the last few milliseconds may be lost (Redis's same default loses up to a second) |
| `?sync=on`, or `CONFIG SET appendfsync always` | once the change is **on disk** | nothing confirmed is lost |
| `?sync=off` | at once, whatever `appendfsync` says | as the default |

- `CONFIG SET appendfsync always` makes every request wait for the disk (each waiting request holds one HTTP thread until its sync, so many writing clients need more HTTP threads: `kdb serve --http-threads`). It is saved as the `_kv` table's `synchronous_commit = on` ([durability per table](performance-tips.md#table-sync-commit)) and survives a restart. `everysec` or `no` goes back to the default.
- Before 2026-10-03 the default waited for the disk; send `?sync=on` (or set `appendfsync always`) to keep that.

<a id="kv-commands"></a>

## The commands

| Command | Answers |
|---|---|
| `GET key` | the value, or `null` |
| `SET key value [NX \| XX] [GET] [EX s \| PX ms \| EXAT unix-s \| PXAT unix-ms \| KEEPTTL]` | `"OK"`; `null` when `NX`/`XX` did not let it set; with `GET` the old value |
| `SETNX key value` | `1` set, `0` the key exists |
| `SETEX key seconds value`, `PSETEX key ms value` | `"OK"` |
| `GETSET key value`, `GETDEL key` | the old value |
| `GETEX key [EX s \| PX ms \| EXAT \| PXAT \| PERSIST]` | the value; sets or removes its expiry |
| `MGET key ...` | a list of values (`null` for missing keys) |
| `MSET key value ...`, `MSETNX key value ...` | `"OK"`; `MSETNX`: `1`, or `0` (nothing set) when any key exists |
| `INCR`, `DECR`, `INCRBY key n`, `DECRBY key n` | the new number; a missing key counts as 0; the key keeps its expiry |
| `INCRBYFLOAT key x` | the new number as text: `"8.5"` |
| `APPEND key text`, `SETRANGE key offset text` | the new length |
| `STRLEN key`, `GETRANGE key start end` (`SUBSTR`) | length; part of the value (offsets in bytes, `-1` = the last) |
| `LCS key1 key2 [LEN]` | the longest common subsequence (or its length) |
| `DEL key ...`, `UNLINK key ...` | how many keys were deleted |
| `EXISTS key ...`, `TYPE key` | how many exist; `"string"`, `"hash"`, `"set"`, `"zset"`, `"list"` or `"none"` |
| `EXPIRE key s [NX \| XX \| GT \| LT]`, `PEXPIRE`, `EXPIREAT`, `PEXPIREAT` | `1` set, `0` not (no key, or the condition said no) |
| `PERSIST key` | `1` when an expiry was removed |
| `TTL key`, `PTTL key` | seconds (ms) left; `-1` no expiry; `-2` no key |
| `EXPIRETIME key`, `PEXPIRETIME key` | when it expires (Unix seconds / ms); `-1`, `-2` as above |
| `KEYS pattern` | the matching keys, **sorted** (`*` any text, `?` one character, `[abc]`, `[^a]`, `[a-z]`, `\` before a special character) |
| `SCAN cursor [MATCH pattern] [COUNT n]` | `[next cursor, [keys]]`; start at `"0"`, stop when the cursor is `"0"` again; a key may come twice, but none is missed |
| `RANDOMKEY`, `DBSIZE` | a key (or `null`); the number of keys |
| `RENAME key new`, `RENAMENX key new`, `COPY src dst [REPLACE]` | `"OK"` / `1` / `0`; the value keeps its expiry |
| `FLUSHDB`, `FLUSHALL` | `"OK"`: every key of **this database** is gone |
| `PING [text]`, `ECHO text`, `TIME` | `"PONG"`; the text; `[seconds, microseconds]` |
| `COMMAND [COUNT \| LIST \| DOCS name ...]`, `INFO` | the commands this server knows; counters of the store (keys, memory, writes) |
| `CONFIG GET pattern`, `CONFIG SET name value ...` | the memory cap and its policy ([below](#kv-memory)) |
| `MEMORY USAGE key`, `MEMORY STATS`, `MEMORY DOCTOR` | the bytes a key takes; the store's memory counters |

- **Expiry:** a key whose time has come is gone at once for every command and for `SELECT`. A `SET` without `KEEPTTL` removes the old expiry, as in Redis.
- **Errors** read as Redis's: `ERR wrong number of arguments for 'get' command`, `ERR syntax error`, `ERR value is not an integer or out of range`, `ERR no such key`.
- **Not here (yet):** streams (`XADD` ...), `SELECT n` (use `?db=`), Lua scripts, `CLIENT TRACKING`, `DUMP`/`RESTORE`.

<a id="kv-pubsub"></a>

## Publish and subscribe

Redis's `PUBLISH` sends a message to every client that listens on a channel. Here it is the same channel as [NOTIFY](listen-notify.md): a `PUBLISH` reaches `LISTEN` on the PostgreSQL port and `GET /listen` streams, and a `NOTIFY` reaches a pattern subscriber.

| Command | Answers |
|---|---|
| `PUBLISH channel message` | how many listeners got it (`0` when nobody listens) |
| `SPUBLISH channel message` | the same (one server has one shard) |
| `PUBSUB CHANNELS [pattern]` | the channels someone listens on now |
| `PUBSUB NUMSUB channel ...` | `[channel, count, ...]`; pattern subscribers are not counted, as in Redis |
| `PUBSUB NUMPAT` | how many different patterns are subscribed |
| `PUBSUB SHARDCHANNELS`, `SHARDNUMSUB` | the same as `CHANNELS`, `NUMSUB` |

To subscribe, open a stream that stays open: a request and its answer cannot carry later messages, so `SUBSCRIBE` in `/kv` answers an error that says where to go.

| Redis | KDB |
|---|---|
| `SUBSCRIBE news` | `GET /listen?channel=news` ([server-sent events](listen-notify.md#listen-http)), or `LISTEN news` on the PostgreSQL port |
| `PSUBSCRIBE price.*` | `GET /listen?pattern=price.*`: each message also says which `"pattern"` it matched |

```js
// client 1: listen
const es = new EventSource('/listen?channel=news&pattern=price.*');
es.onmessage = (e) => console.log(JSON.parse(e.data));
// client 2: publish
await fetch('/kv', { method: 'POST', body: JSON.stringify([['PUBLISH', 'news', 'hi']]) });         // -> [1]
// client 1 gets {"channel":"news","payload":"hi","pid":0}
await fetch('/kv', { method: 'POST', body: 'PUBLISH price.NABIL 512' });                          // -> [1]
// client 1 gets {"channel":"price.NABIL","payload":"512","pid":0,"pattern":"price.*"}
```

**Example: Publish from SQL**

```sql
SELECT kv('PUBLISH', 'news', 'market opens at 11') AS listeners,
       kv('PUBSUB', 'NUMSUB', 'news') AS numsub;
```

Result:

| listeners (LONG) | numsub (STRING) |
|---|---|
| 0 | ["news",0] |

(1 row)

- **At once:** `PUBLISH` sends when it runs, as in Redis. `NOTIFY` waits for its transaction to commit. Neither is stored: a listener that connects later does not get earlier messages.
- **Rights:** `PUBLISH` needs role `write` on the database (it reaches other clients); `PUBSUB` and listening need `read`. Channels belong to one database (`?db=`).
- **Limits:** a channel of up to 4096 bytes, a message of up to 1 MB. A listener that does not read is cut off rather than losing messages quietly ([limits](listen-notify.md#limits)).

<a id="kv-events"></a>

### Keyspace events

With keyspace events on, every key change is published too, on Redis's channels:

| Channel | Payload |
|---|---|
| `__keyspace@0__:<key>` (letter `K`) | the event: `set`, `del`, `expire`, `expired`, ... |
| `__keyevent@0__:<event>` (letter `E`) | the key |

`@0` is Redis's first database, so a Redis client's subscription works unchanged; the channels still belong to one KDB database.

Turn them on with Redis's letters, as a server admin:

```js
await fetch('/kv', { method: 'POST', body: 'CONFIG SET notify-keyspace-events Ex' });   // expired keys, keyevent channel
const es = new EventSource('/listen?channel=__keyevent@0__:expired');                  // payload: the key that expired
```

| Letter | Events |
|---|---|
| `K`, `E` | which channels: keyspace, keyevent (at least one is needed) |
| `g` | `del`, `expire`, `persist`, `rename_from`, `rename_to`, `copy_to` |
| `$` | `set`, `incr`, `decr`, `incrby`, `decrby`, `incrbyfloat`, `append`, `setrange` |
| `x` | `expired`: the key's time came; sent within about 10 ms of it, whether or not anybody reads the key |
| `e` | `evicted`: a key taken by the [memory cap](#kv-memory) |
| `n` | `new`: a key that did not exist was made |
| `l`, `s`, `h`, `z` | list, set, hash and sorted set events, with Redis's names: `lpush`, `rpop`, `sadd`, `srem`, `hset`, `hdel`, `zadd`, `zincr`, ... |
| `A` | every class above but `n` (Redis's `g$lshzxetd`) |
| `t`, `d`, `m` | taken, as Redis takes them; nothing here sends them yet |

**Example: Read the setting**

```sql
SELECT kv('CONFIG', 'GET', 'notify-keyspace-events');
```

Result:

| kv('CONFIG', 'GET', 'notify-keyspace-events') (STRING) |
|---|
| ["notify-keyspace-events",""] |

(1 row)

**Example: Only an admin over HTTP may change it** (shows an error)

```sql
SELECT kv('CONFIG', 'SET', 'notify-keyspace-events', 'KEA');
```

Result:

Error: `line 1, column 8: kv: NOPERM CONFIG SET notify-keyspace-events changes the whole server: it needs a server admin`

- The setting is for the **whole server**, as in Redis, and is off by default. `CONFIG SET` lasts until a restart; set `KDB_NOTIFY_KEYSPACE_EVENTS=Ex` in the environment to have it from the start. `CONFIG SET notify-keyspace-events ""` turns it off.
- While nobody listens anywhere, a key change does not build any event: the setting costs nothing until it is used.
- `FLUSHDB` sends no event per key, as in Redis.

<a id="kv-memory"></a>

## A memory cap: CONFIG SET maxmemory

The store can be a cache with a size limit, as Redis with `maxmemory`:

```js
await fetch('/kv', { method: 'POST', body: JSON.stringify([
  ['CONFIG', 'SET', 'maxmemory', '64mb', 'maxmemory-policy', 'allkeys-lru'],
]) });                                                       // -> ["OK"]
```

| Setting | Values |
|---|---|
| `maxmemory` | the cap: `64mb`, `512kb`, `1gb` or bytes; `0` = no cap (the default) |
| `maxmemory-policy` | `noeviction` (the default), `allkeys-lru`, `volatile-lru`, `allkeys-random`, `volatile-random`, `volatile-ttl` |
| `appendonly` | `yes` (the default): keys are written to `_kv` and survive a restart. `no`: memory only, a restart starts empty |
| `appendfsync` | `everysec` (the default): an answer comes before the disk sync. `always`: it waits for it. `no`: as `everysec` ([sync](#kv-sync)) |

- Over the cap, a command that adds data first evicts keys by the policy, **at once**: the cap holds after every command. `allkeys-lru` takes the keys used longest ago (the oldest of 16 random keys, as Redis does), `volatile-ttl` the key that expires soonest, the `volatile-` ones only keys with an expiry.
- With `noeviction` (or nothing left that the policy may take), such a command fails with Redis's error `OOM command not allowed when used memory > 'maxmemory'.` `DEL`, `EXPIRE` and `FLUSHDB` still work.
- A key counts its own bytes, its value's bytes and 64 bytes: `MEMORY USAGE key` answers that, `SELECT kv_memory()` the whole store, `INFO` shows `used_memory`, `maxmemory` and `evicted_keys`.
- The settings are kept with the table `_kv` (its options `max_bytes`, `evict`, `durability`, as a [cache table](create-table.md#cache-table) has), so they survive a restart. `CONFIG SET` needs role `write` (`notify-keyspace-events`, a [server setting](#kv-events), a server admin); `CONFIG GET` only `read`.

**Example: A store of 1 MB that forgets the oldest keys**

```sql
SELECT kv('CONFIG', 'SET', 'maxmemory', '1mb', 'maxmemory-policy', 'allkeys-lru');
SELECT kv_set('session:1', 'sita'), kv('MEMORY', 'USAGE', 'session:1'), kv_memory();
SELECT kv('CONFIG', 'GET', 'maxmemory*');
SELECT kv('CONFIG', 'SET', 'maxmemory', '0', 'maxmemory-policy', 'noeviction');
```

Result:

`SELECT kv('CONFIG', 'SET', 'maxmemory', '1mb', 'maxmemory-policy', 'allkeys-lru')`

| kv('CONFIG', 'SET', 'maxmemory', '1mb', 'maxmemory-policy', 'allkeys-lru') (STRING) |
|---|
| OK |

(1 row)

`SELECT kv_set('session:1', 'sita'), kv('MEMORY', 'USAGE', 'session:1'), kv_memory()`

| kv_set('session:1', 'sita') (STRING) | kv('MEMORY', 'USAGE', 'session:1') (LONG) | kv_memory() (LONG) |
|---|---|---|
| OK | 77 | 77 |

(1 row)

`SELECT kv('CONFIG', 'GET', 'maxmemory*')`

| kv('CONFIG', 'GET', 'maxmemory*') (STRING) |
|---|
| ["maxmemory","1048576","maxmemory-policy","allkeys-lru","maxmemory-samples","16"] |

(1 row)

`SELECT kv('CONFIG', 'SET', 'maxmemory', '0', 'maxmemory-policy', 'noeviction')`

| kv('CONFIG', 'SET', 'maxmemory', '0', 'maxmemory-policy', 'noeviction') (STRING) |
|---|
| OK |

(1 row)

<a id="kv-collections"></a>

## Hashes, sets, sorted sets and lists

A key can hold more than one text. The commands and answers are Redis 7's; `COMMAND DOCS HSET` shows the syntax of each one.

| Type | Commands | Use it for |
|---|---|---|
| hash | `HSET`, `HGET`, `HMGET`, `HGETALL`, `HDEL`, `HEXISTS`, `HLEN`, `HKEYS`, `HVALS`, `HINCRBY`, `HINCRBYFLOAT`, `HSETNX`, `HSTRLEN`, `HRANDFIELD`, `HSCAN` | a record: a user, a cart, the fields of one session |
| set | `SADD`, `SREM`, `SMEMBERS`, `SISMEMBER`, `SMISMEMBER`, `SCARD`, `SINTER`, `SUNION`, `SDIFF` (and `...STORE`), `SINTERCARD`, `SMOVE`, `SPOP`, `SRANDMEMBER`, `SSCAN` | tags, who is online, unique visitors |
| sorted set | `ZADD`, `ZINCRBY`, `ZREM`, `ZSCORE`, `ZMSCORE`, `ZCARD`, `ZCOUNT`, `ZRANK`, `ZREVRANK`, `ZRANGE` (`BYSCORE`, `BYLEX`, `REV`, `LIMIT`, `WITHSCORES`), `ZRANGEBYSCORE`, `ZPOPMIN`, `ZPOPMAX`, `ZUNION`, `ZINTER`, `ZDIFF` (and `...STORE`), `ZREMRANGEBY...`, `ZRANDMEMBER`, `ZSCAN` | leaderboards, things due at a time (score = Unix time) |
| list | `LPUSH`, `RPUSH`, `LPOP`, `RPOP`, `LLEN`, `LRANGE`, `LINDEX`, `LSET`, `LINSERT`, `LREM`, `LPOS`, `LTRIM`, `LMOVE`, `LMPOP`, `RPOPLPUSH` | queues, the last n events |
| any of them | `SORT key [BY pattern] [LIMIT o n] [GET pattern ...] [ASC \| DESC] [ALPHA] [STORE dst]`, `SORT_RO` | the values sorted, or values of other keys they point to |

```js
await fetch('/kv', { method: 'POST', body: JSON.stringify([
  ['HSET', 'user:1', 'name', 'a', 'age', '3'],
  ['HINCRBY', 'user:1', 'age', '2'],
  ['HGETALL', 'user:1'],
  ['ZADD', 'board', 10, 'a', 20, 'b'],
  ['ZRANGE', 'board', 0, -1, 'WITHSCORES'],
]) });                                   // -> [2, 5, {"name":"a","age":"5"}, 2, ["a","10","b","20"]]
```

**Example: A hash and a leaderboard from SQL**

```sql
SELECT kv('HSET', 'user:1', 'name', 'Sita', 'age', '30'), kv('HINCRBY', 'user:1', 'age', '1'), kv('HGETALL', 'user:1');
SELECT kv('ZADD', 'board', '10', 'ram', '25', 'sita'), kv('ZRANGE', 'board', '0', '-1', 'REV', 'WITHSCORES');
```

Result:

`SELECT kv('HSET', 'user:1', 'name', 'Sita', 'age', '30'), kv('HINCRBY', 'user:1', 'age', '1'), kv('H`

| kv('HSET', 'user:1', 'name', 'Sita', 'age', '30') (LONG) | kv('HINCRBY', 'user:1', 'age', '1') (LONG) | kv('HGETALL', 'user:1') (STRING) |
|---|---|---|
| 2 | 31 | {"name":"Sita","age":"31"} |

(1 row)

`SELECT kv('ZADD', 'board', '10', 'ram', '25', 'sita'), kv('ZRANGE', 'board', '0', '-1', 'REV', 'WITH`

| kv('ZADD', 'board', '10', 'ram', '25', 'sita') (LONG) | kv('ZRANGE', 'board', '0', '-1', 'REV', 'WITHSCORES') (STRING) |
|---|---|
| 2 | ["sita","25","ram","10"] |

(1 row)

- `HGETALL` answers a JSON **object**; scores are texts (`"10"`, `"1.5"`), and `WITHSCORES` lists are flat: `[member, score, ...]`.
- `SMEMBERS`, `SINTER`, `SUNION` and `SDIFF` answer the members **sorted**, so the answer is the same every time (Redis's order changes).
- A command on a key of another type answers `WRONGTYPE Operation against a key holding the wrong kind of value`; so does `GET` of a hash.
- A hash, set or list that becomes empty is deleted, as in Redis. `EXPIRE`, `TTL`, `DEL`, `RENAME`, `COPY` and `TYPE` work on every type.
- They count toward the [memory cap](#kv-memory) like strings, and eviction may take a whole hash, set or list.

<a id="kv-blocking"></a>

### Waiting for a value: BLPOP

`BLPOP key [key ...] timeout` takes the first value of the first list that has one. When all are empty it **waits** until another client pushes, up to `timeout` seconds (`0.5` works; `0` = no limit), then answers `null`. `BRPOP`, `BLMOVE`, `BRPOPLPUSH`, `BLMPOP`, `BZPOPMIN`, `BZPOPMAX` and `BZMPOP` wait the same way.

```js
// a worker: waits up to 5 s for a job
const [job] = await (await fetch('/kv', { method: 'POST', body: JSON.stringify(['BLPOP', 'jobs', 5]) })).json();
// -> ["jobs", "job-17"] as soon as someone runs ['RPUSH', 'jobs', 'job-17'], or null after 5 s
```

- The wait holds one HTTP thread: many waiting workers need more threads (`kdb serve --http-threads`).
- From SQL (`kv('BLPOP', ...)`) a blocking pop never waits: it answers at once, so a statement cannot hang.

<a id="kv-watch"></a>

### WATCH, MULTI and EXEC

`MULTI` queues the commands after it and `EXEC` runs them together: no other client's command comes in between. `WATCH key ...` before `MULTI` makes `EXEC` answer `null` (and run nothing) when another client changed one of those keys meanwhile, so you read again and retry: an **optimistic lock**.

A Redis connection keeps its `WATCH` from one command to the next. Over HTTP, give your requests a **session** name: `POST /kv?session=name`. Requests with the same name (from the same user) share their `WATCH` and `MULTI`; a session ends 10 minutes after its last request. Without `session`, they last for that one request.

```js
// request 1: read the stock and watch it
POST /kv?session=order-7   [["WATCH","stock"],["GET","stock"]]            // -> ["OK","5"]
// request 2: write it only if nobody changed it since
POST /kv?session=order-7   [["MULTI"],["SET","stock","4"],["EXEC"]]       // -> ["OK","QUEUED",["OK"]], or [..., null] to retry
```

- A command refused while queued (unknown, wrong number of words, no right to write) makes `EXEC` answer `EXECABORT` and run nothing, as in Redis.
- `UNWATCH` forgets the watched keys; `DISCARD` drops the queue.

<a id="kv-sql"></a>

## From SQL: kv_get, kv_set, kv_incr

Syntax:

```sql
kv_get(key)                     -- GET
kv_set(key, value [, seconds])  -- SET key value [EX seconds]
kv_incr(key [, n])              -- INCRBY key n (1 when left out)
kv_del(key)                     -- DEL
kv_expire(key, seconds)         -- EXPIRE
kv_ttl(key)                     -- TTL
kv(command, word, ...)          -- any command: kv('MGET', 'a', 'b')
```

The same store, from any SQL client and the PostgreSQL port. A list answer (`MGET`, `KEYS`, `LRANGE`) comes as JSON text, and `HGETALL` as a JSON object. A NULL word gives NULL and changes nothing.

**Example: A counter and a code that expires**

```sql
SELECT kv_incr('page:home');
SELECT kv_incr('page:home', 10);
SELECT kv_set('otp:42', '815204', 120), kv_get('otp:42'), kv_ttl('otp:42');
SELECT kv('MGET', 'page:home', 'otp:42', 'nothing');
```

Result:

`SELECT kv_incr('page:home')`

| kv_incr('page:home') (LONG) |
|---|
| 1 |

(1 row)

`SELECT kv_incr('page:home', 10)`

| kv_incr('page:home', 10) (LONG) |
|---|
| 11 |

(1 row)

`SELECT kv_set('otp:42', '815204', 120), kv_get('otp:42'), kv_ttl('otp:42')`

| kv_set('otp:42', '815204', 120) (STRING) | kv_get('otp:42') (STRING) | kv_ttl('otp:42') (LONG) |
|---|---|---|
| OK | 815204 | 120 |

(1 row)

`SELECT kv('MGET', 'page:home', 'otp:42', 'nothing')`

| kv('MGET', 'page:home', 'otp:42', 'nothing') (STRING) |
|---|
| ["11","815204",null] |

(1 row)

**Example: A counter needs a number** (shows an error)

```sql
SELECT kv_set('name', 'sita'), kv_incr('name');
```

Result:

Error: `line 1, column 32: kv_incr: ERR value is not an integer or out of range`

- **Rights:** `kv_get`, `kv_ttl` and reading commands need role `read`; the others need role `write`, and so does `kv()` when its command is not written out as text (as in `kv(col, 'k')`). A read-only transaction (`BEGIN READ ONLY`) refuses them.
- **On disk:** the client's statement returns once its changes are on disk. Inside an open `BEGIN ... COMMIT` (and with `SET synchronous_commit = off`) it does not wait; the change is written within milliseconds. A key change is **not** part of the transaction: a `ROLLBACK` does not take it back.

<a id="kv-table"></a>

## The table _kv

The keys live in the table `_kv` of the database, made at the first change:

| Column | Type | |
|---|---|---|
| `k` | `STRING PRIMARY KEY` | the key |
| `v` | `STRING` | the value |
| `expires_at` | `TIMESTAMP` | when it expires; `NULL` = never ([row TTL](create-table.md#row-ttl)) |

- `SELECT` reads it like any table: `SELECT k, v FROM _kv WHERE k LIKE 'session:%'`. Expired keys are not in it.
- Only the store changes it: `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `DROP` and `ALTER` of `_kv` are refused (`42501`). Empty it with `FLUSHDB`. [TRUNCATE ALL TABLES](databases.md#truncate-all-tables) empties the store too.
- It is in the log and in backups like any table, and the keys are back after a restart: the store reads `_kv` into memory when the database opens.
- **Memory:** every key and value is held in memory while the database is open, as in Redis. Keep big documents in tables, or set a [cap](#kv-memory).

Hashes, sets, sorted sets and lists are in a second table, `_kv_items`, made when the first one is: one row with the key's type (`t`) and expiry, and **one row per field, member or list item** (`f`, `v`). So `HSET` of one field writes one row, however big the hash is.

```sql
SELECT k, t, f, v FROM _kv_items WHERE k = 'user:1';
-- user:1 | hash | NULL | NULL
-- user:1 | NULL | age  | 31
-- user:1 | NULL | name | Sita
```

Only the store changes `_kv_items` too.
