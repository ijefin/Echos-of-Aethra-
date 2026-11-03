class_name JsonData
extends RefCounted
## Leitura de dados de jogo em JSON (assets/data/). Centraliza o tratamento de erro
## para que nenhum sistema precise de valores hardcoded como fallback silencioso.


## Lê um arquivo JSON e devolve o Dictionary raiz. Em caso de erro, registra com
## push_error e devolve um Dictionary vazio.
static func load_dict(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("JsonData: não foi possível ler %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("JsonData: %s não contém um objeto JSON" % path)
	return {}


## Converte um array JSON [r, g, b] ou [r, g, b, a] em Color.
static func to_color(value: Array) -> Color:
	return Color(value[0], value[1], value[2], value[3] if value.size() > 3 else 1.0)
