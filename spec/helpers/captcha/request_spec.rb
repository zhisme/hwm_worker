require 'spec_helper'
require 'helpers/captcha/request'

RSpec.describe Captcha::Request do
  let(:base64_captcha) { 'aGVsbG8gd29ybGQ=' } # 'hello world' in base64
  let(:request_instance) { described_class.new(base64_captcha: base64_captcha) }

  describe 'constants' do
    it 'defines RUCAPTCHA_URL' do
      expect(described_class::RUCAPTCHA_URL).to eq('http://rucaptcha.com')
    end

    it 'defines SOLVE_URL' do
      expect(described_class::SOLVE_URL).to eq('http://rucaptcha.com/in.php')
    end

    it 'defines FETCH_URL' do
      expect(described_class::FETCH_URL).to eq('http://rucaptcha.com/res.php')
    end
  end

  describe 'custom exceptions' do
    it 'defines CaptchaNotResolved exception' do
      expect { raise Captcha::Request::CaptchaNotResolved }.to raise_error(StandardError)
    end

    it 'defines RucaptchaInternalException exception' do
      expect { raise Captcha::Request::RucaptchaInternalException }.to raise_error(StandardError)
    end

    it 'defines ZeroBalanceException exception' do
      expect { raise Captcha::Request::ZeroBalanceException }.to raise_error(StandardError)
    end
  end

  describe '#initialize' do
    it 'sets base64_captcha' do
      instance = described_class.new(base64_captcha: base64_captcha)
      expect(instance.instance_variable_get(:@base64_captcha)).to eq(base64_captcha)
    end

    it 'initializes captcha_id as empty string' do
      instance = described_class.new(base64_captcha: base64_captcha)
      expect(instance.instance_variable_get(:@captcha_id)).to eq('')
    end
  end

  describe '#solve' do
    context 'when solve is successful' do
      let(:response_body) { '{"status": 1, "request": "12345"}' }

      before do
        allow(Captcha::Http).to receive(:post_form).and_return(response_body)
      end

      it 'returns self' do
        result = request_instance.solve
        expect(result).to eq(request_instance)
      end

      it 'sets json_response' do
        request_instance.solve
        expect(request_instance.json_response).to eq({ 'status' => 1, 'request' => '12345' })
      end

      it 'assigns captcha_id from response' do
        request_instance.solve
        expect(request_instance.instance_variable_get(:@captcha_id)).to eq('12345')
      end

      it 'posts the base64 captcha as a form' do
        expect(Captcha::Http).to receive(:post_form).with(
          described_class::SOLVE_URL,
          method: 'base64',
          key: described_class::API_KEY,
          body: base64_captcha,
          numeric: 4,
          json: 1
        ).and_return(response_body)

        request_instance.solve
      end
    end

    context 'when solve fails with zero balance' do
      let(:response_body) { '{"status": 0, "request": "ERROR_ZERO_BALANCE", "error_text": "No credits"}' }

      before do
        allow(Captcha::Http).to receive(:post_form).and_return(response_body)
      end

      it 'raises ZeroBalanceException' do
        expect { request_instance.solve }.to raise_error(
          Captcha::Request::ZeroBalanceException,
          'No credits'
        )
      end
    end

    context 'when solve fails with internal error' do
      let(:response_body) { '{"status": 0, "request": "ERROR_INTERNAL"}' }

      before do
        allow(Captcha::Http).to receive(:post_form).and_return(response_body)
      end

      it 'raises RucaptchaInternalException' do
        expect { request_instance.solve }.to raise_error(Captcha::Request::RucaptchaInternalException)
      end
    end
  end

  describe '#fetch' do
    before do
      # Set captcha_id as it would be set by solve
      request_instance.instance_variable_set(:@captcha_id, '12345')
    end

    context 'when fetch is successful' do
      let(:response_body) { '{"status": 1, "request": "SOLVED_TEXT"}' }

      before do
        allow(Captcha::Http).to receive(:get).and_return(response_body)
      end

      it 'returns self' do
        result = request_instance.fetch
        expect(result).to eq(request_instance)
      end

      it 'sets json_response' do
        request_instance.fetch
        expect(request_instance.json_response).to eq({ 'status' => 1, 'request' => 'SOLVED_TEXT' })
      end

      it 'polls res.php with the captcha id' do
        expect(Captcha::Http).to receive(:get).with(
          described_class::FETCH_URL,
          key: described_class::API_KEY,
          action: 'get',
          id: '12345',
          json: 1
        ).and_return(response_body)

        request_instance.fetch
      end
    end

    context 'when fetch fails (captcha not resolved yet)' do
      let(:response_body) { '{"status": 0, "request": "CAPCHA_NOT_READY"}' }

      before do
        allow(Captcha::Http).to receive(:get).and_return(response_body)
      end

      it 'raises CaptchaNotResolved' do
        expect { request_instance.fetch }.to raise_error(Captcha::Request::CaptchaNotResolved)
      end
    end
  end

  describe '.last_captcha_id' do
    before do
      described_class.last_captcha_id = 'previous'
    end

    it 'remembers the id of an accepted captcha' do
      allow(Captcha::Http).to receive(:post_form).and_return('{"status": 1, "request": "12345"}')

      request_instance.solve

      expect(described_class.last_captcha_id).to eq('12345')
    end

    it 'keeps the previous id when the upload was rejected' do
      allow(Captcha::Http).to receive(:post_form)
        .and_return('{"status": 0, "request": "ERROR_ZERO_BALANCE", "error_text": "no funds"}')

      expect { request_instance.solve }.to raise_error(Captcha::Request::ZeroBalanceException)

      expect(described_class.last_captcha_id).to eq('previous')
    end
  end

  describe '.report_bad' do
    it 'sends reportbad for the given id' do
      expect(Captcha::Http).to receive(:get).with(
        described_class::FETCH_URL,
        key: described_class::API_KEY,
        action: 'reportbad',
        id: '12345',
        json: 1
      ).and_return('{"status": 1}')

      described_class.report_bad('12345')
    end

    it 'propagates transport errors to the caller' do
      allow(Captcha::Http).to receive(:get).and_raise(Captcha::Http::HttpError)

      expect { described_class.report_bad('12345') }.to raise_error(Captcha::Http::HttpError)
    end
  end

  describe 'integration test: solve and fetch workflow' do
    before do
      allow(Captcha::Http).to receive(:post_form).and_return('{"status": 1, "request": "12345"}')
      allow(Captcha::Http).to receive(:get).and_return('{"status": 1, "request": "ABCD"}')
    end

    it 'completes solve then fetch workflow' do
      request_instance.solve
      expect(request_instance.json_response['request']).to eq('12345')

      request_instance.fetch
      expect(request_instance.json_response['request']).to eq('ABCD')
    end
  end
end
