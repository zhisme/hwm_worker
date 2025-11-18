require 'spec_helper'
require 'models/user'
require 'yaml'

RSpec.describe User do
  let(:test_credentials_file) { '.hwm_credentials.yml' }
  let(:test_users_data) do
    {
      'users' => [
        { 'id' => 1, 'login' => 'hero1', 'password' => 'pass1' },
        { 'id' => 2, 'login' => 'hero2', 'password' => 'pass2' },
        { 'id' => 3, 'login' => 'hero3', 'password' => 'pass3' }
      ]
    }
  end

  before do
    # Mock YAML loading to avoid dependency on actual file
    allow(YAML).to receive(:load_file).with(test_credentials_file).and_return(test_users_data)

    # Reset class variable to ensure clean state
    described_class.instance_variable_set(:@users, nil)

    # Trigger loading of users
    described_class.class_eval { @users = YAML.load_file('.hwm_credentials.yml')['users'] }
  end

  describe 'class attribute' do
    it 'loads users from YAML file' do
      expect(described_class.users).to eq(test_users_data['users'])
    end

    it 'has accessible users attribute' do
      expect(described_class).to respond_to(:users)
    end
  end

  describe '.first' do
    it 'returns User instance' do
      result = described_class.first
      expect(result).to be_a(User)
    end

    it 'returns first user from the list' do
      user = described_class.first
      expect(user.id).to eq(1)
      expect(user.login).to eq('hero1')
      expect(user.password).to eq('pass1')
    end
  end

  describe '.all' do
    it 'returns array of User instances' do
      users = described_class.all
      expect(users).to be_an(Array)
      expect(users.size).to eq(3)
      expect(users).to all(be_a(User))
    end

    it 'returns all users from YAML' do
      users = described_class.all

      expect(users[0].login).to eq('hero1')
      expect(users[1].login).to eq('hero2')
      expect(users[2].login).to eq('hero3')
    end

    it 'preserves user data' do
      users = described_class.all

      expect(users.map(&:id)).to eq([1, 2, 3])
      expect(users.map(&:login)).to eq(['hero1', 'hero2', 'hero3'])
      expect(users.map(&:password)).to eq(['pass1', 'pass2', 'pass3'])
    end
  end

  describe '.find' do
    context 'when user exists' do
      it 'returns User instance' do
        user = described_class.find(login: 'hero2')
        expect(user).to be_a(User)
      end

      it 'finds user by login' do
        user = described_class.find(login: 'hero2')
        expect(user.id).to eq(2)
        expect(user.login).to eq('hero2')
        expect(user.password).to eq('pass2')
      end

      it 'finds first matching user when login is unique' do
        user = described_class.find(login: 'hero1')
        expect(user.login).to eq('hero1')
      end
    end

    context 'when user does not exist' do
      it 'returns User instance with nil record' do
        user = described_class.find(login: 'nonexistent')
        expect(user).to be_a(User)
      end

      it 'raises NoMethodError when accessing attributes on nil record' do
        user = described_class.find(login: 'nonexistent')
        expect { user.id }.to raise_error(NoMethodError)
        expect { user.login }.to raise_error(NoMethodError)
        expect { user.password }.to raise_error(NoMethodError)
      end
    end
  end

  describe '#initialize' do
    let(:user_record) { { 'id' => 42, 'login' => 'test_hero', 'password' => 'test_pass' } }

    it 'accepts a record hash' do
      user = described_class.new(user_record)
      expect(user).to be_a(User)
    end

    it 'stores the record' do
      user = described_class.new(user_record)
      expect(user.instance_variable_get(:@record)).to eq(user_record)
    end
  end

  describe '#id' do
    let(:user_record) { { 'id' => 99, 'login' => 'hero', 'password' => 'pass' } }

    it 'returns id from record' do
      user = described_class.new(user_record)
      expect(user.id).to eq(99)
    end

    it 'returns nil when record has no id' do
      user = described_class.new({})
      expect(user.id).to be_nil
    end
  end

  describe '#login' do
    let(:user_record) { { 'id' => 1, 'login' => 'mylogin', 'password' => 'pass' } }

    it 'returns login from record' do
      user = described_class.new(user_record)
      expect(user.login).to eq('mylogin')
    end

    it 'returns nil when record has no login' do
      user = described_class.new({})
      expect(user.login).to be_nil
    end
  end

  describe '#password' do
    let(:user_record) { { 'id' => 1, 'login' => 'hero', 'password' => 'secret123' } }

    it 'returns password from record' do
      user = described_class.new(user_record)
      expect(user.password).to eq('secret123')
    end

    it 'returns nil when record has no password' do
      user = described_class.new({})
      expect(user.password).to be_nil
    end
  end

  describe 'integration tests' do
    it 'can create multiple user instances without conflict' do
      user1 = described_class.first
      user2 = described_class.find(login: 'hero2')
      users = described_class.all

      expect(user1.login).to eq('hero1')
      expect(user2.login).to eq('hero2')
      expect(users.size).to eq(3)
    end

    it 'each user instance is independent' do
      user1 = described_class.first
      user2 = described_class.first

      expect(user1).not_to equal(user2) # Different object instances
      expect(user1.login).to eq(user2.login) # But same data
    end
  end

  describe 'YAML file loading' do
    it 'loads from .hwm_credentials.yml' do
      expect(YAML).to receive(:load_file).with('.hwm_credentials.yml').and_return(test_users_data)
      described_class.class_eval { @users = YAML.load_file('.hwm_credentials.yml')['users'] }
    end

    it 'extracts users array from YAML' do
      expect(described_class.users).to be_an(Array)
      expect(described_class.users.first).to be_a(Hash)
    end
  end
end
