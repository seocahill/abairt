# MCP integration (Claude web)

Abairt exposes a [Model Context Protocol](https://modelcontextprotocol.io) server so that
Claude web (and other MCP clients) can act as a **translation assistant** over the whole
corpus: researching entries (confirmed and draft), recordings, speaker/dialect context and
translation history, and saving translations, tags and confirmations back. Access is
authorised with OAuth 2 provided by [Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper)
and is **restricted to admin users** — the assistant sees and edits the entire corpus, so the
admin check is the read boundary; per-record writes are additionally governed by Pundit
policies and every edit is versioned (PaperTrail) and reversible.

## Endpoints

| Purpose | Route |
| --- | --- |
| MCP Streamable HTTP transport | `POST/GET/DELETE /mcp` |
| Protected Resource Metadata (RFC 9728) | `GET /.well-known/oauth-protected-resource` |
| Authorization Server Metadata (RFC 8414) | `GET /.well-known/oauth-authorization-server` |
| Dynamic Client Registration (RFC 7591) | `POST /oauth/register` |
| Authorization / token (Doorkeeper) | `GET /oauth/authorize`, `POST /oauth/token` |

## Authorization flow

1. Claude `POST /mcp` without a token and receives `401` with a
   `WWW-Authenticate: Bearer resource_metadata="…"` header.
2. It fetches the protected-resource and authorization-server metadata documents.
3. It self-registers as a public client via `POST /oauth/register`
   (`token_endpoint_auth_method: "none"`, PKCE).
4. The user is sent through `/oauth/authorize`. If they are not signed in they are bounced
   through the existing magic-link login and returned to the consent screen afterwards.
5. Claude exchanges the code at `/oauth/token` (PKCE, no client secret) and calls `/mcp`
   with the bearer token.

Access tokens carry the `mcp` scope, expire after two hours and are refreshable. The token's
resource owner must be an **admin** user or the `/mcp` endpoint returns `401`.

## Tools

Tools live in `app/mcp/` and are thin adapters over the same models, services and Pundit
policies the rest of the app uses. Each subclasses `ApplicationTool` (which resolves the acting
admin, authorizes writes and serialises responses via the `Mcp::*` Alba serializers) and
registers itself, so `McpController` exposes the full set automatically.

**Read / research**

- `search_dictionary_entries` – full-text search over the whole corpus, with filters (dialect,
  speaker, tag, accuracy status, has-audio).
- `get_dictionary_entry` – a single entry in full detail: translation, dialect, speaker, tags,
  audio, source recording and edit history.
- `list_recent_transcriptions` – most recently updated entries, filterable.
- `context_search` – hybrid keyword + vector similarity search from an English description.
- `get_voice_recording` / `list_voice_recordings` – recordings with segments, dialect region,
  speakers and their entries.
- `get_speaker` / `list_speakers` – user/dialect context and a person's recent entries.
- `list_tags` – the tag vocabulary with usage counts.
- `get_word_list` / `list_word_lists` – curated collections.

**Write (Pundit-gated, versioned)**

- `save_translation` – set/replace a translation (supplied or model-generated). Confirmed
  entries are locked; deconfirm first.
- `create_dictionary_entry` – create a new draft entry.
- `set_entry_accuracy` – confirm / deconfirm an entry.
- `tag_entry` – add/remove tags.
- `create_word_list` / `add_to_word_list` – build and curate collections.

## Connecting from Claude web

Add a custom connector pointing at `https://<host>/mcp`. Claude handles registration and the
OAuth handshake automatically; sign in with your abairt account when prompted.

## Managing clients

Registered OAuth applications are available through Doorkeeper's admin UI at
`/oauth/applications` (admin users only).
