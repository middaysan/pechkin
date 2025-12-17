require 'spec_helper'
require 'rack/test'

describe Pechkin::AdminApp do
  include Rack::Test::Methods

  let(:tmp_dir) { Dir.mktmpdir }
  let(:db_path) { File.join(tmp_dir, 'test.sqlite3') }
  let(:options) { OpenStruct.new(config_dir: tmp_dir, log_dir: nil) }
  let(:configuration) { Pechkin::Configuration.load_from_directory(tmp_dir) }
  let(:handler) { Pechkin::Handler.new(configuration.channels) }
  let(:app) do
    # Use a fresh registry for each test to avoid AlreadyRegisteredError
    registry = Prometheus::Client::Registry.new
    allow(Pechkin::PrometheusUtils).to receive(:registry).and_return(registry)
    Pechkin::AppBuilder.new.build(handler, configuration, options)
  end

  before do
    FileUtils.mkdir_p(File.join(tmp_dir, 'bots'))
    FileUtils.mkdir_p(File.join(tmp_dir, 'channels'))
    FileUtils.mkdir_p(File.join(tmp_dir, 'views'))
    ENV['PECHKIN_DB_PATH'] = db_path
    Pechkin::DB.setup
    header 'Host', 'localhost'
  end

  after do
    ActiveRecord::Base.remove_connection
    FileUtils.remove_entry(tmp_dir)
    ENV.delete('PECHKIN_DB_PATH')
  end

  it 'renders the bots page' do
    get '/admin/bots'
    expect(last_response).to be_ok
    expect(last_response.body).to include('Bots')
  end

  it 'creates a new bot and reloads configuration' do
    post '/admin/bots', bot: { name: 'testbot', token: 'token', connector: 'telegram' }
    expect(last_response.status).to eq(302)
    expect(Pechkin::DB::Bot.find_by_name('testbot')).not_to be_nil
    
    # Check if handler was updated
    expect(handler.channels).to be_empty # No channels yet
    
    # Now add a channel
    bot = Pechkin::DB::Bot.find_by_name('testbot')
    post '/admin/channels', channel: { name: 'testchan', bot_id: bot.id, chat_ids: '#general' }
    expect(last_response.status).to eq(302)
    
    expect(handler.channels.key?('testchan')).to be_truthy
    expect(handler.channels['testchan'].chat_ids).to eq(['#general'])
  end

  it 'renders the views page' do
    get '/admin/views'
    expect(last_response).to be_ok
    expect(last_response.body).to include('Views')
  end

  it 'creates a new view' do
    post '/admin/views', view: { name: 'test.erb', content: 'Hello <%= name %>' }
    expect(last_response.status).to eq(302)
    expect(Pechkin::DB::View.find_by_name('test.erb')).not_to be_nil
  end
end
