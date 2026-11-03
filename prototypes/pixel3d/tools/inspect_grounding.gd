# PROTOTYPE - NOT FOR PRODUCTION
# Inspect actual posed feet, rather than the imported bind-pose AABB.
extends SceneTree

func _initialize() -> void:
	call_deferred("inspect")

func inspect() -> void:
	var demo: Node = (load("res://prototypes/pixel3d/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo.set_physics_process(false)
	for anim_name in ["Idle", "Running_A"]:
		demo._anim.play(anim_name)
		for time in [0.0, 0.15, 0.3, 0.45]:
			demo._anim.seek(time, true)
			await process_frame
			await process_frame
			var bottom := INF
			for name in ["Mage_LegLeft", "Mage_LegRight"]:
				var leg := demo._model.find_child(name, true, false) as MeshInstance3D
				var posed := leg.bake_mesh_from_current_skeleton_pose()
				for surface in posed.get_surface_count():
					var vertices: PackedVector3Array = posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
					for v in vertices:
						bottom = minf(bottom, (leg.global_transform * v).y)
			print("GROUNDING %s t=%.2f lowest_foot=%.4f" % [anim_name, time, bottom])
	quit()
