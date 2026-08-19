require 'config/urls'
require 'helpers/captcha/main'
require 'helpers/deadline'
require 'helpers/file_base'

##
# Find available work
#
module Work
  extend self

  HOUR = 60 * 60

  class NoAvailableWork < StandardError; end
  class CannotApplyForJobError < StandardError; end
  class NotAppliedForJobError < StandardError; end
  class AppliedTooEarlyError < StandardError; end

  WORK_URL = "#{HEROESWM_URL}/map.php".freeze

  # The facility page renders one of these once the character holds the job, so
  # any of them proves the submit landed. Locale of the page follows the account
  # language, hence both the English and Russian wording.
  EMPLOYED_MARKERS = [
    'You are already employed.',
    'Вы уже устроены.',
  ].freeze

  EMPLOYED_PATTERN = Regexp.union(EMPLOYED_MARKERS).freeze

  # Rejection: the submit reached the server before the hourly cooldown was
  # over, so no job was taken and this hour earns nothing.
  TOO_EARLY_MARKER = 'Прошло меньше часа с последнего устройства на работу. Ждите.'.freeze

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
    assert_employed(session, user)
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

    assert_employed(session, user)
    WorkLogger.current.info { "#{user.login} successfully applied for a job. Wait hour." }
    log_gold(session, user)
    log_interval(user)
    Rollbar.info("#{user.login} successfully applied for a job.")
    FileBase.write_last_work(user.id)
  rescue Capybara::ElementNotFound => e
    raise CannotApplyForJobError, "Cannot apply for job (with captcha): #{e.message}"
  end

  ##
  # A submit that silently fails (wrong captcha, cooldown not over yet) still
  # renders the facility page, so only the employed marker proves the job was
  # taken. Without it nothing must be written to FileBase, otherwise the next
  # run waits an hour for a job it never got.
  #
  def assert_employed(session, user)
    # One waiting matcher for all wordings, so a missing marker costs a single
    # Capybara wait instead of one per variant.
    return if session.has_text?(EMPLOYED_PATTERN)

    # No wait here: the page is already loaded, this only reads which rejection
    # it carries.
    if session.has_text?(TOO_EARLY_MARKER, wait: 0)
      raise AppliedTooEarlyError,
            "#{user.login} submitted before the cooldown was over, no job taken"
    end

    raise NotAppliedForJobError, "#{user.login} was not employed after submit, marker text missing"
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
      "applied user=#{user.login} interval=#{interval}s over_cooldown=#{interval - HOUR}s"
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
