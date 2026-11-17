require 'base64'

module Captcha
  ##
  # Encode captcha in order to send to rucaptcha
  #
  class Encoder
    attr_reader :base64_captcha

    def self.call(image_data)
      new(image_data).call
    end

    def initialize(image_data)
      @image_data = image_data
    end

    def call
      @base64_captcha = Base64.encode64(@image_data)
      self
    end
  end
end
