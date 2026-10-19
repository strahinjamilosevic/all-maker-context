# Runbook

All commands run on the server as `deploy`, in `~/all-maker-context`, unless stated otherwise.

## Versions

| Component | Image | Pinned on |
|---|---|---|
| n8n | `docker.n8n.io/n8nio/n8n:2.43.8` | 2026-10-19 |
| Qdrant | `qdrant/qdrant:v1.19.2` | 2026-10-19 |
| Caddy | `caddy:2.11.7` | 2026-10-19 |
| Ollama | `ollama/ollama:0.40.6` | 2026-10-19 |
| Embedding model | `nomic-embed-text` (768 dimensions) | 2026-10-19 |
| Backup helper | `alpine:3.22` | 2026-10-19 |

## AI models

Claude (Anthropic API) tags documents and drafts LinkedIn posts. Ollama runs the embedding model on this server; no external account.

Pull the embedding model once after the first `docker compose up -d`:

1. `docker compose exec ollama ollama pull nomic-embed-text`
2. Expect download progress, then `success`.
3. Verify: `docker compose exec ollama ollama list` shows `nomic-embed-text:latest`.

The model lives in the `ollama_models` volume and survives restarts. Changing the embedding model requires re-indexing Qdrant: vectors from different models are not comparable.

## Credentials and expiry

| Item | Where stored | Expires |
|---|---|---|
| GitHub fine-grained PAT | n8n credential | YYYY-MM-DD (fill in) |
| Anthropic API key | n8n credential | none |
| Telegram bot token | n8n credential | none |
| `N8N_ENCRYPTION_KEY` | `.env` + password manager | never rotate without a migration plan |
| `QDRANT_API_KEY` | `.env` + n8n credential | none |

## Daily operations

Status: `docker compose ps`. All three services show `running`.

Logs: `docker compose logs -f n8n` (or `caddy`, `qdrant`). Ctrl+C to exit.

Restart one service: `docker compose restart n8n`.

Restart everything: `docker compose down && docker compose up -d`. Volumes are kept.

## Upgrade an image

1. Run a backup: `./scripts/backup.sh`.
2. Read the release notes for breaking changes.
3. Change the tag in `docker-compose.yml`, commit, push.
4. On the server: `git pull && docker compose pull && docker compose up -d`.
5. Check `docker compose logs n8n` for migration errors. Update the table above.

## Backups

`scripts/backup.sh` archives `n8n_data` and `qdrant_data` to `~/backups`, keeping 7 days. It pauses n8n and Qdrant for a few seconds; webhooks arriving in that window fail and GitHub retries them.

Install the cron job once:

1. `mkdir -p ~/backups`
2. `crontab -e` (choose nano if asked).
3. Add the line: `0 3 * * * /home/deploy/all-maker-context/scripts/backup.sh >> /home/deploy/backups/backup.log 2>&1`
4. Save. Verify: `crontab -l` prints the line.

Test it now: `./scripts/backup.sh`, then `ls -lh ~/backups`. Expect two `.tar.gz` files with today's timestamp.

These archives live on the same server. Hetzner server backups are the off-machine copy. `.env` is not archived; the password manager is its backup.

## Restore

Restoring overwrites the current volume contents. Confirm the archive timestamp first.

1. `docker compose down`
2. Set the stamp: `STAMP=20261019-030000` (from `ls ~/backups`).
3. Restore n8n:
   `docker run --rm -v n8n_data:/target -v ~/backups:/backup alpine:3.22 sh -c "find /target -mindepth 1 -delete && tar xzf /backup/n8n_data-$STAMP.tar.gz -C /target"`
4. Restore Qdrant: same command with `qdrant_data` in both places.
5. `docker compose up -d`, then `docker compose logs n8n`. Log in and confirm workflows and credentials are present.

A restored `n8n_data` only works with the same `N8N_ENCRYPTION_KEY` it was created with.

## Troubleshooting

- Browser shows a certificate error: `docker compose logs caddy`. Check the DNS A record points to this server and ports 80/443 are open in the Hetzner firewall.
- n8n reachable but webhooks fail: check `WEBHOOK_URL` in `.env` ends with `/`.
- n8n cannot reach Qdrant: the credential URL must be `http://qdrant:6333`, not `localhost`.
- Docker bypasses `ufw` for published ports. Only Caddy publishes ports. Do not add `ports:` to n8n or Qdrant.
