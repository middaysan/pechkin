require 'spec_helper'
require 'pechkin/db'
require 'pechkin/configuration'
require 'tmpdir'
require 'fileutils'

describe 'Database Integration' do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:db_path) { File.join(tmp_dir, 'test.sqlite3') }

  before do
    # Prepare disk config
    FileUtils.mkdir_p(File.join(tmp_dir, 'bots'))
    FileUtils.mkdir_p(File.join(tmp_dir, 'channels', 'test-channel'))
    FileUtils.mkdir_p(File.join(tmp_dir, 'views'))

    File.write(File.join(tmp_dir, 'bots', 'marvin.yml'),
               { 'token_env' => 'MARVIN_TOKEN', 'connector' => 'slack' }.to_yaml)
    File.write(File.join(tmp_dir, 'channels', 'test-channel', '_channel.yml'),
               { 'bot' => 'marvin', 'chat_ids' => '#general' }.to_yaml)
    ENV['MARVIN_TOKEN'] = 'disk-token'

    ENV['PECHKIN_DB_PATH'] = db_path
    Pechkin::DB.setup
  end

  after do
    ActiveRecord::Base.remove_connection
    FileUtils.remove_entry(tmp_dir)
    ENV.delete('PECHKIN_DB_PATH')
    ENV.delete('MARVIN_TOKEN')
  end

  it 'loads configuration from database and overwrites disk configuration' do
    # 1. Check disk config first (without DB data)
    config = Pechkin::Configuration.load_from_directory(tmp_dir)
    expect(config.bots['marvin']).not_to be_nil
    expect(config.bots['marvin'].token).to eq('disk-token')

    # 2. Add data to DB
    bot = Pechkin::DB::Bot.create!(name: 'marvin', token: 'db-token', connector: 'telegram')
    view = Pechkin::DB::View.create!(name: 'db_template.erb', content: 'DB Content: <%= message %>')
    channel = Pechkin::DB::Channel.create!(name: 'test-channel', bot: bot, chat_ids: ['12345'].to_json)
    Pechkin::DB::Message.create!(
      channel: channel,
      view: view,
      name: 'db_message',
      variables: { 'foo' => 'bar' }.to_json
    )

    # 3. Reload config
    config = Pechkin::Configuration.load_from_directory(tmp_dir)

    # Bot should be overwritten
    expect(config.bots['marvin'].token).to eq('db-token')
    expect(config.bots['marvin'].connector).to eq('telegram')

    # View should be added
    expect(config.views['db_template.erb']).not_to be_nil

    # Channel should be overwritten
    expect(config.channels['test-channel'].chat_ids).to eq(['12345'])

    # Message in channel should be present
    expect(config.channels['test-channel'].messages['db_message']).not_to be_nil
  end

  it 'handles complex message configurations with variables and filters' do
    bot = Pechkin::DB::Bot.create!(name: 'bender', token: 'bender-token', connector: 'slack')
    channel = Pechkin::DB::Channel.create!(name: 'bender-chan', bot: bot, chat_ids: ['#bender'].to_json)

    Pechkin::DB::Message.create!(
      channel: channel,
      name: 'complex_msg',
      variables: { 'author' => 'Bender' }.to_json,
      filters: ['message.match(/kill all humans/)'].to_json,
      config: { 'slack_attachments' => [] }.to_h.to_json
    )

    config = Pechkin::Configuration.load_from_directory(tmp_dir)
    msg = config.channels['bender-chan'].messages['complex_msg']

    expect(msg).not_to be_nil
    # Check if variables and filters are loaded into the Message object
    # We can check this by looking at the internal @message hash via to_h
    msg_hash = msg.to_h
    expect(msg_hash['variables']).to eq({ 'author' => 'Bender' })
    expect(msg_hash['filters']).to eq(['message.match(/kill all humans/)'])
    expect(msg_hash['slack_attachments']).to eq([])
  end
end
