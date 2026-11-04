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
const PANELS := ["help", "quest", "char", "bag", "vocation"]

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
	_mana_flash = maxf(0.0, _mana_flash - get_process_delta_time())
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

func _panel_rect(w: float, h: float) -> Rect2:
	var r := Rect2(size * 0.5 - Vector2(_px(w), _px(h)) * 0.5, Vector2(_px(w), _px(h)))
	_frame(r)
	return r


func _title(r: Rect2, t: String, key: String) -> float:
	_text(t, r.position + Vector2(_px(18), _px(30)), 15, GOLD, true)
	_text("%s / Esc fecha" % key, Vector2(r.position.x, r.position.y + _px(30)), 10, MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - _px(18))
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


func _bag_panel() -> void:
	var r := _panel_rect(420, 320)
	var y := _title(r, "BOLSA", "I")
	var inv = adventure.inventory
	_text("Equipado", Vector2(r.position.x + _px(18), y), 11, Color(GOLD, 0.85), true)
	y += _px(22)
	for slot: String in inv.equipped:
		var it: Dictionary = inv.item(String(inv.equipped[slot]))
		_text("•  " + String(it.get("name", "")), Vector2(r.position.x + _px(22), y), 12, CREAM)
		y += _px(20)
	y += _px(8)
	_text("Consumíveis", Vector2(r.position.x + _px(18), y), 11, Color(GOLD, 0.85), true)
	y += _px(22)
	_text("•  Poção de vida  ×%d" % int(adventure.potions.hp), Vector2(r.position.x + _px(22), y), 12, CREAM)
	_text("•  Poção de mana  ×%d" % int(adventure.potions.mana), Vector2(r.position.x + _px(22), y + _px(20)), 12, CREAM)
	y += _px(46)
	var held: Dictionary = adventure.quests.items
	var spare: Array = inv.items
	if not held.is_empty() or not spare.is_empty():
		_text("Mochila", Vector2(r.position.x + _px(18), y), 11, Color(GOLD, 0.85), true)
		y += _px(22)
		for it: String in held:
			_text("•  %s  ×%d" % [adventure.quests.item_name(it), int(held[it])], Vector2(r.position.x + _px(22), y), 12, CREAM)
			y += _px(20)
		for it: String in spare:
			_text("•  " + String(inv.item(it).get("name", it)), Vector2(r.position.x + _px(22), y), 12, MUTED)
			y += _px(20)



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
