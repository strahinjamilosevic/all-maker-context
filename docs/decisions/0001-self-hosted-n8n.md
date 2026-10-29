# 0001: Self-hosted n8n

Status: accepted, 2026-10-19

## Context

The pipeline needs scheduled and webhook-driven workflows, GitHub and Telegram integrations, a vector store connection, and an MCP endpoint. It also needs a local embedding model, because no paid AI API is allowed. Running and operating the stack is a goal of the project, not overhead.

## Decision

Run n8n Community Edition with Docker Compose on one Hetzner Cloud VPS, next to Qdrant, Ollama, and Caddy. Use SQLite as the n8n database. Pin every image version.

## Alternatives

- n8n Cloud. No server to run. It cannot reach a private Qdrant or Ollama without exposing them, and the monthly price exceeds the VPS.
- Scripts and GitHub Actions. No UI, no approval step, no MCP trigger. Each integration would be custom code.
- Postgres instead of SQLite. More robust under concurrent load. Not needed for a single user and a few hundred documents.

## Consequences

- Operations are on the owner: OS updates, image upgrades, backups, certificates, firewall. The runbook covers each.
- `N8N_ENCRYPTION_KEY` must be kept. Without it, stored credentials cannot be read.
- One server is a single point of failure. Hetzner backups and nightly volume archives are the recovery path.
- Move to Postgres if executions grow, queue mode is needed, or SQLite locking shows up in the logs.
