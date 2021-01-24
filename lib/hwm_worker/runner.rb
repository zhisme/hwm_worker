require 'hwm_worker/login'
require 'hwm_worker/work'
require 'helpers/work_time'
require 'models/user'

class Runner
  def self.call(user:)
    new(user).call
  end

  def call
    WorkLogger.current.info { "Sleeping for #{WorkTime.wait_time(user.id)}." }
    sleep WorkTime.wait_time(user.id)

    WorkLogger.current.info { "Try to login with #{user.login}" }
    Login.call(session: session, user: user)

    WorkLogger.current.info { "Try to apply for a job with #{user.login}" }
    Work.call(session: session, user: user)
  end

  private

  attr_reader :session, :user

  def initialize(user)
    @session = Capybara::Session.new(:selenium_chrome)
    @user = user
  end
end
