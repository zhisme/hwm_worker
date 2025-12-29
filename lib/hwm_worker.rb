require 'config/initializers'
require 'hwm_worker/version'
require 'hwm_worker/runner'
require 'hwm_worker/auto_hunt'
require 'capybara/session'
require 'helpers/captcha/request'
require 'system_notifications'

module HwmWorker
  def self.run
    # TODO: hack should be used in a single app not in a copies
    Runner.call(user: User.first)
  rescue Captcha::Request::ZeroBalanceException => e
    handle_zero_balance_error(e, worker_name: 'work')
  rescue StandardError => e
    raise e if ENV['APP_ENV'] == 'development'

    notify_error(e, worker_name: 'work')
    Rollbar.error(e)
  end

  def self.hunt
    AutoHunt.call(user: User.first)
  rescue Captcha::Request::ZeroBalanceException => e
    handle_zero_balance_error(e, worker_name: 'hunt')
  rescue StandardError => e
    raise e if ENV['APP_ENV'] == 'development'

    notify_error(e, worker_name: 'hunt')
    Rollbar.error(e)
  end

  def self.handle_zero_balance_error(error, worker_name:)
    error_message = "Rucaptcha service has insufficient balance: #{error.message}"

    # Send critical notification
    SystemNotifications.critical!(
      provider: :telegram,
      title: error.class.name,
      message: error_message,
      worker_name: worker_name,
      user_login: User.first&.login,
      error: error
    )

    # Log to stdout
    puts "ERROR: #{error_message}"

    # Report to Rollbar
    Rollbar.error(error, message: error_message)

    # Exit the application
    exit(1)
  end

  def self.notify_error(error, worker_name:)
    level = classify_error_level(error)

    SystemNotifications.public_send(
      :"#{level}!",
      provider: :telegram,
      title: error.class.name,
      message: error.message,
      worker_name: worker_name,
      user_login: User.first&.login,
      error: error
    )
  end

  def self.classify_error_level(error)
    case error
    when Captcha::Request::ZeroBalanceException
      :critical
    when Login::LoginInvalid,
         Work::CannotApplyForJobError,
         Hunt::AutoHuntBroken,
         Hunt::AutoItemNotFound
      :error
    when Work::NoAvailableWork
      :warning
    else
      :error
    end
  end
end
