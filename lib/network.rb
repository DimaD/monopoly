require 'game_state'
require 'exceptions'
require 'httplib'
require 'yaml'
require 'json'
require 'core'
require 'net/http'
require 'utils'
DEFAULT_PORT = 80

module Monopoly

  class Network
    attr_reader :players, :local_player, :local_port
    attr_writer :local_player

    def initialize core, local_port=DEFAULT_PORT
      @players = {}
      @core = core
      @local_port = DEFAULT_PORT
      @requester = Request.new( @local_port )
      @methods = YAML.load( File.new( File.dirname(__FILE__) + "/../conf/methods.yml" ) )
    end

    def self.connect_to_server address, name, local_port
      req = Request.new(local_port)
      js = req.join( "http://#{address}", name )
      core = Monopoly::Core.new( :json => js["Join"]["Rules"], :state => js["Join"]["State"] )
      n = Network.new(core, local_port)
      n.local_player = core.get_player( Integer(js["Join"]["Id"]) );

      players = req.get_players( "http://#{address}" )
      n.merge_players( _substitute_address(players['GetPlayers'], "#{address}"))
      return [core, n]
    end

    def process request
      puts ">>> connection from #{request.address}:#{request.port} => #{request.path} : #{request.file}"
      begin
        return error404 unless @core.allowed_method?( request.file )
        return error_params unless @core.valid_params?( request.file, convert_params(request.file, request.params) )  

        method_name = request.file.underscore
        if respond_to?(method_name, request)
          send(method_name, request)
        elsif @core.respond_to?(method_name)
          @core.send( method_name, request.params )
        else
          error500 "No method #{method}"
        end
      # rescue Exception => e
      #   return error500(e.message)
      end
    end

    def join req
      if @players["#{req.address}:#{req.port}"]
        report_player_exist
      else 
        pl = @core.new_player( req.params['name'] )
        @players["#{req.address}:#{req.port}"] = pl
        report_join pl.game_id
      end
    end

    def get_players req
      ret = [
        _serialize_player( @local_player, '-1' ),
        @players.map { |addr, pl| _serialize_player pl, addr }
      ].flatten
      report_players ret
    end

    def _serialize_player pl, addr
      { 
        "Id"    => pl.game_id,
        "Ip"    => addr,
        "Ready" => pl.ready,
        "Name"  => pl.name
      }
    end

    def new_local_player name
      return @local_player if @local_player
      @local_player = @core.new_player( name )
    end

    def merge_players pls
      pls.each do |e|
        unless Integer(e["Id"]) == @local_player.game_id
          @players[e["Ip"]] = @core.get_player_or_new(Integer(e["Id"]), e["Name"], e["Ready"])
        end
      end
    end

    def report_players pl
      [ 200, { "Content-Type" => 'application/javascript' },
        JSON.pretty_generate( { "GetPlayers" => pl} )
      ]
    end

    def report_player_exist
      [ 200, { "Content-Type" => 'application/javascript' },
        JSON.pretty_generate({
          'Error' => {
            'Code'  => 200,
            'Message' => 'player from this addresss already joined'
      }})]
    end

    def report_join id
      [ 200, { "Content-Type" => 'application/javascript' },
        JSON.pretty_generate( { "Join" => { "Id" => id,"Rules" => @core.plain_rules, "State" => @core.state} } )
      ]
    end

    def ok
      [200, { "Content-Type" => 'text/plain' }, "OK\n"]
    end

    def error404
      [ 404, { "Content-Type" => 'text/plain' }, "404 Not Found\n"]
    end

    def error500 message=''
      [ 500, { "Content-Type" => 'text/plain' }, message]
    end

    def error_params
      [ 200, { "Content-Type" => 'application/javascript' },
        "{ 'Error' => { 'Code' => 200, 'Message' => 'wrong parameters' } }\n"
      ]
    end

    def convert_params method, params
      params.inject({}) do |memo, e|
        name, value = e
        memo[name] = convert_param method, name, value
        memo
      end
    end

    def convert_param method, name, value
      m = @methods[method]
      type = m[name] if m
      raise ArgumentError, "method: #{method} name: #{name}" unless type

      case type
      when 'int'
        Integer( value )
      when 'string'
        value.to_s
      when /^int\[(\d+)..(\d+)\]$/
        to_integer( value, Integer($1), Integer($2) )
      when 'array[int]'
        to_array_int value
      else
        JSON.parse value
      end
    end

    def to_integer str, n1=0, n2=0
      i = Integer( str )
      raise ArgumentError if (n2 > 0) and (i < n1 or i > n2)
      raise ArgumentError if i < n1
    end

    def to_array_int str
      JSON.parse(str)
    end
  end

  class Request
    def initialize local_port
      @local_port = local_port
    end

    def join address, name
      get(address, "Join", { 'name' => name } )
    end

    def get_players address
      get(address, 'GetPlayers')
    end

    def notify_ready address
      get address, 'NotifyReady'
    end

    def notify_not_ready address
      get address, 'NotifyNotReady'
    end

    def get addr, url, params={}
      params["_port"] ||= @local_port
      uri = URI.parse( "#{addr}/#{url}?#{encode_params(params)}" )
      res = Net::HTTP.get( uri )
      raise RequestError if res.nil?

      js = JSON.parse(res)
      raise RequestError, js if error?(js)
      return js
    end

    def error? js
      js.has_key?("Error")
    end

    def encode_params prs
      s = prs.inject("") do |mem, kv|
        key, value = kv
        encoded = value.to_s.gsub(' ', '%20')
        mem += "#{key}=#{encoded}&"
      end
      s.gsub( /(&)$/, '' )
    end
  end
end