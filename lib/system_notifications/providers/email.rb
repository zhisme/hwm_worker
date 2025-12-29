# frozen_string_literal: true

require_relative 'base'

module SystemNotifications
  module Providers
    class Email < Base
      def self.call(_notification)
        raise NotImplementedError, 'Email provider not implemented. Reserved for daily digest.'
      end

      def self.enabled?
        false
      end
    end
  end
end
