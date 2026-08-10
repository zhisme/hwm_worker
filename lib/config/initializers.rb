# Disable stdout/stderr buffering for real-time logs in containers, kibana usage
$stdout.sync = true
$stderr.sync = true

require 'capybara'
require 'rollbar'
require 'config/secrets'
require 'helpers/deadline'
require 'selenium/webdriver'

# Start the job budget clock as early as possible.
Deadline.start!

Rollbar.configure do |config|
  config.access_token = SECRETS['rollbar']['token']
end

# Determine Selenium URL based on environment
SELENIUM_URL = ENV['SELENIUM_URL'] || 'http://selenium:4444'

CHROME_ARGS = [
  '--no-sandbox',
  '--disable-dev-shm-usage',
  '--disable-gpu',
  '--window-size=1920,1080',
  '--disable-extensions',
  '--disable-background-networking',
  '--disable-sync',
  '--no-first-run',
  '--disable-default-apps',
  '--disable-notifications',
  '--js-flags=--max-old-space-size=128',
].freeze

# Configure Capybara to use Remote Selenium
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  CHROME_ARGS.each { |arg| options.add_argument(arg) }

  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: SELENIUM_URL,
    capabilities: options
  )
end

Capybara.register_driver :selenium_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  CHROME_ARGS.each { |arg| options.add_argument(arg) }

  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: SELENIUM_URL,
    capabilities: options
  )
end
