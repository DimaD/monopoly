#!/usr/local/bin/ruby
$: << "./lib"
require 'optparse'
require 'rubygems'
require 'mongrel'
require 'monopoly_handler'

require 'cookie_sessions'
require 'greedy_network'
require 'mhelpers'
require "delegate"
require 'core'

options = {
  :port => 9999,
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
    options[:name] = name
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
  config = Mongrel::Configurator.new :host => "localhost" do
    listener :port => options[:port] do
      debug "/", what = [:access]
      uri "/static", :handler => Mongrel::DirHandler.new("static")
      uri "/", :handler => Mongrel::MonopolyHandler.new() { get_network }
    end
  end
  puts "Starting bot on port #{options[:port]}..."
  get_network
  config.run.join()
end
