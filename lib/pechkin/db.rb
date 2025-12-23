require 'active_record'
require 'sqlite3'
require 'json'

module Pechkin
  # Database module for Pechkin
  module DB
    def self.setup(options = nil)
      db_config = find_db_config(options)

      ActiveRecord::Base.establish_connection(db_config)

      create_schema unless ENV['PECHKIN_SKIP_AUTO_MIGRATION']
      sync_connectors
    end

    def self.find_db_config(options)
      # 1. From options (file settings)
      if options && options.database && options.database[:adapter]
        adapter_name = options.database[:adapter]
        config = options.database[adapter_name.to_sym] || {}
        config[:adapter] ||= adapter_name
        return config
      end

      # 2. From ENV
      return ENV['DATABASE_URL'] if ENV['DATABASE_URL']

      # 3. Default SQLite
      {
        adapter: 'sqlite3',
        database: ENV['PECHKIN_DB_PATH'] || File.join(Dir.pwd, 'pechkin.sqlite3')
      }
    end

    def self.sync_connectors
      # Synchronize connectors from Pechkin::Connector.list to DB
      Pechkin::Connector.list.each do |name, klass|
        connector = Connector.find_or_initialize_by(name: name)
        connector.connector_class = klass.name
        connector.save!
      end
    end

    def self.update_config_timestamp
      info = SystemInfo.first_or_initialize
      info.last_config_update_at = Time.now
      info.save!
    end

    def self.last_config_update_at
      SystemInfo.first&.last_config_update_at || Time.at(0)
    end

    def self.update_users_timestamp
      info = SystemInfo.first_or_initialize
      info.last_users_update_at = Time.now
      info.save!
    end

    def self.last_users_update_at
      SystemInfo.first&.last_users_update_at || Time.at(0)
    end

    def self.create_schema
      ActiveRecord::Schema.define do
        Pechkin::DB.create_bots_table(self)
        Pechkin::DB.create_views_table(self)
        Pechkin::DB.create_channels_table(self)
        Pechkin::DB.create_messages_table(self)
        Pechkin::DB.create_connectors_table(self)
        Pechkin::DB.create_request_logs_table(self)
        Pechkin::DB.create_system_info_table(self)
        Pechkin::DB.create_users_table(self)
      end
    end

    def self.create_users_table(schema)
      return if schema.table_exists?(:users)

      schema.create_table :users do |t|
        t.string :username, null: false
        t.string :password, null: false
        t.timestamps

        t.index :username, unique: true
      end
    end

    def self.create_system_info_table(schema)
      if schema.table_exists?(:system_info)
        unless schema.column_exists?(:system_info, :last_users_update_at)
          schema.add_column :system_info, :last_users_update_at, :datetime
        end
        return
      end

      schema.create_table :system_info do |t|
        t.datetime :last_config_update_at
        t.datetime :last_users_update_at
        t.timestamps
      end
    end

    def self.create_request_logs_table(schema)
      return if schema.table_exists?(:request_logs)

      schema.create_table :request_logs do |t|
        t.string :ip
        t.string :method
        t.string :path
        t.integer :status
        t.integer :body_size
        t.text :params
        t.timestamps
      end
    end

    def self.create_bots_table(schema)
      return if schema.table_exists?(:bots)

      schema.create_table :bots do |t|
        t.string :name, null: false
        t.string :token, null: false
        t.string :connector, null: false
        t.timestamps

        t.index :name, unique: true
      end
    end

    def self.create_views_table(schema)
      return if schema.table_exists?(:views)

      schema.create_table :views do |t|
        t.string :name, null: false
        t.text :content, null: false
        t.timestamps

        t.index :name, unique: true
      end
    end

    def self.create_channels_table(schema)
      return if schema.table_exists?(:channels)

      schema.create_table :channels do |t|
        t.string :name, null: false
        t.string :chat_ids, null: false
        t.references :bot, foreign_key: true, null: false
        t.timestamps

        t.index :name, unique: true
      end
    end

    def self.create_messages_table(schema)
      return if schema.table_exists?(:messages)

      schema.create_table :messages do |t|
        t.references :channel, foreign_key: true, null: false
        t.references :view, foreign_key: true, null: true
        t.string :name, null: false
        t.text :variables
        t.text :filters
        t.text :config
        t.timestamps

        t.index %i[channel_id name], unique: true
      end
    end

    def self.create_connectors_table(schema)
      return if schema.table_exists?(:connectors)

      schema.create_table :connectors do |t|
        t.string :name, null: false
        t.string :connector_class, null: false
        t.timestamps

        t.index :name, unique: true
      end
    end

    # Base model for Pechkin DB
    class Bot < ActiveRecord::Base
      has_many :channels, dependent: :destroy

      def self.find_by_name(name)
        where(arel_table[:name].eq(name)).first
      end
    end

    # View model for Pechkin DB
    class View < ActiveRecord::Base
      has_many :messages, dependent: :nullify
      has_many :channels, through: :messages

      def self.find_by_name(name)
        where(arel_table[:name].eq(name)).first
      end
    end

    # Channel model for Pechkin DB
    class Channel < ActiveRecord::Base
      belongs_to :bot
      has_many :messages, dependent: :destroy
      has_many :views, through: :messages

      def self.find_by_name(name)
        where(arel_table[:name].eq(name)).first
      end

      def chat_ids_array
        JSON.parse(chat_ids)
      rescue StandardError
        [chat_ids]
      end
    end

    # Message model for Pechkin DB
    class Message < ActiveRecord::Base
      belongs_to :channel
      belongs_to :view

      def variables_hash
        JSON.parse(variables || '{}')
      rescue StandardError
        {}
      end

      def filters_array
        JSON.parse(filters || '[]')
      rescue StandardError
        []
      end

      def config_hash
        JSON.parse(config || '{}')
      rescue StandardError
        {}
      end
    end

    # Connector model for Pechkin DB
    class Connector < ActiveRecord::Base
      def self.find_by_name(name)
        where(arel_table[:name].eq(name)).first
      end
    end

    # RequestLog model for Pechkin DB
    class RequestLog < ActiveRecord::Base
      def params_hash
        JSON.parse(params || '{}')
      rescue StandardError
        {}
      end
    end

    # SystemInfo model for Pechkin DB
    class SystemInfo < ActiveRecord::Base
      self.table_name = 'system_info'
    end

    # User model for Pechkin DB
    class User < ActiveRecord::Base
      validates :username, presence: true, uniqueness: true
      validates :password, presence: true

      def self.find_by_username(username)
        where(arel_table[:username].eq(username)).first
      end
    end
  end
end
