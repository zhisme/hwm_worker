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

  describe '.notify_error' do
    let(:user) { instance_double(User, login: 'test_player') }

    it 'sends notification with error details' do
      error = StandardError.new('Something failed')

      described_class.notify_error(error, provider: :telegram, worker_name: 'work', user: user)

      expect(SystemNotifications::Providers::Telegram).to have_received(:call) do |notification|
        expect(notification.title).to eq('StandardError')
        expect(notification.message).to eq('Something failed')
        expect(notification.worker_name).to eq('work')
        expect(notification.user_login).to eq('test_player')
      end
    end

    it 'classifies error level automatically' do
      error = Work::NoAvailableWork.new('No work')

      described_class.notify_error(error, provider: :telegram, worker_name: 'work')

      expect(SystemNotifications::Providers::Telegram).to have_received(:call) do |notification|
        expect(notification.level).to eq(:warning)
      end
    end

    it 'works without user' do
      error = StandardError.new('Error')

      described_class.notify_error(error, provider: :telegram, worker_name: 'work')

      expect(SystemNotifications::Providers::Telegram).to have_received(:call) do |notification|
        expect(notification.user_login).to be_nil
      end
    end
  end

  describe '.classify_error_level' do
    it 'returns :critical for ZeroBalanceException' do
      error = Captcha::Request::ZeroBalanceException.new('test')
      expect(described_class.classify_error_level(error)).to eq(:critical)
    end

    it 'returns :error for LoginInvalid' do
      error = Login::LoginInvalid.new('test')
      expect(described_class.classify_error_level(error)).to eq(:error)
    end

    it 'returns :error for CannotApplyForJobError' do
      error = Work::CannotApplyForJobError.new('test')
      expect(described_class.classify_error_level(error)).to eq(:error)
    end

    it 'returns :error for AutoHuntBroken' do
      error = Hunt::AutoHuntBroken.new('test')
      expect(described_class.classify_error_level(error)).to eq(:error)
    end

    it 'returns :error for AutoItemNotFound' do
      error = Hunt::AutoItemNotFound.new('test')
      expect(described_class.classify_error_level(error)).to eq(:error)
    end

    it 'returns :warning for NoAvailableWork' do
      error = Work::NoAvailableWork.new('test')
      expect(described_class.classify_error_level(error)).to eq(:warning)
    end

    it 'returns :error for unknown errors' do
      error = RuntimeError.new('test')
      expect(described_class.classify_error_level(error)).to eq(:error)
    end
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
  end
end
