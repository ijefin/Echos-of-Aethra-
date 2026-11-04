@tool
class_name PropScatter
extends Node3D
## Espalha peças (árvores, pedras, arbustos) numa área e GRAVA o resultado como
## filhos editáveis da cena ("bake"). Substitui a floresta procedural em runtime:
## o resultado é determinístico pela semente, fica salvo no .tscn e pode ser
## ajustado à mão no editor (mover, apagar, trocar peça).
##
## Algoritmo: amostragem de disco de Poisson (Bridson) na área -> filtro por ruído
## de densidade -> filtro por exclusões (retângulos, círculos, trilhas Path3D, raio
## livre em volta de marcadores, pegada de peças existentes) -> escolha ponderada da
## peça, giro Y, escala e variante, tudo a partir da mesma semente.
## Todas as coordenadas das exclusões estão no espaço LOCAL deste nó (plano XZ).

enum Shape { RECT, CIRCLE }

const BAKED_NAME: StringName = &"Baked"
const _K_CANDIDATES: int = 24

@export_group("Área")
@export var scatter_seed: int = 1
@export var shape: Shape = Shape.RECT
## RECT: largura (X) e profundidade (Z). CIRCLE: diâmetro = size.x.
@export var area_size: Vector2 = Vector2(60.0, 60.0)
@export var ground_y: float = 0.0
@export_group("Peças")
@export var scenes: Array[PackedScene] = []
## Peso de cada cena (mesma ordem de `scenes`); vazio = todas iguais.
@export var weights: PackedFloat32Array = PackedFloat32Array()
@export var min_distance: float = 3.0
@export var scale_range: Vector2 = Vector2(0.85, 1.2)
@export_group("Densidade")
@export var noise_frequency: float = 0.05
## Pontos com ruído (0..1) abaixo deste valor são descartados. 0 = sem ruído.
@export_range(0.0, 1.0, 0.01) var noise_threshold: float = 0.0
@export_group("Exclusões")
@export var exclusion_rects: Array[Rect2] = []
## Cada Vector3 = (x, z, raio) no espaço local.
@export var exclusion_circles: Array[Vector3] = []
## Path3D de trilhas/estradas a manter livres.
@export var exclusion_paths: Array[NodePath] = []
@export var trail_half_width: float = 2.0
## Nó cuja subárvore tem os marcadores a evitar (padrão: o pai deste nó).
@export var marker_root: NodePath
@export var clear_marker_kinds: Array[StringName] = [&"spawn", &"npc", &"quest", &"stair", &"secret"]
@export var marker_clear_radius: float = 4.0
## Nó cujas WorldProp existentes (casas, poço...) devem ser evitadas.
@export var avoid_props_root: NodePath
@export_group("")
@export_tool_button("Assar floresta", "Bake") var _bake_button: Callable = _bake_from_editor


## Calcula o plano de colocação, sem criar nós. Determinístico pela semente.
## Cada item: {scene: int, position: Vector3 (local), yaw: float, scale: float, variant: int}.
func compute_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	if scenes.is_empty():
		return plan
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = scatter_seed
	var noise: FastNoiseLite = null
	if noise_threshold > 0.0:
		noise = FastNoiseLite.new()
		noise.seed = scatter_seed
		noise.frequency = noise_frequency
	var excl: Dictionary = _collect_exclusions()
	for p: Vector2 in _poisson(rng):
		if noise != null and (noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5) < noise_threshold:
			continue
		if _excluded(p, excl):
			continue
		# Sorteios sempre na mesma ordem para o resultado depender só da semente.
		var scene_i: int = _pick(rng)
		var yaw: float = rng.randf_range(0.0, TAU)
		var sc: float = rng.randf_range(scale_range.x, scale_range.y)
		var variant: int = rng.randi_range(0, 7)
		plan.append({"scene": scene_i, "position": Vector3(p.x, ground_y, p.y), "yaw": yaw,
			"scale": sc, "variant": variant})
	return plan


## Instancia o plano como filhos de um nó `Baked` (substituindo o anterior).
## `scene_owner` é a raiz da cena sendo editada/empacotada; sem ele nada é salvo.
## Devolve a quantidade de peças criadas.
func bake(scene_owner: Node = null) -> int:
	clear_baked()
	var plan: Array[Dictionary] = compute_plan()
	var baked: Node3D = Node3D.new()
	baked.name = BAKED_NAME
	add_child(baked)
	if scene_owner != null:
		baked.owner = scene_owner
	for i: int in plan.size():
		var item: Dictionary = plan[i]
		var inst: Node3D = scenes[item["scene"]].instantiate() as Node3D
		if inst == null:
			continue
		baked.add_child(inst)
		inst.name = "%s_%03d" % [scenes[item["scene"]].resource_path.get_file().get_basename(), i]
		inst.position = item["position"]
		inst.rotation.y = item["yaw"]
		inst.scale = Vector3.ONE * float(item["scale"])
		if inst is WorldProp:
			var wp: WorldProp = inst as WorldProp
			var n: int = wp.get_variant_count()
			wp.variant = int(item["variant"]) % n if n > 0 else 0
		if scene_owner != null:
			inst.owner = scene_owner
	return plan.size()


## Remove o resultado assado anterior.
func clear_baked() -> void:
	var old: Node = get_node_or_null(NodePath(BAKED_NAME))
	if old != null:
		remove_child(old)
		old.free()


func _bake_from_editor() -> void:
	var n: int = bake(owner if owner != null else get_tree().edited_scene_root)
	print("PropScatter: %d peças assadas (semente %d)" % [n, scatter_seed])


# ---------------------------------------------------------------- amostragem

func _poisson(rng: RandomNumberGenerator) -> Array[Vector2]:
	var r: float = maxf(min_distance, 0.05)
	var half: Vector2 = area_size * 0.5
	var cell: float = r / sqrt(2.0)
	var cols: int = ceili(area_size.x / cell) + 1
	var rows: int = ceili(area_size.y / cell) + 1
	var grid: PackedInt32Array = PackedInt32Array()
	grid.resize(cols * rows)
	grid.fill(-1)
	var pts: Array[Vector2] = []
	var active: Array[int] = []
	var first: Vector2 = Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
	pts.append(first)
	active.append(0)
	grid[_gi(first, half, cell, cols)] = 0
	while not active.is_empty():
		var ai: int = rng.randi() % active.size()
		var base: Vector2 = pts[active[ai]]
		var found: bool = false
		for _k in _K_CANDIDATES:
			var ang: float = rng.randf_range(0.0, TAU)
			var dist: float = rng.randf_range(r, 2.0 * r)
			var c: Vector2 = base + Vector2(cos(ang), sin(ang)) * dist
			if absf(c.x) > half.x or absf(c.y) > half.y:
				continue
			if _far_enough(c, pts, grid, half, cell, cols, rows, r):
				pts.append(c)
				active.append(pts.size() - 1)
				grid[_gi(c, half, cell, cols)] = pts.size() - 1
				found = true
				break
		if not found:
			active.remove_at(ai)
	if shape == Shape.CIRCLE:
		var rad: float = area_size.x * 0.5
		pts = pts.filter(func(p: Vector2) -> bool: return p.length() <= rad)
	return pts


func _gi(p: Vector2, half: Vector2, cell: float, cols: int) -> int:
	return int((p.y + half.y) / cell) * cols + int((p.x + half.x) / cell)


func _far_enough(c: Vector2, pts: Array[Vector2], grid: PackedInt32Array, half: Vector2,
		cell: float, cols: int, rows: int, r: float) -> bool:
	var cx: int = int((c.x + half.x) / cell)
	var cy: int = int((c.y + half.y) / cell)
	for y in range(maxi(cy - 2, 0), mini(cy + 3, rows)):
		for x in range(maxi(cx - 2, 0), mini(cx + 3, cols)):
			var idx: int = grid[y * cols + x]
			if idx >= 0 and pts[idx].distance_squared_to(c) < r * r:
				return false
	return true


func _pick(rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for i: int in scenes.size():
		total += weights[i] if i < weights.size() else 1.0
	var roll: float = rng.randf() * total
	for i: int in scenes.size():
		roll -= weights[i] if i < weights.size() else 1.0
		if roll <= 0.0:
			return i
	return scenes.size() - 1


# ---------------------------------------------------------------- exclusões

func _collect_exclusions() -> Dictionary:
	var to_local: Transform3D = WorldXform.to_root(self).affine_inverse()
	var circles: Array[Vector3] = exclusion_circles.duplicate()
	var rects: Array[Rect2] = exclusion_rects.duplicate()
	var mroot: Node = get_node_or_null(marker_root) if not marker_root.is_empty() else get_parent()
	if mroot != null:
		for n: Node in WorldXform.all_nodes(mroot):
			if n is WorldMarker and (n as WorldMarker).get_kind() in clear_marker_kinds:
				var lp: Vector3 = to_local * WorldXform.to_root(n as Node3D).origin
				circles.append(Vector3(lp.x, lp.z, marker_clear_radius))
	var proot: Node = get_node_or_null(avoid_props_root) if not avoid_props_root.is_empty() else null
	if proot != null:
		for n: Node in WorldXform.all_nodes(proot):
			if n is WorldProp:
				var wp: WorldProp = n as WorldProp
				var lp: Vector3 = to_local * WorldXform.to_root(wp).origin
				var ext: Vector2 = Vector2(wp.footprint) * WorldProp.GRID_CELL * 0.5 + Vector2.ONE * 0.5
				rects.append(Rect2(Vector2(lp.x, lp.z) - ext, ext * 2.0))
	var trail_pts: Array[Vector2] = []
	for np: NodePath in exclusion_paths:
		var path: Path3D = get_node_or_null(np) as Path3D
		if path == null or path.curve == null:
			continue
		var xf: Transform3D = to_local * WorldXform.to_root(path)
		for bp: Vector3 in path.curve.get_baked_points():
			var w: Vector3 = xf * bp
			trail_pts.append(Vector2(w.x, w.z))
	return {"circles": circles, "rects": rects, "trail": trail_pts}


func _excluded(p: Vector2, excl: Dictionary) -> bool:
	for r: Rect2 in excl["rects"]:
		if r.has_point(p):
			return true
	for c: Vector3 in excl["circles"]:
		if Vector2(c.x, c.y).distance_squared_to(p) <= c.z * c.z:
			return true
	var tw2: float = trail_half_width * trail_half_width
	var trail: Array[Vector2] = excl["trail"]
	for i: int in trail.size():
		if trail[i].distance_squared_to(p) <= tw2:
			return true
		if i > 0 and _seg_dist2(p, trail[i - 1], trail[i]) <= tw2:
			return true
	return false


func _seg_dist2(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	if len2 < 0.0001:
		return p.distance_squared_to(a)
	var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_squared_to(a + ab * t)
