require 'open-uri'
require 'net/http'
require 'uri'
require 'json'
require 'cgi'

module Pechkin
  # Connector module
  module Connector
    @connectors = {}

    class << self
      def register(name, klass)
        @connectors[name.to_s] = klass
      end

      def list
        @connectors
      end
    end
  end
end

require_relative 'connector/base'
# Load all connectors
Dir[File.join(__dir__, 'connector', '*.rb')].each do |file|
  name = File.basename(file)
  next if name == 'base.rb'

  require_relative "connector/#{name}"
end
