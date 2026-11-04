class_name WorldCollisionExporter
extends RefCounted
## Exporta a colisão de regiões feitas no editor para o formato que o servidor
## dedicado já lê (mesmo esquema de `collision_surface.json` do protótipo):
##   {version, half, source, circles:[[x,z,r,m]], boxes:[[cx,cz,hx,hz,yaw,m]],
##    polys:[[m,x0,z0,x1,z1,...]], floors:{"-1":{y, circles, boxes, polys}}}
## m = máscara: 1 = cenário (bloqueia tudo), 4 = água (bloqueia andar, não tiro).
## Lê StaticBody3D das camadas 1 e 4 e as formas dos GridMap (MeshLibrary), pela pegada
## XZ de cada forma que cruza a faixa de altura do corpo do jogador em cada andar.
## Funciona com as regiões fora da árvore (usa WorldXform).

const MASK_SOLID: int = 1
const MASK_WATER: int = 4
const FORMAT_VERSION: int = 2

## Faixa de altura do corpo do jogador por andar: [y_min, y_max].
var bands: Dictionary = {"0": [0.25, 1.6], "-1": [-7.75, -6.4]}
## Altura do piso de cada andar (usada no campo `y` dos andares abaixo da superfície).
var floor_y: Dictionary = {"0": 0.0, "-1": -8.0}
## Metade do lado do mundo (o servidor usa para limitar o mapa).
var half: float = 100.0

var _stats: Dictionary = {}


## Gera o dicionário de colisão para as raízes dadas (regiões já posicionadas).
func export_roots(roots: Array[Node], source: String = "WorldCollisionExporter") -> Dictionary:
	var floors: Dictionary = {}
	for f: String in bands:
		floors[f] = {"circles": [], "boxes": [], "polys": []}
	_stats.clear()
	for root: Node in roots:
		for n: Node in WorldXform.all_nodes(root):
			if n is StaticBody3D:
				_add_body(n as StaticBody3D, floors)
			elif n is GridMap:
				_add_gridmap(n as GridMap, floors)
	var out: Dictionary = {"version": FORMAT_VERSION, "half": half, "source": source,
		"circles": floors["0"]["circles"], "boxes": floors["0"]["boxes"], "polys": floors["0"]["polys"],
		"floors": {}}
	for f: String in bands:
		if f != "0":
			var d: Dictionary = floors[f]
			d["y"] = floor_y.get(f, 0.0)
			out["floors"][f] = d
	return out


## Grava o dicionário como JSON. Devolve o erro de escrita (OK se gravou).
func save(data: Dictionary, path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.close()
	return OK


## Contagem de formas por tipo da última exportação (diagnóstico).
func stats() -> Dictionary:
	return _stats


func _add_body(body: StaticBody3D, floors: Dictionary) -> void:
	var layer: int = body.collision_layer & (MASK_SOLID | MASK_WATER)
	if layer == 0:
		return
	var m: int = MASK_SOLID if (layer & MASK_SOLID) else MASK_WATER
	var body_xf: Transform3D = WorldXform.to_root(body)
	for c: Node in body.get_children():
		if c is CollisionShape3D and not (c as CollisionShape3D).disabled and (c as CollisionShape3D).shape != null:
			var cs: CollisionShape3D = c as CollisionShape3D
			for f: String in bands:
				_add_shape(floors[f], cs.shape, body_xf * cs.transform, bands[f], m)


func _add_gridmap(gm: GridMap, floors: Dictionary) -> void:
	var lib: MeshLibrary = gm.mesh_library
	if lib == null or (gm.collision_layer & (MASK_SOLID | MASK_WATER)) == 0:
		return
	var m: int = MASK_SOLID if (gm.collision_layer & MASK_SOLID) else MASK_WATER
	var gm_xf: Transform3D = WorldXform.to_root(gm)
	for cell: Vector3i in gm.get_used_cells():
		var item_id: int = gm.get_cell_item(cell)
		var shapes: Array = lib.get_item_shapes(item_id)
		if shapes.is_empty():
			continue
		var cell_xf: Transform3D = gm_xf * Transform3D(gm.get_cell_item_basis(cell), gm.map_to_local(cell))
		var i: int = 0
		while i + 1 < shapes.size():
			for f: String in bands:
				_add_shape(floors[f], shapes[i] as Shape3D, cell_xf * (shapes[i + 1] as Transform3D), bands[f], m)
			i += 2


func _r(v: float) -> float:
	return snappedf(v, 0.01)


func _count(k: String) -> void:
	_stats[k] = int(_stats.get(k, 0)) + 1


func _add_shape(dst: Dictionary, sh: Shape3D, t: Transform3D, band: Array, m: int) -> void:
	var b: Basis = t.basis
	var o: Vector3 = t.origin
	var y0: float = float(band[0])
	var y1: float = float(band[1])
	var vertical: bool = absf(b.y.normalized().dot(Vector3.UP)) > 0.995
	if sh is SphereShape3D:
		var r: float = (sh as SphereShape3D).radius * b.get_scale().x
		var dy: float = 0.0 if (o.y >= y0 and o.y <= y1) else minf(absf(o.y - y0), absf(o.y - y1))
		if dy >= r:
			return
		var rr: float = sqrt(r * r - dy * dy)
		if rr < 0.05:
			return
		dst["circles"].append([_r(o.x), _r(o.z), _r(rr), m])
		_count("sphere")
	elif sh is CylinderShape3D or sh is CapsuleShape3D:
		var r2: float
		var hh: float
		if sh is CylinderShape3D:
			r2 = (sh as CylinderShape3D).radius
			hh = (sh as CylinderShape3D).height * 0.5
		else:
			r2 = (sh as CapsuleShape3D).radius
			hh = (sh as CapsuleShape3D).height * 0.5
		if vertical:
			var hy: float = hh * b.y.length()
			if o.y + hy < y0 or o.y - hy > y1:
				return
			dst["circles"].append([_r(o.x), _r(o.z), _r(r2 * Vector2(b.x.x, b.x.z).length()), m])
			_count("cylinder")
		else:
			_box_like(dst, t, Vector3(r2, hh, r2), y0, y1, m, "cylinder_tilted")
	elif sh is BoxShape3D:
		_box_like(dst, t, (sh as BoxShape3D).size * 0.5, y0, y1, m, "box")
	elif sh is ConvexPolygonShape3D:
		var pts: Array[Vector3] = []
		for p: Vector3 in (sh as ConvexPolygonShape3D).points:
			pts.append(t * p)
		_hull(dst, pts, y0, y1, m, "convex")
	else:
		_count("unsupported_" + sh.get_class())


func _box_like(dst: Dictionary, t: Transform3D, h: Vector3, y0: float, y1: float, m: int, tag: String) -> void:
	var corners: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corners.append(t * Vector3(h.x * sx, h.y * sy, h.z * sz))
	var b: Basis = t.basis
	if absf(b.y.normalized().dot(Vector3.UP)) > 0.995:
		var top: float = t.origin.y + h.y * b.y.length()
		var bot: float = t.origin.y - h.y * b.y.length()
		if top < y0 or bot > y1:
			return
		var ax: Vector2 = Vector2(b.x.x, b.x.z)
		var az: Vector2 = Vector2(b.z.x, b.z.z)
		dst["boxes"].append([_r(t.origin.x), _r(t.origin.z), _r(h.x * ax.length()), _r(h.z * az.length()),
			snappedf(ax.angle(), 0.0001), m])
		_count(tag)
		return
	_hull(dst, corners, y0, y1, m, tag + "_hull")


func _hull(dst: Dictionary, pts: Array[Vector3], y0: float, y1: float, m: int, tag: String) -> void:
	var lo: float = INF
	var hi: float = -INF
	var flat: PackedVector2Array = PackedVector2Array()
	for p: Vector3 in pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
		flat.append(Vector2(p.x, p.z))
	if hi < y0 or lo > y1:
		return
	var hull: PackedVector2Array = Geometry2D.convex_hull(flat)
	if hull.size() < 4:   # convex_hull repete o primeiro ponto no fim
		return
	var row: Array = [m]
	for i in hull.size() - 1:
		row.append(_r(hull[i].x))
		row.append(_r(hull[i].y))
	dst["polys"].append(row)
	_count(tag)
