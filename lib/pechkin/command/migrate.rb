module Pechkin
  module Command
    # Run database migrations
    class Migrate < Base
      def matches?
        options.migrate?
      end

      def execute
        warn 'Running database migrations...'
        DB.setup(options)
        DB.create_schema
        warn 'Migrations finished successfully.'
      end
    end
  end
end
