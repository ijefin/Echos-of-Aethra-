extends RefCounted
## Log com nível e limite de frequência por chave (anomalias de rede não inundam o disco).

const LEVELS := {"debug": 0, "info": 1, "warn": 2, "error": 3}

var level := 1
var per_key_s := 2.0
var _last: Dictionary = {}     # chave → t
var _dropped: Dictionary = {}  # chave → n suprimidos


func _init(level_name := "info") -> void:
	level = int(LEVELS.get(level_name.to_lower(), 1))


func _emit(lv: String, msg: String) -> void:
	var line := "%s [%s] %s" % [Time.get_datetime_string_from_system(true), lv.to_upper(), msg]
	if LEVELS[lv] >= 2:
		printerr(line)
	else:
		print(line)


func write(lv: String, msg: String) -> void:
	if int(LEVELS.get(lv, 1)) >= level:
		_emit(lv, msg)


## Igual a log(), mas no máximo 1 linha a cada `per_key_s` por `key`.
func limited(lv: String, key: String, msg: String) -> void:
	if int(LEVELS.get(lv, 1)) < level:
		return
	var t := Time.get_ticks_msec() / 1000.0
	if t - float(_last.get(key, -999.0)) < per_key_s:
		_dropped[key] = int(_dropped.get(key, 0)) + 1
		return
	var extra := ""
	if int(_dropped.get(key, 0)) > 0:
		extra = " (+%d suprimidas)" % int(_dropped[key])
		_dropped[key] = 0
	_last[key] = t
	_emit(lv, msg + extra)
