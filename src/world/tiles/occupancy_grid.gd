class_name OccupancyGrid
extends RefCounted
## Ocupação das células (x, z) por peças com `footprint`. Impede colocar duas
## coisas no mesmo lugar e responde "o que há nesta célula?".

var _cells: Dictionary = {}   # Vector2i -> StringName (dono)


## True se TODAS as células estão livres.
func can_place(cells: Array[Vector2i]) -> bool:
	for c: Vector2i in cells:
		if _cells.has(c):
			return false
	return true


## Ocupa as células para `owner_id`. Devolve false (sem alterar nada) se alguma estiver ocupada.
func place(owner_id: StringName, cells: Array[Vector2i]) -> bool:
	if not can_place(cells):
		return false
	for c: Vector2i in cells:
		_cells[c] = owner_id
	return true


## Libera todas as células do dono.
func clear(owner_id: StringName) -> void:
	for c: Vector2i in _cells.keys():
		if _cells[c] == owner_id:
			_cells.erase(c)


## Dono da célula, ou &"" se livre.
func owner_at(cell: Vector2i) -> StringName:
	return _cells.get(cell, &"")


func is_free(cell: Vector2i) -> bool:
	return not _cells.has(cell)


func occupied_count() -> int:
	return _cells.size()
