def _substitute_address pls, address
  pls.each { |pl| pl["Ip"] = address if pl["Ip"] == '-1'  }
end

module Reports
  def report_players pl
    [ 200, { "Content-Type" => 'application/javascript' },
      JSON.pretty_generate( { "GetPlayers" => pl} )
    ]
  end

  def report_player_exist
    report_error 'player from this addresss already joined'
  end

  def report_join id
    [ 200, { "Content-Type" => 'application/javascript' },
      JSON.pretty_generate( { "Join" => { "Id" => id,"Rules" => @core.plain_rules, "State" => @core.state} } )
    ]
  end

  def report_player_unknown
    report_error "Unknown player. Maybe you forget to Join me?"
  end
  
  def report_error message
    [ 200, { "Content-Type" => 'application/javascript' },
      JSON.pretty_generate({
        'Error' => {
          'Code'  => 200,
          'Message' => message
    }})]
    
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
