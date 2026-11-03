# PROTOTYPE - NOT FOR PRODUCTION
# Small readable animals for the sandbox: fox families, pond ducks and songbirds.
extends RefCounted

const Dressing := preload("res://prototypes/pixel3d/pixel3d_dressing.gd")
var _demo: Node
var _root: Node3D
var _rng := RandomNumberGenerator.new()
var _animals: Array[Dictionary] = []
var _sphere: SphereMesh
var _box := BoxMesh.new()

func _part(parent: Node3D, color: Color, at: Vector3, size: Vector3, box := false) -> MeshInstance3D:
	return _demo._mesh(_box if box else _sphere, _demo._toon_shared(color), at, parent, Vector3.ZERO, size)

func _eyes(parent: Node3D, x: float, y: float, z: float) -> void:
	for sign_x: float in [-1.0, 1.0]:
		_part(parent, Color(0.035, 0.04, 0.05), Vector3(sign_x * x, y, z), Vector3.ONE * 0.023)

func _dry(p: Vector2) -> bool:
	if Dressing.water_dist(p) < 0.85 or Dressing.cave_dist(p) < 2.8 or Dressing.plaza_dist(p) < 0.5:
		return false
	for tree: Array in _demo._tree_spots:
		var trunk: Vector3 = tree[0]
		if p.distance_squared_to(Vector2(trunk.x, trunk.z)) < 0.65:
			return false
	return true

func _land_point(center: Vector2, radius: float) -> Vector2:
	for i in 40:
		var p := center + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.5, radius)
		if _dry(p):
			return p
	return center

## Build small groups near habitat landmarks so animals are encountered together.
func build(root: Node3D, demo: Node, half: float) -> void:
	_demo = demo
	_root = root
	_rng.seed = 106
	_sphere = SphereMesh.new()
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 8
	_sphere.rings = 4
	for center: Vector2 in [Vector2(-7, -24), Vector2(8, 0), Vector2(-22, 25), Vector2(20, -30)]:
		for i in 2:
			_fox(_land_point(center, 3.0), 0.78 if i == 1 else 1.0)
	for i in 9:
		var p := Dressing.LAKE_C + Vector2.from_angle(float(i) * TAU / 9.0) * _rng.randf_range(2.0, 4.4)
		if Dressing.water_dist(p) < -0.8:
			_duck(p, i % 3 == 0)
	for i in 20:
		var center: Vector2 = [Vector2(5, -25), Vector2(-8, 6), Vector2(6, 2), Vector2(-12, 20)][i % 4]
		_bird(_land_point(center, 6.0), i)
	# Scattered foxes use the same habitat constraints as the nearby families.
	for i in 4:
		_fox(_land_point(Vector2(_rng.randf_range(-half * 0.8, half * 0.8), _rng.randf_range(-half * 0.8, half * 0.8)), 5.0), 1.0)

func _register(node: Node3D, p: Vector2, kind: String, limbs: Array = []) -> Dictionary:
	_root.add_child(node)
	node.position = Vector3(p.x, Dressing.WATER_Y + 0.08 if kind == "duck" else 0.0, p.y)
	var animal := {"node": node, "kind": kind, "home": p, "target": p, "wait": _rng.randf_range(1.0, 4.0), "phase": _rng.randf() * TAU, "limbs": limbs, "speed": 0.0}
	_animals.append(animal)
	return animal

func _fox(p: Vector2, size: float) -> void:
	var n := Node3D.new()
	_register(n, p, "fox")
	var fur := Color(0.73, 0.32, 0.12)
	var cream := Color(0.86, 0.80, 0.66)
	var dark := Color(0.18, 0.14, 0.12)
	_part(n, fur, Vector3(0, 0.35, 0.04), Vector3(0.19, 0.20, 0.38))
	_part(n, cream, Vector3(0, 0.29, -0.20), Vector3(0.13, 0.14, 0.12))
	_part(n, fur, Vector3(0, 0.50, -0.29), Vector3(0.18, 0.18, 0.20))
	_part(n, cream, Vector3(0, 0.44, -0.46), Vector3(0.10, 0.07, 0.15))
	_part(n, dark, Vector3(0, 0.46, -0.59), Vector3(0.04, 0.035, 0.04))
	for sx: float in [-0.12, 0.12]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.09
		ear.height = 0.22
		ear.radial_segments = 3
		_demo._mesh(ear, _demo._toon_shared(fur), Vector3(sx, 0.69, -0.26), n)
		_part(n, dark, Vector3(sx, 0.68, -0.30), Vector3(0.025, 0.055, 0.018))
	_eyes(n, 0.13, 0.54, -0.42)
	var limbs: Array = []
	for x: float in [-0.12, 0.12]:
		for z: float in [-0.20, 0.23]:
			limbs.append(_part(n, dark, Vector3(x, 0.14, z), Vector3(0.065, 0.28, 0.065), true))
	var tail := Node3D.new()
	n.add_child(tail)
	tail.position = Vector3(0, 0.32, 0.31)
	tail.rotation.x = -0.35
	_part(tail, fur, Vector3(0, 0, 0.20), Vector3(0.13, 0.13, 0.31))
	_part(tail, cream, Vector3(0, 0, 0.44), Vector3(0.105, 0.10, 0.13))
	n.scale = Vector3.ONE * size
	_animals.back().limbs = limbs
	_animals.back().tail = tail

func _duck(p: Vector2, brown: bool) -> void:
	var n := Node3D.new()
	_register(n, p, "duck")
	var body := Color(0.48, 0.34, 0.21) if brown else Color(0.76, 0.73, 0.62)
	var head := Color(0.43, 0.30, 0.16) if brown else Color(0.12, 0.36, 0.27)
	_part(n, body, Vector3(0, 0.09, 0), Vector3(0.20, 0.17, 0.32))
	_part(n, head, Vector3(0, 0.31, -0.23), Vector3(0.12, 0.14, 0.13))
	_part(n, Color(0.95, 0.63, 0.13), Vector3(0, 0.28, -0.39), Vector3(0.17, 0.055, 0.16), true)
	_part(n, Color(0.29, 0.27, 0.25), Vector3(0, 0.14, 0.28), Vector3(0.10, 0.08, 0.15))
	for x: float in [-0.16, 0.16]:
		_part(n, body.darkened(0.18), Vector3(x, 0.12, 0.05), Vector3(0.055, 0.11, 0.22))
	_eyes(n, 0.105, 0.35, -0.30)

func _bird(p: Vector2, index: int) -> void:
	var n := Node3D.new()
	_register(n, p, "bird")
	var color: Color = [Color(0.29, 0.40, 0.53), Color(0.51, 0.33, 0.20), Color(0.65, 0.43, 0.20)][index % 3]
	_part(n, color, Vector3(0, 0.14, 0), Vector3(0.11, 0.12, 0.16))
	_part(n, Color(0.81, 0.64, 0.40), Vector3(0, 0.12, -0.08), Vector3(0.085, 0.09, 0.07))
	_part(n, color, Vector3(0, 0.26, -0.11), Vector3(0.09, 0.09, 0.09))
	_part(n, Color(0.77, 0.57, 0.20), Vector3(0, 0.24, -0.22), Vector3(0.045, 0.028, 0.08))
	_part(n, color.darkened(0.15), Vector3(0, 0.17, 0.19), Vector3(0.055, 0.04, 0.13))
	_eyes(n, 0.07, 0.28, -0.16)
	var wings: Array = []
	for sx: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		n.add_child(wing)
		wing.position = Vector3(sx * 0.09, 0.18, 0)
		_part(wing, color.darkened(0.12), Vector3(sx * 0.09, 0, 0.03), Vector3(0.13, 0.025, 0.12))
		wings.append(wing)
	_animals.back().limbs = wings

## Nearby wildlife wanders within its habitat and reacts to the player.
func update(delta: float, t: float, player: Vector3, daylight: float) -> void:
	for a: Dictionary in _animals:
		var n: Node3D = a.node
		if n.position.distance_squared_to(player) > 32.0 * 32.0:
			continue
		var p := Vector2(n.position.x, n.position.z)
		var home: Vector2 = a.home
		var away := p - Vector2(player.x, player.z)
		var scared := away.length() < (4.5 if a.kind == "fox" else 2.8)
		a.wait = float(a.wait) - delta
		if float(a.wait) <= 0.0:
			var step := away.normalized() * 2.2 if scared else Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.8, 2.2)
			var target := p + step
			if target.distance_to(home) > 7.0:
				target = p.lerp(home, 0.4)
			if (a.kind == "duck" and Dressing.water_dist(target) < -0.8) or (a.kind != "duck" and _dry(target)):
				a.target = target
			# Pause to sniff, peck or drift rather than moving continuously.
			a.wait = _rng.randf_range(2.0, 5.0)
		var target: Vector2 = a.target
		var moving := p.distance_to(target) > 0.13
		var speed := (2.2 if scared else 0.75) if a.kind == "fox" else (0.40 if a.kind == "duck" else 0.65)
		var flight: bool = a.kind == "bird" and daylight > 0.2 and (scared or fmod(t + float(a.phase), 12.0) < 2.0)
		if moving:
			var dir := (target - p).normalized()
			var next := p + dir * minf(speed * delta, p.distance_to(target))
			var safe := Dressing.water_dist(next) < -0.6 if a.kind == "duck" else _dry(next)
			if safe:
				n.position.x = next.x
				n.position.z = next.y
			else:
				a.target = p
				a.wait = 0.3
			n.rotation.y = lerp_angle(n.rotation.y, atan2(-dir.x, -dir.y), 1.0 - exp(-delta * 5.0))
		if a.kind == "duck":
			n.position.y = Dressing.WATER_Y + 0.08 + sin(t * 2.2 + float(a.phase)) * 0.025
		elif a.kind == "bird":
			n.position.y = move_toward(n.position.y, 1.5 if flight else 0.0, delta * 2.5)
			for i in a.limbs.size():
				(a.limbs[i] as Node3D).rotation.z = sin(t * 25.0) * (0.8 if i == 0 else -0.8) if flight else 0.0
		else:
			for i in a.limbs.size():
				(a.limbs[i] as Node3D).rotation.x = sin(t * speed * 12.0 + (PI if i % 3 == 0 else 0.0)) * 0.45 if moving else 0.0
			(a.tail as Node3D).rotation.y = sin(t * 2.5 + float(a.phase)) * 0.17
