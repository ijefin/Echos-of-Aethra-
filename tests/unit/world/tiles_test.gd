extends SceneTree
## MeshLibrary gerada do kit placeholder + TileGrid/OccupancyGrid.
##   godot --headless --path . -s res://tests/unit/world/tiles_test.gd
var failures := 0
var passes := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	var kit := "res://assets/world/tiles/_placeholder/_placeholder.json"
	var spec: Dictionary = JsonData.load_dict(kit)
	var n: int = (spec["pieces"] as Array).size()
	check(MeshLibraryBuilder.find_kits().has(kit), "find_kits encontra o kit")
	var lib: MeshLibrary = MeshLibraryBuilder.build(kit)
	check(lib != null and lib.get_item_list().size() == n and n == 7, "MeshLibrary com %d itens" % n)
	var wall: int = lib.find_item_by_name("wall")
	var grass: int = lib.find_item_by_name("grass")
	check(wall >= 0 and lib.get_item_shapes(wall).size() == 2, "parede tem colisão (forma + transformação)")
	check(grass >= 0 and lib.get_item_shapes(grass).is_empty(), "chão sem colisão")
	check(lib.get_item_mesh(wall) != null and lib.get_item_mesh(wall).get_aabb().size.is_equal_approx(Vector3(2, 2, 0.2)), "malha da parede 2x2x0.2")
	var out := "user://test_kit.meshlib"
	check(MeshLibraryBuilder.build_and_save(kit, out) == OK, "build_and_save grava")
	var back: MeshLibrary = load(out) as MeshLibrary
	check(back != null and back.get_item_list().size() == n, "meshlib gravada recarrega com %d itens" % n)
	var shipped := load("res://assets/world/tiles/_placeholder.meshlib") as MeshLibrary
	check(shipped != null and shipped.get_item_list().size() == n, "meshlib versionada no projeto")
	# Grade
	var g := TileGrid.new(Vector3(2, 2, 2))
	check(g.world_to_cell(Vector3(-0.1, 0, 3.9)) == Vector3i(-1, 0, 1), "world_to_cell com negativos")
	check(g.cell_to_world(Vector3i(1, 1, -1)).is_equal_approx(Vector3(3, 2, -1)), "cell_to_world = centro XZ, base Y")
	var cells: Array[Vector2i] = g.prop_cells(Vector3(4, 0, 4), Vector2i(2, 1))
	check(cells.size() == 2 and cells.has(Vector2i(1, 1)) and cells.has(Vector2i(2, 1)), "prop 2x1 centrado em (4,4): %s" % str(cells))
	var rot: Array[Vector2i] = g.prop_cells(Vector3(4, 0, 4), Vector2i(2, 1), PI * 0.5)
	check(rot.has(Vector2i(1, 1)) and rot.has(Vector2i(1, 2)), "giro de 90 graus troca largura e profundidade: %s" % str(rot))
	var occ := OccupancyGrid.new()
	check(occ.place(&"casa", cells) and not occ.place(&"poco", [Vector2i(2, 1)] as Array[Vector2i]), "ocupação impede sobreposição")
	check(occ.owner_at(Vector2i(2, 1)) == &"casa" and occ.is_free(Vector2i(9, 9)), "owner_at/is_free")
	occ.clear(&"casa")
	check(occ.occupied_count() == 0, "clear libera")
	print("%d passou, %d falhou" % [passes, failures])
	quit(1 if failures > 0 else 0)
