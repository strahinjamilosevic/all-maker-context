# all-maker-context

Project brief for Claude Code. Read fully before acting. Owner: Strahinja Milosevic (GitHub: strahinjamilosevic).

If `CLAUDE.local.md` exists, read it too. It is gitignored and holds private context. Never copy its content into committed files.

## 1. What this is

A self-hosted n8n deployment that ingests three existing GitHub repos, structures their content against a controlled taxonomy, flags quality issues, stores it in a vector database, and exposes it to AI agents through an MCP server. A second workflow cross-posts new blog posts to LinkedIn after human approval.

## 2. Goals

1. Keep personal content structured, governed, and queryable by AI agents.
2. Automate blog-to-LinkedIn distribution with a human approval step.
3. Learn n8n, Docker, VPS operations, MCP, and vector stores hands-on.

## 3. References

- n8n docs: https://docs.n8n.io
- n8n repo: https://github.com/n8n-io/n8n
- MCP Server Trigger node: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-langchain.mcptrigger/
- Docker install docs: https://docs.n8n.io/hosting/installation/docker/

## 4. Source repos (read-only for n8n)

Confirm exact repo names with the owner before configuring anything.

| Source | Content | Notes |
|---|---|---|
| all-maker.com | Docusaurus blog: Blog, Resources, Crafting | GitHub Pages, Vale, GA4, llms.txt |
| strahinjamilosevic.com | Mintlify portfolio: skills, education, experience, case studies, mock resume API | |
| careers repo | Resume, education, portfolio data, case studies, application records | May contain personal data: exclude application records and contact details from ingestion |

Proposed mapping (unconfirmed): `strahinjamilosevic/all-maker` (public), `strahinjamilosevic/strahinjamilosevic` (public, has `docs.json`), `strahinjamilosevic/career` (private; top level: `jobs/`, `linkedin/`, `portfolio/`, `profile/`, `resume/`, `scripts/`).

## 5. Architecture

```
GitHub (3 repos) --push webhook--> n8n
                                     |
                         fetch changed .md/.mdx
                                     |
                         normalize (frontmatter, strip MDX)
                                     |
                         LLM extraction against taxonomy
                                     |
                         quality gate --fail--> GitHub Issue (review queue)
                                     |
                         chunk + embed --> Qdrant
                                     |
                         MCP Server Trigger: search_evidence, get_document
                                     |
                         Claude Code / Claude Desktop / other agents

all-maker.com merge to main --> LLM drafts LinkedIn post --> Telegram approval --> LinkedIn
```

Hosting: one Hetzner Cloud VPS, Ubuntu 24.04 LTS, Docker Compose running n8n, Qdrant, Caddy (auto HTTPS). Public hostname: `n8n.all-maker.com`. Qdrant never exposed publicly.

## 6. Repo layout

```
all-maker-context/
  CLAUDE.md
  CLAUDE.local.md        (gitignored, private)
  README.md
  docker-compose.yml
  Caddyfile
  .env.example
  .gitignore
  .gitattributes
  taxonomy/
    schema.yaml
    contributor-guide.md
  workflows/
    ingest.json
    quality-gate.json
    mcp-server.json
    cross-post.json
  scripts/
    server-setup.sh
    backup.sh
  docs/
    architecture.md
    runbook.md
    decisions/
      0001-self-hosted-n8n.md
      0002-qdrant-vector-store.md
      0003-github-issues-review-queue.md
      0004-mcp-server-trigger.md
```

## 7. Rules for Claude Code

- Never commit secrets. `.env` is gitignored; only `.env.example` with variable names.
- Never commit `CLAUDE.local.md` or copy its content into tracked files.
- Workflows are edited in the n8n UI, exported, and committed to `workflows/`. Check exports for embedded secrets before committing.
- The owner is on Windows and new to Docker/VPS work: give every manual step as an explicit, numbered instruction with the exact command and where to run it (local PowerShell vs server SSH session). State the expected output.
- Do not suggest Windows registry edits.
- Before any destructive or irreversible step (deleting volumes, rotating encryption keys, force-pushing), stop and confirm.
- Writing style for docs in this repo: short declaratives, no filler, no emojis, no moralizing.
- Pin Docker image versions in `docker-compose.yml`; note the version in the runbook.

## 8. Plan

Mark each step done in this file as you go. [OWNER] = manual step by Strahinja. [CLAUDE] = Claude Code does it.

### Phase 0: Local machine (Windows)

1. [DONE] [OWNER] Open PowerShell. Install Git: `winget install --id Git.Git -e`. Restart the terminal. Verify: `git --version`.
2. [DONE] [OWNER] Install GitHub CLI: `winget install --id GitHub.cli -e`. Verify: `gh --version`. Log in: `gh auth login` (GitHub.com, HTTPS, browser).
3. [DONE] [OWNER] Configure Git identity:
   `git config --global user.name "Strahinja Milosevic"`
   `git config --global user.email "<your GitHub email>"`
4. [DONE] [OWNER] Create an SSH key for the server: `ssh-keygen -t ed25519 -C "all-maker-context"`. Accept the default path, set a passphrase. Public key is at `$HOME\.ssh\id_ed25519.pub`. Show it: `Get-Content $HOME\.ssh\id_ed25519.pub`.
5. [OWNER] Optional: VS Code extension "Remote - SSH" (Microsoft) to edit server files from VS Code.
6. [DONE] [OWNER] Create the GitHub repo. Local folder `C:\Repositories\all-maker-context` already exists with initial files; publish it with `gh repo create all-maker-context --public --source . --push` after the first commit.
7. Not needed locally: Docker, Terraform, Kubernetes, Node.js.

### Phase 1: Accounts

1. [OWNER] Hetzner Cloud account (https://www.hetzner.com/cloud). Create project `all-maker-context`. Security > SSH keys > add the public key from Phase 0 step 4.
2. [OWNER] LLM API: OpenAI platform account (https://platform.openai.com), add billing, set a monthly spend limit, create an API key. Used for both extraction and embeddings.
3. [OWNER] GitHub fine-grained PAT (Settings > Developer settings > Fine-grained tokens). Repository access: the 3 source repos + all-maker-context. Permissions: Contents read, Metadata read, Webhooks read/write, Issues read/write (all-maker-context only). Expiry: 90 days; record the date in `docs/runbook.md`.
4. [OWNER] Telegram bot for approvals: in Telegram, message @BotFather, `/newbot`, save the token. Message your bot once, then get your chat ID.
5. [OWNER] Later (Phase 6): LinkedIn Developer app (https://developer.linkedin.com). Requires a LinkedIn Page to associate with; add the "Share on LinkedIn" and "Sign In with LinkedIn using OpenID Connect" products.

### Phase 2: Server

1. [OWNER] Hetzner: create server. Location: Falkenstein or Nuremberg. Image: Ubuntu 24.04. Type: smallest shared x86 with at least 4 GB RAM. SSH key: the one from Phase 1. Enable backups. Create a firewall allowing inbound TCP 22, 80, 443 only; attach it.
2. [OWNER] Namecheap > all-maker.com > Advanced DNS: add A record, host `n8n`, value = server IPv4, TTL automatic. Verify after a few minutes: `Resolve-DnsName n8n.all-maker.com`.
3. [DONE] [CLAUDE] Write `scripts/server-setup.sh`: create non-root sudo user `deploy` with the same authorized key, disable root SSH login and password auth, enable `ufw` (22, 80, 443), enable `unattended-upgrades`, install Docker Engine and Compose plugin from Docker's official apt repository, add `deploy` to the `docker` group.
4. [OWNER] Run it: `ssh root@<server-ip>`, copy the script over (`scp scripts/server-setup.sh root@<server-ip>:/root/`), run `bash /root/server-setup.sh`. Reconnect as `ssh deploy@<server-ip>`. Verify: `docker run hello-world`.

### Phase 3: Stack

1. [DONE] [CLAUDE] Write `docker-compose.yml`:
   - `n8n`: official image `docker.n8n.io/n8nio/n8n`, pinned version; volume `n8n_data`; env from `.env`: `N8N_HOST=n8n.all-maker.com`, `N8N_PROTOCOL=https`, `N8N_PORT=5678`, `WEBHOOK_URL=https://n8n.all-maker.com/`, `GENERIC_TIMEZONE=Europe/Amsterdam`, `TZ=Europe/Amsterdam`, `N8N_ENCRYPTION_KEY`, `N8N_SECURE_COOKIE=true`, `N8N_RUNNERS_ENABLED=true`. SQLite is sufficient at this scale; note Postgres as a later option in an ADR.
   - `qdrant`: `qdrant/qdrant`, pinned; volume `qdrant_data`; `QDRANT__SERVICE__API_KEY` from `.env`; no published ports, internal network only.
   - `caddy`: `caddy:2`, ports 80/443, volumes for `Caddyfile`, `caddy_data`, `caddy_config`.
2. [DONE] [CLAUDE] Write `Caddyfile`: `n8n.all-maker.com { reverse_proxy n8n:5678 }`.
3. [DONE] [CLAUDE] Write `.env.example` and `.gitignore`.
4. [OWNER] On the server: `git clone https://github.com/strahinjamilosevic/all-maker-context.git`, `cd all-maker-context`, `cp .env.example .env`, fill values. Generate secrets with `openssl rand -hex 32`. Back up `N8N_ENCRYPTION_KEY` in a password manager: losing it makes stored credentials unreadable.
5. [OWNER] `docker compose up -d`, then `docker compose ps` (all running) and `docker compose logs caddy` (certificate obtained).
6. [OWNER] Open https://n8n.all-maker.com, create the owner account. Optional: register for the free Community Edition license key in Settings.
7. [DONE] [CLAUDE] Write `scripts/backup.sh` (stop-free volume tar of `n8n_data` and `qdrant_data`, keep 7 days) and a cron line; document restore in `docs/runbook.md`.

### Phase 4: Taxonomy

1. [CLAUDE] Inventory the 3 source repos: list content files, existing frontmatter fields, sections. Report before designing.
2. [CLAUDE] Draft `taxonomy/schema.yaml` with controlled vocabularies, for example:
   - `source`: all-maker-blog | portfolio | careers
   - `content_type`: blog_post | resource | case_study | resume_item | skill | project | education | api_reference
   - `employer`: bitvavo | adyen | proglove | blackrock | efront | ncr | none
   - `domain`: api_docs | docs_platform | information_architecture | leadership | hiring | ai_tooling | crafting
   - `skills`: closed list derived from the inventory
   - `audience`: hiring_manager | engineer | writer | general
   - `last_reviewed`: date; `freshness_days`: per content_type
3. [CLAUDE] Write `taxonomy/contributor-guide.md`: required fields, allowed values, how to propose a new value, templates per content_type.
4. [OWNER] Review and approve before Phase 5.

### Phase 5: Workflows

Build in the n8n UI with Claude Code giving node-by-node instructions; export each to `workflows/` when working.

1. Credentials in n8n: GitHub (PAT), OpenAI, Qdrant (URL `http://qdrant:6333` + API key), Telegram.
2. `ingest`: GitHub Trigger (push, per repo) + Schedule Trigger (weekly full re-index) > GitHub node / HTTP Request to fetch changed files > Code node (parse frontmatter, strip MDX, drop excluded paths) > Information Extractor (OpenAI) bound to `taxonomy/schema.yaml` > Code node (validate against vocabulary).
3. `quality-gate`: checks missing required fields, values outside vocabulary, duplicate content hash, `last_reviewed` older than `freshness_days`. Failures open or update a GitHub Issue in all-maker-context labeled `review-queue`, one per document.
4. Store: Default Data Loader + Recursive Character Text Splitter > OpenAI embeddings > Qdrant Vector Store (collection `all_maker_context`), taxonomy fields as payload. Upsert by document path so edits replace old chunks.
5. `mcp-server`: MCP Server Trigger with bearer auth. Tools: `search_evidence(query, filters)` (Qdrant retrieval with payload filters), `get_document(path)`. Test from Claude Code or Claude Desktop (claude.ai web connectors have known issues with self-hosted n8n MCP endpoints).
6. Activate workflows. Test: push a frontmatter change to a source repo, confirm the Qdrant upsert and/or Issue.

### Phase 6: Cross-posting

1. `cross-post`: GitHub Trigger on push to main in all-maker.com, filter to new files under `blog/` > fetch post > OpenAI drafts a LinkedIn post (short declaratives, link to post, no emojis, no hashtag spam) > Telegram "send and wait for approval" > on approve, LinkedIn node posts; on reject, log and stop.
2. Requires the LinkedIn app from Phase 1 step 5.

### Phase 7: Documentation

1. [CLAUDE] `README.md`: purpose, architecture diagram, setup summary, links to ADRs.
2. [CLAUDE] ADRs in `docs/decisions/`.

## 9. Open items

- Exact names of the 3 source repos. Proposed mapping in section 4.
- Paths in the careers repo to exclude from ingestion (personal data, application records). Candidates: `jobs/`, `profile/`, `linkedin/`, `.claude/`, `scripts/`.
