require 'spec_helper'

describe Titan::Session do
  let(:session) { Titan::Session.new }
  let(:error) { 'not impl.' }
  it 'raises errors for methods not implemented' do
    [-> { session.start }, -> { session.shutdown }, -> { session.db_type }, -> { session.begin_tx }].each do |l|
      expect { l.call }.to raise_error error
    end

    expect { session.query }.to raise_error 'not implemented, abstract'
    expect { session._query }.to raise_error 'not implemented'
    expect { Titan::Session.open(:foo) }.to raise_error Titan::Session::InitializationError
  end
end
