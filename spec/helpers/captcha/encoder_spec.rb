require 'spec_helper'
require 'helpers/captcha/encoder'
require 'base64'
require 'fileutils'

RSpec.describe Captcha::Encoder do
  let(:test_captcha_path) { 'captcha.png' }
  let(:test_image_data) { "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01" }

  before do
    # Create a fake captcha.png file for testing
    File.open(test_captcha_path, 'wb') { |f| f.write(test_image_data) }
  end

  after do
    # Clean up test file
    FileUtils.rm_f(test_captcha_path)
  end

  describe '.call' do
    it 'returns an instance of Encoder' do
      result = described_class.call
      expect(result).to be_a(Captcha::Encoder)
    end

    it 'calls instance call method' do
      instance = described_class.new
      allow(described_class).to receive(:new).and_return(instance)
      expect(instance).to receive(:call).and_call_original

      described_class.call
    end
  end

  describe '#call' do
    let(:encoder) { described_class.new }

    it 'returns self for method chaining' do
      result = encoder.call
      expect(result).to eq(encoder)
    end

    it 'sets base64_captcha attribute' do
      encoder.call
      expect(encoder.base64_captcha).not_to be_nil
    end

    it 'encodes captcha.png to base64' do
      encoder.call
      expected_base64 = Base64.encode64(test_image_data)
      expect(encoder.base64_captcha).to eq(expected_base64)
    end

    it 'reads file in binary mode' do
      expect(File).to receive(:open).with('captcha.png', 'rb').and_call_original
      encoder.call
    end
  end

  describe '#base64_captcha' do
    it 'is readable after calling call' do
      encoder = described_class.new
      encoder.call
      expect(encoder.base64_captcha).to be_a(String)
    end

    it 'is nil before calling call' do
      encoder = described_class.new
      expect(encoder.base64_captcha).to be_nil
    end
  end

  describe 'integration with real base64 encoding' do
    it 'produces valid base64 string' do
      encoder = described_class.call
      base64_string = encoder.base64_captcha

      # Valid base64 should only contain these characters
      expect(base64_string).to match(/\A[A-Za-z0-9+\/=\s]+\z/)

      # Should be decodable
      expect { Base64.decode64(base64_string) }.not_to raise_error
    end

    it 'encoded data can be decoded back to original' do
      encoder = described_class.call
      decoded = Base64.decode64(encoder.base64_captcha)
      expect(decoded).to eq(test_image_data.force_encoding('ASCII-8BIT'))
    end
  end

  describe 'error handling' do
    context 'when captcha.png does not exist' do
      before do
        FileUtils.rm_f(test_captcha_path)
      end

      it 'raises an error' do
        encoder = described_class.new
        expect { encoder.call }.to raise_error(Errno::ENOENT)
      end
    end
  end
end
