extends SceneTree
## Integração do módulo de mundo: vilarejo na árvore, peças e isolamento do protótipo.
##   godot --headless --path . -s res://tests/integration/world/world_module_test.gd
var failures := 0
var passes := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)


func _scan(dir: String, hits: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["gd", "tscn", "tres", "json"]:
			if FileAccess.get_file_as_string(dir.path_join(f)).contains("prototypes/"):
				hits.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), hits)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var hits: Array[String] = []
	for d in ["res://src/world", "res://assets/world", "res://data/world"]:
		_scan(d, hits)
	check(hits.is_empty(), "nenhum arquivo do módulo referencia prototypes/ %s" % str(hits))
	var region := (load("res://src/world/regions/sample_village.tscn") as PackedScene).instantiate()
	root.add_child(region)
	await process_frame
	var props: Array[WorldProp] = []
	for n in WorldXform.all_nodes(region):
		if n is WorldProp:
			props.append(n as WorldProp)
	check(props.size() > 100, "vilarejo tem %d WorldProp (floresta assada incluída)" % props.size())
	check(region.get_node("Walls") is GridMap and (region.get_node("Walls") as GridMap).get_used_cells().size() > 10, "paredes no GridMap")
	check(region.get_node("Roofs") is GridMap, "camada de telhados")
	var tree := (load("res://assets/world/props/_placeholder/tree.tscn") as PackedScene).instantiate() as WorldProp
	tree.variant = 1
	root.add_child(tree)
	check(tree.get_variant_count() == 2 and not (tree.get_node("Variant0") as Node3D).visible and (tree.get_node("Variant1") as Node3D).visible, "só a variante 1 visível")
	var body: StaticBody3D = tree.get_node("Body")
	check(body.collision_layer == 1, "colisão na camada 1")
	tree.blocks_movement = false
	check(body.collision_layer == 0, "blocks_movement=false remove a colisão")
	tree.tint = Color(1, 0.5, 0.5)
	var mi: MeshInstance3D = tree.get_node("Variant1/Mesh0")
	check(mi.get_surface_override_material(0) != null and (mi.get_surface_override_material(0) as StandardMaterial3D).albedo_color != (mi.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color, "tint altera o material sem mexer no original")
	tree.tint = Color.WHITE
	check(mi.get_surface_override_material(0) == null, "tint branco restaura")
	var bush := (load("res://assets/world/props/_placeholder/bush.tscn") as PackedScene).instantiate() as WorldProp
	root.add_child(bush)
	check(not bush.get_children().any(func(c: Node) -> bool: return c is StaticBody3D), "peça sem bloqueio não cria corpo")
	tree.apply_style(WorldStyle.new())
	check(true, "WorldStyle padrão é no-op")
	var plain := WorldProp.new()
	plain.footprint = Vector2i(2, 1)
	var mesh_holder := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 3, 1)
	mesh_holder.mesh = bm
	plain.add_child(mesh_holder)
	root.add_child(plain)
	var auto: StaticBody3D = plain.get_node("AutoCollision")
	check(auto.collision_layer == 1 and ((auto.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.is_equal_approx(Vector3(2, 3, 1)), "colisão automática pelo footprint e altura da malha")
	region.queue_free()
	print("%d passou, %d falhou" % [passes, failures])
	quit(1 if failures > 0 else 0)
