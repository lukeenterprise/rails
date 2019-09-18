# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    class Topology # :nodoc:
      attr_reader :env_name

      def initialize(env_name)
        @env_name = env_name
        @groups = {}
      end

      def group(name)
        @groups.fetch(name)
      end

      def add_group(name)
        raise ArgumentError, "#{name.inspect} group is already defined" if @groups.key?(name)

        @groups[name] = Group.new(self, name)
      end

      def add_sharded_group(name)
        raise ArgumentError, "#{name.inspect} group is already defined" if @groups.key?(name)

        @groups[name] = ShardedGroup.new(self, name)
      end

      def resolve_database(database:, role:)
        @groups.fetch(database).resolve_database(role: role)
      end
    end
  end
end
