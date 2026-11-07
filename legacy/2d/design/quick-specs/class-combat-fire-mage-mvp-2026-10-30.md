# Quick Design Spec: Sistema de Classes e Combate — MVP Mago de Fogo

**Type**: New Small System
**Scope**: Define o esquema modular de atributos e classes (só dados) e implementa o kit de combate completo do Mago de Fogo, com game feel, para um MMORPG 2D top-down. Ficam **de fora**: rede e replicação, itens e equipamentos, progressão além do nível 1–10 e as outras classes (aparecem só como perfis de dados de exemplo).
**GDD Reference**: nenhum ainda (sem GDD nem game brief no projeto). Este spec é o registro de design.
**Date**: 2026-10-30
**Estimated Implementation**: ~32–40 h (esquema 8 h · kit do Mago 14 h · game feel 10 h · testes 6 h)

## Overview

Toda entidade de combate (jogador ou inimigo) tem um **AttributeSet**: um dicionário `stat_id → valor` montado a partir de uma **ClassDefinition** em dados. Os atributos primários alimentam os derivados por **coeficientes definidos por classe**, e é isso que permite adicionar Guerreiro, Paladino e Arqueiro sem mudar código, só JSON. As habilidades também são dados: uma **AbilityDefinition** é uma lista de **Effects** componíveis (`damage`, `aoe`, `dot`, `knockback`, `projectile`). O Mago de Fogo é o primeiro caso de teste: lança fogo no alvo selecionado e transforma inimigos agrupados em explosões em área. O game feel vem de hit-stop local, flash de impacto, screen shake e um buffer de input que deixa o kit fluido.

## Core Rules

### A. Esquema modular de atributos

1. **Atributos primários** (globais, em `attributes.json`): `STR`, `AGI`, `INT`, `VIT`, `SPI`.
2. **Atributos derivados**: `max_hp`, `max_resource`, `resource_regen`, `attack_power`, `spell_power`, `armor`, `resist`, `crit_chance`, `haste`, `move_speed`.
3. Fórmula genérica de cada derivado, usando os coeficientes da classe:
   `derived = class.base[derived] + Σ (primary_i × class.coeff[derived][primary_i]) + level × class.growth[derived]`
4. **Recurso** (`resource_type`) declarado pela classe: `mana` no Mago, `rage` no Guerreiro, `faith` no Paladino, `focus` no Arqueiro. Cada tipo tem regras de regeneração em `resources.json` (a mana regenera com o tempo; a rage, por exemplo, ganharia ao causar e receber dano).
5. **Modificadores** (buffs e debuffs) entram como `{stat, op: add|mult, value, duration, source_id}`. Ordem de aplicação: soma dos `add`, depois produto dos `mult`. Uma mesma fonte não acumula consigo mesma, a menos que o efeito declare `stacks`.
6. Perfis de exemplo, só dados, sem kit: Guerreiro (STR/VIT → attack_power/armor, rage), Paladino (STR/SPI → attack_power/spell_power, faith), Arqueiro (AGI → attack_power/crit, focus).

### B. Fórmula de dano (compartilhada por todas as classes)

```
raw       = ability.base + ability.scaling × caster[ability.power_stat]
crit_mult = (rand < caster.crit_chance) ? crit_damage_mult : 1.0
mitig     = target[defense_stat] / (target[defense_stat] + mitigation_K)
final     = round(raw × crit_mult × (1 − mitig) × aoe_falloff)
```
- `power_stat` = `spell_power` para fogo e `defense_stat` = `resist` para dano mágico (`armor` para físico).
- `aoe_falloff` = 1.0 dentro de `inner_radius` e cai linearmente até `falloff_min` na borda do `radius`.
- O RNG é injetado (seedável) para manter os testes determinísticos.

### C. Targeting (tab-target)

1. `Tab` alterna entre os inimigos visíveis, do mais próximo ao mais distante, dentro de `target_acquire_range`. Clicar num inimigo também o seleciona.
2. Habilidades `target: enemy` exigem alvo válido, vivo e dentro de `range`. Sem isso o cast não começa e aparece o feedback "fora de alcance" (texto curto mais um pulso vermelho no anel do alvo).
3. Projéteis são **teleguiados** e sempre acertam se o alvo continuar vivo. Se o alvo morrer no caminho, o projétil termina no último ponto conhecido e detona as AoEs ali.
4. AoEs `centered_on: target` usam a posição do alvo **no momento do impacto**, e `centered_on: self` usa a do mago.

### D. Fluxo de cast e fluidez

1. Estados do caster: `Idle → Casting → Releasing → Recovery → Idle`. O GCD começa no início do cast.
2. **Spell queue**: um input recebido nos últimos `spell_queue_window` do GCD ou do cast fica guardado e dispara automaticamente no primeiro frame livre.
3. **Movimento durante cast**: andar cancela casts com `cast_time > 0` (o recurso não é gasto e o cooldown não começa). Habilidades instantâneas podem ser usadas em movimento.
4. **Recovery cancelável**: depois do frame de release, mover ou lançar outra habilidade interrompe a animação de recovery imediatamente. A animação nunca prende o jogador.
5. O personagem vira para o alvo no início do cast, usando a direção cardinal mais próxima entre as 4.

### E. Kit do Mago de Fogo (MVP)

| # | Habilidade | Tipo | Cast | CD | Custo | Alcance | Efeito |
|---|---|---|---|---|---|---|---|
| 0 | **Fagulha** (`fire_spark`) | Básico, projétil | 0.0 s | GCD | 0 | 320 px | Dano baixo, aplica 1 acúmulo de **Queimadura** |
| 1 | **Bola de Fogo** (`fireball`) | Projétil + AoE | 1.2 s | GCD | 18 mana | 320 px | Dano alto no alvo e explosão de raio 56 px com falloff. Aplica 2 acúmulos de Queimadura em todos os atingidos |
| 2 | **Pilar de Chamas** (`flame_pillar`) | AoE no solo, atrasada | 0.0 s | 8 s | 25 mana | 288 px | Telegraph de 0.6 s na posição do alvo, depois erupção de raio 64 px, knockback radial de 48 px e o maior hit-stop do kit |
| 3 | **Anel de Fogo** (`fire_nova`) | PBAoE | 0.0 s | 12 s | 20 mana | self | Explosão de raio 80 px ao redor do mago, knockback de 72 px para fora. Ferramenta de fuga |
| P | **Ignição** (passiva) | Interação | — | — | — | — | Bola de Fogo num alvo com ≥ 3 acúmulos de Queimadura **detona** todos: dano instantâneo = acúmulos × `ignite_per_stack`, e os acúmulos são consumidos |

**Queimadura** (DoT): `burn_tick_damage` por acúmulo a cada `burn_tick_interval`, até `burn_max_stacks`. Cada nova aplicação renova a duração (`burn_duration`).

**Loop pretendido**: Fagulha e Bola de Fogo empilham Queimadura → a Bola de Fogo detona a Ignição para o pico de dano → o Pilar pune grupos → o Anel cria espaço quando o mago é cercado.

### F. Game feel (impacto e fluidez)

> **Regra MMO crítica**: o hit-stop é **só visual e local**. Ele congela a animação e os VFX do atacante e da vítima no cliente, mas **nunca** altera o `time_scale` global nem a simulação. Assim fica compatível com servidor autoritativo no futuro.

| Camada | Leve (Fagulha, tick de Queimadura) | Médio (Bola de Fogo, Anel) | Pesado (Pilar, Ignição) |
|---|---|---|---|
| Hit-stop (só sprites envolvidos) | 0 ms | 50 ms | 90 ms |
| Flash branco na vítima | 50 ms | 70 ms | 90 ms |
| Screen shake (trauma 0–1, decaimento quadrático) | 0.0 | 0.25 | 0.5 (só quando o caster é o jogador local) |
| Squash da vítima | — | 0.9× por 80 ms | 0.85× por 100 ms |
| Número de dano | pequeno, cinza-laranja | médio, laranja | grande, amarelo com borda. Crit = escala 1.4× com pop |
| Partículas | 4 brasas | 12 brasas + anel de fumaça | 24 brasas, decal de chão queimado (3 s), flash de luz 2D |

- **Antecipação**: o frame de release do ataque (frame 4 de 6) dispara o projétil ou o efeito. O VFX de carga nas mãos aparece já no frame 1.
- **Telegraph** do Pilar: um círculo no chão que pulsa e enche de 0 a 100 % em 0.6 s, para que o impacto pareça merecido.
- **Hit-stop em AoE**: se vários alvos forem atingidos no mesmo frame, aplica **um único** hit-stop (do tier mais alto), sem somar.
- **Knockback**: curva ease-out em `knockback_duration`. A vítima não age durante o knockback.
- Todos os efeitos de feel respeitam a opção de acessibilidade `screen_shake_scale` (0–1) e o toggle `reduce_flashes`.

### G. Contrato com a animação (alimenta o /asset-spec)

| Animação | Frames | FPS | Loop | Eventos |
|---|---|---|---|---|
| `idle` | 4 | 6 | sim | — |
| `walk` | 6 | 10 | sim | — |
| `attack` (cast) | 6 | 12 | não | f1: VFX de carga · **f4: release** · f5–f6: recovery cancelável |

- 4 direções: `down`, `up`, `right`, e `left` = espelho de `right`. Célula de **64×64 px**, personagem com ~44 px de altura, pivô nos pés (32, 58).
- Casts mais longos que a animação (Bola de Fogo, 1.2 s) seguram os frames 2–3 em loop até o release.

## Tuning Knobs

| Knob | Default | Range | Category | Rationale |
|---|---|---|---|---|
| `mitigation_K` | 100 | 50–300 | curve | Com 100 de resist, mitiga 50 %: legível |
| `crit_damage_mult` | 1.5 | 1.25–2.0 | curve | Crit relevante sem dominar o dano |
| `gcd` | 0.75 s | 0.5–1.5 | feel | Mais rápido que MMOs clássicos (1.5 s), favorece a fluidez |
| `spell_queue_window` | 0.2 s | 0.1–0.4 | feel | Elimina a sensação de input perdido |
| `target_acquire_range` | 400 px | 256–640 | gate | Um pouco mais que o maior alcance |
| `fireball_cast_time` | 1.2 s | 0.8–2.0 | feel | Risco e recompensa: o cast mais longo do kit |
| `fireball_aoe_radius` | 56 px | 32–96 | gate | ~2 inimigos de 32 px agrupados |
| `aoe_inner_radius_ratio` | 0.5 | 0.3–1.0 | curve | Centro recompensa a precisão |
| `aoe_falloff_min` | 0.6 | 0.3–1.0 | curve | A borda ainda dói |
| `flame_pillar_telegraph` | 0.6 s | 0.3–1.0 | feel | Legível em PvE, esquivável em PvP |
| `burn_tick_damage` | 3 | 1–10 | curve | Por acúmulo, por tick |
| `burn_tick_interval` | 1.0 s | 0.5–2.0 | curve | — |
| `burn_duration` | 6 s | 3–10 | curve | — |
| `burn_max_stacks` | 5 | 3–10 | gate | — |
| `ignite_threshold` | 3 | 2–5 | gate | Exige ~2 casts de preparação |
| `ignite_per_stack` | 12 | 5–25 | curve | O pico de dano do kit |
| `hitstop_ms` (leve/médio/pesado) | 0/50/90 | 0–150 | feel | Acima de ~120 ms começa a parecer travamento |
| `shake_trauma` (médio/pesado) | 0.25/0.5 | 0–1 | feel | — |
| `knockback_duration` | 0.18 s | 0.1–0.3 | feel | — |
| `mage_move_speed` | 120 px/s | 80–180 | feel | Pouco menos de 2 células por segundo |

Todos os valores ficam em `assets/data/`, nunca no código: `attributes.json`, `resources.json`, `classes/*.json`, `abilities/fire_mage.json` e `combat_feel.json`.

## Acceptance Criteria

- [ ] Uma nova classe (ex.: Guerreiro) é adicionada **só com JSON** e calcula os derivados corretos (teste unitário com valores conhecidos)
- [ ] A fórmula de dano bate com cálculos de referência para crit/sem crit, mitigação 0/50/75 % e falloff na borda e no centro (testes unitários com RNG seedado)
- [ ] Bola de Fogo num alvo com 3+ acúmulos detona a Ignição, consome os acúmulos e causa `stacks × ignite_per_stack` de dano extra
- [ ] Mover durante a Bola de Fogo cancela o cast sem gastar mana nem iniciar o cooldown
- [ ] Um input dado até 0.2 s antes do fim do GCD é executado automaticamente. Nenhum input é perdido nesse intervalo
- [ ] Projétil cujo alvo morre no caminho detona no último ponto conhecido
- [ ] O hit-stop congela só os sprites envolvidos: outras entidades e a simulação continuam (verificado numa cena com 2 inimigos fora da AoE)
- [ ] AoE que atinge 5 alvos aplica um único hit-stop, não cinco
- [ ] **Experiencial (playtest)**: o Pilar de Chamas "pesa" mais que a Bola de Fogo, e a sequência Fagulha → Bola de Fogo → Bola de Fogo (Ignição: 1 + 2 = 3 acúmulos antes da segunda Bola de Fogo) dá um pico de dano que se sente
- [ ] Evidência: screenshot de cada tier de impacto retido em `production/qa/evidence/`
- [ ] `screen_shake_scale = 0` remove todo o tremor de tela

## Systems Index

Ainda não existe `design/gdd/systems-index.md`. Quando houver `/map-systems`, este sistema entra como **Core / Fundação** (prioridade MVP), e o esquema de atributos vira dependência de itens, progressão e IA de inimigos. Se o escopo crescer (rede, mais classes jogáveis), recomendo promovê-lo a GDD completo via `/design-system`.
