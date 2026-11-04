# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Colisão 2D (plano XZ) usada igualmente pelo servidor e pela predição do cliente.
## Obstáculos: círculos [x, z, r, m], caixas orientadas [cx, cz, hx, hz, yaw, m] e
## polígonos convexos [m, x0, z0, x1, z1, ...]. m = máscara (1 cenário, 4 água; padrão 1).
## Água bloqueia o andar mas não bloqueia tiro nem linha de visão (como no cliente:
## camada 4 = margens). Dados exportados do mundo do protótipo por
## `net/tools/export_collision.gd` (um objeto por andar: superfície e gruta "-1").

const CELL := 4.0
const SOLID := 1
const WATER := 4

var half := 60.0
var floor_y := 0.0
var circles: Array = []
var boxes: Array = []
var polys: Array = []          # PackedVector2Array
var _masks := [[], [], []]     # máscara por tipo/índice
var _grid: Dictionary = {}     # Vector2i → Array de [tipo, índice]


func _init(data: Dictionary = {}, world_half := 60.0) -> void:
	half = float(data.get("half", world_half))
	floor_y = float(data.get("y", 0.0))
	for c: Variant in data.get("circles", []):
		if c is Array and (c as Array).size() >= 3:
			add_circle(float(c[0]), float(c[1]), float(c[2]), int(c[3]) if c.size() > 3 else SOLID)
	for b: Variant in data.get("boxes", []):
		if b is Array and (b as Array).size() >= 5:
			add_box(float(b[0]), float(b[1]), float(b[2]), float(b[3]), float(b[4]), int(b[5]) if b.size() > 5 else SOLID)
	for p: Variant in data.get("polys", []):
		if p is Array and (p as Array).size() >= 7:
			var pts := PackedVector2Array()
			var i := 1
			while i + 1 < (p as Array).size():
				pts.append(Vector2(float(p[i]), float(p[i + 1])))
				i += 2
			add_poly(pts, int(p[0]))


static func _script() -> GDScript:
	return load("res://prototypes/pixel3d/net/world_collision.gd")


static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## Colisão da superfície (andar 0).
static func load_file(path: String, world_half := 60.0) -> RefCounted:
	return _script().new(_read(path), world_half)


## Todos os andares exportados: {0: superfície, -1: gruta, ...}.
static func load_floors(path: String, world_half := 60.0) -> Dictionary:
	var data := _read(path)
	var out := {0: _script().new(data, world_half)}
	var fl: Variant = data.get("floors", {})
	if fl is Dictionary:
		for k: Variant in fl:
			var d: Dictionary = (fl[k] as Dictionary).duplicate()
			d["half"] = float(data.get("half", world_half))
			out[int(String(k))] = _script().new(d, world_half)
	return out


func count() -> int:
	return circles.size() + boxes.size() + polys.size()


func add_circle(x: float, z: float, r: float, mask := SOLID) -> void:
	circles.append([x, z, r])
	_masks[0].append(mask)
	_index(0, circles.size() - 1, Vector2(x, z), r)


func add_box(cx: float, cz: float, hx: float, hz: float, yaw: float, mask := SOLID) -> void:
	boxes.append([cx, cz, hx, hz, yaw])
	_masks[1].append(mask)
	_index(1, boxes.size() - 1, Vector2(cx, cz), Vector2(hx, hz).length())


func add_poly(pts: PackedVector2Array, mask := SOLID) -> void:
	if pts.size() < 3:
		return
	var c := Vector2.ZERO
	for p: Vector2 in pts:
		c += p
	c /= float(pts.size())
	var r := 0.0
	for p: Vector2 in pts:
		r = maxf(r, c.distance_to(p))
	polys.append(pts)
	_masks[2].append(mask)
	_index(2, polys.size() - 1, c, r)


func _index(kind: int, i: int, c: Vector2, r: float) -> void:
	var lo := Vector2i(floori((c.x - r) / CELL), floori((c.y - r) / CELL))
	var hi := Vector2i(floori((c.x + r) / CELL), floori((c.y + r) / CELL))
	for gx in range(lo.x, hi.x + 1):
		for gz in range(lo.y, hi.y + 1):
			var k := Vector2i(gx, gz)
			if not _grid.has(k):
				_grid[k] = []
			(_grid[k] as Array).append([kind, i])


func _near(p: Vector2, r: float, mask := SOLID | WATER) -> Array:
	var seen := {}
	var out: Array = []
	var lo := Vector2i(floori((p.x - r) / CELL), floori((p.y - r) / CELL))
	var hi := Vector2i(floori((p.x + r) / CELL), floori((p.y + r) / CELL))
	for gx in range(lo.x, hi.x + 1):
		for gz in range(lo.y, hi.y + 1):
			for e: Array in _grid.get(Vector2i(gx, gz), []):
				if (int(_masks[int(e[0])][int(e[1])]) & mask) == 0:
					continue
				var key := int(e[0]) * 1000000 + int(e[1])
				if not seen.has(key):
					seen[key] = true
					out.append(e)
	return out


## Vetor para empurrar um círculo (p, r) para fora de um obstáculo; ZERO se não toca.
func _push(e: Array, p: Vector2, r: float) -> Vector2:
	var kind := int(e[0])
	if kind == 0:
		var c: Array = circles[int(e[1])]
		var d := p - Vector2(float(c[0]), float(c[1]))
		var min_d := r + float(c[2])
		var l := d.length()
		if l >= min_d:
			return Vector2.ZERO
		if l < 0.0001:
			return Vector2(min_d, 0)
		return d / l * (min_d - l)
	if kind == 2:
		return _push_poly(polys[int(e[1])], p, r)
	var b: Array = boxes[int(e[1])]
	var center := Vector2(float(b[0]), float(b[1]))
	var ext := Vector2(float(b[2]), float(b[3]))
	var local := (p - center).rotated(-float(b[4]))
	var closest := Vector2(clampf(local.x, -ext.x, ext.x), clampf(local.y, -ext.y, ext.y))
	var dl := local - closest
	var dist := dl.length()
	if dist >= r:
		return Vector2.ZERO
	var push_local: Vector2
	if dist > 0.0001:
		push_local = dl / dist * (r - dist)
	else:
		# centro dentro da caixa: sai pelo lado mais próximo
		var px := ext.x - absf(local.x) + r
		var pz := ext.y - absf(local.y) + r
		push_local = Vector2(px * signf(local.x if local.x != 0.0 else 1.0), 0) if px < pz else Vector2(0, pz * signf(local.y if local.y != 0.0 else 1.0))
	return push_local.rotated(float(b[4]))


func _push_poly(pts: PackedVector2Array, p: Vector2, r: float) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for i in pts.size():
		var cp := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % pts.size()])
		var d := p.distance_to(cp)
		if d < best_d:
			best_d = d
			best = cp
	if Geometry2D.is_point_in_polygon(p, pts):
		var out := best - p
		var l := out.length()
		return out + (out / l * r if l > 0.0001 else Vector2(r, 0))
	if best_d >= r:
		return Vector2.ZERO
	if best_d < 0.0001:
		return Vector2(r, 0)
	return (p - best) / best_d * (r - best_d)


## Posição corrigida para não atravessar obstáculos nem sair do mapa.
func resolve(p: Vector2, r: float) -> Vector2:
	var q := p
	for _i in 4:
		var moved := false
		for e: Array in _near(q, r + 2.0):
			var push := _push(e, q, r)
			if push != Vector2.ZERO:
				q += push
				moved = true
		if not moved:
			break
	var lim := half - r
	return Vector2(clampf(q.x, -lim, lim), clampf(q.y, -lim, lim))


func blocked(p: Vector2, r: float) -> bool:
	if absf(p.x) > half - r or absf(p.y) > half - r:
		return true
	for e: Array in _near(p, r + 2.0):
		if _push(e, p, r) != Vector2.ZERO:
			return true
	return false


## Linha de visão / trajetória de tiro: o segmento a→b (com folga `pad`) não cruza
## obstáculos da máscara (padrão: só cenário; água não bloqueia tiro).
func segment_clear(a: Vector2, b: Vector2, pad := 0.0, mask := SOLID) -> bool:
	var length := a.distance_to(b)
	var steps := maxi(1, ceili(length / 0.25))
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / float(steps))
		for e: Array in _near(p, pad + 2.0, mask):
			if _push(e, p, maxf(pad, 0.001)) != Vector2.ZERO:
				return false
	return true


## Altura do chão do andar (plano; a superfície é y = 0, a gruta y = -8).
func ground_y(_x: float, _z: float) -> float:
	return floor_y
