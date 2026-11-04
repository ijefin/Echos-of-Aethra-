# PROTOTYPE - NOT FOR PRODUCTION
# Composição do mundo: clareiras reservadas, bosques agrupados e escolha dos pontos de
# árvore (grade com jitter + distância mínima por hash espacial). Só decide ONDE; os
# modelos continuam em pixel3d_forest.gd.
extends RefCounted

const Camps := preload("res://prototypes/pixel3d/pixel3d_camps.gd")
const Dressing := preload("res://prototypes/pixel3d/pixel3d_dressing.gd")

## Clareiras fixas da floresta inicial: [centro, raio]. O contorno é irregular (ver
## clearing_dist), então o raio é o médio.
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
]

const GRID := 2.0             # passo da grade de candidatos (m)
const SPACING_GROVE := 2.35   # distância mínima dentro do bosque
const SPACING_EDGE := 3.1     # na borda das clareiras/trilhas
const SPACING_LONE := 4.5     # árvore solitária no campo
const LONE_CHANCE := 0.03

static var _groves: FastNoiseLite
static var _meadow: FastNoiseLite


static func _noises() -> void:
	if _groves != null:
		return
	_groves = FastNoiseLite.new()
	_groves.seed = 72
	_groves.frequency = 0.036
	_meadow = FastNoiseLite.new()
	_meadow.seed = 913
	_meadow.frequency = 0.02


## Distância com sinal até a clareira mais próxima (< 0 dentro), contorno ondulado.
static func clearing_dist(p: Vector2) -> float:
	var d := INF
	for c: Array in CLEARINGS:
		var center: Vector2 = c[0]
		var r: float = c[1]
		var v := p - center
		var a := v.angle()
		var wobble := 1.0 + 0.16 * sin(3.0 * a + center.x) + 0.09 * sin(5.0 * a + center.y)
		d = minf(d, v.length() - r * wobble)
	return d


## Distância com sinal até tudo que não pode ter árvore (trilha, água, praça, campos,
## cavernas, clareiras). < 0 = reservado.
static func reserve_dist(p: Vector2, path_d: float) -> float:
	var d := clearing_dist(p)
	d = minf(d, path_d - 2.6)
	d = minf(d, Dressing.water_dist(p) - 1.8)
	d = minf(d, Dressing.plaza_dist(p) - 2.3)
	d = minf(d, Dressing.cave_dist(p) - 2.5)
	d = minf(d, Camps.clearing_distance(p))
	return d


## 0..1: quanto o ponto pertence a um bosque fechado.
static func grove(p: Vector2) -> float:
	_noises()
	var g := _groves.get_noise_2d(p.x, p.y) + 0.12 * _meadow.get_noise_2d(p.x, p.y)
	return smoothstep(-0.2, 0.08, g)


## Planeja as árvores: devolve {"trees": [[Vector2, escala]], "bushes": [Vector2]}.
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
	# ordem embaralhada: sem fileiras visíveis quando a distância mínima corta vizinhos
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	for cell in cells:
		if trees.size() >= max_trees:
			break
		var p := cell + Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.45, 0.45)) * GRID
		if absf(p.x) > half - 1.5 or absf(p.y) > half - 1.5:
			continue
		var r := reserve_dist(p, path_dist.call(p))
		if r < 0.0:
			continue
		var g := grove(p)
		var edge := smoothstep(0.0, 4.5, r)        # 0 colado na clareira, 1 longe
		var chance := g * lerpf(0.55, 1.0, edge)
		var spacing := lerpf(SPACING_EDGE, SPACING_GROVE, edge)
		if g < 0.25:
			chance = LONE_CHANCE
			spacing = SPACING_LONE
		if rng.randf() > chance:
			# borda do bosque sem árvore: arbusto
			if g > 0.12 and g < 0.6 and r > 0.4 and rng.randf() < 0.35:
				bushes.append(p)
			continue
		if _crowded(buckets, p, spacing):
			continue
		var key := Vector2i(floori(p.x / 3.0), floori(p.y / 3.0))
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append([p, spacing])
		var size_k := lerpf(0.72, 1.0, edge) * rng.randf_range(0.85, 1.15)
		trees.append([p, size_k])
		if edge < 0.6 and rng.randf() < 0.5:
			bushes.append(p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.0, 1.6))
	return {"trees": trees, "bushes": bushes}


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


## Pontos que o test_world_reach precisa alcançar a pé a partir da chegada: [nome, xz].
static func reach_targets() -> Array:
	var out: Array = []
	for i in Camps.CENTERS.size():
		out.append(["acampamento %d" % (i + 1), Camps.CENTERS[i] + Vector2(0, 3.5)])
	out.append(["Nessa", Vector2(-14, -23)])
	out.append(["boca Gruta das Raízes", Vector2(-38, -30.5)])
	out.append(["boca 2ª caverna", Vector2(36, 31.5)])
	return out
