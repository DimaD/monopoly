module Monopoly
  class Player
    attr_reader :name, :game_id, :posession, :cash, :position_id, :ready
    attr_writer :ready

    def initialize(name, id, cash, position_id, ready=false, posession=[])
      @name = name
      @game_id = id
      @posession = posession
      @cash = cash
      @position_id = position_id
      @ready = ready;
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
          'Posession'    => @posession,
          'PositionId'   => @position_id,
        }
      }.to_json(*a)
    end
  end
end