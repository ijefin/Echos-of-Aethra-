class_name CombatHud
extends Control
## HUD de combate em resolução NATIVA da tela (fora do SubViewport de pixel art), para o
## texto ficar nítido. Escala pela altura da janela (referência 720 px).
## Mostra: quadro do jogador (vida, recurso, nível de especialização), grupo, hotbar com
## recarga/GCD/mira, barra de conjuração, inimigo sob o cursor, plaquinhas de nome,
## barras de vida e números de dano projetados do mundo, mensagens e ajuda.
## Só exibe estado — nunca altera o jogo.
## Dívida (regra de UI): textos fixos aguardam o sistema de localização; sem gamepad ainda.
##
## Uso: hud.bind(kit, combat_world, world_to_screen, mouse_world)

const REF_HEIGHT := 720.0
const PANEL_BG := Color(0.07, 0.045, 0.06, 0.86)
const PANEL_EDGE := Color(0.85, 0.64, 0.25, 0.75)
const CREAM := Color(1.0, 0.96, 0.82)
const MUTED := Color(0.78, 0.72, 0.66)
const GOLD := Color(0.95, 0.74, 0.3)
const HP_COL := Color(0.78, 0.22, 0.25)
const DANGER := Color(0.66, 0.3, 0.8)
const FIRE := Color(1.0, 0.5, 0.12)
const FIRE_Y := Color(1.0, 0.85, 0.38)
const STEEL := Color(0.78, 0.84, 0.92)
const NUMBER_COLORS := {
	"light": Color(0.95, 0.76, 0.58), "medium": Color(1.0, 0.62, 0.25), "heavy": Color(1.0, 0.86, 0.38),
	"burn": Color(0.92, 0.52, 0.25), "ignite": Color(1.0, 0.92, 0.45), "player": Color(1.0, 0.38, 0.38),
	"level": Color(0.75, 0.9, 1.0),
}

var _kit: ClassKit
var _world: CombatWorld
var _to_screen: Callable
var _mouse_world: Callable
var _font: Font
var _font_bold: Font
var _msg := ""
var _msg_t := 0.0
var _help := true
var _s := 1.0
var _panel: StyleBoxFlat
var _slot_box: StyleBoxFlat
var _net_line := ""
var _debug := false
var _tunables: Array = []
var _tunable_sel := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var regular := SystemFont.new()
	regular.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Arial", "sans-serif"])
	regular.font_weight = 500
	_font = regular
	var bold := SystemFont.new()
	bold.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Arial", "sans-serif"])
	bold.font_weight = 700
	_font_bold = bold
	_panel = StyleBoxFlat.new()
	_panel.bg_color = PANEL_BG
	_panel.border_color = PANEL_EDGE
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(6)
	_panel.shadow_color = Color(0, 0, 0, 0.45)
	_panel.shadow_size = 6
	_slot_box = StyleBoxFlat.new()
	_slot_box.bg_color = Color(0.12, 0.08, 0.1, 0.95)
	_slot_box.border_color = Color(0.45, 0.38, 0.32)
	_slot_box.set_border_width_all(2)
	_slot_box.set_corner_radius_all(5)


## Conecta o HUD ao kit do jogador local e às funções de projeção mundo ↔ tela.
func bind(kit: ClassKit, world: CombatWorld, world_to_screen: Callable, mouse_world: Callable) -> void:
	_kit = kit
	_world = world
	_to_screen = world_to_screen
	_mouse_world = mouse_world
	# Rebind acontece ao trocar de classe (C): o kit é novo, o mundo é o mesmo.
	if not kit.message.is_connected(show_message):
		kit.message.connect(show_message)
	if not world.local_message.is_connected(show_message):
		world.local_message.connect(show_message)


func show_message(text: String) -> void:
	_msg = text
	_msg_t = 1.8


## Linha de status da rede (ex.: "Hospedando na porta 7777 · IP 192.168.0.10").
func set_net_line(text: String) -> void:
	_net_line = text


func toggle_help() -> void:
	_help = not _help


## Liga/desliga o overlay de diagnóstico de game feel (F3).
func toggle_debug() -> bool:
	_debug = not _debug
	return _debug


## Parâmetros ajustáveis exibidos no overlay: [[nome, valor], ...] e o índice selecionado.
## Quem altera os valores é a raiz; o HUD só mostra.
func set_debug_tunables(rows: Array, selected: int) -> void:
	_tunables = rows
	_tunable_sel = selected


func _process(delta: float) -> void:
	_msg_t = maxf(0.0, _msg_t - delta)
	queue_redraw()


# ------------------------------------------------------------------ primitivas

func _px(v: float) -> float:
	return roundf(v * _s)


func _text(s: String, pos: Vector2, size_px: float, col: Color, bold := false, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := _font_bold if bold else _font
	var sz := int(size_px * _s)
	draw_string_outline(f, pos, s, align, width, sz, maxi(2, int(3 * _s)), Color(0.04, 0.02, 0.03, col.a * 0.9))
	draw_string(f, pos, s, align, width, sz, col)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.08)
	sb.border_color = Color(0.03, 0.02, 0.02)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	draw_style_box(sb, r)
	var w := (r.size.x - 2.0) * clampf(frac, 0.0, 1.0)
	if w > 0.5:
		var fill := Rect2(r.position + Vector2(1, 1), Vector2(w, r.size.y - 2.0))
		draw_rect(fill, col)
		draw_rect(Rect2(fill.position, Vector2(w, maxf(1.0, fill.size.y * 0.35))), col.lightened(0.25))


func _diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)


# ------------------------------------------------------------------ desenho

func _draw() -> void:
	_s = maxf(0.75, size.y / REF_HEIGHT)
	if _kit == null:
		return
	_draw_world_overlays()
	_draw_player_frame()
	_draw_party()
	_draw_hover()
	_draw_cast_bar()
	_draw_hotbar()
	if _msg_t > 0.0:
		_text(_msg, Vector2(0, size.y * 0.66), 18, Color(CREAM, minf(1.0, _msg_t * 2.0)), true, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if _help:
		_draw_help()
	if _net_line != "":
		_text(_net_line, Vector2(_px(12), size.y - _px(10)), 12, MUTED)
	if _debug:
		_draw_debug()


func _draw_debug() -> void:
	var me := _world.avatar_of(_world.local_peer())
	if me == null or not is_instance_valid(me):
		return
	# Vetores no mundo, a partir dos pés do jogador.
	var o: Vector2 = _to_screen.call(me.global_position)
	var vecs := [
		["movement", me.movement_direction, Color(0.35, 0.9, 0.45)],
		["facing", me.facing_vector, Color(0.4, 0.7, 1.0)],
		["aim", me.aim_direction, Color(1.0, 0.45, 0.35)],
	]
	for v: Array in vecs:
		var d: Vector2 = v[1]
		if d.length() > 0.01:
			draw_line(o, o + d.normalized() * _px(48), v[2], _px(2))
	var vel_frac := me.velocity.length() / maxf(1.0, me.move_speed)
	if me.velocity.length() > 1.0:
		draw_line(o, o + me.velocity.normalized() * _px(48) * minf(vel_frac, 3.0), Color(1.0, 0.85, 0.3), _px(3))

	var lines := [
		"DIAGNÓSTICO (F3)  ·  %d FPS" % Engine.get_frames_per_second(),
		"movement  (%.2f, %.2f)" % [me.movement_direction.x, me.movement_direction.y],
		"facing    (%.2f, %.2f)" % [me.facing_vector.x, me.facing_vector.y],
		"aim       (%.2f, %.2f)" % [me.aim_direction.x, me.aim_direction.y],
		"velocity  %.0f px/s  (%.0f%%)" % [me.velocity.length(), vel_frac * 100.0],
		"anim %s  ·  kit %s" % [me.anim_name(), _kit.state],
		"esquiva %s  ·  recarga %.2fs%s" % ["SIM" if me.is_dodging else "não", me.dodge_cooldown, "  ·  I-FRAMES" if me.is_invulnerable else ""],
		"",
		"F4 próximo parâmetro  ·  PgUp/PgDn ajustar",
	]
	var w := _px(300)
	var rows := lines.size() + _tunables.size()
	var r := Rect2(size.x - w - _px(12), size.y - _px(16) * rows - _px(130), w, _px(16) * rows + _px(14))
	draw_style_box(_panel, r)
	var y := r.position.y + _px(20)
	for i in lines.size():
		_text(lines[i], Vector2(r.position.x + _px(10), y), 11, GOLD if i == 0 else CREAM, i == 0)
		y += _px(16)
	for i in _tunables.size():
		var row: Array = _tunables[i]
		var sel := i == _tunable_sel
		_text("%s %s = %.3f" % ["▶" if sel else "  ", row[0], float(row[1])], Vector2(r.position.x + _px(10), y), 11, FIRE_Y if sel else MUTED, sel)
		y += _px(16)


func _draw_world_overlays() -> void:
	# Barras de vida e postura de inimigos feridos e plaquinhas dos jogadores.
	for e in _world.enemies:
		if not is_instance_valid(e) or not e.alive or (e.hp >= float(e.stats.max_hp) and e.poise >= e.max_poise):
			continue
		var head := Vector2(0, -50) if e.kind in ["training_dummy", "moss_guardian"] else Vector2(0, -34)
		var p: Vector2 = _to_screen.call(e.global_position + head)
		var w := _px(46)
		_bar(Rect2(p.x - w / 2.0, p.y, w, _px(6)), e.hp / float(e.stats.max_hp), DANGER if e.kind != "training_dummy" else HP_COL)
		_bar(Rect2(p.x - w / 2.0, p.y + _px(7), w, _px(3)), e.poise / maxf(1.0, e.max_poise), Color(0.95, 0.72, 0.2))
		if e.action_state == "stagger":
			_text("STAGGER", p + Vector2(-_px(30), -_px(14)), 10, Color(1.0, 0.9, 0.3), true, HORIZONTAL_ALIGNMENT_CENTER, _px(60))
	for peer: int in _world.players:
		var a: PlayerAvatar = _world.players[peer].avatar
		var k: ClassKit = _world.players[peer].kit
		if a == null or not is_instance_valid(a):
			continue
		var p: Vector2 = _to_screen.call(a.global_position + Vector2(0, -62))
		if peer != _world.local_peer():
			_text(a.display_name, p + Vector2(-_px(60), 0), 13, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER, _px(120))
			_bar(Rect2(p.x - _px(24), p.y + _px(4), _px(48), _px(5)), k.hp / float(k.stats.max_hp), Color(0.35, 0.8, 0.4))
	for n: Dictionary in _world.vfx.numbers:
		var k: float = float(n.t)
		var style: String = n.style
		var sz := 15.0
		if style in ["heavy", "ignite", "level"]:
			sz = 22.0
		elif style == "medium":
			sz = 18.0
		elif style == "burn":
			sz = 13.0
		if n.crit:
			sz *= 1.7 if k < 0.1 else 1.4
		var a := (1.0 - k) / 0.3 if k > 0.7 else 1.0
		var p: Vector2 = _to_screen.call(Vector2(n.pos) + Vector2(0, -k * 26.0))
		_text(String(n.text), p - Vector2(_px(80), 0), sz, Color(NUMBER_COLORS.get(style, CREAM), a), true, HORIZONTAL_ALIGNMENT_CENTER, _px(160))


func _draw_player_frame() -> void:
	var s := _kit.stats
	var r := Rect2(_px(12), _px(12), _px(270), _px(96 if _kit.has_level_track() else 82))
	draw_style_box(_panel, r)
	var x := r.position.x + _px(12)
	var me := _world.avatar_of(_world.local_peer())
	_text("%s" % (me.display_name if me else ""), Vector2(x, r.position.y + _px(22)), 16, CREAM, true)
	_text(_kit.display_class(), Vector2(x + _px(130), r.position.y + _px(22)), 13, GOLD, false, HORIZONTAL_ALIGNMENT_RIGHT, _px(116))
	var bw := r.size.x - _px(24)
	var y := r.position.y + _px(32)
	_bar(Rect2(x, y, bw, _px(14)), _kit.hp / float(s.max_hp), HP_COL)
	_text("%d / %d" % [ceili(_kit.hp), int(s.max_hp)], Vector2(x, y + _px(12)), 11, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER, bw)
	y += _px(19)
	_bar(Rect2(x, y, bw, _px(11)), _kit.res / float(s.max_resource), _kit.resource_color())
	_text("%s %d" % [_kit.resource_name(), int(_kit.res)], Vector2(x, y + _px(10)), 10, CREAM, false, HORIZONTAL_ALIGNMENT_CENTER, bw)
	y += _px(16)
	if _kit.has_level_track():
		var frac := _kit.level_points / maxf(1.0, _kit.level_next)
		_text("%s %d" % [_kit.level_short(), _kit.level], Vector2(x, y + _px(10)), 12, Color(0.75, 0.9, 1.0), true)
		_bar(Rect2(x + _px(52), y + _px(2), bw - _px(52), _px(7)), frac, Color(0.55, 0.75, 1.0))
		y += _px(15)
	var dr := "  ·  Defesa +%d%%" % roundi(_kit.damage_reduction * 100.0) if _kit.damage_reduction > 0.0 else ""
	var power := int(s.spell_power) if String(_kit.def.resource_type) == "mana" else int(s.attack_power)
	_text("Poder %d  ·  Armadura %d%s" % [power, int(s.armor), dr], Vector2(x, y + _px(10)), 11, MUTED)


func _draw_party() -> void:
	var y := _px(118 if _kit.has_level_track() else 104)
	for peer: int in _world.players:
		if peer == _world.local_peer():
			continue
		var a: PlayerAvatar = _world.players[peer].avatar
		var k: ClassKit = _world.players[peer].kit
		var r := Rect2(_px(12), y, _px(200), _px(40))
		draw_style_box(_panel, r)
		_text("%s · %s" % [a.display_name, k.display_class()], r.position + Vector2(_px(10), _px(16)), 12, CREAM, true)
		_bar(Rect2(r.position.x + _px(10), r.position.y + _px(22), r.size.x - _px(20), _px(9)), k.hp / float(k.stats.max_hp), Color(0.35, 0.8, 0.4))
		y += _px(46)


func _draw_hover() -> void:
	var e := _world.enemy_near(_mouse_world.call(), 22.0)
	if e == null:
		return
	var r := Rect2(size.x / 2.0 - _px(130), _px(12), _px(260), _px(68))
	draw_style_box(_panel, r)
	var hostile := e.kind != "training_dummy"
	_diamond(r.position + Vector2(_px(16), _px(18)), _px(6), DANGER if hostile else GOLD)
	_text(e.display_name, r.position + Vector2(_px(28), _px(23)), 15, CREAM, true)
	_bar(Rect2(r.position.x + _px(12), r.position.y + _px(30), r.size.x - _px(24), _px(9)), e.hp / float(e.stats.max_hp), DANGER if hostile else HP_COL)
	_bar(Rect2(r.position.x + _px(12), r.position.y + _px(41), r.size.x - _px(24), _px(4)), e.poise / maxf(1.0, e.max_poise), Color(0.95, 0.72, 0.2))

	var ig: Dictionary = _world.passives.get("ignite", {})
	var ready := e.burn_stacks >= int(ig.get("threshold", 3))
	for i in int(_world.burn_rules.get("max_stacks", 5)):
		var col := Color(0.25, 0.2, 0.22)
		if i < e.burn_stacks:
			col = FIRE_Y if ready else FIRE
		draw_rect(Rect2(r.position.x + _px(12) + i * _px(16), r.position.y + _px(50), _px(13), _px(6)), col)

	var status_text := ""
	var status_col := MUTED
	if e.action_state == "stagger":
		status_text = "POSTURA QUEBRADA"
		status_col = Color(1.0, 0.9, 0.3)
	elif e.action_state == "active" and String(e._action.get("type", "")) == "guard":
		status_text = "GUARDA FRONTAL"
		status_col = Color(0.4, 0.75, 1.0)
	elif ready:
		status_text = "IGNIÇÃO PRONTA"
		status_col = FIRE_Y
	elif e.burn_stacks > 0:
		status_text = "Queimadura ×%d" % e.burn_stacks
	_text(status_text, r.position + Vector2(_px(100), _px(58)), 11, status_col, status_col != MUTED)


func _draw_cast_bar() -> void:
	if _kit.state != "casting":
		return
	var ab: Dictionary = _kit.current.ability
	var w := _px(260)
	var r := Rect2(size.x / 2.0 - w / 2.0, size.y - _px(150), w, _px(14))
	_bar(r, _kit.cast_t / float(ab.cast_time), FIRE)
	_text("%s  %.1fs" % [ab.name, maxf(0.0, float(ab.cast_time) - _kit.cast_t)], Vector2(0, r.position.y - _px(5)), 14, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_hotbar() -> void:
	var ids := _kit.ability_ids
	var slot := _px(58)
	var gap := _px(26)
	var total := ids.size() * slot + (ids.size() - 1) * gap
	var x0 := (size.x - total) / 2.0
	var y0 := size.y - _px(102)

	var auto_text := "Ataque automático: %s · T" % ("ligado" if _kit.auto_attack else "desligado")
	if _kit.has_resolve:
		auto_text += "  ·  RESOLVE ATIVO (+35% Poise)"
	_text(auto_text, Vector2(0, y0 - _px(20)), 12, GOLD if (_kit.auto_attack or _kit.has_resolve) else MUTED, false, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	draw_style_box(_panel, Rect2(x0 - _px(14), y0 - _px(12), total + _px(28), slot + _px(48)))

	for i in ids.size():
		var id: String = ids[i]
		var ab := _kit.ability(id)
		var r := Rect2(x0 + i * (slot + gap), y0, slot, slot)
		draw_style_box(_slot_box, r)
		_draw_icon(id, r.get_center(), slot * 0.36)
		var cost := _kit.effective_cost(ab)
		if _kit.res + 0.01 < cost:
			draw_rect(r.grow(-2), Color(0.1, 0.2, 0.5, 0.45))
		var cd := float(_kit.cooldowns.get(id, 0.0))
		if cd > 0.0:
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(slot - 4, (slot - 4) * cd / float(ab.cooldown))), Color(0, 0, 0, 0.62))
			_text("%.0f" % ceilf(cd) if cd >= 1.0 else "%.1f" % cd, r.position + Vector2(0, slot * 0.62), 20, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER, slot)
		elif _kit.gcd > 0.0:
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(slot - 4, (slot - 4) * _kit.gcd / float(_world.rules.gcd))), Color(0, 0, 0, 0.32))
		if _kit.aiming == id:
			draw_rect(r.grow(_px(2)), FIRE_Y, false, _px(2))
		_text(str(int(ab.slot)), r.position + Vector2(_px(5), _px(15)), 13, GOLD, true)
		if cost > 0.0:
			_text(str(int(cost)), r.position + Vector2(0, slot - _px(5)), 12, _kit.resource_color().lightened(0.4), true, HORIZONTAL_ALIGNMENT_RIGHT, slot - _px(5))

		var label: String = String(ab.name)
		var label_col := MUTED
		if i == 0 and _kit.class_id == "warrior":
			var combo_names := ["Corte (1)", "Retorno (2)", "Quebra (3)"]
			label = combo_names[_kit.combo_step]
			label_col = GOLD if _kit.combo_step > 0 else MUTED
		elif i == 0 and _kit.class_id == "fire_mage" and _kit.spark_count > 0:
			label = "Fagulha ×%d" % (_kit.spark_count + 1)
			label_col = FIRE_Y
		_text(label, Vector2(r.position.x - gap, y0 + slot + _px(18)), 11, label_col, label_col != MUTED, HORIZONTAL_ALIGNMENT_CENTER, slot + gap * 2.0)


func _draw_icon(id: String, c: Vector2, r: float) -> void:
	# Ícones de skill em losango (art bible §3).
	_diamond(c, r * 1.15, Color(0.24, 0.12, 0.1))
	match id:
		"fire_spark":
			_diamond(c, r * 0.45, FIRE)
			draw_circle(c, r * 0.16, CREAM)
		"fireball":
			draw_circle(c, r * 0.62, Color(0.76, 0.21, 0.1))
			draw_circle(c + Vector2(-r * 0.1, -r * 0.1), r * 0.46, FIRE)
			draw_circle(c + Vector2(-r * 0.2, -r * 0.2), r * 0.22, FIRE_Y)
		"flame_pillar":
			draw_rect(Rect2(c.x - r * 0.3, c.y - r * 0.8, r * 0.6, r * 1.5), Color(0.76, 0.21, 0.1))
			draw_rect(Rect2(c.x - r * 0.17, c.y - r * 0.65, r * 0.34, r * 1.25), FIRE)
			draw_rect(Rect2(c.x - r * 0.06, c.y - r * 0.5, r * 0.12, r * 0.9), FIRE_Y)
		"fire_nova":
			draw_arc(c, r * 0.6, 0, TAU, 32, FIRE, r * 0.18)
			draw_arc(c, r * 0.6, 0, TAU, 32, CREAM, r * 0.06)
		"heavy_strike":
			draw_line(c + Vector2(-r * 0.55, r * 0.55), c + Vector2(r * 0.5, -r * 0.5), STEEL, r * 0.18)
			draw_line(c + Vector2(-r * 0.3, r * 0.1), c + Vector2(-r * 0.1, r * 0.3), GOLD, r * 0.14)
		"charge":
			for k in 3:
				var off := Vector2(-r * 0.45 + k * r * 0.32, 0)
				draw_colored_polygon(PackedVector2Array([c + off + Vector2(0, -r * 0.4), c + off + Vector2(r * 0.3, 0), c + off + Vector2(0, r * 0.4)]), Color(STEEL, 0.5 + k * 0.25))
		"war_cry":
			draw_arc(c, r * 0.35, 0, TAU, 24, GOLD, r * 0.1)
			draw_arc(c, r * 0.65, -0.9, 0.9, 16, GOLD, r * 0.08)
			draw_arc(c, r * 0.65, PI - 0.9, PI + 0.9, 16, GOLD, r * 0.08)
		"whirlwind":
			for k in 3:
				var a := float(k) * TAU / 3.0
				draw_arc(c, r * 0.55, a, a + 1.4, 12, STEEL, r * 0.12)


func _draw_help() -> void:
	var lines := [
		"WASD — andar", "1–4 — lançar no cursor, sem clicar",
		"Básico automático contra inimigos ao alcance", "T — ligar/desligar ataque automático",
		"E — invocar Slimes Despertos · R — reiniciar bonecos", "K — tremor de tela · F11 — tela cheia",
		"Espaço/Shift — esquiva · C — trocar personagem", "I — inventário", "F3 — diagnóstico", "H — esconder ajuda · F10 — sair",
	]
	var w := _px(330)
	var r := Rect2(size.x - w - _px(12), _px(12), w, _px(18) * lines.size() + _px(16))
	draw_style_box(_panel, r)
	for i in lines.size():
		_text(lines[i], r.position + Vector2(_px(12), _px(24) + i * _px(18)), 12, CREAM if i > 0 else GOLD, i == 0)
