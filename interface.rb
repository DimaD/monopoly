#!/usr/local/bin/ruby
$: << "./lib"
require 'optparse'
require 'rubygems'
require 'camping'
require 'cookie_sessions'
require 'network'
require 'mhelpers'

begin
  require 'erubis'
  ERB = Erubis::Eruby
rescue
  require 'erb'
end

require 'core'

options = {
  :port => 8080,
}

OptionParser.new("Dmitiry Dzema monopoly client.") do |opts|
  opts.on("-p", "--port PORT", "Port to bind") do |p|
    options[:port] = Integer(p)
  end
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

  def self.get_core
    $core || nil
  end

  def self.get_network
    $network || nil
  end

  def self.set_core c
    $core = c
    $network = Monopoly::Network.new( c )
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
      if Interface::get_core.nil?
        @rules = Monopoly::available_rules
        render :index
      else
        @core = Interface::get_core
        @network = Interface::get_network
        @player  = Interface::get_player
        @field_map = Interface::get_field_map
        render :game
      end
    end
  end

  class Connect < R '/connect'
    def post
      if correct_input?
        Interface::connect_to_server(@input[:address], @input[:name])
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
end


require 'mongrel'
require 'mongrel/camping'
require 'monopoly_handler'
if __FILE__ == $0
  config = Mongrel::Configurator.new :host => "localhost" do
    listener :port => options[:port] do
      debug "/", what = [:access]
      debug "/interface/", what = [:access]
      uri "/static", :handler => Mongrel::DirHandler.new("static")
      uri "/favicon.ico", :handler => Mongrel::Error404Handler.new("")
      uri "/interface/", :handler => Mongrel::Camping::CampingHandler.new(Interface)
      uri "/", :handler => Mongrel::MonopolyHandler.new() { Interface::get_network }
    end
  end
  puts "Starting server on port #{options[:port]}..."
  if options[:default]
    Interface::set_core( Monopoly::Core.new( :rules => 'buxter' ) )
    Interface::set_player Interface::get_network.new_local_player('Default Player')
    puts "Starting default game"
  end
  config.run.join()
end
