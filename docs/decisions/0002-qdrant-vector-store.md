# 0002: Qdrant as the vector store

Status: accepted, 2026-10-19

## Context

Agents need semantic search over a few hundred documents, filtered by taxonomy fields such as employer, domain, and content type. Editing a document must replace its old chunks. Embeddings come from Ollama (`nomic-embed-text`, 768 dimensions). The store must run on the same server without exposure to the internet.

## Decision

Use Qdrant in Docker, on an internal network reachable only by n8n, with an API key. One collection, `all_maker_context`. Taxonomy fields go into the point payload. Updates delete points by `doc_id` before inserting the new chunks.

## Alternatives

- pgvector. Requires running Postgres, which the stack does not need yet (see 0001).
- n8n in-memory vector store. Lost on restart.
- Pinecone or another managed service. External account, data leaves the server, paid tiers for larger use.
- Chroma. Works, but payload filtering and the n8n integration are less mature.

## Consequences

- Payload filters make `search_evidence` filters exact, not prompt-based.
- Delete-then-insert by `doc_id` keeps one version of each document.
- Changing the embedding model requires a full re-index. Vectors from different models are not comparable.
- Qdrant data is archived nightly with `n8n_data`.
