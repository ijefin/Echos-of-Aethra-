extends SceneTree
## Vocações: atributos, ataque básico, Q/R de Guerreiro e Arqueiro, Luz (core skill) nas três.
## godot --headless --path . -s res://src/game/tools/test_vocations.gd

const BASE := Vector3(200, 0, 200)  # arena isolada fora do mapa (piso próprio)

var demo: Node
var a
var _pins: Array = []  # [registro do inimigo, posição] mantidos parados


func _initialize() -> void:
	call_deferred("run")


func _frames(n: int) -> void:
	for i in n:
		for p: Array in _pins:
			var e: Dictionary = p[0]
			if not e.dead:
				(e.body as Node3D).global_position = p[1]
		await physics_frame


func _load(cls: String) -> void:
	if demo != null:
		demo.queue_free()
		await process_frame
	Engine.set_meta("aethra_class", cls)
	demo = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	a = demo._adventure
	a._persist = false
	_pins.clear()
	var floor_body := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(40, 1, 40)
	c.shape = s
	floor_body.add_child(c)
	demo._vp.add_child(floor_body)
	floor_body.global_position = BASE + Vector3(0, -0.5, 0)
	a.state.level = 5  # Q e R liberadas
	a.mana = 999.0
	demo._player.global_position = BASE
	await _frames(8)


## Inimigo i parado em `at` (relativo à arena), vida cheia.
func _enemy(i: int, at: Vector3) -> Dictionary:
	var e: Dictionary = a.enemies.actors[i]
	e.dead = false
	e.hp = int(a.config.enemy[e.kind].hp) * 10  # aguenta vários golpes: medimos o dano
	(e.body as CharacterBody3D).collision_layer = 8
	(e.body as Node3D).show()
	_pins.append([e, BASE + at])
	(e.body as Node3D).global_position = BASE + at
	return e


func _face(dir: Vector3) -> void:
	demo._aim = dir.normalized()
	demo._model.rotation.y = atan2(-dir.x, -dir.z)


func _attack(at: Vector3, node: Node3D = null) -> void:
	demo._attack_t = -1.0
	demo._attack_at(BASE + at, node)
	await _frames(60)


func run() -> void:
	var r := {}
	var hp := {}
	for cls: String in ["mage", "warrior", "archer"]:
		await _load(cls)
		hp[cls] = a.state.max_hp()
		# core skill Luz funciona em todas
		r["luz_" + cls] = a.core.cast("light") and a.core.remaining("light") > 0.0
		if cls == "warrior":
			var front := _enemy(0, Vector3(1.4, 0, 0))
			var back := _enemy(1, Vector3(-1.4, 0, 0))
			await _frames(3)
			var f0 := int(front.hp)
			var b0 := int(back.hp)
			await _attack(Vector3(3, 0, 0), front.body)
			r["espada_acerta_frente"] = int(front.hp) < f0
			r["espada_nao_acerta_costas"] = int(back.hp) == b0
			a.ring_cd = 0.0
			b0 = int(back.hp)
			r["redemoinho_acerta_em_volta"] = a.demo._voc.cast_r() and int(back.hp) < b0
			# Investida: inimigo a 5 m; termina colado nele e causa dano
			_pins.clear()
			demo._player.global_position = BASE + Vector3(0, 0, 6)
			var far := _enemy(2, Vector3(5, 0, 6))
			await _frames(5)
			var h0 := int(far.hp)
			demo._blink_cd = 0.0
			demo._dodge_t = -1.0
			var vp: Viewport = demo.get_viewport()
			# a Investida mira o mouse: sem mouse no teste, usa a direção do modelo
			_face(Vector3(1, 0, 0))
			a.mana = float(a.max_mana())  # Luz + Redemoinho gastaram a mana curta do Guerreiro
			var ok_q: bool = demo._voc.cast_q()
			demo._dodge_dir = Vector3(1, 0, 0)
			await _frames(40)
			var gap := Vector2(demo._player.global_position.x - (far.body as Node3D).global_position.x, demo._player.global_position.z - (far.body as Node3D).global_position.z).length()
			r["investida_alcanca_e_bate"] = ok_q and int(far.hp) < h0 and gap < 2.0
			print("  investida: dist final %.2f, dano %d" % [gap, h0 - int(far.hp)])
			# armadura: 30% menos dano
			a._invulnerable = 0.0
			var before: float = a.hp
			a.take_damage(10, "teste")
			r["armadura_reduz"] = absf((before - a.hp) - 7.0) < 0.01
		if cls == "archer":
			var target := _enemy(0, Vector3(10, 0, 0))
			await _frames(3)
			var t0 := int(target.hp)
			_face(Vector3(1, 0, 0))
			await _attack(Vector3(10, 0, 0), target.body)
			r["flecha_acerta_longe"] = int(target.hp) < t0
			# Flecha Perfurante: dois inimigos em linha levam dano
			_pins.clear()
			var e1 := _enemy(1, Vector3(4, 0, 3))
			var e2 := _enemy(2, Vector3(8, 0, 3))
			demo._player.global_position = BASE + Vector3(0, 0, 3)
			await _frames(5)
			var p1 := int(e1.hp)
			var p2 := int(e2.hp)
			a.ring_cd = 0.0
			demo._attack_t = -1.0
			demo._attack_target = BASE + Vector3(12, 0, 3)
			demo._attack_node = null
			_face(Vector3(1, 0, 0))
			demo._voc._arrow(float(demo._voc.cfg.r.damage_mult), true, 1.0)  # mesmo disparo do R, mira fixa
			await _frames(40)
			r["perfurante_atravessa"] = int(e1.hp) < p1 and int(e2.hp) < p2
			# Salto Evasivo: afasta-se da mira
			demo._player.global_position = BASE + Vector3(0, 0, -6)
			await _frames(5)
			var x0: float = demo._player.global_position.x
			demo._blink_cd = 0.0
			demo._begin_dash(Vector3(-1, 0, 0), float(demo._voc.cfg.q.distance) / float(demo._voc.cfg.q.time), float(demo._voc.cfg.q.time), "Dodge_Backward", "leap")
			await _frames(30)
			r["salto_afasta"] = x0 - demo._player.global_position.x > 3.5
		if cls == "mage":
			var m := _enemy(0, Vector3(4, 0, 0))
			await _frames(3)
			var m0 := int(m.hp)
			await _attack(Vector3(4, 0, 0), m.body)
			r["mago_bola_de_fogo"] = int(m.hp) < m0
	r["vida_guerreiro_maior"] = int(hp.warrior) > int(hp.archer) and int(hp.archer) > int(hp.mage)
	print("  vida: mago %d, guerreiro %d, arqueiro %d" % [hp.mage, hp.warrior, hp.archer])
	Engine.remove_meta("aethra_class")
	var ok := true
	for k: String in r:
		print("%s: %s" % [k, "OK" if r[k] else "FALHOU"])
		ok = ok and r[k]
	print("VOCATIONS: ", "OK" if ok else "FALHOU")
	quit(0 if ok else 1)
