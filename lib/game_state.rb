require 'rubygems'
require 'json'
require 'active_support'
require 'exceptions'
require 'rules'
require 'player'
require 'property'

ADD_CIRCLE_MONEY = 2000
DEFAULT_FACTORY_SELL_COEFF = 1.0

module Monopoly
  class GameState
    attr_accessor :rules, :state, :events_stack
    
    #used to transparently map our config CamelNotation to Ruby underscore_notation
    # def method_missing(symbol, *a)
    #   return unless @state
    #   name = symbol.id2name
    #   if s = @state[name.camelize]
    #     return s
    #   else
    #     raise NoMethodError, "no setting #{name}"
    #   end
    # end

    def to_json(*a)
      { "State" => @state }.to_json(*a)
    end
    
    def self.from_save(s="default")
      path = "./conf/saves/#{s}.js"
      File.exist?(path) || raise(NoFile.new(path), "No such save '#{path}'")
      
      a = self.new
      File.open(path, "r") do |file|
        a.state = JSON.load(file)["State"] || {}
      end
      
      a.rules = Monopoly::Rules.from_file(a.rules)
      a.check
      return a
    end
    
    def self.from_rules(s="default")
      a = self.new
      a.rules = Monopoly::Rules.from_file(s)
      a.generate_state
      return a
    end

    def self.from_js rules_js, state
      a = self.new
      a.rules = Monopoly::Rules.from_js(rules_js)
      a.state = state
      a.generate_state
      a
    end

    def check
      # players.length <= @rules.max_players
    end
    
    def generate_state
      raise RuntimeError, "Can't produce state without rules" if @rules.nil?

      @players_count ||= 0

      @state ||= Hash.new
      @state["Turn"]   ||= -1;
      @state["Rules"]  ||= @rules.name;
      @state["Groups"] ||= []

      if @state["Players"]
        translate_to_objects @state["Players"]
      else
        @state["Players"] = []
      end

      positions = @rules.board["Positions"]
      props = @rules.properties

      @groups = {}
      @rules.groups.each do |gr|
        g = OpenStruct.new(gr)
        @groups[g.Id] = g
        g.properties_a = []
      end

      @positions = {}
      @properties_by_group = Hash.new { |h, k| h[k] = [] }

      positions.each do |pos|
        po = OpenStruct.new(pos)
        if !po.IsJail && !po.IsEvent && po.PropertyId != -1
          property = props.find { |pr| pr["Id"] == po.PropertyId }
          raise RulesError, "No property with id #{pos.PropertyId}" if property.nil?
          po.property = Property.new(property)
          gr = @groups[po.property.GroupId]
          raise MonopolyGameError, "No such group #{po.property.GroupId}" if gr.nil?
          gr.properties ||= 0
          gr.properties += 1
          gr.properties_a << po.property
          po.property.group = gr
          po.property.position_id = po.Id
          po.property.sell_coeff = factory_sell_coeff
          @properties_by_group[po.property.GroupId] << po.property
        end
        @positions[po.Id] = po
      end

      @board_length = @positions.size
      @players ||= {}
      @events_stack ||= []
    end

    def start_game
      if !game_started?
        @state["Turn"] = 1;
      end
    end

    def finish_move
      @state["Turn"] += 1;
    end

    def new_player name
      raise MonopolyGameError, "no more players allowed" if @players_count >= @rules.max_players
      @players_count = players_count + 1
      set_player Player.new( name, @players_count, @rules.starting_money, 0 )
    end

    def get_player id
      @players ||= {}
      @players[id]
    end

    def get_player_or_new id, name, ready, cash=false, position=0, posession=[]
      pl = get_player id
      if pl.nil?
        cash ||= @rules.starting_money
        pl = Player.new( name, id, cash, position, ready )
        @players_count = [id, players_count].max
        if posession
          posession.each do |pos|
            pr = @properties[pos["PropertyId"]]
            raise MonopolyGameError, "no property #{po['PropertyId']} for player #{pl.Name}" if pl.nil?
            player.add_posession( pr, pos["Factories"], pos["Deposit"] )
          end
        end
        set_player pl
      else
        pl.ready = ready
      end
      pl
    end

    def kill_player pl
      add_event "Игрок #{pl.name} обанкротился и вышел из игры"
      pl.kill

      @state["Players"].reject! { |player| player.game_id == pl.game_id }
      @players.delete( pl.game_id )
    end

    def set_player player
      @state["Players"] << player
      @players[player.game_id] = player

      player
    end

    def translate_to_objects pls
      players = pls.clone
      @state["Players"] = []
      players.map { |pl|
        e = pl["Player"]
        get_player_or_new e["Id"], e["Name"], false, e["Cash"], e["PositionId"], e["Possession"]
      }
    end

    def make_move dice1, dice2
      raise MonopolyGameError, "Dices value more then 12" if dice1 + dice2 > 12
  
      pl = get_player_for_turn
      new_pos = (pl.position_id + dice1 + dice2) % @board_length
      move_pl_to pl, new_pos, dice1, dice2

      add_event "Игрок #{pl.name} перешел на поле #{pl.position_id} после броска кубиков [#{dice1}, #{dice2}]"
    end

    def check_events pl, dice1, dice2
      pos = @positions[pl.position_id]
      if pos.IsEvent
        event = get_event_card dice1, dice2
        add_event "Игрок #{pl.name} попал на поле событие и ему выпала карточка: «#{event['Text']}». Игрок перемещается на #{event['Movement']}, его баланс меняется на #{event['Amount']}"
        new_pos = (pl.position_id + event['Movement']) % @board_length
        move_pl_to pl, new_pos, dice1, dice2
        pl.cash += event['Amount']
      elsif pos.IsJail
        # pl.place_to_jail()
      elsif pos.property and pos.property.owner and pos.property.owner != pl.game_id
        own = @players[pos.property.owner]
        pr = own.get_property(pos.property.Id)
        if (pr && !pr.deposit)
          own.cash += pos.property.kickback
          pl.cash  -= pos.property.kickback
          add_event "Игрок #{pl.name} заплатил игроку #{own.name} #{pos.property.kickback} у.е. за проход по клетке «#{pos.property.Name}»"
        end
      end
    end

    def move_pl_to pl, pos, dice1, dice2
      if pos < pl.position_id or pos == 0
        add_event "Игрок #{pl.name} прошел через начало площадки и получил #{ADD_CIRCLE_MONEY} у.е. денег"
        pl.cash += ADD_CIRCLE_MONEY
      end
      pl.position_id = pos
      check_events pl, dice1, dice2
    end

    def get_player_for_turn
      pl = @players.values.sort { |x, y| x.game_id <=> x.game_id }
      n = ( turn_number - 1) % pl.size 
      pl[n]
    end

    def get_event_card d1, d2
      l = @rules.events.size
      i = (d1 + d2) % l
      return @rules.events[i]
    end

    def property_at id
      pos = @positions[id]
      !pos.nil? && !pos.property.nil? ? pos.property : nil
    end

    def add_event m
      @events_stack.unshift(m)
    end

    def rules_name
      @rules.name
    end

    def properties
      @rules.properties
    end

    def property_for_position pos
      @position[pos].property
    end

    def get_position i
      @positions[i]
    end

    def positions
      @rules.board["Positions"]
    end

    def plain_rules
      @rules.plain_rules
    end

    def players_count
      @players_count ||= 0
    end

    def turn_number
      @state["Turn"]
    end

    def game_started?
      @state["Turn"] > 0;
    end

    def factory_sell_coeff
      @rules.factory_sell_coeff || DEFAULT_FACTORY_SELL_COEFF
    end
  end
end