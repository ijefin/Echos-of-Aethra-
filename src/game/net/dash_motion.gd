extends RefCounted
## Investida (guerreiro) e Salto Evasivo (arqueiro) suaves no cliente.
## O servidor resolve o deslocamento inteiro no tick do pedido (dano, parede, primeiro
## monstro) e manda o evento "dash" com from/at/time. Sem isto o corpo pularia de uma vez
## (o próprio jogador pelo snap da reconciliação > 2,5 m; os outros entre dois snapshots).
## Aqui o corpo desenhado vai de `from` até o alvo em `time` s com ease-out — a posição
## autoritativa não muda, só o que se desenha durante o golpe.
## Regras puras (sem nó): testadas em tests/unit/net/dash_motion_test.gd.

## Duração mínima do deslizamento (s): evita divisão por zero e "teleporte" em dash curto.
const MIN_TIME := 0.12


## Começa um deslizamento. `to` = destino do servidor (o alvo pode ser trocado a cada passo).
static func start(from: Vector3, to: Vector3, time: float) -> Dictionary:
	return {"from": from, "to": to, "t": 0.0, "dur": maxf(MIN_TIME, time)}


static func active(d: Dictionary) -> bool:
	return not d.is_empty() and float(d.t) < float(d.dur)


## Avança `delta` e devolve a posição a desenhar, indo para `target` (para o próprio jogador,
## a posição prevista/servidor do quadro; para os outros, o destino do evento).
## A altura vem do alvo (chão/andar do servidor). Terminado, devolve o próprio alvo.
static func step(d: Dictionary, delta: float, target: Vector3) -> Vector3:
	if d.is_empty():
		return target
	d.t = float(d.t) + maxf(0.0, delta)
	var k := clampf(float(d.t) / float(d.dur), 0.0, 1.0)
	if k >= 1.0:
		return target
	var e := 1.0 - (1.0 - k) * (1.0 - k)   # ease-out: arranca rápido, assenta no fim
	var from: Vector3 = d.from
	var p := from.lerp(target, e)
	p.y = target.y
	return p
