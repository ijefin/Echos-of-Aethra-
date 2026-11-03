# PROTOTYPE - NOT FOR PRODUCTION
extends Control
## Chat estilo Tibia: janela pequena e translúcida no canto inferior esquerdo, com abas.
##   Local    — falas de NPC, o que o jogador diz (também sobre a cabeça), interações
##   Servidor — eventos do mundo, dano recebido, poções, XP, itens, nível, missões
##   Grupo / PvP — conversa do grupo e chamada geral de PvP
## Enter abre a digitação (o personagem para), Enter envia, Esc cancela; clique nas abas.
## Protótipo sem rede: Grupo e PvP mostram o que o próprio jogador digita.

const CHANNELS := ["Local", "Servidor", "Grupo", "PvP"]
const KEEP := 120
const LINES := 7
const REF_HEIGHT := 720.0
const COLORS := {
	"Local": Color(1.0, 0.93, 0.35),
	"Servidor": Color(0.85, 0.9, 0.85),
	"Grupo": Color(0.45, 0.85, 1.0),
	"PvP": Color(1.0, 0.45, 0.4),
}

var adventure
var active := "Local"
var typing := false
var _log := {}          # canal -> Array[[texto, cor]]
var _unread := {}
var _input: LineEdit
var _font: SystemFont
var _bold: SystemFont
var _ui := 1.0
var _tab_rects := {}


func build(owner_adventure, layer: CanvasLayer) -> void:
	adventure = owner_adventure
	layer.add_child(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Verdana", "Tahoma", "Segoe UI", "sans-serif"])
	_bold = SystemFont.new()
	_bold.font_names = _font.font_names
	_bold.font_weight = 700
	for c in CHANNELS:
		_log[c] = []
		_unread[c] = false
	_input = LineEdit.new()
	_input.visible = false
	_input.max_length = 160
	_input.placeholder_text = "Digite e pressione Enter"
	_input.add_theme_font_override("font", _font)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.025, 0.035, 0.85)
	box.border_color = Color(0.42, 0.34, 0.2, 0.9)
	box.set_border_width_all(1)
	box.set_content_margin_all(4)
	_input.add_theme_stylebox_override("normal", box)
	_input.add_theme_stylebox_override("focus", box)
	_input.text_submitted.connect(_submit)
	_input.gui_input.connect(_on_input_key)
	add_child(_input)


## Registra uma mensagem num canal (cor padrão do canal se não informada).
func post(channel: String, text: String, color := Color(0, 0, 0, 0)) -> void:
	var lines: Array = _log[channel]
	lines.append([text, COLORS[channel] if color.a == 0.0 else color])
	if lines.size() > KEEP:
		lines.pop_front()
	if channel != active:
		_unread[channel] = true
	queue_redraw()


func open_input() -> void:
	typing = true
	_input.visible = true
	_input.text = ""
	_input.grab_focus()


func _close_input() -> void:
	typing = false
	_input.visible = false
	_input.release_focus()


func _submit(text: String) -> void:
	text = text.strip_edges()
	if not text.is_empty():
		var who := "Você"
		post(active, "%s: %s" % [who, text])
		if active == "Local":
			adventure.player_say(text)
	_close_input()


func _on_input_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_input()
		accept_event()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for c: String in _tab_rects:
			if (_tab_rects[c] as Rect2).has_point(event.position):
				active = c
				_unread[c] = false
				queue_redraw()
		accept_event()


func _process(_delta: float) -> void:
	var win: Vector2 = get_viewport().get_visible_rect().size
	_ui = maxf(0.8, win.y / REF_HEIGHT)
	size = Vector2(roundf(400 * _ui), roundf(150 * _ui))
	position = Vector2(roundf(12 * _ui), win.y - size.y - roundf(12 * _ui))
	_input.position = Vector2(0, size.y - roundf(22 * _ui))
	_input.size = Vector2(size.x, roundf(22 * _ui))
	_input.add_theme_font_size_override("font_size", roundi(11 * _ui))
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.02, 0.025, 0.035, 0.42))
	draw_rect(r, Color(0.42, 0.34, 0.2, 0.55), false, 1.0)
	# abas
	var x := roundf(4 * _ui)
	var tab_h := roundf(18 * _ui)
	var fs := roundi(10 * _ui)
	_tab_rects.clear()
	for c in CHANNELS:
		var w := _bold.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + roundf(14 * _ui)
		var tr := Rect2(x, roundf(3 * _ui), w, tab_h)
		_tab_rects[c] = tr
		var on: bool = c == active
		draw_rect(tr, Color(0.12, 0.11, 0.1, 0.85) if on else Color(0.05, 0.05, 0.06, 0.55))
		draw_rect(tr, Color(0.66, 0.53, 0.3, 0.9) if on else Color(0.3, 0.26, 0.18, 0.6), false, 1.0)
		var col: Color = Color(1, 0.82, 0.38) if on else (Color(1, 0.6, 0.3) if _unread[c] else Color(0.65, 0.63, 0.58))
		_text(c, Vector2(tr.position.x + roundf(7 * _ui), tr.position.y + roundf(13 * _ui)), fs, col, true)
		x += w + roundf(3 * _ui)
	# mensagens (as mais recentes embaixo)
	var lines: Array = _log[active]
	var line_h := roundf(15 * _ui)
	var bottom := size.y - roundf(28 * _ui) if typing else size.y - roundf(8 * _ui)
	var shown := lines.slice(maxi(0, lines.size() - LINES))
	var y := bottom - (shown.size() - 1) * line_h
	for l: Array in shown:
		_text(_clip(String(l[0]), size.x - roundf(14 * _ui), roundi(11 * _ui)), Vector2(roundf(7 * _ui), y), roundi(11 * _ui), l[1])
		y += line_h
	if not typing:
		_text("Enter para falar", Vector2(size.x - roundf(104 * _ui), roundf(15 * _ui)), roundi(9 * _ui), Color(0.6, 0.58, 0.54, 0.7))


func _text(s: String, pos: Vector2, px: int, color: Color, bold := false) -> void:
	var f: Font = _bold if bold else _font
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, roundi(3 * _ui), Color(0, 0, 0, 0.85))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


func _clip(s: String, width: float, px: int) -> String:
	if _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= width:
		return s
	while s.length() > 4 and _font.get_string_size(s + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		s = s.substr(0, s.length() - 1)
	return s + "…"
