require 'game_state'
require 'exceptions'
require 'httplib'

module Monopoly

  class Network

    def process request
      puts ">>> connection from #{request.address}:#{request.port} => #{request.path} : #{request.file}"
      return error404 unless 
    end

    def ok
      "HTTP/1.1 200 OK\nContent-Type: text/plain\n\nOK\n"
    end
  end

end