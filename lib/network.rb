require 'game_state'
require 'exceptions'
require 'httplib'
require 'yaml'


module Monopoly

  class Network
    def initialize core
      @core = core
    end

    def process request
      puts ">>> connection from #{request.address}:#{request.port} => #{request.path} : #{request.file}"
      return error404 unless @core.allowed_method?( request.file )
      return error_params unless @core.valid_params?( request.file, request.params )

      return ok
    end

    def ok
      "HTTP/1.1 200 OK\nContent-Type: text/plain\n\nOK\n"
    end
    
    def error404
      "HTTP/1.1 404 Not Found\nContent-Type: text/plain\n\n404 Not Found"
    end

    def error_params
      "HTTP/1.1 200 OK\nContent-Type: application/javascript\n\n" +
      "{ 'Error' => { 'Code' => 200, 'Message' => 'wrong parameters' } }\n"
    end
  end

end