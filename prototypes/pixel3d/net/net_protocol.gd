# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Protocolo do Ecos de Aethra: todo pacote = [u8 versão][u8 tipo][payload].
## Controle (confiável) = Dictionary via var_to_bytes (sem objetos).
## INPUT e SNAPSHOT (não confiáveis) = binário compacto (StreamPeerBuffer, little endian).
##
## Snapshot (servidor → cliente, 20 Hz, ~60 B + 19 B por entidade):
##   u32 tick | u32 ack_seq | bloco do próprio jogador | u16 n | n × entidade
##   próprio: f32 x,y,z | f32 dodge_t, dodge_cd, dodge_dir_x, dodge_dir_z |
##            u16 hp,max_hp,mana,max_mana | u8 level | u16 xp, xp_req | u8 pot_hp, pot_mana |
##            u8 cd_fire, cd_blink, cd_ring, cd_potion (décimos de s) | u16 effects
##   entidade: u32 id | u8 kind | u8 sub | s16 x,y,z (cm) | u8 yaw | u16 hp, max_hp | u16 effects

const VERSION := 1

# --- cliente → servidor
const C_HELLO := 1
const C_REGISTER := 2
const C_LOGIN := 3
const C_RESUME := 4
const C_INPUT := 5
const C_ACTION := 6
const C_CHAT := 7
const C_FRIEND := 8
const C_LOGOUT := 9
const C_PING := 10

# --- servidor → cliente
const S_WELCOME := 64
const S_ERROR := 65
const S_SNAPSHOT := 66
const S_ENTITY_INFO := 67
const S_EVENT := 68
const S_CHAT := 69
const S_FRIENDS := 70
const S_FRIEND_EVENT := 71
const S_PONG := 72
const S_KICK := 73

## Categoria de rate limit de cada tipo do cliente.
const RATE_CLASS := {
	C_HELLO: "auth", C_REGISTER: "auth", C_LOGIN: "auth", C_RESUME: "auth",
	C_INPUT: "input", C_ACTION: "action", C_CHAT: "chat", C_FRIEND: "friend",
	C_LOGOUT: "auth", C_PING: "ping",
}

const KIND_PLAYER := 1
const KIND_MONSTER := 2
const KIND_PROJECTILE := 3

## Tabela de efeitos genéricos (bit = índice). Acrescente no FIM e suba VERSION.
const EFFECTS := ["dodge", "blink", "windup", "hurt", "light", "dead", "casting", "ring", "slow"]

const MONSTER_SUBKINDS := ["frog", "spider", "wolf"]

const FLAG_DODGE := 1


static func effect_bits(effects: Array) -> int:
	var bits := 0
	for e: Variant in effects:
		var i := EFFECTS.find(String(e))
		if i >= 0:
			bits |= 1 << i
	return bits


static func effect_names(bits: int) -> Array[String]:
	var out: Array[String] = []
	for i in EFFECTS.size():
		if bits & (1 << i):
			out.append(String(EFFECTS[i]))
	return out


# ------------------------------------------------------------------ cabeçalho

## Lê [versão, tipo]; devolve -1 se o cabeçalho for inválido ou de outra versão.
static func packet_type(pkt: PackedByteArray) -> int:
	if pkt.size() < 2 or pkt[0] != VERSION:
		return -1
	return pkt[1]


# ------------------------------------------------------------------ controle

static func encode_control(type: int, data: Dictionary) -> PackedByteArray:
	var out := PackedByteArray([VERSION, type])
	out.append_array(var_to_bytes(data))
	return out


## Decodifica o payload de controle; {} se não for um Dictionary válido.
static func decode_control(pkt: PackedByteArray) -> Dictionary:
	if pkt.size() < 6:
		return {}
	var v: Variant = bytes_to_var(pkt.slice(2))  # bytes_to_var nunca cria objetos
	return v if v is Dictionary else {}


# ------------------------------------------------------------------ input

## cmds: Array de {seq:int, dir:Vector2, flags:int}; os mais novos por último.
static func encode_input(cmds: Array) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u8(VERSION)
	b.put_u8(C_INPUT)
	b.put_u8(cmds.size())
	for c: Dictionary in cmds:
		var d: Vector2 = c.dir
		b.put_u32(int(c.seq))
		b.put_8(clampi(roundi(d.x * 127.0), -127, 127))
		b.put_8(clampi(roundi(d.y * 127.0), -127, 127))
		b.put_u8(int(c.get("flags", 0)))
	return b.data_array


## Devolve [] se o pacote estiver malformado.
static func decode_input(pkt: PackedByteArray) -> Array:
	if pkt.size() < 3:
		return []
	var b := StreamPeerBuffer.new()
	b.data_array = pkt
	b.seek(2)
	var n := b.get_u8()
	if n < 1 or n > 8 or pkt.size() != 3 + n * 7:
		return []
	var out: Array = []
	for i in n:
		var seq := b.get_u32()
		var dx := float(b.get_8()) / 127.0
		var dz := float(b.get_8()) / 127.0
		var flags := b.get_u8()
		out.append({"seq": seq, "dir": Vector2(dx, dz).limit_length(1.0), "flags": flags})
	return out


# ------------------------------------------------------------------ snapshot

static func encode_snapshot(tick: int, ack: int, me: Dictionary, entities: Array) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u8(VERSION)
	b.put_u8(S_SNAPSHOT)
	b.put_u32(tick)
	b.put_u32(ack)
	var p: Vector3 = me.pos
	b.put_float(p.x)
	b.put_float(p.y)
	b.put_float(p.z)
	b.put_float(float(me.dodge_t))
	b.put_float(float(me.dodge_cd))
	var dd: Vector2 = me.dodge_dir
	b.put_float(dd.x)
	b.put_float(dd.y)
	b.put_u16(clampi(int(me.hp), 0, 65535))
	b.put_u16(clampi(int(me.max_hp), 0, 65535))
	b.put_u16(clampi(int(me.mana), 0, 65535))
	b.put_u16(clampi(int(me.max_mana), 0, 65535))
	b.put_u8(clampi(int(me.level), 0, 255))
	b.put_u16(clampi(int(me.xp), 0, 65535))
	b.put_u16(clampi(int(me.xp_req), 0, 65535))
	b.put_u8(clampi(int(me.pot_hp), 0, 255))
	b.put_u8(clampi(int(me.pot_mana), 0, 255))
	for k: String in ["cd_fire", "cd_blink", "cd_ring", "cd_potion"]:
		b.put_u8(clampi(ceili(float(me.get(k, 0.0)) * 10.0), 0, 255))
	b.put_u16(int(me.effects))
	b.put_u16(entities.size())
	for e: Dictionary in entities:
		var ep: Vector3 = e.pos
		b.put_u32(int(e.id))
		b.put_u8(int(e.kind))
		b.put_u8(int(e.get("sub", 0)))
		b.put_16(clampi(roundi(ep.x * 100.0), -32767, 32767))
		b.put_16(clampi(roundi(ep.y * 100.0), -32767, 32767))
		b.put_16(clampi(roundi(ep.z * 100.0), -32767, 32767))
		b.put_u8(int(posmod(roundi(float(e.get("yaw", 0.0)) / TAU * 256.0), 256)))
		b.put_u16(clampi(int(e.get("hp", 0)), 0, 65535))
		b.put_u16(clampi(int(e.get("max_hp", 0)), 0, 65535))
		b.put_u16(int(e.get("effects", 0)))
	return b.data_array


const _SNAP_HEADER := 2 + 8 + 28 + 8 + 1 + 4 + 2 + 4 + 2 + 2
const _SNAP_ENTITY := 19


static func decode_snapshot(pkt: PackedByteArray) -> Dictionary:
	if pkt.size() < _SNAP_HEADER:
		return {}
	var b := StreamPeerBuffer.new()
	b.data_array = pkt
	b.seek(2)
	var snap := {"tick": b.get_u32(), "ack": b.get_u32()}
	var me := {}
	me.pos = Vector3(b.get_float(), b.get_float(), b.get_float())
	me.dodge_t = b.get_float()
	me.dodge_cd = b.get_float()
	me.dodge_dir = Vector2(b.get_float(), b.get_float())
	me.hp = b.get_u16()
	me.max_hp = b.get_u16()
	me.mana = b.get_u16()
	me.max_mana = b.get_u16()
	me.level = b.get_u8()
	me.xp = b.get_u16()
	me.xp_req = b.get_u16()
	me.pot_hp = b.get_u8()
	me.pot_mana = b.get_u8()
	for k: String in ["cd_fire", "cd_blink", "cd_ring", "cd_potion"]:
		me[k] = float(b.get_u8()) / 10.0
	me.effects = b.get_u16()
	snap.me = me
	var n := b.get_u16()
	if pkt.size() != _SNAP_HEADER + n * _SNAP_ENTITY:
		return {}
	var list: Array = []
	for i in n:
		var e := {}
		e.id = b.get_u32()
		e.kind = b.get_u8()
		e.sub = b.get_u8()
		e.pos = Vector3(b.get_16() / 100.0, b.get_16() / 100.0, b.get_16() / 100.0)
		e.yaw = float(b.get_u8()) / 256.0 * TAU
		e.hp = b.get_u16()
		e.max_hp = b.get_u16()
		e.effects = b.get_u16()
		list.append(e)
	snap.entities = list
	return snap
