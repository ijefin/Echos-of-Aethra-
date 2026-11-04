extends SceneTree
## Gera os placeholders e a região de exemplo (determinístico; reexecutável):
##   godot --headless --path . -s res://src/world/tools/build_sample_assets.gd
## 1. Peças placeholder em res://assets/world/props/_placeholder/ (BoxMesh/CylinderMesh)
## 2. Kit de tiles placeholder em res://assets/world/tiles/_placeholder/ + .meshlib
## 3. Região res://src/world/regions/sample_village.tscn
## Quando a arte entregar peças/kits reais, basta trocar as referências (mesmos ids).

const PROPS_DIR: String = "res://assets/world/props/_placeholder"
const KIT_DIR: String = "res://assets/world/tiles/_placeholder"
const KIT_JSON: String = "res://assets/world/tiles/_placeholder/_placeholder.json"
const LIB_PATH: String = "res://assets/world/tiles/_placeholder.meshlib"
const VILLAGE: String = "res://src/world/regions/sample_village.tscn"
const CELL: float = 2.0


func _initialize() -> void:
	_make_props()
	_make_kit()
	_make_village()
	print("BUILD_SAMPLE_ASSETS: OK")
	quit(0)


func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _box(size: Vector3, c: Color) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	m.material = _mat(c)
	return m


func _cyl(top: float, bottom: float, h: float, c: Color) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 8
	m.material = _mat(c)
	return m


func _mesh_node(parent: Node3D, owner_node: Node, mesh: Mesh, pos: Vector3, nm: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	mi.owner = owner_node
	return mi


func _save(root: Node, path: String) -> void:
	var packed: PackedScene = PackedScene.new()
	var err: Error = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	print("%s %s" % ["OK  " if err == OK else "ERRO", path])
	root.free()


## Cria uma peça WorldProp. `parts` = lista de [mesh, pos]; `variant_parts` (opcional) = lista
## de listas para Variant0..N. `col_radius` > 0 cria corpo cilíndrico; `col_box` != ZERO, caixa.
func _prop(file: String, id: String, category: String, footprint: Vector2i, blocks: bool,
		variants: Array, col_radius: float = 0.0, col_box: Vector3 = Vector3.ZERO) -> void:
	var root: WorldProp = WorldProp.new()
	root.name = id.to_pascal_case()
	root.prop_id = StringName(id)
	root.category = StringName(category)
	root.footprint = footprint
	root.blocks_movement = blocks
	for vi: int in variants.size():
		var holder: Node3D = root
		if variants.size() > 1:
			holder = Node3D.new()
			holder.name = "Variant%d" % vi
			root.add_child(holder)
			holder.owner = root
		for pi: int in (variants[vi] as Array).size():
			var part: Array = variants[vi][pi]
			_mesh_node(holder, root, part[0], part[1], "Mesh%d" % pi)
	if blocks and (col_radius > 0.0 or col_box != Vector3.ZERO):
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		root.add_child(body)
		body.owner = root
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "Shape"
		if col_radius > 0.0:
			var sh: CylinderShape3D = CylinderShape3D.new()
			sh.radius = col_radius
			sh.height = 2.0
			cs.shape = sh
			cs.position.y = 1.0
		else:
			var bs: BoxShape3D = BoxShape3D.new()
			bs.size = col_box
			cs.shape = bs
			cs.position.y = col_box.y * 0.5
		body.add_child(cs)
		cs.owner = root
	_save(root, "%s/%s.tscn" % [PROPS_DIR, file])


func _make_props() -> void:
	DirAccess.make_dir_recursive_absolute(PROPS_DIR)
	var brown: Color = Color(0.4, 0.27, 0.15)
	_prop("tree", "tree", "tree", Vector2i.ONE, true, [
		[[_cyl(0.18, 0.25, 1.6, brown), Vector3(0, 0.8, 0)], [_cyl(0.0, 1.2, 2.6, Color(0.18, 0.5, 0.2)), Vector3(0, 2.8, 0)]],
		[[_cyl(0.15, 0.2, 1.2, brown), Vector3(0, 0.6, 0)], [_cyl(0.0, 0.9, 2.0, Color(0.12, 0.4, 0.22)), Vector3(0, 2.2, 0)]],
	], 0.35)
	_prop("rock", "rock", "rock", Vector2i.ONE, true, [
		[[_box(Vector3(1.0, 0.7, 0.9), Color(0.5, 0.5, 0.52)), Vector3(0, 0.35, 0)]],
	], 0.5)
	_prop("bush", "bush", "decor", Vector2i.ONE, false, [
		[[_cyl(0.5, 0.6, 0.6, Color(0.25, 0.55, 0.25)), Vector3(0, 0.3, 0)]],
	])
	_prop("well", "well", "furniture", Vector2i.ONE, true, [
		[[_cyl(0.8, 0.8, 0.8, Color(0.55, 0.55, 0.58)), Vector3(0, 0.4, 0)], [_box(Vector3(1.2, 0.1, 0.1), brown), Vector3(0, 1.6, 0)]],
	], 0.8)
	_prop("crate", "crate", "furniture", Vector2i.ONE, true, [
		[[_box(Vector3(0.8, 0.8, 0.8), Color(0.6, 0.45, 0.25)), Vector3(0, 0.4, 0)]],
	], 0.0, Vector3(0.8, 0.8, 0.8))
	_prop("lamp", "lamp", "decor", Vector2i.ONE, true, [
		[[_cyl(0.08, 0.08, 2.2, Color(0.2, 0.2, 0.22)), Vector3(0, 1.1, 0)], [_box(Vector3(0.3, 0.3, 0.3), Color(1.0, 0.85, 0.4)), Vector3(0, 2.3, 0)]],
	], 0.15)


func _make_kit() -> void:
	DirAccess.make_dir_recursive_absolute(KIT_DIR)
	var pieces: Array = []
	var defs: Array = [
		["grass", Vector3(CELL, 0.2, CELL), Vector3(0, -0.1, 0), Color(0.3, 0.55, 0.28), "none"],
		["road", Vector3(CELL, 0.2, CELL), Vector3(0, -0.1, 0), Color(0.55, 0.42, 0.28), "none"],
		["plaza", Vector3(CELL, 0.2, CELL), Vector3(0, -0.1, 0), Color(0.62, 0.62, 0.6), "none"],
		["floor_wood", Vector3(CELL, 0.2, CELL), Vector3(0, -0.1, 0), Color(0.5, 0.35, 0.2), "none"],
		["wall", Vector3(CELL, 2.0, 0.2), Vector3(0, 1.0, 0), Color(0.82, 0.76, 0.62), "box"],
		["door", Vector3(1.0, 1.8, 0.1), Vector3(0, 0.9, 0), Color(0.35, 0.22, 0.12), "none"],
		["roof", Vector3(CELL + 0.4, 0.3, CELL + 0.4), Vector3(0, 0.15, 0), Color(0.7, 0.25, 0.2), "none"],
	]
	for d: Array in defs:
		var root: Node3D = Node3D.new()
		root.name = String(d[0]).to_pascal_case()
		_mesh_node(root, root, _box(d[1], d[3]), d[2], "Mesh")
		var path: String = "%s/%s.tscn" % [KIT_DIR, d[0]]
		_save(root, path)
		pieces.append({"id": d[0], "scene": path, "collision": d[4]})
	var f: FileAccess = FileAccess.open(KIT_JSON, FileAccess.WRITE)
	f.store_string(JSON.stringify({"kit": "_placeholder", "cell_size": [CELL, CELL, CELL], "scale": 1.0,
		"pieces": pieces}, "\t"))
	f.close()
	print("MeshLibrary: ", error_string(MeshLibraryBuilder.build_and_save(KIT_JSON, LIB_PATH)))


func _make_village() -> void:
	var lib: MeshLibrary = load(LIB_PATH) as MeshLibrary
	var cs: Vector3 = Vector3.ONE * CELL
	var region: WorldRegion = WorldRegion.new()
	region.name = "SampleVillage"
	region.region_id = &"sample_village"
	region.display_name = "Vilarejo de Exemplo"
	region.danger_level = 1
	region.ambience = &"village_day"
	region.bounds = AABB(Vector3(-50, -10, -50), Vector3(100, 40, 100))

	var terrain: MeshInstance3D = MeshInstance3D.new()
	terrain.name = "Terrain"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(110, 110)
	plane.material = _mat(Color(0.2, 0.4, 0.2))
	terrain.mesh = plane
	terrain.position.y = -0.12
	region.add_child(terrain)
	terrain.owner = region

	var layers: Dictionary = {}
	for ln: StringName in [TileRegionBuilder.LAYER_GROUND, TileRegionBuilder.LAYER_WALLS, TileRegionBuilder.LAYER_ROOFS]:
		layers[ln] = TileRegionBuilder.ensure_layer(region, ln, lib, cs)
	var ground: GridMap = layers[TileRegionBuilder.LAYER_GROUND]
	ground.collision_layer = 0
	(layers[TileRegionBuilder.LAYER_ROOFS] as GridMap).collision_layer = 0
	TileRegionBuilder.paint_rect(ground, Rect2i(-15, -15, 30, 30), lib.find_item_by_name("grass"))
	var road: int = lib.find_item_by_name("road")
	TileRegionBuilder.paint_line(ground, Vector2i(0, -15), Vector2i(0, 14), road)
	TileRegionBuilder.paint_line(ground, Vector2i(-1, -15), Vector2i(-1, 14), road)
	TileRegionBuilder.paint_line(ground, Vector2i(0, 0), Vector2i(14, 0), road)
	TileRegionBuilder.paint_rect(ground, Rect2i(-3, -3, 6, 6), lib.find_item_by_name("plaza"))
	TileRegionBuilder.paint_house(layers, lib, Rect2i(-10, -10, 5, 4), TileRegionBuilder.DoorSide.SOUTH)
	TileRegionBuilder.paint_house(layers, lib, Rect2i(5, -9, 4, 5), TileRegionBuilder.DoorSide.WEST)

	var props: Node3D = Node3D.new()
	props.name = "Props"
	region.add_child(props)
	props.owner = region
	_place(props, region, "res://assets/world/props/_placeholder/well.tscn", Vector3(0, 0, 0))
	_place(props, region, "res://assets/world/props/_placeholder/crate.tscn", Vector3(-3.5, 0, 6.0))
	_place(props, region, "res://assets/world/props/_placeholder/crate.tscn", Vector3(-2.2, 0, 6.2))
	_place(props, region, "res://assets/world/props/_placeholder/lamp.tscn", Vector3(-4.5, 0, -4.5))
	_place(props, region, "res://assets/world/props/_placeholder/lamp.tscn", Vector3(4.5, 0, 4.5))

	var markers: Node3D = Node3D.new()
	markers.name = "Markers"
	region.add_child(markers)
	markers.owner = region
	var sp: SpawnPoint = _mk(SpawnPoint.new(), markers, region, "PlayerStart", Vector3(0, 0, 8))
	sp.side = SpawnPoint.Faction.PLAYER
	var npc1: NpcSpot = _mk(NpcSpot.new(), markers, region, "ElderSpot", Vector3(-4, 0, 3))
	npc1.npc_id = &"elder"
	var npc2: NpcSpot = _mk(NpcSpot.new(), markers, region, "MerchantSpot", Vector3(4, 0, -3))
	npc2.npc_id = &"merchant"
	var sec: SecretSpot = _mk(SecretSpot.new(), markers, region, "StashBehindHouse", Vector3(-22, 0, -14))
	sec.secret_id = &"hidden_stash"
	var hunt: HuntArea = _mk(HuntArea.new(), markers, region, "WolfWoods", Vector3(40, 0, -10))
	hunt.hunt_id = &"wolf_woods"
	hunt.radius = 10.0
	hunt.min_level = 1
	hunt.max_level = 5
	for i: int in 2:
		var es: SpawnPoint = _mk(SpawnPoint.new(), markers, region, "WolfSpawn%d" % i,
			Vector3(37 + i * 6, 0, -10 + i * 3))
		es.side = SpawnPoint.Faction.ENEMY
		es.enemy_kind = &"wolf"
		es.level = 2
		es.respawn_s = 25.0
	var lm: Landmark = _mk(Landmark.new(), markers, region, "Plaza", Vector3(0, 0, 0))
	lm.landmark_id = &"village_plaza"
	lm.display_name = "Praça do Vilarejo"
	var qp: QuestPoint = _mk(QuestPoint.new(), markers, region, "ElderHouseDoor", Vector3(-15, 0, -5))
	qp.point_id = &"elder_house_door"

	var trail: Path3D = Path3D.new()
	trail.name = "TrailEast"
	var curve: Curve3D = Curve3D.new()
	curve.add_point(Vector3(28, 0, 0))
	curve.add_point(Vector3(34, 0, -5))
	curve.add_point(Vector3(40, 0, -10))
	trail.curve = curve
	region.add_child(trail)
	trail.owner = region

	var scatter: PropScatter = PropScatter.new()
	scatter.name = "Forest"
	scatter.scatter_seed = 20261104
	scatter.area_size = Vector2(100, 100)
	scatter.min_distance = 4.0
	scatter.noise_threshold = 0.3
	scatter.scenes = [load("res://assets/world/props/_placeholder/tree.tscn"),
		load("res://assets/world/props/_placeholder/rock.tscn"),
		load("res://assets/world/props/_placeholder/bush.tscn")]
	scatter.weights = PackedFloat32Array([6.0, 1.0, 2.0])
	scatter.exclusion_rects = [Rect2(-31, -31, 62, 62)]
	scatter.exclusion_paths = [NodePath("../TrailEast")]
	scatter.trail_half_width = 2.5
	scatter.marker_root = NodePath("../Markers")
	scatter.marker_clear_radius = 5.0
	region.add_child(scatter)
	scatter.owner = region
	print("Floresta assada: ", scatter.bake(region), " peças")
	_save(region, VILLAGE)


func _place(parent: Node3D, owner_node: Node, scene_path: String, pos: Vector3) -> void:
	var inst: Node3D = (load(scene_path) as PackedScene).instantiate() as Node3D
	parent.add_child(inst)
	inst.owner = owner_node
	inst.position = pos
	inst.name = "%s_%d" % [scene_path.get_file().get_basename(), parent.get_child_count()]


func _mk(marker: WorldMarker, parent: Node3D, owner_node: Node, nm: String, pos: Vector3) -> Variant:
	marker.name = nm
	parent.add_child(marker)
	marker.owner = owner_node
	marker.position = pos
	return marker
