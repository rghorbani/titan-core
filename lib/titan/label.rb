module Titan
  # A label is a named graph construct that is used to group nodes.
  # See Titan::Node how to create and delete nodes
  # @see http://s3.thinkaurelius.com/docs/titan/current/schema.html
  class Label
    class InvalidQueryError < StandardError; end

    # @abstract
    def name
      fail 'not implemented'
    end

    # @abstract
    def create_index(*properties)
      fail 'not implemented'
    end

    # @abstract
    def drop_index(*properties)
      fail 'not implemented'
    end

    # List indices for a label
    # @abstract
    def indexes
      fail 'not implemented'
    end

    # Creates a titan constraint on a property
    # See http://s3.thinkaurelius.com/docs/titan/current/indexes.html#_label_constraint
    # @example
    #   label = Titan::Label.create(:person, session)
    #   label.create_constraint(:name, {type: :unique}, session)
    #
    def create_constraint(property, constraints, session = Titan::Session.current)
      gremlin = case constraints[:type]
               when :unique
                 "CREATE CONSTRAINT ON (n:`#{name}`) ASSERT n.`#{property}` IS UNIQUE"
               else
                 fail "Not supported constrain #{constraints.inspect} for property #{property} (expected :type => :unique)"
               end
      session._query_or_fail(gremlin)
    end

    # Drops a titan constraint on a property
    # See http://s3.thinkaurelius.com/docs/titan/current/indexes.html#_label_constraint
    # @example
    #   label = Titan::Label.create(:person, session)
    #   label.create_constraint(:name, {type: :unique}, session)
    #   label.drop_constraint(:name, {type: :unique}, session)
    #
    def drop_constraint(property, constraint, session = Titan::Session.current)
      gremlin = case constraint[:type]
               when :unique
                 "DROP CONSTRAINT ON (n:`#{name}`) ASSERT n.`#{property}` IS UNIQUE"
               else
                 fail "Not supported constrain #{constraint.inspect}"
               end
      session._query_or_fail(gremlin)
    end

    class << self
      include Titan::Core::GremlinTranslator
      INDEX_PATH = '/db/data/schema/index/'
      CONSTRAINT_PATH = '/db/data/schema/constraint/'

      # Returns a label of given name that can be used to specifying constraints
      # @param [Symbol,String] name the name of the label
      def create(name, session = Titan::Session.current)
        session.create_label(name)
      end

      # @return [Enumerable<Titan::Node>] all nodes having given label. Nodes can be wrapped in your own model ruby classes.
      def find_all_nodes(label_name, session = Titan::Session.current)
        session.find_all_nodes(label_name)
      end

      # @return [Enumerable<Titan::Node>] all nodes having given label and properties. Nodes can be wrapped in your own model ruby classes.
      def find_nodes(label_name, key, value, session = Titan::Session.current)
        session.find_nodes(label_name, key, value)
      end
    end
  end
end
