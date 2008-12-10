require 'rubygems'
require 'json'
require 'active_support'
require 'exceptions'
require 'rules'
require 'player'
require 'ostruct'

module Monopoly
  class GameState
    attr_accessor :rules, :state
    
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

    def to_json
      JSON.pretty_generate({"State" => @state})
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
      @state["Turn"] ||= -1;
      @state["Rules"] ||= @rules.name;

      if @state["Players"]
        translate_to_objects @state["Players"]
      else
        @state["Players"] = []
      end

      positions = @rules.board["Positions"]
      props = @rules.properties

      @positions = {}
      positions.each do |pos|
        po = OpenStruct.new(pos)
        if !po.IsJail && !po.IsEvent && po.PropertyId != -1
          property = props.find { |pr| pr["Id"] == po.PropertyId }
          raise RulesError, "No property with id #{pos.PropertyId}" if property.nil?
          po.property = OpenStruct.new(property)
        end
        @positions[po.Id] = po
      end

      @players ||= {}
    end

    def start_game
      if !game_started?
        @state["Turn"] = 1;
      end
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
        pl = Player.new( name, id, cash, position, ready, posession)
        @players_count = [id, players_count].max
        set_player pl
      end
      pl
    end

    def set_player player
      @state["Players"] << player
      @players[player.game_id] = player
      player
    end

    def translate_to_objects pls
      players = pls.clone
      players.each { |pl|
        e = pl["Player"]
        get_player_or_new e["Id"], e["Name"], false, e["Cash"], e["PositionId"], e["Possession"]
      }
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
  end
end