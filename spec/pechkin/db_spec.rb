require 'spec_helper'
require 'pechkin/db'

describe Pechkin::DB do
  describe '.setup' do
    before do
      allow(ActiveRecord::Schema).to receive(:define)
      allow(ActiveRecord::Base).to receive(:establish_connection)
      allow(Pechkin::DB).to receive(:sync_connectors)
    end

    after do
      ENV.delete('DATABASE_URL')
      ENV.delete('PECHKIN_DB_PATH')
    end

    it 'uses DATABASE_URL if present' do
      ENV['DATABASE_URL'] = 'postgres://localhost/mydb'
      Pechkin::DB.setup
      expect(ActiveRecord::Base).to have_received(:establish_connection).with('postgres://localhost/mydb')
    end

    it 'uses PECHKIN_DB_PATH if DATABASE_URL is missing' do
      ENV['PECHKIN_DB_PATH'] = '/path/to/db.sqlite3'
      Pechkin::DB.setup
      expect(ActiveRecord::Base).to have_received(:establish_connection).with(
        adapter: 'sqlite3',
        database: '/path/to/db.sqlite3'
      )
    end

    it 'uses default path if both env vars are missing' do
      expected_path = File.join(Dir.pwd, 'pechkin.sqlite3')
      Pechkin::DB.setup
      expect(ActiveRecord::Base).to have_received(:establish_connection).with(
        adapter: 'sqlite3',
        database: expected_path
      )
    end
  end
end
