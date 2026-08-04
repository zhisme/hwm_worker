require 'helpers/captcha/request'
require 'helpers/work_logger'

module Captcha
  ##
  # Resolve captcha by sending it to rucaptcha
  #
  class Resolver
    # Poll res.php instead of waiting a fixed worst-case delay. Budget is
    # POLL_INTERVAL * MAX_ATTEMPTS = 90s, which must stay under both the
    # selenium session idle timeout and kubernetes.activeDeadlineSeconds.
    POLL_INTERVAL = 5
    MAX_ATTEMPTS = 18

    CaptchaExceededMaxAttempts = Class.new(StandardError)

    attr_reader :solved_text, :base64_captcha

    def self.call(base64_captcha:)
      new(base64_captcha).call
    end

    def call
      request = Request.new(base64_captcha: base64_captcha)
      request.solve

      attempts = 0

      begin
        attempts += 1
        sleep POLL_INTERVAL
        request.fetch.json_response['request']
      rescue Captcha::Request::CaptchaNotResolved
        raise CaptchaExceededMaxAttempts if attempts >= MAX_ATTEMPTS

        WorkLogger.current.debug { "captcha not resolved yet, attempt #{attempts}/#{MAX_ATTEMPTS}" }
        retry
      end
    end

    private

    def initialize(base64_captcha)
      @base64_captcha = base64_captcha
      @solved_text = ''
    end
  end
end
