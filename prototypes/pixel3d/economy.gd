# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Ouro e comércio guiados por dados (data/shop.json). Regras puras, usadas igual pelo jogo
## offline (pixel3d_adventure) e pelo servidor (net/server_content.gd, net/server_trade.gd):
## moedas por abate, preços da comerciante, preço de venda dos itens e a bolsa salva.

const PATH := "res://prototypes/pixel3d/data/shop.json"
const POTIONS := ["hp", "mana"]

static var _cache: Dictionary = {}


static func load_data() -> Dictionary:
	if _cache.is_empty() and FileAccess.file_exists(PATH):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if v is Dictionary:
			_cache = v
	return _cache


## Moedas de um abate: valor do tipo (ou base) + per_level por nível da caçada acima do 1.
static func gold_drop(data: Dictionary, kind: String, level: int) -> int:
	var g: Dictionary = data.get("gold_drop", {})
	var base := int((g.get("kinds", {}) as Dictionary).get(kind, g.get("base", 0)))
	return maxi(0, base + int(g.get("per_level", 0)) * maxi(0, level - 1))


## NPC comerciante (id usado por interact) e raio de troca.
static func merchant(data: Dictionary) -> String:
	return String((data.get("merchant", {}) as Dictionary).get("npc", "nessa"))


static func merchant_radius(data: Dictionary) -> float:
	return float((data.get("merchant", {}) as Dictionary).get("radius_m", 2.8))


## Preço de uma poção ("hp" | "mana"); -1 = não vende.
static func buy_price(data: Dictionary, kind: String) -> int:
	return int((data.get("buy", {}) as Dictionary).get(kind, -1)) if kind in POTIONS else -1


## Quanto a comerciante paga por um item (raridade de items.json; sem raridade = basic).
static func sell_price(data: Dictionary, id: String, it: Dictionary) -> int:
	if it.is_empty():
		return 0
	var over: Dictionary = data.get("sell_items", {})
	if over.has(id):
		return int(over[id])
	var rarity := String(it.get("rarity", "basic")) if it.get("rarity") != null else "basic"
	return int((data.get("sell", {}) as Dictionary).get(rarity, 0))


## Bolsa e equipamento salvos (content.bag / content.equipped). false = save antigo sem bolsa
## (quem chama refaz pela regra antiga). Ids desconhecidos, slot errado ou de outra vocação
## são descartados; a bolsa respeita a capacidade.
static func restore_bag(inv: RefCounted, content: Dictionary) -> bool:
	var bag: Variant = content.get("bag")
	if not (bag is Array):
		return false
	inv.items.clear()
	inv.equipped.clear()
	for raw: Variant in bag:
		var id := String(raw)
		if not (inv.item(id) as Dictionary).is_empty() and inv.items.size() < int(inv.capacity()):
			inv.items.append(id)
	var eq: Variant = content.get("equipped", {})
	if eq is Dictionary:
		for slot: Variant in eq:
			var id := String(eq[slot])
			var it: Dictionary = inv.item(id)
			if not it.is_empty() and String(it.get("slot", "")) == String(slot) and inv.can_use(id) == "":
				inv.equipped[String(slot)] = id
	return true
