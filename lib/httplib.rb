require 'cgi'
require 'socket'

class MonopolyHTTPRequest
  attr_reader :method, :query_string, :version, :params, :port, :address, :path, :file
  def initialize(file, cgi_params, params, address, port)
    @file = file
    @cgi_params = cgi_params
    @params = params
    @address = address
    @port = port
    @method = @cgi_params['REQUEST_METHOD']
    @version = @cgi_params['HTTP_VERSION']
  end

  # def initialize(str, s)
  #   @source = str
  # 
  #   lines = str.split("\n")
  #   first = lines.shift
  #   @method, @path, @version = first.split
  #   @query_string = @path.sub(/^\/[^\?]+\??/, '')
  #   @file = @path.scan(/^\/([^\?]+)\??/).flatten.shift
  # 
  #   @headers = {}
  #   lines.each do |l| 
  #     key, value = l.split(": ")
  #     @headers[key] = value
  #   end
  #   
  #   @params = CGI::parse(@query_string)
  #   @params.each_pair { |key, val|  @params[key] = val[0] if (@params[key].length == 1) }
  #   @port, @address = Socket.unpack_sockaddr_in(s)
  # end
  
  def param str
    @params[str]
  end
  
  def header str
    @headers[str]
  end
end