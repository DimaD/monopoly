require 'rubygems'
require 'eventmachine'
require 'evma_httpserver'
require 'socket'
require 'cgi'
require 'httplib'

class MonopolyServer  < EventMachine::Connection
  def receive_data data
    s = get_sockname
    port, address = Socket.unpack_sockaddr_in(s)
    puts ">>> connection from #{address}:#{port}"
    p data
    send_data data
    close_connection_after_writing
  end
end
