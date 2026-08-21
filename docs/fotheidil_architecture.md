# Fotheidil Integration Architecture

## Overview

The Fotheidil integration processes voice recordings through ABAIR's transcription
service and imports the results as dictionary entries. It talks to the published
Abair API v4 (<https://api.abair.ie/v4/docs>) — the same `fotheidil-api` pipeline
that backs fotheidil.abair.ie, reached over HTTP rather than by driving the site
in a browser.

## Components

### `Fotheidil::ApiService`

Thin client for the API. Holds no state beyond the key:

| Method | Endpoint | Notes |
| --- | --- | --- |
| `submit(path, file_name:)` | `POST /subtitles` | Returns the integer job id |
| `status(id)` | `GET /subtitles/{id}` | Progress counters |
| `transcript(id)` | `GET /subtitles/{id}/transcript` | Segments, or `nil` while running |
| `key_status` | `GET /apikey/status` | Tier, quota, expiry |

Failures raise `Fotheidil::ApiService::Error` carrying the HTTP status and the
API's message.

### `Fotheidil::ProcessVideoOperation`

Trailblazer operation owning the pipeline:

1. `validate_voice_recording` — media must be attached
2. `check_not_already_completed` — short-circuits finished recordings
3. `prepare_audio_track` — downsamples MP3 to 128kbps mono 16kHz
4. `determine_video_source` — reuses a given `fotheidil_video_id`, else submits
5. `wait_for_transcription` — polls until the transcript is available
6. `parse_segments` — drops segments missing timings or text
7. `save_segments` … `publish` — persistence, entry creation, completion

`Fotheidil::CreateSpeakerEntriesService` and `Fotheidil::SegmentUploadChecker`
are unchanged; they consume the segment shape described below.

## Segment shape

`GET /subtitles/{id}/transcript` returns:

```json
{
  "id": 3826,
  "status": "completed",
  "media_length": 3.24,
  "transcript": [
    {
      "id": "0000",
      "text": "Nuair a bhí na robáil ag imirt tamall ón teach.",
      "speaker": "SPEAKER_00",
      "startTimeSeconds": 0.57,
      "endTimeSeconds": 2.87,
      "checked": false
    }
  ]
}
```

The `transcript` array is stored verbatim in `voice_recording.segments`.

## Configuration

```yaml
# bin/rails credentials:edit
abair:
  api_key: <key from https://auth.abair.ie/api-keys>
```

`ENV["ABAIRT_API_KEY"]` is used as a fallback. Check a key with:

```ruby
Fotheidil::ApiService.new.key_status
# => {"tier" => "basic", "status" => "active", "tokens_left" => 499987, ...}
```

## API quirks worth knowing

- **Status lags the transcript.** Completed jobs can sit at
  `audio_extraction_progress: 99` with `status: "processing"` while the
  transcript is already available. `transcript` therefore treats a `409` as the
  only reliable "not ready" and never consults `status`.
- **Media names must be unique.** The API derives its stored name from
  `fileName` and rejects a repeat with `HTTP 500 {"message": "audio already
  uploaded"}`, so the operation appends a random suffix per submission.
- **Job ids are integers**, despite the spec documenting a UUID.
- **A missing `profiles` row breaks key creation.** Accounts created before
  ABAIR added the API-key feature have no row in their Supabase `profiles`
  table, which surfaces as `PGRST116` when accepting the usage agreement and
  `403 "No active Billing-Key found for this account"` on every API call.

## Debugging

```ruby
service = Fotheidil::ApiService.new
id = service.submit("/tmp/clip.mp3", file_name: "clip-#{SecureRandom.hex(4)}.mp3")
service.status(id)
service.transcript(id)
```

The whole pipeline is runnable from the console:

```ruby
Fotheidil::ProcessVideoOperation.call(voice_recording: VoiceRecording.find(210))
# reuse an existing job instead of re-submitting:
Fotheidil::ProcessVideoOperation.call(voice_recording: vr, fotheidil_video_id: "3826")
```
