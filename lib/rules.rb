require 'rubygems'
require 'json'
require 'active_support'
require 'exceptions'

module Monopoly
  class Rules
    attr_reader :rules_file

    def initialize rules, rules_file=nil
      (@rules, @rules_file) = rules, rules_file
    end

    def self.from_file(config=nil)
      rules_file = config.nil? ? 'default' : config
      path = "./conf/rules/#{rules_file}.js"
      File.exist?(path) || raise(NoFile.new(path), "no such rules '#{path}'")
      
      File.open(path, "r") do |file|
        rules = JSON.load(file)["Rules"] || {}
        return self.new(rules, rules_file)
      end
    end

    def self.from_js rls
      self.new(rls)
    end

    def method_missing(symbol)
      name = symbol.id2name
      if s = @rules[name.camelize]
        return s
      else
        raise NoMethodError, "no setting #{name}"
      end
    end

    def plain_rules
      @rules
    end

    def to_json(*a)
      { "Rules" => @rules }.to_json(*a)
    end
    
    def check
      # starting_money > 0
      # salary > 0
      # factory_sell_coeff > 0
    end
    
  end
end