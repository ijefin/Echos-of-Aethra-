extends SceneTree
## Testes do Inventory (lógica pura, sem rede). gdUnit4 ainda não está instalado, então
## roda como script headless:
##   godot --headless --path . -s res://tests/unit/inventory/inventory_items_test.gd
## Sai com código 1 se algum teste falhar.

var _failed := 0


func _db() -> Dictionary:
	return {
		"inventory_size": 3,
		"slots": {"head": {"name": "Cabeça"}, "weapon": {"name": "Arma"}},
		"items": {
			"hat": {"name": "Chapéu", "slot": "head", "classes": ["mage"], "stats": {"INT": 2, "resist": 1}},
			"hood": {"name": "Capuz", "slot": "head", "classes": ["mage"], "stats": {"SPI": 1}},
			"staff": {"name": "Cajado", "slot": "weapon", "stats": {"spell_power": 4}},
			"plate": {"name": "Placa", "slot": "head", "classes": ["warrior"]},
			"gem": {"name": "Gema"},
		},
	}


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failed += 1
		printerr("FALHOU: ", what)


func _initialize() -> void:
	test_give_rejects_unknown_and_overflow()
	test_equip_swaps_back_to_bag()
	test_class_restriction()
	test_unequip_needs_bag_space()
	test_bonus_sums_equipped()
	test_attribute_set_applies_bonus()
	print("inventory: %s" % ("OK" if _failed == 0 else "%d falha(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func test_give_rejects_unknown_and_overflow() -> void:
	var inv := Inventory.new(_db(), "mage")
	var got := inv.give(["hat", "nope", "hood", "staff", "gem"])
	_check(Array(got) == ["hat", "hood", "staff"], "give aceita só conhecidos até a capacidade")
	_check(inv.items.size() == 3, "mochila com 3 itens")


func test_equip_swaps_back_to_bag() -> void:
	var inv := Inventory.new(_db(), "mage")
	inv.give(["hat", "hood"])
	_check(inv.equip("hat") == "", "veste chapéu")
	_check(inv.equip("hood") == "", "veste capuz")
	_check(inv.equipped.head == "hood" and "hat" in inv.items, "chapéu volta para a mochila")
	_check(inv.equip("hat") == "" and inv.equip("staff") != "", "item fora da mochila é recusado")


func test_class_restriction() -> void:
	var inv := Inventory.new(_db(), "mage")
	inv.give(["plate", "gem"])
	_check(inv.equip("plate") != "", "mago não veste placa")
	_check(inv.equip("gem") != "", "item sem slot não é equipável")
	_check(inv.items.size() == 2, "recusa não tira da mochila")


func test_unequip_needs_bag_space() -> void:
	var inv := Inventory.new(_db(), "mage")
	inv.give(["hat"])
	inv.equip("hat")
	inv.give(["hood", "staff", "hood"])
	_check(not inv.unequip("head"), "não tira com mochila cheia")
	inv.items.pop_back()
	_check(inv.unequip("head") and not inv.equipped.has("head"), "tira com espaço")


func test_bonus_sums_equipped() -> void:
	var inv := Inventory.new(_db(), "mage")
	inv.give(["hat", "staff"])
	inv.equip("hat")
	inv.equip("staff")
	_check(inv.bonus() == {"INT": 2.0, "resist": 1.0, "spell_power": 4.0}, "bônus soma o vestido")


func test_attribute_set_applies_bonus() -> void:
	var def := {"primary": {"INT": 10}, "base": {"spell_power": 1}, "coeff": {"spell_power": {"INT": 2}}}
	var s := AttributeSet.build(def, 0, ["spell_power", "resist"], {"INT": 2, "resist": 3})
	_check(is_equal_approx(float(s.spell_power), 25.0), "INT do item passa pelo coeficiente (1 + 12×2)")
	_check(is_equal_approx(float(s.resist), 3.0), "derivado soma direto")
	_check(int(def.primary.INT) == 10, "build não altera a definição da classe")
