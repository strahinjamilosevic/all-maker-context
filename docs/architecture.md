# Architecture

## Principles

- Tag at the source. Frontmatter carries the tags. n8n validates them and never writes them.
- One taxonomy. `taxonomy/schema.yaml` defines sources, fields, vocabularies, rules, and freshness limits. The ingest workflow reads it from this repo on every run.
- Fix at the source. Problems become GitHub Issues. Fixes happen in the source repo, and the next sync closes the Issue.
- No paid AI API in any workflow. Embeddings run locally. Writing and tagging happen in the IDE.
- Humans approve anything public. Nothing is posted to social media without a tap in Telegram.

## Components

```
Internet --443--> Caddy --> n8n
                             |-- backend network (internal) --> Qdrant
                             |-- models network -------------> Ollama
```

| Component | Network | Data |
|---|---|---|
| Caddy | `web`, ports 80 and 443 | certificates in `caddy_data` |
| n8n | `web`, `backend`, `models` | workflows, credentials, executions in `n8n_data` (SQLite) |
| Qdrant | `backend` (internal, no internet) | vectors in `qdrant_data` |
| Ollama | `models` (no published ports) | model files in `ollama_models` |

Only Caddy publishes ports. n8n credentials are encrypted with `N8N_ENCRYPTION_KEY`. `n8n_data` and `qdrant_data` are archived nightly.

## Workflows

| Workflow | Trigger | Purpose |
|---|---|---|
| `ingest` | push to a source repo; weekly full sync (Monday 03:30); manual | Collect, validate, flag, store |
| `mcp-server` | MCP client request | Expose `search_evidence` and `get_document` |
| `mcp-tools` | called by `mcp-server` | Tool logic |
| `cross-post` | new file under `blog/` on all-maker `master`; manual | Post to LinkedIn, Bluesky, Mastodon after approval |
| `quick-post` | message or button tap to the quick-post Telegram bot | Post a text to LinkedIn, Bluesky, Mastodon; send replies and likes |
| `engagement` | every 10 minutes | Forward Bluesky and Mastodon replies and mentions to Telegram topics |
| `error-alert` | failure in another workflow | Telegram alert with workflow, node, error, execution link |

## Ingest

1. Collect. A push syncs the files it added, changed, or removed. A full sync scans every repo tree. Paths are filtered by `sources.include` and `sources.exclude` in the schema.
2. Normalize. Fetch each file, parse YAML frontmatter, strip MDX imports, components, and comments. Files without frontmatter can get their fields from `path_defaults`.
3. Validate. Check the `context:` block: required fields, values inside the vocabularies, list sizes, fields that only apply to some content types, crafting rules. Files matching a secret pattern are not ingested.
4. Quality gate. Flag errors (block search) and warnings (stale content, stubs). Detect exact duplicates by content hash; a duplicate needs `canonical`. One `review-queue` Issue per document: created, updated, or closed to match the latest check.
5. Store. Delete the document's old chunks, then split the text (1500 characters, 150 overlap), embed with `nomic-embed-text` (768 dimensions), and insert into the Qdrant collection `all_maker_context`. Taxonomy fields go into the payload. Only documents without errors and with `status: published` are stored. A full sync also deletes documents that no longer exist.

## Agent access

`mcp-server` uses the MCP Server Trigger with bearer auth. Tools call `mcp-tools`:

- `search_evidence` embeds the query in Ollama, searches Qdrant with payload filters, and returns titles, URLs, tags, and excerpts. Canonical documents rank above copies.
- `get_document` returns the stored text and tags of one document by `doc_id` (`source:path`).

## Cross-posting

1. A push to all-maker `master` that adds a file under `blog/` starts the run. A manual trigger runs it for one post by path.
2. Wait 10 minutes for the site deploy.
3. Read `context.social` from the frontmatter: one hook for all platforms. Append `Full post: <title>`. Text plus closing line must fit Bluesky's 300 characters.
4. Telegram: post link and a prefilled Hacker News submit link, then one approve/skip message per platform. Approvals expire after 3 days.
5. Post to each approved platform. Bluesky links the title and adds a link card. LinkedIn posts as the owner with an article card. Mastodon gets the URL on the last line.
6. Report the result in Telegram. Missing text, text over the limit, or a failed platform opens a `review-queue` Issue. One platform failing does not stop the others.

## Data and privacy

- Docusaurus copies frontmatter into public JS bundles. Tags and social text on all-maker.com are readable, not rendered. Nothing sensitive goes into frontmatter.
- Review-queue Issues live in this public repo. Issue text holds paths, field names, and error messages, never file content.
- The careers repo is private. Its excluded paths never leave GitHub. Ingested career content is reachable only through the authenticated MCP server.
