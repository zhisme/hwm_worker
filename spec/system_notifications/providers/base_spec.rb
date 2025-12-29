# frozen_string_literal: true

require 'spec_helper'
require 'system_notifications/providers/base'

RSpec.describe SystemNotifications::Providers::Base do
  describe '.call' do
    it 'raises NotImplementedError' do
      notification = double('notification')

      expect do
        described_class.call(notification)
      end.to raise_error(NotImplementedError, /must implement \.call/)
    end
  end

  describe '.enabled?' do
    it 'raises NotImplementedError' do
      expect do
        described_class.enabled?
      end.to raise_error(NotImplementedError, /must implement \.enabled\?/)
    end
  end
end
