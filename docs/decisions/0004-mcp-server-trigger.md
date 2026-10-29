# 0004: MCP Server Trigger for agent access

Status: accepted, 2026-10-20

## Context

AI agents need to search the stored content and read single documents. Claude Code and Claude Desktop speak MCP. Retrieval logic (query embedding, payload filters, ranking canonical documents first) already lives in n8n next to the data.

## Decision

Use n8n's MCP Server Trigger in workflow `mcp-server`, with bearer auth, at `https://n8n.all-maker.com/mcp/all-maker-context`. It exposes two tools, `search_evidence` and `get_document`. Both call workflow `mcp-tools`, which holds the logic. Clients read the token from the `ALL_MAKER_MCP_TOKEN` environment variable; `.mcp.json` references the variable, never the value.

## Alternatives

- A standalone MCP server in Node or Python. Another service to build, deploy, and secure.
- The official Qdrant MCP server. Exposes the vector store directly, without taxonomy filters or ranking, and would need Qdrant on a public network.
- A plain webhook API. Works, but every agent would need custom tool definitions.

## Consequences

- No extra service. The endpoint shares Caddy, HTTPS, and n8n's process.
- Tool descriptions are written in n8n and are the contract with agents. Changes there change agent behavior.
- One shared token. Rotation means updating the n8n credential and every client.
- claude.ai web connectors have known issues with self-hosted n8n MCP endpoints. Use Claude Code or another client that supports HTTP transport with custom headers.
