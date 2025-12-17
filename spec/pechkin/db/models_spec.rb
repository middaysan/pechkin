require 'spec_helper'
require 'pechkin/db'
require 'tmpdir'

describe 'Pechkin::DB Models' do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:db_path) { File.join(tmp_dir, 'test_models.sqlite3') }

  before do
    ENV['PECHKIN_DB_PATH'] = db_path
    Pechkin::DB.setup
  end

  after do
    ActiveRecord::Base.remove_connection
    FileUtils.remove_entry(tmp_dir)
    ENV.delete('PECHKIN_DB_PATH')
  end

  describe Pechkin::DB::Bot do
    it 'can be created and found by name' do
      Pechkin::DB::Bot.create!(name: 'marvin', token: 'secret', connector: 'telegram')
      bot = Pechkin::DB::Bot.find_by_name('marvin')
      expect(bot).not_to be_nil
      expect(bot.token).to eq('secret')
    end

    it 'has many channels' do
      bot = Pechkin::DB::Bot.create!(name: 'marvin', token: 'secret', connector: 'telegram')
      bot.channels.create!(name: 'chan1', chat_ids: '[]')
      bot.channels.create!(name: 'chan2', chat_ids: '[]')
      expect(bot.channels.count).to eq(2)
    end

    it 'deletes channels when deleted' do
      bot = Pechkin::DB::Bot.create!(name: 'marvin', token: 'secret', connector: 'telegram')
      bot.channels.create!(name: 'chan1', chat_ids: '[]')
      expect { bot.destroy }.to change(Pechkin::DB::Channel, :count).by(-1)
    end
  end

  describe Pechkin::DB::View do
    it 'can be created and found by name' do
      Pechkin::DB::View.create!(name: 'hello.erb', content: 'Hello!')
      view = Pechkin::DB::View.find_by_name('hello.erb')
      expect(view).not_to be_nil
      expect(view.content).to eq('Hello!')
    end

    it 'has many channels through messages' do
      bot = Pechkin::DB::Bot.create!(name: 'marvin', token: 'secret', connector: 'telegram')
      chan1 = bot.channels.create!(name: 'chan1', chat_ids: '[]')
      chan2 = bot.channels.create!(name: 'chan2', chat_ids: '[]')
      view = Pechkin::DB::View.create!(name: 'shared.erb', content: 'Shared')

      Pechkin::DB::Message.create!(name: 'msg1', channel: chan1, view: view)
      Pechkin::DB::Message.create!(name: 'msg2', channel: chan2, view: view)

      expect(view.channels.distinct.count).to eq(2)
      expect(chan1.views).to include(view)
      expect(chan2.views).to include(view)
    end
  end

  describe Pechkin::DB::Channel do
    let(:bot) { Pechkin::DB::Bot.create!(name: 'marvin', token: 'secret', connector: 'telegram') }

    it 'can be created and found by name' do
      Pechkin::DB::Channel.create!(name: 'chan1', chat_ids: '["#id1"]', bot: bot)
      chan = Pechkin::DB::Channel.find_by_name('chan1')
      expect(chan).not_to be_nil
      expect(chan.bot).to eq(bot)
    end

    describe '#chat_ids_array' do
      it 'parses JSON array' do
        chan = Pechkin::DB::Channel.new(chat_ids: '["#id1", "#id2"]')
        expect(chan.chat_ids_array).to eq(%w[#id1 #id2])
      end

      it 'returns single value in array if not JSON' do
        chan = Pechkin::DB::Channel.new(chat_ids: '#id1')
        expect(chan.chat_ids_array).to eq(['#id1'])
      end
    end
  end

  describe Pechkin::DB::Message do
    let(:bot) { Pechkin::DB::Bot.create!(name: 'marvin', token: 'secret', connector: 'telegram') }
    let(:chan) { Pechkin::DB::Channel.create!(name: 'chan1', chat_ids: '[]', bot: bot) }
    let(:view) { Pechkin::DB::View.create!(name: 'hello.erb', content: 'Hello!') }

    it 'belongs to channel and optionally to view' do
      msg = Pechkin::DB::Message.create!(name: 'msg1', channel: chan, view: view)
      expect(msg.channel).to eq(chan)
      expect(msg.view).to eq(view)

      msg2 = Pechkin::DB::Message.create!(name: 'msg2', channel: chan)
      expect(msg2.view).to be_nil
    end

    describe 'helper methods' do
      let(:msg) do
        Pechkin::DB::Message.new(
          variables: { 'a' => 1 }.to_json,
          filters: %w[foo bar].to_json,
          config: { 'key' => 'val' }.to_json
        )
      end

      it '#variables_hash returns parsed JSON' do
        expect(msg.variables_hash).to eq({ 'a' => 1 })
      end

      it '#filters_array returns parsed JSON' do
        expect(msg.filters_array).to eq(%w[foo bar])
      end

      it '#config_hash returns parsed JSON' do
        expect(msg.config_hash).to eq({ 'key' => 'val' })
      end

      it 'returns defaults on empty or invalid data' do
        empty_msg = Pechkin::DB::Message.new
        expect(empty_msg.variables_hash).to eq({})
        expect(empty_msg.filters_array).to eq([])
        expect(empty_msg.config_hash).to eq({})
      end
    end
  end
end
