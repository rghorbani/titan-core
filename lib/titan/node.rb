module Titan
  # The base class for both the Embedded and Server Titan Node
  # Notice this class is abstract and can't be instantiated
  class Node
    # A module that allows plugins to register wrappers around Titan::Node objects
    module Wrapper
      # Used by Titan::NodeMixin to wrap nodes
      def wrapper
        self
      end

      def titan_obj
        self
      end
    end

    include EntityEquality
    include Wrapper
    include PropertyContainer

    # @return [Hash<Symbol, Object>] all properties of the node
    def props
      fail 'not implemented'
    end

    # replace all properties with new properties
    # @param [Hash<Symbol, Object>] properties a hash of properties the node should have
    def props=(properties)
      fail 'not implemented'
    end

    # Refresh the properties by reading it from the database again next time an property value is requested.
    def refresh
      fail 'not implemented'
    end

    # Updates the properties, keeps old properties
    # @param [Hash<Symbol, Object>] properties hash of properties that should be updated on the node
    def update_props(properties)
      fail 'not implemented'
    end

    # Directly remove the property on the node (low level method, may need transaction)
    def remove_property(key)
      fail 'not implemented'
    end

    # Directly set the property on the node (low level method, may need transaction)
    # @param [Symbol, String] key
    # @param value see Titan::PropertyValidator::VALID_PROPERTY_VALUE_CLASSES for valid values
    def set_property(key, value)
      fail 'not implemented'
    end

    # Directly get the property on the node (low level method, may need transaction)
    # @param [Symbol, String] key
    # @return the value of the key
    def get_property(key, value)
      fail 'not implemented'
    end

    # Creates a relationship of given type to other_node with optionally properties
    # @param [Symbol] type the type of the relation between the two nodes
    # @param [Titan::Node] other_node the other node
    # @param [Hash<Symbol, Object>] props optionally properties for the created relationship
    def create_rel(type, other_node, props = nil)
      fail 'not implemented'
    end


    # Returns an enumeration of relationships.
    # It always returns relationships of depth one.
    #
    # @param [Hash] match the options to create a message with.
    # @option match [Symbol] :dir dir the direction of the relationship, allowed values: :both, :incoming, :outgoing.
    # @option match [Symbol] :type the type of relationship to navigate
    # @option match [Symbol] :between return all the relationships between this and given node
    # @return [Enumerable<Titan::Relationship>] of Titan::Relationship objects
    #
    # @example Return both incoming and outgoing relationships of any type
    #   node_a.rels
    #
    # @example All outgoing or incoming relationship of type friends
    #   node_a.rels(type: :friends)
    #
    # @example All outgoing relationships between me and another node of type friends
    #   node_a.rels(type: :friends, dir: :outgoing, between: node_b)
    #
    def rels(match = {dir: :both})
      fail 'not implemented'
    end

    # Adds one or more Titan labels on the node
    # @param [Array<Symbol>] labels one or more labels to add
    def add_label(*labels)
      fail 'not implemented'
    end

    # Sets label on the node. Any old labels will be removed
    # @param [Array<Symbol>] labels one or more labels to set
    def set_label(*labels)
      fail 'not implemented'
    end

    # Removes given labels
    def remove_label(*labels)
      fail 'not implemented'
    end

    #
    # @return [Array<Symbol>]all labels on the node
    def labels
      fail 'not implemented'
    end

    # Deletes this node from the database
    def del
      fail 'not implemented'
    end

    # @return [Boolean] true if the node exists in the database
    def exist?
      fail 'not implemented'
    end

    # Returns the only node of a given type and direction that is attached to this node, or nil.
    # This is a convenience method that is used in the commonly occuring situation where a node has exactly zero or one relationships of a given type and direction to another node.
    # Typically this invariant is maintained by the rest of the code: if at any time more than one such relationships exist, it is a fatal error that should generate an exception.
    #
    # This method reflects that semantics and returns either:
    # * nil if there are zero relationships of the given type and direction,
    # * the relationship if there's exactly one, or
    # * throws an exception in all other cases.
    #
    # This method should be used only in situations with an invariant as described above. In those situations, a "state-checking" method (e.g. #rel?) is not required,
    # because this method behaves correctly "out of the box."
    #
    # @param (see #rel)
    def node(specs = {})
      fail 'not implemented'
    end

    # Same as #node but returns the relationship. Notice it may raise an exception if there are more then one relationship matching.
    def rel(spec = {})
      fail 'not implemented'
    end

    def _rel(spec = {})
      fail 'not implemented'
    end

    # Returns true or false if there is one or more relationships
    # @return [Boolean]
    def rel?(spec = {})
      fail 'not implemented'
    end

    # Works like #rels method but instead returns the nodes.
    # It does try to load a Ruby wrapper around each node
    # @abstract
    # @param (see #rels)
    # @return [Enumerable<Titan::Node>] an Enumeration of either Titan::Node objects or wrapped Titan::Node objects
    # @note it's possible that the same node is returned more than once because of several relationship reaching to the same node, see #outgoing for alternative
    def nodes(specs = {})
      # rels(specs).map{|n| n.other_node(self)}
    end

    class << self
      # Creates a node
      def create(props = nil, *labels_or_db)
        session = Titan::Core::ArgumentHelper.session(labels_or_db)
        session.create_node(props, labels_or_db)
      end

      # Loads a node from the database with given id
      def load(titan_id, session = Titan::Session.current!)
        node = _load(titan_id, session)
        node && node.wrapper
      end

      # Same as #load but does not try to return a wrapped node
      # @return [Titan::Node] an unwrapped node
      def _load(titan_id, session = Titan::Session.current!)
        session.load_node(titan_id)
      end

      # Find the node with given label and value
      def find_nodes(label, value = nil, session = Titan::Session.current!)
        session.find_nodes(label, value)
      end
    end

    def initialize
      fail "Can't instantiate abstract class" if abstract_class?
    end

    private

    def abstract_class?
      self.class == Node
    end
  end
end
