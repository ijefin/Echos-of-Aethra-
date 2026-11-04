extends SceneTree
## PropScatter: determinismo pela semente, exclusões e bake.
##   godot --headless --path . -s res://tests/unit/world/prop_scatter_test.gd
var failures := 0
var passes := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)


func _mk(parent: Node3D) -> PropScatter:
	var s := PropScatter.new()
	s.scenes = [load("res://assets/world/props/_placeholder/tree.tscn"), load("res://assets/world/props/_placeholder/rock.tscn")]
	s.weights = PackedFloat32Array([3.0, 1.0])
	s.area_size = Vector2(60, 60)
	s.min_distance = 3.0
	s.scatter_seed = 42
	parent.add_child(s)
	return s


func _xz(plan: Array[Dictionary]) -> Array:
	return plan.map(func(d: Dictionary) -> Vector2: return Vector2(d["position"].x, d["position"].z))


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var holder := Node3D.new()
	var s := _mk(holder)
	var a := s.compute_plan()
	var b := s.compute_plan()
	check(a.size() > 100 and a == b, "determinístico: %d pontos, plano idêntico em 2 chamadas" % a.size())
	var s2 := _mk(holder)
	s2.scatter_seed = 43
	check(s2.compute_plan() != a, "outra semente = outro plano")
	var pts: Array = _xz(a)
	var ok := true
	for i in pts.size():
		if absf(pts[i].x) > 30.001 or absf(pts[i].y) > 30.001:
			ok = false
		for j in range(i + 1, pts.size()):
			if (pts[i] as Vector2).distance_to(pts[j]) < 2.999:
				ok = false
	check(ok, "dentro da área e com distância mínima de 3 m")
	var scenes_used := {}
	for d in a:
		scenes_used[d["scene"]] = true
	check(scenes_used.size() == 2, "usa as duas peças do pool")
	# Exclusões
	s.exclusion_rects = [Rect2(-10, -10, 20, 20)]
	s.exclusion_circles = [Vector3(20, 20, 8)]
	var p1 := s.compute_plan()
	var clean := true
	for p: Vector2 in _xz(p1):
		if Rect2(-10, -10, 20, 20).has_point(p) or p.distance_to(Vector2(20, 20)) <= 8.0:
			clean = false
	check(clean and p1.size() < a.size() and p1.size() > 0, "retângulo e círculo excluídos (%d < %d)" % [p1.size(), a.size()])
	# Marcador
	var npc := NpcSpot.new()
	npc.position = Vector3(-15, 0, 10)
	holder.add_child(npc)
	s.exclusion_rects = []
	s.exclusion_circles = []
	s.marker_clear_radius = 6.0
	var p2 := s.compute_plan()
	var far := true
	for p: Vector2 in _xz(p2):
		if p.distance_to(Vector2(-15, 10)) <= 6.0:
			far = false
	check(far and p2.size() < a.size(), "raio livre em volta do marcador respeitado")
	# Trilha
	var path := Path3D.new()
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3(-30, 0, 0))
	path.curve.add_point(Vector3(30, 0, 0))
	holder.add_child(path)
	s.exclusion_paths = [NodePath("../" + String(path.name))]
	s.trail_half_width = 3.0
	root.add_child(holder)
	var p3 := s.compute_plan()
	var off := true
	for p: Vector2 in _xz(p3):
		if absf(p.y) <= 3.0:
			off = false
	check(off and p3.size() < p2.size(), "trilha Path3D mantida livre (%d pontos)" % p3.size())
	# Bake
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	var bs := _mk(scene_root)
	bs.owner = scene_root
	var n1 := bs.bake(scene_root)
	var baked: Node = bs.get_node("Baked")
	check(n1 == baked.get_child_count() and n1 > 0, "bake cria %d filhos" % n1)
	check(baked.get_child(0).owner == scene_root, "filhos assados pertencem à cena (serão salvos)")
	var n2 := bs.bake(scene_root)
	await process_frame
	check(n2 == n1 and bs.get_child_count() == 1, "bake repetido substitui o anterior")
	holder.queue_free()
	scene_root.queue_free()
	print("%d passou, %d falhou" % [passes, failures])
	quit(1 if failures > 0 else 0)
