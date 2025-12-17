require 'spec_helper'
require 'pechkin/backup'
require 'pechkin/db'
require 'tmpdir'
require 'fileutils'

describe Pechkin::Backup::Manager do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:db_path) { File.join(tmp_dir, 'test.sqlite3') }
  let(:manager) { Pechkin::Backup::Manager.new }

  before do
    ENV['PECHKIN_DB_PATH'] = db_path
    Pechkin::DB.setup
  end

  after do
    ActiveRecord::Base.remove_connection
    FileUtils.remove_entry(tmp_dir)
    ENV.delete('PECHKIN_DB_PATH')
  end

  it 'returns correct database path for sqlite' do
    expect(manager.database_path).to eq(db_path)
  end

  it 'returns nil if database file does not exist' do
    allow(File).to receive(:exist?).with(db_path).and_return(false)
    expect(manager.perform_backup).to be_nil
  end

  it 'executes backup for all recipients' do
    recipient = double('Recipient')
    expect(recipient).to receive(:backup).with(db_path).and_return(true)
    
    manager.add_recipient(recipient)
    results = manager.perform_backup
    
    expect(results).to eq({ recipient.class.name => true })
  end
end
