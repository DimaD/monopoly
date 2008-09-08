require 'game_state'
require 'exceptions'

module Monopoly
  
  class Core
  
    def initialize(options={})
      if f = options[:save]
        @state = GameState.from_save( f )
      end
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
  end

end