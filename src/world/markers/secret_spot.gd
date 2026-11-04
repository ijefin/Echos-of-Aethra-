@tool
class_name SecretSpot
extends WorldMarker
## Local de um segredo (item escondido, passagem, easter egg).

@export var secret_id: StringName = &""
## Distância, em metros, em que o jogador "descobre" o segredo.
@export var discover_radius: float = 2.0


func get_kind() -> StringName:
	return &"secret"


func get_marker_id() -> StringName:
	return secret_id if secret_id != &"" else StringName(name)


func get_extra() -> Dictionary:
	return {"secret_id": secret_id, "discover_radius": discover_radius}


func get_debug_color() -> Color:
	return Color(0.8, 0.4, 1.0)
