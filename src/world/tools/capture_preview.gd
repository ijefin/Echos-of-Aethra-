extends SceneTree
## Captura de tela da cena de preview (rode SEM --headless):
##   godot --path . -s res://src/world/tools/capture_preview.gd -- <saida.png> [yaw] [pitch] [distancia]
## Padrão: production/qa/evidence/world_sample_village.png


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "res://production/qa/evidence/world_sample_village.png"
	var scene: Node = (load("res://src/world/tools/world_preview.tscn") as PackedScene).instantiate()
	if args.size() > 1:
		scene.yaw_deg = float(args[1])
	if args.size() > 2:
		scene.pitch_deg = float(args[2])
	if args.size() > 3:
		scene.distance = float(args[3])
	root.add_child(scene)
	root.size = Vector2i(1280, 720)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	print("captura: ", out, " ", img.get_size(), " erro=", error_string(img.save_png(out)))
	quit(0)
