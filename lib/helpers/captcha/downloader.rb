require 'open-uri'

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
      File.open('captcha.png', 'wb') do |fo|
        fo.write URI.open(image_url).read
      end
    end
  end
end
