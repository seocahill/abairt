# Roadmap

Maintained by the architect (see `ARCHITECT.md`). Owner edits welcome.

## Now (approved / building)

- #73 Security scans in CI: Brakeman, bundler-audit, Dependabot (tier 1 `auto`; the builder can start)
- #77 / PR #79 Deploy fix (Sentry off during image build). Ready to merge; production hasn't deployed since 2026-11-07
- #78 Dependency security updates (2 critical: activestorage, rack-session)
- #80 Fast-start playback on phones: stored waveform peaks, segment clips load on tap (tier 1 `auto`)

- #140 Check mode: step through unchecked lines, confirm-and-next (tier 2, flag `f140_check_mode`)
- #141 Keep every version of a segment, including original ASR text (tier 1 `auto`)
- #142 Training-data progress report per speaker (tier 2, flag `f142_training_progress`)
- #169 Dictionary search must never error: shared query sanitiser (tier 1 `auto`)
- #170 Search results open the recording at the matching line, plus search inside a transcript (tier 2, flag `f170_search_to_moment`)
- #171 Mutation-aware Irish search: root forms find lenited/eclipsed forms (tier 2, flag `f171_mutation_search`)
- #172 Place pages: browse recordings and speakers by place (tier 2, flag `f172_place_pages`)
- #123 Asset caching (PR #135 in review; vendoring CDN JS still needs `bin/importmap pin --download` run outside the sandbox)

## Next (proposed, awaiting decision)

1. #133 Re-transcribe safely: candidates compared with current entries (owner decisions recorded on the issue)
2. #124 Waveform peaks out of the recording row, cached file (waiting for the owner's test on the longest recordings)
3. #121 Simplify users: listener signup, listener/speaker/admin split (tier 3, needs the owner)
4. #130 Remove flowbite (blocked on the owner's answer about form styling)

Shipped since last update: #72 flags, #73 security scans, #75 ASR eval, #80 fast start, #81 listening controls, #82 moment links, #125 early play, #126 Android version. Rejected: #74 analytics (owner: no tracking).

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
| 2026-11-15 | 3. Contributor and editor workflows | #140 check mode, #141 full segment history (auto), #142 training-data progress |
| 2026-11-18 | 4. Search, dictionary and discovery | #169 search never errors (auto), #170 search to moment, #171 mutation-aware search, #172 place pages |
