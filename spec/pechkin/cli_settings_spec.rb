require 'spec_helper'
require 'pechkin/cli'

describe Pechkin::CLI do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:settings_file) { File.join(tmp_dir, 'pechkin.settings.yml') }

  before do
    allow(Dir).to receive(:pwd).and_return(tmp_dir)
  end

  after do
    FileUtils.remove_entry(tmp_dir)
  end

  it 'prefers CLI arguments over file settings' do
    File.write(settings_file, <<~YAML)
      port: 1234
      bind_address: 0.0.0.0
    YAML

    options = Pechkin::CLI.parse(['--port', '5678'])
    expect(options.port).to eq(5678)
    expect(options.bind_address).to eq('0.0.0.0')
  end

  it 'uses file settings if CLI arguments are missing' do
    File.write(settings_file, <<~YAML)
      port: 1234
    YAML

    options = Pechkin::CLI.parse([])
    expect(options.port).to eq(1234)
    expect(options.bind_address).to eq('127.0.0.1') # Default
  end

  it 'supports database settings in file' do
    File.write(settings_file, <<~YAML)
      database:
        adapter: postgresql
        postgresql:
          url: postgres://localhost/db
    YAML

    options = Pechkin::CLI.parse([])
    expect(options.database[:adapter]).to eq('postgresql')
    expect(options.database[:postgresql][:url]).to eq('postgres://localhost/db')
  end
end
