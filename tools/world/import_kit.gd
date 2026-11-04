extends SceneTree
## Gera as cenas de peças (WorldProp) de um kit a partir da tabela `mapping.json`.
## Reaplicável: rode de novo depois de mudar a tabela ou ao entrar um kit novo.
##
## godot --headless --path . -s res://tools/world/import_kit.gd -- res://assets/world/tiles/<kit>/mapping.json [...]
##
## Para cada entrada de `props` cria `res://assets/world/props/<categoria>/<prop_id>.tscn`:
## raiz Node3D com world_prop.gd, filhos `Variant0..N` (só o 0 visível) com o modelo
## escalado e, se `blocks`, um StaticBody3D (camada 1) com caixas simples medidas
## da AABB da variante 0. Grava também `<kit>.json` ao lado da tabela.
##
## Campos por peça: prop_id, category, variants[], blocks, footprint [x,z] (opcional:
## calculado pela AABB / cell_size), scale (sobrepõe a do kit), yaw (graus), collision
## ("box" padrão | "trunk" | "doorway" com opening/lintel | "corner" com thickness em u).

const PROP_SCRIPT := "res://src/world/props/world_prop.gd"
const PROPS_DIR := "res://assets/world/props"
const CATEGORIES := [&"wall", &"roof", &"floor", &"door", &"window", &"stairs", &"furniture",
	&"decor", &"tree", &"rock", &"fence", &"light", &"bridge", &"building"]

var _errors := 0


func _init() -> void:
	var seen := {}
	for mapping_path in OS.get_cmdline_user_args():
		_import(mapping_path, seen)
	print("import_kit: %d erro(s)" % _errors)
	quit(1 if _errors > 0 else 0)


func _fail(msg: String) -> void:
	push_error(msg)
	printerr("ERRO: ", msg)
	_errors += 1


func _import(mapping_path: String, seen: Dictionary) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(mapping_path))
	if typeof(data) != TYPE_DICTIONARY:
		_fail("tabela inválida: " + mapping_path)
		return
	var m: Dictionary = data
	var kit := String(m.kit)
	var cell := float(m.cell_size)
	var kit_scale := float(m.scale)
	var src := String(m.source_dir)
	var recenter := bool(m.get("recenter_xz", false))
	var script := load(PROP_SCRIPT) as Script
	var scenes := {}
	var info := {}
	for e: Dictionary in m.props:
		var id := StringName(e.prop_id)
		var cat := StringName(e.category)
		if not CATEGORIES.has(cat):
			_fail("%s: categoria desconhecida %s" % [id, cat])
			continue
		if seen.has(id):
			_fail("%s: prop_id repetido (também em %s)" % [id, seen[id]])
			continue
		seen[id] = kit
		var s := float(e.get("scale", kit_scale))
		var yaw := deg_to_rad(float(e.get("yaw", 0.0)))
		var root := Node3D.new()
		root.name = _pascal(String(id))
		root.set_script(script)
		var box0 := AABB()
		var ok := true
		var variants: Array = e.variants
		for i in variants.size():
			var path := src.path_join(String(variants[i]))
			var ps := load(path) as PackedScene
			if ps == null:
				_fail("%s: modelo não encontrado %s" % [id, path])
				ok = false
				break
			var holder := Node3D.new()
			holder.name = "Variant%d" % i
			holder.visible = i == 0
			root.add_child(holder)
			holder.owner = root
			var model := ps.instantiate() as Node3D
			model.name = "Model"
			model.scale = Vector3.ONE * s
			model.rotation.y = yaw
			holder.add_child(model)
			model.owner = root
			var b := _aabb(model, holder)
			if recenter:
				var c := b.get_center()
				model.position -= Vector3(c.x, 0.0, c.z)
				b.position -= Vector3(c.x, 0.0, c.z)
			if i == 0:
				box0 = b
		if not ok:
			root.free()
			continue
		var fp: Vector2i
		if e.has("footprint"):
			fp = Vector2i(int(e.footprint[0]), int(e.footprint[1]))
		else:
			fp = Vector2i(maxi(1, roundi(box0.size.x / cell)), maxi(1, roundi(box0.size.z / cell)))
		var blocks := bool(e.get("blocks", false))
		root.set(&"prop_id", id)
		root.set(&"category", cat)
		root.set(&"footprint", fp)
		root.set(&"blocks_movement", blocks)
		root.set(&"variant", 0)
		root.set(&"tint", Color.WHITE)
		if blocks:
			_add_collision(root, box0, e, s)
		var out_dir := PROPS_DIR.path_join(String(cat))
		DirAccess.make_dir_recursive_absolute(out_dir)
		var out := out_dir.path_join(String(id) + ".tscn")
		var packed := PackedScene.new()
		packed.pack(root)
		if ResourceSaver.save(packed, out) != OK:
			_fail("%s: falha ao gravar %s" % [id, out])
		root.free()
		scenes[String(id)] = out
		info[String(id)] = {
			"category": String(cat), "footprint": [fp.x, fp.y], "blocks": blocks,
			"variants": variants.size(), "scale": s,
			"size": [snappedf(box0.size.x, 0.01), snappedf(box0.size.y, 0.01), snappedf(box0.size.z, 0.01)],
		}
		print("%-18s %-9s fp=%s blocks=%s size=%s" % [id, cat, fp, blocks, box0.size])
	var kit_json := {
		"kit": kit, "cell_size": cell, "scale": kit_scale, "rotations": m.rotations,
		"mapping": mapping_path, "props": scenes, "info": info,
	}
	var f := FileAccess.open(mapping_path.get_base_dir().path_join(kit + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(kit_json, "\t", false) + "\n")
	f.close()


## Caixas de colisão simples, em espaço da raiz, a partir da AABB `b` da variante 0.
func _add_collision(root: Node3D, b: AABB, e: Dictionary, s: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	body.owner = root
	var boxes: Array[AABB] = []
	match String(e.get("collision", "box")):
		"trunk":
			var w := maxf(0.3, minf(b.size.x, b.size.z) * 0.25)
			var c := b.get_center()
			boxes.append(AABB(Vector3(c.x - w * 0.5, b.position.y, c.z - w * 0.5), Vector3(w, b.size.y, w)))
		"doorway":
			var f := float(e.get("opening", 0.5))
			var side := b.size.x * (1.0 - f) * 0.5
			boxes.append(AABB(b.position, Vector3(side, b.size.y, b.size.z)))
			boxes.append(AABB(b.position + Vector3(b.size.x - side, 0, 0), Vector3(side, b.size.y, b.size.z)))
			var lintel := b.size.y * float(e.get("lintel", 0.25))
			if lintel > 0.0:
				boxes.append(AABB(b.position + Vector3(side, b.size.y - lintel, 0), Vector3(b.size.x - 2.0 * side, lintel, b.size.z)))
		"corner":
			var t := float(e.get("thickness", 1.0)) * s
			boxes.append(AABB(b.position, Vector3(b.size.x, b.size.y, t)))
			boxes.append(AABB(Vector3(b.end.x - t, b.position.y, b.position.z), Vector3(t, b.size.y, b.size.z)))
		_:
			boxes.append(b)
	for i in boxes.size():
		var shape := BoxShape3D.new()
		shape.size = boxes[i].size
		var cs := CollisionShape3D.new()
		cs.name = "Shape%d" % i
		cs.shape = shape
		cs.position = boxes[i].get_center()
		body.add_child(cs)
		cs.owner = root


## AABB das malhas de `n`, no espaço de `space` (sem depender da árvore de cena).
static func _aabb(n: Node3D, space: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := Transform3D.IDENTITY
		var p: Node = m
		while p != space and p != null:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		var b := t * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _pascal(s: String) -> String:
	var out := ""
	for part in s.split("_"):
		out += part.capitalize().replace(" ", "")
	return out
