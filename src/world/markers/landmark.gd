@tool
class_name Landmark
extends WorldMarker
## Ponto notável do mapa (praça, ponte, ruína) usado em bússola, minimapa e missões.

@export var landmark_id: StringName = &""
@export var display_name: String = ""


func get_kind() -> StringName:
	return &"landmark"


func get_marker_id() -> StringName:
	return landmark_id if landmark_id != &"" else StringName(name)


func get_extra() -> Dictionary:
	return {"landmark_id": landmark_id, "display_name": display_name}


func get_debug_color() -> Color:
	return Color(1.0, 1.0, 1.0)
