module Monopoly
  class Player
    attr_reader :name, :id, :posession, :cash, :position_id

    def initialize(name, id, cash, position_id)
      @name = name
      @id = id
      @posession = []
      @cash = cash
      @position_id = position_id
    end

    def to_s
      "#{@id}: #{@name}"
    end

    def to_json(*a)
      { "Player" => {
          'Name'         => @name,
          'Id'           => @id,
          'Cash'         => @cash,
          'Posession'    => @posession,
          'PositionId'   => @position_id,
        }
      }.to_json(*a)
    end
  end
end