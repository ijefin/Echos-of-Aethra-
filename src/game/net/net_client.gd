extends Node
## Cliente de rede: conexão ENet, login/registro, RESUME automático ao cair, envio de
## comandos a taxa fixa com redundância, predição local do próprio jogador com
## reconciliação (re-aplica comandos não confirmados) e buffer de interpolação para as
## outras entidades.

signal connected
signal logged_in(welcome: Dictionary)
signal login_failed(code: String)
signal disconnected(reason: String)
signal reconnecting(attempt: int)
signal entity_entered(info: Dictionary)
signal entity_left(id: int)
signal event_received(ev: Dictionary)
signal chat_received(msg: Dictionary)
signal friends_changed(list: Dictionary)
signal friend_event(ev: Dictionary)
signal stats_changed(me: Dictionary)

const Protocol := preload("res://src/game/net/net_protocol.gd")
const NetConfig := preload("res://src/game/net/net_config.gd")
const Motion := preload("res://src/game/net/player_motion.gd")
const Collision := preload("res://src/game/net/world_collision.gd")

var cfg: Dictionary
var col: RefCounted
## Colisão por andar ({0: superfície, -1: gruta}), igual à do servidor.
var floors: Dictionary = {}
var peer: ENetMultiplayerPeer
var host := "127.0.0.1"
var port := 7777
var state := "offline"   # offline, connecting, hello, auth, game
var eid := 0
var token := ""
var display_name := ""
var me: Dictionary = {}
## Vocação confirmada pelo servidor e a velocidade a pé dela (a predição usa a mesma).
var vocation := "mage"
var move_speed := 4.2           # último bloco "me" do servidor (vida, mana, nível...)
var infos: Dictionary = {}        # id → info estática (nome, tipo)
var friends: Dictionary = {}
var rtt_ms := 0.0

# predição
var predicted: Dictionary = {}    # estado de movimento previsto (PlayerMotion)
var _prev_pos := Vector3.ZERO
var _pending: Array = []          # comandos não confirmados {seq, dir, flags}
var _seq := 0
var _move_dir := Vector2.ZERO
var _dodge_req := false
var _input_acc := 0.0
var _visual_offset := Vector3.ZERO
var _last_tick := -1
var corrections := 0
var snaps := 0

# interpolação
var _buffers: Dictionary = {}     # id → Array de [t_servidor, estado]
var _server_offset := 0.0         # t_servidor ≈ t_local + offset
var _have_offset := false
var _clock := 0.0

# conexão
var _login: Dictionary = {}       # {type, name, pass} pendente
var _want_resume := false
var _retry_t := -1.0
var _retry_n := 0
var _ping_acc := 0.0
var _manual_close := false
var _close_in := -1.0
var _kicked := false


func _init(config: Dictionary = {}) -> void:
	cfg = config if not config.is_empty() else NetConfig.load_config()
	floors = Collision.load_floors("res://src/game/net/data/collision_surface.json", float(cfg.get("world_half", 100.0)))
	col = floors[0]


## Conecta e faz login (ou cadastro, se `register`). O resultado chega por sinal.
## `vocation` (mage|warrior|archer) só vale para personagem novo; o servidor confirma no welcome.
func connect_and_login(address: String, port_number: int, user: String, password: String, register := false, vocation := "") -> Error:
	_login = {"type": Protocol.C_REGISTER if register else Protocol.C_LOGIN, "name": user, "pass": password}
	if not vocation.is_empty():
		_login["vocation"] = vocation
	_want_resume = false
	return _open(address, port_number)


func _open(address: String, port_number: int) -> Error:
	host = address
	port = port_number
	if peer != null:
		peer.close()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port_number)
	if err != OK:
		return err
	peer.peer_connected.connect(func(_id: int) -> void: _on_link())
	peer.peer_disconnected.connect(func(_id: int) -> void: _on_lost("server_closed"))
	state = "connecting"
	_manual_close = false
	_kicked = false
	return OK


func _on_link() -> void:
	state = "hello"
	_send_control(Protocol.C_HELLO, {"v": Protocol.VERSION, "client": "pixel3d"})
	connected.emit()


func _on_lost(reason: String) -> void:
	if state == "offline" or state == "closing":
		return
	var was_game := state == "game"
	state = "offline"
	if _manual_close or _kicked:
		disconnected.emit("kicked" if _kicked else "logout")
		return
	disconnected.emit(reason)
	# queda durante o jogo: tenta voltar no mesmo personagem com o token
	if (was_game or _want_resume) and not token.is_empty():
		_want_resume = true
		_retry_n += 1
		_retry_t = minf(8.0, pow(2.0, _retry_n - 1))
		if _retry_n > 8:
			_want_resume = false
			_retry_t = -1.0


## Encerra a conexão sem logout (simula queda; o servidor mantém o token na graça).
func drop_connection() -> void:
	state = "offline"
	_want_resume = false
	_retry_t = -1.0
	if peer != null:
		peer.close()
		peer = null


## Reconecta com o token atual (RESUME).
func resume(address := "", port_number := 0) -> Error:
	if token.is_empty():
		return ERR_UNAUTHORIZED
	_want_resume = true
	_login = {}
	return _open(address if address != "" else host, port_number if port_number != 0 else port)


func logout() -> void:
	if peer != null and state == "game":
		_send_control(Protocol.C_LOGOUT, {"bye": true})
	_manual_close = true
	_want_resume = false
	token = ""
	state = "closing"
	_close_in = 0.3   # dá tempo do LOGOUT sair antes de fechar


func is_in_game() -> bool:
	return state == "game"


# ------------------------------------------------------------------ envio

func _send(pkt: PackedByteArray, reliable: bool) -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.set_target_peer(1)
	peer.set_transfer_channel(0)
	peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED)
	peer.put_packet(pkt)


func _send_control(type: int, data: Dictionary) -> void:
	_send(Protocol.encode_control(type, data), true)


## Direção do movimento (x = direita, y = para baixo/sul na tela), chamada todo quadro.
## No dash parado, `stationary_facing` alinha somente a predição à orientação visual
## atual (que pode ter vindo de um ataque). O servidor continua autoritativo e usa o
## próprio yaw para aceitar cooldown, direção e colisão.
func set_move(dir: Vector2, dodge := false, stationary_facing := Vector2.ZERO) -> void:
	_move_dir = dir.limit_length(1.0)
	if dodge:
		if _move_dir.length() <= 0.2 and stationary_facing.length() > 0.2 and not predicted.is_empty():
			var face := stationary_facing.normalized()
			predicted.yaw = atan2(-face.x, -face.y)
		_dodge_req = true


func action(act: String, extra: Dictionary = {}) -> void:
	if state != "game":
		return
	var msg := extra.duplicate()
	msg["act"] = act
	_send_control(Protocol.C_ACTION, msg)


func chat(channel: String, text: String, to := "") -> void:
	if state == "game":
		_send_control(Protocol.C_CHAT, {"channel": channel, "text": text, "to": to})


func friend(op: String, other := "") -> void:
	if state == "game":
		_send_control(Protocol.C_FRIEND, {"op": op, "name": other})


## Envia bytes crus (só para testes de robustez do servidor).
func send_raw(pkt: PackedByteArray, reliable := true) -> void:
	_send(pkt, reliable)


# ------------------------------------------------------------------ laço

func _process(delta: float) -> void:
	_clock += delta
	if _retry_t >= 0.0 and state == "offline":
		_retry_t -= delta
		if _retry_t < 0.0:
			reconnecting.emit(_retry_n)
			_open(host, port)
	if peer == null:
		return
	peer.poll()
	if _close_in >= 0.0:
		_close_in -= delta
		if _close_in < 0.0:
			peer.close()
			peer = null
			state = "offline"
			disconnected.emit("logout")
		return
	while peer != null and peer.get_available_packet_count() > 0:
		_handle(peer.get_packet())
	if peer != null and state == "connecting" and peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_on_lost("connect_failed")
		return
	if state != "game":
		return
	var dt := 1.0 / float(cfg.get("input_rate", 20))
	_input_acc += delta
	var guard := 0
	while _input_acc >= dt and guard < 4:
		_input_acc -= dt
		guard += 1
		_input_tick(dt)
	if guard >= 4:
		_input_acc = 0.0
	_visual_offset = _visual_offset.move_toward(Vector3.ZERO, _visual_offset.length() * minf(1.0, float(cfg.get("correction_per_second", 10.0)) * delta) + 0.0001)
	_ping_acc += delta
	if _ping_acc >= 2.0:
		_ping_acc = 0.0
		_send_control(Protocol.C_PING, {"t": _clock})


func _input_tick(dt: float) -> void:
	_seq += 1
	var cmd := {"seq": _seq, "dir": _move_dir, "flags": Protocol.FLAG_DODGE if _dodge_req else 0}
	_dodge_req = false
	_prev_pos = predicted.pos
	Motion.step(predicted, cmd.dir, int(cmd.flags), dt, col_at((predicted.pos as Vector3).y), _move_cfg(), float(cfg.get("player_radius", 0.28)))
	_pending.append(cmd)
	if _pending.size() > 64:
		_pending.pop_front()
	var n := mini(int(cfg.get("input_redundancy", 3)), _pending.size())
	_send(Protocol.encode_input(_pending.slice(_pending.size() - n)), false)


# ------------------------------------------------------------------ recepção

func _handle(pkt: PackedByteArray) -> void:
	var type := Protocol.packet_type(pkt)
	if type == Protocol.S_SNAPSHOT:
		var snap := Protocol.decode_snapshot(pkt)
		if not snap.is_empty():
			_on_snapshot(snap)
		return
	var msg := Protocol.decode_control(pkt)
	match type:
		Protocol.S_PONG:
			if msg.has("hello"):
				state = "auth"
				if _want_resume and not token.is_empty():
					_send_control(Protocol.C_RESUME, {"token": token})
				elif not _login.is_empty():
					var lm := {"name": _login.name, "pass": _login.pass}
					if _login.has("vocation"):
						lm["vocation"] = _login.vocation
					_send_control(int(_login.type), lm)
			elif msg.has("t"):
				rtt_ms = (_clock - float(msg.t)) * 1000.0
		Protocol.S_WELCOME:
			_on_welcome(msg)
		Protocol.S_ERROR:
			var code := String(msg.get("code", "?"))
			if state == "auth":
				if code == "resume":
					token = ""
					_want_resume = false
				login_failed.emit(code)
			else:
				event_received.emit({"type": "error", "code": code})
		Protocol.S_KICK:
			_want_resume = false
			_kicked = true
			token = "" if String(msg.get("reason", "")) == "replaced" else token
			event_received.emit({"type": "kicked", "reason": String(msg.get("reason", ""))})
		Protocol.S_ENTITY_INFO:
			infos[int(msg.get("id", 0))] = msg
			entity_entered.emit(msg)
		Protocol.S_EVENT:
			event_received.emit(msg)
		Protocol.S_CHAT:
			chat_received.emit(msg)
		Protocol.S_FRIENDS:
			friends = msg
			friends_changed.emit(msg)
		Protocol.S_FRIEND_EVENT:
			friend_event.emit(msg)


func _on_welcome(msg: Dictionary) -> void:
	state = "game"
	eid = int(msg.get("eid", 0))
	display_name = String(msg.get("name", ""))
	vocation = String(msg.get("vocation", "mage"))
	move_speed = float(msg.get("speed", (cfg.get("move", {}) as Dictionary).get("speed", 4.2)))
	if msg.has("token"):
		token = String(msg.token)
	_retry_n = 0
	_retry_t = -1.0
	_want_resume = false
	var ch: Dictionary = msg.get("character", {})
	var pos: Array = ch.get("pos", [0, 0, 0])
	predicted = Motion.new_state(Vector3(float(pos[0]), float(pos[1]), float(pos[2])))
	predicted.yaw = float(ch.get("yaw", 0.0))
	_prev_pos = predicted.pos
	_pending.clear()
	_seq = 0
	_last_tick = -1
	_buffers.clear()
	_have_offset = false
	logged_in.emit(msg)


func _on_snapshot(snap: Dictionary) -> void:
	if state != "game":
		return
	var tick := int(snap.tick)
	if tick <= _last_tick:
		return   # fora de ordem
	_last_tick = tick
	snaps += 1
	var server_t := float(tick) / float(cfg.get("tick_rate", 20))
	var off := server_t - _clock
	if not _have_offset:
		_server_offset = off
		_have_offset = true
	else:
		# sobe rápido (pacote adiantado) e desce devagar (absorve jitter)
		_server_offset = off if off > _server_offset else lerpf(_server_offset, off, 0.05)
	me = snap.me
	stats_changed.emit(me)
	_reconcile(int(snap.ack), snap.me)
	var seen := {}
	for e: Dictionary in snap.entities:
		var id := int(e.id)
		seen[id] = true
		if not _buffers.has(id):
			_buffers[id] = []
		var buf: Array = _buffers[id]
		buf.append([server_t, e])
		while buf.size() > 12:
			buf.pop_front()
	for id: int in _buffers.keys():
		if not seen.has(id):
			_buffers.erase(id)
			infos.erase(id)
			entity_left.emit(id)


## Colisão do andar da altura `y` (superfície 0, gruta -1): a mesma que o servidor usa.
func col_at(y: float) -> RefCounted:
	return floors.get(-1 if y < -4.0 else 0, col)


## Movimento para a predição: com o bit "slow" do servidor (teia) a velocidade cai pelo
## mesmo fator que o servidor usa (move.slow_factor).
func _move_cfg() -> Dictionary:
	var mv: Dictionary = cfg.get("move", {})
	var slowed := not me.is_empty() and (int(me.get("effects", 0)) & (1 << Protocol.EFFECTS.find("slow"))) != 0
	if not slowed and is_equal_approx(move_speed, float(mv.get("speed", 4.2))):
		return mv
	var out := mv.duplicate()
	out.speed = move_speed * (float(mv.get("slow_factor", 0.55)) if slowed else 1.0)
	return out


## Reconciliação: parte do estado confirmado e re-aplica os comandos pendentes.
func _reconcile(ack: int, server_me: Dictionary) -> void:
	while not _pending.is_empty() and int(_pending[0].seq) <= ack:
		_pending.pop_front()
	var before: Vector3 = predicted.pos
	var s := Motion.new_state(server_me.pos)
	s.dodge_t = float(server_me.dodge_t)
	s.dodge_cd = float(server_me.dodge_cd)
	s.dodge_dir = server_me.dodge_dir
	s.yaw = float(predicted.get("yaw", 0.0))
	var dt := 1.0 / float(cfg.get("input_rate", 20))
	for c: Dictionary in _pending:
		Motion.step(s, c.dir, int(c.flags), dt, col_at((s.pos as Vector3).y), _move_cfg(), float(cfg.get("player_radius", 0.28)))
	var after: Vector3 = s.pos
	var err := before.distance_to(after)
	predicted = s
	if err > float(cfg.get("snap_threshold_m", 2.5)):
		_visual_offset = Vector3.ZERO   # teleporte do servidor (Eco, renascer): pula
		_prev_pos = after
		corrections += 1
		return
	if err > float(cfg.get("reconcile_threshold_m", 0.15)):
		corrections += 1
	_visual_offset += before - after   # suaviza a correção em vez de pular
	_prev_pos += after - before


# ------------------------------------------------------------------ leitura pelo jogo

## Posição para desenhar o jogador local (prevista, interpolada entre passos + correção suave).
func local_position() -> Vector3:
	if predicted.is_empty():
		return Vector3.ZERO
	var dt := 1.0 / float(cfg.get("input_rate", 20))
	var alpha := clampf(_input_acc / dt, 0.0, 1.0)
	return (_prev_pos.lerp(predicted.pos, alpha)) + _visual_offset


## Posição prevista sem suavização (para lógica: mira, distância).
func predicted_position() -> Vector3:
	return predicted.get("pos", Vector3.ZERO)


func local_yaw() -> float:
	return float(predicted.get("yaw", 0.0))


func is_dodging() -> bool:
	return float(predicted.get("dodge_t", -1.0)) >= 0.0


## Estado interpolado de cada entidade remota (tempo do servidor − atraso de interpolação).
func entities() -> Array:
	var out: Array = []
	var render_t := _clock + _server_offset - float(cfg.get("interp_delay_ms", 110)) / 1000.0
	for id: int in _buffers:
		var buf: Array = _buffers[id]
		if buf.is_empty():
			continue
		var a: Array = buf[0]
		var b: Array = buf[0]
		for i in buf.size():
			var item: Array = buf[i]
			if float(item[0]) <= render_t:
				a = item
				b = buf[mini(i + 1, buf.size() - 1)]
		var ea: Dictionary = a[1]
		var eb: Dictionary = b[1]
		var span := float(b[0]) - float(a[0])
		var k := clampf((render_t - float(a[0])) / span, 0.0, 1.0) if span > 0.0001 else 1.0
		var info: Dictionary = infos.get(id, {})
		out.append({"id": id, "kind": int(eb.kind), "sub": int(eb.sub), "name": String(info.get("name", "")),
			"vocation": String(info.get("vocation", "")), "level": int(info.get("level", 0)),
			"pos": (ea.pos as Vector3).lerp(eb.pos, k), "yaw": lerp_angle(float(ea.yaw), float(eb.yaw), k),
			"hp": int(eb.hp), "max_hp": int(eb.max_hp), "effects": Protocol.effect_names(int(eb.effects))})
	return out


func entity(id: int) -> Dictionary:
	for e: Dictionary in entities():
		if int(e.id) == id:
			return e
	return {}
