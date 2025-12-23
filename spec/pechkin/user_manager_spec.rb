require 'spec_helper'

describe Pechkin::UserManager do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:db_path) { File.join(tmp_dir, 'test.sqlite3') }
  
  before do
    ENV['PECHKIN_DB_PATH'] = db_path
    Pechkin::DB.setup
  end

  after do
    ActiveRecord::Base.remove_connection
    FileUtils.remove_entry(tmp_dir)
    ENV.delete('PECHKIN_DB_PATH')
  end

  subject { Pechkin::UserManager.new }

  it 'generates 12-character passwords' do
    expect(Pechkin::UserManager.generate_password.length).to eq(12)
    expect(Pechkin::UserManager.generate_password).not_to eq(Pechkin::UserManager.generate_password)
  end

  it 'authenticates users from DB' do
    Pechkin::DB::User.create!(username: 'testuser', password: 'testpassword')
    Pechkin::DB.update_users_timestamp
    
    expect(subject.authenticate('testuser', 'testpassword')).to be_truthy
    expect(subject.authenticate('testuser', 'wrongpassword')).to be_falsy
    expect(subject.authenticate('unknown', 'testpassword')).to be_falsy
  end

  it 'syncs cache when DB changes' do
    # Initial load
    expect(subject.authenticate('newuser', 'pass')).to be_falsy
    
    # Add user to DB
    Pechkin::DB::User.create!(username: 'newuser', password: 'pass')
    # Update timestamp to trigger sync
    Pechkin::DB.update_users_timestamp
    
    # Should now authenticate
    expect(subject.authenticate('newuser', 'pass')).to be_truthy
  end

  it 'handles multiple users' do
    Pechkin::DB::User.create!(username: 'u1', password: 'p1')
    Pechkin::DB::User.create!(username: 'u2', password: 'p2')
    Pechkin::DB.update_users_timestamp
    
    expect(subject.authenticate('u1', 'p1')).to be_truthy
    expect(subject.authenticate('u2', 'p2')).to be_truthy
  end
end
