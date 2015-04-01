require 'spec_helper'

describe Titan::Session do
  before(:all) do
    @before_session = Titan::Session.current
    Titan::Session.register_db(:dummy1_db) { 'dummy1_db' }
    Titan::Session.register_db(:dummy2_db) { 'dummy2_db' }
  end

  after(:all) do
    # restore the session
    Titan::Session.set_current(@before_session)
  end


  describe '.open' do
    it 'returns the session created' do
      s1 = Titan::Session.open(:dummy1_db)
      expect(s1).to eq('dummy1_db')

      s2 = Titan::Session.open(:dummy2_db)
      expect(s2).to eq('dummy2_db')
    end
  end

  describe '.set_current' do
    it 'sets the current session' do
      s1 = Titan::Session.open(:dummy1_db)
      Titan::Session.open(:dummy2_db)

      Titan::Session.set_current(s1)
      expect(Titan::Session.current).to eq('dummy1_db')
    end
  end
end
