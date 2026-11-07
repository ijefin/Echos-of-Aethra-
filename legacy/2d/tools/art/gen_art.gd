## Gera a arte placeholder da Clareira de Treino, em modo headless:
##   godot --headless --path . -s res://legacy/2d/tools/art/gen_art.gd
## Escreve PNGs em res://legacy/2d/assets/art/ e o layout do mapa em res://legacy/2d/assets/data/clearing_layout.json.
## Nomes e tamanhos seguem design/assets/specs/*.md: a arte final (IA ou artista) substitui
## estes PNGs sem mudar código.
##
## Regras de arte aplicadas (o que tira o visual "chapado"):
## - rampas de cor com variação de matiz (sombra puxa para azul/roxo, luz para amarelo);
## - volume esférico com luz vindo do canto superior esquerdo;
## - aglomerados de folhas por ruído, não cor chapada;
## - contorno colorido (tom escuro da própria cor) só na silhueta externa.
extends SceneTree

const ART := "res://legacy/2d/assets/art/"
const LAYOUT_PATH := "res://legacy/2d/assets/data/clearing_layout.json"
const WORLD := Vector2i(1600, 1200)
const CLEARING := Vector2(800, 560)
const N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const FIRE: Array[Color] = [Color("c2361a"), Color("ff7a1a"), Color("ffd65c"), Color("fff4c2")]

var light_dir := Vector3(-0.55, -0.65, 0.53).normalized()
var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()

var ramp_leaf: Array[Color]
var ramp_birch_leaf: Array[Color]
var ramp_pine: Array[Color]
var ramp_bark: Array[Color]
var ramp_birch_bark: Array[Color]
var ramp_grass: Array[Color]
var ramp_dirt: Array[Color]
var ramp_stone: Array[Color]
var ramp_moss: Array[Color]
var ramp_robe: Array[Color]
var ramp_gold: Array[Color]
var ramp_fur: Array[Color]
var ramp_squirrel: Array[Color]
var ramp_fg: Array[Color]
var ramp_cap_blue: Array[Color]
var ramp_violet: Array[Color]
var ramp_awakened: Array[Color]
var ramp_straw: Array[Color]
var ramp_steel: Array[Color]
var ramp_tabard: Array[Color]
var ramp_linen: Array[Color]
var ramp_leather: Array[Color]
var ramp_bronze: Array[Color]
var ramp_armor: Array[Color]
var ramp_cap_brown: Array[Color]


func _init() -> void:
	rng.seed = 2026
	noise.seed = 7
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.08
	_build_ramps()
	for d in ["env", "fx", "critters", "chars", "enemies"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ART + d))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/data"))
	var t0 := Time.get_ticks_msec()
	var variants := _gen_trees()
	_gen_undergrowth()
	_gen_rocks_and_wood()
	_gen_foreground()
	_gen_critters()
	_gen_enemies()
	_gen_fx()
	_gen_mage_sheet()
	_gen_warrior_sheet()
	_gen_paperdoll()
	var layout := _gen_layout()
	layout["tree_variants"] = variants
	_gen_ground(layout)
	_save_json(layout)
	print("gen_art: OK em %d ms" % (Time.get_ticks_msec() - t0))
	quit()


# ------------------------------------------------------------------ cores

func _ramp(n: int, shadow_hue: float, light_hue: float, sat: float, val_lo: float, val_hi: float) -> Array[Color]:
	var out: Array[Color] = []
	# Interpola o matiz pelo caminho curto do círculo (0.98 → 0.09 passa pelo vermelho,
	# não pelo azul).
	if light_hue - shadow_hue > 0.5:
		light_hue -= 1.0
	elif shadow_hue - light_hue > 0.5:
		light_hue += 1.0
	for i in n:
		var t := float(i) / float(n - 1)
		out.append(Color.from_hsv(fposmod(lerpf(shadow_hue, light_hue, t), 1.0),
			clampf(lerpf(sat + 0.1, sat - 0.12, t), 0.0, 1.0), lerpf(val_lo, val_hi, t)))
	return out


func _build_ramps() -> void:
	ramp_leaf = _ramp(6, 0.47, 0.21, 0.62, 0.16, 0.80)
	ramp_birch_leaf = _ramp(6, 0.40, 0.16, 0.62, 0.24, 0.90)
	ramp_pine = _ramp(5, 0.50, 0.34, 0.55, 0.13, 0.60)
	ramp_bark = _ramp(5, 0.96, 0.08, 0.42, 0.15, 0.58)
	ramp_birch_bark = _ramp(4, 0.62, 0.12, 0.10, 0.50, 0.94)
	ramp_grass = _ramp(5, 0.42, 0.21, 0.46, 0.30, 0.60)
	ramp_dirt = _ramp(5, 0.98, 0.09, 0.45, 0.30, 0.68)
	ramp_stone = _ramp(5, 0.66, 0.11, 0.14, 0.26, 0.82)
	ramp_moss = _ramp(4, 0.40, 0.22, 0.55, 0.28, 0.66)
	ramp_robe = _ramp(6, 0.92, 1.03, 0.72, 0.20, 0.95)
	ramp_gold = _ramp(4, 0.03, 0.14, 0.70, 0.40, 1.0)
	ramp_fur = _ramp(5, 0.95, 0.10, 0.30, 0.28, 0.85)
	ramp_squirrel = _ramp(5, 0.98, 0.07, 0.68, 0.25, 0.88)
	ramp_fg = _ramp(5, 0.52, 0.33, 0.55, 0.05, 0.30)
	ramp_cap_blue = _ramp(4, 0.66, 0.52, 0.45, 0.35, 0.95)
	ramp_violet = _ramp(4, 0.76, 0.86, 0.65, 0.4, 1.0)
	ramp_awakened = _ramp(5, 0.70, 0.80, 0.55, 0.18, 0.70)
	ramp_straw = _ramp(4, 0.06, 0.13, 0.45, 0.45, 0.88)
	ramp_steel = _ramp(5, 0.64, 0.14, 0.14, 0.24, 0.95)
	ramp_tabard = _ramp(5, 0.68, 0.60, 0.62, 0.16, 0.70)
	ramp_linen = _ramp(4, 0.08, 0.13, 0.22, 0.45, 0.88)
	ramp_leather = _ramp(4, 0.98, 0.08, 0.45, 0.16, 0.48)
	ramp_bronze = _ramp(4, 0.02, 0.11, 0.6, 0.35, 0.92)
	ramp_armor = _ramp(5, 0.66, 0.12, 0.16, 0.18, 0.78)
	ramp_cap_brown = _ramp(4, 0.92, 0.10, 0.28, 0.28, 0.72)


# ------------------------------------------------------------------ primitivas

func _img(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(img, xx, yy, c)


func _ellipse(img: Image, c: Vector2, rx: float, ry: float, col: Color) -> void:
	for y in range(int(c.y - ry), int(c.y + ry) + 1):
		for x in range(int(c.x - rx), int(c.x + rx) + 1):
			var nx := (x - c.x) / maxf(rx, 0.5)
			var ny := (y - c.y) / maxf(ry, 0.5)
			if nx * nx + ny * ny <= 1.0:
				_put(img, x, y, col)


func _pick(ramp: Array[Color], t: float) -> Color:
	return ramp[clampi(int(t * ramp.size()), 0, ramp.size() - 1)]


func _sphere(nx: float, ny: float) -> float:
	var nz := sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))
	return clampf(nx * light_dir.x + ny * light_dir.y + nz * light_dir.z, 0.0, 1.0)


## Massa com volume: luz esférica + aglomerados por ruído + borda recortada.
func _blob(img: Image, c: Vector2, r: Vector2, ramp: Array[Color], jag: float, clump: float, seed_off: float) -> void:
	for y in range(int(c.y - r.y * 1.4), int(c.y + r.y * 1.4) + 1):
		for x in range(int(c.x - r.x * 1.4), int(c.x + r.x * 1.4) + 1):
			var nx := (x - c.x) / r.x
			var ny := (y - c.y) / r.y
			var edge := 1.0 + noise.get_noise_2d(x * 2.5 + seed_off, y * 2.5) * jag
			if nx * nx + ny * ny > edge:
				continue
			var lit := _sphere(clampf(nx, -0.95, 0.95), clampf(ny, -0.95, 0.95))
			lit += noise.get_noise_2d(x * 5.0 + seed_off * 2.0, y * 5.0) * clump
			_put(img, x, y, _pick(ramp, lit))


## Contorno colorido só na silhueta: tom escuro da cor vizinha, puxado para roxo.
func _outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for o in N4:
				var q := Vector2i(x, y) + o
				if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
					continue
				var c := src.get_pixel(q.x, q.y)
				if c.a > 0.5:
					img.set_pixel(x, y, Color.from_hsv(fposmod(c.h - 0.05, 1.0), minf(1.0, c.s + 0.25), c.v * 0.32))
					break


func _save(img: Image, rel: String) -> void:
	var err := img.save_png(ART + rel)
	if err != OK:
		push_error("gen_art: falha ao salvar %s (%d)" % [rel, err])


# ------------------------------------------------------------------ árvores

func _trunk(img: Image, base: Vector2, w: float, h: int, ramp: Array[Color], flare: float) -> void:
	for i in h:
		var y := int(base.y) - i
		var t := float(i) / float(h)
		var hw := w * 0.5 + pow(1.0 - t, 5.0) * flare
		for x in range(int(base.x - hw), int(base.x + hw) + 1):
			var nx := (x - base.x) / maxf(hw, 1.0)
			var lit := 0.6 - nx * 0.5 + noise.get_noise_2d(x * 7.0, y * 0.7) * 0.22
			_put(img, x, y, _pick(ramp, lit))
	for side: float in [-1.0, 1.0]:
		_blob(img, base + Vector2(side * (w * 0.5 + 5.0), -1.0), Vector2(7.0, 3.0), ramp, 0.25, 0.1, 31.0 * side)


func _canopy(img: Image, blobs: Array, ramp: Array[Color]) -> void:
	blobs.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	for b: Array in blobs:
		_blob(img, Vector2(b[0], b[1]), Vector2(b[2], b[3]), ramp, 0.35, 0.3, float(b[0]) * 1.7)


func _gen_trees() -> Array:
	# Carvalho: copa larga em 8 massas.
	var oak := _img(176, 208)
	_trunk(oak, Vector2(88, 202), 20.0, 96, ramp_bark, 14.0)
	_canopy(oak, [[88, 62, 50, 38], [52, 84, 32, 27], [124, 84, 32, 27], [70, 46, 32, 26],
		[108, 42, 30, 24], [88, 96, 42, 26], [58, 108, 24, 17], [118, 106, 26, 17]], ramp_leaf)
	_outline(oak)
	_save(oak, "env/tree_oak.png")

	# Pinheiro: 6 camadas, cada uma com topo iluminado e base em sombra.
	var pine := _img(128, 224)
	_trunk(pine, Vector2(64, 218), 10.0, 70, ramp_bark, 8.0)
	for k in 6:
		var top := 6 + k * 26
		var maxw := 14.0 + k * 9.0
		for i in 44:
			var y := top + i
			var t := float(i) / 44.0
			var hw := maxw * pow(t, 0.8) + noise.get_noise_2d(y * 3.0, k * 10.0) * 3.0
			for x in range(int(64.0 - hw), int(64.0 + hw) + 1):
				var nx := (x - 64.0) / maxf(hw, 1.0)
				var lit := 0.62 - nx * 0.35 - t * 0.4 + noise.get_noise_2d(x * 6.0, y * 6.0) * 0.25
				_put(pine, x, y, _pick(ramp_pine, lit))
	_outline(pine)
	_save(pine, "env/tree_pine.png")

	# Bétula: tronco claro com marcas e copa verde-amarelada.
	var birch := _img(144, 184)
	_trunk(birch, Vector2(72, 178), 12.0, 100, ramp_birch_bark, 8.0)
	for i in 30:
		var y := 178 - rng.randi_range(6, 95)
		var x := 72 + rng.randi_range(-5, 3)
		_put(birch, x, y, ramp_bark[0])
		_put(birch, x + 1, y, ramp_bark[1])
		if rng.randf() < 0.5:
			_put(birch, x + 2, y, ramp_bark[0])
	_canopy(birch, [[72, 52, 40, 30], [44, 70, 24, 20], [100, 68, 26, 21], [62, 36, 24, 19],
		[86, 34, 22, 18], [72, 84, 30, 18]], ramp_birch_leaf)
	_outline(birch)
	_save(birch, "env/tree_birch.png")

	# Metadados usados em runtime: pivô na base do tronco, raio de colisão, área da copa.
	return [
		{"name": "oak", "texture": "env/tree_oak.png", "pivot": [88, 202], "radius": 11, "canopy": [176, 130], "canopy_v": 0.62, "shadow": 1.5},
		{"name": "pine", "texture": "env/tree_pine.png", "pivot": [64, 218], "radius": 7, "canopy": [120, 180], "canopy_v": 0.82, "shadow": 1.0},
		{"name": "birch", "texture": "env/tree_birch.png", "pivot": [72, 178], "radius": 7, "canopy": [140, 102], "canopy_v": 0.58, "shadow": 1.15},
	]


# ------------------------------------------------------------------ vegetação baixa

func _gen_undergrowth() -> void:
	for v in 3:
		var g := _img(24, 30)
		for b in 12 + v * 3:
			var bx := 12.0 + rng.randf_range(-7.0, 7.0)
			var hgt := rng.randf_range(12.0, 27.0)
			var lean := rng.randf_range(-0.3, 0.3) + (bx - 12.0) * 0.04
			var shade := rng.randf_range(0.0, 0.3)
			for i in int(hgt):
				var t := float(i) / hgt
				var x := roundi(bx + lean * i + lean * t * t * 6.0)
				var y := 29 - i
				_put(g, x, y, _pick(ramp_grass, 0.1 + t * 0.9 - shade))
				if t < 0.35:
					_put(g, x + 1, y, _pick(ramp_grass, t - shade))
			if v == 2 and rng.randf() < 0.5:
				var tx := roundi(bx + lean * hgt + lean * 6.0)
				_put(g, tx, 29 - int(hgt), Color("e8d79a"))
				_put(g, tx, 28 - int(hgt), Color("f6ecc0"))
		_save(g, "env/grass_tall_%d.png" % v)

	for v in 2:
		var f := _img(36, 26)
		var origin := Vector2(18, 24)
		var fronds := 7 + v
		for k in fronds:
			var ang := deg_to_rad(lerpf(-165.0, -15.0, float(k) / float(fronds - 1)) + rng.randf_range(-8.0, 8.0))
			var length := rng.randf_range(10.0, 15.0) * (1.0 - absf(cos(ang)) * 0.2)
			var dir := Vector2(cos(ang), sin(ang))
			var perp := Vector2(-dir.y, dir.x)
			for i in int(length):
				var t := float(i) / length
				var p := origin + dir * i + Vector2(0.0, t * t * 5.0)
				_put(f, roundi(p.x), roundi(p.y), _pick(ramp_pine, 0.2 + t * 0.3))
				if i % 2 == 0 and t < 0.92:
					var leaf_len := int((1.0 - t) * 3.0) + 1
					for s: float in [-1.0, 1.0]:
						for j in range(1, leaf_len + 1):
							var q := p + perp * s * j
							_put(f, roundi(q.x), roundi(q.y), _pick(ramp_leaf, 0.3 + t * 0.55 + (0.15 if s < 0 else -0.05)))
		_outline(f)
		_save(f, "env/fern_%d.png" % v)

	for v in 3:
		var b := _img(40, 30)
		_canopy(b, [[14, 18, 11, 9], [27, 18, 11, 9], [20, 11, 12, 9], [20, 21, 13, 7]], ramp_leaf)
		if v == 1:
			for i in 9:
				var p := Vector2i(rng.randi_range(8, 31), rng.randi_range(6, 22))
				_rect(b, p.x, p.y, 2, 2, Color("3a5ab5"))
				_put(b, p.x, p.y, Color("9ab8ff"))
		elif v == 2:
			for i in 10:
				var p := Vector2i(rng.randi_range(8, 31), rng.randi_range(5, 22))
				var petal := Color("f4f1e6") if i % 2 == 0 else Color("f0b8cf")
				for o in N4:
					_put(b, p.x + o.x, p.y + o.y, petal)
				_put(b, p.x, p.y, Color("f2d45c"))
		_outline(b)
		_save(b, "env/bush_%d.png" % v)

	var petals: Array[Color] = [Color("f4f1e6"), Color("f2d45c"), Color("e58bb0"), Color("9a8be8")]
	for v in 4:
		var fl := _img(16, 16)
		for s in 5:
			var tip := Vector2i(rng.randi_range(3, 12), rng.randi_range(3, 9))
			for y in range(tip.y, 16):
				_put(fl, tip.x + (1 if y > 12 and tip.x < 8 else 0), y, _pick(ramp_grass, 0.3 + float(y - tip.y) * 0.02))
			for o in N4:
				_put(fl, tip.x + o.x, tip.y + o.y, petals[v])
			_put(fl, tip.x, tip.y, Color("f6c94a") if v != 1 else Color("c2601a"))
		_save(fl, "env/flowers_%d.png" % v)

	for v in 2:
		var m := _img(14, 12)
		var ramp := ramp_cap_blue if v == 0 else ramp_cap_brown
		_rect(m, 5, 6, 4, 5, Color("e9dfc6"))
		_rect(m, 7, 6, 2, 5, Color("b9a98a"))
		_blob(m, Vector2(7, 5), Vector2(6, 3.5), ramp, 0.0, 0.05, 3.0)
		if v == 0:
			for p in [Vector2i(4, 4), Vector2i(8, 3), Vector2i(10, 5)]:
				_put(m, p.x, p.y, Color("fbf6ea"))
		_outline(m)
		_save(m, "env/mushroom_%d.png" % v)


func _gen_rocks_and_wood() -> void:
	var sizes := [Vector2(12, 8), Vector2(18, 12), Vector2(7, 5)]
	for v in 3:
		var r: Vector2 = sizes[v]
		var img := _img(int(r.x * 2.0 + 6.0), int(r.y * 2.0 + 6.0))
		var c := Vector2(r.x + 3.0, r.y + 3.0)
		for y in img.get_height():
			for x in img.get_width():
				var nx := (x - c.x) / r.x
				var ny := (y - c.y) / r.y
				if nx * nx + ny * ny > 1.0 + noise.get_noise_2d(x * 3.0 + v * 50.0, y * 3.0) * 0.2:
					continue
				var lit := _sphere(clampf(nx, -0.95, 0.95), clampf(ny, -0.95, 0.95)) + noise.get_noise_2d(x * 7.0, y * 7.0) * 0.12
				var col := _pick(ramp_stone, lit)
				if v != 2 and ny < -0.15 and noise.get_noise_2d(x * 4.0 + 99.0, y * 4.0) > 0.0:
					col = _pick(ramp_moss, lit)
				_put(img, x, y, col)
		_outline(img)
		_save(img, "env/rock_%d.png" % v)

	var log_img := _img(64, 24)
	for y in range(4, 21):
		for x in range(8, 60):
			var ny := (y - 12.0) / 8.0
			var lit := 0.55 - ny * 0.45 + noise.get_noise_2d(x * 0.8, y * 9.0) * 0.3
			var col := _pick(ramp_bark, lit)
			if ny < -0.5 and noise.get_noise_2d(x * 3.0 + 7.0, y * 3.0) > 0.15:
				col = _pick(ramp_moss, lit)
			_put(log_img, x, y, col)
	for y in range(4, 21):
		for x in range(4, 13):
			var nx := (x - 8.0) / 4.0
			var ny := (y - 12.0) / 8.5
			var d := sqrt(nx * nx + ny * ny)
			if d <= 1.0:
				_put(log_img, x, y, _pick(ramp_dirt, 0.95 - fmod(d * 3.0, 1.0) * 0.4 - (0.35 if d > 0.85 else 0.0)))
	_outline(log_img)
	_save(log_img, "env/log.png")

	var stump := _img(30, 28)
	_trunk(stump, Vector2(15, 25), 18.0, 14, ramp_bark, 5.0)
	for y in range(7, 16):
		for x in range(5, 26):
			var nx := (x - 15.0) / 9.5
			var ny := (y - 11.0) / 4.0
			var d := sqrt(nx * nx + ny * ny)
			if d <= 1.0:
				_put(stump, x, y, _pick(ramp_dirt, 0.95 - fmod(d * 3.0, 1.0) * 0.35 - (0.4 if d > 0.85 else 0.0)))
	_outline(stump)
	_save(stump, "env/stump.png")


func _gen_foreground() -> void:
	for v in 2:
		var img := _img(240, 100)
		var blobs: Array = []
		for i in 11:
			blobs.append([rng.randi_range(0, 240), rng.randi_range(-10, 34) + (i % 3) * 8, rng.randi_range(22, 40), rng.randi_range(18, 30)])
		for b: Array in blobs:
			_blob(img, Vector2(b[0], b[1]), Vector2(b[2], b[3]), ramp_fg, 0.45, 0.35, float(b[0]))
		for k in 6:
			var x := rng.randi_range(20, 220)
			var length := rng.randi_range(20, 50)
			for i in length:
				var px := x + roundi(sin(i * 0.25 + k) * 2.0)
				_put(img, px, 40 + i, ramp_fg[1])
				if i % 4 == 0:
					_put(img, px + 1, 40 + i, ramp_fg[2])
					_put(img, px - 1, 41 + i, ramp_fg[2])
		_save(img, "env/fg_canopy_%d.png" % v)

	var fern := _img(150, 90)
	var origin := Vector2(10, 92)
	for k in 9:
		var ang := deg_to_rad(lerpf(-95.0, -5.0, float(k) / 8.0))
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var length := rng.randf_range(70.0, 110.0)
		for i in int(length):
			var t := float(i) / length
			var p := origin + dir * i + Vector2(0.0, t * t * 26.0)
			_rect(fern, roundi(p.x), roundi(p.y), 2, 2, ramp_fg[1])
			if i % 3 == 0 and t < 0.95:
				var leaf_len := int((1.0 - t) * 9.0) + 2
				for s: float in [-1.0, 1.0]:
					for j in range(1, leaf_len + 1):
						var q := p + perp * s * j + dir * j * 0.4
						_put(fern, roundi(q.x), roundi(q.y), _pick(ramp_fg, 0.35 + t * 0.4 + (0.15 if s < 0 else 0.0)))
	_save(fern, "env/fg_fern.png")


# ------------------------------------------------------------------ fauna

func _gen_critters() -> void:
	var wings: Array = [
		[Color("f28c28"), Color("3a1a12")],
		[Color("5aa8f0"), Color("1e2f6a")],
		[Color("f4e9a0"), Color("8a7a3a")],
	]
	var bf := _img(32, 24)
	for row in 3:
		var wc: Color = wings[row][0]
		var we: Color = wings[row][1]
		for f in 4:
			var ox := f * 8
			var oy := row * 8
			var span: int = [3, 2, 0, 2][f]
			if span == 0:
				_rect(bf, ox + 4, oy + 1, 1, 5, wc)
			else:
				_rect(bf, ox + 3 - span, oy + 1, span, 3, wc)
				_rect(bf, ox + 4, oy + 1, span, 3, wc)
				_rect(bf, ox + 4 - span, oy + 4, span - 1 if span > 1 else 1, 2, wc)
				_rect(bf, ox + 4, oy + 4, span - 1 if span > 1 else 1, 2, wc)
				_put(bf, ox + 3 - span, oy + 1, we)
				_put(bf, ox + 3 + span, oy + 1, we)
			_rect(bf, ox + 3, oy + 2, 1, 4, Color("1a1214"))
	_save(bf, "critters/butterfly.png")

	# Coelho de perfil (para a direita): idle x2, agachar, esticar, ar, pousar.
	var rabbit := _img(96, 16)
	var rp: Array = [
		[Vector2(7, 11), Vector2(5, 3.5), Vector2(12, 8), 0],
		[Vector2(7, 11), Vector2(5, 3.5), Vector2(12, 8), 1],
		[Vector2(7, 12), Vector2(5.5, 3.0), Vector2(12, 9), 0],
		[Vector2(8, 9), Vector2(6, 3.0), Vector2(13, 6), 2],
		[Vector2(8, 8), Vector2(5, 3.2), Vector2(12.5, 6), 2],
		[Vector2(7, 12), Vector2(5.5, 3.0), Vector2(12, 9), 0],
	]
	for f in 6:
		var cell := _img(16, 16)
		var body: Vector2 = rp[f][0]
		var head: Vector2 = rp[f][2]
		var ear: int = rp[f][3]
		_blob(cell, body, rp[f][1], ramp_fur, 0.0, 0.06, 1.0)
		_blob(cell, head, Vector2(3, 2.8), ramp_fur, 0.0, 0.06, 2.0)
		for i in 5:
			var ex := int(head.x) - 1 - (i / 2 if ear == 2 else 0) - (1 if ear == 1 and i > 2 else 0)
			_put(cell, ex, int(head.y) - 3 - i, _pick(ramp_fur, 0.6))
			_put(cell, ex + 1, int(head.y) - 3 - i, _pick(ramp_fur, 0.85))
		_ellipse(cell, body + Vector2(-5.5, -1.0), 1.5, 1.5, Color("f4f1ea"))
		_put(cell, int(head.x) + 1, int(head.y) - 1, Color("1a1214"))
		_put(cell, int(head.x) + 3, int(head.y), Color("d48a9a"))
		_outline(cell)
		rabbit.blit_rect(cell, Rect2i(0, 0, 16, 16), Vector2i(f * 16, 0))
	_save(rabbit, "critters/rabbit.png")

	# Esquilo de perfil: idle x2, corrida x4, escalada x2 (de costas).
	var squirrel := _img(128, 16)
	for f in 8:
		var cell := _img(16, 16)
		if f < 6:
			var run := f >= 2
			var stretch: float = 1.0 if not run else [1.3, 0.9, 1.25, 0.95][f - 2]
			var body := Vector2(8, 11)
			_blob(cell, Vector2(3.5, 6.0 + (1.0 if f == 1 else 0.0) + (2.0 if run else 0.0)), Vector2(3.0, 4.5 if not run else 3.0), ramp_squirrel, 0.2, 0.15, 9.0)
			_blob(cell, body, Vector2(4.0 * stretch, 2.8), ramp_squirrel, 0.0, 0.08, 4.0)
			_blob(cell, Vector2(12.5, 8.5), Vector2(2.5, 2.3), ramp_squirrel, 0.0, 0.05, 5.0)
			_put(cell, 12, 5, _pick(ramp_squirrel, 0.4))
			_put(cell, 13, 8, Color("1a1214"))
			_put(cell, 9, 12, Color("f1d9b8"))
		else:
			_blob(cell, Vector2(8, 13), Vector2(2.5, 3.0), ramp_squirrel, 0.2, 0.15, 11.0)
			_blob(cell, Vector2(8, 8), Vector2(3.0, 4.5), ramp_squirrel, 0.0, 0.08, 6.0)
			_blob(cell, Vector2(8, 3.5), Vector2(2.5, 2.2), ramp_squirrel, 0.0, 0.05, 7.0)
			var leg := 1 if f == 6 else -1
			_put(cell, 5, 6 + leg, _pick(ramp_squirrel, 0.2))
			_put(cell, 11, 6 - leg, _pick(ramp_squirrel, 0.2))
		_outline(cell)
		squirrel.blit_rect(cell, Rect2i(0, 0, 16, 16), Vector2i(f * 16, 0))
	_save(squirrel, "critters/squirrel.png")


# ------------------------------------------------------------------ inimigos (ASSET-011, ASSET-012)

## Inclina as linhas acima do pé: `amount` px no topo da célula, 0 no pivô (y = 58).
func _shear(src: Image, amount: float) -> Image:
	var out := _img(src.get_width(), src.get_height())
	for y in src.get_height():
		var dx := roundi(amount * clampf((58.0 - y) / 40.0, 0.0, 1.5))
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a > 0.0:
				_put(out, x + dx, y, c)
	return out


func _tri(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var lo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y))).floor()
	var hi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y))).ceil()
	for y in range(int(lo.y), int(hi.y) + 1):
		for x in range(int(lo.x), int(hi.x) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := (p - b).cross(a - b)
			var d2 := (p - c).cross(b - c)
			var d3 := (p - a).cross(c - a)
			var neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
			var pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
			if not (neg and pos):
				_put(img, x, y, col)


## Fragmento de cristal violeta pontudo (art bible §3: o que acordou é angular e quebrado).
func _shard(img: Image, base: Vector2, tip: Vector2, half_w: float) -> void:
	var side := (tip - base).orthogonal().normalized() * half_w
	_tri(img, base - side, base + side, tip, ramp_violet[1])
	_tri(img, base - side, base, tip, ramp_violet[3])
	_put(img, int(tip.x), int(tip.y), Color(1.0, 0.75, 1.0))


func _gen_enemies() -> void:
	# Boneco de treino: alvo dourado e creme (carmesim é a cor do jogador, art bible §4).
	var upright := _img(64, 64)
	_rect(upright, 25, 55, 14, 3, ramp_bark[0])
	_rect(upright, 30, 36, 4, 20, ramp_bark[3])
	_rect(upright, 32, 36, 2, 20, ramp_bark[1])
	_rect(upright, 17, 29, 30, 3, ramp_bark[3])
	_rect(upright, 17, 31, 30, 1, ramp_bark[1])
	_blob(upright, Vector2(32, 35), Vector2(9, 11), ramp_straw, 0.05, 0.15, 3.0)
	_rect(upright, 23, 40, 18, 1, ramp_bark[2])
	_ellipse(upright, Vector2(32, 34), 5, 5, ramp_gold[2])
	_ellipse(upright, Vector2(32, 34), 3, 3, Color("fff4c2"))
	_ellipse(upright, Vector2(32, 34), 1.5, 1.5, ramp_gold[1])
	_blob(upright, Vector2(32, 18), Vector2(6, 6), ramp_straw, 0.05, 0.12, 9.0)
	for p in [Vector2i(29, 17), Vector2i(30, 18), Vector2i(34, 17), Vector2i(33, 18)]:
		_put(upright, p.x, p.y, ramp_bark[0])
	for p in [Vector2i(26, 22), Vector2i(38, 23), Vector2i(16, 28), Vector2i(46, 28)]:
		_rect(upright, p.x, p.y, 2, 2, ramp_straw[3])
	var broken := _img(64, 64)
	_rect(broken, 25, 55, 14, 3, ramp_bark[0])
	_rect(broken, 30, 48, 4, 8, ramp_bark[3])
	for i in 14:
		var p := Vector2i(rng.randi_range(14, 50), rng.randi_range(50, 58))
		_rect(broken, p.x, p.y, rng.randi_range(2, 4), 1, ramp_straw[rng.randi_range(1, 3)])
	_blob(broken, Vector2(44, 54), Vector2(5, 3), ramp_straw, 0.2, 0.15, 4.0)
	var dummy := _img(256, 64)
	var frames: Array[Image] = [upright, _shear(upright, -4.0), _shear(upright, 4.0), broken]
	for f in 4:
		var cell := frames[f]
		_outline(cell)
		dummy.blit_rect(cell, Rect2i(0, 0, 64, 64), Vector2i(f * 64, 0))
	_save(dummy, "enemies/enemy_training_dummy.png")

	# Slime Desperto: gelatina azul-violeta com cristais violeta quebrados.
	var slime := _img(256, 64)
	var shapes: Array = [[Vector2(32, 46), Vector2(10, 11)], [Vector2(32, 51), Vector2(14, 7)],
		[Vector2(32, 50), Vector2(12, 8)], [Vector2(32, 55), Vector2(17, 3.5)]]
	for f in 4:
		var cell := _img(64, 64)
		var c: Vector2 = shapes[f][0]
		var r: Vector2 = shapes[f][1]
		_blob(cell, c, r, ramp_awakened, 0.12, 0.12, 20.0 + f)
		_ellipse(cell, c + Vector2(-3, -r.y * 0.45), r.x * 0.35, maxf(1.0, r.y * 0.18), ramp_awakened[4])
		if f < 3:
			var top := c.y - r.y
			_shard(cell, Vector2(c.x - 5, top + 3), Vector2(c.x - 9, top - 7), 2.0)
			_shard(cell, Vector2(c.x + 3, top + 2), Vector2(c.x + 6, top - 9), 2.5)
			_shard(cell, Vector2(c.x + 9, c.y - 2), Vector2(c.x + 16, c.y - 7), 1.8)
			var eye_y := int(c.y - r.y * 0.1)
			var eye := Color(0.85, 1.0, 1.0) if f != 2 else ramp_awakened[0]
			_rect(cell, int(c.x) - 5, eye_y, 2, 2 if f != 2 else 1, eye)
			_rect(cell, int(c.x) + 2, eye_y, 2, 2 if f != 2 else 1, eye)
		else:
			_shard(cell, Vector2(c.x - 10, c.y - 1), Vector2(c.x - 13, c.y - 6), 1.5)
			_shard(cell, Vector2(c.x + 8, c.y - 1), Vector2(c.x + 12, c.y - 5), 1.5)
		_outline(cell)
		slime.blit_rect(cell, Rect2i(0, 0, 64, 64), Vector2i(f * 64, 0))
	_save(slime, "enemies/enemy_slime_awakened.png")


# ------------------------------------------------------------------ efeitos e utilitários

func _gen_fx() -> void:
	var leaf := _img(6, 4)
	for p in [Vector2i(2, 0), Vector2i(3, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]:
		leaf.set_pixel(p.x, p.y, Color(0.85, 0.85, 0.85) if p.y < 2 else Color(0.62, 0.62, 0.62))
	leaf.set_pixel(1, 3, Color(0.45, 0.45, 0.45))
	_save(leaf, "fx/leaf.png")

	var mote := _img(3, 3)
	for p in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		mote.set_pixel(p.x, p.y, Color(1, 1, 1, 0.45))
	mote.set_pixel(1, 1, Color(1, 1, 1, 1))
	_save(mote, "fx/mote.png")

	var soft := _img(32, 16)
	for y in 16:
		for x in 32:
			var nx := (x - 15.5) / 16.0
			var ny := (y - 7.5) / 8.0
			var d := nx * nx + ny * ny
			if d < 1.0:
				soft.set_pixel(x, y, Color(0, 0, 0, floorf(pow(1.0 - d, 1.2) * 4.0) / 4.0))
	_save(soft, "fx/soft_shadow.png")

	var canopy := _img(128, 64)
	for y in 64:
		for x in 128:
			var nx := (x - 63.5) / 64.0
			var ny := (y - 31.5) / 32.0
			var d := nx * nx + ny * ny
			if d < 1.0:
				canopy.set_pixel(x, y, Color(0, 0, 0, clampf((1.0 - d) * 1.6, 0.0, 1.0)))
	_save(canopy, "fx/canopy_shadow.png")

	var light := _img(64, 64)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			if d < 1.0:
				light.set_pixel(x, y, Color(1, 1, 1, pow(1.0 - d, 2.0)))
	_save(light, "fx/light_radial.png")

	var px := _img(1, 1)
	px.set_pixel(0, 0, Color.WHITE)
	_save(px, "fx/pixel.png")


# ------------------------------------------------------------------ mago (ASSET-001)

func _gen_mage_sheet() -> void:
	var sheet := _img(384, 576)
	var rows := {"idle": [0, 1, 2], "walk": [3, 4, 5], "attack": [6, 7, 8]}
	var frames := {"idle": 4, "walk": 6, "attack": 6}
	var dirs := ["down", "up", "right"]
	for anim: String in rows:
		for di in 3:
			for f in int(frames[anim]):
				var cell := _img(64, 64)
				_draw_mage(cell, dirs[di], anim, f)
				_outline(cell)
				sheet.blit_rect(cell, Rect2i(0, 0, 64, 64), Vector2i(f * 64, int(rows[anim][di]) * 64))
	_save(sheet, "chars/spr_mage_fire_sheet.png")


func _draw_mage(g: Image, dir: String, anim: String, f: int) -> void:
	var cx := 32
	var side := dir == "right"
	var bobs := {"idle": [0, 1, 1, 0], "walk": [0, -1, 0, -1, 0, -1], "attack": [0, -1, -1, 0, 0, 0]}
	var bob: int = bobs[anim][f]
	var sway: int = [1, 0, -1, 0, 1, 0][f] if anim == "walk" else 0
	var y_top := 32 + bob
	var y_bot := 55
	var boot := ramp_bark[0]

	if side:
		_rect(g, cx - 5 + sway * 2, 55, 4, 2, boot)
		_rect(g, cx + 1 - sway * 2, 55, 4, 2, boot)
	else:
		_rect(g, cx - 5, 55 - (1 if sway > 0 else 0), 3, 2, boot)
		_rect(g, cx + 2, 55 - (1 if sway < 0 else 0), 3, 2, boot)

	for y in range(y_top, y_bot + 1):
		var t := float(y - y_top) / float(y_bot - y_top)
		var hw := roundi((5.0 if side else 6.0) + t * (6.0 if side else 8.0))
		var sx := roundi(sway * t * 2.0)
		var left := cx - hw + sx
		var right := cx + hw + sx
		for x in range(left, right):
			var nx := float(x - left) / float(maxi(1, right - left - 1))
			var lit := 0.92 - nx * 0.85
			if y > y_top + 11 and (absf(nx - 0.34) < 0.05 or absf(nx - 0.67) < 0.05):
				lit -= 0.3
			_put(g, x, y, _pick(ramp_gold if y >= y_bot - 1 else ramp_robe, lit))
	var belt := 6 if side else 7
	for x in range(cx - belt, cx + belt):
		_put(g, x, y_top + 9, _pick(ramp_gold, 0.95 - float(x - cx + belt) / float(belt * 2)))

	if side:
		_rect(g, cx + 1, y_top + 3, 6, 7, ramp_robe[3])
		_rect(g, cx + 5, y_top + 3, 2, 7, ramp_robe[1])
		_rect(g, cx + 1, y_top + 9, 6, 1, ramp_gold[2])
	else:
		_rect(g, cx - 10, y_top + 2, 4, 8, ramp_robe[4])
		_rect(g, cx - 10, y_top + 9, 4, 1, ramp_gold[3])
		_rect(g, cx + 6, y_top + 2, 4, 8, ramp_robe[1])
		_rect(g, cx + 6, y_top + 9, 4, 1, ramp_gold[1])

	var hb := y_top + 2
	var tip := y_top - 20
	var lean := -5 if side else 0
	for y in range(tip, hb + 1):
		var t := float(y - tip) / float(hb - tip)
		var hw := maxi(1, roundi(sqrt(t) * 10.0))
		var ox := roundi(lean * (1.0 - t))
		var left := cx - hw + ox
		for x in range(left, left + hw * 2):
			var nx := float(x - left) / float(maxi(1, hw * 2 - 1))
			_put(g, x, y, _pick(ramp_robe, 1.0 - nx * 0.85 - (0.12 if t < 0.12 else 0.0)))
	var shadow_face := ramp_robe[0].darkened(0.55)
	var eye := Color("ffb347")
	if dir == "down":
		_ellipse(g, Vector2(cx, y_top - 5), 6, 5, ramp_gold[2])
		_ellipse(g, Vector2(cx, y_top - 5), 5, 4, shadow_face)
		_rect(g, cx - 3, y_top - 6, 2, 2, eye)
		_rect(g, cx + 1, y_top - 6, 2, 2, eye)
		_put(g, cx - 3, y_top - 6, Color("fff0c0"))
		_put(g, cx + 1, y_top - 6, Color("fff0c0"))
	elif side:
		_ellipse(g, Vector2(cx + 4, y_top - 5), 4, 5, ramp_gold[2])
		_ellipse(g, Vector2(cx + 4, y_top - 5), 3, 4, shadow_face)
		_rect(g, cx + 5, y_top - 6, 2, 2, eye)
		_put(g, cx + 5, y_top - 6, Color("fff0c0"))
	else:
		_rect(g, cx, tip + 6, 1, hb - tip - 6, ramp_robe[1])

	var hy := y_top + 8
	var hx := cx - 13 if dir == "down" else (cx + 11 if dir == "up" else cx + 7)
	var sdx := 0
	var sdy := 0
	var charge := 0
	var flash := false
	if anim == "attack":
		var fdx := 1 if side else 0
		var fdy := 1 if dir == "down" else (-1 if dir == "up" else 0)
		if f == 0:
			sdy = -3
		elif f == 1 or f == 2:
			sdy = -5
			charge = f
		elif f == 3:
			sdx = fdx * 6
			sdy = fdy * 5 - 1
			flash = true
		elif f == 4:
			sdx = fdx * 3
			sdy = fdy * 2
	var top := hy - 18 + sdy
	var bot := hy + 12 + sdy
	var sx := hx + sdx
	_rect(g, sx, top, 1, bot - top, ramp_bark[3])
	_rect(g, sx + 1, top, 1, bot - top, ramp_bark[1])
	_rect(g, sx - 1, hy + sdy - 1, 4, 3, ramp_bark[0])
	_rect(g, sx - 1, top - 4, 4, 4, FIRE[1])
	_rect(g, sx, top - 3, 2, 2, FIRE[2])
	_put(g, sx, top - 3, FIRE[3])
	if charge > 0:
		_ellipse(g, Vector2(sx + 1, top - 7), charge + 2, charge + 2, FIRE[1])
		_ellipse(g, Vector2(sx + 1, top - 7), charge + 1, charge + 1, FIRE[2])
		_rect(g, sx, top - 8, 2, 2, FIRE[3])
	if flash:
		_ellipse(g, Vector2(sx + 1, top - 5), 5, 5, FIRE[2])
		_ellipse(g, Vector2(sx + 1, top - 5), 3, 3, FIRE[3])


# ------------------------------------------------------------------ guerreiro

## Linha grossa em pixels (lâmina da espada).
func _line(g: Image, a: Vector2, b: Vector2, thick: int, col: Color) -> void:
	var n := maxi(1, int(a.distance_to(b)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		_rect(g, roundi(p.x - thick / 2.0), roundi(p.y - thick / 2.0), thick, thick, col)


func _gen_warrior_sheet() -> void:
	var sheet := _img(384, 576)
	var rows := {"idle": [0, 1, 2], "walk": [3, 4, 5], "attack": [6, 7, 8]}
	var frames := {"idle": 4, "walk": 6, "attack": 6}
	var dirs := ["down", "up", "right"]
	for anim: String in rows:
		for di in 3:
			for f in int(frames[anim]):
				var cell := _img(64, 64)
				_draw_warrior(cell, dirs[di], anim, f)
				_outline(cell)
				sheet.blit_rect(cell, Rect2i(0, 0, 64, 64), Vector2i(f * 64, int(rows[anim][di]) * 64))
	_save(sheet, "chars/spr_warrior_sheet.png")


## Guerreiro (art bible §3): ombros largos + lâmina larga. Aço, tabardo azul-nobre, ouro.
func _draw_warrior(g: Image, dir: String, anim: String, f: int) -> void:
	var cx := 32
	var side := dir == "right"
	var bobs := {"idle": [0, 1, 1, 0], "walk": [0, -1, 0, -1, 0, -1], "attack": [0, -1, -1, 1, 1, 0]}
	var bob: int = bobs[anim][f]
	var step: int = [1, 0, -1, 0, 1, 0][f] if anim == "walk" else 0
	var y_top := 30 + bob

	# pernas e botas
	var boot := ramp_steel[0]
	if side:
		_rect(g, cx - 5 + step * 2, 47, 4, 9, ramp_steel[1])
		_rect(g, cx + 1 - step * 2, 47, 4, 9, ramp_steel[2])
		_rect(g, cx - 6 + step * 2, 54, 5, 2, boot)
		_rect(g, cx + 1 - step * 2, 54, 5, 2, boot)
	else:
		_rect(g, cx - 6, 47 - (1 if step > 0 else 0), 4, 9, ramp_steel[2])
		_rect(g, cx + 2, 47 - (1 if step < 0 else 0), 4, 9, ramp_steel[1])
		_rect(g, cx - 6, 54 - (1 if step > 0 else 0), 5, 2, boot)
		_rect(g, cx + 2, 54 - (1 if step < 0 else 0), 5, 2, boot)

	# tabardo
	for y in range(y_top + 10, 51):
		var t := float(y - y_top - 10) / 10.0
		var hw := roundi((5.0 if side else 7.0) + t * 2.0)
		for x in range(cx - hw, cx + hw):
			var nx := float(x - cx + hw) / float(hw * 2)
			_put(g, x, y, _pick(ramp_tabard, 0.85 - nx * 0.7))
	if not side and dir == "down":
		for y in range(y_top + 12, 49):
			_put(g, cx, y, ramp_gold[2])
		_rect(g, cx - 2, y_top + 15, 5, 1, ramp_gold[2])

	# peitoral e cinto
	var chest_w := 8 if side else 11
	for y in range(y_top, y_top + 11):
		for x in range(cx - chest_w, cx + chest_w):
			var nx := float(x - cx + chest_w) / float(chest_w * 2)
			var ny := float(y - y_top) / 11.0
			_put(g, x, y, _pick(ramp_steel, 0.9 - nx * 0.6 - ny * 0.25))
	_rect(g, cx - chest_w, y_top + 10, chest_w * 2, 2, ramp_bark[1])
	_rect(g, cx - 1, y_top + 10, 3, 2, ramp_gold[3])

	# ombreiras largas (o traço da silhueta)
	if side:
		_blob(g, Vector2(cx + 2, y_top + 2), Vector2(7, 5), ramp_steel, 0.0, 0.05, 1.0)
		_rect(g, cx - 4, y_top + 5, 10, 1, ramp_gold[2])
	else:
		_blob(g, Vector2(cx - 11, y_top + 2), Vector2(6, 5), ramp_steel, 0.0, 0.05, 2.0)
		_blob(g, Vector2(cx + 11, y_top + 2), Vector2(6, 5), ramp_steel, 0.0, 0.05, 3.0)
		_rect(g, cx - 15, y_top + 6, 8, 1, ramp_gold[2])
		_rect(g, cx + 8, y_top + 6, 8, 1, ramp_gold[1])

	# elmo com viseira e penacho
	var head := Vector2(cx + (2 if side else 0), y_top - 6)
	_blob(g, head, Vector2(6, 6.5), ramp_steel, 0.0, 0.05, 4.0)
	if dir == "down":
		_rect(g, cx - 4, y_top - 6, 9, 2, ramp_steel[0])
		_put(g, cx - 2, y_top - 6, Color("9fd8ff"))
		_put(g, cx + 2, y_top - 6, Color("9fd8ff"))
		_rect(g, cx, y_top - 4, 1, 4, ramp_steel[1])
	elif side:
		_rect(g, cx + 3, y_top - 6, 5, 2, ramp_steel[0])
		_put(g, cx + 6, y_top - 6, Color("9fd8ff"))
	for i in 5:
		var px := cx + (2 if side else 0) - (i if side else 0)
		_rect(g, px, y_top - 13 - (i / 2 if not side else 0) + (i if side else 0) / 3, 2, 2, _pick(ramp_tabard, 0.5 + i * 0.1))

	# espada larga: posição por frame do ataque
	var hand := Vector2(cx - 13, y_top + 9) if dir == "down" else (Vector2(cx + 13, y_top + 9) if dir == "up" else Vector2(cx + 8, y_top + 8))
	var blade_dir := Vector2(0, -1)
	var reach := 22.0
	if anim == "attack":
		var fwd := Vector2(1, 0) if side else (Vector2(0, 1) if dir == "down" else Vector2(0, -1))
		var poses: Array[Vector2] = [Vector2(0.2, -1), Vector2(-0.6, -0.8), Vector2(-0.9, -0.4), fwd + Vector2(0.4, -0.2), fwd + Vector2(0.2, 0.7), Vector2(0.3, -1)]
		blade_dir = poses[f].normalized()
		if f == 3:
			reach = 26.0
	elif anim == "walk":
		blade_dir = Vector2(0.15 * step, -1).normalized()
	var tip := hand + blade_dir * reach
	_line(g, hand, tip, 3, ramp_steel[3])
	_line(g, hand + blade_dir * 2.0, tip, 1, Color("f4f8ff"))
	var guard := blade_dir.orthogonal()
	_line(g, hand - guard * 4.0, hand + guard * 4.0, 2, ramp_gold[2])
	_rect(g, roundi(hand.x) - 1, roundi(hand.y) - 1, 3, 3, ramp_bark[0])
	if anim == "attack" and f == 3:
		for k in 3:
			_put(g, roundi(tip.x + guard.x * (k - 1) * 2), roundi(tip.y + guard.y * (k - 1) * 2), Color("ffffff"))


# ------------------------------------------------------------------ paperdoll (raças + equipamento)
# Spec: design/assets/specs/character-races-and-equipment-spec.md. Todas as camadas usam
# o mesmo "esqueleto" paramétrico (_pose) por raça/direção/animação/frame, por isso
# encaixam: corpo, roupa e arma são desenhados sobre os mesmos ombros, quadris, mãos e pés.
# Alturas seguem o art bible §3/§8 (figura ~44 px, cabeça 12–14 px), não os 34 px da spec.
# Equipamento é gerado por raça (o robe do elfo não serve no anão).

const RACES := {
	"human": {"h": 44.0, "head_r": 6.5, "shoulder": 8.0, "hip": 6.0, "leg": 15.0, "limb": 4,
		"skin": [0.07, 0.42, 0.86], "hair": "6b4426", "hair_style": "short", "ears": false, "beard": false},
	"elf": {"h": 46.0, "head_r": 6.0, "shoulder": 7.0, "hip": 5.0, "leg": 17.0, "limb": 3,
		"skin": [0.09, 0.28, 0.93], "hair": "e6d38f", "hair_style": "long", "ears": true, "beard": false},
	"dwarf": {"h": 36.0, "head_r": 7.0, "shoulder": 10.0, "hip": 8.0, "leg": 10.0, "limb": 5,
		"skin": [0.06, 0.44, 0.82], "hair": "7a4a2a", "hair_style": "short", "ears": false, "beard": true},
}
const SHEET_LAYOUT := {"idle": [0, 1, 2], "walk": [3, 4, 5], "attack": [6, 7, 8]}
const SHEET_FRAMES := {"idle": 4, "walk": 6, "attack": 6}
const SHEET_DIRS: Array[String] = ["down", "up", "right"]


func _gen_paperdoll() -> void:
	var layers := {
		"spr_base_%s": _paint_base, "spr_gear_robe_fire_%s": _paint_robe_fire,
		"spr_gear_armor_iron_%s": _paint_armor_iron, "spr_weapon_staff_fire_%s": _paint_staff,
		"spr_weapon_sword_iron_%s": _paint_sword,
	}
	for race: String in RACES:
		for pattern: String in layers:
			_save(_layer_sheet(race, layers[pattern]), "chars/%s.png" % (pattern % race))
	_save_paperdoll_preview()


## Folha 384×576 de uma camada para uma raça, no layout padrão (idle/walk/attack × down/up/right).
func _layer_sheet(race: String, painter: Callable) -> Image:
	var sheet := _img(384, 576)
	var r: Dictionary = RACES[race]
	for anim: String in SHEET_LAYOUT:
		for di in 3:
			for f in int(SHEET_FRAMES[anim]):
				var cell := _img(64, 64)
				painter.call(cell, r, _pose(r, SHEET_DIRS[di], anim, f))
				_outline(cell)
				sheet.blit_rect(cell, Rect2i(0, 0, 64, 64), Vector2i(f * 64, int(SHEET_LAYOUT[anim][di]) * 64))
	return sheet


## Esqueleto do frame: cabeça, ombros, quadril, pés, mão da arma e direção da arma.
func _pose(r: Dictionary, dir: String, anim: String, f: int) -> Dictionary:
	var cx := 32.0
	var feet := 58.0
	var bob := 0.0
	var step := 0.0
	match anim:
		"idle":
			bob = [0.0, 0.0, 1.0, 1.0][f]
		"walk":
			bob = [0.0, -1.0, 0.0, 0.0, -1.0, 0.0][f]
			step = [1.0, 0.5, -0.5, -1.0, -0.5, 0.5][f]
		"attack":
			bob = [0.0, -1.0, -1.0, 1.0, 1.0, 0.0][f]
	var side := dir == "right"
	var head_r: float = r.head_r
	var head := Vector2(cx + (1.0 if side else 0.0), feet - float(r.h) + bob + head_r)
	var shoulder_y := head.y + head_r + 1.0
	var hip_y := feet - float(r.leg) + bob
	var sw: float = float(r.shoulder) * (0.7 if side else 1.0)
	var hw: float = float(r.hip) * (0.75 if side else 1.0)
	var wh: Vector2
	var oh: Vector2
	if side:
		wh = Vector2(cx + 4.0 + step * 3.0, hip_y - 3.0)
		oh = Vector2(cx - 3.0 - step * 3.0, hip_y - 3.0)
	else:
		var wx := -1.0 if dir == "down" else 1.0  # mão direita do personagem
		wh = Vector2(cx + wx * (sw + 1.0), hip_y - 2.0 + step * 1.5)
		oh = Vector2(cx - wx * (sw + 1.0), hip_y - 2.0 - step * 1.5)
	var wdir := Vector2(0, -1)
	if anim == "attack":
		var fwd := Vector2(1, 0) if side else (Vector2(0, 1) if dir == "down" else Vector2(0, -1))
		var lifts: Array[Vector2] = [Vector2(0, -6), Vector2(-3, -10), Vector2(-4, -11), fwd * 9.0 + Vector2(0, -4), fwd * 6.0, Vector2(0, -2)]
		var dirs: Array[Vector2] = [Vector2(0.2, -1), Vector2(-0.6, -0.8), Vector2(-0.9, -0.4), fwd + Vector2(0.3, -0.3), fwd + Vector2(0.2, 0.6), Vector2(0.2, -1)]
		wh += lifts[f]
		wdir = dirs[f].normalized()
	elif anim == "walk":
		wdir = Vector2(0.12 * step, -1).normalized()
	var lf: Vector2
	var rf: Vector2
	if side:
		lf = Vector2(cx - 2.0 + step * 4.0, feet)
		rf = Vector2(cx + 1.0 - step * 4.0, feet)
	else:
		lf = Vector2(cx - hw + 2.0, feet - maxf(0.0, step) * 1.5)
		rf = Vector2(cx + hw - 2.0, feet - maxf(0.0, -step) * 1.5)
	return {"cx": cx, "head": head, "head_r": head_r, "shoulder_y": shoulder_y, "hip_y": hip_y, "sw": sw, "hw": hw,
		"feet": feet, "lf": lf, "rf": rf, "wh": wh, "oh": oh, "wdir": wdir, "side": side, "dir": dir,
		"step": step, "anim": anim, "f": f}


func _skin_ramp(r: Dictionary) -> Array[Color]:
	var s: Array = r.skin
	return _ramp(4, float(s[0]) - 0.03, float(s[0]) + 0.03, float(s[1]), float(s[2]) - 0.38, float(s[2]))


func _hair_ramp(r: Dictionary) -> Array[Color]:
	var c := Color(String(r.hair))
	return _ramp(4, c.h - 0.04, c.h + 0.03, c.s, maxf(0.12, c.v - 0.35), minf(1.0, c.v + 0.12))


## Membro com volume: miolo, borda iluminada à esquerda e sombra à direita.
func _limb(g: Image, a: Vector2, b: Vector2, w: int, ramp: Array[Color]) -> void:
	_line(g, a, b, w, ramp[ramp.size() - 2])
	_line(g, a + Vector2(w / 2.0 - 0.5, 0), b + Vector2(w / 2.0 - 0.5, 0), 1, ramp[1])
	_line(g, a - Vector2(w / 2.0 - 0.5, 0), b - Vector2(w / 2.0 - 0.5, 0), 1, ramp[ramp.size() - 1])


## Tronco trapezoidal (ombro → quadril/barra), sombreado da esquerda para a direita.
func _torso(g: Image, p: Dictionary, ramp: Array[Color], extra_top: float, extra_bottom: float, top_y: float, bottom_y: float, sway := 0.0) -> void:
	var cx: float = p.cx
	for y in range(int(top_y), int(bottom_y) + 1):
		var t := clampf((y - top_y) / maxf(1.0, bottom_y - top_y), 0.0, 1.0)
		var half := lerpf(float(p.sw) + extra_top, float(p.hw) + extra_bottom, t)
		var off := sway * t * t
		for x in range(int(cx - half + off), int(cx + half + off) + 1):
			var nx := (x - (cx - half + off)) / maxf(1.0, half * 2.0)
			_put(g, x, y, _pick(ramp, 0.95 - nx * 0.8 - t * 0.1))


func _paint_base(g: Image, r: Dictionary, p: Dictionary) -> void:
	var skin := _skin_ramp(r)
	var hair := _hair_ramp(r)
	var limb: int = r.limb
	var cx: float = p.cx
	var hip_y: float = p.hip_y
	var shoulder_y: float = p.shoulder_y
	var head: Vector2 = p.head
	var hr: float = p.head_r
	# pernas (calça de tecido) e botas de couro
	for foot: Vector2 in [p.lf, p.rf]:
		var hip := Vector2(cx + (foot.x - cx) * 0.6, hip_y)
		_limb(g, hip, foot + Vector2(0, -2), limb, ramp_leather)
		_rect(g, roundi(foot.x - limb / 2.0 - 1), roundi(foot.y - 2), limb + 2, 2, ramp_leather[0])
	var shoulder_l := Vector2(cx - float(p.sw), shoulder_y + 1.0)
	var shoulder_r := Vector2(cx + float(p.sw), shoulder_y + 1.0)
	if p.side:
		_limb(g, Vector2(cx - 1, shoulder_y + 1), p.oh, limb - 1, ramp_linen)
	_torso(g, p, ramp_linen, 0.0, 0.0, shoulder_y, hip_y + 1.0)
	_rect(g, roundi(cx - float(p.hw)), roundi(hip_y), roundi(float(p.hw) * 2.0) + 1, 1, ramp_leather[1])
	if p.side:
		_limb(g, Vector2(cx + 1, shoulder_y + 1), p.wh, limb - 1, ramp_linen)
	else:
		var wh: Vector2 = p.wh
		var oh: Vector2 = p.oh
		_limb(g, shoulder_l if wh.x < cx else shoulder_r, wh, limb - 1, ramp_linen)
		_limb(g, shoulder_r if wh.x < cx else shoulder_l, oh, limb - 1, ramp_linen)
	for hand: Vector2 in [p.wh, p.oh]:
		if p.side and hand == p.oh:
			continue
		_ellipse(g, hand, 1.5, 1.5, skin[2])
	# cabelo longo atrás da cabeça (elfo)
	if r.hair_style == "long" and p.dir != "right":
		_rect(g, roundi(head.x - hr - 1), roundi(head.y), roundi(hr * 2.0) + 3, roundi(hr + 4.0), hair[1])
	elif r.hair_style == "long":
		_rect(g, roundi(head.x - hr), roundi(head.y), 4, roundi(hr + 5.0), hair[1])
	# orelhas pontudas (elfo)
	if r.ears:
		if p.dir == "right":
			_tri(g, Vector2(head.x - 2, head.y), Vector2(head.x + 1, head.y + 1), Vector2(head.x - 5, head.y - 5), skin[2])
		else:
			for s: float in [-1.0, 1.0]:
				_tri(g, Vector2(head.x + s * (hr - 1.0), head.y - 1), Vector2(head.x + s * (hr - 1.0), head.y + 2), Vector2(head.x + s * (hr + 4.0), head.y - 4), skin[2])
	# cabeça com volume
	_blob(g, head, Vector2(hr, hr * 1.05), skin, 0.0, 0.03, 7.0)
	# rosto
	var eye := Color("2a1e22")
	if p.dir == "down":
		_rect(g, roundi(head.x - 3), roundi(head.y + 1), 1, 2, eye)
		_rect(g, roundi(head.x + 2), roundi(head.y + 1), 1, 2, eye)
		_put(g, roundi(head.x), roundi(head.y + 3), skin[1])
	elif p.dir == "right":
		_rect(g, roundi(head.x + 3), roundi(head.y + 1), 1, 2, eye)
		_put(g, roundi(head.x + hr), roundi(head.y + 2), skin[1])
	# cabelo: topo (frente), cabeça inteira (costas), topo e nuca (lado)
	for y in range(int(head.y - hr - 1), int(head.y + hr) + 1):
		for x in range(int(head.x - hr - 1), int(head.x + hr) + 2):
			var d := Vector2(x - head.x, (y - head.y) / 1.05)
			if d.length() > hr + 0.6:
				continue
			var cover := false
			if p.dir == "down":
				cover = y < head.y - hr * 0.2
			elif p.dir == "up":
				cover = y < head.y + hr * 0.75
			else:
				cover = y < head.y - hr * 0.2 or x < head.x - 1.0
			if cover:
				var lit := _sphere(clampf(d.x / hr, -0.95, 0.95), clampf(d.y / hr, -0.95, 0.95))
				_put(g, x, y, _pick(hair, lit + noise.get_noise_2d(x * 9.0, y * 3.0) * 0.2))
	# barba (anão)
	if r.beard and p.dir != "up":
		var bc := Vector2(head.x + (2.0 if p.dir == "right" else 0.0), head.y + hr * 0.75)
		_blob(g, bc, Vector2(hr * 0.85, hr * 0.8), hair, 0.15, 0.25, 13.0)
		_rect(g, roundi(bc.x) - 1, roundi(bc.y + hr * 0.6), 2, 3, hair[1])


func _paint_robe_fire(g: Image, r: Dictionary, p: Dictionary) -> void:
	var cx: float = p.cx
	var shoulder_y: float = p.shoulder_y
	var feet: float = p.feet
	var sway: float = float(p.step) * 1.5
	var sleeve := int(r.limb) + 1
	if p.side:
		_limb(g, Vector2(cx - 1, shoulder_y + 1), Vector2(p.oh) - Vector2(0, 2), sleeve, ramp_robe)
	# corpo do robe: ombros até quase os pés, abrindo na barra
	_torso(g, p, ramp_robe, 1.0, 5.0, shoulder_y - 1.0, feet - 2.0, sway)
	var hem_half := float(p.hw) + 5.0
	_rect(g, roundi(cx - hem_half + sway), roundi(feet - 3.0), roundi(hem_half * 2.0) + 1, 2, ramp_gold[2])
	for k in range(-int(hem_half) + 2, int(hem_half) - 1, 4):
		_put(g, roundi(cx + k + sway), roundi(feet - 5.0), FIRE[1])
	_rect(g, roundi(cx - float(p.hw) - 1.0), roundi(p.hip_y - 1.0), roundi(float(p.hw) * 2.0) + 3, 2, ramp_gold[2])
	if p.dir == "down":
		for y in range(int(p.hip_y + 1.0), int(feet - 3.0)):
			_put(g, roundi(cx), y, ramp_gold[1])
	# gola alta dourada
	var head: Vector2 = p.head
	_ellipse(g, Vector2(head.x, shoulder_y), 4.0, 1.5, ramp_gold[2])
	# mangas largas com punho dourado
	if p.side:
		var wh: Vector2 = p.wh
		_limb(g, Vector2(cx + 1, shoulder_y + 1), wh - Vector2(0, 2), sleeve, ramp_robe)
		_rect(g, roundi(wh.x - sleeve / 2.0), roundi(wh.y - 3.0), sleeve, 1, ramp_gold[2])
	else:
		for hand: Vector2 in [p.wh, p.oh]:
			var sh := Vector2(cx + (-float(p.sw) if hand.x < cx else float(p.sw)), shoulder_y + 1.0)
			_limb(g, sh, hand - (hand - sh).normalized() * 2.0, sleeve, ramp_robe)
			var cuff := hand - (hand - sh).normalized() * 2.5
			_rect(g, roundi(cuff.x - sleeve / 2.0), roundi(cuff.y), sleeve, 1, ramp_gold[2])


func _paint_armor_iron(g: Image, r: Dictionary, p: Dictionary) -> void:
	var cx: float = p.cx
	var shoulder_y: float = p.shoulder_y
	var hip_y: float = p.hip_y
	var limb: int = r.limb
	# grevas e sabatons
	for foot: Vector2 in [p.lf, p.rf]:
		var knee := Vector2(cx + (foot.x - cx) * 0.8, hip_y + float(r.leg) * 0.45)
		_limb(g, knee, foot + Vector2(0, -2), limb + 1, ramp_armor)
		_rect(g, roundi(foot.x - limb / 2.0 - 1), roundi(foot.y - 2), limb + 3, 2, ramp_armor[1])
	if p.side:
		var ob: Vector2 = p.oh
		_limb(g, Vector2(cx - 1, shoulder_y + 4) + (ob - Vector2(cx - 1, shoulder_y + 4)) * 0.45, ob - Vector2(0, 1), limb, ramp_armor)
	# peitoral com crista central
	_torso(g, p, ramp_armor, 1.0, 1.0, shoulder_y, hip_y)
	if p.dir == "down":
		for y in range(int(shoulder_y + 2), int(hip_y - 1)):
			_put(g, roundi(cx), y, ramp_armor[4])
			_put(g, roundi(cx + 1), y, ramp_armor[1])
	# cinto de couro com fivela de bronze e saia de placas
	_rect(g, roundi(cx - float(p.hw) - 1.0), roundi(hip_y - 1.0), roundi(float(p.hw) * 2.0) + 3, 2, ramp_leather[1])
	_rect(g, roundi(cx - 1.0), roundi(hip_y - 1.0), 3, 2, ramp_bronze[2])
	for k in 2:
		var w := float(p.hw) + 1.0 - k
		_rect(g, roundi(cx - w), roundi(hip_y + 1.0 + k * 2.0), roundi(w * 2.0) + 1, 2, _pick(ramp_armor, 0.6 - k * 0.2))
	# braçadeiras
	var hands: Array = [p.wh] if p.side else [p.wh, p.oh]
	for hand: Vector2 in hands:
		var sh := Vector2(cx + (1.0 if p.side else (-float(p.sw) if hand.x < cx else float(p.sw))), shoulder_y + 1.0)
		_limb(g, sh + (hand - sh) * 0.62, hand - (hand - sh).normalized() * 1.5, limb, ramp_armor)
	# ombreiras volumosas com rebite
	var pads: Array = [Vector2(cx + 2.0, shoulder_y + 1.0)] if p.side else [Vector2(cx - float(p.sw), shoulder_y + 1.0), Vector2(cx + float(p.sw), shoulder_y + 1.0)]
	for pad: Vector2 in pads:
		_blob(g, pad, Vector2(4.5 + limb * 0.3, 3.5), ramp_armor, 0.0, 0.05, pad.x)
		_put(g, roundi(pad.x), roundi(pad.y), ramp_bronze[3])
	# elmo fechado (cobre o cabelo)
	var head: Vector2 = p.head
	var hr: float = p.head_r
	_blob(g, head + Vector2(0, -0.5), Vector2(hr + 1.0, hr + 1.0), ramp_armor, 0.0, 0.04, 21.0)
	if p.dir == "down":
		_rect(g, roundi(head.x - hr + 1), roundi(head.y + 1), roundi(hr * 2.0) - 1, 2, ramp_armor[0])
		_rect(g, roundi(head.x), roundi(head.y - 2), 1, 6, ramp_armor[3])
	elif p.dir == "right":
		_rect(g, roundi(head.x + 1), roundi(head.y + 1), roundi(hr), 2, ramp_armor[0])
	else:
		for y in range(int(head.y - hr - 1), int(head.y + 2)):
			_put(g, roundi(head.x), y, ramp_armor[4])
	if r.beard and p.dir != "up":
		_blob(g, head + Vector2(2.0 if p.dir == "right" else 0.0, hr + 2.0), Vector2(hr * 0.6, 2.5), _hair_ramp(r), 0.15, 0.2, 31.0)


func _paint_staff(g: Image, _r: Dictionary, p: Dictionary) -> void:
	var hand: Vector2 = p.wh
	var wdir: Vector2 = p.wdir
	var top := hand + wdir * 20.0
	_line(g, hand - wdir * 9.0, top, 2, ramp_bark[3])
	_line(g, hand - wdir * 9.0 + Vector2(1, 0), top + Vector2(1, 0), 1, ramp_bark[1])
	_ellipse(g, top + wdir * 2.0, 2.5, 2.5, FIRE[1])
	_rect(g, roundi(top.x + wdir.x * 2.0), roundi(top.y + wdir.y * 2.0) - 1, 1, 1, FIRE[3])
	var f: int = p.f
	if p.anim == "attack" and (f == 1 or f == 2):
		_ellipse(g, top + wdir * 4.0, f + 2.0, f + 2.0, FIRE[1])
		_ellipse(g, top + wdir * 4.0, f + 1.0, f + 1.0, FIRE[2])
	elif p.anim == "attack" and f == 3:
		_ellipse(g, top + wdir * 3.0, 5.0, 5.0, FIRE[2])
		_ellipse(g, top + wdir * 3.0, 3.0, 3.0, FIRE[3])


func _paint_sword(g: Image, _r: Dictionary, p: Dictionary) -> void:
	var hand: Vector2 = p.wh
	var wdir: Vector2 = p.wdir
	var reach := 22.0 if p.anim == "attack" and int(p.f) == 3 else 19.0
	var tip := hand + wdir * reach
	_line(g, hand + wdir * 2.0, tip, 3, ramp_steel[3])
	_line(g, hand + wdir * 3.0, tip, 1, Color("f4f8ff"))
	var guard := wdir.orthogonal()
	_line(g, hand + wdir * 1.5 - guard * 4.0, hand + wdir * 1.5 + guard * 4.0, 2, ramp_bronze[2])
	_line(g, hand - wdir * 2.0, hand, 2, ramp_leather[1])
	_rect(g, roundi(hand.x - wdir.x * 3.0) - 1, roundi(hand.y - wdir.y * 3.0) - 1, 2, 2, ramp_bronze[3])


## Prancha de conferência: cada raça × (corpo, robe+cajado, armadura+espada) em 5 poses,
## ampliada 3× com nearest. Vai para production/qa/evidence/.
func _save_paperdoll_preview() -> void:
	var poses := [["idle", "down", 0], ["idle", "right", 0], ["idle", "up", 0], ["walk", "down", 1], ["attack", "right", 3]]
	var outfits := [[_paint_base], [_paint_base, _paint_robe_fire, _paint_staff], [_paint_base, _paint_armor_iron, _paint_sword]]
	var img := _img(outfits.size() * poses.size() * 64, RACES.size() * 64)
	img.fill(Color("3b6b35"))
	var row := 0
	for race: String in RACES:
		var r: Dictionary = RACES[race]
		var col := 0
		for outfit: Array in outfits:
			for pose: Array in poses:
				var p := _pose(r, pose[1], pose[0], pose[2])
				for painter: Callable in outfit:
					var cell := _img(64, 64)
					painter.call(cell, r, p)
					_outline(cell)
					img.blend_rect(cell, Rect2i(0, 0, 64, 64), Vector2i(col * 64, row * 64))
				col += 1
		row += 1
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	var err := img.save_png("res://production/qa/evidence/paperdoll-01-races-gear.png")
	if err != OK:
		push_error("gen_art: falha ao salvar a prancha do paperdoll (%d)" % err)


# ------------------------------------------------------------------ layout e chão

func _path_dist(x: float, y: float) -> float:
	var a := absf(y - (700.0 + sin(x / 170.0) * 55.0))
	var b := absf(x - (820.0 + sin(y / 140.0) * 45.0))
	return minf(a, b)


func _in_clearing(p: Vector2, r: float) -> bool:
	return Vector2(p.x - CLEARING.x, (p.y - CLEARING.y) * 1.25).length() < r


func _far(p: Vector2, list: Array, min_d: float) -> bool:
	for o: Dictionary in list:
		if p.distance_to(Vector2(o.x, o.y)) < min_d:
			return false
	return true


func _in_world(p: Vector2, margin: float) -> bool:
	return p.x > margin and p.y > margin and p.x < WORLD.x - margin and p.y < WORLD.y - margin


func _tree_variant(p: Vector2) -> int:
	var r := rng.randf()
	if p.y < 450.0:
		return 1 if r < 0.6 else (0 if r < 0.85 else 2)
	return 0 if r < 0.5 else (2 if r < 0.75 else 1)


func _gen_layout() -> Dictionary:
	var trees: Array = []
	var props: Array = []
	var critters: Array = []
	var radii := [11, 7, 7]

	var centers: Array = []
	var guard := 0
	while centers.size() < 16 and guard < 3000:
		guard += 1
		var c := Vector2(rng.randf_range(60, WORLD.x - 60), rng.randf_range(80, WORLD.y - 40))
		if _in_clearing(c, 230.0) or _path_dist(c.x, c.y) < 80.0 or not _far(c, centers, 220.0):
			continue
		centers.append({"x": c.x, "y": c.y})
	for c: Dictionary in centers:
		var n := rng.randi_range(4, 8)
		var placed := 0
		for i in n * 8:
			if placed >= n:
				break
			var p := Vector2(c.x, c.y) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 110.0) * Vector2(1.0, 0.8)
			if not _in_world(p, 24.0) or _in_clearing(p, 175.0) or _path_dist(p.x, p.y) < 46.0 or not _far(p, trees, 50.0):
				continue
			var v := _tree_variant(p)
			trees.append({"x": roundi(p.x), "y": roundi(p.y), "v": v, "r": radii[v]})
			placed += 1
	for k in 900:
		var edge := rng.randi_range(0, 3)
		var p := Vector2(rng.randf_range(20, WORLD.x - 20), rng.randf_range(40, 90))
		if edge == 1:
			p = Vector2(rng.randf_range(20, WORLD.x - 20), rng.randf_range(WORLD.y - 70, WORLD.y - 10))
		elif edge == 2:
			p = Vector2(rng.randf_range(20, 90), rng.randf_range(40, WORLD.y - 10))
		elif edge == 3:
			p = Vector2(rng.randf_range(WORLD.x - 90, WORLD.x - 20), rng.randf_range(40, WORLD.y - 10))
		if _path_dist(p.x, p.y) < 46.0 or not _far(p, trees, 56.0):
			continue
		var v := _tree_variant(p)
		trees.append({"x": roundi(p.x), "y": roundi(p.y), "v": v, "r": radii[v]})

	# Vegetação na base de cada árvore: a árvore "nasce" do chão em vez de ser colocada.
	var base_kinds := ["fern", "fern", "bush", "grass_tall", "mushroom", "fern"]
	for t: Dictionary in trees:
		for i in rng.randi_range(2, 4):
			var off := Vector2(rng.randf_range(12.0, 34.0) * (1.0 if rng.randf() < 0.5 else -1.0), rng.randf_range(-6.0, 12.0))
			var p := Vector2(t.x, t.y) + off
			if _path_dist(p.x, p.y) < 22.0:
				continue
			var kind: String = base_kinds[rng.randi_range(0, base_kinds.size() - 1)]
			props.append({"kind": kind, "x": roundi(p.x), "y": roundi(p.y), "v": rng.randi_range(0, 2)})

	var patch := FastNoiseLite.new()
	patch.seed = 21
	patch.frequency = 0.012
	var placed_grass := 0
	for k in 6000:
		if placed_grass >= 280:
			break
		var p := Vector2(rng.randf_range(20, WORLD.x - 20), rng.randf_range(30, WORLD.y - 10))
		if patch.get_noise_2d(p.x, p.y) < 0.1 or _path_dist(p.x, p.y) < 24.0 or _in_clearing(p, 120.0) or not _far(p, trees, 18.0):
			continue
		props.append({"kind": "grass_tall", "x": roundi(p.x), "y": roundi(p.y), "v": rng.randi_range(0, 2)})
		placed_grass += 1

	var flower_centers: Array = []
	for k in 30:
		var c := Vector2(rng.randf_range(80, WORLD.x - 80), rng.randf_range(80, WORLD.y - 60))
		if _path_dist(c.x, c.y) < 40.0 or not _far(c, trees, 40.0):
			continue
		flower_centers.append(c)
		var color := rng.randi_range(0, 3)
		for i in rng.randi_range(3, 6):
			var p := c + Vector2(rng.randf_range(-26, 26), rng.randf_range(-16, 16))
			if _path_dist(p.x, p.y) > 20.0:
				props.append({"kind": "flowers", "x": roundi(p.x), "y": roundi(p.y), "v": color})

	var colliders: Array = trees.duplicate()
	for k in 2000:
		if props.filter(func(o: Dictionary) -> bool: return o.kind == "rock").size() >= 26:
			break
		var p := Vector2(rng.randf_range(30, WORLD.x - 30), rng.randf_range(40, WORLD.y - 20))
		var pd := _path_dist(p.x, p.y)
		if rng.randf() < 0.5 and (pd < 22.0 or pd > 36.0):
			continue
		if pd < 22.0 or _in_clearing(p, 120.0) or not _far(p, colliders, 34.0):
			continue
		var v := rng.randi_range(0, 2)
		var rock := {"kind": "rock", "x": roundi(p.x), "y": roundi(p.y), "v": v, "r": [9, 14, 5][v]}
		props.append(rock)
		colliders.append(rock)
	for spec: Array in [["log", 4, 11], ["stump", 6, 9], ["bush", 30, 0]]:
		var count := 0
		for k in 1500:
			if count >= int(spec[1]):
				break
			var p := Vector2(rng.randf_range(40, WORLD.x - 40), rng.randf_range(60, WORLD.y - 30))
			if _in_clearing(p, 150.0) or _path_dist(p.x, p.y) < 34.0 or not _far(p, colliders, 40.0):
				continue
			var item := {"kind": spec[0], "x": roundi(p.x), "y": roundi(p.y), "v": rng.randi_range(0, 2)}
			if int(spec[2]) > 0:
				item["r"] = spec[2]
				colliders.append(item)
			props.append(item)
			count += 1

	for i in 16:
		var c: Vector2 = flower_centers[i % flower_centers.size()]
		critters.append({"kind": "butterfly", "x": roundi(c.x + rng.randf_range(-20, 20)), "y": roundi(c.y), "v": i % 3})
	var rabbits := 0
	for k in 2000:
		if rabbits >= 7:
			break
		var p := Vector2(rng.randf_range(80, WORLD.x - 80), rng.randf_range(100, WORLD.y - 60))
		if _path_dist(p.x, p.y) < 30.0 or _in_clearing(p, 150.0) or not _far(p, trees, 50.0):
			continue
		critters.append({"kind": "rabbit", "x": roundi(p.x), "y": roundi(p.y), "v": 0})
		rabbits += 1
	var squirrel_trees := trees.filter(func(t: Dictionary) -> bool: return t.v != 1)
	for i in mini(6, squirrel_trees.size()):
		var t: Dictionary = squirrel_trees[rng.randi_range(0, squirrel_trees.size() - 1)]
		critters.append({"kind": "squirrel", "x": int(t.x) + rng.randi_range(-24, 24), "y": int(t.y) + rng.randi_range(6, 16), "v": 0,
			"tree": [t.x, t.y]})

	trees.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y < b.y)
	return {"world": [WORLD.x, WORLD.y], "player_start": [800, 660], "trees": trees, "props": props, "critters": critters}


func _noise_bytes(n: FastNoiseLite, w: int, h: int) -> PackedByteArray:
	var img := n.get_image(w, h)
	img.convert(Image.FORMAT_L8)
	return img.get_data()


func _gen_ground(layout: Dictionary) -> void:
	var w := WORLD.x
	var h := WORLD.y
	var big := FastNoiseLite.new()
	big.seed = 11
	big.frequency = 0.004
	var mid := FastNoiseLite.new()
	mid.seed = 12
	mid.frequency = 0.035
	var edge := FastNoiseLite.new()
	edge.seed = 13
	edge.frequency = 0.07
	var big_d := _noise_bytes(big, w, h)
	var mid_d := _noise_bytes(mid, w, h)
	var edge_d := _noise_bytes(edge, w, h)

	# Oclusão de ambiente: o chão escurece em volta da base de cada árvore.
	var ao := PackedFloat32Array()
	ao.resize(w * h)
	for t: Dictionary in layout.trees:
		var tx := int(t.x)
		var ty := int(t.y)
		for y in range(maxi(0, ty - 18), mini(h, ty + 20)):
			for x in range(maxi(0, tx - 44), mini(w, tx + 45)):
				var nx := (x - tx) / 44.0
				var ny := (y - ty - 2) / 18.0
				var d := nx * nx + ny * ny
				if d < 1.0:
					ao[y * w + x] = maxf(ao[y * w + x], 1.0 - d)

	var grass_c: Array[Color] = ramp_grass
	var dirt_c: Array[Color] = ramp_dirt
	var data := PackedByteArray()
	data.resize(w * h * 4)
	for y in h:
		for x in w:
			var i := y * w + x
			var n_big := big_d[i] / 255.0
			var n_mid := mid_d[i] / 255.0
			var hh := x * 374761393 + y * 668265263
			hh = (hh ^ (hh >> 13)) * 1274126177
			var hsh := float(hh & 0xFFFF) / 65535.0
			var pd := _path_dist(x, y) + (edge_d[i] / 255.0 - 0.5) * 14.0
			var cl := Vector2(x - CLEARING.x, (y - CLEARING.y) * 1.3).length()
			var trample := clampf(1.0 - cl / 150.0, 0.0, 1.0) * (0.6 + n_mid * 0.8)
			var col: Color
			if pd < 15.0 or trample > 0.75:
				var v := 0.15 + n_mid * 0.6 + (hsh - 0.5) * 0.25 + (n_big - 0.5) * 0.3
				if pd < 15.0 and pd > 11.5:
					v -= 0.25
				col = dirt_c[clampi(int(v * 5.0), 0, 4)]
			else:
				var v := 0.2 + n_big * 0.45 + (n_mid - 0.5) * 0.35 + (hsh - 0.5) * 0.12 - ao[i] * 0.55
				if pd < 19.0:
					v -= 0.18
				if trample > 0.5:
					v -= 0.1
				col = grass_c[clampi(int(v * 5.0), 0, 4)]
			data[i * 4] = col.r8
			data[i * 4 + 1] = col.g8
			data[i * 4 + 2] = col.b8
			data[i * 4 + 3] = 255
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)

	# Textura de lâminas de grama: realces claros e sombras curtas.
	for k in 30000:
		var x := rng.randi_range(1, w - 2)
		var y := rng.randi_range(3, h - 1)
		if _path_dist(x, y) < 18.0:
			continue
		var c := img.get_pixel(x, y)
		img.set_pixel(x, y - 1, c.lightened(0.14))
		if k % 3 == 0:
			img.set_pixel(x, y - 2, c.lightened(0.24))
		img.set_pixel(x + 1, y, c.darkened(0.12))
	# Trevos e floreszinhas em grupos.
	for g in 260:
		var cx := rng.randi_range(4, w - 5)
		var cy := rng.randi_range(4, h - 5)
		if _path_dist(cx, cy) < 22.0:
			continue
		var tint: Color = [Color("f4f1e6"), Color("f2d45c"), Color("b9a8f0"), Color("8fd27a")][g % 4]
		for s in rng.randi_range(3, 7):
			_put(img, cx + rng.randi_range(-5, 5), cy + rng.randi_range(-3, 3), tint)
	# Pedrinhas no caminho.
	for k in 1400:
		var x := rng.randi_range(2, w - 4)
		var y := rng.randi_range(2, h - 4)
		if _path_dist(x, y) > 12.0:
			continue
		_put(img, x, y, ramp_stone[4])
		_put(img, x + 1, y, ramp_stone[3])
		_put(img, x + 1, y + 1, ramp_stone[1])
		if k % 2 == 0:
			_put(img, x + 2, y + 1, ramp_stone[1])
	# Grama que invade a borda do caminho.
	for k in 4000:
		var x := rng.randi_range(2, w - 3)
		var y := rng.randi_range(3, h - 2)
		var pd := _path_dist(x, y)
		if pd < 12.0 or pd > 17.0:
			continue
		_put(img, x, y, ramp_grass[2])
		_put(img, x, y - 1, ramp_grass[3])
	_save(img, "env/ground.png")


func _save_json(layout: Dictionary) -> void:
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(layout, "\t"))
	f.close()
