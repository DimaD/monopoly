require 'game_state'
require 'exceptions'
require 'httplib'
require 'yaml'
require 'core'
require 'net/http'
require 'utils'
require 'thread'
require 'json/add/core'

DEFAULT_PORT = 80

module Monopoly

  class Network
    include Enumerable
    include Reports
    attr_reader :players, :local_player, :local_port, :lock, :last_modified
    attr_writer :local_player

    def initialize core, local_port=DEFAULT_PORT
      @players = {}
      @core = core
      @local_port = local_port
      @requester = Request.new( @local_port )
      @methods = YAML.load( File.new( File.dirname(__FILE__) + "/../conf/methods.yml" ) )
      @turns_dices = {}
      @player_dices = Hash.new { |hash, key| hash[key] = Hash.new() }
      @lock = Mutex.new
      @moved = {}
      mark_updated
    end

    def self.connect_to_server address, name, local_port
      req = Request.new(local_port)
      js = req.join( "http://#{address}", name )
      core = Monopoly::Core.new( :json => js["Join"]["Rules"], :state => js["Join"]["State"] )
      n = self.new(core, local_port)
      n.local_player = core.get_player( Integer(js["Join"]["Id"]) );

      players = req.get_players( "http://#{address}" )
      req.notify_ready( "http://#{address}" )

      n.merge_players( _substitute_address(players['GetPlayers'], address), address)
      return [core, n]
    end

    def process request
      puts ">>> connection from #{request.address}:#{request.port} => #{request.path} : #{request.file}"
      begin
        return error404 unless @core.allowed_method?( request.file )
        return error_params unless @core.valid_params?( request.file, convert_params(request.file, request.params) )  

        method_name = request.file.underscore
        r = @lock.synchronize do
          if respond_to?(method_name, request)
            send(method_name, request)
          elsif @core.respond_to?(method_name)
            @core.send( method_name, request.params )
          else
            error500 "No method #{method}"
          end
        end
        if method_name == 'confirm_throw_dice'
          Thread.new(self) { |a| a.lock.synchronize { a.try_to_move } }
        end
        pl = get_player_for_request request
        @players.delete("#{request.address}:#{request.port}") if !p.nil? and pl.bankrupt?

        return r
      # rescue Exception => e
      #   return error500(e.message)
      end
    end

    def join req
      return report_game_started if @core.game_started?

      if @players["#{req.address}:#{req.port}"]
        report_player_exist
      else 
        pl = @core.new_player( req.params['name'] )
        @players["#{req.address}:#{req.port}"] = pl
        mark_updated
        report_join pl.game_id, @core.plain_rules, @core.state
      end
    end

    def get_player_for_request req
      @players["#{req.address}:#{req.port}"]
    end

    def can_start?
      pl = if @players.empty?
        true
      else
        @players.all? { |addr, pl| pl.ready }
      end
      pl && !@core.game_started?
    end

    def start_game
      raise MonopolyError, "can't start game" if !can_start?
      @requester.send_all( @players.keys, :notify_ready )
      @local_player.ready = true

      @core.start_game
    end

    def thrown_dices?
      !@my_dices.nil?
    end

    def try_to_move
      turn = @core.turn_number
      return if my_move?

      if @player_dices[turn].size == @players.size and @moved[turn].nil?
        @moved[turn] = 1
        dices = @player_dices[turn].values()
        mydices = _get_dices

        d1 = calc_dice( dices.map { |d| d[0] }.push( mydices[0] ) )
        d2 = calc_dice( dices.map { |d| d[1] }.push( mydices[1] ) )
        
        p dices.map { |d| d[0] }.push( mydices[0] )
        p dices.map { |d| d[1] }.push( mydices[1] )
        @core.make_move( d1, d2 )
      end
    end

    def make_move
      raise MonopolyGameError, "уже кидал кубики на этом ходу" if !@my_dices.nil?

      dices = @requester.send_all( @players.keys, :throw_dice )
      p dices
      my_dices = _get_dices
      @requester.send_all( @players.keys, :confirm_throw_dice, my_dices[0], my_dices[1] )

      d1 = calc_dice( dices.map { |d| d["ThrowDice"]["Dice1"] }.flatten.push(my_dices[0]) )
      d2 = calc_dice( dices.map { |d| d["ThrowDice"]["Dice2"] }.flatten.push(my_dices[1]) )

      p dices.map { |d| d["ThrowDice"]["Dice1"] }.flatten.push(my_dices[0])
      p dices.map { |d| d["ThrowDice"]["Dice2"] }.flatten.push(my_dices[1])
      @core.make_move( d1, d2 )
    end

    def calc_dice arr
      (arr.inject(0) { |memo, e| memo ^ Integer(e) } % 6) + 1
    end

    def my_move?
      @core.my_move?(@local_player)
    end

    def can_buy?
      @core.can_buy?(@local_player)
    end

    def buy_card
      @core.buy_card(@local_player)
      @requester.send_all( @players.keys, :buy )
    end

    def finish_my_move
      make_move if my_move? and !thrown_dices?

      @core.finish_move( @local_player )
      @requester.send_all( @players.keys, :finish_move )
      mark_updated
      @my_dices = nil
      @trade_offers = {}
    end

    def make_trade_offer player_id, my_money=0, my_offer=[], foreign_money=0, foreign_offer=[]
      offer_id = gen_offer_id

      give  = { "Give"  => { "Cash" => my_money,      "PropertyIDs" => my_offer } }.to_json
      wants = { "Wants" => { "Cash" => foreign_money, "PropertyIDs" => foreign_offer } }.to_json
      @core.add_offer({
        'id'        => offer_id,
        'player_id' => player_id,
        'wants'     => { "Cash" => foreign_money, "PropertyIDs" => foreign_offer },
        'give'      => { "Cash" => my_money,      "PropertyIDs" => my_offer },
        'from'      => @local_player.name,
        'from_id'   => @local_player.game_id,
      })
      @requester.send_all( @players.keys, :trade_offer, offer_id, player_id, give, wants )
    end

    def gen_offer_id
      rand(10000)
    end

    def buy req
      @core.buy_card( get_player_for_request(req) )
      ok
    end

    def trade_offer req
      pl = get_player_for_request req
      return report_player_unknown if pl.nil?

      offer_id = Integer(req.param('ID'))
      @core.add_offer( parse_trade_offer( pl, req.params ) )
      mark_updated
      ok
    end

    def deposit_card id
      @core.deposit(@local_player, id)
      @requester.send_all( @players.keys, :deposit, id )
    end

    def redeem_card id
      @core.redeem(@local_player, id)
      @requester.send_all( @players.keys, :redeem, id )
    end

    def deposit req
      pl = get_player_for_request req
      return report_player_unknown if pl.nil?

      @core.deposit( pl, Integer(req.param('Position')) )
      return ok
    end

    def redeem req
      pl = get_player_for_request req
      return report_player_unknown if pl.nil?

      @core.redeem( pl, Integer(req.param('Position')) )
      return ok
    end

    def parse_trade_offer pl, params
      parsed = {
        'id'        => Integer(params['ID']),
        'player_id' => Integer(params['PlayerID']),
        'wants'     => JSON.parse(params['Wants'])["Wants"],
        'give'      => JSON.parse(params['Give'])['Give'],
        'from'      => pl.name,
        'from_id'   => pl.game_id,
      }
      %w(give wants).each do |e|
        parsed[e]['PropertyIDs'] ||= []
        parsed[e]['Cash'] ||= 0
      end
      p parsed
      parsed
    end

    def make_accept_offer offer_id
      @core.accept_offer(@local_player, offer_id)
      @requester.send_all( @players.keys, :accept_offer, offer_id )
    end

    def make_reject_offer offer_id
      @core.reject_offer(@local_player, offer_id)
      @requester.send_all( @players.keys, :reject_offer, offer_id )
    end

    def assert_offer req
      id = Integer(req.param('ID'))
      pl = get_player_for_request req
      return report_player_unknown if pl.nil?

      @core.accept_offer(pl, id)
      ok
    end

    def reject_offer req
      id = Integer(req.param('ID'))
      return report_unknown_offer if @trade_offers[id].nil?
      pl = get_player_for_request
      return report_player_unknown if pl.nil?

      @core.reject_offer(pl, id)
      ok
    end

    def finish_move req
      pl = get_player_for_request(req)
      @core.finish_move( pl )
      @my_dices = nil
      ok
    end

    def game_events
      @core.events
    end

    def _get_dices
      turn = @core.turn_number
      if @turns_dices[turn].nil?
        @turns_dices[turn] = @my_dices = [ _get_rand, _get_rand ]
        @requester.send_all( @players.keys, :confirm_throw_dice, @my_dices[0], @my_dices[1] )
      end
      @turns_dices[turn]
    end

    def throw_dice req
      return report_not_started if !@core.game_started?
      dices = _get_dices
      report_dices dices[0], dices[1]
    end

    def confirm_throw_dice req
      return report_not_started if !@core.game_started?
      p 'confirm_throw_dice'
      turn = @core.turn_number

      pl = get_player_for_request req
      return report_player_unknown if pl.nil?
      pl = pl.game_id
      dices = @player_dices[turn][pl]
      if dices.nil?
        @player_dices[turn][pl] = [ Integer(req.param('Dice1')), Integer(req.param('Dice2')) ]
      else
        d1, d2 = Integer(req.param('Dice1')), Integer(req.param('Dice2'))
        if !d1.nil? and !d2.nil? and d1 != dices[0] and d2 != dices[1]
          return report_wrong_dices
        end
      end
      ok
    end

    def sell_card pos_id
      @core.sell( @local_player, pos_id )
      mark_updated
      @requester.send_all( @players.keys, :sell, pos_id )
    end

    def sell req
      return report_not_started if !@core.game_started?

      pos = Integer(req.param('Position'))
      pl = get_player_for_request req
      return report_player_unknown if pl.nil?

      @core.sell(pl, pos)

      mark_updated
      ok
    end

    def get_players req
      ret = [
        _serialize_player( @local_player, '-1' ),
        @players.map { |addr, pl| _serialize_player pl, addr }
      ].flatten
      report_players ret
    end

    def get_state req
      report_state @core.state
    end

    def notify_ready req
      res = set_ready req, true
      mark_updated
      if can_start? && !@local_player.first_player?
        @core.start_game
      end
      res
    end

    def notify_not_ready req
      set_ready req, false
    end

    def set_ready request, ready
      pl = @players["#{request.address}:#{request.port}"]
      if !pl.nil?
        pl.ready = ready
        mark_updated
        ok
      else
        report_player_unknown
      end
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

    def merge_players pls, sender
      pls.each do |e|
        unless Integer(e["Id"]) == @local_player.game_id
          pl = @core.get_player_or_new(Integer(e["Id"]), e["Name"], e["Ready"])
          if e["Ip"] == sender
            pl.send_join = true
          end
          @players[e["Ip"]] = pl
          if !pl.send_join
            @requester.join( e['Ip'], @local_player.name )
            @requester.notify_ready( e['Ip'] ) if !pl.send_join
            pl.send_join = true
          end
        end
      end
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
      return i
    end

    def to_array_int str
      JSON.parse(str)
    end

    def mark_updated
      @last_modified = Time.now.to_i
    end

    def trade_offers
      @core.trade_offers
    end

    def mine_trade_offers
      @core.trade_offers.values.select { |e| e['player_id'] == @local_player.game_id }
    end
  end

  class Request
    def initialize local_port
      @local_port = local_port
    end

    def send_all arr, method, *a
      arr.map { |pl| send(method, pl, *a) }
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

    def throw_dice address
      get address, 'ThrowDice'
    end

    def confirm_throw_dice address, d1, d2
      get address, 'ConfirmThrowDice', { 'Dice1' => d1, 'Dice2' => d2 }
    end

    def buy address
      get address, 'Buy'
    end

    def finish_move address
      get address, 'FinishMove'
    end

    def sell address, id
      get address, 'Sell', { 'Position' => id }
    end

    def trade_offer address, offer_id, player_id, give, wants
      get address, 'TradeOffer', { 'ID' => offer_id, 'PlayerID' => player_id, 'Give' => give, 'Wants' => wants }
    end

    def accept_offer address, offer_id
      get address, 'AssertOffer', { 'ID' => offer_id }
    end

    def reject_offer address, offer_id
      get address, 'RejectOffer', { 'ID' => offer_id }
    end

    def get addr, url, params={}
      params["_port"] ||= @local_port

      addr = "http://" + addr.sub(/^http:\/\//, '').sub(/^::1/, 'localhost')

      uri = URI.parse( "#{addr}/#{url}?#{params.to_query}" )
      res = Net::HTTP.get_response( uri )
      raise RequestError if res.nil?

      if ( res.content_type == 'application/javascript' )
        js = JSON.parse(res.body())
        raise RequestError, js['Error']['Message'] if error?(js)
        return js
      end
    end

    def error? js
      js.has_key?("Error")
    end

    # def encode_params prs
    #   s = prs.inject("") do |mem, kv|
    #     key, value = kv
    #     mem += value.to_query(key)
    #   end
    #   s.gsub( /(&)$/, '' )
    # end
  end
end