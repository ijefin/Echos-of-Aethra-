# PROTOTYPE - NOT FOR PRODUCTION
# Reports population and checks approach trails against actual world collision.
extends SceneTree
const Camps := preload("res://prototypes/pixel3d/pixel3d_camps.gd")

func _initialize() -> void:
	call_deferred("inspect")

func inspect() -> void:
	var demo: Node = (load("res://prototypes/pixel3d/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo.set_physics_process(false)
	await physics_frame
	await physics_frame
	print("WOODLAND trees=%d camps=%d tents=%d" % [demo._tree_spots.size(), Camps.CENTERS.size(), Camps.CENTERS.size() * 2])
	var sphere := SphereShape3D.new()
	sphere.radius = 0.30
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1 | 4
	query.exclude = [demo._player.get_rid()]
	var hits := 0
	var samples := 0
	var space: PhysicsDirectSpaceState3D = demo._player.get_world_3d().direct_space_state
	for camp in Camps.TRAILS.size() / 5:
		for i in 4:
			var a: Vector2 = Camps.TRAILS[camp * 5 + i]
			var b: Vector2 = Camps.TRAILS[camp * 5 + i + 1]
			var steps := ceili(a.distance_to(b) / 0.4)
			for k in steps + 1:
				var p := a.lerp(b, float(k) / steps)
				# Inside the camp the player walks around the hearth/furniture.
				if Camps.clearing_distance(p) < 0.0:
					continue
				samples += 1
				query.transform.origin = Vector3(p.x, 0.7, p.y)
				var contacts := space.intersect_shape(query, 4)
				if not contacts.is_empty():
					hits += 1
					print("TRAIL contact=%s" % p)
	print("TRAIL samples=%d blocked=%d" % [samples, hits])
	quit(1 if hits > 0 else 0)
