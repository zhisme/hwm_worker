# frozen_string_literal: true

require 'spec_helper'
require 'system_notifications'

RSpec.describe SystemNotifications do
  before do
    stub_const('SECRETS', {
                 'telegram' => {
                   'bot_token' => 'test_token',
                   'chat_id' => '-123'
                 }
               })
    allow(SystemNotifications::Providers::Telegram).to receive(:enabled?).and_return(true)
    allow(SystemNotifications::Providers::Telegram).to receive(:call)
  end

  describe '.critical!' do
    it 'sends a critical notification' do
      described_class.critical!(
        provider: :telegram,
        title: 'CriticalError',
        message: 'Critical failure'
      )

      expect(SystemNotifications::Providers::Telegram).to have_received(:call) do |notification|
        expect(notification.level).to eq(:critical)
        expect(notification.title).to eq('CriticalError')
        expect(notification.message).to eq('Critical failure')
      end
    end

    it 'accepts optional context' do
      error = StandardError.new('test')

      described_class.critical!(
        provider: :telegram,
        title: 'CriticalError',
        message: 'Critical failure',
        worker_name: 'work',
        user_login: 'player1',
        error: error
      )

      expect(SystemNotifications::Providers::Telegram).to have_received(:call) do |notification|
        expect(notification.worker_name).to eq('work')
        expect(notification.user_login).to eq('player1')
        expect(notification.error).to eq(error)
      end
    end
  end

  describe '.error!' do
    it 'sends an error notification' do
      described_class.error!(
        provider: :telegram,
        title: 'SomeError',
        message: 'Something failed'
      )

      expect(SystemNotifications::Providers::Telegram).to have_received(:call) do |notification|
        expect(notification.level).to eq(:error)
        expect(notification.title).to eq('SomeError')
      end
    end
  end

  describe '.warning!' do
    it 'sends a warning notification' do
      described_class.warning!(
        provider: :telegram,
        title: 'SomeWarning',
        message: 'Something needs attention'
      )

      expect(SystemNotifications::Providers::Telegram).to have_received(:call) do |notification|
        expect(notification.level).to eq(:warning)
        expect(notification.title).to eq('SomeWarning')
      end
    end
  end

  describe 'default source' do
    it 'uses HWM_WORKER as default source' do
      described_class.error!(
        provider: :telegram,
        title: 'Test',
        message: 'Test'
      )

      expect(SystemNotifications::Providers::Telegram).to have_received(:call) do |notification|
        expect(notification.source).to eq('HWM_WORKER')
      end
    end

    it 'allows custom source' do
      described_class.error!(
        provider: :telegram,
        title: 'Test',
        message: 'Test',
        source: 'OTHER_SERVICE'
      )

      expect(SystemNotifications::Providers::Telegram).to have_received(:call) do |notification|
        expect(notification.source).to eq('OTHER_SERVICE')
      end
    end
  end

  describe 'provider class support' do
    it 'accepts provider class directly' do
      described_class.error!(
        provider: SystemNotifications::Providers::Telegram,
        title: 'Test',
        message: 'Test'
      )

      expect(SystemNotifications::Providers::Telegram).to have_received(:call)
    end
  end
end
