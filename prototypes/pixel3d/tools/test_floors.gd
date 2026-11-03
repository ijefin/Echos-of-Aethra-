# PROTOTYPE - NOT FOR PRODUCTION
extends SceneTree
## Teste dos andares: andar até a boca desce, andar até a escada sobe (as duas cavernas).
## godot --headless --path . -s res://prototypes/pixel3d/tools/test_floors.gd

func _initialize() -> void:
	call_deferred("run")


func _step_on(demo: Node, at: Vector3) -> void:
	demo._player.global_position = at
	for i in 6:
		await physics_frame


func run() -> void:
	var demo: Node = (load("res://prototypes/pixel3d/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	var a = demo._adventure
	a._persist = false
	var World = a.world
	var ok := true
	for i in World.STAIRS.size():
		var s: Dictionary = World.STAIRS[i]
		a._stair_cd = 0.0
		await _step_on(demo, s.down)
		var down_ok: bool = a.in_cave and absf(demo._player.global_position.y - World.ROOM.y) < 0.6 and not demo._world_root.visible
		a._stair_cd = 0.0
		await _step_on(demo, s.up)
		var up_ok: bool = not a.in_cave and demo._world_root.visible
		print("caverna %d: desce=%s sobe=%s" % [i, down_ok, up_ok])
		ok = ok and down_ok and up_ok
	print("FLOORS: ", "OK" if ok else "FALHOU")
	quit(0 if ok else 1)
