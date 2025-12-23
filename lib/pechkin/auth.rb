module Pechkin
  module Auth
    class AuthError < StandardError; end

    # Utility class for altering htpasswd files
    class Manager
      attr_reader :htpasswd

      def initialize(htpasswd)
        @htpasswd = htpasswd
      end

      def add(user, password)
        m = File.exist?(htpasswd) ? HTAuth::File::ALTER : HTAuth::File::CREATE
        HTAuth::PasswdFile.open(htpasswd, m) do |f|
          f.add_or_update(user, password, 'md5')
        end
      end
    end

    # Auth middleware to check if provided auth can be found in .htpasswd file
    # or in the database via UserManager
    class Middleware
      attr_reader :htpasswd, :user_manager, :admin_user, :admin_password, :logger

      def initialize(app, auth_file: nil, user_manager: nil, admin_user: nil, admin_password: nil, request_logger: nil)
        @htpasswd = HTAuth::PasswdFile.open(auth_file) if auth_file && File.exist?(auth_file)
        @user_manager = user_manager
        @admin_user = admin_user
        @admin_password = admin_password
        @app = app
        @request_logger = request_logger
      end

      def call(env)
        authorize(env)
        @app.call(env)
      rescue AuthError => e
        path = env['PATH_INFO']
        if path.start_with?('/admin')
          ['302', { 'Location' => '/admin/login' }, []]
        else
          body = { status: 'error', reason: e.message }.to_json
          req = Rack::Request.new(env)
          # No WWW-Authenticate header for API requests
          @request_logger&.log(req, 401, body.to_json.size)
          ['401', { 'Content-Type' => 'application/json' }, [body]]
        end
      rescue StandardError => e
        body = { status: 'error', reason: e.message }.to_json
        ['503', { 'Content-Type' => 'application/json' }, [body]]
      end

      private

      def authorize(env)
        path = env['PATH_INFO']
        is_admin_path = path.start_with?('/admin')

        # 1. Check if we need to authorize at all
        if is_admin_path
          # Always allow access to /admin/login
          return if path == '/admin/login'

          # Check session first for admin panel
          session = env['rack.session']
          return if session && session[:admin_auth]

          # Admin path ALWAYS requires authorization if admin_user/password are set
          return unless admin_user && admin_password
        else
          # Regular paths require authorization only if there are users in DB or htpasswd
          return unless htpasswd || (user_manager && user_manager.any_users?)
        end

        auth = env['HTTP_AUTHORIZATION']
        raise AuthError, 'Auth header is missing' unless auth

        match = auth.match(/^Basic (.*)$/)
        raise AuthError, 'Auth is not basic' unless match

        user, password = *Base64.decode64(match[1]).split(':', 2)
        check_auth(env, user, password)
      end

      def check_auth(env, user, password)
        raise AuthError, 'User is missing' unless user

        raise AuthError, 'Password is missing' unless password

        path = env['PATH_INFO']
        if path.start_with?('/admin')
          if user == admin_user && password == admin_password
            # Set session flag for subsequent requests
            session = env['rack.session']
            session[:admin_auth] = true if session
            return
          end

          raise AuthError, 'Invalid admin credentials'
        end

        # Regular user check (DB + htpasswd)
        # 1. Try DB users via UserManager
        return if user_manager&.authenticate(user, password)

        # 2. Try htpasswd file
        if htpasswd
          e = htpasswd.fetch(user)
          if e
            return if e.authenticated?(password)
          end
        end

        raise AuthError, "Can't authenticate user '#{user}'"
      end
    end
  end
end
