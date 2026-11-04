class_name WorldCatalog
extends RefCounted
## Catálogo de regiões do mundo, lido de dados (`res://data/world/regions.json`).
## Formato:
## {
##   "load_radius": 70.0, "unload_radius": 90.0,          // histerese (metros)
##   "regions": { "<id>": { "scene": "res://...tscn", "origin": [x,y,z],
##        "bounds_center": [x,y,z], "bounds_size": [x,y,z],   // locais à região
##        "load_radius": 70.0, "unload_radius": 90.0 } }      // opcionais por região
## }
## `unload_radius` deve ser maior que `load_radius`; a diferença evita carregar/descarregar
## repetidamente quando o foco anda na fronteira.

const DEFAULT_PATH: String = "res://data/world/regions.json"

var load_radius: float = 70.0
var unload_radius: float = 90.0
## id (StringName) -> {scene: String, origin: Vector3, rect: Rect2 (XZ no mundo), load_radius, unload_radius}
var regions: Dictionary = {}


## Lê o catálogo de um arquivo JSON.
static func load_file(path: String = DEFAULT_PATH) -> WorldCatalog:
	return from_dict(JsonData.load_dict(path))


## Monta o catálogo a partir de um Dictionary já lido (útil em testes).
static func from_dict(data: Dictionary) -> WorldCatalog:
	var cat: WorldCatalog = WorldCatalog.new()
	cat.load_radius = float(data.get("load_radius", cat.load_radius))
	cat.unload_radius = float(data.get("unload_radius", cat.unload_radius))
	var raw: Dictionary = data.get("regions", {})
	for id: String in raw:
		var r: Dictionary = raw[id]
		var origin: Vector3 = _vec3(r.get("origin", [0, 0, 0]))
		var center: Vector3 = _vec3(r.get("bounds_center", [0, 0, 0]))
		var size: Vector3 = _vec3(r.get("bounds_size", [100, 40, 100]))
		var lr: float = float(r.get("load_radius", cat.load_radius))
		var ur: float = maxf(float(r.get("unload_radius", cat.unload_radius)), lr + 1.0)
		cat.regions[StringName(id)] = {
			"scene": String(r.get("scene", "")), "origin": origin,
			"rect": Rect2(Vector2(origin.x + center.x - size.x * 0.5, origin.z + center.z - size.z * 0.5),
				Vector2(size.x, size.z)),
			"load_radius": lr, "unload_radius": ur}
	return cat


## Distância (plano XZ) do ponto até o retângulo da região; 0 se estiver dentro.
func distance_to(region_id: StringName, point: Vector3) -> float:
	if not regions.has(region_id):
		return INF
	var rect: Rect2 = regions[region_id]["rect"]
	var dx: float = maxf(maxf(rect.position.x - point.x, point.x - rect.end.x), 0.0)
	var dz: float = maxf(maxf(rect.position.y - point.z, point.z - rect.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)


static func _vec3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
