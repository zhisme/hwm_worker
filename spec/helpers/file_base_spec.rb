require 'spec_helper'
require 'helpers/file_base'
require 'fileutils'
require 'pathname'

RSpec.describe FileBase do
  let(:user_id) { 'test_user_123' }
  let(:test_path) { FileBase::PATH }
  let(:db_file_path) { test_path.join("last-work-#{user_id}.db") }

  before do
    # Create test directory
    FileUtils.mkdir_p(test_path) unless File.directory?(test_path)
  end

  after do
    # Clean up test files
    FileUtils.rm_f(db_file_path) if File.exist?(db_file_path)
  end

  describe '.last_work' do
    context 'when file does not exist' do
      it 'returns nil' do
        expect(described_class.last_work(user_id)).to be_nil
      end
    end

    context 'when file exists' do
      let(:timestamp) { '1234567890' }

      before do
        File.write(db_file_path, "#{timestamp}\n")
      end

      it 'returns the timestamp as a string' do
        expect(described_class.last_work(user_id)).to eq(timestamp)
      end

      it 'strips whitespace from the content' do
        File.write(db_file_path, "  #{timestamp}  \n")
        expect(described_class.last_work(user_id)).to eq(timestamp)
      end
    end
  end

  describe '.write_last_work' do
    it 'creates a new file with current timestamp' do
      freeze_time = Time.now
      allow(Time).to receive(:now).and_return(freeze_time)

      described_class.write_last_work(user_id)

      expect(File.exist?(db_file_path)).to be true
      expect(File.read(db_file_path).strip).to eq(freeze_time.to_i.to_s)
    end

    it 'overwrites existing file with new timestamp' do
      old_timestamp = (Time.now - 3600).to_i
      File.write(db_file_path, "#{old_timestamp}\n")

      freeze_time = Time.now
      allow(Time).to receive(:now).and_return(freeze_time)

      described_class.write_last_work(user_id)

      expect(File.read(db_file_path).strip).to eq(freeze_time.to_i.to_s)
    end

    it 'creates file with write permissions' do
      described_class.write_last_work(user_id)
      expect(File.writable?(db_file_path)).to be true
    end
  end

  describe 'integration test' do
    it 'write and read workflow works correctly' do
      # Initially no file exists
      expect(described_class.last_work(user_id)).to be_nil

      # Write timestamp
      freeze_time = Time.now
      allow(Time).to receive(:now).and_return(freeze_time)
      described_class.write_last_work(user_id)

      # Read it back
      expect(described_class.last_work(user_id)).to eq(freeze_time.to_i.to_s)
    end
  end

  describe 'path generation' do
    it 'generates correct path for different user IDs' do
      user_ids = ['user1', 'user2', 'admin']

      user_ids.each do |uid|
        described_class.write_last_work(uid)
        expected_path = test_path.join("last-work-#{uid}.db")
        expect(File.exist?(expected_path)).to be true
        FileUtils.rm_f(expected_path)
      end
    end
  end
end
