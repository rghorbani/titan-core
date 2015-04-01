module Titan
  module Server
    class GremlinRelationship < Titan::Relationship
      include Titan::Server::Resource
      include Titan::Core::GremlinTranslator
      include Titan::Core::ActiveEntity

      def initialize(session, value)
        @session = session
        @response_hash = value
        @rel_type = @response_hash[:type]
        @props = @response_hash[:data]
        @start_node_titan_id = titan_id_integer(@response_hash[:start])
        @end_node_titan_id = titan_id_integer(@response_hash[:end])
        @id = @response_hash[:id]
      end

      def ==(other)
        other.class == self.class && other.titan_id == titan_id
      end
      alias_method :eql?, :==

      attr_reader :id

      def titan_id
        id
      end

      def inspect
        "GremlinRelationship #{titan_id}"
      end

      def load_resource
        return if resource_data_present?

        @resource_data = @session._query_or_fail("#{match_start} RETURN n", true, titan_id: titan_id) # r.first_data
      end

      attr_reader :start_node_titan_id

      attr_reader :end_node_titan_id

      def _start_node_id
        @start_node_titan_id ||= get_node_id(:start)
      end

      def _end_node_id
        @end_node_titan_id ||= get_node_id(:end)
      end

      def _start_node
        @_start_node ||= Titan::Node._load(start_node_titan_id)
      end

      def _end_node
        load_resource
        @_end_node ||= Titan::Node._load(end_node_titan_id)
      end

      def get_node_id(direction)
        load_resource
        resource_url_id(resource_url(direction))
      end

      def get_property(key)
        @session._query_or_fail("#{match_start} RETURN n.`#{key}`", true, titan_id: titan_id)
      end

      def set_property(key, value)
        @session._query_or_fail("#{match_start} SET n.`#{key}` = {value}", false,  value: value, titan_id: titan_id)
      end

      def remove_property(key)
        @session._query_or_fail("#{match_start} REMOVE n.`#{key}`", false, titan_id: titan_id)
      end

      # (see Titan::Relationship#props)
      def props
        if @props
          @props
        else
          hash = @session._query_entity_data("#{match_start} RETURN n", nil, titan_id: titan_id)
          @props = Hash[hash[:data].map { |k, v| [k, v] }]
        end
      end

      # (see Titan::Relationship#props=)
      def props=(properties)
        @session._query_or_fail("#{match_start} SET n = { props }", false,  props: properties, titan_id: titan_id)
        properties
      end

      # (see Titan::Relationship#update_props)
      def update_props(properties)
        return if properties.empty?
        q = "#{match_start} SET " + properties.keys.map do |k|
          "n.`#{k}`= #{escape_value(properties[k])}"
        end.join(',')
        @session._query_or_fail(q, false, titan_id: titan_id)
        properties
      end

      def rel_type
        @rel_type.to_sym
      end

      def del
        @session._query("#{match_start} DELETE n", titan_id: titan_id)
      end
      alias_method :delete, :del
      alias_method :destroy, :del

      def exist?
        response = @session._query("#{match_start} RETURN n", titan_id: titan_id)
        # binding.pry
        (response.data.nil? || response.data.empty?) ? false : true
      end

      private

      def match_start(identifier = 'n')
        "MATCH (node)-[#{identifier}]-() WHERE ID(#{identifier}) = {titan_id}"
      end

      def resource_data_present?
        !resource_data.nil? && !resource_data.empty?
      end

      def titan_id_integer(id_or_url)
        id_or_url.is_a?(Integer) ? id_or_url : id_or_url.match(/\d+$/)[0].to_i
      end
    end
  end
end
