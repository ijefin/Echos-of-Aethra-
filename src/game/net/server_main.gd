extends SceneTree
## Ponto de entrada do servidor dedicado (headless):
##   godot --headless --path . -s res://src/game/net/server_main.gd -- [--port=7777] [--data_dir=...] [--quit_after=s]
## Configuração: net/data/net_config.json + variáveis AETHRA_* (+ argumentos acima, para testes).

const NetConfig := preload("res://src/game/net/net_config.gd")
const NetServer := preload("res://src/game/net/net_server.gd")

var server: Node
var _quit_after := -1.0


func _initialize() -> void:
	var cfg := NetConfig.load_config()
	var args := NetConfig.cmdline_args()
	if args.has("port"):
		cfg.port = int(args.port)
	if args.has("data_dir"):
		cfg.data_dir = String(args.data_dir)
	if args.has("log_level"):
		cfg.log_level = String(args.log_level)
	_quit_after = float(args.get("quit_after", -1.0))
	Engine.max_fps = int(args.get("max_fps", 60))   # headless não tem vsync: sem isso o laço gira a 100% de CPU
	server = NetServer.new()
	server.name = "AethraServer"
	root.add_child(server)
	server.setup(cfg)
	if server.start() != OK:
		quit(1)
		return
	print("AETHRA_SERVER_READY %d" % int(cfg.port))


func _process(delta: float) -> bool:
	if _quit_after > 0.0:
		_quit_after -= delta
		if _quit_after <= 0.0:
			server.save_all()
			return true
	return false


func _finalize() -> void:
	if server != null:
		server.save_all()
		print("AETHRA_SERVER_STOPPED")
