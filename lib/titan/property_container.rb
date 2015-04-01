module Titan
  module PropertyContainer
    include Titan::PropertyValidator

    # Returns the Titan Property of given key
    def [](key)
      get_property(key)
    end

    # Sets the titan property
    def []=(key, value)
      validate_property!(value)

      set_property(key, value)
    end
  end
end
