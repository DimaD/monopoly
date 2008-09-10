require 'cgi'
require 'socket'

class HTTPRequest
  attr_reader :method, :query_string, :version, :params, :port, :address, :path, :file
  def initialize(str, s)
    @source = str

    lines = str.split("\n")
    first = lines.shift
    @method, @path, @version = first.split
    @query_string = @path.sub(/^\/[^\?]+\??/, '')
    @file = @path.scan(/^\/?([^\?]+)\?/)

    @headers = {}
    lines.each do |l| 
      key, value = l.split(": ")
      @headers[key] = value
    end
    
    @params = CGI::parse(@query_string)
    @params.each_pair { |key, val|  @params[key] = val[0] if (@params[key].length == 1) }
    @port, @address = Socket.unpack_sockaddr_in(s)
  end
  
  def param str
    @params[str]
  end
  
  def header str
    @headers[str]
  end
end