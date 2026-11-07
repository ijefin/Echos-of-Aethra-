extends SceneTree
## QA visual da Gruta das Raízes natural: um print por ambiente, sem save do jogador.
## godot --path . -s res://src/game/tools/capture_cave.gd

const SHOTS := [
	["entrada", Vector3(0, 0, 8.5), false],
	["salao-aranhas", Vector3(-4, 0, 3), false],
	["ruinas", Vector3(6, 0, -6), true],
	["cachoeira", Vector3(-9, 0, -8), true],
	["altar", Vector3(5, 0, -13.5), true],
	["escada", Vector3(0, 0, 11.5), true],
	["tunel", Vector3(48, 0, 14), true],
	["segunda-caverna", Vector3(74, 0, 69), true],
]


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var demo: Node = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	var a = demo._adventure
	a._persist = false
	demo._px = 1.0 / 26.0
	demo._fit()
	a.state.accept_quest()
	a.state.add_xp(18)
	for s: Array in SHOTS:
		if bool(s[2]) and not a.state.has_reward():
			a.state.restore({"level": 3, "xp": 2, "stage": "claimed"})
			for enemy: Dictionary in a.enemies.actors:
				if enemy.cave:
					enemy.dead = true
					(enemy.body as Node3D).collision_layer = 0
					(enemy.body as Node3D).hide()
		a.warp(a.world.ROOM + (s[1] as Vector3), true)
		a.hp = a.state.max_hp()
		a.notice_time = 0
		await create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://production/qa/evidence/pixel3d-cave-%s.png" % s[0])
	quit()
