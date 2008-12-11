require 'json'

module Monopoly
  class Player
    attr_reader :name, :game_id, :posession, :cash, :position_id, :ready, :send_join, :in_game
    attr_writer :ready, :send_join, :position_id, :cash

    def initialize(name, id, cash, position_id, ready=false, posession=[])
      @name = name
      @game_id = id
      @posession = posession
      @cash = cash
      @position_id = position_id
      @ready = ready
      @send_join = false
      @in_game = true
    end

    def first_player?
      @game_id == 1
    end

    def get_property id
      @posession.find { |p| p.game_id == id }
    end

    def buy pr
      @cash -= pr.Price
      add_posession pr
    end

    def add_posession pr, fact=0, deposit=false
      @posession << pr
      pr.owner = self.game_id
      pr.factories = fact
      pr.deposit = deposit
    end

    def remove_posession pos
      raise MonopolyGameError, "Can't remove posession with factories" if pr.factories > 0
  
      pr.owner = nil
      @posession.reject! { |pr| pr.PropertyId == pos.PropertyId }
    end

    def total_actives
      @posession.filter { |prop| !prop.deposit }.inject(0) { |prop| prop.factories*prop.factory_price + prop.Price }
    end

    def bankrupt?
      @cash <= 0 and @cash.abs > total_actives
    end

    def kill
      @posession.each { |p| remove_posession(p) }
      @ready = false
      @in_game = false
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