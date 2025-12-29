# frozen_string_literal: true

require 'rest-client'
require 'json'
require 'config/secrets'
require_relative 'base'
require_relative '../message_formatter'

module SystemNotifications
  module Providers
    class Telegram < Base
      TELEGRAM_API_URL = 'https://api.telegram.org'

      def self.call(notification)
        return unless enabled?

        new(notification).send_message
      end

      def self.enabled?
        bot_token.to_s != '' && chat_id.to_s != ''
      end

      def self.bot_token
        SECRETS.dig('telegram', 'bot_token')
      end

      def self.chat_id
        SECRETS.dig('telegram', 'chat_id')
      end

      def initialize(notification)
        @notification = notification
      end

      def send_message
        RestClient::Request.new(
          method: :post,
          url: api_url,
          payload: payload,
          headers: { content_type: :json }
        ).execute
      end

      private

      attr_reader :notification

      def api_url
        "#{TELEGRAM_API_URL}/bot#{self.class.bot_token}/sendMessage"
      end

      def payload
        {
          chat_id: self.class.chat_id,
          text: formatted_message,
          parse_mode: 'Markdown'
        }.to_json
      end

      def formatted_message
        MessageFormatter.call(notification, format: :telegram)
      end
    end
  end
end
