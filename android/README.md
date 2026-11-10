# Abairt Android

An Android app for listening to the recordings on [abairt.com](https://abairt.com) on a phone,
built around one use: putting on "radio" (random recordings, one after another) in bed or while
doing something else, listening without reading, and occasionally scanning back to check a line.

It lives in this repository for now so it can be built against the API it needs. It is
self-contained (its own Gradle project, its own CI workflow, excluded from the Rails Docker
image), so moving it to its own repo later is one command:

```bash
git subtree split --prefix=android -b android-app   # then push that branch to the new repo
```

## What it does

**Listening mode** (the home screen): nothing to read. The title, the voice you are hearing,
a thin seek bar, big controls (previous/next recording, back/forward 10 seconds), "Slow",
speed and sleep timer chips. Dark theme is true black.

- **Radio**: "Start radio" queues random recordings that have a transcript, and keeps a few
  waiting ahead of the one playing so it does not stop in the night. It does not repeat a
  recording within a run, and retries quietly when the connection drops.
- **Native controls**: it is a Media3 `MediaSessionService`, so the notification, lock screen,
  Bluetooth and headset buttons all work (play/pause, next/previous recording, plus "back one
  line" and the slow toggle in the notification and on the lock screen), as does audio focus
  (calls pause it) and unplugging headphones. Swiping the app away while it plays does not stop it.
  Without a transcript, "back one line" is "back 10 seconds".
- **The line on the lock screen**: while a recording plays, the lock-screen card shows the line
  being spoken (the Irish, with the English beneath) in place of the title, so in bed you can
  step back a line and glance at it without unlocking. It follows the audio with the screen off,
  waking only when the next line starts. The card fits only so much; tap it to read the whole
  line in the transcript, which opens over the lock screen without unlocking (back returns to
  the lock screen; nothing else in the app is reachable from it). Settings can turn it off.
- **Sleep timer**: 15 to 90 minutes with a 30 second fade-out, or "end of this recording".
- **Slow**: one tap (in the app, or on the lock screen without unlocking) switches between your
  usual speed and a slow one (0.75x to start). While slowed down, the speed chip sets how slow.
- **Speed**: 0.5x to 1.3x, pitch preserved, remembered between runs, as is whether you were
  slowed down.

**Study mode** (tap "Transcript", or the transcript button top right, which also closes it):
the transcript follows the audio, current line highlighted. The app reopens in whichever mode
you left it in.

- Made for reading in bed: while the transcript is open and the audio is playing, the screen
  stays on (until the sleep timer pauses it), and it shows over the lock screen, so pressing
  the power button brings the transcript straight back without unlocking. Leaving the
  transcript brings the lock back; nothing else in the app is reachable from there.

- Tap a line to hear it. "Back one line" restarts the current line, and pressed again soon
  after goes to the line before (so you can step back a sentence at a time).
- "Repeat this line" loops the current line until you turn it off or move away.
- English is hidden until you tap the translate icon on a line (or set it to always show).
- It scrolls with the audio until you scroll yourself; "Now" brings the following back.
- Lines nobody has checked yet (most of the corpus: the machine's transcript) are shown but
  marked "Not checked yet". Turn that off in settings to see only checked lines.

UI text is English, in `app/src/main/res/values/strings.xml`. A `values-ga/strings.xml` with the
same names translates it; it is deliberately left to native speakers.

## Setup

1. Sign in on abairt.com, open your user page and generate an API token.
2. Install the app, open Settings, paste the token (the server defaults to `https://abairt.com`),
   and tap "Test connection".
3. Back on the home screen, "Start radio".

The token is kept in the app's private storage and excluded from backups. A proper sign-in
(the server already has an OAuth provider with PKCE for the MCP server) would be nicer than pasting
a token; see "Next".

## API

It uses two endpoints (see `/api/openapi` on the server, and `AbairtApi.kt`):

- `GET /api/voice_recordings?shuffle=true&limit=5&exclude_ids[]=…` lists recordings that have audio
  and a transcript, as summaries.
- `GET /api/voice_recordings/:id?unchecked=true` returns one with its timed lines. `checked` on
  each line says whether a person has checked it. Without `unchecked`, only checked lines come
  back, which is what the Mayo Irish course uses, so that stays as it was.

The API is rate limited to 100 requests an hour per token. A radio makes roughly one request
per recording played, so this is plenty.

## Build

You need JDK 17+ and the Android SDK (platform 37, build-tools 37). Then:

```bash
cd android
./gradlew testDebugUnitTest      # JVM unit tests
./gradlew assembleDebug          # app/build/outputs/apk/debug/app-debug.apk
./gradlew lintDebug
```

Open `android/` in Android Studio to run it on a device or emulator. From the emulator, a Rails
server on your machine is `http://10.0.2.2:3000` (cleartext is allowed for that address only).

## Code map

| | |
|---|---|
| `playback/PlaybackService.kt` | ExoPlayer + MediaSession; everything that must keep going with the screen off |
| `playback/RadioQueue.kt` | when to fetch more, what not to repeat (pure, unit tested) |
| `playback/SleepTimer.kt` | countdown, fade, end-of-recording (pure, unit tested) |
| `playback/PlaybackProtocol.kt` | custom session commands and the state the service publishes |
| `transcript/Transcript.kt` | which line is playing, where "back one line" goes (pure, unit tested) |
| `data/AbairtApi.kt` | the two API calls (unit tested against a mock server) |
| `ui/` | Compose screens: `ListenScreen`, `StudyScreen`, `SettingsScreen`, and `PlayerViewModel`, which talks to the service through a `MediaController` |

## Status

Compiles, passes lint and 26 unit tests, and builds a minified release. **It has not been run on
a device or emulator** (none was available where it was written), so playback, notification
controls, the sleep timer fade and the line loop are untested in practice. Expect a first pass of
small fixes once it is on a phone.

## Next

- Sign in with the server's OAuth instead of pasting a token.
- Keep recordings offline (the audio cache only holds what was played).
- A browse tree for Android Auto and Bluetooth displays.
- Deep links from the web ("open this moment in the app").
