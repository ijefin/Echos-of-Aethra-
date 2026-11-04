# PROTOTYPE - NOT FOR PRODUCTION
extends SceneTree
## Exporta a colisão do mundo gerado do protótipo para o servidor dedicado:
##   godot --headless --path . -s res://prototypes/pixel3d/net/tools/export_collision.gd -- --no_save --mute
## Monta a cena do jogo (o gerador é determinístico: sementes fixas), percorre todos os
## StaticBody3D das camadas 1 (cenário) e 4 (margens d'água) e grava a pegada XZ de cada
## forma que cruza a faixa de altura do corpo do jogador em cada andar:
##   superfície  y ∈ [0,25; 1,6]      gruta (andar -1, y = -8)  y ∈ [-7,75; -6,4]
## Saída: net/data/collision_surface.json
##   {version, half, source, circles:[[x,z,r,m]], boxes:[[cx,cz,hx,hz,yaw,m]], polys:[[m,x0,z0,x1,z1,...]],
##    floors: {"-1": {y, circles, boxes, polys}}}
## m = máscara: 1 = cenário (bloqueia tudo), 4 = água (bloqueia andar, não bloqueia tiro).

const OUT := "res://prototypes/pixel3d/net/data/collision_surface.json"
const BANDS := {"0": [0.25, 1.6], "-1": [-7.75, -6.4]}
const FLOOR_Y := {"0": 0.0, "-1": -8.0}
const MASK := 1 | 4

var _stats := {}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var t0 := Time.get_ticks_msec()
	var demo: Node = (load("res://prototypes/pixel3d/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	if demo._adventure != null:
		demo._adventure._persist = false
	for i in 4:
		await physics_frame
	var floors := {}
	for f: String in BANDS:
		floors[f] = {"circles": [], "boxes": [], "polys": []}
	var bodies := 0
	for n: Node in _all(demo):
		if not (n is StaticBody3D):
			continue
		var body := n as StaticBody3D
		var layer := body.collision_layer & MASK
		if layer == 0:
			continue
		var m := 1 if (layer & 1) else 4
		bodies += 1
		for c: Node in body.get_children():
			if c is CollisionShape3D and not (c as CollisionShape3D).disabled and (c as CollisionShape3D).shape != null:
				for f: String in BANDS:
					_add(floors[f], c as CollisionShape3D, BANDS[f], m)
	var out := {"version": 2, "half": float(demo.HALF), "source": "pixel3d_demo.tscn (export_collision.gd)",
		"circles": floors["0"].circles, "boxes": floors["0"].boxes, "polys": floors["0"].polys, "floors": {}}
	for f: String in BANDS:
		if f != "0":
			var d: Dictionary = floors[f]
			d["y"] = FLOOR_Y[f]
			out.floors[f] = d
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(out))
	file.close()
	for f: String in BANDS:
		print("andar %s: %d círculos, %d caixas, %d polígonos" % [f, floors[f].circles.size(), floors[f].boxes.size(), floors[f].polys.size()])
	print("corpos lidos: %d; formas por tipo: %s" % [bodies, str(_stats)])
	print("EXPORT_COLLISION: OK -> %s (%d ms)" % [OUT, Time.get_ticks_msec() - t0])
	quit(0)


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		out.append(x)
		stack.append_array(x.get_children())
	return out


func _r(v: float) -> float:
	return snappedf(v, 0.01)


func _count(k: String) -> void:
	_stats[k] = int(_stats.get(k, 0)) + 1


## Pegada de uma forma no andar cuja faixa de altura é `band` = [y0, y1].
func _add(dst: Dictionary, cs: CollisionShape3D, band: Array, m: int) -> void:
	var t := cs.global_transform
	var b := t.basis
	var o := t.origin
	var y0 := float(band[0])
	var y1 := float(band[1])
	var up := b.y.normalized()
	var vertical := absf(up.dot(Vector3.UP)) > 0.995
	var sh := cs.shape
	if sh is SphereShape3D:
		var r := (sh as SphereShape3D).radius * b.get_scale().x
		var dy := 0.0 if (o.y >= y0 and o.y <= y1) else minf(absf(o.y - y0), absf(o.y - y1))
		if dy >= r:
			return
		var rr := sqrt(r * r - dy * dy)
		if rr < 0.05:
			return
		dst.circles.append([_r(o.x), _r(o.z), _r(rr), m])
		_count("sphere")
	elif sh is CylinderShape3D or sh is CapsuleShape3D:
		var r: float
		var hh: float
		if sh is CylinderShape3D:
			r = (sh as CylinderShape3D).radius
			hh = (sh as CylinderShape3D).height * 0.5
		else:
			r = (sh as CapsuleShape3D).radius
			hh = (sh as CapsuleShape3D).height * 0.5
		if vertical:
			var hy := hh * b.y.length()
			if o.y + hy < y0 or o.y - hy > y1:
				return
			dst.circles.append([_r(o.x), _r(o.z), _r(r * Vector2(b.x.x, b.x.z).length()), m])
			_count("cylinder")
		else:
			_box_like(dst, t, Vector3(r, hh, r), y0, y1, m, "cylinder_tilted")
	elif sh is BoxShape3D:
		_box_like(dst, t, (sh as BoxShape3D).size * 0.5, y0, y1, m, "box")
	elif sh is ConvexPolygonShape3D:
		var pts: Array[Vector3] = []
		for p: Vector3 in (sh as ConvexPolygonShape3D).points:
			pts.append(t * p)
		_hull(dst, pts, y0, y1, m, "convex")
	else:
		_count("unsupported_" + sh.get_class())


## Caixa (ou cilindro/cápsula deitados, aproximados pela caixa que os envolve).
func _box_like(dst: Dictionary, t: Transform3D, h: Vector3, y0: float, y1: float, m: int, tag: String) -> void:
	var corners: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corners.append(t * Vector3(h.x * sx, h.y * sy, h.z * sz))
	var b := t.basis
	if absf(b.y.normalized().dot(Vector3.UP)) > 0.995:
		var top := t.origin.y + h.y * b.y.length()
		var bot := t.origin.y - h.y * b.y.length()
		if top < y0 or bot > y1:
			return
		var ax := Vector2(b.x.x, b.x.z)
		var az := Vector2(b.z.x, b.z.z)
		dst.boxes.append([_r(t.origin.x), _r(t.origin.z), _r(h.x * ax.length()), _r(h.z * az.length()),
			snappedf(ax.angle(), 0.0001), m])
		_count(tag)
		return
	_hull(dst, corners, y0, y1, m, tag + "_hull")


## Envoltória convexa da projeção XZ (formas inclinadas): conservadora, bloqueia um pouco a mais.
func _hull(dst: Dictionary, pts: Array[Vector3], y0: float, y1: float, m: int, tag: String) -> void:
	var lo := INF
	var hi := -INF
	var flat := PackedVector2Array()
	for p: Vector3 in pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
		flat.append(Vector2(p.x, p.z))
	if hi < y0 or lo > y1:
		return
	var hull := Geometry2D.convex_hull(flat)
	if hull.size() < 4:   # convex_hull repete o primeiro ponto no fim
		return
	var row: Array = [m]
	for i in hull.size() - 1:
		row.append(_r(hull[i].x))
		row.append(_r(hull[i].y))
	dst.polys.append(row)
	_count(tag)
