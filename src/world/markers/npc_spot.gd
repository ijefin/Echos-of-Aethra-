@tool
class_name NpcSpot
extends WorldMarker
## Local onde um NPC fica (o NPC em si vem dos dados de NPCs, por `npc_id`).

@export var npc_id: StringName = &""


func get_kind() -> StringName:
	return &"npc"


func get_marker_id() -> StringName:
	return npc_id if npc_id != &"" else StringName(name)


func get_extra() -> Dictionary:
	return {"npc_id": npc_id}


func get_debug_color() -> Color:
	return Color(0.4, 1.0, 0.4)
