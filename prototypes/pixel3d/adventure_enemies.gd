# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Nearby hostile frogs and spiders: telegraphed attacks, real collision and XP deaths.
var adventure
var demo: Node
var actors: Array[Dictionary] = []
var _sphere := SphereMesh.new()
var _box := BoxMesh.new()

func _nameplate(kind: String, hp: int, maximum: int) -> String:
	return "%s  %d/%d" % ["Sapo" if kind == "frog" else "Aranha", hp, maximum]

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

func _spawn(id: String, kind: String, at: Vector3, cave: bool) -> void:
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
	if kind == "frog":
		_frog(model)
	else:
		legs = _spider(model)
	var label: Label3D = adventure.world.label(body, _nameplate(kind, cfg.hp, cfg.hp), Vector3(0, 1.35, 0), Color(1, 0.80, 0.68), 34)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.40
	ring.outer_radius = 1.48
	ring.rings = 24
	ring.ring_segments = 4
	var telegraph: MeshInstance3D = demo._mesh(ring, demo._toon(Color(0.9, 0.24, 0.05), Color(1, 0.16, 0.015), 1.4), Vector3(0, 0.035, 0), body, Vector3.ZERO, Vector3(1, 0.16, 1))
	telegraph.hide()
	var dead: bool = cave and adventure.state.cave_kills.has(id)
	actors.append({"id": id, "kind": kind, "body": body, "model": model, "home": at, "cave": cave, "hp": int(cfg.hp), "dead": dead, "respawn": 24.0, "windup": -1.0, "cooldown": 1.0, "label": label, "ring": telegraph, "legs": legs})
	if dead:
		body.collision_layer = 0
		body.hide()

func build(owner_adventure) -> void:
	adventure = owner_adventure
	demo = adventure.demo
	_sphere.radius = 1
	_sphere.height = 2
	_sphere.radial_segments = 8
	_sphere.rings = 4
	var spawns: Array = adventure.config.field_enemies
	for i in spawns.size():
		_spawn("field%d" % i, spawns[i].kind, Vector3(float(spawns[i].x), 0, float(spawns[i].z)), false)
	for i in int(adventure.config.cave_guardians):
		var local: Vector3 = adventure.world.CAVE_SPAWNS[i % adventure.world.CAVE_SPAWNS.size()]
		_spawn("cave%d" % i, "spider", adventure.world.ROOM + local, true)
	for i in adventure.world.TUNNEL_SPAWNS.size():
		var t: Array = adventure.world.TUNNEL_SPAWNS[i]
		_spawn("tunnel%d" % i, String(t[1]), adventure.world.ROOM + (t[0] as Vector3), true)

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
		adventure.on_enemy_killed(a.id, a.kind, a.cave, body.position)
	return true

func ring_damage(center: Vector3, radius: float, damage: int) -> void:
	for a: Dictionary in actors:
		if not a.dead and a.cave == adventure.in_cave and (a.body as Node3D).position.distance_to(center) < radius:
			hit(a.body, damage)

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
					adventure.state.respawn_enemy(a.id)
					adventure.chat.post("Servidor", "Um %s voltou a rondar %s." % [String(adventure.config.enemy[a.kind].name), adventure.region_name(a.home)])
					(a.label as Label3D).text = _nameplate(a.kind, a.hp, a.hp)
			continue
		body.visible = a.cave == adventure.in_cave
		if not body.visible:
			continue
		var distance := body.position.distance_to(player)
		(a.label as Label3D).visible = distance < 9
		if distance > 14:
			continue
		var cfg: Dictionary = adventure.config.enemy[a.kind]
		a.cooldown = maxf(0, float(a.cooldown) - delta)
		if float(a.windup) >= 0:
			a.windup = float(a.windup) - delta
			(a.ring as Node3D).visible = true
			if float(a.windup) < 0:
				(a.ring as Node3D).hide()
				if distance < 1.65 and absf(player.y - body.position.y) < 1.0:
					adventure.take_damage(int(cfg.damage), String(cfg.name))
				a.cooldown = 1.5
			continue
		var safe_camp: bool = not a.cave and player.distance_to(adventure.world.NPC) < 4.0
		var chase: bool = distance < 7.0 and body.position.distance_to(a.home) < 7.0 and not safe_camp and absf(player.y - body.position.y) < 1.0
		if chase and distance < 1.35 and float(a.cooldown) <= 0.0:
			a.windup = float(cfg.windup)
			(a.ring as Node3D).show()
			continue
		var target: Vector3 = player if chase else a.home
		var direction := target - body.position
		direction.y = 0
		var moving := direction.length() > (0.95 if chase else 0.15)
		body.velocity = direction.normalized() * float(cfg.speed) if moving else Vector3.ZERO
		body.velocity.y = -0.5 if body.is_on_floor() else -9.0  # volta ao chão depois de pedras
		body.move_and_slide()
		if moving:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-delta * 8.0))
		var model: Node3D = a.model
		model.position.y = maxf(0, sin(t * 9.0)) * 0.18 if moving and a.kind == "frog" else 0.0
		for i in a.legs.size():
			(a.legs[i] as Node3D).rotation.y = sin(t * 13.0 + i * 1.7) * 0.23 if moving else 0.0
