# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    # ActiveRecord::Base.configurations will return either a HashConfig or
    # UrlConfig respectively. It will never return a DatabaseConfig object,
    # as this is the parent class for the types of database configuration objects.
    class DatabaseConfig # :nodoc:
      attr_reader :env_name, :spec_name, :pool

      def initialize(env_name, spec_name)
        @env_name = env_name
        @spec_name = spec_name
        @pool = ConnectionAdapters::ConnectionPool.new(self)
      end

      def name
        spec_name
      end

      def config
        raise NotImplementedError
      end

      def adapter_method
        # Require the adapter itself and give useful feedback about
        #   1. Missing adapter gems and
        #   2. Adapter gems' missing dependencies.
        adapter = config['adapter']
        path_to_adapter = "active_record/connection_adapters/#{adapter}_adapter"
        begin
          require path_to_adapter
        rescue LoadError => e
          # We couldn't require the adapter itself. Raise an exception that
          # points out config typos and missing gems.
          if e.path == path_to_adapter
            # We can assume that a non-builtin adapter was specified, so it's
            # either misspelled or missing from Gemfile.
            raise LoadError, "Could not load the '#{adapter}' Active Record adapter. Ensure that the adapter is spelled correctly in config/database.yml and that you've added the necessary adapter gem to your Gemfile.", e.backtrace

          # Bubbled up from the adapter require. Prefix the exception message
          # with some guidance about how to address it and reraise.
          else
            raise LoadError, "Error loading the '#{adapter}' Active Record adapter. Missing a gem it depends on? #{e.message}", e.backtrace
          end
        end

        adapter_method = "#{adapter}_connection"

        unless ActiveRecord::Base.respond_to?(adapter_method)
          raise AdapterNotFound, "database configuration specifies nonexistent #{adapter} adapter"
        end

        adapter_method
      end

      def replica?
        raise NotImplementedError
      end

      def migrations_paths
        raise NotImplementedError
      end

      def url_config?
        false
      end

      def to_legacy_hash
        { env_name => config }
      end

      def for_current_env?
        env_name == ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
      end
    end
  end
end
