require 'game_state'
require 'exceptions'
require 'httplib'
require 'yaml'
require 'json'
require 'core'
require 'net/http'

module Monopoly

  class Network
    attr_reader :players

    def initialize core
      @players = {}
      @core = core
      @methods = YAML.load( File.new( File.dirname(__FILE__) + "/../conf/methods.yml" ) )
    end

    def self.connect_to_server address, name
      js = Request.join( "http://#{address}", name )
      core = Monopoly::Core.new( :json => js["Join"]["Rules"], :state => js["Join"]["State"] )
      return [core, Network.new(core) ]
    end

    def process request
      puts ">>> connection from #{request.address}:#{request.port} => #{request.path} : #{request.file}"
      begin
        return error404 unless @core.allowed_method?( request.file )
        return error_params unless @core.valid_params?( request.file, convert_params(request.file, request.params) )  

        method_name = request.file.underscore
        if respond_to?(method_name, request)
          send(method_name, request)
        elsif @core.respond_to?(method_name)
          @core.send( method_name, request.params )
        else
          error500 "No method #{method}"
        end
      rescue Exception => e
        return error500(e.message)
      end
    end

    def join req
      pl = @core.new_player( req.params['name'] )
      @players[req.address] = pl
      report_join pl.id
    end

    def report_join id
      [ 200, { "Content-Type" => 'application/javascript' },
        JSON.pretty_generate( { "Join" => { "ID" => id,"Rules" => @core.plain_rules, "State" => @core.state} } )
      ]
    end

    def ok
      [200, { "Content-Type" => 'text/plain' }, "OK\n"]
    end

    def error404
      [ 404, { "Content-Type" => 'text/plain' }, "404 Not Found\n"]
    end

    def error500 message=''
      [ 500, { "Content-Type" => 'text/plain' }, message]
    end

    def error_params
      [ 200, { "Content-Type" => 'application/javascript' },
        "{ 'Error' => { 'Code' => 200, 'Message' => 'wrong parameters' } }\n"
      ]
    end

    def convert_params method, params
      params.inject({}) do |memo, e|
        name, value = e
        memo[name] = convert_param method, name, value
        memo
      end
    end

    def convert_param method, name, value
      m = @methods[method]
      type = m[name] if m
      raise ArgumentError unless type

      case type
      when 'int'
        Integer( value )
      when 'string'
        value.to_s
      when /^int\[(\d+)..(\d+)\]$/
        to_integer( value, Integer($1), Integer($2) )
      when 'array[int]'
        to_array_int value
      else
        JSON.parse value
      end
    end

    def to_integer str, n1=0, n2=0
      i = Integer( str )
      raise ArgumentError if (n2 > 0) and (i < n1 or i > n2)
      raise ArgumentError if i < n1
    end

    def to_array_int str
      JSON.parse(str)
    end
  end

  class Request
    def self.join(address, name)
      uri = URI.parse(address)
      res = Net::HTTP.get(uri.host, '/Join?name=' + name, uri.port)
      raise RequestError if res.nil?

      js = JSON.parse(res)
      raise RequestError, js if self.error?(js)
      return js
    end

    def self.error? js
      js.has_key?("Error")
    end
  end
end