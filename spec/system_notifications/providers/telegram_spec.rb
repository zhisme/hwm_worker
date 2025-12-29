# frozen_string_literal: true

require 'spec_helper'
require 'system_notifications/notification'
require 'system_notifications/providers/telegram'
require 'rest-client'

RSpec.describe SystemNotifications::Providers::Telegram do
  let(:notification) do
    SystemNotifications::Notification.new(
      level: :critical,
      title: 'TestError',
      message: 'Something went wrong',
      worker_name: 'work',
      user_login: 'player1'
    )
  end

  before do
    stub_const('SECRETS', {
                 'telegram' => {
                   'bot_token' => 'test_bot_token',
                   'chat_id' => '-123456789'
                 }
               })
  end

  describe '.enabled?' do
    context 'when bot_token and chat_id are configured' do
      it 'returns true' do
        expect(described_class.enabled?).to be true
      end
    end

    context 'when bot_token is missing' do
      before do
        stub_const('SECRETS', {
                     'telegram' => {
                       'bot_token' => nil,
                       'chat_id' => '-123456789'
                     }
                   })
      end

      it 'returns false' do
        expect(described_class.enabled?).to be false
      end
    end

    context 'when chat_id is missing' do
      before do
        stub_const('SECRETS', {
                     'telegram' => {
                       'bot_token' => 'test_token',
                       'chat_id' => nil
                     }
                   })
      end

      it 'returns false' do
        expect(described_class.enabled?).to be false
      end
    end

    context 'when telegram config is missing entirely' do
      before do
        stub_const('SECRETS', {})
      end

      it 'returns false' do
        expect(described_class.enabled?).to be false
      end
    end
  end

  describe '.bot_token' do
    it 'returns bot_token from SECRETS' do
      expect(described_class.bot_token).to eq('test_bot_token')
    end
  end

  describe '.chat_id' do
    it 'returns chat_id from SECRETS' do
      expect(described_class.chat_id).to eq('-123456789')
    end
  end

  describe '.call' do
    let(:mock_request) { instance_double(RestClient::Request) }
    let(:mock_response) { double('response', body: '{"ok": true}') }

    context 'when enabled' do
      before do
        allow(RestClient::Request).to receive(:new).and_return(mock_request)
        allow(mock_request).to receive(:execute).and_return(mock_response)
      end

      it 'sends POST request to Telegram API' do
        expect(RestClient::Request).to receive(:new).with(
          hash_including(
            method: :post,
            url: 'https://api.telegram.org/bottest_bot_token/sendMessage'
          )
        ).and_return(mock_request)

        described_class.call(notification)
      end

      it 'includes chat_id in payload' do
        expect(RestClient::Request).to receive(:new).with(
          hash_including(
            payload: a_string_including('"chat_id":"-123456789"')
          )
        ).and_return(mock_request)

        described_class.call(notification)
      end

      it 'includes parse_mode in payload' do
        expect(RestClient::Request).to receive(:new).with(
          hash_including(
            payload: a_string_including('"parse_mode":"Markdown"')
          )
        ).and_return(mock_request)

        described_class.call(notification)
      end
    end

    context 'when disabled' do
      before do
        stub_const('SECRETS', {})
      end

      it 'does not send request' do
        expect(RestClient::Request).not_to receive(:new)
        described_class.call(notification)
      end
    end
  end

  describe '#send_message' do
    let(:mock_request) { instance_double(RestClient::Request) }
    let(:mock_response) { double('response', body: '{"ok": true}') }

    before do
      allow(RestClient::Request).to receive(:new).and_return(mock_request)
      allow(mock_request).to receive(:execute).and_return(mock_response)
    end

    it 'executes the request' do
      provider = described_class.new(notification)

      expect(mock_request).to receive(:execute)

      provider.send_message
    end
  end
end
