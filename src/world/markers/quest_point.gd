@tool
class_name QuestPoint
extends WorldMarker
## Ponto referenciado por missões (entregar item, chegar ao local, investigar).

@export var point_id: StringName = &""
## Distância, em metros, em que o objetivo conta como cumprido.
@export var reach_radius: float = 2.0


func get_kind() -> StringName:
	return &"quest"


func get_marker_id() -> StringName:
	return point_id if point_id != &"" else StringName(name)


func get_extra() -> Dictionary:
	return {"point_id": point_id, "reach_radius": reach_radius}


func get_debug_color() -> Color:
	return Color(1.0, 0.85, 0.0)
