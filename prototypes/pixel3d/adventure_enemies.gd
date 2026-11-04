# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Monstros da superfície e da gruta: sapos (mordida + salto), aranhas (atiradoras de teia)
## e lobos (mordida + investida). Aqui ficam modelos, nomes, vida, XP, respawn e a
## apresentação (telegraph, animação). A decisão fica em `ai/enemy_director.gd`.
const Director := preload("res://prototypes/pixel3d/ai/enemy_director.gd")
const Brain := preload("res://prototypes/pixel3d/ai/enemy_brain.gd")
const RING_BASE := 1.44  # raio médio do toro do telegraph em escala 1

var adventure
var demo: Node
var actors: Array[Dictionary] = []
var director := Director.new()
var _sphere := SphereMesh.new()
var _box := BoxMesh.new()
var _ring_mesh := TorusMesh.new()
var _lane_mesh := BoxMesh.new()
var _mat_warn: Material
var _mat_hot: Material
var _mat_flash: Material
var _mat_spit: Material
var _mat_lane: Material
var _slow_until := -1.0
var _slow_factor := 1.0
var _web: MeshInstance3D
var _fx: Node3D  # raiz dos efeitos (anéis, faixas, teias) dentro do SubViewport

func _nameplate(kind: String, hp: int, maximum: int) -> String:
	var cfg: Dictionary = adventure.config.enemy.get(kind, {})
	var short := String(cfg.get("short", "Sapo" if kind == "frog" else "Aranha"))
	return "%s  %d/%d" % [short, hp, maximum]

func _part(parent: Node3D, at: Vector3, size: Vector3, color: Color, box := false) -> MeshInstance3D:
	return demo._mesh(_box if box else _sphere, demo._toon_shared(color), at, parent, Vector3.ZERO, size)

func _frog(parent: Node3D) -> void:
	var green := Color(0.28, 0.48, 0.16)
	_part(parent, Vector3(0, 0.25, 0), Vector3(0.40, 0.25, 0.39), green)
	_part(parent, Vector3(0, 0.36, -0.22), Vector3(0.34, 0.20, 0.28), green.lightened(0.1))
	for x: float in [-0.27, 0.27]:
		_part(parent, Vector3(x, 0.13, 0.20), Vector3(0.22, 0.13, 0.30), green.darkened(0.12))
		_part(parent, Vector3(x, 0.09, -0.25), Vector3(0.08, 0.09, 0.25), green)
		_part(parent, Vector3(x * 0.75, 0.55, -0.29), Vector3(0.105, 0.11, 0.10), Color(0.80, 0.68, 0.21))
		_part(parent, Vector3(x * 0.75, 0.56, -0.38), Vector3(0.04, 0.065, 0.025), Color(0.06, 0.07, 0.04))
	_part(parent, Vector3(0, 0.30, -0.48), Vector3(0.36, 0.025, 0.03), Color(0.12, 0.17, 0.08), true)

func _spider(parent: Node3D) -> Array[Node3D]:
	var dark := Color(0.23, 0.17, 0.27)
	_part(parent, Vector3(0, 0.37, 0.14), Vector3(0.40, 0.28, 0.46), dark)
	_part(parent, Vector3(0, 0.32, -0.36), Vector3(0.26, 0.21, 0.25), dark.lightened(0.06))
	var legs: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		for i in 4:
			var pivot := Node3D.new()
			parent.add_child(pivot)
			pivot.position = Vector3(side * 0.22, 0.30, -0.35 + i * 0.21)
			for section in 2:
				var a := Vector3.ZERO if section == 0 else Vector3(side * 0.38, 0.12, (i - 1.5) * 0.12)
				var b := Vector3(side * 0.38, 0.12, (i - 1.5) * 0.12) if section == 0 else Vector3(side * 0.58, -0.27, (i - 1.5) * 0.22)
				var limb := CylinderMesh.new()
				limb.top_radius = 0.025
				limb.bottom_radius = 0.045
				limb.height = a.distance_to(b)
				limb.radial_segments = 5
				var mesh: MeshInstance3D = demo._mesh(limb, demo._toon_shared(dark), (a + b) * 0.5, pivot)
				mesh.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
			legs.append(pivot)
	for x: float in [-0.12, -0.045, 0.045, 0.12]:
		var eye := SphereMesh.new()
		eye.radius = 0.037
		eye.height = 0.074
		eye.radial_segments = 5
		demo._mesh(eye, demo._toon(Color(0.95, 0.25, 0.08), Color(1, 0.12, 0.02), 1.4), Vector3(x, 0.39, -0.57), parent)
	return legs

## Lobo cinzento procedural: corpo, peito, cabeça com focinho, orelhas, cauda e 4 patas
## (pivôs devolvidos para a animação de passada).
func _wolf(parent: Node3D) -> Array[Node3D]:
	var grey := Color(0.44, 0.43, 0.47)
	var dark := grey.darkened(0.38)
	var light := Color(0.72, 0.70, 0.68)
	_part(parent, Vector3(0, 0.56, 0.08), Vector3(0.27, 0.25, 0.52), grey)
	_part(parent, Vector3(0, 0.62, -0.30), Vector3(0.27, 0.28, 0.27), grey.lightened(0.07))
	_part(parent, Vector3(0, 0.80, -0.56), Vector3(0.19, 0.18, 0.21), grey)
	_part(parent, Vector3(0, 0.74, -0.76), Vector3(0.10, 0.08, 0.14), light)
	_part(parent, Vector3(0, 0.77, -0.89), Vector3(0.04, 0.035, 0.035), Color(0.05, 0.05, 0.06))
	for x: float in [-0.1, 0.1]:
		_part(parent, Vector3(x, 0.99, -0.52), Vector3(0.05, 0.10, 0.04), dark)
		demo._mesh(_sphere, demo._toon(Color(0.95, 0.7, 0.2), Color(1, 0.6, 0.1), 1.2), Vector3(x * 0.8, 0.85, -0.72), parent, Vector3.ZERO, Vector3(0.03, 0.03, 0.02))
	var tail := Node3D.new()
	parent.add_child(tail)
	tail.position = Vector3(0, 0.66, 0.56)
	tail.rotation.x = 0.6
	_part(tail, Vector3(0, 0, 0.2), Vector3(0.07, 0.07, 0.24), dark)
	var legs: Array[Node3D] = []
	for z: float in [-0.30, 0.32]:
		for x: float in [-0.15, 0.15]:
			var pivot := Node3D.new()
			parent.add_child(pivot)
			pivot.position = Vector3(x, 0.46, z)
			_part(pivot, Vector3(0, -0.23, 0), Vector3(0.07, 0.24, 0.07), dark)
			legs.append(pivot)
	legs.append(tail)
	return legs

## Cria um monstro e o registra na IA. Devolve o registro (dicionário) do monstro.
func spawn(id: String, kind: String, at: Vector3, cave: bool) -> Dictionary:
	var cfg: Dictionary = adventure.config.enemy[kind]
	var body := CharacterBody3D.new()
	body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	body.floor_max_angle = deg_to_rad(46.0)
	body.floor_snap_length = 0.35
	body.collision_layer = 8
	body.collision_mask = 1 | 4
	body.set_meta("kind", "enemy")
	body.set_meta("enemy_index", actors.size())
	demo._vp.add_child(body)
	body.position = at
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.3
	col.shape = shape
	col.position.y = 0.65
	body.add_child(col)
	var model := Node3D.new()
	body.add_child(model)
	var legs: Array[Node3D] = []
	match kind:
		"frog":
			_frog(model)
		"wolf":
			legs = _wolf(model)
		_:
			legs = _spider(model)
	var label: Label3D = adventure.world.label(body, _nameplate(kind, cfg.hp, cfg.hp), Vector3(0, 1.45 if kind == "wolf" else 1.35, 0), Color(1, 0.80, 0.68), 34)
	var telegraph: MeshInstance3D = demo._mesh(_ring_mesh, _mat_warn, Vector3(0, 0.035, 0), body, Vector3.ZERO, Vector3(1, 0.16, 1))
	telegraph.top_level = true  # o anel fica no ponto do golpe (pouso do salto), não no corpo
	telegraph.hide()
	var dead: bool = cave and adventure.state.cave_kills.has(id)
	var actor := {"id": id, "kind": kind, "body": body, "model": model, "home": at, "cave": cave, "hp": int(cfg.hp), "dead": dead, "respawn": 24.0, "windup": -1.0, "cooldown": 1.0, "label": label, "ring": telegraph, "lane": null, "legs": legs, "cfg": cfg, "regen": 0.0}
	actors.append(actor)
	director.add_agent(actor)
	if dead:
		body.collision_layer = 0
		body.hide()
	return actor

func _spawn(id: String, kind: String, at: Vector3, cave: bool) -> void:
	spawn(id, kind, at, cave)

func build(owner_adventure) -> void:
	adventure = owner_adventure
	demo = adventure.demo
	_sphere.radius = 1
	_sphere.height = 2
	_sphere.radial_segments = 8
	_sphere.rings = 4
	_ring_mesh.inner_radius = 1.40
	_ring_mesh.outer_radius = 1.48
	_ring_mesh.rings = 24
	_ring_mesh.ring_segments = 4
	_lane_mesh.size = Vector3(1, 0.02, 1)
	_mat_warn = demo._toon(Color(0.9, 0.24, 0.05), Color(1, 0.16, 0.015), 1.4)
	_mat_hot = demo._toon(Color(1.0, 0.45, 0.2), Color(1, 0.32, 0.08), 2.6)
	_mat_flash = demo._toon(Color(1, 0.95, 0.85), Color(1, 0.9, 0.7), 3.0)
	_mat_spit = demo._toon(Color(0.55, 0.85, 0.3), Color(0.45, 1, 0.2), 1.6)
	_mat_lane = demo._toon(Color(0.75, 0.2, 0.05), Color(0.9, 0.18, 0.02), 1.1)
	_fx = Node3D.new()
	_fx.name = "EnemyFx"
	demo._vp.add_child(_fx)
	director.targets_provider = _targets
	director.damage_sink = _damage_target
	director.slow_sink = _slow_target
	director.on_reset = _on_reset
	director.projectiles.visual_parent = _fx
	director.projectiles.mat_ball = demo._toon(Color(0.88, 0.95, 0.78), Color(0.6, 0.95, 0.4), 1.3)
	director.projectiles.mat_splat = demo._toon(Color(0.86, 0.9, 0.8), Color(0.5, 0.6, 0.45), 0.5)
	var web := TorusMesh.new()
	web.inner_radius = 0.30
	web.outer_radius = 0.40
	web.rings = 12
	web.ring_segments = 3
	_web = demo._mesh(web, director.projectiles.mat_splat, Vector3.ZERO, _fx, Vector3.ZERO, Vector3(1, 0.2, 1))
	_web.top_level = true
	_web.hide()
	var spawns: Array = adventure.config.field_enemies
	for i in spawns.size():
		spawn("field%d" % i, spawns[i].kind, Vector3(float(spawns[i].x), 0, float(spawns[i].z)), false)
	for i in int(adventure.config.cave_guardians):
		var local: Vector3 = adventure.world.CAVE_SPAWNS[i % adventure.world.CAVE_SPAWNS.size()]
		spawn("cave%d" % i, "spider", adventure.world.ROOM + local, true)
	for i in adventure.world.TUNNEL_SPAWNS.size():
		var t: Array = adventure.world.TUNNEL_SPAWNS[i]
		spawn("tunnel%d" % i, String(t[1]), adventure.world.ROOM + (t[0] as Vector3), true)
	# matilhas de lobos: pontos próprios na seção `enemy.wolf.spawns` ([x, z])
	var wolves: Array = adventure.config.enemy.get("wolf", {}).get("spawns", [])
	for i in wolves.size():
		var w: Array = wolves[i]
		spawn("wolf%d" % i, "wolf", Vector3(float(w[0]), 0, float(w[1])), false)

# ------------------------------------------------------------------ ganchos da IA

## Alvos da IA. Hoje só o mago local; no multiplayer o servidor devolve todos os jogadores.
func _targets() -> Array:
	var p: CharacterBody3D = demo._player
	var pos := p.global_position
	var safe: bool = not adventure.in_cave and pos.distance_to(adventure.world.NPC) < 4.0
	return [{"id": "local", "pos": pos, "node": p, "safe": safe}]

## Dano no alvo; devolve se pegou (esquiva/teleporte/invulnerável = não pegou).
func _damage_target(id: String, amount: int, source: String) -> bool:
	if id != "local":
		return false
	var applied: bool = float(adventure._invulnerable) <= 0.0 and float(demo._blink_t) < 0.0 and float(demo._dodge_t) < 0.0
	adventure.take_damage(amount, source)
	return applied

func _slow_target(id: String, factor: float, seconds: float) -> void:
	if id != "local":
		return
	_slow_factor = factor
	_slow_until = director.time + seconds

## Fator de velocidade atual do jogador local (1 = normal). Para o demo aplicar direto.
func player_speed_factor() -> float:
	return _slow_factor if director.time < _slow_until else 1.0

func _on_reset(a: Dictionary) -> void:
	var cfg: Dictionary = a.cfg
	a.hp = int(cfg.hp)
	(a.label as Label3D).text = _nameplate(a.kind, a.hp, cfg.hp)

# ------------------------------------------------------------------ API de combate (mantida)

## Return whether a live hostile target consumed this hit.
func hit(collider: Object, damage: int) -> bool:
	if collider == null or String(collider.get_meta("kind", "")) != "enemy":
		return false
	var index := int(collider.get_meta("enemy_index", -1))
	if index < 0 or index >= actors.size() or actors[index].dead:
		return false
	var a: Dictionary = actors[index]
	var body: CharacterBody3D = a.body
	a.hp = maxi(0, int(a.hp) - damage)
	adventure.floating("-%d" % damage, body.position + Vector3(0, 1, 0), Color(1, 0.77, 0.37))
	var cfg: Dictionary = adventure.config.enemy[a.kind]
	(a.label as Label3D).text = _nameplate(a.kind, a.hp, cfg.hp)
	if int(a.hp) == 0:
		a.dead = true
		a.windup = -1.0
		a.respawn = 24.0
		body.collision_layer = 0
		body.hide()
		director.reset_agent(a)
		_hide_telegraph(a)
		adventure.on_enemy_killed(a.id, a.kind, a.cave, body.position)
	else:
		director.alert(a)  # levou dano de longe: vem atrás
	return true

func ring_damage(center: Vector3, radius: float, damage: int) -> void:
	for a: Dictionary in actors:
		if not a.dead and a.cave == adventure.in_cave and (a.body as Node3D).position.distance_to(center) < radius:
			hit(a.body, damage)

func ai_stats() -> Dictionary:
	return director.stats

# ------------------------------------------------------------------ quadro

func update(delta: float, t: float) -> void:
	var player: Vector3 = demo._player.global_position
	for a: Dictionary in actors:
		var body: CharacterBody3D = a.body
		if a.dead:
			if not a.cave or String(a.id).begins_with("tunnel"):
				a.respawn = float(a.respawn) - delta
				if float(a.respawn) <= 0.0 and player.distance_to(a.home) > 5.0:
					a.dead = false
					a.hp = int(adventure.config.enemy[a.kind].hp)
					a.cooldown = 1.0
					body.position = a.home
					body.collision_layer = 8
					director.reset_agent(a)
					adventure.state.respawn_enemy(a.id)
					adventure.chat.post("Servidor", "Um %s voltou a rondar %s." % [String(adventure.config.enemy[a.kind].name), adventure.region_name(a.home)])
					(a.label as Label3D).text = _nameplate(a.kind, a.hp, a.hp)
			continue
		body.visible = a.cave == adventure.in_cave
	director.space = demo._player.get_world_3d().direct_space_state
	director.update(delta)
	for a: Dictionary in actors:
		if a.dead:
			continue
		var body: CharacterBody3D = a.body
		if not body.visible:
			_hide_telegraph(a)
			continue
		var distance := body.position.distance_to(player)
		(a.label as Label3D).visible = distance < 9
		var b: Brain = a.brain
		if b.state == Brain.RETURN:
			# voltando para casa: regenera (20 % da vida por segundo)
			var maximum := int(a.cfg.hp)
			a.regen = float(a.regen) + maximum * 0.2 * delta
			if float(a.regen) >= 1.0 and int(a.hp) < maximum:
				a.hp = mini(maximum, int(a.hp) + int(a.regen))
				a.regen = fmod(float(a.regen), 1.0)
				(a.label as Label3D).text = _nameplate(a.kind, a.hp, maximum)
		if b.frozen:
			continue
		_animate(a, b, delta, t)
		_telegraph(a, b)
	_apply_slow()

## Lentidão da teia sem tocar no demo: desfaz parte do passo que o jogador acabou de dar.
func _apply_slow() -> void:
	var p: CharacterBody3D = demo._player
	var factor := player_speed_factor()
	_web.visible = factor < 1.0
	if factor >= 1.0:
		return
	_web.global_position = p.global_position + Vector3(0, 0.05, 0)
	_web.rotation.y += 0.05
	# o lento em si é aplicado na velocidade do jogador (pixel3d_demo._physics_process)

# ------------------------------------------------------------------ apresentação

## Corpo acompanha a IA: preparação (agacha/empina/abaixa), golpe no instante do dano,
## recuperação lenta. Tudo procedural (escala, inclinação, pulo do modelo).
func _animate(a: Dictionary, b: Brain, delta: float, t: float) -> void:
	var model: Node3D = a.model
	var kind: String = a.kind
	var k := b.phase()
	var sc := Vector3.ONE
	var lift := 0.0
	var pitch := 0.0
	var lunge := 0.0
	var roll := 0.0
	var shake := 0.0
	match b.state:
		Brain.WINDUP:
			shake = sin(t * 55.0) * 0.025 * k
			match kind:
				"frog":
					sc = Vector3(1.0 + 0.2 * k, 1.0 - 0.32 * k, 1.0 + 0.2 * k)
					pitch = 0.12 * k
				"wolf":
					pitch = -0.2 * k
					lunge = 0.22 * k
					sc = Vector3(1.0, 1.0 - 0.1 * k, 1.0 + 0.06 * k)
				_:
					pitch = 0.5 * k  # empina a frente para cuspir/morder
					sc = Vector3(1.0, 1.0 + 0.1 * k, 1.0)
		Brain.ATTACK:
			lift = b.hop
			match b.attack:
				"leap":
					sc = Vector3(0.88, 1.22, 0.88)
					pitch = -0.25 + 0.5 * k
				"charge":
					sc = Vector3(0.92, 0.94, 1.2)
					pitch = -0.12
				"spit":
					pitch = 0.15
					lunge = -0.18
				_:
					lunge = -0.38
					pitch = -0.08
		Brain.RECOVER:
			var s := 1.0 - k
			match b.attack:
				"leap":
					sc = Vector3(1.0 + 0.22 * s, 1.0 - 0.28 * s, 1.0 + 0.22 * s)
				"charge":
					roll = sin(t * 14.0) * 0.14 * s  # tonto depois da investida
				_:
					lunge = -0.12 * s
	var moving: bool = b.moving and b.state != Brain.ATTACK
	if moving and kind == "frog":
		lift = maxf(lift, maxf(0, sin(t * 9.0)) * 0.18)
	var w := 1.0 - exp(-delta * 18.0)
	model.scale = model.scale.lerp(sc, w)
	model.position = model.position.lerp(Vector3(shake, lift, lunge), w if b.state != Brain.ATTACK else 1.0)
	model.rotation.x = lerp_angle(model.rotation.x, pitch, w)
	model.rotation.z = lerp_angle(model.rotation.z, roll, w)
	var gait := 13.0 if b.state != Brain.ATTACK else 26.0
	var legs: Array = a.legs
	for i in legs.size():
		var leg: Node3D = legs[i]
		var go: bool = moving or (b.state == Brain.ATTACK and b.attack == "charge")
		if kind == "wolf":
			if i == legs.size() - 1:
				leg.rotation.y = sin(t * 8.0) * (0.35 if b.state == Brain.CHASE else 0.12)  # cauda
			else:
				leg.rotation.x = sin(t * gait + (i % 2) * PI + float(i / 2) * 0.6) * 0.55 if go else 0.0
		else:
			leg.rotation.y = sin(t * gait + i * 1.7) * 0.23 if go else (sin(t * 40.0 + i) * 0.08 * k if b.state == Brain.WINDUP else 0.0)

## Telegraph: anel no ponto do golpe (fica quente perto do instante do dano e pisca
## branco no impacto) ou faixa no chão para a investida.
func _telegraph(a: Dictionary, b: Brain) -> void:
	var ring: MeshInstance3D = a.ring
	var showing: bool = b.state == Brain.WINDUP or (b.state == Brain.ATTACK and (b.attack == "leap" or b.attack == "charge")) or b.flash_t > 0.0
	if not showing or b.tele_kind.is_empty():
		_hide_telegraph(a)
		return
	var hot := b.state == Brain.ATTACK or (b.state == Brain.WINDUP and b.phase() > 0.65)
	var mat: Material = _mat_flash if b.flash_t > 0.0 else (_mat_spit if b.attack == "spit" else (_mat_hot if hot else _mat_warn))
	if b.tele_kind == "circle":
		ring.show()
		ring.material_override = mat
		var s := b.tele_radius / RING_BASE
		ring.global_position = b.tele_center + Vector3(0, 0.035, 0)
		ring.scale = Vector3(s, 0.16, s)
		if a.lane != null:
			(a.lane as Node3D).hide()
	else:
		ring.hide()
		var lane: MeshInstance3D = a.lane
		if lane == null:
			lane = demo._mesh(_lane_mesh, _mat_lane, Vector3.ZERO, _fx)
			lane.top_level = true
			a.lane = lane
		lane.show()
		lane.material_override = _mat_flash if b.flash_t > 0.0 else (_mat_hot if hot else _mat_lane)
		var dir := b.attack_dir
		lane.global_position = b.tele_center + Vector3(0, 0.03, 0)
		lane.rotation = Vector3(0, atan2(-dir.x, -dir.z), 0)
		lane.scale = Vector3(b.tele_width, 1, b.tele_len)

func _hide_telegraph(a: Dictionary) -> void:
	(a.ring as Node3D).hide()
	if a.lane != null:
		(a.lane as Node3D).hide()
