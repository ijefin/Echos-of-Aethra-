class_name InventoryPanel
extends PanelContainer
## Painel de inventário (tecla I): equipamento vestido por slot, mochila e bônus total.
## Clique num item da mochila veste; clique num slot tira; arraste pelo fundo para mover.
## Só pede ao servidor
## (NetSession) — o estado mostrado é sempre o que ele replicou.
## Dívida (regra de UI): textos fixos aguardam o sistema de localização; sem gamepad ainda.
##
## Uso:
##   var inv := InventoryPanel.new()
##   ui_layer.add_child(inv)
##   inv.setup(net_session)
##   inv.toggle()

const REF_HEIGHT := 720.0
## Ordem de exibição dos slots (os nomes vêm de items.json).
const SLOT_ORDER: Array[String] = ["head", "neck", "weapon", "chest", "shield", "legs", "feet"]
const PANEL_BG := Color(0.07, 0.045, 0.06, 0.92)
const PANEL_EDGE := Color(0.85, 0.64, 0.25, 0.75)
const CREAM := Color(1.0, 0.96, 0.82)
const MUTED := Color(0.78, 0.72, 0.66)
const GOLD := Color(0.95, 0.74, 0.3)
const BLOCKED := Color(0.75, 0.42, 0.4)

var _net: NetSession
var _db: Dictionary
var _title: Label
var _slots_box: VBoxContainer
var _bag_title: Label
var _bag_grid: GridContainer
var _bonus: Label
## Arrasto: true enquanto o botão esquerdo segura o fundo do painel.
var _dragging := false
## O jogador já moveu o painel: não recentraliza mais ao abrir/redimensionar.
var _placed := false


func setup(net: NetSession) -> void:
	_net = net
	_db = Inventory.load_db()
	_net.inventory_changed.connect(refresh)
	refresh()


func _ready() -> void:
	visible = false
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = PANEL_EDGE
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(14)
	add_theme_stylebox_override("panel", box)
	theme = Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Arial", "sans-serif"])
	font.font_weight = 500
	theme.default_font = font

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	_title = _label("Inventário", GOLD, 1.25)
	root.add_child(_title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 250
	left.add_child(_label("Equipado (clique para tirar)", MUTED, 0.85))
	_slots_box = VBoxContainer.new()
	left.add_child(_slots_box)
	cols.add_child(left)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 330
	_bag_title = _label("Mochila", MUTED, 0.85)
	right.add_child(_bag_title)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 2
	right.add_child(_bag_grid)
	cols.add_child(right)

	_bonus = _label("", CREAM, 0.85)
	_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bonus.custom_minimum_size.x = 596
	root.add_child(_bonus)
	var give := _button("Receber itens de teste", MUTED)
	give.pressed.connect(func() -> void: _net.request_test_items.rpc_id(1))
	root.add_child(give)

	get_viewport().size_changed.connect(_fit)
	_fit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_placed = true
		var vp := get_viewport().get_visible_rect().size
		position = (position + event.relative).clamp(Vector2.ZERO, (vp - size).max(Vector2.ZERO))
		accept_event()


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


## Redesenha a partir do espelho local (mochila) e do equipamento replicado.
func refresh() -> void:
	if _net == null or _slots_box == null:
		return
	var me: Dictionary = _net.players_info.get(multiplayer.get_unique_id(), {})
	var cls := String(me.get("class", ""))
	var view := Inventory.new(_db, cls)
	view.equipped = me.get("equip", {})
	_title.text = "Inventário"

	for c in _slots_box.get_children():
		c.queue_free()
	var slots: Dictionary = _db.get("slots", {})
	for slot: String in SLOT_ORDER:
		if not slots.has(slot):
			continue
		var id := String(view.equipped.get(slot, ""))
		var it := view.item(id)
		var b := _button("%s:  %s" % [slots[slot].name, it.get("name", "—")], _rarity_color(it) if id != "" else MUTED)
		b.tooltip_text = _describe(it)
		if id != "":
			b.pressed.connect(func() -> void: _net.request_unequip.rpc_id(1, slot))
		_slots_box.add_child(b)

	for c in _bag_grid.get_children():
		c.queue_free()
	_bag_title.text = "Mochila  %d/%d  (clique para vestir)" % [_net.local_items.size(), view.capacity()]
	for raw: Variant in _net.local_items:
		var id := String(raw)
		var it := view.item(id)
		var usable := view.can_use(id) == ""
		var b := _button(String(it.get("name", id)), _rarity_color(it) if usable else BLOCKED)
		b.custom_minimum_size.x = 160
		b.tooltip_text = _describe(it) + ("" if usable else "\n" + view.can_use(id))
		b.pressed.connect(func() -> void: _net.request_equip.rpc_id(1, id))
		_bag_grid.add_child(b)

	var bonus := view.bonus()
	_bonus.text = "Bônus do equipamento:  " + (_stats_text(bonus) if not bonus.is_empty() else "nenhum")


func _rarity_color(it: Dictionary) -> Color:
	var colors: Dictionary = _db.get("rarity_colors", {})
	return JsonData.to_color(colors[it.rarity]) if colors.has(it.get("rarity", "")) else CREAM


## "Nome — slot\n+2 Inteligência · +4 Poder Mágico" (dica do botão).
func _describe(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	var slot_name := String(_db.get("slots", {}).get(String(it.get("slot", "")), {}).get("name", ""))
	var tail := "" if it.has("manifest") else "\n(ainda sem sprite)"
	return "%s — %s\n%s%s" % [it.name, slot_name, _stats_text(it.get("stats", {})), tail]


func _stats_text(stats: Dictionary) -> String:
	var names: Dictionary = _db.get("stat_names", {})
	var parts: PackedStringArray = []
	for k: String in stats:
		var v := float(stats[k])
		var txt := "+%d%%" % roundi(v * 100.0) if k == "crit_chance" else String.num(v, 1)
		if k != "crit_chance" and v >= 0.0:
			txt = "+" + txt
		parts.append("%s %s" % [txt, names.get(k, k)])
	return " · ".join(parts)


func _label(text: String, color: Color, size_mult: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.set_meta("size_mult", size_mult)
	return l


func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE  # Espaço é esquiva; não pode apertar botão
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", GOLD)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(1, 1, 1, 0.04)
	flat.set_content_margin_all(5)
	flat.set_corner_radius_all(3)
	var hover := flat.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.95, 0.74, 0.3, 0.14)
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b


## Escala pelo tamanho da janela (referência 720 px) e ancora à direita, centralizado.
func _fit() -> void:
	var s := maxf(0.75, get_viewport().get_visible_rect().size.y / REF_HEIGHT)
	theme.default_font_size = roundi(14 * s)
	scale = Vector2.ONE
	reset_size()
	var vp := get_viewport().get_visible_rect().size
	if _placed:
		position = position.clamp(Vector2.ZERO, (vp - size).max(Vector2.ZERO))
	else:
		position = Vector2(vp.x - size.x - 16 * s, (vp.y - size.y) / 2.0)
