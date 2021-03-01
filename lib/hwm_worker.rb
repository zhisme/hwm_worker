require 'config/initializers'
require 'hwm_worker/version'
require 'hwm_worker/runner'
require 'capybara/session'

module HwmWorker
  def self.run
    # TODO: hack should be used in a single app not in a copies
    Runner.call(user: User.first)
  rescue StandardError => e
    raise e if ENV['APP_ENV'] == 'development'

    Rollbar.error(e)
  end
end
