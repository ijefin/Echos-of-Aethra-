class_name DamageFormula
extends RefCounted
## Fórmula de dano compartilhada por todas as classes
## (design/quick-specs/class-combat-fire-mage-mvp-2026-10-30.md §B).
## O RNG é injetado para os testes serem determinísticos.
##
## Uso:
##   var hit := DamageFormula.compute(ability, caster_stats, target_stats, 1.0, rules, rng)
##   hit.amount  # int
##   hit.crit    # bool


## raw = base + scaling × caster[power_stat]
## final = round(raw × crit_mult × (1 − def / (def + K)) × falloff)
static func compute(ability: Dictionary, caster: Dictionary, target: Dictionary, falloff: float,
		rules: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var raw := float(ability.base) + float(ability.scaling) * float(caster.get(ability.power_stat, 0.0))
	var crit := rng.randf() < float(caster.get("crit_chance", 0.0))
	var defense_stat := "armor" if ability.get("school", "magic") == "physical" else "resist"
	var defense := float(target.get(defense_stat, 0.0))
	var mitigation := defense / (defense + float(rules.mitigation_K))
	var mult := float(rules.crit_damage_mult) if crit else 1.0
	return {"amount": roundi(raw * mult * (1.0 - mitigation) * falloff), "crit": crit}


## 1.0 dentro do raio interno, caindo linearmente até aoe_falloff_min na borda.
static func aoe_falloff(dist: float, radius: float, rules: Dictionary) -> float:
	var inner := radius * float(rules.aoe_inner_radius_ratio)
	if dist <= inner:
		return 1.0
	return 1.0 - clampf((dist - inner) / (radius - inner), 0.0, 1.0) * (1.0 - float(rules.aoe_falloff_min))


## Distância elíptica no chão (vista 3/4): o eixo y conta mais.
static func aoe_dist(center: Vector2, point: Vector2, y_squash: float) -> float:
	return Vector2(point.x - center.x, (point.y - center.y) / y_squash).length()
