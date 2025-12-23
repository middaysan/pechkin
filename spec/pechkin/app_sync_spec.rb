require 'rack/test'
require_relative '../spec_helper'

describe Pechkin::App do
  include Rack::Test::Methods

  let(:logger) { double('logger').as_null_object }
  let(:app) { Pechkin::App.new(logger) }
  let(:handler) { double('handler') }
  let(:configuration) { double('configuration') }

  before(:each) do
    app.handler = handler
    app.configuration = configuration
    allow(configuration).to receive(:channels).and_return({})
  end

  context 'configuration synchronization' do
    it 'reloads configuration if DB timestamp is newer' do
      expect(Pechkin::DB).to receive(:last_config_update_at).and_return(Time.now)
      expect(configuration).to receive(:reload)
      expect(handler).to receive(:update).with(anything)
      expect(handler).to receive(:message?).and_return(false)
      expect(logger).to receive(:error) # because message? is false -> 404

      post '/a/b'
    end

    it 'does not reload configuration if DB timestamp is old' do
      # Initial sync
      allow(Pechkin::DB).to receive(:last_config_update_at).and_return(Time.at(100))
      expect(configuration).to receive(:reload).once
      expect(handler).to receive(:update).once
      expect(handler).to receive(:message?).and_return(false).twice
      
      post '/a/b'
      post '/a/b'
    end
  end
end
