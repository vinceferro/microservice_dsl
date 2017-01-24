require "microservice_dsl/version"
require "typhoeus"

module Kernel
  private

  def prepare_microservice_request(microservice, args = {})
    raise ArgumentError unless microservice

    url = ENV["#{microservice.upcase}_URL"] || "http://#{microservice}.#{ENV['MS_DOMAIN'] || Rails.env}:#{ENV["MS_#{microservice.upcase}_PORT"] || '3000'}"
    url << "/#{args[:path]}" if args[:path]
    body = (args[:body].is_a? String) ? args[:body] : args[:body].to_json if args[:body]
    Typhoeus::Request.new(url, method: args[:method] || :get, headers: MicroserviceDSL.default_headers, body: body, params: args[:params], timeout: ENV['MS_DEFAULT_TIMEOUT'] || 10)
  end

  def call_microservice(microservice, args={})
    request = prepare_microservice_request microservice, args
    response = request.run
    [response.body, response.headers['content-type'], response.code]
  end
end

module MicroserviceDSL
  def self.default_headers
    Thread.current[:default_headers] || {}
  end

  def self.default_headers=(headers = {})
    Thread.current[:default_headers] = headers
  end
end

