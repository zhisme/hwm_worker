require 'spec_helper'
require 'helpers/captcha/encoder'
require 'base64'

RSpec.describe Captcha::Encoder do
  let(:image_data) { "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01".b }

  describe '.call' do
    it 'returns an instance of Encoder' do
      result = described_class.call(image_data)
      expect(result).to be_a(Captcha::Encoder)
    end

    it 'encodes the image data it was given' do
      encoder = described_class.call(image_data)
      expect(encoder.base64_captcha).to eq(Base64.encode64(image_data))
    end
  end

  describe '#base64_captcha' do
    it 'is nil before calling call' do
      encoder = described_class.new(image_data)
      expect(encoder.base64_captcha).to be_nil
    end

    it 'is a valid base64 string after calling call' do
      encoder = described_class.call(image_data)
      expect(encoder.base64_captcha).to match(/\A[A-Za-z0-9+\/=\s]+\z/)
    end
  end

  describe 'round trip' do
    it 'decodes back to the original bytes' do
      encoder = described_class.call(image_data)
      expect(Base64.decode64(encoder.base64_captcha)).to eq(image_data)
    end
  end

  describe 'error handling' do
    it 'raises when there is no image data' do
      expect { described_class.call(nil) }.to raise_error(TypeError)
    end
  end
end
