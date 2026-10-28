require 'spec_helper'
require 'hwm_worker/work'

RSpec.describe Work do
  let(:user) { instance_double('User', id: 'test_user', login: 'test_login') }
  let(:logged_lines) { [] }
  let(:logger) do
    lines = logged_lines
    Class.new do
      define_method(:info) { |message = nil, &block| lines << (block ? block.call : message) }
      alias_method :debug, :info
      alias_method :warn, :info
    end.new
  end

  before { allow(WorkLogger).to receive(:current).and_return(logger) }

  describe 'workaholic penalty' do
    let(:page_html) { '' }
    let(:app) do
      html = page_html
      ->(_env) { [200, { 'content-type' => 'text/html; charset=utf-8' }, [html]] }
    end
    let(:session) { Capybara::Session.new(:rack_test, app) }
    let(:events) { [] }

    before do
      allow(described_class).to receive(:find_work) { session.visit('/') }
      allow(described_class).to receive(:apply_work) { events << :apply }
      allow(Rollbar).to receive(:warning) { |message| events << message }
    end

    # The wage cell of the facility page, where the penalty multiplier appears
    # in red between the base multiplier and the result.
    def wage_cell(penalty)
      '<tr><td>Зарплата: </td><td><b><table><tr><td><b>171</b></td></tr></table></b></td>' \
        "<td>*1.5#{penalty} = 25</td></tr>"
    end

    context 'when the facility page shows the penalty' do
      let(:page_html) { wage_cell('<font color="#E65054"><b>*0.1 (штраф трудоголика)</b></font>') }

      it 'warns with the parsed coefficient before applying' do
        described_class.call(session: session, user: user)

        expect(events).to eq(['test_login has the workaholic penalty, wage is x0.1 until a battle is won', :apply])
        expect(logged_lines).to include('test_login has the workaholic penalty, wage is x0.1 until a battle is won')
      end
    end

    context 'when the penalty coefficient differs' do
      let(:page_html) { wage_cell('<font color="#E65054"><b>*0.25 (штраф трудоголика)</b></font>') }

      it 'reports the coefficient from the page' do
        described_class.call(session: session, user: user)

        expect(events.first).to include('wage is x0.25 until')
      end
    end

    context 'when the wage line has no penalty' do
      let(:page_html) { wage_cell('') }

      it 'applies without a warning' do
        described_class.call(session: session, user: user)

        expect(events).to eq([:apply])
      end
    end

    context 'when the wording is a near miss' do
      let(:page_html) { wage_cell('<font color="#E65054"><b>*0.1 (штраф трудоголик)</b></font>') }

      it 'applies without a warning' do
        described_class.call(session: session, user: user)

        expect(events).to eq([:apply])
      end
    end
  end

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
      allow(session).to receive(:has_text?) do |matcher, **|
        matcher.is_a?(Regexp) ? matcher.match?(text) : text.include?(matcher)
      end
    end

    Work::EMPLOYED_MARKERS.each do |marker|
      it "records the application when the page says #{marker.inspect}" do
        stub_page_text("Balance: 280,459,582\n#{marker}\nFacility functioning log")

        described_class.send(:apply_work_without_captcha, session, user)

        expect(FileBase).to have_received(:write_last_work).with('test_user')
        expect(logged_lines).to include('test_login successfully applied for a job. Wait hour.')
      end
    end

    it 'raises a distinct error when the submit was rejected as too early' do
      stub_page_text("Free posts: 71\n#{Work::TOO_EARLY_MARKER}")

      expect { described_class.send(:apply_work_without_captcha, session, user) }
        .to raise_error(Work::AppliedTooEarlyError, /test_login/)
    end

    it 'does not record a cooldown timestamp for a too early submit' do
      stub_page_text(Work::TOO_EARLY_MARKER)

      expect { described_class.send(:apply_work_without_captcha, session, user) }
        .to raise_error(Work::AppliedTooEarlyError)

      expect(FileBase).not_to have_received(:write_last_work)
      expect(logged_lines).not_to include('test_login successfully applied for a job. Wait hour.')
    end

    it 'prefers the employed marker when the page carries both' do
      stub_page_text("Вы уже устроены.\n#{Work::TOO_EARLY_MARKER}")

      described_class.send(:apply_work_without_captcha, session, user)

      expect(FileBase).to have_received(:write_last_work).with('test_user')
    end

    it 'raises when no marker is on the page' do
      stub_page_text('Free posts: 71')

      expect { described_class.send(:apply_work_without_captcha, session, user) }
        .to raise_error(Work::NotAppliedForJobError, /test_login/)
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
      expect(logged_lines).not_to include('test_login successfully applied for a job. Wait hour.')
    end

    context 'when applying with a captcha' do
      let(:captcha_el) { instance_double(Capybara::Node::Element) }

      before do
        allow(session).to receive(:find).with('#code').and_return(submit_button)
        allow(session).to receive(:find).with('.getjob_submitBtn').and_return(submit_button)
        allow(submit_button).to receive(:fill_in)
        allow(Captcha::Main).to receive(:call).and_return('1234')
        allow(captcha_el).to receive(:[]).with(:src).and_return('https://example.com/captcha.png')
        allow(Captcha::Request).to receive(:last_captcha_id).and_return('777')
        allow(Captcha::Request).to receive(:report_bad)
      end

      it 'does not swallow the missing marker as a captcha apply failure' do
        stub_page_text('Free posts: 71')

        expect { described_class.send(:apply_work_with_captcha, session, user, captcha_el) }
          .to raise_error(Work::NotAppliedForJobError)
      end

      it 'reports the captcha as wrongly solved when the marker is missing' do
        stub_page_text('Free posts: 71')

        expect { described_class.send(:apply_work_with_captcha, session, user, captcha_el) }
          .to raise_error(Work::NotAppliedForJobError)

        expect(Captcha::Request).to have_received(:report_bad).with('777')
      end

      it 'keeps the original error when the report itself fails' do
        stub_page_text('Free posts: 71')
        allow(Captcha::Request).to receive(:report_bad).and_raise(SocketError, 'getaddrinfo failed')

        expect { described_class.send(:apply_work_with_captcha, session, user, captcha_el) }
          .to raise_error(Work::NotAppliedForJobError)

        expect(logged_lines).to include('captcha report_bad failed id=777 error=SocketError')
      end

      it 'does not report the captcha when the job was taken' do
        stub_page_text('You are already employed.')

        described_class.send(:apply_work_with_captcha, session, user, captcha_el)

        expect(Captcha::Request).not_to have_received(:report_bad)
      end

      it 'does not report the captcha when the submit was too early' do
        stub_page_text(Work::TOO_EARLY_MARKER)

        expect { described_class.send(:apply_work_with_captcha, session, user, captcha_el) }
          .to raise_error(Work::AppliedTooEarlyError)

        expect(Captcha::Request).not_to have_received(:report_bad)
      end
    end

    it 'does not report a captcha on the manual branch' do
      stub_page_text('Free posts: 71')
      allow(Captcha::Request).to receive(:report_bad)

      expect { described_class.send(:apply_work_without_captcha, session, user) }
        .to raise_error(Work::NotAppliedForJobError)

      expect(Captcha::Request).not_to have_received(:report_bad)
    end
  end

  describe 'retry after a rejected submit' do
    let(:session) { instance_double(Capybara::Session) }
    let(:attempts) { [] }

    before do
      allow(described_class).to receive(:find_work) { attempts << :find }
      allow(session).to receive(:find).and_raise(Capybara::ElementNotFound)
      allow(Deadline).to receive(:exceeded?).and_return(false)
    end

    def apply_results(*results)
      queue = results.dup
      allow(described_class).to receive(:apply_work) do
        result = queue.shift
        raise result if result
      end
    end

    it 'applies again from the map when the first submit was not taken' do
      apply_results(Work::NotAppliedForJobError, nil)

      expect { described_class.call(session: session, user: user) }.not_to raise_error

      expect(attempts.size).to eq(2)
      expect(logged_lines).to include(a_string_starting_with('apply retry user=test_login attempt=2'))
    end

    it 'gives up after the second rejected submit' do
      apply_results(Work::NotAppliedForJobError, Work::NotAppliedForJobError, nil)

      expect { described_class.call(session: session, user: user) }
        .to raise_error(Work::NotAppliedForJobError)

      expect(attempts.size).to eq(2)
    end

    it 'does not retry when the job budget is exhausted' do
      apply_results(Work::NotAppliedForJobError, nil)
      allow(Deadline).to receive(:exceeded?).and_return(true)

      expect { described_class.call(session: session, user: user) }
        .to raise_error(Work::NotAppliedForJobError)

      expect(attempts.size).to eq(1)
    end

    [Work::AppliedTooEarlyError, Work::CannotApplyForJobError, Work::NoAvailableWork].each do |error|
      it "does not retry on #{error}" do
        apply_results(error, nil)

        expect { described_class.call(session: session, user: user) }.to raise_error(error)

        expect(attempts.size).to eq(1)
      end
    end
  end

  describe 'job row selection' do
    let(:fixture) { File.read(File.expand_path('../fixtures/map.html', __dir__)) }

    let(:map_html) { fixture }
    let(:app) do
      html = map_html
      lambda do |env|
        body = env['PATH_INFO'].end_with?('map.php') ? html : "facility #{env['PATH_INFO']}"
        [200, { 'content-type' => 'text/html; charset=utf-8' }, [body]]
      end
    end
    let(:session) { Capybara::Session.new(:rack_test, app) }

    # Drops the »»» apply link text from the given facility rows, the way a
    # facility without free posts left the old row 3 lookup on 2026-10-18.
    def full(html, *ids)
      ids.reduce(html) do |page, id|
        page.sub(/(object-info\.php\?id=#{id}"\);.*)&nbsp;&raquo;&raquo;&raquo;&nbsp;/, '\1&nbsp;')
      end
    end

    it 'starts from a fixture where every facility has an apply link' do
      expect(fixture.scan('&raquo;&raquo;&raquo;').size).to eq(5)
    end

    context 'when the first facility has a free post' do
      it 'opens the first facility' do
        described_class.send(:find_work, session)

        expect(session.current_url).to end_with('/object-info.php?id=19')
      end
    end

    context 'when the first facilities are full' do
      let(:map_html) { full(fixture, 19, 302) }

      it 'opens the first facility that has a free post' do
        described_class.send(:find_work, session)

        expect(session.current_url).to end_with('/object-info.php?id=281')
      end
    end

    context 'when only the last facility has a free post' do
      let(:map_html) { full(fixture, 19, 302, 281, 344) }

      it 'opens it' do
        described_class.send(:find_work, session)

        expect(session.current_url).to end_with('/object-info.php?id=260')
      end
    end

    context 'when no facility has a free post' do
      let(:map_html) { full(fixture, 19, 302, 281, 344, 260) }

      it 'raises no available work' do
        expect { described_class.send(:find_work, session) }
          .to raise_error(Work::NoAvailableWork, /no facility/)
      end
    end

    context 'when the table has no facility rows' do
      let(:map_html) { fixture.gsub(/^<tr  class="map_obj_table_hover".*$/, '') }

      it 'raises no available work' do
        expect { described_class.send(:find_work, session) }
          .to raise_error(Work::NoAvailableWork)
      end
    end

    context 'when »»» appears outside the apply column' do
      let(:map_html) do
        full(fixture, 19, 302, 281, 344, 260)
          .sub('&nbsp;Sulphur dune&nbsp;', '&nbsp;&raquo;&raquo;&raquo;&nbsp;')
          .sub('</center>', '<a href="elsewhere.php">&raquo;&raquo;&raquo;</a></center>')
      end

      it 'does not follow it' do
        expect { described_class.send(:find_work, session) }
          .to raise_error(Work::NoAvailableWork)
      end
    end

    context 'when the jobs table is missing' do
      let(:map_html) { '<html><body>Please log in</body></html>' }

      it 'raises element not found instead of reporting no work' do
        expect { described_class.send(:find_work, session) }
          .to raise_error(Capybara::ElementNotFound)
      end
    end
  end

  describe 'interval logging' do
    let(:now) { Time.now }

    before { allow(Time).to receive(:now).and_return(now) }

    context 'when a previous application is recorded' do
      it 'reports the gap and how far past the cooldown it landed' do
        allow(FileBase).to receive(:last_work).with('test_user').and_return((now.to_i - 3712).to_s)

        described_class.send(:log_interval, user)

        expect(logged_lines).to include('applied user=test_login interval=3712s over_cooldown=112s')
      end

      it 'reports a negative over_cooldown when applied too early' do
        allow(FileBase).to receive(:last_work).with('test_user').and_return((now.to_i - 3400).to_s)

        described_class.send(:log_interval, user)

        expect(logged_lines).to include('applied user=test_login interval=3400s over_cooldown=-200s')
      end

      it 'reports a large gap when hourly runs were skipped' do
        allow(FileBase).to receive(:last_work).with('test_user').and_return((now.to_i - 7300).to_s)

        described_class.send(:log_interval, user)

        expect(logged_lines).to include('applied user=test_login interval=7300s over_cooldown=3700s')
      end
    end

    context 'when nothing was ever recorded' do
      it 'does not blow up on nil' do
        allow(FileBase).to receive(:last_work).with('test_user').and_return(nil)

        expect { described_class.send(:log_interval, user) }.not_to raise_error
        expect(logged_lines).to include('applied user=test_login interval=none')
      end
    end
  end
end
