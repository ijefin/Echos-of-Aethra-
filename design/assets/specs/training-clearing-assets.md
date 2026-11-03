# Asset Specs — Level: Clareira de Treino (floresta)

> **Source**: pedido da sessão de 2026-10-30 (mapa para testar o combate do Mago de Fogo) + design/quick-specs/class-combat-fire-mage-mvp-2026-10-30.md
> **Art Bible**: design/art/art-bible.md (seções 1–4, 6, 8)
> **Brief**: design/game-brief.md (Ecos de Aethra)
> **Generated**: 2026-10-30 · **Revised**: 2026-10-30 (alinhado ao art bible; ASSET-013..018 adicionados)
> **Review**: modo Solo. art-director e technical-artist não foram consultados nesta revisão; specs derivados do art bible nesta sessão.
> **Status**: 11 assets specced / 11 approved / 0 in production / 0 done

**Bloco de estilo comum** — colar ao fim de todo prompt deste arquivo (`+ STYLE`):

```
detailed pixel art, top-down 3/4 RPG view (high camera angle about 45 degrees), crisp clean pixel clusters, hue-shifted shading (shadows shift toward blue-purple, highlights toward warm yellow), no black or grey shadows, light from the top-left, colored outline only on the outer silhouette, limited palette, hard binary transparency, transparent background, game asset
```

**Pipeline (art bible §8):** gerar a 4–8× → nearest-neighbor ao tamanho exato → quantizar na paleta mestra → limpeza manual → alpha binário → testes de silhueta, P&B e contra o chão do bioma. Prompt + seed em `.txt` ao lado do master.

**Regra de chão (art bible §6):** nada vermelho, carmesim ou laranja no chão ou na decoração baixa. Flores em branco, amarelo ou azul.

## Paleta do cenário (proposta)

| Papel | Hex |
|---|---|
| Grama (sombra / base / luz) | `#345E30` / `#3B6B35` / `#447A3C` |
| Tufos | `#6FA04E` / `#7FB05A` |
| Folhagem (sombra → brilho) | `#24502E` / `#3A7A3A` / `#5FA045` / `#8CC85A` |
| Terra do caminho | `#6A4C30` / `#7A5A3A` / `#8C6A45` |
| Pedra | `#4A464F` / `#6E6A72` / `#9A97A0` |

A grama verde fria é proposital: complementar ao vermelho e laranja do mago e do fogo, para que os efeitos sempre se destaquem do chão.

## Negative prompt (cenário)

```
blurry, anti-aliasing, soft or semi-transparent edges, smooth gradients, 3D render, realistic, photo, isometric tiles, side-scroller view, perspective distortion, black outlines on every shape, pure black shadows, grey shadows, characters, people, text, watermark, signature, jpeg artifacts, noise, dithering noise, inconsistent pixel size, red or orange ground details
```

---

## ASSET-008 — Terreno grama↔terra (TileMapLayer)

| Field | Value |
|---|---|
| Category | Environment / Tileset |
| Dimensions | Tile 32×32 · terreno *Match Corners* (16 tiles) + 4 variações de grama + 4 de terra = folha 256×96 px (revisado: era 256×128) |
| Format | PNG RGBA, tiles de chão opacos |
| Naming | `tile_forest_grass_dirt.png` (revisado: era `til_forest_ground.png`) |
| Engine | Terrain set "forest" no TileMapLayer da camada de chão; variações de preenchimento sorteadas por peso (art bible §8) |

**Visual Description:** Grama baixa com variação suave em 3 tons próximos e tufos esparsos; flores minúsculas só em branco, amarelo e azul. Terra batida quente com pedrinhas. A grama invade a terra com borda orgânica e 1 px de grama mais escura. Contraste de valor baixo no chão andável (art bible §6, legibilidade do personagem).

**Nota de produção:** geradores de IA erram grades exatas de tiles. Gere as texturas seamless separadas e monte as transições no Aseprite ou Tiled.

**Prompt:**
```
seamless pixel art terrain tileset for a top-down RPG, 32x32 tiles on an exact grid: short lush grass in 3 close green values (#345E30, #3B6B35, #447A3C) with sparse tufts and tiny white, yellow and blue flowers (never red), packed warm-brown dirt path (#6A4C30 to #8C6A45) with small grey pebbles, organic grass edges that overhang the dirt with 1px darker grass rim, low value contrast on walkable ground. + STYLE
```

**Status:** Needed

---

## ASSET-009 — Árvores comuns (2 espécies × 2 tamanhos)

| Field | Value |
|---|---|
| Category | Environment |
| Dimensions | Até 144×192 por árvore (art bible §8) · 4 árvores: copa larga grande/média, copa alta-estreita grande/média |
| Pivô | Base do tronco (centro-inferior). Colisão: círculo de raio 7–11 px no pivô |
| Format | PNG RGBA, alpha binário |
| Naming | `env_tree_broad_a.png`, `env_tree_broad_b.png`, `env_tree_tall_a.png`, `env_tree_tall_b.png` |
| Engine | Um ShaderMaterial de vento por variante, nunca por instância (§8); copa fica translúcida com o jogador atrás |

**Visual Description:** Copa de 3–5 massas arredondadas em três camadas de valor, com realces quentes no topo-esquerda e furos de céu na borda. **Tronco que se abre em 2–4 raízes** sobre o chão, com tufos de grama por cima (art bible §3 e §6 — corrige "árvore colocada na grama"). Sem frutas vermelhas. A bétula do placeholder sai; a terceira espécie é a árvore-ancestral (ASSET-014).

**Prompt:**
```
pixel art sheet of 4 forest trees on transparent background, trunk bases aligned on one baseline: two broad round-canopy trees (one large, one medium) and two tall narrow conifer-like trees (one large, one medium). Canopy built from 3-5 overlapping rounded leaf masses in three value layers (shadow #24502E, mid #3A7A3A, light #5FA045 with warm highlight clusters #8CC85A on the top-left), small sky holes at the canopy edge. Each trunk flares into 2-4 visible roots spreading onto the ground with small grass tufts over the roots. Bark in warm brown with hue-shifted purple-brown shadows. + STYLE
```
**Status:** Needed

---

## ASSET-010 — Pedras, arbustos, flores e cogumelos

| Field | Value |
|---|---|
| Category | Environment |
| Dimensions | 8 props em células 32×32 · folha 256×32 (revisado: era 192×32) |
| Layout | 3 pedras com musgo · 2 arbustos (frutinhas azuis; flores brancas) · 1 tufo de flores silvestres · 2 cogumelos (marrom-creme; azul-pálido bioluminescente) |
| Pivô | (16, 22). Pedras colidem (raio 8 px); o resto não |
| Format | PNG RGBA, alpha binário |
| Naming | `env_rocks_bushes.png` |

**Visual Description:** Pedras cinza arredondadas com musgo no topo. Arbustos baixos na paleta das árvores. **Sem vermelho nem laranja** (art bible §6): as frutinhas viram azuis e o cogumelo vermelho do placeholder vira marrom-creme ou azul bioluminescente, que reforça o "mistério" da ilha.

**Prompt:**
```
pixel art sheet of 8 small forest props in one row on transparent background: 3 rounded grey rocks with moss on top (#4A464F to #9A97A0, moss #3B6B35), 2 low leafy bushes (one with small blue berries, one with tiny white flowers), 1 clump of white and yellow wildflowers, 2 mushroom clusters (one brown-cream, one pale blue faintly bioluminescent). NO red or orange anywhere. + STYLE
```
**Status:** Needed

---

## ASSET-011 — Boneco de Treino

| Field | Value |
|---|---|
| Category | Sprite (alvo de teste) |
| Dimensions | Célula 64×64 × 4 frames = 256×64 |
| Frames | f1 parado · f2 inclinado à esquerda (hit) · f3 inclinado à direita (hit) · f4 destruído (palha espalhada) |
| Pivô | (32, 58), igual ao mago |
| Format | PNG RGBA, transparente |
| Naming | `spr_training_dummy.png` |

**Visual Description:** Boneco de palha num poste de madeira, com braços em cruz, corpo de saco amarrado com corda e um alvo em **ouro e creme** pintado no peito (revisado: era vermelho — carmesim é a cor do jogador, art bible §4). A cabeça é de juta com olhos em "x". O flash branco, o tremor e a queimadura são feitos pela engine.

**Prompt:**
```
pixel art sprite sheet, 4 frames in a single row on a transparent background, a straw training dummy on a wooden post, cross-shaped wooden arms, burlap sack body tied with rope, a gold and cream painted target ring (#D9A441, #FFF4C2) on the chest, burlap head with stitched x eyes. frame 1 standing still, frame 2 leaning left as if hit, frame 3 leaning right as if hit, frame 4 broken with straw scattered on the ground. straw tones (#B8894A, #D1A35E), wood (#5B3A29), feet aligned on the same baseline. + STYLE
```
**Status:** Needed

---

## ASSET-012 — Slime Desperto (inimigo)

| Field | Value |
|---|---|
| Category | Sprite (inimigo) |
| Dimensions | Célula 64×64 × 4 frames = 256×64 |
| Frames | f1–f2 pulo em loop (esticado / achatado) · f3 hit · f4 morte (poça com cristais quebrados) |
| Pivô | (32, 58) |
| Format | PNG RGBA, alpha binário |
| Naming | `enemy_slime_awakened.png` (revisado: era `spr_slime_green.png`) |

**Visual Description:** Substitui o slime verde e fofo, que violava o art bible: inimigo tem que ser **angular quebrado** (§3) e **violeta** (§4 — Violeta Desperto = o que acordou). Gelatina azul-violeta escura com fragmentos de cristal violeta pontudos e assimétricos saindo do corpo, núcleo brilhando em `#E05ACF`, olhos frios. Destaca-se do verde da floresta (complementar) e não se confunde com o fogo do jogador.

**Prompt:**
```
pixel art sprite sheet, 4 frames in one row on transparent background, a gelatinous creature corrupted by an ancient awakened power: dark translucent-looking blue-violet jelly body (#3A2050 to #8E3FB0) with jagged broken violet crystal shards (#E05ACF glowing core) jutting out at sharp asymmetric angles, two cold glowing eyes. frame 1 stretched mid-hop, frame 2 squashed on landing, frame 3 hit reaction recoiling, frame 4 collapsing into a puddle with shattered crystal shards. Menacing, angular silhouette, never round and cute. + STYLE
```
**Status:** Needed

---

## ASSET-013 — Terrenos de água e areia (TileMapLayer)

| Field | Value |
|---|---|
| Category | Environment / Tileset |
| Dimensions | Tile 32×32 · margens areia↔água e grama↔água em *Match Corners and Sides* (47 tiles cada) · água em 4 frames animados |
| Format | PNG RGBA, tiles opacos |
| Naming | `tile_shore_water.png`, `tile_shore_sand.png` |
| Engine | Camada "água" do TileMapLayer; animação por atlas de tiles (art bible §8: água em tile 4–8 frames) |

**Visual Description:** Água de lago em **3 faixas de profundidade** (raso turquesa claro, médio Água Serena `#3E8FA8`, fundo azul-roxo pouco saturado), margem de areia ou lama molhada de 2–4 px com linha de espuma animada, brilhos de 1–2 px piscando. Areia de praia clara e quente com ondulações e conchinhas (art bible §6).

**Nota de produção:** gerar a textura da água seamless separada e animar deslocando o padrão de ondulação 1 px por frame, com os brilhos alternando.

**Prompt:**
```
seamless pixel art water and shoreline terrain for a top-down RPG, 32x32 tiles: clear lake water in three depth bands (shallow light turquoise near the shore, mid #3E8FA8, deep low-saturation blue-purple), a 2-4 px band of wet sand or mud at the shore with a thin animated white foam line, tiny 1-2 px sparkle highlights on the water surface, warm pale beach sand with subtle ripples and small shells. + STYLE
```
**Status:** Needed

---

## ASSET-014 — Árvore-ancestral

| Field | Value |
|---|---|
| Category | Environment (marco visual) |
| Dimensions | 176×224 (teto do art bible §8) |
| Pivô | (88, 218), base do tronco. Colisão: círculo de raio 14 px |
| Format | PNG RGBA, alpha binário |
| Naming | `env_tree_ancestral.png` |

**Visual Description:** A árvore mais antiga da ilha, 4–5× a altura do mago. Tronco maciço e retorcido com sulcos fundos e musgo; raízes enormes agarrando o chão e **abraçando um bloco de pedra entalhada** com incrustação de sol dourada apagada — o orgânico engolindo o geométrico, a marca do "antigo" (art bible §3 e §6). Copa enorme em camadas, cipós pendendo.

**Prompt:**
```
pixel art of one ancient giant tree on transparent background, the oldest tree on a mystical island: massive twisting trunk with deep bark grooves and moss, huge roots flaring and gripping the ground and wrapping around a half-buried carved stone block with faded gold sun-motif inlay, an enormous layered canopy of rounded leaf masses (#24502E, #3A7A3A, #5FA045, warm highlights #8CC85A top-left), a few soft hanging vines, sky holes at the canopy edge. Majestic, reverent, slightly mysterious. + STYLE
```
**Status:** Needed

---

## ASSET-015 — Decoração de lago

| Field | Value |
|---|---|
| Category | Environment |
| Dimensions | 6 props em células 32×32 · folha 192×32 |
| Layout | 2 grupos de ninfeias (um com flor branca) · 2 touceiras de juncos/taboas · 1 pedra semissubmersa com musgo · 1 grupo de brilhos |
| Format | PNG RGBA, alpha binário |
| Naming | `env_lake_decor.png` |

**Visual Description:** Ninfeias em grupos de 3–5, juncos em touceiras só na margem, brilhos de 1–2 px. Só verdes e azuis frios; a água em si fica limpa (art bible §6).

**Prompt:**
```
pixel art sheet of 6 lake decorations in one row on transparent background: 2 clusters of 3-5 floating lily pads (one with a small white water lily flower), 2 clumps of tall reeds and cattails for the shoreline, 1 small half-submerged mossy rock, 1 cluster of tiny water sparkles. Greens and cool blues only. + STYLE
```
**Status:** Needed

---

## ASSET-016 — Fonte do povo dos santuários

| Field | Value |
|---|---|
| Category | Environment (animado) |
| Dimensions | 96×96 × 6 frames = 576×96 |
| Pivô | Centro da base da bacia. Colisão: círculo de raio 36 px |
| Format | PNG RGBA, alpha binário |
| Naming | `env_shrine_fountain.png` |

**Visual Description:** Bacia circular concêntrica de pedra clara gasta, motivo solar no centro e incrustação de ouro apagada; musgo nas juntas e raízes subindo pela borda. Água Serena corrente com brilho suave em loop de 6 frames; a pedra é idêntica em todos os frames (art bible §6, fonte).

**Prompt:**
```
pixel art sprite sheet, 6 animation frames in one row on transparent background, an ancient circular stone fountain built by a vanished shrine culture: concentric worn pale-stone basin (#6E6A78 to #C9C2B4) with a carved sun motif at the center and faint gold inlay (#D9A441), moss in the stone joints and small roots creeping over the rim, clear water (#3E8FA8) flowing from the center and gently spilling, soft blue shimmer on the water. Loop the water flow and sparkle across the 6 frames, stone stays identical. Symmetric, reverent geometry invaded by organic growth. + STYLE
```
**Status:** Needed

---

## ASSET-017 — Fogueira-checkpoint

| Field | Value |
|---|---|
| Category | Environment (animado, interativo) |
| Dimensions | 64×64 × 8 frames = 512×64 · toras-assento: 2 × 64×32 (folha 128×32) |
| Pivô | (32, 54). Colisão: círculo de raio 12 px |
| Format | PNG RGBA (o sprite com alpha binário; o glow vem da engine) |
| Naming | `env_bonfire.png`, `env_bonfire_logs.png` |
| Engine | Luz híbrida (§8): halo quente pintado no sprite + PointLight2D suave (fonte-chave). Nunca violeta num raio de 6 tiles (§6) |

**Visual Description:** Anel de pedras redondas, toras cruzadas, chama viva com núcleo quase branco, faíscas subindo e halo quente pintado nas pedras e no chão. Lê como **seguro e acolhedor**, diferente da magia de combate pelo anel de pedra e pelo loop estável (art bible §2 e §6).

**Prompt:**
```
pixel art sprite sheet, 8 animation frames in one row on transparent background, a welcoming campfire checkpoint: a ring of rounded grey stones, crossed burning logs, a lively flame with a near-white core (#FFF4C2), yellow (#FFD65C) and orange (#FF7A1A) outer flames, sparks rising, a soft painted warm glow on the stones and the ground around it. Seamless loop of flickering fire. Must read as safe and cozy, clearly different from combat magic. + STYLE
```
**Prompt (toras-assento):**
```
pixel art sheet of 2 mossy wooden logs used as seats around a campfire, on transparent background, weathered bark with hue-shifted shading, moss on top, wet dark undersides touching the ground. + STYLE
```
**Status:** Needed

---

## ASSET-018 — Props da praia do naufrágio

| Field | Value |
|---|---|
| Category | Environment (bioma praia) |
| Dimensions | Casco quebrado até 176×128 · vela rasgada 64×64 · caixotes, barril, cordas, tábuas em 32×32 |
| Pivô | Base de cada prop. O casco colide (forma composta na engine) |
| Format | PNG RGBA, alpha binário |
| Naming | `env_wreck_hull.png`, `env_wreck_sail.png`, `env_wreck_props.png` |

**Visual Description:** Casco de madeira partido na diagonal sobre a areia, costelas quebradas e mastro tombado; vela clara rasgada sobre pedras; caixotes (um aberto), barril, cordas enroladas e tábuas espalhadas. Madeira gasta com base escura e molhada onde toca a areia, algas. Na composição do mapa, uma **trilha de destroços aponta para a floresta** (art bible §6). Contexto: bioma praia; especificado aqui a pedido do usuário até existir um spec de level próprio para a praia.

**Prompt:**
```
pixel art sheet of shipwreck props on transparent background for a top-down beach: a large broken wooden ship hull lying diagonally on the sand with snapped ribs and a torn mast, a torn pale sail draped over rocks, wooden cargo crates (one broken open), a barrel, coiled ropes, scattered planks. Weathered wood with hue-shifted shading, wet dark bottoms where they touch sand, small seaweed details. + STYLE
```
**Status:** Needed
