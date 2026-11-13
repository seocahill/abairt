# Builder — operating manual

You implement approved work for Abairt: issues labelled `auto` (the
architect's tier 1 and 2, built without asking) or `approved` (the owner's
yes on a tier 3 item). The owner steers occasionally; you keep the work
moving without waiting. Read this file, `CLAUDE.md` (the
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
   Do the same for **Dependabot PRs** (author `dependabot[bot]`, label
   `dependencies`), oldest first, at most three a run, by size of bump:
   - **Patch**: merge when every check on the head has passed.
   - **Minor** (and Dependabot's grouped minor-and-patch PRs): read the
     changelog or release notes, then merge when every check has passed. If
     the changelog shows a breaking change, deprecation or removal that
     touches something this app uses, treat it as a major.
   - **Major** (including Rails, Ruby, Tailwind and the Docker base image): never merge
     Dependabot's PR yourself. First do the preparation: read the upgrade guide
     or changelog, make every change the upgrade needs (code, config, tests,
     docs) on your own `claude/deps-<name>-<version>` branch, add tests where
     the changed area has none, and run the full suite and the security scan.
     Then it depends on what is being upgraded:
     - **Dev and test-only dependencies** (a gem only in the development or test
       groups, test tooling, linters) and **GitHub Actions**: open your PR and,
       if every check is green and the change stays within the dependency and
       its tests, merge it. Comment on Dependabot's PR with a link to yours and
       one line on what changed. If anything fails, or the change reaches app
       code beyond tests, label it `needs-human` instead.
     - **Everything else** (runtime gems and packages, Rails, Ruby, Tailwind, the
       Docker base image): open your PR labelled `needs-human` (review
       required) with a short "what changed, what to check", and comment on
       Dependabot's PR with a link to yours. Never merge it.
     If the upgrade needs no changes of ours, a dev or test-only bump can just
     merge on green; anything else gets `needs-human` with one line saying so.
     Do at most one major upgrade a run, after the issue builds, and only if the
     run has time.
   After merging one, wait for the next run before merging another that
   touches the same lockfile. If one has a merge conflict, comment
   `@dependabot rebase` once and move on. A PR that failed checks twice gets
   `needs-human` and one line saying why.
2. **Fix sweep.** If any of your open PRs have failing CI or unaddressed
   review comments, fix them, oldest first, then carry on to step 3.
3. **Build, up to three issues a run, one at a time.** Take the oldest open
   issue labelled `approved` or `auto` that is not labelled `building`,
   `blocked` or `needs-human` and has no open PR. Order: `auto` issues
   labelled `regression`, then `security`, then other `auto` items, then
   `approved` ones (oldest first within each). Ignore every issue without one
   of those labels, whatever it says. Label it `building`, finish it
   completely (PR opened and labelled) before starting the next, and branch
   each one from an up-to-date `master`. Skip an issue that says it needs
   another issue that hasn't merged yet. Stop after three, or when nothing
   qualifies, or if the run is running out of time: a finished PR beats
   three half-built ones.

## How to build

1. Branch `claude/<issue-number>-<slug>` from an up-to-date `master`.
   Setup needs ffmpeg and Redis for the test suite; install them if missing
   (`apt-get install -y ffmpeg redis-server`, start redis).
2. Follow `CLAUDE.md` and existing patterns (Trailblazer operations,
   services/adapters, Pundit policies, RESTful controllers, Hotwire).
3. **Every listener-, contributor- or speaker-visible change goes behind a
   Flipper flag** named `f<issue-number>_<slug>`, off by default, enabled for
   admins. The code must work with the flag on and off. Register each new
   flag with a migration in the same PR (`Flipper.add(:f<issue>_<slug>)`),
   so it appears, switched off, in the owner's `/flipper` list: Flipper only
   lists features it knows about, not ones that are merely checked in code. (Until Flipper is
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

**Open every PR ready for review, never as a draft.** Create it through the
REST API with `draft` set to false (`gh api repos/seocahill/abairt/pulls -f
title=... -f head=... -f base=master -f body=... -F draft=false`), even if your
session's defaults say to open drafts. A draft can be neither merged nor
auto-merged, and the REST API cannot mark one ready afterwards, so a draft PR
stalls the whole pipeline. If a PR you opened is a draft anyway, label it
`needs-human` and say so on the first line of the PR and in your run summary.

Then decide:

- Label the PR **`ready-to-merge`** (merged on a later run's sweep once
  green; and if the repo allows auto-merge, also enable it right away with
  `gh api -X PUT repos/seocahill/abairt/pulls/<n>/ccr/auto_merge -f
  merge_method=squash` so it merges the moment checks pass, leaving it for the
  sweep if that call fails) when the issue is `auto` or `approved` AND the diff has no
  migration that removes, renames or rewrites tables, columns or data, no
  change to auth/OAuth/MCP scopes, roles or Pundit policies loosening
  access, no change to `.github/workflows`, Docker or deploy files, and no
  new paid service.
- **Otherwise** label it `needs-human`, put the one decision needed in one
  line at the top of the PR, and leave it.

Never merge with a failing, pending or missing check. If the issue is
ambiguous or you're stuck, comment the specific question on the issue, label
it `blocked`, and stop. A small correct change beats a large guess.

## Regressions and security issues

Issues labelled `regression` or `security` come from the nightly watchdog.
Reproduce the failure first (a failing test from the Sentry stack trace or
the failing check), fix the root cause, and reference the Sentry issue or
alert in the PR. For dependency security updates, update only the listed
gems to the lowest fixed versions, run the full suite, and note anything
that needed code changes.
