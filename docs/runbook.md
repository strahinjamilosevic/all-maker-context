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

No paid AI API is used. Tags and social text are written in the source repos with Claude Code. Ollama runs the embedding model on this server; no external account, no per-use cost.

Pull the embedding model once after the first `docker compose up -d`:

1. `docker compose exec ollama ollama pull nomic-embed-text`
2. Expect download progress, then `success`.
3. Verify: `docker compose exec ollama ollama list` shows `nomic-embed-text:latest`.

The model lives in the `ollama_models` volume and survives restarts. Changing the embedding model requires re-indexing Qdrant: vectors from different models are not comparable.

## Credentials and expiry

| Item | Where stored | Expires |
|---|---|---|
| GitHub PAT `n8n-sources` (all-maker, strahinjamilosevic, career: Contents read, Webhooks read/write) | n8n credential `GitHub sources (read)` | 2027-01-18 |
| GitHub PAT `n8n-review-queue` (all-maker-context: Contents read, Issues read/write) | n8n credential `GitHub review queue` | 2027-01-18 |
| Telegram bot token (@Allmaker_publish_bot) | n8n credential `Telegram approvals` + password manager | none |
| Telegram bot token (quick-post bot) | n8n credential `Telegram quick-post` + password manager | none; revoke in @BotFather if leaked |
| `N8N_ENCRYPTION_KEY` | `.env` + password manager | never rotate without a migration plan |
| `QDRANT_API_KEY` | `.env` + n8n credential | none |
| MCP bearer token | n8n credential `MCP bearer token` + password manager + `ALL_MAKER_MCP_TOKEN` on clients | none; rotate if leaked |
| Bluesky app password `n8n` (replaced the main password on 2026-10-29) | n8n credential `Bluesky app password` + password manager | none; revoke in Bluesky if leaked |
| LinkedIn app `all-maker-context` (Client ID, Client Secret) | n8n credential `LinkedIn` + password manager | access token after 60 days: reconnect |
| Mastodon access token (app `all-maker-context-2`, scopes `read:notifications`, `read:statuses`, `write:statuses`, `write:favourites`) | n8n credential `Mastodon token` + password manager | none; revoke in Mastodon if leaked |

## Rotate the GitHub tokens

Both tokens expire on the date above. Two weeks before:

1. GitHub > Settings > Developer settings > Fine-grained tokens. Open the token, click **Regenerate token**, keep the same expiry length.
2. n8n > Credentials. Open the matching credential, paste the new token, save. Expect "Connection tested successfully".
3. Update the expiry date in this table and commit.

## Error alerts

Workflow `error-alert` (`workflows/error-alert.json`) sends a Telegram message to @Allmaker_publish_bot's chat when a connected workflow fails: workflow, node, error, execution link. It must be published to be selectable.

Connect a new workflow: open it, **Settings** > **Error Workflow** > `error-alert`, and set **Timeout Workflow** to 15 minutes. `ingest` is connected.

## MCP server

Endpoint: `https://n8n.all-maker.com/mcp/all-maker-context`. Workflows `mcp-server` (trigger and tools) and `mcp-tools` (logic). Both must be published.

Auth: bearer token in n8n credential `MCP bearer token` and in the password manager. Clients read it from the environment variable `ALL_MAKER_MCP_TOKEN`; `.mcp.json` in this repo references the variable, never the value.

Rotate the token: generate a new one (`openssl rand -hex 32`), update the n8n credential, update `ALL_MAKER_MCP_TOKEN` on each client machine, restart the clients.

## Cross-posting

Workflow `cross-post` (`workflows/cross-post.json`). Trigger: a push to `master` in all-maker that adds a file under `blog/`. It waits 10 minutes for the site deploy, sends the post link and a Hacker News submit link to Telegram, then asks for approval per platform. The text comes from `context.social` in the post frontmatter: one string, used on every platform, with `Full post: <title>` appended. No text, a text over Bluesky's limit, or a failed post opens a `review-queue` Issue.

Platforms: LinkedIn, Bluesky, Mastodon (@strahinjamilosevic@mastodon.social). Approvals expire after 3 days; an expired approval counts as Skip.
Post one specific post by hand: open `cross-post`, set the path in **Post path** (for example `blog/2026-10-12-coding-is-harder.md`), click the orange **Execute workflow** button next to the **Run for one post** node. The small play icon in the node's hover toolbar runs that node only. A push that adds several posts handles the first; the Telegram message names the others.

Do not set a Timeout Workflow on `cross-post`: it waits for approvals.

Reconnect LinkedIn: the access token expires after 60 days and n8n cannot refresh it. Posts then fail with an authorization error and an Issue opens. n8n > Credentials > `LinkedIn` > **Reconnect**, sign in, save.

## Quick posting and replies

Two workflows and one Telegram bot (the quick-post bot), in a private Telegram group `all-maker social` with Topics turned on:

| Topic | What happens there |
|---|---|
| Compose | Send a text: it becomes a post on LinkedIn, Bluesky, and Mastodon after you tap **Post to all 3**. |
| Bluesky | New replies, mentions, and quotes on Bluesky, one message each. |
| Mastodon | New mentions on Mastodon (replies to your posts arrive as mentions), one message each. |

LinkedIn has no topic. Its API does not let new apps read comments: answer LinkedIn comments in the LinkedIn app.

`quick-post` (`workflows/quick-post.json`) holds the bot's only trigger. Telegram delivers a bot's messages to one webhook, so every message and button tap for the bot lands there. `engagement` (`workflows/engagement.json`) checks Bluesky and Mastodon every 10 minutes and posts new notifications into the topics.

New post:

- Send the text in Compose (or in the bot's private chat). The bot replies with a preview and **Post to all 3** / **Cancel**.
- Limit: 300 characters, Bluesky's limit. A link counts as its short form, at most 30 characters. Over the limit: the bot says by how much and posts nothing.
- The first https link gets a link card on all three platforms. Bluesky shows links shortened and clickable.
- Text only. A photo or file is refused.

Reply and like:

- Swipe left on a notification (or long-press > **Reply**) and type the answer. The bot replies with a preview and **Send reply** / **Cancel**. The reply goes to that post, on that platform.
- Mastodon replies start with the author's `@handle`; the bot adds it if missing. A reply is never more public than the post it answers: a reply to a private mention stays private.
- **Like** on a notification likes the post on that platform.
- Each notification shows the post it answers (`Re: ...`) and an **Open on ...** link. Do not edit or delete notifications: the link is how a reply finds its target.

Rules for both:

- Each button works once. A second tap or a tap after Cancel answers "Already handled". To fix a typo, tap Cancel and send the corrected text.
- Only the owner's Telegram user ID (8199050777) is accepted. Messages from anyone else are dropped without a reply.
- A failed platform shows as `FAILED` with the error in the result message. On a new post, the other platforms still post.
- Static data (the record of handled buttons and the last notification seen) is kept only in published runs. Buttons tapped during a manual test run are not remembered.
- Bluesky allows 300 logins a day. `engagement` logs in 144 times a day. Do not poll more often than every 10 minutes.

### Set up the bot and the group

1. Telegram on your phone: open @BotFather, send `/newbot`. Name: `all-maker quick post`. Username: any free name ending in `bot`, for example `Allmaker_post_bot`. BotFather replies with a token like `123456789:AA...`. Save it in your password manager.
2. Open the new bot's chat and tap **Start**. Nothing answers yet.
3. Telegram: **New Group**. Name: `all-maker social`. Add the new bot as the only member. Create.
4. Group > **Edit** (pencil) > **Topics**: on. Expected: the group now shows a topic list with **General**.
5. Group > **Edit** > **Administrators** > **Add Admin** > the bot. Leave the default rights, save. An admin bot receives every message in the group; a regular member bot does not.
6. Group > **Edit** > **Administrators** > yourself: **Remain Anonymous** must be off. Anonymous messages hide your user ID and the bot drops them.
7. Create three topics (topic list > **Create Topic**): `Compose`, `Bluesky`, `Mastodon`.
8. @BotFather: send `/setjoingroups`, pick the bot, choose **Disable**. The bot stays in this group; nobody can add it to another.

### Mastodon token

`engagement` reads notifications; the current token only posts. Create one token with all needed scopes and put it in the existing credential. `cross-post` keeps working with it.

1. https://mastodon.social > **Preferences** > **Development** > **New application**. Name: `all-maker-context-2`. Scopes: untick `read`, `write`, `follow`; tick `read:notifications`, `read:statuses`, `write:statuses`, `write:favourites`. Submit.
2. Open the application, copy **Your access token**. Save it in your password manager.
3. n8n > **Credentials** > `Mastodon token` > Value: `Bearer <token>` (same format as before). Save.
4. Back in Mastodon > **Development**: delete the old application `all-maker-context`. This revokes the old token.

### Set up the workflows

1. n8n (https://n8n.all-maker.com) > **Credentials** > **Add credential** > **Telegram API**. Name: `Telegram quick-post`. Access Token: the token from step 1 of the bot setup. Save. Expected: "Connection tested successfully".
2. n8n > **Workflows** > **Create workflow**. Top-right **...** menu > **Import from File** > select `C:\Repositories\all-maker-context\workflows\quick-post.json`. Expected: 34 nodes and a sticky note. If an earlier `quick-post` exists, delete it first.
3. Open every Telegram node (On Telegram message, Send preview, Send reply preview, Answer: posting, Send result, Answer: sending, Send engage result, Answer button, Send reply) and set **Credential** to `Telegram quick-post`. LinkedIn, Bluesky, and Mastodon nodes keep their existing credentials.
4. Check the nodes the import may not fill in:
   - **Send preview**: **Reply Markup** = Inline Keyboard, one row: `Post to all 3` (Callback Data `post`), `Cancel` (Callback Data `cancel`).
   - **Send reply preview**: same, with `Send reply` (`reply`) and `Cancel` (`cancel`). **Parse Mode** = HTML.
   - **Answer: posting**, **Answer: sending**, **Answer button**: **Resource** = Callback, **Operation** = Answer Query, **Query ID** = `{{ $json.query_id }}`.
5. Workflow **...** menu > **Settings**: **Error Workflow** = `error-alert`, **Timeout Workflow** on, 15 minutes. Save. Click **Publish**.
6. In the Telegram group, send `/ids` in each of the three topics. Expected: `Chat ID: -100...` and `Topic ID: <number>`. Note the chat ID and the Bluesky and Mastodon topic IDs.
7. Import `C:\Repositories\all-maker-context\workflows\engagement.json` the same way. Expected: 14 nodes and a sticky note.
8. **Config** node: check `group_chat_id`, `bluesky_topic_id`, `mastodon_topic_id` against the values from step 6. The committed file has `-1003986483509`, `4`, `6`.
9. **Send to topic** node: **Credential** = `Telegram quick-post`. Check **Reply Markup** = Inline Keyboard with one button `Like` (Callback Data `like`), **Parse Mode** = HTML, **Message Thread ID** = `{{ $json.topic_id }}`.
10. **Settings**: **Error Workflow** = `error-alert`, **Timeout Workflow** on, 5 minutes. Save. Click **Publish**.

### Test

From your phone, in the group:

1. Compose: send `/start`. Expected: the help text.
2. Compose: send 320 times the letter a. Expected: "Too long for Bluesky: 320 of 300 characters. Shorten by 20."
3. Compose: send `Test`, tap **Cancel**. Expected: "Cancelled. Nothing was sent." Tap **Cancel** again: "Already handled."
4. From another account (or ask someone), reply to one of your Bluesky posts. Within 10 minutes, expected: a message in the Bluesky topic with the reply, `Re: <your post>`, and **Open on Bluesky**.
5. Swipe-reply to that message with `Thanks`, tap **Send reply**. Expected: "Replied on Bluesky." with a link. Open it: the reply sits under the right post.
6. Repeat 4 and 5 for Mastodon. Test **Like** on one notification.
7. First real post: send it in Compose, tap **Post to all 3**. Expected: `posted` per platform, with Bluesky and Mastodon links. Check the text and link card on each.
8. Export both workflows: **...** menu > **Download**. Replace the files in `workflows/`, check them for secrets (credential IDs and names are fine, tokens are not), commit.

## Daily operations

Status: `docker compose ps`. All four services (caddy, n8n, ollama, qdrant) show `Up`.

Logs: `docker compose logs -f n8n` (or `caddy`, `qdrant`, `ollama`). Ctrl+C to exit.

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

- Bluesky node fails with `AuthFactorTokenRequired` ("A sign in code has been sent to your email"): the `Bluesky app password` credential holds the account password. Create an app password (Bluesky > Settings > Privacy and security > App passwords) and put it in the credential's `password` field.
- A Telegram button tap does nothing and `quick-post` shows no new execution: the trigger dropped it. Do not set **Restrict to User IDs** on **On Telegram message**; it drops button taps. **Route** checks the user ID.
- Browser shows a certificate error: `docker compose logs caddy`. Check the DNS A record points to this server and ports 80/443 are open in the Hetzner firewall.
- n8n reachable but webhooks fail: check `WEBHOOK_URL` in `.env` ends with `/`.
- n8n cannot reach Qdrant: the credential URL must be `http://qdrant:6333`, not `localhost`.
- Docker bypasses `ufw` for published ports. Only Caddy publishes ports. Do not add `ports:` to n8n or Qdrant.
