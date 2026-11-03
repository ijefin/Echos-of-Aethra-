class_name NetSession
extends Node
## Sessão de jogo: sozinho (offline), hospedar (listen server ENet) ou entrar por IP.
## O host é o servidor autoritativo (CombatWorld valida tudo); os clientes só enviam
## input/pedidos. Para jogar pela internet, o host precisa liberar a porta UDP
## (redirecionamento no roteador) ou os dois usarem uma VPN de jogo (Radmin, ZeroTier,
## Tailscale).
##
## Uso:
##   var net := NetSession.new()
##   net.name = "Net"
##   add_child(net)
##   net.setup(clearing, cfg)
##   net.host(7777, "Jeff", "warrior")

## O jogador local entrou no mundo.
signal started
## Texto de status para a tela inicial/HUD ("Conectando…", "Falha na conexão"...).
signal status_changed(text: String)
## A mochila ou o equipamento do jogador local mudou (painel de inventário redesenha).
signal inventory_changed
## Aviso curto do servidor para o jogador local ("Sua classe não pode usar isto").
signal notice(text: String)

## peer_id → {"name": String, "class": String, "equip": {slot → item}}
var players_info: Dictionary = {}
## Inventário de cada jogador (só no servidor): peer → Inventory.
var inventories: Dictionary = {}
## Espelho da mochila do jogador local, enviado pelo servidor.
var local_items: Array = []
var mode := ""
var port := 7777

var _clearing: TrainingClearing
var _cfg: Dictionary
var _playable: Array = []


func setup(clearing: TrainingClearing, cfg: Dictionary, playable: Array) -> void:
	_clearing = clearing
	_cfg = cfg
	_playable = playable
	port = int(cfg.get("default_port", 7777))


func start_solo(player_name: String, cls: String) -> void:
	mode = "solo"
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_begin_server(player_name, cls)


## Abre o servidor na porta dada. Devolve "" ou a mensagem de erro.
func host(port_number: int, player_name: String, cls: String) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port_number, int(_cfg.get("max_players", 8)))
	if err != OK:
		return "Não foi possível abrir a porta %d (%s)" % [port_number, error_string(err)]
	mode = "host"
	port = port_number
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_begin_server(player_name, cls)
	return ""


## Conecta a um host. Devolve "" ou a mensagem de erro imediata.
func join(address: String, port_number: int, player_name: String, cls: String) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port_number)
	if err != OK:
		return "Endereço inválido (%s)" % error_string(err)
	mode = "client"
	port = port_number
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func() -> void:
		status_changed.emit("Conectado. Entrando no mundo…")
		register.rpc_id(1, player_name, cls))
	multiplayer.connection_failed.connect(func() -> void:
		status_changed.emit("Falha na conexão com %s:%d" % [address, port_number]))
	multiplayer.server_disconnected.connect(func() -> void:
		status_changed.emit("O host encerrou a partida"))
	status_changed.emit("Conectando a %s:%d…" % [address, port_number])
	return ""


## Endereços IPv4 desta máquina (para o host passar ao amigo).
static func local_addresses() -> Array[String]:
	var out: Array[String] = []
	for a: String in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


func _begin_server(player_name: String, cls: String) -> void:
	_clearing.combat.start_server_world()
	_server_add_player(1, player_name, cls)


## Cliente pede para entrar (servidor).
@rpc("any_peer", "call_remote", "reliable")
func register(player_name: String, cls: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if cls not in _playable:
		cls = String(_playable[0])
	for other: int in players_info:
		var info: Dictionary = players_info[other]
		var avatar := _clearing.combat.avatar_of(other)
		spawn_player.rpc_id(peer, other, String(info.name), String(info["class"]), avatar.global_position if avatar else Vector2.ZERO)
		set_equipment.rpc_id(peer, other, info.get("equip", {}))
	_clearing.combat.send_world_to(peer)
	_server_add_player(peer, player_name.substr(0, 16), cls)


func _server_add_player(peer: int, player_name: String, cls: String) -> void:
	var spawn: Array = _cfg.get("player_spawn", [800, 660])
	var spread := float(_cfg.get("spawn_spread_px", 24))
	var pos := Vector2(spawn[0], spawn[1]) + Vector2(randf_range(-spread, spread), randf_range(-spread * 0.5, spread * 0.5))
	spawn_player.rpc(peer, player_name, cls, pos)
	_init_inventory(peer, cls)


@rpc("authority", "call_local", "reliable")
func spawn_player(peer: int, player_name: String, cls: String, pos: Vector2) -> void:
	if players_info.has(peer):
		return
	players_info[peer] = {"name": player_name, "class": cls}
	_clearing.spawn_player(peer, player_name, cls, pos)
	if peer == multiplayer.get_unique_id():
		started.emit()


## Próxima classe jogável depois de `cls` (ciclo da tecla C).
func next_class(cls: String) -> String:
	var i := _playable.find(cls)
	return String(_playable[(i + 1) % _playable.size()])


## Jogador pede para trocar de classe (servidor): respawna no mesmo lugar com a nova classe.
@rpc("any_peer", "call_local", "reliable")
func request_class(cls: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = 1
	if cls not in _playable or not players_info.has(peer):
		return
	var avatar := _clearing.combat.avatar_of(peer)
	var pos := avatar.global_position if avatar else Vector2.ZERO
	var player_name := String(players_info[peer].name)
	despawn_player.rpc(peer)
	spawn_player.rpc(peer, player_name, cls, pos)
	_init_inventory(peer, cls)


# ------------------------------------------------------------------ itens (servidor autoritativo)

## GiveItems — API do servidor: põe itens na mochila de `peer` e avisa o dono. Funciona
## para itens ainda sem sprite (os atributos valem ao vestir). Retorna os ids aceitos;
## desconhecidos e o que passar da capacidade são recusados.
##   net.give_items(peer, ["ember_amulet", "wanderer_boots"])
func give_items(peer: int, ids: Array) -> Array[String]:
	if not multiplayer.is_server() or not inventories.has(peer):
		return []
	var got := (inventories[peer] as Inventory).give(ids)
	if not got.is_empty():
		_push_inventory(peer)
	return got


## Mochila nova da classe: recebe e veste os "starter_items" de combat_classes.json.
func _init_inventory(peer: int, cls: String) -> void:
	var def: Dictionary = _clearing.combat.classes.get(cls, {})
	var inv := Inventory.new(Inventory.load_db(), cls)
	inventories[peer] = inv
	for id: String in inv.give(def.get("starter_items", [])):
		inv.equip(id)
	_push_inventory(peer)


## Manda a mochila ao dono e o equipamento a todos.
func _push_inventory(peer: int) -> void:
	var inv: Inventory = inventories[peer]
	inventory_state.rpc_id(peer, inv.items)
	set_equipment.rpc(peer, inv.equipped)


func _sender_peer() -> int:
	var peer := multiplayer.get_remote_sender_id()
	return 1 if peer == 0 else peer


## Jogador pede para vestir um item da própria mochila (servidor valida classe/slot).
@rpc("any_peer", "call_local", "reliable")
func request_equip(item_id: String) -> void:
	if not multiplayer.is_server() or not inventories.has(_sender_peer()):
		return
	var peer := _sender_peer()
	var err := (inventories[peer] as Inventory).equip(item_id)
	if err != "":
		inventory_notice.rpc_id(peer, err)
		return
	_push_inventory(peer)


## Jogador pede para tirar o item de um slot (volta para a mochila).
@rpc("any_peer", "call_local", "reliable")
func request_unequip(slot: String) -> void:
	if not multiplayer.is_server() or not inventories.has(_sender_peer()):
		return
	var peer := _sender_peer()
	if (inventories[peer] as Inventory).unequip(slot):
		_push_inventory(peer)
	else:
		inventory_notice.rpc_id(peer, "Mochila cheia")


## Ferramenta de teste: dá ao jogador os "test_items" da classe dele.
@rpc("any_peer", "call_local", "reliable")
func request_test_items() -> void:
	if not multiplayer.is_server() or not players_info.has(_sender_peer()):
		return
	var peer := _sender_peer()
	var def: Dictionary = _clearing.combat.classes.get(String(players_info[peer]["class"]), {})
	var got := give_items(peer, def.get("test_items", []))
	inventory_notice.rpc_id(peer, "Recebeu %d itens" % got.size() if not got.is_empty() else "Nada recebido (mochila cheia?)")


@rpc("authority", "call_local", "reliable")
func inventory_state(items: Array) -> void:
	local_items = items
	inventory_changed.emit()


@rpc("authority", "call_local", "reliable")
func inventory_notice(text: String) -> void:
	notice.emit(text)


## Equipamento de `peer` (todos os peers): visual do avatar e atributos do kit.
@rpc("authority", "call_local", "reliable")
func set_equipment(peer: int, equipped: Dictionary) -> void:
	if not players_info.has(peer):
		return
	players_info[peer]["equip"] = equipped
	var view := Inventory.new(Inventory.load_db(), String(players_info[peer]["class"]))
	view.equipped = equipped
	var avatar := _clearing.combat.avatar_of(peer)
	if avatar != null:
		avatar.show_gear(equipped)
	var p: Dictionary = _clearing.combat.players.get(peer, {})
	if p.has("kit"):
		(p.kit as ClassKit).apply_gear(view.bonus())
	if peer == multiplayer.get_unique_id():
		inventory_changed.emit()


@rpc("authority", "call_local", "reliable")
func despawn_player(peer: int) -> void:
	players_info.erase(peer)
	inventories.erase(peer)
	_clearing.despawn_player(peer)


func _on_peer_disconnected(peer: int) -> void:
	if multiplayer.is_server() and players_info.has(peer):
		despawn_player.rpc(peer)
