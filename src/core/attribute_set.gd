class_name AttributeSet
extends RefCounted
## Monta os atributos derivados de uma classe ou inimigo a partir de dados
## (dicionários de atributos e fórmulas fornecidos pelo sistema consumidor).
## Adicionar uma classe nova é só fornecer seus dados.
##
## Uso:
##   var stats := AttributeSet.build(classes["fire_mage"], 1, derived)
##   stats.spell_power  # base + Σ primário × coeficiente + nível × crescimento


## derived = base[stat] + Σ (primary[p] × coeff[stat][p]) + level × growth[stat] + bonus[stat]
## `bonus` (equipamento): chaves derivadas somam direto; as demais somam ao primário
## antes dos coeficientes (ex.: INT +2 também sobe poder mágico e mana).
static func build(def: Dictionary, level: int, derived: Array, bonus: Dictionary = {}) -> Dictionary:
	var primary: Dictionary = (def.get("primary", {}) as Dictionary).duplicate()
	for k: String in bonus:
		if k not in derived:
			primary[k] = float(primary.get(k, 0.0)) + float(bonus[k])
	var base: Dictionary = def.get("base", {})
	var coeff: Dictionary = def.get("coeff", {})
	var growth: Dictionary = def.get("growth", {})
	var out := {"level": level}
	for stat: String in derived:
		var v := float(base.get(stat, 0.0))
		var co: Dictionary = coeff.get(stat, {})
		for p: String in co:
			v += float(primary.get(p, 0.0)) * float(co[p])
		v += level * float(growth.get(stat, 0.0))
		v += float(bonus.get(stat, 0.0))
		out[stat] = v
	return out
