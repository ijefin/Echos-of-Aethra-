extends RefCounted
## Gruta das Raízes, versão natural: salões irregulares ligados por túneis, paredes de
## rocha com musgo e raízes, chão antigo quebrado nas ruínas, cachoeirinhas ao fundo,
## braseiros antigos acesos e áreas escuras entre eles. Coordenadas locais da gruta
## (x, z), com -z = fundo (topo da tela). O lado sul das paredes fica baixo (corte) para
## não esconder o personagem.

## [centro local, raio] dos salões.
const ROOMS := [
	[Vector2(0, 11), 5.5],     # entrada; o patamar de saída fica ao sul
	[Vector2(-5, 2), 7.0],     # Salão das Aranhas
	[Vector2(6, -7), 8.0],     # Ruínas das Tochas
	[Vector2(-10, -9), 4.6],   # Gruta da Cachoeira
	[Vector2(5, -16.5), 4.4],  # Altar do baú
	[Vector2(48, 14), 4.0],    # câmara do túnel
	[Vector2(63, 39), 3.8],    # câmara do túnel
	[Vector2(74, 70), 4.5],    # embaixo da segunda caverna (sudeste do mapa)
]
## [a, b, meia-largura] dos túneis.
const TUNNELS := [
	[Vector2(0, 11), Vector2(-5, 2), 3.0],
	[Vector2(-5, 2), Vector2(6, -7), 3.0],
	[Vector2(-5, 2), Vector2(-10, -9), 2.6],
	[Vector2(6, -7), Vector2(5, -16.5), 2.8],
	# passagem longa por baixo do mapa até a outra caverna (como as caves do Tibia)
	[Vector2(6, -7), Vector2(28, -1), 2.4],
	[Vector2(28, -1), Vector2(48, 14), 2.4],
	[Vector2(48, 14), Vector2(63, 39), 2.3],
	[Vector2(63, 39), Vector2(72, 61), 2.3],
	[Vector2(72, 61), Vector2(74, 70), 2.4],
]
const RUIN_CENTER := Vector2(6, -7)
const RUIN_RADIUS := 7.6
const GRID := 0.85
const BOUNDS := Rect2(-18, -24, 100, 102)
## Braseiros antigos sempre acesos (o resto da gruta fica na penumbra).
const BRAZIERS := [Vector2(-4.2, 9.2), Vector2(4.2, 9.2), Vector2(0.6, -2.8), Vector2(2.2, -19.4), Vector2(7.8, -19.4),
	Vector2(45.5, 12.0), Vector2(65.0, 37.0), Vector2(71.5, 67.5), Vector2(76.5, 67.5)]
## Cachoeirinhas: [x, z, largura] encostadas nas paredes do fundo.
const FALLS := [[-11.2, -12.0, 0.95], [-8.6, -12.4, 0.6], [8.6, -19.3, 0.55]]

var demo: Node
var root: Node3D
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _stone: Callable


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## < 0 dentro da parte andável, com borda irregular por ruído.
func field(p: Vector2) -> float:
	var d := INF
	for r: Array in ROOMS:
		d = minf(d, p.distance_to(r[0]) - float(r[1]))
	for t: Array in TUNNELS:
		d = minf(d, _seg_dist(p, t[0], t[1]) - float(t[2]))
	return d + _noise.get_noise_2d(p.x, p.y) * 0.75


func build(owner_demo: Node, parent: Node3D, stone_material: Callable) -> void:
	demo = owner_demo
	root = parent
	_stone = stone_material
	_noise.seed = 31
	_noise.frequency = 0.17
	_rng.seed = 77
	_floor()
	_walls()
	_ruins()
	_details()
	for b: Vector2 in BRAZIERS:
		_brazier(Vector3(b.x, 0, b.y))
	for f: Array in FALLS:
		_waterfall(Vector3(float(f[0]), 0, float(f[1])), float(f[2]))
	_pool(Vector3(-10.0, 0, -11.0), 2.3)


func _floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = BOUNDS.size + Vector2(6, 6)
	var m := ShaderMaterial.new()
	m.shader = load("res://src/game/shaders/cave_floor.gdshader")
	m.set_shader_parameter("noise_tex", demo._noise)
	m.set_shader_parameter("room_origin", root.position)
	m.set_shader_parameter("ruin_center", RUIN_CENTER)
	m.set_shader_parameter("ruin_radius", RUIN_RADIUS)
	demo._mesh(plane, m, Vector3(BOUNDS.get_center().x, 0, BOUNDS.get_center().y), root)
	var body := StaticBody3D.new()
	body.set_meta("kind", "cave_floor")
	root.add_child(body)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BOUNDS.size.x + 6, 1, BOUNDS.size.y + 6)
	col.shape = box
	col.position = Vector3(BOUNDS.get_center().x, -0.5, BOUNDS.get_center().y)
	body.add_child(col)


func _rock(at: Vector3, scale: Vector3, color: Color) -> MeshInstance3D:
	var mesh: Mesh = demo._forest._crown(_rng.randi_range(0, 7))
	return demo._mesh(mesh, _stone.call(color), at, root, Vector3(_rng.randf_range(-8, 8), _rng.randf() * 360.0, _rng.randf_range(-8, 8)), scale)


## Paredes: anel de colisão na borda; pedras altas no fundo e nos lados, baixas no sul.
func _walls() -> void:
	var walls := StaticBody3D.new()
	walls.set_meta("kind", "rock")
	root.add_child(walls)
	var greys := [Color(0.34, 0.32, 0.36), Color(0.29, 0.27, 0.31), Color(0.38, 0.35, 0.37)]
	var moss := Color(0.28, 0.4, 0.21)
	var x := BOUNDS.position.x
	while x <= BOUNDS.end.x:
		var z := BOUNDS.position.y
		while z <= BOUNDS.end.y:
			var p := Vector2(x, z) + Vector2(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.2, 0.2))
			var f := field(p)
			var gz := field(p + Vector2(0, 0.3)) - field(p - Vector2(0, 0.3))
			# indo para +z o campo cresce = parede ao sul do espaço andável (entre câmera e jogador)
			var south := gz > 0.12
			if f > 0.0 and f < 1.0:
				var c := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 0.8
				cyl.height = 4.0
				c.shape = cyl
				c.position = Vector3(p.x, 2.0, p.y)
				walls.add_child(c)
				var r := _rng.randf_range(0.7, 1.15)
				var col: Color = greys[_rng.randi() % 3]
				if south:
					_rock(Vector3(p.x, 0.2, p.y), Vector3(r, r * 0.42, r), col)
				else:
					_rock(Vector3(p.x, 0.55 * r, p.y), Vector3(r, r * _rng.randf_range(0.8, 1.2), r), col)
					if _rng.randf() < 0.65:
						var top := _rng.randf_range(0.65, 1.0)
						var rk := _rock(Vector3(p.x + _rng.randf_range(-0.3, 0.3), 1.5 + _rng.randf() * 0.9, p.y - 0.25), Vector3(top, top * 0.9, top), col.darkened(0.08))
						if _rng.randf() < 0.3:
							_rock(rk.position + Vector3(0, top * 0.6, 0), Vector3(top * 0.8, 0.22, top * 0.8), moss)
			elif f >= 1.0 and f < 2.8 and not south and _rng.randf() < 0.7:
				var big := _rng.randf_range(1.2, 1.9)
				_rock(Vector3(p.x, big * 0.6 + _rng.randf() * 1.6, p.y), Vector3(big, big, big), greys[1].darkened(0.12))
			z += GRID
		x += GRID


## Ruínas antigas (não é sala construída: são restos dentro da rocha natural).
func _ruins() -> void:
	var stone: Color = Color(0.5, 0.47, 0.43)
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.42
	pillar.bottom_radius = 0.48
	pillar.radial_segments = 7
	for i in 6:
		var a := float(i) / 6.0 * TAU + 0.35
		var p := RUIN_CENTER + Vector2(cos(a), sin(a)) * (RUIN_RADIUS - 1.1)
		if field(p) > -0.6 or _seg_dist(p, RUIN_CENTER, Vector2(5, -16.5)) < 2.2 or _near_torch(p):
			continue
		var h := _rng.randf_range(0.6, 2.6)  # colunas partidas em alturas diferentes
		var col := StaticBody3D.new()
		col.set_meta("kind", "rock")
		col.position = Vector3(p.x, 0, p.y)
		root.add_child(col)
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.5
		cyl.height = h
		shape.shape = cyl
		shape.position.y = h * 0.5
		col.add_child(shape)
		var m := pillar.duplicate() as CylinderMesh
		m.height = h
		demo._mesh(m, _stone.call(stone), Vector3(0, h * 0.5, 0), col)
		demo._mesh(demo._forest._crown(i % 8), _stone.call(stone.darkened(0.1)), Vector3(0, h, 0), col, Vector3(0, i * 40.0, 0), Vector3(0.48, 0.22, 0.48))
		if _rng.randf() < 0.5:
			demo._mesh(demo._forest._crown(1), _stone.call(Color(0.28, 0.4, 0.21)), Vector3(0, h + 0.05, 0), col, Vector3.ZERO, Vector3(0.36, 0.1, 0.36))
	# coluna caída atravessada no chão
	var fallen := CylinderMesh.new()
	fallen.top_radius = 0.38
	fallen.bottom_radius = 0.42
	fallen.height = 3.2
	fallen.radial_segments = 7
	demo._mesh(fallen, _stone.call(stone.darkened(0.05)), Vector3(RUIN_CENTER.x + 2.8, 0.36, RUIN_CENTER.y - 3.4), root, Vector3(0, 35, 90))
	# degraus quebrados do altar
	for k in 3:
		var step := BoxMesh.new()
		step.size = Vector3(4.2 - k * 0.9, 0.18, 1.1 - k * 0.2)
		demo._mesh(step, _stone.call(stone.lightened(0.03 * k)), Vector3(5, 0.09 + k * 0.18, -15.0 - k * 0.55), root, Vector3(0, _rng.randf_range(-4, 4), 0))


func _near_torch(p: Vector2) -> bool:
	for t: Vector3 in [Vector3(0, 0, -9), Vector3(12, 0, -6), Vector3(6, 0, -1.5)]:
		if p.distance_to(Vector2(t.x, t.z)) < 1.8:
			return true
	return false


## Mesmo chão da gruta sobre o patamar (rocha, terra, musgo), sem quadrado liso.
func floor_patch(at: Vector3, size: Vector2) -> void:
	var plane := PlaneMesh.new()
	plane.size = size
	var m := ShaderMaterial.new()
	m.shader = load("res://src/game/shaders/cave_floor.gdshader")
	m.set_shader_parameter("noise_tex", demo._noise)
	m.set_shader_parameter("room_origin", root.position)
	m.set_shader_parameter("ruin_radius", 0.0)
	demo._mesh(plane, m, at, root)


func _details() -> void:
	var wood := Color(0.36, 0.25, 0.17)
	for i in 5200:
		var p := Vector2(_rng.randf_range(BOUNDS.position.x, BOUNDS.end.x), _rng.randf_range(BOUNDS.position.y, BOUNDS.end.y))
		var f := field(p)
		var gz := field(p + Vector2(0, 0.3)) - field(p - Vector2(0, 0.3))
		# raízes penduradas na frente das paredes do fundo
		if f > -0.4 and f < 0.3 and gz < -0.15 and _rng.randf() < 0.18:
			for k in _rng.randi_range(1, 3):
				var root_mesh := CylinderMesh.new()
				root_mesh.top_radius = 0.06
				root_mesh.bottom_radius = 0.02
				root_mesh.height = _rng.randf_range(1.2, 2.4)
				root_mesh.radial_segments = 4
				demo._mesh(root_mesh, _stone.call(wood), Vector3(p.x + k * 0.25, 3.4 - root_mesh.height * 0.5, p.y + 0.4), root, Vector3(_rng.randf_range(-12, 12), 0, _rng.randf_range(-12, 12)))
		# cogumelos que brilham perto das bordas
		elif f > -1.4 and f < -0.4 and _rng.randf() < 0.05:
			var cyan := _rng.randf() < 0.6
			var tint := Color(0.35, 0.9, 1.0) if cyan else Color(0.75, 0.45, 1.0)
			var glow: Material = demo._toon(tint, tint, 2.2)
			for k in _rng.randi_range(2, 4):
				var cap := SphereMesh.new()
				cap.radius = _rng.randf_range(0.06, 0.13)
				cap.height = cap.radius
				cap.radial_segments = 6
				cap.rings = 2
				demo._mesh(cap, glow, Vector3(p.x + _rng.randf_range(-0.3, 0.3), 0.07, p.y + _rng.randf_range(-0.3, 0.3)), root)
		# pedrinhas soltas
		elif f < -0.5 and _rng.randf() < 0.04:
			var s := _rng.randf_range(0.12, 0.3)
			_rock(Vector3(p.x, s * 0.3, p.y), Vector3(s, s * 0.6, s), Color(0.33, 0.31, 0.34))
	# cristais azuis com luz curta (pontos de cor, não iluminação geral)
	for c: Vector2 in [Vector2(-13.0, -7.5), Vector2(-12.0, 3.5), Vector2(13.0, -4.0)]:
		if field(c) > 1.5:
			continue
		var crystal := SphereMesh.new()
		crystal.radius = 0.22
		crystal.height = 0.95
		crystal.radial_segments = 4
		crystal.rings = 2
		var tint := Color(0.3, 0.62, 0.95)
		demo._mesh(crystal, demo._toon(tint, tint, 2.0), Vector3(c.x, 0.5, c.y), root, Vector3(0, 0, 14))
		var l := OmniLight3D.new()
		l.light_color = tint
		l.light_energy = 0.5
		l.omni_range = 3.5
		l.position = Vector3(c.x, 1.0, c.y)
		root.add_child(l)


## Braseiro antigo de pedra, sempre aceso: ilhas de luz quente no escuro.
func _brazier(at: Vector3) -> void:
	var b := StaticBody3D.new()
	b.set_meta("kind", "rock")
	b.position = at
	root.add_child(b)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 1.0
	shape.shape = cyl
	shape.position.y = 0.5
	b.add_child(shape)
	var base := CylinderMesh.new()
	base.top_radius = 0.22
	base.bottom_radius = 0.34
	base.height = 0.7
	base.radial_segments = 6
	demo._mesh(base, _stone.call(Color(0.44, 0.41, 0.38)), Vector3(0, 0.35, 0), b)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.34
	bowl.bottom_radius = 0.18
	bowl.height = 0.2
	bowl.radial_segments = 6
	demo._mesh(bowl, _stone.call(Color(0.22, 0.2, 0.22)), Vector3(0, 0.8, 0), b)
	var flames := GPUParticles3D.new()
	flames.amount = 10
	flames.lifetime = 0.55
	flames.preprocess = 0.6
	flames.local_coords = true
	flames.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.direction = Vector3.UP
	pm.spread = 10
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 1.0, 0)
	pm.color_ramp = demo._ramp([Color(1, 0.6, 0.15), Color(1, 0.23, 0.025, 0.0)])
	flames.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.42)
	quad.material = demo._flame_draw
	flames.draw_pass_1 = quad
	flames.position.y = 0.95
	b.add_child(flames)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.62, 0.3)
	l.light_energy = 1.6
	l.omni_range = 5.0
	l.position.y = 1.3
	b.add_child(l)
	b.set_meta("light", l)


func _waterfall(at: Vector3, width: float) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://src/game/shaders/waterfall.gdshader")
	m.set_shader_parameter("noise_tex", demo._noise)
	m.set_shader_parameter("seed", _rng.randf() * 10.0)
	var q := QuadMesh.new()
	q.size = Vector2(width, 4.2)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at + Vector3(0, 2.1, 0)
	root.add_child(mi)
	# névoa e respingos no pé
	var mist := GPUParticles3D.new()
	mist.amount = 14
	mist.lifetime = 1.4
	mist.preprocess = 1.4
	mist.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(width * 0.5, 0.05, 0.2)
	pm.direction = Vector3.UP
	pm.spread = 35
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, -0.6, 0)
	pm.color = Color(0.82, 0.94, 1.0, 0.7)
	mist.process_material = pm
	var dot := QuadMesh.new()
	dot.size = Vector2(0.07, 0.07)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.material = dm
	mist.draw_pass_1 = dot
	mist.position = at + Vector3(0, 0.1, 0.3)
	root.add_child(mist)


func _pool(at: Vector3, radius: float) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 12
	var wm := ShaderMaterial.new()
	wm.shader = load("res://src/game/shaders/water.gdshader")
	wm.set_shader_parameter("noise_tex", demo._noise)
	wm.set_shader_parameter("foam_width", -1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = wm
	mi.position = at + Vector3(0, 0.03, 0)
	root.add_child(mi)
	for k in 9:
		var a := float(k) / 9.0 * TAU
		var s := _rng.randf_range(0.25, 0.45)
		_rock(at + Vector3(cos(a) * (radius + 0.1), 0.1, sin(a) * (radius + 0.1)), Vector3(s, s * 0.5, s), Color(0.3, 0.33, 0.3))
