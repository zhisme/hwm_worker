require 'hwm_worker/login'
require 'hwm_worker/work'
require 'helpers/work_time'
require 'helpers/deadline'
require 'models/user'

class Runner
  # Worst case cost of login, navigation and the captcha round trip. If the
  # cooldown sleep would not leave this much, the run cannot finish and is
  # skipped instead of getting SIGTERMed mid-submit.
  #
  # Measured work time after the cooldown sleep sits at 197-215s, so 240 keeps
  # a margin without skipping runs that would have finished.
  WORK_BUDGET = 240

  def self.call(user:)
    new(user).call
  end

  def call
    wait = WorkTime.wait_time(user.id)

    log_phase('start', "cooldown_wait=#{wait}s work_budget=#{WORK_BUDGET}s")

    if wait + WORK_BUDGET > Deadline.left
      log_phase('skip', "reason=budget cooldown_wait=#{wait}s work_budget=#{WORK_BUDGET}s")
      return
    end

    WorkLogger.current.info { "Sleeping for #{wait}." }
    sleep wait
    log_phase('slept', "cooldown_wait=#{wait}s")

    WorkLogger.current.info { "Try to login with #{user.login}" }
    Login.call(session: session, user: user)
    log_phase('login_done')

    WorkLogger.current.info { "Try to apply for a job with #{user.login}" }
    Work.call(session: session, user: user)
    log_phase('done', 'outcome=applied')
  rescue StandardError => e
    log_phase('done', "outcome=failed error=#{e.class}")
    raise
  end

  private

  attr_reader :session, :user

  ##
  # One greppable line per phase so runs can be compared over time:
  #   run phase=login_done user=xa4ba4 elapsed=95s budget_left=525s
  #
  def log_phase(phase, extra = nil)
    WorkLogger.current.info do
      [
        "run phase=#{phase} user=#{user.login}",
        "elapsed=#{Deadline.elapsed}s budget_left=#{Deadline.left_for_log}",
        extra,
      ].compact.join(' ')
    end
  end

  def initialize(user)
    session_mode = SECRETS['capybara']['session'].to_sym || :selenium_chrome_headless

    @session = Capybara::Session.new(session_mode)
    @user = user
  end
end
