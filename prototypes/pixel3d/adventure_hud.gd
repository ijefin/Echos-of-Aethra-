# PROTOTYPE - NOT FOR PRODUCTION
extends Control
## HUD mínimo e original ("obsidiana e latão"): quase nada fixo na tela.
## Fixo: barra de habilidades/poções com ícones e recarga, vida e mana finas, linha de XP,
## objetivo curto no canto, linha de ação e avisos sem caixa (somem sozinhos).
## Em atalhos: H/F1 atalhos · J missões · C personagem · I bolsa · Esc fecha.
## Desenhado em resolução nativa (texto nítido); escala pela altura da janela.

const REF_HEIGHT := 720.0
const INK := Color(0.035, 0.04, 0.055, 0.86)
const BRASS := Color(0.66, 0.53, 0.3, 0.95)
const BRASS_DIM := Color(0.42, 0.34, 0.2, 0.9)
const CREAM := Color(0.95, 0.92, 0.84)
const MUTED := Color(0.7, 0.68, 0.62)
const GOLD := Color(1.0, 0.82, 0.38)
const HP_COL := Color(0.78, 0.2, 0.18)
const MP_COL := Color(0.25, 0.48, 0.9)
const PANELS := ["help", "quest", "char", "bag", "vocation", "friends", "shop", "trade"]
const Economy := preload("res://prototypes/pixel3d/economy.gd")

var adventure
var panel := ""
## Compatível com o código existente (tecla I e ferramenta de captura).
var bag_open: bool:
	get:
		return panel == "bag"
	set(v):
		panel = "bag" if v else ("" if panel == "bag" else panel)

var _font: SystemFont
var _bold: SystemFont
var _ui := 1.0
var _mana_flash := 0.0
## Painel de amigos (só online): nome a pedir e amigo selecionado.
var _friend_input: LineEdit
var _friend_sel := 0


func build(owner_adventure) -> void:
	adventure = owner_adventure
	var layer := CanvasLayer.new()
	layer.layer = 5
	adventure.demo.add_child(layer)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(self)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Verdana", "Tahoma", "Segoe UI", "sans-serif"])
	_font.font_weight = 400
	_bold = SystemFont.new()
	_bold.font_names = _font.font_names
	_bold.font_weight = 700


func toggle(which: String) -> void:
	panel = "" if panel == which else which


func any_open() -> bool:
	return panel != ""


func flash_mana() -> void:
	_mana_flash = 0.6


func update() -> void:
	var dt := get_process_delta_time()
	_mana_flash = maxf(0.0, _mana_flash - dt)
	_stat_fx = maxf(0.0, _stat_fx - dt)
	for fx: Dictionary in [_reject_fx, _accept_fx]:
		for key: String in fx.keys():
			fx[key] = float(fx[key]) - dt
			if float(fx[key]) <= 0.0:
				fx.erase(key)
	_gold_fx = maxf(0.0, _gold_fx - dt)
	if int(adventure.gold) != _gold_seen:
		if _gold_seen >= 0:
			_gold_fx = 0.6
		_gold_seen = int(adventure.gold)
	if panel != "bag":
		_drag_id = ""
		_drag_slot = ""
		_drag_live = false
	if panel != "trade" and not trade.is_empty() and adventure.online != null:
		adventure.online.trade_cancel()   # fechou o painel: a troca cancela para os dois
		trade = {}
	queue_redraw()


# ------------------------------------------------------------------ desenho

func _px(v: float) -> float:
	return roundf(v * _ui)


func _text(s: String, pos: Vector2, size: int, color: Color, bold := false, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f: Font = _bold if bold else _font
	var px := roundi(size * _ui)
	draw_string_outline(f, pos, s, align, width, px, roundi(3 * _ui), Color(0, 0, 0, color.a * 0.9))
	draw_string(f, pos, s, align, width, px, color)


func _frame(r: Rect2, fill := INK) -> void:
	draw_rect(r, fill)
	draw_rect(r, BRASS_DIM, false, 1.0)
	var d := _px(3)
	for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), BRASS)


func _draw() -> void:
	if adventure == null:
		return
	_ui = maxf(0.8, size.y / REF_HEIGHT)
	var state = adventure.state
	var demo = adventure.demo
	# --- barra de ação
	var slots := _slots(state, demo)
	var s := _px(42)
	var gap := _px(5)
	var total := slots.size() * s + (slots.size() - 1) * gap + _px(10)
	var x0 := roundf(size.x * 0.5 - total * 0.5)
	var y0 := size.y - s - _px(18)
	var x := x0
	for i in slots.size():
		if i == 4:
			x += _px(10)  # separa habilidades de poções
		_slot(Rect2(x, y0, s, s), slots[i])
		x += s + gap
	# --- vida e mana: duas barras finas logo acima
	var bw := (total - _px(8)) * 0.5
	var by := y0 - _px(20)
	_bar(Rect2(x0, by, bw, _px(14)), adventure.hp / float(state.max_hp()), HP_COL, "%d / %d" % [ceili(adventure.hp), state.max_hp()])
	var mp_col := MP_COL.lerp(Color(1, 1, 1), _mana_flash)
	_bar(Rect2(x0 + bw + _px(8), by, bw, _px(14)), adventure.mana / float(adventure.max_mana()), mp_col, "%d / %d" % [floori(adventure.mana), adventure.max_mana()])
	# --- XP: linha dourada no pé + nível
	var xr := Rect2(x0, size.y - _px(9), total, _px(3))
	draw_rect(xr, Color(0, 0, 0, 0.7))
	draw_rect(Rect2(xr.position, Vector2(xr.size.x * clampf(float(state.xp) / state.xp_required(), 0, 1), xr.size.y)), GOLD)
	_text("Nv %d" % state.level, Vector2(x0 - _px(42), size.y - _px(5)), 12, GOLD, true)
	# --- linha de ação e aviso (sem caixa)

	if adventure.notice_time > 0 and panel == "":
		var a := clampf(adventure.notice_time / 0.8, 0.0, 1.0)
		_text(adventure.notice_text, Vector2(size.x * 0.2, by - _px(38)), 13, Color(CREAM, a), false, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.6)
	# --- objetivo curto no canto (sem moldura)
	var lines: PackedStringArray = String(adventure.objective()).split("\n")
	var shown := 0
	for l in lines.slice(0, 3):
		if not l.is_empty():
			shown += 1
	# painel discreto (pouca opacidade) atrás do objetivo
	_frame(Rect2(size.x - _px(262), _px(10), _px(250), _px(30) + shown * _px(16) + _px(8)), Color(0.035, 0.04, 0.055, 0.45))
	_text(String(adventure.objective_title()), Vector2(size.x - _px(250), _px(26)), 11, Color(GOLD, 0.9), true)
	var ly := _px(44)
	for l in lines.slice(0, 3):
		if not l.is_empty():
			_text(l, Vector2(size.x - _px(250), ly), 11, Color(CREAM, 0.85))
			ly += _px(16)
	_text("H  atalhos", Vector2(_px(12), _px(20)), 11, Color(MUTED, 0.75))
	match panel:
		"help":
			_help_panel()
		"quest":
			_quest_panel()
		"char":
			_char_panel()
		"bag":
			_bag_panel()
		"vocation":
			_vocation_panel()
		"friends":
			_friends_panel()
		"shop":
			_shop_panel()
		"trade":
			_trade_panel()
	if _friend_input != null:
		_friend_input.visible = panel == "friends"


# ------------------------------------------------------------------ amigos (online)

## Lista de amigos estilo Tibia (VIP): pedidos recebidos, amigos com presença e região.
func _friends_panel() -> void:
	var r := _panel_rect(440, 380)
	var y := _title(r, "AMIGOS", "O")
	var x := r.position.x + _px(22)
	var fl: Dictionary = adventure.online.friends if adventure.online != null else {}
	var incoming: Array = fl.get("incoming", [])
	var list: Array = fl.get("friends", [])
	if not incoming.is_empty():
		_text("PEDIDOS", Vector2(x, y), 11, Color(GOLD, 0.85), true)
		y += _px(24)
		for i in mini(incoming.size(), 9):
			var w := _keycap(Vector2(x, y), "%d" % (i + 1))
			_text(String(incoming[i]), Vector2(x + w + _px(10), y), 12, CREAM)
			y += _px(26)
		y += _px(6)
	_text("AMIGOS", Vector2(x, y), 11, Color(GOLD, 0.85), true)
	y += _px(24)
	_friend_sel = clampi(_friend_sel, 0, maxi(0, list.size() - 1))
	for i in list.size():
		var f: Dictionary = list[i]
		var on := bool(f.get("online", false))
		if i == _friend_sel:
			draw_rect(Rect2(x - _px(6), y - _px(16), r.size.x - _px(32), _px(22)), Color(1, 1, 1, 0.06))
		draw_circle(Vector2(x + _px(5), y - _px(5)), _px(4), Color(0.35, 0.9, 0.35) if on else Color(0.45, 0.45, 0.48))
		_text(String(f.get("name", "")), Vector2(x + _px(18), y), 12, CREAM if on else MUTED, on)
		if on and not String(f.get("region", "")).is_empty():
			_text(String(f.region), Vector2(r.position.x, y), 11, MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - _px(22))
		y += _px(24)
		if y > r.end.y - _px(70):
			break
	var fy := r.end.y - _px(20)
	var kx := x
	for row: Array in [["Enter", "pedir"], ["1–9", "aceitar"], ["↑↓", "escolher"], ["Del", "remover"]]:
		var w2 := _keycap(Vector2(kx, fy), String(row[0]))
		_text(String(row[1]), Vector2(kx + w2 + _px(6), fy), 11, MUTED)
		kx += w2 + _px(78)
	if _friend_input == null:
		_friend_input = LineEdit.new()
		_friend_input.placeholder_text = "nome"
		_friend_input.max_length = 16
		_friend_input.text_submitted.connect(_on_friend_name)
		add_child(_friend_input)
	_friend_input.position = Vector2(r.position.x + _px(22), r.end.y - _px(68))
	_friend_input.size = Vector2(r.size.x - _px(44), _px(26))


func _on_friend_name(t: String) -> void:
	t = t.strip_edges()
	if not t.is_empty() and adventure.online != null:
		adventure.online.friend("request", t)
	_friend_input.text = ""
	_friend_input.release_focus()


## Teclas do painel de amigos. Devolve true se consumiu o evento.
func friends_key(event: InputEvent) -> bool:
	if panel != "friends" or adventure.online == null or not (event is InputEventKey) or not event.pressed:
		return false
	var fl: Dictionary = adventure.online.friends
	var list: Array = fl.get("friends", [])
	var incoming: Array = fl.get("incoming", [])
	var k: int = (event as InputEventKey).physical_keycode
	if k == KEY_ENTER or k == KEY_KP_ENTER:
		if _friend_input != null:
			_friend_input.grab_focus()
		return true
	if k >= KEY_1 and k <= KEY_9:
		var i := k - KEY_1
		if i < incoming.size():
			adventure.online.friend("accept", String(incoming[i]))
		return true
	if k == KEY_UP or k == KEY_DOWN:
		_friend_sel = clampi(_friend_sel + (1 if k == KEY_DOWN else -1), 0, maxi(0, list.size() - 1))
		return true
	if k == KEY_DELETE and _friend_sel < list.size():
		adventure.online.friend("remove", String((list[_friend_sel] as Dictionary).get("name", "")))
		return true
	return false


func _bar(r: Rect2, ratio: float, color: Color, value: String) -> void:
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0, 1), r.size.y)), color)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0, 1), _px(2))), color.lightened(0.35))
	# valor grande e legível, centralizado sobre a barra
	_text(value, Vector2(r.position.x, r.position.y + r.size.y - _px(2)), 13, Color(1, 1, 1), true, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Slot: {key, icon, cd (0..1), locked_level, count}
func _slots(state, demo) -> Array:
	var voc: Dictionary = demo._voc.cfg
	var blink_cd: float = clampf(demo._blink_cd / maxf(0.01, float(voc.q.cooldown)), 0, 1)
	var ring_cd: float = clampf(adventure.ring_cd / maxf(0.01, float(voc.r.cooldown)), 0, 1)
	var attack_icon := {"fireball": "fire", "melee": "sword", "arrow": "bow"}.get(String(voc.attack), "fire") as String
	return [
		{"key": "Clique", "icon": attack_icon, "cd": 0.0, "lock": 0, "cost": adventure.cost("fire")},
		{"key": "Q", "icon": String(voc.q.icon), "cd": blink_cd, "lock": 0 if state.has_skill("blink") else int(adventure.config.blink_level), "cost": adventure.cost("blink")},
		{"key": "R", "icon": String(voc.r.icon), "cd": ring_cd, "lock": 0 if state.has_skill("ring") else int(adventure.config.ring_level), "cost": adventure.cost("ring")},
		{"key": "Espaço", "icon": "dodge", "cd": clampf(demo._dodge_cd_left() if demo.has_method("_dodge_cd_left") else 0.0, 0, 1), "lock": 0},
		{"key": "1", "icon": "hp_potion", "cd": adventure.potion_cd_ratio(), "lock": 0, "count": int(adventure.potions.hp)},
		{"key": "2", "icon": "mp_potion", "cd": adventure.potion_cd_ratio(), "lock": 0, "count": int(adventure.potions.mana)},
		{"key": "3", "icon": "light", "cd": adventure.core.cooldown_ratio("light"), "lock": 0, "cost": int(adventure.core.skill("light").mana), "active": adventure.core.remaining("light") / float(adventure.core.skill("light").duration), "left": adventure.core.remaining("light")},
	]


func _slot(r: Rect2, s: Dictionary) -> void:
	_frame(r, Color(0.05, 0.055, 0.075, 0.82))
	var c := r.get_center()
	var k := r.size.x / 42.0
	var dim: bool = int(s.get("lock", 0)) > 0 or (s.has("count") and int(s.count) <= 0) or (s.has("cost") and adventure.mana < float(s.cost))
	var tint := Color(1, 1, 1, 0.35 if dim else 1.0)
	match String(s.icon):
		"fire":
			draw_circle(c, 9 * k, Color(1.0, 0.45, 0.1) * tint)
			draw_circle(c + Vector2(-2, -2) * k, 5 * k, Color(1.0, 0.85, 0.35) * tint)
		"eco":
			draw_arc(c, 10 * k, 0, TAU, 20, Color(0.45, 0.85, 1.0) * tint, 2.5 * k)
			draw_circle(c + Vector2(6, -6) * k, 3 * k, Color(0.8, 0.97, 1.0) * tint)
		"ring":
			draw_arc(c, 11 * k, 0, TAU, 24, Color(1.0, 0.5, 0.15) * tint, 4 * k)
			draw_arc(c, 5 * k, 0, TAU, 16, Color(1.0, 0.8, 0.4) * tint, 2 * k)
		"sword":
			draw_line(c + Vector2(-8, 8) * k, c + Vector2(8, -8) * k, Color(0.85, 0.88, 0.95) * tint, 3 * k)
			draw_line(c + Vector2(-9, 3) * k, c + Vector2(-3, 9) * k, Color(0.75, 0.6, 0.3) * tint, 3 * k)
		"bow":
			draw_arc(c + Vector2(4, 0) * k, 11 * k, PI * 0.62, PI * 1.38, 12, Color(0.7, 0.48, 0.25) * tint, 3 * k)
			draw_line(c + Vector2(-4.5, -10) * k, c + Vector2(-4.5, 10) * k, Color(0.92, 0.9, 0.82) * tint, 1.2 * k)
			draw_line(c + Vector2(-9, 0) * k, c + Vector2(10, 0) * k, Color(0.85, 0.82, 0.75) * tint, 1.8 * k)
		"charge":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -6) * k, c + Vector2(6, -6) * k, c + Vector2(11, 0) * k, c + Vector2(6, 6) * k, c + Vector2(-10, 6) * k, c + Vector2(-5, 0) * k]), Color(0.95, 0.75, 0.35) * tint)
		"whirl":
			draw_arc(c, 10 * k, 0.3, TAU - 0.3, 20, Color(0.85, 0.9, 1.0) * tint, 3 * k)
			draw_arc(c, 5 * k, 1.5, TAU + 1.0, 14, Color(0.6, 0.7, 0.9) * tint, 2 * k)
		"leap":
			draw_arc(c + Vector2(0, 6) * k, 9 * k, PI * 1.05, PI * 1.95, 12, Color(0.55, 0.9, 0.6) * tint, 3 * k)
			draw_circle(c + Vector2(-8, 5) * k, 2.5 * k, Color(0.55, 0.9, 0.6) * tint)
		"pierce":
			draw_line(c + Vector2(-11, 0) * k, c + Vector2(9, 0) * k, Color(0.7, 0.9, 1.0) * tint, 2.5 * k)
			draw_colored_polygon(PackedVector2Array([c + Vector2(12, 0) * k, c + Vector2(6, -4) * k, c + Vector2(6, 4) * k]), Color(0.85, 0.95, 1.0) * tint)
			for x: float in [-4.0, 2.0]:
				draw_arc(c + Vector2(x, 0) * k, 5 * k, -0.9, 0.9, 6, Color(0.6, 0.85, 1.0, 0.7 * tint.a), 1.5 * k)
		"dodge":
			for o: float in [-5.0, 3.0]:
				draw_polyline(PackedVector2Array([c + Vector2(o - 3, -7) * k, c + Vector2(o + 4, 0) * k, c + Vector2(o - 3, 7) * k]), Color(0.92, 0.92, 0.88) * tint, 2.5 * k)
		"light":
			# sol pequeno: núcleo + 8 raios
			for i in 8:
				var a := TAU * float(i) / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 7 * k, c + Vector2(cos(a), sin(a)) * 11 * k, Color(1.0, 0.88, 0.5) * tint, 2 * k)
			draw_circle(c, 5.5 * k, Color(1.0, 0.95, 0.75) * tint)
		"hp_potion", "mp_potion":
			var col := Color(0.86, 0.18, 0.2) if s.icon == "hp_potion" else Color(0.25, 0.5, 0.95)
			draw_rect(Rect2(c + Vector2(-2.5, -11) * k, Vector2(5, 6) * k), Color(0.75, 0.7, 0.6) * tint)
			draw_circle(c + Vector2(0, 3) * k, 8.5 * k, Color(0.85, 0.85, 0.8, 0.6 * tint.a))
			draw_circle(c + Vector2(0, 4) * k, 7 * k, col * tint)
			draw_circle(c + Vector2(-3, 1) * k, 2 * k, Color(1, 1, 1, 0.6 * tint.a))
	# recarga: leque escuro que esvazia no sentido horário
	var cd := float(s.get("cd", 0.0))
	if cd > 0.0:
		var pts := PackedVector2Array([c])
		var steps := 24
		for i in steps + 1:
			var a := -PI * 0.5 + TAU * cd * float(i) / steps
			pts.append(c + Vector2(cos(a), sin(a)) * r.size.x * 0.75)
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(_clip_square(pts, r), Color(0, 0, 0, 0.62))
	# efeito ativo: moldura dourada que se esgota + minutos restantes
	if float(s.get("active", 0.0)) > 0.0:
		var act := float(s.active)
		draw_arc(c, r.size.x * 0.47, -PI * 0.5, -PI * 0.5 + TAU * act, 32, Color(1.0, 0.85, 0.4, 0.95), _px(1.5))
		var left := int(ceil(float(s.left)))
		_text("%d:%02d" % [left / 60, left % 60], Vector2(r.position.x, r.end.y - _px(3)), 10, Color(1.0, 0.9, 0.6), true, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - _px(3))
	if int(s.get("lock", 0)) > 0:
		draw_rect(r, Color(0, 0, 0, 0.45))
		_text("nív %d" % int(s.lock), Vector2(r.position.x, c.y + _px(4)), 10, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_text(String(s.key), r.position + Vector2(_px(3), _px(11)), 9, Color(GOLD, 0.95), true)
	if s.has("count"):
		_text("%d" % int(s.count), Vector2(r.position.x, r.end.y - _px(3)), 11, CREAM, true, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - _px(3))


func _clip_square(pts: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p.clamp(r.position, r.end))
	return out


# ------------------------------------------------------------------ painéis (atalhos)

func _panel_rect(w: float, h: float, drop := 0.0) -> Rect2:
	var r := Rect2(size * 0.5 - Vector2(_px(w), _px(h)) * 0.5 + Vector2(0, _px(drop)), Vector2(_px(w), _px(h)))
	_frame(r)
	return r


func _title(r: Rect2, t: String, key: String) -> float:
	_text(t, r.position + Vector2(_px(18), _px(30)), 15, GOLD, true)
	_text(("%s / Esc fecha" % key) if key != "Esc" else "Esc fecha", Vector2(r.position.x, r.position.y + _px(30)), 10, MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - _px(18))
	draw_line(r.position + Vector2(_px(18), _px(40)), Vector2(r.end.x - _px(18), r.position.y + _px(40)), BRASS_DIM, 1.0)
	return r.position.y + _px(66)


func _keycap(pos: Vector2, key: String) -> float:
	var w := maxf(_px(26), _bold.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(11 * _ui)).x + _px(12))
	var r := Rect2(pos + Vector2(0, -_px(15)), Vector2(w, _px(20)))
	draw_rect(r, Color(0.12, 0.12, 0.15, 0.95))
	draw_rect(r, BRASS_DIM, false, 1.0)
	_text(key, Vector2(r.position.x, pos.y), 11, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER, w)
	return w


func _help_panel() -> void:
	var r := _panel_rect(640, 380)
	var y := _title(r, "ATALHOS", "H")
	var cols := [
		["MOVIMENTO E COMBATE", [["W A S D", "andar"], ["Clique", "bola de fogo (mira no mouse)"], ["Q · Botão dir.", "Eco de Aethra (teleporte)"], ["Espaço", "esquiva"], ["R", "Anel de Brasa"], ["1 · 2", "poção de vida · de mana"], ["3", "Luz — utevo vis lux"]]],
		["MUNDO E JANELAS", [["E", "interagir / falar"], ["I", "bolsa"], ["J", "missões"], ["C", "personagem"], ["H · F1", "atalhos"], ["Roda", "zoom"], ["N", "+3 horas"], ["L", "luz da arma"], ["F2", "vocação"], ["Esc", "fechar janela"]]],
	]
	for ci in cols.size():
		var cx := r.position.x + _px(24) + ci * r.size.x * 0.5
		_text(String(cols[ci][0]), Vector2(cx, y), 11, Color(GOLD, 0.85), true)
		var yy := y + _px(30)
		for row: Array in cols[ci][1]:
			var w := _keycap(Vector2(cx, yy), String(row[0]))
			_text(String(row[1]), Vector2(cx + w + _px(10), yy), 12, CREAM)
			yy += _px(28)


## Diário (J): Nessa e as missões do conteúdo. Ativas mostram o passo (história) e o
## progresso; concluídas ficam embaixo, apagadas. Segredos revelados no rodapé.
func _quest_panel() -> void:
	var q = adventure.quests
	var ids: Array[String] = q.active_ids()
	var finished: Array[String] = q.done.duplicate()
	var r := _panel_rect(520, 150 + ids.size() * 92 + finished.size() * 20 + (0 if adventure.state.stage == "complete" else 70))
	var y := _title(r, "MISSÕES", "J")
	var x := r.position.x + _px(18)
	var w := r.size.x - _px(36)
	var stage := {"available": "Disponível", "active": "Em andamento", "claimed": "Colar recuperado", "complete": "Concluída"}
	_text("As Três Brasas", Vector2(x, y), 13, CREAM if adventure.state.stage != "complete" else MUTED, true)
	_text(String(stage.get(adventure.state.stage, "")), Vector2(r.position.x, y), 11, GOLD, false, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - _px(18))
	var yy := y + _px(20)
	if adventure.state.stage != "complete":
		for l in String(adventure.objective()).split("\n"):
			if not l.is_empty():
				_text(l, Vector2(x, yy), 12, CREAM)
			yy += _px(18)
		_text("Nessa, a lampadeira, perdeu o colar na Gruta das Raízes, a oeste do acampamento.", Vector2(x, yy), 11, MUTED, false, HORIZONTAL_ALIGNMENT_LEFT, w)
		yy += _px(24)
	for id: String in ids:
		var quest: Dictionary = q.quest(id)
		yy += _px(6)
		_text(String(quest.name), Vector2(x, yy), 13, CREAM, true)
		_text("Em andamento", Vector2(r.position.x, yy), 11, GOLD, false, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - _px(18))
		yy += _px(19)
		yy = _wrap(String(quest.summary), Vector2(x, yy), w, 11, MUTED) + _px(3)
		yy = _wrap(q.step_text(id), Vector2(x, yy), w, 12, CREAM)
		var prog: String = q.progress_text(id)
		if not prog.is_empty():
			_text(prog, Vector2(x + _px(10), yy), 11, Color(GOLD, 0.85))
			yy += _px(17)
	if not finished.is_empty():
		yy += _px(8)
		for id: String in finished:
			_text(String(q.quest(id).name), Vector2(x, yy), 12, MUTED)
			_text("Concluída", Vector2(r.position.x, yy), 11, Color(GOLD, 0.6), false, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - _px(18))
			yy += _px(20)
	if not q.secrets.is_empty():
		_text("Segredos revelados: %d de %d" % [q.secrets.size(), (q.data.secrets as Dictionary).size()], Vector2(x, r.end.y - _px(20)), 11, Color(0.6, 0.8, 1.0, 0.85))


func _char_panel() -> void:
	var r := _panel_rect(420, 300)
	var y := _title(r, "PERSONAGEM", "C")
	var st = adventure.state
	var voc: Dictionary = adventure.demo._voc.cfg
	var rows := [["Vocação", String(voc.name)], ["Nível", "%d" % st.level], ["Experiência", "%d / %d" % [st.xp, st.xp_required()]],
		["Vida", "%d / %d" % [ceili(adventure.hp), st.max_hp()]], ["Mana", "%d / %d" % [floori(adventure.mana), adventure.max_mana()]],
		[String(voc.attack_label), "%d" % adventure.basic_damage()], ["Armadura", "%d%%" % roundi(adventure.armor_ratio() * 100.0)]]
	for row: Array in rows:
		_text(String(row[0]), Vector2(r.position.x + _px(22), y), 12, MUTED)
		_text(String(row[1]), Vector2(r.position.x, y), 12, CREAM, true, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - _px(22))
		y += _px(24)


# ------------------------------------------------------------------ bolsa (estilo Tibia)
## Painel I: bonecos do equipamento à esquerda (posições do Tibia) e a grade da bolsa à
## direita. Arrastar um item até o slot ou dar duplo clique veste; item de outra vocação
## fica apagado e é recusado com o slot piscando em vermelho (sem texto). Poção com duplo
## clique é bebida. Nome e atributos aparecem ao passar o mouse.

## Slot → [coluna, linha] no boneco (Tibia: colar/cabeça, arma/peito/escudo, calça, botas).
const DOLL := {"neck": [0, 0], "head": [1, 0], "weapon": [0, 1], "chest": [1, 1], "shield": [2, 1], "legs": [1, 2], "feet": [1, 3]}
const BAG_COLS := 6
const REJECT := Color(0.95, 0.22, 0.18)

## Células desenhadas no último quadro (para o mouse): {rect, kind, id}.
var _bag_cells: Array[Dictionary] = []
var _doll_rects: Dictionary = {}
## Arraste em curso: id do item, de onde saiu e se já passou do limiar.
var _drag_id := ""
var _drag_press := Vector2.ZERO
var _drag_live := false
## Feedback: id/slot → tempo restante do brilho (recusa vermelha, aceite dourado).
var _reject_fx: Dictionary = {}
var _accept_fx: Dictionary = {}
## Online: item pedido ao servidor, ainda sem resposta (célula pulsando).
var pending_equip := ""
## Online: slot pedido para desequipar, ainda sem resposta.
var pending_unequip := ""
var _stat_fx := 0.0
## Arraste saindo de um slot do boneco (desequipar soltando na grade).
var _drag_slot := ""
## Área da grade e do painel no último quadro (soltar na grade / fora do painel).
var _grid_rect := Rect2()
var _bag_rect := Rect2()
## Brilho do ouro quando o total muda.
var _gold_fx := 0.0
var _gold_seen := -1


func _rarity_color(it: Dictionary) -> Color:
	var rc: Array = (adventure.inventory.db.get("rarity_colors", {}) as Dictionary).get(String(it.get("rarity", "common")), [0.7, 0.68, 0.62])
	return Color(float(rc[0]), float(rc[1]), float(rc[2]))


static func _arr_color(a: Variant, fallback: Color) -> Color:
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return fallback


## O que a bolsa mostra, na ordem: moedas, poções, itens de missão, equipamento guardado.
func bag_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if int(adventure.gold) > 0:
		out.append({"kind": "gold", "id": "gold", "count": int(adventure.gold)})
	for k: String in ["hp", "mana"]:
		if int(adventure.potions.get(k, 0)) > 0:
			out.append({"kind": "potion", "id": k, "count": int(adventure.potions[k])})
	var held: Dictionary = adventure.quests.items
	for id: String in held:
		out.append({"kind": "quest", "id": id, "count": int(held[id])})
	for id: String in adventure.inventory.items:
		out.append({"kind": "item", "id": id})
	return out


func _bag_panel() -> void:
	var inv = adventure.inventory
	var cell := _px(44)
	var gap := _px(5)
	var entries := bag_entries()
	var rows := ceili(float(maxi(inv.capacity(), entries.size())) / BAG_COLS)
	var doll_w := cell * 3 + gap * 2
	var grid_w := cell * BAG_COLS + gap * (BAG_COLS - 1)
	var r := _panel_rect((22 + 30 + 22) + (doll_w + grid_w) / _ui, 48 + 22 + (cell * rows + gap * (rows - 1)) / _ui)
	var y := _title(r, "BOLSA", "I") - _px(18)
	_bag_rect = r
	var mouse := get_local_mouse_position()
	var t := Time.get_ticks_msec() / 1000.0
	_bag_cells.clear()
	_doll_rects.clear()
	var drag_it: Dictionary = inv.item(_drag_id) if _drag_live else {}
	var from_slot := not _drag_slot.is_empty()
	# --- boneco do equipamento
	var dx := r.position.x + _px(22)
	var hover := {}
	for slot: String in DOLL:
		var cr: Array = DOLL[slot]
		var rect := Rect2(dx + float(cr[0]) * (cell + gap), y + float(cr[1]) * (cell + gap), cell, cell)
		rect.position.x += _shake(slot)
		_doll_rects[slot] = rect
		var id := String(inv.equipped.get(slot, ""))
		_frame(rect, Color(0.05, 0.055, 0.075, 0.9))
		if id.is_empty():
			_item_icon(rect, {"slot": slot, "color": [0.6, 0.6, 0.6]}, 0.16)
		else:
			var sa := 0.3 if (_drag_live and _drag_slot == slot) else (0.55 + 0.45 * absf(sin(t * 6.0)) if pending_unequip == slot else 1.0)
			_item_icon(rect, inv.item(id), sa)
			draw_rect(rect.grow(-1.0), Color(_rarity_color(inv.item(id)), 0.55 * sa), false, 1.0)
		if not from_slot and not drag_it.is_empty() and String(drag_it.get("slot", "")) == slot and inv.can_use(_drag_id) == "":
			draw_rect(rect.grow(_px(2)), Color(GOLD, 0.6 + 0.3 * sin(t * 8.0)), false, _px(2))
		_fx_border(rect, slot)
		if rect.has_point(mouse) and not id.is_empty():
			hover = inv.item(id)
	# números do personagem logo abaixo (brilham quando mudam)
	var sy := y + 4 * (cell + gap) + _px(14)
	var voc: Dictionary = adventure.demo._voc.cfg
	var sc := CREAM.lerp(GOLD, clampf(_stat_fx / 0.4, 0.0, 1.0))
	_text(String(voc.attack_label), Vector2(dx, sy), 11, MUTED)
	_text("%d" % adventure.basic_damage(), Vector2(dx, sy), 11, sc, true, HORIZONTAL_ALIGNMENT_RIGHT, doll_w)
	_text("Armadura", Vector2(dx, sy + _px(17)), 11, MUTED)
	_text("%d%%" % roundi(adventure.armor_ratio() * 100.0), Vector2(dx, sy + _px(17)), 11, sc, true, HORIZONTAL_ALIGNMENT_RIGHT, doll_w)
	# --- grade da bolsa
	var gx := dx + doll_w + _px(30)
	_grid_rect = Rect2(gx, y, grid_w, cell * rows + gap * (rows - 1))
	if from_slot and _drag_live:   # tirando do boneco: a grade acende onde ele vai cair
		draw_rect(_grid_rect.grow(_px(3)), Color(GOLD, 0.45 + 0.3 * sin(t * 8.0)), false, _px(2))
	for i in rows * BAG_COLS:
		var rect := Rect2(gx + (i % BAG_COLS) * (cell + gap), y + (i / BAG_COLS) * (cell + gap), cell, cell)
		draw_rect(rect, Color(0.03, 0.035, 0.05, 0.85))
		draw_rect(rect, Color(BRASS_DIM, 0.45), false, 1.0)
		if i >= entries.size():
			continue
		var e: Dictionary = entries[i]
		var id := String(e.id)
		rect.position.x += _shake(id) if e.kind == "item" else 0.0
		_bag_cells.append({"rect": rect, "kind": e.kind, "id": id})
		var dragging_this: bool = _drag_live and _drag_id == id and e.kind == "item"
		var a := 0.3 if dragging_this else 1.0
		match String(e.kind):
			"gold":
				_coin_icon(rect, a)
				_text("%d" % int(e.count), Vector2(rect.position.x, rect.end.y - _px(3)), 11, CREAM.lerp(GOLD, clampf(_gold_fx / 0.4, 0, 1)), true, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - _px(3))
			"potion":
				_slot_potion(rect, id, a)
				_text("%d" % int(e.count), Vector2(rect.position.x, rect.end.y - _px(3)), 11, CREAM, true, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - _px(3))
			"quest":
				_quest_icon(rect, id, a)
				if int(e.count) > 1:
					_text("%d" % int(e.count), Vector2(rect.position.x, rect.end.y - _px(3)), 11, CREAM, true, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - _px(3))
			"item":
				var it: Dictionary = inv.item(id)
				var usable: bool = inv.can_use(id) == ""
				if not usable:
					a *= 0.42
				if id == pending_equip:
					a *= 0.55 + 0.45 * absf(sin(t * 6.0))
				_item_icon(rect, it, a)
				draw_rect(rect.grow(-1.0), Color(_rarity_color(it), 0.6 * a), false, 1.0)
				_fx_border(rect, id)
		if rect.has_point(mouse) and not _drag_live:
			hover = _entry_info(e)
	# --- item arrastado segue o mouse
	if not drag_it.is_empty():
		_item_icon(Rect2(mouse - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), drag_it, 0.85)
	elif not hover.is_empty():
		_tooltip(mouse, hover)


## Deslocamento horizontal de quem acabou de ser recusado (tremida curta).
func _shake(key: String) -> float:
	var left := float(_reject_fx.get(key, 0.0))
	return sin(left * 70.0) * _px(3) * clampf(left / 0.5, 0.0, 1.0) if left > 0.0 else 0.0


func _fx_border(rect: Rect2, key: String) -> void:
	var rj := float(_reject_fx.get(key, 0.0))
	if rj > 0.0:
		draw_rect(rect, Color(REJECT, 0.35 * clampf(rj / 0.5, 0, 1)))
		draw_rect(rect.grow(_px(1)), Color(REJECT, clampf(rj / 0.5, 0, 1)), false, _px(2))
	var ok := float(_accept_fx.get(key, 0.0))
	if ok > 0.0:
		draw_rect(rect.grow(_px(1)), Color(GOLD, clampf(ok / 0.5, 0, 1)), false, _px(2))


func _entry_info(e: Dictionary) -> Dictionary:
	match String(e.kind):
		"potion":
			return {"name": "Poção de vida" if e.id == "hp" else "Poção de mana"}
		"gold":
			return {"name": "%d moedas de ouro" % int(e.count)}
		"quest":
			return {"name": adventure.quests.item_name(String(e.id))}
	return adventure.inventory.item(String(e.id))


## Nome (cor da raridade) e atributos do item sob o mouse.
func _tooltip(at: Vector2, it: Dictionary) -> void:
	var lines: Array[String] = []
	var names: Dictionary = adventure.inventory.db.get("stat_names", {})
	var stats: Dictionary = it.get("stats", {})
	for k: String in stats:
		var v := float(stats[k])
		var val := ("+%d%%" % roundi(v * 100.0)) if absf(v) < 1.0 and v != 0.0 else ("%+d" % roundi(v))
		lines.append("%s %s" % [val, String(names.get(k, k))])
	var w := _bold.get_string_size(String(it.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(12 * _ui)).x
	for l in lines:
		w = maxf(w, _font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(11 * _ui)).x)
	var box := Rect2(at + Vector2(_px(16), _px(12)), Vector2(w + _px(16), _px(24) + lines.size() * _px(15)))
	box.position = box.position.clamp(Vector2.ZERO, size - box.size)
	draw_rect(box, Color(0.02, 0.025, 0.035, 0.94))
	draw_rect(box, BRASS_DIM, false, 1.0)
	var col := _rarity_color(it) if it.has("slot") else CREAM
	_text(String(it.get("name", "")), box.position + Vector2(_px(8), _px(17)), 12, col, true)
	var ly := box.position.y + _px(33)
	for l in lines:
		_text(l, Vector2(box.position.x + _px(8), ly), 11, CREAM)
		ly += _px(15)


func _slot_potion(rect: Rect2, kind: String, a: float) -> void:
	var c := rect.get_center()
	var k := rect.size.x / 42.0
	var col := Color(0.86, 0.18, 0.2, a) if kind == "hp" else Color(0.25, 0.5, 0.95, a)
	draw_rect(Rect2(c + Vector2(-2.5, -11) * k, Vector2(5, 6) * k), Color(0.75, 0.7, 0.6, a))
	draw_circle(c + Vector2(0, 3) * k, 8.5 * k, Color(0.85, 0.85, 0.8, 0.6 * a))
	draw_circle(c + Vector2(0, 4) * k, 7 * k, col)
	draw_circle(c + Vector2(-3, 1) * k, 2 * k, Color(1, 1, 1, 0.6 * a))


## Itens de missão: insígnia (losango de latão), presas (dente curvo).
func _quest_icon(rect: Rect2, id: String, a: float) -> void:
	var c := rect.get_center()
	var k := rect.size.x / 42.0
	if id.contains("fang"):
		var bone := Color(0.95, 0.92, 0.8, a) if id == "wolf_fang" else Color(1.0, 0.86, 0.5, a)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -10) * k, c + Vector2(4, -9) * k, c + Vector2(3, 2) * k, c + Vector2(-1, 11) * k, c + Vector2(-3, 1) * k]), bone)
		draw_line(c + Vector2(-6, -10) * k, c + Vector2(4, -9) * k, Color(0.5, 0.35, 0.2, a), 2 * k)
		return
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11) * k, c + Vector2(9, 0) * k, c + Vector2(0, 11) * k, c + Vector2(-9, 0) * k]), Color(0.72, 0.56, 0.28, a))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6) * k, c + Vector2(5, 0) * k, c + Vector2(0, 6) * k, c + Vector2(-5, 0) * k]), Color(0.35, 0.55, 0.85, a))


## Texturas de items.json "icon" (gerados por src/items/tools/), lidas uma vez.
var _icon_tex: Dictionary = {}


## Ícone gerado do item (items.json "icon"), ou null para cair no desenho por código.
func _item_tex(it: Dictionary) -> Texture2D:
	var path := String(it.get("icon", ""))
	if path.is_empty():
		return null
	if not _icon_tex.has(path):
		_icon_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _icon_tex[path]


## Ícone desenhado por slot (forma) e cor do item (items.json "color"); arma pela vocação.
## Se o item tem "icon", desenha a textura gerada no lugar.
func _item_icon(rect: Rect2, it: Dictionary, a: float) -> void:
	var tex := _item_tex(it)
	if tex != null:
		draw_texture_rect(tex, rect.grow(-rect.size.x * 0.04), false, Color(1, 1, 1, a))
		return
	var c := rect.get_center()
	var k := rect.size.x / 42.0
	var base := _arr_color(it.get("color"), Color(0.6, 0.6, 0.6))
	if base.v < 0.5:
		base = base.lightened(0.3)  # madeira/tecido escuro some no fundo escuro do slot
	var col := Color(base, a)
	var dark := Color(base.darkened(0.45), a)
	var glow := Color(_arr_color(it.get("glow"), base.lightened(0.4)), a)
	var classes: Array = it.get("classes", [])
	var cls := String(classes[0]) if classes.size() == 1 else ""
	match String(it.get("slot", "")):
		"weapon":
			match cls:
				"fire_mage":
					draw_line(c + Vector2(-9, 11) * k, c + Vector2(6, -6) * k, col, 3 * k)
					draw_circle(c + Vector2(8, -8) * k, 4.5 * k, glow)
					draw_circle(c + Vector2(7, -9) * k, 1.8 * k, Color(1, 1, 1, 0.7 * a))
				"archer":
					draw_arc(c + Vector2(4, 0) * k, 11 * k, PI * 0.62, PI * 1.38, 12, col, 3 * k)
					draw_line(c + Vector2(-4.5, -10) * k, c + Vector2(-4.5, 10) * k, Color(glow if it.get("glow_energy", 0.0) > 0.0 else Color(0.92, 0.9, 0.82), a), 1.2 * k)
				_:
					draw_line(c + Vector2(-7, 7) * k, c + Vector2(9, -9) * k, col, 3.5 * k)
					draw_line(c + Vector2(-9, 3) * k, c + Vector2(-3, 9) * k, Color(0.75, 0.6, 0.3, a), 3 * k)
					draw_line(c + Vector2(-10, 10) * k, c + Vector2(-7, 7) * k, dark, 3 * k)
		"head":
			var pts := PackedVector2Array()
			for i in 9:
				var ang := PI + PI * float(i) / 8.0
				pts.append(c + Vector2(cos(ang) * 9, sin(ang) * 9 + 3) * k)
			draw_colored_polygon(pts, col)
			draw_rect(Rect2(c + Vector2(-11, 2) * k, Vector2(22, 3.5) * k), dark)
		"neck":
			draw_arc(c + Vector2(0, -4) * k, 8 * k, 0.15 * PI, 0.85 * PI, 10, Color(0.8, 0.7, 0.45, a), 1.5 * k)
			draw_arc(c + Vector2(0, -10) * k, 8 * k, 0.1, PI - 0.1, 10, Color(0.8, 0.7, 0.45, a), 1.5 * k)
			draw_circle(c + Vector2(0, 5) * k, 4.5 * k, col)
			draw_circle(c + Vector2(-1.5, 3.5) * k, 1.5 * k, Color(1, 1, 1, 0.6 * a))
		"chest":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -8) * k, c + Vector2(-4, -11) * k, c + Vector2(4, -11) * k, c + Vector2(11, -8) * k,
				c + Vector2(8, -2) * k, c + Vector2(7, 11) * k, c + Vector2(-7, 11) * k, c + Vector2(-8, -2) * k]), col)
			draw_line(c + Vector2(0, -10) * k, c + Vector2(0, 10) * k, dark, 1.2 * k)
		"legs":
			draw_rect(Rect2(c + Vector2(-8, -10) * k, Vector2(16, 5) * k), dark)
			draw_rect(Rect2(c + Vector2(-8, -6) * k, Vector2(7, 17) * k), col)
			draw_rect(Rect2(c + Vector2(1, -6) * k, Vector2(7, 17) * k), col)
		"feet":
			for o: float in [-6.0, 5.0]:
				draw_colored_polygon(PackedVector2Array([c + Vector2(o - 3, -9) * k, c + Vector2(o + 2, -9) * k, c + Vector2(o + 2, 5) * k,
					c + Vector2(o + 6, 6) * k, c + Vector2(o + 6, 10) * k, c + Vector2(o - 3, 10) * k]), col)
		"shield":
			match cls:
				"fire_mage":
					if String(it.get("name", "")).to_lower().contains("orbe"):
						draw_circle(c, 9 * k, Color(glow, 0.5 * a))
						draw_circle(c, 6 * k, col)
					else:
						draw_rect(Rect2(c + Vector2(-8, -10) * k, Vector2(16, 20) * k), col)
						draw_rect(Rect2(c + Vector2(-8, -10) * k, Vector2(3, 20) * k), dark)
						draw_circle(c + Vector2(2, 0) * k, 3 * k, Color(1.0, 0.6, 0.2, a))
				_:
					draw_circle(c, 11 * k, dark)
					draw_circle(c, 9 * k, col)
					draw_circle(c, 3 * k, Color(0.8, 0.8, 0.85, a))


# ------------------------------------------------------------------ bolsa: mouse

## Mouse do painel I: arrastar item até um slot, duplo clique veste/bebe. true = consumiu.
func bag_mouse(event: InputEvent) -> bool:
	if panel == "shop":
		return _shop_mouse(event)
	if panel == "trade":
		return _trade_mouse(event)
	if panel != "bag":
		return false
	if event is InputEventMouseMotion:
		if not _drag_id.is_empty() and not _drag_live and (event as InputEventMouseMotion).position.distance_to(_drag_press) > _px(6):
			_drag_live = true
		return not _drag_id.is_empty()
	if not (event is InputEventMouseButton) or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return false
	var mb := event as InputEventMouseButton
	if mb.pressed:
		var slot_hit := _slot_at(mb.position)
		if not slot_hit.is_empty():
			# boneco: duplo clique tira; arrastar até a grade também
			if adventure.inventory.equipped.has(slot_hit):
				if mb.double_click:
					_drag_id = ""
					_drag_slot = ""
					_drag_live = false
					unequip_slot(slot_hit)
				else:
					_drag_id = String(adventure.inventory.equipped[slot_hit])
					_drag_slot = slot_hit
					_drag_press = mb.position
					_drag_live = false
			return true
		var cell := _cell_at(mb.position)
		if cell.is_empty():
			return _bag_rect.has_point(mb.position)   # clique dentro do painel não ataca
		if mb.double_click:
			_drag_id = ""
			_drag_live = false
			use_entry(String(cell.kind), String(cell.id))
			return true
		if cell.kind == "item":
			_drag_id = String(cell.id)
			_drag_slot = ""
			_drag_press = mb.position
			_drag_live = false
		return true
	# soltou
	var id := _drag_id
	var from := _drag_slot
	var live := _drag_live
	_drag_id = ""
	_drag_slot = ""
	_drag_live = false
	if id.is_empty() or not live:
		return true
	if not from.is_empty():
		if _grid_rect.grow(_px(6)).has_point(mb.position):
			unequip_slot(from)
		return true
	for slot: String in _doll_rects:
		if (_doll_rects[slot] as Rect2).has_point(mb.position):
			drop_on_slot(id, slot)
			return true
	if not _bag_rect.has_point(mb.position):
		drop_outside(id, mb.position)   # fora da bolsa: chão ou outro jogador (online)
	return true


func _slot_at(p: Vector2) -> String:
	for slot: String in _doll_rects:
		if (_doll_rects[slot] as Rect2).has_point(p):
			return slot
	return ""


## Desequipar (duplo clique ou arrastar o slot até a grade). Bolsa cheia: o slot treme em
## vermelho. Online espera o servidor (o slot pulsa).
func unequip_slot(slot: String) -> bool:
	var err: String = adventure.unequip_item(slot)
	if err != "":
		_reject_fx[slot] = 0.5
		return false
	if adventure.online != null:
		pending_unequip = slot
	else:
		unequip_done(slot)
	return true


func unequip_done(slot := "") -> void:
	if slot.is_empty():
		slot = pending_unequip
	pending_unequip = ""
	if not slot.is_empty():
		_accept_fx[slot] = 0.5
	_stat_fx = 0.6


func unequip_refused() -> void:
	if not pending_unequip.is_empty():
		_reject_fx[pending_unequip] = 0.5
	pending_unequip = ""


## Item arrastado para fora da bolsa. Online: sobre outro jogador pede troca (com o item já
## oferecido); no chão, larga. Offline não há para onde ir: o item treme e volta.
func drop_outside(id: String, at: Vector2) -> void:
	if adventure.online == null or not adventure.drop_item(id, at):
		_reject_fx[id] = 0.5


func _cell_at(p: Vector2) -> Dictionary:
	for c: Dictionary in _bag_cells:
		if (c.rect as Rect2).has_point(p):
			return c
	return {}


## Duplo clique numa célula: poção é bebida; equipamento é vestido no slot dele.
func use_entry(kind: String, id: String) -> void:
	match kind:
		"potion":
			adventure.drink(id)
		"item":
			drop_on_slot(id, String(adventure.inventory.item(id).get("slot", "")))


## Soltar o item no slot: recusa (vermelho) se o slot não é o dele ou a vocação não usa;
## senão pede ao jogo (offline veste na hora; online espera o servidor).
func drop_on_slot(id: String, slot: String) -> bool:
	var inv = adventure.inventory
	if String(inv.item(id).get("slot", "")) != slot or inv.can_use(id) != "":
		equip_refused(id, slot)
		return false
	var err: String = adventure.equip_item(id)
	if err != "":
		equip_refused(id, slot)
		return false
	if adventure.online != null:
		pending_equip = id
	else:
		equip_done(slot)
	return true


## Recusa: célula e slot tremem e piscam em vermelho.
func equip_refused(id := "", slot := "") -> void:
	if id.is_empty():
		id = pending_equip
	if slot.is_empty():
		slot = String(adventure.inventory.item(id).get("slot", ""))
	pending_equip = ""
	_reject_fx[id] = 0.5
	if not slot.is_empty():
		_reject_fx[slot] = 0.5


## Aceite: o slot brilha em dourado e os números do personagem acendem.
func equip_done(slot := "") -> void:
	if slot.is_empty() and not pending_equip.is_empty():
		slot = String(adventure.inventory.item(pending_equip).get("slot", ""))
	pending_equip = ""
	if not slot.is_empty():
		_accept_fx[slot] = 0.5
	_stat_fx = 0.6


## Moedas de ouro empilhadas (estilo Tibia).
func _coin_icon(rect: Rect2, a: float, small := false) -> void:
	var c := rect.get_center()
	var k := rect.size.x / 42.0 * (2.2 if small else 1.0)
	var offs: Array = [Vector2(-5, 5), Vector2(4, 4), Vector2(-1, -2)] if not small else [Vector2(0, 0)]
	for o: Vector2 in offs:
		var p := c + o * k
		draw_circle(p, 6.5 * k, Color(0.55, 0.38, 0.1, a))
		draw_circle(p + Vector2(-0.6, -0.8) * k, 5.6 * k, Color(1.0, 0.8, 0.28, a))
		draw_circle(p + Vector2(-0.6, -0.8) * k, 3.4 * k, Color(0.92, 0.66, 0.18, a))
		draw_circle(p + Vector2(-2.2, -2.6) * k, 1.3 * k, Color(1, 1, 0.85, 0.8 * a))


# ------------------------------------------------------------------ troca com a Nessa (estilo Tibia)
## Abre ao falar com a Nessa (fora dos momentos da missão). À esquerda o que ela vende, à
## direita o que ela compra da bolsa (com o preço); duplo clique compra/vende um. Recusa (sem
## ouro, longe) = a célula treme em vermelho; aceite = brilho dourado e o ouro acende.

## Células do último quadro: {rect, kind: buy|sell, id}.
var _shop_cells: Array[Dictionary] = []
var _shop_last := ""


func open_shop() -> void:
	panel = "shop"


func _shop_panel() -> void:
	var inv = adventure.inventory
	var shop: Dictionary = adventure.shop
	var cell := _px(42)
	var gap := _px(5)
	var cols := 5
	var sell_rows := maxi(2, ceili(float(inv.items.size()) / cols))
	# um pouco abaixo do centro: a Nessa (e a fala sobre a cabeça dela) continua visível
	var r := _panel_rect(22 + 150 + 30 + (cols * 42 + (cols - 1) * 5) + 22, 66 + 18 + sell_rows * 47 + 46, 95)
	var y := _title(r, "NESSA", "E") - _px(10)
	var mouse := get_local_mouse_position()
	_shop_cells.clear()
	var hover := {}
	var lx := r.position.x + _px(22)
	_text("Comprar", Vector2(lx, y), 11, MUTED, true)
	var ry := y + _px(10)
	for kind: String in Economy.POTIONS:
		var price := Economy.buy_price(shop, kind)
		if price < 0:
			continue
		var rect := Rect2(lx, ry, cell, cell)
		rect.position.x += _shake("buy:" + kind)
		draw_rect(rect, Color(0.03, 0.035, 0.05, 0.85))
		draw_rect(rect, Color(BRASS_DIM, 0.45), false, 1.0)
		_slot_potion(rect, kind, 1.0)
		_fx_border(rect, "buy:" + kind)
		var row := Rect2(rect.position, Vector2(_px(150), cell))
		_text("Poção de vida" if kind == "hp" else "Poção de mana", Vector2(rect.end.x + _px(8), ry + _px(17)), 11, CREAM)
		var afford: bool = int(adventure.gold) >= price
		_coin_icon(Rect2(Vector2(rect.end.x + _px(6), ry + _px(22)), Vector2(_px(18), _px(18))), 1.0, true)
		_text("%d" % price, Vector2(rect.end.x + _px(26), ry + _px(36)), 11, GOLD if afford else Color(MUTED, 0.8), true)
		_shop_cells.append({"rect": row, "kind": "buy", "id": kind})
		if row.has_point(mouse):
			draw_rect(row.grow(_px(1)), Color(GOLD, 0.25), false, 1.0)
		ry += cell + gap
	# --- vender: a bolsa (só o que não está vestido) com o preço de cada um
	var sx := lx + _px(150 + 30)
	_text("Vender", Vector2(sx, y), 11, MUTED, true)
	var gy := y + _px(10)
	for i in sell_rows * cols:
		var rect := Rect2(sx + (i % cols) * (cell + gap), gy + (i / cols) * (cell + gap), cell, cell)
		draw_rect(rect, Color(0.03, 0.035, 0.05, 0.85))
		draw_rect(rect, Color(BRASS_DIM, 0.45), false, 1.0)
		if i >= inv.items.size():
			continue
		var id := String(inv.items[i])
		rect.position.x += _shake("sell:" + id)
		var it: Dictionary = inv.item(id)
		_item_icon(rect, it, 1.0)
		draw_rect(rect.grow(-1.0), Color(_rarity_color(it), 0.6), false, 1.0)
		_text("%d" % Economy.sell_price(shop, id, it), Vector2(rect.position.x, rect.end.y - _px(3)), 10, GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - _px(3))
		_fx_border(rect, "sell:" + id)
		_shop_cells.append({"rect": rect, "kind": "sell", "id": id})
		if rect.has_point(mouse):
			hover = it
	# --- ouro do jogador no pé
	var fy := r.end.y - _px(34)
	draw_line(Vector2(lx, fy - _px(6)), Vector2(r.end.x - _px(22), fy - _px(6)), BRASS_DIM, 1.0)
	_coin_icon(Rect2(Vector2(lx, fy), Vector2(_px(26), _px(26))), 1.0)
	_text("%d" % int(adventure.gold), Vector2(lx + _px(32), fy + _px(18)), 13, CREAM.lerp(GOLD, clampf(_gold_fx / 0.4, 0, 1)), true)
	if not hover.is_empty():
		_tooltip(mouse, hover)


func _shop_mouse(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton) or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return false
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return true
	for c: Dictionary in _shop_cells:
		if (c.rect as Rect2).has_point(mb.position):
			if mb.double_click:
				if String(c.kind) == "buy":
					shop_buy(String(c.id))
				else:
					shop_sell(String(c.id))
			return true
	return true


## Compra uma poção (duplo clique). true = feito/pedido.
func shop_buy(kind: String) -> bool:
	_shop_last = "buy:" + kind
	if adventure.buy_potion(kind) != "":
		_reject_fx[_shop_last] = 0.5
		return false
	if adventure.online == null:
		shop_done()
	return true


## Vende um item da bolsa (duplo clique). true = feito/pedido.
func shop_sell(id: String) -> bool:
	_shop_last = "sell:" + id
	if adventure.sell_item(id) != "":
		_reject_fx[_shop_last] = 0.5
		return false
	if adventure.online == null:
		shop_done()
	return true


func shop_done() -> void:
	if _shop_last.begins_with("buy:"):
		_accept_fx[_shop_last] = 0.5
	_gold_fx = 0.6


func shop_refused() -> void:
	if not _shop_last.is_empty():
		_reject_fx[_shop_last] = 0.5


# ------------------------------------------------------------------ troca entre jogadores (online)
## Abre para os dois quando um arrasta um item da bolsa até o outro. Em cima: a sua oferta e a
## do outro (moldura verde = confirmou), cada uma com a linha de ouro e poções. Embaixo: a sua
## bolsa (duplo clique põe/tira da oferta) e as fontes de ouro/poção (clique põe 10 moedas ou
## 1 poção; clique na linha da sua oferta ou botão direito na fonte tira).
## Botões só com ícone: ✓ confirma, ✕ cancela. Mudar a oferta desfaz as confirmações.

## Moedas por clique na fonte de ouro da troca.
const TRADE_GOLD_STEP := 10

## {with, name, mine, theirs, my_gold, their_gold, my_pots, their_pots, my_ok, their_ok}
## vindo do servidor; {} = sem troca.
var trade: Dictionary = {}
var _trade_cells: Array[Dictionary] = []
var _trade_ok_rect := Rect2()
var _trade_x_rect := Rect2()


func _offer_box(at: Vector2, title: String, items: Array, ok: bool, mine: bool, cell: float, gap: float) -> void:
	var box := Rect2(at, Vector2(cell * 3 + gap * 2 + _px(12), cell * 2 + gap + _px(30) + _px(26)))
	draw_rect(box, Color(0.02, 0.025, 0.035, 0.7))
	draw_rect(box, Color(0.35, 0.85, 0.4, 0.95) if ok else BRASS_DIM, false, _px(2) if ok else 1.0)
	_text(title, box.position + Vector2(_px(6), _px(15)), 11, Color(0.6, 1.0, 0.6) if ok else CREAM, true)
	for i in 6:
		var rect := Rect2(box.position + Vector2(_px(6) + (i % 3) * (cell + gap), _px(22) + (i / 3) * (cell + gap)), Vector2(cell, cell))
		draw_rect(rect, Color(0.03, 0.035, 0.05, 0.85))
		draw_rect(rect, Color(BRASS_DIM, 0.45), false, 1.0)
		if i < items.size():
			var it: Dictionary = adventure.inventory.item(String(items[i]))
			_item_icon(rect, it, 1.0)
			draw_rect(rect.grow(-1.0), Color(_rarity_color(it), 0.6), false, 1.0)
			_trade_cells.append({"rect": rect, "kind": "mine" if mine else "theirs", "id": String(items[i])})
	# ouro e poções da oferta: ícone + quantidade (só aparecem quando há algo)
	var side := "my" if mine else "their"
	var pots: Dictionary = trade.get(side + "_pots", {})
	var amounts := {"gold": int(trade.get(side + "_gold", 0)), "hp": int(pots.get("hp", 0)), "mana": int(pots.get("mana", 0))}
	var w := (box.size.x - _px(12)) / 3.0
	var col := 0
	for what: String in ["gold", "hp", "mana"]:
		var chip := Rect2(box.position + Vector2(_px(6) + col * w, cell * 2 + gap + _px(26)), Vector2(w - _px(3), _px(22)))
		col += 1
		var n := int(amounts[what])
		if n <= 0:
			continue
		var ico := Rect2(chip.position, Vector2(chip.size.y, chip.size.y))
		if what == "gold":
			_coin_icon(ico, 1.0, true)
		else:
			_slot_potion(ico.grow(_px(4)), what, 1.0)
		_text("%d" % n, Vector2(ico.end.x + _px(2), chip.end.y - _px(5)), 11, GOLD if what == "gold" else CREAM, true)
		_fx_border(chip, "trade:" + side + ":" + what)
		if mine:
			_trade_cells.append({"rect": chip, "kind": "mine_amount", "id": what})


func _trade_panel() -> void:
	var cell := _px(40)
	var gap := _px(5)
	var r := _panel_rect(22 + 2 * (3 * 40 + 2 * 5 + 12) + 20 + 22, 66 + 2 * 40 + 5 + 30 + 26 + 20 + 3 * 45 + 50)
	var y := _title(r, "TROCA", "Esc") - _px(18)
	var mouse := get_local_mouse_position()
	_trade_cells.clear()
	var x := r.position.x + _px(22)
	var mine: Array = trade.get("mine", [])
	var theirs: Array = trade.get("theirs", [])
	_offer_box(Vector2(x, y), "Você", mine, bool(trade.get("my_ok", false)), true, cell, gap)
	var bw := cell * 3 + gap * 2 + _px(12)
	_offer_box(Vector2(x + bw + _px(20), y), String(trade.get("name", "")), theirs, bool(trade.get("their_ok", false)), false, cell, gap)
	# --- a sua bolsa (menos o que já está na oferta)
	var gy := y + cell * 2 + gap + _px(30) + _px(26) + _px(20)
	var left: Array = (adventure.inventory.items as Array).duplicate()
	for id: Variant in mine:
		left.erase(id)
	var cols := 6
	for i in 3 * cols:
		var rect := Rect2(x + (i % cols) * (cell + gap), gy + (i / cols) * (cell + gap), cell, cell)
		draw_rect(rect, Color(0.03, 0.035, 0.05, 0.85))
		draw_rect(rect, Color(BRASS_DIM, 0.45), false, 1.0)
		if i >= left.size():
			continue
		var id := String(left[i])
		var it: Dictionary = adventure.inventory.item(id)
		rect.position.x += _shake("trade:" + id)
		_item_icon(rect, it, 1.0)
		draw_rect(rect.grow(-1.0), Color(_rarity_color(it), 0.6), false, 1.0)
		_fx_border(rect, "trade:" + id)
		_trade_cells.append({"rect": rect, "kind": "bag", "id": id})
	# --- botões (só ícones)
	var by := r.end.y - _px(46)
	# --- fontes: o seu ouro e as suas poções que ainda não estão na oferta
	var my_pots: Dictionary = trade.get("my_pots", {})
	var have := {"gold": int(adventure.gold) - int(trade.get("my_gold", 0)),
		"hp": int(adventure.potions.get("hp", 0)) - int(my_pots.get("hp", 0)),
		"mana": int(adventure.potions.get("mana", 0)) - int(my_pots.get("mana", 0))}
	var sx := x
	for what: String in ["gold", "hp", "mana"]:
		var rect := Rect2(sx, by, cell, cell)
		sx += cell + gap
		var n := maxi(0, int(have[what]))
		rect.position.x += _shake("trade:src:" + what)
		_frame(rect, Color(0.03, 0.035, 0.05, 0.85))
		var a := 1.0 if n > 0 else 0.35
		if what == "gold":
			_coin_icon(rect, a)
		else:
			_slot_potion(rect, what, a)
		_text("%d" % n, Vector2(rect.position.x, rect.end.y - _px(3)), 11, CREAM if n > 0 else Color(CREAM, 0.4), true, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - _px(3))
		_fx_border(rect, "trade:src:" + what)
		if rect.has_point(mouse):
			draw_rect(rect.grow(_px(1)), Color(GOLD, 0.5), false, 1.0)
		_trade_cells.append({"rect": rect, "kind": "source", "id": what})
	_trade_ok_rect = Rect2(r.end.x - _px(22) - cell * 2 - gap, by, cell, cell)
	_trade_x_rect = Rect2(r.end.x - _px(22) - cell, by, cell, cell)
	var ok_on := bool(trade.get("my_ok", false))
	_frame(_trade_ok_rect, Color(0.08, 0.2, 0.1, 0.95) if ok_on else Color(0.05, 0.055, 0.075, 0.9))
	var c := _trade_ok_rect.get_center()
	var k := cell / 42.0
	draw_polyline(PackedVector2Array([c + Vector2(-9, 0) * k, c + Vector2(-3, 7) * k, c + Vector2(10, -8) * k]), Color(0.4, 0.95, 0.45), 3.5 * k)
	_frame(_trade_x_rect)
	c = _trade_x_rect.get_center()
	draw_line(c + Vector2(-8, -8) * k, c + Vector2(8, 8) * k, REJECT, 3.5 * k)
	draw_line(c + Vector2(8, -8) * k, c + Vector2(-8, 8) * k, REJECT, 3.5 * k)
	for b: Rect2 in [_trade_ok_rect, _trade_x_rect]:
		if b.has_point(mouse):
			draw_rect(b.grow(_px(1)), Color(GOLD, 0.5), false, 1.0)
	for tc: Dictionary in _trade_cells:
		if (tc.rect as Rect2).has_point(mouse) and String(tc.kind) in ["bag", "mine", "theirs"]:
			_tooltip(mouse, adventure.inventory.item(String(tc.id)))
			break


func _trade_mouse(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and adventure.online != null:
		for tc: Dictionary in _trade_cells:
			if (tc.rect as Rect2).has_point(mb.position) and String(tc.kind) in ["source", "mine_amount"]:
				trade_amount(String(tc.id), false)
				return true
		return true
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	if not mb.pressed or adventure.online == null:
		return true
	if _trade_ok_rect.has_point(mb.position):
		adventure.online.trade_ok()
		return true
	if _trade_x_rect.has_point(mb.position):
		adventure.online.trade_cancel()
		trade = {}
		panel = ""
		return true
	for tc: Dictionary in _trade_cells:
		if (tc.rect as Rect2).has_point(mb.position) and String(tc.kind) in ["source", "mine_amount"]:
			trade_amount(String(tc.id), String(tc.kind) == "source")
			return true
	if not mb.double_click:
		return true
	for tc: Dictionary in _trade_cells:
		if (tc.rect as Rect2).has_point(mb.position):
			match String(tc.kind):
				"bag":
					if (trade.get("mine", []) as Array).size() >= int(adventure.shop.get("trade_max_items", 6)):
						_reject_fx["trade:" + String(tc.id)] = 0.5
					else:
						adventure.online.trade_add(String(tc.id))
				"mine":
					adventure.online.trade_remove(String(tc.id))
			break
	return true


## Põe (add) ou tira ouro (de TRADE_GOLD_STEP em TRADE_GOLD_STEP) ou uma poção da sua oferta.
## Sem o que pôr/tirar, a fonte treme em vermelho. O servidor confere e manda o estado novo.
func trade_amount(what: String, add: bool) -> bool:
	if trade.is_empty() or adventure.online == null:
		return false
	var cur := int(trade.get("my_gold", 0)) if what == "gold" else int((trade.get("my_pots", {}) as Dictionary).get(what, 0))
	var have := int(adventure.gold) if what == "gold" else int(adventure.potions.get(what, 0))
	var step := TRADE_GOLD_STEP if what == "gold" else 1
	var n := mini(have, cur + step) if add else maxi(0, cur - step)
	if n == cur:
		_reject_fx["trade:src:" + what] = 0.5
		return false
	adventure.online.trade_set(what, n)
	return true


## Estado da troca vindo do servidor (net_play): abre/atualiza/fecha o painel.
func trade_state(ev: Dictionary) -> void:
	match String(ev.get("op", "")):
		"open", "state":
			trade = ev.duplicate()
			panel = "trade"
		"done":
			trade = {}
			if panel == "trade":
				panel = "bag"   # a bolsa abre mostrando o que chegou
			_stat_fx = 0.6
		"close":
			trade = {}
			if panel == "trade":
				panel = ""



# ------------------------------------------------------------------ vocação

## Retângulos dos 3 cartões (para clique). Calculados no desenho.
var _voc_cards: Array[Rect2] = []


func _vocation_panel() -> void:
	var data: Dictionary = adventure.demo._voc.all
	var order: Array = data.order
	var r := _panel_rect(760, 380)
	var y := _title(r, "ESCOLHA SUA VOCAÇÃO", "F2")
	_voc_cards.clear()
	var w := (r.size.x - _px(24) * 2 - _px(14) * (order.size() - 1)) / order.size()
	for i in order.size():
		var id := String(order[i])
		var v: Dictionary = data.classes[id]
		var card := Rect2(r.position.x + _px(24) + i * (w + _px(14)), y - _px(14), w, r.end.y - y - _px(10))
		_voc_cards.append(card)
		var current: bool = id == adventure.demo._voc.id
		_frame(card, Color(0.09, 0.08, 0.06, 0.92) if current else Color(0.05, 0.055, 0.075, 0.85))
		if current:
			draw_rect(card, GOLD, false, 2.0)
		var cx := card.position.x + _px(14)
		var cy := card.position.y + _px(26)
		_keycap(Vector2(cx, cy), "%d" % (i + 1))
		_text(String(v.name).to_upper(), Vector2(cx + _px(36), cy), 14, GOLD if current else CREAM, true)
		cy += _px(26)
		cy = _wrap(String(v.role), Vector2(cx, cy), card.size.x - _px(28), 11, MUTED)
		cy += _px(12)
		var stats: Dictionary = v.stats
		for key: String in ["vida", "mana", "alcance", "mobilidade"]:
			_text(key.capitalize(), Vector2(cx, cy), 11, CREAM)
			var bx := cx + _px(84)
			for p in 5:
				var col := GOLD if p < int(stats.get(key, 0)) else Color(0.25, 0.23, 0.2)
				draw_rect(Rect2(bx + p * _px(16), cy - _px(9), _px(12), _px(8)), col)
			cy += _px(20)
		cy += _px(6)
		_text("Q  " + String(v.q.name), Vector2(cx, cy), 11, CREAM)
		cy += _px(18)
		_text("R  " + String(v.r.name), Vector2(cx, cy), 11, CREAM)


## Texto com quebra de linha simples; devolve o y seguinte.
func _wrap(t: String, pos: Vector2, width: float, size_pt: int, color: Color) -> float:
	var line := ""
	var y := pos.y
	for word in t.split(" "):
		var test := word if line.is_empty() else line + " " + word
		if _font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size_pt * _ui)).x > width and not line.is_empty():
			_text(line, Vector2(pos.x, y), size_pt, color)
			y += _px(size_pt + 5)
			line = word
		else:
			line = test
	if not line.is_empty():
		_text(line, Vector2(pos.x, y), size_pt, color)
		y += _px(size_pt + 5)
	return y


## Tecla 1..3 com o painel aberto: escolhe a vocação (true = consumiu a tecla).
func vocation_key(index: int) -> bool:
	if panel != "vocation":
		return false
	var order: Array = adventure.demo._voc.all.order
	if index >= 0 and index < order.size():
		adventure.choose_vocation(String(order[index]))
	return true


func vocation_click(pos: Vector2) -> bool:
	if panel != "vocation":
		return false
	for i in _voc_cards.size():
		if _voc_cards[i].has_point(pos):
			return vocation_key(i)
	return true
