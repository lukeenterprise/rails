# frozen_string_literal: true

module ActiveRecord
  class AsyncQueriesHandler
    def initialize
      # TODO: this should have sane defaults computed from the db config pool size etc.
      # It could also make sense to have distinct thread pools per connection pools.
      @thread_pool = Concurrent::ThreadPoolExecutor.new( 
        min_threads: 5,
        max_threads: 5,
        max_queue: 25,
        # fallback_policy: :caller_runs
      )
    end

    def register(future_result)
      current_queries[future_result] = future_result
      Thread.start { future_result.execute_or_skip }
      @thread_pool.post { future_result.execute_or_skip }
    end

    # This should be called from a request/job middleware to cancel all queries that might not have been used
    def finalize
      if queries = Thread.current.thread_variable_get(:ar_async_queries)
        Thread.current.thread_variable_set(:ar_async_queries, nil)
        queries.each_value(&:cancel!)
      end
    end

    private

    def current_queries
      Thread.current.thread_variable_get(:ar_async_queries) ||
        Thread.current.thread_variable_set(:ar_async_queries, ObjectSpace::WeakMap.new)
    end
  end

  class << self
    attr_accessor :async_query_handler
  end
  @async_query_handler = AsyncQueriesHandler.new

  class FutureResult
    Canceled = Class.new(ActiveRecordError)

    delegate :empty?, to: :result!

    def initialize(pool, *args, **kwargs)
      @mutex = Mutex.new

      @pool = pool
      @args = args
      @kwargs = kwargs

      @executed = false
      @error = nil
      @result = nil
      schedule!
    end

    def schedule!
      ActiveRecord.async_query_handler.register(self)
    end

    def cancel!
      @executed = true
      @error = Canceled
    end

    def execute_or_skip
      return if @executed
      return unless @mutex.try_lock
      return if @executed

      ActiveRecord::Base.logger.info("Executing in background #{Process.clock_gettime(Process::CLOCK_MONOTONIC)}")

      begin
        execute_query
      ensure
        @mutex.unlock
      end
    end

    def result!
      execute_or_wait
      if @error
        raise @error
      else
        @result
      end
    end

    private

    def execute_or_wait
      return if @executed
      if @mutex.try_lock
        begin
          ActiveRecord::Base.logger.info("Executing in foreground #{Process.clock_gettime(Process::CLOCK_MONOTONIC)}")
          execute_query
        ensure
          @mutex.unlock
        end
      else
        ActiveRecord::Base.logger.info("Waiting on result #{Process.clock_gettime(Process::CLOCK_MONOTONIC)}")
        @mutex.synchronize do
          return if @executed
          execute_query
        end
      end
    end

    def execute_query
      @result = begin
        @pool.with_connection do |connection|
          connection.exec_query(*@args, **@kwargs)
        end
      rescue ::RangeError
        ActiveRecord::Result.new([], [])
      end
    rescue => error
      @error = error
    ensure
      @executed = true
    end
  end
end
