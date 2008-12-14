require 'network'

MAX_BUILD_PER_TURN = 2
MIN_MONEY_TO_BUILD = 2000
MIN_MONEY_TO_BUY   = 1000
MIN_PANIC_MONEY    = 500

class GreedyNetwork < Monopoly::Network
  def process request
    if @thread.nil?
      @thread = Thread.new(self) do |s|
        while true
          begin
            sleep(1)
            s.process_logic
          rescue Exception => e
            p e
          end
          
        end
      end
    end

    super
  end

  def process_logic
    if @local_player.cash <= MIN_PANIC_MONEY
      return try_to_survive
    end

    try_to_build
    if offers = get_my_offers
      process_offers( offers )
    end
    if my_move?
      puts '>  make move'
      make_move
      if want_to_buy?
        buy_card
        puts "> Buy card"
      end
      puts '> finish'
      finish_my_move
    end
  end

  def try_to_survive
    @local_player.posession.each do |e|
      if @local_player.can_destroy?(e)
        destroy_factory_local e.position_id
        return if @local_player.cash > MIN_PANIC_MONEY
      end
    end

    @local_player.posession.each do |e|
      if e.can_sell?
        deposit_card e.Id
        return if @local_player.cash > MIN_PANIC_MONEY
      end
    end

    @local_player.posession.each do |e|
      if e.can_sell?
        sell_card e.position_id
        return if @local_player.cash > MIN_PANIC_MONEY
      end
    end
  end

  def want_to_buy?
    can_buy? and @local_player.cash >= MIN_MONEY_TO_BUY 
  end

  def try_to_build
    return if !@last_build_turn.nil? and @last_build_turn == @core.turn_number

    builded = 0
    @local_player.posession.each do |e|
      if @local_player.can_build?(e) and builded < MAX_BUILD_PER_TURN and @local_player.cash >= MIN_MONEY_TO_BUILD
        buy_factory_local e.position_id
        builded += 1
      end
    end

    @last_build_turn = @core.turn_number if builded > 0
  end

  def process_offers offs
    needed = @local_player.needs_props.map { |e| e.Id }

    offs.each do |off_id, obj|
      wants = obj['wants']
      give  = obj['give']
      if (wants["PropertyIDs"].size == 0 and wants['Cash'] == 0) or contains_needed(obj, needed)
        make_accept_offer off_id
      else
        make_reject_offer off_id
      end
    end
  end

  def contains_needed offer, needed
    give = offer['give']['PropertyIDs']
    wants = offer['wants']['Cash']
    return false if offer['wants']['PropertyIDs'].size > 0

    dont_need = give - needed
    dont_give = needed - give
    need_give = give - dont_need
    good = need_give.size
    bad = give.size - good
    good * 2 > bad and @local_player.cash > (wants*1.5 - offer['give']['Cash'])
  end

  def get_my_offers
    offs = @core.trade_offers.select { |k, v| v['player_id'] == @local_player.game_id }
    offs.size > 0 ? offs : false
  end
end