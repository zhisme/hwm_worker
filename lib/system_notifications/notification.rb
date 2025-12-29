# frozen_string_literal: true

module SystemNotifications
  class Notification
    LEVELS = %i[critical error warning].freeze
    DEFAULT_SOURCE = 'HWM_WORKER'
    STACK_TRACE_LIMIT = 5

    attr_reader :level, :title, :message, :source, :worker_name, :user_login, :error, :occurred_at

    def initialize(level:, title:, message:, source: DEFAULT_SOURCE, worker_name: nil, user_login: nil, error: nil, occurred_at: nil)
      @level = validate_level!(level)
      @title = title
      @message = message
      @source = source
      @worker_name = worker_name
      @user_login = user_login
      @error = error
      @occurred_at = occurred_at || Time.now
    end

    def stack_trace
      return nil unless error&.backtrace

      lines = error.backtrace.first(STACK_TRACE_LIMIT)
      lines << '... (truncated)' if error.backtrace.size > STACK_TRACE_LIMIT
      lines
    end

    def critical?
      level == :critical
    end

    def error?
      level == :error
    end

    def warning?
      level == :warning
    end

    private

    def validate_level!(level)
      level_sym = level.to_sym
      return level_sym if LEVELS.include?(level_sym)

      raise ArgumentError, "Invalid level: #{level}. Must be one of: #{LEVELS.join(', ')}"
    end
  end
end
