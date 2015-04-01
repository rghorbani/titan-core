module Titan
  module Server
    class GremlinNode < Titan::Node
      include Titan::Server::Resource
      include Titan::Core::GremlinTranslator
      include Titan::Core::ActiveEntity

      def initialize(session, value)
        @session = session

        @titan_id = if value.is_a?(Hash)
                    @props = value[:data]
                    @labels = value[:metadata][:labels].map!(&:to_sym) if value[:metadata]
                    value[:id]
                  else
                    value
                  end
      end

      attr_reader :titan_id

      def inspect
        "GremlinNode #{titan_id} (#{object_id})"
      end

      # TODO, needed by gremlin-gremlin
      def _java_node
        self
      end

      # (see Titan::Node#create_rel)
      def create_rel(type, other_node, props = nil)
        q = @session.query.match(:a, :b).where(a: {titan_id: titan_id}, b: {titan_id: other_node.titan_id})
            .create("(a)-[r:`#{type}`]->(b)").break.set(r: props).return(r: :titan_id)

        id = @session._query_or_fail(q, true)

        GremlinRelationship.new(@session, type: type, data: props, start: titan_id, end: other_node.titan_id, id: id)
      end

      # (see Titan::Node#props)
      def props
        if @props
          @props
        else
          hash = @session._query_entity_data(match_start_query.return(:n), nil)
          @props = Hash[hash[:data].to_a]
        end
      end

      def refresh
        @props = nil
      end

      # (see Titan::Node#remove_property)
      def remove_property(key)
        refresh
        @session._query_or_fail(match_start_query.remove(n: key), false)
      end

      # (see Titan::Node#set_property)
      def set_property(key, value)
        refresh
        @session._query_or_fail(match_start_query.set(n: {key => value}), false)
      end

      # (see Titan::Node#props=)
      def props=(properties)
        refresh
        @session._query_or_fail(match_start_query.set_props(n: properties), false)
        properties
      end

      def remove_properties(properties)
        return if properties.empty?

        refresh
        @session._query_or_fail(match_start_query.remove(n: properties), false, titan_id: titan_id)
      end

      # (see Titan::Node#update_props)
      def update_props(properties)
        refresh
        return if properties.empty?

        @session._query_or_fail(match_start_query.set(n: properties), false)

        properties
      end

      # (see Titan::Node#get_property)
      def get_property(key)
        @props ? @props[key.to_sym] : @session._query_or_fail(match_start_query.return(n: key), true)
      end

      # (see Titan::Node#labels)
      def labels
        @labels ||= @session._query_or_fail(match_start_query.return('labels(n) AS labels'), true).map(&:to_sym)
      end

      def _gremlin_label_list(labels_list)
        ':' + labels_list.map { |label| "`#{label}`" }.join(':')
      end

      def add_label(*new_labels)
        @session._query_or_fail(match_start_query.set(n: new_labels), false)
        new_labels.each { |label| labels << label }
      end

      def remove_label(*target_labels)
        @session._query_or_fail(match_start_query.remove(n: target_labels), false)
        target_labels.each { |label| labels.delete(label) } unless labels.nil?
      end

      def set_label(*label_names)
        q = match_start_query

        labels_to_add = label_names.map(&:to_sym).uniq
        labels_to_remove = labels - label_names

        common_labels = labels & labels_to_add
        labels_to_add -= common_labels
        labels_to_remove -= common_labels

        q = q.remove(n: labels_to_remove) unless labels_to_remove.empty?
        q = q.set(n: labels_to_add) unless labels_to_add.empty?

        @session._query_or_fail(q, false) unless (labels_to_add + labels_to_remove).empty?
      end

      # (see Titan::Node#del)
      def del
        query = match_start_query.optional_match('n-[r]-()').delete(:n, :r)
        @session._query_or_fail(query, false)
      end

      alias_method :delete, :del
      alias_method :destroy, :del

      # (see Titan::Node#exist?)
      def exist?
        !@session._query(match_start_query.return(n: :titan_id)).data.empty?
      end

      # (see Titan::Node#node)
      def node(match = {})
        ensure_single_relationship { match(GremlinNode, 'p as result LIMIT 2', match) }
      end

      # (see Titan::Node#rel)
      def rel(match = {})
        ensure_single_relationship { match(GremlinRelationship, 'r as result LIMIT 2', match) }
      end

      # (see Titan::Node#rel?)
      def rel?(match = {})
        result = match(GremlinRelationship, 'r as result', match)
        !!result.first
      end

      # (see Titan::Node#nodes)
      def nodes(match = {})
        match(GremlinNode, 'p as result', match)
      end

      # (see Titan::Node#rels)
      def rels(match = {dir: :both})
        match(GremlinRelationship, 'r as result', match)
      end

      # @private
      def match(clazz, returns, match = {})
        gremlin_rel = match[:type] ? "[r:`#{match[:type]}`]" : '[r]'
        query = self.query

        query = query.match(:p).where(p: {titan_id: match[:between].titan_id}) if match[:between]

        r = query.match("(n)#{relationship_arrow(gremlin_rel, match[:dir])}(p)").return(returns).response

        r.raise_error if r.error?

        r.to_node_enumeration.map(&:result)
      end

      def query(identifier = :n)
        @session.query.match(identifier).where(identifier => {titan_id: titan_id})
      end

      private

      def relationship_arrow(rel_spec, direction = nil)
        case direction || :both
        when :outgoing then "-#{rel_spec}->"
        when :incoming then "<-#{rel_spec}-"
        when :both then "-#{rel_spec}-"
        else
          fail "Invalid value for relationship_arrow direction: #{direction.inspect}"
        end
      end

      def ensure_single_relationship(&block)
        result = yield
        fail "Expected to only find one relationship from node #{titan_id} matching #{match.inspect} but found #{result.count}" if result.count > 1
        result.first
      end

      def match_start_query(identifier = :n)
        @session.query.match(identifier).where(identifier => {titan_id: titan_id}).with(identifier)
      end
    end
  end
end
