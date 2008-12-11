require 'network'
require 'json/add/core'

class GreedyNetwork < Monopoly::Network
  def process request
    r = super
    Thread.new { @lock.synchronize { try_to_move } }
    r
  end

  def try_to_move
    if my_move?
      make_move
      if can_buy?
        buy_card
        puts "> Buy card"
      end
    end
  end
end