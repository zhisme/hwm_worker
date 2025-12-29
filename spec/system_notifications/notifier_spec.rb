# frozen_string_literal: true

require 'spec_helper'
require 'system_notifications/notifier'

RSpec.describe SystemNotifications::Notifier do
  let(:notification) do
    SystemNotifications::Notification.new(
      level: :critical,
      title: 'TestError',
      message: 'Something went wrong'
    )
  end

  before do
    stub_const('SECRETS', {
                 'telegram' => {
                   'bot_token' => 'test_token',
                   'chat_id' => '-123'
                 }
               })
  end

  describe '.call' do
    context 'with symbol provider' do
      it 'resolves :telegram to Telegram provider' do
        allow(SystemNotifications::Providers::Telegram).to receive(:enabled?).and_return(true)
        allow(SystemNotifications::Providers::Telegram).to receive(:call)

        described_class.call(notification, provider: :telegram)

        expect(SystemNotifications::Providers::Telegram).to have_received(:call).with(notification)
      end

      it 'raises ArgumentError for unknown symbol provider' do
        expect do
          described_class.call(notification, provider: :unknown)
        end.to raise_error(ArgumentError, /Unknown provider: unknown/)
      end
    end

    context 'with class provider' do
      it 'uses the class directly' do
        allow(SystemNotifications::Providers::Telegram).to receive(:enabled?).and_return(true)
        allow(SystemNotifications::Providers::Telegram).to receive(:call)

        described_class.call(notification, provider: SystemNotifications::Providers::Telegram)

        expect(SystemNotifications::Providers::Telegram).to have_received(:call).with(notification)
      end
    end

    context 'with invalid provider type' do
      it 'raises ArgumentError' do
        expect do
          described_class.call(notification, provider: 123)
        end.to raise_error(ArgumentError, /Invalid provider/)
      end
    end

    context 'when provider is disabled' do
      before do
        allow(SystemNotifications::Providers::Telegram).to receive(:enabled?).and_return(false)
      end

      it 'does not call the provider' do
        allow(SystemNotifications::Providers::Telegram).to receive(:call)

        described_class.call(notification, provider: :telegram)

        expect(SystemNotifications::Providers::Telegram).not_to have_received(:call)
      end

      it 'logs a warning to stdout' do
        expect do
          described_class.call(notification, provider: :telegram)
        end.to output(/WARNING.*not enabled/).to_stdout
      end
    end

    context 'when provider raises an error' do
      before do
        allow(SystemNotifications::Providers::Telegram).to receive(:enabled?).and_return(true)
        allow(SystemNotifications::Providers::Telegram).to receive(:call).and_raise(StandardError, 'API error')
      end

      it 'does not re-raise the error' do
        expect do
          described_class.call(notification, provider: :telegram)
        end.not_to raise_error
      end

      it 'logs the error to stdout' do
        expect do
          described_class.call(notification, provider: :telegram)
        end.to output(/ERROR.*Telegram failed: API error/).to_stdout
      end
    end
  end
end
