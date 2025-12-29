# frozen_string_literal: true

require 'spec_helper'
require 'system_notifications/notification'
require 'system_notifications/message_formatter'

RSpec.describe SystemNotifications::MessageFormatter do
  let(:occurred_at) { Time.utc(2025, 1, 15, 14, 30, 0) }

  let(:notification) do
    SystemNotifications::Notification.new(
      level: :critical,
      title: 'ZeroBalanceException',
      message: 'Rucaptcha service has insufficient balance',
      source: 'HWM_WORKER',
      worker_name: 'work',
      user_login: 'player1',
      occurred_at: occurred_at
    )
  end

  describe '.call' do
    context 'with telegram format' do
      it 'returns formatted message' do
        result = described_class.call(notification, format: :telegram)

        expect(result).to be_a(String)
        expect(result).to include('CRITICAL')
        expect(result).to include('ZeroBalanceException')
      end
    end

    context 'with unknown format' do
      it 'raises ArgumentError' do
        expect do
          described_class.call(notification, format: :unknown)
        end.to raise_error(ArgumentError, /Unknown format/)
      end
    end
  end

  describe 'telegram format' do
    subject(:formatted) { described_class.call(notification, format: :telegram) }

    it 'includes level emoji and title in header' do
      expect(formatted).to include("\u{1F534} CRITICAL: ZeroBalanceException")
    end

    it 'includes source' do
      expect(formatted).to include('*Source:* HWM_WORKER')
    end

    it 'includes worker name' do
      expect(formatted).to include('*Worker:* work')
    end

    it 'includes user login' do
      expect(formatted).to include('*User:* player1')
    end

    it 'includes formatted time in UTC' do
      expect(formatted).to include('*Time:* 2025-01-15 14:30 UTC')
    end

    it 'includes message' do
      expect(formatted).to include('*Message:*')
      expect(formatted).to include('Rucaptcha service has insufficient balance')
    end

    context 'with different levels' do
      it 'uses red circle for critical' do
        notification = SystemNotifications::Notification.new(
          level: :critical,
          title: 'Test',
          message: 'Test'
        )
        result = described_class.call(notification, format: :telegram)
        expect(result).to include("\u{1F534}")
      end

      it 'uses orange circle for error' do
        notification = SystemNotifications::Notification.new(
          level: :error,
          title: 'Test',
          message: 'Test'
        )
        result = described_class.call(notification, format: :telegram)
        expect(result).to include("\u{1F7E0}")
      end

      it 'uses yellow circle for warning' do
        notification = SystemNotifications::Notification.new(
          level: :warning,
          title: 'Test',
          message: 'Test'
        )
        result = described_class.call(notification, format: :telegram)
        expect(result).to include("\u{1F7E1}")
      end
    end

    context 'without optional fields' do
      let(:notification) do
        SystemNotifications::Notification.new(
          level: :error,
          title: 'TestError',
          message: 'Test message',
          occurred_at: occurred_at
        )
      end

      it 'omits worker name when not provided' do
        expect(formatted).not_to include('*Worker:*')
      end

      it 'omits user login when not provided' do
        expect(formatted).not_to include('*User:*')
      end
    end

    context 'with stack trace' do
      let(:error) do
        e = StandardError.new('test error')
        e.set_backtrace([
                          'lib/file1.rb:10:in `method1`',
                          'lib/file2.rb:20:in `method2`'
                        ])
        e
      end

      let(:notification) do
        SystemNotifications::Notification.new(
          level: :error,
          title: 'TestError',
          message: 'Test message',
          error: error,
          occurred_at: occurred_at
        )
      end

      it 'includes stack trace section' do
        expect(formatted).to include('*Stack trace:*')
      end

      it 'wraps each line in backticks' do
        expect(formatted).to include('`lib/file1.rb:10:in')
        expect(formatted).to include('`lib/file2.rb:20:in')
      end
    end

    context 'markdown escaping' do
      let(:notification) do
        SystemNotifications::Notification.new(
          level: :error,
          title: 'Error_with_underscore',
          message: 'Message with *asterisks* and `backticks`',
          occurred_at: occurred_at
        )
      end

      it 'escapes markdown special characters in title' do
        expect(formatted).to include('Error\\_with\\_underscore')
      end

      it 'escapes markdown special characters in message' do
        expect(formatted).to include('\\*asterisks\\*')
        expect(formatted).to include('\\`backticks\\`')
      end
    end
  end
end
