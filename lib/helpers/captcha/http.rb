require 'net/http'
require 'uri'

module Captcha
  ##
  # Tiny Net::HTTP wrapper for the rucaptcha calls: explicit timeouts, one
  # retry on 5xx/transport errors, body returned as a string.
  #
  # Replaced RestClient (issue #95): it maps status codes through an internal
  # table, so a 521 from Cloudflare surfaced as a raw KeyError instead of an
  # error callers can rescue.
  #
  module Http
    extend self

    class HttpError < StandardError; end

    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 20
    WRITE_TIMEOUT = 20
    RETRIES = 1

    TRANSPORT_ERRORS = [
      Timeout::Error,
      SystemCallError,
      IOError,
      EOFError,
      OpenSSL::SSL::SSLError
    ].freeze

    def get(url, params = {})
      uri = URI(url)
      uri.query = URI.encode_www_form(params) if params.any?

      run(uri, Net::HTTP::Get.new(uri))
    end

    def get_binary(url)
      uri = URI(url)

      run(uri, Net::HTTP::Get.new(uri), binary: true)
    end

    def post_form(url, form)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(form)

      run(uri, request)
    end

    private

    # shortcut: fixed 1s pause between the two attempts, tune if rucaptcha's
    # 5xx windows turn out to be longer.
    def run(uri, request, binary: false, retries: RETRIES)
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == 'https',
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT,
        write_timeout: WRITE_TIMEOUT
      ) do |http|
        http.request(request)
      end

      return response.body.to_s.b if binary && response.is_a?(Net::HTTPSuccess)
      return response.body.to_s if response.is_a?(Net::HTTPSuccess)

      raise HttpError, http_error_message(response, uri) unless response.is_a?(Net::HTTPServerError) && retries.positive?

      sleep 1
      run(uri, request, binary: binary, retries: retries - 1)
    rescue *TRANSPORT_ERRORS
      raise unless retries.positive?

      sleep 1
      run(uri, request, binary: binary, retries: retries - 1)
    end

    def http_error_message(response, uri)
      "HTTP #{response.code} for #{uri.host}#{uri.path}"
    end
  end
end
