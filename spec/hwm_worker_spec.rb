require 'spec_helper'
require 'hwm_worker'

RSpec.describe HwmWorker do
  before do
    # Stub SystemNotifications to prevent actual notifications
    allow(SystemNotifications).to receive(:critical!)
    allow(SystemNotifications).to receive(:error!)
    allow(SystemNotifications).to receive(:warning!)
  end

  it "has a version number" do
    expect(HwmWorker::VERSION).not_to be nil
  end

  it "loads the module successfully" do
    expect(HwmWorker).to be_a(Module)
  end

  describe '.run' do
    let(:user) { instance_double(User, login: 'test_player') }

    before do
      allow(User).to receive(:first).and_return(user)
      allow(Runner).to receive(:call)
    end

    context 'when ZeroBalanceException is raised' do
      let(:error) { Captcha::Request::ZeroBalanceException.new('No credits') }

      before do
        allow(Runner).to receive(:call).and_raise(error)
        allow(Rollbar).to receive(:error)
        allow(STDOUT).to receive(:puts)
      end

      it 'logs error to stdout' do
        expect { described_class.run }.to raise_error(SystemExit)
        expect(STDOUT).to have_received(:puts).with('ERROR: Rucaptcha service has insufficient balance: No credits')
      end

      it 'reports to Rollbar' do
        expect { described_class.run }.to raise_error(SystemExit)
        expect(Rollbar).to have_received(:error).with(
          error,
          message: 'Rucaptcha service has insufficient balance: No credits'
        )
      end

      it 'exits with status code 1' do
        expect { described_class.run }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'handles the exception without propagating it' do
        expect { described_class.run }.to raise_error(SystemExit)
      end

      it 'sends critical notification' do
        expect { described_class.run }.to raise_error(SystemExit)
        expect(SystemNotifications).to have_received(:critical!).with(
          provider: :telegram,
          title: 'Captcha::Request::ZeroBalanceException',
          message: 'Rucaptcha service has insufficient balance: No credits',
          worker_name: 'work',
          user_login: 'test_player',
          error: error
        )
      end
    end

    context 'when other StandardError is raised' do
      let(:error) { StandardError.new('Some other error') }

      before do
        allow(Runner).to receive(:call).and_raise(error)
        allow(Rollbar).to receive(:error)
        allow(ENV).to receive(:[]).with('APP_ENV').and_return('production')
      end

      it 'reports to Rollbar' do
        described_class.run
        expect(Rollbar).to have_received(:error).with(error)
      end

      it 'does not exit' do
        expect { described_class.run }.not_to raise_error
      end

      it 'sends error notification' do
        described_class.run
        expect(SystemNotifications).to have_received(:error!).with(
          provider: :telegram,
          title: 'StandardError',
          message: 'Some other error',
          worker_name: 'work',
          user_login: 'test_player',
          error: error
        )
      end
    end

    context 'when APP_ENV is development and StandardError is raised' do
      let(:error) { StandardError.new('Development error') }

      before do
        allow(Runner).to receive(:call).and_raise(error)
        allow(ENV).to receive(:[]).with('APP_ENV').and_return('development')
      end

      it 'raises the error' do
        expect { described_class.run }.to raise_error(StandardError, 'Development error')
      end
    end
  end

  describe '.hunt' do
    let(:user) { instance_double(User, login: 'test_player') }

    before do
      allow(User).to receive(:first).and_return(user)
      allow(AutoHunt).to receive(:call)
    end

    context 'when ZeroBalanceException is raised' do
      let(:error) { Captcha::Request::ZeroBalanceException.new('No credits') }

      before do
        allow(AutoHunt).to receive(:call).and_raise(error)
        allow(Rollbar).to receive(:error)
        allow(STDOUT).to receive(:puts)
      end

      it 'logs error to stdout' do
        expect { described_class.hunt }.to raise_error(SystemExit)
        expect(STDOUT).to have_received(:puts).with('ERROR: Rucaptcha service has insufficient balance: No credits')
      end

      it 'reports to Rollbar' do
        expect { described_class.hunt }.to raise_error(SystemExit)
        expect(Rollbar).to have_received(:error).with(
          error,
          message: 'Rucaptcha service has insufficient balance: No credits'
        )
      end

      it 'exits with status code 1' do
        expect { described_class.hunt }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'handles the exception without propagating it' do
        expect { described_class.hunt }.to raise_error(SystemExit)
      end

      it 'sends critical notification' do
        expect { described_class.hunt }.to raise_error(SystemExit)
        expect(SystemNotifications).to have_received(:critical!).with(
          provider: :telegram,
          title: 'Captcha::Request::ZeroBalanceException',
          message: 'Rucaptcha service has insufficient balance: No credits',
          worker_name: 'hunt',
          user_login: 'test_player',
          error: error
        )
      end
    end

    context 'when other StandardError is raised' do
      let(:error) { StandardError.new('Some other error') }

      before do
        allow(AutoHunt).to receive(:call).and_raise(error)
        allow(Rollbar).to receive(:error)
        allow(ENV).to receive(:[]).with('APP_ENV').and_return('production')
      end

      it 'reports to Rollbar' do
        described_class.hunt
        expect(Rollbar).to have_received(:error).with(error)
      end

      it 'does not exit' do
        expect { described_class.hunt }.not_to raise_error
      end

      it 'sends error notification' do
        described_class.hunt
        expect(SystemNotifications).to have_received(:error!).with(
          provider: :telegram,
          title: 'StandardError',
          message: 'Some other error',
          worker_name: 'hunt',
          user_login: 'test_player',
          error: error
        )
      end
    end
  end

  describe '.handle_zero_balance_error' do
    let(:error) { Captcha::Request::ZeroBalanceException.new('No credits') }
    let(:user) { instance_double(User, login: 'test_player') }

    before do
      allow(User).to receive(:first).and_return(user)
      allow(Rollbar).to receive(:error)
      allow(STDOUT).to receive(:puts)
    end

    it 'logs error to stdout with proper formatting' do
      expect { described_class.handle_zero_balance_error(error, worker_name: 'work') }.to raise_error(SystemExit)
      expect(STDOUT).to have_received(:puts).with('ERROR: Rucaptcha service has insufficient balance: No credits')
    end

    it 'reports to Rollbar with error and message' do
      expect { described_class.handle_zero_balance_error(error, worker_name: 'work') }.to raise_error(SystemExit)
      expect(Rollbar).to have_received(:error).with(
        error,
        message: 'Rucaptcha service has insufficient balance: No credits'
      )
    end

    it 'exits with status code 1' do
      expect { described_class.handle_zero_balance_error(error, worker_name: 'work') }.to raise_error(SystemExit) do |exit_error|
        expect(exit_error.status).to eq(1)
      end
    end

    it 'sends critical notification' do
      expect { described_class.handle_zero_balance_error(error, worker_name: 'work') }.to raise_error(SystemExit)
      expect(SystemNotifications).to have_received(:critical!).with(
        provider: :telegram,
        title: 'Captcha::Request::ZeroBalanceException',
        message: 'Rucaptcha service has insufficient balance: No credits',
        worker_name: 'work',
        user_login: 'test_player',
        error: error
      )
    end
  end

  describe '.classify_error_level' do
    it 'returns :critical for ZeroBalanceException' do
      error = Captcha::Request::ZeroBalanceException.new('test')
      expect(described_class.classify_error_level(error)).to eq(:critical)
    end

    it 'returns :error for LoginInvalid' do
      error = Login::LoginInvalid.new('test')
      expect(described_class.classify_error_level(error)).to eq(:error)
    end

    it 'returns :error for CannotApplyForJobError' do
      error = Work::CannotApplyForJobError.new('test')
      expect(described_class.classify_error_level(error)).to eq(:error)
    end

    it 'returns :error for AutoHuntBroken' do
      error = Hunt::AutoHuntBroken.new('test')
      expect(described_class.classify_error_level(error)).to eq(:error)
    end

    it 'returns :error for AutoItemNotFound' do
      error = Hunt::AutoItemNotFound.new('test')
      expect(described_class.classify_error_level(error)).to eq(:error)
    end

    it 'returns :warning for NoAvailableWork' do
      error = Work::NoAvailableWork.new('test')
      expect(described_class.classify_error_level(error)).to eq(:warning)
    end

    it 'returns :error for unknown errors' do
      error = RuntimeError.new('test')
      expect(described_class.classify_error_level(error)).to eq(:error)
    end
  end
end
