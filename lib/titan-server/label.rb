module Titan
  class Label
    class << self
      def constraints(session = Titan::Session.current)
        session.connection.get(CONSTRAINT_PATH).body
      end

      def constraint?(label_name, property, session = Titan::Session.current)
        label_constraints = session.connection.get("#{CONSTRAINT_PATH}/#{label_name}").body
        !label_constraints.select { |c| c[:label] == label_name.to_s && c[:property_keys].first == property.to_s }.empty?
      end

      def indexes(session = Titan::Session.current)
        session.connection.get(INDEX_PATH).body
      end

      def index?(label_name, property, session = Titan::Session.current)
        label_indexes = session.connection.get("#{INDEX_PATH}/#{label_name}").body
        !label_indexes.select { |i| i[:label] == label_name.to_s && i[:property_keys].first == property.to_s }.empty?
      end

      def drop_all_indexes(session = Titan::Session.current)
        indexes.each do |i|
          begin
            session._query_or_fail("DROP INDEX ON :`#{i[:label]}`(#{i[:property_keys].first})")
          rescue Titan::Server::GremlinResponse::ResponseError
            # This will error on each constraint. Ignore and continue.
            next
          end
        end
      end

      def drop_all_constraints(session = Titan::Session.current)
        constraints.each do |c|
          session._query_or_fail("DROP CONSTRAINT ON (n:`#{c[:label]}`) ASSERT n.`#{c[:property_keys].first}` IS UNIQUE")
        end
      end
    end
  end
end
