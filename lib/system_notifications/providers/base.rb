# frozen_string_literal: true

module SystemNotifications
  module Providers
    class Base
      def self.call(notification)
        raise NotImplementedError, "#{name} must implement .call"
      end

      def self.enabled?
        raise NotImplementedError, "#{name} must implement .enabled?"
      end
    end
  end
end
