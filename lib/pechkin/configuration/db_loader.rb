module Pechkin
  # Loader for database configurations
  class DBLoader
    include ConfigurationLoader

    def load_configs(bots, views, channels, options = nil)
      DB.setup(options)
      load_bots(bots)
      load_views(views)
      load_channels(channels, bots, views)
    end

    private

    def load_bots(bots)
      DB::Bot.all.each do |db_bot|
        bots[db_bot.name] = Bot.new(
          token: db_bot.token,
          connector: db_bot.connector,
          name: db_bot.name
        )
      end
    end

    def load_views(views)
      DB::View.all.each do |db_view|
        views[db_view.name] = MessageTemplate.new(db_view.content)
      end
    end

    def load_channels(channels, bots, views)
      DB::Channel.all.each do |db_channel|
        bot_name = db_channel.bot.name
        bot = bots[bot_name]

        # We need to create connector as done in ConfigurationLoaderChannels
        connector = create_connector(bot)

        messages = load_messages(db_channel, views)

        channels[db_channel.name] = Channel.new(
          connector: connector,
          chat_ids: db_channel.chat_ids_array,
          messages: messages
        )
      end
    end

    def load_messages(db_channel, views)
      messages = {}
      db_channel.messages.each do |db_msg|
        message_config = db_msg.config_hash
        message_config['variables'] = db_msg.variables_hash
        message_config['filters'] = db_msg.filters_array

        message_config['template'] = views[db_msg.view.name] if db_msg.view

        messages[db_msg.name] = Message.new(message_config)
      end
      messages
    end
  end
end
