# 0003: GitHub Issues as the review queue

Status: accepted, 2026-10-19

## Context

The quality gate finds missing fields, values outside the vocabulary, duplicates, and stale content. Someone has to fix each finding in the source repo, usually with Claude Code in the IDE. Findings must not pile up as duplicates, and fixed ones must disappear without manual cleanup.

## Decision

Open one GitHub Issue per document in this repo, labeled `review-queue`. A hidden `doc_id` marker in the Issue body links it to its document. Each sync creates, updates, or closes the Issue to match the latest check. Cross-post failures use the same label with a separate marker, so ingest never closes them.

## Alternatives

- Telegram alerts only. Easy to miss, no state, no checklist.
- An n8n data table. Invisible outside n8n and not linked to the code.
- Notion or Linear. Another account and integration for a one-person queue.

## Consequences

- The queue sits next to the code. Issues link to the source file and can be referenced from fix commits.
- Claude Code can read and fix Issues with `gh`.
- This repo is public, so Issues are public. Issue text holds paths, field names, and error messages, never file content.
- The `n8n-review-queue` token needs Issues read/write on this repo only.
