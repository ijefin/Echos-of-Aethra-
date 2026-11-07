# Composição do mundo: regiões (data/world_regions.json), trilhas, Estrada Velha, serra
# (campo de distância do que é aberto), clareiras reservadas, bosques agrupados e escolha
# dos pontos de árvore (grade com jitter + distância mínima por hash espacial). Só decide
# ONDE; os modelos de árvore continuam em pixel3d_forest.gd.
extends RefCounted

const Camps := preload("res://src/game/pixel3d_camps.gd")
const Dressing := preload("res://src/game/pixel3d_dressing.gd")
const DATA := "res://src/game/data/world_regions.json"
const HALF := 100.0

## Clareiras fixas da floresta inicial: [centro, raio]. Hunts, marcos e segredos entram
## a partir do JSON. O contorno é irregular (ver clearing_dist), o raio é o médio.
const CLEARINGS := [
	[Vector2(0, 0), 7.5],          # chegada do jogador / praça
	[Vector2(-14, -25), 6.0],      # Nessa
	[Vector2(-38, -28.5), 6.5],    # boca da Gruta das Raízes
	[Vector2(36, 33.0), 6.5],      # boca da segunda caverna
	# campinas abertas para lutar e respirar entre os bosques
	[Vector2(22, -36), 8.0],
	[Vector2(-46, -6), 7.0],
	[Vector2(34, -2), 7.5],
	[Vector2(-44, 46), 7.5],
	[Vector2(14, 42), 7.0],
	[Vector2(-8, -45), 6.5],
	[Vector2(48, -44), 6.5],
	[Vector2(-26, 52), 6.0],
	# campinas das regiões novas
	[Vector2(-72, -40), 6.5],
	[Vector2(70, 40), 7.0],
	[Vector2(-10, -78), 6.0],
	[Vector2(45, -82), 6.0],
]

## Trilhas de terra novas (polilinhas) ligando a floresta às regiões.
const TRAILS := [
	# leste: estrada → ponte do leste → Covil → passo leste → Vale → estrada do norte
	[Vector2(75, 2.0), Vector2(75, -11.3), Vector2(77, -20), Vector2(80, -28), Vector2(70, -39), Vector2(60, -50),
		Vector2(54, -58), Vector2(52, -67), Vector2(48, -76), Vector2(36, -82), Vector2(20, -83), Vector2(4, -82), Vector2(-2.4, -82)],
	# Vale → Torre de Vigia
	[Vector2(-2.4, -82), Vector2(-14, -83), Vector2(-24, -80.5), Vector2(-30, -80.5)],
	# estrada → Árvore-Mãe
	[Vector2(80, 2.9), Vector2(81, 9), Vector2(82, 13.5)],
	# estrada do sul → caçada do Charco
	[Vector2(1.2, 72), Vector2(10, 75), Vector2(17, 77), Vector2(24, 78)],
	# estrada do sul → Estátua Afundada
	[Vector2(2.7, 76), Vector2(-8, 78.5), Vector2(-21, 78)],
]
## Estrada Velha: calçamento antigo, do pé da serra até a Estátua Afundada.
const OLD_ROAD := [Vector2(-80, -56), Vector2(-80, -30), Vector2(-80, -17.3), Vector2(-80, 5), Vector2(-80, 10),
	Vector2(-79, 25), Vector2(-80, 40), Vector2(-82, 55), Vector2(-74, 68), Vector2(-58, 76), Vector2(-40, 79), Vector2(-36, 79)]

## Serra: o que é ABERTO dentro da faixa norte (o resto é rocha).
const SERRA_Z := -60.0
const VALLEY_C := Vector2(2, -82)
const VALLEY_H := Vector2(60, 8)
const EAST_PASS := [Vector2(56, -54), Vector2(53, -62), Vector2(52, -67), Vector2(48, -77)]
const POCKET_C := Vector2(-46, -68)
const POCKET_R := 3.8
const POCKET_DOOR := [Vector2(-48.5, -58.0), Vector2(-46.6, -65.0)]

const GRID := 2.0             # passo da grade de candidatos (m)
const SPACING_GROVE := 2.35   # distância mínima dentro do bosque
const SPACING_EDGE := 3.1     # na borda das clareiras/trilhas
const SPACING_LONE := 4.5     # árvore solitária no campo
const LONE_CHANCE := 0.03
const BORDER := 95.0          # dali até a borda: mata fechada escondendo a parede

static var _groves: FastNoiseLite
static var _meadow: FastNoiseLite
static var _data: Dictionary
static var _clearings: Array


static func _noises() -> void:
	if _groves != null:
		return
	_groves = FastNoiseLite.new()
	_groves.seed = 72
	_groves.frequency = 0.036
	_meadow = FastNoiseLite.new()
	_meadow.seed = 913
	_meadow.frequency = 0.02


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return _data


static func v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# ------------------------------------------------------------------ regiões

## Região do ponto (dicionário do JSON). Floresta no meio; bordas por faixa.
static func region_at(p: Vector2) -> Dictionary:
	var regions: Array = data().regions
	var id := "floresta"
	if p.y < -60.0:
		id = "serra"
	elif p.y > 60.0:
		id = "charco"
	elif p.x > 60.0:
		id = "bosque"
	elif p.x < -60.0:
		id = "ruinas"
	for r: Dictionary in regions:
		if r.id == id:
			return r
	return regions[0]


## Nome para o chat ("na Serra do Vigia" etc.), com sub-áreas e pontos famosos.
static func region_name(p: Vector2) -> String:
	for l: Dictionary in data().landmarks:
		if v2(l.center).distance_to(p) < float(l.radius) + 4.0:
			return ("perto do " if String(l.name).begins_with("Posto") else "perto da ") + String(l.name)
	for h: Dictionary in data().hunts:
		if v2(h.center).distance_to(p) < float(h.radius) + 2.0:
			return "na caçada " + ("do " if h.id != "estrada_velha" else "da ") + String(h.name)
	for s: Dictionary in data().subareas:
		if p.x >= float(s.min[0]) and p.x <= float(s.max[0]) and p.y >= float(s.min[1]) and p.y <= float(s.max[1]):
			return ("no " if String(s.name).begins_with("Vale") else "na ") + String(s.name)
	var r := region_at(p)
	var name := String(r.name)
	if name.begins_with("Ruínas"):
		return "nas " + name
	return ("no " if name.begins_with("Bosque") or name.begins_with("Charco") else "na ") + name


# ------------------------------------------------------------------ trilhas e estrada

static func _poly_dist(p: Vector2, pts: Array) -> float:
	var d := INF
	for i in pts.size() - 1:
		d = minf(d, Camps.segment_distance(p, pts[i], pts[i + 1]))
	return d


## Distância até as trilhas novas e a Estrada Velha (mesma convenção do path_dist).
static func trail_dist(p: Vector2) -> float:
	var d := old_road_dist(p) - 0.4
	for t: Array in TRAILS:
		d = minf(d, _poly_dist(p, t) + 0.3)
	return d


static func old_road_dist(p: Vector2) -> float:
	return _poly_dist(p, OLD_ROAD)


## Segmentos (a.xy, b.xy) para o shader do chão.
static func trail_segments() -> PackedVector4Array:
	var out := PackedVector4Array()
	for t: Array in TRAILS:
		for i in t.size() - 1:
			var a: Vector2 = t[i]
			var b: Vector2 = t[i + 1]
			out.append(Vector4(a.x, a.y, b.x, b.y))
	return out


static func road_segments() -> PackedVector4Array:
	var out := PackedVector4Array()
	for i in OLD_ROAD.size() - 1:
		var a: Vector2 = OLD_ROAD[i]
		var b: Vector2 = OLD_ROAD[i + 1]
		out.append(Vector4(a.x, a.y, b.x, b.y))
	return out


static func configure_terrain(material: ShaderMaterial) -> void:
	var trails := trail_segments()
	var road := road_segments()
	var pools := PackedVector3Array()
	for pool: Vector3 in Dressing.POOLS:
		pools.append(pool)
	material.set_shader_parameter("world_trails", trails)
	material.set_shader_parameter("world_trail_count", trails.size())
	material.set_shader_parameter("old_road", road)
	material.set_shader_parameter("old_road_count", road.size())
	material.set_shader_parameter("pools", pools)
	material.set_shader_parameter("pool_count", pools.size())


# ------------------------------------------------------------------ serra

static func _box_dist(p: Vector2, c: Vector2, h: Vector2) -> float:
	var d := (p - c).abs() - h
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0)


## < 0 = chão aberto; > 0 = dentro da rocha da serra (quanto mais, mais fundo no maciço).
static func open_dist(p: Vector2) -> float:
	if p.y > SERRA_Z + 6.0:
		return -INF
	var wob := 2.0 * sin(p.x * 0.13) + 1.2 * sin(p.x * 0.31 + 1.0)
	var d := (SERRA_Z + wob) - p.y
	# desfiladeiro seguindo a estrada norte-sul
	if p.y > -84.0:
		d = minf(d, absf(p.x - sin(p.y * 0.18) * 3.0) - 4.2 + 0.6 * sin(p.y * 0.7))
	d = minf(d, _poly_dist(p, EAST_PASS) - 3.8)
	var vw := 1.5 * sin(p.x * 0.21) + 1.0 * sin(p.x * 0.47 + 2.0)
	d = minf(d, _box_dist(p, VALLEY_C, VALLEY_H + Vector2(0, vw * 0.5)) - 1.5)
	d = minf(d, p.distance_to(POCKET_C) - POCKET_R)
	d = minf(d, Camps.segment_distance(p, POCKET_DOOR[0], POCKET_DOOR[1]) - 1.05)
	return d


static func mountain(p: Vector2) -> bool:
	return open_dist(p) > 0.0


## Chão onde bicho e monstro podem andar (sem água, sem rocha da serra, dentro do mapa).
static func walkable(p: Vector2, clearance := 1.0) -> bool:
	return absf(p.x) < BORDER - 1.0 and absf(p.y) < BORDER - 1.0 and open_dist(p) < -clearance and Dressing.water_dist(p) > clearance


# ------------------------------------------------------------------ clareiras

static func clearings() -> Array:
	if _clearings.is_empty():
		_clearings = CLEARINGS.duplicate()
		for h: Dictionary in data().hunts:
			_clearings.append([v2(h.center), float(h.radius)])
		for l: Dictionary in data().landmarks:
			_clearings.append([v2(l.center), float(l.radius)])
		for s: Dictionary in data().secrets:
			_clearings.append([v2(s.position), 3.6])
	return _clearings


## Distância com sinal até a clareira mais próxima (< 0 dentro), contorno ondulado.
static func clearing_dist(p: Vector2) -> float:
	var d := INF
	for c: Array in clearings():
		var center: Vector2 = c[0]
		var r: float = c[1]
		var v := p - center
		if v.length_squared() > (r * 1.3 + 8.0) * (r * 1.3 + 8.0):
			d = minf(d, v.length() - r * 1.25)
			continue
		var a := v.angle()
		var wobble := 1.0 + 0.16 * sin(3.0 * a + center.x) + 0.09 * sin(5.0 * a + center.y)
		d = minf(d, v.length() - r * wobble)
	return d


## Distância com sinal até tudo que não pode ter árvore. < 0 = reservado.
static func reserve_dist(p: Vector2, path_d: float) -> float:
	var d := clearing_dist(p)
	d = minf(d, path_d - 2.6)
	d = minf(d, Dressing.water_dist(p) - 1.8)
	d = minf(d, Dressing.plaza_dist(p) - 2.3)
	d = minf(d, Dressing.cave_dist(p) - 2.5)
	d = minf(d, Camps.clearing_distance(p))
	d = minf(d, open_dist(p) * -1.0 - 1.2)  # pé da serra livre (rocha cuida da borda)
	return d


## 0..1: quanto o ponto pertence a um bosque fechado.
static func grove(p: Vector2) -> float:
	_noises()
	var g := _groves.get_noise_2d(p.x, p.y) + 0.12 * _meadow.get_noise_2d(p.x, p.y)
	return smoothstep(-0.2, 0.08, g)


# ------------------------------------------------------------------ árvores

## Planeja as árvores: {"trees": [[Vector2, escala, região]], "bushes": [Vector2]}.
## `path_dist` = Callable(Vector2) -> float (trilhas do demo).
static func plan_trees(half: float, max_trees: int, rng: RandomNumberGenerator, path_dist: Callable) -> Dictionary:
	_noises()
	var trees: Array = []
	var bushes: Array = []
	var buckets := {}
	var cells: Array[Vector2] = []
	var n := int(half * 2.0 / GRID)
	for ix in n:
		for iz in n:
			cells.append(Vector2(-half + (ix + 0.5) * GRID, -half + (iz + 0.5) * GRID))
	# a mata da borda entra primeiro: o limite de árvores nunca abre buraco na parede
	var border: Array[Vector2] = []
	var inner: Array[Vector2] = []
	for c in cells:
		if (absf(c.x) > BORDER or c.y > BORDER) and c.y > SERRA_Z:
			border.append(c)
		else:
			inner.append(c)
	_shuffle(inner, rng)
	cells = border + inner
	for cell in cells:
		if trees.size() >= max_trees:
			break
		var p := cell + Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45)) * GRID
		if absf(p.x) > half - 0.8 or absf(p.y) > half - 0.8:
			continue
		var reg := region_at(p)
		var at_border := (absf(p.x) > BORDER or p.y > BORDER) and p.y > SERRA_Z
		var r := reserve_dist(p, path_dist.call(p))
		if r < 0.0 and not (at_border and path_dist.call(p) > 2.0 and Dressing.water_dist(p) > 1.0):
			continue
		var g := grove(p)
		var base: float = float(reg.tree_base)
		var edge := smoothstep(0.0, 4.5, r)        # 0 colado na clareira, 1 longe
		var chance := g * lerpf(0.55, 1.0, edge) * base
		var spacing := lerpf(SPACING_EDGE, SPACING_GROVE, edge)
		if reg.id == "bosque":
			spacing *= 1.25  # copas grandes
		if g < 0.25:
			chance = LONE_CHANCE * (2.0 if reg.id == "charco" else 1.0)
			spacing = SPACING_LONE
		if at_border:
			chance = 1.0
			spacing = 2.6
		if rng.randf() > chance:
			# borda do bosque sem árvore: arbusto
			if g > 0.12 and g < 0.6 and r > 0.4 and rng.randf() < 0.35 * base:
				bushes.append(p)
			continue
		if _crowded(buckets, p, spacing):
			continue
		var key := Vector2i(floori(p.x / 3.0), floori(p.y / 3.0))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append([p, spacing])
		var size_k := lerpf(0.72, 1.0, edge) * rng.randf_range(0.85, 1.15)
		if reg.id == "bosque":
			size_k *= rng.randf_range(1.25, 1.6)
		trees.append([p, size_k, String(reg.id)])
		if edge < 0.6 and rng.randf() < 0.5:
			bushes.append(p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.0, 1.6))
	return {"trees": trees, "bushes": bushes}


static func _shuffle(a: Array[Vector2], rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := a[i]
		a[i] = a[j]
		a[j] = tmp


static func _crowded(buckets: Dictionary, p: Vector2, spacing: float) -> bool:
	var k := Vector2i(floori(p.x / 3.0), floori(p.y / 3.0))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var bucket: Array = buckets.get(k + Vector2i(dx, dz), [])
			for e: Array in bucket:
				var q: Vector2 = e[0]
				var sep := (spacing + float(e[1])) * 0.5
				if p.distance_squared_to(q) < sep * sep:
					return true
	return false


# ------------------------------------------------------------------ teste de alcance

## Pontos que o test_world_reach precisa alcançar a pé a partir da chegada: [nome, xz].
static func reach_targets() -> Array:
	var out: Array = []
	for i in Camps.CENTERS.size():
		out.append(["acampamento %d" % (i + 1), Camps.CENTERS[i] + Vector2(0, 3.5)])
	out.append(["Nessa", Vector2(-14, -23)])
	out.append(["boca Gruta das Raízes", Vector2(-38, -30.5)])
	out.append(["boca 2ª caverna", Vector2(36, 31.5)])
	out.append(["região Serra do Vigia (Vale)", Vector2(0, -80)])
	out.append(["região Bosque Antigo", Vector2(78, 0)])
	out.append(["região Charco das Brumas", Vector2(0, 85)])
	out.append(["região Ruínas da Estrada Velha", Vector2(-80, -10)])
	for h: Dictionary in data().hunts:
		out.append(["hunt " + String(h.name), v2(h.center)])
	for s: Dictionary in data().secrets:
		out.append(["segredo " + String(s.id), v2(s.position)])
	for l: Dictionary in data().landmarks:
		var c := v2(l.center)
		if l.id == "torre_vigia":
			c = Vector2(-30, -80.5)  # porta da torre
		elif l.id == "estatua_afundada":
			c = Vector2(-30, 74.5)   # margem da poça
		elif l.id == "arvore_mae":
			c = Vector2(82, 15)      # pé da árvore
		out.append(["marco " + String(l.name), c])
	return out


## Pontos que NÃO podem ser alcançados (dentro da rocha da serra / cordilheira).
static func blocked_targets() -> Array:
	return [["contraforte oeste", Vector2(-30, -67)], ["contraforte leste", Vector2(30, -67)],
		["cordilheira", Vector2(0, -97)], ["maciço noroeste", Vector2(-80, -80)]]
