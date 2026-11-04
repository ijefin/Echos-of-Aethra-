class_name MeshLibraryBuilder
extends RefCounted
## Gera uma MeshLibrary (para GridMap) a partir de um kit de tiles.
## Um kit é `res://assets/world/tiles/<kit>/<kit>.json`:
## {
##   "kit": "nome", "cell_size": [2,2,2], "scale": 1.0,
##   "pieces": [ { "id": "wall", "scene": "res://.../wall.tscn",
##                 "collision": "box" | "convex" | "trimesh" | "none" } ]   // padrão "box"
## }
## A malha de cada peça é o primeiro MeshInstance3D da cena (a transformação dele
## dentro da cena é preservada). A saída vai para `res://assets/world/tiles/<kit>.meshlib`.
## Os itens recebem o id da lista (0..N-1) e o nome `id` da peça.

const TILES_DIR: String = "res://assets/world/tiles"


## Constrói a MeshLibrary de um kit. Devolve null (com push_error) se o kit for inválido.
static func build(kit_json_path: String) -> MeshLibrary:
	var kit: Dictionary = JsonData.load_dict(kit_json_path)
	if kit.is_empty() or not (kit.get("pieces") is Array):
		push_error("MeshLibraryBuilder: kit inválido em %s" % kit_json_path)
		return null
	var scale: float = float(kit.get("scale", 1.0))
	var lib: MeshLibrary = MeshLibrary.new()
	var meshes: Array[Mesh] = []
	for piece: Dictionary in kit["pieces"]:
		var packed: PackedScene = load(String(piece.get("scene", ""))) as PackedScene
		if packed == null:
			push_error("MeshLibraryBuilder: cena ausente para a peça '%s'" % piece.get("id", "?"))
			continue
		var root: Node = packed.instantiate()
		var mi: MeshInstance3D = _first_mesh(root)
		if mi == null:
			push_error("MeshLibraryBuilder: peça '%s' sem MeshInstance3D" % piece.get("id", "?"))
			root.free()
			continue
		var xf: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3.ZERO) \
			* WorldXform.to_root(mi, root.get_parent())
		var id: int = lib.get_last_unused_item_id()
		lib.create_item(id)
		lib.set_item_name(id, String(piece.get("id", "item%d" % id)))
		lib.set_item_mesh(id, mi.mesh)
		lib.set_item_mesh_transform(id, xf)
		var shapes: Array = _collision_for(mi.mesh, xf, String(piece.get("collision", "box")))
		if not shapes.is_empty():
			lib.set_item_shapes(id, shapes)
		meshes.append(mi.mesh)
		root.free()
	_assign_previews(lib, meshes)
	return lib


## Constrói e grava a MeshLibrary. `out_path` vazio = `res://assets/world/tiles/<kit>.meshlib`.
static func build_and_save(kit_json_path: String, out_path: String = "") -> Error:
	var lib: MeshLibrary = build(kit_json_path)
	if lib == null:
		return ERR_INVALID_DATA
	if out_path.is_empty():
		out_path = "%s/%s.meshlib" % [TILES_DIR, kit_json_path.get_file().get_basename()]
	return ResourceSaver.save(lib, out_path)


## Caminhos de todos os kits (`<TILES_DIR>/<kit>/<kit>.json`).
static func find_kits() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for d: String in DirAccess.get_directories_at(TILES_DIR):
		var p: String = "%s/%s/%s.json" % [TILES_DIR, d, d]
		if FileAccess.file_exists(p):
			out.append(p)
	return out


static func _first_mesh(root: Node) -> MeshInstance3D:
	for n: Node in WorldXform.all_nodes(root):
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			return n as MeshInstance3D
	return null


static func _collision_for(mesh: Mesh, xf: Transform3D, mode: String) -> Array:
	match mode:
		"none":
			return []
		"convex":
			return [mesh.create_convex_shape(), Transform3D(xf.basis, xf.origin)]
		"trimesh":
			return [mesh.create_trimesh_shape(), Transform3D(xf.basis, xf.origin)]
		_:
			var box: AABB = xf * mesh.get_aabb()
			var shape: BoxShape3D = BoxShape3D.new()
			shape.size = box.size
			return [shape, Transform3D(Basis.IDENTITY, box.get_center())]


## No editor, gera as miniaturas dos itens (opcional; fora do editor não faz nada).
static func _assign_previews(lib: MeshLibrary, meshes: Array[Mesh]) -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton(&"EditorInterface"):
		return
	var ei: Object = Engine.get_singleton(&"EditorInterface")
	var previews: Array = ei.call("make_mesh_previews", meshes, 64)
	for i: int in mini(previews.size(), lib.get_item_list().size()):
		lib.set_item_preview(lib.get_item_list()[i], previews[i])
