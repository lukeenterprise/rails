# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
   class Schema
     attr_reader :name, :roles

     def initialize(name)
       @name = name
       @roles = {}
     end

     def migration_context # :nodoc:
       MigrationContext.new(writing_role.db_config.migrations_paths, schema_migration)
     end

     def schema_migration # :nodoc:
       @schema_migration ||= begin
                               schema = self
                               name = "#{schema.name.to_s.camelize}::SchemaMigration"

                               Class.new(ActiveRecord::SchemaMigration) do
                                 define_singleton_method(:name) { name }
                                 define_singleton_method(:to_s) { name }

                                 connects_to schema: schema.name
                               end
                             end
     end

     def add_role(role_name, role)
       @roles[role_name] = role
     end

     def writing_role
       roles.fetch(Base.writing_role)
     end
   end
  end
end
