require 'hwm_worker/login'
require 'hwm_worker/hunt'
require 'models/user'

class AutoHunt
  def self.call(user:)
    new(user).call
  end

  def call
    WorkLogger.current.info { "Sleeping for #{sleep_time}" }
    sleep sleep_time

    WorkLogger.current.info { "Try to login with #{user.login}" }
    Login.call(session: session, user: user)

    WorkLogger.current.info { "Auto hunt started for #{user.login}" }
    Hunt.call(session: session, user: user)
  end

  private

  attr_reader :session, :user, :sleep_time

  def initialize(user)
    session_mode = SECRETS['capybara']['session'].to_sym || :selenium_chrome_headless

    @session = Capybara::Session.new(session_mode)
    @user = user
    @sleep_time = WorkTime.hunt_wait_time
  end
end
