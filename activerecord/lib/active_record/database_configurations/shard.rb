# frozen_string_literal: true

module ActiveRecord
  class DatabaseConfigurations
    class Shard # :nodoc:
      attr_reader :name

      def initialize(group, name)
        @group = group
        @name = name
        @roles = {}
      end

      def role(name)
        @roles.fetch(name) do
          raise InvalidSelectionError, "There is no #{name.inspect} role"
        end
      end

      def spec_name
        @group.spec_name
      end

      def env_name
        @group.env_name
      end

      def add_role(name, database_configuration)
        raise ArgumentError, "#{name.inspect} role is already defined" if @roles.key?(name)

        @roles[name] = Role.new(self, name, database_configuration)
      end
    end
  end
end
