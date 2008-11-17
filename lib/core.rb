require 'game_state'
require 'exceptions'

module Monopoly
  
  class Core
  
    def initialize(options={})
      if f = options[:save]
        @state = GameState.from_save( f )
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

    def allowed_method? m
      @methods.has_key?( m )
    end

    def valid_params? m, params
      return false unless allowed_method? m

      valid_params = @methods[m]
      valid_params.each_pair do |name, type|
        return false unless params.has_key?(name) and check_type( type, params[name] )
      end
      return true
    end

    def check_type type, str
      case type
      when 'int'
        is_integer?(str)
      when 'string'
        str.length > 0
      when /^int\[(\d+)..(\d+)\]$/
        is_integer?( str, Integer($1), Integer($2) )
      end
    end

    def is_integer? str, n1=0, n2=0
      begin
        i = Integer( str )
        return n2 > 0 ? (i >= n1 and i <= n2) : i >= n1
      rescue ArgumentError
        return false
      end
    end

  end #class Core
end