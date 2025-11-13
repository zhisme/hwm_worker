require 'capybara'
require 'rollbar'
require 'config/secrets'
require 'selenium/webdriver'

Rollbar.configure do |config|
  config.access_token = SECRETS['rollbar']['token']
end

# Determine Selenium URL based on environment
SELENIUM_URL = ENV['SELENIUM_URL'] || 'http://selenium:4444'

# Configure Capybara to use Remote Selenium
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1920,1080')

  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: SELENIUM_URL,
    options: options
  )
end

Capybara.register_driver :selenium_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1920,1080')

  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: SELENIUM_URL,
    options: options
  )
end

