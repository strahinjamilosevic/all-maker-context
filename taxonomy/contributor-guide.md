# Contributor guide

How to tag content so the context layer can ingest it. The vocabulary lives in [schema.yaml](schema.yaml). This guide explains how to use it.

## Principles

- Tag at the source. Tags are written in frontmatter when content is written, and reviewed with it.
- n8n validates tags. It never invents them.
- One authoritative copy per fact. A restatement points to the original with `canonical`.
- Only values from `schema.yaml`. A missing value is proposed, not improvised.

## Where tags go

All taxonomy fields sit under one frontmatter key, `context`. Site fields such as `title`, `tags`, `slug`, and `sidebar_position` stay where they are and keep working.

```yaml
---
title: Docs as code, not dev
tags: [opinion, technical writing]    # Docusaurus tags: site navigation, unchanged
context:                              # taxonomy: governance and agent search
  content_type: blog_post
  domain: [technical_writing, docs_strategy]
  status: published
---
```

Docusaurus `tags` and `context.tags` are separate. The first builds site pages. The second is the controlled taxonomy.

`profile/facts.yaml` cannot hold frontmatter, and `linkedin/*.md` is pasted into LinkedIn as-is. Their fields come from `path_defaults` in the schema, and their review date is their last commit date.

## Fields

| Field | Required | Values | Notes |
|---|---|---|---|
| `content_type` | yes | see below | One per document. |
| `domain` | yes | 1 to 3 from the list | What the content is about. |
| `status` | yes | `published`, `draft`, `stub` | Stubs reach the review queue but not search. |
| `employer` | for `case_study`, `achievement` | `bitvavo`, `adyen`, `proglove`, `blackrock`, `ncr`, `none` | `blackrock` covers eFront, acquired by BlackRock. |
| `last_reviewed` | when the type has a freshness limit | `YYYY-MM-DD` | Date a person last confirmed the content is accurate. |
| `skills` | no | up to 8 | Practices the content demonstrates. |
| `tools` | no, not on blog posts | up to 12 | Tools the content uses or discusses. Blog posts carry ideas, not tool inventories. |
| `tags` | crafting only | `crafting` + `metalworking`, `leatherworking`, or `cooking` | One craft per page. Overview pages list every craft they cover. |
| `canonical` | for restatements | `<source>:<path>`, or a list | Points to the authoritative copy, or copies. |
| `social` | no, blog posts only | one string | Cross-post text, used on every platform. |

## Content types

| `content_type` | Where it lives | Freshness |
|---|---|---|
| `blog_post` | all-maker `blog/` | never stale |
| `guide` | all-maker `docs/resources/` | 365 days |
| `craft_log` | all-maker `docs/` crafting sections | never stale |
| `case_study` | portfolio `projects/` | 365 days |
| `profile_page` | portfolio home, experience, skills, education, contact | 180 days |
| `achievement` | career `profile/achievements/` | 180 days |
| `social_profile` | career `linkedin/` | 180 days |
| `profile_data` | career `profile/facts.yaml` | 90 days |

A document past its freshness limit opens a review-queue Issue. Review it, update it if needed, and set `last_reviewed` to today.

## Templates

### Blog post

```yaml
context:
  content_type: blog_post
  domain: [technical_writing]
  status: published
  social: "One to three short sentences. The hook."
```

Social text: one hook for LinkedIn, Bluesky, and Mastodon. Short declaratives. No link, no emojis, no hashtag lists. The cross-post workflow appends:

```
Full post: <post title>
```

On Bluesky the title links to the post. LinkedIn shows a link card under the post. Mastodon gets the URL on the next line.

Length: Bluesky is the strictest platform. The hook plus the closing line must fit 300 characters, so the hook gets 287 minus the title length. A 25-character title leaves 262. Over the limit, nothing is posted and a review-queue Issue gives the exact number to cut.

### Guide

```yaml
context:
  content_type: guide
  domain: [api_docs, content_governance]
  status: published
  last_reviewed: 2026-10-19
  skills: [api_governance]
```

### Craft log

```yaml
context:
  content_type: craft_log
  domain: [crafting]
  tags: [crafting, metalworking]
  status: published
```

### Case study

```yaml
context:
  content_type: case_study
  domain: [api_docs, docs_platform]
  employer: bitvavo
  status: published
  last_reviewed: 2026-10-19
  skills: [api_documentation, docs_platform_setup]
  tools: [docusaurus, openapi, asyncapi]
```

### Achievement

```yaml
context:
  content_type: achievement
  domain: [career]
  employer: adyen
  status: published
  last_reviewed: 2026-10-19
  canonical:
    - portfolio:projects/adyen-terminal-api-reference.mdx
    - portfolio:projects/adyen-in-person-payments-overhaul.mdx
```

Use `canonical` when the achievement restates published case studies. Search then returns the case studies first. Leave it out when the achievement holds facts found nowhere else.

### Profile page and social profile

```yaml
context:
  content_type: profile_page   # or social_profile
  domain: [career]
  status: published
  last_reviewed: 2026-10-19
```

## Tag with Claude Code

1. Open the source repo in VS Code.
2. Ask Claude Code: "Tag `<file>` using the all-maker-context taxonomy." Point it to this guide and `schema.yaml`.
3. Review the frontmatter it proposes. Correct anything that misrepresents the content.
4. Commit and push. n8n validates on the next ingest.

For a review-queue Issue: open the Issue, open the file it names, ask Claude Code to fix what the Issue lists, then close the Issue with the commit.

## Propose a new value

1. Open an Issue in all-maker-context with the label `taxonomy`.
2. State the value, the field, two or more documents that need it, and why no existing value fits.
3. If accepted: add the value to `schema.yaml`, bump `version`, and note the change in the commit message.

A value used by one document only is not added. Use the closest existing value.

## What is never ingested

- Credentials: passwords, API keys, tokens. Any file matching `secret_patterns` is skipped and reported.
- `profile/application_answers.yaml` (salary, date of birth, diversity answers).
- `jobs/`, config files, and tooling folders. See `sources` in the schema.
