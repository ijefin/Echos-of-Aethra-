extends SceneTree
## Gera os ícones da bolsa a partir dos modelos 3D (rode COM janela, não --headless):
##   godot --path . -s res://src/items/tools/bake_item_icons.gd -- [opções] [ids...]
## Opções:
##   --items      só ícones de itens (assets/items/icons/<id>.png)
##   --models     só a vitrine da biblioteca (assets/items/icons/models/<chave>.png)
##   --missing    pula quem já tem PNG
##   ids...       limita a esses ids de item / chaves de modelo
## Sem opções: tudo. Normalmente chamado por `bash tools/bake_item_icons.sh`.

const BAKER_SCENE := "res://src/items/tools/icon_baker.tscn"
const MODEL_ICON_DIR := ItemCatalog.ICON_DIR + "/models"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("bake_item_icons: precisa de janela (rode sem --headless)")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	var only := PackedStringArray()
	for a in args:
		if not a.begins_with("--"):
			only.append(a)
	var do_items := "--models" not in args
	var do_models := "--items" not in args
	var missing := "--missing" in args
	var cat := ItemCatalog.load_default()
	var baker := (load(BAKER_SCENE) as PackedScene).instantiate() as IconBaker
	baker.settings = cat.art.get("bake", {})
	root.add_child(baker)
	await process_frame
	var done := 0
	var failed := 0
	if do_models:
		for key in cat.model_keys():
			if not only.is_empty() and key not in only:
				continue
			var e := cat.model_entry(key)
			var r := await _bake_one(baker, String(e.path), e.get("view", {}), Color.WHITE, "%s/%s.png" % [MODEL_ICON_DIR, key], missing)
			done += int(r == OK)
			failed += int(r != OK and r != ERR_ALREADY_EXISTS)
	if do_items:
		for d in cat.with_model():
			if not only.is_empty() and String(d.id) not in only:
				continue
			var r := await _bake_one(baker, d.model_path, d.icon_view, d.tint, "%s/%s.png" % [ItemCatalog.ICON_DIR, d.id], missing)
			done += int(r == OK)
			failed += int(r != OK and r != ERR_ALREADY_EXISTS)
	print("bake_item_icons: %d gerados, %d falhas" % [done, failed])
	quit(1 if failed > 0 else 0)


func _bake_one(baker: IconBaker, model_path: String, view: Dictionary, tint: Color, out: String, missing: bool) -> Error:
	if missing and FileAccess.file_exists(out):
		return ERR_ALREADY_EXISTS
	var scene := load(model_path) as PackedScene
	if scene == null:
		printerr("bake_item_icons: modelo não carregou: ", model_path)
		return ERR_CANT_OPEN
	var img := await baker.bake(scene, view, tint)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var err := img.save_png(out)
	print("  ", out, " ", error_string(err))
	return err
