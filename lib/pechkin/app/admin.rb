require 'sinatra/base'
require 'json'
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

      def reload_config
        configuration.reload
        handler.update(configuration.channels)
      end
    end

    get '/' do
      redirect '/admin/bots'
    end

    # Bots
    get '/bots' do
      @bots = DB::Bot.all
      erb :bots_index
    end

    get '/bots/new' do
      @bot = DB::Bot.new
      erb :bot_form
    end

    post '/bots' do
      @bot = DB::Bot.new(params[:bot])
      if @bot.save
        reload_config
        redirect '/admin/bots'
      else
        erb :bot_form
      end
    end

    get '/bots/:id/edit' do
      @bot = DB::Bot.find(params[:id])
      erb :bot_form
    end

    post '/bots/:id' do
      @bot = DB::Bot.find(params[:id])
      if @bot.update(params[:bot])
        reload_config
        redirect '/admin/bots'
      else
        erb :bot_form
      end
    end

    post '/bots/:id/delete' do
      DB::Bot.find(params[:id]).destroy
      reload_config
      redirect '/admin/bots'
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
        redirect "/admin/channels"
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
        redirect "/admin/channels"
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
      redirect "/admin/channels"
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
  end
end
