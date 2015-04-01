require 'titan-core/query_clauses'
require 'active_support/notifications'

module Titan
  module Core
    # Allows for generation of gremlin queries via ruby method calls (inspired by ActiveRecord / arel syntax)
    #
    # Can be used to express gremlin queries in ruby nicely, or to more easily generate queries programatically.
    #
    # Also, queries can be passed around an application to progressively build a query across different concerns
    #
    # See also the following link for full gremlin language documentation:
    # http://gremlin.tinkerpop.com
    class Query
      include Titan::Core::QueryClauses
      include Titan::Core::QueryFindInBatches
      DEFINED_CLAUSES = {}

      def initialize(options = {})
        @session = options[:session] || Titan::Session.current

        @options = options
        @clauses = []
        @_params = {}
      end

      # @method start *args
      # START clause
      # @return [Query]

      # @method match *args
      # MATCH clause
      # @return [Query]

      # @method optional_match *args
      # OPTIONAL MATCH clause
      # @return [Query]

      # @method using *args
      # USING clause
      # @return [Query]

      # @method where *args
      # WHERE clause
      # @return [Query]

      # @method with *args
      # WITH clause
      # @return [Query]

      # @method order *args
      # ORDER BY clause
      # @return [Query]

      # @method limit *args
      # LIMIT clause
      # @return [Query]

      # @method skip *args
      # SKIP clause
      # @return [Query]

      # @method set *args
      # SET clause
      # @return [Query]

      # @method remove *args
      # REMOVE clause
      # @return [Query]

      # @method unwind *args
      # UNWIND clause
      # @return [Query]

      # @method return *args
      # RETURN clause
      # @return [Query]

      # @method create *args
      # CREATE clause
      # @return [Query]

      # @method create_unique *args
      # CREATE UNIQUE clause
      # @return [Query]

      # @method merge *args
      # MERGE clause
      # @return [Query]

      # @method on_create_set *args
      # ON CREATE SET clause
      # @return [Query]

      # @method on_match_set *args
      # ON MATCH SET clause
      # @return [Query]

      # @method delete *args
      # DELETE clause
      # @return [Query]

      METHODS = %w(with start match optional_match using where set create create_unique merge on_create_set on_match_set remove unwind delete return order skip limit)

      CLAUSIFY_CLAUSE = proc do |method|
        const_get(method.to_s.split('_').map(&:capitalize).join + 'Clause')
      end

      CLAUSES = METHODS.map(&CLAUSIFY_CLAUSE)

      METHODS.each_with_index do |clause, i|
        clause_class = CLAUSES[i]

        DEFINED_CLAUSES[clause.to_sym] = clause_class
        define_method(clause) do |*args|
          build_deeper_query(clause_class, args)
        end
      end

      alias_method :offset, :skip
      alias_method :order_by, :order

      # Clears out previous order clauses and allows only for those specified by args
      def reorder(*args)
        query = copy

        query.remove_clause_class(OrderClause)
        query.order(*args)
      end

      # Works the same as the #set method, but when given a nested array it will set properties rather than setting entire objects
      # @example
      #    # Creates a query representing the gremlin: MATCH (n:Person) SET n.age = 19
      #    Query.new.match(n: :Person).set_props(n: {age: 19})
      def set_props(*args)
        build_deeper_query(SetClause, args, set_props: true)
      end

      # Allows what's been built of the query so far to be frozen and the rest built anew.  Can be called multiple times in a string of method calls
      # @example
      #   # Creates a query representing the gremlin: MATCH (q:Person), r:Car MATCH (p: Person)-->q
      #   Query.new.match(q: Person).match('r:Car').break.match('(p: Person)-->q')
      def break
        build_deeper_query(nil)
      end

      # Allows for the specification of values for params specified in query
      # @example
      #   # Creates a query representing the gremlin: MATCH (q: Person {id: {id}})
      #   # Calls to params don't affect the gremlin query generated, but the params will be
      #   # Passed down when the query is made
      #   Query.new.match('(q: Person {id: {id}})').params(id: 12)
      #
      def params(args)
        @_params = @_params.merge(args)

        self
      end

      def unwrapped
        @_unwrapped_obj = true
        self
      end

      def unwrapped?
        !!@_unwrapped_obj
      end

      def response
        return @response if @response
        gremlin = to_gremlin
        @response = ActiveSupport::Notifications.instrument('titan.gremlin_query', context: @options[:context] || 'GREMLIN', gremlin: gremlin, params: merge_params) do
          @session._query(gremlin, merge_params)
        end
        if !response.respond_to?(:error?) || !response.error?
          response
        else
          response.raise_gremlin_error
        end
      end

      include Enumerable

      def count(var = nil)
        v = var.nil? ? '*' : var
        pluck("count(#{v})").first
      end

      def each
        response = self.response
        if response.is_a?(Titan::Server::GremlinResponse)
          response.unwrapped! if unwrapped?
          response.to_node_enumeration
        else
          Titan::Embedded::ResultWrapper.new(response, to_gremlin, unwrapped?)
        end.each { |object| yield object }
      end

      # @method to_a
      # Class is Enumerable.  Each yield is a Hash with the key matching the variable returned and the value being the value for that key from the response
      # @return [Array]
      # @raise [Titan::Server::GremlinResponse::ResponseError] Raises errors from titan server


      # Executes a query without returning the result
      # @return [Boolean] true if successful
      # @raise [Titan::Server::GremlinResponse::ResponseError] Raises errors from titan server
      def exec
        response

        true
      end

      # Return the specified columns as an array.
      # If one column is specified, a one-dimensional array is returned with the values of that column
      # If two columns are specified, a n-dimensional array is returned with the values of those columns
      #
      # @example
      #    Query.new.match(n: :Person).return(p: :name}.pluck(p: :name) # => Array of names
      # @example
      #    Query.new.match(n: :Person).return(p: :name}.pluck('p, DISTINCT p.name') # => Array of [node, name] pairs
      #
      def pluck(*columns)
        query = return_query(columns)
        columns = query.response.columns

        case columns.size
        when 0 then fail ArgumentError, 'No columns specified for Query#pluck'
        when 1
          column = columns[0]
          query.map { |row| row[column] }
        else
          query.map do |row|
            columns.map do |column|
              row[column]
            end
          end
        end
      end

      def return_query(columns)
        query = copy
        query.remove_clause_class(ReturnClause)

        columns = columns.flat_map do |column_definition|
          if column_definition.is_a?(Hash)
            column_definition.map { |k, v| "#{k}.#{v}" }
          else
            column_definition
          end
        end.map(&:to_sym)

        query.return(columns)
      end

      # Returns a GREMLIN query string from the object query representation
      # @example
      #    Query.new.match(p: :Person).where(p: {age: 30})  # => "MATCH (p:Person) WHERE p.age = 30
      #
      # @return [String] Resulting gremlin query string
      def to_gremlin
        gremlin_string = partitioned_clauses.map do |clauses|
          clauses_by_class = clauses.group_by(&:class)

          gremlin_parts = CLAUSES.map do |clause_class|
            clause_class.to_gremlin(clauses) if clauses = clauses_by_class[clause_class]
          end

          gremlin_parts.compact.join(' ').strip
        end.join ' '

        gremlin_string = "GREMLIN #{@options[:parser]} #{gremlin_string}" if @options[:parser]
        gremlin_string.strip
      end

      # Returns a GREMLIN query specifying the union of the callee object's query and the argument's query
      #
      # @example
      #    # Generates gremlin: MATCH (n:Person) UNION MATCH (o:Person) WHERE o.age = 10
      #    q = Titan::Core::Query.new.match(o: :Person).where(o: {age: 10})
      #    result = Titan::Core::Query.new.match(n: :Person).union_gremlin(q)
      #
      # @param other [Query] Second half of UNION
      # @param options [Hash] Specify {all: true} to use UNION ALL
      # @return [String] Resulting UNION gremlin query string
      def union_gremlin(other, options = {})
        "#{to_gremlin} UNION#{options[:all] ? ' ALL' : ''} #{other.to_gremlin}"
      end

      def &(other)
        fail "Sessions don't match!" if @session != other.session

        self.class.new(session: @session).tap do |new_query|
          new_query.options = options.merge(other.options)
          new_query.clauses = clauses + other.clauses
        end.params(other._params)
      end

      MEMOIZED_INSTANCE_VARIABLES = [:response, :merge_params]
      def copy
        dup.tap do |query|
          MEMOIZED_INSTANCE_VARIABLES.each do |var|
            query.instance_variable_set("@#{var}", nil)
          end
        end
      end

      def clause?(method)
        clause_class = DEFINED_CLAUSES[method] || CLAUSIFY_CLAUSE.call(method)
        clauses.any? do |clause|
          clause.is_a?(clause_class)
        end
      end

      protected

      attr_accessor :session, :options, :clauses, :_params

      def add_clauses(clauses)
        @clauses += clauses
      end

      def remove_clause_class(clause_class)
        @clauses = @clauses.reject do |clause|
          clause.is_a?(clause_class)
        end
      end

      private

      def build_deeper_query(clause_class, args = {}, options = {})
        copy.tap do |new_query|
          new_query.add_clauses [nil] if [nil, WithClause].include?(clause_class)
          new_query.add_clauses clause_class.from_args(args, options) if clause_class
        end
      end

      def break_deeper_query
        copy.tap do |new_query|
          new_query.add_clauses [nil]
        end
      end

      def partitioned_clauses
        partitioning = [[]]

        @clauses.each do |clause|
          if clause.nil? && partitioning.last != []
            partitioning << []
          else
            partitioning.last << clause
          end
        end

        partitioning
      end

      def merge_params
        @merge_params ||= @clauses.compact.inject(@_params) { |params, clause| params.merge(clause.params) }
      end

      def sanitize_params(params)
        passthrough_classes = [String, Numeric, Array, Regexp]
        params.each do |key, value|
          params[key] = value.to_s if not passthrough_classes.any? { |klass| value.is_a?(klass) }
        end
      end
    end
  end
end
