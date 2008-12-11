require 'network'
require 'json/add/core'

class GreedyNetwork < Monopoly::Network
  def process request
    p "process"
    r = super
    if my_move?
      Thread.new(self) { |a| sleep(0.5); a.lock.synchronize { a.process_logic } }
    end
    r
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