# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Som ambiente sem loop cansativo: fundos que cruzam dia/noite/gruta e sons avulsos
## sorteados (posição em volta do jogador, tom, volume e intervalo variam sempre).
## Dia: pássaros. Noite: grilos que trocam de lugar, corujas espaçadas, sapos perto da
## água. Gruta: gotas com eco e cachoeiras. Fixos: rio e fonte.
## Sons gerados por tools/gen_ambience.py (síntese, sem licença de terceiros).

const DIR := "res://prototypes/pixel3d/audio/"
const Dressing := preload("res://prototypes/pixel3d/pixel3d_dressing.gd")
const World := preload("res://prototypes/pixel3d/adventure_world.gd")
const Cave := preload("res://prototypes/pixel3d/adventure_cave.gd")
const COUNTS := {"bird": 18, "cricket": 6, "owl": 6, "frog": 5, "drip": 8}
const BED_DB := -16.0
const MUTE_DB := -60.0

var demo: Node
var _beds := {}                 # nome -> AudioStreamPlayer
var _lib := {}                  # categoria -> Array[AudioStream]
var _next := {"bird": 2.0, "owl": 9.0, "frog": 4.0, "drip": 1.0}
var _crickets: Array = []       # {player, life}
var _rng := RandomNumberGenerator.new()
var _river: AudioStreamPlayer3D
var _fountain: AudioStreamPlayer3D
var _falls: Array[AudioStreamPlayer3D] = []


func build(owner_demo: Node) -> void:
	demo = owner_demo
	_rng.randomize()
	demo._vp.audio_listener_enable_3d = true
	var ear := AudioListener3D.new()
	demo._player.add_child(ear)
	ear.position.y = 1.2
	ear.make_current()  # o ouvido fica no personagem; a câmera ortográfica está longe
	for cat: String in COUNTS:
		var list: Array[AudioStream] = []
		for i in int(COUNTS[cat]):
			list.append(_wav("%s_%02d" % [cat, i]))
		_lib[cat] = list
	for bed: String in ["bed_day", "bed_night", "bed_cave"]:
		var p := AudioStreamPlayer.new()
		p.stream = _looped(_wav(bed))
		p.volume_db = MUTE_DB
		demo.add_child(p)
		p.play(_rng.randf() * 10.0)
		_beds[bed] = p
	_river = _emitter(_looped(_wav("water_loop")), Vector3.ZERO, -10.0, 4.0)
	_fountain = _emitter(_looped(_wav("water_loop")), Vector3(Dressing.PLAZA_C.x, 1.0, Dressing.PLAZA_C.y), -14.0, 2.5)
	_fountain.pitch_scale = 1.35
	for f: Array in Cave.FALLS:
		var at := World.ROOM + Vector3(float(f[0]), 1.0, float(f[1]))
		var p := _emitter(_looped(_wav("waterfall_loop")), at, -12.0, 3.0)
		p.pitch_scale = _rng.randf_range(0.9, 1.1)
		_falls.append(p)


## WAV lido direto do disco (dispensa o importador; protótipo roda do projeto).
func _wav(name: String) -> AudioStreamWAV:
	return AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(DIR + name + ".wav"))


func _looped(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream


func _emitter(stream: AudioStream, at: Vector3, db: float, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = 28.0
	demo._vp.add_child(p)
	p.global_position = at
	p.play(_rng.randf() * 5.0)
	return p


## Som avulso em volta do jogador (distância/ângulo/tom/volume sorteados).
func _one_shot(cat: String, around: Vector3, near: float, far: float, db: float, height := 1.5) -> void:
	var list: Array = _lib[cat]
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(near, far)
	var p := AudioStreamPlayer3D.new()
	p.stream = list[_rng.randi() % list.size()]
	p.volume_db = db + _rng.randf_range(-4.0, 2.0)
	p.pitch_scale = _rng.randf_range(0.88, 1.12)
	p.unit_size = 5.0
	p.max_distance = 32.0
	demo._vp.add_child(p)
	p.global_position = around + Vector3(cos(a) * d, height + _rng.randf_range(0.0, 2.5), sin(a) * d)
	p.finished.connect(p.queue_free)
	p.play()


func _set_bed(name: String, weight: float, delta: float) -> void:
	var p: AudioStreamPlayer = _beds[name]
	var target := lerpf(MUTE_DB, BED_DB, clampf(weight, 0.0, 1.0)) if weight > 0.01 else MUTE_DB
	p.volume_db = move_toward(p.volume_db, target, delta * 12.0)


func update(delta: float, night: float, in_cave: bool, player: Vector3) -> void:
	var day := 1.0 - night
	var out := 0.0 if in_cave else 1.0
	_set_bed("bed_day", day * out, delta)
	_set_bed("bed_night", night * out, delta)
	_set_bed("bed_cave", 1.0 - out, delta)
	# rio: o emissor acompanha o ponto da margem mais perto do jogador
	_river.global_position = Vector3(player.x, 0.5, Dressing.river_center(player.x))
	_river.stream_paused = in_cave
	_fountain.stream_paused = in_cave
	for f in _falls:
		f.stream_paused = not in_cave
	for cat: String in _next:
		_next[cat] = float(_next[cat]) - delta
	if in_cave:
		if float(_next.drip) <= 0.0:
			_next.drip = _rng.randf_range(0.7, 2.6)
			_one_shot("drip", player, 3.0, 11.0, -12.0, 2.5)
		_update_crickets(delta, player, 0)
		return
	if day > 0.25 and float(_next.bird) <= 0.0:
		# mais pássaros de manhã cheia; intervalo nunca fixo
		_next.bird = _rng.randf_range(1.0, 4.5) / maxf(0.35, day)
		_one_shot("bird", player, 5.0, 16.0, -10.0, 3.0)
	if night > 0.5 and float(_next.owl) <= 0.0:
		_next.owl = _rng.randf_range(14.0, 34.0)
		_one_shot("owl", player, 12.0, 24.0, -9.0, 4.0)
	if night > 0.35 and float(_next.frog) <= 0.0:
		_next.frog = _rng.randf_range(2.5, 8.0)
		if Dressing.water_dist(Vector2(player.x, player.z)) < 18.0:
			_one_shot("frog", player, 4.0, 14.0, -13.0, 0.3)
	_update_crickets(delta, player, roundi(night * 5.0) if night > 0.3 else 0)


## Grilos: N emissores que vivem 8–20 s, entram e saem em fade e mudam de lugar.
func _update_crickets(delta: float, player: Vector3, wanted: int) -> void:
	for i in range(_crickets.size() - 1, -1, -1):
		var c: Dictionary = _crickets[i]
		var p: AudioStreamPlayer3D = c.player
		c.life = float(c.life) - delta
		var fade_in := clampf((float(c.total) - float(c.life)) / 2.0, 0.0, 1.0)
		var fade_out := clampf(float(c.life) / 2.0, 0.0, 1.0)
		p.volume_db = lerpf(MUTE_DB, float(c.db), minf(fade_in, fade_out))
		if float(c.life) <= 0.0 or (i >= wanted and float(c.life) > 2.0):
			if float(c.life) > 2.0:
				c.life = 2.0  # sai em fade
			if float(c.life) <= 0.0:
				p.queue_free()
				_crickets.remove_at(i)
	if _crickets.size() < wanted:
		var list: Array = _lib.cricket
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(4.0, 13.0)
		var p := AudioStreamPlayer3D.new()
		p.stream = _looped(list[_rng.randi() % list.size()].duplicate())
		p.pitch_scale = _rng.randf_range(0.92, 1.08)
		p.unit_size = 4.0
		p.max_distance = 26.0
		p.volume_db = MUTE_DB
		demo._vp.add_child(p)
		p.global_position = player + Vector3(cos(a) * d, 0.2, sin(a) * d)
		p.play(_rng.randf() * 3.0)
		var total := _rng.randf_range(8.0, 20.0)
		_crickets.append({"player": p, "life": total, "total": total, "db": _rng.randf_range(-20.0, -14.0)})
