module MicroserviceDSL
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      if env[MicroserviceDSL.rack_hop_header] && !env[MicroserviceDSL.rack_hop_header].blank?
        MicroserviceDSL.current_hop = env[MicroserviceDSL.rack_hop_header]
      else
        MicroserviceDSL.current_hop = "1"
      end
      MicroserviceDSL.next_hop = 0
      
      @app.call(env)
    end
  end
end