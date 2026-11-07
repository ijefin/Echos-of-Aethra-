class_name Butterfly
extends Node2D
## Borboleta: vagueia em torno de um ponto (um canteiro de flores), voa alto e para
## longe quando o jogador chega perto e depois volta. O nó fica no chão (para o y-sort
## e a sombra) e o sprite voa acima dele.

const FRAMES := 4
const FLAP_FPS := 14.0
const WANDER := Vector2(28, 16)
const CRUISE_SPEED := 22.0
const FLEE_SPEED := 60.0
const FLEE_SECONDS := 1.5
const CRUISE_ALT := 10.0
const FLEE_ALT := 26.0

var _player: Node2D
var _home := Vector2.ZERO
var _row := 0
var _t := 0.0
var _seed := 0.0
var _alt := CRUISE_ALT
var _flee_t := 0.0
var _flee_px := 34.0
var _sprite: Sprite2D
var _shadow: Sprite2D


## `row` escolhe a cor (linha da folha butterfly.png). `player` é qualquer Node2D
## que as borboletas devem evitar.
func setup(texture: Texture2D, shadow_tex: Texture2D, row: int, home: Vector2, player: Node2D, flee_px: float, seed_value: float) -> void:
	_home = home
	_row = row
	_player = player
	_flee_px = flee_px
	_seed = seed_value
	global_position = home
	_shadow = Sprite2D.new()
	_shadow.texture = shadow_tex
	_shadow.scale = Vector2(0.2, 0.2)
	_shadow.modulate = Color(1, 1, 1, 0.5)
	_shadow.z_index = -5
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = FRAMES
	_sprite.vframes = 3
	add_child(_sprite)


func _process(delta: float) -> void:
	_t += delta
	var target := _home + Vector2(sin(_t * 0.7 + _seed) * WANDER.x, cos(_t * 0.53 + _seed * 2.0) * WANDER.y)
	var away := global_position - _player.global_position
	if away.length() < _flee_px:
		_flee_t = FLEE_SECONDS
	var speed := CRUISE_SPEED
	if _flee_t > 0.0:
		_flee_t -= delta
		target = global_position + away.normalized() * 40.0
		speed = FLEE_SPEED
		_alt = lerpf(_alt, FLEE_ALT, delta * 3.0)
	else:
		_alt = lerpf(_alt, CRUISE_ALT + sin(_t * 2.1 + _seed) * 3.0, delta * 2.0)
	var prev_x := global_position.x
	global_position = global_position.move_toward(target, speed * delta)
	_sprite.position.y = -_alt
	_sprite.frame = _row * FRAMES + int(_t * FLAP_FPS + _seed * 5.0) % FRAMES
	if absf(global_position.x - prev_x) > 0.01:
		_sprite.flip_h = global_position.x < prev_x
	_shadow.scale = Vector2.ONE * (0.24 - _alt * 0.004)
