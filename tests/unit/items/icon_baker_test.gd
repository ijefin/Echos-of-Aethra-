extends SceneTree
## Testes das partes puras do IconBaker (pós-processo e enquadramento; sem GPU).
##   godot --headless --path . -s res://tests/unit/items/icon_baker_test.gd

var _failed := 0


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failed += 1
		printerr("FALHOU: ", what)


func _initialize() -> void:
	test_stylize_hard_alpha_and_outline()
	test_stylize_scales_nearest()
	test_frame_camera_fits_points()
	test_frame_camera_zoom_shrinks_view()
	print("icon_baker: %s" % ("OK" if _failed == 0 else "%d falha(s)" % _failed))
	quit(1 if _failed > 0 else 0)


func _dot_image() -> Image:
	# 5×5 transparente com um pixel meio opaco no centro e um quase invisível no canto.
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.set_pixel(2, 2, Color(1, 0, 0, 0.8))
	img.set_pixel(0, 0, Color(0, 1, 0, 0.2))
	return img


func test_stylize_hard_alpha_and_outline() -> void:
	var outline := Color8(25, 0, 51)  # exata em RGBA8
	var out := IconBaker.stylize(_dot_image(), 0.5, outline, 0)
	_check(out.get_pixel(2, 2).is_equal_approx(Color(1, 0, 0, 1)), "pixel acima do corte fica opaco")
	_check(out.get_pixel(0, 0).a == 0.0, "pixel abaixo do corte some")
	for p: Vector2i in [Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)]:
		_check(out.get_pixelv(p).is_equal_approx(outline), "contorno em %s" % p)
	_check(out.get_pixel(1, 1).a == 0.0, "diagonal não ganha contorno")


func test_stylize_scales_nearest() -> void:
	var out := IconBaker.stylize(_dot_image(), 0.5, Color.BLACK, 10)
	_check(out.get_size() == Vector2i(10, 10), "amplia para out_size")
	_check(out.get_pixel(4, 4).is_equal_approx(Color(1, 0, 0, 1)) and out.get_pixel(5, 5).is_equal_approx(Color(1, 0, 0, 1)), "nearest: 1 px vira bloco 2×2")


func test_frame_camera_fits_points() -> void:
	var cam := Camera3D.new()
	var pts := PackedVector3Array([Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 3, 0)])
	IconBaker.frame_camera(cam, Basis.IDENTITY, pts, 0.0)
	_check(is_equal_approx(cam.size, 3.0), "tamanho = maior lado (3)")
	_check(cam.position.is_equal_approx(Vector3(0, 1.5, 2.0)), "centro do quadro e câmera à frente")
	IconBaker.frame_camera(cam, Basis.IDENTITY, pts, 0.25)
	_check(is_equal_approx(cam.size, 6.0), "margem de 25% de cada lado dobra o quadro")
	cam.free()


func test_frame_camera_zoom_shrinks_view() -> void:
	var cam := Camera3D.new()
	var pts := PackedVector3Array([Vector3(-1, -1, 0), Vector3(1, 1, 0)])
	IconBaker.frame_camera(cam, Basis.IDENTITY, pts, 0.0, 2.0)
	_check(is_equal_approx(cam.size, 1.0), "zoom 2 corta o quadro pela metade")
	cam.free()
