require 'spec_helper'
require 'pechkin/request_logger'
require 'pechkin/db'

describe Pechkin::RequestLogger do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:db_path) { File.join(tmp_dir, 'test.sqlite3') }
  let(:logger) { Pechkin::RequestLogger.new }

  before do
    ENV['PECHKIN_DB_PATH'] = db_path
    Pechkin::DB.setup
  end

  after do
    ActiveRecord::Base.remove_connection
    FileUtils.remove_entry(tmp_dir)
    ENV.delete('PECHKIN_DB_PATH')
  end

  describe '#log' do
    let(:req) do
      double('Rack::Request', 
        ip: '127.0.0.1', 
        request_method: 'POST', 
        path_info: '/channel/msg',
        post?: true,
        put?: false,
        body: StringIO.new('{"foo": "bar"}')
      )
    end

    it 'saves request details to the database' do
      expect { logger.log(req, 200, 15) }.to change { Pechkin::DB::RequestLog.count }.by(1)
      
      log = Pechkin::DB::RequestLog.last
      expect(log.ip).to eq('127.0.0.1')
      expect(log.method).to eq('POST')
      expect(log.path).to eq('/channel/msg')
      expect(log.status).to eq(200)
      expect(log.body_size).to eq(15)
      expect(log.params_hash).to eq({ 'foo' => 'bar' })
    end

    it 'cleans up old logs' do
      # Create 1000 logs
      1000.times do |i|
        Pechkin::DB::RequestLog.create!(
          ip: '1.1.1.1',
          method: 'POST',
          path: '/test',
          status: 200,
          body_size: 10,
          created_at: Time.now - (2000 - i).seconds
        )
      end

      expect(Pechkin::DB::RequestLog.count).to eq(1000)

      # Log one more
      logger.log(req, 200, 15)

      expect(Pechkin::DB::RequestLog.count).to eq(1000)
      expect(Pechkin::DB::RequestLog.order(created_at: :desc).first.ip).to eq('127.0.0.1')
    end
  end

  describe '.recent_logs' do
    it 'returns recent logs from the database' do
      Pechkin::DB::RequestLog.create!(ip: '1.1.1.1', method: 'GET', path: '/1', status: 200, body_size: 0, created_at: Time.now - 10)
      Pechkin::DB::RequestLog.create!(ip: '2.2.2.2', method: 'GET', path: '/2', status: 200, body_size: 0, created_at: Time.now)

      logs = Pechkin::RequestLogger.recent_logs
      expect(logs.size).to eq(2)
      expect(logs.first['ip']).to eq('2.2.2.2') # Descending order
      expect(logs.last['ip']).to eq('1.1.1.1')
    end
  end
end
