extends SceneTree
## Focused visual QA fixtures, independent of player saves and the gameplay test.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var demo: Node = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	var a = demo._adventure
	a._persist = false
	demo._px = 1.0 / 20.0
	demo._fit()
	a.state.accept_quest()
	a.state.add_xp(18)
	a.hp = a.state.max_hp()
	a.warp(a.world.ROOM + Vector3(0, 0, 2.8), true)
	a.say("Guardiões protegem o baú. A inscrição ensina a ordem das tochas.")
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://production/qa/evidence/pixel3d-adventure-cave-readable.png")
	a.state.restore({"level": 3, "xp": 2, "stage": "claimed"})
	a._equip_reward()
	for enemy: Dictionary in a.enemies.actors:
		if enemy.cave:
			enemy.dead = true
			(enemy.body as Node3D).collision_layer = 0
			(enemy.body as Node3D).hide()
	a.warp(a.world.ROOM + Vector3(0, 0, -1), true)
	a.hp = a.state.max_hp()
	a.notice_time = 0
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://production/qa/evidence/pixel3d-adventure-puzzle-lit.png")
	a.hud.bag_open = true
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://production/qa/evidence/pixel3d-adventure-bag-readable.png")
	quit()
