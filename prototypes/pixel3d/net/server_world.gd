# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Simulação autoritativa do mundo compartilhado (pura, sem nós): jogadores, monstros,
## projéteis, dano, XP e recompensas. O transporte (net_server.gd) chama `step(dt)` a
## taxa fixa, entrega comandos/ações e lê `events` + `snapshot_for()`.
##
## IA dos monstros: com `attach_ai(ServerAI)` (servidor dedicado) roda a IA real do jogo
## (`ai/enemy_director.gd`) num World3D headless; sem ela (testes puros) fica a IA MÍNIMA
## de `_monster_ai()` (aggro → perseguir → preparar → golpe → voltar).

const Protocol := preload("res://prototypes/pixel3d/net/net_protocol.gd")
const Motion := preload("res://prototypes/pixel3d/net/player_motion.gd")
const Validator := preload("res://prototypes/pixel3d/net/move_validator.gd")
const Combat := preload("res://prototypes/pixel3d/net/combat_rules.gd")
const Interest := preload("res://prototypes/pixel3d/net/interest_grid.gd")
const AdventureState := preload("res://prototypes/pixel3d/first_adventure_state.gd")

const NPC := Vector3(-14, 0, -25)
const ENTRANCE := Vector3(-38, 0, -28)

var cfg: Dictionary
var tuning: Dictionary
var col: RefCounted
var combat: RefCounted
var interest: RefCounted
var now := 0.0
var tick := 0
var players: Dictionary = {}       # eid → P
var monsters: Dictionary = {}      # eid → M
var projectiles: Dictionary = {}   # eid → J
## Eventos produzidos neste passo: {to: eid | -1 (todos perto de `at`), type, ...}.
var events: Array = []
var _next_id := 100
var _rng := RandomNumberGenerator.new()
var _mcfg: Dictionary
var _mv: Dictionary
var _radius := 0.35
## Adaptador da IA real (net/server_ai.gd) ou null.
var ai: RefCounted = null
## Projéteis de monstro (teia) em voo: eid → dicionário do director.projectiles.
var monster_shots: Dictionary = {}


## `classes_data` = data/classes.json e `core_data` = data/core_skills.json (vazios = só o mago antigo).
func _init(net_cfg: Dictionary, adventure_tuning: Dictionary, collision: RefCounted, seed_value := 7, classes_data: Dictionary = {}, core_data: Dictionary = {}) -> void:
	cfg = net_cfg
	tuning = adventure_tuning
	col = collision
	combat = Combat.new(tuning, cfg.get("combat", {}), col, classes_data, core_data)
	interest = Interest.new(cfg)
	_mcfg = cfg.get("monsters", {})
	_mv = cfg.get("move", {})
	_radius = float(cfg.get("player_radius", 0.35))
	_rng.seed = seed_value
	var i := 0
	for e: Dictionary in tuning.get("field_enemies", []):
		spawn_monster("field%d" % i, String(e.kind), Vector3(float(e.x), 0, float(e.z)), int(e.get("level", 1)), String(e.get("hunt", "")))
		i += 1
	# matilhas de lobos (mesmos pontos do cliente: enemy.wolf.spawns [x, z])
	var wolves: Array = ((tuning.get("enemy", {}) as Dictionary).get("wolf", {}) as Dictionary).get("spawns", [])
	for w_i in wolves.size():
		var w: Array = wolves[w_i]
		spawn_monster("wolf%d" % w_i, "wolf", Vector3(float(w[0]), 0, float(w[1])), int(w[2]) if w.size() > 2 else 1)


## Liga a IA real (ServerAI). Chamar uma vez, logo depois de criar o mundo.
func attach_ai(adapter: RefCounted) -> void:
	ai = adapter
	ai.world = self
	ai.npc = NPC
	for m: Dictionary in monsters.values():
		ai.add_monster(m, m.cfg)


func _id() -> int:
	_next_id += 1
	return _next_id


func _v3(a: Variant, fallback: Vector3) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


# ------------------------------------------------------------------ jogadores

## Entra no mundo com os dados salvos (ou novos). Devolve o eid.
## `vocation` só vale para personagem NOVO (sem vocação salva); validada contra classes.json.
func add_player(key: String, display: String, saved: Dictionary, vocation := "") -> int:
	var eid := _id()
	var st := AdventureState.new(tuning)
	var progress: Dictionary = saved.get("progress", {})
	st.restore(progress)
	st.vocation = combat.vocation_id(progress.get("vocation", vocation) if progress.has("vocation") else vocation)
	st.hp_mult = combat.hp_mult(st.vocation)
	var spawn := _v3(cfg.get("spawn", []), NPC + Vector3(0, 0, 2.3))
	var spread := float(cfg.get("spawn_spread_m", 1.5))
	var fresh := spawn + Vector3(_rng.randf_range(-spread, spread), 0, _rng.randf_range(-spread, spread))
	var pos := _v3(saved.get("pos", []), fresh)
	var p2: Vector2 = col.resolve(Vector2(pos.x, pos.z), _radius)
	var ms := Motion.new_state(Vector3(p2.x, 0, p2.y))
	ms.yaw = float(saved.get("yaw", 0.0))
	var pots: Dictionary = tuning.get("potion", {})
	var p := {
		"eid": eid, "key": key, "name": display, "ms": ms, "state": st,
		"hp": clampf(float(saved.get("hp", st.max_hp())), 1.0, float(st.max_hp())),
		"mana": clampf(float(saved.get("mana", combat.max_mana(st.level, st.vocation))), 0.0, float(combat.max_mana(st.level, st.vocation))),
		"vocation": st.vocation, "speed": combat.move_speed(st.vocation, float(_mv.get("speed", 4.2))),
		"armor": combat.armor(st.vocation),
		"potions": {"hp": int((saved.get("potions", {}) as Dictionary).get("hp", pots.get("start_hp", 3))),
			"mana": int((saved.get("potions", {}) as Dictionary).get("mana", pots.get("start_mana", 3)))},
		"cd": {}, "effects": {}, "invuln_until": 0.0, "last_hurt": -999.0,
		"validator": Validator.new(cfg), "spell_power": 0, "kills": int(saved.get("kills", 0)),
	}
	players[eid] = p
	return eid


## Dados persistentes do personagem (o que vai para o disco).
func character_data(eid: int) -> Dictionary:
	var p: Dictionary = players.get(eid, {})
	if p.is_empty():
		return {}
	var pos: Vector3 = p.ms.pos
	return {"version": 1, "pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)],
		"yaw": snappedf(float(p.ms.yaw), 0.01), "hp": roundi(float(p.hp)), "mana": roundi(float(p.mana)),
		"potions": (p.potions as Dictionary).duplicate(), "progress": (p.state as RefCounted).snapshot(),
		"kills": int(p.kills)}


func remove_player(eid: int) -> Dictionary:
	var data := character_data(eid)
	players.erase(eid)
	interest.forget(eid)
	for m: Dictionary in monsters.values():
		if int(m.target) == eid:
			m.target = 0
	return data


func player_input(eid: int, cmds: Array) -> void:
	if players.has(eid):
		(players[eid].validator as RefCounted).receive(cmds)


func region_of(pos: Vector3) -> String:
	var p := Vector2(pos.x, pos.z)
	if Vector2(ENTRANCE.x, ENTRANCE.z).distance_to(p) < 12.0:
		return "perto da Gruta das Raízes"
	if Vector2(NPC.x, NPC.z).distance_to(p) < 14.0:
		return "nos arredores do acampamento"
	return "na floresta " + ("ao norte" if pos.z < -10.0 else ("ao sul" if pos.z > 10.0 else ("a leste" if pos.x > 0.0 else "a oeste")))


# ------------------------------------------------------------------ ações

## Ação do jogador. act = {act, target: eid, x, z, kind}. Ações:
##   "fire"   ataque básico da vocação (mago: bola de fogo; arqueiro: flecha; guerreiro: golpe em arco)
##   "blink"  Q da vocação (mago: Eco; guerreiro: Investida; arqueiro: Salto Evasivo)
##   "ring"   R da vocação (mago: Anel de Brasa; guerreiro: Redemoinho; arqueiro: Flecha Perfurante)
##   "q"/"r"  sinônimos de blink/ring;  "potion" (kind hp|mana);  "light" (core skill Luz)
## Devolve "" se aceita, ou o motivo da recusa (o servidor não confia em nada do cliente).
func player_action(eid: int, act: Dictionary) -> String:
	if not players.has(eid):
		return "no_player"
	var p: Dictionary = players[eid]
	var a := String(act.get("act", ""))
	match a:
		"fire", "attack":
			return _act_attack(p, act)
		"blink", "q":
			return _act_q(p, act)
		"ring", "r":
			return _act_r(p, act)
		"potion":
			return _act_potion(p, act)
		"light":
			# core skill de luz ("utevo vis lux"): mana + recarga de core_skills.json; relançar renova.
			var err: String = combat.can_use(p, "light", now)
			if err != "":
				return err
			combat.commit(p, "light", now)
			var dur: float = combat.light_duration()
			_set_effect(p, "light", dur)
			events.append({"to": -1, "type": "light", "eid": int(p.eid), "left": dur, "duration": dur, "at": [p.ms.pos.x, p.ms.pos.z]})
			return ""
	return "unknown"


## Segundos restantes da Luz do jogador (0 = apagada). Vai no entity_info para quem chega depois.
func light_left(p: Dictionary) -> float:
	return maxf(0.0, float((p.effects as Dictionary).get("light", now)) - now)


func _act_attack(p: Dictionary, act: Dictionary) -> String:
	var err: String = combat.can_use(p, "fire", now)
	if err != "":
		return err
	var me: Vector3 = p.ms.pos
	var kind: String = combat.attack_kind(p)
	var aim: Variant = _aim_point(act, me, combat.fire_range(p))
	if aim == null:
		return "target"
	var tgt: Vector3 = aim
	if kind == "melee":
		# golpe em arco: alcance da espada (+ raio do monstro + tolerância de latência)
		var reach: float = combat.fire_range(p)
		var tol := float((cfg.get("combat", {}) as Dictionary).get("melee_range_tolerance", 0.6))
		if int(act.get("target", 0)) != 0 and Vector2(tgt.x - me.x, tgt.z - me.z).length() > reach + float(_mcfg.get("radius", 0.45)) + tol:
			return "range"
		combat.commit(p, "fire", now)
		var dir := _face(p, tgt)
		var v: Dictionary = combat.voc(p)
		var hits := _melee(p, dir, reach, float(v.get("melee_arc_deg", 130.0)), combat.fire_damage(p))
		_set_effect(p, "casting", float(v.get("attack_t", 0.5)))
		events.append({"to": -1, "type": "slash", "eid": int(p.eid), "dir": [dir.x, dir.y], "reach": reach, "arc": float(v.get("melee_arc_deg", 130.0)), "hits": hits, "at": [me.x, me.z]})
		return ""
	err = combat.target_ok(me, tgt, combat.fire_range(p))
	if err != "":
		return err
	combat.commit(p, "fire", now)
	_shoot(p, tgt, combat.fire_damage(p), false)
	_set_effect(p, "casting", combat.cooldown("fire", p))
	return ""


## Q: Eco (mago), Investida (guerreiro), Salto Evasivo (arqueiro).
func _act_q(p: Dictionary, act: Dictionary) -> String:
	var err: String = combat.can_use(p, "blink", now)
	if err != "":
		return err
	var me: Vector3 = p.ms.pos
	var to := Vector3(float(act.get("x", me.x)), 0, float(act.get("z", me.z)))
	if not is_finite(to.x) or not is_finite(to.z):
		return "target"
	match combat.q_id(p):
		"charge", "leap":
			var q: Dictionary = combat.skill_cfg(p, "q")
			var d2 := Vector2(to.x - me.x, to.z - me.z)
			var dir := d2.normalized() if d2.length() > 0.3 else Vector2(-sin(float(p.ms.yaw)), -cos(float(p.ms.yaw)))
			var charge: bool = combat.q_id(p) == "charge"
			if not charge:
				dir = -dir   # salta PARA TRÁS em relação à mira
			var path: Array[Vector2] = combat.dash_path(me, dir, float(q.get("distance", 5.0)), _radius)
			if path.is_empty():
				return "blocked"
			combat.commit(p, "blink", now)
			var end: Vector2 = path[path.size() - 1]
			var hit_id := 0
			if charge:
				# o primeiro monstro no caminho leva o golpe e a investida para nele
				for i in path.size():
					for m: Dictionary in monsters.values():
						if String(m.state) != "dead" and path[i].distance_to(Vector2(m.pos.x, m.pos.z)) <= 1.3:
							hit_id = int(m.eid)
							end = path[i]
							break
					if hit_id != 0:
						break
				if hit_id != 0:
					_damage_monster(monsters[hit_id], combat.skill_damage(p, "q"), int(p.eid))
			p.ms.pos = Vector3(end.x, col.ground_y(end.x, end.y), end.y)
			p.ms.dodge_t = -1.0
			p.ms.yaw = atan2(dir.x, dir.y) if not charge else atan2(-dir.x, -dir.y)
			(p.validator as RefCounted).reset_budget()
			var t := float(q.get("time", 0.3))
			_set_effect(p, "dodge", t)   # visual de esquiva/investida para os outros
			p.invuln_until = maxf(float(p.invuln_until), now + t)
			events.append({"to": -1, "type": "dash", "eid": int(p.eid), "skill": combat.q_id(p), "from": [me.x, me.z],
				"at": [end.x, end.y], "time": t, "hit": hit_id})
			return ""
	var dest: Variant = combat.blink_target(me, to, _radius)
	if dest == null:
		return "blocked"
	combat.commit(p, "blink", now)
	p.ms.pos = dest
	p.ms.dodge_t = -1.0
	(p.validator as RefCounted).reset_budget()
	_set_effect(p, "blink", 0.32)
	events.append({"to": -1, "type": "blink", "eid": int(p.eid), "from": [me.x, me.z], "at": [(dest as Vector3).x, (dest as Vector3).z]})
	return ""


## R: Anel de Brasa (mago), Redemoinho de Aço (guerreiro), Flecha Perfurante (arqueiro).
func _act_r(p: Dictionary, act: Dictionary) -> String:
	var err: String = combat.can_use(p, "ring", now)
	if err != "":
		return err
	var me: Vector3 = p.ms.pos
	match combat.r_id(p):
		"whirl":
			combat.commit(p, "ring", now)
			var r: Dictionary = combat.skill_cfg(p, "r")
			var hits := _melee(p, Vector2(-sin(float(p.ms.yaw)), -cos(float(p.ms.yaw))), float(r.get("radius", 2.6)), 360.0, combat.skill_damage(p, "r"))
			_set_effect(p, "ring", 0.6)
			events.append({"to": -1, "type": "whirl", "eid": int(p.eid), "radius": float(r.get("radius", 2.6)), "hits": hits, "at": [me.x, me.z]})
			return ""
		"pierce":
			var sp: Dictionary = combat.shot_params(p, true)
			var aim: Variant = _aim_point(act, me, float(sp.speed) * float(sp.life))
			if aim == null:
				return "target"
			combat.commit(p, "ring", now)
			_shoot(p, aim, combat.skill_damage(p, "r"), true)
			_set_effect(p, "casting", 0.5)
			return ""
	combat.commit(p, "ring", now)
	_set_effect(p, "ring", 0.4)
	var rr := float(tuning.get("ring_radius", 3.2))
	for m: Dictionary in monsters.values():
		if String(m.state) != "dead" and Vector2(m.pos.x - me.x, m.pos.z - me.z).length() <= rr + float(_mcfg.get("radius", 0.45)):
			_damage_monster(m, combat.ring_damage(p), int(p.eid))
	return ""


func _act_potion(p: Dictionary, act: Dictionary) -> String:
	var kind := String(act.get("kind", ""))
	if kind not in ["hp", "mana"]:
		return "kind"
	if now < float((p.cd as Dictionary).get("potion", 0.0)):
		return "cooldown"
	if int(p.potions[kind]) <= 0:
		return "empty"
	var pot: Dictionary = tuning.get("potion", {})
	if kind == "hp":
		if float(p.hp) >= float(p.state.max_hp()):
			return "full"
		p.hp = minf(float(p.state.max_hp()), float(p.hp) + float(pot.get("hp_heal", 45)))
	else:
		var mm := float(combat.max_mana(p.state.level, p))
		if float(p.mana) >= mm:
			return "full"
		p.mana = minf(mm, float(p.mana) + float(pot.get("mana_restore", 35)))
	p.potions[kind] = int(p.potions[kind]) - 1
	(p.cd as Dictionary)["potion"] = now + float(pot.get("cooldown", 1.0))
	return ""


## Vira o jogador para `tgt` e devolve a direção XZ (unitária).
func _face(p: Dictionary, tgt: Vector3) -> Vector2:
	var me: Vector3 = p.ms.pos
	var d := Vector2(tgt.x - me.x, tgt.z - me.z)
	if d.length() < 0.05:
		d = Vector2(-sin(float(p.ms.yaw)), -cos(float(p.ms.yaw)))
	d = d.normalized()
	p.ms.yaw = atan2(-d.x, -d.y)
	return d


## Golpe em setor (arco em graus; 360 = em volta): todos os monstros vivos no alcance
## (+ raio do monstro), dentro do ângulo e com linha livre. Devolve quantos acertou.
func _melee(p: Dictionary, dir: Vector2, reach: float, arc_deg: float, dmg: int) -> int:
	var me: Vector3 = p.ms.pos
	var a := Vector2(me.x, me.z)
	var hits := 0
	for m: Dictionary in monsters.values():
		if String(m.state) == "dead":
			continue
		var to := Vector2(m.pos.x, m.pos.z) - a
		if to.length() > reach + float(_mcfg.get("radius", 0.45)):
			continue
		if arc_deg < 359.0 and to.length() > 0.2 and rad_to_deg(absf(dir.angle_to(to.normalized()))) > arc_deg * 0.5:
			continue
		if not col.segment_clear(a, Vector2(m.pos.x, m.pos.z), 0.0):
			continue
		_damage_monster(m, dmg, int(p.eid))
		hits += 1
	return hits


## Projétil do jogador (bola de fogo, flecha, flecha perfurante).
func _shoot(p: Dictionary, tgt: Vector3, dmg: int, pierce: bool) -> void:
	var me: Vector3 = p.ms.pos
	var d := _face(p, tgt)
	var sp: Dictionary = combat.shot_params(p, pierce)
	var jid := _id()
	var sub := maxi(0, Protocol.PROJECTILE_SUBKINDS.find(String(sp.name)))
	projectiles[jid] = {"eid": jid, "owner": int(p.eid), "pos": me + Vector3(0, 0.85, 0),
		"vel": Vector3(d.x, 0, d.y) * float(sp.speed), "life": float(sp.life), "dmg": dmg,
		"pierce": pierce, "hit": [], "name": String(sp.name), "sub": sub}


## Ponto de mira: entidade alvo (posição do SERVIDOR, não a do cliente) ou ponto no chão.
func _aim_point(act: Dictionary, me: Vector3, max_range: float) -> Variant:
	var tid := int(act.get("target", 0))
	if tid != 0:
		if monsters.has(tid) and String(monsters[tid].state) != "dead":
			return monsters[tid].pos
		if players.has(tid):
			return players[tid].ms.pos
		return null
	if not (act.get("x") is float or act.get("x") is int) or not (act.get("z") is float or act.get("z") is int):
		return null
	var t := Vector3(float(act.x), 0, float(act.z))
	if not is_finite(t.x) or not is_finite(t.z):
		return null
	var d := Vector2(t.x - me.x, t.z - me.z)
	if d.length() > max_range:   # ponto no chão longe: atira na direção até o alcance
		d = d.normalized() * max_range
	return Vector3(me.x + d.x, 0, me.z + d.y)


func _set_effect(p: Dictionary, effect: String, seconds: float) -> void:
	(p.effects as Dictionary)[effect] = now + seconds


# ------------------------------------------------------------------ passo fixo

func step(dt: float) -> void:
	now += dt
	tick += 1
	for p: Dictionary in players.values():
		_step_player(p, dt)
	if ai != null:
		for m: Dictionary in monsters.values():
			_monster_respawn_tick(m)
		ai.step(dt)
		for m: Dictionary in monsters.values():
			if String(m.state) != "dead":
				ai.sync_monster(m)
				m.state = "windup" if bool(m.get("winding", false)) else "live"
		_sync_monster_shots()
	else:
		for m: Dictionary in monsters.values():
			_monster_ai(m, dt)
	_step_projectiles(dt)


func _sync_monster_shots() -> void:
	var alive := {}
	for s: Dictionary in ai.shots():
		if not s.has("eid"):
			s["eid"] = _id()
		alive[int(s.eid)] = s
	monster_shots = alive


func _step_player(p: Dictionary, dt: float) -> void:
	var v: RefCounted = p.validator
	for c: Dictionary in v.take(dt):
		if float(p.hp) <= 0.0:
			continue
		var before: Vector3 = p.ms.pos
		var trial := Motion.copy(p.ms)
		Motion.step(trial, c.dir, int(c.flags), v.cmd_dt, col, _move_cfg(p), _radius)
		if v.check_step(before, trial.pos):
			p.ms = trial
	if float(p.ms.dodge_t) >= 0.0:
		_set_effect(p, "dodge", 0.06)
	var st: RefCounted = p.state
	p.mana = minf(float(combat.max_mana(st.level, p)), float(p.mana) + float(tuning.get("mana_regen_per_second", 2.5)) * dt)
	if now - float(p.last_hurt) > float(tuning.get("regen_delay", 5.0)):
		p.hp = minf(float(st.max_hp()), float(p.hp) + float(tuning.get("regen_per_second", 4.0)) * dt)
	for e: String in (p.effects as Dictionary).keys():
		if now >= float(p.effects[e]):
			(p.effects as Dictionary).erase(e)


## Parâmetros de movimento do jogador agora (lento da teia reduz a velocidade a pé).
func _move_cfg(p: Dictionary) -> Dictionary:
	var speed := float(p.get("speed", _mv.get("speed", 4.2)))   # velocidade da vocação
	if not (p.effects as Dictionary).has("slow") and is_equal_approx(speed, float(_mv.get("speed", 4.2))):
		return _mv
	var mv := _mv.duplicate()
	mv.speed = speed
	if (p.effects as Dictionary).has("slow"):
		mv.speed = speed * float(p.get("slow_factor", _mv.get("slow_factor", 0.55)))
	return mv


## Lento replicado (bit "slow" no snapshot; o cliente aplica move.slow_factor na predição).
func slow_player(eid: int, factor: float, seconds: float) -> void:
	var p: Dictionary = players.get(eid, {})
	if p.is_empty():
		return
	p.slow_factor = clampf(factor, 0.2, 1.0)
	_set_effect(p, "slow", seconds)


func _step_projectiles(dt: float) -> void:
	var mr := float(_mcfg.get("radius", 0.45))
	var sr := float((cfg.get("combat", {}) as Dictionary).get("shot_radius", 0.25))
	for jid: int in projectiles.keys():
		var j: Dictionary = projectiles[jid]
		j.life = float(j.life) - dt
		var from: Vector3 = j.pos
		var to: Vector3 = from + (j.vel as Vector3) * dt
		var hit := false
		# varredura do segmento contra monstros vivos
		for m: Dictionary in monsters.values():
			if String(m.state) == "dead":
				continue
			var mp := Vector2(m.pos.x, m.pos.z)
			var a := Vector2(from.x, from.z)
			var b := Vector2(to.x, to.z)
			var closest := Geometry2D.get_closest_point_to_segment(mp, a, b)
			if closest.distance_to(mp) <= mr + sr:
				if bool(j.get("pierce", false)):
					# perfurante: atravessa monstros, cada um leva o golpe uma vez
					if not (j.hit as Array).has(int(m.eid)):
						(j.hit as Array).append(int(m.eid))
						_damage_monster(m, int(j.dmg), int(j.owner))
					continue
				_damage_monster(m, int(j.dmg), int(j.owner))
				hit = true
				break
		if not hit and not col.segment_clear(Vector2(from.x, from.z), Vector2(to.x, to.z), 0.0):
			hit = true
		j.pos = to
		if hit or float(j.life) <= 0.0:
			projectiles.erase(jid)


# ------------------------------------------------------------------ monstros

## Atributos do tipo escalados pelo nível da caçada (igual a adventure_enemies.scaled_cfg):
## vida, dano de todos os golpes e XP crescem por nível acima do 1 (tuning `enemy_level`).
func scaled_cfg(kind: String, level: int) -> Dictionary:
	var base: Dictionary = (tuning.get("enemy", {}) as Dictionary).get(kind, {})
	if base.is_empty() or level <= 1:
		return base
	var k: Dictionary = tuning.get("enemy_level", {"hp": 0.15, "damage": 0.08, "xp": 0.35})
	var out := base.duplicate()
	var n := level - 1
	out.hp = int(round(float(base.get("hp", 16)) * (1.0 + float(k.get("hp", 0.15)) * n)))
	out.xp = int(round(float(base.get("xp", 1)) * (1.0 + float(k.get("xp", 0.35)) * n)))
	for key: String in ["damage", "leap_damage", "charge_damage", "projectile_damage"]:
		if base.has(key):
			out[key] = int(round(float(base[key]) * (1.0 + float(k.get("damage", 0.08)) * n)))
	out.level = level
	return out


func spawn_monster(key: String, kind: String, at: Vector3, level := 1, hunt := "") -> int:
	var def: Dictionary = scaled_cfg(kind, maxi(1, level))
	if def.is_empty():
		return 0
	var eid := _id()
	monsters[eid] = {"eid": eid, "key": key, "kind": kind, "sub": maxi(0, Protocol.MONSTER_SUBKINDS.find(kind)),
		"name": String(def.get("name", kind)), "home": at, "pos": at, "yaw": 0.0,
		"hp": int(def.get("hp", 16)), "max_hp": int(def.get("hp", 16)), "speed": float(def.get("speed", 1.5)),
		"damage": int(def.get("damage", 6)), "windup": float(def.get("windup", 0.6)), "xp": int(def.get("xp", 1)),
		"state": "idle", "target": 0, "t": 0.0, "next_attack": 0.0, "respawn_at": 0.0,
		"level": maxi(1, level), "cfg": def, "hunt": hunt, "respawn_s": float(def.get("respawn", _mcfg.get("respawn_s", 15.0)))}
	if ai != null:
		ai.add_monster(monsters[eid], def)
	return eid


func _damage_monster(m: Dictionary, amount: int, by: int) -> void:
	if String(m.state) == "dead":
		return
	m.hp = maxi(0, int(m.hp) - amount)
	events.append({"to": -1, "type": "damage", "target": int(m.eid), "amount": amount, "by": by, "at": [m.pos.x, m.pos.z]})
	if ai != null:
		if int(m.hp) > 0:
			ai.on_damaged(m, by)
	elif players.has(by) and int(m.target) == 0:
		m.target = by
		m.state = "chase"
	if int(m.hp) > 0:
		return
	m.state = "dead"
	if ai != null:
		ai.on_killed(m)
	m.target = 0
	m.respawn_at = now + float(m.get("respawn_s", _mcfg.get("respawn_s", 15.0)))
	if not players.has(by):
		return
	# Recompensa calculada SÓ aqui: o cliente apenas recebe o resultado.
	var p: Dictionary = players[by]
	var st: RefCounted = p.state
	var old_level: int = st.level
	if st.record_kill(String(m.key), String(m.kind), false, int(m.xp)):
		p.kills = int(p.kills) + 1
		events.append({"to": by, "type": "kill", "target": int(m.eid), "name": String(m.name), "xp": int(m.xp),
			"kind": String(m.kind), "hunt": String(m.get("hunt", "")), "at": [m.pos.x, m.pos.z]})
		if st.level > old_level:
			p.hp = float(st.max_hp())
			p.mana = float(combat.max_mana(st.level, p))
			events.append({"to": by, "type": "level", "from": old_level, "level": st.level})


func _nearest_player(at: Vector3, radius: float) -> int:
	var best := 0
	var best_d := radius
	for p: Dictionary in players.values():
		if float(p.hp) <= 0.0:
			continue
		var d := Vector2(p.ms.pos.x - at.x, p.ms.pos.z - at.z).length()
		if d < best_d:
			best_d = d
			best = int(p.eid)
	return best


## Morto → renasce em casa depois de `respawn_s`.
func _monster_respawn_tick(m: Dictionary) -> void:
	if String(m.state) != "dead" or now < float(m.respawn_at):
		return
	m.pos = m.home
	m.hp = int(m.max_hp)
	m.state = "idle"
	for p: Dictionary in players.values():
		(p.state as RefCounted).respawn_enemy(String(m.key))
	if ai != null:
		ai.on_respawn(m)


## IA mínima (sem física; só para os testes puros). Estados: idle, chase, windup, return, dead.
func _monster_ai(m: Dictionary, dt: float) -> void:
	var state := String(m.state)
	if state == "dead":
		_monster_respawn_tick(m)
		return
	var home: Vector3 = m.home
	var pos: Vector3 = m.pos
	if Vector2(pos.x - home.x, pos.z - home.z).length() > float(_mcfg.get("leash_m", 14.0)):
		m.state = "return"
		m.target = 0
	if String(m.state) == "idle":
		var t := _nearest_player(pos, float(_mcfg.get("aggro_m", 7.0)))
		if t != 0:
			m.target = t
			m.state = "chase"
	match String(m.state):
		"return":
			_monster_move(m, home, dt)
			if Vector2(m.pos.x - home.x, m.pos.z - home.z).length() < 0.3:
				m.state = "idle"
				m.hp = int(m.max_hp)
		"chase":
			if not players.has(int(m.target)) or float(players[int(m.target)].hp) <= 0.0:
				m.state = "return"
				m.target = 0
				return
			var tp: Vector3 = players[int(m.target)].ms.pos
			var d := Vector2(tp.x - pos.x, tp.z - pos.z).length()
			if d <= float(_mcfg.get("attack_range_m", 1.3)) and now >= float(m.next_attack):
				m.state = "windup"
				m.t = 0.0
			elif d > float(_mcfg.get("attack_range_m", 1.3)) * 0.8:
				_monster_move(m, tp, dt)
		"windup":
			m.t = float(m.t) + dt
			if float(m.t) >= float(m.windup):
				m.next_attack = now + float(_mcfg.get("attack_cooldown_s", 1.4))
				m.state = "chase"
				if players.has(int(m.target)):
					var tp2: Vector3 = players[int(m.target)].ms.pos
					if Vector2(tp2.x - pos.x, tp2.z - pos.z).length() <= float(_mcfg.get("hit_range_m", 1.7)):
						damage_player(int(m.target), int(m.damage), String(m.name))


func _monster_move(m: Dictionary, to: Vector3, dt: float) -> void:
	var pos: Vector3 = m.pos
	var d := Vector2(to.x - pos.x, to.z - pos.z)
	if d.length() < 0.01:
		return
	var stepv := d.normalized() * minf(d.length(), float(m.speed) * dt)
	var np: Vector2 = col.resolve(Vector2(pos.x, pos.z) + stepv, float(_mcfg.get("radius", 0.45)))
	m.pos = Vector3(np.x, 0, np.y)
	m.yaw = atan2(-d.x, -d.y)


## Dano autoritativo no jogador. Devolve se pegou (esquiva/invulnerável/morto = não).
func damage_player(eid: int, amount: int, source: String) -> bool:
	var p: Dictionary = players.get(eid, {})
	if p.is_empty() or float(p.hp) <= 0.0 or now < float(p.invuln_until) or float(p.ms.dodge_t) >= 0.0:
		return false
	amount = maxi(1, roundi(float(amount) * (1.0 - float(p.get("armor", 0.0)))))   # armadura da vocação
	p.hp = maxf(0.0, float(p.hp) - float(amount))
	p.last_hurt = now
	p.invuln_until = now + float((cfg.get("combat", {}) as Dictionary).get("hurt_invulnerable_s", 0.75))
	_set_effect(p, "hurt", 0.3)
	events.append({"to": -1, "type": "damage", "target": eid, "amount": amount, "source": source, "at": [p.ms.pos.x, p.ms.pos.z]})
	if float(p.hp) <= 0.0:
		var rp := _v3(cfg.get("respawn", []), NPC + Vector3(0, 0, 2.3))
		events.append({"to": eid, "type": "death", "source": source})
		p.hp = float((p.state as RefCounted).max_hp())
		p.ms = Motion.new_state(rp)
		(p.validator as RefCounted).reset_budget()
	return true


# ------------------------------------------------------------------ snapshots

## Reconstrói a grade de interesse (uma vez por snapshot).
func index_interest() -> void:
	interest.clear()
	for p: Dictionary in players.values():
		interest.put(int(p.eid), p.ms.pos, 0)
	for m: Dictionary in monsters.values():
		if String(m.state) != "dead":
			interest.put(int(m.eid), m.pos, 1)
	for j: Dictionary in projectiles.values():
		interest.put(int(j.eid), j.pos, 2)
	for s: Dictionary in monster_shots.values():
		interest.put(int(s.eid), s.pos, 2)


func _player_effects(p: Dictionary) -> int:
	return Protocol.effect_bits((p.effects as Dictionary).keys())


## {me, entities, entered, ack} para o jogador `eid`.
func snapshot_for(eid: int) -> Dictionary:
	var p: Dictionary = players[eid]
	var st: RefCounted = p.state
	var cd: Dictionary = p.cd
	var me := {"pos": p.ms.pos, "dodge_t": p.ms.dodge_t, "dodge_cd": p.ms.dodge_cd, "dodge_dir": p.ms.dodge_dir,
		"hp": roundi(float(p.hp)), "max_hp": st.max_hp(), "mana": floori(float(p.mana)), "max_mana": combat.max_mana(st.level, p),
		"level": st.level, "xp": st.xp, "xp_req": st.xp_required(),
		"pot_hp": p.potions.hp, "pot_mana": p.potions.mana, "effects": _player_effects(p)}
	for k: String in ["fire", "blink", "ring", "potion"]:
		me["cd_" + k] = maxf(0.0, float(cd.get(k, 0.0)) - now)
	var q: Dictionary = interest.query(eid, p.ms.pos)
	var list: Array = []
	for id: int in q.visible:
		list.append(entity_state(id))
	return {"me": me, "entities": list, "entered": q.entered, "ack": int((p.validator as RefCounted).last_seq)}


func entity_state(id: int) -> Dictionary:
	if players.has(id):
		var o: Dictionary = players[id]
		return {"id": id, "kind": Protocol.KIND_PLAYER, "sub": 0, "pos": o.ms.pos, "yaw": o.ms.yaw,
			"hp": roundi(float(o.hp)), "max_hp": (o.state as RefCounted).max_hp(), "effects": _player_effects(o)}
	if monsters.has(id):
		var m: Dictionary = monsters[id]
		var fx: Array = ["windup"] if String(m.state) == "windup" else []
		return {"id": id, "kind": Protocol.KIND_MONSTER, "sub": int(m.sub), "pos": m.pos, "yaw": m.yaw,
			"hp": int(m.hp), "max_hp": int(m.max_hp), "effects": Protocol.effect_bits(fx)}
	if projectiles.has(id):
		var j: Dictionary = projectiles[id]
		var v: Vector3 = j.vel
		return {"id": id, "kind": Protocol.KIND_PROJECTILE, "sub": int(j.get("sub", 0)), "pos": j.pos, "yaw": atan2(-v.x, -v.z),
			"hp": 0, "max_hp": 0, "effects": 0}
	if monster_shots.has(id):
		var s: Dictionary = monster_shots[id]
		var sv: Vector3 = s.vel
		return {"id": id, "kind": Protocol.KIND_PROJECTILE, "sub": Protocol.PROJECTILE_SUBKINDS.find("web"), "pos": s.pos, "yaw": atan2(-sv.x, -sv.z),
			"hp": 0, "max_hp": 0, "effects": 0}
	return {}


## Informação estática enviada (confiável) quando a entidade entra na área de interesse.
func entity_info(id: int) -> Dictionary:
	if players.has(id):
		var pl: Dictionary = players[id]
		return {"id": id, "kind": Protocol.KIND_PLAYER, "name": String(pl.name), "level": int(pl.state.level),
			"vocation": String(pl.vocation), "light_left": light_left(pl)}
	if monsters.has(id):
		return {"id": id, "kind": Protocol.KIND_MONSTER, "name": String(monsters[id].name), "monster": String(monsters[id].kind),
			"level": int(monsters[id].level)}
	if projectiles.has(id):
		return {"id": id, "kind": Protocol.KIND_PROJECTILE, "name": String(projectiles[id].get("name", "fire")), "owner": int(projectiles[id].owner)}
	if monster_shots.has(id):
		return {"id": id, "kind": Protocol.KIND_PROJECTILE, "name": "web", "owner": 0}
	return {}
