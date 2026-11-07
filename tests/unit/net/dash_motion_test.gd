extends SceneTree
## Investida/salto suaves no cliente (net/dash_motion.gd): o corpo desenhado desliza do
## ponto de partida até o destino do servidor no tempo da habilidade, sem teleporte.
##   godot --headless --path . -s res://tests/unit/net/dash_motion_test.gd

const DashMotion := preload("res://src/game/net/dash_motion.gd")
const DT := 1.0 / 60.0

var failures := 0
var passes := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	test_slide_is_gradual_and_ends_on_target()
	test_target_snap_mid_dash_is_absorbed()
	test_short_dash_uses_min_time()
	test_inactive_returns_target()
	print("DASH_MOTION: %s (%d ok, %d falhas)" % ["OK" if failures == 0 else "FALHOU", passes, failures])
	quit(0 if failures == 0 else 1)


func test_slide_is_gradual_and_ends_on_target() -> void:
	var from := Vector3(0, 0, 0)
	var to := Vector3(5, 0, 0)   # Salto Evasivo: 5 m
	var d := DashMotion.start(from, to, 0.3)
	var prev := from
	var max_step := 0.0
	var monotonic := true
	var frames := 0
	while DashMotion.active(d) and frames < 200:
		var p := DashMotion.step(d, DT, to)
		max_step = maxf(max_step, p.distance_to(prev))
		monotonic = monotonic and p.x >= prev.x - 0.0001
		prev = p
		frames += 1
	check(frames >= 17 and frames <= 19, "dura o tempo da habilidade (%d quadros a 60 Hz para 0,3 s)" % frames)
	check(max_step < 0.6, "sem teleporte: maior passo por quadro %.2f m (de 5 m)" % max_step)
	check(monotonic, "anda sempre para o destino (não volta)")
	check(prev.distance_to(to) < 0.001, "termina exatamente no destino do servidor")


func test_target_snap_mid_dash_is_absorbed() -> void:
	# próprio jogador: a posição prevista salta para o destino quando chega o snapshot
	var from := Vector3(0, 0, 0)
	var d := DashMotion.start(from, Vector3(4, 0, 0), 0.3)
	var p1 := DashMotion.step(d, DT, from)            # snapshot ainda antigo
	var p2 := DashMotion.step(d, DT, Vector3(4, 0, 0))  # reconciliação: destino
	check(p1.distance_to(from) < 0.001, "antes do snapshot novo fica no lugar")
	check(p2.distance_to(p1) < 1.0, "salto da reconciliação vira deslizamento (%.2f m no quadro)" % p2.distance_to(p1))


func test_short_dash_uses_min_time() -> void:
	var d := DashMotion.start(Vector3.ZERO, Vector3(1, 0, 0), 0.0)
	check(is_equal_approx(float(d.dur), DashMotion.MIN_TIME), "tempo zero usa o mínimo (%.2f s)" % float(d.dur))
	var p := DashMotion.step(d, DT, Vector3(1, 0.5, 0))
	check(is_equal_approx(p.y, 0.5), "altura vem do alvo (chão do servidor)")


func test_inactive_returns_target() -> void:
	var t := Vector3(3, 0, 2)
	check(DashMotion.step({}, DT, t) == t and not DashMotion.active({}), "sem dash: devolve a posição do servidor")
