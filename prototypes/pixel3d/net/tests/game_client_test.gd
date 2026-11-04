# PROTOTYPE - NOT FOR PRODUCTION
extends SceneTree
## Teste de integração com o CLIENTE REAL do jogo (pixel3d_demo.tscn) contra um servidor
## local. Roteiro em tools/net_game_client_test.sh (servidor + bot "Bia" + este cliente):
##   godot --headless --path . -s res://prototypes/pixel3d/net/tests/game_client_test.gd --
##         --connect=127.0.0.1:17790 --user=Tester --pass=senha123 --register --class=mage --no_save --mute
## As teclas são simuladas com Input.parse_input_event (o jogo lê o teclado de verdade).

const Protocol := preload("res://prototypes/pixel3d/net/net_protocol.gd")
const AdvWorld := preload("res://prototypes/pixel3d/adventure_world.gd")

var demo: Node
var adv
var online
var fails := 0
var events: Array = []


func check(cond: bool, what: String) -> void:
	print("CHECK %s game: %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1


func _initialize() -> void:
	call_deferred("run")


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func wait_until(cond: Callable, timeout: float) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return bool(cond.call())


func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


## Segura WASD na direção `d` (x direita, y para baixo); ZERO solta tudo.
func _hold(d: Vector2) -> void:
	_key(KEY_D, d.x > 0.3)
	_key(KEY_A, d.x < -0.3)
	_key(KEY_S, d.y > 0.3)
	_key(KEY_W, d.y < -0.3)


func run() -> void:
	demo = (load("res://prototypes/pixel3d/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	adv = demo._adventure
	check(adv != null and adv.online != null, "jogo abriu em modo online (--connect)")
	if adv == null or adv.online == null:
		_end()
		return
	online = adv.online
	online.net.combat_event.connect(func(e: Dictionary) -> void: events.append(e))
	check(await wait_until(func() -> bool: return online.is_online(), 20.0), "cliente do jogo entrou no servidor")
	await wait_until(func() -> bool: return int(online.net.client.snaps) > 5, 5.0)
	var me: Dictionary = online.net.me()
	check(adv.enemies.actors.is_empty(), "nenhum monstro local no modo online")
	check(int(adv.hp) == int(me.hp) and int(adv.state.level) == int(me.level), "HUD = estado do servidor (vida %d, nível %d)" % [int(adv.hp), int(adv.state.level)])
	# andar com o teclado de verdade: o servidor confirma
	var start: Vector3 = me.pos
	_hold(Vector2(1, 0))
	await wait(1.0)
	_hold(Vector2.ZERO)
	await wait(0.6)
	var srv: Vector3 = online.net.me().pos
	var moved := Vector2(srv.x - start.x, srv.z - start.z).length()
	check(moved > 1.0 and moved < 4.2 * 1.4, "tecla D: servidor moveu o personagem %.2f m em ~1 s" % moved)
	check(demo._player.global_position.distance_to(srv) < 0.3, "corpo do jogo = posição do servidor (erro %.3f m)" % demo._player.global_position.distance_to(srv))
	# outro jogador e monstros vindos do snapshot
	check(await wait_until(func() -> bool: return _remote("Bia", Protocol.KIND_PLAYER) != null, 30.0), "vê a Bia (outro jogador) com modelo e nome")
	var bia: Dictionary = _remote("Bia", Protocol.KIND_PLAYER) if _remote("Bia", Protocol.KIND_PLAYER) != null else {}
	check(not bia.is_empty() and String((bia.label as Label3D).text).begins_with("Bia ") and (bia.label as Label3D).text.contains("/"),
		"nome + vida da Bia no rótulo estilo Tibia (\"%s\")" % (String((bia.label as Label3D).text) if not bia.is_empty() else ""))
	check(await wait_until(func() -> bool: return not bia.is_empty() and (bia.light as OmniLight3D).visible, 15.0), "vê a Luz da Bia")
	check(await wait_until(func() -> bool: return _chat_has("Local", "Bia: ola Tester"), 15.0), "chat Local da Bia chegou na aba Local")
	var mon := _nearest_monster()
	check(not mon.is_empty() and (mon.label as Label3D).text.contains("/"), "monstros do servidor desenhados com nome e vida (%s)" % (String((mon.label as Label3D).text) if not mon.is_empty() else "nenhum"))
	# amizade pelo painel (O) e pela API
	demo._unhandled_input(_press(KEY_O))
	check(adv.hud.panel == "friends", "tecla O abre o painel de amigos")
	online.friend("request", "Bia")
	check(await wait_until(func() -> bool: return _friend_online("Bia"), 20.0), "Bia aceitou: aparece online no painel de amigos")
	await process_frame
	adv.hud.panel = ""
	# conversar com a Nessa (tecla E): o servidor aceita a missão; o cliente só mostra
	var npc: Vector3 = AdvWorld.NPC
	var t_end := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < t_end and demo._player.global_position.distance_to(npc) > 2.0:
		var dn: Vector3 = npc - demo._player.global_position
		_hold(Vector2(dn.x, dn.z).normalized())
		await process_frame
	_hold(Vector2.ZERO)
	await wait(0.3)
	check(adv.interact_target() == "nessa", "perto da Nessa: E pede \"nessa\" ao servidor (%.1f m)" % demo._player.global_position.distance_to(npc))
	adv.interact()
	check(await wait_until(func() -> bool: return String(adv.state.stage) == "active", 5.0), "Nessa: missão aceita pelo servidor (estágio %s)" % String(adv.state.stage))
	check(_chat_has("Servidor", "Missão iniciada: As Três Brasas.") and not String(adv.world.npc_speech.text).is_empty(), "Nessa: aviso de missão no chat e fala sobre a cabeça")
	# bolsa (I) online: o pedido vai ao servidor e só o estado dele vale. Um item que só existe
	# na cópia local da bolsa é recusado pelo servidor: o equipamento não muda e o slot pisca.
	adv.hud.panel = "bag"
	adv.inventory.items.append("sentinel_staff")
	var sent: bool = adv.hud.drop_on_slot("sentinel_staff", "weapon")
	check(sent and adv.hud.pending_equip == "sentinel_staff" and String(adv.inventory.equipped.get("weapon", "")) == "fire_staff",
		"bolsa online: soltar no slot só pede ao servidor (arma local continua %s)" % String(adv.inventory.equipped.get("weapon", "")))
	check(await wait_until(func() -> bool: return adv.hud.pending_equip == "", 5.0) and adv.hud._reject_fx.has("weapon"),
		"bolsa online: servidor recusou (item fora da bolsa dele) e o slot piscou")
	check(String(adv.inventory.equipped.get("weapon", "")) == "fire_staff", "bolsa online: arma segue a do servidor")
	adv.inventory.items.erase("sentinel_staff")
	check(not adv.hud.drop_on_slot("iron_sword", "weapon"), "bolsa online: item de outra vocação recusado no cliente")
	adv.hud.panel = ""
	# caçar: andar até um monstro e atirar pelo caminho normal do jogo (_attack_at)
	var killed := await _hunt(45.0)
	check(killed, "abate de monstro pelo cliente do jogo (evento do servidor)")
	check(not killed or _chat_has("Servidor", "Você derrotou"), "mensagem de abate no chat Servidor")
	# fala no Local pelo chat do jogo
	adv.chat.active = "Local"
	adv.chat._submit("pronto")
	check(await wait_until(func() -> bool: return _chat_has("Local", "Tester: pronto"), 10.0), "chat do jogo enviou pela rede (eco do servidor)")
	await wait(1.5)
	_end()


func _end() -> void:
	print("BOT_DONE game %d" % fails)
	quit(0 if fails == 0 else 1)


func _press(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	return ev


func _remote(n: String, kind: int) -> Variant:
	for id: int in online.remotes:
		var r: Dictionary = online.remotes[id]
		if int(r.kind) == kind and String(r.name) == n:
			return r
	return null


func _nearest_monster(skip := {}) -> Dictionary:
	var best := {}
	var bd := INF
	for id: int in online.remotes:
		var r: Dictionary = online.remotes[id]
		if int(r.kind) != Protocol.KIND_MONSTER or skip.has(id):
			continue
		var d := (r.root as Node3D).global_position.distance_to(demo._player.global_position)
		if d < bd:
			bd = d
			best = r
			best["id"] = id
	return best


func _chat_has(tab: String, text: String) -> bool:
	for line: Array in adv.chat._log.get(tab, []):
		if String(line[0]).contains(text):
			return true
	return false


func _friend_online(n: String) -> bool:
	for f: Dictionary in (online.friends.get("friends", []) as Array):
		if String(f.get("name", "")) == n and bool(f.get("online", false)):
			return true
	return false


func _hunt(timeout: float) -> bool:
	var skip := {}
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	var seen := 0
	while Time.get_ticks_msec() < end:
		for i in range(seen, events.size()):
			var e: Dictionary = events[i]
			if String(e.get("type", "")) == "kill":
				_hold(Vector2.ZERO)
				return true
			if String(e.get("type", "")) == "refused" and String(e.get("reason", "")) == "los":
				var m0 := _nearest_monster(skip)
				if not m0.is_empty():
					skip[int(m0.id)] = true
		seen = events.size()
		var m := _nearest_monster(skip)
		if m.is_empty():
			skip.clear()
			await wait(0.3)
			continue
		var to: Vector3 = (m.root as Node3D).global_position - demo._player.global_position
		_hold(Vector2(to.x, to.z).normalized() if Vector2(to.x, to.z).length() > 6.0 else Vector2.ZERO)
		if Vector2(to.x, to.z).length() <= 9.5:
			var body: Node3D = null
			for ch: Node in (m.root as Node3D).get_children():
				if ch is StaticBody3D:
					body = ch
			demo._attack_at((m.root as Node3D).global_position, body)
		await wait(0.5)
	_hold(Vector2.ZERO)
	return false
