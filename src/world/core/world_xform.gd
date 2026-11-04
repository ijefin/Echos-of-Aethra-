class_name WorldXform
extends RefCounted
## Utilitário de transformações que funciona com nós FORA da árvore de cena
## (servidor, testes headless, ferramentas): acumula as transformações locais
## em vez de depender de `global_transform`, que exige o nó na árvore.


## Transformação de `node` no espaço de `stop` (exclusive). Com `stop == null`
## acumula toda a cadeia de pais até a raiz.
static func to_root(node: Node3D, stop: Node = null) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != stop:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## Todos os descendentes de `root` (inclusive ele), em profundidade, sem recursão.
static func all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		var kids: Array[Node] = n.get_children()
		kids.reverse()
		stack.append_array(kids)
	return out
