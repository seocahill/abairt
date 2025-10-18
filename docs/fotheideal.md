# Fotheidil Architecture

## Overview
Fotheidil is a free Irish-language automatic speech recognition (ASR) and transcription system available at https://fotheidil.abair.ie. The system supports three major Irish dialects (Ulster, Connaught, Munster) and provides a complete pipeline from audio upload to formatted transcription output.

Ref: https://arxiv.org/html/2501.00509v1

## Architecture

## Frontend Layer

### Technology Stack
- **Next.js** - Modern React framework for the web application
- **Server Actions** - Dynamic action IDs for form submissions
- Real-time progress tracking UI
- Editable transcription interface with export capabilities

### Features
- Live progress updates during processing
- In-browser transcription editing
- Multiple export formats (PDF, DOCX, SRT)
- Real-time communication with backend via Supabase

## Authentication & Storage

### Supabase
Handles multiple responsibilities:
- **Authentication**: JWT-based tokens with 1-hour expiry and refresh tokens
- **Database**: PostgreSQL-based storage for users, transcriptions, and processing state
- **Real-time subscriptions**: Powers live updates from backend to frontend

**Auth Flow**:
- Login returns access token (1-hour expiry) and refresh token
- Tokens stored in cookies: `sb-pdntukcptgktuzpynlsv-auth-token`
- Refresh endpoint: `https://pdntukcptgktuzpynlsv.supabase.co/auth/v1/token`

## Backend Infrastructure

The system runs on **3 separate Virtual Machines**:

### 1. Media Processing Server
- Handles file uploads from authenticated users
- Converts uploaded audio to 16kHz WAV format
- Orchestrates the processing pipeline
- Manages job queuing and distribution

### 2. Recognition VM
Hosts the machine learning models for transcription:

- **Voice Activity Detection (VAD)**: Silero-VAD pre-trained model
- **Speaker Diarisation**: Kaldi x-vector model trained on VoxCeleb datasets
- **ASR Engine**: Modular TDNN-HMM system with semi-supervised learning
- **Post-processing**: Transformer-based capitalization and punctuation restoration

### 3. Database VM
- Supabase PostgreSQL instance
- Stores transcriptions, user data, processing metadata
- Powers real-time updates to frontend
- Maintains processing state for job tracking

## Processing Pipeline

Complete workflow from upload to transcription:

1. **Upload** → Media Processing VM receives authenticated request
2. **Audio Conversion** → Convert to 16kHz WAV format
3. **Voice Activity Detection** → Identify speech segments using Silero-VAD
4. **Speaker Diarisation** → Detect and separate speakers using Kaldi x-vectors
5. **Segment Joining** → Merge continuous single-speaker segments
6. **ASR Transcription** → Dialect-aware speech recognition (Ulster/Connaught/Munster)
7. **Capitalization & Punctuation** → Transformer-based text restoration
8. **Storage** → Results saved to Supabase database
9. **Export** → User can download as PDF, DOCX, or SRT subtitle format

## Machine Learning Models

### ASR System
- **Architecture**: Modular TDNN-HMM (Time Delay Neural Network - Hidden Markov Model)
- **Training approach**: Semi-supervised learning on unlabeled Irish radio recordings
- **Dialect support**: Separate models/optimizations for Ulster, Connaught, and Munster dialects
- **Data sources**: Multiple Irish language speech datasets including radio broadcasts

### Speaker Diarisation
- **Model**: Kaldi x-vector embeddings
- **Training data**: VoxCeleb speaker recognition datasets
- **Purpose**: Separate multiple speakers in conversation/interview recordings

### Voice Activity Detection
- **Model**: Silero-VAD (pre-trained)
- **Purpose**: Identify speech vs silence segments to optimize processing

### Post-processing
- **Model**: Transformer-based sequence-to-sequence
- **Purpose**: Restore proper capitalization and punctuation to raw ASR output

## Integration Points (for Abairt)

Our Rails application integrates with Fotheidil through:

1. **Authentication** (`FotheidilAuthenticationService`)
   - Uses Supabase refresh tokens stored in Rails credentials
   - Refreshes access tokens as needed (1-hour expiry)
   - Manages cookie headers for authenticated requests

2. **Upload** (`FotheidilIntegrationService`)
   - POST multipart/form-data to Media Processing VM
   - Receives job ID for tracking

3. **Polling** (not yet implemented)
   - Query Supabase database for job completion status
   - Retrieve transcription results

4. **Parsing** (`FotheidilParsingService`)
   - Extract transcription data from response
   - Create `DictionaryEntry` records for new Irish words/phrases

## Key Design Principles

- **Accessibility**: "Democratize speech technology" for Irish language
- **Dialect awareness**: Dedicated support for three major Irish dialects
- **Real-time feedback**: Progress tracking throughout pipeline
- **Semi-supervised learning**: Leverages unlabeled data (radio recordings) to improve models
- **Modular architecture**: Separate VMs allow independent scaling and maintenance

## Public API Design Proposal

Currently, Fotheidil does not offer a public API for programmatic access. Since the system is built on Supabase, which has built-in REST and GraphQL API capabilities, exposing a public API would be relatively straightforward.

### Recommended Approach: Supabase PostgREST API

Supabase automatically generates a RESTful API from the PostgreSQL schema using PostgREST. The Fotheidil team could expose a public API with minimal effort:

#### **Authentication**
```
POST /auth/v1/signup
POST /auth/v1/token (for login and refresh)
```
- Already implemented via Supabase Auth
- Returns JWT tokens for authenticated requests
- Standard OAuth2 refresh token flow

#### **Upload Endpoint**
```
POST /api/v1/transcriptions
Content-Type: multipart/form-data

Parameters:
- file: audio file (mp3, wav, m4a, etc.)
- dialect: optional (ulster, connaught, munster)
- speakers: optional number of expected speakers

Response:
{
  "id": "uuid-job-id",
  "status": "queued",
  "created_at": "2025-01-03T12:00:00Z"
}
```

#### **Status Check Endpoint**
```
GET /api/v1/transcriptions/{job_id}
Authorization: Bearer {access_token}

Response:
{
  "id": "uuid-job-id",
  "status": "processing|completed|failed",
  "progress": 0.75,
  "current_step": "asr_transcription",
  "created_at": "2025-01-03T12:00:00Z",
  "completed_at": "2025-01-03T12:05:23Z",
  "result": {
    "transcript": "...",
    "speakers": [...],
    "segments": [...]
  }
}
```

#### **Webhook Support** (Optional)
```
POST /api/v1/transcriptions
...
webhook_url: "https://abairt.com/webhooks/fotheidil"

When completed, Fotheidil POSTs to webhook:
{
  "job_id": "uuid",
  "status": "completed",
  "result": {...}
}
```

### Benefits of Supabase-based Public API

1. **Already Built**: Supabase provides row-level security (RLS) policies for access control
2. **Auto-documented**: PostgREST generates OpenAPI specs automatically
3. **Real-time**: Supabase Realtime can provide WebSocket updates for job progress
4. **Standard**: RESTful API with JSON responses, follows best practices
5. **Rate-limiting**: Built-in rate limiting via Supabase
6. **API Keys**: Simple API key management through Supabase dashboard

### Implementation Estimate

For the Fotheidil team:
- **0-2 hours**: Enable PostgREST endpoints for `transcriptions` table
- **2-4 hours**: Add RLS policies for user isolation and rate limiting
- **2-4 hours**: Document API endpoints and create example code
- **Total**: ~8 hours to launch a production-ready public API

### Current Workaround (Option 1)

Until a public API is available, we use refresh token authentication:
1. Authenticate once manually in browser
2. Extract `refresh_token` from Supabase auth response
3. Store in Rails credentials
4. Use Supabase OAuth endpoint to refresh access tokens
5. Make authenticated requests to existing endpoints

This is fragile but functional for validation purposes.

## References

- Research paper: https://arxiv.org/html/2501.00509v1
- Production system: https://fotheidil.abair.ie
- Supabase project: `pdntukcptgktuzpynlsv.supabase.co`
- Supabase PostgREST docs: https://supabase.com/docs/guides/api
