require 'network'
require 'json/add/core'

class GreedyNetwork < Monopoly::Network
  def process request
    if @thread.nil?
      @thread = Thread.new(self) do |s|
        while true
          sleep(1)
          s.process_logic
        end
      end
    end

    super
  end

  def process_logic
    puts 'process_logic'
    if my_move?
      puts '>  make move'
      make_move
      p @local_player
      if can_buy?
        buy_card
        puts "> Buy card"
      end
      puts '> finish'
      finish_my_move
    end
  end
end