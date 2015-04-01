require 'spec_helper'

describe Titan::Label do
  describe 'instance methods' do
    let(:session) do
      double(:session)
    end

    let(:label) do
      label = Titan::Label.new
      allow(label).to receive(:name) { :person }
      label
    end

    describe 'create_constraint' do
      it 'generates a gremlin query' do
        expect(session).to receive(:_query_or_fail).with('CREATE CONSTRAINT ON (n:`person`) ASSERT n.`name` IS UNIQUE')
        label.create_constraint(:name, {type: :unique}, session)
      end

      it 'raise an exception if invalid constraint' do
        expect { label.create_constraint(:name, type: :unknown) }.to raise_error
      end
    end

    describe '#drop_constraint' do
      it 'generates a gremlin query' do
        expect(session).to receive(:_query_or_fail).with('DROP CONSTRAINT ON (n:`person`) ASSERT n.`name` IS UNIQUE')
        label.drop_constraint(:name, {type: :unique}, session)
      end

      it 'raise an exception if invalid constraint' do
        expect { label.drop_constraint(:name, type: :unknown) }.to raise_error
      end
    end
  end
end
