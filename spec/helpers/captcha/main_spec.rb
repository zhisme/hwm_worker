require 'spec_helper'
require 'helpers/captcha/main'
require 'helpers/captcha/downloader'
require 'helpers/captcha/encoder'
require 'helpers/captcha/resolver'

RSpec.describe Captcha::Main do
  let(:image_url) { 'http://example.com/captcha.png' }
  let(:image_data) { 'raw-png-bytes' }
  let(:base64_captcha) { 'aGVsbG8gd29ybGQ=' }
  let(:solved_text) { 'ABCD' }
  let(:mock_encoder) { instance_double(Captcha::Encoder, base64_captcha: base64_captcha) }

  before do
    allow(Captcha::Downloader).to receive(:call).and_return(image_data)
    allow(Captcha::Encoder).to receive(:call).and_return(mock_encoder)
    allow(Captcha::Resolver).to receive(:call).and_return(solved_text)
  end

  describe '.call' do
    it 'passes the downloaded bytes to the encoder' do
      expect(Captcha::Encoder).to receive(:call).with(image_data).and_return(mock_encoder)

      described_class.call(image_url: image_url)
    end

    it 'resolves the captcha with the encoder output' do
      expect(Captcha::Resolver).to receive(:call).with(base64_captcha: base64_captcha)

      described_class.call(image_url: image_url)
    end

    it 'returns the solved text' do
      expect(described_class.call(image_url: image_url)).to eq(solved_text)
    end

    it 'runs download, encode, resolve in order' do
      call_order = []

      allow(Captcha::Downloader).to receive(:call) do
        call_order << :downloader
        image_data
      end
      allow(Captcha::Encoder).to receive(:call) do
        call_order << :encoder
        mock_encoder
      end
      allow(Captcha::Resolver).to receive(:call) do
        call_order << :resolver
        solved_text
      end

      described_class.call(image_url: image_url)

      expect(call_order).to eq(%i[downloader encoder resolver])
    end
  end

  describe 'error propagation' do
    it 'propagates downloader failures' do
      allow(Captcha::Downloader).to receive(:call).and_raise(Captcha::Downloader::CaptchaEmpty)

      expect { described_class.call(image_url: image_url) }.to raise_error(Captcha::Downloader::CaptchaEmpty)
    end

    it 'propagates resolver failures' do
      allow(Captcha::Resolver).to receive(:call).and_raise(Captcha::Request::CaptchaNotResolved)

      expect { described_class.call(image_url: image_url) }.to raise_error(Captcha::Request::CaptchaNotResolved)
    end
  end
end
