# Roadmap

Maintained by the architect (see `ARCHITECT.md`). Owner edits welcome.

## Now (approved / building)

- #73 Security scans in CI: Brakeman, bundler-audit, Dependabot (tier 1 `auto`; the builder can start)

## Next (proposed, awaiting decision)

1. #72 Feature flags: Flipper with an admin-only UI (blocks every visible change)
2. #75 ASR evaluation set and WER/CER report by speaker and dialect (needs the owner to say what counts as ground truth; folds in #36)
3. #74 Privacy-first usage analytics in our own DB (Ahoy, cookieless)

## Later (ideas not yet worth a proposal)

- Pipeline resilience: ASR/TTS calls return `nil` on failure, and only `EmbedDictionaryEntryJob` has `retry_on`. Add retries with backoff, a visible "transcription failed / retrying" state, and alerts when `ServiceStatus` shows abair.ie down. (Lens 1, after #75 so it can be measured.)
- Review throughput: 0 of 8,601 segments in the 20 newest recordings are checked. A fast review queue for unchecked segments, ordered by low ASR confidence once #75 exists. (Lens 3.)
- MCP/API payload size: `list_voice_recordings` (limit 20) returns ~2 MB because every segment is inlined. Return summaries plus a link to segments. (Lens 8.)
- Long-file handling from `TODO.md`: split uploads over ~10 minutes and set an upload size limit. (Lens 3/5.)
- R2 public bucket and Cloudflare CDN for audio, from `TODO.md` "Asset caching". (Lens 5.)
- Open PRs from the owner, still undecided: #70 (retire learning features, new home page), #57 (radio mode), #49 (speech AI plan).

## Lens log

| Week of | Lens | Proposals |
|---|---|---|
| 2026-11-07 | 1. Transcription pipeline (plus week-one foundations) | #72 Flipper, #73 security scans (auto), #74 analytics, #75 ASR eval/WER |
