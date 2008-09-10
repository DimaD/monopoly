#!/usr/bin/env ruby
#
#  Created by Dmitriy Dzema on 2007-09-22.
#  Copyright (c) 2007. All rights reserved.
#   
#   Command line parameters:
#     game - game file to use. Game files are storing in .conf/ subfolder
#     mode - game mode: console, client, check
# 
#####
$: << "./lib"

require 'rubygems'
require File.dirname(__FILE__) + '/core_extensions/extend'
require "lib/server"
require 'eventmachine'

EventMachine::run {
  EventMachine::start_server "localhost", 8080, MonopolyServer
  puts "Start listening ..."
}