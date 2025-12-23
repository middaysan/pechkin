require_relative '../app_settings'

module Pechkin
  module Command
    # Initialize pechkin.settings.yml with default values
    class InitSettings < Base
      DEFAULT_SETTINGS = <<~YAML
        # Pechkin settings file

        # Admin credentials for /admin panel.
        # These credentials are used ONLY for accessing the Admin UI.
        admin_user: admin
        admin_password: pass123
        
        # Secret key for session encryption. Highly recommended to set this
        # for multi-instance setups or to keep sessions after restart.
        # session_secret: some-long-random-string

        # Path to configuration directory. Default: current directory
        # config_dir: .

        # Port to listen on. Default: 9292
        # port: 9292
        
        # Host address to bind to. Default: 127.0.0.1
        # address: 127.0.0.1
        
        # Minimum number of threads for Puma server. Default: 5
        # min_threads: 5
        
        # Maximum number of threads for Puma server. Default: 20
        # max_threads: 20
        
        # Path to htpasswd file. If not specified pechkin.htpasswd will be looked up
        # in configuration directory.
        # htpasswd: pechkin.htpasswd
        
        # Path to log directory. If not specified will write to STDOUT.
        # log_dir: logs
        
        # Database configuration
        database:
          # Database adapter to use: sqlite3 or postgresql
          adapter: sqlite3
          
          # SQLite3 configuration
          sqlite3:
            adapter: sqlite3
            database: pechkin.sqlite3
            
          # PostgreSQL configuration
          postgresql:
            adapter: postgresql
            database: pechkin
            username: user
            password: password
            host: localhost
            port: 5432
      YAML

      def matches?
        options.init_settings
      end

      def execute
        filename = AppSettings::SETTINGS_FILE
        if File.exist?(filename)
          warn "File #{filename} already exists. Skipping."
        else
          File.write(filename, DEFAULT_SETTINGS)
          puts "Created #{filename} with default settings."
        end
      end
    end
  end
end
