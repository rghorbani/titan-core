module Titan
  module Core
    # A module to make Titan::Node and Titan::Relationship work better together with titan.rb's Titan::ActiveNode and Titan::ActiveRelationship
    module ActiveEntity
      # @return true
      def persisted?
        true
      end
    end
  end
end
