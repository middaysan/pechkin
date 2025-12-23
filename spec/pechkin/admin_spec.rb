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
    # Configure session_secret for tests
    options.session_secret = 'a' * 64
    options.admin_user = 'admin'
    options.admin_password = 'pass123'
    Pechkin::AdminApp.set :show_exceptions, true
    Pechkin::AdminApp.set :raise_errors, true
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
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    get '/admin/bots'
    expect(last_response).to be_ok
    expect(last_response.body).to include('Bots')
  end

  it 'creates a new bot and reloads configuration' do
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    post '/admin/bots', bot: { name: 'testbot', token: 'token', connector: 'telegram' }
    expect(last_response.status).to eq(302)
    expect(Pechkin::DB::Bot.find_by_name('testbot')).not_to be_nil
    
    # Check if handler was updated
    expect(handler.channels).to be_empty # No channels yet
    
    # Now add a channel
    bot = Pechkin::DB::Bot.find_by_name('testbot')
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    post '/admin/channels', channel: { name: 'testchan', bot_id: bot.id, chat_ids: '#general' }
    expect(last_response.status).to eq(302)
    
    expect(handler.channels.key?('testchan')).to be_truthy
    expect(handler.channels['testchan'].chat_ids).to eq(['#general'])
  end

  it 'renders the views page' do
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    get '/admin/views'
    expect(last_response).to be_ok
    expect(last_response.body).to include('Views')
  end

  it 'creates a new view' do
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    post '/admin/views', view: { name: 'test.erb', content: 'Hello <%= name %>' }
    expect(last_response.status).to eq(302)
    expect(Pechkin::DB::View.find_by_name('test.erb')).not_to be_nil
  end

  it 'renders the connectors page and displays default ones' do
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    get '/admin/connectors'
    expect(last_response).to be_ok
    expect(last_response.body).to include('Connectors')
    expect(last_response.body).to include('telegram')
    expect(last_response.body).to include('slack')
  end

  it 'allows adding a new connector via UI' do
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    post '/admin/connectors', connector: { name: 'discord', connector_class: 'Pechkin::Connector::Discord' }
    expect(last_response.status).to eq(302)
    expect(Pechkin::DB::Connector.find_by_name('discord')).not_to be_nil
  end

  it 'sets a session secret' do
    expect(Pechkin::AdminApp.session_secret).not_to be_nil
  end

  it 'updates configuration timestamp when config is reloaded' do
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    initial_timestamp = Pechkin::DB.last_config_update_at
    post '/admin/bots', bot: { name: 'testbot2', token: 'token', connector: 'telegram' }
    expect(Pechkin::DB.last_config_update_at).to be > initial_timestamp
  end

  it 'renders the logs page' do
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    get '/admin/logs'
    expect(last_response).to be_ok
    expect(last_response.body).to include('Recent Request Logs')
  end

  it 'renders the users page' do
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    get '/admin/users'
    expect(last_response).to be_ok
    expect(last_response.body).to include('Users for Basic Auth')
  end

  it 'creates a new user with auto-generated password' do
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    post '/admin/users', user: { username: 'new_admin' }
    expect(last_response.status).to eq(302)
    
    user = Pechkin::DB::User.find_by_username('new_admin')
    expect(user).not_to be_nil
    expect(user.password.length).to eq(12)
  end

  it 'allows deleting a user' do
    user = Pechkin::DB::User.create!(username: 'to_delete', password: 'password')
    # Admin is already authorized in before block
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    post "/admin/users/#{user.id}/delete"
    expect(last_response.status).to eq(302)
    expect(Pechkin::DB::User.find_by_username('to_delete')).to be_nil
  end

  it 'allows editing a user password' do
    user = Pechkin::DB::User.create!(username: 'to_edit', password: 'old_password')
    header 'Authorization', "Basic #{Base64.strict_encode64('admin:pass123')}"
    post "/admin/users/#{user.id}", user: { username: 'to_edit', password: 'new_password' }
    expect(last_response.status).to eq(302)
    
    user.reload
    expect(user.password).to eq('new_password')
  end

  describe 'Authentication' do
    it 'redirects to login page when not authenticated' do
      header 'Authorization', nil
      get '/admin/bots'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to include('/admin/login')
    end

    it 'renders login page' do
      get '/admin/login'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Pechkin Login')
    end

    it 'allows logging in with correct credentials' do
      post '/admin/login', username: 'admin', password: 'pass123'
      puts last_response.body if last_response.status == 500
      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq('http://localhost/admin')
    end

    it 'fails logging in with incorrect credentials' do
      post '/admin/login', username: 'admin', password: 'wrong_password'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Invalid username or password')
    end

    it 'allows logging out' do
      post '/admin/login', username: 'admin', password: 'pass123'
      get '/admin/logout'
      expect(last_response.status).to eq(302)
      expect(last_response.location).to eq('http://localhost/admin/login')
    end
  end
end
