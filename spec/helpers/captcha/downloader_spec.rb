require 'spec_helper'
require 'helpers/captcha/downloader'
require 'fileutils'

RSpec.describe Captcha::Downloader do
  let(:image_url) { 'http://example.com/captcha.png' }
  let(:test_captcha_path) { 'captcha.png' }
  let(:fake_image_data) { "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR" }

  after do
    # Clean up test file
    FileUtils.rm_f(test_captcha_path) if File.exist?(test_captcha_path)
  end

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
      let(:mock_io) { StringIO.new(fake_image_data) }

      before do
        allow(described_class).to receive(:open).with(image_url).and_return(mock_io)
      end

      it 'downloads the image' do
        described_class.call(image_url: image_url)
        expect(File.exist?(test_captcha_path)).to be true
      end

      it 'writes correct content to file' do
        described_class.call(image_url: image_url)
        content = File.binread(test_captcha_path)
        expect(content).to eq(fake_image_data.force_encoding('ASCII-8BIT'))
      end

      it 'writes file in binary mode' do
        expect(File).to receive(:open).with('captcha.png', 'wb').and_call_original
        described_class.call(image_url: image_url)
      end

      it 'calls open with the image URL' do
        expect(described_class).to receive(:open).with(image_url).and_return(mock_io)
        described_class.call(image_url: image_url)
      end
    end

    context 'with different image URLs' do
      let(:mock_io) { StringIO.new(fake_image_data) }

      before do
        allow(described_class).to receive(:open).and_return(mock_io)
      end

      it 'handles URLs with query parameters' do
        url_with_params = 'http://example.com/captcha.png?id=123&token=abc'
        expect(described_class).to receive(:open).with(url_with_params).and_return(mock_io)
        described_class.call(image_url: url_with_params)
      end

      it 'handles HTTPS URLs' do
        https_url = 'https://example.com/secure/captcha.png'
        expect(described_class).to receive(:open).with(https_url).and_return(mock_io)
        described_class.call(image_url: https_url)
      end
    end
  end

  describe 'file writing behavior' do
    let(:mock_io) { StringIO.new(fake_image_data) }

    before do
      allow(described_class).to receive(:open).with(image_url).and_return(mock_io)
    end

    it 'overwrites existing captcha.png if it exists' do
      # Create initial file
      File.write(test_captcha_path, 'old data')

      # Download new captcha
      described_class.call(image_url: image_url)

      # Should be overwritten
      expect(File.binread(test_captcha_path)).to eq(fake_image_data.force_encoding('ASCII-8BIT'))
    end

    it 'creates file with correct permissions' do
      described_class.call(image_url: image_url)
      expect(File.readable?(test_captcha_path)).to be true
      expect(File.writable?(test_captcha_path)).to be true
    end
  end

  describe 'error handling' do
    context 'when URL is unreachable' do
      before do
        allow(described_class).to receive(:open).with(image_url).and_raise(OpenURI::HTTPError.new('404 Not Found', StringIO.new))
      end

      it 'raises an error' do
        expect { described_class.call(image_url: image_url) }.to raise_error(OpenURI::HTTPError)
      end
    end

    context 'when network error occurs' do
      before do
        allow(described_class).to receive(:open).with(image_url).and_raise(SocketError.new('getaddrinfo: Name or service not known'))
      end

      it 'raises SocketError' do
        expect { described_class.call(image_url: image_url) }.to raise_error(SocketError)
      end
    end
  end
end
