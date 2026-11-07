extends SceneTree
## Teste do combate do mago: volta ao chão, acerto de perto, desnível e obstáculo.
## godot --headless --path . -s res://src/game/tools/test_mage_combat.gd

var demo: Node
var a


func _initialize() -> void:
	call_deferred("run")


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## Põe um inimigo de campo parado em `at` e devolve o registro dele.
func _enemy_at(at: Vector3) -> Dictionary:
	var e: Dictionary = a.enemies.actors[0]
	e.dead = false
	e.hp = int(a.config.enemy[e.kind].hp)
	e.cooldown = 99.0  # não ataca durante o teste
	e.windup = -1.0
	(e.body as CharacterBody3D).collision_layer = 8
	(e.body as Node3D).global_position = at
	e.home = at
	a.config.enemy[e.kind].speed = 0.0  # alvo parado: mede só a mira
	return e


## Atira no corpo do inimigo e diz se ele perdeu vida.
func _shoot(e: Dictionary) -> bool:
	var before := int(e.hp)
	demo._attack_t = -1.0
	a.mana = 999.0
	demo._attack_at((e.body as Node3D).global_position, e.body)
	for i in 70:
		await physics_frame
		if OS.has_environment("TRACE") and not demo._projectiles.is_empty():
			print("    bola ", (demo._projectiles[0].node as Node3D).global_position, " v=", demo._projectiles[0].vel)
	return int(e.hp) < before


func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	demo._vp.add_child(b)
	b.global_position = at
	return b


func run() -> void:
	demo = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	a = demo._adventure
	a._persist = false
	await _frames(10)
	var results := {}
	# arena isolada fora do mapa: só um piso plano no y = 0 (o cenário real não interfere)
	var base := Vector3(200, 0, 200)
	_box(base + Vector3(0, -0.5, 0), Vector3(40, 1, 40))

	# 1) sobe num bloco de 0,6 m, sai andando: tem que voltar ao chão (y ≈ 0)
	var ledge := _box(base + Vector3(0, 0.3, 0), Vector3(2, 0.6, 2))
	await _frames(2)
	demo._player.global_position = base + Vector3(0, 1.2, 0)
	await _frames(40)
	var on_top: float = demo._player.global_position.y
	demo._player.global_position = base + Vector3(0.9, on_top, 0)
	demo._player.velocity = Vector3(4, 0, 0)
	for i in 40:
		demo._player.velocity.x = 4.0
		await physics_frame
	await _frames(30)
	var after: float = demo._player.global_position.y
	results["volta_ao_chao"] = absf(on_top - 0.6) < 0.15 and absf(after) < 0.1
	print("  em cima=%.2f depois=%.2f" % [on_top, after])

	# 2) monstro colado no mago (0,6 m)
	demo._player.global_position = base + Vector3(-6, 0, 0)
	demo._player.velocity = Vector3.ZERO
	await _frames(10)
	var e := _enemy_at(demo._player.global_position + Vector3(0.6, 0, 0))
	await _frames(3)
	results["acerta_de_perto"] = await _shoot(e)

	# 3) mago em cima do bloco, monstro no chão a 3 m
	demo._player.global_position = base + Vector3(0, 1.2, 0)
	demo._player.velocity = Vector3.ZERO
	await _frames(20)
	e = _enemy_at(base + Vector3(-3.5, 0, 0))
	await _frames(3)
	results["acerta_de_cima"] = await _shoot(e)

	# 4) mago no chão, monstro em cima do bloco
	ledge.global_position = base + Vector3(0, 0.3, 0)
	demo._player.global_position = base + Vector3(-3.5, 0, 0)
	await _frames(10)
	e = _enemy_at(base + Vector3(0, 0.7, 0))
	await _frames(20)
	print("  monstro=%s mago=%s" % [(e.body as Node3D).global_position, demo._player.global_position])
	results["acerta_em_cima"] = await _shoot(e)
	print("  depois monstro=%s hp=%d" % [(e.body as Node3D).global_position, e.hp])

	# 5) parede entre os dois: o fogo para na parede
	ledge.queue_free()
	demo._player.global_position = base + Vector3(-4, 0, 6)
	await _frames(10)
	var wall := _box(base + Vector3(-2, 1, 6), Vector3(0.4, 2, 3))
	e = _enemy_at(base + Vector3(0, 0, 6))
	await _frames(3)
	results["parede_bloqueia"] = not await _shoot(e)
	wall.queue_free()

	var ok := true
	for k: String in results:
		print("%s: %s" % [k, "OK" if results[k] else "FALHOU"])
		ok = ok and results[k]
	print("MAGE_COMBAT: ", "OK" if ok else "FALHOU")
	quit(0 if ok else 1)
