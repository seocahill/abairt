# Vision — Abairt

Written and edited by the owner, not by the architect or builder. The architect
reads this first, every run, and treats it as the end state it is steering
toward. Change it whenever your thinking changes; it takes effect on the next
architect run (Sundays). Keep it short: a page is plenty.

For a quick steer between edits ("focus on X next week"), open an issue
labelled `owner-note` instead.

## What this is for

Today Abairt is a platform for transcribing, translating and listening to
audio and video of native speakers of the Mayo / North Connacht dialects of
Irish. What lasts is the corpus it builds: accurate, credited recordings and
transcriptions that people can listen to now and that models can be trained
on later (see "Where it's going").

## Who it serves, and what great looks like for them

- **Transcribers**: native speakers, volunteers and editors who transcribe,
  translate and correct. Many may be elderly, so accessibility is a
  requirement, not a nice-to-have: readable text, large targets, few steps,
  WCAG 2.2 AA.
- **Listeners**: people who come to hear native speech, often passively.
- **Other software**: the course app, researchers and the models below, all
  through a first-class API and MCP server.

I'm happy to let the best-in-class peers define "great" rather than spell it
out here. The architect should name the peers it compares against in each
proposal and say where we fall short. In practice:

- **Listening and watching** meets the standard of mainstream audio and video
  streaming apps on every screen, phone first.
- **Transcribing** meets the standard of the best transcription and subtitle
  editors.
- **Reference data** (places, speaker names, map coordinates) is accurate,
  up to date and a pleasure to browse.
- **The API and MCP** are products in their own right: complete, documented
  and stable.

## Where it's going

A dialectally accurate speech stack for Mayo Irish, trained on this corpus:

- **ASR** that transcribes Mayo speech accurately.
- **TTS** in native voices, starting with Pap Ó Murchú.
- **A fine-tuned LLM**, either standalone or as a "fixer" that corrects
  abair.ie's output toward Mayo forms.

The goal is to reach the point where we can expose an agentic speaker: an
agent that understands and speaks Mayo Irish with native-level accuracy.

Abairt's job on the way is to produce the training and evaluation data for
each of these, and to measure each model against it. Choosing or changing a
provider or model is still my call (see `DECISIONS.md`).

## What it should never become

A learning platform. I've decided teaching belongs in a dedicated application
that consumes Abairt's data as needed (see #70). Abairt makes its data easy to
consume; it doesn't build quizzes, lessons, word lists or progress tracking.

Released without consent. Nothing made from a speaker's recordings (a TTS
voice, a model, a dataset) is made publicly available without that speaker's
express consent. Building and testing privately is fine; releasing is not.

## Current priorities

- **Finish the core.** Transcription, listening and search should be
  competitive with peer apps.
- **Bin what's poor and build it anew.** Where something is bad (the admin
  backend, for example), replace it rather than patch it, and retire
  superfluous features. Removing dead code with no visible effect is fine.
  Retiring a feature people can see needs my yes first: propose it, say what
  would be lost, and wait. Deleting data still needs me. Big rebuilds, the
  admin backend included, are broken into a sequence of small issues that each
  ship on their own.
- **Training data.** Good training data is key to everything in "Where it's
  going". Identify what we have, flag where human work is needed, and set
  targets we can work towards. For a Pap Ó Murchú TTS voice, for example:
  which segments are suitable (e.g. one speaker, clean audio, checked
  transcription), which need review, and how much we have against how much a
  voice needs. Report progress against the targets in the weekly digest.
