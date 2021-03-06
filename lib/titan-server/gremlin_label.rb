module Titan
  module Server
    class GremlinLabel < Titan::Label
      extend Forwardable
      def_delegator :@session, :query_gremlin_for
      attr_reader :name

      def initialize(session, name)
        @name = name
        @session = session
      end

      def create_index(*properties)
        response = @session._query("CREATE INDEX ON :`#{@name}`(#{properties.join(',')})")
        response.raise_error if response.error?
      end

      def drop_index(*properties)
        properties.each do |property|
          response = @session._query("DROP INDEX ON :`#{@name}`(#{property})")
          response.raise_error if response.error? && !response.error_msg.match(/No such INDEX ON/)
        end
      end

      def indexes
        @session.indexes(@name)
      end

      def uniqueness_constraints
        @session.uniqueness_constraints(@name)
      end
    end
  end
end
