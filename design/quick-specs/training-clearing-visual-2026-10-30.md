# Quick Design Spec: Clareira de Treino — passe visual (Godot)

**Type**: New Small System
**Scope**: Mundo vivo e com profundidade para a Clareira de Treino, mais o mago andando. Combate fica fora (vem de `class-combat-fire-mage-mvp-2026-10-30.md`).
**GDD Reference**: nenhum (workflow minimal). Assets: `design/assets/specs/training-clearing-assets.md`, `fire-mage-assets.md`.
**Date**: 2026-10-30

## O que resolve

Feedback do playtest do protótipo HTML: "muito desenhado e solto, profundidade zero, árvores só colocadas na grama".

| Problema | Solução implementada |
|---|---|
| Objetos parecem adesivos | Sombra de contato sob tudo e AO assada no chão ao redor das árvores |
| Contorno preto em tudo | Contorno colorido (tom escuro da própria cor), só na silhueta |
| Sem luz | Rampas com variação de matiz, volume esférico, luz do cajado (PointLight2D), feixes de luz, sombra das copas com luz manchada, glow HDR, vinheta |
| Tudo parado | Vento (árvores, arbustos, samambaias), grama alta que se abre ao passar, folhas caindo, pólen, vagalumes |
| Sem vida | Borboletas, coelhos e esquilos com fuga do jogador |
| Composição aleatória | Árvores em aglomerados, vegetação na base de cada tronco, copas em primeiro plano nas bordas da tela |

## Schemas de dados

### `assets/data/world_ambience.json` (editável à mão)

| Chave | Tipo | Significado |
|---|---|---|
| `player.move_speed` | px/s | velocidade do mago |
| `player.anim_fps.{idle,walk}` | fps | taxa das animações |
| `player.staff_light_{energy,scale,color}` | — | luz do cristal do cajado (color = [r,g,b]) |
| `wind.tree_sway_px` / `tree_sway_speed` | px / rad·s | balanço do topo das árvores |
| `wind.bush_sway_px` | px | balanço de arbustos, samambaias e flores |
| `wind.grass_{sway_px,bend_px,bend_radius}` | px | vento e abertura da grama alta perto do jogador |
| `light.canvas_tint` | [r,g,b] | cor ambiente (CanvasModulate) |
| `light.canopy_shadow_{strength,drift}` | 0–1 / velocidade | sombra das copas e deriva das manchas de sol |
| `light.canopy_fade_alpha` | 0–1 | alfa da árvore quando o jogador está atrás dela |
| `light.god_rays` / `god_ray_intensity` | qtd / 0–1 | feixes de luz |
| `light.{vignette,glow_intensity,saturation,contrast}` | — | pós-processamento |
| `particles.{leaves,pollen,fireflies}` | qtd | partículas de ambiente |
| `critters.*_flee_px` | px | distância em que cada bicho foge |
| `critters.rabbit_{hop,flee}_speed`, `squirrel_run_speed` | px/s | velocidades |
| `critters.squirrel_hide_seconds` | [min,max] s | tempo escondido na copa |

### `assets/data/clearing_layout.json` (gerado — não editar à mão)

Saída de `tools/art/gen_art.gd`. `world` [w,h] · `player_start` [x,y] · `tree_variants[]` {name, texture, pivot, radius, canopy [w,h], canopy_v, shadow} · `trees[]` {x, y, v, r} · `props[]` {kind, x, y, v, r?} · `critters[]` {kind, x, y, v, tree?}. Para mudar o mapa, mude o gerador e rode de novo.

## Como regenerar a arte

```
godot --headless --path . -s res://tools/art/gen_art.gd
godot --headless --path . --import
```

A arte final substitui os PNGs em `assets/art/` com o mesmo nome e tamanho.

## Acceptance Criteria

- [x] A cena abre e roda sem erros de script (verificado com `--write-movie`, 150 frames)
- [x] Evidência: `production/qa/evidence/godot-clearing-01-ambience.png`
- [ ] Playtest: grama se abre ao passar; árvore fica translúcida com o mago atrás; coelhos, esquilos e borboletas fogem
- [ ] Playtest: sensação de "estar dentro da floresta", e não de objetos colados num fundo
