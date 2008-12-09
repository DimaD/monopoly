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

function add_player(pl){
  // if (_players_i[pl.Id])
  //   return;

  _players.push(pl);
  _players_i[pl.Id] = pl;
  if (pl.Possession) {
    for (var i=0; i < pl.Possession.length; i++) {
      p = pl.Possession[i];
      console.log(p);
      _properties[p.PropertyId]["owner"] = pl;
      _properties[p.PropertyId]["factories"] = p.Factories;    
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
      str += '<p>Стоимость посещения: <strong>' + prop['Rent' + prop.factories] + '</strong> (' + prop.factories + ')</p>';
    }
    str += '<p>Цена: <strong>' + prop.Price + '</strong></p>';
    str += '<p>Цена посещения: '  + prop.Rent0 + '</p>';
    str += '<p>Цена за 1 магазин: ' + prop.Rent1 + '</p>';
    str += '<p>Цена за 2 магазина: '  + prop.Rent2 + '</p>';
    str += '<p>Цена за 3 магазина: '  + prop.Rent3 + '</p>';
  str += '</div>';
  return str;
}