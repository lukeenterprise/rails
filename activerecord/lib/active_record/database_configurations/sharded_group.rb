# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    class ShardedGroup # :nodoc:
      attr_reader :name

      def initialize(topology, name)
        @topology = topology
        @name = name
        @shards = {}

        @selected_roles = {}
        @selected_shards = {}
      end

      def shard(shard)
        @shards.fetch(shard) do
          raise InvalidSelectionError, "There is no #{shard.inspect} shard"
        end
      end

      def select(role: selected_role, shard: selected_shard)
        previous_role = selected_role
        previous_shard = selected_shard

        self.selected_role = role
        self.selected_shard = shard

        yield
      ensure
        self.selected_role = previous_role
        self.selected_shard = previous_shard
      end

      def current_database
        shard(selected_shard).role(selected_role)
      end

      def spec_name
        name
      end

      def env_name
        @topology.env_name
      end

      def add_shard(name)
        raise ArgumentError, "#{name.inspect} shard is already defined" if @shards.key?(name)

        @shards[name] = Shard.new(self, name)
      end

      def resolve_database(role:)
        @roles.fetch(role)
      end

      def schema_cache
        raise NotImplementedError
      end

      def selected_role
        @selected_roles[Thread.current] || ActiveRecord::Base.writing_role
      end

      def selected_role=(role)
        @selected_roles[Thread.current] = role
      end

      def selected_shard
        @selected_shards[Thread.current]
      end

      def selected_shard=(shard)
        @selected_shards[Thread.current] = shard
      end
    end
  end
end
