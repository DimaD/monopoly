module MHelpers

  def get_position i
    Interface.get_core.get_position(i)
  end

  def class_for_pos position
    if position.IsJail
      "jail"
    elsif position.IsEvent
      "event"
    elsif position.PropertyId == -1
      "service"
    else
      "property group_#{position.property.GroupId}"
    end
  end

  def name_for_pos position
    if position.IsJail
      "Тюрьма"
    elsif position.IsEvent
      "Событие"
    elsif position.PropertyId == -1
      position.Id == 0 ? ">Начало" : "пустое поле"
    else
      position.property.Name
    end
  end
end
