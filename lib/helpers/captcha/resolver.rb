require 'helpers/captcha/request'
require 'helpers/deadline'
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
    CaptchaDeadlineExceeded = Class.new(StandardError)

    attr_reader :solved_text, :base64_captcha

    def self.call(base64_captcha:)
      new(base64_captcha).call
    end

    def call
      request = Request.new(base64_captcha: base64_captcha)
      request.solve

      attempts = 0
      started_at = Deadline.elapsed

      WorkLogger.current.info { "captcha submitted budget_left=#{Deadline.left_for_log}" }

      begin
        attempts += 1
        sleep POLL_INTERVAL
        solved = request.fetch.json_response['request']

        WorkLogger.current.info do
          "captcha solved attempts=#{attempts} took=#{Deadline.elapsed - started_at}s " \
            "budget_left=#{Deadline.left_for_log}"
        end

        solved
      rescue Captcha::Request::CaptchaNotResolved
        if attempts >= MAX_ATTEMPTS
          raise CaptchaExceededMaxAttempts,
                "captcha unsolved after #{attempts} attempts over #{Deadline.elapsed - started_at}s"
        end

        if Deadline.exceeded?
          raise CaptchaDeadlineExceeded,
                "gave up polling rucaptcha after #{attempts} attempts over " \
                "#{Deadline.elapsed - started_at}s, job budget exhausted"
        end

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
