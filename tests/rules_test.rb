require "test/unit"
require "rules"

class TestParser < Test::Unit::TestCase
  def setup
    @settings = Monopoly::Rules.new('tests/settings_test.txt')
  end
  
  def test_camelizing
    assert_equal(100, @settings.starting_money)
    assert_equal(0.5, @settings.factory_sell_coeff)
  end

  def test_raising
    assert_nothing_raised(Exception) { @settings.starting_money }
    assert_raise(NoMethodError) { @settings.non_existing_method }
  end

end
