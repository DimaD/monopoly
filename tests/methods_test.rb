require "test/unit"
require "core"

class TestMethods < Test::Unit::TestCase
  def setup
    @core = Monopoly::Core.new(:save => 'default')
  end

  def check_params m, arg={}
    @core.valid_params?( m, arg )
  end

  def test_method_join
    assert( @core.allowed_method?( 'Join' ) )
  end

  def test_string
    assert( !check_params( 'Join', { 'n' => '1'} ), "n is not required for Join")
    assert( check_params( 'Join', { 'name' => '1'} ) )
  end

  def test_empty_params
    assert( !check_params( 'AssertOffer', {} ), "ID is required")
  end

  def test_int
    assert( !check_params( 'AssertOffer', { 'aaa' => '1'} ), "ID is required")
    assert( check_params( 'AssertOffer', { 'ID' => '1' } ), "ID is int for AssertOffer" )
    assert( !check_params( 'AssertOffer', { 'ID' => 'aaa' } ) )
    assert( !check_params( 'AssertOffer', { 'ID' => '-12' } ), "ID is int for AssertOffer" )
  end

  def test_int_range
    assert( check_params( 'ConfirmThrowDice',  { 'Dice1' => '1',  'Dice2' => '2',  'PositionId' => 3}))
    assert( !check_params( 'ConfirmThrowDice', { 'Dice1' => '10', 'Dice2' => '2',  'PositionId' => 3}))
    assert( !check_params( 'ConfirmThrowDice', { 'Dice1' => '-1', 'Dice2' => '2',  'PositionId' => 3}))
    assert( !check_params( 'ConfirmThrowDice', { 'Dice1' => '0',  'Dice2' => '10', 'PositionId' => 3}))
  end

  def test_array_int
    
  end
end
