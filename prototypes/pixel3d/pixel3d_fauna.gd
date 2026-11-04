# PROTOTYPE - NOT FOR PRODUCTION
# Vida de chão e de bosque: arbustos (alguns com frutinhas), coelhos saltitando, cervos
# que fogem, borboletas de dia, fadas nas árvores mágicas (violeta), colmeias com abelhas
# e entradas de caverna com cogumelos que brilham. Animais longe do jogador ficam parados.
extends RefCounted

const Dressing := preload("res://prototypes/pixel3d/pixel3d_dressing.gd")
const WorldLayout := preload("res://prototypes/pixel3d/world/world_layout.gd")
const ACTIVE_RADIUS := 32.0

var _demo: Node
var _root: Node3D
var _rng := RandomNumberGenerator.new()
var _rabbits: Array = []   # {node, t, from, to, wait}
var _deer: Array = []      # {node, target, speed, legs, phase}
var _fairies: Array = []   # {node, light, center, a, b, c, r}
var butterflies: GPUParticles3D


func build(root: Node3D, demo: Node, tree_spots: Array, half: float) -> void:
	_demo = demo
	_root = root
	_rng.seed = 21
	_bushes(half)
	for i in 28:
		_rabbits.append(_new_rabbit(_free_point(half, 2.0)))
	for i in 12:
		_deer.append(_new_deer(_free_point(half, 3.0)))
	var violet: Array = tree_spots.filter(func(s: Array) -> bool: return String(s[2]) == "violet")
	for i in mini(10, violet.size()):
		var s: Array = violet[_rng.randi() % violet.size()]
		_fairies.append(_new_fairy(s[0], float(s[1])))
	var others: Array = tree_spots.filter(func(s: Array) -> bool: return String(s[2]) in ["green", "golden"])
	for i in mini(9, others.size()):
		var s: Array = others[_rng.randi() % others.size()]
		_hive(s[0], float(s[1]))
	for c: Vector2 in Dressing.CAVES:
		_cave(c)
	_butterflies()


## Borboletas coloridas em volta do jogador (só de dia; presas ao emissor de vida no ar).
func _butterflies() -> void:
	butterflies = GPUParticles3D.new()
	butterflies.amount = 18
	butterflies.lifetime = 6.0
	butterflies.preprocess = 6.0
	butterflies.local_coords = false
	butterflies.visibility_aabb = AABB(Vector3(-16, -4, -14), Vector3(32, 10, 28))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10, 0.4, 8)
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.2
	pm.turbulence_noise_scale = 2.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.3))
	g.add_point(0.33, Color(0.95, 0.5, 0.75))
	g.add_point(0.66, Color(0.55, 0.7, 1.0))
	g.set_color(g.get_point_count() - 1, Color(1.0, 0.98, 0.95))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_initial_ramp = gt
	butterflies.process_material = pm
	var wing := QuadMesh.new()
	wing.size = Vector2(0.09, 0.07)
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	wm.vertex_color_use_as_albedo = true
	wing.material = wm
	butterflies.draw_pass_1 = wing
	butterflies.position.y = 0.8
	_demo._dress.ambient.add_child(butterflies)


func _free_point(half: float, clearance: float) -> Vector2:
	for i in 80:
		var p := Vector2(_rng.randf_range(-half + 3, half - 3), _rng.randf_range(-half + 3, half - 3))
		if Dressing.water_dist(p) > clearance and Dressing.plaza_dist(p) > clearance and Dressing.cave_dist(p) > clearance and WorldLayout.walkable(p, clearance):
			return p
	return Vector2.ZERO


# ------------------------------------------------------------------ arbustos

func _bushes(half: float) -> void:
	var greens := [Color(0.2, 0.4, 0.2), Color(0.26, 0.48, 0.22), Color(0.17, 0.34, 0.24)]
	var blob := SphereMesh.new()
	blob.radius = 0.5
	blob.height = 0.75
	blob.radial_segments = 7
	blob.rings = 3
	var berry := SphereMesh.new()
	berry.radius = 0.06
	berry.height = 0.12
	berry.radial_segments = 4
	berry.rings = 2
	var lists := [[], [], []]
	var berries: Array = []
	var patches := FastNoiseLite.new()
	patches.seed = 314
	patches.frequency = 0.16
	for i in int(700.0 * half * half / 3600.0):
		var p := Vector2(_rng.randf_range(-half + 1, half - 1), _rng.randf_range(-half + 1, half - 1))
		if WorldLayout.open_dist(p) > -0.5:
			continue
		if patches.get_noise_2d(p.x, p.y) < 0.05:
			continue
		if _demo.path_dist(p) < 2.0 or Dressing.water_dist(p) < 0.8 or Dressing.plaza_dist(p) < 1.0 or Dressing.cave_dist(p) < 1.0:
			continue
		var size := _rng.randf_range(0.6, 1.3)
		for k in _rng.randi_range(2, 3):
			var off := Vector3(_rng.randf_range(-0.35, 0.35), 0.18, _rng.randf_range(-0.35, 0.35)) * size
			var basis := Basis.from_scale(Vector3(size, size * _rng.randf_range(0.8, 1.1), size))
			lists[_rng.randi() % 3].append(Transform3D(basis, Vector3(p.x, 0, p.y) + off))
		if _rng.randf() < 0.22:
			for k in 5:
				var a := _rng.randf() * TAU
				berries.append(Transform3D(Basis(), Vector3(p.x + cos(a) * 0.45 * size, 0.35 * size + _rng.randf() * 0.2, p.y + sin(a) * 0.45 * size)))
	# arbustos da borda dos bosques (planejados junto com as árvores)
	for p: Vector2 in _demo.edge_bushes:
		var size := _rng.randf_range(0.55, 1.0)
		for k in _rng.randi_range(1, 3):
			var off := Vector3(_rng.randf_range(-0.35, 0.35), 0.18, _rng.randf_range(-0.35, 0.35)) * size
			var basis := Basis.from_scale(Vector3(size, size * _rng.randf_range(0.8, 1.1), size))
			lists[_rng.randi() % 3].append(Transform3D(basis, Vector3(p.x, 0, p.y) + off))
	for g in 3:
		_multi(blob, lists[g], _demo._toon_shared(greens[g], 0.015))
	_multi(berry, berries, _demo._toon_shared(Color(0.85, 0.15, 0.25)))


func _multi(mesh: Mesh, xforms: Array, mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	_root.add_child(mmi)


# ------------------------------------------------------------------ coelhos

func _new_rabbit(p: Vector2) -> Dictionary:
	var n := Node3D.new()
	_root.add_child(n)
	var fur: Color = [Color(0.6, 0.45, 0.32), Color(0.88, 0.86, 0.82), Color(0.45, 0.36, 0.3)][_rng.randi() % 3]
	var mat: Material = _demo._toon_shared(fur)
	var body := SphereMesh.new()
	body.radius = 0.13
	body.height = 0.22
	body.radial_segments = 6
	body.rings = 3
	_demo._mesh(body, mat, Vector3(0, 0.11, 0.02), n, Vector3.ZERO, Vector3(1.0, 0.9, 1.3))
	var head := SphereMesh.new()
	head.radius = 0.08
	head.height = 0.16
	head.radial_segments = 6
	head.rings = 3
	_demo._mesh(head, mat, Vector3(0, 0.2, -0.13), n)
	var ear := BoxMesh.new()
	ear.size = Vector3(0.035, 0.14, 0.03)
	for sx: float in [-0.035, 0.035]:
		_demo._mesh(ear, mat, Vector3(sx, 0.32, -0.12), n, Vector3(-12, 0, sx * 300.0))
	var tail := SphereMesh.new()
	tail.radius = 0.045
	tail.height = 0.09
	_demo._mesh(tail, _demo._toon_shared(Color(0.95, 0.94, 0.9)), Vector3(0, 0.14, 0.18), n)
	n.position = Vector3(p.x, 0, p.y)
	n.rotation.y = _rng.randf() * TAU
	return {"node": n, "t": -1.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "wait": _rng.randf_range(0.5, 3.0)}


func _update_rabbit(r: Dictionary, delta: float, player: Vector3) -> void:
	var n: Node3D = r.node
	if float(r.t) >= 0.0:
		r.t = float(r.t) + delta
		var k := minf(float(r.t) / 0.28, 1.0)
		n.position = (r.from as Vector3).lerp(r.to, k) + Vector3(0, sin(PI * k) * 0.28, 0)
		if k >= 1.0:
			r.t = -1.0
		return
	r.wait = float(r.wait) - delta
	var away := Vector2(n.position.x - player.x, n.position.z - player.z)
	var scared := away.length() < 4.0
	if float(r.wait) > 0.0 and not scared:
		return
	var dir := away.normalized() if scared else Vector2.from_angle(_rng.randf() * TAU)
	var dest := Vector2(n.position.x, n.position.z) + dir.rotated(_rng.randf_range(-0.5, 0.5)) * (1.2 if scared else 0.7)
	if Dressing.water_dist(dest) < 0.5:
		r.wait = 0.4
		return
	r.from = n.position
	r.to = Vector3(dest.x, 0, dest.y)
	r.t = 0.0
	r.wait = 0.05 if scared else _rng.randf_range(0.8, 3.5)
	n.rotation.y = atan2(-dir.x, -dir.y)


# ------------------------------------------------------------------ cervos

func _new_deer(p: Vector2) -> Dictionary:
	var n := Node3D.new()
	_root.add_child(n)
	var coat: Material = _demo._toon_shared(Color(0.62, 0.4, 0.24))
	var light: Material = _demo._toon_shared(Color(0.86, 0.76, 0.62))
	var body := CapsuleMesh.new()
	body.radius = 0.2
	body.height = 0.9
	body.radial_segments = 6
	body.rings = 2
	_demo._mesh(body, coat, Vector3(0, 0.7, 0), n, Vector3(90, 0, 0))
	var neck := CylinderMesh.new()
	neck.top_radius = 0.07
	neck.bottom_radius = 0.11
	neck.height = 0.45
	neck.radial_segments = 6
	_demo._mesh(neck, coat, Vector3(0, 0.98, -0.38), n, Vector3(-35, 0, 0))
	var head := BoxMesh.new()
	head.size = Vector3(0.16, 0.16, 0.3)
	_demo._mesh(head, coat, Vector3(0, 1.18, -0.55), n)
	_demo._mesh(head, light, Vector3(0, 1.13, -0.68), n, Vector3.ZERO, Vector3(0.6, 0.5, 0.3))
	var antler := BoxMesh.new()
	antler.size = Vector3(0.03, 0.3, 0.03)
	for sx: float in [-0.07, 0.07]:
		_demo._mesh(antler, light, Vector3(sx, 1.38, -0.5), n, Vector3(0, 0, sx * 250.0))
	var legs: Array = []
	var leg := BoxMesh.new()
	leg.size = Vector3(0.06, 0.55, 0.06)
	for lp: Vector3 in [Vector3(-0.12, 0.3, -0.3), Vector3(0.12, 0.3, -0.3), Vector3(-0.12, 0.3, 0.3), Vector3(0.12, 0.3, 0.3)]:
		legs.append(_demo._mesh(leg, coat, lp, n))
	n.position = Vector3(p.x, 0, p.y)
	return {"node": n, "target": p, "speed": 0.0, "legs": legs, "phase": 0.0, "wait": _rng.randf_range(1.0, 5.0)}


func _update_deer(d: Dictionary, delta: float, player: Vector3, half: float) -> void:
	var n: Node3D = d.node
	var here := Vector2(n.position.x, n.position.z)
	var away := here - Vector2(player.x, player.z)
	var want := 0.0
	if away.length() < 6.0:
		d.target = here + away.normalized() * 6.0
		want = 5.5
	elif here.distance_to(d.target) > 0.3:
		want = 1.0
	else:
		d.wait = float(d.wait) - delta
		if float(d.wait) <= 0.0:
			d.wait = _rng.randf_range(3.0, 8.0)
			d.target = here + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.0, 6.0)
	var tgt: Vector2 = d.target
	tgt = tgt.clamp(Vector2(-half + 3, -half + 3), Vector2(half - 3, half - 3))
	if Dressing.water_dist(tgt) < 1.0:
		d.target = here
		want = 0.0
	d.speed = move_toward(float(d.speed), want, delta * 8.0)
	if float(d.speed) > 0.05:
		var dir := (tgt - here).normalized()
		n.rotation.y = lerp_angle(n.rotation.y, atan2(-dir.x, -dir.y), 1.0 - exp(-delta * 6.0))
		here += Vector2(-sin(n.rotation.y), -cos(n.rotation.y)) * float(d.speed) * delta
		n.position = Vector3(here.x, 0, here.y)
		d.phase = float(d.phase) + delta * float(d.speed) * 5.0
	var legs: Array = d.legs
	for i in legs.size():
		(legs[i] as Node3D).rotation.x = sin(float(d.phase) + (PI if i % 3 == 0 else 0.0)) * 0.5 * clampf(float(d.speed), 0.0, 1.0)


# ------------------------------------------------------------------ fadas, colmeias, cavernas

func _new_fairy(center: Vector3, size: float) -> Dictionary:
	var n := Node3D.new()
	_root.add_child(n)
	var orb := SphereMesh.new()
	orb.radius = 0.06
	orb.height = 0.12
	orb.radial_segments = 4
	orb.rings = 2
	var col := [Color(0.75, 0.55, 1.0), Color(0.5, 0.9, 1.0), Color(1.0, 0.7, 0.95)][_rng.randi() % 3] as Color
	_demo._mesh(orb, _demo._toon(col, col, 4.0), Vector3.ZERO, n)
	var wing := QuadMesh.new()
	wing.size = Vector2(0.12, 0.08)
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = Color(col.r, col.g, col.b, 0.55)
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	wing.material = wm
	for sx: float in [-0.07, 0.07]:
		var w := MeshInstance3D.new()
		w.mesh = wing
		w.position = Vector3(sx, 0.02, 0)
		n.add_child(w)
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 1.6
	l.light_energy = 0.4
	n.add_child(l)
	var trail := GPUParticles3D.new()
	trail.amount = 10
	trail.lifetime = 0.8
	trail.local_coords = false
	trail.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 8, 12))
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, -0.3, 0)
	pm.color_ramp = Dressing._ramp([Color(col.r * 2.5, col.g * 2.5, col.b * 2.5, 1.0), Color(col.r, col.g, col.b, 0.0)])
	trail.process_material = pm
	var dot := QuadMesh.new()
	dot.size = Vector2(0.035, 0.035)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dot.material = sm
	trail.draw_pass_1 = dot
	n.add_child(trail)
	return {"node": n, "light": l, "center": center + Vector3(0, 2.2 * size, 0), "a": _rng.randf_range(0.5, 1.1), "b": _rng.randf_range(0.9, 1.7), "c": _rng.randf_range(0.6, 1.2), "r": 1.4 * size, "p": _rng.randf() * TAU}


func _hive(tree: Vector3, size: float) -> void:
	var h := Node3D.new()
	_root.add_child(h)
	h.position = tree + Vector3(0.55 * size, 2.0 * size, 0.3 * size)
	var honey: Material = _demo._toon_shared(Color(0.86, 0.62, 0.22))
	var dark: Material = _demo._toon_shared(Color(0.55, 0.36, 0.14))
	for k in 4:
		var ring := CylinderMesh.new()
		ring.top_radius = 0.12 + (0.06 if k in [1, 2] else 0.0)
		ring.bottom_radius = 0.14 + (0.06 if k in [1, 2] else 0.0)
		ring.height = 0.1
		ring.radial_segments = 8
		_demo._mesh(ring, honey if k % 2 == 0 else dark, Vector3(0, -k * 0.1, 0), h)
	var hole := SphereMesh.new()
	hole.radius = 0.04
	hole.height = 0.08
	_demo._mesh(hole, _demo._toon_shared(Color(0.12, 0.08, 0.06)), Vector3(0, -0.2, -0.19), h)
	var bees := GPUParticles3D.new()
	bees.amount = 10
	bees.lifetime = 2.0
	bees.preprocess = 2.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 3.0
	pm.turbulence_noise_speed = Vector3(0.5, 0.5, 0.5)
	pm.color = Color(0.95, 0.8, 0.15)
	bees.process_material = pm
	var dot := QuadMesh.new()
	dot.size = Vector2(0.04, 0.04)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	bm.vertex_color_use_as_albedo = true
	dot.material = bm
	bees.draw_pass_1 = dot
	bees.position = Vector3(0, -0.1, 0)
	h.add_child(bees)


func _cave(c: Vector2) -> void:
	var cave := StaticBody3D.new()
	cave.position = Vector3(c.x, 0, c.y)
	_root.add_child(cave)
	var rock: Material = _demo._toon_shared(Color(0.46, 0.44, 0.5))
	var rock_dark: Material = _demo._toon_shared(Color(0.36, 0.34, 0.42))
	# morro de pedra em volta da boca (aberta para o sul, de frente para a câmera)
	for b: Array in [[Vector3(-1.9, 0.6, -0.4), 1.6], [Vector3(1.9, 0.6, -0.4), 1.7], [Vector3(0, 1.6, -1.2), 2.2], [Vector3(-1.2, 1.9, -0.6), 1.2], [Vector3(1.3, 2.0, -0.7), 1.3], [Vector3(-3.2, 0.3, -1.4), 1.3], [Vector3(3.3, 0.3, -1.3), 1.4]]:
		var s := SphereMesh.new()
		s.radius = b[1]
		s.height = float(b[1]) * 1.5
		s.radial_segments = 7
		s.rings = 4
		_demo._mesh(s, rock if _rng.randf() < 0.6 else rock_dark, b[0], cave, Vector3(0, _rng.randf() * 360.0, 0))
		var col := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = float(b[1]) * 0.85
		col.shape = sph
		col.position = b[0]
		cave.add_child(col)
	var mouth := BoxMesh.new()
	mouth.size = Vector3(1.5, 1.5, 0.4)
	_demo._mesh(mouth, _demo._toon_shared(Color(0.05, 0.03, 0.08)), Vector3(0, 0.75, 0.25), cave)
	var shroom: Material = _demo._toon(Color(0.4, 0.95, 1.0), Color(0.3, 0.9, 1.0), 2.5)
	for k in 7:
		var cap := SphereMesh.new()
		cap.radius = _rng.randf_range(0.06, 0.12)
		cap.height = cap.radius
		cap.radial_segments = 6
		cap.rings = 2
		var a := _rng.randf_range(-1.2, 1.2)
		_demo._mesh(cap, shroom, Vector3(sin(a) * 1.3, 0.08, 0.6 + cos(a) * 0.4), cave)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.9, 1.0)
	glow.omni_range = 2.5
	glow.light_energy = 0.8
	glow.position = Vector3(0, 0.5, 0.9)
	cave.add_child(glow)


func update(delta: float, t: float, player: Vector3, half: float, day: float) -> void:
	for r: Dictionary in _rabbits:
		if (r.node as Node3D).position.distance_to(player) < ACTIVE_RADIUS:
			_update_rabbit(r, delta, player)
	for d: Dictionary in _deer:
		if (d.node as Node3D).position.distance_to(player) < ACTIVE_RADIUS:
			_update_deer(d, delta, player, half)
	for f: Dictionary in _fairies:
		var n: Node3D = f.node
		var ph := t + float(f.p)
		n.position = (f.center as Vector3) + Vector3(cos(ph * float(f.a)) * float(f.r), sin(ph * float(f.b)) * 0.6, sin(ph * float(f.c)) * float(f.r))
		(f.light as OmniLight3D).light_energy = lerpf(0.25, 1.1, 1.0 - day) * (0.8 + 0.2 * sin(ph * 7.0))
	if butterflies != null:
		butterflies.amount_ratio = day
