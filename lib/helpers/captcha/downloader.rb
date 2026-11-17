require 'helpers/captcha/http'

##
# Download captcha by url
#
module Captcha
  module Downloader
    extend self

    class CaptchaEmpty < StandardError; end

    def call(image_url:)
      raise CaptchaEmpty if image_url.nil?

      download_captcha(image_url)
    end

    private

    def download_captcha(image_url)
      File.binwrite('captcha.png', Http.get_binary(image_url))
    end
  end
end
