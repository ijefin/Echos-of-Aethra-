extends RefCounted
## Sessões: token aleatório por login, ligado a um peer. Ao cair a conexão, o token vale
## por `grace` segundos para RESUME (volta no mesmo personagem, sem senha). Só o hash
## SHA-256 do token fica em memória. Puro: relógio e gerador injetados.

var grace := 120.0
var _by_hash: Dictionary = {}   # hash → {key, peer (0 = desconectado), expires}
var _by_peer: Dictionary = {}   # peer → hash
var _by_key: Dictionary = {}    # conta → hash
var random_bytes: Callable = func(n: int) -> PackedByteArray: return Crypto.new().generate_random_bytes(n)


func _init(reconnect_grace := 120.0) -> void:
	grace = reconnect_grace


static func _h(token: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(token.to_utf8_buffer())
	return ctx.finish().hex_encode()


## Cria sessão nova (invalida a anterior da conta). Devolve o token em claro (só vai ao cliente).
func issue(key: String, peer: int) -> String:
	end_account(key)
	var token: String = (random_bytes.call(24) as PackedByteArray).hex_encode()
	var h := _h(token)
	_by_hash[h] = {"key": key, "peer": peer, "expires": INF}
	_by_peer[peer] = h
	_by_key[key] = h
	return token


## Conexão caiu: o token entra no período de graça.
func detach(peer: int, now: float) -> String:
	if not _by_peer.has(peer):
		return ""
	var h: String = _by_peer[peer]
	_by_peer.erase(peer)
	var s: Dictionary = _by_hash[h]
	s.peer = 0
	s.expires = now + grace
	return String(s.key)


## RESUME: devolve a conta se o token for válido e não estiver em uso; "" se não.
func resume(token: String, peer: int, now: float) -> String:
	var h := _h(token)
	if not _by_hash.has(h):
		return ""
	var s: Dictionary = _by_hash[h]
	if int(s.peer) != 0 or now > float(s.expires):
		return ""
	s.peer = peer
	s.expires = INF
	_by_peer[peer] = h
	return String(s.key)


func key_of(peer: int) -> String:
	return String((_by_hash.get(_by_peer.get(peer, ""), {}) as Dictionary).get("key", ""))


func peer_of(key: String) -> int:
	return int((_by_hash.get(_by_key.get(key, ""), {}) as Dictionary).get("peer", 0))


## Logout explícito / login em outro lugar: o token deixa de valer.
func end_account(key: String) -> void:
	if not _by_key.has(key):
		return
	var h: String = _by_key[key]
	var s: Dictionary = _by_hash.get(h, {})
	if int(s.get("peer", 0)) != 0:
		_by_peer.erase(int(s.peer))
	_by_hash.erase(h)
	_by_key.erase(key)


## Remove sessões vencidas; devolve as contas liberadas.
func expire(now: float) -> Array[String]:
	var out: Array[String] = []
	for h: String in _by_hash.keys():
		var s: Dictionary = _by_hash[h]
		if int(s.peer) == 0 and now > float(s.expires):
			out.append(String(s.key))
			_by_hash.erase(h)
			_by_key.erase(String(s.key))
	return out
