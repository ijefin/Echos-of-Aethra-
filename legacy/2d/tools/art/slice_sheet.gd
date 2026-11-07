## Fatia uma folha de sprites "solta" (sem grade exata, ex.: gerada por IA de imagem) em
## frames alinhados pelos pés e escreve o manifesto que o PlayerAvatar lê (modo sprite8).
##   godot --headless --path . -s res://legacy/2d/tools/art/slice_sheet.gd -- res://legacy/2d/tools/art/sheets/nightshalk.json
## O JSON da folha descreve: linhas [y_topo, y_base], centro/passo das colunas, escala e
## quais frames formam cada animação por direção. Ver legacy/2d/tools/art/sheets/nightshalk.json.
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("slice_sheet: passe o JSON da folha depois de --")
		quit(1)
		return
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var src := Image.new()
	if src.load(ProjectSettings.globalize_path(String(cfg.source))) != OK:
		push_error("slice_sheet: não abriu %s" % cfg.source)
		quit(1)
		return
	src.convert(Image.FORMAT_RGBA8)
	var out_dir := String(cfg.out_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var scale := float(cfg.scale)
	var cell_w := int(cfg.cell_w)
	var cell_h := int(cfg.cell_h)
	var out_w := roundi(cell_w * scale)
	var out_h := roundi(cell_h * scale)
	var rows: Array = cfg.rows
	var manifest := {
		"pivot": [out_w / 2.0, out_h - 2.0],
		"dirs": {}, "mirror": cfg.get("mirror", {}), "anims": {},
	}
	var rel_dir := out_dir.trim_prefix("res://legacy/2d/assets/art/")
	for anim: String in cfg.anims:
		var a: Dictionary = cfg.anims[anim]
		var dirs := {}
		for key: String in a.dirs:
			var spec: Array = a.dirs[key]
			var row: Array = rows[int(spec[0])]
			var paths: Array = []
			for col in range(int(spec[1]), int(spec[2]) + 1):
				var cx := float(cfg.col_center0) + float(cfg.col_step) * col
				# Recorte do tamanho da célula com a base da linha (os pés) no fundo.
				var region := Rect2i(roundi(cx - cell_w / 2.0), int(row[1]) - cell_h + 1, cell_w, cell_h)
				region = region.intersection(Rect2i(Vector2i.ZERO, src.get_size()))
				var frame := Image.create_empty(cell_w, cell_h, false, Image.FORMAT_RGBA8)
				frame.blit_rect(src, region, Vector2i(region.position.x - roundi(cx - cell_w / 2.0), cell_h - region.size.y))
				frame.resize(out_w, out_h, Image.INTERPOLATE_LANCZOS)
				_binary_alpha(frame)
				var file := "%s_%s_%s_%02d.png" % [cfg.out_prefix, anim, key, col - int(spec[1])]
				frame.save_png(out_dir + file)
				paths.append(rel_dir + file)
			dirs[key] = paths
		manifest.anims[anim] = {"fps": a.fps, "dirs": dirs, "mirror": cfg.get("mirror", {})}
		if anim == "idle":
			for key: String in dirs:
				manifest.dirs[key] = dirs[key][0]
	var f := FileAccess.open(String(cfg.manifest_out), FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	print("slice_sheet: OK — %d animações, células %dx%d, manifesto %s" % [manifest.anims.size(), out_w, out_h, cfg.manifest_out])
	quit()


## Alfa binário (0 ou 1), sem franja semitransparente da redução (art bible §8).
func _binary_alpha(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(p.r, p.g, p.b, 1.0 if p.a > 0.5 else 0.0))
