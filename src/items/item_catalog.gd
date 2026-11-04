class_name ItemCatalog
extends RefCounted
## Catálogo de itens: junta os dados de jogo (`assets/data/items.json`) com a arte
## (`assets/items/item_models.json`) e responde consultas por id, slot e vocação.
## Lógica pura e injetável: o construtor recebe os dicionários já lidos; só
## `load_default()`/`from_files()` tocam disco.
##
## Uso:
##   var cat := ItemCatalog.load_default()
##   cat.item(&"iron_sword").display_name
##   cat.by_slot(&"shield")              # Array[ItemDefinition]
##   cat.usable_by("warrior", &"weapon")
##
## item_models.json:
##   "models": { chave: {"path": "res://…gltf", "view": {yaw, pitch, roll, zoom, offset}} }
##   "items":  { id_do_item: "chave" | {"model": "chave", "view": {…}} }
## Precedência do modelo: items.json "model" > item_models.json "items" > nenhum.
## Ícone: items.json "icon" > `<icon_dir>/<id>.png` se existir (convenção do IconBaker).

const ITEMS_PATH := "res://assets/data/items.json"
const MODELS_PATH := "res://assets/items/item_models.json"
const ICON_DIR := "res://assets/items/icons"

## items.json completo (slots, stat_names, rarity_colors, items).
var db: Dictionary
## item_models.json completo (models, items).
var art: Dictionary
var _defs: Dictionary = {}   # StringName -> ItemDefinition
var _order: Array[StringName] = []


## `items_db` = conteúdo de items.json; `models_db` = conteúdo de item_models.json.
## `icon_exists(path) -> bool` decide se o ícone por convenção existe (injete nos testes).
func _init(items_db: Dictionary, models_db: Dictionary = {}, icon_dir: String = ICON_DIR,
		icon_exists: Callable = Callable()) -> void:
	db = items_db
	art = models_db
	var exists := icon_exists if icon_exists.is_valid() else Callable(ResourceLoader, "exists")
	var items: Dictionary = db.get("items", {})
	for raw_id: Variant in items:
		var id := String(raw_id)
		var def := ItemDefinition.from_dict(id, items[raw_id], art_for(id))
		if def.icon_path == "":
			var conv := "%s/%s.png" % [icon_dir, id]
			if bool(exists.call(conv)):
				def.icon_path = conv
		_defs[def.id] = def
		_order.append(def.id)


## Lê items.json e item_models.json dos caminhos padrão.
static func load_default() -> ItemCatalog:
	return from_files(ITEMS_PATH, MODELS_PATH)


## Lê os dois arquivos. `models_path` ausente/vazio = catálogo sem arte.
static func from_files(items_path: String, models_path: String = "") -> ItemCatalog:
	var models := {}
	if models_path != "" and FileAccess.file_exists(models_path):
		models = JsonData.load_dict(models_path)
	return ItemCatalog.new(JsonData.load_dict(items_path), models)


## Definição do item, ou null se o id não existe.
func item(id: StringName) -> ItemDefinition:
	return _defs.get(id)


## True se o id existe no catálogo.
func has_item(id: StringName) -> bool:
	return _defs.has(id)


## Ids na ordem de items.json.
func ids() -> Array[StringName]:
	return _order.duplicate()


## Todas as definições na ordem de items.json.
func all() -> Array[ItemDefinition]:
	var out: Array[ItemDefinition] = []
	for id in _order:
		out.append(_defs[id])
	return out


## Itens de um slot de equipamento.
func by_slot(slot: StringName) -> Array[ItemDefinition]:
	return all().filter(func(d: ItemDefinition) -> bool: return d.slot == slot)


## Itens de uma natureza (&"equipment", &"consumable", &"key"...).
func by_kind(kind: StringName) -> Array[ItemDefinition]:
	return all().filter(func(d: ItemDefinition) -> bool: return d.kind == kind)


## Itens que a vocação pode usar; `slot` vazio = qualquer slot (inclui não equipáveis).
func usable_by(vocation: String, slot: StringName = &"") -> Array[ItemDefinition]:
	return all().filter(func(d: ItemDefinition) -> bool:
		return d.usable_by(vocation) and (slot == &"" or d.slot == slot))


## Itens de uma raridade.
func by_rarity(rarity: StringName) -> Array[ItemDefinition]:
	return all().filter(func(d: ItemDefinition) -> bool: return d.rarity == rarity)


## Itens que têm modelo 3D (os que o IconBaker consegue renderizar).
func with_model() -> Array[ItemDefinition]:
	return all().filter(func(d: ItemDefinition) -> bool: return d.model_path != "")


## Nome do slot para a interface (items.json "slots"); o próprio id se não houver.
func slot_name(slot: StringName) -> String:
	return String((db.get("slots", {}) as Dictionary).get(String(slot), {}).get("name", slot))


## Nome do atributo para a interface (items.json "stat_names").
func stat_name(stat: String) -> String:
	return String((db.get("stat_names", {}) as Dictionary).get(stat, stat))


## Cor da raridade (items.json "rarity_colors"); cinza se não houver.
func rarity_color(rarity: StringName) -> Color:
	var c: Variant = (db.get("rarity_colors", {}) as Dictionary).get(String(rarity))
	return JsonData.to_color(c) if c is Array else Color(0.7, 0.68, 0.62)


## Chaves da biblioteca de modelos (item_models.json "models").
func model_keys() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in art.get("models", {}):
		out.append(String(k))
	return out


## Entrada de um modelo da biblioteca: {path, view}. Vazio se a chave não existe.
func model_entry(key: String) -> Dictionary:
	return (art.get("models", {}) as Dictionary).get(key, {})


## Arte resolvida de um item: {model: caminho, view: {…}} (view do modelo + ajuste do item).
func art_for(id: String) -> Dictionary:
	var ref: Variant = (art.get("items", {}) as Dictionary).get(id)
	if ref == null:
		return {}
	var entry: Dictionary = {"model": ref} if ref is String else ref
	var key := String(entry.get("model", ""))
	var lib := model_entry(key)
	var view: Dictionary = (lib.get("view", {}) as Dictionary).duplicate()
	view.merge(entry.get("view", {}), true)
	var path := String(lib.get("path", key))   # chave desconhecida = caminho direto
	return {"model": path, "view": view}
