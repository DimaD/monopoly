require 'mongrel'
require 'httplib'

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

      pa = req.params
      params = HttpRequest.query_parse( pa['QUERY_STRING'] );
      file = pa['REQUEST_PATH'].sub("/", "")
      port, address = Socket.unpack_sockaddr_in(req.socket.getsockname)
      r = MonopolyHTTPRequest.new( file, pa, params, address, port )

      response res, n.process( r )
    end

    def response res, result
      res.start(result[0]) do |head, out|
        result[1].each_pair { |name, val| head[name] = val }
        out.write( result[2] )
      end
    end
  end
end