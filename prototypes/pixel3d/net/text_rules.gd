# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Sanitização de nomes e chat (puro, estático).


## Nome de conta/personagem: letras (com acento), dígitos, espaço único, '_' e '-'.
## Devolve "" se inválido.
static func clean_name(raw: String, min_len := 3, max_len := 16) -> String:
	var s := raw.strip_edges()
	while s.contains("  "):
		s = s.replace("  ", " ")
	if s.length() < min_len or s.length() > max_len:
		return ""
	for i in s.length():
		var c := s.unicode_at(i)
		var letter := (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 0xC0 and c <= 0x24F and c != 0xD7 and c != 0xF7)
		var digit := c >= 48 and c <= 57
		if not (letter or digit or c == 32 or c == 95 or c == 45):
			return ""
	if s.unicode_at(0) == 32 or s.unicode_at(0) == 45 or s.unicode_at(0) == 95:
		return ""
	return s


## Chave canônica (case-insensitive) para nomes.
static func name_key(n: String) -> String:
	return n.strip_edges().to_lower()


## Chat: remove controles/bidi/zero-width, colapsa espaços, corta no limite.
static func clean_chat(raw: String, max_len := 160) -> String:
	var out := ""
	for i in raw.length():
		var c := raw.unicode_at(i)
		if c < 32 or c == 127 or (c >= 0x80 and c < 0xA0):
			out += " "
			continue
		if (c >= 0x200B and c <= 0x200F) or (c >= 0x202A and c <= 0x202E) or (c >= 0x2066 and c <= 0x2069) or c == 0xFEFF:
			continue
		out += String.chr(c)
	out = out.strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.substr(0, max_len)


static func valid_password(p: String, min_len := 6, max_len := 64) -> bool:
	return p.length() >= min_len and p.length() <= max_len
