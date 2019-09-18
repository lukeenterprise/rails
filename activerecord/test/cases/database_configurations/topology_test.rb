# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class DatabaseConfigurations
    class TopologyTest < ActiveRecord::TestCase
      def setup
        @base_config = ActiveRecord::Base.connection_pool.spec.db_config.configuration_hash.dup
      end

      def test_simple_two_tier_topology
        @topology = Topology.new("arunit")
        primary_group = @topology.add_group(:primary)

        primary_group.add_role(:writing, @base_config)
        primary_group.add_role(:reading, @base_config.merge(replica: true))

        primary_group = @topology.group(:primary)

        writing_role = primary_group.current_database
        assert_equal :writing, writing_role.name
        assert_kind_of DatabaseConfig, writing_role.db_config
        assert_equal "arunit", writing_role.db_config.env_name
        assert_equal :primary, writing_role.db_config.spec_name
        refute_predicate writing_role.db_config, :replica?

        primary_group.select(role: :reading) do
          reading_role = primary_group.current_database
          assert_equal :reading, reading_role.name
          assert_kind_of DatabaseConfig, reading_role.db_config
          assert_equal "arunit", reading_role.db_config.env_name
          assert_equal :primary, reading_role.db_config.spec_name
          assert_predicate reading_role.db_config, :replica?
        end

        assert_raises InvalidSelectionError do
          primary_group.select(role: :not_found) do
            primary_group.current_database
          end
        end
      end

      def test_sharded_topology
        @topology = Topology.new("sharded_arunit")
        primary_group = @topology.add_sharded_group(:primary)

        first_shard = primary_group.add_shard(1)
        first_shard.add_role(:writing, @base_config.merge(shard: 1))
        first_shard.add_role(:reading, @base_config.merge(shard: 1, replica: true))

        second_shard = primary_group.add_shard(2)
        second_shard.add_role(:writing, @base_config.merge(shard: 2))
        second_shard.add_role(:reading, @base_config.merge(shard: 2, replica: true))

        primary_group = @topology.group(:primary)

        primary_group.select(shard: 1) do
          writing_role = primary_group.current_database
          assert_equal :writing, writing_role.name
          assert_kind_of DatabaseConfig, writing_role.db_config
          assert_equal "sharded_arunit", writing_role.db_config.env_name
          assert_equal :primary, writing_role.db_config.spec_name
          refute_predicate writing_role.db_config, :replica?
          assert_equal 1, writing_role.db_config.configuration_hash[:shard]
        end

        primary_group.select(shard: 2, role: :reading) do
          reading_role = primary_group.current_database
          assert_equal :reading, reading_role.name
          assert_kind_of DatabaseConfig, reading_role.db_config
          assert_equal "sharded_arunit", reading_role.db_config.env_name
          assert_equal :primary, reading_role.db_config.spec_name
          assert_predicate reading_role.db_config, :replica?
          assert_equal 2, reading_role.db_config.configuration_hash[:shard]
        end

        assert_raises InvalidSelectionError do
          primary_group.select(role: :reading) do
            primary_group.current_database
          end
        end

        assert_raises InvalidSelectionError do
          primary_group.select(shard: 42, role: :reading) do
            primary_group.current_database
          end
        end

        assert_raises InvalidSelectionError do
          primary_group.select(shard: 1, role: :not_found) do
            primary_group.current_database
          end
        end
      end
    end
  end
end
