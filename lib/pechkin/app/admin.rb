require 'sinatra/base'
require 'json'
require 'securerandom'
require_relative '../db'

module Pechkin
  class AdminApp < Sinatra::Base
    set :views, File.join(File.dirname(__FILE__), 'views')
    set :public_folder, File.join(File.dirname(__FILE__), 'public')

    configure :test do
      disable :host_authorization
    end

    helpers do
      def handler
        settings.handler
      end

      def configuration
        settings.configuration
      end

      def request_logger
        settings.request_logger
      end

      def log_dir
        settings.log_dir
      end

      def user_manager
        settings.user_manager
      end

      def reload_config
        configuration.reload
        handler.update(configuration.channels)
        DB.update_config_timestamp
      end

      def sync_users
        DB.update_users_timestamp
        user_manager.sync
      end

      def admin_user
        settings.admin_user
      end

      def admin_password
        settings.admin_password
      end
    end

    get '/login' do
      erb :login, layout: :layout
    end

    post '/login' do
      if params[:username] == admin_user && params[:password] == admin_password
        session[:admin_auth] = true
        redirect '/admin'
      else
        @error = 'Invalid username or password'
        erb :login, layout: :layout
      end
    end

    get '/logout' do
      session.delete(:admin_auth)
      redirect '/admin/login'
    end

    get '/' do
      redirect '/admin/bots'
    end

    # Logs
    get '/logs' do
      @logs = RequestLogger.recent_logs
      erb :logs_index
    end

    # Users
    get '/users' do
      @users = DB::User.all
      erb :users_index
    end

    get '/users/new' do
      @user = DB::User.new
      erb :user_form
    end

    get '/users/:id/edit' do
      @user = DB::User.find(params[:id])
      erb :user_form
    end

    post '/users' do
      @user = DB::User.new(params[:user])
      @user.password = UserManager.generate_password if @user.username && !@user.username.empty?

      if @user.save
        sync_users
        redirect '/admin/users'
      else
        erb :user_form
      end
    end

    post '/users/:id' do
      @user = DB::User.find(params[:id])
      if @user.update(params[:user])
        sync_users
        redirect '/admin/users'
      else
        erb :user_form
      end
    end

    post '/users/:id/delete' do
      DB::User.find(params[:id]).destroy
      sync_users
      redirect '/admin/users'
    end

    # Bots
    get '/bots' do
      @bots = DB::Bot.all
      erb :bots_index
    end

    get '/bots/new' do
      @bot = DB::Bot.new
      @connectors = DB::Connector.all
      erb :bot_form
    end

    post '/bots' do
      @bot = DB::Bot.new(params[:bot])
      if @bot.save
        reload_config
        redirect '/admin/bots'
      else
        @connectors = DB::Connector.all
        erb :bot_form
      end
    end

    get '/bots/:id/edit' do
      @bot = DB::Bot.find(params[:id])
      @connectors = DB::Connector.all
      erb :bot_form
    end

    post '/bots/:id' do
      @bot = DB::Bot.find(params[:id])
      if @bot.update(params[:bot])
        reload_config
        redirect '/admin/bots'
      else
        @connectors = DB::Connector.all
        erb :bot_form
      end
    end

    post '/bots/:id/delete' do
      DB::Bot.find(params[:id]).destroy
      reload_config
      redirect '/admin/bots'
    end

    # Connectors
    get '/connectors' do
      @connectors = DB::Connector.all
      erb :connectors_index
    end

    get '/connectors/new' do
      @connector = DB::Connector.new
      erb :connector_form
    end

    post '/connectors' do
      @connector = DB::Connector.new(params[:connector])
      if @connector.save
        redirect '/admin/connectors'
      else
        erb :connector_form
      end
    end

    get '/connectors/:id/edit' do
      @connector = DB::Connector.find(params[:id])
      erb :connector_form
    end

    post '/connectors/:id' do
      @connector = DB::Connector.find(params[:id])
      if @connector.update(params[:connector])
        redirect '/admin/connectors'
      else
        erb :connector_form
      end
    end

    post '/connectors/:id/delete' do
      DB::Connector.find(params[:id]).destroy
      redirect '/admin/connectors'
    end

    # Views
    get '/views' do
      @views = DB::View.all
      erb :views_index
    end

    get '/views/new' do
      @view = DB::View.new
      erb :view_form
    end

    post '/views' do
      @view = DB::View.new(params[:view])
      if @view.save
        reload_config
        redirect '/admin/views'
      else
        erb :view_form
      end
    end

    get '/views/:id/edit' do
      @view = DB::View.find(params[:id])
      erb :view_form
    end

    post '/views/:id' do
      @view = DB::View.find(params[:id])
      if @view.update(params[:view])
        reload_config
        redirect '/admin/views'
      else
        erb :view_form
      end
    end

    post '/views/:id/delete' do
      DB::View.find(params[:id]).destroy
      reload_config
      redirect '/admin/views'
    end

    # Channels
    get '/channels' do
      @channels = DB::Channel.all
      erb :channels_index
    end

    get '/channels/new' do
      @channel = DB::Channel.new
      @bots = DB::Bot.all
      erb :channel_form
    end

    post '/channels' do
      # chat_ids comes as string, we might want to store it as JSON array
      @channel = DB::Channel.new(params[:channel])
      if @channel.save
        reload_config
        redirect '/admin/channels'
      else
        @bots = DB::Bot.all
        erb :channel_form
      end
    end

    get '/channels/:id/edit' do
      @channel = DB::Channel.find(params[:id])
      @bots = DB::Bot.all
      erb :channel_form
    end

    post '/channels/:id' do
      @channel = DB::Channel.find(params[:id])
      if @channel.update(params[:channel])
        reload_config
        redirect '/admin/channels'
      else
        @bots = DB::Bot.all
        erb :channel_form
      end
    end

    post '/channels/:id/delete' do
      DB::Channel.find(params[:id]).destroy
      reload_config
      redirect '/admin/channels'
    end

    # Messages
    get '/channels/:channel_id/messages/new' do
      @channel = DB::Channel.find(params[:channel_id])
      @message = DB::Message.new(channel: @channel)
      @views = DB::View.all
      erb :message_form
    end

    post '/channels/:channel_id/messages' do
      @channel = DB::Channel.find(params[:channel_id])
      @message = DB::Message.new(params[:message].merge(channel: @channel))
      if @message.save
        reload_config
        redirect '/admin/channels'
      else
        @views = DB::View.all
        erb :message_form
      end
    end

    get '/messages/:id/edit' do
      @message = DB::Message.find(params[:id])
      @channel = @message.channel
      @views = DB::View.all
      erb :message_form
    end

    post '/messages/:id' do
      @message = DB::Message.find(params[:id])
      if @message.update(params[:message])
        reload_config
        redirect '/admin/channels'
      else
        @channel = @message.channel
        @views = DB::View.all
        erb :message_form
      end
    end

    post '/messages/:id/delete' do
      msg = DB::Message.find(params[:id])
      msg.destroy
      reload_config
      redirect '/admin/channels'
    end

    # Migration
    get '/migration' do
      @file_config = Configuration.load_only_from_files(configuration.working_dir)
      erb :migration
    end

    post '/migration/import' do
      file_config = Configuration.load_only_from_files(configuration.working_dir)

      DB::Bot.transaction do
        # 1. Bots
        file_config.bots.each do |name, bot_data|
          db_bot = DB::Bot.find_or_initialize_by(name: name)
          db_bot.update!(token: bot_data.token, connector: bot_data.connector)
        end

        # 2. Views
        file_config.views.each do |name, template|
          db_view = DB::View.find_or_initialize_by(name: name)
          db_view.update!(content: template.raw_template)
        end

        # 3. Channels and Messages
        file_config.channels.each do |channel_name, channel_data|
          db_bot = DB::Bot.find_by(name: channel_data.connector.name)
          db_channel = DB::Channel.find_or_initialize_by(name: channel_name)
          db_channel.update!(
            bot: db_bot,
            chat_ids: channel_data.chat_ids.to_json
          )

          channel_data.messages.each do |msg_name, msg_obj|
            msg_data = msg_obj.to_h
            db_view = nil
            if msg_data['template'].is_a?(MessageTemplate)
              # We need to find the view name.
              # In file_config.views we have name -> template mapping.
              view_name = file_config.views.find do |_, v|
                v.raw_template == msg_data['template'].raw_template
              end&.first
              db_view = DB::View.find_by(name: view_name) if view_name
            end

            db_msg = DB::Message.find_or_initialize_by(channel: db_channel, name: msg_name)

            variables = msg_data.delete('variables') || {}
            filters = msg_data.delete('filters') || []
            msg_data.delete('template') # Already handled

            db_msg.update!(
              view: db_view,
              variables: variables.to_json,
              filters: filters.to_json,
              config: msg_data.to_json
            )
          end
        end
      end

      reload_config
      redirect '/admin/migration'
    end

    # Backup
    get '/backup' do
      @backup_results = session.delete(:backup_results)
      erb :backup
    end

    post '/backup/run' do
      session[:backup_results] = Backup.perform_backup
      redirect '/admin/backup'
    end

    get '/backup/download' do
      db_path = Backup.manager.database_path

      if db_path && File.exist?(db_path)
        send_file db_path, filename: File.basename(db_path), type: 'application/x-sqlite3'
      else
        status 404
        'Database file not found or not using SQLite.'
      end
    end
  end
end
