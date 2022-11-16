# frozen_string_literal: true

require 'config/urls'

##
# Do auto hunt
#
module Hunt
  extend self

  class AutoItemNotFound < StandardError; end
  class AutoHuntBroken < StandardError; end

  HUNT_URL = "#{HEROESWM_URL}/map.php".freeze
  AUTO_BUTTON_TEXT = 'Автобой'.freeze

  def call(session:, user:)
    start_hunt(session, user)
  end

  private

  def start_hunt(session, user)
    session.visit(HUNT_URL)
    selector = '#neut_right_block > div.map_buttons_container > div:nth-child(2)'
    hunt_link = session.find(selector)
    hunt_text = hunt_link[:hint]

    assert_correct_hunt_btn!(hunt_text)

    hunt_link.click
    sleep 15
    session.find('form > input[type=submit]').click
    Rollbar.info("#{user.login} successfully performed autohunt.")
  rescue Selenium::WebDriver::Error::ElementNotInteractableError, Capybara::ElementNotFound
    raise AutoItemNotFound
  end

  def assert_correct_hunt_btn!(hunt_text)
    return true if hunt_text == AUTO_BUTTON_TEXT

    raise AutoHuntBroken
  end
end
