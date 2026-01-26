# Use Ruby 3.4.1 slim as base image
FROM ruby:4.0.1-slim

# Install minimal system dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock hwm_worker.gemspec ./
COPY lib/hwm_worker/version.rb ./lib/hwm_worker/

# Install bundler and gems
RUN gem install bundler -v 2.6.3 && \
    bundle install --jobs 4 --retry 3

# Copy the rest of the application
COPY . .

# Create necessary directories
RUN mkdir -p file_base

# Copy sample config files if production configs don't exist
RUN if [ ! -f .hwm_credentials.yml ]; then \
        cp .hwm_credentials.sample.yml .hwm_credentials.yml; \
    fi && \
    if [ ! -f secrets.yml ]; then \
        cp secrets.sample.yml secrets.yml; \
    fi

# Set environment variable (can be overridden at runtime)
ARG APP_ENV=production
ENV APP_ENV=${APP_ENV}

# Default command (can be overridden)
CMD ["bin/run"]
