require 'json'

module Monopoly
  class Player
    attr_reader :name, :game_id, :posession, :cash, :position_id, :ready, :send_join
    attr_writer :ready, :send_join, :position_id, :cash

    def initialize(name, id, cash, position_id, ready=false, posession=[])
      @name = name
      @game_id = id
      @posession = posession
      @cash = cash
      @position_id = position_id
      @ready = ready
      @send_join = false
    end

    def first_player?
      @game_id == 1
    end

    def buy pr
      @cash -= pr.Price
      @posession << pr
      pr.owner = self.game_id
      pr.Factories = 0
    end

    def to_s
      "#{@game_id}: #{@name}"
    end

    def to_json(*a)
      { "Player" => {
          'Name'         => @name,
          'Id'           => @game_id,
          'Ready'        => @ready,
          'Cash'         => @cash,
          'Possession'    => @posession.map { |e| e.to_js },
          'PositionId'   => @position_id,
        }
      }.to_json(*a)
    end

    def to_js
      JSON.generate( self )
    end
  end
end