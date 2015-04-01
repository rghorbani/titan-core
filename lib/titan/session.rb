module Titan
  class Session
    @@current_session = nil
    @@all_sessions = {}
    @@factories = {}

    # @abstract
    def close
      self.class.unregister(self)
    end

    # Only for embedded database
    # @abstract
    def start
      fail 'not impl.'
    end

    # Only for embedded database
    # @abstract
    def shutdown
      fail 'not impl.'
    end

    # Only for embedded database
    # @abstract
    def running
      fail 'not impl.'
    end

    # @return [:embedded_db | :server_db]
    def db_type
      fail 'not impl.'
    end

    def auto_commit?
      true # TODO
    end

    # @abstract
    def begin_tx
      fail 'not impl.'
    end

    class GremlinError < StandardError
      attr_reader :error_msg, :error_status, :error_code
      def initialize(error_msg, error_code, error_status)
        super(error_msg)
        @error_msg = error_msg
        @error_status = error_status
      end
    end

    class InitializationError < RuntimeError; end

    # Performs a gremlin query.  See {Gremlin::Core::Query} for more details, but basic usage looks like:
    #
    # @example Using gremlin DSL
    #   Titan::Session.query.match("(c:person)-[:friends]->(p:person)").where(c: {name: 'andreas'}).pluck(:p).first[:name]
    #
    # @example Show the generated Gremlin
    #   Titan::Session.query..match("(c:person)-[:friends]->(p:person)").where(c: {name: 'andreas'}).return(:p).to_gremlin
    #
    # @example Use Gremlin string instead of the gremlin DSL
    #   Titan::Session.query("MATCH (c:person)-[:friends]->(p:person) WHERE c.name = \"andreas\" RETURN p").first[:p][:name]
    #
    # @return [Titan::Core::Query, Enumerable] return a Query object for DSL or a Enumerable if using raw gremlin strings
    # @see http://gremlin.tinkerpop.com The Gremlin Query Language Documentation
    #
    def query(options = {})
      fail 'not implemented, abstract'
    end

    # Same as #query but does not accept an DSL and returns the raw result from the database.
    # Notice, it might return different values depending on which database is used, embedded or server.
    # @abstract
    def _query(*params)
      fail 'not implemented'
    end

    class << self
      # Creates a new session to Titan.
      # This will be the default session to be used unless there is already a session created (see #current and #set_current)
      #
      # @example A Titan Server session
      #   Titan::Session.open(:server_db, 'http://localhost:7474', {basic_auth: {username: 'foo', password: 'bar'}})
      #
      # @example Using a user defined Faraday HTTP connection
      #   connection = Faraday.new do |b|
      #     # faraday config
      #   end
      #   Titan::Session.open(:server_db, 'http://localhost:7474', connection: connection)
      #
      # @example A embedded Titan session
      #   Titan::Session.open(:embedded_db, 'path/to/db')
      #
      # @see also Titan::Server::GremlinSession#open for :server_db params
      # @param db_type the type of database, e.g. :embedded_db, or :server_db
      # @param [String] endpoint_url The path to the server, either a URL or path to embedded DB
      # @param [Hash] params Additional configuration options
      def open(db_type = :server_db, endpoint_url = nil, params = {})
        validate_session_num!(db_type)
        name = params[:name]
        default = params[:default]
        [:name, :default].each { |k| params.delete(k) }
        register(create_session(db_type, endpoint_url, params), name, default)
      end

      # @private
      def validate_session_num!(db_type)
        return unless current && db_type == :embedded_db
        fail InitializationError, 'Multiple sessions are not supported by Titan Embedded.'
      end
      private :validate_session_num!

      # @private
      def create_session(db_type, endpoint_url, params = {})
        unless @@factories[db_type]
          fail InitializationError, "Can't connect to database '#{db_type}', available #{@@factories.keys.join(',')}"
        end
        @@factories[db_type].call(endpoint_url, params)
      end

      # @return [Titan::Session] the current session
      def current
        @@current_session
      end

      # Returns the current session or raise an exception if no session is available
      def current!
        fail 'No session, please create a session first with Titan::Session.open(:server_db) or :embedded_db' unless current
        current
      end

      # @see Titan::Session#query
      def query(*args)
        current!.query(*args)
      end

      # Returns a session with given name or else raise an exception
      def named(name)
        @@all_sessions[name] || fail("No session named #{name}.")
      end

      # Sets the session to be used as default
      # @param [Titan::Session] session the session to use
      def set_current(session)
        @@current_session = session
      end

      # Registers a callback which will be called immediately if session is already available,
      # or called when it later becomes available.
      def on_session_available
        yield Titan::Session.current if Titan::Session.current

        add_listener do |event, data|
          yield data if event == :session_available
        end
      end

      def user_agent_string
        gem, version = if defined?(::Titan::ActiveNode)
                         ['titan', ::Titan::VERSION]
                       else
                         ['titan-core', ::Titan::Core::VERSION]
                       end


        "#{gem}-gem/#{version} (https://github.com/rghorabni/#{gem})"
      end

      # @private
      def add_listener(&listener)
        _listeners << listener
      end

      # @private
      def _listeners
        @@listeners ||= []
        @@listeners
      end

      # @private
      def _notify_listeners(event, data)
        _listeners.each { |li| li.call(event, data) }
      end

      # @private
      def register(session, name = nil, default = nil)
        if default == true
          set_current(session)
        elsif default.nil?
          set_current(session) unless @@current_session
        end
        @@all_sessions[name] = session if name
        session
      end

      # @private
      def unregister(session)
        @@current_session = nil if @@current_session == session
      end

      def inspect
        "Titan::Session available: #{@@factories && @@factories.keys}"
      end

      # @private
      def register_db(db, &session_factory)
        puts "replace factory for #{db}" if @@factories[db]
        @@factories[db] = session_factory
      end
    end
  end
end
