require 'json'
require 'helpers/captcha/http'
require 'config/secrets'

module Captcha
  ##
  # HTTP calls to rucaptcha
  #
  class Request
    class CaptchaNotResolved < StandardError; end
    class RucaptchaInternalException < StandardError; end
    class ZeroBalanceException < StandardError; end

    RUCAPTCHA_URL = 'http://rucaptcha.com'.freeze
    SOLVE_URL = "#{RUCAPTCHA_URL}/in.php".freeze
    FETCH_URL = "#{RUCAPTCHA_URL}/res.php".freeze
    API_KEY = SECRETS['rucaptcha']['token']

    # rucaptcha API parameters: `method=base64` sends the image inline,
    # `numeric=4` asks for a 4-digit answer, `json=1` switches the response
    # from plain text to JSON.
    IMAGE_METHOD = 'base64'
    ANSWER_LENGTH = 4
    JSON_FLAG = 1

    ACTION_GET = 'get'
    ACTION_REPORT_BAD = 'reportbad'

    attr_reader :json_response

    class << self
      attr_accessor :last_captcha_id
    end

    def self.report_bad(captcha_id)
      Http.get(
        FETCH_URL,
        key: API_KEY,
        action: ACTION_REPORT_BAD,
        id: captcha_id,
        json: JSON_FLAG
      )
    end

    def initialize(base64_captcha:)
      @base64_captcha = base64_captcha
      @captcha_id = ''
    end

    def fetch
      fetch_response(
        Http.get(
          FETCH_URL,
          key: API_KEY,
          action: ACTION_GET,
          id: captcha_id,
          json: JSON_FLAG
        )
      )

      return self if success?

      raise CaptchaNotResolved
    end

    def solve
      fetch_response(
        Http.post_form(
          SOLVE_URL,
          method: IMAGE_METHOD,
          key: API_KEY,
          body: base64_captcha,
          numeric: ANSWER_LENGTH,
          json: JSON_FLAG
        )
      )
      assign_captcha_to_solve_id

      if success?
        self.class.last_captcha_id = captcha_id
        return self
      end

      handle_failure!
    end

    private

    attr_reader :captcha_id, :base64_captcha

    def fetch_response(body)
      @json_response = JSON.parse(body)
    end

    def success?
      @json_response['status'].to_s == '1'
    end

    def assign_captcha_to_solve_id
      @captcha_id = json_response['request']
    end

    def handle_failure!
      case json_response['request']
      when 'ERROR_ZERO_BALANCE'
        raise ZeroBalanceException, json_response['error_text']
      else
        raise RucaptchaInternalException, json_response.inspect
      end
    end
  end
end
