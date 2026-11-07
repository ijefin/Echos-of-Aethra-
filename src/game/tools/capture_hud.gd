extends SceneTree
## QA do HUD mínimo: tela de jogo, atalhos (H) e personagem (C).
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var demo: Node = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	var a = demo._adventure
	a._persist = false
	a.state.accept_quest()
	a.state.add_xp(14)
	a.hp = 41
	a.mana = 22
	demo._blink_cd = 1.4
	for shot: Array in [["", "pixel3d-hud-game"], ["help", "pixel3d-hud-atalhos"], ["char", "pixel3d-hud-personagem"]]:
		a.hud.panel = shot[0]
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://production/qa/evidence/%s.png" % shot[1])
	quit()
