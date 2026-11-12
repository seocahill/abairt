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

## Log

<!-- - YYYY-MM-DD #<issue> <title> — approved | rejected: <reason> -->
