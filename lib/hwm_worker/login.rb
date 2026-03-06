require 'config/urls'
require 'helpers/captcha/main'
require 'helpers/work_logger'

##
# Login to heroeswm.ru
#
module Login
  extend self

  class LoginInvalid < StandardError; end

  UNSUCCESS_LOGIN_URL = HEROESWM_URL + 'login.php'
  CAPTCHA_IMG_SELECTOR = 'form > table > tbody > tr:nth-child(4) > td > table > tbody > tr > td:nth-child(1) > img'

  def call(session:, user:)
    login(session, user)

    return session if logged_in?(session)

    if captcha_present?(session)
      login_with_captcha(session, user)
    end

    WorkLogger.current.fatal { "#{user.login} is invalid." }
    raise LoginInvalid unless logged_in?(session)
    session
  end

  private

  def login_with_captcha(session, user)
    captcha_el = session.find(CAPTCHA_IMG_SELECTOR)
    image_url = HEROESWM_URL + captcha_el[:src]
    solved_captcha = Captcha::Main.call(image_url: image_url)

    session.within 'form' do
      session.fill_in 'pcode', with: solved_captcha
      session.fill_in 'pass', with: user.password
    end

    session.find('.entergame input').click
  end

  def login(session, user)
    session.visit HEROESWM_URL
    session.within 'form' do
      session.fill_in 'login', with: user.login
      session.fill_in 'pass', with: user.password
    end

    session.find('.entergame input').click
  end

  def logged_in?(session)
    session.current_url != UNSUCCESS_LOGIN_URL
  end

  def captcha_present?(session)
    session.has_css?(CAPTCHA_IMG_SELECTOR)
  end
end
