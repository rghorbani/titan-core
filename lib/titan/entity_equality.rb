module Titan
  module EntityEquality
    def ==(other)
      other.class == self.class && other.titan_id == titan_id
    end
    alias_method :eql?, :==
  end
end
