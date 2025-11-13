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
    && rm -rf /var/lib/apt/lists/*

# Install Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update -qq && \
    apt-get install -y google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# Install ChromeDriver
RUN CHROMEDRIVER_VERSION=$(curl -sS chromedriver.storage.googleapis.com/LATEST_RELEASE) && \
    wget -O /tmp/chromedriver.zip https://chromedriver.storage.googleapis.com/$CHROMEDRIVER_VERSION/chromedriver_linux64.zip && \
    unzip /tmp/chromedriver.zip -d /usr/local/bin/ && \
    rm /tmp/chromedriver.zip && \
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
