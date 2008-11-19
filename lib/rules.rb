require 'rubygems'
require 'json'
require 'active_support'
require 'exceptions'

module Monopoly
  class Rules
    attr_reader :rules_file
    def initialize(config=nil)
      @rules_file = config.nil? ? 'default' : config
      path = "./conf/rules/#{@rules_file}.js"
      File.exist?(path) || raise(NoFile.new(path), "no such rules '#{path}'")
      
      File.open(path, "r") do |file|
        @rules = JSON.load(file)["Rules"] || {}
      end
    end
    
    def method_missing(symbol)
      name = symbol.id2name
      if s = @rules[name.camelize]
        return s
      else
        raise NoMethodError, "no setting #{name}"
      end
    end
    
    def to_json
      JSON.pretty_generate({"Rules" => @rule})
    end
    
    def check
      # starting_money > 0
      # salary > 0
      # factory_sell_coeff > 0
    end
    
  end
end