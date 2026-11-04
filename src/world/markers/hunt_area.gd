@tool
class_name HuntArea
extends WorldMarker
## Área de caça: região (círculo ou retângulo no plano XZ) com faixa de níveis.

enum Shape { CIRCLE, BOX }

@export var hunt_id: StringName = &""
@export var shape: Shape = Shape.CIRCLE
## Raio do círculo (metros).
@export var radius: float = 10.0
## Tamanho do retângulo em X e Z (metros); a rotação Y do nó gira o retângulo.
@export var size: Vector2 = Vector2(20.0, 20.0)
@export var min_level: int = 1
@export var max_level: int = 10


func get_kind() -> StringName:
	return &"hunt"


func get_marker_id() -> StringName:
	return hunt_id if hunt_id != &"" else StringName(name)


func get_extra() -> Dictionary:
	return {"hunt_id": hunt_id, "shape": &"circle" if shape == Shape.CIRCLE else &"box",
		"radius": radius, "size": size, "min_level": min_level, "max_level": max_level}


func get_debug_color() -> Color:
	return Color(1.0, 0.6, 0.1)


## Teste puro de pertinência a partir do dicionário gerado por `to_dict()`.
static func contains_point(info: Dictionary, point: Vector3) -> bool:
	var origin: Vector3 = info["position"]
	var dx: float = point.x - origin.x
	var dz: float = point.z - origin.z
	if info["shape"] == &"circle":
		return dx * dx + dz * dz <= float(info["radius"]) * float(info["radius"])
	var local: Vector2 = Vector2(dx, dz).rotated(float(info["yaw"]))
	var half: Vector2 = (info["size"] as Vector2) * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y
