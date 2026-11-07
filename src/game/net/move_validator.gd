extends RefCounted
## Validação de movimento no servidor. O cliente NUNCA manda posição: manda comandos
## (direção + flags) numerados. Este validador garante:
##  - orçamento de tempo: cada comando custa `cmd_dt`; o orçamento cresce com o tempo real
##    (no máximo `budget_max`), então mandar comandos em excesso não acelera ninguém;
##  - fila limitada e sem repetição (seq antigo/duplicado é ignorado);
##  - anti-teleporte: deslocamento por comando ≤ velocidade máxima × dt × tolerância.

var cmd_dt: float
var budget_max: float
var max_queue: int
var max_speed: float
var tolerance: float

var budget := 0.0
var last_seq := 0
var queue: Array = []
var rejected := 0
var teleports := 0


func _init(cfg: Dictionary) -> void:
	cmd_dt = 1.0 / float(cfg.get("input_rate", 20))
	budget_max = float(cfg.get("move_budget_max_s", 0.25))
	max_queue = int(cfg.get("max_queued_inputs", 8))
	var mv: Dictionary = cfg.get("move", {})
	max_speed = maxf(float(mv.get("speed", 4.2)), float(mv.get("dodge_speed", 11.0)))
	tolerance = float(cfg.get("teleport_tolerance", 1.15))


## Recebe comandos (com redundância); devolve quantos novos foram aceitos.
func receive(cmds: Array) -> int:
	var added := 0
	for c: Dictionary in cmds:
		var seq := int(c.seq)
		if seq <= last_seq or _queued(seq):
			continue
		if seq > last_seq + 1000:   # salto absurdo de numeração
			rejected += 1
			continue
		queue.append(c)
		added += 1
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.seq) < int(b.seq))
	while queue.size() > max_queue:
		queue.pop_front()
		rejected += 1
	return added


func _queued(seq: int) -> bool:
	for c: Dictionary in queue:
		if int(c.seq) == seq:
			return true
	return false


## Avança o relógio do servidor; devolve os comandos que podem ser simulados agora.
func take(tick_dt: float) -> Array:
	budget = minf(budget + tick_dt, budget_max)
	var out: Array = []
	while not queue.is_empty() and budget + 0.0001 >= cmd_dt:
		var c: Dictionary = queue.pop_front()
		budget -= cmd_dt
		last_seq = int(c.seq)
		out.append(c)
	return out


## Verifica um passo já simulado; false = deslocamento impossível (reverter).
func check_step(from: Vector3, to: Vector3) -> bool:
	var d := Vector2(to.x - from.x, to.z - from.z).length()
	if d > max_speed * cmd_dt * tolerance + 0.01:
		teleports += 1
		return false
	return true


## Teleporte legítimo do servidor (Eco, renascer): não conta como trapaça.
func reset_budget() -> void:
	budget = 0.0
