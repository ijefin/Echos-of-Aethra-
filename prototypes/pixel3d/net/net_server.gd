# PROTOTYPE - NOT FOR PRODUCTION
extends Node
## Transporte do servidor dedicado: ENet UDP cru (sem RPC/SceneMultiplayer), handshake,
## contas, sessões, rate limit, área de interesse, snapshots a taxa fixa, eventos, chat e
## amigos. Toda a regra de jogo fica em ServerWorld/AccountStore/FriendsService (puros).

const Protocol := preload("res://prototypes/pixel3d/net/net_protocol.gd")
const NetConfig := preload("res://prototypes/pixel3d/net/net_config.gd")
const World := preload("res://prototypes/pixel3d/net/server_world.gd")
const Accounts := preload("res://prototypes/pixel3d/net/account_store.gd")
const Friends := preload("res://prototypes/pixel3d/net/friends_service.gd")
const Sessions := preload("res://prototypes/pixel3d/net/session_registry.gd")
const Limiter := preload("res://prototypes/pixel3d/net/rate_limiter.gd")
const TextRules := preload("res://prototypes/pixel3d/net/text_rules.gd")
const Store := preload("res://prototypes/pixel3d/net/json_store.gd")
const Collision := preload("res://prototypes/pixel3d/net/world_collision.gd")
const Log := preload("res://prototypes/pixel3d/net/net_log.gd")
const ServerAI := preload("res://prototypes/pixel3d/net/server_ai.gd")

const TUNING_PATH := "res://prototypes/pixel3d/data/first_adventure.json"
const CLASSES_PATH := "res://prototypes/pixel3d/data/classes.json"
const CORE_SKILLS_PATH := "res://prototypes/pixel3d/data/core_skills.json"
const COLLISION_PATH := "res://prototypes/pixel3d/net/data/collision_surface.json"

var cfg: Dictionary
var world: RefCounted
var accounts: RefCounted
var friends: RefCounted
var sessions: RefCounted
var limiter: RefCounted
var logger: RefCounted
var peer: ENetMultiplayerPeer
## peer → {stage: "hello"|"auth"|"game", t0, last, addr, eid, key}
var conns: Dictionary = {}
var eid_peer: Dictionary = {}    # eid → peer
var _auth_fail: Dictionary = {}  # ip → [falhas, bloqueado_até]
var _acc := 0.0
var _snap_acc := 0.0
var _save_acc := 0.0
var _region_acc := 0.0
var _clock := 0.0
var _stats := {"in": 0, "out": 0, "in_bytes": 0, "out_bytes": 0, "kicks": 0}
var _stats_acc := 0.0
var _data_path := ""
var _floors: Dictionary = {}


func setup(config: Dictionary) -> void:
	cfg = config
	logger = Log.new(String(cfg.get("log_level", "info")))
	var tuning: Dictionary = {}
	var f := FileAccess.open(TUNING_PATH, FileAccess.READ)
	if f != null:
		var v: Variant = JSON.parse_string(f.get_as_text())
		if v is Dictionary:
			tuning = v
	var floors: Dictionary = Collision.load_floors(COLLISION_PATH, float(cfg.get("world_half", 100.0)))
	var col: RefCounted = floors[0]
	world = World.new(cfg, tuning, col, 7, Store.load_dict(CLASSES_PATH), Store.load_dict(CORE_SKILLS_PATH), floors)
	_floors = floors
	if is_inside_tree():
		_attach_ai()
	_data_path = String(cfg.get("data_dir", "user://aethra-server")).path_join("accounts.json")
	accounts = Accounts.new(cfg, Store.load_dict(_data_path))
	friends = Friends.new(accounts)
	sessions = Sessions.new(float(cfg.get("reconnect_grace_s", 120.0)))
	limiter = Limiter.new(cfg.get("rate_limits", {}), float(cfg.get("abuse_score_kick", 40)), float(cfg.get("abuse_decay_per_second", 2.0)))
	logger.write("info", "mundo: %d monstros, %d obstáculos na superfície, %d andares; contas: %d; dados em %s" % [
		world.monsters.size(), col.count(), floors.size(), accounts.accounts().size(), ProjectSettings.globalize_path(_data_path)])


## IA real do jogo num World3D headless com a colisão exportada. Precisa do nó na árvore:
## o setup() roda no _initialize do server_main (antes disso), então liga no 1º quadro.
func _attach_ai() -> void:
	if world.ai != null or not bool(cfg.get("server_ai", true)):
		return
	var holder := Node3D.new()
	holder.name = "AI"
	add_child(holder)
	world.attach_ai(ServerAI.new(holder, _floors))
	logger.write("info", "IA real dos monstros ligada (%d monstros, enemy_director)" % world.monsters.size())


## Abre a porta UDP. Devolve OK ou o erro.
func start() -> Error:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(int(cfg.port), int(cfg.max_players))
	if err != OK:
		logger.write("error", "não abriu UDP %d: %s" % [int(cfg.port), error_string(err)])
		return err
	peer.peer_connected.connect(_on_connected)
	peer.peer_disconnected.connect(_on_disconnected)
	logger.write("info", "servidor Ecos de Aethra ouvindo UDP %d (máx. %d jogadores, %d Hz, protocolo v%d)" % [
		int(cfg.port), int(cfg.max_players), int(cfg.tick_rate), Protocol.VERSION])
	return OK


func _process(delta: float) -> void:
	if peer == null:
		return
	if world.ai == null and bool(cfg.get("server_ai", true)):
		_attach_ai()
	_clock += delta
	peer.poll()
	while peer.get_available_packet_count() > 0:
		var from := peer.get_packet_peer()
		var pkt := peer.get_packet()
		_handle(from, pkt)
	var dt := 1.0 / float(cfg.tick_rate)
	_acc = minf(_acc + delta, dt * 5.0)   # servidor atrasado não entra em espiral
	while _acc >= dt:
		_acc -= dt
		world.step(dt)
		_dispatch_events()
	_snap_acc += delta
	var sdt := 1.0 / float(cfg.snapshot_rate)
	if _snap_acc >= sdt:
		_snap_acc = fmod(_snap_acc, sdt)
		_send_snapshots()
	_housekeeping(delta)


func _housekeeping(delta: float) -> void:
	_save_acc += delta
	if _save_acc >= float(cfg.get("autosave_s", 30.0)):
		_save_acc = 0.0
		save_all()
	_region_acc += delta
	if _region_acc >= 2.0:
		_region_acc = 0.0
		for p: int in conns:
			var c: Dictionary = conns[p]
			if String(c.stage) == "game" and world.players.has(int(c.eid)):
				_deliver_friend_events(friends.set_presence(String(c.key), true, world.region_of(world.players[int(c.eid)].ms.pos)))
	for key: String in sessions.expire(_clock):
		logger.write("debug", "sessão expirada: %s" % key)
	for p: int in conns.keys():
		var c: Dictionary = conns[p]
		if String(c.stage) != "game" and _clock - float(c.t0) > float(cfg.get("handshake_timeout_s", 15.0)):
			kick(p, "handshake_timeout")
		elif _clock - float(c.last) > float(cfg.get("idle_timeout_s", 30.0)):
			kick(p, "idle_timeout")
	_stats_acc += delta
	if _stats_acc >= 60.0:
		logger.write("info", "1 min: %d conectados, in %d pkts/%d B, out %d pkts/%d B, kicks %d" % [
			conns.size(), _stats["in"], _stats.in_bytes, _stats.out, _stats.out_bytes, _stats.kicks])
		_stats = {"in": 0, "out": 0, "in_bytes": 0, "out_bytes": 0, "kicks": 0}
		_stats_acc = 0.0


# ------------------------------------------------------------------ conexões

func _on_connected(id: int) -> void:
	var addr := ""
	var pp := peer.get_peer(id)
	if pp != null:
		addr = pp.get_remote_address()
	conns[id] = {"stage": "hello", "t0": _clock, "last": _clock, "addr": addr, "eid": 0, "key": ""}
	logger.write("debug", "peer %d conectou de %s" % [id, addr])


func _on_disconnected(id: int) -> void:
	_leave_world(id, false)
	conns.erase(id)
	limiter.forget(id)


## Tira o personagem do mundo e salva. `logout` = sessão encerrada (sem RESUME).
func _leave_world(id: int, logout: bool) -> void:
	var c: Dictionary = conns.get(id, {})
	if c.is_empty() or String(c.stage) != "game":
		return
	var eid := int(c.eid)
	var key := String(c.key)
	accounts.set_character(key, world.remove_player(eid))
	eid_peer.erase(eid)
	if logout:
		sessions.end_account(key)
	else:
		sessions.detach(id, _clock)
	_deliver_friend_events(friends.set_presence(key, false, ""))
	c.stage = "auth"
	save_all()
	logger.write("info", "%s saiu (%s)" % [accounts.display_name(key), "logout" if logout else "conexão caiu, aguarda RESUME"])


func kick(id: int, reason: String) -> void:
	if not conns.has(id):
		return
	_stats.kicks += 1
	logger.limited("warn", "kick:" + reason, "desconectando peer %d (%s): %s" % [id, String(conns[id].addr), reason])
	_send_control(id, Protocol.S_KICK, {"reason": reason})
	# abuso encerra a sessão (sem RESUME); queda por tempo ou login em outro lugar não
	_leave_world(id, reason not in ["replaced", "idle_timeout", "handshake_timeout"])
	conns.erase(id)
	limiter.forget(id)
	peer.disconnect_peer(id, false)   # false = envia o S_KICK antes de cair


func save_all() -> void:
	for p: int in conns:
		var c: Dictionary = conns[p]
		if String(c.stage) == "game":
			accounts.set_character(String(c.key), world.character_data(int(c.eid)))
	if not accounts.dirty:
		return
	var err: Error = Store.save(_data_path, accounts.data)
	if err == OK:
		accounts.dirty = false
	else:
		logger.limited("error", "save", "falha ao salvar %s: %s" % [_data_path, error_string(err)])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if accounts != null:
			save_all()


# ------------------------------------------------------------------ envio

func _send(id: int, pkt: PackedByteArray, reliable: bool) -> void:
	peer.set_target_peer(id)
	peer.set_transfer_channel(0)
	peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
	peer.put_packet(pkt)
	_stats.out += 1
	_stats.out_bytes += pkt.size()


func _send_control(id: int, type: int, data: Dictionary) -> void:
	_send(id, Protocol.encode_control(type, data), true)


func _error(id: int, code: String) -> void:
	_send_control(id, Protocol.S_ERROR, {"code": code})


# ------------------------------------------------------------------ recepção

func _handle(id: int, pkt: PackedByteArray) -> void:
	if not conns.has(id):
		return
	var c: Dictionary = conns[id]
	_stats["in"] += 1
	_stats.in_bytes += pkt.size()
	if pkt.size() > int(cfg.get("max_inbound_packet", 512)):
		kick(id, "oversize")
		return
	var type := Protocol.packet_type(pkt)
	if type < 0 or not Protocol.RATE_CLASS.has(type):
		limiter.penalize(id, 5.0, _clock)
		_check_abuse(id, "bad_header")
		return
	c.last = _clock
	if not limiter.allow(id, String(Protocol.RATE_CLASS[type]), _clock):
		logger.limited("debug", "rate:%d" % id, "peer %d acima do limite (tipo %d)" % [id, type])
		_check_abuse(id, "rate")
		return
	if type == Protocol.C_INPUT:
		if String(c.stage) == "game":
			var cmds := Protocol.decode_input(pkt)
			if cmds.is_empty():
				limiter.penalize(id, 2.0, _clock)
			else:
				world.player_input(int(c.eid), cmds)
		return
	var msg := Protocol.decode_control(pkt)
	if msg.is_empty():
		limiter.penalize(id, 3.0, _clock)
		_check_abuse(id, "bad_payload")
		return
	match type:
		Protocol.C_HELLO:
			if int(msg.get("v", -1)) != Protocol.VERSION:
				_error(id, "version")
				kick(id, "version")
				return
			c.stage = "auth"
			_send_control(id, Protocol.S_PONG, {"hello": true, "v": Protocol.VERSION, "tick_rate": int(cfg.tick_rate)})
		Protocol.C_REGISTER, Protocol.C_LOGIN, Protocol.C_RESUME:
			_auth(id, c, type, msg)
		Protocol.C_PING:
			_send_control(id, Protocol.S_PONG, {"t": float(msg.get("t", 0.0)), "tick": int(world.tick)})
		Protocol.C_LOGOUT:
			_leave_world(id, true)
			peer.disconnect_peer(id, false)
		_:
			if String(c.stage) != "game":
				limiter.penalize(id, 2.0, _clock)
				return
			match type:
				Protocol.C_ACTION:
					_on_action(id, c, msg)
				Protocol.C_CHAT:
					_on_chat(id, c, msg)
				Protocol.C_FRIEND:
					_on_friend(id, c, msg)
	_check_abuse(id, "abuse")


func _check_abuse(id: int, reason: String) -> void:
	if conns.has(id) and limiter.should_kick(id, _clock):
		kick(id, reason)


func _auth(id: int, c: Dictionary, type: int, msg: Dictionary) -> void:
	if String(c.stage) != "auth":
		_error(id, "stage")
		limiter.penalize(id, 2.0, _clock)
		return
	var ip := String(c.addr)
	var lock: Array = _auth_fail.get(ip, [0, 0.0])
	if _clock < float(lock[1]):
		_error(id, "locked")
		return
	var key := ""
	var name_s := String(msg.get("name", "")) if msg.get("name") is String else ""
	var pass_s := String(msg.get("pass", "")) if msg.get("pass") is String else ""
	# vocação pedida: só vale para personagem novo; o mundo valida contra classes.json
	c["vocation"] = String(msg.get("vocation", "")).left(16) if msg.get("vocation") is String else ""
	match type:
		Protocol.C_REGISTER:
			var r: Dictionary = accounts.register(name_s, pass_s, int(Time.get_unix_time_from_system()))
			if not bool(r.ok):
				_error(id, String(r.error))
				return
			key = String(r.key)
			save_all()
			logger.write("info", "conta criada: %s" % accounts.display_name(key))
		Protocol.C_LOGIN:
			key = accounts.verify(name_s, pass_s)
		Protocol.C_RESUME:
			var tok := String(msg.get("token", "")) if msg.get("token") is String else ""
			if tok.length() == 48:
				key = sessions.resume(tok, id, _clock)
	if key.is_empty():
		lock[0] = int(lock[0]) + 1
		if int(lock[0]) >= int(cfg.get("auth_failures_before_lock", 5)):
			lock = [0, _clock + float(cfg.get("auth_lock_seconds", 60))]
			logger.limited("warn", "lock:" + ip, "login bloqueado temporariamente para %s" % ip)
		_auth_fail[ip] = lock
		_error(id, "auth" if type != Protocol.C_RESUME else "resume")
		return
	_auth_fail.erase(ip)
	_enter_world(id, c, key, type == Protocol.C_RESUME)


func _enter_world(id: int, c: Dictionary, key: String, resumed: bool) -> void:
	# mesma conta conectada em outro peer: o novo assume, o antigo cai
	for other: int in conns.keys():
		if other != id and String(conns[other].key) == key and String(conns[other].stage) == "game":
			kick(other, "replaced")
	var token := ""
	if resumed:
		token = ""  # o cliente continua com o token que já tem
	else:
		token = sessions.issue(key, id)
	var display: String = accounts.display_name(key)
	var eid: int = world.add_player(key, display, accounts.character(key), String(c.get("vocation", "")))
	c.stage = "game"
	c.eid = eid
	c.key = key
	eid_peer[eid] = id
	var welcome := {"eid": eid, "name": display, "resumed": resumed, "tick": int(world.tick),
		"tick_rate": int(cfg.tick_rate), "character": world.character_data(eid),
		"vocation": String(world.players[eid].vocation), "speed": float(world.players[eid].speed)}
	if not token.is_empty():
		welcome["token"] = token
	welcome["content"] = world.content.client_state(world.players[eid])   # diário, bolsa, Nessa
	_send_control(id, Protocol.S_WELCOME, welcome)
	_deliver_friend_events(friends.set_presence(key, true, world.region_of(world.players[eid].ms.pos)))
	_send_control(id, Protocol.S_FRIENDS, friends.list(key))
	logger.write("info", "%s entrou (%s, peer %d, %s)" % [display, "RESUME" if resumed else "login", id, String(c.addr)])


func _on_action(id: int, c: Dictionary, msg: Dictionary) -> void:
	for k: String in msg:
		if not (msg[k] is String or msg[k] is int or msg[k] is float):
			limiter.penalize(id, 3.0, _clock)
			return
	var err: String = world.player_action(int(c.eid), msg)
	if err != "":
		if err == "unknown":
			limiter.penalize(id, 2.0, _clock)
		_send_control(id, Protocol.S_EVENT, {"type": "refused", "act": String(msg.get("act", "")), "reason": err})


func _on_chat(id: int, c: Dictionary, msg: Dictionary) -> void:
	var text := TextRules.clean_chat(String(msg.get("text", "")) if msg.get("text") is String else "", int(cfg.get("chat_max", 160)))
	if text.is_empty():
		return
	var channel := String(msg.get("channel", "local")) if msg.get("channel") is String else "local"
	var who: String = accounts.display_name(String(c.key))
	if text.begins_with("/admin "):
		_admin(id, text)
		return
	var out := {"channel": channel, "from": who, "text": text}
	match channel:
		"global":
			for p: int in conns:
				if String(conns[p].stage) == "game":
					_send_control(p, Protocol.S_CHAT, out)
		"private":
			var to := TextRules.name_key(String(msg.get("to", "")) if msg.get("to") is String else "")
			var tp: int = sessions.peer_of(to)
			if tp == 0 or not conns.has(tp) or String(conns[tp].stage) != "game":
				_error(id, "offline")
				return
			_send_control(tp, Protocol.S_CHAT, out)
			_send_control(id, Protocol.S_CHAT, out)
		_:
			out.channel = "local"
			var at: Vector3 = world.players[int(c.eid)].ms.pos
			_send_near(at, 30.0, Protocol.S_CHAT, out)


## Comandos de administração pelo chat: "/admin <token> save|who|kick <nome>".
## Desligado se AETHRA_ADMIN_TOKEN estiver vazio.
func _admin(id: int, text: String) -> void:
	var parts := text.split(" ", false)
	var token := String(cfg.get("admin_token", ""))
	if token.is_empty() or parts.size() < 3 or not Accounts.constant_time_equal(parts[1], token):
		limiter.penalize(id, 10.0, _clock)
		logger.limited("warn", "admin", "tentativa de /admin inválida do peer %d" % id)
		_check_abuse(id, "admin")
		return
	match parts[2]:
		"save":
			accounts.dirty = true
			save_all()
			_send_control(id, Protocol.S_CHAT, {"channel": "server", "from": "Servidor", "text": "salvo"})
		"who":
			var names: Array[String] = []
			for p: int in conns:
				if String(conns[p].stage) == "game":
					names.append(accounts.display_name(String(conns[p].key)))
			_send_control(id, Protocol.S_CHAT, {"channel": "server", "from": "Servidor", "text": ", ".join(names)})
		"kick":
			if parts.size() >= 4:
				var tp: int = sessions.peer_of(TextRules.name_key(" ".join(parts.slice(3))))
				if tp != 0:
					kick(tp, "admin")


func _on_friend(id: int, c: Dictionary, msg: Dictionary) -> void:
	var op := String(msg.get("op", "")) if msg.get("op") is String else ""
	var other := String(msg.get("name", "")) if msg.get("name") is String else ""
	var key := String(c.key)
	var r: Dictionary
	match op:
		"request": r = friends.request(key, other)
		"accept": r = friends.accept(key, other)
		"decline": r = friends.decline(key, other)
		"remove": r = friends.remove(key, other)
		"list":
			_send_control(id, Protocol.S_FRIENDS, friends.list(key))
			return
		_:
			limiter.penalize(id, 2.0, _clock)
			return
	if not bool(r.ok):
		_error(id, "friend_" + String(r.error))
		return
	_deliver_friend_events(r.events)
	_send_control(id, Protocol.S_FRIENDS, friends.list(key))
	var other_peer: int = sessions.peer_of(TextRules.name_key(other))
	if other_peer != 0 and conns.has(other_peer) and String(conns[other_peer].stage) == "game":
		_send_control(other_peer, Protocol.S_FRIENDS, friends.list(TextRules.name_key(other)))
	save_all()


func _deliver_friend_events(evs: Array) -> void:
	for ev: Dictionary in evs:
		var p: int = sessions.peer_of(String(ev.to))
		if p != 0 and conns.has(p) and String(conns[p].stage) == "game":
			var out := ev.duplicate()
			out.erase("to")
			_send_control(p, Protocol.S_FRIEND_EVENT, out)


func _send_near(at: Vector3, radius: float, type: int, data: Dictionary) -> void:
	for p: int in conns:
		var c: Dictionary = conns[p]
		if String(c.stage) != "game" or not world.players.has(int(c.eid)):
			continue
		var pos: Vector3 = world.players[int(c.eid)].ms.pos
		if Vector2(pos.x - at.x, pos.z - at.z).length() <= radius:
			_send_control(p, type, data)


func _dispatch_events() -> void:
	for ev: Dictionary in world.events:
		var to := int(ev.to)
		var out := ev.duplicate()
		out.erase("to")
		if to == -1:
			var a: Array = ev.get("at", [0.0, 0.0])
			_send_near(Vector3(float(a[0]), 0, float(a[1])), float(cfg.get("interest_enter_m", 40.0)), Protocol.S_EVENT, out)
		elif eid_peer.has(to):
			_send_control(int(eid_peer[to]), Protocol.S_EVENT, out)
	world.events.clear()


func _send_snapshots() -> void:
	world.index_interest()
	var max_out := int(cfg.get("max_outbound_packet", 1400))
	for p: int in conns:
		var c: Dictionary = conns[p]
		if String(c.stage) != "game" or not world.players.has(int(c.eid)):
			continue
		var s: Dictionary = world.snapshot_for(int(c.eid))
		for id: int in s.entered:
			_send_control(p, Protocol.S_ENTITY_INFO, world.entity_info(id))
		var ents: Array = s.entities
		var pkt := Protocol.encode_snapshot(int(world.tick), int(s.ack), s.me, ents)
		while pkt.size() > max_out and not ents.is_empty():
			ents = ents.slice(0, ents.size() - 4)   # corta os de menor prioridade (fim da lista)
			pkt = Protocol.encode_snapshot(int(world.tick), int(s.ack), s.me, ents)
		_send(p, pkt, false)


## Estatísticas para testes/monitoramento.
func online_count() -> int:
	var n := 0
	for p: int in conns:
		if String(conns[p].stage) == "game":
			n += 1
	return n
