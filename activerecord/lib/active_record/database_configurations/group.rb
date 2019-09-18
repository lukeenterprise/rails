# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    class Group # :nodoc:
      attr_reader :name

      def initialize(topology, name)
        @topology = topology
        @name = name
        @roles = {}
        @selected_roles = {}
      end

      def role(name)
        @roles.fetch(name) do
          raise InvalidSelectionError, "There is no #{name.inspect} role"
        end
      end

      def select(role:)
        previous_role = selected_role
        self.selected_role = role
        yield
      ensure
        self.selected_role = previous_role
      end

      def current_database
        role(selected_role)
      end

      def spec_name
        name
      end

      def env_name
        @topology.env_name
      end

      def add_role(name, database_configuration)
        raise ArgumentError, "#{name.inspect} role is already defined" if @roles.key?(name)

        @roles[name] = Role.new(self, name, database_configuration)
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
    end
  end
end
