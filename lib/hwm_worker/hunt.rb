# frozen_string_literal: true

require 'config/urls'
require 'helpers/work_logger'

##
# Do auto hunt
#
module Hunt
  extend self

  class AutoItemNotFound < StandardError; end
  class AutoHuntBroken < StandardError; end

  HUNT_URL = "#{HEROESWM_URL}/map.php".freeze
  AUTO_BUTTON_TEXT = 'Автобой'.freeze

  # The battle report wording follows the account language, so both locales.
  WIN_MARKERS = ['Победа', 'Victory'].freeze
  LOSS_MARKERS = ['Поражение', 'Defeat'].freeze

  # Skill gained is rendered next to the word, as "+0.34 умения" or
  # "skill: 0.34". Either order appears depending on the report layout.
  SKILL_AFTER = /(?:умени[а-яё]*|skill)\s*:?\s*\+?(\d+(?:[.,]\d+)?)/i
  SKILL_BEFORE = /\+?(\d+(?:[.,]\d+)?)\s*(?:умени[а-яё]*|skill)/i

  # The workaholic penalty is cleared by a win worth 0.5 skill; below that the
  # game credits one penalty-free job per 0.05 skill.
  QUALIFYING_SKILL = 0.5
  SKILL_PER_JOB = 0.05

  # The battle report replaces the page once the submit lands. Unknown report
  # markup must not hang the run, so this is the longest we wait for it.
  REPORT_WAIT = 30

  def call(session:, user:)
    start_hunt(session, user)
  end

  ##
  # Summarises a battle report page text.
  #
  def result(text)
    outcome = if text.match?(Regexp.union(WIN_MARKERS))
                'win'
              elsif text.match?(Regexp.union(LOSS_MARKERS))
                'loss'
              else
                'unknown'
              end

    skill = text[SKILL_AFTER, 1] || text[SKILL_BEFORE, 1]
    skill = skill&.tr(',', '.')&.to_f
    credits = (skill / SKILL_PER_JOB + 1e-6).floor if skill

    {
      outcome: outcome,
      skill: skill,
      qualifies: outcome == 'win' && !skill.nil? && skill >= QUALIFYING_SKILL,
      credits: credits,
    }
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
    log_result(session, user)
  rescue Selenium::WebDriver::Error::ElementNotInteractableError, Capybara::ElementNotFound
    raise AutoItemNotFound
  end

  def log_result(session, user)
    session.has_text?(Regexp.union(WIN_MARKERS + LOSS_MARKERS), wait: REPORT_WAIT)
    summary = result(session.text)

    WorkLogger.current.info do
      "autohunt user=#{user.login} result=#{summary[:outcome]} " \
        "skill=#{summary[:skill] || 'unknown'} qualifies=#{summary[:qualifies]} " \
        "credits=#{summary[:credits] || 'unknown'}"
    end
    Rollbar.info("#{user.login} performed an autohunt.")
    summary
  end

  def assert_correct_hunt_btn!(hunt_text)
    return true if hunt_text == AUTO_BUTTON_TEXT

    raise AutoHuntBroken, "autobattle button hint is #{hunt_text.inspect}, expected #{AUTO_BUTTON_TEXT.inspect}"
  end
end
