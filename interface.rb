#!/usr/local/bin/ruby
$: << "./lib"
require 'rubygems'
require 'camping'
require 'cookie_sessions'
require 'network'

begin
  require 'erubis'
  ERB = Erubis::Eruby
rescue
  require 'erb'
end

require 'core'

$core = nil

Camping.goes :Interface

module Interface
  include Camping::CookieSessions
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
end

module Interface::Controllers

   # The root slash shows the `index' view.
  class Index < R '/'
    def get
      @error = @state.delete(:error) || false
      if Interface::get_core.nil?
        @rules = Monopoly::available_rules
        render :index
      else
        @core = Interface::get_core
        @network = Interface::get_network
        render :game
      end
    end
  end

  class Connect < R '/connect'
    def post
      if (@input[:name].length > 0) && (@input[:address].length > 0)
        render :connect
      else
        @state[:error] = 'Введите адрес сервера и желаемое имя пользователя'
        redirect Index
      end
    end
  end

  class NewGame < R '/new_game'
    def post
      if ( @input[:rules].length > 0 )
        Interface::set_core( Monopoly::Core.new( :rules => @input[:rules] ) )
      else
        @state[:error] = 'Необходимо выбрать правила'
      end
      redirect Index
    end
  end
end


require 'mongrel'
require 'mongrel/camping'
require 'monopoly_handler'
if __FILE__ == $0
  config = Mongrel::Configurator.new :host => "ibook.local" do
    listener :port => 3000 do
      debug "/", what = [:access]
      debug "/interface/", what = [:access]
      uri "/static", :handler => Mongrel::DirHandler.new("static")
      uri "/favicon.ico", :handler => Mongrel::Error404Handler.new("")
      uri "/interface/", :handler => Mongrel::Camping::CampingHandler.new(Interface)
      uri "/", :handler => Mongrel::MonopolyHandler.new() { Interface::get_network }
    end
  end
  puts "Starting server on port 3000..."
  config.run.join()
end