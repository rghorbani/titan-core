module Titan
  module Server
    class GremlinNodeUncommited
      def initialize(db, data)
        @db = db
        @data = data
      end

      def [](key)
        @data[key]
      end
    end
  end
end
