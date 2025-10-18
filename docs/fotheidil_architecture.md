# Fotheidil Integration Architecture

## Overview

The Fotheidil integration allows users to process voice recordings using the Fotheidil.abair.ie transcription service. The system uploads audio files, polls for transcription completion, and imports the results as dictionary entries.

## Architecture

The integration is organized into distinct services under the `Fotheidil::` namespace, each with a clear responsibility:

### 1. Authentication (`Fotheidil::AuthenticationService`)

**Responsibility**: Manage authentication with Fotheidil API

**Process**:
1. First attempts to use stored refresh token from database (`Setting.get('fotheidil.refresh_token')`)
2. If refresh token is valid, exchanges it for a new access token via Supabase API
3. If refresh token is invalid/expired, falls back to browser-based login
4. Stores new refresh tokens in database for future use

**Key Methods**:
- `authenticate` - Main authentication flow
- `refresh_access_token` - Token refresh logic (private)
- `browser_login_and_extract_token` - Browser fallback (private)

### 2. Browser Automation (`Fotheidil::BrowserService`)

**Responsibility**: Headless browser operations using Selenium WebDriver

**Features**:
- Headless Chrome setup
- Login to Fotheidil.abair.ie
- Cookie extraction
- Page navigation and interaction

**Key Methods**:
- `setup_browser` - Initialize Chrome driver
- `authenticate` - Login via browser
- `extract_cookies` - Get session cookies
- `decode_supabase_token` - Extract auth tokens from cookies
- `cleanup` - Close browser

### 3. File Upload (`Fotheidil::UploadService`)

**Responsibility**: Upload audio/video files to Fotheidil

**Process**:
1. Navigate to upload page
2. Select file via file input element
3. Click upload button
4. Monitor for redirect (indicates successful upload)
5. Return video URL

**Key Methods**:
- `upload_file(file_path)` - Upload file and return video URL

### 4. Parsing & Transcript Extraction (`Fotheidil::ParserService`)

**Responsibility**: Extract transcripts and create voice recordings

**Key Features**:
- Multi-page transcript extraction with pagination support
- Speaker identification (SPEAKER_01, SPEAKER_02, etc.)
- Timestamp parsing (HH:MM:SS.CC format)
- Duplicate detection across pages
- Multiple extraction strategies (fallback logic)

**Key Methods**:
- `process_voice_recording(voice_recording)` - Upload file and extract transcript
- `process_first_unimported_video` - Process from existing videos page
- `extract_transcript_from_video_page` - Parse transcript HTML
- `create_voice_recording_for_video` - Create VoiceRecording model (legacy method)
- `update_voice_recording_with_transcript` - Update existing VoiceRecording

### 5. Integration Orchestrator (`Fotheidil::IntegrationService`)

**Responsibility**: Coordinate all services

**Process**:
1. Initialize browser service
2. Authenticate using AuthenticationService
3. Create parser service with browser instance
4. Process voice recording (upload → parse → update)
5. Cleanup browser resources

**Key Methods**:
- `authenticate` - Setup and authenticate
- `process_voice_recording(voice_recording)` - Main processing flow
- `process_first_unimported_video` - Process from videos page
- `cleanup` - Resource cleanup

### 6. Speaker Entry Creation (`Fotheidil::CreateSpeakerEntriesService`)

**Responsibility**: Queue Fotheidil segments for processing using existing job infrastructure

**Process**:
1. Validate diarization data source is 'fotheidil'
2. Extract segments from diarization_data
3. Queue each segment via `ProcessDiarizationSegmentJob` with pre-existing transcription
4. Job creates DictionaryEntry with:
   - Temporary speaker user
   - Start/end timestamps (region_start/region_end)
   - Pre-filled transcription (word_or_phrase) from Fotheidil
   - Skips transcription API call since text already exists

**Key Difference from Pyannote Flow**:
- Pyannote: Job creates entry → extracts audio → calls abair.ie API for transcription
- Fotheidil: Job creates entry with transcription → extracts audio → skips API call

## Workflow

### Upload & Process Flow

```
User creates VoiceRecording with use_fotheidil_api=true
  ↓
FotheidilProcessVoiceRecordingJob.perform_later
  ↓
Fotheidil::IntegrationService.new
  ↓
1. Authenticate
   - Try refresh token
   - Fallback to browser login
   - Store new refresh token
  ↓
2. Process Voice Recording
   - Download media file to temp location
   - Upload to Fotheidil (via UploadService)
   - Extract video ID from redirect URL
   - Wait for processing
   - Navigate to video page
   - Extract transcript (with pagination)
   - Update VoiceRecording with transcript data
  ↓
3. Create Speaker Entries
   - Parse diarization segments
   - Create SpeakerEntry for each segment
  ↓
4. Cleanup
   - Close browser
   - Delete temp files
```

### Authentication Flow

```
1. Check for stored refresh_token in database
   ↓
2. If found → Try token refresh
   - POST to Supabase API
   - Get new access_token
   - Store rotated refresh_token
   ↓
3. If refresh fails → Browser login
   - Launch headless Chrome
   - Navigate to login page
   - Fill email/password
   - Submit form
   - Extract auth cookie
   - Parse and store tokens
   ↓
4. Return authenticated status
```

### Transcript Extraction Strategies

The parser uses multiple strategies to extract transcripts:

**Strategy 1: Fotheidil DOM Structure** (Primary)
- Look for divs with `SPEAKER_` text and timestamps
- Parse `[contenteditable="true"]` elements for transcript text
- Extract HH:MM:SS.CC timestamps
- Handle pagination ("Next Page" buttons)
- Deduplicate across pages

**Strategy 2: Structured Transcript** (Fallback)
- Look for table rows or transcript segments
- Extract from data attributes and classes
- Parse timestamps and text separately

**Strategy 3: Raw Text Extraction** (Last Resort)
- Extract any substantial text content
- Skip UI/navigation text
- Generate dummy timestamps

## Data Flow

### VoiceRecording diarization_data Structure

```json
{
  "source": "fotheidil",
  "fotheidil_video_id": "abc123",
  "fotheidil_url": "https://fotheidil.abair.ie/videos/abc123",
  "title": "Recording Title",
  "processed_at": "2025-10-05T12:00:00Z",
  "segments": [
    {
      "start": 0.0,
      "end": 5.5,
      "text": "Transcribed text",
      "speaker": "SPEAKER_01",
      "confidence": null
    }
  ],
  "raw_fotheidil_data": {
    // Full extraction data for debugging
  }
}
```

## Configuration

### Required Credentials

```yaml
fotheidil:
  email: "your-email@example.com"
  password: "your-password"
  supabase_anon_key: "your-supabase-key"
  refresh_token: "optional-initial-token"  # Auto-managed after first login
```

### Settings Table

- `fotheidil.refresh_token` - Stored refresh token (auto-rotated)

## UI Integration

### Controller Changes

```ruby
# app/controllers/voice_recordings_controller.rb

def create
  # Check for Fotheidil processing option
  if voice_recording_params[:use_fotheidil_api] == 'true' && current_user.admin?
    FotheidilProcessVoiceRecordingJob.perform_later(@voice_recording.id)
  else
    DiarizeVoiceRecordingJob.perform_later(@voice_recording.id)
  end
end
```

### Form Changes

```erb
<!-- app/views/voice_recordings/_form.html.erb -->

<% if current_user&.admin? %>
  <div class="field">
    <%= form.check_box :use_fotheidil_api %>
    <%= form.label :use_fotheidil_api, "Use Fotheidil API for processing" %>
  </div>
<% end %>
```

## Error Handling

- All services use Rails.logger for debugging
- Browser errors are caught and logged
- Temp files are cleaned up in ensure blocks
- Failed uploads/parsing update diarization_status to 'failed'
- Refresh token rotation handles Supabase token expiration

## Testing

Run the job manually in Rails console:

```ruby
# Find or create a voice recording
vr = VoiceRecording.last
vr.update(diarization_status: 'pending')

# Run the job synchronously
FotheidilProcessVoiceRecordingJob.new.perform(vr.id)

# Check results
vr.reload
vr.diarization_data
vr.speaker_entries
```

## Future Improvements

1. **API-based approach**: Replace browser automation with direct API calls once Fotheidil provides an API
2. **Async polling**: Instead of sleep(), use job retries to poll for completion
3. **Better error recovery**: Retry logic for transient failures
4. **Batch processing**: Process multiple videos in one browser session
5. **Token management**: Background job to refresh tokens before expiration
