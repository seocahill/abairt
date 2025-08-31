# Anti-Bot Detection Features

The importers have been enhanced with several anti-bot detection measures to work reliably on servers like Hetzner where bot detection is more aggressive.

## Features Implemented

### RTE Importer (`app/services/importers/rte_ie.rb`)

1. **Random User Agent Rotation**: Cycles through realistic browser user agents
2. **Comprehensive Headers**: Adds realistic browser headers including:
   - Accept headers with proper priorities
   - Accept-Language with Irish (ga) support
   - Security headers (DNT, Sec-Fetch-* headers)
   - Cache-Control and Referer headers

3. **Request Delays**: 
   - Random delays (1-3 seconds) between requests
   - Additional random delays (0.5-2 seconds) before ffmpeg downloads

4. **Retry Logic with Exponential Backoff**:
   - Up to 3 retries on failure
   - Exponential backoff with jitter (2^retries + random 1-5 seconds)
   - Special handling for rate limiting (429) and service unavailable (503) errors

5. **Proxy Support**: 
   - Set `PROXY_URL` environment variable to use a proxy
   - Format: `http://username:password@proxy.example.com:8080`

### YouTube Importer (`app/services/importers/youtube.rb`)

1. **Random User Agent**: Same user agent rotation as RTE importer
2. **yt-dlp Anti-Bot Options**:
   - Random sleep intervals (1-3 seconds)
   - Google referer
   - Retry logic for both metadata extraction and downloads
   - Fragment retry handling

## Usage

### Environment Variables

- `PROXY_URL`: Optional proxy server URL for additional IP rotation

### Example Proxy Usage

```bash
# Using a SOCKS5 proxy
export PROXY_URL="socks5://proxy.example.com:1080"

# Using HTTP proxy with authentication
export PROXY_URL="http://user:pass@proxy.example.com:8080"

# Run the Rails application
RAILS_ENV=production bin/rails server
```

## Technical Details

### User Agents Used

The system rotates between these realistic user agents:
- Chrome on Windows 10
- Chrome on macOS
- Firefox on Windows 10
- Safari on macOS
- Chrome on Linux

### Request Patterns

- Random delays prevent detection of automated access patterns
- Headers mimic real browser requests
- SSL verification disabled to handle server-side SSL issues
- Proper referer headers to appear as legitimate traffic

### Error Handling

- Graceful degradation when requests fail
- Detailed logging for debugging
- Automatic retries with intelligent backoff
- Rate limit detection and handling

## Troubleshooting

If imports still fail:

1. Check logs for specific error messages
2. Try setting a proxy via `PROXY_URL`
3. Ensure yt-dlp is up to date: `pip install -U yt-dlp`
4. Consider rotating IP addresses or using a VPN

## Security Note

These features are designed for legitimate content import and should comply with the terms of service of target websites. Always respect robots.txt and rate limits.