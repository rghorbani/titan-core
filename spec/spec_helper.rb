# To run coverage via travis
require 'coveralls'
Coveralls.wear!
# require 'simplecov'
# SimpleCov.start

# To run it manually via Rake
if ENV['COVERAGE']
  puts 'RUN SIMPLECOV'
  require 'simplecov'
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
  SimpleCov.start
end

require 'rubygems'
require 'bundler/setup'
require 'rspec'
require 'fileutils'
require 'tmpdir'
require 'logger'
require 'rspec/its'
require 'titan-core'
require 'ostruct'

if RUBY_PLATFORM == 'java'
  require 'titan-embedded/embedded_impermanent_session'
  require 'ruby-debug'

  # for some reason this is not impl. in JRuby
  class OpenStruct
    def [](key)
      send(key)
    end
  end
end

Dir["#{File.dirname(__FILE__)}/shared_examples/**/*.rb"].each { |f| require f }

EMBEDDED_DB_PATH = File.join(Dir.tmpdir, 'titan-core-java')

require "#{File.dirname(__FILE__)}/helpers"

RSpec.configure do |c|
  c.include Helpers
end


FileUtils.rm_rf(EMBEDDED_DB_PATH)

RSpec.configure do |c|
  c.before(:all, api: :server) do
    Titan::Session.current.close if Titan::Session.current
    create_server_session
  end

  c.before(:all, api: :embedded) do
    Titan::Session.current.close if Titan::Session.current
    create_embedded_session
    Titan::Session.current.start unless Titan::Session.current.running?
  end

  # if ENV['TEST_AUTHENTICATION'] == 'true'
  #   uri = URI.parse("http://localhost:7474/user/titan/password")
  #   db_default = 'titan'
  #   suite_default = 'titanrb rules, ok?'

  #   c.before(:suite, api: :server) do
  #     Net::HTTP.post_form(uri, { 'password' => db_default, 'new_password' => suite_default })
  #   end

  #   c.after(:suite, api: :server) do
  #     Net::HTTP.post_form(uri, { 'password' => suite_default, 'new_password' => db_default })
  #   end
  # end

  c.before(:each, api: :embedded) do
    curr_session = Titan::Session.current
    curr_session.close if curr_session && !curr_session.is_a?(Titan::Embedded::EmbeddedSession)
    Titan::Session.current || create_embedded_session
    Titan::Session.current.start unless Titan::Session.current.running?
  end

  c.before(:each, api: :server) do
    curr_session = Titan::Session.current
    curr_session.close if curr_session && !curr_session.is_a?(Titan::Server::GremlinSession)
    Titan::Session.current || create_server_session
  end

  c.exclusion_filter = {
    api: lambda do |ed|
      RUBY_PLATFORM != 'java' && ed == :embedded
    end,

    server_only: lambda do |bool|
      RUBY_PLATFORM == 'java' && bool
    end
  }
end
