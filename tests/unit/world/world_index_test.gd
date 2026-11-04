extends SceneTree
## WorldIndex lê os marcadores do vilarejo de exemplo:
##   godot --headless --path . -s res://tests/unit/world/world_index_test.gd
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
	var region: Node = (load("res://src/world/regions/sample_village.tscn") as PackedScene).instantiate()
	var idx: WorldIndex = WorldIndex.scan(region)
	check(idx.region["region_id"] == &"sample_village" and idx.region["danger_level"] == 1, "região: id e perigo")
	check((idx.region["bounds"] as AABB).size == Vector3(100, 40, 100), "região: bounds")
	check(idx.player_spawns().size() == 1, "1 spawn de jogador")
	check(idx.player_spawns()[0]["position"].is_equal_approx(Vector3(0, 0, 8)), "spawn do jogador em (0,0,8)")
	var npcs: Array = idx.get_all(&"npc").map(func(d: Dictionary) -> StringName: return d["id"])
	check(npcs.has(&"elder") and npcs.has(&"merchant") and npcs.size() == 2, "2 NPCs: elder e merchant")
	check(not idx.find(&"secret", &"hidden_stash").is_empty(), "segredo hidden_stash")
	check(idx.enemy_spawns(&"wolf").size() == 2 and idx.enemy_spawns(&"bear").is_empty(), "spawns de lobo filtrados")
	check(not idx.find(&"landmark", &"village_plaza").is_empty() and not idx.find(&"quest", &"elder_house_door").is_empty(), "landmark e quest point")
	check(idx.hunt_area_at(Vector3(40, 0, -10)).get("id") == &"wolf_woods", "área de caça contém o centro")
	check(idx.hunt_area_at(Vector3(0, 0, 0)).is_empty(), "praça fora da área de caça")
	check(idx.hunt_area_at(Vector3(51, 0, -10)).is_empty(), "fora do raio")
	check(idx.find(&"spawn", &"nope").is_empty(), "find inexistente = vazio")
	# Região deslocada: posições acompanham a transformação da raiz.
	(region as Node3D).position = Vector3(100, 0, 0)
	var moved: WorldIndex = WorldIndex.scan(region)
	check(moved.player_spawns()[0]["position"].is_equal_approx(Vector3(100, 0, 8)), "posições seguem a origem da região")
	# Caixa girada
	var box_info: Dictionary = {"position": Vector3.ZERO, "shape": &"box", "size": Vector2(10, 2), "yaw": PI / 2}
	check(HuntArea.contains_point(box_info, Vector3(0, 0, 4)) and not HuntArea.contains_point(box_info, Vector3(4, 0, 0)), "HuntArea box girada")
	region.free()
	print("%d passou, %d falhou" % [passes, failures])
	quit(1 if failures > 0 else 0)
