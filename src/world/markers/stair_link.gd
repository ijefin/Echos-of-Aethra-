@tool
class_name StairLink
extends WorldMarker
## Ligação entre andares (escada, buraco, portal de gruta).

@export var link_id: StringName = &""
## Andar de destino (0 = superfície, -1 = gruta...).
@export var target_floor: int = 0
## `link_id` do marcador de chegada no andar de destino (vazio = mesmo id, andar destino).
@export var target_link_id: StringName = &""


func get_kind() -> StringName:
	return &"stair"


func get_marker_id() -> StringName:
	return link_id if link_id != &"" else StringName(name)


func get_extra() -> Dictionary:
	return {"link_id": link_id, "target_floor": target_floor, "target_link_id": target_link_id}


func get_debug_color() -> Color:
	return Color(0.7, 0.7, 0.7)
