# Use Ruby 3.4.1 as base image
FROM ruby:3.4.1-slim

# Install dependencies required for Chrome and gems
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    wget \
    gnupg \
    ca-certificates \
    unzip \
    libnss3 \
    libgconf-2-4 \
    libfontconfig1 \
    libxss1 \
    libappindicator3-1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libgdk-pixbuf2.0-0 \
    libnspr4 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    xdg-utils \
    fonts-liberation \
    libgbm1 \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome - download .deb directly
RUN wget -q -O /tmp/google-chrome-stable.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt-get update -qq && \
    apt-get install -y /tmp/google-chrome-stable.deb && \
    rm -rf /var/lib/apt/lists/* /tmp/google-chrome-stable.deb

# Install ChromeDriver - match Chrome version
RUN CHROME_VERSION=$(google-chrome --version | grep -oP '\d+\.\d+\.\d+') && \
    CHROME_MAJOR_VERSION=$(echo $CHROME_VERSION | cut -d. -f1) && \
    CHROMEDRIVER_VERSION=$(curl -sS "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_${CHROME_MAJOR_VERSION}") && \
    wget -O /tmp/chromedriver.zip "https://storage.googleapis.com/chrome-for-testing-public/${CHROMEDRIVER_VERSION}/linux64/chromedriver-linux64.zip" && \
    unzip /tmp/chromedriver.zip -d /tmp/ && \
    mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/ && \
    rm -rf /tmp/chromedriver.zip /tmp/chromedriver-linux64 && \
    chmod +x /usr/local/bin/chromedriver

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

# Set environment variable
ENV APP_ENV=production

# Default command (can be overridden)
CMD ["bin/run"]
