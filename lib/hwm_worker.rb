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
    SystemNotifications.notify_error(e, provider: :telegram, worker_name: 'work', user: User.first)
    Rollbar.error(e)
    exit(1)
  rescue StandardError => e
    raise e if ENV['APP_ENV'] == 'development'

    SystemNotifications.notify_error(e, provider: :telegram, worker_name: 'work', user: User.first)
    Rollbar.error(e)
  end

  def self.hunt
    AutoHunt.call(user: User.first)
  rescue Captcha::Request::ZeroBalanceException => e
    SystemNotifications.notify_error(e, provider: :telegram, worker_name: 'hunt', user: User.first)
    Rollbar.error(e)
    exit(1)
  rescue StandardError => e
    raise e if ENV['APP_ENV'] == 'development'

    SystemNotifications.notify_error(e, provider: :telegram, worker_name: 'hunt', user: User.first)
    Rollbar.error(e)
  end
end
