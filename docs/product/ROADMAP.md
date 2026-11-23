# Roadmap

Maintained by the architect (see `ARCHITECT.md`). Owner edits welcome.

## Now (approved / building)

- #133 Re-transcribe safely (flag `f133_retranscribe`): step 1 merged (#205), step 2 in #206 (`ready-to-merge`), steps 3 and 4 to come
- #171 Mutation-aware search (flag `f171_mutation_search`): built in #202, `needs-human` (owner checks the rule table and gives 10 test words)
- #121 Simplify users: steps 1, 2, 4 shipped (#189, #190, #191); step 3 `blocked` on the owner's A/B answer
- #203 Retire features: media imports, data dashboard, ASR quality, island context playground, status (owner's own, approved)
- #188 Recording cards play direct from storage; vendor the CDN JavaScript (approved; vendoring must run outside the sandbox)
- #124 Waveform peaks out of the recording row (approved)
- #181 Tailwind 2 → 4 with a page-by-page visual check (owner's own, `auto`)
- New this week (tier 1 `auto`, ranked): #207 recordings filters under 1 s, #209 Ruby 3.4.13 security upgrade, #210 lighter pages on phones (after #188), #208 cached tag counts

## Next (proposed, awaiting decision)

Nothing tier 3 is waiting. Owner-only actions:
1. Switch off Cloudflare Web Analytics on abairt.com (its beacon is injected into every page; see the 2026-11-23 digest)
2. Optional Cloudflare Cache Rule for `assets.abairt.com` (from #188)
3. Flag rollouts: `f170_search_to_moment`, `f172_place_pages`, `f140_check_mode`, `f121_simple_signup`
4. Flag cleanup due from 2026-11-29 if they've been on for everyone since they shipped: `f81_listening_controls`, `f82_moment_links`, `f125_early_play`, `f126_android_version`

Shipped since last update: #169 search never errors, #170 search to moment, #172 place pages, #152/#183/#184 admin navigation and pages, #121 steps 1, 2, 4, #201 rack-protection security update, #133 step 1. Rejected: #123 asset caching (owner: Cloudflare already does it).

## Later (ideas not yet worth a proposal)

- Pipeline resilience: ASR/TTS calls return `nil` on failure, and only `EmbedDictionaryEntryJob` has `retry_on`. Add retries with backoff, a visible "transcription failed / retrying" state, and alerts when `ServiceStatus` shows abair.ie down. (Lens 1, after #75 so it can be measured.)
- Review throughput: 0 of 8,601 segments in the 20 newest recordings are checked. A fast review queue for unchecked segments, ordered by low ASR confidence once #75 exists. (Lens 3.)
- MCP/API payload size: `list_voice_recordings` (limit 20) returns ~2 MB because every segment is inlined. Return summaries plus a link to segments. (Lens 8.)
- Long-file handling from `TODO.md`: split uploads over ~10 minutes and set an upload size limit. (Lens 3/5.)
- R2 public bucket and Cloudflare CDN for audio, from `TODO.md` "Asset caching": media already plays from `assets.abairt.com`; only the owner's Cache Rule is left (#188). (Lens 5.)
- Upgrade wavesurfer.js 6.2 → current major (v7 rewrite: native regions/peaks API). After #80, so the peaks work carries over. (Lens 2/5.)
- Recording page: `@recording.users.each` runs a `COUNT` per speaker (N+1) in `show.html.erb`; the page is 70–100 ms today, so it's low priority. (Lens 5.)
- `PlacePins` and `recording_pins` run on every recordings-list view (~30 ms); cache them like #208 once #207 lands. (Lens 5.)
- Long recordings without stored peaks (e.g. #200, 79 min) still decode the full file for the waveform; #124 covers it after the owner's test. (Lens 5.)
- Ga/En subtitle toggles only render on the index (`controller.action_name == "index"`); the show page has no way to hide English while listening. Fold into #81 if approved. (Lens 2.)
- Open PRs from the owner, still undecided: #70 (retire learning features, new home page), #57 (radio mode), #49 (speech AI plan).

## Lens log

| Week of | Lens | Proposals |
|---|---|---|
| 2026-11-07 | 1. Transcription pipeline (plus week-one foundations) | #72 Flipper, #73 security scans (auto), #74 analytics, #75 ASR eval/WER |
| 2026-11-08 | 2. Listening experience and mobile UX | #80 fast-start playback (auto), #81 listening controls, #82 moment links + phone header |
| 2026-11-15 | 3. Contributor and editor workflows | #140 check mode, #141 full segment history (auto), #142 training-data progress |
| 2026-11-18 | 4. Search, dictionary and discovery | #169 search never errors (auto), #170 search to moment, #171 mutation-aware search, #172 place pages |
| 2026-11-23 | 5. Performance and media delivery (plus urgent security) | #207 recordings filters under 1 s (auto), #208 cached tag counts (auto), #209 Ruby 3.4.13 RCE fix (auto), #210 lighter pages on phones (auto) |
