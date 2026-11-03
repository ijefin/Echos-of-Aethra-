class_name CombatVfx
extends Node2D
## Desenha os efeitos de combate em pixel art, em 3 camadas do mundo:
##   chão (z -3): telegraphs, chão queimado, mira (alcance + área)
##   corpo (z 4): explosões, pilares, anéis, cortes, fumaça, corpo dos projéteis
##   brilho (z 5, aditivo, cores HDR > 1 que acendem o glow): brasas, núcleos, flashes
## Os números de dano ficam em `numbers` e são desenhados pelo HUD em resolução nativa.
## Projéteis e telegraphs são simulados localmente a partir dos eventos do servidor.
## Placeholder procedural: os sprites dos ASSET-002..007 substituem estas formas depois.
##
## Uso: vfx.add_effect("explosion", pos, 0.45, {"r": 56.0})

class DrawLayer extends Node2D:
	var painter: Callable

	func _draw() -> void:
		painter.call(self)


const FIRE_W := Color(1.5, 1.4, 1.05)
const FIRE_Y := Color(1.25, 0.98, 0.38)
const FIRE_O := Color(1.0, 0.48, 0.1)
const FIRE_R := Color(0.76, 0.21, 0.1)
const SMOKE_D := Color(0.23, 0.18, 0.2)
const SMOKE_L := Color(0.42, 0.35, 0.37)
const SCORCH := Color(0.1, 0.06, 0.08)
const STEEL := Color(1.3, 1.35, 1.45)
const GOLD := Color(1.3, 1.0, 0.45)
const DUST := Color(0.62, 0.52, 0.38)
const MAX_PARTICLES := 400

var y_squash := 0.75
var scorch_seconds := 3.0
## Números flutuantes: {pos, text, style, crit, t}. Desenhados pelo HUD.
var numbers: Array[Dictionary] = []
## Mira do jogador local: {origin, range, point, radius, cone} ou vazio.
var aim: Dictionary = {}

var _projectiles: Array[Dictionary] = []
var _telegraphs: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _scorches: Array[Dictionary] = []
var _layers: Array[DrawLayer] = []


func _ready() -> void:
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var specs := [[-3, _paint_ground, null], [4, _paint_body, null], [5, _paint_glow, add_mat]]
	for s: Array in specs:
		var layer := DrawLayer.new()
		layer.z_index = s[0]
		layer.painter = s[1]
		if s[2] != null:
			layer.material = s[2]
		add_child(layer)
		_layers.append(layer)


## Efeito temporário. `type`: explosion, pillar, nova, spark, cast_flash, shout, slash,
## dash, impact, whirl.
func add_effect(type: String, pos: Vector2, duration: float, extra: Dictionary = {}) -> void:
	var fx := {"type": type, "pos": pos, "t": 0.0, "dur": duration}
	fx.merge(extra)
	_effects.append(fx)


func add_projectile(id: int, pos: Vector2, dir: Vector2, speed: float, left: float, big: bool) -> void:
	_projectiles.append({"id": id, "pos": pos, "dir": dir, "speed": speed, "left": left, "big": big})


func remove_projectile(id: int) -> void:
	for i in range(_projectiles.size() - 1, -1, -1):
		if int(_projectiles[i].id) == id:
			_projectiles.remove_at(i)


func add_telegraph(pos: Vector2, r: float, dur: float) -> void:
	_telegraphs.append({"pos": pos, "r": r, "t": 0.0, "dur": dur})


## Mancha de chão queimado que some em scorch_seconds.
func add_scorch(pos: Vector2) -> void:
	_scorches.append({"pos": pos, "t": 0.0})
	if _scorches.size() > 24:
		_scorches.pop_front()


## Brasas que saltam e sobem.
func emit_embers(pos: Vector2, count: int, speed: float) -> void:
	for i in count:
		if _particles.size() >= MAX_PARTICLES:
			return
		var dir := Vector2.from_angle(randf() * TAU)
		var s := speed * randf_range(0.3, 1.0)
		_particles.append({"kind": "ember", "pos": pos, "vel": Vector2(dir.x * s, dir.y * s * 0.75 - 20.0),
			"life": 0.0, "max": randf_range(0.35, 0.8), "size": 2.0 if randf() < 0.3 else 1.0})


## Fumaça que sobe e se espalha.
func emit_smoke(pos: Vector2, count: int) -> void:
	for i in count:
		if _particles.size() >= MAX_PARTICLES:
			return
		_particles.append({"kind": "smoke", "pos": pos + Vector2(randf_range(-8, 8), randf_range(-4, 4)),
			"vel": Vector2(randf_range(-10, 10), randf_range(-26, -12)), "life": 0.0, "max": randf_range(0.6, 1.1), "size": 3.0})


## Número flutuante. `style`: light/medium/heavy/burn/ignite/player/level.
func add_number(pos: Vector2, text: String, style: String, crit: bool) -> void:
	numbers.append({"pos": pos + Vector2(randf_range(-6, 6), 0), "text": text, "style": style, "crit": crit, "t": 0.0})


func _process(delta: float) -> void:
	for i in range(_effects.size() - 1, -1, -1):
		var fx: Dictionary = _effects[i]
		fx.t = float(fx.t) + delta
		if fx.has("node"):
			var n: Node2D = fx.node
			if is_instance_valid(n):
				fx.pos = n.global_position
		if float(fx.t) >= float(fx.dur):
			_effects.remove_at(i)
	for i in range(_telegraphs.size() - 1, -1, -1):
		_telegraphs[i].t = float(_telegraphs[i].t) + delta
		if float(_telegraphs[i].t) >= float(_telegraphs[i].dur):
			_telegraphs.remove_at(i)
	for i in range(_projectiles.size() - 1, -1, -1):
		var p: Dictionary = _projectiles[i]
		var step := float(p.speed) * delta
		p.pos = Vector2(p.pos) + Vector2(p.dir) * step
		p.left = float(p.left) - step
		emit_embers(p.pos, 1, 15.0 if p.big else 4.0)
		if p.big and randf() < 0.4:
			emit_smoke(p.pos, 1)
		if float(p.left) < -40.0:  # o servidor não respondeu: some sozinho
			_projectiles.remove_at(i)
	for i in range(_scorches.size() - 1, -1, -1):
		_scorches[i].t = float(_scorches[i].t) + delta
		if float(_scorches[i].t) >= scorch_seconds:
			_scorches.remove_at(i)
	for i in range(numbers.size() - 1, -1, -1):
		numbers[i].t = float(numbers[i].t) + delta
		if float(numbers[i].t) >= 1.0:
			numbers.remove_at(i)
	var drag := pow(0.9, delta * 60.0)
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p.life = float(p.life) + delta
		if float(p.life) >= float(p.max):
			_particles.remove_at(i)
			continue
		p.pos = Vector2(p.pos) + Vector2(p.vel) * delta
		p.vel = Vector2(p.vel.x * drag, p.vel.y * drag - (25.0 if p.kind == "ember" else 6.0) * delta)
	for layer in _layers:
		layer.queue_redraw()


# ------------------------------------------------------------------ primitivas de pixel

static func px_ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx < 0.5 or ry < 0.5:
		return
	var rows := roundi(ry)
	var cx := roundf(c.x)
	var cy := roundf(c.y)
	for dy in range(-rows, rows + 1):
		var w := roundi(rx * sqrt(maxf(0.0, 1.0 - float(dy * dy) / (ry * ry))))
		if w > 0:
			ci.draw_rect(Rect2(cx - w, cy + dy, w * 2, 1), col)


static func px_ring(ci: CanvasItem, c: Vector2, rx: float, ry: float, thick: float, col: Color) -> void:
	var irx := rx - thick
	var iry := ry - thick
	var rows := roundi(ry)
	var cx := roundf(c.x)
	var cy := roundf(c.y)
	for dy in range(-rows, rows + 1):
		var wo := roundi(rx * sqrt(maxf(0.0, 1.0 - float(dy * dy) / (ry * ry))))
		var wi := 0
		if iry > 0.0 and absf(dy) < iry:
			wi = roundi(irx * sqrt(1.0 - float(dy * dy) / (iry * iry)))
		if wi <= 0:
			ci.draw_rect(Rect2(cx - wo, cy + dy, wo * 2, 1), col)
		else:
			ci.draw_rect(Rect2(cx - wo, cy + dy, wo - wi, 1), col)
			ci.draw_rect(Rect2(cx + wi, cy + dy, wo - wi, 1), col)


## Arco pontilhado em pixels (cone do golpe corpo a corpo, borda de alcance).
static func px_arc(ci: CanvasItem, c: Vector2, r: float, ry_scale: float, from_a: float, to_a: float, col: Color, step_px := 2.0) -> void:
	var steps := maxi(4, int(absf(to_a - from_a) * r / step_px))
	for i in steps + 1:
		var a := lerpf(from_a, to_a, float(i) / float(steps))
		ci.draw_rect(Rect2(roundf(c.x + cos(a) * r), roundf(c.y + sin(a) * r * ry_scale), 1, 1), col)


# ------------------------------------------------------------------ pintores das camadas

func _paint_ground(ci: CanvasItem) -> void:
	if not aim.is_empty():
		var o: Vector2 = aim.origin
		var rng_px: float = aim.range
		if rng_px > 0.0:
			px_arc(ci, o, rng_px, y_squash, 0.0, TAU, Color(1.0, 0.95, 0.75, 0.45), 4.0)
		var p: Vector2 = aim.point
		var r: float = aim.radius
		if aim.get("cone", 0.0) > 0.0:
			var dir: Vector2 = (p - o).normalized()
			var half := deg_to_rad(float(aim.cone)) / 2.0
			for k in 3:
				px_arc(ci, o, r - k * 3.0, y_squash, dir.angle() - half, dir.angle() + half, Color(1.0, 0.9, 0.6, 0.6))
		elif r > 0.0:
			px_ellipse(ci, p, r, r * y_squash, Color(1.0, 0.6, 0.2, 0.18))
			px_ring(ci, p, r, r * y_squash, 1.0, Color(1.0, 0.85, 0.4, 0.8))
		else:
			px_ring(ci, p, 5, 3, 1.0, Color(1.0, 0.9, 0.6, 0.9))
	for s in _scorches:
		var a: float = 0.7 * (1.0 - float(s.t) / scorch_seconds)
		var p: Vector2 = s.pos
		px_ellipse(ci, p, 24, 10, Color(SCORCH, a))
		px_ellipse(ci, p + Vector2(-3, -1), 15, 6, Color(SCORCH.darkened(0.3), a))
	for tg in _telegraphs:
		var k := clampf(float(tg.t) / float(tg.dur), 0.0, 1.0)
		var r: float = tg.r
		var pulse := 0.5 + 0.5 * sin(float(tg.t) * 30.0)
		var p: Vector2 = tg.pos
		px_ellipse(ci, p, r * k, r * k * y_squash, Color(FIRE_O, 0.22 + 0.15 * pulse))
		px_ring(ci, p, r, r * y_squash, 2.0, Color(1.0, 0.84, 0.36, 0.9) if pulse > 0.5 else Color(FIRE_O, 0.9))
		for i in 8:
			var a: float = float(i) / 8.0 * TAU + float(tg.t) * 2.0
			ci.draw_rect(Rect2(p.x + cos(a) * (r - 6.0), p.y + sin(a) * (r - 6.0) * y_squash, 2, 2), Color(1.0, 0.84, 0.36))


func _paint_body(ci: CanvasItem) -> void:
	for fx in _effects:
		var k: float = float(fx.t) / float(fx.dur)
		var p: Vector2 = fx.pos
		match String(fx.type):
			"explosion":
				var r: float = fx.r
				if k >= 0.12:
					var g := minf(1.0, (k - 0.12) / 0.3)
					var rr := r * (0.55 + 0.45 * g) + randf() * 2.0
					if k < 0.7:
						px_ellipse(ci, p + Vector2(0, -6), rr, rr * y_squash, FIRE_R)
						px_ellipse(ci, p + Vector2(0, -8), rr * 0.8, rr * 0.6, FIRE_O)
					var sr := r * (0.6 + 0.6 * k)
					px_ring(ci, p + Vector2(0, -4), sr, sr * y_squash, 4.0, Color(SMOKE_D, 1.0 - k))
			"pillar":
				_paint_pillar(ci, fx, k, false)
			"nova":
				var r := 8.0 + (float(fx.r) - 8.0) * (1.0 - (1.0 - k) * (1.0 - k))
				px_ring(ci, p + Vector2(0, -4), r, r * y_squash, 10.0 * (1.0 - k * 0.5), Color(FIRE_O, 1.0 - k * k))
			"impact":
				var r := float(fx.r) * (0.4 + 0.8 * k)
				px_ring(ci, p, r, r * y_squash, 4.0, Color(DUST, 1.0 - k))
			"dash":
				var to: Vector2 = fx.to
				for j in 8:
					var q := p.lerp(to, float(j) / 8.0)
					px_ellipse(ci, q + Vector2(0, -2), 4.0 * (1.0 - k), 2.0 * (1.0 - k), Color(DUST, 0.7 * (1.0 - k)))
	for pr in _projectiles:
		var c: Vector2 = pr.pos
		if pr.big:
			px_ellipse(ci, c, 6, 6, FIRE_R)
			px_ellipse(ci, c, 5, 5, FIRE_O)
		else:
			px_ellipse(ci, c, 3, 3, FIRE_O)
	for pa in _particles:
		if pa.kind != "smoke":
			continue
		var r: float = float(pa.life) / float(pa.max)
		var s: float = float(pa.size) + r * 4.0
		ci.draw_rect(Rect2(pa.pos.x - s / 2.0, pa.pos.y - s / 2.0, s, s), Color(SMOKE_D if r < 0.4 else SMOKE_L, 0.45 * (1.0 - r)))


func _paint_glow(ci: CanvasItem) -> void:
	for fx in _effects:
		var k: float = float(fx.t) / float(fx.dur)
		var p: Vector2 = fx.pos
		match String(fx.type):
			"explosion":
				if k < 0.12:
					px_ellipse(ci, p + Vector2(0, -8), fx.r * 0.5, fx.r * 0.4, FIRE_W)
				elif k < 0.7:
					var rr: float = fx.r * 0.5 * (1.0 - k)
					px_ellipse(ci, p + Vector2(0, -10), rr, rr * 0.8, FIRE_Y)
			"pillar":
				_paint_pillar(ci, fx, k, true)
			"nova":
				var r := 8.0 + (float(fx.r) - 8.0) * (1.0 - (1.0 - k) * (1.0 - k))
				px_ring(ci, p + Vector2(0, -4), r, r * y_squash, maxf(2.0, 4.0 * (1.0 - k)), Color(FIRE_W, 1.0 - k * k))
			"spark", "cast_flash":
				var r := 2.0 + k * 7.0
				var col := Color(FIRE_W, 1.0 - k)
				ci.draw_rect(Rect2(p.x - r, p.y, r * 2.0, 1), col)
				ci.draw_rect(Rect2(p.x, p.y - r, 1, r * 2.0), col)
				px_ellipse(ci, p, 3.0 * (1.0 - k) + 1.0, 3.0 * (1.0 - k) + 1.0, Color(FIRE_Y, 1.0 - k))
			"slash":
				var dir: Vector2 = fx.dir
				var half := deg_to_rad(float(fx.arc)) / 2.0
				var sweep := lerpf(-half, half, minf(1.0, k * 1.6))
				var r: float = fx.r
				for j in 3:
					px_arc(ci, p + Vector2(0, -14), r - j * 4.0, y_squash, dir.angle() - half, dir.angle() + sweep,
						Color(STEEL, (1.0 - k) * (1.0 - j * 0.3)), 1.0)
			"shout":
				var r := float(fx.r) * (0.2 + 0.8 * (1.0 - (1.0 - k) * (1.0 - k)))
				px_ring(ci, p, r, r * y_squash, 2.0, Color(GOLD, 1.0 - k))
				px_ring(ci, p, r * 0.7, r * 0.7 * y_squash, 1.0, Color(GOLD, (1.0 - k) * 0.6))
			"whirl":
				var r: float = fx.r
				var spin := float(fx.t) * 22.0
				for j in 3:
					var a := spin + float(j) * TAU / 3.0
					px_arc(ci, p + Vector2(0, -10), r * 0.8, y_squash, a, a + 1.4, Color(STEEL, 0.9 - k * 0.5), 1.0)
	for pr in _projectiles:
		var c: Vector2 = pr.pos
		if pr.big:
			px_ellipse(ci, c + Vector2(-1, -1), 3.0 + randf(), 3.0 + randf(), FIRE_Y)
			ci.draw_rect(Rect2(c.x - 1, c.y - 2, 2, 2), FIRE_W)
		else:
			ci.draw_rect(Rect2(c.x - 1, c.y - 1, 2, 2), FIRE_W)
	for pa in _particles:
		if pa.kind != "ember":
			continue
		var r: float = float(pa.life) / float(pa.max)
		var col := FIRE_W if r < 0.3 else (FIRE_Y if r < 0.6 else (FIRE_O if r < 0.85 else FIRE_R))
		ci.draw_rect(Rect2(roundf(pa.pos.x), roundf(pa.pos.y), pa.size, pa.size), col)


func _paint_pillar(ci: CanvasItem, fx: Dictionary, k: float, glow: bool) -> void:
	var small: bool = fx.get("small", false)
	var max_h := 60.0 if small else 110.0
	var width := 16.0 if small else 30.0
	var h := max_h * (k / 0.3 if k < 0.3 else (1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4))
	var p: Vector2 = fx.pos
	if glow and k < 0.2 and not small:
		px_ellipse(ci, p, 34, 34 * y_squash, Color(FIRE_Y, 0.3))
	var j := 0.0
	while j < h:
		var taper := 1.0 - (j / max_h) * 0.6
		var jit := sin(j * 0.35 + float(fx.t) * 50.0) * 3.0
		var w := width * taper * (1.0 - k * 0.4)
		if glow:
			ci.draw_rect(Rect2(p.x - w * 0.2 + jit, p.y - j, w * 0.4, 2), FIRE_Y)
			if k < 0.5:
				ci.draw_rect(Rect2(p.x - w * 0.08 + jit, p.y - j, maxf(1.0, w * 0.16), 2), FIRE_W)
		else:
			ci.draw_rect(Rect2(p.x - w / 2.0 + jit, p.y - j, w, 2), FIRE_R)
			ci.draw_rect(Rect2(p.x - w * 0.35 + jit, p.y - j, w * 0.7, 2), FIRE_O)
		j += 2.0
