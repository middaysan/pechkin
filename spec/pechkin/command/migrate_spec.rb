require 'spec_helper'

describe Pechkin::Command::Migrate do
  let(:options) { double('options', migrate?: true) }
  subject { Pechkin::Command::Migrate.new(options) }

  describe '#matches?' do
    it 'returns true if migrate? is true' do
      expect(subject.matches?).to be(true)
    end
  end

  describe '#execute' do
    it 'calls DB.setup and DB.create_schema' do
      expect(Pechkin::DB).to receive(:setup)
      expect(Pechkin::DB).to receive(:create_schema)
      expect { subject.execute }.to output(/Migrations finished successfully/).to_stderr
    end
  end
end
