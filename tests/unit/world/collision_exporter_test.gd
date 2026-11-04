extends SceneTree
## WorldCollisionExporter: formato idêntico ao do servidor.
##   godot --headless --path . -s res://tests/unit/world/collision_exporter_test.gd
const SERVER_JSON := "res://prototypes/pixel3d/net/data/collision_surface.json"
const Collision := preload("res://prototypes/pixel3d/net/world_collision.gd")
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
	var ex := WorldCollisionExporter.new()
	var data: Dictionary = ex.export_roots([region] as Array[Node], "teste")
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SERVER_JSON))
	var k1 := data.keys()
	var k2 := ref.keys()
	k1.sort()
	k2.sort()
	check(k1 == k2, "mesmas chaves de topo do servidor: %s" % str(k1))
	check(int(data["version"]) == int(ref["version"]), "mesma versão do formato")
	var f1: Dictionary = data["floors"]["-1"]
	var f2: Dictionary = ref["floors"]["-1"]
	var fk1 := f1.keys()
	var fk2 := f2.keys()
	fk1.sort()
	fk2.sort()
	check(fk1 == fk2 and is_equal_approx(f1["y"], f2["y"]), "andar -1 com mesmas chaves e y")
	check(data["circles"].size() > 50, "árvores/pedras viram círculos (%d)" % data["circles"].size())
	check(data["boxes"].size() > 10, "paredes do GridMap viram caixas (%d)" % data["boxes"].size())
	var shapes_ok := true
	for c: Array in data["circles"]:
		shapes_ok = shapes_ok and c.size() == 4 and int(c[3]) in [1, 4]
	for b: Array in data["boxes"]:
		shapes_ok = shapes_ok and b.size() == 6 and int(b[5]) in [1, 4]
	check(shapes_ok, "linhas com o mesmo número de campos e máscara 1/4")
	check(ref["circles"][0].size() == 4 and ref["boxes"][0].size() == 6, "(referência) mesmo layout de linhas")
	var well := false
	for c: Array in data["circles"]:
		if absf(c[0]) < 0.1 and absf(c[1]) < 0.1:
			well = true
	check(well, "poço em (0,0) exportado")
	var out := "user://world_collision_test.json"
	check(ex.save(data, out) == OK, "JSON gravado")
	var back: Variant = JSON.parse_string(FileAccess.get_file_as_string(out))
	check(back is Dictionary and (back as Dictionary).has("boxes"), "JSON válido ao reler")
	var floors: Dictionary = Collision.load_floors(out, 100.0)
	check(floors.has(0) and (floors[0] as RefCounted).count() == data["circles"].size() + data["boxes"].size() + data["polys"].size(), "o carregador do servidor aceita o arquivo")
	region.free()
	print("%d passou, %d falhou" % [passes, failures])
	quit(1 if failures > 0 else 0)
