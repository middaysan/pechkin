require 'spec_helper'
require 'pechkin/app_settings'

describe Pechkin::AppSettings do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:settings_file) { File.join(tmp_dir, 'pechkin.settings.yml') }

  after do
    FileUtils.remove_entry(tmp_dir)
  end

  it 'returns empty hash if file does not exist' do
    expect(Pechkin::AppSettings.load(tmp_dir)).to eq({})
  end

  it 'loads settings from yaml file' do
    File.write(settings_file, <<~YAML)
      port: 1234
      address: 0.0.0.0
      database:
        adapter: postgresql
    YAML

    settings = Pechkin::AppSettings.load(tmp_dir)
    expect(settings[:port]).to eq(1234)
    expect(settings[:address]).to eq('0.0.0.0')
    expect(settings[:database][:adapter]).to eq('postgresql')
  end

  it 'returns empty hash if file is empty' do
    File.write(settings_file, '')
    expect(Pechkin::AppSettings.load(tmp_dir)).to eq({})
  end
end
