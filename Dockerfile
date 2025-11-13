# Use Ruby 3.4.1 as base image (full, not slim, for Chrome dependencies)
FROM ruby:3.4.1

# Install system dependencies and Chrome dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    wget \
    gnupg \
    ca-certificates \
    unzip \
    jq \
    # Chrome dependencies
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libexpat1 \
    libfontconfig1 \
    libgbm1 \
    libgcc-s1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxkbcommon0 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    lsb-release \
    xdg-utils \
    libu2f-udev \
    libvulkan1 \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome for Testing and ChromeDriver
RUN CHROME_VERSION=$(curl -s https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json | jq -r '.channels.Stable.version') && \
    wget -q -O /tmp/chrome-linux64.zip "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chrome-linux64.zip" && \
    wget -q -O /tmp/chromedriver-linux64.zip "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chromedriver-linux64.zip" && \
    unzip -q /tmp/chrome-linux64.zip -d /opt/ && \
    unzip -q /tmp/chromedriver-linux64.zip -d /opt/ && \
    mv /opt/chrome-linux64/chrome /usr/local/bin/google-chrome && \
    mv /opt/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver && \
    chmod +x /usr/local/bin/google-chrome /usr/local/bin/chromedriver && \
    rm -rf /tmp/chrome-linux64.zip /tmp/chromedriver-linux64.zip /opt/chrome-linux64 /opt/chromedriver-linux64 && \
    # Verify installations
    google-chrome --version && \
    chromedriver --version

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
RUN mkdir -p logs file_base

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
