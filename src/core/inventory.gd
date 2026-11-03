class_name Inventory
extends RefCounted
## Inventário e equipamento de um personagem, guiado por dados (assets/data/items.json).
## Lógica pura: o servidor guarda um por jogador e replica; nada aqui toca rede ou cena.
## Item = id em items.json com slot, classes que podem usar, atributos e (opcional) sprite.
##
## Uso:
##   var inv := Inventory.new(Inventory.load_db(), "fire_mage")
##   inv.give(["fire_staff", "ember_amulet"])   # → ids aceitos
##   inv.equip("fire_staff")                    # → "" ou motivo da recusa
##   AttributeSet.build(def, 1, derived, inv.bonus())

const DB_PATH := "res://assets/data/items.json"

static var _db_cache: Dictionary = {}

var db: Dictionary
var class_id := ""
## Itens na mochila (um id por item; equipamento não empilha).
var items: Array[String] = []
## Slot → id do item vestido.
var equipped: Dictionary = {}


func _init(item_db: Dictionary, cls: String) -> void:
	db = item_db
	class_id = cls


## items.json, lido uma vez.
static func load_db() -> Dictionary:
	if _db_cache.is_empty():
		_db_cache = JsonData.load_dict(DB_PATH)
	return _db_cache


func item(id: String) -> Dictionary:
	return db.get("items", {}).get(id, {})


func capacity() -> int:
	return int(db.get("inventory_size", 30))


## Põe itens na mochila. Ids desconhecidos e o que passar da capacidade são recusados.
## Retorna os ids aceitos.
func give(ids: Array) -> Array[String]:
	var accepted: Array[String] = []
	for raw: Variant in ids:
		var id := String(raw)
		if item(id).is_empty() or items.size() >= capacity():
			continue
		items.append(id)
		accepted.append(id)
	return accepted


## "" se a classe pode vestir o item; senão, o motivo.
func can_use(id: String) -> String:
	var it := item(id)
	if it.is_empty():
		return "Item desconhecido"
	if not (db.get("slots", {}) as Dictionary).has(String(it.get("slot", ""))):
		return "Item não é equipável"
	var classes: Array = it.get("classes", [])
	if not classes.is_empty() and class_id not in classes:
		return "Sua classe não pode usar isto"
	return ""


## Veste um item da mochila; o que estava no slot volta para a mochila.
## Retorna "" em sucesso ou o motivo da recusa.
func equip(id: String) -> String:
	if id not in items:
		return "Item não está no inventário"
	var err := can_use(id)
	if err != "":
		return err
	var slot := String(item(id).slot)
	items.erase(id)
	var old := String(equipped.get(slot, ""))
	if old != "":
		items.append(old)
	equipped[slot] = id
	return ""


## Tira o item do slot e devolve à mochila (falha se a mochila estiver cheia).
func unequip(slot: String) -> bool:
	var id := String(equipped.get(slot, ""))
	if id == "" or items.size() >= capacity():
		return false
	equipped.erase(slot)
	items.append(id)
	return true


## Soma dos atributos de tudo que está vestido (primários e derivados juntos).
func bonus() -> Dictionary:
	var out := {}
	for slot: String in equipped:
		var stats: Dictionary = item(String(equipped[slot])).get("stats", {})
		for k: String in stats:
			out[k] = float(out.get(k, 0.0)) + float(stats[k])
	return out
