require 'config/initializers'
require 'hwm_worker/version'
require 'hwm_worker/runner'
require 'hwm_worker/auto_hunt'
require 'capybara/session'
require 'helpers/captcha/request'

module HwmWorker
  def self.run
    # TODO: hack should be used in a single app not in a copies
    Runner.call(user: User.first)
  rescue Captcha::Request::ZeroBalanceException => e
    handle_zero_balance_error(e)
  rescue StandardError => e
    raise e if ENV['APP_ENV'] == 'development'

    Rollbar.error(e)
  end

  def self.hunt
    AutoHunt.call(user: User.first)
  rescue Captcha::Request::ZeroBalanceException => e
    handle_zero_balance_error(e)
  rescue StandardError => e
    raise e if ENV['APP_ENV'] == 'development'

    Rollbar.error(e)
  end

  def self.handle_zero_balance_error(error)
    error_message = "Rucaptcha service has insufficient balance: #{error.message}"

    # Log to stdout
    puts "ERROR: #{error_message}"

    # Report to Rollbar
    Rollbar.error(error, message: error_message)

    # Exit the application
    exit(1)
  end
end
