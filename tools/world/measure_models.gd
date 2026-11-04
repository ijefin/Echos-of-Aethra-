extends SceneTree
## Mede a AABB (sem escala) de modelos glTF/GLB. Uso:
## godot --headless --path . -s res://tools/world/measure_models.gd -- <arquivo1> <arquivo2> ...
## Imprime: caminho  size.x size.y size.z  pos.x pos.y pos.z
## Pastas são varridas recursivamente. `arquivo#Prefixo_` mede só as malhas cujo nome
## começa com o prefixo e não são capa (como o jogo mede o corpo do KayKit Adventurers).


func _init() -> void:
	var paths: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if DirAccess.dir_exists_absolute(a):
			_collect(a, paths)
		else:
			paths.append(a)
	for arg in paths:
		var path := arg.get_slice("#", 0)
		var only := arg.get_slice("#", 1) if arg.contains("#") else ""
		var ps := load(path) as PackedScene
		if ps == null:
			print("FALHA ", path)
			continue
		var n := ps.instantiate() as Node3D
		root.add_child(n)
		var box := aabb_of(n, only)
		print("%s  %.3f %.3f %.3f  %.3f %.3f %.3f" % [path.get_file(), box.size.x, box.size.y, box.size.z, box.position.x, box.position.y, box.position.z])
		n.free()
	quit()


## Junta (recursivo) os .glb/.gltf de uma pasta.
static func _collect(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb") or f.ends_with(".gltf"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)


## AABB combinada, em coordenadas do nó raiz, de todas as malhas visíveis.
static func aabb_of(n: Node3D, only: String = "") -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.visible:
			continue
		if only != "" and (not String(m.name).begins_with(only) or String(m.name).contains("Cape")):
			continue
		# transform relativa à raiz sem depender da árvore (roda em _init)
		var t := Transform3D.IDENTITY
		var p: Node = m
		while p != n and p != null:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		var b := t * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
