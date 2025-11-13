# Docker Usage Guide

This guide explains how to use Docker with hwm_worker in both production and development environments.

## Prerequisites

- Docker installed
- Docker Compose installed (optional, but recommended)
- Configuration files: `.hwm_credentials.yml` and `secrets.yml`

## Quick Start

### Using Docker Compose (Recommended)

#### Production Mode
```bash
# Build and run in production mode
docker-compose up hwm_worker

# Run in background
docker-compose up -d hwm_worker

# View logs
docker-compose logs -f hwm_worker
```

#### Development Mode
```bash
# Build and run in development mode (Rollbar disabled)
docker-compose up hwm_worker_dev

# Run in background
docker-compose up -d hwm_worker_dev

# View logs
docker-compose logs -f hwm_worker_dev
```

### Using Docker CLI

#### Production Mode
```bash
# Build the image
docker build -t hwm_worker:latest .

# Run the container
docker run -d \
  -v $(pwd)/.hwm_credentials.yml:/app/.hwm_credentials.yml \
  -v $(pwd)/secrets.yml:/app/secrets.yml \
  -v $(pwd)/logs:/app/logs \
  --name hwm_worker \
  hwm_worker:latest
```

#### Development Mode
```bash
# Build the image with development environment
docker build --build-arg APP_ENV=development -t hwm_worker:dev .

# Run the container in development mode
docker run -d \
  -e APP_ENV=development \
  -v $(pwd)/.hwm_credentials.yml:/app/.hwm_credentials.yml \
  -v $(pwd)/secrets.yml:/app/secrets.yml \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/lib:/app/lib \
  -v $(pwd)/bin:/app/bin \
  --name hwm_worker_dev \
  hwm_worker:dev
```

## Environment Differences

### Production Mode (`APP_ENV=production`)
- Rollbar error reporting **enabled**
- Errors are logged to Rollbar
- Uses production configuration from `secrets.yml`
- Default mode

### Development Mode (`APP_ENV=development`)
- Rollbar error reporting **disabled**
- Errors are raised directly (easier debugging)
- Source code can be mounted for live changes
- Useful for testing and development

## Running Different Commands

### Auto Hunt
```bash
# Production
docker-compose run --rm hwm_worker bin/hunt

# Development
docker-compose run --rm hwm_worker_dev bin/hunt

# Docker CLI
docker run --rm \
  -v $(pwd)/.hwm_credentials.yml:/app/.hwm_credentials.yml \
  -v $(pwd)/secrets.yml:/app/secrets.yml \
  hwm_worker:latest bin/hunt
```

### Interactive Console
```bash
# Production
docker-compose run --rm hwm_worker bin/console

# Development
docker-compose run --rm hwm_worker_dev bin/console
```

## Configuration Files

Make sure you have the following files in your project root:

1. `.hwm_credentials.yml` - Your game credentials
2. `secrets.yml` - API tokens and configuration

These files are mounted as volumes and are **not** included in the Docker image for security.

## Troubleshooting

### Chrome/Selenium Issues
The Docker image includes Chrome for Testing with all necessary dependencies. Chrome runs in headless mode with the following flags:
- `--no-sandbox` (required for Docker)
- `--disable-dev-shm-usage` (prevents memory issues)
- `--headless=new` (headless mode)

### Viewing Logs
```bash
# Docker Compose
docker-compose logs -f hwm_worker

# Docker CLI
docker logs -f hwm_worker
```

### Accessing the Container
```bash
# Docker Compose
docker-compose exec hwm_worker bash

# Docker CLI
docker exec -it hwm_worker bash
```

## Stopping and Cleaning Up

```bash
# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Remove images
docker rmi hwm_worker:latest hwm_worker:dev
```
