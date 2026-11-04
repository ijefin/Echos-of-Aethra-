extends SceneTree
## WorldStreamer: carrega/descarrega regiões com histerese.
##   godot --headless --path . -s res://tests/unit/world/world_streamer_test.gd
var failures := 0
var passes := 0
var _events: Array[String] = []


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	call_deferred("run")


func _settle(s: WorldStreamer) -> void:
	for i in 600:
		await process_frame
		if s.pending_ids().is_empty():
			break
	await process_frame


func run() -> void:
	var scene := "res://src/world/regions/sample_village.tscn"
	var cat := WorldCatalog.from_dict({"load_radius": 70.0, "unload_radius": 90.0, "regions": {
		"a": {"scene": scene, "origin": [0, 0, 0], "bounds_size": [100, 40, 100]},
		"b": {"scene": scene, "origin": [300, 0, 0], "bounds_size": [100, 40, 100]}}})
	var s := WorldStreamer.new()
	s.setup(cat)
	root.add_child(s)
	s.region_loaded.connect(func(id: StringName, _r: Node3D) -> void: _events.append("+" + id))
	s.region_unloaded.connect(func(id: StringName) -> void: _events.append("-" + id))
	check(is_equal_approx(cat.distance_to(&"b", Vector3(190, 0, 0)), 60.0), "distância até o retângulo da região")
	s.update_focus(Vector3.ZERO)
	await _settle(s)
	check(s.is_loaded(&"a") and not s.is_loaded(&"b"), "foco em A: só A carrega")
	check(s.get_region(&"b") == null and s.get_region(&"a") != null, "get_region")
	s.update_focus(Vector3(135, 0, 0))   # A a 85 m (< 90): histerese mantém; B a 115 m: não carrega
	await _settle(s)
	check(s.is_loaded(&"a") and not s.is_loaded(&"b"), "histerese: A fica a 85 m, B ainda não")
	s.update_focus(Vector3(150, 0, 0))   # A a 100 m > 90: descarrega
	await _settle(s)
	check(not s.is_loaded(&"a") and not s.is_loaded(&"b"), "A descarrega além de 90 m")
	s.update_focus(Vector3(185, 0, 0))   # B a 65 m: carrega
	await _settle(s)
	check(s.is_loaded(&"b") and (s.get_region(&"b") as Node3D).position == Vector3(300, 0, 0), "B carrega a 65 m, na origem do catálogo")
	s.update_focus(Vector3(175, 0, 0))   # B a 75 m: entre 70 e 90, continua
	await _settle(s)
	check(s.is_loaded(&"b"), "histerese: B continua a 75 m")
	check(_events == ["+a", "-a", "+b"], "sinais na ordem: %s" % str(_events))
	s.update_focus(Vector3(-500, 0, 0))
	await _settle(s)
	check(s.loaded_ids().is_empty() and _events.back() == "-b", "tudo descarregado ao se afastar")
	s.queue_free()
	print("%d passou, %d falhou" % [passes, failures])
	quit(1 if failures > 0 else 0)
