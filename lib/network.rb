require 'game_state'
require 'exceptions'
require 'httplib'
require 'yaml'

module Monopoly

  class Network
    def initialize
      @methods = YAML.load( File.new( File.dirname(__FILE__) + "/../conf/methods.yml" ) )
    end
    
    def process request
      puts ">>> connection from #{request.address}:#{request.port} => #{request.path} : #{request.file}"
      return error404() unless allowed_method( request.file )
    end

    def ok
      "HTTP/1.1 200 OK\nContent-Type: text/plain\n\nOK\n"
    end
    
    def error404
      "HTTP/1.1 404 Not Found\nContent-Type: text/plain\n\nOK\n"
    end
    
    def allowed_method m
      @methods[m].nil?
    end
  end

end