# PROTOTYPE - NOT FOR PRODUCTION
# Cenário vivo do protótipo pixel3d: lago e rio (com bacia no chão), ponte, praça com
# fonte, lampiões piscando e vida no ar (vagalumes, folhas). As fórmulas de água/praça
# repetem shaders/terrain.gdshaderinc.
extends RefCounted

const SH := "res://prototypes/pixel3d/shaders/"
const LAKE_C := Vector2(-15.0, 13.0)
const LAKE_R := 6.5
const PLAZA_C := Vector2(2.2, 4.7)
const PLAZA_R := 3.4
const RIVER_HALF := 1.8
const BRIDGE_X := -1.3
const WATER_Y := -0.18
## Bocas de caverna (entradas viradas para o sul).
const CAVES := [Vector2(-38.0, -32.0), Vector2(36.0, 30.0)]
const WATER_LAYER := 4  # camada de colisão das margens: bloqueia jogador, não projéteis

var lamps: Array[OmniLight3D] = []
var ambient: Node3D
var fireflies: GPUParticles3D


static func river_center(x: float) -> float:
	return sin(x * 0.11) * 4.0 - 15.0


## Lago orgânico (mesma fórmula de shaders/terrain.gdshaderinc).
static func lake_dist(p: Vector2) -> float:
	var d := (p - LAKE_C) * Vector2(0.78, 1.12)
	var a := atan2(d.y, d.x)
	var r := LAKE_R * (1.0 + 0.22 * sin(2.0 * a + 0.6) + 0.14 * sin(3.0 * a + 2.1) + 0.08 * sin(5.0 * a + 0.4))
	return d.length() - r


## < 0 dentro d'água (lago ou rio).
static func water_dist(p: Vector2) -> float:
	var lake := lake_dist(p)
	var river := absf(p.y - river_center(p.x)) - RIVER_HALF
	return minf(lake, river)


static func cave_dist(p: Vector2) -> float:
	var d := INF
	for c: Vector2 in CAVES:
		d = minf(d, p.distance_to(c) - 4.5)
	return d


static func plaza_dist(p: Vector2) -> float:
	return p.distance_to(PLAZA_C) - PLAZA_R


func build(root: Node3D, demo: Node, noise: Texture2D) -> void:
	_water(root, noise)
	_bridge(root, demo)
	_fountain(root, demo, noise)
	_lamps(root, demo)
	_ambient(root)


# ------------------------------------------------------------------ água

func _water_mat(noise: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SH + "water.gdshader")
	m.set_shader_parameter("noise_tex", noise)
	return m


func _water(root: Node3D, noise: Texture2D) -> void:
	var lake := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(LAKE_R * 1.45 / 0.78, LAKE_R * 1.45 / 1.12) * 2.0 + Vector2(3, 3)
	lake.mesh = plane
	lake.material_override = _water_mat(noise)
	lake.position = Vector3(LAKE_C.x, WATER_Y, LAKE_C.y)
	root.add_child(lake)
	# margem que bloqueia: cilindros cobrindo o interior do contorno orgânico
	var lake_body := StaticBody3D.new()
	lake_body.collision_layer = WATER_LAYER
	root.add_child(lake_body)
	var gx := -14.0
	while gx <= 14.0:
		var gz := -14.0
		while gz <= 14.0:
			var p := LAKE_C + Vector2(gx, gz)
			if lake_dist(p) < -0.9:
				var lc := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 0.95
				cyl.height = 2.0
				lc.shape = cyl
				lc.position = Vector3(p.x, 0, p.y)
				lake_body.add_child(lc)
			gz += 1.2
		gx += 1.2

	# rio: fita ao longo da curva, UV.y = distância (correnteza segue o leito)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_v := 0.0
	var dist := 0.0
	var x := -70.0
	var first := true
	while x <= 70.0:
		var c := Vector3(x, WATER_Y, river_center(x))
		var tangent := Vector3(1.0, 0.0, cos(x * 0.11) * 0.44).normalized()
		var side := Vector3(-tangent.z, 0.0, tangent.x) * (RIVER_HALF + 0.8)
		var l := c - side
		var r := c + side
		if not first:
			dist += 0.5 * sqrt(1.0 + pow(cos(x * 0.11) * 0.44, 2))
			var v := dist / 4.0
			for vert: Array in [[prev_l, 0.0, prev_v], [r, 1.0, v], [prev_r, 1.0, prev_v], [prev_l, 0.0, prev_v], [l, 0.0, v], [r, 1.0, v]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(vert[1], vert[2]))
				st.add_vertex(vert[0])
			prev_v = v
		prev_l = l
		prev_r = r
		first = false
		x += 0.5
	var river := MeshInstance3D.new()
	river.mesh = st.commit()
	var rm := _water_mat(noise)
	rm.set_shader_parameter("use_uv", true)
	rm.set_shader_parameter("flow_speed", 0.35)
	river.material_override = rm
	root.add_child(river)
	# margens bloqueiam, menos na ponte
	var river_body := StaticBody3D.new()
	river_body.collision_layer = WATER_LAYER
	root.add_child(river_body)
	for xi in range(-70, 71):
		if absf(xi - BRIDGE_X) < 1.6:
			continue
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 2.0, RIVER_HALF * 2.0 - 0.6)
		col.shape = box
		col.position = Vector3(xi, 0.0, river_center(xi))
		col.rotation.y = -atan(cos(xi * 0.11) * 0.44)
		river_body.add_child(col)


func _bridge(root: Node3D, demo: Node) -> void:
	var z := river_center(BRIDGE_X)
	var b := Node3D.new()
	b.position = Vector3(BRIDGE_X, 0, z)
	b.rotation.y = -atan(cos(BRIDGE_X * 0.11) * 0.44)
	root.add_child(b)
	var wood: Material = demo._toon(Color(0.5, 0.33, 0.2))
	var dark: Material = demo._toon(Color(0.32, 0.2, 0.13))
	for i in 11:
		var plank := BoxMesh.new()
		plank.size = Vector3(1.9, 0.1, 0.42)
		demo._mesh(plank, wood if i % 2 == 0 else dark, Vector3(0, 0.08 + sin(i / 10.0 * PI) * 0.18, -2.5 + i * 0.5), b)
	for sx: float in [-1.0, 1.0]:
		var rail := BoxMesh.new()
		rail.size = Vector3(0.08, 0.08, 5.4)
		demo._mesh(rail, dark, Vector3(0.95 * sx, 0.7, 0), b)
		for k in 4:
			var post := BoxMesh.new()
			post.size = Vector3(0.1, 0.7, 0.1)
			demo._mesh(post, dark, Vector3(0.95 * sx, 0.35, -2.4 + k * 1.6), b)


# ------------------------------------------------------------------ praça

func _fountain(root: Node3D, demo: Node, noise: Texture2D) -> void:
	var f := StaticBody3D.new()
	f.position = Vector3(PLAZA_C.x, 0, PLAZA_C.y)
	root.add_child(f)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.3
	cyl.height = 1.0
	col.shape = cyl
	f.add_child(col)
	var stone: Material = demo._toon(Color(0.62, 0.6, 0.62))
	var stone_dark: Material = demo._toon(Color(0.45, 0.43, 0.48))
	var basin := CylinderMesh.new()
	basin.top_radius = 1.25
	basin.bottom_radius = 1.32
	basin.height = 0.5
	basin.radial_segments = 14
	demo._mesh(basin, stone, Vector3(0, 0.25, 0), f)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.05
	disc.bottom_radius = 1.05
	disc.height = 0.02
	disc.radial_segments = 14
	var wm := _water_mat(noise)
	wm.set_shader_parameter("foam_width", -1.0)
	var water := MeshInstance3D.new()
	water.mesh = disc
	water.material_override = wm
	water.position = Vector3(0, 0.52, 0)
	f.add_child(water)
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.14
	pillar.bottom_radius = 0.2
	pillar.height = 1.1
	pillar.radial_segments = 8
	demo._mesh(pillar, stone_dark, Vector3(0, 1.05, 0), f)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.55
	bowl.bottom_radius = 0.28
	bowl.height = 0.18
	bowl.radial_segments = 12
	demo._mesh(bowl, stone, Vector3(0, 1.62, 0), f)
	# jato: gotas sobem do topo e caem na bacia
	var jet := GPUParticles3D.new()
	jet.amount = 90
	jet.lifetime = 0.95
	jet.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08
	pm.direction = Vector3.UP
	pm.spread = 28.0
	pm.initial_velocity_min = 1.7
	pm.initial_velocity_max = 2.3
	pm.gravity = Vector3(0, -7.5, 0)
	jet.process_material = pm
	var drop := QuadMesh.new()
	drop.size = Vector2(0.06, 0.06)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.albedo_color = Color(0.78, 0.94, 1.0)
	drop.material = dm
	jet.draw_pass_1 = drop
	jet.position = Vector3(0, 1.75, 0)
	jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(jet)


func _lamp(root: Node3D, demo: Node, pos: Vector2) -> void:
	var l := StaticBody3D.new()
	l.position = Vector3(pos.x, 0, pos.y)
	root.add_child(l)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.12
	cyl.height = 1.8
	col.shape = cyl
	col.position.y = 0.9
	l.add_child(col)
	var iron: Material = demo._toon(Color(0.16, 0.14, 0.18))
	var post := CylinderMesh.new()
	post.top_radius = 0.04
	post.bottom_radius = 0.07
	post.height = 1.7
	post.radial_segments = 6
	demo._mesh(post, iron, Vector3(0, 0.85, 0), l)
	var cap := BoxMesh.new()
	cap.size = Vector3(0.38, 0.07, 0.38)
	demo._mesh(cap, iron, Vector3(0, 2.10, 0), l)
	demo._mesh(cap, iron, Vector3(0, 1.66, 0), l)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.04
	roof.bottom_radius = 0.29
	roof.height = 0.17
	roof.radial_segments = 4
	demo._mesh(roof, iron, Vector3(0, 2.21, 0), l, Vector3(0, 45, 0))
	var bar := BoxMesh.new()
	bar.size = Vector3(0.035, 0.4, 0.035)
	for x: float in [-0.15, 0.15]:
		for z: float in [-0.15, 0.15]:
			demo._mesh(bar, iron, Vector3(x, 1.88, z), l)
	var lantern := BoxMesh.new()
	lantern.size = Vector3(0.17, 0.29, 0.17)
	var core: MeshInstance3D = demo._mesh(lantern, demo._toon(Color(1.0, 0.85, 0.58), Color(1.0, 0.64, 0.25), 5.0), Vector3(0, 1.88, 0), l)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.77, 0.48)
	light.omni_range = 5.8
	light.omni_attenuation = 1.25
	light.light_specular = 0.0
	light.light_size = 0.16
	light.light_energy = 2.4
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	light.position = Vector3(0, 1.88, 0)
	l.add_child(light)
	lamps.append(light)


func _lamps(root: Node3D, demo: Node) -> void:
	for k in 4:
		var a := PI / 4.0 + k * PI / 2.0
		_lamp(root, demo, PLAZA_C + Vector2(cos(a), sin(a)) * (PLAZA_R + 0.5))
	for z: float in [-24.0, -9.0, 14.0, 22.0]:
		_lamp(root, demo, Vector2(sin(z * 0.18) * 3.0 + 1.9, z))
	for x: float in [-20.0, 13.0, 24.0]:
		_lamp(root, demo, Vector2(x, sin(x * 0.15) * 2.0 + 4.0 + 1.9))


## Pisca das chamas dos lampiões (chamar a cada frame); à noite acendem forte.
func flicker(t: float, night := 0.0, player := Vector3.ZERO) -> void:
	var base := lerpf(0.18, 2.4, night)
	# Only two nearby lanterns cast shadows, keeping the cost bounded.
	var nearest := lamps.duplicate()
	nearest.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool: return a.global_position.distance_squared_to(player) < b.global_position.distance_squared_to(player))
	for i in lamps.size():
		lamps[i].light_energy = base * (1.0 + 0.035 * sin(t * 3.0 + i * 1.7) + 0.015 * sin(t * 7.0 + i))
		lamps[i].shadow_enabled = night > 0.2 and nearest.find(lamps[i]) < 2 and lamps[i].global_position.distance_squared_to(player) < 225.0
	if fireflies != null:
		fireflies.amount_ratio = 0.15 + 0.85 * night


# ------------------------------------------------------------------ vida no ar

func _ambient(root: Node3D) -> void:
	ambient = Node3D.new()
	root.add_child(ambient)
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fire.vertex_color_use_as_albedo = true
	fire.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var dot := QuadMesh.new()
	dot.size = Vector2(0.06, 0.06)
	dot.material = fire
	var flies := _ambient_particles(46, 5.0, dot, Vector3(10, 1.0, 8), 0.9)
	fireflies = flies
	var fpm: ParticleProcessMaterial = flies.process_material
	fpm.turbulence_enabled = true
	fpm.turbulence_noise_strength = 1.4
	fpm.turbulence_noise_scale = 3.0
	fpm.gravity = Vector3.ZERO
	fpm.color_ramp = _ramp([Color(0.9, 1.6, 0.4, 0.0), Color(1.3, 2.0, 0.5, 1.0), Color(0.9, 1.6, 0.4, 0.0)])
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	leaf_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	leaf_mat.vertex_color_use_as_albedo = true
	leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.09, 0.06)
	leaf.material = leaf_mat
	var leaves := _ambient_particles(26, 7.0, leaf, Vector3(11, 0.5, 9), 4.5)
	var lpm: ParticleProcessMaterial = leaves.process_material
	lpm.gravity = Vector3(0.25, -0.55, 0.15)
	lpm.turbulence_enabled = true
	lpm.turbulence_noise_strength = 0.8
	lpm.color_ramp = _ramp([Color(0.55, 0.6, 0.2, 0.0), Color(0.78, 0.55, 0.2, 1.0), Color(0.6, 0.4, 0.15, 0.0)])


func _ambient_particles(amount: int, life: float, quad: QuadMesh, extents: Vector3, y: float) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.amount = amount
	g.lifetime = life
	g.preprocess = life
	g.local_coords = false
	g.visibility_aabb = AABB(Vector3(-16, -4, -14), Vector3(32, 10, 28))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.2
	g.process_material = pm
	g.draw_pass_1 = quad
	g.position.y = y
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ambient.add_child(g)
	return g


static func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, colors[0])
	g.set_color(1, colors[colors.size() - 1])
	for i in range(1, colors.size() - 1):
		g.add_point(float(i) / (colors.size() - 1), colors[i])
	var t := GradientTexture1D.new()
	t.gradient = g
	t.use_hdr = true
	return t
