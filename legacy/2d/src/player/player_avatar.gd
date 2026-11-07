class_name PlayerAvatar
extends CharacterBody2D
## Avatar de um jogador (qualquer classe). Anda em 8 direções e anima em 4 direções por
## uma spritesheet no layout do ASSET-001 (células de 64 px, pivô nos pés).
##
## Rede: o dono (multiplayer authority = peer do jogador) lê o input, move o corpo e
## envia o estado ~30×/s; os outros peers só interpolam. O servidor manda dash e
## teleporte (renascer) para o dono por RPC.
##
## Uso:
##   var a := PlayerAvatar.new()
##   a.name = "P%d" % peer_id
##   a.set_multiplayer_authority(peer_id)
##   world.add_child(a)
##   a.setup(cfg, class_def, sheet, light_tex, mote_tex, shadow_tex, send_hz)

const SHEET_COLS := 6
const SHEET_ROWS := 9
const CELL := 64
const PIVOT := Vector2(32, 58)
const ANIMS: Array[String] = ["idle", "walk", "attack"]
## Linhas da spritesheet por animação, na ordem down / up / right (left = espelho).
const ROWS := {"idle": [0, 1, 2], "walk": [3, 4, 5], "attack": [6, 7, 8]}
const FRAMES := {"idle": 4, "walk": 6}
const DIRS: Array[String] = ["down", "up", "right"]
const DIR_INDEX := {"down": 0, "up": 1, "right": 2}
## Ponta da arma/cajado relativa aos pés, por direção (x espelha à esquerda).
const TIP := {"down": Vector2(-12, -38), "up": Vector2(12, -38), "right": Vector2(10, -34)}
const FLASH_MODULATE := Color(3.0, 1.4, 1.4)
## Modo de sprite de 8 direções (classe com "sprite8"): ordem dos índices de _facing8,
## a partir do leste no sentido horário (y para baixo).
const DIR8: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

var move_speed := 120.0
var speed_mult := 1.0
var anim_fps := {"idle": 6.0, "walk": 10.0}
## Frame da animação de ataque a mostrar (0–5), ou -1 para andar/parado normalmente.
var attack_frame := -1
var display_name := ""
var peer_id := 1

## Direções e estados do Action Controller
var movement_direction := Vector2.ZERO
var aim_direction := Vector2.DOWN
var facing_vector := Vector2.DOWN

## Parâmetros de aceleração e frenagem (carregados de combat_rules.json)
var accel_time := 0.10
var friction_time := 0.08
var turn_time := 0.07

## Esquiva / Dodge Roll
var dodge_cooldown := 0.0
var dodge_max_cooldown := 1.4
var dodge_t := 0.0
var dodge_duration := 0.18
var dodge_speed := 340.0
var dodge_dir := Vector2.DOWN
var is_dodging := false
var is_invulnerable := false
var _dodge_buffered := false
var _dodge_buffer_t := 0.0
var _ghost_t := 0.0

## Referência ao kit de habilidades
var kit: ClassKit

var _dead := false
var _moving := false
var _freeze_ms := 0.0
var _flash_ms := 0.0
var _sprite: Sprite2D
var _light: PointLight2D
var _glow: Sprite2D
var _dust: CPUParticles2D
var _facing := "down"
var _flip := false
var _anim := "idle"
var _anim_t := 0.0
var _light_energy := 0.9
var _has_light := true
var _send_interval := 1.0 / 30.0
var _send_t := 0.0
var _net_target := Vector2.ZERO
var _dash_t := 0.0
var _dash_dur := 0.0
var _dash_from := Vector2.ZERO
var _dash_to := Vector2.ZERO
## Sprite de 8 direções: chave de DIR8 → [Texture2D, espelhar]. Vazio = modo spritesheet.
var _dir8: Dictionary = {}
var _facing8 := 2
var _bob_px := 2.0
var _bob_hz := 4.5
## Animações por frames no modo 8 direções: nome → {fps, dirs: chave → [frames, espelhar]}.
var _anim8: Dictionary = {}
var _hurt_t := 0.0
var _death_t := 0.0
## Paperdoll: textura do corpo → chave "anim/dir/i", usada para achar o mesmo frame nas
## camadas de equipamento (que seguem a mesma grade de frames do corpo).
var _frame_keys: Dictionary = {}
## Slot → {"item", "sprite": Sprite2D, "frames": {chave → Texture2D}, "fx": Dictionary,
## "emit": Sprite2D|null, "emit_frames", "light": PointLight2D|null, "nodes": [Node]}.
var _gear: Dictionary = {}
## Material aditivo compartilhado pelas camadas de brilho dos itens.
var _add_mat: CanvasItemMaterial
## Classe com luz no cajado: a luz passa a depender da arma vestida ter "light".
var _uses_gear_light := false


## Monta o avatar. `cfg` = bloco "player" de world_ambience.json; `class_def` = classe em
## combat_classes.json (velocidade, luz do cajado). Texturas injetadas para a arte poder
## ser trocada sem mexer aqui.
func setup(cfg: Dictionary, class_def: Dictionary, stats: Dictionary, sheet: Texture2D, light_tex: Texture2D,
		mote_tex: Texture2D, shadow_tex: Texture2D, send_hz: float, movement_rules: Dictionary = {}) -> void:
	move_speed = float(stats.get("move_speed", cfg.get("move_speed", move_speed)))
	var fps: Dictionary = cfg.get("anim_fps", {})
	for k: String in fps:
		anim_fps[k] = float(fps[k])
	if not movement_rules.is_empty():
		accel_time = float(movement_rules.get("accel_ms", 100)) / 1000.0
		friction_time = float(movement_rules.get("friction_ms", 80)) / 1000.0
		turn_time = float(movement_rules.get("turn_ms", 70)) / 1000.0
		dodge_duration = float(movement_rules.get("dodge_duration", 0.18))
		dodge_speed = float(movement_rules.get("dodge_speed", 340.0))
		dodge_max_cooldown = float(movement_rules.get("dodge_cooldown", 1.4))
	_light_energy = float(cfg.get("staff_light_energy", _light_energy))
	_has_light = bool(class_def.get("staff_light", true))
	_uses_gear_light = _has_light and class_def.has("starter_items")
	if _uses_gear_light:
		_has_light = false  # acende quando o servidor mandar vestir a arma
	_send_interval = 1.0 / maxf(1.0, send_hz)
	_net_target = global_position
	collision_layer = 1
	collision_mask = 1 | 2  # mundo + inimigos

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	shape.position = Vector2(0, -2)
	add_child(shape)

	var shadow := Sprite2D.new()
	shadow.texture = shadow_tex
	shadow.z_index = -5
	shadow.scale = Vector2(0.7, 0.7)
	shadow.modulate = Color(1, 1, 1, 0.8)
	add_child(shadow)

	_sprite = Sprite2D.new()
	_sprite.texture = sheet
	_sprite.hframes = SHEET_COLS
	_sprite.vframes = SHEET_ROWS
	_sprite.offset = Vector2(CELL / 2.0, CELL / 2.0) - PIVOT
	add_child(_sprite)
	_setup_dir8(class_def.get("sprite8", {}))

	_light = PointLight2D.new()
	_light.texture = light_tex
	_light.texture_scale = float(cfg.get("staff_light_scale", 1.4))
	_light.color = JsonData.to_color(cfg.get("staff_light_color", [1.0, 0.62, 0.28]))
	_light.energy = _light_energy
	_light.visible = _has_light
	add_child(_light)

	_glow = Sprite2D.new()
	_glow.texture = light_tex
	_glow.scale = Vector2(0.22, 0.22)
	_glow.modulate = Color(1.6, 1.0, 0.45, 0.9)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add_mat
	_glow.visible = _has_light
	add_child(_glow)

	_dust = CPUParticles2D.new()
	_dust.texture = mote_tex
	_dust.amount = 8
	_dust.lifetime = 0.5
	_dust.local_coords = false
	_dust.emitting = false
	_dust.direction = Vector2(0, -1)
	_dust.spread = 70.0
	_dust.gravity = Vector2(0, -12)
	_dust.initial_velocity_min = 6.0
	_dust.initial_velocity_max = 14.0
	_dust.color = Color(0.78, 0.68, 0.52, 0.55)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	_dust.color_ramp = fade
	_dust.z_index = -4
	add_child(_dust)
	_apply_frame("idle", 0)


## Liga o modo de 8 direções: uma textura por direção, direções faltantes por espelho.
## `cfg` = bloco "sprite8" da classe em combat_classes.json.
func _setup_dir8(cfg: Dictionary) -> void:
	if cfg.is_empty():
		return
	if cfg.has("manifest"):
		# Manifesto gerado por legacy/2d/tools/art/slice_sheet.gd; chaves da classe têm prioridade.
		var m := JsonData.load_dict("res://assets/data/" + String(cfg.manifest))
		m.merge(cfg, true)
		cfg = m
	var dirs: Dictionary = cfg.get("dirs", {})
	for key: String in dirs:
		var tex := load("res://legacy/2d/assets/art/" + String(dirs[key])) as Texture2D
		if tex != null:
			_dir8[key] = [tex, false]
	var mirror: Dictionary = cfg.get("mirror", {})
	for key: String in mirror:
		if _dir8.has(String(mirror[key])):
			_dir8[key] = [_dir8[String(mirror[key])][0], true]
	if _dir8.is_empty():
		return
	var first: Texture2D = _dir8.values()[0][0]
	var pivot: Array = cfg.get("pivot", [first.get_width() / 2.0, first.get_height() - 2.0])
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.texture = first
	_sprite.offset = Vector2(first.get_width(), first.get_height()) / 2.0 - Vector2(pivot[0], pivot[1])
	_bob_px = float(cfg.get("walk_bob_px", _bob_px))
	_bob_hz = float(cfg.get("walk_bob_hz", _bob_hz))
	# Animações por frames: {"walk": {"fps": 10, "dirs": {"s": [caminhos...]}, "mirror": {"w": "e"}}}
	var anims: Dictionary = cfg.get("anims", {})
	for anim_name: String in anims:
		var a: Dictionary = anims[anim_name]
		var frames_by_dir := {}
		var adirs: Dictionary = a.get("dirs", {})
		for key: String in adirs:
			var list: Array[Texture2D] = []
			for path: String in adirs[key]:
				var t := load("res://legacy/2d/assets/art/" + path) as Texture2D
				if t != null:
					_frame_keys[t] = "%s/%s/%d" % [anim_name, key, list.size()]
					list.append(t)
			if not list.is_empty():
				frames_by_dir[key] = [list, false]
		var amirror: Dictionary = a.get("mirror", {})
		for key: String in amirror:
			if frames_by_dir.has(String(amirror[key])):
				frames_by_dir[key] = [frames_by_dir[String(amirror[key])][0], true]
		if not frames_by_dir.is_empty():
			_anim8[anim_name] = {"fps": float(a.get("fps", 10.0)), "dirs": frames_by_dir}


## Frame atual da animação por frames (modo 8 direções), para enviar pela rede.
func _dir8_frame() -> int:
	var a: Dictionary = _anim8.get(_anim, {})
	if a.is_empty():
		return 0
	var frames: Array = _dir8_entry(a.dirs)[0]
	return int(_anim_t * float(a.fps)) % maxi(1, frames.size())


## Código de direção enviado pela rede: 0–2 = vistas da spritesheet; 3–10 = 8 direções.
func _dir_code() -> int:
	return 3 + _facing8 if not _dir8.is_empty() else int(DIR_INDEX[_facing])


func is_local() -> bool:
	return is_multiplayer_authority()


func _physics_process(delta: float) -> void:
	var ms := delta * 1000.0
	_freeze_ms = maxf(0.0, _freeze_ms - ms)
	_flash_ms = maxf(0.0, _flash_ms - ms)
	if is_local():
		_local_move(delta)
	else:
		global_position = global_position.lerp(_net_target, clampf(delta * 15.0, 0.0, 1.0))
	_update_anim(delta)


func _local_move(delta: float) -> void:
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	if _dodge_buffered:
		_dodge_buffer_t = maxf(0.0, _dodge_buffer_t - delta)
		if _dodge_buffer_t <= 0.0:
			_dodge_buffered = false

	var input := Vector2.ZERO
	if not _dead and _dash_dur <= 0.0 and not is_dodging:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	movement_direction = input

	# Input Buffering para esquiva
	if Input.is_action_just_pressed("dodge"):
		if can_dodge():
			var dir := movement_direction if movement_direction != Vector2.ZERO else _facing_vector()
			start_dodge(dir)
		else:
			_dodge_buffered = true
			_dodge_buffer_t = 0.12

	if _dodge_buffered and can_dodge():
		_dodge_buffered = false
		var dir := movement_direction if movement_direction != Vector2.ZERO else _facing_vector()
		start_dodge(dir)

	if is_dodging:
		dodge_t += delta
		var k := minf(1.0, dodge_t / maxf(0.001, dodge_duration))
		is_invulnerable = (dodge_t <= 0.12)
		var speed_curve := 1.0 - k * 0.45
		velocity = dodge_dir * dodge_speed * speed_curve
		_ghost_t += delta
		if _ghost_t >= 0.04:
			_ghost_t = 0.0
			_spawn_ghost()
		if dodge_t >= dodge_duration:
			is_dodging = false
			is_invulnerable = false
	elif _dash_dur > 0.0:
		_dash_t += delta
		var k := minf(1.0, _dash_t / _dash_dur)
		velocity = (_dash_from.lerp(_dash_to, k) - global_position) / maxf(delta, 0.0001)
		if k >= 1.0:
			_dash_dur = 0.0
	else:
		# Aceleração e Frenagem (curvas de 80-120ms e 60-100ms)
		var max_sp := move_speed * speed_mult
		var target_vel := movement_direction * max_sp
		if movement_direction != Vector2.ZERO:
			if velocity.dot(movement_direction) < -0.1:
				var rate := max_sp / maxf(0.001, turn_time)
				velocity = velocity.move_toward(target_vel, rate * delta)
			else:
				var rate := max_sp / maxf(0.001, accel_time)
				velocity = velocity.move_toward(target_vel, rate * delta)
		else:
			var rate := max_sp / maxf(0.001, friction_time)
			velocity = velocity.move_toward(Vector2.ZERO, rate * delta)

	move_and_slide()
	_moving = velocity.length() > 6.0

	# Atualiza orientação visual (facing) de forma independente do movimento
	var is_aiming_or_acting: bool = (kit != null and (kit.state in ["casting", "windup", "recovery"] or kit.aiming != "")) or attack_frame >= 0
	if is_dodging:
		face_toward(dodge_dir)
	elif is_aiming_or_acting:
		face_toward(aim_direction)
	elif _moving:
		face_toward(velocity.normalized() if velocity.length() > 6.0 else movement_direction)

	_send_t += delta
	if _send_t >= _send_interval and multiplayer.get_peers().size() > 0:
		_send_t = 0.0
		var anim_i := ANIMS.find("attack" if attack_frame >= 0 else _anim)
		var frame := attack_frame if attack_frame >= 0 else int(_anim_t * anim_fps[_anim]) % int(FRAMES[_anim])
		if not _dir8.is_empty() and attack_frame < 0:
			frame = _dir8_frame()
		if multiplayer.is_server():
			_send_state_to_ready(global_position, _dir_code(), _flip, anim_i, frame, 0)
		else:
			net_state.rpc_id(1, global_position, _dir_code(), _flip, anim_i, frame)


func _update_anim(delta: float) -> void:
	var anim := "walk" if _moving else "idle"
	if anim != _anim:
		_anim = anim
		_anim_t = 0.0
	if _freeze_ms <= 0.0 and is_local():  # hit-stop: a animação segura o frame
		_anim_t += delta
		if attack_frame >= 0:
			_apply_frame("attack", attack_frame)
		else:
			_apply_frame(_anim, int(_anim_t * anim_fps[_anim]) % int(FRAMES[_anim]))
	_update_overlay_anims(delta)
	_dust.emitting = _moving
	_sprite.self_modulate = FLASH_MODULATE if _flash_ms > 0.0 else Color.WHITE
	var tip := _tip_local()
	_light.position = tip
	_glow.position = tip
	var t := Time.get_ticks_msec() / 1000.0
	_light.energy = 0.0 if _dead else _light_energy * (0.88 + 0.08 * sin(t * 11.0) + 0.04 * sin(t * 23.0))
	_sync_gear()


## Peers que já entraram no mundo (fornecido pela sessão); só eles recebem o estado.
var ready_peers: Callable


## Servidor envia o estado deste avatar aos peers prontos, exceto `skip` (quem mandou).
func _send_state_to_ready(pos: Vector2, dir_i: int, flip: bool, anim_i: int, frame: int, skip: int) -> void:
	if not ready_peers.is_valid():
		return
	for p: int in ready_peers.call():
		if p != 1 and p != skip and p != peer_id:
			net_state.rpc_id(p, pos, dir_i, flip, anim_i, frame)


## Estado do avatar: o dono manda ao servidor, que aplica e repassa aos outros peers.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func net_state(pos: Vector2, dir_i: int, flip: bool, anim_i: int, frame: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != peer_id and sender != 1:
		return
	if multiplayer.is_server() and sender == peer_id:
		_send_state_to_ready(pos, dir_i, flip, anim_i, frame, sender)
	_net_target = pos
	if dir_i >= 3:
		_facing8 = clampi(dir_i - 3, 0, 7)
		face_toward(Vector2.from_angle(_facing8 * PI / 4.0))
	else:
		_facing = DIRS[clampi(dir_i, 0, 2)]
	_flip = flip
	var anim := ANIMS[clampi(anim_i, 0, 2)]
	_moving = anim == "walk"
	if _freeze_ms <= 0.0:
		_apply_frame(anim, frame)


## O servidor manda o dono avançar até `target` em `seconds` (Investida).
@rpc("any_peer", "call_local", "reliable")
func dash_to(target: Vector2, seconds: float) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1] or not is_local():
		return
	_dash_from = global_position
	_dash_to = target
	_dash_t = 0.0
	_dash_dur = maxf(0.01, seconds)


## Pequeno avanço procedural em direção a um golpe.
func lunge(dir: Vector2, distance: float) -> void:
	if not _dead and distance > 0.0:
		var target := global_position + dir.normalized() * distance
		global_position = target
		_net_target = target


## O servidor recoloca o jogador (renascer).
@rpc("any_peer", "call_local", "reliable")
func teleport(pos: Vector2) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	global_position = pos
	_net_target = pos


## true enquanto o dono está dando input de movimento (cancela conjurações).
func is_moving() -> bool:
	return _moving


## Nome da animação em reprodução (para o overlay de diagnóstico F3).
func anim_name() -> String:
	return _anim


func can_dodge() -> bool:
	if _dead or is_dodging or dodge_cooldown > 0.0 or _dash_dur > 0.0:
		return false
	if kit != null and kit.state in ["casting", "windup"]:
		return false
	return true


func start_dodge(dir: Vector2) -> void:
	dodge_dir = dir.normalized() if dir != Vector2.ZERO else _facing_vector()
	is_dodging = true
	is_invulnerable = true
	dodge_t = 0.0
	dodge_cooldown = dodge_max_cooldown
	_ghost_t = 0.0
	_spawn_ghost()
	if kit != null and kit.state == "recovery":
		kit.state = "idle"


func _facing_vector() -> Vector2:
	if facing_vector != Vector2.ZERO:
		return facing_vector
	match _facing:
		"down": return Vector2.DOWN
		"up": return Vector2.UP
		"right": return Vector2.LEFT if _flip else Vector2.RIGHT
	return Vector2.DOWN


func _spawn_ghost() -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.texture
	ghost.hframes = _sprite.hframes
	ghost.vframes = _sprite.vframes
	ghost.frame = _sprite.frame
	ghost.flip_h = _sprite.flip_h
	ghost.offset = _sprite.offset
	ghost.global_position = _sprite.global_position
	ghost.scale = _sprite.scale
	ghost.modulate = Color(0.65, 0.85, 1.3, 0.55)
	ghost.z_index = z_index - 1
	for slot: String in _gear:
		var layer: Sprite2D = _gear[slot].sprite
		if layer.visible:
			var g := Sprite2D.new()
			g.texture = layer.texture
			g.flip_h = layer.flip_h
			g.offset = layer.offset
			g.show_behind_parent = layer.show_behind_parent
			ghost.add_child(g)
	var parent := get_parent()
	if parent != null:
		parent.add_child(ghost)
		var tw := ghost.create_tween()
		tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
		tw.tween_callback(ghost.queue_free)


## Vira para a direção cardinal mais próxima de `dir` (4 direções; esquerda = espelho).
func face_toward(dir: Vector2) -> void:
	if dir.is_zero_approx():
		return
	facing_vector = dir.normalized()
	_facing8 = posmod(roundi(dir.angle() / (PI / 4.0)), 8)
	if absf(dir.x) > absf(dir.y):
		_facing = "right"
		_flip = dir.x < 0.0
	elif dir.y != 0.0:
		_facing = "down" if dir.y > 0.0 else "up"
		_flip = false


## Posição global da ponta da arma/cajado (origem de projéteis e brilhos).
func tip_global() -> Vector2:
	return global_position + _tip_local()


## Feedback de acerto: flash avermelhado e/ou hit-stop (ms). Com arte de dano (sprite8),
## toca a animação "hurt".
func hit_feel(flash_ms: float, freeze_ms: float) -> void:
	_flash_ms = maxf(_flash_ms, flash_ms)
	_freeze_ms = maxf(_freeze_ms, freeze_ms)
	if flash_ms > 0.0 and _anim8.has("hurt") and not _dead:
		var a: Dictionary = _anim8.hurt
		_hurt_t = float((_dir8_entry(a.dirs)[0] as Array).size()) / float(a.fps)


## Toca dano/morte por frames (sprite8) por cima do resto; vale para o dono e para os outros peers.
func _update_overlay_anims(delta: float) -> void:
	if _dir8.is_empty():
		return
	var anim_name := ""
	var t := 0.0
	if _dead and _anim8.has("death"):
		_death_t += delta
		anim_name = "death"
		t = _death_t
	elif _hurt_t > 0.0 and _anim8.has("hurt"):
		var a: Dictionary = _anim8.hurt
		var dur := float((_dir8_entry(a.dirs)[0] as Array).size()) / float(a.fps)
		_hurt_t -= delta
		anim_name = "hurt"
		t = dur - _hurt_t
	if anim_name == "":
		return
	var anim: Dictionary = _anim8[anim_name]
	var entry: Array = _dir8_entry(anim.dirs)
	var frames: Array = entry[0]
	_sprite.texture = frames[mini(int(t * float(anim.fps)), frames.size() - 1)]
	_sprite.flip_h = entry[1]
	_sprite.position = Vector2.ZERO
	_sprite.rotation = 0.0
	_sprite.scale = Vector2.ONE


## Caído: sem input, escurecido, sem luz.
func set_dead(value: bool) -> void:
	_dead = value
	if value:
		_sprite.position = Vector2.ZERO
		_sprite.rotation = 0.0
		_sprite.scale = Vector2.ONE
	_death_t = 0.0
	var has_death_art := _anim8.has("death")
	_sprite.modulate = Color(0.45, 0.4, 0.5, 0.7) if value and not has_death_art else Color.WHITE
	_glow.visible = _has_light and not value


func is_dead() -> bool:
	return _dead


func _tip_local() -> Vector2:
	var tip: Vector2 = TIP[_facing]
	if _flip:
		tip.x = -tip.x
	return tip


func _apply_frame(anim: String, f: int) -> void:
	if not _dir8.is_empty():
		_apply_dir8(anim, f)
	else:
		var row: int = ROWS[anim][DIR_INDEX[_facing]]
		_sprite.frame = row * SHEET_COLS + clampi(f, 0, SHEET_COLS - 1)
		_sprite.flip_h = _flip
	# A mesma pose deriva dos frames locais e replicados. Só desloca o desenho;
	# colisão, posição autoritativa e origem do projétil continuam nos pés.
	_sprite.position = Vector2.ZERO
	_sprite.rotation = 0.0
	_sprite.scale = Vector2.ONE
	if not _dir8.is_empty() and anim == "walk" and not _dead and not _anim8.has("walk"):
		# Sem frames de caminhada: passo procedural (pulinho + leve achatamento).
		var s := absf(sin(_anim_t * _bob_hz * PI))
		_sprite.position.y = -s * _bob_px
		_sprite.scale = Vector2(1.0 + (1.0 - s) * 0.04, 1.0 - (1.0 - s) * 0.04)
	if anim != "attack" or _dead:
		return
	var phase := clampi(f, 0, 5)
	var impulse: float = [-0.5, -0.8, -1.0, 1.0, 0.45, 0.0][phase]
	var direction := Vector2.DOWN if _facing == "down" else Vector2.UP
	if _facing == "right":
		direction = Vector2.LEFT if _flip else Vector2.RIGHT
	var weight := 1.5 if _has_light else 2.5
	if not _dir8.is_empty():
		direction = facing_vector
	_sprite.position = direction * impulse * weight
	_sprite.rotation = impulse * (0.025 if _has_light else 0.055) * (-1.0 if _flip else 1.0)
	_sprite.scale = Vector2(1.0 - absf(impulse) * 0.025, 1.0 + impulse * 0.035)


## Escolhe a textura da direção atual (8 direções). Se a animação tem frames, usa o
## frame do tempo local (dono) ou o recebido pela rede (`f`); senão, a pose parada.
func _apply_dir8(anim_name: String, f: int) -> void:
	var a: Dictionary = _anim8.get(anim_name, {})
	if not a.is_empty():
		var entry: Array = _dir8_entry(a.dirs)
		var frames: Array = entry[0]
		var idx := int(_anim_t * float(a.fps)) if is_local() else f
		if anim_name == "attack":
			# O kit conta o ataque em 6 passos (release no 3); espalha pelos frames da arte.
			idx = roundi(clampf(f / 5.0, 0.0, 1.0) * (frames.size() - 1))
		_sprite.texture = frames[posmod(idx, frames.size())]
		_sprite.flip_h = entry[1]
		return
	var still: Array = _dir8_entry(_dir8)
	_sprite.texture = still[0]
	_sprite.flip_h = still[1]


## Entrada da direção atual em `table`; direções sem arte usam a mais próxima.
func _dir8_entry(table: Dictionary) -> Array:
	for step in 8:
		for sgn: int in [1, -1]:
			var key := DIR8[posmod(_facing8 + step * sgn, 8)]
			if table.has(key):
				return table[key]
	return table.values()[0]


## Mostra o que está vestido: slot → id (slots ausentes ficam vazios). Só visual — quem
## decide o equipamento é o servidor (NetSession/Inventory). Itens sem "manifest" (ainda
## sem sprite) contam atributos mas não desenham nada.
##   avatar.show_gear({"weapon": "fire_staff", "head": "mage_hat"})
func show_gear(equipped_items: Dictionary) -> void:
	var slots: Dictionary = Inventory.load_db().get("slots", {})
	for slot: String in slots:
		_show_gear_slot(slot, String(equipped_items.get(slot, "")))


func _show_gear_slot(slot: String, item_id: String) -> void:
	if _sprite == null:
		return
	if _gear.has(slot):
		var old: Sprite2D = _gear[slot].sprite
		_sprite.remove_child(old)
		old.queue_free()
		for n: Node in _gear[slot].nodes:
			n.queue_free()
		_gear.erase(slot)
	var db := Inventory.load_db()
	var item: Dictionary = db.items.get(item_id, {}) if item_id != "" else {}
	if slot == "weapon" and _uses_gear_light:
		_has_light = bool(item.get("light", false))
		_light.visible = _has_light
		_glow.visible = _has_light and not _dead
	if item.is_empty() or not item.has("manifest"):
		return
	var slot_def: Dictionary = db.slots[slot]
	var layer := Sprite2D.new()
	layer.name = "Gear_" + slot
	layer.show_behind_parent = bool(slot_def.get("behind", false))
	layer.z_index = int(slot_def.get("z", 0))
	_sprite.add_child(layer)
	var g := {"item": item_id, "sprite": layer, "frames": _load_gear_frames(String(item.manifest)),
		"fx": item.get("fx", {}), "emit": null, "emit_frames": {}, "light": null, "nodes": []}
	_add_gear_fx(g)
	_gear[slot] = g
	_sync_gear()


## Efeitos do item (campo "fx" em items.json), todos opcionais:
##   emit: manifesto da camada de brilho (pixels acesos) — aditiva, HDR, pulsa
##   emit_hdr / pulse_hz / pulse_amp: intensidade base e pulso do brilho (e da luz)
##   aura: brasas subindo em volta do corpo {amount, lifetime, extents, rise, color}
##   light: luz de calor no chão {color, energy, scale, offset}
func _add_gear_fx(g: Dictionary) -> void:
	var fx: Dictionary = g.fx
	if fx.has("emit"):
		var e := Sprite2D.new()
		e.material = _additive()
		(g.sprite as Sprite2D).add_child(e)
		g.emit = e
		g.emit_frames = _load_gear_frames(String(fx.emit))
	if fx.has("aura"):
		var aura := _make_aura(fx.aura)
		add_child(aura)
		g.nodes.append(aura)
	if fx.has("light"):
		var lc: Dictionary = fx.light
		var l := PointLight2D.new()
		l.texture = _light.texture
		l.color = JsonData.to_color(lc.get("color", [1.0, 0.45, 0.2]))
		l.energy = float(lc.get("energy", 0.5))
		l.texture_scale = float(lc.get("scale", 2.0))
		var off: Array = lc.get("offset", [0, -12])
		l.position = Vector2(off[0], off[1])
		add_child(l)
		g.light = l
		g.nodes.append(l)


## Brasas subindo em volta do corpo: aditivas, cor HDR (acende o bloom) que esfria e some.
func _make_aura(cfg: Dictionary) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _dust.texture
	p.amount = int(cfg.get("amount", 10))
	p.lifetime = float(cfg.get("lifetime", 1.0))
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var ext: Array = cfg.get("extents", [9, 4])
	p.emission_rect_extents = Vector2(ext[0], ext[1])
	p.position = Vector2(0, -8)
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2(0, -18)
	var rise: Array = cfg.get("rise", [8, 20])
	p.initial_velocity_min = float(rise[0])
	p.initial_velocity_max = float(rise[1])
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var hot := JsonData.to_color(cfg.get("color", [2.4, 1.0, 0.3]))
	var ramp := Gradient.new()
	ramp.set_color(0, hot)
	ramp.add_point(0.5, Color(hot.r * 0.7, hot.g * 0.35, hot.b * 0.3, 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.1, 0.05, 0.0))
	p.color_ramp = ramp
	p.material = _additive()
	p.z_index = 1
	return p


func _additive() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


## Chave "anim/dir/i" → textura, a partir do manifesto da camada.
func _load_gear_frames(manifest: String) -> Dictionary:
	var out := {}
	var m := JsonData.load_dict("res://assets/data/" + manifest)
	var anims: Dictionary = m.get("anims", {})
	for anim_name: String in anims:
		var dirs: Dictionary = anims[anim_name].get("dirs", {})
		for key: String in dirs:
			var paths: Array = dirs[key]
			for i in paths.size():
				var t := load("res://legacy/2d/assets/art/" + String(paths[i])) as Texture2D
				if t != null:
					out["%s/%s/%d" % [anim_name, key, i]] = t
	return out


## Põe em cada camada de equipamento o mesmo frame/espelho/flash do corpo. Frames sem
## arte na camada (ex.: animação nova só no corpo) escondem a camada.
func _sync_gear() -> void:
	if _gear.is_empty():
		return
	var key := String(_frame_keys.get(_sprite.texture, ""))
	var t := Time.get_ticks_msec() / 1000.0
	for slot: String in _gear:
		var g: Dictionary = _gear[slot]
		var layer: Sprite2D = g.sprite
		var tex: Texture2D = g.frames.get(key)
		layer.visible = tex != null
		layer.texture = tex
		layer.flip_h = _sprite.flip_h
		layer.offset = _sprite.offset
		layer.self_modulate = _sprite.self_modulate
		var fx: Dictionary = g.fx
		if fx.is_empty():
			continue
		# Brilho pulsante: seno lento entre (1 - amp) e (1 + amp) da intensidade base.
		var pulse := 1.0 + float(fx.get("pulse_amp", 0.0)) * sin(t * TAU * float(fx.get("pulse_hz", 1.0)))
		var e: Sprite2D = g.emit
		if e != null:
			var etex: Texture2D = g.emit_frames.get(key)
			e.visible = etex != null and layer.visible and not _dead
			e.texture = etex
			e.flip_h = layer.flip_h
			e.offset = layer.offset
			var hdr := float(fx.get("emit_hdr", 2.0)) * pulse
			e.self_modulate = Color(hdr, hdr, hdr, 1.0)
		var l: PointLight2D = g.light
		if l != null:
			l.visible = not _dead
			l.energy = float(fx.light.get("energy", 0.5)) * pulse
