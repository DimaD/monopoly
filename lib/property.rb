require 'ostruct'

class Property < OpenStruct

  def kickback
    return 0 if !owner
    self.factories ||= 0
    return self.send( "Rent#{self.factories}" ) if self.factories >= 0 and self.factories <= 3;
    return 0;
  end

  def to_js
    {
      'owner' => owner,
      'Factories' => self.factories,
      'Id' => self.Id,
      'PropertyId' => self.Id,
      'Name' => self.Name,
      'GroupId' => self.GroupId,
      'Price' => self.Price,
      'Rent0' => self.Rent0,
      'Rent1' => self.Rent1,
      'Rent2' => self.Rent2,
      'Rent3' => self.Rent3
    }
  end
end