module Titan
  module Transaction
    extend self

    module Instance
      # @private
      def register_instance
        @pushed_nested = 0
        Titan::Transaction.register(self)
      end

      # Marks this transaction as failed, which means that it will unconditionally be rolled back when close() is called. Aliased for legacy purposes.
      def mark_failed
        @failure = true
      end
      alias_method :failure, :mark_failed

      # If it has been marked as failed. Aliased for legacy purposes.
      def failed?
        !!@failure
      end
      alias_method :failure?, :failed?

      def mark_expired
        @expired = true
      end

      def expired?
        !!@expired
      end

      # @private
      def push_nested!
        @pushed_nested += 1
      end

      # @private
      def pop_nested!
        @pushed_nested -= 1
      end

      # Only for the embedded titan !
      # Acquires a read lock for entity for this transaction.
      # See titan java docs.
      # @param [Titan::Node,Titan::Relationship] entity
      # @return [Java::OrgTitanKernelImplCoreapi::PropertyContainerLocker]
      def acquire_read_lock(entity)
      end

      # Only for the embedded titan !
      # Acquires a write lock for entity for this transaction.
      # See titan java docs.
      # @param [Titan::Node,Titan::Relationship] entity
      # @return [Java::OrgTitanKernelImplCoreapi::PropertyContainerLocker]
      def acquire_write_lock(entity)
      end

      # Commits or marks this transaction for rollback, depending on whether failure() has been previously invoked.
      def close
        pop_nested!
        return if @pushed_nested >= 0
        fail "Can't commit transaction, already committed" if @pushed_nested < -1
        Titan::Transaction.unregister(self)
        failed? ? delete : commit
      end
    end

    # @return [Titan::Transaction::Instance]
    def new(current = Session.current!)
      current.begin_tx
    end

    # Runs the given block in a new transaction.
    # @param [Boolean] run_in_tx if true a new transaction will not be created, instead if will simply yield to the given block
    # @@yield [Titan::Transaction::Instance]
    def run(run_in_tx = true)
      fail ArgumentError, 'Expected a block to run in Transaction.run' unless block_given?

      return yield(nil) unless run_in_tx

      tx = Titan::Transaction.new
      yield tx
    rescue Exception => e # rubocop:disable Lint/RescueException
      print_exception_cause(e)
      tx.mark_failed unless tx.nil?
      raise
    ensure
      tx.close unless tx.nil?
    end

    # @return [Titan::Transaction]
    def current
      Thread.current[:titan_curr_tx]
    end

    # @private
    def print_exception_cause(exception)
      return if !exception.respond_to?(:cause) || !exception.cause.respond_to?(:print_stack_trace)

      puts "Java Exception in a transaction, cause: #{exception.cause}"
      exception.cause.print_stack_trace
    end

    # @private
    def unregister(tx)
      Thread.current[:titan_curr_tx] = nil if tx == Thread.current[:titan_curr_tx]
    end

    # @private
    def register(tx)
      # we don't support running more then one transaction per thread
      fail 'Already running a transaction' if current
      Thread.current[:titan_curr_tx] = tx
    end

    # @private
    def unregister_current
      Thread.current[:titan_curr_tx] = nil
    end
  end
end
