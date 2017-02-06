$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'microservice_dsl'
require 'webmock/rspec'
require 'rails'

class DummyApplication < ::Rails::Application
  config.eager_load      = false
  config.secret_key_base = SecureRandom.hex(30)
end
  
DummyApplication.initialize!
DummyApplication.routes.default_url_options[:host] = 'example.com'

RSpec.configure do |config|
  config.before(:each) do
    stub_request(:get, /.*\.test/).
      with(headers: {'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
      to_return(status: 200, body: '{"just": "some", "random": "data"}', headers: {})
  end
end