require 'ostruct'
require 'forwardable'
require 'fileutils'

require 'titan-core/version'
require 'titan/property_validator'
require 'titan/property_container'
require 'titan-core/active_entity'
require 'titan-core/helpers'
require 'titan-core/gremlin_translator'
require 'titan-core/query_find_in_batches'
require 'titan-core/query'

require 'titan/entity_equality'
require 'titan/node'
require 'titan/label'
require 'titan/session'

require 'titan/relationship'
require 'titan/transaction'

require 'titan-server'

if RUBY_PLATFORM == 'java'
  require 'titan-embedded'
else
  # just for the tests
  module Titan
    module Embedded
    end
  end
end
