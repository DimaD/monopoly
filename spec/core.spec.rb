require File.dirname(__FILE__) + '/spec_helper'
require 'core'

describe Monopoly::Core do
  
  before(:all) do
    @game = Monopoly::Core.new
  end
  
  it "should save game" do
    @game.should respond_to(:save_game)
  end
end
