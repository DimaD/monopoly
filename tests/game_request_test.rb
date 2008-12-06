require "test/unit"
require "network"

class TestParser < Test::Unit::TestCase
  def setup
    @r = Monopoly::Request.new(3030)
  end

  def test_should_cut_last_amp
    str = @r.encode_params( { 'name' => 1, 'val' => 3 } )
    assert_no_match(/&$/, str)
  end

  def test_escaping_spaces
    str = @r.encode_params( { 'name' => 'One Two' } )
    assert_match(/name=One%20Two/, str)
  end
end
