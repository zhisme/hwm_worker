require 'config/urls'

##
# Do auto hunt
#
module Hunt
  extend self

  class AutoItemNotFound < StandardError; end
  class AutoHuntBroken < StandardError; end

  HUNT_URL = "#{HEROESWM_URL}/map.php".freeze

  def call(session:, user:)
    start_hunt(session, user)
  end

  private

  def start_hunt(session, user)
    session.visit(HUNT_URL)
    selector = '#neut_right_block > div.map_buttons_container > div:nth-child(2)'
    hunt_link = session.find(selector)
    hunt_text = session.all("#{selector} .ntooltiptext", visible: false).first.text(:all)

    assert_correct_hunt_btn!(hunt_text)

    hunt_link.click
    session.find('form > input[type=submit]').click
    WorkLogger.current.info { "#{user.login} finished auto hunt" }
  rescue Selenium::WebDriver::Error::ElementNotInteractableError
    raise AutoItemNotFound
  end

  def assert_correct_hunt_btn!(hunt_text)
    return true if hunt_text == 'Автобой'

    raise AutoHuntBroken
  end
end
