require 'helpers/captcha/http'

##
# Download captcha by url
#
module Captcha
  module Downloader
    extend self

    class CaptchaEmpty < StandardError; end

    # Returns the raw image bytes; the caller encodes and ships them to
    # rucaptcha, nothing needs to touch the filesystem.
    def call(image_url:)
      raise CaptchaEmpty if image_url.nil?

      Http.get_binary(image_url)
    end
  end
end
