# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    # ActiveRecord::Base.configurations will return either a HashConfig or
    # UrlConfig respectively. It will never return a DatabaseConfig object,
    # as this is the parent class for the types of database configuration objects.
    class DatabaseConfig # :nodoc:
      include Mutex_m

      attr_reader :env_name, :spec_name

      attr_accessor :schema_cache

      def initialize(env_name, spec_name)
        super()
        @env_name = env_name
        @spec_name = spec_name
        @pool = nil
        @pool_pid = Process.pid
      end

      def disconnect!
        discard_unowned_pool!

        return unless @pool

        synchronize do
          return unless @pool

          @pool.automatic_reconnect = false
          @pool.disconnect!
        end

        nil
      end

      def connection_pool
        discard_unowned_pool!

        @pool || synchronize { @pool ||= ConnectionAdapters::ConnectionPool.new(self) }
      end

      def discard_unowned_pool!
        return if @pool_pid == Process.pid

        synchronize do
          return if @pool_pid == Process.pid

          @pool&.discard!
          @pool = nil
          @pool_pid = Process.pid
        end
      end

      def config
        raise NotImplementedError
      end

      def adapter_method
        "#{adapter}_connection"
      end

      def database
        raise NotImplementedError
      end

      def adapter
        raise NotImplementedError
      end

      def pool
        raise NotImplementedError
      end

      def checkout_timeout
        raise NotImplementedError
      end

      def reaping_frequency
        raise NotImplementedError
      end

      def idle_timeout
        raise NotImplementedError
      end

      def replica?
        raise NotImplementedError
      end

      def migrations_paths
        raise NotImplementedError
      end

      def for_current_env?
        env_name == ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
      end
    end
  end
end
