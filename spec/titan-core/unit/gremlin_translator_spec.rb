require 'spec_helper'

describe Titan::Core::GremlinTranslator do
  let(:klass) { Class.new.extend Titan::Core::GremlinTranslator }

  context '#escape_value' do
    context 'with symbol' do
      it 'stringifies symbol' do
        expect(klass.escape_value(:"matt's")).to eq('\'matt\\\'s\'')
      end
    end
  end

  context '#sanitize_escape_sequences' do
    context 'with valid strings' do
      [
        'a\\\\p',
        'a\b',
        'a\tb',
        'a\bb',
        'a\nb',
        'a\rb',
        'a\fb',
        'a\'b',
        'a\"b',
        "a\b",
        '\u00b5',
        "\u00b5",
        'test\\usomething',
        "D'Amore-Schamberger"
      ].each do |s|
        it "does not change #{s}" do
          expect(klass.sanitize_escape_sequences(s)).to eq(s)
        end
      end
    end

    context 'with invalid strings' do
      {
        'a\pb'    => 'apb',
        '2\56'    => '256'
      }.each do |before, after|
        it "replaces #{before} with #{after}" do
          expect(klass.sanitize_escape_sequences(before)).to eq(after)
        end
      end
    end
  end

  context '#gremlin_prop_list' do
    it 'drops nil properties' do
      items = klass.gremlin_prop_list!(one: 1, two: 2, three: nil)
      expect(items).to eq(props: {one: 1, two: 2})
    end
  end
end
