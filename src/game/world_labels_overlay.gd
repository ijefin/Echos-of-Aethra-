extends Control
## Textos do mundo nítidos, estilo Tibia: negrito, colorido, contorno preto, desenhados
## na resolução NATIVA por cima da imagem pixelada. Os Label3D continuam existindo (o
## código de jogo mexe neles: texto, cor, visível, posição animada), mas ficam numa camada
## que a câmera não renderiza; aqui cada um é projetado da posição 3D para a tela.

const HIDDEN_LAYER := 1 << 19
const REF_HEIGHT := 720.0
const OUTLINE := 4

var demo: Node
var labels: Array[Label3D] = []
var _font: SystemFont
var _announce := ""
var _fade := 0.0
## Ação possível ("E — ...") desenhada sobre o objeto/pessoa.
var prompt_text := ""
var prompt_at := Vector3.INF
var _announce_sub := ""
var _announce_t := 0.0
const ANNOUNCE_TIME := 4.5
var _hp_re := RegEx.create_from_string("^(.+?)\\s+(\\d+)/(\\d+)$")


## Verde (cheio) → amarelo → vermelho (quase morto), cores de vida do Tibia.
static func _health_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color(0.25, 0.85, 0.25)
	if ratio > 0.3:
		return Color(0.95, 0.85, 0.2)
	return Color(0.95, 0.25, 0.2)


func setup(owner_demo: Node) -> void:
	demo = owner_demo
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Verdana", "Tahoma", "Segoe UI", "Arial", "sans-serif"])
	_font.font_weight = 700
	_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_font.hinting = TextServer.HINTING_NORMAL


## Passa a desenhar este Label3D aqui (e some com a versão pixelada dele).
func adopt(label: Label3D) -> void:
	label.layers = HIDDEN_LAYER
	labels.append(label)


## Mensagem no centro da tela (subir de nível), como no Tibia; some sozinha.
func announce(text: String, sub := "") -> void:
	_announce = text
	_announce_sub = sub
	_announce_t = ANNOUNCE_TIME


## Escurece e clareia rápido (troca de andar).
func fade_in() -> void:
	_fade = 1.0


func _process(delta: float) -> void:
	_announce_t = maxf(0.0, _announce_t - delta)
	_fade = maxf(0.0, _fade - delta * 2.8)
	queue_redraw()


func _draw() -> void:
	var cam: Camera3D = demo._cam
	var ui := maxf(0.75, size.y / REF_HEIGHT)
	if _fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, _fade))
	if _announce_t > 0.0:
		var a := clampf(_announce_t / 1.0, 0.0, 1.0)
		var big := roundi(20 * ui)
		var w := _font.get_string_size(_announce, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
		var pos := Vector2(roundf(size.x * 0.5 - w * 0.5), roundf(size.y * 0.36))
		draw_string_outline(_font, pos, _announce, HORIZONTAL_ALIGNMENT_LEFT, -1, big, OUTLINE, Color(0, 0, 0, a))
		draw_string(_font, pos, _announce, HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(1, 1, 1, a))
		if not _announce_sub.is_empty():
			var small := roundi(14 * ui)
			var ws := _font.get_string_size(_announce_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
			var ps := Vector2(roundf(size.x * 0.5 - ws * 0.5), pos.y + roundf(26 * ui))
			draw_string_outline(_font, ps, _announce_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, small, OUTLINE, Color(0, 0, 0, a))
			draw_string(_font, ps, _announce_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(1.0, 0.85, 0.4, a))
	if not prompt_text.is_empty() and prompt_at != Vector3.INF and not cam.is_position_behind(prompt_at):
		var pp: Vector2 = cam.unproject_position(prompt_at) * float(demo._scale) + demo._view.position
		# quadradinho cinza com a tecla + a ação ao lado ("E — abrir" -> [E] abrir)
		var parts := prompt_text.split(" — ", true, 1)
		var key := parts[0]
		var action := parts[1] if parts.size() > 1 else ""
		var kpx := roundi(15 * ui)
		var apx := roundi(14 * ui)
		var box := roundf(24 * ui)
		var aw := _font.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, apx).x
		var total := box + roundf(6 * ui) + aw
		var kr := Rect2(roundf(pp.x - total * 0.5), roundf(pp.y - box), box, box)
		draw_rect(kr.grow(1.0), Color(0, 0, 0, 0.9))
		draw_rect(kr, Color(0.36, 0.36, 0.38, 0.95))
		draw_rect(Rect2(kr.position, Vector2(kr.size.x, roundf(2 * ui))), Color(0.6, 0.6, 0.62))
		var kw := _font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, kpx).x
		var kpos := Vector2(roundf(kr.get_center().x - kw * 0.5), roundf(kr.get_center().y + kpx * 0.36))
		draw_string(_font, kpos, key, HORIZONTAL_ALIGNMENT_LEFT, -1, kpx, Color(1, 1, 1))
		if not action.is_empty():
			var apos := Vector2(kr.end.x + roundf(6 * ui), roundf(kr.get_center().y + apx * 0.36))
			draw_string_outline(_font, apos, action, HORIZONTAL_ALIGNMENT_LEFT, -1, apx, OUTLINE, Color(0, 0, 0))
			draw_string(_font, apos, action, HORIZONTAL_ALIGNMENT_LEFT, -1, apx, Color(0.95, 0.92, 0.84))
	for i in range(labels.size() - 1, -1, -1):
		var l := labels[i]
		if not is_instance_valid(l):
			labels.remove_at(i)
			continue
		if not l.is_visible_in_tree() or l.modulate.a <= 0.01 or l.text.is_empty():
			continue
		var world := l.global_position
		if cam.is_position_behind(world):
			continue
		var at: Vector2 = cam.unproject_position(world) * float(demo._scale) + demo._view.position
		# tamanho de Tibia: nomes ~12 px, avisos grandes ~16 px (em 720p), escala com a tela
		var px := roundi(clampf(l.font_size * 0.4, 12.0, 22.0) * ui)
		var lines := l.text.split("\n")
		var line_h := _font.get_height(px)
		var y := at.y - line_h * (lines.size() - 1)
		var color := l.modulate
		var shadow := Color(0, 0, 0, color.a)
		# monstro ("Nome  16/16"): nome na cor da vida + barrinha, como no Tibia
		var hp := _hp_re.search(l.text) if lines.size() == 1 else null
		if hp != null:
			var ratio := clampf(float(hp.get_string(2)) / maxf(1.0, float(hp.get_string(3))), 0.0, 1.0)
			var hcol := _health_color(ratio)
			hcol.a = color.a
			var name := hp.get_string(1)
			var nw := _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var npos := Vector2(roundf(at.x - nw * 0.5), roundf(at.y))
			draw_string_outline(_font, npos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, px, OUTLINE, shadow)
			draw_string(_font, npos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, px, hcol)
			var bw := roundf(28.0 * ui)
			var bar := Rect2(roundf(at.x - bw * 0.5), npos.y + roundf(3.0 * ui), bw, roundf(4.0 * ui))
			draw_rect(bar.grow(1.0), shadow)
			draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * ratio), bar.size.y)), hcol)
			continue
		for line in lines:
			var w := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var pos := Vector2(roundf(at.x - w * 0.5), roundf(y))
			draw_string_outline(_font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, px, OUTLINE, shadow)
			draw_string(_font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
			y += line_h
