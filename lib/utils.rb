def _substitute_address pls, address
  pls.each { |pl| pl["Ip"] = address if pl["Ip"] == '-1'  }
end
