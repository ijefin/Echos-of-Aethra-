class_name WorldStyle
extends Resource
## Estilo visual do mundo: troca materiais na carga das peças e regiões.
## O jogo injeta uma subclasse (ex.: pixel-art/toon); o módulo de mundo não conhece
## shaders. A implementação padrão é um no-op, então o mundo funciona sem estilo.


## Ajusta um MeshInstance3D (trocar/derivar materiais). Padrão: não faz nada.
func apply_to_mesh(_mesh: MeshInstance3D) -> void:
	pass


## Ajusta uma MeshLibrary (peças de GridMap). Atenção: muda a biblioteca compartilhada.
func apply_to_library(_library: MeshLibrary) -> void:
	pass


## Aplica o estilo em toda a subárvore: MeshInstance3D e GridMap.
func apply_to_tree(root: Node) -> void:
	for n: Node in WorldXform.all_nodes(root):
		if n is MeshInstance3D:
			apply_to_mesh(n as MeshInstance3D)
		elif n is GridMap and (n as GridMap).mesh_library != null:
			apply_to_library((n as GridMap).mesh_library)


## Aplica o estilo a uma peça (WorldProp). Subclasses podem sobrescrever.
func apply_to_prop(prop: Node3D) -> void:
	apply_to_tree(prop)
