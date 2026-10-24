# Cluster: automatic failover (--cluster-peers, kareladb witness)

> Two or three KarelaDB servers and a witness elect a leader; when the leader's computer dies, another takes over by itself in about 5 to 10 seconds.

- Category: Backup, check, repair, restore
- Keywords: cluster, failover, automatic failover, high availability, ha, leader, follower, election, raft, term, witness, kareladb witness, quorum, majority, lease, fencing, split brain, --cluster-peers, --node-id, --cluster-token, KARELADB\_CLUSTER\_PEERS, KARELADB\_NODE\_ID, KARELADB\_CLUSTER\_TOKEN, KARELADB\_ELECTION\_TIMEOUT\_MS, KARELADB\_LEASE\_MS, KARELADB\_CLUSTER\_HEARTBEAT\_MS, GET /api/cluster, api/cluster, 421, 25006, 08007, \_diverged, kareladb cluster diverged, DELETE /api/cluster/diverged, copy id
- See also: [Standby server: a live read-only copy (--standby-of, kareladb promote)](standby.md), [Backup, check, repair and restore](backup-and-safety.md), [kareladb serve](cli-serve.md)

A **cluster** is three voters that choose one **leader** among them. The leader is a primary: it takes every change. The other data nodes are its [standbys](standby.md): they copy its log and serve reads. When the leader's computer dies, the others notice within about 5 seconds and elect a new leader, which takes changes from then on. Nobody has to run `kareladb promote`.

Two leaders never both write: a leader that loses touch with the others stops taking changes **before** anyone else can be elected (see [Fencing](#fencing)).

<a id="shape"></a>

## The shape

| Layout | Computers | Good | Not so good |
|---|---|---|---|
| 2 data nodes + 1 witness | 2 big, 1 tiny | cheap: the witness holds no data, only votes (a few MB of memory) | after one data node dies there is one copy until it is back |
| 3 data nodes | 3 big | still two copies after one dies | 3 times the disk and memory |

Two voters alone are not safe: when they lose contact, neither can tell "the other is dead" from "the cable is cut". A third voter breaks the tie, so `--cluster-peers` needs at least 3.

<a id="start"></a>

## Start a cluster

Every node gets the same list of voters, each as `id=http://host:port`, and its own `--node-id`:

```bash
PEERS=a=http://10.0.0.1:9900,b=http://10.0.0.2:9900,w=http://10.0.0.3:9900

# data node a
kareladb serve --data-dir /data --bind 0.0.0.0 --token <secret> --node-id a --cluster-peers $PEERS
# data node b
kareladb serve --data-dir /data --bind 0.0.0.0 --token <secret> --node-id b --cluster-peers $PEERS
# the witness (no data)
kareladb witness --data-dir /witness --bind 0.0.0.0 --port 9900 --token <secret> --node-id w --cluster-peers $PEERS
```

| Setting | Meaning |
|---|---|
| `--cluster-peers LIST` (`KARELADB_CLUSTER_PEERS`) | every voter, this one too: `id=http://host:port`, comma-separated. An entry without `id=` uses `host:port` as its id |
| `--node-id ID` (`KARELADB_NODE_ID`) | this node's id in the list |
| `--cluster-token T` (`KARELADB_CLUSTER_TOKEN`) | what the nodes send each other. Default: `--token`. Every node must accept it as an admin's token, because followers read the leader's log with it |
| `KARELADB_ELECTION_TIMEOUT_MS` | how long a node waits without hearing the leader before it asks to be elected (default 5000, random +-20%) |
| `KARELADB_LEASE_MS` | how long a leader may write after a majority last answered it (default 3000) |
| `KARELADB_CLUSTER_HEARTBEAT_MS` | how often the leader says "I am here" (default 500) |
| `KARELADB_SYNC_STANDBYS` | `1` or `prefer` (default): a commit is confirmed once a standby holds it too, or by the leader alone while no standby copies; `required`: never by the leader alone; `0`: the leader alone ([sync commit](#sync)) |
| `KARELADB_SYNC_WAIT_MS` | with `required`: how long a written commit waits for a standby before it fails (default 10000) |
| `KARELADB_ON_LEADER`, `KARELADB_ON_FOLLOWER` | a command run on each role change ([clients](#clients)) |
| `KARELADB_ROLE_SCRIPT_TIMEOUT_MS` | `30000` (default): a role script that runs longer is killed and logged |

The lease plus one heartbeat must end before the shortest election timeout (3000 + 500 < 4000 with the defaults). A node refuses to start otherwise, because then two leaders could write at once. Give every node the same three settings: each message carries the sender's lease and shortest timeout, and a node refuses votes and heartbeats from a node whose settings do not fit beside its own (its log says why).

A node starts as a follower that copies nothing. Within the election timeout one data node is elected; it says so in its log (`cluster: this node is the leader in term 1`), and the others start copying it.

A list of two voters is refused, because two nodes alone cannot fail over safely:

**Command line: Two voters are not enough**

```bash
kareladb serve --data-dir data --token T --node-id a --cluster-peers a=http://10.0.0.1:9900,b=http://10.0.0.2:9900
```

Output:

```text
error: --cluster-peers needs at least 3 voters (two data nodes and a witness, or three data nodes): two alone cannot tell a dead node from a cut cable
```

exit code 1

A witness needs the same list of voters as the data nodes:

**Command line: A witness without --cluster-peers**

```bash
kareladb witness --data-dir witness --node-id w --token T
```

Output:

```text
error: kareladb witness needs --cluster-peers (every voter, this one too; env KARELADB_CLUSTER_PEERS)
```

exit code 1

<a id="connect"></a>

## Connection strings

Give clients **both data nodes** (not the witness: it holds no data). The driver tries them in order and keeps the one that takes writes.

| Client | Connection string |
|---|---|
| psql, libpq, Python psycopg | `postgresql://user:pass@10.0.0.1:8832,10.0.0.2:8832/default?target_session_attrs=read-write` |
| Go pgx | `postgres://user:pass@10.0.0.1:8832,10.0.0.2:8832/default?target_session_attrs=read-write` |
| Java JDBC | `jdbc:postgresql://10.0.0.1:8832,10.0.0.2:8832/default?targetServerType=primary` |
| Node `pg` | one host per pool; on error `25006` or a closed connection, connect to the other node |
| HTTP (`/exec`, `/write`) | send to either node; a follower answers `421` with `X-KarelaDB-Leader: <url>`: send it again there |
| A load balancer | health check `GET /health?role=leader` (writes) or `?role=follower` (reads) |
| Reads only | `target_session_attrs=any` (or `prefer-standby`): any node answers reads. A follower says true to `pg_is_in_recovery()` and on to `in_hot_standby` and `transaction_read_only`, as a PostgreSQL standby does, so every driver tells it from the leader |

After a failover the driver's open connections to the old leader break. A
connection pool opens new ones and finds the new leader by itself; a client
that keeps one connection should connect again on error and send the write
again only if it was not confirmed (see [what a commit does](#sync)).

Any server answers `/health` without a token. A plain server (no cluster) says it leads:

**HTTP: The role check a load balancer uses**

```http
GET /health?role=leader
```

Response:

HTTP 200 (application/json)

```text
{
  "status": "ok",
  "version": "0.2.0-dev",
  "product": "KarelaDB",
  "server_time_ms": 1792822728141,
  "auth_required": false,
  "login": false,
  "tls": false,
  "ready": true,
  "standby": false,
  "role": "leader"
}
```

**HTTP: Asked for a follower, the leader answers 503**

```http
GET /health?role=follower
```

Response:

HTTP 503 (application/json)

```text
{
  "status": "ok",
  "version": "0.2.0-dev",
  "product": "KarelaDB",
  "server_time_ms": 1792822728177,
  "auth_required": false,
  "login": false,
  "tls": false,
  "ready": true,
  "standby": false,
  "role": "leader"
}
```

<a id="election"></a>

## How the leader is chosen

| Step | What happens |
|---|---|
| 1 | The leader sends a heartbeat to every other voter every 500 ms (`POST /api/cluster/heartbeat`, on the same port). |
| 2 | A node that hears nothing for its election timeout first asks the others whether they **would** vote for it. A voter that heard a leader, or gave a vote, less than 4 s ago says no, to this question and to a real vote. So a node that was only cut off cannot disturb a working cluster when it comes back, and no second leader is elected while the first may still write. |
| 3 | If a majority would, it adds 1 to the **term** (an election counter), votes for itself and asks for real votes (`POST /api/cluster/vote`). |
| 4 | A voter gives one vote per term, and only to a candidate whose log is at least as far as its own **for every database**, and as far as what the leader last said a majority holds. The witness keeps that list. A log's end is the term of the leader that wrote its last entry, then its LSN: a newer term wins over a longer log from an older term. So the most up-to-date node wins. Before both comes the database's **copy id**, which making of the database the log belongs to: a database dropped and made again (even within one term) starts its LSNs again from 1, and a node that only holds the dropped one never wins over a node holding the new one, however long its old log is. |
| 5 | With a majority (2 of 3) the candidate is the leader. Every database becomes a primary's, in place, and its log goes on in a new history named by the term. Timers start. |
| 6 | The other data node becomes its follower and copies its log. |

The term, the vote and the last leader are in `<data>/_cluster/state`. A node writes and syncs this file **before** it answers a vote, so it never votes twice in one term, even across a crash. If the file is damaged, the node refuses to start rather than guess.

A node that replays a long log after a crash still votes: nothing is applied to a database while it opens, so the end its open's log check read (before the replay starts) is its log end, and the node answers votes with it. Only until that check has read the log does it say `this voter's own log ends are still being read`.

<a id="fencing"></a>

## Fencing: two leaders never write

| Layer | How |
|---|---|
| Lease | The leader may write only while a majority answered a heartbeat it sent in the last 3 s (a steady clock, not the time of day). When the lease runs out, every database refuses commits at once, with SQLSTATE `25006`, and the node steps down. Others can be elected only after 4 s without a heartbeat, which is after the lease ended. |
| Term on every log request | A follower sends its term with each request for the log (`GET /api/wal?term=`). A leader that sees a higher term steps down at once and answers `421`. A follower never applies a log from an older term. |

A follower that was the leader before (it lost its lease, or the cluster moved on while it was away) becomes a follower in place: its databases turn into copies again and it copies from the new leader. Nothing has to be copied by hand, even when its log no longer fits the new leader's (next section).

<a id="rejoin"></a>

## When the old leader comes back

A leader that was cut off, or whose computer stopped, may have logged commits the new leader never got. In async mode some of them may have been confirmed to a client. When it comes back, it takes the new leader's history by itself, database by database:

| Its copy | What it does |
|---|---|
| Fits the new leader's log | copies on from where it is. |
| Has commits after the point where the two logs part (the fork) | cuts its log back to the fork and copies on from there. Its data files are linked, not copied, so this takes a moment even for a big database. |
| Its files no longer hold the data as it was at the fork (a checkpoint ran after it), or the new leader no longer keeps the log it needs | copies the database again: `GET /api/snapshot?db=` on the leader sends a consistent copy while writes go on there; the node checks every file, restores it and follows from its end. |

The fork is found from the log terms of both nodes (which leader wrote which part of the log) and checked with the commit at the fork and the database's copy id, so a database made again under the same name is never taken for the same one: it is copied again, and the old copy is kept whole in `_diverged`.

Nothing is deleted. When the old copy held commits the leader never got, its whole folder (its log too) moves to `<data>/_diverged/<database>-<time>`, with:

| File | What it holds |
|---|---|
| `diverged.txt` | the database, the fork LSN, how many commits only this node had, and when it moved |
| `diverged.kdbwal` | those commits, in the form `GET /api/wal` sends |
| the rest | the database as this node held it: open it with `kareladb sql --data-dir` to look at the rows |

Look at them, and delete one when you no longer need it, with the node running or stopped:

```bash
kareladb cluster diverged list --data-dir /data
# folder                                   database                 fork_lsn      end_lsn     txns  how          moved
# default-20261023-021530                  default                     98012        98140      128  cut back     2026-10-23 02:15:30
kareladb cluster diverged drop default-20261023-021530 --data-dir /data
# deleted /data/_diverged/default-20261023-021530
```

On a running node the same is `DELETE /api/cluster/diverged?folder=<folder>` with the cluster token (`404` when `_diverged` holds no such folder; a path is refused). KarelaDB never deletes a `_diverged` folder by itself.

A copy that only fell behind (nothing of its own, and the leader confirmed the last transaction they share) goes to `<data>/_trash` instead, as a dropped database does. When the leader cannot confirm it (it no longer keeps that part of its log), the whole old copy is kept in `_diverged`. A rejoin that fails (no disk space for the leader's snapshot, the leader busy sending one) is tried again after 5 seconds, then twice as long each time, up to 10 minutes. `GET /api/cluster` lists every `_diverged` folder under `diverged`.

A power cut at any step leaves a usable node: the old folder stays in place until the new copy is complete, and a swap that was under way is finished at the next start. The users database (`_system`) is not copied again while the server runs: if it went apart, `GET /api/standby` says so; stop the node, move `<data>/_system` away and start it again.

<a id="status"></a>

## Watch it

`GET /api/cluster` (with the cluster token) on any node:

```json
{"node":"a","witness":false,"role":"leader","term":3,"leader":"a","leader_url":"http://10.0.0.1:9900",
 "voted_for":"a","lease_left_ms":2950,
 "peers":[{"id":"b","url":"http://10.0.0.2:9900","reachable":true,"last_answer_ms_ago":40,"error":null},
          {"id":"w","url":"http://10.0.0.3:9900","reachable":true,"last_answer_ms_ago":41,"error":null}],
 "log_ends":{"_system":{"term":3,"lsn":120},"default":{"term":2,"lsn":7},"trades":{"term":3,"lsn":98012}},
 "majority_holds":{"_system":{"term":3,"lsn":120},"default":{"term":2,"lsn":7},"trades":{"term":3,"lsn":98012}},
 "lag":{"_system":0,"default":0,"trades":0},
 "sync_commit":{"wanted":true,"on":true,"waits":51200,"wait_us":40960000,"acks":9800,"fallbacks":0}}
```

| Field | Meaning |
|---|---|
| `role` | `leader`, `follower`, `pre-candidate` (asking whether it could win) or `candidate` |
| `term` | the election counter; it goes up by one for each election |
| `lease_left_ms` | the leader: how much longer it may write without another answer from a majority |
| `log_ends` | where each database's log ends on this node: its last LSN and the term of the leader that wrote it (0: before the cluster) |
| `majority_holds` | per database, the log a majority of the voters holds (the leader works it out; others show what it last said) |
| `lag` | per database, log entries not yet on the standby (on the leader) or not yet on this node (on a follower) |
| `sync_commit` | `wanted`: `KARELADB_SYNC_STANDBYS` is not `0`; `on`: commits wait for a standby now (this node leads); `mode`: `off`, `prefer` or `required`; how many waited, for how long in all, the standby acks, the `fallbacks` (commits confirmed without a standby) and the `refused` (commits refused or failed with `required`) |
| `diverged` | a data node: the copies kept in `<data>/_diverged` because they held commits the leader never got ([rejoin](#rejoin)); `folder` is the name `DELETE /api/cluster/diverged?folder=` takes, `path` where it is |
| `unopenable` | a data node: databases that could not be opened (a damaged manifest, a missing key), with the error. They are left out of this node's log ends, so they never keep it out of an election; the open is tried again now and then |
| `followers` | the followers that do not vote, from `KARELADB_CLUSTER_FOLLOWERS` ([reading from followers](#reads)) |

Without a token:

| Request | Answer |
|---|---|
| `GET /health` | adds `"role":"leader"` or `"follower"` and `"cluster":{"node","term","leader"}`; the console's status bar shows it (`Leader - term 3`, `Follower - term 3 - leader a`) |
| `GET /health?role=leader` | `200` only on the leader, else `503`: point a load balancer's health check at it to send writes to the leader alone. `?role=follower` is the opposite. |

`/metrics` adds `kdb_cluster_leader` (1 on the leader), `kdb_cluster_term`, `kdb_cluster_lag_lsn{db="..."}`, `kdb_cluster_sync_on`, `kdb_cluster_sync_acks_total`, `kdb_cluster_sync_waits_total`, `kdb_cluster_sync_wait_seconds_total`, `kdb_cluster_sync_fallback_total`, `kdb_cluster_sync_required` (1 with `required`) and `kdb_cluster_sync_refused_total`.

A follower's copy and its lag show in `GET /api/standby`, `/api/stats` and `/metrics`, as on any [standby](standby.md#status).

<a id="sync"></a>

## Sync commit: a confirmed commit is on two disks

| `KARELADB_SYNC_STANDBYS` | A commit is confirmed once | Lost when the leader's computer dies |
|---|---|---|
| `required` | it is on the leader's disk **and** on a standby's disk. Never by the leader alone: with no standby copying, writes are refused | nothing that was confirmed |
| `1` or `prefer` (the default in a cluster) | it is on the leader's disk **and** on a standby's disk, while a standby copies. While none copies, by the leader alone (below) | nothing confirmed while a standby copies. Commits confirmed while none copied: lost if the leader's disk dies before a standby copies them |
| `0` | it is on the leader's disk | when its computer dies: what the standby had not copied yet, usually the last few ms. When it is only cut off from the network: everything it confirmed until its lease ran out, up to 3 s of commits |

A session can still say `SET synchronous_commit = off`: its commits are then confirmed at once, without waiting for any disk, as in PostgreSQL.

How it works: a standby syncs its log before it asks the leader for more, so its next request says "I hold everything before this". A commit waits for that. Writers that commit at the same time share one wait, so many writers pay it once together. Measured on one computer (2 data nodes and a witness, one INSERT per commit over the PostgreSQL port):

| | `KARELADB_SYNC_STANDBYS=0` | `1` |
|---|---|---|
| 1 client, time per commit (median) | 0.67 ms | 1.47 ms |
| 32 clients, commits per second | 15,700 | 9,300 |

When no standby copies - only the witness is reachable, or the standby is down - waiting would stop every write. With `1` (`prefer`) the leader then confirms commits without a standby (async), writes `WARNING: sync commit: no standby is copying ...` in its log (at most every 10 s) and counts each in `kdb_cluster_sync_fallback_total`. The first commit after a standby dies waits up to the lease (3 s) before that, and so does the first commit of each database after a node becomes leader, after `CREATE DATABASE` and after a database is opened again: the standby gets that long to find it. Sync commit comes back by itself as soon as a standby copies again. With `required` it refuses them instead ([below](#sync-required)).

<a id="sync-required"></a>

### `required`: never confirmed alone

Use `KARELADB_SYNC_STANDBYS=required` for data where a refused write is better than a confirmed write that may vanish (orders, payments).

| Case | What the commit does |
|---|---|
| A standby copies | the same as `1`: confirmed once the standby holds it |
| No standby copies (for longer than the lease) | refused **before it is written**: SQLSTATE `25006`, HTTP `500`, `no standby holds this database's log now ... nothing of it was written`. Send it again once a standby copies (`GET /api/cluster`) |
| The standby goes away while the commit waits | the commit waits up to `KARELADB_SYNC_WAIT_MS` (10 s) or its `statement_timeout`, then fails: `25006`, `no standby holds this commit ... it is on the leader's disk ... not confirmed`. It stays on the leader and the standby copies it when it comes back. Check whether it is there before you send it again |
| `SET synchronous_commit = off` | not refused and not waited for, as with `1`: the session asked for no wait |

Each refused or failed commit counts in `kdb_cluster_sync_refused_total`, and the log says `WARNING: sync commit: ... required: commits are refused` at most every 10 s. Reads always go on. PostgreSQL's synchronous standby makes a commit wait forever (or, cancelled, keeps it with a warning); MySQL's semi-sync falls back to async after a timeout. `required` instead refuses up front once it knows no standby copies, so a client never hangs and never hears "done" for a commit only one disk holds.

Only a voting standby confirms a commit. A follower that does not vote (`KARELADB_CLUSTER_FOLLOWERS`) copies the same log, but an election never looks at it, so its copy does not count.

| Case | What the commit does |
|---|---|
| The standby is up but its copy makes no progress (its disk is full, every apply fails) | counts as "no standby copies": async after the lease, with the warning |
| The leader still reaches the witness | async: the commits are confirmed by the leader alone. No second leader can write meanwhile (the witness still backs this one), but if the leader's computer is lost before a standby copies them, they are lost - the same as `KARELADB_SYNC_STANDBYS=0` for that time. The warning in the log says so |
| The leader reaches no one | waits; when the lease ends the node steps down and the commit fails |
| The leader steps down while a commit waits | the commit fails with `committed on this node's disk but not confirmed by a standby ... may be lost` (HTTP `500`, SQLSTATE `08007`, "transaction resolution unknown"). It is on the old leader's disk only: check on the new leader whether it is there before you send it again. The old leader itself goes on: it becomes a follower, and if the new leader never got that commit, the old leader's copy goes to [`_diverged`](#rejoin) and it takes the new leader's history. |

Reads never wait for a standby. A node that stepped down with a commit no standby confirmed refuses reads of that database (`503`, try again) until it follows the new leader again (a few seconds): its rows are not shown to other clients while the cluster may still drop them. A node that restarts in between does not know this any more.

`CREATE DATABASE` and `DROP DATABASE` are not covered by sync commit: the leader confirms them alone, and a standby makes or drops its copy on its next look at the leader's list (within a second). If the leader's computer dies in that second, the new leader may still have a dropped database (with its rows) or lack a new one. Check after a failover, or wait a second after either before you count on it.

<a id="clients"></a>

## Clients

| Client | How it finds the leader |
|---|---|
| PostgreSQL drivers | list every data node: `host=10.0.0.1,10.0.0.2 target_session_attrs=read-write` (libpq, pgx, JDBC). A follower says `in_hot_standby = on` and `transaction_read_only = on`, so the driver skips it. |
| HTTP | a write sent to a follower is answered `421 Misdirected Request` with the leader's address in the header `X-KarelaDB-Leader`; the body is the same `25006` error as before. Send the request again there. |
| The console | on a `421` it offers once to open the leader's console |
| `kareladb exec` | `kareladb exec --url http://10.0.0.2:9900 --token T "INSERT ..."` follows a `421` once to the leader |
| A virtual address | `KARELADB_ON_LEADER` and `KARELADB_ON_FOLLOWER` name a command the node runs on each role change, with the role, the term and the leader's id: `move-ip.sh leader 3 a`. Use it to move a keepalived or cloud floating IP address to the leader. The scripts run one at a time, in order, and never hold up the election. Only the newest role's script runs when several changes come at once; one that runs longer than `KARELADB_ROLE_SCRIPT_TIMEOUT_MS` (30 s) is killed with everything it started. |

<a id="reads"></a>

## Reading from followers

Every follower answers reads, so reads can be spread over the nodes. Add as
many more read copies as you like: a **learner** copies the leader like any
follower but never votes, so the election stays the same with or without it.

```bash
# a learner: its --node-id is not in --cluster-peers
kareladb serve --data-dir /data/f1 --token T --node-id f1 \
  --cluster-peers a=http://10.0.0.1:9900,b=http://10.0.0.2:9900,w=http://10.0.0.3:9900 --cluster-learner
```

Or list the learners on every node with `KARELADB_CLUSTER_FOLLOWERS=f1=http://10.0.0.4:9900,f2=http://10.0.0.5:9900`:
a node whose id is there is a learner, and `GET /api/cluster` on a voter lists them.
A learner asks the voters who leads every heartbeat and follows the newest
leader; `GET /api/cluster` on it says `"role":"learner"`, the leader and `lag_ms`.

**Read your own write.** A copy is a few ms behind the leader, so a read sent
there right after a write may not see it yet. The cluster leader answers every
write that changed something (`POST /exec`, `/write`, `/imp`, `/api/v2/write`)
with `X-KarelaDB-Lsn`: where that database's log ends with the write in it.
Send it back as `X-KarelaDB-Min-Lsn` with the read (same database), and the
follower waits until it has applied that far. Only a cluster leader sends it:
a plain primary with [standbys](standby.md) does not.

The key-value store (`/kv`, `kv_get()` and the other `kv_*` functions) answers
on the leader only. It keeps its keys in memory, and a follower copies the
leader's `_kv` rows into the table, not into that memory, so a follower
refuses every key command, reads too: `/kv` answers `421` with the leader's
address in `X-KarelaDB-Leader`, as a write does. When a follower becomes the
leader it reads its keys again from `_kv` before it takes a command, so it
goes on from the keys the old leader had, not from the ones it held when it
started.

```bash
curl -si -X POST http://leader:9900/exec -H "Authorization: Bearer T" -d "INSERT INTO trades VALUES (...)" | grep -i x-kareladb-lsn
# X-KarelaDB-Lsn: 98012
curl -s "http://follower:9900/exec?query=SELECT%20count(*)%20FROM%20trades" -H "Authorization: Bearer T" -H "X-KarelaDB-Min-Lsn: 98012"
```

| Setting | Default | What it does on a follower or standby |
|---|---|---|
| `KARELADB_READ_WAIT_MS` | 2000 (10000 at most) | the longest a read with `X-KarelaDB-Min-Lsn` waits; after that it answers `503` (with `Retry-After`) so the client reads from the leader. At most 64 reads wait at once on a node; the next is told `503` at once |
| `KARELADB_MAX_READ_LAG_MS` | 0 (no limit) | a node further behind than this answers HTTP reads with `503`, so clients and load balancers go to another node. A node copying from nobody (during an election, or before it has reached a leader) counts as too far behind |

Both apply to HTTP reads only (`/exec`, `/v/...`, `/exp` and `POST /cursor`),
after the token check; the leader ignores them. The PostgreSQL port does not
read them: a lagging follower still answers there. The lag is the one
`GET /api/standby` shows.

A follower applies the leader's log a run of transactions at a time, with one
disk sync per run. Measured on one machine (two writers committing small
transactions as fast as they could): the copy stayed a median of 96 log
entries behind and caught up 15 ms after the load stopped (one sync per
transaction: 5,700 entries behind, 2.5 s to catch up). A read on the follower
waits only while a run is applied: p99 20 us during that load (1.1-1.7 ms
before).

<a id="failures"></a>

## What happens when something breaks

Each row was tested on one computer with two data nodes and a witness, with
four clients writing all the time (`tools/cluster_check` in the source; it cuts
links with its own proxies). With sync commit (the default) not one confirmed
row was lost in any of them, both data nodes always ended with the same rows,
and no term ever had two leaders.

| What broke | What the cluster did |
|---|---|
| The leader's computer died (`kill -9`) | the other data node led and took writes again 3.6 to 6 s later (90 failovers in a 22-minute run) |
| The leader died in the middle of a big transaction (200,000 rows), a `CHECKPOINT` or an `ALTER TABLE` | the same; the transaction or the new column is there whole or not at all |
| The leader died while the `COMMIT` of a spilled transaction (past `--txn-spill-mb`) wrote it into the log | the same: the transaction is there whole or not at all |
| The leader was cut off from both others | it stopped confirming writes at once (they waited, then failed); the other data node led 3.9 s later. When the cable came back, the old leader followed the new one |
| The witness was cut off | nothing changed: same leader, same term, writes went on |
| A link that went down and up every 0.2 to 1.5 s, for 40 s | no election at all (the term stayed the same) |
| A slow link to the follower (20 ms more per packet) | sync commits got slower (1,600 to 225 rows a second for four clients), none failed |
| All three stopped (power cut or clean stop), then started in any order | the same history; writes were taken again 1 to 4.4 s after the last node started |

With `KARELADB_SYNC_STANDBYS=0` (async) the same tests lose confirmed rows, as expected:

| What broke | Lost with async (four clients) |
|---|---|
| The leader's computer died | 100 rows: what the follower had not copied yet |
| The leader was cut off from both others | 29,635 and 74,704 rows in two runs: everything it confirmed in the 3 s until its lease ran out. They are in its `_diverged` folder |

Use sync commit (the default) when a confirmed row must never be lost.

<a id="limits"></a>

## What it does not do yet

| | |
|---|---|
| `KARELADB_SYNC_STANDBYS=0`, or `1` with only the witness reachable (`required` refuses instead) | a commit the follower had not copied when the leader's computer died is lost from the cluster (usually the last few ms). A leader that is only cut off goes on confirming until its lease ends: those commits (up to 3 s of them) are kept in its `_diverged` folder when it comes back, not in the cluster. |
| An old leader's users database (`_system`) with commits the new one never got | it stops copying `_system` and says so; move `<data>/_system` away while the node is stopped. Every other database takes the leader's history by itself ([rejoin](#rejoin)). |
| `kareladb promote` | refused on a cluster node: the leader is elected. |
| Reads during an apply | a read on a follower waits while a run of the leader's transactions is applied (usually microseconds, at most a few ms): it does not read a snapshot there, which could show half a transaction. |

<a id="see-also"></a>

## See also

- [Standby server](standby.md): how a follower copies the leader's log.
- [Backups and safety](backup-and-safety.md).
