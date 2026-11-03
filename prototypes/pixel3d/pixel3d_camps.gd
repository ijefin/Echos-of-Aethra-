# PROTOTYPE - NOT FOR PRODUCTION
# Woodland camps and their trails. The same layout drives ground shaders and placement.
extends RefCounted

const CENTERS := [Vector2(-14, -30), Vector2(18, 16), Vector2(-32, 30)]
const TRAILS := [
	Vector2(-14, -30), Vector2(-10, -26), Vector2(-6, -27), Vector2(-2, -26), Vector2(3, -27),
	Vector2(18, 16), Vector2(15, 12), Vector2(16, 9), Vector2(14, 7), Vector2(14, 5.7),
	Vector2(-32, 30), Vector2(-31, 23), Vector2(-28, 17), Vector2(-29, 10), Vector2(-27, 5.5),
	Vector2(-14, -30), Vector2(-20, -28), Vector2(-25, -30), Vector2(-30, -28), Vector2(-38, -28),
]
const CLEAR_RADIUS := 6.4
var _demo: Node
var _fires: Array[OmniLight3D] = []
var _box := BoxMesh.new()

static func segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0))

## Signed distance to the reserved campsite clearings.
static func clearing_distance(p: Vector2) -> float:
	var result := INF
	for center: Vector2 in CENTERS:
		result = minf(result, p.distance_to(center) - CLEAR_RADIUS)
	return result

## Distance in the same convention as the existing main-road shader.
static func path_distance(p: Vector2) -> float:
	var result := INF
	for camp in CENTERS.size():
		result = minf(result, p.distance_to(CENTERS[camp]) - 2.4)
	for camp in TRAILS.size() / 5:
		for i in 4:
			result = minf(result, segment_distance(p, TRAILS[camp * 5 + i], TRAILS[camp * 5 + i + 1]) + 0.6)
	return result

## Upload the exact CPU layout, avoiding a separate hardcoded GPU path map.
static func configure_terrain(material: ShaderMaterial) -> void:
	material.set_shader_parameter("camp_centers", PackedVector2Array(CENTERS))
	material.set_shader_parameter("woodland_trails", PackedVector2Array(TRAILS))

static func woodland_density(p: Vector2, noise: float) -> float:
	var dense := maxf(1.0 - p.distance_to(Vector2(-30, -38)) / 23.0, 1.0 - p.distance_to(Vector2(32, 34)) / 24.0)
	dense = maxf(dense, 1.0 - p.distance_to(Vector2(-40, 4)) / 20.0)
	return clampf(dense * 1.8 + noise * 0.6, 0.0, 1.0)

func _cube(parent: Node3D, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return _demo._mesh(_box, _demo._toon_shared(color), pos, parent, rot, size)

func _solid(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	body.position = pos

func _pole(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.85
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 7
	var n: MeshInstance3D = _demo._mesh(mesh, _demo._toon_shared(color), (a + b) * 0.5, parent)
	n.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func _tent(parent: Node3D, at: Vector3, yaw: float, color: Color) -> void:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = at
	n.rotation_degrees.y = yaw
	var wood := Color(0.39, 0.27, 0.17)
	# Two sloped canvas panels; the dark entrance remains visibly recessed.
	_cube(n, color, Vector3(-0.68, 0.87, 0), Vector3(0.07, 2.20, 3.0), Vector3(0, 0, -38))
	_cube(n, color.lightened(0.08), Vector3(0.68, 0.87, 0), Vector3(0.07, 2.20, 3.0), Vector3(0, 0, 38))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for z: float in [-1.44, 1.44]:
		var a := Vector3(-1.3, 0.02, z)
		var b := Vector3(1.3, 0.02, z)
		var c := Vector3(0, 1.74, z)
		for v: Vector3 in [a, b, c, c, b, a]:
			st.add_vertex(v)
	st.generate_normals()
	_demo._mesh(st.commit(), _demo._toon_shared(Color(0.12, 0.16, 0.15)), Vector3.ZERO, n)
	_pole(n, Vector3(0, 0, 1.53), Vector3(0, 1.83, 1.53), 0.045, wood)
	_pole(n, Vector3(0, 1.83, -1.55), Vector3(0, 1.83, 1.55), 0.04, wood)
	_cube(n, Color(0.53, 0.41, 0.25), Vector3(0, 0.035, 0.25), Vector3(2.1, 0.06, 2.0))
	for sx: float in [-1.0, 1.0]:
		for z: float in [-1.25, 1.25]:
			_pole(n, Vector3(sx * 0.65, 0.88, z), Vector3(sx * 1.75, 0.08, z + 0.16), 0.013, Color(0.64, 0.57, 0.38))
			_pole(n, Vector3(sx * 1.75, 0.0, z + 0.16), Vector3(sx * 1.75, 0.22, z + 0.16), 0.025, wood)
	_solid(n, Vector3(0, 0.80, 0), Vector3(2.5, 1.6, 2.9))

func _bench(parent: Node3D, at: Vector3, yaw: float) -> void:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = at
	n.rotation_degrees.y = yaw
	_pole(n, Vector3(-1.15, 0.32, 0), Vector3(1.15, 0.32, 0), 0.22, Color(0.39, 0.25, 0.15))
	# Split top and cut ends make it read as a seat rather than discarded wood.
	_cube(n, Color(0.60, 0.43, 0.25), Vector3(0, 0.49, 0), Vector3(2.15, 0.08, 0.37))
	for x: float in [-0.72, 0.72]:
		_pole(n, Vector3(x, 0, 0), Vector3(x, 0.30, 0), 0.14, Color(0.29, 0.20, 0.14))
	_solid(n, Vector3(0, 0.25, 0), Vector3(2.3, 0.5, 0.45))

func _fire(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 83
	var stone := SphereMesh.new()
	stone.radius = 0.17
	stone.height = 0.23
	stone.radial_segments = 6
	stone.rings = 3
	for i in 10:
		var angle := i * TAU / 10.0
		_demo._mesh(stone, _demo._toon_shared(Color(0.36, 0.36, 0.37)), Vector3(cos(angle) * 0.64, 0.11, sin(angle) * 0.64), parent, Vector3(0, rng.randf() * 360, 0))
	for angle: float in [-0.6, 0.7]:
		_pole(parent, Vector3(-cos(angle) * 0.43, 0.13, -sin(angle) * 0.43), Vector3(cos(angle) * 0.43, 0.13, sin(angle) * 0.43), 0.11, Color(0.18, 0.12, 0.09))
	var fire := GPUParticles3D.new()
	fire.amount = 22
	fire.lifetime = 0.85
	fire.preprocess = 1.0
	fire.position.y = 0.20
	fire.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.26
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0, 0.7, 0)
	pm.scale_min = 0.55
	pm.scale_max = 1.1
	pm.scale_curve = _demo._curve([Vector2(0, 0.7), Vector2(0.25, 1.0), Vector2(1, 0.0)])
	pm.color_ramp = _demo._ramp([Color(1.0, 0.55, 0.12), Color(0.95, 0.22, 0.035, 0.8), Color(0.4, 0.07, 0.01, 0)])
	fire.process_material = pm
	var shader := ShaderMaterial.new()
	shader.shader = load("res://prototypes/pixel3d/shaders/flame_particle.gdshader")
	shader.set_shader_parameter("noise_tex", _demo._noise)
	shader.set_shader_parameter("intensity", 2.8)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.46, 0.66)
	quad.material = shader
	fire.draw_pass_1 = quad
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fire)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.22)
	light.omni_range = 6.0
	light.omni_attenuation = 1.3
	light.light_specular = 0.0
	light.light_size = 0.25
	light.position.y = 0.8
	parent.add_child(light)
	_fires.append(light)
	_solid(parent, Vector3(0, 0.18, 0), Vector3(1.25, 0.36, 1.25))
	# Cooking tripod and hanging pot, offset so the flame remains readable.
	for i in 3:
		var angle := i * TAU / 3.0
		_pole(parent, Vector3(cos(angle) * 0.8, 0, sin(angle) * 0.8), Vector3(0.16, 1.85, 0.05), 0.035, Color(0.28, 0.20, 0.14))
	_pole(parent, Vector3(0.16, 1.85, 0.05), Vector3(0.16, 1.13, 0.05), 0.012, Color(0.16, 0.17, 0.18))
	var pot := CylinderMesh.new()
	pot.top_radius = 0.20
	pot.bottom_radius = 0.15
	pot.height = 0.24
	pot.radial_segments = 9
	_demo._mesh(pot, _demo._toon_shared(Color(0.20, 0.21, 0.23)), Vector3(0.16, 1.03, 0.05), parent)

func _decor(parent: Node3D, variant: int) -> void:
	var wood := Color(0.48, 0.33, 0.20)
	for i in 2:
		var p := Vector3(-4.0 + i * 0.66, 0.30, 0.2 + i * 0.14)
		_cube(parent, wood, p, Vector3(0.58, 0.60, 0.58))
		for y: float in [0.10, 0.48]:
			_cube(parent, wood.lightened(0.10), Vector3(p.x, y, p.z - 0.30), Vector3(0.62, 0.07, 0.04))
		_solid(parent, p, Vector3(0.58, 0.6, 0.58))
	for k in 5:
		_pole(parent, Vector3(3.4 + (k % 2) * 0.20, 0.13 + (k / 2) * 0.14, 2.4), Vector3(4.25 + (k % 2) * 0.20, 0.13 + (k / 2) * 0.14, 2.4), 0.08, wood)
	_cube(parent, Color(0.26, 0.35, 0.29), Vector3(-2.0, 0.18, -3.0), Vector3(0.40, 0.36, 0.30))
	_cube(parent, Color(0.55, 0.40, 0.25), Vector3(-2.0, 0.18, -3.16), Vector3(0.08, 0.38, 0.035))
	# Rolled blanket and a small supply table.
	_pole(parent, Vector3(-3.8, 0.13, 1.4), Vector3(-3.0, 0.13, 1.4), 0.17, Color(0.34, 0.42, 0.48))
	_cube(parent, wood, Vector3(3.8, 0.72, 0.3), Vector3(1.3, 0.10, 0.75))
	for x: float in [3.3, 4.3]:
		for z: float in [0.02, 0.58]:
			_cube(parent, wood, Vector3(x, 0.36, z), Vector3(0.08, 0.72, 0.08))
	_solid(parent, Vector3(3.8, 0.38, 0.3), Vector3(1.3, 0.76, 0.75))
	_cube(parent, Color(0.68, 0.64, 0.48), Vector3(3.7, 0.79, 0.3), Vector3(0.5, 0.025, 0.35))
	# A signed entrance and bunting make the camps feel occupied.
	_pole(parent, Vector3(2.5, 0, 4.0), Vector3(2.5, 1.6, 4.0), 0.055, wood)
	_cube(parent, wood.lightened(0.1), Vector3(2.5, 1.35, 4.0), Vector3(0.95, 0.32, 0.07))
	_cube(parent, Color(0.83, 0.73, 0.40), Vector3(2.5, 1.35, 4.045), Vector3(0.42, 0.06, 0.015), Vector3(0, 0, -10))
	for x: float in [-4.8, 4.8]:
		_pole(parent, Vector3(x, 0, -4.5), Vector3(x, 2.7, -4.5), 0.04, wood)
	_pole(parent, Vector3(-4.8, 2.6, -4.5), Vector3(4.8, 2.6, -4.5), 0.012, Color(0.58, 0.53, 0.38))
	for i in 7:
		var x := -3.6 + i * 1.2
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
		for v: Vector3 in [Vector3(x - 0.24, 2.6, -4.5), Vector3(x + 0.24, 2.6, -4.5), Vector3(x, 2.12, -4.5), Vector3(x, 2.12, -4.5), Vector3(x + 0.24, 2.6, -4.5), Vector3(x - 0.24, 2.6, -4.5)]:
			st.add_vertex(v)
		st.generate_normals()
		var color: Color = [Color(0.72, 0.45, 0.18), Color(0.29, 0.46, 0.43), Color(0.62, 0.28, 0.24)][(i + variant) % 3]
		_demo._mesh(st.commit(), _demo._toon(color, Color.BLACK, 0.0, 0.012), Vector3.ZERO, parent)

## Build three camps, each connected to the main road by a reserved dirt trail.
func build(root: Node3D, demo: Node) -> void:
	_demo = demo
	for i in CENTERS.size():
		var camp := Node3D.new()
		camp.name = "WoodlandCamp%d" % (i + 1)
		root.add_child(camp)
		camp.position = Vector3(CENTERS[i].x, 0, CENTERS[i].y)
		var canvas: Color = [Color(0.52, 0.45, 0.27), Color(0.27, 0.43, 0.40), Color(0.52, 0.31, 0.22)][i]
		_tent(camp, Vector3(-2.8, 0, -2.5), -22, canvas)
		_tent(camp, Vector3(3.6, 0, -2.2), -65, canvas.darkened(0.08))
		_bench(camp, Vector3(-1.7, 0, 1.5), -20)
		_bench(camp, Vector3(1.9, 0, 1.0), 65)
		_fire(camp)
		_decor(camp, i)

## Warm firelight remains tied to the hearth and only nearby fires cast shadows.
func update(t: float, night: float, viewer: Vector3) -> void:
	for i in _fires.size():
		var light := _fires[i]
		var near := light.global_position.distance_squared_to(viewer)
		light.visible = near < 28.0 * 28.0
		light.shadow_enabled = near < 16.0 * 16.0
		light.light_energy = lerpf(1.1, 3.2, night) * (1.0 + 0.05 * sin(t * 6.0 + i) + 0.025 * sin(t * 13.0))
