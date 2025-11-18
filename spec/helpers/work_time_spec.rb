require 'spec_helper'
require 'helpers/work_time'
require 'helpers/file_base'

RSpec.describe WorkTime do
  let(:user_id) { 'test_user' }

  describe '.wait_time' do
    context 'when no last work exists' do
      before do
        allow(FileBase).to receive(:last_work).with(user_id).and_return(nil)
      end

      it 'returns 0' do
        expect(described_class.wait_time(user_id)).to eq(0)
      end
    end

    context 'when last work exists' do
      let(:current_time) { Time.now }

      before do
        allow(Time).to receive(:now).and_return(current_time)
      end

      context 'when less than an hour has passed' do
        let(:last_work_time) { current_time.to_i - 1800 } # 30 minutes ago

        before do
          allow(FileBase).to receive(:last_work).with(user_id).and_return(last_work_time.to_s)
        end

        it 'returns remaining time plus DELTA' do
          expected_wait = (last_work_time + WorkTime::HOUR) - current_time.to_i
          expect(described_class.wait_time(user_id)).to eq(expected_wait + WorkTime::DELTA)
        end

        it 'calculates correct wait time (30 minutes remaining)' do
          # Should wait 30 minutes (1800 seconds) + 10 seconds DELTA
          expect(described_class.wait_time(user_id)).to eq(1800 + WorkTime::DELTA)
        end
      end

      context 'when more than an hour has passed' do
        let(:last_work_time) { current_time.to_i - 7200 } # 2 hours ago

        before do
          allow(FileBase).to receive(:last_work).with(user_id).and_return(last_work_time.to_s)
        end

        it 'returns 0' do
          expect(described_class.wait_time(user_id)).to eq(0)
        end
      end

      context 'when exactly an hour has passed' do
        let(:last_work_time) { current_time.to_i - WorkTime::HOUR }

        before do
          allow(FileBase).to receive(:last_work).with(user_id).and_return(last_work_time.to_s)
        end

        it 'returns DELTA (only the buffer time)' do
          expect(described_class.wait_time(user_id)).to eq(WorkTime::DELTA)
        end
      end

      context 'when just worked (0 seconds ago)' do
        let(:last_work_time) { current_time.to_i }

        before do
          allow(FileBase).to receive(:last_work).with(user_id).and_return(last_work_time.to_s)
        end

        it 'returns full hour plus DELTA' do
          expect(described_class.wait_time(user_id)).to eq(WorkTime::HOUR + WorkTime::DELTA)
        end
      end

      context 'edge case: negative time difference' do
        let(:last_work_time) { current_time.to_i + 100 } # Future time (should not happen)

        before do
          allow(FileBase).to receive(:last_work).with(user_id).and_return(last_work_time.to_s)
        end

        it 'returns hour plus DELTA when last_work is in future' do
          # When last_work is in the future (100 seconds from now),
          # time_to_wait = (last_work + HOUR) - now = 100 + 3600 = 3700
          # Since it's positive, return 3700 + 10 = 3710
          expect(described_class.wait_time(user_id)).to eq(3710)
        end
      end
    end
  end

  describe '.hunt_wait_time' do
    it 'returns a random value' do
      values = 10.times.map { described_class.hunt_wait_time }
      # At least some values should be different (randomness check)
      expect(values.uniq.size).to be > 1
    end

    it 'returns value within range [0, HAUNT_MAX_WAIT)' do
      100.times do
        wait_time = described_class.hunt_wait_time
        expect(wait_time).to be >= 0
        expect(wait_time).to be < WorkTime::HAUNT_MAX_WAIT
      end
    end

    it 'returns an integer' do
      expect(described_class.hunt_wait_time).to be_a(Integer)
    end
  end

  describe 'constants' do
    it 'HOUR is 3600 seconds' do
      expect(WorkTime::HOUR).to eq(3600)
    end

    it 'DELTA is 10 seconds' do
      expect(WorkTime::DELTA).to eq(10)
    end

    it 'HAUNT_MAX_WAIT is 1000' do
      expect(WorkTime::HAUNT_MAX_WAIT).to eq(1000)
    end
  end
end
