require 'mongrel'
require 'httplib'
require 'json'

module Mongrel
  class HttpRequest
    attr_reader :socket
  end


  class MonopolyHandler < HttpHandler
    def initialize(*a, &block)
      @core_block = block
      super(*a)
    end

    def process req, res
      n = @core_block.call
      if n.nil?
        response res, [500, { 'Content-Type' => 'application/javascript' },
          '{ "Error" : { "Code" : 500, "Message" : "Server not ready" }}'
        ]
        return
      end

      begin
        pa = req.params
        params = HttpRequest.query_parse( pa['QUERY_STRING'] );
        file = pa['REQUEST_PATH'].sub("/", "")
        port, address = Socket.unpack_sockaddr_in(req.socket.getsockname)
        r = MonopolyHTTPRequest.new( file, pa, params, address, port )
        
        response res, n.process( r )
      rescue Exception => e
        response res, [ 500, { 'Content-Type' => 'text/plain'}, e.message ]
        p "Exception: #{e.message}"
        raise
      end
      
    end

    def response res, result
      res.start(result[0]) do |head, out|
        result[1].each_pair { |name, val| head[name] = val }
        out.write( result[0] == 500 ? json_error(result[2]) : result[2] )
      end
    end

    def json_error txt
      { 'Error' => { 'Code' => 500, 'Message' => txt } }.to_json
    end
  end
end