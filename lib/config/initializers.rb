require 'capybara'
require 'rollbar'
require 'config/secrets'
require 'selenium/webdriver'

Rollbar.configure do |config|
  config.access_token = SECRETS['rollbar']['token']
end

# Configure Capybara for Docker-friendly Chrome
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  # Docker-specific Chrome options
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--disable-software-rasterizer')
  options.add_argument('--window-size=1920,1080')

  # Use the installed Chrome binary
  options.binary = '/usr/local/bin/google-chrome'

  # Create service with explicit chromedriver path
  service = Selenium::WebDriver::Service.chrome(path: '/usr/local/bin/chromedriver')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service)
end

Capybara.register_driver :selenium_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  # Docker-specific Chrome options (same as headless but without --headless)
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1920,1080')

  # Use the installed Chrome binary
  options.binary = '/usr/local/bin/google-chrome'

  # Create service with explicit chromedriver path
  service = Selenium::WebDriver::Service.chrome(path: '/usr/local/bin/chromedriver')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options, service: service)
end

