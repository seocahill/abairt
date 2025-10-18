# Selenium Chrome Setup

This project uses a separate Chrome service for browser automation (Fotheidil scraping).

## Architecture

- **Development (local)**: Uses local Chrome (GUI visible for debugging)
- **Development (containerized)**: Uses Selenium Chrome container
- **Production**: Uses Selenium Chrome container in Docker Swarm

## Usage

### Option 1: Local Chrome (Development Default)

Just run your Rails app normally:

```bash
bin/rails server
```

The browser will open visually on your machine.

### Option 2: Containerized Chrome (Testing Production Setup)

Start the Chrome service:

```bash
docker-compose up chrome
```

Then run your Rails app with the SELENIUM_URL:

```bash
SELENIUM_URL=http://localhost:4444/wd/hub bin/rails server
```

### Option 3: Visual Debugging (See what the browser is doing)

When using containerized Chrome, you can watch the browser via VNC:

1. Start Chrome service:
   ```bash
   docker-compose up chrome
   ```

2. Open VNC viewer in browser:
   ```
   http://localhost:7900
   ```
   Password: `secret` (default)

3. Run your scraping with SELENIUM_URL set:
   ```bash
   SELENIUM_URL=http://localhost:4444/wd/hub bin/rails runner "Fotheidil::ParserService.new.parse_segments(1141)"
   ```

You'll see the browser automation happening in real-time in your browser!

## Testing

To test the parser with containerized Chrome:

```bash
# Start Chrome
docker-compose up -d chrome

# Run tests
SELENIUM_URL=http://localhost:4444/wd/hub RAILS_ENV=development bin/rails runner test/scripts/test_fotheidil_pagination.rb

# Or run in console
SELENIUM_URL=http://localhost:4444/wd/hub bin/rails console
> parser = Fotheidil::ParserService.new
> segments = parser.parse_segments(1141)
> puts segments.length
```

## Production

In production (Docker Swarm), the `SELENIUM_URL` is automatically set in docker-compose.production.yml:

```yaml
environment:
  SELENIUM_URL: http://chrome:4444/wd/hub
```

No additional configuration needed!

## Troubleshooting

### Chrome container won't start
```bash
docker-compose logs chrome
```

### Can't connect to Chrome
Ensure the chrome service is running:
```bash
docker-compose ps chrome
```

Should show status as "Up"

### Browser timing out
Increase timeout in browser_service.rb or check Chrome container logs
