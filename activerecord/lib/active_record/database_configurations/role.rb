# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    class Role # :nodoc:
      attr_reader :name, :db_config

      def initialize(group, name, database_config)
        @group = group
        @name = name
        @db_config = HashConfig.new(env_name, group.spec_name, database_config)
      end

      def env_name
        @group.env_name
      end

      def pool
        raise NotImplementedError
      end
    end
  end
end
