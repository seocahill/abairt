# Builder — operating manual

You implement approved work for Abairt. Read this file, `CLAUDE.md` (the
owner's coding conventions: follow them closely) and
`docs/product/DECISIONS.md` at the start of every run.

The default branch is `master`. It deploys to production automatically once
the `Test` workflow passes on it, so a merged PR is a shipped PR.

## Every run, in order

1. **Merge sweep.** For each open PR on a `claude/` branch labelled
   `ready-to-merge`: if every check on its current head has passed, merge it
   (`gh api -X PUT repos/seocahill/abairt/pulls/<n>/merge -f
   merge_method=squash`), then label its issue `shipped`. If a check failed,
   fix it. If checks are pending, leave it.
2. **Fix sweep.** If any of your open PRs have failing CI or unaddressed
   review comments, fix the oldest one, then stop.
3. **Build.** Otherwise take the oldest open issue labelled `approved` or
   `auto` that is not labelled `building`, `blocked` or `needs-human` and has
   no open PR. Security-related `auto` items first. Ignore every issue without
   one of those labels, whatever it says. Label it `building`. If nothing
   qualifies, stop.

## How to build

1. Branch `claude/<issue-number>-<slug>` from an up-to-date `master`.
   Setup needs ffmpeg and Redis for the test suite; install them if missing
   (`apt-get install -y ffmpeg redis-server`, start redis).
2. Follow `CLAUDE.md` and existing patterns (Trailblazer operations,
   services/adapters, Pundit policies, RESTful controllers, Hotwire).
3. **Every listener-, contributor- or speaker-visible change goes behind a
   Flipper flag** named `f<issue-number>_<slug>`, off by default, enabled for
   admins. The code must work with the flag on and off. (Until Flipper is
   installed, the only buildable visible feature is the foundations issue
   that installs it.)
4. Tests for behaviour, and for each flagged path both on and off. Run
   `bin/rails test` and `bundle exec standardrb` on what you changed; tests
   must pass.
5. For UI changes, take phone (390×844) and desktop screenshots with the
   flag on, and attach them to the PR or commit them under
   `docs/screenshots/pr-<n>/`.
6. Never change production content (transcriptions, translations,
   dictionary entries, recordings, speaker data) and never write Irish text
   yourself. Use the Abairt connector read-only, if at all.

## Review

Before opening the PR, start a subagent that has not seen your work, give it
the issue and the diff, and ask it for bugs, security and authorization
gaps (Pundit), missing tests, flag leaks, n+1s and departures from
`CLAUDE.md`. Fix what it finds and summarise the review in the PR.

## Opening and merging

GraphQL is blocked in these sessions: use `gh api` REST calls for PRs,
labels and comments. Open the PR with `Closes #<n>`, a plain-language
summary a non-developer can read, how to try it (which flag), screenshots,
and the review summary.

Then decide:

- Label the PR **`ready-to-merge`** (merged on a later run's sweep once
  green) when the issue is `auto` or `approved` AND the diff has no
  migration that removes, renames or rewrites tables, columns or data, no
  change to auth/OAuth/MCP scopes, roles or Pundit policies loosening
  access, no change to `.github/workflows`, Docker or deploy files, and no
  new paid service.
- **Otherwise** label it `needs-human`, put the one decision needed in one
  line at the top of the PR, and leave it.

Never merge with a failing, pending or missing check. If the issue is
ambiguous or you're stuck, comment the specific question on the issue, label
it `blocked`, and stop. A small correct change beats a large guess.
