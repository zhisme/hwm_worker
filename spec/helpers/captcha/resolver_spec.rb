require 'spec_helper'
require 'helpers/captcha/resolver'
require 'helpers/captcha/request'

RSpec.describe Captcha::Resolver do
  let(:base64_captcha) { 'aGVsbG8gd29ybGQ=' }
  let(:solved_text) { 'ABCD' }
  let(:mock_request) { instance_double(Captcha::Request) }

  describe '.call' do
    it 'creates new instance and calls instance method' do
      instance = described_class.new(base64_captcha)
      allow(described_class).to receive(:new).with(base64_captcha).and_return(instance)
      expect(instance).to receive(:call).and_call_original

      allow(Captcha::Request).to receive(:new).and_return(mock_request)
      allow(mock_request).to receive(:solve).and_return(mock_request)
      allow(mock_request).to receive(:fetch).and_return(mock_request)
      allow(mock_request).to receive(:json_response).and_return({ 'request' => solved_text })
      allow_any_instance_of(described_class).to receive(:sleep)

      described_class.call(base64_captcha: base64_captcha)
    end
  end

  describe '#call' do
    let(:resolver) { described_class.new(base64_captcha) }

    before do
      allow(Captcha::Request).to receive(:new).with(base64_captcha: base64_captcha).and_return(mock_request)
      allow(resolver).to receive(:sleep) # Mock sleep to speed up tests
    end

    context 'when captcha is resolved on first poll' do
      before do
        allow(mock_request).to receive(:solve).and_return(mock_request)
        allow(mock_request).to receive(:fetch).and_return(mock_request)
        allow(mock_request).to receive(:json_response).and_return({ 'request' => solved_text })
      end

      it 'returns the solved captcha text' do
        expect(resolver.call).to eq(solved_text)
      end

      it 'creates Request with base64_captcha' do
        expect(Captcha::Request).to receive(:new).with(base64_captcha: base64_captcha).and_return(mock_request)
        resolver.call
      end

      it 'calls solve on request' do
        expect(mock_request).to receive(:solve).and_return(mock_request)
        resolver.call
      end

      it 'sleeps one poll interval before fetching' do
        expect(resolver).to receive(:sleep).with(described_class::POLL_INTERVAL).once
        resolver.call
      end

      it 'fetches exactly once' do
        expect(mock_request).to receive(:fetch).once.and_return(mock_request)
        resolver.call
      end
    end

    context 'when captcha needs several polls' do
      let(:failures) { 3 }

      before do
        allow(mock_request).to receive(:solve).and_return(mock_request)
        allow(mock_request).to receive(:json_response).and_return({ 'request' => solved_text })

        call_count = 0
        allow(mock_request).to receive(:fetch) do
          call_count += 1
          raise Captcha::Request::CaptchaNotResolved if call_count <= failures

          mock_request
        end
      end

      it 'returns the solved captcha text' do
        expect(resolver.call).to eq(solved_text)
      end

      it 'polls until resolved' do
        resolver.call
        expect(mock_request).to have_received(:fetch).exactly(failures + 1).times
      end

      it 'sleeps one interval per attempt' do
        resolver.call
        expect(resolver).to have_received(:sleep).with(described_class::POLL_INTERVAL).exactly(failures + 1).times
      end
    end

    context 'when captcha is never resolved' do
      before do
        allow(mock_request).to receive(:solve).and_return(mock_request)
        allow(mock_request).to receive(:fetch).and_raise(Captcha::Request::CaptchaNotResolved)
      end

      it 'raises CaptchaExceededMaxAttempts rather than leaking CaptchaNotResolved' do
        expect { resolver.call }.to raise_error(described_class::CaptchaExceededMaxAttempts)
      end

      it 'gives up after MAX_ATTEMPTS polls' do
        expect { resolver.call }.to raise_error(described_class::CaptchaExceededMaxAttempts)
        expect(mock_request).to have_received(:fetch).exactly(described_class::MAX_ATTEMPTS).times
      end

      it 'sleeps one interval per attempt and no more' do
        expect { resolver.call }.to raise_error(described_class::CaptchaExceededMaxAttempts)
        expect(resolver).to have_received(:sleep)
          .with(described_class::POLL_INTERVAL).exactly(described_class::MAX_ATTEMPTS).times
      end

      it 'does not exceed the poll budget' do
        expect { resolver.call }.to raise_error(described_class::CaptchaExceededMaxAttempts)
        budget = described_class::POLL_INTERVAL * described_class::MAX_ATTEMPTS
        expect(budget).to be <= 90
      end
    end

    context 'when the last poll succeeds' do
      before do
        allow(mock_request).to receive(:solve).and_return(mock_request)
        allow(mock_request).to receive(:json_response).and_return({ 'request' => solved_text })

        call_count = 0
        allow(mock_request).to receive(:fetch) do
          call_count += 1
          raise Captcha::Request::CaptchaNotResolved if call_count < described_class::MAX_ATTEMPTS

          mock_request
        end
      end

      it 'returns the solved text without raising on the boundary attempt' do
        expect(resolver.call).to eq(solved_text)
        expect(mock_request).to have_received(:fetch).exactly(described_class::MAX_ATTEMPTS).times
      end
    end

    context 'when solve fails' do
      before do
        allow(mock_request).to receive(:solve).and_raise(Captcha::Request::ZeroBalanceException, 'no funds')
      end

      it 'propagates the error without polling' do
        allow(mock_request).to receive(:fetch)

        expect { resolver.call }.to raise_error(Captcha::Request::ZeroBalanceException, 'no funds')
        expect(mock_request).not_to have_received(:fetch)
      end
    end

    context 'when fetch returns a blank answer' do
      before do
        allow(mock_request).to receive(:solve).and_return(mock_request)
        allow(mock_request).to receive(:fetch).and_return(mock_request)
        allow(mock_request).to receive(:json_response).and_return({})
      end

      it 'returns nil rather than looping forever' do
        expect(resolver.call).to be_nil
        expect(mock_request).to have_received(:fetch).once
      end
    end
  end

  describe 'CaptchaExceededMaxAttempts' do
    it 'is a StandardError so HwmWorker.run notifies instead of crashing' do
      expect(described_class::CaptchaExceededMaxAttempts.ancestors).to include(StandardError)
    end

    it 'is not confused with CaptchaNotResolved' do
      expect(described_class::CaptchaExceededMaxAttempts).not_to eq(Captcha::Request::CaptchaNotResolved)
      expect(described_class::CaptchaExceededMaxAttempts.ancestors)
        .not_to include(Captcha::Request::CaptchaNotResolved)
    end
  end

  describe '#initialize' do
    it 'sets base64_captcha' do
      resolver = described_class.new(base64_captcha)
      expect(resolver.base64_captcha).to eq(base64_captcha)
    end

    it 'initializes solved_text as empty string' do
      resolver = described_class.new(base64_captcha)
      expect(resolver.solved_text).to eq('')
    end
  end

  describe 'attributes' do
    let(:resolver) { described_class.new(base64_captcha) }

    it 'has readable base64_captcha' do
      expect(resolver).to respond_to(:base64_captcha)
    end

    it 'has readable solved_text' do
      expect(resolver).to respond_to(:solved_text)
    end
  end

  describe 'integration with Request class' do
    let(:resolver) { described_class.new(base64_captcha) }

    before do
      allow(resolver).to receive(:sleep)
    end

    it 'uses same Request instance for solve and fetch' do
      request_instance = instance_double(Captcha::Request)
      allow(Captcha::Request).to receive(:new).and_return(request_instance)
      allow(request_instance).to receive(:solve).and_return(request_instance)
      allow(request_instance).to receive(:fetch).and_return(request_instance)
      allow(request_instance).to receive(:json_response).and_return({ 'request' => solved_text })

      resolver.call

      expect(request_instance).to have_received(:solve).once
      expect(request_instance).to have_received(:fetch).once
    end
  end
end
