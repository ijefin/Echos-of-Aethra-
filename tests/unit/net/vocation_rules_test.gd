extends SceneTree
## Vocações e core skill Luz no servidor (regras puras, sem sockets e sem física):
##   godot --headless --path . -s res://tests/unit/net/vocation_rules_test.gd
## Fixtures: data/classes.json e data/core_skills.json do protótipo (fonte da verdade do
## cliente) + tuning mínimo e colisão montada no próprio teste.

const N := "res://prototypes/pixel3d/net/"
const World := preload(N + "server_world.gd")
const Collision := preload(N + "world_collision.gd")
const NetConfig := preload(N + "net_config.gd")
const Protocol := preload(N + "net_protocol.gd")
const Motion := preload(N + "player_motion.gd")
const CLASSES := "res://prototypes/pixel3d/data/classes.json"
const CORE := "res://prototypes/pixel3d/data/core_skills.json"

var failures := 0
var passes := 0
var classes: Dictionary
var core: Dictionary


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	classes = JSON.parse_string(FileAccess.get_file_as_string(CLASSES))
	core = JSON.parse_string(FileAccess.get_file_as_string(CORE))
	test_vocation_choice()
	test_speed_and_armor()
	test_warrior_melee_arc()
	test_archer_arrow_range()
	test_warrior_charge()
	test_archer_leap()
	test_warrior_whirl()
	test_archer_pierce()
	test_mage_unchanged()
	test_light_sync()
	print("VOCATION_RULES: %s (%d ok, %d falhas)" % ["OK" if failures == 0 else "FALHOU", passes, failures])
	quit(0 if failures == 0 else 1)


func _tuning() -> Dictionary:
	return {"xp_first": 10, "xp_step": 8, "max_level": 20, "player_hp": 60, "hp_per_level": 8, "basic_damage": 8,
		"regen_delay": 5.0, "regen_per_second": 0.0, "blink_level": 2, "ring_level": 3, "ring_damage": 18, "ring_radius": 3.2,
		"torch_order": [0, 2, 1], "cave_guardians": 8, "mana_base": 40, "mana_per_level": 6, "mana_regen_per_second": 0.0,
		"mana_cost": {"fire": 3, "blink": 10, "ring": 15}, "potion": {"hp_heal": 45, "mana_restore": 35, "start_hp": 3, "start_mana": 3, "cooldown": 1.0},
		"enemy": {"frog": {"name": "Sapo Bravio", "hp": 500, "damage": 6, "speed": 0.0, "xp": 3, "windup": 0.65}},
		"field_enemies": []}


func _world(col_data: Dictionary = {}) -> RefCounted:
	var cfg := NetConfig.load_config(func(_k: String) -> String: return "")
	cfg.spawn = [0.0, 0.0, 0.0]
	cfg.spawn_spread_m = 0.0
	(cfg.monsters as Dictionary)["aggro_m"] = 0.0   # IA mínima parada: só as regras do jogador
	var d := {"half": 100.0}
	d.merge(col_data, true)
	return World.new(cfg, _tuning(), Collision.new(d), 7, classes, core)


## Jogador da vocação `voc` na origem olhando para +x, com nível e mana à vontade.
func _player(w: RefCounted, voc: String, level := 5) -> Dictionary:
	var eid: int = w.add_player(voc + "_t", voc, {}, voc)
	var p: Dictionary = w.players[eid]
	p.state.level = level
	p.mana = 999.0
	p.ms.yaw = atan2(-1.0, 0.0)
	return p


func _frog(w: RefCounted, at: Vector2) -> Dictionary:
	return w.monsters[w.spawn_monster("t%d" % w.monsters.size(), "frog", Vector3(at.x, 0, at.y))]


func _lost(m: Dictionary) -> int:
	return int(m.max_hp) - int(m.hp)


func _base(p: Dictionary) -> int:
	return 8 + int(p.state.level) - 1


func test_vocation_choice() -> void:
	var w := _world()
	var wa := _player(w, "warrior", 1)
	var vw: Dictionary = classes.classes.warrior
	check(String(wa.vocation) == "warrior" and int(wa.state.max_hp()) == roundi(60 * float(vw.hp_mult)),
		"vocação: guerreiro novo nasce com vida × %.1f (%d)" % [float(vw.hp_mult), int(wa.state.max_hp())])
	check(int(w.combat.max_mana(1, wa)) == roundi(40 * float(vw.mana_mult)), "vocação: mana máxima × mana_mult (%d)" % int(w.combat.max_mana(1, wa)))
	var hack: int = w.add_player("x", "x", {}, "dragao")
	check(String(w.players[hack].vocation) == "mage", "vocação: id desconhecido vira mago")
	var saved: Dictionary = w.remove_player(int(wa.eid))
	var back: int = w.add_player("warrior_t", "warrior", saved, "archer")
	check(String(w.players[back].vocation) == "warrior", "vocação: a salva vence o pedido no login (não troca de classe relogando)")


func test_speed_and_armor() -> void:
	var w := _world()
	var ar := _player(w, "archer")
	var mv: Dictionary = w._move_cfg(ar)
	check(is_equal_approx(float(mv.speed), float(classes.classes.archer.speed)), "vocação: velocidade do arqueiro %.1f m/s no servidor" % float(mv.speed))
	var s := Motion.new_state(Vector3.ZERO)
	for i in 20:
		Motion.step(s, Vector2(1, 0), 0, 0.05, w.col, mv, 0.28)
	check(absf(s.pos.x - float(classes.classes.archer.speed)) < 0.01, "vocação: arqueiro anda %.2f m em 1 s" % s.pos.x)
	var wa := _player(w, "warrior")
	var hp0 := float(wa.hp)
	w.damage_player(int(wa.eid), 10, "teste")
	check(is_equal_approx(hp0 - float(wa.hp), 7.0), "vocação: armadura 30%% do guerreiro (10 → %.0f)" % (hp0 - float(wa.hp)))


func test_warrior_melee_arc() -> void:
	var w := _world()
	var p := _player(w, "warrior")
	var front := _frog(w, Vector2(1.8, 0))
	var side := _frog(w, Vector2(0, 1.5))
	var back := _frog(w, Vector2(-1.5, 0))
	var far := _frog(w, Vector2(3.6, 0.3))
	check(w.player_action(int(p.eid), {"act": "fire", "target": int(far.eid)}) == "range", "guerreiro: alvo a 3,6 m fora do alcance da espada (2,0 + raio 0,45 + tolerância 0,6)")
	check(w.player_action(int(p.eid), {"act": "fire", "target": int(front.eid)}) == "", "guerreiro: golpe no alvo à frente aceito")
	var dmg := roundi(_base(p) * float(classes.classes.warrior.damage_mult))
	check(_lost(front) == dmg, "guerreiro: acerta à frente com dano × 1,5 (%d)" % _lost(front))
	check(_lost(side) == 0 and _lost(back) == 0, "guerreiro: arco de 130° não pega lado (90°) nem costas")
	check(w.player_action(int(p.eid), {"act": "fire", "target": int(front.eid)}) == "cooldown", "guerreiro: recarga do golpe = attack_t")
	check(float(p.mana) == 999.0, "guerreiro: golpe básico não gasta mana (costs.fire = 0)")


func test_archer_arrow_range() -> void:
	var w := _world()
	var p := _player(w, "archer")
	var m := _frog(w, Vector2(15, 0))
	check(w.player_action(int(p.eid), {"act": "fire", "target": int(m.eid)}) == "", "arqueiro: flecha a 15 m aceita (alcance 24 × 0,75 = 18 m)")
	var j: Dictionary = w.projectiles.values()[0]
	check(is_equal_approx((j.vel as Vector3).length(), float(classes.classes.archer.arrow_speed)) and int(j.sub) == Protocol.PROJECTILE_SUBKINDS.find("arrow"),
		"arqueiro: flecha a 24 m/s replicada como projétil 'arrow'")
	for i in 20:
		w.step(0.05)
	check(_lost(m) == roundi(_base(p) * float(classes.classes.archer.damage_mult)), "arqueiro: flecha acerta com dano × 0,9 (%d)" % _lost(m))
	var mage := _player(w, "mage")
	mage.ms.pos = Vector3(0, 0, 5)
	var m2 := _frog(w, Vector2(15, 5))
	check(w.player_action(int(mage.eid), {"act": "fire", "target": int(m2.eid)}) == "range", "mago: bola de fogo a 15 m recusada (alcance 10,4)")


func test_warrior_charge() -> void:
	var w := _world({"boxes": [[0.0, 12.0, 3.0, 2.5, 0.0]]})
	var p := _player(w, "warrior")
	var m := _frog(w, Vector2(4, 0))
	check(w.player_action(int(p.eid), {"act": "q", "x": 10.0, "z": 0.0}) == "", "investida: aceita no nível 5")
	var pos: Vector3 = p.ms.pos
	check(pos.x > 2.5 and pos.x < 4.0, "investida: para no primeiro monstro do caminho (x %.2f)" % pos.x)
	var dmg := roundi(roundi(_base(p) * 1.5) * float(classes.classes.warrior.q.damage_mult))
	check(_lost(m) == dmg, "investida: dano básico × 1,3 (%d)" % _lost(m))
	check(float(p.mana) == 999.0 - float(classes.classes.warrior.costs.blink), "investida: custa costs.blink de mana")
	check(w.player_action(int(p.eid), {"act": "q", "x": 10.0, "z": 0.0}) == "cooldown", "investida: recarga q.cooldown")
	# contra a parede: anda até ela e não entra
	w.now += 10.0
	var p2 := _player(w, "warrior")
	p2.ms.pos = Vector3(0, 0, 7)
	check(w.player_action(int(p2.eid), {"act": "q", "x": 0.0, "z": 20.0}) == "", "investida: lançada contra parede")
	var z: float = p2.ms.pos.z
	check(z > 8.5 and z <= 9.5 - 0.27, "investida: para antes da parede (z %.2f; parede em 9,5)" % z)
	var lvl1 := _player(w, "warrior", 1)
	check(w.player_action(int(lvl1.eid), {"act": "q", "x": 5.0, "z": 0.0}) == "level", "investida: bloqueada no nível 1 (blink_level)")


func test_archer_leap() -> void:
	var w := _world()
	var p := _player(w, "archer")
	check(w.player_action(int(p.eid), {"act": "blink", "x": 5.0, "z": 0.0}) == "", "salto evasivo: aceito")
	var pos: Vector3 = p.ms.pos
	check(absf(pos.x + float(classes.classes.archer.q.distance)) < 0.3 and absf(pos.z) < 0.1, "salto evasivo: 5 m PARA TRÁS da mira (x %.2f)" % pos.x)


func test_warrior_whirl() -> void:
	var w := _world()
	var p := _player(w, "warrior")
	var a := _frog(w, Vector2(2.0, 0))
	var b := _frog(w, Vector2(-2.0, 0.5))
	var c := _frog(w, Vector2(0, 4.0))
	check(w.player_action(int(p.eid), {"act": "r"}) == "", "redemoinho: aceito no nível 5")
	var dmg := roundi(roundi(_base(p) * 1.5) * float(classes.classes.warrior.r.damage_mult))
	check(_lost(a) == dmg and _lost(b) == dmg, "redemoinho: 360°, frente e costas levam × 1,6 (%d)" % dmg)
	check(_lost(c) == 0, "redemoinho: fora do raio 2,6 não pega")


func test_archer_pierce() -> void:
	var w := _world()
	var p := _player(w, "archer")
	var a := _frog(w, Vector2(8, 0))
	var b := _frog(w, Vector2(11, 0))
	check(w.player_action(int(p.eid), {"act": "ring", "x": 20.0, "z": 0.0}) == "", "flecha perfurante: aceita")
	for i in 20:
		w.step(0.05)
	var dmg := roundi(roundi(_base(p) * 0.9) * float(classes.classes.archer.r.damage_mult))
	check(_lost(a) == dmg and _lost(b) == dmg, "flecha perfurante: atravessa e acerta os dois (%d cada)" % dmg)
	w.now += 10.0
	var a2 := _frog(w, Vector2(8, 2))
	var b2 := _frog(w, Vector2(11, 2))
	p.ms.pos = Vector3(0, 0, 2)
	w.player_action(int(p.eid), {"act": "fire", "target": int(b2.eid)})
	for i in 20:
		w.step(0.05)
	check(_lost(a2) > 0 and _lost(b2) == 0, "flecha comum para no primeiro monstro")


func test_mage_unchanged() -> void:
	var w := _world()
	var p := _player(w, "mage")
	var m := _frog(w, Vector2(2.5, 0))
	check(w.player_action(int(p.eid), {"act": "ring"}) == "", "mago: Anel de Brasa como antes")
	check(_lost(m) == 18 + int(p.state.level) - 1, "mago: dano do anel = ring_damage + nível − 1")
	check(w.player_action(int(p.eid), {"act": "blink", "x": 0.0, "z": -5.0}) == "" and absf(p.ms.pos.z + 5.0) < 0.01, "mago: Eco teleporta")


func test_light_sync() -> void:
	var w := _world()
	var a := _player(w, "warrior")
	var b := _player(w, "archer")
	b.ms.pos = Vector3(3, 0, 0)
	var light: Dictionary = core.skills.light
	var mana0 := float(a.mana)
	check(w.player_action(int(a.eid), {"act": "light"}) == "", "luz: guerreiro lança a core skill")
	check(float(a.mana) == mana0 - float(light.mana), "luz: custa %d de mana (core_skills.json)" % int(light.mana))
	var ev := {}
	for e: Dictionary in w.events:
		if String(e.type) == "light":
			ev = e
	check(not ev.is_empty() and is_equal_approx(float(ev.duration), float(light.duration)) and int(ev.to) == -1,
		"luz: evento para todos por perto com a duração (%.0f s)" % float(ev.get("duration", 0.0)))
	w.index_interest()
	var seen := {}
	for e: Dictionary in w.snapshot_for(int(b.eid)).entities:
		if int(e.id) == int(a.eid):
			seen = e
	check(not seen.is_empty() and "light" in Protocol.effect_names(int(seen.effects)), "luz: o outro jogador vê o bit 'light' no snapshot")
	var info: Dictionary = w.entity_info(int(a.eid))
	check(String(info.vocation) == "warrior" and absf(float(info.light_left) - float(light.duration)) < 0.01,
		"luz: entity_info leva vocação e tempo restante (%.0f s) para quem chega depois" % float(info.light_left))
	check(w.player_action(int(a.eid), {"act": "light"}) == "cooldown", "luz: recarga de %.0f s" % float(light.cooldown))
	for i in int((float(light.cooldown) + 1.0) / 0.05):
		w.step(0.05)
	check(w.player_action(int(a.eid), {"act": "light"}) == "" and absf(w.light_left(a) - float(light.duration)) < 0.06, "luz: relançar renova a duração")
	w.now += float(light.duration) + 1.0
	w.step(0.05)
	check(not (a.effects as Dictionary).has("light") and w.light_left(a) == 0.0, "luz: apaga no fim da duração")
