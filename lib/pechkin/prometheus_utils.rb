module Pechkin
  module PrometheusUtils # :nodoc:
    class << self
      def registry
        registry = ::Prometheus::Client.registry
        
        register_gauge(registry, :pechkin_start_time_seconds, 'Startup timestamp')
          .set(Time.now.to_i)

        version_labels = { version: Pechkin::Version.version_string }
        register_gauge(registry, :pechkin_version, 'Pechkin version', labels: [:version])
          .set(1, labels: version_labels)

        registry
      end

      private

      def register_gauge(registry, name, docstring, labels: [])
        registry.get(name) || registry.gauge(name, docstring: docstring, labels: labels)
      rescue Prometheus::Client::Registry::AlreadyRegisteredError
        registry.get(name)
      end
    end
  end
end
