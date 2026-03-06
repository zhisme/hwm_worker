require 'spec_helper'
require 'hwm_worker/inventory_check'

RSpec.describe InventoryCheck do
  let(:session) { instance_double(Capybara::Session) }
  let(:user) { instance_double(User, login: 'hero1') }
  let(:durability_el) { double('durability_element') }

  before do
    allow(session).to receive(:visit)
    allow(session).to receive(:find).with('#slot11 .art_durability_hidden', visible: :all).and_return(durability_el)
  end

  describe '.call' do
    context 'when durability is high' do
      before { allow(durability_el).to receive(:text).with(:all).and_return('12/40') }

      it 'does not raise an error' do
        expect { described_class.call(session: session, user: user) }.not_to raise_error
      end
    end

    context 'when durability is 2' do
      before { allow(durability_el).to receive(:text).with(:all).and_return('2/40') }

      it 'does not raise an error' do
        expect { described_class.call(session: session, user: user) }.not_to raise_error
      end
    end

    context 'when durability is 1' do
      before { allow(durability_el).to receive(:text).with(:all).and_return('1/40') }

      it 'raises MirrorLowDurability' do
        expect { described_class.call(session: session, user: user) }.to raise_error(
          InventoryCheck::MirrorLowDurability,
          'Mirror durability is 1/40 for hero1. Sell it now!'
        )
      end
    end

    context 'when durability is 0' do
      before { allow(durability_el).to receive(:text).with(:all).and_return('0/40') }

      it 'raises MirrorLowDurability' do
        expect { described_class.call(session: session, user: user) }.to raise_error(
          InventoryCheck::MirrorLowDurability,
          'Mirror durability is 0/40 for hero1. Sell it now!'
        )
      end
    end

    context 'when element is not found' do
      before do
        allow(session).to receive(:find)
          .with('#slot11 .art_durability_hidden', visible: :all)
          .and_raise(Capybara::ElementNotFound)
      end

      it 'lets Capybara::ElementNotFound bubble up' do
        expect { described_class.call(session: session, user: user) }.to raise_error(Capybara::ElementNotFound)
      end
    end
  end
end
