# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Grade de navegação de UM andar (plano em `base_y`) com A* de 8 direções.
## Células bloqueadas são descobertas sob demanda, por blocos de CHUNK×CHUNK células,
## consultando colisores (camada 1 = cenário, 4 = margens d'água) com `intersect_shape`
## numa faixa acima do piso. Cada bloco é subdividido como quadtree: área livre custa
## uma consulta só. O resultado fica em cache até `invalidate()`.

const CHUNK := 16
const SQRT2 := 1.41421356

var cell := 0.5
var base_y := 0.0
var mask := 1 | 4
var clearance := 0.3
var max_expand := 1600
var space: PhysicsDirectSpaceState3D
## Corpos dinâmicos que NÃO bloqueiam a grade (ex.: jogadores, que estão na camada 1).
var exclude: Array[RID] = []
var queries := 0
var last_partial := false

var _chunks := {}  # Vector2i -> PackedByteArray (1 = bloqueado)
var _shape := BoxShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()


func _init(floor_y := 0.0, cell_size := 0.5, clearance_radius := 0.3, collision_mask := 1 | 4) -> void:
	base_y = floor_y
	cell = cell_size
	clearance = clearance_radius
	mask = collision_mask
	_query.shape = _shape
	_query.collision_mask = mask
	_query.collide_with_areas = false


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.z / cell))


func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * cell, base_y, (c.y + 0.5) * cell)


## Apaga o cache dos blocos que tocam o círculo (obstáculo novo/removido).
func invalidate(center: Vector3, radius: float) -> void:
	var span := CHUNK * cell
	for x in range(floori((center.x - radius) / span), floori((center.x + radius) / span) + 1):
		for z in range(floori((center.z - radius) / span), floori((center.z + radius) / span) + 1):
			_chunks.erase(Vector2i(x, z))


func invalidate_all() -> void:
	_chunks.clear()


func is_blocked_at(p: Vector3) -> bool:
	return blocked(world_to_cell(p))


func blocked(c: Vector2i) -> bool:
	var ck := Vector2i(floori(float(c.x) / CHUNK), floori(float(c.y) / CHUNK))
	var data: PackedByteArray
	if _chunks.has(ck):
		data = _chunks[ck]
	else:
		data = _build_chunk(ck)
	return data[(c.x - ck.x * CHUNK) + (c.y - ck.y * CHUNK) * CHUNK] == 1


func _build_chunk(ck: Vector2i) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(CHUNK * CHUNK)
	data.fill(0)
	if space != null:
		_query.exclude = exclude
		_fill(data, ck, 0, 0, CHUNK)
	_chunks[ck] = data
	return data


## Quadtree: consulta a região inteira; só subdivide onde há colisor.
func _fill(data: PackedByteArray, ck: Vector2i, x0: int, z0: int, size: int) -> void:
	var half := size * cell * 0.5
	_shape.size = Vector3(half * 2.0 + clearance * 2.0, 0.9, half * 2.0 + clearance * 2.0)
	var origin := Vector3((ck.x * CHUNK + x0) * cell + half, base_y + 0.8, (ck.y * CHUNK + z0) * cell + half)
	_query.transform = Transform3D(Basis.IDENTITY, origin)
	queries += 1
	if space.intersect_shape(_query, 1).is_empty():
		return
	if size == 1:
		data[x0 + z0 * CHUNK] = 1
		return
	var h := size / 2
	_fill(data, ck, x0, z0, h)
	_fill(data, ck, x0 + h, z0, h)
	_fill(data, ck, x0, z0 + h, h)
	_fill(data, ck, x0 + h, z0 + h, h)


## Célula livre mais próxima de `c` dentro de `radius` células (ou `c` se nenhuma).
func nearest_free(c: Vector2i, radius: int) -> Vector2i:
	if not blocked(c):
		return c
	for r in range(1, radius + 1):
		for dx in range(-r, r + 1):
			for dz in [-r, r]:
				var n := c + Vector2i(dx, dz)
				if not blocked(n):
					return n
		for dz in range(-r + 1, r):
			for dx in [-r, r]:
				var n := c + Vector2i(dx, dz)
				if not blocked(n):
					return n
	return c


## Segmento livre na grade (amostrado a meia célula).
func line_clear(a: Vector3, b: Vector3) -> bool:
	var flat := Vector2(b.x - a.x, b.z - a.z)
	var steps := maxi(1, ceili(flat.length() / (cell * 0.5)))
	for i in steps + 1:
		var k := float(i) / steps
		if blocked(Vector2i(floori((a.x + flat.x * k) / cell), floori((a.z + flat.y * k) / cell))):
			return false
	return true


## Caminho de `from` até `to` (pontos no mundo, sem o ponto de partida).
## Sem caminho completo dentro de `max_expand`: devolve o trecho até a célula mais próxima
## do destino e marca `last_partial`.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	last_partial = false
	var out := PackedVector3Array()
	var s := nearest_free(world_to_cell(from), 2)
	var goal_cell := world_to_cell(to)
	var g := nearest_free(goal_cell, 3)
	var goal_point := Vector3(to.x, base_y, to.z) if g == goal_cell else cell_center(g)
	if blocked(g):
		last_partial = true
	if s == g or line_clear(cell_center(s), goal_point):
		out.append(goal_point)
		return out
	# A* com heap binário (f em PackedFloat32Array, células em Array paralelo)
	var heap_f := PackedFloat32Array()
	var heap_c: Array[Vector2i] = []
	var gscore := {s: 0.0}
	var came := {}
	var closed := {}
	var best := s
	var best_h := _h(s, g)
	_push(heap_f, heap_c, best_h, s)
	var expanded := 0
	var found := false
	while not heap_c.is_empty():
		var cur: Vector2i = _pop(heap_f, heap_c)
		if closed.has(cur):
			continue
		if cur == g:
			found = true
			break
		closed[cur] = true
		expanded += 1
		if expanded > max_expand:
			break
		var gc: float = gscore[cur]
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var n := cur + Vector2i(dx, dz)
				if closed.has(n) or blocked(n):
					continue
				if dx != 0 and dz != 0 and (blocked(cur + Vector2i(dx, 0)) or blocked(cur + Vector2i(0, dz))):
					continue  # não corta quina
				var ng := gc + (SQRT2 if dx != 0 and dz != 0 else 1.0)
				if ng < float(gscore.get(n, INF)):
					gscore[n] = ng
					came[n] = cur
					var h := _h(n, g)
					if h < best_h:
						best_h = h
						best = n
					_push(heap_f, heap_c, ng + h, n)
	var end := g if found else best
	if not found:
		last_partial = true
	var cells: Array[Vector2i] = [end]
	while came.has(cells[-1]):
		cells.append(came[cells[-1]])
	cells.reverse()  # s ... end
	# suavização (puxa o barbante): pula para o ponto visível mais distante
	var i := 0
	var cur_point := cell_center(s)
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not line_clear(cur_point, cell_center(cells[j])):
			j -= 1
		cur_point = cell_center(cells[j])
		out.append(cur_point)
		i = j
	if found:
		if out.is_empty():
			out.append(goal_point)
		else:
			out[out.size() - 1] = goal_point
	return out


func _h(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dz := absi(a.y - b.y)
	return float(maxi(dx, dz)) + (SQRT2 - 1.0) * float(mini(dx, dz))


func _push(hf: PackedFloat32Array, hc: Array[Vector2i], f: float, c: Vector2i) -> void:
	hf.append(f)
	hc.append(c)
	var i := hf.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if hf[p] <= hf[i]:
			break
		var tf := hf[p]
		hf[p] = hf[i]
		hf[i] = tf
		var tc := hc[p]
		hc[p] = hc[i]
		hc[i] = tc
		i = p


func _pop(hf: PackedFloat32Array, hc: Array[Vector2i]) -> Vector2i:
	var top := hc[0]
	var last := hf.size() - 1
	hf[0] = hf[last]
	hc[0] = hc[last]
	hf.resize(last)
	hc.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < last and hf[l] < hf[m]:
			m = l
		if r < last and hf[r] < hf[m]:
			m = r
		if m == i:
			break
		var tf := hf[m]
		hf[m] = hf[i]
		hf[i] = tf
		var tc := hc[m]
		hc[m] = hc[i]
		hc[i] = tc
		i = m
	return top
