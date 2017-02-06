require "microservice_dsl/version"
require "typhoeus"

module Kernel
  private

  def prepare_microservice_request(microservice, args = {})
    raise ArgumentError unless microservice

    url = ENV["#{microservice.upcase}_URL"] || "http://#{microservice}.#{ENV['MS_DOMAIN'] || Rails.env}:#{ENV["MS_#{microservice.upcase}_PORT"] || '3000'}"
    url << "/#{args[:path]}" if args[:path]
    body = (args[:body].is_a? String) ? args[:body] : args[:body].to_json if args[:body]
    Typhoeus::Request.new(url, method: args[:method] || :get, headers: MicroserviceDSL.default_headers.merge(args[:headers] || {}).merge({MicroserviceDSL.hop_header => MicroserviceDSL.hop_string}), body: body, params: args[:params], timeout: ENV['MS_DEFAULT_TIMEOUT'] || 10)
  end

  def call_microservice(microservice, args={})
    request = prepare_microservice_request microservice, args
    response = request.run
    [response.body, response.headers['content-type'], response.code]
  end
end

module MicroserviceDSL
  def self.hop_header
    "X-Hop-Count"
  end
  
  def self.rack_hop_header
    "HTTP_#{self.hop_header.upcase.gsub("-", "_")}"
  end
  
  def self.default_headers
    Thread.current[:microservice_dsl_default_headers] || {}
  end

  def self.default_headers=(headers = {})
    Thread.current[:microservice_dsl_default_headers] = headers
  end
  
  def self.current_hop=(hop)
    Thread.current[:microservice_dsl_current_hop] = hop
  end
  
  def self.current_hop
    Thread.current[:microservice_dsl_current_hop] = "1" unless Thread.current[:microservice_dsl_current_hop]
    Thread.current[:microservice_dsl_current_hop]
  end
  
  def self.next_hop=(hop)
    Thread.current[:microservice_dsl_next_hop] = hop
  end
  
  def self.next_hop
    Thread.current[:microservice_dsl_next_hop] = 0 unless Thread.current[:microservice_dsl_next_hop]
    Thread.current[:microservice_dsl_next_hop] += 1
  end
  
  def self.hop_string
    [self.current_hop, self.next_hop].join(".")
  end
end

