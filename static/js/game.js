players_icons = [ 
  "player1.png", "player2.png",  "player3.png", "player4.png", 
  "player5.png", "player6.png", "player7.png", "player8.png" ];

var _positions = {}
var _positions_by_properties = {}
function load_positions(positions){
  for (var i=0; i < positions.length; i++) {
    var pos = positions[i];
    _positions[pos.Id] = pos;
    _positions_by_properties[pos.PropertyId] = pos;
  }
}

var _players = []
var _players_i = {}
function load_players(players){
  var l = players_icons.length;
  for (var i = 0; i < players.length; i++) {
    var pl = players[i]["Player"];
    pl.icon = players_icons[ (pl.Id-1) % 10 ];
    add_player(pl)
  }
}

function show_players_icons(){
  $('.player_info').each(function(){
    var id = parseInt(this.id.replace('player_info_', ''))
    var pl = _players_i[id]
    $(this).prepend( $("<img />").attr({ src: '/static/img/' + players_icons[ (pl.Id-1) % 10 ]}) )
  });
}

function add_player(pl){
  // if (_players_i[pl.Id])
  //   return;

  _players.push(pl);
  _players_i[pl.Id] = pl;
  if (pl.Possession) {
    for (var i=0; i < pl.Possession.length; i++) {
      p = pl.Possession[i];
      _properties[p.PropertyId]["owner"] = pl;
      _properties[p.PropertyId]["factories"] = p.Factories || 0;
      _properties[p.PropertyId]["deposit"] = p.Deposit;
    }
  }

  var img = document.createElement('img');
  img.id = 'player_' + pl.Id;
  img.src = '/static/img/' + pl.icon;
  img.style.display = 'none';
  img.className = 'player';
  img.title = pl.Name;
  document.body.appendChild(img);
  display_player(pl);
}

function player_tooltip () {
  var id = parseInt(this.id.replace('player_', ''));
  var pl = _players_i[id];
  var str = '<h3>' + pl.Name + '</h3>';
  str += '<div class="body">';
    str += 'Наличные: ' + pl.Cash;
  
  str += '</div>';
  return str;
}

function display_player(pl){
  var pli = $('#player_' + pl.Id);
  var pos = $('#position_' + pl.PositionId);
  if (!pos)
    return;
  
  var e = pli.remove();
  pos.append(e);
  e.show();
}

var _properties_positions = {};
var _properties = {};
function load_properties(properties){
  for (var i = 0; i < properties.length; i++) {
    var pr = properties[i];

    _properties_positions[_positions_by_properties[pr.Id].Id] = pr;
    _properties[pr.Id] = pr;
  }
}

function property_tooltip(){
  var id = parseInt(this.id.replace('position_', ''));
  var prop = _properties_positions[id];
  var str = '<h3>' + prop.Name + '</h3>';
  str += '<div class="body">';
    if (prop.owner) {
      str += '<p>Хозяин: ' + prop.owner.Name + '</p>';
      str += '<p>Стоимость посещения: <strong>' + visiting_price(prop) + '</strong> (' + prop.factories + ')</p>';
      if (prop.deposit)
        str += '<p><strong>заложена в банк</strong></p>';
    }
    str += '<p>Цена: <strong>' + prop.Price + '</strong></p>';
    str += '<p>Цена посещения без магазинов: '  + prop.Rent0 + '</p>';
    str += '<p>Цена за 1 магазин: ' + prop.Rent1 + '</p>';
    str += '<p>Цена за 2 магазина: '  + prop.Rent2 + '</p>';
    str += '<p>Цена за 3 магазина: '  + prop.Rent3 + '</p>';
  str += '</div>';
  return str;
}

function visiting_price(prop) {
  if (prop.deposit) {
    return 0;
  } else {
    return prop['Rent' + prop.factories];
  }
}

function load_trade_offers(offers){
  set_reload_lock();
  jQuery.facebox(gen_offers_html(offers));
}

function gen_offers_html(offers) {
  var str = "";
  for (var i=0; i < offers.length; i++) {
    var offer = offers[i];
    str += gen_offer_html(offer);
  }
  return str;
}

function gen_offer_html(offer){
  var res = "<form action='offer/" + offer.id + "' method='POST'>";
  res += "<h3>Предложение от игрока " + offer.from + "</h3>";
  res += "<h4>Предлагает</h4>";
    if (offer.give.Cash != 0)
      res += "деньги: " + offer.give.Cash + " у.е.<br></br>";
    if (offer.give.PropertyIDs.length > 0)
      res += "карточки: " + gen_names_for_properties(offer.give.PropertyIDs);
  res += "<h4>Просит</h4>";
  if (offer.wants.Cash != 0)
    res += "деньги: " + offer.wants.Cash + " у.е.<br></br>";
  if (offer.wants.PropertyIDs.length > 0)
    res += "карточки: " + gen_names_for_properties(offer.wants.PropertyIDs) + "<br></br>";
  res += "<input type='submit' name='sOk' value='Принять'></imput>&nbsp;<input type='submit' name='sCancel' value='Отказать'></input></form>";
  return res;
}

function gen_names_for_properties(ids){
  props = [];
  for (var i=0; i < ids.length; i++)
    props.push(_properties[ids[i]].Name);
  return props.join(", ")
}

function set_reload_lock(){
  console.log('set')
  _mega_lock = true;
}

function free_reload_lock(){
  console.log('unset')
  _mega_lock = false;
}

function try_to_reload(){
  if (!_mega_lock)
    location.reload(true);
}

function check_modified(last){
  $.get('is_updated', { 'since': last }, function(data){
    if (data == 'true')
      try_to_reload();
    setTimeout(function(){ check_modified(last); }, 2000);
  });
}

function load_last_modified(last){
  _mega_lock = false;
  $(document).bind('init.facebox', set_reload_lock );
  $(document).bind('close.facebox', free_reload_lock);
  
  $(function(){
    setTimeout(function(){ check_modified(last); }, 2000);
  });
}

$(function(){
  $(document).bind('fancybox.close', free_reload_lock);
  $(document).bind('fancybox.start', set_reload_lock);
  $('.make_offer').each(function(){
    var id = parseInt( this.id.replace('offer_', '') )
    $(this).show();
    $(this).fancybox({
      'frameWidth' : 610,
      'overlayShow': true,
      'itemLoadCallback': function(opts){ 
        opts.itemArray.push( { 'url': 'offerwith/' + id, title: "Предложить сделку" });
      }
    });
  });

});