require 'network'

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
    puts [].to_json
    puts {}.to_json
    puts( { "Join" => { "Id" => id,"Rules" => 123, "State" => 321} }.to_json )
    puts report_json(12, 12, 12)
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