class_name MainMenu
extends Control
## Tela inicial em resolução nativa: nome, classe e modo (sozinho, hospedar, entrar).
## O mundo continua animado atrás dela. Só emite pedidos — quem inicia é o GameMain.
## Dívida (regra de UI): textos fixos aguardam o sistema de localização.
##
## Uso:
##   menu.setup(classes, playable, 7777, NetSession.local_addresses())
##   menu.host_requested.connect(...)

signal solo_requested(player_name: String, cls: String)
signal host_requested(port: int, player_name: String, cls: String)
signal join_requested(address: String, port: int, player_name: String, cls: String)

const GOLD := Color(0.95, 0.74, 0.3)
const CREAM := Color(1.0, 0.96, 0.82)
const MUTED := Color(0.78, 0.72, 0.66)

var _name_edit: LineEdit
var _class_opt: OptionButton
var _address_edit: LineEdit
var _port_edit: LineEdit
var _status: Label
var _class_ids: Array = []


## Monta a tela. `classes` vem de combat_classes.json; `playable` lista as jogáveis.
func setup(classes: Dictionary, playable: Array, default_port: int, local_ips: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.03, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Ecos de Aethra"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A ilha chama os escolhidos"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", MUTED)
	box.add_child(subtitle)
	box.add_child(HSeparator.new())

	_name_edit = _labeled_line(box, "Nome", "Viajante")
	var class_row := HBoxContainer.new()
	var class_label := Label.new()
	class_label.text = "Classe"
	class_label.custom_minimum_size = Vector2(110, 0)
	class_row.add_child(class_label)
	_class_opt = OptionButton.new()
	_class_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in playable:
		_class_ids.append(id)
		_class_opt.add_item(String(classes[id].get("name", id)))
	class_row.add_child(_class_opt)
	box.add_child(class_row)

	var solo := Button.new()
	solo.text = "Jogar sozinho"
	solo.pressed.connect(func() -> void: solo_requested.emit(_player_name(), _cls()))
	box.add_child(solo)
	box.add_child(HSeparator.new())

	_port_edit = _labeled_line(box, "Porta", str(default_port))
	var host := Button.new()
	host.text = "Hospedar partida"
	host.pressed.connect(func() -> void: host_requested.emit(_port(), _player_name(), _cls()))
	box.add_child(host)
	var ips := Label.new()
	ips.text = "Seu IP na rede: %s" % (", ".join(local_ips) if not local_ips.is_empty() else "—")
	ips.add_theme_color_override("font_color", MUTED)
	ips.add_theme_font_size_override("font_size", 14)
	box.add_child(ips)
	box.add_child(HSeparator.new())

	_address_edit = _labeled_line(box, "IP do host", "127.0.0.1")
	var join := Button.new()
	join.text = "Entrar na partida"
	join.pressed.connect(func() -> void: join_requested.emit(_address_edit.text.strip_edges(), _port(), _player_name(), _cls()))
	box.add_child(join)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", GOLD)
	box.add_child(_status)
	var hint := Label.new()
	hint.text = "Pela internet: o host libera a porta UDP no roteador ou os dois usam uma VPN de jogo (Radmin, ZeroTier, Tailscale)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(420, 0)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", MUTED)
	box.add_child(hint)


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Viajante"


func _cls() -> String:
	return String(_class_ids[maxi(0, _class_opt.selected)])


func _port() -> int:
	return clampi(int(_port_edit.text), 1024, 65535)


func _labeled_line(parent: Control, label_text: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	parent.add_child(row)
	return edit


func _make_theme() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Arial", "sans-serif"])
	font.font_weight = 600
	t.default_font = font
	t.default_font_size = 18
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.045, 0.06, 0.92)
	panel.border_color = Color(0.85, 0.64, 0.25, 0.8)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(26)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 12
	t.set_stylebox("panel", "PanelContainer", panel)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": Color(0.22, 0.12, 0.1), "hover": Color(0.36, 0.17, 0.1), "pressed": Color(0.5, 0.22, 0.08), "focus": Color(0.22, 0.12, 0.1)}[state]
		b.border_color = Color(0.85, 0.64, 0.25, 0.9 if state != "normal" else 0.5)
		b.set_border_width_all(1)
		b.set_corner_radius_all(6)
		b.set_content_margin_all(10)
		t.set_stylebox(state, "Button", b)
		t.set_stylebox(state, "OptionButton", b)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_color", "Label", CREAM)
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0.12, 0.08, 0.09)
	line.border_color = Color(0.45, 0.38, 0.32)
	line.set_border_width_all(1)
	line.set_corner_radius_all(5)
	line.set_content_margin_all(8)
	t.set_stylebox("normal", "LineEdit", line)
	t.set_stylebox("focus", "LineEdit", line)
	t.set_color("font_color", "LineEdit", CREAM)
	return t
