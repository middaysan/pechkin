require 'active_record'
require 'sqlite3'
require 'json'

module Pechkin
  # Database module for Pechkin
  module DB
    def self.setup
      db_config = ENV['DATABASE_URL'] || {
        adapter: 'sqlite3',
        database: ENV['PECHKIN_DB_PATH'] || File.join(Dir.pwd, 'pechkin.sqlite3')
      }

      ActiveRecord::Base.establish_connection(db_config)

      create_schema
    end

    def self.create_schema
      ActiveRecord::Schema.define do
        Pechkin::DB.create_bots_table(self)
        Pechkin::DB.create_views_table(self)
        Pechkin::DB.create_channels_table(self)
        Pechkin::DB.create_messages_table(self)
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
  end
end
