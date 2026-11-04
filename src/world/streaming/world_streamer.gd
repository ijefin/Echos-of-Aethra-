class_name WorldStreamer
extends Node
## Carrega e descarrega cenas de região conforme a posição do foco (jogador/câmera).
## Injetável: recebe o catálogo, o provedor de foco e (opcionalmente) um WorldStyle.
## Carrega sem travar o frame (`ResourceLoader.load_threaded_request`) e usa histerese:
## carrega a `load_radius`, só descarrega além de `unload_radius`.
##
## Uso:
##   var s := WorldStreamer.new()
##   s.setup(WorldCatalog.load_file(), func() -> Vector3: return player.global_position)
##   add_child(s)
##   s.region_loaded.connect(_on_region_loaded)

signal region_loaded(region_id: StringName, region: Node3D)
signal region_unloaded(region_id: StringName)
signal region_failed(region_id: StringName)

## Intervalo entre reavaliações automáticas do foco (segundos).
@export var update_interval_s: float = 0.25

var catalog: WorldCatalog
## Callable() -> Vector3 com a posição do foco. Se vazio, chame `update_focus` à mão.
var focus_provider: Callable = Callable()
## Nó que recebe as regiões carregadas (padrão: o próprio streamer).
var host: Node
var style: WorldStyle

var _loaded: Dictionary = {}    # StringName -> Node3D
var _pending: Dictionary = {}   # StringName -> caminho da cena
var _failed: Dictionary = {}    # StringName -> true (não tenta de novo até o foco se afastar)
var _last_focus: Vector3 = Vector3.ZERO
var _accum: float = 0.0


## Injeta as dependências.
func setup(p_catalog: WorldCatalog, p_focus_provider: Callable = Callable(),
		p_host: Node = null, p_style: WorldStyle = null) -> void:
	catalog = p_catalog
	focus_provider = p_focus_provider
	host = p_host
	style = p_style


func _process(delta: float) -> void:
	_accum += delta
	if focus_provider.is_valid() and _accum >= update_interval_s:
		_accum = 0.0
		update_focus(focus_provider.call())
	poll()


## Reavalia o que carregar/descartar para um foco. Chamável direto (testes, servidor).
func update_focus(focus: Vector3) -> void:
	_last_focus = focus
	if catalog == null:
		return
	for id: StringName in catalog.regions:
		var info: Dictionary = catalog.regions[id]
		var dist: float = catalog.distance_to(id, focus)
		if _loaded.has(id):
			if dist > float(info["unload_radius"]):
				_unload(id)
		elif _pending.has(id):
			pass
		elif dist <= float(info["load_radius"]):
			if not _failed.has(id):
				_request(id, String(info["scene"]))
		elif dist > float(info["unload_radius"]):
			_failed.erase(id)


## Verifica as cargas em andamento e instancia as que terminaram.
func poll() -> void:
	for id: StringName in _pending.keys():
		var path: String = _pending[id]
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_pending.erase(id)
				_finish(id, ResourceLoader.load_threaded_get(path) as PackedScene)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_pending.erase(id)
				_failed[id] = true
				push_error("WorldStreamer: falha ao carregar a região '%s' (%s)" % [id, path])
				region_failed.emit(id)


## Regiões carregadas (ids).
func loaded_ids() -> Array:
	return _loaded.keys()


## Regiões com carga em andamento (ids).
func pending_ids() -> Array:
	return _pending.keys()


func is_loaded(region_id: StringName) -> bool:
	return _loaded.has(region_id)


## Nó raiz de uma região carregada (null se não carregada).
func get_region(region_id: StringName) -> Node3D:
	return _loaded.get(region_id)


func _request(id: StringName, path: String) -> void:
	var err: Error = ResourceLoader.load_threaded_request(path)
	if err != OK:
		_failed[id] = true
		push_error("WorldStreamer: não foi possível iniciar a carga de '%s' (%s)" % [path, error_string(err)])
		region_failed.emit(id)
		return
	_pending[id] = path


func _finish(id: StringName, scene: PackedScene) -> void:
	# O foco pode ter se afastado enquanto carregava: descarta sem instanciar.
	if scene == null or catalog.distance_to(id, _last_focus) > float(catalog.regions[id]["unload_radius"]):
		return
	var region: Node3D = scene.instantiate() as Node3D
	if region == null:
		push_error("WorldStreamer: a cena da região '%s' não tem raiz Node3D" % id)
		_failed[id] = true
		region_failed.emit(id)
		return
	region.position = catalog.regions[id]["origin"]
	if style != null:
		style.apply_to_tree(region)
	(host if host != null else self).add_child(region)
	_loaded[id] = region
	region_loaded.emit(id, region)


func _unload(id: StringName) -> void:
	var region: Node3D = _loaded[id]
	_loaded.erase(id)
	if is_instance_valid(region):
		region.get_parent().remove_child(region)
		region.queue_free()
	region_unloaded.emit(id)
