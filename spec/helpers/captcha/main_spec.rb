require 'spec_helper'
require 'helpers/captcha/main'
require 'helpers/captcha/downloader'
require 'helpers/captcha/encoder'
require 'helpers/captcha/resolver'
require 'helpers/captcha/saver'

RSpec.describe Captcha::Main do
  let(:image_url) { 'http://example.com/captcha.png' }
  let(:base64_captcha) { 'aGVsbG8gd29ybGQ=' }
  let(:solved_text) { 'ABCD' }
  let(:mock_encoder) { instance_double(Captcha::Encoder, base64_captcha: base64_captcha) }

  describe '.call' do
    before do
      allow(Captcha::Downloader).to receive(:call)
      allow(Captcha::Encoder).to receive(:call).and_return(mock_encoder)
      allow(Captcha::Resolver).to receive(:call).and_return(solved_text)
      allow(Captcha::Saver).to receive(:call)
    end

    it 'downloads captcha image' do
      expect(Captcha::Downloader).to receive(:call).with(image_url: image_url)
      described_class.call(image_url: image_url)
    end

    it 'encodes the downloaded image' do
      expect(Captcha::Encoder).to receive(:call)
      described_class.call(image_url: image_url)
    end

    it 'resolves captcha using encoder output' do
      expect(Captcha::Resolver).to receive(:call).with(base64_captcha: base64_captcha)
      described_class.call(image_url: image_url)
    end

    it 'calls saver' do
      expect(Captcha::Saver).to receive(:call)
      described_class.call(image_url: image_url)
    end

    it 'returns resolved captcha text' do
      result = described_class.call(image_url: image_url)
      expect(result).to eq(solved_text)
    end

    it 'executes steps in correct order' do
      call_order = []

      allow(Captcha::Downloader).to receive(:call) { call_order << :downloader }
      allow(Captcha::Encoder).to receive(:call) do
        call_order << :encoder
        mock_encoder
      end
      allow(Captcha::Resolver).to receive(:call) do
        call_order << :resolver
        solved_text
      end
      allow(Captcha::Saver).to receive(:call) { call_order << :saver }

      described_class.call(image_url: image_url)

      expect(call_order).to eq([:downloader, :encoder, :resolver, :saver])
    end
  end

  describe 'module behavior' do
    it 'extends self' do
      expect(described_class).to respond_to(:call)
    end
  end

  describe 'integration workflow' do
    before do
      allow(Captcha::Downloader).to receive(:call)
      allow(Captcha::Encoder).to receive(:call).and_return(mock_encoder)
      allow(Captcha::Resolver).to receive(:call).and_return(solved_text)
      allow(Captcha::Saver).to receive(:call)
    end

    it 'passes data between components correctly' do
      # Encoder provides base64
      expect(Captcha::Encoder).to receive(:call).and_return(mock_encoder)
      expect(mock_encoder).to receive(:base64_captcha).and_return(base64_captcha)

      # Resolver receives base64 from encoder
      expect(Captcha::Resolver).to receive(:call).with(base64_captcha: base64_captcha).and_return(solved_text)

      result = described_class.call(image_url: image_url)
      expect(result).to eq(solved_text)
    end

    it 'handles full workflow from URL to solved text' do
      result = described_class.call(image_url: image_url)

      expect(Captcha::Downloader).to have_received(:call).with(image_url: image_url)
      expect(Captcha::Encoder).to have_received(:call)
      expect(Captcha::Resolver).to have_received(:call).with(base64_captcha: base64_captcha)
      expect(Captcha::Saver).to have_received(:call)
      expect(result).to eq(solved_text)
    end
  end

  describe 'error propagation' do
    context 'when Downloader raises error' do
      before do
        allow(Captcha::Downloader).to receive(:call).and_raise(Captcha::Downloader::CaptchaEmpty)
      end

      it 'propagates CaptchaEmpty error' do
        expect { described_class.call(image_url: image_url) }.to raise_error(Captcha::Downloader::CaptchaEmpty)
      end
    end

    context 'when Resolver raises error' do
      before do
        allow(Captcha::Downloader).to receive(:call)
        allow(Captcha::Encoder).to receive(:call).and_return(mock_encoder)
        allow(Captcha::Resolver).to receive(:call).and_raise(Captcha::Request::CaptchaNotResolved)
      end

      it 'propagates CaptchaNotResolved error' do
        expect { described_class.call(image_url: image_url) }.to raise_error(Captcha::Request::CaptchaNotResolved)
      end
    end
  end

  describe 'parameter handling' do
    before do
      allow(Captcha::Downloader).to receive(:call)
      allow(Captcha::Encoder).to receive(:call).and_return(mock_encoder)
      allow(Captcha::Resolver).to receive(:call).and_return(solved_text)
      allow(Captcha::Saver).to receive(:call)
    end

    it 'accepts image_url as keyword argument' do
      expect { described_class.call(image_url: image_url) }.not_to raise_error
    end

    it 'passes image_url to Downloader' do
      expect(Captcha::Downloader).to receive(:call).with(image_url: image_url)
      described_class.call(image_url: image_url)
    end
  end
end
