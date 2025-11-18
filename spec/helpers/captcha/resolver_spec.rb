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

    context 'when captcha is resolved successfully on first try' do
      before do
        allow(mock_request).to receive(:solve).and_return(mock_request)
        allow(mock_request).to receive(:fetch).and_return(mock_request)
        allow(mock_request).to receive(:json_response).and_return({ 'request' => solved_text })
      end

      it 'returns the solved captcha text' do
        result = resolver.call
        expect(result).to eq(solved_text)
      end

      it 'creates Request with base64_captcha' do
        expect(Captcha::Request).to receive(:new).with(base64_captcha: base64_captcha).and_return(mock_request)
        resolver.call
      end

      it 'calls solve on request' do
        expect(mock_request).to receive(:solve).and_return(mock_request)
        resolver.call
      end

      it 'sleeps for 20 seconds before fetching' do
        expect(resolver).to receive(:sleep).with(20)
        resolver.call
      end

      it 'calls fetch after sleeping' do
        expect(mock_request).to receive(:fetch).and_return(mock_request)
        resolver.call
      end
    end

    context 'when captcha is not resolved on first fetch (retry scenario)' do
      before do
        allow(mock_request).to receive(:solve).and_return(mock_request)
      end

      it 'retries once when CaptchaNotResolved is raised' do
        allow(mock_request).to receive(:fetch).once.and_raise(Captcha::Request::CaptchaNotResolved)
        allow(mock_request).to receive(:fetch).once.and_return(mock_request)
        allow(mock_request).to receive(:json_response).and_return({ 'request' => solved_text })
        allow(resolver).to receive(:sleep)
        allow(STDOUT).to receive(:puts)

        result = resolver.call
        expect(result).to eq(solved_text)
      end

      it 'sleeps 30 seconds after CaptchaNotResolved' do
        call_count = 0
        allow(mock_request).to receive(:fetch) do
          call_count += 1
          if call_count == 1
            raise Captcha::Request::CaptchaNotResolved
          else
            mock_request
          end
        end
        allow(mock_request).to receive(:json_response).and_return({ 'request' => solved_text })
        allow(STDOUT).to receive(:puts)

        expect(resolver).to receive(:sleep).with(20).ordered
        expect(resolver).to receive(:sleep).with(30).ordered

        resolver.call
      end

      it 'prints retry message' do
        call_count = 0
        allow(mock_request).to receive(:fetch) do
          call_count += 1
          if call_count == 1
            raise Captcha::Request::CaptchaNotResolved
          else
            mock_request
          end
        end
        allow(mock_request).to receive(:json_response).and_return({ 'request' => solved_text })
        allow(resolver).to receive(:sleep)

        expect { resolver.call }.to output(/Captcha::Request::CaptchaNotResolved. Retrying/).to_stdout
      end

      it 'fetches again after retry sleep' do
        call_count = 0
        allow(mock_request).to receive(:fetch) do
          call_count += 1
          if call_count == 1
            raise Captcha::Request::CaptchaNotResolved
          else
            mock_request
          end
        end
        allow(mock_request).to receive(:json_response).and_return({ 'request' => solved_text })
        allow(resolver).to receive(:sleep)
        allow(STDOUT).to receive(:puts)

        resolver.call
        expect(call_count).to eq(2)
      end
    end

    context 'when both fetch attempts fail' do
      before do
        allow(mock_request).to receive(:solve).and_return(mock_request)
        allow(mock_request).to receive(:fetch).and_raise(Captcha::Request::CaptchaNotResolved)
        allow(STDOUT).to receive(:puts)
      end

      it 'raises CaptchaNotResolved after retry' do
        expect { resolver.call }.to raise_error(Captcha::Request::CaptchaNotResolved)
      end
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
