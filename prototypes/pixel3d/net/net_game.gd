# PROTOTYPE - NOT FOR PRODUCTION
extends Node
## Fachada de integração: o protótipo (pixel3d_demo/pixel3d_adventure) só fala com esta
## classe. Ela encapsula NetClient (transporte, predição, interpolação) e NetWorldView
## (visual das entidades remotas).
##
## Uso no jogo (ver patch no README do servidor):
##   var net := NetGame.new()
##   add_child(net)
##   net.start_from_args(args, world_root, label_factory)   # --connect=host:porta --user= --pass=
##   # todo quadro: net.send_move(input, dodge_apertado); _player.global_position = net.local_position()
##   # ações:       net.fire_at(id_alvo, ponto); net.blink_to(ponto); net.ring(); net.drink("hp")

signal online_started(welcome: Dictionary)
signal online_failed(reason: String)
signal connection_lost(reason: String)
signal remote_spawned(id: int, info: Dictionary)
signal remote_despawned(id: int)
## Bloco "me" do servidor: hp, max_hp, mana, max_mana, level, xp, xp_req, pot_hp, pot_mana,
## cd_fire, cd_blink, cd_ring, cd_potion, effects (bits; use effect_names()).
signal stats_changed(me: Dictionary)
## Eventos do servidor: damage, kill, level, death, blink, refused (feedback visual), error, kicked.
signal combat_event(ev: Dictionary)
signal chat_received(msg: Dictionary)
signal friends_updated(list: Dictionary)
signal friend_event(ev: Dictionary)

const NetClient := preload("res://prototypes/pixel3d/net/net_client.gd")
const NetConfig := preload("res://prototypes/pixel3d/net/net_config.gd")
const Protocol := preload("res://prototypes/pixel3d/net/net_protocol.gd")
const WorldView := preload("res://prototypes/pixel3d/net/net_world_view.gd")

var client: Node
var view: Node3D


func _ready() -> void:
	if client == null:
		_make_client()


func _make_client() -> void:
	client = NetClient.new()
	client.name = "NetClient"
	add_child(client)
	client.logged_in.connect(func(w: Dictionary) -> void: online_started.emit(w))
	client.login_failed.connect(func(code: String) -> void: online_failed.emit(code))
	client.disconnected.connect(func(r: String) -> void: connection_lost.emit(r))
	client.entity_entered.connect(func(info: Dictionary) -> void: remote_spawned.emit(int(info.get("id", 0)), info))
	client.entity_left.connect(func(id: int) -> void: remote_despawned.emit(id))
	client.stats_changed.connect(func(me: Dictionary) -> void: stats_changed.emit(me))
	client.event_received.connect(func(ev: Dictionary) -> void: combat_event.emit(ev))
	client.chat_received.connect(func(m: Dictionary) -> void: chat_received.emit(m))
	client.friends_changed.connect(func(l: Dictionary) -> void: friends_updated.emit(l))
	client.friend_event.connect(func(ev: Dictionary) -> void: friend_event.emit(ev))


## Lê "--connect=host:porta", "--user=", "--pass=", "--register". Devolve false se não houver --connect.
func start_from_args(args: Dictionary, world_root: Node3D = null, label_factory: Callable = Callable()) -> bool:
	if not args.has("connect"):
		return false
	var hp := parse_address(String(args.connect))
	start(String(hp[0]), int(hp[1]), String(args.get("user", "")), String(args.get("pass", "")), args.has("register"), world_root, label_factory,
		String(args.get("vocation", args.get("class", ""))))
	return true


static func parse_address(s: String) -> Array:
	var host := s
	var port := 7777
	var i := s.rfind(":")
	if i > 0 and s.substr(i + 1).is_valid_int():
		host = s.substr(0, i)
		port = int(s.substr(i + 1))
	return [host, port]


## `vocation` (mage|warrior|archer) só vale para personagem novo; a confirmada vem em `vocation()`.
func start(host: String, port: int, user: String, password: String, register := false, world_root: Node3D = null, label_factory: Callable = Callable(), vocation := "") -> void:
	if client == null:
		_make_client()
	if world_root != null:
		view = WorldView.new()
		view.name = "NetWorldView"
		view.label_factory = label_factory
		world_root.add_child(view)
	client.connect_and_login(host, port, user, password, register, vocation)


func is_online() -> bool:
	return client != null and client.is_in_game()


func _process(_delta: float) -> void:
	if view != null and is_online():
		view.sync_entities(client.entities())


# ------------------------------------------------------------------ entrada (cliente → servidor)

## Chamar todo quadro com a direção WASD (x direita, y para baixo) e se a esquiva foi apertada.
func send_move(dir: Vector2, dodge := false) -> void:
	client.set_move(dir, dodge)


## Ataque básico: alvo (id de entidade do servidor, 0 = nenhum) ou ponto no chão.
func fire_at(target_id: int, point: Vector3) -> void:
	client.action("fire", {"target": target_id, "x": point.x, "z": point.z})


func blink_to(point: Vector3) -> void:
	client.action("blink", {"x": point.x, "z": point.z})


func ring() -> void:
	client.action("ring")


## Q da vocação: Eco (mago, ponto de destino), Investida (guerreiro, direção) ou
## Salto Evasivo (arqueiro, salta para TRÁS da mira). O servidor move e manda o evento "dash"/"blink".
func q_at(point: Vector3) -> void:
	client.action("q", {"x": point.x, "z": point.z})


## R da vocação: Anel (mago), Redemoinho (guerreiro) ou Flecha Perfurante (arqueiro, mira em `point`).
func r_at(point: Vector3) -> void:
	client.action("r", {"x": point.x, "z": point.z})


## Vocação confirmada pelo servidor no login.
func vocation() -> String:
	return client.vocation if client != null else "mage"


func drink(kind: String) -> void:
	client.action("potion", {"kind": kind})


## Core skill de luz: o servidor liga o efeito "light" (visto por todos).
func cast_light() -> void:
	client.action("light")


func say(channel: String, text: String, to := "") -> void:
	client.chat(channel, text, to)


func friend(op: String, other := "") -> void:
	client.friend(op, other)


func logout() -> void:
	client.logout()


# ------------------------------------------------------------------ leitura (servidor → jogo)

## Posição do jogador local para desenhar (prevista + correção suave).
func local_position() -> Vector3:
	return client.local_position()


func local_yaw() -> float:
	return client.local_yaw()


func is_dodging() -> bool:
	return client.is_dodging()


func me() -> Dictionary:
	return client.me


## Entidades remotas interpoladas: {id, kind, sub, name, pos, yaw, hp, max_hp, effects: Array[String]}.
func entities() -> Array:
	return client.entities()


## Id da entidade do servidor ligada a um nó visual (para mirar com o mouse), ou 0.
func entity_id_of(node: Node) -> int:
	return int(node.get_meta("net_id", 0)) if node != null else 0


static func effect_names(bits: int) -> Array[String]:
	return Protocol.effect_names(bits)
