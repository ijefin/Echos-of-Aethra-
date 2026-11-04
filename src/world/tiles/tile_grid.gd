class_name TileGrid
extends RefCounted
## Matemática de grade compartilhada entre GridMap, PropScatter e ocupação.
## Convenção: células de `cell_size` metros; a célula (cx, cy, cz) cobre
## [cx*sx, (cx+1)*sx] em X (idem Z); `cell_to_world` devolve o CENTRO em XZ e a BASE em Y.

var cell_size: Vector3 = Vector3(2.0, 2.0, 2.0)


func _init(p_cell_size: Vector3 = Vector3(2.0, 2.0, 2.0)) -> void:
	cell_size = p_cell_size


## Centro da célula em XZ, base da célula em Y.
func cell_to_world(cell: Vector3i) -> Vector3:
	return Vector3((cell.x + 0.5) * cell_size.x, cell.y * cell_size.y, (cell.z + 0.5) * cell_size.z)


## Célula que contém o ponto do mundo.
func world_to_cell(point: Vector3) -> Vector3i:
	return Vector3i(floori(point.x / cell_size.x), floori(point.y / cell_size.y), floori(point.z / cell_size.z))


## Células (x, z) ocupadas por um footprint cujo canto mínimo é `origin`, após
## `quarter_turns` giros de 90 graus em torno do centro do footprint.
static func footprint_cells(origin: Vector2i, footprint: Vector2i, quarter_turns: int = 0) -> Array[Vector2i]:
	var size: Vector2i = footprint
	if posmod(quarter_turns, 2) == 1:
		size = Vector2i(footprint.y, footprint.x)
	var out: Array[Vector2i] = []
	for x in size.x:
		for z in size.y:
			out.append(origin + Vector2i(x, z))
	return out


## Células ocupadas por uma peça posicionada no mundo (centro do footprint = posição da peça).
func prop_cells(world_pos: Vector3, footprint: Vector2i, yaw: float = 0.0) -> Array[Vector2i]:
	var turns: int = posmod(roundi(yaw / (PI * 0.5)), 4)
	var size: Vector2i = footprint if posmod(turns, 2) == 0 else Vector2i(footprint.y, footprint.x)
	var corner: Vector3 = world_pos - Vector3(size.x * cell_size.x * 0.5, 0.0, size.y * cell_size.z * 0.5)
	var origin: Vector3i = world_to_cell(corner + Vector3(cell_size.x * 0.01, 0.0, cell_size.z * 0.01))
	return footprint_cells(Vector2i(origin.x, origin.z), footprint, turns)
