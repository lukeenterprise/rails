# frozen_string_literal: true

require "pathname"
require "rails/version"

module Rails
  class Application
    module ConfigLoader # :nodoc:
      module Default
        class << self
          def config_for(app, name, env: Rails.env)
            if name.is_a?(Pathname)
              yaml = name
            else
              yaml = Pathname.new("#{app.paths["config"].existent.first}/#{name}.yml")
            end

            if yaml.exist?
              require "erb"
              config = YAML.load(ERB.new(yaml.read).result) || {}
              config = (config["shared"] || {}).merge(config[env] || {})

              ActiveSupport::OrderedOptions.new.tap do |options|
                options.update(Application::NonSymbolAccessDeprecatedHash.new(config))
              end
            else
              raise "Could not load configuration. No such file - #{yaml}"
            end
          rescue Psych::SyntaxError => e
            raise "YAML syntax error occurred while parsing #{yaml}. " \
              "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
              "Error: #{e.message}"
          end
        end
      end
    end
  end
end
