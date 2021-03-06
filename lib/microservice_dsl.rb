require 'microservice_dsl/version'
require 'microservice_dsl/instrument'
require 'typhoeus'
require 'json'
require 'digest'
require 'redis'

module Kernel
  private

  def prepare_microservice_request(microservice, args = {})
    raise ArgumentError unless microservice

    url = ENV["#{microservice.upcase}_URL"] || "http://#{microservice}.#{ENV['MS_DOMAIN'] || Rails.env}:#{ENV["MS_#{microservice.upcase}_PORT"] || '3000'}"
    url << "/#{args[:path]}" if args[:path]
    body = args[:body].is_a?(String) ? args[:body] : args[:body].to_json if args[:body]
    headers = MicroserviceDSL.default_headers.merge(args[:headers] || {}).merge(MicroserviceDSL.hop_header => MicroserviceDSL.hop_string)
    method = args[:method] || :get
    timeout = ENV['MS_DEFAULT_TIMEOUT'].try(:to_f) || 0
    timeout = 10 if timeout == 0
    req = Typhoeus::Request.new(url, method: method, headers: headers, body: body, params: args[:params], timeout: timeout)

    if method.to_s.casecmp('get').zero?
      req.on_complete do |res|
        if res.code == 200 && etag = res.headers['etag']
          MicroserviceDSL.set_cache(url, etag, res)
        end
      end
      if cached = MicroserviceDSL.get_cache(url, req)
        req.options[:headers]['If-None-Match'] = cached[:etag]
        req.on_complete do |res|
          if res.code == 304
            res.options[:response_body] = cached[:response][:body]
            res.options[:response_code] = cached[:response][:code]
            res.options[:headers] = Typhoeus::Response::Header.new(cached[:response][:headers])
          end
        end
      end

    end
    req
  end

  def call_microservice(microservice, args = {})
    request = prepare_microservice_request microservice, args
    response = nil
    MicroserviceDSL::Instrument.instrument('run.microservice_dsl', 'Call microservice', request.url) do
      response = request.run
    end
    [response.body, response.headers['content-type'], response.code]
  end
end

module MicroserviceDSL
  def self.redis_reset!
    @@redis = nil
  end

  def self.redis
    return nil unless caching?
    splitted = ENV['MS_CACHE_URL'].split(':')
    host = splitted[0]
    port = splitted[1] || '6379'
    @@redis ||= Redis.new(host: host, port: port)
  end

  def self.caching?
    if ENV['MS_CACHE_URL']
      true
    else
      false
    end
  end

  def self.set_cache(url, etag, res)
    return nil unless caching?
    puts "Etag: #{etag}"
    data = {
      etag: etag,
      response: {
        body: res.body,
        code: res.code,
        headers: res.headers
      }
    }
    puts data
    redis.set([redis_hash_name, cache_key(url, res.request)].join(':'), JSON.dump(data))
  end

  def self.cache_key(url, req)
    @@taggers ||= nil
    url = url.tr(':', '|')
    if @@taggers
      @@taggers.map { |t| Digest::MD5.hexdigest(req.options[:headers][t]) }.join('/') + '-' + url
    else
      url
    end
  end

  def self.get_etag(url, req)
    return nil unless caching?
    if val = get_cache(url, req)
      val[:etag]
    end
  end

  def self.has_cache?(url, etag, req)
    return nil unless caching?
    (stored_etag = get_etag(url, req)) && (stored_etag == etag) && stored_etag
  end

  def self.get_cache(url, req)
    return nil unless caching?
    if val = redis.get([redis_hash_name, cache_key(url, req)].join(':'))
      JSON.parse(val, symbolize_names: true)
    end
  end

  def self.redis_hash_name
    ENV['MS_CACHE_HASH'] || 'msdsl'
  end

  def self.cache_taggers=(taggers)
    raise unless taggers.is_a?(Array)
    @@taggers = taggers
  end

  def self.hop_header
    'X-Hop-Count'
  end

  def self.rack_hop_header
    "HTTP_#{hop_header.upcase.tr('-', '_')}"
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
    Thread.current[:microservice_dsl_current_hop] = '1' unless Thread.current[:microservice_dsl_current_hop]
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
    [current_hop, next_hop].join('.')
  end

  def self.hashable_string_for(obj)
    case obj
    when Hash
      hashable_string_for(obj.sort_by { |sub_obj| sub_obj.first.to_s })
    when Array
      obj.map { |sub_obj| hashable_string_for(sub_obj) }.to_s
    else
      obj.to_s
    end
  end
end

require 'microservice_dsl/railtie' if defined?(Rails)
