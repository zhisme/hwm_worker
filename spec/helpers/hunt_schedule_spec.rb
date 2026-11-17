require 'spec_helper'
require 'helpers/hunt_schedule'
require 'fileutils'

RSpec.describe HuntSchedule do
  let(:schedule_path) { 'file_base/next_hunt_schedule_test' }

  around do |example|
    original = ENV.to_hash
    ENV['HUNT_SCHEDULE_FILE'] = schedule_path
    example.run
    ENV.replace(original)
    FileUtils.rm_f(schedule_path)
  end

  describe '.next_run_at' do
    let(:now) { Time.at(1_700_000_000) }

    it 'never schedules closer than the minimum gap' do
      ENV['HUNT_MIN_GAP_SECONDS'] = '14400'
      ENV['HUNT_MAX_GAP_SECONDS'] = '72000'

      500.times do
        gap = described_class.next_run_at(now) - now
        expect(gap).to be >= 14_400
        expect(gap).to be <= 72_000
      end
    end

    it 'spreads runs across the range instead of picking one value' do
      ENV['HUNT_MIN_GAP_SECONDS'] = '14400'
      ENV['HUNT_MAX_GAP_SECONDS'] = '72000'

      gaps = 50.times.map { described_class.next_run_at(now) - now }
      expect(gaps.uniq.size).to be > 1
    end

    it 'returns the minimum gap when the range is a single point' do
      ENV['HUNT_MIN_GAP_SECONDS'] = '14400'
      ENV['HUNT_MAX_GAP_SECONDS'] = '14400'

      expect(described_class.next_run_at(now) - now).to eq(14_400)
    end

    it 'refuses an inverted range instead of picking a bogus time' do
      ENV['HUNT_MIN_GAP_SECONDS'] = '72000'
      ENV['HUNT_MAX_GAP_SECONDS'] = '14400'

      expect { described_class.next_run_at(now) }.to raise_error(ArgumentError, /max gap/)
    end
  end

  describe '.cron_expression' do
    it 'formats minute and hour as a daily cron expression' do
      expect(described_class.cron_expression(Time.new(2026, 7, 29, 13, 47, 0))).to eq('47 13 * * *')
    end

    it 'does not zero-pad, so cron parses the fields as numbers' do
      expect(described_class.cron_expression(Time.new(2026, 7, 29, 3, 5, 0))).to eq('5 3 * * *')
    end

    it 'handles midnight' do
      expect(described_class.cron_expression(Time.new(2026, 7, 29, 0, 0, 0))).to eq('0 0 * * *')
    end

    it 'handles the last minute of the day' do
      expect(described_class.cron_expression(Time.new(2026, 7, 29, 23, 59, 0))).to eq('59 23 * * *')
    end
  end

  describe '.write_next_run' do
    let(:now) { Time.at(1_700_000_000) }

    before do
      ENV['HUNT_MIN_GAP_SECONDS'] = '14400'
      ENV['HUNT_MAX_GAP_SECONDS'] = '14400'
      FileUtils.mkdir_p('file_base')
    end

    it 'writes a cron expression the scheduler will accept' do
      described_class.write_next_run(now)

      expect(File.read(schedule_path)).to match(/\A\d{1,2} \d{1,2} \* \* \*\z/)
    end

    it 'writes the time it returns' do
      at = described_class.write_next_run(now)

      expect(File.read(schedule_path)).to eq("#{at.min} #{at.hour} * * *")
    end

    it 'overwrites the previous schedule' do
      File.write(schedule_path, '0 0 * * *')

      described_class.write_next_run(now)

      expect(File.read(schedule_path)).not_to eq('0 0 * * *')
    end

    it 'crosses midnight without wrapping into a negative hour' do
      ENV['HUNT_MIN_GAP_SECONDS'] = '3600'
      ENV['HUNT_MAX_GAP_SECONDS'] = '3600'
      late = Time.new(2026, 7, 29, 23, 30, 0)

      described_class.write_next_run(late)

      expect(File.read(schedule_path)).to eq('30 0 * * *')
    end

    it 'returns nil and leaves no file when the path is unwritable' do
      ENV['HUNT_SCHEDULE_FILE'] = 'file_base/no_such_dir/next_hunt_schedule'

      expect(described_class.write_next_run(now)).to be_nil
    end

    it 'does not raise when the path is unwritable, so a good hunt is not marked failed' do
      ENV['HUNT_SCHEDULE_FILE'] = 'file_base/no_such_dir/next_hunt_schedule'

      expect { described_class.write_next_run(now) }.not_to raise_error
    end
  end
end
