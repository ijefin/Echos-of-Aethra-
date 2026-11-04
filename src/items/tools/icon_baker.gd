class_name IconBaker
extends Node
## Renderiza o modelo 3D de um item num SubViewport e devolve o ícone da bolsa
## (fundo transparente, pixels duros, contorno de 1 px de arte, escala inteira).
## Câmera ortográfica 3/4 padrão e luz fixa (guia pixel3d: sol quente, ambiente roxo,
## toon). Tudo vem de `settings` (bloco "bake" de assets/items/item_models.json).
## Precisa de GPU: rode com janela (não --headless). Uso típico em
## `bake_item_icons.gd`; também serve para ferramentas do editor.
##
##   var baker: IconBaker = preload("res://src/items/tools/icon_baker.tscn").instantiate()
##   baker.settings = catalog.art.bake
##   add_child(baker)
##   var img := await baker.bake(def.get_model(), def.icon_view, def.tint)

## Padrões usados quando `settings` não traz a chave.
const DEFAULTS := {
	"size": 64, "art_px": 32, "yaw": 35.0, "pitch": -30.0, "roll": 0.0, "zoom": 1.0,
	"margin": 0.06, "alpha_cut": 0.5, "outline": [0.07, 0.05, 0.1, 1.0],
	"light_color": [1.0, 0.92, 0.78], "light_energy": 1.1, "light_rotation": [-52.0, -38.0, 0.0],
	"ambient_color": [0.42, 0.36, 0.64], "ambient_energy": 0.6, "toon": true,
}

## Parâmetros do bake (chaves de DEFAULTS). Ler antes de entrar na árvore.
var settings: Dictionary = {}

var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var px := int(_get_setting("art_px"))
	_vp.size = Vector2i(px, px)
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _color("ambient_color")
	env.ambient_light_energy = float(_get_setting("ambient_energy"))
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	var rot: Array = _get_setting("light_rotation")
	sun.rotation_degrees = Vector3(float(rot[0]), float(rot[1]), float(rot[2]))
	sun.light_color = _color("light_color")
	sun.light_energy = float(_get_setting("light_energy"))
	_vp.add_child(sun)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_vp.add_child(_cam)
	_cam.current = true


## Renderiza `model` e devolve o ícone final (`size` × `size`, RGBA8).
## `view` sobrepõe yaw/pitch/roll/zoom/offset; `tint` multiplica a cor dos materiais.
func bake(model: PackedScene, view: Dictionary = {}, tint: Color = Color.WHITE) -> Image:
	var raw := await render_raw(model, view, tint)
	return stylize(raw, float(_get_setting("alpha_cut")), _color("outline"), int(_get_setting("size")))


## Renderiza na resolução de arte (`art_px`), sem pós-processo.
func render_raw(model: PackedScene, view: Dictionary = {}, tint: Color = Color.WHITE) -> Image:
	for c in _pivot.get_children():
		c.free()
	var inst := model.instantiate()
	_pivot.add_child(inst)
	_restyle(inst, tint)
	var v := settings.duplicate()
	v.merge(view, true)
	_pivot.rotation_degrees = Vector3(0.0, float(v.get("yaw", DEFAULTS.yaw)), 0.0)
	var cam_basis := Basis.from_euler(Vector3(deg_to_rad(float(v.get("pitch", DEFAULTS.pitch))), 0.0,
			deg_to_rad(float(v.get("roll", DEFAULTS.roll)))))
	var off: Array = v.get("offset", [0.0, 0.0])
	frame_camera(_cam, cam_basis, world_points(inst), float(v.get("margin", DEFAULTS.margin)),
			float(v.get("zoom", DEFAULTS.zoom)), Vector2(float(off[0]), float(off[1])))
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Cantos (globais) das AABBs de toda malha sob `root`.
static func world_points(root: Node) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is VisualInstance3D and n is GeometryInstance3D:
			var vi := n as VisualInstance3D
			var box := vi.get_aabb()
			for i in 8:
				pts.append(vi.global_transform * box.get_endpoint(i))
	return pts


## Posiciona a câmera ortográfica `cam` (orientação `cam_basis`) para enquadrar `pts`
## com `margin` (fração do quadro) de folga, `zoom` (>1 aproxima) e `offset` (fração).
static func frame_camera(cam: Camera3D, cam_basis: Basis, pts: PackedVector3Array, margin: float,
		zoom: float = 1.0, offset: Vector2 = Vector2.ZERO) -> void:
	if pts.is_empty():
		pts = PackedVector3Array([Vector3.ZERO])
	var inv := cam_basis.inverse()
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for p in pts:
		var q := inv * p
		lo = lo.min(q)
		hi = hi.max(q)
	var extent := maxf(maxf(hi.x - lo.x, hi.y - lo.y), 0.01)
	var size := extent / maxf(1.0 - 2.0 * margin, 0.1) / maxf(zoom, 0.01)
	var center := (lo + hi) * 0.5 + Vector3(offset.x, offset.y, 0.0) * size
	cam.size = size
	cam.near = 0.05
	cam.far = (hi.z - lo.z) + 4.0
	cam.transform = Transform3D(cam_basis, cam_basis * Vector3(center.x, center.y, hi.z + 2.0))


## Pós-processo de pixel art: alfa duro (corte `alpha_cut`), contorno de 1 px de arte
## (4-vizinhos) na cor `outline` e ampliação nearest para `out_size`. Puro (testável).
static func stylize(src: Image, alpha_cut: float, outline: Color, out_size: int) -> Image:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var on := c.a >= alpha_cut
			solid[y * w + x] = 1 if on else 0
			img.set_pixel(x, y, Color(c, 1.0) if on else Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			if solid[y * w + x] == 1:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and solid[ny * w + nx] == 1:
					img.set_pixel(x, y, outline)
					break
	if out_size > 0 and (w != out_size or h != out_size):
		img.resize(out_size, out_size, Image.INTERPOLATE_NEAREST)
	return img


## Materiais próprios do ícone: toon (como o jogo) e `tint` multiplicando o albedo.
func _restyle(root: Node, tint: Color) -> void:
	var toon := bool(_get_setting("toon"))
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is MeshInstance3D) or (n as MeshInstance3D).mesh == null:
			continue
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var base := mi.get_active_material(s)
			var mat: StandardMaterial3D = base.duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()
			if toon:
				mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mat.albedo_color *= tint
			mi.set_surface_override_material(s, mat)


func _get_setting(key: String) -> Variant:
	return settings.get(key, DEFAULTS[key])


func _color(key: String) -> Color:
	return JsonData.to_color(_get_setting(key))
