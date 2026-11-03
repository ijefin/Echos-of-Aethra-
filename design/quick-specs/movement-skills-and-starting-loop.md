# Quick Design Spec: Habilidades de Movimento e Loop Inicial

**Type**: New Small System + Content Loop
**Date**: 2026-11-03
**Base**: `design/game-brief.md`, `design/gdd/core-combat-rework.md`, `design/quick-specs/class-combat-fire-mage-mvp-2026-10-30.md`, protótipo `prototypes/pixel3d/` (unidades em **u** = metros da cena 3D; andar = 4,2 u/s; esquiva = 11 u/s por 0,24 s; blink = 7 u, 0,32 s, CD 0,55 s).
**Status**: rascunho para decisão do usuário.

## 1. Kit de movimento

Regras comuns: todo movimento é resolvido no servidor (host); o cliente prediz e corrige. Destino de teleporte = ponto mais distante **válido** no caminho (raycast de navmesh); paredes bloqueiam, abismos e água funda são válidos só para teleporte (não para dash). Nenhum movimento atravessa "paredes de arena" de boss.

| # | Nome | Fantasia | Regra exata | Combos | Quem usa |
|---|---|---|---|---|---|
| 1 | **Eco de Aethra** (blink + âncora) | "Estou em dois lugares" | Blink 7 u, 0,32 s, i-frames 0,12–0,32 s. Deixa uma **âncora** por 3,0 s; reativar = volta à âncora (0,20 s, sem i-frames). CD 6 s (contado a partir do retorno ou da expiração). 10 mana. Atravessa água/fosso; não atravessa parede. | Lançar Pilar → blink fora → voltar quando explode. Puxar bando e retornar à posição segura. | Mago (todas as escolas) |
| 2 | **Passo de Brasa** (esquiva Piromante) | "Corro deixando o chão em chamas" | Substitui a esquiva: 11 u/s por 0,24 s, i-frames 0,04–0,20 s. Deixa rastro 0,8 u de largura que dura 2,5 s; inimigo que pisa recebe 1 Queimadura (máx. 1 por 0,5 s por alvo). CD 1,2 s, 0 mana. Na água: sem rastro. | Kite em círculo empilha Queimadura → Bola de Fogo detona Ignição. | Mago de Fogo (bônus do conjunto Piromante: rastro dura +1 s) |
| 3 | **Investida Perfurante** | "Atravesso a linha deles" | Dash 6 u em 0,22 s, atravessa inimigos normais (para em elite/boss), 18 de dano físico + 25 poise a cada um, **interrompe canal**. Sem i-frames; super-armor durante o dash. CD 7 s, 15 rage. Não atravessa parede nem água funda (para na borda). | Investida → Quebra no tanque staggered. Interrompe o Oráculo. | Guerreiro |
| 4 | **Salto Sísmico** | "Caio do céu" | Salto até 6 u, 0,55 s no ar (intangível de 0,15 a 0,45 s), impacto raio 2,5 u, 30 dano, 40 poise, knockback 1,5 u. Telegrafia no chão do destino. CD 12 s, 20 rage. Pode pular riacho estreito (≤ 4 u). | Salto no meio do bando → Anel de Fogo do aliado. | Guerreiro |
| 5 | **Corrente de Faíscas** | "Sou um raio" | Até 3 blinks curtos de 3 u, cada um 0,15 s, janela de 0,6 s para encadear; i-frames só no 1º. Cada salto causa 8 dano no ponto de partida. CD 9 s, 15 mana. | Atravessar um corredor de armadilhas; ziguezague entre atiradores. | Mago (árvore de raio futura) |
| 6 | **Troca Arcana** | "Inverto o campo" | Troca de posição com alvo marcado a ≤ 9 u, 0,25 s. Normais/especiais: sim; elite: só se staggered; boss: nunca. CD 14 s, 20 mana. | Puxar o Oráculo para dentro do Pilar; tirar aliado do perigo (co-op). | Mago / suporte |
| 7 | **Salto ao Cometa** | "Viajo na minha magia" | Reativar enquanto a Bola de Fogo voa: teleporta ao projétil (0,2 s), que detona imediatamente com 70 % do dano. Sem custo extra; CD 10 s. | Bola de Fogo → Salto → Anel de Fogo (entrada explosiva). | Mago de Fogo |
| 8 | **Passo Sombrio** | "Apareço nas costas" | Teleporte para trás do alvo a ≤ 8 u, próximo golpe +50 % dano nas costas (Guardião de Musgo). CD 10 s. | Contra a guarda frontal do Guardião. | Arquétipo assassino (futuro) |
| 9 | **Gancho de Raízes** | "A ilha me puxa" | Projétil 10 u; em ponto de ancoragem (árvore/ruína) puxa o jogador a 14 u/s; em inimigo leve, puxa o inimigo. CD 8 s. | Travessia de cânions; puxar atirador para o tanque. | Utilidade de santuário (todas as classes) |
| 10 | **Deslizar na Água** | "Patino sobre o lago" | Correr na água rasa/funda por até 2,0 s a 6 u/s após qualquer dash; termina em afundamento leve (volta à margem, −5 % HP). CD passivo. | Blink → deslizar para cruzar lago grande. | Poder de santuário (lago) |

## 2. Game feel de movimento

- **Buffer**: input de movimento nos últimos 0,15 s de qualquer lock entra na fila (prioridade sobre ataque se ambos chegaram na mesma janela). Só o último fica.
- **Cancelamentos**: movimento cancela recovery de qualquer ataque a partir de `recovery_cancel_at`; esquiva/blink cancela **windup** de casts com `movement_cancel=true` (sem gastar mana/CD). Ataque pode cancelar os últimos 0,08 s de um dash ("dash-attack").
- **Direção**: dash/blink usa a direção do analógico/WASD; sem input, usa a direção do cursor; nunca "para trás" por padrão.
- **Hitstop**: só visual e local (regra do spec do Mago). Investida 40 ms por alvo atravessado (máx. 80 ms total); Salto Sísmico 90 ms; blinks: 0 ms (fluidez > peso).
- **Câmera**: lead suave de 0,6 u na direção do movimento; no blink a câmera segue com amortecimento de 0,10 s (não corta seco); shake só no impacto (Salto 0,4 trauma). Respeita `screen_shake_scale`.
- **Leitura visual** (assinatura aprovada): saída = dissolve 0→1 em 0,12 s + faíscas; 3 **fantasmas** ao longo do trajeto (alpha 0,6→0, 0,25 s); chegada = onda de choque no chão. Cada habilidade troca a cor e a forma do fantasma: Eco = âncora azul pulsante com fio de luz até o jogador; Passo de Brasa = rastro laranja com brasas; Investida = linhas de velocidade + poeira.
- **Telegrafia**: destino de Salto e de Troca mostra marcador antes de confirmar (mira) ou um flash de 0,1 s (quick-cast). Inimigos sempre telegrafam ≥ 0,35 s, para que i-frames sejam uma escolha de timing, não sorte.
- **I-frames legíveis**: durante i-frames o personagem pisca contorno branco a 20 Hz; um "esquivou!" pequeno quando um golpe é evitado por i-frame (feedback de competência).

## 3. Loop inicial (30–45 min)

**0–10 min — Pátio de Treino (NPC Instrutora Lyra).** Escalonamento: cada mecânica sozinha, depois combinada.
1. *Andar e esquivar*: boneco lança bolas lentas; 3 esquivas com i-frame liberam o próximo.
2. *Riacho*: riacho de 5 u de largura sem ponte; só o blink atravessa. Falha = cai na água rasa e volta à margem (sem dano).
3. *Percurso cronometrado*: 6 portais de luz; ouro ≤ 22 s, prata ≤ 30 s, bronze = completar. Ouro dá cosmético de rastro.
4. *Bonecos móveis*: 3 bonecos em trilho (2 u/s); acertar os 3 em 15 s; um deles só é atingível após blink para o outro lado da cerca.
5. *Recompensa*: Eco de Aethra (âncora) ou Investida, conforme a classe.

**10–25 min — Gruta das Raízes (NPC Ferreiro Oran pede o "Lingote de Brasa").**
- Armadilhas: placas de espinho (telegraph 0,5 s → esquiva), jatos de fogo em corredor alternando (ritmo de 1,2 s → blink/Corrente), vão sobre água funda (blink obrigatório), sala de pedras rolantes (âncora para voltar após pegar o baú).
- 2 encontros pequenos (Slimes) e uma sala secreta atrás de parede atravessável só por blink (explorador).
- Recompensa: item com atributos (botas "Passos de Cinza": +6 % move_speed, −10 % CD de esquiva) e a quest entrega o **Passo de Brasa** (Mago) / **Salto Sísmico** (Guerreiro).

**25–45 min — Bando da Clareira Queimada (meso-loop com fogueira).**
- Composição base (5): 2 **Avançadores** (Slime Saltador), 1 **Tanque** (Guardião de Musgo), 1 **Atirador** (Oráculo de Brasa), 1 **Invocador** (novo: Xamã de Cogumelo, invoca 2 esporos a cada 8 s, HP baixo, foge).
- Comportamento de grupo (servidor): no máximo **2 atacantes ativos** por jogador ao mesmo tempo (token de ataque); tanque se posiciona entre jogador e atirador; atirador mantém 6–9 u; invocador fica atrás do tanque. Sem tokens livres, os demais circulam ("position").
- Leitura correta: mover-se para quebrar a formação (Troca/Investida no atirador), não ficar parado trocando dano.
- Recompensa final: peça do conjunto Piromante (ou equivalente do Guerreiro) + fogueira acesa + caminho para o Santuário.

## 4. Fórmulas e tuning knobs

```
dist_blink_real = min(blink_range, dist_até_primeiro_bloqueio − raio_capsula)
recall_valido   = (t_agora − t_blink) ≤ anchor_duration  E  âncora em navmesh/água
burn_rastro     = 1 acúmulo por alvo a cada trail_tick (respeita burn_max_stacks=5)
dano_investida  = (charge_base + 0.6 × attack_power) × (1 − mitig)   // mitig da fórmula B
mobilidade_por_min = 60 / cd_efetivo   // alvo: blink ≤ 10/min, esquiva ≤ 50/min
```
Exemplo: blink de 7 u com parede a 4,2 u e raio de cápsula 0,4 → teleporta 3,8 u.

| Knob | Default | Range | Categoria | Razão |
|---|---|---|---|---|
| `blink_range` | 7 u | 5–9 | gate | ~1,7 s de caminhada salvos |
| `blink_iframe_start/end` | 0,12/0,32 s | — | feel | i-frame só enquanto invisível |
| `anchor_duration` | 3,0 s | 2–5 | gate | tempo para "testar" uma posição |
| `echo_cd` | 6 s | 4–10 | gate | blink livre (0,55 s) era só protótipo |
| `echo_cost` | 10 mana | 0–20 | curve | ~½ Bola de Fogo |
| `ember_trail_duration` | 2,5 s | 1,5–4 | curve | |
| `ember_trail_tick` | 0,5 s | 0,3–1 | curve | evita empilhar 5 em 1 passo |
| `dodge_cd` | 1,2 s | 0,6–2 | gate | |
| `charge_distance` | 6 u | 4–8 | gate | |
| `charge_base / poise` | 18 / 25 | 10–30 / 15–40 | curve | interrompe canal do Oráculo |
| `charge_cd` | 7 s | 5–12 | gate | |
| `move_input_buffer` | 0,15 s | 0,08–0,25 | feel | |
| `camera_lead` | 0,6 u | 0–1,2 | feel | |
| `attack_tokens_per_player` | 2 | 1–3 | gate | dificuldade do bando |

Todos em `assets/data/abilities/movement.json` e `assets/data/ai/pack_rules.json`.

## 5. Critérios de aceite — 3 primeiras

**Ordem recomendada: (1) Eco de Aethra, (2) Passo de Brasa, (3) Investida Perfurante.** Eco reaproveita o blink já aprovado e adiciona uma decisão (voltar ou não) — maior ganho de profundidade por hora. Passo de Brasa liga movimento ao loop de Queimadura/Ignição já existente (movimento vira dano, não só fuga). Investida dá ao Guerreiro mobilidade ofensiva e resolve o counter do Oráculo previsto no GDD.

Eco de Aethra
- [ ] Blink com parede a 4,2 u termina a 3,8 u (teste unitário com cápsula 0,4).
- [ ] Golpe que chega entre 0,12 e 0,32 s não causa dano; fora disso causa.
- [ ] Reativar em ≤ 3,0 s volta à âncora; após 3,0 s a âncora some e o CD começa.
- [ ] Blink sobre riacho de 5 u funciona; contra parede nunca atravessa.
- [ ] Sem mana suficiente: não executa e mostra feedback "sem mana".

Passo de Brasa
- [ ] Inimigo parado no rastro por 2,5 s recebe exatamente 5 acúmulos (tick 0,5 s), nunca mais que `burn_max_stacks`.
- [ ] Rastro não é criado sobre água.
- [ ] Esquiva no windup da Bola de Fogo cancela sem gastar mana nem iniciar CD.

Investida Perfurante
- [ ] Atravessa 3 Slimes em linha, aplicando dano e poise uma vez a cada.
- [ ] Para no primeiro elite/boss e na borda de água funda.
- [ ] Interrompe o canal de 1,4 s do Oráculo (teste de integração).
- [ ] Hitstop total ≤ 80 ms mesmo atravessando 5 alvos.

Experiencial (playtest, 3 jogadores): ≥ 2 de 3 usam a âncora de forma intencional no bando sem instrução extra; o percurso cronometrado é refeito voluntariamente por ≥ 1 jogador.

## 6. Perguntas em aberto

1. Blink livre (CD 0,55 s do protótipo) ou blink com CD real (6 s)? O livre é divertido, mas torna a esquiva redundante e trivializa armadilhas.
2. Mobilidade é por classe ou existe um "slot de movimento" equipável (poderes de santuário como Gancho e Deslizar valem para todas)?
3. Cargas (2 blinks e recarga) ou CD simples?
4. Em co-op, a Troca Arcana pode trocar com aliados?
5. Percurso cronometrado deve ter ranking entre amigos (co-op) ou só medalhas locais?
6. O Invocador (Xamã de Cogumelo) entra no MVP ou o bando inicial fica com 4 papéis já existentes?
