# MCP integration (Claude web)

Abairt exposes a [Model Context Protocol](https://modelcontextprotocol.io) server so that
Claude web (and other MCP clients) can search and read the confirmed dictionary/transcription
corpus. Access is authorised with OAuth 2 provided by [Doorkeeper](https://github.com/doorkeeper-gem/doorkeeper).

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

Access tokens carry the `mcp` scope, expire after two hours and are refreshable.

## Tools

Tools live in `app/mcp/` and read only confirmed (`accuracy_status: confirmed`) data:

- `search_dictionary_entries` – full-text search over Irish words/phrases and translations.
- `get_dictionary_entry` – fetch a single entry (translation, dialect, speaker, audio URL).
- `list_recent_transcriptions` – most recently updated confirmed transcriptions.

## Connecting from Claude web

Add a custom connector pointing at `https://<host>/mcp`. Claude handles registration and the
OAuth handshake automatically; sign in with your abairt account when prompted.

## Managing clients

Registered OAuth applications are available through Doorkeeper's admin UI at
`/oauth/applications` (admin users only).
