require 'game_state'
require 'exceptions'
require 'find'
require 'rules'

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
    def initialize(options={})
      if f = options[:save]
        @state = GameState.from_save( f )
      elsif f = options[:rules]
        @state = GameState.from_rules( f )
      elsif st = options[:state]
        @state = GameState.from_js( options[:json], st )
      end
      @methods = YAML.load( File.new( File.dirname(__FILE__) + "/../conf/methods.yml" ) )
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
    
    def start_game
      @state.start_game
    end

    def events
      @state.events_stack
    end

    def my_move? lp
      pl = @state.get_player_for_turn
      !pl.nil? && (pl.game_id == lp.game_id )
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
      raise MonopolyGameError, "не твой ход" if !my_move?(pl)
      if pl.bankrupt?
        @state.kill_player pl
      end
      @state.finish_move
    end

    def sell pl, pid
      prop = pl.property_at( pid )
      raise MonopolyGameError, "Player #{pl.name} don't have property at position #{pid}" if prop.nil?
      pl.sell( prop )
      pl.cash += prop.Price
      @state.add_event "Игрок #{pl.name} продал карточку #{prop.Name} банку"
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
      @state.game_started?
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