require 'cgi'
require 'socket'

class HTTPRequest
  attr_reader :method, :query_string, :version, :params, :port, :address
  def initialize(str, s)
    @source = str

    lines = str.split("\n")
    first = lines.shift
    @method, @path, @version = first.split
    @query_string = @path.sub(/^[^\?]+\?/,'')
    
    @headers = {}
    lines.each do |l| 
      key, value = l.split(": ")
      @headers[key] = value
    end
    
    @params = CGI::parse(@query_string)
    
    @port, @address = Socket.unpack_sockaddr_in(s)
  end
  
  def param str
    @params[str]
  end
  
  def header str
    @headers[str]
  end
end