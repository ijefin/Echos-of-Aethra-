# PROTOTYPE - NOT FOR PRODUCTION
# Pedaços de 20×20 m: tudo que é estático (chão, grama, flores, árvores, rochas, marcos)
# fica num nó por pedaço, e só os pedaços que cabem na tela (+ margem) ficam visíveis.
# Colisão não depende de visibilidade, então física e IA continuam valendo no mapa todo.
extends RefCounted

const SIZE := 20.0
const EXTENT := 120.0  # cobre o mapa (±100) e a faixa de mata além da borda

var root: Node3D
var _chunks := {}
var visible_count := 0
var _last := Vector4(INF, INF, INF, INF)


func setup(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "Chunks"
	parent.add_child(root)


func key(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x + EXTENT) / SIZE), floori((p.y + EXTENT) / SIZE))


## Nó do pedaço que contém p (cria na primeira vez). Filhos usam coordenada de mundo.
func node_at(p: Vector2) -> Node3D:
	var k := key(p)
	if not _chunks.has(k):
		var n := Node3D.new()
		n.name = "C%d_%d" % [k.x, k.y]
		root.add_child(n)
		_chunks[k] = n
	return _chunks[k]


func node_at3(p: Vector3) -> Node3D:
	return node_at(Vector2(p.x, p.z))


func count() -> int:
	return _chunks.size()


## Mostra só os pedaços dentro do retângulo [center - half_w, center + half_w] em x e
## [center - back, center + fwd] em z (a serra alta ao norte aparece de mais longe).
func update(center: Vector3, half_w: float, back: float, fwd: float) -> void:
	var box := Vector4(center.x - half_w, center.z - fwd, center.x + half_w, center.z + back)
	if absf(box.x - _last.x) < 2.0 and absf(box.y - _last.y) < 2.0 and absf(box.z - _last.z) < 2.0 and absf(box.w - _last.w) < 2.0:
		return
	_last = box
	visible_count = 0
	for k: Vector2i in _chunks:
		var x0 := -EXTENT + k.x * SIZE
		var z0 := -EXTENT + k.y * SIZE
		var on := x0 + SIZE > box.x and x0 < box.z and z0 + SIZE > box.y and z0 < box.w
		(_chunks[k] as Node3D).visible = on
		if on:
			visible_count += 1
