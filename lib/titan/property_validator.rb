module Titan
  module PropertyValidator
    require 'set'
    class InvalidPropertyException < Exception
    end

    # the valid values on a property, and arrays of those.
    VALID_PROPERTY_VALUE_CLASSES = Set.new([Array, NilClass, String, Float, TrueClass, FalseClass, Fixnum])

    # @param [Object] value the value we want to check if it's a valid titan property value
    # @return [True, False] A false means it can't be persisted.
    def valid_property?(value)
      VALID_PROPERTY_VALUE_CLASSES.include?(value.class)
    end

    def validate_property!(value)
      return if valid_property?(value)

      fail Titan::PropertyValidator::InvalidPropertyException, "Not valid Titan Property value #{value.class}, valid: #{Titan::Node::VALID_PROPERTY_VALUE_CLASSES.to_a.join(', ')}"
    end
  end
end
