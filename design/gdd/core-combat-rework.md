# Core Combat Rework — Draft

## Summary

Refatorar o núcleo de combate de **Ecos de Aethra** para que Mago de Fogo e Guerreiro tenham loops distintos, responsivos e combináveis, sem vitória por apertar uma única habilidade. O recorte imediato entrega os dois kits completos, um sistema pequeno de combo/poise e três arquétipos de inimigo data-driven. Bosses e famílias adicionais usam o mesmo contrato, mas ficam para uma segunda entrega depois do loop básico ser validado em playtest.

O servidor continua autoritativo sobre recurso, cooldown, dano, estados, IA e resolução dos golpes. O cliente apenas antecipa animação/VFX, envia intenção e reproduz eventos confirmados.

## Overview

### Pilares

1. **Leitura antes de punição:** ataques fortes têm antecipação visual e sonora; dano inevitável é baixo.
2. **Básico cria escolha:** o ataque sem custo prepara recursos ou estados, não é só preenchimento.
3. **Setup → conversão → saída:** combos fortes exigem pelo menos duas ações coerentes e oferecem janela para reação.
4. **Sem delete acidental:** uma habilidade isolada não remove mais de 25% da vida de um jogador equivalente; uma janela completa de combo bem executado mira 35–45% em PvP.
5. **Inimigo é um problema, não um saco de HP:** cada arquétipo pede posicionamento ou resposta diferente.
6. **Impacto legível:** antecipação, frame de contato, recoil, flash, número, som e recovery têm pesos coerentes.

### Escopo imediato

- Mago de Fogo: Fagulha, Bola de Fogo, Pilar e Anel, com Queimadura/Ignição revisadas.
- Guerreiro: combo de três golpes no ataque básico, Investida, Grito de Guerra e Redemoinho.
- Sistemas compartilhados: combo window, poise/stagger, tags de estado, cooldown/GCD por habilidade, eventos de telegraph e ataque inimigo.
- Três inimigos representativos: simples (Slime Saltador), intermediário (Guardião de Musgo) e especial (Oráculo de Brasa).
- Feedback procedural suficiente para prototipar enquanto sprites finais não chegam.

### Fora desta entrega

- Boss completo, loot, equipamentos, progressão acima do loop já existente, novas classes e árvore de talentos.
- Refazer toda a arte. A entrega só define o novo contrato de sprites e usa escala, inclinação, sombra, trail e tint como ponte visual.
- PvP competitivo/rankeado. O duelo serve apenas para impedir explosões de dano absurdas no mesmo ruleset.

## Detailed Design

### 1. Cadência, fila e cancelamento

- Cada habilidade pode sobrescrever `gcd`, `windup`, `active` e `recovery`; o valor global é fallback.
- Input nos últimos `queue_window = 0,20 s` do lock atual é guardado. Só o último input fica na fila.
- Movimento cancela apenas casts marcados `movement_cancel = true`; não consome recurso nem inicia cooldown antes do release confirmado.
- Recovery pode ser cancelado por movimento depois de `recovery_cancel_at` e por outra habilidade quando GCD terminar.
- O servidor valida uma sequência monotônica de `cast_sequence`; pedidos repetidos ou antigos são descartados.
- Ataque básico usa quick-cast para a posição do cursor. Habilidades de área continuam aceitando mira/confirmar; uma opção futura permite quick-cast para todas.

### 2. Sistema compartilhado de combo

Cada `ClassKit` mantém no servidor:

- `combo_id`, `combo_step`, `combo_expires_at`;
- estados de alvo com `source_peer`, `tag`, `stacks`, `expires_at`;
- `last_confirmed_hit_at`, para combo depender de acerto e não só de animação.

Uma etapa só avança quando o golpe acerta um alvo válido. Errar, ser derrubado ou deixar a janela vencer reinicia a cadeia. Trocar de alvo não quebra combos de classe, mas estados como Queimadura pertencem ao alvo atingido.

### 3. Poise e stagger

- Inimigos têm `max_poise`, regeneração após 2 s sem receber poise damage e resistência a controle por categoria.
- Golpes causam `poise_damage`. Ao chegar a zero, ocorre `stagger` e o poise volta cheio após o estado.
- Ataques simples de jogador sofrem só micro-reação visual; não travam simulação ou IA.
- Elites e bosses nunca entram em stunlock: após um break recebem `stagger_immunity` por 3–6 s.
- Knockback, stun e stagger são resolvidos no servidor e replicados como eventos com duração.

### 4. Mago de Fogo

**Fantasia:** preparar o campo, acumular calor e converter a preparação em uma explosão satisfatória. É forte a média distância e frágil quando cercado.

| Ação | Papel | Regra revisada |
|---|---|---|
| Fagulha | básico/setup | Quick-cast, GCD 0,55 s, dano leve, 1 Queimadura. A terceira Fagulha consecutiva em até 1,25 s ganha projétil mais largo e +40% poise damage, sem multiplicador grande de dano. |
| Bola de Fogo | conversão | Cast 0,90 s, custo 16, dano médio e 2 Queimaduras. Se o alvo já tinha 3+ stacks **antes do impacto**, consome até 5 e ativa Ignição. |
| Pilar de Chamas | leitura/controle | Telegraph 0,70 s, CD 8 s, custo 22. Causa dano alto e muito poise; em alvo queimando, renova a duração mas não consome stacks. |
| Anel de Fogo | saída | CD 10 s, custo 18. Dano baixo, knockback alto e 0,35 s de resistência a stagger para o mago. Não detona Ignição. |

**Combos pretendidos**

1. `Fagulha ×3 → Bola de Fogo`: pico de alvo único; exige permanência e cast legível.
2. `Pilar → Fagulha → Bola de Fogo`: combo de controle; Pilar abre break, Fagulha completa setup e Bola converte.
3. `Anel → Pilar na rota de retorno`: cria espaço e pune perseguidor, mas gasta 40 mana e não pode ser repetido.
4. `Fagulha ×3` sem conversão: opção eficiente para conservar mana e quebrar poise.

**Ignição**

- Lê os stacks existentes antes de a Bola aplicar seus próprios 2 stacks.
- Dano: base por stack com teto explícito; consome os stacks lidos, depois aplica os 2 stacks novos da Bola.
- Em PvP recebe multiplicador próprio menor e nunca ignora resist.
- Não pode critar separadamente; herda o crit da Bola apenas para VFX, evitando dupla rolagem explosiva.

### 5. Guerreiro

**Fantasia:** encurtar distância, construir ritmo corpo a corpo, quebrar postura e gastar Fúria no momento certo. Sobrevive por decisão e contato, não por dano passivo alto.

**Golpe Pesado torna-se sequência básica de três etapas** dentro de `combo_window = 1,05 s`:

| Etapa | Perfil | Efeito |
|---|---|---|
| 1 — Corte | 0,90× dano, arco 100° | aproximação procedural de 6 px, 10 Fúria no acerto |
| 2 — Retorno | 1,00× dano, arco 125° | atinge melhor grupos próximos, 10 Fúria |
| 3 — Quebra | 1,35× dano, arco 85° | windup maior, +80% poise damage, knockback curto, 16 Fúria |

- Cada etapa tem windup/recovery próprio; a etapa 3 não pode sair sem dois acertos confirmados.
- Errar reinicia a sequência e dá recovery um pouco maior, impedindo spam sem alvo.

| Ação | Papel | Regra revisada |
|---|---|---|
| Investida | aproximação/setup | CD 7 s. Para no primeiro alvo/obstáculo, causa dano leve, aplica `off_balance` por 1,2 s e dá 12 Fúria. Não atravessa o alvo. |
| Grito de Guerra | defesa/risco | CD 14 s. 30% redução por 4 s, taunt e 10 Fúria. Se receber golpe telegrafado durante os primeiros 0,45 s, ganha `resolve`: próximo Quebra causa +35% poise, não +dano. |
| Redemoinho | gasto/área | Custa 35 Fúria, CD 5 s. Três ticks com dano reduzido por tick; o último causa poise e knockback. Movimento a 55% durante a execução. |

**Combos pretendidos**

1. `Corte → Retorno → Quebra`: loop seguro, dano eficiente e break.
2. `Investida → Corte → Retorno → Quebra`: perseguição; `off_balance` melhora poise damage da cadeia, não explode HP.
3. `Grito (timing) → cadeia → Quebra`: resposta defensiva que acelera break.
4. `Corte → Retorno → Redemoinho`: troca o finisher de alvo único por controle de grupo, gastando Fúria.
5. `Investida → Redemoinho`: entrada rápida em grupo, com custo e cooldown suficientes para exigir saída planejada.

### 6. Arquétipos de inimigo

Todos usam uma máquina de estados compartilhada (`idle`, `pursue`, `position`, `telegraph`, `active`, `recover`, `stagger`, `return`) e uma lista data-driven de ações com condições, peso, distância, cooldown e fases. A IA escolhe somente no servidor.

#### Simples — Slime Saltador

- Papel: ensina esquiva e punish.
- Moveset: aproxima até 52 px; mostra squash de 0,35 s; salta em linha reta; contato existe só na janela ativa de 0,18 s; recovery de 0,70 s.
- Fraqueza: poise baixo; qualquer finisher coerente interrompe o preparo.
- Não rastreia o jogador depois que o salto começa.

#### Intermediário — Guardião de Musgo

- Papel: bloqueador de espaço, vida/poise médios.
- Moveset: (1) golpe frontal em cone após 0,60 s; (2) pisão circular após 0,85 s quando cercado; (3) guarda frontal de 1,2 s que reduz dano frontal, mas deixa costas vulneráveis.
- Regra: alterna ações, proibindo repetir o mesmo golpe mais de duas vezes.
- Resposta: flanquear a guarda, usar Anel para reposicionar ou quebrar poise com Quebra/Pilar.

#### Especial — Oráculo de Brasa

- Papel: prioridade tática e controle de arena; HP menor que o Guardião.
- Moveset: (1) projétil lento em rajada de 3; (2) círculo de brasa com telegraph de 0,90 s; (3) canal de 1,4 s que fortalece outro inimigo até ser interrompido.
- Mantém distância de 120–190 px, mas não recua através de parede ou para fora da área de retorno.
- Resposta: Investida interrompe canal; Bola/Pilar punem posição; básico conserva recurso enquanto desvia das rajadas.

#### Contrato futuro de elite/boss

- `rank`: normal, intermediate, special, elite, boss.
- `phases`: condições de HP/tempo e conjunto de ações por fase.
- `action_deck`: impede repetição degenerada e permite pesos condicionais.
- `break_rules`: poise por fase, imunidade pós-break e ações interrompíveis.
- `enrage`: limite de tempo opcional, nunca necessário em mobs comuns.
- Boss futuro deve ter 3–5 ações por fase, pelo menos uma janela clara de punish e nenhuma combinação inevitável.

### 7. Feedback visual e contrato de sprites

O sprite atual não precisa carregar sozinho toda a leitura. No protótipo:

- windup inclina/estica a silhueta na direção oposta ao golpe;
- frame ativo usa trail curto e deslocamento da arma/corpo;
- contato gera recoil de 2–5 px, sombra comprimida, flash por tier e partículas direcionais;
- recovery retorna por easing, sem teleportar a pose;
- ataque 1/2/3 do Guerreiro recebe trail e deslocamento distintos mesmo antes de novos frames;
- terceira Fagulha, Ignição, Quebra e break de poise têm assinatura visual exclusiva;
- telegraphs usam forma + cor + animação, sem depender apenas de vermelho/verde.

Contrato mínimo para o sprite revisado por classe: idle 4 frames, walk 6, três ataques básicos de 5–7 frames, cast curto 6, cast longo 8, hit 3, down 4; down/up/right e left espelhado quando seguro. Até esses sprites existirem, o sistema procedural acima é obrigatório.

## Formulas

### Dano

```text
raw = ability.base + ability.scaling × caster[power_stat]
mitigation = defense / (defense + mitigation_K)
final = round(raw × combo_step_mult × crit_mult × (1 - mitigation) × falloff × mode_mult)
```

- `combo_step_mult` do Guerreiro: 0,90 / 1,00 / 1,35.
- `crit_mult = 1,5`; Ignição e DoT não fazem nova rolagem de crit.
- `mode_mult` usa o multiplicador PvP existente e pode ter ajuste por efeito (`pvp_mult`).

### Ignição

```text
consumed = min(pre_hit_burn_stacks, ignite_max_stacks)
ignite_raw = consumed × ignite_per_stack + caster.spell_power × ignite_scaling
ignite_final = round(ignite_raw × (1 - resist_mitigation) × mode_mult)
```

Alvo inicial: `ignite_per_stack = 7–9`, `ignite_scaling = 0,20–0,30`, máximo 5. O número final deve representar aproximadamente 20–25% do HP de um mob simples ou 10–15% do HP de um jogador equivalente, nunca uma execução isolada.

### Poise

```text
poise_damage = ability.poise × combo_poise_mult × target.control_taken_mult
new_poise = max(0, current_poise - poise_damage)
```

Ao quebrar: `stagger_duration = clamp(base_stagger × target.stagger_mult, 0,60, 1,40)`.

### Limites de burst e TTK

- Uma habilidade isolada contra jogador equivalente: 8–25% do HP máximo após mitigação.
- Combo completo com setup, em 2,0–3,5 s: 35–45% do HP em PvP.
- Acima de 45%: reduzir `pvp_mult` do finisher, não enfraquecer PvE automaticamente.
- Crítico não pode transformar combo não letal em 100–0; o teste usa pior caso de crit em todas as partes elegíveis.

## Tuning Knobs

| Valor | Alvo inicial | Faixa segura |
|---|---:|---:|
| GCD básico do Mago | 0,55 s | 0,45–0,70 s |
| Janela Fagulha | 1,25 s | 0,9–1,6 s |
| Janela combo Guerreiro | 1,05 s | 0,8–1,35 s |
| Recovery etapa 1/2/3 | 0,18/0,20/0,34 s | 0,12–0,45 s |
| Fireball cast | 0,90 s | 0,75–1,20 s |
| Telegraph Pilar | 0,70 s | 0,55–0,95 s |
| DR Grito | 30% | 20–40% |
| Duração Grito | 4,0 s | 3–5 s |
| Poise regen delay | 2,0 s | 1,5–3 s |
| Imunidade pós-break elite/boss | 4,0 s | 3–6 s |
| Telegraph mob simples | 0,35 s | 0,28–0,50 s |
| Telegraph intermediário | 0,60–0,85 s | 0,50–1,10 s |
| Telegraph especial | 0,90–1,40 s | 0,70–1,60 s |

### Targets PvE solo, nível equivalente

| Alvo | Jogador aprendendo | Combo eficiente |
|---|---:|---:|
| Mob simples | 4–6 s | 2,5–3,5 s |
| Intermediário | 12–18 s | 8–12 s |
| Especial | 14–20 s | 10–14 s |
| Elite futuro | 25–40 s | 20–30 s |
| Fase de boss futuro | 60–90 s | 45–70 s |

Sobrevivência: Mago cai em 6–9 ataques simples não evitados; Guerreiro em 9–13. Golpe pesado telegrafado equivale a 2–2,5 ataques simples. Nenhum ataque normal isolado remove mais de 30% do HP do Mago cheio.

## Edge Cases

- Latência: o cliente pode tocar windup, mas só o evento servidor produz hit/VFX de impacto; rejeição cancela sem dano fantasma.
- Dois finishers no mesmo frame usam ordem de chegada do servidor; o segundo lê o estado já consumido.
- Troca de alvo durante cast não muda o ponto confirmado no release.
- Alvo morre antes do impacto: projétil termina no último ponto válido; AoE ainda resolve, efeitos de alvo único não buscam outro alvo.
- Combo expira durante hit-stop visual: tempo autoritativo continua; hit-stop nunca pausa relógio do servidor.
- Múltiplos jogadores aplicam Queimadura: stacks carregam `source_peer`; Ignição consome apenas stacks do caster no MVP, evitando roubo de setup.
- Knockback contra parede interrompe deslocamento sem dano adicional no MVP.
- Boss muda de fase durante stagger: termina o stagger, limpa controles e entra na nova fase com imunidade temporária.
- Inimigo sem caminho válido retorna ao home; não ataca através de obstáculo nem acumula ações na fila.
- Redemoinho atinge uma entidade no máximo uma vez por tick, mesmo com sobreposição de shapes.
- Investida é limitada e validada no servidor para impedir atravessar parede/teleporte por cliente adulterado.

## Dependencies

- `ClassKit`: fila, combo state, timings por habilidade e validação de recurso.
- `CombatWorld`: resolução de tags, poise, hit metadata, telegraphs e eventos replicados.
- `Enemy`: máquina de estados/ações data-driven no servidor; puppets só interpolam.
- `PlayerAvatar`: contratos de pose procedural e três variações de ataque básico.
- `CombatVFX`/HUD: indicadores de combo, poise break, telegraphs e assinatura dos finishers.
- `combat_abilities.json`, `combat_classes.json`, `combat_enemies.json`, `combat_rules.json`: todos os knobs; nenhum valor de balance novo deve ficar hardcoded.
- Áudio: eventos nomeados podem ser emitidos agora, mas assets/mix ficam para polish posterior.

## Acceptance Criteria

### Sensação e input

- [ ] Dez inputs consecutivos feitos dentro da queue window produzem dez ações na ordem, sem perda ou duplicação.
- [ ] Movimento cancela Bola de Fogo antes do release sem custo/cooldown; depois do release não cancela o efeito.
- [ ] Ataques básicos respondem em até 100 ms localmente (animação antecipada), sem antecipar dano.
- [ ] Recovery 1/2 pode ser cancelado nos pontos definidos; o finisher mantém recovery perceptível.

### Mago

- [ ] Fagulha ×3 tem leitura audiovisual distinta e prepara, mas não causa burst desproporcional.
- [ ] Bola só detona stacks existentes antes do impacto; consome no máximo 5 e reaplica seus 2 stacks depois.
- [ ] Ignição e DoT não fazem crit independente.
- [ ] Anel cria distância consistente sem permitir cadeia infinita de controle.

### Guerreiro

- [ ] Etapas 1/2/3 só avançam após hit confirmado e reiniciam ao errar/expirar.
- [ ] Quebra causa mais poise, mas nenhum multiplicador oculto capaz de deletar alvo.
- [ ] Investida para no primeiro obstáculo/alvo válido e não permite atravessar cenário.
- [ ] Redemoinho consome Fúria uma vez e cada alvo recebe no máximo três ticks.

### Inimigos

- [ ] Os três arquétipos rodam pela mesma máquina de ações, apenas com dados diferentes.
- [ ] Todo golpe de dano médio/pesado mostra telegraph dentro da faixa definida.
- [ ] Slime não corrige a trajetória após iniciar salto; Guardião expõe costas durante guarda; Oráculo pode ter canal interrompido.
- [ ] Elite/boss não pode ficar em stagger contínuo devido à imunidade pós-break.

### Balanceamento

- [ ] Simulação determinística mede DPS/TTK dos dois kits nos três arquétipos e nos dois perfis de jogador.
- [ ] Nenhuma habilidade isolada excede 25% do HP de jogador equivalente; combo completo fica em 35–45% no cenário PvP de referência.
- [ ] TTK PvE mediano fica dentro das faixas da tabela, com e sem combo eficiente.
- [ ] Mago e Guerreiro têm pelo menos três sequências úteis; nenhuma sequência domina alvo único, grupo, defesa e mobilidade ao mesmo tempo.

### Rede e robustez

- [ ] Dano, recurso, cooldown, combo, poise, IA e controle são exclusivamente autoritativos no servidor.
- [ ] Teste host + cliente com 150 ms RTT não produz hit duplicado, combo avançado sem acerto ou estado divergente.
- [ ] Snapshot tardio reconstrói HP, recurso, estados relevantes, poise e fase de inimigo.

### Arte provisória

- [ ] Ataques 1/2/3, terceira Fagulha, Ignição, Quebra e poise break são distinguíveis sem depender do número de dano.
- [ ] Telegraphs continuam legíveis em escala 1× e para protanopia/deuteranopia por forma e movimento.

## Sequência recomendada de implementação

1. Timings por habilidade + combo state + testes determinísticos de dano/TTK.
2. Guerreiro 1/2/3 e revisão de Queimadura/Ignição.
3. Poise/stagger compartilhado.
4. Máquina de ações e os três arquétipos inimigos.
5. Feedback procedural/HUD, depois playtest e balance-check.
6. Somente após os targets passarem: novo sprite sheet e primeiro boss usando o contrato validado.
