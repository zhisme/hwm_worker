require 'spec_helper'
require 'hwm_worker/hunt'

RSpec.describe Hunt do
  describe '.result' do
    it 'reads a qualifying win' do
      summary = described_class.result('Победа! Получено умений: 0.62')

      expect(summary).to eq(outcome: 'win', skill: 0.62, qualifies: true, credits: 12)
    end

    it 'marks a win below the clearing threshold as non-qualifying' do
      summary = described_class.result('Победа. Ваша награда: +0.3 умения')

      expect(summary[:outcome]).to eq('win')
      expect(summary[:skill]).to eq(0.3)
      expect(summary[:qualifies]).to be(false)
      expect(summary[:credits]).to eq(6)
    end

    it 'reads a loss' do
      summary = described_class.result('Поражение. Умения: 0.12')

      expect(summary[:outcome]).to eq('loss')
      expect(summary[:qualifies]).to be(false)
    end

    it 'reads the English wording' do
      summary = described_class.result('Victory. Faction skill: 0.55')

      expect(summary).to eq(outcome: 'win', skill: 0.55, qualifies: true, credits: 11)
    end

    it 'reads a decimal comma' do
      summary = described_class.result('Победа, умения 0,45')

      expect(summary[:skill]).to eq(0.45)
      expect(summary[:qualifies]).to be(false)
      expect(summary[:credits]).to eq(9)
    end

    it 'reports unknown when the page carries no battle report' do
      summary = described_class.result('Location: Rogues Wood')

      expect(summary).to eq(outcome: 'unknown', skill: nil, qualifies: false, credits: nil)
    end
  end
end
