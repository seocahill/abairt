# Roadmap

Maintained by the architect (see `ARCHITECT.md`). Owner edits welcome.

## Now (approved / building)

- #73 Security scans in CI: Brakeman, bundler-audit, Dependabot (tier 1 `auto`; the builder can start)
- #77 / PR #79 Deploy fix (Sentry off during image build). Ready to merge; production hasn't deployed since 2026-11-07
- #78 Dependency security updates (2 critical: activestorage, rack-session)
- #80 Fast-start playback on phones: stored waveform peaks, segment clips load on tap (tier 1 `auto`)

## Next (proposed, awaiting decision)

1. #72 Feature flags: Flipper with an admin-only UI (blocks every visible change)
2. #75 ASR evaluation set and WER/CER report by speaker and dialect (needs the owner to say what counts as ground truth; folds in #36)
3. #74 Privacy-first usage analytics in our own DB (Ahoy, cookieless)
4. #81 Listening controls: tap a line to jump, replay/loop a line, keyboard and lock-screen (Media Session) controls (needs #72)
5. #82 Share a link to a moment (`?t=`), compact phone header that credits the speaker, Open Graph previews (needs #72)

## Later (ideas not yet worth a proposal)

- Pipeline resilience: ASR/TTS calls return `nil` on failure, and only `EmbedDictionaryEntryJob` has `retry_on`. Add retries with backoff, a visible "transcription failed / retrying" state, and alerts when `ServiceStatus` shows abair.ie down. (Lens 1, after #75 so it can be measured.)
- Review throughput: 0 of 8,601 segments in the 20 newest recordings are checked. A fast review queue for unchecked segments, ordered by low ASR confidence once #75 exists. (Lens 3.)
- MCP/API payload size: `list_voice_recordings` (limit 20) returns ~2 MB because every segment is inlined. Return summaries plus a link to segments. (Lens 8.)
- Long-file handling from `TODO.md`: split uploads over ~10 minutes and set an upload size limit. (Lens 3/5.)
- R2 public bucket and Cloudflare CDN for audio, from `TODO.md` "Asset caching". (Lens 5.)
- Upgrade wavesurfer.js 6.2 → current major (v7 rewrite: native regions/peaks API). After #80, so the peaks work carries over. (Lens 2/5.)
- Recording page: `@recording.users.each` runs a `COUNT` per speaker (N+1) in `show.html.erb`. (Lens 5.)
- Ga/En subtitle toggles only render on the index (`controller.action_name == "index"`); the show page has no way to hide English while listening. Fold into #81 if approved. (Lens 2.)
- Open PRs from the owner, still undecided: #70 (retire learning features, new home page), #57 (radio mode), #49 (speech AI plan).

## Lens log

| Week of | Lens | Proposals |
|---|---|---|
| 2026-11-07 | 1. Transcription pipeline (plus week-one foundations) | #72 Flipper, #73 security scans (auto), #74 analytics, #75 ASR eval/WER |
| 2026-11-08 | 2. Listening experience and mobile UX | #80 fast-start playback (auto), #81 listening controls, #82 moment links + phone header |
