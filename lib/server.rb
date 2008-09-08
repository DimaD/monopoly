require 'rubygems'
require 'eventmachine'
require 'evma_httpserver'
require 'socket'
require 'cgi'
require 'httplib'

class MonopolyServer  < EventMachine::Connection
  def receive_data data
    s = get_sockname
    req = HTTPRequest.new(data, get_sockname)
    
    puts ">>> connection from #{req.address}:#{req.port} => #{req.query_string}"
    p req.params
    send_data data
    close_connection_after_writing
  end
end
