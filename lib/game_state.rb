require 'rubygems'
require 'json'
require 'active_support'
require 'exceptions'
require 'rules'

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
      
      a.rules = Monopoly::Rules.new(a.rules)
      a.check
      return a
    end
    
    def self.from_rules(s="default")
      a = self.new
      a.rules = Monopoly::Rules.new(s)
      a.generate_state
      return a
    end
    
    def check
      # players.length <= @rules.max_players
    end
    
    def generate_state
      raise RuntimeError, "Can't produce state without rules" if @rules.nil?
      raise RuntimeError, "State is alredy exist" if @state.not.nil?
      
      @state = Hash.new
      @state["Turn"] = 1;
      @state["Rules"] = rules.name;
    end
  end
end