# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Contas: nome + senha (SHA-256 iterado com sal aleatório por conta), personagem salvo,
## grafo de amizades. Puro: só manipula `data`; quem grava em disco é o servidor (JsonStore).
## Observação: o Godot não expõe PBKDF2/scrypt; o hash iterado é o melhor disponível sem
## GDExtension. As contas guardam `iter` para permitir subir o custo depois.

const TextRules := preload("res://prototypes/pixel3d/net/text_rules.gd")

var data: Dictionary = {"version": 1, "accounts": {}}
var iterations := 20000
var name_min := 3
var name_max := 16
var pass_min := 6
var pass_max := 64
var dirty := false
## Fonte de bytes aleatórios (injetável em testes): Callable(n) -> PackedByteArray.
var random_bytes: Callable = func(n: int) -> PackedByteArray: return Crypto.new().generate_random_bytes(n)


func _init(cfg: Dictionary = {}, stored: Dictionary = {}) -> void:
	iterations = int(cfg.get("password_iterations", iterations))
	name_min = int(cfg.get("name_min", name_min))
	name_max = int(cfg.get("name_max", name_max))
	pass_min = int(cfg.get("password_min", pass_min))
	pass_max = int(cfg.get("password_max", pass_max))
	if stored.get("accounts") is Dictionary:
		data = stored
		if not data.has("version"):
			data["version"] = 1


func accounts() -> Dictionary:
	return data.accounts


func exists(key: String) -> bool:
	return accounts().has(key)


func display_name(key: String) -> String:
	return String((accounts().get(key, {}) as Dictionary).get("name", key))


## {ok: bool, key: String, error: String}
func register(raw_name: String, password: String, now_unix: int) -> Dictionary:
	var n := TextRules.clean_name(raw_name, name_min, name_max)
	if n.is_empty():
		return {"ok": false, "error": "bad_name"}
	if not TextRules.valid_password(password, pass_min, pass_max):
		return {"ok": false, "error": "bad_password"}
	var key := TextRules.name_key(n)
	if exists(key):
		return {"ok": false, "error": "name_taken"}
	var salt: String = (random_bytes.call(16) as PackedByteArray).hex_encode()
	accounts()[key] = {
		"name": n, "salt": salt, "iter": iterations, "hash": hash_password(password, salt, iterations),
		"created": now_unix, "character": {}, "friends": {}, "incoming": {}, "outgoing": {},
	}
	dirty = true
	return {"ok": true, "key": key}


## Devolve a chave da conta ou "" (nome inexistente e senha errada dão a mesma resposta).
func verify(raw_name: String, password: String) -> String:
	var key := TextRules.name_key(raw_name)
	if not exists(key) or password.length() > pass_max:
		return ""
	var acc: Dictionary = accounts()[key]
	var h := hash_password(password, String(acc.salt), int(acc.get("iter", iterations)))
	return key if constant_time_equal(h, String(acc.hash)) else ""


static func hash_password(password: String, salt: String, iter: int) -> String:
	var digest := (salt + ":" + password).to_utf8_buffer()
	var salt_bytes := salt.to_utf8_buffer()
	for _i in maxi(1, iter):
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(digest)
		ctx.update(salt_bytes)
		digest = ctx.finish()
	return digest.hex_encode()


static func constant_time_equal(a: String, b: String) -> bool:
	if a.length() != b.length():
		return false
	var diff := 0
	for i in a.length():
		diff |= a.unicode_at(i) ^ b.unicode_at(i)
	return diff == 0


func character(key: String) -> Dictionary:
	return (accounts().get(key, {}) as Dictionary).get("character", {})


func set_character(key: String, ch: Dictionary) -> void:
	if exists(key):
		accounts()[key]["character"] = ch
		dirty = true
