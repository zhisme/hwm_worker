# frozen_string_literal: true

require_relative 'notification'
require_relative 'providers/base'
require_relative 'providers/telegram'
require_relative 'providers/email'

module SystemNotifications
  class Notifier
    PROVIDER_MAP = {
      telegram: Providers::Telegram,
      email: Providers::Email
    }.freeze

    def self.call(notification, provider:)
      new(notification, provider).call
    end

    def initialize(notification, provider)
      @notification = notification
      @provider = resolve_provider(provider)
    end

    def call
      unless @provider.enabled?
        log_warning("#{@provider.name} is not enabled, skipping notification")
        return
      end

      @provider.call(@notification)
    rescue StandardError => e
      log_error("#{@provider.name} failed: #{e.message}")
    end

    private

    def resolve_provider(provider)
      case provider
      when Symbol
        PROVIDER_MAP.fetch(provider) do
          raise ArgumentError, "Unknown provider: #{provider}. Available: #{PROVIDER_MAP.keys.join(', ')}"
        end
      when Class
        provider
      else
        raise ArgumentError, "Invalid provider: #{provider}. Must be a Symbol or Class."
      end
    end

    def log_warning(message)
      puts "[SystemNotifications] WARNING: #{message}"
    end

    def log_error(message)
      puts "[SystemNotifications] ERROR: #{message}"
    end
  end
end
