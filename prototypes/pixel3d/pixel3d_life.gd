# PROTOTYPE - NOT FOR PRODUCTION
# Vida do lago: vitórias-régias boiando (algumas com flor), peixes nadando sob a água e
# pulando de vez em quando, sapos na margem/nas folhas que saltam na água. Respingo e
# ondinha em toda entrada na água.
extends RefCounted

const Dressing := preload("res://prototypes/pixel3d/pixel3d_dressing.gd")
const PAD_COUNT := 22
const FISH_COUNT := 7
const FROG_COUNT := 5

var _demo: Node
var _root: Node3D
var _rng := RandomNumberGenerator.new()
var _pads: Array = []      # [Node3D, fase]
var _fish: Array = []      # {node, target, speed, jump_t, jump_from, jump_to, next_jump}
var _frogs: Array = []     # {node, state, t, from, to, wait, splash}
var _drop_mat: StandardMaterial3D


func build(root: Node3D, demo: Node) -> void:
	_demo = demo
	_root = root
	_rng.seed = 11
	_drop_mat = StandardMaterial3D.new()
	_drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_drop_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_drop_mat.albedo_color = Color(0.85, 0.97, 1.0)
	_build_pads()
	for i in FISH_COUNT:
		_fish.append(_new_fish())
	for i in FROG_COUNT:
		_frogs.append(_new_frog())


func _lake_point(min_depth: float) -> Vector2:
	for i in 60:
		var p := Dressing.LAKE_C + Vector2(_rng.randf_range(-11, 11), _rng.randf_range(-9, 9))
		if Dressing.lake_dist(p) < -min_depth:
			return p
	return Dressing.LAKE_C


# ------------------------------------------------------------------ vitórias-régias

func _pad_mesh(radius: float) -> ArrayMesh:
	# disco com a fenda clássica (um gomo faltando)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 12
	for i in seg:
		if i == 0:
			continue
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		# ordem anti-horária vista de cima (senão a face de cima é descartada)
		for v: Vector3 in [Vector3.ZERO, Vector3(cos(a0), 0, sin(a0)) * radius, Vector3(cos(a1), 0, sin(a1)) * radius]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


func _build_pads() -> void:
	var greens := [Color(0.24, 0.5, 0.22), Color(0.3, 0.58, 0.24), Color(0.2, 0.42, 0.24)]
	for i in PAD_COUNT:
		var p := _lake_point(0.8)
		var pad := Node3D.new()
		_root.add_child(pad)
		pad.position = Vector3(p.x, Dressing.WATER_Y + 0.015, p.y)
		pad.rotation.y = _rng.randf() * TAU
		var r := _rng.randf_range(0.3, 0.55)
		_demo._mesh(_pad_mesh(r), _demo._toon(greens[i % 3]), Vector3.ZERO, pad)
		if _rng.randf() < 0.35:
			var bloom := SphereMesh.new()
			bloom.radius = 0.11
			bloom.height = 0.14
			bloom.radial_segments = 6
			bloom.rings = 3
			_demo._mesh(bloom, _demo._toon(Color(0.96, 0.62, 0.78)), Vector3(r * 0.3, 0.06, 0), pad)
			var heart := SphereMesh.new()
			heart.radius = 0.04
			heart.height = 0.08
			_demo._mesh(heart, _demo._toon(Color(1.0, 0.9, 0.4)), Vector3(r * 0.3, 0.12, 0), pad)
		_pads.append([pad, _rng.randf() * TAU])


# ------------------------------------------------------------------ peixes

func _new_fish() -> Dictionary:
	var n := Node3D.new()
	_root.add_child(n)
	var koi: Color = [Color(1.0, 0.5, 0.15), Color(0.95, 0.9, 0.85), Color(0.9, 0.3, 0.2)][_rng.randi() % 3]
	var body := SphereMesh.new()
	body.radius = 0.12
	body.height = 0.24
	body.radial_segments = 6
	body.rings = 3
	_demo._mesh(body, _demo._toon(koi), Vector3.ZERO, n, Vector3.ZERO, Vector3(0.7, 0.6, 1.7))
	var tail := BoxMesh.new()
	tail.size = Vector3(0.18, 0.03, 0.12)
	var tail_node := _demo._mesh(tail, _demo._toon(koi * Color(0.85, 0.85, 0.85)), Vector3(0, 0, 0.24), n) as Node3D
	var p := _lake_point(1.2)
	n.position = Vector3(p.x, Dressing.WATER_Y - 0.3, p.y)
	return {"node": n, "tail": tail_node, "target": _lake_point(1.2), "speed": _rng.randf_range(0.6, 1.4),
		"jump_t": -1.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "next_jump": _rng.randf_range(3.0, 9.0), "phase": _rng.randf() * TAU}


func _update_fish(f: Dictionary, delta: float, t: float) -> void:
	var n: Node3D = f.node
	if float(f.jump_t) >= 0.0:
		f.jump_t = float(f.jump_t) + delta
		var k := float(f.jump_t) / 0.75
		var pos: Vector3 = (f.from as Vector3).lerp(f.to, k)
		pos.y = Dressing.WATER_Y - 0.1 + sin(PI * k) * 0.8
		n.look_at(pos + ((f.to as Vector3) - (f.from as Vector3)).normalized() * 0.2 + Vector3(0, cos(PI * k) * 0.3, 0), Vector3.UP)
		n.position = pos
		if k >= 1.0:
			f.jump_t = -1.0
			n.position.y = Dressing.WATER_Y - 0.3
			n.rotation.x = 0.0
			splash(Vector3(pos.x, Dressing.WATER_Y, pos.z))
		return
	var cur := Vector2(n.position.x, n.position.z)
	var tgt: Vector2 = f.target
	if cur.distance_to(tgt) < 0.4:
		f.target = _lake_point(1.2)
	var dir := (tgt - cur).normalized()
	# cabeça no -Z do nó (rabo em +Z): olha e nada para o mesmo lado
	var yaw := atan2(-dir.x, -dir.y)
	n.rotation.y = lerp_angle(n.rotation.y, yaw, 1.0 - exp(-delta * 3.0))
	var fwd := Vector2(-sin(n.rotation.y), -cos(n.rotation.y))
	cur += fwd * float(f.speed) * delta
	n.position = Vector3(cur.x, Dressing.WATER_Y - 0.3 + sin(t * 2.0 + float(f.phase)) * 0.04, cur.y)
	(f.tail as Node3D).rotation.y = sin(t * 9.0 + float(f.phase)) * 0.5
	f.next_jump = float(f.next_jump) - delta
	if float(f.next_jump) <= 0.0:
		f.next_jump = _rng.randf_range(4.0, 10.0)
		var land := cur + fwd * 1.6
		if Dressing.lake_dist(land) < -0.6:
			f.jump_t = 0.0
			f.from = Vector3(cur.x, Dressing.WATER_Y, cur.y)
			f.to = Vector3(land.x, Dressing.WATER_Y, land.y)
			splash(f.from)


# ------------------------------------------------------------------ sapos

func _new_frog() -> Dictionary:
	var n := Node3D.new()
	_root.add_child(n)
	var green := Color(0.42, 0.66, 0.26)
	var body := SphereMesh.new()
	body.radius = 0.12
	body.height = 0.2
	body.radial_segments = 6
	body.rings = 3
	_demo._mesh(body, _demo._toon(green), Vector3(0, 0.08, 0), n, Vector3.ZERO, Vector3(1.0, 0.75, 1.2))
	var eye := SphereMesh.new()
	eye.radius = 0.04
	eye.height = 0.08
	for sx: float in [-0.06, 0.06]:
		_demo._mesh(eye, _demo._toon(Color(0.95, 0.9, 0.6)), Vector3(sx, 0.17, -0.07), n)
	var leg := BoxMesh.new()
	leg.size = Vector3(0.06, 0.04, 0.14)
	for sx: float in [-0.11, 0.11]:
		_demo._mesh(leg, _demo._toon(green * Color(0.8, 0.8, 0.8)), Vector3(sx, 0.03, 0.06), n)
	var f := {"node": n, "state": "sit", "t": 0.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "wait": _rng.randf_range(2.0, 7.0), "into_water": false}
	_place_frog(f)
	return f


func _place_frog(f: Dictionary) -> void:
	var n: Node3D = f.node
	n.visible = true
	if _rng.randf() < 0.5 and not _pads.is_empty():
		var pad: Node3D = _pads[_rng.randi() % _pads.size()][0]
		n.position = pad.position + Vector3(0, 0.01, 0)
	else:
		for i in 60:
			var p := Dressing.LAKE_C + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-10, 10))
			var d := Dressing.lake_dist(p)
			if d > 0.15 and d < 0.6:
				n.position = Vector3(p.x, 0.0, p.y)
				break
	n.rotation.y = _rng.randf() * TAU


func _update_frog(f: Dictionary, delta: float, player: Vector3) -> void:
	var n: Node3D = f.node
	match String(f.state):
		"sit":
			f.wait = float(f.wait) - delta
			var scared := n.visible and Vector2(n.position.x - player.x, n.position.z - player.z).length() < 2.6
			if float(f.wait) <= 0.0 or scared:
				# pula para uma folha ou mergulha
				f.from = n.position
				f.into_water = scared or _rng.randf() < 0.45 or _pads.is_empty()
				var dest: Vector3
				if bool(f.into_water):
					var p := _lake_point(0.6)
					var here := Vector2(n.position.x, n.position.z)
					p = here + (p - here).limit_length(1.8)
					dest = Vector3(p.x, Dressing.WATER_Y, p.y)
				else:
					dest = (_pads[_rng.randi() % _pads.size()][0] as Node3D).position + Vector3(0, 0.01, 0)
					if dest.distance_to(n.position) > 3.0:
						dest = n.position.lerp(dest, 3.0 / dest.distance_to(n.position))
				f.to = dest
				f.t = 0.0
				f.state = "jump"
				n.look_at(Vector3(dest.x, n.position.y, dest.z) + Vector3(0.001, 0, 0), Vector3.UP)
		"jump":
			f.t = float(f.t) + delta
			var k := float(f.t) / 0.5
			var pos := (f.from as Vector3).lerp(f.to, minf(k, 1.0))
			pos.y += sin(PI * minf(k, 1.0)) * 0.6
			n.position = pos
			n.scale = Vector3(0.9, 1.15, 0.9) if k < 0.85 else Vector3(1.1, 0.85, 1.1)
			if k >= 1.0:
				n.scale = Vector3.ONE
				if bool(f.into_water):
					splash(Vector3(pos.x, Dressing.WATER_Y, pos.z))
					n.visible = false
					f.state = "under"
					f.wait = _rng.randf_range(3.0, 7.0)
				else:
					f.state = "sit"
					f.wait = _rng.randf_range(2.0, 6.0)
		"under":
			f.wait = float(f.wait) - delta
			if float(f.wait) <= 0.0:
				_place_frog(f)
				f.state = "sit"
				f.wait = _rng.randf_range(3.0, 8.0)


# ------------------------------------------------------------------ água

## Respingo (gotas) + ondinha que se abre na superfície.
func splash(pos: Vector3) -> void:
	var g := GPUParticles3D.new()
	g.amount = 14
	g.lifetime = 0.5
	g.one_shot = true
	g.explosiveness = 1.0
	g.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, -8.0, 0)
	g.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	q.material = _drop_mat
	g.draw_pass_1 = q
	_root.add_child(g)
	g.global_position = pos + Vector3(0, 0.03, 0)
	g.emitting = true
	_demo.get_tree().create_timer(1.0).timeout.connect(g.queue_free)
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.5
	t.rings = 20
	t.ring_segments = 3
	ring.mesh = t
	var m: ShaderMaterial = _demo._ghost_material(0.8)
	m.set_shader_parameter("color", Color(0.85, 0.97, 1.0))
	m.set_shader_parameter("energy", 0.9)
	m.set_shader_parameter("rim_cut", 2.0)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.02, 0)
	ring.scale = Vector3(0.2, 0.08, 0.2)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(1.4, 0.08, 1.4), 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(a: float) -> void: m.set_shader_parameter("alpha", a), 0.8, 0.0, 0.9)
	tw.chain().tween_callback(ring.queue_free)


func update(delta: float, t: float, player: Vector3) -> void:
	for pd: Array in _pads:
		var pad: Node3D = pd[0]
		pad.position.y = Dressing.WATER_Y + 0.015 + sin(t * 1.2 + float(pd[1])) * 0.012
		pad.rotation.y += sin(t * 0.3 + float(pd[1])) * 0.0008
	for f: Dictionary in _fish:
		_update_fish(f, delta, t)
	for f: Dictionary in _frogs:
		_update_frog(f, delta, player)
