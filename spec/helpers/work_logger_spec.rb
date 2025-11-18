require 'spec_helper'
require 'helpers/work_logger'
require 'logger'

RSpec.describe WorkLogger do
  describe 'class attribute' do
    it 'has a current logger' do
      expect(described_class.current).to be_a(Logger)
    end

    it 'is accessible via class method' do
      expect(described_class).to respond_to(:current)
    end
  end

  describe '.current' do
    it 'returns a Logger instance' do
      expect(described_class.current).to be_instance_of(Logger)
    end

    it 'logs to STDOUT' do
      # Capture the logger's logdev
      logdev = described_class.current.instance_variable_get(:@logdev)
      dev = logdev.instance_variable_get(:@dev)

      expect(dev).to eq(STDOUT)
    end

    it 'is the same instance across calls' do
      logger1 = described_class.current
      logger2 = described_class.current

      expect(logger1).to equal(logger2)
    end
  end

  describe 'logging functionality' do
    let(:output) { StringIO.new }
    let(:test_logger) { Logger.new(output) }

    before do
      # Replace logger with test logger for output capture
      described_class.instance_variable_set(:@current, test_logger)
    end

    after do
      # Reset to original logger
      described_class.instance_variable_set(:@current, Logger.new(STDOUT))
    end

    it 'can log info messages' do
      described_class.current.info('Test info message')
      output.rewind
      expect(output.read).to include('Test info message')
    end

    it 'can log error messages' do
      described_class.current.error('Test error message')
      output.rewind
      expect(output.read).to include('Test error message')
    end

    it 'can log warn messages' do
      described_class.current.warn('Test warning message')
      output.rewind
      expect(output.read).to include('Test warning message')
    end

    it 'can log debug messages' do
      described_class.current.debug('Test debug message')
      output.rewind
      expect(output.read).to include('Test debug message')
    end

    it 'supports all standard logger levels' do
      expect(described_class.current).to respond_to(:info)
      expect(described_class.current).to respond_to(:error)
      expect(described_class.current).to respond_to(:warn)
      expect(described_class.current).to respond_to(:debug)
      expect(described_class.current).to respond_to(:fatal)
    end
  end

  describe 'Docker/Kubernetes compatibility' do
    it 'logs to STDOUT for container compatibility' do
      # This is the key requirement - logger must use STDOUT
      logdev = described_class.current.instance_variable_get(:@logdev)
      dev = logdev.instance_variable_get(:@dev)

      expect(dev).to eq(STDOUT)
    end

    it 'does not log to a file' do
      logdev = described_class.current.instance_variable_get(:@logdev)
      dev = logdev.instance_variable_get(:@dev)

      expect(dev).not_to be_a(File)
    end
  end

  describe 'initialization' do
    it 'initializes logger on class load' do
      # The logger should be created when the class is loaded
      expect(described_class.instance_variable_get(:@current)).to be_a(Logger)
    end

    it 'does not require explicit initialization' do
      # Should work immediately without calling any initialization method
      expect { described_class.current.info('test') }.not_to raise_error
    end
  end
end
