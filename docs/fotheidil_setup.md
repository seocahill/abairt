# Fotheidil Integration Setup

This document explains how to extract the necessary credentials to integrate with Fotheidil's private API.

## Prerequisites

- Firefox or Chrome browser
- Access to Fotheidil account at https://fotheidil.abair.ie
- Rails credentials access (`bin/rails credentials:edit`)

## Step 1: Extract Supabase Anon API Key

The Supabase `anon` API key is needed for refresh token authentication.

### Easiest Method: WebSocket URL (Recommended)

1. **Open Developer Tools**
   - Firefox: `Ctrl+Shift+E` (Network tab)
   - Chrome: `Ctrl+Shift+I` → Network tab

2. **Log in to Fotheidil**
   - Go to https://fotheidil.abair.ie
   - Enter your credentials and log in

3. **Find the WebSocket Connection**
   - In the Network tab, filter by "WS" or "WebSocket"
   - Look for a connection to `wss://pdntukcptgktuzpynlsv.supabase.co/realtime/v1/websocket`
   - Click on it to see the full URL
   - The URL will look like:
   ```
   wss://pdntukcptgktuzpynlsv.supabase.co/realtime/v1/websocket?apikey=eyJhbGci...&vsn=1.0.0
   ```
   - Copy the `apikey` parameter value (everything between `apikey=` and `&vsn`)

The key is a long string starting with `eyJ` - copy the entire value.

### Alternative: HTTP Request Headers

1. **Find Supabase HTTP Requests**
   - In Network tab, filter for `supabase.co`
   - Look for any request to `https://pdntukcptgktuzpynlsv.supabase.co`
   - Click on the request → "Headers" tab
   - Find the `apikey` header
   - Copy the value

## Step 2: Extract Refresh Token

The refresh token allows long-term authentication without re-logging in.

### Method 1: Check Set-Cookie Headers (Recommended)

1. **Log in to Fotheidil**
   - Open https://fotheidil.abair.ie/login
   - Open DevTools → Network tab
   - Enter your credentials and click "Sign In"

2. **Find the Set-Cookie Header**
   - Look for the POST request to `/login`
   - Click on the request
   - Go to "Headers" tab (not Response!)
   - Scroll down to "Response Headers"
   - Find the `set-cookie` header for `sb-pdntukcptgktuzpynlsv-auth-token`
   - The cookie value is a Base64-encoded JSON object containing:
     - `access_token` (JWT, expires in 1 hour)
     - `refresh_token` (short string like "5drjpae4atsu")
     - `token_type` ("bearer")
     - `expires_in` (3600 seconds)

3. **Decode the Cookie Value**
   - Copy the cookie value (the part after `sb-pdntukcptgktuzpynlsv-auth-token=`)
   - It looks like: `base64-eyJhY2Nlc3NfdG9rZW4iOi...`
   - Use browser console or Rails console to decode:
   ```javascript
   // In browser console
   JSON.parse(atob('base64-eyJhY2Nlc3NfdG9rZW4iOi...'.split('-')[1]))
   ```
   ```ruby
   # In Rails console
   require 'base64'
   require 'json'

   cookie_value = "base64-eyJhY2Nlc3NfdG9rZW4iOi..." # paste cookie value
   decoded = JSON.parse(Base64.decode64(cookie_value.split('-')[1]))
   puts "Refresh token: #{decoded['refresh_token']}"
   ```

### Method 2: Check Cookies Tab

1. **After Logging In**
   - Open DevTools → Application/Storage tab (Chrome) or Storage tab (Firefox)
   - Go to "Cookies" → `https://fotheidil.abair.ie`
   - Find cookie named `sb-pdntukcptgktuzpynlsv-auth-token`
   - Copy the value and decode as shown above

### Method 3: Check Local Storage

1. **After Logging In**
   - Open DevTools → Application/Storage tab
   - Go to "Local Storage" → `https://fotheidil.abair.ie`
   - Look for keys containing `supabase.auth.token`
   - The value contains the same auth object with `refresh_token`

## Step 3: Store Credentials in Rails

Once you have both the API key and refresh token:

```bash
EDITOR=nano bin/rails credentials:edit
```

Add the following structure:

```yaml
fotheidil:
  email: your-email@example.com
  password: your-password  # Optional, only needed for initial login
  supabase_anon_key: eyJhbGci...  # Long JWT string from WebSocket URL
  refresh_token: xxxxx...  # Short string from login cookie
```

Save and exit (Ctrl+X → Y → Enter for nano).

## Step 4: Test the Setup

```bash
bin/rails runner "
service = FotheidilAuthenticationService.new
if service.authenticate
  puts '✅ Authentication successful!'
  puts 'Access token: ' + service.access_token[0..20] + '...'
else
  puts '❌ Authentication failed'
end
"
```

## Troubleshooting

### 401 Invalid API Key

- The `supabase_anon_key` is incorrect
- Re-extract from browser network requests
- Make sure you copied the entire key (starts with `eyJ`, very long)

### 400 Invalid Grant

- The `refresh_token` has expired or is invalid
- Log in again and extract a fresh refresh token
- Refresh tokens can expire after 60 days of inactivity

### No Response / Timeout

- Check your internet connection
- Verify the Supabase URL is correct: `pdntukcptgktuzpynlsv.supabase.co`
- Check if Fotheidil is currently operational

## Security Notes

- Never commit credentials to git
- Rails credentials are encrypted with `master.key`
- Keep `master.key` secure and separate from your repository
- Refresh tokens should be rotated periodically for security
- The anon API key is "public" but should still not be widely shared

## Next Steps

Once authentication is working:
1. Test file upload to Fotheidil
2. Implement polling for transcription results
3. Parse and store transcriptions in Abairt database
