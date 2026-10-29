# all-maker-context

A personal context layer. It takes content from three GitHub repos, checks it against a controlled taxonomy, opens review Issues for quality problems, and stores clean content in a vector database. AI agents query it through an MCP server. A second workflow cross-posts new blog posts to LinkedIn, Bluesky, and Mastodon after approval in Telegram.

Everything runs on one self-hosted n8n instance. No workflow calls a paid AI API. Embeddings run locally in Ollama.

## How it works

```
GitHub (3 repos) --push webhook--> n8n
                                     |
                         fetch changed .md/.mdx/.yaml
                                     |
                         normalize (frontmatter, strip MDX)
                                     |
                         validate tags against taxonomy/schema.yaml
                                     |
                         quality gate --fail--> GitHub Issue (review-queue)
                                     |
                         chunk + embed (Ollama, nomic-embed-text) --> Qdrant
                                     |
                         MCP server: search_evidence, get_document
                                     |
                         Claude Code / Claude Desktop / other MCP clients

New blog post on all-maker master --> social text from frontmatter --> Telegram approval per platform --> LinkedIn / Bluesky / Mastodon
```

Tags are written at the source, in the frontmatter, when the content is written. n8n reads and validates them. It does not generate them. Review-queue Issues are fixed in the source repo, and the next sync closes them.

Details: [docs/architecture.md](docs/architecture.md).

## Sources

| Source | Repo | Content |
|---|---|---|
| `all-maker-blog` | [all-maker](https://github.com/strahinjamilosevic/all-maker) | Docusaurus site: blog, guides, craft logs |
| `portfolio` | [strahinjamilosevic](https://github.com/strahinjamilosevic/strahinjamilosevic) | Mintlify portfolio: profile pages, case studies |
| `careers` | private | Achievements, profile facts, LinkedIn profile text |

Scope and exclusions per repo are in [taxonomy/schema.yaml](taxonomy/schema.yaml) under `sources`. Files that hold personal data or job-search records are excluded by path.

## What the repo shows

| Concern | Where |
|---|---|
| Taxonomy, controlled vocabularies, templates | [taxonomy/schema.yaml](taxonomy/schema.yaml), [taxonomy/contributor-guide.md](taxonomy/contributor-guide.md) |
| Ingestion from separate sources | [workflows/ingest.json](workflows/ingest.json) |
| Freshness, duplicates, required fields | Quality gate in `ingest`, Issues labeled `review-queue` |
| Agent access | [workflows/mcp-server.json](workflows/mcp-server.json), [workflows/mcp-tools.json](workflows/mcp-tools.json), [.mcp.json](.mcp.json) |
| Distribution with human approval | [workflows/cross-post.json](workflows/cross-post.json) |
| Operations | [docs/runbook.md](docs/runbook.md), [scripts/](scripts/) |
| Decisions | [docs/decisions/](docs/decisions/) |

## Stack

One Hetzner Cloud VPS, Ubuntu, Docker Compose:

| Service | Role | Exposed |
|---|---|---|
| Caddy | HTTPS reverse proxy, automatic certificates | ports 80, 443 |
| n8n | Workflows, MCP server | through Caddy at `n8n.all-maker.com` |
| Qdrant | Vector store | internal network only |
| Ollama | Embedding model `nomic-embed-text` | internal network only |

Image versions are pinned in [docker-compose.yml](docker-compose.yml) and listed in the runbook.

## Setup summary

1. Create a VPS with a firewall that allows TCP 22, 80, 443. Point a DNS A record at it.
2. Run [scripts/server-setup.sh](scripts/server-setup.sh) as root. It creates the `deploy` user, hardens SSH, enables `ufw` and unattended upgrades, and installs Docker.
3. As `deploy`: clone this repo, `cp .env.example .env`, fill in the values, `docker compose up -d`.
4. Pull the embedding model: `docker compose exec ollama ollama pull nomic-embed-text`.
5. Open n8n, create the owner account, add the credentials listed in the runbook, import the files in `workflows/`, publish them.
6. Install the backup cron job from the runbook.

Full steps, credential expiry dates, upgrades, and restore: [docs/runbook.md](docs/runbook.md).

## Use the MCP server

Clients connect to `https://n8n.all-maker.com/mcp/all-maker-context` with a bearer token. For Claude Code, [.mcp.json](.mcp.json) reads the token from the `ALL_MAKER_MCP_TOKEN` environment variable.

| Tool | Does |
|---|---|
| `search_evidence(query, filters)` | Semantic search with optional filters: employer, domain, skill, tool, content type |
| `get_document(doc_id)` | Full text and tags of one document |

## Decisions

- [0001: Self-hosted n8n](docs/decisions/0001-self-hosted-n8n.md)
- [0002: Qdrant as the vector store](docs/decisions/0002-qdrant-vector-store.md)
- [0003: GitHub Issues as the review queue](docs/decisions/0003-github-issues-review-queue.md)
- [0004: MCP Server Trigger for agent access](docs/decisions/0004-mcp-server-trigger.md)
