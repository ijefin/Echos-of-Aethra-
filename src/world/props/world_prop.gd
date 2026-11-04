@tool
class_name WorldProp
extends Node3D
## Peça posicionável do mundo (árvore, pedra, parede, porta, móvel...).
## Contrato com a arte: cada peça é uma cena com raiz WorldProp em
## `res://assets/world/props/<categoria>/<nome>.tscn`.
## - Variantes: filhos chamados `Variant0..N`; só o de índice `variant` fica visível.
## - Colisão: se a cena tiver um StaticBody3D filho, ele é usado (camada 1 quando
##   `blocks_movement`, senão camada 0). Sem ele, uma caixa baseada na malha é criada.

## Lado, em metros, de uma célula da grade usada para calcular a colisão automática.
const GRID_CELL: float = 1.0
## Camada física do cenário sólido.
const LAYER_SOLID: int = 1

@export var prop_id: StringName = &""
## Categoria: &"tree", &"rock", &"wall", &"roof", &"floor", &"door", &"furniture", &"decor"...
@export var category: StringName = &"decor"
## Células da grade ocupadas (largura em X, profundidade em Z).
@export var footprint: Vector2i = Vector2i.ONE
@export var blocks_movement: bool = true:
	set(value):
		blocks_movement = value
		if is_node_ready():
			_ensure_collision()
@export var variant: int = 0:
	set(value):
		variant = value
		if is_node_ready():
			_apply_variant()
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		if is_node_ready():
			_apply_tint()


func _ready() -> void:
	_apply_variant()
	_apply_tint()
	_ensure_collision()


## Aplica um WorldStyle (troca de materiais) e reaplica a cor `tint` por cima.
func apply_style(style: WorldStyle) -> void:
	if style != null:
		style.apply_to_prop(self)
	_apply_tint()


## Quantidade de variantes visuais (filhos `Variant*`); 0 se a peça não tem variantes.
func get_variant_count() -> int:
	var n: int = 0
	for c: Node in get_children():
		if String(c.name).begins_with("Variant"):
			n += 1
	return n


## Resumo serializável da peça (usado por índices e ferramentas).
func to_dict() -> Dictionary:
	return {"prop_id": prop_id, "category": category, "footprint": footprint,
		"blocks_movement": blocks_movement, "variant": variant}


func _apply_variant() -> void:
	var count: int = get_variant_count()
	if count == 0:
		return
	var active: int = posmod(variant, count)
	for c: Node in get_children():
		if String(c.name).begins_with("Variant") and c is Node3D:
			(c as Node3D).visible = String(c.name) == "Variant%d" % active


func _apply_tint() -> void:
	for n: Node in WorldXform.all_nodes(self):
		if not (n is MeshInstance3D):
			continue
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var key: StringName = StringName("_wp_base_%d" % s)
			if not mi.has_meta(key):
				mi.set_meta(key, mi.get_active_material(s))
			var base: Material = mi.get_meta(key) as Material
			if tint == Color.WHITE:
				mi.set_surface_override_material(s, null)
			elif base is BaseMaterial3D:
				var m: BaseMaterial3D = (base as BaseMaterial3D).duplicate() as BaseMaterial3D
				m.albedo_color = m.albedo_color * tint
				mi.set_surface_override_material(s, m)


func _ensure_collision() -> void:
	var body: StaticBody3D = null
	for c: Node in get_children():
		if c is StaticBody3D:
			body = c as StaticBody3D
			break
	if body != null:
		body.collision_layer = LAYER_SOLID if blocks_movement else 0
		return
	if not blocks_movement:
		return
	var box: AABB = _local_aabb()
	var size: Vector3 = Vector3(footprint.x * GRID_CELL, maxf(box.size.y, 0.1), footprint.y * GRID_CELL)
	body = StaticBody3D.new()
	body.name = &"AutoCollision"
	body.collision_layer = LAYER_SOLID
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = Vector3(0.0, box.position.y + box.size.y * 0.5, 0.0)
	body.add_child(cs)
	add_child(body)   # sem owner: não é salvo na cena, é recriado a cada carga


func _local_aabb() -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for n: Node in WorldXform.all_nodes(self):
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
			var mi: MeshInstance3D = n as MeshInstance3D
			var box: AABB = WorldXform.to_root(mi, self) * mi.get_aabb()
			result = box if first else result.merge(box)
			first = false
	return result
