module Pechkin
  # Common code for all configuration loaders. To use this code just include
  # module in user class.
  module ConfigurationLoader
    def fetch_field(object, field, file)
      contains = object.key?(field)

      raise ConfigurationError, "#{file}: '#{field}' is missing" unless contains

      object[field]
    end

    # Fetch token from environment variable defined in configuration file.
    def fetch_value_from_env(object, token_field, file)
      raise ConfigurationError, "#{file}: '#{token_field}' is missing in configuration" unless object.key?(token_field)

      env_var = object[token_field]
      token = ENV.fetch(env_var, nil)

      raise ConfigurationError, "#{file}: environment var '#{token_field}' is missing" if token.to_s.strip.empty?

      token
    end

    def create_connector(bot)
      connector_klass = Connector.list[bot.connector]
      # Also check for aliases if any (e.g. 'tg' for 'telegram')
      connector_klass ||= Connector.list['telegram'] if bot.connector == 'tg'

      raise "Unknown connector #{bot.connector} for #{bot.name}" unless connector_klass

      connector_klass.new(bot.token, bot.name)
    end

    def yaml_load(file)
      YAML.safe_load(IO.read(file))
    end
  end
end
