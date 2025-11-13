# Docker Setup for HwmWorker

This project uses Docker Compose with a separate Selenium container for browser automation.

## Architecture

- **app**: Ruby application (hwm_worker)
- **selenium**: Standalone Chrome browser with ChromeDriver

The app connects to the Selenium container via Remote WebDriver.

## Quick Start

```bash
# Build and start both services
docker-compose up

# Run in background
docker-compose up -d

# View logs
docker-compose logs -f app
docker-compose logs -f selenium

# Stop services
docker-compose down
```

## Running Different Commands

```bash
# Run the main worker
docker-compose up app

# Run hunt command
docker-compose run --rm app bin/hunt

# Run console
docker-compose run --rm app bin/console

# Run with production environment
docker-compose run --rm -e APP_ENV=production app bin/run
```

## Configuration

### Environment Variables

- `APP_ENV`: Set to `development` or `production` (default: `development` in docker-compose)
- `SELENIUM_URL`: URL to Selenium server (default: `http://selenium:4444`)

### Required Files

Mount these files as volumes (already configured in docker-compose.yml):

- `.hwm_credentials.yml`: Your game credentials
- `secrets.yml`: API tokens and configuration

## Debugging

### View Selenium Browser (VNC)

The Selenium container exposes a VNC server on port 7900:

1. Open your browser to http://localhost:7900
2. Password: `secret`
3. You can see Chrome running in real-time

### Check Selenium Status

```bash
curl http://localhost:4444/status
```

### Access App Container

```bash
docker-compose exec app bash
```

## Without Docker Compose

If you prefer to run containers manually:

```bash
# Start Selenium
docker run -d --name selenium -p 4444:4444 --shm-size=2g selenium/standalone-chrome:latest

# Build app image
docker build -t hwm_worker .

# Run app
docker run --rm \
  --link selenium:selenium \
  -e APP_ENV=development \
  -e SELENIUM_URL=http://selenium:4444 \
  -v $(pwd)/.hwm_credentials.yml:/app/.hwm_credentials.yml \
  -v $(pwd)/secrets.yml:/app/secrets.yml \
  hwm_worker
```

## Troubleshooting

### Selenium not ready

If you see connection errors, wait a few seconds for Selenium to start:

```bash
# Check if Selenium is ready
docker-compose logs selenium | grep "Started Selenium"
```

### App can't connect to Selenium

Make sure both containers are on the same network:

```bash
docker-compose ps
```

Both should show as "Up".

### Performance issues

Increase shared memory size for Selenium in docker-compose.yml:

```yaml
selenium:
  shm_size: 4gb  # Increase from 2gb
```
