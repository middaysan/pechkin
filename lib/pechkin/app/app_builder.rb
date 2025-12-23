require_relative 'admin'
require_relative '../request_logger'
require_relative '../middlewares/favicon_stub'

module Pechkin
  # Application configurator and builder. This creates all needed middleware
  # and stuff
  class AppBuilder
    def build(handler, configuration, options)
      logger = create_logger(options.log_dir)
      request_logger = RequestLogger.new
      user_manager = UserManager.new

      session_secret = options.session_secret || ENV['PECHKIN_SESSION_SECRET'] || SecureRandom.hex(64)

      handler.logger = logger
      app = App.new(logger, request_logger)
      app.handler = handler
      app.configuration = configuration

      AdminApp.set :handler, handler
      AdminApp.set :configuration, configuration
      AdminApp.set :logger, logger
      AdminApp.set :request_logger, request_logger
      AdminApp.set :log_dir, options.log_dir
      AdminApp.set :user_manager, user_manager
      AdminApp.set :session_secret, session_secret
      AdminApp.set :admin_user, options.admin_user
      AdminApp.set :admin_password, options.admin_password

      prometheus = Pechkin::PrometheusUtils.registry

      Rack::Builder.app do
        use Rack::CommonLogger, logger
        use Pechkin::Middleware::FaviconStub
        use Rack::Session::Cookie, secret: session_secret, key: 'pechkin.session'
        use Rack::Deflater
        use Prometheus::Middleware::Collector, registry: prometheus
        # Add Auth check if found htpasswd file or it was excplicitly provided
        # See CLI class for configuration details
        use Pechkin::Auth::Middleware,
            auth_file: options.htpasswd,
            user_manager: user_manager,
            admin_user: options.admin_user,
            admin_password: options.admin_password,
            request_logger: request_logger
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
