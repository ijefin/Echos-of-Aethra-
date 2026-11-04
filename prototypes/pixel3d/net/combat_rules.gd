# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Regras de combate do servidor (puras): recarga, mana, nível, alcance, linha de visão, dano,
## por VOCAÇÃO (data/classes.json) e core skills (data/core_skills.json).
## `ch` é o registro do jogador em ServerWorld ({state, mana, cd: {skill → t_pronto}, vocation, ...}).
## Chaves de habilidade (iguais ao cliente e ao snapshot): "fire" = ataque básico da vocação,
## "blink" = Q, "ring" = R, "potion", "light" (core skill).
## Sem classes.json (testes antigos) vale o mago original de first_adventure.json.

var tuning: Dictionary   # data/first_adventure.json
var combat: Dictionary   # net_config.json → combat
var classes: Dictionary  # data/classes.json → classes
var core: Dictionary     # data/core_skills.json → skills
var col: RefCounted


func _init(adventure_tuning: Dictionary, combat_cfg: Dictionary, collision: RefCounted, classes_data: Dictionary = {}, core_data: Dictionary = {}) -> void:
	tuning = adventure_tuning
	combat = combat_cfg
	col = collision
	classes = classes_data.get("classes", {})
	core = core_data.get("skills", {})


## Vocação válida (ou "mage").
func vocation_id(v: Variant) -> String:
	var s := String(v) if v is String else ""
	if classes.is_empty():
		return "mage"
	return s if classes.has(s) else "mage"


func voc(ch: Variant) -> Dictionary:
	if ch is Dictionary:
		return classes.get(String((ch as Dictionary).get("vocation", "mage")), {})
	return classes.get(String(ch), {}) if ch is String else {}


func attack_kind(ch: Dictionary) -> String:
	return String(voc(ch).get("attack", "fireball"))


func q_id(ch: Dictionary) -> String:
	return String((voc(ch).get("q", {}) as Dictionary).get("id", "blink"))


func r_id(ch: Dictionary) -> String:
	return String((voc(ch).get("r", {}) as Dictionary).get("id", "ring"))


func light_cfg() -> Dictionary:
	return core.get("light", {})


func mana_cost(skill: String, ch: Variant = null) -> int:
	if skill == "light":
		return int(light_cfg().get("mana", combat.get("light_mana", 20)))
	var costs: Dictionary = voc(ch).get("costs", {})
	if costs.has(skill):
		return int(costs[skill])
	return int((tuning.get("mana_cost", {}) as Dictionary).get(skill, 0))


func cooldown(skill: String, ch: Variant = null) -> float:
	var v := voc(ch)
	match skill:
		"fire": return float(v.get("attack_t", combat.get("fire_cooldown", 0.42)))
		"blink": return float((v.get("q", {}) as Dictionary).get("cooldown", combat.get("blink_cooldown", tuning.get("blink_cooldown", 3.0))))
		"ring": return float((v.get("r", {}) as Dictionary).get("cooldown", combat.get("ring_cooldown", tuning.get("ring_cooldown", 6.0))))
		"potion": return float(combat.get("potion_cooldown", 1.0))
		"light": return float(light_cfg().get("cooldown", combat.get("light_cooldown", 2.0)))
	return 1.0


func required_level(skill: String) -> int:
	return int(tuning.get(skill + "_level", 1))


func max_mana(level: int, ch: Variant = null) -> int:
	var base := int(tuning.get("mana_base", 40)) + (level - 1) * int(tuning.get("mana_per_level", 6))
	return int(round(base * float(voc(ch).get("mana_mult", 1.0))))


func hp_mult(ch: Variant) -> float:
	return float(voc(ch).get("hp_mult", 1.0))


func armor(ch: Variant) -> float:
	return clampf(float(voc(ch).get("armor", 0.0)), 0.0, 0.9)


func move_speed(ch: Variant, fallback: float) -> float:
	return float(voc(ch).get("speed", fallback))


func light_duration() -> float:
	return float(light_cfg().get("duration", combat.get("light_duration_s", 120.0)))


## "" = pode usar; senão o código do motivo (o cliente mostra só feedback visual).
func can_use(ch: Dictionary, skill: String, now: float) -> String:
	if int(ch.hp) <= 0:
		return "dead"
	if int(ch.state.level) < required_level(skill):
		return "level"
	if now < float((ch.cd as Dictionary).get(skill, 0.0)):
		return "cooldown"
	if float(ch.mana) < float(mana_cost(skill, ch)):
		return "mana"
	return ""


## Debita mana e arma a recarga (chamar só depois de can_use == "").
func commit(ch: Dictionary, skill: String, now: float) -> void:
	ch.mana = float(ch.mana) - float(mana_cost(skill, ch))
	(ch.cd as Dictionary)[skill] = now + cooldown(skill, ch)


## Alvo dentro do alcance (com tolerância de latência) e com linha de visão.
func target_ok(from: Vector3, to: Vector3, max_range: float) -> String:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	if a.distance_to(b) > max_range + float(combat.get("range_tolerance", 1.5)):
		return "range"
	if not col.segment_clear(a, b, 0.05):
		return "los"
	return ""


## Alcance do ataque básico: bola de fogo (velocidade × vida), flecha, ou espada.
func fire_range(ch: Variant = null) -> float:
	var v := voc(ch)
	match String(v.get("attack", "fireball")):
		"arrow":
			return float(v.get("arrow_speed", 24.0)) * float(v.get("arrow_life", 0.75))
		"melee":
			return float(v.get("melee_range", 2.0))
	return float(combat.get("fire_range", 10.4))


## Velocidade e vida do projétil do ataque básico (fogo ou flecha).
func shot_params(ch: Variant, pierce := false) -> Dictionary:
	var v := voc(ch)
	if String(v.get("attack", "fireball")) == "arrow":
		var life := float(v.get("arrow_life", 0.75))
		if pierce:
			life = float((v.get("r", {}) as Dictionary).get("arrow_life", life))
		return {"speed": float(v.get("arrow_speed", 24.0)), "life": life, "name": "pierce" if pierce else "arrow"}
	return {"speed": float(combat.get("shot_speed", 13.0)), "life": float(combat.get("shot_life", 0.8)), "name": "fire"}


## Dano do ataque básico: igual ao cliente (base + nível − 1 + poder mágico) × multiplicador da vocação.
func fire_damage(ch: Dictionary) -> int:
	var base := int(tuning.get("basic_damage", 8)) + int(ch.state.level) - 1 + int(ch.get("spell_power", 0))
	return int(round(base * float(voc(ch).get("damage_mult", 1.0))))


func ring_damage(ch: Dictionary) -> int:
	return int(tuning.get("ring_damage", 18)) + int(ch.state.level) - 1


## Dano das Q/R com multiplicador sobre o básico (investida, redemoinho, perfurante).
func skill_damage(ch: Dictionary, slot: String) -> int:
	var s: Dictionary = voc(ch).get(slot, {})
	return int(round(float(fire_damage(ch)) * float(s.get("damage_mult", 1.0))))


func skill_cfg(ch: Dictionary, slot: String) -> Dictionary:
	return voc(ch).get(slot, {})


## Destino do Eco: dentro do alcance, livre e com visão. Devolve o ponto final ou null.
func blink_target(from: Vector3, to: Vector3, radius: float) -> Variant:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var max_r := float(combat.get("blink_range", 7.0))
	if a.distance_to(b) > max_r:
		b = a + (b - a).normalized() * max_r
	if col.blocked(b, radius) or not col.segment_clear(a, b, 0.05):
		return null
	return Vector3(b.x, col.ground_y(b.x, b.y), b.y)


## Investida / Salto: anda em linha reta até `distance` sem atravessar obstáculo
## (para no primeiro bloqueio). Devolve os pontos do caminho (passos de 0,25 m).
func dash_path(from: Vector3, dir: Vector2, distance: float, radius: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var p := Vector2(from.x, from.z)
	var d := dir.normalized()
	var steps := maxi(1, ceili(distance / 0.25))
	for i in steps:
		var nxt: Vector2 = p + d * (distance / steps)
		var fixed: Vector2 = col.resolve(nxt, radius)
		if fixed.distance_to(p) < (distance / steps) * 0.3:
			break   # bateu de frente: para (raspando na parede ainda desliza)
		p = fixed
		out.append(p)
	return out
