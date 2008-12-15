#!/usr/local/bin/ruby
$: << "./lib"
require 'optparse'
require 'rubygems'
require 'camping'
require 'cookie_sessions'
require 'network'
require 'mhelpers'
require "delegate"
require 'core_extensions/extend'
begin
  require 'erubis'
  ERB = Erubis::Eruby
rescue
  require 'erb'
end

require 'core'

options = {
  :port => 8080,
  :host => "localhost",
}

OptionParser.new("Dmitiry Dzema monopoly client.") do |opts|
  opts.on("-p", "--port PORT", "Port to bind") do |p|
    options[:port] = Integer(p)
  end
  opts.on("-a", "--host HOST", "Host ot bind to") { |p| options[:host] = p }
  opts.on("-d", "--default", "Start with default params") do |p|
    options[:default] = p
  end
  
end.parse!


$core = nil
$options = options

Camping.goes :Interface

module Interface
  include Camping::CookieSessions
  include MHelpers

  @@state_secret = "JI0ZspUChfzIyGwlfjRJI0ZspUChfzIyGwlfjRuv8CCVXhrJZmOlxYMrPGTznUhnAEzGpuv8CCVXhrJZmOlxYMrPGJI0ZspUChfzIyGwlfjRuv8CCVXhrJZmOlxYMrPGTznUhnAEzGpTznUhnAEzGp";
  def render(m, layout=true)
    content = ERB.new(IO.read("templates/#{m}.html.erb")).result(binding)
    content = ERB.new(IO.read("templates/layout.html.erb")).result(binding) if layout
    return content
  end

  def check_started
    !Interface::get_core.nil? && !Interface::get_network.nil? && Interface::get_core.game_started?
  end

  def self.get_core
    $core || nil
  end

  def self.get_network
    $network || nil
  end

  def self.set_core c
    $core = c
    $network = Monopoly::Network.new( c, $options[:port] )
  end

  def self.set_player p
    $player = p
  end

  def self.get_player
    $player
  end

  def self.get_field_map
    return nil if !self.get_core
    return $field_map if $field_map
    props = self.get_core.positions
    l = props.size # + start + empty corner
    if l.modulo(4) == 0
      n = l/4 + 1
      $field_map = { :type => :square, :length => n }
    else
      $field_map = { :type => :seq, :length => l }
    end
  end

  def self.connect_to_server(address, name)
    ($core, $network) = Monopoly::Network.connect_to_server( address, name, $options[:port] )
    $player = $network.local_player
  end
end

module Interface::Controllers

   # The root slash shows the `index' view.
  class Index < R '/'
    def get
      @error = !@state.nil? && @state.delete(:error) || false
      if Interface.get_network && !Interface.get_network.synced
        @message = Interface.get_network.fail_reason
        render :unsync
        return
      end
      if Interface.get_network && Interface::get_core.game_started?
        Interface.get_network.check_bankrupts
      end
      
      if Interface::get_core.nil?
        @rules = Monopoly::available_rules
        render :index
      elsif !Interface.get_network.finished
        @core      = Interface::get_core
        @network   = Interface::get_network
        @player    = Interface::get_player
        @field_map = Interface::get_field_map

        render :game
      else
        @network = Interface::get_network
        render :finished
      end
    end
  end

  class Connect < R '/connect'
    def post
      if correct_input?
        begin
          Interface::connect_to_server(@input[:address], @input[:name])
        rescue Exception => e
          @state[:error] = e.message
        end
      else
        @state[:error] = 'Введите адрес сервера и желаемое имя пользователя'
      end
      redirect Index
    end

    def correct_input?
      (@input[:name].length > 0) && (@input[:address].length > 0)
    end
  end

  class NewGame < R '/new_game'
    def post
      unless ( @input[:rules].nil? || @input[:name].nil?)
        Interface::set_core( Monopoly::Core.new( :rules => @input[:rules] ) )
        Interface::set_player Interface::get_network.new_local_player(@input[:name])
      else
        @state[:error] = 'Необходимо выбрать правила и указать желаемое имя'
      end
      redirect Index
    end
  end

  class Surrender < R '/surrender'
    def get
      begin
        Interface::get_network.surrender_me
      rescue Exception => e
        @state[:error] = e.message
      end
      
      redirect Index
    end
  end

  class BeginGame < R '/begin_game'
    def get
      if Interface::get_core.nil? || Interface::get_network.nil?
        @state[:error] = 'Нельзя начать, если вы не инициализириовали игру'
      elsif !Interface::get_network.can_start?
        @state[:error] = 'Нельзя начинать, не все игроки готовы'
      else
        Interface::get_network.start_game
      end
      redirect Index
    end
  end

  class Buy < R '/buy'
    def get
      if Interface::get_core.nil? || Interface::get_network.nil?
        @state[:error] = 'Нельзя купить, если вы не инициализириовали игру'
      elsif !Interface::get_core.game_started?
        @state[:error] = 'Нельзя покупать, пока игра не началась'
      elsif !Interface::get_network.my_move?
        @state[:error] = 'Нельзя покупать, пока не пришел ваш ход'
      elsif !Interface::get_network.can_buy?
        @state[:error] = 'Нельзя купить эту карточку'
      else
        begin
          Interface::get_network.buy_card
        rescue Exception => e
          @state[:error] = e.message
        end
      end

      redirect Index
    end
  end

  class FinishMove < R '/finish_move'
    def get
      if Interface::get_core.nil? || Interface::get_network.nil?
        @state[:error] = 'Нельзя закончить ход, если вы не инициализириовали игру'
      elsif !Interface::get_core.game_started?
        @state[:error] = 'Нельзя закончить ход, пока игра не началась'
      elsif !Interface::get_network.my_move?
        @state[:error] = 'Нельзя закончить ход, пока не пришел ваш ход'
      else
        begin
          Interface::get_network.finish_my_move
        rescue Exception => e
          @state[:error] = e.message
        end
      end

      redirect Index
    end
  end

  class Throw < R '/throw'
    def get
      if Interface::get_core.nil? || Interface::get_network.nil?
        @state[:error] = 'Нельзя кидать кубики, если вы не инициализириовали игру'
      elsif !Interface::get_core.game_started?
        @state[:error] = 'Нельзя кидать кубики, пока игра не началась'
      elsif !Interface::get_network.my_move?
        @state[:error] = 'Нельзя кидать кубики, пока не пришел ваш ход'
      else
        begin
          Interface::get_network.make_move
        rescue Exception => e
           @state[:error] = e.message
        end
      end
      redirect Index
    end
  end

  class Sell < R '/sell'
    def get
      if Interface::get_core.nil? || Interface::get_network.nil?
        @state[:error] = 'Нельзя продавать, если вы не инициализириовали игру'
      elsif !Interface::get_core.game_started?
        @state[:error] = 'Нельзя продавать, пока игра не началась'
      elsif @input[:id].nil?
        @state[:error] = "Нужно указать карточку для продажи, ага"
      else
        Interface::get_network.sell_card( Integer( @input[:id] ) )
      end
      redirect Index
    end
  end

  class Deposit < R '/deposit/(\d+)'
    def get id
      position_id = Integer(id)
      if check_started
        Interface::get_network.deposit_card(position_id)
      end
      redirect Index
    end
  end

  class Redeem < R '/redeem/(\d+)'
    def get id
      position_id = Integer(id)
      if check_started
        Interface::get_network.redeem_card(position_id)
      end
      redirect Index
    end
  end

  class UpdatesChecker < R '/is_updated'
    def get
      return false if @input[:since].nil?
      network = Interface.get_network
      !network.nil? && network.last_modified > Integer(@input[:since])
    end
  end

  class Offer < R '/offer/(\d+)'
    def post id
      begin
        if check_started
          offer_id = Integer(id)
          if @input['sOk']
            Interface.get_network.make_accept_offer(offer_id)
          elsif @input['sCancel']
            Interface.get_network.make_reject_offer(offer_id)
          end
        end
      rescue Exception => e
        @state[:error] = e.message
      end
      
      redirect Index
    end
  end

  class BuyFactory < R '/buyfactory/(\d+)'
    def get propid
      begin
        Interface.get_network.buy_factory_local( Integer(propid) )
      rescue Exception => e
        @state[:error] = e.message
      end
      redirect Index
    end
  end

  class DestroyFactory < R '/destroyfactory/(\d+)'
    def get propid
      begin
        Interface.get_network.destroy_factory_local( Integer(propid) )
      rescue Exception => e
        @state[:error] = e.message
      end
      redirect Index
    end
  end

  class ShowOffer < R '/offerwith/(\d+)'
    def get id
      if !check_started
        @error = 'Игра не началсь!'
      else
        @network = Interface::get_network
        @player  = Interface::get_core.get_player( Integer(id) )
        @local_player  = Interface::get_player
      end
      render 'offerwith', false
    end

    def post id
      if empty_input_data?
        @state[:error] = "Надо же хоть что-то в сделке указать"
        redirect ShowOffer
      else
        begin
          my_money = get_money :my_money
          my_offer = get_offer :my_offer

          foreign_money = get_money :foreign_money
          foreign_offer = get_offer :foreign_offer
        
          Interface::get_network.make_trade_offer( Integer(id), my_money, my_offer, foreign_money, foreign_offer )
        rescue Exception => e
          @state[:error] = e.message
          @error = e.message
        end
        render 'offersent', false
      end
    end

    def empty_input_data?
      [
        :my_money, :foreign_money, :foreign_offer, :my_offer
      ].map { |e| @input[e].nil? }.inject(false) { |memo, m| memo || m }
      return false
    end

    def get_money t
      m = @input[t]
      m = (m.nil? || (m.length == 0)) ? 0 : m
      Integer( m )
    end

    def get_offer t
      @input[t].to_a.map { |e| Integer(e) }
    end
  end
end


require 'mongrel'
require 'mongrel/camping'
require 'monopoly_handler'
if __FILE__ == $0
  config = Mongrel::Configurator.new :host => options[:host] do
    listener :port => options[:port] do
      debug "/", what = [:access]
      debug "/interface/", what = [:access]
      uri "/static", :handler => Mongrel::DirHandler.new("static")
      uri "/favicon.ico", :handler => Mongrel::Error404Handler.new("")
      uri "/interface/", :handler => Mongrel::Camping::CampingHandler.new(Interface)
      uri "/", :handler => Mongrel::MonopolyHandler.new() { Interface::get_network }
    end
  end
  puts "Starting server on #{options[:host]}:#{options[:port]}..."
  if options[:default]
    Interface::set_core( Monopoly::Core.new( :rules => 'buxter' ) )
    Interface::set_player Interface::get_network.new_local_player('Default Player')
    puts "Starting default game"
  end
  config.run.join()
end
