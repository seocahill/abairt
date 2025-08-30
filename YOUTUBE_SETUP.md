# YouTube Import Setup

The YouTube importer requires `yt-dlp` to be installed on the system.

## Installation

### macOS (Homebrew)
```bash
brew install yt-dlp
```

### macOS/Linux (pip)
```bash
pip install yt-dlp
```

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install yt-dlp
```

## Verification

Test that yt-dlp is working:
```bash
yt-dlp --version
```

## Usage

Once installed, the YouTube importer will automatically:
1. Extract video metadata (title, description, duration)
2. Download video in MP4 format (best quality available)
3. Attach the video file to the voice recording

## Supported URLs

- `https://www.youtube.com/watch?v=VIDEO_ID`
- `https://youtu.be/VIDEO_ID`
- YouTube playlist URLs (will import first video only)

## Error Handling

If yt-dlp is not installed, imports will fail gracefully with appropriate error messages in the logs.