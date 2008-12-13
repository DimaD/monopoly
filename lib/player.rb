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
      @posession.find { |p| p.Id == id }
    end

    def property_at pid
      @posession.find { |p| p.position_id == pid }
    end

    def buy pr
      @cash -= pr.Price
      add_posession pr
    end

    def sell prop
      property = get_property( prop.Id )
      raise MonopolyGameError, "Don't own property #{prop.Id} #{prop.Name}" if property.nil?

      remove_posession prop
    end

    def add_posession pr, fact=0, deposit=false
      @posession << pr
      pr.owner = self.game_id
      pr.factories = fact
      pr.deposit = deposit
    end

    def remove_posession pos
      raise MonopolyGameError, "Can't remove posession with factories" if pos.factories > 0
  
      pos.owner = nil
      @posession.reject! { |pr| pr.PropertyId == pos.PropertyId }
    end

    def total_actives
      p @posession
      actives = @posession.select { |prop| !prop.deposit }.map { |prop| prop.factories*prop.factory_price + prop.Price }
      actives.inject(0) { |mem, var| mem + var }
    end

    def can_build?(prop)
      
    end

    def can_destroy?(prop)
      
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
      { "Player" => js }.to_json(*a)
    end

    def to_js
      js.to_json
    end

    def js
      {
        'Name'         => @name,
        'Id'           => @game_id,
        'Ready'        => @ready,
        'Cash'         => @cash,
        'Possession'   => @posession.map { |e| e.to_js },
        'PositionId'   => @position_id,
      }
    end
  end
end