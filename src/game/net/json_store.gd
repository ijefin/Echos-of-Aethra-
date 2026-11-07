extends RefCounted
## Persistência JSON atômica: grava em `.tmp`, guarda o anterior em `.bak` e renomeia.
## Na leitura, se o principal estiver corrompido/ausente, usa o `.bak`.


static func save(path: String, data: Dictionary) -> Error:
	var abs_path := ProjectSettings.globalize_path(path)
	var dir := abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var mk := DirAccess.make_dir_recursive_absolute(dir)
		if mk != OK:
			return mk
	var tmp := abs_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "", false))
	f.flush()
	f.close()
	# confere o que foi gravado antes de trocar
	var check := FileAccess.open(tmp, FileAccess.READ)
	if check == null or not (JSON.parse_string(check.get_as_text()) is Dictionary):
		return ERR_FILE_CORRUPT
	check.close()
	if FileAccess.file_exists(abs_path):
		var bak := abs_path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		var mv := DirAccess.rename_absolute(abs_path, bak)
		if mv != OK:
			return mv
	return DirAccess.rename_absolute(tmp, abs_path)


## Devolve {} se nada válido existir.
static func load_dict(path: String) -> Dictionary:
	var abs_path := ProjectSettings.globalize_path(path)
	for p: String in [abs_path, abs_path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var v: Variant = JSON.parse_string(f.get_as_text())
		if v is Dictionary:
			return v
	return {}
