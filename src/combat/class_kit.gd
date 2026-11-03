class_name ClassKit
extends Node
## Kit de combate de uma classe, guiado por dados (combat_classes.json + combat_abilities.json).
## Serve qualquer classe: Mago de Fogo e Guerreiro hoje, outras só com JSON.
##
## Lado do dono (jogador local): input, mira pelo mouse (tecla arma a skill, clique
## lança no ponto), estados idle → casting/windup → recovery, frame de ataque, e o
## pedido de cast ao servidor no frame de release (anim.attack.release).
## Lado do servidor: valida e paga o custo, cooldowns autoritativos, vida, recurso
## (mana regenera; fúria sobe em combate e decai fora dele), buffs, nível de
## especialização (level_track — Magic Level dos magos) e morte/renascer.
## hp/res/level são autoritativos no servidor e espelhados nos clientes.
##
## Uso:
##   var kit := ClassKit.new()
##   kit.name = "Kit"
##   avatar.add_child(kit)
##   kit.setup(avatar, combat_world, "fire_mage", peer_id)

## Mensagem curta para o HUD ("Fora de alcance", "Mana insuficiente"...).
signal message(text: String)

## Ações da demo automática: tempo (s), slot ou comando.
const DEMO_SCRIPT: Array = [[0.8, "1"], [1.6, "2"], [3.4, "2"], [5.4, "3"], [6.6, "1"], [7.6, "e"], [9.8, "4"], [10.8, "1"], [11.8, "2"]]
const DEMO_LOOP := 15.0

var peer_id := 1
var class_id := ""
var def: Dictionary = {}
var stats: Dictionary = {}
## Soma dos atributos do equipamento vestido (já incluída em `stats`).
var gear_bonus: Dictionary = {}
var hp := 1.0
var res := 0.0
var dead := false
var level := 1
var level_points := 0.0
var level_next := 1.0
var ability_ids: Array = []
var state := "idle"
var current: Dictionary = {}
var cast_t := 0.0
var gcd := 0.0
var cooldowns: Dictionary = {}
## Skill armada esperando o clique (vazio = nenhuma).
var aiming := ""
var damage_reduction := 0.0
## Modo duelo (tecla P): só jogadores com PvP ligado ferem e são feridos por outros jogadores.
var pvp := false
## Ataque básico contínuo (tecla T).
var auto_attack := false
## Combo do Guerreiro: etapa atual (0, 1 ou 2) e tempo restante.
var combo_step := 0
var combo_expires_t := 0.0
## Contagem da Fagulha do Mago (0 a 2; 3ª é empoderada).
var spark_count := 0
var spark_expires_t := 0.0
## Janela de contra-ataque do Grito de Guerra e bônus Resolve para o Quebra.
var has_resolve := false
var resolve_window_t := 0.0
var whirlwind_t := 0.0
## Joga sozinho em loop (argumento `-- --demo`).
var demo := false

var _avatar: PlayerAvatar
var _world: CombatWorld
var _rules: Dictionary
var _anim: Dictionary
var _res_cfg: Dictionary
var _by_slot: Dictionary = {}
var _queued: Dictionary = {}
var _wind_t := 0.0
var _rec_t := 0.0
var _respawn_t := 0.0
var _spawn := Vector2.ZERO
var _server_cd: Dictionary = {}
var _server_combo_step := 0
var _server_combo_expires_t := 0.0
var _dr_t := 0.0
var _since_combat := 99.0
var _demo_t := 0.0
var _demo_i := 0


## Prende o kit ao avatar e ao mundo de combate. `cls` é a chave em combat_classes.json.
func setup(avatar: PlayerAvatar, world: CombatWorld, cls: String, peer: int) -> void:
	_avatar = avatar
	_world = world
	class_id = cls
	peer_id = peer
	_rules = world.rules
	_anim = world.anim.attack
	def = world.classes[cls]
	_res_cfg = world.resources.get(String(def.resource_type), {})
	stats = AttributeSet.build(def, 1, world.derived)
	hp = stats.max_hp
	res = stats.max_resource if bool(_res_cfg.get("start_full", true)) else 0.0
	ability_ids = def.get("abilities", [])
	for id: String in ability_ids:
		_by_slot[int(world.abilities[id].slot)] = id
	var track: Dictionary = def.get("level_track", {})
	level = int(track.get("start", 1))
	level_next = _points_for(level)
	_spawn = avatar.global_position


## Recalcula os atributos com o bônus do equipamento. Roda em todos os peers quando o
## servidor replica uma troca de item; vida/recurso atuais só são limitados ao novo máximo.
func apply_gear(bonus: Dictionary) -> void:
	gear_bonus = bonus
	stats = AttributeSet.build(def, 1, _world.derived, bonus)
	hp = minf(hp, float(stats.max_hp))
	res = minf(res, float(stats.max_resource))
	if _avatar != null:
		_avatar.move_speed = float(stats.get("move_speed", _avatar.move_speed))


# ------------------------------------------------------------------ consultas

func ability(id: String) -> Dictionary:
	return _world.abilities[id]


func display_class() -> String:
	return String(def.get("name", class_id))


func resource_name() -> String:
	return "Fúria" if String(def.resource_type) == "rage" else "Mana"


func resource_color() -> Color:
	return JsonData.to_color(_res_cfg.get("color", [0.24, 0.56, 0.66]))


func has_level_track() -> bool:
	return def.has("level_track")


func level_short() -> String:
	return String(def.get("level_track", {}).get("short", "Nv"))


## Multiplicador de custo pelo nível de especialização (Magic Level reduz o custo).
func cost_mult() -> float:
	var track: Dictionary = def.get("level_track", {})
	if track.is_empty():
		return 1.0
	var pct := float(track.per_level.get("cost_pct", 0.0))
	return maxf(float(track.get("min_cost_mult", 0.5)), 1.0 + pct / 100.0 * (level - 1))


## Multiplicador de dano pelo nível de especialização.
func damage_mult() -> float:
	var track: Dictionary = def.get("level_track", {})
	if track.is_empty():
		return 1.0
	return 1.0 + float(track.per_level.get("damage_pct", 0.0)) / 100.0 * (level - 1)


func effective_cost(ab: Dictionary) -> float:
	return roundf(float(ab.cost) * cost_mult())


## Alcance da skill somando o bônus do nível (Magic Level aumenta o alcance).
func effective_range(ab: Dictionary) -> float:
	var track: Dictionary = def.get("level_track", {})
	var bonus := 0.0
	if not track.is_empty():
		bonus = float(track.per_level.get("range_px", 0.0)) * (level - 1)
	return float(ab.range) + bonus


## Ponto de mira limitado ao alcance (mirar além do alcance lança no limite).
func aim_point(ab: Dictionary, mouse_world: Vector2) -> Vector2:
	if String(ab.aim) == "self":
		return _avatar.global_position
	var from := _avatar.global_position
	var off := mouse_world - from
	var r := effective_range(ab)
	return from + off.limit_length(r)


func is_local() -> bool:
	return _avatar != null and _avatar.is_local()


# ------------------------------------------------------------------ dono (input e estados)

## Input do jogador local. Devolve true se consumiu o evento.
func handle_input(event: InputEvent, mouse_world: Vector2) -> bool:
	if not is_local():
		return false
	if event is InputEventKey and event.pressed:
		var key: int = event.physical_keycode
		if key == KEY_T and not event.echo:
			auto_attack = not auto_attack
			message.emit("Ataque automático: %s" % ("ligado" if auto_attack else "desligado"))
			return true
		if key >= KEY_1 and key <= KEY_4:
			var id := String(_by_slot.get(key - KEY_0, ""))
			if id == "":
				return true
			var ab := ability(id)
			if int(ab.get("slot", 0)) == 1:
				# Quick-cast no cursor para ataque básico (Fagulha / Golpe Pesado)
				try_cast(id, aim_point(ab, mouse_world))
				aiming = ""
			elif String(ab.aim) == "self":
				try_cast(id, _avatar.global_position)
			elif aiming == id and not event.echo:
				try_cast(id, aim_point(ab, mouse_world))  # apertar de novo lança no cursor
				aiming = ""
			else:
				aiming = id
			return true
		if key == KEY_ESCAPE and aiming != "":
			aiming = ""
			return true
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and aiming != "":
			var id := aiming
			aiming = ""
			try_cast(id, aim_point(ability(id), mouse_world))
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT and aiming != "":
			aiming = ""
			return true
	return false


## Tenta lançar `id` em `point` (já limitado ao alcance). Dentro da janela final do
## GCD/cast, entra na fila.
func try_cast(id: String, point: Vector2) -> void:
	if dead or id == "":
		return
	var ab := ability(id)
	if not _can_start():
		var remaining := gcd
		if state == "casting":
			remaining = maxf(remaining, float(current.ability.cast_time) - cast_t)
		elif state == "windup":
			remaining = maxf(remaining, _windup_seconds() - _wind_t)
		if remaining <= float(_rules.spell_queue_window):
			_queued = {"id": id, "point": point}
		return
	if float(cooldowns.get(id, 0.0)) > 0.0:
		message.emit("%s em recarga" % ab.name)
		return
	if res + 0.01 < effective_cost(ab):
		message.emit("%s insuficiente" % resource_name())
		return

	var step := 0
	if id == "heavy_strike" and ab.has("steps"):
		if combo_expires_t <= 0.0:
			combo_step = 0
		step = combo_step
	elif id == "fire_spark":
		if spark_expires_t > 0.0:
			spark_count = (spark_count + 1) % 3
		else:
			spark_count = 0
		step = spark_count

	current = {"id": id, "ability": ab, "point": point, "step": step}
	gcd = float(ab.get("gcd", _rules.gcd))
	if String(ab.aim) != "self":
		_avatar.face_toward(point - _avatar.global_position)
	if float(ab.cast_time) > 0.0:
		state = "casting"
		cast_t = 0.0
	else:
		state = "windup"
		_wind_t = 0.0


func _windup_seconds() -> float:
	if current.has("ability") and current.ability.has("steps"):
		var step_idx: int = int(current.get("step", 0))
		var s_data: Dictionary = current.ability.steps[step_idx]
		if s_data.has("windup"):
			return float(s_data.windup)
	return float(_anim.release) / float(_anim.fps)


func _can_start() -> bool:
	return state != "casting" and state != "windup" and gcd <= 0.0


func _release() -> void:
	var ab: Dictionary = current.ability
	var id: String = current.id
	var point: Vector2 = current.point
	var step: int = int(current.get("step", 0))
	state = "recovery"
	_rec_t = 0.0

	# Lunge procedural no primeiro golpe do Guerreiro
	if id == "heavy_strike" and ab.has("steps"):
		var step_data: Dictionary = ab.steps[step]
		var lunge_dist := float(step_data.get("lunge_px", 0.0))
		if lunge_dist > 0.0:
			var dir := (point - _avatar.global_position).normalized()
			_avatar.lunge(dir, lunge_dist)

	if id == "whirlwind":
		whirlwind_t = float(ab.get("ticks", 3)) * float(ab.get("tick_seconds", 0.3))

	if id == "fire_spark":
		spark_expires_t = float(_rules.get("spark_combo_window", 1.25))

	current = {}
	if float(ab.cooldown) > 0.0:
		cooldowns[id] = float(ab.cooldown)
	if String(ab.aim) == "self":
		point = _avatar.global_position
	_world.request_cast.rpc_id(1, id, point, _avatar.tip_global(), step)


func _local_tick(delta: float) -> void:
	if demo:
		_run_demo(delta)
	gcd = maxf(0.0, gcd - delta)
	for k: String in cooldowns:
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - delta)
	combo_expires_t = maxf(0.0, combo_expires_t - delta)
	if combo_expires_t <= 0.0 and combo_step > 0:
		combo_step = 0
	spark_expires_t = maxf(0.0, spark_expires_t - delta)
	if spark_expires_t <= 0.0:
		spark_count = 0
	whirlwind_t = maxf(0.0, whirlwind_t - delta)
	if _avatar != null:
		_avatar.speed_mult = 0.55 if whirlwind_t > 0.0 else 1.0

	if dead:
		state = "idle"
		current = {}
		aiming = ""
		_avatar.attack_frame = -1
		return
	var moving := _avatar.is_moving()
	var fps := float(_anim.fps)
	var release := int(_anim.release)
	var frames := int(_anim.frames)
	match state:
		"casting":
			if moving and bool(current.ability.get("movement_cancel", true)):
				state = "idle"
				current = {}
				gcd = 0.0
				message.emit("Conjuração cancelada (andou)")
			else:
				cast_t += delta
				_avatar.face_toward(Vector2(current.point) - _avatar.global_position)
				if cast_t >= float(current.ability.cast_time):
					_release()
		"windup":
			_wind_t += delta
			if _wind_t >= _windup_seconds():
				_release()
		"recovery":
			_rec_t += delta
			var rec_duration := float(frames - release) / fps
			if current.has("ability") and current.ability.has("steps"):
				var step_idx: int = int(current.get("step", 0))
				rec_duration = float(current.ability.steps[step_idx].get("recovery", rec_duration))
			if moving or _rec_t >= rec_duration:
				state = "idle"

	# Auto-ataque: se ligado e pronto para agir
	if auto_attack and _can_start() and not dead:
		var basic_id := String(_by_slot.get(1, ""))
		if basic_id != "":
			var basic_ab := ability(basic_id)
			var target := _world.find_auto_attack_target(_avatar.global_position, effective_range(basic_ab) + 20.0)
			if target != null:
				try_cast(basic_id, target.global_position)

	if not _queued.is_empty() and _can_start():
		var q := _queued
		_queued = {}
		try_cast(String(q.id), q.point)
	var f := -1
	match state:
		"casting":
			f = 0 if cast_t < 1.0 / fps else 1 + int(cast_t * fps) % 2
		"windup":
			f = mini(release - 1, int(_wind_t * fps))
		"recovery":
			f = mini(frames - 1, release + int(_rec_t * fps))
	_avatar.attack_frame = f


@rpc("authority", "call_local", "reliable")
func notify_combo(next_step: int, expires_in: float) -> void:
	combo_step = next_step
	combo_expires_t = expires_in


@rpc("authority", "call_local", "reliable")
func notify_resolve(active: bool) -> void:
	has_resolve = active


func _process(delta: float) -> void:
	if _avatar == null:
		return
	if is_local():
		_local_tick(delta)
	if multiplayer.is_server():
		_server_tick(delta)


# ------------------------------------------------------------------ servidor

## Valida e paga o custo de `id`. Devolve "" se pode lançar, ou o motivo da recusa.
func server_try_pay(id: String) -> String:
	if dead:
		return "Você está caído"
	if float(_server_cd.get(id, 0.0)) > 0.05:
		return "Em recarga"
	var ab := ability(id)
	var cost := effective_cost(ab)
	if res + 0.01 < cost:
		return "%s insuficiente" % resource_name()
	res -= cost
	if float(ab.cooldown) > 0.0:
		_server_cd[id] = float(ab.cooldown)
	var track: Dictionary = def.get("level_track", {})
	if String(track.get("gained_by", "")) == "mana_spent" and cost > 0.0:
		_add_level_points(cost)
	_since_combat = 0.0
	return ""


## Dano recebido no servidor, mitigado por armadura e buffs. Devolve o dano final.
func server_take_damage(amount: float) -> float:
	if dead:
		return 0.0
	if resolve_window_t > 0.0:
		has_resolve = true
		notify_resolve.rpc_id(peer_id, true)
	var armor := float(stats.get("armor", 0.0))
	var final := amount * (1.0 - armor / (armor + float(_rules.mitigation_K))) * (1.0 - damage_reduction)
	hp -= final
	_since_combat = 0.0
	server_gain(final * float(_res_cfg.get("gain_per_hp_lost", 0.0)))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		_respawn_t = float(_rules.get("respawn_seconds", 2.0))
	return final


## Ganha recurso (fúria) no servidor, sem passar do máximo.
func server_gain(amount: float) -> void:
	if amount > 0.0:
		res = minf(float(stats.max_resource), res + amount)
		_since_combat = 0.0


## Buff de redução de dano (Grito de Guerra).
func server_buff_damage_reduction(value: float, seconds: float, resolve_window: float = 0.0) -> void:
	damage_reduction = value
	_dr_t = seconds
	if resolve_window > 0.0:
		resolve_window_t = resolve_window


## Avança a etapa do combo de forma autoritativa quando um golpe confirma acerto.
func server_combo_hit_confirmed(id: String, executed_step: int) -> void:
	if id == "heavy_strike":
		var window: float = float(_rules.get("combo_window", 1.05))
		if executed_step == 0:
			_server_combo_step = 1
			_server_combo_expires_t = window
			notify_combo.rpc_id(peer_id, 1, window)
		elif executed_step == 1:
			_server_combo_step = 2
			_server_combo_expires_t = window
			notify_combo.rpc_id(peer_id, 2, window)
		else:
			_server_combo_step = 0
			_server_combo_expires_t = 0.0
			notify_combo.rpc_id(peer_id, 0, 0.0)


func server_combo_reset() -> void:
	_server_combo_step = 0
	_server_combo_expires_t = 0.0
	notify_combo.rpc_id(peer_id, 0, 0.0)


func _server_tick(delta: float) -> void:
	_since_combat += delta
	for k: String in _server_cd:
		_server_cd[k] = maxf(0.0, float(_server_cd[k]) - delta)
	resolve_window_t = maxf(0.0, resolve_window_t - delta)
	_server_combo_expires_t = maxf(0.0, _server_combo_expires_t - delta)
	if _server_combo_expires_t <= 0.0 and _server_combo_step > 0:
		_server_combo_step = 0
		notify_combo.rpc_id(peer_id, 0, 0.0)
	if _dr_t > 0.0:
		_dr_t -= delta
		if _dr_t <= 0.0:
			damage_reduction = 0.0
			resolve_window_t = 0.0
	if dead:
		_respawn_t -= delta
		if _respawn_t <= 0.0:
			dead = false
			hp = stats.max_hp
			res = stats.max_resource if bool(_res_cfg.get("start_full", true)) else 0.0
			_avatar.teleport.rpc_id(peer_id, _spawn)
		return
	res = minf(float(stats.max_resource), res + float(stats.resource_regen) * delta)
	if _since_combat > float(_res_cfg.get("decay_delay_s", INF)):
		res = maxf(0.0, res - float(_res_cfg.get("decay_per_s", 0.0)) * delta)


func _points_for(lv: int) -> float:
	var track: Dictionary = def.get("level_track", {})
	if track.is_empty():
		return INF
	return float(track.base_points) * pow(float(track.growth), lv - 1)


func _add_level_points(points: float) -> void:
	level_points += points
	while level_points >= level_next:
		level_points -= level_next
		level += 1
		level_next = _points_for(level)
		_world.broadcast_level_up(peer_id, level)


# ------------------------------------------------------------------ demo

func _run_demo(delta: float) -> void:
	_demo_t += delta
	if _demo_t >= DEMO_LOOP:
		_demo_t = 0.0
		_demo_i = 0
	while _demo_i < DEMO_SCRIPT.size() and _demo_t >= float(DEMO_SCRIPT[_demo_i][0]):
		var action: String = DEMO_SCRIPT[_demo_i][1]
		_demo_i += 1
		if action == "e":
			_world.request_command.rpc_id(1, "slimes")
			continue
		var id := String(_by_slot.get(int(action), ""))
		if id == "":
			continue
		var target := _world.nearest_enemy_position(_avatar.global_position)
		try_cast(id, aim_point(ability(id), target))
