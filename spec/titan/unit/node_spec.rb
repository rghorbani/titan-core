require 'spec_helper'

describe Titan::Node do
  describe 'new' do
    it 'throws an exception' do
      expect { Titan::Node.new }.to raise_error
    end
  end
end
