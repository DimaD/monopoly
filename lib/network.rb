require 'game_state'
require 'exceptions'
require 'httplib'
require 'yaml'


module Monopoly

  class Network
    attr_reader :maybe_players

    def initialize core
      @maybe_players = []
      @core = core
      @methods = YAML.load( File.new( File.dirname(__FILE__) + "/../conf/methods.yml" ) )
    end

    def process request
      puts ">>> connection from #{request.address}:#{request.port} => #{request.path} : #{request.file}"
      begin
        return error404 unless @core.allowed_method?( request.file )
        return error_params unless @core.valid_params?( request.file, convert_params(request.file, request.params) )  
      rescue Exception => e
        return error500(e.message)
      end

      method_name = request.file.underscore
      if respond_to?(method_name)
        send(method_name, request.params)
      elsif @core.respond_to?(method_name)
        @core.send( method_name, request.params )
      else
        error500 "No method #{method}"
      end
    end

    def join params
      @maybe_players << params['name']
      ok
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

end