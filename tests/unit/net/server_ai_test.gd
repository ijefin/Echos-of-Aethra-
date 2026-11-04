extends SceneTree
## IA real dos monstros no servidor (ServerWorld + ServerAI + ai/enemy_director.gd num
## World3D headless com a colisão exportada). Sem sockets:
##   godot --headless --path . -s res://tests/unit/net/server_ai_test.gd
## (Usa física 3D do Godot, então roda como SceneTree; dados = fixtures versionados.)

const N := "res://prototypes/pixel3d/net/"
const World := preload(N + "server_world.gd")
const ServerAI := preload(N + "server_ai.gd")
const Collision := preload(N + "world_collision.gd")
const NetConfig := preload(N + "net_config.gd")
const Protocol := preload(N + "net_protocol.gd")
const TUNING := "res://prototypes/pixel3d/data/first_adventure.json"
const DT := 0.05

var failures := 0
var passes := 0
var world: RefCounted
var col: RefCounted


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var cfg := NetConfig.load_config()
	var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TUNING))
	var floors: Dictionary = Collision.load_floors(N + "data/collision_surface.json", 100.0)
	col = floors[0]
	world = World.new(cfg, tuning, col)
	var holder := Node3D.new()
	root.add_child(holder)
	world.attach_ai(ServerAI.new(holder, floors))
	await physics_frame
	await physics_frame
	var n_field: int = (tuning.field_enemies as Array).size()
	var n_wolf: int = (tuning.enemy.wolf.get("spawns", []) as Array).size()
	check(world.monsters.size() == n_field + n_wolf, "IA: %d monstros (field_enemies %d + lobos %d)" % [world.monsters.size(), n_field, n_wolf])
	var leveled := 0
	for m: Dictionary in world.monsters.values():
		if int(m.level) > 1:
			leveled += 1
	check(leveled > 0, "IA: nível dos hunts vem de field_enemies.level (%d monstros com nível > 1)" % leveled)
	await _test_melee_chase()
	await _test_spider_web()
	await _test_kill_respawn()
	_test_dodge_and_safe()
	print("SERVER_AI: %s (%d ok, %d falhas)" % ["OK" if failures == 0 else "FALHOU", passes, failures])
	quit(0 if failures == 0 else 1)


func _first(kind: String) -> Dictionary:
	for m: Dictionary in world.monsters.values():
		if String(m.kind) == kind and String(m.state) != "dead":
			return m
	return {}


func _player_near(key: String, at: Vector3, offset: Vector2) -> Dictionary:
	var eid: int = world.add_player(key, key, {})
	var p: Dictionary = world.players[eid]
	var q: Vector2 = col.resolve(Vector2(at.x, at.z) + offset, 0.28)
	p.ms.pos = Vector3(q.x, 0, q.y)
	return p


func _steps(seconds: float, until: Callable = Callable()) -> bool:
	for i in int(seconds / DT):
		world.step(DT)
		world.events.clear()
		_check_inside()
		if until.is_valid() and until.call():
			return true
		if i % 4 == 0:
			await physics_frame
	return false


var _inside := 0
func _check_inside() -> void:
	for m: Dictionary in world.monsters.values():
		if String(m.state) != "dead" and col.blocked(Vector2(m.pos.x, m.pos.z), 0.05):
			_inside += 1


func _test_melee_chase() -> void:
	var frog := _first("frog")
	var p := _player_near("alvo_sapo", frog.home, Vector2(3.0, 0.0))
	var hp0 := float(p.hp)
	var d0 := Vector2(frog.pos.x - p.ms.pos.x, frog.pos.z - p.ms.pos.z).length()
	var min_d := d0
	var got := await _steps(12.0, func() -> bool:
		min_d = minf(min_d, Vector2(frog.pos.x - p.ms.pos.x, frog.pos.z - p.ms.pos.z).length())
		return float(p.hp) < hp0)
	check(min_d < d0 - 0.5, "IA: sapo persegue o jogador do servidor (%.1f → %.1f m)" % [d0, min_d])
	check(got, "IA: golpe da IA real tira vida autoritativa (%.0f → %.0f)" % [hp0, float(p.hp)])
	check(_inside == 0, "IA: monstros não entram em obstáculos exportados (%d amostras dentro)" % _inside)
	world.remove_player(int(p.eid))


func _test_spider_web() -> void:
	var sp := _first("spider")
	var p := _player_near("alvo_aranha", sp.home, Vector2(0.0, 5.0))
	var saw_shot := false
	var slowed := await _steps(15.0, func() -> bool:
		if not world.monster_shots.is_empty():
			world.index_interest()
			var snap: Dictionary = world.snapshot_for(int(p.eid))
			for e: Dictionary in snap.entities:
				if int(e.kind) == Protocol.KIND_PROJECTILE and int(e.sub) == 1:
					saw_shot = true
		return (p.effects as Dictionary).has("slow"))
	check(saw_shot, "IA: teia da aranha replicada no snapshot (projétil sub 1)")
	check(slowed, "IA: teia aplica lento autoritativo no jogador")
	if slowed:
		world.index_interest()
		var me: Dictionary = world.snapshot_for(int(p.eid)).me
		check("slow" in Protocol.effect_names(int(me.effects)), "IA: bit slow vai no snapshot do próprio jogador")
		var mv: Dictionary = world._move_cfg(p)
		check(is_equal_approx(float(mv.speed), 4.2 * float(p.slow_factor)), "IA: lento reduz a velocidade a pé no servidor (%.2f m/s)" % float(mv.speed))
	world.remove_player(int(p.eid))


func _test_kill_respawn() -> void:
	var wolf := _first("wolf")
	var p := _player_near("caçador", wolf.home, Vector2(4.0, 0.0))
	var key := String(wolf.key)
	world._damage_monster(wolf, 3, int(p.eid))
	await _steps(0.5)
	var a: Dictionary = world.ai.actors[int(wolf.eid)]
	var brain = a.brain
	check(brain.target_id == str(int(p.eid)), "IA: dano provoca o monstro (alvo = quem bateu)")
	world._damage_monster(wolf, 999, int(p.eid))
	check(String(wolf.state) == "dead" and bool(a.dead), "IA: monstro morto sai da IA")
	var xp_event := false
	for e: Dictionary in world.events:
		if String(e.type) == "kill" and int(e.to) == int(p.eid):
			xp_event = true
	check(xp_event, "IA: abate e XP continuam calculados no ServerWorld")
	world.events.clear()
	var back := await _steps(float(cfg_respawn()) + 1.0, func() -> bool: return String(wolf.state) != "dead")
	check(back and not bool(a.dead) and Vector2(wolf.pos.x - wolf.home.x, wolf.pos.z - wolf.home.z).length() < 1.5,
		"IA: %s renasce em casa e volta para a IA" % key)
	world.remove_player(int(p.eid))


func cfg_respawn() -> float:
	return float((world.cfg.get("monsters", {}) as Dictionary).get("respawn_s", 15.0))


func _test_dodge_and_safe() -> void:
	var p := _player_near("esquiva", Vector3(0, 0, 0), Vector2.ZERO)
	p.ms.dodge_t = 0.1
	check(not world.damage_player(int(p.eid), 5, "teste"), "IA: damage_sink falha durante a esquiva")
	p.ms.dodge_t = -1.0
	check(world.damage_player(int(p.eid), 5, "teste"), "IA: damage_sink pega fora da esquiva")
	p.ms.pos = world.NPC + Vector3(1, 0, 1)
	var t: Array = world.ai._targets()
	var mine: Dictionary = {}
	for x: Dictionary in t:
		if x.id == str(int(p.eid)):
			mine = x
	check(bool(mine.get("safe", false)), "IA: perto da Nessa o jogador é alvo seguro")
	world.remove_player(int(p.eid))
