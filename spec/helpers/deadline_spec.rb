require 'spec_helper'
require 'helpers/deadline'

RSpec.describe Deadline do
  before { described_class.reset! }

  after { described_class.reset! }

  def stub_budget(seconds)
    stub_const('Deadline::BUDGET', seconds)
  end

  def stub_elapsed(seconds)
    start = 1000.0
    allow(described_class).to receive(:monotonic).and_return(start, start + seconds)
  end

  describe '.unlimited?' do
    it 'is true when budget is zero' do
      stub_budget(0)
      expect(described_class).to be_unlimited
    end

    it 'is false when budget is set' do
      stub_budget(600)
      expect(described_class).not_to be_unlimited
    end
  end

  describe '.left' do
    it 'is infinite when unlimited' do
      stub_budget(0)
      expect(described_class.left).to eq(Float::INFINITY)
    end

    it 'subtracts elapsed time and RESERVE from the budget' do
      stub_budget(600)
      stub_elapsed(100)
      described_class.start!

      expect(described_class.left).to eq(600 - Deadline::RESERVE - 100)
    end

    it 'starts the clock lazily when start! was never called' do
      stub_budget(600)
      allow(described_class).to receive(:monotonic).and_return(1000.0)

      expect(described_class.left).to eq(600 - Deadline::RESERVE)
    end

    it 'goes negative once the budget is blown' do
      stub_budget(100)
      stub_elapsed(500)
      described_class.start!

      expect(described_class.left).to eq(100 - Deadline::RESERVE - 500)
    end
  end

  describe '.elapsed' do
    it 'reports whole seconds since the clock started' do
      stub_elapsed(42.4)
      described_class.start!

      expect(described_class.elapsed).to eq(42)
    end

    it 'works without a configured budget' do
      stub_budget(0)
      stub_elapsed(7.6)
      described_class.start!

      expect(described_class.elapsed).to eq(8)
    end

    it 'is 0 when the clock was never started' do
      allow(described_class).to receive(:monotonic).and_return(1000.0)

      expect(described_class.elapsed).to eq(0)
    end
  end

  describe '.left_for_log' do
    it 'renders remaining seconds with a unit' do
      stub_budget(600)
      stub_elapsed(100)
      described_class.start!

      expect(described_class.left_for_log).to eq("#{600 - Deadline::RESERVE - 100}s")
    end

    it 'renders negative budget rather than clamping' do
      stub_budget(60)
      stub_elapsed(200)
      described_class.start!

      expect(described_class.left_for_log).to eq("#{60 - Deadline::RESERVE - 200}s")
    end

    it 'renders unlimited instead of Infinity' do
      stub_budget(0)

      expect(described_class.left_for_log).to eq('unlimited')
    end
  end

  describe '.exceeded?' do
    it 'is false while budget remains' do
      stub_budget(600)
      stub_elapsed(10)
      described_class.start!

      expect(described_class).not_to be_exceeded
    end

    it 'is true once only RESERVE is left' do
      stub_budget(600)
      stub_elapsed(600 - Deadline::RESERVE)
      described_class.start!

      expect(described_class).to be_exceeded
    end

    it 'is true past the budget' do
      stub_budget(60)
      stub_elapsed(120)
      described_class.start!

      expect(described_class).to be_exceeded
    end

    it 'is never true when unlimited' do
      stub_budget(0)
      expect(described_class).not_to be_exceeded
    end
  end
end
