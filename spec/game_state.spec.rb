require File.dirname(__FILE__) + '/spec_helper'
require 'game_state'
require 'exceptions'

describe "A Monopoly::GameState" do
  
  it "should be able to load from save" do
    Monopoly::GameState.should respond_to(:from_save)
  end
  
  it "should be able to init new state from rules" do
    Monopoly::GameState.should respond_to(:from_rules)
  end
  
  it "should rise exception if try to load from non-existing rules" do
    lambda {
      Monopoly::GameState.from_rules('jhsdfkjjsadfbjkhasdfnkjasdjfhasfdkljf.txt')
    }.should raise_error(NoFile)
  end
  
  it "should rise exception if try to load from non-existing save" do
    lambda {
      Monopoly::GameState.from_save('non_existing_savedsfdjhsdfjsdajkfksa.asdasd')
    }.should raise_error(NoFile)
  end
  
end
