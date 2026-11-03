class_name RigShape
extends Node2D
## Peça visual de um osso do rig. Placeholder vetorial em HD (cápsula, elipse ou polígono
## com gradiente de luz de cima-esquerda e contorno colorido suave) até a peça pintada
## da IA existir; com `texture` definida, desenha a textura no lugar (Fase 2).
## As coordenadas são locais ao osso: +Y aponta ao longo do membro.
##
## Uso:
##   var s := RigShape.capsule(30.0, 7.0, 6.0, Color("b8323a"))
##   bone.add_child(s)

const LIGHT_DIR := Vector2(-0.6, -0.8)

var points := PackedVector2Array()
var base_color := Color.WHITE
var outline_width := 2.0
var shade := 0.35
var texture: Texture2D
var texture_offset := Vector2.ZERO
## Brilho extra (gemas, fogo): cor somada no centro, sem contorno.
var glow := false


## Cápsula ao longo de +Y, de 0 até `length`, raio r0 no topo e r1 na ponta.
static func capsule(length: float, r0: float, r1: float, color: Color, offset := Vector2.ZERO) -> RigShape:
	var s := RigShape.new()
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var a := PI + PI * float(i) / steps
		pts.append(offset + Vector2(cos(a) * r0, sin(a) * r0))
	for i in steps + 1:
		var a := PI * float(i) / steps
		pts.append(offset + Vector2(cos(a) * r1, length + sin(a) * r1))
	s.points = _reverse_bottom(pts, steps)
	s.base_color = color
	return s


## Elipse centrada em `center`.
static func ellipse(center: Vector2, rx: float, ry: float, color: Color) -> RigShape:
	var s := RigShape.new()
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	s.points = pts
	s.base_color = color
	return s


## Polígono livre.
static func poly(pts: PackedVector2Array, color: Color) -> RigShape:
	var s := RigShape.new()
	s.points = pts
	s.base_color = color
	return s


static func _reverse_bottom(pts: PackedVector2Array, steps: int) -> PackedVector2Array:
	# Ordem do contorno: arco de cima da esquerda para a direita, depois o de baixo da
	# direita para a esquerda, para o polígono não se cruzar.
	var top := pts.slice(0, steps + 1)
	var bottom := pts.slice(steps + 1)
	var out := PackedVector2Array()
	out.append_array(top)
	for i in range(bottom.size()):
		out.append(bottom[i])
	return out


func _draw() -> void:
	if texture != null:
		draw_texture(texture, texture_offset)
		return
	if points.size() < 3:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	var size := (hi - lo).length()
	var center := (lo + hi) / 2.0
	var colors := PackedColorArray()
	for p in points:
		# Luz de cima-esquerda: realce quente, sombra puxando para azul/roxo (art bible §4).
		var t := ((p - center).dot(LIGHT_DIR) / maxf(1.0, size * 0.5))
		var c := base_color
		if t > 0.0:
			c = c.lerp(Color(1.0, 0.95, 0.8), t * shade * 0.8)
		else:
			c = c.lerp(Color(0.18, 0.12, 0.3), -t * shade)
		colors.append(c)
	draw_polygon(points, colors)
	if glow:
		return
	var outline := Color.from_hsv(fposmod(base_color.h - 0.04, 1.0), minf(1.0, base_color.s + 0.25), base_color.v * 0.35)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, outline, outline_width, true)
