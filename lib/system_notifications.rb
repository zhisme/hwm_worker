# frozen_string_literal: true

require_relative 'system_notifications/notification'
require_relative 'system_notifications/notifier'
require_relative 'system_notifications/message_formatter'
require_relative 'system_notifications/providers/base'
require_relative 'system_notifications/providers/telegram'
require_relative 'system_notifications/providers/email'

module SystemNotifications
  DEFAULT_SOURCE = 'HWM_WORKER'

  class << self
    def critical!(provider:, title:, message:, **context)
      notify(level: :critical, provider: provider, title: title, message: message, **context)
    end

    def error!(provider:, title:, message:, **context)
      notify(level: :error, provider: provider, title: title, message: message, **context)
    end

    def warning!(provider:, title:, message:, **context)
      notify(level: :warning, provider: provider, title: title, message: message, **context)
    end

    private

    def notify(level:, provider:, title:, message:, **context)
      notification = Notification.new(
        level: level,
        title: title,
        message: message,
        source: context.fetch(:source, DEFAULT_SOURCE),
        worker_name: context[:worker_name],
        user_login: context[:user_login],
        error: context[:error],
        occurred_at: context[:occurred_at]
      )

      Notifier.call(notification, provider: provider)
    end
  end
end
