require 'spec_helper'
require 'rack/test'

describe 'Admin Backup' do
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

  it 'renders the backup page' do
    get '/admin/backup'
    expect(last_response).to be_ok
    expect(last_response.body).to include('Database Backup')
    expect(last_response.body).to include('Download Database File')
  end

  it 'downloads the database file' do
    get '/admin/backup/download'
    expect(last_response).to be_ok
    expect(last_response.headers['Content-Type']).to eq('application/x-sqlite3')
    expect(last_response.headers['Content-Disposition']).to include('attachment')
    expect(last_response.headers['Content-Disposition']).to include('test.sqlite3')
  end

  it 'returns 404 if database is not sqlite' do
    # Mock database_path to return nil
    allow_any_instance_of(Pechkin::Backup::Manager).to receive(:database_path).and_return(nil)
    
    get '/admin/backup/download'
    expect(last_response.status).to eq(404)
  end

  it 'runs all backups' do
    recipient = double('Recipient')
    allow(recipient).to receive(:backup).and_return(true)
    Pechkin::Backup.add_recipient(recipient)

    post '/admin/backup/run'
    expect(last_response).to be_redirect
    follow_redirect!
    expect(last_response.body).to include('Success')
  end
end
