require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'stringio'

describe Pechkin::Command::InitSettings do
  let(:options) { double('options', init_settings: true) }
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  subject { Pechkin::Command::InitSettings.new(options, stdout: stdout, stderr: stderr) }

  describe '#matches?' do
    it 'returns true if init_settings is true' do
      expect(subject.matches?).to be(true)
    end
  end

  describe '#execute' do
    let(:tmp_dir) { Dir.mktmpdir }
    let(:settings_file) { File.join(tmp_dir, 'pechkin.settings.yml') }

    before do
      # We need to stub the constant or change directory for the test
      allow(Pechkin::AppSettings).to receive(:const_get).with(:SETTINGS_FILE).and_return(settings_file)
      # Actually, InitSettings uses AppSettings::SETTINGS_FILE directly. 
      # Stubbing constants in Ruby is a bit tricky.
      # Let's try to change Dir.pwd or stub the filename in the execute method if possible.
      # But better to just stub the File.exist? and File.write if we want to be clean.
    end

    after do
      FileUtils.remove_entry(tmp_dir)
    end

    it 'creates a new settings file if it does not exist' do
      # Instead of stubbing constant, let's just use the real constant but make sure we don't overwrite project file.
      # We can use Dir.chdir inside the test.
      Dir.chdir(tmp_dir) do
        subject.execute
        expect(File.exist?('pechkin.settings.yml')).to be(true)
        expect(stdout.string).to include('Created')
        
        content = File.read('pechkin.settings.yml')
        expect(content).to include('database:')
        expect(content).to include('adapter: sqlite3')
      end
    end

    it 'skips creation if the file already exists' do
      Dir.chdir(tmp_dir) do
        File.write('pechkin.settings.yml', 'existing content')
        subject.execute
        expect(File.read('pechkin.settings.yml')).to eq('existing content')
        expect(stderr.string).to include('already exists')
      end
    end
  end
end
