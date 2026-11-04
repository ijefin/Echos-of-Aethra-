class_name WorldIndex
extends RefCounted
## Índice puro (sem nós) dos marcadores de uma região. É a interface que IA,
## missões e servidor usam para saber ONDE as coisas estão — nada de coordenadas
## fixas em código. Funciona com a região dentro ou fora da árvore de cena.
##
## Cada marcador vira um Dictionary: {kind, id, position: Vector3, yaw: float, ...extras}.

## Dados da região: {region_id, display_name, danger_level, bounds: AABB, ambience}.
var region: Dictionary = {}
var _by_kind: Dictionary = {}


## Varre `root` (a própria WorldRegion ou qualquer subárvore) e monta o índice.
static func scan(root: Node) -> WorldIndex:
	var idx: WorldIndex = WorldIndex.new()
	if root is WorldRegion:
		var r: WorldRegion = root as WorldRegion
		idx.region = {"region_id": r.region_id, "display_name": r.display_name,
			"danger_level": r.danger_level, "bounds": r.get_world_bounds(), "ambience": r.ambience}
	for n: Node in WorldXform.all_nodes(root):
		if n is WorldMarker:
			idx.add(n as WorldMarker)
	return idx


## Registra um marcador no índice.
func add(marker: WorldMarker) -> void:
	var d: Dictionary = marker.to_dict()
	var kind: StringName = d["kind"]
	if not _by_kind.has(kind):
		_by_kind[kind] = [] as Array[Dictionary]
	(_by_kind[kind] as Array[Dictionary]).append(d)


## Tipos presentes (&"spawn", &"npc", &"secret", &"hunt", &"stair", &"landmark", &"quest").
func kinds() -> Array:
	return _by_kind.keys()


## Todos os marcadores de um tipo (cópia rasa; vazio se não houver).
func get_all(kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _by_kind.has(kind):
		out.assign(_by_kind[kind])
	return out


## Marcador por tipo e id; dicionário vazio se não existir.
func find(kind: StringName, id: StringName) -> Dictionary:
	for d: Dictionary in get_all(kind):
		if d["id"] == id:
			return d
	return {}


## Spawns de jogador (`side == &"player"`).
func player_spawns() -> Array[Dictionary]:
	return _spawns(&"player")


## Spawns de inimigos, opcionalmente filtrados por `enemy_kind`.
func enemy_spawns(enemy_kind: StringName = &"") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in _spawns(&"enemy"):
		if enemy_kind == &"" or d["enemy_kind"] == enemy_kind:
			out.append(d)
	return out


## Primeira área de caça que contém o ponto (plano XZ); vazio se nenhuma.
func hunt_area_at(point: Vector3) -> Dictionary:
	for d: Dictionary in get_all(&"hunt"):
		if HuntArea.contains_point(d, point):
			return d
	return {}


## Número total de marcadores.
func count() -> int:
	var n: int = 0
	for k: StringName in _by_kind:
		n += (_by_kind[k] as Array).size()
	return n


func _spawns(side: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in get_all(&"spawn"):
		if d["side"] == side:
			out.append(d)
	return out
