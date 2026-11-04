# PROTOTYPE - NOT FOR PRODUCTION
# Reusable faceted crowns, branching trunks and understory for the visual sandbox.
extends RefCounted

var _crowns: Array[ArrayMesh] = []

func _crown(variant: int) -> ArrayMesh:
	while _crowns.size() <= variant:
		var seed_id := _crowns.size()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 9
		sphere.rings = 4
		var arrays := sphere.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for idx in indices:
			var v := vertices[idx]
			var distortion := 1.0 + 0.09 * sin(v.x * 5.1 + v.y * 3.7 + seed_id) + 0.05 * cos(v.z * 6.3 - v.y * 4.0 + seed_id * 2.0)
			v *= distortion
			v.x += v.y * 0.12 * sin(float(seed_id) + 1.0)
			surface.set_smooth_group(0)
			surface.add_vertex(v)
		surface.generate_normals()
		_crowns.append(surface.commit())
	return _crowns[variant]

func _branch(demo: Node, parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var wood := CylinderMesh.new()
	wood.top_radius = radius * 0.45
	wood.bottom_radius = radius
	wood.height = a.distance_to(b)
	wood.radial_segments = 5
	var mesh: MeshInstance3D = demo._mesh(wood, material, (a + b) * 0.5, parent)
	mesh.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

## Make a legible species silhouette with asymmetric branch-supported clusters.
## `species` força a espécie ("pine", "birch", "broad"); vazio = sorteio de sempre.
func populate(demo: Node, body: Node3D, palette: Array, size: float, rng: RandomNumberGenerator, biome: String, species := "") -> void:
	var pick := rng.randf()
	var pine := biome == "green" and pick < 0.28
	var birch := biome == "green" and pick > 0.76
	if species != "":
		pine = species == "pine"
		birch = species == "birch"
	var bark: Material = demo._toon_shared(Color(0.67, 0.65, 0.57) if birch else Color(0.32, 0.22, 0.17))
	var lean := Vector3(rng.randf_range(-0.18, 0.18), 0, rng.randf_range(-0.15, 0.15)) * size
	var height := (4.4 if pine else (3.7 if birch else 2.8)) * size
	_branch(demo, body, Vector3.ZERO, Vector3(lean.x, height, lean.z), 0.13 * size if birch else 0.21 * size, bark)
	# Spreading roots and visible forks anchor the crown to the ground.
	for i in 3:
		var angle := float(i) * TAU / 3.0 + rng.randf()
		_branch(demo, body, Vector3(0, 0.38 * size, 0), Vector3(cos(angle) * 0.5, 0.035, sin(angle) * 0.5) * size, 0.09 * size, bark)
	if pine:
		for k in 5:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.035
			cone.bottom_radius = (1.18 - k * 0.19) * size
			cone.height = (1.6 - k * 0.12) * size
			cone.radial_segments = 8
			demo._mesh(cone, demo._toon_shared(palette[k % 3], 0.018), Vector3(lean.x + sin(k * 2.0) * 0.12, (1.65 + k * 0.62) * size, lean.z), body, Vector3(4.0 * sin(k), k * 39.0, 5.0 * cos(k)))
	else:
		var count := 4 if birch else 6
		var turn := rng.randf() * TAU
		for k in count:
			var angle := turn + k * 2.4
			var spread := (0.52 if birch else 0.95) * size
			var center := Vector3(cos(angle) * spread, (2.55 + rng.randf_range(-0.2, 0.55) + (k * 0.18 if birch else 0.0)) * size, sin(angle) * spread) + lean
			_branch(demo, body, Vector3(0, 1.45 * size, 0), center, 0.075 * size, bark)
			var radius := rng.randf_range(0.68, 0.96) * size
			var shape := Vector3(radius * (0.8 if birch else 1.15), radius * (1.1 if birch else 0.67), radius)
			demo._mesh(_crown(rng.randi_range(0, 7)), demo._toon_shared(palette[k % 3], 0.018), center, body, Vector3(0, rng.randf() * 360.0, 0), shape)
	if birch:
		var scar := BoxMesh.new()
		scar.size = Vector3(0.22, 0.035, 0.14) * size
		for k in 5:
			demo._mesh(scar, demo._toon_shared(Color(0.23, 0.24, 0.23)), Vector3(0, (0.45 + k * 0.42) * size, -0.09 * size), body, Vector3(0, k * 75.0, 0))
	# Occasional fallen wood and mushrooms belong to tree groups, not open paths.
	if rng.randf() < 0.18:
		_branch(demo, body, Vector3(-0.7, 0.12, 0.4) * size, Vector3(0.55, 0.18, 1.0) * size, 0.13 * size, bark)
	if rng.randf() < 0.35:
		for k in rng.randi_range(2, 4):
			var p := Vector3(rng.randf_range(-0.7, 0.7), 0.12, rng.randf_range(0.3, 0.8)) * size
			var stem := CylinderMesh.new()
			stem.top_radius = 0.025
			stem.bottom_radius = 0.035
			stem.height = 0.2
			demo._mesh(stem, demo._toon_shared(Color(0.73, 0.65, 0.47)), p, body)
			demo._mesh(_crown(0), demo._toon_shared(Color(0.65, 0.29, 0.17)), p + Vector3(0, 0.1, 0), body, Vector3.ZERO, Vector3(0.12, 0.06, 0.12))
