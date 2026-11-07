# Peças do mundo maior: Serra do Vigia (contrafortes, desfiladeiro, cordilheira), marcos
# (Torre de Vigia, Árvore-Mãe, Estátua Afundada, Posto Velho), recantos secretos com
# marco de pedras, enfeites das caçadas (teias do Covil, juncos do Charco, colunas da
# Estrada Velha), árvore seca e a borda do mapa (parede + mata além dela).
extends RefCounted

const WorldLayout := preload("res://src/game/world/world_layout.gd")
const Dressing := preload("res://src/game/pixel3d_dressing.gd")

const ROCK := [Color(0.46, 0.44, 0.5), Color(0.38, 0.36, 0.43), Color(0.53, 0.5, 0.52)]
const MOSS := Color(0.3, 0.4, 0.24)
const SNOW := Color(0.88, 0.9, 0.97)
const STONE := Color(0.56, 0.54, 0.53)
const STONE_DARK := Color(0.42, 0.4, 0.42)
const WOOD := Color(0.5, 0.33, 0.2)
const WOOD_DARK := Color(0.32, 0.2, 0.13)

var demo: Node
var chunks
var rng := RandomNumberGenerator.new()
## Segredos construídos: [{id, position, node}] (para quests/teste).
var secrets: Array = []
var mountain_rocks := 0
var _rock_meshes: Array[ArrayMesh] = []
var _box := BoxMesh.new()


func build(owner_demo: Node, chunk_set) -> void:
	demo = owner_demo
	chunks = chunk_set
	rng.seed = 4242
	_mountains()
	_tower()
	_mother_tree()
	_statue()
	_outpost()
	_old_road_ruins()
	_secrets()
	_lair()
	_reeds()
	_border()


# ------------------------------------------------------------------ ajudantes

func _mat(c: Color, sway := 0.0) -> Material:
	return demo._toon_shared(c, sway)


## Pedra facetada (normais por face) com 8 variações.
func rock_mesh(variant: int) -> ArrayMesh:
	while _rock_meshes.size() <= variant:
		var seed_id := _rock_meshes.size()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 7
		sphere.rings = 4
		var arrays := sphere.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)
		for idx in indices:
			var v := vertices[idx]
			var k := 1.0 + 0.16 * sin(v.x * 4.3 + v.z * 2.9 + seed_id * 1.7) + 0.1 * cos(v.y * 5.1 - v.x * 3.3 + seed_id)
			v *= k
			if v.y < -0.2:
				v.y = -0.2 - (v.y + 0.2) * 0.3  # base achatada: senta no chão
			st.add_vertex(v)
		st.generate_normals()
		_rock_meshes.append(st.commit())
	return _rock_meshes[variant]


func _body(at: Vector3, kind := "rock") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.set_meta("kind", kind)
	chunks.node_at3(at).add_child(b)
	b.position = at
	return b


func _col_box(body: Node3D, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	c.position = pos
	c.rotation_degrees = rot
	body.add_child(c)


func _col_cyl(body: Node3D, pos: Vector3, radius: float, height: float) -> void:
	var c := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	c.shape = s
	c.position = pos
	body.add_child(c)


func _cube(parent: Node3D, pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return demo._mesh(_box, _mat(color), pos, parent, rot, size)


func _cyl(parent: Node3D, pos: Vector3, r_bottom: float, r_top: float, h: float, color: Color, sides := 8, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = r_bottom
	m.top_radius = r_top
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return demo._mesh(m, _mat(color), pos, parent, rot)


func _boulder(parent: Node3D, pos: Vector3, r: float, h: float, color: Color) -> void:
	demo._mesh(rock_mesh(rng.randi_range(0, 7)), _mat(color), pos, parent, Vector3(rng.randf_range(-6, 6), rng.randf() * 360.0, rng.randf_range(-6, 6)), Vector3(r, h, r * rng.randf_range(0.85, 1.15)))


# ------------------------------------------------------------------ serra

## Rocha em tudo que não é aberto ao norte (WorldLayout.open_dist > 0): pedras pequenas
## e coladas na borda (parede sem fresta), blocos grandes e picos no miolo, cordilheira
## nevada ao fundo. Colisão: um corpo por pedaço com um cilindro por pedra de borda.
func _mountains() -> void:
	var buckets := {}
	var bodies := {}
	var z := -112.0
	while z < -50.0:
		var x := -116.0
		while x < 116.0:
			var p := Vector2(x + rng.randf_range(-0.8, 0.8), z + rng.randf_range(-0.8, 0.8))
			x += 1.6
			var d := WorldLayout.open_dist(p)
			if absf(p.x) > 100.0 or p.y < -100.0:
				d = maxf(d, 8.0)  # fora do mapa: maciço
			if d < 0.35:
				continue
			var r := clampf(1.25 + d * 0.32, 1.25, 4.6)
			if _taken(buckets, p, r):
				continue
			var k := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
			if not buckets.has(k):
				buckets[k] = []
			(buckets[k] as Array).append([p, r])
			var deep := p.y < -90.0
			var h := r * rng.randf_range(0.9, 1.5) + (rng.randf_range(2.0, 5.0) if deep else 0.0) + minf(d, 10.0) * 0.18
			var parent: Node3D = chunks.node_at(p)
			var col: Color = ROCK[rng.randi() % ROCK.size()]
			if d < 2.0 and rng.randf() < 0.35:
				col = MOSS.lerp(col, 0.35)
			_boulder(parent, Vector3(p.x, -0.15, p.y), r, h * 0.62, col)
			mountain_rocks += 1
			if d < 7.0:
				var key: Vector2i = chunks.key(p)
				if not bodies.has(key):
					var b := StaticBody3D.new()
					b.set_meta("kind", "rock")
					parent.add_child(b)
					bodies[key] = b
				_col_cyl(bodies[key], Vector3(p.x, 1.5, p.y), r * 0.92 + 0.3, 3.0 + h)
		z += 1.6
	# picos nevados: cordilheira ao fundo e alguns no meio do contraforte
	var px := -112.0
	while px < 112.0:
		var p := Vector2(px + rng.randf_range(-2, 2), rng.randf_range(-104, -95))
		_peak(p, rng.randf_range(5.5, 8.0), rng.randf_range(13.0, 21.0))
		if rng.randf() < 0.6:
			var q := Vector2(px + rng.randf_range(-3, 3), rng.randf_range(-109, -103))
			_peak(q, rng.randf_range(6.0, 9.0), rng.randf_range(17.0, 25.0))
		px += rng.randf_range(7.0, 10.0)
	for i in 70:
		var p := Vector2(rng.randf_range(-100, 100), rng.randf_range(-74, -61))
		if WorldLayout.open_dist(p) > 6.5:
			_peak(p, rng.randf_range(3.5, 5.0), rng.randf_range(6.0, 9.5))
	# cascalho e pedras soltas no pé da serra e no chão do vale
	for i in 260:
		var p := Vector2(rng.randf_range(-98, 98), rng.randf_range(-92, -52))
		var d := WorldLayout.open_dist(p)
		if d > -0.6 or d < -5.0 or WorldLayout.trail_dist(p) < 2.0 or absf(p.x - sin(p.y * 0.18) * 3.0) < 2.0 or WorldLayout.clearing_dist(p) < 0.0:
			continue
		var r := rng.randf_range(0.35, 0.8)
		var b := _body(Vector3(p.x, 0, p.y))
		_col_cyl(b, Vector3(0, 0.4, 0), r * 0.8, 0.8)
		_boulder(b, Vector3(0, -0.05, 0), r, r * 0.8, ROCK[rng.randi() % ROCK.size()])


func _taken(buckets: Dictionary, p: Vector2, r: float) -> bool:
	var k := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for e: Array in buckets.get(k + Vector2i(dx, dz), []):
				var q: Vector2 = e[0]
				var sep := (r + float(e[1])) * 0.6
				if p.distance_squared_to(q) < sep * sep:
					return true
	return false


func _peak(p: Vector2, r: float, h: float) -> void:
	var parent: Node3D = chunks.node_at(p)
	var rot := Vector3(0, rng.randf() * 360.0, 0)
	_cyl(parent, Vector3(p.x, h * 0.5 - 0.5, p.y), r, r * 0.12, h, ROCK[rng.randi() % ROCK.size()], 7, rot)
	if h > 11.0:
		var cap := h * 0.3
		_cyl(parent, Vector3(p.x, h - cap * 0.5 - 0.45, p.y), r * 0.12 + r * 0.88 * 0.3 + 0.08, r * 0.1, cap, SNOW, 7, rot)


# ------------------------------------------------------------------ marcos

## Torre de Vigia: torre de pedra octogonal + mirante de pedra com rampa ao sul.
func _tower() -> void:
	var c := Vector3(-30, 0, -84)
	var b := _body(c, "landmark")
	b.set_meta("landmark", "torre_vigia")
	_col_cyl(b, Vector3(0, 4.5, 0), 2.55, 9.0)
	_cyl(b, Vector3(0, 4.5, 0), 2.6, 2.3, 9.0, STONE, 8)
	for y: float in [3.0, 6.2]:
		_cyl(b, Vector3(0, y, 0), 2.62 - y * 0.03, 2.6 - y * 0.03, 0.22, STONE_DARK, 8)
	_cyl(b, Vector3(0, 9.15, 0), 2.6, 2.6, 0.3, STONE_DARK, 8)
	for k in 8:
		var a := k * TAU / 8.0 + TAU / 16.0
		_cube(b, Vector3(cos(a) * 2.35, 9.6, sin(a) * 2.35), Vector3(0.7, 0.6, 0.5), STONE, Vector3(0, -rad_to_deg(a) + 90.0, 0))
	# porta e seteiras viradas para o sul (câmera)
	_cube(b, Vector3(0, 1.0, 2.45), Vector3(1.1, 2.0, 0.3), Color(0.08, 0.06, 0.1))
	_cube(b, Vector3(0, 2.1, 2.5), Vector3(1.4, 0.2, 0.32), WOOD_DARK)
	for y: float in [4.6, 7.6]:
		_cube(b, Vector3(0, y, 2.36), Vector3(0.22, 0.7, 0.3), Color(0.08, 0.06, 0.1))
	# bandeira no topo
	_cyl(b, Vector3(0, 11.0, 0), 0.05, 0.04, 3.0, WOOD_DARK, 5)
	demo._mesh(_box, demo._toon(Color(0.62, 0.2, 0.18), Color.BLACK, 0.0, 0.05), Vector3(0.55, 12.0, 0), b, Vector3.ZERO, Vector3(1.0, 0.6, 0.04))
	# mirante: base de pedra a leste da torre, topo a 2,4 m, rampa subindo do sul
	var m := _body(Vector3(-25.5, 0, -85.2), "landmark")
	_col_box(m, Vector3(0, 1.2, 0), Vector3(4.0, 2.4, 4.0))
	_cube(m, Vector3(0, 1.2, 0), Vector3(4.0, 2.4, 4.0), STONE_DARK)
	_cube(m, Vector3(0, 2.45, 0), Vector3(4.1, 0.12, 4.1), WOOD)
	# parapeito de madeira (norte, leste e o sul fora da rampa)
	for rail: Array in [[Vector3(0, 3.0, -1.95), Vector3(4.0, 0.1, 0.1)], [Vector3(1.95, 3.0, 0), Vector3(0.1, 0.1, 4.0)],
			[Vector3(1.45, 3.0, 1.95), Vector3(1.1, 0.1, 0.1)], [Vector3(-1.45, 3.0, 1.95), Vector3(1.1, 0.1, 0.1)]]:
		_cube(m, rail[0], rail[1], WOOD)
		var rs: Vector3 = rail[1]
		_col_box(m, Vector3(rail[0].x, 3.0, rail[0].z), Vector3(maxf(rs.x, 0.2), 1.2, maxf(rs.z, 0.2)))
	for post: Vector3 in [Vector3(-1.95, 0, -1.95), Vector3(0, 0, -1.95), Vector3(1.95, 0, -1.95), Vector3(1.95, 0, 0), Vector3(1.95, 0, 1.95), Vector3(0.95, 0, 1.95), Vector3(-0.95, 0, 1.95), Vector3(-1.95, 0, 1.95)]:
		_cube(m, post + Vector3(0, 2.8, 0), Vector3(0.12, 0.7, 0.12), WOOD_DARK)
	# rampa: 3,4 m de corrida para 2,4 m de subida (35°, abaixo do limite de 46° do jogador)
	var run := 3.4
	var rise := 2.4
	var ang := rad_to_deg(atan2(rise, run))
	var length := sqrt(run * run + rise * rise)
	var ramp := _body(Vector3(-25.5, 0, -85.2 + 2.0 + run * 0.5), "landmark")
	_col_box(ramp, Vector3(0, rise * 0.5 - 0.17, 0), Vector3(1.8, 0.3, length), Vector3(ang, 0, 0))
	_cube(ramp, Vector3(0, rise * 0.5 - 0.17, 0), Vector3(1.8, 0.3, length), STONE, Vector3(ang, 0, 0))
	for k in 6:
		var t := (k + 0.5) / 6.0
		_cube(ramp, Vector3(0, rise * (1.0 - t) - 0.02, -run * 0.5 + run * t), Vector3(1.82, 0.06, 0.12), STONE_DARK)
	_cube(ramp, Vector3(0, rise * 0.5 - 0.6, 0.1), Vector3(1.7, rise * 0.8, run * 0.7), STONE_DARK)


## Árvore-Mãe: a maior árvore (modelo do pixel3d_forest em escala 3,2), anel de pedras
## e cogumelos que brilham.
func _mother_tree() -> void:
	var c := Vector3(82, 0, 20)
	var body := _body(c, "tree")
	_col_cyl(body, Vector3(0, 1.5, 0), 1.0, 3.0)
	var palette: Array = demo.CANOPY.violet
	body.set_meta("leaf", palette[0])
	body.set_meta("size", 3.2)
	body.set_meta("landmark", "arvore_mae")
	demo._forest.populate(demo, body, palette, 3.2, rng, "violet", "broad")
	demo._tree_spots.append([c, 3.2, "violet"])
	for k in 9:
		var a := k * TAU / 9.0 + 0.2
		var s := _body(c + Vector3(cos(a) * 6.8, 0, sin(a) * 6.8))
		var h := rng.randf_range(1.1, 1.8)
		_col_cyl(s, Vector3(0, h * 0.5, 0), 0.38, h)
		_cube(s, Vector3(0, h * 0.5, 0), Vector3(0.6, h, 0.45), STONE_DARK, Vector3(rng.randf_range(-6, 6), -rad_to_deg(a), rng.randf_range(-6, 6)))
		_cube(s, Vector3(0, h * 0.62, 0.0), Vector3(0.62, 0.1, 0.47), MOSS, Vector3(0, -rad_to_deg(a), 0))
	var glow: Material = demo._toon(Color(0.45, 0.95, 1.0), Color(0.35, 0.9, 1.0), 2.4)
	var cap := SphereMesh.new()
	cap.radius = 0.11
	cap.height = 0.12
	cap.radial_segments = 6
	cap.rings = 2
	for k in 18:
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.6, 3.2)
		demo._mesh(cap, glow, Vector3(cos(a) * r, 0.07, sin(a) * r), body)


## Estátua Afundada: guardiã encapuzada tombada, meio submersa na poça do charco.
func _statue() -> void:
	var c := Vector3(-30, 0, 82.5)
	var n := Node3D.new()
	chunks.node_at3(c).add_child(n)
	n.position = c + Vector3(0, -1.1, 0)
	n.rotation_degrees = Vector3(-14, 25, 16)
	_cyl(n, Vector3(0, 2.0, 0), 1.0, 0.62, 4.2, STONE, 8)
	_cyl(n, Vector3(0, 4.6, 0), 0.62, 0.12, 1.2, STONE_DARK, 8)    # capuz
	demo._mesh(rock_mesh(3), _mat(Color(0.5, 0.48, 0.47)), Vector3(0, 4.35, 0.18), n, Vector3.ZERO, Vector3(0.42, 0.5, 0.42))
	# braço erguido com espada partida
	_cube(n, Vector3(0.85, 3.6, 0.1), Vector3(0.32, 1.5, 0.32), STONE, Vector3(0, 0, -28))
	_cube(n, Vector3(1.35, 4.7, 0.1), Vector3(0.14, 1.4, 0.06), Color(0.62, 0.62, 0.66), Vector3(0, 0, -10))
	_cube(n, Vector3(1.22, 4.05, 0.1), Vector3(0.6, 0.1, 0.12), STONE_DARK, Vector3(0, 0, -10))
	for k in 5:
		_cube(n, Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(1.0, 3.2), 0.75), Vector3(0.5, 0.25, 0.1), MOSS)
	# pedaços caídos na margem
	for at: Vector3 in [Vector3(-34.5, 0, 77.6), Vector3(-25.0, 0, 77.8), Vector3(-26.5, 0, 76.5)]:
		var b := _body(at)
		var r := rng.randf_range(0.5, 0.8)
		_col_cyl(b, Vector3(0, 0.4, 0), r * 0.8, 0.8)
		_cube(b, Vector3(0, r * 0.4, 0), Vector3(r * 1.3, r * 0.8, r), STONE, Vector3(rng.randf_range(-15, 15), rng.randf() * 360.0, rng.randf_range(-15, 15)))


## Posto Velho: muros partidos, guarita caída, carroça e placa na Estrada Velha.
func _outpost() -> void:
	var c := Vector3(-80, 0, 10)
	# muro em L a oeste da estrada, topo quebrado
	var walls := _body(c, "landmark")
	walls.set_meta("landmark", "posto_velho")
	for i in 7:
		var h: float = [2.2, 1.9, 2.4, 1.2, 0.6, 1.7, 2.1][i]
		var at := Vector3(-11.0 + i * 1.1, h * 0.5, -4.0)
		_cube(walls, at, Vector3(1.12, h, 0.6), STONE if i % 2 == 0 else STONE_DARK)
		_col_box(walls, at, Vector3(1.12, h, 0.6))
	for i in 6:
		var h: float = [2.3, 2.0, 1.4, 2.2, 0.8, 1.6][i]
		var at := Vector3(-11.0, h * 0.5, -3.0 + i * 1.1)
		_cube(walls, at, Vector3(0.6, h, 1.12), STONE_DARK if i % 2 == 0 else STONE)
		_col_box(walls, at, Vector3(0.6, h, 1.12))
	# guarita caída: postes tortos e telhado no chão
	for post: Array in [[Vector3(-7.5, 1.3, 1.0), Vector3(4, 0, -6)], [Vector3(-5.0, 1.1, 1.2), Vector3(-12, 0, 14)], [Vector3(-7.4, 1.2, 3.5), Vector3(10, 0, 3)]]:
		_cube(walls, post[0], Vector3(0.18, 2.5, 0.18), WOOD_DARK, post[1])
		_col_box(walls, Vector3(post[0].x, 1.0, post[0].z), Vector3(0.3, 2.0, 0.3))
	_cube(walls, Vector3(-6.0, 0.35, 2.6), Vector3(2.8, 0.12, 2.2), WOOD, Vector3(18, 20, 8))
	for k in 4:
		_cube(walls, Vector3(-6.4 + k * 0.5, 0.25, 4.2), Vector3(0.14, 0.1, 1.8), WOOD_DARK, Vector3(0, 70 + k * 9, 0))
	# carroça tombada a leste da estrada
	var cart := _body(c + Vector3(5.5, 0, 3.0), "landmark")
	_cube(cart, Vector3(0, 0.75, 0), Vector3(1.4, 0.5, 2.4), WOOD, Vector3(0, 12, 8))
	_col_box(cart, Vector3(0, 0.6, 0), Vector3(1.5, 1.2, 2.4), Vector3(0, 12, 0))
	for wz: float in [-0.8, 0.8]:
		_cyl(cart, Vector3(0.8, 0.45, wz), 0.45, 0.45, 0.12, WOOD_DARK, 10, Vector3(0, 0, 90))
	_cyl(cart, Vector3(-1.3, 0.12, 1.8), 0.45, 0.45, 0.12, WOOD_DARK, 10)  # roda solta
	# placa sem texto (só setas de madeira)
	var signpost := _body(c + Vector3(2.4, 0, -4.2), "landmark")
	_col_cyl(signpost, Vector3(0, 1.0, 0), 0.12, 2.0)
	_cyl(signpost, Vector3(0, 1.1, 0), 0.08, 0.07, 2.2, WOOD_DARK, 6)
	_cube(signpost, Vector3(0.35, 1.8, 0), Vector3(0.9, 0.26, 0.06), WOOD, Vector3(0, 0, 4))
	_cube(signpost, Vector3(-0.3, 1.45, 0), Vector3(0.8, 0.24, 0.06), WOOD, Vector3(0, 35, -6))


## Colunas partidas e lajes tombadas ao longo da Estrada Velha.
func _old_road_ruins() -> void:
	var road: Array = WorldLayout.OLD_ROAD
	for i in road.size() - 1:
		var a: Vector2 = road[i]
		var b: Vector2 = road[i + 1]
		var seg_len := a.distance_to(b)
		var t := rng.randf_range(2.0, 8.0)
		while t < seg_len:
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x) * (3.0 + rng.randf_range(0.0, 1.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
			var p := a + dir * t + side
			t += rng.randf_range(9.0, 15.0)
			if WorldLayout.clearing_dist(p) < 1.0 or Dressing.water_dist(p) < 1.5 or demo.path_dist(p) < 1.6 and WorldLayout.old_road_dist(p) > 2.5:
				continue
			var body := _body(Vector3(p.x, 0, p.y))
			if rng.randf() < 0.6:
				var h := rng.randf_range(0.6, 2.4)
				_col_cyl(body, Vector3(0, h * 0.5, 0), 0.42, h)
				_cyl(body, Vector3(0, h * 0.5, 0), 0.42, 0.4, h, STONE, 8)
				_cyl(body, Vector3(0, 0.12, 0), 0.6, 0.6, 0.24, STONE_DARK, 4, Vector3(0, 45, 0))
				_cube(body, Vector3(0, h * 0.7, 0.36), Vector3(0.3, h * 0.35, 0.1), MOSS)
			else:
				var yaw := rng.randf() * 180.0
				_col_box(body, Vector3(0, 0.3, 0), Vector3(1.8, 0.6, 0.8), Vector3(0, yaw, 0))
				_cyl(body, Vector3(0, 0.36, 0), 0.38, 0.38, 1.9, STONE, 8, Vector3(90, yaw, 0))


# ------------------------------------------------------------------ segredos

## Recanto escondido: anel de pedra com uma fresta (virada para `entrance`), arbustos
## tapando a fresta por fora, e um marco de pedras empilhadas no meio.
func _secrets() -> void:
	for s: Dictionary in WorldLayout.data().secrets:
		var c := WorldLayout.v2(s.position)
		var door := WorldLayout.v2(s.entrance)
		var node := Node3D.new()
		node.name = String(s.id)
		node.set_meta("secret_id", String(s.id))
		chunks.node_at(c).add_child(node)
		node.position = Vector3(c.x, 0, c.y)
		secrets.append({"id": String(s.id), "position": c, "node": node})
		var open_a := (door - c).angle()
		if s.region != "serra":  # na serra a própria rocha faz o anel
			var ring := StaticBody3D.new()
			ring.set_meta("kind", "rock")
			node.add_child(ring)
			for k in range(1, 12):
				var a := open_a + k * TAU / 12.0
				var p := Vector3(cos(a) * 3.5, 0, sin(a) * 3.5)
				var r := rng.randf_range(0.95, 1.25)
				var h := rng.randf_range(1.5, 2.3)
				_col_cyl(ring, p + Vector3(0, 1.0, 0), 1.0, 2.0)
				var col: Color = MOSS.lerp(ROCK[k % 3], 0.4) if s.region == "bosque" else ROCK[k % 3]
				_boulder(ring, p + Vector3(0, -0.1, 0), r, h * 0.62, col)
		# arbustos fora da fresta
		var out := Vector2.from_angle(open_a)
		var across := Vector2(-out.y, out.x)
		for k in 5:
			demo.edge_bushes.append(c + out * rng.randf_range(4.6, 6.2) + across * rng.randf_range(-2.2, 2.2))
		_cairn(node)


func _cairn(parent: Node3D) -> void:
	var y := 0.0
	for k in 5:
		var r := 0.42 - k * 0.07
		var h := 0.16 + rng.randf() * 0.06
		_cyl(parent, Vector3(rng.randf_range(-0.04, 0.04), y + h * 0.5, rng.randf_range(-0.04, 0.04)), r, r * 0.92, h, ROCK[k % 3].lightened(0.08), 6, Vector3(rng.randf_range(-5, 5), rng.randf() * 360.0, rng.randf_range(-5, 5)))
		y += h
	# pedrinha clara no topo e anel de seixos em volta
	_cyl(parent, Vector3(0, y + 0.06, 0), 0.08, 0.05, 0.12, Color(0.85, 0.83, 0.78), 5)
	for k in 7:
		var a := k * TAU / 7.0
		_cyl(parent, Vector3(cos(a) * 0.85, 0.05, sin(a) * 0.85), 0.12, 0.1, 0.1, ROCK[k % 3], 5)


# ------------------------------------------------------------------ caçadas

## Covil do Bosque: teias entre as árvores e ossos no chão.
func _lair() -> void:
	var c := Vector2(80, -28)
	for h: Dictionary in WorldLayout.data().hunts:
		if h.id == "covil_bosque":
			c = WorldLayout.v2(h.center)
	var web_mat := StandardMaterial3D.new()
	web_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	web_mat.albedo_color = Color(0.92, 0.94, 0.98, 0.55)
	web_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	web_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var web := _web_mesh()
	for k in 7:
		var a := k * TAU / 7.0 + rng.randf_range(-0.2, 0.2)
		var p := c + Vector2.from_angle(a) * rng.randf_range(8.5, 10.5)
		var mi: MeshInstance3D = demo._mesh(web, web_mat, Vector3(p.x, rng.randf_range(1.4, 2.2), p.y), chunks.node_at(p), Vector3(rng.randf_range(-10, 10), -rad_to_deg(a) + 90.0, 0), Vector3.ONE * rng.randf_range(0.9, 1.4))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bone := Color(0.86, 0.83, 0.74)
	for k in 9:
		var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 8.0)
		var parent: Node3D = chunks.node_at(p)
		_cyl(parent, Vector3(p.x, 0.06, p.y), 0.05, 0.05, rng.randf_range(0.4, 0.7), bone, 5, Vector3(90, rng.randf() * 180.0, 0))
		if k % 3 == 0:
			demo._mesh(rock_mesh(1), _mat(bone), Vector3(p.x + 0.3, 0.1, p.y), parent, Vector3.ZERO, Vector3(0.16, 0.14, 0.18))


func _web_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.025
	var spokes := 8
	var rings := [0.35, 0.7, 1.05, 1.35]
	for k in spokes:
		var a := k * TAU / spokes
		var d := Vector3(cos(a), sin(a), 0)
		var n := Vector3(-d.y, d.x, 0) * w
		var e := d * 1.5
		for v: Vector3 in [-n, n, e + n, -n, e + n, e - n]:
			st.add_vertex(v)
	for r: float in rings:
		for k in spokes:
			var a0 := k * TAU / spokes
			var a1 := (k + 1) * TAU / spokes
			var p0 := Vector3(cos(a0), sin(a0), 0) * r
			var p1 := Vector3(cos(a1), sin(a1), 0) * r * 0.97
			var up := Vector3(0, 0, 0) + (p0 + p1).normalized() * w
			for v: Vector3 in [p0 - up, p1 - up, p1 + up, p0 - up, p1 + up, p0 + up]:
				st.add_vertex(v)
	return st.commit()


## Juncos em volta das poças e pelo charco (MultiMesh por pedaço).
func _reeds() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var b := Basis(Vector3.UP, i * TAU / 4.0 + 0.3)
		var h := 0.7 + i * 0.16
		var off := b * Vector3(0.05, 0, 0)
		for v: Vector3 in [Vector3(-0.03, 0, 0), Vector3(0.03, 0, 0), Vector3(0.01, h, 0.02)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(b * v + off)
	var mesh := st.commit()
	var groups := {}
	for i in 9000:
		var p := Vector2(rng.randf_range(-99, 99), rng.randf_range(60, 99))
		var pd := Dressing.pool_dist(p)
		var keep := (pd > -0.4 and pd < 1.6) or (pd > 0.0 and rng.randf() < 0.08)
		if not keep or demo.path_dist(p) < 1.6 or WorldLayout.clearing_dist(p) < -1.0 and pd > 1.6:
			continue
		var k: Vector2i = chunks.key(p)
		if not groups.has(k):
			groups[k] = []
		(groups[k] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), Vector3(p.x, 0, p.y)))
	var mat: Material = _mat(Color(0.45, 0.47, 0.24), 0.03)
	for k: Vector2i in groups:
		var arr: Array = groups[k]
		var first: Transform3D = arr[0]
		_multimesh(chunks.node_at(Vector2(first.origin.x, first.origin.z)), mesh, mat, arr)


func _multimesh(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


# ------------------------------------------------------------------ árvore seca

## Árvore seca do charco: tronco cinza torto e galhos nus bifurcados (sem copa).
func dead_tree(body: Node3D, size: float, r: RandomNumberGenerator) -> void:
	var bark: Material = _mat(Color(0.4, 0.36, 0.33))
	var lean := Vector3(r.randf_range(-0.35, 0.35), 0, r.randf_range(-0.3, 0.3)) * size
	var top := Vector3(lean.x, 3.1 * size, lean.z)
	_limb(body, Vector3.ZERO, top, 0.2 * size, bark)
	for i in 3:
		var a := float(i) * TAU / 3.0 + r.randf()
		_limb(body, Vector3(0, 0.3 * size, 0), Vector3(cos(a) * 0.55, 0.03, sin(a) * 0.55) * size, 0.08 * size, bark)
	for k in r.randi_range(3, 5):
		var a := r.randf() * TAU
		var from := Vector3.ZERO.lerp(top, r.randf_range(0.45, 0.9))
		var to := from + Vector3(cos(a) * 1.1, r.randf_range(0.5, 1.1), sin(a) * 1.1) * size
		_limb(body, from, to, 0.07 * size, bark)
		var twig := to + Vector3(cos(a + 0.9) * 0.5, 0.45, sin(a + 0.9) * 0.5) * size
		_limb(body, to, twig, 0.035 * size, bark)
		if r.randf() < 0.5:
			# barba de musgo pendurada
			demo._mesh(_box, _mat(Color(0.42, 0.46, 0.34), 0.03), to + Vector3(0, -0.3, 0) * size, body, Vector3.ZERO, Vector3(0.06, 0.55, 0.06) * size)


func _limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var wood := CylinderMesh.new()
	wood.top_radius = radius * 0.5
	wood.bottom_radius = radius
	wood.height = a.distance_to(b)
	wood.radial_segments = 5
	wood.rings = 1
	var mesh: MeshInstance3D = demo._mesh(wood, material, (a + b) * 0.5, parent)
	mesh.quaternion = Quaternion(Vector3.UP, (b - a).normalized())


# ------------------------------------------------------------------ borda

## Parede invisível em volta do mapa + mata cerrada (só copas, MultiMesh) além dela.
func _border() -> void:
	var walls := StaticBody3D.new()
	walls.set_meta("kind", "rock")
	demo._world_root.add_child(walls)
	var e := WorldLayout.HALF + 0.5
	for w: Array in [[Vector3(e, 2, 0), Vector3(1, 6, e * 2 + 2)], [Vector3(-e, 2, 0), Vector3(1, 6, e * 2 + 2)],
			[Vector3(0, 2, e), Vector3(e * 2 + 2, 6, 1)], [Vector3(0, 2, -e), Vector3(e * 2 + 2, 6, 1)]]:
		_col_box(walls, w[0], w[1])
	var crown: Mesh = demo._forest._crown(2)
	var greens := [Color(0.13, 0.3, 0.19), Color(0.18, 0.38, 0.2), Color(0.11, 0.26, 0.2)]
	var groups := {}
	var trunks := {}
	for i in 5200:
		var p := Vector2(rng.randf_range(-118, 118), rng.randf_range(-60, 118))
		if absf(p.x) < 99.0 and p.y < 99.0:
			continue
		var s := rng.randf_range(1.2, 2.1)
		var k: Vector2i = chunks.key(p)
		var g := rng.randi() % 3
		var key := Vector3i(k.x, k.y, g)
		if not groups.has(key):
			groups[key] = []
			trunks[k] = []
		(groups[key] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 1.1, s * 0.75, s)), Vector3(p.x, 2.2 + s * 0.8, p.y)))
		if not trunks.has(k):
			trunks[k] = []
		if rng.randf() < 0.3:
			(trunks[k] as Array).append(Transform3D(Basis().scaled(Vector3(0.22, 2.6, 0.22)), Vector3(p.x, 1.3, p.y)))
	for key: Vector3i in groups:
		var arr: Array = groups[key]
		var first: Transform3D = arr[0]
		var mmi := _multimesh(chunks.node_at(Vector2(first.origin.x, first.origin.z)), crown, _mat(greens[key.z], 0.012), arr)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.6
	trunk_mesh.bottom_radius = 1.0
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 5
	for k: Vector2i in trunks:
		var arr: Array = trunks[k]
		if arr.is_empty():
			continue
		var first: Transform3D = arr[0]
		_multimesh(chunks.node_at(Vector2(first.origin.x, first.origin.z)), trunk_mesh, _mat(Color(0.3, 0.21, 0.16)), arr)
