extends RefCounted
## Conteúdo jogável AUTORITATIVO do servidor: missões e segredos (regra pura quests.gd),
## bolsa e equipamento (src/core/inventory.gd), Nessa/baú (first_adventure_state.gd) e as
## recompensas (XP, item da vocação vestido, poções, bônus permanentes).
## Cada jogador (registro de ServerWorld) ganha `p.quests` e `p.inv`; tudo vai para
## `state.content` (persistido no accounts.json pelo character_data), no mesmo formato do
## save offline (quests.snapshot() + equipped + potions).
## Os bônus do equipamento acima do inicial e das relíquias viram números do combate, com a
## mesma conta do cliente (pixel3d_adventure): p.spell_power (dano), p.armor,
## state.bonus_hp e p.mana_bonus.
## O cliente só pede "interagir com X"; aqui se confere andar e distância na posição do servidor.

const Quests := preload("res://src/game/quests.gd")
const ItemInventory := preload("res://src/core/inventory.gd")
const Economy := preload("res://src/game/economy.gd")
const ITEMS_PATH := "res://assets/data/items.json"
const REGIONS_PATH := "res://src/game/data/world_regions.json"
## Iguais a pixel3d_adventure.gd (POWER_STATS, ARMOR_PER_POINT, ARMOR_CAP, raios de interação).
const POWER_STATS := ["attack_power", "spell_power"]
const ARMOR_PER_POINT := 0.02
const ARMOR_CAP := 0.8
const TALK_RADIUS := 2.8
const SECRET_RADIUS := 2.3
const CHEST_RADIUS := 2.2
const EMPTY_QUESTS := {"quests": [], "npcs": {}, "items": {}, "secrets": {}}

var quest_data: Dictionary
var item_db: Dictionary
## data/shop.json: ouro por abate, preços da comerciante (economy.gd).
var shop: Dictionary
var classes: Dictionary
var tuning: Dictionary
var combat: RefCounted
## id do segredo → posição (xz) do marco (world_regions.json).
var secret_pos: Dictionary = {}
## Folga de distância (m) para a diferença predição × servidor.
var tolerance := 1.2
var nessa := Vector3(-14, 0, -25)
var chest := Vector3(-33, -8, -56.2)


## quests.json, items.json e world_regions.json (o mundo injeta; os testes também podem).
static func load_data() -> Dictionary:
	return {"quests": _json(Quests.PATH), "items": _json(ITEMS_PATH), "regions": _json(REGIONS_PATH), "shop": _json(Economy.PATH)}


static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}


func _init(data: Dictionary, classes_data: Dictionary, adventure_tuning: Dictionary, combat_rules: RefCounted, tol := 1.2) -> void:
	var qd: Dictionary = data.get("quests", {})
	quest_data = qd if qd.has("quests") else EMPTY_QUESTS.duplicate(true)
	item_db = data.get("items", {})
	shop = data.get("shop", {}) if data.has("shop") else Economy.load_data()
	classes = classes_data.get("classes", {})
	tuning = adventure_tuning
	combat = combat_rules
	tolerance = tol
	for s: Variant in (data.get("regions", {}) as Dictionary).get("secrets", []):
		if s is Dictionary and (s as Dictionary).has("position"):
			secret_pos[String(s.id)] = Vector2(float(s.position[0]), float(s.position[1]))


# ------------------------------------------------------------------ jogador

## Monta missões e bolsa do jogador a partir de state.content (save do servidor).
func attach(p: Dictionary) -> void:
	var st: RefCounted = p.state
	var q := Quests.new(quest_data)
	q.restore(st.content)
	var v: Dictionary = classes.get(String(p.vocation), {})
	var inv := ItemInventory.new(item_db, String(v.get("item_class", "")))
	var start: Array = v.get("start_items", [])
	inv.give(start)
	for id: Variant in start:
		inv.equip(String(id))
	p.baseline = inv.bonus()
	p.quests = q
	p.inv = inv
	p.gold = maxi(0, int(st.content.get("gold", 0)))
	if not Economy.restore_bag(inv, st.content):   # save antigo: refaz a bolsa pelas recompensas
		if st.has_reward():
			_wear(p, String(tuning.get("reward_item", "")))
		inv.give(q.owned)
		var eq: Variant = st.content.get("equipped", {})
		if eq is Dictionary:
			for slot: Variant in eq:
				var id := String(eq[slot])
				if id in inv.items:
					inv.equip(id)
	refresh(p)
	save(p)


## Bônus de um atributo do equipamento vestido acima do equipamento inicial.
func gear(p: Dictionary, stat: String) -> float:
	return float((p.inv as RefCounted).bonus().get(stat, 0.0)) - float((p.baseline as Dictionary).get(stat, 0.0))


## Recalcula dano extra, armadura, vida e mana máximas (equipamento + relíquias).
func refresh(p: Dictionary) -> void:
	var power := 0.0
	for s: String in POWER_STATS:
		power += gear(p, s)
	p.spell_power = int(round(power))
	var v: Dictionary = classes.get(String(p.vocation), {})
	p.armor = clampf(float(v.get("armor", 0.0)) + gear(p, "armor") * ARMOR_PER_POINT, 0.0, ARMOR_CAP)
	var perm: Dictionary = (p.quests as RefCounted).perm
	var st: RefCounted = p.state
	st.bonus_hp = int(round(gear(p, "max_hp"))) + int(perm.get("max_hp", 0))
	p.mana_bonus = int(round(gear(p, "max_resource"))) + int(perm.get("max_resource", 0))
	if p.has("hp"):
		p.hp = minf(float(p.hp), float(st.max_hp()))
	if p.has("mana"):
		p.mana = minf(float(p.mana), float(combat.max_mana(st.level, p)))


## Grava o conteúdo no state (vai para o disco pelo character_data).
func save(p: Dictionary) -> void:
	if not p.has("quests"):
		return
	var out: Dictionary = (p.quests as RefCounted).snapshot()
	out["equipped"] = ((p.inv as RefCounted).equipped as Dictionary).duplicate()
	out["bag"] = ((p.inv as RefCounted).items as Array).duplicate()
	out["gold"] = int(p.get("gold", 0))
	if p.has("potions"):
		out["potions"] = (p.potions as Dictionary).duplicate()
	(p.state as RefCounted).content = out


## O que o cliente precisa para mostrar diário, objetivo, bolsa e o baú da Nessa.
func client_state(p: Dictionary) -> Dictionary:
	var st: RefCounted = p.state
	return {"quests": (p.quests as RefCounted).snapshot(), "bag": ((p.inv as RefCounted).items as Array).duplicate(),
		"equipped": ((p.inv as RefCounted).equipped as Dictionary).duplicate(), "stage": String(st.stage),
		"lit": (st.lit as Array).duplicate(), "guardians": (st.cave_kills as Dictionary).keys(),
		"gold": int(p.get("gold", 0))}


# ------------------------------------------------------------------ recompensas

func _stats(p: Dictionary) -> Dictionary:
	var st: RefCounted = p.state
	return {"dmg": int(combat.fire_damage(p)), "armor": float(p.armor), "hp": int(st.max_hp()), "mana": int(combat.max_mana(st.level, p))}


## Frases de ganho iguais às do cliente offline ("+3 de dano  +8% de armadura").
static func gains(before: Dictionary, after: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if int(after.dmg) > int(before.dmg):
		out.append("+%d de dano" % (int(after.dmg) - int(before.dmg)))
	if float(after.armor) > float(before.armor) + 0.001:
		out.append("+%d%% de armadura" % roundi((float(after.armor) - float(before.armor)) * 100.0))
	if int(after.hp) > int(before.hp):
		out.append("+%d de vida" % (int(after.hp) - int(before.hp)))
	if int(after.mana) > int(before.mana):
		out.append("+%d de mana" % (int(after.mana) - int(before.mana)))
	return out


func _wear(p: Dictionary, id: String) -> void:
	var inv: RefCounted = p.inv
	if id.is_empty() or (inv.item(id) as Dictionary).is_empty():
		return
	var slot := String(inv.item(id).get("slot", ""))
	if String(inv.equipped.get(slot, "")) != id:
		if not (id in inv.items):
			inv.give([id])
		inv.equip(id)


## Aplica a recompensa e devolve o resumo para o cliente mostrar:
## {xp, item, item_name, gains, potions, perm, level_from, level_to}.
func reward(p: Dictionary, r: Dictionary) -> Dictionary:
	var st: RefCounted = p.state
	var q: RefCounted = p.quests
	var inv: RefCounted = p.inv
	var out := {"xp": 0, "gold": 0, "item": "", "item_name": "", "gains": [], "potions": {}, "perm": {}, "level_from": int(st.level), "level_to": int(st.level)}
	var gold := maxi(0, int(r.get("gold", 0)))
	if gold > 0:
		p.gold = int(p.get("gold", 0)) + gold
		out.gold = gold
	var items: Dictionary = r.get("items", {})
	var item_id := String(items.get(String(p.vocation), ""))
	if not item_id.is_empty() and not (inv.item(item_id) as Dictionary).is_empty():
		var before := _stats(p)
		inv.give([item_id])
		q.owned.append(item_id)
		inv.equip(item_id)
		refresh(p)
		out.item = item_id
		out.item_name = String(inv.item(item_id).get("name", item_id))
		out.gains = gains(before, _stats(p))
	var perm: Dictionary = r.get("perm", {})
	for k: String in perm:
		q.perm[k] = int(q.perm.get(k, 0)) + int(perm[k])
	if not perm.is_empty():
		refresh(p)
		p.hp = float(st.max_hp())
		p.mana = float(combat.max_mana(st.level, p))
		out.perm = perm.duplicate()
	var pots: Dictionary = r.get("potions", {})
	for k: String in pots:
		if k in ["hp", "mana"]:
			p.potions[k] = int(p.potions.get(k, 0)) + int(pots[k])
	out.potions = pots.duplicate()
	var xp := int(r.get("xp", 0))
	if xp > 0:
		st.add_xp(xp)
		out.xp = xp
		if int(st.level) > int(out.level_from):
			refresh(p)
			p.hp = float(st.max_hp())
			p.mana = float(combat.max_mana(st.level, p))
	out.level_to = int(st.level)
	return out


# ------------------------------------------------------------------ eventos

func _no(reason: String) -> Dictionary:
	return {"err": reason, "ev": {}}


func _ok(p: Dictionary, ev: Dictionary) -> Dictionary:
	save(p)
	ev["type"] = "content"
	ev["state"] = client_state(p)
	return {"err": "", "ev": ev}


static func _v2(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


## Pedido "interagir": target = "npc:<id>" | "pickup" | "secret:<id>" | "nessa" | "chest".
## Devolve {err, ev}; err != "" = recusado (range, floor, target, claimed, locked).
func interact(p: Dictionary, target: String) -> Dictionary:
	if not p.has("quests"):
		return _no("target")
	var me: Vector3 = p.ms.pos
	var flat := Vector2(me.x, me.z)
	var fl := int(p.get("floor", 0))
	var parts := target.split(":", true, 1)
	var kind := parts[0]
	var id := parts[1] if parts.size() > 1 else ""
	var q: RefCounted = p.quests
	var st: RefCounted = p.state
	if float(p.get("hp", 1.0)) <= 0.0:
		return _no("dead")
	match kind:
		"npc":
			var npcs: Dictionary = quest_data.get("npcs", {})
			if not npcs.has(id) or not (npcs[id] as Dictionary).has("pos"):
				return _no("target")
			if fl != 0:
				return _no("floor")
			if flat.distance_to(_v2(npcs[id].pos)) > TALK_RADIUS + tolerance:
				return _no("range")
			var r: Dictionary = q.talk(id, int(st.level))
			var ev := {"what": "talk", "npc": id, "event": String(r.event), "quest": String(r.quest), "lines": r.lines}
			if String(r.event) == "complete":
				ev["reward"] = reward(p, r.get("reward", {}))
			return _ok(p, ev)
		"pickup":
			if fl != 0:
				return _no("floor")
			for pk: Dictionary in q.pickups():
				var at: Vector2 = pk.at
				if flat.distance_to(at) <= Quests.PICKUP_RADIUS + tolerance:
					var picked: Dictionary = q.pickup(at)
					return _ok(p, {"what": "quest", "events": [picked], "at": [at.x, at.y]})
			return _no("range")
		"secret":
			if not secret_pos.has(id) or not (quest_data.get("secrets", {}) as Dictionary).has(id):
				return _no("target")
			if fl != 0:
				return _no("floor")
			if flat.distance_to(secret_pos[id]) > SECRET_RADIUS + tolerance:
				return _no("range")
			var entry: Dictionary = q.claim_secret(id)
			if entry.is_empty():
				return _no("claimed")
			return _ok(p, {"what": "secret", "id": id, "reward": reward(p, entry.get("reward", {}))})
		"nessa":
			if fl != 0:
				return _no("floor")
			if flat.distance_to(Vector2(nessa.x, nessa.z)) > TALK_RADIUS + tolerance:
				return _no("range")
			var res := "waiting"
			if st.accept_quest():
				res = "accept"
			elif st.finish_quest():
				res = "finish"
			elif String(st.stage) == "complete":
				res = "after"
			# fora dos momentos da missão, a Nessa também abre a troca (comerciante do acampamento)
			return _ok(p, {"what": "nessa", "result": res, "shop": res in ["after", "waiting"] and Economy.merchant(shop) == "nessa"})
		"chest":
			if fl != -1:
				return _no("floor")
			if flat.distance_to(Vector2(chest.x, chest.z)) > CHEST_RADIUS + tolerance:
				return _no("range")
			if not st.claim_chest():
				return _no("locked")
			var before := _stats(p)
			_wear(p, String(tuning.get("reward_item", "")))
			refresh(p)
			var it := String(tuning.get("reward_item", ""))
			return _ok(p, {"what": "chest", "item": it, "item_name": String((p.inv as RefCounted).item(it).get("name", it)), "gains": gains(before, _stats(p))})
	return _no("target")


## Abate confirmado pelo servidor: progresso das missões (e itens que caem). {} = nada mudou.
func on_kill(p: Dictionary, kind: String, hunt: String, at: Vector2) -> Dictionary:
	if not p.has("quests"):
		return {}
	var evs: Array = (p.quests as RefCounted).on_kill(kind, hunt)
	if evs.is_empty():
		return {}
	return _ok(p, {"what": "quest", "events": evs, "at": [at.x, at.y]}).ev


## Passos "reach" na posição do servidor (só na superfície). {} = nada mudou.
func on_tick(p: Dictionary) -> Dictionary:
	if not p.has("quests") or int(p.get("floor", 0)) != 0:
		return {}
	var me: Vector3 = p.ms.pos
	var evs: Array = (p.quests as RefCounted).on_reach(Vector2(me.x, me.z))
	if evs.is_empty():
		return {}
	return _ok(p, {"what": "quest", "events": evs, "at": [me.x, me.z]}).ev


## Vestir um item da bolsa: o inventário confere se está na bolsa, se é equipável e se a
## vocação pode usar. Devolve {err, ev}.
func equip(p: Dictionary, id: String) -> Dictionary:
	if not p.has("inv"):
		return _no("equip")
	var before := _stats(p)
	var err: String = (p.inv as RefCounted).equip(id)
	if err != "":
		return _no("equip")
	refresh(p)
	var it: Dictionary = (p.inv as RefCounted).item(id)
	return _ok(p, {"what": "equip", "item": id, "item_name": String(it.get("name", id)), "gains": gains(before, _stats(p))})


## Tirar o item do slot e devolver à bolsa. Recusas: "slot" (vazio/desconhecido), "full".
func unequip(p: Dictionary, slot: String) -> Dictionary:
	if not p.has("inv"):
		return _no("slot")
	var inv: RefCounted = p.inv
	var id := String(inv.equipped.get(slot, ""))
	if id.is_empty():
		return _no("slot")
	if (inv.items as Array).size() >= int(inv.capacity()):
		return _no("full")
	var before := _stats(p)
	inv.unequip(slot)
	refresh(p)
	return _ok(p, {"what": "unequip", "slot": slot, "item": id, "item_name": String(inv.item(id).get("name", id)), "gains": gains(before, _stats(p))})


# ------------------------------------------------------------------ ouro e comércio

## Moedas de um abate do servidor (somadas ao jogador). Devolve quantas.
func kill_gold(p: Dictionary, kind: String, level: int) -> int:
	var g := Economy.gold_drop(shop, kind, level)
	if g > 0:
		p.gold = int(p.get("gold", 0)) + g
	return g


## A comerciante está perto o bastante (posição do servidor, superfície)? "" = sim.
func _near_merchant(p: Dictionary) -> String:
	if int(p.get("floor", 0)) != 0:
		return "floor"
	var me: Vector3 = p.ms.pos
	if Vector2(me.x, me.z).distance_to(Vector2(nessa.x, nessa.z)) > Economy.merchant_radius(shop) + tolerance:
		return "range"
	return ""


## Comprar uma poção da comerciante. Recusas: kind, range, floor, gold.
func buy(p: Dictionary, kind: String) -> Dictionary:
	var price := Economy.buy_price(shop, kind)
	if price < 0 or not p.has("potions"):
		return _no("kind")
	var near := _near_merchant(p)
	if near != "":
		return _no(near)
	if int(p.get("gold", 0)) < price:
		return _no("gold")
	p.gold = int(p.gold) - price
	p.potions[kind] = int(p.potions.get(kind, 0)) + 1
	return _ok(p, {"what": "buy", "kind": kind, "price": price})


## Vender um item da bolsa (não vestido). Recusas: item, range, floor.
func sell(p: Dictionary, id: String) -> Dictionary:
	if not p.has("inv"):
		return _no("item")
	var inv: RefCounted = p.inv
	if not (id in inv.items):
		return _no("item")
	var price := Economy.sell_price(shop, id, inv.item(id))
	if price <= 0:
		return _no("item")
	var near := _near_merchant(p)
	if near != "":
		return _no(near)
	(inv.items as Array).erase(id)
	p.gold = int(p.get("gold", 0)) + price
	return _ok(p, {"what": "sell", "item": id, "item_name": String(inv.item(id).get("name", id)), "price": price})
