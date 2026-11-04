extends SceneTree
## Testes do ItemCatalog/ItemDefinition (lógica pura; dados injetados, sem disco).
##   godot --headless --path . -s res://tests/unit/items/item_catalog_test.gd
## Sai com código 1 se algum teste falhar.

var _failed := 0


func _items_db() -> Dictionary:
	return {
		"slots": {"weapon": {"name": "Arma"}, "shield": {"name": "Escudo"}},
		"stat_names": {"STR": "Força"},
		"rarity_colors": {"rare": [0.45, 0.7, 1.0]},
		"items": {
			"sword": {"name": "Espada", "slot": "weapon", "classes": ["warrior"], "stats": {"STR": 2}, "rarity": "common", "tint": [1.0, 0.5, 0.5]},
			"staff": {"name": "Cajado", "slot": "weapon", "classes": ["fire_mage"], "model": "res://direto.glb"},
			"buckler": {"name": "Broquel", "slot": "shield", "rarity": "rare", "desc": "Amassado por anos de patrulha.", "icon": "res://icone.png"},
			"potion": {"name": "Poção", "kind": "consumable", "stack": 20, "value": 10, "use": {"hp": 45}},
		},
	}


func _models_db() -> Dictionary:
	return {
		"models": {
			"kk_sword": {"path": "res://modelos/sword.gltf", "view": {"yaw": 30.0, "zoom": 1.0}},
			"kk_staff": {"path": "res://modelos/staff.gltf"},
		},
		"items": {
			"sword": {"model": "kk_sword", "view": {"zoom": 1.4}},
			"staff": "kk_staff",
			"buckler": "res://modelos/buckler.gltf",
		},
	}


func _catalog() -> ItemCatalog:
	var exists := func(path: String) -> bool: return path == "res://icons/sword.png"
	return ItemCatalog.new(_items_db(), _models_db(), "res://icons", exists)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failed += 1
		printerr("FALHOU: ", what)


func _initialize() -> void:
	test_definition_fields()
	test_defaults()
	test_queries()
	test_model_precedence_and_view_merge()
	test_icon_resolution()
	test_ui_names()
	test_real_data_loads()
	print("items: %s" % ("OK" if _failed == 0 else "%d falha(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func test_definition_fields() -> void:
	var b := _catalog().item(&"buckler")
	_check(b != null and b.display_name == "Broquel", "nome lido")
	_check(b.lore == "Amassado por anos de patrulha.", "lore lida de desc")
	_check(b.slot == &"shield" and b.kind == &"equipment" and b.is_equippable(), "slot define equipamento")
	_check(b.rarity == &"rare", "raridade lida")
	var s := _catalog().item(&"sword")
	_check(s.stats == {"STR": 2} and s.tint.is_equal_approx(Color(1.0, 0.5, 0.5)), "atributos e tint")


func test_defaults() -> void:
	var p := _catalog().item(&"potion")
	_check(p.kind == &"consumable" and not p.is_equippable(), "consumível sem slot")
	_check(p.is_stackable() and p.max_stack == 20 and p.value == 10, "pilha e valor")
	_check(p.use_effect == {"hp": 45}, "efeito de uso")
	_check(p.rarity == ItemDefinition.DEFAULT_RARITY, "sem raridade = basic")
	_check(p.usable_by("qualquer"), "sem classes = todas as vocações")
	_check(_catalog().item(&"nope") == null and not _catalog().has_item(&"nope"), "id desconhecido = null")


func test_queries() -> void:
	var cat := _catalog()
	_check(cat.ids() == [&"sword", &"staff", &"buckler", &"potion"], "ordem de items.json preservada")
	_check(cat.by_slot(&"weapon").size() == 2, "by_slot")
	_check(cat.by_kind(&"consumable").size() == 1, "by_kind")
	var war := cat.usable_by("warrior").map(func(d: ItemDefinition) -> StringName: return d.id)
	_check(war == [&"sword", &"buckler", &"potion"], "usable_by inclui itens sem restrição")
	_check(cat.usable_by("fire_mage", &"weapon").size() == 1, "usable_by com slot")
	_check(cat.by_rarity(&"rare").size() == 1, "by_rarity")
	_check(cat.with_model().size() == 3, "with_model")


func test_model_precedence_and_view_merge() -> void:
	var cat := _catalog()
	_check(cat.item(&"staff").model_path == "res://direto.glb", "items.json model vence item_models.json")
	_check(cat.item(&"sword").model_path == "res://modelos/sword.gltf", "chave da biblioteca vira caminho")
	_check(cat.item(&"buckler").model_path == "res://modelos/buckler.gltf", "caminho direto em item_models.json")
	var v := cat.item(&"sword").icon_view
	_check(is_equal_approx(float(v.yaw), 30.0) and is_equal_approx(float(v.zoom), 1.4), "view do item sobrepõe a do modelo")
	_check(cat.model_keys() == ["kk_sword", "kk_staff"], "model_keys")


func test_icon_resolution() -> void:
	var cat := _catalog()
	_check(cat.item(&"buckler").icon_path == "res://icone.png", "icon explícito")
	_check(cat.item(&"sword").icon_path == "res://icons/sword.png", "icon por convenção quando existe")
	_check(cat.item(&"potion").icon_path == "", "sem ícone gerado = vazio")


func test_ui_names() -> void:
	var cat := _catalog()
	_check(cat.slot_name(&"shield") == "Escudo" and cat.slot_name(&"x") == "x", "slot_name")
	_check(cat.stat_name("STR") == "Força" and cat.stat_name("LUK") == "LUK", "stat_name")
	_check(cat.rarity_color(&"rare").is_equal_approx(Color(0.45, 0.7, 1.0)), "rarity_color")


## Os dados reais carregam e todo item com modelo aponta para um arquivo que existe.
func test_real_data_loads() -> void:
	var cat := ItemCatalog.load_default()
	_check(cat.ids().size() > 0, "items.json real carrega")
	_check(cat.has_item(&"iron_sword"), "item conhecido presente")
	for d in cat.with_model():
		_check(ResourceLoader.exists(d.model_path), "modelo de %s existe (%s)" % [d.id, d.model_path])
	for key in cat.model_keys():
		_check(ResourceLoader.exists(String(cat.model_entry(key).get("path", ""))), "modelo da biblioteca %s existe" % key)
	for d in cat.all():
		if d.icon_path != "":
			_check(ResourceLoader.exists(d.icon_path), "ícone de %s existe (%s)" % [d.id, d.icon_path])
