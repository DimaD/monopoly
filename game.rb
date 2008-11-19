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

require "lib/server"
require 'core'

core = Monopoly::Core.new( :rules => 'default' )

start_monopoly_server core
p 123123