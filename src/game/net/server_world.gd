extends RefCounted
## Simulação autoritativa do mundo compartilhado (pura, sem nós): jogadores, monstros,
## projéteis, dano, XP e recompensas. O transporte (net_server.gd) chama `step(dt)` a
## taxa fixa, entrega comandos/ações e lê `events` + `snapshot_for()`.
##
## IA dos monstros: com `attach_ai(ServerAI)` (servidor dedicado) roda a IA real do jogo
## (`ai/enemy_director.gd`) num World3D headless; sem ela (testes puros) fica a IA MÍNIMA
## de `_monster_ai()` (aggro → perseguir → preparar → golpe → voltar).

const Protocol := preload("res://src/game/net/net_protocol.gd")
const Motion := preload("res://src/game/net/player_motion.gd")
const Validator := preload("res://src/game/net/move_validator.gd")
const Combat := preload("res://src/game/net/combat_rules.gd")
const Interest := preload("res://src/game/net/interest_grid.gd")
const AdventureState := preload("res://src/game/first_adventure_state.gd")
const Content := preload("res://src/game/net/server_content.gd")
const Trade := preload("res://src/game/net/server_trade.gd")

const NPC := Vector3(-14, 0, -25)
const ENTRANCE := Vector3(-38, 0, -28)
## Andar -1 (Gruta das Raízes): mesmos valores de adventure_world.gd (o teste
## tests/unit/net/server_floors_test.gd confere). Copiados para o servidor não carregar a cena.
const ROOM := Vector3(-38, -8, -39)
const STAIRS := [
	{"down": Vector3(-38, 0, -31.3), "arrive": Vector3(-38, -8, -32.0), "up": Vector3(-38, -8, -28.6), "exit": Vector3(-38, 0, -28.4)},
	{"down": Vector3(36, 0, 30.7), "arrive": Vector3(36, -8, 30.2), "up": Vector3(36, -8, 33.0), "exit": Vector3(36, 0, 33.4)},
]
const PORTAL := Vector3(-29.5, -8, -54.5)
const CHEST := Vector3(-33, -8, -56.2)
const TORCHES := [Vector3(0, 0, -9), Vector3(12, 0, -6), Vector3(6, 0, -1.5)]
const CAVE_SPAWNS := [Vector3(-8, 0, 3), Vector3(-4, 0, 5), Vector3(-7, 0, -1), Vector3(-2, 0, 0),
	Vector3(3, 0, -9), Vector3(9, 0, -10), Vector3(9, 0, -4), Vector3(4, 0, -5)]
const TUNNEL_SPAWNS := [[Vector3(28, 0, -1), "spider"], [Vector3(30, 0, 2), "frog"], [Vector3(47, 0, 13), "spider"],
	[Vector3(50, 0, 15), "spider"], [Vector3(46, 0, 16), "frog"], [Vector3(62, 0, 38), "spider"], [Vector3(65, 0, 40), "spider"]]
const STAIR_RADIUS := 1.0
const PORTAL_RADIUS := 1.1
const TORCH_REACH := 12.0

var cfg: Dictionary
var tuning: Dictionary
var col: RefCounted
## Colisão por andar: {0: superfície, -1: gruta}. Sem a gruta, o servidor só tem a superfície.
var floors: Dictionary = {}
var combat: RefCounted
## Missões, segredos, bolsa, equipamento e recompensas (server_content.gd).
var content: RefCounted
## Itens no chão e troca entre jogadores (server_trade.gd).
var trade: RefCounted
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
func _init(net_cfg: Dictionary, adventure_tuning: Dictionary, collision: RefCounted, seed_value := 7, classes_data: Dictionary = {}, core_data: Dictionary = {}, floors_data: Dictionary = {}, content_data: Dictionary = {}) -> void:
	cfg = net_cfg
	tuning = adventure_tuning
	col = collision
	floors = floors_data.duplicate() if not floors_data.is_empty() else {0: collision}
	floors[0] = collision
	combat = Combat.new(tuning, cfg.get("combat", {}), col, classes_data, core_data)
	interest = Interest.new(cfg)
	content = Content.new(content_data if not content_data.is_empty() else Content.load_data(), classes_data, tuning, combat,
		float((cfg.get("combat", {}) as Dictionary).get("interact_tolerance_m", 1.2)))
	content.nessa = NPC
	content.chest = CHEST
	trade = Trade.new(self, content.shop)
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
	# gruta: guardiões (contam para o baú) e bandos do túnel, só se a gruta foi carregada
	if floors.has(-1):
		for g in int(tuning.get("cave_guardians", 0)):
			spawn_monster("cave%d" % g, "spider", ROOM + (CAVE_SPAWNS[g % CAVE_SPAWNS.size()] as Vector3))
		for t_i in TUNNEL_SPAWNS.size():
			var t: Array = TUNNEL_SPAWNS[t_i]
			spawn_monster("tunnel%d" % t_i, String(t[1]), ROOM + (t[0] as Vector3))


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
	var fl := floor_of(pos.y) if floors.has(floor_of(pos.y)) else 0
	var fcol: RefCounted = floors[fl]
	var p2: Vector2 = fcol.resolve(Vector2(pos.x, pos.z), _radius)
	var ms := Motion.new_state(Vector3(p2.x, fcol.ground_y(p2.x, p2.y), p2.y))
	ms.yaw = float(saved.get("yaw", 0.0))
	var pots: Dictionary = tuning.get("potion", {})
	var p := {
		"eid": eid, "key": key, "name": display, "ms": ms, "state": st, "floor": fl, "stair_cd": 0.0,
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
	content.attach(p)   # bolsa, equipamento, missões e bônus (vida/mana máx. podem subir)
	p.hp = clampf(float(saved.get("hp", st.max_hp())), 1.0, float(st.max_hp()))
	var mm := float(combat.max_mana(st.level, p))
	p.mana = clampf(float(saved.get("mana", mm)), 0.0, mm)
	return eid


## Dados persistentes do personagem (o que vai para o disco).
func character_data(eid: int) -> Dictionary:
	var p: Dictionary = players.get(eid, {})
	if p.is_empty():
		return {}
	content.save(p)
	var pos: Vector3 = p.ms.pos
	return {"version": 1, "pos": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)],
		"yaw": snappedf(float(p.ms.yaw), 0.01), "hp": roundi(float(p.hp)), "mana": roundi(float(p.mana)),
		"potions": (p.potions as Dictionary).duplicate(), "progress": (p.state as RefCounted).snapshot(),
		"kills": int(p.kills)}


func remove_player(eid: int) -> Dictionary:
	trade.on_leave(eid)   # troca aberta fecha para o outro lado
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
	if floor_of(pos.y) < 0:
		return "na Gruta das Raízes"
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
##   "interact" (target) · "equip" (item) · "unequip" (slot) · "buy" (kind) · "sell" (item)
##   "drop" (item) · "take" (gid) · "trade_ask" (target) · "trade_add"/"trade_remove" (item)
##   "trade_set" (what gold|hp|mana, n) · "trade_ok" · "trade_cancel"
## Devolve "" se aceita, ou o motivo da recusa (o servidor não confia em nada do cliente).
## Se a ação mudou o que aparece no modelo (arma/escudo/cabeça/peito), avisa quem está perto
## (evento "gear") para os outros clientes redesenharem o personagem.
func player_action(eid: int, act: Dictionary) -> String:
	if not players.has(eid):
		return "no_player"
	var p: Dictionary = players[eid]
	var before := gear_look(p)
	var err := _player_action(p, act)
	var after := gear_look(p)
	if after != before:
		events.append({"to": -1, "type": "gear", "eid": int(p.eid), "gear": after, "at": [p.ms.pos.x, p.ms.pos.z]})
	return err


## Slots do equipamento que aparecem no modelo dos outros jogadores.
const LOOK_SLOTS := ["weapon", "shield", "head", "chest"]


## O equipamento visível do jogador (vai no entity_info e no evento "gear").
func gear_look(p: Dictionary) -> Dictionary:
	var out := {}
	if not p.has("inv"):
		return out
	var eq: Dictionary = (p.inv as RefCounted).equipped
	for s: String in LOOK_SLOTS:
		if not String(eq.get(s, "")).is_empty():
			out[s] = String(eq[s])
	return out


func _player_action(p: Dictionary, act: Dictionary) -> String:
	var a := String(act.get("act", ""))
	combat.col = _col(p)   # alcance/visão/destino no andar do jogador
	match a:
		"torch":
			return _act_torch(p, act)
		"fire", "attack":
			return _act_attack(p, act)
		"blink", "q":
			return _act_q(p, act)
		"ring", "r":
			return _act_r(p, act)
		"potion":
			return _act_potion(p, act)
		"interact":
			return _content_result(p, content.interact(p, String(act.get("target", ""))))
		"equip":
			return _content_result(p, content.equip(p, String(act.get("item", ""))))
		"unequip":
			return _content_result(p, content.unequip(p, String(act.get("slot", ""))))
		"buy":
			return _content_result(p, content.buy(p, String(act.get("kind", ""))))
		"sell":
			return _content_result(p, content.sell(p, String(act.get("item", ""))))
		"drop":
			return trade.drop(p, String(act.get("item", "")))
		"take":
			return trade.take(p, int(act.get("gid", 0)))
		"trade_ask":
			return trade.ask(p, int(act.get("target", 0)))
		"trade_add", "trade_remove":
			return trade.offer(p, String(act.get("item", "")), a == "trade_add")
		"trade_set":
			return trade.set_amount(p, String(act.get("what", "")), int(act.get("n", 0)))
		"trade_ok":
			return trade.confirm(p)
		"trade_cancel":
			return trade.cancel(p)
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


## Resultado do conteúdo ({err, ev}): o evento vai só para o jogador; subida de nível
## pela recompensa gera o mesmo evento "level" do abate.
func _content_result(p: Dictionary, r: Dictionary) -> String:
	if String(r.err) != "":
		return String(r.err)
	_content_event(p, r.ev)
	return ""


func _content_event(p: Dictionary, ev: Dictionary) -> void:
	if ev.is_empty():
		return
	var out := ev.duplicate()
	out["to"] = int(p.eid)
	events.append(out)
	var rw: Dictionary = ev.get("reward", {})
	if not rw.is_empty() and int(rw.level_to) > int(rw.level_from):
		events.append({"to": int(p.eid), "type": "level", "from": int(rw.level_from), "level": int(rw.level_to)})


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
			p.ms.pos = Vector3(end.x, _col(p).ground_y(end.x, end.y), end.y)
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
		if String(m.state) != "dead" and _same_floor(m.pos, me) and Vector2(m.pos.x - me.x, m.pos.z - me.z).length() <= rr + float(_mcfg.get("radius", 0.45)):
			_damage_monster(m, combat.ring_damage(p), int(p.eid))
	return ""


## Tocha das Ruínas (andar -1): o servidor confere andar, distância e linha de visão;
## a ordem e o reinício ficam em first_adventure_state.ignite (regra pura do jogo).
func _act_torch(p: Dictionary, act: Dictionary) -> String:
	var i := int(act.get("index", -1))
	if i < 0 or i >= TORCHES.size():
		return "target"
	if int(p.floor) != -1:
		return "floor"
	var st: RefCounted = p.state
	if st.stage != "active":
		return "stage"
	var tp: Vector3 = ROOM + (TORCHES[i] as Vector3)
	var me: Vector3 = p.ms.pos
	if Vector2(tp.x - me.x, tp.z - me.z).length() > TORCH_REACH:
		return "range"
	var ok: bool = st.ignite(i)
	events.append({"to": int(p.eid), "type": "torch", "index": i, "ok": ok, "lit": (st.lit as Array).duplicate()})
	return "" if ok else "order"


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
		if String(m.state) == "dead" or not _same_floor(m.pos, me):
			continue
		var to := Vector2(m.pos.x, m.pos.z) - a
		if to.length() > reach + float(_mcfg.get("radius", 0.45)):
			continue
		if arc_deg < 359.0 and to.length() > 0.2 and rad_to_deg(absf(dir.angle_to(to.normalized()))) > arc_deg * 0.5:
			continue
		if not _col(p).segment_clear(a, Vector2(m.pos.x, m.pos.z), 0.0):
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
		"pierce": pierce, "hit": [], "name": String(sp.name), "sub": sub, "floor": int(p.floor)}


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
		if tick % 5 == 0 and float(p.hp) > 0.0:
			_content_event(p, content.on_tick(p))   # passos "chegue a" na posição do servidor
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
	trade.step()


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
		Motion.step(trial, c.dir, int(c.flags), v.cmd_dt, _col(p), _move_cfg(p), _radius)
		if v.check_step(before, trial.pos):
			p.ms = trial
	p.stair_cd = maxf(0.0, float(p.stair_cd) - dt)
	if float(p.stair_cd) <= 0.0 and float(p.hp) > 0.0:
		_check_stairs(p)
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


# ------------------------------------------------------------------ andares

## Andar de uma altura (superfície 0, gruta -1).
static func floor_of(y: float) -> int:
	return -1 if y < -4.0 else 0


func _same_floor(a: Vector3, b: Vector3) -> bool:
	return floor_of(a.y) == floor_of(b.y)


func _col(p: Dictionary) -> RefCounted:
	return floors.get(int(p.get("floor", 0)), col)


## Escadas estilo Tibia (sem tecla): pisou na boca desce, pisou na escada sobe; o círculo
## de retorno ao lado do baú leva de volta à Nessa depois do colar.
func _check_stairs(p: Dictionary) -> void:
	if not floors.has(-1):
		return
	var me: Vector3 = p.ms.pos
	var flat := Vector2(me.x, me.z)
	for s: Dictionary in STAIRS:
		var down: Vector3 = s.down
		var up: Vector3 = s.up
		if int(p.floor) == 0 and flat.distance_to(Vector2(down.x, down.z)) < STAIR_RADIUS:
			_warp(p, s.arrive, -1)
			return
		if int(p.floor) == -1 and flat.distance_to(Vector2(up.x, up.z)) < STAIR_RADIUS:
			_warp(p, s.exit, 0)
			return
	if int(p.floor) == -1 and (p.state as RefCounted).has_reward() and flat.distance_to(Vector2(PORTAL.x, PORTAL.z)) < PORTAL_RADIUS:
		_warp(p, NPC + Vector3(0, 0, 2.1), 0)


func _warp(p: Dictionary, to: Vector3, fl: int) -> void:
	var from: Vector3 = p.ms.pos
	var fcol: RefCounted = floors.get(fl, col)
	var q: Vector2 = fcol.resolve(Vector2(to.x, to.z), _radius)
	p.floor = fl
	p.ms = Motion.new_state(Vector3(q.x, fcol.ground_y(q.x, q.y), q.y))
	p.stair_cd = 1.0
	(p.validator as RefCounted).reset_budget()
	events.append({"to": -1, "type": "floor", "eid": int(p.eid), "floor": fl, "from": [from.x, from.z], "at": [q.x, q.y]})


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
			if String(m.state) == "dead" or floor_of(m.pos.y) != int(j.get("floor", 0)):
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
		if not hit and not (floors.get(int(j.get("floor", 0)), col) as RefCounted).segment_clear(Vector2(from.x, from.z), Vector2(to.x, to.z), 0.0):
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
	if st.record_kill(String(m.key), String(m.kind), floor_of((m.home as Vector3).y) < 0, int(m.xp)):
		p.kills = int(p.kills) + 1
		var gold: int = content.kill_gold(p, String(m.kind), int(m.get("level", 1)))   # moedas pelo nível da caçada
		events.append({"to": by, "type": "kill", "target": int(m.eid), "name": String(m.name), "xp": int(m.xp),
			"kind": String(m.kind), "hunt": String(m.get("hunt", "")), "at": [m.pos.x, m.pos.z],
			"gold": gold, "gold_total": int(p.gold)})
		_content_event(p, content.on_kill(p, String(m.kind), String(m.get("hunt", "")), Vector2(m.pos.x, m.pos.z)))
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
		p.floor = 0
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
			"vocation": String(pl.vocation), "light_left": light_left(pl), "gear": gear_look(pl)}
	if monsters.has(id):
		return {"id": id, "kind": Protocol.KIND_MONSTER, "name": String(monsters[id].name), "monster": String(monsters[id].kind),
			"level": int(monsters[id].level)}
	if projectiles.has(id):
		return {"id": id, "kind": Protocol.KIND_PROJECTILE, "name": String(projectiles[id].get("name", "fire")), "owner": int(projectiles[id].owner)}
	if monster_shots.has(id):
		return {"id": id, "kind": Protocol.KIND_PROJECTILE, "name": "web", "owner": 0}
	return {}
