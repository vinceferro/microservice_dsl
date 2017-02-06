require 'spec_helper'

describe MicroserviceDSL do
  let(:app) {Rails.application}
  it 'has a version number' do
    expect(MicroserviceDSL::VERSION).not_to be nil
  end
  
  it 'adds proper hop counter' do
    MicroserviceDSL.current_hop = "2.1"
    MicroserviceDSL.next_hop = 2
    
    req = prepare_microservice_request("service")
    
    expect(req.options[:headers][MicroserviceDSL.hop_header]).to eq("2.1.3")
    
    req = prepare_microservice_request("service")
    
    expect(req.options[:headers][MicroserviceDSL.hop_header]).to eq("2.1.4")
  end
  
  it 'uses default values for hop counter' do
    Thread.new do
      req = prepare_microservice_request("service")
    
      expect(req.options[:headers][MicroserviceDSL.hop_header]).to eq("1.1")
    
      req = prepare_microservice_request("service")
    
      expect(req.options[:headers][MicroserviceDSL.hop_header]).to eq("1.2")
    
      expect(MicroserviceDSL.current_hop).to eq("1")
      expect(MicroserviceDSL.next_hop).to eq("3")
    end
  end
end
