module Pechkin
  # Backup module for Pechkin database
  module Backup
    class << self
      def manager
        @manager ||= Manager.new
      end

      def add_recipient(recipient)
        manager.add_recipient(recipient)
      end

      def perform_backup
        manager.perform_backup
      end
    end

    # Manager coordinates the backup process
    class Manager
      attr_reader :recipients

      def initialize
        @recipients = []
      end

      def add_recipient(recipient)
        @recipients << recipient
      end

      def perform_backup
        db_path = database_path
        return nil unless db_path && File.exist?(db_path)

        results = {}
        @recipients.each do |recipient|
          results[recipient.class.name] = recipient.backup(db_path)
        end
        results
      end

      def database_path
        config = ActiveRecord::Base.connection_db_config.configuration_hash
        return config[:database] if config[:adapter] == 'sqlite3'

        nil
      rescue ActiveRecord::ConnectionNotEstablished
        nil
      end
    end

    # Base class for backup recipients
    class BaseRecipient
      def backup(_file_path)
        raise NotImplementedError
      end
    end
  end
end
