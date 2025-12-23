require 'yaml'

module Pechkin
  # Application settings loader for pechkin.settings.yml
  class AppSettings
    SETTINGS_FILE = 'pechkin.settings.yml'.freeze

    def self.load_from_disk(working_dir = Dir.pwd)
      file = File.join(working_dir, SETTINGS_FILE)
      return {} unless File.exist?(file)

      content = File.read(file)
      return {} if content.strip.empty?

      YAML.safe_load(content, symbolize_names: true) || {}
    end
  end
end
