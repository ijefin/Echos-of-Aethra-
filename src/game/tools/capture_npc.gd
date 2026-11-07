extends SceneTree
## QA: fala da Nessa sobre a cabeça + painel do objetivo.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var demo: Node = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	var a = demo._adventure
	a._persist = false
	await create_timer(0.8).timeout
	a.interact()
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://production/qa/evidence/pixel3d-npc-talk.png")
	quit()
