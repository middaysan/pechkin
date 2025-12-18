require_relative 'admin'
require_relative '../request_logger'

module Pechkin
  # Application configurator and builder. This creates all needed middleware
  # and stuff
  class AppBuilder
    def build(handler, configuration, options)
      logger = create_logger(options.log_dir)
      request_logger = RequestLogger.new
      
      handler.logger = logger
      app = App.new(logger, request_logger)
      app.handler = handler

      AdminApp.set :handler, handler
      AdminApp.set :configuration, configuration
      AdminApp.set :logger, logger
      AdminApp.set :request_logger, request_logger
      AdminApp.set :log_dir, options.log_dir

      prometheus = Pechkin::PrometheusUtils.registry

      Rack::Builder.app do
        use Rack::CommonLogger, logger
        use Rack::Deflater
        use Prometheus::Middleware::Collector, registry: prometheus
        # Add Auth check if found htpasswd file or it was excplicitly provided
        # See CLI class for configuration details
        use Pechkin::Auth::Middleware, auth_file: options.htpasswd if options.htpasswd
        use Prometheus::Middleware::Exporter, registry: prometheus

        map '/admin' do
          run AdminApp
        end

        run app
      end
    end

    private

    def create_logger(log_dir)
      if log_dir
        raise "Directory #{log_dir} does not exist" unless File.exist?(log_dir)

        log_file = File.join(log_dir, 'pechkin.log')
        file = File.open(log_file, File::WRONLY | File::APPEND)
        Logger.new(file)
      else
        Logger.new($stdout)
      end
    end
  end
end
