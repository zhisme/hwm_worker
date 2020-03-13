require 'config/urls'
require 'helpers/captcha/main'
require 'helpers/file_base'

##
# Find available work
#
module Work
  extend self

  class NoAvailableWork < StandardError; end

  WORK_URL = HEROESWM_URL + 'map.php'

  def call(session:, user:)
    find_work(session)
    apply_work(session, user)
  end

  private

  def apply_work(session, user)
    captcha = session.find('[name="working"] table tbody tr:nth-child(2) td.wb img')
    solved_captcha = Captcha::Main.call(image_url: captcha[:src])

    session.within '[name="working"]' do
      session.fill_in 'code', with: solved_captcha
    end

    session.find('#wbtn').click

    WorkLogger.current.info { "#{user.login} successfully applied for a job. Wait hour." }
    Rollbar.info("#{user.login} successfully applied for a job.")
    FileBase.write_last_work(user.id)
  end

  def find_work(session)
    session.visit(WORK_URL)
    work_link = session.find('table.wb tr:nth-child(2) td:nth-child(6) a')
    work_link.assert_text('»»»')
    work_link.click
  rescue Selenium::WebDriver::Error::ElementNotInteractableError,
         Selenium::WebDriver::Error::ElementNotSelectableError
    raise NoAvailableWork
  end
end
