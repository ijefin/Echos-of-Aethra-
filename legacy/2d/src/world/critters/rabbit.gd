class_name Rabbit
extends Node2D
## Coelho: fica parado mexendo o nariz, dá pulinhos aleatórios e foge em pulos rápidos
## quando o jogador chega perto. Folha rabbit.png: idle 0-1, pulo 2-5 (de perfil, para a direita).

enum State { IDLE, HOP, FLEE }

const HOP_SECONDS := 0.32
const HOP_HEIGHT := 4.0
const FLEE_SECONDS := 1.6

var _player: Node2D
var _state := State.IDLE
var _timer := 0.0
var _hop_t := 0.0
var _dir := Vector2.RIGHT
var _hop_speed := 38.0
var _flee_speed := 115.0
var _flee_px := 72.0
var _bounds := Rect2()
var _rng := RandomNumberGenerator.new()
var _sprite: Sprite2D
var _shadow: Sprite2D


## Configura o coelho. `bounds` limita a área do mundo onde ele pode andar.
func setup(texture: Texture2D, shadow_tex: Texture2D, pos: Vector2, player: Node2D, cfg: Dictionary, bounds: Rect2, seed_value: int) -> void:
	global_position = pos
	_player = player
	_hop_speed = float(cfg.get("rabbit_hop_speed", _hop_speed))
	_flee_speed = float(cfg.get("rabbit_flee_speed", _flee_speed))
	_flee_px = float(cfg.get("rabbit_flee_px", _flee_px))
	_bounds = bounds
	_rng.seed = seed_value
	_timer = _rng.randf_range(0.5, 3.0)
	_shadow = Sprite2D.new()
	_shadow.texture = shadow_tex
	_shadow.scale = Vector2(0.4, 0.4)
	_shadow.modulate = Color(1, 1, 1, 0.7)
	_shadow.z_index = -5
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = 6
	_sprite.offset = Vector2(0, -7)
	add_child(_sprite)


func _process(delta: float) -> void:
	var away := global_position - _player.global_position
	if away.length() < _flee_px and _state != State.FLEE:
		_state = State.FLEE
		_timer = FLEE_SECONDS
		_dir = (away.normalized() + Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))).normalized()
		_hop_t = 0.0
	match _state:
		State.IDLE:
			_timer -= delta
			_sprite.frame = 1 if fmod(_timer, 1.2) < 0.15 else 0
			_sprite.position.y = 0.0
			if _timer <= 0.0:
				_state = State.HOP
				_timer = _rng.randf_range(0.6, 1.6)
				_dir = Vector2.from_angle(_rng.randf() * TAU)
				_hop_t = 0.0
		State.HOP, State.FLEE:
			_timer -= delta
			var landed := _hop(delta, _hop_speed if _state == State.HOP else _flee_speed, 1.0 if _state == State.HOP else 1.6)
			if landed and _timer <= 0.0:
				_state = State.IDLE
				_timer = _rng.randf_range(1.0, 4.0)
				_sprite.position.y = 0.0


## Avança um pulo. Devolve true no frame em que um pulo termina (pouso).
func _hop(delta: float, speed: float, rate: float) -> bool:
	_hop_t += delta * rate
	var landed := _hop_t >= HOP_SECONDS
	if landed:
		_hop_t -= HOP_SECONDS
	var phase := _hop_t / HOP_SECONDS
	if phase > 0.15 and phase < 0.85:
		var next := global_position + _dir * speed * delta
		if not _bounds.has_point(next):
			_dir = -_dir
			next = global_position + _dir * speed * delta
		global_position = next
	_sprite.frame = 2 + mini(3, int(phase * 4.0))
	_sprite.position.y = -sin(phase * PI) * HOP_HEIGHT
	_sprite.flip_h = _dir.x < 0.0
	_shadow.scale = Vector2.ONE * (0.4 - sin(phase * PI) * 0.08)
	return landed
