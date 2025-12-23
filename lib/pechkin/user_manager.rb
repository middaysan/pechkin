require 'securerandom'
require_relative 'db'

module Pechkin
  # Manages user authentication and caching
  class UserManager
    def initialize
      @users = {}
      @last_sync = Time.at(0)
      @mutex = Mutex.new
      sync
    end

    def sync
      last_update = DB.last_users_update_at
      return if @last_sync >= last_update

      @mutex.synchronize do
        # Double check after acquiring lock
        last_update = DB.last_users_update_at
        return if @last_sync >= last_update

        reload_cache
        @last_sync = last_update
      end
    end

    def authenticate(username, password)
      sync
      @mutex.synchronize do
        @users[username] == password
      end
    end

    def any_users?
      sync
      @mutex.synchronize do
        !@users.empty?
      end
    end

    def self.generate_password(length = 12)
      SecureRandom.alphanumeric(length)
    end

    private

    def reload_cache
      @users = DB::User.all.each_with_object({}) do |user, hash|
        hash[user.username] = user.password
      end
    end
  end
end
