require 'game_state'
require 'exceptions'
require 'httplib'
require 'yaml'


module Monopoly

  class Network
    def initialize core
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

      return ok
    end

    def ok
      "HTTP/1.1 200 OK\nContent-Type: text/plain\n\nOK\n"
    end
    
    def error404
      "HTTP/1.1 404 Not Found\nContent-Type: text/plain\n\n404 Not Found"
    end

    def error500 message=''
      "HTTP/1.1 505 Server Error\nContent-Type: text/plain\n\n#{message}"
    end

    def error_params
      "HTTP/1.1 200 OK\nContent-Type: application/javascript\n\n" +
      "{ 'Error' => { 'Code' => 200, 'Message' => 'wrong parameters' } }\n"
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