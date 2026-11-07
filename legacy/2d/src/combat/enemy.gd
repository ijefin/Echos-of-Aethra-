class_name Enemy
extends CharacterBody2D
## Alvo de combate: boneco de treino ou Slime Desperto. Guarda atributos, HP, Queimadura
## e o estado de game feel (hit-stop, flash, squash, balanço, knockback).
##
## Rede: no servidor roda IA, Queimadura, knockback, atordoamento e provocação; nos
## clientes (`puppet = true`) só interpola os snapshots do servidor e mostra o feel.
##
## Uso:
##   var e := Enemy.new()
##   e.name = "E12"
##   e.position = pos
##   parent.add_child(e)
##   e.setup("slime_awakened", defs["slime_awakened"], tex, shadow_tex, world, derived, puppet)

signal died(enemy: Enemy)

const CELL_OFFSET := Vector2(0, -26)  # célula 64×64 com pivô nos pés (32, 58)
const FLASH_MODULATE := Color(4.0, 4.0, 4.0)  # HDR: branco que acende o glow
const FLAME_OFFSETS: Array[Vector2] = [Vector2(-7, -26), Vector2(6, -30), Vector2(-2, -38), Vector2(9, -20), Vector2(-10, -18)]

var kind := ""
var display_name := ""
var stats: Dictionary = {}
var hp := 1.0
var alive := true
var radius := 10.0
var burn_stacks := 0
var burn_time := 0.0
var burn_tick := 0.0
var freeze_ms := 0.0
var flash_ms := 0.0
var stun_t := 0.0
## Peer que provocou este inimigo (Grito de Guerra) e por quanto tempo.
var taunt_peer := 0
var taunt_t := 0.0
var puppet := false

var _def: Dictionary
var _world: CombatWorld
var _sprite: Sprite2D
var _shadow: Sprite2D
var _home := Vector2.ZERO
var _respawn_t := 0.0
var _kb_active := false
var _kb_from := Vector2.ZERO
var _kb_dir := Vector2.ZERO
var _kb_dist := 0.0
var _kb_t := 0.0
var _kb_dur := 0.18
var _squash_amt := 1.0
var _squash_t := 0.0
var _squash_dur := 0.0
var _wobble_t := 9.0
var _wobble_amp := 0.0
var _anim_t := 0.0
var _attack_cd := 0.0
var _fade := 1.0
var _net_pos := Vector2.ZERO
var _net_flip := false
var poise := 1.0
var max_poise := 1.0
var action_state := "idle"
var _action: Dictionary = {}
var _action_t := 0.0
var _action_index := 0
var _locked_origin := Vector2.ZERO
var _locked_point := Vector2.ZERO
var _locked_dir := Vector2.RIGHT
var _hit_peers: Dictionary = {}
var _poise_delay := 0.0
var _break_immunity := 0.0
var _visual_t := 0.0
var _visual_duration := 0.0
var _action_cooldowns: Dictionary = {}
var off_balance_t := 0.0


func apply_off_balance(seconds: float) -> void:
	off_balance_t = maxf(off_balance_t, seconds)


## Called only by the authoritative combat resolver. Visual hit-stop never stops AI.
func apply_poise(amount: float) -> void:
	if puppet or not alive or amount <= 0.0 or _break_immunity > 0.0:
		return
	if off_balance_t > 0.0:
		amount *= 1.25
	_poise_delay = float(_def.get("poise_regen_delay", 2.0))
	poise = maxf(0.0, poise - amount)
	if poise <= 0.0:
		stun_t = maxf(stun_t, float(_def.get("stagger_seconds", 0.8)))
		_break_immunity = stun_t + float(_def.get("stagger_immunity", 3.0))
		poise = max_poise
		_cancel_action()
		action_state = "stagger"
		_action_t = stun_t
		show_action.rpc("stagger", {}, global_position, global_position, stun_t, poise)


## Front guard only; resolver passes the attacker's world position.
func incoming_damage_mult(from: Vector2) -> float:
	if action_state == "active" and String(_action.get("type", "")) == "guard":
		if (from - global_position).normalized().dot(_locked_dir) > 0.0:
			return float(_action.get("damage_mult", 0.4))
	return 1.0


@rpc("authority", "call_local", "reliable")
func show_action(phase: String, action: Dictionary, origin: Vector2, point: Vector2, duration: float, current_poise: float) -> void:
	if puppet:
		action_state = phase
		_action = action
		_locked_origin = origin
		_locked_point = point
		_locked_dir = (point - origin).normalized()
	poise = current_poise
	_visual_t = 0.0
	_visual_duration = duration
	queue_redraw()


func sync_action_to(peer: int) -> void:
	show_action.rpc_id(peer, action_state, _action, _locked_origin, _locked_point, _action_t, poise)


## Configura o inimigo. `def` é a entrada de combat_enemies.json; `derived` é a lista
## de atributos derivados de combat_classes.json.
func setup(kind_id: String, def: Dictionary, texture: Texture2D, shadow_tex: Texture2D,
		world: CombatWorld, derived: Array, is_puppet: bool) -> void:
	kind = kind_id
	_def = def
	_world = world
	puppet = is_puppet
	display_name = String(def.get("name", kind_id))
	stats = AttributeSet.build(def, 1, derived)
	hp = stats.max_hp
	max_poise = float(def.get("max_poise", 60.0))
	poise = max_poise
	radius = float(def.get("radius", 10.0))
	_home = position
	_net_pos = position
	collision_layer = 2
	collision_mask = 1 | 2

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.7
	shape.shape = circle
	shape.position = Vector2(0, -2)
	shape.disabled = puppet
	add_child(shape)

	_shadow = Sprite2D.new()
	_shadow.texture = shadow_tex
	_shadow.scale = Vector2(0.75, 0.75)
	_shadow.modulate = Color(1, 1, 1, 0.75)
	_shadow.z_index = -5
	add_child(_shadow)

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = int(def.get("frames", 4))
	_sprite.offset = CELL_OFFSET
	_sprite.modulate = JsonData.to_color(def.get("tint", [1, 1, 1]))
	add_child(_sprite)


## Feedback visual de um acerto (todos os peers). `hitstop_ms` é o do maior tier do frame.
func apply_hit_feel(tier: Dictionary, hitstop_ms: float) -> void:
	flash_ms = maxf(flash_ms, float(tier.flash))
	var squash: Array = tier.get("squash", [])
	if squash.size() == 2:
		_squash_amt = float(squash[0])
		_squash_dur = float(squash[1])
		_squash_t = 0.0
	if hitstop_ms > 0.0:
		freeze_ms = maxf(freeze_ms, hitstop_ms)
	_wobble_t = 0.0
	_wobble_amp = maxf(float(tier.wobble), _wobble_amp * 0.5)


## Subtrai HP (servidor). Devolve true se este dano matou o inimigo.
func apply_damage(amount: float) -> bool:
	if not alive:
		return false
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		_die()
		return true
	return false


## Empurra para longe de `center` (servidor). O movimento começa depois do hit-stop.
func start_knockback(center: Vector2, distance: float, duration: float) -> void:
	if not alive or distance <= 0.0:
		return
	var away := global_position - center
	if away.length() < 1.0:
		away = Vector2.from_angle(randf() * TAU)
	_kb_active = true
	_kb_from = global_position
	_kb_dir = away.normalized()
	_kb_dist = distance
	_kb_t = 0.0
	_kb_dur = duration


## Volta ao estado inicial (bonecos renascem; tecla R).
func reset_to_home() -> void:
	alive = true
	hp = stats.max_hp
	burn_stacks = 0
	stun_t = 0.0
	taunt_t = 0.0
	_kb_active = false
	global_position = _home
	_net_pos = _home
	_fade = 1.0
	modulate.a = 1.0
	_sprite.frame = 0
	poise = max_poise
	_break_immunity = 0.0
	_action_cooldowns.clear()
	_cancel_action()


## Estado vindo do servidor (clientes).
func apply_snapshot(pos: Vector2, new_hp: float, stacks: int, is_alive: bool, flip: bool) -> void:
	_net_pos = pos
	hp = new_hp
	burn_stacks = stacks
	_net_flip = flip
	if is_alive and not alive:
		reset_to_home()
		global_position = pos
	elif not is_alive and alive:
		_die()


func is_respawning() -> bool:
	return not alive and _respawn_t > 0.0


func _die() -> void:
	alive = false
	_cancel_action()
	burn_stacks = 0
	_kb_active = false
	_sprite.frame = _sprite.hframes - 1
	_respawn_t = float(_def.get("respawn_seconds", 0.0))
	died.emit(self)


func _physics_process(delta: float) -> void:
	_visual_t += delta
	var ms := delta * 1000.0
	freeze_ms = maxf(0.0, freeze_ms - ms)
	flash_ms = maxf(0.0, flash_ms - ms)
	if _squash_dur > 0.0:
		_squash_t += ms
		if _squash_t >= _squash_dur:
			_squash_dur = 0.0
	if freeze_ms <= 0.0:
		_anim_t += delta
		_wobble_t += delta

	if puppet:
		if alive:
			var prev := global_position
			global_position = global_position.lerp(_net_pos, clampf(delta * 12.0, 0.0, 1.0))
			velocity = (global_position - prev) / maxf(delta, 0.0001)
		elif _respawn_t <= 0.0:
			_fade -= delta * 1.5
			modulate.a = maxf(0.0, _fade)
		_update_visuals()
		return

	if not alive:
		_update_dead(delta)
		_update_visuals()
		return
	_update_burn(delta)
	if not alive:
		_update_visuals()
		return
	stun_t = maxf(0.0, stun_t - delta)
	taunt_t = maxf(0.0, taunt_t - delta)
	off_balance_t = maxf(0.0, off_balance_t - delta)
	_visual_t += delta
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_break_immunity = maxf(0.0, _break_immunity - delta)
	_poise_delay = maxf(0.0, _poise_delay - delta)
	if _poise_delay <= 0.0:
		poise = minf(max_poise, poise + float(_def.get("poise_regen", 15.0)) * delta)
	for key in _action_cooldowns:
		_action_cooldowns[key] = maxf(0.0, float(_action_cooldowns[key]) - delta)
	if (stun_t > 0.0 or _kb_active) and action_state in ["windup", "active"]:
		_cancel_action()

	velocity = Vector2.ZERO
	if _kb_active:
		if freeze_ms <= 0.0:
			_kb_t += delta
			var k := minf(1.0, _kb_t / _kb_dur)
			var eased := 1.0 - (1.0 - k) * (1.0 - k)
			velocity = (_kb_from + _kb_dir * _kb_dist * eased - global_position) / maxf(delta, 0.0001)
			if k >= 1.0:
				_kb_active = false
	elif stun_t > 0.0:
		pass
	elif _def.get("chase", false):
		_update_actions(delta)
	elif _def.get("returns_home", false):
		var to_home := _home - global_position
		if to_home.length() > 0.5:
			velocity = to_home.normalized() * minf(40.0, to_home.length() / maxf(delta, 0.0001))
	move_and_slide()
	_update_visuals()


func _update_burn(delta: float) -> void:
	if burn_stacks <= 0:
		return
	var b: Dictionary = _world.burn_rules
	burn_time -= delta
	burn_tick -= delta
	if burn_tick <= 0.0:
		burn_tick += float(b.tick_interval)
		_world.deal_damage(self, burn_stacks * float(b.tick_damage), "light", false, "burn", 0)
	if burn_time <= 0.0:
		burn_stacks = 0


func _cancel_action() -> void:
	var changed := action_state != "idle"
	action_state = "idle"
	_action.clear()
	_hit_peers.clear()
	_action_t = 0.0
	_attack_cd = maxf(_attack_cd, 0.35)
	if changed and not puppet and is_inside_tree():
		show_action.rpc("idle", {}, global_position, global_position, 0.0, poise)


func _begin_phase(phase: String, duration: float) -> void:
	action_state = phase
	_action_t = duration
	show_action.rpc(phase, _action, _locked_origin, _locked_point, duration, poise)


func _update_actions(delta: float) -> void:
	if global_position.distance_to(_home) > float(_def.get("leash_px", 360.0)):
		_cancel_action()
		velocity = global_position.direction_to(_home) * float(stats.move_speed)
		return
	if action_state in ["windup", "active", "recover", "stagger"]:
		_action_t -= delta
		if action_state == "active":
			_resolve_active()
		if _action_t > 0.0:
			return
		match action_state:
			"windup":
				_hit_peers.clear()
				_begin_phase("active", float(_action.get("active", 0.18)))
			"active":
				_begin_phase("recover", float(_action.get("recovery", 0.7)))
			_:
				_cancel_action()
		return
	var target := _world.choose_target(self, float(_def.get("aggro_px", 220.0)))
	if target == null:
		if global_position.distance_to(_home) > 5.0:
			velocity = global_position.direction_to(_home) * float(stats.move_speed)
		return
	var distance := global_position.distance_to(target.global_position)
	var actions: Array = _def.get("actions", [])
	if _attack_cd <= 0.0:
		for offset in actions.size():
			var index := (_action_index + offset) % actions.size()
			var candidate: Dictionary = actions[index]
			if distance > float(candidate.get("range", 60)) or distance < float(candidate.get("min_range", 0)):
				continue
			if float(_action_cooldowns.get(index, 0.0)) > 0.0 or not _clear_line(global_position, target.global_position):
				continue
			_action = candidate.duplicate(true)
			_action_cooldowns[index] = float(candidate.get("cooldown", 2.0))
			_action_index = (index + 1) % actions.size()
			_locked_origin = global_position
			_locked_point = target.global_position
			_locked_dir = global_position.direction_to(_locked_point)
			if _locked_dir.is_zero_approx():
				_locked_dir = Vector2.DOWN
			_begin_phase("windup", float(candidate.get("windup", 0.6)))
			return
	var preferred := float(_def.get("preferred_range", 30.0))
	if distance > preferred:
		velocity = global_position.direction_to(target.global_position) * float(stats.move_speed)
	elif distance < preferred * 0.65 and bool(_def.get("retreat", false)):
		velocity = target.global_position.direction_to(global_position) * float(stats.move_speed) * 0.65


func _clear_line(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _resolve_active() -> void:
	var type := String(_action.get("type", "circle"))
	if type == "guard":
		return
	if type == "leap":
		velocity = _locked_dir * float(_action.get("speed", 250.0))
	var reach := float(_action.get("radius", 30.0))
	var duration := float(_action.get("active", 0.18))
	var progress := clampf(1.0 - _action_t / maxf(duration, 0.001), 0.0, 1.0)
	for peer: int in _world.players:
		var player := _world.avatar_of(peer)
		if player == null or player.is_dead():
			continue
		var center := _locked_point if type == "ground" else _locked_origin
		if type == "leap":
			center = global_position
		var hit := false
		var hit_key := str(peer)
		if type == "barrage":
			# Three slow bolts travel on locked rays; one hit per bolt, not per frame.
			for bolt in 3:
				var bolt_progress := progress * 1.5 - float(bolt) * 0.25
				if bolt_progress < 0.0 or bolt_progress > 1.0:
					continue
				var dir := _locked_dir.rotated(deg_to_rad(float(bolt - 1) * 14.0))
				var point := _locked_origin + dir * bolt_progress * float(_action.get("travel", 260.0))
				hit_key = "%d:%d" % [peer, bolt]
				if not _hit_peers.has(hit_key) and player.global_position.distance_to(point) < reach + 9.0 and _clear_line(_locked_origin, point):
					_hit_peers[hit_key] = true
					_world.enemy_attack(self, player, float(_action.get("damage", 8)))
			continue
		var offset := player.global_position - center
		hit = offset.length() <= reach + 9.0
		if type == "cone":
			hit = hit and offset.normalized().dot(_locked_dir) >= cos(deg_to_rad(float(_action.get("arc", 90.0)) * 0.5))
		if hit and not _hit_peers.has(hit_key) and _clear_line(center, player.global_position):
			_hit_peers[hit_key] = true
			_world.enemy_attack(self, player, float(_action.get("damage", 16.0)))


func _update_dead(delta: float) -> void:
	if _respawn_t > 0.0:
		_respawn_t -= delta
		if _respawn_t <= 0.0:
			reset_to_home()
			_world.emit_smoke(global_position + Vector2(0, -20), 8)
	else:
		_fade -= delta * 1.5
		modulate.a = maxf(0.0, _fade)
		if _fade <= 0.0:
			_world.remove_enemy(self)


## Pulo de ataque (todos os peers, via evento do servidor).
func play_attack() -> void:
	_squash_amt = 1.25
	_squash_dur = 120.0
	_squash_t = 0.0


func _update_visuals() -> void:
	_sprite.self_modulate = FLASH_MODULATE if flash_ms > 0.0 else Color.WHITE
	var sy := 1.0
	if _squash_dur > 0.0:
		sy = lerpf(_squash_amt, 1.0, _squash_t / _squash_dur)
	_sprite.scale = Vector2(1.0 + (1.0 - sy) * 0.6, sy)
	if not alive:
		_sprite.rotation = 0.0
		_sprite.frame = _sprite.hframes - 1
		queue_redraw()
		return
	var wobble := _wobble_amp * sin(_wobble_t * 28.0) * exp(-_wobble_t * 7.0)
	if kind == "training_dummy":
		_sprite.rotation = wobble
		_sprite.frame = 0 if absf(wobble) < 0.05 else (1 if wobble < 0.0 else 2)
	else:
		_sprite.rotation = wobble * 0.5
		_sprite.frame = int(_anim_t * 4.0) % 2
		if puppet:
			_sprite.flip_h = _net_flip
		elif absf(velocity.x) > 1.0:
			_sprite.flip_h = velocity.x < 0.0
	_sprite.modulate = Color(0.7, 0.7, 1.0) if stun_t > 0.0 else Color.WHITE
	queue_redraw()


func sprite_flipped() -> bool:
	return _sprite.flip_h


func _draw() -> void:
	if not alive:
		return

	# Telegraphs visuais das ações do inimigo
	var act_type := String(_action.get("type", ""))
	var progress := clampf(_visual_t / maxf(_visual_duration, 0.01), 0.0, 1.0)

	if action_state == "windup":
		var warn_col := Color(1.0, 0.3, 0.15, 0.75)
		var fill_col := Color(1.0, 0.45, 0.15, 0.35)

		match act_type:
			"leap":
				var target_rel := _locked_point - global_position
				var reach := float(_action.get("radius", 18.0))
				draw_line(Vector2.ZERO, target_rel, Color(1.0, 0.4, 0.1, 0.4), 2.0)
				draw_arc(target_rel, reach, 0, TAU, 24, warn_col, 2.0)
				draw_circle(target_rel, reach * progress, fill_col)
			"cone":
				var reach := float(_action.get("radius", 46.0))
				var arc_rad := deg_to_rad(float(_action.get("arc", 90.0)))
				var base_angle := _locked_dir.angle()
				var start_ang := base_angle - arc_rad * 0.5
				var end_ang := base_angle + arc_rad * 0.5
				draw_arc(Vector2.ZERO, reach, start_ang, end_ang, 20, warn_col, 2.0)
				draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(start_ang) * reach, warn_col, 1.5)
				draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(end_ang) * reach, warn_col, 1.5)
				draw_arc(Vector2.ZERO, reach * progress, start_ang, end_ang, 20, fill_col, 3.0)
			"circle":
				var reach := float(_action.get("radius", 48.0))
				draw_arc(Vector2.ZERO, reach, 0, TAU, 28, warn_col, 2.0)
				draw_circle(Vector2.ZERO, reach * progress, fill_col)
			"ground":
				var target_rel := _locked_point - global_position
				var reach := float(_action.get("radius", 50.0))
				draw_arc(target_rel, reach, 0, TAU, 28, warn_col, 2.0)
				draw_circle(target_rel, reach * progress, fill_col)
			"barrage":
				var travel := float(_action.get("travel", 240.0))
				for b in 3:
					var b_dir := _locked_dir.rotated(deg_to_rad(float(b - 1) * 14.0))
					draw_line(Vector2.ZERO, b_dir * (travel * 0.4), Color(1.0, 0.5, 0.2, 0.4), 1.5)
					draw_circle(b_dir * (travel * 0.4 * progress), 3.5, Color(1.2, 0.8, 0.3, 0.8))

	elif action_state == "active" and act_type == "guard":
		var base_angle := _locked_dir.angle()
		draw_arc(Vector2.ZERO, 16.0, base_angle - 1.2, base_angle + 1.2, 16, Color(0.4, 0.75, 1.0, 0.85), 3.0)
		draw_arc(Vector2.ZERO, 20.0, base_angle - 0.8, base_angle + 0.8, 12, Color(0.7, 0.9, 1.0, 0.5), 1.5)

	elif action_state == "stagger":
		var head_y := -38.0 if kind == "slime_awakened" else -54.0
		var t_m := Time.get_ticks_msec() / 200.0
		for s in 3:
			var star_pos := Vector2(cos(t_m + s * 2.09) * 12.0, head_y + sin(t_m + s * 2.09) * 4.0)
			draw_circle(star_pos, 2.5, Color(1.3, 1.2, 0.3))

	# Chamas da Queimadura: uma por acúmulo, tremulando.
	if burn_stacks > 0:
		var t := Time.get_ticks_msec() / 80.0
		var lift := 16.0 if kind == "slime_awakened" else 0.0
		for i in mini(burn_stacks, FLAME_OFFSETS.size()):
			var o := FLAME_OFFSETS[i] + Vector2(0, lift)
			var h := 3.0 + float((int(t) + i * 3) % 3)
			draw_rect(Rect2(o.x, o.y - h, 2, h), Color(1.3, 0.6, 0.15))
			draw_rect(Rect2(o.x, o.y - h - 1.0, 2, 1), Color(1.5, 1.2, 0.5))
