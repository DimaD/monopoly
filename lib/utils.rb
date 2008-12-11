def _substitute_address pls, address
  pls.each { |pl| pl["Ip"] = address if pl["Ip"] == '-1'  }
end

def _get_rand
  rand(6) + 1
end

module Reports
  def report_players pl
    [ 200, { "Content-Type" => 'application/javascript' },
      { "GetPlayers" => pl}.to_json
    ]
  end

  def report_player_exist
    report_error 'player from this addresss already joined'
  end

  def report_join id, rules, state
    [ 200, { "Content-Type" => 'application/javascript' },
      { "Join" => { "Id" => id,"Rules" => rules, "State" => state} }.to_json
    ]
  end

  def report_state state
    report_json( { 'State' => state } )
  end

  def report_player_unknown
    report_error "Unknown player. Maybe you forget to Join me?"
  end

  def report_game_started
    report_error "Game have already started. You are too late."
  end

  def report_not_started
    report_error "Game has'not started yet"
  end

  def report_dices d1, d2
    report_json( { 'ThrowDice' => { 'Dice1' => d1, 'Dice2' => d2 } } )
  end

  def report_wrong_dices
    report_error "You dices differs from previous call. Maybe you are the cheater?"
  end

  def report_error message
    [ 200, { "Content-Type" => 'application/javascript' },
      {
        'Error' => {
          'Code'  => 200,
          'Message' => message
    }}.to_json]
    
  end

  def report_json obj
    p obj
    [ 200, { "Content-Type" => 'application/javascript' }, obj.to_json ]
  end

  def ok
    [200, { "Content-Type" => 'text/plain' }, "OK\n"]
  end

  def error404
    [ 404, { "Content-Type" => 'text/plain' }, "404 Not Found\n"]
  end

  def error500 message=''
    [ 500, { "Content-Type" => 'text/plain' }, message]
  end

  def error_params
    report_error 'Wrong parameters'
  end
end
