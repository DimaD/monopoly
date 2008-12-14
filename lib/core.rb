require 'game_state'
require 'exceptions'
require 'find'
require 'rules'

REDEEM_COEFF = 1.1

module Monopoly
  def self.available_rules
    conf_rules =  File.dirname(__FILE__) + "/../conf/rules"
    rules = []
    Find.find( conf_rules ) do |f|
      if !FileTest.directory?(f) && (File.dirname(f) == conf_rules)
        rules << Monopoly::Rules.from_file( File.basename(f, ".js") )
      end
    end
    rules
  end

  class Core
    attr_reader :trade_offers

    def initialize(options={})
      if f = options[:save]
        @state = GameState.from_save( f )
      elsif f = options[:rules]
        @state = GameState.from_rules( f )
      elsif st = options[:state]
        @state = GameState.from_js( options[:json], st )
      end
      @methods = YAML.load( File.new( File.dirname(__FILE__) + "/../conf/methods.yml" ) )
      @trade_offers = {}
      @game_stoped = false
    end
  
    def load_save
      raise NonImplemented
    end
    
    def save_game(options)

      return if (!initialized || options.length == 0)

      if f = options[:to_file]
        File.open(File.dirname(__FILE__) + "/../conf/saves/#{f}", "w") do |file|
          file << @state.to_json
        end
      end
    end
    
    def initialized
      @state.not.nil?
    end

    def make_move dice1, dice2
      @state.make_move dice1, dice2
    end

    def add_offer offer
      check_offer offer
      @trade_offers[offer['id']] = offer
      @state.add_event( "#{get_player(offer['player_id']).name} получил предложение о сделке от #{get_player(offer['from_id']).name}" )
    end

    def accept_offer pl, offer_id
      off = get_offer offer_id
      raise MonopolyGameError, "Player #{pl.name} can't accept offer #{offer_id}" if pl.game_id != off['player_id']
      check_offer off

      sender  = get_player off['from_id']
      reciver = get_player off['player_id']

      off['give']['PropertyIDs'].each do |pr|
        prop = sender.get_property(pr)
        sender.sell(prop);
        reciver.add_posession(prop)
      end
      off['wants']['PropertyIDs'].each do |pr|
        prop = reciver.get_property(pr)
        reciver.sell(prop);
        sender.add_posession(prop)
      end
      reciver.cash += off['give']['Cash']
      sender.cash  -= off['give']['Cash']

      sender.cash  += off['wants']['Cash']
      reciver.cash -= off['wants']['Cash']

      @trade_offers.delete(offer_id)
      @state.add_event( "#{reciver.name} принял сделку #{offer_id} от игрока #{sender.name}")
    end

    def reject_offer pl, offer_id
      off = get_offer offer_id

      raise MonopolyGameError, "Player #{pl.name} can't reject offer #{offer_id}" if pl.game_id != off['player_id']


      offer = @trade_offers.delete(offer_id)
      @state.add_event( "#{pl.name} отклонил предложение о сделке от #{get_player(offer['from_id']).name}" )
    end

    def check_offer offer
      sender  = get_player offer['from_id']
      reciver = get_player offer['player_id']

      give_cash = offer['give']['Cash']
      if give_cash != 0 and sender.cash < give_cash
        raise MonopolyGameError, "Player #{sender.name} don't have enough money to give"
      end
      offer['give']['PropertyIDs'].each do |pr|
        prop = sender.get_property(pr)
        raise MonopolyGameError, "Player #{sender.name} don't own property #{pr}" if prop.nil?
        raise MonopolyGameError, "Can't sell property #{prop.Name}" if !prop.can_sell?
      end

      wants_cash = offer['wants']['Cash']
      if wants_cash != 0 and reciver.cash < wants_cash
        raise MonopolyGameError, "Player #{reciver.name} don't have enough money to give"
      end
      offer['wants']['PropertyIDs'].each do |pr|
        prop = reciver.get_property(pr)
        raise MonopolyGameError, "Player #{reciver.name} don't own property #{pr}" if prop.nil?
        raise MonopolyGameError, "Can't sell property #{reciver.Name}" if !prop.can_sell?
      end
    end

    def buy_factory pl, prop
      if pl.can_build?(prop)
        prop.factories += 1
        pl.cash -= prop.factory_price
        @state.add_event("Игрок #{pl.name} построил магазин на поле #{prop.Name}")
      end
    end

    def sell_factory pl, prop
       if pl.can_destroy?(prop)
         prop.factories -= 1
         pl.cash += (prop.factory_price*@state.factory_sell_coeff).ceil
         @state.add_event("Игрок #{pl.name} продал магазин на поле #{prop.Name}")
       end
    end
    
    def get_offer offer_id
      off = @trade_offers[offer_id]
      raise MonopolyGameError, "Don't have offer #{offer_id}. Unsync?" if off.nil?
      off
    end

    def start_game
      @state.start_game
    end

    def events
      @state.events_stack
    end

    def my_move? lp
      pl = @state.get_player_for_turn
      !pl.nil? && !lp.nil? && (pl.game_id == lp.game_id )
    end

    def can_buy? lp
      return false if !my_move?(lp)

      pr = @state.property_at(lp.position_id)
      return false if pr.nil?
      return false if pr.IsJail or pr.IsEvent
      return pr.owner.nil? && (lp.cash >= pr.Price)
    end

    def buy_card pl
      raise MonopolyGameError, "нельзя купить эту карточку. Рассинхронизация?" if !can_buy?(pl)

      pr = @state.property_at( pl.position_id )
      pl.buy(pr)
      @state.add_event "Игрок #{pl.name} купил карточку #{pr.Name}"
    end

    def finish_move pl
      raise MonopolyGameError, "не твой ход" if !my_move?(pl) && !pl.bankrupt?
      if pl.bankrupt?
        @state.kill_player pl
      end
      @state.finish_move
      @trade_offers = {}
    end

    def sell pl, pid
      prop = get_property_for_player pl, pid
      pl.sell( prop )
      pl.cash += prop.Price
      @state.add_event "Игрок #{pl.name} продал карточку #{prop.Name} банку"
    end

    def deposit pl, position_id
      prop = get_property_for_player pl, position_id

      if prop.can_sell?
        prop.deposit = true
        pl.cash += prop.Price
        @state.add_event( "Игрок #{pl.name} заложил в банк карточку #{prop.Name}" )
      else
        raise MonopolyGameError, "You can't deposit property #{prop.Name}, cause it has factories"
      end
    end

    def redeem pl, position_id
      prop = get_property_for_player pl, position_id

      need_to_pay = (prop.Price*REDEEM_COEFF).ceil
      if pl.cash >= need_to_pay
        prop.deposit = false
        pl.cash -= need_to_pay
        @state.add_event( "Игрок #{pl.name} выкупил у банка карточку #{prop.Name}" )
      else
        raise MonopolyGameError, "You don't have enough money to redeem #{prop.Name}, it costs #{need_to_pay}"
      end
    end

    def get_property_for_player pl, position_id
      prop = pl.property_at( position_id )
      raise MonopolyGameError, "Player #{pl.name} don't have property at position #{position_id}" if prop.nil?
      prop
    end

    def end_game
      @game_stoped = true
    end

    def finish_game
      @finished = true
    end

    def turn_number
      @state.turn_number
    end

    def allowed_method? m
      @methods.has_key?( m )
    end

    def rules_name
      @state.rules_name
    end

    def plain_rules
      @state.plain_rules
    end

    def state
      @state.state
    end

    def new_player name
      @state.new_player(name)
    end

    def get_player id
      @state.get_player(id)
    end

    def get_player_or_new *a
      @state.get_player_or_new(*a)
    end

    def game_started?
      !@game_stoped && @state.game_started?
    end

    def properties
      @state.properties
    end

    def property_for_position pos
      @state.property_for_position pos
    end

    def get_position i
      @state.get_position(i)
    end

    def positions
      @state.positions
    end

    def valid_params? m, params
      return false unless allowed_method? m

      valid_params = @methods[m]
      unless valid_params.nil?
        valid_params.each_pair do |name, type|
          return false unless params.has_key?(name) and check_type( type, params[name] )
        end
      end

      return true
    end

    def check_type type, obj
      case type
      when 'int'
        is_integer?(obj)
      when 'string'
        obj.length > 0
      when /^int\[(\d+)..(\d+)\]$/
        is_integer?( obj, Integer($1), Integer($2) )
      when 'array[int]'
        is_array_int? obj
      else
        type.map { |name, val| check_type val, obj[name] }.all? { |e| e == true }
      end
    end

    def is_integer? i, n1=0, n2=0
      return false unless i.is_a?(Integer)
      return n2 > 0 ? (i >= n1 and i <= n2) : i >= n1
    end

    def is_array_int? arr
      v = arr.all? { |e| is_integer?(e) }
    end
  end #class Core
end