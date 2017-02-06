require 'microservice_dsl/middleware'

module MicroserviceDSL
  class Railtie < Rails::Railtie
    initializer 'microservice_dsl.hop_counter' do |app|
       app.middleware.insert_before ActionDispatch::RequestId, MicroserviceDSL::Middleware
    end
  end
end

