require 'helpers/captcha/resolver'
require 'helpers/captcha/encoder'
require 'helpers/captcha/downloader'

module Captcha
  ##
  # All stuff going to captcha goes here
  #    Pass image_url from src <image src='http://heroeswm.ru/work_codes/xxx.png'>
  #    Retrieve string with solved captcha
  #
  module Main
    extend self

    def call(image_url:)
      image_data = Downloader.call(image_url: image_url)
      encoder = Encoder.call(image_data)
      resolved = Resolver.call(base64_captcha: encoder.base64_captcha)

      resolved
    end
  end
end
