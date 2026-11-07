# Print paired canopy sources and ground-light destinations for visual QA.
extends SceneTree

func _initialize() -> void:
	call_deferred("inspect")

func inspect() -> void:
	var demo: Node = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo.set_physics_process(false)
	demo._sky.hour = 8.5
	demo._sky.update(0.0, Vector3(0, 0, -8))
	for beam: Dictionary in demo._sky._shafts:
		if (beam.light as SpotLight3D).visible:
			print("SHAFT source=%s ground=%s" % [(beam.light as SpotLight3D).position, beam.target])
	quit()
