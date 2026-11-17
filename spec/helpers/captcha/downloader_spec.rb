require 'spec_helper'
require 'helpers/captcha/downloader'

RSpec.describe Captcha::Downloader do
  let(:image_url) { 'http://example.com/captcha.png' }
  let(:fake_image_data) { "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR".b }

  describe 'CaptchaEmpty exception' do
    it 'is defined' do
      expect { raise Captcha::Downloader::CaptchaEmpty }.to raise_error(StandardError)
    end
  end

  describe '.call' do
    context 'when image_url is nil' do
      it 'raises CaptchaEmpty' do
        expect { described_class.call(image_url: nil) }.to raise_error(Captcha::Downloader::CaptchaEmpty)
      end
    end

    context 'when image_url is provided' do
      before do
        allow(Captcha::Http).to receive(:get_binary).with(image_url).and_return(fake_image_data)
      end

      it 'returns the image bytes without writing a file' do
        expect(described_class.call(image_url: image_url)).to eq(fake_image_data)
        expect(File.exist?('captcha.png')).to be false
      end

      it 'requests the image URL as binary' do
        expect(Captcha::Http).to receive(:get_binary).with(image_url).and_return(fake_image_data)
        described_class.call(image_url: image_url)
      end
    end

    context 'with different image URLs' do
      before do
        allow(Captcha::Http).to receive(:get_binary).and_return(fake_image_data)
      end

      it 'handles URLs with query parameters' do
        url_with_params = 'http://example.com/captcha.png?id=123&token=abc'
        expect(Captcha::Http).to receive(:get_binary).with(url_with_params).and_return(fake_image_data)
        described_class.call(image_url: url_with_params)
      end

      it 'handles HTTPS URLs' do
        https_url = 'https://example.com/secure/captcha.png'
        expect(Captcha::Http).to receive(:get_binary).with(https_url).and_return(fake_image_data)
        described_class.call(image_url: https_url)
      end
    end
  end

  describe 'error handling' do
    context 'when the server returns an error status' do
      before do
        allow(Captcha::Http).to receive(:get_binary).with(image_url)
                                                     .and_raise(Captcha::Http::HttpError.new('HTTP 404 for example.com/captcha.png'))
      end

      it 'raises the http error' do
        expect { described_class.call(image_url: image_url) }.to raise_error(Captcha::Http::HttpError)
      end
    end

    context 'when network error occurs' do
      before do
        allow(Captcha::Http).to receive(:get_binary).with(image_url)
                                                     .and_raise(SocketError.new('getaddrinfo: Name or service not known'))
      end

      it 'raises SocketError' do
        expect { described_class.call(image_url: image_url) }.to raise_error(SocketError)
      end
    end
  end
end
