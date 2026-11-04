extends SceneTree
## Gera as MeshLibrary dos kits de tiles (sem abrir o editor):
##   godot --headless --path . -s res://src/world/tools/build_mesh_library.gd
##   godot --headless --path . -s res://src/world/tools/build_mesh_library.gd -- res://assets/world/tiles/<kit>/<kit>.json
## Sem argumentos, processa todos os kits em res://assets/world/tiles/*/*.json.


func _initialize() -> void:
	var kits: PackedStringArray = OS.get_cmdline_user_args()
	if kits.is_empty():
		kits = MeshLibraryBuilder.find_kits()
	var failed: int = 0
	for k: String in kits:
		var err: Error = MeshLibraryBuilder.build_and_save(k)
		print("%s %s" % ["OK  " if err == OK else "ERRO", k])
		if err != OK:
			failed += 1
	quit(1 if failed > 0 else 0)
