# PROTOTYPE - NOT FOR PRODUCTION
extends SceneTree
## Cliente headless roteirizado para o teste de sessão (tools/net_session_test.ps1).
##   godot --headless --path . -s res://prototypes/pixel3d/net/tests/net_bot.gd -- --role=alice|bruno|relogin --port=17777 [--state=arquivo.json]
## Imprime "CHECK PASS|FAIL <papel>: <item>" e "BOT_DONE <papel> <falhas>".

const NetClient := preload("res://prototypes/pixel3d/net/net_client.gd")
const NetConfig := preload("res://prototypes/pixel3d/net/net_config.gd")
const Protocol := preload("res://prototypes/pixel3d/net/net_protocol.gd")

const PASSWORD := "segredo-teste-1"

var c: Node
var role := ""
var port := 17777
var state_path := ""
var fails := 0
var events: Array = []
var friend_events: Array = []
var chats: Array = []
var welcomes: Array = []
var login_errors: Array = []
var disconnects: Array = []
var seen_damage := false
var seen_projectile := false
var _move := Vector2.ZERO


func check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CHECK %s %s: %s" % ["PASS" if cond else "FAIL", role, what])


func _initialize() -> void:
	Engine.max_fps = 60
	var args := NetConfig.cmdline_args()
	role = String(args.get("role", "alice"))
	port = int(args.get("port", 17777))
	state_path = String(args.get("state", ""))
	c = NetClient.new()
	root.add_child(c)
	c.logged_in.connect(func(w: Dictionary) -> void: welcomes.append(w))
	c.login_failed.connect(func(code: String) -> void: login_errors.append(code))
	c.event_received.connect(func(e: Dictionary) -> void: events.append(e))
	c.friend_event.connect(func(e: Dictionary) -> void: friend_events.append(e))
	c.chat_received.connect(func(m: Dictionary) -> void: chats.append(m))
	c.disconnected.connect(func(r: String) -> void: disconnects.append(r))
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if c != null and c.is_in_game():
		c.set_move(_move)
		for e: Dictionary in c.entities():
			if int(e.kind) == Protocol.KIND_MONSTER and int(e.hp) < int(e.max_hp):
				seen_damage = true
			if int(e.kind) == Protocol.KIND_PROJECTILE:
				seen_projectile = true
	return false


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func wait_until(cond: Callable, timeout: float) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return bool(cond.call())


func finish() -> void:
	print("BOT_DONE %s %d" % [role, fails])
	quit(0 if fails == 0 else 1)


func _run() -> void:
	match role:
		"alice": await _alice()
		"bruno": await _bruno()
		"relogin": await _relogin()
		"buddy": await _buddy()
	finish()


# ------------------------------------------------------------------ utilidades

## Vocação de cada bot (personagem novo): Alice arqueira, Bruno guerreiro.
const VOCATION := {"Alice": "archer", "Bruno": "warrior", "Bia": "warrior"}


func login(user: String) -> bool:
	c.connect_and_login("127.0.0.1", port, user, PASSWORD, true, String(VOCATION.get(user, "")))
	var ok: bool = await wait_until(func() -> bool: return not welcomes.is_empty() or not login_errors.is_empty(), 15.0)
	if ok and welcomes.is_empty() and login_errors.has("name_taken"):
		login_errors.clear()
		c.drop_connection()
		c.connect_and_login("127.0.0.1", port, user, PASSWORD, false)
		ok = await wait_until(func() -> bool: return not welcomes.is_empty() or not login_errors.is_empty(), 15.0)
	return ok and not welcomes.is_empty()


func server_pos() -> Vector3:
	return c.me.get("pos", Vector3.ZERO)


func find_player(n: String) -> Dictionary:
	for e: Dictionary in c.entities():
		if int(e.kind) == Protocol.KIND_PLAYER and String(e.name) == n:
			return e
	return {}


func nearest_monster() -> Dictionary:
	var best := {}
	var bd := INF
	var me: Vector3 = c.predicted_position()
	for e: Dictionary in c.entities():
		if int(e.kind) == Protocol.KIND_MONSTER and float(_skip.get(int(e.id), -1.0)) < _now():
			var d := (e.pos as Vector3).distance_to(me)
			if d < bd:
				bd = d
				best = e
	return best


func has_event(list: Array, key: String, value: Variant) -> bool:
	for e: Dictionary in list:
		if e.get(key) == value:
			return true
	return false


func friend_presence(n: String, online: bool) -> bool:
	for e: Dictionary in friend_events:
		if String(e.get("name", "")) == n and String(e.get("op", "")) in ["presence", "accepted"] and bool(e.get("online", false)) == online:
			return true
	return false


# ------------------------------------------------------------------ Alice

func _alice() -> void:
	check(await login("Alice"), "entra no servidor (cadastro/login)")
	await wait_until(func() -> bool: return int(c.snaps) > 3, 5.0)
	check(c.vocation == "archer" and is_equal_approx(c.move_speed, 4.6), "vocação: servidor confirmou arqueira (%s, %.1f m/s)" % [c.vocation, c.move_speed])
	var start := server_pos()
	_move = Vector2(1, 0)
	await wait(1.0)
	_move = Vector2.ZERO
	await wait(0.6)
	var moved := server_pos().distance_to(start)
	check(moved > 0.5 and moved <= c.move_speed * 1.3, "move: servidor confirmou %.2f m em ~1 s (máx. %.2f com a velocidade da vocação)" % [moved, c.move_speed * 1.3])
	check(c.predicted_position().distance_to(server_pos()) < 0.25, "predição local = posição do servidor após parar (erro %.3f m)" % c.predicted_position().distance_to(server_pos()))
	check(await wait_until(func() -> bool: return not find_player("Bruno").is_empty(), 20.0), "vê o outro jogador (Bruno) replicado")
	c.friend("request", "Bruno")
	check(await wait_until(func() -> bool: return has_event(friend_events, "op", "accepted"), 15.0), "amizade: Bruno aceitou o pedido (evento em tempo real)")
	check(await wait_until(func() -> bool: return friend_presence("Bruno", true), 5.0), "presença: Bruno aparece online")
	check(await wait_until(func() -> bool: return String(find_player("Bruno").get("vocation", "")) == "warrior", 10.0), "vocação: vê o Bruno como guerreiro (entity_info)")
	check(await wait_until(func() -> bool: return "light" in (find_player("Bruno").get("effects", []) as Array), 20.0), "luz: vê a Luz do Bruno (efeito replicado para os outros)")
	check(has_event(events, "type", "light"), "luz: recebeu o evento da Luz do Bruno com a duração")
	var lv0 := int(c.me.level)
	var xp0 := int(c.me.xp)
	c.action("blink", {"x": 0.0, "z": 0.0})
	check(await wait_until(func() -> bool: return _refused("blink", "level"), 5.0), "servidor recusa Eco no nível 1 (validação de nível)")
	var killed: bool = await _hunt(30.0)
	check(killed, "derrota um monstro do servidor (evento kill vindo do servidor)")
	await wait(0.4)
	var kill_xp := 0
	for e: Dictionary in events:
		if String(e.get("type", "")) == "kill":
			kill_xp = int(e.get("xp", 0))
			break
	check(killed and (int(c.me.xp) == xp0 + kill_xp or int(c.me.level) > lv0), "XP aplicado pelo servidor e replicado no snapshot (+%d; antes %d/%d, depois %d/%d)" % [kill_xp, lv0, xp0, int(c.me.level), int(c.me.xp)])
	c.chat("global", "pronto")
	check(await wait_until(func() -> bool: return friend_presence("Bruno", false), 30.0), "presença: Bruno ficou offline ao cair")
	friend_events = friend_events.filter(func(e: Dictionary) -> bool: return bool(e.get("online", false)) == false)
	check(await wait_until(func() -> bool: return friend_presence("Bruno", true), 30.0), "presença: Bruno voltou online após reconectar")
	await _speedhack()
	c.logout()
	await wait(0.6)


var _seen_events := 0
## Monstros sem linha de tiro (árvore/rio no meio): ignorados por alguns segundos.
var _skip := {}


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Houve recusa `reason` desde a última consulta?
func _refused_recent(reason: String) -> bool:
	var hit := false
	for i in range(_seen_events, events.size()):
		var e: Dictionary = events[i]
		if String(e.get("type", "")) == "refused" and String(e.get("reason", "")) == reason:
			hit = true
	_seen_events = events.size()
	return hit


func _refused(act: String, reason: String) -> bool:
	for e: Dictionary in events:
		if String(e.get("type", "")) == "refused" and String(e.get("act", "")) == act and String(e.get("reason", "")) == reason:
			return true
	return false


## Atira no monstro mais próximo até o servidor anunciar o abate.
func _hunt(timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if has_event(events, "type", "kill"):
			_move = Vector2.ZERO
			return true
		var m := nearest_monster()
		if not m.is_empty():
			var me: Vector3 = c.predicted_position()
			var to: Vector3 = (m.pos as Vector3) - me
			# sem linha de tiro (árvore/rio no meio): troca de alvo por 5 s
			if _refused_recent("los"):
				_skip[int(m.id)] = _now() + 5.0
			_move = Vector2(to.x, to.z).normalized() if Vector2(to.x, to.z).length() > 4.0 else Vector2.ZERO
			c.action("fire", {"target": int(m.id)})
		await wait(0.45)
		t += 0.45
	_move = Vector2.ZERO
	if not has_event(events, "type", "kill"):
		var why := {}
		for e: Dictionary in events:
			var k := "%s/%s" % [String(e.get("type", "")), String(e.get("reason", ""))]
			why[k] = int(why.get(k, 0)) + 1
		var m := nearest_monster()
		print("CHECK INFO %s: caça sem abate: eventos %s; hp %d; eu %s; monstro mais perto %s" % [role, str(why), int(c.me.get("hp", 0)), str(server_pos()), str(m)])
	return has_event(events, "type", "kill")


## Manda comandos de movimento em excesso (12× por tick) direto no socket.
func _speedhack() -> void:
	await wait(0.5)
	var start := server_pos()
	var t0 := Time.get_ticks_msec()
	var seq: int = c._seq + 1
	c.set_process(false)   # o cliente normal para de mandar; só o trapaceiro fala
	for i in 20:
		for k in 3:
			var cmds: Array = []
			for j in 4:
				cmds.append({"seq": seq, "dir": Vector2(-1, 0), "flags": 0})
				seq += 1
			c.send_raw(Protocol.encode_input(cmds), false)
		c.peer.poll()
		await wait(0.05)
		_drain()
	await wait(0.6)
	_drain()
	var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
	var moved := server_pos().distance_to(start)
	var v: float = c.move_speed
	var limit := v * elapsed + v * 0.25 + 0.3   # tempo real + orçamento de jitter (0,25 s)
	check(moved <= limit, "anti-speedhack: 12× comandos por %.2f s moveram %.2f m (limite tempo real %.2f m; sem validação seriam %.1f m)" % [elapsed, moved, limit, v * 0.05 * 240])
	c.set_process(true)


func _drain() -> void:
	c.peer.poll()
	while c.peer.get_available_packet_count() > 0:
		c._handle(c.peer.get_packet())


# ------------------------------------------------------------------ Bruno

func _bruno() -> void:
	check(await login("Bruno"), "entra no servidor (cadastro/login)")
	_move = Vector2(-1, 0.3)
	await wait(0.5)
	_move = Vector2.ZERO
	check(await wait_until(func() -> bool: return not find_player("Alice").is_empty(), 20.0), "vê o outro jogador (Alice) replicado")
	check(await wait_until(func() -> bool: return has_event(friend_events, "op", "request"), 20.0), "recebe pedido de amizade da Alice em tempo real")
	c.friend("accept", "Alice")
	check(c.vocation == "warrior" and is_equal_approx(c.move_speed, 4.0), "vocação: servidor confirmou guerreiro (%s, %.1f m/s)" % [c.vocation, c.move_speed])
	c.action("light")
	check(await wait_until(func() -> bool: return "light" in Protocol.effect_names(int(c.me.get("effects", 0))), 5.0), "luz: Luz (utevo vis lux) ligada pelo servidor")
	check(await wait_until(func() -> bool: return friend_presence("Alice", true) or _friend_listed("Alice"), 5.0), "presença: Alice online na lista de amigos")
	check(await wait_until(func() -> bool: return seen_damage, 40.0), "vê o dano no monstro (vida replicada pelo servidor)")
	check(seen_projectile, "vê a flecha da Alice (projétil replicado)")
	check(await wait_until(func() -> bool: return _chat_from("Alice", "pronto"), 40.0), "chat global da Alice chegou")
	await wait(1.0)
	var before := {"pos": server_pos(), "level": int(c.me.level), "xp": int(c.me.xp), "hp": int(c.me.hp)}
	var tok: String = c.token
	c.drop_connection()
	await wait(3.0)
	welcomes.clear()
	c.resume()
	check(await wait_until(func() -> bool: return not welcomes.is_empty(), 15.0) and bool(welcomes[0].get("resumed", false)), "reconecta por token (RESUME, sem senha)")
	await wait_until(func() -> bool: return int(c.snaps) > 2, 3.0)
	await wait(0.5)
	var after_pos := server_pos()
	check(after_pos.distance_to(before.pos) < 0.05 and int(c.me.level) == int(before.level) and int(c.me.xp) == int(before.xp), "volta no mesmo estado (pos %s → %s, nível %d, xp %d)" % [str(before.pos), str(after_pos), int(c.me.level), int(c.me.xp)])
	check(c.token == tok, "token preservado no cliente após RESUME")
	if not state_path.is_empty():
		var f := FileAccess.open(state_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"pos": [after_pos.x, after_pos.y, after_pos.z], "level": int(c.me.level), "xp": int(c.me.xp)}))
		f.close()
	await wait(6.0)   # Alice confere a presença online
	disconnects.clear()
	var big := PackedByteArray([Protocol.VERSION, Protocol.C_CHAT])
	big.resize(2000)
	c.send_raw(big, true)
	check(await wait_until(func() -> bool: return not disconnects.is_empty() or has_event(events, "type", "kicked"), 8.0), "servidor derruba quem manda pacote gigante (2000 B)")


func _friend_listed(n: String) -> bool:
	for f: Dictionary in (c.friends.get("friends", []) as Array):
		if String(f.name) == n and bool(f.online):
			return true
	return false


func _chat_from(who: String, text: String) -> bool:
	for m: Dictionary in chats:
		if String(m.get("from", "")) == who and String(m.get("text", "")) == text:
			return true
	return false


# ------------------------------------------------------------------ depois de reiniciar o servidor

func _relogin() -> void:
	var saved := {}
	if FileAccess.file_exists(state_path):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(state_path))
		if v is Dictionary:
			saved = v
	check(not saved.is_empty(), "estado anterior do Bruno registrado")
	c.connect_and_login("127.0.0.1", port, "Bruno", PASSWORD, false)
	check(await wait_until(func() -> bool: return not welcomes.is_empty(), 15.0), "login com senha após reiniciar o servidor")
	check(String(welcomes[0].get("vocation", "")) == "warrior" if not welcomes.is_empty() else false, "persistência: vocação guerreiro sobreviveu ao reinício")
	await wait_until(func() -> bool: return int(c.snaps) > 2, 5.0)
	var p: Array = saved.get("pos", [0, 0, 0])
	var sp := Vector3(float(p[0]), float(p[1]), float(p[2]))
	check(server_pos().distance_to(sp) < 0.05 and int(c.me.xp) == int(saved.get("xp", -1)) and int(c.me.level) == int(saved.get("level", -1)),
		"persistência: mesmo personagem, posição e XP após reiniciar (%s ~ %s)" % [str(server_pos()), str(sp)])
	check(_friend_listed("Alice") or _friend_in_list("Alice"), "persistência: amizade com Alice sobreviveu ao reinício")
	welcomes.clear()
	login_errors.clear()
	var c2: Node = NetClient.new()
	root.add_child(c2)
	var errs: Array = []
	c2.login_failed.connect(func(code: String) -> void: errs.append(code))
	c2.connect_and_login("127.0.0.1", port, "Bruno", "senha-errada", false)
	check(await wait_until(func() -> bool: return errs.has("auth"), 10.0), "senha errada é recusada")
	await _cave_round_trip()
	c.logout()
	await wait(0.6)


# ------------------------------------------------------------------ Bia (par do teste do cliente do jogo)

## Companheira do teste do cliente real (tools/net_game_client_test.sh): entra, fica
## perto da chegada, liga a Luz, fala no Local, aceita a amizade de "Tester" e espera.
func _buddy() -> void:
	var stay := float(NetConfig.cmdline_args().get("stay", 60.0))
	check(await login("Bia"), "entra no servidor (cadastro/login)")
	_move = Vector2(0.6, 0.4)
	await wait(0.6)
	_move = Vector2.ZERO
	check(await wait_until(func() -> bool: return not find_player("Tester").is_empty(), 40.0), "vê o cliente do jogo (Tester) replicado")
	c.action("light")
	await wait(1.0)
	c.chat("local", "ola Tester")
	check(await wait_until(func() -> bool: return has_event(friend_events, "op", "request"), 40.0), "recebe o pedido de amizade do Tester")
	c.friend("accept", "Tester")
	var end := Time.get_ticks_msec() + int(stay * 1000.0)
	while Time.get_ticks_msec() < end:
		if _chat_from("Tester", "pronto"):
			break
		await wait(0.5)
	check(_chat_from("Tester", "pronto"), "chat local do Tester chegou")
	c.logout()
	await wait(0.6)


# ------------------------------------------------------------------ gruta (andar -1)

const STAIRS_DOWN := Vector3(-38, 0, -31.3)
const STAIRS_UP := Vector3(-38, -8, -28.6)


## Desce pela boca da Gruta das Raízes e sobe pela escada de pedra (o servidor decide).
func _cave_round_trip() -> void:
	var down_ok: bool = await _go_to(STAIRS_DOWN, 40.0, func() -> bool: return server_pos().y < -4.0)
	check(down_ok, "gruta: desceu pela boca (andar -1, y %.1f)" % server_pos().y)
	if not down_ok:
		return
	var sees_guardian := await wait_until(func() -> bool:
		for e: Dictionary in c.entities():
			if int(e.kind) == Protocol.KIND_MONSTER and (e.pos as Vector3).y < -4.0:
				return true
		return false, 5.0)
	check(sees_guardian, "gruta: vê os monstros do andar -1")
	var up_ok: bool = await _go_to(STAIRS_UP, 20.0, func() -> bool: return server_pos().y > -1.0)
	check(up_ok, "gruta: subiu pela escada de pedra (y %.1f)" % server_pos().y)


## Caminho em grade (0,5 m, BFS) na colisão do andar atual até `goal`; segue os pontos
## até `done` ficar verdadeiro.
func _go_to(goal: Vector3, timeout: float, done: Callable) -> bool:
	var me := server_pos()
	var col: RefCounted = c.col_at(me.y)
	var path := _bfs(col, Vector2(me.x, me.z), Vector2(goal.x, goal.z))
	path.append(Vector2(goal.x, goal.z))
	var i := 0
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if done.call():
			_move = Vector2.ZERO
			return true
		var p: Vector3 = c.predicted_position()
		var here := Vector2(p.x, p.z)
		while i < path.size() - 1 and here.distance_to(path[i]) < 0.4:
			i += 1
		var d := path[i] - here
		_move = d.normalized() if d.length() > 0.05 else Vector2.ZERO
		await process_frame
	_move = Vector2.ZERO
	return bool(done.call())


func _bfs(col: RefCounted, a: Vector2, b: Vector2) -> Array[Vector2]:
	const CELL := 0.5
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(15, 15)
	var nx := int((absf(a.x - b.x) + 30.0) / CELL) + 1
	var nz := int((absf(a.y - b.y) + 30.0) / CELL) + 1
	var cell := func(p: Vector2) -> Vector2i: return Vector2i(clampi(int((p.x - lo.x) / CELL), 0, nx - 1), clampi(int((p.y - lo.y) / CELL), 0, nz - 1))
	var center := func(k: Vector2i) -> Vector2: return lo + (Vector2(k) + Vector2(0.5, 0.5)) * CELL
	var start: Vector2i = cell.call(a)
	var goal: Vector2i = cell.call(b)
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var k := queue[head]
		head += 1
		if k == goal:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := k + d
			if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz or prev.has(n):
				continue
			if n != goal and col.blocked(center.call(n), 0.32):
				continue
			prev[n] = k
			queue.append(n)
	var out: Array[Vector2] = []
	if not prev.has(goal):
		return out
	var k2 := goal
	while k2 != start:
		out.push_front(center.call(k2))
		k2 = prev[k2]
	return out


func _friend_in_list(n: String) -> bool:
	for f: Dictionary in (c.friends.get("friends", []) as Array):
		if String(f.name) == n:
			return true
	return false
