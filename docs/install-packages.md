# Install packages and the Claude skill

> The Windows and Linux install packages, the Docker image, and the skill file that teaches an AI assistant in another project how to use KDB.

- Category: Getting started
- Keywords: install, installer, package, zip, tar.gz, install.sh, install.ps1, PATH, systemd, service, Docker, image, container, docker stop, docker rm, stop-timeout, restart unless-stopped, HEALTHCHECK, healthy, connection refused, retry, 503, Retry-After, KDB\_DRAIN\_TIMEOUT, last shutdown, not clean, uninstall, Claude, AI, skill, kdb skill, kdb skill install, --dir, --url, --home, KDB\_URL, token file, 0600, /skill.md, agent, assistant, KDB\_TOKEN, KDB\_MEMORY, KDB\_MEMORY\_LIMIT, KDB\_READER\_YIELD, KDB\_SNAPSHOT\_READS, KDB\_CORE\_DUMPS, KDB\_CORE\_KEEP, core dump, crash, gdb, kdb.debug, KDB\_DATA\_DIR, KDB\_CONFIG, KDB\_BACKUP\_SCHEDULE, KDB\_BACKUP\_COMMAND, GLIBC\_TUNABLES, kdb.conf, volume
- See also: [Quick start](quick-start.md), [kdb serve](cli-serve.md), [Web console](web-console.md), [HTTP API overview](http-overview.md), [Keeping kdb serve safe](server-security.md)

KDB ships as one program and three folders of plain files next to it: the web console, the help pages and the Claude skill. There is nothing else to install - no runtime, no libraries, no service to configure first. There are three ways to get it onto a machine.

| Way | You get | Best for |
|---|---|---|
| The Windows package | `kdb-<version>-windows-x64.zip` | a desktop or a Windows server |
| The Linux package | `kdb-<version>-linux-x64.tar.gz`, built static so it runs on any distribution | a VPS or a Linux desktop |
| The Docker image | a small Alpine image with the program and its folders | a server you would rather not install anything on |

An unpacked package looks like this:

```text
kdb-<version>-<os>-x64/
  kdb.exe (Windows) or kdb (Linux)   the program - nothing else is inside it
  web/                               the web console
  help/                              the help pages (missing when the package was made without them)
  skill/skill.md                     the Claude skill
  install.ps1 or install.sh, kdb.conf.example, README.md
```

<a id="windows"></a>

## Windows

Unpack the zip and run the installer from the folder it made:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

It copies `kdb.exe` and its `web`, `help` and `skill` folders into `%LOCALAPPDATA%\Programs\kdb`, adds that folder to **your** PATH (no administrator rights needed) and writes the [Claude skill](install-packages.md#skill). Add `-Token my-secret` to save your token beside the skill, in a file only you can read.

| Option | Meaning | Default |
|---|---|---|
| `-Prefix <folder>` | where the program goes | `%LOCALAPPDATA%\Programs\kdb` |
| `-Token <secret>` | the token, saved in the file `token` beside the skill | `$env:KDB_TOKEN` |
| `-Data <folder>` | the data folder it suggests | `%LOCALAPPDATA%\kdb\data` |
| `-NoPath` | do not touch PATH | - |
| `-NoSkill` | do not write the skill | - |

Uninstalling is deleting that folder and taking it off your PATH. Nothing is registered with Windows.

<a id="linux"></a>

## Linux

Unpack the tar.gz and run the installer from the folder it made:

```bash
./install.sh                                              # just you: ~/.local/bin, folders in ~/.local/share/kdb
sudo ./install.sh --system                                # everyone: /usr/local/bin, folders in /usr/local/share/kdb
sudo ./install.sh --system --service --token my-secret    # ...and start it at boot
```

| Option | Meaning | Default |
|---|---|---|
| `--system` | install into `/usr/local` instead of `~/.local` | - |
| `--prefix <folder>` | install somewhere else | `~/.local` |
| `--service` | write a systemd unit and start it (needs root and `--token`) | - |
| `--token <secret>` | the token for the service and the skill | `$KDB_TOKEN` |
| `--data <folder>` | the data folder | `/var/lib/kdb` or `~/.local/share/kdb` |

With `--service` the server runs as its own `kdb` user, is restarted if it stops, and can write to its data folder and nowhere else. The unit file holds the token, so it is readable only by root.

```bash
systemctl status kdb
journalctl -u kdb -f
```

<a id="folders"></a>

## Where kdb finds the console, the help and the skill

The web console, the help pages and the Claude skill are files, so a new console or help needs the files copied, not a new program. `kdb` looks for each folder in this order and uses the first one that has its files in it (`index.html`, or `skill.md`):

| Order | Web console | Help pages | Claude skill |
|---|---|---|---|
| 1. `kdb.conf` | `"web_dir"` | `"help_dir"` | `"skill_dir"` |
| 2. environment | `KDB_WEB_DIR` | `KDB_HELP_DIR` | `KDB_SKILL_DIR` |
| 3. next to the program | `web/` | `help/` | `skill/` |
| 4. `share/kdb` beside the program folder | `../share/kdb/web` | `../share/kdb/help` | `../share/kdb/skill` |
| 5. a source checkout (`build/bin/kdb`) | `web/console` | `docs/help/site` | `.claude/skills/kdb` |

- The console's **Settings** page shows the folders in use and what chose each one. They are read-only there.
- Files are read when they are asked for, so copying a new help build into `help/` shows at the next page load, without a restart.
- A folder that is missing does not stop the server. The HTTP API works, `http://127.0.0.1:9900/` says the console is not installed and lists the folders it looked in, and `/help/` says how to build the help.

A `kdb.conf` that names all three:

```json
{
  "data_dir": "E:/kdb-data",
  "web_dir": "E:/kdb/web",
  "help_dir": "E:/kdb/help",
  "skill_dir": "E:/kdb/skill"
}
```

<a id="docker"></a>

## Docker

```bash
docker run -d --name kdb -p 9900:9900 -p 8832:8832 \
  -e KDB_TOKEN=<token> -v kdb-data:/data kdb
```

The data lives in the named volume `kdb-data`, so removing and recreating the container does not lose it. The server refuses to start without `KDB_TOKEN`: the image listens on all addresses, so a published port can reach it, and KDB does not do that without a secret.

The image holds `/usr/local/bin/kdb` and its folders in `/usr/local/share/kdb/web`, `help` and `skill` (named by `KDB_WEB_DIR`, `KDB_HELP_DIR` and `KDB_SKILL_DIR`). The image build only compiles `kdb` and copies those folders from the source tree, so run the help build first when the help pages should be in it.

- Add `--restart unless-stopped` so the server comes back by itself after Docker or the computer restarts.
- The image has a health check: `docker ps` shows `healthy` once the HTTP port answers `GET /health`. While the server is stopping, `/health` answers 503.
- Anything after the image name is added to `kdb serve`, for example `... kdb --threads 4`.

The settings of the image, all given with `-e NAME=value`:

| Variable | Meaning | Default in the image |
|---|---|---|
| `KDB_TOKEN` | the secret every request sends as `Authorization: Bearer <token>`. The start script passes it as `--token`; the program itself reads no `KDB_TOKEN`. | none: required |
| `KDB_MEMORY` | `--memory`, in MB (passed as the flag) | `256` |
| `KDB_MEMORY_LIMIT` | one limit for everything the server holds ([memory limit](cli-serve.md#memory-limit)), like `3GB` | 85% of the container's memory limit, else of Docker's memory |
| `KDB_DATA_DIR` | the data folder | `/data` |
| `KDB_CONFIG` | the settings file (passed as `--config`) | `/data/kdb.conf` |
| `KDB_DRAIN_TIMEOUT` | how long running requests may finish on a stop | `5s` |
| `KDB_READER_YIELD` | `on`: reads do not wait for a long trigger or transaction ([--reader-yield](cli-serve.md#kdb-serve)). `off`: they wait. | `on` |
| `KDB_SNAPSHOT_READS` | `on`: a read of a table being written reads a snapshot of the committed rows and does not wait ([--snapshot-reads](cli-serve.md#kdb-serve)) | `off` |
| `KDB_PER_TABLE_READS` | `off`: every read waits for every writer, as before ([--per-table-reads](cli-serve.md#kdb-serve)) | `on` |
| `KDB_READ_ONLY_CALLS` | `off`: every `CALL` is a transaction, also one that only reads ([--read-only-calls](cli-serve.md#kdb-serve)) | `on` |
| `KDB_CORE_DUMPS` | `on`: a crash leaves a core dump in `/data/_logs/cores` (kdb runs from that folder). At the next start the dump is renamed with its time. `off`: no dumps. The unstripped program for reading one is `/usr/local/lib/kdb/kdb.debug` (`gdb kdb.debug core.<time>`). | `on` |
| `KDB_CORE_KEEP` | how many old core dumps are kept; a dump is about as big as the server's memory | `2` |
| every other `KDB_*` variable of `kdb serve` | as listed in [every option](cli-serve.md#all-options), for example `KDB_HTTP_THREADS`, `KDB_TIMER_WORKERS`, `KDB_CACHE_MB`, `KDB_TIMEZONE` | the program's defaults |
| `GLIBC_TUNABLES` | for example `glibc.malloc.arena_max=8`: how many memory arenas the C library keeps (fewer than the query threads makes concurrent queries wait for each other's allocations; 2 arenas halved the request rate of 8 clients) (see `allocator_arena_max` in [/api/stats](http-server-info.md#api-stats)). With `trim_threshold` set, KDB puts glibc's mmap line at 32 MB, where glibc would move it itself (`allocator_mmap_threshold`) | KDB chooses |

A fuller run line, as a long-running server uses it:

```bash
docker run -d --name kdb --restart unless-stopped --stop-timeout 60 \
  -p 9900:9900 -p 8832:8832 \
  -e KDB_TOKEN=<token> -e KDB_MEMORY=1536 -e KDB_READER_YIELD=on \
  -e GLIBC_TUNABLES=glibc.malloc.arena_max=8:glibc.malloc.trim_threshold=67108864 \
  -v kdb-data:/data kdb
```

On Windows, `-v "D:\kdb_data:/data"` puts the data in a Windows folder instead of a named volume.

<a id="docker-settings"></a>

### The data folder and kdb.conf in the container

- The image passes the data folder as the environment variable `KDB_DATA_DIR`, **not** as `--data-dir`. A command-line flag always wins over what the console's [Settings page](console-settings.md) saves, so a flag would make that page read-only. With the variable, `/data` is the default and an admin can still choose another folder in the console.
- `kdb.conf` is `/data/kdb.conf`, inside the volume. A setting saved on the Settings page survives `docker rm` and a new image.
- A data folder chosen on the Settings page must be under a mounted volume too. Anywhere else is in the container's own layer and is thrown away with the container.
- Backups go to `/data/_backups`, inside the volume, with no setting. Turn on a schedule with `-e KDB_BACKUP_SCHEDULE="daily 02:00"` (or the Settings page), and copy each backup off the machine with `-e KDB_BACKUP_COMMAND="..."` - the tool it runs (rclone, aws) must be in the image ([backup schedule](backup-schedule.md#backup-command)).

<a id="docker-stop"></a>

### Stopping and restarting the container

| Command | What KDB gets | Next start says |
|---|---|---|
| `docker stop kdb`, container run **with** `--stop-timeout 60` | SIGTERM, then a kill after 60 s | `last shutdown: clean` |
| `docker stop -t 60 kdb` | SIGTERM, then a kill after 60 s | `last shutdown: clean` |
| `docker stop kdb`, container run **without** `--stop-timeout` | SIGTERM, then a kill after Docker's default wait - seen as short as **1 s** | `clean` only if nothing was running |
| `docker rm -f kdb`, `docker kill kdb` | a kill at once | `last shutdown: not clean (crash or kill)` |

An image cannot choose how long Docker waits, so give the container `--stop-timeout` when you create it. Without it, a stop while a request runs, or while a big database closes, ends in a kill.

On SIGTERM the server:

1. keeps the port open and lets requests that are already running finish, up to `KDB_DRAIN_TIMEOUT` (5 s in the image);
2. answers every new request with **503** and `Retry-After: 2`;
3. cancels what still runs (a writer that waits for a busy table stops waiting too), closes every database side by side and writes the clean-shutdown mark.

A kill is safe too - every confirmed write is in the log - but the next start has to replay the log. So stop the container before you remove it:

```bash
docker stop -t 60 kdb && docker rm kdb
docker run -d --name kdb --restart unless-stopped --stop-timeout 60 \
  -e KDB_DRAIN_TIMEOUT=30s -e KDB_TOKEN=<token> \
  -p 9900:9900 -p 8832:8832 -v kdb-data:/data kdb
```

- `--stop-timeout 60` makes a plain `docker stop` (and Docker's own restart) wait 60 s. Keep `KDB_DRAIN_TIMEOUT` well below it, so closing the databases still fits.
- The server log shows `databases closed cleanly (N ms)`. If N gets close to the stop timeout, give it more.
- With Docker Compose the same is `stop_grace_period: 60s` on the service.

<a id="docker-clients"></a>

### What a client should do

While the container is stopped and started again there is a short gap, about 2 s on a laptop.

| The client sees | Meaning | Do |
|---|---|---|
| HTTP **503** with `Retry-After` | the server is stopping; the request was not run | wait that many seconds, send it again |
| **connection refused** | the server is not listening yet (or any more) | wait a second, try again |
| the connection closed before a reply | the request was cut off | send it again |

- A write that was cut off, or answered 503, is rolled back as a whole: no row of it is saved. Sending the same `/write`, `/imp` or `/exec` again is safe.
- A request that was already running when the stop began gets its real answer, then the connection closes. Open a new one for the next request.
- Retry refused connections, not only HTTP errors. A loader that gives up on the first refused connection stops at every restart.

<a id="skill"></a>

## The Claude skill

Claude Code, or any other AI assistant, working in **some other project** has no idea KDB exists. It will not guess the port, the token, the shape of `/exec` or where the help is. A *skill file* tells it, once, and every project on the machine benefits.

The installers write it for you. To do it by hand, or again after the address or token changed:

Syntax:

```sql
kdb skill
kdb skill install [--dir <folder>] [--url <address>] [--token <secret>] [--home <checkout>]
```

```bash
kdb skill install                                  # writes ~/.claude/skills/kdb/SKILL.md
kdb skill install --token <token> --home /srv/kdb-source
kdb skill                                          # print it instead, to pipe somewhere
```

| Option | Meaning | Default |
|---|---|---|
| `--dir <folder>` | where to write `SKILL.md` | `~/.claude/skills/kdb` |
| `--url <address>` | the address the assistant should use | `$KDB_URL`, else `http://localhost:9900` |
| `--token <secret>` | the token, saved in the file `token` beside `SKILL.md` (see below) | `$KDB_TOKEN` |
| `--home <folder>` | a source checkout, so the assistant can read `docs/help/topics/` | - |

**Command line: Install into a folder of your choice, with another address**

```bash
kdb skill install --dir my-skills/kdb --url http://kdb.example.lan:9900
```

Output:

```text
wrote my-skills/kdb/SKILL.md
Claude Code picks it up in any project the next time it starts.
```

**The token is never written into `SKILL.md`.** An assistant may quote that file, or you may copy it somewhere, so it only says where the token is. The token goes into its own file, `token`, in the same folder:

| | `SKILL.md` | `token` |
|---|---|---|
| holds | the skill, the address, the paths, **where** the token file is | the token, on one line |
| who can read it | like any of your files | only you: mode `0600` on Linux and macOS, an owner-only ACL on Windows |

Run without a token, `kdb skill install` leaves an existing `token` file alone and still points to it. A `SKILL.md` written by an older `kdb` held the token in clear: run `kdb skill install` again to replace it.

`--dir` is **refused** when it is, or is inside, a folder the server hands out without a login: the skill folder (`GET /skill.md`), the console folder or the help folder, wherever `kdb` looks for them ([the folders](install-packages.md#folders)). A token there could be fetched by anyone who reaches the server.

The text is the file `skill/skill.md` next to the program, found the same way as the [other folders](install-packages.md#folders), so this works with no source folder and no network.

A running server also hands the same text out, without a token, at `GET /skill.md`. That is how a machine that can only reach the server over the network gets it:

```bash
mkdir -p ~/.claude/skills/kdb
curl -s http://your-server:9900/skill.md -o ~/.claude/skills/kdb/SKILL.md
```

From Docker, ask the program inside the container:

```bash
docker exec kdb kdb skill > ~/.claude/skills/kdb/SKILL.md
```

Claude Code reads the folder when it starts, so open a new terminal afterwards.

<a id="building"></a>

## Building the packages yourself

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --target kdb
node tools/help/build_help.mjs --kdb build/bin/kdb.exe   # the help pages -> docs/help/site (runs every example)
cpack --config build/CPackConfig.cmake          # -> dist/kdb-<version>-<os>-<arch>
```

The Linux package is built inside the Docker image, which also links it static:

```bash
docker build --target package -o dist -f docker/Dockerfile .
```

A package holds the program, its `web`, `help` and `skill` folders, the installer and `kdb.conf.example`. No source, no tests, no build folder. The help build is its own step: without it the package has no `help` folder, and `/help` says how to add one.
