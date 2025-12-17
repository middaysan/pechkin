require 'spec_helper'
require 'rack/test'

describe 'Migration' do
  include Rack::Test::Methods

  let(:tmp_dir) { Dir.mktmpdir }
  let(:db_path) { File.join(tmp_dir, 'test.sqlite3') }
  let(:options) { OpenStruct.new(config_dir: tmp_dir, log_dir: nil) }
  let(:configuration) { Pechkin::Configuration.load_from_directory(tmp_dir) }
  let(:handler) { Pechkin::Handler.new(configuration.channels) }
  let(:app) do
    registry = Prometheus::Client::Registry.new
    allow(Pechkin::PrometheusUtils).to receive(:registry).and_return(registry)
    Pechkin::AppBuilder.new.build(handler, configuration, options)
  end

  before do
    # Prepare files
    FileUtils.mkdir_p(File.join(tmp_dir, 'bots'))
    FileUtils.mkdir_p(File.join(tmp_dir, 'channels', 'test-channel'))
    FileUtils.mkdir_p(File.join(tmp_dir, 'views'))

    File.write(File.join(tmp_dir, 'bots', 'marvin.yml'),
               { 'token_env' => 'MARVIN_TOKEN', 'connector' => 'slack' }.to_yaml)
    File.write(File.join(tmp_dir, 'views', 'hello.erb'), 'Hello <%= name %>')
    File.write(File.join(tmp_dir, 'channels', 'test-channel', '_channel.yml'),
               { 'bot' => 'marvin', 'chat_ids' => '#general' }.to_yaml)
    File.write(File.join(tmp_dir, 'channels', 'test-channel', 'welcome.yml'),
               { 'template' => 'hello.erb', 'variables' => { 'name' => 'World' } }.to_yaml)
    
    ENV['MARVIN_TOKEN'] = 'secret'
    ENV['PECHKIN_DB_PATH'] = db_path
    Pechkin::DB.setup
    header 'Host', 'localhost'
  end

  after do
    ActiveRecord::Base.remove_connection
    FileUtils.remove_entry(tmp_dir)
    ENV.delete('PECHKIN_DB_PATH')
    ENV.delete('MARVIN_TOKEN')
  end

  it 'renders the migration page with file data' do
    get '/admin/migration'
    expect(last_response).to be_ok
    expect(last_response.body).to include('marvin')
    expect(last_response.body).to include('hello.erb')
    expect(last_response.body).to include('test-channel')
  end

  it 'imports data from files to database' do
    # Initially DB should be empty (except what might be in setup)
    expect(Pechkin::DB::Bot.count).to eq(0)
    expect(Pechkin::DB::View.count).to eq(0)
    expect(Pechkin::DB::Channel.count).to eq(0)

    post '/admin/migration/import'
    expect(last_response.status).to eq(302)

    expect(Pechkin::DB::Bot.find_by_name('marvin')).not_to be_nil
    expect(Pechkin::DB::Bot.find_by_name('marvin').token).to eq('secret')
    
    expect(Pechkin::DB::View.find_by_name('hello.erb')).not_to be_nil
    expect(Pechkin::DB::View.find_by_name('hello.erb').content).to eq('Hello <%= name %>')

    db_channel = Pechkin::DB::Channel.find_by_name('test-channel')
    expect(db_channel).not_to be_nil
    expect(db_channel.bot.name).to eq('marvin')
    expect(db_channel.chat_ids_array).to eq(['#general'])

    expect(db_channel.messages.find_by(name: 'welcome')).not_to be_nil
    msg = db_channel.messages.find_by(name: 'welcome')
    expect(msg.view.name).to eq('hello.erb')
    expect(msg.variables_hash).to eq({ 'name' => 'World' })
  end
end
