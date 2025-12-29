# frozen_string_literal: true

require 'spec_helper'
require 'hwm_worker'

RSpec.describe HwmWorker do
  let(:user) { instance_double(User, login: 'test_player') }

  before do
    allow(User).to receive(:first).and_return(user)
    allow(SystemNotifications).to receive(:notify_error)
  end

  it 'has a version number' do
    expect(HwmWorker::VERSION).not_to be_nil
  end

  it 'loads the module successfully' do
    expect(HwmWorker).to be_a(Module)
  end

  describe '.run' do
    before do
      allow(Runner).to receive(:call)
    end

    context 'when ZeroBalanceException is raised' do
      let(:error) { Captcha::Request::ZeroBalanceException.new('No credits') }

      before do
        allow(Runner).to receive(:call).and_raise(error)
        allow(Rollbar).to receive(:error)
      end

      it 'sends notification' do
        expect { described_class.run }.to raise_error(SystemExit)
        expect(SystemNotifications).to have_received(:notify_error).with(
          error,
          provider: :telegram,
          worker_name: 'work',
          user: user
        )
      end

      it 'reports to Rollbar' do
        expect { described_class.run }.to raise_error(SystemExit)
        expect(Rollbar).to have_received(:error).with(error)
      end

      it 'exits with status code 1' do
        expect { described_class.run }.to raise_error(SystemExit) do |exit_error|
          expect(exit_error.status).to eq(1)
        end
      end
    end

    context 'when other StandardError is raised' do
      let(:error) { StandardError.new('Some other error') }

      before do
        allow(Runner).to receive(:call).and_raise(error)
        allow(Rollbar).to receive(:error)
        allow(ENV).to receive(:[]).with('APP_ENV').and_return('production')
      end

      it 'sends notification' do
        described_class.run
        expect(SystemNotifications).to have_received(:notify_error).with(
          error,
          provider: :telegram,
          worker_name: 'work',
          user: user
        )
      end

      it 'reports to Rollbar' do
        described_class.run
        expect(Rollbar).to have_received(:error).with(error)
      end

      it 'does not exit' do
        expect { described_class.run }.not_to raise_error
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
    before do
      allow(AutoHunt).to receive(:call)
    end

    context 'when ZeroBalanceException is raised' do
      let(:error) { Captcha::Request::ZeroBalanceException.new('No credits') }

      before do
        allow(AutoHunt).to receive(:call).and_raise(error)
        allow(Rollbar).to receive(:error)
      end

      it 'sends notification' do
        expect { described_class.hunt }.to raise_error(SystemExit)
        expect(SystemNotifications).to have_received(:notify_error).with(
          error,
          provider: :telegram,
          worker_name: 'hunt',
          user: user
        )
      end

      it 'reports to Rollbar' do
        expect { described_class.hunt }.to raise_error(SystemExit)
        expect(Rollbar).to have_received(:error).with(error)
      end

      it 'exits with status code 1' do
        expect { described_class.hunt }.to raise_error(SystemExit) do |exit_error|
          expect(exit_error.status).to eq(1)
        end
      end
    end

    context 'when other StandardError is raised' do
      let(:error) { StandardError.new('Some other error') }

      before do
        allow(AutoHunt).to receive(:call).and_raise(error)
        allow(Rollbar).to receive(:error)
        allow(ENV).to receive(:[]).with('APP_ENV').and_return('production')
      end

      it 'sends notification' do
        described_class.hunt
        expect(SystemNotifications).to have_received(:notify_error).with(
          error,
          provider: :telegram,
          worker_name: 'hunt',
          user: user
        )
      end

      it 'reports to Rollbar' do
        described_class.hunt
        expect(Rollbar).to have_received(:error).with(error)
      end

      it 'does not exit' do
        expect { described_class.hunt }.not_to raise_error
      end
    end
  end
end
