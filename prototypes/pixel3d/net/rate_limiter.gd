# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Token bucket por peer e por categoria de mensagem + placar de abuso.
## Puro: o relógio é passado em cada chamada (segundos).

var limits: Dictionary          # categoria → {rate, burst}
var kick_score: float
var decay: float
var _buckets: Dictionary = {}   # peer → {categoria → [tokens, t_last]}
var _score: Dictionary = {}     # peer → [score, t_last]


func _init(rate_limits: Dictionary, abuse_kick := 40.0, abuse_decay := 2.0) -> void:
	limits = rate_limits
	kick_score = abuse_kick
	decay = abuse_decay


## Consome 1 ficha de `category` (e de "any"). false = mensagem deve ser descartada.
func allow(peer: int, category: String, now: float) -> bool:
	var ok := _take(peer, "any", now)
	if limits.has(category):
		ok = _take(peer, category, now) and ok
	if not ok:
		penalize(peer, 1.0, now)
	return ok


## Soma pontos de abuso (pacote malformado, gigante, ação inválida...).
func penalize(peer: int, points: float, now: float) -> void:
	var s: Array = _score.get(peer, [0.0, now])
	s[0] = maxf(0.0, float(s[0]) - (now - float(s[1])) * decay) + points
	s[1] = now
	_score[peer] = s


func score(peer: int, now: float) -> float:
	var s: Array = _score.get(peer, [0.0, now])
	return maxf(0.0, float(s[0]) - (now - float(s[1])) * decay)


func should_kick(peer: int, now: float) -> bool:
	return score(peer, now) >= kick_score


func forget(peer: int) -> void:
	_buckets.erase(peer)
	_score.erase(peer)


func _take(peer: int, category: String, now: float) -> bool:
	var spec: Dictionary = limits.get(category, {})
	if spec.is_empty():
		return true
	var rate := float(spec.get("rate", 10.0))
	var burst := float(spec.get("burst", rate))
	var per: Dictionary = _buckets.get(peer, {})
	var b: Array = per.get(category, [burst, now])
	var tokens := minf(burst, float(b[0]) + (now - float(b[1])) * rate)
	var ok := tokens >= 1.0
	if ok:
		tokens -= 1.0
	per[category] = [tokens, now]
	_buckets[peer] = per
	return ok
