#!/usr/local/bin/ruby
require 'rubygems'
require 'camping'
require 'mongrel'
require 'mongrel/camping'

begin
  require 'erubis'
  ERB = Erubis::Eruby
rescue
  require 'erb'
end

Camping.goes :Interface

module Interface
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
      render :index 
    end
  end

  class Connect < R '/connect'
    def post
      render :posted
    end
  end
end

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