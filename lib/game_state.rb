require 'rubygems'
require 'json'
require 'active_support'
require 'exceptions'
require 'rules'
require 'player'

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

    def self.from_js js
      a = self.new
      a.rules = Monopoly::Rules.from_js(js)
      a.generate_state
      p a
      a
    end

    def check
      # players.length <= @rules.max_players
    end
    
    def generate_state
      raise RuntimeError, "Can't produce state without rules" if @rules.nil?
      raise RuntimeError, "State is alredy exist" if !@state.nil?

      @players_count = 0
      @state = Hash.new
      @state["Turn"] = -1;
      @state["Rules"] = @rules.name;
      @state["Players"] = []
    end

    def new_player name
      @players_count += 1
      player = Player.new( name, @players_count, @rules.starting_money, 0 )
      @state["Players"] << player
      player
    end

    def rules_name
      @rules.name
    end

    def plain_rules
      @rules.plain_rules
    end
  end
end