#!/usr/local/bin/ruby
$: << "./lib"
require 'rubygems'
require 'camping'
require 'cookie_sessions'

begin
  require 'erubis'
  ERB = Erubis::Eruby
rescue
  require 'erb'
end

require 'core'

Camping.goes :Interface

module Interface
  include Camping::CookieSessions
  @@state_secret = "JI0ZspUChfzIyGwlfjRJI0ZspUChfzIyGwlfjRuv8CCVXhrJZmOlxYMrPGTznUhnAEzGpuv8CCVXhrJZmOlxYMrPGJI0ZspUChfzIyGwlfjRuv8CCVXhrJZmOlxYMrPGTznUhnAEzGpTznUhnAEzGp";
  def render(m, layout=true)
    content = ERB.new(IO.read("templates/#{m}.html.erb")).result(binding)
    content = ERB.new(IO.read("templates/layout.html.erb")).result(binding) if layout
    return content
  end
end

module Interface::Controllers

   # The root slash shows the `index' view.
  class Index < R '/'
    def get
      @error = @state.delete(:error) || false
      @rules = Monopoly::available_rules
      render :index 
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
end


require 'mongrel'
require 'mongrel/camping'

if __FILE__ == $0
  config = Mongrel::Configurator.new :host => "localhost" do
    listener :port => 3000 do
      debug "/", what = [:access]
      uri "/static", :handler => Mongrel::DirHandler.new("static")
      uri "/favicon.ico", :handler => Mongrel::Error404Handler.new("")
      uri "/", :handler => Mongrel::Camping::CampingHandler.new(Interface)
    end
  end
  puts "Starting server on port 3000..."
  config.run.join()
end