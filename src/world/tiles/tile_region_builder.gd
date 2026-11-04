class_name TileRegionBuilder
extends RefCounted
## Convenções e ajudantes de pintura de GridMap dentro de uma WorldRegion.
## Camadas (nós GridMap filhos da região): Ground (chão/estrada/praça, y=0),
## Walls (paredes e portas, y=0), Roofs (telhados, y=1). Todos usam a MESMA
## MeshLibrary e o mesmo `cell_size`. Uma parede "ao longo de X" é a orientação 0;
## paredes ao longo de Z usam giro de 90 graus em Y.

const LAYER_GROUND: StringName = &"Ground"
const LAYER_WALLS: StringName = &"Walls"
const LAYER_ROOFS: StringName = &"Roofs"

enum DoorSide { NORTH, SOUTH, EAST, WEST }


## Cria (ou reaproveita) o GridMap de camada `layer_name` filho de `region`.
static func ensure_layer(region: Node3D, layer_name: StringName, library: MeshLibrary, cell_size: Vector3) -> GridMap:
	var gm: GridMap = region.get_node_or_null(NodePath(layer_name)) as GridMap
	if gm == null:
		gm = GridMap.new()
		gm.name = layer_name
		region.add_child(gm)
		if region.owner != null:
			gm.owner = region.owner
		elif region.is_inside_tree() == false:
			gm.owner = region   # região ainda é raiz de cena
	gm.mesh_library = library
	gm.cell_size = cell_size
	gm.cell_center_y = false
	return gm


## Id do item pelo nome na biblioteca (-1 se não existir).
static func item(library: MeshLibrary, item_name: String) -> int:
	return library.find_item_by_name(item_name)


## Preenche um retângulo de células (x, z) no andar `y` com o item.
static func paint_rect(gm: GridMap, rect: Rect2i, item_id: int, y: int = 0) -> void:
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			gm.set_cell_item(Vector3i(x, y, z), item_id)


## Linha reta de células (horizontal ou vertical) — ruas e trilhas.
static func paint_line(gm: GridMap, from: Vector2i, to: Vector2i, item_id: int, y: int = 0) -> void:
	var step: Vector2i = Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var cur: Vector2i = from
	while true:
		gm.set_cell_item(Vector3i(cur.x, y, cur.y), item_id)
		if cur == to:
			break
		cur += step


## Monta uma casa modular: piso, paredes no contorno, porta num lado e telhado.
## `rect` em células. Devolve o rect para registrar na ocupação.
static func paint_house(layers: Dictionary, library: MeshLibrary, rect: Rect2i, door_side: DoorSide,
		names: Dictionary = {}) -> Rect2i:
	var floor_id: int = item(library, String(names.get("floor", "floor_wood")))
	var wall_id: int = item(library, String(names.get("wall", "wall")))
	var door_id: int = item(library, String(names.get("door", "door")))
	var roof_id: int = item(library, String(names.get("roof", "roof")))
	var ground: GridMap = layers[LAYER_GROUND]
	var walls: GridMap = layers[LAYER_WALLS]
	var roofs: GridMap = layers[LAYER_ROOFS]
	var along_x: int = walls.get_orthogonal_index_from_basis(Basis.IDENTITY)
	var along_z: int = walls.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI * 0.5))
	var last: Vector2i = rect.end - Vector2i.ONE
	var door_cell: Vector2i = _door_cell(rect, door_side)
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			var cell: Vector2i = Vector2i(x, z)
			ground.set_cell_item(Vector3i(x, 0, z), floor_id)
			roofs.set_cell_item(Vector3i(x, 1, z), roof_id)
			var on_edge: bool = x == rect.position.x or x == last.x or z == rect.position.y or z == last.y
			if not on_edge:
				continue
			var ori: int = along_x if (z == rect.position.y or z == last.y) else along_z
			walls.set_cell_item(Vector3i(x, 0, z), door_id if cell == door_cell else wall_id, ori)
	return rect


static func _door_cell(rect: Rect2i, side: DoorSide) -> Vector2i:
	var mid: Vector2i = rect.position + rect.size / 2
	match side:
		DoorSide.NORTH:
			return Vector2i(mid.x, rect.position.y)
		DoorSide.SOUTH:
			return Vector2i(mid.x, rect.end.y - 1)
		DoorSide.EAST:
			return Vector2i(rect.end.x - 1, mid.y)
		_:
			return Vector2i(rect.position.x, mid.y)


## Célula (x, y, z) de um ponto do mundo para o GridMap (considera a transformação dele).
static func world_to_cell(gm: GridMap, point: Vector3) -> Vector3i:
	return gm.local_to_map(WorldXform.to_root(gm).affine_inverse() * point)


## Centro (mundo) da célula do GridMap.
static func cell_to_world(gm: GridMap, cell: Vector3i) -> Vector3:
	return WorldXform.to_root(gm) * gm.map_to_local(cell)
