#!/usr/local/bin/ruby
$: << "./lib"
require 'optparse'

options = {
  :port => 9999,
  :address => 'localhost',
  :host => 'localhost:8080',
  :name => 'Greedy Bot'
}

OptionParser.new("Dmitiry Dzema monopoly greedy robot client.") do |opts|
  opts.on("-p", "--port PORT", "Port to bind") do |p|
    options[:port] = Integer(p)
  end
  opts.on("--host HOST:PORT", "Host and port to connect") do |p|
    options[:host] = p
  end
  opts.on("-n", "--name NAME", "Bot name") do |p|
    options[:name] = p
  end
  opts.on("-a", "--address ADDRESS", "BOT ip to bind to") do |p|
    options[:address] = p
  end
  
end.parse!

$options = options

def get_network
  return $network if !$network.nil?
  ( $core, $network ) = connect_to_server
  $network
end

def connect_to_server
  GreedyNetwork.connect_to_server $options[:host], $options[:name], $options[:port]
end

if __FILE__ == $0
  require "rubygems"
  require 'monopoly_handler'
  require 'mongrel'
  require 'greedy_network'
  config = Mongrel::Configurator.new :host => options[:address] do
    listener :port => options[:port] do
      debug "/", what = [:access]
      uri "/", :handler => Mongrel::MonopolyHandler.new() { get_network }
    end
  end
  begin
    puts "Starting bot on port #{options[:port]}..."
    get_network

    c = config.run
    t = Thread.new do
      while true
        sleep(2)
        if get_network.finished
          config.stop
          puts get_network.local_bankrupt ? "I have lost. Excuse me, master." : "I have won"
          exit
        end
      end
    end
    c.join()
    t.join()
  rescue Errno::ECONNREFUSED => e
    puts "Не могу соединиться с сервером #{$options[:host]}"
  rescue Exception => e
    puts e.message
  end
end
