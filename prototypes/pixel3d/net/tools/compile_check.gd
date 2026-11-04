# PROTOTYPE - NOT FOR PRODUCTION
extends SceneTree
## Carrega todos os scripts da camada de rede e acusa qualquer erro de compilação.


func _initialize() -> void:
	var bad := 0
	for dir: String in ["res://prototypes/pixel3d/net/", "res://prototypes/pixel3d/net/tools/"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var s: Variant = load(dir + f)
				if s == null or not (s as GDScript).can_instantiate():
					printerr("COMPILE FAIL: ", dir + f)
					bad += 1
	print("COMPILE_CHECK: ", "OK" if bad == 0 else "FAIL (%d)" % bad)
	quit(1 if bad else 0)
