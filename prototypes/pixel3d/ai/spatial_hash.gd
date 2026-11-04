# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Grade de hashing espacial no plano XZ: vizinhos e alvos sem varrer todos contra todos.
## Reconstruída a cada quadro (inserir é O(1)); a consulta devolve candidatos das células
## que cobrem o raio — quem chama filtra pela distância exata.

var cell := 2.0
var _cells := {}  # Vector2i -> Array


func _init(cell_size := 2.0) -> void:
	cell = cell_size


## Esvazia a grade (chamar antes de reinserir no quadro).
func clear() -> void:
	_cells.clear()


## Insere `item` na célula de `pos`.
func insert(item: Variant, pos: Vector3) -> void:
	var k := Vector2i(floori(pos.x / cell), floori(pos.z / cell))
	if _cells.has(k):
		(_cells[k] as Array).append(item)
	else:
		_cells[k] = [item]


## Candidatos nas células que tocam o círculo (`pos`, `radius`).
func query(pos: Vector3, radius: float) -> Array:
	var out: Array = []
	var x0 := floori((pos.x - radius) / cell)
	var x1 := floori((pos.x + radius) / cell)
	var z0 := floori((pos.z - radius) / cell)
	var z1 := floori((pos.z + radius) / cell)
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var k := Vector2i(x, z)
			if _cells.has(k):
				out.append_array(_cells[k])
	return out
