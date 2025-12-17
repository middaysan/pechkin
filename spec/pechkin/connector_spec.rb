require 'spec_helper'

describe Pechkin::Connector do
  it 'has registered telegram and slack connectors' do
    expect(Pechkin::Connector.list).to include('telegram')
    expect(Pechkin::Connector.list).to include('slack')
  end

  it 'registers new connectors' do
    class TestConnector < Pechkin::Connector::Base; end
    Pechkin::Connector.register('test', TestConnector)
    expect(Pechkin::Connector.list['test']).to eq(TestConnector)
  end
end
