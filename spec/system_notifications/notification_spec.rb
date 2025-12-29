# frozen_string_literal: true

require 'spec_helper'
require 'system_notifications/notification'

RSpec.describe SystemNotifications::Notification do
  let(:valid_attributes) do
    {
      level: :critical,
      title: 'TestError',
      message: 'Something went wrong'
    }
  end

  describe '#initialize' do
    it 'creates a notification with required attributes' do
      notification = described_class.new(**valid_attributes)

      expect(notification.level).to eq(:critical)
      expect(notification.title).to eq('TestError')
      expect(notification.message).to eq('Something went wrong')
    end

    it 'sets default source to HWM_WORKER' do
      notification = described_class.new(**valid_attributes)

      expect(notification.source).to eq('HWM_WORKER')
    end

    it 'allows custom source' do
      notification = described_class.new(**valid_attributes, source: 'OTHER_SERVICE')

      expect(notification.source).to eq('OTHER_SERVICE')
    end

    it 'sets occurred_at to current time by default' do
      freeze_time = Time.new(2025, 1, 15, 12, 0, 0)
      allow(Time).to receive(:now).and_return(freeze_time)

      notification = described_class.new(**valid_attributes)

      expect(notification.occurred_at).to eq(freeze_time)
    end

    it 'allows custom occurred_at' do
      custom_time = Time.new(2025, 1, 10, 8, 0, 0)
      notification = described_class.new(**valid_attributes, occurred_at: custom_time)

      expect(notification.occurred_at).to eq(custom_time)
    end

    it 'accepts optional worker_name' do
      notification = described_class.new(**valid_attributes, worker_name: 'work')

      expect(notification.worker_name).to eq('work')
    end

    it 'accepts optional user_login' do
      notification = described_class.new(**valid_attributes, user_login: 'player1')

      expect(notification.user_login).to eq('player1')
    end

    it 'accepts optional error object' do
      error = StandardError.new('test error')
      notification = described_class.new(**valid_attributes, error: error)

      expect(notification.error).to eq(error)
    end

    context 'level validation' do
      it 'accepts :critical level' do
        notification = described_class.new(**valid_attributes, level: :critical)
        expect(notification.level).to eq(:critical)
      end

      it 'accepts :error level' do
        notification = described_class.new(**valid_attributes, level: :error)
        expect(notification.level).to eq(:error)
      end

      it 'accepts :warning level' do
        notification = described_class.new(**valid_attributes, level: :warning)
        expect(notification.level).to eq(:warning)
      end

      it 'accepts string levels and converts to symbol' do
        notification = described_class.new(**valid_attributes, level: 'error')
        expect(notification.level).to eq(:error)
      end

      it 'raises ArgumentError for invalid level' do
        expect do
          described_class.new(**valid_attributes, level: :info)
        end.to raise_error(ArgumentError, /Invalid level: info/)
      end
    end
  end

  describe '#stack_trace' do
    context 'when error has backtrace' do
      it 'returns first 5 lines of backtrace' do
        error = StandardError.new('test')
        error.set_backtrace([
                              'lib/file1.rb:10:in `method1`',
                              'lib/file2.rb:20:in `method2`',
                              'lib/file3.rb:30:in `method3`',
                              'lib/file4.rb:40:in `method4`',
                              'lib/file5.rb:50:in `method5`',
                              'lib/file6.rb:60:in `method6`',
                              'lib/file7.rb:70:in `method7`'
                            ])

        notification = described_class.new(**valid_attributes, error: error)
        stack_trace = notification.stack_trace

        expect(stack_trace.size).to eq(6) # 5 lines + truncated message
        expect(stack_trace.last).to eq('... (truncated)')
      end

      it 'returns all lines if backtrace has 5 or fewer lines' do
        error = StandardError.new('test')
        error.set_backtrace([
                              'lib/file1.rb:10:in `method1`',
                              'lib/file2.rb:20:in `method2`'
                            ])

        notification = described_class.new(**valid_attributes, error: error)
        stack_trace = notification.stack_trace

        expect(stack_trace.size).to eq(2)
        expect(stack_trace).not_to include('... (truncated)')
      end
    end

    context 'when error is nil' do
      it 'returns nil' do
        notification = described_class.new(**valid_attributes)
        expect(notification.stack_trace).to be_nil
      end
    end

    context 'when error has no backtrace' do
      it 'returns nil' do
        error = StandardError.new('test')
        notification = described_class.new(**valid_attributes, error: error)
        expect(notification.stack_trace).to be_nil
      end
    end
  end

  describe 'level predicates' do
    it '#critical? returns true for critical level' do
      notification = described_class.new(**valid_attributes, level: :critical)
      expect(notification.critical?).to be true
      expect(notification.error?).to be false
      expect(notification.warning?).to be false
    end

    it '#error? returns true for error level' do
      notification = described_class.new(**valid_attributes, level: :error)
      expect(notification.critical?).to be false
      expect(notification.error?).to be true
      expect(notification.warning?).to be false
    end

    it '#warning? returns true for warning level' do
      notification = described_class.new(**valid_attributes, level: :warning)
      expect(notification.critical?).to be false
      expect(notification.error?).to be false
      expect(notification.warning?).to be true
    end
  end
end
