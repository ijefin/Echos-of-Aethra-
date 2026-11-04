@tool
class_name WorldMarker
extends Node3D
## Base dos marcadores editáveis de uma região (spawns, NPCs, segredos, áreas de caça...).
## No editor mostra um gizmo de debug (esfera + rótulo); em jogo é invisível.
## IA, missões e servidor NÃO usam coordenadas fixas: consultam o WorldIndex,
## que lê estes nós via `to_dict()`.

## Tipo do marcador (chave usada no WorldIndex). Subclasses sobrescrevem.
func get_kind() -> StringName:
	return &"marker"


## Identificador do marcador dentro da região. Padrão: nome do nó.
func get_marker_id() -> StringName:
	return StringName(name)


## Dados específicos do tipo (somados ao dicionário base). Subclasses sobrescrevem.
func get_extra() -> Dictionary:
	return {}


## Cor do gizmo de debug no editor.
func get_debug_color() -> Color:
	return Color(1.0, 0.9, 0.2)


## Dicionário consumido pelo WorldIndex. `position` e `yaw` são no espaço do mundo
## (cadeia de transformações até a raiz da cena), mesmo fora da árvore.
func to_dict() -> Dictionary:
	var xf: Transform3D = WorldXform.to_root(self)
	var d: Dictionary = {"kind": get_kind(), "id": get_marker_id(),
		"position": xf.origin, "yaw": xf.basis.get_euler().y}
	d.merge(get_extra(), true)
	return d


func _ready() -> void:
	if Engine.is_editor_hint():
		_build_debug_gizmo()


func _build_debug_gizmo() -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.35
	mesh.height = 0.7
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = get_debug_color()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = &"_DebugGizmo"
	mi.mesh = mesh
	mi.position.y = 0.35
	add_child(mi)   # sem owner: existe só no editor, não é salvo
	var label: Label3D = Label3D.new()
	label.name = &"_DebugLabel"
	label.text = "%s: %s" % [get_kind(), get_marker_id()]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.position.y = 1.1
	add_child(label)
