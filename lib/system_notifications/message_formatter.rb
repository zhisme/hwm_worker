# frozen_string_literal: true

module SystemNotifications
  class MessageFormatter
    LEVEL_EMOJIS = {
      critical: "\u{1F534}", # Red circle
      error: "\u{1F7E0}",    # Orange circle
      warning: "\u{1F7E1}"   # Yellow circle
    }.freeze

    def self.call(notification, format:)
      new(notification, format).format
    end

    def initialize(notification, format)
      @notification = notification
      @format = format
    end

    def format
      case @format
      when :telegram
        format_telegram
      else
        raise ArgumentError, "Unknown format: #{@format}"
      end
    end

    private

    attr_reader :notification

    def format_telegram
      lines = []
      lines << header_line
      lines << ''
      lines << "*Source:* #{escape_markdown(notification.source)}"
      lines << "*Worker:* #{escape_markdown(notification.worker_name)}" if notification.worker_name
      lines << "*User:* #{escape_markdown(notification.user_login)}" if notification.user_login
      lines << "*Time:* #{format_time}"
      lines << ''
      lines << '*Message:*'
      lines << escape_markdown(notification.message)

      if notification.stack_trace
        lines << ''
        lines << '*Stack trace:*'
        notification.stack_trace.each do |line|
          lines << "`#{escape_markdown(line)}`"
        end
      end

      lines.join("\n")
    end

    def header_line
      emoji = LEVEL_EMOJIS[notification.level]
      level_text = notification.level.to_s.upcase
      "#{emoji} #{level_text}: #{escape_markdown(notification.title)}"
    end

    def format_time
      notification.occurred_at.utc.strftime('%Y-%m-%d %H:%M UTC')
    end

    def escape_markdown(text)
      return text unless text

      # Escape Telegram Markdown special characters: _ * [ ] ( ) ~ ` > # + - = | { } . !
      # For basic Markdown mode, we mainly need to escape: _ * ` [
      text.to_s.gsub(/([_*`\[\]])/, '\\\\\1')
    end
  end
end
