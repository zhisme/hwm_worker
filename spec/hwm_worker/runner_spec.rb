require 'spec_helper'
require 'hwm_worker/runner'
require 'helpers/deadline'

RSpec.describe Runner do
  let(:user) { instance_double('User', id: 'test_user', login: 'xa4ba4') }
  let(:session) { instance_double(Capybara::Session) }
  let(:runner) { described_class.allocate }
  let(:logged_lines) { [] }
  # Logger takes the message as a block, so capture the rendered strings.
  let(:logger) do
    lines = logged_lines
    Class.new do
      define_method(:info) { |message = nil, &block| lines << (block ? block.call : message) }
      alias_method :debug, :info
      alias_method :fatal, :info
    end.new
  end

  before do
    runner.instance_variable_set(:@user, user)
    runner.instance_variable_set(:@session, session)
    allow(WorkLogger).to receive(:current).and_return(logger)
    allow(runner).to receive(:sleep)
  end

  describe '#call' do
    context 'when the cooldown sleep plus work fits the remaining budget' do
      before do
        allow(WorkTime).to receive(:wait_time).with('test_user').and_return(240)
        allow(Deadline).to receive(:left).and_return(240 + Runner::WORK_BUDGET + 1)
      end

      it 'sleeps and runs login and work' do
        expect(runner).to receive(:sleep).with(240)
        expect(Login).to receive(:call).with(session: session, user: user)
        expect(Work).to receive(:call).with(session: session, user: user)

        runner.call
      end

      it 'logs every phase in order with budget context' do
        allow(Login).to receive(:call)
        allow(Work).to receive(:call)

        runner.call

        phases = logged_lines.grep(/^run phase=/).map { |line| line[/phase=(\w+)/, 1] }
        expect(phases).to eq(%w[start slept login_done done])
        expect(logged_lines).to include(
          a_string_including('run phase=done', 'outcome=applied', 'budget_left=541s')
        )
      end
    end

    context 'when work raises' do
      before do
        allow(WorkTime).to receive(:wait_time).with('test_user').and_return(0)
        allow(Deadline).to receive(:left).and_return(600)
        allow(Login).to receive(:call)
        allow(Work).to receive(:call).and_raise(Work::CannotApplyForJobError, 'no form')
      end

      it 'logs the failed outcome and re-raises' do
        expect { runner.call }.to raise_error(Work::CannotApplyForJobError)

        expect(logged_lines).to include(
          a_string_including('run phase=done', 'outcome=failed', 'error=Work::CannotApplyForJobError')
        )
      end
    end

    context 'when the sleep would eat the whole budget' do
      before do
        allow(WorkTime).to receive(:wait_time).with('test_user').and_return(240)
        allow(Deadline).to receive(:left).and_return(260)
      end

      it 'skips without touching the browser' do
        expect(runner).not_to receive(:sleep)
        expect(Login).not_to receive(:call)
        expect(Work).not_to receive(:call)

        runner.call
      end

      it 'logs why the run was skipped' do
        runner.call

        expect(logged_lines).to include(
          a_string_including('run phase=skip', 'user=xa4ba4', 'reason=budget', 'cooldown_wait=240s', 'budget_left=260s')
        )
      end

      it 'does not log a login or done phase' do
        runner.call

        expect(logged_lines).not_to include(a_string_including('phase=login_done'))
        expect(logged_lines).not_to include(a_string_including('phase=done'))
      end
    end

    context 'when there is exactly enough budget' do
      before do
        allow(WorkTime).to receive(:wait_time).with('test_user').and_return(100)
        allow(Deadline).to receive(:left).and_return(100 + Runner::WORK_BUDGET)
      end

      it 'proceeds, RESERVE already covers the boundary' do
        expect(Login).to receive(:call)
        expect(Work).to receive(:call)

        runner.call
      end
    end

    context 'when one second short of enough budget' do
      before do
        allow(WorkTime).to receive(:wait_time).with('test_user').and_return(100)
        allow(Deadline).to receive(:left).and_return(100 + Runner::WORK_BUDGET - 1)
      end

      it 'skips' do
        expect(Login).not_to receive(:call)

        runner.call
      end
    end

    context 'when no cooldown is pending but the budget is already blown' do
      before do
        allow(WorkTime).to receive(:wait_time).with('test_user').and_return(0)
        allow(Deadline).to receive(:left).and_return(-5.0)
      end

      it 'skips' do
        expect(Login).not_to receive(:call)

        runner.call
      end
    end

    context 'when running without a budget' do
      before do
        allow(WorkTime).to receive(:wait_time).with('test_user').and_return(240)
        allow(Deadline).to receive(:left).and_return(Float::INFINITY)
      end

      it 'always proceeds' do
        expect(Login).to receive(:call)
        expect(Work).to receive(:call)

        runner.call
      end
    end
  end
end
