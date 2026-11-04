extends SceneTree
## Andares no servidor: escadas superfície ↔ gruta (andar -1) com a colisão exportada,
## guardiões e tochas autoritativos, portal de volta, interesse por andar e persistência.
##   godot --headless --path . -s res://tests/unit/net/server_floors_test.gd
## Sem física (IA mínima); fixtures = colisão exportada + tuning do protótipo.

const N := "res://prototypes/pixel3d/net/"
const World := preload(N + "server_world.gd")
const Collision := preload(N + "world_collision.gd")
const NetConfig := preload(N + "net_config.gd")
const Protocol := preload(N + "net_protocol.gd")
const AdvWorld := preload("res://prototypes/pixel3d/adventure_world.gd")
const TUNING := "res://prototypes/pixel3d/data/first_adventure.json"

var failures := 0
var passes := 0
var w: RefCounted
var _seq := {}


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	var cfg := NetConfig.load_config(func(_k: String) -> String: return "")
	(cfg.monsters as Dictionary)["aggro_m"] = 0.0   # monstros parados: o teste é de andar
	var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TUNING))
	var floors: Dictionary = Collision.load_floors(N + "data/collision_surface.json", 100.0)
	w = World.new(cfg, tuning, floors[0], 7, {}, {}, floors)
	test_constants_match_game()
	test_cave_monsters()
	test_stairs_down_up(tuning)
	test_torches_and_guardians(tuning)
	test_portal_and_persistence()
	print("SERVER_FLOORS: %s (%d ok, %d falhas)" % ["OK" if failures == 0 else "FALHOU", passes, failures])
	quit(0 if failures == 0 else 1)


func test_constants_match_game() -> void:
	check(World.ROOM == AdvWorld.ROOM and World.PORTAL == AdvWorld.PORTAL and World.CHEST == AdvWorld.CHEST,
		"andares: sala, portal e baú iguais aos do jogo")
	check(str(World.STAIRS) == str(AdvWorld.STAIRS) and str(World.TORCHES) == str(AdvWorld.TORCHES)
		and str(World.CAVE_SPAWNS) == str(AdvWorld.CAVE_SPAWNS) and str(World.TUNNEL_SPAWNS) == str(AdvWorld.TUNNEL_SPAWNS),
		"andares: escadas, tochas e pontos de nascimento iguais aos do jogo")


func test_cave_monsters() -> void:
	var guardians := 0
	var tunnel := 0
	for m: Dictionary in w.monsters.values():
		if String(m.key).begins_with("cave") and is_equal_approx((m.home as Vector3).y, -8.0):
			guardians += 1
		if String(m.key).begins_with("tunnel"):
			tunnel += 1
	check(guardians == 8 and tunnel == World.TUNNEL_SPAWNS.size(), "gruta: 8 guardiões e %d do túnel no andar -1" % tunnel)


## Anda (comandos de verdade, validados) em direção a `to` por até `seconds`.
func walk(eid: int, to: Vector3, seconds: float, until: Callable = Callable()) -> bool:
	var p: Dictionary = w.players[eid]
	for i in int(seconds / 0.05):
		var me: Vector3 = p.ms.pos
		var d := Vector2(to.x - me.x, to.z - me.z)
		var seq: int = int(_seq.get(eid, 0)) + 1
		_seq[eid] = seq
		w.player_input(eid, [{"seq": seq, "dir": d.normalized() if d.length() > 0.1 else Vector2.ZERO, "flags": 0}])
		w.step(0.05)
		if until.is_valid() and until.call():
			return true
	return false


func _visible(observer: int) -> Array:
	w.index_interest()
	var out: Array = []
	for e: Dictionary in w.snapshot_for(observer).entities:
		out.append(int(e.id))
	return out


func test_stairs_down_up(_tuning: Dictionary) -> void:
	var down: Vector3 = World.STAIRS[0].down
	var a: int = w.add_player("ana", "Ana", {"pos": [down.x, 0.0, down.z + 2.2]})
	var b: int = w.add_player("bia", "Bia", {"pos": [down.x + 1.5, 0.0, down.z + 2.5]})
	var pa: Dictionary = w.players[a]
	w.events.clear()
	var went := walk(a, down, 3.0, func() -> bool: return int(pa.floor) == -1)
	check(went and is_equal_approx((pa.ms.pos as Vector3).y, -8.0), "escada: pisou na boca e desceu para o andar -1 (y %.1f)" % (pa.ms.pos as Vector3).y)
	var ev_ok := false
	for e: Dictionary in w.events:
		if String(e.type) == "floor" and int(e.eid) == a and int(e.floor) == -1:
			ev_ok = true
	check(ev_ok, "escada: evento 'floor' para a apresentação")
	check(w.region_of(pa.ms.pos) == "na Gruta das Raízes", "escada: região vira a gruta (presença dos amigos)")
	var vis_b := _visible(b)
	check(not vis_b.has(a), "interesse: quem ficou na superfície não vê quem desceu")
	var sees_guardian := false
	for id: int in _visible(a):
		if w.monsters.has(id) and String(w.monsters[id].key).begins_with("cave"):
			sees_guardian = true
	check(sees_guardian and not _visible(a).has(b), "interesse: na gruta vê os guardiões e não vê a superfície")
	# anda dentro da gruta sem sair do mapa nem atravessar parede
	var start: Vector3 = pa.ms.pos
	walk(a, start + Vector3(-30, 0, 0), 3.0)
	check(not (w.floors[-1] as RefCounted).blocked(Vector2(pa.ms.pos.x, pa.ms.pos.z), 0.2) and (pa.ms.pos as Vector3).y < -7.9,
		"gruta: a colisão do andar -1 segura o jogador (parou em %.1f, %.1f)" % [pa.ms.pos.x, pa.ms.pos.z])
	var up: Vector3 = World.STAIRS[0].up
	var back := walk(a, up, 8.0, func() -> bool: return int(pa.floor) == 0)
	check(back and absf((pa.ms.pos as Vector3).y) < 0.01, "escada: pisou na escada de pedra e subiu (%.1f, %.1f)" % [pa.ms.pos.x, pa.ms.pos.z])
	w.remove_player(a)
	w.remove_player(b)


func test_torches_and_guardians(tuning: Dictionary) -> void:
	var arrive: Vector3 = World.STAIRS[0].arrive
	var a: int = w.add_player("tocha", "Tocha", {"pos": [arrive.x, -8.0, arrive.z]})
	var p: Dictionary = w.players[a]
	check(int(p.floor) == -1, "tochas: jogador salvo na gruta volta no andar -1")
	check(w.player_action(a, {"act": "torch", "index": 0}) == "stage", "tochas: sem a missão da Nessa ativa nada acende")
	(p.state as RefCounted).accept_quest()
	var order: Array = tuning.torch_order
	check(w.player_action(a, {"act": "torch", "index": 0}) == "range", "tochas: longe demais (> 12 m) recusa")
	walk(a, World.ROOM + Vector3(6, 0, -5), 8.0)   # meio das Ruínas: as três tochas a menos de 12 m
	var wrong := int(order[1])
	check(w.player_action(a, {"act": "torch", "index": wrong}) == "order" and (p.state.lit as Array).is_empty(), "tochas: ordem errada apaga tudo")
	for i: Variant in order:
		w.player_action(a, {"act": "torch", "index": int(i)})
	check((p.state.lit as Array).size() == order.size(), "tochas: acesas na ordem I, II, III (%s)" % str(p.state.lit))
	var lit_ev := false
	for e: Dictionary in w.events:
		if String(e.type) == "torch" and int(e.to) == a and (e.lit as Array).size() == order.size():
			lit_ev = true
	check(lit_ev, "tochas: evento só para o jogador com a lista acesa")
	w.events.clear()
	for m: Dictionary in w.monsters.values():
		if String(m.key).begins_with("cave"):
			w._damage_monster(m, 9999, a)
	check((p.state.cave_kills as Dictionary).size() == int(tuning.cave_guardians) and (p.state as RefCounted).can_open_chest(),
		"guardiões: os 8 abates contam para o baú (cave_kills %d)" % (p.state.cave_kills as Dictionary).size())
	w.remove_player(a)


func test_portal_and_persistence() -> void:
	var a: int = w.add_player("portal", "Portal", {"pos": [World.PORTAL.x - 2.0, -8.0, World.PORTAL.z]})
	var p: Dictionary = w.players[a]
	walk(a, World.PORTAL, 2.0)
	check(int(p.floor) == -1, "portal: sem o colar não leva a lugar nenhum")
	(p.state as RefCounted).stage = "claimed"
	p.stair_cd = 0.0
	walk(a, World.PORTAL + Vector3(-2, 0, 0), 0.5)
	var ok := walk(a, World.PORTAL, 3.0, func() -> bool: return int(p.floor) == 0)
	if not ok:
		print("  portal: parou em %s, distância %.2f, bloqueado %s" % [str(p.ms.pos), Vector2(p.ms.pos.x - World.PORTAL.x, p.ms.pos.z - World.PORTAL.z).length(), str((w.floors[-1] as RefCounted).blocked(Vector2(World.PORTAL.x, World.PORTAL.z), 0.28))])
	check(ok and Vector2(p.ms.pos.x - World.NPC.x, p.ms.pos.z - World.NPC.z).length() < 3.5, "portal: com o colar volta para perto da Nessa")
	var data: Dictionary = w.remove_player(a)
	check(absf(float(data.pos[1])) < 0.01, "persistência: posição salva com a altura do andar")
