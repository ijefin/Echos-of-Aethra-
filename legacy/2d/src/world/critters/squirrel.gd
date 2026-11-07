class_name Squirrel
extends Node2D
## Esquilo: corre de um lado para o outro perto da sua árvore. Quando o jogador chega
## perto, corre até o tronco, sobe, some na copa e só desce alguns segundos depois.
## Folha squirrel.png: idle 0-1, corrida 2-5, escalada 6-7.

enum State { IDLE, RUN, FLEE, CLIMB, HIDDEN, DESCEND }

const CLIMB_HEIGHT := 70.0
const CLIMB_SPEED := 55.0

var _player: Node2D
var _tree_base := Vector2.ZERO
var _state := State.IDLE
var _timer := 0.0
var _target := Vector2.ZERO
var _run_speed := 90.0
var _flee_px := 64.0
var _hide_range := Vector2(4.0, 7.0)
var _climb := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _sprite: Sprite2D
var _shadow: Sprite2D


## `tree_base` é a base do tronco da árvore-casa do esquilo, em coordenadas de mundo.
func setup(texture: Texture2D, shadow_tex: Texture2D, pos: Vector2, tree_base: Vector2, player: Node2D, cfg: Dictionary, seed_value: int) -> void:
	global_position = pos
	_tree_base = tree_base
	_player = player
	_run_speed = float(cfg.get("squirrel_run_speed", _run_speed))
	_flee_px = float(cfg.get("squirrel_flee_px", _flee_px))
	var hide: Array = cfg.get("squirrel_hide_seconds", [4.0, 7.0])
	_hide_range = Vector2(hide[0], hide[1])
	_rng.seed = seed_value
	_timer = _rng.randf_range(0.5, 2.5)
	_shadow = Sprite2D.new()
	_shadow.texture = shadow_tex
	_shadow.scale = Vector2(0.35, 0.35)
	_shadow.modulate = Color(1, 1, 1, 0.7)
	_shadow.z_index = -5
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = 8
	_sprite.offset = Vector2(0, -7)
	add_child(_sprite)


func _process(delta: float) -> void:
	_t += delta
	var near_player := global_position.distance_to(_player.global_position) < _flee_px
	if near_player and (_state == State.IDLE or _state == State.RUN):
		_state = State.FLEE
		_target = _tree_base + Vector2(0, 1)
	match _state:
		State.IDLE:
			_timer -= delta
			_sprite.frame = 1 if fmod(_t, 2.0) < 0.25 else 0
			if _timer <= 0.0:
				_state = State.RUN
				_target = _tree_base + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(4, 22))
		State.RUN, State.FLEE:
			var speed := _run_speed * (1.6 if _state == State.FLEE else 1.0)
			_run_to(delta, speed)
			if global_position.distance_to(_target) < 1.5:
				if _state == State.FLEE:
					_state = State.CLIMB
					_climb = 0.0
				else:
					_state = State.IDLE
					_timer = _rng.randf_range(1.0, 3.5)
		State.CLIMB:
			_climb += CLIMB_SPEED * delta
			_sprite.frame = 6 + int(_t * 10.0) % 2
			_sprite.flip_h = false
			_sprite.position.y = -_climb
			_sprite.modulate.a = clampf(1.0 - (_climb - CLIMB_HEIGHT * 0.7) / (CLIMB_HEIGHT * 0.3), 0.0, 1.0)
			_shadow.visible = false
			if _climb >= CLIMB_HEIGHT:
				_state = State.HIDDEN
				_timer = _rng.randf_range(_hide_range.x, _hide_range.y)
		State.HIDDEN:
			_timer -= delta
			if _timer <= 0.0 and not near_player:
				_state = State.DESCEND
		State.DESCEND:
			_climb -= CLIMB_SPEED * delta
			_sprite.frame = 6 + int(_t * 10.0) % 2
			_sprite.position.y = -_climb
			_sprite.modulate.a = clampf(1.0 - (_climb - CLIMB_HEIGHT * 0.7) / (CLIMB_HEIGHT * 0.3), 0.0, 1.0)
			if _climb <= 0.0:
				_sprite.position.y = 0.0
				_sprite.modulate.a = 1.0
				_shadow.visible = true
				_state = State.IDLE
				_timer = _rng.randf_range(1.0, 3.0)


func _run_to(delta: float, speed: float) -> void:
	var prev := global_position
	global_position = global_position.move_toward(_target, speed * delta)
	_sprite.frame = 2 + int(_t * 14.0) % 4
	if absf(global_position.x - prev.x) > 0.01:
		_sprite.flip_h = global_position.x < prev.x
	_sprite.position.y = -absf(sin(_t * 22.0)) * 1.5
