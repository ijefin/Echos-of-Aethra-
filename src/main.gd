class_name GameMain
extends Control
## Raiz do jogo. O mundo em pixel art roda num SubViewport de baixa resolução com escala
## INTEIRA (pixel perfeito) que preenche a tela inteira — telas maiores mostram mais mundo
## em vez de bordas pretas. A interface (HUD, tela inicial) fica por cima em resolução
## nativa, com texto nítido. Todo o input passa por aqui e é repassado ao mundo já com o
## mouse em coordenadas do mundo.
##
## Linha de comando (depois de `--`): --solo · --host · --join=IP[:porta] · --class=warrior
## · --name=Jeff · --port=7777 · --demo · --shot=res://x.png [--shot_delay=4] [--debug]
## · --give=item,item (GiveItems ao entrar) · --equip=item,item · --inventory (abre o painel)

const BASE_HEIGHT := 360.0
const CLEARING_SCENE := "res://src/world/training_clearing.tscn"

var _container: SubViewportContainer
var _viewport: SubViewport
var _clearing: TrainingClearing
var _ui: CanvasLayer
var _hud: CombatHud
var _menu: MainMenu
var _inventory: InventoryPanel
var _started := false
## Overlay F3: parâmetros do avatar local ajustáveis ao vivo [propriedade, passo].
const TUNABLES := [
	["move_speed", 5.0], ["accel_time", 0.01], ["friction_time", 0.01], ["turn_time", 0.01],
	["dodge_speed", 10.0], ["dodge_duration", 0.01], ["dodge_max_cooldown", 0.1],
]
var _debug := false
var _tunable_sel := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Nomes fixos: as RPCs localizam nós pelo caminho, que tem de ser igual em todos os peers.
	_container = SubViewportContainer.new()
	_container.name = "WorldView"
	_container.stretch = true
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.name = "WorldViewport"
	_viewport.use_hdr_2d = true
	_viewport.snap_2d_transforms_to_pixel = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_container.add_child(_viewport)
	_clearing = (load(CLEARING_SCENE) as PackedScene).instantiate() as TrainingClearing
	_viewport.add_child(_clearing)

	_ui = CanvasLayer.new()
	_ui.name = "UI"
	_ui.layer = 10
	add_child(_ui)
	_hud = CombatHud.new()
	_hud.visible = false
	_ui.add_child(_hud)
	_inventory = InventoryPanel.new()
	_ui.add_child(_inventory)
	_inventory.setup(_clearing.net)
	_clearing.net.notice.connect(func(t: String) -> void: _hud.show_message(t))
	_menu = MainMenu.new()
	_ui.add_child(_menu)
	var cls_data := JsonData.load_dict(CombatWorld.CLASSES_PATH)
	_menu.setup(cls_data.get("classes", {}), cls_data.get("playable", ["fire_mage"]),
		int(_clearing.combat.net_cfg.get("default_port", 7777)), NetSession.local_addresses())
	_menu.solo_requested.connect(func(n: String, c: String) -> void: _clearing.start_solo(n, c))
	_menu.host_requested.connect(_on_host)
	_menu.join_requested.connect(_on_join)
	_clearing.net.status_changed.connect(_menu.set_status)
	_clearing.local_player_ready.connect(_on_local_ready)

	get_viewport().size_changed.connect(_fit)
	_fit()
	_apply_cmdline()


## Escala inteira: 720p → 2×, 1080p → 3×, 1440p → 4×. O SubViewport cresce para
## preencher a janela inteira, então não sobram bordas.
func _fit() -> void:
	_container.stretch_shrink = maxi(1, int(size.y / BASE_HEIGHT))


func world_to_screen(p: Vector2) -> Vector2:
	return (_viewport.get_canvas_transform() * p) * float(_container.stretch_shrink)


func mouse_world() -> Vector2:
	var m := get_viewport().get_mouse_position() / float(_container.stretch_shrink)
	return _viewport.get_canvas_transform().affine_inverse() * m


func _process(_delta: float) -> void:
	if _started:
		_clearing.update_aim(mouse_world())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F11:
				var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
				return
			KEY_F10:
				get_tree().quit()
				return
			KEY_H:
				if _started:
					_hud.toggle_help()
					return
			KEY_F3:
				if _started:
					_debug = _hud.toggle_debug()
					_push_tunables()
					return
			KEY_F4, KEY_PAGEUP, KEY_PAGEDOWN:
				if _started and _debug:
					_tune(event.physical_keycode)
					return
			KEY_I:
				if _started:
					_inventory.toggle()
					return
			KEY_K:
				if _started:
					_clearing.shake_scale = 0.0 if _clearing.shake_scale > 0.0 else 1.0
					_hud.show_message("Tremor de tela: %s" % ("ligado" if _clearing.shake_scale > 0.0 else "desligado"))
					return
	if _started:
		_clearing.game_input(event, mouse_world())


func _on_host(port: int, player_name: String, cls: String) -> void:
	var err := _clearing.start_host(port, player_name, cls)
	if err != "":
		_menu.set_status(err)
		return
	var ips := NetSession.local_addresses()
	_hud.set_net_line("Hospedando na porta %d · IP %s" % [port, ", ".join(ips) if not ips.is_empty() else "—"])


func _on_join(address: String, port: int, player_name: String, cls: String) -> void:
	var err := _clearing.start_join(address, port, player_name, cls)
	if err != "":
		_menu.set_status(err)
		return
	_hud.set_net_line("Conectado a %s:%d" % [address, port])


func _on_local_ready(kit: ClassKit) -> void:
	_started = true
	_menu.visible = false
	_hud.visible = true
	_hud.bind(kit, _clearing.combat, world_to_screen, mouse_world)
	_hud.show_message(kit.display_class())
	if _debug:
		_push_tunables()


func _apply_cmdline() -> void:
	var opts := {}
	for a: String in OS.get_cmdline_user_args():
		var parts := a.trim_prefix("--").split("=", true, 1)
		opts[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_clearing.demo = opts.has("demo")
	var player_name := String(opts.get("name", "Viajante"))
	var cls := String(opts.get("class", "fire_mage"))
	if cls == "mage":
		cls = "fire_mage"
	var port := int(opts.get("port", _clearing.combat.net_cfg.get("default_port", 7777)))
	if opts.has("host"):
		_on_host(port, player_name, cls)
	elif opts.has("join"):
		var target := String(opts.join).split(":")
		_on_join(target[0], int(target[1]) if target.size() > 1 else port, player_name, cls)
	elif opts.has("solo") or opts.has("demo"):
		_clearing.start_solo(player_name, cls)
	if opts.has("switch_at"):
		get_tree().create_timer(float(opts.switch_at)).timeout.connect(func() -> void:
			_clearing.game_input(_key_event(KEY_C), mouse_world()))
	if opts.has("give") or opts.has("equip") or opts.has("inventory"):
		# QA: dá/veste itens e abre o inventário logo depois de entrar (modo solo/host).
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			var me := multiplayer.get_unique_id()
			if opts.has("give"):
				_clearing.net.give_items(me, String(opts.give).split(","))
			if opts.has("equip"):
				for id: String in String(opts.equip).split(","):
					_clearing.net.request_equip.rpc_id(1, id)
			if opts.has("inventory"):
				_inventory.toggle())
	if opts.has("shot"):
		_capture_after(float(opts.get("shot_delay", 4.0)), String(opts.shot), opts.has("debug"))


## Captura de evidência de QA: `--shot=res://...png [--shot_delay=4] [--debug]` salva a
## tela depois do atraso (opcionalmente com o overlay F3) e fecha o jogo.
func _capture_after(delay: float, path: String, debug: bool) -> void:
	await get_tree().create_timer(delay).timeout
	if debug and _started and not _debug:
		_debug = _hud.toggle_debug()
		_push_tunables()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _local_avatar() -> PlayerAvatar:
	return _clearing.combat.avatar_of(_clearing.combat.local_peer())


## F4 troca o parâmetro selecionado; PgUp/PgDn somam/subtraem o passo dele.
func _tune(key: Key) -> void:
	var a := _local_avatar()
	if a == null:
		return
	if key == KEY_F4:
		_tunable_sel = (_tunable_sel + 1) % TUNABLES.size()
	else:
		var prop: String = TUNABLES[_tunable_sel][0]
		var step: float = TUNABLES[_tunable_sel][1] * (1.0 if key == KEY_PAGEUP else -1.0)
		a.set(prop, maxf(absf(step), float(a.get(prop)) + step))
	_push_tunables()


func _push_tunables() -> void:
	var a := _local_avatar()
	if a == null:
		return
	var rows := []
	for t: Array in TUNABLES:
		rows.append([t[0], float(a.get(t[0]))])
	_hud.set_debug_tunables(rows, _tunable_sel)


func _key_event(key: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.pressed = true
	return ev
