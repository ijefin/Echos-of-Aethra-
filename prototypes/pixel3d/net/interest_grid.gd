# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Área de interesse: grade espacial (XZ) + histerese (entra a `enter_m`, sai a `leave_m`)
## + prioridade (jogadores > monstros > projéteis, depois distância) com teto por snapshot.

var cell := 16.0
var enter_m := 40.0
var leave_m := 48.0
var max_entities := 48
## Diferença de altura que separa andares (superfície y=0, gruta y=-8).
const FLOOR_GAP := 4.0
var _grid: Dictionary = {}       # Vector2i → Array[int] (ids)
var _pos: Dictionary = {}        # id → Vector3
var _tier: Dictionary = {}       # id → int (0 = mais importante)
var known: Dictionary = {}       # observador → {id: true}


func _init(cfg: Dictionary = {}) -> void:
	cell = float(cfg.get("interest_cell_m", cell))
	enter_m = float(cfg.get("interest_enter_m", enter_m))
	leave_m = float(cfg.get("interest_leave_m", leave_m))
	max_entities = int(cfg.get("max_snapshot_entities", max_entities))


func clear() -> void:
	_grid.clear()
	_pos.clear()
	_tier.clear()


func put(id: int, pos: Vector3, tier: int) -> void:
	_pos[id] = pos
	_tier[id] = tier
	var k := Vector2i(floori(pos.x / cell), floori(pos.z / cell))
	if not _grid.has(k):
		_grid[k] = []
	(_grid[k] as Array).append(id)


## Ids visíveis para `observer` (que está em `at`), já ordenados por prioridade.
## Devolve {visible: Array[int], entered: Array[int], left: Array[int]}.
func query(observer: int, at: Vector3) -> Dictionary:
	var was: Dictionary = known.get(observer, {})
	var cand: Array = []
	var r := ceili(leave_m / cell)
	var c := Vector2i(floori(at.x / cell), floori(at.z / cell))
	for gx in range(c.x - r, c.x + r + 1):
		for gz in range(c.y - r, c.y + r + 1):
			for id: int in _grid.get(Vector2i(gx, gz), []):
				if id == observer:
					continue
				var p: Vector3 = _pos[id]
				if absf(p.y - at.y) > FLOOR_GAP:
					continue   # outro andar (gruta 8 m abaixo): não aparece, como no Tibia
				var d := Vector2(p.x - at.x, p.z - at.z).length()
				if d <= enter_m or (was.has(id) and d <= leave_m):
					cand.append([int(_tier[id]), d, id])
	cand.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var now_known := {}
	var vis: Array[int] = []
	var entered: Array[int] = []
	for e: Array in cand:
		if vis.size() >= max_entities:
			break
		var id := int(e[2])
		vis.append(id)
		now_known[id] = true
		if not was.has(id):
			entered.append(id)
	var left: Array[int] = []
	for id: int in was:
		if not now_known.has(id):
			left.append(id)
	known[observer] = now_known
	return {"visible": vis, "entered": entered, "left": left}


func forget(observer: int) -> void:
	known.erase(observer)
	for o: int in known:
		(known[o] as Dictionary).erase(observer)
