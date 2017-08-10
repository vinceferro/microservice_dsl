module MicroserviceDSL
  module Instrument
    def self.instrument(name, title = nil, body = nil, &block)
      if defined?(Appsignal)
        Appsignal.instrument(name, title, body) do
          block.call
        end
      else
        block.call
      end
    end
  end
end
