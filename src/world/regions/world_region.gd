@tool
class_name WorldRegion
extends Node3D
## Raiz de cena de uma região do mundo. Convenção de filhos:
##   Ground / Walls / Roofs  GridMap (chão, paredes, telhados)
##   Props                   Node3D com WorldProp (assados à mão ou por PropScatter)
##   Markers                 Node3D com WorldMarker (SpawnPoint, NpcSpot, ...)
## O servidor, a IA e as missões leem a região pelo WorldIndex, nunca por caminhos fixos.

@export var region_id: StringName = &""
@export var display_name: String = ""
@export_range(0, 100, 1) var danger_level: int = 0
## Limites da região, em coordenadas LOCAIS da região (centro + tamanho).
@export var bounds: AABB = AABB(Vector3(-50.0, -10.0, -50.0), Vector3(100.0, 40.0, 100.0)):
	set(value):
		bounds = value
		if is_node_ready() and Engine.is_editor_hint():
			_rebuild_debug_bounds()
## Id da ambiência (trilha/sons) — resolvido pelo sistema de áudio, não aqui.
@export var ambience: StringName = &""


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_debug_bounds()


## Limites no espaço do mundo (aplica posição da região; rotações são ignoradas).
func get_world_bounds() -> AABB:
	return AABB(bounds.position + WorldXform.to_root(self).origin, bounds.size)


## Índice de marcadores desta região (atalho para `WorldIndex.scan(self)`).
func build_index() -> WorldIndex:
	return WorldIndex.scan(self)


func _rebuild_debug_bounds() -> void:
	var old: Node = get_node_or_null("_DebugBounds")
	if old != null:
		old.free()
	var a: Vector3 = bounds.position
	var b: Vector3 = bounds.end
	var corners: Array[Vector3] = []
	for x in [a.x, b.x]:
		for y in [a.y, b.y]:
			for z in [a.z, b.z]:
				corners.append(Vector3(x, y, z))
	var pairs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 4), Vector2i(1, 3), Vector2i(1, 5),
		Vector2i(2, 3), Vector2i(2, 6), Vector2i(3, 7), Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 7), Vector2i(6, 7)]
	var pts: PackedVector3Array = PackedVector3Array()
	for p: Vector2i in pairs:
		pts.append(corners[p.x])
		pts.append(corners[p.y])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 1.0, 0.6)
	mesh.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = &"_DebugBounds"
	mi.mesh = mesh
	add_child(mi)   # sem owner: só no editor
