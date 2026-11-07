extends SceneTree
## Teste da IA dos monstros numa arena isolada fora do mapa (200,0,200), com piso e
## obstáculos próprios. Cobre percepção, leash/memória, telegraph, salto, investida,
## aranha atiradora, teia, A* em L, travamento e desempenho com 30+ monstros.
## godot --headless --path . -s res://src/game/tools/test_enemy_ai.gd -- --no_save --mute

const Brain := preload("res://src/game/ai/enemy_brain.gd")
const BASE := Vector3(200, 0, 200)

var demo: Node
var a
var en
var dir
var hits: Array = []  # [segundos, dano, origem]
var slows: Array = []
var _n := 0
var _clock := 0.0


func _initialize() -> void:
	call_deferred("run")


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		_clock += 1.0 / Engine.physics_ticks_per_second


## Espera até `cond` ser verdadeira (máx. `seconds`). Devolve se aconteceu.
func _until(cond: Callable, seconds: float) -> bool:
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		if cond.call():
			return true
		await _frames(1)
	return bool(cond.call())


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


func _mk(kind: String, at: Vector3) -> Dictionary:
	_n += 1
	var e: Dictionary = en.spawn("teste%d" % _n, kind, at, false)
	e.cooldown = 0.0
	(e.brain as Brain).calm_until = -1.0
	return e


func _kill(e: Dictionary) -> void:
	e.dead = true
	e.respawn = 1e9
	(e.body as CharacterBody3D).collision_layer = 0
	(e.body as Node3D).hide()
	dir.reset_agent(e)
	en._hide_telegraph(e)


func _player(at: Vector3) -> void:
	demo._player.global_position = at
	demo._player.velocity = Vector3.ZERO


func _ppos() -> Vector3:
	return demo._player.global_position


func _dist(e: Dictionary) -> float:
	var p: Vector3 = (e.body as Node3D).global_position
	return Vector2(p.x - _ppos().x, p.z - _ppos().z).length()


func _state(e: Dictionary) -> int:
	return (e.brain as Brain).state


func run() -> void:
	demo = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	a = demo._adventure
	a._persist = false
	en = a.enemies
	dir = en.director
	await _frames(10)
	for e: Dictionary in en.actors:  # monstros do mapa ficam fora do teste
		_kill(e)
	_box(BASE + Vector3(0, -0.5, 0), Vector3(130, 1, 130))
	dir.damage_sink = func(id: String, amount: int, source: String) -> bool:
		hits.append([_clock, amount, source])
		return true
	dir.slow_sink = func(id: String, factor: float, seconds: float) -> void:
		slows.append([factor, seconds])
	var frog: Dictionary = a.config.enemy.frog
	var r := {}

	# 1) detecta e persegue
	var R := BASE + Vector3(-45, 0, -45)
	_player(R + Vector3(5.5, 0, 0))
	var f1 := _mk("frog", R)
	(f1.brain as Brain).special_cd = 99.0
	f1.cooldown = 99.0
	var chased := await _until(func() -> bool: return _state(f1) == Brain.CHASE, 1.5)
	var d0 := _dist(f1)
	await _frames(60)
	r["detecta_e_persegue"] = chased and _dist(f1) < d0 - 1.0
	print("  persegue: estado=%s dist %.2f -> %.2f" % [(f1.brain as Brain).state_name(), d0, _dist(f1)])

	# 2) alvo some além do raio de perda/leash: volta para casa e larga o alvo
	_player(R + Vector3(26, 0, 0))
	var returned := await _until(func() -> bool: return _state(f1) == Brain.RETURN, 8.0)
	var home_ok := await _until(func() -> bool: return _state(f1) == Brain.IDLE and (f1.body as Node3D).global_position.distance_to(f1.home) < 1.0, 15.0)
	r["perde_alvo_e_volta"] = returned and home_ok and (f1.brain as Brain).target_id.is_empty()
	print("  volta: RETURN=%s casa=%s pos=%s" % [returned, home_ok, (f1.body as Node3D).global_position - R])
	_kill(f1)

	# 2b) memória: some atrás de parede (dentro do raio) → procura por memory_s, depois desiste
	R = BASE + Vector3(-25, 0, -45)
	_box(R + Vector3(0, 1.5, 6), Vector3(10, 3, 0.4))
	dir.invalidate_nav(R, 12.0)
	_player(R + Vector3(5, 0, 0))
	var f2 := _mk("frog", R)
	(f2.brain as Brain).special_cd = 99.0
	f2.cooldown = 99.0
	await _until(func() -> bool: return _state(f2) == Brain.CHASE, 1.5)
	await _frames(10)
	_player(R + Vector3(0, 0, 8.5))
	var hid_at := _clock
	await _frames(int(float(frog.memory_s) * 0.5 * 60))
	var still := _state(f2) == Brain.CHASE
	var gave := await _until(func() -> bool: return _state(f2) == Brain.RETURN, float(frog.memory_s) + 2.0)
	r["memoria_e_desiste"] = still and gave
	print("  memória: ainda caçando em %.1fs=%s, desistiu após %.1fs=%s" % [float(frog.memory_s) * 0.5, still, _clock - hid_at, gave])
	_kill(f2)

	# 3) mordida: só acerta no fim do telegraph; erra se o jogador sai do anel
	R = BASE + Vector3(-5, 0, -45)
	_player(R + Vector3(1.0, 0, 0))
	var f3 := _mk("frog", R)
	(f3.brain as Brain).special_cd = 99.0
	hits.clear()
	var wound := await _until(func() -> bool: return _state(f3) == Brain.WINDUP, 2.0)
	var t_wind := _clock
	var none_before := hits.is_empty()
	await _until(func() -> bool: return not hits.is_empty(), 2.0)
	var delay := (float(hits[0][0]) if not hits.is_empty() else 0.0) - t_wind
	var hit_ok: bool = wound and none_before and hits.size() == 1 and delay >= float(frog.windup) - 0.05
	await _until(func() -> bool: return _state(f3) == Brain.WINDUP, 4.0)
	var n_hits := hits.size()
	await _frames(int(float(frog.windup) * 0.4 * 60))
	_player(R + Vector3(4.5, 0, 0))  # sai do anel durante a preparação
	await _until(func() -> bool: return _state(f3) == Brain.RECOVER, 2.0)
	var miss_ok := hits.size() == n_hits
	r["mordida_so_apos_telegraph"] = hit_ok
	r["mordida_erra_se_sair"] = miss_ok
	print("  mordida: preparou=%s dano após %.2fs (windup %.2f) | esquiva: dano extra=%d" % [wound, delay, float(frog.windup), hits.size() - n_hits])
	_kill(f3)

	# 3b) salto do sapo: acerta no pouso; esquiva lateral escapa
	R = BASE + Vector3(15, 0, -45)
	_player(R + Vector3(3.4, 0, 0))
	var f4 := _mk("frog", R)
	(f4.brain as Brain).special_cd = 0.0
	hits.clear()
	var leap1 := await _until(func() -> bool: return _state(f4) == Brain.WINDUP and (f4.brain as Brain).attack == "leap", 2.0)
	await _until(func() -> bool: return _state(f4) == Brain.RECOVER, 2.5)
	var leap_hit := hits.size() == 1 and int(hits[0][1]) == int(frog.leap_damage)
	_kill(f4)
	R = BASE + Vector3(15, 0, -30)
	_player(R + Vector3(3.4, 0, 0))
	var f5 := _mk("frog", R)
	(f5.brain as Brain).special_cd = 0.0
	hits.clear()
	var leap2 := await _until(func() -> bool: return _state(f5) == Brain.WINDUP and (f5.brain as Brain).attack == "leap", 2.0)
	await _frames(10)
	_player(R + Vector3(3.4, 0, 3.0))
	await _until(func() -> bool: return _state(f5) == Brain.RECOVER, 2.5)
	r["salto_acerta_no_pouso"] = leap1 and leap_hit
	r["salto_esquivavel"] = leap2 and hits.is_empty()
	print("  salto: acertou=%s | esquiva: danos=%d" % [leap_hit, hits.size()])
	_kill(f5)

	# 3c) investida do lobo: faixa marcada; quem sai da faixa não leva
	var wolf: Dictionary = a.config.enemy.wolf
	R = BASE + Vector3(35, 0, -45)
	_player(R + Vector3(5.5, 0, 0))
	var w1 := _mk("wolf", R)
	(w1.brain as Brain).special_cd = 0.0
	hits.clear()
	var ch1 := await _until(func() -> bool: return _state(w1) == Brain.WINDUP and (w1.brain as Brain).attack == "charge", 2.0)
	await _until(func() -> bool: return _state(w1) == Brain.RECOVER, 3.0)
	var ch_hit := hits.size() == 1 and int(hits[0][1]) == int(wolf.charge_damage)
	_kill(w1)
	R = BASE + Vector3(35, 0, -30)
	_player(R + Vector3(5.5, 0, 0))
	var w2 := _mk("wolf", R)
	(w2.brain as Brain).special_cd = 0.0
	hits.clear()
	var ch2 := await _until(func() -> bool: return _state(w2) == Brain.WINDUP and (w2.brain as Brain).attack == "charge", 2.0)
	await _frames(15)
	_player(R + Vector3(5.5, 0, 2.6))
	await _until(func() -> bool: return _state(w2) == Brain.RECOVER, 3.0)
	r["investida_acerta"] = ch1 and ch_hit
	r["investida_esquivavel"] = ch2 and hits.is_empty()
	print("  investida: acertou=%s | esquiva: danos=%d" % [ch_hit, hits.size()])
	_kill(w2)

	# 4) aranha mantém distância, recua quando o jogador chega e cospe teia
	var spider: Dictionary = a.config.enemy.spider
	R = BASE + Vector3(-45, 0, -10)
	_player(R + Vector3(6, 0, 0))
	var s1 := _mk("spider", R)
	s1.cooldown = 99.0
	await _frames(150)
	var keep := _dist(s1)
	_player((s1.body as Node3D).global_position + Vector3(1.8, 0, 0))
	await _frames(100)
	var after := _dist(s1)
	r["aranha_mantem_distancia"] = keep >= float(spider.retreat_distance) and keep <= float(spider.attack_range) + 0.5
	r["aranha_recua"] = after >= float(spider.retreat_distance) - 0.2
	print("  aranha: distância segurada %.2f, depois de chegar perto (1,8) -> %.2f" % [keep, after])
	hits.clear()
	slows.clear()
	s1.cooldown = 0.0
	var fired0: int = dir.projectiles.fired
	var spat := await _until(func() -> bool: return not hits.is_empty(), 5.0)
	r["aranha_cospe_e_acerta"] = spat and int(dir.projectiles.fired) > fired0 and not slows.is_empty()
	print("  aranha: teias=%d danos=%s lento=%s" % [int(dir.projectiles.fired) - fired0, hits, slows])
	_kill(s1)

	# 5) teia direta: acerta no aberto; parede bloqueia
	R = BASE + Vector3(-25, 0, -10)
	_player(R + Vector3(5, 0, 0))
	hits.clear()
	slows.clear()
	await _frames(2)
	dir.projectiles.fire(R, _ppos(), spider, "teia-teste", RID())
	await _frames(60)
	var open_hit := hits.size() == 1 and String(hits[0][2]) == "teia-teste" and slows.size() == 1
	_player(R + Vector3(5, 0, 10))
	_box(R + Vector3(2.5, 1, 10), Vector3(0.4, 2, 3))
	hits.clear()
	var blocked0: int = dir.projectiles.blocked
	await _frames(2)
	dir.projectiles.fire(R + Vector3(0, 0, 10), _ppos(), spider, "teia-teste", RID())
	await _frames(60)
	r["teia_acerta"] = open_hit
	r["teia_parede_bloqueia"] = hits.is_empty() and int(dir.projectiles.blocked) == blocked0 + 1
	print("  teia: aberto=%s | parede: danos=%d bloqueios=%d" % [open_hit, hits.size(), int(dir.projectiles.blocked) - blocked0])

	# 6) obstáculo em L: o A* contorna até o jogador
	R = BASE + Vector3(-5, 0, -10)
	_box(R + Vector3(2, 1, 0), Vector3(0.4, 2, 6.4))
	_box(R + Vector3(0, 1, 3), Vector3(4.4, 2, 0.4))
	dir.invalidate_nav(R, 12.0)
	_player(R + Vector3(4.5, 0, 0))
	var old_mem: float = frog.memory_s
	var old_leash: float = frog.leash
	frog.memory_s = 30.0
	frog.leash = 30.0
	var f6 := _mk("frog", R)
	(f6.brain as Brain).special_cd = 99.0
	f6.cooldown = 99.0
	await _frames(2)
	dir.alert(f6, "local")
	var straight := _dist(f6)
	await _frames(3)
	var wps: int = (f6.brain as Brain).path.size()
	var best := INF
	for i in 600:
		await _frames(1)
		best = minf(best, _dist(f6))
		if best < 2.0:
			break
	r["contorna_L_com_astar"] = best < 2.0 and wps >= 2
	print("  L: reta %.1f m, caminho com %d pontos, menor distância %.2f" % [straight, wps, best])
	_kill(f6)
	frog.memory_s = old_mem
	frog.leash = old_leash

	# 7a) alvo inalcançável (cercado por muro baixo, visível): trava → desiste e volta
	R = BASE + Vector3(15, 0, -10)
	_player(R + Vector3(5, 0, 0))
	_box(R + Vector3(5, 0.3, -1.6), Vector3(3.6, 0.6, 0.3))
	_box(R + Vector3(5, 0.3, 1.6), Vector3(3.6, 0.6, 0.3))
	_box(R + Vector3(3.4, 0.3, 0), Vector3(0.3, 0.6, 3.6))
	_box(R + Vector3(6.6, 0.3, 0), Vector3(0.3, 0.6, 3.6))
	dir.invalidate_nav(R, 12.0)
	var f7 := _mk("frog", R)
	(f7.brain as Brain).special_cd = 99.0
	f7.cooldown = 99.0
	var gave7 := await _until(func() -> bool: return _state(f7) == Brain.RETURN, 10.0)
	r["travado_desiste"] = gave7 and (f7.brain as Brain).stuck_events > 0
	print("  inalcançável: travamentos=%d desistiu=%s" % [(f7.brain as Brain).stuck_events, gave7])
	_kill(f7)

	# 7b) obstáculo novo (grade em cache desatualizada): trava → refaz a grade e contorna
	R = BASE + Vector3(35, 0, -10)
	_player(R + Vector3(6, 0, 0))
	var f8 := _mk("frog", R)
	(f8.brain as Brain).special_cd = 99.0
	f8.cooldown = 99.0
	await _until(func() -> bool: return _state(f8) == Brain.CHASE, 1.5)
	await _frames(6)
	_box((f8.body as Node3D).global_position + Vector3(1.3, 0.3, 0), Vector3(0.3, 0.6, 5.0))  # sem invalidar
	var best8 := INF
	for i in 600:
		await _frames(1)
		best8 = minf(best8, _dist(f8))
		if best8 < 1.6:
			break
	r["travamento_refaz_caminho"] = (f8.brain as Brain).stuck_events > 0 and best8 < 1.6
	print("  obstáculo novo: travamentos=%d menor distância %.2f" % [(f8.brain as Brain).stuck_events, best8])
	_kill(f8)

	# 8) desempenho: 32 monstros ativos em volta do jogador
	R = BASE + Vector3(10, 0, 30)
	_player(R)
	var crowd: Array[Dictionary] = []
	var kinds := ["frog", "spider", "wolf", "frog"]
	for i in 32:
		var ang := TAU * i / 32.0
		var rad := 5.0 + float(i % 4) * 2.0
		crowd.append(_mk(kinds[i % 4], R + Vector3(cos(ang), 0, sin(ang)) * rad))
	await _frames(5)
	dir.stats.frames = 0
	dir.stats.usec = 0
	dir.stats.max_usec = 0
	dir.stats.paths = 0
	dir.stats.thinks = 0
	await _frames(300)
	var avg: float = dir.average_ms()
	var states := {}
	for e: Dictionary in crowd:
		var nm: String = (e.brain as Brain).state_name()
		states[nm] = int(states.get(nm, 0)) + 1
	print("  desempenho: %d monstros ativos, IA média %.3f ms/quadro, pico %.3f ms, %d caminhos A*, %d decisões em %d quadros; estados %s" % [int(dir.stats.active), avg, float(dir.stats.max_usec) / 1000.0, int(dir.stats.paths), int(dir.stats.thinks), int(dir.stats.frames), states])
	r["desempenho_30_monstros"] = int(dir.stats.active) >= 30 and avg < 2.0

	var ok := true
	for k: String in r:
		print("%s: %s" % [k, "OK" if r[k] else "FALHOU"])
		ok = ok and r[k]
	print("ENEMY_AI: ", "OK" if ok else "FALHOU")
	quit(0 if ok else 1)
