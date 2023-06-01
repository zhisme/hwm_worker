require 'rest-client'
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

    attr_reader :json_response

    def initialize(base64_captcha:)
      @base64_captcha = base64_captcha
      @captcha_id = ''
    end

    def fetch
      fetch_response(fetch_request)

      return self if success?

      raise CaptchaNotResolved
    end

    def solve
      fetch_response(solve_request)
      assign_captcha_to_solve_id

      return self if success?

      handle_failure!
    end

    private

    attr_reader :action, :captcha_id, :base64_captcha

    def solve?
      action == :solve
    end

    def fetch_response(request)
      response = request.execute
      @json_response = JSON.parse response.body
    end

    def success?
      @json_response['status'].to_s == '1'
    end

    def solve_request
      RestClient::Request.new(
        method: :post,
        url: SOLVE_URL,
        payload: {
          method: 'base64',
          key: API_KEY,
          body: base64_captcha,
          numeric: 4,
          json: 1,
        }
      )
    end

    def assign_captcha_to_solve_id
      @captcha_id = json_response['request']
    end

    def fetch_request
      RestClient::Request.new(
        method: :get,
        url: "#{FETCH_URL}?key=#{API_KEY}&action=get&id=#{captcha_id}&json=1"
      )
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
