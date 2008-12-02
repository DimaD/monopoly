class NonImplemented < Exception
end

class MonopolyCheckException < Exception
end

class MonopolyGameError < Exception
end

class NoFile < Exception
  attr_reader :file
  
  def initialize(file)
    @file = file
  end
end