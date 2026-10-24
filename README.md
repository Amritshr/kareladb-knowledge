# KarelaDB knowledge

Documentation of **KarelaDB (KARELA DataBase)** for people and for AI assistants (web site: https://amritshr.github.io/kareladb-knowledge/): 123 help topics, 25 tutorial chapters and 2321 examples. Every example ran on kareladb 0.2.0-dev when this was built (2026-10-24), and its real result is written under it.

KarelaDB is a SQL database for time-series and relational data, made by Amrit Shrestha. One program serves an HTTP/JSON API and a web console (port 9900) and the PostgreSQL wire protocol (port 8832). It is not kdb+/q.

KarelaDB was called KDB until 2026-10-22; it was renamed so nobody mixes it up with kdb+ by KX Systems. The old `kdb` command and the `KDB_*` settings still work.

This repository holds documents and AI skills only. It has no source code of KarelaDB.

## Give it to an AI

| AI | What to do |
|---|---|
| Any chat assistant that opens links (ChatGPT, Claude, Gemini, Copilot, Perplexity, ...) | Give it this link: https://raw.githubusercontent.com/Amritshr/kareladb-knowledge/main/llms.txt and ask it to read the topics it needs. For a custom GPT, Gem or Project, paste [ai/system-prompt.md](ai/system-prompt.md) into its instructions. |
| Claude Code, Claude.ai, Claude Desktop | Copy `skills/kareladb/` (and `skills/kareladb-geometry/`) into `~/.claude/skills/` or your project's `.claude/skills/`, or upload the folder as a skill in Claude.ai. A KarelaDB server can also write it: `kareladb skill install`. |
| OpenAI Codex, Cursor, Windsurf, Zed, Aider, Jules and other agents | Copy [ai/AGENTS.md](ai/AGENTS.md) into your project (as `AGENTS.md`). Tools that read Agent Skills can use `skills/` as it is. |
| Gemini CLI | Copy [ai/GEMINI.md](ai/GEMINI.md) into your project. |
| GitHub Copilot | Copy [ai/.github/copilot-instructions.md](ai/.github/copilot-instructions.md) into your project's `.github/`. |
| Cursor rules | Copy [ai/.cursor/rules/kareladb.mdc](ai/.cursor/rules/kareladb.mdc) into your project's `.cursor/rules/`. |
| RAG, embeddings, your own tools | [llms-full.txt](llms-full.txt) is everything in one file; [index.json](index.json) lists every topic and part; `docs/` has one file per topic. |

## What is here

| Path | What it is |
|---|---|
| [llms.txt](llms.txt) | the index for AIs: one line per topic, by category ([llmstxt.org](https://llmstxt.org)) |
| [docs/](docs/) | one markdown file per help topic |
| [tutorial/](tutorial/) | the tutorial, chapter by chapter |
| [fixtures/](fixtures/) | the sample tables the examples load first |
| [skills/](skills/) | the Agent Skills (`SKILL.md`) |
| [ai/](ai/) | the same knowledge as AGENTS.md, GEMINI.md, Copilot and Cursor rules, and a system prompt |

## Start reading

- [About KarelaDB](docs/about-kareladb.md): What KarelaDB is, who made it, what you can use it for, how it keeps your data safe, how fast it is and how it is tested.
- [Quick start](docs/quick-start.md): Get kareladb, make a database, create a table, add rows, query them and open the web console.
- [SQL basics](docs/sql-basics.md): How KarelaDB reads SQL text: statements, names, text, numbers, TRUE/FALSE/NULL, comments, errors and reserved words.
- [CREATE TABLE](docs/create-table.md): Make a relational or a time-series table, with partitions, sort order, a dedup key, rounded times and computed columns, or make one from a query with CREATE TABLE ... AS.
- [SELECT](docs/select.md): Choose the columns and values that a query gives back, and the table they come from.
- [SAMPLE BY](docs/sample-by.md): Put rows into time buckets (1 minute, 15 minutes, 1 hour, 1 day, 1 week, 1 month) and make candles.
- [HTTP API overview](docs/http-overview.md): How to talk to kareladb serve over HTTP - the address, choosing the database, JSON answers, errors, safety rules and limits.
- [PostgreSQL protocol (port 8832)](docs/postgres-protocol.md): Connect to KarelaDB with PostgreSQL tools and drivers - psql, DBeaver, Python, Node, C#, Go - and what works and what does not.
- [Performance tips](docs/performance-tips.md): Make loading and queries fast - memory, threads, batch commits, bulk INSERTs, good table design, time filters, what the column engine takes, zone maps, saved stats, and how to measure.
- [Limits](docs/limits.md): The sizes and counts KarelaDB allows, what happens at each limit, and the features that are not there yet.

Made from the KarelaDB help, which is also served by every KarelaDB server at `/help`. Do not edit these files here: they are built again from the help on each release.

Copyright (c) 2026 Amrit Shrestha. See [NOTICE.md](NOTICE.md).
