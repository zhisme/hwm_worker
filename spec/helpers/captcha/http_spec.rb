require 'spec_helper'
require 'helpers/captcha/http'

RSpec.describe Captcha::Http do
  let(:ok_body) { 'pong' }

  def response(klass, code, body = nil)
    res = klass.new('1.1', code, 'status')
    res.instance_variable_set(:@read, true)
    res.instance_variable_set(:@body, body) if body
    res
  end

  def stub_http(*responses)
    http = double('http')
    allow(http).to receive(:request).and_return(*responses)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    http
  end

  before do
    allow(described_class).to receive(:sleep)
  end

  describe '.get' do
    it 'returns the body' do
      stub_http(response(Net::HTTPSuccess, '200', ok_body))

      expect(described_class.get('http://example.com/ping', a: 1, b: 2)).to eq(ok_body)
    end

    it 'sends params as the query string' do
      http = stub_http(response(Net::HTTPSuccess, '200', ok_body))

      described_class.get('http://example.com/ping', a: 1, b: 2)

      expect(http).to have_received(:request).with(having_attributes(path: '/ping?a=1&b=2'))
    end

    it 'returns a binary body when asked' do
      stub_http(response(Net::HTTPSuccess, '200', "\x89PNG".b))

      body = described_class.get_binary('http://example.com/img.png')

      expect(body.encoding).to eq(Encoding::ASCII_8BIT)
    end

    it 'raises HttpError on a client error without retrying' do
      http = stub_http(response(Net::HTTPNotFound, '404'))

      expect { described_class.get('http://example.com/missing') }
        .to raise_error(Captcha::Http::HttpError, 'HTTP 404 for example.com/missing')
      expect(http).to have_received(:request).once
    end

    it 'retries a 5xx once and then raises' do
      http = stub_http(
        response(Net::HTTPServerError, '521'),
        response(Net::HTTPServerError, '521')
      )

      expect { described_class.get('http://example.com/x') }
        .to raise_error(Captcha::Http::HttpError, 'HTTP 521 for example.com/x')
      expect(http).to have_received(:request).twice
    end

    it 'succeeds on the retry after a 5xx' do
      stub_http(
        response(Net::HTTPServerError, '503'),
        response(Net::HTTPSuccess, '200', ok_body)
      )

      expect(described_class.get('http://example.com/x')).to eq(ok_body)
    end

    it 'retries a transport error once' do
      http = double('http')
      allow(http).to receive(:request).and_raise(Errno::ECONNRESET)
      allow(Net::HTTP).to receive(:start).and_yield(http)

      expect { described_class.get('http://example.com/x') }.to raise_error(Errno::ECONNRESET)
      expect(http).to have_received(:request).twice
    end
  end

  describe '.post_form' do
    it 'sends the form encoded as urlencoded body' do
      http = stub_http(response(Net::HTTPSuccess, '200', '{"status":1}'))

      described_class.post_form('http://example.com/in.php', method: 'base64', json: 1)

      expect(http).to have_received(:request).with(
        having_attributes(body: 'method=base64&json=1')
      )
    end
  end

  describe 'timeouts' do
    it 'sets explicit open and read timeouts' do
      stub_http(response(Net::HTTPSuccess, '200', ok_body))

      expect(Net::HTTP).to receive(:start).with(
        'example.com', 80,
        hash_including(
          open_timeout: described_class::OPEN_TIMEOUT,
          read_timeout: described_class::READ_TIMEOUT,
          write_timeout: described_class::WRITE_TIMEOUT
        )
      ).and_yield(double(request: response(Net::HTTPSuccess, '200', ok_body)))

      described_class.get('http://example.com/x')
    end
  end
end
