extends RefCounted
## Percepção dos monstros: linha de visão (raio na camada do cenário) e escolha de alvo.
## Funções puras sobre um `PhysicsDirectSpaceState3D` — rodam igual no cliente e no servidor.

const EYE := 0.6  # altura dos olhos do monstro
const CHEST := 0.8  # altura do centro do alvo

static var _ray := PhysicsRayQueryParameters3D.new()
static var rays := 0


## Há visão livre de `from` (pé do monstro) até `to` (pé do alvo)? `exclude` = corpos ignorados.
static func line_of_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID], mask := 1) -> bool:
	if space == null:
		return true
	_ray.from = from + Vector3(0, EYE, 0)
	_ray.to = to + Vector3(0, CHEST, 0)
	_ray.collision_mask = mask
	_ray.exclude = exclude
	_ray.collide_with_areas = false
	rays += 1
	return space.intersect_ray(_ray).is_empty()


## Alvo mais próximo, do mesmo andar, dentro de `radius`, que não esteja em zona segura.
## `candidates` são dicionários {id, pos, node?, safe?}.
static func nearest(candidates: Array, at: Vector3, radius: float, floor_tolerance := 2.5) -> Dictionary:
	var best: Dictionary = {}
	var best_d := radius
	for t: Dictionary in candidates:
		if t.get("safe", false):
			continue
		var p: Vector3 = t.pos
		if absf(p.y - at.y) > floor_tolerance:
			continue
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d <= best_d:
			best_d = d
			best = t
	return best


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
