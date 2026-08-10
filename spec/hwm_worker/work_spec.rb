require 'spec_helper'
require 'hwm_worker/work'

RSpec.describe Work do
  let(:user) { instance_double('User', id: 'test_user', login: 'xa4ba4') }
  let(:logged_lines) { [] }
  let(:logger) do
    lines = logged_lines
    Class.new do
      define_method(:info) { |message = nil, &block| lines << (block ? block.call : message) }
      alias_method :debug, :info
    end.new
  end

  before { allow(WorkLogger).to receive(:current).and_return(logger) }

  describe 'interval logging' do
    let(:now) { Time.now }

    before { allow(Time).to receive(:now).and_return(now) }

    context 'when a previous application is recorded' do
      it 'reports the gap and how far past the cooldown it landed' do
        allow(FileBase).to receive(:last_work).with('test_user').and_return((now.to_i - 3712).to_s)

        described_class.send(:log_interval, user)

        expect(logged_lines).to include('applied user=xa4ba4 interval=3712s over_cooldown=112s')
      end

      it 'reports a negative over_cooldown when applied too early' do
        allow(FileBase).to receive(:last_work).with('test_user').and_return((now.to_i - 3400).to_s)

        described_class.send(:log_interval, user)

        expect(logged_lines).to include('applied user=xa4ba4 interval=3400s over_cooldown=-200s')
      end

      it 'reports a large gap when hourly runs were skipped' do
        allow(FileBase).to receive(:last_work).with('test_user').and_return((now.to_i - 7300).to_s)

        described_class.send(:log_interval, user)

        expect(logged_lines).to include('applied user=xa4ba4 interval=7300s over_cooldown=3700s')
      end
    end

    context 'when nothing was ever recorded' do
      it 'does not blow up on nil' do
        allow(FileBase).to receive(:last_work).with('test_user').and_return(nil)

        expect { described_class.send(:log_interval, user) }.not_to raise_error
        expect(logged_lines).to include('applied user=xa4ba4 interval=none')
      end
    end
  end
end
