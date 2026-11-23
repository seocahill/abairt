# Decisions

The owner's yes/no decisions on proposals, newest first. The architect reads
this every run so it learns what the owner wants and doesn't re-propose
rejected ideas. The architect appends entries from issue activity (approved =
`approved` label; rejected = closed with `rejected` label and the owner's
one-line reason as the last comment). The owner can also edit this file
directly to state standing preferences.

## Standing preferences

- Pace: steady, not hectic. A few good changes a week beats many.
- Dialect content is the owner's domain; the app's job is to present it
  brilliantly.
- Ship behind feature flags; merge on green CI; destructive data changes
  always need the owner.
- Dependencies (owner, 2026-11-12): patch bumps merge on green, and minor
  bumps are checked against the changelog and merged. Major bumps are prepared
  by the builder with every change the upgrade needs and tests added where
  missing; dev and test-only dependencies and GitHub Actions then merge if the
  suite is green, and everything else waits for the owner's review.
- Autopilot (owner, 2026-11-12): the architect proposes, the builder builds
  and merges, and the owner only intervenes occasionally. Visible changes
  are built without approval and ship dark behind a flag; the owner
  switches flags on. Only these wait for the owner's yes: ASR, translation
  or TTS provider or model changes, new third-party services, anything
  costing money, new data collection about listeners or speakers, auth and
  roles, destructive data changes, and anything needing the owner's answer.
- Abairt is the corpus; the Mayo Irish course (mayo-irish-app) does the
  teaching (see #70). Learning features (quizzes, spaced repetition, word
  lists, progress tracking) belong in the course, not here.

- No analytics or tracking of listeners, of any kind, including first-party and cookieless (owner, 2026-11-14, #74). Do not re-propose; use the corpus, Sentry and the code as evidence instead.
- Compression and static asset caching are Cloudflare's job: production already serves gzip/br/zstd and caches fingerprinted assets at the edge (owner, 2026-11-22, #123). Don't propose app-level compression or asset caching again.
- Sign-in stays magic link; a password is optional on top (owner, 2026-11-22, #121). New accounts still wait for admin approval.
- Major front-end upgrades (Tailwind and the like) must follow the upgrade guide and be checked page by page for visual or functional regressions. Modernising the layout to current primitives is welcome if it stays as functional (owner, 2026-11-22, #181).
- Tidy-up phase: retire features with no residual value rather than polish them (owner, 2026-11-23, #203).
- The "never write Irish forms" rule was read too strictly for language rules the app needs, such as the mutation table in #171: the owner let the builder encode it for review in the PR and may narrow the rule's wording (owner, 2026-11-22, #171). Corpus content (transcriptions, translations, glosses, dictionary entries) is still never written by agents.

## Log

<!-- - YYYY-MM-DD #<issue> <title> — approved | rejected: <reason> -->
- 2026-11-23 #203 Retire features (media imports, data dashboard, ASR quality, island context playground, status) — approved (owner's own issue)
- 2026-11-22 #188 Recording cards play direct from storage, and vendor the CDN JavaScript — approved (owner's follow-up to #123)
- 2026-11-22 #121 Simplify users: minimal listener signup, listener/speaker/admin split — approved (steps 1, 2 and 4 shipped; step 3 waits on the owner's A/B answer)
- 2026-11-22 #133 Re-transcribe a recording safely, never overwrite — approved
- 2026-11-22 #124 Waveform peaks out of the recording row, served as a cached file — approved
- 2026-11-22 #123 Asset caching: compression, vendored JavaScript, long-lived media — rejected: "Cloudflare already handles compression and asset caching (checked against production on 2026-11-22)"
- 2026-11-15 #74 Privacy-first usage analytics, in our own database (Ahoy, cookieless) — rejected: "no tracking please" (owner, 2026-11-14)
- 2026-11-15 #75 ASR evaluation set and WER/CER report by speaker and dialect — approved (shipped, PR #139)
- 2026-11-15 #130 Remove flowbite lib — approved (blocked on the owner's answer about form and accordion styling)
