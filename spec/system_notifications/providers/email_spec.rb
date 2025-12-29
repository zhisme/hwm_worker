# frozen_string_literal: true

require 'spec_helper'
require 'system_notifications/providers/email'

RSpec.describe SystemNotifications::Providers::Email do
  describe '.enabled?' do
    it 'returns false' do
      expect(described_class.enabled?).to be false
    end
  end

  describe '.call' do
    it 'raises NotImplementedError' do
      notification = double('notification')

      expect do
        described_class.call(notification)
      end.to raise_error(NotImplementedError, /Email provider not implemented/)
    end

    it 'mentions daily digest in error message' do
      notification = double('notification')

      expect do
        described_class.call(notification)
      end.to raise_error(NotImplementedError, /daily digest/)
    end
  end
end
