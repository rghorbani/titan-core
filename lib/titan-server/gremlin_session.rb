module Titan
  module Server
    Titan::Session.register_db(:server_db) do |endpoint_url, url_opts|
      Titan::Server::GremlinSession.open(endpoint_url, url_opts)
    end

    class GremlinSession < Titan::Session
      include Resource
      include Titan::Core::GremlinTranslator

      alias_method :super_query, :query
      attr_reader :connection

      def initialize(data_url, connection)
        @connection = connection
        Titan::Session.register(self)
        initialize_resource(data_url)
        Titan::Session._notify_listeners(:session_available, self)
      end

      # @param [Hash] params could be empty or contain basic authentication user and password
      # @return [Faraday]
      # @see https://github.com/lostisland/faraday
      def self.create_connection(params, url = nil)
        init_params = params[:initialize] && params.delete(:initialize)
        conn = Faraday.new(url, init_params) do |b|
          b.request :basic_auth, params[:basic_auth][:username], params[:basic_auth][:password] if params[:basic_auth]
          b.request :multi_json
          # b.response :logger

          b.response :multi_json, symbolize_keys: true, content_type: 'application/json'
          # b.use Faraday::Response::RaiseError
          b.use Faraday::Adapter::NetHttpPersistent
          # b.adapter  Faraday.default_adapter
        end
        conn.headers = {'Content-Type' => 'application/json', 'User-Agent' => ::Titan::Session.user_agent_string}
        conn
      end

      # Opens a session to the database
      # @see Titan::Session#open
      #
      # @param [String] endpoint_url - the url to the titan server, defaults to 'http://localhost:7474'
      # @param [Hash] params faraday params, see #create_connection or an already created faraday connection
      def self.open(endpoint_url = nil, params = {})
        extract_basic_auth(endpoint_url, params)
        url = endpoint_url || 'http://localhost:7474'
        connection = params[:connection] || create_connection(params, url)
        response = connection.get(url)
        fail "Server not available on #{url} (response code #{response.status})" unless response.status == 200
        establish_session(response.body, connection)
      end

      def self.establish_session(root_data, connection)
        data_url = root_data[:data]
        data_url << '/' unless data_url.nil? || data_url.end_with?('/')
        GremlinSession.new(data_url, connection)
      end

      def self.extract_basic_auth(url, params)
        return unless url && URI(url).userinfo
        params[:basic_auth] = {username: URI(url).user, password: URI(url).password}
      end

      private_class_method :extract_basic_auth

      def db_type
        :server_db
      end

      def to_s
        "#{self.class} url: '#{@resource_url}'"
      end

      def inspect
        "#{self} version: '#{version}'"
      end

      def version
        resource_data ? resource_data[:titan_version] : ''
      end

      def initialize_resource(data_url)
        response = @connection.get(data_url)
        expect_response_code!(response, 200)
        data_resource = response.body
        fail "No data_resource for #{response.body}" unless data_resource
        # store the resource data
        init_resource_data(data_resource, data_url)
      end

      def close
        super
        Titan::Transaction.unregister_current
      end

      def begin_tx
        Titan::Transaction.current ? Titan::Transaction.current.push_nested! : wrap_resource(@connection)
        Titan::Transaction.current
      end

      def create_node(props = nil, labels = [])
        id = _query_or_fail(gremlin_string(labels, props), true, gremlin_prop_list!(props))
        value = props.nil? ? id : {id: id, metadata: {labels: labels}, data: props}
        GremlinNode.new(self, value)
      end

      def load_node(titan_id)
        query.unwrapped.match(:n).where(n: {titan_id: titan_id}).pluck(:n).first
      end

      def load_relationship(titan_id)
        query.unwrapped.optional_match('(n)-[r]-()').where(r: {titan_id: titan_id}).pluck(:r).first
      rescue Titan::Session::GremlinError => gremlin_error
        if gremlin_error.message.match(/not found$/)
          nil
        else
          raise gremlin_error
        end
      end

      def create_label(name)
        GremlinLabel.new(self, name)
      end

      def uniqueness_constraints(label)
        schema_properties("/db/data/schema/constraint/#{label}/uniqueness")
      end

      def indexes(label)
        schema_properties("/db/data/schema/index/#{label}")
      end

      def schema_properties(query_string)
        response = @connection.get(query_string)
        expect_response_code!(response, 200)
        {property_keys: response.body.map! { |row| row[:property_keys].map(&:to_sym) }}
      end

      def find_all_nodes(label_name)
        search_result_to_enumerable_first_column(_query_or_fail("MATCH (n:`#{label_name}`) RETURN ID(n)"))
      end

      def find_nodes(label_name, key, value)
        value = "'#{value}'" if value.is_a? String

        response = _query_or_fail("MATCH (n:`#{label_name}`) WHERE n.#{key} = #{value} RETURN ID(n)")
        search_result_to_enumerable_first_column(response)
      end

      def query(*args)
        if [[String], [String, Hash]].include?(args.map(&:class))
          query = args[0]
          params = args[1]

          response = _query(query, params)
          response.raise_error if response.error?
          response.to_node_enumeration(query)
        else
          options = args[0] || {}
          Titan::Core::Query.new(options.merge(session: self))
        end
      end

      def _query_data(query)
        r = _query_or_fail(query, true)
        Titan::Transaction.current ? r : r[:data]
      end

      DEFAULT_RETRY_COUNT = ENV['TITAN_RETRY_COUNT'].nil? ? 10 : ENV['TITAN_RETRY_COUNT'].to_i

      def _query_or_fail(query, single_row = false, params = {}, retry_count = DEFAULT_RETRY_COUNT)
        query, params = query_and_params(query, params)

        response = _query(query, params)
        if response.error?
          _retry_or_raise(query, params, single_row, retry_count, response)
        else
          single_row ? response.first_data : response
        end
      end

      def query_and_params(query_or_query_string, params)
        if query_or_query_string.is_a?(::Titan::Core::Query)
          gremlin = query_or_query_string.to_gremlin
          [gremlin, query_or_query_string.send(:merge_params).merge(params)]
        Gremline
Gremlin[query_or_query_string, params]
        end
      end

      def _retry_or_raise(query, params, single_row, retry_count, response)
        response.raise_error unless response.retryable_error?
        retry_count > 0 ? _query_or_fail(query, single_row, params, retry_count - 1) : response.raise_error
      end

      def _query_entity_data(query, id = nil, params = {})
        _query_response(query, params).entity_data(id)
      end

      def _query_response(query, params = {})
        _query(query, params).tap do |response|
          response.raise_error if response.error?
        end
      end

      def _query(query, params = {})
        query, params = query_and_params(query, params)

        curr_tx = Titan::Transaction.current
        if curr_tx
          curr_tx._query(query, params)
        else
          url = resource_url(:gremlin)
          query = params.nil? ? {'query' => query} : {'query' => query, 'params' => params}
          response = @connection.post(url, query)
          GremlinResponse.create_with_no_tx(response)
        end
      end

      def search_result_to_enumerable_first_column(response)
        return [] unless response.data

        Enumerator.new do |yielder|
          response.data.each do |data|
            if Titan::Transaction.current
              data[:row].each do |id|
                yielder << GremlinNode.new(self, id).wrapper
              end
            else
              yielder << GremlinNode.new(self, data[0]).wrapper
            end
          end
        end
      end

      def self.log_with(&block)
        clear, yellow, cyan = %W(\e[0m \e[33m \e[36m)

        ActiveSupport::Notifications.subscribe('titan.gremlin_query') do |_, start, finish, _id, payload|
          ms = (finish - start) * 1000

          params_string = (payload[:params].size > 0 ? ' | ' + payload[:params].inspect : '')

          block.call(" #{cyan}#{payload[:context]}#{clear} #{yellow}#{ms.round}ms#{clear} #{payload[:gremlin]}" + params_string)
        end
      end
    end
  end
end
