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

  describe 'application verification' do
    let(:session) { instance_double(Capybara::Session) }
    let(:submit_button) { instance_double(Capybara::Node::Element) }
    let(:gold_element) { instance_double(Capybara::Node::Element, text: '61,372') }

    before do
      allow(FileBase).to receive(:last_work).and_return(nil)
      allow(FileBase).to receive(:write_last_work)
      allow(Rollbar).to receive(:info)
      allow(submit_button).to receive(:click)
      allow(session).to receive(:find).with('input.getjob_submitBtn').and_return(submit_button)
      allow(session).to receive(:find).with('img[hwm_label="Золото"] + span').and_return(gold_element)
      allow(gold_element).to receive(:text).with(:all).and_return('61,372')
    end

    # Capybara does the matching for real here: the double returns whether the
    # pattern hits the page text, so a broken pattern fails the spec.
    def stub_page_text(text)
      allow(session).to receive(:has_text?) { |pattern| pattern.match?(text) }
    end

    Work::EMPLOYED_MARKERS.each do |marker|
      it "records the application when the page says #{marker.inspect}" do
        stub_page_text("Balance: 280,459,582\n#{marker}\nFacility functioning log")

        described_class.send(:apply_work_without_captcha, session, user)

        expect(FileBase).to have_received(:write_last_work).with('test_user')
        expect(logged_lines).to include('xa4ba4 successfully applied for a job. Wait hour.')
      end
    end

    it 'raises when no marker is on the page' do
      stub_page_text('Free posts: 71')

      expect { described_class.send(:apply_work_without_captcha, session, user) }
        .to raise_error(Work::NotAppliedForJobError, /xa4ba4/)
    end

    it 'raises on a near miss of the marker wording' do
      stub_page_text('You can be employed.')

      expect { described_class.send(:apply_work_without_captcha, session, user) }
        .to raise_error(Work::NotAppliedForJobError)
    end

    it 'does not record the application when the marker is missing' do
      stub_page_text('Free posts: 71')

      expect { described_class.send(:apply_work_without_captcha, session, user) }
        .to raise_error(Work::NotAppliedForJobError)

      expect(FileBase).not_to have_received(:write_last_work)
      expect(logged_lines).not_to include('xa4ba4 successfully applied for a job. Wait hour.')
    end

    it 'does not swallow the missing marker as a captcha apply failure' do
      stub_page_text('Free posts: 71')
      allow(session).to receive(:find).with('#code').and_return(submit_button)
      allow(session).to receive(:find).with('.getjob_submitBtn').and_return(submit_button)
      allow(submit_button).to receive(:fill_in)
      allow(Captcha::Main).to receive(:call).and_return('1234')
      captcha_el = instance_double(Capybara::Node::Element)
      allow(captcha_el).to receive(:[]).with(:src).and_return('https://example.com/captcha.png')

      expect { described_class.send(:apply_work_with_captcha, session, user, captcha_el) }
        .to raise_error(Work::NotAppliedForJobError)
    end
  end

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
