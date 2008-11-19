require 'rubygems'
require 'eventmachine'
require 'evma_httpserver'
require 'socket'
require 'cgi'
require 'httplib'
require 'core'
require 'network'

require File.dirname(__FILE__) + '/../core_extensions/extend'

def start_monopoly_server core, port=8080
  n = Monopoly::Network.new( core )
  t = Thread.new do
    ev = EventMachine::run {
      EventMachine.epoll
      EventMachine::start_server "localhost", port, MonopolyServer,  n
      puts "Start listening on port #{port} ..."
    }
  end
end

class MonopolyServer  < EventMachine::Connection
  def initialize(monopoly)
    @m = monopoly
  end

  def receive_data data
    s = get_sockname
    req = HTTPRequest.new(data, get_sockname)
    
    send_data @m.process(req) || "HTTP/1.0 500\n"
    close_connection_after_writing
  end
end
