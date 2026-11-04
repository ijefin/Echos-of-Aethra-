class_name WorldPreview
extends Node3D
## Cena de visualização de uma região com câmera orbital simples (para prints e
## conferência no editor). Arraste/gire com o mouse esquerdo; roda do mouse = zoom.

@export var region_scene: PackedScene
@export var target: Vector3 = Vector3.ZERO
@export var distance: float = 70.0
@export_range(5.0, 85.0) var pitch_deg: float = 40.0
@export var yaw_deg: float = 35.0
## Graus por segundo de giro automático (0 = parado).
@export var auto_orbit_deg_s: float = 0.0
@export var world_style: WorldStyle

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	if region_scene != null:
		var region: Node = region_scene.instantiate()
		if world_style != null:
			world_style.apply_to_tree(region)
		add_child(region)
	_apply_pose()


func _process(delta: float) -> void:
	if auto_orbit_deg_s != 0.0:
		yaw_deg += auto_orbit_deg_s * delta
		_apply_pose()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		var rel: Vector2 = (event as InputEventMouseMotion).relative
		yaw_deg -= rel.x * 0.3
		pitch_deg = clampf(pitch_deg + rel.y * 0.3, 5.0, 85.0)
		_apply_pose()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b: int = (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance * 0.9, 5.0)
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			distance *= 1.1
		_apply_pose()


## Posiciona a câmera de acordo com yaw/pitch/distance.
func _apply_pose() -> void:
	var yaw: float = deg_to_rad(yaw_deg)
	var pitch: float = deg_to_rad(pitch_deg)
	var offset: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	_camera.position = target + offset
	_camera.look_at(target)
