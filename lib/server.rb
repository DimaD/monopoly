require 'rubygems'
require 'eventmachine'
require 'evma_httpserver'
require 'socket'
require 'cgi'
require 'httplib'
require 'core'
require 'network'

def core
  @core ||= Monopoly::Core.new(:save => 'default')
end

def monopoly
  @monopoly ||= Monopoly::Network.new( core )
end

class MonopolyServer  < EventMachine::Connection
  def receive_data data
    s = get_sockname
    req = HTTPRequest.new(data, get_sockname)
    
    send_data monopoly.process(req) || "HTTP/1.0 500\n"
    close_connection_after_writing
  end
end
