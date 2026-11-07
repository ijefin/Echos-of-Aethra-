extends RefCounted
## IA de combate dos monstros (sem LLM): máquina de estados por monstro
## IDLE → PATROL → CHASE → WINDUP → ATTACK → RECOVER → (CHASE | RETURN).
##
## Desacoplada da apresentação e do jogador local:
## - `targets_provider` devolve [{id, pos, node?, safe?}] (hoje só o mago; no multiplayer,
##   os jogadores do servidor);
## - `damage_sink(id, amount, source) -> bool` e `slow_sink(id, factor, seconds)` aplicam efeitos;
## - `on_reset(actor)` avisa quando o monstro voltou para casa (o dono regenera a vida).
## Cada `actor` é o dicionário do dono, com ao menos: body (CharacterBody3D), home (Vector3),
## cfg (Dictionary de `enemy.<tipo>`), dead (bool), cooldown (float).
##
## Desempenho: decisão escalonada (0,1–0,5 s conforme o alvo mais próximo), monstros sem
## alvo por perto congelados, grade de hashing para alvos/vizinhos, A* só quando o destino
## andou além de `repath_dist`, e no máximo `max_paths_per_frame` caminhos por quadro.

const Brain := preload("res://src/game/ai/enemy_brain.gd")
const NavGrid := preload("res://src/game/ai/nav_grid.gd")
const SpatialHash := preload("res://src/game/ai/spatial_hash.gd")
const Perception := preload("res://src/game/ai/perception.gd")
const Projectiles := preload("res://src/game/ai/enemy_projectiles.gd")

const SLOTS := 8
const FLOOR_TOL := 2.5

var targets_provider: Callable
var damage_sink: Callable
var slow_sink: Callable
var on_reset: Callable
var space: PhysicsDirectSpaceState3D
var agents: Array[Dictionary] = []
var projectiles := Projectiles.new()
var targets: Array = []
var time := 0.0

# ajustes globais (por tipo ficam no JSON)
var active_radius := 26.0
var think_near := 0.1
var think_far := 0.5
var near_dist := 8.0
var far_dist := 24.0
var repath_dist := 1.0
var max_paths_per_frame := 3
var stuck_time := 0.8
var stuck_limit := 3

var stats := {"frames": 0, "usec": 0, "max_usec": 0, "paths": 0, "thinks": 0, "active": 0}

var _grids := {}
var _agent_hash := SpatialHash.new(2.0)
var _target_hash := SpatialHash.new(8.0)
var _slots := {}  # target_id -> Array (SLOTS) de Brain ou null
var _paths_this_frame := 0
var _target_rids: Array[RID] = []


func _init() -> void:
	projectiles.on_hit = _on_projectile_hit


# ------------------------------------------------------------------ registro

func add_agent(actor: Dictionary) -> void:
	var b := Brain.new()
	var home: Vector3 = actor.home
	b.rng.seed = hash(Vector3i(roundi(home.x * 10.0), roundi(home.y), roundi(home.z * 10.0)))
	b.think_t = fmod(agents.size() * 0.037, 0.3)  # escalona as decisões entre quadros
	b.idle_for = b.rng.randf_range(1.0, 4.0)
	actor.brain = b
	agents.append(actor)


## Zera a IA (respawn, morte, teleporte de teste).
func reset_agent(actor: Dictionary) -> void:
	var b: Brain = actor.brain
	_release_slot(b)
	b.target_id = ""
	b.attack = ""
	b.tele_kind = ""
	b.hop = 0.0
	b.path.clear()
	b.path_goal = Vector3.INF
	b.wants_move = false
	b.retreating = false
	b.stuck_count = 0
	b.special_cd = 1.0
	_enter(b, Brain.IDLE)


## Provoca o monstro (ex.: levou dano de longe): passa a perseguir o alvo `target_id`
## ou o mais próximo, mesmo sem visão. Quem está voltando para casa ignora.
func alert(actor: Dictionary, target_id := "") -> void:
	var b: Brain = actor.brain
	if actor.dead or b.state == Brain.RETURN:
		return
	var pos: Vector3 = (actor.body as Node3D).global_position
	var t: Dictionary = _find_target(target_id) if not target_id.is_empty() else Perception.nearest(targets, pos, _f(actor.cfg, "lose_radius", 10.0) * 1.5, FLOOR_TOL)
	if t.is_empty() or t.get("safe", false):
		return
	if b.target_id != String(t.id) or b.state <= Brain.PATROL:
		_engage(actor, b, t)
	b.last_seen = t.pos
	b.memory_until = time + _f(actor.cfg, "memory_s", 3.0)


func grid_for(y: float) -> NavGrid:
	var key := roundi(y)
	if not _grids.has(key):
		_grids[key] = NavGrid.new(float(key), 0.5, 0.3, 1 | 4)
	var g: NavGrid = _grids[key]
	g.space = space
	g.exclude = _target_rids
	return g


## Obstáculo novo/removido: esquece a grade em volta.
func invalidate_nav(center: Vector3, radius: float) -> void:
	for g: NavGrid in _grids.values():
		g.invalidate(center, radius)


func average_ms() -> float:
	return float(stats.usec) / maxf(1.0, float(stats.frames)) / 1000.0


# ------------------------------------------------------------------ quadro

func update(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	time += delta
	targets = targets_provider.call() if targets_provider.is_valid() else []
	_target_rids.clear()
	_target_hash.clear()
	for t: Dictionary in targets:
		if t.get("node") is CollisionObject3D:
			_target_rids.append((t.node as CollisionObject3D).get_rid())
		_target_hash.insert(t, t.pos)
	_agent_hash.clear()
	for a: Dictionary in agents:
		if not a.dead:
			_agent_hash.insert(a, (a.body as Node3D).global_position)
	_paths_this_frame = 0
	var active := 0
	for a: Dictionary in agents:
		if a.dead or a.get("disabled", false):
			continue
		if _update_agent(a, delta):
			active += 1
	projectiles.space = space
	projectiles.update(delta, targets)
	var us := Time.get_ticks_usec() - t0
	stats.frames = int(stats.frames) + 1
	stats.usec = int(stats.usec) + us
	stats.max_usec = maxi(int(stats.max_usec), us)
	stats.active = active


func _update_agent(a: Dictionary, delta: float) -> bool:
	var b: Brain = a.brain
	var body: CharacterBody3D = a.body
	var pos := body.global_position
	var cfg: Dictionary = a.cfg
	var near := _nearest_any(pos, active_radius)
	if near == INF:
		# ninguém por perto neste andar: congela (LoD); quem estava em combate volta para casa
		if b.state != Brain.IDLE and b.state != Brain.PATROL:
			body.global_position = a.home
			_arrive_home(a, b)
		b.frozen = true
		b.moving = false
		return false
	b.frozen = false
	b.state_t += delta
	a.cooldown = maxf(0.0, float(a.cooldown) - delta)
	b.special_cd = maxf(0.0, b.special_cd - delta)
	b.flash_t = maxf(0.0, b.flash_t - delta)
	b.think_t -= delta
	if b.think_t <= 0.0 and (b.state <= Brain.CHASE or b.state == Brain.RETURN):
		b.think_t = lerpf(think_near, think_far, clampf((near - near_dist) / (far_dist - near_dist), 0.0, 1.0))
		stats.thinks = int(stats.thinks) + 1
		_think(a, b, pos, cfg)
	_tick_combat(a, b, pos, cfg)
	_move(a, b, body, cfg, delta)
	return true


# ------------------------------------------------------------------ decisão

func _think(a: Dictionary, b: Brain, pos: Vector3, cfg: Dictionary) -> void:
	match b.state:
		Brain.IDLE, Brain.PATROL:
			var t := _acquire(a, pos, cfg)
			if not t.is_empty():
				_engage(a, b, t)
				_think_chase(a, b, pos, cfg)
				return
			if b.state == Brain.IDLE:
				b.wants_move = false
				if b.state_t > b.idle_for:
					b.idle_for = b.rng.randf_range(2.0, 5.0)
					var r := _f(cfg, "patrol_radius", 2.5)
					if r > 0.0:
						var ang := b.rng.randf() * TAU
						var home: Vector3 = a.home
						var goal := home + Vector3(cos(ang), 0, sin(ang)) * b.rng.randf_range(r * 0.4, r)
						if not grid_for(home.y).is_blocked_at(goal):
							_enter(b, Brain.PATROL)
							_go(a, b, pos, goal, 0.45)
					b.state_t = 0.0
			elif Perception.flat_distance(pos, b.move_goal) < 0.4 or not b.wants_move or b.state_t > 8.0:
				b.wants_move = false
				_enter(b, Brain.IDLE)
		Brain.CHASE:
			_think_chase(a, b, pos, cfg)
		Brain.RETURN:
			var home: Vector3 = a.home
			if Perception.flat_distance(pos, home) < 0.6:
				_arrive_home(a, b)
			else:
				_go(a, b, pos, home, 1.15)


## Alvo visível mais próximo dentro do raio de detecção (até 3 testes de visão).
func _acquire(a: Dictionary, pos: Vector3, cfg: Dictionary) -> Dictionary:
	var b: Brain = a.brain
	if time < b.calm_until:
		return {}
	var detect := _f(cfg, "detect_radius", 6.5)
	var found: Array = []
	for t: Dictionary in _target_hash.query(pos, detect):
		if t.get("safe", false) or absf((t.pos as Vector3).y - pos.y) > FLOOR_TOL:
			continue
		var d := Perception.flat_distance(pos, t.pos)
		if d <= detect:
			found.append([d, t])
	found.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	for i in mini(3, found.size()):
		var t: Dictionary = found[i][1]
		if _los(a, pos, t):
			return t
	return {}


func _engage(a: Dictionary, b: Brain, t: Dictionary) -> void:
	_release_slot(b)
	b.target_id = String(t.id)
	b.last_seen = t.pos
	b.memory_until = time + _f(a.cfg, "memory_s", 3.0)
	b.stuck_count = 0
	b.retreating = false
	_enter(b, Brain.CHASE)
	b.think_t = 0.0


func _give_up(a: Dictionary, b: Brain) -> void:
	_release_slot(b)
	b.target_id = ""
	b.retreating = false
	b.face_target = false
	b.path.clear()
	b.path_goal = Vector3.INF
	b.stuck_count = 0
	_enter(b, Brain.RETURN)
	b.think_t = 0.0


func _arrive_home(a: Dictionary, b: Brain) -> void:
	_release_slot(b)
	b.target_id = ""
	b.wants_move = false
	b.attack = ""
	b.tele_kind = ""
	b.hop = 0.0
	b.calm_until = time + 1.5  # histerese: não reage logo ao chegar
	_enter(b, Brain.IDLE)
	if on_reset.is_valid():
		on_reset.call(a)


func _think_chase(a: Dictionary, b: Brain, pos: Vector3, cfg: Dictionary) -> void:
	var home: Vector3 = a.home
	var t := _find_target(b.target_id)
	if t.is_empty() or t.get("safe", false) or absf((t.pos as Vector3).y - pos.y) > FLOOR_TOL:
		_give_up(a, b)
		return
	if Perception.flat_distance(pos, home) > _f(cfg, "leash", 12.0):
		_give_up(a, b)
		return
	var tp: Vector3 = t.pos
	var d := Perception.flat_distance(pos, tp)
	b.target_dist = d
	var vis := d <= _f(cfg, "lose_radius", 10.0) and _los(a, pos, t)
	b.seen = vis
	if vis:
		b.last_seen = tp
		b.memory_until = time + _f(cfg, "memory_s", 3.0)
	elif time > b.memory_until:
		_give_up(a, b)
		return
	# multiplayer: outro alvo visível bem mais perto rouba a atenção
	if vis and targets.size() > 1:
		var other := Perception.nearest(_target_hash.query(pos, d), pos, d - 2.5, FLOOR_TOL)
		if not other.is_empty() and String(other.id) != b.target_id and _los(a, pos, other):
			_engage(a, b, other)
			t = other
			tp = t.pos
			d = Perception.flat_distance(pos, tp)
	b.face = tp - pos
	if not vis:
		b.face_target = false
		if bool(cfg.get("ranged", false)):
			_go(a, b, pos, _ranged_spot(a, b, pos, b.last_seen, _f(cfg, "preferred_distance", 5.0), true), 1.0)
		elif Perception.flat_distance(pos, b.last_seen) > 0.6:
			_go(a, b, pos, b.last_seen, 1.0)
		else:
			b.wants_move = false
		return
	if float(a.cooldown) <= 0.0 and _try_attack(a, b, pos, cfg, tp, d):
		return
	if bool(cfg.get("ranged", false)):
		_think_ranged(a, b, pos, cfg, t, d)
	else:
		_think_melee(a, b, pos, cfg, t, d)


func _think_melee(a: Dictionary, b: Brain, pos: Vector3, cfg: Dictionary, t: Dictionary, d: float) -> void:
	var reach := _f(cfg, "attack_range", 1.3)
	b.face_target = d < reach + 1.0
	if d <= reach * 0.9:
		b.wants_move = false  # já está no alcance: espera a recarga, só separa dos outros
		return
	var r := maxf(_f(cfg, "preferred_distance", reach * 0.75), 0.8)
	_go(a, b, pos, _slot_position(a, b, t, pos, r), 1.0)


func _think_ranged(a: Dictionary, b: Brain, pos: Vector3, cfg: Dictionary, t: Dictionary, d: float) -> void:
	var pref := _f(cfg, "preferred_distance", 5.0)
	var retreat := _f(cfg, "retreat_distance", 3.0)
	var reach := _f(cfg, "attack_range", 7.5)
	var tp: Vector3 = t.pos
	# histerese: começa a recuar abaixo de `retreat`, para perto da distância preferida
	if d < retreat:
		b.retreating = true
	elif d >= pref - 0.4:
		b.retreating = false
	b.face_target = true
	if b.retreating:
		_go(a, b, pos, _ranged_spot(a, b, pos, tp, pref, false), _f(cfg, "retreat_speed_mul", 1.15))
	elif d > reach:
		_go(a, b, pos, _ranged_spot(a, b, pos, tp, pref, true), 1.0)
	else:
		b.wants_move = false  # na faixa boa e com visão: segura a posição e espera a recarga


func _try_attack(a: Dictionary, b: Brain, pos: Vector3, cfg: Dictionary, tp: Vector3, d: float) -> bool:
	var grid := grid_for((a.home as Vector3).y)
	if b.special_cd <= 0.0:
		if cfg.has("leap_max") and d >= _f(cfg, "leap_min", 2.2) and d <= _f(cfg, "leap_max", 4.2) and grid.line_clear(pos, tp):
			_start_attack(a, b, "leap", pos, tp, cfg)
			return true
		if cfg.has("charge_max") and d >= _f(cfg, "charge_min", 3.0) and d <= _f(cfg, "charge_max", 7.0) and grid.line_clear(pos, tp):
			_start_attack(a, b, "charge", pos, tp, cfg)
			return true
	if bool(cfg.get("ranged", false)):
		if d <= _f(cfg, "melee_range", 1.2):
			_start_attack(a, b, "bite", pos, tp, cfg)
			return true
		if d >= _f(cfg, "retreat_distance", 3.0) * 0.8 and d <= _f(cfg, "attack_range", 7.5):
			_start_attack(a, b, "spit", pos, tp, cfg)
			return true
		return false
	if d <= _f(cfg, "attack_range", 1.3):
		_start_attack(a, b, "bite", pos, tp, cfg)
		return true
	return false


# ------------------------------------------------------------------ ataques

func _start_attack(a: Dictionary, b: Brain, kind: String, pos: Vector3, tp: Vector3, cfg: Dictionary) -> void:
	_release_slot(b)
	var flat := Vector3(tp.x - pos.x, 0, tp.z - pos.z)
	var dir := flat.normalized() if flat.length() > 0.01 else -(a.body as Node3D).global_transform.basis.z
	b.attack = kind
	b.attack_hit.clear()
	b.attack_from = pos
	b.attack_dir = dir
	b.face = dir
	b.wants_move = false
	b.path.clear()
	b.path_goal = Vector3.INF
	match kind:
		"bite":
			b.attack_dur = _f(cfg, "windup", 0.6)
			b.tele_kind = "circle"
			b.tele_center = pos
			b.tele_radius = _f(cfg, "hit_radius", 1.6)
		"spit":
			b.attack_dur = _f(cfg, "windup", 0.55)
			b.tele_kind = "circle"
			b.tele_center = pos
			b.tele_radius = 0.75
		"leap":
			# trajetória definida já na preparação: o anel marca o ponto de pouso
			var to := pos + flat.limit_length(_f(cfg, "leap_max", 4.2))
			var grid := grid_for((a.home as Vector3).y)
			var c := grid.nearest_free(grid.world_to_cell(to), 2)
			if c != grid.world_to_cell(to):
				to = grid.cell_center(c)
			to.y = pos.y
			b.attack_to = to
			b.attack_dur = _f(cfg, "leap_windup", 0.75)
			b.tele_kind = "circle"
			b.tele_center = to
			b.tele_radius = _f(cfg, "leap_radius", 1.15)
		"charge":
			var length := minf(flat.length() + _f(cfg, "charge_overshoot", 1.5), _f(cfg, "charge_max", 7.0) + _f(cfg, "charge_overshoot", 1.5))
			var grid := grid_for((a.home as Vector3).y)
			var free := 0.0
			while free < length and not grid.is_blocked_at(pos + dir * (free + 0.5)):
				free += 0.5
			length = maxf(free, 1.0)
			b.attack_to = pos + dir * length
			b.attack_dur = _f(cfg, "charge_windup", 0.85)
			b.tele_kind = "lane"
			b.tele_center = pos + dir * (length * 0.5)
			b.tele_len = length
			b.tele_width = _f(cfg, "charge_width", 0.9)
	_enter(b, Brain.WINDUP)


func _tick_combat(a: Dictionary, b: Brain, pos: Vector3, cfg: Dictionary) -> void:
	match b.state:
		Brain.WINDUP:
			b.wants_move = false
			if b.attack == "bite" or b.attack == "spit":
				var t := _find_target(b.target_id)
				if not t.is_empty():
					b.face = (t.pos as Vector3) - pos
			if b.state_t >= b.attack_dur:
				_release(a, b, pos, cfg)
		Brain.ATTACK:
			match b.attack:
				"leap":
					var k := b.state_t / maxf(b.attack_dur, 0.01)
					b.hop = sin(PI * clampf(k, 0.0, 1.0)) * _f(cfg, "leap_height", 0.9)
					if k >= 1.0:
						b.hop = 0.0
						b.flash_t = 0.15
						b.tele_center = pos
						_area_damage(a, b, pos, _f(cfg, "leap_radius", 1.15), int(cfg.get("leap_damage", cfg.get("damage", 6))), cfg)
						_recover(b, _f(cfg, "leap_recover", 0.8))
				"charge":
					for t: Dictionary in _target_hash.query(pos, 2.0):
						var id := String(t.id)
						if t.get("safe", false) or b.attack_hit.has(id):
							continue
						if Perception.flat_distance(pos, t.pos) <= b.tele_width * 0.5 + 0.55 and absf((t.pos as Vector3).y - pos.y) < 1.0:
							b.attack_hit.append(id)
							b.flash_t = 0.15
							if _damage(id, int(cfg.get("charge_damage", cfg.get("damage", 6))), cfg):
								b.hits_landed += 1
					var travelled := Perception.flat_distance(pos, b.attack_from)
					var body: CharacterBody3D = a.body
					var hit_wall := b.state_t > 0.12 and Vector2(body.get_real_velocity().x, body.get_real_velocity().z).length() < _f(cfg, "charge_speed", 11.0) * 0.25
					if travelled >= b.tele_len - 0.1 or hit_wall or b.state_t > b.tele_len / _f(cfg, "charge_speed", 11.0) + 0.4:
						_recover(b, _f(cfg, "charge_recover", 1.0) * (1.6 if hit_wall else 1.0))
				_:
					if b.state_t >= 0.18:
						_recover(b, _f(cfg, "recover", 0.4))
		Brain.RECOVER:
			if b.state_t >= b.attack_dur:
				b.tele_kind = ""
				b.attack = ""
				_enter(b, Brain.CHASE)
				b.think_t = 0.0


## Instante do golpe: o dano só conta para quem está na área AGORA.
func _release(a: Dictionary, b: Brain, pos: Vector3, cfg: Dictionary) -> void:
	match b.attack:
		"bite":
			b.flash_t = 0.15
			_area_damage(a, b, pos, _f(cfg, "hit_radius", 1.6), int(cfg.get("damage", 6)), cfg)
			a.cooldown = _f(cfg, "cooldown", 1.5)
			_enter(b, Brain.ATTACK)
			b.attack_dur = 0.18
		"spit":
			var t := _find_target(b.target_id)
			var aim: Vector3 = (t.pos as Vector3) if not t.is_empty() else b.last_seen
			projectiles.fire(pos, aim, cfg, String(cfg.get("name", "monstro")), (a.body as CollisionObject3D).get_rid())
			b.flash_t = 0.1
			a.cooldown = _f(cfg, "cooldown", 2.2)
			_enter(b, Brain.ATTACK)
			b.attack_dur = 0.18
		"leap":
			b.special_cd = _f(cfg, "leap_cooldown", 4.5)
			a.cooldown = maxf(float(a.cooldown), _f(cfg, "cooldown", 1.5) * 0.6)
			_enter(b, Brain.ATTACK)
			b.attack_dur = _f(cfg, "leap_time", 0.5)
		"charge":
			b.special_cd = _f(cfg, "charge_cooldown", 5.0)
			a.cooldown = maxf(float(a.cooldown), _f(cfg, "cooldown", 1.4) * 0.6)
			_enter(b, Brain.ATTACK)
			b.attack_dur = b.tele_len / _f(cfg, "charge_speed", 11.0)


func _recover(b: Brain, seconds: float) -> void:
	_enter(b, Brain.RECOVER)
	b.attack_dur = seconds
	b.hop = 0.0


func _area_damage(a: Dictionary, b: Brain, center: Vector3, radius: float, amount: int, cfg: Dictionary) -> void:
	for t: Dictionary in _target_hash.query(center, radius + 0.5):
		if t.get("safe", false):
			continue
		var p: Vector3 = t.pos
		if Perception.flat_distance(center, p) <= radius and absf(p.y - center.y) < 1.0:
			if _damage(String(t.id), amount, cfg):
				b.hits_landed += 1


func _damage(id: String, amount: int, cfg: Dictionary) -> bool:
	if not damage_sink.is_valid():
		return false
	return bool(damage_sink.call(id, amount, String(cfg.get("name", "monstro"))))


func _on_projectile_hit(id: String, amount: int, factor: float, seconds: float, source: String) -> void:
	var applied := false
	if damage_sink.is_valid():
		applied = bool(damage_sink.call(id, amount, source))
	if applied and slow_sink.is_valid():
		slow_sink.call(id, factor, seconds)


# ------------------------------------------------------------------ movimento

func _go(a: Dictionary, b: Brain, pos: Vector3, goal: Vector3, mul: float) -> void:
	b.move_goal = goal
	b.wants_move = true
	b.speed_mul = mul
	var stale := b.path_goal == Vector3.INF or Perception.flat_distance(goal, b.path_goal) > repath_dist or b.path_i >= b.path.size() or b.need_repath
	if not stale:
		return
	if _paths_this_frame >= max_paths_per_frame and not b.path.is_empty() and not b.need_repath:
		return  # orçamento do quadro esgotado: segue o caminho antigo
	_paths_this_frame += 1
	stats.paths = int(stats.paths) + 1
	var grid := grid_for((a.home as Vector3).y)
	b.path = grid.find_path(pos, goal)
	b.path_i = 0
	b.path_goal = goal
	b.path_partial = grid.last_partial
	b.need_repath = false


func _move(a: Dictionary, b: Brain, body: CharacterBody3D, cfg: Dictionary, delta: float) -> void:
	var pos := body.global_position
	var vel := Vector3.ZERO
	var speed := _f(cfg, "speed", 1.5)
	var dashing := false
	if b.state == Brain.ATTACK and b.attack == "leap":
		var span := b.attack_to - b.attack_from
		vel = Vector3(span.x, 0, span.z) / maxf(_f(cfg, "leap_time", 0.5), 0.05)
		dashing = true
	elif b.state == Brain.ATTACK and b.attack == "charge":
		vel = b.attack_dir * _f(cfg, "charge_speed", 11.0)
		dashing = true
	elif b.wants_move and b.state != Brain.WINDUP and b.state != Brain.RECOVER and b.state != Brain.ATTACK:
		while b.path_i < b.path.size() - 1 and Perception.flat_distance(pos, b.path[b.path_i]) < 0.35:
			b.path_i += 1
		if b.path_i < b.path.size():
			var to := b.path[b.path_i] - pos
			to.y = 0
			if to.length() < 0.25 and b.path_i == b.path.size() - 1:
				if not b.path_partial:
					b.wants_move = false  # chegou (caminho parcial não conta: vira travamento)
			else:
				vel = to.normalized() * speed * b.speed_mul
	if not dashing:
		# separação: empurra para longe dos vizinhos (grade de hashing, sem O(n²))
		var sep := Vector3.ZERO
		for o: Dictionary in _agent_hash.query(pos, 1.2):
			if o == a or o.dead:
				continue
			var off := pos - (o.body as Node3D).global_position
			off.y = 0
			var l := off.length()
			if l < 1.1:
				if l < 0.01:
					off = Vector3(cos(float(b.rng.seed % 628) * 0.01), 0, sin(float(b.rng.seed % 628) * 0.01))
					l = 0.01
				sep += off / l * (1.1 - l)
		if sep != Vector3.ZERO and speed > 0.0:
			vel += sep * maxf(speed, 1.0) * 1.4
			vel = vel.limit_length(maxf(speed * b.speed_mul, 1.0) * 1.15)
		_check_stuck(a, b, pos, speed, delta)
	vel.y = -0.5 if body.is_on_floor() else -9.0  # volta ao chão depois de pedras
	body.velocity = vel
	body.move_and_slide()
	var flat_v := Vector3(vel.x, 0, vel.z)
	b.moving = flat_v.length() > 0.2
	var face := b.face if (b.state >= Brain.WINDUP and b.state <= Brain.RECOVER) or b.face_target else flat_v
	if dashing:
		face = b.attack_dir
	face.y = 0
	if face.length() > 0.05:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-delta * 9.0))


func _check_stuck(a: Dictionary, b: Brain, pos: Vector3, speed: float, delta: float) -> void:
	var travelling := b.wants_move and speed > 0.0 and (b.state == Brain.CHASE or b.state == Brain.RETURN or b.state == Brain.PATROL)
	if not travelling:
		b.stuck_clock = 0.0
		b.stuck_ref = pos
		return
	b.stuck_clock += delta
	if b.stuck_clock < stuck_time:
		return
	var moved := Perception.flat_distance(pos, b.stuck_ref)
	b.stuck_clock = 0.0
	b.stuck_ref = pos
	if moved >= maxf(0.15, speed * b.speed_mul * stuck_time * 0.25):
		b.stuck_count = 0
		return
	# sem progresso: o cenário pode ter mudado → esquece a grade local e recalcula
	b.stuck_events += 1
	b.stuck_count += 1
	grid_for((a.home as Vector3).y).invalidate(pos, 2.0)
	b.need_repath = true
	b.path_goal = Vector3.INF
	if b.stuck_count >= stuck_limit:
		b.stuck_count = 0
		if b.state == Brain.RETURN:
			(a.body as Node3D).global_position = a.home  # nem o caminho de casa existe: reaparece lá
			_arrive_home(a, b)
		elif b.state == Brain.PATROL:
			b.wants_move = false
			_enter(b, Brain.IDLE)
		else:
			_give_up(a, b)


# ------------------------------------------------------------------ apoio

## Slot de aproximação: SLOTS pontos ao redor do alvo; cada monstro pega o livre mais perto.
func _slot_position(a: Dictionary, b: Brain, t: Dictionary, pos: Vector3, r: float) -> Vector3:
	var id := String(t.id)
	var tp: Vector3 = t.pos
	if not _slots.has(id):
		var fresh: Array = []
		fresh.resize(SLOTS)
		_slots[id] = fresh
	var list: Array = _slots[id]
	var grid := grid_for((a.home as Vector3).y)
	var best := -1
	var best_d := INF
	for i in SLOTS:
		if list[i] != null and list[i] != b:
			continue
		var ang := TAU * i / SLOTS
		var p := tp + Vector3(cos(ang), 0, sin(ang)) * r
		if grid.is_blocked_at(p):
			continue
		var d := Perception.flat_distance(pos, p)
		if d < best_d:
			best_d = d
			best = i
	_release_slot(b)
	if best < 0:
		return tp  # todos ocupados: vai direto e a separação abre espaço
	list[best] = b
	b.slot = best
	b.slot_target = id
	var ang_b := TAU * best / SLOTS
	return tp + Vector3(cos(ang_b), 0, sin(ang_b)) * r


func _release_slot(b: Brain) -> void:
	if b.slot >= 0 and _slots.has(b.slot_target):
		var list: Array = _slots[b.slot_target]
		if list[b.slot] == b:
			list[b.slot] = null
	b.slot = -1
	b.slot_target = ""


## Ponto a `r` do alvo para o atirador: começa pelo lado onde já está (recuar = afastar),
## gira em passos de 45°; com `need_los`, exige linha de tiro até o alvo.
func _ranged_spot(a: Dictionary, b: Brain, pos: Vector3, center: Vector3, r: float, need_los: bool) -> Vector3:
	var grid := grid_for((a.home as Vector3).y)
	var home: Vector3 = a.home
	var leash := _f(a.cfg, "leash", 12.0)
	var away := Vector3(pos.x - center.x, 0, pos.z - center.z)
	var base := atan2(away.z, away.x) if away.length() > 0.05 else b.rng.randf() * TAU
	var rays := 0
	var fallback := Vector3.INF
	for step: int in [0, 1, -1, 2, -2, 3, -3, 4]:
		var ang := base + step * PI / 4.0
		var p := center + Vector3(cos(ang), 0, sin(ang)) * r
		p.y = pos.y
		if grid.is_blocked_at(p) or Perception.flat_distance(p, home) > leash - 0.5:
			continue
		if fallback == Vector3.INF:
			fallback = p
		if not need_los:
			return p
		if rays >= 3:
			break
		rays += 1
		var ex: Array[RID] = [(a.body as CollisionObject3D).get_rid()]
		ex.append_array(_target_rids)
		if Perception.line_of_sight(space, p, center, ex, 1):
			return p
	return fallback if fallback != Vector3.INF else center


func _los(a: Dictionary, pos: Vector3, t: Dictionary) -> bool:
	var ex: Array[RID] = [(a.body as CollisionObject3D).get_rid()]
	if t.get("node") is CollisionObject3D:
		ex.append((t.node as CollisionObject3D).get_rid())
	return Perception.line_of_sight(space, pos, t.pos, ex, 1)


func _find_target(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	for t: Dictionary in targets:
		if String(t.id) == id:
			return t
	return {}


func _nearest_any(pos: Vector3, radius: float) -> float:
	var best := INF
	for t: Dictionary in _target_hash.query(pos, radius):
		var p: Vector3 = t.pos
		if absf(p.y - pos.y) > FLOOR_TOL:
			continue
		var d := Perception.flat_distance(pos, p)
		if d <= radius and d < best:
			best = d
	return best


func _enter(b: Brain, s: int) -> void:
	b.state = s
	b.state_t = 0.0
	b.entered[s] = int(b.entered.get(s, 0)) + 1
	if s == Brain.CHASE or s == Brain.IDLE or s == Brain.RETURN or s == Brain.PATROL:
		b.tele_kind = ""
		b.attack = ""
		b.hop = 0.0


func _f(cfg: Dictionary, key: String, default: float) -> float:
	return float(cfg.get(key, default))
