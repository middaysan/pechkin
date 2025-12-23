require_relative '../spec_helper'

describe Pechkin::Auth::Middleware do
  before(:all) do
    @htpasswd_file = Tempfile.new(['pechkin-', '.htpasswd'])
    @htpasswd_file.close
    Pechkin::Auth::Manager.new(@htpasswd_file.path).add('htuser', 'htuser')
  end

  let(:app) { double }
  let(:user_manager) { instance_double(Pechkin::UserManager) }
  let(:admin_user) { 'admin' }
  let(:admin_password) { 'pass123' }
  let(:middleware) do
    Pechkin::Auth::Middleware.new(app,
                                 auth_file: @htpasswd_file.path,
                                 user_manager: user_manager,
                                 admin_user: admin_user,
                                 admin_password: admin_password)
  end

  before do
    allow(user_manager).to receive(:authenticate).and_return(false)
    allow(user_manager).to receive(:any_users?).and_return(true)
  end

  context 'common failures' do
    let(:env) { { 'PATH_INFO' => '/foo/bar' } }

    it 'fails to authorize if Authorization header is missing' do
      code, _header, body = middleware.call(env)
      expect(code).to eq('401')
      expect(body.first)
        .to eq({ status: 'error', reason: 'Auth header is missing' }.to_json)
    end

    it 'fails to authorize if Authorization is not Basic' do
      env['HTTP_AUTHORIZATION'] = 'Bearer aoch7Ref5aiku7aM'
      code, _header, body = middleware.call(env)
      expect(code).to eq('401')
      expect(body.first)
        .to eq({ status: 'error', reason: 'Auth is not basic' }.to_json)
    end

    it 'fails to authorize if Auth header contains only user field' do
      auth = Base64.encode64('admin')
      env['HTTP_AUTHORIZATION'] = "Basic #{auth}"
      code, _header, body = middleware.call(env)
      expect(code).to eq('401')
      expect(body.first)
        .to eq({ status: 'error', reason: 'Password is missing' }.to_json)
    end
  end

  context 'when accessing /admin' do
    let(:env) { { 'PATH_INFO' => '/admin/bots' } }

    it 'authorizes with admin credentials' do
      auth = Base64.encode64("#{admin_user}:#{admin_password}")
      env['HTTP_AUTHORIZATION'] = "Basic #{auth}"
      expect(app).to receive(:call).with(env).and_return(['200', {}, 'OK'])
      expect(middleware.call(env)).to eq(['200', {}, 'OK'])
    end

    it 'fails with regular user credentials' do
      auth = Base64.encode64("htuser:htuser")
      env['HTTP_AUTHORIZATION'] = "Basic #{auth}"
      
      code, headers, _body = middleware.call(env)
      expect(code).to eq(302)
      expect(headers['Location']).to eq('/admin/login')
    end

    it 'sets session flag after successful authentication' do
      auth = Base64.strict_encode64("#{admin_user}:#{admin_password}")
      env['HTTP_AUTHORIZATION'] = "Basic #{auth}"
      session = {}
      env['rack.session'] = session
      
      expect(app).to receive(:call).and_return(['200', {}, 'OK'])
      middleware.call(env)
      
      expect(session[:admin_auth]).to be(true)
    end

    it 'authorizes using session flag without Authorization header' do
      env['rack.session'] = { admin_auth: true }
      expect(app).to receive(:call).and_return(['200', {}, 'OK'])
      
      code, _, _ = middleware.call(env)
      expect(code).to eq('200')
    end

    it 'fails with wrong admin password' do
      auth = Base64.encode64("#{admin_user}:wrong")
      env['HTTP_AUTHORIZATION'] = "Basic #{auth}"
      
      code, headers, _body = middleware.call(env)
      expect(code).to eq(302)
      expect(headers['Location']).to eq('/admin/login')
    end

    it 'handles passwords with colons correctly' do
      # Recreate middleware with a password containing a colon
      complex_password = 'pass:with:colons'
      mw = Pechkin::Auth::Middleware.new(app, admin_user: 'admin', admin_password: complex_password)
      
      auth = Base64.strict_encode64("admin:#{complex_password}")
      env['HTTP_AUTHORIZATION'] = "Basic #{auth}"
      
      expect(app).to receive(:call).and_return(['200', {}, 'OK'])
      code, _, _ = mw.call(env)
      expect(code).to eq('200')
    end
  end

  context 'when accessing webhooks' do
    let(:env) { { 'PATH_INFO' => '/mychan/mymsg' } }

    it 'authorizes with DB user' do
      auth = Base64.encode64("dbuser:dbpass")
      env['HTTP_AUTHORIZATION'] = "Basic #{auth}"
      expect(user_manager).to receive(:authenticate).with('dbuser', 'dbpass').and_return(true)
      expect(app).to receive(:call).with(env).and_return(['200', {}, 'OK'])
      expect(middleware.call(env)).to eq(['200', {}, 'OK'])
    end

    it 'authorizes with htpasswd user' do
      auth = Base64.encode64("htuser:htuser")
      env['HTTP_AUTHORIZATION'] = "Basic #{auth}"
      expect(app).to receive(:call).with(env).and_return(['200', {}, 'OK'])
      expect(middleware.call(env)).to eq(['200', {}, 'OK'])
    end

    it 'fails with admin credentials' do
      auth = Base64.encode64("#{admin_user}:#{admin_password}")
      env['HTTP_AUTHORIZATION'] = "Basic #{auth}"
      
      code, headers, body = middleware.call(env)
      expect(code).to eq('401')
      expect(headers).not_to have_key('WWW-Authenticate')
      expect(JSON.parse(body.first)['reason']).to include("Can't authenticate user")
    end

    it 'skips authorization if no users exist' do
      allow(user_manager).to receive(:any_users?).and_return(false)
      # We need to recreate middleware or clear its htpasswd cache
      mw = Pechkin::Auth::Middleware.new(app, user_manager: user_manager)
      
      expect(app).to receive(:call).with(env).and_return(['200', {}, 'OK'])
      expect(mw.call(env)).to eq(['200', {}, 'OK'])
    end
  end

  after(:all) do
    @htpasswd_file.unlink
  end
end
