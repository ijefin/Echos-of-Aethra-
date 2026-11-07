class_name CombatWorld
extends Node2D
## Combate autoritativo no servidor e espelhado nos clientes.
##
## Servidor: valida e executa skills (projétil, chão, área própria, cone corpo a corpo,
## investida, redemoinho), simula projéteis, inimigos, dano, Queimadura, Ignição,
## provocação e atordoamento, e transmite eventos visuais (`fx`) e snapshots.
## Clientes: só desenham efeitos, números e feel a partir dos eventos.
## Offline (jogar sozinho) é o mesmo caminho: o próprio jogo é o servidor.
##
## Regra MMO (quick spec §F): o hit-stop congela só animação/knockback dos envolvidos.
## Puzzles futuros: escute `element_impact` (elemento, posição, raio) — servidor.
##
## Uso:
##   var world := CombatWorld.new()
##   world.name = "Combat"
##   parent.add_child(world)
##   world.setup(y_sorted_world, textures, local_peer_provider)

## Toda skill que atinge o mundo emite este sinal no servidor (ex.: "fire", pos, 56.0).
signal element_impact(element: String, position: Vector2, radius: float)
## Uma mensagem para o jogador local (ex.: recusa de cast, subiu de nível).
signal local_message(text: String)
## Tremor de tela pedido para o jogador local (0–1 de trauma).
signal local_shake(amount: float)

const TIER_ORDER := {"light": 0, "medium": 1, "heavy": 2}
const CLASSES_PATH := "res://legacy/2d/assets/data/combat_classes.json"
const ABILITIES_PATH := "res://legacy/2d/assets/data/combat_abilities.json"
const RULES_PATH := "res://legacy/2d/assets/data/combat_rules.json"
const ENEMIES_PATH := "res://legacy/2d/assets/data/combat_enemies.json"
const NET_PATH := "res://legacy/2d/assets/data/net_session.json"
const RANGE_TOLERANCE := 16.0

var classes: Dictionary
var resources: Dictionary
var abilities: Dictionary
var passives: Dictionary
var burn_rules: Dictionary
var rules: Dictionary
var feel: Dictionary
var anim: Dictionary
var enemy_data: Dictionary
var net_cfg: Dictionary
var derived: Array
var rng := RandomNumberGenerator.new()
var enemies: Array[Enemy] = []
## peer_id → {"avatar": PlayerAvatar, "kit": ClassKit}
var players: Dictionary = {}
var vfx: CombatVfx

var _world: Node2D
var _textures: Dictionary
var _pending: Array = []
var _projectiles: Array[Dictionary] = []
var _telegraphs: Array[Dictionary] = []
var _scheduled: Array[Dictionary] = []
var _lights: Array[Dictionary] = []
var _light_tex: Texture2D
var _next_id := 1
var _snap_t := 0.0
var _stats_t := 0.0


## Carrega os dados e prende o combate à cena. `world` é o nó com y-sort onde entram
## inimigos; `textures` traz light, shadow e as texturas de inimigo por id.
func setup(world: Node2D, textures: Dictionary) -> void:
	_world = world
	_textures = textures
	_light_tex = textures.get("light")
	var cls := JsonData.load_dict(CLASSES_PATH)
	var abl := JsonData.load_dict(ABILITIES_PATH)
	var rul := JsonData.load_dict(RULES_PATH)
	enemy_data = JsonData.load_dict(ENEMIES_PATH)
	net_cfg = JsonData.load_dict(NET_PATH)
	classes = cls.get("classes", {})
	resources = cls.get("resources", {})
	derived = cls.get("derived", [])
	abilities = abl.get("abilities", {})
	passives = abl.get("passives", {})
	burn_rules = abl.get("status", {}).get("burn", {})
	rules = rul.get("combat", {})
	feel = rul.get("feel", {})
	anim = rul.get("anim", {})
	rng.randomize()
	process_priority = 100  # depois de jogadores e inimigos: agrega os acertos do frame

	vfx = CombatVfx.new()
	vfx.name = "Vfx"
	vfx.y_squash = float(rules.aoe_y_squash)
	vfx.scorch_seconds = float(feel.scorch_seconds)
	add_child(vfx)


## Chamado pela sessão quando o jogo começa (servidor cria os inimigos iniciais).
func start_server_world() -> void:
	for id: String in enemy_data.get("spawns", {}):
		for p: Array in enemy_data.spawns[id]:
			_server_spawn_enemy(id, Vector2(p[0], p[1]))


func register_player(peer: int, avatar: PlayerAvatar, kit: ClassKit) -> void:
	players[peer] = {"avatar": avatar, "kit": kit}


func unregister_player(peer: int) -> void:
	players.erase(peer)


func local_peer() -> int:
	return multiplayer.get_unique_id()


func local_kit() -> ClassKit:
	var p: Dictionary = players.get(local_peer(), {})
	return p.get("kit")


func avatar_of(peer: int) -> PlayerAvatar:
	var p: Dictionary = players.get(peer, {})
	return p.get("avatar")


## Posição do inimigo vivo mais perto de `from` (ou `from` se não houver nenhum).
func nearest_enemy_position(from: Vector2) -> Vector2:
	var best := from + Vector2(0, -80)
	var best_d := INF
	for e in enemies:
		if e.alive and e.global_position.distance_squared_to(from) < best_d:
			best_d = e.global_position.distance_squared_to(from)
			best = e.global_position
	return best


## Inimigo vivo sob o ponto do mundo (para o HUD mostrar informações).
func enemy_near(point: Vector2, radius: float) -> Enemy:
	for e in enemies:
		if e.alive and (e.global_position + Vector2(0, -18)).distance_to(point) <= radius:
			return e
	return null


# ------------------------------------------------------------------ pedidos dos jogadores (servidor)

## Um jogador pede para lançar `id` em `point`; `tip` é a ponta da arma dele.
@rpc("any_peer", "call_local", "reliable")
func request_cast(id: String, point: Vector2, tip: Vector2, step: int = 0) -> void:
	if not multiplayer.is_server():
		return
	var sender := _sender()
	if not players.has(sender):
		return
	var kit: ClassKit = players[sender].kit
	var avatar: PlayerAvatar = players[sender].avatar
	if id not in kit.ability_ids:
		return
	var ab: Dictionary = abilities[id]
	var origin := avatar.global_position
	point = origin + (point - origin).limit_length(kit.effective_range(ab) + RANGE_TOLERANCE)
	if tip.distance_to(origin) > 64.0:
		tip = origin + Vector2(0, -30)
	var err := kit.server_try_pay(id)
	if err != "":
		cast_rejected.rpc_id(sender, err)
		return
	fx.rpc("cast", {"pos": tip, "element": String(ab.get("element", ""))})
	match String(ab.type):
		"projectile":
			_server_launch(ab, sender, tip, point, step)
		"ground":
			_telegraphs.append({"ability": ab, "caster": sender, "pos": point, "t": 0.0, "dur": float(ab.ground.telegraph)})
			fx.rpc("telegraph", {"pos": point, "r": float(ab.aoe.radius), "dur": float(ab.ground.telegraph)})
		"self_aoe":
			_server_self_aoe(ab, sender, origin)
		"melee_combo":
			_server_melee_combo(ab, sender, origin, point, step)
		"melee_cone":
			_server_melee(ab, sender, origin, point)
		"dash":
			avatar.dash_to.rpc_id(sender, point, float(ab.dash_seconds))
			fx.rpc("dash", {"from": origin, "to": point})
			_scheduled.append({"t": float(ab.dash_seconds), "kind": "dash_impact", "ability": ab, "caster": sender, "pos": point})
			kit.server_gain(float(ab.get("rage_gain", 0.0)))
		"spin":
			fx.rpc("whirl", {"peer": sender, "dur": float(ab.ticks) * float(ab.tick_seconds), "r": float(ab.aoe.radius)})
			for i in int(ab.ticks):
				_scheduled.append({"t": i * float(ab.tick_seconds), "kind": "spin_tick", "ability": ab, "caster": sender, "tick_idx": i})


## Comandos de debug da clareira: "slimes" (E) e "reset" (R).
@rpc("any_peer", "call_local", "reliable")
func request_command(cmd: String) -> void:
	if not multiplayer.is_server():
		return
	var avatar := avatar_of(_sender())
	if avatar == null:
		return
	match cmd:
		"slimes":
			_server_spawn_slime_pack(avatar.global_position)
		"reset":
			for e in enemies:
				if e.kind == "training_dummy":
					e.reset_to_home()
		"pvp":
			var kit: ClassKit = players[_sender()].kit
			kit.pvp = not kit.pvp
			fx.rpc("pvp", {"peer": _sender(), "on": kit.pvp})


# ------------------------------------------------------------------ PvP (servidor)

## Jogadores que `caster` pode ferir: os dois precisam estar com o duelo ligado.
func _pvp_targets(caster: int) -> Array[PlayerAvatar]:
	var out: Array[PlayerAvatar] = []
	if not players.has(caster) or not (players[caster].kit as ClassKit).pvp:
		return out
	for peer: int in players:
		if peer == caster:
			continue
		var k: ClassKit = players[peer].kit
		if k.pvp and not k.dead:
			out.append(players[peer].avatar)
	return out


## Uma skill acerta um jogador em duelo: dano reduzido por pvp_damage_mult e empurrão.
func _hit_player(ab: Dictionary, caster: int, target: PlayerAvatar, falloff: float, from: Vector2) -> void:
	if ab.get("no_damage", false):
		return
	var kit: ClassKit = players[caster].kit
	var victim: ClassKit = players[target.peer_id].kit
	var hit := DamageFormula.compute(ab, kit.stats, victim.stats, falloff, rules, rng)
	var amount := float(hit.amount) * kit.damage_mult() * float(rules.get("pvp_damage_mult", 1.0))
	var final := victim.server_take_damage(amount)
	fx.rpc("player_hit", {"peer": target.peer_id, "amount": final, "enemy": "", "crit": hit.crit})
	var kb := float(ab.get("knockback", 0.0))
	if kb > 0.0 and not victim.dead:
		var dir := (target.global_position - from).normalized() if target.global_position.distance_to(from) > 1.0 else Vector2.DOWN
		target.dash_to.rpc_id(target.peer_id, target.global_position + dir * kb, float(rules.get("pvp_knockback_seconds", 0.15)))
	if victim.dead:
		fx.rpc("pvp_kill", {"killer": caster, "victim": target.peer_id})
	if kit.def.resource_type == "rage":
		kit.server_gain(float(ab.get("rage_gain", 0.0)) * 0.5)


@rpc("authority", "call_local", "reliable")
func cast_rejected(text: String) -> void:
	local_message.emit(text)


func _sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return s if s != 0 else multiplayer.get_unique_id()


# ------------------------------------------------------------------ execução das skills (servidor)

func _server_launch(ab: Dictionary, caster: int, tip: Vector2, point: Vector2, step: int = 0) -> void:
	var aim := point + Vector2(0, -14)
	var dist := maxf(12.0, tip.distance_to(aim))
	var dir := (aim - tip).normalized() if dist > 0.5 else Vector2.RIGHT
	var id := _next_id
	_next_id += 1
	var actual_ab := ab
	var is_big := String(ab.projectile.size) == "big"
	if String(ab.get("name", "")) == "Fagulha" and step == 2:
		actual_ab = ab.duplicate(true)
		actual_ab.poise = float(ab.get("poise", 8.0)) * 1.4
		is_big = true
	var proj := {"id": id, "ability": actual_ab, "caster": caster, "pos": tip, "dir": dir, "left": dist}
	_projectiles.append(proj)
	fx.rpc("proj", {"id": id, "pos": tip, "dir": dir, "speed": float(ab.projectile.speed), "left": dist,
		"big": is_big})


func _server_self_aoe(ab: Dictionary, caster: int, c: Vector2) -> void:
	var kit: ClassKit = players[caster].kit
	if ab.has("taunt_seconds"):
		for e in enemies:
			if e.alive and DamageFormula.aoe_dist(c, e.global_position, float(rules.aoe_y_squash)) <= float(ab.aoe.radius):
				e.taunt_peer = caster
				e.taunt_t = float(ab.taunt_seconds)
	if ab.has("buff"):
		kit.server_buff_damage_reduction(float(ab.buff.damage_reduction), float(ab.buff.seconds), float(ab.get("resolve_window", 0.0)))
	elif ab.has("stagger_resist"):
		kit.server_buff_damage_reduction(0.0, float(ab.stagger_resist))
	kit.server_gain(float(ab.get("rage_gain", 0.0)))
	if ab.get("no_damage", false):
		fx.rpc("shout", {"pos": c, "r": float(ab.aoe.radius)})
		return
	explode_at(ab, c, String(ab.tier), caster)
	fx.rpc("nova", {"pos": c, "r": float(ab.aoe.radius)})


func _server_melee_combo(ab: Dictionary, caster: int, c: Vector2, point: Vector2, step: int) -> void:
	var kit: ClassKit = players[caster].kit
	var steps: Array = ab.get("steps", [])
	var step_idx: int = clampi(step, 0, maxi(0, steps.size() - 1))
	var step_data: Dictionary = steps[step_idx] if not steps.is_empty() else ab
	var dir := (point - c).normalized() if point.distance_to(c) > 1.0 else Vector2.RIGHT
	var half := deg_to_rad(float(step_data.get("arc_deg", ab.get("arc_deg", 90.0)))) / 2.0
	var reach := float(step_data.get("range", ab.get("range", 46.0)))
	var hits := 0

	for e in enemies:
		if not e.alive:
			continue
		var to := e.global_position - c
		var dist := DamageFormula.aoe_dist(c, e.global_position, float(rules.aoe_y_squash))
		if dist > reach + e.radius or (to.length() > 4.0 and absf(dir.angle_to(to)) > half):
			continue
		var custom_ab := ab.duplicate(true)
		for k in step_data:
			custom_ab[k] = step_data[k]
		_hit_enemy(custom_ab, e, caster, 1.0, String(step_data.get("tier", "medium")))
		var kb := float(step_data.get("knockback", 0.0))
		if kb > 0.0:
			e.start_knockback(c, kb, float(rules.knockback_duration))
		hits += 1

	for a in _pvp_targets(caster):
		var to := a.global_position - c
		if DamageFormula.aoe_dist(c, a.global_position, float(rules.aoe_y_squash)) > reach + float(rules.pvp_player_radius):
			continue
		if to.length() > 4.0 and absf(dir.angle_to(to)) > half:
			continue
		var custom_ab := ab.duplicate(true)
		for k in step_data:
			custom_ab[k] = step_data[k]
		_hit_player(custom_ab, caster, a, 1.0, c)
		hits += 1

	if hits > 0:
		kit.server_combo_hit_confirmed("heavy_strike", step_idx)
		kit.server_gain(float(step_data.get("rage_gain", 0.0)))
	else:
		kit.server_combo_reset()

	fx.rpc("slash", {"pos": c, "dir": dir, "r": reach, "arc": float(step_data.get("arc_deg", ab.get("arc_deg", 90.0)))})


func _server_melee(ab: Dictionary, caster: int, c: Vector2, point: Vector2) -> void:
	var kit: ClassKit = players[caster].kit
	var dir := (point - c).normalized() if point.distance_to(c) > 1.0 else Vector2.RIGHT
	var half := deg_to_rad(float(ab.arc_deg)) / 2.0
	var hits := 0
	for e in enemies:
		if not e.alive:
			continue
		var to := e.global_position - c
		var dist := DamageFormula.aoe_dist(c, e.global_position, float(rules.aoe_y_squash))
		if dist > float(ab.range) + e.radius or (to.length() > 4.0 and absf(dir.angle_to(to)) > half):
			continue
		_hit_enemy(ab, e, caster, 1.0, String(ab.tier))
		e.start_knockback(c, float(ab.get("knockback", 0.0)), float(rules.knockback_duration))
		hits += 1
	for a in _pvp_targets(caster):
		var to := a.global_position - c
		if DamageFormula.aoe_dist(c, a.global_position, float(rules.aoe_y_squash)) > float(ab.range) + float(rules.pvp_player_radius):
			continue
		if to.length() > 4.0 and absf(dir.angle_to(to)) > half:
			continue
		_hit_player(ab, caster, a, 1.0, c)
		hits += 1
	if hits > 0:
		kit.server_gain(float(ab.get("rage_gain", 0.0)))
	fx.rpc("slash", {"pos": c, "dir": dir, "r": float(ab.range), "arc": float(ab.arc_deg)})


## Aplica dano de uma skill a um inimigo, com Magic Level, Queimadura e Postura (Poise).
func _hit_enemy(ab: Dictionary, e: Enemy, caster: int, falloff: float, tier: String) -> void:
	var kit: ClassKit = players[caster].kit if players.has(caster) else null
	var caster_stats: Dictionary = kit.stats if kit != null else {}
	var hit := DamageFormula.compute(ab, caster_stats, e.stats, falloff, rules, rng)
	var amount := float(hit.amount) * (kit.damage_mult() if kit != null else 1.0)
	if ab.has("damage_mult"):
		amount *= float(ab.damage_mult)

	# Redução por guarda frontal
	var atk_pos: Vector2 = players[caster].avatar.global_position if (kit != null and players.has(caster)) else e.global_position
	amount *= e.incoming_damage_mult(atk_pos)

	deal_damage(e, roundf(amount), tier, hit.crit, "", caster)

	# Aplicação autoritativa de Postura (Poise Damage)
	var poise_dmg := float(ab.get("poise", 10.0))
	if kit != null and kit.has_resolve and String(ab.get("name", "")) == "Quebra":
		poise_dmg *= 1.35
		kit.has_resolve = false
		kit.notify_resolve.rpc_id(caster, false)
	e.apply_poise(poise_dmg)

	if ab.has("burn_stacks"):
		apply_burn(e, int(ab.burn_stacks))
	if ab.get("renews_burn", false) and e.burn_stacks > 0:
		e.burn_time = float(burn_rules.duration)
	if ab.has("off_balance_seconds"):
		e.apply_off_balance(float(ab.off_balance_seconds))
	if ab.has("stun_seconds"):
		e.stun_t = maxf(e.stun_t, float(ab.stun_seconds))


## Explosão em área (elipse no chão). Devolve quantos inimigos acertou.
func explode_at(ab: Dictionary, center: Vector2, tier: String, caster: int) -> int:
	var radius := float(ab.aoe.radius)
	var hits := 0
	for e in enemies:
		if not e.alive:
			continue
		var d := DamageFormula.aoe_dist(center, e.global_position, float(rules.aoe_y_squash))
		if d > radius:
			continue
		_hit_enemy(ab, e, caster, DamageFormula.aoe_falloff(d, radius, rules), tier)
		if ab.has("knockback"):
			e.start_knockback(center, float(ab.knockback), float(rules.knockback_duration))
		hits += 1
	for a in _pvp_targets(caster):
		var d := DamageFormula.aoe_dist(center, a.global_position, float(rules.aoe_y_squash))
		if d <= radius:
			_hit_player(ab, caster, a, DamageFormula.aoe_falloff(d, radius, rules), center)
			hits += 1
	element_impact.emit(String(ab.get("element", "")), center, radius)
	return hits


## Dano no servidor + registro do acerto para o evento "hits" do frame.
func deal_damage(e: Enemy, amount: float, tier: String, crit: bool, style: String, caster: int) -> void:
	if not e.alive or amount <= 0.0:
		return
	var killed := e.apply_damage(amount)
	_pending.append([String(e.name), int(amount), tier, crit, style, caster, killed])


func apply_burn(e: Enemy, stacks: int) -> void:
	if not e.alive:
		return
	if e.burn_stacks == 0:
		e.burn_tick = float(burn_rules.tick_interval)
	e.burn_stacks = mini(int(burn_rules.max_stacks), e.burn_stacks + stacks)
	e.burn_time = float(burn_rules.duration)


func _update_projectiles(delta: float) -> void:
	for i in range(_projectiles.size() - 1, -1, -1):
		var p: Dictionary = _projectiles[i]
		var ab: Dictionary = p.ability
		var step := float(ab.projectile.speed) * delta
		p.pos = Vector2(p.pos) + Vector2(p.dir) * step
		p.left = float(p.left) - step
		var hit_r := float(ab.projectile.get("hit_radius", 10.0))
		var target: Enemy = null
		for e in enemies:
			if e.alive and (e.global_position + Vector2(0, -14)).distance_to(p.pos) <= hit_r + e.radius:
				target = e
				break
		var player_target: PlayerAvatar = null
		if target == null:
			for a in _pvp_targets(int(p.caster)):
				if (a.global_position + Vector2(0, -14)).distance_to(p.pos) <= hit_r + float(rules.pvp_player_radius):
					player_target = a
					break
		if target != null:
			_projectiles.remove_at(i)
			_projectile_hit(p, target)
		elif player_target != null:
			_projectiles.remove_at(i)
			if ab.has("aoe"):
				_projectile_explode(p, player_target.global_position, String(ab.tier))
			else:
				_hit_player(ab, int(p.caster), player_target, 1.0, Vector2(p.pos))
				fx.rpc("proj_end", {"id": p.id, "pos": p.pos, "kind": "spark"})
		elif float(p.left) <= 0.0:
			_projectiles.remove_at(i)
			if ab.projectile.get("explode_at_end", false):
				_projectile_explode(p, Vector2(p.pos) + Vector2(0, 14), String(ab.tier))
			else:
				fx.rpc("proj_end", {"id": p.id, "pos": p.pos, "kind": "fizzle"})


func _projectile_hit(p: Dictionary, target: Enemy) -> void:
	var ab: Dictionary = p.ability
	var caster: int = p.caster
	var kit: ClassKit = players[caster].kit if players.has(caster) else null
	if ab.has("aoe"):
		var tier := String(ab.tier)
		var ig: Dictionary = passives.get("ignite", {})
		if ab.get("ignites", false) and target.burn_stacks >= int(ig.get("threshold", 3)):
			var consumed := mini(target.burn_stacks, int(ig.get("max_consume", 5)))
			var per_stack := float(ig.get("per_stack", 8.0))
			var scaling := float(ig.get("scaling", 0.25))
			var sp := float(kit.stats.get("spell_power", 0.0)) if kit != null else 0.0
			var raw_ignite := consumed * per_stack + sp * scaling
			var resist := float(target.stats.get("resist", 0.0))
			var final_ignite := roundf(raw_ignite * (1.0 - resist / (resist + float(rules.mitigation_K))) * (kit.damage_mult() if kit != null else 1.0))
			target.burn_stacks = 0
			deal_damage(target, final_ignite, String(ig.tier), false, "ignite", caster)
			target.apply_poise(20.0)
			tier = String(ig.tier)
			fx.rpc("ignite", {"pos": target.global_position})
		_projectile_explode(p, target.global_position, tier)
	else:
		_hit_enemy(ab, target, caster, 1.0, String(ab.tier))
		fx.rpc("proj_end", {"id": p.id, "pos": p.pos, "kind": "spark"})
		element_impact.emit(String(ab.get("element", "")), target.global_position, 8.0)


func _projectile_explode(p: Dictionary, center: Vector2, tier: String) -> void:
	var ab: Dictionary = p.ability
	explode_at(ab, center, tier, int(p.caster))
	fx.rpc("proj_end", {"id": p.id, "pos": p.pos, "kind": "explode", "ground": center, "r": float(ab.aoe.radius), "tier": tier})


func _update_telegraphs(delta: float) -> void:
	for i in range(_telegraphs.size() - 1, -1, -1):
		var tg: Dictionary = _telegraphs[i]
		tg.t = float(tg.t) + delta
		if float(tg.t) < float(tg.dur):
			continue
		_telegraphs.remove_at(i)
		explode_at(tg.ability, tg.pos, String(tg.ability.tier), int(tg.caster))
		fx.rpc("pillar", {"pos": tg.pos})


func _update_scheduled(delta: float) -> void:
	for i in range(_scheduled.size() - 1, -1, -1):
		var s: Dictionary = _scheduled[i]
		s.t = float(s.t) - delta
		if float(s.t) > 0.0:
			continue
		_scheduled.remove_at(i)
		var caster: int = s.caster
		var avatar := avatar_of(caster)
		if avatar == null:
			continue
		match String(s.kind):
			"dash_impact":
				explode_at(s.ability, avatar.global_position, String(s.ability.tier), caster)
				fx.rpc("impact", {"pos": avatar.global_position, "r": float(s.ability.aoe.radius)})
			"spin_tick":
				var is_last: bool = int(s.get("tick_idx", 0)) == int(s.ability.get("ticks", 3)) - 1
				var spin_ab: Dictionary = s.ability
				if is_last and (s.ability.has("final_poise") or s.ability.has("final_knockback")):
					spin_ab = s.ability.duplicate(true)
					spin_ab.poise = float(s.ability.get("final_poise", 20.0))
					spin_ab.knockback = float(s.ability.get("final_knockback", 14.0))
				explode_at(spin_ab, avatar.global_position, String(s.ability.tier), caster)


## Encontra o inimigo vivo mais próximo dentro do raio para o ataque automático.
func find_auto_attack_target(from: Vector2, max_dist: float) -> Enemy:
	var best: Enemy = null
	var best_d := max_dist
	for e in enemies:
		if not e.alive:
			continue
		var d := from.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


# ------------------------------------------------------------------ inimigos (servidor)

func _server_spawn_enemy(kind: String, pos: Vector2) -> Enemy:
	var e_name := "E%d" % _next_id
	_next_id += 1
	var e := _create_enemy(e_name, kind, pos, false)
	enemy_spawned.rpc(e_name, kind, pos)
	return e


func _create_enemy(e_name: String, kind: String, pos: Vector2, puppet: bool) -> Enemy:
	var def: Dictionary = enemy_data.enemies[kind]
	var e := Enemy.new()
	e.name = e_name
	e.position = pos
	_world.add_child(e)
	e.setup(kind, def, _textures.get(kind), _textures.get("shadow"), self, derived, puppet)
	enemies.append(e)
	return e


func _server_spawn_slime_pack(around: Vector2) -> void:
	var pack: Dictionary = enemy_data.get("slime_pack", {})
	var alive := enemies.filter(func(e: Enemy) -> bool: return e.kind == "slime_awakened" and e.alive).size()
	for i in int(pack.get("count", 5)):
		if alive + i >= int(pack.get("max_alive", 15)):
			break
		var a := rng.randf() * TAU
		var pos := around + Vector2(cos(a), sin(a) * 0.8) * float(pack.get("distance_px", 170))
		_server_spawn_enemy("slime_awakened", pos)
		fx.rpc("spawn_puff", {"pos": pos})


## Alvo do inimigo: quem provocou (Grito de Guerra) ou o jogador vivo mais perto.
func choose_target(e: Enemy, aggro: float) -> PlayerAvatar:
	if e.taunt_t > 0.0:
		var forced := avatar_of(e.taunt_peer)
		if forced != null and not forced.is_dead():
			return forced
	var best: PlayerAvatar = null
	var best_d := aggro
	for peer: int in players:
		var a: PlayerAvatar = players[peer].avatar
		if a.is_dead():
			continue
		var d := a.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


## Inimigo acerta um jogador (servidor).
func enemy_attack(e: Enemy, target: PlayerAvatar, damage: float) -> void:
	if not players.has(target.peer_id):
		return
	var kit: ClassKit = players[target.peer_id].kit
	var final := kit.server_take_damage(damage)
	fx.rpc("player_hit", {"peer": target.peer_id, "amount": final, "enemy": String(e.name)})


## Remove um inimigo morto (servidor) e avisa os clientes.
func remove_enemy(e: Enemy) -> void:
	enemies.erase(e)
	enemy_removed.rpc(String(e.name))
	e.queue_free()


@rpc("authority", "call_remote", "reliable")
func enemy_spawned(e_name: String, kind: String, pos: Vector2) -> void:
	if _world.get_node_or_null(NodePath(e_name)) != null:
		return
	_create_enemy(e_name, kind, pos, true)


@rpc("authority", "call_remote", "reliable")
func enemy_removed(e_name: String) -> void:
	var e := _world.get_node_or_null(NodePath(e_name)) as Enemy
	if e != null:
		enemies.erase(e)
		e.queue_free()


## Snapshot de todos os inimigos: [nome, x, y, hp, acúmulos, vivo, espelhado] × N.
@rpc("authority", "call_remote", "unreliable_ordered")
func enemy_snapshot(data: Array) -> void:
	var i := 0
	while i + 6 < data.size():
		var e := _world.get_node_or_null(NodePath(String(data[i]))) as Enemy
		if e != null:
			e.apply_snapshot(Vector2(data[i + 1], data[i + 2]), float(data[i + 3]), int(data[i + 4]), bool(data[i + 5]), bool(data[i + 6]))
		i += 7


## Vida, recurso, nível e duelo dos jogadores:
## [peer, hp, res, nível, pontos, próximo, caído, pvp, redução de dano] × N.
@rpc("authority", "call_remote", "unreliable_ordered")
func player_stats(data: Array) -> void:
	var i := 0
	while i + 8 < data.size():
		var peer := int(data[i])
		if players.has(peer):
			var kit: ClassKit = players[peer].kit
			kit.hp = float(data[i + 1])
			kit.res = float(data[i + 2])
			kit.level = int(data[i + 3])
			kit.level_points = float(data[i + 4])
			kit.level_next = float(data[i + 5])
			kit.dead = bool(data[i + 6])
			kit.pvp = bool(data[i + 7])
			kit.damage_reduction = float(data[i + 8])
		i += 9


## Manda o estado atual do mundo para quem acabou de entrar (servidor).
func send_world_to(peer: int) -> void:
	for e in enemies:
		enemy_spawned.rpc_id(peer, String(e.name), e.kind, e.global_position)


func broadcast_level_up(peer: int, level: int) -> void:
	fx.rpc("level_up", {"peer": peer, "level": level})


func _broadcast_state(delta: float) -> void:
	if multiplayer.get_peers().is_empty():
		return
	_snap_t += delta
	if _snap_t >= 1.0 / float(net_cfg.get("snapshot_hz", 20)):
		_snap_t = 0.0
		var data: Array = []
		for e in enemies:
			data.append_array([String(e.name), e.global_position.x, e.global_position.y, e.hp, e.burn_stacks, e.alive, e.sprite_flipped()])
		enemy_snapshot.rpc(data)
	_stats_t += delta
	if _stats_t >= 1.0 / float(net_cfg.get("stats_send_hz", 10)):
		_stats_t = 0.0
		var stats_data: Array = []
		for peer: int in players:
			var k: ClassKit = players[peer].kit
			stats_data.append_array([peer, k.hp, k.res, k.level, k.level_points, k.level_next, k.dead, k.pvp, k.damage_reduction])
		player_stats.rpc(stats_data)


# ------------------------------------------------------------------ eventos visuais (todos os peers)

## Evento visual transmitido pelo servidor. Cada peer desenha por conta própria.
@rpc("authority", "call_local", "reliable")
func fx(kind: String, data: Dictionary) -> void:
	match kind:
		"cast":
			vfx.add_effect("cast_flash", data.pos, 0.12)
			if String(data.get("element", "")) == "fire":
				add_light(data.pos, 1.0, 0.6, 0.12)
				vfx.emit_embers(data.pos, 5, 45.0)
		"proj":
			vfx.add_projectile(int(data.id), data.pos, data.dir, float(data.speed), float(data.left), bool(data.big))
		"proj_end":
			vfx.remove_projectile(int(data.id))
			match String(data.kind):
				"spark":
					vfx.add_effect("spark", data.pos, 0.16)
					add_light(data.pos, 0.6, 0.8, 0.08)
				"explode":
					var g: Vector2 = data.ground
					var heavy := String(data.tier) == "heavy"
					vfx.add_effect("explosion", g, 0.45, {"r": float(data.r)})
					vfx.add_scorch(g)
					vfx.emit_smoke(g + Vector2(0, -10), 8)
					add_light(g + Vector2(0, -10), 1.5 if heavy else 1.1, 1.6 if heavy else 1.3, 0.18)
				_:
					vfx.emit_embers(data.pos, 4, 30.0)
		"ignite":
			vfx.add_effect("pillar", data.pos, 0.35, {"small": true})
		"telegraph":
			vfx.add_telegraph(data.pos, float(data.r), float(data.dur))
		"pillar":
			var c: Vector2 = data.pos
			vfx.add_effect("pillar", c, 0.55)
			vfx.add_scorch(c)
			vfx.emit_smoke(c + Vector2(0, -30), 12)
			add_light(c + Vector2(0, -40), 1.6, 1.8, 0.24)
			for k in 20:
				vfx.emit_embers(c + Vector2(rng.randf_range(-12, 12), -rng.randf_range(0, 90)), 1, 80.0)
		"nova":
			var c: Vector2 = data.pos
			vfx.add_effect("nova", c, 0.35, {"r": float(data.r)})
			add_light(c + Vector2(0, -10), 1.3, 1.5, 0.2)
			for i in 24:
				var a := float(i) / 24.0 * TAU
				vfx.emit_embers(c + Vector2(cos(a) * 30.0, sin(a) * 22.0), 1, 160.0)
		"shout":
			vfx.add_effect("shout", data.pos, 0.5, {"r": float(data.r)})
		"slash":
			vfx.add_effect("slash", data.pos, 0.16, {"dir": data.dir, "r": float(data.r), "arc": float(data.arc)})
		"dash":
			vfx.add_effect("dash", data.from, 0.3, {"to": data.to})
			vfx.emit_smoke(data.from, 6)
		"impact":
			vfx.add_effect("impact", data.pos, 0.3, {"r": float(data.r)})
			vfx.emit_smoke(data.pos, 10)
			_shake_if_local_near(data.pos, 0.35)
		"whirl":
			var a := avatar_of(int(data.peer))
			if a != null:
				vfx.add_effect("whirl", a.global_position, float(data.dur), {"node": a, "r": float(data.r)})
		"hits":
			_apply_hits(data.list)
		"player_hit":
			var a := avatar_of(int(data.peer))
			if a != null:
				a.hit_feel(70.0, 0.0)
				vfx.add_number(a.global_position + Vector2(0, -50), str(int(data.amount)), "player", false)
				if int(data.peer) == local_peer():
					local_shake.emit(0.2)
			if String(data.enemy) != "":
				var e := _world.get_node_or_null(NodePath(String(data.enemy))) as Enemy
				if e != null:
					e.play_attack()
		"pvp":
			var a := avatar_of(int(data.peer))
			if a != null:
				if players.has(int(data.peer)):
					(players[int(data.peer)].kit as ClassKit).pvp = bool(data.on)
				local_message.emit("%s %s o modo duelo" % [a.display_name, "ligou" if bool(data.on) else "desligou"])
		"pvp_kill":
			var killer := avatar_of(int(data.killer))
			var victim := avatar_of(int(data.victim))
			if killer != null and victim != null:
				local_message.emit("%s derrotou %s!" % [killer.display_name, victim.display_name])
				vfx.emit_smoke(victim.global_position + Vector2(0, -16), 12)
		"spawn_puff":
			vfx.emit_smoke(Vector2(data.pos) + Vector2(0, -8), 6)
			vfx.emit_embers(Vector2(data.pos) + Vector2(0, -8), 4, 30.0)
		"level_up":
			var a := avatar_of(int(data.peer))
			if a != null:
				vfx.add_number(a.global_position + Vector2(0, -60), "%s %d!" % [_level_short(int(data.peer)), int(data.level)], "level", false)
				for i in 16:
					vfx.emit_embers(a.global_position + Vector2(0, -20), 1, 70.0)
			if int(data.peer) == local_peer():
				local_message.emit("%s subiu para %d!" % [_level_name(int(data.peer)), int(data.level)])


func _level_short(peer: int) -> String:
	var p: Dictionary = players.get(peer, {})
	var kit: ClassKit = p.get("kit")
	return kit.level_short() if kit != null else "Nv"


func _level_name(peer: int) -> String:
	var p: Dictionary = players.get(peer, {})
	var kit: ClassKit = p.get("kit")
	return String(kit.def.get("level_track", {}).get("name", "Nível")) if kit != null else "Nível"


## Aplica os acertos do frame em todos os peers: números, flash, squash e um único
## hit-stop do maior tier; tremor só para quem lançou.
func _apply_hits(list: Array) -> void:
	var top := "light"
	for h: Array in list:
		if TIER_ORDER[String(h[2])] > TIER_ORDER[top]:
			top = String(h[2])
	var top_cfg: Dictionary = feel.tiers[top]
	var hitstop := float(top_cfg.hitstop)
	var local_hit := false
	for h: Array in list:
		var e := _world.get_node_or_null(NodePath(String(h[0]))) as Enemy
		var style := String(h[4])
		var crit := bool(h[3])
		if e == null:
			continue
		var label := ("IGNIÇÃO " if style == "ignite" else "") + str(int(h[1])) + ("!" if crit else "")
		vfx.add_number(e.global_position + Vector2(0, -46 if e.kind == "training_dummy" else -30), label,
			style if style != "" else String(h[2]), crit)
		var cfg: Dictionary = feel.tiers[String(h[2])]
		e.apply_hit_feel(cfg, hitstop)
		vfx.emit_embers(e.global_position + Vector2(0, -22), int(cfg.embers), 60.0)
		if bool(h[6]):
			vfx.emit_smoke(e.global_position + Vector2(0, -16), 10)
			vfx.emit_embers(e.global_position + Vector2(0, -16), 16, 90.0)
		if int(h[5]) == local_peer():
			local_hit = true
	if local_hit:
		var me := avatar_of(local_peer())
		if me != null and hitstop > 0.0:
			me.hit_feel(0.0, hitstop)
		local_shake.emit(float(top_cfg.shake))


func _shake_if_local_near(pos: Vector2, amount: float) -> void:
	var me := avatar_of(local_peer())
	if me != null and me.global_position.distance_to(pos) < 200.0:
		local_shake.emit(amount)


## Luz de impacto curta (PointLight2D local). Respeita o teto de luzes (art bible §8).
func add_light(pos: Vector2, energy: float, scale_mult: float, duration: float) -> void:
	if _lights.size() >= int(feel.get("max_combat_lights", 6)):
		var oldest: Dictionary = _lights.pop_front()
		(oldest.node as PointLight2D).queue_free()
	var light := PointLight2D.new()
	light.texture = _light_tex
	light.texture_scale = scale_mult
	light.color = Color(1.0, 0.62, 0.28)
	light.energy = energy
	light.global_position = pos
	add_child(light)
	_lights.append({"node": light, "t": 0.0, "dur": duration, "energy": energy})


func emit_smoke(pos: Vector2, count: int) -> void:
	vfx.emit_smoke(pos, count)


func _process(delta: float) -> void:
	if multiplayer.is_server():
		_update_projectiles(delta)
		_update_telegraphs(delta)
		_update_scheduled(delta)
		if not _pending.is_empty():
			var list := _pending.duplicate()
			_pending.clear()
			fx.rpc("hits", {"list": list})
		for peer: int in players:
			var p: Dictionary = players[peer]
			if (p.avatar as PlayerAvatar).is_dead() != (p.kit as ClassKit).dead:
				(p.avatar as PlayerAvatar).set_dead((p.kit as ClassKit).dead)
		_broadcast_state(delta)
	else:
		for peer: int in players:
			var p: Dictionary = players[peer]
			if (p.avatar as PlayerAvatar).is_dead() != (p.kit as ClassKit).dead:
				(p.avatar as PlayerAvatar).set_dead((p.kit as ClassKit).dead)
	for i in range(_lights.size() - 1, -1, -1):
		var l: Dictionary = _lights[i]
		l.t = float(l.t) + delta
		var node: PointLight2D = l.node
		if float(l.t) >= float(l.dur):
			node.queue_free()
			_lights.remove_at(i)
		else:
			node.energy = float(l.energy) * (1.0 - float(l.t) / float(l.dur))
