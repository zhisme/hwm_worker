require 'config/urls'
require 'helpers/captcha/main'
require 'helpers/deadline'
require 'helpers/file_base'
require 'helpers/work_time'

##
# Find available work
#
module Work
  extend self

  class NoAvailableWork < StandardError; end
  class CannotApplyForJobError < StandardError; end

  WORK_URL = "#{HEROESWM_URL}/map.php".freeze

  def call(session:, user:)
    find_work(session)
    apply_work(session, user)
  end

  private

  def apply_work(session, user)
    captcha_el = session.find('[name="work"] img.getjob_capcha')

    WorkLogger.current.info { "apply user=#{user.login} branch=captcha budget_left=#{Deadline.left_for_log}" }
    apply_work_with_captcha(session, user, captcha_el)
  rescue Capybara::ElementNotFound
    WorkLogger.current.info { "apply user=#{user.login} branch=manual budget_left=#{Deadline.left_for_log}" }
    apply_work_without_captcha(session, user)
  end

  def apply_work_without_captcha(session, user)
    session.find('input.getjob_submitBtn').click
    WorkLogger.current.info { "#{user.login} successfully applied for a job. Wait hour." }
    log_gold(session, user)
    log_interval(user)
    Rollbar.info("#{user.login} successfully applied for a job.")
    FileBase.write_last_work(user.id)
  rescue Capybara::ElementNotFound => e
    raise CannotApplyForJobError, "Cannot apply for job (manual): #{e.message}"
  end

  def apply_work_with_captcha(session, user, captcha_el)
    solved_captcha = Captcha::Main.call(image_url: captcha_el[:src])

    session.find('#code').click
    session.find('#code').fill_in(with: solved_captcha)

    session.find('.getjob_submitBtn').click

    WorkLogger.current.info { "#{user.login} successfully applied for a job. Wait hour." }
    log_gold(session, user)
    log_interval(user)
    Rollbar.info("#{user.login} successfully applied for a job.")
    FileBase.write_last_work(user.id)
  rescue Capybara::ElementNotFound => e
    raise CannotApplyForJobError, "Cannot apply for job (with captcha): #{e.message}"
  end

  ##
  # Gap between this application and the previous one. Should sit just above
  # HOUR; a much larger gap means an hourly run was skipped or failed.
  #
  def log_interval(user)
    last_work = FileBase.last_work(user.id)

    if last_work.nil?
      WorkLogger.current.info { "applied user=#{user.login} interval=none" }
      return
    end

    interval = Time.now.to_i - last_work.to_i
    WorkLogger.current.info do
      "applied user=#{user.login} interval=#{interval}s over_cooldown=#{interval - WorkTime::HOUR}s"
    end
  end

  def log_gold(session, user)
    gold_text = session.find('img[hwm_label="Золото"] + span').text(:all)
    WorkLogger.current.info { "#{user.login} current gold: #{gold_text}" }
  rescue Capybara::ElementNotFound
    WorkLogger.current.info { "#{user.login} could not parse gold amount" }
  end

  def find_work(session)
    session.visit(WORK_URL)
    work_link = session.find('table.wb tr:nth-child(3) td:last-child a')
    work_link.assert_text('»»»')
    work_link.click
  rescue Selenium::WebDriver::Error::ElementNotInteractableError
    raise NoAvailableWork
  end
end
