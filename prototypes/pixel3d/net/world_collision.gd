# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Colisão 2D (plano XZ) usada igualmente pelo servidor e pela predição do cliente.
## Obstáculos: círculos [x, z, r] e caixas orientadas [cx, cz, hx, hz, yaw].
## Dados exportados do mundo do protótipo por `net/tools/export_collision.gd`.

const CELL := 4.0

var half := 60.0
var circles: Array = []
var boxes: Array = []
var _grid: Dictionary = {}   # Vector2i → Array de [tipo, índice]


func _init(data: Dictionary = {}, world_half := 60.0) -> void:
	half = float(data.get("half", world_half))
	for c: Variant in data.get("circles", []):
		if c is Array and (c as Array).size() >= 3:
			add_circle(float(c[0]), float(c[1]), float(c[2]))
	for b: Variant in data.get("boxes", []):
		if b is Array and (b as Array).size() >= 5:
			add_box(float(b[0]), float(b[1]), float(b[2]), float(b[3]), float(b[4]))


static func load_file(path: String, world_half := 60.0) -> RefCounted:
	var script: GDScript = load("res://prototypes/pixel3d/net/world_collision.gd")
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return script.new({}, world_half)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return script.new(parsed if parsed is Dictionary else {}, world_half)


func add_circle(x: float, z: float, r: float) -> void:
	circles.append([x, z, r])
	_index(0, circles.size() - 1, Vector2(x, z), r)


func add_box(cx: float, cz: float, hx: float, hz: float, yaw: float) -> void:
	boxes.append([cx, cz, hx, hz, yaw])
	_index(1, boxes.size() - 1, Vector2(cx, cz), Vector2(hx, hz).length())


func _index(kind: int, i: int, c: Vector2, r: float) -> void:
	var lo := Vector2i(floori((c.x - r) / CELL), floori((c.y - r) / CELL))
	var hi := Vector2i(floori((c.x + r) / CELL), floori((c.y + r) / CELL))
	for gx in range(lo.x, hi.x + 1):
		for gz in range(lo.y, hi.y + 1):
			var k := Vector2i(gx, gz)
			if not _grid.has(k):
				_grid[k] = []
			(_grid[k] as Array).append([kind, i])


func _near(p: Vector2, r: float) -> Array:
	var seen := {}
	var out: Array = []
	var lo := Vector2i(floori((p.x - r) / CELL), floori((p.y - r) / CELL))
	var hi := Vector2i(floori((p.x + r) / CELL), floori((p.y + r) / CELL))
	for gx in range(lo.x, hi.x + 1):
		for gz in range(lo.y, hi.y + 1):
			for e: Array in _grid.get(Vector2i(gx, gz), []):
				var key := int(e[0]) * 1000000 + int(e[1])
				if not seen.has(key):
					seen[key] = true
					out.append(e)
	return out


## Vetor para empurrar um círculo (p, r) para fora de um obstáculo; ZERO se não toca.
func _push(e: Array, p: Vector2, r: float) -> Vector2:
	if int(e[0]) == 0:
		var c: Array = circles[int(e[1])]
		var d := p - Vector2(float(c[0]), float(c[1]))
		var min_d := r + float(c[2])
		var l := d.length()
		if l >= min_d:
			return Vector2.ZERO
		if l < 0.0001:
			return Vector2(min_d, 0)
		return d / l * (min_d - l)
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


## Posição corrigida para não atravessar obstáculos nem sair do mapa.
func resolve(p: Vector2, r: float) -> Vector2:
	var q := p
	for _i in 3:
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


## Linha de visão: o segmento a→b (com folga `pad`) não cruza obstáculos.
func segment_clear(a: Vector2, b: Vector2, pad := 0.0) -> bool:
	var length := a.distance_to(b)
	var steps := maxi(1, ceili(length / 0.25))
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / float(steps))
		for e: Array in _near(p, pad + 2.0):
			if _push(e, p, maxf(pad, 0.001)) != Vector2.ZERO:
				return false
	return true


## Altura do chão (superfície plana no protótipo; andares/gruta ficam para depois).
func ground_y(_x: float, _z: float) -> float:
	return 0.0
