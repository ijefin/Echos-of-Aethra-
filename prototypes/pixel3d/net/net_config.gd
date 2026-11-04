# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Configuração de rede: JSON de tuning + sobrescritas por variável de ambiente.
## Puro: o leitor de ambiente é injetado (testes passam um Dictionary).

const DEFAULT_PATH := "res://prototypes/pixel3d/net/data/net_config.json"

## Variável de ambiente → [chave, tipo]. Segredos (ADMIN_TOKEN) nunca vêm do JSON.
const ENV_MAP := {
	"AETHRA_PORT": ["port", TYPE_INT],
	"AETHRA_MAX_PLAYERS": ["max_players", TYPE_INT],
	"AETHRA_DATA_DIR": ["data_dir", TYPE_STRING],
	"AETHRA_LOG_LEVEL": ["log_level", TYPE_STRING],
	"AETHRA_TICK_RATE": ["tick_rate", TYPE_INT],
	"AETHRA_ADMIN_TOKEN": ["admin_token", TYPE_STRING],
	"AETHRA_PASSWORD_ITERATIONS": ["password_iterations", TYPE_INT],
	"AETHRA_RECONNECT_GRACE_S": ["reconnect_grace_s", TYPE_FLOAT],
	"AETHRA_AUTOSAVE_S": ["autosave_s", TYPE_FLOAT],
}


## Carrega `path` e aplica o ambiente. `env` = Callable(nome) -> String ("" = ausente).
static func load_config(env: Callable = Callable(), path := DEFAULT_PATH) -> Dictionary:
	var cfg: Dictionary = {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			cfg = parsed
	return apply_env(cfg, env)


## Aplica sobrescritas de ambiente em uma cópia de `cfg`.
static func apply_env(cfg: Dictionary, env: Callable = Callable()) -> Dictionary:
	var out := cfg.duplicate(true)
	if not out.has("admin_token"):
		out["admin_token"] = ""
	var getter := env if env.is_valid() else Callable(OS, "get_environment")
	for key: String in ENV_MAP:
		var raw := String(getter.call(key))
		if raw.is_empty():
			continue
		var spec: Array = ENV_MAP[key]
		match int(spec[1]):
			TYPE_INT:
				if raw.is_valid_int():
					out[spec[0]] = int(raw)
			TYPE_FLOAT:
				if raw.is_valid_float():
					out[spec[0]] = float(raw)
			_:
				out[spec[0]] = raw
	out["port"] = clampi(int(out.get("port", 7777)), 1, 65535)
	out["max_players"] = clampi(int(out.get("max_players", 16)), 1, 256)
	return out


## Argumentos `--chave=valor` depois de `--` na linha de comando.
static func cmdline_args() -> Dictionary:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return args
